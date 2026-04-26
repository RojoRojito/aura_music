import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../player/player_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (_, settings, __) {
        return Scaffold(
          backgroundColor: AuraColors.background,
          appBar: AppBar(
            backgroundColor: AuraColors.background, elevation: 0,
            title: const Text('Ajustes', style: TextStyle(
                color: AuraColors.text, fontWeight: FontWeight.bold, fontSize: 22)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('Reproduccion'),
              _speedTile(context, settings),
              _sleepTimerTile(context, settings),
              const SizedBox(height: 20),
              _section('Apariencia'),
              _dynamicThemeTile(context, settings),
              const SizedBox(height: 20),
              _section('Acerca de'),
              _tile(Icons.info_outline, 'AURA Music', 'v1.0.0'),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(
        color: AuraColors.primary, fontSize: 11,
        letterSpacing: 2, fontWeight: FontWeight.w700)));

  Widget _tile(IconData icon, String title, String sub) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AuraColors.textMuted),
    title: Text(title, style: const TextStyle(color: AuraColors.text)),
    subtitle: Text(sub, style: const TextStyle(
        color: AuraColors.textMuted, fontSize: 12)));

  Widget _speedTile(BuildContext ctx, SettingsController settings) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.speed, color: AuraColors.textMuted),
    title: const Text('Velocidad', style: TextStyle(color: AuraColors.text)),
    subtitle: Text('${settings.playbackSpeed}x',
        style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right, color: AuraColors.textMuted),
    onTap: () => _showSpeedPicker(ctx, settings),
  );

  Widget _sleepTimerTile(BuildContext ctx, SettingsController settings) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.timer, color: AuraColors.textMuted),
    title: const Text('Temporizador de sueno',
        style: TextStyle(color: AuraColors.text)),
    subtitle: Text(settings.isSleepTimerActive
        ? settings.sleepTimerRemaining
        : 'Desactivado',
        style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right, color: AuraColors.textMuted),
    onTap: () => _showSleepTimerPicker(ctx, settings),
  );

  Widget _dynamicThemeTile(BuildContext ctx, SettingsController settings) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: const Icon(Icons.color_lens, color: AuraColors.textMuted),
    title: const Text('Tema dinamico',
        style: TextStyle(color: AuraColors.text)),
    subtitle: Text(settings.dynamicThemeEnabled ? 'Activado' : 'Desactivado',
        style: const TextStyle(color: AuraColors.textMuted, fontSize: 12)),
    value: settings.dynamicThemeEnabled,
    activeColor: AuraColors.primary,
    onChanged: (v) async {
      await settings.setDynamicTheme(v);
    },
  );

  void _showSpeedPicker(BuildContext ctx, SettingsController settings) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Velocidad de reproduccion',
              style: TextStyle(color: AuraColors.text, fontSize: 18, fontWeight: FontWeight.bold))),
        ...speeds.map((s) => ListTile(
          title: Text('${s}x',
              style: TextStyle(color: settings.playbackSpeed == s
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
        const SizedBox(height: 16),
      ]),
    );
  }

  void _showSleepTimerPicker(BuildContext ctx, SettingsController settings) {
    final options = [0, 5, 15, 30, 45, 60, 90, 120];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Temporizador de sueno',
              style: TextStyle(color: AuraColors.text, fontSize: 18, fontWeight: FontWeight.bold))),
        ...options.map((m) => ListTile(
          title: Text(m == 0 ? 'Desactivado' : '$m minutos',
              style: TextStyle(color: settings.sleepTimerMinutes == m
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
        const SizedBox(height: 16),
      ]),
    );
  }
}