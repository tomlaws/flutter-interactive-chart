import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

import '../interactive_chart.dart';

class Config {
  static final List<Subchart> defaultAdditionalChartOptions = [
    Subchart.sma(),
    Subchart.ema(),
    Subchart.wma(),
    Subchart.sar(),
    Subchart.bollinger(),
  ];
  static List<Subchart> defaultSubchartOptions = [
    Subchart.roc(),
    Subchart.rsi(),
    Subchart.macd(),
    Subchart.mom()
  ];

  static Future<bool> showConfigDialog(Subchart additionalChart,
      List<Subchart> subcharts, BuildContext context) async {
    Subchart cloneAdditionalChart = additionalChart.cloneWithoutData();
    List<Subchart> cloneSubcharts =
        subcharts.map((e) => e.cloneWithoutData()).toList();

    var confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: EdgeInsets.all(16),
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          actionsPadding: EdgeInsets.all(8),
          title: const Text('設定'),
          content: StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              child: ListBody(
                children: [
                  Text(
                    '主圖層',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Container(
                    height: 8,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<Subchart>(
                          value: defaultAdditionalChartOptions.firstWhere(
                              (element) =>
                                  element.indicator ==
                                  cloneAdditionalChart.indicator),
                          onChanged: (Subchart? newValue) {
                            if (newValue != null) {
                              setState(() {
                                cloneAdditionalChart =
                                    newValue.cloneWithoutData();
                              });
                            }
                          },
                          items: defaultAdditionalChartOptions
                              .map<DropdownMenuItem<Subchart>>(
                                  (Subchart value) {
                            return DropdownMenuItem<Subchart>(
                              value: value,
                              child: Text(value.indicator.label),
                            );
                          }).toList(),
                          isDense: true,
                          isExpanded: true,
                        ),
                      ),
                      TextButton(onPressed: () {}, child: Text('參數')),
                    ],
                  ),
                  ...(defaultSubchartOptions
                      .mapIndexed((i, e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    '圖層 ${i + 1}',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                                Row(children: [
                                  Expanded(
                                    child: DropdownButton<Subchart>(
                                      value: defaultSubchartOptions.firstWhere(
                                          (element) =>
                                              element.indicator ==
                                              cloneSubcharts[i].indicator),
                                      onChanged: (Subchart? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            cloneSubcharts[i] =
                                                newValue.cloneWithoutData();
                                          });
                                        }
                                      },
                                      items: defaultSubchartOptions
                                          .where((element) =>
                                              !subcharts
                                                  .map((e) => e.indicator)
                                                  .contains(
                                                      element.indicator) ||
                                              cloneSubcharts[i].indicator ==
                                                  element.indicator)
                                          .map<DropdownMenuItem<Subchart>>(
                                              (Subchart value) {
                                        return DropdownMenuItem<Subchart>(
                                          value: value,
                                          child: Text(value.indicator.label),
                                        );
                                      }).toList(),
                                      isDense: true,
                                      isExpanded: true,
                                    ),
                                  ),
                                  TextButton(
                                      onPressed: () {}, child: Text('參數')),
                                ])
                              ]))
                      .toList())
                ],
              ),
            );
          }),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            TextButton(
              child: const Text('確定'),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      additionalChart.replace(cloneAdditionalChart);
      subcharts.clear();
      subcharts.addAll(cloneSubcharts);
      await saveConfig(additionalChart, subcharts);
      return true;
    }
    return false;
  }

  static Future<void> saveConfig(
      Subchart additionalChart, List<Subchart> subcharts) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('additionalChart', jsonEncode(additionalChart));
      prefs.setString('subcharts', jsonEncode(subcharts));
    } catch (ex) {
      print(ex);
    }
  }

  static Future<void> setAdditionalChart(Subchart additionalChart) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('additionalChart', jsonEncode(additionalChart));
    } catch (ex) {
      print(ex);
    }
  }

  static Future<void> loadConfig(
      Subchart additionalChart, List<Subchart> subcharts) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // Load default setting
      subcharts.clear();
      subcharts.addAll(defaultSubchartOptions.map((e) => e.cloneWithoutData()));
      if (prefs.containsKey('additionalChart')) {
        Map<String, dynamic> json =
            jsonDecode(prefs.getString('additionalChart')!);
        additionalChart.replace(Subchart.fromJson(json));
      }
      if (prefs.containsKey('subcharts')) {
        List<dynamic> jsonSubcharts = jsonDecode(prefs.getString('subcharts')!);
        // Length equals to default options
        if (jsonSubcharts.length == defaultSubchartOptions.length) {
          subcharts.clear();
          subcharts
              .addAll(jsonSubcharts.map((e) => Subchart.fromJson(e)).toList());
        }
      }
    } catch (ex) {
      print(ex);
    }
  }
}
