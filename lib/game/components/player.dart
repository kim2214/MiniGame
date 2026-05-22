import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../runner_game.dart';

enum PlayerState { running, jumping, sliding }

class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameRef<RunnerGame>, CollisionCallbacks {
  static const double playerSize = 80.0; // 키워주면 더 귀엽게 보입니다
  static const double gravity = 1500.0;
  static const double jumpVelocity = -650.0; // 점프력을 살짝 높임
  // 한 달리기 사이클(8프레임) 동안 배경이 시각적으로 진행해야 할 픽셀 거리.
  // 이 값을 gameSpeed로 나눠 stepTime을 동적으로 맞춰 발이 미끄러지지 않게 한다.
  static const double pixelsPerRunCycle = 220.0;
  static const double slideDuration = 0.8;

  double velocityY = 0.0;
  late double groundY;
  late RectangleHitbox _hitbox;
  double _slideTimeLeft = 0;
  final Random _rng = Random();

  Player() : super(size: Vector2.all(playerSize), anchor: Anchor.bottomCenter);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. 이미지 캐시에서 이미지 가져오기
    final runImage = gameRef.images.fromCache('run.png');
    final jumpImage = gameRef.images.fromCache('jump.png');
    final slideImage = gameRef.images.fromCache('slide.png');

    // 2. 프레임 개수 (Run: 8, Jump: 6, Slide: 7). floor로 sub-pixel 방지.
    final runFrameWidth = (runImage.width / 8).floorToDouble();
    final jumpFrameWidth = (jumpImage.width / 6).floorToDouble();
    final slideFrameWidth = (slideImage.width / 7).floorToDouble();

    // 3. 달리기 애니메이션 생성
    final runAnimation = SpriteAnimation.fromFrameData(
      runImage,
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: 0.08, // 사람 달리기 1사이클(약 0.64s)에 맞춰 보폭과 시각 속도를 조정
        textureSize: Vector2(runFrameWidth, runImage.height.toDouble()),
      ),
    );

    // 4. 점프 애니메이션 생성
    final jumpAnimation = SpriteAnimation.fromFrameData(
      jumpImage,
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.1,
        textureSize: Vector2(jumpFrameWidth, jumpImage.height.toDouble()),
        loop: false, // 점프는 공중에서 무한반복되지 않게 설정
      ),
    );

    // 5. 슬라이드 애니메이션 생성 — run.png와 동일하게 전체 프레임을 그대로 재생.
    final slideAnimation = SpriteAnimation.fromFrameData(
      slideImage,
      SpriteAnimationData.sequenced(
        amount: 7,
        stepTime: 0.09,
        textureSize: Vector2(slideFrameWidth, slideImage.height.toDouble()),
        loop: false, // 한 번 재생 후 마지막 프레임 유지
      ),
    );

    // 6. 애니메이션 맵에 등록하고 기본 상태를 running으로 설정
    animations = {
      PlayerState.running: runAnimation,
      PlayerState.jumping: jumpAnimation,
      PlayerState.sliding: slideAnimation,
    };
    current = PlayerState.running;

    groundY = gameRef.size.y - 100.0; // 바닥 높이
    position = Vector2(50.0 + playerSize / 2, groundY);

    // 충돌 박스 - 동적으로 상태에 따라 size/position 변경
    _hitbox = RectangleHitbox(
      size: Vector2(playerSize * 0.5, playerSize * 0.8),
      position: Vector2(playerSize * 0.25, playerSize * 0.1),
    );
    add(_hitbox);
  }

  void _updateHitbox() {
    if (current == PlayerState.sliding) {
      // 낮고 넓은 hitbox — 박쥐 아래로 통과 가능
      _hitbox.size = Vector2(playerSize * 0.7, playerSize * 0.35);
      _hitbox.position = Vector2(playerSize * 0.15, playerSize * 0.62);
    } else {
      _hitbox.size = Vector2(playerSize * 0.5, playerSize * 0.8);
      _hitbox.position = Vector2(playerSize * 0.25, playerSize * 0.1);
    }
  }

  void _syncRunStepTime() {
    final speed = gameRef.gameSpeed;
    if (speed <= 0) return;
    final newStepTime = pixelsPerRunCycle / speed / 8;
    final runFrames = animations?[PlayerState.running]?.frames;
    if (runFrames == null) return;
    for (final frame in runFrames) {
      frame.stepTime = newStepTime;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 달리기 애니메이션 속도를 게임 속도에 동기화 (스케이팅 방지)
    if (current == PlayerState.running) {
      _syncRunStepTime();
    }

    // 슬라이드 타이머 진행
    if (current == PlayerState.sliding) {
      _slideTimeLeft -= dt;
      if (_slideTimeLeft <= 0) {
        current = PlayerState.running;
        _updateHitbox();
      }
    }

    // 공중에 있거나 위로 점프 중일 때만 중력을 적용합니다.
    if (position.y < groundY || velocityY < 0) {
      velocityY += gravity * dt;
      position.y += velocityY * dt;
    }

    // 바닥에 닿았을 때 (착지)
    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;

      // 슬라이드 상태가 아닐 때만 running으로 강제 전환
      if (current != PlayerState.running &&
          current != PlayerState.sliding) {
        current = PlayerState.running;
        _updateHitbox();
      }
    } else {
      // 공중에 떠 있을 때
      if (current != PlayerState.jumping) {
        current = PlayerState.jumping;
        _updateHitbox();
      }
    }
  }

  void jump() {
    // 슬라이드 중이라면 즉시 캔슬하고 점프 (반응성 우선)
    if (current == PlayerState.sliding) {
      _slideTimeLeft = 0;
      current = PlayerState.running;
      _updateHitbox();
    }
    // 바닥에 있을 때만 점프 가능
    if (position.y >= groundY) {
      velocityY = jumpVelocity;
      HapticFeedback.lightImpact();
      gameRef.audio.playJump();
      gameRef.add(_buildJumpDust(Vector2(position.x, groundY)));
    }
  }

  void slide() {
    // 이미 슬라이드 중이거나 공중이면 무시
    if (current == PlayerState.sliding) return;
    if (position.y < groundY) return;

    current = PlayerState.sliding;
    // 슬라이드 애니메이션 한 번 처음부터 재생
    animationTickers?[PlayerState.sliding]?.reset();
    _slideTimeLeft = slideDuration;
    _updateHitbox();
    HapticFeedback.lightImpact();
    gameRef.audio.playJump(); // 슬라이드 시작 SFX (점프 사운드 재활용)
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
              paint: Paint()
                ..color = const Color(0xFF8B6F47).withOpacity(0.65),
            ),
          );
        },
      ),
    );
  }

  void reset() {
    position = Vector2(50.0 + playerSize / 2, groundY);
    velocityY = 0;
    _slideTimeLeft = 0;
    current = PlayerState.running;
    _updateHitbox();
  }
}
