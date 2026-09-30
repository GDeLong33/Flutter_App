import '../models/box_score.dart';
import '../models/game.dart';
import '../models/lineup_slot.dart';
import '../models/player_result.dart';
import 'espn_api_client.dart';
import 'espn_parsers.dart';
import 'name_matcher.dart';

/// Loads a week's scoreboard and box scores and matches the lineup against
/// them. Returns unscored results; scoring is applied separately so that
/// changing settings doesn't require a refetch.
///
/// Matching strategy per player:
/// 1. Resolve the name via ESPN search (filtered by position) to get the
///    ESPN id and *current* team.
/// 2. Look in the current team's game for that week (match by id, then name).
/// 3. If not there, scan the week's finished box scores. This finds players
///    who were on a different team that week (traded since).
/// 4. Otherwise: bye if the team has no game, upcoming if it hasn't kicked
///    off, else "no stats" (inactive / hasn't recorded a stat).
class LineupTrackerService {
  LineupTrackerService(this._api);

  final EspnApiClient _api;

  /// Final box scores never change, so they're cached for the session.
  final _finalBoxScores = <String, BoxScore>{};
  final _resolvedPlayers = <String, PlayerSearchResult?>{};
  final _statusCache = <String, ({String? status, DateTime fetchedAt})>{};

  static const _statusTtl = Duration(minutes: 30);

  Future<Scoreboard> fetchScoreboard([WeekRef? week]) => _api.fetchScoreboard(week);

  Future<LineupWeekResult> loadWeek({
    required Scoreboard scoreboard,
    required List<LineupSlot> lineup,
  }) async {
    final offense = lineup.where((s) => !s.isDefense).toList();
    final resolved = await Future.wait(offense.map(_resolvePlayer));
    final resolvedBySlot = Map.fromIterables(offense, resolved);

    // Fetch the box scores we definitely need: started games of each
    // player's current team and of each D/ST.
    final neededGameIds = <String>{};
    for (final slot in lineup) {
      final teamId = slot.isDefense
          ? scoreboard.findTeam(slot.name)?.id
          : resolvedBySlot[slot]?.teamId;
      final game = teamId == null ? null : scoreboard.gameForTeam(teamId);
      if (game != null && game.hasStarted) neededGameIds.add(game.id);
    }
    final gamesById = {for (final g in scoreboard.games) g.id: g};
    final boxScores = <String, BoxScore>{};
    await _fetchBoxScores(neededGameIds.map((id) => gamesById[id]!), boxScores);

    // Scan other finished games only if some player wasn't found.
    Future<void> ensureAllFinished() => _fetchBoxScores(
        scoreboard.games.where((g) => g.state == GameState.finished), boxScores);

    final statuses = await _fetchStatuses(resolved.whereType<PlayerSearchResult>());

    final results = <PlayerResult>[];
    for (final slot in lineup) {
      if (slot.isDefense) {
        results.add(_defenseResult(slot, scoreboard, boxScores));
        continue;
      }
      final search = resolvedBySlot[slot];
      final currentGame = search?.teamId == null ? null : scoreboard.gameForTeam(search!.teamId!);

      var found = currentGame != null && boxScores[currentGame.id] != null
          ? _findInBoxScore(boxScores[currentGame.id]!, slot, search)
          : null;
      var foundGame = found == null ? null : currentGame;
      if (found == null) {
        await ensureAllFinished();
        for (final g in scoreboard.games.where((g) => g.state == GameState.finished)) {
          if (g.id == currentGame?.id) continue;
          final hit = _findInBoxScore(boxScores[g.id]!, slot, search, strict: true);
          if (hit != null) {
            found = hit;
            foundGame = g;
            break;
          }
        }
      }

      results.add(_playerResult(
        slot: slot,
        search: search,
        scoreboard: scoreboard,
        currentGame: currentGame,
        found: found,
        foundGame: foundGame,
        status: search == null ? null : statuses[search.id],
      ));
    }

    return LineupWeekResult(
      week: scoreboard.week,
      players: results,
      lastUpdated: DateTime.now(),
    );
  }

  PlayerResult _playerResult({
    required LineupSlot slot,
    required PlayerSearchResult? search,
    required Scoreboard scoreboard,
    required NflGame? currentGame,
    required BoxScorePlayer? found,
    required NflGame? foundGame,
    required String? status,
  }) {
    final position = search?.position ?? slot.effectivePosition;
    final headshot = search?.headshotUrl;
    final name = found?.name ?? search?.name ?? slot.name;

    if (found != null && foundGame != null) {
      final side = foundGame.sideFor(found.teamId);
      return PlayerResult(
        slot: slot,
        displayName: name,
        position: position,
        availability: PlayerAvailability.playing,
        team: side.team,
        opponent: foundGame.opponentOf(found.teamId).team,
        isHome: side.isHome,
        game: foundGame,
        stats: found.stats,
        headshotUrl: headshot,
        injuryStatus: foundGame.state == GameState.finished ? null : status,
      );
    }

    if (search == null) {
      return PlayerResult(
        slot: slot,
        displayName: slot.name,
        position: position,
        availability: PlayerAvailability.notFound,
      );
    }

    final team = _teamFor(search, scoreboard, currentGame);
    if (currentGame == null) {
      return PlayerResult(
        slot: slot,
        displayName: name,
        position: position,
        availability: PlayerAvailability.bye,
        team: team,
        headshotUrl: headshot,
        injuryStatus: status,
      );
    }

    final side = currentGame.sideFor(search.teamId!);
    return PlayerResult(
      slot: slot,
      displayName: name,
      position: position,
      availability: currentGame.hasStarted ? PlayerAvailability.noStats : PlayerAvailability.upcoming,
      team: side.team,
      opponent: currentGame.opponentOf(search.teamId!).team,
      isHome: side.isHome,
      game: currentGame,
      headshotUrl: headshot,
      injuryStatus: currentGame.state == GameState.finished ? null : status,
    );
  }

