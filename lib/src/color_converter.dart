import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

class ColorConverter implements JsonConverter<Color, String> {
  const ColorConverter();

  @override
  Color fromJson(String colorValue) {
    Color color = Color(int.parse(colorValue)).withOpacity(1);
    return color;
  }

  @override
  String toJson(Color color) {
    return color.value.toString();
  }
}
