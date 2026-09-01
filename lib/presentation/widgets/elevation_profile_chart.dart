/// Elevation profile chart — renders the route's height profile as an
/// area chart with a purple gradient fill (matches the screenshot the
/// user provided: «Высоты» title, ↑ascent / ↓descent stats on the right,
/// distance on the X axis in km, height on the Y axis in m).
///
/// Uses CustomPaint so we don't pull in fl_chart just for this one chart.
/// The input is the list of route waypoints (each has lat/lng/elevation).
/// Distance is computed incrementally via GeoUtils.distanceMeters.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/core/utils/geo_utils.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.points,
    this.accentColor,
    this.height = 160,
  });

  /// Route waypoints (planned) — elevation is taken from each point's
  /// `elevation` field (parsed from GPX `<ele>`). If all elevations are 0
  /// the chart renders an empty-state message.
  final List<GeoPoint> points;

  /// Tint color for the chart line + gradient. Defaults to the violet
  /// primary token to match the screenshot.
  final Color? accentColor;

  final double height;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l.noRouteYet,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
      );
    }

    // Compute cumulative distance + elevation series.
    final distances = <double>[];
    final elevations = <double>[];
    var cum = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        cum += GeoUtils.distanceMeters(
          lat1: points[i - 1].lat,
          lng1: points[i - 1].lng,
          lat2: points[i].lat,
          lng2: points[i].lng,
        );
      }
      distances.add(cum);
      elevations.add(points[i].elevation);
    }

    // If all elevations are zero (e.g. a route imported without <ele>),
    // show an empty state instead of a flat line at 0.
    final hasElevation = elevations.any((e) => e > 0);
    if (!hasElevation) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l.noRouteYet,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
      );
    }

    final totalDistance = distances.last;
    final minElev = elevations.reduce(math.min);
    final maxElev = elevations.reduce(math.max);
    var gain = 0.0;
    var loss = 0.0;
    for (var i = 1; i < elevations.length; i++) {
      final d = elevations[i] - elevations[i - 1];
      if (d > 0) {
        gain += d;
      } else {
        loss -= d;
      }
    }

    final color = accentColor ?? DesignTokens.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: title + ascent/descent stats.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l.elevationProfile,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Text('↑ ${gain.round()} м',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 12),
                Text('↓ ${loss.round()} м',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ElevationPainter(
              distances: distances,
              elevations: elevations,
              minElev: minElev,
              maxElev: maxElev,
              totalDistance: totalDistance,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({
    required this.distances,
    required this.elevations,
    required this.minElev,
    required this.maxElev,
    required this.totalDistance,
    required this.color,
  });

  final List<double> distances;
  final List<double> elevations;
  final double minElev;
  final double maxElev;
  final double totalDistance;
  final Color color;

  static const double _leftPad = 36;
  static const double _rightPad = 12;
  static const double _topPad = 8;
  static const double _bottomPad = 22; // leaves room for X axis labels

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final plotLeft = _leftPad;
    final plotTop = _topPad;
    final plotRight = size.width - _rightPad;
    final plotBottom = size.height - _bottomPad;
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;

    // Background.
    final bgPaint = ui.Paint()
      ..color = const Color(0xFF1A1A2E).withValues(alpha: 0.04);
    canvas.drawRect(
      Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom),
      bgPaint,
    );

    // Y axis labels (3 ticks: min / mid / max).
    final yTextStyle = ui.TextStyle(
      color: const Color(0xFF6B6B80),
      fontSize: 9,
    );
    final elevRange = (maxElev - minElev).clamp(1.0, double.infinity);
    for (var i = 0; i <= 2; i++) {
      final t = i / 2;
      final value = (minElev + elevRange * t).round();
      final y = plotBottom - plotH * t;
      _drawText(
        canvas,
        '${value}м',
        Offset(plotLeft - 4, y - 6),
        yTextStyle,
        alignRight: true,
        maxWidth: _leftPad - 6,
      );
      // Gridline.
      final gridPaint = ui.Paint()
        ..color = const Color(0xFF6B6B80).withValues(alpha: 0.15)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotRight, y),
        gridPaint,
      );
    }

    // X axis labels — 5 evenly-spaced distance ticks.
    final xTextStyle = ui.TextStyle(
      color: const Color(0xFF6B6B80),
      fontSize: 9,
    );
    final xTickCount = math.min(5, distances.length);
    for (var i = 0; i <= xTickCount - 1; i++) {
      final t = i / (xTickCount - 1);
      final x = plotLeft + plotW * t;
      final km = (totalDistance * t) / 1000;
      _drawText(
        canvas,
        '${km.toStringAsFixed(km < 10 ? 1 : 0)} км',
        Offset(x, plotBottom + 4),
        xTextStyle,
        alignCenter: true,
        maxWidth: 50,
      );
    }

    // Build the line path + area path.
    final linePath = ui.Path();
    final areaPath = ui.Path();
    final n = distances.length;
    for (var i = 0; i < n; i++) {
      final dx = totalDistance == 0
          ? 0.0
          : (distances[i] / totalDistance) * plotW;
      final dy = plotH - ((elevations[i] - minElev) / elevRange) * plotH;
      final x = plotLeft + dx;
      final y = plotTop + dy;
      if (i == 0) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, plotBottom);
        areaPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
      if (i == n - 1) {
        areaPath.lineTo(x, plotBottom);
        areaPath.close();
      }
    }

    // Area fill — vertical gradient under the line.
    final rect = Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom);
    final gradient = ui.Gradient.linear(
      Offset(0, plotTop),
      Offset(0, plotBottom),
      [
        color.withValues(alpha: 0.55),
        color.withValues(alpha: 0.05),
      ],
    );
    final areaPaint = ui.Paint()
      ..shader = gradient
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(rect, ui.Paint()..color = const Color(0x00000000));
    canvas.drawPath(areaPath, areaPaint);

    // Line stroke.
    final linePaint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = ui.StrokeJoin.round
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawPath(linePath, linePaint);
  }

  void _drawText(
    ui.Canvas canvas,
    String text,
    Offset offset,
    ui.TextStyle style, {
    bool alignRight = false,
    bool alignCenter = false,
    double maxWidth = 40,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: alignCenter
          ? TextAlign.center
          : (alignRight ? TextAlign.right : TextAlign.left),
      maxLines: 1,
    ))
      ..pushStyle(style)
      ..addText(text);
    final p = builder.build()..layout(ui.ParagraphConstraints(
          width: maxWidth,
        ));
    double dx = offset.dx;
    if (alignRight) dx = offset.dx - p.maxIntrinsicWidth;
    if (alignCenter) dx = offset.dx - p.maxIntrinsicWidth / 2;
    canvas.drawParagraph(p, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter old) =>
      old.distances != distances ||
      old.elevations != elevations ||
      old.color != color;
}
