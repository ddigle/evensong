# Evensong: The Nine Lamps — 컨셉아트 브리프

> game-concept.md의 아트 방향(§10)을 실제 이미지 도구에 넣기 위한 실행 문서.
> 기준: A안(32px 음울한 중세 픽셀 + 동적 조명), 정렬형 탑다운 + C안의 장식 언어는 제단과 UI에만.
> 상태: 라운드 15 · 2026-10-02

## 0. 북극성 (확정, R15 · 2026-10-02)

**북극성 = `assets/concept/01-keyart/northstar_pixel_v6_final.png`.** 이후 모든 생성의 레퍼런스이자 판단 기준.
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

**v1에서 바꾼 이유 (R15).** R6의 v1은 종족 배치(R9), 9인(R11), 지상+지하(R12), 가제(R13)보다 먼저 만들어졌다. 그래서 지하 동굴에 인간 비례 4명, 남색 그림자, 채도 높은 보라 덩굴로 그려져 있었다. v6는 이것을 모두 고쳤고, 아이소메트릭 후보(v3)와 비교한 끝에 투영을 정렬형 탑다운으로 정했다.
- v1 기록: 북극성 6e3a72c4-bafe-45c9-b21a-a42833eb35b6, 원본 d2440f66-cd96-4dce-bc45-7c140b397eed. 파일은 `northstar_pixel_v1.png`, `keyart_seedream_v1.png`로 보관한다
- R6 비교군 (탈락): Nano Banana 2 (8519319d-6576-4c44-93b8-5e7b5caefb19), Nano Banana Pro (d55b86e8-0eac-4456-9ee8-5f7000e79d89)
- R15 후보와 탈락작 31장의 job id, 측정값, 탈락 이유는 `assets/concept/01-keyart/prompts.md`

크레딧 기록: R6 1단계 5.5크레딧 (무료 플랜). R15 북극성 재작업 31크레딧 (starter 플랜, 잔액 274.5 → 243.5, 2026-10-02). 생성 전에는 `balance`로 실제 잔액을 확인한다.

상태: 1단계 완료 (R15 재채택). 다음은 2단계 팔라딘 시트 (`seedream_v5_lite` + 북극성 레퍼런스, §5.2) → 3단계 PixelLab.

## 1. 단계

| 단계 | 산출물 | 도구 | 목적 |
|---|---|---|---|
| 1 무드 키아트 | 3~5장 중 1장을 "북극성"으로 채택 | 힉스필드 Seedream 5.0 Lite (완료, §0. R15 재채택) | 톤·팔레트·빛·투영 확정 |
| 2 클래스 시트 | 팔라딘 1장 먼저 → 채택본을 레퍼런스로 나머지 | 힉스필드 `seedream_v5_lite` + 레퍼런스 이미지(`medias` image_references) | 실루엣과 클래스 색 확정 |
| 3 픽셀 전환 | 32px 스프라이트, 4방향, idle/walk/attack | PixelLab (+ Aseprite) | 실제 에셋 |
| 4 환경·오브젝트 | 제단, 오염 타일, 바이옴 2개 무드 | 1~2단계 도구 → PixelLab 타일셋 | 슬라이스 환경 |
| 5 성화 UI | 코덱스 페이지, 기도 화면, 아이콘 프레임 | 이미지 모델 (+ Recraft 벡터) | 정적, 가장 쉬움 |

슬라이스 순서: 팔라딘 → 광부 → 아처 → 성직자. 나머지 5개(마법사·약초사·시프·기술자·룬마스터)는 슬라이스 검증 후.

## 2. 도구 배정 이유

- 컨셉·키아트: 힉스필드는 여러 이미지 모델을 한 곳에서 쓰고, MCP로 클로드 대화창에서 바로 뽑을 수 있다. 미드저니 V7은 회화적 품질이 가장 높지만 세밀한 지시(특정 갑옷 수정)에는 약하다. FLUX.2 Pro는 프롬프트 충실도가 높아 "이 요소를 꼭 넣어라"에 강하다
- 픽셀: 범용 모델은 "픽셀풍" 그림을 만들 뿐 격자에 맞는 진짜 픽셀아트가 아니다. PixelLab은 격자 크기(16/32/64)를 이해하고 4·8방향 회전, 타일셋, 애니메이션 시트를 만들며 Aseprite 플러그인과 MCP 에이전트 툴킷이 있다
- 대량 일관성: 에셋이 수백 개가 되면 Scenario에 채택본을 학습시켜 스타일 드리프트를 막는다. 슬라이스 단계에서는 아직 불필요

