import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Круговая диаграмма распределения — особенность предметной области:
/// показывает, как привычки распределены по категориям.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.values, this.size = 160});

  /// Название категории → количество привычек.
  final Map<String, int> values;
  final double size;

  static const _colors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF039BE5),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = values.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    if (entries.isEmpty || total == 0) {
      return Text('Нет данных для диаграммы', style: theme.textTheme.bodySmall);
    }

    final legend = [
      for (var i = 0; i < entries.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _colors[i % _colors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entries[i].key} — ${entries[i].value} '
                '(${(entries[i].value * 100 / total).round()}%)',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          label: 'Распределение привычек по категориям',
          child: CustomPaint(
            size: Size.square(size),
            painter: _PiePainter(
              values: [for (final e in entries) e.value],
              total: total,
              colors: _colors,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: legend,
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter({
    required this.values,
    required this.total,
    required this.colors,
  });

  final List<int> values;
  final int total;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    var start = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect.deflate(1), start, sweep, true, paint);
      start += sweep;
    }

    // Вырез в середине — «пончик», чтобы читались подписи.
    final hole = Paint()..color = Colors.transparent;
    hole.blendMode = BlendMode.clear;
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * 0.28, hole);
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.values.length != values.length;
}
