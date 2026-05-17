import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AuraLoadingIndicator extends StatelessWidget {
  const AuraLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AuraColors.primary));
  }
}
