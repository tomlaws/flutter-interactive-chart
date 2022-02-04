import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ];
  static List<Subchart> availableSubchartOptions = [
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
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            titlePadding: EdgeInsets.all(16),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            actionsPadding: EdgeInsets.all(8),
            title: const Text('設定'),
            content: SingleChildScrollView(
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
                      TextButton(
                          onPressed: () {
                            showParamConfigDialog(
                                cloneAdditionalChart, context);
                          },
                          child: Text('參數')),
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
                                      value: availableSubchartOptions
                                          .firstWhere((element) =>
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
                                      items: availableSubchartOptions
                                          .where((element) =>
                                              !cloneSubcharts
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
                                      onPressed: () {
                                        showParamConfigDialog(
                                            cloneSubcharts[i], context);
                                      },
                                      child: Text('參數')),
                                ])
                              ]))
                      .toList())
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  TextButton(
                    child: const Text('重設'),
                    onPressed: () {
                      reset(cloneAdditionalChart, cloneSubcharts);
                      setState(() {});
                    },
                  ),
                  Expanded(
                    child: Container(),
                  ),
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
              )
            ],
          );
        });
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

  static Future<bool> showParamConfigDialog(
      Subchart subchart, BuildContext context) async {
    Subchart cloneSubchart = subchart.cloneWithoutData();

    var confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        final _formKey = GlobalKey<FormState>();
        return Form(
          key: _formKey,
          child: StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              titlePadding: EdgeInsets.all(16),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              actionsPadding: EdgeInsets.all(8),
              title: const Text('參數設定'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: cloneSubchart.params.mapIndexed((i, e) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom:
                              (i == cloneSubchart.params.length - 1 ? 0 : 8.0)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '參數 ${i + 1}',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Container(width: 16),
                          // IconButton(
                          //   splashRadius: 16,
                          //   icon: Icon(
                          //     Icons.remove,
                          //     color: Colors.white,
                          //   ),
                          //   padding: EdgeInsets.symmetric(
                          //       vertical: 0.0, horizontal: 4.0),
                          //   iconSize: 16.0,
                          //   color: Theme.of(context).primaryColor,
                          //   onPressed: () {
                          //     setState(() {
                          //       if (e is double && cloneSubchart.params[i].toString().contains('.')) {
                          //         var p =  cloneSubchart.params[i].toString().split('.');
                          //         cloneSubchart.params[i]
                          //       } else {

                          //       }
                          //       var precision = cloneSubchart.params[i].toString().split('.')
                          //       cloneSubchart.params[i] -=
                          //           e is double ? 0.1 : 1;
                          //       cloneSubchart.params[i] = cloneSubchart
                          //           .params[i]
                          //           .clamp(e is double ? 0.01 : 1, 999);
                          //       cloneSubchart.params = [
                          //         ...cloneSubchart.params
                          //       ];
                          //     });
                          //   },
                          // ),
                          Expanded(
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                e is double
                                    ? FilteringTextInputFormatter.allow(
                                        RegExp('[0-9.,]+'))
                                    : FilteringTextInputFormatter.digitsOnly
                              ],
                              style: TextStyle(fontSize: 14),
                              key:
                                  Key(cloneSubchart.params.hashCode.toString()),
                              initialValue: e.toString(),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                isCollapsed: true,
                                contentPadding: EdgeInsets.all(8),
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              onSaved: (value) {
                                if (value == null) return;
                                cloneSubchart.params[i] = e is double
                                    ? (double.tryParse(value) ?? e)
                                    : (int.tryParse(value) ?? e);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '不能為空';
                                }
                                if (!(e is double || e is int))
                                  return '請輸入正確數值';
                                if (e is double) {
                                  if (double.tryParse(value) == null) {
                                    return '請輸入正確數值';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          // IconButton(
                          //   splashRadius: 16,
                          //   icon: Icon(
                          //     Icons.add,
                          //     color: Colors.white,
                          //   ),
                          //   padding: EdgeInsets.symmetric(
                          //       vertical: 0.0, horizontal: 4.0),
                          //   iconSize: 16.0,
                          //   color: Theme.of(context).primaryColor,
                          //   onPressed: () {
                          //     setState(() {
                          //       cloneSubchart.params[i] +=
                          //           e is double ? 0.1 : 1;
                          //       cloneSubchart.params[i] = cloneSubchart
                          //           .params[i]
                          //           .clamp(e is double ? 0.01 : 1, 999);
                          //       cloneSubchart.params = [
                          //         ...cloneSubchart.params
                          //       ];
                          //     });
                          //   },
                          // ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                Row(
                  children: [
                    TextButton(
                      child: const Text('重設'),
                      onPressed: () {
                        resetParams(cloneSubchart);
                        setState(() {});
                      },
                    ),
                    Expanded(
                      child: Container(),
                    ),
                    TextButton(
                      child: const Text('取消'),
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                    ),
                    TextButton(
                      child: const Text('確定'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          Navigator.pop(context, true);
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          }),
        );
      },
    );
    if (confirm == true) {
      subchart.replace(cloneSubchart);
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

  static void reset(Subchart additionalChart, List<Subchart> subcharts) {
    subcharts.clear();
    subcharts.addAll(defaultSubchartOptions.map((e) => e.cloneWithoutData()));
    additionalChart
        .replace(Config.defaultAdditionalChartOptions[0].cloneWithoutData());
  }

  static void resetParams(Subchart cloneSubchart) {
    cloneSubchart.params = [
      ...defaultAdditionalChartOptions,
      ...availableSubchartOptions
    ]
        .firstWhere((element) => element.indicator == cloneSubchart.indicator)
        .cloneWithoutData()
        .params;
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
