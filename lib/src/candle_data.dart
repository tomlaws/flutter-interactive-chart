class CandleData {
  /// The timestamp of this data point, in milliseconds since epoch.
  final int timestamp;

  /// The "open" price of this data point. It's acceptable to have null here for
  /// a few data points, but they must not all be null. If either [open] or
  /// [close] is null for a data point, it will appear as a gap in the chart.
  final double? open;

  /// The "high" price. If either one of [high] or [low] is null, we won't
  /// draw the narrow part of the candlestick for that data point.
  final double? high;

  /// The "low" price. If either one of [high] or [low] is null, we won't
  /// draw the narrow part of the candlestick for that data point.
  final double? low;

  /// The "close" price of this data point. It's acceptable to have null here
  /// for a few data points, but they must not all be null. If either [open] or
  /// [close] is null for a data point, it will appear as a gap in the chart.
  final double? close;

  /// The volume information of this data point.
  final double? volume;

  /// Data holder for additional trend lines, for this data point.
  ///
  /// For a single trend line, we can assign it as a list with a single element.
  /// For example if we want "7 days moving average", do something like
  /// `trends = [ma7]`. If there are multiple tread lines, we can assign a list
  /// with multiple elements, like `trends = [ma7, ma30]`.
  /// If we don't want any trend lines, we can assign an empty list.
  ///
  /// This should be an unmodifiable list, so please do not use `add`
  /// or `clear` methods on the list. Always assign a new list if values
  /// are changed. Otherwise the UI might not be updated.
  List<double?> trends;

  CandleData({
    required this.timestamp,
    required this.open,
    required this.close,
    required this.volume,
    this.high,
    this.low,
    List<double?>? trends,
  }) : this.trends = List.unmodifiable(trends ?? []);

  static List<double?> computeMA(List<CandleData> data, [int period = 7]) {
    // If data is not at least twice as long as the period, return nulls.
    if (data.length < period * 2) return List.filled(data.length, null);

    final List<double?> result = [];
    // Skip the first [period] data points. For example, skip 7 data points.
    final firstPeriod =
        data.take(period).map((d) => d.close).whereType<double>();
    double ma = firstPeriod.reduce((a, b) => a + b) / firstPeriod.length;
    result.addAll(List.filled(period, null));

    // Compute the moving average for the rest of the data points.
    for (int i = period; i < data.length; i++) {
      final curr = data[i].close;
      final prev = data[i - period].close;
      if (curr != null && prev != null) {
        ma = (ma * period + curr - prev) / period;
        result.add(ma);
      } else {
        result.add(null);
      }
    }
    return result;
  }

  static List<double?> _ema(List<double?> inReal, int inTimePeriod, double k1) {
    try {
      List<double?> outReal = List<double?>.filled(inReal.length, null);
      int lookbackTotal = inTimePeriod - 1;
      int startIdx = lookbackTotal;
      int today = startIdx - lookbackTotal;
      int i = inTimePeriod;
      double tempReal = 0.0;
      for (; i > 0;) {
        tempReal += inReal.elementAt(today) ?? 0.0;
        today++;
        i--;
      }
      double prevMA = tempReal / inTimePeriod;
      for (; today <= startIdx;) {
        prevMA = (((inReal.elementAt(today) ?? 0) - prevMA) * k1) + prevMA;
        today++;
      }
      outReal[startIdx] = prevMA;
      var outIdx = startIdx + 1;
      for (; today < inReal.length;) {
        prevMA = (((inReal.elementAt(today) ?? 0) - prevMA) * k1) + prevMA;
        outReal[outIdx] = prevMA;
        today++;
        outIdx++;
      }
      return outReal;
    } catch (ex) {
      return List.filled(inReal.length, null);
    }
  }

  static List<double?> computeEMA(List<CandleData> data, int inTimePeriod) {
    final k = 2.0 / (inTimePeriod + 1);
    final outReal = _ema(data.map((e) => e.close).toList(), inTimePeriod, k);
    return outReal;
  }

  static List<double?> _rsi(List inReal, int inTimePeriod) {
    List<double?> outReal = List<double?>.filled(inReal.length, null);
    if (inTimePeriod < 2) {
      return outReal;
    }

    var tempValue1 = 0.0;
    var tempValue2 = 0.0;
    var outIdx = inTimePeriod;
    var today = 0;
    var prevValue = inReal.elementAt(today);
    var prevGain = 0.0;
    var prevLoss = 0.0;
    today++;
    for (var i = inTimePeriod; i > 0; i--) {
      tempValue1 = inReal.elementAt(today);
      today++;
      tempValue2 = tempValue1 - prevValue;
      prevValue = tempValue1;
      if (tempValue2 < 0) {
        prevLoss -= tempValue2;
      } else {
        prevGain += tempValue2;
      }
    }
    prevLoss /= inTimePeriod;
    prevGain /= inTimePeriod;
    if (today > 0) {
      tempValue1 = prevGain + prevLoss;
      if (!((-0.00000000000001 < tempValue1) &&
          (tempValue1 < 0.00000000000001))) {
        outReal[outIdx] = 100.0 * (prevGain / tempValue1);
      } else {
        outReal[outIdx] = 0.0;
      }
      outIdx++;
    } else {
      for (; today < 0;) {
        tempValue1 = inReal.elementAt(today);
        tempValue2 = tempValue1 - prevValue;
        prevValue = tempValue1;
        prevLoss *= inTimePeriod - 1;
        prevGain *= inTimePeriod - 1;
        if (tempValue2 < 0) {
          prevLoss -= tempValue2;
        } else {
          prevGain += tempValue2;
        }
        prevLoss /= inTimePeriod;
        prevGain /= inTimePeriod;
        today++;
      }
    }
    for (; today < inReal.length;) {
      tempValue1 = inReal.elementAt(today);
      today++;
      tempValue2 = tempValue1 - prevValue;
      prevValue = tempValue1;
      prevLoss *= inTimePeriod - 1;
      prevGain *= inTimePeriod - 1;
      if (tempValue2 < 0) {
        prevLoss -= tempValue2;
      } else {
        prevGain += tempValue2;
      }
      prevLoss /= inTimePeriod;
      prevGain /= inTimePeriod;
      tempValue1 = prevGain + prevLoss;
      if (!((-0.00000000000001 < tempValue1) &&
          (tempValue1 < 0.00000000000001))) {
        outReal[outIdx] = 100.0 * (prevGain / tempValue1);
      } else {
        outReal[outIdx] = 0.0;
      }
      outIdx++;
    }
    return outReal;
  }

  static List<double?> computeRSI(List<CandleData> data, int inTimePeriod) {
    final outReal = _rsi(data.map((e) => e.close).toList(), inTimePeriod);
    return outReal;
  }

  static List<List<double?>> _macd(List<double?> inReal, int inFastPeriod,
      int inSlowPeriod, int inSignalPeriod) {
    if (inSlowPeriod < inFastPeriod) {
      inSlowPeriod = inFastPeriod;
      inFastPeriod = inSlowPeriod;
    }

    var k1 = 0.0;
    var k2 = 0.0;
    if (inSlowPeriod != 0) {
      k1 = 2.0 / (inSlowPeriod + 1).toDouble();
    } else {
      inSlowPeriod = 26;
      k1 = 0.075;
    }
    if (inFastPeriod != 0) {
      k2 = 2.0 / (inFastPeriod + 1).toDouble();
    } else {
      inFastPeriod = 12;
      k2 = 0.15;
    }
    final lookbackSignal = inSignalPeriod - 1;
    var lookbackTotal = lookbackSignal;
    lookbackTotal += inSlowPeriod - 1;
    final fastEMABuffer = _ema(inReal, inFastPeriod, k2);
    final slowEMABuffer = _ema(inReal, inSlowPeriod, k1);
    for (var i = 0; i < fastEMABuffer.length; i++) {
      final fastEMABufferElt = fastEMABuffer.elementAt(i) ?? 0.0;
      final slowEMABufferElt = slowEMABuffer.elementAt(i) ?? 0.0;
      fastEMABuffer[i] = fastEMABufferElt - slowEMABufferElt;
    }
    List<double?> outMACD = List.filled(inReal.length, 0.0);
    for (var i = lookbackTotal - 1; i < fastEMABuffer.length; i++) {
      outMACD[i] = fastEMABuffer.elementAt(i);
    }
    final outMACDSignal =
        _ema(outMACD, inSignalPeriod, (2.0 / (inSignalPeriod + 1).toDouble()));
    final outMACDHist = List.filled(inReal.length, 0.0);
    for (var i = lookbackTotal; i < outMACDHist.length; i++) {
      final outMacdElt = outMACD.elementAt(i) ?? 0.0;
      final outMACDSignalElt = outMACDSignal.elementAt(i) ?? 0.0;
      outMACDHist[i] = outMacdElt - outMACDSignalElt;
    }
    return [
      outMACDHist,
      outMACD,
      outMACDSignal,
    ]; // ,divergence, macd, signal,
  }

  static List<List<double?>> computeMACD(List<CandleData> data,
      int inFastPeriod, int inSlowPeriod, int inSignalPeriod) {
    final outReal = _macd(data.map((e) => e.close).toList(), inFastPeriod,
        inSlowPeriod, inSignalPeriod);
    return outReal;
  }

  @override
  String toString() => "<CandleData ($timestamp: $close)>";
}
