/// Raw offensive / kicking stats for one player in one game.
class PlayerStats {
  const PlayerStats({
    this.passCompletions = 0,
    this.passAttempts = 0,
    this.passYards = 0,
    this.passTds = 0,
    this.interceptions = 0,
    this.sacksTaken = 0,
    this.rushAttempts = 0,
    this.rushYards = 0,
    this.rushTds = 0,
    this.targets = 0,
    this.receptions = 0,
    this.receivingYards = 0,
    this.receivingTds = 0,
    this.fumbles = 0,
    this.fumblesLost = 0,
    this.twoPointConversions = 0,
    this.returnTds = 0,
    this.fieldGoalsMade = 0,
    this.fieldGoalsAttempted = 0,
    this.fieldGoalDistances = const [],
    this.extraPointsMade = 0,
    this.extraPointsAttempted = 0,
  });

  static const empty = PlayerStats();

  final int passCompletions;
  final int passAttempts;
  final int passYards;
  final int passTds;
  final int interceptions;
  final int sacksTaken;
  final int rushAttempts;
  final int rushYards;
  final int rushTds;
  final int targets;
  final int receptions;
  final int receivingYards;
  final int receivingTds;
  final int fumbles;
  final int fumblesLost;
  final int twoPointConversions;

  /// Kick / punt return touchdowns.
  final int returnTds;
  final int fieldGoalsMade;
  final int fieldGoalsAttempted;

  /// Distances (yards) of made field goals, from the scoring plays. May be
  /// shorter than [fieldGoalsMade] if the play-by-play lags the box score.
  final List<int> fieldGoalDistances;
  final int extraPointsMade;
  final int extraPointsAttempted;

  int get fieldGoalsMissed => fieldGoalsAttempted - fieldGoalsMade;
  int get extraPointsMissed => extraPointsAttempted - extraPointsMade;

  PlayerStats copyWith({
    int? passCompletions,
    int? passAttempts,
    int? passYards,
    int? passTds,
    int? interceptions,
    int? sacksTaken,
    int? rushAttempts,
    int? rushYards,
    int? rushTds,
    int? targets,
    int? receptions,
    int? receivingYards,
    int? receivingTds,
    int? fumbles,
    int? fumblesLost,
    int? twoPointConversions,
    int? returnTds,
    int? fieldGoalsMade,
    int? fieldGoalsAttempted,
    List<int>? fieldGoalDistances,
    int? extraPointsMade,
    int? extraPointsAttempted,
  }) =>
      PlayerStats(
        passCompletions: passCompletions ?? this.passCompletions,
        passAttempts: passAttempts ?? this.passAttempts,
        passYards: passYards ?? this.passYards,
        passTds: passTds ?? this.passTds,
        interceptions: interceptions ?? this.interceptions,
        sacksTaken: sacksTaken ?? this.sacksTaken,
        rushAttempts: rushAttempts ?? this.rushAttempts,
        rushYards: rushYards ?? this.rushYards,
        rushTds: rushTds ?? this.rushTds,
        targets: targets ?? this.targets,
        receptions: receptions ?? this.receptions,
        receivingYards: receivingYards ?? this.receivingYards,
        receivingTds: receivingTds ?? this.receivingTds,
        fumbles: fumbles ?? this.fumbles,
        fumblesLost: fumblesLost ?? this.fumblesLost,
        twoPointConversions: twoPointConversions ?? this.twoPointConversions,
        returnTds: returnTds ?? this.returnTds,
        fieldGoalsMade: fieldGoalsMade ?? this.fieldGoalsMade,
        fieldGoalsAttempted: fieldGoalsAttempted ?? this.fieldGoalsAttempted,
        fieldGoalDistances: fieldGoalDistances ?? this.fieldGoalDistances,
        extraPointsMade: extraPointsMade ?? this.extraPointsMade,
        extraPointsAttempted: extraPointsAttempted ?? this.extraPointsAttempted,
      );
}

/// Team defense / special teams stats for one game.
class DefenseStats {
  const DefenseStats({
    this.sacks = 0,
    this.interceptions = 0,
    this.fumbleRecoveries = 0,
    this.touchdowns = 0,
    this.safeties = 0,
    this.pointsAllowed = 0,
  });

  final double sacks;
  final int interceptions;
  final int fumbleRecoveries;

  /// Defensive and special teams return touchdowns.
  final int touchdowns;
  final int safeties;
  final int pointsAllowed;

  DefenseStats copyWith({int? pointsAllowed}) => DefenseStats(
        sacks: sacks,
        interceptions: interceptions,
        fumbleRecoveries: fumbleRecoveries,
        touchdowns: touchdowns,
        safeties: safeties,
        pointsAllowed: pointsAllowed ?? this.pointsAllowed,
      );
}
