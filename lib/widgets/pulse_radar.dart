import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flashdrop/core/theme/app_theme.dart';

/// Subtle concentric monochrome radar pulse used during discovery, advertising, and handshakes.
class PulseRadar extends StatefulWidget {
  const PulseRadar({
    super.key,
    required this.icon,
    this.active = true,
    this.size = 136,
  });

  final IconData icon;
  final bool active;
  final double size;

  @override
  State<PulseRadar> createState() => _PulseRadarState();
}

class _PulseRadarState extends State<PulseRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulseRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final coreSize = widget.size * 0.56;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                size: Size.square(widget.size),
                painter: _RadarPainter(
                  progress: _controller.value,
                  ringColor: scheme.onSurface,
                ),
              ),
            ),
          Container(
            width: coreSize,
            height: coreSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: FlashDropGradients.secondaryTile(theme.brightness),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              widget.icon,
              size: coreSize * 0.44,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.ringColor,
  });

  final double progress;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = maxRadius * 0.52;

    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3.0) % 1.0;
      final curved = Curves.easeOut.transform(phase);
      final radius = minRadius + (maxRadius - minRadius) * curved;
      final alpha = (1.0 - curved) * 0.22;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = ringColor.withValues(alpha: math.max(0.0, alpha));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
}
