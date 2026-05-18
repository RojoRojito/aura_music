import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens/tokens.dart';
import '../player/player_controller.dart';
import '../../widgets/aura_animations.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isDark = settings.themeMode == ThemeMode.dark;

    final bgColor = isDark ? AuraColors.background : AuraColors.lightBackground;
    final textColor = isDark ? AuraColors.text : AuraColors.lightText;
    final mutedColor = isDark ? AuraColors.textMuted : AuraColors.lightTextMuted;
    final surfaceColor = isDark ? AuraColors.surface : AuraColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, elevation: 0,
        title: Text('Ajustes', style: AuraTypography.headline.copyWith(
            color: textColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpacing.xl),
        children: [
          _section('Reproducción', mutedColor),
          _speedTile(context, settings, textColor, mutedColor, surfaceColor),
          _sleepTimerTile(context, settings, textColor, mutedColor, surfaceColor),
          const SizedBox(height: AuraSpacing.xl),
          _section('Apariencia', mutedColor),
          _themeTile(context, settings, textColor, mutedColor, surfaceColor),
          _dynamicThemeTile(context, settings, textColor, mutedColor),
          const SizedBox(height: AuraSpacing.xl),
          _section('Acerca de', mutedColor),
          _tile(Icons.info_outline, 'AURA Music', 'v1.0.0', textColor, mutedColor),
        ],
      ),
    );
  }

  Widget _section(String t, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: AuraSpacing.sm),
    child: Text(t.toUpperCase(), style: AuraTypography.overline.copyWith(
        color: AuraColors.primary)));

  Widget _tile(IconData icon, String title, String sub, Color textColor, Color mutedColor) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: mutedColor),
    title: Text(title, style: AuraTypography.title.copyWith(color: textColor)),
    subtitle: Text(sub, style: AuraTypography.caption.copyWith(color: mutedColor)));

  Widget _speedTile(BuildContext ctx, SettingsController settings, Color textColor, Color mutedColor, Color surfaceColor) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.speed, color: mutedColor),
    title: Text('Velocidad', style: AuraTypography.title.copyWith(color: textColor)),
    subtitle: Text('${settings.playbackSpeed}x',
        style: AuraTypography.caption.copyWith(color: mutedColor)),
    trailing: Icon(Icons.chevron_right, color: mutedColor),
    onTap: () => _showSpeedPicker(ctx, settings, surfaceColor),
  );

  Widget _sleepTimerTile(BuildContext ctx, SettingsController settings, Color textColor, Color mutedColor, Color surfaceColor) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.timer, color: mutedColor),
    title: Text('Temporizador de sueño', style: AuraTypography.title.copyWith(color: textColor)),
    subtitle: Text(settings.isSleepTimerActive
        ? settings.sleepTimerRemaining
        : 'Desactivado',
        style: AuraTypography.caption.copyWith(color: mutedColor)),
    trailing: Icon(Icons.chevron_right, color: mutedColor),
    onTap: () => _showSleepTimerPicker(ctx, settings, surfaceColor),
  );

  Widget _themeTile(BuildContext ctx, SettingsController settings, Color textColor, Color mutedColor, Color surfaceColor) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.dark_mode, color: mutedColor),
    title: Text('Tema oscuro', style: AuraTypography.title.copyWith(color: textColor)),
    trailing: Switch(
      value: settings.themeMode == ThemeMode.dark,
      activeColor: AuraColors.primary,
      onChanged: (v) async {
        await settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
      },
    ),
  );

  Widget _dynamicThemeTile(BuildContext ctx, SettingsController settings, Color textColor, Color mutedColor) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: Icon(Icons.color_lens, color: mutedColor),
    title: Text('Tema dinamico', style: AuraTypography.title.copyWith(color: textColor)),
    subtitle: Text(settings.dynamicThemeEnabled ? 'Activado' : 'Desactivado',
        style: AuraTypography.caption.copyWith(color: mutedColor)),
    value: settings.dynamicThemeEnabled,
    activeColor: AuraColors.primary,
    onChanged: (v) async {
      await settings.setDynamicTheme(v);
    },
  );

  void _showSpeedPicker(BuildContext ctx, SettingsController settings, Color surfaceColor) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showAuraBottomSheet(
      context: ctx,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.all(AuraSpacing.xl),
          child: Text('Velocidad de reproduccion',
              style: AuraTypography.headline)),
        ...speeds.map((s) => ListTile(
          title: Text('${s}x',
              style: AuraTypography.title.copyWith(
                  color: settings.playbackSpeed == s
                      ? AuraColors.primary
                      : AuraColors.text)),
          trailing: settings.playbackSpeed == s
              ? const Icon(Icons.check, color: AuraColors.primary)
              : null,
          onTap: () async {
            await settings.setPlaybackSpeed(s);
            if (ctx.mounted) {
              final player = ctx.read<PlayerController>();
              await player.setSpeed(s);
            }
            Navigator.pop(ctx);
          },
        )),
        const SizedBox(height: AuraSpacing.xl),
      ]),
    );
  }

  void _showSleepTimerPicker(BuildContext ctx, SettingsController settings, Color surfaceColor) {
    final options = [0, 5, 15, 30, 45, 60, 90, 120];
    showAuraBottomSheet(
      context: ctx,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.all(AuraSpacing.xl),
          child: Text('Temporizador de sueño',
              style: AuraTypography.headline)),
        ...options.map((m) => ListTile(
          title: Text(m == 0 ? 'Desactivado' : '$m minutos',
              style: AuraTypography.title.copyWith(
                  color: settings.sleepTimerMinutes == m
                      ? AuraColors.primary
                      : AuraColors.text)),
          trailing: settings.sleepTimerMinutes == m
              ? const Icon(Icons.check, color: AuraColors.primary)
              : null,
          onTap: () async {
            await settings.setSleepTimer(m);
            Navigator.pop(ctx);
          },
        )),
        const SizedBox(height: AuraSpacing.xl),
      ]),
    );
  }
}