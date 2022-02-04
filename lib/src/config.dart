import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../interactive_chart.dart';

class Config {
  static Future<void> showConfigDialog(
      List<Subchart> subcharts, BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('設定'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('主圖層'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('確定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> loadConfig(List<Subchart> subcharts) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('subcharts')) {
        List<dynamic> jsonSubcharts = jsonDecode(prefs.getString('subcharts')!);
        if (jsonSubcharts.length > 0) {
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
