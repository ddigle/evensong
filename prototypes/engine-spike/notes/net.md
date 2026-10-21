# net: 호스트 권한 온라인 협동 (Godot 고수준 멀티플레이 + ENet)

시험일 2026-10-18, Godot 4.7.2 stable (official, ed1daf0bf), Windows 11 데스크탑(Ryzen 9 9950X3D, RTX 5090), SSH 세션에서 Git Bash로 실행.
모든 수치는 **한 기기 안 localhost**(지연·손실 없음)에서 잰 것이다. 실제 인터넷이나 Steam 릴레이는 시험하지 않았다.

## 시험한 것

요구사항: "호스트 권한 온라인 협동 최대 9인 + 타일 변경분(델타) 동기화, Steam 릴레이는 나중" (game-concept §13, gameplay-design §3.1·§5).

구조 (전부 Godot 4 내장 기능, 애드온 없음):

- **호스트가 타일 상태의 주인**이다. 클라이언트는 "이 칸 벽을 부숴 달라"를 RPC(`any_peer` → 호스트만)로 **요청만** 한다. 호스트가 검사(맵 안인가, 손이 닿는가 56px, 벽이 있는가, 부술 수 있는 벽인가)하고 적용한 뒤, 그 틱에 바뀐 칸들을 **델타 묶음 하나**로 모두에게 보낸다 (`authority` RPC, 순번 포함)
- 델타는 "칸을 이 값으로" 절대값 6바이트(레이어 u8, x u16, y u16, 값 u8). 두 번 적용해도 같아서, 늦게 들어온 사람이 스냅샷에 이미 든 델타를 또 받아도 문제없다
- **늦게 들어온 사람**: 호스트가 접속 순간 맵 전체를 32×32 칸 청크로 잘라 zstd 압축해 보내고(스냅샷), 그다음부터 델타를 받는다. 스냅샷과 델타는 같은 reliable 채널 1을 써서 순서가 보장된다
- **플레이어**: `MultiplayerSpawner`(spawn_function)로 생성. 위치는 `MultiplayerSynchronizer`(권한 = 호스트)로 복제. 입력은 플레이어 아래 별도 `MultiplayerSynchronizer`(권한 = 그 플레이어의 클라이언트, 호스트에게만 보임)로 호스트에 보내고, **이동 시뮬레이션은 호스트만** 한다(벽 충돌 포함)
- **전송 계층 교체**: 게임 코드는 SceneMultiplayer(RPC·Spawner·Synchronizer)만 쓰고, 그 밑의 `MultiplayerPeer`를 만드는 일만 작은 인터페이스(`net_transport.gd`)로 뺐다. `enet_transport.gd`(지금), `steam_transport.gd`(GodotSteam `SteamMultiplayerPeer`, 설치 안 함), `transports.gd`(이름으로 고르는 팩토리). 전송을 고르는 건 `--net-transport=steam` 한 줄이지만, Steam에서 9인 상한·relay 설정·로비 비동기 흐름은 아직 없다 (RESULTS §6 "검증에서 찾은 빈틈")
- 타일 데이터는 레이어 3장(바닥 / 벽(파괴) / 광맥)을 `PackedByteArray` 하나에 담은 순수 데이터(`tile_world.gd`), 화면은 레이어마다 `TileMapLayer` 하나(`tile_view.gd`, 색 타일셋을 실행 중에 만듦. 그림 에셋 없음)

자동 테스트 `tests/test_net.gd` (168 checks, 약 14초):

1. 프로세스 안 단위 확인: 같은 시드 = 같은 맵, 호스트 검사(수락·거부 4종), 델타(크기, 멱등, 깨진 버퍼 무시), 청크 스냅샷 왕복(청크 배수가 아닌 100×70 포함), TileMapLayer 뷰 = 데이터, 봇 스크립트 파서, 전송 팩토리(Steam은 GodotSteam이 없으면 `ERR_UNAVAILABLE`)
2. **실제 세션**: `OS.create_process`로 이 프로젝트를 헤드리스 인스턴스 4개(호스트 1 + 클라이언트 3, `--max-fps 60`)로 띄운다. 각자 `--script-actions=`로 정해진 행동을 한다:
   위로 3칸 걷기 → 돌벽 2개 부수기(수락) → 기반암·빈 칸·먼 칸 부수기(거부 3종) → 모두 모이기(늦은 참가자 c3는 이때 접속) → 3초 함께 순찰 → 1초 정지 → 호스트가 **한 틱에 타일 200개 편집** → 아래로 걸어가 벽 2개 더 부수기 → 처음 칸으로 복귀.
   c1은 호스트인 척 가짜 델타(기반암)를 한 번 보낸다(모두가 거부해야 함)
