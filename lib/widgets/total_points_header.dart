import 'package:flutter/material.dart';

import '../models/game.dart';
import '../models/player_result.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'formatting.dart';

/// Big total-points scoreboard at the top of the lineup screen.
class TotalPointsHeader extends StatelessWidget {
  const TotalPointsHeader({
    super.key,
    required this.result,
    required this.pollingDescription,
    this.refreshing = false,
  });

  final LineupWeekResult result;
  final String? pollingDescription;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final players = result.players;
    int count(bool Function(PlayerResult) f) => players.where(f).length;
    final live = count((p) => p.gameState == GameState.live);
    final done = count((p) =>
        p.gameState == GameState.finished || p.availability == PlayerAvailability.bye);
    final toPlay = players.length - live - done;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            result.anyLive ? const Color(0xFF0F2A1C) : AppColors.surfaceHigh,
            AppColors.surface,
          ],
        ),
        border: Border.all(
          color: result.anyLive ? AppColors.live.withValues(alpha: 0.4) : AppColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                result.week.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (result.anyLive) const Pill(text: '● LIVE', color: AppColors.live),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Fmt.points(result.totalPoints),
                style: const TextStyle(
                  fontSize: 56,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'PTS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              _Count(label: 'Live', value: live, color: AppColors.live),
              _Count(label: 'Yet to play', value: toPlay, color: AppColors.textMuted),
              _Count(label: 'Done', value: done, color: AppColors.finalGame),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (refreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              Expanded(
                child: Text(
                  [
                    'Updated ${Fmt.lastUpdated(result.lastUpdated)}',
                    ?pollingDescription,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '$value ',
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
        TextSpan(text: label, style: const TextStyle(color: AppColors.textMuted)),
      ]),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class TotalPointsHeaderSkeleton extends StatelessWidget {
  const TotalPointsHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 70, height: 12),
          SizedBox(height: 12),
          SkeletonBox(width: 150, height: 52),
          SizedBox(height: 12),
          SkeletonBox(width: 200, height: 12),
        ],
      ),
    );
  }
}
