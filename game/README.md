# Evensong 게임 프로젝트 (Godot 4.7.2)

수직 슬라이스를 만드는 진짜 게임 폴더다 (`prototypes/engine-spike/`는 버리는 시험이고, 여기 코드는 새로 짰다).
지금은 **M1 "첫 단계: 이동 · 타일 · 제단 빛 · 2인 접속"**의 세 단계 G1(뼈대 + 월드), G2(캐릭터 + 빛), G3(2인 네트워크)가 모두 들어 있고, 검증에서 나온 지적을 반영했다. 그 위에 H1(다지기: 늦은 참가 = 월드 스냅샷, 호스트가 정하는 바라보기, 호스트 멈춤 뒤 입력 따라잡기, 테스트 기반, 제단 옆 겹침, 내 캐릭터를 틱 사이에 그리기, `session.gd` 나누기)을 더했고, H1 검토 지적을 반영했다(H-fix: 실제 세션에서 듣지 않던 호스트 멈춤 따라잡기를 고침, 테스트 포트 확인을 IPv4까지, 세션 시험 `stall` 추가 등. [검토 반영 (H-fix)](#검토-반영-h-fix-2026-10-22)). 단계 상태와 알려진 문제는 [맨 아래](#m1-범위와-단계-상태).
그 위에 **M2a "아이템 · 핫바 · 마우스 조준 · 몸 동작"**(혼자 할 때 먼저)을 더했다: 타입 있는 아이템 표(도구 6 · 재료 1 · 채집물 15), 플레이어마다 인벤토리 + 핫바, 마우스 조준(바라보기와 목표 칸, 칸 표시), 도구를 들고 좌클릭하면 그 도구의 몸 동작(64칸 동작 시트를 발에 맞춰, 손에 든 표식은 숨기고 나머지 표식은 레이어로, ● R25~R27), 최소 HUD(핫바 줄, Tab 인벤토리). 동작은 아직 월드를 바꾸지 않고 목표 칸만 알린다. [아이템 · 조준 · 동작 (M2a)](#아이템--조준--동작-m2a).
그 위에 **M2b "네트워크 + 월드"**를 더했다: M2a가 더한 것을 모두 호스트가 정한다(클라이언트는 입력 프레임에 바라보기(조준)와 요청 하나(사용 · 줍기 · 핫바 고르기 · 디버그 버리기 · 디버그 주기)를 실어 보내고, 호스트가 그 프레임의 자리에서 검사하고 적용한다. 몸 동작과 든 아이템은 상태 묶음에, 월드 변화는 번호 붙은 편집으로, 인벤토리는 호스트에 있고 주인에게만 간다. 자기 동작 시작은 이동처럼 예측한다). 지상에 시드로 채집물(야생 약초 3종 · 버섯 · 돌)을 흩고 F로 줍는다(약초사가 캐면 상급 ● §3.4), 땅에 떨어진 아이템(디버그 F7로 버리기, F로 줍기), 늦은 참가 스냅샷에 채집물과 드롭이 들어간다. [M2b: 네트워크 + 월드](#m2b-네트워크--월드). M2b 검토 지적을 반영했다(M2-fix: 타일 선 위의 발 칸, 고르기 바로잡기, 사용의 바라보기, 동작 중 표시, 클라이언트 F7·`--give`, 빠진 시험. [검토 반영 (M2-fix)](#검토-반영-m2-fix-2026-10-22)).
그 위에 **M3a "지도 · 첫 던전 · 채굴 · 횃불"**(혼자 할 때 먼저)을 더했다: 지도 번호(지상 0, 첫 던전 1)로 지도마다 WorldData와 GameWorld를 따로 두고 플레이어는 늘 한 지도에 있다. 시드로 만드는 던전(방·통로·부서지는 벽·구리/철 광맥·기반암 테두리·이단의 제단 자리·출구 계단, 04-env 절벽 타일셋을 dual grid로, 벽 앞면 24px), 지상의 던전 입구(F로 내려가고, 던전의 계단에서 F로 입구 옆으로 올라온다), 벽 충돌(벽과 그 앞면 칸), 채굴(● R11: 누구나 1×1·느리게·경도 상한, 광부 3×3·빠르게·상위 경도. 칠 때마다 쌓이는 타격, 금 3단계, 깨지면 돌·광석이 인벤토리로, 다 차면 그 칸에 드롭), 어두운 던전과 횃불(디버그로 받아 바닥 칸에 놓는 빛, 벽 횃불 장식). 세션은 지상만이다(입구는 호스트가 "dungeon offline only"로 거부, 세션 흐름은 M2b 그대로). [M3a: 지도 · 던전 · 채굴 · 횃불](#m3a-지도--던전--채굴--횃불).
그 위에 **M3b "세션의 지도"**를 더했다: M3a가 혼자 할 때 더한 것(지도 둘, 던전, 채굴, 횃불, 그 드롭)을 세션에서 모두 호스트가 정한다. 플레이어마다 지도 번호가 호스트 상태이고, 입구·계단의 F는 요청(TRAVEL)이며 호스트가 손 닿는지 보고 그 플레이어를 다른 지도의 도착점으로 옮긴다. **클라이언트는 자기가 있는 지도 하나만 갖는다**: 지도에 들어갈 때 그 지도를 늦은 참가와 같은 스냅샷 길로 받고(조각 → 지도 들어옴 메시지 → 그동안의 편집), 그 뒤로는 그 지도의 번호 붙은 편집만 받는다. 상태 묶음의 상태마다 지도 번호가 있어 자기 지도의 플레이어만 그린다. 타일을 겨누는 요청은 겨눈 지도를 함께 보내고 호스트가 다른 지도면 거부한다. 전송 형식 버전 4. [M3b: 세션의 지도](#m3b-세션의-지도).

기준 문서: `docs/game-concept.md` §2 §3 §7 §9.3 §11 §12 §13, `docs/gameplay-design.md` §1 §2.1 §3.0 §3.1 §3.2 §3.4 §3.8 §5, `docs/concept-art-brief.md` §4 §5.6 §5.7, `assets/concept/03-pixel/prompts.md`(8~12차, 몸 동작), `assets/concept/04-env/prompts.md`("본 제작", 채집물, M3a: 던전 바닥↔벽 타일, 광맥, 벽 금, 던전 입구, 이단의 제단, 소품).
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

- 출력: 첫 줄 `EVENSONG_TESTS start: 13 file(s) in res://tests, ports 24621-24640`(이 실행이 쓰는 테스트 포트 묶음, 아래 "테스트 포트"), 파일마다 `PASS test_x.gd (n checks, ms)` 또는 `FAIL ...`과 실패 한 줄씩(`  - `), 측정값(`  * `), 경고(`  ! `). 끝에 `EVENSONG_TESTS done: ...`
- 종료 코드: 모두 통과 0, 하나라도 실패 1 (불러오기 실패·시간 초과·테스트 파일 없음·시작 중 오류·마지막 파일 뒤 오류도 1)
- 통과하는 실행에도 오류 묶음이 **8개** 찍힌다. 모두 테스트가 `allow_error()`로 미리 알리고 일부러 낸 것이다 (각 묶음 아래 `at:`·backtrace 줄이 붙는다):
  - `ERROR: Character: unknown class 'wizard'` 1개: `test_actors.gd`가 모르는 클래스 이름을 거부하는지 확인
  - `ERROR: Character: 0 is not a body action` 1개 (M2a): `test_actions.gd`가 걷기를 몸 동작으로 보여 달라는 요청을 거부하는지 확인
  - `SCRIPT ERROR: Parse Error: ... (Warning treated as error.)` 5개: `test_core.gd`가 "경고를 오류로" 설정 5종이 실제로 컴파일을 막는지 확인
  - `ERROR: Couldn't create an ENet host.` 1개: `test_net.gd`가 같은 포트에 호스트를 하나 더 열어 실패가 시그널로 오는지 확인. 빈 포트 찾기는 이제 `UDPServer`로 해서(쓰는 포트면 오류 줄 없이 코드만 돌려준다) 포트가 막혀 있어도 이 줄이 늘지 않는다
  - 이 밖의 `ERROR`·`SCRIPT ERROR` 줄은 문제다. 러너가 실패로 세므로 어느 파일의 FAIL 아래(또는 `FAIL (startup)`, `FAIL (after the last file)` 아래)에 같은 내용이 나온다
  - `ERROR`로 grep하면 `  * child logs: 14 instances, ... lines scanned for ERROR:` 측정 줄도 걸린다. 오류가 아니다
- 자식 프로세스(러너 자체 시험, `test_net_session.gd`의 세션)의 오류는 화면에 찍히지 않는다. 테스트가 출력이나 로그를 받아서 검사한다

### 테스트 하나만

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=world < /dev/null      # test_world.gd
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=core,world < /dev/null
```

- 파일당 제한 시간(초, 기본 120): `-- --timeout=300`
- 러너 자체 시험: `-- --dir=res://tests/fixtures --prefix=case_ --timeout=2` (2개 PASS, 9개 FAIL, 종료 1이 정상)와 `-- --dir=res://tests/fixtures --prefix=late_ --timeout=2` (파일은 PASS, 그 뒤 `FAIL (after the last file)`, 종료 1이 정상). `test_core.gd`가 자식 프로세스로 둘 다 돌려 확인한다. 자식은 `OS.create_process` + `--log-file`로 띄우고 0.05초마다 살아 있는지 보다가 마감(60초)이 지나면 죽이고 실패로 센다(예전 `OS.execute`는 자식이 멈추면 테스트 전체가 같이 멈췄다). 마감이 실제로 듣는지는 30초 걸릴 자식(`case_timeout.gd`를 `--timeout=60`으로)을 2초 마감으로 띄워 죽는 것으로 매번 확인한다

### 테스트 포트

네트워크 테스트는 UDP 포트 20개 한 묶음을 쓴다. 러너가 실행마다 한 번 정해서 넘겨준다(테스트 파일은 `Runner.port_first`/`port_last`, 자식 프로세스는 `--host=<포트>` 같은 명시 포트나 `--ports-from-parent=<첫 포트>`).

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --port-base=25000 < /dev/null   # 25000-25019
EVENSONG_TEST_PORT_BASE=25100 timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd < /dev/null
```

- 기본은 24621-24640. 그 묶음을 다른 실행이 잡고 있으면 위로 20씩(24641, 24661, ... 10묶음까지) 옮긴다. `--port-base`나 환경 변수로 준 묶음이 잡혀 있으면 옮기지 않고 `FAIL (startup)`으로 끝난다. 이때 테스트 파일은 하나도 돌리지 않는다(첫 줄이 `..., no test ports claimed`, 끝 줄 `EVENSONG_TESTS done: 0 passed, 0 failed ... no file ran: test ports not claimed`, 종료 1. H-fix 전에는 쥐지 않은 기본 묶음으로 모든 파일을 돌렸다)
- "잡혀 있다" = 그 묶음의 잠금(TCP `127.0.0.1:<첫 포트>` 듣기)을 다른 러너가 쥐고 있거나, 묶음 안 UDP 포트 하나라도 누가 쓰고 있다. 러너는 잠금을 실행 내내 쥐고 있다. 듣기는 운영체제가 하나만 받아 주는 일이라 두 러너가 같은 때 시작해도 한쪽만 잡고, 러너가 끝나거나 죽으면 운영체제가 푼다. 그래서 두 작업 트리에서 테스트를 동시에 돌려도 서로 다른 묶음을 쓴다
- UDP 포트는 주소 세 개로 확인한다: `*`(IPv6 이중 스택, 호스트가 듣는 주소), `0.0.0.0`, `127.0.0.1` (`Runner.PROBE_ADDRESSES`). Windows는 이중 스택 소켓이 다른 프로그램의 IPv4 소켓과 같은 포트를 같이 쓰게 해 주고, 그러면 테스트 클라이언트가 127.0.0.1로 보낸 것은 그 프로그램이 받는다. 이 데스크탑에서 재 보니 `0.0.0.0`을 잡은 소켓은 `0.0.0.0` 확인만, `127.0.0.1`을 잡은 소켓은 `127.0.0.1` 확인만 실패했다(`*` 확인은 둘 다 통과). H-fix 전에는 `*` 하나로만 확인해서 IPv4만 잡은 프로그램이 있는 포트를 비었다고 보고 세션 테스트가 120초 뒤 실패했다
- 남은 경합: 러너가 아닌 다른 프로그램(또는 이 잠금이 없는 예전 러너)이 묶음을 확인한 뒤에 그 안의 포트를 잡으면 막을 수 없다. 그러면 세션 테스트가 그 포트에 호스트를 못 열고 실패한다(빈 포트는 세션마다 다시 찾으므로 묶음 안 다른 포트로 비켜 가는 경우가 많다)

### 네트워크 테스트

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net < /dev/null           # 한 프로세스 안 (약 2초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session < /dev/null   # 실제 세션 (약 75초, M3b)
timeout 400 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-full --timeout=300 < /dev/null   # + 10프로세스 상한 시험
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-exe=build/evensong.console.exe < /dev/null   # 자식을 내보낸 exe로
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-sessions=cave,four < /dev/null   # 그 세션만 (M3b)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_maps < /dev/null      # M3b 단위 시험 (약 4초)
```

- `test_net.gd`: 전송 형식(왕복, 잘린 패킷 전부, 무작위 바이트 2,000개), 인원 상한(진짜 9명: 10번째 거부, 빈 자리 다시 쓰기), 호스트 입력 검사(순서·중복·속도 제한·고르게 적용·따라잡기는 틱당 4개까지, 실제 시간 시계 `InputGate.ticks_between`과 그 시계로 두 배 빨리 보내는 클라이언트, 호스트가 1초 멈췄다 따라잡기를 두 순서로: 물리 틱 안에서 멈춤 / 틱 밖에서 멈춰 Godot이 따라잡기 틱 뒤에 네트워크를 읽음, 멈춤 크레딧이 쌓이지 않고 사라짐), 호스트가 바라보기를 방향에서 정하기(클라이언트 예측과 프레임마다 같음), 호스트의 묶음/키프레임/조용함 판단, 클라이언트 예측을 지연·손실 있는 가짜 연결로 호스트와 맞춰 보기(지연 0·5·9틱, 손실 0·25%, 위치와 바라보기), 보간, 월드 스냅샷(여섯 레이어 왕복, 조각 크기·순서·틱당 개수, 받는 쪽 검사: 빠진 조각·바뀐 바이트·다른 월드·크기, 크기 상한 `MAX_SIDE`·`MAX_PACKED`, 크기·md5가 맞는 무작위 조각도 풀기 단계에서 거부), 스냅샷 뒤의 편집 기록, 스냅샷 크기와 참가 시간(128×96, 512×512 합성, 512×512 무작위), 봇 스크립트, CLI, RPC 표(누가 부를 수 있는지·채널·신뢰성), 전송(ENet 호스트+참가를 한 프로세스에서, 양쪽 연결의 패킷 조절 설정, Steam은 신호로 unavailable)
- `test_world_items.gd` (M2b): 채집물 표와 등급 규칙(● §3.4), 줍기·버리기·사용·주기 규칙(손 닿는 칸, 발이 타일 선 위일 때의 발 칸, 가득 찬 인벤토리, 드롭 일부만 줍기, 주기 개수 0 = `bad count`, 클라이언트의 300개 주기 = 요청 255 + 45), 호스트 요청 검사(진짜 `NetSession` + `SessionHost.run_frame`, 전송 없이: 손 닿지 않음, 틀린 칸, 빈 칸, 도구 아님, 동작 중, 마구 보내기 = rate, 클라이언트 주기·버리기 끔, 고르기는 예산 밖, 거부된 고르기는 인벤토리를 돌려보냄, 바라보기와 다른 쪽 칸의 사용은 칸 쪽을 봄), 같은 틱에 둘이 같은 것을 줍기(채집물·드롭 모두 정확히 하나, 손으로 부른 `run_frame`과 `SessionHost.tick` 자체: 게이트에 자리 2를 먼저 넣어도 자리 1이 가짐), 드롭의 월드 해시·스냅샷(왕복, 거부 9가지, `MAX_DROPS`에서 버리기 거부 + 그 월드의 스냅샷 왕복)·편집 기록(스냅샷 + 뒤 편집 = 호스트 월드), 그림(ItemView) = 데이터, 인벤토리 전송 형식, 몸 동작 예측을 지연·손실 있는 가짜 연결로 호스트 `run_frame`과 맞춰 보기(오차·동작 보정 0, 호스트가 거부한 사용은 보정), 서서 조준만 하는 클라이언트(바라보기가 바뀌는 틱만 프레임을 기록하고 호스트도 같은 쪽을 봄), 호스트의 인벤토리 위에 아직 처리 안 된 고르기를 다시 얹기(`SessionClient.on_inventory`: 프레임에 실린 것·아직 줄에 있는 것, ack가 덮으면 호스트 것), 남의 동작 보간, 혼자 할 때 `main.tscn`에서 F 줍기 · F7 버리기
- `test_net_maps.gd` (M3b): 지도 들어옴 메시지(왕복, 잘린 것 전부, 없는 지도, 다른 지도의 자기 상태), 지도를 적은 편집, 스냅샷 머리말의 지도 번호(기대한 지도가 아니면 받는 쪽이 거부), 두 지도를 섞지 않는 보간, 봇 `waitmap`. 호스트 요청 검사(진짜 `NetSession` + `SessionHost`, 전송 없이): 멀리서·길 아닌 칸·맵 밖 TRAVEL, 마구 보내는 TRAVEL(`rate`), 지도를 받는 중의 TRAVEL(`still loading`), 입구에 PICKUP(`a way to another map`), 다른 지도를 겨눈 사용·횃불·줍기·버리기·TRAVEL(`wrong map`, 예산을 쓰지 않음), 멀리 있는 칸을 캐는 악의 클라이언트(2·3·40칸, 맵 밖), 휘두르는 동안 매 프레임 사용(`busy`), 기반암 테두리와 출구 위 기반암(공용·광부 모두 `too hard`, 편집 없음). 같은 틱 채굴 경주(`SessionHost.tick`, 자리 2를 먼저 넣음): 한 번 남은 칸(자리 1이 깨고 돌, 자리 2는 `no wall`), 두 번 남은 칸(둘 다 맞고 자리 2가 깨고 돌), 광부 둘의 3×3 겹침(겹친 칸마다 한 번씩만 깨지고 아이템은 깬 쪽 하나). 잡은 전송으로 전체 흐름(`CaptureSession`이 호스트의 진짜 메시지를 잡아 진짜 `SessionClient`에 채널 순서대로): 지상의 A는 던전 편집을 하나도 안 받고 아래의 호스트를 그리지 않음 → A가 내려가 호스트의 던전 그대로(금·횃불·드롭, 동굴 그림 해시 같음) → 실시간 편집 → B가 둘 다 아래일 때 늦게 참가(지상에서 아무도 안 그림) → B가 1바이트 조각으로 내려가는 동안 호스트가 캔 편집은 B의 지도 들어옴 뒤에 → 지상 편집이 B에게 오면 잘못된 메시지 → A가 올라감(지상 = 호스트, 떠난 던전 = 호스트) → 위치·지도 해시 같음. 예측: 호스트가 이미 깬 벽을 클라이언트가 아직 모를 때(편집이 0·30·90틱 늦게) 그동안만 보정되고 편집이 온 뒤로는 없음, 같은 마지막 위치. 지도 전환: 다른 지도의 상태는 맞추지 않음, 전환은 호스트 상태에서 그 뒤 프레임을 새 지도에서 다시 돌림, 옛 지도를 겨눈 사용은 다시 돌릴 때 동작을 시작하지 않음
- `test_net_session.gd`: 이 프로젝트를 헤드리스 프로세스 여러 개(`main.tscn` + `--host`/`--join` + `--bot`)로 띄워 localhost ENet으로 실제 세션을 돌린다. 세션마다 모든 인스턴스가 결과 JSON을 쓰고 호스트와 비교한다 (아래 "네트워크 (G3)"의 "테스트가 확인하는 것")
  - `pair`: 호스트 + 클라이언트 1이 같이 걷고 멈춤 → (M2b) 호스트가 곡괭이를 3번 휘두르고 야생 약초(47,51)까지 걸어가 줍고(c1은 그것이 사라지는 편집을 받는다) 돌 5개를 그 칸에 버림, c1은 검을 달라고 요청해(주기 요청) 핫바 세 칸을 연달아 골라 검으로 돌아오고(매 프레임 고르기 3번, 모두 처리) 2번 휘두른 뒤 서서 남쪽을 조준만 한다(바라보기만 바뀌는 프레임: 호스트·c2도 c1이 남쪽을 보는지): 서로의 든 아이템과 동작을 본다 → 호스트가 월드 편집 → 늦은 참가자. 늦은 참가자는 `--test-perturb-generator`로 자기 생성기가 다른 월드를 만들게 해서 띄운다(다른 아키텍처 흉내): 그래도 호스트의 월드 해시·바닥 그림으로 끝나야 하고, 진단은 `generator=differs`. (M2b) 이 약초사는 주운 약초가 빠지고 돌 드롭이 있는 스냅샷을 받아(welcome `gatherables=73 drops=1`) 그 돌을 줍고, 약초 하나를 더 캐서 상급을 받는다. 옆에서 아무도 없는 포트에 참가 → 실패해야 함
  - `four`: 호스트 + 클라이언트 3 (상한을 `--max-players=4`로 낮춤) → 하나가 나감 → 늦은 참가자가 그 자리를 받음 → 다섯 번째는 "full"로 거부. (M2b) c1이 나가기 전에 호스트가 돌 5개를 (63,53)에 버리고, 세 클라이언트가 그 칸의 다른 세 옆에 서서 버리기 전부터 1.5초 동안 매 틱 F를 누른다(경주 + 요청 마구 보내기): 정확히 하나가 갖고, 나머지는 "rate"·"nothing there"로 거부된다. 이 호스트는 `--test-snapshot-chunk-bytes=32`로 스냅샷을 32바이트 조각 18개(M2b 월드 약 563B. M1에서는 11개·두 틱)로 잘라 세 틱에 걸쳐 보낸다(보통 월드는 1KB 조각 하나라 여러 조각·여러 틱 길을 실제 세션에서 지나게 하려고). 세 틱(= ⌈18/8⌉)인지는 호스트가 센 조각 보낸 틱 수(결과 JSON `streams`)로 확인한다
  - `lag`: 클라이언트 쪽에서 왕복 120ms 지연 + 15% 손실을 흉내 (`--net-lag`, `--net-loss`). 옆에서 `drop`: 호스트가 사라졌을 때 사람처럼 띄운 클라이언트(`--net-out` 없음)가 혼자 계속하는지
  - `stall` (H-fix): 호스트 + 걷는 클라이언트 1. 호스트가 봇 `stall:700`으로 물리 틱 밖(`_process`)에서 0.7초 멈춘다(긴 프레임 흉내). 그 뒤 클라이언트 입력 대기열이 따라잡아야 한다(속도 제한에 걸린 틱 ≤ 2, 멈춤 크레딧을 썼음). 이어서 호스트가 4틱마다 월드를 편집하는(60번) 동안 늦은 참가자 c2가 1바이트 조각 341~345개(43~44틱, M2b부터 채집물 때문에 약 567개·71틱)로 월드를 받는다: 받는 동안 생긴 편집이 welcome 뒤에 가야 하고(`catch_up_edits` > 0) c2의 월드·편집 수가 호스트와 같아야 한다. (M2b) 편집 10번마다 호스트가 돌 하나를 버려서(드롭 6개) 받는 도중의 드롭도 welcome 뒤 편집으로 가고, c2의 드롭 목록이 호스트와 같아야 한다
  - `cave` (M3b, 시드 1): 호스트(광부) + c1(성직자) + 늦은 c2(약초사). 호스트가 입구로 내려가 횃불을 놓고 도착 방 서쪽 바위를 3×3 한 번 쳐서 금이 가게 한다. 그동안 c1은 지상: 그 편집을 하나도 받지 않고 호스트를 그리지 않는다(표시 파일 `c1.alone`). c1이 내려가면 지도 스냅샷에 금 6칸과 횃불이 있다. 둘이 같이 캔다: 호스트가 3×3을 깨고 돌을 버리고, c1이 방 동쪽 바위를 4번 쳐서 금 2단계를 내고 횃불을 놓는다. 서로의 편집이 실시간으로 간다. c2가 둘 다 아래일 때 참가해 지상에서 아무도 그리지 않고(`c2.alone`), c1이 계단으로 올라오는 것을 보고(`c2.sees`), 내려가서 그때까지의 깸·금·횃불 둘·드롭을 스냅샷으로 받는다(`c2.down`: 호스트는 그리고 c1은 안 그림). 봇은 `waitmap`으로 서로를 기다린다. 끝에 모든 지도의 해시를 비교한다: c1의 지상, c2의 던전, c1이 떠날 때의 던전(호스트 로그의 같은 편집 번호 뒤 해시)
  - `four`에 더한 것 (M3b): M2b 경주 뒤 c2(아처)와 c3(성직자)가 곡괭이(`--give`)를 들고 내려가(32바이트 조각이라 던전이 10조각·2틱) 같은 바위를 두 쪽에서(c3은 그 앞면을) 친다: 정확히 한 번 깨지고, 돌은 깬 쪽 하나에. c4는 둘이 아래일 때 늦게 참가해 둘을 그리지 않는다
  - `--net-full`(선택): 진짜 상한 9명 = 호스트 + 클라이언트 8, 열 번째 거부. 프로세스 10개라 기본에서는 뺐다
- 자식 프로세스 로그(`--log-file`)에 `ERROR:` 줄이 하나라도 있으면 실패. 끝까지 남은 프로세스는 죽이고 실패. 통과하면 실행 폴더(`%APPDATA%/Godot/app_userdata/Evensong/net_test/run_*`)를 지우고, 실패하거나 `--net-keep`이면 남긴다 (로그·결과 JSON·표시 파일)
- 포트는 러너의 테스트 포트 묶음(위 "테스트 포트") 안에서 세션마다 빈 것을 찾는다

### 타일셋 다시 만들기

`art/tiles/`의 PNG·JSON이나 `world/tileset_builder.gd`를 바꿨을 때만. 같은 입력이면 같은 파일이 나온다(두 번 만들어 md5 같음을 확인했다).

```bash
timeout 120 "$GODOT" --headless --path game --script res://tools/build_tileset.gd < /dev/null
```

- 출력 `EVENSONG_TILESET res://world/tilesets/surface.tres error=0 sources=11 tiles=40 exact_keys=31 md5=...`와 (M3a) `EVENSONG_TILESET res://world/tilesets/dungeon.tres error=0 sources=2 tiles=30 exact_keys=21 md5=...`
- 결과 `world/tilesets/surface.tres`, `world/tilesets/dungeon.tres`를 커밋한다. 커밋된 파일이 새로 만든 것과 다르면 `test_world.gd`(지상)·`test_dungeon.gd`(던전)가 실패한다 (`ext_resource` id는 저장 위치에 따라 달라서 경로로 바꿔 비교한다)

### 캐릭터 기준점 표 다시 만들기

`art/chars/base_body_v02_*.png`나 `actors/rig_measure.gd`(재는 규칙)를 바꿨을 때만. 같은 시트면 같은 파일이 나온다.

```bash
timeout 120 "$GODOT" --headless --path game --script res://tools/build_rig_anchors.gd < /dev/null
```

- 애니메이션(걷기·idle + 몸 동작 8개, M2a)·방향마다 `EVENSONG_ANCHORS walk south torso=[...] head=[...]` 한 줄(30줄), 끝에 `EVENSONG_ANCHORS saved res://actors/rig_anchors.gd error=0 md5=...`. 이 데스크탑 약 2.6초
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
- 마지막 줄은 `EVENSONG_SMOKE ok exported=true ... gatherables=74 dungeon=64x48 hash=009e7147ad79 ores=47 dungeon_seeds=3ec443b95c4c dungeon_map=313B items=25 actions=8 ... net=v4 checks=250`을 찍고 0으로 끝나야 한다. 아래 "스모크" 참조

### 실행

```bash
"$GODOT" --path game                                   # main.tscn: 월드 + 제단 + 내 캐릭터 + 다른 네 클래스
"$GODOT" --path game -- --class=cleric --no-evening    # 성직자로, 저녁 어둠 끈 채 시작
"$GODOT" --path game res://scenes/world.tscn -- --seed=7 --overlay   # 맵 보기 (자유 카메라, 캐릭터 없음)
game/build/evensong.exe -- --class=miner               # 내보낸 빌드
timeout 60 "$GODOT" --headless --path game --quit-after 120 < /dev/null   # 그리지 않고 120프레임 (오류 확인용)
"$GODOT" --path game -- --class=miner --give=pickaxe,hoe,sickle,watering_can,sword,bow,wild_healing:12,stone_a:30   # M2a: 도구를 들고 시작
"$GODOT" --path game -- --class=miner --give=pickaxe,torch:10 --start-map=dungeon   # M3a: 던전 도착점에서, 곡괭이(1번)와 횃불(2번)
```

- `main.tscn`(실행 장면): WASD 또는 방향키로 8방향 걷기, 카메라는 내 캐릭터 가운데(맵 밖은 안 보이게 가장자리에서 멈춤). 제단 둘레에 나머지 네 클래스가 제단을 보고 서 있다(움직이지 않는 더미, 표식 다섯 가지가 한 화면에 보이게)
- F4로 저녁 어둠 + 제단 빛 켜고 끄기, F3으로 디버그 선(맵 테두리, 청크 경계, 제단 자리, 임시 안전 반경) 켜고 끄기
- M2a (키는 모두 임시값): 마우스를 움직이면 1초 동안 캐릭터가 마우스 쪽을 보고 발 옆의 목표 칸에 금빛 모서리 표시가 뜬다. 좌클릭 = 고른 핫바 칸의 도구 사용(그 도구의 몸 동작, 누르고 있으면 반복), Q / E = 핫바 왼쪽 / 오른쪽, Tab = 인벤토리 칸 전부 보기. 인벤토리는 비어서 시작한다: **F5**(디버그)가 도구 6개와 채집물·재료 묶음을 주고, `--give=`로도 준다. **F6**(디버그)은 들고 있는 것과 상관없이 몸 동작 8개를 차례로 한다(아이템이 없는 마법·던지기도 여기서 본다). 콘솔에 `EVENSONG_ACTION start item=pickaxe action=pickaxe facing=east target=61,48`
- M2b (키는 모두 임시값): **F** = 목표 칸의 채집물(없으면 드롭)을 줍기, **F7**(디버그) = 고른 칸의 묶음을 목표 칸에 버리기. 혼자 할 때는 바로, 세션에서는 요청으로 간다. 콘솔에 `EVENSONG_ITEMS pickup item=wild_buff count=1 grade=common at=47,51`. 채집물은 제단 빛 밖(가장 가까운 것이 약 13타일)에 있다
- M3a (키는 M2 그대로, 혼자 할 때): 지상 제단 동쪽(시드 1: 제단 가운데에서 약 10타일, 처음 화면 오른쪽 끝)의 **던전 입구**를 조준하고 **F** = 던전 도착점으로 내려간다. 던전 도착점 바로 북쪽의 **계단**을 조준하고 F = 입구 바로 남쪽으로 올라온다. 곡괭이를 들고 벽(또는 벽 앞면)을 조준하고 좌클릭(누르고 있으면 반복) = 채굴, 휘두르기 4번째 프레임에 맞는다. 광부는 3×3. 횃불(F5 묶음의 7번째 칸 = 핫바 7번, `--give=torch:<수>`)을 고르고 좌클릭 = 목표 칸(빈 바닥)에 놓는다(누르고 있어도 한 번). F4는 던전에서 어둠과 횃불 빛을 같이 끈다. 콘솔에 `EVENSONG_MAP travel to=dungeon feet=608,252`, `EVENSONG_MINE at=46,19 class=miner hit=9 broken=5 gained={ &"stone_a": 5 } ...`, `EVENSONG_ITEMS place item=torch ...`
- M3b: 세션에서도 같다(입구·계단 F로 오가기, 채굴, 횃불). 모두 호스트에게 가는 요청이고 호스트가 정한다(아래 "M3b: 세션의 지도", "두 기기에서 M3 해 보기")
- M3a: F5 디버그 묶음은 이제 24칸을 다 채운다(도구 6 + 횃불 10 + M2 묶음). 그래서 F5 뒤에 캔 돌은 돌 a 묶음에 쌓이지만 광석은 들어갈 칸이 없어 그 칸에 드롭으로 떨어진다(가득 찬 인벤토리 규칙). 채굴을 해 보려면 `--give=pickaxe,torch:10`이 낫다
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
- 늦은 참가 보기: 창 1을 `-- --host --bot="wait:180;edit:62,50,soil"`로 띄우면(봇이 키 대신 움직인다) 3초 뒤 제단 아래 풀 한 칸이 흙이 된다. 그 뒤에 창 2를 띄우면 흙이 된 칸이 보인다. 참가자는 월드를 시드로 다시 만들지 않고 **호스트에게서 받는다**(아래 "네트워크"의 늦은 참가). 콘솔에 `welcome ... world_bytes=341 raw=73749 chunks=1 ... generator=match`
- 셋 이상: 창 3, 4 ... 를 같은 `--join`으로. 9명까지, 열 번째는 "full"로 거부된다 (콘솔에 `EVENSONG_NET client ended reason="refused: full" code=3`)
- 호스트 창을 닫으면 클라이언트는 다른 사람을 지우고 혼자 계속 걷는다 (콘솔에 `lost the host`, `offline playing on alone`). M2b: 그때부터 마지막으로 받은 인벤토리가 자기 것이 되고 줍기·버리기는 혼자 할 때처럼 바로 된다
- M2b: 두 창 모두 마우스로 조준하고 좌클릭으로 들고 있는 도구를 휘두르고(상대 창에 그 동작이 보인다), F로 줍고, Q/E로 고른다. 도구는 F5(디버그 묶음)로 받는다: 에디터로 띄운 호스트(디버그 빌드)는 클라이언트의 주기·버리기(F7) 요청을 받아 준다. 내보낸 exe 호스트는 `--test-allow-give`를 붙여야 한다(없으면 `give off`·`drop off`로 거부)

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
- **월드는 호스트가 보낸다** (H1): 서피스(ARM64)는 자기 생성기로 월드를 만들지 않고 데스크탑이 보낸 월드(레이어 6장, zstd로 압축, 조각으로)를 받아 그린다. 그래서 ARM64의 float 노이즈가 데스크탑과 달라도 참가는 된다. 콘솔의 `welcome ... generator=match`/`generator=differs (local ..., host ...)`가 서피스 생성기가 같은 월드를 만들었을지를 알려 주는 진단이다(실패 아님). 서피스에서 `evensong.console.exe --headless -- --smoke`의 `seed 1 world hash` 결과도 같은 것을 말해 준다
- 종료 코드 5는 이제 "받은 월드가 검사를 통과하지 못함"(조각 수·크기·md5·월드 해시)이다. 정상 연결에서는 나오지 않는다
- H-fix부터 ENet 패킷 조절을 끈다(아래 "네트워크"). localhost에서만 재 봤으니, 두 기기에서 서로의 캐릭터가 걷는 동안 몇 초씩 멈췄다 튀지 않는지 본다
- 스파이크(2026-10-21)에서 사람이 느낀 "서피스 쪽 자기 캐릭터 반응이 조금 늦음"은 이제 예측으로 푼다. 이번에도 사람이 두 기기로 다시 해 보지 않았다 (아래 "G3에서 확인하지 않은 것")

두 기기에서 M2b 해 보기 (사람이 할 것):

```bash
# 데스크탑: 내보낸 뒤 (내보낸 exe는 release라 클라이언트의 F5·F7을 받으려면 --test-allow-give)
game/build/evensong.console.exe -- --host --test-allow-give --class=miner
# 서피스:
evensong.console.exe -- --join=<데스크탑 주소> --class=herbalist
```

1. 둘 다 F5로 디버그 묶음을 받는다(핫바 1번 = 곡괭이). 서피스 콘솔에 오류가 없고 핫바가 차는지(호스트가 보낸 인벤토리)
2. 마우스를 움직여 목표 칸 표시가 마우스 쪽 발 옆 칸에 뜨는지(스폰 자리처럼 발이 타일 선 위에 있을 때도 동쪽·서쪽 조준이 발과 같은 줄인지, M2-fix), 좌클릭을 누르고 있으면 곡괭이를 계속 휘두르는지, 휘두르는 동안 마우스를 돌려도 표시가 치는 칸에 머무는지. **상대 화면에서도** 그 사람이 그쪽을 보고 휘두르는지, 끊기지 않는지. 서서 마우스만 돌렸을 때 상대 화면에서도 그쪽을 보는지
3. Q/E로 검·활·물뿌리개로 바꿔 휘둘러 본다: 상대 화면의 동작이 바뀌는지. 자기 화면에서 클릭과 동작 사이가 늦지 않은지(예측). Q/E를 빠르게 여러 번 눌러도 핫바가 상대 화면의 든 아이템과 어긋나지 않는지
4. 제단 빛 밖으로 걸어가(시드 1에서 가장 가까운 채집물은 제단 북쪽 약 13타일 칸 (62,34)의 버섯, 야생 약초는 서쪽 칸 (47,51)·동북쪽 (77,39)) F로 줍는다: 내 인벤토리에 들어오고 **상대 화면에서도 사라지는지**. 약초사(서피스)가 야생 약초를 캐면 핫바 칸 왼쪽 위에 금빛 점(상급)이 있는지, 광부가 캐면 없는지(● §3.4)
5. F7로 고른 묶음을 버리고 상대가 F로 주울 수 있는지, 둘이 같은 드롭에 동시에 F를 누르면 한 사람만 갖는지
6. 그 상태에서 세 번째 창(또는 서피스를 닫고 다시 참가)을 띄우면 주운 채집물은 없고 드롭은 있는지. 다시 참가하면 인벤토리는 빈 것이 맞다(이어지지 않음, 임시값)
7. 이상하면 두 콘솔의 `EVENSONG_NET ... request_refused ...` 줄(거부 이유)과 `action`·`pickup` 줄을 남겨 둔다

두 기기에서 M3 해 보기 (사람이 할 것, M3b):

```bash
# 데스크탑: 내보낸 뒤 (내보낸 exe는 release라 클라이언트의 --give를 받으려면 --test-allow-give)
game/build/evensong.console.exe -- --host --test-allow-give --class=miner --give=pickaxe,torch:10
# 서피스: 먼저 생성기 비교, 그다음 참가
evensong.console.exe --headless -- --smoke      # dungeon=64x48 hash=009e7147ad79, dungeon_seeds=3ec443b95c4c 인지
evensong.console.exe -- --join=<데스크탑 주소> --class=cleric --give=pickaxe,torch:5
```

1. 둘 다 제단 동쪽 약 10타일의 던전 입구로 가서 입구를 조준하고 F: 내려가는지, 화면이 던전으로 바뀌기까지 걸리는 시간(왕복 + 지도 조각 하나), 바뀌는 순간 튀거나 멈칫하는지(서피스는 던전을 그리는 데 한 프레임이 길 수 있다)
2. 한 사람만 내려가 캔다: 지상에 남은 쪽 화면에 내려간 사람이 보이지 않는지. 그다음 지상 쪽이 내려가면 판 자리·금·놓은 횃불이 그대로 보이는지
3. 둘이 옆에서 캔다(곡괭이 = 핫바 1번, 횃불 = 2번): 상대의 금(앞면의 금이 잘 보인다)과 깨짐이 바로 보이는지, 같은 바위를 둘이 칠 때 한 번만 깨지고 돌이 한 사람에게만 가는지(데스크탑 콘솔 `mine slot=.. broken=1`)
4. 서피스(클라이언트) 쪽 휘두르기가 늦지 않은지(시작은 바로, 깨짐은 왕복 뒤), 데스크탑이 막 깬 자리로 서피스가 바로 걸어 들어갈 때 걸리거나 뒤로 당겨지는지(편집이 오기 전 잠깐만 그래야 한다)
5. 계단(도착점 바로 북쪽)으로 올라오기: 지상이 그대로인지, 그동안 상대가 지상에서 주운 것이 반영됐는지
6. 둘 다 던전에 있을 때 세 번째로 참가(또는 서피스를 닫고 다시 참가): 지상에 도착하고 던전의 사람은 안 보이는지, 내려가면 다 있는지
7. 이상하면 두 콘솔의 `travel`, `map entered`, `entered peer=`, `request_refused ... (wrong map|still loading|out of reach)`, `mine` 줄을 남겨 둔다

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
  - `shots/net_host.png`, `shots/net_client.png` (G3, H1에서 다시 찍음): 세션 하나의 두 창. 호스트(팔라딘)와 클라이언트(성직자)가 각자 자기 캐릭터 가운데 카메라로 같은 장면을 본다. 클라이언트의 월드는 호스트가 보낸 스냅샷이다(로그 `welcome ... world_bytes=342 chunks=1 ... generator=match`). 성직자는 서쪽으로 걸어 제단 동쪽 면에 붙어 섰고, 몸이 제단 그림 뒤로 들어가지 않는다(제단 옆 띠). 찍은 명령 (호스트는 찍은 뒤에도 `--keep-running`으로 남아 있어야 클라이언트 화면에 나온다):

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24639 --scale=2 --bot="move:1,1,40;wait:3000" --screenshot=shots/net_host.png --frames=420 --keep-running --net-timeout=14 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24639 --class=cleric --scale=2 --bot="move:-1,0,30;wait:3000" --screenshot=shots/net_client.png --frames=360 < /dev/null
```
- 더미의 idle 프레임은 찍는 순간에 따라 달라서 같은 명령도 픽셀까지 같지는 않다
- M2b 두 창 그림 `shots/m2b_host.png`, `shots/m2b_client.png`: 세션 하나의 두 화면. 호스트(팔라딘, 검)는 동쪽을, 클라이언트(광부, 곡괭이, 호스트에게 주기 요청으로 받음)는 서쪽을 조준하고 누르고 있어 계속 휘두른다. 두 화면 모두 두 사람이 각자의 도구를 든 동작으로 보인다(찍는 순간의 동작 프레임은 실행마다 다르다). 클라이언트는 찍고 나면 나가므로 호스트가 먼저 찍게 프레임 수를 맞췄다(처음에 호스트 420프레임으로 찍었더니 클라이언트가 이미 나가서 호스트 화면에 혼자였다). 찍은 명령 (봇이 마우스·클릭 대신, 호스트는 찍은 뒤에도 남아 있게):

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24638 --scale=2 --give=sword --bot="aim:24,0;use:3000" --screenshot=shots/m2b_host.png --frames=330 --keep-running --net-timeout=14 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24638 --class=miner --scale=2 --give=pickaxe --bot="aim:-24,0;use:3000" --screenshot=shots/m2b_client.png --frames=300 < /dev/null
```
- M2a 그림 4장 (마우스 대신 `--test-aim`으로 조준을 고정하고, 동작은 `--test-action`으로 한 프레임에 멈춘다). M1 그림(`main_evening*.png`)은 HUD가 생기기 전에 찍었다:
  - `shots/m2_hotbar.png`: 광부, 디버그 묶음과 같은 아이템 23칸(`--give=`), Tab으로 연 인벤토리(아래 줄 = 핫바, 고른 칸 1 = 곡괭이, 금빛 테), 묶음 수(3×5 숫자), 상급 약초 칸의 금빛 점, 동쪽 목표 칸 표시
  - `shots/m2_aim.png`: 아처가 활을 고르고 서쪽(약간 아래)을 조준: 서쪽을 보고(동쪽 반전), 발 서쪽 칸에 표시
  - `shots/m2_use.png`: 광부가 곡괭이 동작 4번째 프레임으로 동쪽 표시 칸을 친다 (등의 곡괭이 레이어는 숨김, ● R27)
  - `shots/m2_actions_miner.png`: 광부의 몸 동작 8개(곡괭이·괭이·낫·물주기·검·활·마법·던지기) 가운데 프레임, 윗줄 남쪽 · 아랫줄 동쪽, 저녁 끔. 곡괭이 동작만 등의 곡괭이가 없다

```bash
timeout 120 "$GODOT" --path game -- --give=pickaxe,hoe,sickle,watering_can,sword,bow,wild_healing:12,mushroom_a:5,stone_a:30,stone_block:8,wild_healing:3:fine,wild_buff:4,wild_poison:2,herb_clump:6,mushroom_b:3,mushroom_c:2,mushroom_d,mushroom_ash:2,stone_b:4,stone_c:4,stone_mossy:2,stone_veined,stone_mould --test-select=1 --test-inventory --test-aim=40,8 --class=miner --screenshot=shots/m2_hotbar.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --give=pickaxe,hoe,sickle,watering_can,sword,bow,wild_healing:12,stone_a:30 --test-select=6 --test-aim=-28,10 --class=archer --screenshot=shots/m2_aim.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --give=pickaxe,hoe,sickle,watering_can,sword,bow --test-select=1 --test-aim=30,4 --test-action=pickaxe:4 --class=miner --screenshot=shots/m2_use.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --test-action-lineup --class=miner --no-evening --screenshot=shots/m2_actions_miner.png --frames=30 < /dev/null
```

- M3a 그림 3장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때 `--bot`이 키·마우스 대신. `--max-fps 60`이라 프레임 수 ≈ 물리 틱 수):
  - `shots/m3_surface_entrance.png`: 저녁의 지상, 제단 빛 밖 동쪽의 던전 입구(아치 + 내려가는 계단 + 둘레 잔해 장식). 팔라딘이 입구 바로 남쪽에서 입구를 조준하고 서 있다(입구 앞에 그려짐)
  - `shots/m3_dungeon_torch.png`: 던전 도착점, 어둠(`DUNGEON_DARK_COLOR`). 약초사가 횃불 둘을 놓았다(남쪽 칸, 서쪽으로 걸어가 한 칸 더). 북쪽 벽 앞면의 출구 계단(임시 그림: 아치 + 뒤집은 계단) 양옆에 벽 횃불(불꽃 4프레임, 작은 빛). 핫바 1번 = 횃불 아이콘(코드 그림)
  - `shots/m3_miner_mining.png`: 광부가 통로에 횃불을 놓고 북쪽 벽 앞면을 곡괭이로 친다: 왼쪽에 3번 휘둘러 판 3×3 구멍(앞면이 세 칸 위로 물러남), 오른쪽은 한 번·두 번 맞은 3×3이 겹쳐 금 1·2단계(앞면의 금이 보인다. 바위 윗면의 금은 그림이 옅어 어둠 속에서 잘 안 보인다, 알려진 문제), 찍는 순간 곡괭이 동작 중. 핫바에 돌 a 9개

```bash
timeout 120 "$GODOT" --max-fps 60 --path game -- --bot="walkto:70,49;walkto:72,48;aimat:72,47" --screenshot=shots/m3_surface_entrance.png --frames=240 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --start-map=dungeon --class=herbalist --give=torch:3 --test-select=1 --bot="aim:0,30;use:2;wait:20;move:-1,0,25;aim:-20,0;use:2;wait:20;aim:off;move:1,0,20" --screenshot=shots/m3_dungeon_torch.png --frames=150 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=miner --start-map=dungeon --give=pickaxe,torch:2 --test-select=2 --bot="walkto:46,17;aim:20,0;use:2;wait:4;select:1;walkto:45,17;aimat:45,16;use:108;walkto:48,17;aimat:48,16;use:36;walkto:49,17;aimat:49,16;use:60" --screenshot=shots/m3_miner_mining.png --frames=372 < /dev/null
```

- M3b 두 창 그림 `shots/m3b_host.png`, `shots/m3b_client.png`: 세션 하나의 두 화면, 둘 다 던전. 호스트(광부)는 도착 방 서쪽 바위를, 클라이언트(성직자, 후광)는 동쪽 위 벽 앞면을 누르고 있어 계속 친다. 둘 다 내려오자마자 남쪽에 횃불을 하나씩 놓았다(랜턴 둘). 호스트 화면 왼쪽은 광부의 3×3이 깬 자리. 클라이언트의 던전은 호스트가 보낸 지도다(로그 `map entered map=dungeon ... bytes=341 ... torches=1`). 클라이언트는 찍고 나가므로 호스트가 먼저 찍게 프레임 수를 맞췄다(호스트는 2초 먼저 떠서 700프레임 ≈ 클라이언트 600프레임보다 조금 앞). 클라이언트에 `--keep-running`을 주면 호스트가 끝난 뒤 혼자 남아 `timeout`이 죽일 때 엔진 종료 오류 줄이 찍힌다(그래서 뺐다). 찍은 명령:

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24637 --scale=2 --class=miner --give=pickaxe,torch:3 --bot="walkto:70,49;walkto:73,48;aimat:73,47;pick;wait:20;select:2;aim:0,24;use:2;wait:10;select:1;walkto:34,15;aimat:33,15;use:3000" --screenshot=shots/m3b_host.png --frames=700 --keep-running --net-timeout=16 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24637 --class=cleric --scale=2 --give=pickaxe,torch:3 --bot="walkto:70,49;walkto:73,48;aimat:73,47;pick;wait:20;select:2;aim:0,24;use:2;wait:10;select:1;walkto:40,15;aimat:41,14;use:3000" --screenshot=shots/m3b_client.png --frames=600 < /dev/null
```

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
- `rig`: 5클래스 × 4방향 × (걷기 6 + idle 4 + M2a 몸 동작 8개의 55) 프레임을 저녁 끈 화면에 세워, 배경 + 시트에서 CPU로 합친 그림과 픽셀까지 비교 (그리기 순서, v01→v02 이동 + 기준점, 서쪽 반전, 64칸 동작의 발 맞춤, 손에 든 표식 숨기기). 한 화면에 캐릭터 20명, 65화면
- 일부러 깨 본 것 (M2a): 캐릭터가 64칸 동작 칸의 (16, 16)을 빼먹고 32칸처럼 놓음 → `rig` FAIL(65화면 중 불일치 655,477픽셀)·종료 1
- `items` (M2b): 채집물이 가장 많이 보이는 화면(시드 1: 9개)과 드롭 하나를 저녁 끈 채 찍어, 그것들을 숨긴 화면 + 각자의 그림(월드 그림 / 아이콘)을 그 칸에 놓은 것과 픽셀까지 비교. 일부러 깨 봄: 그림을 1px 내리면 FAIL(불일치 1,054픽셀)
- `cave` (M3a): 시드 1 던전의 도착 방 둘레를 어둠 끄고(엔티티 숨김) 찍어, 그림 칸마다 `CaveView.drawn_at`의 절벽 타일 + 광맥·금 오버레이를 CPU로 합친 그림과 픽셀까지 비교. 그 전에 벽을 깎아 둔다(앞면이 있는 벽 셋에 금 1·2·3단계, 옆 벽 하나에 1단계, 앞면 벽 하나는 깨서 앞면이 한 칸 위로). 지상 월드는 그동안 숨긴다
- `dark` (M3a): 같은 던전에 횃불 하나를 놓고(다른 빛은 끄고 다른 엔티티는 숨김) 어둠 켬·끔 두 번 찍어, 횃불 반경 밖 픽셀은 모두 어둡고(비율 ≤ 0.3) 첫 단계(반경의 45%) 안 픽셀은 모두 밝은지(≥ 0.75), 그 자리가 안전 반경이 아닌지(빛일 뿐)
- `cave_net` (M3b): 세션 클라이언트가 받는 던전. 호스트의 시드 1 던전을 진짜 규칙(`Mining.strike`: 광부 3×3 금 1단계, 공용 3·5번으로 금 2·3단계, 광부 3×3 깸)으로 캐며 편집마다 호스트 그림에 적용하고, 반쯤에서 찍은 지도 스냅샷(`WorldSnapshot` → `Receiver.finish`(던전))으로 만든 클라이언트 월드에 나머지를 실시간 편집으로 적용한다. 두 화면(어둠 끔, 엔티티 숨김)이 픽셀까지 같고 클라이언트 데이터의 CPU 합성(타일 + 광맥·금 오버레이)과도 같아야 한다
- `ysort`: 겹친 두 캐릭터(나중에 추가한 쪽이 뒤), 제단 뒤·앞의 캐릭터가 발 y 순서대로 그려지는지. 트리 순서로 그렸다면 틀렸을 픽셀(지금 516개)이 0보다 커야(= 검사가 실제로 겹침을 본다) 통과
- `ysort`는 H1부터 캐릭터 둘을 더 세운다: `Movement`로 제단 서쪽·동쪽 면까지 걸어가 붙은 광부(동쪽을 봄)와 아처(서쪽을 봄). 제단 뒤에 그려지지만 그 픽셀이 제단 그림에 하나도 겹치지 않아야 한다(`side_pixels_hidden=0`)
- 일부러 깨 본 것 (G2, 커밋하지 않음): 서쪽 반전 끄기, 한 프레임의 표식 1px 밀기, 캐릭터 빛을 디더로, 캐릭터를 월드 빛 레이어로, 불꽃 shaded, 빛 `texture_scale` 1.02, 빛 위치 1px, y 정렬 끄기. 8개 모두 해당 부분이 FAIL·종료 1. H1: 제단 옆 띠를 0으로 → `ysort` FAIL(`side_pixels_hidden=27`)·종료 1

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
| `--bot=<스크립트>` | 내 캐릭터를 키 대신 스크립트로: `wait:<틱>`, `move:<dx>,<dy>,<틱>`, `edit:<x>,<y>,<grass\|soil>`(호스트만), `mark:<이름>`, `leave`(클라이언트), `stall:<ms>`(테스트 전용, H-fix: 그 틱 뒤 `_process`에서 프로세스를 1..5000ms 멈춤 = 긴 프레임), `;`로 잇는다 (`net/net_bot.gd`). M2b: `walkto:<x>,<y>[,<틱>]`(그 칸 가운데로 걸어감), `aim:<dx>,<dy>`·`aim:off`(발에서 그만큼 떨어진 곳을 조준 / 끔), `aimat:<x>,<y>`(그 칸 가운데를 조준), `use:<틱>`(좌클릭을 누르고 있음), `pick[:<번>]`(매 틱 F), `select:<1..8>`, `drop[:<개수>]`, `give:<id>[:<수>[:<등급>]]` | 동작 |
| `--start-map=<surface\|dungeon>` | 혼자 할 때 그 지도에서 시작(던전이면 도착점) | 동작 (M3a) |
| `--bot=` `waitmap:<인원>,<지도>[,<틱>]` | M3b: 이 기기가 아는 그 지도(`surface`/`dungeon`/0/1)의 플레이어가 그 수 이상일 때까지 서서 기다림(기본 최대 1800틱). `pick`(F)은 입구·계단을 겨누면 지도를 옮긴다(세션에서는 TRAVEL 요청) | 동작 (M3b) |
| `--bot=<스크립트>` (혼자 할 때) | M3a: 세션이 아니어도 봇이 키·마우스 대신 내 캐릭터를 움직인다(`pick`은 F와 같아서 입구·계단에서는 지도를 옮긴다). 스크린샷·테스트용 | 동작 (M3a) |
| `--max-players=<1..9>` | 호스트: 인원 상한을 낮춘다 (테스트용. 9보다 높일 수 없다) | 동작 |
| `--net-out=<폴더>`, `--net-name=<이름>` | 테스트 인스턴스: 결과 JSON·표시 파일을 쓰고 세션이 끝나면 종료 | 동작 |
| `--net-start=<n>`, `--net-expect=<n>`, `--net-expect-refused=<n>` | 호스트: 클라이언트 n명이 오면 봇 시작 / n명이 봇을 마치거나 나가고 n번 거부했으면 세션 끝 | 동작 (테스트) |
| `--net-timeout=<초>` | 그 시간이 지나면 종료 코드 6 (테스트가 멈춰 있지 않게) | 동작 |
| `--net-lag=<ms>`, `--net-loss=<%>` | 클라이언트: 왕복 지연·손실 흉내 (unreliable 입력·상태만) | 동작 |
| `--test-perturb-generator` | 이 프로세스의 생성기가 같은 시드로 다른 월드를 만든다(재 가장자리 노이즈 시드를 바꿈, `SurfaceGen.test_perturb`). 다른 아키텍처 흉내 | 동작 (테스트 전용, H1) |
| `--test-snapshot-chunk-bytes=<1..1024>` | 호스트: 월드 스냅샷을 이 크기 조각으로 자른다(`WorldSnapshot.chunk_bytes`, 기본 1024). 작은 월드도 여러 조각·여러 틱으로 보내 보려고 | 동작 (테스트 전용, H1) |
| `--give=<id>[:<수>[:<등급>]],...` | 디버그: 시작할 때 내 인벤토리에 아이템을 넣는다. id는 아래 "아이템 표", 등급 `common`/`fine`은 약초만. 예 `--give=pickaxe,stone_a:30,wild_healing:3:fine`. 게임 안에서는 F5가 디버그 묶음을 준다. M2b: 호스트는 자기 인벤토리에 바로, 클라이언트는 호스트에게 주기 요청을 보낸다(호스트가 디버그 빌드이거나 `--test-allow-give`일 때만 받아 준다). 요청 하나의 개수는 1바이트라 255개를 넘으면 여러 요청으로 나눈다(M2-fix: 전에는 300이 44로 잘렸다). 기다리는 요청은 `NET_LOCAL_OPS_MAX` 64개까지, 넘는 것은 `request_dropped` 줄을 찍고 버린다 | 동작 (M2a, M2b) |
| `--test-allow-give` | 호스트: 내보낸(release) 빌드에서도 클라이언트의 디버그 주기·버리기(F7) 요청을 받아 준다 (세션 시험을 내보낸 exe로 돌릴 때, 사람이 두 기기로 해 볼 때) | 동작 (M2b, 버리기는 M2-fix) |
| `--test-select=<1..8>` | 시작할 때 핫바 칸 고르기 | 동작 (스크린샷용, M2a) |
| `--test-inventory` | 인벤토리 칸 전부 보기(Tab)를 연 채 시작 | 동작 (스크린샷용, M2a) |
| `--test-aim=<dx>,<dy>` | 마우스 대신 발에서 이만큼(px) 떨어진 곳을 늘 조준 | 동작 (스크린샷·테스트용, M2a) |
| `--test-action=<동작>[:<프레임>]` | 내 캐릭터가 그 몸 동작(`pickaxe`·`hoe`·`sickle`·`watering`·`sword`·`bow`·`magic`·`throw`)의 한 프레임(1부터, 기본 가운데)에 멈춘다. 입력은 받지 않는다 | 동작 (스크린샷용, M2a) |
| `--test-action-lineup[=<프레임>]` | 더미 대신 내 클래스가 몸 동작 8개를 두 줄(남쪽·동쪽)로 한 프레임(1..6, 기본 동작마다 가운데)에 멈춰 서 있고, 내 캐릭터는 숨긴다 | 동작 (스크린샷용, M2a) |

아는 인자의 값이 틀리면 `EVENSONG_CLI error: ...`를 찍고 종료 코드 2. 모르는 인자는 무시한다 (테스트 러너의 `--only=` 등이 같은 명령줄로 들어오기 때문).
세션 종료 코드: 0 끝남·나감, 3 거부됨, 4 접속 실패·호스트 잃음(`--net-out`일 때), 5 받은 월드가 검사를 통과하지 못함(조각 수·크기·md5·월드 해시), 6 `--net-timeout`.
테스트 러너 인자(`run_all.gd`, `--` 뒤): `--only=`, `--timeout=`, `--dir=`, `--prefix=`, `--port-base=<n>`(테스트 포트 묶음), `--ports-from-parent=<n>`(자식 러너용: 부모가 잡은 묶음), `--net-exe=`, `--net-full`, `--net-keep`, `--net-sessions=<a,b>`(M3b: 그 세션만, pair·four·lag·stall·cave·full).

### 스모크 (`--smoke`, `core/smoke.gd`)

고정 문자열이 아니라 실제로 확인한다. 하나라도 틀리면 `EVENSONG_SMOKE FAIL <n> failure(s) ...`과 종료 코드 1.
엔진 4.7.2, 렌더러 설정 forward_plus, 루트 창에 실제로 적용된 480×270·viewport·integer·expand·Nearest·픽셀 스냅, 기본 창 1920×1080, 이동 키 배치,
커밋된 타일셋(소스 11, 타일 40, 그림 있는 코너 키 31, 키마다 그림 유무가 규칙과 같은지), 기본 시드 월드(크기, 제단 자리, 흙·재 있음, 흙+재 칸 0, 월드 해시 = `SurfaceGen.GOLDEN_HASH`)를
실제로 그려서 그림 칸 12,513개 전부의 코너가 데이터와 같은지(대체 타일 0, 빈 칸 0),
캐릭터 시트 크기와 클래스 다섯의 표식 레이어(리그를 만들어 표식이 보이는지), 기준점 표의 모양(이제 걷기·idle + 몸 동작 8개), `main.tscn`이 불러지는지,
M2a: 몸 동작 시트 8장의 크기(칸 × (시작 칸 + 프레임), 칸 × 3줄), 아이템 22개의 아이콘(16×16, 그림 또는 코드로 그린 것)과 월드 그림, 도구 6개의 몸 동작, M2a 입력 액션 6개,
M2b: 기본 월드의 채집물 수(= 임시값 표의 합 74), 채집물 15종의 월드 그림, F·F7 입력 액션, 드롭이 든 스냅샷 왕복, 요청이 붙은 입력 프레임 왕복,
M3a: 기본 월드의 던전 입구, 던전 타일셋(소스 2, 타일 30, 그림 있는 코너 키 21), 시드 1 던전(크기, 해시 = `DungeonGen.GOLDEN_HASH`, 출구 계단, 도착점에 설 수 있음, 제단 자리)을 동굴 그림으로 그려 그림 칸·오버레이 전부 = 데이터,
M3b: 시드 1~8 던전의 해시 묶음(`DungeonGen.SEEDS_GOLDEN`, 출력 `dungeon_seeds=3ec443b95c4c`: 다른 기기의 던전 생성기가 같은지 보는 값), 캔 던전(금·깸·횃불·드롭)을 지도 스냅샷 길로 보내 받은 것 = 원본이고 동굴 그림 = 데이터(`dungeon_map=313B`), 전송 형식 v4(지도가 든 상태, 지도를 적은 TRAVEL, 지도를 적은 편집, 지도 들어옴 메시지),
기본 월드의 안전 반경 hard 빛 텍스처 226×226 텍셀 전부 = `is_in_safe_zone()`, 불꽃 마스크 81픽셀,
네트워크(G3): 물리 틱 60, ENet 호스트가 루프백 빈 포트에서 열리고 닫힘(방화벽 창이 뜨지 않게 127.0.0.1만), Steam 가용성 = GodotSteam 유무, 상태 묶음 왕복, 늦은 참가 월드 스냅샷 왕복(H1: 이 빌드의 zstd로 압축 → 조각 → 받기 → 같은 월드), 9명 뒤 열 번째 거부, `main.tscn`에 `Net` 노드.
내보낸 exe에서 돌면 pck 안의 타일셋·그림까지 확인하는 셈이다. 월드 해시는 이 데스크탑(x86_64)에서 만든 값이라, 다른 기기(서피스 ARM64)에서 `--smoke`가 해시로 FAIL이면 그 기기는 같은 시드로 다른 월드를 만든다는 뜻이다. 늦은 참가는 이제 호스트의 월드를 받으므로 그래도 된다(H1). 다만 그 기기가 호스트가 되면 같은 시드라도 데스크탑과 다른 월드가 된다.
`test_core.gd`는 같은 창 검사가 설정이 다른 창에서는 실패하는 것도 확인한다.

## 폴더

```
game/                           Godot 프로젝트 루트 (= res://)
  project.godot                 이름 "Evensong", 메인 장면 res://scenes/main.tscn, 오토로드 Cli, 설정은 아래 "규칙"
  export_presets.cfg            "Windows Desktop" (x86_64) + "Windows ARM64", release, pck 내장, 콘솔 래퍼, tests/·tools/ 제외
  core/                         cli.gd (오토로드 Cli), cli_options.gd (인자), config.gd (상수: ● / 임시값 / 구현 선택), smoke.gd,
                                main.gd (main.tscn 루트: 내 플레이어 + 더미 + 카메라 + HUD + 목표 칸 표시, 키, 테스트 플래그)
  items/                        item_db.gd (아이템 표, M2a), item_stack.gd (한 칸의 묶음), inventory.gd (인벤토리 + 핫바),
                                item_icons.gd (아이콘: 그림 불러오기 + 도구 임시 아이콘을 코드로), world_items.gd (M2b:
                                채집물 표, 줍기·버리기·사용·주기 규칙과 거부 이유, 등급 규칙, M3a: 횃불 놓기·입구 거부),
                                mining.gd (채굴 규칙, M3a)
  ui/                           hud.gd (핫바 줄 · Tab 인벤토리 칸 · 3×5 숫자, 자기 캔버스 레이어)
  world/                        terrain.gd (지형·코너 키), world_data.gd (레이어 6장), tileset_builder.gd, wang_table.gd,
                                surface_gen.gd (생성기), ground_view.gd (청크 dual grid), game_world.gd (world.tscn 루트),
                                altar.gd (제단 그림 + 불꽃), debug_overlay.gd, target_marker.gd (조준 목표 칸 표시, M2a),
                                item_view.gd (채집물·드롭 그림, M2b), M3a: walls.gd (벽 바이트·앞면·경도 규칙),
                                dungeon_gen.gd (던전 생성기), cave_table.gd (절벽 타일 조회: 코너 + 둘레), cave_view.gd
                                (던전 dual grid + 광맥·금 오버레이), fixture_view.gd (입구·계단·제단·횃불 그림과 빛),
                                tilesets/surface.tres, tilesets/dungeon.tres (만든 타일셋, 커밋)
  actors/                       character.gd (레이어 캐릭터), rig_data.gd (리그 표), rig_anchors.gd (생성된 기준점 표),
                                rig_measure.gd (기준점 재기), movement.gd (이동 규칙), player.gd (+ M2a 조작: 조준·사용·동작
                                시간, M2b: 프레임 만들기·진행), player_sim.gd (M2b: 프레임 하나를 진행하는 규칙, 호스트·예측·혼자 공통),
                                aim.gd (조준 규칙과 창 늘이기 계산, M2a), player_camera.gd, free_camera.gd (world.tscn 맵 보기용)
  light/                        safe_zone.gd (안전 반경 규칙), light_gen.gd (빛 텍스처·불꽃 마스크), altar_light.gd, lighting.gd,
                                torch_light.gd (횃불 빛 텍스처, M3a)
  net/                          session.gd (세션 노드 Net: 두 역할이 같이 쓰는 상태·RPC 표·틱 나누기), session_host.gd
                                (호스트 흐름), session_client.gd (클라이언트 흐름), session_bots.gd (봇·테스트 흐름: go/done/
                                finish, 결과), world_snapshot.gd (늦은 참가 월드 스냅샷), transport.gd (전송 인터페이스), enet_transport.gd,
                                steam_transport.gd (자리만), transports.gd (이름 → 전송), protocol.gd (전송 형식),
                                roster.gd (인원 상한·스폰 자리), input_gate.gd (호스트 입력 검사), state_broadcast.gd
                                (묶음/키프레임/조용함), prediction.gd (클라이언트 예측·보정), interpolation.gd (남의 캐릭터
                                보간 + 호스트 시계), edit_log.gd (월드 편집 기록), net_member.gd (세션 안 플레이어 하나),
                                net_bot.gd (--bot), link_sim.gd (지연·손실 흉내), net_stats.gd (트래픽), session_report.gd
                                (테스트 결과 JSON·표시 파일)
  scenes/                       main.tscn (실행 장면: 월드 + 카메라 + Net), world.tscn (월드 + 제단 + 빛 + 자유 카메라 + 디버그 선)
  art/tiles/, art/chars/, art/env/, art/items/   우리 PNG·JSON 사본 (아래 "그림 출처")
  tests/                        run_all.gd (러너), base_test.gd (기반 클래스), test_core.gd, test_world.gd, test_actors.gd,
                                test_light.gd, test_net.gd, test_net_session.gd (다중 프로세스), test_items.gd, test_aim.gd,
                                test_actions.gd (M2a), test_world_items.gd (M2b), test_dungeon.gd, test_mining.gd (M3a),
                                test_net_maps.gd (M3b: 세션의 지도, 한 프로세스),
                                fixtures/ (러너 자체 시험)
  tools/                        build_tileset.gd (타일셋 빌더), build_rig_anchors.gd (기준점 표), check_render.gd (창 그림 검사)
  shots/                        스크린샷 (.gdignore)
  build/                        내보내기 결과 (커밋 안 함, .gdignore만 커밋)
```

## 월드 데이터

- `WorldData`는 칸마다 1바이트씩 **레이어 6장**(● gameplay-design §3.1: 바닥 / 벽 / 광맥 / 식생 / 오염 / 설치물)을 `PackedByteArray`로 들고 있다. M1은 바닥(풀 0 / 일군 흙 1 / 재 2), 오염(구역 번호 1.., 0 = 깨끗), 설치물(제단 = 1)만 쓰고, 벽·광맥은 0으로 둔다. M2b부터 식생 = 채집물(1 + `WorldItems.GATHERABLES` 순서, 0 = 없음), 그리고 레이어 밖에 **드롭 목록**(번호 → 아이템·개수·등급·픽셀 자리)이 있다. 월드 해시(`content_hash`)는 드롭까지 덮는다
- 바닥 레이어가 곧 **꼭짓점 격자**(dual grid)다. 월드 칸 (x, y)의 바닥 값 = 그 칸 가운데 꼭짓점의 지형. 그림 칸은 반 칸 밀려 있어서 그림 칸 (dx, dy)의 NW·NE·SW·SE 코너가 꼭짓점 (dx, dy), (dx+1, dy), (dx, dy+1), (dx+1, dy+1)이다. W×H 월드는 그림 칸 (W+1)×(H+1)개(-1..W-1)이고, 맵 밖 꼭짓점은 풀로 읽는다. 괭이질 한 칸 = 그 칸 가운데 16×16 흙 덩어리 (스파이크 RESULTS §2의 (b))
- 코너 키 = NW + 3·NE + 9·SW + 27·SE (0..80). 우리 그림은 풀↔흙, 풀↔재 두 벌뿐이라 키 81개 중 31개만 그림이 있고, 흙과 재가 한 칸에 섞이는 50개는 없다. 그래서 **흙과 재는 같은 그림 칸의 코너가 되면 안 된다**(꼭짓점 8방향 이웃 금지). `WorldData.set_terrain()`이 거부하고, 생성기는 거리로 떼어 둔다. 그래도 생기면(규칙을 거치지 않고 쓴 데이터) 가장 가까운 키의 타일로 그리고 `GroundView.verify()`가 "fallbacks"로 센다
- 같은 코너의 타일이 여럿이면(풀 5, 흙 3, 재 4) 칸 위치 해시로 고른다. 같은 데이터 → 같은 그림
- `GroundView`는 그림 칸 32×32개마다 `TileMapLayer` 하나(청크)를 둔다. 128×96 맵 = 청크 20개. 렌더링 사분면은 8칸. `set_terrain(꼭짓점, 값)`은 그 꼭짓점을 코너로 가진 그림 칸 4개만 다시 그린다 (청크 경계에서는 여러 청크에 걸쳐)
- 생성기(`SurfaceGen.generate(seed)`): 맵 가운데 제단 자리(3×3, 설치물 레이어), 제단 빛 반경 안에만 일군 흙 3덩어리(칸의 네 모서리까지 반경 안, 제단 둘레 1칸 비움, 덩어리끼리 안 붙음), 반경 + 4타일 밖에 고정 오염(재) 구역 3곳(노이즈로 가장자리를 흔든 원). 같은 기기에서 같은 시드 → 같은 월드(PCG32 + FastNoiseLite + 정수 해시). FastNoiseLite는 float 계산이라 다른 아키텍처(ARM64)에서도 같은지는 확인하지 못했다. 늦은 참가는 이것에 기대지 않는다(H1: 호스트가 월드를 보낸다, 아래 "네트워크"). 시드 1의 해시(x86_64 결과)를 `SurfaceGen.GOLDEN_HASH`로 고정해서 `test_world.gd`와 `--smoke`가 비교한다. **M2b에서 바뀌었다**: `e04258e54b02b0ed09ce02c9a92c11a8` → `ff2e1d90c4dc12d6dfad926584d440d0` (채집물 74개를 흩는 4단계와, 해시가 드롭 목록까지 덮게 된 것. 흙·재는 그대로: 채집물은 그 뒤에 같은 난수열에서 뽑는다) 이 값은 생성 결과가 모르게 바뀌는 것을 잡을 뿐이고, 생성 규칙이 맞는지는 `test_world.gd`의 40시드 규칙 검사가 본다
- 제단은 설치물 레이어의 자리(3×3) 위에 `Altar` 노드로 놓인다 (아래 "빛과 제단"). 걷기 충돌은 설치물 레이어를 본다
- **M3a**: 생성기 5단계가 던전 입구(설치물 `PLACEABLE_ENTRANCE`, 2×1)를 넣는다. 그래서 `SurfaceGen.GOLDEN_HASH`가 **다시 바뀌었다**: `ff2e1d90c4dc12d6dfad926584d440d0` → `1d9f92c7b5ef2a715f95cc32d7424b36` (입구 칸 2개뿐. 난수를 쓰지 않고 4단계 뒤에 놓아서 채집물 74개는 M2b 자리 그대로다, `test_dungeon.gd`가 확인). 늦은 참가 스냅샷 원본이 그만큼 바뀌어 세션 시험의 압축 크기·조각 수가 조금 달라졌다(시험은 수를 스스로 센다). 설치물 중 막는 것은 제단·입구·계단·이단의 제단(`WorldData.placeable_blocks`), 횃불은 막지 않는다
- **M3a 지도**: 지도마다 WorldData가 따로다(`map_id`: 지상 `Config.MAP_SURFACE` 0, 첫 던전 `MAP_DUNGEON` 1. 해시·스냅샷에는 들어가지 않는다). 던전은 벽(WALL)·광맥(ORE)·설치물만 쓰고 바닥 레이어는 0이다. 벽 바이트 = 종류(아래 4비트: 0 없음, 1 바위, 2 기반암) | 맞은 횟수(위 4비트), 광맥 = 0 없음 / 1 구리 / 2 철 (`world/walls.gd`). 그래서 채굴 한 번이 보통 칸 편집 하나이고 스냅샷·해시·편집 기록이 반쯤 깬 벽까지 그대로 덮는다

## 캐릭터 (G2)

- `Character`(actors/character.gd) = 기본 몸 한 벌 + 클래스 표식 레이어 하나 (● brief §5.6 R21). 노드 위치 = 두 발 사이(프레임 바닥 가운데, 발 줄 y=31 바로 아래)라 y 정렬 부모(`Entities`) 아래에서 **발 기준으로 정렬**된다. 속성: `class_id`(paladin|miner|archer|cleric|herbalist), `direction`(남·동·북·서), `walking`(걷기 6프레임 / idle 4프레임)
- 구조: `Rig`(서쪽이면 `scale.x = -1`) 아래 `Body` + 슬롯 `Back`(곡괭이·활) · `Arm`(방패) · `Waist`(씨앗주머니) · `Float`(후광). 방향마다 순서표(`RigData.DRAW_ORDER`)대로 자식 순서를 바꾼다: 등 장비는 남·동(·서)에서 몸 뒤, 북에서 몸 앞. 방패·주머니·후광은 늘 앞. `z_index`는 쓰지 않는다(다른 캐릭터·바닥과의 순서까지 바뀐다)
- 서쪽 = 동쪽 좌우 반전 (● R19). 프레임 32px가 발 가운데 기준이라 반전해도 정수 픽셀이다
- 표식 위치 = v01 걷기 첫 프레임 기준 위치 + v01→v02 발 맞춤 이동(걷기 남 +4 동 +3 북 +4, idle 남 +5 동 +2 북 +3) + 그 프레임의 기준점 이동(+ 후광은 걷기 2~4프레임에서 1px 뜸)
- 기준점(● R27, brief §5.6 "위치"): 프레임마다 **걷기 첫 프레임**의 몸통 줄(v01 y 13~22)·머리 줄(y 0~11)이 가장 많이 겹치는 이동(RGB 차 합 < 60인 픽셀 수, 몸통 ±4px, 머리 ±8px, 같으면 작은 이동). 두 프레임을 각자의 발 맞춤 이동을 되돌린 v01 좌표에서 비교한다. 방패·곡괭이·활·주머니는 몸통, 후광은 머리를 따른다. `tools/build_rig_anchors.gd`가 재서 `actors/rig_anchors.gd`에 표로 쓰고, 테스트가 다시 잰다
  - 걷기 기준점은 스파이크와 같다 (몸통: 북 1·2프레임 아래로 1px, 머리: 남 2~5프레임 위로 1px, 나머지 0)
  - idle: 몸통 남 0 / 동 (0,2)(−1,2)(−1,2)(0,2) / 북 (0,1)×4, 머리 남 (−1,0)(0,0)(−1,0)(−1,0) / 동 (−1,2)(0,2)(−1,2)(0,1) / 북 (0,1)×4. idle은 다른 템플릿이라 걷기와 몸 모양이 조금 달라서 0이 아니다. 창 검사 `--save`로 남긴 걷기·idle 전 프레임(5클래스 × 4방향)을 2배로 모아 봤을 때 표식은 제자리에 붙어 보였다(동쪽 idle에서 표식이 좌우로 1px 흔들린다). 기준점은 재는 법에 따라 1px씩 달라질 수 있으니(스파이크 notes/chars.md) **사람이 보고 고정하는 편이 낫다**
- 방패 시트(`sig_paladin_shield_v01.png`)는 남·동 줄에 걷기 프레임마다 떼어 낸 칸이 6개씩 있지만, "단단한 파츠는 방향당 1장 + 기준점"(● R27)대로 **줄마다 첫 칸만** 쓴다 (R27 동작 시험이 쓴 칸과 같다)
- `Player`(actors/player.gd) = 시뮬레이션(발 위치 float, 4방향 바라보기) + `Character`. `_physics_process`(60Hz 고정)에서 키를 읽어 `apply_input()`(= `Movement.step()` + `Movement.facing_for()`)을 돌린다. 노드는 정수 픽셀에 둔다. `PlayerCamera`도 정수 픽셀에서 내 캐릭터 가운데를 따라가고 맵 가장자리에서 멈춘다(맵이 화면보다 작은 축은 가운데). 그래서 내 캐릭터와 카메라가 같이 1픽셀씩 움직인다
- **틱 사이에 그리기** (H1): 물리 틱으로 움직이는 플레이어(혼자일 때 내 캐릭터, 호스트가 시뮬레이션하는 모든 플레이어, 클라이언트의 예측된 내 캐릭터)는 `_process`에서 지난 틱 위치와 이번 틱 위치 사이를 `Engine.get_physics_interpolation_fraction()`만큼 간 곳에, 정수 픽셀로 반올림해 그린다(`Player.draw_position`). 60Hz보다 빠른 모니터에서 0·1·2px로 튀던 걸음이 0·1px로 고르다(테스트: 144Hz 흉내에서 2px 뜀 10번 → 0번). 시뮬레이션 위치(`sim_position`)·네트워크 상태·위치 해시는 그대로이고 그림만 최대 한 틱(1/60초) 뒤에 있다. 호스트의 보정(틱이 아닌 `show_state`)은 그리는 구간 전체를 옮겨서 튀지 않고, 같은 상태면 아무것도 바꾸지 않는다. 남의 캐릭터(클라이언트)는 원래 보간된 상태를 매 프레임 받으므로 그대로 그린다. 카메라는 `process_priority` 1로 플레이어 다음에 따라간다
  - 한 틱에 두 걸음(2.4px)보다 많이 움직인 플레이어는 그 틱 끝 위치에 그린다(H-fix, `Player.MAX_DRAWN_STEP_PX` 3px). 호스트가 밀린 클라이언트의 프레임을 한 틱에 여러 개 적용할 때(아래 "호스트가 멈췄다 돌아올 때")다: 두 끝을 잇는 직선은 걸음이 돌아간 모서리를 가로질러 제단 안을 지날 수 있다(테스트: 제단 북서 모서리를 도는 90걸음 틱이 반이 지난 때 직선 위면 제단 안, 실제로는 11번 그려 모두 틱 끝). 그래서 따라잡기는 그림에서 걸음당 한 칸씩이 아니라 틱마다 최대 4걸음씩 뛰어 보인다. 보통(틱당 1걸음)은 그대로다(144Hz 시험 같은 수)
- 이동 규칙(`Movement`, 순수 함수, 결정적: G3에서 호스트와 클라이언트 예측이 같은 함수를 쓴다): 입력은 축마다 −1/0/1인 8방향, 속력은 대각선도 `WALK_SPEED`. 발 상자(가로 10 × 세로 4px)가 맵(위쪽은 머리 자리 28px 남김) 안, 장애물 밖에 있어야 한다. 장애물 = 막힌 칸(설치물 = 제단 3×3)과 **제단 옆 띠**(H1, `Movement.side_bands`): 제단 자리 서쪽·동쪽 면 옆으로 `ALTAR_SIDE_CLEARANCE`(서 5, 동 3px) 폭, 자리 위 변부터 아래 변 4px 위까지. 발이 제단 자리 높이에 있을 때(= 제단 뒤에 그려질 때)만 걸려서, 옆면에 붙은 캐릭터의 몸(발에서 좌우 9px)이 제단 그림(48px 자리 중 불투명 열 0~46) 뒤로 들어가지 않는다. 북쪽·남쪽 면은 전처럼 발 상자가 딱 붙어 멈춘다(모서리에서는 띠 폭만큼 면이 넓어진 셈). 이 폭은 `test_actors.gd`가 시트와 제단 그림에서 다시 재서 비교한다. x 먼저, 그다음 y로 움직이고 부딪힌 곳에 딱 붙어 멈추므로 대각선은 벽을 따라 미끄러진다. 바라보기는 4방향: 한 축이면 그쪽, 대각선이면 지금 바라보는 쪽이 두 축 중 하나일 때 그대로, 아니면 가로
- `main.tscn`: 내 캐릭터는 스폰 자리 0(제단 서쪽), 나머지 네 클래스는 자리 1~4에 제단을 보고 선 idle 더미. 스폰 자리 9개(`Config.SPAWN_SLOTS`)는 모두 안전 반경 안, 제단 밖이고 서로 겹치지 않는다 (세션에서는 호스트가 가장 작은 빈 자리를 준다, 아래 "네트워크")

## 아이템 · 조준 · 동작 (M2a)

혼자 할 때(`main.tscn`, `--host`/`--join` 없음)의 내 캐릭터에 붙었다. 문서의 ●는 그대로 따르고, 나머지는 [임시값](#임시값-사람-확인-필요) 표에 있다.

### 아이템 표 (`items/item_db.gd`)

- 종류: 도구(핫바에서 들고 좌클릭하면 그 도구의 몸 동작), 재료, 채집물(세상에서 줍는 것. 줍기는 아직 없다). 아이템마다 id, 종류, 아이콘, (채집물) 월드 그림, 묶음 크기, 등급이 있는지, (도구) 몸 동작
- 도구 6 (묶음 1, 등급 없음, 아이콘은 코드로 그린 임시): `pickaxe` → 곡괭이 동작, `hoe` → 괭이, `sickle` → 낫, `watering_can` → 물주기, `sword` → 검, `bow` → 활. 손에 드는 도구를 동작에 그려 넣은(● R25) 동작마다 하나다. 마법(성직자 기도·치료)과 던지기(약초사 약제 투척)는 손에 드는 도구가 없고 그것을 부르는 것(스킬·약제)이 M2 밖이라 아이템이 없다. F6과 `--test-action`으로 본다
- 재료 1 (묶음 99): `stone_block` (04-env 묶음 2 #61 "건설 재료 덤", 3/4 아이콘 v02)
- 채집물 15 (묶음 99): 약초 `wild_healing`·`wild_buff`·`wild_poison`(아이콘 = 꺾은 가지 `item_sprig_*`, 월드 그림 = 자라는 풀 `item_wild_*`)과 `herb_clump`(덤불, 아이콘 = 월드 그림), 버섯 `mushroom_a`·`b`·`c`·`d`·`ash`(ash는 오염 쪽), 돌 `stone_a`·`b`·`c`·`mossy`·`veined`·`mould`(뒤의 둘은 오염 쪽)
- 등급: 약초 넷만 일반(`common`)·상급(`fine`)이 있다 (● gameplay-design §3.4 원칙 "약초를 약초사가 캐면 상급 등급, 다른 클래스는 일반 등급"). 등급이 다르면 한 칸에 쌓지 않는다. 버섯·돌·도구의 등급은 문서에 없어서 두지 않았다(임시값). 캐는 일이 없으니 등급은 지금 `--give`로만 생긴다
- 그림: 채집물·재료는 04-env "본 제작"(2026-10-21) 손질판 v02이고 모두 **채택 후보, 사람 확인 전**이다. 임시 그림으로 쓴다 (아래 "그림 출처")
- M3a: 재료에 광석 둘(`ore_copper`, `ore_iron`, 채굴로 생김), 새 종류 "놓는 것"(`torch`, 아이콘은 코드). 표는 25개이고 뒤에 더해서 M2의 번호(전송 형식이 쓰는 순서)는 그대로다

### 인벤토리와 핫바 (`items/inventory.gd`)

- 플레이어마다 24칸, 앞 8칸이 핫바(임시값). 넣기는 같은 아이템·등급 묶음부터 채우고(칸 순서라 핫바 먼저) 그다음 앞쪽 빈 칸, 못 넣은 수를 돌려준다. F5 디버그 묶음은 못 넣은 것을 버린다
- 나누기는 묶음 일부를 첫 빈 칸으로 옮긴다(빈 칸이 없거나 수가 틀리면 아무것도 안 함). 옮기기는 빈 칸이면 옮기고, 같은 아이템·등급이면 들어가는 만큼 합치고, 아니면 맞바꾼다. 화면에서 끌어 옮기는 조작은 아직 없다(함수와 테스트만)
- Q / E = 핫바 왼쪽 / 오른쪽, 끝에서 반대쪽 끝으로 돈다. 키 초안(gameplay-design §1 ○)의 숫자 키 1 2 3은 스킬이라 핫바에 쓰지 않았다. F(상호작용)는 상호작용할 것이 없어 아직 묶지 않았다(M2b에서 F = 줍기로 묶음)
- M2a에서는 인벤토리를 네트워크로 보내지 않았다. M2b부터 인벤토리는 호스트에 있고 주인에게만 간다 (아래 "M2b")

### 조준 (`actors/aim.gd`, `Player.tick_controls`)

- 정해진 것은 ● 에임형(gameplay-design §2.1 R12: 마우스 방향 스킬샷)뿐이고, 아래 규칙은 모두 임시값이다
  - 조준 중 = 마우스가 지난 1초(`AIM_HOLD_SEC`) 안에 움직였거나, 사용 버튼을 누르고 있거나, 동작 중. 조준 중이면 마우스 쪽을 본다(4방향, 큰 축 쪽, 정확한 대각선은 남·북). 아니면 M1 그대로 걷는 방향을 본다(`Movement.facing_for`). 테스트: 조준 없이 600틱 무작위로 걸으면 위치·바라보기·걷기가 매 틱 M1 규칙과 같다(M2-fix: 비교 대상을 M1의 `apply_input` 그대로, 곧 `Movement.step` + `Movement.facing_for`를 테스트에 적은 것으로 바꿨다. 전에는 `apply_input`도 M2b의 `PlayerSim.step`을 불러 같은 함수끼리 비교하는 셈이라 `PlayerSim`의 바라보기 규칙을 바꿔도 통과했다)
  - 기준점은 발이다. 발 → 마우스 방향을 45° 8구역(축과 대각선이 가운데, 경계 ±22.5°)으로 나누고, 목표 칸 = 발 칸의 그 방향 이웃 칸(○ gameplay-design §3.2 "마우스 방향의 인접 타일을 타격", 채굴에 쓴 말). 마우스가 정확히 발 위면 앞의 구역·바라보기를 둔다
  - **발 칸** = 발 상자(발에서 위로 `FEET_HEIGHT` 4px)의 가운데가 있는 칸(`Aim.feet_cell`, M2-fix). 발 점은 그림의 아래 끝이라 타일 선 위에 있으면 그 점은 아래 줄 칸에 속하는데, 그려진 발(4px)은 모두 위 줄에 있다. 전에는 발 점의 칸을 써서 발이 타일 선에서 3px 아래까지일 때 목표 칸·표시·손 닿는 칸이 한 줄 아래였다(스폰 자리 0·1이 바로 그 자리 y = 768 = 48×16이라, 처음 동쪽·서쪽을 조준하면 발 옆이 아니라 대각선 아래 칸에 표시가 떴다). 호스트·예측·혼자가 같은 함수를 쓴다
- 마우스 → 월드: 게임은 엔진의 `get_global_mouse_position()`(캔버스 변환 = 카메라 + 창 늘이기)을 쓴다. `Aim.view_size`·`view_scale`·`view_margin`·`window_to_view`는 엔진 계산(`Window::_update_viewport_size`: 480×270, viewport, 정수배, expand, 32비트 float)을 그대로 옮긴 것이고, 테스트가 창 크기 6가지에서 엔진과 비교한다(**헤드리스에서만**: 창을 띄우면 루트 뷰포트가 주입한 마우스 이벤트 대신 OS 커서를 읽어 `test_aim.gd`의 `main.tscn` 마우스 검사가 실패한다. M2-fix 검토가 창으로 돌려 확인. 창의 y축 늘이기 계산은 엔진과 같았다. 진짜 마우스로 조준해 보는 것은 사람이 할 일): 1920×1080 → 480×270 4배, 960×540 → 2배, 1000×700 → 480×336 2배 + 검은 띠 (20, 14), 1366×768 → 480×270 2배 + 띠 (203, 114), 1000×703 → 480×337, 세로 500×1000 → 480×960 1배. 띠 위의 마우스는 뷰포트 밖 좌표가 되고(1000×700의 창 (0, 0) = 뷰포트 (−10, −7)) 조준은 그대로 된다
- 목표 칸 표시(`world/target_marker.gd`): 16px 칸 네 모서리의 금빛(#f4c95d) ㄱ자(팔 4px)와 그 안쪽 잿빛 검정(#1a1714) 띠. 코드로 그리고 unshaded라 저녁에도 보인다. Main이 World의 Ground와 Entities 사이에 넣어 바닥 위·캐릭터 아래다. 조준 중이고 칸이 맵 안일 때만 보인다. 동작 중에는 동작의 목표 칸(`Player.action_cell`)에 머문다(M2-fix: 전에는 동작 중에도 마우스를 따라가서 치는 칸을 떠났다). 발 북쪽 줄(북·북동·북서) 칸은 캐릭터 몸이 가린다

### 몸 동작 (`RigData`, `Character.show_action`, `Player`)

- 시트 8장(`art/chars/base_body_v02_<동작>.png`, 03-pixel 10~12차): 프레임 수는 곡괭이·괭이·낫·마법 6, 물주기·활·검 8, 던지기 7 (brief §5.6). 도구를 든 일곱은 64×64 칸이고 32 프레임을 칸의 (16, 16)에 둔 좌표라 발 줄이 y=47이다(● R26 "동작 칸"). 첫 칸은 생성의 시작 그림(= 걷기 첫 프레임)이라 재생은 둘째 칸부터다. 던지기는 도구 없는 템플릿 동작이라 32×32 칸, 시작 칸 없이 7프레임, 발 y=31(줄마다 +4 +4 +3 옮긴 판)
- 발 맞춤: 64칸은 칸의 (32, 48)을 발 점에 놓는다(32칸은 (16, 32)). 테스트: 일곱 장 × 세 줄의 시작 칸을 이 규칙으로 놓으면 걷기 첫 프레임을 걷기 규칙으로 놓은 것과 픽셀까지 같다
- 표식(● R27): 그 동작에서 손에 들지 않는 표식은 걷기용 표식 레이어 한 장을 동작 프레임마다 기준점(몸통 이동, 후광은 머리 이동)에 붙인다. 손에 든 도구가 곧 그 클래스의 표식이면 숨긴다: 광부의 곡괭이 동작과 아처의 활 동작 두 경우뿐이다(`RigData.HELD_SIGNATURE`). 그리기 순서는 걷기와 같다(등 장비는 북쪽을 볼 때만 몸 앞)
- 기준점: 걷기·idle과 같은 규칙(● R27, `RigMeasure`)으로 동작 55프레임 × 3줄을 재서 `actors/rig_anchors.gd`에 더했다(생성 파일, 이 데스크탑 약 2.1초). `test_actors.gd`가 다시 잰다
- 재생: 핫바에서 고른 아이템이 도구일 때 좌클릭하면 그 동작을 한다. 시간은 시뮬레이션 틱으로 센다: 프레임당 6틱(0.1초)이라 곡괭이 0.6초, 검 0.8초, 던지기 0.7초. 동작 중에는 걷지 않고 바라보기·목표 칸은 시작한 틱의 것이다. 누르고 있으면 끝나는 틱에 다시 시작한다. 셋 다 임시값. 재료·채집물·빈 손은 아무것도 하지 않는다
- 월드 효과는 없다(채굴·농사는 다음 단계). `Player.action_started(아이템, 동작, 목표 칸)` 시그널로 알리고 Main이 `EVENSONG_ACTION start ...` 줄을 찍는다
- 세션: M2a에서는 세션의 플레이어가 `controls`가 꺼져 있고 조준·동작이 없었다. **M2b부터 세션에서도 켜지고 호스트가 정한다** (아래 "M2b")

### HUD (`ui/hud.gd`)

- 자기 캔버스 레이어(10)라 카메라와 저녁 어둠의 영향을 받지 않는다. 핫바 8칸이 화면 아래 가운데(바닥에서 4px), 칸 18px(아이콘 16 + 테 1), 간격 2px. 고른 칸은 금빛 테(#f4c95d 바깥, #9c6a1f 안쪽), 나머지는 #1a1714 / #4a423a 테에 조금 비치는 #2e2a26 바탕. 2개 이상이면 오른쪽 아래에 3×5 숫자(#efe3c6, 그림자 #1a1714), 상급이면 왼쪽 위에 금빛 점 2×2. 글꼴은 쓰지 않는다. Tab이면 나머지 16칸을 핫바 위에 두 줄로 보인다(보기만). 아이템 이름은 보이지 않는다
- 성화 UI(game-concept §10, 2차)가 아니다. 색은 brief §4의 기반·신앙 줄만 썼다

## M2b: 네트워크 + 월드

M2a(혼자 할 때의 아이템·조준·동작)를 세션으로 가져오고, 지상에 채집물과 떨어진 아이템을 더했다. 문서의 ●는 그대로 따르고(호스트 권한 ● game-concept §13, 등급 ● gameplay-design §3.4), 나머지는 [임시값](#임시값-사람-확인-필요) 표의 "M2b" 줄이다.

### 한 가지 규칙: 프레임 (`actors/player_sim.gd`, `Player.make_frame` / `step_frame`)

- 플레이어 시뮬레이션은 이제 **입력 프레임 하나를 한 번 진행하는 규칙 하나**다(`PlayerSim.step`): 방향(8방향), **바라보기(look)**(조준 중이면 마우스 쪽 4방향, 아니면 -1 = M1처럼 걷는 방향), 그 프레임에 시작할 몸 동작(사용이 풀린 결과)과 목표 칸. 순서는 M2a의 `tick_controls` 그대로다(동작 진행·끝 → 사용이면 시작(목표 칸 쪽을 봄: look이 그 칸 쪽이면 look, 아니면 칸의 방향 `Aim.use_facing`, M2-fix) → 동작이 잠그지 않으면 이동 → 동작이 없으면 바라보기는 look 또는 걷는 방향). 동작은 **프레임으로** 센다(프레임당 `ACTION_FRAME_TICKS`)
- 혼자 할 때 `tick_controls` = `make_frame`(키·마우스·사용 버튼 → 프레임, 조준 갱신) + `step_frame`. 호스트는 모든 플레이어를 `step_frame`으로, 클라이언트 예측은 같은 `PlayerSim.step`으로 진행한다. M2a 테스트(동작 시간·잠금·반복)는 그대로 통과한다. 조준 없이 걷는 600틱 시험은 M2-fix에서 M1 규칙을 테스트에 따로 적은 것과 비교하게 바꿨다(위 "조준")
- 세션에서도 내 플레이어는 `controls`가 켜져 있다(마우스 조준, 목표 칸 표시). F6(디버그 동작 차례로)은 혼자 할 때만

### 요청 (`NetProtocol` 입력 패킷, `SessionHost.run_frame`, `items/world_items.gd`)

- 클라이언트가 보내는 것은 여전히 입력 패킷 하나뿐이다(RPC 표에서 클라이언트가 부를 수 있는 것은 hello·입력·done 그대로). **프레임은 1바이트 그대로**이고 코드에 바라보기를 넣었다: 코드 = 방향(0..8) + 9 × (look + 1), 0..44. look이 없으면(-1) M1의 0..8과 같다
- 요청은 그 프레임에 붙는다(프레임 하나에 하나). 패킷 끝에 요청이 있을 때만 `u8 개수` + 요청마다 `u8 프레임 위치, u8 종류, 필드`: 사용 USE(핫바 칸, 목표 칸 s16×2), 줍기 PICKUP(목표 칸), 고르기 SELECT(핫바 칸), 디버그 버리기 DROP(칸, 개수 0=전부, 목표 칸), 디버그 주기 GIVE(아이템 번호 또는 255 = 디버그 묶음, 개수, 등급). 확인 안 된 프레임과 함께 다시 담겨서 잃어도 다음 패킷이 메운다. 요청이 없는 패킷은 M1과 같은 크기다
- 호스트는 **그 프레임을 처리할 때, 그 프레임의 자리에서** 요청을 검사하고 적용한 뒤 프레임을 진행한다(`run_frame`). 호스트 자신의 프레임도 같은 길(키·마우스·봇 → `make_frame`)이다:
  - 사용: 그 칸에 도구가 있어야 하고(빈 칸 `empty slot`, 도구 아님 `not a tool`), 목표 칸이 발 칸의 바로 옆이어야 하고(`out of reach`), 동작이 아직 이어지면 안 된다(`busy`). 거부된 사용은 시작하지 않는다(클라이언트 예측은 다음 상태에서 보정된다). 받아 준 사용의 바라보기는 호스트가 목표 칸에서 정한다(M2-fix: 프레임의 look이 칸 쪽이 아니면 칸 쪽을 본다. 전에는 서쪽을 보며 동쪽 칸을 칠 수 있었다. 같은 규칙이 `PlayerSim.step`에 있어 예측도 같다)
  - 고르기: 예산 밖이다(M2-fix). 프레임 하나에 하나뿐이고 프레임은 입력 게이트가 묶고, 월드를 바꾸지 않으며(상태 묶음의 든 아이템만), 클라이언트가 바로 예측하므로 `rate`로 거부하면 클라이언트 핫바만 다른 칸에 남았다(검토가 패킷 하나를 잃은 실제 세션에서 재현). 핫바 밖 칸(`no such slot`)처럼 거부된 고르기는 그 틱 끝에 주인에게 인벤토리(호스트의 고른 칸 + ack)를 보내 바로잡는다. 받아 준 고르기는 아무것도 돌려보내지 않는다(예측이 맞으므로)
  - 줍기·버리기·주기: 플레이어마다 요청 예산(`NET_OP_INTERVAL_TICKS` 6틱에 하나, 몰아서 `NET_OP_BURST` 4개)을 넘으면 `rate`. 줍기·버리기는 목표 칸이 맵 안·발 옆이어야 하고(`outside the map`, `out of reach`), 줍기는 그 칸에 채집물이 있으면 그것, 없으면 가장 작은 번호의 드롭(`nothing there`), 인벤토리에 안 들어가면 `inventory full`(채집물은 그대로, 드롭은 들어가는 만큼만 줍고 나머지는 남는다). 버리기는 제단 칸이 아니고(`blocked`) 땅의 드롭이 `MAX_DROPS` 256개보다 적어야 한다. 클라이언트의 주기·버리기(디버그 F5·F7)는 호스트가 디버그 빌드이거나 `--test-allow-give`일 때만(`give off`, `drop off`. 버리기는 M2-fix: 전에는 내보낸 release 호스트도 클라이언트의 F7을 받아서, 버리고 줍기를 되풀이하면 지워지지 않는 편집 기록이 초당 약 10개씩 늘었다); 호스트 자신의 주기·버리기(F5, F7, `--give`)는 늘 된다
  - 결과: 월드 변화는 M1의 편집 기록으로(번호 붙은 편집이 모두에게, 늦은 참가자에게는 스냅샷 뒤 편집으로), 인벤토리가 바뀐 플레이어에게는 그 틱 끝에 **자기 인벤토리만** 보낸다(`ack` = 호스트가 처리한 그 플레이어의 마지막 프레임). 거부는 결과 JSON `ops`에 모두 세고, 호스트 로그 `request_refused slot=.. <요청>: <이유> n=<그 이유로 거부된 수>`는 플레이어·이유마다 처음 8줄(`NET_REFUSAL_LOG_FIRST`), 그다음은 60번째마다(`NET_REFUSAL_LOG_EVERY`)만 찍는다(M2-fix: 매 프레임 거부되는 사용을 보내는 클라이언트가 로그를 초당 60줄씩 채웠다)
- 같은 틱의 경주: 호스트는 플레이어를 자리 순서로, 프레임을 번호 순서로 처리하고 편집을 바로 적용한다. 둘이 같은 틱에 같은 것을 주우면 자리 번호가 작은 쪽이 갖고, 다른 쪽은 `nothing there`다(단위 시험: `run_frame`을 손으로 부른 것과, M2-fix부터 `SessionHost.tick` 자체에 자리 2의 프레임을 먼저 넣은 것 + `four` 세션)
- 클라이언트의 키 요청(F, F7, F5, Q/E, `--give`)은 기다리는 줄(`NET_LOCAL_OPS_MAX` 64개, 넘으면 `request_dropped` 줄)에 들어갔다가 줍기·버리기·주기는 호스트와 같은 예산으로, 고르기는 다음 빈 프레임에 하나씩 붙는다. 그래서 호스트가 제때 받으면 사람이 누른 것은 `rate`로 버려지지 않는다. 다만 패킷을 잃어 다음 패킷에 몰려 오거나 호스트가 멈췄다 따라잡으면(틱당 최대 4프레임) 예산 4개를 넘는 줍기·버리기·주기가 `rate`로 거부될 수 있다(M2-fix 검토가 재현. 이것들은 예측하지 않으므로 아무 일도 일어나지 않고 호스트 로그에 남는다. 다시 누르면 된다). 봇의 요청은 그 틱에 바로 붙는다(마구 보내기 시험이 진짜로 매 프레임 보내도록)

### 예측과 보이는 것

- 클라이언트는 자기 사용(동작 시작)을 이동처럼 바로 예측한다(자기 인벤토리 사본으로 도구를 알아본다). 동작이 이어지는 동안은 서 있어도 매 틱 프레임을 기록해 보내서 호스트와 클라이언트가 같은 프레임에서 동작을 끝낸다. 호스트 상태가 오면 (위치·바라보기·동작·동작 프레임)에서 확인 안 된 프레임을 다시 돌린다. `action_corrections`가 예측과 호스트가 다른 상태 수다(세션 시험에서 0). 핫바 고르기도 바로 바꾸고, 호스트의 인벤토리가 오면 호스트가 아직 처리하지 않은 고르기(ack 뒤 프레임에 실린 것, 아직 줄에 있는 것)를 그 위에 다시 얹는다(M2-fix부터 단위 시험이 있다). 서 있어도 조준(look)이 바라보기를 바꾸는 틱에는 프레임을 기록해 보내서 호스트도 같은 쪽을 본다(단위 시험 + `pair`의 c1). 줍기·버리기·주기는 예측하지 않는다(호스트의 편집·인벤토리가 오면 바뀐다)
- 상태 묶음(20Hz, 바뀔 때만 + 키프레임은 그대로)에 플레이어마다 **몸 동작과 그 프레임 수, 든 아이템**을 더했다(14 → 16B: flags 3~6비트 = 동작, u8 동작 프레임, u8 든 아이템). 다른 클라이언트는 보간된 시각에 동작을 시작 틱부터 그린다(두 상태 사이에서 시작해도). 동작 중에는 상태가 매 틱 바뀌므로 동작하는 동안 묶음이 20Hz로 나간다
- 든 아이템은 지금 그림이 없다: 슬라이스는 도구를 몸 동작에 그려 넣었고(● R25) 서 있을 때·걸을 때 손에 든 도구 레이어는 2단계(○ brief §5.6)다. 그래서 다른 사람에게는 **동작할 때 그 도구가 보이고**, 든 아이템은 상태·결과 JSON에만 있다(나중에 도구 레이어가 생기면 쓴다)

### 채집물 (`SurfaceGen`, `WorldItems`, `world/item_view.gd`)

- 생성기의 4단계: `Config.GATHER_ON_GRASS`(야생 회복·버프·독초 8개씩, 버섯 a~d 4개씩, 돌 a·b·c·이끼 6·5·5·4)를 깨끗한 풀에, `GATHER_ON_ASH`(재 버섯 6, 금 간 돌 4, 곰팡이 돌 4: 04-env의 "오염 쪽")를 재에 흩는다. 칸 가운데가 안전 반경 + 1타일 밖, 맵 가장자리에서 2칸 안쪽(`GATHER_EDGE_TILES`), 다른 채집물의 8이웃이 아닌 칸. 시드 1: 74개, 제단에서 가장 가까운 것이 약 13타일. 덤불(herb_clump)은 아이템 표에 있지만 흩지 않는다. 모두 임시값
- 채집물은 **식생(VEGETATION) 레이어**에 산다: 값 = 1 + `WorldItems.GATHERABLES`의 순서(0 = 없음). 그래서 스냅샷·월드 해시·편집 기록이 그대로 덮는다. 줍기 = 그 칸의 식생을 0으로 하는 편집. 다시 자라지 않는다(문서에 없음)
- 등급(● gameplay-design §3.4, §3.0 표 "공용 수행 … 일반 등급 약초만"): 약초사가 캐면 약초 넷은 상급, 다른 클래스는 일반. 버섯·돌은 등급이 없다(M2a 임시값 그대로)
- 그림: `ItemView`가 채집물마다 월드 그림(04-env v02, M2a에서 복사한 것), 드롭마다 아이콘을 `Entities`(발 y 정렬) 아래 Sprite2D로 둔다. 노드는 그 칸의 아래 변에 있어서 그 칸 안에 발이 있는 캐릭터는 채집물 뒤, 남쪽 칸의 캐릭터는 앞에 그려진다. 캐릭터와 같은 hard 빛 레이어. 걸음을 막지 않는다(문서에 없음)

### 떨어진 아이템 (드롭, `WorldData.drops`)

- 디버그 F7(임시값 키)이 고른 칸의 묶음 전부를 목표 칸 가운데에 버린다(봇 `drop[:<개수>]`). 칸 하나에 여러 개가 쌓일 수 있고, F는 번호가 가장 작은 것부터 줍는다
- 누가 버렸든 **먼저 주운 사람 것**이다(○ gameplay-design §5 "드롭은 주운 사람 것", 임시값). 보스 드롭 분배는 M2 밖
- 드롭은 타일이 아니라 월드의 목록(번호, 아이템, 개수, 등급, 픽셀 자리)이다. 월드 해시가 덮고, 스냅샷 원본 끝에 `u16 개수 + 11B × 드롭`으로 들어가고(받는 쪽이 아이템·개수·등급·맵 안·번호 중복을 검사), 편집 기록에 "드롭 놓기/바꾸기"(절대값, 16B)와 "드롭 사라짐"(9B) 편집이 더해졌다. 그래서 스냅샷을 보내는 도중에 생긴 드롭도 welcome 뒤 편집으로 간다(`stall` 세션)

### 늦은 참가 (M2b)

- 참가자는 스냅샷으로 채집물(식생 레이어)과 드롭을, welcome의 플레이어 정보로 모두의 든 아이템·동작을 받는다. 그 뒤의 줍기·버리기는 편집으로 온다. welcome 로그에 `gatherables=.. drops=..`
- **다시 참가해도 인벤토리는 이어지지 않는다**: M1에 다시 참가 기억이 없어서 새 참가자는 빈 인벤토리로 시작하고, 나간 플레이어의 인벤토리는 호스트에서 사라진다(저장은 M2 밖)

### 전송 형식 버전 3 (`NetProtocol.VERSION`)

입력 프레임 코드(바라보기), 입력 패킷의 요청, 상태 16B·정보 17B, 인벤토리 메시지(호스트 → 주인, 채널 0 reliable, 6 + 3B × 24칸 = 78B), 드롭 편집, 스냅샷의 드롭. 버전 2 클라이언트는 `version`으로 거부된다.

## M3a: 지도 · 던전 · 채굴 · 횃불

혼자 할 때 먼저(M3a 지시). 문서의 ●는 그대로 따르고(채굴 3단 접근 ● gameplay-design §3.0 R11, 레이어 ● §3.1, 16px ● R18), 나머지는 [임시값](#임시값-사람-확인-필요) 표의 "M3a" 줄이다. 세션(`--host`/`--join`)은 지상 하나뿐이고 M2b 그대로 돈다(아래 "세션에서").

### 지도 (`GameWorld.map_id`, `Main.worlds`, `Main.travel`)

- 지도 하나 = `world.tscn` 하나(GameWorld: 데이터, 바닥/동굴 그림, 엔티티, 빛). `main.tscn`의 `World`가 지상이고, 혼자 할 때 Main이 같은 장면을 하나 더 만들어 `Dungeon`(`map_id` 1)으로 둔다. 한 번에 하나만 보인다: 숨긴 지도의 `CanvasModulate`(어둠)와 빛은 적용되지 않고(F4·F3도 보이는 지도만 받는다), 먼저 숨기고 나서 보인다(순서가 바뀌면 어둠이 흰색으로 풀린다)
- 내 캐릭터는 늘 한 지도에 있다: `travel()`이 Player 노드를 그 지도의 `Entities`로 옮기고 `Player.data`를 그 지도의 데이터로 바꾸고(`Player.set_world`: 남쪽을 보고, 동작은 멈춤), 도착점에 세운다. 카메라 경계, 목표 칸 표시(그 지도의 바닥과 엔티티 사이로 옮김)도 같이 바뀐다. 더미는 지상에 남는다
- 도착점: 던전은 출구 계단 바로 남쪽 두 칸의 가운데(`DungeonGen.arrival_point`), 지상은 입구 바로 남쪽(`DungeonGen.arrival_below`)
- F(M2의 상호작용 키)가 목표 칸이 입구·계단(`WorldItems.is_portal`)이고 손이 닿으면 다른 지도로, 아니면 M2의 줍기

### 던전 생성 (`world/dungeon_gen.gd`)

- `DungeonGen.generate(seed)`: 같은 시드 → 같은 던전. 정수 난수(PCG32)와 칸 계산뿐이라 지상의 FastNoiseLite와 달리 다른 아키텍처에서도 같을 것이다(재 보지는 않았다). 시드 1의 해시 `DungeonGen.GOLDEN_HASH` = `009e7147ad7969ac9098fc6cd2afcd4a` (x86_64)
- 순서: 바위로 채우고 테두리 2칸 기반암 → 방 7개(7~12 × 6~9, 서로·테두리에서 3칸) → 방마다 이미 이은 가장 가까운 방과 3칸 너비 L자 통로 → 출구 계단(방 위쪽 줄의 앞면 칸 2개, 그 위 바위는 기반암) → 도착 방에서 가장 먼 방 가운데에 이단의 제단 자리(3×2) → 광맥(구리 9 · 철 5, 2~5칸, 걸을 수 있는 바닥 옆 바위에서 시작) → 방마다 북쪽 벽에 벽 횃불(6칸마다, 도착 방은 계단 양옆). 도착 방 = 통로를 낸 뒤 계단 자리가 남은 첫 방
- 시험(40시드): 기반암 테두리, 계단은 앞면 칸이고 그 위는 깰 수 없음, 도착점에 설 수 있고 계단 바로 남쪽, 제단 자리는 바닥이고 도착점에서 닿음, 열린 바닥 전부가 한 덩어리(갇힌 곳 없음), 광맥마다 걸어서 닿는 칸에서 캘 수 있음, 두 광석이 다 있음, 벽 횃불은 앞면 있는 바위 위, 바닥 레이어 0, 동굴 그림 = 규칙. 시드 1: 방 7, 광석 칸 47, 벽 횃불 8, 열린 칸 511

### 벽과 앞면 (`world/walls.gd`, `world/cave_view.gd`)

- 04-env 던전 타일셋은 절벽(cliff) 셋이다: 코너 값이 바닥(lower)·벽 윗면(upper)·앞면(transition) 셋이고, JSON이 "앞면은 경계 **아래** 칸을 차지한다"고 적어 둔 규칙대로 쓴다. 꼭짓점(= 월드 칸 가운데) 값 = 벽 칸이면 벽, 벽 바로 아래 바닥 칸이면 앞면, 아니면 바닥, 맵 밖은 벽(`Walls.vertex`). 그림 칸·청크·반 칸 밀림은 지상 dual grid 그대로다(`CaveView`, 청크 32)
- 벽의 앞면(24px, 타일에서 잼: 벽 칸 가운데 줄 3px 아래부터)은 벽 아래 칸 위에 그려진다. 그래서 **그 앞면 칸은 막힌다**(`Walls.blocks`, 걷기 충돌 = 그려진 것). 앞면 칸을 조준하면 그 위의 벽을 친다(`Walls.owner_of`). 남쪽에서 벽 쪽으로 걸으면 발이 앞면 아래 끝에 딱 붙어 서서 캐릭터가 앞면 앞에 그려지고, 북쪽에서 붙으면 벽 윗면이 발 아래(남쪽)라 겹치지 않는다(벽이 캐릭터를 가릴 일이 없어서 벽을 y 정렬하지 않았다)
- 결과: 가로 굴은 두 줄 이상이어야 들어갈 수 있다(위 줄은 윗벽의 앞면). 광부의 3×3은 자연히 그렇고, 다른 클래스는 두 줄을 판다. 세로 굴은 한 줄도 된다
- 타일 고르기(`CaveTable`): 코너 키 81개 중 셋에 그림이 있는 21개, 키 넷은 타일이 둘이라 위·아래 꼭짓점(JSON `pattern_4x4`의 바깥 줄, "context")이 맞는 쪽을 쓴다(예: 벽의 서쪽 가장자리 위 끝 t1_10과 그냥 t1_4). 속 타일 변형(바닥 3, 벽 윗면 2)은 지상처럼 칸 위치 해시로. 셋에 없는 키(앞면 바로 아래 벽 윗면, 한 줄 차이로 끝나는 두 벽 등)는 가장 가까운 키(코너마다 앞면↔벽 1, 앞면↔바닥 1, 벽↔바닥 2)로 그리고 `verify()`가 fallback으로 센다. 생성된 던전 40개에 모두 19칸, 마구 깬 뒤에는 많아진다(시드 1에서 무작위 편집 120번 뒤 111칸): 깬 자리의 모양에 따라 앞면이 짧게 끊겨 보인다(알려진 문제)
- 광맥 그림: 04-env `tiles_ore_*_v02`는 벽 윗면 타일에 광석을 박은 16×16이라, 같은 윗면 타일과 다른 픽셀(22~36개)만 떼어 벽 칸 위에 얹는다(앞면 있는 벽은 앞면 위까지만). 구리·철 a/b는 칸 해시로
- 금: 맞은 벽은 `Walls.crack_stage`(최대 타격의 1/3씩, 1~3단계)의 04-env `wall_crack_top_v01`을 윗면에, 앞면이 보이는 벽은 `wall_crack_face_v01`을 앞면에도 얹는다(04-env 던전 목업의 자리)
- 편집 하나를 다시 그리는 범위: 그 칸과 아래 칸이 코너나 둘레에 드는 그림 칸(가로 2 × 세로 5)과 위·아래 칸의 오버레이. 무작위 편집 120번을 제자리에서 다시 그린 그림 = 새로 그린 그림(시험)

### 채굴 (`items/mining.gd`)

- ● gameplay-design §3.0 R11 광부 줄: 공용 = "누구나 채굴. 느리고 1×1, 경도 상한", 전용 = "3×3 고속, 상위 경도". 그대로 광부만 3×3, 광부의 휘두르기는 타격 2배, 경도 상한은 공용 1 · 광부 2. 숫자는 임시값: 경도 바위 1 · 구리 1 · 철 2 · 기반암 깰 수 없음, 깨지는 타격 바위 6 · 구리 8 · 철 10, 휘두르기 한 번 공용 1 · 광부 2타. 그래서 바위 한 칸에 공용 6번(3.6초), 광부는 3번에 3×3 아홉 칸. 철은 광부만
- ○ §3.2의 "마우스 방향의 인접 타일을 타격, 홀드하면 연속"은 M2의 목표 칸·누르고 반복 그대로. 휘두르기는 곡괭이 동작의 4번째 프레임(`MINING_IMPACT_FRAME` 3, 18틱째)에 맞는다(M2 `m2_use.png`의 그 프레임이 땅을 친다)
- 3×3이 어디로 뻗는지는 문서에 없다(임시값 `MINER_AREA_AWAY`): 친 칸에서 시작해 플레이어 반대쪽으로 3칸, 휘두르는 방향의 가로로는 가운데. 대각선은 그 구석에서 뻗는다. false면 친 칸 가운데
- 맞은 칸은 타격이 쌓이고(벽 바이트 위 4비트), 최대에 닿으면 깨진다: 바위 → 돌 a(`MINED_ROCK_ITEM`), 광석 칸 → 구리/철 광석. 인벤토리에 넣고, 안 들어가면 그 칸 가운데에 드롭(○ §3.2 "채굴 시 드롭은 인벤토리로 자동"에서 가득 찼을 때는 임시값), 땅의 드롭이 `MAX_DROPS`면 사라짐. 벽 횃불은 그 벽과 같이 없어진다
- 아무것도 깰 수 없는 곳(기반암 테두리, 계단 위 바위, 그 클래스에 너무 단단한 칸, 벽이 아닌 곳)은 휘두르기만 하고 아무 일도 없다. 지상에는 벽이 없으니 곡괭이는 M2 그대로다
- 이단의 제단은 벽이 아니라 칠 수 없다(파괴는 M4)

### 횃불 (`WorldItems.place`, `world/fixture_view.gd`, `light/torch_light.gd`)

- ● gameplay-design §3.0 R11 표의 "기본 키트 (횃불, 발판)"의 횃불. 상인(M8) 대신 디버그(F5 묶음 10개, `--give=torch:<수>`)로 받는다. 아이템 종류 "놓는 것"(`ItemDB.Kind.PLACEABLE`), 묶음 99(재료와 같은 값)
- 핫바에서 고르고 좌클릭 = 목표 칸에 하나 놓는다(누르고 있어도 한 번). 놓을 수 있는 칸: 손 닿는 칸, 벽·앞면·설치물·채집물이 없는 바닥(드롭은 있어도 됨). 걸음을 막지 않고 다시 줍지 못한다(임시값). 지상에도 놓을 수 있다
- 빛만이다: 안전 반경(`SafeZone`)은 여전히 제단 하나다(횃불이 안전인지는 문서에 없다). 횃불 빛 = 반경 80px의 딱딱한 네 단계(1 / 0.7 / 0.45 / 0.22, 디더 없음), 바닥과 캐릭터를 다 비춤. 벽 횃불은 48px
- 그림: 횃불 아이템 그림이 없어서 놓은 횃불은 04-env 땅 랜턴 켜짐판(`prop_lantern_ground_v03_lit`, 목업에서 플레이어가 놓은 빛)과 그 빛 마스크(unshaded), 아이콘은 코드로 그린 작은 랜턴(임시)

### 어둠

- 던전은 `DUNGEON_DARK_COLOR`(0.13, 0.11, 0.10) 하나이고 제단 빛이 없다. 빛은 놓은 횃불과 벽 횃불뿐. F4는 어둠과 횃불 빛을 같이 끈다(그림 원래 색)

### 세션에서 (M3a, M3b에서 끝남)

- (M3b에서 바뀜: 아래 "M3b: 세션의 지도") M3a의 세션은 M2b 그대로 지상만이었다: 던전 GameWorld를 만들지 않고, 입구에 F(줍기 요청)를 보내면 호스트가 `dungeon offline only`로 거부했다. 전송 형식은 v3 그대로
- 같은 규칙을 호스트도 쓴다: 횃불 USE는 호스트가 놓고(요청 예산은 줍기와 같음, 편집 + 인벤토리), 곡괭이가 맞는 틱에 호스트가 채굴한다(지상엔 벽이 없어 아무 일도 없다). 클라이언트는 횃불 놓기를 예측하지 않는다
- 세션의 지도(플레이어마다 지도 번호, 던전 스냅샷, 지도별 편집과 상태)는 M3b에서 넣었다

### 시험 (M3a)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=dungeon,mining < /dev/null   # 약 9초
```

- `test_dungeon.gd`: 던전 타일셋(새로 만든 것 = 커밋된 것, 절벽 타일 25장의 코너·둘레, context로 고르기, 없는 키의 fallback), 생성 규칙 40시드(위 "던전 생성"), 같은 시드 = 같은 던전과 황금 해시, 지상 입구 40시드(하나, 막힘, 빛 밖, 남쪽에 설 수 있음, 시드 1은 원래 자리, 채집물 74개 그대로), 동굴 그림 = 규칙과 무작위 편집 120번을 제자리에서 다시 그린 것 = 새로 그린 것, 충돌(벽·앞면이 막음, 북쪽으로 걸으면 앞면 아래 끝에 딱 붙음, 서쪽 벽, 대각선 미끄러짐, 횃불은 안 막음, 위 벽을 깨면 앞면이 한 칸 위로), 예측(던전에서 1,500틱 무작위로 걸으며 벽에 부딪혀도 호스트 `PlayerSim`과 6틱 늦은 보정이 늘 0), 던전 월드 장면(동굴 그림, 제단 없음, 어둠, 계단·제단·벽 횃불과 빛, F4), 지상 월드 장면(입구와 잔해 장식), `main.tscn`에서 F로 내려가고 올라오기(지도·플레이어 부모·데이터·도착점·카메라 경계·표시·더미), 세션 호스트가 입구를 거부
- `test_mining.gd`: 벽 바이트, 앞면과 맞는 벽, 경도·타격 수, 금 단계 표, 3×3 모양(동·북동·앞면 너머 북), 공용(한 칸, 6번에 깨짐, 금 1·1·2·2·3, 철은 너무 단단함, 두 칸 떨어진 벽은 못 침), 광부(매번 3×3 아홉 칸, 3번에 바위 8칸이 깨지고 철은 남음, 철 광석), 가득 찬 인벤토리 → 드롭, `MAX_DROPS` → 사라짐, 벽 횃불이 벽과 같이, 계단 위 바위·기반암은 안 깨짐, 지상에서 곡괭이는 아무 일 없음, 금 오버레이 자리, 횃불 놓기 규칙 8가지와 `make_frame`(클릭에 한 번), 횃불 그림과 빛(안전 반경 아님), 호스트 `run_frame`(클라이언트의 횃불 USE, 곡괭이가 18틱째에 맞음, 그림이 편집을 따라감), `main.tscn`에서 봇으로 광부가 앞면 위 바위를 깸
- 창 그림 검사 `cave`·`dark` (위 "그림 검사")

## M3b: 세션의 지도

M3a가 혼자 할 때 더한 것(지도 둘, 던전, 채굴, 횃불, 그 드롭)을 세션으로 가져왔다. ● 호스트 권한(game-concept §13)대로 M3가 더한 것을 모두 호스트가 정한다. 새 임시값은 "M3b" 줄이고, 그 밖은 [구현에서 고른 값](#구현에서-고른-값-설계-결정-아님)의 "M3b" 줄이다.

### 지도 번호와 오가기 (`NetMember.map_id`, `SessionHost._travel`, `WorldItems.travel`)

- 플레이어마다 지도 번호가 **호스트 상태**다. 호스트는 지도마다 GameWorld를 가진다(`NetSession.worlds`: `main.tscn`이 지상 `World`와 던전 `Dungeon`을 만들고, 호스트는 던전을 자기 생성기로 만든다). 멤버의 Player 노드는 그 지도의 `Entities` 아래에 있고 그 지도의 데이터 위에서 걷는다(벽 충돌)
- 입구·계단의 F는 요청이다: 클라이언트(와 호스트 자신)의 F(PICKUP)가 자기 지도의 입구·계단 칸을 겨누면 프레임에 붙을 때 `TRAVEL`(지도 + 칸)로 바뀐다(`SessionHost.attach_local_op`). 호스트는 그 프레임의 자리에서 검사한다: 겨눈 지도가 그 멤버의 지도가 아니면 `wrong map`, 줍기와 같은 요청 예산(`rate`), 그 멤버에게 앞 지도를 아직 보내는 중이면 `still loading`, 그다음 `WorldItems.travel`(맵 안, 손 닿는 칸(`REACH_TILES`), 그 칸의 길이 가는 지도: 입구 → 던전, 계단 → 지상. 아니면 `no way there`). 혼자 할 때 `Main.pick_up`도 같은 함수다
- 받아 주면 바로 옮긴다(`move_to_map`): 지도 번호, 노드를 그 지도의 `Entities`로, 도착점에 남쪽을 보고 동작은 멈춤(`Player.set_world`, M3a와 같은 자리). 그 프레임의 걸음은 새 지도에서 진행된다. 호스트 자신이면 바로 그 지도를 보인다(`local_map_changed` → `Main._show_map`). 클라이언트에게는 그 지도를 보낸다(아래). 입구에 PICKUP이 오면 `a way to another map`(줍는 것이 아님)
- 클라이언트는 오가기를 예측하지 않는다: F 뒤에도 지도 들어옴 메시지가 올 때까지(localhost 한두 프레임, 실제 망에서는 왕복 + 지도 조각) 옛 지도에서 걷는다. 메시지가 오면 새 지도로 바뀌고 그동안의 프레임을 새 지도에서 다시 돌린다(아래 "예측")
- 늦은 참가자는 지금처럼 지상에 도착한다. 다시 참가해도 지도는 이어지지 않는다(지상에서 시작, 인벤토리처럼)

### 지도 보내기: 클라이언트는 자기 지도만 (`SessionHost._stream`, `_enter_map`, `SessionClient.on_map_entry`)

**정한 것: 클라이언트는 자기가 있는 지도만 받는다. 들어갈 때 그 지도의 스냅샷을 받고, 그 뒤로는 그 지도의 편집만 받는다.** (다른 길: 모든 지도의 모든 편집을 모두에게 보내고 참가 스냅샷에 지도를 다 넣기)

- 트래픽: 편집이 가장 많은 일은 채굴이다(광부 휘두르기 한 번 = 칸 편집 최대 9개 + 광석·벽 횃불·드롭 편집, 0.6초마다). 고른 방식에서는 지상에 있는 사람이 던전의 채굴 편집을 하나도 받지 않는다(`cave` 세션: 호스트가 내려가 판 편집 7개가 지상의 c1에게 0개). 그 대신 들어갈 때마다 지도 전체를 받는다: 시드 1 던전 64×48 = 원본 18.4KB → 압축 309~345B, 조각 1개(지상은 566~582B). 던전이 여러 개가 되거나 커지면(슬라이스 밖) 차이가 더 벌어진다
- 단순함: 늦은 참가 스냅샷 길(H1, PR #48)을 그대로 쓴다. 같은 `WorldSnapshot`(머리말에 지도 번호만 더함, M3b) · 같은 조각 크기와 틱당 8조각 · 같은 받는 쪽 검사(조각 수·크기·md5·월드 해시 + 기대한 지도 번호) · "스냅샷 위치 + 그 뒤 편집" 규칙. welcome 대신 **지도 들어옴** 메시지(지도, 그 지도 편집 기록의 스냅샷 위치, 스냅샷 수, 그 지도에서의 자기 상태)를 보내고, 받는 동안 생긴 그 지도의 편집은 그 뒤에 번호대로 보낸다. 클라이언트는 떠난 지도의 데이터·편집 기록을 버리고(다음에 들어올 때 새로 받는다), "그동안 무엇을 놓쳤나"를 따로 계산하지 않는다
- 순서: 채널 0(reliable) 하나라 "그 지도의 조각 → 지도 들어옴 → 그 지도의 편집"이 순서대로 온다. 그 플레이어는 받는 동안에도 상태 묶음·출입은 받는다(늦은 참가와 다른 점). 받는 중인 멤버에게는 그 지도의 실시간 편집을 보내지 않는다(`peers_on`). 단위 시험: 1바이트 조각 309개(39틱)로 받는 동안 호스트가 캔 편집이 지도 들어옴 뒤에 간다
- 편집 기록은 지도마다 따로다(`NetSession.log_for`, 번호도 지도마다 0부터). 편집 메시지에 지도 번호를 더했다: 클라이언트는 자기 지도가 아닌 편집을 잘못된 메시지로 센다(호스트는 보내지 않는다)
- 클라이언트의 지도 들어옴: 조각을 검사해 그 지도의 GameWorld에 올리고(`load_data`: 동굴 그림, 횃불, 드롭), 자기와 남의 Player 노드를 그 월드로 옮기고, 예측을 새 데이터로 바꾸고(`Prediction.switch_map`), Main에 알린다(`local_map_changed`: 지도·카메라·표시·어둠). 로그 `map entered map=dungeon world=... bytes=345 raw=18456 chunks=1 edits=7 drops=0 torches=1 cracked=6 build_ms=62.3`, 떠난 지도는 `map_left map=dungeon edits=.. world=..`

### 상태와 그리기 (`NetProtocol` 상태 17B, `Interpolation`, `SessionClient.draw_others`)

- 상태 묶음의 상태마다 지도 번호(u8)를 더했다(16 → 17B, 정보 18B). 묶음은 여전히 모든 플레이어를 담아 모두에게 간다: 자기 지도의 사람만 그리고(`Player.visible`), 다른 지도의 사람은 위치만 따라간다(결과 JSON의 위치 해시가 지도까지 같은지 본다). 지도별로 나눠 보내지 않은 이유: 묶음이 작고(사람당 17B), 누가 지도를 옮겼는지가 묶음·키프레임 흐름에 그대로 실려 따로 메시지가 필요 없다. 지상의 c1은 호스트가 던전에서 캘 때 초당 약 1.07KB(상태만)를 받는다(아래 측정). 9인이 지도 둘에 흩어지면 지도별 묶음이 더 싸다(알려진 문제)
- 보간: 다른 지도의 상태가 오면 그 사람의 버퍼를 비우고 새 지도에서 다시 시작한다. 두 지도 사이를 섞어 그리지 않는다(단위 시험)
- 늦은 참가자의 welcome에도 플레이어마다 지도가 있어 던전에 있는 사람은 지상에 그리지 않는다(`cave` c2, `four` c4. 로그 `welcome ... elsewhere=2`)
- 호스트 화면도 같다: 다른 지도의 멤버는 숨긴 GameWorld 안에 있어 그려지지 않는다

### 채굴·횃불·드롭 (호스트 검사)

- 채굴은 두 번 검사한다. 사용(USE): 그 칸에 곡괭이, 목표 칸이 발 옆, 동작 중이 아님(`busy`: 휘두르기 하나가 끝나야 다음, 그래서 동작 길이가 채굴의 속도 제한이다), 겨눈 지도가 그 멤버의 지도. 맞는 틱(`Mining.impact_tick`): 그 멤버의 지도 데이터에서 `Mining.strike`(벽인지, 손 닿는지, 경도·클래스 상한, 3×3). 아무것도 못 깬 휘두르기는 이유별로 센다(결과 JSON `swings_missed`: `no wall`, `too hard`). 기반암 테두리·출구 위 기반암은 공용·광부 모두 `too hard`(편집 없음)
- 금(맞은 횟수)·깸·광석·벽 횃불이 떨어지는 것·가득 찼을 때 드롭은 모두 그 지도의 번호 붙은 편집이다(벽 바이트 위 4비트 = 맞은 횟수라 금이 다른 사람에게 그대로 보인다). 횃불 놓기(요청 예산)도 같다
- 같은 칸을 같은 틱에 둘이 치면: 호스트는 자리 순서로 처리하고 편집을 바로 적용한다. 그 칸이 한 번 남았으면 자리가 작은 쪽이 깨고 돌을 갖고, 다른 쪽 휘두르기는 `no wall`(그 앞면을 쳤다면 위 벽이 없어져 앞면도 아니다). 두 번 남았으면 둘 다 맞고 두 번째가 깨고 갖는다. 광부 둘의 3×3이 겹치면 겹친 칸마다 한 번씩만 깨지고 아이템은 그 칸을 깬 쪽 하나에. 규칙: **그 칸을 깬 타격의 주인이 갖는다** (`test_net_maps.gd`의 세 경우, `four` 세션은 실제 세션에서 정확히 한 번 깨짐과 깬 쪽의 돌을 본다. 실제 세션에서 같은 틱은 맞추지 못했다: c2·c3가 4틱 차이로 맞았다)

### 예측 (`Prediction`)

- 예측은 클라이언트가 가진 그 지도의 데이터(호스트 편집이 적용되는 같은 `WorldData`)로 걷는다. 데이터는 호스트보다 늦을 뿐 벽이 생기지는 않으므로(벽은 깨지기만 한다) 클라이언트는 "호스트가 이미 깬 벽"에 막힐 수만 있다. 그동안은 호스트 상태가 보정하고, 다시 돌릴 때 그 벽 안에서 시작해도 이미 겹친 장애물은 무시해서(`Movement`) 빠져나온다. 편집이 오면 다음 상태부터 맞는다: 단위 시험(편집 0·30·90틱 늦게, 6틱 지연)에서 보정 0·2·3번, 편집이 온 뒤로는 0번, 마지막 위치 같음
- 지도를 옮기는 동안: 클라이언트의 상태 중 다른 지도의 것(지도 들어옴보다 먼저 온 묶음)은 맞추지 않고 센다(`other_map`). 지도 들어옴의 상태(그 플레이어가 마지막으로 처리된 프레임 뒤)에서 확인 안 된 프레임을 새 지도에서 다시 돌린다(`switch_map`, 보정으로 세지 않음). 옛 지도를 겨눈 사용은 호스트가 `wrong map`으로 거부하므로 다시 돌릴 때도 동작을 시작하지 않는다(`Prediction.anim_on_map`)

### 전송 형식 버전 4 (`NetProtocol.VERSION`)

상태 17B(+ 지도), 정보 18B, 타일 요청(USE 6B, PICKUP 5B, DROP 7B)에 겨눈 지도 u8, 새 요청 TRAVEL(지도 u8 + 칸 s16×2 = 5B), 편집 메시지에 지도 u8(칸 11B, 드롭 놓기 17B, 드롭 사라짐 10B), 스냅샷 머리말에 지도 번호(22B), 새 RPC `_rpc_map`(지도 들어옴 66B: 지도, 편집 위치, 원본·압축 크기, 조각 수, md5 둘, 자기 상태). 입력 프레임은 1바이트 그대로다(TRAVEL도 프레임에 붙는 요청). 버전 3 클라이언트는 `version`으로 거부된다.

### 시험 (M3b)

- `test_net_maps.gd` (위 "네트워크 테스트"), `test_net_session.gd`의 `cave` 세션과 `four`의 던전 경주. `_check_agreement`가 지도별로 바뀌었다: 모든 인스턴스의 모든 지도(호스트는 전부, 클라이언트는 자기 지도)가 그림 = 데이터(지상은 대체 타일 0, 던전은 대체 타일을 세지 않음), 클라이언트의 지도 = 호스트의 그 지도(해시, 그림 해시, 편집 수, 채집물, 드롭), 위치 해시에 지도까지
- `test_dungeon.gd`의 세션 시험은 "입구 거부" 대신 "호스트가 멤버를 내려보내고 올려보냄"이다. 시드 1~8 던전 해시 묶음
- 창 그림 검사 `cave_net`, 스모크 M3b 항목

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
- **늦은 참가 = 월드 스냅샷** (H1, game-concept §13 ○ "늦은 참가 스냅샷 스트리밍"): 호스트는 참가자를 받는 순간의 월드(`WorldData` 레이어 6장 전부 + 크기·시드·제단 자리)를 `WorldSnapshot`으로 묶어 zstd로 압축하고, 1KB(`NET_SNAPSHOT_CHUNK_BYTES`) 조각으로 잘라 틱마다 최대 8개(`NET_SNAPSHOT_CHUNKS_PER_TICK`, 틱당 8KB = 480KB/s)씩 reliable 채널 0으로 보낸다. 마지막 조각을 보낸 그 틱에 welcome(자리, 지금의 플레이어들, 스냅샷의 편집 기록 위치, 원본·압축 크기, 조각 수, 압축 바이트 md5, 월드 md5, 진단용 생성기 해시. 시드는 스냅샷 머리말에만 있다)을 보내고, 스냅샷 뒤에 생긴 편집을 번호와 함께 이어서 보낸다. 그때부터 그 참가자는 묶음·편집·출입·go를 받는다(그 전에는 받지 않아서, 채널 0 하나의 순서대로 "월드 → welcome → 나머지"가 된다). 클라이언트는 조각을 순서대로 모으고(순서가 틀리거나 1KB를 넘거나 상한을 넘으면 끊음), welcome에서 조각 수·크기·md5를 맞춰 본 뒤 풀어서 월드를 만들고 그 `content_hash()`가 호스트의 월드 md5와 같은지 확인하고(다르면 종료 코드 5) 그 월드를 그린다(`GameWorld.load_data`). **자기 생성기로 만들지 않는다.** 시드와 생성기 해시는 진단뿐이다: 자기 생성기로 스냅샷 머리말의 시드로 월드를 만들어 호스트 생성기 해시와 비교해 `generator=match|differs`를 찍는다(실패 아님. 결과 JSON의 클라이언트 `generator_hash`는 welcome 전에는 빈 값). M1 월드 128×96 = 73,749B → 341~342B, 조각 1개. 받는 쪽 크기 상한(H-fix): 한 변 `MAX_SIDE` 512칸(M1 맵 가로의 4배), 압축 바이트 `MAX_PACKED` 약 1.6MB. 압축이 전혀 안 되는 최대 월드도 틱당 8KB로 약 3.3초라 접속 제한 10초 안에 다 오고 `load_data`가 1초 안쪽이다(예전 2048은 약 25MB라 받을 수 없는 크기까지 받아 주었다). 접속 제한에 걸렸는데 조각이 오고 있었으면 이유가 `not admitted`가 아니라 `world not complete within 10 s (<조각> chunks, <바이트> B so far)`다 편집은 "칸 = 값" 절대값이라 두 번 적용해도 같다. M1에는 게임 편집이 없어서 호스트의 디버그 편집(봇 `edit:`, 풀 ↔ 흙만)으로 길을 시험한다
- **이동은 호스트가 정한다**: 클라이언트는 입력 프레임(번호, 8방향)만 보낸다. **바라보기는 보내지 않는다** (H1): 호스트가 방향에서 클라이언트와 같은 규칙(`Movement.facing_for`, `Player.apply_input`)으로 정한다. 프레임 하나 = 1바이트(코드 0..8, 9 이상은 버림). **M2b에서 바뀜**: 조준 중에는 마우스 쪽 바라보기(look)를 프레임 코드에 실어 보낸다(코드 0..44, 아래 "M2b"의 "요청"). look이 없는 프레임의 바라보기는 지금도 호스트가 방향에서 정한다. 클라이언트 예측은 호스트가 이 프레임 뒤에 정할 바라보기를 미리 계산해 두고, 호스트 상태와 다르면 `facing_corrections`로 센다(테스트에서 늘 0). 움직이는 동안과 멈춘 첫 틱에만 프레임이 생기고(서 있으면 아무것도 안 보냄), 2틱마다(30Hz) 호스트가 아직 확인하지 않은 프레임을 전부 다시 담아 unreliable로 보낸다(패킷 하나를 잃어도 다음 패킷에 들어 있다). 호스트(`InputGate`)는 번호 순서대로 한 번씩만, 축마다 −1..1로, **실제로 흐른 시간** 한 틱마다 토큰 하나(최대 30개 모아 둠)만큼만 적용해서 실제 시간보다 빨리 걸을 수 없다. 받은 프레임은 틱마다 하나씩(3개 넘게 밀리면 더, 단 틱당 최대 4개 `NET_INPUT_CATCH_UP_FRAMES`, H-fix) 적용해서 다른 사람 눈에 고르게 걷고, 밀렸을 때는 걷는 속도의 4배까지로 따라잡는다(한 번에 뛰지 않음). 호스트 자신의 캐릭터는 키를 바로 적용한다
- **호스트가 멈췄다 돌아올 때** (H1, H-fix에서 고침): 토큰은 `take()` 횟수가 아니라 실제 시간(호스트 틱 사이 `Time.get_ticks_usec`, `InputGate.ticks_between`)으로 채운다. 긴 프레임으로 틱을 놓치면 그 시간만큼(한 번에 최대 64틱) 채우고, 기다리는 프레임 수만큼은 모아 두는 상한(30)을 넘어도 된다(그 프레임들은 정말 그만큼 오래된 것이라). **그런데 Godot은 한 프레임에서 물리 틱(따라잡기 틱 포함)을 먼저 돌리고 네트워크는 그 뒤 process 단계에서 읽는다**(`SceneTree.process`의 multiplayer poll). 그래서 멈춤이 물리 틱 밖(그리기, `_process`, RPC 처리, 운영체제)에서 났으면, 놓친 시간을 재는 첫 따라잡기 틱에는 멈춘 동안 온 프레임이 아직 대기열에 없고, 상한이 채울 시간을 버렸다. 프레임은 그다음 poll에 한꺼번에 들어와 걷는 동안 내내 약 30프레임(0.5초) 뒤처졌다(H1 검토가 실제 세션에서 찾음. H1의 단위 시험은 프레임을 따라잡기 틱 전에 넣어서 물리 틱 안의 멈춤만 흉내 냈다). H-fix: 놓친 틱의 채움 중 상한이 자른 몫을 **멈춤 크레딧**(`hitch_credit`)으로 실제 시간 30틱(`InputGate.HITCH_CREDIT_TICKS`, 0.5초) 동안 들고 있다가, 그동안 들어와 상한 위에서 기다리는 프레임에 쓴다. 크레딧은 더해지지 않고 더 큰 멈춤이 바꿔 넣으며(30fps 호스트에서 서 있는 클라이언트가 모을 수 있는 크레딧은 1틱), 토큰은 여전히 실제 시간에서만(바로, 또는 크레딧으로 조금 늦게, 한 번만) 나오므로 "실제 시간 + 30프레임보다 빨리 못 걷는다"는 그대로다. 멈춘 동안 서 있다가 몰아 보내는 클라이언트도 멈춘 시간만큼만 더 간다(단위 시험). 결과: 실제 세션(`stall`: 0.7초 멈춤, 대기열 최고 42프레임)에서 속도 제한에 걸린 틱이 194~204 → 0, 크레딧 약 39틱 사용. 단위 모형(1초 멈춤)은 두 순서 모두 30틱 뒤 대기열 4 이하, 제한 0. 크레딧 없이(H1 규칙) 돌리면 틱 밖 순서에서 대기열 31, 제한 409틱으로 시험이 실패한다
  - 한계: 멈춤이 약 1초(64틱)를 넘으면 대기열 상한 64를 넘는 프레임은 버린다(`overflow`). 클라이언트는 확인 안 된 프레임 중 새 32개만 다시 보내므로, 더 길게 멈추면 버린 프레임이 다시 오지 않아 빈 번호가 생기고 그 클라이언트의 자기 캐릭터가 한 번 크게 보정된다(아래 측정의 모형 값). M1에서 호스트가 1초 넘게 멈출 일은 없다고 보고 두었다
- **묶음 상태**(`StateBroadcast`): 호스트는 3틱마다(20Hz, 임시값) 모든 플레이어의 상태(자리, float32 위치 그대로, 바라보기, 걷기, 확인한 마지막 프레임 번호)를 한 패킷(5 + 14B × 인원, M2b부터 16B: 동작·든 아이템)에 담아, **바뀐 것이 있을 때만** unreliable로 보낸다. 바뀐 것이 없어지면 같은 상태를 reliable 키프레임으로 한 번 더 보내고(마지막 묶음을 잃어도 맞게), 그다음에는 누가 다시 움직일 때까지 아무것도 보내지 않는다. 남는 것은 ENet 자체의 유지 패킷(클라이언트 하나당 초당 약 5개)뿐이다
- **자기 캐릭터 예측**(`Prediction`): 클라이언트는 입력을 그 틱에 바로 같은 `Movement.step`으로 적용한다(왕복을 기다리지 않음). 호스트 상태가 오면 "프레임 n까지 처리한 위치"에서 시작해 아직 확인 안 된 프레임을 다시 돌린다. 같은 코드·같은 float32·같은 순서라 다시 돌린 결과가 예측과 같다: 테스트에서 오차는 늘 0.0px (지연 120ms + 손실 15% 흉내에서도). 호스트와 다르면(프레임을 못 받았거나 호스트가 옮겼거나) 호스트가 이기고 오차로 센다
- **남의 캐릭터 보간**(`Interpolation`): 호스트 틱 번호가 찍힌 상태를 모아 두고 100ms(임시값, 묶음 2개) 뒤를 선형으로 그린다. 마지막 상태 뒤는 앞질러 추측하지 않고 멈춘다. 조용하던 사람이 다시 움직이면 직전 상태를 한 간격 앞에 다시 넣어 조용했던 동안 미끄러지지 않게 한다. 호스트 틱은 묶음 도착 시각에서 가장 덜 늦은 값으로 추정한다(`RemoteClock`)
- **채널**: 0 reliable (hello, 월드 조각, welcome, 거부, 들어옴·나감, 편집, 키프레임, M2b 인벤토리, M3b 지도 들어옴, 테스트용 go/done/finish), 1 unreliable ordered (입력), 2 unreliable ordered (상태). 클라이언트가 부를 수 있는 RPC는 hello·입력·done 셋뿐이고 나머지는 호스트만(authority) 부를 수 있다 (`test_net.gd`가 RPC 표를 확인)
- **파일** (H1): `session.gd`(753줄)를 흐름별로 나눴다. `session.gd`(427줄, 그중 RPC 받기·보내기가 절반)는 두 역할이 같이 쓰는 상태(플레이어, 편집 기록, 전송, 끝내기, 로그)와 RPC 표만 가진다. 각 `@rpc` 받는 함수는 역할을 보고 흐름에 넘기기만 하고, 흐름은 `send_*`로 보낸다. 호스트 흐름 `session_host.gd`(285줄), 클라이언트 흐름 `session_client.gd`(246줄), 봇·테스트 흐름 `session_bots.gd`(155줄). 동작은 그대로다(같은 세션 테스트가 통과). H-fix 뒤 445 / 295 / 253 / 155줄 (테스트 멈춤, 스트림 기록, 접속 제한 이유)
- **ENet 패킷 조절(throttle)을 끔** (H-fix, `Config.NET_ENET_THROTTLE` = (5000, 2, 0), `EnetTransport`가 연결마다 `throttle_configure`): ENet은 reliable 메시지의 확인 왕복 시간이 지난 주기의 최소 + 변동 2배보다 길 때마다 연결의 조절 값을 낮추고, 낮은 값만큼 unreliable 패킷(우리 상태 묶음)을 버리고 reliable 창도 줄인다. 두 쪽이 60Hz로 네트워크를 읽으면 왕복 시간이 프레임 단위(localhost에서 약 16 / 33ms)로 뛰고 두 프로세스의 프레임 위상에 따라 흘러서, reliable 메시지가 잦으면(호스트가 4틱마다 편집) 조절 값이 약 1.5초 만에 0이 되어 걷는 클라이언트가 몇 초 동안 상태 묶음을 하나도 못 받았다(`stall` 세션이 가끔 실패해서 찾음: 걷는 4초 동안 확인 5번, 확인 안 된 프레임 128개 넘김. 계측해 보니 조절 값 32 → 0). 감속 0이면 낮아지지 않는다: 같은 흉내 6번에서 조절 값 653번 재어 모두 32(전에는 6번 중 5번 32 밑으로, 1번은 0까지). M1 트래픽은 9인 걸을 때도 약 23 KB/s라 혼잡 제어를 잃는 값이 작다고 봤다. 실제 인터넷에서 혼잡할 때 덜 버리는 대신 늦어질 수 있다(두 기기 시험에서 볼 것)
- **나감**: 호스트는 그 자리를 비우고 남은 사람에게 알린다. 클라이언트가 호스트를 잃으면: 테스트 인스턴스(`--net-out`)는 종료 코드 4, 사람이 띄운 것은 다른 플레이어를 지우고 혼자 계속 걷는다
- 전송 형식은 모두 `PackedByteArray` 하나에 직접 쓴다(`NetProtocol`, 버전 2, M2b부터 3). 디코더는 크기·범위를 먼저 보고 틀리면 버리고 센다(엔진 오류 없이). 스냅샷은 zstd다: Godot의 zstd 풀기는 잘못된 입력에 빈 배열을 돌려주지만 deflate는 엔진 오류 줄을 낸다
- 트래픽 통계(`NetStats`)는 "걷는 사람/전체" 묶음별이고, 호스트가 참가자에게 월드를 보내는 틱(과 그 뒤 두 틱)은 따로 "joining" 묶음에 넣는다(참가 비용이 서 있을 때 트래픽에 섞이지 않게). 다만 늦은 참가자의 ENet 연결 인사(호스트가 그 peer를 알기 전, 약 135B·패킷 3개)는 그때의 묶음에 들어간다(H-fix에서 잼: 둘이 서 있기만 하는 세션에 참가자를 하나 붙이면 0/2 묶음이 패킷 3개·약 135B 는다). pair의 0/2 구간(약 1.45초)에 이것이 떨어지면 0/2가 약 110 → 약 195~225 B/s가 된다(아래 측정)

### 테스트가 확인하는 것 (`test_net_session.gd`)

모든 인스턴스가 끝에 결과 JSON을 쓴다. 호스트와 비교하는 것: **위치 해시**(플레이어마다 자리·클래스·float32 위치 그대로·바라보기의 md5), **월드 해시**, **바닥 그림 해시**(`GroundView.view_hash`, H1), 플레이어 수. 그 밖에 바닥 그림 = 데이터(`GroundView.verify`), 모든 참가자가 월드를 스냅샷으로 받음(호스트가 보낸 스냅샷 수 ≥ 참가자 수), 클라이언트 예측 오차 ≤ 0.5px(실제로는 0.0)와 바라보기 보정 0(H1), 확인 안 된 프레임 0, 늦은 참가자: 편집 기록 위치(M1 1, M2b부터 pair·four 모두 3), 호스트의 편집된 월드(시드만의 월드와 다름), welcome에 호스트 생성기 해시, 생성기 진단(pair의 흔든 생성기는 `differs`, 나머지는 `match`), 참가 시간, `four`의 32바이트 조각(M1 11개, M2b 18개), 나간 자리를 늦은 참가자가 받음, 거부 이유 `full`, 잘못된 메시지 0, 호스트 입력 검사의 빈 번호·잘못된 패킷 0, 조용함(아무도 12틱 넘게 안 움직였는데 보낸 묶음 0), 헤드리스 자식의 틱이 실제 시간을 따라감(테스트 멈춤 시간은 빼고), 종료 코드, 자식 로그에 `ERROR:` 0, 남은 프로세스 0.
M2b에서 더한 것: 아이템 그림 = 데이터(`items_view`, 모든 인스턴스), 클라이언트의 동작 보정 0, 남은 채집물 수와 드롭 목록이 호스트와 같음, `pair`: 모두가 보는 각자의 든 아이템(호스트 = 돌, c1 = 요청해서 받은 검), 호스트가 돌린 c1의 검 동작 수 = c1이 예측한 수, c1이 본 호스트 곡괭이 동작 수 = 호스트의 수(3), 호스트가 주운 약초(일반)와 버린 돌이 c1에 실시간 편집으로 감, 늦은 참가자의 스냅샷에 줍힌 약초가 없고 드롭이 있음(welcome `gatherables=73 drops=1`), 그 참가자가 드롭을 줍고 약초를 상급으로 캠, 클라이언트 인벤토리 = 호스트의 사본, 거부된 요청 0, `four`: 버린 돌 5개를 정확히 한 클라이언트가 가짐(호스트 로그의 줍기 한 줄, 그 클라이언트의 인벤토리), 마구 누른 F가 `rate`와 `nothing there`로 거부됨, 늦은 참가자 스냅샷의 편집 위치 3, `stall`: 스트림 도중의 드롭 6개가 c1·c2에 호스트와 같은 목록으로 있음(그중 일부는 welcome 뒤 편집으로).
M2-fix에서 더한 것: `pair`의 c1이 매 프레임 고른 핫바 3번을 호스트가 모두 처리함(`ops` done select 3, 거부 0), 서서 조준만 한 c1이 호스트·c1·c2 모두에서 남쪽을 봄(바라보기만 바뀐 프레임을 기록하지 않게 깨면 셋 다 서쪽으로 남아 실패).
H-fix에서 더한 것: 호스트 입력 토큰이 실제 시간을 따라감(게이트마다 채운 시간이 호스트 틱 수의 0.9~1.1배 + 멈춘 시간. 호스트가 시계를 잘못 재면 실패한다), 모든 스냅샷이 틱당 8조각으로 나감(호스트가 센 틱 수 = ⌈조각/8⌉, `four`의 c4는 M1 2틱, M2b 18조각이라 3틱), `stall` 세션(위 "네트워크 테스트": 멈춤 뒤 속도 제한 틱 ≤ 2와 크레딧 사용, 받는 도중 편집이 welcome 뒤에 감, 편집 수와 월드가 호스트와 같음).

## 규칙

- **타입을 붙인 GDScript만**. `project.godot`에서 경고 5종(`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`)을 **오류**로 켰다. 걸리면 그 스크립트가 컴파일되지 않는다. 자주 걸리는 것: `int(v)`·`float(v)`에 Variant를 넣기(→ `var n: int = v`로 먼저 받기), Variant를 `as T`로 바꾸기(→ 타입 있는 변수에 대입), `Dictionary.get()` 결과를 바로 인자로 넘기기, `Script.new()`(→ `GDScript`로 받기). 데이터는 타입 없는 Dictionary 대신 타입 있는 Dictionary나 작은 클래스로
- Godot 4 API만 (`TileMapLayer`, `@export`·`@onready`, Callable 시그널). C# 없음. 줄바꿈 LF
- 게임 클래스는 `class_name`을 쓴다 (새 파일을 추가하면 임포트를 한 번 돌려 클래스 캐시를 갱신). `tests/`의 스크립트는 `class_name` 없이 경로로 `extends "res://tests/base_test.gd"` (내보내기에서 빠지는 폴더라서)
- 게임 코드는 오토로드 이름 `Cli`를 직접 쓰지 않고 `CliOptions.current()`를 쓴다. `--script`로 시작하는 도구는 오토로드가 등록되기 전에 컴파일돼서 `Cli`를 못 찾는다 (G1에서 실제로 겪음)
- 상수는 `core/config.gd`에 모은다. 주석으로 ●(문서 결정) / `PROVISIONAL`(○·?, 문서 위치) / `IMPL`(에이전트 선택)을 구분한다. 임시값을 새로 만들면 아래 표에도 적는다
- 기계가 읽는 출력 줄은 `EVENSONG_` 접두어 (`EVENSONG_SMOKE`, `EVENSONG_SCREENSHOT`, `EVENSONG_TESTS`, `EVENSONG_TILESET`, `EVENSONG_ANCHORS`, `EVENSONG_RENDER`, `EVENSONG_CLI`, `EVENSONG_NET <인스턴스> <사건> ...`)
- 네트워크: 게임 상태를 바꾸는 것은 호스트만 한다. 클라이언트가 보내는 RPC는 `any_peer`로 열고 호스트가 검사한다(지금은 hello·입력·done). 클라이언트가 보내는 값은 호스트가 스스로 정할 수 있으면 보내지 않는다(M1의 바라보기. M2b부터 조준 중의 바라보기 look은 마우스라 호스트가 정할 수 없어 보낸다. 그래도 사용의 바라보기는 호스트가 목표 칸에서 정한다). 새 메시지는 `NetProtocol`에 크기 고정 형식으로 넣고 디코더가 크기·범위를 먼저 본다. RPC는 `session.gd`에 받는 함수와 `send_*`를 두고 처리는 흐름 파일에 둔다. 이동 규칙을 바꾸면 호스트와 예측이 같이 바뀐다(`Movement` 하나). 월드를 바꾸는 일은 `EditLog`를 거친다(이미 있는 참가자에게 번호 붙은 편집으로 가고, 늦은 참가자는 스냅샷과 그 뒤 편집으로 같은 월드를 받도록. M3b: 그 지도의 기록으로, `SessionHost.apply_world_edit(편집, 지도)`, 그 지도에 있는 사람에게만). 타일을 겨누는 새 요청은 지도 번호를 싣고 호스트가 그 멤버의 지도와 맞춰 본다(M3b). 월드 레이어를 늘리거나 바꾸면 `WorldSnapshot`의 머리말·`decode_raw` 검사도 같이 본다
- 요청 (M2b): 클라이언트의 새 요청은 새 RPC가 아니라 입력 프레임에 붙인다(`NetProtocol.Op`, 필드 크기 고정, 디코더가 범위를 먼저 봄). 호스트는 그 프레임을 처리할 때 검사·적용한다(`SessionHost.run_frame`). 검사 규칙은 `items/world_items.gd`의 순수 함수로 두어 호스트와 혼자 할 때(`Main`)가 같이 쓴다. 플레이어의 프레임 규칙은 `PlayerSim.step` 하나다(호스트·예측·혼자). 드롭은 `WorldData.drops`와 편집으로만 바꾼다
- 빛 레이어: 바닥·제단·건물 = `Config.LIGHT_LAYER_WORLD`(1, 기본값), 캐릭터 스프라이트와 채집물·드롭(M2b) = `LIGHT_LAYER_ACTORS`(2). `light_mask`는 자식에게 물려지지 않으니 스프라이트마다 넣는다
- 빛 텍스처(`PointLight2D.texture`)는 실행 중에 새로 만들어 갈아 끼우지 않는다. `AltarLight.texture_for()`의 캐시를 쓴다
- 스프라이트 안의 그리기 순서는 트리 순서로, 다른 물체와의 순서는 y 정렬(발 = 노드 위치)로 정한다. `z_index`는 디버그 선에만 쓴다
- 그림은 `assets/concept`의 우리 PNG·JSON만 `art/`로 복사한다 (바이트까지 같게). 남의 에셋은 넣지 않는다. `game/` 아래 PNG는 LFS 규칙(`assets/concept/**`) 밖이라 작은 것만
- `const`로 둔 타입 있는 컨테이너의 원소가 packed 배열이고(`Dictionary[StringName, PackedStringArray]`, `Array[PackedStringArray]`) 값을 배열 리터럴로 쓰면, 4.7.2에서 읽을 때 엉뚱한 값(빈 문자열 24개)이 나오고 그것으로 이미지를 만들다 크래시가 났다 (M2a에서 잼, 스크래치 시험으로 재현). 이런 상수는 원소를 `Array`로 둔다(`ItemIcons.MAPS`, `Hud.DIGITS`). `const X: PackedStringArray = [...]`처럼 packed 배열 자체인 상수는 괜찮다
- `get_stack()`은 GDScript 내장 함수라 같은 이름의 메서드를 만들면 클래스 안에서 부를 때 내장이 불린다(인벤토리 칸 읽기는 `stack_at`)
- 테스트가 `tree.root.size`를 바꾸면(창 늘이기 시험, `test_aim.gd`) 끝에 원래대로 돌려놓는다
- 생성기나 그 상수를 일부러 바꾸면 `world/surface_gen.gd`의 `GOLDEN_HASH`를 새 값으로 바꾼다 (실패 메시지에 새 값이 나온다. `test_world.gd`와 스모크가 이 값을 본다). 늦은 참가는 이제 호스트의 월드를 받지만(H1), 같은 시드가 같은 월드라는 것(시드 공유, 혼자 할 때)은 여전히 이 값이 지킨다

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
- 그 파일이 도는 동안(정리와 그 뒤 2프레임 포함) 로그에 찍힌 **엔진 오류, `push_error()`, GDScript 실행 오류, 셰이더 오류는 모두 실패**다 (OS `Logger`로 받는다. 다른 스레드에서 난 것도). `allow_error()`로 알린 것만 통과하고, 알렸는데 안 나오거나 횟수가 다르면 그것도 실패다. 경고는 세지 않고 `  ! `로 찍기만 한다
- 파일 밖의 오류도 실패다: 첫 파일 전 `FAIL (startup)`, 마지막 파일이 끝난 뒤 10프레임 안 `FAIL (after the last file) ... logged after <파일> finished`, 두 파일 사이(다른 스레드만 가능)는 다음 파일의 실패로 `logged after <앞 파일> finished, before this file started:`를 붙여 센다 (다음 파일의 `allow_error()`로는 통과하지 않는다)
- 네트워크 포트가 필요하면 러너의 묶음 안에서 `Runner.free_port(Runner.port_first, Runner.port_last)`로 찾는다(`const Runner := preload("res://tests/run_all.gd")`, 쓰는 포트면 오류 줄 없이 건너뛴다)
- 노드는 `add_node()`로 붙인다. 정리 뒤 루트 아래에 새 노드가 남아 있으면 그 파일이 실패하고(`left <이름> (<클래스>) under the root after cleanup()`), 러너가 그 노드를 지운다 (다음 파일 시간에 오류를 내지 않게)
- 러너가 못 잡는 것: 파일이 남긴 타이머·스레드·시그널 콜백이 그보다 늦게 내는 오류. 그때 돌고 있는 파일의 실패로 세지고, 마지막 파일 뒤 10프레임보다 늦으면 놓친다
- 러너가 실패를 놓치지 않는지는 `tests/fixtures/case_*.gd` 11개(check 실패, 알리지 않은 push_error, 엔진 오류, await 뒤 오류, 실행 오류, 시간 초과, 기반 클래스 아님, 알렸는데 안 나온 오류, 루트에 남긴 노드 / 통과 2개)와 `late_error.gd`(마지막 파일 뒤 오류, 따로 돌림)로 `test_core.gd`가 매번 확인한다
- 시간 측정은 예열 한 번 + 여러 번 재고 범위로 적는다. 테스트가 확인하지 않은 것은 주장하지 않는다

## 임시값 (사람 확인 필요)

문서가 ○(제안)이거나 ?(미정)이거나 문서에 없는데 M1(아래 M2a·M2b 줄은 그 단계)에 값이 필요해서 넣은 것. 대부분 `core/config.gd`의 `PROVISIONAL` 상수다. 상수가 아닌 줄은 "코드" 칸에 적힌 곳에 있다: 키 배치(`project.godot`), 제단 그림(`art/env/`, `world/altar.gd`), 8방향 이동·4방향 바라보기 규칙(`Movement`), 카메라 가장자리 멈춤(`PlayerCamera`), 디버그 월드 편집(`net/net_bot.gd`), M2a의 조준 규칙(`actors/aim.gd`), 도구 아이콘(`items/item_icons.gd`), 아이템 표(`items/item_db.gd`), 그림(`art/items/`), 세션에서 끄기(`Player.controls`, `core/main.gd`), M2b의 줍기·드롭 규칙(`items/world_items.gd`)과 키(`project.godot`). 정해지면 그 값이나 코드를 바꾸고, 생성기에 닿는 값이면 `SurfaceGen.GOLDEN_HASH`를 갱신한다.

| 무엇 | 코드 | 지금 값 | 문서 |
|---|---|---|---|
| 지상 시작 구역 크기 | `MAP_SIZE` | 128 × 96 타일 (2048 × 1536 px) | ○ gameplay-design §3.1 (경계 있는 연속 맵, 크기 없음) |
| 제단 안전 반경 | `SAFE_RADIUS_TILES` | 7타일 = 112 px (스파이크 값). 지름 14칸이 화면 세로 약 17칸 안에 들어간다 | ? 반경 미정 (game-concept §7 화면 배율 줄: "제단 빛 반경을 정할 때 화면 세로 약 17칸 안에 들어오는지 함께 본다") |
| 제단 바닥 차지 | `ALTAR_FOOTPRINT` | 3 × 3 타일, 맵 한가운데 | ○ concept-art-brief §5.7 (R29) |
| 밭(일군 흙) | `SOIL_PATCH_COUNT`, `SOIL_PATCH_MIN`/`MAX` | 빛 반경 안에 3덩어리, 2×2 ~ 4×3, 제단 둘레 1칸 비움 | ○ "빛 안의 밭" game-concept §9.7·§12 판정 기준, gameplay-design §3.8 |
| 고정 오염 구역 수 | `ASH_ZONE_COUNT` | 3 | ○ 2~3곳 (game-concept §12: "제안" 절의 표시 없는 줄). 그 안의 수도 미정 |
| 오염 구역 크기 | `ASH_ZONE_RADIUS_MIN`/`MAX` | 반지름 5~8타일 (+ 가장자리 노이즈 ±3타일) | 문서에 없음 |
| 빛과 오염 사이 거리 | `ASH_CLEARANCE_TILES` | 안전 반경 밖 4타일부터 재 | 문서에 없음 (흙·재가 닿지 않게 하는 풀 띠이기도 하다) |
| 키 배치 | `project.godot` 입력 `move_*`, `debug_overlay`, `toggle_evening` | WASD + 방향키 (물리 키), F3 디버그 선, F4 저녁 켜고 끄기 | ○ gameplay-design §1 키 배치 초안 (F3·F4는 개발용, 초안에 없음) |
| 걷기 속도 | `WALK_SPEED` | 72 px/s (4.5타일/초), 8방향 같은 속력 | 문서에 없음 (M1 지시: 64~80 px/s) |
| 지상의 빛 | `EVENING_COLOR` | 늘 저녁 하나, `CanvasModulate` (0.40, 0.34, 0.31) 따뜻한 회색 (스파이크 값). 낮밤 순환 없음 | ? 낮밤 / 영원한 황혼 (gameplay-design §3.1, game-concept §7) |
| 제단 빛 색·세기 | `ALTAR_LIGHT_COLOR`, `ALTAR_LIGHT_ENERGY` | (1.0, 0.97, 0.91) × 0.65, 더하기 (스파이크 값. 빛 안 ≈ 그린 색) | 문서에 없음 |
| 안전 반경 테두리 | `SAFE_EDGE_BAND_PX`, `AltarLight` | 바닥: 반경 안쪽 16px 디더 띠 / 캐릭터: 같은 반경 hard 사본 (스파이크 제안) | 문서에 없음 (concept-art-brief §7 체크리스트의 "디더링으로 사라지는 빛 원"과 같은 쪽) |
| 제단 그림 | `art/env/altar_v04.png`, `altar_v04_unlit.png` | 4단계 채택 후보를 임시 그림으로. 등잔 9개 모두 켜짐 | ○ R29 채택 후보 (concept-art-brief §5.7), 켜진 등잔 수 메커닉은 ○ game-concept §9.3 |
| 8방향 이동 + 4방향 바라보기 | `Movement` | 위 "캐릭터" 참조 | 문서에 없음 (M1 지시) |
| 카메라 가장자리 | `PlayerCamera.clamp_center` | 내 캐릭터 가운데, 단 맵 가장자리에서는 맵 밖이 안 보이게 멈춘다 (맵이 화면보다 작은 축은 맵 가운데). 그래서 가장자리 근처에서는 캐릭터가 화면 가운데에서 벗어난다 | ● gameplay-design §1 "카메라는 각 플레이어 중심"에서 가장자리만 벗어난다 (멈출지는 문서에 없음). 늘 가운데로 하려면 `Main._follow`에서 `bounds`를 비우면 된다 |
| 상태 묶음 빈도 | `NET_STATE_HZ` | 20Hz (3틱마다), 바뀐 것이 있을 때만 | 문서에 없음 (M1 지시: 20~30Hz) |
| 남의 캐릭터 보간 지연 | `NET_INTERP_DELAY_MS` | 100ms (묶음 2개) | 문서에 없음 (M1 지시: 약 100ms) |
| 같은 클래스 둘 | `NET_UNIQUE_CLASSES` | 허용 (false). true면 호스트가 `class_taken`으로 거부 | ? 정해지지 않음 (gameplay-design §5 ○ 파티 UI 3×3은 클래스당 한 명 같지만 M1은 5클래스라 9인을 막게 된다) |
| 스폰 (혼자·호스트·참가자) | `SPAWN_FACING`, `Roster`, `SPAWN_SLOTS`(자리 9곳은 아래 구현 표) | 제단 둘레 자리 중 가장 작은 빈 자리, 남쪽(`SPAWN_FACING`)을 보고 선다 | 접속 스폰은 문서에 없음. 가까운 것은 "부활 지점: 제단" (gameplay-design §2.6, §5 ○) |
| 디버그 월드 편집 | 봇 `edit:<x>,<y>,<grass\|soil>` | 호스트만, 바닥 풀 ↔ 흙(괭이질)만 | 문서에 없음 (M1에 게임 편집이 없어 늦은 참가 길을 시험하려고. 키는 만들지 않았다) |
| M2a 키 | `project.godot` 입력 `use_item`, `hotbar_prev`·`hotbar_next`, `toggle_inventory`, `debug_give`, `debug_action` | 좌클릭 = 들고 있는 도구 사용, Q / E = 핫바 왼쪽 / 오른쪽, Tab = 인벤토리(보기만). 숫자 키는 핫바에 안 씀(초안에서 1 2 3은 스킬), F 상호작용은 아직 안 묶음(할 것이 없음). F5 디버그 아이템 묶음, F6 다음 몸 동작 | ○ gameplay-design §1 키 배치 초안 (F5·F6은 개발용, 초안에 없음) |
| 핫바·인벤토리 크기 | `HOTBAR_SLOTS`, `INVENTORY_SLOTS` | 핫바 8칸 = 인벤토리 24칸의 앞 8칸 | 문서에 없음 (gameplay-design §1 ○ "무기와 도구는 핫바로 전환"에 칸 수 없음) |
| 묶음 크기 | `STACK_TOOL`, `STACK_MATERIAL`, `STACK_GATHERABLE` | 도구 1, 재료 99, 채집물 99 | 문서에 없음 |
| 조준 중 (마우스 쪽 보기) | `AIM_HOLD_SEC`, `Player.tick_controls` | 마우스가 1초 안에 움직였거나, 사용 버튼을 누르고 있거나, 동작 중이면 마우스 쪽을 봄. 아니면 M1 그대로 걷는 방향 | 문서에 없음 (● gameplay-design §2.1 R12는 "에임형 (마우스 방향 스킬샷)"까지) |
| 조준 기준·구역·바라보기 | `Aim.sector`, `Aim.facing`, `Aim.feet_cell` | 기준점 = 발, 45° 8구역(축·대각선이 가운데), 마우스 쪽 바라보기는 4방향(큰 축, 정확한 대각선은 남·북), 마우스가 발 위면 그대로. **발 칸 = 발 상자(발 위 4px)의 가운데가 있는 칸** (M2-fix: 전에는 발 점의 칸이라 발이 타일 선 위면 그려진 발보다 한 줄 아래였다. 스폰 자리 0·1이 그렇다. 목표 칸·표시·손 닿는 칸이 모두 이것을 쓴다) | 문서에 없음 (● §2.1 에임형) |
| 목표 칸 | `Aim.target_cell` | 발 칸의 마우스 방향 이웃 칸(8방향). 맵 밖이면 표시를 숨김 | ○ gameplay-design §3.2 "마우스 방향의 인접 타일을 타격" (채굴에 쓴 말) |
| 몸 동작 길이 | `ACTION_FRAME_TICKS` | 프레임당 6틱(0.1초): 6프레임 0.6초, 8프레임 0.8초, 던지기 0.7초 | 문서에 없음 |
| 동작 중 이동 | `ACTION_LOCKS_MOVEMENT` | 동작이 끝날 때까지 걷지 않고 바라보기·목표 칸도 시작 때 것 | 문서에 없음 |
| 누르고 있기 | `ACTION_REPEAT_WHILE_HELD` | 누르고 있으면 동작이 끝나는 틱에 다시 시작 | ○ gameplay-design §3.2 "홀드하면 연속" (채굴에 쓴 말) |
| 도구 아이콘 | `items/item_icons.gd` `MAPS` | 16×16 코드 그림 6개 (brief §4 갈흑 외곽선·신앙 금빛·나무색, 04-env 철·구리 색) | 그림 없음 (assets/에 도구 아이콘이 없다. 사람이 그림을 정하면 바꾼다) |
| 마법·던지기를 부르는 아이템 | `ItemDB` (없음) | 아이템 없음. F6·`--test-action`으로만 본다 | 문서에 없음 (마법 = 성직자 기도·치료, 던지기 = 약초사 약제 투척, brief §5.6 표. 스킬 ? gameplay-design §2.2, 약제 ○ game-concept §12. 둘 다 M2 밖) |
| 등급이 있는 아이템 | `ItemDef.graded` | 약초 4개만 일반·상급. 버섯·돌·도구는 등급 없음 | 약초는 ● gameplay-design §3.4 원칙, 나머지는 문서에 없음 |
| 재료 아이콘 시점 | `stone_block` = `item_stone_block_v02.png` | 3/4 아이콘 v02 | ○ brief §5.7 "떨어진 재료 아이콘을 정면 정렬(v03)로 할지 3/4(v02)로 둘지" |
| 채집물·재료 그림 | `art/items/` | 04-env 본 제작 손질판 v02 19장 (아래 "그림 출처") | ○ 채택 후보, 사람 확인 전 (brief §5.7 "결과 (R32)", 04-env/prompts.md "본 제작") |
| 시작 인벤토리 | `Main` | 비어 있음 (F5, `--give`로 넣음) | 문서에 없음 |
| 세션의 조준·동작·인벤토리 | `Player.controls`, `Main` | M2a: 세션에서는 조준·동작 끔, 인벤토리는 보내지 않고 각자 자기 화면에서만. **M2b에서 이 줄은 끝났다**: M2b 지시(M2가 더한 것은 모두 호스트 권한)대로 세션에서도 켜고 호스트가 정한다(위 "M2b") | 문서에 없음 (M2a 지시: 혼자 할 때 먼저) → ● 호스트 권한 game-concept §13 |
| M2b 채집물 수 | `GATHER_ON_GRASS`, `GATHER_ON_ASH` | 풀에 야생 회복·버프·독초 8개씩, 버섯 a~d 4개씩, 돌 a 6·b 5·c 5·이끼 4 / 재에 재 버섯 6, 금 간 돌 4, 곰팡이 돌 4 = 74개 (128×96 맵, 맵 크기와 상관없이 같은 수) | ○ brief §5.7 범위 표 "야생 약초·균류 채집물", game-concept §12 (무엇이 있는지만, 수·밀도 없음). **돌은 문서에 없다**: 에이전트가 04-env/prompts.md 묶음 2의 "칸 0~19 채집물"에서 가져왔다(M2-fix에서 바로 적음. 전에는 이 줄과 `config.gd`가 돌까지 §5.7 표와 ● R28로 덮은 것처럼 적었다. §5.7 표는 약초·균류만, R28은 작물 3종이다). 오염 쪽 셋은 04-env/prompts.md "오염 쪽" |
| M2b 채집물 자리 | `GATHER_CLEARANCE_TILES`, `GATHER_EDGE_TILES`(M2-fix: `SurfaceGen`의 표시 없는 상수에서 옮김, 값 그대로), `SurfaceGen.gatherable_spot_ok` | 칸 가운데가 안전 반경 + 1타일 밖, 맵 가장자리에서 2칸 안쪽, 다른 채집물의 8이웃이 아님. 덤불(herb_clump)은 흩지 않음 | 문서에 없음 (4단계 목업이 채집물을 빛 밖에, 밭을 빛 안에 둔 것을 따름) |
| M2b 채집물이 다시 자라는지 | (없음) | 다시 자라지 않는다 | 문서에 없음 |
| M2b 채집물·드롭이 걸음을 막는지 | `Movement` (그대로) | 막지 않는다 (밟고 지나간다) | 문서에 없음 |
| M2b 손 닿는 칸 | `REACH_TILES` | 줍기·사용·버리기는 목표 칸(발 칸 `Aim.feet_cell`의 8이웃, M2a의 목표 칸)만. 호스트가 그보다 먼 칸·발 칸을 거부 | ○ gameplay-design §3.2 "마우스 방향의 인접 타일", §3.4 "F로 식물·드롭 줍기" |
| M2b 키 | `project.godot` 입력 `interact`, `debug_drop` | F = 목표 칸의 채집물, 없으면 드롭 줍기 / F7(개발용) = 고른 칸의 묶음 전부를 목표 칸에 버리기 | ○ gameplay-design §1 키 배치 초안 "F 상호작용 (줍기 …)" (F7은 초안에 없음) |
| M2b 드롭 주인 | `WorldItems.pickup` | 누구나 어떤 드롭이든 주울 수 있고 먼저 주운 사람 것. 인벤토리에 다 안 들어가면 들어가는 만큼 줍고 나머지는 남는다 | ○ gameplay-design §5 "드롭은 주운 사람 것" (일부만 줍기는 문서에 없음) |
| M3a 던전 크기 | `DUNGEON_SIZE` | 64 × 48 타일 (화면 약 2 × 3) | ○ game-concept §12 "첫 던전 1개", gameplay-design §3.1 ○ "던전 = 별도 맵" (크기 없음) |
| M3a 방·통로 | `DUNGEON_ROOM_COUNT`, `DUNGEON_ROOM_MIN`/`MAX`, `DUNGEON_ROOM_GAP`, `DUNGEON_CORRIDOR_WIDTH` | 방 7개(배치되는 만큼), 7~12 × 6~9 (윗줄은 북쪽 벽 앞면), 방 사이·테두리 3칸, 통로 3칸 너비 L자 | 문서에 없음 |
| M3a 기반암 테두리 | `DUNGEON_BORDER_TILES` | 2칸, 깰 수 없음 | 문서에 없음 (M3a 지시 "map border unbreakable") |
| M3a 광맥 | `DUNGEON_VEINS`, `DUNGEON_VEIN_SIZE_MIN`/`MAX` | 구리 9 · 철 5 줄기, 2~5칸, 걸을 수 있는 바닥 옆 바위에서 시작 | ○ brief §5.7 "광맥 1~2종" (종류·수 없음. 04-env 채택 후보가 구리·철) |
| M3a 벽 횃불 장식 | `DUNGEON_WALL_TORCH_SPACING` | 방 북쪽 벽(앞면 있는 바위)에 6칸마다, 도착 방은 계단 양옆. 작은 빛 | 문서에 없음 (04-env 던전 목업이 방 북쪽 벽에 횃불 둘) |
| M3a 이단의 제단 자리 | `SHRINE_FOOTPRINT`, `DungeonGen._place_shrine` | 3 × 2, 도착 방에서 (가운데 기준) 가장 먼 방 가운데. 불 꺼짐, 부술 수 없음 | ○ game-concept §12 "첫 던전 1개 (= 첫 오염 원천)", ? 이단 쪽 불 색 (brief §5.7) |
| M3a 던전 입구 | `ENTRANCE_FOOTPRINT`, `ENTRANCE_OFFSET_TILES`, `SurfaceGen.entrance_spot_ok` | 2 × 1, 제단 자리 왼쪽 위 칸에서 (10, 1) 타일 (시드 1: 제단 가운데 동쪽 약 10타일, 빛 밖). 막혀 있으면 가까운 데서 찾음(빛 + 1타일 밖, 가장자리 2칸 안, 채집물·설치물·흙 없음) | ○ gameplay-design §3.1 "지상의 입구로 진입" (자리 없음) |
| M3a 출구 계단과 도착점 | `EXIT_FOOTPRINT`, `DungeonGen.arrival_point`, `arrival_below` | 도착 방 북쪽 벽 앞면 2칸(위 바위는 기반암), 도착점은 그 바로 남쪽. 지상으로는 입구 바로 남쪽 | 문서에 없음 |
| M3a 앞면 칸이 막힘 | `Walls.blocks`, `Walls.owner_of` | 벽 아래 칸(앞면이 그려진 칸)은 걷지 못하고, 조준하면 위 벽을 친다. 가로 굴은 두 줄이어야 들어간다 | 문서에 없음 (그림에서 나온 구현 선택이지만 놀이에 닿아서 여기 적음) |
| M3a 경도·타격 | `HARDNESS_*`, `HARDNESS_CAP_*`, `WALL_HITS_*`, `MINING_POWER_*` | 경도 바위 1 · 구리 1 · 철 2, 상한 공용 1 · 광부 2, 깨지는 타격 바위 6 · 구리 8 · 철 10, 한 번에 공용 1 · 광부 2 | ● 공용 "느리고 1×1, 경도 상한" / 광부 "3×3 고속, 상위 경도" (gameplay-design §3.0 R11), ○ §3.1 "벽 타일에 경도 등급" (숫자 없음) |
| M3a 맞는 프레임 | `MINING_IMPACT_FRAME` | 곡괭이 동작 4번째 프레임(18틱째) | 문서에 없음 |
| M3a 3×3 방향 | `MINER_AREA_AWAY` | 친 칸에서 플레이어 반대쪽으로 3칸, 가로로는 가운데 (false = 친 칸 가운데) | ● 3×3 (R11), 어디로 뻗는지는 문서에 없음 |
| M3a 금 단계 | `Walls.crack_stage` | 최대 타격의 1/3마다 1·2·3단계 (올림) | 문서에 없음 (04-env 금 그림이 3단계) |
| M3a 깨진 칸이 주는 것 | `MINED_ROCK_ITEM`, `Walls.ORE_ITEMS` | 바위 → 돌 a 1개, 광석 칸 → 그 광석 1개(돌은 안 줌). 인벤토리에 안 들어가면 그 칸에 드롭, 드롭이 `MAX_DROPS`면 사라짐 | ○ gameplay-design §3.2 "채굴 시 드롭은 인벤토리로 자동" (가득 찼을 때는 문서에 없음) |
| M3a 던전 어둠 | `DUNGEON_DARK_COLOR` | (0.13, 0.11, 0.10), 제단 빛 없음 | 문서에 없음 (04-env 던전 목업은 어둡게 하지 않았다) |
| M3a 횃불 | `TORCH_LIGHT_*`, `WALL_TORCH_LIGHT_*`, `TorchLight.STEP_*`, `WorldItems.place` | 놓은 횃불 반경 80px · 세기 0.95, 벽 횃불 48px · 0.8, 색 (1, 0.86, 0.62), 딱딱한 네 단계. 손 닿는 빈 바닥에 하나씩(누르고 있어도 한 번), 막지 않음, 다시 줍지 못함. 안전 반경 아님 | ● 기본 키트에 횃불 (gameplay-design §3.0 R11), 빛의 크기·안전 여부·놓는 규칙은 문서에 없음 |
| M3a 횃불 그림 | `FixtureView` 횃불, `ItemIcons.MAPS["torch"]` | 놓은 횃불 = 04-env 땅 랜턴 켜짐판 v03, 아이콘 = 코드로 그린 작은 랜턴 | 그림 없음 (04-env에 횃불 아이템이 없다. ○ brief §5.7 랜턴 = 건설 조명) |
| M3a 출구 계단 그림 | `FixtureView._add_exit` | 임시: 던전 입구 아치 + 내려가는 계단 그림을 위아래 뒤집어 올라가는 계단처럼 | 그림 없음 (brief §5.7 범위에 던전 안 계단이 없다) |
| M3a 세션 | `WorldItems.pickup`, `Main` | M3a: 세션은 지상만, 입구는 호스트가 거부(`dungeon offline only`). **M3b에서 이 줄은 끝났다**: 세션에서도 오가고 캔다(위 "M3b", 아래 "M3b 지도 오가기") | M3a 지시 "local / offline first" → ● 호스트 권한 game-concept §13 (M3b 지시) |
| M3b 지도 오가기 (세션) | `WorldItems.travel`, `SessionHost._travel` | 입구·계단을 손 닿는 칸(`REACH_TILES`)에서 F. 요청 예산은 줍기와 같고 따로 기다리는 시간(쿨다운)은 없다. 도착점·남쪽 바라보기·동작 멈춤은 M3a 그대로. 여럿이 오면 같은 도착점에 겹쳐 선다(플레이어끼리 충돌 없음, M1부터) | ○ gameplay-design §3.1 "지상의 입구로 진입", 나머지는 문서에 없음 |
| M3b 다른 지도의 플레이어 | `SessionClient.draw_others` | 그리지 않고 화면에 아무 표시도 없다(누가 던전에 있는지 알 수 없다) | 문서에 없음 (파티 UI는 ○ gameplay-design §5 "파티 UI 3×3") |
| M3b 다시 참가할 때의 지도 | `SessionHost.on_hello` | 늘 지상 스폰 자리에서(던전에서 나갔어도) | 문서에 없음 (M2b "다시 참가" 줄과 같은 이유: 다시 참가 기억이 없다) |
| M2b 디버그 주기·버리기 | `NetSession.gives_allowed` | 클라이언트의 주기 요청(F5, `--give`)과 버리기 요청(F7, M2-fix)은 호스트가 디버그 빌드(에디터 실행)이거나 `--test-allow-give`일 때만 | 문서에 없음 (M2b 지시 "debug give in test builds only". 버리기도 디버그 키라 같이 묶었다) |
| M2b 다시 참가 | `SessionHost` | 다시 참가해도 인벤토리가 이어지지 않는다(새 참가자는 빈 인벤토리, 나간 사람의 인벤토리는 사라짐) | 문서에 없음 (M1에 다시 참가 기억이 없음, 저장은 M2 밖) |

### 구현에서 고른 값 (설계 결정 아님)

| 무엇 | 코드 | 값 | 이유 |
|---|---|---|---|
| 기본 시드 | `DEFAULT_SEED` | 1 | |
| 바닥 청크 크기 | `GROUND_CHUNK` | 그림 칸 32 × 32 | 스파이크: `TileMapLayer`가 클수록 한 칸 편집이 비싸다 (RESULTS §3) |
| 바닥 렌더링 사분면 | `GROUND_QUADRANT` | 8칸 (128 px) | 캔버스 아이템 하나가 받는 빛 15개 한도 (RESULTS §4). G2의 빛은 2개뿐이라 그대로 둠 |
| 속 타일 변형 가중치 | `VARIANT_WEIGHT` | 변형 하나당 0.25 (기본 타일 1) | 풀은 기본 50%, 변형 4개 각 12.5% (테스트가 1만 칸에서 비율 확인) |
| 재 가장자리 노이즈 | `ASH_EDGE_NOISE_TILES`, `ASH_EDGE_NOISE_FREQUENCY` | ±3타일, 0.2 / 타일 | ±2타일은 덩어리가 너무 둥글었다 (스크래치 캡처로 비교) |
| 자유 카메라 속도 | `FREE_CAMERA_SPEED` | 240 px/s | `world.tscn`(맵 보기)에서만. 실행 장면은 플레이어 카메라 |
| 기본 호스트 포트 | `DEFAULT_PORT` | 24600 (UDP) | 테스트는 20개 묶음, 기본 `NET_TEST_PORT_FIRST..LAST` 24621-24640 (스파이크는 24601-24620). 러너가 잠금 + 확인(주소 세 개, `Runner.PROBE_ADDRESSES`)으로 고른다 (위 "테스트 포트") |
| 시뮬레이션 틱 | `NET_TICK_RATE`, `NET_TICK` | 60 (= 물리 틱, 스모크가 확인) | 입력 프레임 하나 = `Movement.step` 한 번 (1/60초) |
| 입력 보내기 | `NET_INPUT_HZ`, `NET_MAX_FRAMES_PER_PACKET` | 30Hz, 확인 안 된 프레임을 최대 32개(0.5초)까지 매번 다시 | 패킷을 잃어도 다음 패킷이 메운다. 움직이기 시작한 틱에는 바로 보낸다 |
| 호스트 속도 제한 | `NET_INPUT_BURST`, `InputGate.take(elapsed_ticks)`, `InputGate.ticks_between` | 실제 시간 한 틱마다 토큰 1, 최대 30 (+ 기다리던 프레임 수), 한 번에 최대 64틱 | 실제 시간보다 빨리 걸을 수 없고, 몰려 온 패킷은 0.5초까지 따라잡는다. 호스트가 멈췄던 시간도 채워서 뒤처진 대기열이 돌아온다 (H1) |
| 멈춤 크레딧 | `InputGate.HITCH_CREDIT_TICKS` | 놓친 틱 중 상한이 자른 몫, 실제 시간 30틱(0.5초) 동안, 더하지 않고 바꿔 넣음 | Godot이 따라잡기 틱 뒤에 네트워크를 읽어서, 멈춘 동안 온 프레임은 다음 틱에야 대기열에 들어온다. 그때 쓸 수 있게 (H-fix) |
| 따라잡기 속도 | `NET_INPUT_CATCH_UP_FRAMES` | 틱당 최대 4프레임 | 밀린 클라이언트가 다른 사람 눈에 한 틱에 수십 걸음 뛰지 않고 4배 속도로 따라잡게 (H-fix) |
| 한 틱에 그리는 구간 | `Player.MAX_DRAWN_STEP_PX` | 3px (두 걸음 2.4px + 여유) | 그보다 많이 움직인 틱(따라잡기)은 끝 위치에 그린다. 두 끝을 잇는 직선이 제단을 지날 수 있어서 (H-fix) |
| 스냅샷 크기 상한 | `WorldSnapshot.MAX_SIDE`, `MAX_PACKED` | 한 변 512칸, 압축 약 1.6MB (`MAX_RAW` + 1/64 + 1KB) | 받는 쪽이 잡을 메모리와 받을 크기의 상한. 이 크기는 압축이 안 돼도 틱당 8KB로 약 3.3초라 접속 제한 10초 안에 오고, 그리기 1초 안쪽. 맵이 커지면 접속 제한과 같이 올린다 (H-fix, 전에는 2048) |
| 입력 프레임의 바라보기 | `NetProtocol` 프레임 코드 0..8 | 보내지 않음, 호스트가 `Movement.facing_for`로 정함. **M2b에서 바뀜**: 아래 "바라보기를 프레임 코드에" 줄(조준 중에는 look을 보냄, 코드 0..44) | 호스트 권한. 클라이언트가 바라보기를 마음대로 정할 수 없고 1바이트 그대로 (H1) |
| 늦은 참가 월드 | `WorldSnapshot`, `NET_SNAPSHOT_CHUNK_BYTES`, `NET_SNAPSHOT_CHUNKS_PER_TICK` | 레이어 6장 + 머리말을 zstd로, 1KB 조각, 틱당 8조각 | 다른 아키텍처에서 생성이 달라도 같은 월드. 조각 하나 + 헤더가 UDP 한 덩어리(약 1400B)에 들어가 ENet이 쪼개지 않고, 큰 맵은 메시지가 아니라 틱 수로 커진다 (H1) |
| 제단 옆 띠 | `ALTAR_SIDE_CLEARANCE` | 서 5px, 동 3px (발 상자 밖으로 더) | 몸이 발에서 좌우 9px까지, 제단 그림 불투명 열 0~46. 옆면에 붙어도 몸이 제단 뒤로 안 들어간다. 테스트가 그림에서 다시 잰다 (H1) |
| 틱 사이에 그리기 | `Player.smooth_draw`, `draw_position` | 켬 (물리 틱으로 움직이는 플레이어) | 60Hz보다 빠른 화면에서 고른 걸음. 시뮬레이션은 그대로, 그림만 최대 1틱 뒤 (H1) |
| 호스트의 고른 적용 | `NET_INPUT_JITTER_FRAMES` | 3프레임 넘게 쌓이면 한 틱에 더 적용 (최대 4, 위) | 30Hz로 오는 입력을 60Hz로 고르게 (다른 사람 눈에) |
| 연결 한도 | `NET_TRANSPORT_PEER_LIMIT` | ENet 16 | 9명을 넘는 사람에게도 "full"을 말해 주려고. 상한은 `Roster`가 센다 |
| ENet 패킷 조절 | `NET_ENET_THROTTLE` | (간격 5000ms, 가속 2, 감속 0) = 낮아지지 않음 | ENet 기본(감속 2)은 60Hz로 뛰는 왕복 시간에 반응해 상태 묶음을 몇 초씩 버렸다(위 "네트워크"). 트래픽이 작아서 끔 (H-fix) |
| 접속 시간 | `NET_CONNECT_TIMEOUT_SEC`, `NET_HELLO_TIMEOUT_SEC`, `NET_REFUSE_GRACE_SEC` | 10초 / 5초 / 2초 | ENet 스스로는 약 31초 뒤에야 실패를 알린다 (이 데스크탑에서 잼). 10초는 월드를 다 받기까지다(스냅샷 크기 상한이 이 안에 들어오게 정함) |
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
| 인벤토리 넣기·나누기·옮기기 | `Inventory` | 같은 아이템·등급 묶음 먼저, 그다음 앞쪽 빈 칸 / 나누기는 첫 빈 칸으로 / 옮기기는 옮김·합침·맞바꿈 | 흔한 방식(테라리아·코어키퍼). 칸 순서라 새 아이템은 핫바부터 (M2a) |
| 동작 시간을 틱으로 | `Player.action_tick` | 시뮬레이션 틱으로 세고 프레임 = 틱 / `ACTION_FRAME_TICKS` | 그림 속도가 아니라 시뮬레이션이 정하게. 나중에 호스트가 같은 수로 셀 수 있다 (M2a) |
| 목표 칸 표시 모양 | `TargetMarker` | 칸 모서리 ㄱ자 금빛(팔 4px) + 안쪽 갈흑 띠, unshaded, 바닥 위·캐릭터 아래. 동작 중에는 동작의 목표 칸 | 풀·흙 위에서 읽히고 저녁에도 보이게. 칸 가운데를 비워 바닥이 보이게 (M2a). 동작 중에는 목표 칸이 시작 때 것이라 표시도 그 칸에 (M2-fix) |
| HUD 배치 | `Hud` | 칸 18px, 간격 2px, 아래 4px, 캔버스 레이어 10, 3×5 숫자, 상급 = 금빛 점 | 480×270에서 핫바 8칸 = 158px. 글꼴 없이 (M2a) |
| 디버그 묶음 | `ItemDB.debug_kit` | 도구 6 + 채집물·재료 17묶음 = 23칸 (약초 상급 하나 포함). **M3a**: 도구 뒤(핫바 7번)에 횃불 10개를 넣어 24칸을 다 채움 | 모든 아이템이 한 번에 보이게 (M2a). 횃불은 핫바에 있어야 쓸 수 있어서 도구 바로 뒤 (M3a) |
| 조준 마우스 위치 | `Player.mouse_world` | 엔진 `get_global_mouse_position()` | 창 늘이기·카메라를 엔진과 같게. `Aim`의 같은 계산은 테스트가 엔진과 비교하는 데 쓴다 (M2a) |
| 프레임 하나의 규칙 | `PlayerSim.step` | 동작 진행 → 사용이면 시작 → 이동 → 바라보기. 동작은 프레임으로 센다 | 혼자·호스트·예측이 같은 함수라 같은 프레임 줄이면 같은 상태 (M2b) |
| 바라보기를 프레임 코드에 | `NetProtocol.frame_code` | 코드 = 방향 + 9 × (look + 1), 0..44, 1바이트 그대로 | 조준은 클라이언트의 입력(마우스)이라 호스트가 정할 수 없다. look이 없으면 M1 코드 0..8 (M2b) |
| 요청을 프레임에 | `NetProtocol` 입력 패킷 끝 | 프레임 하나에 요청 하나, 확인될 때까지 프레임과 같이 다시 보냄. 새 클라이언트 RPC 없음 | 호스트가 그 프레임의 자리에서 검사해서 예측과 어긋나지 않고(같은 위치, 같은 순서), unreliable이어도 잃지 않는다. 따로 reliable RPC로 보내면 채널이 달라 프레임과 순서가 섞인다 (M2b) |
| 언제 프레임을 기록하나 | `Prediction.step_frame` | 움직일 때·멈춘 첫 틱(M1) + 요청이 있을 때 + 동작이 이어지는 동안 매 틱 + look이 바라보기를 바꿀 때 | 동작이 프레임으로 끝나므로 호스트와 같은 프레임에서 끝나야 한다. 서서 조준만 하면 바라보기가 바뀔 때만 1바이트 (M2b) |
| 요청 예산 | `NET_OP_INTERVAL_TICKS`, `NET_OP_BURST`, `NetMember.op_budget` | 줍기·버리기·주기: 6틱에 하나, 몰아서 4개. 사용은 동작 하나가 묶고(거부된 사용은 검사 한 번과 카운터뿐), 고르기는 예산 밖(M2-fix) | 사람이 누르는 속도보다 넉넉하고 매 프레임 보내는 클라이언트는 막는다. 틱 단위 정수로 센다(실수로 세면 6틱 뒤 0.9999로 모자랐다) (M2b). 고르기는 예측하는 요청이라 rate로 거부하면 클라이언트 핫바만 어긋나고, 월드를 바꾸지 않으며 프레임 수가 묶는다 (M2-fix) |
| 키 요청 줄 세우기 | `NetSession.local_ops`, `take_local_token`, `NET_LOCAL_OPS_MAX` | 클라이언트·호스트 모두 키 요청을 호스트와 같은 예산으로 하나씩 보냄(고르기는 다음 빈 프레임에). 줄은 64개까지, 넘으면 `request_dropped` 줄을 찍고 버림. 봇 요청은 바로 | 호스트가 제때 받으면 사람이 누른 것이 rate로 버려지지 않게(패킷을 잃거나 호스트가 멈춰 몰려 오면 4개 넘는 줍기·버리기·주기는 거부될 수 있다, 위 "요청"). 64는 클라이언트의 `--give` 디버그 묶음 23개(255개 넘는 수는 나뉨)가 다 들어가게. 전에는 코드 안 16에서 말없이 버렸다 (M2b, M2-fix) |
| 거부 로그 줄이기 | `NET_REFUSAL_LOG_FIRST`, `NET_REFUSAL_LOG_EVERY` | 플레이어·이유마다 처음 8줄, 그다음은 60번째마다 (`n=` 개수와 함께). 결과 JSON의 수는 모두 셈 | 매 프레임 거부되는 요청(사용·줍기)을 보내는 클라이언트가 호스트 로그를 초당 60줄씩 채우지 않게 (M2-fix) |
| 사용의 바라보기 | `Aim.use_facing`, `PlayerSim.step` | 프레임의 look이 목표 칸 쪽(칸 방향의 두 축 중 하나)이면 look, 아니면 칸 방향의 큰 축(정확한 대각선은 남·북) | 호스트가 정한다: 서쪽을 보며 동쪽 칸을 치는 프레임을 받지 않게. 정상 클라이언트의 look은 늘 칸 쪽이라 예측과 같다 (M2-fix) |
| 클라이언트 주기 나누기 | `Main.give_requests`, `WorldItems.GIVE_COUNT_MAX` | 255개 넘는 `--give`는 255씩 여러 요청으로 | 전송 형식의 개수가 1바이트라 300이 44로 잘렸다. 혼자·호스트와 같은 수를 받게 (M2-fix) |
| 땅의 드롭 상한 | `MAX_DROPS` | 256 | 스냅샷과 월드가 끝없이 커지지 않게 (M2b) |
| 같은 틱 순서 | `SessionHost.tick` | 플레이어는 자리 순서, 프레임은 번호 순서, 편집은 바로 적용 | 같은 틱에 같은 것을 주우면 자리 번호가 작은 쪽 (M2b. M2-fix부터 `tick` 자체로 시험) |
| 상태에 동작·든 아이템 | `NetProtocol` 상태 16B | flags 3~6비트 = 동작, u8 동작 프레임, u8 든 아이템 | 동작 시작 틱을 알 수 있어 보간이 시작부터 그리고, 예측 보정이 동작까지 맞춘다. 든 아이템은 바뀔 때만 묶음이 나간다 (M2b) |
| 인벤토리 메시지 | `_rpc_inventory` | 바뀐 틱 끝에 주인에게만 전부(78B) + ack | 드물게 바뀌어 차이보다 전부가 단순. ack로 아직 처리되지 않은 고르기를 다시 얹는다 (M2b) |
| 목표 칸 좌표 | 요청 필드 s16 | 부호 있는 16비트 | 맵 0열에 서서 서쪽을 겨누면 목표 칸이 −1이다(혼자 할 때처럼 동작은 된다) (M2b) |
| 채집물·드롭 그림 | `ItemView` | 칸 아래 변에 노드, 그림은 그 칸, `Entities` y 정렬, 캐릭터 빛 레이어 | 발 기준 y 정렬에 같이 들어가고 디더 빛의 바둑판이 작은 물체에 생기지 않게 (M2b) |
| 지도 하나 = GameWorld 하나 | `Main.worlds`, `GameWorld.map_id` | 혼자 할 때 `world.tscn`을 하나 더(던전), 하나만 보임, 플레이어 노드를 옮김 | 지상 코드(세션·스냅샷·테스트)가 `world`를 그대로 쓰고, 숨긴 지도의 어둠·빛이 적용되지 않음 (M3a) |
| 벽 바이트 | `Walls.pack` | 아래 4비트 종류, 위 4비트 맞은 횟수 | 레이어 6장(●)을 늘리지 않고, 채굴 한 번 = 칸 편집 하나라 스냅샷·해시·편집 기록이 그대로 (M3a) |
| 던전 그림 | `CaveView`, `CaveTable` | 꼭짓점 값 3가지(바닥·벽·앞면)의 dual grid, 코너 키 + 둘레(context)로 타일, 없는 키는 가까운 키 | 04-env 절벽 셋의 JSON 규칙 그대로. 지상 `GroundView`·`WangTable`은 손대지 않음 (M3a) |
| 다시 그리는 범위 | `CaveView.redraw_wall` | 그림 칸 가로 2 × 세로 5 + 위·아래 칸 오버레이 | 칸과 아래 칸(앞면)이 코너·둘레에 드는 범위 (M3a) |
| 광맥 그림 | `CaveView.ore_image` | 04-env 광맥 타일 − 같은 윗면 타일 = 광석 픽셀만 | 광맥 타일은 그림 칸(반 칸 밀림)이 아니라 월드 칸 위에 얹어야 해서 (M3a) |
| 횃불·벽 횃불 빛 | `TorchLight` | 반경마다 한 번 만든 텍스처를 붙잡아 둠, 딱딱한 단계 | 제단 빛과 같은 4.7.2 텍스처 규칙, 캐릭터 얼굴에 디더 바둑판이 생기지 않게 (M3a) |
| 벽 횃불 불꽃 | `FixtureView` | `flame_large_v01` 1~4프레임 140ms, unshaded, 횃불마다 위상 | 04-env 목업의 기준점 (9, −4)과 미리보기 GIF 140ms (M3a) |
| 혼자 할 때 봇 | `Main._physics_process` | `--bot`이 있으면 키 대신 봇(`NetBot`)이 `tick_controls`를 부름 | 스크린샷·테스트에서 같은 길(조준·동작·채굴·F)을 지나게 (M3a) |
| 트래픽 묶음 | `NetSession._count_traffic` | `act<n>/<인원>` 동작 중, `req/<인원>` 요청 전후 3틱. M3b: 플레이어가 지도 둘 이상에 있으면 뒤에 ` split`, 지도를 보내는 틱과 그 뒤 두 틱은 `entering` | 동작·요청이 서 있을 때(0/n) 측정에 섞이지 않게 (M2b). 지도 둘에서의 트래픽을 따로 재려고 (M3b) |
| 클라이언트는 자기 지도만 | `SessionHost.peers_on`, `_stream`, `_enter_map`, `SessionClient.on_map_entry` | 지도에 들어갈 때 그 지도의 스냅샷(늦은 참가 길, 같은 조각·틱당 8조각) + 지도 들어옴 + 그동안의 편집, 그 뒤 그 지도의 편집만. 떠난 지도는 버림 | 위 "M3b: 지도 보내기"(트래픽·단순함) (M3b) |
| 지도 번호 | `MAP_COUNT`, `MAP_NAMES` | 2 (지상 0, 던전 1) | 디코더가 다른 번호를 거부한다 (M3b) |
| 타일 요청의 지도 | `NetProtocol` USE·PICKUP·DROP·TRAVEL의 u8 지도 | 그 멤버의 지도가 아니면 `wrong map`, 예산을 쓰기 전에 | 옮긴 뒤 옛 지도에서 만든 프레임이 새 지도의 우연히 맞는 칸에 작용하지 않게. 예측도 같은 규칙으로 다시 돌린다 (M3b) |
| 상태의 지도 | 상태 17B | 모든 플레이어의 상태를 모두에게, 클라이언트가 지도 번호로 그리기만 거름 | 위 "상태와 그리기". 지도 옮김이 묶음·키프레임 흐름에 그대로 실린다 (M3b) |
| 편집 기록 | `NetSession.log_for` | 지도마다 기록과 번호 | 지도를 받을 때 "스냅샷 위치 + 그 뒤 편집"이 지도마다 맞게 (M3b) |
| 받는 중 오가기 | `WorldItems.WHY_LOADING` | 앞 지도를 다 보내기 전에는 TRAVEL 거부 | 한 클라이언트에게 두 지도의 조각이 섞여 가지 않게 (M3b) |
| 오가기 예측 | `Prediction.switch_map` | 예측하지 않음. 지도 들어옴의 상태에서 그 뒤 프레임을 새 지도에서 다시 돌림 | 새 지도 데이터가 오기 전에는 그 지도에서 걸을 수 없다 (M3b) |
| 봇 `waitmap` | `NetBot`, `SessionBots.map_counts` | 이 기기가 아는 지도별 인원까지 기다림 | 세션 시험이 시간 대신 상태로 서로를 기다리게 (M3b) |
| 표시 파일 내용 | `SessionBots.mark`, `SessionReport.seen` | JSON: 틱, 내 지도, 플레이어마다 지도·그려짐 | 그 순간 무엇을 그렸는지 시험이 본다 (M3b) |
| 던전 해시 묶음 | `DungeonGen.SEEDS_GOLDEN`, `seeds_digest` | 시드 1~8 던전 해시의 md5 | 서피스 ARM64와 생성기 비교 (M3b) |

## 그림 출처

`art/`의 파일은 모두 `assets/concept`의 우리 파일 그대로다 (`test_actors.gd`가 저장소에서 돌 때 68개 전부 md5 비교, M3a에서 19개 더함). 도구 아이콘 6개는 파일이 아니라 코드다(`items/item_icons.gd`, 임시값).

| 파일 | 원본 |
|---|---|
| `tiles_grass-soil_v03.png`, `tiles_grass-soil_v01.json` | `04-env/` (풀↔일군 흙 Wang 16장, JSON은 v01 배치) |
| `tiles_grass-corruption_v05.png` | `04-env/` (풀↔재) |
| `tiles_grass-corruption_v02.json` | `03-pixel/` (v05 그림의 배치) |
| `tiles_grass_var_1~4_v02.png`, `tiles_soil_var_1~2_v01.png`, `tiles_ash_var_1~3_v02.png` | `04-env/` (속 타일 변형) |
| `chars/base_body_v02_walk.png`, `chars/base_body_v02_idle.png` | `03-pixel/` (기본 몸 걷기 6 / idle 4프레임, 줄 남·동·북, 발 y=31) |
| `chars/sig_paladin_shield_v01.png`, `sig_miner_pickaxe_v01.png`, `sig_archer_bow_v01.png`, `sig_cleric_halo_v01.png`, `sig_herbalist_pouch_v02.png` | `03-pixel/` (클래스 표식 레이어 5종, 걷기 v01 첫 프레임에 그림) |
| `env/altar_v04.png`, `env/altar_v04_unlit.png` | `04-env/` (제단 3×3, 켜짐·꺼짐) |
| `chars/base_body_v02_{pickaxe,hoe,sickle,watering,sword,bow,magic}.png` (M2a) | `03-pixel/` (몸 동작 7개, 64×64 칸, 시작 칸 + 6·8프레임, 줄 남·동·북, 발 y=47. 10~12차 + 손질) |
| `chars/base_body_v02_throw.png` (M2a) | `03-pixel/` (던지기 32×32, 7프레임, 발 y=31. 8차 + 손질) |
| `items/item_sprig_{healing,buff,poison}_v02.png`, `items/item_wild_{healing,buff,poison,herb_clump}_v02.png` (M2a) | `04-env/` (본 제작 묶음 2, size 16: 꺾은 약초 = 아이콘, 자라는 약초·덤불 = 월드 그림. 채택 후보) |
| `items/item_mushroom_{a,b,c,d,ash}_v02.png`, `items/item_stone_{a,b,c,mossy,veined,mould,block}_v02.png` (M2a) | `04-env/` (같은 묶음: 버섯 5, 돌 6, 돌 블록 = 재료. 채택 후보) |
| `tiles/tiles_dungeon_v02.png`, `tiles/tiles_dungeon_v01.json`, `tiles/tiles_dungeon_v02_var.png` (M3a) | `04-env/` (던전 바닥↔벽 절벽 셋 25장 + 속 타일 변형 5장, JSON은 v01 배치. 1차 시험 연장 + 2차 손질, 채택 후보) |
| `tiles/tiles_ore_{copper,iron}_{a,b}_v02.png` (M3a) | `04-env/` (벽 윗면에 박은 광맥, 마지막 손질. 채택 후보) |
| `tiles/wall_crack_top_v01.png`, `tiles/wall_crack_face_v01.png` (M3a) | `04-env/` (부서지는 벽 금 3단계, 윗면 16×16 / 앞면 16×24. 본 제작 손그림) |
| `env/dungeon_entrance_v02.png`, `env/dungeon_entrance_stairs_v01.png`, `env/dungeon_entrance_debris_v01.png` (M3a) | `04-env/` (던전 입구 아치, 내려가는 계단, 둘레 잔해. 출구 계단은 이 아치 + 뒤집은 계단으로 만든 임시) |
| `env/heretic_shrine_v02.png` (M3a) | `04-env/` (이단의 제단, 불 없음) |
| `env/prop_wall_torch_a_v02.png`, `env/flame_large_v01.png` (M3a) | `04-env/` (꺼진 벽 횃불 + 공유 큰 불꽃 5프레임) |
| `env/prop_lantern_ground_v03_lit.png`, `env/prop_lantern_ground_v03_emissive.png` (M3a) | `04-env/` (켜진 땅 랜턴과 빛 마스크, 손질 2. 놓은 횃불의 임시 그림) |
| `items/item_ore_{copper,iron}_a_v02.png` (M3a) | `04-env/` (광석 아이템, 04-env 던전 목업이 쓴 것) |

## 측정 (이 데스크탑, `.godot/`을 지운 상태에서)

M3b (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.6초, 종료 0, 오류 줄 0 (새 시험 스크립트 `test_net_maps.gd`의 `.uid`, 커밋) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 13파일 통과 7,624 checks 116.9~117.1초 종료 0 (actions 1,055 / actors 1,588 / aim 1,094 / core 267 / dungeon 80 / items 1,510 / light 73 / mining 82 / net 436 / net_maps 131 / net_session 560 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M3a보다 약 33초 늘었다: 세션 시험 약 52 → 82.5초(`cave` 약 25초, `four`의 던전 경주 약 6초), 새 파일 `net_maps` 2.0초. 파일당 제한 120초 안이다. 이 세션의 그 전 전체 실행 하나에서 `test_aim.gd`의 표시 검사가 한 번 실패했다(부하에서 물리 틱 둘이 한 프레임에 돌아 `_process`의 표시가 아직 안 따라옴, 혼자 세 번 통과). 그 검사 앞에 프레임 둘을 기다리게 고쳤다 |
| 세션 시험 `--net-full` | 통과 826 checks 88.0초 (9인 상한 세션 포함) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 561 checks 79.0초 (자식 모두 내보낸 exe, pair·four·cave 호스트에 `--test-allow-give`) |
| 내보내기 | x86_64 3.4초 `evensong.exe` 109,758,464 B, ARM64 3.0초 92,152,320 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--class=miner --give=pickaxe,torch:5 --start-map=dungeon`) | 250 checks ok (`dungeon_seeds=3ec443b95c4c dungeon_map=313B ... net=v4`), 1.0초 / 1.3초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 3.0초, 9부분 모두 ok. `cave_net` 편집 32개(클라이언트 스냅샷 344B 뒤 23개), 금 1·2·3단계, 깬 칸 6, 오버레이 22, 클라이언트 = 합성 불일치 0, 호스트 = 클라이언트 불일치 0 |
| 두 창 그림 | `shots/m3b_host.png`, `shots/m3b_client.png` 480×270 (창 960×540), 두 로그 오류 줄 0 |
| 지도 스냅샷 | 시드 1 던전: 원본 18,456B(드롭 하나면 18,467B) → 압축 309~345B, 조각 1개, 만들기 65~87µs. 클라이언트가 받아 그리기 62~70ms(동굴 그림). 지상으로 돌아올 때 566B |
| 단위 시험 (`test_net_maps.gd`) | 예측과 호스트가 이미 깬 벽: 편집이 0·30·90틱 늦을 때 보정 0·2·3번(마지막 29·41틱), 최대 오차 2.6px, 편집 뒤 0번. 같은 틱 채굴 세 경우 모두 한 번만 깨짐 |
| 세션 `four` 던전 경주 (4번) | 바위는 늘 정확히 한 번 깨짐, 깬 쪽(자리 1 한 번, 자리 2 세 번)에 돌. 두 클라이언트가 같은 틱에 맞은 일은 없었다(c3가 4~15틱 먼저 또는 늦게). 던전은 32바이트 조각 10개·2틱 |
| 일부러 깨 보기 (스크래치 `r4m3/mut/mut3b.py`, 23개 + 창 1개) | 23개 모두 FAIL·종료 1, 창 그림 검사로 1개 FAIL (아래) |

트래픽 (M3b, localhost, ENet 바이트, 괄호는 UDP/IP 포함. 전체 실행 둘 + `--net-exe` + `--net-full`, 호스트 송신, "c1 수신"은 그 묶음 동안 c1이 받은 것):

| 상황 | 호스트 송신 | 비고 |
|---|---|---|
| pair 둘 다 걸음 (2/2) | 1,068~1,078 B/s (1.72~1.74 KB/s), 23 pkt/s | M2b 1,031~1,038: 상태가 16 → 17B(지도) |
| pair 아무도 안 움직임 (0/2) | 166~207 B/s | M2b 167~182 |
| pair 한 사람 동작 중 (act1/2) | 1,072~1,091 B/s | M2b 1,015~1,055 |
| cave 둘 다 서 있고 지도가 다름 (0/2 split, 약 3.6초) | 88~106 B/s (213~247 B/s), 4.5~5 pkt/s. c1 수신 140~146 B/s | 조용하다: 상태 묶음 없음, ENet 유지 패킷 정도. 같은 지도의 pair 0/2보다 낮다(이 묶음엔 편집·연결 인사가 없다) |
| cave 호스트가 던전에서 캠, c1은 지상 (act1/2 split) | 1,070~1,087 B/s. c1 수신 1,070~1,083 B/s | c1은 상태 묶음만 받는다(던전 편집 0개). 같은 지도에서 둘이 걸을 때(2/2)와 같은 크기 |
| cave 둘 다 던전에서 캠 (act2/2) | 1,344~1,387 B/s (2.33~2.40 KB/s), 35~36 pkt/s. c1 수신 1,343~1,362 B/s | 상태 + 서로의 채굴 편집. 지상에 있을 때보다 c1 수신이 약 270~290 B/s 많다 |
| cave 지도를 보내는 틱 (entering, 9틱) | 12.3 KB/s × 0.15초 ≈ 1.8KB | 지도 들어옴 세 번(c1 내려감 345B, 올라옴 566B, c2 내려감 311B) + 그 틱의 상태 |
| four 둘이 던전에서 같은 바위를 침, 나머지 둘은 지상 (act2/4 split) | 5.51~5.56 KB/s (7.70~7.77 KB/s), 78~80 pkt/s | M2b의 four 4/4(걸음) 5.0 KB/s와 비슷하다 |
| four 아무도 안 움직임 (0/4) | 276~354 B/s | M2b 428~580 |
| 9인 걸음 (`--net-full`, 9/9) | 28.2 KB/s (33.8 KB/s ≈ 0.27 Mbps), 200 pkt/s | M2b 26.4: 9명 × 1B × 20Hz × 8 클라이언트 ≈ 1.4 KB/s 더 |

일부러 깨 보기 (M3b, 스크래치 `r4m3/mut/mut3b.py`, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 23개 모두 FAIL·종료 1, 처음 돌린 대로): 호스트가 요청의 지도를 안 봄, TRAVEL 손 닿는 칸 검사 빼기, 받는 중 TRAVEL 허용, TRAVEL 요청 예산 빼기, 아무 칸이나 던전으로 가는 길, 편집을 모든 클라이언트에게(지도 무시), 지도를 받는 중인 클라이언트에게도 편집, 지도 들어옴 뒤 따라잡기 편집 안 보냄, 모든 편집을 지상 기록에, 채굴을 지상 데이터로, 옮긴 멤버가 옛 지도 데이터로 걸음, 클라이언트가 모든 지도의 플레이어를 그림, 클라이언트가 다른 지도의 편집을 적용, 보간이 두 지도를 섞음, 다른 지도의 스냅샷을 받아 줌, 상태에서 지도 빼기(net·net_maps), 예측이 다른 지도의 상태를 맞춤, 다시 돌릴 때 옛 지도를 겨눈 사용을 시작함, 지도 조각이 끝나기 전에 지도 들어옴, 지도 전환 뒤 예측이 옛 데이터로 충돌 — 여기까지 `test_net_maps.gd` — 그리고 실제 세션 `cave`로: 클라이언트 F가 입구에서 TRAVEL이 아니라 PICKUP(둘이 던전에서 캐지 못함), Main이 새 지도를 보이지 않음(그려짐 검사), 프레임이 지도를 늘 지상으로(c1의 던전 사용이 `wrong map`이라 동작 보정 1). 창 그림 검사로: 받은 지도의 금 오버레이를 안 그림(`CaveView.setup`이 광맥 칸만 오버레이) → `cave_net` FAIL(클라이언트 = 합성 불일치 179, 호스트 = 클라이언트 179. `cave`는 그 그림을 편집으로 그려서 통과)

M3a (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.8~3.9초, 종료 0, 오류 줄 0 (새 스크립트 8개의 `.uid`, 새 PNG 18장의 `.import` 생김, 커밋) |
| 타일셋 다시 만들기 | 두 번 만들어 둘 다 같은 md5. 지상 `surface.tres`는 그대로(`ae29305880186ae9c5e6de5f5a813c8e`), 던전 `dungeon.tres` = `4278922a8774b0305fca5f0a28b19fe3` (소스 2, 타일 30, 코너 키 21) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 12파일 통과 7,293 checks 83.1~83.5초 종료 0 (actions 1,055 / actors 1,588 / aim 1,094 / core 266 / dungeon 76 / items 1,510 / light 73 / mining 81 / net 425 / net_session 377 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M2-fix보다 약 9초 늘었다: 새 파일 둘(6.0 + 2.9초) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 378 checks 49.5초 |
| 던전 생성 / 동굴 그림 (헤드리스, 예열 뒤) | 시드 1 64×48: 생성 24.2~24.3ms, `CaveView.setup` 55~73ms(그림 칸 3,185개 + 광맥 오버레이 47개) |
| 던전 규칙 40시드 | 모든 규칙 통과, fallback 그림 칸 모두 19개. 시드 1: 방 7, 광석 칸 47, 벽 횃불 8, 열린 칸 511 |
| 창 그림 검사 `check_render.gd` | 3.3초, 8부분 모두 ok. `cave` 불일치 0(금 1·2·3단계, 앞면 있는 벽 3, 깬 칸 1, 오버레이 18), `dark` 반경 밖 77,100픽셀 중 밝은 것 0, 첫 단계 안 3,064픽셀 중 어두운 것 0 |
| 내보내기 | x86_64 3.3초 `evensong.exe` 109,740,048 B, ARM64 3.3초 92,133,904 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give=pickaxe,torch:5 --start-map=dungeon`) | 243 checks ok (`dungeon=64x48 hash=009e7147ad79 ores=47 items=25`), 0.75초 / 1.3초 종료 0 오류 줄 0 |
| 지상 월드 | 해시 `1d9f92c7b5ef2a715f95cc32d7424b36`(입구 칸 2개), 스냅샷 원본 73,762B → 압축 576B 근처, 여전히 조각 1개. `stall`의 c2는 1바이트 조각 570개·72틱 |
| 스크린샷 3장 | 위 "스크린샷"의 M3a 명령, 모두 480×270 (창 960×540), 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r4m3/mut/mutate.py`, 25개 + 창 2개) | 25개 모두 FAIL·종료 1 (처음 돌렸을 때 놓친 셋은 아래), 창 그림 검사로 2개 FAIL |

일부러 깨 보기 (M3a, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 `--only=dungeon,mining` 중 해당 파일을 돌리고 되돌림. 25개 모두 FAIL·종료 1, 황금 해시만 틀린 것이 아니라 규칙 검사로): 앞면 칸이 안 막힘, 벽이 안 막힘(걷기), 광부가 1×1, 3×3을 가운데로, 광부 타격이 공용과 같음, 공용 경도 상한 = 광부, 금 단계를 내림으로, 가득 찬 인벤토리면 사라짐(드롭 없음), 벽 횃불이 벽과 같이 안 없어짐, 기반암이 깨짐, 방을 통로로 안 이음, 광맥이 아무 바위에나(바닥 옆 아님), 다시 그리는 범위 세로 3줄, context 무시, 맞는 틱 1틱 늦게, 횃불을 앞면 칸에, 호스트가 횃불 USE 무시, 호스트가 채굴 안 함, F로 안 오감, 벽 편집을 안 다시 그림, 지상 입구 없음, 세션 호스트가 입구 F를 받아 줌, 횃불 빛 텍스처가 반경 너머까지, 앞면을 치면 위 벽에 안 닿음, 계단 위 바위의 보호 빼기(`Walls.hardness`). 처음 돌렸을 때 놓친 셋: 계단 위 바위 보호 빼기(생성기가 그 바위를 기반암으로도 만들어서 행동이 같았다 → 손으로 만든 계단에 바로 시험을 더함), 다시 그리는 범위(무작위 편집 120번에는 context 타일이 바뀌는 경우가 없었다 → 작은 동굴에 촘촘한 편집 800번, 25번마다 새 그림과 비교), 맞는 틱 1틱 늦게(호스트 시험이 `impact_tick()` 자체를 기준으로 셌다 → 동작 시작부터 프레임마다 세어 18틱째인지). 창 그림 검사로: 앞면 금을 1px 아래로 → `cave` FAIL(불일치 129픽셀, 처음엔 합성이 스프라이트 자리를 그대로 써서 놓쳤다 → 합성을 데이터와 따로 적은 자리로), 횃불 빛 `texture_scale` 2 → `dark` FAIL(반경 밖 밝은 픽셀 28,148)

M2-fix (2026-10-22, M2b 검토 반영):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.2초, 종료 0, 오류 줄 0 (새 스크립트 없음, `.uid` 변화 없음) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 10파일 통과 7,053 checks 74.1~74.3초 종료 0 (actions 1,055 / actors 1,569 / aim 1,094 / core 257 / items 1,455 / light 73 / net 425 / net_session 377 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. `four`의 c4: 563B를 18조각, `stall`의 c2: 567조각 71틱 |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 378 checks 49.0초 |
| 내보내기 | x86_64 3.3초 `evensong.exe` 109,645,520 B, ARM64 3.2초 92,039,376 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give=pickaxe,stone_a:300`) | 227 checks ok, 0.57초 / 1.2초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.4초, 6부분 모두 ok |
| 스크린샷 다시 찍기 | 목표 칸 표시가 보이는 5장(`m2_hotbar`·`m2_aim`·`m2_use`·`m2b_host`·`m2b_client`)을 위 명령 그대로 다시 찍었다. `m2_aim`의 표시가 이제 아처 발 서쪽 같은 줄이다(전에는 남서). 두 창 호스트 로그 `action ... target=61,47`(전에는 61,48, 발은 47줄) |
| 일부러 깨 보기 (스크래치 `r3m2/fix/mut/mutate.sh`, 15개) | 15개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M2-fix, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 테스트 파일을 돌림. 15개 모두 FAIL·종료 1): 서서 바라보기만 바뀐 프레임을 기록하지 않기(world_items + `pair` 세션 셋 다 c1이 서쪽), `on_inventory`에서 프레임에 실린 고르기 / 줄에 있는 고르기를 다시 얹지 않기(각각), `SessionHost.tick`이 자리를 거꾸로 처리, `MAX_DROPS` 검사 빼기, 목표 칸을 발 점의 칸으로(aim 72개·actions), 손 닿는 칸을 발 점의 칸으로, 사용의 바라보기를 look 그대로, 동작 중 표시를 마우스 칸으로, 고르기를 다시 예산에 넣기, 거부된 고르기에 인벤토리 안 보내기, `PlayerSim`의 대각선 바라보기를 큰 축으로(600틱 중 300틱만 M1과 같음), 클라이언트 주기를 나누지 않기, 클라이언트 버리기 허용, 줄의 고르기도 토큰 기다리기

M2b (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.2초, 종료 0, 오류 줄 0 (새 스크립트 4개의 `.uid` 생김, 커밋) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 10파일 통과 6,979 checks 72.8~73.1초 종료 0 (actions 1,053 / actors 1,569 / aim 1,059 / core 257 / items 1,455 / light 73 / net 425 / net_session 373 / world 429 / world_items 286). 오류 묶음은 알린 8개뿐. M2a보다 약 18초 늘었다: 거의 세션 시험(약 37 → 51~52초: pair의 걷기·줍기·늦은 참가자 걷기, four의 경주, stall의 드롭) |
| 세션 시험 `--net-full` | 통과 602 checks 56.0초 (9인 상한 세션 포함) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 374 checks 50.2초 (자식 17개 모두 내보낸 exe, pair 호스트에 `--test-allow-give`) |
| 내보내기 | x86_64 3.2초 `evensong.exe` 109,644,208 B, ARM64 2.8초 92,038,064 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give` 포함) | 227 checks ok (`gatherables=74 ... net=v3`), 0.67초 / 1.2초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.6초, 6부분 모두 ok. `items` 채집물 9 + 드롭 1, 불일치 0. `ground`는 판정 픽셀이 129,347 → 129,333(제단 화면 오른쪽 위 끝에 채집물 하나가 들어와 어두운 외곽선 픽셀이 빠짐), 불일치 0 |
| 두 창 그림 | `shots/m2b_host.png`, `shots/m2b_client.png` 480×270 (창 960×540), 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r3m2/m2b/mutate.py`, 22개 + 창 1개) | 22개 모두 FAIL·종료 1, 창 그림 검사로 1개 FAIL (아래) |
| 시드 1 월드 | 원본 73,749 → 73,751B(드롭 개수 2B), 압축 341~342 → 563~576B(채집물 74칸 + 실행 중 드롭), 여전히 조각 1개. 늦은 참가 준비 68~129ms |

트래픽 (M2b, localhost, ENet 바이트, 괄호는 UDP/IP 포함. 세 번 + `--net-full` 한 번):

| 상황 | 호스트 송신 | 비고 |
|---|---|---|
| pair 둘 다 걸음 (2/2) | 1,031~1,038 B/s (1.67~1.70 KB/s), 23 pkt/s | M1 950~970: 상태가 14 → 16B |
| pair 아무도 안 움직임 (0/2) | 167~182 B/s | M1 111 또는 193~225. 이 묶음에 바닥 편집과 늦은 참가자의 연결 인사가 들어 있다(H-fix에서 잰 것과 같은 원인) |
| pair 한 사람 동작 중 (act1/2) | 1,015~1,055 B/s (1.65~1.71 KB/s), 22~23 pkt/s | 동작 중에는 상태가 매 틱 바뀌어 걸을 때처럼 20Hz로 나간다. 그 클라이언트 송신 526~561 B/s(동작 동안 매 틱 프레임) |
| pair 둘 다 동작 (act2/2) | 1,001~1,075 B/s | |
| four 경주 + F 마구 누르기 (req/4) | 5.04~5.11 KB/s (7.05~7.17 KB/s), 72~73 pkt/s | 처리한 프레임의 확인이 묶음으로 나간다(셋 다 걸을 때 4/4의 5.0 KB/s와 같다) |
| four 아무도 안 움직임 (0/4) | 428~580 B/s | M1 458~550 |
| 9인 걸음 (`--net-full`, 9/9) | 26.4 KB/s (31.9 KB/s ≈ 0.26 Mbps), 197 pkt/s | M1 22.0~23.1 KB/s. 9명 × 2B × 20Hz × 8 클라이언트 ≈ 2.9 KB/s 더 |

일부러 깨 보기 (M2b, 스크래치 `r3m2/m2b/mutate.py`, 하나씩 바꾸고 해당 테스트 파일을 돌리고 되돌림. 22개 모두 FAIL·종료 1): 손 닿는 칸 검사 빼기, 줍기 편집을 바로 적용하지 않음(같은 틱 경주에서 둘 다 가짐), 약초사도 일반 등급, 요청 예산 빼기, 동작 중 사용 허용, 클라이언트가 동작을 예측하지 않음(호스트가 돌린 동작 수가 예측과 다름), 동작 중 프레임 기록 안 함(동작 보정 2), 상태에서 동작 빼기, 상태에서 든 아이템 빼기, 스냅샷에서 드롭 빼기, 월드 해시에서 드롭 빼기, 식생 편집 때 그림 안 고침, 보간이 새 상태의 동작 시작을 안 봄, 주기를 늘 허용, 제단 칸에 버리기 허용, 채집물을 빛 안에도, 프레임 코드에서 바라보기 빼기, 드롭이 다 안 들어가도 통째로 줍기, 그리고 실제 세션으로: 주인에게 인벤토리 안 보냄(pair c1이 검을 못 가짐), 상태의 든 아이템을 빈 손으로(pair), 줍기 칸을 한 칸 밀기(pair c2 스냅샷 편집 위치 2), 클라이언트가 드롭 편집을 적용 안 함(pair c2 월드 다름). 창 그림 검사로: 채집물 그림 1px 아래로 → `items` FAIL(불일치 1,054픽셀)·종료 1

M2a (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.0초, 종료 0, 오류 줄 0. 단 새 PNG를 처음 넣고 `.import` 파일이 아직 없을 때의 첫 임포트는 스크립트를 먼저 읽어 `Preload file ... has no resource loaders` 줄 8개가 나왔다(종료 0). 한 번 더 임포트하면 없어지고, `.import`를 커밋했으니 클론에서는 나오지 않는다 |
| 전체 테스트, 세 번 (마지막은 마지막 코드) | 세 번 모두 9파일 통과 6,550 checks 55.1~55.4초 종료 0 (actions 1,053 / actors 1,569 / aim 1,059 / core 253 / items 1,455 / light 73 / net 357 / net_session 302 / world 429). 오류 묶음은 알린 8개뿐. H-fix보다 약 8초 늘었다: 동작 기준점 다시 재기(0.5 → 2.1초), 창 크기 6가지 조준 시험(4.0초), 동작 시험(2.3초) |
| 동작 프레임 그림 (`test_actions.gd`) | 5클래스 × 4방향 × 55프레임 = 1,100개: 노드가 그리는 스프라이트를 CPU로 합친 그림 = 시트 + 문서 규칙으로 합친 그림, 42~47ms |
| 조준 (`test_aim.gd`) | `main.tscn`에서 창 6가지 × (가운데·북서 모서리) × 마우스 9곳(뷰포트 테두리 8 + 검은 띠) = 108곳. 가운데일 때 테두리 8곳이 8구역을 다 낸다 |
| 창 그림 검사 `check_render.gd` | 2.2초, 5부분 모두 ok. `rig` 65화면(그중 몸 동작 55) × 20명, 불일치 0 |
| 내보내기 | x86_64 2.9초 `evensong.exe` 109,599,712 B, ARM64 2.9초 91,993,568 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give` 포함) | 208 checks ok (`items=22 actions=8`, 기준점 표 모양이 10동작이라 늘었다), 0.46초 / 1.2초 종료 0 오류 줄 0 |
| 세션 테스트를 내보낸 exe 자식으로 (`--net-exe`) | 통과 303 checks 34.8초 (자식 모두 내보낸 exe) |
| 스크린샷 4장 | 위 "스크린샷"의 M2a 명령, 모두 480×270 (창 960×540) |
| 일부러 깨 보기 (스크래치 `mutate.py`, 21개) | 21개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M2a, 스크래치 `r3m2/mutate.py`, 하나씩 바꾸고 해당 테스트 파일을 돌리고 되돌림. 21개 모두 FAIL·종료 1): 곡괭이 시트 재생 첫 칸 1 → 0, 64칸 안의 32 프레임 자리 (16, 16) → (16, 15), 손에 든 표식 숨기기 끄기, 괭이 동작에서도 곡괭이 숨기기, 캐릭터가 동작 칸 자리를 빼먹음, 던지기 옮김 +4 +4 +3 → +4 +3 +4(actions·actors), 기준점 재기가 동작 칸 자리를 빼먹음(actors: 커밋된 표와 다름), 동작 중 이동 잠금 빼기, 프레임 = 틱 / 7, 누르고 있어도 반복 안 함, 조준 없이도 마우스 쪽 보기(M1 바라보기 600틱 중 60틱만 같음), 구역을 round 대신 floor, 목표 칸 한 구역 밀기, 검은 띠 빼기, 조준을 캔버스 변환 대신 창 좌표로, 맵 밖 표시 숨기기 빼기, 등급 무시하고 쌓기, 핫바 Q/E가 끝에서 안 돌기, 묶음 전체 나누기 허용, 도구가 99개씩 쌓임, Q와 E 바꾸기. 창 그림 검사로: 캐릭터가 동작 칸 자리를 빼먹음 → `rig` FAIL(불일치 655,477픽셀)·종료 1

같은 기기라도 실행 때마다 흔들린다. H1 검토 에이전트가 같은 데스크탑에서 잰 값은 아래 H1 표보다 최대 약 1.8배 느렸다(스냅샷 그리기·참가, 전체 테스트 46초). 그래서 H-fix는 이 세션에서 여러 번 돌린 범위로 적는다.

H-fix (2026-10-22, H1 검토 반영):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.2~4.4초, 종료 0, 오류 줄 0 (새 스크립트 없음, `.uid` 변화 없음) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 6파일 통과 2,592 checks 46.8~47.0초 종료 0 (actors 1,188 / core 243 / light 73 / net 357 / net_session 302 / world 429). 오류 묶음은 알린 7개뿐. 이 세션의 다른 전체 실행은 49~52초. H1보다 약 7초 늘어난 것은 새 `stall` 세션(약 7초)이다 |
| 세션 테스트만 | 35.5~38.0초 (`stall` 포함). 내보낸 exe 자식으로(`--net-exe`) 통과 303 checks 35.2초 |
| 내보내기 | x86_64 3.2초 `evensong.exe` 109,500,872 B, ARM64 2.8초 91,894,728 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 85 checks ok, 0.5초 / 1.1초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 1.5초, 5부분 모두 ok (`_hidden_by`의 줄 잇기만 고침) |
| 호스트 멈춤, 실제 세션 (스크래치 2프로세스 + `stall` 세션) | 0.7초 멈춤(물리 틱 밖), 걷는 클라이언트 대기열 최고 42프레임. H1 규칙: 속도 제한 틱 194~204, 중복 프레임 1,813. H-fix: 0, 중복 885~960(다시 담은 것이 줄었다), 크레딧 39~40틱 사용, 예측 오차 0 |
| 호스트 멈춤, 모형 (`long_stall.gd`, 스크래치: 실제 `Prediction` + `InputGate`, Godot 순서) | 1초(60틱)까지 버림·빈 번호·보정 0. 64틱부터 대기열 상한을 넘은 프레임을 버림(64틱 2개, 90틱 262개), 빈 번호와 보정은 아직 0. 100틱(1.7초)부터 빈 번호 1개 + 보정 한 번: 1.7초 9.6px, 2초 33.6px, 2.5초 69.6px, 3초 이상 98.4px(클라이언트가 확인 안 된 프레임을 128개까지만 들고 있어서 더 커지지 않음) |
| ENet 패킷 조절 (스크래치 2프로세스: 0.7초 멈춤 + 4틱마다 편집 150번, 걷는 클라이언트, 호스트가 6틱마다 조절 값 기록) | ENet 기본: 6번 중 5번 32 밑으로, 1번은 약 7초째부터 0~8로 떨어져 확인 138번(다른 실행 152). 감속 0: 6번 모두 653번 잰 값이 다 32, 확인 152~153 |
| 늦은 참가 연결 인사가 서 있는 묶음에 드는 양 (스크래치: 둘이 서 있는 세션, 참가자 있음/없음 두 번씩) | 참가자가 붙으면 0/2 묶음 패킷 +3, 약 +135B |
| 일부러 깨 보기 (스크래치 `hfix/mutate.py`, 14개) | 14개 모두 FAIL·종료 1 (아래) |

H-fix 범위 (이 세션에서 돌린 전체 테스트 6번과 세션 테스트만 7번):

- `test_net.gd` 스냅샷: 128×96 그리기 20~33ms·참가 21~34ms, 512×512 합성 압축 3.3~4.4ms·그리기 445~742ms·참가 552~853ms, 512×512 무작위 압축 5.1~7.6ms·검사 + 풀기 4.0~5.0ms
- 실제 세션 늦은 참가(에디터 빌드 자식): 접속에서 월드 준비까지 76~116ms(그중 검사 + 풀기 + 그리기 22~41ms). 내보낸 exe 자식은 68~83ms(14~16ms)
- pair 0/2(호스트 송신): 109.8~115.2 B/s 또는 193.5~225.5 B/s. 뒤쪽은 늦은 참가자의 ENet 연결 인사(약 135B)가 그 1.45초 안에 떨어진 실행이다(위 "트래픽 통계"). 이 세션의 세션 실행 14번 중 4번
- 호스트 멈춤 단위 모형(1초): 물리 틱 안 멈춤은 대기열 최고 62 → 30틱 뒤 4 이하, 18틱 동안 여러 개씩 적용, 크레딧 0. 틱 밖 멈춤은 최고 60 → 4 이하, 20틱, 크레딧 59. 둘 다 속도 제한 0, 틱당 최대 4

일부러 깨 보기 (H-fix, 스크래치 `hfix/mutate.py`, 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 14개 모두 FAIL·종료 1): 게이트에서 멈춤 크레딧 빼기(H1 규칙) → 단위 시험(틱 밖 순서 대기열 31·제한 409틱)과 `stall` 세션(제한 191~194틱) 둘 다, `ticks_between`이 1000배 → 단위 시험, 호스트가 게이트에 1000배 시간을 줌 → 세션의 "토큰이 실제 시간을 따라감"(pair 401틱에 25,664틱), 호스트가 실제 시간 대신 틱마다 1(H1 전 규칙) → `stall`, 틱당 따라잡기 상한 빼기, 크레딧이 더해지게(30fps 흉내에서 300틱), 호스트가 스냅샷을 한 틱에 다 보냄 → 세션의 틱 수 검사(`four` 11조각 1틱), welcome 뒤 따라잡기 편집 안 보냄 → `stall`/c2 월드·편집 수·잘못된 메시지 46, 포트 확인을 `*` 하나로 → `test_core`(IPv4만 잡은 포트), 포트를 못 잡아도 파일을 돌림 → `test_core`, 여러 걸음 틱을 직선으로 그림 → `test_actors`(제단 안 5번), `MAX_SIDE` 2048로 → 단위 시험(52초 거리), ENet 조절 설정 빼기 → 단위 시험((5000, 2, 2))

H1 다지기 (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.1초, 종료 0, 오류 줄 0 (새 스크립트 4개의 `.uid` 생김, 커밋) |
| 전체 테스트, 두 번 | 두 번 모두 6파일 통과 2,459 checks 40.2초 종료 0 (actors 1,184 / core 229 / light 73 / net 326 / net_session 218 / world 429). 오류 묶음은 알린 7개뿐. G3보다 약 5초 느린 것은 러너 자식 마감 시험(2초)과 스냅샷 참가 측정(512×512 그리기 등 약 1.5초)이다 |
| `--net-full` | 통과, 397 checks, 34.3초 |
| 내보낸 exe로 세션 테스트 (`--net-exe=build/evensong.console.exe`) | 통과, 219 checks, 28.0초 (자식 14개 모두 내보낸 exe) |
| 내보내기 | x86_64 3.2초 `evensong.exe` 109,498,424 B, ARM64 3.0초 91,892,280 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 85 checks ok (스냅샷 왕복 하나 더, `snapshot=342B/73749B net=v2`), 0.6초 / 1.2초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.8초, 5부분 모두 ok (ysort 캐릭터 6, 제단 옆면 둘 `side_pixels_hidden=0`) |
| 두 창 스크린샷 | `shots/net_host.png`, `shots/net_client.png` 다시 찍음. 클라이언트 `join_ms=114.6` (창 모드, 그리기 56.8ms 포함) |
| 테스트 포트 | 두 러너를 동시에 띄우면 하나는 24621-24640, 하나는 24641-24660(둘 다 통과). `--port-base=25000` → 25000-25019, `EVENSONG_TEST_PORT_BASE=25100` → 25100-25119. 다른 실행이 쥔 묶음을 `--port-base`로 주면 `FAIL (startup) ... no free block`·종료 1 |
| 러너 자식 마감 | 30초 걸릴 자식을 2.05초에 죽이고 실패로 보고 |

늦은 참가 월드 스냅샷 (`test_net.gd`, 한 프로세스 안 ENet localhost로 조각 전송, 호스트처럼 1/60초마다 8조각씩. "참가"는 압축 + 전송 + 받는 쪽 검사·풀기 + 그리기):

| 월드 | 원본 → 압축 (zstd) | 조각 / 틱 | 압축 | 전송 | 검사 + 풀기 | 그리기 | 참가 |
|---|---|---|---|---|---|---|---|
| 128×96 M1 맵 (시드 1) | 73,749 B → 342 B (0.5%) | 1 / 1 | 0.2~0.3ms | 1틱 안 | 0.1~0.2ms | 20~21ms | 약 22ms |
| 512×512 합성 (생성기 + 벽 노이즈 덩어리·광맥·식생, 레이어 6장 다 씀) | 1,572,885 B → 54,210 B (3.4%) | 53 / 7 | 3.3~3.6ms | 102~103ms | 2.9~3.3ms | 441~467ms | 약 550~580ms |
| 512×512 무작위 (위 한계, 모든 칸 무작위) | 1,572,885 B → 약 1,377,950 B (87.6%) | 1,346 / 169 | 5~6ms | 2.8초 (틱 수로 계산, 보내지 않음) | 4~9ms | (안 그림) | 약 2.8초 + 그리기 |

- 실제 세션(헤드리스 자식, localhost): 늦은 참가자가 접속하고 월드가 준비되기까지 71~95ms(hello 왕복과 호스트 틱 기다림 포함, 그중 검사 + 풀기 + 그리기 18~24ms). `four`는 32바이트 조각 11개로 두 틱(M2b부터 채집물 때문에 18개·세 틱). 창 모드 클라이언트는 그리기가 길어 115ms. (H1 한 번의 측정. 여러 번 잰 범위는 위 H-fix)
- 참가 트래픽은 "joining" 묶음으로 따로 센다: pair 두 참가자 1,415 B(패킷 15), four 32바이트 조각으로 4.3~4.4 KB(패킷 75~78), `--net-full` 여덟 참가자 8.8 KB(패킷 113). 그래서 서 있을 때 트래픽은 G3와 같은 값으로 돌아왔다: pair 0/2 111 B/s, four 0/4 458~477 B/s, 9인 0/9 1.47 KB/s. 걸을 때: pair 949 B/s, four 4.4~4.5 KB/s, 9인 22.5 KB/s. (pair 0/2는 늦은 참가자의 연결 인사가 그 구간에 떨어지면 약 195~225 B/s다. H-fix에서 원인을 잼)
- 128×96의 그리기(20ms)는 G2의 "그림 칸 12,513개 그리기 33~36ms"와 같은 일이다(이번 측정이 더 빨리 나왔다. 기기 상태 차이)
- 512×512 무작위는 실제 월드가 아니라 압축이 안 될 때의 위 한계다. 틱당 8KB라 1.3MB는 2.8초 걸린다. 더 큰 맵은 "근처 청크부터"(스파이크 RESULTS §5) 같은 순서가 필요하다(아래 알려진 문제)

그 밖의 H1 측정:

- 호스트 멈춤 (`test_net.gd`): 걷는 클라이언트, 호스트가 60틱(1초) 멈춘 뒤 Godot처럼 따라잡기 틱 8개를 한꺼번에. 대기열 최대 61프레임 → 30틱 뒤부터 최대 1프레임. 예전 규칙(호출마다 토큰 1)으로 바꾸면 25프레임에서 내려오지 않는다(일부러 깨 보기). **H-fix에서 틀렸음이 밝혀짐**: 이 모형은 멈춘 동안의 프레임을 따라잡기 틱 전에 넣었다(물리 틱 안의 멈춤). Godot은 따라잡기 틱 뒤에 네트워크를 읽어서 실제 세션에서는 대기열이 약 30프레임 뒤처진 채였다(위 H-fix)
- 틱 사이에 그리기 (`test_actors.gd`, 144Hz 흉내, 1초 중 50틱 걷기): 프레임 사이 x 걸음 {0px: 84, 1px: 60} (예전 반올림 위치 그리기는 {0: 94, 1: 40, 2: 10}). 시뮬레이션 위치·바라보기·걷기는 모든 틱에서 같음
- 제단 옆 띠: 몸은 발에서 왼쪽 9px·오른쪽 9px까지(모든 방향·프레임), 제단 그림 불투명 열 0~46 → (서 5, 동 3). 옆면 높이의 모든 줄(46줄 × 양쪽)에 붙어 서도 몸 픽셀이 제단 그림에 겹치는 것 0. 장비는 아직 서쪽 6px(광부가 서쪽을 볼 때 곡괭이), 동쪽 7px(광부가 동쪽을 볼 때)까지 제단 가장자리 뒤로 들어갈 수 있다
- 바라보기: 가짜 연결 예측(지연 0·5·9틱, 손실 0·25%)과 모든 세션에서 바라보기 보정 0. 프레임 하나 1바이트 그대로(코드 36개 → 9개)

일부러 깨 보기 (H1, 스크래치 `mutate.py`, 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 17개 모두 FAIL·종료 1): 클라이언트가 자기 생성기로 월드 만들기(pair/c2 월드·그림 해시 다름), 받는 쪽이 월드 해시 검사 빼기, 보내는 쪽이 틱당 개수 넘기기, 호스트가 마지막 조각 전에 welcome(four/c4 종료 5), 호스트가 클라이언트 바라보기를 정하지 않기(세션 바라보기 보정 21), 예측 다시 돌리기가 바라보기를 안 정하기, 입력 토큰을 예전 규칙으로, 러너 자식 마감 빼기(30초 기다린 뒤 FAIL), 묶음 잠금 빼기, 묶음 UDP 확인 빼기, 제단 옆 띠 0, 서쪽 띠 1px 모자람(몸 픽셀 41개가 제단 그림에 겹침), 틱 사이 그리기 끄기, `begin_tick`이 시작점을 안 남기기, 물리 틱에서 `begin_tick` 안 부르기, 예측 걸음을 보정처럼 다루기, 월드 조각 RPC를 클라이언트가 부를 수 있게. 처음 돌렸을 때 "예측 걸음" 시험 하나는 기대값이 우연히 깬 결과와 같아 못 잡았다. 그 시험을 고치는 중에 진짜 문제를 찾았다: 그리는 시작점을 `apply_input` 안에서 남기면, 호스트에서 어떤 틱에 프레임이 안 온 다른 플레이어가 지난 틱 시작점으로 한 걸음 뒤로 그려진다. 그래서 시작점을 물리 틱마다 모든 플레이어에 남기게(`begin_tick`) 바꾸고 그 경우를 시험에 넣었다

M1 검증 반영 (2026-10-22, 러너·임시값 정리 뒤):

| 단계 | 결과 |
|---|---|
| 임포트 (두 번 했다: 고친 뒤, 주석 하나 더 고친 뒤) | 두 번 모두 3.0초, 종료 0, 오류 줄 0 (새 픽스처 `.uid` 2개 생김, 커밋) |
| 전체 테스트, 임포트마다 두 번 | 네 번 모두 6파일 통과 2,310 checks 35.4~35.6초 종료 0 (actors 1,138 / core 203 / light 73 / net 279 / net_session 188 / world 429). 오류 묶음은 알린 7개뿐 (위 "전체 테스트") |
| 러너 자체 시험 | 픽스처 11개 + `late_error.gd`를 자식 프로세스 둘로, 약 2.9초 |
| 내보내기 (두 번) | x86_64 2.5~2.6초 `evensong.exe` 109,481,520 B, ARM64 2.4~2.5초 91,875,376 B, 모두 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 84 checks ok (월드 해시 비교 하나 더), 0.4~0.5초 / 1.1초 종료 0 오류 줄 0. 에디터 빌드 `--smoke`도 84 checks ok |
| 러너 일부러 깨 보기 (커밋 안 함) | 남긴 노드를 지우지 않기, 남긴 노드 검사 빼기, 마지막 파일 뒤 기다림 0프레임, `GOLDEN_HASH` 한 글자. 4개 모두 `test_core.gd`(해시는 `test_world.gd`도) FAIL·종료 1 |
| 검증 에이전트의 탐침 9개 + 변형 1개 (스크래치에서 `tests/`에 잠깐 복사, 지움) | 루트에 노드를 남기는 탐침(3번째 프레임에 오류, 그리고 2번째 프레임으로 바꾼 변형)은 이제 그 파일이 FAIL이고 뒤 파일(통과 탐침)은 PASS, 혼자 돌려도 FAIL. 나머지 7개(알리지 않은 엔진 오류, 워커 스레드 push_error, 지연 호출, 타이머 콜백 실행 오류, `_exit_tree` 오류, 파싱 오류, 횟수 넘친 허용)는 전처럼 FAIL |

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
M2a = 혼자 할 때의 아이템·인벤토리·핫바·마우스 조준·몸 동작 재생과 최소 HUD. 동작의 월드 효과(채굴·농사), 줍기, 전투·피해, 제작, 건설, 상인, 스킬, 기도, 저장, 나무(? game-concept §12)는 M2a가 아니다.
M2b = M2a를 호스트 권한 세션으로 + 지상 채집물과 F 줍기(등급 ● §3.4) + 떨어진 아이템(디버그 버리기) + 늦은 참가에 그것들. 채굴 효과, 농사, 전투·피해, 제작, 건설, 상인, 스킬, 기도, Steam, 저장, 나무·나뭇가지·통나무는 M2b가 아니다.
M3a = 혼자 할 때의 지도 둘(지상 + 첫 던전), 던전 생성·그림, 입구·계단으로 오가기, 벽 충돌, 채굴(공용·광부), 던전 어둠과 횃불. 세션의 던전(M3b), 전투·HP·적·적 생성(M4), 이단의 제단 파괴(M4), 농사, 제작, 건설·벽 놓기, 상인, 스킬, 기도, Steam, 저장, 나무는 M3a가 아니다.
M3b = M3a가 더한 것을 호스트 권한 세션으로(지도 번호, 오가기, 지도 보내기, 지도별 편집·상태·그리기, 채굴·횃불 검사, 늦은 참가). 전투·HP·적·적 생성(M4), 이단의 제단 파괴(M4), 농사, 제작, 건설·벽 놓기, 상인, 스킬, 기도, Steam, 저장, 나무는 M3b가 아니다.

| 단계 | 내용 | 상태 |
|---|---|---|
| G1 뼈대 + 월드 | 프로젝트·설정, 내보내기 2종, CLI·스모크, 테스트 러너(엔진 오류까지 셈, 자체 시험), 타일셋 빌더, 레이어 6장 데이터 + 꼭짓점 격자, dual grid 조회, 시드 생성기, 청크 바닥 그리기와 편집, world.tscn 자유 카메라, 테스트, 스크린샷 | **끝** |
| G2 캐릭터 + 빛 | 캐릭터 리그(5클래스, 걷기·idle 4방향, 서쪽 반전, 표식 레이어 오프셋 + 기준점 표, 발 기준 y 정렬), 이동·충돌(맵 경계, 제단), 플레이어 카메라, 제단 놓기 + 저녁 어둠 + 안전 반경 빛(바닥 디더 + 캐릭터 hard), `is_in_safe_zone()` = 빛, unshaded 불꽃, main.tscn(내 캐릭터 + 더미 넷), 테스트, 창 그림 검사, 스크린샷 | **끝** |
| G3 네트워크 | 전송 계층(ENet + Steam 자리, 시그널로 결과), 호스트·참가, 호스트 권한 이동(입력 프레임 → 호스트 검사·시뮬레이션 → 바뀔 때만 20Hz 묶음 + 키프레임) + 자기 캐릭터 예측·보정 + 남의 캐릭터 100ms 보간, 호스트가 세는 인원 상한 9 + 빈 스폰 자리 다시 쓰기, 클래스, 늦은 참가(시드 + 편집 기록 + 해시 확인, H1에서 스냅샷으로 바꿈), 다중 프로세스 테스트(2인·4인·지연/손실·호스트 잃음, 선택 10프로세스), 대역폭, 두 창·두 기기 명령 | **끝** |
| H1 다지기 | 늦은 참가 = 월드 스냅샷(레이어 6장, zstd, 1KB 조각 틱당 8개, 받는 쪽 검사, 생성기는 진단만, 흔든 생성기 참가자 시험, 128×96·512×512 크기와 참가 시간), 호스트가 바라보기를 정함(프레임에서 뺌), 호스트 멈춤 뒤 입력 대기열 돌아오기(실제 시간으로 토큰), 테스트 기반(러너 자식 마감, 테스트 포트 묶음 고르기·잠금), 제단 옆 겹침(옆 띠), 내 캐릭터를 틱 사이에 그리기, `session.gd` 흐름별로 나누기 | **끝** (사람 확인: 두 기기, 144Hz 화면) |
| H-fix 검토 반영 | 호스트 멈춤 따라잡기를 실제 세션 순서에서도(멈춤 크레딧, 틱당 4프레임, 시계 시험), ENet 패킷 조절 끔, 테스트 포트 IPv4 확인과 못 잡으면 멈춤, 여러 걸음 틱은 끝에 그리기, 스냅샷 크기 상한 512, `stall` 세션(멈춤 + 받는 도중 편집), 스트림 틱 수·토큰 실제 시간 세션 검사, 시험 정리 | **끝** (사람 확인: 두 기기) |
| M2a 아이템 · 조준 · 동작 | 아이템 표(도구 6·재료 1·채집물 15, 등급, 아이콘), 인벤토리 + 핫바(쌓기·나누기·옮기기·Q/E), 마우스 조준(8구역, 목표 칸, 마우스 쪽 바라보기, 창 늘이기 6가지를 엔진과 비교, 목표 칸 표시), 몸 동작 8개(64칸 발 맞춤, 기준점 다시 재기, 손에 든 표식 숨기기, 틱 단위 시간·이동 잠금·누르고 반복), 최소 HUD, 디버그 주기(`--give`, F5)·F6, 테스트 3파일 + 창 그림 검사, 스크린샷 4장. 혼자 할 때만 | **끝** (사람 확인: 마우스로 해 보기, 임시값 줄) |
| M2b 네트워크 + 월드 | 프레임 하나의 규칙(`PlayerSim`), 프레임에 바라보기·요청(사용·줍기·고르기·버리기·주기), 호스트 검사(손 닿는 칸·목표 칸·아이템·동작 중·요청 예산·주기 정책)와 같은 틱 경주, 상태에 동작·든 아이템, 주인에게만 인벤토리, 자기 동작·고르기 예측, 남의 동작 보간, 채집물 74개(식생 레이어, 등급 ● §3.4), 드롭 목록(해시·스냅샷·편집), 늦은 참가에 채집물·드롭·든 아이템, 전송 형식 v3, 봇 명령, 단위 시험 1파일 + 세션 시험 확장 + 창 그림 검사 `items`, 두 창 캡처 | **끝** (사람 확인: 두 기기로 휘두르기·줍기·경주, 임시값 줄) |
| M3a 지도 · 던전 · 채굴 · 횃불 | 지도 번호와 지도별 GameWorld, 던전 생성기(방·통로·광맥·기반암·출구 계단·이단의 제단 자리·벽 횃불, 황금 해시, 40시드 규칙), 던전 타일셋(절벽 셋 + context) 빌더와 동굴 dual grid(앞면, 광맥·금 오버레이), 지상 입구(생성기 5단계, 지상 해시 갱신), F로 오가기, 벽·앞면 충돌, 채굴(1×1/3×3, 경도·타격·금, 돌·광석, 가득 차면 드롭), 횃불(아이템·놓기·빛), 던전 어둠, 호스트 규칙(횃불·채굴, 입구 거부), 혼자 할 때 `--bot`·`--start-map`, 테스트 2파일 + 창 그림 검사 `cave`·`dark`, 스크린샷 3장 | **끝** (사람 확인: 아래 "M3a에서 확인하지 않은 것", 임시값 줄) |
| M3b 세션의 지도 | 플레이어마다 지도 번호(호스트 상태), TRAVEL 요청과 호스트 검사, 지도 보내기(스냅샷 길 + 지도 들어옴 + 그동안 편집, 클라이언트는 자기 지도만), 지도별 편집 기록·편집의 지도, 상태의 지도와 지도별 그리기·보간, 요청의 지도(`wrong map`), 지도 전환 예측, 늦은 참가에 지도, 채굴·횃불·드롭을 지도의 편집으로, 전송 형식 v4, 봇 `waitmap`·표시 파일 JSON, 단위 시험 1파일 + 세션 `cave`·`four` 던전 경주 + 지도별 일치 검사, 창 그림 검사 `cave_net`, 스모크 M3b, 두 창 캡처 | **끝** (사람 확인: 아래 "두 기기에서 M3 해 보기", 임시값 줄) |
| M2-fix 검토 반영 | 발 칸 = 발 상자 가운데(타일 선 위의 발), 사용의 바라보기를 호스트가 목표 칸에서, 동작 중 표시는 동작의 칸, 고르기는 예산 밖 + 거부되면 인벤토리로 바로잡기, 클라이언트 F7도 주기처럼, 거부 로그 줄이기, 클라이언트 `--give` 255씩 나누기 + 줄 64개·버린 것 로그, 시험(서서 조준, 인벤토리 다시 얹기, `tick` 순서, `MAX_DROPS`, M1 바라보기를 따로 적은 600틱, 발 칸, 표시, 주기 나누기, 버리기 끔), README 고침, 스크린샷 5장 다시 | **끝** (사람 확인: 두 기기, 새 임시값 표 문구) |

### 검토 반영 (M2-fix, 2026-10-22)

M2b 검토 에이전트들의 지적 17개(겹친 것 포함)와 처리. 하나씩 코드·탐침·재현으로 확인한 뒤 고쳤고, 고친 것마다 깨 보면 실패하는 시험을 붙였다(위 "측정"의 M2-fix 일부러 깨 보기 15개):

- 고침 (중간): 발 칸이 발 점(그림 아래 끝)의 칸이라, 발이 타일 선에서 3px 아래까지일 때 목표 칸·표시·손 닿는 칸이 그려진 발보다 한 줄 아래였다. 스폰 자리 0·1(y = 760 + 8 = 768 = 48×16)이 그 자리라 처음 동·서로 조준하면 대각선 아래 칸이 표시됐다(커밋된 `m2_aim.png`, 두 창 로그 `target=61,48`로 확인). `Aim.feet_cell` = 발 상자 가운데의 칸으로 바꾸고 목표 칸·`in_reach`·사용의 바라보기가 모두 이것을 쓴다(호스트·예측·혼자 같은 함수). 시험: 발 칸 표(타일 선 위·아래), 4분의 1px씩 두 칸 높이 128곳에서 발 칸이 그려진 발 줄의 반 이상을 가짐, `main.tscn` 스폰 자리 0에서 동쪽 조준 = 발 픽셀 오른쪽 칸, 타일 선 위 발의 손 닿는 칸. 임시값 "조준 기준" 줄에 적음
- 고침 (중간, 두 검토): 서 있는 클라이언트가 조준만으로 돌 때 프레임을 기록하는 것과, 호스트의 인벤토리가 올 때 아직 처리 안 된 고르기를 다시 얹는 것에 시험이 없었다(검토가 둘 다 지워 봐도 통과). 단위 시험 둘(`_check_look_turns`: `Prediction` + `InputGate` + `run_frame`, 바라보기만 바뀐 틱만 기록·호스트도 같은 쪽 / `_check_inventory_rebase`: 진짜 `SessionClient.on_inventory`, 프레임에 실린 고르기·줄에 있는 고르기가 남고 ack가 덮으면 호스트 것)과 `pair` 세션의 c1 단계(고르기 3번, 휘두른 뒤 서서 남쪽 조준: 호스트·c1·c2 모두 남쪽)를 더했다. 둘 다 지워 보면 실패한다
- 고침 (중간·낮음, 두 검토): 호스트가 고르기를 `rate`로 거부하면 아무것도 돌려보내지 않아, 클라이언트는 예측한 칸을 들고 호스트·다른 사람은 다른 칸을 보았다(검토가 패킷 하나를 잃은 실제 세션·단위 탐침으로 재현). 고르기는 예산 밖으로(프레임당 하나, 월드를 바꾸지 않음), 그래도 거부된 고르기(`no such slot`)는 주인에게 인벤토리를 보내 바로잡는다. 받아 준 고르기는 아무것도 보내지 않는다(전에는 인벤토리 78B를 보냈다). "사람이 누른 것은 `rate`로 버려지지 않는다"는 "호스트가 제때 받으면"으로 고치고, 몰려 오면 줍기·버리기·주기가 거부될 수 있다고 적었다. 검토가 낸 다른 방법(예산을 호스트 틱 대신 프레임 시간으로)은 서 있는 클라이언트의 프레임 번호가 실제 시간을 따르지 않아 고르지 않았다
- 고침 (낮음, 두 검토): 클라이언트의 `--give` 개수가 1바이트라 300이 44로, 256이 0(`unknown item`으로 거부)이 되었고, 기다리는 요청 줄이 코드 안 16에서 말없이 버렸다. 255씩 나눠 보내고(`Main.give_requests`), 줄은 `Config.NET_LOCAL_OPS_MAX` 64(넘으면 `request_dropped` 줄), 개수 0은 `bad count`. CLI에서 255 넘는 수를 거부하는 방법은 혼자·호스트에서 되는 수를 막게 되어 고르지 않았다
- 고침 (낮음): 호스트가 사용의 목표 칸은 검사했지만 프레임의 look과 맞는지는 보지 않아, 서쪽을 보며 동쪽 칸을 칠 수 있었다. 동작을 시작할 때 look이 목표 칸 쪽이 아니면 칸 쪽을 본다(`Aim.use_facing`, `PlayerSim.step` 안이라 호스트가 정하고 예측도 같다. 정상 클라이언트의 look은 늘 칸 쪽이라 바뀌는 것이 없다. 마우스가 정확히 발 위일 때만 다를 수 있었다)
- 고침 (낮음): 동작 중에도 표시가 마우스를 따라가 치는 칸을 떠났다. 동작 중에는 `action_cell`에 그린다(시험: 휘두르는 도중 마우스를 서쪽으로). **그대로 둠**: 조준하지 않을 때(표시가 숨었을 때) F·F7이 쓰는 칸. 지금도 목표 칸은 매 틱 마우스 커서 쪽으로 갱신되므로(커서는 보인다) "보이지 않는 칸"은 아니지만, 조준하지 않을 때 F가 앞(바라보는 쪽) 칸을 써야 할지, 표시를 늘 보일지는 설계 결정(○ gameplay-design §1 "F 상호작용", §3.4)이라 정하지 않고 알려진 문제에 적었다
- 고침 (낮음): README의 낡은 수(`four` 18조각·세 틱, 늦은 참가 편집 위치 3), M1의 "바라보기는 보내지 않는다"·코드 0..8 문장과 규칙·구현 표 줄에 "M2b에서 바뀜", 스모크 주석의 없는 검사, `test_aim`의 창 크기 비교는 헤드리스에서만(창에서는 OS 커서를 읽음. 진짜 마우스는 사람 확인)
- 고침 (낮음): 내보낸 release 호스트가 클라이언트의 디버그 버리기(F7)를 받아, 버리고 줍기를 되풀이하면 편집 기록이 끝없이 늘었다. 클라이언트 버리기도 주기와 같은 조건(`drop off`). 호스트 자신의 F7과 허용된 빌드의 편집 기록은 여전히 줄지 않는다(알려진 문제)
- 고침 (낮음): 같은 틱 경주 "자리 번호가 작은 쪽"을 `SessionHost.tick`으로 시험하지 않았다(손으로 자리 순서대로 불러서 늘 참). 게이트에 자리 2의 프레임을 먼저 넣고 `tick`을 돌려 자리 1이 갖는지 본다(거꾸로 처리하게 깨면 실패)
- 고침 (낮음): 조준 없이 600틱 M1과 같음 시험이 같은 `PlayerSim.step`끼리 비교했다. M1 규칙을 테스트에 따로 적어 비교하고(대각선 틱 100 넘게), README 문장도 고쳤다
- 일부 고침 (낮음): 거부된 사용은 예산을 쓰지 않고 거부마다 로그 한 줄이라 매 프레임 보내면 초당 60줄. 로그를 플레이어·이유마다 처음 8줄 + 60번째마다로 줄였다(카운터는 모두 셈). 거부된 사용에 예산을 물리지는 않았다: 그러면 정상 세션의 이유(`busy` 등)가 `rate`로 섞이고, 남는 비용은 검사 한 번과 정수 하나다
- 고침 (낮음): 호스트의 `too many drops` 거부에 시험이 없었다. `MAX_DROPS`개를 깐 월드에서 버리기 거부 + 그 월드의 스냅샷 왕복·압축
- 고침 (낮음): 요청 줄 상한 16과 `GATHER_EDGE`가 표시 없는 상수였다(`Config.NET_LOCAL_OPS_MAX` IMPL, `Config.GATHER_EDGE_TILES` PROVISIONAL, 값 그대로라 월드 해시 같음, 표에 적음). 돌을 채집물로 흩는 것은 문서에 없고 04-env 묶음 이름에서 온 에이전트 선택이라고 표와 `config.gd`에 바로 적었다

### 검토 반영 (H-fix, 2026-10-22)

H1 검토 에이전트들의 지적 14개와 처리. 하나씩 직접 재현하거나 코드로 확인한 뒤 고쳤다:

- 고침 (높음·중간, 두 검토가 같은 것을 지적): 호스트 멈춤 따라잡기가 실제 세션에서 듣지 않았다. 재현: 2프로세스, 호스트 0.7초 멈춤(물리 틱 밖) → 속도 제한 204틱, 대기열 최고 42. 원인과 고침은 위 "호스트가 멈췄다 돌아올 때"(멈춤 크레딧 + 틱당 4프레임). 단위 시험을 두 순서로 바꿨고(틱 밖 순서는 H1 코드에서 실패: 대기열 31, 제한 409), 실제 세션 시험 `stall`과 테스트 전용 봇 `stall:<ms>`를 더했다. 검토가 낸 다른 방법(호스트가 틱 처음에 직접 네트워크를 읽기)은 RPC 처리가 물리 틱 안으로 들어오고 보내는 시점도 바뀌어서 고르지 않았다
- 고침 (중간): 실제 시간 시계 계산을 시험하는 곳이 없었다. `InputGate.ticks_between`으로 빼서 가짜 시각으로 단위 시험(60Hz 프레임 = 1틱, 같은 시각 = 0, 거꾸로 = 0, 그 시계로 두 배 보내는 클라이언트도 실제 시간 + 30)하고, 모든 세션에서 게이트마다 채운 시간이 호스트 틱 수를 따라가는지 본다(1000배로 깨면 세션도 실패)
- 고침 (중간): 테스트 포트 확인이 `*` 하나라 IPv4만 잡은 프로그램을 못 봤다. 재현: 0.0.0.0·127.0.0.1을 잡은 소켓을 `*` 확인이 통과. 세 주소로 확인하고 `test_core`가 IPv4만 잡은 소켓 두 가지로 시험
- 고침 (낮음): `--port-base` 묶음을 못 잡으면 `FAIL (startup)`을 찍고도 쥐지 않은 기본 묶음으로 모든 파일을 돌렸다. 이제 아무 파일도 돌리지 않고 끝난다(`test_core`가 자식 러너로 시험)
- 고침 (낮음): 스냅샷 크기 상한 2048은 받을 수 없는 크기였다. 512로(위 "늦은 참가"), 접속 제한에 걸린 이유를 "월드를 다 받지 못함"과 구분, 알려진 문제에 적음
- 고침 (낮음): 여러 걸음을 적용한 틱을 두 끝 사이 직선으로 그려 제단 안을 지날 수 있었다. 두 걸음 넘는 틱은 끝에 그린다(시험: 직선은 제단을 지나고 그림은 늘 끝)
- 고침 (낮음): README 측정값이 다시 재면 안 나왔다. 여러 번 잰 범위와 기기 흔들림을 적고, pair 0/2가 두 값으로 갈리는 원인(늦은 참가자의 연결 인사, 잼)과 1초·1.7초를 넘는 멈춤의 한계(모형으로 잼)를 적음
- 고침 (낮음): 호스트가 틱당 8조각을 지키는지 세션 시험이 없었다. 호스트가 스트림마다 조각 보낸 틱 수를 결과에 남기고 모든 세션에서 ⌈조각/8⌉인지, `four`의 c4는 2틱인지 본다(M2b부터 18조각·3틱)
- 고침 (낮음): 받는 도중 편집 길을 지나는 시험이 없었다. `stall` 세션 뒤쪽(1바이트 조각, 4틱마다 편집 60번, welcome 뒤 편집 10~11개)
- 고침 (낮음): 늘 참인 검사 셋. "packed world md5 = content hash"는 뺌, "chunk count"는 기본 조각 크기로 돌아왔는지로 바꿈, 무작위 바이트 시험은 크기·md5가 맞는 조각으로 넣어 실제로 풀기 단계까지 가게(2,000번 중 1,500번 넘게 거기서 거부되는지 셈)
- 고침 (낮음): check_render.gd 352줄의 탭 다섯 개를 줄 잇기로
- 일부 고침 (낮음, 선택): 클라이언트의 생성기 해시는 welcome에서만 정함(전에는 거부된 클라이언트가 자기 시드 월드 해시를 적음), 진단 시드는 스냅샷 머리말에서 가져오고 welcome의 시드 칸(8B)을 뺌(같은 v2 안: 아직 main에 머지 안 된 형식). 참가 클라이언트가 시작할 때 자기 시드로 월드를 만드는 것은 그대로 둠(이유는 알려진 문제)
- 검토 밖에서 찾아 고침: `stall` 세션이 가끔 실패(걷는 클라이언트가 4초 동안 상태 묶음 5개). ENet 패킷 조절이 원인이라 계측으로 확인하고 껐다(위 "네트워크")
- 늦은 참가자의 연결 인사를 "joining" 묶음으로 옮기지는 않았다(호스트가 peer를 알기 전의 바이트라 통계를 몇 틱 늦게 나눠야 한다). 원인을 재서 설명만 적었다(검토가 낸 두 방법 중 하나)

### 검증 반영 (2026-10-22)

검증 에이전트의 지적과 처리:

- 고침 (중간): 러너가 마지막 파일 뒤에 난 오류를 세지 않아 PASS·종료 0으로 끝날 수 있었다. 이제 마지막 파일 뒤 10프레임을 기다려 `FAIL (after the last file)`로 센다. 파일이 루트에 남긴 노드는 그 파일의 실패로 세고 러너가 지운다(늦은 오류가 다음 파일 탓이 되던 주된 길). 파일 사이 오류에는 앞 파일 이름을 붙인다. 정리 뒤 기다림은 1프레임 → 3프레임(1 + `SETTLE_FRAMES` 2)
- 고침 (낮음): 통과하는 실행의 알린 오류 묶음 7개를 위 "전체 테스트"에 모두 적음. 스폰 방향을 `Config.SPAWN_FACING`(임시값)으로 빼고 `SPAWN_SLOTS`에 "자리는 IMPL, 제단 둘레 스폰은 임시값"을 적음. 임시값 표 머리말을 "대부분 config.gd, 아닌 줄은 코드 칸"으로 고침. 오염 구역 수의 ●를 ○로(문서 §12는 "제안" 절의 표시 없는 줄). 카메라 가장자리 멈춤을 임시값 표에 올림(● gameplay-design §1과 가장자리에서 다름). 시드 1 월드 해시를 `SurfaceGen.GOLDEN_HASH`로 옮겨 스모크도 비교하게 하고, "모든 기기에서 같다"를 "x86_64에서만 확인"으로 고침
- 그대로 둠: 해시 고정값이 옳음을 증명하지 않는다는 지적은 맞지만 고정값의 일은 변화 감지다(옳음은 40시드 규칙 검사). 설명만 고쳤다

알려진 문제·남은 일:

- (M3a) 바위 윗면의 금(`wall_crack_top_v01`) 1·2단계는 어두운 바위 위의 어두운 선이라 1배·어둠 속에서 거의 안 보인다(앞면의 금은 보인다, `m3_miner_mining.png`). 그림을 밝게 할지, 금을 다르게 보일지는 사람이 본다
- (M3a) 절벽 셋에 없는 코너 조합(앞면 바로 아래 벽 윗면, 한 줄 차이로 끝나는 이웃 벽)은 가까운 타일로 그려서 앞면이 짧게 끊기거나 이웃 칸과 한 줄 어긋난다. 생성된 던전에는 드물고(40시드에 19칸) 마구 판 뒤에는 많다. 그 조합의 타일을 더 그릴지는 그림 쪽 일이다
- (M3a) 앞면 칸이 막혀서 가로 굴은 두 줄이어야 들어간다(공용 클래스는 앞으로 한 칸 갈 때마다 두 칸을 판다). 앞면이 24px(1.5칸)인 그림에서 나온 것이라, 앞면 칸을 걷게 하면 캐릭터가 앞면 위에 떠 보인다. 사람이 해 보고 정한다(임시값 "앞면 칸이 막힘")
- (M3a) F5 묶음이 24칸을 다 채워서 F5 뒤에 캔 광석은 드롭으로 떨어진다(위 "실행"). 묶음을 줄일지는 사람이 정한다
- (M3a) 횃불을 다시 줍지 못하고, 하나하나가 `PointLight2D`라 바닥 사분면(128px) 하나에 빛이 15개 넘게 닿으면 넘는 빛은 그 사분면을 비추지 않는다(스파이크 RESULTS §4). 횃불 빛의 단계 모양(딱딱한 네 겹 원)은 임시다
- (M3a) 출구 계단은 임시 그림(아치 + 뒤집은 내려가는 계단)이다. 벽 횃불 불꽃은 늘 켜져 있고(이단의 불이 아니라 공유 불꽃), 이단의 제단은 불이 꺼진 그림이다
- (M3a, M3b에서 풂) 세션은 던전이 없었다(입구 거부). M3b에서 세션도 오가고 캔다. 클라이언트가 횃불을 놓으면 여전히 왕복 시간 뒤에 보인다(예측 안 함)
- (M3b) 오가기는 예측하지 않는다: F 뒤에도 지도 들어옴이 올 때까지(왕복 + 지도 조각) 옛 지도에서 걷다가 새 지도 도착점(+ 그동안 걸은 만큼)으로 바뀐다. 던전을 받아 그리는 데(`load_data`, 동굴 그림) 이 데스크탑에서 약 60~70ms라 들어가는 순간 한 프레임이 길다(로그 `build_ms=62.3`). 두 기기에서 어떻게 느껴지는지는 사람이 본다
- (M3b) 상태 묶음은 모든 플레이어를 모두에게 보낸다: 지상에 있는 사람도 던전 사람의 상태를 받는다(호스트가 던전에서 캐는 동안 지상 c1 수신 약 1.07KB/s, 상태뿐. 편집은 안 받는다). 9인이 지도 둘에 흩어지면 지도별 묶음이 더 싸다. 지금은 단순함을 골랐다
- (M3b) 지도에 들어갈 때마다 지도 전체를 다시 받는다(던전 309~345B, 지상 566~582B, 각 조각 1개). 떠난 지도를 들고 있다가 차이만 받는 방법은 없다(슬라이스 크기에서는 필요 없다고 봄)
- (M3b) 편집 기록은 지도마다 줄지 않는다. 채굴이 편집을 많이 만든다(광부 휘두르기 한 번에 칸 편집 6~9개). 호스트 메모리에만 쌓이고, 늦은 참가·지도 들어옴은 스냅샷 + 그 뒤 편집만 받는다. 기록 압축은 아직 없다(M2-fix 줄과 같은 문제)
- (M3b) 호스트를 잃은 클라이언트가 던전에 있으면 혼자 던전에서 계속한다. 계단으로 올라가면 지상은 그 클라이언트가 지상을 떠날 때의 사본이다(그 뒤의 변화 없음)
- (M3b) 같은 칸을 같은 틱에 둘이 치는 경주는 단위 시험(`SessionHost.tick`)으로만 정확히 맞췄다. 실제 세션(`four`)에서는 두 사람이 몇 틱 차이로 맞고, 한 번만 깨지고 돌은 깬 쪽에 가는 것을 본다. 깬 뒤에도 누르고 있으면 그 칸이 이제 위 벽의 앞면이라 위 벽을 계속 판다(앞면 규칙, M3a)
- (M3b) 다른 지도에 있는 사람이 어디 있는지 화면에 아무 표시가 없다(임시값 "다른 지도의 플레이어")
- (M3a) 던전 지도는 다른 지도로 가도 그대로 남는다(판 자리·놓은 횃불·드롭). 저장은 없어서 프로그램을 끄면 사라진다
- (M2a) 몸 동작의 기준점 중 몇 개가 크게 튄다. 규칙(● R27)대로 잰 값이고 고치지 않았다: 마법 북쪽 머리 (0, 6)(프레임 2·6, 몸 전체가 금빛으로 밝아지는 프레임이라 색이 맞는 픽셀이 적다), 던지기 남쪽 머리 (5, 6)·북쪽 머리 (−6, 4)(5번째 프레임, 크게 젖히는 자세), 마법 북쪽 몸통 (2, −4). 성직자의 후광과 등·허리 표식이 그 프레임에서 몇 px 어긋나 보일 수 있다. 창 그림 검사 `--save`로 남긴 `rig_<동작>_<프레임>_got.png`로 사람이 보고 idle처럼 손으로 고정할지 정한다
- (M2a) 몸 동작은 64칸이라 도구가 몸보다 멀리 나간다(시트에서 잰 값: 발에서 좌우 최대 13px, 몸은 9px. 발 줄 아래로 7px). 제단 옆 띠(몸 기준)는 그대로라 제단 옆면에 붙어 동작하면 도구가 제단 그림 뒤로 들어갈 수 있다. 목표 칸이 제단이면 동작은 그대로 한다(월드 효과가 없으니)
- (M2a, M2b에서 풂) 조준·동작은 혼자 할 때만이었다. M2b에서 입력 프레임에 바라보기와 요청을 넣어 호스트가 정한다(위 "M2b")
- (M2a) 목표 칸 표시는 캐릭터 아래에 그려서 발 북쪽 줄 칸(북·북동·북서)은 몸에 가린다. 마우스가 1초 동안 안 움직이면 표시가 사라진다(조준 끝)
- (M2a) 마법과 던지기는 그것을 부르는 아이템이 없어 F6·`--test-action`으로만 본다. 도구 아이콘은 코드로 그린 임시다
- (M2a) `--test-*` 플래그와 F5·F6 디버그 키는 내보낸 빌드에도 들어 있다

- (M2b) 든 아이템은 그림이 없다. 슬라이스는 도구를 몸 동작에 그려 넣고(● R25) 서 있을 때 손에 든 도구 레이어는 2단계(○ brief §5.6)라, 다른 사람의 도구는 동작할 때만 보인다. 든 아이템은 상태 묶음과 결과 JSON에만 있다
- (M2b) 줍기·버리기·주기는 예측하지 않는다. 클라이언트에서 F를 누르면 왕복 시간 뒤에 채집물이 사라지고 인벤토리에 들어온다(localhost에서는 한두 프레임). 두 기기에서 늦게 느껴지는지는 사람이 본다
- (M2b) 채집물은 시드 1에서 제단에서 가장 가까운 것이 약 13타일이다(빛 밖 + 1타일, 74개를 맵 전체에). 수·자리는 임시값이라 사람이 보고 정한다. 다시 자라지 않아서 다 주우면 끝이다
- (M2b) 드롭은 디버그 F7로만 생긴다(사망 드롭·채굴 드롭은 M2 밖). 칸 하나에 여러 드롭이 겹쳐 그려지고 개수 표시가 없다
- (M2b) 호스트가 거부한 사용은 클라이언트가 이미 그 동작을 시작해 보였다가 다음 상태(최대 왕복 + 50ms 뒤)에 되돌린다. 정상 세션에서는 일어나지 않는다(도구·칸 검사가 양쪽에서 같다)
- (M2b) 세션 시험이 약 37 → 51초로 늘었다(pair·four에 걷기·줍기·경주를 더함). 전체 테스트 약 73초
- (M2b) `--test-allow-give`, 봇 명령들은 내보낸 빌드에도 들어 있다
- (M2-fix 검토, 정하지 않음) 조준하지 않을 때(마우스가 1초 넘게 가만히 있어 표시가 숨었을 때)도 F·F7은 목표 칸, 곧 발 칸에서 마우스 커서 쪽 이웃 칸에 작용한다. 커서는 보이지만 표시는 없다. 그때 F가 바라보는 쪽 칸을 써야 할지, 표시를 늘 보일지는 설계 결정이라 사람이 정한다(○ gameplay-design §1 "F 상호작용", §3.4 "F로 식물·드롭 줍기")
- (M2-fix 검토) 편집 기록(`EditLog`)은 줄지 않는다. `MAX_DROPS`는 땅의 드롭 수를 묶지만 기록은 묶지 않아서, 버리고 줍기를 되풀이하면 호스트 메모리의 기록이 편집마다 늘어난다(늦은 참가자는 스냅샷 + 그 뒤 편집만 받는다). 이제 내보낸 release 호스트는 클라이언트의 F7을 거부하므로(`drop off`) 남는 것은 호스트 자신의 F7과, 디버그 빌드·`--test-allow-give` 호스트에서의 클라이언트 F7이다. 게임 편집(채굴·농사)이 생기면 기록 압축을 같이 정한다
- (M2-fix 검토) 클라이언트 키 요청은 호스트의 예산에 맞춰 보내지만, 패킷을 잃어 다음 패킷에 몰려 오거나 호스트가 멈췄다 따라잡으면 한 틱에 4개 넘는 줍기·버리기·주기가 `rate`로 거부될 수 있다(검토 탐침: 몰려 온 5개 중 1개, 8개 중 4개). 예측하지 않는 요청이라 아무 일도 일어나지 않고 호스트 로그에 남는다. 고르기는 예산 밖이라 해당 없다
- (M2-fix 검토) `test_aim.gd`의 `main.tscn` 마우스 검사(창 크기 6가지)는 헤드리스에서만 맞다. 창을 띄우면 루트 뷰포트가 주입한 이벤트 대신 OS 커서를 읽는다. 진짜 마우스로 조준해 보는 것은 사람이 한다
- 러너는 파일이 남긴 타이머·스레드·시그널 콜백이 늦게 내는 오류를 여전히 엉뚱한 파일 탓으로 세거나(그때 돌던 파일), 마지막 파일 뒤 10프레임보다 늦으면 놓친다. 루트에 남긴 노드만 따로 잡는다
- 다른 아키텍처의 월드 생성: FastNoiseLite가 float 계산이라 ARM64가 다른 월드를 만들 수 있다. H1부터 늦은 참가는 호스트의 월드를 받으므로 그래도 참가는 된다(흔든 생성기로 시험함). 남는 것: 서피스가 **호스트**가 되면 같은 시드라도 데스크탑과 다른 월드가 된다(시드 공유). 서피스 생성기가 같은지는 서피스에서 `evensong.console.exe --headless -- --smoke`(해시가 다르면 `seed 1 world hash` FAIL)나 참가 로그의 `generator=` 진단으로 안다. 다르면 노이즈를 정수 계산으로 바꿀지는 사람이 정할 일
- 스냅샷은 참가를 받는 순간 월드 전체를 한 번에 압축해 참가자마다 들고 있다가 보낸다(128×96은 342B, 512×512 합성 54KB). 큰 맵에서 근처 청크부터 보내기, 받는 동안 미리 걷기는 없다. 틱당 8KB라 압축이 안 되는 1.3MB는 2.8초 걸린다
- 스냅샷 크기 한계 (H-fix): 받는 쪽은 한 변 512칸(`MAX_SIDE`), 압축 1.6MB(`MAX_PACKED`)까지만 받는다. 접속 제한 10초(`NET_CONNECT_TIMEOUT_SEC`)가 월드를 다 받을 때까지라, 틱당 8KB로 약 4.8MB를 넘는 스냅샷은 그 안에 다 올 수 없다(지금 상한은 3.3초 거리). 맵을 512보다 키우면 두 값과 "근처 청크부터"를 같이 정해야 한다. 512×512를 그리는 데(`load_data`) 이 데스크탑에서 0.4~0.8초, 그동안 클라이언트 화면이 멈춘다
- 참가자가 월드를 받는 도중에 호스트가 편집하면 그 편집은 welcome 뒤에 번호대로 따로 간다. H-fix부터 실제 세션(`stall`)에서 지난다: 1바이트 조각 341~345개를 받는 동안 4틱마다 편집해서 welcome 뒤에 간 편집 10~11개, 참가자 월드 = 호스트 월드. M2b: 조각 약 567개(71틱), 그동안의 드롭까지 welcome 뒤 편집 약 20개 이 편집을 보내지 않게 깨 보면 실패한다
- 호스트가 1초(64틱)보다 오래 멈추면 걷던 클라이언트의 프레임 일부가 버려지고, 더 길면 한 번 크게 보정된다 (위 "호스트가 멈췄다 돌아올 때"의 한계)
- 참가하는 클라이언트도 시작할 때 자기 `--seed`(기본 1)로 월드를 한 번 만들어 그린다(`Main._ready`, `GameWorld`). welcome 전에 카메라 경계·바닥·제단이 있어야 해서 그대로 두었다. 이 월드는 welcome에서 받은 월드로 바뀌고 어디에도 쓰지 않는다(H-fix: 이 월드의 해시를 생성기 해시로 적던 것은 뺐다. 클라이언트의 `generator_hash`는 welcome의 진단에서만 정해진다). 그래서 `--test-perturb-generator` 참가자는 welcome 전 잠깐 다른 월드를 보인다
- 제단 옆 띠는 몸(기본 몸, 모든 클래스 같음) 기준이다. 등·팔의 장비(곡괭이·활·방패)는 제단 가장자리 뒤로 서쪽 6px·동쪽 7px까지 들어갈 수 있다(제단을 등지거나 옆으로 볼 때). 장비까지 넣으면 몸과 제단 사이가 7px까지 벌어져 보여서 몸 기준으로 했다. 띠는 제단 자리 위 변까지라 북쪽 면 모서리에서는 띠 폭만큼 면이 넓어진 셈이다(그 높이에서 제단 그림은 5px 아래에서 시작해 겹치지 않는다)
- 틱 사이에 그리기는 그림을 최대 한 틱(16.7ms) 늦게 보여 준다. 고른 걸음을 실제 144Hz 모니터에서 눈으로 본 사람은 아직 없다(시험은 144Hz 프레임 흉내). 이 데스크탑의 화면 주사율은 확인하지 않았다
- `--test-perturb-generator`, `--test-snapshot-chunk-bytes`, 봇 `stall:`은 테스트 전용인데 내보낸 빌드에도 들어 있다(사람이 쓸 일은 없다)
- 테스트 포트: 러너끼리는 잠금으로 겹치지 않지만, 러너가 아닌 프로그램이 확인 뒤에 묶음 안 포트를 잡는 것은 막지 못한다 (위 "테스트 포트"). 확인 전부터 잡고 있는 프로그램은 IPv4만 잡았어도 이제 찾는다(H-fix)
- 임시값 표의 모든 줄(특히 카메라 가장자리, 스폰, 같은 클래스 둘, 오염 구역 수, M2a의 키·조준·동작 줄, M3a·M3b 줄)은 사람이 확인해야 한다. M3b도 있던 임시값은 바꾸지 않았다: "M3a 세션" 줄을 끝났다고 적고 줄 셋(지도 오가기, 다른 지도의 플레이어, 다시 참가할 때의 지도)을 더했다. M3a도 있던 임시값은 바꾸지 않고 줄만 더했다(F5 디버그 묶음은 구현 값이라 횃불을 넣었다). H1과 H-fix는 임시값을 하나도 바꾸지 않았다(새 값은 모두 "구현에서 고른 값"). M2a도 있던 임시값은 바꾸지 않고 줄만 더했다. M2-fix도 값은 바꾸지 않았다: "조준 기준" 줄의 발 칸을 그려진 발에 맞게 고쳤고(검토 지적, 사람이 볼 것), "채집물 자리"에 `GATHER_EDGE_TILES`(값 2 그대로)를 옮겨 적고, "디버그 주기"를 "주기·버리기"로 넓히고, "채집물 수"에 돌의 출처를 바로 적었다

M3b에서 확인하지 않은 것: **두 기기**(서피스 ARM64)로 오가기·같이 캐기·늦은 참가(아래 "두 기기에서 M3 해 보기", 사람이 한다. ARM64 exe는 이번에도 내보내기만 했다. 서피스의 `--smoke`가 `dungeon_seeds=3ec443b95c4c`이면 던전 생성기도 같다), 실제 지연에서 지도 들어옴까지 걸리는 시간과 그동안 옛 지도에서 걷는 느낌(localhost에서만), 사람이 마우스·키보드로 두 창에서 캐 보기(시험은 봇), 9인이 지도 둘에 흩어졌을 때 트래픽(9인 시험은 지상에서 걷기만), 같은 틱 채굴 경주를 실제 세션에서(단위 시험만).

M3a에서 확인하지 않은 것: 사람이 키보드·마우스로 던전을 걷고 캐 보기(시험은 봇과 함수로), 금·광석·어둠·횃불 빛이 1배 화면에서 읽히는지(스크린샷 3장은 에이전트가 2~5배로 확대해 봤다), 실제 창에서 던전의 프레임 시간(빛 수십 개), 다른 아키텍처(ARM64)에서 던전 해시가 같은지(정수 계산뿐이라 같을 것으로 봄, 서피스에서 `--smoke`의 `seed 1 dungeon hash`로 알 수 있다), 내보낸 exe의 창 스크린샷(헤드리스 스모크와 120프레임만).

M2b에서 확인하지 않은 것: **두 기기**(서피스 ARM64)로 휘두르기·줍기·경주·늦은 참가(위 "두 기기에서 M2b 해 보기", 사람이 한다. 이번에도 ARM64 exe는 내보내기만 했다), 사람이 마우스·키보드로 두 창에서 해 보기(테스트는 봇으로만), 실제 지연에서 동작 예측이 보정 없이 맞는지(가짜 연결 단위 시험과 localhost 세션만, 세션의 `lag`은 걷기만), 9인이 동시에 동작할 때 트래픽(9인 시험은 걷기만), 동작 중 스크린 그림의 매 프레임(세션 그림은 두 장, 프레임 그림은 M2a 창 검사).

G1에서 확인하지 않은 것: ARM64 exe 실행(이 기기는 x86_64), 실제 창의 프레임 시간, 내보낸 exe의 창 스크린샷(G2에서 확인함), 에디터(`-e`)로 열어 보기(사람이 한다).

G3에서 확인하지 않은 것: **두 기기**(데스크탑 + 서피스, Tailscale)로 새 네트워크 코드를 돌려 보기(사람이 한다. 위 "둘이 하기"), ARM64 exe 실행(이 기기는 x86_64, 내보내기만 함), 실제 인터넷·Steam 릴레이(Steam은 M1 밖), 진짜 지연·손실(자동 시험은 localhost + 클라이언트 쪽 흉내뿐, 호스트 쪽 지연은 흉내 내지 않았다), 사람이 키보드로 두 창에서 걸어 보기(테스트는 봇으로만), 호스트를 처음 열 때 Windows 방화벽 창(이 세션에서는 아무 창도 확인하지 못했다), 다른 아키텍처끼리 월드 해시가 같은지(H1부터 참가에는 상관없다. 서피스에서 `--smoke`나 `generator=` 진단으로 볼 수 있다), 창 모드의 실제 프레임 시간.

H1에서 확인하지 않은 것: 두 기기(서피스 ARM64)로 스냅샷 참가 해 보기(사람이 한다. 이번에도 ARM64 exe는 내보내기만 했다), 60Hz보다 빠른 실제 모니터에서 틱 사이 그리기를 눈으로 보기, 진짜 큰 맵 세션(512×512는 단위 시험의 한 프로세스 전송과 그리기만. 세션은 M1 맵뿐). 받는 도중의 편집과 호스트가 실제로 멈추는 세션은 H-fix의 `stall` 세션이 확인한다(멈춤은 `OS.delay_msec`로 낸 것이고, 실제 무거운 프레임·다른 기기에서는 아니다).

H-fix에서 확인하지 않은 것: 두 기기(서피스 ARM64, Tailscale)에서 ENet 패킷 조절을 끈 연결(localhost에서만 잼. 실제 망에서 상태 묶음이 끊기지 않는지, 혼잡할 때 늦어지지 않는지는 사람이 두 기기로 볼 것), 서피스의 `--smoke`(이번에도 ARM64 exe는 내보내기만 했다), 물리 틱 밖 멈춤이 진짜 무거운 프레임(그리기·RPC)에서 나는 경우(시험은 `_process`의 `OS.delay_msec`), 따라잡기 4배 속도를 사람이 화면으로 보기.

G2에서 확인하지 않은 것: 사람이 키보드로 직접 걸어 보기(테스트는 입력 액션을 눌러 물리 틱으로 확인했다), 실제 창의 프레임 시간, ARM64 exe 실행, 에디터로 열어 보기, idle 기준점을 사람이 보고 고정하기, 화면 캡처는 창 안 렌더 타깃이고 모니터에 나간 그림(스왑체인)은 아니다(스파이크에서 사람이 따로 확인한 방식).