3. 끝나면 모든 인스턴스가 `user://net_test/run_*/<이름>.json`에 **타일 해시(SHA-256)와 플레이어 위치 해시**를 쓴다. 통과 조건: 전부 호스트와 같음, 모두가 모든 플레이어를 봄, TileMapLayer 뷰 = 데이터, 델타 순번 빠짐 없음, 수락 4×인원 / 거부 3×인원, 버스트가 한 묶음(1,200 B)으로 나감, 늦은 참가자의 스냅샷에 이미 편집이 들어 있음, 종료 코드 전부 0. 프로세스는 끝까지 기다렸다가 남으면 죽인다(통과하면 run 폴더도 지움, 실패하면 로그 보존)

```bash
GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"; SPIKE=prototypes/engine-spike
timeout 300 "$GODOT" --headless --path $SPIKE --script res://tests/run_all.gd -- --only=net < /dev/null
# 변형: --net-clients=8 (9인)  --net-sync=on_change  --net-sync-hz=20  --net-compress=range|zstd  --net-map=1024  --net-relay=off
# 수동 플레이(창 2개): "$GODOT" --path $SPIKE res://net/net.tscn   그리고   "$GODOT" --path $SPIKE res://net/net.tscn -- --net-role=client --net-timeout=0
#   (--net-role를 주면 자동 시험 모드라 기본 90초 뒤 끝난다. 사람이 할 때는 --net-timeout=0)
# 두 기기: 다른 PC에서 내보낸 exe로 evensong_spike.exe -- --scene=net --net-role=client --net-timeout=0 --net-address=<호스트 IP>
#   (Tailscale이면 호스트의 100.x 주소. 서피스 스냅드래곤은 "Windows ARM64" 프리셋으로 내보낸 exe)
```

포트는 24601~24620만 쓴다(테스트는 24601~24619 중 빈 것을 찾고, 수동 기본값은 24620).

## 수치

바이트는 ENet 통계(ENet 헤더 포함, UDP/IP 헤더 제외)다. 괄호 안 "선로"는 패킷당 UDP/IPv4 28 B를 더한 추정치. "호스트 송신"은 호스트가 모든 클라이언트에게 보낸 합이다.

### 대역폭: 위치 동기화 (호스트 송신, 기본 = `always` 30Hz, 압축 없음)

| 조건 | 4인 모두 이동 | 4인 정지 | 9인 모두 이동 | 9인 정지 |
|---|---|---|---|---|
| always 30Hz (기본) | 6.2~6.9 KB/s, 95~103 pkt/s (선로 ~8.9~9.8 KB/s) | 6.2~6.9 KB/s | 36.4~37.5 KB/s, 272 pkt/s (선로 ~45 KB/s ≈ 0.36 Mbps) | 34~36.5 KB/s |
| always 20Hz | 4.7~4.9 KB/s (~7.1) | 4.6~4.7 KB/s | 25.6~26.7 KB/s (~31) | 25.7~25.9 KB/s |
| on_change 30Hz (reliable) | 8.8~9.0 KB/s (~11.7) | 0.13~0.3 KB/s | 49.6~51.4 KB/s (~60.7) | 0.2~1.4 KB/s |
| always 30Hz + ENet range coder | 4.5 KB/s (~7.3) | 4.0~4.1 KB/s | 20.4 KB/s (~27.9) | 20.2 KB/s |
| always 30Hz + ENet zstd | 5.6 KB/s | 5.1 KB/s | 22.8 KB/s | 23.1 KB/s |

