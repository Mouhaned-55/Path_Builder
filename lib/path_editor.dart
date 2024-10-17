import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:path_builder_app/path_data.dart';
import 'package:path_builder_app/path_painter.dart';
import 'package:path_builder_app/widgets.dart';
import 'package:path_provider/path_provider.dart';

// Main widget for the Path Editor
class PathEditor extends StatefulWidget {
  const PathEditor({super.key});

  @override
  _PathEditorState createState() => _PathEditorState();
}

// State class for PathEditor
class _PathEditorState extends State<PathEditor> {
  // List to store paths
  List<PathData> paths = [PathData()];
  int currentPathIndex = 0; // Tracks the current path index
  File? backgroundImage; // Stores the selected background image

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Display background image if selected
        if (backgroundImage != null)
          Positioned.fill(
            child: SvgPicture.file(
              backgroundImage!,
              width: 50,
              height: 50,
            ),
          ),
        Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Handle touch events
                onTapDown: (TapDownDetails details) {
                  final tapPosition = details.localPosition;
                  _selectPointOrAddNew(tapPosition); // Select or add a point
                },
                onPanUpdate: (DragUpdateDetails details) {
                  _updateSelectedPoint(details.delta); // Update point position
                },
                onPanEnd: (_) {
                  _clearSelection(); // Clear selection on pan end
                },
                onDoubleTap: () {
                  _removeSelectedPoint(); // Remove selected point on double tap
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PathPainter(paths), // Custom painter for drawing paths
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Buttons for different actions
                buildButton(
                  text: 'New Path',
                  onPressed: _addNewPath,
                ),
                buildButton(
                  text: 'Save',
                  onPressed: _exportDrawing,
                ),
                buildButton(
                  text: 'Import SVG',
                  onPressed: _importDrawing,
                ),
                buildButton(
                  text: 'Clear',
                  onPressed: _clearAllDrawings,
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  // Function to import an SVG file as background
  Future<void> _importDrawing() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'], // Allow only SVG files
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        backgroundImage = File(result.files.first.path!); // Set background image
      });
    }
  }

  // Function to clear all drawings
  void _clearAllDrawings() {
    setState(() {
      paths.clear(); // Clear the list of paths
      backgroundImage = null; // Clear background image
    });
    _addNewPath(); // Add a new path
  }

  // Function to export the current drawing as an SVG file
  Future<void> _exportDrawing() async {
    final svgPath = StringBuffer();
    svgPath.write('<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">\n');

    // Add background SVG if it exists
    if (backgroundImage != null) {
      String backgroundSvgContent = await backgroundImage!.readAsString();
      svgPath.write('<defs>\n<g id="background">\n$backgroundSvgContent\n</g>\n</defs>\n');
      svgPath.write('<use href="#background" x="0" y="0" />\n');
    }

    // Iterate through paths and create SVG paths
    for (var pathData in paths) {
      if (pathData.points.isNotEmpty) {
        svgPath.write('<path d="M${pathData.points[0].dx},${pathData.points[0].dy} ');

        for (int i = 0; i < pathData.points.length - 1; i++) {
          if (pathData.isControlPointModified[i]) {
            var cpOut = pathData.controlPointsOut[i]!;
            var cpIn = pathData.controlPointsIn[i + 1]!;
            svgPath.write('C${cpOut.dx},${cpOut.dy},${cpIn.dx},${cpIn.dy},${pathData.points[i + 1].dx},${pathData.points[i + 1].dy} ');
          } else {
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
    print('SVG shape exported to ${file.path}'); // Log the exported file path
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG shape exported to ${file.path}')),
    );
  }

  // Function to add a new path
  void _addNewPath() {
    setState(() {
      paths.add(PathData()); // Add a new PathData object
      currentPathIndex = paths.length - 1; // Set to the new path's index
    });
  }

  // Function to select a point or add a new point
  void _selectPointOrAddNew(Offset position) {
    const double proximity = 10.0; // Proximity threshold for selection
    var currentPath = paths[currentPathIndex];

    for (int i = 0; i < currentPath.points.length; i++) {
      if (_isWithinProximity(currentPath.points[i], position, proximity)) {
        _selectPoint(i); // Select existing point
        return;
      }
      if (_isWithinProximity(currentPath.controlPointsOut[i], position, proximity)) {
        _selectControlPoint(i, isOutward: true); // Select control point outward
        return;
      }
      if (_isWithinProximity(currentPath.controlPointsIn[i], position, proximity)) {
        _selectControlPoint(i, isOutward: false); // Select control point inward
        return;
      }
    }

    _addNewPoint(position); // Add new point if none are selected
  }

  // Function to select a point by index
  void _selectPoint(int index) {
    setState(() {
      paths[currentPathIndex].selectedPointIndex = index; // Update selected point index
      paths[currentPathIndex].selectedControlPointIndex = null; // Clear control point selection
    });
  }

  // Function to select a control point by index
  void _selectControlPoint(int index, {required bool isOutward}) {
    setState(() {
      paths[currentPathIndex].selectedPointIndex = null; // Clear point selection
      paths[currentPathIndex].selectedControlPointIndex = index; // Update selected control point index
      paths[currentPathIndex].isOutwardControl = isOutward; // Set direction of control point
    });
  }

  // Function to add a new point at the given position
  void _addNewPoint(Offset position) {
    setState(() {
      var currentPath = paths[currentPathIndex];
      currentPath.points.add(position); // Add the new point
      currentPath.controlPointsIn.add(position - const Offset(30, 0)); // Add input control point
      currentPath.controlPointsOut.add(position + const Offset(30, 0)); // Add output control point
      currentPath.isControlPointModified.add(false); // Initialize control point modification state
      currentPath.isVisible.add(true); // New lines start as visible
    });
  }

  // Function to check if a point is within proximity to another point
  bool _isWithinProximity(Offset? point, Offset position, double threshold) {
    return point != null && (point - position).distance < threshold; // Calculate distance
  }

  // Function to update the position of the selected point
  void _updateSelectedPoint(Offset delta) {
    var currentPath = paths[currentPathIndex];
    if (currentPath.selectedPointIndex != null) {
      _movePointAndControlPoints(currentPath.selectedPointIndex!, delta); // Move point and control points
    } else if (currentPath.selectedControlPointIndex != null) {
      _moveControlPoint(currentPath.selectedControlPointIndex!, delta); // Move control point
    }
  }

  // Function to move a point and its control points
  void _movePointAndControlPoints(int index, Offset delta) {
    setState(() {
      var currentPath = paths[currentPathIndex];
      currentPath.points[index] += delta; // Move point
      currentPath.controlPointsIn[index] = currentPath.controlPointsIn[index]! + delta; // Move input control point
      currentPath.controlPointsOut[index] = currentPath.controlPointsOut[index]! + delta; // Move output control point
    });
  }

  // Function to move a control point
  void _moveControlPoint(int index, Offset delta) {
    setState(() {
      var currentPath = paths[currentPathIndex];
      if (currentPath.isOutwardControl) {
        currentPath.controlPointsOut[index] = currentPath.controlPointsOut[index]! + delta; // Move outward control point
      } else {
        currentPath.controlPointsIn[index] = currentPath.controlPointsIn[index]! + delta; // Move inward control point
      }
    });
  }

  // Function to remove the selected point
  void _removeSelectedPoint() {
    setState(() {
      var currentPath = paths[currentPathIndex];
      if (currentPath.selectedPointIndex != null) {
        int index = currentPath.selectedPointIndex!; // Get index of the selected point
        currentPath.points.removeAt(index); // Remove point from list
        currentPath.controlPointsIn.removeAt(index); // Remove corresponding input control point
        currentPath.controlPointsOut.removeAt(index); // Remove corresponding output control point
        currentPath.isControlPointModified.removeAt(index); // Remove modification state
        currentPath.selectedPointIndex = null; // Clear selection
      }
    });
  }

  // Function to clear the selection
  void _clearSelection() {
    setState(() {
      var currentPath = paths[currentPathIndex];
      currentPath.selectedPointIndex = null; // Clear selected point index
      currentPath.selectedControlPointIndex = null; // Clear selected control point index
    });
  }
}
