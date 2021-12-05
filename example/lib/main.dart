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
  List<bool> isSelected = [true, false];
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
        'https://chart4.spsystem.info/pserver/chartdata_query.php?prod_code=HSIZ1&second=$_period');
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
                  children: <Widget>[Text('SMA'), Text('EMA')],
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
                      : InteractiveChart(
                          /** Only [candles] is required */
                          candles: _candleData,
                          indicator: _indicator,
                          subcharts: [
                            Subchart.rsi(_candleData),
                            Subchart.macd(_candleData)
                          ],
                          initialVisibleCandleCount: 4 * 60,
                          /** Uncomment the following for examples on optional parameters */

                          /** Example styling */
                          style: ChartStyle(
                            // priceGainColor: Colors.teal[200]!,
                            // priceLossColor: Colors.blueGrey,
                            // volumeColor: Colors.teal.withOpacity(0.8),
                            trendLineStyles: [
                              Paint()
                                ..strokeWidth = 1.0
                                ..strokeCap = StrokeCap.round
                                ..color = Colors.red.shade400,
                              Paint()
                                ..strokeWidth = 1.0
                                ..strokeCap = StrokeCap.round
                                ..color = Colors.purple.shade100,
                              Paint()
                                ..strokeWidth = 1.0
                                ..strokeCap = StrokeCap.round
                                ..color = Colors.yellow.shade300,
                              Paint()
                                ..strokeWidth = 1.0
                                ..strokeCap = StrokeCap.round
                                ..color = Colors.indigo.shade200,
                              Paint()
                                ..strokeWidth = 1.0
                                ..strokeCap = StrokeCap.round
                                ..color = Colors.orange.shade400,
                              Paint()
                                ..strokeWidth = 1.0
                                ..strokeCap = StrokeCap.round
                                ..color = Colors.pink.shade200
                            ],
                            // priceGridLineColor: Colors.blue[200]!,
                            // priceLabelStyle: TextStyle(color: Colors.blue[200]),
                            // timeLabelStyle: TextStyle(color: Colors.blue[200]),
                            // selectionHighlightColor: Colors.red.withOpacity(0.2),
                            // overlayBackgroundColor: Colors.red[900]!.withOpacity(0.6),
                            // overlayTextStyle: TextStyle(color: Colors.red[100]),
                            // timeLabelHeight: 32,
                          ),
                          overlayInfo: (CandleData candle) {
                            return {
                              if (_period < 31556926)
                                '日期': new DateFormat('dd/MM').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                        candle.timestamp)),
                              _period < 86400
                                      ? '時間'
                                      : _period < 2592000
                                          ? '日期'
                                          : _period < 31556926
                                              ? '月份'
                                              : '年份':
                                  _formatTimestamp(candle.timestamp),
                              "開": candle.open?.toStringAsFixed(2) ?? "-",
                              "高": candle.high?.toStringAsFixed(2) ?? "-",
                              "低": candle.low?.toStringAsFixed(2) ?? "-",
                              "收": candle.close?.toStringAsFixed(2) ?? "-",
                              "成量": candle.volume?.asAbbreviated() ?? "-",
                            };
                          },
                          /** Customize axis labels */
                          timeLabel: (timestamp, visibleDataCount) {
                            return _formatTimestamp(timestamp);
                          },
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
          ]),
        ),
      ),
    );
  }

  _formatTimestamp(int timestamp) {
    if (_period < 86400)
      return new DateFormat('HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    else if (_period < 2592000)
      return new DateFormat('dd/MM')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    else if (_period < 31556926)
      return new DateFormat('MM')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    else
      return new DateFormat('yy')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  _computeTrendLines() {
    // final ma7 = CandleData.computeMA(_data, 7);
    // final ma30 = CandleData.computeMA(_data, 30);
    // final ma90 = CandleData.computeMA(_data, 90);

    // final ema7 = CandleData.computeEma(_data, 7);
    // final ema30 = CandleData.computeEma(_data, 30);
    // final ema90 = CandleData.computeEma(_data, 90);
    List<List<double?>> set = [];
    switch (_indicator) {
      case Indicator.SMA:
        set = [
          CandleData.computeMA(_candleData, 5),
          CandleData.computeMA(_candleData, 10),
          CandleData.computeMA(_candleData, 20),
          //CandleData.computeMA(_candleData, 50),
          //CandleData.computeMA(_candleData, 100),
          //CandleData.computeMA(_candleData, 150)
        ];
        break;
      case Indicator.EMA:
        set = [
          CandleData.computeEMA(_candleData, 5),
          CandleData.computeEMA(_candleData, 10),
          CandleData.computeEMA(_candleData, 20),
          // CandleData.computeEMA(_candleData, 100),
          // CandleData.computeEMA(_candleData, 150)
        ];
        break;
      default:
        break;
    }
    for (int i = 0; i < _candleData.length; i++) {
      _candleData[i].trends = set.map((s) => s[i]).toList();
    }
    setState(() {});
    //final test = CandleData.computeEmaRaw([10, 22, 15, 50, 40], 5);
    //print(test);
  }

  _removeTrendLines() {
    for (final data in _data) {
      data.trends = [];
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
