enum Indicator { SMA, WMA, EMA, Bollinger, SAR }

extension IndicatorExtension on Indicator {
  List<String> labels(List<int> periods) {
    return periods.map((element) {
      return '${this.toString().replaceAll('Indicator.', '')} ($element)';
    }).toList();
  }
}
