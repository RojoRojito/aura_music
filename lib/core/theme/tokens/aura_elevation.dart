import 'package:flutter/material.dart';

class AuraElevation {
  static const List<BoxShadow> level0 = [];

  static List<BoxShadow> level1({Color color = const Color(0xFF7C4DFF)}) => [
        BoxShadow(
          color: color.withOpacity(0.12),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> level2({Color color = const Color(0xFF7C4DFF)}) => [
        BoxShadow(
          color: color.withOpacity(0.16),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> level3({Color color = const Color(0xFF7C4DFF)}) => [
        BoxShadow(
          color: color.withOpacity(0.20),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> level4({Color color = const Color(0xFF7C4DFF)}) => [
        BoxShadow(
          color: color.withOpacity(0.24),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];
}
