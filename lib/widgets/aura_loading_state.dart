import 'package:flutter/material.dart';
import '../core/theme/tokens/tokens.dart';
import 'aura_empty_state.dart';

enum AuraState { loading, empty, error, content }

class AuraLoadingState extends StatelessWidget {
  final AuraState state;
  final Widget? content;
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showShimmer;

  const AuraLoadingState({
    super.key,
    required this.state,
    this.content,
    this.emptyIcon,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorMessage,
    this.onRetry,
    this.showShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case AuraState.loading:
        return _buildLoading(context);
      case AuraState.empty:
        return _buildEmpty();
      case AuraState.error:
        return _buildError(context);
      case AuraState.content:
        return content ?? const SizedBox.shrink();
    }
  }

  Widget _buildLoading(BuildContext context) {
    if (showShimmer) {
      return Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildEmpty() {
    return AuraEmptyState(
      icon: emptyIcon ?? Icons.music_off,
      title: emptyTitle ?? 'Nothing here yet',
      message: emptyMessage ?? 'Content will appear once available.',
      actionLabel: emptyActionLabel,
      onAction: onEmptyAction,
    );
  }

  Widget _buildError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: AuraSpacing.lg),
            Text(
              'Something went wrong',
              style: AuraTypography.headline.copyWith(
                color: isDark
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorMessage != null) ...[
              SizedBox(height: AuraSpacing.sm),
              Text(
                errorMessage!,
                style: AuraTypography.body.copyWith(
                  color: isDark
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: AuraSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
