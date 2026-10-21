# Evensong 게임 프로젝트 (Godot 4.7.2)

수직 슬라이스를 만드는 진짜 게임 폴더다 (`prototypes/engine-spike/`는 버리는 시험이고, 여기 코드는 새로 짰다).
지금은 **M1 "첫 단계: 이동 · 타일 · 제단 빛 · 2인 접속"**의 세 단계 G1(뼈대 + 월드), G2(캐릭터 + 빛), G3(2인 네트워크)가 모두 들어 있다. 단계 상태는 [맨 아래](#m1-범위와-단계-상태).

기준 문서: `docs/game-concept.md` §7 §11 §12 §13, `docs/gameplay-design.md` §1 §3.1, `docs/concept-art-brief.md` §5.6 §5.7.
문서의 ●는 그대로 따르고, ○·?는 정하지 않고 [임시값](#임시값-사람-확인-필요)으로 둔다.

## 준비

- Godot 4.7.2 stable 콘솔 빌드: `C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe` (AGENTS.md "엔진")
- 내보내기 템플릿: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
- 아래 명령은 **저장소 루트에서 Git Bash** 기준이다. `< /dev/null`은 stdin을 기다리지 않게, `timeout`은 멈췄을 때 끊으려고 붙인다

```bash
GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
```

PowerShell에서는 `& "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/run_all.gd` 처럼 쓴다.

## 명령

### 임포트

클론 직후, `.godot/`을 지운 뒤, PNG나 `class_name` 스크립트를 추가한 뒤에 한 번. `*.import`, `*.uid`가 생기면 커밋한다.

```bash
timeout 300 "$GODOT" --headless --path game --import < /dev/null
```

- 종료 코드는 GDScript 오류가 있어도 0이다. 스크립트가 컴파일되는지는 테스트(`test_core.gd`가 모든 `.gd`를 불러 봄)로 본다
- 에디터 언어가 한국어라 진행 줄이 한국어(색 코드 포함)로 나온다

### 전체 테스트

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd < /dev/null
```

- 출력: 파일마다 `PASS test_x.gd (n checks, ms)` 또는 `FAIL ...`과 실패 한 줄씩(`  - `), 측정값(`  * `), 경고(`  ! `). 끝에 `EVENSONG_TESTS done: ...`
- 종료 코드: 모두 통과 0, 하나라도 실패 1 (불러오기 실패·시간 초과·테스트 파일 없음·시작 중 오류도 1)
- `SCRIPT ERROR: Parse Error: ... (Warning treated as error.)` 다섯 줄은 정상이다. `test_core.gd`가 "경고를 오류로" 설정이 실제로 컴파일을 막는지 일부러 확인하는 줄이고, 테스트가 `allow_error()`로 미리 알린 것이다

### 테스트 하나만

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=world < /dev/null      # test_world.gd
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=core,world < /dev/null
```

- 파일당 제한 시간(초, 기본 120): `-- --timeout=300`
- 러너 자체 시험: `-- --dir=res://tests/fixtures --prefix=case_ --timeout=2` (2개 PASS, 8개 FAIL, 종료 1이 정상. `test_core.gd`가 자식 프로세스로 이것을 돌려 확인한다)

### 네트워크 테스트

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net < /dev/null           # 한 프로세스 안 (0.5초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session < /dev/null   # 실제 세션 (약 30초)
timeout 400 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-full --timeout=300 < /dev/null   # + 10프로세스 상한 시험
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-exe=build/evensong.console.exe < /dev/null   # 자식을 내보낸 exe로
```

- `test_net.gd`: 전송 형식(왕복, 잘린 패킷 전부, 무작위 바이트 2,000개), 인원 상한(진짜 9명: 10번째 거부, 빈 자리 다시 쓰기), 호스트 입력 검사(순서·중복·속도 제한·고르게 적용), 호스트의 묶음/키프레임/조용함 판단, 클라이언트 예측을 지연·손실 있는 가짜 연결로 호스트와 맞춰 보기(지연 0·5·9틱, 손실 0·25%), 보간, 편집 기록(규칙, 시드 + 기록 = 호스트 월드), 봇 스크립트, CLI, RPC 표(누가 부를 수 있는지·채널·신뢰성), 전송(ENet 호스트+참가를 한 프로세스에서, Steam은 신호로 unavailable)
- `test_net_session.gd`: 이 프로젝트를 헤드리스 프로세스 여러 개(`main.tscn` + `--host`/`--join` + `--bot`)로 띄워 localhost ENet으로 실제 세션을 돌린다. 세션마다 모든 인스턴스가 결과 JSON을 쓰고 호스트와 비교한다 (아래 "네트워크 (G3)"의 "테스트가 확인하는 것")
  - `pair`: 호스트 + 클라이언트 1이 같이 걷고 멈춤 → 호스트가 월드 편집 → 늦은 참가자. 옆에서 아무도 없는 포트에 참가 → 실패해야 함
  - `four`: 호스트 + 클라이언트 3 (상한을 `--max-players=4`로 낮춤) → 하나가 나감 → 늦은 참가자가 그 자리를 받음 → 다섯 번째는 "full"로 거부
  - `lag`: 클라이언트 쪽에서 왕복 120ms 지연 + 15% 손실을 흉내 (`--net-lag`, `--net-loss`). 옆에서 `drop`: 호스트가 사라졌을 때 사람처럼 띄운 클라이언트(`--net-out` 없음)가 혼자 계속하는지
  - `--net-full`(선택): 진짜 상한 9명 = 호스트 + 클라이언트 8, 열 번째 거부. 프로세스 10개라 기본에서는 뺐다
- 자식 프로세스 로그(`--log-file`)에 `ERROR:` 줄이 하나라도 있으면 실패. 끝까지 남은 프로세스는 죽이고 실패. 통과하면 실행 폴더(`%APPDATA%/Godot/app_userdata/Evensong/net_test/run_*`)를 지우고, 실패하거나 `--net-keep`이면 남긴다 (로그·결과 JSON·표시 파일)
- 포트는 24621~24640 중 빈 것을 쓴다

### 타일셋 다시 만들기

`art/tiles/`의 PNG·JSON이나 `world/tileset_builder.gd`를 바꿨을 때만. 같은 입력이면 같은 파일이 나온다(두 번 만들어 md5 같음을 확인했다).

```bash
timeout 120 "$GODOT" --headless --path game --script res://tools/build_tileset.gd < /dev/null
```

- 출력 `EVENSONG_TILESET res://world/tilesets/surface.tres error=0 sources=11 tiles=40 exact_keys=31 md5=...`
- 결과 `world/tilesets/surface.tres`를 커밋한다. 커밋된 파일이 새로 만든 것과 다르면 `test_world.gd`가 실패한다 (`ext_resource` id는 저장 위치에 따라 달라서 경로로 바꿔 비교한다)

### 캐릭터 기준점 표 다시 만들기

`art/chars/base_body_v02_*.png`나 `actors/rig_measure.gd`(재는 규칙)를 바꿨을 때만. 같은 시트면 같은 파일이 나온다.

```bash
timeout 120 "$GODOT" --headless --path game --script res://tools/build_rig_anchors.gd < /dev/null
```

- 방향마다 `EVENSONG_ANCHORS walk south torso=[...] head=[...]` 한 줄, 끝에 `EVENSONG_ANCHORS saved res://actors/rig_anchors.gd error=0 md5=...`
- 결과 `actors/rig_anchors.gd`(생성 파일, 손으로 고치지 않음)를 커밋한다. `test_actors.gd`가 시트에서 다시 재서 커밋된 표·파일 내용과 다르면 실패한다

### 내보내기 (Windows release, pck 내장, 콘솔 래퍼)

```bash
mkdir -p game/build/arm64
timeout 600 "$GODOT" --headless --path game --export-release "Windows Desktop" build/evensong.exe < /dev/null
timeout 600 "$GODOT" --headless --path game --export-release "Windows ARM64" build/arm64/evensong.exe < /dev/null
timeout 60 game/build/evensong.console.exe --headless -- --smoke < /dev/null
```

- 경로는 `game/` 기준이다 → `game/build/evensong.exe`(+ `evensong.console.exe`), `game/build/arm64/evensong.exe`
- ARM64는 `build/arm64` 폴더가 없으면 "주어진 내보내기 경로는 존재하지 않습니다"로 실패한다 (그래서 `mkdir`). 이 데스크탑(x86_64)에서는 실행해 볼 수 없다
- `tests/`, `tools/`는 내보내기에서 뺀다. `build/`는 `.gdignore`가 있어 임포트하지 않고 커밋하지 않는다
- 마지막 줄은 `EVENSONG_SMOKE ok exported=true ... checks=83`를 찍고 0으로 끝나야 한다. 아래 "스모크" 참조

### 실행

```bash
"$GODOT" --path game                                   # main.tscn: 월드 + 제단 + 내 캐릭터 + 다른 네 클래스
"$GODOT" --path game -- --class=cleric --no-evening    # 성직자로, 저녁 어둠 끈 채 시작
"$GODOT" --path game res://scenes/world.tscn -- --seed=7 --overlay   # 맵 보기 (자유 카메라, 캐릭터 없음)
game/build/evensong.exe -- --class=miner               # 내보낸 빌드
timeout 60 "$GODOT" --headless --path game --quit-after 120 < /dev/null   # 그리지 않고 120프레임 (오류 확인용)
```

- `main.tscn`(실행 장면): WASD 또는 방향키로 8방향 걷기, 카메라는 내 캐릭터 가운데(맵 밖은 안 보이게 가장자리에서 멈춤). 제단 둘레에 나머지 네 클래스가 제단을 보고 서 있다(움직이지 않는 더미, 표식 다섯 가지가 한 화면에 보이게)
- F4로 저녁 어둠 + 제단 빛 켜고 끄기, F3으로 디버그 선(맵 테두리, 청크 경계, 제단 자리, 임시 안전 반경) 켜고 끄기
- `world.tscn`: WASD 또는 방향키로 자유 카메라 이동 (제단·빛은 있고 캐릭터는 없다)
- 창 기본 1920×1080(4배). `-- --scale=3`이면 1440×810
- `--quit-after` 같은 Godot 인자는 `--` **앞에** 쓴다

### 둘이 하기 (G3)

창 두 개 (이 데스크탑 한 대):

```bash
"$GODOT" --path game -- --host --scale=2                                  # 창 1: 호스트 (팔라딘), 포트 24600
"$GODOT" --path game -- --join=127.0.0.1 --class=cleric --scale=2         # 창 2: 참가 (성직자)
```

- 두 창 모두 WASD/방향키로 걷는다(포커스가 있는 창만 키를 받는다). 창 제목에 `Evensong (host, paladin)` / `(client, cleric)`
- 클라이언트에서 지연을 느껴 보려면 창 2에 `--net-lag=120 --net-loss=5` (왕복 120ms, 손실 5% 흉내). 자기 캐릭터는 바로 움직이고(예측), 호스트 캐릭터는 100ms 뒤에서 부드럽게 따라온다(보간)
- 늦은 참가 보기: 창 1을 `-- --host --bot="wait:180;edit:62,50,soil"`로 띄우면(봇이 키 대신 움직인다) 3초 뒤 제단 아래 풀 한 칸이 흙이 된다. 그 뒤에 창 2를 띄우면 흙이 된 칸이 보인다
- 셋 이상: 창 3, 4 ... 를 같은 `--join`으로. 9명까지, 열 번째는 "full"로 거부된다 (콘솔에 `EVENSONG_NET client ended reason="refused: full" code=3`)
- 호스트 창을 닫으면 클라이언트는 다른 사람을 지우고 혼자 계속 걷는다 (콘솔에 `lost the host`, `offline playing on alone`)

두 기기 (데스크탑 호스트 + 서피스 스냅드래곤, Tailscale. 스파이크에서 사람이 한 구성):

```bash
# 데스크탑: 내보내기 (아래 "내보내기") 후
game/build/evensong.console.exe -- --host
# 서피스: game/build/arm64/evensong.exe 와 evensong.console.exe 를 옮겨서 (저장소 README "기기 간 파일 옮기기")
evensong.console.exe -- --join=<데스크탑의 Tailscale 이름 또는 100.x 주소> --class=cleric
```

- 포트는 UDP 24600 (`--host=<port>`, `--join=<주소>:<port>`로 바꾼다). 호스트는 모든 인터페이스에서 듣는다. 처음 호스트를 열 때 Windows 방화벽 창이 뜨면 허용한다 (스파이크 때와 같은 일)
- `evensong.console.exe`로 띄우면 콘솔에 `EVENSONG_NET ...` 줄이 나온다 (접속, 거부 이유, 끊김). `evensong.exe`는 콘솔이 없다
- 접속이 10초 안에 받아들여지지 않으면 `failed: not admitted within 10 s`, 종료 코드 4로 끝난다 (주소·포트·방화벽 확인)
- 스파이크(2026-10-21)에서 사람이 느낀 "서피스 쪽 자기 캐릭터 반응이 조금 늦음"은 이제 예측으로 푼다. 이번에는 사람이 두 기기로 다시 해 보지 않았다 (아래 "G3에서 확인하지 않은 것")

### 스크린샷

```bash
timeout 120 "$GODOT" --path game -- --screenshot=shots/main_evening.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --no-evening --screenshot=shots/main_evening_off.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game res://scenes/world.tscn -- --screenshot=shots/world.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game res://scenes/world.tscn -- --overlay --screenshot=shots/world_overlay.png --frames=30 < /dev/null
```

- `--frames`(기본 10) 프레임 뒤 루트 뷰포트를 PNG로 저장하고 끝난다. 출력 `EVENSONG_SCREENSHOT shots/world.png 480x270 window=960x540 error=0`
- 렌더러가 필요해서 `--headless` 없이 돌린다 (`--headless`와 같이 주면 종료 코드 2)
- 화면비가 expand라 창이 16:9가 아니면 뷰포트가 넓어진다 (처음 찍었을 때 1024×768 화면에 맞춰 줄어든 창이라 480×349가 나왔다). 그래서 `--scale` 없이 찍으면 화면에 들어가는 가장 큰 정수 배(1~4) 창으로 맞춰 늘 480×270으로 찍는다
- 상대 경로는 `game/` 기준. 내보낸 exe에서는 exe 폴더 기준이다
- `shots/`는 `.gdignore`로 임포트하지 않는다. 지금 들어 있는 그림 (모두 시드 1, 480×270):
  - `shots/main_evening.png`: 실행 장면. 가운데가 내 캐릭터(기본 팔라딘, 남쪽을 봄), 제단 둘레에 광부·아처·성직자·약초사 더미, 저녁 어둠과 제단 빛(디더 테두리)
  - `shots/main_evening_off.png`: 같은 장면, 저녁 어둠·제단 빛 끔 (그림 원래 색)
  - `shots/world.png`: 맵 보기 장면, 제단 가운데, 저녁 어둠 켬. `shots/world_overlay.png`: 같은 화면 + 디버그 선 (노란 원 = 임시 안전 반경이 빛 테두리와 겹친다)
  - `shots/net_host.png`, `shots/net_client.png` (G3): 세션 하나의 두 창. 호스트(팔라딘)와 클라이언트(성직자)가 각자 자기 캐릭터 가운데 카메라로 같은 장면을 본다. 찍은 명령 (호스트는 찍은 뒤에도 `--keep-running`으로 남아 있어야 클라이언트 화면에 나온다):

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24639 --scale=2 --bot="move:1,1,40;wait:3000" --screenshot=shots/net_host.png --frames=420 --keep-running --net-timeout=14 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24639 --class=cleric --scale=2 --bot="move:-1,0,30;wait:3000" --screenshot=shots/net_client.png --frames=360 < /dev/null
```
- 더미의 idle 프레임은 찍는 순간에 따라 달라서 같은 명령도 픽셀까지 같지는 않다

### 그림 검사 (창, 렌더러 필요)

헤드리스 테스트는 더미 렌더러라 화면을 못 본다. 빛·불꽃·캐릭터 레이어·y 정렬이 **실제로 그려진 픽셀**을 보는 검사는 따로 창을 띄워 돌린다 (창이 3초쯤 떴다 닫힌다).

```bash
timeout 180 "$GODOT" --path game --script res://tools/check_render.gd < /dev/null
```

- 부분마다 `EVENSONG_RENDER <부분> ok|FAIL ...`, 끝에 `EVENSONG_RENDER done ok failed_parts=0`. 종료 코드 0 / 하나라도 틀리면 1 (차이 그림을 `game/build/render_check/`에 남김) / `--headless`면 2
- `-- --save`를 붙이면 통과해도 찍은 그림(바닥 저녁 켬·끔, 리그 10장, y 정렬)을 모두 남긴다. 사람이 표식 위치를 눈으로 볼 때 쓴다 (`rig_<walk|idle>_<프레임>_got.png`: 칸 = 클래스, 줄 = 남·동·북·서)
- `ground`: 제단 둘레 화면 480×270 픽셀 전부를 저녁 켬·끔으로 두 번 찍어 색 비율로 밝음/어둠을 가르고, 바닥 빛 텍셀(= 규칙, `test_light.gd`가 텍셀마다 확인)과 비교. 테두리 띠 ±8px 고리(약 2만 픽셀)는 따로 센다. 반경 밖에 밝은 픽셀 0
- `flames`: 불꽃 81픽셀이 저녁에도 원본 색 그대로 (채널 차 0)
- `actor`: 반경선이 몸을 지나가게 세운 캐릭터의 픽셀마다 밝음 = `is_in_safe_zone(픽셀 중심)` (캐릭터는 디더가 아니라 hard 빛)
- `rig`: 5클래스 × 4방향 × (걷기 6 + idle 4) 프레임을 저녁 끈 화면에 세워, 배경 + 시트에서 CPU로 합친 그림과 픽셀까지 비교 (그리기 순서, v01→v02 이동 + 기준점, 서쪽 반전)
- `ysort`: 겹친 두 캐릭터(나중에 추가한 쪽이 뒤), 제단 뒤·앞의 캐릭터가 발 y 순서대로 그려지는지. 트리 순서로 그렸다면 틀렸을 픽셀(지금 516개)이 0보다 커야(= 검사가 실제로 겹침을 본다) 통과
- 일부러 깨 본 것 (G2, 커밋하지 않음): 서쪽 반전 끄기, 한 프레임의 표식 1px 밀기, 캐릭터 빛을 디더로, 캐릭터를 월드 빛 레이어로, 불꽃 shaded, 빛 `texture_scale` 1.02, 빛 위치 1px, y 정렬 끄기. 8개 모두 해당 부분이 FAIL·종료 1

### 명령줄 인자 (`--` 뒤, `core/cli_options.gd`)

| 인자 | 뜻 | 지금 |
|---|---|---|
| `--smoke` | 스모크 검사 후 한 줄 출력, 통과 0 / 실패 1 | 동작 |
| `--seed=<n>` | 월드 시드 (기본 1) | 동작 |
| `--screenshot=<파일.png>` `--frames=<n>` | 위 스크린샷 | 동작 |
| `--scale=<n>` | 창 = 480×270 × n (헤드리스에서는 무시) | 동작 |
| `--overlay` | 디버그 선을 켠 채 시작 | 동작 |
| `--no-evening` | 저녁 어둠과 제단 빛을 끈 채 시작 (F4로 다시 켬) | 동작 |
| `--keep-running` | `--screenshot`을 찍은 뒤 끝내지 않고 계속 (세션 창 두 개를 찍을 때 먼저 찍은 쪽이 나가지 않게) | 동작 (G3) |
| `--class=<paladin\|miner\|archer\|cleric\|herbalist>` | 내 클래스 (기본 paladin). 혼자일 때 나머지 넷은 더미 | 동작 |
| `--host[=<port>]`, `--join=<주소>[:<port>]` | 호스트 / 참가 (기본 포트 24600, IPv6는 `[::1]:24600`). 세션에서는 더미가 없다 | 동작 (G3) |
| `--transport=<enet\|steam>` | 전송 계층 (기본 enet). steam은 M1에서 자리만 있어 "unavailable"로 실패한다 | 동작 |
| `--bot=<스크립트>` | 내 캐릭터를 키 대신 스크립트로: `wait:<틱>`, `move:<dx>,<dy>,<틱>`, `edit:<x>,<y>,<grass\|soil>`(호스트만), `mark:<이름>`, `leave`(클라이언트), `;`로 잇는다 (`net/net_bot.gd`) | 동작 |
| `--max-players=<1..9>` | 호스트: 인원 상한을 낮춘다 (테스트용. 9보다 높일 수 없다) | 동작 |
| `--net-out=<폴더>`, `--net-name=<이름>` | 테스트 인스턴스: 결과 JSON·표시 파일을 쓰고 세션이 끝나면 종료 | 동작 |
| `--net-start=<n>`, `--net-expect=<n>`, `--net-expect-refused=<n>` | 호스트: 클라이언트 n명이 오면 봇 시작 / n명이 봇을 마치거나 나가고 n번 거부했으면 세션 끝 | 동작 (테스트) |
| `--net-timeout=<초>` | 그 시간이 지나면 종료 코드 6 (테스트가 멈춰 있지 않게) | 동작 |
| `--net-lag=<ms>`, `--net-loss=<%>` | 클라이언트: 왕복 지연·손실 흉내 (unreliable 입력·상태만) | 동작 |

아는 인자의 값이 틀리면 `EVENSONG_CLI error: ...`를 찍고 종료 코드 2. 모르는 인자는 무시한다 (테스트 러너의 `--only=` 등이 같은 명령줄로 들어오기 때문).
세션 종료 코드: 0 끝남·나감, 3 거부됨, 4 접속 실패·호스트 잃음(`--net-out`일 때), 5 월드 해시가 호스트와 다름, 6 `--net-timeout`.

### 스모크 (`--smoke`, `core/smoke.gd`)

고정 문자열이 아니라 실제로 확인한다. 하나라도 틀리면 `EVENSONG_SMOKE FAIL <n> failure(s) ...`과 종료 코드 1.
엔진 4.7.2, 렌더러 설정 forward_plus, 루트 창에 실제로 적용된 480×270·viewport·integer·expand·Nearest·픽셀 스냅, 기본 창 1920×1080, 이동 키 배치,
커밋된 타일셋(소스 11, 타일 40, 그림 있는 코너 키 31, 키마다 그림 유무가 규칙과 같은지), 기본 시드 월드(크기, 제단 자리, 흙·재 있음, 흙+재 칸 0)를
실제로 그려서 그림 칸 12,513개 전부의 코너가 데이터와 같은지(대체 타일 0, 빈 칸 0),
캐릭터 시트 크기와 클래스 다섯의 표식 레이어(리그를 만들어 표식이 보이는지), 기준점 표의 모양, `main.tscn`이 불러지는지,
기본 월드의 안전 반경 hard 빛 텍스처 226×226 텍셀 전부 = `is_in_safe_zone()`, 불꽃 마스크 81픽셀,
네트워크(G3): 물리 틱 60, ENet 호스트가 루프백 빈 포트에서 열리고 닫힘(방화벽 창이 뜨지 않게 127.0.0.1만), Steam 가용성 = GodotSteam 유무, 상태 묶음 왕복, 9명 뒤 열 번째 거부, `main.tscn`에 `Net` 노드.
내보낸 exe에서 돌면 pck 안의 타일셋·그림까지 확인하는 셈이다.
`test_core.gd`는 같은 창 검사가 설정이 다른 창에서는 실패하는 것도 확인한다.

## 폴더

```
game/                           Godot 프로젝트 루트 (= res://)
  project.godot                 이름 "Evensong", 메인 장면 res://scenes/main.tscn, 오토로드 Cli, 설정은 아래 "규칙"
  export_presets.cfg            "Windows Desktop" (x86_64) + "Windows ARM64", release, pck 내장, 콘솔 래퍼, tests/·tools/ 제외
  core/                         cli.gd (오토로드 Cli), cli_options.gd (인자), config.gd (상수: ● / 임시값 / 구현 선택), smoke.gd,
                                main.gd (main.tscn 루트: 내 플레이어 + 더미 + 카메라)
  world/                        terrain.gd (지형·코너 키), world_data.gd (레이어 6장), tileset_builder.gd, wang_table.gd,
                                surface_gen.gd (생성기), ground_view.gd (청크 dual grid), game_world.gd (world.tscn 루트),
                                altar.gd (제단 그림 + 불꽃), debug_overlay.gd, tilesets/surface.tres (만든 타일셋, 커밋)
  actors/                       character.gd (레이어 캐릭터), rig_data.gd (리그 표), rig_anchors.gd (생성된 기준점 표),
                                rig_measure.gd (기준점 재기), movement.gd (이동 규칙), player.gd, player_camera.gd,
                                free_camera.gd (world.tscn 맵 보기용)
  light/                        safe_zone.gd (안전 반경 규칙), light_gen.gd (빛 텍스처·불꽃 마스크), altar_light.gd, lighting.gd
  net/                          session.gd (세션 노드 Net: 접속·RPC·틱), transport.gd (전송 인터페이스), enet_transport.gd,
                                steam_transport.gd (자리만), transports.gd (이름 → 전송), protocol.gd (전송 형식),
                                roster.gd (인원 상한·스폰 자리), input_gate.gd (호스트 입력 검사), state_broadcast.gd
                                (묶음/키프레임/조용함), prediction.gd (클라이언트 예측·보정), interpolation.gd (남의 캐릭터
                                보간 + 호스트 시계), edit_log.gd (월드 편집 기록), net_member.gd (세션 안 플레이어 하나),
                                net_bot.gd (--bot), link_sim.gd (지연·손실 흉내), net_stats.gd (트래픽), session_report.gd
                                (테스트 결과 JSON·표시 파일)
  scenes/                       main.tscn (실행 장면: 월드 + 카메라 + Net), world.tscn (월드 + 제단 + 빛 + 자유 카메라 + 디버그 선)
  art/tiles/, art/chars/, art/env/   우리 PNG·JSON 사본 (아래 "그림 출처")
  tests/                        run_all.gd (러너), base_test.gd (기반 클래스), test_core.gd, test_world.gd, test_actors.gd,
                                test_light.gd, test_net.gd, test_net_session.gd (다중 프로세스), fixtures/ (러너 자체 시험)
  tools/                        build_tileset.gd (타일셋 빌더), build_rig_anchors.gd (기준점 표), check_render.gd (창 그림 검사)
  shots/                        스크린샷 (.gdignore)
  build/                        내보내기 결과 (커밋 안 함, .gdignore만 커밋)
```

## 월드 데이터

- `WorldData`는 칸마다 1바이트씩 **레이어 6장**(● gameplay-design §3.1: 바닥 / 벽 / 광맥 / 식생 / 오염 / 설치물)을 `PackedByteArray`로 들고 있다. M1은 바닥(풀 0 / 일군 흙 1 / 재 2), 오염(구역 번호 1.., 0 = 깨끗), 설치물(제단 = 1)만 쓰고, 벽·광맥·식생은 0으로 둔다
- 바닥 레이어가 곧 **꼭짓점 격자**(dual grid)다. 월드 칸 (x, y)의 바닥 값 = 그 칸 가운데 꼭짓점의 지형. 그림 칸은 반 칸 밀려 있어서 그림 칸 (dx, dy)의 NW·NE·SW·SE 코너가 꼭짓점 (dx, dy), (dx+1, dy), (dx, dy+1), (dx+1, dy+1)이다. W×H 월드는 그림 칸 (W+1)×(H+1)개(-1..W-1)이고, 맵 밖 꼭짓점은 풀로 읽는다. 괭이질 한 칸 = 그 칸 가운데 16×16 흙 덩어리 (스파이크 RESULTS §2의 (b))
- 코너 키 = NW + 3·NE + 9·SW + 27·SE (0..80). 우리 그림은 풀↔흙, 풀↔재 두 벌뿐이라 키 81개 중 31개만 그림이 있고, 흙과 재가 한 칸에 섞이는 50개는 없다. 그래서 **흙과 재는 같은 그림 칸의 코너가 되면 안 된다**(꼭짓점 8방향 이웃 금지). `WorldData.set_terrain()`이 거부하고, 생성기는 거리로 떼어 둔다. 그래도 생기면(규칙을 거치지 않고 쓴 데이터) 가장 가까운 키의 타일로 그리고 `GroundView.verify()`가 "fallbacks"로 센다
- 같은 코너의 타일이 여럿이면(풀 5, 흙 3, 재 4) 칸 위치 해시로 고른다. 같은 데이터 → 같은 그림
- `GroundView`는 그림 칸 32×32개마다 `TileMapLayer` 하나(청크)를 둔다. 128×96 맵 = 청크 20개. 렌더링 사분면은 8칸. `set_terrain(꼭짓점, 값)`은 그 꼭짓점을 코너로 가진 그림 칸 4개만 다시 그린다 (청크 경계에서는 여러 청크에 걸쳐)
- 생성기(`SurfaceGen.generate(seed)`): 맵 가운데 제단 자리(3×3, 설치물 레이어), 제단 빛 반경 안에만 일군 흙 3덩어리(칸의 네 모서리까지 반경 안, 제단 둘레 1칸 비움, 덩어리끼리 안 붙음), 반경 + 4타일 밖에 고정 오염(재) 구역 3곳(노이즈로 가장자리를 흔든 원). 같은 시드 → 모든 기기에서 같은 월드(PCG32 + FastNoiseLite + 정수 해시). 시드 1의 해시를 `test_world.gd`의 `GOLDEN_HASH`로 고정했다 (내보낸 exe의 스모크에서도 같은 해시가 나왔다)
- 제단은 설치물 레이어의 자리(3×3) 위에 `Altar` 노드로 놓인다 (아래 "빛과 제단"). 걷기 충돌은 설치물 레이어를 본다

## 캐릭터 (G2)

- `Character`(actors/character.gd) = 기본 몸 한 벌 + 클래스 표식 레이어 하나 (● brief §5.6 R21). 노드 위치 = 두 발 사이(프레임 바닥 가운데, 발 줄 y=31 바로 아래)라 y 정렬 부모(`Entities`) 아래에서 **발 기준으로 정렬**된다. 속성: `class_id`(paladin|miner|archer|cleric|herbalist), `direction`(남·동·북·서), `walking`(걷기 6프레임 / idle 4프레임)
- 구조: `Rig`(서쪽이면 `scale.x = -1`) 아래 `Body` + 슬롯 `Back`(곡괭이·활) · `Arm`(방패) · `Waist`(씨앗주머니) · `Float`(후광). 방향마다 순서표(`RigData.DRAW_ORDER`)대로 자식 순서를 바꾼다: 등 장비는 남·동(·서)에서 몸 뒤, 북에서 몸 앞. 방패·주머니·후광은 늘 앞. `z_index`는 쓰지 않는다(다른 캐릭터·바닥과의 순서까지 바뀐다)
- 서쪽 = 동쪽 좌우 반전 (● R19). 프레임 32px가 발 가운데 기준이라 반전해도 정수 픽셀이다
- 표식 위치 = v01 걷기 첫 프레임 기준 위치 + v01→v02 발 맞춤 이동(걷기 남 +4 동 +3 북 +4, idle 남 +5 동 +2 북 +3) + 그 프레임의 기준점 이동(+ 후광은 걷기 2~4프레임에서 1px 뜸)
- 기준점(● R27, brief §5.6 "위치"): 프레임마다 **걷기 첫 프레임**의 몸통 줄(v01 y 13~22)·머리 줄(y 0~11)이 가장 많이 겹치는 이동(RGB 차 합 < 60인 픽셀 수, 몸통 ±4px, 머리 ±8px, 같으면 작은 이동). 두 프레임을 각자의 발 맞춤 이동을 되돌린 v01 좌표에서 비교한다. 방패·곡괭이·활·주머니는 몸통, 후광은 머리를 따른다. `tools/build_rig_anchors.gd`가 재서 `actors/rig_anchors.gd`에 표로 쓰고, 테스트가 다시 잰다
  - 걷기 기준점은 스파이크와 같다 (몸통: 북 1·2프레임 아래로 1px, 머리: 남 2~5프레임 위로 1px, 나머지 0)
  - idle: 몸통 남 0 / 동 (0,2)(−1,2)(−1,2)(0,2) / 북 (0,1)×4, 머리 남 (−1,0)(0,0)(−1,0)(−1,0) / 동 (−1,2)(0,2)(−1,2)(0,1) / 북 (0,1)×4. idle은 다른 템플릿이라 걷기와 몸 모양이 조금 달라서 0이 아니다. 창 검사 `--save`로 남긴 걷기·idle 전 프레임(5클래스 × 4방향)을 2배로 모아 봤을 때 표식은 제자리에 붙어 보였다(동쪽 idle에서 표식이 좌우로 1px 흔들린다). 기준점은 재는 법에 따라 1px씩 달라질 수 있으니(스파이크 notes/chars.md) **사람이 보고 고정하는 편이 낫다**
- 방패 시트(`sig_paladin_shield_v01.png`)는 남·동 줄에 걷기 프레임마다 떼어 낸 칸이 6개씩 있지만, "단단한 파츠는 방향당 1장 + 기준점"(● R27)대로 **줄마다 첫 칸만** 쓴다 (R27 동작 시험이 쓴 칸과 같다)
- `Player`(actors/player.gd) = 시뮬레이션(발 위치 float, 4방향 바라보기) + `Character`. `_physics_process`(60Hz 고정)에서 키를 읽어 `Movement.step()`을 돌리고, 노드는 발 위치를 반올림한 정수 픽셀에 둔다. `PlayerCamera`도 정수 픽셀에서 내 캐릭터 가운데를 따라가고 맵 가장자리에서 멈춘다(맵이 화면보다 작은 축은 가운데). 그래서 내 캐릭터와 카메라가 같이 1픽셀씩 움직인다
- 이동 규칙(`Movement`, 순수 함수, 결정적: G3에서 호스트와 클라이언트 예측이 같은 함수를 쓴다): 입력은 축마다 −1/0/1인 8방향, 속력은 대각선도 `WALK_SPEED`. 발 상자(가로 10 × 세로 4px)가 맵(위쪽은 머리 자리 28px 남김) 안, 막힌 칸(설치물 = 제단 3×3) 밖에 있어야 한다. x 먼저, 그다음 y로 움직이고 부딪힌 곳에 딱 붙어 멈추므로 대각선은 벽을 따라 미끄러진다. 바라보기는 4방향: 한 축이면 그쪽, 대각선이면 지금 바라보는 쪽이 두 축 중 하나일 때 그대로, 아니면 가로
- `main.tscn`: 내 캐릭터는 스폰 자리 0(제단 서쪽), 나머지 네 클래스는 자리 1~4에 제단을 보고 선 idle 더미. 스폰 자리 9개(`Config.SPAWN_SLOTS`)는 모두 안전 반경 안, 제단 밖이고 서로 겹치지 않는다 (세션에서는 호스트가 가장 작은 빈 자리를 준다, 아래 "네트워크")

## 빛과 제단 (G2)

- **규칙은 하나**: `SafeZone.is_in_safe_zone(pos)` = 제단 가운데에서 반경(임시 7타일 = 112px) 안 (경계 포함). 게임 로직은 `GameWorld.is_in_safe_zone()`로 이것을 부르고, 빛 텍스처는 같은 함수를 텍셀 가운데마다 불러 만든다
- `AltarLight` = `PointLight2D` 두 개, 제단 가운데(정수 픽셀), `texture_scale` 1(텍셀 하나 = 월드 픽셀 하나):
  - `GroundLight`: 디더 테두리. 반경 − 16px까지 꽉 차고, 그 띠에서 월드 좌표에 고정된 4×4 Bayer 무늬로 사라진다. 켜진 텍셀은 모두 안전 반경 안이다. 빛 레이어 1(바닥 청크, 제단)만 비춘다
  - `ActorLight`: 같은 반경의 hard 테두리 사본. 빛 레이어 2(캐릭터 스프라이트)만 비춘다. 경계 위 캐릭터 얼굴에 체커보드가 생기지 않는다(스파이크 RESULTS §4)
  - 텍스처는 영역마다 한 번 만들어 static 캐시에 붙잡아 둔다(226×226, GDScript 약 26ms). 4.7.2에서 `PointLight2D.texture`를 바꾸며 옛 텍스처가 풀리면 엔진 오류 줄이 나서(스파이크) 한 번 만든 텍스처는 놓지 않는다. 같은 월드를 다시 만들거나 F4로 껐다 켜도 텍스처는 그대로다(테스트)
- 저녁: `CanvasModulate` 따뜻한 회색(임시). 빛 안은 저녁 + 빛 ≈ 그린 색(약 1.05 / 0.97 / 0.90배), 밖은 저녁색 그대로. F4·`--no-evening`은 저녁과 제단 빛을 **같이** 끈다(빛만 남기면 빛 안이 하얗게 뜬다). 낮밤 순환은 만들지 않았다(? 지상의 빛 미정)
- 제단(`Altar`, world/altar.gd): 그림 `altar_v04.png`(48×57, 불투명 x 0~46, y 5~47)의 왼쪽 위를 자리 3×3의 왼쪽 위에 둔다. 그림의 맨 아래 외곽선 줄이 자리의 마지막 픽셀 줄에 온다. 노드는 자리 바닥 가운데라 y 정렬에서 발이 자리 아래 변보다 아래(남쪽)인 캐릭터는 제단 앞, 위인 캐릭터는 제단 뒤에 그려진다
- 불꽃: `altar_v04.png`와 `altar_v04_unlit.png`가 다르고 밝기 148 이상인 픽셀 = 81개(등잔 9 × 9). 같은 자리에 unshaded로 한 번 더 그려서 저녁에도 원본 색 그대로다(창 검사에서 채널 차 0). brief §5.7은 불꽃을 손으로 그려 빛 마스크와 함께 두라고 하는데 그 그림이 아직 없어서 켜짐·꺼짐 차이로 만든다
- 디버그 선(F3)도 unshaded라 저녁에 어두워지지 않는다

## 네트워크 (G3)

● 호스트 권한 협동 (game-concept §13), 2인부터, 구조는 ● 9인 (`Config.MAX_PLAYERS`). Godot 내장 고수준 멀티플레이(SceneMultiplayer RPC) 위에 직접 짰다. `MultiplayerSpawner`·`MultiplayerSynchronizer`는 쓰지 않는다 (스파이크 RESULTS §5: always는 서 있어도 보내고 on_change는 걸을 때 더 비싸다).

- **노드 하나**: `main.tscn`의 `Net`(`NetSession`)이 모든 RPC를 받는다. 모든 기기에서 경로가 같다(`/root/Main/Net`). 혼자 할 때(`--host`/`--join` 없음)는 아무것도 하지 않는다
- **전송 계층**(`NetTransport`): `configure(options)` 뒤 `host(api)` / `join(api)`. 결과는 시그널(`opened` / `open_failed(이유)`)로, 호출 안이 아니라 나중에 한 번. ENet(`EnetTransport`)이 지금 쓰는 것, `SteamTransport`는 GodotSteam이 없으면(지금) "unavailable"로 실패하는 자리다. 실제 Steam 로비 흐름은 M1이 아니다. 클라이언트끼리는 통하지 않는다(`server_relay = false`, Steam 기본과 같음)
- **접속**: 클라이언트가 hello(프로토콜 버전, 클래스)를 보내면 호스트가 `Roster`로 받거나 거부한다. 거부 이유: `full`(인원 상한), `version`, `class`(슬라이스 클래스가 아님), `class_taken`(같은 클래스 금지일 때만, 지금은 꺼짐). **상한은 전송이 아니라 호스트가 센다** (ENet은 연결을 16개까지 받아서 열 번째에게 이유를 말해 줄 수 있다. Steam peer에는 상한 인자가 없다). 받으면 가장 작은 빈 스폰 자리(나간 사람 자리를 다시 씀), 거부하면 이유를 보내고 클라이언트가 스스로 끊는다(호스트가 바로 끊으면 ENet이 보낼 메시지를 버린다. 2초 지나도 남아 있으면 호스트가 끊는다). hello 없이 5초 있는 연결도 끊는다
- **늦은 참가 = 시드 + 편집 기록**: welcome에 시드, 맵 크기, 편집 기록(`EditLog`), 호스트 월드 md5, 지금 있는 플레이어가 들어간다. 클라이언트는 `SurfaceGen.generate(시드)` 후 기록을 차례로 적용하고 md5가 호스트와 다르면 끊는다(종료 코드 5: 다른 아키텍처에서 생성이 달라지면 여기서 드러난다). 편집은 "칸 = 값" 절대값이라 두 번 적용해도 같다. M1에는 게임 편집이 없어서 호스트의 디버그 편집(봇 `edit:`, 풀 ↔ 흙만)으로 길을 시험한다. 그 뒤의 편집은 reliable로 그때그때 보낸다
- **이동은 호스트가 정한다**: 클라이언트는 입력 프레임(번호, 8방향, 바라보기)만 보낸다. 움직이는 동안과 멈춘 첫 틱에만 프레임이 생기고(서 있으면 아무것도 안 보냄), 2틱마다(30Hz) 호스트가 아직 확인하지 않은 프레임을 전부 다시 담아 unreliable로 보낸다(패킷 하나를 잃어도 다음 패킷에 들어 있다). 호스트(`InputGate`)는 번호 순서대로 한 번씩만, 축마다 −1..1로, 틱마다 토큰 하나(최대 30개 모아 둠)만큼만 적용해서 실제 시간보다 빨리 걸을 수 없다. 받은 프레임은 틱마다 하나씩(밀리면 더) 적용해서 다른 사람 눈에 고르게 걷는다. 호스트 자신의 캐릭터는 키를 바로 적용한다
- **묶음 상태**(`StateBroadcast`): 호스트는 3틱마다(20Hz, 임시값) 모든 플레이어의 상태(자리, float32 위치 그대로, 바라보기, 걷기, 확인한 마지막 프레임 번호)를 한 패킷(5 + 14B × 인원)에 담아, **바뀐 것이 있을 때만** unreliable로 보낸다. 바뀐 것이 없어지면 같은 상태를 reliable 키프레임으로 한 번 더 보내고(마지막 묶음을 잃어도 맞게), 그다음에는 누가 다시 움직일 때까지 아무것도 보내지 않는다. 남는 것은 ENet 자체의 유지 패킷(클라이언트 하나당 초당 약 5개)뿐이다
- **자기 캐릭터 예측**(`Prediction`): 클라이언트는 입력을 그 틱에 바로 같은 `Movement.step`으로 적용한다(왕복을 기다리지 않음). 호스트 상태가 오면 "프레임 n까지 처리한 위치"에서 시작해 아직 확인 안 된 프레임을 다시 돌린다. 같은 코드·같은 float32·같은 순서라 다시 돌린 결과가 예측과 같다: 테스트에서 오차는 늘 0.0px (지연 120ms + 손실 15% 흉내에서도). 호스트와 다르면(프레임을 못 받았거나 호스트가 옮겼거나) 호스트가 이기고 오차로 센다
- **남의 캐릭터 보간**(`Interpolation`): 호스트 틱 번호가 찍힌 상태를 모아 두고 100ms(임시값, 묶음 2개) 뒤를 선형으로 그린다. 마지막 상태 뒤는 앞질러 추측하지 않고 멈춘다. 조용하던 사람이 다시 움직이면 직전 상태를 한 간격 앞에 다시 넣어 조용했던 동안 미끄러지지 않게 한다. 호스트 틱은 묶음 도착 시각에서 가장 덜 늦은 값으로 추정한다(`RemoteClock`)
- **채널**: 0 reliable (hello, welcome, 거부, 들어옴·나감, 편집, 키프레임, 테스트용 go/done/finish), 1 unreliable ordered (입력), 2 unreliable ordered (상태). 클라이언트가 부를 수 있는 RPC는 hello·입력·done 셋뿐이고 나머지는 호스트만(authority) 부를 수 있다 (`test_net.gd`가 RPC 표를 확인)
- **나감**: 호스트는 그 자리를 비우고 남은 사람에게 알린다. 클라이언트가 호스트를 잃으면: 테스트 인스턴스(`--net-out`)는 종료 코드 4, 사람이 띄운 것은 다른 플레이어를 지우고 혼자 계속 걷는다
- 전송 형식은 모두 `PackedByteArray` 하나에 직접 쓴다(`NetProtocol`). 디코더는 크기·범위를 먼저 보고 틀리면 버리고 센다(엔진 오류 없이)

### 테스트가 확인하는 것 (`test_net_session.gd`)

모든 인스턴스가 끝에 결과 JSON을 쓴다. 호스트와 비교하는 것: **위치 해시**(플레이어마다 자리·클래스·float32 위치 그대로·바라보기의 md5), **월드 해시**, 플레이어 수. 그 밖에 바닥 그림 = 데이터(`GroundView.verify`), 클라이언트 예측 오차 ≤ 0.5px(실제로는 0.0)와 확인 안 된 프레임 0, 늦은 참가자의 편집 1개와 "시드만의 월드와 다름", 나간 자리를 늦은 참가자가 받음, 거부 이유 `full`, 잘못된 메시지 0, 호스트 입력 검사의 빈 번호·잘못된 패킷 0, 조용함(아무도 12틱 넘게 안 움직였는데 보낸 묶음 0), 헤드리스 자식의 틱이 실제 시간을 따라감, 종료 코드, 자식 로그에 `ERROR:` 0, 남은 프로세스 0.

## 규칙

- **타입을 붙인 GDScript만**. `project.godot`에서 경고 5종(`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`)을 **오류**로 켰다. 걸리면 그 스크립트가 컴파일되지 않는다. 자주 걸리는 것: `int(v)`·`float(v)`에 Variant를 넣기(→ `var n: int = v`로 먼저 받기), Variant를 `as T`로 바꾸기(→ 타입 있는 변수에 대입), `Dictionary.get()` 결과를 바로 인자로 넘기기, `Script.new()`(→ `GDScript`로 받기). 데이터는 타입 없는 Dictionary 대신 타입 있는 Dictionary나 작은 클래스로
- Godot 4 API만 (`TileMapLayer`, `@export`·`@onready`, Callable 시그널). C# 없음. 줄바꿈 LF
- 게임 클래스는 `class_name`을 쓴다 (새 파일을 추가하면 임포트를 한 번 돌려 클래스 캐시를 갱신). `tests/`의 스크립트는 `class_name` 없이 경로로 `extends "res://tests/base_test.gd"` (내보내기에서 빠지는 폴더라서)
- 게임 코드는 오토로드 이름 `Cli`를 직접 쓰지 않고 `CliOptions.current()`를 쓴다. `--script`로 시작하는 도구는 오토로드가 등록되기 전에 컴파일돼서 `Cli`를 못 찾는다 (G1에서 실제로 겪음)
- 상수는 `core/config.gd`에 모은다. 주석으로 ●(문서 결정) / `PROVISIONAL`(○·?, 문서 위치) / `IMPL`(에이전트 선택)을 구분한다. 임시값을 새로 만들면 아래 표에도 적는다
- 기계가 읽는 출력 줄은 `EVENSONG_` 접두어 (`EVENSONG_SMOKE`, `EVENSONG_SCREENSHOT`, `EVENSONG_TESTS`, `EVENSONG_TILESET`, `EVENSONG_ANCHORS`, `EVENSONG_RENDER`, `EVENSONG_CLI`, `EVENSONG_NET <인스턴스> <사건> ...`)
- 네트워크: 게임 상태를 바꾸는 것은 호스트만 한다. 클라이언트가 보내는 RPC는 `any_peer`로 열고 호스트가 검사한다(지금은 hello·입력·done). 새 메시지는 `NetProtocol`에 크기 고정 형식으로 넣고 디코더가 크기·범위를 먼저 본다. 이동 규칙을 바꾸면 호스트와 예측이 같이 바뀐다(`Movement` 하나). 월드를 바꾸는 일은 `EditLog`를 거친다(늦은 참가자가 같은 월드를 받도록)
- 빛 레이어: 바닥·제단·건물 = `Config.LIGHT_LAYER_WORLD`(1, 기본값), 캐릭터 스프라이트 = `LIGHT_LAYER_ACTORS`(2). `light_mask`는 자식에게 물려지지 않으니 스프라이트마다 넣는다
- 빛 텍스처(`PointLight2D.texture`)는 실행 중에 새로 만들어 갈아 끼우지 않는다. `AltarLight.texture_for()`의 캐시를 쓴다
- 스프라이트 안의 그리기 순서는 트리 순서로, 다른 물체와의 순서는 y 정렬(발 = 노드 위치)로 정한다. `z_index`는 디버그 선에만 쓴다
- 그림은 `assets/concept`의 우리 PNG·JSON만 `art/`로 복사한다 (바이트까지 같게). 남의 에셋은 넣지 않는다. `game/` 아래 PNG는 LFS 규칙(`assets/concept/**`) 밖이라 작은 것만
- 생성기나 그 상수를 일부러 바꾸면 `test_world.gd`의 `GOLDEN_HASH`를 새 값으로 바꾼다 (실패 메시지에 새 값이 나온다). 늦은 참가(G3)가 "시드 + 편집 기록"으로 월드를 다시 만들기 때문에 이 값이 모르게 바뀌면 안 된다

### 테스트 쓰는 법

`tests/test_<이름>.gd` 하나 = 러너가 찾는 테스트 파일 하나.

```gdscript
extends "res://tests/base_test.gd"

func run() -> Array[String]:
	check_eq(1 + 1, 2, "덧셈")
	var node: Node2D = add_node(Node2D.new()) as Node2D   # 루트에 붙이고, 끝나면 러너가 지운다
	await await_frames(2)                                 # await 해도 된다
	allow_error("Node not found")                         # 일부러 내는 오류는 먼저 알린다 (기본 정확히 1번)
	node.get_node("missing")
	note("측정값 한 줄")                                   # PASS/FAIL 아래 "  * "로 찍힌다
	return failures
```

- 헬퍼: `check`, `check_eq`(int/float는 수로, String/StringName은 글자로 비교), `check_ne`, `check_between`, `check_has`, `fail`, `note`, `allow_error(패턴, 횟수)`(-1 = 아무 횟수), `add_node`, `await_frames`
- 그 파일이 도는 동안(정리 포함) 로그에 찍힌 **엔진 오류, `push_error()`, GDScript 실행 오류, 셰이더 오류는 모두 실패**다 (OS `Logger`로 받는다). `allow_error()`로 알린 것만 통과하고, 알렸는데 안 나오거나 횟수가 다르면 그것도 실패다. 첫 파일 전에 난 오류는 `FAIL (startup)`. 경고는 세지 않고 `  ! `로 찍기만 한다
- 러너가 실패를 놓치지 않는지는 `tests/fixtures/case_*.gd` 10개(check 실패, 알리지 않은 push_error, 엔진 오류, await 뒤 오류, 실행 오류, 시간 초과, 기반 클래스 아님, 알렸는데 안 나온 오류 / 통과 2개)로 `test_core.gd`가 매번 확인한다
- 시간 측정은 예열 한 번 + 여러 번 재고 범위로 적는다. 테스트가 확인하지 않은 것은 주장하지 않는다

## 임시값 (사람 확인 필요)

문서가 ○(제안)이거나 ?(미정)인데 M1에 값이 필요해서 넣은 것. 모두 `core/config.gd`의 `PROVISIONAL` 상수다 (키 배치만 `project.godot`). 정해지면 상수만 바꾸고 `GOLDEN_HASH`를 갱신한다.

| 무엇 | 코드 | 지금 값 | 문서 |
|---|---|---|---|
| 지상 시작 구역 크기 | `MAP_SIZE` | 128 × 96 타일 (2048 × 1536 px) | ○ gameplay-design §3.1 (경계 있는 연속 맵, 크기 없음) |
| 제단 안전 반경 | `SAFE_RADIUS_TILES` | 7타일 = 112 px (스파이크 값). 지름 14칸이 화면 세로 약 17칸 안에 들어간다 | ? 반경 미정 (game-concept §7 화면 배율 줄: "제단 빛 반경을 정할 때 화면 세로 약 17칸 안에 들어오는지 함께 본다") |
| 제단 바닥 차지 | `ALTAR_FOOTPRINT` | 3 × 3 타일, 맵 한가운데 | ○ concept-art-brief §5.7 (R29) |
| 밭(일군 흙) | `SOIL_PATCH_COUNT`, `SOIL_PATCH_MIN`/`MAX` | 빛 반경 안에 3덩어리, 2×2 ~ 4×3, 제단 둘레 1칸 비움 | ○ "빛 안의 밭" game-concept §9.7·§12 판정 기준, gameplay-design §3.8 |
| 고정 오염 구역 수 | `ASH_ZONE_COUNT` | 3 | ● 2~3곳 (game-concept §12). 그 안의 수는 미정 |
| 오염 구역 크기 | `ASH_ZONE_RADIUS_MIN`/`MAX` | 반지름 5~8타일 (+ 가장자리 노이즈 ±3타일) | 문서에 없음 |
| 빛과 오염 사이 거리 | `ASH_CLEARANCE_TILES` | 안전 반경 밖 4타일부터 재 | 문서에 없음 (흙·재가 닿지 않게 하는 풀 띠이기도 하다) |
| 키 배치 | `project.godot` 입력 `move_*`, `debug_overlay`, `toggle_evening` | WASD + 방향키 (물리 키), F3 디버그 선, F4 저녁 켜고 끄기 | ○ gameplay-design §1 키 배치 초안 (F3·F4는 개발용, 초안에 없음) |
| 걷기 속도 | `WALK_SPEED` | 72 px/s (4.5타일/초), 8방향 같은 속력 | 문서에 없음 (M1 지시: 64~80 px/s) |
| 지상의 빛 | `EVENING_COLOR` | 늘 저녁 하나, `CanvasModulate` (0.40, 0.34, 0.31) 따뜻한 회색 (스파이크 값). 낮밤 순환 없음 | ? 낮밤 / 영원한 황혼 (gameplay-design §3.1, game-concept §7) |
| 제단 빛 색·세기 | `ALTAR_LIGHT_COLOR`, `ALTAR_LIGHT_ENERGY` | (1.0, 0.97, 0.91) × 0.65, 더하기 (스파이크 값. 빛 안 ≈ 그린 색) | 문서에 없음 |
| 안전 반경 테두리 | `SAFE_EDGE_BAND_PX`, `AltarLight` | 바닥: 반경 안쪽 16px 디더 띠 / 캐릭터: 같은 반경 hard 사본 (스파이크 제안) | 문서에 없음 (concept-art-brief §7 체크리스트의 "디더링으로 사라지는 빛 원"과 같은 쪽) |
| 제단 그림 | `art/env/altar_v04.png`, `altar_v04_unlit.png` | 4단계 채택 후보를 임시 그림으로. 등잔 9개 모두 켜짐 | ○ R29 채택 후보 (concept-art-brief §5.7), 켜진 등잔 수 메커닉은 ○ game-concept §9.3 |
| 8방향 이동 + 4방향 바라보기 | `Movement` | 위 "캐릭터" 참조 | 문서에 없음 (M1 지시) |
| 상태 묶음 빈도 | `NET_STATE_HZ` | 20Hz (3틱마다), 바뀐 것이 있을 때만 | 문서에 없음 (M1 지시: 20~30Hz) |
| 남의 캐릭터 보간 지연 | `NET_INTERP_DELAY_MS` | 100ms (묶음 2개) | 문서에 없음 (M1 지시: 약 100ms) |
| 같은 클래스 둘 | `NET_UNIQUE_CLASSES` | 허용 (false). true면 호스트가 `class_taken`으로 거부 | ? 정해지지 않음 (gameplay-design §5 ○ 파티 UI 3×3은 클래스당 한 명 같지만 M1은 5클래스라 9인을 막게 된다) |
| 참가자 스폰 | `Roster`, `SPAWN_SLOTS` | 가장 작은 빈 자리, 남쪽을 보고 선다 | ○ gameplay-design §5 "부활 지점: 제단" (제단 둘레에 놓는 것은 G2 자리를 그대로 씀) |
| 디버그 월드 편집 | 봇 `edit:<x>,<y>,<grass\|soil>` | 호스트만, 바닥 풀 ↔ 흙(괭이질)만 | 문서에 없음 (M1에 게임 편집이 없어 늦은 참가 길을 시험하려고. 키는 만들지 않았다) |

### 구현에서 고른 값 (설계 결정 아님)

| 무엇 | 코드 | 값 | 이유 |
|---|---|---|---|
| 기본 시드 | `DEFAULT_SEED` | 1 | |
| 바닥 청크 크기 | `GROUND_CHUNK` | 그림 칸 32 × 32 | 스파이크: `TileMapLayer`가 클수록 한 칸 편집이 비싸다 (RESULTS §3) |
| 바닥 렌더링 사분면 | `GROUND_QUADRANT` | 8칸 (128 px) | 캔버스 아이템 하나가 받는 빛 15개 한도 (RESULTS §4). G2의 빛은 2개뿐이라 그대로 둠 |
| 속 타일 변형 가중치 | `VARIANT_WEIGHT` | 변형 하나당 0.25 (기본 타일 1) | 풀은 기본 50%, 변형 4개 각 12.5% (테스트가 1만 칸에서 비율 확인) |
| 재 가장자리 노이즈 | `ASH_EDGE_NOISE_TILES`, `ASH_EDGE_NOISE_FREQUENCY` | ±3타일, 0.2 / 타일 | ±2타일은 덩어리가 너무 둥글었다 (스크래치 캡처로 비교) |
| 자유 카메라 속도 | `FREE_CAMERA_SPEED` | 240 px/s | `world.tscn`(맵 보기)에서만. 실행 장면은 플레이어 카메라 |
| 기본 호스트 포트 | `DEFAULT_PORT` | 24600 (UDP) | 테스트는 `NET_TEST_PORT_FIRST..LAST` 24621-24640 (스파이크는 24601-24620) |
| 시뮬레이션 틱 | `NET_TICK_RATE`, `NET_TICK` | 60 (= 물리 틱, 스모크가 확인) | 입력 프레임 하나 = `Movement.step` 한 번 (1/60초) |
| 입력 보내기 | `NET_INPUT_HZ`, `NET_MAX_FRAMES_PER_PACKET` | 30Hz, 확인 안 된 프레임을 최대 32개(0.5초)까지 매번 다시 | 패킷을 잃어도 다음 패킷이 메운다. 움직이기 시작한 틱에는 바로 보낸다 |
| 호스트 속도 제한 | `NET_INPUT_BURST` | 틱마다 토큰 1, 최대 30 | 실제 시간보다 빨리 걸을 수 없고, 몰려 온 패킷은 0.5초까지 따라잡는다 |
| 호스트의 고른 적용 | `NET_INPUT_JITTER_FRAMES` | 3프레임 넘게 쌓이면 한 틱에 더 적용 | 30Hz로 오는 입력을 60Hz로 고르게 (다른 사람 눈에) |
| 연결 한도 | `NET_TRANSPORT_PEER_LIMIT` | ENet 16 | 9명을 넘는 사람에게도 "full"을 말해 주려고. 상한은 `Roster`가 센다 |
| 접속 시간 | `NET_CONNECT_TIMEOUT_SEC`, `NET_HELLO_TIMEOUT_SEC`, `NET_REFUSE_GRACE_SEC` | 10초 / 5초 / 2초 | ENet 스스로는 약 31초 뒤에야 실패를 알린다 (이 데스크탑에서 잼) |
| 위치 전송 | `NetProtocol` | float32 그대로 (4B × 2) | 예측을 다시 돌린 결과가 호스트와 비트까지 같게. 고정소수점으로 줄이면 속도가 조금 바뀐다 |
| 조용함 판정 | `StateBroadcast.QUIET_TICKS` | 12틱 | 테스트용 판정. 마지막 걸음·출입 뒤 12틱이 지나면 묶음을 보내면 안 된다 |
| ENet 압축 | `EnetTransport` | 없음 | 스파이크: range coder로 ENet 바이트 30~45% 줄지만 호스트·클라이언트가 같아야 해서 M1은 단순하게 |
| 호스트를 잃은 클라이언트 | `Main._on_net_ended` | 사람이 띄운 것은 혼자 계속, 테스트 인스턴스는 종료 코드 4 | UI가 없어서 창이 그냥 닫히는 것보다 낫다고 봄 |
| 재 속 타일 | `tiles_ash_var_1~3_v02.png` | 곰팡이·뼈 장식이 그려진 판 | 장식을 흩뿌리는 코드가 아직 없어서. 흩뿌리기를 만들면 `tiles_ash_plain_*`로 바꾼다 (04-env/prompts.md) |
| 두 번째 전부-풀 타일 | 풀↔재 세트의 전부 풀 타일 | 쓰지 않음 | 풀↔흙 세트의 것(= `tiles_grass_base_v02.png`)과 2픽셀만 달라서 한 벌로 |
| 내 클래스 기본값 | `DEFAULT_CLASS` | paladin | `--class`가 없을 때 |
| 애니메이션 속도 | `WALK_FRAME_TIME`, `IDLE_FRAME_TIME` | 걷기 0.12초/프레임 (3단계 걷기 GIF와 같음), idle 0.2초/프레임 | |
| 발 충돌 상자 | `FEET_HALF_WIDTH`, `FEET_HEIGHT` | 발 기준 가로 10 × 세로 4 px (발 위쪽으로) | 30px 캐릭터의 발 폭 정도. 제단 아래 변에 붙으면 몸이 제단 앞면을 가린다 |
| 머리 자리 | `HEAD_ROOM_PX` | 발은 맵 위 끝에서 28px 아래까지만 | 머리(프레임 y=4)가 맵 밖으로 안 나가게 |
| 스폰 자리 | `SPAWN_SLOTS` | 제단 가운데 기준 9곳 (서·동·북·남서·남동·북서·북동·먼 서·먼 동) | 모두 안전 반경 안·제단 밖·서로 안 겹침 (테스트). 자리 0 = 내 캐릭터 |
| 빛 레이어 | `LIGHT_LAYER_WORLD`, `LIGHT_LAYER_ACTORS` | 1, 2 | 바닥용 디더 빛과 캐릭터용 hard 빛을 나누려고 |
| 불꽃 마스크 밝기 | `FLAME_MIN_LUMA` | 148 (0~255) | 켜짐·꺼짐 차이 211픽셀 중 불꽃 81픽셀만 (돌에 비친 빛은 뺌, 스파이크 값) |
| 기준점 재기 | `RigData.ANCHOR_TOLERANCE` 등 | RGB 차 합 < 60, 몸통 ±4 / 머리 ±8px, 기준 = 걷기 첫 프레임 | 반경은 brief §5.6 R27. 색 허용 60은 스파이크 값 |
| 후광 자리 | `RigData.signature_for("cleric")` | v01 좌표 (10, −5), 머리를 따름, 걷기 2~4프레임 1px 위 | 스파이크·5차 목업 값. 머리 꼭대기 바로 위 (테스트) |
| 방패 칸 | `RigData` `LAYOUT_ROW_FIRST` | 방패 시트 줄마다 첫 칸 | ● R27 "방향당 1장 + 기준점"을 따름 (위 "캐릭터") |
| 대각선 바라보기 | `Movement.facing_for` | 지금 방향이 두 축 중 하나면 유지, 아니면 가로 | 대각선에서 방향이 깜빡이지 않게 |
| 제단 그림 자리 | `Altar.setup` | 그림 왼쪽 위 = 자리 왼쪽 위 (맨 아래 외곽선 = 자리 마지막 줄) | 불투명 47×43이 3×3 자리 안에 든다 |

## 그림 출처

`art/`의 파일은 모두 `assets/concept`의 우리 파일 그대로다 (`test_actors.gd`가 저장소에서 돌 때 22개 전부 md5 비교).

| 파일 | 원본 |
|---|---|
| `tiles_grass-soil_v03.png`, `tiles_grass-soil_v01.json` | `04-env/` (풀↔일군 흙 Wang 16장, JSON은 v01 배치) |
| `tiles_grass-corruption_v05.png` | `04-env/` (풀↔재) |
| `tiles_grass-corruption_v02.json` | `03-pixel/` (v05 그림의 배치) |
| `tiles_grass_var_1~4_v02.png`, `tiles_soil_var_1~2_v01.png`, `tiles_ash_var_1~3_v02.png` | `04-env/` (속 타일 변형) |
| `chars/base_body_v02_walk.png`, `chars/base_body_v02_idle.png` | `03-pixel/` (기본 몸 걷기 6 / idle 4프레임, 줄 남·동·북, 발 y=31) |
| `chars/sig_paladin_shield_v01.png`, `sig_miner_pickaxe_v01.png`, `sig_archer_bow_v01.png`, `sig_cleric_halo_v01.png`, `sig_herbalist_pouch_v02.png` | `03-pixel/` (클래스 표식 레이어 5종, 걷기 v01 첫 프레임에 그림) |
| `env/altar_v04.png`, `env/altar_v04_unlit.png` | `04-env/` (제단 3×3, 켜짐·꺼짐) |

## 측정 (이 데스크탑, `.godot/`을 지운 상태에서)

G3 (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 + 전체 테스트, 두 번 (흔들림 확인) | 두 번 모두: 임포트 2.9초 종료 0 오류 줄 0, 테스트 6파일 통과 2,297 checks 약 35초 종료 0 (actors 1,136 / core 192 / light 73 / net 279 / net_session 188 / world 429). net_session이 그중 약 28초 |
| `test_net.gd` | 279 checks, 약 0.4초. 가짜 연결 예측: 지연 0·5·9틱(손실 0·0·25%)에서 프레임 329개, 오차 0.000px |
| `test_net_session.gd` | 약 29초 (세션 셋 + drop). `--net-full` 넣으면 약 33초 (자식 10개 세션 하나 더) |
| 내보내기 | x86_64 2.7초 `evensong.exe` 109,481,072 B, ARM64 2.4초 91,874,928 B, 둘 다 종료 0, 오류 줄 0. 내보낸 exe 120프레임(헤드리스) 1.1초 종료 0 오류 줄 0 |
| 내보낸 exe `--smoke` | 83 checks ok (네트워크 8개 더: 물리 틱, ENet 루프백 호스트, Steam 없음, 상태 왕복, 10번째 거부, main.tscn의 Net) |
| 내보낸 exe로 세션 테스트 (`--net-exe=build/evensong.console.exe`) | 통과, 189 checks, 약 28초 (호스트·클라이언트·늦은 참가자·거부되는 다섯 번째·drop 모두 내보낸 exe, 자식 14개) |
| 두 창 스크린샷 (창 모드, `--max-fps 60`) | `shots/net_host.png`(호스트 화면), `shots/net_client.png`(클라이언트 화면), 둘 다 480×270. 같은 순간의 두 화면에 팔라딘(호스트)과 성직자(클라이언트)가 같은 자리에 보인다 |
| 일부러 깨 보기 (스크래치 `mutate.py`, 커밋 안 함) | 15개 모두 잡힘 (아래) |

트래픽 (localhost, ENet 통계 = ENet 헤더 포함·UDP/IP 헤더 제외, 괄호는 UDP/IPv4 28B/패킷을 더한 선로 추정. 봇이 같이 걷는 동안 / 모두 서 있는 동안, 이 세션에서 여러 번 돌린 범위):

| 인원 | 호스트 송신, 모두 걸을 때 | 호스트 송신, 모두 서 있을 때 | 클라이언트 하나 송신 (걸을 때 / 서 있을 때) | 클라이언트 하나 수신 (걸을 때) |
|---|---|---|---|---|
| 2 | 950~970 B/s (1.6 KB/s), 23~24 pkt/s | 111 B/s (266 B/s), 5.5 pkt/s | 760~780 B/s (1.7 KB/s) / 40~53 B/s | 약 960 B/s |
| 4 | 4.5~4.6 KB/s (6.5~6.6 KB/s), 72 pkt/s | 475~550 B/s (1.0~1.1 KB/s) | 730~790 B/s (1.7 KB/s) / 40~47 B/s | 약 1.5 KB/s |
| 9 (`--net-full`) | 22.0~23.1 KB/s (27~28.6 KB/s ≈ 0.23 Mbps), 185~193 pkt/s | 1.5 KB/s (2.6 KB/s) | 680~740 B/s / 42~64 B/s | 약 3.0 KB/s |

- 서 있을 때 세션은 아무것도 보내지 않는다(테스트: 조용함 위반 0). 남는 것은 ENet 유지 패킷(클라이언트 하나당 초당 약 5개)과, 표의 4·9인 "서 있을 때"에 섞인 출입·편집·키프레임 같은 일회성 메시지다
- 스파이크(RESULTS §5, `MultiplayerSynchronizer` always 30Hz)는 4인 6.5 KB/s, 9인 36 KB/s를 서 있어도 똑같이 보냈다. 지금은 20Hz·바뀔 때만이라 걸을 때 4인 4.6 KB/s, 9인 약 23 KB/s, 서 있을 때는 유지 패킷 정도
- 클라이언트 송신이 인원과 상관없이 비슷한 것은 입력만 보내기 때문이다 (30 pkt/s, 확인 안 된 프레임을 다시 담음)
- 9인 수치는 `--net-full` 1.45초 창 하나에서 잰 것이라 거칠다
- 지연 흉내(왕복 120ms, 손실 15%): 클라이언트 입력 패킷 약 129개 중 19개 버림, 호스트에 중복 프레임 수백 개(다시 담은 것), 빈 번호 0, 예측 오차 0.0px. 남의 캐릭터를 그릴 때 가장 새 상태를 지나 버린 프레임 14~23 / 약 90 (100ms 버퍼로 15% 손실을 다 덮지는 못한다. localhost에서는 0)
- 10프로세스(`--net-full`)를 처음 돌렸을 때 클라이언트 하나가 남의 캐릭터를 그린 프레임의 18%에서 새 상태를 지나 버렸다. 호스트 시계 추정을 클라이언트 물리 틱 수로 했더니, CPU를 늦게 받은 프로세스가 틱을 몰아서 따라잡을 때 추정이 앞서 나갔다. 클라이언트 쪽을 실제 시간(`Time.get_ticks_usec`)으로 바꾼 뒤 0

일부러 깨 보기 (G3, 스크래치 `mutate.py`, 파일마다 되돌림): 다시 돌리기 빼기, 서 있을 때도 프레임 기록, 속도 제한 끄기, 중복 프레임 다시 적용, 빈 자리 다시 쓰기 끄기, 인원 상한 끄기, 키프레임 안 보내기, 늘 묶음 보내기, 클라이언트가 편집 무시, welcome에서 편집 기록 빼기, 보간 지연 빼기, 상태의 y에 x 쓰기, 지연 흉내가 안 버림, 호스트가 멈춤 프레임 무시, 호스트 잃은 클라이언트가 종료. 마지막 코드로 다시 돌려 15개 모두 테스트가 FAIL·종료 1. 처음 돌렸을 때 "보간 지연 빼기"만 놓쳐서(세션 테스트가 끝 위치만 봤다) "가장 새 상태를 지나 그린 프레임" 검사를 더했다. 그 과정에서 조용함 판정의 순서 버그(걸음 시작을 그 틱의 묶음 판단 뒤에 기록해서, 조용하다 처음 움직이는 묶음을 위반으로 셈. 세션 테스트가 가끔 실패)도 찾아 고쳤다

G2 (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 | 4.3초, 종료 0, 오류 줄 0 |
| 기준점 표 다시 만들기 | 0.6초, 종료 0, 커밋된 파일과 같음 (테스트가 다시 재서 확인) |
| 전체 테스트 | 4파일 통과, 1,811 checks, 약 9.0초, 종료 0 (actors 1,136 checks 1.3초 중 기준점 다시 재기 0.5초, core 173 checks 2.8초, light 73 checks 0.4초, world 429 checks 4.1초) |
| 창 그림 검사 `check_render.gd` | 2.5초, 5부분 모두 ok, 종료 0 (ground 화면 129,600픽셀 중 129,347개 판정·불일치 0, 테두리 고리 20,900개; flames 81개 차 0; actor 298픽셀 불일치 0; rig 10화면 1,296,000픽셀 불일치 0; ysort 불일치 0) |
| 내보내기 | x86_64 4.0초, `evensong.exe` 109,413,984 B; ARM64 3.9초, 91,807,840 B. 둘 다 종료 0 |
| 내보낸 exe `--smoke` | 0.7초, 75 checks ok, 월드 해시 `e04258e54b02` (에디터 빌드와 같음) |
| 내보낸 exe 120프레임 (헤드리스) | 1.3초, 종료 0, 오류 줄 0 |
| 내보낸 exe 창 스크린샷 (`--class=herbalist`) | 480×270, 종료 0 (G1에서 못 해 본 것) |
| 스크린샷 (main.tscn) | 약 1.9초, 480×270 (이 세션 화면이 1024×768이라 창 960×540) |
| 안전 반경 빛 이미지 226×226 만들기 (GDScript, 영역마다 한 번) | 약 26 ms |
| 생성 128×96 / 그림 칸 12,513개 그리기 / `set_terrain` 한 번 (헤드리스, 예열 뒤 3번) | 2.5~5.4 ms / 32.9~35.8 ms / 약 17 µs |

마지막 줄은 G1(아래)보다 느리게 나왔는데, G1 커밋(`0c1c032`)을 그대로 풀어 같은 때에 돌려도 33.6~34.9 ms, 17.6 µs가 나왔다. 코드가 아니라 그때 기기 상태 차이다. 실행마다 이 정도는 흔들린다고 보면 된다.

G1 (2026-10-21): 임포트 2.5초, 전체 테스트 2파일 580 checks 4.9초, 내보내기 각 2.6초(109,359,360 B / 91,753,216 B), 내보낸 exe 스모크 0.38초 43 checks, 생성 1.3~2.4 ms, 그리기 18.7~22.5 ms, `set_terrain` 약 10 µs.

생성·그리기 수치는 헤드리스(더미 렌더러)라 GPU 쪽 비용은 들어 있지 않다. 실제 창에서의 프레임 시간은 아직 재지 않았다.

일부러 깨 보기 (G2에서 한 번씩, 커밋하지 않음, 스크래치 `mutate.sh`): 테스트로 - 북쪽 그리기 순서, 서쪽 반전 끄기, 기준점 무시, 커밋된 기준점 표 한 값, idle 발 맞춤 이동, 디더 빛이 반경 밖까지, 캐릭터 빛을 디더로, 불꽃 shaded, y 정렬 끄기, 제단 충돌 끄기, 대각선 정규화 빼기, 카메라 가장자리 멈춤 빼기, 머리 자리 빼기, 대각선 바라보기 규칙, 스폰 자리를 제단 위로. 15개 모두 FAIL·종료 1. 창 그림 검사로 - 위 "그림 검사" 8개 모두 FAIL·종료 1.

일부러 깨 보기 (G1에서 한 번, 커밋하지 않음): 그림 칸의 코너를 한 칸 밀기, 편집 때 4칸 중 1칸 안 그리기, 흙을 반경 1.6배까지 놓기, 흙·재 이웃 규칙 끄기, 커밋된 `.tres`의 코너 하나 바꾸기, `project.godot` 화면비를 keep으로, 빌더의 변형 가중치 바꾸기. 7개 모두 테스트가 FAIL·종료 1로 잡았다.

## M1 범위와 단계 상태

M1 = 한 화면에서 이동, 타일, 제단 빛, 2인 접속. 전투·채굴·건설·농사·제작·적·UI 메뉴·Steam은 M1이 아니다.

| 단계 | 내용 | 상태 |
|---|---|---|
| G1 뼈대 + 월드 | 프로젝트·설정, 내보내기 2종, CLI·스모크, 테스트 러너(엔진 오류까지 셈, 자체 시험), 타일셋 빌더, 레이어 6장 데이터 + 꼭짓점 격자, dual grid 조회, 시드 생성기, 청크 바닥 그리기와 편집, world.tscn 자유 카메라, 테스트, 스크린샷 | **끝** |
| G2 캐릭터 + 빛 | 캐릭터 리그(5클래스, 걷기·idle 4방향, 서쪽 반전, 표식 레이어 오프셋 + 기준점 표, 발 기준 y 정렬), 이동·충돌(맵 경계, 제단), 플레이어 카메라, 제단 놓기 + 저녁 어둠 + 안전 반경 빛(바닥 디더 + 캐릭터 hard), `is_in_safe_zone()` = 빛, unshaded 불꽃, main.tscn(내 캐릭터 + 더미 넷), 테스트, 창 그림 검사, 스크린샷 | **끝** |
| G3 네트워크 | 전송 계층(ENet + Steam 자리, 시그널로 결과), 호스트·참가, 호스트 권한 이동(입력 프레임 → 호스트 검사·시뮬레이션 → 바뀔 때만 20Hz 묶음 + 키프레임) + 자기 캐릭터 예측·보정 + 남의 캐릭터 100ms 보간, 호스트가 세는 인원 상한 9 + 빈 스폰 자리 다시 쓰기, 클래스, 늦은 참가(시드 + 편집 기록 + 해시 확인), 다중 프로세스 테스트(2인·4인·지연/손실·호스트 잃음, 선택 10프로세스), 대역폭, 두 창·두 기기 명령 | **끝** |

G1에서 확인하지 않은 것: ARM64 exe 실행(이 기기는 x86_64), 실제 창의 프레임 시간, 내보낸 exe의 창 스크린샷(G2에서 확인함), 에디터(`-e`)로 열어 보기(사람이 한다).

G3에서 확인하지 않은 것: **두 기기**(데스크탑 + 서피스, Tailscale)로 새 네트워크 코드를 돌려 보기(사람이 한다. 위 "둘이 하기"), ARM64 exe 실행(이 기기는 x86_64, 내보내기만 함), 실제 인터넷·Steam 릴레이(Steam은 M1 밖), 진짜 지연·손실(자동 시험은 localhost + 클라이언트 쪽 흉내뿐, 호스트 쪽 지연은 흉내 내지 않았다), 사람이 키보드로 두 창에서 걸어 보기(테스트는 봇으로만), 호스트를 처음 열 때 Windows 방화벽 창(이 세션에서는 아무 창도 확인하지 못했다), 다른 아키텍처끼리 월드 해시가 같은지(welcome이 해시를 비교해서 다르면 종료 코드 5로 드러난다), 창 모드의 실제 프레임 시간.

G2에서 확인하지 않은 것: 사람이 키보드로 직접 걸어 보기(테스트는 입력 액션을 눌러 물리 틱으로 확인했다), 실제 창의 프레임 시간, ARM64 exe 실행, 에디터로 열어 보기, idle 기준점을 사람이 보고 고정하기, 화면 캡처는 창 안 렌더 타깃이고 모니터에 나간 그림(스왑체인)은 아니다(스파이크에서 사람이 따로 확인한 방식).
