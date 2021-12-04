import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:interactive_chart/src/line.dart';

import 'chart_style.dart';
import 'candle_data.dart';

class PainterParams {
  final List<CandleData> candles;
  final List<List<double?>> additionalTrends;
  final List<String> additionalTrendLabels;

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
  final List<double?>? leadingAdditionalTrends;
  final List<double?>? trailingAdditionalTrends;

  PainterParams(
      {required this.candles,
      required this.additionalTrends,
      required this.additionalTrendLabels,
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
      required this.leadingAdditionalTrends,
      required this.trailingAdditionalTrends});

  double get chartWidth => // width without price labels
      size.width - style.priceLabelWidth;

  double get chartHeight => // height without time labels
      size.height - style.timeLabelHeight;

  double get volumeHeight => chartHeight * style.volumeHeightFactor;

  double get priceHeight => chartHeight - volumeHeight;

  int getCandleIndexFromOffset(double x) {
    final adjustedPos = x - xShift + candleWidth / 2;
    final i = adjustedPos ~/ candleWidth;
    return i;
  }

  double fitPrice(double y) =>
      priceHeight * (maxPrice - y) / (maxPrice - minPrice);

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

  static PainterParams lerp(PainterParams a, PainterParams b, double t) {
    double lerpField(double getField(PainterParams p)) =>
        lerpDouble(getField(a), getField(b), t)!;
    return PainterParams(
      candles: b.candles,
      additionalTrends: b.additionalTrends,
      additionalTrendLabels: b.additionalTrendLabels,
      style: b.style,
      size: b.size,
      candleWidth: b.candleWidth,
      startOffset: b.startOffset,
      maxPrice: lerpField((p) => p.maxPrice),
      minPrice: lerpField((p) => p.minPrice),
      maxVol: lerpField((p) => p.maxVol),
      minVol: lerpField((p) => p.minVol),
      xShift: b.xShift,
      tapPosition: b.tapPosition,
      leadingTrends: b.leadingTrends,
      trailingTrends: b.trailingTrends,
      leadingAdditionalTrends: b.leadingAdditionalTrends,
      trailingAdditionalTrends: b.trailingAdditionalTrends,
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

    if (leadingAdditionalTrends != other.leadingAdditionalTrends ||
        trailingAdditionalTrends != other.trailingAdditionalTrends) return true;

    if (style != other.style) return true;

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