## 3. 공통 스타일 접미어 (모든 프롬프트 끝에 붙인다)

```
grim medieval fantasy, worn materials, plain gear without emblems or symbols,
warm candle-gold light against warm brown-black shadows, no blue or navy in any shadow,
muted palette of ash/stone/leather with candle-gold accents,
corruption as grey cracked earth with thin bruise-violet veins,
no text, no letters, no watermark, no UI
```
렌더링(회화체·도트풍)과 조명의 세기는 단계마다 본문에 쓴다. §5.0과 §5.1은 그 자체로 완결된 프롬프트라 접미어를 붙이지 않는다.

네거티브 (지원하는 도구에서. `seedream_v5_lite`는 지원하지 않는다):
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

레퍼런스 이미지는 북극성(§0)을 넣는다. A~D 스타일 보드(`assets/concept/01-keyart/style-board-4options.png`)는 화풍이 섞여 있고 글자가 있어 생성 레퍼런스로 쓰지 않는다.

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
같은 프롬프트로 4장을 뽑아 2장이 엄밀한 정렬 격자로 나왔다. 인물은 일렬 대형으로 섰다.

### 5.2 팔라딘 캐릭터 시트 (2단계)

```
Character concept sheet, front view and three-quarter view of the same character, full body.
A human paladin of a grim medieval faith, medium build: heavy plate armor in worn steel with
gold-leaf trim, a tall kite shield that is completely blank, flat dull steel with no emblem and
no marks, closed helm with a narrow visor, ash-gray tabard with a single gold stripe. Solemn,
weathered, devout. Clean silhouette readable at small size.
Plain dark background, neutral even lighting, single character.
Use the reference only for its rendering style, palette and warm lighting; do not copy its scene.
Palette: worn iron and ash (#4a423a, #8c7b66), leather (#6b5e4f), gold (#c9932b, #f4c95d). [공통 접미어]
```

북극성 job id를 레퍼런스로 넣는다(AGENTS.md). 나머지 클래스는 이 틀에서 두 번째 문장(종족·체형·장비)만 바꾸고, 채택된 팔라딘 시트도 레퍼런스로 넣는다. 이때 "same rendering style as the reference"만 쓰고 비례는 복사하지 않는다. 종족마다 체형이 다르다(인간 중간, 엘프 크고 가늘게, 드워프 낮고 넓게).

? 시트 화풍(회화체 / 도트풍)은 2단계를 시작하기 전에 정한다. 위 프롬프트는 어느 쪽인지 정하지 않는다.

- 광부 (드워프): short, very broad, heavily bearded dwarf, leather apron and gloves, round helmet with a small oil lamp, heavy pickaxe, soot-stained
- 아처 (엘프): tall, slender elf with long pointed ears, earth-brown hooded cloak, longbow taller than the shoulders, quiver, face half in shadow
- 성직자 (인간): human of medium build, ivory robes with a gold stole, deep hood, long staff topped with a small flame, prayer beads
- 마법사 (엘프): tall, slender elf with long pointed ears, charcoal robes with copper trim, one hand holding a small glowing enchanting crystal, no hat, calm posture
- 약초사 (인간): human of medium build, patched brown and ochre garb, satchel of herbs and vials, small animal companion at the feet
- 시프 (엘프): tall, slender elf with long pointed ears, dark leather, short hooded cape, twin daggers, crouched stance, half-turned
- 기술자 (드워프): short, very broad, bearded dwarf, leather apron with tool belt, goggles on forehead, backpack of gears and a coiled rope, one hand on a small mechanical trap
- 룬마스터 (드워프, 초안): short, very broad, bearded dwarf, engraved mail under a stone-gray mantle, heavy engraving hammer, small glowing stones on the belt

녹색 옷은 쓰지 않는다(녹색은 오염 신호 전용). "rune", "glyph" 같은 단어는 글자를 부르므로 프롬프트에 쓰지 않는다.

### 5.3 제단 (4단계)

