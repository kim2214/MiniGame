import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/ground.dart';
import 'components/player.dart';
import 'managers/obstacle_manager.dart';

enum GameState { title, playing, gameOver }

class RunnerGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  static const String _bestScoreKey = 'best_score';
  static const double _initialGameSpeed = 300.0;

  late Player player;
  late ObstacleManager obstacleManager;
  late TextComponent _scoreText;
  late TextComponent _bestText;

  GameState state = GameState.title;
  double score = 0;
  int bestScore = 0;
  double gameSpeed = _initialGameSpeed;

  // 외부(GameOver 오버레이 등)에서 표시할 정수 점수
  int get displayScore => score.floor();

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await images.loadAll(['run.png', 'jump.png', 'obstacle.png']);
    await _loadBestScore();

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
        // GameOver 오버레이의 Restart 버튼에서 처리하므로 화면 탭으로도 가능하게 둠.
        resetGame();
        break;
    }
  }

  void startGame() {
    if (state == GameState.playing) return;
    state = GameState.playing;
    score = 0;
    gameSpeed = _initialGameSpeed;
    _scoreText.text = 'Score: 0';
    overlays.remove('Title');
  }

  void gameOver() {
    if (state == GameState.gameOver) return;
    state = GameState.gameOver;
    final intScore = displayScore;
    if (intScore > bestScore) {
      bestScore = intScore;
      _bestText.text = 'Best: $bestScore';
      _saveBestScore();
    }
    pauseEngine();
    overlays.add('GameOver');
  }

  void resetGame() {
    score = 0;
    gameSpeed = _initialGameSpeed;
    state = GameState.playing;
    obstacleManager.reset();
    player.reset();
    _scoreText.text = 'Score: 0';
    overlays.remove('GameOver');
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state == GameState.playing) {
      // 거리 기반 점수: 빠르게 달릴수록 더 많이 적립 (프레임레이트 무관).
      score += gameSpeed * dt / 50.0;
      gameSpeed += 5 * dt;
      _scoreText.text = 'Score: $displayScore';
    }
  }
}
