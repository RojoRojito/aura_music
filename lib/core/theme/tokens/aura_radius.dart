import 'package:flutter/material.dart';

class AuraRadius {
  static const double none = 0;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = double.infinity;

  static BorderRadius radius(double value) => BorderRadius.circular(value);
  static BorderRadius get smRadius => radius(sm);
  static BorderRadius get mdRadius => radius(md);
  static BorderRadius get lgRadius => radius(lg);
  static BorderRadius get xlRadius => radius(xl);
  static BorderRadius get fullRadius => const BorderRadius.all(Radius.circular(full));
}
