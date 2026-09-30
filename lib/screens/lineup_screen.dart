import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_result.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/player_card.dart';
import '../widgets/total_points_header.dart';
import '../widgets/week_selector.dart';
import 'edit_lineup_screen.dart';
import 'player_detail_screen.dart';
import 'settings_screen.dart';

class LineupScreen extends ConsumerWidget {
  const LineupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scored = ref.watch(scoredWeekProvider);
    final activeWeek = ref.watch(activeWeekProvider);
    final calendar = ref.watch(seasonCalendarProvider);
    final notifier = ref.read(lineupWeekProvider.notifier);

    // Show skeletons (not stale numbers) when switching weeks.
    final data = scored.value;
    final showingStaleWeek = data != null && activeWeek.value != null && data.week != activeWeek.value;

    Widget body;
    final error = calendar.error ?? activeWeek.error ?? scored.error;
    if (error != null && data == null) {
      body = ErrorView(
        error: error,
        onRetry: () {
          if (calendar.hasError) ref.invalidate(seasonCalendarProvider);
          notifier.refresh();
        },
      );
    } else if (data == null || showingStaleWeek) {
      body = const _SkeletonList();
    } else {
      body = RefreshIndicator(
        color: AppColors.live,
        onRefresh: notifier.refresh,
        child: _LineupList(result: data, refreshing: scored.isLoading),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lineup Tracker'),
        actions: [
          const WeekSelector(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              final route = switch (v) {
                'edit' => MaterialPageRoute<void>(builder: (_) => const EditLineupScreen()),
                _ => MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              };
              Navigator.of(context).push(route);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit lineup'))),
              PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.tune), title: Text('Scoring settings'))),
            ],
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _LineupList extends ConsumerWidget {
  const _LineupList({required this.result, required this.refreshing});

  final LineupWeekResult result;
  final bool refreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polling = ref.watch(pollingDescriptionProvider);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        TotalPointsHeader(result: result, pollingDescription: polling, refreshing: refreshing),
        if (result.refreshError != null) ...[
          const SizedBox(height: 10),
          _RefreshErrorBanner(
            error: result.refreshError!,
            onRetry: ref.read(lineupWeekProvider.notifier).refresh,
          ),
        ],
        const SizedBox(height: 14),
        for (var i = 0; i < result.players.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PlayerCard(
              player: result.players[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlayerDetailScreen(slotIndex: i)),
              ),
            ),
          ),
      ],
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Update failed, showing last known scores.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const TotalPointsHeaderSkeleton(),
        const SizedBox(height: 14),
        for (var i = 0; i < 9; i++)
          const Padding(padding: EdgeInsets.only(bottom: 10), child: PlayerCardSkeleton()),
      ],
    );
  }
}
