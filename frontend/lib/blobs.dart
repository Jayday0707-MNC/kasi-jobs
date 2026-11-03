import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kGreenDark, kGreen, kEmerald],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: BlobBackground()),
          child,
        ],
      ),
    );
  }
}

class BlobBackground extends StatefulWidget {
  const BlobBackground({super.key});

  @override
  State<BlobBackground> createState() => _BlobBackgroundState();
}

class _BlobBackgroundState extends State<BlobBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob({
    required double left,
    required double top,
    required double size,
    required Color color,
    required double t,
    required double phase,
  }) {
    double r(double k) =>
        size * (0.34 + 0.16 * (0.5 + 0.5 * math.sin(t + phase + k)));
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Transform.rotate(
        angle: math.sin(t + phase) * 0.35,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r(0)),
              topRight: Radius.circular(r(1.6)),
              bottomRight: Radius.circular(r(3.2)),
              bottomLeft: Radius.circular(r(4.8)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final base = math.max(w, 320.0);
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value * 2 * math.pi;
              return Stack(
                children: [
                  _blob(
                    left: w * 0.55 + math.sin(t) * 26,
                    top: -base * 0.18 + math.cos(t) * 20,
                    size: base * 0.62,
                    color: kCoral.withValues(alpha: 0.30),
                    t: t,
                    phase: 0,
                  ),
                  _blob(
                    left: -base * 0.18 + math.cos(t) * 24,
                    top: h * 0.45 + math.sin(t) * 22,
                    size: base * 0.55,
                    color: kAmber.withValues(alpha: 0.26),
                    t: t,
                    phase: 2,
                  ),
                  _blob(
                    left: w * 0.35 + math.sin(t + 1) * 30,
                    top: h * 0.55 + math.cos(t + 2) * 18,
                    size: base * 0.5,
                    color: kViolet.withValues(alpha: 0.24),
                    t: t,
                    phase: 4,
                  ),
                  _blob(
                    left: w * 0.8 + math.cos(t) * 18,
                    top: h * 0.2 + math.sin(t) * 24,
                    size: base * 0.34,
                    color: kSky.withValues(alpha: 0.28),
                    t: t,
                    phase: 1,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}