  TeamInfo? _teamFor(PlayerSearchResult search, Scoreboard sb, NflGame? game) {
    if (game != null) return game.sideFor(search.teamId!).team;
    for (final t in sb.teamsOnBye) {
      if (t.id == search.teamId) return t;
    }
    if (search.teamAbbreviation == null) return null;
    return TeamInfo(
      id: search.teamId ?? '',
      abbreviation: search.teamAbbreviation!,
      displayName: search.teamAbbreviation!,
    );
  }

  PlayerResult _defenseResult(LineupSlot slot, Scoreboard sb, Map<String, BoxScore> boxScores) {
    final team = sb.findTeam(slot.name);
    if (team == null) {
      return PlayerResult(
        slot: slot,
        displayName: slot.name,
        position: 'D/ST',
        availability: PlayerAvailability.notFound,
      );
    }
    final game = sb.gameForTeam(team.id);
    if (game == null) {
      return PlayerResult(
        slot: slot,
        displayName: team.displayName,
        position: 'D/ST',
        availability: PlayerAvailability.bye,
        team: team,
      );
    }
    final side = game.sideFor(team.id);
    final defense = boxScores[game.id]?.defenseByTeamId[team.id];
    return PlayerResult(
      slot: slot,
      displayName: side.team.displayName,
      position: 'D/ST',
      availability: game.hasStarted ? PlayerAvailability.playing : PlayerAvailability.upcoming,
      team: side.team,
      opponent: game.opponentOf(team.id).team,
      isHome: side.isHome,
      game: game,
      // The scoreboard score is authoritative for points allowed.
      defenseStats: defense?.copyWith(pointsAllowed: game.opponentOf(team.id).score),
      headshotUrl: side.team.logoUrl,
    );
  }

  /// Finds the lineup player in a box score: by ESPN id if known, otherwise by
  /// name. With [strict] (scanning other teams' games), name-only matches
  /// must be unambiguous and have offensive/kicking involvement, so a
  /// same-named defender isn't picked up.
  BoxScorePlayer? _findInBoxScore(
    BoxScore box,
    LineupSlot slot,
    PlayerSearchResult? search, {
    bool strict = false,
  }) {
    if (search != null) {
      for (final p in box.players) {
        if (p.id == search.id) return p;
      }
      // With a known id, a name-only hit in the player's own game is safe;
      // elsewhere it's a different person.
      if (strict) return null;
    }
    final byName = box.players.where((p) => NameMatcher.matches(p.name, slot.name)).toList();
    if (byName.isEmpty) return null;
    byName.sort((a, b) => _involvement(b).compareTo(_involvement(a)));
    if (strict && _involvement(byName.first) == 0) return null;
    return byName.first;
  }

  static int _involvement(BoxScorePlayer p) {
    final s = p.stats;
    return s.passAttempts + s.rushAttempts + s.targets + s.receptions +
        s.fieldGoalsAttempted + s.extraPointsAttempted;
  }

  Future<void> _fetchBoxScores(Iterable<NflGame> games, Map<String, BoxScore> into) async {
    await Future.wait(games.where((g) => !into.containsKey(g.id)).map((g) async {
      final cached = _finalBoxScores[g.id];
      if (cached != null) {
        into[g.id] = cached;
        return;
      }
      final box = await _api.fetchBoxScore(g.id);
      into[g.id] = box;
      if (g.state == GameState.finished) _finalBoxScores[g.id] = box;
    }));
  }

  Future<PlayerSearchResult?> _resolvePlayer(LineupSlot slot) async {
    final key = '${NameMatcher.normalize(slot.name)}|${slot.effectivePosition}';
    if (_resolvedPlayers.containsKey(key)) return _resolvedPlayers[key];
    final List<PlayerSearchResult> results;
    try {
      results = await _api.searchPlayers(slot.name);
    } on EspnApiException {
      return null; // Not cached, so it's retried next refresh.
    }
    final allowed = slot.position != null ? [slot.position!] : slot.slot.eligiblePositions;
    final nameMatches = results.where((r) => NameMatcher.matches(r.name, slot.name));
    final best = nameMatches.where((r) => allowed.contains(r.position)).firstOrNull ??
        nameMatches.firstOrNull ??
        results.where((r) => allowed.contains(r.position)).firstOrNull;
    _resolvedPlayers[key] = best;
    return best;
  }

  Future<Map<String, String?>> _fetchStatuses(Iterable<PlayerSearchResult> players) async {
    final now = DateTime.now();
    final out = <String, String?>{};
    await Future.wait(players.map((p) async {
      final cached = _statusCache[p.id];
      if (cached != null && now.difference(cached.fetchedAt) < _statusTtl) {
        out[p.id] = cached.status;
        return;
      }
      try {
        final status = await _api.fetchAthleteStatus(p.id);
        _statusCache[p.id] = (status: status, fetchedAt: now);
        out[p.id] = status;
      } on EspnApiException {
        out[p.id] = null; // Injury status is optional.
      }
    }));
    return out;
  }

  /// Forget resolved players, e.g. after the lineup is edited.
  void clearPlayerCache() => _resolvedPlayers.clear();

  Future<List<PlayerSearchResult>> searchPlayers(String query) => _api.searchPlayers(query, limit: 15);

  Future<List<TeamInfo>> fetchTeams() => _api.fetchTeams();
}
