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

  Subchart._raw(
      {required this.data,
      required this.colors,
      required this.hist,
      required this.pair});

  Subchart.rsi(List<CandleData> candles)
      : this._raw(
            colors: [Colors.blue.shade50],
            data: [CandleData.computeRSI(candles, 14)],
            hist: [],
            pair: null);

  Subchart.macd(List<CandleData> candles)
      : this._raw(
            colors: [
              Colors.white,
              Colors.green,
              Colors.red,
            ],
            data: CandleData.computeMACD(candles, 12, 26, 9),
            hist: [0],
            pair: [1, 2]);

  List<SubchartRange> getRange(int start, int end) {
    var flat = data.expand((i) => i.getRange(start, end).toList()).toList();
    double? maxValue;
    double? minValue;
    try {
      maxValue = flat.map((v) => v).whereType<double>().reduce(max);
      minValue = flat.map((v) => v).whereType<double>().reduce(min);
    } catch (ex) {}
    return data
        .map((e) => SubchartRange(
            colors: colors,
            leading: e.at(start - 1),
            trailing: e.at(end + 1),
            values: e.getRange(start, end).toList(),
            hist: hist,
            pair: pair,
            min: minValue,
            max: maxValue))
        .toList();
  }
}

class SubchartRange {
  final double? leading;
  final double? trailing;
  final List<double?> values;
  final List<Color> colors;
  final List<int?> hist; //histogram
  final List<int>? pair;
  final double? min;
  final double? max;
  SubchartRange(
      {required this.leading,
      required this.trailing,
      required this.values,
      required this.colors,
      required this.hist,
      required this.pair,
      required this.min,
      required this.max});

  SubchartRange lerp(SubchartRange another, t) {
    return SubchartRange(
        leading: another.leading,
        trailing: another.trailing,
        values: another.values,
        colors: another.colors,
        hist: another.hist,
        pair: another.pair,
        min: (min != null && another.min != null)
            ? lerpDouble(min, another.min, t)
            : another.min,
        max: (max != null && another.max != null)
            ? lerpDouble(max, another.max, t)
            : another.max);
  }
}
