# 01-keyart 기록

## 북극성 v2 후보 (2026-10-02, 채택 대기)

v1(R6)이 R9~R13 결정(3종족×3직분 9클래스, 9인, 지상+지하, 가제 "아홉 등불")과 맞지 않아 다시 잡았다.
방향: 재빛 저녁의 지상, 제단 윗면의 등잔 9개(3×3), 금빛 원 안에서 인간·엘프·드워프가 셋씩 저녁기도. 오염은 던전 입구에서 새어 나와 빛의 경계에서 멈춘다. 신앙 문장은 그리지 않는다.
공통 설정: 힉스필드 MCP / `seedream_v5_lite`, 16:9, quality high (출력 4096×2304), 장당 1크레딧. 이 모델은 시드를 지정할 수 없다.
측정(356×200 축소, 어두운 픽셀 중 차가운 색 비율 / 보라 픽셀 비율. 목표 30% 미만 / 1% 미만): v1 도트 86% / 5.5%, v1 회화 76% / 0.11%.

### keyart_seedream_v2.png (회화 원본)
- job: 4502794d-8ab1-4837-b7ac-c235f0259d53. 레퍼런스 없음(텍스트만). 측정 1% / 0.34%
- 3×3 등잔 9개, 드워프 셋(톱니 배낭·광부 헬멧·망치), 키 크고 귀가 뾰족한 엘프(마법사·아처). 인물은 10명, 방패에 작은 마름모 무늬, 오염 일부가 벽을 타고 오른다
- 프롬프트:

```
Orthographic three-quarter top-down game camera, like a classic tile-based RPG: ground seen from high above, upright things slightly from the front, no vanishing point, no sky, no horizon. The frame shows about thirty floor tiles across; each figure is small, a human about one eighth of the image height, with open ground around everyone.

Exactly nine figures of three peoples, and height is how you tell the peoples apart: the three elves are the tallest, a full head taller than the humans, very slender with long limbs and long pointed ears; the three humans are of medium height; the three dwarves are the shortest, two-thirds of human height, very broad and heavily bearded.

Evening on the surface of a dying land: thick ash and smoke hide the sunken sun, and the dead grass, packed earth and broken flagstones are tinted warm umber and dull ochre-brown; the deepest shadows are the brown-black of old soot. No cave.

Center: a broad, low, square solid stone altar about three tiles wide with worn gold-leaf edges. On its top, nine small clay oil lamps in three rows of three, with dark gaps between them: nine separate flames, all burning, the brightest point in the image. A thin thread of incense smoke rises. Their light makes one round pool of candle-gold about half the image wide over worn paving stones, fading softly at the rim, with no drawn line and no glowing ring on the ground. All nine figures stand inside the light, shadows pointing outward.

They stand in evening prayer, heads bowed, weapons lowered, in three groups of three. Behind the altar, facing the viewer, the three humans: a paladin in worn plate and closed helm resting on a tall kite shield that is completely blank, flat dull steel with no emblem and no marks; a cleric in dull ivory robes and gold stole, one hand lifted to lead the prayer, the other holding a plain staff topped by a small flame; a herbalist in patched brown and ochre clothes with a bulging herb satchel.
On the left, the three dwarves: at the front-left of the light a miner with a pickaxe and a small lamp on a round helmet; behind him a smith with a heavy engraving hammer and an engineer with a backpack of gears.
On the right, the three tall elves: at the front-right of the light an archer in earth-brown leathers, hood down, with a longbow taller than the shoulders, the only bow in the scene; behind, a hooded thief with twin daggers and a mage in charcoal robes holding a small glowing crystal in one open hand. The front of the altar is left open.

Upper-right corner: a collapsed stone stairway sinks into a black opening, and corruption seeps out: grey cracked earth with thin dark bruise-violet veins, patches of dull olive mould, small bone-coloured nodules lying flat. Nothing grows upward; it is matte, unlit, darker than the lit ground, and stops at the rim of the light. Left edge: a dark rock wall with a few tile-sized chunks dug out.

Palette: 80% desaturated warm grey-brown #1a1714 #2e2a26 #4a423a #6b5e4f #8c7b66; light in candle gold and ivory #f4c95d #c9932b #efe3c6; corruption #3b1f4d #6f8f3a #d8d2c0, violet only in thin veins. Plain worn clothing in ash, leather and earth tones; no emblems, symbols, letters or marks on shields, clothing or the altar. Grim medieval fantasy, painterly concept art, clean readable shapes. No text, no letters, no watermark, no UI.
```

