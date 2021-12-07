//enum Subchart { rsi }
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'chart_painter.dart';
import 'dart:math';

class Subchart {
  final List<List<double?>> data;
  final List<Color> colors;
  final List<int> hist; //index of data needs to be histogram
  final List<int>? pair; //index of a pair, length must be equal to 2
  final Map<String, String> Function(int index, List<List<double?>> values)
      info;

  Subchart._raw(
      {required this.data,
      required this.colors,
      required this.hist,
      required this.pair,
      required this.info});

  Subchart.rsi(List<CandleData> candles)
      : this._raw(
            colors: [Colors.blue.shade50],
            data: [CandleData.computeRSI(candles, 14)],
            hist: [],
            pair: null,
            info: (i, values) =>
                {'RSI (14):': values[0][i]?.toStringAsFixed(2) ?? '-'});

  Subchart.macd(List<CandleData> candles)
      : this._raw(
            colors: [
              Colors.white,
              Colors.green,
              Colors.red,
            ],
            data: CandleData.computeMACD(candles, 12, 26, 9),
            hist: [0],
            pair: [1, 2],
            info: (i, values) => {
                  'MACD (12,26):': values[1][i]?.toStringAsFixed(2) ?? '-',
                  'Signal (9):': values[2][i]?.toStringAsFixed(2) ?? '-',
                  'Divergence:': values[0][i]?.toStringAsFixed(2) ?? '-',
                });

  SubchartRange getRange(int start, int end) {
    var flat = data.expand((i) => i.getRange(start, end).toList()).toList();
    double? maxValue;
    double? minValue;
    try {
      maxValue = flat.map((v) => v).whereType<double>().reduce(max);
      minValue = flat.map((v) => v).whereType<double>().reduce(min);
    } catch (ex) {}
    return SubchartRange(
        colors: colors,
        leading: data.map((e) => e.at(start - 1)).toList(),
        trailing: data.map((e) => e.at(end + 1)).toList(),
        values: data.map((e) => e.getRange(start, end).toList()).toList(),
        hist: hist,
        pair: pair,
        info: info,
        min: minValue,
        max: maxValue);
  }
}

class SubchartRange {
  final List<double?> leading;
  final List<double?> trailing;
  final List<List<double?>> values;
  final List<Color> colors;

  /// index of [values] that have to be histogram
  final List<int?> hist;

  /// index of [values] that have to be a pair
  final List<int>? pair;
  final double? min;
  final double? max;
  final Map<String, String> Function(int index, List<List<double?>> values)
      info;

  SubchartRange(
      {required this.leading,
      required this.trailing,
      required this.values,
      required this.colors,
      required this.hist,
      required this.pair,
      required this.min,
      required this.max,
      required this.info});

  double yForOverlay(int index) {
    var filtered = values.map((e) => e.at(index)).whereType<double>();
    var sum = filtered.reduce((a, b) => a + b);
    return sum / filtered.length;
  }

  SubchartRange lerp(SubchartRange another, t) {
    return SubchartRange(
        leading: another.leading,
        trailing: another.trailing,
        values: another.values,
        colors: another.colors,
        hist: another.hist,
        pair: another.pair,
        info: info,
        min: (min != null && another.min != null)
            ? lerpDouble(min, another.min, t)
            : another.min,
        max: (max != null && another.max != null)
            ? lerpDouble(max, another.max, t)
            : another.max);
  }
}
