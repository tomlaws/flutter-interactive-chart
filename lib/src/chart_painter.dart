import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:collection/collection.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:collection/collection.dart';

import 'candle_data.dart';
import 'painter_params.dart';

typedef TimeLabelGetter = String Function(int timestamp, int visibleDataCount);
typedef PriceLabelGetter = String Function(double price);
typedef OverlayInfoGetter = Map<String, String> Function(CandleData candle);

class ChartPainter extends CustomPainter {
  final PainterParams params;
  final TimeLabelGetter getTimeLabel;
  final PriceLabelGetter getPriceLabel;
  final OverlayInfoGetter getOverlayInfo;
  List<double> occupied = [];

  ChartPainter({
    required this.params,
    required this.getTimeLabel,
    required this.getPriceLabel,
    required this.getOverlayInfo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    occupied = [];
    // Draw time labels (dates) & price labels
    //_drawTimeLabels2(canvas, params);
    _drawChartLabels(canvas, params);
    _drawTimeLabels2(canvas, params);
    _drawPriceGridAndLabels(canvas, params);

    // Draw prices, volumes & trend line
    canvas.save();
    canvas.clipRect(Offset.zero & Size(params.chartWidth, params.chartHeight));

    // canvas.drawRect(
    //   // apply yellow tint to clipped area (for debugging)
    //   Offset.zero & Size(params.chartWidth, params.chartHeight),
    //   Paint()..color = Colors.yellow[100]!,
    // );
    canvas.translate(params.xShift, 0);
    for (int i = 0; i < params.candles.length; i++) {
      _drawSingleDay(canvas, params, i);
    }
    canvas.restore();

    // Draw subcharts
    _drawSubchartLabels(canvas, params);
    _drawSubcharts(canvas, params);
    canvas.translate(params.xShift, 0);
    canvas.clipRect(Offset.zero &
        Size(params.chartWidth,
            params.subchartHeight * params.subcharts.length));

    canvas.restore();
    // Draw tap highlight & overlay
    if (params.tapPosition != null) {
      if (params.tapPosition!.dx < params.chartWidth) {
        _drawTapHighlightAndOverlay(canvas, params);
      }
    }
    canvas.save();
  }

  void _drawTimeLabels2(canvas, PainterParams params) {
    // attemp to put labels right below the candle sticks
    final lineCount = params.candles.length;
    List<TextPainter> painters = [];
    for (int i = 0; i < lineCount; i++) {
      double x = i * params.candleWidth;
      final index = params.getCandleIndexFromOffset(x);
      if (index < params.candles.length) {
        final candle = params.candles[index];
        final visibleDataCount = params.candles.length;
        final text = getTimeLabel(candle.timestamp, visibleDataCount);
        final timeTp = TextPainter(
          text: TextSpan(
            text: text,
            style: params.style.timeLabelStyle,
          ),
        )
          ..textDirection = TextDirection.ltr
          ..layout();
        painters.add(timeTp);
      }
    }
    var maxLabelWidth = painters.map((e) => e.width).reduce(max);
    // at least two times bigger
    if (maxLabelWidth * 2 <= params.candleWidth)
      for (int i = 0; i < painters.length; ++i) {
        var timeTp = painters[i];
        final topPadding = params.style.timeLabelHeight - timeTp.height;
        double x = i * params.candleWidth + params.xShift;
        timeTp.paint(
          canvas,
          Offset(x - timeTp.width / 2, params.chartHeight + topPadding),
        );
      }
    else
      return _drawTimeLabels(canvas, params);
  }

  void _drawTimeLabels(canvas, PainterParams params) {
    // We draw one time label per 90 pixels of screen width
    final lineCount = params.chartWidth ~/ 90;
    final gap = 1 / (lineCount + 1);
    for (int i = 1; i <= lineCount; i++) {
      double x = i * gap * params.chartWidth;
      final index = params.getCandleIndexFromOffset(x);
      if (index < params.candles.length) {
        final candle = params.candles[index];
        final visibleDataCount = params.candles.length;
        final timeTp = TextPainter(
          text: TextSpan(
            text: getTimeLabel(candle.timestamp, visibleDataCount),
            style: params.style.timeLabelStyle,
          ),
        )
          ..textDirection = TextDirection.ltr
          ..layout();

        // Align texts towards vertical bottom
        final topPadding = params.style.timeLabelHeight - timeTp.height;
        timeTp.paint(
          canvas,
          Offset(x - timeTp.width / 2, params.chartHeight + topPadding),
        );
      }
    }
  }

  void _drawPriceGridAndLabels(canvas, PainterParams params) {
    [0.0, 0.25, 0.5, 0.75, 1.0]
        .map((v) => ((params.maxPrice - params.minPrice) * v) + params.minPrice)
        .forEach((y) {
      canvas.drawLine(
        Offset(0, params.fitPrice(y)),
        Offset(params.chartWidth, params.fitPrice(y)),
        Paint()
          ..strokeWidth = 0.5
          ..color = params.style.priceGridLineColor,
      );
      final priceTp = TextPainter(
        text: TextSpan(
          text: getPriceLabel(y),
          style: params.style.priceLabelStyle,
        ),
      )
        ..textDirection = TextDirection.ltr
        ..layout();
      priceTp.paint(
          canvas,
          Offset(
            params.chartWidth + 4,
            params.fitPrice(y) - priceTp.height / 2,
          ));
    });
  }

  void _drawSingleDay(Canvas canvas, PainterParams params, int i) {
    final candle = params.candles[i];
    final additionalChart = params.additionalChart.values;
    final x = i * params.candleWidth;
    final thickWidth = max(params.candleWidth * 0.8, 0.8);
    final thinWidth = max(params.candleWidth * 0.2, 0.2);
    // Draw price bar
    final open = candle.open;
    final close = candle.close;
    final high = candle.high;
    final low = candle.low;
    if (open != null && close != null) {
      final color = open == close
          ? params.style.priceUnchangeColor
          : (open > close
              ? params.style.priceLossColor
              : params.style.priceGainColor);
      canvas.drawLine(
        Offset(x, params.fitPrice(open)),
        Offset(x, params.fitPrice(close)),
        Paint()
          ..strokeWidth = thickWidth
          ..color = color,
      );
      if (high != null && low != null) {
        canvas.drawLine(
          Offset(x, params.fitPrice(high)),
          Offset(x, params.fitPrice(low)),
          Paint()
            ..strokeWidth = thinWidth
            ..color = color,
        );
      }
    }
    // Draw volume bar
    final volume = candle.volume;
    if (volume != null) {
      canvas.drawLine(
        Offset(x, params.chartHeight),
        Offset(x, params.fitVolume(volume)),
        Paint()
          ..strokeWidth = thickWidth
          ..color = params.style.volumeColor,
      );
    }

    // Draw trend line
    for (int j = 0; j < candle.trends.length; j++) {
      final trendLinePaint = params.style.trendLineStyles.at(j) ??
          (Paint()
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..color = Colors.blue);

      final pt = candle.trends.at(j); // current data point
      final prevPt = params.candles.at(i - 1)?.trends.at(j);
      if (pt != null && prevPt != null) {
        canvas.drawLine(
          Offset(x - params.candleWidth, params.fitPrice(prevPt)),
          Offset(x, params.fitPrice(pt)),
          trendLinePaint,
        );
      }
      if (i == 0) {
        // In the front, draw an extra line connecting to out-of-window data
        if (pt != null && params.leadingTrends?.at(j) != null) {
          canvas.drawLine(
            Offset(x - params.candleWidth,
                params.fitPrice(params.leadingTrends!.at(j)!)),
            Offset(x, params.fitPrice(pt)),
            trendLinePaint,
          );
        }
      } else if (i == params.candles.length - 1) {
        // At the end, draw an extra line connecting to out-of-window data
        if (pt != null && params.trailingTrends?.at(j) != null) {
          canvas.drawLine(
            Offset(x, params.fitPrice(pt)),
            Offset(
              x + params.candleWidth,
              params.fitPrice(params.trailingTrends!.at(j)!),
            ),
            trendLinePaint,
          );
        }
      }
    }

    // Draw additional trend line
    // Draw trend line
    for (int j = 0; j < additionalChart.length; j++) {
      final pt = additionalChart[j].at(i); // current data point
      final prevPt = additionalChart[j].at(i - 1);
      // If dotted
      if (params.additionalChart.dotted) {
        if (pt != null)
          canvas.drawCircle(
              Offset(x, params.fitPrice(pt)),
              params.candleWidth / 2 / 2,
              Paint()
                ..strokeCap = StrokeCap.round
                ..color = params.additionalChart.colors[j]);
        continue;
      }

      final trendLinePaint = (Paint()
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..color = params.additionalChart.colors[j]);

      if (pt != null && prevPt != null) {
        canvas.drawLine(
          Offset(x - params.candleWidth, params.fitPrice(prevPt)),
          Offset(x, params.fitPrice(pt)),
          trendLinePaint,
        );
      }
      if (i == 0) {
        // In the front, draw an extra line connecting to out-of-window data
        if (pt != null && params.additionalChart.leading[j] != null) {
          canvas.drawLine(
            Offset(x - params.candleWidth,
                params.fitPrice(params.additionalChart.leading[j]!)),
            Offset(x, params.fitPrice(pt)),
            trendLinePaint,
          );
        }
      } else if (i == params.candles.length - 1) {
        // At the end, draw an extra line connecting to out-of-window data
        if (pt != null && params.additionalChart.trailing[j] != null) {
          canvas.drawLine(
            Offset(x, params.fitPrice(pt)),
            Offset(
              x + params.candleWidth,
              params.fitPrice(params.additionalChart.trailing[j]!),
            ),
            trendLinePaint,
          );
        }
      }
    }
  }

  void _drawTapHighlightAndOverlay(canvas, PainterParams params) {
    final pos = params.tapPosition!;
    final i = params.getCandleIndexFromOffset(pos.dx);
    canvas.save();
    canvas.translate(params.xShift, 0.0);
    // Draw highlight bar (selection box)
    canvas.drawLine(
        Offset(i * params.candleWidth, 0.0),
        Offset(i * params.candleWidth, params.chartsHeight),
        Paint()
          ..strokeWidth = max(params.candleWidth * 0.88, 1.0)
          ..color = params.style.selectionHighlightColor);
    canvas.restore();
    // Draw info pane
    final additionalChart = params.additionalChart;
    _drawTapInfoOverlay(canvas, params, i);

    // Draw data points
    var px = params.xShift + i * params.candleWidth;
    for (int j = 0; j < additionalChart.values.length; j++) {
      double? v = additionalChart.values[j].at(i);
      if (v == null) continue;
      var py = params.fitPrice(v);
      canvas.drawCircle(Offset(px, py), min(4.0, params.candleWidth / 2),
          Paint()..color = params.additionalChart.colors[j]);
    }

    // For subcharts

    // for subcharts tap info
    for (int j = 0; j < params.subcharts.length; j++) {
      final chart = params.subcharts[j];
      if (chart.max == null || chart.min == null) continue;
      final info = chart.labels;
      final labelPainters = info.keys
          .mapIndexed((i, e) => TextPainter(
                text: TextSpan(
                  text: e + ':',
                  style: params.style.overlayTextStyle
                      .apply(color: chart.colors[i]),
                ),
              )
                ..textDirection = TextDirection.ltr
                ..layout())
          .toList();
      final valuePainters = info.values
          .map((e) => TextPainter(
                text: TextSpan(
                  text: e(i, chart.values),
                  style:
                      params.style.overlayTextStyle.apply(color: Colors.white),
                ),
              )
                ..textDirection = TextDirection.ltr
                ..layout())
          .toList();
      final xGap = 8.0;
      final yGap = 4.0;
      final labelMaxWidth = labelPainters.map((e) => e.width).reduce(max);
      final labelMaxHeight = labelPainters.map((e) => e.height).reduce(max);
      final valueMaxWidth = valuePainters.map((e) => e.width).reduce(max);
      final valueMaxHeight = valuePainters.map((e) => e.height).reduce(max);
      final panelWidth = labelMaxWidth + valueMaxWidth + xGap * 3;
      final panelHeight =
          (max(labelMaxHeight, valueMaxHeight) + yGap) * (info.length) + yGap;
      var baseX = 0.0;
      var baseY = params.chartHeight +
          params.chartSpacing +
          params.style.timeLabelHeight +
          params.subchartHeight * j;

      if (px <= params.size.width / 2) {
        baseX = px + 30;
      } else {
        // Otherwise we show panel on the left of the finger touch position.
        baseX = px - panelWidth - 30;
      }
      baseX = baseX.clamp(0, params.size.width - panelWidth);

      if (baseY < 0) baseY = 0.0;

      var price = chart.yForOverlay(i);
      if (price == null) continue;
      var py = params.fitPriceForSubchart(price, chart.max!, chart.min!) -
          panelHeight / 2;
      py = py.clamp(0, params.subchartHeight - panelHeight - 4);
      RRect panelRect = RRect.fromRectAndRadius(
        Offset(baseX, baseY + py) & Size(panelWidth, panelHeight),
        Radius.circular(8),
      );
      //var overlayBackgroundColor = params.style.overlayBackgroundColor;
      canvas.drawRRect(panelRect, Paint()..color = Colors.black);

      for (int i = 0; i < labelPainters.length; i++) {
        var painter = labelPainters[i];
        painter.paint(
            canvas,
            Offset(baseX + xGap,
                baseY + py + yGap * (i + 1) + (labelMaxHeight * i)));
      }
      for (int i = 0; i < valuePainters.length; i++) {
        var painter = valuePainters[i];
        painter.paint(
            canvas,
            Offset(baseX + labelMaxWidth + xGap * 2,
                baseY + py + yGap * (i + 1) + (labelMaxHeight * i)));
      }
    }
  }

  void _drawTapInfoOverlay(canvas, PainterParams params, int d) {
    final xGap = 8.0;
    final yGap = 4.0;

    TextPainter makeTP(String text, {Color? color}) => TextPainter(
          text: TextSpan(
            text: text,
            style: color != null
                ? params.style.overlayTextStyle.apply(color: color)
                : params.style.overlayTextStyle,
          ),
        )
          ..textDirection = TextDirection.ltr
          ..layout();
    final candle = params.candles[d];
    final info = getOverlayInfo(candle);
    if (info.isEmpty) return;
    final labels = info.keys.map((text) => makeTP(text)).toList();
    final values = info.values.map((text) => makeTP(text)).toList();

    final labelsMaxWidth = labels.map((tp) => tp.width).reduce(max);
    final valuesMaxWidth = values.map((tp) => tp.width).reduce(max);
    final panelWidth = (labelsMaxWidth + valuesMaxWidth) * 2 + xGap * 5;
    // final panelHeight = max(
    //       labels.map((tp) => tp.height).reduce((a, b) => a + b),
    //       values.map((tp) => tp.height).reduce((a, b) => a + b),
    //     ) +
    //     yGap * (values.length + 1);
    final panelHeight = max(labels.map((tp) => tp.height).reduce(max),
                values.map((tp) => tp.height).reduce(max)) *
            (labels.length / 2).ceil() +
        yGap * ((labels.length / 2).ceil() + 1);

    // Shift the canvas, so the overlay panel can appear near touch position.
    canvas.save();
    final ref = params.tapPosition!;
    final mid = ((candle.open ?? 0) + (candle.close ?? 0)) / 2;
    final pos = Offset(ref.dx, params.fitPrice(mid));
    final fingerSize = 30.0; // leave some margin around user's finger
    double dx, dy;
    assert(params.size.width >= panelWidth, "Overlay panel is too wide.");
    if (pos.dx <= params.size.width / 2) {
      // If user touches the left-half of the screen,
      // we show the overlay panel near finger touch position, on the right.
      dx = pos.dx + fingerSize;
    } else {
      // Otherwise we show panel on the left of the finger touch position.
      dx = pos.dx - panelWidth - fingerSize;
    }
    dx = dx.clamp(0, params.size.width - panelWidth);
    dy = pos.dy - panelHeight - fingerSize;
    if (dy < 0) dy = 0.0;
    canvas.translate(dx, dy);

    // Draw the background for overlay panel
    RRect panelRect = RRect.fromRectAndRadius(
      Offset.zero & Size(panelWidth, panelHeight),
      Radius.circular(8),
    );
    var overlayBackgroundColor = params.style.overlayBackgroundColor;
    if (candle.open != null && candle.close != null) {
      if (candle.open! > candle.close!) {
        overlayBackgroundColor = params.style.priceLossColor;
      } else if (candle.open! < candle.close!) {
        overlayBackgroundColor = params.style.priceGainColor;
      } else {
        overlayBackgroundColor = params.style.priceUnchangeColor;
      }
    }
    canvas.drawRRect(panelRect, Paint()..color = overlayBackgroundColor);

    // Draw texts
    var y = 0.0;
    for (int i = 0; i < labels.length; i += 2) {
      y += yGap;
      final rowHeight = max(labels[i].height, values[i].height);
      // Draw labels (left align, vertical center)
      final labelY = y + (rowHeight - labels[i].height) / 2; // vertical center
      labels[i].paint(canvas, Offset(xGap, labelY));
      // Draw values (right align, vertical center)
      final leading = valuesMaxWidth - values[i].width; // right align
      final valueY = y + (rowHeight - values[i].height) / 2; // vertical center
      values[i].paint(
        canvas,
        Offset(labelsMaxWidth + xGap * 2 + leading, valueY),
      );

      // second column
      if (labels.at(i + 1) != null) {
        labels[i + 1].paint(
            canvas,
            Offset(panelWidth - valuesMaxWidth - xGap * 2 - labelsMaxWidth,
                labelY));
        values[i + 1]
            .paint(canvas, Offset(panelWidth - xGap - valuesMaxWidth, valueY));
      }

      y += rowHeight;
    }

    canvas.restore();

    var additionalChart = params.additionalChart;
    if (additionalChart.values.length > 0) {
      final info = additionalChart.labels;
      final labels = info.keys
          .mapIndexed((i, t) =>
              makeTP(t + ':', color: params.additionalChart.colors[i]))
          .toList();
      final values =
          info.values.map((f) => makeTP(f(d, additionalChart.values))).toList();
      if (labels.length == 0) return;
      var bgHeight = 24.0;
      // Track occpuied
      occupied.addAll([dy, panelRect.bottom]);
      for (int i = 0; i < additionalChart.values.length; i++) {
        double? v = additionalChart.values[i].at(d);
        if (v != null) {
          canvas.save();
          var y = params.fitPrice(v);
          // check overlap
          var py = getEmptySpace(y - bgHeight / 2, 24);

          //draw
          final rowHeight = max(labels[i].height, values[i].height);
          final rowWidth = labels[i].width + values[i].width + 24.0;
          var px = pos.dx <= params.size.width / 2
              ? pos.dx + fingerSize
              : pos.dx - fingerSize - rowWidth;
          canvas.translate(px, py);
          final rect = RRect.fromRectAndRadius(
            Offset.zero & Size(rowWidth, bgHeight),
            Radius.circular(8),
          );
          canvas.drawRRect(rect, Paint()..color = Colors.black87);

          final labelY =
              yGap + (rowHeight - labels[i].height) / 2; // vertical center
          labels[i].paint(canvas, Offset(xGap, labelY));

          // Draw values (right align, vertical center)
          final valueY =
              yGap + (rowHeight - values[i].height) / 2; // vertical center
          values[i].paint(
            canvas,
            Offset(rect.width - values[i].width - xGap, valueY),
          );

          canvas.restore();
        }
      }
    }
  }

  /// [below] indicates prefer putting below overlapped item, auto placement if null
  double getEmptySpace(double y, double height) {
    for (int j = 0; j < occupied.length; j += 2) {
      double top1 = y;
      double bottom1 = top1 + height;
      double top2 = occupied[j];
      double bottom2 = top2 + occupied[j + 1];
      if (!(bottom1 < top2 || top1 > bottom2)) {
        // overlapped
        double ry1 = (top2 - y).abs();
        double ry2 = (bottom2 - y).abs();
        return getEmptySpace(bottom2 + 1, height);
      }
    }
    //0046purple
    // insert to occupied (sorted)
    int j = 0;
    for (j = 0; j < occupied.length; j += 2) {
      if (occupied[j] >= y) break;
    }
    occupied.insertAll(j, [y, height]);
    return y;
  }

  void _drawSubcharts(Canvas canvas, PainterParams params) {
    for (int i = 0; i < params.subcharts.length; ++i) {
      canvas.save();
      canvas.clipRect(Offset.zero &
          Size(
              params.chartWidth,
              params.chartHeight +
                  params.style.timeLabelHeight +
                  params.chartSpacing +
                  params.subchartHeight * (i + 1)));
      // draw background
      canvas.translate(
          0.0,
          params.chartHeight +
              params.style.timeLabelHeight +
              params.chartSpacing +
              params.subchartHeight * i.toDouble());
      RRect rect = RRect.fromRectAndRadius(
        Offset.zero & Size(params.chartWidth, params.style.subchartHeight),
        Radius.zero,
      );
      canvas.drawRRect(rect, Paint()..color = Colors.transparent);

      var subchart = params.subcharts[i];
      var pathFill = [];
      var pathFillColor = [];
      var values = subchart.values;
      var minValue = subchart.min;
      var maxValue = subchart.max;
      for (int j = 0; j < values.length; ++j) {
        var leading = subchart.leading[j];
        var trailing = subchart.trailing[j];
        var range = subchart.values[j];
        var color = subchart.colors.at(j) ?? Colors.transparent;
        var hist = subchart.hist.contains(j);

        if (minValue == null ||
            maxValue == null ||
            minValue.isNaN ||
            maxValue.isNaN) continue;

        // draw lines
        for (int k = 0; k < range.length; k++) {
          final x = params.xShift + k * params.candleWidth;
          final pt = range.at(k);
          if (pt == null) continue;
          //
          if (hist) {
            final thickWidth = max(params.candleWidth * 0.8, 0.8);
            canvas.drawLine(
                Offset(x, params.fitPriceForSubchart(0, maxValue, minValue)),
                Offset(x, params.fitPriceForSubchart(pt, maxValue, minValue)),
                Paint()
                  ..strokeWidth = thickWidth
                  ..color = color);
            continue;
          }
          //
          final paint = Paint()
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round
            ..color = color;

          final prevPt = range.at(k - 1);
          if (prevPt != null) {
            canvas.drawLine(
              Offset(x - params.candleWidth,
                  params.fitPriceForSubchart(prevPt, maxValue, minValue)),
              Offset(x, params.fitPriceForSubchart(pt, maxValue, minValue)),
              paint,
            );
          }
          if (k == 0) {
            // In the front, draw an extra line connecting to out-of-window data
            if (leading != null) {
              canvas.drawLine(
                Offset(x - params.candleWidth,
                    params.fitPriceForSubchart(leading, maxValue, minValue)),
                Offset(x, params.fitPriceForSubchart(pt, maxValue, minValue)),
                paint,
              );
            }
          } else if (k == range.length - 1) {
            // At the end, draw an extra line connecting to out-of-window data
            if (trailing != null) {
              canvas.drawLine(
                Offset(x, params.fitPriceForSubchart(pt, maxValue, minValue)),
                Offset(
                  x + params.candleWidth,
                  params.fitPriceForSubchart(trailing, maxValue, minValue),
                ),
                paint,
              );
            }
          }
        }

        // fill pair
        if (subchart.pair != null && subchart.pair!.contains(j)) {
          var data = range;
          var path = Path();

          path.moveTo(params.xShift + 0 - params.candleWidth,
              params.subchartHeight); // include leading
          if (leading != null) {
            path.lineTo(params.xShift + 0 - params.candleWidth,
                params.fitPriceForSubchart(leading, maxValue, minValue));
          }
          for (int j = 0; j < data.length; j++) {
            final x = params.xShift + j * params.candleWidth;
            final pt = data.at(j) ?? 0;
            double y = params.fitPriceForSubchart(pt, maxValue, minValue);
            path.lineTo(x, y);
          }
          if (trailing != null) {
            path.lineTo(params.xShift + data.length * params.candleWidth,
                params.fitPriceForSubchart(trailing, maxValue, minValue));
            path.lineTo(params.xShift + data.length * params.candleWidth,
                params.subchartHeight); // include trailing
          } else {
            path.lineTo(params.xShift + (data.length - 1) * params.candleWidth,
                params.subchartHeight); // include trailing
          }
          path.close();
          pathFill.add(path);
          pathFillColor.add(color);
        }
      }
      if (pathFill.length == 2) {
        final paint1 = Paint();
        paint1.color = pathFillColor[0].withOpacity(.4);
        paint1.style = PaintingStyle.fill;
        canvas.drawPath(
            Path.combine(
              PathOperation.difference,
              pathFill[0],
              pathFill[1],
            ),
            paint1);

        final paint2 = Paint();
        paint2.color = pathFillColor[1].withOpacity(.4);
        paint2.style = PaintingStyle.fill;
        canvas.drawPath(
            Path.combine(
              PathOperation.difference,
              pathFill[1],
              pathFill[0],
            ),
            paint2);
      }
      canvas.restore();
    }
  }

  void _drawChartLabels(Canvas canvas, PainterParams params) {
    var c = params.additionalChart;
    var keys = c.labels.keys;
    var labelTps = keys
        .mapIndexed((i, e) => TextPainter(
              text: TextSpan(
                text: e,
                style: params.style.overlayTextStyle.apply(color: c.colors[i]),
              ),
            )
              ..textDirection = TextDirection.ltr
              ..layout())
        .toList();
    var labelX = 0.0;
    for (int i = 0; i < labelTps.length; i++) {
      labelTps[i].paint(canvas, Offset(labelX + 8, 12));
      labelX += labelTps[i].width + 24;
    }
  }

  void _drawSubchartLabels(Canvas canvas, PainterParams params) {
    for (int i = 0; i < params.subcharts.length; ++i) {
      var c = params.subcharts[i];

      if (c.values.length == 0) continue;
      double? maxValue = c.max;
      double? minValue = c.min;
      bool zeroLine = c.zeroLine;
      if (maxValue == null || minValue == null) continue;
      var by = params.chartHeight +
          params.style.timeLabelHeight +
          params.chartSpacing +
          params.subchartHeight * i;

      // Draw indicator labels
      var labels = c.labels;
      var labelTps = labels.keys
          .mapIndexed((i, e) => TextPainter(
                text: TextSpan(
                  text: e,
                  style:
                      params.style.overlayTextStyle.apply(color: c.colors[i]),
                ),
              )
                ..textDirection = TextDirection.ltr
                ..layout())
          .toList();
      var labelX = 0.0;
      for (int i = 0; i < labelTps.length; i++) {
        labelTps[i].paint(
            canvas,
            Offset(
              labelX + 8,
              by,
            ));
        labelX += labelTps[i].width + 24;
      }

      if (zeroLine) {
        canvas.drawLine(
          Offset(0, by + params.fitPriceForSubchart(0, maxValue, minValue)),
          Offset(params.chartWidth,
              by + params.fitPriceForSubchart(0, maxValue, minValue)),
          Paint()
            ..strokeWidth = 0.5
            ..color = params.style.priceGridLineColor,
        );
        final priceTp = TextPainter(
          text: TextSpan(
            text: getPriceLabel(0),
            style: params.style.priceLabelStyle,
          ),
        )
          ..textDirection = TextDirection.ltr
          ..layout();
        priceTp.paint(
            canvas,
            Offset(
              params.chartWidth + 4,
              by +
                  params.fitPriceForSubchart(0, maxValue, minValue) -
                  priceTp.height / 2,
            ));
      } else {
        [0.25, 0.75]
            .map((v) => ((maxValue - minValue) * v) + minValue)
            .forEach((y) {
          canvas.drawLine(
            Offset(0, by + params.fitPriceForSubchart(y, maxValue, minValue)),
            Offset(params.chartWidth,
                by + params.fitPriceForSubchart(y, maxValue, minValue)),
            Paint()
              ..strokeWidth = 0.5
              ..color = params.style.priceGridLineColor,
          );
          final priceTp = TextPainter(
            text: TextSpan(
              text: getPriceLabel(y),
              style: params.style.priceLabelStyle,
            ),
          )
            ..textDirection = TextDirection.ltr
            ..layout();
          priceTp.paint(
              canvas,
              Offset(
                params.chartWidth + 4,
                by +
                    params.fitPriceForSubchart(y, maxValue, minValue) -
                    priceTp.height / 2,
              ));
        });
      }
    }
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) =>
      params.shouldRepaint(oldDelegate.params);
}

extension ElementAtOrNull<E> on List<E> {
  E? at(int index) {
    if (index < 0 || index >= length) return null;
    return elementAt(index);
  }
}
