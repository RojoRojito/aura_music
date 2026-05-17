import 'package:flutter/material.dart';

class AuraLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const AuraLoadingIndicator({
    super.key,
    this.size = 40,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
