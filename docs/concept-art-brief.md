# Evensong: The Nine Lamps — 컨셉아트 브리프

> game-concept.md의 아트 방향(§10)을 실제 이미지 도구에 넣기 위한 실행 문서.
> 기준: A안(32px 음울한 중세 픽셀 + 동적 조명) + 정렬형 탑다운. C안의 장식 언어는 제단과 UI에만.
> 게임 스프라이트(3단계부터)의 도트 구조는 Tiny Farm RPG (R18). 톤은 둘로 나눈다: 캐릭터·생활·꾸미기는 아기자기하게, 외부 위협은 북극성의 음울한 색으로 (R19, §5.6).
> 상태: 라운드 24 · 2026-10-17

## 0. 북극성 (확정, R15 · 2026-10-02)

**북극성 = `assets/concept/01-keyart/northstar_pixel_v6_final.png`.** 이후 모든 생성의 레퍼런스이자 판단 기준 (성화 UI 제외, §5.5).
지상의 저녁, 제단 윗면의 등잔 9개(3×3), 그 빛 안에 인간·드워프·엘프가 셋씩 선 정렬형 탑다운 화면이다.
- 도구: 힉스필드 MCP → `seedream_v5_lite`, 16:9, quality high, 이미지 레퍼런스 = 아래 원본 키아트
- job: cc88a996-0f61-4849-93c0-7d1cf96d2e0b
- URL: https://d8j0ntlcm91z4.cloudfront.net/user_3JgRtXwbNoo2upapZF30zhtgJ8O/hf_20261001_231116_cc88a996-0f61-4849-93c0-7d1cf96d2e0b.png
- 프롬프트: §5.0

**원본 키아트 (북극성의 부모).** 회화체. 구도·배율·인물 배치의 원본.
- 파일: `assets/concept/01-keyart/keyart_seedream_v6.png`
- 도구: `seedream_v5_lite`, 텍스트만 (§5.1 프롬프트 그대로)
- job: 5d338aae-eefb-4689-804b-41f0e1b47669
- URL: https://d8j0ntlcm91z4.cloudfront.net/user_3JgRtXwbNoo2upapZF30zhtgJ8O/hf_20261001_230811_5d338aae-eefb-4689-804b-41f0e1b47669.png

**v1에서 바꾼 이유 (R15).** R6의 v1은 종족 배치(R9), 9인(R11), 지상+지하(R12), 가제(R13)보다 먼저 만들어졌다. 그래서 지하 동굴에 인간 비례 4명, 남색 그림자, 채도 높은 보라 덩굴로 그려져 있었다. v6는 이 네 가지를 고쳤고, 아이소메트릭 후보(v3)와 비교한 끝에 투영을 정렬형 탑다운으로 정했다. 엘프와 인간의 키 차이는 v6에서도 약하다(§7).
- v1 기록: 북극성 6e3a72c4-bafe-45c9-b21a-a42833eb35b6, 원본 d2440f66-cd96-4dce-bc45-7c140b397eed. 파일은 `northstar_pixel_v1.png`, `keyart_seedream_v1.png`로 보관한다. v1의 프롬프트·URL·당시 공통 접미어는 `assets/concept/01-keyart/prompts.md`의 v1 항목에 옮겨 두었다
- R6 비교군 (탈락): Nano Banana 2 (8519319d-6576-4c44-93b8-5e7b5caefb19), Nano Banana Pro (d55b86e8-0eac-4456-9ee8-5f7000e79d89). v1 원본과 같은 프롬프트(prompts.md의 v1 항목)
- R15 후보와 탈락작 31장의 job id, 측정값, 탈락 이유는 `assets/concept/01-keyart/prompts.md`

크레딧 기록: R6 1단계 5.5크레딧 (Seedream lite 1 + Nano Banana 2 1.5 + Nano Banana Pro 2 + 도트풍 1, 무료 플랜). R15 북극성 재작업 31크레딧 (starter 플랜, 잔액 274.5 → 243.5, 2026-10-02). 생성 전에는 `balance`로 실제 잔액을 확인한다.

상태: 1단계 완료 (R15 재채택). 2단계 완료 (R17, 도트풍 시트 9장, §5.2). 3단계 픽셀 전환은 화풍(R18), 톤·방향(R19), 캐릭터 키(R20, 약 30px), 클래스 표식 장비와 꾸미기(R21)를 정했다 (§5.6). 슬라이스 5클래스의 표식은 시험으로 모두 그려 봤다 (PixelLab 5~7차, R23·R24).

## 1. 단계

| 단계 | 산출물 | 도구 | 목적 |
|---|---|---|---|
| 1 무드 키아트 | 3~5장 중 1장을 "북극성"으로 채택 | 힉스필드 Seedream 5.0 Lite (완료, §0. R15 재채택) | 톤·팔레트·제단 빛 표현·투영 확정 |
| 2 클래스 시트 | 팔라딘 1장 먼저 → 팔라딘 도트풍 시트를 레퍼런스로 나머지 (완료, §5.2. R17 채택) | 힉스필드 `seedream_v5_lite` + 레퍼런스 이미지(`medias` image_references) | 실루엣과 클래스 색 확정 |
| 3 픽셀 전환 | 32×32 프레임 2등신 스프라이트(Tiny Farm 구조, §5.6), 아래·위·옆 + 좌우 반전, idle/walk/attack | PixelLab (+ Aseprite) | 실제 에셋 |
| 4 환경·오브젝트 | 제단, 오염 타일, 바이옴 2개 무드 | 1~2단계 도구 → PixelLab 타일셋 | 슬라이스 환경 |
| 5 성화 UI | 코덱스 페이지, 기도 화면, 아이콘 프레임 | 이미지 모델 (+ Recraft 벡터) | 정적, 가장 쉬움 |

슬라이스 순서: 팔라딘 → 광부 → 아처 → 성직자 → 약초사 (R23, game-concept §12). 나머지 4개(마법사·시프·기술자·룬마스터)는 슬라이스 검증 후.

## 2. 도구 배정 이유

- 컨셉·키아트: 힉스필드는 여러 이미지 모델을 한 곳에서 쓰고, MCP로 클로드 대화창에서 바로 뽑을 수 있다. 미드저니 V7은 회화적 품질이 가장 높지만 세밀한 지시(특정 갑옷 수정)에는 약하다. FLUX.2 Pro는 프롬프트 충실도가 높아 "이 요소를 꼭 넣어라"에 강하다
- 픽셀: 범용 모델은 "픽셀풍" 그림을 만들 뿐 격자에 맞는 진짜 픽셀아트가 아니다. PixelLab은 격자 크기(16/32/64)를 이해하고 4·8방향 회전, 타일셋, 애니메이션 시트를 만들며 Aseprite 플러그인과 MCP 에이전트 툴킷이 있다
- 대량 일관성: 에셋이 수백 개가 되면 Scenario에 채택본을 학습시켜 스타일 드리프트를 막는다. 슬라이스 단계에서는 아직 불필요

