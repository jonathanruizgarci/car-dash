import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Medidor circular tipo tablero.
class Gauge extends StatelessWidget {
  final double value;
  final double max;
  final String unit;
  final String? label;
  final int decimals;
  final double? warnFrom;

  const Gauge({
    super.key,
    required this.value,
    required this.max,
    required this.unit,
    this.label,
    this.decimals = 0,
    this.warnFrom,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warn = warnFrom != null && value >= warnFrom!;
    final color = warn ? Colors.redAccent : cs.primary;
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight);
      if (!size.isFinite || size < 40) return const SizedBox.shrink();
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              fraction: max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble(),
              track: cs.surfaceContainerHighest,
              color: color,
              tick: cs.onSurfaceVariant,
              max: max,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toStringAsFixed(decimals),
                    style: TextStyle(fontSize: size * 0.21, fontWeight: FontWeight.w700, height: 1.0),
                  ),
                  Text(unit, style: TextStyle(fontSize: size * 0.07, color: cs.onSurfaceVariant)),
                  if (label != null)
                    Padding(
                      padding: EdgeInsets.only(top: size * 0.02),
                      child: Text(label!, style: TextStyle(fontSize: size * 0.05, color: cs.primary)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color track;
  final Color color;
  final Color tick;
  final double max;

  _GaugePainter({
    required this.fraction,
    required this.track,
    required this.color,
    required this.tick,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 * 0.9;
    final stroke = size.width * 0.05;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final rect = Rect.fromCircle(center: c, radius: r);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, arc..color = track);
    if (fraction > 0.001) {
      canvas.drawArc(rect, start, sweep * fraction, false, arc..color = color);
    }

    final tp = Paint()
      ..color = tick.withValues(alpha: 0.6)
      ..strokeWidth = size.width * 0.006;
    for (var i = 0; i <= 20; i++) {
      final a = start + sweep * i / 20;
      final o = Offset(math.cos(a), math.sin(a));
      final inner = i % 2 == 0 ? r - stroke * 2.1 : r - stroke * 1.6;
      canvas.drawLine(c + o * (r - stroke * 1.0), c + o * inner, tp);
    }

    final big = max >= 1000;
    for (var i = 0; i <= 5; i++) {
      final a = start + sweep * i / 5;
      final v = max * i / 5;
      final text = big ? (v / 1000).toStringAsFixed(0) : v.toStringAsFixed(0);
      final painter = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: tick, fontSize: size.width * 0.045)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(math.cos(a), math.sin(a)) * (r - stroke * 3.4) -
          Offset(painter.width / 2, painter.height / 2);
      painter.paint(canvas, pos);
    }

    final a = start + sweep * fraction;
    final dir = Offset(math.cos(a), math.sin(a));
    final needle = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + dir * (r * 0.62), c + dir * (r - stroke * 1.3), needle);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track || old.max != max;
}
