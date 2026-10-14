@AGENTS.md

## Claude Code 전용

공통 규칙(힉스필드 사용 규칙 포함)은 AGENTS.md에 있다. 여기에는 Claude Code에서만 의미 있는 내용만 둔다.

- 힉스필드 MCP 연결은 claude.ai 커넥터 또는 `claude mcp add --transport http higgsfield https://mcp.higgsfield.ai/mcp` 중 하나만 쓴다. 둘 다 등록하면 같은 도구가 두 벌 생긴다
- PixelLab MCP는 `claude mcp add pixellab https://api.pixellab.ai/mcp -s user -t http -H "Authorization: Bearer <토큰>"`로 사람이 등록한다. 프로젝트(local) 범위는 경로 대소문자(`C:\dev` / `C:\Dev`)가 다르면 잡히지 않으므로 `-s user`를 쓴다. 토큰은 저장소에 넣지 않는다 (`-s project` 금지)
