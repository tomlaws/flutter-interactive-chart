// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subchart.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subchart _$SubchartFromJson(Map<String, dynamic> json) => Subchart(
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => (e as List<dynamic>)
                  .map((e) => (e as num?)?.toDouble())
                  .toList())
              .toList() ??
          const [],
      indicator: $enumDecode(_$IndicatorEnumMap, json['indicator']),
      params: (json['params'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      colors: (json['colors'] as List<dynamic>)
          .map((e) => const ColorConverter().fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$SubchartToJson(Subchart instance) => <String, dynamic>{
      'data': instance.data,
      'indicator': _$IndicatorEnumMap[instance.indicator],
      'params': instance.params,
      'colors': instance.colors.map(const ColorConverter().toJson).toList(),
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
