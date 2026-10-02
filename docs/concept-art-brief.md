# Evensong: The Nine Lamps — 컨셉아트 브리프

> game-concept.md의 아트 방향(§10)을 실제 이미지 도구에 넣기 위한 실행 문서.
> 기준: A안(32px 음울한 중세 픽셀 + 동적 조명) + C안의 장식 언어는 제단과 UI에만.
> 상태: 라운드 14 · 2026-10-02

## 0. 북극성 (확정, 2026-09-22)

**북극성 = 도트풍 렌더.** 이후 모든 생성의 레퍼런스이자 판단 기준.
- 도구: 힉스필드 MCP → Seedream 5.0 Lite, 이미지 레퍼런스 = 아래 원본 키아트
- job: 6e3a72c4-bafe-45c9-b21a-a42833eb35b6
- URL: https://d8j0ntlcm91z4.cloudfront.net/user_3JgRtXwbNoo2upapZF30zhtgJ8O/hf_20260922_134344_6e3a72c4-bafe-45c9-b21a-a42833eb35b6.png
- 프롬프트: §5.6 앞에 추가한 "도트풍 재현" 프롬프트 (§5.0)

**원본 키아트 (북극성의 부모).** 회화체. 톤·구도의 원본.
- 도구: Seedream 5.0 Lite, 텍스트만 (§5.1 프롬프트 그대로)
- job: d2440f66-cd96-4dce-bc45-7c140b397eed
- URL: https://d8j0ntlcm91z4.cloudfront.net/user_3JgRtXwbNoo2upapZF30zhtgJ8O/hf_20260922_133119_d2440f66-cd96-4dce-bc45-7c140b397eed.png

비교군 (탈락): Nano Banana 2 (8519319d-6576-4c44-93b8-5e7b5caefb19), Nano Banana Pro (d55b86e8-0eac-4456-9ee8-5f7000e79d89). 같은 §5.1 프롬프트.

보관: 2026-10-01 두 장을 `assets/concept/01-keyart/northstar_pixel_v1.png`, `keyart_seedream_v1.png`로 저장소에 보관했다 (LFS). 위 URL은 만료될 수 있다.

크레딧 기록: 1단계 총 5.5 크레딧 (Seedream lite 1 + Nano Banana 2 1.5 + Nano Banana Pro 2 + 도트풍 1). 잔여 4.5 (2026-09-22 기준. 생성 전에는 `balance`로 실제 잔액을 확인한다).

상태: 1단계 완료. 다음은 2단계 팔라딘 시트 (Seedream lite + 북극성 레퍼런스) → 3단계 PixelLab.

## 1. 단계

