# AGENTS.md

모든 AI 코딩 에이전트(Claude Code, Codex 등)가 공통으로 따르는 프로젝트 규칙. Claude Code는 CLAUDE.md를 통해 이 파일을 읽는다.
공통 규칙은 이 파일에만 쓴다. Codex는 CLAUDE.md를 읽지 않으므로, CLAUDE.md에는 Claude Code에서만 의미 있는 내용만 둔다.

## 프로젝트

가제: Evensong: The Nine Lamps (이븐송: 아홉 등불). 확정 전이므로 코드·패키지·저장소 이름에는 짧은 식별자 `evensong`을 쓴다.

종교적 색채의 어두운 세계에서 최대 9인이 고정 클래스(3종족 × 3직분)로 협동하는 탑다운 도트 샌드박스 어드벤처.
지상(연속 맵, 사는 층) + 던전(별도 맵, 나가는 층). 제단(배치형 코어)이 중심.

## 문서가 기준이다

- docs/game-concept.md — 무엇을 만드는가 (컨셉, 클래스, 세계관, 아트, 범위)
- docs/gameplay-design.md — 어떻게 플레이되는가 (층 1~5)
- docs/concept-art-brief.md — 컨셉아트 제작 절차, 프롬프트, 북극성

규칙:
- 저장소의 docs/가 유일한 원본이다 (2026-10-02부터. R13까지 Claude 채팅에서 쓰던 사본은 더 쓰지 않는다)
- 구현 전에 관련 문서를 읽는다. 문서와 코드가 다르면 문서가 기준이다
- 표기: ● 결정 / ○ 제안(미확정) / ? 결정 필요. ○와 ?는 구현 전에 사람에게 확인한다
- 문서 수정은 `docs/<이름>` 브랜치의 PR로 한다. 결정이나 내용을 바꾸면 고친 문서의 상태 줄을 갱신하고 "변경 이력"에 라운드 번호로 한 줄 남긴다. 라운드는 프로젝트 전체의 마지막 R + 1이다 (문서마다 따로 세지 않는다. 한 PR에서 고친 문서는 같은 번호). 오탈자 수정은 이력 없이 PR만
- 수직 슬라이스 범위(game-concept §12) 밖의 기능은 만들지 않는다

## 작업 방식

- 기능마다 브랜치: `feat/<짧은-이름>`, 문서는 `docs/<이름>`, 에셋은 `art/<이름>`
- main에 직접 커밋하지 않는다. PR로 올린다 (예외: 저장소 초기 커밋)
- PR 머지는 사람이 한다. 에이전트는 PR을 머지하지 않는다
- 에이전트를 동시에 돌릴 때는 에이전트마다 작업 트리를 따로 쓴다 (예: `git worktree add ../evensong-codex -b feat/<이름> main`). 한 브랜치는 한 에이전트만 쓴다
- 커밋 메시지는 한국어 가능. 무엇을·왜를 한 줄로
- 큰 바이너리(컨셉아트 원본, 영상, 오디오, .aseprite)는 Git LFS (.gitattributes 참조)

## 에셋

- 폴더: assets/concept/01-keyart, 02-sheets, 03-pixel, 04-env, 05-ui
- 파일명: `paladin_v03.png`, 채택본은 `_final`
- 각 폴더의 prompts.md에 도구·모델·프롬프트·레퍼런스·job id·비율·품질을 기록한다. 시드는 모델이 지원할 때만. 재현 가능해야 한다
- 생성 이미지의 호스팅 URL은 만료될 수 있으므로 생성 직후 저장소에 내려받는다

### 이미지 생성 (힉스필드 MCP)

- 힉스필드 MCP가 연결된 에이전트만 생성한다. 연결되지 않은 에이전트는 필요한 이미지를 PR 설명이나 Issue로 요청한다
- 생성 전에 `generate_*` 호출에 `get_cost: true`를 넣어 크레딧을 먼저 확인하고 사람에게 알린다 (잔액은 `balance`). 여러 장은 사람이 승인한 수만큼만
- 기본 모델은 북극성과 같은 Seedream 5.0 Lite, `model: "seedream_v5_lite"`. 도구의 기본 모델은 다르므로 매번 명시한다. 옵션은 `quality`(basic/high, 기본 basic)와 `aspect_ratio`뿐이고 시드·네거티브는 없다. 레퍼런스는 `medias`로 넣는다
- 북극성 job id를 레퍼런스로 넣는다(성화 UI 제외): `medias: [{ value: "cc88a996-0f61-4849-93c0-7d1cf96d2e0b", role: "image_references" }]` (북극성 v6, R15. docs/concept-art-brief.md §0)
- 장면을 복사하면 안 되는 생성(캐릭터 시트, 오브젝트, 타일)에는 프롬프트에 "use the reference only for its palette and warm colour temperature; do not copy its scene"을 넣는다. 화풍은 단계마다 브리프가 정하고, 성화 UI에는 북극성을 넣지 않는다

## 엔진

미정 (game-concept §13). 결정 전에는 game/ 에 엔진 프로젝트를 만들지 않는다.
주 개발 기기는 Snapdragon X Elite(Windows ARM64)다. 에이전트는 다른 환경(클라우드 컨테이너 등)에서 돌 수도 있다. 엔진·도구는 ARM64 지원을 확인하고, 배포 빌드는 x86_64도 함께 만든다.
