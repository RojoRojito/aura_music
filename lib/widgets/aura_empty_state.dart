import 'package:flutter/material.dart';
import '../core/theme/tokens/tokens.dart';

class AuraEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AuraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: isDark
                  ? colorScheme.onSurface.withOpacity(0.3)
                  : colorScheme.onSurface.withOpacity(0.25),
            ),
            SizedBox(height: AuraSpacing.lg),
            Text(
              title,
              style: AuraTypography.headline.copyWith(
                color: isDark
                    ? colorScheme.onSurface
                    : colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AuraSpacing.sm),
            Text(
              message,
              style: AuraTypography.body.copyWith(
                color: isDark
                    ? colorScheme.onSurface.withOpacity(0.6)
                    : colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: AuraSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