- 클라이언트 하나: 송신 약 0.23~0.36 KB/s(입력, on_change면 0.5~0.7), 수신은 세션 평균 약 4~4.4 KB/s(4인) / 5.9~7.7 KB/s(9인, 스냅샷 포함)
- `always`는 **서 있어도 같은 양**을 보낸다(unreliable, 매 주기). `on_change`는 정지 때 거의 0이지만 이동 중엔 reliable 확인 응답 때문에 오히려 30~40% 더 든다
- 9인 30Hz는 인원 제곱에 비례(9명 위치 × 8클라이언트 × 30Hz ≈ 2,160 갱신/s, 갱신당 약 17 B). 그래도 호스트 업로드 0.36 Mbps라 가정용 회선에 문제없는 크기다
- `--net-relay=off`(클라이언트끼리 호스트를 거쳐 통신하지 않음, GodotSteam 기본값과 같음)로도 4인·9인 모두 통과, 대역폭 같음. 이 설계는 클라이언트 간 통신이 필요 없다

### 대역폭: 타일 200개 한 틱 편집 (버스트)

| 조건 | 페이로드 | 1초 창에서 평소보다 더 나간 양 (호스트 송신) |
|---|---|---|
| 4인 (클라이언트 3), 압축 없음 | 클라이언트당 1,200 B, 묶음 1개 | 약 3.3~4.1 KB (선로 ~4.1~4.3 KB) = 클라이언트당 ~1.1~1.4 KB |
| 4인, range coder | 같음 | 약 1.4~1.5 KB (선로 ~1.6 KB) |
| 4인, on_change | 같음 | 약 3.4~3.6 KB |
| 9인 (클라이언트 8), 압축 없음 | 같음 | 약 10.6~12.9 KB (선로 ~13.6 KB) |
| 9인, range coder | 같음 | 약 2.7 KB |

타일 편집은 사람 손으로는 초당 몇 개라 평소엔 무시할 만하고, 폭발·광부 3×3 채굴 같은 몰아치기도 200칸에 클라이언트당 1.2 KB다.

### 스냅샷 (늦은 참가)

| 맵 | 원본 | zstd 청크 합 | 호스트 만들기 | 클라이언트 압축 풀기 | 클라이언트 TileMapLayer 다시 그리기 | 세션 |
|---|---|---|---|---|---|---|
| 256×256, 레이어 3 (64청크) | 196,608 B | 19.1~19.3 KB (약 10%) | 2.1 ms | 5~7 ms | 154~211 ms (적용 전체 160~280 ms) | 13.3~14.1 s, 통과 |
| 1024×1024, 레이어 3 (1,024청크) | 3,145,728 B | 306,483 B (9.7%) | 32.6 ms | 83~85 ms | **약 2.7 s** | 33 s, 통과 |

- 1024²에서는 호스트도 맵 생성 + 뷰 채우기에 약 3.0 s 걸리고, 클라이언트는 스냅샷 수신~적용에 3.4~4.7 s(이 중 2.7 s가 `TileMapLayer.set_cell` 약 300만 번, 메인 스레드를 막음)
- 데이터(압축·해제·해시)는 빠르다. 병목은 **화면 쪽 전체 다시 그리기**다
- 늦은 참가 시점: 호스트 시작 후 2.0~2.8 s, 다른 플레이어들이 이미 벽을 부순 뒤. 참가자의 스냅샷 해시가 초기 맵과 달랐고(편집이 들어 있음) 이후 델타 4~5묶음을 순번 빠짐 없이 받음

### 그 밖

| 항목 | 결과 |
|---|---|
| 세션 1회 (4인 / 9인) | 13.3~14.1 s, 테스트 파일 약 14 s. 전체 테스트(스켈레톤 + net) 14.3 s, 종료 코드 0 |
| 반복 | 같은 날 변형 포함 24회 실행, 실패 0 (따로 일부러 잘못된 인자를 준 1회: 0.5 s 만에 FAIL, 종료 코드 1, 남은 프로세스 0, 로그 폴더 보존) |
| 호스트 검사 | 4인: 수락 16, 거부 12 (unbreakable / no_wall / out_of_reach 각 4). 9인: 36 / 27 |
| 가짜 델타 | Godot가 거부: `RPC '_rpc_apply_deltas' is not allowed on node /root/Net/World from: <id>. Mode is "authority", authority is 1.` 타일 해시 그대로 |
| 내보낸 exe | release 내보내기 후 `evensong_spike.console.exe --headless -- --scene=net --net-role=host/client ...` 2개로 세션 성공, 해시 일치 |
| 창 모드 | `-- --scene=net --screenshot=...`로 호스트 화면 캡처 확인(맵·플레이어·HUD). 창 두 개로 사람이 직접 해 보는 것은 모듈에서 하지 않았고, 2026-10-21에 사람이 했다 (아래) |
| 사람 확인 (2026-10-21) | 데스크탑 창 두 개, 데스크탑 호스트 + 서피스(스냅드래곤, ARM64 빌드) 클라이언트를 Tailscale 직접 연결(핑 약 10ms)로. 이동·벽 부수기·늦은 참가 모두 맞음. 서피스 쪽 자기 캐릭터 반응이 조금 늦지만 심각하지 않음 (자기 캐릭터도 호스트가 움직이는 구조라 왕복 + 30Hz만큼 늦다 → 게임에서는 자기 캐릭터 예측) |
| 9인 | `--net-clients=8`로 9인 세션 통과 (233 checks) |

