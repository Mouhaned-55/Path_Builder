import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget buildButton({
  required String text,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: 100,
    height: 40,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    ),
  );
}