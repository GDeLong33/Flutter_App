import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pulsing grey placeholder used by loading skeletons.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.8).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Full-screen error with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load scores",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Player headshot (or team logo) with an initials fallback.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          fontSize: size * 0.34,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Small rounded label, e.g. "LIVE", "Q", "IR".
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: filled ? AppColors.background : color,
        ),
      ),
    );
  }
}
