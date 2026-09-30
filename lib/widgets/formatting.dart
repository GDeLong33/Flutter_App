import 'package:intl/intl.dart';

import '../models/game.dart';
import '../models/player_result.dart';

/// Shared display helpers.
class Fmt {
  /// 12 -> "12.0", 12.5 -> "12.5", 12.34 -> "12.34".
  static String points(double p) {
    final s = p.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  static String signedPoints(double p) => p > 0 ? '+${points(p)}' : points(p);

  static String kickoff(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? 'Today ${DateFormat.jm().format(t)}' : DateFormat('EEE M/d · h:mm a').format(t);
  }

  static String lastUpdated(DateTime t) => DateFormat('h:mm:ss a').format(t);

  /// "vs DAL" or "@ DAL".
  static String matchup(PlayerResult p) {
    if (p.opponent == null) return '';
    return '${p.isHome == true ? 'vs' : '@'} ${p.opponent!.abbreviation}';
  }

  /// Short game status for a card: kickoff time, live clock, or final score.
  static String gameStatus(PlayerResult p) {
    final g = p.game;
    switch (p.availability) {
      case PlayerAvailability.bye:
        return 'BYE';
      case PlayerAvailability.notFound:
        return 'Not found on ESPN';
      default:
        break;
    }
    if (g == null) return '';
    switch (g.state) {
      case GameState.upcoming:
        if (g.statusName == 'STATUS_POSTPONED' || g.statusName == 'STATUS_CANCELED') {
          return g.statusDetail;
        }
        return Fmt.kickoff(g.kickoff);
      case GameState.live:
        return g.statusDetail.isNotEmpty ? g.statusDetail : 'Q${g.period} ${g.displayClock}';
      case GameState.finished:
        final team = p.team;
        if (team == null) return g.statusDetail;
        final us = g.sideFor(team.id).score;
        final them = g.opponentOf(team.id).score;
        final wl = us > them ? 'W' : (us < them ? 'L' : 'T');
        final label = g.statusDetail.isEmpty ? 'Final' : g.statusDetail;
        return '$label · $wl $us-$them';
    }
  }

  static String liveScore(PlayerResult p) {
    final g = p.game;
    final team = p.team;
    if (g == null || team == null || g.state != GameState.live) return '';
    return '${g.sideFor(team.id).score}-${g.opponentOf(team.id).score}';
  }
}
