# Evensong 엔진 스파이크 (Godot 4.7.2)

엔진을 정하기 전에 Godot 4가 이 게임에 맞는지 짧게 확인하는 **버리는 프로젝트**다.
진짜 게임 폴더 `game/`은 엔진이 결정된 뒤에 만든다. 여기 코드는 `game/`으로 옮기지 않는다 (결정 뒤 다시 쓴다).

확인할 요구사항 (docs/game-concept.md §12-§13, docs/gameplay-design.md §1-§3, docs/concept-art-brief.md §5.6-§5.7):
16px 타일 / 32x32 캐릭터 프레임(30px 치비)·레이어 시그니처 스프라이트·프레임별 오프셋 / 우리 PixelLab 타일셋의 Wang(코너) 오토타일 /
부서지는 벽 / 타일 레이어 여러 장 / 2D 라이트(제단 안전 반경, 저녁 어둠, 스스로 빛나는 불꽃, 노멀맵) /
호스트 권한 온라인 협동 최대 9인 + 타일 변경분 동기화(Steam 릴레이는 나중) / 정수 배율 픽셀 퍼펙트(화면 배율 미정) /
에이전트가 CLI에서 헤드리스로 전부 할 수 있을 것.

## 준비

- Godot 4.7.2 stable 콘솔 빌드: `C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe` (stdout으로 출력한다)
- 내보내기 템플릿: `%APPDATA%\Godot\export_templates\4.7.2.stable\` 에 설치되어 있어야 한다
- 아래 명령은 **저장소 루트에서 Git Bash** 기준이다. `< /dev/null`은 stdin을 기다리지 않게, `timeout`은 멈췄을 때 끊으려고 붙인다

```bash
GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
SPIKE=prototypes/engine-spike
```

PowerShell에서는 `& "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototypes/engine-spike --script res://tests/run_all.gd` 처럼 쓴다.

## 명령

### 1. 임포트

클론 직후, 그리고 에셋(PNG 등)을 추가한 뒤에 한 번. `.godot/` 캐시와 `*.import`, `*.uid`를 만든다 (`*.import`, `*.uid`는 커밋한다).

```bash
timeout 300 "$GODOT" --headless --path $SPIKE --import < /dev/null
```

### 2. 전체 테스트

```bash
timeout 300 "$GODOT" --headless --path $SPIKE --script res://tests/run_all.gd < /dev/null
```

- 출력: 파일마다 `PASS test_x.gd (n checks, ms)` 또는 `FAIL ...` + 실패 메시지 한 줄씩, 끝에 `SPIKE_TESTS done: ...`
- 종료 코드: 모두 통과 0, 하나라도 실패 1 (불러오기 실패·시간 초과·테스트 파일 없음도 1)
- 일부만: `... --script res://tests/run_all.gd -- --only=skeleton,tiles` (`test_<모듈>.gd`의 `<모듈>` 이름)
- 파일당 제한 시간(초, 기본 120): `... -- --timeout=300`

### 3. 내보내기 (Windows x86_64 release, pck 내장)

```bash
timeout 600 "$GODOT" --headless --path $SPIKE --export-release "Windows Desktop" build/evensong_spike.exe < /dev/null
timeout 60 $SPIKE/build/evensong_spike.console.exe --headless -- --smoke < /dev/null
```

- 내보내기 경로는 프로젝트 폴더 기준이다 → `prototypes/engine-spike/build/evensong_spike.exe` (+ 콘솔 래퍼 `evensong_spike.console.exe`)
- 두 번째 줄은 `SPIKE_SMOKE ok godot=... exported=true ...` 한 줄을 찍고 0으로 끝나야 한다. `--headless --quit`만 줘도 바로 끝난다
- `tests/`는 내보내기에서 뺀다 (`exclude_filter`). `build/`는 `.gdignore`가 있어 임포트하지 않고, 커밋하지 않는다

### 4. 장면 하나 실행

```bash
"$GODOT" --path $SPIKE res://light/light.tscn              # 창으로 바로 (light 모듈)
"$GODOT" --path $SPIKE -- --scene=light                    # 메뉴를 거쳐 res://light/light.tscn
"$GODOT" --path $SPIKE -- --scene=light --scale=3          # 창 크기 = 480x270 x 3
timeout 60 "$GODOT" --headless --path $SPIKE res://light/light.tscn --quit-after 120 < /dev/null
```

마지막 줄은 그리지 않고 120프레임 돌린 뒤 끝낸다 (로직·스크립트 오류 확인용). 인자 없이 `"$GODOT" --path $SPIKE`면 메뉴(`main.tscn`)가 뜨고, 숫자 키 1~9로 장면을 연다. 어느 장면에서든 F10이면 메뉴로 돌아온다.

### 5. 스크린샷 모드

```bash
timeout 120 "$GODOT" --path $SPIKE -- --scene=light --screenshot=build/shots/light.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path $SPIKE -- --screenshot=build/shots/menu.png < /dev/null
```

- `--frames`(기본 10) 프레임 뒤 루트 뷰포트를 PNG로 저장하고 0으로 끝난다. 출력 `SPIKE_SCREENSHOT <경로> 480x270 error=0`
- 저장되는 이미지는 **기본 해상도 480x270**이다 (정수 배율로 키우기 전). 상대 경로는 프로젝트 폴더 기준
- 렌더러가 필요하므로 `--headless`를 빼고 실행한다 (`--headless`와 같이 주면 오류 메시지와 함께 종료 코드 2).
  이 데스크탑에서는 SSH 세션에서도 된다 (Vulkan Forward+, RTX 5090, 2026-10-18 확인). GPU 없는 클라우드 컨테이너에서는 시험하지 않았다

