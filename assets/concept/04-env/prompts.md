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

## 4단계 1차 시험 손질 (2026-10-17, 생성 없음, 무료)

1차 판정의 지적을 손질 에이전트 여섯이 나눠 고쳤다(제단, 흙, 작물, 작은 것·조제대, 오염 땅, 풀). 모두 스크립트로 픽셀을 직접 바꾸거나 손으로 찍었고 생성 도구는 쓰지 않았다. 손질 전후는 `stage4_fix_<묶음>_compare.png`.

- 제단 `altar_v03.png` (48×57, 판 47×43): b9의 배치(3×3 등잔, 따뜻한 회색, 금 모서리)를 바탕으로 다시 찍었다. 폭 38 → 47px(3×3 칸을 채움), 등잔 간격 가로 13·세로 10px, 불꽃 3×4(#efe3c6 심 + #f4c95d + #c9932b 밑동), 접시는 짙은 흙빛, 윗면 미로 이음매 → 판석 이음매 넷, 끊긴 1px 금 테두리, 외곽선 #1a1714. 변형: `altar_v03_unlit.png`(꺼짐, 심지 점), `altar_v03_5lit.png`(5개 켜짐. 등잔 수 메커닉은 game-concept §9.3 ○)
- 흙 `tiles_grass-soil_v02.png`: 칸마다 찍힌 황토 말뚝 무늬를 지우고 1px 고랑 한 줄로, 와인빛 #351a20 → 따뜻한 갈흑. 풀 픽셀은 그대로라 v01 `.json` 배치를 그대로 쓴다. `tiles_grass-soil_v02_watered.png`: 흙 픽셀만 (0.70, 0.66, 0.62)을 곱하고 1px 물기 점을 넣음 → 둘째 흙 타일셋 대신
- 작물 `crops_v02_sheet.png` (줄: 회복·버프·독초, 칸: 0~4단계, 수확, 시듦, 16px): AI 그림을 바탕으로 손으로 다시 찍었다(AI 작물 프레임은 모두 바뀜). 키 4~5/8/11/14/14px, 익은 색은 4단계에만(회복 빨간 열매, 버프 주황 꽃, 독초 녹슨 꼬투리 반점 #c4421c), 독초 채도 0.95 → 약 0.7, 0단계 흙더미에 작물색 씨앗, 닫힌 #1a1714 외곽선, 작물마다 7~12색. 시든 판은 한 방법(잎은 잿빛, 열매·꽃 자리는 마른 붉은색 #5c1010, 올리브 곰팡이 점)
- 작은 것 `items_v02_strip.png` (왼쪽부터 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 45, 46, 47, 52, 53번): 순흑·청흑 외곽선 → #1a1714, 씨앗 봉투에 작물색 띠, 독 물약을 겨자색 + 녹 반점으로(병든 올리브 계열에서 뺌), 덤불·이끼 돌을 세이지 쪽으로, 풀 무더기 끝을 짚 베이지로. 조제대 `alchemy_table_v02.png`: 청록 병 → 빨간 물약, 구리 솥을 작은 가마솥으로
- 오염 땅 `tiles_grass-corruption_v04.png`(03-pixel v03을 손질, v02 `.json` 배치) + 속 타일 변형 `tiles_ash_var_1~3_v01.png`: 보라 소용돌이 → 따뜻한 짙은 금, 몇 곳만 1px 보라 맥, 풀 경계 보라 선 제거, 올리브 곰팡이·뼈 돌기를 조금. §6 측정(6×6칸, 96px): 보라 26.27% → 0.28%, 어두운 픽셀 중 차가운 색 97.3% → 2.3%. 손질판이라 타일셋 id는 없다
- 풀 속 타일 변형 `tiles_grass_var_1~4_v01.png`: 같은 초록에 꽃 점만 다르게, 연보라 점은 크림·분홍으로. 바깥 1px 테두리는 원본과 같아 서로·경계 타일과 이어진다. `grass_hue_proposals_v01.png`: 풀 색을 (a) 15° 초록 쪽, (b) 15° 금빛 쪽으로 옮긴 제안(적용 안 함. 독초는 옛 AI 그림으로 그려져 있음)
- 목업 v02: `stage4_mockup_v02_day.png`(3배)·`_day_1x`, 저녁판 `stage4_mockup_v02_eve.png`·`_eve_1x`(제단 둘레 밖을 3단으로 어둡게, 등잔 5개 켜짐), 작은 것 `stage4_items_v02.png`
- 재판정 (검토 에이전트 셋)
  - 풀린 것: 외곽선 통일, 제단 크기·이음매·외곽선·금 테두리, 오염 땅 §6 통과(목업 전체 보라 1.41% → 0.01%), 흙의 말뚝 무늬, 청록 병, 시든 회복 약초, 작물 색 수, 독초 채도, 저녁판에서 빛 안이 안전으로 읽힘
  - 새로 생긴 흠: 흙이 칸마다 고랑 한 줄이라 나무 바닥처럼 보임. 작물 밑 흙더미에 외곽선이 있어 화분처럼 보임. 줄기가 가는 버프·독초는 외곽선이 50% 넘게 차지해 1배에서 검게 뭉침. 오염 땅 금이 닫혀 포석처럼 보이고 뼈 돌기가 16px 격자로 반복됨. 저녁에는 오염이 그냥 어둠이 됨. 덤불이 시든 작물처럼 회색이 됨
  - 남은 흠: 조제대가 여전히 비스듬한 시점, 불꽃이 화면에서 가장 밝은 점이 아님(버섯·후광·풀꽃이 더 밝음), 물 준 흙이 명도로만 구분돼 저녁 빛 띠 경계와 헷갈림, 독초(레몬 노랑)가 버프 물약(노랑)과 짝지어 보임, 시든 작물에 병든 올리브가 거의 없음(brief §4 ○는 "병든 올리브 + 잿빛")

## PixelLab 4단계 1차 시험 연장 (2026-10-17, 9회 사용) + 2차 손질 (무료)

사람이 1차 판정 뒤 제안대로 정함: 풀 초록을 약 +15° 초록 쪽으로, 물약 색을 작물에 맞춤(회복 빨강, 버프 호박·주황, 독 = 독초 노랑 + 녹 반점), 시든 작물은 병든 올리브 + 잿빛, 물 준 흙은 칸별 덧칠(둘째 흙 타일셋 안 만듦), 남은 22회 중 9회를 던전 바닥↔벽 타일 1세트와 큰 오브젝트 5장에 씀(13회는 남김). 잔액 1,781 → 1,772.

1. 던전 바닥↔벽 (4회): `create_topdown_tileset`, `lower_description: "dark worn stone dungeon floor, uneven grey-brown flagstones with dust and grit, dim and grim"`, `upper_description: "rough dark grey natural cave rock wall, solid cracked boulders, grim and heavy"`, `transition_description: "the rock wall's front face rising from the floor with a dark shadow at its base"`, `transition_size: 1.0`(25장, 벽 앞면 포함), `tile_size: 16`, `view: "low top-down"`, `outline: "lineless"`, `shading: "basic shading"`, `detail: "medium detail"` (tileset 08042210-d9dd-4d06-b641-be485232c543, 바닥 기준 0304d0b5-8614-4e49-aebe-2762e2d0f450, 벽 기준 49f72e32-6adc-408c-b9c2-7610ae6263f9) → `tiles_dungeon_v01.png` + `.json`
   - 구조는 된다: 모서리 값이 바닥·앞면(transition)·벽 윗면 셋이고, 벽 윗면 바로 아래 바닥 꼭짓점을 앞면으로 두면 북쪽 벽에 앞면 한 줄이 그려진다. 방 하나를 조립하면 빠진 조합이 0
   - 색·질감은 틀렸다: 벽 윗면과 바닥이 초록빛 격자무늬(쇠창살·카펫처럼), 바닥 가장자리에 흰 선
2. 큰 오브젝트 5장 (각 1회): `create_map_object` 기본 모드, `view: "low top-down"`, `outline: "single color outline"`, `shading: "medium shading"`, `detail: "medium detail"`. 모두 정렬 문구("seen from the front / straight from the front, … front edge exactly horizontal, edges parallel to the image, not rotated, not isometric")를 넣음
   - 조제대 c (object 10b8d804-03aa-4aa3-889f-c87d07f3d44e, 48×32) → `alchemy_table_v03_c.png`: "a small wooden alchemy workbench seen from the front: a straight rectangular wooden table whose front edge is exactly horizontal, both front legs level and parallel to the image edges, not rotated, not isometric; on top a stone mortar and pestle, a round glass flask of red liquid and two small potion bottles, a bundle of dried herbs; cozy warm colours, no symbols, no letters"
   - 조제대 d (object 488d1fb3-213d-4947-a228-56e9ea9001e2, 48×32) → `alchemy_table_v03_d.png`: "a herbalist's potion-making table seen straight from the front, a plain rectangular wooden table with its front edge exactly horizontal and edges parallel to the image, not rotated, not isometric; on top a glass alembic flask with a curved spout, a mortar and pestle, three small corked bottles in red, amber and yellow, dried herbs hanging from the table edge; cozy warm colours, no symbols, no letters"
   - 성물 제작대 (object 4c83e07f-5365-41c4-ae97-162ff899e597, 48×32) → `relic_bench_v01.png`: "a sturdy relic crafting bench seen straight from the front, a heavy oak workbench with its front edge exactly horizontal and edges parallel to the image, not rotated, not isometric; on top an ivory cloth runner, small gold-leaf tools, a lit candle and a half-finished brass oil lamp; warm candlelight colours; plain wood with no symbols, no emblems, no crosses, no letters"
   - 이단의 제단 (object a8b7fe06-2664-49db-9e54-ea60cb9e737e, 48×48) → `heretic_shrine_v01.png`: "a crude heretic shrine of stacked skulls and bones on a broken flat stone slab, seen from the front with the slab's base edge exactly horizontal, not rotated, not isometric; grey ash and bone colours, a few thin dark violet cracks, patches of dull olive mould, grim and menacing; no symbols, no letters"
   - 던전 입구 (object 6b0336e9-a7ab-4c40-9eb3-656882d197fd, 48×48) → `dungeon_entrance_v01.png`: "a dark dungeon entrance set into the ground, a low arch of rough grey stones over worn stairs leading down into darkness, seen from the front with the arch's base edge exactly horizontal, not rotated, not isometric; ash-grey stones with a little dull olive moss, grim; no symbols, no letters"
   - 결과: 5장 중 4장이 정렬형(1차는 5장 중 1장). 이단의 제단만 받침이 마름모. 성물 제작대 천에 흐린 무늬가 있었고(손질로 지움), 던전 입구는 남색 어둠과 푸른 회색 돌
3. 2차 손질 (무료, 손질 에이전트 아홉. 사람의 결정을 반영)
   - 풀: `tools/art/regrass.py`(이번에 추가)로 풀 초록 8색을 정확히 +15° HLS 색상만 옮긴다(명도·채도 그대로, 다른 색은 그대로). 흙 타일의 풀 쪽 가장자리 6색은 `--soil-edges`. 풀 속 타일 `tiles_grass_base_v02.png`(연보라 점 → 따뜻한 크림)와 변형 `tiles_grass_var_1~4_v02.png`. 병든 올리브와 색상 차 0.8° → 14.4°(CIELAB 0.3° → 8.7°)
   - 흙 `tiles_grass-soil_v03.png`: 고랑 한 줄 대신 칸마다 끊긴 짧은 고랑 2~3개와 부스러기, 채움색 채도를 낮춤(약 #6a4528), 속 타일 변형 `tiles_soil_var_1~2_v01.png`. 물 준 흙 `…_watered.png`: 명도만이 아니라 젖은 얼룩·물기 띠·따뜻한 반짝임으로 구분. 작물 흙더미 색은 이 흙 색에 맞춰 바꿔 쓴다(물 준 칸에서는 물 준 색으로)
   - 오염 땅 `tiles_grass-corruption_v05.png` + `tiles_ash_var_1~3_v02.png`: 닫힌 금(포석처럼 보임)을 끊어 가지 치고 끝나게, 곰팡이를 5~8px 얼룩(#6f8f3a + 테두리 #4b6127)으로, 뼈 돌기 위치를 다르게. §6 측정 통과(measure는 손질 에이전트 기록)
   - 작물 `crops_v03_sheet.png`(줄: 회복·버프·독초, 칸: 0~4단계, 수확, 시듦): 1~4단계 흙더미 외곽선 제거(화분처럼 보이던 것), 버프·독초 줄기는 안쪽 외곽선을 잎의 가장 어두운 색으로(검은 비율 35% 이하), 버프 1단계는 곧은 싹, 독초 4단계·수확물에 3×3 녹 꼬투리, 시든 판은 한 방법(처진 모양, 떨어진 잎, 병든 올리브 + 잿빛). 흙더미 없는 야생 독초 `crop_poison_wild_v01.png`
   - 작은 것 `items_v03_strip.png`(왼쪽부터 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 45, 46, 47, 52, 53번, 끝에 오염 쪽 버섯): 버프 물약 호박색, 독 물약·독 씨앗 봉투 띠를 독초 노랑 + 녹 반점, 구리 줄무늬를 #c06a2e/#df903f/#8c4a22, 덤불을 회복 약초 세이지 + 밝은 열매, 생활 쪽 아이템 하이라이트는 밝기 215 이하(불꽃이 가장 밝게), 아이템마다 16색 안팎, 오염 땅에 놓는 잿빛 버섯 새로
   - 제단 `altar_v04.png`(꺼짐 `_unlit`, 5개 켜짐 `_5lit`): 불꽃 2×4~5px, 심 #fff6dc(밝기 246)로 그림에서 가장 밝은 색, 윗면 돌을 조금 어둡고 따뜻하게
   - 조제대 `alchemy_table_v04.png`: 정렬형 c를 골라 다듬음(d는 상판이 얇게 옆에서 본 듯하고 늘어진 약초가 고추처럼 읽힘). 물약 색을 작물에 맞춤
   - 성물 제작대 `relic_bench_v02.png`: 천의 무늬를 지우고 금 테두리, 상징·문장·십자·글자 없음 확인. 던전 입구 `dungeon_entrance_v02.png`: 남색 어둠 → 따뜻한 검정, 푸른 돌 → 잿빛, 올리브 이끼
   - 이단의 제단 `heretic_shrine_v02.png`: 해골 더미 구도는 두고 받침을 정렬형 깨진 석판으로 다시 그림(잿빛, 1px 보라 금, 올리브 곰팡이, 마른 핏자국)
   - 던전 `tiles_dungeon_v02.png` + 속 타일 변형 `tiles_dungeon_v02_var.png`(바닥 셋, 벽 윗면 둘): 바닥은 어긋난 판석, 벽 윗면은 금 간 바위, 앞면 벽돌은 색만 따뜻하게, 흰 선 → 짙은 그림자, 모서리 짝마다 가장자리 픽셀을 맞춤. 광맥 `ore_vein_{copper,iron}_{a,b}_v01.png`(묶음 48~51번을 벽 윗면 색에 맞춤)
4. 목업 v03: 지상 `stage4_mockup_v03_day.png`·`_1x`, 저녁 `stage4_mockup_v03_eve.png`·`_1x`(제단 둘레 원 안은 밝게, 경계는 디더링, 불꽃·후광은 어두워지지 않는 빛, 오염 땅은 덜 어둡게), 던전 방 `stage4_dungeon_v03.png`·`_1x`. 손질 전후 `stage4_fix2_<묶음>_compare.png`
5. 판정 (검토 에이전트 둘: 에셋별 본 제작 사용 여부, 본 제작 계획)
   - 쓸 수 있음: 풀 v02 속 타일·변형, 흙 v03·물 준 흙·흙 변형, 작물 3종(0~4단계·수확·시듦)과 야생 독초, 씨앗 봉투, 덤불, 버섯(생활·오염 쪽), 이끼 돌, 풀 무더기, 제단 v04(켜짐·꺼짐·5개), 성물 제작대 v02, 던전 입구 v02, 이단의 제단 v02, 던전 타일 v02와 변형
   - 작은 손질 뒤 쓸 수 있음: 오염 땅 v05(뼈·곰팡이가 속 타일 같은 자리에 있어 16px 격자로 보임 → 흩뿌리는 장식으로), 물약(독 물약 반점을 작물 녹색 #c4421c로, 다른 판은 빼도 됨), 광석 아이템(철 아이템과 광맥을 맞춤), 조제대 v04(44색 → 24색 안팎)
   - 다시 할 것: 광맥 v01(벽 위에 붙인 네모판처럼 보이고, 철은 유리·얼음처럼 읽힘)
   - 요령: 속 타일 변형의 같은 자리에 박은 드문 장식(뼈, 곰팡이)은 자주 쓰이면 16px 격자로 보인다 → 장식은 따로 흩뿌린다. 광맥은 벽의 바위 안에 그리고 광석 아이템과 같은 모양·색으로. 손그림 아이템(16색 이하) 옆의 생성 오브젝트(40색 이상)는 색 수를 줄여야 한 손으로 그린 것처럼 보인다. 풀·흙·오염 타일에 같은 regrass 표를 쓰니 옛 초록이 하나도 남지 않았다
   - 본 제작 계획(46회 = 첫 판 32 + 다시 뽑기 여유 14)과 정할 것은 brief §5.7 (R29)

## 4단계 1차 시험 마지막 손질 (2026-10-17, 생성 없음, 무료)

위 판정의 "다시 할 것"과 "작은 손질"을 고쳤다(손질 에이전트 둘).

- 광맥 `tiles_ore_{copper,iron}_{a,b}_v02.png`: 벽 윗면 타일(던전 v02의 바위 윗면)을 그대로 두고 그 바위 2~3개 안에 광석을 박은 16×16 타일. 네모판·테두리 없음, 바깥 1px 테두리는 벽 윗면·변형과 같아 이어진다. 구리는 #8c4a22/#c06a2e/#df903f만, 철은 깎인 면이 있는 덩이(#34302d/#5e5953/#a39d92, 반짝임 #d2cbb8)에 녹 점(#6e3624/#a5552f). 철 아이템도 같은 색으로 바꿈(`items_v04_strip.png`의 25번). 던전 방 `stage4_dungeon_v04.png`·`_1x`
- 물약: 독 물약 23번·47번의 마개 2px를 녹색 #c4421c로(`items_v04_strip.png`, 순서는 v03과 같고 23·25·47번만 바뀜)
- 조제대 `alchemy_table_v05.png`: 44색 → 24색(물약·외곽선 픽셀은 그대로, 나무를 5단으로)
- 오염 장식: 뼈 돌기 `decal_bone_1~3_v01.png`(1~3px, #8c7b66 턱), 곰팡이 `decal_mould_1~3_v01.png`(#6f8f3a 5~7px + #4b6127 테두리). 장식을 뺀 속 타일 `tiles_ash_plain_1~3_v01.png`. 엔진에서 칸에 고정하지 않고 흩뿌린다(금 픽셀에서 1px, 장식끼리 2px, 풀에서 뼈 2px·곰팡이 3px 떨어뜨림)
- 손질 전후 `stage4_fix3_veins_compare.png`, `stage4_fix3_small_compare.png`
- 남은 흠: 철 광맥은 1배에서 구리보다 약하고 반짝임이 뼈 색과 비슷하다(녹 점으로만 갈림). 철·녹 색 6개는 §4 팔레트 밖이라 사람 확인이 필요하다. 광맥은 벽 윗면에만 있고 벽 앞면 판은 없다. 곰팡이 장식은 이전 17px 얼룩보다 작다

## 본 제작 (2026-10-21 밤, PixelLab 35회 사용) + 손질·통합 (무료)

사람이 brief §5.7 "○ 본 제작 (R29)"을 밤사이 진행하도록 승인했다. PixelLab 상한은 모든 에이전트 합계 46회다. 사람이 자는 동안 에이전트 넷이 한 작업 트리(브랜치 `art/stage4-main`)에서 나눠 했고, 질문하지 않았다. ? 항목은 `_candA`/`_candB` 후보를 나란히 두고 고르지 않았다. 모두 채택 후보이고 사람 확인 전이다.

- 나눔: a1 = 흙길 타일, 기본 작업대·모루·공유 창고, 보스 구역 기둥 후보 (상한 16회). a2 = 소품 묶음 둘 (상한 30회). a3 = 손그림 다섯 가지 (0회). a4 = 통합: 작은 손질, 목업, 후보 시트, 이 기록 (0회). 검토 뒤 a5 = 고침 (0회, 아래 "### 5. 검토 뒤 고침")
- **사용: 35회** = a2 20회 + a1 15회. 잔액 1,772 → 1,737이다. a1과 a2가 같은 계정에서 동시에 생성해서, 둘이 적은 잔액 차이 35는 같은 35회다. 통합 때 다시 확인한 잔액도 1,737이다. a1은 타일셋 값을 도구 설명의 최대치 4회로 세어 "최대 16회"로 적었지만, 잔액으로 보면 실제 값은 3회다. 11회는 쓰지 않았다
- 레퍼런스: 흙길 타일셋에 우리 v02 풀 기준 타일 id만 넣었다. 오브젝트와 묶음은 글만 썼다(이미지 레퍼런스 없음). 다른 사람 팩 이미지는 넣지 않았다
- 손질은 모두 스크립트로 했다(무료). 다시 돌리면 바이트까지 같은 파일이 나온다. 통합 때 `tools/art/`로 옮긴 뒤 다시 돌려 확인했다. 단 글자가 든 미리보기(후보 시트, `stage4_a1_preview_v01`, a3 미리보기)는 Windows 글꼴(malgun.ttf 등)을 읽고, 글꼴이 없으면 기본 글꼴로 바뀌어 다른 기기에서는 바이트가 다를 수 있다. 실행은 `uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I <스크립트> …`로 한다
  - `tools/art/stage4_path_objects.py {path|objects|preview}` (a1)
  - `tools/art/stage4_props.py assets/concept/04-env` (a2)
  - `tools/art/stage4_handdrawn.py {all|check}` (a3)
  - `tools/art/stage4_mockup.py {fix|surface|dungeon|candidates|all}` (a4. `dungeon`은 a5가 고침)
- 미리보기 파일 이름의 a1·a2·a3은 위 에이전트 몫을 가리킨다

### 1. 흙길 타일, 기본 작업대·모루·공유 창고, 보스 구역 기둥 후보 (a1, 15회)

1. 풀밭↔흙길 (타일셋 1개, 실제 3회): `create_topdown_tileset`, 1차 시험 풀밭↔일군 흙과 같은 틀 (tileset cace8d41-ecb3-4017-baae-43ad0c60902a, 흙길 기준 타일 dd2191f9-f56b-4103-ad35-f18263d650fb)
   - 설정: `lower_description: "packed dirt footpath of smooth trodden light warm ochre-brown earth, flat and dry, lighter than tilled soil, a few small tan pebbles, cozy"`, `upper_description: "cozy meadow grass in soft warm sage and olive greens with straw-yellow tufts and a few tiny cream and pink flowers, muted earthy colours, cute"`(v02 풀 문구 그대로), `upper_base_tile_id: c1198d1f-4f65-44fc-8b18-75c2c1b42402`(v02 타일셋 fe7bfb85-8339-4e1f-9492-e7755ab300f8의 풀), `transition_description: "a thin ragged grass edge with a few loose dirt crumbs"`, `transition_size: 0.25`, `tile_size: 16`, `view: "low top-down"`, `outline: "lineless"`, `shading: "basic shading"`, `detail: "medium detail"`. 나머지는 기본값이다(text_guidance_scale 8, tile_strength 1, tileset_adherence 100, freedom 500). 결과 16장 → `tiles_grass-path_v01.png` + `.json`(타일 배치. 내려받기 주소는 뺐다)
   - 판정: 풀 타일은 v02와 픽셀까지 같다. 구조는 채택 후보다(풀 가장자리가 들쭉날쭉하고, 흙 쪽에 그늘 턱이 생기고, 모서리 맞춤 16장). 색과 질감은 틀렸다. 흙길이 연한 복숭아·모래색(#f3cda1, 밝기 211)이라 모래밭처럼 읽혔다. 밝은 자갈 점(#fbddb8)은 칸마다 같은 자리에 격자로 찍혔다. 풀 가장자리 이빨은 회색과 보라 기운 회색(#60605f, #4d4950)이었다
   - 손질 → `tiles_grass-path_v02.png` + 흙길 속 타일 변형 `tiles_path_var_1~3_v01.png`(자갈 2·4·5개). 배치는 v01 `.json`을 그대로 쓴다
     1. regrass(풀 8색 +15°)와 delavender(풀 속 타일의 연보라 2px). 풀 속 타일은 `tiles_grass_base_v02.png`와 픽셀까지 같아진다
     2. regrass 표에 없는 풀 가장자리 초록 6색을 같은 규칙(+15° HLS)으로 옮겼다: #8aa568→#7ba568, #7b9762→#6e9762, #6e8260→#668260, #7f8768→#778768, #6b7160→#677160, #cfe38f→#bae38f. 병렬 작업 충돌을 피하려고 `tools/art/regrass.py`는 고치지 않았고, 이 표는 `stage4_path_objects.py`의 `PATH_EDGE_GREENS`에 있다(○ regrass에 PATH_EDGE 표로 합칠 수 있다)
     3. 회색 이빨 2색을 같은 명도의 따뜻한 짙은 초록으로 바꿨다: #60605f→#57734a, #4d4950→#445d37
     4. 흙길 바탕 #f3cda1 → #c8a073. #c8a073·#b8916a·#d2ae84 셋을 작은 맵에서 비교해 골랐다. 일군 흙 #6a4528보다 확실히 밝고 모래가 아니라 흙으로 읽힌다(손으로 고른 색이고 ? 항목은 아니다). 격자 자갈은 지웠다. 그늘 턱 #d6b095→#b78251, 부스러기 #8e7f7e→#946641
     5. 자갈(#d2b692 위 + #b78251 아래, 1~2px)과 부스러기(#946641 1px)를 칸마다 흩뿌렸다(시드 20261021, 바탕 70px당 1개). 결과 27색이고 옛 초록은 0개다
   - 남은 흠: 풀 가장자리 이빨이 짙은 초록 테처럼 진하다(산울타리 같음)
2. 큰 오브젝트 12장: `create_map_object` 기본 모드, 1장 1회. `view: "low top-down"`, `outline: "single color outline"`, `shading: "medium shading"`, `detail: "medium detail"`, 배경 투명
   - 정렬: 1차 시험의 정렬 문구만 쓴 a판 4장은 모두 비스듬했다(작업대 3/4, 모루 윗면 기울어짐, 상자 3/4, 기둥 받침 비스듬). 같은 설명에 **"flat elevation with no side faces visible"**과 "(윗면) only a thin horizontal strip"만 더한 b판은 4장 중 3장이 정렬형이었다(상자만 3/4). 상자는 6장 중 2장만 정렬됐다
   - 기본 작업대 a (object a58d9969-75a7-4074-a3c9-bc6663899cab, 48×32) → `workbench_v01_a.png`: "a simple wooden carpenter's workbench seen straight from the front: a plain rectangular table of rough warm planks whose front edge is exactly horizontal, both front legs level and parallel to the image edges, not rotated, not isometric; on top a wooden mallet, a small hand saw and a few wood offcuts and curled shavings; cozy warm colours, no symbols, no letters" — 탈락: 오른쪽 옆면이 보이는 3/4
   - 기본 작업대 b (object d98faed8-72ac-43b8-a327-95c73d5aff3e, 48×32) → `workbench_v01_b.png`: "a simple wooden carpenter's workbench seen straight from the front, flat elevation with no side faces visible: a plain rectangular table of rough warm planks whose front edge is exactly horizontal, both front legs level and parallel to the image edges, the tabletop only a thin horizontal strip, not rotated, not isometric; on top a wooden mallet, a small hand saw and a few wood offcuts and curled shavings; cozy warm colours, no symbols, no letters" — 정렬형, 채택 후보. 흠: 대팻밥이 금빛 노란 똬리(#f1c54f)라 금덩이처럼 보임, 윗면 위쪽에 외곽선 없음, 35색
     - 손질 → `workbench_v02.png`: 노랑·올리브 계열(55px)을 밝기 순으로 연한 나무 대팻밥 4단(#e2c49c/#caa275/#a47b55/#6e523f)으로, 차가운 회색 1px을 따뜻한 회색으로, 밝기 215 넘는 3px 낮춤, 외곽선 #1a1714(밝기 42 미만 선은 #1a1714로 바꾸고, 바깥 픽셀이 밝으면 바깥에 1px 덧댐), 떨어진 1px 정리, CIELAB 가까운 색 합치기로 20색. 최대 밝기 215
   - 모루 a (object 139e6acb-008f-42c7-8651-6ce5590456d6, 32×32) → `anvil_v01_a.png`: "a sturdy blacksmith's anvil on a squat wooden stump seen straight from the front: the anvil's flat top face and the stump's base edge exactly horizontal, horn pointing left, edges parallel to the image, not rotated, not isometric; dark brown-black iron with a soft warm highlight on the flat top, a pair of tongs leaning on the stump; cozy warm colours, no symbols, no letters" — 탈락: 윗면이 기울어짐, 그루터기 밑에 풀
   - 모루 b (object 280350f0-bad1-4854-8beb-8860af7111d9, 32×32) → `anvil_v01_b.png`: "a sturdy blacksmith's anvil on a squat wooden stump seen straight from the front, flat elevation with no side faces visible: the anvil's flat top face and the stump's base edge exactly horizontal, horn pointing left, edges parallel to the image, the top face only a thin horizontal strip, not rotated, not isometric; dark brown-black iron with a soft warm highlight on the flat top, a pair of tongs leaning on the stump; cozy warm colours, no symbols, no letters" — 정렬형(뿔 왼쪽, 오른쪽에 집게), 채택 후보. 흠: 쇠가 남보라 회색(#353245, #1b1725 등), 윗면이 달군 쇠처럼 주황, 뿔에 분홍 반짝임, 그루터기가 붉은 주황(채도 0.5~0.66), 밑동에 풀과 보라 회색 흙 조각
     - 손질 → `anvil_v02.png`: 풀 8px·보라 흙 28px·떨어진 조각 3px 지움. 모루·집게의 주황·분홍은 광석 철과 같은 따뜻한 강철 회색으로(색상 32°, 채도 0.07, 최대 밝기 205). 몸통의 남보라 회색·근흑은 따뜻한 철 회색으로 올려(색상 26°, 밝기 22 + 0.9×원래) #1a1714 외곽선 안에서 형태가 보이게 했다. 그루터기는 색상 24°·채도 ×0.72의 차분한 갈색. 외곽선 #1a1714, 20색
   - 공유 창고(상자) a (object 9baea8d6-ceba-46df-8f1f-2433ea3bdfba, 32×32) → `storage_chest_v01_a.png`: "a large wooden storage chest seen straight from the front: a sturdy rectangular chest of warm oak planks with dark iron bands and a small brass lock plate, lid closed, its front face and bottom edge exactly horizontal and edges parallel to the image, not rotated, not isometric; cozy warm colours, no symbols, no letters" — 탈락: 3/4, 두꺼운 회색 테
   - 상자 b (object b4bfd7cd-8472-487e-9d45-02ab557d6b82, 32×32) → `storage_chest_v01_b.png`: a 문구의 "seen straight from the front" 뒤에 ", flat elevation with no side faces visible"을, "parallel to the image" 뒤에 ", the lid top only a thin horizontal strip"을 더함 — 탈락: 아이소메트릭에 가까운 3/4, 보라 회색 테
   - 상자 c (object 414c05f9-1443-4b6f-9eb9-312a8979a607, 48×32) → `storage_chest_v01_c.png`: "a wide wooden storage chest drawn as a symmetrical straight front view: its front face is a flat rectangle of warm oak planks with two dark iron bands and a small brass lock plate in the centre, the closed lid only a thin horizontal strip above it, bottom edge exactly horizontal, left and right sides hidden, edges parallel to the image, not rotated, not isometric, no perspective; cozy warm colours, no symbols, no letters" — 탈락: 그림은 가장 좋지만 왼쪽 옆면이 보이는 원근 3/4
   - 상자 d (object cc3ce78f-6888-4773-898e-a8bb2c1b7b22, 48×32) → `storage_chest_v01_d.png`: "a shared village storage corner drawn as a straight front view: a closed wooden chest with iron bands in the middle, a stacked pair of plain wooden crates on its left and a tied burlap sack on its right, all standing on one level ground line exactly horizontal, front faces flat and parallel to the image, sides hidden, not rotated, not isometric, no perspective; cozy warm colours, no symbols, no letters" — 정렬형이지만 탈락: 셋이 작고(상자 15×11px), 가운데 자물쇠가 금빛 + 모양이라 십자로 읽힌다(신앙 상징 결정 전 금지), 푸른 띠
   - 상자 e (object 84307a76-07ab-41e4-8b4b-acfd55fd5722, 32×32) → `storage_chest_v01_e.png`: "a closed wooden storage chest drawn as a straight front view, standing on a level ground line exactly horizontal: its front face is a flat rectangle parallel to the image, sides hidden, the lid only a thin strip on top, not rotated, not isometric, no perspective; warm oak planks with two dark iron bands and a plain square brass lock plate; cozy warm colours, no symbols, no letters" — 탈락: 돌아간 3/4
   - 상자 f (object bf1f2fa3-fe32-424d-8cb0-e72fbc06b669, 48×32) → `storage_chest_v01_f.png`: e 문구 앞을 "a long low closed wooden storage chest filling the width of the image, drawn as a straight front view, …"로 바꿈(나머지 같음) — 정렬형, 채택 후보(41×18px, 쇠 띠 둘, 민무늬 네모 놋쇠 자물쇠, 13색)
     - 손질 → `storage_chest_v02.png`: 무채색 쇠 띠(#312f2d/#51504e/#7d7d7d, 182px)를 같은 밝기의 따뜻한 회색(색상 28°, 채도 0.08)으로, 외곽선 #1a1714(104px 바꿈, 6px 덧댐). 14색, 최대 밝기 215(자물쇠 #f3d983)
   - 보스 구역의 광부 지형 요소 **candA = 금 간 받침 기둥**: game-concept §12의 ? 항목에 대한 문서 안("광부가 부수면 잔해가 떨어지는 금 간 받침 기둥, 상태 4단계")을 그린 후보다. 결정이 아니고, 다른 안(candB)은 만들지 않았다
     - a (object 0b7d5814-70fb-4ef9-9076-f36b46c89bac, 32×64) → `boss_pillar_candA_v01_a.png`: "a cracked stone support pillar in a dark dungeon seen straight from the front: a thick square column of rough warm dark brown stone blocks on a wider stepped base, its base edge exactly horizontal and its sides vertical and parallel to the image, not rotated, not isometric; deep cracks running down the blocks, a few chips and pebbles of rubble at its foot, dusty and grim; warm ash-brown stone, no blue, no symbols, no letters" — 탈락: 받침과 머리가 비스듬, 분홍빛 모래색
     - b (object 02904031-fa10-4f54-849c-899725f80508, 32×64) → `boss_pillar_candA_v01_b.png`: a 문구의 "seen straight from the front" 뒤에 ", flat elevation with no side faces visible"을 더함 — 정렬형(머리돌, 금 간 돌 기둥, 넓은 받침, 발치 잔해). 흠: 밝은 모래색(최대 밝기 211)이라 던전에서 혼자 뜸, 금이 남색(#060422), 바깥 외곽선 없음
     - 손질 → `boss_pillar_candA_v02.png`: 남색 금 106px → #1a1714. 돌 601px를 밝기 순서대로 던전 타일 계열 따뜻한 회색(색상 31°, 채도 0.15, 밝기 45~211 → 58~172)으로 다시 칠함(바닥 #6b5e4f보다 조금 밝게). 금 아래·오른쪽 1px에 밝은 턱(+22). 다시 칠하자 원래 금이 이음매처럼 읽혀서 오른쪽 가운데 블록에 금 하나를 손으로 그었다(14px 지그재그 + 턱). 바깥 외곽선 #1a1714, 14색
     - 남은 흠: 금과 이음매가 같은 #1a1714라 "금 간" 느낌이 약하다. 상태 4단계(멀쩡 → 금 → 크게 금·조각 떨어짐 → 무너진 잔해)는 이 안이 정해지면 이 그림에서 손으로 만든다(생성 불필요). 꼭대기를 천장에 닿게 할지는 정하지 않았다
3. 미리보기: `stage4_a1_preview_v01.png` (4배. 풀·흙길·일군 흙 위에 제단·창고·작업대·모루·성물 제작대, 던전 바닥 위 기둥, 아래는 원본 → 손질판 짝). §6 측정: 차가운 색 0%, 보라 0.00%

### 2. 소품 묶음 둘 (a2, 20회)

위협 쪽 소품·건설 조명·던전 장식 묶음(size 32)과 채집물·작은 위협 소품·재료 묶음(size 16). 두 묶음 모두 대부분 성공해서 다시 뽑기 여유(10회)는 쓰지 않았다.

- 도구: `create_1_direction_object`, `view: "top-down"`(이 도구는 top-down·sidescroller만 받는다). 값은 PixelLab `search_help` 답과 두 응답 모두 size 16·32에서 10회(33~42는 15회)라 size 32를 썼다(같은 64칸). `style_images`·`palette`·`max_colors`는 넣지 않았다. 이 도구의 레퍼런스는 `style_images`뿐이고 그 크기가 출력 크기를 정해서, 큰 장면 그림인 북극성은 맞지 않는다
- 64칸을 모두 구체적인 물건으로 채우고 물건마다 2~3 변형을 두었다(1차 시험 권고)
- 내려받기: 생성 직후 review 상태의 64칸을 모두 받아 원본 시트로 붙였다(`props32_v01_sheet.png` 256×256, `items16_v01_sheet.png` 128×128, 8×8칸, 칸 번호 = 줄 × 8 + 칸 = 아래 표의 #). 원본은 이 시트에 손실 없이 다 있어서 물건마다 `_v01`을 자르지 않았다
- 고르기: `select_object_frames`로 남길 칸을 완료 object로 올렸다(태그 `a2-stage4-props32`, `a2-stage4-items16`). 고르지 않은 칸(묶음 1의 24·46·47·63, 묶음 2의 19·29·30)은 review 상태로 남아 있다(지우려면 `dismiss_review`)

묶음 1: size 32 (review object 9d2ec005-4ec2-436b-bd39-c9ac8f74150a, job 88d04f95-b6bd-4c72-b349-c9b77e6dc8a1, `name: "a2 stage4 props size32"`). 64칸 중 60칸을 남겼다. 칸 0~21 위협, 22~35 건설 조명(불 없는 몸통), 36~63 던전 장식
- `description`: "top-down RPG pixel art prop for a dark medieval fantasy farming game, one object centred with empty space around it, seen straight from the front and a little from above, its base edge exactly horizontal, not rotated, not isometric, 1px dark warm brown-black outline, 2-3 shade levels per material, warm brown-black shadows with no blue or navy, no text, no letters, no symbols" (1차 시험 연장의 정렬 문구를 공통 설명에 넣었고, 상자류 칸에도 다시 썼다)

| # | 설명 (item_descriptions, 그대로) | 판정 | 손질 파일 | object id |
|---|---|---|---|---|
| 0 | pile of old bleached bones with one cracked skull, a low and wide heap on the ground, ash and bone colours, grim | 좋음. 흰 점 2개 제거 | `prop_bone_pile_a_v02.png` | 452e8745-0393-424b-a52a-d41888ac16ee |
| 1 | small heap of scattered ribs, long bones and a jawbone lying flat on the ground, dull bone and ash colours, grim | 갈비뼈 더미, 바쁜 편 | `prop_bone_pile_b_v02.png` | b9c4e44a-0cb8-430b-b784-dc009adbdec6 |
| 2 | low mound of ash with a few charred bones and a skull poking out, warm ash colours, grim, no blue | "재" 더미가 모래색으로 나옴 → 잿빛으로 바꿈 | `prop_bone_pile_c_v02.png` | 2d5f84f1-376c-4488-9a36-6dcff3c67622 |
| 3 | broken heretic idol: a crude faceless stone figure snapped off at the chest, standing on a small square base, ash-grey stone with thin dark violet cracks, no carvings, grim | 좋음. 금은 가는 보라로 | `prop_idol_broken_a_v02.png` | 01fa40aa-66f1-4a82-8259-9548394616fd |
| 4 | toppled broken idol: the faceless head and shoulders of a crude stone statue lying on its side among stone chips, ash-grey stone with thin dark violet cracks, grim | 좋음 | `prop_idol_broken_b_v02.png` | 2050311d-6e68-4ac3-b05b-87db99b1d211 |
| 5 | tall broken stone idol, a faceless hooded figure missing one arm, weathered ash-grey stone with patches of dull olive mould, no carvings, grim | 좋음(두건 쓴 얼굴 없는 상). 올리브 곰팡이는 안 나옴 | `prop_idol_broken_c_v02.png` | dedb472c-00a2-4e89-a41e-08f7507e9e76 |
| 6 | a rough standing ritual stone, a tall narrow menhir of ash-grey stone with one thin dark violet crack and dull olive mould at its base, no carvings, grim | 좋음. 밑동 곰팡이 대신 갈색 흙 얼룩(둠) | `prop_ritual_stone_a_v02.png` | a9a6b8d8-e9a5-494b-a293-a7a8a1f054c6 |
| 7 | a pair of short rough ritual standing stones side by side, ash-grey with dried dark red stains, no carvings, grim | 좋음 | `prop_ritual_stone_b_v02.png` | 708ebcb5-b4f0-4310-8ea9-3668b3e8e028 |
| 8 | a squat ritual stone with a hollow bowl on top holding dried dark blood, ash-grey stone, no carvings, grim | 피 고인 돌 사발, 화분처럼도 보임 | `prop_ritual_stone_c_v02.png` | faf6c411-4f8b-4b77-92c8-0152aa019551 |
| 9 | an unlit dark iron brazier: a wide shallow bowl on three bent legs full of cold black ash and charred bones, rusty dark iron, no fire, no flame, grim | 좋음(불 없음) | `prop_brazier_dark_a_v02.png` | 6df72ade-33d7-4dd8-8cf0-aadc8f1c2b55 |
| 10 | an unlit tall heretic brazier: a spiked iron bowl of cold ash on a single iron pole, rusty black iron, no fire, no flame, grim | 좋음(불 없음) | `prop_brazier_dark_b_v02.png` | d185ed1a-b225-4da2-ab40-a9f7350ab7e7 |
| 11 | an unlit squat stone fire bowl full of cold ash and a few bones, ash-grey stone, no fire, no flame, grim | 좋음(불 없음) | `prop_brazier_dark_c_v02.png` | 205c322c-e768-4a0f-9bd6-793c7f4cf6c3 |
| 12 | a cluster of three melted black wax candle stubs on a small skull, unlit, no flame, grim | 좋음(불 없음) | `prop_candles_black_a_v02.png` | eccc6b32-a814-4c81-961c-1c868d03e4b9 |
| 13 | a cluster of tall and short black wax candles melted together on the ground, unlit, no flame, grim | 좋음(불 없음) | `prop_candles_black_b_v02.png` | a30e0b0c-220e-4ceb-82f1-96ad654f1f39 |
| 14 | a cracked stone offering bowl with dried dark red stains and a few small bones, ash-grey stone, grim | 좋음 | `prop_offering_bowl_v02.png` | f856ee94-bef8-4290-ae6d-548ae221293b |
| 15 | a dead thorny bramble of ash-grey twigs with a patch of dull olive mould, low and wide, grim | 바쁜 편, 밑에 갈색 흙 얼룩(둠) | `prop_bramble_dead_a_v02.png` | 214ce0c4-d5b7-4b8c-9481-23d6e575a11e |
| 16 | a withered dead thorn bush with bare grey-brown twisted branches, grim | 좋음 | `prop_bramble_dead_b_v02.png` | 0247d21a-e59b-49e9-b41f-f2b3ae689c0e |
| 17 | a skull mounted on a rough wooden stake driven into the ground, bone and dark wood, grim | 좋음 | `prop_skull_stake_v02.png` | 30f41f1a-7b91-4f91-82d0-a5393855f822 |
| 18 | a crooked wooden stake with tattered dark rags and a dangling bone, no symbols, grim | 좋음 | `prop_rag_stake_v02.png` | c187ee93-6d92-4b0c-8bea-4bfe23e67c66 |
| 19 | a small cage of rusty iron bars with old bones inside, grim | 좋음 | `prop_bone_cage_v02.png` | 09baa729-9e92-4337-ba6a-6b32c6a651be |
| 20 | a small heap of cracked skulls stacked in a pyramid, ash and bone colours, grim | 좋음 | `prop_skull_pile_v02.png` | 615d6df3-b405-4542-b76b-41e3860005ba |
| 21 | a corrupted boulder of ash-grey stone split by thin dark violet veins with dull olive mould, grim | 좋음. 보라 맥이 #3b1f4d로 읽힘 | `prop_boulder_corrupt_v02.png` | 5a1d72fb-713a-43ee-aefb-05af267e4532 |
| 22 | an unlit wall torch: a wooden torch with a charred cloth-wrapped tip held in a dark iron wall bracket, seen from the front, no flame, no fire, cozy warm wood colours | 좋음. 천 감은 끝이 황갈색(불 아님) | `prop_wall_torch_a_v02.png` | ae6ae041-f0fe-4687-b282-ab899f5d3b2a |
| 23 | an unlit wall torch in a simple curved iron bracket plate, wooden handle with a blackened tip, no flame, no fire | 좋음(그은 끝) | `prop_wall_torch_b_v02.png` | ba2917bd-e740-4bb9-b0f5-05fe1ffd6ac9 |
| 24 | an unlit wall torch: a short stick wrapped in tarred rope in a ring-shaped iron holder with a small back plate, no flame, no fire | 탈락: 밧줄 감은 횃불이 나선으로 읽히지 않음 | — | — |
| 25 | an unlit lantern post: a straight wooden post with a short crossarm and a small iron lantern hanging from it, the lantern glass empty and dark, no flame, no light, cozy warm wood | 좋음. 켜진 유리 → 꺼진 유리 | `prop_lantern_post_a_v02.png` | 64d703e7-04ed-426b-9f3b-946491943313 |
| 26 | an unlit lantern post: a dark iron pole with a curled hook at the top holding a square iron lantern, empty dark glass, no flame, no light | 좋음. 켜진 유리 → 꺼진 유리, 발밑 푸른 점 제거 | `prop_lantern_post_b_v02.png` | 5eee75ee-4008-4156-b80e-4b02ba162858 |
| 27 | an unlit lamp post: a short square stone base with a wooden pole and a small lantern on top, empty dark glass, no flame, no light | 좋음. 켜진 유리 → 꺼진 유리 | `prop_lantern_post_c_v02.png` | 28088a65-cd05-4099-90e8-92b25ab0ffa9 |
| 28 | an unlit standing candle stand: a tall wrought-iron floor candelabrum on three feet with one thick ivory candle on top, no flame, cozy warm | 좋음(심지만) | `prop_candle_stand_a_v02.png` | c285f17c-4589-4646-a91a-19a246b4e3df |
| 29 | an unlit standing candle stand: a tall brass floor candlestick with a wide drip tray and one thick ivory candle, no flame | 좋음(심지만) | `prop_candle_stand_b_v02.png` | 2f2e8ca3-8ca0-4f5e-8772-771e69e61f67 |
| 30 | an unlit three-arm standing candelabrum of dark iron on a tripod base with three ivory candles, no flame | 좋음(심지만) | `prop_candle_stand_c_v02.png` | 2160e5a4-7ddd-437b-831e-83728bb09749 |
| 31 | an unlit small iron lantern with a ring handle standing on the ground, empty dark glass, no flame | 좋음(유리 어두움) | `prop_lantern_ground_v02.png` | bd2fe0f4-1393-4def-9dea-67088b62bb0b |
| 32 | an unlit hanging lantern on a short iron wall hook, empty dark glass, no flame | 좋음. 흰 유리(켜짐) → 꺼진 유리 | `prop_lantern_wall_v02.png` | 34f428e6-439b-4fea-8be0-411775f36306 |
| 33 | an unlit wall sconce: a small iron candle holder plate with one ivory candle, no flame | 좋음(심지만) | `prop_wall_sconce_v02.png` | cac5436b-f0f4-41f5-83c0-fb4b12b20b34 |
| 34 | an unlit iron fire basket on a tall stand holding fresh split logs, clean and well kept, cozy warm wood, no fire, no flame | 좋음. 통나무 끝 주황이 잉걸불처럼 보일 수 있음 | `prop_fire_basket_v02.png` | 512b64f0-0bb2-4f54-93ae-824dfcf2db4d |
| 35 | an unlit round campfire ring of stones with neatly stacked fresh logs in the middle, cozy, no fire, no flame | 좋음(둥근 돌 화덕, 불 없음) | `prop_campfire_ring_v02.png` | 61efcca1-057f-42ac-88f5-b805e06aa038 |
| 36 | a small heap of broken rock rubble and dust, warm grey-brown stone chunks, low and wide | 좋음 | `prop_rubble_a_v02.png` | 9b603d6c-127b-4f63-96e1-e11f63c323b5 |
| 37 | a pile of fallen stone bricks and rubble, warm grey-brown, low | 좋음 | `prop_rubble_b_v02.png` | ff2fe46d-53f7-42e7-8b91-65a183eb2923 |
| 38 | scattered rock rubble with a few larger broken stones and pebbles, warm brownish grey, low and flat | 좋음 | `prop_rubble_c_v02.png` | 6eef1212-a02b-41c1-80b2-6b5382b566c5 |
| 39 | a cracked stone pillar stub: a short broken round column with a jagged broken top, warm grey-brown stone, base edge horizontal | 좋음 | `prop_pillar_stub_a_v02.png` | d6ea7401-d1d4-4b7f-8e26-5cd4eafe2223 |
| 40 | a short broken square stone pillar with a crumbled top and a chunk lying beside it, warm grey-brown stone | 좋음 | `prop_pillar_stub_b_v02.png` | 5d25de31-9da7-4c14-bbce-274da29a5c01 |
| 41 | a broken stone column base with a few toppled drum segments next to it, weathered warm grey-brown stone | 좋음 | `prop_pillar_stub_c_v02.png` | df9135a0-0d4d-4154-b27a-5f17c646709f |
| 42 | a coil of heavy rusty iron chain lying on the floor, dark rusty iron | 좋음 | `prop_chain_a_v02.png` | 5e7b8c59-68d2-49e7-9d91-df8f9fbfd2f2 |
| 43 | rusty iron chains with an open shackle hanging from an iron ring on a short piece of stone wall, seen from the front | 좋음 | `prop_chain_b_v02.png` | 498fb625-7047-4077-8cc5-b13ccc5444c5 |
| 44 | a long rusty chain lying in a loose S curve on the floor with a broken shackle at one end | 좋음 | `prop_chain_c_v02.png` | 3deb0fb6-eed0-44c7-ba7b-c868fdc2fb41 |
| 45 | a sturdy wooden crate with dark iron corner brackets, seen from the front, front edge exactly horizontal, warm brown wood | 좋음(정면 정렬) | `prop_crate_a_v02.png` | 1d357612-e45b-4f1a-9fe7-3d17267be8d8 |
| 46 | an old wooden crate with a cracked plank and a loose lid, seen from the front, front edge exactly horizontal, weathered brown wood | 탈락: 3/4로 돌아간 상자(정렬 아님) | — | — |
| 47 | two wooden crates stacked, the smaller one on top, seen from the front, front edges horizontal, warm brown wood | 탈락: 겹친 상자가 3/4로 돌아감 | — | — |
| 48 | an old wooden barrel with dark iron hoops standing upright, seen from the front, warm brown wood | 좋음 | `prop_barrel_a_v02.png` | 8f2440de-10e4-45cb-bfde-41de01ec38e7 |
| 49 | a wooden barrel with a closed lid and rusty hoops and a little dust at its base, seen from the front | 좋음 | `prop_barrel_b_v02.png` | 758a4c5d-81f7-4607-9bc3-1f0d95fa640a |
| 50 | a small wooden keg standing upright with iron hoops, seen from the front | 좋음 | `prop_barrel_c_v02.png` | 52ba74d0-a8f7-482d-839f-fb79df6a97c5 |
| 51 | a wooden barrel tipped over on its side, seen from the front, warm brown wood with dark iron hoops | 후보: 누운 통이 비스듬함(둥근 물체라 둠) | `prop_barrel_tipped_v02.png` | 955e9ff1-cf73-4149-ad63-c5341c546e7e |
| 52 | a smashed wooden crate: broken planks and splinters in a heap, warm brown wood | 후보: 부서진 상자가 약간 비스듬함 | `prop_crate_smashed_v02.png` | a08e5796-f4c8-4037-a611-34d4b62cd1da |
| 53 | a smashed barrel: broken staves and a loose iron hoop in a heap | 좋음. 가운데 붉은 점(피처럼 보일 수 있음) → 통합 손질 `prop_barrel_smashed_v03.png` | `prop_barrel_smashed_v02.png` | 4c768a14-59ab-4f3f-be06-ef71bc9f99bd |
| 54 | a burlap sack of goods tied at the top, slumped, warm tan cloth | 좋음 | `prop_sack_a_v02.png` | 9b288997-1aea-440a-b5e1-bbcaf8b1594a |
| 55 | two burlap sacks leaning together, warm tan cloth | 좋음 | `prop_sack_b_v02.png` | 17f10194-30b3-4934-9e5a-656beea17976 |
| 56 | a wooden mine support frame: two upright posts with a crossbeam, seen from the front, rough brown timber | 좋음(정면 정렬) | `prop_mine_frame_v02.png` | 29106b2e-e1a0-4c62-a97e-4fd5b3dc830f |
| 57 | a broken wooden support beam leaning on a heap of rubble | 좋음 | `prop_beam_broken_v02.png` | 6ad767de-eb55-48dc-a569-6202c427a558 |
| 58 | a rough pointed cave stalagmite of warm grey-brown rock standing on the floor | 좋음 | `prop_stalagmite_a_v02.png` | 1486fa54-1164-46fe-8d54-7adb5a252709 |
| 59 | a pair of short cave stalagmites of warm brownish grey rock | 좋음 | `prop_stalagmite_b_v02.png` | e277cb56-a477-4841-b3de-c2e79e83398f |
| 60 | a large cobweb spread between two points, pale dusty beige threads | 좋음(외곽선 없는 실 그림이라 외곽선 손질 제외) | `prop_cobweb_v02.png` | 879d6272-9243-4afb-af40-1f20f973d7dd |
| 61 | a small heap of broken pottery shards beside a cracked clay jar, warm terracotta | 좋음 | `prop_pottery_broken_v02.png` | c8bd1fcd-4d69-49c1-ab56-6b57fc5f306f |
| 62 | a tall cracked clay storage jar, warm terracotta, seen from the front | 좋음 | `prop_jar_clay_v02.png` | 60e27027-e3ca-450b-84a0-df9ae98b72cd |
| 63 | a weathered square stone block with a crack, seen from the front, front edge exactly horizontal, warm grey-brown stone | 탈락: 위에서 본 납작한 판(바닥 타일처럼 읽힘) | — | — |

묶음 2: size 16 (review object 7ba4e4b2-eefd-4ed3-ab11-864df6a5c89b, job 9b62221e-9656-411f-8dd7-6cf9cf89c1ca, `name: "a2 stage4 small items size16"`). 64칸 중 61칸을 남겼다. 칸 0~19 채집물, 20~35 작은 위협 소품, 36~60 재료, 61~63 건설 재료 덤
- `description`: 1차 시험 묶음과 같은 "cozy farming game pixel art item, small and centred, 1px dark warm brown outline, 2-3 shade levels per material, soft warm muted earthy colours, no text, no letters"

| # | 설명 (item_descriptions, 그대로) | 판정 | 손질 파일 | object id |
|---|---|---|---|---|
| 0 | a small loose rock, warm grey-brown stone with a light top edge | 좋음 | `item_stone_a_v02.png` | c18b684a-bc57-42e7-a8d3-017ec01fd3fe |
| 1 | two small round pebbles side by side, warm brownish grey | 좋음 | `item_stone_b_v02.png` | 28a3636e-6251-4987-a205-df720d6d714e |
| 2 | a rough chunk of stone with sharp edges, warm grey-brown | 좋음 | `item_stone_c_v02.png` | 130b21f1-a7f8-4a63-b48a-e469a9cacab3 |
| 3 | a small rock with a patch of fresh green moss on top | 좋음(이끼는 작물 초록으로) | `item_stone_mossy_v02.png` | d24337b4-e63a-4c57-977d-9ae77f6c673c |
| 4 | a few fallen twigs lying loosely together, warm brown wood | 좋음 | `item_sticks_a_v02.png` | 253b2d2d-f4d2-4276-8c96-78179ba51f76 |
| 5 | a single forked wooden stick, warm brown | 좋음 | `item_sticks_b_v02.png` | 09aa9bfa-e249-4f60-9ce0-e8d4d48ed08d |
| 6 | a small bundle of sticks tied with twine | 나뭇단이 장작처럼도 읽힘 | `item_sticks_c_v02.png` | 55132edd-cfc2-4d65-b92d-b8b295d6e38e |
| 7 | wild healing herb plant growing from the ground, round soft green leaves and a few small red berries, no pot, no soil mound | 좋음(회복 약초와 같은 초록·빨강) | `item_wild_healing_v02.png` | 1db54696-9bed-4826-a606-cc06ebec5ea8 |
| 8 | wild buff herb plant growing from the ground, slender green stems with small amber-orange flowers, no pot | 좋음(호박색 꽃) | `item_wild_buff_v02.png` | e2b9c26d-2b16-480a-8840-27f7b7149ce2 |
| 9 | wild poison weed growing from the ground, jagged mustard-yellow leaves with tiny rust-red spotted pods, no purple, no pot | 겨자색 잎. 녹 꼬투리는 거의 없음 | `item_wild_poison_v02.png` | 1111645b-db44-4783-a4ef-dbaaaf542d73 |
| 10 | a wild herb clump with fresh green leaves and tiny white flowers | 흰 꽃은 안 나옴, 초록 덤불 | `item_wild_herb_clump_v02.png` | e72be1f2-5596-4216-8c88-11dce80b7bf3 |
| 11 | a picked sprig of healing herb: a short stem with round green leaves and red berries | 좋음 | `item_sprig_healing_v02.png` | 35355681-6ecd-459f-b63f-270b03b3cdee |
| 12 | a picked sprig of buff herb: slender stems with amber-orange flowers tied with string | 좋음 | `item_sprig_buff_v02.png` | 15971333-9775-4d4d-810f-562135b46436 |
| 13 | a picked sprig of poison weed: jagged mustard-yellow leaves with a rust-red pod | 작은 녹 꼬투리 | `item_sprig_poison_v02.png` | a3990eab-1c54-4943-a675-0d6cae8b64c1 |
| 14 | a cluster of small cream-capped forest mushrooms | 좋음 | `item_mushroom_a_v02.png` | 1967cde2-e1c5-4e45-94b9-444b4996dbda |
| 15 | a single plump brown-capped mushroom | 좋음 | `item_mushroom_b_v02.png` | e721c9b8-62c2-408d-ba15-592917c5007b |
| 16 | a pair of small orange-brown mushrooms with cream spots | 좋음 | `item_mushroom_c_v02.png` | 55ed3ab5-ed82-4738-adc1-1bfc014dd2c8 |
| 17 | a tall thin pale tan mushroom with a wide cap | 좋음 | `item_mushroom_d_v02.png` | 9002f96d-03c3-47c1-8ddc-94d3d767fac7 |
| 18 | a sickly ash-grey mushroom cluster with dull olive spots, grim | 좋음(오염 쪽) | `item_mushroom_ash_v02.png` | eb0de9ed-5333-4a7a-938e-20b4abe45ca0 |
| 19 | a strip of fallen bark and two small twigs, warm brown | 탈락: 나무껍질이 판자처럼 읽힘(47과 겹침) | — | — |
| 20 | a small skull lying on the ground, dull bone, grim | 좋음 | `item_skull_small_a_v02.png` | 562d10b3-bd93-4a6d-afa7-be427739e23d |
| 21 | a small cracked skull with a missing jaw, ash-grey bone, grim | 좋음(푸른 회색 → 따뜻한 회색) | `item_skull_small_b_v02.png` | aa2e5dce-1211-4e0b-85a3-33d25eade048 |
| 22 | two small scattered bones and a tooth, dull bone, grim | 좋음 | `item_bones_small_a_v02.png` | 34935482-0e08-4a95-9572-391bf93664ff |
| 23 | a broken rib bone fragment, ash-grey bone, grim | 좋음 | `item_bones_small_b_v02.png` | cf1a01e3-784f-44c2-ba60-665aed1ba34b |
| 24 | a melted black wax candle stub, unlit, no flame, grim | 약함: 어두운 바닥에서 묻힘 | `item_candle_black_a_v02.png` | 9a8439ef-319d-43c4-9716-96f51df05b0b |
| 25 | two short black wax candle stubs melted together, unlit, no flame, grim | 약함: 어두운 바닥에서 묻힘 | `item_candle_black_b_v02.png` | 652c6db4-5078-4f6f-a65d-191fd345ed0e |
| 26 | a small ash-grey stone with a thin dark violet crack, grim | 푸른 보라 돌 → 잿빛 돌 + 보라 금 1줄 | `item_stone_veined_v02.png` | 571e42d9-9244-429a-9f79-f43f06c994f1 |
| 27 | a small cracked ash-grey rock with dull olive mould, grim | 좋음 | `item_stone_mould_v02.png` | 0bc0ee91-f46a-4438-afd5-5224816d0d6c |
| 28 | a clump of dull olive mould with a darker rim, grim | 둥지처럼도 보임 | `item_mould_clump_v02.png` | 1f61b344-eb77-4704-ae11-3b55823cafc0 |
| 29 | a rusty iron spike stuck in the ground, grim | 탈락: 쇠꼬챙이가 갈고리·곡괭이로 읽힘 | — | — |
| 30 | a rusty bent nail and a broken shackle ring, grim | 탈락: 못·족쇄 고리가 구불한 선으로만 읽힘 | — | — |
| 31 | a corrupted thorn twig, ash-grey with dull olive mould spots, grim | 좋음 | `item_thorn_twig_v02.png` | 066e1f2f-6f72-4e3f-a879-f9626547c442 |
| 32 | a tattered dark rag with dried dark red stains, grim | 좋음 | `item_rag_bloody_v02.png` | 8996de6c-b153-4a16-a23f-a4833f417291 |
| 33 | a crude bone charm hanging from dark twine, no symbols, grim | 어두운 깃발처럼도 보임 | `item_bone_charm_v02.png` | 10e743a5-78ce-4c9c-9e64-87824262eae0 |
| 34 | a small heap of ash with a charred bone, warm ash colours, grim, no blue | 좋음(푸른 회색 → 따뜻한 재) | `item_ash_heap_v02.png` | 2c9b503f-e3ed-409a-8e66-319dcd8055e1 |
| 35 | a cracked clay offering cup with a dried dark red stain, grim | 주의: 굽 달린 잔이라 성배처럼 읽힐 수 있음(신앙 상징 결정 전) → 통합 손질 `item_offering_cup_v03.png`(굽 없는 잔) | `item_offering_cup_v02.png` | cc87139b-4a5c-4683-ab20-b047ca903bac |
| 36 | copper ore chunk: rough warm brown rock with bright orange copper streaks | 좋음 | `item_ore_copper_a_v02.png` | f5876336-33ac-46a3-8daf-1fa161cb68f9 |
| 37 | copper ore nugget: lumpy orange-brown copper with darker brown rock | 좋음 | `item_ore_copper_b_v02.png` | 27547824-0d9c-43ba-9780-ee8e45388bc7 |
| 38 | a small pile of copper ore pebbles, orange and brown | 좋음 | `item_ore_copper_c_v02.png` | 5e3b8b08-d474-40fb-9229-a4e552bd3cc0 |
| 39 | iron ore chunk: dark warm grey rock with rust-red spots and a few dull silver flecks, no blue | 좋음 | `item_ore_iron_a_v02.png` | ddfb5003-1837-4f79-a528-b414a20d8af4 |
| 40 | iron ore nugget: a faceted dark iron lump with rust-red patches, no blue | 용암 같던 주황 → 녹 반점 | `item_ore_iron_b_v02.png` | 74dff024-6a8d-4e47-b7bf-aeb6940ea1d8 |
| 41 | a small pile of iron ore pebbles, dark warm grey with rust spots, no blue | 약함: 어두운 자갈 | `item_ore_iron_c_v02.png` | e74f2f7f-5007-4678-9c0a-0d9973303442 |
| 42 | a copper ingot, a trapezoid bar of shiny orange copper | 좋음 | `item_ingot_copper_a_v02.png` | d0aa31e4-d655-4cd5-b9d4-ada7e0697f65 |
| 43 | two stacked copper ingots, orange copper | 좋음 | `item_ingot_copper_b_v02.png` | e088f9ef-dc32-4adc-9aaf-125046549645 |
| 44 | an iron ingot, a trapezoid bar of dark warm grey iron with a light top edge, no blue | 좋음 | `item_ingot_iron_a_v02.png` | 5bb1d4af-3661-417a-8823-c42a87ef3cc5 |
| 45 | two stacked iron ingots, warm grey iron, no blue | 좋음 | `item_ingot_iron_b_v02.png` | 171a0e9c-b207-4a62-9c5b-48a78cf42840 |
| 46 | a stack of three wooden planks, warm light brown wood | 좋음 | `item_planks_a_v02.png` | 934d6864-ef83-4562-9aaa-52c42b33245e |
| 47 | a single long wooden plank, warm brown wood with grain | 좋음 | `item_planks_b_v02.png` | bfc7b2a0-7cad-4754-b56c-f7432185528c |
| 48 | two wooden planks tied together with rope, warm brown wood | 좋음 | `item_planks_c_v02.png` | fe0bb7a5-bcd5-4aed-a7fd-6d4e2233d4f2 |
| 49 | a folded bolt of undyed linen cloth, cream | 좋음 | `item_cloth_a_v02.png` | 411f0a01-bb51-4e85-922a-b40feff87c56 |
| 50 | a rolled bolt of ivory cloth tied with string | 좋음 | `item_cloth_b_v02.png` | 7660b5db-3141-4d75-8d57-59ec74819abe |
| 51 | a small folded square of rough brown cloth | 좋음 | `item_cloth_c_v02.png` | ab6fa979-5cec-4a08-ac6f-12546bae3eea |
| 52 | a tanned leather hide stretched flat, warm brown | 좋음 | `item_leather_a_v02.png` | e97c8a73-d196-4018-a3c6-ce9e767845fd |
| 53 | a rolled piece of brown leather tied with a cord | 좋음 | `item_leather_b_v02.png` | b9f46571-9386-449f-95d1-d117e4ab155f |
| 54 | a folded piece of dark brown leather | 약함: 매우 어두움(최대 밝기 58) | `item_leather_c_v02.png` | 6a5e6552-f176-4231-b34d-48fe1fc7176d |
| 55 | a single clean bone, ivory white | 좋음 | `item_bone_a_v02.png` | f94e9b2f-e033-4b5d-a77f-ebc04ef6b579 |
| 56 | a small bundle of bones tied with twine, ivory | 좋음 | `item_bone_b_v02.png` | ddaabffb-6022-4b79-9069-0117f0c2c527 |
| 57 | a large thigh bone, ivory with darker ends | 좋음 | `item_bone_c_v02.png` | 00af7fc1-a4eb-4320-9795-8a2457f63399 |
| 58 | a small glass vial of holy water with a cork wrapped in gold thread, the water pale ivory with a faint gold glow, no blue, no symbols | 좋음(우유빛 → 상아빛) | `item_holy_water_a_v02.png` | b27a0fe8-e4c4-4595-8ff8-2b8fbca30bf3 |
| 59 | a small round flask of holy water, clear glass with a pale gold shimmer and a gold-banded cork, no blue, no symbols | 좋음 | `item_holy_water_b_v02.png` | 5e5d9dfd-3369-4c15-a6f8-79ee28143e4b |
| 60 | a tiny tall holy water bottle with a wax seal, pale ivory-gold liquid, no blue, no symbols | 가는 병, 붉은 띠 → 금빛 띠. 남은 붉은 점 2px → 통합 손질 `item_holy_water_c_v03.png` | `item_holy_water_c_v02.png` | c4d3240f-74b1-4df4-b9a0-fa7bd5c7be25 |
| 61 | a cut stone building block, warm grey-brown, square | 좋음(건설 재료 덤) | `item_stone_block_v02.png` | 0fd7d2fd-4794-4698-bed2-873073554d8b |
| 62 | a short log of wood with bark and a visible cut end | 좋음(덤) | `item_log_v02.png` | bccc9788-ba14-4c3e-80f4-6c6f3b889892 |
| 63 | a coil of rough hemp rope | 좋음(덤) | `item_rope_v02.png` | 4e48ddfb-eacb-46e6-9514-982671715f8d |

손질 (`stage4_props.py`, 원본 시트 둘과 `crops_v03_sheet.png`·`items_v04_strip.png`를 읽는다). 칸마다 순서대로:
1. 알파를 0/255로. 소품만: 생성기가 그려 넣은 불투명 바닥 그림자 타원(#625b53·#55524d)을 지운다. 캔버스 가장자리에서 투명·그림자색만 지나 닿는 픽셀만 지운다(4-연결, 지울 양이 불투명의 25%를 넘으면 그 칸은 그대로). 25칸에서 1~42px씩 지웠다. 기존 오브젝트(제단 v04, 이단의 제단 v02, 성물 제작대 v02, 조제대 v05)에 바닥 그림자가 없어서 맞췄다. 처음에는 "외곽선 밖의 어두운 픽셀"을 모두 지웠는데 외곽선 틈으로 새어 돌 속까지 비어서, 두 색만 지우게 바꿨다
2. 2px 이하로 떨어진 점 제거
3. 칸별 손질: 랜턴 넷(25·26·27·32)은 유리가 흰색·크림이라 켜진 것처럼 보여 꺼진 유리(#4a423a, 창마다 왼쪽 위 1px #6b5e4f 반사, 아랫줄 #2e2a26)로. 보라 맥 돌(아이템 26)은 잿빛 돌 + #3b1f4d 금 한 줄. 재 더미(소품 2)는 모래색 → 잿빛 단계. 성수 c(아이템 60)의 붉은 띠 → 신앙 금빛
4. 차가운 회색 → 따뜻한 회색: B > R인 회색, 파란 색상, 완전 무채색을 같은 밝기의 따뜻한 회색으로(brief 철 #5e5953의 R:G:B 비 1.047 : 0.991 : 0.924). 보라 기운 근흑도 같다
5. 계열 맞춤: 위협 칸의 보라는 #3b1f4d / #5e2d7a만(밝은 보라 면 없음. "가는 보라 금"은 와인색 #381a29로 나와 #3b1f4d로 바꿈), 올리브 곰팡이는 #4b6127 / #6f8f3a. 생활 초록은 crops_v03 초록 10색에서 가장 가까운 색(병든 올리브는 생활 쪽에 쓰지 않음). 독초는 작물 독초 노랑 #45390f #6e6620 #a5a132 #d5ce40 + 녹 꼬투리 #c4421c / #5b2e15(진한 빨강만. 처음에 주황 갈색까지 보내 가을 잎처럼 보여 줄였다). 버프 약초 호박색 #723f0e #a3520f #e0861a #f4c95d, 회복 열매 #5c1010 #c41e24 #f5674c. 구리 #5b2e15 #8c4a22 #c06a2e #df903f(금빛 #eaa63a를 넣은 첫 판은 구리 주괴가 금괴처럼 보여 뺐다), 철 #34302d #5e5953 #a39d92 #d2cbb8 + 녹 #6e3624 #a5552f(1차 시험 마지막 손질의 광맥·철 아이템과 같음)
6. 밝기 상한: 215 초과 색은 색상을 두고 215로(원본 최대 255 → 214.5)
7. 외곽선 #1a1714: 밝기 25 미만 근흑과 가장자리의 밝기 40 미만 픽셀은 #1a1714. 외곽선이 빠진 밝은 가장자리는 바깥 1px을 더해 닫는다. 야생·잘라 낸 약초, 죽은 덤불 둘(가는 줄기라 1배에서 검게 뭉침), 거미줄(실 그림)에는 더하지 않았다
8. 색 수 줄이기: CIELAB에서 가장 가까운 두 색을 합친다(새 색을 만들지 않음). 소품 24색 이하(결과 6~23색), 아이템 16색 이하(5~16색)
9. 가벼운 맞춤: brief §4·crops_v03·items_v04의 색과 ΔE76 6 미만이면 그 색으로(근흑과 악마 #2a0808은 빼고. 처음 판에서 나무 그림자가 #2a0808로 붙었다)

- 확인: 121장 모두 색 수, 최대 밝기 215, 파란 기운 색 없음, #1a1714 외곽선(거미줄 제외), 반투명 없음. §6 측정은 `props32_v02_sheet.png`·`items16_v02_sheet.png`·`stage4_a2_scale_check_1x.png` 모두 차가운 색 0%, 보라 0.01%
- 파일: 손질판 낱장 `prop_<이름>_v02.png` 60장(32×32), `item_<이름>_v02.png` 61장(16×16). 손질판 시트 `props32_v02_sheet.png`·`items16_v02_sheet.png`(남긴 칸만 # 순서로 8칸씩). 손질 전후 `stage4_a2_props32_compare.png`(3배)·`stage4_a2_items16_compare.png`(5배). 크기 확인 `stage4_a2_scale_check.png`(3배)·`_1x`
- 판정 (a2): 64칸 안에서는 화풍이 고르다. size 16 묶음은 1차 시험 아이템(items_v04)과 같은 손으로 보인다. 정렬 문구로 상자·통·기둥·광산 틀·랜턴 기둥은 정면 정렬로 나왔다. 상자 3장 중 2장(46·47)만 3/4로 돌아갔고, 납작한 돌 블록(63)은 위에서 본 판이 됐다
- 요청했지만 안 나온 것: 올리브 곰팡이(소품 5·6·15·21에 넣었지만 size 32 시트에 초록이 한 픽셀도 없다. 오염 표시는 `decal_mould_*`를 흩뿌리는 쪽이 낫다)

### 3. 손그림 (a3, 생성 없음)

brief §5.7 본 제작의 "손" 목록 다섯 가지를 `stage4_handdrawn.py`로 찍었다(ASCII 격자나 간단한 규칙, 시드 고정). 입력은 우리 4단계 에셋뿐이다. 새 색은 없다: 모든 결과의 색이 4단계 에셋 14개의 색 또는 brief §4 팔레트 안이다(`check`). 생활 쪽 최대 밝기 214(상아 천·초 #e2d6b8)이고, 가장 밝은 픽셀은 거룩한 불꽃 심 #fff6dc(245.7, 제단 v04 불꽃과 같은 값) 하나다.

1. 부서지는 벽 금 3단계: `wall_crack_top_v01.png`(48×16 = 벽 윗면 16×16 × 1·2·3단계), `wall_crack_face_v01.png`(48×24 = 벽 앞면 16×24 × 3단계. 0번 줄 = `tiles_dungeon_v02`의 벽 윗면 아래 32px 기둥(타일 (48,0) 위, (48,16) 아래)의 3번 줄)
   - 4방향으로만 이어지는 1px 금(#1a1714)에 빛 받는 쪽 가장자리(윗면 #8c7b66, 앞면 #5a5044)를 띄엄띄엄. 1단계 머리카락 금, 2단계 비대칭 Y, 3단계는 가장자리까지 그물 + 내려앉은 조각(#24201c 구멍, 새로 깨진 면 #6b5e4f) + 바닥 부스러기. 첫 판은 대각선만이라 X 표시처럼 보여 계단식 금으로 고쳤다
   - 같은 단계의 벽이 나란히 있으면 반복된다(좌우 반전으로 2벌을 쓸 수 있다)
2. 불꽃 4 + 1프레임과 빛 마스크: 스트립마다 5프레임(1~4 반복, 5 = 꺼진 심지의 잔불). 같은 배치의 `_emissive.png`: RGB = 빛 세기(255 / 205 / 150 / 100 / 60), 빛나는 픽셀만 A=255, 연기는 빛나지 않는다
   - `flame_small_v01.png`(20×7, 프레임 4×7): 제단 등잔·성물 촛불용. 맨 아래 줄(y6)이 심지에 앉고 불꽃은 x1~2. #fff6dc 심 / #f4c95d / #c9932b / #9c6a1f. 1프레임은 altar_v04 1·3열 등잔의 정지 불꽃과 픽셀까지 같다
   - `flame_large_v01.png`(30×10, 프레임 6×10): 건설 조명·화로용. 맨 아래 줄(y9)이 받침
   - `altar_v04_litbase.png`: 켜진 제단에서 정지 불꽃만 빛 번짐 #a48d6b·기름 빛 #c9932b로 바꾼 바탕. 프레임 왼쪽 위를 등잔마다 (9,5) (22,5) (35,5) (9,15) (22,15) (35,15) (9,25) (22,25) (35,25)에 둔다(48×57 파일 좌표)
   - 이단의 불 (? 이단 쪽 불의 색): 두 후보는 모양(갈라진 혀 여러 개 + 떨어지는 불티)이 같고 색만 다르다. `flame_heretic_small_*`(25×8, 프레임 5×8), `flame_heretic_large_*`(40×13, 프레임 8×13). **candA 촛불 금빛**: #f4c95d 심 / #c9932b / #9c6a1f / #6f5522, 연기 #2e2a26, 심을 거룩한 불보다 한 단 낮춤(최대 201.5). **candB 악마 주황**: §4 악마 줄만 #ff7a1a 심 / #c8321f / #8f1a1a / #5c1010, 연기 #2a0808(최대 150.8). 큰 이단 불 첫 판은 둥근 공에 뿔이 난 모양이라 혀를 갈라 다시 그렸다
3. 건설 벽·문·바닥 후보 (? 건설 벽 재질): 시트 128×72 둘, 배치 같음
   - `build_stone_candA_v01.png` **candA 돌만**: 던전 벽 모양(윗면 + 24px 앞면)을 투명 위에 다시 칠함. 윗면 제단 윗면의 따뜻한 회색 마름돌(#8f8272 계열), 앞면 제단 앞면 벽돌(#4a423a 계열), 바닥은 한 단 어두운 판석(#7d705f), 문은 돌 아치 문틀 + 나무 문짝(철띠 #2e2a26, 손잡이 #c9932b). 16색
   - `build_wood_candB_v01.png` **candB 나무 + 돌**: 나무 벽(성물 제작대 나무 색 #402c25~#b38264)을 돌 기초(아래 6줄) 위에. 윗면은 벽 방향의 판재, 모서리·갈림·외딴 칸은 단면 기둥. 엇갈린 널판 바닥, 나무 문. 14색. "나무 + 돌"이 (가) 나무 벽과 돌 벽을 둘 다 짓는다인지 (나) 한 벽에 두 재질인지 문서에 없어서, 돌 기초로 (나)로도 읽히게 하고 미리보기에 돌 집 + 나무 별채로 (가)도 보였다. 나무는 game-concept §12 ?(나무를 슬라이스에 넣을지)에 달려 있다
   - 시트 배치: y0~31 벽 윗면 16장(번호 = 이웃 마스크 N=1, E=2, S=4, W=8, 한 줄 8장), y32~47 안쪽 모서리 점 NE·NW·SE·SW(x0~63)와 바닥 A·B·C(x64~111), y48~71 앞면 16×24 외톨이·왼쪽 끝·가운데·오른쪽 끝(x0~63)과 문 닫힘·열림(x64~95)
   - 조립: 벽 칸에 마스크대로 윗면. 남쪽 칸이 벽이 아니면 앞면(16×24)을 남쪽 칸 위쪽부터 그린다(던전 벽처럼 1.5칸). 앞면 종류는 서·동 이웃이 앞면을 보이는지로 고른다. 문은 벽 칸이고 앞면만 문이다. 두 직교 이웃이 있고 대각선 칸이 비면 안쪽 모서리 점. 북쪽 줄부터 그린다. 16장 + 4장으로 47가지 이웃 조합이 다 나온다
   - 첫 판은 앞면이 16px라 캐릭터보다 낮은 담처럼 보였고, 나무 기둥 윗면 동심원이 문장처럼 읽혀 고쳤다
4. 제단 업그레이드 1단계 후보 (? 모습): 56×64. altar_v04 몸체(47×43)를 (4,12)에 그대로 두고 받침 단(옆·뒤 3px, 앞은 디딤 3줄 + 챌면 4줄)을 붙였다. 맵에서 altar_v04 자리에 넣으려면 (−4, −7) 옮긴다. 파일은 후보마다 켜짐 `.png`, 꺼짐 `_unlit`, 불꽃만 뺀 `_litbase`, 1프레임 빛 마스크 `_emissive`
   - `altar_up1_candA_v01*` **candA = 문서 안**: 받침 단 + 윗면 네 모서리 금 촛대(상아 초 #e2d6b8/#c9b994) + 앞면 금 테(#f4c95d/#c9932b) 상아 천(6px마다 주름, 아래 금 술). 26색(꺼짐 23)
   - `altar_up1_candB_v01*` **candB**: 받침 단 + 받침 앞 모서리의 키 큰 금 등잔대 둘(큰 불꽃) + 앞면 윗줄 금박. 23색(꺼짐 20)
   - 불꽃 자리(56×64 좌표): 등잔 9개 (13,12) (26,12) (39,12) (13,22) (26,22) (39,22) (13,32) (26,32) (39,32) flame_small, candA 촛대 (5,0) (46,0) (5,27) (46,27) flame_small, candB 등잔대 (1,24) (48,24) flame_large
5. 던전 입구 둘레와 흩뿌리는 오염 장식
   - `dungeon_entrance_stairs_v01.png`(48×48, dungeon_entrance_v02 위에 겹침): 입구 안을 어둠으로 내려가는 디딤 넷으로(가까울수록 밝음 #a69782 → #3b342d, 디딤 사이 #1a1714, 첫 디딤 가운데가 닳아 밝음). 11색
   - `dungeon_entrance_debris_v01.png`(96×72, 아치를 (24,12)에): 떨어진 아치 돌(이끼 두 곳), 잔돌·모래(시드 31), 밖으로 갈수록 성긴 잿빛 얼룩. 입구 앞 길(가운데 ±8px)은 비움. `dungeon_entrance_set_v01.png` = 둘레 + v02 + 계단 한 장(15색)
   - 장식(칸에 고정하지 않고 흩뿌림): `decal_crack_1~4_v01.png` 열린 금(잿빛 땅), `decal_vein_1~3_v01.png` 1px 보라 맥 #3b1f4d(2번만 #5e2d7a 한 점), `decal_ashcreep_1~3_v01.png` 풀 쪽 경계의 잿빛 얼룩(첫 판은 점 무리라 풀 위에서 벌레처럼 보여 덩어리로 고침), `decal_rubble_1~4_v01.png` 잔돌(풀·잿빛 어디나)
   - §6 측정(`stage4_a3_entrance_preview_1x.png`): 차가운 색 1%, 보라 0.06%
6. 미리보기: `stage4_a3_cracks_preview.png`, `stage4_a3_flames_preview.png`·`.gif`(4배, 140ms), `stage4_a3_build_preview.png`, `stage4_a3_altar_preview.png`, `stage4_a3_entrance_preview.png`·`_1x`

### 4. 통합 (a4, 생성 없음)

새 파일을 모두 4~8배로 확대해 보고, 깨진 것 셋을 손질했다. 목업은 `stage4_mockup.py`다. 화면은 480×270(game-concept §7, R31)이고 목업 본 파일은 3배(brief §7 판정 배율. 1080p 실제 화면은 4배)다.

1. 작은 손질 (`fix`, 손질 전후 `stage4_fix4_small_compare.png`)
   - `item_holy_water_c_v03.png`: 액체 가운데 짙은 빨강 #620004 2px가 핏방울처럼 보여 금빛 띠 #6f5522와 상아빛 물 #dfc69c로
   - `item_offering_cup_v03.png`: 굽 달린 잔이 성배로 읽힐 수 있어(신앙 상징 결정 전, game-concept §7) 굽·다리를 지우고 몸통 밑을 외곽선으로 닫아 4px 내렸다. 굽 없는 금 간 흙 잔이다. v02는 쓰지 않는다. 묶음 시트 `items16_v02_sheet.png`와 a2 미리보기(`stage4_a2_items16_compare`, `stage4_a2_scale_check*`)에는 v02 잔이 그대로 남아 있다(기록용, v03이 대신한다)
   - `prop_barrel_smashed_v03.png`: 가운데 와인빛 #301412 4px(피처럼 보임)를 따뜻한 갈흑 #2c1f1a로
2. 목업
   - `stage4_mockup_v04_day.png`·`_1x`: 풀밭, 흙길 v02(큰길 + 제단 앞 갈래), 밭(일군 흙 v03 + 회복·버프·독초 0~4단계 + 물 준 줄), 제단(`altar_v04_litbase` + 공유 작은 불꽃 9개, 등잔마다 위상을 어긋나게), 촛대 둘·불 바구니·모닥불(공유 불꽃), 랜턴 기둥 둘(꺼짐), 공유 창고 + 통·자루, 조제대 v05·기본 작업대·모루·성물 제작대, 채집물(야생 약초 셋·버섯·돌·나뭇가지), 오염 땅 v05(장식 없는 잿빛 속 타일 + 새 금·맥·잔돌 + 뼈·곰팡이 장식을 흩뿌림, 풀 쪽 잿빛 얼룩), 위협 소품(뼈 더미, 부서진 우상, 의식 돌, 꺼진 화로, 해골 말뚝, 죽은 덤불, 오염 바위), 오염 옆 시든 작물, 다섯 클래스
   - `stage4_mockup_v04_eve.png`·`_1x`: 같은 장면. 제단 빛(안 100px, 밖 150px)과 촛대·불 바구니·모닥불 빛 밖을 3단 디더링으로 어둡게 했다(풀 ×0.42/0.38/0.35, 잿빛 땅 ×0.54/0.50/0.47로 v03과 같은 값, 오염은 덜 어둡게). 불꽃·후광은 어두워지지 않는 층이다
   - `stage4_dungeon_v05.png`·`_1x`: 왼쪽 158px = 지상의 던전 입구 둘레(잿빛 땅 + 풀 경계, `dungeon_entrance_set_v01`, 흩뿌린 장식, 해골 말뚝·죽은 덤불·뼈, 입구로 가는 팔라딘·성직자). 오른쪽 320px = 던전 방(던전 v02 + 변형, 광맥 v02 다섯 칸, 북쪽 벽의 금 1·2·3단계, 거미줄, 공유 큰 불꽃을 단 횃불 둘, 광산 틀·부러진 들보, 이단의 제단 + 꺼진 화로·검은 초·해골 더미·제물 그릇, 창고 구석, 잔해·기둥 토막·석순·광석, 오른쪽 벽의 철 광맥 칸을 곡괭이로 치는 광부, 아처·약초사). ? 항목은 넣지 않았다: 이단의 불은 색이 정해질 때까지 꺼 두었고, 보스 구역의 광부 지형 요소(기둥 후보)는 후보 시트에만 있다. 첫 판에는 기둥 후보가 라벨 없이 들어가 있어 a5가 뺐다(아래 "### 5. 검토 뒤 고침")
   - `stage4_candidates_v01.png`: ? 후보 넷을 3배로 나란히, 한국어 라벨(아래 "사람이 정할 것")
   - 캐릭터: 03-pixel `base_body_v02_walk.png` 첫 프레임 + 표식 레이어(남 +4, 동 +3, 북 +4 내림), 서쪽은 동쪽 합성의 좌우 반전, 후광은 머리 꼭대기 5px 위. 광부의 곡괭이질은 `base_body_v02_pickaxe.png` 동쪽 4번째 프레임이고, 손에 든 도구가 표식이라 등 표식을 숨겼다(R27)
   - 불꽃 자리(프롭 좌표, 불꽃 프레임 왼쪽 위): 촛대 a (14,−5), 촛대 b (15,−4) flame_small. 불 바구니 (13,−2), 모닥불 (13,4), 벽 횃불 a (9,−4) flame_large (`stage4_mockup.py`의 `LIGHT_ANCHORS`)
3. 판정 (brief §7, §5.7 손질 규칙. 목업은 1배와 3배로 봤다)
   - §6 측정(`arttool.py measure`): 낮·저녁·던전 목업과 후보 시트 모두 차가운 색 0%, 보라 0.00% (OK)
   - 손질 규칙 검사(오늘 밤 채택 후보 168장): 아이템 16색·소품과 오브젝트 24색 이하, 생활 쪽 최대 밝기 215 이하(흙길 v02의 풀꽃 점 226은 허용 범위), 파란 기운 회색 0, 반투명 0, 오브젝트에 #1a1714 외곽선. 예외 둘(검토에서 찾음): `altar_up1_candA_v01`은 26색, `_litbase`는 25색이라 24색을 넘는다(후보라 줄이지 않았다). 얇은 식물·가시덤불·거미줄·바닥 장식은 손질 때 일부러 외곽선을 다 두르지 않았다(거미줄 0%, 야생 약초·잔가지 15~45%, 죽은 덤불 54~59%)
   - 가장 밝은 점: 세 목업 모두 거룩한 불꽃 심 #fff6dc(246)이다. 215를 넘는 나머지는 풀꽃 점(223·226), 후광(237), 3단계 캐릭터 얼굴·눈 하이라이트(218~232, 이번 범위 밖)
   - 정렬형: 기본 작업대·모루·공유 창고·기둥 후보는 정면 정렬. 소품 묶음은 누운 통(51)·부서진 상자(52)만 조금 비스듬하다. size 16 아이템 중 재료 아이콘(돌 블록, 주괴, 널판, 천 a)은 3/4·비스듬한 아이콘이다. 땅에 떨어진 아이템도 정면 정렬이어야 하는지는 사람이 본다(그렇다면 생성 없이 손으로 다시 그린다)
   - 제단 빛 = 안전 (§7): 저녁판에서 빛 안의 밭·작업대·제단과 빛 밖의 채집물·오염 땅이 갈린다. 오염 땅은 덜 어둡게 해서 금과 장식이 남는다
   - 생활↔위협 대비 (§7): 낮판에서 따뜻한 풀·흙·나무와 잿빛 오염·뼈·꺼진 화로가 한 화면에서 갈린다. 보라는 가는 맥에만 있다
   - 1배: 제단과 등잔 불꽃, 창고, 작업대·모루·조제대·성물 제작대, 흙길(모래가 아니라 흙), 오염 소품(해골·우상·의식 돌·화로)은 읽힌다. 다섯 클래스는 방패·후광이 확실하고 곡괭이·활·주머니는 약하다(3단계와 같음). 벽 금은 3단계만 보인다
   - 3배: 모두 읽힌다. 벽 금 1단계는 3배에서도 약하다(의도: 첫 타격)
4. 약한 것 (사람 확인 전, 고치지 않음. 대부분 아래 "## 본 제작 손질 2"에서 고쳤다)
   - 크기: size 32 소품은 캔버스를 채워서 통·상자·자루가 캐릭터(약 30px)만 하다. 낮판에서 통이 공유 창고보다 높다. 랜턴 기둥·촛대는 캐릭터와 같은 키라 오히려 작다. 고치려면 작은 것은 size 24, 큰 것은 size 48로 다시 뽑는다(약 20회. 오늘 남은 11회로는 모자란다). ? 항목이 아니라 후보를 만들지 않았다
   - 던전: 따뜻한 회색 소품(잔해·기둥 토막·석순, 후보 시트의 보스 기둥 후보)이 같은 계열 바닥 위에서 1배에 외곽선으로만 읽힌다. 기둥 후보의 금이 이음매와 같은 색이라 "금 간" 기둥으로 약하다
   - 흙길: 풀이 위에 있는 가장자리의 이빨이 짙은 초록 테라 3배에서 산울타리처럼 보인다
   - 모루 몸통이 어두워(밝기 45~90) 1배에서 검은 덩어리이고, 윗면 강철 띠로만 모루로 읽힌다. 기본 작업대 위 망치·톱이 흐리다
   - 랜턴 다섯(기둥 셋·땅·벽)은 꺼진 판만 있고 켜짐판과 불꽃 자리가 없다(목업에서도 꺼 둠). 성물 제작대 v02의 촛불은 아직 3px 정지 불꽃이라, 공유 불꽃으로 바꾸려면 그 자리를 지우는 손질이 따로 든다
   - 아이템: 곰팡이 덩이(28)는 목업에서 거북·둥지처럼 보인다. 가죽 c(54)는 매우 어둡고(최대 밝기 58), 검은 초 둘(24·25)은 던전 바닥에서 묻히고, 철광석 c(41)와 뼈 부적(33)이 약하다. 불 바구니(소품 34)의 통나무 끝 주황은 잉걸불처럼 보일 수 있다
   - 건설 벽: candA는 바닥과 벽 윗면 색이 가까워 방 안이 덜 갈린다. candB는 북쪽 벽 앞면이 울타리처럼 보인다. 둘 다 문 폭이 8px라 캐릭터(약 16px 폭)보다 좁아 보이고, 세로 벽 옆문과 풀 쪽 바닥 가장자리 조각이 없다. 앞면이 아래 칸으로 늘어지는 것과 충돌 칸은 gameplay-design §3.3 ?(벽이 바닥 위 별도 층인지)에 달렸다
   - 제단 업그레이드: 두 후보 모두 받침이 3×3 칸보다 옆으로 3~4px 넓다. candA 앞 모서리 촛대가 제단 옆 외곽선을 덮고, 26색이다
   - 철·녹 6색(#34302d #5e5953 #a39d92 #d2cbb8 #6e3624 #a5552f)은 1차 시험처럼 §4 팔레트 밖이다(사람 확인)
5. 사람이 정할 것 (? 항목. 아무것도 고르지 않았다. 후보 시트 `stage4_candidates_v01.png`)
   - 제단 업그레이드 1단계 모습: `altar_up1_candA_v01*` 문서 안(받침 단, 금 모서리 촛대, 금 테 상아 천) / `altar_up1_candB_v01*` 받침 단 + 키 큰 금 등잔대 둘 + 앞면 금박
   - 건설 벽 재질: `build_stone_candA_v01` 돌만 / `build_wood_candB_v01` 나무 + 돌(나무가 슬라이스에 들어올 때만 뜻이 있다)
   - 이단 쪽 불의 색: `flame_heretic_*_candA_v01` 촛불 금빛(모양만 다름) / `flame_heretic_*_candB_v01` 악마 주황
   - 보스 구역의 광부 지형 요소(game-concept §12): `boss_pillar_candA_v02` 금 간 받침 기둥(문서 안)만 있다. 안이 하나뿐이라 A/B 고르기가 아니다: 이 안을 받을지, 다른 안을 낼지를 정한다(다른 안은 무엇을 하는 요소인지 정하는 설계 쪽 일이라 그림으로 만들지 않았다). 목업 본 판에는 넣지 않았다. 정해지면 상태 4단계를 손으로 만든다
   - ○ (문서의 ? 항목은 아님) 공유 창고의 모습: 긴 상자 하나(f, 채택 후보) / 상자·나무 상자·자루를 묶은 창고 구석(d처럼. 이번 d는 자물쇠가 십자로 읽혀 탈락)
6. 요령
   - `create_map_object` 정렬: "flat elevation with no side faces visible" + "(윗면) only a thin horizontal strip"을 더하자 정렬이 4장 중 0장에서 3장으로 올랐다. 낮은 상자꼴은 그래도 3/4가 나왔고, 넓은 캔버스(48×32)에 "long low … filling the width of the image"와 "standing on a level ground line"을 같이 쓴 판만 정렬됐다(같은 문구의 32×32는 실패). 여러 물건을 한 캔버스에 넣으면 정렬은 되지만 물건마다 작아진다
   - 같은 계정으로 에이전트 여럿이 동시에 생성하면 잔액 차이로 각자의 값을 떼어 볼 수 없다. 다음에는 한 에이전트가 생성을 마친 뒤 잔액을 적고 다음 에이전트가 시작하거나, 응답의 cost를 적는다
   - `create_1_direction_object` size 32는 물건마다 캔버스를 채워 크기 차이가 사라진다. 크기가 다른 물건은 크기별 묶음으로 나눈다. 이 크기는 소품 밑에 불투명 회색 바닥 타원을 그려 넣었다(손질로 지움)
   - 설명의 "dull olive mould"는 size 32 묶음에서 한 픽셀도 나오지 않았고, "thin dark violet cracks"는 와인색 #381a29로 나왔다. 랜턴은 "empty dark glass, no light"라고 써도 유리가 흰색·크림(켜진 모습)으로 나왔다. 오염 신호와 꺼진 유리는 손질로 맞춘다
   - "grey" 계열은 이번에도 남색·보라 기운 회색이 나왔다(모루 쇠, 상자 테, 기둥 금). 따뜻한 회색 손질을 셈에 넣는다

### 5. 검토 뒤 고침 (a5, 생성 없음)

검토에서 나온 문제를 하나씩 판단해 맞는 것만 고쳤다. PixelLab은 쓰지 않았다.

1. ? 후보가 목업 본 판에 라벨 없이 들어가 있었다 → 맞음, 고침
   - 첫 판 `stage4_dungeon_v05`(커밋 cd6993a)는 던전 방 오른쪽에 `boss_pillar_candA_v02`를 놓고 광부가 곡괭이로 치게 했다. 보스 구역의 광부 지형 요소는 game-concept §12의 ? 항목이고 안이 하나뿐이라, 본 판에서는 정해진 답처럼 보였다. 같은 장면에서 이단의 불은 ? 라서 꺼 두었으니 ? 항목을 다루는 방식도 어긋났다. 통합(a4) 보고의 "목업 본 판에는 정해졌거나 공유하는 조각만 썼다"는 이 파일에서는 틀렸다(첫 판 때 이 기록의 목업 줄에는 기둥이 적혀 있어서, 기록으로는 숨기지 않았다)
   - 고침 (`stage4_mockup.py dungeon`): 기둥을 뺐다. 기둥은 후보 시트 `stage4_candidates_v01.png` 넷째 판에만 있다. 광부는 오른쪽 벽의 철 광맥 칸(19, 8)을 치게 옮겼다(곡괭이 동작 캔버스 왼쪽 위 (250, 96), 날 끝이 벽 가장자리 x 294에 닿음. 좌표는 오른쪽 판 기준). 그 자리에 있던 석순 a는 (262, 140) → (242, 196)으로 옮겼다. 바닥·광맥 배치, 왼쪽 판, 나머지 소품·캐릭터는 그대로다
   - 라벨("candA (?)")을 그려 넣는 방법은 쓰지 않았다. 목업은 1배·3배 읽힘과 §6 측정에 쓰는 판정용 그림이라 글자가 섞이면 판정이 흐려지고, 이단의 불처럼 ? 항목은 본 판에서 빼는 쪽이 같은 처리다
   - 파일 이름은 그대로 두고 다시 만들었다(사람 확인 전, 같은 PR 안의 파일이라 버전을 올리지 않았다. 첫 판은 cd6993a에 있다). 다시 돌리면 바이트까지 같다(두 번 돌려 확인)
   - 다시 잰 값: §6 측정 3배·1배 모두 차가운 색 0%, 보라 0.00% (OK). 가장 밝은 점은 그대로 거룩한 불꽃 심 #fff6dc(246)
   - 이제 세 목업 본 판(낮·저녁·던전)에 `_candA`·`_candB` 파일은 없다. 다만 낮·저녁판의 나뭇가지 채집물(`item_sticks_a_v02`·`item_sticks_b_v02`)은 game-concept §12 ?(나무 = 목재 원천을 슬라이스에 넣을지)와 닿을 수 있다. 검토 항목 밖이라 고치지 않았고, 사람이 본다
2. 검토의 작은 지적 (통합 뒤 기록만 고침, 그림은 그대로)
   - 손질 규칙 검사의 "걸린 것 없음"이 넘쳐 말했다 → 위 §4 판정 줄에 예외(제단 업그레이드 candA 26·25색, 일부러 외곽선을 덜 두른 얇은 것들)를 적었다
   - size 16 재료 아이콘의 3/4 시점, 묶음 시트에 남은 v02 잔, 글자 든 미리보기의 글꼴 의존 → 각 줄에 적었다
   - 던전 목업의 횃불 둘에 공유 거룩한 불꽃을 단 것: 횃불은 상점 기본 키트로 플레이어가 놓는 빛(gameplay-design 기술자 줄 "상점의 기본 키트 (횃불, 발판)")이라 공유 불꽃이 맞다. 이단 쪽 불의 색(?)과는 상관없다. 던전에 원래 있는 불(이단의 제단·화로)은 그대로 꺼 두었다

## 본 제작 손질 2 (2026-10-22 새벽, PixelLab 10회)

위 "### 4. 통합"의 "4. 약한 것"을 사람이 자는 동안 고쳤다. 에이전트 셋이 한 작업 트리(브랜치 `art/stage4-scale`, main e58319e에서)에서 나눠 했고, 질문하지 않았다. ? 항목(제단 업그레이드 모습, 건설 벽 재질, 이단 쪽 불 색, 보스 구역의 광부 지형 요소, 나무를 슬라이스에 넣을지, 누가 무엇을 심는지)은 고르지 않았고 새 후보도 만들지 않았다. 모두 채택 후보이고 사람 확인 전이다.

- 나눔: s1 = 작은 소품을 size 24로 다시 뽑기 (상한 10회). s2 = 손으로 고칠 수 있는 약한 것 (0회). s3 = 통합: 새 파일 확대 검토와 작은 손질, 목업, 크기 비교 시트, 측정·규칙 검사, 이 기록 (0회). s4 = PR 검토 뒤 고침 (0회, 맨 아래 "### 검토 뒤 고침 (s4)": 통·자루 v04, 던전 소품 v04, 목업 낮·저녁 v06·던전 v07, 기록 고침)
- **사용: 10회** (s1 한 묶음). 잔액 1,737 → 1,727. s1이 생성 전후 `get_balance`로 확인했고 차이가 응답의 cost 10과 같다(그 사이 다른 생성 없음). 통합 때 다시 확인한 잔액도 1,727이다(이번 주기 2,000 중 남은 생성 수, 다시 채워지는 날 2026-11-14)
- **밤 전체: 45회** = 본 제작 35회 + 손질 2 10회. 사람이 승인한 상한 46회 중 1회가 남는다
- 레퍼런스: 이미지 레퍼런스 없이 글만 썼다. 다른 사람 팩 이미지는 넣지 않았다. 내려받기 주소는 적지 않았다(계정 경로가 들어 있다)
- 손질은 모두 스크립트다(무료). 세 스크립트 모두 두 번 이상 돌려 출력의 sha256이 같았다(s2·s3는 다른 폴더에서도 돌려 확인). 글자가 든 그림(`stage4_s2_compare`, `stage4_scale_compare_v01`)은 Pillow에 들어 있는 기본 글꼴(`ImageFont.load_default`)이라 고정한 pillow 11.3.0이면 기기와 상관없이 같은 바이트다. 실행은 `uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I <스크립트> …`
  - `tools/art/stage4_props24.py` (s1, 인자 없음)
  - `tools/art/stage4_fix5.py {all|tall|lit|bench|anvil|workbench|path|dungeon|items|build|altar|compare|check}` (s2)
  - `tools/art/stage4_mockup.py {fix2|surface5|dungeon6|scale|rules}` (s3. 앞의 `fix|surface|dungeon|candidates` 출력은 바이트까지 그대로 다시 나온다. `scale`은 s4가 라벨을 고쳤다)
  - `tools/art/stage4_fix6.py {all|props|boards|compare|rules|check}` (s4)
- v02 파일은 하나도 고치지 않았다. 새 판은 새 이름이다: v03(이미 v03이 있던 깨진 통, 통합에서 다시 손질한 검은 초 b는 v04), v01만 있던 건설 벽·제단 업그레이드 candA는 v02, 꺼짐판이 v02인 땅·벽 랜턴의 켜짐판은 `_v02_lit`

### 1. 작은 소품 크기 (s1, 10회)

size 32 묶음의 통·상자·자루는 캔버스를 채워 캐릭터(기본 몸 걷기 남 키 28px)만 했다. 그 묶음에서 실제로 작은 물건만 골라 size 24 묶음 하나로 다시 뽑았다. 키가 커야 하는 랜턴 기둥·촛대는 다시 뽑지 않고 s2가 손으로 늘렸다(아래 2절).

- 도구: `create_1_direction_object`, object **aa947894-a736-4170-848b-a3615b4861a1** (job 455ee755-749c-4256-8d70-49a92d05931b, 243초, `name: "s1 stage4 props size24"`). `size: 24`(42 이하라 64칸, 값 10회로 size 16·32와 같다), `view: "top-down"`. `style_images`·`palette`·`max_colors`는 넣지 않았다(a2와 같음)
- `description`: a2 묶음 1과 글자까지 같다 ("top-down RPG pixel art prop for a dark medieval fantasy farming game, one object centred with empty space around it, seen straight from the front and a little from above, its base edge exactly horizontal, not rotated, not isometric, 1px dark warm brown-black outline, 2-3 shade levels per material, warm brown-black shadows with no blue or navy, no text, no letters, no symbols")
- `item_descriptions`: 위 "### 2." 묶음 1 표의 설명을 그대로 2~4번씩 반복했다. 새 문구는 작은 자루 하나다. 같은 설명도 칸마다 다르게 나왔다
- 내려받기: 생성 직후 review 64칸을 원본 시트 `props24_v01_sheet.png`(192×192, 8×8칸, 칸 번호 = 줄 × 8 + 칸)로 받았다(반투명 0). 고른 칸 둘(39, 62)은 올린 object 그림과 시트 칸이 픽셀까지 같았다
- 고르기: `select_object_frames`로 19칸을 완료 object로 올렸다(태그 `s1-stage4-props24`). 남은 45칸은 review object aa947894…에 있다(지우려면 `dismiss_review`)

| 칸 | 설명 (item_descriptions, 그대로) | a2 # | 판정 | 키 |
|---|---|---|---|---|
| 0~3 | a sturdy wooden crate with dark iron corner brackets, seen from the front, front edge exactly horizontal, warm brown wood | 45 | 2만 정면 정렬(윗면 가는 띠 + 앞면). 0·1·3은 옆면이 보이는 3/4 → 2 | 19~21 |
| 4~6 | an old wooden crate with a cracked plank and a loose lid, seen from the front, front edge exactly horizontal, weathered brown wood | 46 | 셋 다 3/4 → 탈락 (a2와 같다. v02도 없다) | 21 |
| 7~9 | two wooden crates stacked, the smaller one on top, seen from the front, front edges horizontal, warm brown wood | 47 | 셋 다 3/4이고 상자 앞면마다 소용돌이 무늬가 문양처럼 읽힘 → 탈락 | 21 |
| 10~13 | an old wooden barrel with dark iron hoops standing upright, seen from the front, warm brown wood | 48 | 모두 정면. 10이 가장 따뜻한 갈색 → 10 | 21 |
| 14~17 | a wooden barrel with a closed lid and rusty hoops and a little dust at its base, seen from the front | 49 | 모두 정면. 15·17 뚜껑 회색, 16·17 밑에 불투명 흙먼지 → 14 | 20~21 |
| 18~21 | a small wooden keg standing upright with iron hoops, seen from the front | 50 | 넷이 거의 같음 → 18 | 17 |
| 22~24 | a wooden barrel tipped over on its side, seen from the front, warm brown wood with dark iron hoops | 51 | 셋 다 수평으로 누움(v02의 비스듬함이 없다) → 22 | 16 |
| 25~27 | a smashed wooden crate: broken planks and splinters in a heap, warm brown wood | 52 | 25는 멀쩡한 빈 상자(3/4) 탈락, 26 산만, 27 널판 더미 → 27 | 19~20 |
| 28~30 | a smashed barrel: broken staves and a loose iron hoop in a heap | 53 | 28 테가 엉킨 선, 29 선 채 깨진 통 + 풀린 테, 30 누운 깨진 통 → 29 (통합에서 탈락, 아래 3절) | 18~21 |
| 31~34 | a burlap sack of goods tied at the top, slumped, warm tan cloth | 54 | 모두 좋음 → 32 | 20 |
| 35~38 | two burlap sacks leaning together, warm tan cloth | 55 | 모두 좋음. 37(열린 자루 + 묶은 자루)이 가장 낮음 → 37 | 18~20 |
| 39~40 | a small burlap sack of grain tied at the top, short and squat, slumped low on the ground, warm tan cloth | (새 문구) | 키 14. 묶지 않고 입구가 열려 금빛 낟알이 금화처럼 보임 → 39, 낟알만 손질 | 14 |
| 41~43 | a small heap of broken pottery shards beside a cracked clay jar, warm terracotta | 61 | 42 선 깨진 항아리 + 조각 → 42 | 16~19 |
| 44~47 | a tall cracked clay storage jar, warm terracotta, seen from the front | 62 | 44·45 깨끗한 금, 46·47 얼룩이 탁함 → 44 | 20 |
| 48~50 | an unlit small iron lantern with a ring handle standing on the ground, empty dark glass, no flame | 31 | 셋이 거의 같음. 유리 칸은 그리지 않고 뚫어 두었고(창 둘 x9~10·x13~14, y12~16의 16px이 투명이라 꺼짐판에서는 바닥이 비친다), 고리 구멍만 흰색 2px → 48 (s4 고침: 처음에는 "유리는 어둡고"라고 적었다. review 시트 원본 칸에서도 창은 투명이다) | 21 |
| 51~53 | a cracked stone offering bowl with dried dark red stains and a few small bones, ash-grey stone, grim | 14 | 51 피 + 뼈 하나 → 51 | 16~17 |
| 54~55 | a cluster of three melted black wax candle stubs on a small skull, unlit, no flame, grim | 12 | 둘 다 좋음 → 54 | 18~20 |
| 56~57 | a cluster of tall and short black wax candles melted together on the ground, unlit, no flame, grim | 13 | 56 키 20, 57 키 17 → 57 | 17~20 |
| 58~59 | a small heap of cracked skulls stacked in a pyramid, ash and bone colours, grim | 20 | 59는 회색 돌이 섞임 → 58 | 17~20 |
| 60~61 | an unlit squat stone fire bowl full of cold ash and a few bones, ash-grey stone, no fire, no flame, grim | 11 | 61에 뼈가 있음(설명대로) → 61 | 16 |
| 62~63 | a small cage of rusty iron bars with old bones inside, grim | 19 | 둘 다 정면 → 62 | 20 |

남긴 19칸 (캔버스 24×24, 바닥 줄 = 맨 아래 불투명 줄 y20~22. 키·색 수·최대 밝기는 손질 뒤):

| 칸 | 손질 파일 | 바꾸는 것 | 키 v02 → | 폭 | 색 | 최대 밝기 | object id |
|---|---|---|---|---|---|---|---|
| 2 | `prop_crate_a_v03.png` | crate_a v02 | 29 → 19 | 18 | 24 | 134 | 175fcadd-a829-48cb-9ec6-3e63c7d2b9e6 |
| 10 | `prop_barrel_a_v03.png` | barrel_a v02 | 29 → 21 | 16 | 24 | 149 | 6d0ccd43-b4a7-4798-9dd0-8f9e50648535 |
| 14 | `prop_barrel_b_v03.png` | barrel_b v02 | 29 → 20 | 16 | 24 | 129 | d68dc272-813a-4b60-b4a4-c81be8ef120e |
| 18 | `prop_barrel_c_v03.png` (작은 통) | barrel_c v02 | 26 → 17 | 14 | 23 | 134 | 9afd79b7-8662-44dc-b268-fe1d3d850ff6 |
| 22 | `prop_barrel_tipped_v03.png` | barrel_tipped v02 | 26 → 16 | 20 | 22 | 158 | 38915679-dd83-4c0a-b7a3-28bc7fdf62a3 |
| 27 | `prop_crate_smashed_v03.png` | crate_smashed v02 | 28 → 19 | 20 | 23 | 149 | 78993911-3b66-453b-b410-888c03d1471a |
| 29 | `prop_barrel_smashed_v04.png` (**탈락**, 아래 3절) | barrel_smashed v03 | 28 → 21 | 20 | 23 | 210 | e806c273-7e4f-4937-8a8b-d592841acc3c |
| 32 | `prop_sack_a_v03.png` | sack_a v02 | 25 → 20 | 18 | 17 | 166 | 08d200bf-9b0a-4ab2-afd4-4f7d6f44629e |
| 37 | `prop_sack_b_v03.png` | sack_b v02 | 27 → 18 | 20 | 20 | 167 | fa9b5fb0-c429-4b88-a168-53c170534c40 |
| 39 | `prop_sack_small_v03.png` | (새 것) | — → 14 | 16 | 20 | 201 | 992b8c5b-d205-4e2e-bf09-a396e6923269 |
| 42 | `prop_pottery_broken_v03.png` | pottery_broken v02 | 25 → 19 | 20 | 17 | 149 | c3965197-b019-443a-a1eb-dd577aca5c6d |
| 44 | `prop_jar_clay_v03.png` | jar_clay v02 | 28 → 20 | 16 | 17 | 145 | 7f37e126-4f0f-4ea8-9661-3130d4e7f0a8 |
| 48 | `prop_lantern_ground_v03.png` | lantern_ground v02 | 26 → 21 | 12 | 16 | 132 | 84e5890c-60fd-40fb-8b29-48a2f60881ad |
| 51 | `prop_offering_bowl_v03.png` (위협) | offering_bowl v02 | 23 → 17 | 20 | 22 | 214 | a1376664-fa0d-44e6-b33e-e7afd3a60349 |
| 54 | `prop_candles_black_a_v03.png` (위협) | candles_black_a v02 | 25 → 18 | 16 | 20 | 214 | 6fea5bfd-26b2-46f8-9770-d529dba3fc4d |
| 57 | `prop_candles_black_b_v03.png` (위협, 통합 손질판 v04) | candles_black_b v02 | 29 → 17 | 18 | 10 | 90 | 1e8cb15c-d9ad-4635-995e-dbe2cc3f5c44 |
| 58 | `prop_skull_pile_v03.png` (위협) | skull_pile v02 | 24 → 17 | 20 | 22 | 214 | 9db9ede8-8271-4ae4-9873-dc8cd2f88ec8 |
| 61 | `prop_brazier_dark_c_v03.png` (위협) | brazier_dark_c v02 | 23 → 16 | 20 | 21 | 214 | aa1dfb2b-4514-4188-8024-a40328426754 |
| 62 | `prop_bone_cage_v03.png` (위협) | bone_cage v02 | 31 → 20 | 18 | 24 | 210 | ccd7aac0-6bb6-42c6-bc41-45f307ac2bfb |

- 그 밖의 파일: 손질판 시트 `props24_v02_sheet.png`(192×72, 위 표 순서로 8칸씩), 크기 확인 `stage4_s1_scale_check.png`(1440×812: 왼쪽 위 480×200 = 1배 판, 아래 = 같은 판 3배. 글자 없음)
- 손질 (`stage4_props24.py`). `stage4_props.py`(a2)는 불러오면 전체 손질을 바로 돌려서 규칙 함수를 복사했다(색 합치기에서 같은 거리 짝은 정렬된 순서로 골라 결과가 순서에 기대지 않게 했다). 칸마다 순서대로:
  1. 알파 0/255. 바닥 그림자(#625b53·#55524d) 지우기는 0px: size 24는 바닥 타원을 그리지 않았다. 2px 이하 떨어진 점 지우기
  2. 칸별: 땅 랜턴 고리 구멍의 순백 2px (11,4)(12,4)가 켜진 유리처럼 보여 투명으로. 작은 자루의 금빛 낟알 25px(색상 30~50°, 채도 0.55 이상, 밝기 90 이상)를 밝기 순으로 기본 작업대 v02의 연한 대팻밥 3단(#e2c49c / #caa275 / #a47b55)으로(생활 쪽에 신앙 금빛을 쓰지 않음). 검은 초 둘은 밀랍 안쪽이 밝기 0~24라 외곽선 규칙이 초를 통째로 외곽선으로 만들어서(첫 판 57번 7색), 네 이웃이 모두 불투명한 안쪽 픽셀 중 밝기 25 미만만 밝기 28 + 0.9 × 원래의 따뜻한 회색으로 올렸다(54번 57px, 57번 72px. a1의 모루 몸통 방식)
  3. 차가운 회색 → 같은 밝기의 따뜻한 회색. 4. 계열 맞춤(a2와 같음). 5. 밝기 상한 215. 6. 외곽선 #1a1714(a2 소품 규칙. 덧댄 픽셀은 쇠창살 우리 2px뿐). 7. 24색 이하(CIELAB 가까운 두 색 합치기, 새 색 없음). 8. brief §4·crops_v03·items_v04 색과 ΔE76 6 미만이면 그 색으로
- 판정 (s1, 1배·3배. 크기 줄은 s4가 잰 값으로 고침): 통·상자·자루가 v02의 25~29px에서 19~21px로 내려와 "캐릭터만 한 통"은 사라졌다. 다만 허리~어깨 높이는 아니다: 캐릭터(28px)의 어깨는 발에서 12~13px, 옷깃 14px, 얼굴 15~21px(눈 18~21)이라, 19~21px인 통 a·b·상자 a·자루 a·항아리·땅 랜턴은 캐릭터 키의 68~75%, 눈 높이에 닿는다. 어깨·목 쪽은 작은 자루(14)·누운 통(16)·작은 통(17)뿐이다. 통(21) > 작은 통(17) > 작은 자루(14)의 차이는 1배에서 보인다. 공유 창고(키 19, 폭 44)와 견주면 상자 a·깨진 상자·깨진 항아리는 같고(19), 통 a(21)·통 b(20)·자루 a(20)·저장 항아리(20)·땅 랜턴(21)은 창고보다 1~2px 높다(v02 통 29보다는 8~10px 낮다). 처음 판정의 "허리~어깨 높이", "창고보다 낮거나 같다"는 틀렸다(아래 "### 검토 뒤 고침 (s4)"). 위협 쪽 사발·해골 더미·초·화로·우리도 캐릭터보다 작다(16~20px). 3배에서 상자는 정면 정렬, 누운 통은 수평이다
- 약한 것 (s1): 자루 a는 20px로 목표(자루 12~18)보다 2px 크다(묶은 자루 네 칸이 모두 20). 작은 자루는 입구가 열린 낟알 자루라 묶은 자루와 모양이 다르다. 땅 랜턴은 21px(폭 12)로 아직 캐릭터의 3/4이라 작은 랜턴 기둥처럼 보인다. 상자는 4칸 중 1칸만 정렬됐고, 낡은 상자(#46)·쌓은 상자(#47)는 이번에도 모두 3/4라 v03이 없다. 깨진 항아리 19·저장 항아리 20은 "키 큰 항아리"라 통 쪽 크기로 봤다

### 2. 손질 (s2, 생성 없음)

`stage4_fix5.py`. 입력은 우리 4단계 파일(04-env의 v01·v02)과 03-pixel `base_body_v02_walk.png`(전후 시트의 키 비교용)뿐이다. 전후 시트 `stage4_s2_compare.png`(4배, 2200×3176).

1. 키 큰 소품: 기둥·대만 늘리고 윗부분(랜턴·초·팔)은 픽셀까지 v02 그대로다. 기둥의 "기둥만 있는 줄"(그 줄에 기둥 칸 밖 픽셀이 없음을 검사)을 돌려 가며 끼워 넣고, 받침·발은 그만큼 내려간다. 아래 여백은 v02와 같다. 원본 object: 랜턴 기둥 a 64d703e7-04ed-426b-9f3b-946491943313, b 5eee75ee-4008-4156-b80e-4b02ba162858, c 28088a65-cd05-4099-90e8-92b25ab0ffa9, 촛대 a c285f17c-4589-4646-a91a-19a246b4e3df, b 2f2e8ca3-8ca0-4f5e-8772-771e69e61f67, c 2160e5a4-7ddd-437b-831e-83728bb09749

   | 파일 | 캔버스 | 키 v02 → v03 | 끼운 곳 (v02 줄) | 끼운 줄 | 발 줄 |
   |---|---|---|---|---|---|
   | `prop_lantern_post_a_v03.png` | 32×48 | 29 → 42 | 25 앞, 21~28줄 반복 | 13 | y45 |
   | `prop_lantern_post_b_v03.png` | 32×48 | 28 → 42 | 24 앞, 21~23줄 | 14 | y46 |
   | `prop_lantern_post_c_v03.png` | 32×48 | 30 → 42 | 21 앞, 19~22줄 | 12 | y46 |
   | `prop_candle_stand_a_v03.png` | 32×40 | 31 → 34 | 19 앞, 17~18줄 | 3 | y39 |
   | `prop_candle_stand_b_v03.png` | 32×40 | 29 → 34 | 20 앞, 20줄 | 5 | y38 |
   | `prop_candle_stand_c_v03.png` | 32×40 | 29 → 34 | 22 앞, 21줄 | 5 | y38 |

   - 촛대 불꽃 자리(공유 `flame_small_v01` 프레임 왼쪽 위, v03 파일 좌표): a (14, 0), b (15, −1), c 가운데 (15, −1)·왼쪽 (7, 4)·오른쪽 (22, 4). 불꽃 맨 아랫줄이 심지 줄에 앉는다
   - 판정: 기둥은 캐릭터보다 확실히 크고(42 대 28~30) 랜턴이 머리 위에 걸린다. 촛대는 불꽃까지 약 38px. 촛대 b는 짧은 손잡이 촛대였는데 금 대가 길어져 바닥 촛대로 읽힌다. 남은 흠: 기둥 b·c와 촛대 b·c는 끼운 줄이 한 색이라 긴 민무늬 대다(8배에서만 보임)
2. 랜턴 켜짐판 + 빛 마스크: 유리를 거룩한 불꽃 색으로 채웠다. a3 불꽃과 같은 넷만 쓴다: 심 #fff6dc(밝기 245.7, 제단 불꽃과 같은 값) 255, #f4c95d 205, #c9932b 150, #9c6a1f 100(`_emissive.png`의 RGB = 빛 세기, 빛나는 픽셀만 A=255). 유리 몸은 #f4c95d 이하, 가운데만 심이다. 켜짐판은 정지 그림이고 흔들림은 엔진 빛 세기로 준다고 보았다(유리가 3~4px라 불꽃 프레임을 넣기에 작다). 원본 object: 땅 랜턴 bd2fe0f4-1393-4def-9dea-67088b62bb0b, 벽 랜턴 34f428e6-439b-4fea-8be0-411775f36306 (기둥은 1번)

   | 켜짐판 | 유리 칸 (포함) | 빛 가운데 (엔진 점광원) | 꺼짐 짝 |
   |---|---|---|---|
   | `prop_lantern_post_a_v03_lit.png` | (21,19)–(24,22) | (23, 21) | `prop_lantern_post_a_v03.png` |
   | `prop_lantern_post_b_v03_lit.png` | (21,16)–(23,19) | (22.5, 18) | `prop_lantern_post_b_v03.png` |
   | `prop_lantern_post_c_v03_lit.png` | (14,13)–(17,15) | (16, 14.5) | `prop_lantern_post_c_v03.png` |
   | `prop_lantern_ground_v02_lit.png` | (15,19)–(16,24) | (16, 22) | `prop_lantern_ground_v02.png` |
   | `prop_lantern_wall_v02_lit.png` | (13,19)–(19,24), 창 x13~14·x18~19 | (16.5, 22) | `prop_lantern_wall_v02.png` |
   | `prop_lantern_ground_v03_lit.png` (s3, 아래 3절) | (9,12)–(14,16), 창 x9~10·x13~14 | (12, 14.5) | `prop_lantern_ground_v03.png` |

   - 땅·벽 랜턴은 꺼짐판이 v02 그대로라 `_v02_lit`이다(s1이 같은 시간에 만든 24px 땅 랜턴 v03은 다른 그림이라 짝으로 오해되지 않게 이름을 갈랐다)
   - 판정: 어둡게 한 풀 위 4배와 1배에서 다섯 모두 켜진 랜턴으로 읽힌다. 땅 랜턴 v02는 2px 기둥이라 가장 약하다
3. 성물 제작대 `relic_bench_v03.png` (원본 object 4c83e07f-5365-41c4-ae97-162ff899e597): 초 위 3px 정지 불꽃 7픽셀을 지우고 (38, 2)에 꺼진 심지 #1a1714. **공유 `flame_small_v01` 자리 (37, −4)**(맨 아랫줄 y2가 심지 x38을 덮는다). v02의 27색(brief §5.7에 적힌 예외)을 가장 가까운 적은 색 셋 합치기로 24색: #432f29→#402c25 (ΔE 1.6, 28px), #a97358→#a76f54 (1.7, 18px), #6c4e41→#67493c (2.1, 7px). 최대 밝기 214.2
4. 모루 `anvil_v03.png` (원본 280350f0-bad1-4854-8beb-8860af7111d9): 쇠 8색만 같은 색상 비로 밝혔다(R ≥ G ≥ B 유지): #302c29→#4d4742 (45→72), #4b4440→#6c625c (70→100), #6d645d→#83786f, #7d736b→#8f847a, #888076→#988f83, #979088→#a39c93, #a8a29b→#b1aba4, #d0ccc9 그대로(205). 20색. 1배에서 검은 덩어리가 아니라 회색 쇠 몸통 + 밝은 윗면으로 읽힌다
   - 기본 작업대 `workbench_v03.png` (원본 d98faed8-72ac-43b8-a327-95c73d5aff3e): 흐린 망치·톱 자국을 판 색으로 지우고, 끝에서 본 나무 망치 머리(2×5) + 짙은 자루와, 강철 날 + 이빨 + 손잡이의 톱을 손으로 그렸다. 대팻밥은 그대로. 20색, 최대 214.6. 3배에서 망치와 톱이 갈리고, 1배에서는 "판 위에 도구 둘"이고 망치는 블록 + 막대로 읽힌다. 첫 판은 도구마다 외곽선을 둘러 판 위가 검은 띠 둘로 보여 줄였다
5. 흙길 `tiles_grass-path_v03.png` + `.json`(v01 `.json`을 바이트 그대로 복사, 주소 없음, 타일셋 cace8d41-ecb3-4017-baae-43ad0c60902a): 산울타리처럼 보이던 가장자리 초록을 타일셋에 이미 있는 밝은 가장자리 초록으로(새 색 없음): #445d37→#57734a, #57734a→#6e9762, #668260→#6e9762, #677160→#778768. 네 색 모두 풀 속 타일에는 없다. 27 → 24색. 시험 셋 중 이빨 끝에 얇은 짙은 점이 남는 판을 골랐다. 3배에서 짙은 울타리 테가 아니라 풀이 끝나는 그늘로 읽힌다
6. 던전 따뜻한 회색 소품 `prop_{rubble_a,rubble_b,rubble_c,pillar_stub_a,pillar_stub_b,pillar_stub_c,stalagmite_a,stalagmite_b}_v03.png` (원본 object: 잔해 a 9b603d6c-127b-4f63-96e1-e11f63c323b5, b ff2fe46d-53f7-42e7-8b91-65a183eb2923, c 6eef1212-a02b-41c1-80b2-6b5382b566c5, 기둥 토막 a d6ea7401-d1d4-4b7f-8e26-5cd4eafe2223, b 5d25de31-9da7-4c14-bbce-274da29a5c01, c df9135a0-0d4d-4154-b27a-5f17c646709f, 석순 a 1486fa54-1164-46fe-8d54-7adb5a252709, b e277cb56-a477-4841-b3de-c2e79e83398f)
   - 외곽선을 뺀 밝기 60 이상 색을 같은 색상 비로 L → L + (215 − L) × 0.30 (최대 213.2). 바닥 그림자: 맨 아래 4줄 모양을 (+1, +1)·(+2, +1)로 옮긴 빈 칸을 불투명 #24201c로(18~36px, 외곽선 24와 바닥 줄눈 43 사이 값). 16~22색
   - 시험 넷 중(밝은 면만 25~35% 밝히기, 그림자 있음·없음) 몸통까지 30% + 그림자만 여덟 모두 1배에서 바닥과 떨어졌다. **그림자를 구웠으므로 던전 바닥 전용**이다(풀밭에서는 오른쪽 아래에 어두운 조각)
7. 아이템 (16×16)

   | 파일 | 원본 object | 한 일 | 색 / 최대 밝기 |
   |---|---|---|---|
   | `item_mould_clump_v03.png` | 1f61b344-eb77-4704-ae11-3b55823cafc0 | 거북·둥지처럼 보이던 덩이를 손으로 다시: 낮고 넓은 곰팡이 얼룩(15×8), #6f8f3a 몸 + #4b6127 아래 테 + #2e2a26 구멍 셋 | 4 / 123.7 |
   | `item_leather_c_v03.png` | 6a5e6552-f176-4231-b34d-48fe1fc7176d | 모양 그대로 색만 제단 등잔의 흙갈색 단계로(#4a2c1d / #5e3722 / #7a4a2e / #94603a) | 5 / 107.2 (v02 58) |
   | `item_candle_black_a_v03.png`, `_b_v03.png` | 9a8439ef-319d-43c4-9716-96f51df05b0b, 652c6db4-5078-4f6f-a65d-191fd345ed0e | 바깥 실루엣 바로 안쪽의 왼쪽·위 초 픽셀만 잿빛 테 #8c7b66, 왼쪽 위 모서리 #b2a693. 불꽃 색은 이단 불 ?라 쓰지 않음 | 7·8 / 170·167 |
   | `item_ore_iron_c_v03.png` | e74f2f7f-5007-4678-9c0a-0d9973303442 | 흩어진 부스러기 다섯 → 큰 덩이 하나 + 기댄 조각(v02와 같은 철·녹 색) | 7 / 202.9 |
   | `item_bone_charm_v03.png` | 10e743a5-78ce-4c9c-9e64-87824262eae0 | 닫힌 끈 고리 + 양쪽 송곳니 + 매달린 뼈. 위가 열린 첫 판은 새총처럼 보여 고리를 닫았다 | 6 / 200.7 |
   | `item_stone_block_v03.png` | 0fd7d2fd-4794-4698-bed2-873073554d8b | 3/4 → 정면 정렬(윗면 2줄 + 앞면 끌 자국) | 9 / 169.0 |
   | `item_ingot_copper_a_v03.png`, `_b_v03.png` | d0aa31e4-d655-4cd5-b9d4-ada7e0697f65, e088f9ef-dc32-4adc-9aaf-125046549645 | 3/4 → 정면 사다리꼴 주괴(b = 둘 쌓음), 구리 4색 | 5 / 158.4 |
   | `item_ingot_iron_a_v03.png`, `_b_v03.png` | 5bb1d4af-3661-417a-8823-c42a87ef3cc5, 171a0e9c-b207-4a62-9c5b-48a78cf42840 | 같은 모양, 철 4색 | 5 / 202.9 |
   | `item_planks_a_v03.png`, `_b_v03.png`, `_c_v03.png` | 934d6864-ef83-4562-9aaa-52c42b33245e, bfc7b2a0-7cad-4754-b56c-f7432185528c, fe0bb7a5-bcd5-4aed-a7fd-6d4e2233d4f2 | 3/4·비스듬 → 정면: a 끝이 엇갈린 판 셋, b 긴 판 하나, c 긴 판 위 짧은 판. 끝을 맞춘 첫 판은 서랍장처럼 보였다 | 5~6 / 160.4 |
   | `item_cloth_a_v03.png` | 411f0a01-bb51-4e85-922a-b40feff87c56 | 3/4 → 정면: 개어 쌓은 상아 천 | 7 / 212.2 |

   - 재료 아이콘의 정면 정렬은 a4가 사람이 볼 일로 남긴 것이라 v02(3/4)와 v03(정면)을 둘 다 둔다. 3배에서 돌 블록·주괴·널판·천으로 읽히고, 1배에서는 주괴·널판이 작은 가로 막대라 v02보다 덜 눈에 띈다
8. 건설 벽 `build_stone_candA_v02.png`, `build_wood_candB_v02.png` (? 재질 후보 둘에 같은 손질, 고르지 않음): 문 폭 8 → 12px(문짝 x2~13 + 틀 1px, 닫힘·열림), candA 바닥만 시트에 있던 색으로 한 단 어둡게(#7d705f→#6b5e4f, #897c6c→#7d705f, #6b5e4f→#5a5047, #5a5047→#4a423a. 밝기는 벽 윗면 약 131, 바닥 약 96, 앞면 67). 16·14색 그대로. 문이 8px보다 캐릭터 몸 폭에 가까워졌고, candA 방 안 바닥이 벽 윗면과 갈린다. 다만 문짝 12px는 캐릭터 몸 폭(15~17px)보다 아직 좁고, 열린 통로는 폭 10px·높이 17~19px라 캐릭터(28px)를 세우면 머리가 문 위로 나온다(s4가 잰 값, 아래 3절 "5. 약한 것"). 남은 흠은 a4 기록 그대로(candB 북쪽 앞면이 울타리 같음, 세로 벽 옆문·풀 쪽 바닥 가장자리 없음, gameplay-design §3.3 ?)
9. 제단 업그레이드 `altar_up1_candA_v02.png` + `_unlit`·`_litbase`·`_emissive` (? 후보 그대로): 26 → 24색. #8a5a34 → #94603a (ΔE 3.2, 18px), #ad9c7a → #a48d6b (5.9, 12px). 더 가까운 짝은 돌 무늬 색(250~400px)이라 두었다. 켜짐 24, 바탕 23, 꺼짐 23색. 4배·8배에서 차이가 안 보인다

### 3. 통합 (s3, 생성 없음)

1. 새 파일 확대 검토(4~8배와 1배, 풀·던전 바닥 위) → 작은 손질 둘(`stage4_mockup.py fix2`)과 탈락 하나
   - `prop_candles_black_b_v04.png`: s1 v03이 10색의 근흑 덩어리라 던전 바닥에서 1배로 묻혔다. s2가 아이템 검은 초에 쓴 규칙(`stage4_fix5.candle_rim`: 바깥 외곽선 바로 안쪽의 왼쪽·위 밀랍 → #8c7b66, 왼쪽 위 모서리 #b2a693)을 복사하지 않고 그대로 불러 17px. 12색. 불꽃 색은 쓰지 않았다(이단 불 ?)
   - `prop_lantern_ground_v03_lit.png` + `_v03_emissive.png`: s1의 24px 땅 랜턴에는 켜짐판이 없었다. 창 둘(x9~10·x13~14, y12~16)이 원래 뚫린 틈이라 그 칸만 s2와 같은 색·값으로 채웠다(가운데 기둥 쪽 x10·x13, y14에 심 #fff6dc). 빛 가운데 (12, 14.5). 20색
   - **탈락** `prop_barrel_smashed_v04.png`: 선 채 깨진 통에 큰 테 고리가 붙어, 1배·3배에서 부서진 통이 아니라 "고리 달린 어두운 통"으로 읽힌다. 깨진 통 후보는 a4의 `prop_barrel_smashed_v03.png`(32px 묶음, 키 28)로 남는다(크기 문제는 그대로). 파일은 지우지 않았다
   - 나머지는 깨진 것이 없었다
2. 목업 (`stage4_mockup.py surface5|dungeon6|scale`). 배치는 v04·v05와 같고 새 파일만 바꿔 넣었다. v04·v05·후보 시트는 다시 돌려도 바이트까지 같다
   - `stage4_mockup_v05_day.png`·`_1x`: 흙길 v03, 촛대 v03 a·b(공유 불꽃 새 자리), 공유 창고 옆 v03 통 a·상자 a·자루 a·작은 통·작은 자루, 기본 작업대 v03·모루 v03, 성물 제작대 v03(빈 심지 + 공유 불꽃), 랜턴 기둥 v03 셋(낮에는 꺼짐. a·c는 v04 자리, b는 큰길 아래 x96·발 214에 더함), 작업대 둘레에 떨어진 v03 재료(널판 a, 철 주괴 a, 돌 블록, 천 a), 잿빛 땅의 곰팡이 덩이 v03. 떨어진 재료는 **○ 미정 중 정면(v03) 쪽 안을 보여 준다**(정면이냐 3/4(v02)냐는 아래 6의 사람 확인. ? 항목은 아니다. s4가 이 줄에 밝혀 적음. v06도 같다) 나머지(밭, 제단, 불 바구니·모닥불, 채집물, 위협 소품, 다섯 클래스)는 v04와 같다
   - `stage4_mockup_v05_eve.png`·`_1x`: 같은 장면에서 랜턴을 켜짐판으로 바꾸고, 빛나는 유리(빛 마스크 칸)를 불꽃처럼 어두워지지 않는 층에 둔다. 랜턴의 빛 원은 안 5px·밖 32px로 제단(안 100·밖 150)보다 훨씬 작게 했다(빛 = 안전은 제단 빛이고, 건설 조명이 안전 반경을 만드는지는 문서에 없다). 성물 제작대 불꽃에 작은 빛(4·26)을 더했고, 나머지 어둡게 하기는 v04와 같은 값이다
   - `stage4_dungeon_v06.png`·`_1x`: 왼쪽 판(지상의 던전 입구)은 v05와 같다(같은 함수). 오른쪽 방: 이단의 제단 둘레를 v03 위협 소품(화로 c, 검은 초 a, 해골 더미, 제물 그릇) + 검은 초 b v04 + 쇠창살 우리 v03 + 아이템 검은 초 a v03·뼈 부적 v03으로, 창고 구석을 v03 상자·통 b·작은 통·자루 b·항아리·깨진 항아리로, 잔해·기둥 토막·석순을 v03(바닥에서 뗀 판)으로 바꾸고, 철광석 c v03과 창고 구석에 플레이어가 놓은 켜진 땅 랜턴 v03을 더했다. 이단의 불은 그대로 꺼 두었고 보스 구역 기둥 후보는 넣지 않았다(v05와 같은 처리). 던전은 v05처럼 어둡게 하지 않았다
   - `stage4_scale_compare_v01.png` (3배): 줄마다 같은 바닥 줄에 캐릭터(기본 몸 걷기 남, 28px)와 옛 판 → 새 판을 나란히 둔다. 풀밭 셋(통·상자·자루 + 공유 창고 / 깨진 것·항아리·땅 랜턴(꺼짐·켜짐) + 기본 작업대 / 랜턴 기둥·촛대, 촛대에는 공유 불꽃), 던전 바닥 하나(위협 소품, 검은 초 b는 v02 → v03 → v04). 금빛 점선 = 캐릭터 키, 연한 점선 = 타일 16px. 라벨의 숫자는 파일의 불투명 키(불꽃 제외)
   - 목업 본 판에 ? 후보는 없다(`_candA`·`_candB` 파일, 이단의 불, 보스 기둥 모두 뺌). 낮·저녁판의 나뭇가지 채집물(`item_sticks_a_v02`·`item_sticks_b_v02`)은 v04처럼 그대로 두었다. game-concept §12 ?(나무 = 목재 원천을 슬라이스에 넣을지)와 닿을 수 있어 사람이 본다
3. 측정과 규칙 검사
   - §6 측정(`arttool.py measure`): `stage4_mockup_v05_day`·`_eve`·`stage4_dungeon_v06`(3배·1배)과 `stage4_scale_compare_v01` 모두 차가운 색 0%, 보라 0.00% (OK)
   - 가장 밝은 점: 세 목업 모두 거룩한 불꽃 심 #fff6dc(245.7)이다(켜진 랜턴 유리의 심도 같은 값). 215를 넘는 나머지는 v04·v05와 같은 것들이다: 풀꽃 점(222.6·225.8), 성직자 후광(237.4), 3단계 캐릭터 얼굴·눈(218~232), 던전 광부의 곡괭이 날 #e4ded2(222.4, 3단계)
   - 손질 규칙 검사(`stage4_mockup.py rules`. 손질 2의 채택 후보 70장 = s1 18 + s2 49 + s3 3. 탈락한 깨진 통 v04와 시트·미리보기는 뺌): 아이템 16색·소품과 오브젝트 24색 이하, 최대 밝기 215 이하(불꽃 심 #fff6dc을 뺀 값. 가장 높은 것 기본 작업대 214.6), 파란·보라 기운 회색(B > R이고 채도 0.35 미만) 0, 반투명 0, 빛 마스크는 회색 값 100·150·205·255(제단 205·255)와 알파 0/255뿐. 외곽선은 가장자리(투명과 닿은) 불투명 픽셀 중 #1a1714 비율로 쟀다
   - 예외: (가) 켜진 랜턴 여섯과 제단 candA 켜짐판에 불꽃 심 #fff6dc(245.7)가 있다(제단 불꽃과 같은 값이라 규칙 안의 예외). (나) 흙길 v03의 최대 225.8은 풀꽃 점(a4 기록의 허용 범위)이고, 바닥 타일이라 외곽선이 없다(lineless). (다) 던전 소품 v03 여덟은 외곽선 비율이 70~86%다. 가장자리에 구운 바닥 그림자 #24201c가 있어서이고, 그림자를 빼면 92~100%(v02와 같은 값)다. (라) 촛대 c v03은 85%: 양쪽 초 옆면이 짙은 갈색 #55382d 테다. v02에서 그대로 온 것(84%)이라 고치지 않았다. (마) 건설 벽 두 시트는 53%다. 타일 시트라 벽 윗면이 이웃과 이어지는 쪽은 일부러 외곽선을 두르지 않는다(a3 설계). (바) 90%를 넘지만 100%가 아닌 것: 쇠창살 우리 v03 93%, 제단 candA v02 94%(바탕·꺼짐판 99%), 촛대 a v03 94%, 땅 랜턴 v02 켜짐판 95%, 촛대 b v03 98%, 랜턴 기둥 b v03·켜짐판 99%, 부서진 상자 v03 99%, 깨진 항아리 v03 99% (s4가 빠진 것을 채웠다. 처음에는 넷만 적었다)
4. 판정 (brief §7, 1배와 3배)
   - 크기 (s4가 잰 값으로 고침): 낮판 1배에서 공유 창고 옆 통 a(21)·자루 a(20)·상자 a(19)는 캐릭터 키의 68~75%, 눈 높이이고, 작은 통(17)·작은 자루(14)가 어깨~턱 쪽이다. 통 a는 아직 창고(19)보다 높다: 판에서 통 꼭대기 y96, 창고 꼭대기 y99로 3px 위다(v04에서는 10px 위). 자루 a는 창고와 같은 줄(y99)이다. 처음 판정의 "허리~어깨 높이이고 창고보다 낮다"는 틀렸다(고친 판은 아래 "### 검토 뒤 고침 (s4)"의 v06). 랜턴 기둥은 캐릭터보다 확실히 크고 랜턴이 머리 위에 있다. 촛대는 불꽃까지 캐릭터보다 조금 크다. 던전의 위협 소품·창고 구석도 캐릭터보다 작다
   - 저녁: 켜진 랜턴 셋이 1배에서 작은 금빛 점 + 작은 빛 웅덩이로 읽히고, 제단 빛이 여전히 가장 크다. 촛대·성물 제작대의 공유 불꽃이 새 자리에 앉는다
   - 모루 v03은 1배에서 회색 쇠 몸통으로 읽힌다. 기본 작업대의 망치·톱은 3배에서 갈리고 1배에서는 도구 둘 정도다. 흙길 가장자리는 3배에서 울타리 테가 아니다
   - 던전: 잔해·기둥 토막·석순 v03이 1배에서 바닥과 떨어진다. 검은 초 b v04는 테 덕에 1배에서 실루엣이 남지만 여전히 이 방에서 가장 어둡다. 켜진 땅 랜턴 v03은 1배에서 금빛 창 둘로 읽힌다
   - 3배: 모두 읽힌다. 아이템 v03(곰팡이 얼룩, 가죽, 철광석 덩이, 뼈 부적, 정면 재료)은 v02의 약한 점이 풀렸다
5. 약한 것 (사람 확인 전, 고치지 않음. "(s4)"는 검토 뒤 s4가 더한 줄)
   - 자루 a v03 20px(목표 12~18보다 2px. s4 v04는 18), 땅 랜턴 v03 21px(캐릭터의 3/4, 작은 기둥처럼 보임), 정렬된 상자는 1종(crate_a v03)뿐(낡은 상자·쌓은 상자 v03 없음). 다시 하려면 생성이 든다(밤 상한 46회 중 1회만 남음)
   - (s4) 통 a·b와 자루 a v03이 아직 공유 창고보다 높다: 통 a 21, 통 b 20, 자루 a 20 대 창고 19. 낮판 v05에서 통 a 꼭대기가 창고보다 3px 위다(a4의 "통이 창고보다 높다"가 10px에서 3px로 줄었을 뿐). s4가 몸통 줄만 지운 v04(통 a 19, 통 b 18, 자루 a 18)와 낮·저녁 목업 v06으로 고쳤다(아래 "### 검토 뒤 고침 (s4)"). 저장 항아리 v03(20)과 땅 랜턴 v03(21)도 창고보다 높지만 창고 옆에 놓이지 않아(던전·비교 시트) 고치지 않았다
   - (s4) 건설 벽 문(두 ? 후보 v02, 같은 모양): 문짝 12px(x2~13, 틀 포함 14) 대 캐릭터 몸 폭 15~17px(머리 16~18px). 열린 통로는 폭 10px, 높이 17~19px(나무 17, 돌 19. 문 꼭대기~문턱은 나무 20px, 돌 아치 22px) 대 캐릭터 키 28px라, 캐릭터를 열린 문에 세우면 통로를 다 덮고 머리가 문 위로 나온다. 폭은 16px 칸 안에서 문짝 14px까지(틀을 한쪽만 두거나 돌 아치 틀을 문짝에 넣음) 넓힐 수 있지만 그래도 몸보다 좁다. 높이는 a3의 24px 벽 앞면과 gameplay-design §3.3 ?(벽이 바닥 위 별도 층인지)에 달려 고치지 않았다(사람이 정한다)
   - (s4) 던전 따뜻한 회색 소품 v03은 R·G·B를 같은 비로 밝혀 채도도 올랐다(CIELAB 평균 채도 v02 13~19 → v03 16~25, 색상 63~69°. §4 기반 회색 #4a423a·#6b5e4f·#8c7b66은 6~14). 3배에서 석순·잔해가 살구·사암빛으로 읽힌다(따뜻해서 차가운 회색 규칙은 통과). s4가 L*만 올린 v04(채도 = v02)와 던전 목업 v07로 고쳤다. v04도 채도 13~19라 §4 회색보다는 따뜻하다(생성된 v02의 색상 그대로)
   - 던전 창고 구석에서 상자 v03(세로 널판)과 통이 1배에서 비슷하게 보인다. 검은 초 a v03(해골 + 초)은 3배에서 귀 달린 작은 짐승처럼도 보인다
   - 낮판에 떨어진 재료 v03: 천 a는 1배에서 크림색 덩어리(빵·비누처럼), 돌 블록은 회색 상자처럼 보인다. 정면 재료 아이콘을 쓸지는 아래 6의 사람 확인과 같다
   - 랜턴 기둥 b·c와 촛대 b·c의 늘린 대가 한 색 민무늬다(8배에서만). 땅 랜턴 v02 켜짐판은 2px 기둥이라 가장 약하다
   - 던전 소품 v03은 그림자를 구워 던전 바닥 전용이다(풀밭에 쓰려면 그림자 없는 판이 따로 든다). 불 바구니 통나무 끝 주황(a4 "약한 것")은 이번에 다루지 않았다
   - 철·녹 6색이 §4 팔레트 밖인 것(a4)은 그대로다
6. 사람이 정할 것
   - ? 항목 넷(제단 업그레이드 1단계 모습, 건설 벽 재질, 이단 쪽 불의 색, 보스 구역의 광부 지형 요소)은 위 "### 4. 통합"의 5와 같다. 손질 2에서는 건설 벽 두 후보와 제단 candA에 같은 손질만 했고(v02), 후보 시트 `stage4_candidates_v01.png`는 다시 만들지 않았다(v01 그림 기준)
   - ○ 땅에 떨어진 재료 아이콘을 정면 정렬(v03)로 할지 3/4(v02)로 둘지 (a4에서 남긴 것)
   - ○ 건설 조명(랜턴)의 빛이 안전 반경을 만드는지. 목업에서는 제단보다 작은 장식 빛으로만 그렸다
   - ○ (s4가 더함. s2가 혼자 정한 것) 켜진 랜턴 여섯은 공유 큰 불꽃(`flame_large_v01`, a3 기록 "건설 조명·화로용")을 쓰지 않고 유리를 정지 그림으로 채웠다(흔들림은 엔진 빛 세기로 준다고 봄). 유리 심 #fff6dc(245.7)는 제단 불꽃 심과 같은 밝기다(랜턴마다 2~4px). brief §5.7 본 제작 계획은 4 + 1프레임 불꽃을 등잔·조명·성물 촛불이 같이 쓴다고 적었으므로, 랜턴도 불꽃 프레임을 쓸지, 심을 제단보다 어둡게 둘지(제단 불꽃만 가장 밝게) 사람이 정한다. 그 밖의 빛 규칙(같은 네 색, 빛 마스크 = 켜짐판과 꺼짐판이 다른 픽셀, 세기 255/205/150/100)은 맞다
   - ○ 자루·땅 랜턴·상자를 남은 1회나 새 승인으로 다시 뽑을지
   - ○ (s4) 작은 소품의 목표 키(아래 "### 검토 뒤 고침 (s4)"의 표). 기록에 남은 목표는 s1의 자루 12~18뿐이고, 나머지는 s4가 캐릭터 몸 높이와 공유 창고(19)로 낸 제안이다
7. 요령
   - size 24 묶음도 64칸, 값 10회다. size 24는 캔버스를 다 채우지 않았다(통 20~21, 작은 통 17, 누운 통 16, 자루 18~20, 사발·화로 16~17). 크기를 말로 쓴 칸("small keg", "short and squat")은 그만큼 작게 나왔다. 바닥 그림자 타원은 그리지 않았지만, "dust at its base"를 쓴 칸은 흙먼지를 불투명하게 그렸다
   - 상자 정렬은 size 24에서도 약했다(같은 설명 4칸 중 1칸, 다른 상자 설명 6칸은 0칸). 둥글거나 앞면이 높은 물건(통·자루·항아리·사발·우리)은 모두 정면으로 나왔다
   - "grain"은 금빛 낟알로 나와 금화처럼 읽혔다 → 생활 쪽 노란 재료는 손질로 나무색에 맞춘다
   - 몸 전체가 아주 어두운 물건(검은 밀랍)은 외곽선 규칙(밝기 25 미만 → 외곽선)이 몸을 지운다 → 안쪽만 먼저 올린다. 어두운 바닥 위에서는 바깥 왼쪽·위의 잿빛 테가 불꽃 색 없이 실루엣을 살린다
   - 키 큰 소품은 다시 뽑지 않고 기둥 줄을 끼워 늘리면 윗부분이 픽셀까지 그대로라, 켜짐판·불꽃 자리를 그대로 옮길 수 있다
   - 이번에는 생성을 한 에이전트만 했고, 전후 잔액 차이와 응답의 cost가 같았다(본 제작 요령대로)

### 검토 뒤 고침 (s4)

손질 2(PR #47) 검토의 지적 8개를 하나씩 다시 재 보고 모두 맞다고 봤다. 손으로 고칠 수 있는 것은 고치고 나머지는 기록을 고쳤다. **PixelLab 0회**(생성 없음, 무료). ? 항목은 고르지 않았고 새 후보도 만들지 않았다. 새 판은 새 이름이고 옛 파일은 그대로다(예외: 라벨만 고친 `stage4_scale_compare_v01.png`, 아래 7).

- 스크립트: `tools/art/stage4_fix6.py {all|props|boards|compare|rules|check}` (s4, 새 파일). `stage4_mockup.py`는 라벨 고침과 새 판을 만들 인자(`SWAP`, `surface5(day, eve_name)`, `dungeon6(out)`, `scale_compare(rows, out, head, guides)`)만 더했다. 기본값이면 s3 출력과 같다. 입력은 우리 4단계 파일과 03-pixel `base_body_v02_walk.png`뿐이다
- 재현: `stage4_fix6.py all`을 작업 트리와 다른 폴더에서 두 번 더 돌려 04-env 전체의 sha256이 같았다. `stage4_mockup.py all`을 다시 돌리면 s3 출력 중 `stage4_scale_compare_v01.png`(라벨)만 바뀌고 나머지는 바이트까지 같다(고치기 전 sha256과 비교)

1. 작은 소품 키 판정 (medium) → 맞음. 기록 고침 + 통·자루 v04 + 낮·저녁 목업 v06
   - 잰 값 (`stage4_fix6.py check`): 캐릭터(기본 몸 걷기 v02 남 첫 프레임)는 28px다. 발에서 잰 높이로 몸통·허리 1~11, 어깨 12~13(폭 13~15), 옷깃 14, 턱·얼굴 아래 15~17, 눈 높이 18~21(폭 16~18), 머리카락 22~28. s1 v03의 통 a 21·통 b 20·자루 a 20·저장 항아리 20·상자 a 19·깨진 상자 19·깨진 항아리 19·땅 랜턴 21은 캐릭터의 68~75%로 눈 높이다. 공유 창고 19보다 통 a·b, 자루 a, 저장 항아리, 땅 랜턴이 1~2px 높다. 낮판 v05에서 통 a 꼭대기는 y96, 창고 y99(3px 위), 자루 a y99(같은 줄)
   - 기록 고침: "### 1."의 판정 줄과 "### 3."의 4. 판정 크기 줄을 잰 값으로 바꿨고, 3. 5. 약한 것에 "통 a·b와 자루 a가 아직 창고보다 높다"를 더했다
   - 목표 키 (○ s4 제안, 사람 확인 전). 기록에 남은 목표는 s1의 자루 12~18뿐이다(s1 지시에 있던 나머지 목표는 적혀 있지 않아 되살릴 수 없다). 나머지는 두 기준으로 냈다: a4가 약한 것으로 든 "통이 공유 창고보다 높다"에 따라 그릇·짐은 공유 창고(19) 이하, 작은 것은 큰 것보다 한 단 작게. 치비 몸이라 창고 19도 캐릭터 눈 높이다. "허리~어깨"(13 이하)로 맞추면 통이 작은 자루만 해진다

     | 묶음 | 목표 키 (○) | 근거 | 지금 (v03 → s4) |
     |---|---|---|---|
     | 서 있는 통 a·b, 상자, 저장 항아리 | 16~19 (창고 이하, 캐릭터의 57~68%) | a4 "통이 창고보다 높다" | 통 a 21 → **v04 19**, 통 b 20 → **v04 18**, 상자 a 19, 저장 항아리 20 (1px 넘음, 그대로) |
     | 묶은 자루 a·b | 12~18 | s1 목표 | 자루 a 20 → **v04 18**, 자루 b 18 |
     | 작은 통, 작은 자루 | 12~17 (어깨~턱) | 큰 것과 1배에서 갈리게 | 작은 통 17, 작은 자루 14 |
     | 누운 통, 깨진 상자·항아리 | 19 이하 | 눕거나 부서지면 낮다 | 누운 통 16, 깨진 상자 19, 깨진 항아리 19 |
     | 땅 랜턴 (손에 드는 크기) | 12~16 | s1 약한 것 "작은 랜턴 기둥처럼 보임"(기둥 42와 갈리게) | 21 (5px 넘음, 그대로) |
     | 위협 소품 (사발·검은 초·해골 더미·화로·우리) | 20 이하 | a4 "캐릭터만 한 소품" | 16~20 (검은 초 b는 v04 17) |

   - 고침 (`stage4_fix6.py props`): s2가 기둥 줄을 끼워 늘린 것의 반대로, 몸통만 있는 줄 둘을 지우고 그 위를 내렸다(발 줄은 그대로). 지우는 줄은 바로 위에 남는 줄과 불투명 폭이 같고 양 끝 말고는 #1a1714가 없어야 한다(테·끈 줄이 아님)고 스크립트가 검사한다

     | 새 파일 | 원본 (s1 object) | 지운 줄 (v03 y) | 키 | 색 / 최대 밝기 |
     |---|---|---|---|---|
     | `prop_barrel_a_v04.png` | `prop_barrel_a_v03` (6d0ccd43-b4a7-4798-9dd0-8f9e50648535) | 13·14 (테 사이 널 띠 y12~15 → 2줄) | 21 → 19 (= 창고) | 24 / 149.3 |
     | `prop_barrel_b_v04.png` | `prop_barrel_b_v03` (d68dc272-813a-4b60-b4a4-c81be8ef120e) | 13·14 (테 사이 널 띠 y12~16에서 2줄) | 20 → 18 | 24 / 129.4 |
     | `prop_sack_a_v04.png` | `prop_sack_a_v03` (08d200bf-9b0a-4ab2-afd4-4f7d6f44629e) | 13·14 (자루 몸통 y10~19 → 8줄) | 20 → 18 (s1 목표 안) | 17 / 166.0 |

   - 시험(스크래치, 8배): 통 a를 18로 하려고 위 띠 y7까지 지우면 뚜껑 쪽이 눌리고, 가운데 띠 셋(y12~14)을 지우면 테 둘이 붙어 보여서 19에서 멈췄다. 낮판에서 통 a는 창고보다 1px 뒤(발 117 대 118)에 서 있어 꼭대기가 1px 위(y98 대 y99)지만 키는 같다(19 = 19)
   - 목업 (`stage4_fix6.py boards`): `stage4_mockup_v06_day.png`·`_1x`, `stage4_mockup_v06_eve.png`·`_1x` = v05와 같은 배치·코드(`stage4_mockup.surface5`)에서 통 a·자루 a만 v04로 바꿨다(`stage4_mockup.SWAP`). v05와 다른 픽셀은 1배에서 266px이고 모두 상자 x342~388·y96~111 안이다. 떨어진 재료는 v05처럼 ○ 정면(v03) 쪽 안이다
   - 비교 시트 `stage4_s4_compare.png` (`stage4_fix6.py compare`, 3배, 2498×375): 풀밭 줄 = 캐릭터, 공유 창고, 통 a·통 b·자루 a의 v02 → v03 → v04, 상자 a·저장 항아리·땅 랜턴 v03. 던전 바닥 줄 = 던전 소품 여덟의 v02 → v03 → v04. 점선: 금빛 = 캐릭터 28, 상아 = 창고 19, 갈색 = 어깨 13. 글자는 Pillow 기본 글꼴(고정 pillow 11.3.0이면 같은 바이트)
   - 판정 (1배·3배): 낮판 v06 1배에서 통 a는 창고와 같은 키로 읽히고 자루 a는 창고보다 낮다. 3배에서 줄을 지운 자리는 보이지 않는다(테 사이 널 띠가 조금 짧을 뿐). 통 a > 통 b > 작은 통은 19 > 18 > 17이라 1배에서는 거의 같은 키다
2. 건설 벽 문 (low) → 맞음. 기록만 고침
   - 잰 값 (`stage4_fix5.DOORS`): 문짝 12px(x2~13, 틀 포함 14) 대 캐릭터 몸 폭 15~17px(머리 16~18). 열린 통로는 폭 10px, 높이 나무 17·돌 19px(문 꼭대기~문턱 나무 20, 돌 아치 22) 대 캐릭터 28px
   - s2 줄의 "드나드는 문으로 보이고"를 고치고 3. 5. 약한 것에 숫자를 적었다. 문짝을 14px로 넓히는 것은 ? 재질 후보 두 장을 함께 다시 그리는 일이고 그래도 몸보다 좁다. 높이는 a3의 24px 벽 앞면과 gameplay-design §3.3 ?에 달려 있어 사람에게 남긴다
3. 던전 따뜻한 회색 소품 (low) → 맞음. 소품 v04 + 던전 목업 v07
   - 잰 값 (CIELAB 평균 채도 / 평균 밝기, 외곽선·구운 그림자 제외. 던전 바닥 속 타일 채도 9.5, §4 기반 회색 #4a423a 6.4·#6b5e4f 10.9·#8c7b66 14.2)

     | 소품 | 채도 v02 → v03 → v04 | 밝기 v02 → v03 → v04 | 외곽선 v04 (그림자 빼고) |
     |---|---|---|---|
     | 잔해 a | 15.0 → 18.6 → 15.0 | 107.1 → 133.8 → 133.7 | 77% (92%) |
     | 잔해 b | 13.1 → 15.8 → 12.9 | 94.2 → 117.8 → 117.6 | 83% (97%) |
     | 잔해 c | 18.4 → 22.9 → 18.4 | 111.9 → 141.4 → 141.3 | 85% (93%) |
     | 기둥 토막 a | 16.3 → 19.6 → 16.2 | 112.3 → 137.4 → 137.4 | 72% (100%) |
     | 기둥 토막 b | 17.0 → 20.7 → 17.0 | 115.8 → 142.7 → 142.6 | 86% (99%) |
     | 기둥 토막 c | 15.5 → 19.2 → 15.5 | 103.8 → 130.2 → 130.1 | 70% (100%) |
     | 석순 a | 14.3 → 18.8 → 14.3 | 97.2 → 128.5 → 128.4 | 73% (98%) |
     | 석순 b | 18.8 → 24.9 → 18.8 | 96.4 → 130.3 → 130.2 | 86% (100%) |

   - 고침 (`stage4_fix6.py props`): `prop_{rubble_a,rubble_b,rubble_c,pillar_stub_a,pillar_stub_b,pillar_stub_c,stalagmite_a,stalagmite_b}_v04.png`. 입력은 v02(원본 object는 위 "### 2." 6번). s2의 규칙과 목표 밝기(밝기 60 이상 색을 L → L + (215 − L) × 0.30)는 그대로 두고, 그 밝기를 CIELAB L*만 올려 맞췄다(v02의 a*·b* 유지, 8비트로 반올림한 뒤 목표 밝기에 가장 가까운 쪽). 구운 바닥 그림자는 s2 함수 그대로라 알파 모양이 v03과 같다. 색 수 16~22(v03과 같음), 최대 밝기 213.2
   - 목업 `stage4_dungeon_v07.png`·`_1x` = v06 배치(`stage4_mockup.dungeon6`)에서 던전 소품 여덟과 창고 구석의 통 b만 v04로 바꿨다(1배에서 다른 픽셀 1,720px). 왼쪽 판, 이단의 불(꺼 둠), 보스 기둥 후보(넣지 않음)는 v06과 같다
   - 판정: 3배에서 석순·잔해·기둥 토막이 살구·사암빛에서 잿빛 돌 쪽으로 돌아왔고, 1배에서 바닥과 떨어지는 것은 v03과 같다(밝기가 같다). v04도 채도 13~19로 §4 기반 회색(6~14)보다 조금 따뜻하다. 생성된 v02의 색상(63~69°)을 그대로 둔 값이고, 더 회색으로 하려면 a*·b*를 §4 쪽으로 섞는 손질을 따로 한다
4. 켜진 랜턴 (low) → 맞음. 기록만 고침 (3. 6. 사람이 정할 것에 ○ 줄)
   - 확인: 여섯 모두 빛 마스크의 불투명 픽셀 = 켜짐판과 꺼짐판이 다른 픽셀이고, 색은 #fff6dc / #f4c95d / #c9932b / #9c6a1f뿐, 심은 랜턴마다 2~4px. 빛 규칙은 맞고, 공유 큰 불꽃 대신 정지 유리를 쓴 것과 심이 제단 불꽃과 같은 밝기인 것을 s2가 혼자 정했으므로 사람이 정할 일로 적었다
5. 목업 본 판의 v03 재료 아이콘 (low) → 맞음(금지는 아님). 기록만 고침
   - 3. 2. 목업 줄에 "○ 미정 중 정면(v03) 쪽 안을 보여 준다"를 밝혀 적었다. 본 판은 v06에서도 v03이다. v02로 바꾸지 않은 까닭: brief의 정렬형 규칙에 맞는 쪽이고, a4가 사람에게 물은 것도 "떨어진 아이템도 정면이어야 하는지"이기 때문이다. v02와 v03은 `stage4_s2_compare.png`의 아이템 줄에 나란히 있다
6. 스크립트 안의 기록 경로 (low) → 맞음. `stage4_props24.py`·`stage4_fix5.py`의 docstring이 커밋되지 않은 `_records/s1.md`·`s2.md`를 가리켜서, 이 파일의 "### 1." / "### 2."로 고쳤다(출력에는 영향 없음). s4 기록도 이 절에만 있다
7. 크기 비교 시트 라벨 (low) → 맞음. `stage4_mockup.py scale`의 라벨만 고쳐 같은 이름으로 다시 만들었다(같은 PR 안·사람 확인 전이라 a5처럼 버전을 올리지 않음): "sack_b: v02 27 -> v03 18 -> sack_small v03 14 (new)", "barrel_smashed: v03 28 -> v04 21 (rejected)". 옛 판과 다른 픽셀은 이 두 라벨 줄(y51~61, y206~218)뿐이다
8. 기록 정밀도 (low) → 맞음. 기록만 고침
   - (a) "### 1." 표 48~50 칸: 24px 땅 랜턴은 창이 뚫려 있다(x9~10·x13~14, y12~16의 16px + 고리 2px가 투명. review 원본 칸에서도 창은 투명). "유리는 어둡고"를 고쳤다
   - (b) "### 3." 3. 예외 (바)에 빠진 것(촛대 b v03 98%, 랜턴 기둥 b v03·켜짐판 99%, 부서진 상자 v03 99%, 깨진 항아리 v03 99%, 제단 candA v02 바탕·꺼짐판 99%)을 채웠다

- 측정: §6(`arttool.py measure`) 낮·저녁 v06, 던전 v07(3배·1배), `stage4_s4_compare`, 다시 만든 `stage4_scale_compare_v01` 모두 차가운 색 0%, 보라 0.00% (OK). 가장 밝은 점은 세 목업 모두 그대로 거룩한 불꽃 심 #fff6dc(245.7)
- 손질 규칙 검사(`stage4_fix6.py rules`, s4 새 파일 11장): 소품 24색 이하(통 24·24, 자루 17, 던전 16~22), 최대 밝기 213.2, 파란·보라 기운 회색 0, 반투명 0. 외곽선은 통·자루 100%, 던전 소품 v04는 v03과 같은 예외 (다)(구운 그림자, 빼면 92~100%)
- 남은 것 (고치지 않음): 저장 항아리 v03 20(목표보다 1px)과 땅 랜턴 v03 21(5px)은 줄 지우기를 하지 않았다(항아리는 창고 옆에 놓이지 않고, 땅 랜턴은 5px을 줄이면 창·고리 모양이 바뀐다). 문 크기, 랜턴 불꽃·심 밝기, 정면 재료 아이콘, 목표 키 표는 사람이 정한다(3. 5·6)

## M7 나무·그루터기 (2026-10-25, PixelLab 3회 사용)

슬라이스 M7(game-concept §12 R37 "나무 1종 = 목재 원천, 누구나 벤다", brief §5.7 범위 표 "나무": ● 나무 1종과 벌목 동작, ○ 도구는 도끼)에 필요한 나무 그림·그루터기·도끼질 몸 동작을 만들었다. 사람이 이 일 전체에 PixelLab 12회를 승인했다(2026-10-25, 사람이 자리에 없어 질문하지 않음). **이 일에서 8회를 썼다**: 나무 3회(이 절), 도끼질 5회(03-pixel/prompts.md "PixelLab 14차"). 잔액 1,709 → 1,701, 4회는 검토 뒤 다시 뽑기용으로 남겼다. 같은 시각에 PixelLab을 쓴 다른 작업은 없어서 잔액 차이가 모두 이 일의 값이고, 생성 호출마다 앞뒤로 `get_balance`를 불러 값을 확인했다. 힉스필드는 쓰지 않았다. 나무는 글만 썼고(이미지 레퍼런스 없음), 다른 사람 팩 이미지는 어디에도 넣지 않았다. 내려받기 주소는 적지 않는다(계정 경로가 들어 있다). 모두 채택 후보이고 사람 확인 전이다.

### 1. 나무 후보 (`create_map_object`, 1장 1회)

공통: 기본 모드(바탕 그림 없음, 배경 투명), `view: "low top-down"`, `outline: "single color outline"`, `shading: "medium shading"`, `detail: "medium detail"` (작업대·모루와 같은 설정). 정렬 문구 "seen straight from the front, flat elevation"과 "standing on a level ground line exactly horizontal"을 넣었다. 원본은 `tree_v01_{a,b,c}.png` (받은 그대로).

| 판 | 캔버스 | object | job | 값 (잔액) | 그림 | 판정 |
|---|---|---|---|---|---|---|
| a | 48×64 | a08110dd-ca72-422e-abe9-3a80a6b4b0bd | c60fbd0e-9330-40f9-bb43-4c7e002e2341 | 1 (1,709 → 1,708) | 42×52, 31색 | 탈락. 둥근 덤불 수관에 짧은 줄기. 밑동에 풀 조각을 그렸고("no grass or ground patch"인데도), 수관이 노란 올리브라 풀·병든 올리브와 가깝다 |
| b | 64×80 | 78e8c178-2c8b-4ac0-b70f-3881711c92dd | 054848e9-b4e8-40ea-8fed-5e724ff8a606 | 1 (→ 1,707) | 52×72, 29색 | **채택**. 덩어리 서넛의 둥근 수관, 두 갈래 가지로 갈라지는 굵은 줄기, 퍼진 뿌리가 1배에서 보인다. 풀 조각·그림자 없음, 정면 정렬. 흠: 수관 밝은 면이 올리브 노랑(#9db043, 색상 70°, 풀 #80bd5a와 같은 밝기)이라 풀밭에 묻힘, 수관 가장자리가 청록 어둠(#1b322c, 차가운 색), 껍질이 분홍빛 갈색, 외곽선이 보랏빛 검정, 가운데 곧은뿌리가 땅줄 아래로 2px |
| c | 48×72 | a2d45c9e-cbe8-49cc-9047-0ce6ff58ff34 | 2ec3c79b-f1ca-4c0e-8e48-2a2aa57c09b1 | 1 (→ 1,706) | 41×64, 30색 | 탈락. "clearly darker than meadow grass"라고 했는데 채도 높은 연두의 원뿔꼴 수관(배나무·침엽수처럼), 가늘고 어두운 줄기 |

- description
  - a: "a single round leafy broadleaf tree seen straight from the front, flat elevation: a big round bushy crown of clumped leaves in warm deep greens with soft yellow-green highlights and dark warm brown-green shadows, under it a sturdy straight brown trunk clearly visible for its lower third, the trunk base slightly flared with a few small roots standing on a level ground line exactly horizontal, the trunk centred, not rotated, not isometric; no grass or ground patch at its base, no shadow, no fruit, no flowers, no face; cozy warm colours"
  - b: "a tall oak tree seen straight from the front, flat elevation: a broad rounded crown made of three or four big clumps of leaves in warm rich greens with light yellow-green highlights and dark warm olive shadows, a thick brown bark trunk clearly visible between the crown and the ground, its base flaring into short roots standing on a level ground line exactly horizontal, the trunk centred, not rotated, not isometric; no grass or ground patch at its base, no shadow, no fruit, no flowers, no face; cozy warm colours"
  - c: "a sturdy leafy tree seen straight from the front, flat elevation: a rounded crown of big leaf clumps in deep warm forest greens, clearly darker than meadow grass, with light yellow-green highlights on the top of each clump and dark warm brown-green shadows underneath, a thick brown bark trunk clearly visible below the crown with one short side branch, its base flaring into short roots standing on a level ground line exactly horizontal, the trunk centred, not rotated, not isometric; no grass or ground patch at its base, no shadow, no fruit, no flowers, no face; cozy warm colours"
- 요령: 세 판 모두 정면 정렬로 나왔다(앞면이 높은 물체는 정렬 문구로 잘 된다는 4단계 결과와 같다). 값은 캔버스 크기(48×64 ~ 64×80)와 상관없이 1회였다. 큰 캔버스의 b도 캔버스를 거의 채웠다. 글의 색("warm deep greens", "clearly darker than meadow grass")은 지켜지지 않아 색은 손질로 맞췄다(4단계 요령과 같음)
- 고른 이유: b가 "벨 수 있는 나무"로 가장 잘 읽힌다(줄기·밑동·뿌리가 1배에서 보인다). 크기는 캐릭터(걷기 키 28~29px)의 약 2.5배로, 480×270 화면에서 나무로 읽히고 제단(57px)보다 크며 목업에 8그루를 놓아도 화면을 덮지 않는다

### 2. 손질 (생성 없음, 무료)

`uv run -q --python 3.14.6 --script tools/art/m7_tree_axe.py tree` (고정 버전 `m7_tree_axe.py.lock`. `--python 3.14.6`을 빼면 SSH·샌드박스 셸에서 uv가 3.14 바로가기를 못 읽을 수 있다, os error 448). 다시 돌리면 같은 파일이 나온다(해시로 확인, 아래 4).

- `tree_v02.png` (64×80, 원본 b와 같은 캔버스·같은 자리)
  - 색: raw 29색 → 14색. raw 색마다 묶음·단을 표(`TREE_MAP`)로 정해 바꿨다
    - 수관 7단 #1f331c #2a4723 #375d2b #477633 #5a8f3e #6ea448 #98d072. 색상 95~112°로 생활 쪽 풀(#80bd5a, 97°)과 같은 쪽이고 병든 올리브(#6f8f3a, 82.6°, 오염 신호 brief §4)에서 12° 이상 떨어진다. 수관 몸통(#6ea448)은 밝기 137로 풀(160)보다 어둡게 해서 풀밭 위에서 덩어리로 갈린다. 어두운 초록은 모두 R ≥ B(차가운 색 아님)
    - 껍질 6단은 04-env 통나무 아이템 `item_log_v02`의 껍질 색 그대로 #3e241a #492312 #5b2e15 #794725 #8c5a2c #a96e43 (벤 나무와 떨어진 통나무가 같은 나무로 읽히게)
    - raw의 보랏빛·청록 어두운 색(#1c1327 #251a24 #2c1e27 #20242b, #1a2f2a #1b322c #22372e)은 실루엣 가장자리면 외곽선, 안쪽이면 수관 맨 아래 단(#1f331c)이나 껍질 맨 아래 단(#3e241a)
  - 땅줄: y 72 아래(가운데 곧은뿌리 끝과 오른쪽 뿌리 끝, 9px)를 지우고 72줄에서 닫았다. 맨 아래 불투명 줄이 곧 땅에 닿는 줄이다
  - 외곽선: #1a1714 1px (heretic.py와 같은 규칙: 가장자리 픽셀이 어두우면 그 자리를, 밝으면 바깥에 더함. 24px 바꿈, 87px 더함)
  - 결과: 그림 53×71 (x 6~58, y 2~72), 14색, 최대 밝기 180.5, 어두운 색 중 차가운 색 0, 반투명 0, 실루엣 가장자리 237/237이 외곽선 색
- `stump_v01.png` (64×80, 나무와 같은 캔버스·같은 줄기 자리. 게임에서 그림만 바꾸면 된다): 생성하지 않았다. tree_v02의 줄기 밑동(y 63~72의 줄기와 뿌리)을 그대로 두고, 그 위 y 59~63에 위에서 본 나이테 면(8×4 타원, `STUMP_CAP` 판)을 손으로 얹었다. 나이테 면 색은 통나무 아이템의 나뭇결·널판(`item_planks_a_v03`) 색 #d79149 #bc8440 #a05f22 #8c4a22. 그림 22×14 (x 22~43, y 59~72), 11색, 최대 밝기 157.7. 손 그림이 1배·3배에서 그루터기로 읽혀 생성 1회를 아꼈다

### 3. 미리보기·목업 (생성 없음, `m7_tree_axe.py preview`, `mockup`)

- `tree_v02_board.png` (912×1656, 글자 없음)
  - 맨 위 줄(1배) 셋: 낮 풀밭 띠(240×120: 나무 + 서쪽 칸에서 동쪽을 보고 도끼질하는 캐릭터(도끼 시트 동 3열, 날이 줄기에 닿음), 그루터기 + 남쪽을 보는 idle, 나무 + 바로 아래 칸에서 북쪽을 보고 도끼질(북 4열)) | 같은 띠의 저녁(왼쪽 나무만 제단 빛 안, 4단계 목업 `darken`과 같은 값) | 후보 a·b·c 원본, tree_v02, stump_v01
  - 둘째·셋째 줄: 낮·저녁 띠 3배
  - 넷째·다섯째 줄: `03-pixel/base_body_v02_axe.png`(위)와 `base_body_v02_sickle.png`(아래) 2배. 빨간 줄 = 발 줄 바로 아래(칸 y 48)
- `stage4_tree_mockup_v01_day.png` / `_eve.png` (3배) + `_1x` (480×270): 4단계 목업 코드(`stage4_mockup.py`의 `surface_ground`·`altar_lit`·`darken`)로 풀밭·흙길·제단(공유 불꽃, 저녁 빛 안 100px·밖 150px)을 깔고 나무 8그루, 그루터기 3, 도끼질하는 캐릭터 셋(동, 서 = 동 2열 반전, 북), 그루터기 옆 idle, 길을 걷는 캐릭터를 놓았다. 나무·그루터기는 아래 5의 자리 규칙, 그리기 순서는 발·자리 아래 변으로 y 정렬
- §6 측정(`arttool.py measure`): 목업 낮·저녁 3배·1배 모두 차가운 색 0%, 보라 0.00% (OK)

### 4. 판정과 남은 흠

- 1배: 나무는 풀밭 위에서 수관 덩어리 + 갈색 줄기로 바로 읽히고, 퍼진 뿌리가 보여 땅에 선 "벨 나무"로 읽힌다. 그루터기는 주황 나이테 면으로 1배에서 보인다. 저녁 빛 밖에서도 외곽선과 수관 명암으로 남는다
- 다시 돌리기: `all`을 두 번(`--script`와 `--with` 두 명령으로) 돌려 결과 9개 파일의 sha256이 같았다. 손질 규칙 검사(`check`): 나무 14색·그루터기 11색(24색 이하), 최대 밝기 215 이하, 차가운 어두운 색 0, 반투명 0, 가장자리 100% 외곽선
- 남은 흠 (고치지 않음)
  - 수관 밝은 면(#6ea448)이 풀(#80bd5a)과 색상이 같아 풀밭에서는 외곽선과 명암으로만 갈린다. 더 갈리게 하려면 수관을 한 단 더 어둡게 하거나 발밑 그림자(엔진)를 둔다
  - 줄기 북쪽 약 4칸 안에 선 캐릭터는 수관에 가린다(목업 왼쪽 아래, 길 위 캐릭터의 다리). 수관을 반투명으로 할지는 게임 쪽 일이다(○, M7b)
  - 그루터기 나이테 면이 8×4로 작다. 3배에서는 나이테가 보이고 1배에서는 주황 덩어리로 읽힌다
  - 나무는 한 장뿐이다(변형, 흔들림, 쓰러짐 프레임 없음). 벨 때 흔들림은 엔진에서 그림을 1px씩 옮기는 정도를 생각할 수 있다(○)
  - 껍질·나이테 색(통나무 아이템 색)은 04-env 채택 후보 색이고 §4 팔레트 밖이다(사람 확인)

### 5. M7b에 넘길 것 (game/은 고치지 않았다)

- 그림: `tree_v02.png`, `stump_v01.png` 64×80, 같은 캔버스·같은 자리. 벨 때 텍스처만 바꾼다. game/art/env/로 바이트 그대로 복사하고 game/README.md "그림 출처" 표와 `test_actors.gd`의 md5 목록에 더한다
- 자리: 줄기 1칸(자리 칸 = 막는 칸, 크기는 ○). 줄기(외곽선 포함)는 그림 x 29~36이고, 그림 열 32를 칸 가운데(칸 x 8)에 두면 줄기가 칸 x 5~12에 온다. 맨 아래 불투명 줄 72 = 자리 아래 변의 줄(`FixtureView` 조제대와 같은 규칙). 그림 왼쪽 위 = (tx·16 + 8 − 32, (ty + 1)·16 − 1 − 72). 노드 = 자리 아래 변(y 정렬). 뿌리는 옆 칸(그림 x 22~43)에, 수관은 위로 약 4.4칸·옆으로 1칸씩 그려질 뿐이다
- 빛: 월드 빛을 받는 그림(`Config.LIGHT_LAYER_WORLD`). 빛나는 픽셀 없음
- 도끼질 몸 동작은 03-pixel/prompts.md "PixelLab 14차"의 "M7b에 넘길 것"
