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
  final List<double> params;
  final List<Color> colors;
  final List<int> hist; //index of data needs to be histogram
  final List<int>? pair; //index of a pair, length must be equal to 2

  final bool zeroLine;

  Subchart._raw(
      {required List<CandleData> candles,
      required this.indicator,
      required this.params,
      required this.colors,
      required this.hist,
      required this.pair,
      this.zeroLine = false}) {
    data = [];
    switch (indicator) {
      case Indicator.ROC:
        data.add(CandleData.computeROC(candles, params[0].toInt()));
        break;
      case Indicator.SMA:
        data.add(CandleData.computeMA(candles, params[0].toInt()));
        data.add(CandleData.computeMA(candles, params[1].toInt()));
        data.add(CandleData.computeMA(candles, params[2].toInt()));
        break;
      case Indicator.EMA:
        data.add(CandleData.computeEMA(candles, params[0].toInt()));
        data.add(CandleData.computeEMA(candles, params[1].toInt()));
        data.add(CandleData.computeEMA(candles, params[2].toInt()));
        break;
      case Indicator.WMA:
        // data.add(CandleData.computeWMA(candles, periods[i]));
        break;
      case Indicator.EMA:
        data.add(CandleData.computeEMA(candles, params[0].toInt()));
        break;
      case Indicator.Bollinger:
        data.add(CandleData.computeROC(candles, params[0].toInt()));
        break;
      case Indicator.SAR:
        data.add(CandleData.computeSAR(candles, params[0], params[1]));
        break;
      case Indicator.MACD:
        var r = CandleData.computeMACD(
            candles, params[0].toInt(), params[1].toInt(), params[2].toInt());
        data.add(r[1]);
        data.add(r[2]);
        data.add(r[0]);
        break;
      case Indicator.RSI:
        data.add(CandleData.computeRSI(candles, params[0].toInt()));
        break;
    }
  }
  Subchart.sma(List<CandleData> candles)
      : this._raw(
          colors: [
            Colors.red.shade400,
            Colors.purple.shade100,
            Colors.yellow.shade300,
          ],
          candles: candles,
          indicator: Indicator.SMA,
          params: [5, 10, 20],
          hist: [],
          pair: null,
        );
  Subchart.ema(List<CandleData> candles)
      : this._raw(
          colors: [
            Colors.red.shade400,
            Colors.purple.shade100,
            Colors.yellow.shade300,
          ],
          candles: candles,
          indicator: Indicator.EMA,
          params: [5, 10, 20],
          hist: [],
          pair: null,
        );
  Subchart.sar(List<CandleData> candles)
      : this._raw(
          colors: [
            Colors.white70,
          ],
          candles: candles,
          indicator: Indicator.SAR,
          params: [0.02, 0.2],
          hist: [],
          pair: null,
        );

  Subchart.roc(List<CandleData> candles)
      : this._raw(
            colors: [Colors.white70],
            candles: candles,
            indicator: Indicator.ROC,
            params: [12],
            hist: [0],
            pair: null,
            zeroLine: true);

  Subchart.rsi(List<CandleData> candles)
      : this._raw(
          colors: [Colors.white70],
          candles: candles,
          indicator: Indicator.RSI,
          params: [14],
          hist: [],
          pair: null,
        );

  Subchart.macd(List<CandleData> candles)
      : this._raw(
            colors: [Colors.red, Colors.green, Colors.white70],
            zeroLine: true,
            params: [12, 26, 9],
            indicator: Indicator.MACD,
            candles: candles,
            hist: [2],
            pair: [0, 1]);

  Map<String, String Function(int index, List<List<double?>> values)>
      get labels {
    switch (indicator) {
      case Indicator.SMA:
        return {
          'SMA (${params[0]})': (i, values) => _formatValue(values[0][i]),
          'SMA (${params[1]})': (i, values) => _formatValue(values[1][i]),
          'SMA (${params[2]})': (i, values) => _formatValue(values[2][i])
        };
      case Indicator.WMA:
        return {
          'WMA (${params[0]})': (i, values) => _formatValue(values[0][i]),
          'WMA (${params[1]})': (i, values) => _formatValue(values[1][i]),
          'WMA (${params[2]})': (i, values) => _formatValue(values[2][i])
        };
      case Indicator.EMA:
        return {
          'EMA (${params[0]})': (i, values) => _formatValue(values[0][i]),
          'EMA (${params[1]})': (i, values) => _formatValue(values[1][i]),
          'EMA (${params[2]})': (i, values) => _formatValue(values[2][i])
        };
      case Indicator.SAR:
        return {
          'SAR (${params[0]},${params[1]})': (i, values) =>
              _formatValue(values[0][i]),
        };
      case Indicator.RSI:
        return {
          'RSI (${params[0]})': (i, values) => _formatValue(values[0][i]),
        };
      case Indicator.MACD:
        return {
          'MACD (${params[0]},${params[1]})': (i, values) =>
              _formatValue(values[0][i]),
          'Signal (${params[2]})': (i, values) => _formatValue(values[1][i]),
          'Divergence': (i, values) => _formatValue(values[2][i])
        };
      case Indicator.Bollinger:
        return {
          'SMA (${params[0]})': (i, values) => _formatValue(values[0][i]),
          'SMA (${params[1]})': (i, values) => _formatValue(values[1][i]),
          'SMA (${params[2]})': (i, values) => _formatValue(values[2][i])
        };
      case Indicator.SAR:
        return {
          'SMA (${params[0]})': (i, values) => _formatValue(values[0][i]),
          'SMA (${params[1]})': (i, values) => _formatValue(values[1][i]),
          'SMA (${params[2]})': (i, values) => _formatValue(values[2][i])
        };
      case Indicator.ROC:
        return {
          "ROC (${params[0]})": (i, values) => _formatValue(values[0][i]),
        };
    }
  }

  bool get dotted {
    switch (indicator) {
      case Indicator.SAR:
        return true;
      default:
        return false;
    }
  }

  String _formatValue(double? v) {
    return v?.toStringAsFixed(2) ?? '-';
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
    );
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

  SubchartRange(
      {required this.subchart,
      required this.leading,
      required this.trailing,
      required this.values,
      required this.min,
      required this.max});

  List<Color> get colors {
    return this.subchart.colors;
  }

  List<int>? get pair {
    return this.subchart.pair;
  }

  List<int> get hist {
    return this.subchart.hist;
  }

  bool get dotted {
    return this.subchart.dotted;
  }

  bool get zeroLine {
    return this.subchart.zeroLine;
  }

  Map<String, String Function(int index, List<List<double?>> values)>
      get labels {
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
      min: (min != null && another.min != null)
          ? lerpDouble(min, another.min, t)
          : another.min,
      max: (max != null && another.max != null)
          ? lerpDouble(max, another.max, t)
          : another.max,
    );
  }
}
