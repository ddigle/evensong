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
- 손질은 모두 스크립트로 했다(무료). 다시 돌리면 바이트까지 같은 파일이 나온다. 통합 때 `tools/art/`로 옮긴 뒤 다시 돌려 확인했다. 실행은 `uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I <스크립트> …`로 한다
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
   - `item_offering_cup_v03.png`: 굽 달린 잔이 성배로 읽힐 수 있어(신앙 상징 결정 전, game-concept §7) 굽·다리를 지우고 몸통 밑을 외곽선으로 닫아 4px 내렸다. 굽 없는 금 간 흙 잔이다. v02는 쓰지 않는다
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
   - 손질 규칙 검사(오늘 밤 채택 후보 168장): 아이템 16색·소품과 오브젝트 24색 이하, 생활 쪽 최대 밝기 215 이하(흙길 v02의 풀꽃 점 226은 허용 범위), 파란 기운 회색 0, 반투명 0, 오브젝트에 #1a1714 외곽선. 걸린 것 없음
   - 가장 밝은 점: 세 목업 모두 거룩한 불꽃 심 #fff6dc(246)이다. 215를 넘는 나머지는 풀꽃 점(223·226), 후광(237), 3단계 캐릭터 얼굴·눈 하이라이트(218~232, 이번 범위 밖)
   - 정렬형: 기본 작업대·모루·공유 창고·기둥 후보는 정면 정렬. 소품 묶음은 누운 통(51)·부서진 상자(52)만 조금 비스듬하다
   - 제단 빛 = 안전 (§7): 저녁판에서 빛 안의 밭·작업대·제단과 빛 밖의 채집물·오염 땅이 갈린다. 오염 땅은 덜 어둡게 해서 금과 장식이 남는다
   - 생활↔위협 대비 (§7): 낮판에서 따뜻한 풀·흙·나무와 잿빛 오염·뼈·꺼진 화로가 한 화면에서 갈린다. 보라는 가는 맥에만 있다
   - 1배: 제단과 등잔 불꽃, 창고, 작업대·모루·조제대·성물 제작대, 흙길(모래가 아니라 흙), 오염 소품(해골·우상·의식 돌·화로)은 읽힌다. 다섯 클래스는 방패·후광이 확실하고 곡괭이·활·주머니는 약하다(3단계와 같음). 벽 금은 3단계만 보인다
   - 3배: 모두 읽힌다. 벽 금 1단계는 3배에서도 약하다(의도: 첫 타격)
4. 약한 것 (사람 확인 전, 고치지 않음)
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