| 단계 | 산출물 | 도구 | 목적 |
|---|---|---|---|
| 1 무드 키아트 | 3~5장 중 1장을 "북극성"으로 채택 | 힉스필드 Seedream 5.0 Lite (완료, §0) | 톤·팔레트·빛 확정 |
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
grim medieval fantasy, religious iconography, gothic reliquary details, worn materials,
painterly concept art, high-contrast chiaroscuro, single warm light source against deep shadow,
muted palette of ash/stone/leather with candle-gold accents and violet corruption,
no text, no watermark, no UI
```

네거티브 (지원하는 도구에서):
```
photorealism, anime, cute chibi proportions, bright saturated colors, modern or sci-fi elements,
text, watermark, blurry, extra limbs
```

## 4. 팔레트 코드 (프롬프트에 그대로 넣는다)

- 기반: #1a1714 #2e2a26 #4a423a #6b5e4f #8c7b66
- 신앙: #f4c95d #c9932b #9c6a1f #efe3c6 #6f5522
- 타락: #3b1f4d #5e2d7a #8a5fb0 #6f8f3a #d8d2c0
- 악마: #2a0808 #5c1010 #8f1a1a #c8321f #ff7a1a

레퍼런스 이미지는 북극성(§0)을 넣는다. A~D 스타일 보드(`assets/concept/01-keyart/style-board-4options.png`)는 화풍이 섞여 있고 글자가 있어 생성 레퍼런스로 쓰지 않는다.

## 5. 바로 쓰는 프롬프트

### 5.1 무드 키아트 (1단계)

```
Top-down view of a dark underground sanctuary. A small stone altar with a single candle flame
casts a warm amber radius on a damp cave floor; beyond the light, darkness and creeping violet
corruption with pale bone-white growths. Four figures around the altar: an armored paladin with
a tall shield, a hooded cleric in ivory robes with a gold stole and staff, an archer in an
earth-brown cloak with a longbow, a miner with a lamp helmet and pickaxe.
Palette: ash and stone (#1a1714, #2e2a26, #4a423a, #6b5e4f), candle gold (#f4c95d, #c9932b),
corruption violet (#3b1f4d, #5e2d7a). [공통 접미어]
```

### 5.2 팔라딘 캐릭터 시트 (2단계)

```
Character concept sheet, front view and three-quarter view of the same character, full body.
A paladin of a grim medieval faith: heavy plate armor in worn steel with gold-leaf trim, a tall
kite shield bearing a simple sacred emblem, closed helm with a narrow visor, ash-gray tabard with
a single gold stripe. Solemn, weathered, devout. Clean silhouette readable at small size.
Plain dark background, neutral even lighting.
Palette: steel gray (#4a423a, #8c7b66), leather (#6b5e4f), gold (#c9932b, #f4c95d). [공통 접미어]
```

북극성 이미지를 레퍼런스로 함께 넣는다. 나머지 클래스는 이 틀에서 두 번째 문장만 바꾼다. 채택된 팔라딘 이미지를 레퍼런스로 넣고 "same rendering style and proportions as the reference"를 추가한다.

- 광부: leather apron and gloves, round helmet with a small oil lamp, heavy pickaxe, soot-stained, sturdy build
- 아처: earth-brown hooded cloak, longbow taller than the shoulders, quiver, lean build, face half in shadow
- 성직자: ivory robes with a gold stole, deep hood, long staff topped with a small flame, prayer beads, thin build
- 마법사: charcoal robes with copper runes, one hand holding an enchanting crystal, no hat, calm posture
- 약초사: patched green-brown garb, satchel of herbs and vials, small animal companion at the feet
- 시프: dark leather, short hooded cape, twin daggers, crouched stance, half-turned
- 기술자: leather apron with tool belt, goggles on forehead, backpack of gears and a coiled rope, one hand on a small mechanical trap
- 룬마스터 (초안): rune-etched mail under a stone-gray mantle, heavy engraving hammer, glowing rune stones on the belt, short broad build

### 5.3 제단 (4단계)

```
Top-down view, a portable stone altar for a grim medieval faith: a squat block of gray stone with
worn gold-leaf edges, a single tall candle burning in a copper holder, small offerings of bone and
dried herbs at its base. Isolated on a plain dark background. [공통 접미어]
```

### 5.4 오염 지대 무드 (4단계)

```
Top-down view of cave floor being consumed by corruption: violet veins spreading through cracked
stone, pale bone-white nodules, sickly green fungus, a heretic's crude shrine of stacked skulls at
the source. Palette: #3b1f4d, #5e2d7a, #8a5fb0, #6f8f3a, #d8d2c0 on ash black. [공통 접미어]
```

### 5.5 성화 UI (5단계)

```
Illuminated manuscript page border with a stained-glass rose window motif, gold leaf on aged
parchment, sacred iconography of a candle flame and a shield, gothic tracery, symmetrical,
flat decorative design, high contrast. Palette: gold (#c9932b, #f4c95d), ivory (#efe3c6),
deep red (#5c1010), ash black (#1a1714). No text.
```

### 5.0 도트풍 재현 (북극성에 쓴 프롬프트, 레퍼런스 이미지 필수)

```
Recreate the reference scene as authentic 16-bit top-down pixel art for a video game: the same
dark underground sanctuary, stone altar with a single candle flame casting a warm amber light
radius, violet corruption creeping at the edges with bone-white growths, and the same four
characters (paladin with tall shield, cleric in ivory robes with staff, archer with longbow,
miner with lamp helmet and pickaxe) as 32-pixel-tall sprites with clear readable silhouettes.
Strict pixel grid, crisp square pixels, no anti-aliasing, no blur, limited palette of about 48
colors, dithering only in the shadow gradients, tile-based cave floor of 16-pixel tiles.
Palette: ash and stone (#1a1714, #2e2a26, #4a423a, #6b5e4f), candle gold (#f4c95d, #c9932b),
corruption violet (#3b1f4d, #5e2d7a). Grim medieval fantasy, religious iconography.
No text, no watermark, no UI.
```
범용 모델의 "도트풍"이라 격자가 정확하지 않다. 무드 확인용. 진짜 도트는 §5.6.

### 5.6 픽셀 전환 (3단계, PixelLab)

```
32px tall top-down character sprite, 4 directions, grim medieval paladin: worn steel armor with
gold trim, tall shield on the left arm, closed helm. Limited palette, clean silhouette,
no anti-aliasing. [채택된 시트 이미지를 레퍼런스로 첨부]
```
애니메이션은 idle(4프레임) → walk(6~8프레임) → attack(4~6프레임) 순서로.

## 6. 운영 규칙

- 폴더: `assets/concept/01-keyart/`, `02-sheets/`, `03-pixel/`, `04-env/`, `05-ui/`
- 파일명: `paladin_v03.png` 처럼 버전 번호. 채택본은 `_final`
- 각 폴더에 `prompts.md`를 두고 프롬프트·도구·모델·job id·레퍼런스 이미지·비율·품질을 기록한다 (시드는 모델이 지원할 때만). 재현할 수 있어야 나중에 고칠 수 있다
- 한 번에 하나만 바꾼다. 조명과 갑옷을 동시에 바꾸면 무엇이 효과였는지 모른다
- 4장씩 뽑고 고른다. 첫 장에 집착하지 않는다
- 잘 나온 이미지는 곧바로 다음 프롬프트의 레퍼런스로 고정한다. 이게 일관성의 8할
- 게임 이름 대신 시각적 특징을 쓴다. "블래스퍼머스 스타일"이 아니라 "gold leaf, dithered shadows, gothic reliquary"
- 도구의 약관과 상업적 사용 조건을 확인하고, 무엇을 어디서 생성했는지 기록을 남긴다

## 7. 채택 체크리스트

- [ ] 어둠 속에서 제단의 빛이 "안전"으로 읽히는가
- [ ] 팔라딘·광부·아처·성직자가 실루엣만으로 구분되는가
- [ ] 오염이 테라리아의 보라 오염과 다르게 보이는가
- [ ] 32px로 줄였을 때 클래스 색 하나가 살아남는가
- [ ] 성스러움(UI)과 세속(게임 화면)의 대비가 느껴지는가

## 변경 이력

- R6: 1단계 키아트 3엔진 비교 → Seedream 5 Lite 채택. 도트풍 렌더를 북극성으로 확정 (2026-09-22)
- R13: 가제 반영 (제목)
- R14: 저장소 docs/를 원본으로 전환. 북극성 두 장 보관 기록. §1 도구 칸을 실제 사용 도구에 맞춤. 나머지 클래스 5개, §5.2에 룬마스터 변형 추가 (초안). 레퍼런스는 북극성으로 정리 (스타일 보드는 비교용). prompts.md 기록 항목을 AGENTS.md와 맞춤
