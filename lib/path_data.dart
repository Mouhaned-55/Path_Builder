import 'package:flutter/material.dart';

class PathData {
  List<Offset> points = [];
  List<Offset?> controlPointsIn = [];
  List<Offset?> controlPointsOut = [];
  List<bool> isControlPointModified = [];
  List<bool> isVisible = [];
  int? selectedPointIndex;
  int? selectedControlPointIndex;
  bool isOutwardControl = true;
}
