/// A points-allowed bracket for D/ST scoring: applies when points allowed is
/// <= [maxPointsAllowed] (and above the previous tier). The last tier should
/// have a null max, meaning "and up".
class PointsAllowedTier {
  const PointsAllowedTier({required this.maxPointsAllowed, required this.points});

  final int? maxPointsAllowed;
  final double points;

  PointsAllowedTier copyWith({double? points}) =>
      PointsAllowedTier(maxPointsAllowed: maxPointsAllowed, points: points ?? this.points);

  Map<String, dynamic> toJson() => {'max': maxPointsAllowed, 'points': points};

  factory PointsAllowedTier.fromJson(Map<String, dynamic> json) => PointsAllowedTier(
        maxPointsAllowed: json['max'] as int?,
        points: (json['points'] as num).toDouble(),
      );
}

/// Fantasy scoring rules. Defaults are standard PPR.
class ScoringSettings {
  const ScoringSettings({
    this.passYardsPerPoint = 25,
    this.passTd = 4,
    this.interception = -2,
    this.rushYardsPerPoint = 10,
    this.rushTd = 6,
    this.receivingYardsPerPoint = 10,
    this.receivingTd = 6,
    this.reception = 1,
    this.fumbleLost = -2,
    this.twoPointConversion = 2,
    this.returnTd = 6,
    this.fractionalYardage = false,
    this.fgUnder40 = 3,
    this.fg40to49 = 4,
    this.fg50Plus = 5,
    this.fgMissed = -1,
    this.extraPoint = 1,
    this.extraPointMissed = 0,
    this.dstSack = 1,
    this.dstInterception = 2,
    this.dstFumbleRecovery = 2,
    this.dstTouchdown = 6,
    this.dstSafety = 2,
    this.pointsAllowedTiers = defaultPointsAllowedTiers,
  });

  static const defaults = ScoringSettings();

  static const defaultPointsAllowedTiers = [
    PointsAllowedTier(maxPointsAllowed: 0, points: 5),
    PointsAllowedTier(maxPointsAllowed: 6, points: 4),
    PointsAllowedTier(maxPointsAllowed: 13, points: 3),
    PointsAllowedTier(maxPointsAllowed: 17, points: 1),
    PointsAllowedTier(maxPointsAllowed: 27, points: 0),
    PointsAllowedTier(maxPointsAllowed: 34, points: -1),
    PointsAllowedTier(maxPointsAllowed: 45, points: -3),
    PointsAllowedTier(maxPointsAllowed: null, points: -5),
  ];

  // Offense
  final double passYardsPerPoint;
  final double passTd;
  final double interception;
  final double rushYardsPerPoint;
  final double rushTd;
  final double receivingYardsPerPoint;
  final double receivingTd;
  final double reception;
  final double fumbleLost;
  final double twoPointConversion;
  final double returnTd;

  /// When false (standard), yardage only scores whole points: 59 rushing
  /// yards = 5 pts. When true, 59 rushing yards = 5.9 pts.
  final bool fractionalYardage;

  // Kicking
  final double fgUnder40;
  final double fg40to49;
  final double fg50Plus;
  final double fgMissed;
  final double extraPoint;
  final double extraPointMissed;

  // Defense / special teams
  final double dstSack;
  final double dstInterception;
  final double dstFumbleRecovery;
  final double dstTouchdown;
  final double dstSafety;
  final List<PointsAllowedTier> pointsAllowedTiers;

