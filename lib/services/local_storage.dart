import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/lineup_slot.dart';
import '../models/scoring_settings.dart';

/// Persists scoring settings and lineup edits on the device.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _settingsKey = 'scoring_settings_v1';
  static const _lineupKey = 'lineup_v1';

  ScoringSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return ScoringSettings.defaults;
    try {
      return ScoringSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return ScoringSettings.defaults; // Corrupt data: fall back, don't crash.
    }
  }

  Future<void> saveSettings(ScoringSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  /// Returns null when the user hasn't edited the lineup.
  List<LineupSlot>? loadLineup() {
    final raw = _prefs.getString(_lineupKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => LineupSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return null;
    }
  }

  Future<void> saveLineup(List<LineupSlot> lineup) =>
      _prefs.setString(_lineupKey, jsonEncode(lineup.map((s) => s.toJson()).toList()));

  Future<void> clearLineup() => _prefs.remove(_lineupKey);
}
