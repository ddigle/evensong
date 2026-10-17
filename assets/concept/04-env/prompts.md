# 04-env 기록

(생성할 때마다 도구·모델·프롬프트·레퍼런스·job id·비율·품질을 추가. 시드는 모델이 지원할 때만)

## PixelLab 4단계 1차 시험 (2026-10-17, brief §5.7, 18회 사용)

R28에서 사람이 4단계를 PixelLab으로 바로 가기로 하고 1차 시험 최대 40회를 승인했다. 이번에 18회를 썼다. 잔액 1,799 → 1,781.

1. 풀밭↔일군 흙 타일 (3회): `create_topdown_tileset`, `lower_description: "tilled farm soil, neat rows of dark warm brown furrows of loose earth, cozy"`, `upper_description`은 2·3차 v02와 같은 풀밭 문구, `upper_base_tile_id` = v02 타일셋(fe7bfb85-8339-4e1f-9492-e7755ab300f8)의 풀 기준 타일 c1198d1f-4f65-44fc-8b18-75c2c1b42402, `transition_description: "a thin trimmed grass edge with a few loose soil crumbs"`, `transition_size: 0.25`, `tile_size: 16`, `view: "low top-down"`, `outline: "lineless"`, `shading: "basic shading"`, `detail: "medium detail"` (tileset 0f3a96a4-e4d2-4602-827d-13963849d3fe, 흙 기준 타일 887b080a-fb0c-443e-85e5-5f205dbdccf9) → `tiles_grass-soil_v01.png` + `.json`(타일 배치, 내려받기 주소는 뺌)
   - 풀 타일은 v02와 픽셀까지 같다(기준 타일로 이어 붙였기 때문)
2. 제단 (3회): `create_map_object`, `view: "low top-down"`, `outline: "single color outline"`, `shading: "medium shading"`, `detail: "medium detail"`
   - a (object b6cd7d82-1f06-4d87-923a-2a83c40259d6, 48×48) → `altar_v01_a.png`: "a broad low square stone altar, grey stone block with worn warm gold-leaf rims along its top edges, plain stone faces with no carvings, symbols, letters or marks, nine small clay oil lamps with tiny warm flames standing on its flat top in three straight rows of three, a few dried herbs at its base, cozy warm candlelight colours"
   - b (object 46d1d31f-9dc3-441e-9392-18c33b727d9b, 48×48) → `altar_v01_b.png`: "a wide low square altar of grey stone, flat top seen from slightly above with exactly nine small clay oil lamps arranged in a neat three by three grid, each lamp with a tiny warm flame, thin worn gold rim around the top edge, plain sides with no carvings, no symbols, no letters, warm cozy light"
   - c (object 0a611025-e109-4b43-a294-deb5827cd5ce, 화풍 맞춤: `background_image` = v02 풀 타일 4×4(64×64), `inpainting: {"type": "oval", "fraction": 0.7}`) → `altar_v01_c.png`: "a broad low square stone altar standing on the grass, grey stone with worn warm gold-leaf rims, plain stone faces with no carvings, symbols, letters or marks, nine small clay oil lamps with tiny warm flames on its flat top in three straight rows of three"
   - 첫 c 호출은 바탕 그림 base64가 잘못 들어가 실패했다(값 없음)
3. 조제대 (2회): `create_map_object`, 제단과 같은 설정, "a small wooden alchemy workbench, sturdy warm wooden table with a little copper cauldron, a stone mortar and pestle, two small glass bottles and a bundle of dried herbs on top, cozy warm colours, no symbols, no letters"
   - a 32×32 (object 46d8853c-255c-4944-8bda-460b54f2145b) → `alchemy_table_v01_a.png`
   - b 48×32 (object b8749dc4-a001-4186-8c35-22d89c874b2e) → `alchemy_table_v01_b.png`
4. 작물·작은 것 한 묶음 (10회): `create_1_direction_object`, `size: 16`(64칸), `view: "top-down"`, description "cozy farming game pixel art item, small and centred, 1px dark warm brown outline, 2-3 shade levels per material, soft warm muted earthy colours, no text, no letters", `item_descriptions` 54개 (review object bc2c1c55-35dd-46e9-9db0-b7df6405b634) → `items_v01_sheet.png` (8×8, 16px 칸, 번호 = 줄×8 + 칸)
   - 0~5 회복 약초(심은 씨앗, 싹, 어린 것, 반쯤, 다 자람, 수확 다발), 6~11 버프 약초, 12~17 독초 (각 "<작물> stage N: …, of a <작물 모양>"; 회복 약초 = "healing herb with round soft green leaves and small bright red berries", 버프 약초 = "buff herb with slender stems and bright golden-yellow flowers", 독초 = "poison weed with jagged yellow-green leaves and small yellow-green spotted pods, no purple")
   - 18~20 씨앗 봉투, 21~23 물약(빨강·금빛·독), 24~25 구리·철 광석 덩이, 26 야생 약초 덤불, 27 동굴 버섯, 28 이끼 돌, 29 풀 무더기
   - 30~35 다 자람·수확 다발 다른 판, 36~44 성장 2~4칸 다른 판, 45~47 물약 다른 판, 48~51 광맥(구리 줄·덩이, 철 줄·덩이, 바위벽 타일 위), 52~53 버섯·덤불 다른 판
   - 54~63은 설명 없이 채워진 칸(도구가 공통 설명으로 그림): 양동이, 물뿌리개, 괭이, 삽, 쇠스랑, 흙더미, 장작, 붉은 열매 바구니, 갈퀴, 밀 다발
