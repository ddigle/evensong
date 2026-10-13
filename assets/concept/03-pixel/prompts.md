# 03-pixel 기록

(생성할 때마다 도구·모델·프롬프트·레퍼런스·job id·비율·품질을 추가. 시드는 모델이 지원할 때만)

## AutoSprite 시험 (2026-10-14, 실행 불가, 크레딧 사용 0)

목적: 동작 애셋을 사지 않고 늘릴 수 있는지 보려고 힉스필드 `autosprite`(캐릭터 이미지 → 스프라이트 시트 PNG)로 1건만 시험. 사람이 1건 승인.
설정: `model: "autosprite"`, `kind: "walk"`, `video_tier: "turbo"`, `frame_count: 8`, `frame_size: 64`, `medias: [{ value: "2806487c-c057-4a4a-a4b8-87522f5e8546", role: "image" }]` (팔라딘 정면).

결과 (힉스필드 MCP, 잔액 199.5 → 199.5):
- `generate_image` + `get_cost: true` → "Error estimating cost: Something went wrong" (request 98929ab5-592a-4a1c-b609-a8c3377e5721)
- `generate_image` 제출 → "Job set type not supported: autosprite" (request 6037a24b-d712-4bbc-98f5-d9813ec9886e). job이 만들어지지 않음
- `generate_video` → "image model; use generate_image instead". `apps_search "sprite"` → 결과 없음

`models_explore`에는 모델이 있지만(파라미터: kind idle/walk/run/attack/jump/custom/iso_*, video_tier turbo/pro/max, frame_count 2~64, frame_size 32~512, remove_bg, with_sound, is_humanoid) MCP로는 제출할 수 없다. 다시 시험하려면 힉스필드 웹에서 사람이 직접 하거나 MCP 지원을 기다린다.
