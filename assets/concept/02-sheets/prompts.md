# 02-sheets 기록

(생성할 때마다 도구·모델·프롬프트·레퍼런스·job id·비율·품질을 추가. 시드는 모델이 지원할 때만)

## 9클래스 도트풍 시트 (2026-10-03, 우선 후보 선정, 사람 확인 대기)

사람의 결정: 시트 화풍은 도트풍(2026-10-03). 팔라딘은 슬림하지 않은 거구 체형으로 다시 뽑는다.
공통 설정: `seedream_v5_lite`, 4:3, quality high (3584×2688), 클래스마다 4장. 레퍼런스 두 개: ① 북극성 v6 (cc88a996-0f61-4849-93c0-7d1cf96d2e0b, 팔레트·색온도만) ② 도트풍 팔라딘 v04 (fafe57aa-619e-4330-8547-7b398dc794b6, 도트 렌더링·외곽선·두 시점 배치만). 40크레딧 (잔액 239.5 → 199.5).
종족 키(스프라이트 높이, ○ 프롬프트 값): 인간 64px, 거구 팔라딘 68px, 엘프 72px, 드워프 50px.

공통 틀 (`<...>`만 클래스마다 바꾼다):

```
Character concept sheet, front view and three-quarter view of the same character, full body.
<CLASS LINE> Clean silhouette readable at small size.
Plain dark background, soft even warm light, single character.
Use the first reference only for its palette and warm colour temperature; do not copy its scene. Match the second reference's pixel rendering, dark outline and two-view sheet layout, but not its armor, shield or body proportions.
Palette: <CLASS PALETTE>.
Rendering: pixel art character sheet, each view drawn as a <N>-pixel-tall sprite enlarged with nearest-neighbour scaling, crisp square pixels on one strict grid, no anti-aliasing, no blur, dark outline, limited palette of about 48 colours.
grim medieval fantasy, worn materials, plain gear and objects without emblems, symbols or letters,
warm brown-black shadows with no blue or navy in any shadow,
muted palette of ash/stone/leather with candle-gold accents,
no text, no letters, no watermark, no UI
```

