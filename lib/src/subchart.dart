//enum Subchart { rsi }
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'chart_painter.dart';
import 'package:collection/collection.dart';
import 'dart:math';

class Subchart {
  late final List<List<double?>> data;
  final Indicator indicator;
  final List<int> params;
  final List<Color> colors;
  final List<int> hist; //index of data needs to be histogram
  final List<int>? pair; //index of a pair, length must be equal to 2
  final Map<String, String> Function(int index, List<List<double?>> values)
      info;

  final bool zeroLine;

  Subchart._raw(
      {required List<CandleData> candles,
      required this.indicator,
      required this.params,
      required this.colors,
      required this.hist,
      required this.pair,
      required this.info,
      this.zeroLine = false}) {
    data = [];
    switch (indicator) {
      case Indicator.ROC:
        data.add(CandleData.computeROC(candles, params[0]));
        break;
      case Indicator.SMA:
        data.add(CandleData.computeMA(candles, params[0]));
        break;
      case Indicator.WMA:
        // data.add(CandleData.computeWMA(candles, periods[i]));
        break;
      case Indicator.EMA:
        data.add(CandleData.computeEMA(candles, params[0]));
        break;
      case Indicator.Bollinger:
        data.add(CandleData.computeROC(candles, params[0]));
        break;
      case Indicator.SAR:
        data.add(CandleData.computeROC(candles, params[0]));
        break;
      case Indicator.MACD:
        var r =
            CandleData.computeMACD(candles, params[0], params[1], params[2]);
        data.add(r[1]);
        data.add(r[2]);
        data.add(r[0]);
        break;
      case Indicator.RSI:
        data.add(CandleData.computeRSI(candles, params[0]));
        break;
    }
  }

  Subchart.roc(List<CandleData> candles)
      : this._raw(
            colors: [Colors.blue.shade50],
            candles: candles,
            indicator: Indicator.ROC,
            params: [12],
            hist: [0],
            pair: null,
            zeroLine: true,
            info: (i, values) =>
                {'ROC (12):': values[0][i]?.toStringAsFixed(2) ?? '-'});

  Subchart.rsi(List<CandleData> candles)
      : this._raw(
            colors: [Colors.blue.shade50],
            candles: candles,
            indicator: Indicator.RSI,
            params: [14],
            hist: [],
            pair: null,
            info: (i, values) =>
                {'RSI (14):': values[0][i]?.toStringAsFixed(2) ?? '-'});

  Subchart.macd(List<CandleData> candles)
      : this._raw(
            colors: [
              Colors.red,
              Colors.green,
              Colors.white,
            ],
            zeroLine: true,
            params: [12, 26, 9],
            indicator: Indicator.MACD,
            candles: candles,
            hist: [2],
            pair: [0, 1],
            info: (i, values) => {
                  'MACD (12,26):': values[1][i]?.toStringAsFixed(2) ?? '-',
                  'Signal (9):': values[2][i]?.toStringAsFixed(2) ?? '-',
                  'Divergence:': values[0][i]?.toStringAsFixed(2) ?? '-',
                });

  List<String> get labels {
    switch (indicator) {
      case Indicator.SMA:
        return params.map((element) {
          return 'SMA ($element)';
        }).toList();
      case Indicator.WMA:
        return params.map((element) {
          return 'WMA ($element)';
        }).toList();
      case Indicator.EMA:
        return params.map((element) {
          return 'EMA ($element)';
        }).toList();
      case Indicator.RSI:
        return ["RSI"];
      case Indicator.MACD:
        return [
          "MACD (${params[0]},${params[1]})",
          "EMA (${params[2]})",
          "Divergence"
        ];
      case Indicator.Bollinger:
        return params.map((element) {
          return 'SMA ($element)';
        }).toList();
      case Indicator.SAR:
        return params.map((element) {
          return 'SMA ($element)';
        }).toList();
      case Indicator.ROC:
        return ["ROC (${params[0]})"];
    }
  }

  SubchartRange getRange(int start, int end) {
    var flat = data.expand((i) => i.getRange(start, end).toList()).toList();
    double? maxValue;
    double? minValue;
    try {
      maxValue = flat.map((v) => v).whereType<double>().reduce(max);
      minValue = flat.map((v) => v).whereType<double>().reduce(min);
    } catch (ex) {}
    return SubchartRange(
        subchart: this,
        leading: data.map((e) => e.at(start - 1)).toList(),
        trailing: data.map((e) => e.at(end + 1)).toList(),
        values: data.map((e) => e.getRange(start, end).toList()).toList(),
        min: minValue,
        max: maxValue,
        info: info);
  }
}

class SubchartRange {
  final Subchart subchart;
  final List<double?> leading;
  final List<double?> trailing;
  final List<List<double?>> values;

  /// index of [values] that have to be a pair
  final double? min;
  final double? max;
  final Map<String, String> Function(int index, List<List<double?>> values)
      info;

  SubchartRange({
    required this.subchart,
    required this.leading,
    required this.trailing,
    required this.values,
    required this.min,
    required this.max,
    required this.info,
  });

  List<Color> get colors {
    return this.subchart.colors;
  }

  List<int>? get pair {
    return this.subchart.pair;
  }

  List<int> get hist {
    return this.subchart.hist;
  }

  bool get zeroLine {
    return this.subchart.zeroLine;
  }

  List<String> get labels {
    return this.subchart.labels;
  }

  double? yForOverlay(int index) {
    var filtered = values.map((e) => e.at(index)).whereNotNull().toList();
    if (filtered.length == 0) return null;
    var sum = filtered.reduce((a, b) => a + b);
    return sum / filtered.length;
  }

  SubchartRange lerp(SubchartRange another, t) {
    return SubchartRange(
      subchart: subchart,
      leading: another.leading,
      trailing: another.trailing,
      values: another.values,
      info: info,
      min: (min != null && another.min != null)
          ? lerpDouble(min, another.min, t)
          : another.min,
      max: (max != null && another.max != null)
          ? lerpDouble(max, another.max, t)
          : another.max,
    );
  }
}
