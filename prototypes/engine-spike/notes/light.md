# light: 2D 라이트 (제단 안전 반경, 저녁 어둠, 불꽃, 노멀맵, 그림자)

시험일 2026-10-18, Godot 4.7.2 stable (official), Windows 11 데스크탑(RTX 5090), SSH 세션에서 Git Bash로 실행.
렌더러 두 가지로 같은 캡처를 돌렸다: Forward+ (Vulkan 1.4.341, 프로젝트 기본값)와 Compatibility (OpenGL 3.3, `--rendering-method gl_compatibility`).

## 시험한 것

요구사항 "2D 라이트(제단 안전 반경, 저녁 어둠, 스스로 빛나는 불꽃, 노멀맵)" (game-concept §12-§13, concept-art-brief §5.7, §7 체크리스트의 "테두리가 디더링으로 사라지는 빛 원").

장면 `res://light/light_demo.tscn` (메뉴·`--scene=light`는 `light.tscn`이 이 장면을 인스턴스한다):

- 풀밭: `tiles_grass_base_v02.png` 한 장을 `TileMapLayer`(16px)에 깔았다 (코드에서 TileSet 생성)
- 제단 `altar_v04.png` (48x57) + 캐릭터 `base_body_v02_walk.png` 3명: 빛 안, 빛 밖(손등불), 빛 경계를 오가며 걷는 1명
- 저녁 어둠: `CanvasModulate` 따뜻한 회색 (0.40, 0.34, 0.31). 그림자가 파랗지 않고 갈색이 되게 (§10)
- 안전 반경: 제단 등잔 3x3 중심에 `PointLight2D`. 빛 텍스처를 코드로 만든다 (반지름 R px, `texture_scale` 1 = 텍셀 하나가 기본 해상도 픽셀 하나).
  테두리 4가지: hard / dither (4x4 Bayer, 월드 좌표에 고정, 폭 16px) / banded (2단 0.6·0.3) / smooth. 기본 7타일 = 112px, 기본 테두리 dither.
  게임 규칙 `is_in_safe_zone()`이 빛 텍스처와 같은 숫자(반지름)를 쓴다
- 캐릭터 전용 빛 (`AltarLightActors`): 땅·제단·벽은 light_mask 1, 캐릭터는 2. 땅에는 디더 테두리 빛, 캐릭터에는 같은 반지름의 hard 테두리 빛을 따로 비춘다 (A 키로 끄고 켬)
- 불꽃: `altar_v04.png`와 `altar_v04_unlit.png`가 다르고 밝기 148 이상인 픽셀 = 불꽃 마스크 (81픽셀 = 등잔 9개 x 9). 같은 자리에 `CanvasItemMaterial.LIGHT_MODE_UNSHADED`로 한 번 더 그린다
- 노멀맵: 스크립트로 생성 (`light_gen.gd normal_map()`): 알파 경계까지 거리(2px 베벨) + 밝기(줄눈은 홈) → Sobel 기울기. 앞면 행(제단 40행부터)은 남쪽(화면 아래)을 향하게. `CanvasTexture.normal_texture`로 넣었다. 벽 블록도 같은 방식
- 그림자: 32x32 돌 블록(제단 팔레트로 코드에서 그림) + `LightOccluder2D` (바닥 발자국 32x16 사각형), 그림자 필터 없음(픽셀 그대로)
- 기타 측정: 한 캔버스 아이템이 받는 빛 개수 한도, 프레임 시간

## 실행

```bash
GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
SPIKE=prototypes/engine-spike
timeout 300 "$GODOT" --headless --path $SPIKE --script res://tests/run_all.gd -- --only=light < /dev/null   # 헤드리스 테스트
timeout 300 "$GODOT" --path $SPIKE --script res://light/capture_light.gd < /dev/null                         # 창이 3초쯤 떴다 닫힌다
timeout 300 "$GODOT" --path $SPIKE --rendering-method gl_compatibility --script res://light/capture_light.gd -- --no-images --tag=_gl < /dev/null
"$GODOT" --path $SPIKE -- --scene=light        # 직접 보기. E 테두리, A 캐릭터 빛, N 노멀맵, F 불꽃, C 저녁, S 그림자, L 손등불, +/- 반경, Space 정지, H HUD
```

