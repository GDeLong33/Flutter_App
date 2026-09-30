import 'package:flutter/material.dart';

import '../models/game.dart';
import '../models/player_result.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'formatting.dart';

/// One lineup slot. The left accent bar and status pill are color-coded:
/// live = green, final = neutral, upcoming / bye = muted.
class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player, this.onTap});

  final PlayerResult player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final state = p.gameState;
    final accent = AppColors.forState(state);
    final isLive = state == GameState.live;
    final muted = state == GameState.upcoming ||
        p.availability == PlayerAvailability.bye ||
        p.availability == PlayerAvailability.notFound;

    final subtitle = [
      p.position ?? p.slot.slot.label,
      if (p.team != null && !p.slot.isDefense) p.team!.abbreviation,
      if (Fmt.matchup(p).isNotEmpty) Fmt.matchup(p),
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLive ? AppColors.live.withValues(alpha: 0.45) : AppColors.outline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          p.slot.slot.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Avatar(name: p.displayName, url: p.headshotUrl, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Opacity(
                          opacity: muted ? 0.75 : 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.displayName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (p.injuryStatus != null) ...[
                                    const SizedBox(width: 6),
                                    Pill(text: _injuryAbbrev(p.injuryStatus!), color: AppColors.danger),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 6),
                              _StatusLine(player: p),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Points(player: p),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _injuryAbbrev(String status) {
    final s = status.toLowerCase();
    if (s.contains('reserve')) return 'IR';
    if (s.contains('questionable')) return 'Q';
    if (s.contains('doubtful')) return 'D';
    if (s.contains('out')) return 'OUT';
    if (s.contains('suspen')) return 'SUSP';
    return status.toUpperCase();
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.player});

  final PlayerResult player;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final state = p.gameState;
    final children = <Widget>[];

    if (p.availability == PlayerAvailability.bye) {
      children.add(const Pill(text: 'BYE', color: AppColors.textMuted));
    } else if (p.availability == PlayerAvailability.notFound) {
      children.add(const Pill(text: 'NOT FOUND', color: AppColors.danger));
    } else if (state == GameState.live) {
      children.add(const Pill(text: 'LIVE', color: AppColors.live, filled: true));
    } else if (state == GameState.finished) {
      children.add(const Pill(text: 'FINAL', color: AppColors.finalGame));
    }

    final status = p.availability == PlayerAvailability.bye ||
            p.availability == PlayerAvailability.notFound
        ? ''
        : Fmt.gameStatus(p).replaceFirst(RegExp(r'^Final · '), '');
    final live = Fmt.liveScore(p);
    final note = p.availability == PlayerAvailability.noStats && state != null
        ? (state == GameState.finished ? 'Did not play' : 'No stats yet')
        : '';
    final text = [status, live, note].where((s) => s.isNotEmpty).join(' · ');
    if (text.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 6));
      children.add(Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: state == GameState.live ? AppColors.live : AppColors.textMuted,
            fontWeight: state == GameState.live ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ));
    }
    return Row(children: children);
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.player});

  final PlayerResult player;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final pending = p.gameState == GameState.upcoming ||
        p.availability == PlayerAvailability.bye ||
        p.availability == PlayerAvailability.notFound;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          pending ? '—' : Fmt.points(p.points),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: pending
                ? AppColors.textMuted
                : (p.gameState == GameState.live ? AppColors.live : AppColors.textPrimary),
          ),
        ),
        const Text('PTS', style: TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1)),
      ],
    );
  }
}

/// Placeholder shown while the first load is in flight.
class PlayerCardSkeleton extends StatelessWidget {
  const PlayerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            SkeletonBox(width: 28, height: 12),
            SizedBox(width: 16),
            SkeletonBox(width: 42, height: 42, radius: 21),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 11),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 11),
                ],
              ),
            ),
            SkeletonBox(width: 40, height: 24),
          ],
        ),
      ),
    );
  }
}
