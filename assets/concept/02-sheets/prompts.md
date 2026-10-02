# 02-sheets 기록

(생성할 때마다 도구·모델·프롬프트·레퍼런스·job id·비율·품질을 추가. 시드는 모델이 지원할 때만)

## 팔라딘 시트 화풍 비교 (2026-10-02, 결정 대기)

브리프 §5.2의 "? 시트 화풍(회화체 / 도트풍)"을 정하려고 같은 프롬프트에 렌더링 문구 한 줄만 바꿔 2장씩 뽑았다.
공통 설정: 힉스필드 MCP / `seedream_v5_lite`, 4:3, quality high (출력 3584×2688), 레퍼런스 = 북극성 v6 (cc88a996-0f61-4849-93c0-7d1cf96d2e0b, 팔레트·색온도만). 4크레딧 (잔액 243.5 → 239.5).

| 파일 | 화풍 | job | 메모 |
|---|---|---|---|
| paladin_v01.png | 회화체 | daf9f15d-7b04-482a-b4a5-c98fb39a39ed | 상아 장포에 금 줄, 어깨·가슴에 금 넝쿨 장식. 키 큰 실사 비례. 정면과 3/4가 거의 같다 |
| paladin_v02.png | 회화체 | 7a390223-71ce-401a-813b-6c515a261ff9 | 더 어둡고 거친 질감, 회색 장포에 가로 금 줄 |
| paladin_v03.png | 도트풍 | 5fb6dfb4-97c4-413a-8e47-b422d636e88b | 굵은 블록, 장포가 길고 넓다, 실루엣이 단순 |
| paladin_v04.png | 도트풍 | fafe57aa-619e-4330-8547-7b398dc794b6 | 어두운 외곽선, 정면과 3/4가 구분됨, 가장 게임 에셋답다 |

네 장 모두 방패는 민무늬로 나왔고(문장·징 없음), 그림자에 청색이 거의 없다(어두운 픽셀 중 차가운 색 0~7%).

- paladin_style_compare.jpg: 네 장 비교 시트
- paladin_style_32px_test.png: 각 시트의 정면 그림을 32px·64px 높이로 줄인 것. 회화체는 32px에서 윤곽이 배경에 묻혀 방패와 몸이 뭉치고, 도트풍은 어깨·방패·금 줄이 남는다. 실제 스프라이트는 3단계 PixelLab이 다시 그리므로 이 축소는 "시트가 32px에 쓸 정보를 얼마나 주는가"를 보는 근사다

렌더링 문구 (나머지는 brief §5.2 프롬프트 + §3 공통 접미어 그대로):
- 회화체: `Rendering: painterly concept art, visible brush strokes, soft painted edges, clean readable shapes.`
- 도트풍: `Rendering: pixel art character sheet, each view drawn as a 64-pixel-tall sprite enlarged with nearest-neighbour scaling, crisp square pixels on one strict grid, no anti-aliasing, no blur, dark outline, limited palette of about 48 colours.`
