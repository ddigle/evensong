# 엔진 스파이크 결과: Godot 4.7.2

시험일 2026-10-18. Godot 4.7.2 stable (official, ed1daf0bf), Windows 11 데스크탑(Ryzen 9 9950X3D, RTX 5090), SSH 세션에서 Git Bash로 실행.
렌더러는 Forward+ (Vulkan 1.4.341, 프로젝트 기본값)이고, 빛은 비교용으로 Compatibility (OpenGL 3.3)에서도 돌렸다.

- 판정: **strong** = 이 게임에 그대로 쓸 수 있다 / **ok** = 되지만 직접 짤 것이나 확인할 것이 남았다 / **weak** = 이 게임에 맞지 않거나 크게 손봐야 한다
- 수치는 모두 이 데스크탑에서 잰 것이라 절대값이 낮게 나온다. 비교와 규모를 보는 데 쓴다
- 이 스파이크는 Godot만 시험했다. Unity와 나란히 비교하지 않았다
- 버리는 프로젝트다. 코드는 `game/`으로 옮기지 않는다 (README)

## 합친 것

| 모듈 | 브랜치 (커밋) | 모듈 판정 | 노트 |
|---|---|---|---|
| skeleton | `feat/engine-spike` (9007667) | strong | [notes/skeleton.md](notes/skeleton.md) |
| tiles | `feat/engine-spike-tiles` (69b8ff5, a492e83) | strong | [notes/tiles.md](notes/tiles.md) |
| light | `feat/engine-spike-light` (367af87) | strong | [notes/light.md](notes/light.md) |
| net | `feat/engine-spike-net` (aa94462) | strong | [notes/net.md](notes/net.md) |
| chars | `feat/engine-spike-chars` (b604151) | strong | [notes/chars.md](notes/chars.md) |

네 브랜치를 `git merge --no-ff`로 합쳤고 충돌은 없었다. 모듈 폴더 밖에서 겹친 파일은 `shots/.gdignore` 하나였다 (light와 chars가 같은 빈 파일을 넣음).
`project.godot`, `tests/run_all.gd`, `tests/spike_test.gd`는 어느 모듈도 고치지 않았다.

## 요약