캡처는 `--headless`로 안 된다 (더미 렌더러. 그러면 종료 코드 2). 결과는 `shots/`:

| 파일 | 내용 |
|---|---|
| `light_dither.png`, `light_hard.png`, `light_banded.png`, `light_smooth.png`, `light_day.png` | 기본 해상도 480x270. day = 저녁·빛 끔 (비교 기준) |
| `light_dither_1080.png`, `light_hard_1080.png` | 1920x1080 = 480x270의 정수 4배. 프로젝트 설정(스트레치 viewport + integer)에서 1080p 화면에 실제로 나오는 그림과 같다 |
| `light_dither_1080_native.png` | 비교용: 2D를 1920x1080으로 직접 그림 (SubViewport, canvas_items 스트레치와 같은 방식) |
| `light_edges.png` | 경계 동쪽을 테두리 4가지로 나란히 (hard, dither, banded, smooth), 3배 |
| `light_actor_split.png` | 경계 위 캐릭터: 빛 하나를 같이 씀 / 캐릭터 전용 hard 빛, 4배 |
| `light_altar_normals.png` | 제단: 노멀맵 끔 / 켬 / 생성한 노멀맵, 3배 |
| `light_limit_probe.png` | 빛 30개를 TileMapLayer 한 사분면 위에 (15개만 켜짐) |
| `light_metrics.json`, `light_metrics_gl.json` | 아래 수치 전부 (Vulkan / OpenGL) |

## 수치

픽셀 비율 = (그 장면의 밝기) / (day 장면의 같은 픽셀 밝기). Vulkan과 OpenGL이 소수 둘째 자리까지 같아서 하나만 적는다 (다른 것만 따로).

| 항목 | 결과 |
|---|---|
| 헤드리스 테스트 `test_light.gd` | 161 checks 통과, 약 0.2초 |
| 캡처 스크립트 전체 (이미지 + 벤치마크) | 약 3초, 종료 코드 0, 오류 줄 없음 |
| 빛 안 / 빛 밖 RGB 배율 | 안 (1.05, 0.97, 0.90) = 그린 색 그대로(조금 따뜻하게) / 밖 (0.40, 0.34, 0.31) = 저녁색 그대로 |
| 안전 반경 규칙 = 그림 | hard 텍스처 224x224 텍셀 전부 `is_in_safe_zone()`과 일치 (테스트). 화면 픽셀 510개 표본에서 불일치 0 (캡처. 단 표본이 가로·세로 두 줄이라 경계를 지나는 곳은 4군데뿐이고, 캡처는 불일치가 있어도 종료 0이다). 디더 텍셀은 반경 밖에 하나도 없음 |
| 테두리 마지막 밝은 픽셀 (동쪽, R=112) | hard 112, dither 109, banded 112, smooth 109 |
| 테두리 안 밝기 단계 수 | hard 2, dither 2 (켜짐/꺼짐만), banded 4 (1.0/0.75/0.55/0.35), smooth 14 |
| 경계 위 캐릭터 (발 거리 105px, 243픽셀) | 빛 공유: 밝은 픽셀 68, 행 안 밝음↔어둠 바뀜 99번 (얼굴에 체커보드) / 캐릭터 전용 hard 빛: 밝은 픽셀 201, 바뀜 16번 (반경선 한 줄이 머리를 지남) |
| 불꽃 81픽셀 (unshaded) | 원본 색과 채널 차 최대 **0**, 최저 밝기 151. 제단 빛을 꺼도 0 |
| 불꽃 (shaded, 비교) | 채널 차 최대 162, 최저 밝기 55 (저녁에 묻힘) |
| 노멀맵: 제단 윗면 / 앞면 | 켬 0.974 / 0.61, 끔 0.991 / 0.989. 빛이 제단 위(height 64)에 있어 윗면은 거의 그대로, 남쪽을 보는 앞면이 어두워진다 |
| 노멀맵 방향 확인 (작은 빛을 북쪽/남쪽에) | 북쪽 빛: 북쪽 테두리 0.76 > 앞면 0.354. 남쪽 빛: 앞면 0.868 > 북쪽 테두리 0.459. 노멀맵 끄면 둘 다 0.96 |
| 그림자 (벽 뒤 땅) | 0.36 (= 어둠과 같음), 그림자 옆 같은 거리 땅 0.98 |
| 오클루더 cull_mode와 벽 앞면 | DISABLED·CLOCKWISE: 벽 앞면까지 그림자 0.354. COUNTER_CLOCKWISE: 앞면 0.644 (= 그림자 끈 값), 뒤 땅은 0.36 그대로. 기본값으로 CCW를 쓴다 |
| 한 캔버스 아이템이 받는 빛 | Sprite2D 한 장, TileMapLayer(사분면 16 = 256x256px가 아이템 하나): 30개 중 **15개**만. 사분면 4(64x64px): 30/30. 스프라이트 따로 30개: 30/30. 두 렌더러 같음 |

