import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// NativeEqualizerService — Clean bridge between Flutter and native DSP engine.
///
/// This replaces the old EqualizerService that mixed UI state management
/// with native communication. Now this class ONLY handles the MethodChannel
/// communication layer.
///
/// State management is handled by EqualizerState (separate class).
/// UI logic is handled by EqualizerController (separate class).
class NativeEqualizerService {
  static const _channel = MethodChannel("com.daviddev.aura/equalizer");

  /// Initialize the DSP engine with an audio session ID.
  /// Called when just_audio provides a valid androidAudioSessionId.
  /// Returns a map with 'success' boolean indicating whether init succeeded.
  Future<dynamic> initSession(int sessionId) async {
    try {
      debugPrint('[NativeEQ] initSession: sessionId=$sessionId');
      final result = await _channel.invokeMethod("initSession", {"sessionId": sessionId});
      debugPrint('[NativeEQ] initSession OK: $result');
      return result;
    } catch (e) {
      debugPrint('[NativeEQ] initSession ERROR: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Enable or disable the entire DSP engine.
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod("setEnabled", {"enabled": enabled});
    } catch (e) {
      debugPrint('[NativeEQ] setEnabled ERROR: $e');
    }
  }

  /// Get the number of native EQ bands available on this device.
  Future<int> getBandCount() async {
    try {
      final result = await _channel.invokeMethod("getBandCount");
      return (result as num?)?.toInt() ?? 5;
    } catch (e) {
      debugPrint('[NativeEQ] getBandCount ERROR: $e');
      return 5;
    }
  }

  /// Get the center frequencies of native EQ bands in Hz.
  Future<List<int>> getBandFrequencies() async {
    try {
      final result = await _channel.invokeMethod("getBandFrequencies");
      if (result is List) {
        return result.map((e) => (e as num).toInt()).toList();
      }
      return [60, 230, 910, 3600, 14000];
    } catch (e) {
      debugPrint('[NativeEQ] getBandFrequencies ERROR: $e');
      return [60, 230, 910, 3600, 14000];
    }
  }

  /// Set gain for a specific EQ band.
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    try {
      await _channel.invokeMethod("setBandGain", {
        "bandIndex": bandIndex,
        "gainDb": gainDb,
      });
    } catch (e) {
      debugPrint('[NativeEQ] setBandGain ERROR: $e');
    }
  }

  /// Set all EQ band gains at once.
  Future<void> setAllBandGains(List<double> gains) async {
    try {
      await _channel.invokeMethod("setAllBandGains", {"gains": gains});
    } catch (e) {
      debugPrint('[NativeEQ] setAllBandGains ERROR: $e');
    }
  }

  /// Set bass boost strength (0-15 dB).
  /// In DynamicsProcessing mode, this is applied as gain on the first EQ band.
  /// In legacy mode, this uses the Android BassBoost effect.
  Future<void> setBassBoost(double gainDb) async {
    try {
      await _channel.invokeMethod("setBassBoost", {"gainDb": gainDb});
    } catch (e) {
      debugPrint('[NativeEQ] setBassBoost ERROR: $e');
    }
  }

  /// Set bass target frequency (30-120 Hz).
  /// In DynamicsProcessing mode, this sets the cutoff frequency of the first EQ band.
  Future<void> setBassFrequency(int hz) async {
    try {
      await _channel.invokeMethod("setBassFrequency", {"hz": hz});
    } catch (e) {
      debugPrint('[NativeEQ] setBassFrequency ERROR: $e');
    }
  }

  /// Set virtualizer strength (0.0-1.0).
  Future<void> setVirtualizer(double strength) async {
    try {
      await _channel.invokeMethod("setVirtualizer", {"strength": strength});
    } catch (e) {
      debugPrint('[NativeEQ] setVirtualizer ERROR: $e');
    }
  }

  /// Set loudness enhancer gain (0-10 dB).
  Future<void> setLoudness(double gainDb) async {
    try {
      await _channel.invokeMethod("setLoudness", {"gainDb": gainDb});
    } catch (e) {
      debugPrint('[NativeEQ] setLoudness ERROR: $e');
    }
  }

  /// Enable or disable loudness enhancer.
  Future<void> setLoudnessEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod("setLoudnessEnabled", {"enabled": enabled});
    } catch (e) {
      debugPrint('[NativeEQ] setLoudnessEnabled ERROR: $e');
    }
  }

  /// Enable or disable the limiter.
  Future<void> setLimiterEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod("setLimiterEnabled", {"enabled": enabled});
    } catch (e) {
      debugPrint('[NativeEQ] setLimiterEnabled ERROR: $e');
    }
  }

  /// Set limiter parameters.
  Future<void> setLimiterParams({
    required double threshold,
    required double ratio,
    required double attack,
    required double release,
    required double postGain,
  }) async {
    try {
      await _channel.invokeMethod("setLimiter", {
        "threshold": threshold,
        "ratio": ratio,
        "attack": attack,
        "release": release,
        "postGain": postGain,
      });
    } catch (e) {
      debugPrint('[NativeEQ] setLimiterParams ERROR: $e');
    }
  }

  /// Get the current engine mode: "dynamics_processing", "legacy", or "unavailable".
  Future<String> getEngineMode() async {
    try {
      final result = await _channel.invokeMethod("getEngineMode");
      return result as String? ?? "unavailable";
    } catch (e) {
      debugPrint('[NativeEQ] getEngineMode ERROR: $e');
      return "unavailable";
    }
  }

  /// Reinitialize the current DSP session.
  /// Useful after app recreation or configuration changes.
  Future<void> reinitializeSession() async {
    try {
      await _channel.invokeMethod("reinitializeSession");
      debugPrint('[NativeEQ] reinitializeSession OK');
    } catch (e) {
      debugPrint('[NativeEQ] reinitializeSession ERROR: $e');
    }
  }

  // ─── DSP State Persistence ───────────────────────────────────

  /// Save the current DSP state to native SharedPreferences.
  Future<void> saveDspState() async {
    try {
      await _channel.invokeMethod("saveDspState");
      debugPrint('[NativeEQ] saveDspState OK');
    } catch (e) {
      debugPrint('[NativeEQ] saveDspState ERROR: $e');
    }
  }

  /// Load DSP state from native SharedPreferences.
  /// Returns a map with all DSP configuration values.
  Future<Map<String, dynamic>> loadDspState() async {
    try {
      final result = await _channel.invokeMethod("loadDspState");
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      debugPrint('[NativeEQ] loadDspState ERROR: $e');
      return {};
    }
  }

  /// Set whether the DSP engine should be restored after device boot.
  Future<void> setRestoreAfterBoot(bool enabled) async {
    try {
      await _channel.invokeMethod("setRestoreAfterBoot", {"enabled": enabled});
    } catch (e) {
      debugPrint('[NativeEQ] setRestoreAfterBoot ERROR: $e');
    }
  }
}
