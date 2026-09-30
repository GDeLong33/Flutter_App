enum GameState { upcoming, live, finished }

class TeamInfo {
  const TeamInfo({
    required this.id,
    required this.abbreviation,
    required this.displayName,
    this.shortName,
    this.logoUrl,
  });

  final String id;
  final String abbreviation;
  final String displayName;
  final String? shortName;
  final String? logoUrl;

  /// True if [query] names this team: "Baltimore Ravens", "Ravens", "BAL".
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q == displayName.toLowerCase() ||
        q == abbreviation.toLowerCase() ||
        (shortName != null && q == shortName!.toLowerCase());
  }
}

class GameTeam {
  const GameTeam({required this.team, required this.score, required this.isHome});

  final TeamInfo team;
  final int score;
  final bool isHome;
}

/// A single NFL game from the scoreboard.
class NflGame {
  const NflGame({
    required this.id,
    required this.kickoff,
    required this.state,
    required this.statusName,
    required this.statusDetail,
    required this.period,
    required this.displayClock,
    required this.home,
    required this.away,
  });

  final String id;
  final DateTime kickoff;
  final GameState state;

  /// ESPN status name, e.g. STATUS_SCHEDULED, STATUS_HALFTIME, STATUS_FINAL,
  /// STATUS_POSTPONED.
  final String statusName;

  /// Human readable status, e.g. "10:23 - 2nd", "Halftime", "Final/OT".
  final String statusDetail;
  final int period;
  final String displayClock;
  final GameTeam home;
  final GameTeam away;

  bool involves(String teamId) => home.team.id == teamId || away.team.id == teamId;

  GameTeam sideFor(String teamId) => home.team.id == teamId ? home : away;
  GameTeam opponentOf(String teamId) => home.team.id == teamId ? away : home;

  /// True once a box score may contain player stats.
  bool get hasStarted => state != GameState.upcoming;
}

/// A selectable week, e.g. regular season week 3.
class WeekRef {
  const WeekRef({
    required this.year,
    required this.seasonType,
    required this.week,
    required this.label,
  });

  final int year;

  /// ESPN season type: 1 = preseason, 2 = regular season, 3 = postseason.
  final int seasonType;
  final int week;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is WeekRef &&
      other.year == year &&
      other.seasonType == seasonType &&
      other.week == week;

  @override
  int get hashCode => Object.hash(year, seasonType, week);

  @override
  String toString() => '$year/$seasonType/$week';
}

/// One week's scoreboard.
class Scoreboard {
  const Scoreboard({
    required this.week,
    required this.games,
    required this.teamsOnBye,
    required this.calendar,
  });

  final WeekRef week;
  final List<NflGame> games;
  final List<TeamInfo> teamsOnBye;

  /// All regular season and postseason weeks of this season.
  final List<WeekRef> calendar;

  NflGame? gameForTeam(String teamId) {
    for (final g in games) {
      if (g.involves(teamId)) return g;
    }
    return null;
  }

  /// Finds a team playing (or on bye) this week by name or abbreviation.
  TeamInfo? findTeam(String query) {
    for (final g in games) {
      if (g.home.team.matches(query)) return g.home.team;
      if (g.away.team.matches(query)) return g.away.team;
    }
    for (final t in teamsOnBye) {
      if (t.matches(query)) return t;
    }
    return null;
  }
}