### northstar_pixel_v2.png (도트 변환)
- job: e0b09f78-edd0-4128-9ace-6f31d9f3e9db. 레퍼런스: keyart_seedream_v2 (4502794d…). 측정 1% / 0.43%
- 구도·인물·등잔을 그대로 유지. 방패 마름모 무늬와 벽을 타는 마젠타 오염 덩굴이 남아 있다
- 프롬프트:

```
Re-draw the reference image as a pixel art screenshot of a top-down 2D video game, keeping the same composition, camera, scale, figures, altar and light layout. Treat it as a 480 by 270 pixel game screen enlarged with nearest-neighbour scaling: every art pixel is a square block of the same size on one strict grid, no anti-aliasing, no blur, no smooth gradients, dithering only in the deepest shadows and in the falloff band at the rim of the light. The ground is built from 16-pixel tiles.
Keep three clearly different body heights as sprites: elves about 32 pixels tall and thin, humans about 28, dwarves about 22 pixels tall and almost as wide as a human. Each sprite has a dark outline and a readable role item: tall plain shield, staff with a small flame, herb satchel, longbow, twin daggers, small crystal, pickaxe and helmet lamp, engraving hammer, gear backpack. The altar keeps its nine lamp flames in three rows of three; each of the nine flames stays a separate bright dot, and they stay the brightest point on screen.
Re-map every colour to a limited palette of about 48 colours, even where the reference is cooler: shadows warm brown-black #1a1714 #2e2a26, ground ash and earth #4a423a #6b5e4f #8c7b66, light candle gold and ivory #f4c95d #c9932b #9c6a1f #efe3c6, corruption grey cracked earth with bone #d8d2c0 and dull olive #6f8f3a, violet only as thin dark lines #3b1f4d #5e2d7a. No blue or navy in any shadow. The flat corruption stops at the rim of the golden circle. Grim medieval fantasy, plain gear without emblems. No text, no letters, no watermark, no UI.
```

### northstar_pixel_v3.png (도트 v2 수정, 추천)
- job: 15e84540-28d4-43ea-8f51-a30c61ee8a6d. 레퍼런스: northstar_pixel_v2 (e0b09f78…). 측정 1% / 0.01%
- v2에서 방패를 민무늬로, 오염을 바닥에 납작한 올리브 곰팡이·뼈 결절로 바꿨다. 나머지는 같다. 보라 맥이 거의 사라져 오염의 색 정체성은 4단계(오염 타일)에서 다시 잡아야 한다
- 프롬프트:

```
Keep the reference pixel art exactly as drawn: the same composition, the same square pixel grid, the stone altar with its nine separate lamp flames, every figure with its pose and position, the stairway and the rock walls, the warm lighting. Change only two things. First, the paladin's tall kite shield becomes completely blank: flat dull steel with no mark, gem or emblem in the middle. Second, the corruption around the dark opening in the upper right lies flat on the ground: grey cracked earth with thin dark bruise-violet lines in the cracks (#3b1f4d), patches of dull olive mould (#6f8f3a) and small flat bone-coloured nodules (#d8d2c0); no branches, vines or growths climbing the walls or rising upward, and no bright magenta. Everything else stays identical. Warm brown-black shadows, candle-gold light, crisp square pixels, no anti-aliasing, no blur. No text, no letters, no watermark, no UI.
```