5. 손질 (무료)
   - `altar_v02.png` (48×57): 제단 b에 둘째 등잔 줄(21~29줄)을 한 번 더 넣어 9개(3×3)로, 파란 기운 회색은 R과 B를 바꿔 따뜻한 회색으로, 연보라 모서리 장식은 brief §4 신앙 금빛 4단으로. 옛 아래 모서리 장식이 가운데 높이에 남은 28~29줄은 26~27줄로 덮음
   - 물 준 흙: 일군 흙 타일에 RGB × (0.72, 0.70, 0.74)
   - 시든 작물: 다 자란 작물의 잎·꽃 색을 병든 올리브(#6f8f3a 계열 3단)와 잿빛 3단으로(외곽선·흙은 그대로, brief §4 ○)
6. 목업 (무료): `stage4_mockup_v01.png`(3배)·`stage4_mockup_v01_1x.png`(1배). 풀밭, 일군 흙 밭(줄마다 회복·버프·독초 0~4단계, 마지막 줄은 물 준 흙), 오염 옆 작은 밭의 시든 작물 셋, 오염 가장자리 풀밭의 독초, v03 오염 땅, 제단 v02, 조제대 b, 다섯 클래스(표식 포함). `stage4_items_v01.png`(작은 것 3배), `stage4_withered_v01.png`(다 자람 ↔ 시듦, 4배)
7. 판정 (검토 에이전트 넷: 화풍 일관성, 브리프 색·톤 규칙, 1배·3배 가독성, 남은 예산. 이미지와 문서만 보고 판정)
   - 제단: a는 비스듬한 시점(마름모 격자), c는 아이소메트릭 정육면체라 탈락. b만 정렬형이라 손질판 `altar_v02.png`가 후보다. 남은 흠: 그림이 38px라 3×3 칸(48px)보다 작음, 불꽃이 1~2px라 1배에서 가장 밝은 점이 아님(풀꽃 점보다 약함), 윗면 이음매가 미로 무늬라 새김처럼 보임, 진한 외곽선이 없음
   - 조제대: a는 둥근 상판에 다리가 비스듬한 3/4 시점이라 탈락. b는 색·크기가 맞지만 약간 돌아간 3/4 시점이고 청록 병이 있음(우리 물약 색이 아님)
   - 흙 타일: 채택 후보. 칸마다 같은 황토 말뚝 무늬가 반복돼 빈 밭이 심은 것처럼 보이고, 씨앗 단계(0단계) 흙더미와 헷갈림. 물 준 흙은 칸별 덧칠로 충분해 둘째 흙 타일셋(일군 흙↔물 준 흙)은 만들지 않는다
   - 작물: 세 작물은 서로 구분된다. 단계마다 키가 고르게 커지지 않고(예: 회복 5·9·12·13·14px), 익은 색이 1단계부터 보인다(회복 빨강, 버프 주황). 독초는 #6f8f3a와 색상·채도로는 갈리지만(겨자색, 채도 약 0.95) 명도가 같고, 화면에서 가장 채도가 높아 버프와 함께 노랗게 읽힘 → 둘째 신호(녹·붉은 반점) 필요. 시든 회복 약초는 빨간 열매가 남아 건강해 보임(시든 버프·독초는 읽힘). 16px 작물 하나에 35~50색이라 32px 캐릭터보다 거칠다
   - 작은 것: 물약·씨앗 봉투·광석 덩이·버섯·덤불은 대체로 채택. 외곽선 진하기가 제각각(순흑 #000, 따뜻한 갈흑, 중간 갈색, 없음). 광맥(48~51)은 던전 벽 타일을 보고 정한다. 63 밀 다발은 슬라이스 밖 넷째 작물
   - 기존 오염 땅 v03(목업 오른쪽): #3b1f4d 보라가 오염 면의 약 26%(§6 측정 1.41%, 기준 1% 미만)이고 풀 경계에 보라 선이 이어진다. §5.4의 올리브 곰팡이·뼈 돌기가 없다 → 손질 필요
   - 풀 v02(#99bd5a)는 병든 올리브(#6f8f3a)와 색상·채도가 같아 오염 신호가 풀 그늘처럼 읽힌다(brief §4 ○ R23과 어긋남. 사람이 정할 일). 풀·흙·오염 모두 속 타일이 하나라 반복 무늬가 보인다(Wang 형식의 한계 → 손으로 속 타일 변형과 장식 점)
   - 목업이 낮처럼 밝아 "제단 빛 = 안전"은 판정할 수 없었다. 빛 밖을 어둡게 한 저녁판이 필요하다
   - 도구 요령: `create_map_object`의 화풍 맞춤(background_image)은 아이소메트릭이 나왔다 → 큰 오브젝트는 기본 모드에 "front edge exactly horizontal, edges parallel to the image, not rotated, not isometric" 같은 정렬 문구를 넣는다. `create_1_direction_object` 묶음은 64칸 화풍이 고르고 10회였다. `create_topdown_tileset` 기본 모드와 `create_map_object`에는 palette 인자가 없어 위협 쪽은 뒤에 `reduce_colors`로 맞춘다