  ScoringSettings copyWith({
    double? passYardsPerPoint,
    double? passTd,
    double? interception,
    double? rushYardsPerPoint,
    double? rushTd,
    double? receivingYardsPerPoint,
    double? receivingTd,
    double? reception,
    double? fumbleLost,
    double? twoPointConversion,
    double? returnTd,
    bool? fractionalYardage,
    double? fgUnder40,
    double? fg40to49,
    double? fg50Plus,
    double? fgMissed,
    double? extraPoint,
    double? extraPointMissed,
    double? dstSack,
    double? dstInterception,
    double? dstFumbleRecovery,
    double? dstTouchdown,
    double? dstSafety,
    List<PointsAllowedTier>? pointsAllowedTiers,
  }) =>
      ScoringSettings(
        passYardsPerPoint: passYardsPerPoint ?? this.passYardsPerPoint,
        passTd: passTd ?? this.passTd,
        interception: interception ?? this.interception,
        rushYardsPerPoint: rushYardsPerPoint ?? this.rushYardsPerPoint,
        rushTd: rushTd ?? this.rushTd,
        receivingYardsPerPoint: receivingYardsPerPoint ?? this.receivingYardsPerPoint,
        receivingTd: receivingTd ?? this.receivingTd,
        reception: reception ?? this.reception,
        fumbleLost: fumbleLost ?? this.fumbleLost,
        twoPointConversion: twoPointConversion ?? this.twoPointConversion,
        returnTd: returnTd ?? this.returnTd,
        fractionalYardage: fractionalYardage ?? this.fractionalYardage,
        fgUnder40: fgUnder40 ?? this.fgUnder40,
        fg40to49: fg40to49 ?? this.fg40to49,
        fg50Plus: fg50Plus ?? this.fg50Plus,
        fgMissed: fgMissed ?? this.fgMissed,
        extraPoint: extraPoint ?? this.extraPoint,
        extraPointMissed: extraPointMissed ?? this.extraPointMissed,
        dstSack: dstSack ?? this.dstSack,
        dstInterception: dstInterception ?? this.dstInterception,
        dstFumbleRecovery: dstFumbleRecovery ?? this.dstFumbleRecovery,
        dstTouchdown: dstTouchdown ?? this.dstTouchdown,
        dstSafety: dstSafety ?? this.dstSafety,
        pointsAllowedTiers: pointsAllowedTiers ?? this.pointsAllowedTiers,
      );

  Map<String, dynamic> toJson() => {
        'passYardsPerPoint': passYardsPerPoint,
        'passTd': passTd,
        'interception': interception,
        'rushYardsPerPoint': rushYardsPerPoint,
        'rushTd': rushTd,
        'receivingYardsPerPoint': receivingYardsPerPoint,
        'receivingTd': receivingTd,
        'reception': reception,
        'fumbleLost': fumbleLost,
        'twoPointConversion': twoPointConversion,
        'returnTd': returnTd,
        'fractionalYardage': fractionalYardage,
        'fgUnder40': fgUnder40,
        'fg40to49': fg40to49,
        'fg50Plus': fg50Plus,
        'fgMissed': fgMissed,
        'extraPoint': extraPoint,
        'extraPointMissed': extraPointMissed,
        'dstSack': dstSack,
        'dstInterception': dstInterception,
        'dstFumbleRecovery': dstFumbleRecovery,
        'dstTouchdown': dstTouchdown,
        'dstSafety': dstSafety,
        'pointsAllowedTiers': pointsAllowedTiers.map((t) => t.toJson()).toList(),
      };

  /// Missing keys fall back to defaults, so older saved settings keep working
  /// when new options are added.
  factory ScoringSettings.fromJson(Map<String, dynamic> json) {
    const d = defaults;
    double n(String key, double fallback) => (json[key] as num?)?.toDouble() ?? fallback;
    final tiers = json['pointsAllowedTiers'] as List<dynamic>?;
    return ScoringSettings(
      passYardsPerPoint: n('passYardsPerPoint', d.passYardsPerPoint),
      passTd: n('passTd', d.passTd),
      interception: n('interception', d.interception),
      rushYardsPerPoint: n('rushYardsPerPoint', d.rushYardsPerPoint),
      rushTd: n('rushTd', d.rushTd),
      receivingYardsPerPoint: n('receivingYardsPerPoint', d.receivingYardsPerPoint),
      receivingTd: n('receivingTd', d.receivingTd),
      reception: n('reception', d.reception),
      fumbleLost: n('fumbleLost', d.fumbleLost),
      twoPointConversion: n('twoPointConversion', d.twoPointConversion),
      returnTd: n('returnTd', d.returnTd),
      fractionalYardage: json['fractionalYardage'] as bool? ?? d.fractionalYardage,
      fgUnder40: n('fgUnder40', d.fgUnder40),
      fg40to49: n('fg40to49', d.fg40to49),
      fg50Plus: n('fg50Plus', d.fg50Plus),
      fgMissed: n('fgMissed', d.fgMissed),
      extraPoint: n('extraPoint', d.extraPoint),
      extraPointMissed: n('extraPointMissed', d.extraPointMissed),
      dstSack: n('dstSack', d.dstSack),
      dstInterception: n('dstInterception', d.dstInterception),
      dstFumbleRecovery: n('dstFumbleRecovery', d.dstFumbleRecovery),
      dstTouchdown: n('dstTouchdown', d.dstTouchdown),
      dstSafety: n('dstSafety', d.dstSafety),
      pointsAllowedTiers: tiers == null
          ? d.pointsAllowedTiers
          : tiers.map((t) => PointsAllowedTier.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}
