import 'package:flutter/material.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';
import '../data/repositories/eq_repository.dart';
import '../data/models/eq_config.dart';

class EqualizerService extends ChangeNotifier {
  final EqRepository _eqRepository;

  EqConfig? _currentConfig;
  int? _currentSongId;
  bool _initialized = false;

  Equalizer? _equalizer;
  BassBoost? _bassBoost;
  Virtualizer? _virtualizer;

  EqualizerService(this._eqRepository);

  EqConfig? get currentConfig => _currentConfig;

  int get bandCount => _equalizer?.numberOfBands ?? 0;

  List<String> get bandFrequencies {
    if (_equalizer == null) return const [];
    return List.generate(bandCount, (i) {
      final freq = _equalizer!.getBandFreq(i);
      if (freq >= 1000) return '${(freq / 1000).toStringAsFixed(1)}kHz';
      return '${freq}Hz';
    });
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
      _equalizer = Equalizer(sessionId: audioSessionId);
      _bassBoost = BassBoost(sessionId: audioSessionId);
      _virtualizer = Virtualizer(sessionId: audioSessionId);
      await _equalizer!.init();
      await _bassBoost!.init();
      await _virtualizer!.init();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Equalizer init error: $e');
    }
  }

  Future<void> loadSong(int songId) async {
    _currentSongId = songId;
    var config = await _eqRepository.loadForSong(songId);

    if (config == null) {
      final bands = bandCount;
      config = EqConfig(
        songId: songId,
        bandLevels: List.filled(bands, 0),
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

    if (_equalizer != null) {
      if (config.enabled) {
        for (var i = 0; i < config.bandLevels.length; i++) {
          await _equalizer!.setBandLevel(i, config.bandLevels[i]);
        }
      } else {
        for (var i = 0; i < bandCount; i++) {
          await _equalizer!.setBandLevel(i, 0);
        }
      }
    }

    if (_bassBoost != null) {
      await _bassBoost!.setStrength(config.bassBoostStrength);
    }

    if (_virtualizer != null) {
      await _virtualizer!.setStrength(config.virtualizerStrength);
    }

    await _eqRepository.saveForSong(config);
    notifyListeners();
  }

  List<int> getPreset(String name) {
    final preset = presets[name];
    if (preset == null || preset.isEmpty) {
      return List.filled(bandCount, 0);
    }
    if (preset.length == bandCount) return preset;
    return List.generate(bandCount, (i) => i < preset.length ? preset[i] : 0);
  }

  @override
  void dispose() {
    _equalizer?.release();
    _bassBoost?.release();
    _virtualizer?.release();
    super.dispose();
  }
}
