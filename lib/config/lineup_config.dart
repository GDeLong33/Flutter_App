import '../models/lineup_slot.dart';

/// The default starting lineup. Edit this list to change the players the app
/// starts with; changes made in the in-app "Edit lineup" screen are saved on
/// the device and take precedence (use "Reset to default" there to return to
/// this list).
///
/// Only names are stored. Teams are looked up from ESPN at runtime so trades
/// are picked up automatically.
const List<LineupSlot> defaultLineup = [
  LineupSlot(slot: SlotType.qb, name: 'Bryce Young'),
  LineupSlot(slot: SlotType.rb, name: 'Christian McCaffrey'),
  LineupSlot(slot: SlotType.rb, name: 'James Cook'),
  LineupSlot(slot: SlotType.wr, name: 'Devonta Smith'),
  LineupSlot(slot: SlotType.wr, name: 'Josh Downs'),
  LineupSlot(slot: SlotType.te, name: 'Juwan Johnson'),
  LineupSlot(slot: SlotType.flex, name: 'David Montgomery', position: 'RB'),
  LineupSlot(slot: SlotType.k, name: 'Spencer Shrader'),
  LineupSlot(slot: SlotType.dst, name: 'Baltimore Ravens'),
];
