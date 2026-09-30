import 'player_stats.dart';

class BoxScorePlayer {
  const BoxScorePlayer({
    required this.id,
    required this.name,
    required this.teamId,
    required this.stats,
  });

  final String id;
  final String name;
  final String teamId;
  final PlayerStats stats;
}

/// Parsed player and D/ST stats for one game.
class BoxScore {
  const BoxScore({
    required this.gameId,
    required this.players,
    required this.defenseByTeamId,
  });

  final String gameId;
  final List<BoxScorePlayer> players;
  final Map<String, DefenseStats> defenseByTeamId;

  bool get hasPlayerStats => players.isNotEmpty;
}