```
Straight top-down view (square grid aligned to the image edges, not isometric) of a portable
stone altar for a grim medieval faith: a broad, low, square block of gray stone with worn
gold-leaf rims, its edges parallel to the image edges. On its top, nine small clay oil lamps in
three straight rows of three, nine separate flames; small offerings of bone and dried herbs at
its base. Isolated on a plain dark background. [공통 접미어]
```

### 5.4 오염 지대 무드 (4단계)

```
Straight top-down view (square tiles aligned to the image edges, not isometric) of surface
ground near a dungeon entrance being consumed by corruption: grey cracked earth with thin dark
bruise-violet veins, patches of dull olive mould, small flat bone-coloured nodules, a heretic's
crude shrine of stacked skulls at the source. Everything lies flat, nothing grows upward, matte
and unlit. Palette: #3b1f4d, #5e2d7a, #6f8f3a, #d8d2c0 on ash black, violet only in thin veins.
[공통 접미어]
```

### 5.5 성화 UI (5단계)

```
Illuminated manuscript page border with a stained-glass rose window motif, gold leaf on aged
parchment, sacred iconography of a candle flame and a shield, gothic tracery, symmetrical,
flat decorative design, high contrast. Palette: gold (#c9932b, #f4c95d), ivory (#efe3c6),
deep red (#5c1010), ash black (#1a1714). No text.
```

### 5.0 도트풍 재현 (북극성 v6에 쓴 프롬프트, 레퍼런스 = §5.1 결과 필수)

```
Re-draw the reference image as a pixel art screenshot of a top-down 2D video game, keeping the same composition, camera, scale, figures, altar and light layout. Keep the straight top-down grid: square floor tiles whose edges run exactly horizontal and vertical, not isometric, not rotated. Treat it as a 480 by 270 pixel game screen enlarged with nearest-neighbour scaling: every art pixel is a square block of the same size on one strict grid, no anti-aliasing, no blur, no smooth gradients, dithering only in the deepest shadows and in the falloff band at the rim of the light. The ground is built from 16-pixel tiles.
Keep three clearly different body heights as sprites: elves about 32 pixels tall and thin, humans about 28, dwarves about 22 pixels tall and almost as wide as a human. Each sprite has a dark outline and a readable role item: tall plain shield, staff with a small flame, herb satchel, longbow, twin daggers, small crystal, pickaxe and helmet lamp, engraving hammer, gear backpack. The altar keeps its nine lamp flames in three rows of three; each of the nine flames stays a separate bright dot, and they stay the brightest point on screen.
Re-map every colour to a limited palette of about 48 colours, even where the reference is cooler: shadows warm brown-black #1a1714 #2e2a26, ground ash and earth #4a423a #6b5e4f #8c7b66, light candle gold and ivory #f4c95d #c9932b #9c6a1f #efe3c6, corruption grey cracked earth with bone #d8d2c0 and dull olive #6f8f3a, violet only as thin dark lines #3b1f4d #5e2d7a. No blue or navy in any shadow. The flat corruption stops at the rim of the golden circle. Grim medieval fantasy, plain gear without emblems. No text, no letters, no watermark, no UI.
```
범용 모델의 "도트풍"이라 격자가 완전히 정확하지는 않다(바닥 빛에 부드러운 그라데이션이 남는다). 무드와 기준용이다. 진짜 도트는 §5.6.

### 5.6 픽셀 전환 (3단계, PixelLab)

```
32px tall straight top-down character sprite (not isometric), 4 directions, grim medieval
human paladin: worn steel armor with gold trim, tall blank shield on the left arm, closed helm.
Limited palette, clean silhouette, no anti-aliasing. [채택된 시트 이미지를 레퍼런스로 첨부]
```
애니메이션은 idle(4프레임) → walk(6~8프레임) → attack(4~6프레임) 순서로.
? 방향 수(4 / 8)와 PixelLab의 view(low / high top-down)는 3단계 전에 정한다.

## 6. 운영 규칙

