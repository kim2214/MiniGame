import 'dart:math';

import 'package:flame/components.dart';

import '../components/obstacle.dart';
import '../runner_game.dart';

class ObstacleManager extends Component with HasGameRef<RunnerGame> {
  // 기본 spawn interval (gameSpeed=300 기준). 게임 속도가 빨라질수록 줄어듦.
  static const double _baseInterval = 1.8;

  // 최소 간격 캡 — 점프 비행시간(~0.87s) 보장.
  static const double _minInterval = 1.05;

  // 무작위 추가 지연 (0~_jitterMax). 패턴 단조로움 방지. 음수 jitter는 안 줘서 안 어려워지게.
  static const double _jitterMax = 0.5;

  // 군집 패턴 해금 점수 — 더블은 200부터, 트리플은 500부터.
  static const int _doubleUnlockScore = 200;
  static const int _tripleUnlockScore = 500;

  // 군집 내 선인장 간 중심 거리 (선인장 폭 대비 배율). 살짝 겹쳐 덤불 느낌.
  static const double _clusterSpacingFactor = 0.85;

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
      final clusterWidth = spawnObstacle();
      // 군집이 차지하는 폭만큼 다음 간격을 연장 — 군집 끝을 넘자마자
      // 다음 장애물이 오는 불가능 패턴 방지.
      _nextInterval = _calcNextInterval() + clusterWidth / gameRef.gameSpeed;
    }
  }

  double _calcNextInterval() {
    double base = _baseInterval * (300.0 / gameRef.gameSpeed);
    if (base < _minInterval) base = _minInterval;
    return base + random.nextDouble() * _jitterMax;
  }

  /// 장애물 패턴 하나를 스폰하고, 단일 대비 추가로 차지한 폭(px)을 반환.
  double spawnObstacle() {
    final score = gameRef.displayScore;

    // 군집 개수 결정 — 점수에 따라 해금, 확률은 고정 (난이도는 속도가 담당)
    final roll = random.nextDouble();
    int count = 1;
    if (score >= _tripleUnlockScore && roll < 0.12) {
      count = 3;
    } else if (score >= _doubleUnlockScore && roll < 0.32) {
      count = 2;
    }

    if (count == 1) {
      // 단일 — 크기 0.8~1.2 랜덤. 큰 선인장은 풀점프, 작은 건 짧은 점프로도 통과.
      final factor = 0.8 + random.nextDouble() * 0.4;
      gameRef.add(Obstacle(sizeFactor: factor));
      return 0;
    }

    // 군집 — 멤버는 약간 작게(0.78~0.95) 통일해 점프 가능성 보장.
    final factor = 0.78 + random.nextDouble() * 0.17;
    final spacing = Obstacle.baseSize * factor * _clusterSpacingFactor;
    for (var i = 0; i < count; i++) {
      gameRef.add(Obstacle(sizeFactor: factor, xOffset: i * spacing));
    }
    return (count - 1) * spacing;
  }

  void reset() {
    timer = 0;
    _nextInterval = _baseInterval;
    gameRef.children.whereType<Obstacle>().forEach((o) => o.removeFromParent());
  }
}
