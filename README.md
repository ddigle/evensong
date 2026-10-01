# Evensong: The Nine Lamps (가제)

이븐송: 아홉 등불

하나의 신앙으로 뭉친 최대 9인이 이단과 타락과 악마에게 잠식당하는 세계를 정화하며 살아남는 탑다운 도트 협동 샌드박스.

- 기획: docs/game-concept.md
- 게임 방식: docs/gameplay-design.md
- 컨셉아트: docs/concept-art-brief.md, assets/concept/
- 에이전트 규칙: AGENTS.md (Claude Code는 CLAUDE.md)

## 시작하기

1. Git for Windows, Git LFS 설치 후 `git lfs install`
2. 이 폴더에서 `git init`, 첫 커밋, GitHub에 비공개 저장소로 push
3. Claude Code 실행: 이 폴더에서 `claude`
4. 힉스필드 MCP 연결: `claude mcp add --transport http higgsfield https://mcp.higgsfield.ai/mcp` → Claude Code 안에서 `/mcp`로 로그인
5. 북극성 이미지 두 장을 assets/concept/01-keyart/ 로 내려받기 (URL은 docs/concept-art-brief.md §0)

## 협업

- main 보호, 기능마다 브랜치 + PR
- 미결 사항은 GitHub Issues로 (docs의 "미결" 목록에서 옮김)
