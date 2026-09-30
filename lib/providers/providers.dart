import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/lineup_config.dart';
import '../models/game.dart';
import '../models/lineup_slot.dart';
import '../models/player_result.dart';
import '../models/scoring_settings.dart';
import '../services/espn_api_client.dart';
import '../services/lineup_tracker_service.dart';
import '../services/local_storage.dart';
import '../services/polling_policy.dart';
import '../services/scoring_calculator.dart';

// ------------------------------------------------------------ infrastructure

/// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final localStorageProvider =
    Provider<LocalStorage>((ref) => LocalStorage(ref.watch(sharedPreferencesProvider)));

final espnApiClientProvider = Provider<EspnApiClient>((ref) {
  final client = EspnApiClient();
  ref.onDispose(client.close);
  return client;
});

final trackerServiceProvider =
    Provider<LineupTrackerService>((ref) => LineupTrackerService(ref.watch(espnApiClientProvider)));

// ------------------------------------------------------------------ settings

final scoringSettingsProvider =
    NotifierProvider<ScoringSettingsNotifier, ScoringSettings>(ScoringSettingsNotifier.new);

class ScoringSettingsNotifier extends Notifier<ScoringSettings> {
  @override
  ScoringSettings build() => ref.read(localStorageProvider).loadSettings();

  Future<void> update(ScoringSettings settings) async {
    state = settings;
    await ref.read(localStorageProvider).saveSettings(settings);
  }

  Future<void> reset() => update(ScoringSettings.defaults);
}

// -------------------------------------------------------------------- lineup

final lineupProvider = NotifierProvider<LineupNotifier, List<LineupSlot>>(LineupNotifier.new);

class LineupNotifier extends Notifier<List<LineupSlot>> {
  @override
  List<LineupSlot> build() => ref.read(localStorageProvider).loadLineup() ?? defaultLineup;

  Future<void> replace(int index, LineupSlot slot) async {
    state = [...state]..[index] = slot;
    await ref.read(localStorageProvider).saveLineup(state);
  }

  Future<void> resetToDefault() async {
    state = defaultLineup;
    await ref.read(localStorageProvider).clearLineup();
  }
}

// --------------------------------------------------------------------- weeks

/// The current week plus the season's week list, from the default scoreboard.
final seasonCalendarProvider = FutureProvider<({WeekRef current, List<WeekRef> weeks})>((ref) async {
  final sb = await ref.watch(trackerServiceProvider).fetchScoreboard();
  final weeks = sb.calendar.isEmpty ? [sb.week] : sb.calendar;
  return (current: sb.week, weeks: weeks);
});

/// The week the user picked; null means "current week".
final selectedWeekProvider = NotifierProvider<SelectedWeekNotifier, WeekRef?>(SelectedWeekNotifier.new);

class SelectedWeekNotifier extends Notifier<WeekRef?> {
  @override
  WeekRef? build() => null;

  void select(WeekRef? week) => state = week;
}

/// The week actually being displayed.
final activeWeekProvider = FutureProvider<WeekRef>((ref) async {
  final selected = ref.watch(selectedWeekProvider);
  if (selected != null) return selected;
  return (await ref.watch(seasonCalendarProvider.future)).current;
});

// ------------------------------------------------------------------- results

/// Raw (unscored) lineup results for the active week, with adaptive polling.
final lineupWeekProvider =
    AsyncNotifierProvider<LineupWeekNotifier, LineupWeekResult>(LineupWeekNotifier.new);

class LineupWeekNotifier extends AsyncNotifier<LineupWeekResult> {
  Timer? _timer;

  @override
  Future<LineupWeekResult> build() async {
    ref.onDispose(() => _timer?.cancel());
    final week = await ref.watch(activeWeekProvider.future);
    final lineup = ref.watch(lineupProvider);
    final result = await _load(week, lineup);
    _schedule(result);
    return result;
  }

  Future<LineupWeekResult> _load(WeekRef week, List<LineupSlot> lineup) async {
    final service = ref.read(trackerServiceProvider);
    final scoreboard = await service.fetchScoreboard(week);
    return service.loadWeek(scoreboard: scoreboard, lineup: lineup);
  }

  /// Pull-to-refresh / retry / timer tick. Keeps showing old data if the
  /// refresh fails and surfaces the error as a banner instead.
  Future<void> refresh() async {
    _timer?.cancel();
    final previous = state.value;
    if (previous == null) {
      // Nothing on screen yet (e.g. the initial load failed): full reload.
      ref.invalidateSelf();
      try {
        await future;
      } on Object {
        // The error is exposed through `state`.
      }
      return;
    }
    try {
      final week = await ref.read(activeWeekProvider.future);
      final result = await _load(week, ref.read(lineupProvider));
      if (!ref.mounted) return;
      state = AsyncData(result);
      _schedule(result);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(previous.copyWith(refreshError: e));
      _schedule(previous, afterError: true);
    }
  }

  void _schedule(LineupWeekResult result, {bool afterError = false}) {
    _timer?.cancel();
    final delay = PollingPolicy.nextDelay(result.games, DateTime.now(), afterError: afterError);
    if (delay != null) _timer = Timer(delay, refresh);
  }
}

/// Lineup results with fantasy points applied. Recomputed instantly when
/// scoring settings change, without refetching.
final scoredWeekProvider = Provider<AsyncValue<LineupWeekResult>>((ref) {
  final calc = ScoringCalculator(ref.watch(scoringSettingsProvider));
  return ref.watch(lineupWeekProvider).whenData(calc.scoreWeek);
});

/// When the next automatic refresh will happen; used for the status line.
final pollingDescriptionProvider = Provider<String?>((ref) {
  final result = ref.watch(lineupWeekProvider).value;
  if (result == null) return null;
  return PollingPolicy.describe(result.games, DateTime.now());
});

/// Teams list for the D/ST picker.
final teamsProvider = FutureProvider<List<TeamInfo>>((ref) => ref.watch(trackerServiceProvider).fetchTeams());
