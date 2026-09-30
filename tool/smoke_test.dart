// ignore_for_file: avoid_print

// Live check against ESPN, without the UI:
//   dart run tool/smoke_test.dart            (current week)
//   dart run tool/smoke_test.dart 2 3        (season type 2, week 3)
import 'package:lineup_tracker/config/lineup_config.dart';
import 'package:lineup_tracker/models/game.dart';
import 'package:lineup_tracker/models/scoring_settings.dart';
import 'package:lineup_tracker/services/espn_api_client.dart';
import 'package:lineup_tracker/services/lineup_tracker_service.dart';
import 'package:lineup_tracker/services/scoring_calculator.dart';

Future<void> main(List<String> args) async {
  final api = EspnApiClient();
  final service = LineupTrackerService(api);
  try {
    var scoreboard = await service.fetchScoreboard();
    if (args.length == 2) {
      scoreboard = await service.fetchScoreboard(WeekRef(
        year: scoreboard.week.year,
        seasonType: int.parse(args[0]),
        week: int.parse(args[1]),
        label: '',
      ));
    }
    final raw = await service.loadWeek(scoreboard: scoreboard, lineup: defaultLineup);
    final result = const ScoringCalculator(ScoringSettings.defaults).scoreWeek(raw);
    print('${scoreboard.week.label} (${scoreboard.games.length} games)');
    for (final p in result.players) {
      final g = p.game;
      print('${p.slot.slot.label.padRight(5)} ${p.displayName.padRight(22)} '
          '${(p.team?.abbreviation ?? '-').padRight(4)} vs ${(p.opponent?.abbreviation ?? '-').padRight(4)} '
          '${p.availability.name.padRight(9)} ${(g?.statusDetail ?? '').padRight(24)} '
          '${p.points.toStringAsFixed(2).padLeft(6)}  ${p.injuryStatus ?? ''}');
      for (final l in p.breakdown.lines) {
        print('        ${l.label}: ${l.statDisplay} -> ${l.points}');
      }
    }
    print('TOTAL ${result.totalPoints}');
  } finally {
    api.close();
  }
}
