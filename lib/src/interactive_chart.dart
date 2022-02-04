import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:interactive_chart/src/subchart.dart';
import 'package:intl/intl.dart' as intl;
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'candle_data.dart';
import 'chart_painter.dart';
import 'chart_style.dart';
import 'indicator.dart';
import 'config.dart';

import 'painter_params.dart';
import 'package:http/http.dart' as http;

class InteractiveChart extends StatefulWidget {
  /// The full list of [CandleData] to be used for this chart.
  ///
  /// It needs to have at least 3 data points. If data is sufficiently large,
  /// the chart will default to display the most recent 90 data points when
  /// first opened (configurable with [initialVisibleCandleCount] parameter),
  /// and allow users to freely zoom and pan however they like.
  //final List<CandleData> candles;
  final String prodCode;
  final List<int> periods;
  final List<String> periodLabels;
  final int period;

  /// The default number of data points to be displayed when the chart is first
  /// opened. The default value is 90. If [CandleData] does not have enough data
  /// points, the chart will display all of them.
  final int initialVisibleCandleCount;

  /// If non-null, the style to use for this chart.
  final ChartStyle style;

  /// How the date/time label at the bottom are displayed.
  ///
  /// If null, it defaults to use yyyy-mm format if more than 20 data points
  /// are visible in the current chart window, otherwise it uses mm-dd format.
  final TimeLabelGetter? timeLabel;

  /// How the price labels on the right are displayed.
  ///
  /// If null, it defaults to show 2 digits after the decimal point.
  final PriceLabelGetter? priceLabel;

  /// How the overlay info are displayed, when user touches the chart.
  ///
  /// If null, it defaults to display `date`, `open`, `high`, `low`, `close`
  /// and `volume` fields when user selects a data point in the chart.
  ///
  /// To customize it, pass in a function that returns a Map<String,String>:
  /// ```dart
  /// return {
  ///   "Date": "Customized date string goes here",
  ///   "Open": candle.open?.toStringAsFixed(2) ?? "-",
  ///   "Close": candle.close?.toStringAsFixed(2) ?? "-",
  /// };
  /// ```
  final OverlayInfoGetter? overlayInfo;

  /// An optional event, fired when the user clicks on a candlestick.
  final ValueChanged<CandleData>? onTap;

  /// An optional event, fired when user zooms in/out.
  ///
  /// This provides the width of a candlestick at the current zoom level.
  final ValueChanged<double>? onCandleResize;

  const InteractiveChart({
    Key? key,
    required this.prodCode,
    this.periods = const [
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
    ],
    this.periodLabels = const [
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
    ],
    required this.period,
    this.initialVisibleCandleCount = 45,
    ChartStyle? style,
    this.timeLabel,
    this.priceLabel,
    this.overlayInfo,
    this.onTap,
    this.onCandleResize,
  })  : this.style = style ?? const ChartStyle(),
        // assert(candles.length >= 3,
        //     "InteractiveChart requires 3 or more CandleData"),
        // assert(initialVisibleCandleCount >= 3,
        //     "initialVisibleCandleCount must be more 3 or more"),
        super(key: key);

