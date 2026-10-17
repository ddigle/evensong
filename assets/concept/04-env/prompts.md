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
