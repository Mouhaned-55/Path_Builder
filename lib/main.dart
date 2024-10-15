import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
              onPressed: _saveToGallery,
              child: Text('Save to Gallery'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveToGallery() async {
    await _requestPermissions();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(1080, 1920)));

    // Use PathPainter to draw on the canvas
    PathPainter painter = PathPainter(paths);
    painter.paint(canvas, Size(1080, 1920));

    // Convert the canvas to an image
    final picture = recorder.endRecording();
    final img = await picture.toImage(1080, 1920);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Get a temporary directory to store the image before saving to gallery
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(filePath);
    await file.writeAsBytes(buffer);

    // Save the image to the gallery using ImageGallerySaver
    final result = await ImageGallerySaver.saveFile(filePath);
    print('Saved to gallery: $result');
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
    ].request();
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