  @override
  _InteractiveChartState createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart>
    with TickerProviderStateMixin {
  Timer? _timer;
  bool _loading = true;
  List<CandleData> _candles = [];
  late int _period;
  // The width of an individual bar in the chart.
  late double _candleWidth;

  // The x offset (in px) of current visible chart window,
  // measured against the beginning of the chart.
  // i.e. a value of 0.0 means we are displaying data for the very first day,
  // and a value of 20 * _candleWidth would be skipping the first 20 days.
  late double _startOffset;

  // The position that user is currently tapping, null if user let go.
  Offset? _tapPosition;

  double? _prevChartWidth; // used by _handleResize
  late double _prevCandleWidth;
  late double _prevStartOffset;
  late Offset _initialFocalPoint;
  PainterParams? _prevParams; // used in onTapUp event

  late Subchart _activeAdditionalChart =
      Config.defaultAdditionalChartOptions[0].cloneWithoutData();
  late List<Subchart> _subcharts = [];

  late TabController periodTabController;
  late TabController additionalChartTabController;

  @override
  void initState() {
    super.initState();
    _period = widget.periods[0];
    periodTabController =
        TabController(length: widget.periods.length, vsync: this);
    additionalChartTabController = TabController(
        length: Config.defaultAdditionalChartOptions.length, vsync: this);
    _setup();
  }

  Future<bool> _setup() async {
    await Config.loadConfig(_activeAdditionalChart, _subcharts);
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    }
    _loading = true;
    await _update();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _update();
    });
    _loading = false;
    return true;
  }

  @override
  void dispose() {
    periodTabController.dispose();
    additionalChartTabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _update({bool reset = false}) async {
    var url = Uri.parse(
        'https://chart4.spsystem.info/pserver/chartdata_query.php?prod_code=${widget.prodCode}&second=$_period');
    var response = await http.get(url);
    var body = response.body;
    var data = body.split(':');
    var candles = data[4].split('\n');
    _candles = [];
    candles.forEach((e) {
      var splited = e.split(',');
      if (splited.length == 7) {
        double open = double.parse(splited[0]);
        double high = double.parse(splited[1]);
        double low = double.parse(splited[2]);
        double close = double.parse(splited[3]);
        double volume = double.parse(splited[4]);
        int timestamp = int.parse(splited[5]) * 1000;
        _candles.add(CandleData(
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            timestamp: timestamp));
      }
    });
    if (reset) {
      _prevStartOffset = _startOffset = double.infinity;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    int tabIndex = Config.defaultAdditionalChartOptions.indexWhere(
        (element) => element.indicator == _activeAdditionalChart.indicator);
    if (additionalChartTabController.index != tabIndex) {
      additionalChartTabController.index = tabIndex;
    }
    return Column(children: [
      Container(
        color: Colors.black54,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: additionalChartTabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  isScrollable: true,
                  tabs: Config.defaultAdditionalChartOptions
                      .map((e) => Tab(
                            text: e.indicator.label,
                          ))
                      .toList(),
                  onTap: (i) {
                    setState(() {
                      _activeAdditionalChart = Config
                          .defaultAdditionalChartOptions[i]
                          .cloneWithoutData()
                        ..setCandles(_candles);
                      Config.setAdditionalChart(_activeAdditionalChart);
                    });
                  },
                ),
              ),
              IconButton(
                iconSize: 16,
                icon: Icon(Icons.settings),
                onPressed: () async {
                  bool confirm = await Config.showConfigDialog(
                      _activeAdditionalChart, _subcharts, context);
                  if (confirm) {
                    setState(() {});
                  }
                },
              )
            ],
          ),
          Container(
            width: double.infinity,
            child: TabBar(
              controller: periodTabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              isScrollable: true,
              tabs: widget.periodLabels
                  .map((e) => Tab(
                        text: e,
                      ))
                  .toList(),
              onTap: (i) {
                _period = widget.periods[i];
                _update(reset: true);
              },
            ),
          ),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final size = Size(
                constraints.biggest.width,
                max(
                    constraints.biggest.height,
                    widget.style.subchartHeight * _subcharts.length +
                        widget.style.timeLabelHeight +
                        320));
            final w = size.width - widget.style.priceLabelWidth;
            _handleResize(w);
            // Find the visible data range
            final int start = (_startOffset / _candleWidth).floor();
            final int count = (w / _candleWidth).ceil();
            final int end = (start + count).clamp(start, _candles.length);

            final candlesInRange = _candles.getRange(start, end).toList();

            _activeAdditionalChart.setCandles(_candles);
            final additionalChartInRange = _activeAdditionalChart.getRange(
                start, end < _candles.length ? end + 1 : end);

            if (end < _candles.length) {
              // Put in an extra item, since it can become visible when scrolling
              final nextItem = _candles[end];
              candlesInRange.add(nextItem);
            }

            // If possible, find neighbouring trend line data,
            // so the chart could draw better-connected lines
            final leadingTrends = _candles.at(start - 1)?.trends;
            final trailingTrends = _candles.at(end + 1)?.trends;

            // Find the horizontal shift needed when drawing the candles.
            // First, always shift the chart by half a candle, because when we
            // draw a line using a thick paint, it spreads to both sides.
            // Then, we find out how much "fraction" of a candle is visible, since
            // when users scroll, they don't always stop at exact intervals.
            final halfCandle = _candleWidth / 2;
            final fractionCandle = _startOffset - start * _candleWidth;
            final xShift = halfCandle - fractionCandle;

            // Calculate min and max among the visible data
            double? highest(CandleData c) {
              if (c.high != null) return c.high;
              if (c.open != null && c.close != null)
                return max(c.open!, c.close!);
              return c.open ?? c.close;
            }

            double? lowest(CandleData c) {
              if (c.low != null) return c.low;
              if (c.open != null && c.close != null)
                return min(c.open!, c.close!);
              return c.open ?? c.close;
            }

            var maxPrice =
                candlesInRange.map(highest).whereType<double>().reduce(max);
            var minPrice =
                candlesInRange.map(lowest).whereType<double>().reduce(min);

            // fix max min by additional chart
            maxPrice = max(additionalChartInRange.max ?? maxPrice, maxPrice);
            minPrice = min(additionalChartInRange.min ?? minPrice, minPrice);

            final maxVol = candlesInRange
                .map((c) => c.volume)
                .whereType<double>()
                .reduce(max);
            final minVol = candlesInRange
                .map((c) => c.volume)
                .whereType<double>()
                .reduce(min);

            // subcharts
            List<SubchartRange> subchartsInRange = [];
            for (int i = 0; i < _subcharts.length; ++i) {
              var subchart = _subcharts[i]..setCandles(_candles);
              subchartsInRange.add(subchart.getRange(
                  start, end < _candles.length ? end + 1 : end));
            }

            final child = TweenAnimationBuilder(
              tween: PainterParamsTween(
                end: PainterParams(
                  candles: candlesInRange,
                  additionalChart: additionalChartInRange,
                  subcharts: subchartsInRange,
                  style: widget.style,
                  size: size,
                  candleWidth: _candleWidth,
                  startOffset: _startOffset,
                  maxPrice: maxPrice,
                  minPrice: minPrice,
                  maxVol: maxVol,
                  minVol: minVol,
                  xShift: xShift,
                  tapPosition: _tapPosition,
                  leadingTrends: leadingTrends,
                  trailingTrends: trailingTrends,
                ),
              ),
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (_, PainterParams params, __) {
                _prevParams = params;
                return RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: ChartPainter(
                      params: params,
                      getTimeLabel: widget.timeLabel ?? defaultTimeLabel,
                      getPriceLabel: widget.priceLabel ?? defaultPriceLabel,
                      getOverlayInfo: widget.overlayInfo ?? defaultOverlayInfo,
                    ),
                  ),
                );
              },
            );

            return SingleChildScrollView(
              child: Listener(
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    final dy = signal.scrollDelta.dy;
                    if (dy.abs() > 0) {
                      _onScaleStart(signal.position);
                      _onScaleUpdate(
                        dy > 0 ? 0.9 : 1.1,
                        signal.position,
                        w,
                      );
                    }
                  }
                },
                child: GestureDetector(
                  // Tap and hold to view candle details
                  onTapDown: (details) => setState(() {
                    _tapPosition = details.localPosition;
                  }),
                  onTapCancel: () => setState(() => _tapPosition = null),
                  onTapUp: (_) {
                    setState(() => _tapPosition = null);
                    // Fire callback event (if needed)
                    if (widget.onTap != null) _fireOnTapEvent();
                  },
                  // Pan and zoom
                  onScaleStart: (details) =>
                      _onScaleStart(details.localFocalPoint),
                  onScaleUpdate: (details) =>
                      _onScaleUpdate(details.scale, details.localFocalPoint, w),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  _onScaleStart(Offset focalPoint) {
    _prevCandleWidth = _candleWidth;
    _prevStartOffset = _startOffset;
    _initialFocalPoint = focalPoint;
  }

  _onScaleUpdate(double scale, Offset focalPoint, double w) {
    // Handle zoom
    final candleWidth = (_prevCandleWidth * scale)
        .clamp(_getMinCandleWidth(w), _getMaxCandleWidth(w));
    final clampedScale = candleWidth / _prevCandleWidth;
    var startOffset = _prevStartOffset * clampedScale;
    // Handle pan
    final dx = (focalPoint - _initialFocalPoint).dx * -1;
    startOffset += dx;
    // Adjust pan when zooming
    final double prevCount = w / _prevCandleWidth;
    final double currCount = w / candleWidth;
    final zoomAdjustment = (currCount - prevCount) * candleWidth;
    final focalPointFactor = focalPoint.dx / w;
    startOffset -= zoomAdjustment * focalPointFactor;
    startOffset = startOffset.clamp(0, _getMaxStartOffset(w, candleWidth));
    // Fire candle width resize event
    if (candleWidth != _candleWidth) {
      widget.onCandleResize?.call(candleWidth);
    }
    // Apply changes
    setState(() {
      _candleWidth = candleWidth;
      _startOffset = startOffset;
    });
  }

  _handleResize(double w) {
    // if (w == _prevChartWidth) return;
    if (_prevChartWidth != null) {
      // Re-clamp when size changes (e.g. screen rotation)
      _candleWidth = _candleWidth.clamp(
        _getMinCandleWidth(w),
        _getMaxCandleWidth(w),
      );
      _startOffset = _startOffset.clamp(
        0,
        _getMaxStartOffset(w, _candleWidth),
      );
    } else {
      // Default zoom level. Defaults to a 90 day chart, but configurable.
      // If data is shorter, we use the whole range.
      final count = min(
        _candles.length,
        widget.initialVisibleCandleCount,
      );
      _candleWidth = w / count;
      // Default show the latest available data, e.g. the most recent 90 days.
      _startOffset = (_candles.length - count) * _candleWidth;
    }
    _prevChartWidth = w;
  }

  // The narrowest candle width, i.e. when drawing all available data points.
  double _getMinCandleWidth(double w) => w / _candles.length;

  // The widest candle width, e.g. when drawing 14 day chart
  double _getMaxCandleWidth(double w) => w / min(14, _candles.length);

  // Max start offset: how far can we scroll towards the end of the chart
  double _getMaxStartOffset(double w, double candleWidth) {
    final count = w / candleWidth; // visible candles in the window
    final start = _candles.length - count;
    return max(0, candleWidth * start);
  }

  String defaultTimeLabel(int timestamp, int visibleDataCount) {
    return _formatTimestamp(timestamp);
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp)
        .toIso8601String()
        .split("T")
        .first
        .split("-");

    if (visibleDataCount > 20) {
      // If more than 20 data points are visible, we should show year and month.
      return "${date[0]}-${date[1]}"; // yyyy-mm
    } else {
      // Otherwise, we should show month and date.
      return "${date[1]}-${date[2]}"; // mm-dd
    }
  }

  String defaultPriceLabel(double price) => price.toStringAsFixed(2);

  _formatTimestamp(int timestamp) {
    if (widget.period < 86400)
      return new DateFormat('HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    else if (widget.period < 2592000)
      return new DateFormat('dd/MM')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    else if (widget.period < 31556926)
      return new DateFormat('MM')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    else
      return new DateFormat('yyyy')
          .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Map<String, String> defaultOverlayInfo(CandleData candle) {
    return {
      if (widget.period < 2592000)
        '日期': new DateFormat('dd/MM')
            .format(DateTime.fromMillisecondsSinceEpoch(candle.timestamp)),
      if (widget.period < 86400)
        '時間': _formatTimestamp(candle.timestamp)
      else if (widget.period >= 31556926)
        '年份': _formatTimestamp(candle.timestamp)
      else if (widget.period >= 2592000)
        '月份': _formatTimestamp(candle.timestamp),
      if (widget.period >= 86400) '': '',
      // '': '',
      // else if (widget.period < 2592000)
      //   '': ''
      // else if (widget.period < 2592000)
      // widget.period < 86400
      //     ? '時間'
      //     : widget.period < 2592000
      //         ? '日期'
      //         : widget.period < 31556926
      //             ? '月份'
      //             : '年份': _formatTimestamp(candle.timestamp),
      "開": candle.open?.toString() ?? "-",
      "高": candle.high?.toString() ?? "-",
      "低": candle.low?.toString() ?? "-",
      "收": candle.close?.toString() ?? "-",
      "成量": candle.volume?.asAbbreviated() ?? "-",
    };
    final date = intl.DateFormat.yMMMd()
        .format(DateTime.fromMillisecondsSinceEpoch(candle.timestamp));
    return {
      "Date": date,
      "Open": candle.open?.toStringAsFixed(2) ?? "-",
      "High": candle.high?.toStringAsFixed(2) ?? "-",
      "Low": candle.low?.toStringAsFixed(2) ?? "-",
      "Close": candle.close?.toStringAsFixed(2) ?? "-",
      "Volume": candle.volume?.asAbbreviated() ?? "-",
    };
  }

  void _fireOnTapEvent() {
    if (_prevParams == null || _tapPosition == null) return;
    final params = _prevParams!;
    final dx = _tapPosition!.dx;
    final selected = params.getCandleIndexFromOffset(dx);
    final candle = params.candles[selected];
    widget.onTap?.call(candle);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._rightWidget);

  final TabBar _tabBar;
  final Widget? _rightWidget;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black.withOpacity(.8),
      child: _rightWidget == null
          ? _tabBar
          : Row(
              children: [
                Expanded(
                  child: _tabBar,
                ),
                _rightWidget!
              ],
            ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

extension Formatting on double {
  String asPercent() {
    final format = this < 100 ? "##0.00" : "#,###";
    final v = intl.NumberFormat(format, "en_US").format(this);
    return "${this >= 0 ? '+' : ''}$v%";
  }

  String asAbbreviated() {
    if (this < 1000) return double.parse(this.toStringAsFixed(3)).toString();
    if (this >= 1e18) return this.toStringAsExponential(3);
    final s = intl.NumberFormat("#,###", "en_US").format(this).split(",");
    const suffixes = ["K", "M", "B", "T", "Q"];
    return "${s[0]}.${s[1]}${suffixes[s.length - 2]}";
  }
}
