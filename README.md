# Evensong: The Nine Lamps (가제)

이븐송: 아홉 등불

하나의 신앙으로 뭉친 최대 9인이 이단과 타락과 악마에게 잠식당하는 세계를 정화하며 살아남는 탑다운 도트 협동 샌드박스.

- 기획: docs/game-concept.md
- 게임 방식: docs/gameplay-design.md
- 컨셉아트: docs/concept-art-brief.md, assets/concept/
- 에이전트 규칙: AGENTS.md (Claude Code는 CLAUDE.md)

## 시작하기 (새 기기·협업자, Windows)

WSL이 아니라 Windows에서 직접 작업한다. 게임 엔진 에디터, Aseprite, GPU를 그대로 쓰고 LFS·줄바꿈 문제를 한 파일시스템 안에서 끝내기 위해서다.

1. 설치 (PowerShell)
   ```powershell
   winget install --id Git.Git -e              # Git LFS 포함
   winget install --id astral-sh.uv -e         # 파이썬 도구 실행 (Python도 uv가 받는다)
   irm https://claude.ai/install.ps1 | iex     # Claude Code (네이티브)
   winget install --id GitHub.cli -e           # gh (에이전트가 PR을 만들고 머지한다)
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
   - SSH로 접속한 세션에서는 Git Credential Manager가 Windows 자격 증명 관리자를 못 써서 push가 `Unable to persist credentials with the 'wincredman' credential store`로 실패한다. 이 기기용 SSH 키(`ssh-keygen -t ed25519`)를 GitHub Settings → SSH keys에 등록하고 push만 SSH로 보낸다: `git remote set-url --push origin git@github.com:ddigle/evensong.git`
   - gh 로그인: `gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key --web --insecure-storage` → 표시된 코드를 https://github.com/login/device 에 넣는다. `--insecure-storage`는 같은 이유로 토큰을 `%APPDATA%\GitHub CLI\hosts.yml`에 둔다. 확인은 `gh auth status`
4. 도구: 저장소 루트에서 `uv run tools/art/arttool.py <명령>`. 첫 실행 때 uv가 Python(`.python-version`)과 패키지(`arttool.py.lock`)를 받는다. 가상환경을 따로 만들지 않는다 (사용법은 `tools/art/arttool.py` 머리말). uv는 0.13.0 이상이어야 한다(`uv self update`). 그보다 낮으면 SSH로 접속한 세션에서 `uv trampoline failed to spawn Python`으로 실패한다
5. 점검: `powershell -ExecutionPolicy Bypass -File tools\check-setup.ps1`. FAIL이 0이면 된다
6. 에이전트 실행: Claude Code는 이 폴더에서 `claude` (CLAUDE.md가 AGENTS.md를 불러온다). Codex는 이 폴더나 별도 worktree에서 `codex` (AGENTS.md를 바로 읽는다)
7. 힉스필드 MCP(이미지 생성): claude.ai의 힉스필드 커넥터가 연결돼 있으면 생략. 아니면 `claude mcp add --transport http higgsfield https://mcp.higgsfield.ai/mcp` → Claude Code 안에서 `/mcp`로 로그인. 둘 중 하나만 쓴다 (둘 다 등록하면 같은 도구가 두 벌 생긴다)

저장소 초기 설정(스타터 킷 반입, 북극성 두 장 보관, 초기 커밋)은 2026-10-01에 끝났다.

## 기기 간 파일 옮기기

작업 기기(Windows 데스크탑·노트북, macOS, Android)는 Tailscale 한 계정으로 이어져 있다. 허브는 저장소와 에이전트가 있는 데스크탑이다. 아래 `<데스크탑>`, `<기기>`에는 `tailscale status`에 나오는 기기 이름을, `<사용자>`에는 데스크탑 Windows 계정 이름을 넣는다.

- **공용 폴더**: 데스크탑의 `C:\dev\share\`. 저장소 밖에 있으며 커밋하지 않는다
  - `inbox\`: 다른 기기에서 보낸 파일이 들어온다. 정리가 끝나면 비운다
  - `refs\<이름>\`: 구매한 레퍼런스 팩 (예: `refs\tiny-farm-rpg\`). 공개 저장소에 올리면 재배포가 되므로 여기에만 둔다
- **다른 기기 → 데스크탑**
  - Windows·macOS: `scp -r "<파일이나 폴더>" <사용자>@<데스크탑>:C:/dev/share/inbox/`
    - 폴더째 보낼 수 있다
    - 경로에 공백이나 괄호가 있으면, 그 위 폴더로 `cd`한 뒤 `".\폴더 이름"`처럼 상대 경로로 보낸다
    - scp는 파일마다 왕복이 생겨 작은 파일이 많으면 느리다(5,800개·14MB에 약 20분). 그럴 때는 `tar -cf 묶음.tar "폴더"`로 묶어 한 파일로 보내고 데스크탑에서 `tar -xf 묶음.tar`로 푼다(tar는 Windows·macOS 기본)
    - 보내는 기기의 SSH 공개키가 데스크탑의 `C:\ProgramData\ssh\administrators_authorized_keys`에 한 줄로 들어 있어야 한다. 관리자 계정은 이 파일만 읽고, 비밀번호 로그인은 꺼져 있다
  - Android나 키가 없는 기기: Taildrop을 쓴다. 공유 → Tailscale → `<데스크탑>`을 고르거나, Windows 탐색기에서 우클릭 → Send with Tailscale
    - 받은 파일은 데스크탑의 `Downloads`에 들어온다. 그 뒤 `C:\dev\share\`로 옮긴다
    - 폴더는 ZIP으로 묶어서 보낸다
- **데스크탑 → 다른 기기**: `tailscale file cp <파일> <기기>:`. 받는 기기의 다운로드 폴더에 들어온다. 에이전트도 SSH 세션에서 이 명령으로 결과물을 보낼 수 있다

## 협업

- main은 PR로만 바꾼다. 브랜치 보호를 쓸 수 없는 플랜이면 AGENTS.md 규칙으로 지킨다
- 기능마다 브랜치 + PR
- ? 미결 사항을 GitHub Issues로 옮길지 결정 필요 (지금은 각 문서의 "미결" 목록이 기준)