## 3. 공통 스타일 접미어 (§5.2~§5.4 끝에 붙인다)

```
grim medieval fantasy, worn materials, plain gear and objects without emblems, symbols or letters,
warm brown-black shadows with no blue or navy in any shadow,
muted palette of ash/stone/leather with candle-gold accents,
no text, no letters, no watermark, no UI
```
접미어에는 그림자 색만 두고, 조명·렌더링(회화체·도트풍)·장면은 각 프롬프트 본문에 쓴다. R19부터 이 접미어(grim, muted)는 위협 쪽(적·오염·던전)과 북극성 계열 이미지에만 붙인다. 생활 쪽은 §5.6의 톤을 따른다. §5.0과 §5.1은 그 자체로 완결된 프롬프트라 접미어를 붙이지 않는다. 문장·상징을 막는 말은 신앙 상징(game-concept §7, 미결)이 정해지기 전까지 둔다.

네거티브 (지원하는 도구에서. `seedream_v5_lite`는 지원하지 않는다. 컨셉 이미지용이다. 게임 스프라이트는 2등신이므로 3단계에는 "cute chibi proportions"를 쓰지 않는다, §5.6):
```
photorealism, anime, cute chibi proportions, bright saturated colors, modern or sci-fi elements,
isometric view, diamond-shaped tiles, emblems or sacred symbols on shields and clothing,
blue or navy shadows, text, watermark, blurry, extra limbs
```

## 4. 팔레트 코드 (프롬프트에 그대로 넣는다)

- 기반: #1a1714 #2e2a26 #4a423a #6b5e4f #8c7b66
- 신앙: #f4c95d #c9932b #9c6a1f #efe3c6 #6f5522
- 타락: #3b1f4d #5e2d7a #8a5fb0 #6f8f3a #d8d2c0
- 악마: #2a0808 #5c1010 #8f1a1a #c8321f #ff7a1a

