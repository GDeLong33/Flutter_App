import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// App bar button showing the active week; opens a picker sheet.
class WeekSelector extends ConsumerWidget {
  const WeekSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWeekProvider).value;
    final calendar = ref.watch(seasonCalendarProvider).value;
    return TextButton.icon(
      onPressed: calendar == null ? null : () => _showPicker(context, ref, calendar.weeks, calendar.current, active),
      icon: const Icon(Icons.calendar_month_rounded, size: 18),
      label: Text(active?.label ?? 'Week'),
      style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<WeekRef> weeks,
    WeekRef current,
    WeekRef? active,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final initialIndex = weeks.indexOf(active ?? current).clamp(0, weeks.length - 1);
        return SafeArea(
          child: ListView.builder(
            controller: ScrollController(initialScrollOffset: (initialIndex - 3).clamp(0, 999) * 52.0),
            itemCount: weeks.length,
            itemExtent: 52,
            itemBuilder: (context, i) {
              final w = weeks[i];
              final isCurrent = w == current;
              final isFuture = weeks.indexOf(w) > weeks.indexOf(current);
              return ListTile(
                title: Text(
                  w.label,
                  style: TextStyle(color: isFuture ? AppColors.textMuted : null),
                ),
                trailing: isCurrent
                    ? const Text('CURRENT', style: TextStyle(color: AppColors.live, fontSize: 11, fontWeight: FontWeight.w800))
                    : null,
                selected: w == (active ?? current),
                selectedTileColor: AppColors.surfaceHigh,
                onTap: () {
                  // Selecting the current week goes back to "follow current".
                  ref.read(selectedWeekProvider.notifier).select(isCurrent ? null : w);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }
}
