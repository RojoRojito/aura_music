import 'package:flutter/material.dart';

class AuraAnimation {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration ambient = Duration(milliseconds: 3000);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve spring = Curves.easeOutBack;
  static const Curve ambientCurve = Curves.easeInOut;

  static const int listStaggerMs = 30;
}
