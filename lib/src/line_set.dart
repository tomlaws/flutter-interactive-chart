import 'package:flutter/widgets.dart';

import '../interactive_chart.dart';

/// Parse lines so that they are friendly to the painter
class LineSet {
  List<List<double?>> data = [];
  List<Color> color = [];
  List<String?> label = [];
  List<bool> visible = [];

  LineSet(List<Line> lines) {
    if (lines.length == 0) return;
    int len = lines[0].data.length;
    assert(lines.every((l) => l.data.length == len),
        "The number of points in line set is inconsistent");
    for (int i = 0; i < len; ++i) {
      data.add(lines.map((e) => e.data.elementAt(i)).toList());
    }
  }
}
