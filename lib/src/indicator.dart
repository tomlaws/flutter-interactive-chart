enum Indicator { SMA, WMA, EMA, RSI, MACD, Bollinger, SAR, ROC }

extension IndicatorExtension on Indicator {
  List<String> labels(List<int> periods) {
    return periods.map((element) {
      return '${this.toString().replaceAll('Indicator.', '')} ($element)';
    }).toList();
  }
}
