import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:interactive_chart/interactive_chart.dart';
import 'mock_data.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  List<bool> isSelected = [true, false, false];
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
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setup() async {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    }
    _initializing = true;
    await _update();
    _initializing = false;
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _update();
    });
  }

  Future<void> _update() async {
    var url = Uri.parse(
        'https://chart4.spsystem.info/pserver/chartdata_query.php?prod_code=HSIF2&second=$_period');
    var response = await http.get(url);
    var body = response.body;
    var data = body.split(':');
    var candles = data[4].split('\n');
    _candleData = [];
    candles.forEach((e) {
      var splited = e.split(',');
      if (splited.length == 7) {
        //print(splited);
        double open = double.parse(splited[0]);
        double high = double.parse(splited[1]);
        double low = double.parse(splited[2]);
        double close = double.parse(splited[3]);
        double volume = double.parse(splited[4]);
        int timestamp = int.parse(splited[5]) * 1000;
        _candleData.add(CandleData(
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            timestamp: timestamp));
      }
    });
    setState(() {});
  }

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
        appBar: AppBar(
          title: Text("Demo"),
          actions: [
            // IconButton(
            //   icon: Icon(_darkMode ? Icons.dark_mode : Icons.light_mode),
            //   onPressed: () => setState(() => _darkMode = !_darkMode),
            // ),
            // IconButton(
            //   icon: Icon(
            //     _showAverage ? Icons.show_chart : Icons.bar_chart_outlined,
            //   ),
            //   onPressed: () {
            //     setState(() => _showAverage = !_showAverage);
            //     if (_showAverage) {
            //       _computeTrendLines();
            //     } else {
            //       _removeTrendLines();
            //     }
            //   },
            // ),
          ],
        ),
        body: SafeArea(
          minimum: const EdgeInsets.all(24.0),
          child: Column(children: [
            Container(
                margin: EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    height: 36,
                    child: ToggleButtons(
                      //borderRadius: BorderRadius.circular(16),
                      children: _periodLabels
                          .map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('$e'),
                              ))
                          .toList(),
                      onPressed: (int index) {
                        setState(() {
                          for (int i = 0; i < _selectedPeriods.length; i++) {
                            _selectedPeriods[i] = index == i ? true : false;
                          }
                          _period = _periods[index];
                        });
                        _setup();
                      },
                      isSelected: _selectedPeriods,
                    ),
                  ),
                )),
            Container(
              margin: EdgeInsets.only(bottom: 16),
              child: SizedBox(
                height: 36,
                child: ToggleButtons(
                  //borderRadius: BorderRadius.circular(16),
                  children: <Widget>[Text('SMA'), Text('EMA'), Text('SAR')],
                  //renderBorder: false,
                  onPressed: (int index) {
                    setState(() {
                      for (int buttonIndex = 0;
                          buttonIndex < isSelected.length;
                          buttonIndex++) {
                        if (buttonIndex == index) {
                          isSelected[buttonIndex] = true;
                        } else {
                          isSelected[buttonIndex] = false;
                        }
                      }
                      switch (index) {
                        case 0:
                          _indicator = Indicator.SMA;
                          break;
                        case 1:
                          _indicator = Indicator.EMA;
                          break;
                        case 2:
                          _indicator = Indicator.SAR;
                          break;
                      }
                    });
                  },
                  isSelected: isSelected,
                ),
              ),
            ),
            Expanded(
              child: _initializing
                  ? Center(
                      child: Container(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator()),
                    )
                  : _candleData.length == 0
                      ? SizedBox()
                      : Container(
                          color: Colors.black38,
                          child: InteractiveChart(
                            /** Only [candles] is required */
                            period: _period,
                            candles: _candleData,
                            additionalChart:
                                getAdditionalChart(_indicator) ?? Subchart.sma()
                                  ..setCandles(_candleData),
                            subcharts: [
                              Subchart.roc()..setCandles(_candleData),
                              Subchart.rsi()..setCandles(_candleData),
                              Subchart.macd()..setCandles(_candleData),
                            ],
                            initialVisibleCandleCount: 4 * 60,
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
      ),
    );
  }

  Subchart? getAdditionalChart(Indicator ind) {
    switch (ind) {
      case Indicator.SMA:
        return Subchart.sma()..setCandles(_candleData);
      case Indicator.WMA:
        // TODO: Handle this case.
        break;
      case Indicator.EMA:
        return Subchart.ema()..setCandles(_candleData);
      case Indicator.RSI:
        // TODO: Handle this case.
        break;
      case Indicator.MACD:
        // TODO: Handle this case.
        break;
      case Indicator.Bollinger:
        // TODO: Handle this case.
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
