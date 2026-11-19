import 'package:flutter/material.dart';

/// Quiet, staggered fade + slight vertical glide entrance animation.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 12,
  });

  final Widget child;
  final int delayMs;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: 280 + delayMs);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, builtChild) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offsetY * (1.0 - value)),
            child: builtChild,
          ),
        );
      },
    );
  }
}
