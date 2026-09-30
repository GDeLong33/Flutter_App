import '../models/player_result.dart';
import '../models/player_stats.dart';
import '../models/scoring_settings.dart';

/// Converts raw stats into fantasy points, with a per-stat breakdown.
///
/// Lines are only emitted for stats that are non-zero, so a WR won't show
/// "Passing yards · 0".
class ScoringCalculator {
  const ScoringCalculator(this.settings);

  final ScoringSettings settings;

  /// Scores every player in a loaded week.
  LineupWeekResult scoreWeek(LineupWeekResult week) => week.copyWith(
        players: week.players.map((p) => p.withBreakdown(scoreResult(p))).toList(),
        refreshError: week.refreshError,
      );

  ScoreBreakdown scoreResult(PlayerResult p) {
    if (p.defenseStats != null) return scoreDefense(p.defenseStats!);
    if (p.stats != null) return scorePlayer(p.stats!);
    return ScoreBreakdown.empty;
  }

  ScoreBreakdown scorePlayer(PlayerStats s) {
    final lines = <ScoreLine>[];
    void add(String label, num value, double points, {String? display}) {
      if (value == 0) return;
      lines.add(ScoreLine(label: label, statDisplay: display ?? '$value', points: points));
    }

    // Passing
    add('Passing yards', s.passYards, yardagePoints(s.passYards, settings.passYardsPerPoint));
    add('Passing TDs', s.passTds, s.passTds * settings.passTd);
    add('Interceptions thrown', s.interceptions, s.interceptions * settings.interception);

    // Rushing
    add('Rushing yards', s.rushYards, yardagePoints(s.rushYards, settings.rushYardsPerPoint));
    add('Rushing TDs', s.rushTds, s.rushTds * settings.rushTd);

    // Receiving
    add('Receptions', s.receptions, s.receptions * settings.reception);
    add('Receiving yards', s.receivingYards,
        yardagePoints(s.receivingYards, settings.receivingYardsPerPoint));
    add('Receiving TDs', s.receivingTds, s.receivingTds * settings.receivingTd);

    // Misc
    add('Fumbles lost', s.fumblesLost, s.fumblesLost * settings.fumbleLost);
    add('2-pt conversions', s.twoPointConversions,
        s.twoPointConversions * settings.twoPointConversion);
    add('Return TDs', s.returnTds, s.returnTds * settings.returnTd);

    // Kicking
    if (s.fieldGoalsMade > 0) {
      var under40 = 0, from40to49 = 0, over50 = 0;
      for (final d in s.fieldGoalDistances.take(s.fieldGoalsMade)) {
        if (d >= 50) {
          over50++;
        } else if (d >= 40) {
          from40to49++;
        } else {
          under40++;
        }
      }
      // Made FGs whose distance we couldn't determine are scored as short.
      under40 += (s.fieldGoalsMade - s.fieldGoalDistances.length).clamp(0, s.fieldGoalsMade);
      add('FG 0-39 yds', under40, under40 * settings.fgUnder40);
      add('FG 40-49 yds', from40to49, from40to49 * settings.fg40to49);
      add('FG 50+ yds', over50, over50 * settings.fg50Plus);
    }
    add('FG missed', s.fieldGoalsMissed, s.fieldGoalsMissed * settings.fgMissed);
    add('Extra points', s.extraPointsMade, s.extraPointsMade * settings.extraPoint);
    add('XP missed', s.extraPointsMissed, s.extraPointsMissed * settings.extraPointMissed);

    return ScoreBreakdown(lines);
  }

  ScoreBreakdown scoreDefense(DefenseStats s) {
    final lines = <ScoreLine>[];
    void add(String label, num value, double points) {
      if (value == 0) return;
      lines.add(ScoreLine(label: label, statDisplay: _fmt(value), points: points));
    }

    add('Sacks', s.sacks, s.sacks * settings.dstSack);
    add('Interceptions', s.interceptions, s.interceptions * settings.dstInterception);
    add('Fumble recoveries', s.fumbleRecoveries, s.fumbleRecoveries * settings.dstFumbleRecovery);
    add('Return TDs', s.touchdowns, s.touchdowns * settings.dstTouchdown);
    add('Safeties', s.safeties, s.safeties * settings.dstSafety);
    // Always shown, even at 0 points, since it's the core D/ST stat.
    lines.add(ScoreLine(
      label: 'Points allowed',
      statDisplay: '${s.pointsAllowed}',
      points: pointsAllowedPoints(s.pointsAllowed),
    ));
    return ScoreBreakdown(lines);
  }

  /// Points for a yardage total. Whole points only (truncated toward zero)
  /// unless fractional yardage is enabled.
  double yardagePoints(int yards, double yardsPerPoint) {
    if (yardsPerPoint <= 0) return 0;
    final raw = yards / yardsPerPoint;
    if (settings.fractionalYardage) return (raw * 100).roundToDouble() / 100;
    return raw.truncateToDouble();
  }

  double pointsAllowedPoints(int pointsAllowed) {
    for (final tier in settings.pointsAllowedTiers) {
      final max = tier.maxPointsAllowed;
      if (max == null || pointsAllowed <= max) return tier.points;
    }
    return 0;
  }

  static String _fmt(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