| 요구사항 | 판정 | 핵심 수치 |
|---|---|---|
| [헤드리스·CLI](#1-헤드리스cli) | **strong** | 새 클론 임포트 3.0초, 전체 테스트 1,297 checks 36초, 내보내기 3.0초. 모두 종료 코드로 판정 |
| [타일 자동 타일·부수기·성능](#2-타일-자동-타일부수기성능) | **strong** (직접 짠 dual grid 기준. 내장 terrain은 weak) | 512² 채우기 0.46~0.65초, 편집 한 번 평균 0.05~0.24ms. 그림이 있는 조합은 틀린 칸 0, 그림이 없는 조합은 가장 가까운 타일로 그려 이음매가 남는다 |
| [여러 층](#3-여러-층) | **ok** | 레이어 4장 동작. 칸당 약 300B, 1024²×3장 전체 다시 그리기 2.7초라 조각 스트리밍을 짜야 한다 |
| [빛·어둠·노멀맵·불꽃](#4-빛어둠노멀맵불꽃) | **strong** | 빛 텍스처 = 안전 반경 규칙 (텍셀 전부 일치), 불꽃 색 차 0, 그림자 빛 64개 Vulkan 0.6~1.0ms (실행마다 흔들림) |
| [네트워크 동기화·늦은 접속·대역폭](#5-네트워크-동기화늦은-접속대역폭) | **strong** (자동 시험은 localhost, 두 기기는 사람 확인) | 9인 해시 일치, 9인 30Hz 호스트 송신 약 36KB/s (≈ 0.34 Mbps), 늦은 참가 스냅샷 19KB |
| [Steam 준비](#6-steam-준비) | **ok** | 전송 계층 교체 자리와 GodotSteam 4.7.2 빌드 확인(웹). 설치·실행은 안 함 |
| [캐릭터 레이어·팔레트](#7-캐릭터-레이어팔레트) | **strong** (팔레트는 지금 에셋 쪽이 weak) | GPU 그림 = CPU 기준 그림 (480x270 전체 프레임 6장, 다른 픽셀 0) |
| [화면 배율](#8-화면-배율) | **strong** | 6조합 모두 정수·정사각 배율, 내부 렌더 다른 픽셀 0. 실제 화면 캡처도 같음 (창 아래 모서리 둥글림만 다름, 2026-10-21) |

## 이번 통합에서 돌린 것

합친 뒤의 `feat/engine-spike`에서 저장소 루트 기준으로 돌렸다. `GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"`, `SPIKE=prototypes/engine-spike`, 명령마다 `< /dev/null`과 `timeout`.

| 단계 | 명령 | 결과 |
|---|---|---|
| 임포트 (작업 트리) | `"$GODOT" --headless --path $SPIKE --import` | 종료 0, 오류 줄 0, 바뀐 파일 없음 |
| 임포트 (새 클론) | `git archive HEAD`를 빈 폴더에 풀고 같은 명령 | **2.95초**, 종료 0, 오류 줄 0. 그 폴더에서 전체 테스트도 통과 (1,297 checks, 35.9초) |
| 전체 테스트 | `--script res://tests/run_all.gd -- --timeout=300` | **5파일 통과, 1,297 checks, 35.7초, 종료 0**. chars 744 (0.2초), light 161 (0.2초), net 168 (13.6초), skeleton 48 (0.01초), tiles 176 (21.7초) |
| 9인 네트워크 | `... -- --only=net --net-clients=8` | 233 checks, 14.4초, 통과 |
| 내보내기 | `--export-release "Windows Desktop" build/evensong_spike.exe` | 3.0초, 종료 0. `evensong_spike.exe` 109,582,160 B (104.5 MiB, pck 내장), 콘솔 래퍼 188,928 B |
| 내보낸 exe 헤드리스 | `build/evensong_spike.console.exe --headless -- --smoke` | 0.28초, `SPIKE_SMOKE ok godot=4.7.2-stable (official) display=headless base=480x270 stretch=2/1 exported=true modules=4`, 종료 0. `ok`는 고정 문자열이라 exe가 뜨고 끝나는 것만 보여 준다 |
| 내보낸 exe에서 모듈 장면 | `... --headless --quit-after 120 -- --scene=<모듈>` | tiles 1.2초, light 1.0초, net 2.4초 (호스트로 포트 24620을 열고 끝남), chars 1.0초. 넷 다 종료 0, 오류 줄 0 |
| 스크린샷 (스켈레톤) | `-- --screenshot=shots/menu.png`, `-- --scene=<모듈> --screenshot=shots/scene_<모듈>.png --frames=30` | 5장 모두 `error=0`, 장마다 1.1~1.4초. 메뉴가 네 모듈을 모두 찾음 |
| tiles 스크린샷 | `-- --scene=tiles --tiles-method=b` / `=a` (→ `tiles/shots/`) | 둘 다 `error=0`. 지도 픽셀은 커밋된 그림과 같고 HUD의 빌드 시간 숫자(50픽셀)만 달라서 커밋된 파일을 그대로 뒀다 |
| tiles 렌더 벤치 | `--script res://tiles/bench_tiles.gd -- --render` (창) | 18.7초, 종료 0. 수치는 §2 |
| light 캡처 (Vulkan) | `--script res://light/capture_light.gd` (창) | 2.6초, 종료 0, 오류 줄 0. PNG 12장이 커밋된 것과 바이트까지 같음 |
| light 캡처 (OpenGL) | `--rendering-method gl_compatibility --script res://light/capture_light.gd -- --no-images --tag=_gl` | 4.1초, 종료 0. 수치가 Vulkan과 소수 둘째 자리까지 같음 (프레임 시간 빼고) |
| chars GPU 검증 | `res://chars/chars.tscn -- --chars-shots=shots` | 1.3초, `CHARS_VERIFY ok frames=6 characters=32 pixels=777600 mismatches=0`. PNG 같음 |
| chars 배율 | `res://chars/scale.tscn -- --chars-scale-shots=shots` | 3.4초, `CHARS_SCALE ok` 6/6. PNG 같음 |
| chars 화면 캡처 확인 | `res://chars/scale.tscn -- --scale=4 --chars-present-check` | 종료 3, `CHARS_PRESENT unavailable` (SSH = Windows 세션 0이라 화면 캡처가 빈 그림). 예상한 결과 |

- light 벤치 수치는 실행마다 흔들려서, 커밋된 `shots/light_metrics*.json`(모듈 실행 값)은 그대로 두고 이번 값은 §4 표에 적었다
- 새로 넣은 그림: [shots/menu.png](shots/menu.png), [shots/scene_tiles.png](shots/scene_tiles.png), [shots/scene_light.png](shots/scene_light.png), [shots/scene_net.png](shots/scene_net.png), [shots/scene_chars.png](shots/scene_chars.png) (모두 480x270, 합쳐 약 120KB)

## 요구사항별 결과

### 1. 헤드리스·CLI

판정 **strong**. 근거: [notes/skeleton.md](notes/skeleton.md), [shots/menu.png](shots/menu.png)

| 항목 | 수치 |
|---|---|
| 새 클론 → 임포트 | 2.95초, 종료 0 |
| 전체 테스트 | 1,297 checks, 35.7초 (대부분 net 다중 프로세스 13.6초와 tiles 512² 벤치 21.7초) |
| 모듈 하나만 (`--only=<모듈>`) | chars·light 0.2초, net 14초, tiles 22초 |
| 내보내기 + exe 실행 | 3.0초 + 0.28초 |
| 내보낸 exe에서 장면 120프레임 (헤드리스) | 1.0~2.4초 |
| 스크린샷 (창, 480x270) | 장면당 1.1~1.4초 |
| 러너가 실패를 놓치지 않는가 | check 실패, null 호출, 없는 키, 파싱 오류, 끝나지 않는 await 5종 모두 FAIL·종료 1 (skeleton에서 일부러 깨 봄). **단, GDScript 스크립트 오류만 센다**: `push_error()`와 엔진 쪽 오류(널 인자, 범위 밖 인덱스, 없는 노드)는 오류 줄만 찍히고 통과한다 (검증에서 확인). net 자식 프로세스의 엔진 오류도 세지 않는다 |
| 그림을 사람 눈 없이 판정 | GPU 렌더 = CPU 기준 그림 (chars, 다른 픽셀 0, 종료 코드로 판정), 빛 텍스처 = 게임 규칙 (light 테스트), 이음매·틀린 칸 수 (tiles). light 캡처는 수치를 찍기만 하고 늘 종료 0이다 |
| 다중 프로세스 | 테스트가 `OS.create_process`로 헤드리스 인스턴스 4~9개를 띄우고 해시로 비교, 남은 프로세스 정리 |
| check 수 | 품질 척도로 보지 않는다. chars 744개 중 약 360개는 캐릭터가 읽는 표를 같은 표와 비교해서 틀릴 수 없다. 테스트가 실제로 깨지는지는 "일부러 깨 보기"(§7, skeleton)가 보여 준다 |

걸린 것:
- 스크린샷·캡처·렌더 벤치는 렌더러가 필요해서 `--headless`로는 안 된다 (창이 1~4초 뜬다). 이 데스크탑은 SSH에서도 되지만, GPU 없는 클라우드 컨테이너는 시험하지 않았다
- 실제 화면 출력(스왑체인)은 SSH(세션 0)에서 읽을 수 없다. 데스크탑 세션에서 돌리면 읽힌다 (2026-10-21 화면 배율 확인, §8)
- `--quit-after`는 `--` **앞에** 써야 한다. 뒤에 쓰면 사용자 인자로 넘어가 장면이 끝나지 않는다 (이번 통합에서 한 번 겪음. `timeout`으로 죽이면 `Unreferenced static string` 오류 줄이 나오는데 강제 종료 때문이다)
- 내보낸 exe의 `--screenshot=` 상대 경로는 현재 폴더가 아니라 exe 폴더 기준이다
- 에디터 언어가 한국어라 임포트·내보내기 진행 줄이 한국어(색 코드 포함)로 나온다. 판정은 종료 코드와 `SPIKE_*` 줄로 한다

### 2. 타일 자동 타일·부수기·성능

판정 **strong** (직접 짠 dual grid (b) 기준). Godot 내장 terrain (a)은 이 게임에 **weak**.
근거: [notes/tiles.md](notes/tiles.md), [tiles/shots/tiles_b.png](tiles/shots/tiles_b.png) (dual grid), [tiles/shots/tiles_a.png](tiles/shots/tiles_a.png) (내장 terrain), [shots/scene_tiles.png](shots/scene_tiles.png)

우리 PixelLab 코너 타일셋(풀↔흙, 풀↔오염, 던전 바닥↔벽)을 PNG + JSON에서 `TileSet`(`.tres`)으로 다시 만들 수 있게 빌드하고 (두 번 빌드해도 md5 같음), 16px `TileMapLayer`에 두 방법으로 놓았다.

| 항목 | (b) dual grid (권장) | (a) Godot terrain |
|---|---|---|
| 우리 타일셋과 뜻이 맞나 | 맞다. 꼭짓점 = 월드 칸 (PixelLab 코너 정의 그대로) | 안 맞다. 칸 가운데 지형 + 모서리 비트를 풀이기가 추측 |
| 괭이질 한 칸 | 칸 가운데 16x16 덩어리, 2x2는 32x32 | 칸 모서리에 붙은 덩어리, 2x2도 덩어리 하나 |
| 512² 채우기, 지상 (단독 / 테스트 안) | 604ms / 649ms | 4,753ms / 4,809ms |
| 512² 채우기, 던전 (단독 / 테스트 안) | 461ms / 514ms | 8,499ms / 8,503ms |
| 편집 2,000번, 매번 갱신 (평균 / p99, 테스트 안) | 지상 235 / 458µs, 던전 219 / 433µs | 지상 442 / 640µs, 던전 496 / 834µs |
| 편집 2,000번, 한꺼번에 갱신 (평균, 테스트 안) | 지상 66µs, 던전 65µs | 지상 276µs, 던전 320µs |
| 틀린 칸 (그림이 있는 조합만) | 0 (지상 263,169칸, 던전 178,299칸) | 칸 가운데 지형 틀림 0 |
| 이음매 (512², 같은 잣대, 무작위 편집 뒤) | 지상 약 1,200 (흙 옆 재), 던전 약 22,000 (빈 조합을 가장 가까운 타일로) | 지상 863, 던전 30,909 |
| 같은 데이터 → 같은 그림 | 그렇다 (꼭짓점 + 위치 해시) | 아니다 (칠한 순서, 전역 RNG) |
| 부순 벽을 다시 쌓으면 | 처음과 같음 | 6칸이 처음과 다름 |
| 실제 렌더 (창, 512² 레이어, 프레임마다 화면 안 1칸 편집, 300프레임, 이번 실행) | 편집 프레임 평균 0.72~0.76ms, 최대 3.4~4.9ms | 평균 0.89~1.01ms, 최대 2.7~5.3ms |
| 직접 짠 코드 | 약 450줄 (`wang.gd`, `wang_lookup.gd`, `dual_grid.gd`) | 거의 없음 |

- 처음 표는 (b)를 "틀린 칸"(빈 조합 칸은 셈에서 뺌), (a)를 "이음매"로 서로 다른 잣대로 쟀다. 검증 단계에서 같은 벤치 상태를 (a)의 이음매 잣대로 다시 재니 (b)는 지상에서 더 많고 던전에서 약 30% 적었다. (b)를 고르는 근거는 이음매 수가 아니라 코너 뜻이 우리 타일셋과 같다는 것, 칠한 순서와 상관없이 같은 그림, 채우기가 8~18배 빠르다는 것이다. 이음매는 그림 쪽 빈 조합을 채우거나 흙과 재가 맞닿지 않게 하는 규칙으로 줄인다
- 렌더 쪽 (a)/(b) 차이는 흔들림 안이다. 검증 재실행에서는 (b) 지상 1.11ms, (a) 1.00ms였다 (처음 도는 (b) 지상은 예열이 없어 느리게 나온다)
- "단독"은 모듈 노트의 `bench_tiles.gd --quality` 값, "테스트 안"은 이번 통합 전체 테스트의 `TILES_BENCH` 값이다 (다른 레이어가 살아 있어 10~50% 느리다)
- 부서지는 벽: 벽 하나를 부수면 꼭짓점 2개가 바뀌고, 던전에서는 그림 칸 10개를 다시 그려(문맥 타일이 위아래 한 줄씩) 그중 6개가 바뀐다. 충돌 타일과 광맥 덧칠이 같이 없어지는 것을 물리 질의(`intersect_point`)로 확인했고, 테두리·기반 칸은 부서지지 않는다
- 레이어 크기별 한 칸 갱신(`set_cell` + `update_internals()`): 64² 5µs, 128² 13µs, 256² 41µs, 512² 130µs

남은 문제: 그림 쪽 빈 조합 (지상 81개 키 중 흙+재가 섞인 50개, 던전 36개 키 중 15개, 동굴 맵 그림 칸의 5.8%), 앞면 칸을 걸을 수 있는지(설계), (b)는 에디터 terrain 붓으로 칠할 수 없어 손으로 만드는 방에는 데이터 도구가 필요하다.

### 3. 여러 층

판정 **ok**. 레이어를 겹쳐 쓰는 것 자체는 잘 되지만, 맵 전체를 `TileMapLayer`로 들고 있으면 메모리와 다시 그리기 비용이 커서 조각 레이어와 스트리밍을 게임 코드로 짜야 한다.
근거: [notes/tiles.md](notes/tiles.md), [notes/net.md](notes/net.md), [notes/light.md](notes/light.md), [tiles/shots/tiles_b.png](tiles/shots/tiles_b.png), [shots/scene_net.png](shots/scene_net.png)

| 항목 | 수치 |
|---|---|
| tiles: 한 TileSet으로 Floor / Walls / Ore / Collision 4장 | `break_wall()`·`place_wall()`이 넷을 같이 고친다. 순서·반 칸 밀림·칸 수, 광맥은 벽 위에만, 캐도 바닥은 그대로 (테스트 통과) |
| net: 바닥 / 벽 / 광맥 3장 | `PackedByteArray` 하나(칸당 레이어별 1B) + `TileMapLayer` 3장. 뷰 = 데이터 (해시 일치) |
| `TileMapLayer` 메모리 | 칸당 약 290~360B. 512² 한 장 = 약 62~90MB (헤드리스 `MEMORY_STATIC`, 실행 맥락에 따라 다름. GPU 쪽은 안 잼). 기획 레이어 6장(gameplay-design §3.1)을 512² 전체로 만들면 약 0.4~0.5GB. 월드 데이터 자체는 칸당 1~2B |
| 레이어가 클수록 한 칸 갱신이 비싸다 | 64² 5µs → 512² 130µs |
| 전체 다시 그리기 (늦은 참가) | 256²×3장 150~210ms, 1024²×3장 약 2.7초 (메인 스레드 정지, `set_cell` 약 300만 번) |
| 레이어와 빛 한도 | `TileMapLayer` 사분면(기본 16x16칸 = 256px) 하나가 빛 15개까지만 받는다. `rendering_quadrant_size` 4면 30/30 (§4) |

남은 문제: 64x64 같은 조각 레이어 + 플레이어 근처만 그리기 + 여러 프레임에 나눠 채우기. 식생·오염·설치물 레이어는 만들지 않았다. 오염을 투명 위 자동 타일 레이어로 할지는 흙+재 빈 조합 문제와 같이 정한다 (concept-art-brief §5.7 ?, gameplay-design §3.1).

### 4. 빛·어둠·노멀맵·불꽃

판정 **strong**. 전부 Godot 4 기본 노드다 (`CanvasModulate`, `PointLight2D`, `CanvasTexture` 노멀맵, `LightOccluder2D`, unshaded `CanvasItemMaterial`).
근거: [notes/light.md](notes/light.md), [shots/scene_light.png](shots/scene_light.png), [shots/light_dither.png](shots/light_dither.png), [shots/light_hard.png](shots/light_hard.png), [shots/light_banded.png](shots/light_banded.png), [shots/light_smooth.png](shots/light_smooth.png), [shots/light_day.png](shots/light_day.png), [shots/light_edges.png](shots/light_edges.png), [shots/light_dither_1080.png](shots/light_dither_1080.png), [shots/light_hard_1080.png](shots/light_hard_1080.png), [shots/light_dither_1080_native.png](shots/light_dither_1080_native.png), [shots/light_actor_split.png](shots/light_actor_split.png), [shots/light_altar_normals.png](shots/light_altar_normals.png), [shots/light_limit_probe.png](shots/light_limit_probe.png)

| 항목 | 수치 (프레임 시간 말고는 Vulkan과 OpenGL이 같다. 이번 실행에서 다시 확인) |
|---|---|
| 제단 안전 반경 = 게임 규칙 `is_in_safe_zone()` | hard 텍스처 224x224 텍셀 전부 일치 (테스트), 디더 텍셀은 반경 밖에 없음. 화면 쪽 증거는 약하다: 510픽셀 표본이 가로·세로 두 줄이라 경계를 지나는 곳이 4군데뿐이고, 캡처는 불일치가 있어도 종료 0 |
| 저녁 어둠 (`CanvasModulate` 0.40, 0.34, 0.31) | 빛 밖 = 저녁색 그대로, 빛 안 RGB 배율 (1.05, 0.97, 0.90) |
| 테두리 4종 (R = 112px) | 마지막 밝은 픽셀: hard 112, dither 109, banded 112, smooth 109. 밝기 단계: 2 / 2 / 4 / 14 |
| 불꽃 (등잔 81픽셀, unshaded 덧그림) | 원본 색과 채널 차 최대 **0**, 최저 밝기 151 (shaded로 그리면 차 162, 밝기 55) |
| 노멀맵 (생성, `CanvasTexture`) | 북쪽 빛: 북 테두리 0.76 > 앞면 0.354 / 남쪽 빛: 앞면 0.868 > 북 테두리 0.459 / 끄면 둘 다 0.96 |
| 그림자 (`LightOccluder2D`, 필터 없음) | 벽 뒤 땅 0.36 (= 어둠), 옆 같은 거리 0.98 |
| 경계 위 캐릭터 (243픽셀) | 빛 공유: 행 안 밝음↔어둠 바뀜 99번 (얼굴 체커보드) → 캐릭터 전용 hard 빛(light_mask 2): 16번 |
| 캔버스 아이템 하나가 받는 빛 | **15개**까지 (스프라이트, `TileMapLayer` 사분면 16). 사분면 4: 30/30 |
| 프레임 시간, 600프레임 평균 / p99 (이번 실행, Vulkan) | 데모 0.20 / 1.5ms, + 움직이는 횃불 9·오클루더 30: 0.36 / 2.0ms, 그림자 빛 64개: 0.63 / 1.8ms, 빛 64개 그림자 끔: 0.27 / 1.3ms |
| 같은 측정 (이번 실행, OpenGL) | 0.32 / 1.8ms, 0.81 / 4.8ms, 3.22 / 4.7ms (CPU 렌더 3.0ms), 0.46 / 6.2ms |
| 검증 단계 재실행 (Vulkan) | 0.39 / 0.65 / 1.00 / 0.70ms. 빛 64개 그림자 끔이 0.27 → 0.70ms로 2.6배 흔들렸다. 한 번 잰 범위가 아니라 규모로만 본다 |
| 디더 빛 텍스처 만들기 (GDScript, 한 번만) | 반경 40px 2.3ms, 112px 12.5ms, 192px 33.8ms |

남은 문제: 아이템당 빛 15개 한도(설정 항목 없음, 땅 레이어 사분면을 줄여 피함). `PointLight2D.texture`·`CanvasTexture.normal_texture`를 실행 중에 갈아 끼우면 오류 줄이 난다(텍스처 캐시로 우회). 움직이는 빛의 디더는 월드에 고정되지 않는다(`light()` 셰이더 미시험). `TileSet` occlusion layer와 부서지는 벽의 그림자 갱신, PixelLab `create_normal_map`과의 비교는 시험하지 않았다.

### 5. 네트워크 동기화·늦은 접속·대역폭

판정 **strong** (자동 시험은 localhost. 2026-10-21 사람이 창 두 개와 두 기기로 확인). 호스트 권한, RPC 요청·검증, 권한 없는 RPC 자동 거부, `MultiplayerSpawner`·`MultiplayerSynchronizer`, 늦은 참가 스냅샷 + 델타가 전부 Godot 4 내장 기능이다 (애드온 없음, 네트워크 핵심 약 400줄).
근거: [notes/net.md](notes/net.md), [shots/scene_net.png](shots/scene_net.png)

| 항목 | 수치 |
|---|---|
| 구조 | 클라이언트는 "이 칸을 부숴 달라" RPC만 보낸다. 호스트가 검사(맵 안, 손 닿는 거리 56px, 벽 있음, 부술 수 있음)하고 그 틱의 변경을 델타 묶음 하나로 방송 (칸당 6B, 절대값이라 두 번 적용해도 같음) |
| 4인 세션 (이번 실행) | 168 checks, 13.6초. 늦은 참가 2.1초, 모든 인스턴스의 타일·위치 해시 = 호스트, 델타 순번 빠짐 없음 |
| 9인 세션 (이번 실행) | 233 checks, 14.4초. 늦은 참가 2.8초, 해시 일치, 수락 36 / 거부 27 |
| 가짜 델타 (클라이언트가 호스트인 척) | Godot가 거부 (`Mode is "authority"`), 해시 그대로 |
| 위치 동기화 호스트 송신, always 30Hz (이번 실행) | 4인 6.5~6.6KB/s (선로 약 8.7~9.4KB/s), 9인 35.6~35.7KB/s (선로 약 41.6~42.8KB/s ≈ 0.34 Mbps) |
| 다른 설정 (모듈 측정, 9인 이동 중) | 20Hz 25.6~26.7KB/s, ENet range coder 20.4KB/s, zstd 22.8KB/s, on_change 49.6~51.4KB/s (정지 때는 0.2~1.4KB/s) |
| 클라이언트 송신 (입력) | 약 0.3~0.5KB/s |
| 타일 200개를 한 틱에 편집 | 클라이언트당 페이로드 1,200B, 묶음 1개. 호스트 추가 송신 4인 약 4.0KB, 9인 약 11.3KB (range coder면 9인 2.7KB) |
| 늦은 참가 스냅샷 256²×3장 | 196,608B → zstd 32x32 청크 64개 19.1KB (9.7%). 호스트 만들기 2.1~2.2ms, 클라이언트 적용 157~211ms (그중 `TileMapLayer` 152~204ms) |
| 늦은 참가 스냅샷 1024²×3장 (모듈) | 306KB, 클라이언트 다시 그리기 약 2.7초, 수신에 1~3초 |
| 내보낸 exe (모듈) | host·client 두 프로세스로 세션, 해시 일치 |
| 사람 확인 (2026-10-21) | 데스크탑 창 두 개, 그리고 데스크탑 호스트 + 서피스 클라이언트(스냅드래곤, "Windows ARM64" 내보내기)를 Tailscale 직접 연결(핑 약 10ms)로 해 봤다. 이동·벽 부수기·늦은 참가가 모두 양쪽에 맞게 보였다. 서피스 쪽 자기 캐릭터 반응이 조금 늦지만 심각하지 않았다. 지금은 자기 캐릭터도 호스트가 움직여 돌려주므로 왕복 시간 + 30Hz 동기화 간격만큼 늦는다 → 게임 코드에서 자기 캐릭터 예측 |

남은 문제: 자동 시험은 localhost만 했다 (지연·손실·지터 없음, ENet에 흉내 옵션도 없음). 두 기기는 사람이 Tailscale 직접 연결(핑 약 10ms) 하나로만 해 봤다. 클라이언트 예측·보간이 없다 (Godot 내장 Synchronizer가 해 주지 않으므로 직접 짠다). Synchronizer의 always는 정지 중에도 보내고 on_change는 이동 중에 더 비싸서, 게임에서는 정지 때 쉬는 위치 묶음 패킷을 직접 만드는 편이 낫다. 큰 맵은 근처 청크부터 보내는 스냅샷 스트리밍이 필요하다.

### 6. Steam 준비

판정 **ok**. 바꿀 자리와 호환 확인은 끝났지만 실제로 돌린 것은 없다.
근거: [notes/net.md](notes/net.md) "GodotSteam 호환"

| 항목 | 상태 |
|---|---|
| 전송 계층 분리 | 게임 코드는 SceneMultiplayer만 쓰고 `MultiplayerPeer` 만들기만 `net_transport.gd`로 뺐다. `enet_transport.gd`(동작), `steam_transport.gd`(GodotSteam `SteamMultiplayerPeer` 호출), `transports.gd`(이름으로 고름). 전송을 고르는 것은 `--net-transport=steam` 한 줄이지만, 그것만으로 Steam에서 다 되지는 않는다 (아래 "검증에서 찾은 빈틈") |
| GodotSteam이 없을 때 | `steam_transport.gd`가 `ERR_UNAVAILABLE`을 돌려준다 (테스트로 확인) |
| GodotSteam 호환 (웹 확인 2026-10-18) | 4.23 (2026-10-05)에 Godot 4.7.2용 에디터·내보내기 템플릿. GDExtension 4.23.1 (2026-10-07)은 Godot 4.4 이상이면 동작해서 공식 4.7.2 바이너리와 지금 CLI 방식을 그대로 쓸 수 있다 |
| Steam peer 기본값 대비 | `server_relay` 기본 false → `--net-relay=off`로 4인·9인 통과, 대역폭 같음 (이 설계는 클라이언트끼리 통신이 필요 없다) |
| ENet과 다른 점 (소스 확인) | 최대 인원 인자가 없다 (10번째 접속은 호스트가 끊어야 함), `UNRELIABLE_ORDERED`는 reliable로 간다, 가상 포트 0, 채널 수는 프로젝트 설정 |
| 검증에서 찾은 빈틈 | Steam 쪽에는 9인 상한이 없고 호스트도 인원을 세지 않는다 (ENet만 `create_server(port, 8)`로 막음). `--net-relay`는 SceneMultiplayer에만 들어가고 Steam peer의 `server_relay`에는 안 들어간다. `net_main.gd`가 ENet 옵션을 직접 다룬다. 실제 Steam 흐름(로비 만들기 → 콜백 → `host_with_lobby`)은 지금의 동기식 `create_host()`로 나타낼 수 없다. 게임 코드에서는 상한을 호스트에서 세고, 전송별 설정을 전송 쪽으로 옮기고, 접속을 시그널로 짠다 |
| 실제 Steam 릴레이 | 시험 안 함 (GodotSteam 미설치, Steam 미실행. Steam 로그인과 두 기기가 필요해 사람이 해야 한다) |

### 7. 캐릭터 레이어·팔레트

판정 **strong** (레이어). 팔레트 스왑은 엔진 쪽 strong, **지금 스프라이트로는 weak**.
근거: [notes/chars.md](notes/chars.md), [shots/scene_chars.png](shots/scene_chars.png), [shots/chars_layers.png](shots/chars_layers.png), [shots/chars_layers_x3.png](shots/chars_layers_x3.png), [shots/chars_walk_x2.png](shots/chars_walk_x2.png)

| 항목 | 수치·방법 |
|---|---|
| 프레임 | `base_body_v02_walk.png` 32x32 칸, 30px 치비, 발 y = 31. 노드 위치 = 두 발 사이 |
| 레이어 | `Rig` 아래 `Body` + 슬롯 `Back`(곡괭이) · `Waist`(씨앗주머니) · `Float`(후광). 방향별 순서표대로 `move_child` (곡괭이는 북쪽만 몸 앞). `z_index`는 다른 캐릭터·타일 순서까지 바꿔서 쓰지 않았다 |
| 프레임별 오프셋 | v01→v02 이동 (남 +4, 동 +3, 북 +4) + 몸통·머리 기준점 표. 후광은 2~4프레임에서 1px 뜬다 |
| 서쪽 | `Rig.scale.x = -1` (동쪽 반전), 정수 픽셀 유지 |
| GPU 렌더 = CPU 기준 그림 (이번 실행) | 32명 (4방향 × 표식 4종 × 기본·바꾼 색)을 480x270 전체 프레임 6장(777,600픽셀, 대부분 풀 바닥)으로 비교, **다른 픽셀 0** |
| 일부러 깨 보기 | 북쪽 순서·기준점 표·서쪽 반전·팔레트 개수를 하나씩 틀리면 테스트 실패, 셰이더를 끄면 2,988픽셀 다름으로 실패 |
| 팔레트 스왑 | canvas_item 셰이더, 원본 10색 → 목표 10색, 캐릭터마다 ShaderMaterial 하나 (9명이면 문제없는 수) |
| 헤드리스 테스트 | 744 checks, 0.2초 |

남은 문제: AI가 만든 프레임은 인덱스 색이 아니라 상의 베이지가 얼굴·머리에도 쓰여서, 이번에는 프레임 y 17~25줄로 바꿀 범위를 제한했고 옆모습은 일부만 바뀐다. 상의를 꾸미기 장비 레이어로 따로 그리거나 기본 몸을 재질별 고정 램프 색으로 정리해야 한다 (concept-art-brief §5.6 ○ 레이어 구조). 기준점은 재는 방법에 따라 1px씩 달라서 사람이 보고 고정하는 편이 낫다. y 정렬(다른 캐릭터와 겹침), 움직이는 카메라, 64x64 동작 칸(R26), idle은 시험하지 않았다.

### 8. 화면 배율

판정 **strong** (2026-10-21 실제 화면 확인 끝). Godot가 고른 배율(`get_final_transform()`)이 모든 조합에서 정수·정사각이고, 내부 렌더는 원본 PNG 픽셀 그대로다. 창 크기 스크린샷(`scale_<내부>_<창>.png`, `light_*_1080.png`)은 내부 렌더를 CPU에서 최근접으로 키운 것이라 그 자체로는 증거가 아니다. 실제 화면에 나간 그림은 아래 표 마지막 줄에서 따로 확인했다.
근거: [notes/chars.md](notes/chars.md), [shots/scale_480x270_internal.png](shots/scale_480x270_internal.png), [shots/scale_640x360_internal.png](shots/scale_640x360_internal.png), [shots/light_dither_1080.png](shots/light_dither_1080.png) vs [shots/light_dither_1080_native.png](shots/light_dither_1080_native.png)

| 내부 해상도 | 창 | 배율 | 검은 테두리 (한쪽) | 보이는 타일 | 30px 캐릭터 화면 키 | 스크린샷 |
|---|---|---:|---|---|---:|---|
| 480×270 | 1920×1080 | 4 | 0×0 | 30 × 16.9 | 120px | [scale_480x270_1920x1080.png](shots/scale_480x270_1920x1080.png) |
| 480×270 | 2560×1440 | 5 | 80×45 | 30 × 16.9 | 150px | [scale_480x270_2560x1440.png](shots/scale_480x270_2560x1440.png) |
| 480×270 | 3840×2160 | 8 | 0×0 | 30 × 16.9 | 240px | [scale_480x270_3840x2160.png](shots/scale_480x270_3840x2160.png) |
| 640×360 | 1920×1080 | 3 | 0×0 | 40 × 22.5 | 90px | [scale_640x360_1920x1080.png](shots/scale_640x360_1920x1080.png) |
| 640×360 | 2560×1440 | 4 | 0×0 | 40 × 22.5 | 120px | [scale_640x360_2560x1440.png](shots/scale_640x360_2560x1440.png) |
| 640×360 | 3840×2160 | 6 | 0×0 | 40 × 22.5 | 180px | [scale_640x360_3840x2160.png](shots/scale_640x360_3840x2160.png) |

| 항목 | 수치 |
|---|---|
| Godot 실제 배율(`Window.get_final_transform()`) = 계산값 | 6/6 (이번 실행 3.4초), 다른 창 크기 8가지(keep·expand)는 [notes/chars.md](notes/chars.md) 표 |
| 내부 렌더 색 | 두 해상도 모두 149색, 전부 원본 PNG에 있는 색 (흐림·섞인 색 없음) |
| 화면으로 복사할 때 | 4.7.2 소스에서 뷰포트 blit 샘플러 기본값이 NEAREST (Forward+·Mobile). Compatibility(OpenGL)는 확인 안 함 |
| 화면 해상도로 직접 그리면 | 그림자 경계가 아트 픽셀보다 잘게 나온다 (`light_dither_1080_native.png`). 지금 설정(viewport 스트레치 + integer)은 아트 픽셀 단위 |
| 실제 화면 캡처 확인 (2026-10-21, 4K 모니터에 1920×1080 창, 4배) | `"$GODOT" --path $SPIKE res://chars/scale.tscn -- --scale=4 --chars-present-check`. 창 안 2,073,600픽셀 중 다른 픽셀 112개, 전부 창 아래 두 모서리(왼쪽 56, 오른쪽 56, 높이 14px)다. Windows 11이 일반 창의 모서리를 둥글게 깎아 뒤 화면과 섞은 것이고, 게임 픽셀은 4×4 사각형 그대로다. 그래서 검사는 아래 두 모서리 32px 사각형 안의 차이를 따로 세고, 그 밖이 0이면 `CHARS_PRESENT ok`다 (처음 판은 모서리까지 세서 FAIL이었다). 전체 화면에서는 모서리를 깎지 않는다 |

chars 모듈의 권장은 **640×360 내부 해상도 + 정수 배율 + viewport 모드**다 (16:9 흔한 크기 넷을 테두리 없이 채우고, 1080p에서 정확히 3배라 concept-art-brief §7의 3배 판정이 곧 실제 화면, 보이는 땅이 78% 넓음). 대신 1080p에서 캐릭터가 480×270(4배)보다 작게 보인다. 화면 배율은 game-concept §7 미결이라 사람이 정한다. 640×360으로 정하면 `project.godot`의 기본 해상도를 640×360, 창 기본값을 1920×1080으로 바꾼다 (스켈레톤만 고치는 파일).

## 함께 시험하지 않은 것

모듈마다 자기 장면에서 따로 시험했다. 합친 뒤 메뉴·`--scene=`·내보낸 exe에서 네 장면이 모두 열리는 것은 확인했지만, 한 화면에 섞어서는 돌리지 않았다:
- dual grid 타일(반 칸 밀린 그림 레이어) 위의 2D 빛·그림자, 부서지는 벽과 `TileSet` occlusion layer
- 타일 위 레이어 캐릭터의 y 정렬과 앞면 칸 가림
- net의 실제 타일셋 (net은 색 타일만 쓴다) 과 dual grid 다시 그리기 비용

## 남은 문제

엔진 쪽 (Godot 한계, 우회 있음):
- 내장 terrain 오토타일이 꼭짓점 Wang 셋과 맞지 않는다 → dual grid 직접 구현 (약 450줄), 에디터 terrain 붓 없음
- 캔버스 아이템 하나에 빛 15개 한도 (설정 항목 없음) → 땅 레이어 `rendering_quadrant_size`를 4~8로 (그리기 호출 비용은 안 잼)
- 빛·노멀맵 텍스처를 실행 중에 바꾸면 오류 줄 2종 → 텍스처를 캐시에 붙잡아 둔다
- `TileMapLayer` 칸당 약 300B, 큰 레이어일수록 한 칸 갱신이 비싸다 → 조각 레이어
- `MultiplayerSynchronizer`에 보간·예측이 없다 → 직접 짠다

게임 코드로 짤 것: 조각 레이어와 근처만 그리기, 스냅샷 스트리밍, 자기 캐릭터 예측 + 남의 캐릭터 보간, 위치 묶음 패킷, Steam에서 9인 상한, 움직이는 빛의 월드 고정 디더, "발이 빛 안이면 몸 전체 밝게"(필요하면). 검증에서 나온 것: 호스트 쪽 인원 상한, 빈 스폰 번호 다시 쓰기 (지금은 나갔다 들어올 때마다 번호가 늘어 10번째가 호스트 자리에 난다), 테스트 러너가 엔진 오류(`push_error`, 널 인자 등)도 실패로 세게, 그림 판정 캡처가 불일치면 종료 1, GDScript 경고(`untyped_declaration`, `unsafe_*`)를 오류로 켜고 타입 있는 Dictionary나 작은 클래스로 데이터를 넘기기 (스파이크는 선언은 다 타입이 있지만 `unsafe_*`를 켜면 스크립트 40개 중 25개가 걸린다), 큰 파일 나누기 (`net_main.gd` 657줄).

그림 쪽: 흙+재 조합 타일 (지상 50/81 키), 던전 빈 키 15/36 (대부분 세로 한 칸 틈), 캐릭터 인덱스 색 정리 또는 상의 레이어 분리, 기준점 사람이 고정.

정할 것 (? / 미결): 화면 배율 (game-concept §7), 엔진 (game-concept §7·§13), 앞면 칸 통행, 오염을 따로 겹치는 레이어로 할지 (concept-art-brief §5.7 ?), 안전 반경 테두리 기본값 (모듈 제안: dither).

사람이 할 확인: (2026-10-21에 끝남: 데스크탑 화면 배율 §8, 창 두 개 협동과 두 기기 Tailscale §5) 먼 회선이나 지연 흉내 도구, Steam 릴레이 (두 기기·Steam 로그인), GPU 없는 클라우드 컨테이너에서의 스크린샷, PixelLab `create_normal_map` 비교 (유료라 승인 필요).

## 검증 (통합 뒤 다시 확인)

다른 에이전트 둘이 파일을 고치지 않고 다시 돌리고 읽었다.
- 재현: README 명령(임포트·전체 테스트·내보내기·exe), 네트워크 테스트 3번 (3/3 통과, 흔들림 없음), 9인과 1024² 맵, tiles 품질·렌더 벤치, light·chars 캡처. 수치는 위 표와 같은 범위였고, light·chars PNG는 커밋된 것과 바이트까지 같았다. `git archive`로 만든 새 폴더에서도 1,297 checks 통과
- 규칙: `game/`에는 첫 커밋의 README만 있고 이 브랜치가 바꾼 것은 `prototypes/engine-spike/` 안뿐이다. 복사한 그림·JSON 30개는 `assets/concept`의 우리 파일과 바이트까지 같다. LF·.gitignore 정상, Godot 3 API 흔적 없음. Wang 코너는 JSON → `.tres` → PNG로 57/57 일치 (10개는 손으로 점검)
- 고친 표현: §1 러너 오류 감지 범위와 check 수, §1·§4 빛 화면 표본, §2 이음매 비교 잣대와 다시 그리는 칸 수, §3 메모리, §4 프레임 시간 흔들림, §6 Steam 교체, §7 픽셀 수, §8 창 크기 스크린샷, README 예시 모듈 이름, notes 해당 줄. 요구사항별 판정은 바뀌지 않았다
- 코드는 고치지 않았다 (버리는 프로젝트). 찾은 코드 문제는 "남은 문제 → 게임 코드로 짤 것"에 옮겼다

## 종합 판정

**Godot 4.7.2는 이 게임에 맞다 (strong).** 요구사항 8개 중 6개가 strong이고, ok인 둘(여러 층, Steam 준비)도 엔진이 막는 것이 아니라 게임 코드로 짤 일(조각 레이어·스트리밍)과 사람이 두 기기로 해야 하는 확인(Steam 릴레이)이 남은 것이다. 무엇보다 에이전트가 GUI 없이 전부 할 수 있었다: 새 클론 임포트 3초, 다중 프로세스 9인 세션을 포함한 테스트 1,297개 36초, Windows 내보내기 3초, 그림도 스크린샷을 픽셀 단위로 비교해 판정했다. 16px 타일·레이어·부서지는 벽, 2D 빛·노멀맵·불꽃, 호스트 권한 협동과 늦은 참가, 정수 배율이 모두 내장 노드로 됐다. 가장 약한 곳은 내장 terrain 오토타일로, 우리 PixelLab 코너 타일셋과 뜻이 달라 쓸 수 없지만 dual grid 약 450줄로 대신했고 이쪽이 우리 코너 뜻과 같고 더 빠르며(512² 채우기 8~18배) 피어마다 같은 그림을 낸다 (이음매는 그림 쪽 빈 조합에서 남는다). 남은 위험은 실제 회선·Steam 릴레이 미검증, 예측·보간과 큰 맵 스트리밍을 직접 짜야 하는 점, 그리고 그림 쪽 빈 조합·팔레트 인덱스 색이다. 엔진을 정하는 것은 사람이다 (game-concept §7·§13을 `docs/` PR로 갱신). Godot로 정하면 화면 배율(480×270 / 640×360)을 함께 정하고, 위 "함께 시험하지 않은 것"을 수직 슬라이스 첫 단계에서 확인한다.
