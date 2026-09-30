import '../models/box_score.dart';
import '../models/game.dart';
import '../models/player_stats.dart';
import 'name_matcher.dart';

/// Pure functions that turn ESPN JSON into models. Kept separate from the
/// HTTP client so they can be tested against saved responses.
///
/// ESPN's endpoints are unofficial, so every field access is defensive: a
/// missing field becomes 0 / null rather than an exception.
class EspnParsers {
  // ---------------------------------------------------------------- scoreboard

  static Scoreboard parseScoreboard(Map<String, dynamic> json) {
    final season = _map(json['season']);
    final year = _int(season['year']);
    final seasonType = _int(season['type'], fallback: 2);
    final weekNumber = _int(_map(json['week'])['number'], fallback: 1);

    final calendar = <WeekRef>[];
    final leagues = _list(json['leagues']);
    if (leagues.isNotEmpty) {
      for (final period in _list(_map(leagues.first)['calendar'])) {
        final p = _map(period);
        // "value" is the season type: 1 pre, 2 regular, 3 post, 4 off.
        final type = _int(p['value']);
        if (type != 2 && type != 3) continue;
        for (final entry in _list(p['entries'])) {
          final e = _map(entry);
          final label = e['label'] as String? ?? 'Week ${e['value']}';
          // Skip the Pro Bowl week; nobody starts players in it.
          if (label.toLowerCase().contains('pro bowl')) continue;
          calendar.add(WeekRef(
            year: year,
            seasonType: type,
            week: _int(e['value']),
            label: label,
          ));
        }
      }
    }

    final current = calendar.firstWhere(
      (w) => w.seasonType == seasonType && w.week == weekNumber,
      orElse: () => WeekRef(
        year: year,
        seasonType: seasonType,
        week: weekNumber,
        label: 'Week $weekNumber',
      ),
    );

    final games = _list(json['events']).map((e) => parseGame(_map(e))).whereType<NflGame>().toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

    final byes = _list(_map(json['week'])['teamsOnBye']).map((t) => _parseTeam(_map(t))).toList();

    return Scoreboard(week: current, games: games, teamsOnBye: byes, calendar: calendar);
  }

  static NflGame? parseGame(Map<String, dynamic> event) {
    final comps = _list(event['competitions']);
    if (comps.isEmpty) return null;
    final comp = _map(comps.first);
    final competitors = _list(comp['competitors']).map(_map).toList();
    if (competitors.length != 2) return null;

    GameTeam side(Map<String, dynamic> c) => GameTeam(
          team: _parseTeam(_map(c['team'])),
          score: _int(c['score']),
          isHome: c['homeAway'] == 'home',
        );
    final home = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => competitors[0]);
    final away = competitors.firstWhere((c) => c != home, orElse: () => competitors[1]);

    final status = _map(comp['status'] ?? event['status']);
    final type = _map(status['type']);
    final state = switch (type['state']) {
      'in' => GameState.live,
      'post' => GameState.finished,
      _ => GameState.upcoming,
    };

