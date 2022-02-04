// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subchart.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subchart _$SubchartFromJson(Map<String, dynamic> json) => Subchart(
      indicator: $enumDecode(_$IndicatorEnumMap, json['indicator']),
      params: (json['params'] as List<dynamic>).map((e) => e as num).toList(),
    );

Map<String, dynamic> _$SubchartToJson(Subchart instance) => <String, dynamic>{
      'indicator': _$IndicatorEnumMap[instance.indicator],
      'params': instance.params,
    };

const _$IndicatorEnumMap = {
  Indicator.SMA: 'SMA',
  Indicator.WMA: 'WMA',
  Indicator.EMA: 'EMA',
  Indicator.RSI: 'RSI',
  Indicator.MACD: 'MACD',
  Indicator.BOLLINGER: 'BOLLINGER',
  Indicator.SAR: 'SAR',
  Indicator.ROC: 'ROC',
  Indicator.MOM: 'MOM',
};