북극성 v6 기준: 그림자는 따뜻한 갈흑이고 청색·남색이 없다. 오염의 보라는 가는 맥에만 쓰고 밝은 보라(#8a5fb0)는 면으로 칠하지 않는다.
○ 제안: 녹색은 오염 신호로 남겨 두고 클래스 옷에는 쓰지 않는다(약초사를 갈색·황토로 바꾼 이유).
○ 제안 (R23, 농사): 작물·풀의 녹색은 생활 쪽 색이다. 오염 신호의 녹색은 타락 줄의 병든 올리브(#6f8f3a)만 쓰고, 오염에 시든 작물이 이 색과 잿빛으로 바뀐다.

레퍼런스 이미지는 북극성(§0)을 넣는다(성화 UI 제외, §5.5). A~D 스타일 보드(`assets/concept/01-keyart/style-board-4options.png`)는 화풍이 섞여 있고 글자가 있어 생성 레퍼런스로 쓰지 않는다.

## 5. 바로 쓰는 프롬프트

### 5.1 무드 키아트 (1단계, 북극성 원본 v6에 쓴 프롬프트, 텍스트만)

```
Straight top-down 2D game view: the floor is a grid of square stone tiles whose edges run exactly horizontal and vertical in the image, like graph paper laid flat and seen from above at a steep angle; upright things show only a little of their front face, and the front edge of the altar is a horizontal line. Not isometric and not rotated: no diamond-shaped tiles, no diagonal grid lines, no vanishing point, no sky, no horizon. The frame shows about thirty floor tiles across; each figure is small, a human about one eighth of the image height, with open ground around everyone.

Exactly nine figures of three peoples, and height is how you tell the peoples apart: the three elves are clearly the tallest, a full head taller than the humans, very slender with long limbs and long pointed ears, so the elf archer and the elf mage stand taller than the paladin; the three humans are of medium height; the three dwarves are the shortest, two-thirds of human height, very broad and heavily bearded.

Evening on the surface of a dying land: thick ash and smoke hide the sunken sun, and the dead grass, packed earth and broken flagstones are tinted warm umber and dull ash-brown, not orange; the deepest shadows are the brown-black of old soot. No cave.

Center: a broad, low, square solid stone altar about three tiles wide, its edges parallel to the image edges, with worn gold-leaf rims. On its top, nine small clay oil lamps in three straight rows of three, with dark gaps between them: nine separate flames, all burning, the brightest point in the image. A thin thread of incense smoke rises. Their light makes one round pool of candle-gold about half the image wide over worn paving stones, fading softly at the rim, with no drawn line and no glowing ring on the ground. All nine figures stand inside the light, shadows pointing outward.

They stand in evening prayer, heads bowed, weapons lowered, in three groups of three. Above the altar, facing the viewer, the three humans: a paladin in worn plate and closed helm resting on a tall kite shield that is completely blank, flat dull steel with no emblem, boss or marks; a cleric in dull ivory robes and gold stole, one hand lifted to lead the prayer, the other holding a plain staff topped by a small flame; a herbalist in patched brown and ochre clothes with a bulging herb satchel.
Left of the altar, the three dwarves: a miner with a pickaxe and a small lamp on a round helmet, a smith with a heavy engraving hammer, and an engineer with a backpack of gears.
Right of the altar, the three tall elves: an archer in earth-brown leathers, hood down, with a longbow taller than the shoulders, the only bow in the scene; a hooded thief with twin daggers; and a mage in charcoal robes holding a small glowing crystal in one open hand. The space below the altar is left open.

Upper-right corner: a collapsed stone stairway sinks into a black opening, and corruption seeps out: grey cracked earth with thin dark bruise-violet veins, patches of dull olive mould, small bone-coloured nodules lying flat. Nothing grows upward; it is matte, unlit, darker than the lit ground, and stops at the rim of the light. Left edge: a dark rock wall with a few tile-sized chunks dug out.

Palette: 80% desaturated warm grey-brown #1a1714 #2e2a26 #4a423a #6b5e4f #8c7b66; light in candle gold and ivory #f4c95d #c9932b #efe3c6; corruption #3b1f4d #6f8f3a #d8d2c0, violet only in thin veins. Plain worn clothing in ash, leather and earth tones; no emblems, symbols, letters or marks on shields, clothing or the altar. Grim medieval fantasy, painterly concept art, clean readable shapes. No text, no letters, no watermark, no UI.
```
같은 프롬프트로 4장을 뽑아 2장이 엄밀한 정렬 격자로 나왔다(나머지 2장은 대각선 격자). 프롬프트의 "smith"가 룬마스터다("rune"이라는 단어를 피했다). v6에서 인물은 일렬 대형으로 섰다.

### 5.2 클래스 캐릭터 시트 (2단계, R17 채택)

● 시트 화풍은 도트풍이다 (2026-10-03 결정. 회화체는 32px로 줄이면 윤곽이 배경에 묻혔다). R17의 "팔라딘은 거구" 결정은 R18에서 폐지했다. 게임 스프라이트는 전 클래스가 같은 체형이다(§5.6). 시트의 거구 팔라딘은 컨셉 기록으로 남긴다.
R18부터 시트는 비례 기준이 아니라 의상·도구 기준이다 (무엇을 입고 무엇을 드는가). R21부터 옷·모자는 클래스에 묶지 않는 꾸미기 장비의 참고이고, 클래스는 표식 장비로 읽는다(§5.6).
채택본 9장: `assets/concept/02-sheets/<클래스>_vNN_final.png`. 클래스별 CLASS LINE·팔레트·job id·선정 이유는 `02-sheets/prompts.md`.

```
Character concept sheet, front view and three-quarter view of the same character, full body.
<CLASS LINE> Clean silhouette readable at small size.
Plain dark background, soft even warm light, single character.
Use the first reference only for its palette and warm colour temperature; do not copy its scene.
Match the second reference's pixel rendering, dark outline and two-view sheet layout, but not
its armor, shield or body proportions.
Palette: <CLASS PALETTE>.
Rendering: pixel art character sheet, each view drawn as a <N>-pixel-tall sprite enlarged with
nearest-neighbour scaling, crisp square pixels on one strict grid, no anti-aliasing, no blur,
dark outline, limited palette of about 48 colours. [공통 접미어]
```

`seedream_v5_lite`, 4:3, quality high, 클래스마다 4장. 레퍼런스 두 개: ① 북극성 v6 (팔레트·색온도만) ② 도트풍 팔라딘 v04 시트 `fafe57aa-619e-4330-8547-7b398dc794b6` (도트 렌더링·외곽선·두 시점 배치만). 두 번째 레퍼런스의 장비가 새어 들어오는 클래스(시프 등)는 레퍼런스 문장을 "Take only the pixel rendering and dark outline from the second reference; ignore its armor, tabard, shield and body."로 바꾸고 CLASS LINE에 "No metal plate armor, no pauldrons, no tabard"를 넣는다.

종족 체형 문구: 인간 "medium build" (팔라딘만 "huge, hulking ... massively built"), 엘프 "tall, slender ... about seven heads tall, long pointed ears clearly visible", 드워프 "short, very broad ... about four heads tall and almost as wide as a human, not a child". 시트의 스프라이트 높이 N(인간 64 / 팔라딘 68 / 엘프 72 / 드워프 50)은 시트를 만들 때 쓴 프롬프트 값이다. 게임 안에서는 종족별 키 차이를 두지 않는다(R18, §5.6).

"rune", "glyph", "engraved"(갑옷에 쓸 때) 같은 단어는 글자·문양을 부르므로 프롬프트에 쓰지 않는다. "engraving hammer"(각인 망치)는 v6에서 문제가 없었다.

### 5.3 제단 (4단계)

```
Straight top-down view of a portable stone altar for a grim medieval faith, isolated on a plain
dark background: a broad, low, square block of gray stone with worn gold-leaf rims, its edges
exactly horizontal and vertical in the image, not isometric and not rotated. Plain stone faces
with no carvings, symbols, letters or marks. On its top, nine small clay oil lamps in three
straight rows of three, nine separate flames; small offerings of bone and dried herbs at its base.
Use the reference only for its palette and warm colour temperature; do not copy its scene. [공통 접미어]
```

### 5.4 오염 지대 무드 (4단계)

```
Straight top-down view of surface ground near a dungeon entrance being consumed by corruption:
square floor tiles whose edges run exactly horizontal and vertical in the image, not isometric
and not rotated, no diamond-shaped tiles, no diagonal grid lines. Grey cracked earth with thin
dark bruise-violet veins, patches of dull olive mould, small flat bone-coloured nodules, a
heretic's crude shrine of stacked skulls at the source. Everything lies flat, nothing grows
upward, matte and unlit. Palette: #3b1f4d, #5e2d7a, #6f8f3a, #d8d2c0 on ash black, violet only
in thin veins. Use the reference only for its palette and warm colour temperature; do not copy
its scene. [공통 접미어]
```

### 5.5 성화 UI (5단계, ○ 신앙 상징 결정 전 임시)

```
Illuminated manuscript page border with a stained-glass rose window motif, gold leaf on aged
parchment, a single small candle flame motif, abstract gothic tracery, symmetrical, flat
decorative design, high contrast, no symbols, no letters or script. Palette: gold (#c9932b,
#f4c95d), ivory (#efe3c6), deep red (#5c1010), ash black (#1a1714). No text.
```
성화 UI는 게임 화면과 다른 시각 언어를 쓴다(game-concept §10). 북극성은 레퍼런스로 넣지 않는다. 신앙 상징이 정해지면 다시 쓴다.

### 5.0 도트풍 재현 (북극성 v6에 쓴 프롬프트, 레퍼런스 = §5.1 결과 필수)

```
Re-draw the reference image as a pixel art screenshot of a top-down 2D video game, keeping the same composition, camera, scale, figures, altar and light layout. Keep the straight top-down grid: square floor tiles whose edges run exactly horizontal and vertical, not isometric, not rotated. Treat it as a 480 by 270 pixel game screen enlarged with nearest-neighbour scaling: every art pixel is a square block of the same size on one strict grid, no anti-aliasing, no blur, no smooth gradients, dithering only in the deepest shadows and in the falloff band at the rim of the light. The ground is built from 16-pixel tiles.
Keep three clearly different body heights as sprites: elves about 32 pixels tall and thin, humans about 28, dwarves about 22 pixels tall and almost as wide as a human. Each sprite has a dark outline and a readable role item: tall plain shield, staff with a small flame, herb satchel, longbow, twin daggers, small crystal, pickaxe and helmet lamp, engraving hammer, gear backpack. The altar keeps its nine lamp flames in three rows of three; each of the nine flames stays a separate bright dot, and they stay the brightest point on screen.
Re-map every colour to a limited palette of about 48 colours, even where the reference is cooler: shadows warm brown-black #1a1714 #2e2a26, ground ash and earth #4a423a #6b5e4f #8c7b66, light candle gold and ivory #f4c95d #c9932b #9c6a1f #efe3c6, corruption grey cracked earth with bone #d8d2c0 and dull olive #6f8f3a, violet only as thin dark lines #3b1f4d #5e2d7a. No blue or navy in any shadow. The flat corruption stops at the rim of the golden circle. Grim medieval fantasy, plain gear without emblems. No text, no letters, no watermark, no UI.
```
범용 모델의 "도트풍"이라 격자가 완전히 정확하지는 않다(바닥 빛에 부드러운 그라데이션이 남는다). 무드와 기준용이다. 진짜 도트는 §5.6. 프롬프트의 종족 키(32/28/22px)는 이 키아트에만 쓴 값이다. 게임 스프라이트는 R18부터 체형이 하나이고, R21부터 종족은 클래스와 무관한 꾸미기 파츠다(game-concept §3, §5.6).

### 5.6 픽셀 전환 (3단계, PixelLab, R18 화풍 · R19 톤·방향)

● 게임 스프라이트의 도트 구조는 Tiny Farm RPG(itch.io, Maeve, 16x16 팩)와 같게 한다. 북극성 v6는 분위기·질감·팔레트의 기준으로만 쓴다 (R18, 2026-10-14. PixelLab 1차 시험의 사실 비례 팔라딘을 보고 사람이 정함. R19에서 북극성의 범위를 위협 쪽으로 좁힘).
- ● 톤 (R19): 캐릭터, 월드 안의 상호작용, 생활 동사(채굴·건설·제작·기도 등), 꾸미기 요소는 아기자기하게 한다. 외부 위협(이단·타락 적, 오염 지대, 던전, 악마)은 기존 컨셉의 음울한 색으로 한다. 북극성 v6와 §4 타락·악마 팔레트가 위협 쪽 기준이고, 촛불 금빛은 양쪽에 쓴다
- ○ 해석: 제단의 빛(안전 반경) 안이 아기자기한 삶, 빛 밖이 음울한 위협이다. 빛 = 신앙 = 안전(game-concept §10)과 같은 경계를 쓴다
- ● 크기: 타일 16px, 캐릭터 프레임 32×32, 캐릭터 키 약 30px (프레임을 거의 채운다. R20, R18의 약 20px에서 바꿈). Tiny Farm(약 20px)보다 크고 디테일이 살며, 타일 약 2칸 높이다. A안의 "32px"는 프레임 크기다
- ● 비례: 2등신 (머리가 키의 절반쯤, 짧은 몸과 팔다리). 모든 캐릭터가 같은 체형이다. 종족별 키·체형 차이와 R17의 거구 팔라딘은 두지 않는다
- ● 외형은 클래스와 무관한 꾸미기이고, 클래스는 표식 장비로만 읽는다 (R21, game-concept §3. R18의 "직분은 도구·모자·옷"을 바꿈). 표식: 팔라딘 대형 방패, 시프 허리의 쌍검, 광부 등의 곡괭이, 성직자 후광, 마법사 떠서 따라다니는 책, 룬마스터 위성처럼 도는 룬, 약초사 허리의 씨앗주머니, 아처 등에 맨 큰 활, 기술자 허리의 망치(제작용, R22)
- ● 종족은 고르지 않아도 되는 꾸미기 파츠로 남는다 (R21): 엘프 뾰족 귀(모자·머리카락 밖으로 나오게 과장), 드워프 수염. 인간은 전용 파츠가 없다 (R22)
- R17 시트(§5.2, 02-sheets/prompts.md)의 옷·모자(팔라딘 닫힌 투구, 성직자 깊은 두건, 광부 램프 투구, 기술자 고글 등)는 이제 꾸미기 장비의 참고다. 한 클래스의 기본값으로 묶지 않는다
- ● 선·명암: 따뜻한 갈흑 1px 외곽선, 재질마다 2~3단 명암, 한 캐릭터 10여 색
- ● 구도: 바닥은 위에서, 인물은 정면에 가깝게 (PixelLab `view: "low top-down"`). 타일·오브젝트 도구는 기본값이 high top-down이라 매번 명시한다
- 색: 생활 쪽은 따뜻하고 밝게(○ 채도는 Tiny Farm에 가깝게, 그림자는 따뜻한 갈흑이고 청색 없음). 위협 쪽은 §4 타락·악마 팔레트와 북극성 v6(잿빛, 뼈, 가는 보라 맥). 두 쪽이 한 화면에서 대비돼야 한다. ○ 세부 생활 팔레트는 시험으로 정한다
- Tiny Farm 이미지는 생성 도구에 넣지 않는다. 라이선스가 AI 학습 사용을 금지하므로 구조는 말로만 옮긴다. 구매한 정식판은 저장소 밖 `C:\dev\share\refs\tiny-farm-rpg\`에 둔다 (R23, AGENTS.md. 재배포 금지라 커밋하지 않는다). 실측 구조는 아래 "Tiny Farm 정식판 구조"
- ● 방향 (R19): Tiny Farm식. 아래·위·옆을 그리고 반대쪽 옆은 좌우 반전한다. 반전된 쪽에서는 방패 같은 한쪽 장비가 반대 팔로 옮겨 가거나 몸 뒤로 숨는다(2차 목업). PixelLab은 4방향(v3는 8방향)으로 만들고 남·북·동만 쓴다
- ○ 모션 프레임 (Tiny Farm 수치): idle 4, walk 6, 공격 6~10, 피격 4, 사망 4. 순서는 idle → walk → attack. 동작별 수치와 클래스 대응은 아래 "Tiny Farm 정식판 구조" (R23)

○ 레이어 구조 (R21, 꾸미기를 위해 처음부터. 슬라이스는 기본값만 쓴다):
- 기본 몸(애니메이션 1벌) 위에 장비 파츠(하의·신발·상의·장갑·망토), 머리 모양, 종족 파츠, 모자, 표식 장비를 겹친다. 피부·머리·옷 색은 팔레트 스왑으로 바꾼다
- 그리기 순서표를 방향마다 둔다. 등 장비·망토·긴 머리는 남쪽에서 몸 뒤, 북쪽에서 몸 앞이다. 옆은 반전(R19)이라 한쪽에 찬 장비는 반대쪽으로 간다
- 단단한 파츠(투구, 방패, 망치 등)는 방향당 1장을 그리고, 기본 몸 프레임마다 기록한 기준점(머리·손·허리·등)에 붙인다. 흔들리는 망토·긴 머리는 프레임마다 그려야 해서 비싸다
- 만드는 법 (R23, 5차 시험으로 바꿈): 기본 몸의 방향마다 한 프레임에 PixelLab `inpaint_image`로 단단한 파츠를 그린다(마스크 = 파츠가 들어갈 자리). 마스크 밖은 기본 몸과 픽셀까지 같으므로 차이(`tools/art/layers.py diff`)가 곧 파츠 레이어다. 이 한 장을 걷기 프레임마다 몸의 움직임(몸통 줄 정렬)만큼 옮겨 붙인다. 표식 하나에 방향 3 × 10회 = 약 30회
  - `edit_image`는 남·북에서 몸 전체를 다시 그려 차이로 떼어낼 수 없었다(동쪽만 됨). 쓰려면 색으로 떼어낸다(`layers.py segment`, 장비 색이 몸 색과 다를 때만)
  - 떠 있는 표식(후광·책·룬)은 손으로 그려도 된다(5차 후광, 무료). 몸에 붙는 표식을 손으로 그리면 inpaint보다 확연히 거칠었다(5차 활)

○ 모자와 머리 모양 (R21):
- 모자는 머리를 가리는 정도로 3종이다: 투구(전부 가림), 두건·캡(정수리만 가리고 옆·뒷머리는 보임), 머리띠·관(안 가림). 머리 모양은 정수리·옆·뒷머리·앞머리로 나눠 그리고, 모자 종류에 따라 일부를 숨긴다. 머리 모양 × 모자 조합마다 그리지 않는다
- 종족 파츠는 모자 밖에 둔다. 엘프 귀는 어느 모자에서도 밖으로 나오고, 드워프 수염은 투구 아래로 나온다. 안 그러면 투구 하나로 종족이 사라진다
- ● 높이: 프레임은 32×32 그대로 둔다 (R22). 캐릭터가 프레임을 거의 채우므로 모자는 머리 위 2~3px 안에서 그린다. 떠 있는 표식(후광·책·룬)은 별도 스프라이트라 이 제한을 받지 않는다
- ○ 발 맞춤 (R23, 5차 측정): 템플릿 걷기는 키 28px인데 머리 꼭대기가 모든 프레임에서 y=0에 붙어 모자 자리가 없고, 발 높이는 애니메이션마다 y=26~29로 달랐다. 모든 애니메이션의 발을 프레임 바닥(y=31)에 맞춰 옮기면 머리 위에 3~4px가 생긴다. 엔진의 기준점도 발에 둔다
- ● 투구 숨기기 토글 (R22, game-concept §3): 숨기면 모자 레이어만 빼고 머리 모양을 전부 그린다
- 모자·옷이 특정 클래스를 떠올리게 하지 않는다. 문장 금지(신앙 상징 결정 전까지)는 모자에도 적용한다

○ 표식 장비 그리기 (R21):
- 몸에 붙는 것(방패, 쌍검, 씨앗주머니, 망치, 곡괭이, 활)은 레이어로 기준점에 붙인다. 떠 있는 것(후광, 책, 룬)은 몸과 따로 움직이는 스프라이트라 걷기 프레임마다 그리지 않아도 되고, 32 프레임 밖에 둘 수 있다. 룬이 몸 뒤로 돌 때는 몸 뒤에 그린다
- 허리의 셋(시프, 약초사, 기술자): 30px 캐릭터의 허리는 몇 px뿐이라 몸 폭 밖으로 나오게 과장한다. 쌍검은 양쪽 허리에서 칼자루가 비죽 나오고, 망치는 자루가 아래로 길고, 씨앗주머니는 크고 둥글다
  - ○ 크기 (R24, PixelLab 6·7차): 몸통 절반쯤(폭 6~10px)으로 그리고, 허리띠에서 발 높이까지 처져도 된다. 폭 6~7px 주머니(6차)는 1배에서 기본 몸과 구분되지 않았고, 색을 바꿔도 마찬가지였다. 몸통 절반 크기(7차)는 1배 옆모습에서 확실하고, 앞·뒤는 곡괭이·활 정도다. 시프 쌍검·기술자 망치도 이 크기를 기준으로 본다
  - ○ 씨앗주머니 모양 (R24, 7차 `03-pixel/sig_herbalist_pouch_v02.png`): 오른쪽 엉덩이에 찬 진한 초록 천 주머니, 끈으로 묶은 입구에 두 잎 새싹. 풀밭의 중간 톤 초록에 묻히지 않게 진한 초록에 밝은 하이라이트를 넣는다 (§4 ○ 생활 녹색)
- 등의 둘(광부, 아처): 남쪽에서는 어깨 위로 솟은 끝만 보인다. 곡괭이 날(T자)과 활 끝(휜 호)이 확실히 달라야 한다
- 쓸 때(공격·채굴)는 방패·쌍검·곡괭이·활을 손에 든다. 책은 펼쳐지고, 룬은 날아가고, 후광은 빛난다
- ● 망치 둘 (R22): 기술자 망치는 제작·설치 동작에서만 손에 들고 공격에는 쓰지 않는다. 룬마스터는 공격할 때 마법 망치를 든다. ○ 마법 망치는 공격할 때만 나타나고 머리가 빛나서 기술자의 쇠망치와 다르게 보인다
- 후광은 신앙 상징이 아니라 빛 고리로 그린다. 룬은 글자 없는 빛나는 돌로 그린다 ("rune"·"glyph"는 프롬프트에 쓰지 않는다, §5.2)

○ Tiny Farm 정식판 구조 (R23. 구매한 팩의 PNG 크기와 픽셀로 셌다. 이미지는 쓰지 않고 구조만 옮긴다):
- 조립: 동작마다 피부(4), 눈(2종 × 색 4), 머리 모양(7종 × 색 4), 옷(1벌 × 색 5), 장신구(모자 여러 종, 엘프 귀, 수염), 도구가 각각 32×32 프레임 스트립이고, 동작마다 Aseprite 조립 파일이 있다. R21 레이어 구조와 같은 방식이다. 엘프 귀·수염도 장신구 레이어라 우리 종족 파츠와 같다
- 방향: 조립용 스트립은 방향 4묶음이고, 그중 두 묶음은 서로 좌우 반전에 1px 이동이다. 완성 캐릭터 시트는 3줄이다. R19의 "옆은 반전"과 같다
- 크기: 몸은 18px(y 8~25)이고, 모자는 머리카락 위 3px 안(y 4~6)에서 시작한다. 우리 캐릭터(약 30px, R20)보다 작지만 모자 높이 규칙(R22, 머리 위 2~3px)은 같다
- 몸 동작을 도구끼리 나눠 쓴다. 곡괭이·괭이(·잠자리채)가 한 동작, 도끼·낫이 한 동작이고 도구 레이어만 바꾼다. 도구 레이어는 도구마다 10벌이고, 무기·방어구 아이콘의 재질도 10단계(나무·구리·철·금 …)다. 우리 곡괭이 등급(gameplay-design §3.1)과 같은 구조다
- 동작과 방향당 프레임, 우리 쓰임:

| Tiny Farm 동작 | 프레임 | 우리 쓰임 (○) |
|---|---|---|
| idle · walk · run | 4 · 6 · 8 | 공용 |
| 곡괭이·괭이 | 6 | 광부 채굴, 밭 일구기 (한 동작) |
| 도끼·낫 | 6 | 수확(낫), 벌목 |
| 물주기 | 8 | 약초사 물주기 |
| 삽 | 5 | 2차 |
| 검 | 10 | 팔라딘·시프, 룬마스터 마법 망치 |
| 활 | 7 | 아처 |
| 마법 | 6 | 성직자 기도·치료, 마법사 |
| 들어 올리기 · 던지기 | 4 · 5 | 약제 투척(약초사), 함정 설치(기술자, 2차) |
| 쓰다듬기 | 3 | 동물 (2차) |
| 피격 · 사망 | 4 · 4 | 공용 |

- 슬라이스 몸 동작 (○): 공용 idle·walk·피격·사망 + 곡괭이·괭이, 낫, 물주기, 검, 활, 마법, 던지기 = 11동작 × 남·동·북. 도구와 표식 장비는 레이어로 얹는다
- 작물: 16px 칸 한 줄에 씨앗 → 커지는 성장 칸 4~6개 → 수확물 1칸이다(토마토·옥수수·피망은 성장 칸이 6~8개). 키 큰 작물은 16×32 칸이다. 봄 12종, 여름 12종, 가을 6종에 과일나무가 따로 있다
- 작업대: 연금술대, 모루, 화로, 작업대, 냄비, 발효통, 벌통 등 13종. 약초사의 조제대는 연금술대 자리다 (gameplay-design §3.5)
- 적: 슬라임, 고블린 외에 버섯 적과 독꽃 적이 있다. 약초사의 독초·균류 재료를 타락한 식물에서 얻는 아이디어로 쓴다 (game-concept §9.7)

○ PixelLab 설정 (2~4차 시험 기준, 확정 전):
```
create_character  mode: "v3", size: 32, view: "low top-down",
  outline: "single color black outline", detail: "medium detail"
아군: "cute chibi <human | elf | dwarf> <class>, about two heads tall with a big head and small body,
  <종족 파츠: long pointed elf ears clearly sticking out | big beard>, <모자>, <옷>, <도구>, cozy warm colours, friendly"
적:   "chibi <적>, about two heads tall with a big head and small body, ..., grim and menacing,
  desaturated ash, bone and dark violet colours, no blue"
```
기본 모드 + chibi 프리셋은 2차에서 탈락했다(열린 투구, 방패 문장, 북쪽이 앞모습). v3 size 32의 결과(키 약 30px)를 그대로 쓴다(R20). 캐릭터당 2회.
R21부터 아군은 클래스 캐릭터를 통째로 뽑지 않고 기본 몸 + 파츠로 만든다(위 레이어 구조). 기본 몸은 위 아군 프롬프트에서 종족·클래스·모자·도구를 빼고 뽑는다.
- ○ 걷기: 템플릿(`walking-6-frames`, 방향당 1회)으로 남·동·북을 만들고, 서쪽은 동쪽을 좌우 반전한다. 빠진 장비 픽셀은 다른 프레임에서 복사해 채운다(4차: 남쪽 방패 2프레임). skeleton-v3는 장비를 지키지만 20px에서 거의 움직이지 않았다(3차)
- ○ 위협 쪽 색: 생성 뒤 `reduce_colors`에 "그 에셋의 생활 쪽 색 + 북극성 위협 색" 팔레트를 넣어 맞춘다(4차, `03-pixel/palette_grass_threat_v01.png`). 생활 쪽 색이 보라 기운이면 팔레트에서 뺀다

근거 기록:
- 체형 비교 샘플: `assets/concept/03-pixel/chibi_race_sample_v01.png` (손으로 찍음, `tools/art/chibi_sample.py`). 채택은 A'안(같은 체형 + 엘프 귀·드워프 수염)
- PixelLab 1~5차 시험: `assets/concept/03-pixel/prompts.md`. 톤 목업은 `stage3_cozy_grim_mockup_v03.png` (30px 캐릭터, 북극성 팔레트로 맞춘 오염 땅, 걷기 남·동·서). 표식 레이어 목업은 `stage3_signature_layers_v01.png`·`stage3_signature_walk_v01.gif` (5차, 같은 기본 몸 + 표식 4종)

## 6. 운영 규칙

- 폴더: `assets/concept/01-keyart/`, `02-sheets/`, `03-pixel/`, `04-env/`, `05-ui/`
- 파일명: `paladin_v03.png` 처럼 버전 번호. 채택본은 `_final`
- 각 폴더에 `prompts.md`를 두고 프롬프트·도구·모델·job id·레퍼런스 이미지·비율·품질을 기록한다 (시드는 모델이 지원할 때만). 재현할 수 있어야 나중에 고칠 수 있다
- 한 번에 하나만 바꾼다. 조명과 갑옷을 동시에 바꾸면 무엇이 효과였는지 모른다
- 4장씩 뽑고 고른다. 첫 장에 집착하지 않는다
- 잘 나온 이미지는 곧바로 다음 프롬프트의 레퍼런스로 고정한다. 이게 일관성의 8할
- 북극성을 레퍼런스로 넣되 장면을 복사하면 안 되는 생성(시트, 오브젝트, 타일)에는 "use the reference only for its palette and warm colour temperature; do not copy its scene"을 넣는다. 화풍은 단계마다 본문에서 정한다. 성화 UI에는 북극성을 넣지 않는다
- 게임 이름 대신 시각적 특징을 쓴다. "블래스퍼머스 스타일"이 아니라 "gold leaf, dithered shadows, gothic reliquary"
- 도구의 약관과 상업적 사용 조건을 확인하고, 무엇을 어디서 생성했는지 기록을 남긴다

프롬프트 요령 (R15 기록에서 확인한 것, 근거는 01-keyart/prompts.md):
- "orthographic three-quarter top-down"만 쓰면 아이소메트릭이 나왔다(v2·v3). 격자 방향을 직접 써야 정렬형이 나온다. 1차 문구("square floor tiles aligned to the image edges ... Not isometric")와 §5.1의 2차 문구("a grid of square stone tiles whose edges run exactly horizontal and vertical in the image ... Not isometric and not rotated") 모두 4장 중 2장이 정렬됐고 나머지는 대각선·회전 격자였다. 문구만으로는 막을 수 없으니 여러 장 뽑아 원본 해상도로 확인하고 고른다
- 장면 키아트는 회화 원본 → 도트 변환 두 단계로 만든다. 텍스트만으로 바로 도트를 뽑으면 치비 비례가 나왔다(d5723dd1, 47a12576)
- 종족 키 문단을 프롬프트 앞쪽에 두면 드워프는 확실히 작고 넓게 나온다. 엘프 키는 v6에서도 인간과 비슷했다. 2단계 시트에서 보강한다
- 방패 문장: "completely blank, no emblem and no marks"로도 마름모 무늬(v2)나 가운데 징(b24b9991)이 생겼다. v6의 "no emblem, boss or marks"를 쓰고, 원본 해상도로 확대해 확인한다
- 2단계 시트 (R17, 근거는 02-sheets/prompts.md): 두 번째 레퍼런스(팔라딘 시트)의 갑옷이 다른 클래스로 새어 들어온다(광부 v01 어깨갑옷, 시프 v01~v04 판금, 룬마스터 v03 가슴판). 금지 문구와 "Take only the pixel rendering and dark outline from the second reference"로 막았다. 북극성 하나만 쓰면 판금은 사라지지만 배경색·화풍이 다른 시트와 어긋나므로 레퍼런스 두 개를 유지한다
- "front view and three-quarter view"는 가끔 보기 라벨 글자를 그리고(룬마스터 v01), 두 시점이 거의 같은 각도로 나오기도 한다(기술자 v01). 채택 전에 원본 해상도로 확인한다
- PixelLab 1차 시험 (R18, 근거는 03-pixel/prompts.md): 시트를 `image_to_pixelart`로 바꿀 때 `faithful: true`는 흐려졌고, 새로 해석하는 설정은 또렷했지만 색이 바뀌었다(회색 방패 → 주황). 템플릿 걷기는 방패·휘장을 프레임마다 지우고 체형을 표준으로 되돌렸다. 레퍼런스 없는 v3는 캔버스를 거의 다 채운다(48 → 키 약 45px). 기본 타일셋은 글만으로 북극성 질감이 나오지 않았다(격자 무늬 흙, 작은 벽돌, 노란 외곽선). 무료 체험은 동시 작업이 1건이라 애니메이션을 방향마다 따로 호출한다
- PixelLab 2차 시험 (R19): 2등신은 v3(레퍼런스 없음, size 32)에 "about two heads tall with a big head and small body"를 쓰면 잘 나왔다. 기본 모드 + chibi 프리셋은 투구·문장·방향이 틀렸다. v3 2등신은 캔버스를 거의 다 채운다(32 → 키 약 30px). 템플릿 걷기는 체형·투구는 지켰지만 방패를 6프레임 중 2프레임에서 지웠다. 타일셋 `outline: "lineless"`로 노란 외곽선은 사라졌지만 풀이 형광 연두로 나왔다
- PixelLab 3·4차 (R20): 30px 그림을 `image_to_pixelart`(32 출력, `faithful: false`, `init_image_strength: 150`)로 20px로 줄인 뒤 v3로 돌리면 읽히긴 하지만 덩어리졌다. 풀은 "soft warm sage and olive greens ... tiny cream and pink flowers, muted earthy colours"로 차분해졌다. 오염 땅은 글로는 회색이 안 나오고(연보라) `reduce_colors` 팔레트로 잡혔다. 동쪽 걷기를 반전한 서쪽 걷기는 자연스러웠다
- PixelLab 5차 (R23): 기본 몸(v3 size 32)에 템플릿 걷기·숨쉬기를 남·동·북으로 붙였다. `edit_image`(방패)는 모양은 좋았지만 남·북에서 몸 전체를 다시 그렸다. `inpaint_image`(곡괭이·활·북쪽 방패)는 마스크 밖 몸이 그대로라 레이어가 깨끗했다. 후보 몸 하나는 시키지 않은 곤봉을 등에 메고 나와 탈락했다. 기본 몸은 후보를 여러 장 뽑아 장비가 하나도 없는 것을 고른다
- PixelLab 6·7차 (R24): inpaint로 그린 파츠 크기는 마스크 크기를 따른다. 11×12 마스크에서는 폭 4~7px 주머니가, 12~13×14에서는 6~10px가 나왔다. 같은 설명이어도 앞모습(남)이 옆모습보다 작게 나왔다. 6차 남쪽은 폭 4px라 탈락시키고 북쪽 레이어를 반전해 대신했는데, 뒤에서 본 매듭 같은 세부가 앞모습에 남는다. 풀밭 위에서는 중간 톤 초록이 묻히므로 진한 톤에 하이라이트를 넣는다. 작은 파츠는 색을 바꿔도(녹슨 빨강, 무료 시험) 1배에서 나아지지 않았다
- ○ 채택 전 측정 (권장 기준): 356×200으로 bilinear 축소한 뒤 어두운 픽셀 = R+G+B < 200, 차가운 색 = 어두운 픽셀 중 B > R+5, 보라 = B > G+40 이고 R > G+20. 목표는 어두운 픽셀 중 차가운 색 30% 미만, 전체 대비 보라 1% 미만. 격자 방향과 문장은 원본 해상도로 확대해서 확인한다(축소본에서는 회전된 격자가 정렬형처럼 보였다)

## 7. 채택 체크리스트

북극성 v6 판정 (R15):
- [x] 어둠 속에서 제단의 빛이 "안전"으로 읽히는가 (v6: 테두리가 디더링으로 사라지는 빛 원)
- [x] 팔라딘·광부·아처·성직자가 실루엣만으로 구분되는가 (v6)
- [x] 오염이 테라리아의 보라 오염과 다르게 보이는가 (v6: 회색 균열 + 가는 보라 맥, 바닥에 납작)
- [x] 정렬형 탑다운 격자인가 (아이소메트릭이나 회전 격자가 아닌가) (v6)
- 몸집으로 종족이 읽히는가: R18에서 항목 폐지 (체형 통일). v6에서 드워프는 확실했고 엘프와 인간의 키 차이는 약했다
- [ ] 종족 파츠(엘프 귀, 드워프 수염)가 모자를 써도 읽히는가 (3단계. 샘플에서 수염은 확실, 귀는 두건·머리카락과 겹치면 약함. R21부터 종족 파츠는 고르지 않을 수 있다)
- [ ] 같은 외형이어도 표식 장비만으로 9클래스가 구분되는가 (R21. 허리의 셋(시프·약초사·기술자)과 등의 둘(광부·아처)을 특히 본다. R18 샘플에서는 도구·모자로도 시프와 로브를 입은 마법사·성직자가 약했다). 5차(R23): 팔라딘·광부·아처·성직자 넷은 걸어도 구분된다. 1배에서 방패·후광은 확실하고 곡괭이·활은 약하며, 옆모습 방패는 고리처럼 읽힌다. 6·7차(R24): 약초사 씨앗주머니는 작게(폭 6~7px) 그리면 1배에서 보이지 않았고, 몸통 절반 크기로 키우니 옆모습은 확실하고 앞·뒤는 곡괭이·활 정도다. 슬라이스 다섯은 3배에서 모두 구분된다(`03-pixel/stage3_signature_lineup_v03.png`). 남은 것은 2단계의 마법사·시프·기술자·룬마스터
  - 판정 배율: 1배는 가장 엄한 기준이다. ? 실제 화면 배율 (game-concept §7, 엔진과 함께 정한다). §5.0처럼 480×270 화면을 1080p에 띄우면 4배라, 3배 판정이 실제에 가깝다
- [ ] 생활(아기자기)과 위협(음울)이 한 화면에서 대비되는가 (R19. 2차 목업에서 대비는 분명, 풀 색이 형광이라 생활 팔레트를 다듬어야 함)
- 32px로 줄였을 때 클래스 색 하나가 살아남는가: R21에서 항목 폐지 (옷 색은 꾸미기, 클래스 색은 ○ 발밑 표식으로). R17 시트 축소 시험 `02-sheets/class_lineup_32px.png`에서는 마법사와 시프가 어두운 옷이라 비슷하게 묻혔다
- [ ] 성스러움(UI)과 세속(게임 화면)의 대비가 느껴지는가 (5단계)

## 변경 이력

- R6: 1단계 키아트 3엔진 비교 → Seedream 5 Lite 채택. 도트풍 렌더를 북극성으로 확정 (2026-09-22)
- R13: 가제 반영 (제목)
- R14: 저장소 docs/를 원본으로 전환. 북극성 두 장 보관 기록. §1 도구 칸을 실제 사용 도구에 맞춤. 나머지 클래스 5개, §5.2에 룬마스터 변형 추가 (초안). 레퍼런스는 북극성으로 정리 (스타일 보드는 비교용). prompts.md 기록 항목을 AGENTS.md와 맞춤
- R15: 북극성을 v6로 교체 (지상 저녁, 3×3 등잔 제단, 3종족 9인, 정렬형 탑다운). §0·§5.0·§5.1을 v6 기록으로 바꾸고 v1의 프롬프트·URL·당시 접미어는 prompts.md로 옮김. §1에 투영 목적 추가, 방향 수는 ?. §3 접미어에서 문장·단일 광원·보라 덩굴·회화체를 부르는 말을 빼고 따뜻한 그림자와 문장 금지(신앙 상징 결정 전까지)를 넣음. §4에 v6 팔레트 기준과 ○ 녹색 금지. §5.2 종족 체형, 민무늬 방패(no emblem, boss or marks), 레퍼런스는 팔레트·색온도만, 시트 화풍은 ?, "rune"·"glyph"·"engraved"(갑옷) 금지. §5.3 등잔 9개·새김 없는 제단, §5.4 지상 오염, §5.3·§5.4 정렬형 문구, §5.5 상징 없는 임시 UI(○), §5.6 정렬형·방향 수 ?. §6에 프롬프트 요령과 ○ 측정 기준, §7에 v6 판정
- R17: 2단계 클래스 시트 9장 채택 (`02-sheets/<클래스>_vNN_final.png`). §5.2 시트 화풍 ? → ● 도트풍, ● 팔라딘 거구 체형, 실제로 쓴 프롬프트 틀·레퍼런스 두 개·종족 체형 문구로 교체(클래스 문구는 prompts.md로), 시트 스프라이트 높이는 ○. §0 상태·§1 2단계 완료. §5.6 팔라딘 체형·레퍼런스 예. §6에 2단계 요령, §7에 R17 시트 관찰
- R18: 3단계 화풍 결정 (PixelLab 1차 시험과 체형 비교 샘플 뒤). 머리말·§0 상태·§1. §5.6을 다시 씀: ● 도트 구조는 Tiny Farm RPG(32×32 프레임, 2등신 약 20px, 1px 외곽선, 2~3단 명암, low top-down), 북극성은 분위기·질감·팔레트 기준, ● 체형 통일·종족은 머리 표식·직분은 도구, Tiny Farm 이미지는 도구에 넣지 않음. 시점 ? → ● low top-down, 종족 키 ○ → 폐지, 방향 수는 ? 그대로, ○ 모션 프레임과 다음 PixelLab 설정. §5.2 거구 팔라딘(R17) 폐지, 시트는 의상·도구 기준. §3 네거티브의 치비 금지는 컨셉 이미지에만. §5.0 종족 키 설명. §6에 PixelLab 1차 요령, §7 종족 몸집 항목을 머리 표식·도구 구분 항목으로
- R19: 톤 이원화와 방향 결정 (PixelLab 2차 시험). 머리말·§0 상태·§1. §5.6에 ● 톤(캐릭터·생활·꾸미기는 아기자기, 외부 위협은 북극성의 음울한 색), ○ 제단 빛 안/밖 해석, 색 줄을 생활/위협으로 나눔, 방향 ? → ● Tiny Farm식(아래·위·옆 + 좌우 반전), PixelLab 설정을 v3 기준으로 바꾸고 키 문제(약 30px) 기록. §3 접미어는 위협 쪽에만. §6에 2차 요령, §7에 대비 항목
- R20: 캐릭터 키 약 20px → ● 약 30px (32 프레임을 거의 채움, PixelLab 3차 시험 뒤 사람이 정함). §0 상태, §5.6 크기 줄과 PixelLab 설정(v3 size 32 그대로, ○ 걷기는 템플릿 + 반전 + 빠진 장비 복사, ○ 위협 쪽 색은 reduce_colors 팔레트), §6에 3·4차 요령
- R21: 외형을 클래스에서 떼어냄 (game-concept §3). §0 상태. §5.6: R18의 "직분은 도구·모자·옷" → ● 클래스는 표식 장비 9종으로만, ● 종족은 고르지 않아도 되는 꾸미기 파츠(인간은 ?), R17 시트의 옷·모자는 꾸미기 참고. ○ 레이어 구조(기본 몸 + 파츠 + 표식, 방향별 순서표, 기준점, edit_image로 파츠 추출), ○ 모자 3종과 종족 파츠는 모자 밖, 모자 높이(32×40은 ?), ○ 표식 장비 그리기(허리 셋·등 둘 구분, 떠 있는 표식은 별도 스프라이트). §5.0·§5.2 설명. §7 클래스 판별 항목을 표식 장비로, 클래스 색 항목 폐지
- R22: §5.6 인간 파츠 없음, ● 프레임 32×32 그대로(모자는 머리 위 2~3px 안, 32×40 ? 해소), ● 투구 숨기기 토글, ● 망치 둘(기술자는 제작·설치 동작에만, 룬마스터는 공격할 때 마법 망치), ○ 마법 망치 모양
- R23: 약초사를 슬라이스에 추가(§1 순서). §5.6 만드는 법을 `edit_image` → `inpaint_image` 방향당 1장 + 기준점 붙이기로(PixelLab 5차), ○ 발 맞춤(머리 위 3~4px 확보), ○ Tiny Farm 정식판 구조(조립 레이어, 방향, 크기, 도구가 나눠 쓰는 몸 동작, 동작·프레임과 클래스 대응, 슬라이스 몸 동작 11개, 작물 성장 칸, 작업대, 식물 적). 정식판은 저장소 밖에 둔다. §4 ○ 작물 녹색과 오염 녹색. §6 5차 요령, §7 5차 판정
- R24: §0 상태. §5.6 허리 표식 ○ 크기(몸통 절반, 발 높이까지 처져도 됨)와 ○ 씨앗주머니 모양 (PixelLab 6·7차). §6 6·7차 요령(마스크 크기 = 파츠 크기, 앞모습이 작게 나옴, 풀밭 위 초록). §7 6·7차 판정과 판정 배율(1배가 가장 엄한 기준, 실제 화면 배율은 ?)
