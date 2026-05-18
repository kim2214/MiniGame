import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_manager.dart';
import 'components/ground.dart';
import 'components/parallax_background.dart';
import 'components/player.dart';
import 'managers/obstacle_manager.dart';

enum GameState { title, playing, gameOver }

class RunnerGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  static const String _bestScoreKey = 'best_score';
  static const double _initialGameSpeed = 300.0;
  static const double _deathAnimDuration = 0.4;
  static const double _deathShakeMagnitude = 12;
  static const int _milestoneStep = 500;

  late Player player;
  late ObstacleManager obstacleManager;
  late TextComponent _scoreText;
  late TextComponent _bestText;

  final AudioManager audio = AudioManager();

  GameState state = GameState.title;
  double score = 0;
  int bestScore = 0;
  double gameSpeed = _initialGameSpeed;

  double _deathAnimTime = 0;
  bool _isNewBest = false;
  int _lastMilestone = 0;
  final Random _rng = Random();

  int get displayScore => score.floor();

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await images.loadAll(['run.png', 'jump.png', 'obstacle.png']);
    await _loadBestScore();
    await audio.init();

    // 배경 패럴랙스 (priority 음수로 항상 뒤에)
    add(SkyLayer());
    add(SunLayer());
    add(DistantMountainLayer());
    add(CloudLayer());
    add(HillLayer());

    add(Ground());
    player = Player();
    add(player);
    obstacleManager = ObstacleManager();
    add(obstacleManager);

    _scoreText = TextComponent(
      text: 'Score: 0',
      anchor: Anchor.topRight,
      position: Vector2(size.x - 16, 16),
      priority: 100,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
    );
    _bestText = TextComponent(
      text: 'Best: $bestScore',
      anchor: Anchor.topRight,
      position: Vector2(size.x - 16, 48),
      priority: 100,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellowAccent,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
    );
    add(_scoreText);
    add(_bestText);

    overlays.add('Title');
    overlays.add('AudioControl');
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    bestScore = prefs.getInt(_bestScoreKey) ?? 0;
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, bestScore);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    switch (state) {
      case GameState.title:
        startGame();
        break;
      case GameState.playing:
        player.jump();
        break;
      case GameState.gameOver:
        // 죽음 연출 중에는 재시작 방지
        if (_deathAnimTime <= 0) {
          resetGame();
        }
        break;
    }
  }

  void startGame() {
    if (state == GameState.playing) return;
    state = GameState.playing;
    score = 0;
    gameSpeed = _initialGameSpeed;
    _lastMilestone = 0;
    _scoreText.text = 'Score: 0';
    overlays.remove('Title');
  }

  void gameOver() {
    if (state == GameState.gameOver) return;
    state = GameState.gameOver;
    _isNewBest = false;
    final intScore = displayScore;
    if (intScore > bestScore && intScore > 0) {
      bestScore = intScore;
      _bestText.text = 'Best: $bestScore';
      _saveBestScore();
      _isNewBest = true;
    }
    audio.playHit();
    _deathAnimTime = _deathAnimDuration;
    // pauseEngine은 죽음 연출이 끝난 뒤에 호출 (overlay도 그 때 표시)
  }

  void resetGame() {
    score = 0;
    gameSpeed = _initialGameSpeed;
    state = GameState.playing;
    _deathAnimTime = 0;
    _lastMilestone = 0;
    obstacleManager.reset();
    player.reset();
    _scoreText.text = 'Score: 0';
    overlays.remove('GameOver');
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (state == GameState.gameOver && _deathAnimTime > 0) {
      _deathAnimTime -= dt;
      if (_deathAnimTime <= 0) {
        _deathAnimTime = 0;
        if (_isNewBest) {
          audio.playNewBest();
        }
        pauseEngine();
        overlays.add('GameOver');
      }
    }

    if (state == GameState.playing) {
      score += gameSpeed * dt / 50.0;
      gameSpeed += 5 * dt;
      _scoreText.text = 'Score: $displayScore';

      final milestone = displayScore ~/ _milestoneStep;
      if (milestone > _lastMilestone) {
        _lastMilestone = milestone;
        audio.playMilestone();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final shaking = state == GameState.gameOver && _deathAnimTime > 0;

    if (shaking) {
      final intensity = _deathAnimTime / _deathAnimDuration;
      final dx =
          (_rng.nextDouble() - 0.5) * 2 * _deathShakeMagnitude * intensity;
      final dy =
          (_rng.nextDouble() - 0.5) * 2 * _deathShakeMagnitude * intensity;
      canvas.save();
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.restore();

      // 빨간 플래시 (위에 덧칠)
      final flashOpacity = 0.55 * intensity;
      final flashPaint = Paint()..color = Colors.red.withOpacity(flashOpacity);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), flashPaint);
    } else {
      super.render(canvas);
    }
  }
}
