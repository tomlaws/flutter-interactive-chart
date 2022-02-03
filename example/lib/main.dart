import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:interactive_chart/interactive_chart.dart';
import 'mock_data.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<CandleData> _data = MockDataTesla.candles;
  bool _darkMode = true;
  bool _initializing = true;
  Timer? _timer;
  List<CandleData> _candleData = [];
  Indicator _indicator = Indicator.SMA;
  List<bool> isSelected = [true, false, false, false, false];
  static List<int> _periods = [
    60,
    120,
    300,
    600,
    900,
    1800,
    3600,
    7200,
    86400,
    604800,
    2592000,
    31556926
  ];
  static List<String> _periodLabels = [
    "1 分鐘",
    "2 分鐘",
    "5 分鐘",
    "10 分鐘",
    "15 分鐘",
    "30 分鐘",
    "60 分鐘",
    "2 小時",
    "1 日",
    "1 星期",
    "1 月",
    "1 年"
  ];
  List<bool> _selectedPeriods = [
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  ];
  int _period = 60;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: MyCustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          scaffoldBackgroundColor: Color(0xFF222222),
          brightness: _darkMode ? Brightness.dark : Brightness.light,
          backgroundColor: Colors.black),
      home: Scaffold(
        body: Column(children: [
          Expanded(
            child: Container(
              color: Colors.black38,
              child: InteractiveChart(
                /** Only [candles] is required */
                period: _period,
                prodCode: 'HSIG2',
                // additionalChart:
                //     getAdditionalChart(_indicator) ?? Subchart.sma()
                //       ..setCandles(_candleData),

                /** Uncomment the following for examples on optional parameters */

                /** Example styling */
                style: ChartStyle(
                  // priceGainColor: Colors.teal[200]!,
                  // priceLossColor: Colors.blueGrey,
                  // volumeColor: Colors.teal.withOpacity(0.8),
                  trendLineStyles: [],
                  // priceGridLineColor: Colors.blue[200]!,
                  // priceLabelStyle: TextStyle(color: Colors.blue[200]),
                  // timeLabelStyle: TextStyle(color: Colors.blue[200]),
                  // selectionHighlightColor: Colors.red.withOpacity(0.2),
                  // overlayBackgroundColor: Colors.red[900]!.withOpacity(0.6),
                  // overlayTextStyle: TextStyle(color: Colors.red[100]),
                  // timeLabelHeight: 32,
                ),
                /** Customize axis labels */
                // timeLabel: (timestamp, visibleDataCount) {
                //   return _formatTimestamp(timestamp);
                // },
                // priceLabel: (price) => "${price.round()} 💎",
                /** Customize overlay (tap and hold to see it)
                                       ** Or return an empty object to disable overlay info. */
                // overlayInfo: (candle) => {
                //   "💎": "🤚    ",
                //   "Hi": "${candle.high?.toStringAsFixed(2)}",
                //   "Lo": "${candle.low?.toStringAsFixed(2)}",
                // },
                /** Callbacks */
                // onTap: (candle) => print("user tapped on $candle"),
                // onCandleResize: (width) => print("each candle is $width wide"),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Subchart? getAdditionalChart(Indicator ind) {
    switch (ind) {
      case Indicator.SMA:
        return Subchart.sma()..setCandles(_candleData);
      case Indicator.WMA:
        return Subchart.wma()..setCandles(_candleData);
      case Indicator.EMA:
        return Subchart.ema()..setCandles(_candleData);
      case Indicator.RSI:
        // TODO: Handle this case.
        break;
      case Indicator.MACD:
        // TODO: Handle this case.
        break;
      case Indicator.BOLLINGER:
        return Subchart.bollinger()..setCandles(_candleData);
        break;
      case Indicator.SAR:
        return Subchart.sar()..setCandles(_candleData);
      case Indicator.ROC:
        // TODO: Handle this case.
        break;
    }
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
