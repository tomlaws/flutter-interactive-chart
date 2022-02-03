enum Indicator { SMA, WMA, EMA, RSI, MACD, BOLLINGER, SAR, ROC, MOM }

extension IndicatorExtension on Indicator {
  String get label {
    return this.toString().replaceFirst("Indicator.", "").substring(0, 3);
  }
}