    return NflGame(
      id: '${event['id']}',
      kickoff: DateTime.tryParse('${event['date']}')?.toLocal() ?? DateTime.now(),
      state: state,
      statusName: type['name'] as String? ?? '',
      statusDetail: type['shortDetail'] as String? ?? type['detail'] as String? ?? '',
      period: _int(status['period']),
      displayClock: status['displayClock'] as String? ?? '',
      home: side(home),
      away: side(away),
    );
  }

  static TeamInfo _parseTeam(Map<String, dynamic> t) {
    String? logo = t['logo'] as String?;
    final logos = _list(t['logos']);
    if (logo == null && logos.isNotEmpty) logo = _map(logos.first)['href'] as String?;
    return TeamInfo(
      id: '${t['id']}',
      abbreviation: t['abbreviation'] as String? ?? '',
      displayName: t['displayName'] as String? ?? '',
      shortName: t['shortDisplayName'] as String? ?? t['name'] as String?,
      logoUrl: logo,
    );
  }

  /// Parses the /teams endpoint into a sorted team list.
  static List<TeamInfo> parseTeams(Map<String, dynamic> json) {
    final sports = _list(json['sports']);
    if (sports.isEmpty) return const [];
    final leagues = _list(_map(sports.first)['leagues']);
    if (leagues.isEmpty) return const [];
    return _list(_map(leagues.first)['teams'])
        .map((t) => _parseTeam(_map(_map(t)['team'])))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  // ------------------------------------------------------------------ summary

  static BoxScore parseSummary(String gameId, Map<String, dynamic> json) {
    final box = _map(json['boxscore']);
    final scoringPlays = _list(json['scoringPlays']).map(_map).toList();

    // --- Individual players ---
    final byId = <String, _PlayerAccumulator>{};
    for (final teamEntry in _list(box['players']).map(_map)) {
      final teamId = '${_map(teamEntry['team'])['id']}';
      for (final category in _list(teamEntry['statistics']).map(_map)) {
        final name = category['name'] as String? ?? '';
        final keys = _list(category['keys']).map((k) => '$k').toList();
        for (final a in _list(category['athletes']).map(_map)) {
          final athlete = _map(a['athlete']);
          final id = '${athlete['id']}';
          final acc = byId.putIfAbsent(
            id,
            () => _PlayerAccumulator(id, athlete['displayName'] as String? ?? '', teamId),
          );
          final values = _list(a['stats']).map((v) => '$v').toList();
          acc.apply(name, _StatRow(keys, values));
        }
      }
    }

    // Field goal distances and 2-pt conversions only appear in play text.
    for (final play in scoringPlays) {
      final teamId = '${_map(play['team'])['id']}';
      final text = play['text'] as String? ?? '';
      final typeText = _map(play['type'])['text'] as String? ?? '';

      if (typeText.contains('Field Goal')) {
        final m = _fgRegex.firstMatch(text);
        if (m != null) {
          _findByName(byId.values, m.group(1)!, teamId)?.fgDistances.add(int.parse(m.group(2)!));
        }
      }
      for (final m in _twoPtPassRegex.allMatches(text)) {
        _findByName(byId.values, m.group(1)!, teamId)?.twoPt++;
        _findByName(byId.values, m.group(2)!, teamId)?.twoPt++;
      }
      for (final m in _twoPtRunRegex.allMatches(text)) {
        _findByName(byId.values, m.group(1)!, teamId)?.twoPt++;
      }
    }

    final players = byId.values.map((a) => a.build()).toList();

    // --- Team defenses ---
    final teamStats = <String, Map<String, String>>{};
    for (final t in _list(box['teams']).map(_map)) {
      final id = '${_map(t['team'])['id']}';
      teamStats[id] = {
        for (final s in _list(t['statistics']).map(_map))
          '${s['name']}': '${s['displayValue'] ?? s['value'] ?? ''}',
      };
    }
    final scores = <String, int>{};
    final headerComps = _list(_map(json['header'])['competitions']);
    if (headerComps.isNotEmpty) {
      for (final c in _list(_map(headerComps.first)['competitors']).map(_map)) {
        scores['${_map(c['team'])['id']}'] = _int(c['score']);
      }
    }
    final defTotals = <String, _StatRow>{};
    for (final teamEntry in _list(box['players']).map(_map)) {
      final teamId = '${_map(teamEntry['team'])['id']}';
      for (final category in _list(teamEntry['statistics']).map(_map)) {
        if (category['name'] == 'defensive') {
          defTotals[teamId] = _StatRow(
            _list(category['keys']).map((k) => '$k').toList(),
            _list(category['totals']).map((v) => '$v').toList(),
          );
        }
      }
    }

    final defense = <String, DefenseStats>{};
    final teamIds = {...teamStats.keys, ...scores.keys};
    for (final id in teamIds) {
      final oppId = teamIds.firstWhere((t) => t != id, orElse: () => '');
      final opp = teamStats[oppId] ?? const {};
      var tds = 0, safeties = 0;
      for (final play in scoringPlays) {
        if ('${_map(play['team'])['id']}' != id) continue;
        final typeText = (_map(play['type'])['text'] as String? ?? '').toLowerCase();
        final scoringType = (_map(play['scoringType'])['name'] as String? ?? '').toLowerCase();
        if (typeText.contains('safety') || scoringType == 'safety') {
          safeties++;
        } else if (scoringType == 'touchdown' &&
            (typeText.contains('return') || typeText.contains('blocked'))) {
          tds++;
        }
      }
      defense[id] = DefenseStats(
        sacks: defTotals[id]?.dbl('sacks') ?? 0,
        interceptions: _int(opp['interceptions']),
        fumbleRecoveries: _int(opp['fumblesLost']),
        touchdowns: tds,
        safeties: safeties,
        pointsAllowed: scores[oppId] ?? 0,
      );
    }

    return BoxScore(gameId: gameId, players: players, defenseByTeamId: defense);
  }

  static final _fgRegex = RegExp(r'^(.+?) (\d+) Yd Field Goal');
  static final _twoPtPassRegex =
      RegExp(r'\(([^()]+?) Pass to ([^()]+?) for Two-Point Conversion\)', caseSensitive: false);
  static final _twoPtRunRegex =
      RegExp(r'\(([^()]+?) (?:Run|Rush) for Two-Point Conversion\)', caseSensitive: false);

  static _PlayerAccumulator? _findByName(
      Iterable<_PlayerAccumulator> players, String name, String teamId) {
    for (final p in players) {
      if (p.teamId == teamId && NameMatcher.matches(p.name, name)) return p;
    }
    return null;
  }

  // ------------------------------------------------------------------- search

  static List<PlayerSearchResult> parsePlayerSearch(Map<String, dynamic> json) {
    return _list(json['items']).map(_map).where((i) => i['type'] == 'player').map((i) {
      final teams = _list(i['teamRelationships']).map(_map).toList();
      final team = teams.isEmpty ? null : _map(teams.first['core']);
      return PlayerSearchResult(
        id: '${i['id']}',
        name: i['displayName'] as String? ?? '',
        position: normalizePosition(_map(i['position'])['abbreviation'] as String?),
        teamId: team == null ? null : '${team['id']}',
        teamAbbreviation: team?['abbreviation'] as String?,
        headshotUrl: _map(i['headshot'])['href'] as String?,
        isActive: i['isActive'] as bool? ?? true,
      );
    }).toList();
  }

  /// Athlete endpoint → injury / roster status such as "Injured Reserve".
  /// Returns null for plain "Active".
  static String? parseAthleteStatus(Map<String, dynamic> json) {
    final athlete = _map(json['athlete'] ?? json);
    final injuries = _list(athlete['injuries']);
    if (injuries.isNotEmpty) {
      final status = _map(injuries.first)['status'] as String?;
      if (status != null && status.isNotEmpty) return status;
    }
    final status = _map(athlete['status'])['name'] as String?;
    if (status == null || status == 'Active') return null;
    return status;
  }

  /// ESPN uses "PK" for kickers; the app uses "K".
  static String? normalizePosition(String? pos) => pos == 'PK' ? 'K' : pos;

  // ------------------------------------------------------------------ helpers

  static Map<String, dynamic> _map(Object? v) =>
      v is Map<String, dynamic> ? v : const <String, dynamic>{};
  static List<dynamic> _list(Object? v) => v is List ? v : const [];
  static int _int(Object? v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
    return fallback;
  }
}