## GodotSteam 호환 (웹 확인, 2026-10-18)

**결론: GodotSteam은 Godot 4.7을 지원한다 (4.7.2 전용 빌드 있음).** 설치·실행은 하지 않았다 (Steam도 띄우지 않음).

- GodotSteam 4.20 (2026-06-24): Godot 4.7 출시에 맞춰 나옴 (공식 블로그)
- GodotSteam 4.22 (2026-08-22, 블로그 "Godot 4.7.2 and GodotSteam 4.22 / 4.11"): 모듈판과 GDExtension판 코드를 하나로 합침
- 최신 **4.23 (2026-10-05)**: Godot **4.7.2**와 4.5.2용 미리 빌드한 에디터·내보내기 템플릿, Steamworks SDK 1.65 (파일 이름 `win64-g472-s165-gs423-editor`, `godotsteam-g472-s165-gs423-templates`)
- **GDExtension 4.23.1 (2026-10-07)**: "Godot 4.4 이상 어느 버전에서나 동작". 프로젝트에 압축만 풀면 되므로 공식 Godot 4.7.2 바이너리를 그대로 쓸 수 있다 → 에이전트의 CLI 작업 방식이 바뀌지 않는다
- `SteamMultiplayerPeer`: godot4 브랜치 소스의 `register_types.cpp`에서 모듈·GDExtension 공통으로 등록된다. API: `create_host(virtual_port = 0)`, `create_client(steam_id, virtual_port = 0)`, `host_with_lobby(lobby_id)`, `connect_to_lobby(lobby_id)`, `add_peer(steam_id, virtual_port)`. `steam_transport.gd`의 호출과 맞다
- 저장소는 Codeberg(codeberg.org/godotsteam/godotsteam)로 옮겼고 GitHub 릴리스에는 큰 파일만 남는다

ENet과 다른 점 (소스에서 확인. 바꿀 때 챙길 것):

- 피어의 `server_relay`가 기본 **false**: 클라이언트끼리 호스트를 거쳐 통신할 수 없다 → 이 설계는 필요 없음을 `--net-relay=off`로 확인했다
- 최대 인원 인자가 없다: 10번째 접속은 호스트가 직접 끊어야 한다 (ENet은 `create_server(port, 8)`이 막아 줌)
- `TRANSFER_MODE_UNRELIABLE_ORDERED`는 reliable로 보낸다. 채널 수는 프로젝트 설정 `steam/multiplayer_peer/max_channels`(기본 4, 이 모듈은 0과 1만 씀)
- 가상 포트는 0이 기본 (`--net-transport=steam`이면 포트 기본값을 0으로 바꿔 둠)
- Steam 초기화: 프로젝트 설정 `steam/initialization/processes/initialize_on_startup` + `embed_callbacks`(4.20+) 또는 직접 `steamInitEx()` + 매 프레임 `run_callbacks()`

