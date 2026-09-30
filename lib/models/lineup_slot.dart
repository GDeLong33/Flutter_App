/// Fantasy lineup positions. [flex] can hold an RB, WR or TE.
enum SlotType {
  qb('QB'),
  rb('RB'),
  wr('WR'),
  te('TE'),
  flex('FLEX'),
  k('K'),
  dst('D/ST');

  const SlotType(this.label);
  final String label;

  static SlotType fromLabel(String label) =>
      SlotType.values.firstWhere((s) => s.label == label);

  /// Player positions that may fill this slot (ESPN position abbreviations).
  List<String> get eligiblePositions => switch (this) {
        SlotType.qb => const ['QB'],
        SlotType.rb => const ['RB'],
        SlotType.wr => const ['WR'],
        SlotType.te => const ['TE'],
        SlotType.flex => const ['RB', 'WR', 'TE'],
        SlotType.k => const ['K'],
        SlotType.dst => const ['D/ST'],
      };
}

/// One starter in the lineup. For [SlotType.dst], [name] is the team name
/// (e.g. "Baltimore Ravens").
class LineupSlot {
  const LineupSlot({
    required this.slot,
    required this.name,
    this.position,
  });

  final SlotType slot;
  final String name;

  /// The player's real position. Only needed for FLEX, where it narrows the
  /// ESPN search (e.g. "RB"). Defaults to the slot's single position.
  final String? position;

  bool get isDefense => slot == SlotType.dst;

  String get effectivePosition => position ?? slot.eligiblePositions.first;

  LineupSlot copyWith({String? name, String? position}) => LineupSlot(
        slot: slot,
        name: name ?? this.name,
        position: position ?? this.position,
      );

  Map<String, dynamic> toJson() => {
        'slot': slot.label,
        'name': name,
        if (position != null) 'position': position,
      };

  factory LineupSlot.fromJson(Map<String, dynamic> json) => LineupSlot(
        slot: SlotType.fromLabel(json['slot'] as String),
        name: json['name'] as String,
        position: json['position'] as String?,
      );
}
