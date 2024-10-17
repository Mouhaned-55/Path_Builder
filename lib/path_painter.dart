import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_builder_app/path_data.dart';

class PathPainter extends CustomPainter {
  final List<PathData> paths;

  PathPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    for (var pathData in paths) {
      _drawPath(canvas, pathData);
      _drawControlPoints(canvas, pathData);
      _drawPoints(canvas, pathData);
    }
  }

  void _drawPath(Canvas canvas, PathData pathData) {
    Paint pathPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    if (pathData.points.isNotEmpty) {
      Path path = Path()..moveTo(pathData.points.first.dx, pathData.points.first.dy);

      for (int i = 0; i < pathData.points.length - 1; i++) {
        if (pathData.isControlPointModified[i]) {
          Offset controlIn = pathData.controlPointsIn[i] ?? pathData.points[i];
          Offset controlOut = pathData.controlPointsOut[i] ?? pathData.points[i + 1];
          path.cubicTo(controlOut.dx, controlOut.dy, controlIn.dx,
              controlIn.dy, pathData.points[i + 1].dx, pathData.points[i + 1].dy);
        } else {
          path.lineTo(pathData.points[i + 1].dx, pathData.points[i + 1].dy);
        }
      }
      canvas.drawPath(path, pathPaint);
    }
  }

  void _drawControlPoints(Canvas canvas, PathData pathData) {
    Paint controlPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < pathData.points.length; i++) {
      if (pathData.isVisible[i]) {
        if (pathData.controlPointsIn[i] != null) {
          canvas.drawLine(pathData.points[i], pathData.controlPointsIn[i]!, controlPaint);
        }
        if (pathData.controlPointsOut[i] != null) {
          canvas.drawLine(pathData.points[i], pathData.controlPointsOut[i]!, controlPaint);
        }
      }
    }
  }

  void _drawPoints(Canvas canvas, PathData pathData) {
    Paint pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (Offset point in pathData.points) {
      canvas.drawCircle(point, 5.0, pointPaint);
    }

    Paint controlPointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (Offset? controlPoint in pathData.controlPointsIn) {
      if (controlPoint != null) {
        canvas.drawCircle(controlPoint, 5.0, controlPointPaint);
      }
    }

    for (Offset? controlPoint in pathData.controlPointsOut) {
      if (controlPoint != null) {
        canvas.drawCircle(controlPoint, 5.0, controlPointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