### northstar_v2_compare.jpg
- 비교 시트: v1 도트 / v2 회화 / v2 도트 / v3 도트

### 탈락 (파일은 보관하지 않음. job id로 힉스필드에서 다시 볼 수 있다)
| job | 종류 | 탈락 이유 |
|---|---|---|
| bc798fba | 회화 | 방패에 별 문장, 10~11명 |
| a2fc218b | 회화 | 낮처럼 밝음(차가움 24%), 오염에 보라 면 |
| dde7f511 | 회화 | 분위기·오염은 좋지만 7명 |
| a3229394 | 회화 | 방패 문장, 빛 테두리가 빛나는 고리 |
| c37e656f | 회화(따뜻한 조명) | 등잔 12개, 12명, 제단에 문 |
| 6a5952fc | 회화(따뜻한 조명) | 차점. 9명 정확·드워프 좋음, 엘프 키가 안 크고 아처 2명, 빛 원이 그린 선 |
| d5723dd1 | 바로 도트 | 치비 비례, 방패 문장, 채도 높은 보라 덩굴 |
| 47a12576 | 바로 도트 | 치비 비례, 화면 전체가 노랗게 뜸 |
| 6c936a21 | 회화 | 등잔 12개, 빛 원이 사각형 |
| 97f56754 | 회화 | 실사풍, 구도 붕괴, 등잔 12개 |
| ec442013 | 도트(6a5952fc 변환) | 그린 선 원, 가슴의 글자 같은 표식 |
| 1cdc6cdc | 도트(4502794d 변환) | northstar_pixel_v2와 거의 같음 |
| bb30eed3 | 회화 | 팔라딘이 2명 |
| 887fc81a | 회화 | 바닥이 주황으로 과포화 |
| f171bf7d | 도트(v2 수정) | 오염이 거의 지워짐 |

배운 것: 텍스트만으로 바로 도트를 뽑으면 치비 비례가 나온다. 회화 원본 → 도트 변환 두 단계가 구도를 지킨다. 종족 키 문단을 프롬프트 앞쪽에 두어야 엘프가 커진다. "plain shield"만으로는 문장이 생기므로 "completely blank, no emblem and no marks"까지 써야 한다.
사용: 이번 라운드 18크레딧 (잔액 274.5 → 256.5).

## northstar_pixel_v1.png (북극성 R6. v2 후보 검토 중)
- 도구: 힉스필드 MCP / Seedream 5.0 Lite
- job: 6e3a72c4-bafe-45c9-b21a-a42833eb35b6
- 레퍼런스: keyart_seedream_v1 (d2440f66-cd96-4dce-bc45-7c140b397eed)
- 프롬프트: docs/concept-art-brief.md §5.0
- 설정: 비율 16:9 (파일 2848×1600에서 역산), quality 기록 없음. 이 모델은 시드를 지정할 수 없다
- 파일: 2026-10-01 내려받음. 2848×1600, 5,222,767 B. 원본 URL은 concept-art-brief.md §0

## keyart_seedream_v1.png (원본 키아트)
- 도구: 힉스필드 MCP / Seedream 5.0 Lite, 텍스트만
- job: d2440f66-cd96-4dce-bc45-7c140b397eed
- 프롬프트: docs/concept-art-brief.md §5.1 (+ §3 공통 접미어)
- 설정: 비율 16:9 (파일 2848×1600에서 역산), quality 기록 없음. 이 모델은 시드를 지정할 수 없다
- 파일: 2026-10-01 내려받음. 2848×1600, 5,771,666 B. 원본 URL은 concept-art-brief.md §0

## style-board-4options.png
- 채팅에서 코드로 그린 A~D 스타일 비교 보드 (AI 생성 아님). 1608×1180, 한글 캡션 포함
- 비교용이다. 화풍이 섞여 있고 글자가 있어 생성 레퍼런스로 쓰지 않는다 (레퍼런스는 북극성)