class PlayerSearchResult {
  const PlayerSearchResult({
    required this.id,
    required this.name,
    required this.position,
    required this.teamId,
    required this.teamAbbreviation,
    required this.headshotUrl,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? position;
  final String? teamId;
  final String? teamAbbreviation;
  final String? headshotUrl;
  final bool isActive;
}

/// A box score stat row: parallel `keys` / `values` arrays. Handles compound
/// values like "26/48" (completions/attempts) and "3-29" (sacks-yards).
class _StatRow {
  _StatRow(List<String> keys, List<String> values) {
    for (var i = 0; i < keys.length && i < values.length; i++) {
      final key = keys[i];
      final value = values[i].trim();
      if (key.contains('/')) {
        final ks = key.split('/');
        final vs = value.split('/');
        for (var j = 0; j < ks.length && j < vs.length; j++) {
          _values[ks[j]] = vs[j];
        }
      } else if (key.startsWith('sacks-')) {
        final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(value);
        _values['sacksTaken'] = m?.group(1) ?? '0';
      } else {
        _values[key] = value;
      }
    }
  }

  final _values = <String, String>{};

  int i(String key) {
    final v = _values[key];
    if (v == null) return 0;
    return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
  }

  double dbl(String key) => double.tryParse(_values[key] ?? '') ?? 0;
}

class _PlayerAccumulator {
  _PlayerAccumulator(this.id, this.name, this.teamId);

  final String id;
  final String name;
  final String teamId;
  PlayerStats stats = PlayerStats.empty;
  final fgDistances = <int>[];
  int twoPt = 0;

  void apply(String category, _StatRow r) {
    stats = switch (category) {
      'passing' => stats.copyWith(
          passCompletions: r.i('completions'),
          passAttempts: r.i('passingAttempts'),
          passYards: r.i('passingYards'),
          passTds: r.i('passingTouchdowns'),
          interceptions: r.i('interceptions'),
          sacksTaken: r.i('sacksTaken'),
        ),
      'rushing' => stats.copyWith(
          rushAttempts: r.i('rushingAttempts'),
          rushYards: r.i('rushingYards'),
          rushTds: r.i('rushingTouchdowns'),
        ),
      'receiving' => stats.copyWith(
          receptions: r.i('receptions'),
          receivingYards: r.i('receivingYards'),
          receivingTds: r.i('receivingTouchdowns'),
          targets: r.i('receivingTargets'),
        ),
      'fumbles' => stats.copyWith(fumbles: r.i('fumbles'), fumblesLost: r.i('fumblesLost')),
      'kicking' => stats.copyWith(
          fieldGoalsMade: r.i('fieldGoalsMade'),
          fieldGoalsAttempted: r.i('fieldGoalAttempts'),
          extraPointsMade: r.i('extraPointsMade'),
          extraPointsAttempted: r.i('extraPointAttempts'),
        ),
      'kickReturns' => stats.copyWith(returnTds: stats.returnTds + r.i('kickReturnTouchdowns')),
      'puntReturns' => stats.copyWith(returnTds: stats.returnTds + r.i('puntReturnTouchdowns')),
      _ => stats,
    };
  }

  BoxScorePlayer build() => BoxScorePlayer(
        id: id,
        name: name,
        teamId: teamId,
        stats: stats.copyWith(fieldGoalDistances: List.unmodifiable(fgDistances), twoPointConversions: twoPt),
      );
}
