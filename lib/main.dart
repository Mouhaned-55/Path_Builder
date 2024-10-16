import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text('PATH BUILDER')),
        body: PathEditor(),
      ),
    );
  }
}

class PathEditor extends StatefulWidget {
  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  List<PathData> paths = [PathData()];
  int currentPathIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTapDown: (TapDownDetails details) {
              final tapPosition = details.localPosition;
              _selectPointOrAddNew(tapPosition);
            },
            onPanUpdate: (DragUpdateDetails details) {
              _updateSelectedPoint(details.delta);
            },
            onPanEnd: (_) {
              _clearSelection();
            },
            onDoubleTap: () {
              _removeSelectedPoint();
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: PathPainter(paths),
            ),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: _addNewPath,
              child: Text('Start New Path'),
            ),
            ElevatedButton(
              onPressed: _exportDrawing,
              child: Text('Save to Gallery'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportDrawing() async {
    final svgPath = StringBuffer();
    svgPath.write(
        '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">\n');

    for (var pathData in paths) {
      if (pathData.points.isNotEmpty) {
        svgPath.write('<path d="M${pathData.points[0].dx},${pathData.points[0].dy} ');

        for (int i = 0; i < pathData.points.length - 1; i++) {
          if (pathData.isControlPointModified[i]) {
            // Export cubic Bézier curves using 'C' command
            var cpOut = pathData.controlPointsOut[i]!;
            var cpIn = pathData.controlPointsIn[i + 1]!;
            svgPath.write(
                'C${cpOut.dx},${cpOut.dy},${cpIn.dx},${cpIn.dy},${pathData.points[i + 1].dx},${pathData.points[i + 1].dy} ');
          } else {
            // Export straight lines using 'L' command
            svgPath.write('L${pathData.points[i + 1].dx},${pathData.points[i + 1].dy} ');
          }
        }
        svgPath.write('" stroke="black" fill="none" stroke-width="4"/>\n');
      }
    }

    svgPath.write('</svg>');

    final directory = await getApplicationDocumentsDirectory();
    final svgPathFile = '${directory.path}/exported_shape.svg';
    final file = await File(svgPathFile).writeAsString(svgPath.toString());
    print('SVG shape exported to ${file.path}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG shape exported to ${file.path}')),
    );
  }




  void _addNewPath() {
    setState(() {
      paths.add(PathData());
      currentPathIndex = paths.length - 1;
    });
  }

  void _selectPointOrAddNew(Offset position) {
    const double proximityThreshold = 10.0;
    var currentPath = paths[currentPathIndex];

    for (int i = 0; i < currentPath.points.length; i++) {
      if (_isWithinProximity(currentPath.points[i], position, proximityThreshold)) {
        _selectPoint(i);
        return;
      }
      if (_isWithinProximity(currentPath.controlPointsOut[i], position, proximityThreshold)) {
        _selectControlPoint(i, isOutward: true);
        return;
      }
      if (_isWithinProximity(currentPath.controlPointsIn[i], position, proximityThreshold)) {
        _selectControlPoint(i, isOutward: false);
        return;
      }
    }

    _addNewPoint(position);
  }

  void _selectPoint(int index) {
    setState(() {
      paths[currentPathIndex].selectedPointIndex = index;
      paths[currentPathIndex].selectedControlPointIndex = null;
    });
  }

  void _selectControlPoint(int index, {required bool isOutward}) {
    setState(() {
      paths[currentPathIndex].selectedPointIndex = null;
      paths[currentPathIndex].selectedControlPointIndex = index;
      paths[currentPathIndex].isOutwardControl = isOutward;
    });
  }

  void _addNewPoint(Offset position) {
    setState(() {
      var currentPath = paths[currentPathIndex];
      currentPath.points.add(position);
      currentPath.controlPointsIn.add(position - const Offset(30, 0));
      currentPath.controlPointsOut.add(position + const Offset(30, 0));
      currentPath.isControlPointModified.add(false);
      currentPath.isVisible.add(true); // New lines start as visible
    });
  }

  bool _isWithinProximity(Offset? point, Offset position, double threshold) {
    return point != null && (point - position).distance < threshold;
  }

  void _updateSelectedPoint(Offset delta) {
    var currentPath = paths[currentPathIndex];
    if (currentPath.selectedPointIndex != null) {
      _movePointAndControlPoints(currentPath.selectedPointIndex!, delta);
    } else if (currentPath.selectedControlPointIndex != null) {
      _moveControlPoint(currentPath.selectedControlPointIndex!, delta);
    }
  }

  void _movePointAndControlPoints(int index, Offset delta) {
    setState(() {
      var currentPath = paths[currentPathIndex];
      currentPath.points[index] += delta;
      currentPath.controlPointsIn[index] = currentPath.controlPointsIn[index]! + delta;
      currentPath.controlPointsOut[index] = currentPath.controlPointsOut[index]! + delta;
    });
  }

  void _moveControlPoint(int index, Offset delta) {
    setState(() {
      var currentPath = paths[currentPathIndex];
      if (currentPath.isOutwardControl) {
        currentPath.controlPointsOut[index] = currentPath.controlPointsOut[index]! + delta;
      } else {
        currentPath.controlPointsIn[index] = currentPath.controlPointsIn[index]! - delta;
      }
      currentPath.isControlPointModified[index] = true;
    });
  }

  void _clearSelection() {
    setState(() {
      paths[currentPathIndex].selectedPointIndex = null;
      paths[currentPathIndex].selectedControlPointIndex = null;
    });
  }

  void _removeSelectedPoint() {
    if (paths[currentPathIndex].selectedPointIndex != null) {
      setState(() {
        var currentPath = paths[currentPathIndex];
        currentPath.points.removeAt(currentPath.selectedPointIndex!);
        currentPath.controlPointsIn.removeAt(currentPath.selectedPointIndex!);
        currentPath.controlPointsOut.removeAt(currentPath.selectedPointIndex!);
        currentPath.isControlPointModified.removeAt(currentPath.selectedPointIndex!);
        currentPath.isVisible.removeAt(currentPath.selectedPointIndex!);
        currentPath.selectedPointIndex = null;
      });
    }
  }
}

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
