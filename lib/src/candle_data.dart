import 'dart:math' as math;

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

  static List<double?> _var(List<double?> inReal, int inTimePeriod) {
    List<double?> outReal = List.filled(inReal.length, null);
    final nbInitialElementNeeded = inTimePeriod - 1;
    final startIdx = nbInitialElementNeeded;
    var periodTotal1 = 0.0;
    var periodTotal2 = 0.0;
    var trailingIdx = startIdx - nbInitialElementNeeded;
    var i = trailingIdx;
    if (inTimePeriod > 1) {
      for (; i < startIdx;) {
        var tempReal = inReal.elementAt(i);
        if (tempReal == null) continue;
        periodTotal1 += tempReal;
        tempReal *= tempReal;
        periodTotal2 += tempReal;
        i++;
      }
    }
    var outIdx = startIdx;
    for (var ok = true; ok;) {
      var tempReal = inReal.elementAt(i);
      if (tempReal == null) continue;
      periodTotal1 += tempReal;
      tempReal *= tempReal;
      periodTotal2 += tempReal;
      final meanValue1 = periodTotal1 / inTimePeriod;
      final meanValue2 = periodTotal2 / inTimePeriod;
      tempReal = inReal.elementAt(trailingIdx);
      periodTotal1 -= tempReal!;
      tempReal *= tempReal;
      periodTotal2 -= tempReal;
      outReal[outIdx] = meanValue2 - meanValue1 * meanValue1;
      i++;
      trailingIdx++;
      outIdx++;
      ok = i < inReal.length;
    }
    return outReal;
  }

  static List<double?> _stdDev(
      List<double?> inReal, int inTimePeriod, double inNbDev) {
    final outReal = _var(inReal, inTimePeriod);
    if (inNbDev != 1.0) {
      for (var i = 0; i < inReal.length; i++) {
        final tempReal = outReal.elementAt(i);
        if (tempReal == null) continue;
        if (!(tempReal < 0.00000000000001)) {
          outReal[i] = math.sqrt(tempReal) * inNbDev;
        } else {
          outReal[i] = 0.0;
        }
      }
    } else {
      for (var i = 0; i < inReal.length; i++) {
        final tempReal = outReal.elementAt(i);
        if (tempReal == null) continue;
        if (!(tempReal < 0.00000000000001)) {
          outReal[i] = math.sqrt(tempReal);
        } else {
          outReal[i] = 0.0;
        }
      }
    }
    return outReal;
  }

  static List<double?> _sma(List<double?> inReal, int inTimePeriod) {
    List<double?> outReal = List.filled(inReal.length, null);
    final lookbackTotal = inTimePeriod - 1;
    final startIdx = lookbackTotal;
    var periodTotal = 0.0;
    var trailingIdx = startIdx - lookbackTotal;
    var i = trailingIdx;
    if (inTimePeriod > 1) {
      for (; i < startIdx;) {
        if (inReal.elementAt(i) == null) continue;
        periodTotal += inReal.elementAt(i)!;
        i++;
      }
    }

    var outIdx = startIdx;
    for (var ok = true; ok;) {
      if (inReal.elementAt(i) == null) continue;
      periodTotal += inReal.elementAt(i)!;
      final tempReal = periodTotal;
      if (inReal.elementAt(trailingIdx) == null) continue;
      periodTotal -= inReal.elementAt(trailingIdx)!;
      outReal[outIdx] = tempReal / inTimePeriod;
      trailingIdx++;
      i++;
      outIdx++;
      ok = i < outReal.length;
    }
    return outReal;
  }

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
  }

  static List<double?> computeEMA(List<CandleData> data, int inTimePeriod) {
    try {
      final k = 2.0 / (inTimePeriod + 1);
      final outReal = _ema(data.map((e) => e.close).toList(), inTimePeriod, k);
      return outReal;
    } catch (ex) {
      return List.filled(data.length, null);
    }
  }

  static List<double?> _wma(List<double> inReal, int inTimePeriod) {
    List<double?> outReal = List.filled(inReal.length, null);
    final lookbackTotal = inTimePeriod - 1;
    final startIdx = lookbackTotal;
    if (inTimePeriod == 1) {
      outReal = List.from(inReal);
      return outReal;
    }

    final divider = (inTimePeriod * (inTimePeriod + 1)) >> 1;
    var outIdx = inTimePeriod - 1;
    var trailingIdx = startIdx - lookbackTotal;
    var periodSum = 0.0;
    var periodSub = 0.0;
    var inIdx = trailingIdx;
    var i = 1;
    for (; inIdx < startIdx;) {
      final tempReal = inReal.elementAt(inIdx);
      periodSub += tempReal;
      periodSum += tempReal * i;
      inIdx++;
      i++;
    }
    var trailingValue = 0.0;
    for (; inIdx < inReal.length;) {
      final tempReal = inReal.elementAt(inIdx);
      periodSub += tempReal;
      periodSub -= trailingValue;
      periodSum += tempReal * inTimePeriod;
      trailingValue = inReal.elementAt(trailingIdx);
      outReal[outIdx] = periodSum / divider;
      periodSum -= periodSub;
      inIdx++;
      trailingIdx++;
      outIdx++;
    }
    return outReal;
  }

  static List<double?> computeWMA(List<CandleData> data, int inTimePeriod) {
    try {
      final outReal =
          _wma(data.map((e) => e.close ?? 0).toList(), inTimePeriod);
      return outReal;
    } catch (ex) {
      return List.filled(data.length, null);
    }
  }

  static List<List<double?>> _bbands(List<double?> inReal, int inTimePeriod,
      double inNbDevUp, double inNbDevDn) {
    List<double?> outRealUpperBand = List.filled(inReal.length, null);
    final outRealMiddleBand = _sma(inReal, inTimePeriod);
    List<double?> outRealLowerBand = List.filled(inReal.length, null);
    final tempBuffer2 = _stdDev(inReal, inTimePeriod, 1.0);
    if (inNbDevUp == inNbDevDn) {
      if (inNbDevUp == 1.0) {
        for (var i = 0; i < inReal.length; i++) {
          final tempReal = tempBuffer2.elementAt(i);
          final tempReal2 = outRealMiddleBand.elementAt(i);
          if (tempReal == null || tempReal2 == null) continue;
          outRealUpperBand[i] = tempReal2 + tempReal;
          outRealLowerBand[i] = tempReal2 - tempReal;
        }
      } else {
        for (var i = 0; i < inReal.length; i++) {
          if (tempBuffer2.elementAt(i) == null) continue;
          final tempReal = tempBuffer2.elementAt(i)! * inNbDevUp;
          final tempReal2 = outRealMiddleBand.elementAt(i);
          if (tempReal2 == null) continue;
          outRealUpperBand[i] = tempReal2 + tempReal;
          outRealLowerBand[i] = tempReal2 - tempReal;
        }
      }
    } else if (inNbDevUp == 1.0) {
      for (var i = 0; i < inReal.length; i++) {
        final tempReal = tempBuffer2.elementAt(i);
        final tempReal2 = outRealMiddleBand.elementAt(i);
        if (tempReal == null || tempReal2 == null) continue;
        outRealUpperBand[i] = tempReal2 + tempReal;
        outRealLowerBand[i] = tempReal2 - (tempReal * inNbDevDn);
      }
    } else if (inNbDevDn == 1.0) {
      for (var i = 0; i < inReal.length; i++) {
        final tempReal = tempBuffer2.elementAt(i);
        final tempReal2 = outRealMiddleBand.elementAt(i);
        if (tempReal == null || tempReal2 == null) continue;
        outRealLowerBand[i] = tempReal2 - tempReal;
        outRealUpperBand[i] = tempReal2 + (tempReal * inNbDevUp);
      }
    } else {
      for (var i = 0; i < inReal.length; i++) {
        final tempReal = tempBuffer2.elementAt(i);
        final tempReal2 = outRealMiddleBand.elementAt(i);
        if (tempReal == null || tempReal2 == null) continue;
        outRealUpperBand[i] = tempReal2 + (tempReal * inNbDevUp);
        outRealLowerBand[i] = tempReal2 - (tempReal * inNbDevDn);
      }
    }

    return [outRealUpperBand, outRealMiddleBand, outRealLowerBand];
  }

  static List<List<double?>> computeBBands(List<CandleData> data,
      int inTimePeriod, double inNbDevUp, double inNbDevDn) {
    try {
      final outReal = _bbands(data.map((e) => e.close).toList(), inTimePeriod,
          inNbDevUp, inNbDevDn);

      return outReal;
    } catch (ex) {
      return [
        List.filled(data.length, null),
        List.filled(data.length, null),
        List.filled(data.length, null)
      ];
    }
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
    try {
      final outReal = _rsi(data.map((e) => e.close).toList(), inTimePeriod);
      return outReal;
    } catch (ex) {
      return List.filled(data.length, null);
    }
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
    if (outMACDSignal.length != inReal.length) {
      throw new Error();
    }
    return [
      outMACDHist,
      outMACD,
      outMACDSignal,
    ]; // ,divergence, macd, signal,
  }

  static List<List<double?>> computeMACD(List<CandleData> data,
      int inFastPeriod, int inSlowPeriod, int inSignalPeriod) {
    try {
      final outReal = _macd(data.map((e) => e.close).toList(), inFastPeriod,
          inSlowPeriod, inSignalPeriod);

      return outReal;
    } catch (ex) {
      return [
        List.filled(data.length, null),
        List.filled(data.length, null),
        List.filled(data.length, null)
      ];
    }
  }

  static List<double?> _roc(List<double?> inReal, int inTimePeriod) {
    List<double?> outReal = List<double?>.filled(inReal.length, null);
    final startIdx = inTimePeriod;
    var outIdx = inTimePeriod;
    var inIdx = startIdx;
    var trailingIdx = startIdx - inTimePeriod;
    for (; inIdx < inReal.length;) {
      final tempReal = inReal.elementAt(trailingIdx);
      if (tempReal == null || inReal.elementAt(inIdx) == null) continue;
      if (tempReal != 0.0) {
        outReal[outIdx] = ((inReal.elementAt(inIdx)! / tempReal) - 1.0) * 100.0;
      } else {
        outReal[outIdx] = 0.0;
      }
      trailingIdx++;
      outIdx++;
      inIdx++;
    }
    return outReal;
  }

  static List<double?> computeROC(List<CandleData> data, int inTimePeriod) {
    try {
      final outReal = _roc(data.map((e) => e.close).toList(), inTimePeriod);
      return outReal;
    } catch (ex) {
      return List.filled(data.length, null);
    }
  }

  static List<double> _minusDM(List inHigh, List inLow, int inTimePeriod) {
    List<double> outReal = List.filled(inHigh.length, 0.0);
    var lookbackTotal = 1;
    if (inTimePeriod > 1) {
      lookbackTotal = inTimePeriod - 1;
    }

    final startIdx = lookbackTotal;
    var outIdx = startIdx;
    var today = startIdx;
    var prevHigh = 0.0;
    var prevLow = 0.0;
    if (inTimePeriod <= 1) {
      today = startIdx - 1;
      prevHigh = inHigh.elementAt(today);
      prevLow = inLow.elementAt(today);
      for (; today < inHigh.length - 1;) {
        today++;
        var tempReal = inHigh.elementAt(today);
        final diffP = tempReal - prevHigh;
        prevHigh = tempReal;
        tempReal = inLow.elementAt(today);
        final diffM = prevLow - tempReal;
        prevLow = tempReal;
        if ((diffM > 0) && (diffP < diffM)) {
          outReal[outIdx] = diffM;
        } else {
          outReal[outIdx] = 0;
        }
        outIdx++;
      }
      return outReal;
    }

    var prevMinusDM = 0.0;
    today = startIdx - lookbackTotal;
    prevHigh = inHigh.elementAt(today);
    prevLow = inLow.elementAt(today);
    var i = inTimePeriod - 1;
    for (; i > 0;) {
      i--;
      today++;
      var tempReal = inHigh.elementAt(today);
      final diffP = tempReal - prevHigh;
      prevHigh = tempReal;
      tempReal = inLow.elementAt(today);
      final diffM = prevLow - tempReal;
      prevLow = tempReal;
      if ((diffM > 0) && (diffP < diffM)) {
        prevMinusDM += diffM;
      }
    }
    i = 0;
    for (; i != 0;) {
      i--;
      today++;
      var tempReal = inHigh.elementAt(today);
      final diffP = tempReal - prevHigh;
      prevHigh = tempReal;
      tempReal = inLow.elementAt(today);
      final diffM = prevLow - tempReal;
      prevLow = tempReal;
      if ((diffM > 0) && (diffP < diffM)) {
        prevMinusDM = prevMinusDM - (prevMinusDM / inTimePeriod) + diffM;
      } else {
        prevMinusDM = prevMinusDM - (prevMinusDM / inTimePeriod);
      }
    }
    outReal[startIdx] = prevMinusDM;
    outIdx = startIdx + 1;
    for (; today < inHigh.length - 1;) {
      today++;
      var tempReal = inHigh.elementAt(today);
      final diffP = tempReal - prevHigh;
      prevHigh = tempReal;
      tempReal = inLow.elementAt(today);
      final diffM = prevLow - tempReal;
      prevLow = tempReal;
      if ((diffM > 0) && (diffP < diffM)) {
        prevMinusDM = prevMinusDM - (prevMinusDM / inTimePeriod) + diffM;
      } else {
        prevMinusDM = prevMinusDM - (prevMinusDM / inTimePeriod);
      }
      outReal[outIdx] = prevMinusDM;
      outIdx++;
    }
    return outReal;
  }

  static List<double?> _sar(List<double> inHigh, List<double> inLow,
      double inAcceleration, double inMaximum) {
    List<double?> outReal = List<double?>.filled(inHigh.length, null);
    var af = inAcceleration;
    if (af > inMaximum) {
      af = inMaximum;
      inAcceleration = inMaximum;
    }

    final epTemp = _minusDM(inHigh, inLow, 1);
    var isLong = 1;
    if (epTemp.elementAt(1) > 0) {
      isLong = 0;
    }

    const startIdx = 1;
    var outIdx = startIdx;
    var todayIdx = startIdx;
    var newHigh = inHigh.elementAt(todayIdx - 1);
    var newLow = inLow.elementAt(todayIdx - 1);
    var sar = 0.0;
    var ep = 0.0;
    if (isLong == 1) {
      ep = inHigh.elementAt(todayIdx);
      sar = newLow;
    } else {
      ep = inLow.elementAt(todayIdx);
      sar = newHigh;
    }
    newLow = inLow.elementAt(todayIdx);
    newHigh = inHigh.elementAt(todayIdx);
    var prevLow = 0.0;
    var prevHigh = 0.0;
    for (; todayIdx < inHigh.length;) {
      prevLow = newLow;
      prevHigh = newHigh;
      newLow = inLow.elementAt(todayIdx);
      newHigh = inHigh.elementAt(todayIdx);
      todayIdx++;
      if (isLong == 1) {
        if (newLow <= sar) {
          isLong = 0;
          sar = ep;
          if (sar < prevHigh) {
            sar = prevHigh;
          }

          if (sar < newHigh) {
            sar = newHigh;
          }

          outReal[outIdx] = sar;
          outIdx++;
          af = inAcceleration;
          ep = newLow;
          sar = sar + af * (ep - sar);
          if (sar < prevHigh) {
            sar = prevHigh;
          }

          if (sar < newHigh) {
            sar = newHigh;
          }
        } else {
          outReal[outIdx] = sar;
          outIdx++;
          if (newHigh > ep) {
            ep = newHigh;
            af += inAcceleration;
            if (af > inMaximum) {
              af = inMaximum;
            }
          }

          sar = sar + af * (ep - sar);
          if (sar > prevLow) {
            sar = prevLow;
          }

          if (sar > newLow) {
            sar = newLow;
          }
        }
      } else {
        if (newHigh >= sar) {
          isLong = 1;
          sar = ep;
          if (sar > prevLow) {
            sar = prevLow;
          }

          if (sar > newLow) {
            sar = newLow;
          }

          outReal[outIdx] = sar;
          outIdx++;
          af = inAcceleration;
          ep = newHigh;
          sar = sar + af * (ep - sar);
          if (sar > prevLow) {
            sar = prevLow;
          }

          if (sar > newLow) {
            sar = newLow;
          }
        } else {
          outReal[outIdx] = sar;
          outIdx++;
          if (newLow < ep) {
            ep = newLow;
            af += inAcceleration;
            if (af > inMaximum) {
              af = inMaximum;
            }
          }

          sar = sar + af * (ep - sar);
          if (sar < prevHigh) {
            sar = prevHigh;
          }

          if (sar < newHigh) {
            sar = newHigh;
          }
        }
      }
    }
    return outReal;
  }

  static List<double?> computeSAR(
      List<CandleData> data, double inAcceleration, double inMaximum) {
    try {
      final outReal = _sar(data.map((e) => e.high ?? 0).toList(),
          data.map((e) => e.low ?? 0).toList(), inAcceleration, inMaximum);
      return outReal;
    } catch (ex) {
      return List.filled(data.length, null);
    }
  }

  @override
  String toString() => "<CandleData ($timestamp: $close)>";
}
