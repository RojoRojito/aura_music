import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/eq_config.dart';
import '../../data/models/song.dart';
import '../../widgets/aura_animations.dart';
import '../../services/equalizer_service.dart';
import '../../features/equalizer/equalizer_controller.dart';

class EqualizerScreen extends StatefulWidget {
  final Song? song;
  const EqualizerScreen({super.key, this.song});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const List<int> _uiFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
  ];

  static const Map<int, List<int>> _bandSelections = {
    5:  [0, 2, 5, 8, 11],
    7:  [0, 2, 4, 6, 8, 10, 11],
    10: [0, 1, 2, 4, 5, 6, 7, 9, 10, 11],
  };

  @override
  Widget build(BuildContext context) {
    // Use the new controller for all operations
    final eqController = context.watch<EqualizerController>();
    final eqService = context.watch<EqualizerService>();

    if (!eqController.isAvailable) {
      return Scaffold(
        backgroundColor: AuraColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AuraColors.textOf(context), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Ecualizador', style: TextStyle(color: AuraColors.textOf(context), fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.equalizer, color: AuraColors.textMutedOf(context), size: 64),
              const SizedBox(height: 16),
              Text('Ecualizador no disponible', style: TextStyle(color: AuraColors.textMutedOf(context), fontSize: 16)),
              const SizedBox(height: 8),
              Text('Tu dispositivo no soporta ecualización nativa', style: TextStyle(color: AuraColors.textMutedOf(context), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final config = eqController.currentConfig;

    return Scaffold(
      backgroundColor: AuraColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AuraColors.textOf(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ecualizador',
          style: TextStyle(
            color: AuraColors.textOf(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Show engine mode indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'DSP: ${eqController.engineMode}',
              child: Icon(
                eqController.engineMode == 'dynamics_processing'
                    ? Icons.auto_awesome
                    : eqController.engineMode == 'legacy'
                        ? Icons.build
                        : Icons.warning,
                color: eqController.engineMode == 'dynamics_processing'
                    ? Colors.green
                    : eqController.engineMode == 'legacy'
                        ? Colors.orange
                        : Colors.red,
                size: 20,
              ),
            ),
          ),
          Switch(
            value: eqController.isEnabled,
            onChanged: (_) => eqController.toggleEnabled(),
            activeColor: AuraColors.primary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPresetsSection(eqController, config),
            const SizedBox(height: 20),
            _buildEqSection(eqController, config),
            const SizedBox(height: 20),
            _buildBassSection(eqController, config),
            const SizedBox(height: 20),
            _buildVolumeSection(eqController, config),
            const SizedBox(height: 20),
            _buildLimiterSection(eqController, config),
            const SizedBox(height: 20),
            _buildVirtualizerSection(eqController, config),
            const SizedBox(height: 32),
            _buildResetButton(eqController),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── PRESETS ───────────────────────────────────────────

  Widget _buildPresetsSection(EqualizerController eqController, EqConfig? config) {
    return _sectionContainer(
      context,
      label: 'PRESETS',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EqConfig.presetCurves.keys.map((name) {
            final isSelected = config?.presetName == name;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name),
                selected: isSelected,
                selectedColor: AuraColors.primary.withOpacity(0.3),
                backgroundColor: AuraColors.surfaceOf(context),
                side: BorderSide(
                  color: isSelected ? AuraColors.primary : Colors.white24,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AuraColors.primary : AuraColors.textOf(context),
                  fontSize: 12,
                ),
                onSelected: (_) => eqController.applyPreset(name),
              ),
            ),
          }).toList(),
        ),
      ),
    );
  }

  // ─── ECUALIZADOR (EQ BANDS) ───────────────────────────

  Widget _buildEqSection(EqualizerController eqController, EqConfig? config) {
    final eqEnabled = config?.enabled ?? false;
    final visualCount = config?.visualBandCount ?? 5;
    final selectedIndices = _bandSelections[visualCount] ?? _bandSelections[5]!;

    return _sectionContainer(
      context,
      label: 'ECUALIZADOR',
      toggleValue: eqEnabled,
      onToggle: (_) => eqController.toggleEnabled(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [5, 7, 10].map((count) {
              final isSelected = visualCount == count;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$count'),
                  selected: isSelected,
                  selectedColor: AuraColors.primary.withOpacity(0.3),
                  backgroundColor: AuraColors.surfaceOf(context),
                  side: BorderSide(
                    color: isSelected ? AuraColors.primary : Colors.white24,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? AuraColors.primary : AuraColors.textOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => eqController.setVisualBandCount(count),
                ),
              ),
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: AuraColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: eqEnabled
                ? _buildBandsGrid(eqController, config, selectedIndices)
                : Opacity(
                    opacity: 0.4,
                    child: IgnorePointer(
                      ignoring: true,
                      child: _buildBandsGrid(eqController, config, selectedIndices),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandsGrid(EqualizerController eqController, EqConfig? config, List<int> indices) {
    final bands = config?.bandGains ?? List.filled(12, 0.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: indices.map((i) {
        final freq = _uiFrequencies[i];
        final freqText = freq >= 1000 ? '${freq ~/ 1000}kHz' : '${freq}Hz';
        final gain = i < bands.length ? bands[i] : 0.0;
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
                    color: eqController.isEnabled
                        ? AuraColors.primary
                        : AuraColors.textMutedOf(context),
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
                      onChanged: (v) => eqController.setBandGain(i, v),
                    ),
                  ),
                ),
                Text(
                  freqText,
                  style: TextStyle(
                    color: AuraColors.textMutedOf(context),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      }).toList(),
    );
  }

  // ─── GRAVES (Bass Booster) ─────────────────────────────

  Widget _buildBassSection(EqualizerController eqController, EqConfig? config) {
    final bassEnabled = (config?.bassBoost ?? 0) > 0;
    final bassHz = config?.bassFrequencyHz ?? 80;

    return _sectionContainer(
      context,
      label: 'GRAVES',
      icon: Icons.speaker,
      toggleValue: bassEnabled,
      onToggle: (val) {
        if (!val) {
          eqController.setBassBoost(0);
        } else {
          eqController.setBassBoost(5);
        }
      },
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.speaker, color: AuraColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 15,
                  divisions: 30,
                  value: config?.bassBoost ?? 0.0,
                  activeColor: AuraColors.accent,
                  inactiveColor: Colors.white12,
                  onChanged: bassEnabled
                      ? (v) => eqController.setBassBoost(v)
                      : null,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '+${(config?.bassBoost ?? 0.0).toStringAsFixed(1)} dB',
                  style: TextStyle(
                    color: AuraColors.accent,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [30, 60, 80, 100].map((hz) {
              final isSelected = bassHz == hz;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$hz Hz'),
                  selected: isSelected,
                  selectedColor: AuraColors.primary.withOpacity(0.3),
                  backgroundColor: AuraColors.surfaceOf(context),
                  side: BorderSide(
                    color: isSelected ? AuraColors.primary : Colors.white24,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? AuraColors.primary : AuraColors.textOf(context),
                    fontSize: 11,
                  ),
                  onSelected: bassEnabled
                      ? (_) => eqController.setBassFrequency(hz)
                      : null,
                ),
              ),
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── VOLUMEN (Loudness) ────────────────────────────────

  Widget _buildVolumeSection(EqualizerController eqController, EqConfig? config) {
    final loudEnabled = config?.loudnessEnabled ?? false;

    return _sectionContainer(
      context,
      label: 'VOLUMEN',
      icon: Icons.volume_up,
      toggleValue: loudEnabled,
      onToggle: (val) => eqController.setLoudnessEnabled(val),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.volume_up, color: AuraColors.secondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  value: config?.loudness ?? 0.0,
                  activeColor: AuraColors.secondary,
                  inactiveColor: Colors.white12,
                  onChanged: loudEnabled
                      ? (v) => eqController.setLoudness(v)
                      : null,
                ),
              ),
              SizedBox(
                width: 58,
                child: Text(
                  '+${(config?.loudness ?? 0.0).toStringAsFixed(1)} dB',
                  style: TextStyle(
                    color: AuraColors.secondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aumenta el volumen percibido sin distorsión',
            style: TextStyle(
              color: AuraColors.textMutedOf(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIMITADOR ─────────────────────────────────────────

  Widget _buildLimiterSection(EqualizerController eqController, EqConfig? config) {
    final limiterOn = config?.limiterEnabled ?? false;

    return _sectionContainer(
      context,
      label: 'LIMITADOR',
      toggleValue: limiterOn,
      onToggle: (val) => eqController.setLimiterEnabled(val),
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: limiterOn
                ? Column(
                    children: [
                      _buildLimiterSlider(
                        'Umbral',
                        config?.limiterThreshold ?? -3.0,
                        -12.0, 0.0, 24,
                        (v) => eqController.setLimiterParams(threshold: v),
                        'dB',
                      ),
                      _buildLimiterSlider(
                        'Ratio',
                        config?.limiterRatio ?? 4.0,
                        1.0, 20.0, 19,
                        (v) => eqController.setLimiterParams(ratio: v),
                        'x',
                      ),
                      _buildLimiterSlider(
                        'Ataque',
                        config?.limiterAttack ?? 10.0,
                        1.0, 200.0, 199,
                        (v) => eqController.setLimiterParams(attack: v),
                        'ms',
                      ),
                      _buildLimiterSlider(
                        'Salida',
                        config?.limiterPostGain ?? 0.0,
                        0.0, 6.0, 12,
                        (v) => eqController.setLimiterParams(postGain: v),
                        'dB',
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Previene distorsión al subir el volumen',
                      style: TextStyle(
                        color: AuraColors.textMutedOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            'Solo disponible en Android 9+',
            style: TextStyle(
              color: AuraColors.textMutedOf(context),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimiterSlider(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                color: AuraColors.textMutedOf(context),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              value: value,
              activeColor: AuraColors.primary,
              inactiveColor: Colors.white12,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                color: AuraColors.textOf(context),
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ─── VIRTUALIZADOR 3D ─────────────────────────────────

  Widget _buildVirtualizerSection(EqualizerController eqController, EqConfig? config) {
    final virtEnabled = (config?.virtualizer ?? 0) > 0;

    return _sectionContainer(
      context,
      label: 'VIRTUALIZADOR 3D',
      icon: Icons.surround_sound,
      toggleValue: virtEnabled,
      onToggle: (val) {
        if (!val) {
          eqController.setVirtualizer(0);
        } else {
          eqController.setVirtualizer(0.5);
        }
      },
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.surround_sound, color: AuraColors.secondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 1,
                  divisions: 20,
                  value: config?.virtualizer ?? 0.0,
                  activeColor: AuraColors.secondary,
                  inactiveColor: Colors.white12,
                  onChanged: virtEnabled
                      ? (v) => eqController.setVirtualizer(v)
                      : null,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${((config?.virtualizer ?? 0.0) * 100).round()}%',
                  style: TextStyle(
                    color: AuraColors.secondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mejor experiencia con auriculares',
            style: TextStyle(
              color: AuraColors.textMutedOf(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESET BUTTON ──────────────────────────────────────

  Widget _buildResetButton(EqualizerController eqController) {
    return Center(
      child: TextButton(
        onPressed: () => _showResetDialog(context, eqController),
        style: TextButton.styleFrom(foregroundColor: AuraColors.errorOf(context)),
        child: const Text('Restablecer todo'),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────

  Widget _sectionContainer(
    BuildContext context, {
    required String label,
    required Widget child,
    IconData? icon,
    bool? toggleValue,
    ValueChanged<bool>? onToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuraColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AuraColors.textMutedOf(context), size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: AuraColors.textMutedOf(context),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (toggleValue != null && onToggle != null)
                Switch(
                  value: toggleValue,
                  onChanged: onToggle,
                  activeColor: AuraColors.primary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          toggleValue == false
              ? Opacity(
                  opacity: 0.4,
                  child: IgnorePointer(ignoring: true, child: child),
                )
              : child,
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, EqualizerController eqController) {
    showAuraDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraColors.surfaceOf(context),
        title: Text(
          'Restablecer ecualizador',
          style: TextStyle(color: AuraColors.textOf(context)),
        ),
        content: Text(
          '¿Restablecer todos los ajustes a valores por defecto?',
          style: TextStyle(color: AuraColors.textMutedOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: AuraColors.textOf(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              eqController.reset();
            },
            style: TextButton.styleFrom(foregroundColor: AuraColors.errorOf(context)),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }
}
