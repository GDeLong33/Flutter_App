import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scoring_settings.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Editable scoring rules. Every change is saved immediately and the lineup
/// is rescored without refetching.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(scoringSettingsProvider);
    final notifier = ref.read(scoringSettingsProvider.notifier);
    void set(ScoringSettings next) => notifier.update(next);

    Widget num(String label, double value, ScoringSettings Function(double) apply, {String? hint}) =>
        _NumberTile(
          // Key by value so "Reset" refreshes the text fields.
          key: ValueKey('$label-$value'),
          label: label,
          hint: hint,
          value: value,
          onChanged: (v) => set(apply(v)),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoring'),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset scoring?'),
                  content: const Text('Restore standard PPR defaults.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (ok == true) notifier.reset();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('Passing'),
          num('Yards per point', s.passYardsPerPoint, (v) => s.copyWith(passYardsPerPoint: v)),
          num('Passing TD', s.passTd, (v) => s.copyWith(passTd: v)),
          num('Interception', s.interception, (v) => s.copyWith(interception: v)),
          const _Header('Rushing & receiving'),
          num('Rushing yards per point', s.rushYardsPerPoint, (v) => s.copyWith(rushYardsPerPoint: v)),
          num('Rushing TD', s.rushTd, (v) => s.copyWith(rushTd: v)),
          num('Receiving yards per point', s.receivingYardsPerPoint,
              (v) => s.copyWith(receivingYardsPerPoint: v)),
          num('Receiving TD', s.receivingTd, (v) => s.copyWith(receivingTd: v)),
          num('Reception (PPR)', s.reception, (v) => s.copyWith(reception: v), hint: '1 = PPR, 0.5 = half'),
          const _Header('Misc'),
          num('Fumble lost', s.fumbleLost, (v) => s.copyWith(fumbleLost: v)),
          num('2-pt conversion', s.twoPointConversion, (v) => s.copyWith(twoPointConversion: v)),
          num('Kick/punt return TD', s.returnTd, (v) => s.copyWith(returnTd: v)),
          SwitchListTile(
            title: const Text('Decimal yardage points'),
            subtitle: const Text('Off: 59 rush yds = 5 pts. On: 5.9 pts.'),
            value: s.fractionalYardage,
            onChanged: (v) => set(s.copyWith(fractionalYardage: v)),
          ),
          const _Header('Kicking'),
          num('FG 0-39 yds', s.fgUnder40, (v) => s.copyWith(fgUnder40: v)),
          num('FG 40-49 yds', s.fg40to49, (v) => s.copyWith(fg40to49: v)),
          num('FG 50+ yds', s.fg50Plus, (v) => s.copyWith(fg50Plus: v)),
          num('FG missed', s.fgMissed, (v) => s.copyWith(fgMissed: v)),
          num('Extra point', s.extraPoint, (v) => s.copyWith(extraPoint: v)),
          num('Extra point missed', s.extraPointMissed, (v) => s.copyWith(extraPointMissed: v)),
          const _Header('Defense / special teams'),
          num('Sack', s.dstSack, (v) => s.copyWith(dstSack: v)),
          num('Interception', s.dstInterception, (v) => s.copyWith(dstInterception: v)),
          num('Fumble recovery', s.dstFumbleRecovery, (v) => s.copyWith(dstFumbleRecovery: v)),
          num('Return TD', s.dstTouchdown, (v) => s.copyWith(dstTouchdown: v)),
          num('Safety', s.dstSafety, (v) => s.copyWith(dstSafety: v)),
          const _Header('Points allowed'),
          for (var i = 0; i < s.pointsAllowedTiers.length; i++)
            num(
              _tierLabel(s.pointsAllowedTiers, i),
              s.pointsAllowedTiers[i].points,
              (v) => s.copyWith(
                pointsAllowedTiers: [...s.pointsAllowedTiers]..[i] = s.pointsAllowedTiers[i].copyWith(points: v),
              ),
            ),
        ],
      ),
    );
  }

  static String _tierLabel(List<PointsAllowedTier> tiers, int i) {
    final min = i == 0 ? 0 : (tiers[i - 1].maxPointsAllowed ?? 0) + 1;
    final max = tiers[i].maxPointsAllowed;
    if (max == null) return '$min+ points allowed';
    if (min == max) return '$min points allowed';
    return '$min-$max points allowed';
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.live),
      ),
    );
  }
}

class _NumberTile extends StatefulWidget {
  const _NumberTile({super.key, required this.label, required this.value, required this.onChanged, this.hint});

  final String label;
  final String? hint;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberTile> createState() => _NumberTileState();
}

class _NumberTileState extends State<_NumberTile> {
  late final _controller = TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_controller.text.trim());
    if (v == null) {
      _controller.text = _fmt(widget.value); // Revert invalid input.
    } else if (v != widget.value) {
      widget.onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label),
      subtitle: widget.hint == null ? null : Text(widget.hint!, style: const TextStyle(color: AppColors.textMuted)),
      trailing: SizedBox(
        width: 76,
        child: Focus(
          onFocusChange: (has) {
            if (!has) _commit();
          },
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
            onSubmitted: (_) => _commit(),
          ),
        ),
      ),
    );
  }
}
