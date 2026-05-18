import 'package:flutter/foundation.dart';
import '../data/models/eq_config.dart';
import '../data/repositories/eq_repository.dart';
import 'native_equalizer_service.dart';
import 'equalizer_state.dart';
import '../features/equalizer/equalizer_controller.dart';

/// EqualizerService — Compatibility wrapper for the new DSP architecture.
///
/// This class maintains backward compatibility with existing code that
/// uses EqualizerService directly, while delegating to the new modular
/// architecture under the hood.
///
/// New code should use:
/// - EqualizerState for state management
/// - EqualizerController for UI operations
/// - NativeEqualizerService for native communication
///
/// This wrapper exists to avoid breaking existing UI code during the
/// transition to the new architecture.
class EqualizerService extends ChangeNotifier {
  final EqRepository _eqRepository;
  late final NativeEqualizerService _nativeService;
  late final EqualizerState _state;
  late final EqualizerController _controller;

  // Expose the new components for new code
  NativeEqualizerService get nativeService => _nativeService;
  EqualizerState get state => _state;
  EqualizerController get controller => _controller;

  static const List<int> bandFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 12000, 16000, 20000
  ];
  static const int bandCount = 12;

  EqConfig? get currentConfig => _state.currentConfig;
  bool get isEnabled => _state.isEnabled;
  bool get isAvailable => _state.isAvailable;
  bool get limiterEnabled => _state.limiterEnabled;
  bool get loudnessEnabled => _state.loudnessEnabled;
  double get loudness => _state.loudness;
  int get nativeBandCount => _state.nativeBandCount;
  List<int> get nativeBandFrequencies => _state.nativeBandFrequencies;

  EqualizerService(this._eqRepository) {
    _nativeService = NativeEqualizerService();
    _state = EqualizerState(_eqRepository, _nativeService);
    _controller = EqualizerController(_state, _nativeService);

    // Forward state changes to notifyListeners for backward compatibility
    _state.addListener(() => notifyListeners());
  }

  // ─── Backward Compatible API ────────────────────────────────

  Future<void> initSession(int sessionId) async {
    await _controller.initSession(sessionId);
  }

  Future<void> loadGlobal() async {
    await _state.loadGlobal();
  }

  Future<void> saveGlobal() async {
    await _state.saveGlobal();
  }

  Future<void> setBandGain(int index, double gainDb) async {
    await _controller.setBandGain(index, gainDb);
  }

  Future<void> setBassBoost(double gainDb) async {
    await _controller.setBassBoost(gainDb);
  }

  Future<void> setVirtualizer(double strength) async {
    await _controller.setVirtualizer(strength);
  }

  Future<void> toggleEnabled() async {
    await _controller.toggleEnabled();
  }

  Future<void> applyPreset(String name) async {
    await _controller.applyPreset(name);
  }

  Future<void> setLoudness(double db) async {
    await _controller.setLoudness(db);
  }

  Future<void> setLoudnessEnabled(bool enabled) async {
    await _controller.setLoudnessEnabled(enabled);
  }

  Future<void> setLimiterEnabled(bool enabled) async {
    await _controller.setLimiterEnabled(enabled);
  }

  Future<void> setLimiterParams({
    required double threshold,
    required double ratio,
    required double attack,
    required double release,
    required double postGain,
  }) async {
    await _controller.setLimiterParams(
      threshold: threshold,
      ratio: ratio,
      attack: attack,
      release: release,
      postGain: postGain,
    );
  }

  Future<void> setBassFrequency(int hz) async {
    await _controller.setBassFrequency(hz);
  }

  void applyConfigDirect(EqConfig config) {
    _controller.applyConfigDirect(config);
  }

  Future<void> reset() async {
    await _controller.reset();
  }

  @override
  void dispose() {
    _state.dispose();
    _controller.dispose();
    super.dispose();
  }
}
