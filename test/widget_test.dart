import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lineup_tracker/config/lineup_config.dart';
import 'package:lineup_tracker/main.dart';
import 'package:lineup_tracker/models/game.dart';
import 'package:lineup_tracker/models/player_result.dart';
import 'package:lineup_tracker/providers/providers.dart';
import 'package:lineup_tracker/services/espn_parsers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const week = WeekRef(year: 2026, seasonType: 2, week: 3, label: 'Week 3');

TeamInfo team(String id, String abbr) => TeamInfo(id: id, abbreviation: abbr, displayName: abbr);

NflGame game(GameState state, {String detail = ''}) => NflGame(
      id: 'g-${state.name}',
      kickoff: DateTime(2026, 9, 27, 13),
      state: state,
      statusName: '',
      statusDetail: detail,
      period: 2,
      displayClock: '4:12',
      home: GameTeam(team: team('5', 'CLE'), score: 21, isHome: true),
      away: GameTeam(team: team('29', 'CAR'), score: 18, isHome: false),
    );

/// A week with one player in each state, using real parsed box score stats.
LineupWeekResult sampleWeek() {
  final json = jsonDecode(File('test/fixtures/summary_car_at_cle.json').readAsStringSync());
  final box = EspnParsers.parseSummary('1', json as Map<String, dynamic>);
  final young = box.players.firstWhere((p) => p.name == 'Bryce Young');
  final fitz = box.players.firstWhere((p) => p.name == 'Ryan Fitzgerald');
  final slots = defaultLineup;
  final finalGame = game(GameState.finished, detail: 'Final');
  final liveGame = game(GameState.live, detail: '4:12 - 2nd');
  PlayerResult base(int i, PlayerAvailability a, {NflGame? g}) => PlayerResult(
        slot: slots[i],
        displayName: slots[i].name,
        availability: a,
        position: slots[i].effectivePosition,
        team: team('29', 'CAR'),
        opponent: team('5', 'CLE'),
        isHome: false,
        game: g,
      );
  return LineupWeekResult(
    week: week,
    lastUpdated: DateTime(2026, 9, 27, 15),
    players: [
      PlayerResult(
        slot: slots[0],
        displayName: 'Bryce Young',
        availability: PlayerAvailability.playing,
        position: 'QB',
        team: team('29', 'CAR'),
        opponent: team('5', 'CLE'),
        isHome: false,
        game: finalGame,
        stats: young.stats,
      ),
      base(1, PlayerAvailability.noStats, g: liveGame),
      base(2, PlayerAvailability.upcoming, g: game(GameState.upcoming)),
      base(3, PlayerAvailability.bye),
      base(4, PlayerAvailability.notFound),
      base(5, PlayerAvailability.noStats, g: finalGame),
      base(6, PlayerAvailability.upcoming, g: game(GameState.upcoming)),
      PlayerResult(
        slot: slots[7],
        displayName: 'Spencer Shrader',
        availability: PlayerAvailability.playing,
        position: 'K',
        team: team('29', 'CAR'),
        opponent: team('5', 'CLE'),
        isHome: false,
        game: liveGame,
        stats: fitz.stats,
        injuryStatus: 'Questionable',
      ),
      PlayerResult(
        slot: slots[8],
        displayName: 'Baltimore Ravens',
        availability: PlayerAvailability.playing,
        position: 'D/ST',
        team: team('29', 'CAR'),
        opponent: team('5', 'CLE'),
        isHome: false,
        game: finalGame,
        defenseStats: box.defenseByTeamId['29'],
      ),
    ],
  );
}

class FakeLineupWeek extends LineupWeekNotifier {
  @override
  Future<LineupWeekResult> build() async => sampleWeek();

  @override
  Future<void> refresh() async {}
}

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      seasonCalendarProvider.overrideWith((ref) async => (current: week, weeks: const [week])),
      lineupWeekProvider.overrideWith(FakeLineupWeek.new),
    ],
    retry: (_, _) => null,
    child: const LineupTrackerApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lineup screen shows total and every slot state', (tester) async {
    await pumpApp(tester);

    // QB 13 + K 15 + D/ST (2 sacks + 1 FR + PA 21 -> 0) 4 = 32
    expect(find.text('32.0'), findsOneWidget);
    expect(find.text('Bryce Young'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('BYE'), findsOneWidget);
    expect(find.text('NOT FOUND'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Spencer Shrader'), 200);
    expect(find.text('Q'), findsOneWidget); // Questionable pill
  });

  testWidgets('tapping a card opens the stat breakdown', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Bryce Young'));
    await tester.pumpAndSettle();

    expect(find.text('PASSING'), findsOneWidget);
    expect(find.text('26/48'), findsOneWidget);
    expect(find.text('FANTASY POINTS BREAKDOWN'), findsOneWidget);
    expect(find.text('Passing yards'), findsOneWidget);
    expect(find.text('+11.0'), findsOneWidget);
    expect(find.text('-2.0'), findsOneWidget);
  });

  testWidgets('D/ST detail shows defense stats', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Baltimore Ravens'), 200);
    await tester.tap(find.text('Baltimore Ravens'));
    await tester.pumpAndSettle();

    expect(find.text('DEFENSE / SPECIAL TEAMS'), findsOneWidget);
    expect(find.text('Points allowed'), findsOneWidget);
  });

  testWidgets('changing scoring settings rescores and persists', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scoring settings'));
    await tester.pumpAndSettle();

    // Passing TD is the second field in the list: 4 -> 6.
    final passTdField = find.descendant(
      of: find.widgetWithText(ListTile, 'Passing TD'),
      matching: find.byType(TextField),
    );
    await tester.enterText(passTdField, '6');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('scoring_settings_v1'), contains('"passTd":6'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('34.0'), findsOneWidget); // +2 for Bryce Young's TD
  });

  testWidgets('edit lineup screen lists every slot', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit lineup'));
    await tester.pumpAndSettle();

    for (final slot in defaultLineup) {
      expect(find.text(slot.name), findsOneWidget);
    }
    expect(find.text('FLEX'), findsOneWidget);
  });
}
