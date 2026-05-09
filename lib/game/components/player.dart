import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../runner_game.dart';

enum PlayerState { running, jumping }

class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameRef<RunnerGame>, CollisionCallbacks {
  static const double playerSize = 80.0; // 키워주면 더 귀엽게 보입니다
  static const double gravity = 1500.0;
  static const double jumpVelocity = -650.0; // 점프력을 살짝 높임

  double velocityY = 0.0;
  late double groundY;

  Player() : super(size: Vector2.all(playerSize));

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. 이미지 캐시에서 이미지 가져오기
    final runImage = gameRef.images.fromCache('run.png');
    final jumpImage = gameRef.images.fromCache('jump.png');

    // 2. 올려주신 이미지 기준으로 프레임 개수 유추 (Run: 8개, Jump: 6개)
    final runFrameWidth = runImage.width / 8;
    final jumpFrameWidth = jumpImage.width / 6;

    // 3. 달리기 애니메이션 생성
    final runAnimation = SpriteAnimation.fromFrameData(
      runImage,
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: 0.06, // 0.1에서 0.06으로 줄여 더 빠르고 부드럽게 재생
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

    // 5. 애니메이션 맵에 등록하고 기본 상태를 running으로 설정
    animations = {
      PlayerState.running: runAnimation,
      PlayerState.jumping: jumpAnimation,
    };
    current = PlayerState.running;

    groundY = gameRef.size.y - 100.0; // 바닥 높이
    position = Vector2(50.0, groundY - playerSize);

    // 충돌 박스(Hitbox) 추가 - 캐릭터 이미지에 맞게 크기 조절
    add(RectangleHitbox(
      size: Vector2(playerSize * 0.5, playerSize * 0.8),
      position: Vector2(playerSize * 0.25, playerSize * 0.1),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 공중에 있거나 위로 점프 중일 때만 중력을 적용합니다.
    // (이 조건이 없으면 매 프레임마다 바닥으로 미세하게 파고들었다가 다시 올라오는 과정이 반복되어 캐릭터가 위아래로 덜덜 떨릴 수 있습니다.)
    if (position.y < groundY - playerSize || velocityY < 0) {
      velocityY += gravity * dt;
      position.y += velocityY * dt;
    }

    // 바닥에 닿았을 때 (착지)
    if (position.y >= groundY - playerSize) {
      position.y = groundY - playerSize;
      velocityY = 0;
      
      // 상태가 달리기 상태가 아니라면 변경
      if (current != PlayerState.running) {
        current = PlayerState.running;
      }
    } else {
      // 공중에 떠 있을 때
      if (current != PlayerState.jumping) {
        current = PlayerState.jumping;
      }
    }
  }

  void jump() {
    // 바닥에 있을 때만 점프 가능
    if (position.y >= groundY - playerSize) {
      velocityY = jumpVelocity;
    }
  }

  void reset() {
    position = Vector2(50.0, groundY - playerSize);
    velocityY = 0;
    current = PlayerState.running;
  }
}
