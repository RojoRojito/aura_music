import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens/tokens.dart';

class AuraGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool useBlur;

  const AuraGlass({
    super.key,
    required this.child,
    this.blurSigma = 20,
    this.opacity = AuraTranslucency.medium,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.5,
    this.radius = AuraRadius.lg,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final border = borderColor ?? Theme.of(context).colorScheme.outline.withOpacity(0.3);

    final decoration = BoxDecoration(
      color: bg.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: borderWidth),
    );

    final content = Padding(
      padding: padding,
      child: child,
    );

    if (!useBlur || _isLowEndDevice()) {
      return Container(
        decoration: decoration,
        margin: margin,
        child: content,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(decoration: decoration, child: content),
        ),
      ),
    );
  }

  static bool _isLowEndDevice() {
    if (Platform.isAndroid) {
      final hardware = Platform.environment['HARDWARE'] ?? '';
      final ram = Platform.environment['RAM'] ?? '';
      return hardware.toLowerCase().contains('mt6') ||
          ram.toLowerCase().contains('1') ||
          ram.toLowerCase().contains('2');
    }
    return false;
  }

  static Widget disabled({
    required Widget child,
    Color? backgroundColor,
    double opacity = AuraTranslucency.medium,
    double radius = AuraRadius.lg,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    final bg = backgroundColor ?? Colors.black26;
    return Container(
      decoration: BoxDecoration(
        color: bg.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
