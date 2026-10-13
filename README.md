# Evensong: The Nine Lamps (가제)

이븐송: 아홉 등불

하나의 신앙으로 뭉친 최대 9인이 이단과 타락과 악마에게 잠식당하는 세계를 정화하며 살아남는 탑다운 도트 협동 샌드박스.

- 기획: docs/game-concept.md
- 게임 방식: docs/gameplay-design.md
- 컨셉아트: docs/concept-art-brief.md, assets/concept/
- 에이전트 규칙: AGENTS.md (Claude Code는 CLAUDE.md)

## 시작하기 (새 기기·협업자, Windows)

WSL이 아니라 Windows에서 직접 작업한다. 게임 엔진 에디터, Aseprite, GPU를 그대로 쓰고 LFS·줄바꿈 문제를 한 파일시스템 안에서 끝내기 위해서다.

1. 설치 (PowerShell). ARM64 기기면 ARM64 설치본이 깔렸는지 확인한다
   ```powershell
   winget install --id Git.Git -e              # Git LFS 포함
   winget install --id astral-sh.uv -e         # 파이썬 도구 실행 (Python도 uv가 받는다)
   irm https://claude.ai/install.ps1 | iex     # Claude Code (네이티브)
   ```
2. Git 설정
   ```powershell
   git lfs install
   git config --global user.name "<이름>"
   git config --global user.email "<GitHub noreply 이메일>"
   git config --global init.defaultBranch main
   git config --global core.longpaths true
   ```
3. `git clone https://github.com/ddigle/evensong.git C:\Dev\evensong` 후 `cd C:\Dev\evensong`. 처음에 GitHub 로그인 창이 뜬다(Git Credential Manager). 컨셉아트는 LFS로 함께 받아진다
4. 도구: 저장소 루트에서 `uv run tools/art/arttool.py <명령>`. 첫 실행 때 uv가 Python(`.python-version`)과 패키지(`arttool.py.lock`)를 받는다. 가상환경을 따로 만들지 않는다 (사용법은 `tools/art/arttool.py` 머리말)
5. 점검: `powershell -ExecutionPolicy Bypass -File tools\check-setup.ps1`. FAIL이 0이면 된다
6. 에이전트 실행: Claude Code는 이 폴더에서 `claude` (CLAUDE.md가 AGENTS.md를 불러온다). Codex는 이 폴더나 별도 worktree에서 `codex` (AGENTS.md를 바로 읽는다)
7. 힉스필드 MCP(이미지 생성): claude.ai의 힉스필드 커넥터가 연결돼 있으면 생략. 아니면 `claude mcp add --transport http higgsfield https://mcp.higgsfield.ai/mcp` → Claude Code 안에서 `/mcp`로 로그인. 둘 중 하나만 쓴다 (둘 다 등록하면 같은 도구가 두 벌 생긴다)

저장소 초기 설정(스타터 킷 반입, 북극성 두 장 보관, 초기 커밋)은 2026-10-01에 끝났다.

## 협업

- main은 PR로만 바꾼다. 브랜치 보호를 쓸 수 없는 플랜이면 AGENTS.md 규칙으로 지킨다
- 기능마다 브랜치 + PR
- ? 미결 사항을 GitHub Issues로 옮길지 결정 필요 (지금은 각 문서의 "미결" 목록이 기준)
