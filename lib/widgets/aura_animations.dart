import 'package:flutter/material.dart';
import '../core/theme/tokens/tokens.dart';
import '../core/theme/app_theme.dart';

class AuraPlayingBars extends StatefulWidget {
  final Color? color;
  final double height;
  final double barWidth;
  final double spacing;

  const AuraPlayingBars({
    super.key,
    this.color,
    this.height = 16,
    this.barWidth = 3,
    this.spacing = 3,
  });

  @override
  State<AuraPlayingBars> createState() => _AuraPlayingBarsState();
}

class _AuraPlayingBarsState extends State<AuraPlayingBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    const barCount = 4;
    _controllers = List.generate(
      barCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 100),
      )..repeat(reverse: true),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? AuraColors.primary;
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_animations.length, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) => Container(
              width: widget.barWidth,
              height: widget.height * _animations[i].value,
              margin: EdgeInsets.only(right: i < _animations.length - 1 ? widget.spacing : 0),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          );
        }),
      ),
    );
  }
}

Future<T?> showAuraBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AuraRadius.lg),
          ),
        ),
    clipBehavior: clipBehavior ?? Clip.antiAlias,
    transitionAnimationController: AnimationController(
      duration: AuraAnimation.normal,
      reverseDuration: AuraAnimation.slow,
      vsync: Navigator.of(context),
    )..addStatusListener((status) {}),
    builder: builder,
  );
}

Future<T?> showAuraDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    builder: builder,
    transitionBuilder: (ctx, anim, secAnim, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: AuraAnimation.spring),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: anim,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
      );
    },
  );
}
