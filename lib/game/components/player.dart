import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../runner_game.dart';

class Player extends SpriteAnimationComponent
    with HasGameRef<RunnerGame>, CollisionCallbacks {
  static const double playerSize = 80.0; // 캐릭터 표시 높이
  static const double gravity = 1500.0;
  static const double jumpVelocity = -650.0; // 점프력을 살짝 높임
  // 한 달리기 사이클(15프레임) 동안 배경이 시각적으로 진행해야 할 픽셀 거리.
  // 이 값을 gameSpeed로 나눠 stepTime을 동적으로 맞춰 발이 미끄러지지 않게 한다.
  static const double pixelsPerRunCycle = 220.0;

  // run.png는 균일 그리드가 아니다 — 캐릭터 15개가 제각각의 간격으로 놓여 있어
  // 등분(sequenced) 슬라이스가 불가능. 알파 채널을 분석해 얻은 각 캐릭터의
  // 중심 기준 srcPosition.x 목록 (프레임 폭 110px 기준).
  static const List<double> _runFrameX = [
    34,
    153,
    277,
    396,
    526,
    642,
    762,
    881,
    996,
    1111,
    1238,
    1351,
    1470,
    1585,
    1701,
  ];

  // 캐릭터가 실제로 그려진 세로 범위 (y 349~508). 위아래 투명 여백을 잘라내
  // 화면에서 납작하게 찌그러지지 않게 한다.
  static const double _runFrameSrcY = 348;
  static const double _runFrameWidth = 110;
  static const double _runFrameHeight = 162;

  static int get runFrameCount => _runFrameX.length;

  double velocityY = 0.0;
  late double groundY;
  final Random _rng = Random();

  Player()
      : super(
          // 원본 프레임 비율(110:162)을 유지해 찌그러짐 방지.
          size: Vector2(
            playerSize * _runFrameWidth / _runFrameHeight,
            playerSize,
          ),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final runImage = gameRef.images.fromCache('run.png');

    // 측정된 프레임 위치로 수동 슬라이스 — 균일 그리드가 아니므로 sequenced 불가.
    final sprites = [
      for (final x in _runFrameX)
        Sprite(
          runImage,
          srcPosition: Vector2(x, _runFrameSrcY),
          srcSize: Vector2(_runFrameWidth, _runFrameHeight),
        ),
    ];
    animation = SpriteAnimation.spriteList(sprites, stepTime: 0.045);

    groundY = gameRef.size.y - 100.0; // 바닥 높이
    position = Vector2(50.0 + size.x / 2, groundY);

    // 충돌 박스 — 캐릭터 본체 중심부만 (팔다리 끝은 제외해 판정을 관대하게)
    add(RectangleHitbox(
      size: Vector2(size.x * 0.6, size.y * 0.8),
      position: Vector2(size.x * 0.2, size.y * 0.1),
    ));
  }

  void _syncRunStepTime() {
    final speed = gameRef.gameSpeed;
    if (speed <= 0) return;
    final newStepTime = pixelsPerRunCycle / speed / runFrameCount;
    final frames = animation?.frames;
    if (frames == null) return;
    for (final frame in frames) {
      frame.stepTime = newStepTime;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 달리기 애니메이션 속도를 게임 속도에 동기화 (스케이팅 방지)
    _syncRunStepTime();

    // 공중에 있거나 위로 점프 중일 때만 중력을 적용합니다.
    if (position.y < groundY || velocityY < 0) {
      velocityY += gravity * dt;
      position.y += velocityY * dt;
    }

    // 바닥에 닿았을 때 (착지)
    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
    }
  }

  void jump() {
    // 바닥에 있을 때만 점프 가능
    if (position.y >= groundY) {
      velocityY = jumpVelocity;
      HapticFeedback.lightImpact();
      gameRef.audio.playJump();
      gameRef.add(_buildJumpDust(Vector2(position.x, groundY)));
    }
  }

  ParticleSystemComponent _buildJumpDust(Vector2 origin) {
    return ParticleSystemComponent(
      position: origin.clone(),
      priority: 5,
      particle: Particle.generate(
        count: 7,
        lifespan: 0.45,
        generator: (i) {
          final dx = (_rng.nextDouble() - 0.5) * 110;
          final dy = -25 - _rng.nextDouble() * 70;
          return AcceleratedParticle(
            speed: Vector2(dx, dy),
            acceleration: Vector2(0, 320),
            child: CircleParticle(
              radius: 1.5 + _rng.nextDouble() * 2.2,
              paint: Paint()..color = const Color(0xFF8B6F47).withOpacity(0.65),
            ),
          );
        },
      ),
    );
  }

  void reset() {
    position = Vector2(50.0 + size.x / 2, groundY);
    velocityY = 0;
  }
}
