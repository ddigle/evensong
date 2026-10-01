# Evensong: The Nine Lamps (가제)

이븐송: 아홉 등불

하나의 신앙으로 뭉친 최대 9인이 이단과 타락과 악마에게 잠식당하는 세계를 정화하며 살아남는 탑다운 도트 협동 샌드박스.

- 기획: docs/game-concept.md
- 게임 방식: docs/gameplay-design.md
- 컨셉아트: docs/concept-art-brief.md, assets/concept/
- 에이전트 규칙: AGENTS.md (Claude Code는 CLAUDE.md)

## 시작하기 (새 기기·협업자)

1. Git for Windows(ARM64 기기는 ARM64 설치본), Git LFS 설치 후 `git lfs install`
2. `git config --global user.name "<이름>"`, `git config --global user.email "<GitHub noreply 이메일>"`, `git config --global init.defaultBranch main`
3. `git clone https://github.com/ddigle/evensong.git`. 컨셉아트(북극성 등)는 LFS로 함께 받아진다. PNG가 몇 줄짜리 텍스트로 보이면 `git lfs pull`
4. 에이전트 실행: Claude Code는 이 폴더에서 `claude` (CLAUDE.md가 AGENTS.md를 불러온다). Codex는 이 폴더나 별도 worktree에서 `codex` (AGENTS.md를 바로 읽는다)
5. 힉스필드 MCP(이미지 생성): claude.ai의 힉스필드 커넥터가 연결돼 있으면 생략. 아니면 `claude mcp add --transport http higgsfield https://mcp.higgsfield.ai/mcp` → Claude Code 안에서 `/mcp`로 로그인. 둘 다 등록하지 않는다

저장소 초기 설정(스타터 킷 반입, 북극성 두 장 보관, 초기 커밋)은 2026-10-01에 끝났다.

## 협업

- main은 PR로만 바꾼다. 브랜치 보호를 쓸 수 없는 플랜이면 AGENTS.md 규칙으로 지킨다
- 기능마다 브랜치 + PR
- 미결 사항은 GitHub Issues로 (docs의 "미결" 목록에서 옮김)
