# Lineup Tracker

A Flutter app that tracks how your fantasy football starting lineup is scoring during the current NFL week. It uses live data from ESPN's public JSON endpoints.

- Lineup cards with the matchup, game status (kickoff time, live clock or final score) and fantasy points, under a big total
- Player detail screen: the full stat line and how each stat converts to points
- Auto-refresh every 30s while any of your games are live. It checks every minute near kickoff and stops once everything is final. You can also pull to refresh, and the header shows when it last updated
- Week picker for looking back at past weeks
- Configurable scoring (standard PPR by default), saved on the device
- Edit-lineup screen with ESPN player search

## Setup

Requires the Flutter SDK (tested with Flutter 3.47 / Dart 3.13). You don't need an API key.

```sh
flutter pub get
flutter run                 # choose a connected device / emulator
flutter run -d chrome       # or run it in the browser (use -d edge if Chrome isn't installed)
```

On Windows, building the **Windows desktop** target requires Developer Mode (`start ms-settings:developers`) because plugins use symlinks. Android, iOS and web builds don't need it.

## Tests and checks

```sh
flutter analyze
flutter test                          # scoring calculator, ESPN parsers, polling, widgets
dart run tool/smoke_test.dart         # live ESPN check of your lineup, current week
dart run tool/smoke_test.dart 2 3     # ... a specific week (season type 2 = regular season, week 3)
```

The parser tests run against real ESPN responses saved in `test/fixtures/`.

## Changing your lineup

- **In the app:** open ⋮ → *Edit lineup*, tap a slot, and search for the replacement player. Your edits are saved on the device.
- **In code:** edit [`lib/config/lineup_config.dart`](lib/config/lineup_config.dart). This is the default lineup, and *Reset to default* in the app returns to it.

Only names are stored. Each player's team is looked up on ESPN at runtime, so traded players are handled automatically. For FLEX, set `position` (e.g. `'RB'`) so a same-named player at another position isn't matched.

## How it works

```
lib/
  config/     default lineup
  models/     lineup slots, games, stats, scoring settings, results
  services/   espn_api_client  HTTP calls
              espn_parsers     JSON → models (defensive, no crashes on missing fields)
              lineup_tracker_service  matches players to box scores
              scoring_calculator      stats → points + breakdown
              polling_policy          refresh schedule
              local_storage           shared_preferences persistence
  providers/  Riverpod providers (settings, lineup, week, results + polling)
  screens/    lineup (home), player detail, settings, edit lineup
  widgets/    cards, header, skeletons, week selector
```

**Data sources** (unofficial ESPN endpoints, so they could change without notice):

| Endpoint | Used for |
|---|---|
| `site.api.espn.com/.../nfl/scoreboard?seasontype=&week=&dates=` | games, status, scores, byes, the season's week list |
| `site.api.espn.com/.../nfl/summary?event={id}` | box score player stats and scoring plays |
| `site.web.api.espn.com/apis/common/v3/search?type=player` | resolving a name to an ESPN id, current team and position |
| `site.web.api.espn.com/apis/common/v3/sports/football/nfl/athletes/{id}` | injury / roster status |

**Player matching:** each name is resolved through ESPN search, filtered by position. This deals with names like "Devonta Smith", which matches both a WR and a CB, and "James Cook", who is listed as "James Cook III". The app then looks for that player in their current team's box score, matching by ESPN id and then by name. If the player isn't there, it scans that week's other finished box scores, which covers players who were traded after that week. When there's still no match, the card shows **BYE** (no game), the kickoff time (not started) or **Did not play / No stats yet**.

**Scoring notes:**
- Yardage scores whole points by default (59 rush yds = 5 pts). Turn on *Decimal yardage points* to get 5.9 instead.
- Field-goal distances are read from ESPN's scoring-play text. If a made FG's distance isn't available yet, it's scored as 0–39 yds.
- 2-pt conversions also come from the scoring-play text.
- D/ST points allowed is the opponent's final score, including points scored against the offense (e.g. pick-sixes).
- D/ST touchdowns count interception, fumble, kick and punt return TDs.
- Blocked kicks aren't available from these endpoints, so they aren't scored.

**ESPN's "current week":** ESPN switches its default week to the next one partway through the week, usually Tuesday or Wednesday. Until then the app opens on the week that just finished. Use the week picker to jump ahead.
