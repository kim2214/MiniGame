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
  // 가변 점프 — 상승 중에 입력을 떼면 상승 속도에 곱해 점프를 짧게 끊는다.
  // 짧게 탭 = 낮은 점프(~절반), 누르고 있으면 풀점프.
  static const double _jumpCutFactor = 0.42;

  // 입력 버퍼 — 착지 직전(이 시간 안)의 점프 입력을 기억했다가 닿는 즉시 점프.
  // 타이밍이 약간 빨라도 점프가 씹히지 않아 조작이 공정하게 느껴진다.
  static const double _jumpBufferDuration = 0.12;

  // 한 달리기 사이클(15프레임) 동안 배경이 시각적으로 진행해야 할 픽셀 거리.
  // 이 값을 gameSpeed로 나눠 stepTime을 동적으로 맞춰 발이 미끄러지지 않게 한다.
  // 키울수록 애니메이션이 느려진다. (220 → 330: 프레임 크기 편차가 있는
  // AI 생성 시트라 빠르게 재생하면 덜덜거려 보여 1.5배 느리게 조정)
  static const double pixelsPerRunCycle = 330.0;

  // run.png는 균일 그리드가 아니다 — 캐릭터 15개가 제각각의 간격으로 놓여 있어
  // 등분(sequenced) 슬라이스가 불가능. 알파 채널을 분석해 얻은 srcPosition.x 목록.
  // 정렬 기준은 "머리 중심" — 바운딩 박스 중심으로 자르면 팔다리가 뻗은 방향에
  // 따라 몸통이 프레임마다 좌우로 흔들린다(덜덜거림). 머리는 달리기 내내 거의
  // 고정이므로 머리 x좌표가 모든 프레임에서 같은 위치에 오도록 창을 잡았다.
  // (원본 10번째 캐릭터 srcX=1112는 혼자 10% 작은 이상치 프레임이라 제외 — 움찔거림 유발)
  static const List<double> _runFrameX = [
    38,
    154,
    275,
    397,
    524,
    641,
    762,
    885,
    996,
    1234,
    1353,
    1470,
    1586,
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
  bool _jumpHeld = false;
  double _jumpBufferLeft = 0;
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
    // 초기값 — 실제로는 매 프레임 _syncRunStepTime이 게임 속도에 맞춰 갱신.
    animation = SpriteAnimation.spriteList(sprites, stepTime: 0.073);

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

    // 점프 입력 버퍼 타이머 진행
    if (_jumpBufferLeft > 0) {
      _jumpBufferLeft -= dt;
    }

    // 공중에 있거나 위로 점프 중일 때만 중력을 적용합니다.
    final wasAirborne = position.y < groundY;
    if (wasAirborne || velocityY < 0) {
      velocityY += gravity * dt;
      position.y += velocityY * dt;
    }

    // 바닥에 닿았을 때 (착지)
    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
      if (wasAirborne) {
        _onLand();
        // 착지 직전에 눌렀던 점프가 버퍼에 남아 있으면 즉시 점프.
        // 이미 손을 뗀 짧은 탭이었다면 낮은 점프로 처리.
        if (_jumpBufferLeft > 0) {
          _executeJump();
          if (!_jumpHeld) {
            velocityY *= _jumpCutFactor;
          }
        }
      }
    }
  }

  // 착지 피드백 — 점프보다 약한 먼지 + 가벼운 햅틱
  void _onLand() {
    HapticFeedback.selectionClick();
    gameRef.add(_buildDust(
      Vector2(position.x, groundY),
      count: 5,
      spreadX: 130,
      riseY: 40,
    ));
  }

  /// 점프 입력 시작 (탭 다운 / 위로 스와이프)
  void pressJump() {
    _jumpHeld = true;
    if (position.y >= groundY) {
      _executeJump();
    } else {
      // 공중에서 누른 입력은 버퍼에 저장 → 착지 즉시 점프
      _jumpBufferLeft = _jumpBufferDuration;
    }
  }

  /// 점프 입력 해제 (탭 업 / 드래그 끝) — 상승 중이면 점프를 짧게 끊는다
  void releaseJump() {
    _jumpHeld = false;
    if (velocityY < 0) {
      velocityY *= _jumpCutFactor;
    }
  }

  void _executeJump() {
    velocityY = jumpVelocity;
    _jumpBufferLeft = 0;
    HapticFeedback.lightImpact();
    gameRef.audio.playJump();
    gameRef.add(_buildDust(
      Vector2(position.x, groundY),
      count: 7,
      spreadX: 110,
      riseY: 70,
    ));
  }

  // 흙먼지 파티클 — 점프(위로 솟음)와 착지(옆으로 퍼짐) 양쪽에서 재사용.
  ParticleSystemComponent _buildDust(
    Vector2 origin, {
    required int count,
    required double spreadX,
    required double riseY,
  }) {
    return ParticleSystemComponent(
      position: origin.clone(),
      priority: 5,
      particle: Particle.generate(
        count: count,
        lifespan: 0.45,
        generator: (i) {
          final dx = (_rng.nextDouble() - 0.5) * spreadX;
          final dy = -25 - _rng.nextDouble() * riseY;
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
    _jumpHeld = false;
    _jumpBufferLeft = 0;
  }
}
