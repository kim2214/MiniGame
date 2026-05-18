import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManager {
  static const String _muteKey = 'audio_muted';

  static const String jumpSfx = 'jump.wav';
  static const String hitSfx = 'hit.wav';
  static const String milestoneSfx = 'score_milestone.wav';
  static const String newBestSfx = 'new_best.wav';

  final ValueNotifier<bool> mutedNotifier = ValueNotifier<bool>(false);

  bool get isMuted => mutedNotifier.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    mutedNotifier.value = prefs.getBool(_muteKey) ?? false;
    await FlameAudio.audioCache.loadAll([
      jumpSfx,
      hitSfx,
      milestoneSfx,
      newBestSfx,
    ]);
  }

  Future<void> setMuted(bool muted) async {
    mutedNotifier.value = muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, muted);
  }

  void toggleMute() {
    setMuted(!isMuted);
  }

  void play(String name, {double volume = 1.0}) {
    if (isMuted) return;
    FlameAudio.play(name, volume: volume);
  }

  void playJump() => play(jumpSfx, volume: 0.6);
  void playHit() => play(hitSfx, volume: 0.8);
  void playMilestone() => play(milestoneSfx, volume: 0.5);
  void playNewBest() => play(newBestSfx, volume: 0.7);
}
