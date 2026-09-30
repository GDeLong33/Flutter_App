import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lineup_tracker/models/box_score.dart';
import 'package:lineup_tracker/models/game.dart';
import 'package:lineup_tracker/models/scoring_settings.dart';
import 'package:lineup_tracker/services/espn_parsers.dart';
import 'package:lineup_tracker/services/name_matcher.dart';
import 'package:lineup_tracker/services/polling_policy.dart';
import 'package:lineup_tracker/services/scoring_calculator.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  // Real ESPN response: 2026 week 3, CAR @ CLE (CLE won 21-18).
  group('box score parsing', () {
    late BoxScore box;
    const calc = ScoringCalculator(ScoringSettings.defaults);
    BoxScorePlayer player(String name) => box.players.firstWhere((p) => p.name == name);

    setUpAll(() => box = EspnParsers.parseSummary('401872949', fixture('summary_car_at_cle.json')));

    test('quarterback stat line', () {
      final s = player('Bryce Young').stats;
      expect(s.passCompletions, 26);
      expect(s.passAttempts, 48);
      expect(s.passYards, 291);
      expect(s.passTds, 1);
      expect(s.interceptions, 1);
      expect(s.sacksTaken, 3);
      // 291/25 -> 11, 1 TD -> 4, 1 INT -> -2
      expect(calc.scorePlayer(s).total, 13);
    });

    test('stats merge across categories and 2-pt conversions come from play text', () {
      final watson = player('Deshaun Watson').stats;
      expect(watson.passYards, 144);
      expect(watson.rushYards, 45);
      expect(watson.twoPointConversions, 1);
      // 144 -> 5, 2 TD -> 8, 45 rush -> 4, 2PT -> 2
      expect(calc.scorePlayer(watson).total, 19);

      final boston = player('Denzel Boston').stats;
      expect(boston.twoPointConversions, 1);
      expect(calc.scorePlayer(boston).total, 2 + 4 + 2);
    });

    test('receiving and fumbles', () {
      final fannin = player('Harold Fannin Jr.').stats;
      expect(fannin.receptions, 7);
      expect(fannin.targets, 9);
      expect(fannin.receivingTds, 2);
      expect(calc.scorePlayer(fannin).total, 7 + 5 + 12);

      expect(player('Malachi Corley').stats.fumblesLost, 1);
    });

    test('kicker distances come from scoring plays', () {
      final fitz = player('Ryan Fitzgerald').stats;
      expect(fitz.fieldGoalsMade, 4);
      expect(fitz.fieldGoalDistances, [35, 41, 53, 37]);
      expect(calc.scorePlayer(fitz).total, 3 + 4 + 5 + 3);

      final szmyt = player('Andre Szmyt').stats;
      expect(szmyt.fieldGoalDistances, [48, 45]);
      expect(szmyt.extraPointsMade, 1);
      expect(calc.scorePlayer(szmyt).total, 4 + 4 + 1);
    });

    test('team defenses', () {
      final car = box.defenseByTeamId['29']!;
      expect(car.sacks, 2);
      expect(car.interceptions, 0);
      expect(car.fumbleRecoveries, 1);
      expect(car.pointsAllowed, 21);

      final cle = box.defenseByTeamId['5']!;
      expect(cle.sacks, 3);
      expect(cle.interceptions, 1);
      expect(cle.fumbleRecoveries, 0);
      expect(cle.pointsAllowed, 18);
      expect(calc.scoreDefense(cle).total, 3 + 2 + 0);
    });

    test('pre-game summary without players parses to an empty box score', () {
      final empty = EspnParsers.parseSummary('1', {'boxscore': {'teams': []}});
      expect(empty.players, isEmpty);
      expect(empty.hasPlayerStats, isFalse);
    });

    test('garbage values like "--" become zero', () {
      final box = EspnParsers.parseSummary('1', {
        'boxscore': {
          'players': [
            {
              'team': {'id': '1'},
              'statistics': [
                {
                  'name': 'passing',
                  'keys': ['completions/passingAttempts', 'passingYards', 'passingTouchdowns'],
                  'athletes': [
                    {
                      'athlete': {'id': '9', 'displayName': 'Test QB'},
                      'stats': ['--', '--', '1'],
                    },
                  ],
                },
              ],
            },
          ],
        },
      });
      final s = box.players.single.stats;
      expect(s.passYards, 0);
      expect(s.passCompletions, 0);
      expect(s.passTds, 1);
    });
  });

  group('scoreboard parsing', () {
    // Real ESPN response for 2026 week 5 (scheduled, KC and CAR on bye).
    late Scoreboard sb;
    setUpAll(() => sb = EspnParsers.parseScoreboard(fixture('scoreboard_week5.json')));

    test('week, games and byes', () {
      expect(sb.week.week, 5);
      expect(sb.week.seasonType, 2);
      expect(sb.games, hasLength(15));
      expect(sb.games.every((g) => g.state == GameState.upcoming), isTrue);
      expect(sb.teamsOnBye.map((t) => t.abbreviation), containsAll(['KC', 'CAR']));
    });

    test('calendar has regular season and postseason weeks only', () {
      expect(sb.calendar.where((w) => w.seasonType == 2), hasLength(18));
      expect(sb.calendar.any((w) => w.seasonType == 3), isTrue);
      expect(sb.calendar.any((w) => w.seasonType == 1), isFalse);
      expect(sb.calendar.any((w) => w.label.toLowerCase().contains('pro bowl')), isFalse);
    });

    test('finds teams by full name, nickname or abbreviation', () {
      expect(sb.findTeam('Baltimore Ravens')?.abbreviation, 'BAL');
      expect(sb.findTeam('ravens')?.abbreviation, 'BAL');
      expect(sb.findTeam('BAL')?.displayName, 'Baltimore Ravens');
      // Bye teams are still found.
      expect(sb.findTeam('Kansas City Chiefs')?.abbreviation, 'KC');
      expect(sb.gameForTeam(sb.findTeam('KC')!.id), isNull);
    });
  });

  group('name matching', () {
    test('ignores case, punctuation and suffixes', () {
      expect(NameMatcher.matches('Devonta Smith', 'DeVonta Smith'), isTrue);
      expect(NameMatcher.matches('James Cook', 'James Cook III'), isTrue);
      expect(NameMatcher.matches('Harold Fannin', 'Harold Fannin Jr.'), isTrue);
      expect(NameMatcher.matches("Ja'Marr Chase", 'JaMarr Chase'), isTrue);
      expect(NameMatcher.matches('Amon-Ra St. Brown', 'Amon-Ra St Brown'), isTrue);
      expect(NameMatcher.matches('Josh Downs', 'Josh Allen'), isFalse);
    });
  });

  group('polling policy', () {
    final now = DateTime(2026, 10, 4, 12);
    NflGame game(GameState state, {Duration offset = Duration.zero}) {
      const team = TeamInfo(id: '1', abbreviation: 'A', displayName: 'A');
      return NflGame(
        id: 'g',
        kickoff: now.add(offset),
        state: state,
        statusName: '',
        statusDetail: '',
        period: 0,
        displayClock: '',
        home: const GameTeam(team: team, score: 0, isHome: true),
        away: const GameTeam(team: team, score: 0, isHome: false),
      );
    }

    test('30s while live, slower after an error', () {
      final games = [game(GameState.live), game(GameState.finished)];
      expect(PollingPolicy.nextDelay(games, now), const Duration(seconds: 30));
      expect(PollingPolicy.nextDelay(games, now, afterError: true), const Duration(seconds: 60));
    });

    test('stops when everything is final', () {
      expect(PollingPolicy.nextDelay([game(GameState.finished)], now), isNull);
      expect(PollingPolicy.nextDelay(const [], now), isNull);
    });

    test('every minute close to kickoff (including delayed kickoffs)', () {
      expect(PollingPolicy.nextDelay([game(GameState.upcoming, offset: const Duration(minutes: 10))], now),
          const Duration(seconds: 60));
      expect(PollingPolicy.nextDelay([game(GameState.upcoming, offset: const Duration(minutes: -5))], now),
          const Duration(seconds: 60));
    });

    test('sleeps until shortly before a later kickoff, capped at 30 min', () {
      expect(PollingPolicy.nextDelay([game(GameState.upcoming, offset: const Duration(minutes: 25))], now),
          const Duration(minutes: 10));
      expect(PollingPolicy.nextDelay([game(GameState.upcoming, offset: const Duration(days: 3))], now),
          const Duration(minutes: 30));
    });
  });
}
