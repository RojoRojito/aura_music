import 'package:flutter/material.dart';
import '../core/theme/tokens/tokens.dart';

class AuraListStagger extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDuration;
  final Curve curve;

  const AuraListStagger({
    super.key,
    required this.children,
    this.staggerDuration = const Duration(milliseconds: AuraAnimation.listStaggerMs),
    this.curve = AuraAnimation.easeOut,
  });

  @override
  State<AuraListStagger> createState() => _AuraListStaggerState();
}

class _AuraListStaggerState extends State<AuraListStagger>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (i) => AnimationController(
        vsync: this,
        duration: AuraAnimation.normal,
      ),
    );
    _animations = _controllers.map((c) => CurvedAnimation(parent: c, curve: widget.curve)).toList();

    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * widget.staggerDuration.inMilliseconds), () {
        if (mounted) _controllers[i].forward();
      });
    }
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
    return Column(
      children: List.generate(
        widget.children.length,
        (i) => FadeTransition(
          opacity: _animations[i],
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(_animations[i]),
            child: widget.children[i],
          ),
        ),
      ),
    );
  }
}