### SpikeCli 인자 (오토로드 `res://skeleton/spike_cli.gd`)

Godot 인자 뒤 `--` 다음에 쓴다.

| 인자 | 뜻 |
|---|---|
| `--smoke` | `SPIKE_SMOKE ok ...` 한 줄(버전, 디스플레이, 기본 해상도, 스트레치, 내보낸 빌드인지, 모듈 수)을 찍고 종료 코드 0 |
| `--scene=<모듈>` 또는 `--scene=res://...tscn` | 시작할 때 그 장면으로 바꾼다. 없으면 종료 코드 2 |
| `--screenshot=<파일.png>` | 위 스크린샷 모드 |
| `--frames=<n>` | 스크린샷 전에 기다릴 프레임 수 (기본 10) |
| `--scale=<n>` | 창 크기를 기본 해상도의 n배로 (헤드리스에서는 무시) |

에디터는 `"$GODOT" --path $SPIKE -e`로 연다. GUI가 필요하므로 사람이 데스크탑에서 연다.

## 프로젝트 설정 (스켈레톤이 정한 것)

- 이름 "Evensong engine spike", 메인 장면 `res://main.tscn`
- 기본 해상도 480x270, 스트레치 모드 `viewport`, 배율 모드 `integer` (창 기본 1440x810 = 3배. 화면 배율은 아직 미정)
- 기본 텍스처 필터 Nearest, 2D 픽셀 스냅(트랜스폼·정점) 켬
- 렌더러 Forward+ (기본값)
- 오토로드 `SpikeCli`

`tests/test_skeleton.gd`가 이 설정이 실제 루트 창에 적용됐는지까지 확인한다.

## 폴더

```
prototypes/engine-spike/        Godot 프로젝트 루트 (= res://)
  project.godot                 스켈레톤만 고친다
  export_presets.cfg            "Windows Desktop" (x86_64, release, pck 내장, 콘솔 래퍼, tests/ 제외)
  main.tscn                     메뉴: 모듈 장면 목록
  skeleton/                     메뉴 스크립트, SpikeCli 오토로드, 모듈 탐색 (modules.gd)
  tests/                        spike_test.gd (기반 클래스), run_all.gd (러너), test_<모듈>.gd
  notes/<모듈>.md               모듈별 결과 (한국어)
  art/<모듈>/                   모듈이 쓰는 우리 PNG 사본
  <모듈>/<모듈>.tscn            모듈 진입 장면 (메뉴와 --scene=<모듈>이 자동으로 찾는다)
  build/                        내보내기·스크린샷 결과 (커밋하지 않는다)
```

## 모듈 규칙

모듈 하나 = 요구사항 하나를 시험하는 폴더 하나 (이 스파이크: tiles, light, net, chars).

1. **코드**는 `res://<모듈>/` 아래에 둔다. 진입 장면은 `res://<모듈>/<모듈>.tscn`. 예약된 폴더 이름(`addons`, `art`, `build`, `notes`, `skeleton`, `tests`)은 모듈 이름으로 쓰지 않는다
2. **테스트**는 `res://tests/test_<모듈>.gd` 하나. 기반 클래스를 상속하고 `run()`을 덮어쓴다
   ```gdscript
   extends "res://tests/spike_test.gd"

   func run() -> Array[String]:
       check_eq(1 + 1, 2, "덧셈")
       var node: Node2D = add_node(Node2D.new()) as Node2D   # 루트에 붙이고, 끝나면 러너가 지운다
       await await_frames(2)                                 # await 해도 된다
       check(node.is_inside_tree(), "트리 안")
       return failures                                       # 빈 배열 = 통과
   ```
   - 헬퍼: `check`, `check_eq`, `check_ne`, `check_near`, `check_between`, `check_not_null`, `check_has`, `fail`, `add_node`, `await_frames`, `await_physics_frames`. `tree`는 SceneTree
   - `check_eq`는 타입까지 비교한다 (int/float는 수로, String/StringName은 글자로 같으면 같다)
   - 테스트 중에 난 GDScript 런타임 오류(SCRIPT ERROR)도 실패로 센다. 파일당 기본 120초 제한
   - 헤드리스(더미 렌더러)에서 돈다. 그림이 필요한 확인은 스크린샷 모드로 하고 결과를 notes에 적는다
3. **결과**는 `res://notes/<모듈>.md`에 한국어로: 무엇을 시험했나, 수치, 실패한 것, 이 게임에 대한 판정 **strong / ok / weak**
4. **에셋**은 저장소의 우리 PNG(`C:/dev/evensong/assets/concept/...`)에서 필요한 것만 `res://art/<모듈>/`로 복사한다. 남의 이미지(itch.io 팩 등)는 넣지 않는다.
   `prototypes/` 아래 PNG는 LFS 규칙(`assets/concept/**`) 밖이라 일반 git으로 들어가므로 작게(필요한 부분만 잘라서) 쓴다
5. **고치지 않는 것**: `project.godot`, `tests/run_all.gd`, `tests/spike_test.gd`, 다른 모듈의 폴더. 프로젝트 설정이 필요하면
   모듈 코드에서 실행 중에 바꾸거나(`get_tree().root`의 속성, `ProjectSettings.set_setting` 등) notes 파일에 요청을 적는다
6. **코드 규칙**: Godot 4 API만 (`TileMapLayer`(TileMap 아님), `@export`/`@onready`, 시그널은 Callable로), 정적 타입 GDScript, C# 쓰지 않음.
   줄바꿈은 LF (저장소 `.gitattributes`)
