import 'dart:math';

import 'package:flame/components.dart';

import '../components/flying_obstacle.dart';
import '../components/obstacle.dart';
import '../runner_game.dart';

class ObstacleManager extends Component with HasGameRef<RunnerGame> {
  // 기본 spawn interval (gameSpeed=300 기준). 게임 속도가 빨라질수록 줄어듦.
  static const double _baseInterval = 1.8;
  // 최소 간격 캡 — 점프 비행시간(~0.87s) 보장.
  static const double _minInterval = 1.05;
  // 무작위 추가 지연 (0~_jitterMax). 패턴 단조로움 방지. 음수 jitter는 안 줘서 안 어려워지게.
  static const double _jitterMax = 0.5;
  // 박쥐 등장 시작 점수.
  static const int _batStartScore = 100;

  double timer = 0;
  double _nextInterval = _baseInterval;
  final random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    timer += dt;
    if (timer >= _nextInterval) {
      timer = 0;
      spawnObstacle();
      _nextInterval = _calcNextInterval();
    }
  }

  double _calcNextInterval() {
    double base = _baseInterval * (300.0 / gameRef.gameSpeed);
    if (base < _minInterval) base = _minInterval;
    return base + random.nextDouble() * _jitterMax;
  }

  void spawnObstacle() {
    // 점수 100까지는 선인장만. 이후 박쥐 확률이 점진 상승 (최대 40%).
    final score = gameRef.displayScore;
    final batChance = ((score - _batStartScore) / 600).clamp(0.0, 0.4);
    final spawnBat =
        score > _batStartScore && random.nextDouble() < batChance;

    if (spawnBat) {
      gameRef.add(FlyingObstacle());
    } else {
      gameRef.add(Obstacle());
    }
  }

  void reset() {
    timer = 0;
    _nextInterval = _baseInterval;
    gameRef.children.whereType<Obstacle>().forEach((o) => o.removeFromParent());
    gameRef.children
        .whereType<FlyingObstacle>()
        .forEach((o) => o.removeFromParent());
  }
}