### 프레임 시간 (vsync 끔, 600프레임 평균, 기본 해상도 480x270에서 그림)

| 장면 | Vulkan Forward+ 평균 / p99 | OpenGL Compatibility 평균 / p99 |
|---|---|---|
| 데모 장면 그대로 (빛 3 + 그림자, 오클루더 1) | 0.30 ms / 2.9 ms | 0.41 ms / 2.7 ms |
| + 움직이는 횃불 9개(그림자 켬) + 오클루더 30개 | 0.51 ms / 2.9 ms | 1.09 ms / 3.8 ms |
| + 빛 64개 전부 그림자 켬 + 오클루더 30개 | 0.83 ms / 2.8 ms | 3.28 ms / 4.7 ms (CPU 렌더 3.1 ms) |
| 빛 64개, 그림자 끔 | 0.38 ms / 2.4 ms | 0.55 ms / 2.3 ms |

- RTX 5090 + 9950X3D 기준이라 절대값은 낮게 나온다. 차이만 본다: 그림자 켠 빛이 비용의 대부분이고, 그림자 빛 64개에서 OpenGL은 Vulkan보다 프레임 시간이 4배쯤 길다 (CPU 렌더 시간 0.23 → 3.1 ms)
- 같은 측정을 캐릭터 전용 빛을 넣기 전에도 한 번 돌렸을 때는 0.15 / 0.27 / 0.52 / 0.20 ms였다. 실행마다 2배 넘게 흔들린다 (통합 뒤 검증 재실행에서 빛 64개 그림자 끔이 0.70ms)
- 창 크기는 1440x810을 요청했지만 SSH 세션에서 1028x749로 떴다. viewport 스트레치라 2D는 480x270에서 그리므로 창 크기는 결과에 거의 영향이 없다

## 실패하거나 걸린 것

- **한 아이템에 빛 15개 한도** (프로젝트 설정에서 바꿀 항목을 찾지 못했다): TileMapLayer는 기본으로 16x16칸(256px)을 아이템 하나로 그리므로, 그 안에 빛이 16개 이상 겹치면 일부가 그냥 안 비친다. 9인 + 손등불 + 제단 + 건물 조명이면 닿을 수 있다. 땅 레이어는 `rendering_quadrant_size`를 4~8로 줄이면 풀린다 (4에서 30/30 확인). 그리기 호출이 늘어나는 비용은 이번에 재지 않았다
- **디더 테두리가 캐릭터에도 찍힌다**: 같은 빛을 쓰면 경계 위 캐릭터 얼굴에 체커보드가 생긴다 (위 99번). light_mask로 캐릭터에 hard 빛을 따로 주면 풀린다 (빛 1개 추가). 그래도 반경선 한 줄이 몸을 가를 수 있다. "발이 안이면 몸 전체가 밝다"가 필요하면 셰이더나 modulate로 따로 해야 한다 (시험 안 함)
- **움직이는 빛의 디더는 헤엄친다**: 제단 빛은 디더를 월드 좌표에 고정했지만, 손등불은 텍스처가 빛을 따라 움직여 걸을 때 땅 위 무늬가 1px씩 밀린다 (코드상 당연한 결과, 화면으로 따로 재지는 않음). 월드 고정이 필요하면 `light()` 셰이더로 디더를 계산해야 한다 (시험 안 함)
- **Godot 4.7.2 오류 줄 두 가지** (별도 탐침 스크립트로 재현, 그림에는 영향 없음):
  - `PointLight2D.texture`를 새 텍스처로 바꾸면서 옛 텍스처가 바로 해제되면 `ERROR: Parameter "t" is null. (texture_remove_from_decal_atlas)`. Vulkan, OpenGL 둘 다 (OpenGL은 `texture_remove_from_texture_atlas`). 데모는 만든 빛 텍스처를 캐시에 붙잡아 둬서 피한다
  - 실행 중 `CanvasTexture.normal_texture`를 바꾸면 `ERROR: Attempted to free invalid ID` (Vulkan만). 데모는 노멀맵을 바꾸지 않고 스프라이트의 텍스처를 CanvasTexture ↔ 일반 텍스처로 바꿔 켜고 끈다
  - 이 오류 줄은 엔진 쪽 오류라 지금 테스트 러너는 실패로 세지 않는다 (스크립트 오류만 센다. 헤드리스 더미 렌더러에서는 나지도 않는다). 실제 게임에서 빛 반경 업그레이드 때 텍스처를 갈아 끼우는 코드는 이 점을 지켜야 한다