- 폴더: `assets/concept/01-keyart/`, `02-sheets/`, `03-pixel/`, `04-env/`, `05-ui/`
- 파일명: `paladin_v03.png` 처럼 버전 번호. 채택본은 `_final`
- 각 폴더에 `prompts.md`를 두고 프롬프트·도구·모델·job id·레퍼런스 이미지·비율·품질을 기록한다 (시드는 모델이 지원할 때만). 재현할 수 있어야 나중에 고칠 수 있다
- 한 번에 하나만 바꾼다. 조명과 갑옷을 동시에 바꾸면 무엇이 효과였는지 모른다
- 4장씩 뽑고 고른다. 첫 장에 집착하지 않는다
- 잘 나온 이미지는 곧바로 다음 프롬프트의 레퍼런스로 고정한다. 이게 일관성의 8할
- 북극성을 레퍼런스로 넣되 장면을 복사하면 안 되는 생성(시트, 타일, UI)에는 "use the reference only for its rendering style, palette and warm lighting; do not copy its scene"을 넣는다
- 게임 이름 대신 시각적 특징을 쓴다. "블래스퍼머스 스타일"이 아니라 "gold leaf, dithered shadows, gothic reliquary"
- 도구의 약관과 상업적 사용 조건을 확인하고, 무엇을 어디서 생성했는지 기록을 남긴다

프롬프트 요령 (R15에서 확인한 것):
- "top-down"이나 "orthographic three-quarter"만 쓰면 Seedream은 대개 아이소메트릭이나 회전된 격자로 그린다. 정렬형은 "square floor tiles whose edges run exactly horizontal and vertical ... Not isometric and not rotated"처럼 격자 방향을 직접 쓴다
- 장면 키아트는 회화 원본 → 도트 변환 두 단계로 만든다. 텍스트만으로 바로 도트를 뽑으면 치비 비례가 나온다
- 종족 키 문단은 프롬프트 앞쪽에 둔다. 뒤에 두면 엘프가 커지지 않는다
- 문장을 막으려면 "completely blank, no emblem and no marks"까지 쓴다. "plain shield"만으로는 문장이 생긴다
- 채택 전에 잰다: 356×200으로 줄여 어두운 픽셀 중 차가운 색 30% 미만, 보라 픽셀 1% 미만. 격자 방향과 문장은 원본 해상도로 확대해서 확인한다(축소본에서는 회전된 격자가 정렬형처럼 보인다)

## 7. 채택 체크리스트

북극성 v6 판정 (R15):
- [x] 어둠 속에서 제단의 빛이 "안전"으로 읽히는가 (v6: 테두리가 디더링으로 사라지는 빛 원)
- [x] 팔라딘·광부·아처·성직자가 실루엣만으로 구분되는가 (v6)
- [x] 오염이 테라리아의 보라 오염과 다르게 보이는가 (v6: 회색 균열 + 가는 보라 맥, 바닥에 납작)
- [x] 정렬형 탑다운 격자인가 (아이소메트릭이나 회전 격자가 아닌가) (v6)
- [ ] 몸집으로 종족이 읽히는가 (v6: 드워프는 확실, 엘프와 인간의 키 차이는 약함. 2단계 시트에서 보강)
- [ ] 32px로 줄였을 때 클래스 색 하나가 살아남는가 (3단계)
- [ ] 성스러움(UI)과 세속(게임 화면)의 대비가 느껴지는가 (5단계)

## 변경 이력

- R6: 1단계 키아트 3엔진 비교 → Seedream 5 Lite 채택. 도트풍 렌더를 북극성으로 확정 (2026-09-22)
- R13: 가제 반영 (제목)
- R14: 저장소 docs/를 원본으로 전환. 북극성 두 장 보관 기록. §1 도구 칸을 실제 사용 도구에 맞춤. 나머지 클래스 5개, §5.2에 룬마스터 변형 추가 (초안). 레퍼런스는 북극성으로 정리 (스타일 보드는 비교용). prompts.md 기록 항목을 AGENTS.md와 맞춤
- R15: 북극성을 v6로 교체 (지상 저녁, 3×3 등잔 제단, 3종족 9인, 정렬형 탑다운). §0·§5.0·§5.1을 v6 기록으로 바꿈. §3 접미어에서 문장·단일 광원·보라 덩굴을 부르는 말을 빼고 따뜻한 그림자를 넣음. §5.2에 종족 체형 반영, 방패 문장 삭제, 레퍼런스는 화풍만 쓰도록. §5.3 등잔 9개 제단, §5.4 지상 오염, §5.6 정렬형. §6에 프롬프트 요령, §7에 v6 판정
