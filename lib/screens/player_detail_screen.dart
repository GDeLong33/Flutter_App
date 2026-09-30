import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../models/player_result.dart';
import '../models/player_stats.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/formatting.dart';

/// Full stat line and scoring breakdown for one lineup slot. Watches the
/// same provider as the home screen, so it updates live too.
class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({super.key, required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(scoredWeekProvider).value;
    final player = result != null && slotIndex < result.players.length ? result.players[slotIndex] : null;

    return Scaffold(
      appBar: AppBar(title: Text(player?.slot.slot.label ?? '')),
      body: player == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.live,
              onRefresh: ref.read(lineupWeekProvider.notifier).refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _Header(player: player),
                  const SizedBox(height: 20),
                  ..._body(player),
                ],
              ),
            ),
    );
  }

  List<Widget> _body(PlayerResult p) {
    final message = switch (p.availability) {
      PlayerAvailability.bye => '${p.team?.displayName ?? 'Team'} is on bye this week.',
      PlayerAvailability.notFound =>
        "Couldn't find \"${p.slot.name}\" on ESPN. Check the spelling in Edit lineup.",
      PlayerAvailability.upcoming => 'Game hasn\'t started yet. Kickoff ${Fmt.kickoff(p.game!.kickoff)}.',
      PlayerAvailability.noStats => p.gameState == GameState.finished
          ? 'No stats recorded. The player was likely inactive.'
          : 'No stats recorded yet in this game.',
      PlayerAvailability.playing => null,
    };
    if (message != null && p.defenseStats == null) {
      return [_Message(message)];
    }

    return [
      if (p.stats != null) ..._statSections(p.stats!),
      if (p.defenseStats != null) _defenseSection(p.defenseStats!),
      const SizedBox(height: 8),
      _BreakdownTable(player: p),
    ];
  }

  List<Widget> _statSections(PlayerStats s) {
    final sections = <Widget>[];
    if (s.passAttempts > 0) {
      sections.add(_StatSection('Passing', [
        ('C/ATT', '${s.passCompletions}/${s.passAttempts}'),
        ('YDS', '${s.passYards}'),
        ('TD', '${s.passTds}'),
        ('INT', '${s.interceptions}'),
        ('SACKED', '${s.sacksTaken}'),
      ]));
    }
    if (s.rushAttempts > 0 || s.rushYards != 0) {
      sections.add(_StatSection('Rushing', [
        ('CAR', '${s.rushAttempts}'),
        ('YDS', '${s.rushYards}'),
        ('AVG', s.rushAttempts == 0 ? '-' : (s.rushYards / s.rushAttempts).toStringAsFixed(1)),
        ('TD', '${s.rushTds}'),
      ]));
    }
    if (s.targets > 0 || s.receptions > 0) {
      sections.add(_StatSection('Receiving', [
        ('REC', '${s.receptions}'),
        ('TGT', '${s.targets}'),
        ('YDS', '${s.receivingYards}'),
        ('TD', '${s.receivingTds}'),
      ]));
    }
    if (s.fieldGoalsAttempted > 0 || s.extraPointsAttempted > 0) {
      sections.add(_StatSection('Kicking', [
        ('FG', '${s.fieldGoalsMade}/${s.fieldGoalsAttempted}'),
        ('XP', '${s.extraPointsMade}/${s.extraPointsAttempted}'),
        if (s.fieldGoalDistances.isNotEmpty) ('DIST', s.fieldGoalDistances.join(', ')),
      ]));
    }
    if (s.fumbles > 0 || s.twoPointConversions > 0 || s.returnTds > 0) {
      sections.add(_StatSection('Other', [
        ('FUM', '${s.fumbles}'),
        ('LOST', '${s.fumblesLost}'),
        ('2PT', '${s.twoPointConversions}'),
        ('RET TD', '${s.returnTds}'),
      ]));
    }
    if (sections.isEmpty) sections.add(const _Message('No offensive stats recorded.'));
    return sections;
  }

  Widget _defenseSection(DefenseStats d) => _StatSection('Defense / Special Teams', [
        ('SACK', d.sacks == d.sacks.roundToDouble() ? '${d.sacks.toInt()}' : '${d.sacks}'),
        ('INT', '${d.interceptions}'),
        ('FR', '${d.fumbleRecoveries}'),
        ('TD', '${d.touchdowns}'),
        ('SAF', '${d.safeties}'),
        ('PA', '${d.pointsAllowed}'),
      ]);
}

class _Header extends StatelessWidget {
  const _Header({required this.player});

  final PlayerResult player;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final g = p.game;
    final accent = AppColors.forState(p.gameState);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Avatar(name: p.displayName, url: p.headshotUrl, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  [
                    p.position ?? '',
                    if (p.team != null) p.team!.displayName,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if (p.injuryStatus != null) ...[
                  const SizedBox(height: 4),
                  Pill(text: p.injuryStatus!.toUpperCase(), color: AppColors.danger),
                ],
                const SizedBox(height: 8),
                if (g != null)
                  Text(
                    '${g.away.team.abbreviation} ${g.hasStarted ? g.away.score : ''}  @  '
                    '${g.home.team.abbreviation} ${g.hasStarted ? g.home.score : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                Text(
                  Fmt.gameStatus(p),
                  style: TextStyle(
                    fontSize: 13,
                    color: p.gameState == GameState.live ? AppColors.live : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                Fmt.points(p.points),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.accent),
              ),
              const Text('PTS', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  const _StatSection(this.title, this.stats);

  final String title;
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final (label, value) in stats)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.player});

  final PlayerResult player;

  @override
  Widget build(BuildContext context) {
    final lines = player.breakdown.lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Fantasy points breakdown'),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              if (lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No scoring stats yet.', style: TextStyle(color: AppColors.textMuted)),
                ),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(l.label)),
                      SizedBox(
                        width: 56,
                        child: Text(l.statDisplay, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textMuted)),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          Fmt.signedPoints(l.points),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: l.points > 0
                                ? AppColors.positive
                                : (l.points < 0 ? AppColors.negative : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
                    Text(
                      Fmt.points(player.points),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.textMuted),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
