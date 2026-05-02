import 'dart:async';
import 'package:flutter/material.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';
import '../data/repositories/eq_repository.dart';
import '../data/models/eq_config.dart';

class EqualizerService extends ChangeNotifier {
  final EqRepository _eqRepository;

  EqConfig? _currentConfig;
  bool _initialized = false;
  int _bandCount = 0;
  List<int> _centerFreqs = const [];

  EqualizerService(this._eqRepository);

  EqConfig? get currentConfig => _currentConfig;

  int get bandCount => _bandCount;
  List<int> get centerFreqs => _centerFreqs;

  List<String> get bandFrequencies {
    return _centerFreqs.map((freq) {
      final hz = freq ~/ 1000;
      if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}kHz';
      return '${hz}Hz';
    }).toList();
  }

  static const Map<String, List<int>> presets = {
    'Plano': [],
    'Rock': [500, 400, 300, 200, 100],
    'Pop': [200, 100, 0, 100, 200],
    'Jazz': [300, 200, 100, 200, 300],
    'Clásica': [100, 200, 300, 200, 100],
    'Hip-Hop': [600, 500, 0, 200, 400],
    'Electrónica': [400, 300, 200, 300, 400],
    'Latino': [300, 200, 100, 300, 200],
  };

  Future<void> initForSession(int audioSessionId) async {
    if (_initialized) return;
    try {
      await EqualizerFlutter.init(audioSessionId);
      await EqualizerFlutter.setEnabled(true);
      final freqs = await EqualizerFlutter.getCenterBandFreqs();
      _centerFreqs = freqs;
      _bandCount = freqs.length;
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Equalizer init error: $e');
    }
  }

  Future<void> loadSong(int songId) async {
    var config = await _eqRepository.loadForSong(songId);

    if (config == null || config.bandLevels.isEmpty) {
      config = EqConfig(
        songId: songId,
        bandLevels: List.filled(_bandCount, 0),
        bassBoostStrength: 0,
        virtualizerStrength: 0,
        enabled: true,
        presetName: 'Plano',
      );
    }

    _currentConfig = config;
    await applyConfig(config);
  }

  Future<void> applyConfig(EqConfig config) async {
    if (!_initialized) return;

    _currentConfig = config;

    if (config.enabled) {
      for (var i = 0; i < config.bandLevels.length && i < _bandCount; i++) {
        await EqualizerFlutter.setBandLevel(i, config.bandLevels[i]);
      }
    } else {
      for (var i = 0; i < _bandCount; i++) {
        await EqualizerFlutter.setBandLevel(i, 0);
      }
    }

    // Bass boost y virtualizer no están soportados por equalizer_flutter.
    // Los valores se guardan en el repositorio pero no se aplican al hardware.

    await _eqRepository.saveForSong(config);
    notifyListeners();
  }

  List<int> getPreset(String name) {
    final preset = presets[name];
    if (preset == null || preset.isEmpty) {
      return List.filled(_bandCount, 0);
    }
    if (preset.length == _bandCount) return preset;
    return List.generate(_bandCount, (i) => i < preset.length ? preset[i] : 0);
  }

  @override
  void dispose() {
    EqualizerFlutter.release();
    super.dispose();
  }
}
