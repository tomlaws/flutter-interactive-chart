import 'package:flutter/widgets.dart';

class Line {
  List<double?> data;
  Color color;
  String? label;
  bool visible;
  Line(
      {required this.data,
      this.label,
      this.visible = true,
      this.color = const Color(0xFF7F7F7F)});

  Line withRange(int start, int end) {
    return Line(
        data: this.data.getRange(start, end).toList(),
        label: this.label,
        visible: this.visible,
        color: this.color);
  }
}
