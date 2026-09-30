import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/box_score.dart';
import '../models/game.dart';
import 'espn_parsers.dart';

class EspnApiException implements Exception {
  EspnApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin HTTP wrapper around ESPN's public (unofficial) NFL JSON endpoints.
class EspnApiClient {
  EspnApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _site = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl';
  static const _common = 'https://site.web.api.espn.com/apis/common/v3';
  static const _timeout = Duration(seconds: 15);

  /// The scoreboard for [week], or the current week when null.
  Future<Scoreboard> fetchScoreboard([WeekRef? week]) async {
    final uri = Uri.parse('$_site/scoreboard').replace(
      queryParameters: week == null
          ? null
          : {
              'seasontype': '${week.seasonType}',
              'week': '${week.week}',
              'dates': '${week.year}',
            },
    );
    return EspnParsers.parseScoreboard(await _get(uri));
  }

  Future<BoxScore> fetchBoxScore(String eventId) async {
    final uri = Uri.parse('$_site/summary').replace(queryParameters: {'event': eventId});
    return EspnParsers.parseSummary(eventId, await _get(uri));
  }

  Future<List<PlayerSearchResult>> searchPlayers(String query, {int limit = 10}) async {
    final uri = Uri.parse('$_common/search').replace(queryParameters: {
      'query': query,
      'limit': '$limit',
      'type': 'player',
      'sport': 'football',
      'league': 'nfl',
    });
    return EspnParsers.parsePlayerSearch(await _get(uri));
  }

  /// Roster / injury status for a player, e.g. "Injured Reserve". Null when
  /// active and healthy.
  Future<String?> fetchAthleteStatus(String athleteId) async {
    final uri = Uri.parse('$_common/sports/football/nfl/athletes/$athleteId');
    return EspnParsers.parseAthleteStatus(await _get(uri));
  }

  Future<List<TeamInfo>> fetchTeams() async {
    return EspnParsers.parseTeams(await _get(Uri.parse('$_site/teams')));
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(_timeout);
    } on Exception catch (e) {
      throw EspnApiException('Could not reach ESPN. Check your connection. ($e)');
    }
    if (res.statusCode != 200) {
      throw EspnApiException('ESPN returned HTTP ${res.statusCode}', statusCode: res.statusCode);
    }
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through.
    }
    throw EspnApiException('ESPN returned an unexpected response');
  }

  void close() => _client.close();
}