- **노멀맵은 은은하다**: 위에서 내려다보는 낮은 물체라 윗면은 거의 정면을 보고, 효과는 테두리 1~2px과 앞면에서만 난다. 제단 빛이 물체 바로 위에 있으면 앞면이 어두워진다 (빛이 뒤에 있으므로 맞는 결과). 생성 노멀맵은 알파·밝기만 보므로 그림의 의도와 다를 수 있다. PixelLab MCP의 `create_normal_map`은 비교하지 않았다 (유료)
- **오클루더는 다각형이다**: 벽 블록 하나에 손으로 넣었다. 부서지는 벽은 TileSet의 occlusion layer(타일마다 오클루더)로 갈 텐데, 칸을 지울 때 그림자가 따라 바뀌는지는 이 모듈에서 시험하지 않았다
- **1080p를 직접 그리면 픽셀이 깨진다**: `light_dither_1080_native.png`처럼 2D를 화면 해상도로 그리면 그림자 경계가 아트 픽셀보다 잘게(믹셀) 나온다. 지금 설정(viewport 스트레치, 정수 배율)이면 그림자 계단도 아트 픽셀 단위다
- 디더 테두리 빛 텍스처는 Godot에 내장된 것이 없어 GDScript로 만든다: 반경 40px 2.3 ms, 112px 12.5 ms, 192px 33.8 ms (헤드리스, 한 번만 만들고 캐시). 반경 업그레이드 때 한 번이면 문제없지만 매 프레임은 안 된다. 제단 노멀맵 생성은 7.9 ms.
  내장 `GradientTexture2D`(방사형)로는 부드러운 원이나 CONSTANT 보간 계단까지만 되고 디더는 없다 (GradientTexture2D는 시험하지 않음)
- 프로젝트 설정은 바꾸지 않았다 (필요한 것은 모두 실행 중 노드 속성으로). 요청 없음

## 이 게임에 쓸 때 정할 것 (제안)

- 안전 반경 테두리: dither를 기본으로 (북극성 v6의 "디더링으로 사라지는 빛 원"과 같음). banded도 픽셀풍에 맞는다. smooth는 단계가 14개라 픽셀풍과 어긋난다
- 빛 레이어 두 장: 월드(땅·건물) / 캐릭터. 캐릭터는 hard 테두리
- 땅 TileMapLayer `rendering_quadrant_size`를 줄이거나 화면 안 그림자 빛 수를 정해 둔다
- 불꽃·성물 촛불 등 발광 픽셀은 unshaded 덧그림 (concept-art-brief §5.7 "불꽃은 손으로 그려 빛 마스크와 함께")

## 판정

**strong** — 요구한 2D 라이트가 전부 Godot 4 기본 노드로 된다 (CanvasModulate, PointLight2D, CanvasTexture 노멀맵, LightOccluder2D, unshaded 머티리얼). 안전 반경은 픽셀 하나까지 게임 규칙과 맞출 수 있고, 디더 테두리도 텍셀 = 픽셀로 깨끗하며, 불꽃은 저녁에도 원본 색 그대로다. 두 렌더러 결과가 같고, 프레임 시간은 그림자 빛 64개에서도 Vulkan 0.8 ms, OpenGL 3.3 ms다 (이 데스크탑 기준).
걸리는 점은 아이템당 빛 15개 한도, 텍스처 교체 오류 줄(우회 가능), 디더 테두리를 캐릭터와 나눠야 하는 점이다. 셋 다 설계로 피할 수 있다.
