import '../models/game.dart';

/// Decides how often to refresh, based on the state of the lineup's games.
///
/// - Any game live → every 30 s.
/// - A game kicks off within 15 min (or is past kickoff but not yet marked
///   live, e.g. a delay) → every 60 s.
/// - Games later → wake up shortly before the next kickoff (max 30 min, so
///   schedule changes are picked up).
/// - Everything final / on bye → stop.
class PollingPolicy {
  static const live = Duration(seconds: 30);
  static const nearKickoff = Duration(seconds: 60);
  static const maxIdle = Duration(minutes: 30);
  static const _kickoffWindow = Duration(minutes: 15);

  static Duration? nextDelay(Iterable<NflGame> games, DateTime now, {bool afterError = false}) {
    final list = games.toList();
    if (list.any((g) => g.state == GameState.live)) {
      // Back off a little after a failed refresh so we don't hammer ESPN.
      return afterError ? nearKickoff : live;
    }
    final upcoming = list.where((g) => g.state == GameState.upcoming).toList();
    if (upcoming.isEmpty) return null;

    final nextKickoff = upcoming.map((g) => g.kickoff).reduce((a, b) => a.isBefore(b) ? a : b);
    final untilKickoff = nextKickoff.difference(now);
    if (untilKickoff <= _kickoffWindow) return nearKickoff;
    final wake = untilKickoff - _kickoffWindow;
    return wake < maxIdle ? wake : maxIdle;
  }

  static String? describe(Iterable<NflGame> games, DateTime now) {
    final delay = nextDelay(games, now);
    if (delay == null) return 'All games final · auto-refresh off';
    if (delay == live) return 'Live · refreshing every 30s';
    if (delay == nearKickoff) return 'Kickoff soon · refreshing every minute';
    return 'Auto-refresh before kickoff';
  }
}
