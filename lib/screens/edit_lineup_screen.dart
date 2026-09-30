import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lineup_slot.dart';
import '../providers/providers.dart';
import '../services/espn_parsers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Lists the lineup; tap a slot to search ESPN and swap in another player.
class EditLineupScreen extends ConsumerWidget {
  const EditLineupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineup = ref.watch(lineupProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit lineup'),
        actions: [
          TextButton(
            onPressed: () => ref.read(lineupProvider.notifier).resetToDefault(),
            child: const Text('Reset to default'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: lineup.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          final slot = lineup[i];
          return ListTile(
            leading: SizedBox(
              width: 44,
              child: Center(
                child: Text(slot.slot.label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              ),
            ),
            title: Text(slot.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: slot.slot == SlotType.flex && slot.position != null ? Text(slot.position!) : null,
            trailing: const Icon(Icons.swap_horiz),
            onTap: () async {
              final replacement = slot.isDefense
                  ? await _pickTeam(context, slot)
                  : await showModalBottomSheet<LineupSlot>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _PlayerSearchSheet(slot: slot),
                    );
              if (replacement != null) {
                await ref.read(lineupProvider.notifier).replace(i, replacement);
              }
            },
          );
        },
      ),
    );
  }

  Future<LineupSlot?> _pickTeam(BuildContext context, LineupSlot slot) {
    return showModalBottomSheet<LineupSlot>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final teams = ref.watch(teamsProvider);
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: teams.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(teamsProvider)),
              data: (list) => ListView(
                children: [
                  for (final t in list)
                    ListTile(
                      leading: Avatar(name: t.displayName, url: t.logoUrl, size: 36),
                      title: Text('${t.displayName} D/ST'),
                      selected: t.matches(slot.name),
                      onTap: () => Navigator.pop(context, slot.copyWith(name: t.displayName)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerSearchSheet extends ConsumerStatefulWidget {
  const _PlayerSearchSheet({required this.slot});

  final LineupSlot slot;

  @override
  ConsumerState<_PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}

class _PlayerSearchSheetState extends ConsumerState<_PlayerSearchSheet> {
  Timer? _debounce;
  String _query = '';
  Future<List<PlayerSearchResult>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final trimmed = q.trim();
      if (trimmed == _query) return;
      setState(() {
        _query = trimmed;
        _results = trimmed.length < 2 ? null : ref.read(trackerServiceProvider).searchPlayers(trimmed);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final eligible = widget.slot.slot.eligiblePositions;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search ${eligible.join('/')} to replace ${widget.slot.name}',
                ),
                onChanged: _onChanged,
              ),
            ),
            Expanded(
              child: _results == null
                  ? const Center(
                      child: Text('Type at least 2 letters', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : FutureBuilder<List<PlayerSearchResult>>(
                      future: _results,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return ErrorView(
                            error: snap.error!,
                            onRetry: () => setState(() {
                              _results = ref.read(trackerServiceProvider).searchPlayers(_query);
                            }),
                          );
                        }
                        final players = snap.data!.where((p) => eligible.contains(p.position)).toList();
                        if (players.isEmpty) {
                          return const Center(
                            child: Text('No matching players at this position', style: TextStyle(color: AppColors.textMuted)),
                          );
                        }
                        return ListView.builder(
                          itemCount: players.length,
                          itemBuilder: (context, i) {
                            final p = players[i];
                            return ListTile(
                              leading: Avatar(name: p.name, url: p.headshotUrl, size: 40),
                              title: Text(p.name),
                              subtitle: Text([p.position, p.teamAbbreviation ?? 'Free agent'].whereType<String>().join(' · ')),
                              onTap: () => Navigator.pop(
                                context,
                                LineupSlot(
                                  slot: widget.slot.slot,
                                  name: p.name,
                                  position: widget.slot.slot == SlotType.flex ? p.position : null,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
