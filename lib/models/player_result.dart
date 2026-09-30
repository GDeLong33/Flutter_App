import 'game.dart';
import 'lineup_slot.dart';
import 'player_stats.dart';

/// One line of a fantasy score breakdown, e.g. "Rushing yards · 87 → 8.0".
class ScoreLine {
  const ScoreLine({required this.label, required this.statDisplay, required this.points});

  final String label;
  final String statDisplay;
  final double points;
}

class ScoreBreakdown {
  const ScoreBreakdown(this.lines);

  static const empty = ScoreBreakdown([]);

  final List<ScoreLine> lines;

  /// Rounded to 2 decimals to avoid floating point noise like 12.299999.
  double get total =>
      (lines.fold<double>(0, (sum, l) => sum + l.points) * 100).roundToDouble() / 100;
}

enum PlayerAvailability {
  /// Game has started and the player has stats (or a D/ST is playing).
  playing,

  /// Game hasn't kicked off yet.
  upcoming,

  /// The player's team has no game this week.
  bye,

  /// Game started but the player isn't in the box score: inactive, injured,
  /// or simply hasn't recorded a stat yet.
  noStats,

  /// Could not find this player on ESPN at all.
  notFound,
}

/// Everything the UI needs to show one lineup slot for one week.
class PlayerResult {
  const PlayerResult({
    required this.slot,
    required this.displayName,
    required this.availability,
    this.position,
    this.team,
    this.opponent,
    this.isHome,
    this.game,
    this.stats,
    this.defenseStats,
    this.breakdown = ScoreBreakdown.empty,
    this.headshotUrl,
    this.injuryStatus,
  });

  final LineupSlot slot;

  /// Name as ESPN spells it, or the configured name when not resolved.
  final String displayName;
  final PlayerAvailability availability;
  final String? position;
  final TeamInfo? team;
  final TeamInfo? opponent;
  final bool? isHome;
  final NflGame? game;
  final PlayerStats? stats;
  final DefenseStats? defenseStats;
  final ScoreBreakdown breakdown;
  final String? headshotUrl;

  /// e.g. "Out", "Questionable", "Injured Reserve". Null when healthy/unknown.
  final String? injuryStatus;

  double get points => breakdown.total;

  PlayerResult withBreakdown(ScoreBreakdown breakdown) => PlayerResult(
        slot: slot,
        displayName: displayName,
        availability: availability,
        position: position,
        team: team,
        opponent: opponent,
        isHome: isHome,
        game: game,
        stats: stats,
        defenseStats: defenseStats,
        breakdown: breakdown,
        headshotUrl: headshotUrl,
        injuryStatus: injuryStatus,
      );

  GameState? get gameState => game?.state;
}

/// The result of loading one week for the whole lineup.
class LineupWeekResult {
  const LineupWeekResult({
    required this.week,
    required this.players,
    required this.lastUpdated,
    this.refreshError,
  });

  final WeekRef week;
  final List<PlayerResult> players;
  final DateTime lastUpdated;

  /// Set when a background refresh failed; [players] then holds the last
  /// successful data.
  final Object? refreshError;

  double get totalPoints =>
      (players.fold<double>(0, (s, p) => s + p.points) * 100).roundToDouble() / 100;

  bool get anyLive => players.any((p) => p.gameState == GameState.live);

  Iterable<NflGame> get games => players.map((p) => p.game).whereType<NflGame>();

  LineupWeekResult copyWith({List<PlayerResult>? players, Object? refreshError}) =>
      LineupWeekResult(
        week: week,
        players: players ?? this.players,
        lastUpdated: lastUpdated,
        refreshError: refreshError,
      );
}
