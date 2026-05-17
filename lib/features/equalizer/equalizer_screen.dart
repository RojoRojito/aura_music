import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/eq_config.dart';
import '../../data/models/song.dart';
import '../../services/equalizer_service.dart';

class EqualizerScreen extends StatefulWidget {
  final Song song;
  const EqualizerScreen({super.key, required this.song});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EqualizerService>().loadForSong(widget.song.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eqService = context.watch<EqualizerService>();
    final config = eqService.currentConfig;
    final isEnabled = eqService.isEnabled;

    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AuraColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ecualizador',
              style: TextStyle(
                color: AuraColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.song.title,
              style: const TextStyle(
                color: AuraColors.textMuted,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Switch(
            value: isEnabled,
            onChanged: (_) => eqService.toggleEnabled(),
            activeColor: AuraColors.primary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRESETS',
              style: TextStyle(
                color: AuraColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: EqConfig.presets.keys.map((name) {
                  final isSelected = config?.presetName == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      selectedColor: AuraColors.primary.withOpacity(0.3),
                      backgroundColor: AuraColors.surface,
                      side: BorderSide(
                        color: isSelected ? AuraColors.primary : Colors.white24,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AuraColors.primary : AuraColors.text,
                        fontSize: 12,
                      ),
                      onSelected: (_) => eqService.applyPreset(name),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ECUALIZADOR — ${eqService.nativeBandCount} BANDAS NATIVAS',
              style: const TextStyle(
                color: AuraColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 270,
              decoration: BoxDecoration(
                color: AuraColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isEnabled
                  ? _buildBandsGrid(eqService, config)
                  : Opacity(
                      opacity: 0.4,
                      child: IgnorePointer(
                        ignoring: true,
                        child: _buildBandsGrid(eqService, config),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            const Text(
              'GRAVES',
              style: TextStyle(
                color: AuraColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.speaker, color: AuraColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 15,
                    divisions: 30,
                    value: config?.bassBoost ?? 0.0,
                    activeColor: AuraColors.accent,
                    inactiveColor: Colors.white12,
                    onChanged: isEnabled
                        ? (v) => eqService.setBassBoost(v)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '+${(config?.bassBoost ?? 0.0).toStringAsFixed(1)} dB',
                    style: const TextStyle(
                      color: AuraColors.accent,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'VIRTUALIZADOR',
              style: TextStyle(
                color: AuraColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.surround_sound, color: AuraColors.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 1,
                    divisions: 20,
                    value: config?.virtualizer ?? 0.0,
                    activeColor: AuraColors.secondary,
                    inactiveColor: Colors.white12,
                    onChanged: isEnabled
                        ? (v) => eqService.setVirtualizer(v)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${((config?.virtualizer ?? 0.0) * 100).round()}%',
                    style: const TextStyle(
                      color: AuraColors.secondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: TextButton(
                onPressed: () => _showResetDialog(context, eqService),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Restablecer esta canción'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandsGrid(EqualizerService eqService, EqConfig? config) {
    final bands = config?.bandGains ?? List.filled(12, 0.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(12, (i) {
        final freq = EqualizerService.bandFrequencies[i];
        final freqText = freq >= 1000 ? '${freq ~/ 1000}kHz' : '${freq}Hz';
        final gain = bands[i];
        final gainText = gain >= 0 ? '+${gain.toStringAsFixed(1)}' : gain.toStringAsFixed(1);
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  gainText,
                  style: TextStyle(
                    color: eqService.isEnabled
                        ? AuraColors.primary
                        : AuraColors.textMuted,
                    fontSize: 9,
                  ),
                ),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      min: -12,
                      max: 12,
                      divisions: 48,
                      value: gain,
                      activeColor: AuraColors.primary,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => eqService.setBandGain(i, v),
                    ),
                  ),
                ),
                Text(
                  i == 0 || i == 4 || i == 8 || i == 11
                      ? freqText
                      : freqText.replaceAll('Hz', ''),
                  style: const TextStyle(
                    color: AuraColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showResetDialog(BuildContext context, EqualizerService eqService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraColors.surface,
        title: const Text(
          'Restablecer ecualizador',
          style: TextStyle(color: AuraColors.text),
        ),
        content: const Text(
          '¿Restablecer todos los ajustes para esta canción?',
          style: TextStyle(color: AuraColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              eqService.resetSong();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }
}