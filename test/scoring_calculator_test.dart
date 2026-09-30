import 'package:flutter_test/flutter_test.dart';
import 'package:lineup_tracker/models/player_result.dart';
import 'package:lineup_tracker/models/player_stats.dart';
import 'package:lineup_tracker/models/scoring_settings.dart';
import 'package:lineup_tracker/services/scoring_calculator.dart';

double? pointsFor(ScoreBreakdown b, String label) {
  for (final l in b.lines) {
    if (l.label == label) return l.points;
  }
  return null;
}

void main() {
  const ppr = ScoringCalculator(ScoringSettings.defaults);

  group('offense (standard PPR)', () {
    test('quarterback line', () {
      const stats = PlayerStats(
        passCompletions: 22,
        passAttempts: 33,
        passYards: 287, // 11.48 -> 11 whole points
        passTds: 2,
        interceptions: 1,
        rushAttempts: 4,
        rushYards: 23,
        rushTds: 1,
      );
      final b = ppr.scorePlayer(stats);
      expect(pointsFor(b, 'Passing yards'), 11);
      expect(pointsFor(b, 'Passing TDs'), 8);
      expect(pointsFor(b, 'Interceptions thrown'), -2);
      expect(pointsFor(b, 'Rushing yards'), 2);
      expect(pointsFor(b, 'Rushing TDs'), 6);
      expect(b.total, 25);
    });

    test('receiver gets 1 point per reception', () {
      const stats = PlayerStats(targets: 10, receptions: 7, receivingYards: 94, receivingTds: 1);
      final b = ppr.scorePlayer(stats);
      expect(pointsFor(b, 'Receptions'), 7);
      expect(pointsFor(b, 'Receiving yards'), 9);
      expect(pointsFor(b, 'Receiving TDs'), 6);
      expect(b.total, 22);
    });

    test('fumbles lost, 2-pt conversions and return TDs', () {
      const stats = PlayerStats(
        rushAttempts: 12,
        rushYards: 40,
        fumbles: 2,
        fumblesLost: 1,
        twoPointConversions: 1,
        returnTds: 1,
      );
      final b = ppr.scorePlayer(stats);
      expect(pointsFor(b, 'Fumbles lost'), -2);
      expect(pointsFor(b, '2-pt conversions'), 2);
      expect(pointsFor(b, 'Return TDs'), 6);
      expect(b.total, 4 - 2 + 2 + 6);
    });

    test('negative rushing yards truncate toward zero', () {
      final b = ppr.scorePlayer(const PlayerStats(rushAttempts: 3, rushYards: -7));
      expect(pointsFor(b, 'Rushing yards'), 0);
      final b2 = ppr.scorePlayer(const PlayerStats(rushAttempts: 3, rushYards: -12));
      expect(pointsFor(b2, 'Rushing yards'), -1);
    });

    test('zero stats produce no lines and zero points', () {
      final b = ppr.scorePlayer(PlayerStats.empty);
      expect(b.lines, isEmpty);
      expect(b.total, 0);
    });

    test('fractional yardage', () {
      const calc = ScoringCalculator(ScoringSettings(fractionalYardage: true));
      final b = calc.scorePlayer(const PlayerStats(rushAttempts: 10, rushYards: 59, passAttempts: 1, passYards: 10));
      expect(pointsFor(b, 'Rushing yards'), 5.9);
      expect(pointsFor(b, 'Passing yards'), 0.4);
      expect(b.total, 6.3);
    });

    test('half PPR setting', () {
      const calc = ScoringCalculator(ScoringSettings(reception: 0.5));
      final b = calc.scorePlayer(const PlayerStats(targets: 5, receptions: 5, receivingYards: 30));
      expect(b.total, 2.5 + 3);
    });

    test('custom 6-point passing TDs', () {
      const calc = ScoringCalculator(ScoringSettings(passTd: 6));
      final b = calc.scorePlayer(const PlayerStats(passAttempts: 30, passTds: 3));
      expect(b.total, 18);
    });

    test('yards-per-point of zero disables yardage instead of dividing by zero', () {
      const calc = ScoringCalculator(ScoringSettings(passYardsPerPoint: 0));
      final b = calc.scorePlayer(const PlayerStats(passAttempts: 30, passYards: 300));
      expect(b.total, 0);
    });
  });

  group('kicker', () {
    test('field goals scored by distance', () {
      const stats = PlayerStats(
        fieldGoalsMade: 4,
        fieldGoalsAttempted: 5,
        fieldGoalDistances: [35, 41, 53, 39],
        extraPointsMade: 2,
        extraPointsAttempted: 3,
      );
      final b = ppr.scorePlayer(stats);
      expect(pointsFor(b, 'FG 0-39 yds'), 6); // 35, 39
      expect(pointsFor(b, 'FG 40-49 yds'), 4); // 41
      expect(pointsFor(b, 'FG 50+ yds'), 5); // 53
      expect(pointsFor(b, 'FG missed'), -1);
      expect(pointsFor(b, 'Extra points'), 2);
      expect(pointsFor(b, 'XP missed'), 0); // Default is no XP-miss penalty.
      expect(b.total, 6 + 4 + 5 - 1 + 2);
    });

    test('40 and 50 yard boundaries', () {
      final b = ppr.scorePlayer(const PlayerStats(
        fieldGoalsMade: 2,
        fieldGoalsAttempted: 2,
        fieldGoalDistances: [40, 50],
      ));
      expect(pointsFor(b, 'FG 40-49 yds'), 4);
      expect(pointsFor(b, 'FG 50+ yds'), 5);
    });

    test('made FGs with unknown distance count as short FGs', () {
      final b = ppr.scorePlayer(const PlayerStats(
        fieldGoalsMade: 3,
        fieldGoalsAttempted: 3,
        fieldGoalDistances: [52],
      ));
      expect(pointsFor(b, 'FG 50+ yds'), 5);
      expect(pointsFor(b, 'FG 0-39 yds'), 6);
      expect(b.total, 11);
    });
  });

  group('defense / special teams', () {
    test('shutout with turnovers', () {
      const d = DefenseStats(
        sacks: 4,
        interceptions: 2,
        fumbleRecoveries: 1,
        touchdowns: 1,
        safeties: 1,
        pointsAllowed: 0,
      );
      final b = ppr.scoreDefense(d);
      expect(pointsFor(b, 'Sacks'), 4);
      expect(pointsFor(b, 'Interceptions'), 4);
      expect(pointsFor(b, 'Fumble recoveries'), 2);
      expect(pointsFor(b, 'Return TDs'), 6);
      expect(pointsFor(b, 'Safeties'), 2);
      expect(pointsFor(b, 'Points allowed'), 5);
      expect(b.total, 23);
    });

    test('half sacks', () {
      final b = ppr.scoreDefense(const DefenseStats(sacks: 2.5, pointsAllowed: 20));
      expect(pointsFor(b, 'Sacks'), 2.5);
      expect(b.lines.firstWhere((l) => l.label == 'Sacks').statDisplay, '2.5');
    });

    test('points allowed tiers', () {
      final expected = {
        0: 5.0,
        1: 4.0,
        6: 4.0,
        7: 3.0,
        13: 3.0,
        14: 1.0,
        17: 1.0,
        18: 0.0,
        27: 0.0,
        28: -1.0,
        34: -1.0,
        35: -3.0,
        45: -3.0,
        46: -5.0,
        70: -5.0,
      };
      expected.forEach((pa, pts) {
        expect(ppr.pointsAllowedPoints(pa), pts, reason: '$pa points allowed');
      });
    });

    test('points allowed line is always present', () {
      final b = ppr.scoreDefense(const DefenseStats(pointsAllowed: 21));
      expect(b.lines.map((l) => l.label), ['Points allowed']);
      expect(b.total, 0);
    });
  });

  test('settings survive a JSON round trip', () {
    final custom = ScoringSettings.defaults.copyWith(
      reception: 0.5,
      passTd: 6,
      fractionalYardage: true,
      pointsAllowedTiers: [
        ...ScoringSettings.defaultPointsAllowedTiers.take(7),
        const PointsAllowedTier(maxPointsAllowed: null, points: -10),
      ],
    );
    final restored = ScoringSettings.fromJson(custom.toJson());
    expect(restored.reception, 0.5);
    expect(restored.passTd, 6);
    expect(restored.fractionalYardage, isTrue);
    expect(restored.pointsAllowedTiers.last.points, -10);
    expect(restored.pointsAllowedTiers.last.maxPointsAllowed, isNull);
  });

  test('missing JSON keys fall back to defaults', () {
    final s = ScoringSettings.fromJson({'reception': 0});
    expect(s.reception, 0);
    expect(s.passYardsPerPoint, 25);
    expect(s.pointsAllowedTiers.length, ScoringSettings.defaultPointsAllowedTiers.length);
  });
}
