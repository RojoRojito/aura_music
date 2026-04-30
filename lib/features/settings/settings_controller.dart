import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static const String _keySleepTimer = 'sleep_timer_minutes';
  static const String _keyPlaybackSpeed = 'playback_speed';
  static const String _keyDynamicTheme = 'dynamic_theme';

  SharedPreferences? _prefs;

  int _sleepTimerMinutes = 0;
  double _playbackSpeed = 1.0;
  bool _dynamicThemeEnabled = true;

  int get sleepTimerMinutes => _sleepTimerMinutes;
  double get playbackSpeed => _playbackSpeed;
  bool get dynamicThemeEnabled => _dynamicThemeEnabled;

  DateTime? _sleepTimerEnd;
  Timer? _sleepTimerCountdown;
  final _sleepTimerController = StreamController<void>.broadcast();

  Stream<void> get onSleepTimerExpired => _sleepTimerController.stream;
  DateTime? get sleepTimerEnd => _sleepTimerEnd;

  bool get isSleepTimerActive => _sleepTimerEnd != null && _sleepTimerEnd!.isAfter(DateTime.now());

  String get sleepTimerRemaining {
    if (_sleepTimerEnd == null) return 'Desactivado';
    final remaining = _sleepTimerEnd!.difference(DateTime.now());
    if (remaining.isNegative) return 'Desactivado';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _sleepTimerMinutes = _prefs?.getInt(_keySleepTimer) ?? 0;
    _playbackSpeed = _prefs?.getDouble(_keyPlaybackSpeed) ?? 1.0;
    _dynamicThemeEnabled = _prefs?.getBool(_keyDynamicTheme) ?? true;
    notifyListeners();
  }

  Future<void> setSleepTimer(int minutes) async {
    _sleepTimerMinutes = minutes;
    _sleepTimerCountdown?.cancel();
    if (minutes > 0) {
      _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimerCountdown = Timer(Duration(minutes: minutes), () {
        _sleepTimerEnd = null;
        _sleepTimerMinutes = 0;
        _sleepTimerController.add(null);
        notifyListeners();
      });
    } else {
      _sleepTimerEnd = null;
    }
    await _prefs?.setInt(_keySleepTimer, minutes);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _prefs?.setDouble(_keyPlaybackSpeed, speed);
    notifyListeners();
  }

  Future<void> setDynamicTheme(bool enabled) async {
    _dynamicThemeEnabled = enabled;
    await _prefs?.setBool(_keyDynamicTheme, enabled);
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimerCountdown?.cancel();
    _sleepTimerEnd = null;
    _sleepTimerMinutes = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimerCountdown?.cancel();
    _sleepTimerController.close();
    super.dispose();
  }
}