| 클래스 | N | CLASS LINE | CLASS PALETTE |
|---|---|---|---|
| 팔라딘 (거구) | 68 | A huge, hulking human paladin of a grim medieval faith: towering and massively built, very broad shoulders and chest, thick arms and legs, a heavy-set giant of a man, heavy layered plate armor in worn steel with gold-leaf trim, a tall kite shield that is completely blank, flat dull steel with no emblem, boss or marks, closed helm with a narrow visor, ash-gray tabard with a single gold stripe. Solemn, weathered, immovable like a wall. | worn iron and ash (#4a423a, #8c7b66), leather (#6b5e4f), gold (#c9932b, #f4c95d) |
| 광부 | 50 | A dwarf miner of a grim medieval faith: short, very broad, heavily bearded adult dwarf with stocky proportions, about four heads tall and almost as wide as a human, not a child; leather apron and gloves, round helmet with a small oil lamp, heavy pickaxe, soot-stained clothes. | soot and leather (#2e2a26, #4a423a, #6b5e4f), iron (#8c7b66), lamp gold (#f4c95d, #c9932b) |
| 아처 | 72 | A tall, slender elf archer of a grim medieval faith: long limbs, about seven heads tall, earth-brown cloak with the hood down and long pointed ears clearly visible, longbow taller than the shoulders, quiver of arrows, worn leather bracers and boots, no green clothing. | earth and leather (#4a423a, #6b5e4f, #8c7b66), dark brown (#2e2a26), small gold accents (#c9932b) |
| 성직자 | 64 | A human cleric of a grim medieval faith, medium build: dull ivory robes with a gold stole, deep hood, a long plain staff topped with a small flame, prayer beads, no symbols on the stole or robes. Serene and devout. | dull ivory (#efe3c6), gold (#c9932b, #f4c95d), ash (#4a423a, #6b5e4f) |
| 마법사 | 72 | A tall, slender elf mage of a grim medieval faith: long limbs, about seven heads tall, long pointed ears clearly visible, charcoal robes with copper trim, one hand holding a small pale glowing enchanting crystal, no hat, calm posture. | charcoal (#1a1714, #2e2a26, #4a423a), copper (#9c6a1f, #c9932b), pale crystal glow (#efe3c6) |
| 약초사 | 64 | A human herbalist of a grim medieval faith, medium build: patched brown and ochre garb, a satchel of dried herbs and small vials, a small animal companion at the feet, no green clothing. Practical and weathered. | brown and ochre (#6b5e4f, #8c7b66, #9c6a1f), ash (#4a423a), small gold accents (#c9932b) |
| 시프 (v01~v04) | 72 | A tall, slender elf thief of a grim medieval faith: long limbs, about seven heads tall, long pointed ears clearly visible, dark leather armor, short cape with the hood down, twin daggers, crouched ready stance, half-turned. Quick and wary. | dark leather (#1a1714, #2e2a26, #4a423a), steel (#8c7b66), small gold accents (#c9932b) |
| 시프 보정 (v05~v08) | 72 | ...long pointed ears clearly visible, lightly dressed in a dark soft-leather jerkin, wrapped cloth sleeves, fitted trousers and soft boots, a short ragged cape with the hood down, twin daggers, crouched ready stance, half-turned. No metal plate armor, no pauldrons, no tabard, no greaves. Quick and wary. (레퍼런스 문장: "Take only the pixel rendering and dark outline from the second reference; ignore its armor, tabard, shield and body." v06·v08은 북극성 레퍼런스 하나만) | dark leather (#1a1714, #2e2a26, #4a423a), steel blades (#8c7b66), small gold accents (#c9932b) |
| 기술자 | 50 | A dwarf engineer of a grim medieval faith: short, very broad, bearded adult dwarf with stocky proportions, about four heads tall and almost as wide as a human, not a child; leather apron with a tool belt, goggles pushed up on the forehead, a backpack of brass gears and a coiled rope, one hand on a small mechanical trap. Clever and gruff. | leather (#4a423a, #6b5e4f), brass (#9c6a1f, #c9932b), iron (#8c7b66) |
| 룬마스터 | 50 | A dwarf smith of a grim medieval faith: short, very broad, bearded adult dwarf with stocky proportions, about four heads tall and almost as wide as a human, not a child; plain heavy mail under a stone-gray mantle, a heavy engraving hammer, small glowing stones on the belt, no tabard, no shield. Stern and patient. (레퍼런스 문장 끝에 "tabard" 추가) | stone grey (#4a423a, #8c7b66), iron (#6b5e4f), ember gold glow (#f4c95d, #c9932b) |

job id (후보 시트 `<클래스>_vNN-vNN_candidates.jpg`의 A~D 순서 = 버전 번호 순서). **굵게** = 우선 후보, 원본 PNG로 보관:

| 클래스 | v01 / A | v02 / B | v03 / C | v04 / D | 우선 후보 이유 |
|---|---|---|---|---|---|
| 팔라딘 거구 (v05~v08) | **3c795f07-217d-4737-9f3f-30565ba0d587** | b0798ec8-255f-46f7-9206-6c4999f8fd45 | 1ae3d646-5ce9-4c5e-8988-3b98f5105486 | 5d87afe8-329a-461b-8ab8-cf28c4473d8f | v05: 가장 넓고 묵직한 "벽" 실루엣, 민무늬 방패 |
| 광부 | 31708c5f-3984-4c30-9ec1-07978f830f06 | **c2992647-eafa-4337-b592-868b068164f5** | 41181b84-f8a8-4b61-9aa1-2d682fe4dd08 | cd9f2d2f-ea71-4be8-b4ad-700ee0e0e2e4 | v02: 앞치마·곡괭이·램프가 분명, 정면과 3/4가 구분. v01은 3/4에 팔라딘 어깨갑옷이 섞임 |
| 아처 | **808dfcc9-0fec-4481-9c1b-96e57c70ad5b** | 66b355e1-0a38-466d-8eca-e59a45b0e71d | c09c8194-1f39-4c8e-a1e7-c35fec44aa02 | 41a1f03f-e2d4-4293-af09-c79ea7bf1353 | v01: 후드를 내림이 분명, 3/4가 실제로 옆을 봄. v02는 후드를 씀 |
| 성직자 | b4b74cd5-21d2-489c-8fdb-d59a1efa7650 | ff7ec142-aba5-444d-a420-2ee0466b6cb8 | **dcee8951-4316-4691-a283-9d21bebb033a** | a2a0d060-e0f9-44df-a317-c9d9d7325f35 | v03: 금 영대·염주·불꽃 지팡이, 두 시점 일관. v02는 정면만 가면 |
| 마법사 | 22c6ac1f-b857-4139-ad76-ae224d3c9705 | d75756c1-aa92-4370-afa5-0c520031c9b4 | ebae6fe5-03b7-4445-8885-c2a9182635cf | **634d8584-b0a4-489f-9ebe-81fdf71563ab** | v04: 은발이 어두운 로브와 대비돼 작게도 읽힘. v03은 수정 빛이 가장 따뜻한 대안 |
| 약초사 | ce88bbc9-1052-408c-83a8-bac4037c07dd | 4c60ac86-adbe-4264-90fb-1ecf9ce5fcfe | 98dcb94f-7c51-47f4-af1a-e70c91dc1241 | **b919435f-0b50-40f9-be14-edec982dd7b1** | v04: 마른 약초(녹색 아님)와 가방이 분명. v01은 약병 채도가 높음 |
| 시프 (v01~v04) | ed5fa03c-8c8e-41b4-b0db-4852e4a5dff2 | d6516aad-652b-42ce-968a-0f52864c442e | def24121-3749-4af6-bd6a-33477f8cbbc4 | 0a7796a3-46a9-4e7e-bb0c-91e441507568 | 모두 팔라딘 레퍼런스의 판금이 새어 탈락(v02는 장포까지) |
| 시프 보정 (v05~v08) | **d24dccc3-9c74-476b-823a-278376d3d68e** | f761b157-2c8d-4b1f-b54b-0f9ef1059e85 | e570fcb1-0195-48f7-92e9-db0f10ce778b | 1f380a87-160f-4373-b9d8-08ae581865f3 | v05: 가벼운 가죽·붕대·해진 망토, 웅크린 3/4. v06·v08(북극성만)은 배경색·화풍이 다른 시트와 어긋남 |
| 기술자 | a379efc6-29ec-4246-9492-4762ea70f5bb | **b044487c-f331-47e5-abc7-4881202c03dd** | a355800a-39f0-4265-ba33-3e95c81e55c2 | 1de8c041-f376-493a-a8b0-b7530f6c29a6 | v02: 밧줄·톱니 배낭·덫 상자, 두 시점 구분. v01은 두 그림이 거의 같음 |
| 룬마스터 | bb1d290d-739b-446e-aee4-044177a5644f | 8681320b-5b5a-4c2d-b3f3-49b39a0e40d5 | ea145c19-95a1-461a-ba4d-74deacc54b2b | **eeeecb1a-79db-4a4e-8e11-6e52c4400776** | v04: 회색 망토가 광부·기술자와 구분. v01은 그림 아래에 "FREMT VIEW" 같은 글자가 생겨 탈락, v03은 가슴판이 섞임 |

- class_lineup.png: 우선 후보 9장의 정면을 종족 키 비율(인간 64 / 팔라딘 68 / 엘프 72 / 드워프 50)로 맞춰 한 줄로 세운 것
- class_lineup_32px.png: 같은 줄을 게임 크기(인간 28px 기준)로 줄인 것. 팔라딘·성직자·약초사·드워프 셋은 바로 구분되지만, 마법사와 시프는 어두운 옷이라 비슷하게 묻힌다(3단계 클래스 색으로 보완)

배운 것:
- 두 번째 레퍼런스(팔라딘 시트)의 갑옷이 다른 클래스로 새어 들어온다(광부 v01 어깨갑옷, 시프 v01~v04 판금, 룬마스터 v03 가슴판). "No metal plate armor, no pauldrons, no tabard" 같은 금지와 "Take only the pixel rendering and dark outline from the second reference"로 막혔다(시프 보정 v05·v07)
- 북극성 레퍼런스 하나만 쓰면 판금은 사라지지만 배경색·화풍이 다른 시트와 어긋난다(시프 v06·v08). 레퍼런스 두 개를 유지한다
- "Character concept sheet ... front view and three-quarter view"는 가끔 보기 라벨 글자를 그린다(룬마스터 v01). 채택 전에 글자가 있는지 확인한다
- 시트 두 시점이 거의 같은 각도로 나오는 경우가 있다(기술자 v01, 회화체 v01)

## 팔라딘 시트 화풍 비교 (2026-10-02. 2026-10-03 사람이 도트풍으로 결정)

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
