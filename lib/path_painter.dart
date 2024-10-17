import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_builder_app/path_data.dart';


class PathPainter extends CustomPainter {
  final List<PathData> paths; // A list of path data to be painted.

  PathPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    // Iterate through each path data and draw the path, control points, and points.
    for (var pathData in paths) {
      _drawPath(canvas, pathData); // Draw the path itself.
      _drawControlPoints(canvas, pathData); // Draw the control points.
      _drawPoints(canvas, pathData); // Draw the points.
    }
  }


  void _drawPath(Canvas canvas, PathData pathData) {
    // Paint configuration for the path.
    Paint pathPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    if (pathData.points.isNotEmpty) {
      Path path = Path()..moveTo(pathData.points.first.dx, pathData.points.first.dy);

      for (int i = 0; i < pathData.points.length - 1; i++) {
        if (pathData.isControlPointModified[i]) {
          // Use cubic Bézier curves if the control point is modified.
          Offset controlIn = pathData.controlPointsIn[i] ?? pathData.points[i];
          Offset controlOut = pathData.controlPointsOut[i] ?? pathData.points[i + 1];
          path.cubicTo(controlOut.dx, controlOut.dy, controlIn.dx,
              controlIn.dy, pathData.points[i + 1].dx, pathData.points[i + 1].dy);
        } else {
          // Draw straight lines otherwise.
          path.lineTo(pathData.points[i + 1].dx, pathData.points[i + 1].dy);
        }
      }
      canvas.drawPath(path, pathPaint); // Draw the constructed path on the canvas.
    }
  }


  void _drawControlPoints(Canvas canvas, PathData pathData) {
    Paint controlPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < pathData.points.length; i++) {
      if (pathData.isVisible[i]) {
        // Draw lines from each point to its input and output control points.
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
      // Draw each point as a filled circle.
      canvas.drawCircle(point, 5.0, pointPaint);
    }

    Paint controlPointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (Offset? controlPoint in pathData.controlPointsIn) {
      // Draw each input control point as a filled circle if it's not null.
      if (controlPoint != null) {
        canvas.drawCircle(controlPoint, 5.0, controlPointPaint);
      }
    }

    for (Offset? controlPoint in pathData.controlPointsOut) {
      // Draw each output control point as a filled circle if it's not null.
      if (controlPoint != null) {
        canvas.drawCircle(controlPoint, 5.0, controlPointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // The painter should repaint whenever the delegate changes.
    return true;
  }
}
