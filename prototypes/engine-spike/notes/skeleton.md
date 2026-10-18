# skeleton: 프로젝트 뼈대와 CLI 헤드리스 작업

시험일 2026-10-18, Godot 4.7.2 stable (official, ed1daf0bf), Windows 11 데스크탑(Ryzen 9 9950X3D, RTX 5090), SSH 세션에서 Git Bash로 실행.

## 시험한 것

요구사항 "에이전트가 CLI에서 헤드리스로 전부 할 수 있을 것"의 바닥: 임포트, 테스트, 내보내기, 내보낸 exe 실행, 장면 실행, 스크린샷을 모두 GUI 없이 명령 한 줄로.

- 프로젝트 설정: 480x270, 스트레치 viewport + integer, 기본 필터 Nearest, 2D 픽셀 스냅. `test_skeleton.gd`가 설정값뿐 아니라 루트 창(`content_scale_*`, `canvas_item_default_texture_filter`, `snap_2d_*`)에 실제로 적용됐는지 확인한다
- 테스트 러너: `--script res://tests/run_all.gd`로 `test_*.gd`를 찾아 돌리고 종료 코드로 결과를 알린다
- 러너가 실패를 놓치지 않는지 일부러 깨진 테스트 5개로 확인 (확인 뒤 지움): check 실패, null 메서드 호출, 없는 키 접근(헬퍼 함수 안), 파싱 오류, 끝나지 않는 await(`--timeout=2`). 다섯 다 FAIL, 종료 코드 1
- 내보내기: `--export-release "Windows Desktop"` → exe 실행 `--headless -- --smoke`, `--headless --quit`
- 임시 모듈(`zdemo/zdemo.tscn`, 확인 뒤 지움)로 메뉴 자동 탐색, `--scene=`, 장면 경로 직접 실행, `--quit-after`, 스크린샷 확인

## 수치

| 항목 | 결과 |
|---|---|
| 첫 헤드리스 임포트 (`--import`) | 3.2초, 종료 코드 0 |
| 전체 테스트 (1파일 44 checks) | 테스트 자체 20~30ms, 프로세스 전체 0.4초, 종료 코드 0 |
| release 내보내기 | 3.5초, 종료 코드 0 |
| `evensong_spike.exe` (pck 내장) | 109,277,888 바이트 (약 104 MiB) |
| `evensong_spike.console.exe` (콘솔 래퍼) | 188,928 바이트 |
| 내보낸 exe `--headless -- --smoke` | 0.19초, `SPIKE_SMOKE ok ... exported=true`, 종료 코드 0 |
| 내보낸 exe `--headless --quit` | 종료 코드 0 |
| 헤드리스 장면 120프레임 (`--quit-after 120`) | 1.3초, 종료 코드 0 |
| 스크린샷 (`--screenshot`, 창 모드) | SSH 세션에서도 성공. Vulkan 1.4.341 Forward+, RTX 5090. 480x270 PNG |

## 실패하거나 걸린 것

- 없음 (막힌 것 없음). 참고할 점:
- 스크린샷은 렌더러가 필요해서 `--headless`로는 안 된다 (더미 렌더러). 이 데스크탑은 SSH에서도 창 모드 실행이 되지만 GPU 없는 클라우드 컨테이너는 시험하지 않았다
- 스크린샷은 루트 뷰포트의 기본 해상도(480x270) 이미지다. 정수 배율로 키운 화면 그대로가 필요하면 배율 모듈에서 따로 잡아야 한다
- SSH 세션에서 창 모드로 띄우면 `Failed to request display timeout override.`가 한 줄 나온다. 결과에는 영향 없다
- `--script` 모드에서는 오토로드가 들어오지만 첫 프레임 뒤에 쓰는 게 안전하다 (러너는 첫 `process_frame`을 기다린 뒤 시작한다). 헤드리스 루트 창 크기는 64x64로 나오지만 `content_scale_size`는 480x270으로 적용된다
- GDScript 4에서 `1 == "1"`처럼 타입이 다른 값 비교는 false가 아니라 런타임 오류다. 그래서 `check_eq`는 타입을 먼저 본다
- 에디터 언어가 한국어로 설정돼 있어 임포트·내보내기 진행 줄이 한국어로 나온다 (색 코드 포함). 판정은 종료 코드와 `SPIKE_*` 줄로 한다
- 런타임 오류 감지는 Godot 4.5에 들어온 `Logger`(`OS.add_logger`)를 쓴다. 4.5 아래 버전에서는 러너가 파싱되지 않는다

## 판정

**strong** — 임포트·테스트·내보내기·exe 실행·장면 실행·스크린샷이 모두 명령 한 줄과 종료 코드로 끝나고, 각각 몇 초 안이다. 에이전트가 GUI 없이 반복하기에 충분하다.
