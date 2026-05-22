import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/effects.dart';

import 'audio_manager.dart';
import 'components/ground.dart';
import 'components/milestone_popup.dart';
import 'components/parallax_background.dart';
import 'components/player.dart';
import 'components/player_shadow.dart';
import 'managers/obstacle_manager.dart';

enum GameState { title, playing, paused, gameOver }

class RunnerGame extends FlameGame
    with TapCallbacks, DragCallbacks, HasCollisionDetection {
  static const String _bestScoreKey = 'best_score';
  static const double _initialGameSpeed = 300.0;
  static const double _deathAnimDuration = 0.4;
  static const double _deathShakeMagnitude = 12;
  static const int _milestoneStep = 500;

  // 난이도 곡선: speed = init + (max - init) * (1 - e^(-t/tau))
  // 완화된 곡선: t=0:300, t=30:~431, t=60:~518, t=∞:620
  static const double _maxGameSpeed = 620.0;
  static const double _speedTimeConstant = 70.0;

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
  double _elapsedTime = 0;
  Vector2? _dragOrigin;
  bool _dragGestureTriggered = false;
  // 작은 임계값으로 입력 반응성 ↑ (스와이프 의도 빠르게 감지)
  static const double _swipeThreshold = 20.0;
  final Random _rng = Random();

  int get displayScore => score.floor();

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await images.loadAll(
      ['run.png', 'jump.png', 'slide.png', 'obstacle.png', 'bat.png'],
    );
    await _loadBestScore();
    await audio.init();

    // 배경 패럴랙스 (priority 음수로 항상 뒤에). 렌더 순서는 priority가 결정.
    add(SkyLayer());
    add(StarLayer());
    add(MoonLayer());
    add(SunLayer());
    add(DistantMountainLayer());
    add(CloudLayer());
    add(HillLayer());
    add(AtmosphereOverlay());

    add(Ground());
    player = Player();
    add(PlayerShadow()); // 플레이어보다 먼저 add → 같은 priority에서 뒤에 그려짐
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
    // TapCallbacks + DragCallbacks가 함께 있으면 제스처 아레나가 둘을 구분.
    // onTapDown은 드래그가 아닌 "확정된 탭"일 때만 호출되므로 어느 위치든 점프.
    switch (state) {
      case GameState.title:
        startGame();
        break;
      case GameState.playing:
        player.jump();
        break;
      case GameState.paused:
        break;
      case GameState.gameOver:
        if (_deathAnimTime <= 0) {
          resetGame();
        }
        break;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragOrigin = event.localPosition.clone();
    _dragGestureTriggered = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (state != GameState.playing) return;
    if (_dragGestureTriggered) return;
    final origin = _dragOrigin;
    if (origin == null) return;
    final dy = event.localEndPosition.y - origin.y;
    if (dy > _swipeThreshold) {
      // 아래로 스와이프 → 슬라이드
      player.slide();
      _dragGestureTriggered = true;
    } else if (dy < -_swipeThreshold) {
      // 위로 스와이프 → 점프
      player.jump();
      _dragGestureTriggered = true;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragOrigin = null;
    _dragGestureTriggered = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragOrigin = null;
    _dragGestureTriggered = false;
  }

  void startGame() {
    if (state == GameState.playing) return;
    state = GameState.playing;
    score = 0;
    gameSpeed = _initialGameSpeed;
    _elapsedTime = 0;
    _lastMilestone = 0;
    _scoreText.text = 'Score: 0';
    overlays.remove('Title');
    overlays.add('PauseControl');
  }

  void pause() {
    if (state != GameState.playing) return;
    state = GameState.paused;
    pauseEngine();
    overlays.remove('PauseControl');
    overlays.add('Paused');
  }

  void resume() {
    if (state != GameState.paused) return;
    state = GameState.playing;
    overlays.remove('Paused');
    overlays.add('PauseControl');
    resumeEngine();
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
      _pulseBestText();
    }
    audio.playHit();
    _deathAnimTime = _deathAnimDuration;
    overlays.remove('PauseControl');
    // pauseEngine은 죽음 연출이 끝난 뒤에 호출 (overlay도 그 때 표시)
  }

  void resetGame() {
    score = 0;
    gameSpeed = _initialGameSpeed;
    state = GameState.playing;
    _deathAnimTime = 0;
    _elapsedTime = 0;
    _lastMilestone = 0;
    obstacleManager.reset();
    player.reset();
    _scoreText.text = 'Score: 0';
    // 죽음 연출 중 pause로 인해 펄스 스케일이 남아있을 수 있어 초기화
    _bestText.scale = Vector2.all(1.0);
    overlays.remove('GameOver');
    overlays.remove('Paused');
    overlays.add('PauseControl');
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
      _elapsedTime += dt;
      // 점근 곡선: 초반엔 빠르게 가속, 720px/s에 수렴
      gameSpeed = _initialGameSpeed +
          (_maxGameSpeed - _initialGameSpeed) *
              (1 - exp(-_elapsedTime / _speedTimeConstant));
      score += gameSpeed * dt / 50.0;
      _scoreText.text = 'Score: $displayScore';

      final milestone = displayScore ~/ _milestoneStep;
      if (milestone > _lastMilestone) {
        _lastMilestone = milestone;
        audio.playMilestone();
        add(MilestonePopup(scoreValue: milestone * _milestoneStep));
      }
    }
  }

  void _pulseBestText() {
    _bestText.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.45),
          EffectController(duration: 0.15, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.22, curve: Curves.easeIn),
        ),
      ]),
    );
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