출처: [GodotSteam 블로그 2026-06-24](https://godotsteam.com/blog/2026/06/24/new-godot-new-godotsteam-and-more/), [블로그 2026-08-22](https://godotsteam.com/blog/2026/08/22/godot-472-and-godotsteam-422--411/), [Codeberg 릴리스](https://codeberg.org/godotsteam/godotsteam/releases), [GitHub 릴리스 v4.23](https://github.com/GodotSteam/GodotSteam/releases/tag/v4.23), [MultiplayerPeer 문서](https://godotsteam.com/classes/multiplayer_peer/), [변경 이력](https://godotsteam.com/changelog/godot4/), 소스 `register_types.cpp`·`godotsteam_multiplayer_peer.h/.cpp`·`godotsteam_project_settings.cpp` (godot4 브랜치)

## 실패하거나 걸린 것

- 시험 중 막힌 것은 없다. 처음 만든 코드에서 고친 것: 테스트 파일 문자열 안에 줄바꿈이 그대로 들어간 곳(`"\n"`으로), 빈 맵의 해시에서 `HashingContext.update`가 엔진 오류를 찍던 것
- **localhost만 시험했다.** 지연·손실·지터가 없다. Godot의 ENet 설정에는 지연·손실을 흉내 내는 옵션이 없어서 실제 회선이나 별도 도구(예: Windows의 clumsy)가 필요하다. Steam 릴레이도 미검증 (Steam 로그인·두 기기가 필요해 사람이 해야 한다)
- **예측·보간이 없다.** 이동을 호스트만 시뮬레이션하므로 클라이언트의 자기 캐릭터가 왕복 지연만큼 늦게 움직인다. localhost에서는 안 보이지만 릴레이 RTT 50~150 ms면 느껴질 것이다. 다른 플레이어는 30Hz 위치를 보간 없이 그대로 찍는다. Godot 내장 Synchronizer는 보간·예측을 해 주지 않으므로 게임에서 직접 짜야 한다 (자기 캐릭터 예측 + 서버 보정, 남은 보간 버퍼)
- `MultiplayerSynchronizer`의 두 모드가 모두 아쉽다: `always`는 정지 중에도 보내고, `on_change`는 이동 중에 더 비싸다. 게임에서는 정지 시 보내지 않는 unreliable 20Hz 묶음(전원 위치를 한 패킷에, 좌표 16비트)을 직접 만드는 편이 낫다. ENet range coder만 켜도 ENet 바이트 기준 30~45%(선로 기준 18~38%) 준다
- 큰 맵의 **TileMapLayer 전체 다시 그리기가 느리다** (1024²×3레이어 2.7 s, 메인 스레드 정지). 게임에서는 화면 근처 청크만 그리고 나머지는 여러 프레임에 나눠 채워야 한다. 기획 레이어는 6장(gameplay-design §3.1)이라 원본 크기도 두 배가 된다
- 1024² 스냅샷(306 KB)은 ENet reliable 창 때문에 localhost에서도 1~3 s에 걸쳐 들어왔다. 게임에서는 플레이어 근처 청크부터 보내고 속도를 조절하는 스트리밍이 필요하다 (던전이 별도 맵이라 한 번에 보낼 양은 줄어든다)
- 측정은 대략치다: 버킷은 호스트 프레임 단위로 "몇 명이 움직였나"로 나눴고, 스냅샷 직후 0.5 s는 따로 셌다(1024²에서는 스냅샷이 그보다 길어 정지 버킷에 섞였다)
- 프로젝트 설정 변경 요청: 없음. 헤드리스에서만 실행 중에 `Engine.max_fps = 60`을 건다

## 판정

**strong** — 호스트 권한, RPC 요청·검증, 권한 없는 RPC 자동 거부, Spawner·Synchronizer, 늦은 참가 스냅샷 + 델타가 전부 Godot 4 내장 기능으로 짜였고(네트워크 핵심인 world_sync·player·player_input·전송 4파일은 주석 빼고 약 400줄, CLI·봇·측정까지 모듈 전체 약 1,300줄), 9인까지 헤드리스 다중 프로세스 테스트가 14초에 끝난다(에이전트가 반복하기 쉽다). 대역폭은 9인 30Hz에서도 호스트 업로드 0.36 Mbps 수준이다. GodotSteam은 4.7.2용 빌드와 4.4+ GDExtension이 나와 있고, 전송 계층은 클래스 하나로 바꿀 수 있게 해 두었다.
남은 위험은 엔진보다 게임 쪽 일이다: 실제 회선·Steam 릴레이 미검증, 예측·보간 직접 구현, 큰 맵의 청크 단위 그리기와 스냅샷 스트리밍.
