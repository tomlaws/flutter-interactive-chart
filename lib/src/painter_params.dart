import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'dart:math';

import 'chart_style.dart';
import 'candle_data.dart';

class PainterParams {
  final List<CandleData> candles;
  final SubchartRange additionalChart;
  final List<SubchartRange> subcharts;

  final ChartStyle style;
  final Size size;
  final double candleWidth;
  final double startOffset;

  final double maxPrice;
  final double minPrice;
  final double maxVol;
  final double minVol;

  final double xShift;
  final Offset? tapPosition;
  final List<double?>? leadingTrends;
  final List<double?>? trailingTrends;
  PainterParams({
    required this.candles,
    required this.additionalChart,
    required this.subcharts,
    required this.style,
    required this.size,
    required this.candleWidth,
    required this.startOffset,
    required this.maxPrice,
    required this.minPrice,
    required this.maxVol,
    required this.minVol,
    required this.xShift,
    required this.tapPosition,
    required this.leadingTrends,
    required this.trailingTrends,
  });

  double get chartWidth => // width without price labels
      size.width - style.priceLabelWidth;

  double get chartSpacing => 4;

  double get subchartHeight => // height without time labels
      style.subchartHeight;

  double get subchartsHeight =>
      chartSpacing + (subcharts.length * (style.subchartHeight));

  double get chartHeight => // height without time labels
      max(320, size.height - style.timeLabelHeight - subchartsHeight);

  double get volumeHeight => chartHeight * style.volumeHeightFactor;

  double get priceHeight => chartHeight - volumeHeight;

  double get chartsHeight =>
      subchartsHeight + chartHeight + style.timeLabelHeight;

  int getCandleIndexFromOffset(double x) {
    final adjustedPos = x - xShift + candleWidth / 2;
    final i = adjustedPos ~/ candleWidth;
    return i;
  }

  double paddingY = 36.0;
  double fitPrice(double y) =>
      paddingY +
      (priceHeight - paddingY * 2) * (maxPrice - y) / (maxPrice - minPrice);

  double subchartPaddingY = 24.0;
  double fitPriceForSubchart(double y, double max, double min) =>
      subchartPaddingY +
      (subchartHeight - subchartPaddingY * 2) *
          (max - y) /
          ((max - min) == 0 ? 1 : (max - min));

  double fitVolume(double y) {
    final gap = 12; // the gap between price bars and volume bars
    final baseAmount = 2; // display at least "something" for the lowest volume
    final diff = maxVol - minVol;
    if (diff == 0) {
      return priceHeight + volumeHeight * 0.25;
    }
    final volGridSize = (volumeHeight - baseAmount - gap) / diff;
    final vol = (y - minVol) * volGridSize;
    return volumeHeight - vol + priceHeight - baseAmount;
  }

  /// two sides +/-
  double fitVolumeForSubchart(double y, double max, double min, double height) {
    final baseAmount = 4; // double
    var diff = max - min;
    if (diff == 0) {
      diff = 1;
    }
    final volGridSize = (height * 2 - baseAmount) / diff;
    final vol = (y - 0) * volGridSize;
    return vol + height;
  }

  static PainterParams lerp(PainterParams a, PainterParams b, double t) {
    double lerpField(double getField(PainterParams p)) =>
        lerpDouble(getField(a), getField(b), t)!;
    // List<List<SubchartRange>> lerpSubchart() {
    //   List<List<SubchartRange>> l1 = [];
    //   for (int i = 0; i < a.subcharts.length; i++) {
    //     List<SubchartRange> l2 = [];
    //     for (int j = 0; j < a.subcharts[i].length; j++) {
    //       l2.add(a.subcharts[i][j].lerp(b.subcharts[i][j], t));
    //     }
    //     l1.add(l2);
    //   }
    //   return l1;
    // }

    return PainterParams(
      candles: b.candles,
      additionalChart: b.additionalChart,
      subcharts: b.subcharts,
      style: b.style,
      size: b.size,
      candleWidth: b.candleWidth,
      startOffset: b.startOffset,
      // disable lerp for now
      // maxPrice: lerpField((p) => p.maxPrice),
      // minPrice: lerpField((p) => p.minPrice),
      // maxVol: lerpField((p) => p.maxVol),
      // minVol: lerpField((p) => p.minVol),
      maxPrice: b.maxPrice,
      minPrice: b.minPrice,
      maxVol: b.maxVol,
      minVol: b.minVol,
      xShift: b.xShift,
      tapPosition: b.tapPosition,
      leadingTrends: b.leadingTrends,
      trailingTrends: b.trailingTrends,
    );
  }

  bool shouldRepaint(PainterParams other) {
    if (candles.length != other.candles.length) return true;

    if (size != other.size ||
        candleWidth != other.candleWidth ||
        startOffset != other.startOffset ||
        xShift != other.xShift) return true;

    if (maxPrice != other.maxPrice ||
        minPrice != other.minPrice ||
        maxVol != other.maxVol ||
        minVol != other.minVol) return true;

    if (tapPosition != other.tapPosition) return true;

    if (leadingTrends != other.leadingTrends ||
        trailingTrends != other.trailingTrends) return true;

    if (additionalChart != other.additionalChart) return true;

    if (style != other.style) return true;

    if (subcharts != other.subcharts) return true;

    return false;
  }
}

class PainterParamsTween extends Tween<PainterParams> {
  PainterParamsTween({
    PainterParams? begin,
    required PainterParams end,
  }) : super(begin: begin, end: end);

  @override
  PainterParams lerp(double t) => PainterParams.lerp(begin ?? end!, end!, t);
}
