import 'package:flutter/material.dart';
import 'package:flashdrop/core/theme/app_theme.dart';

class TransferProgressRing extends StatelessWidget {
  const TransferProgressRing({
    super.key,
    required this.fraction,
    required this.percentage,
    required this.speedLabel,
  });

  final double fraction;
  final int percentage;
  final String speedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = fraction.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (_, animatedValue, __) {
        return Container(
          width: 204,
          height: 204,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FlashDropGradients.cardSurface(theme.brightness),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: animatedValue,
                  strokeWidth: 8,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percentage%',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    speedLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
