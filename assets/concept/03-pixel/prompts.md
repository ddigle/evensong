# 03-pixel 기록

(생성할 때마다 도구·모델·프롬프트·레퍼런스·job id·비율·품질을 추가. 시드는 모델이 지원할 때만)

## AutoSprite 시험 (2026-10-14, 실행 불가, 크레딧 사용 0)

목적: 동작 애셋을 사지 않고 늘릴 수 있는지 보려고 힉스필드 `autosprite`(캐릭터 이미지 → 스프라이트 시트 PNG)로 1건만 시험. 사람이 1건 승인.
설정: `model: "autosprite"`, `kind: "walk"`, `video_tier: "turbo"`, `frame_count: 8`, `frame_size: 64`, `medias: [{ value: "2806487c-c057-4a4a-a4b8-87522f5e8546", role: "image" }]` (팔라딘 정면).

결과 (힉스필드 MCP, 잔액 199.5 → 199.5):
- `generate_image` + `get_cost: true` → "Error estimating cost: Something went wrong" (request 98929ab5-592a-4a1c-b609-a8c3377e5721)
- `generate_image` 제출 → "Job set type not supported: autosprite" (request 6037a24b-d712-4bbc-98f5-d9813ec9886e). job이 만들어지지 않음
- `generate_video` → "image model; use generate_image instead". `apps_search "sprite"` → 결과 없음

`models_explore`에는 모델이 있지만(파라미터: kind idle/walk/run/attack/jump/custom/iso_*, video_tier turbo/pro/max, frame_count 2~64, frame_size 32~512, remove_bg, with_sound, is_humanoid) MCP로는 제출할 수 없다. 다시 시험하려면 힉스필드 웹에서 사람이 직접 하거나 MCP 지원을 기다린다.

## PixelLab 1차 시험 (2026-10-14, 팔라딘 + 바닥 타일, 13회 사용)

목적: itch.io의 Tiny Farm RPG를 눈으로만 참고해, 그 스케일(16px 타일)에 우리 톤으로 한 화면을 만들 수 있는지 본다. 3단계 결정(브리프 §5.6 ? 방향 수, ? 시점, ○ 종족 키)의 근거로 쓴다. 사람이 13회 승인. 도구는 모두 PixelLab MCP, 무료 체험(40회, 동시 작업 1건). 잔액 40 → 27 (항목 합은 12회, 1회 차이는 원인 미확인).
4방향·48 캔버스는 시험용 설정이고 확정이 아니다.

1. 레퍼런스 준비 (무료): `uv run tools/art/arttool.py ref assets/concept/02-sheets/paladin_v05_final.png --out ref.png --canvas 48 --height 30 --sole 42` → 1536px PNG를 `get_upload_url`로 올림
2. `image_to_pixelart` (각 1회, `output_width/height: 48`, `seed: 1`)
   - `paladin_px_v01.png`: `faithful: true`, `init_image_strength: 200` (job 4a886b2e-ba3a-4685-a92a-27f97063f014). 흐리고 폭이 좁아짐. 탈락
   - `paladin_px_v02.png`: `faithful: false`, `init_image_strength: 0` (job a6ebe671-870b-46cf-bdae-ecdc7169092a). 외곽선이 또렷한 도트, 그림 영역 24x34px(그림자 포함). 방패와 휘장이 주황으로 바뀜
   - `paladin_px_v02_ref.png`: v02에 `arttool.py cutout --tol 24` 후 `arttool.py regrey 27,17,35,35 20,24,25,37` (방패·휘장 주황만 같은 밝기 회색으로, 145픽셀). 이것을 3번 레퍼런스로 씀
3. `create_character` (1회): `mode: "v3"`, `reference_image_url`: v02_ref, `n_directions: 4`, `view: "low top-down"`, 48x48 (character 8b0035f9-b65a-46a4-b0be-96bd2931e60c)
   description: "huge broad-shouldered human paladin in battered dark steel plate armour, closed great helm, amber gold trim on the pauldrons, pale grey tabard hanging between the legs, large plain grey kite shield on his left arm, no weapon"
   → `paladin_low_v01_rotations.png` (남·동·북·서). 방패는 방향마다 왼팔에 맞게 남음(서쪽에서 보이고 동쪽에서 가려짐). 시트에 없는 갈색 망토가 생김
4. `animate_character` (4회): `template_animation_id: "walking-6-frames"`, 방향마다 1건씩(동시 1건 제한), group 34bd06da-e72e-412d-b510-ba7fefe94e0d
   → `paladin_low_v01_walk.png` (행: 남·동·북·서, 열: 6프레임). 방패와 휘장이 프레임마다 사라졌다 나타나고, 몸이 표준 체형으로 가늘어짐(폭 24 → 19~20px). 그대로는 못 씀. 다음 후보: `mode: "skeleton-v3"`(정체성 유지, 방향당 2~4회) 또는 손질
5. `create_character` (2회): `mode: "v3"` 레퍼런스 없음, `size: 48`, `view: "high top-down"`, `outline: "selective outline"`, `detail: "medium detail"`, description은 3번 끝에 ", dark gritty medieval" (character baccb95a-e6c5-440f-ad89-a77faac75fbe, 항상 8방향)
   → `paladin_high_v01_rotations.png` (남·남동·동·북동·북·북서·서·남서). 가장 깔끔하고 시트 디자인(회색 강철, 금 테두리, 회색 방패, 밝은 휘장)에 오히려 더 가까움. 다만 캔버스를 거의 다 채움(키 약 45px). "캔버스의 60%" 안내와 다름
   주의: 3번과 5번은 시점과 경로(시트 변환/글 생성)가 함께 달라서 시점 효과만 따로 비교할 수 없다
6. `create_topdown_tileset` (3회): `lower_description: "packed dark earth, muted warm brown dirt"`, `upper_description: "worn grey-brown flagstone floor, square stone slabs with dark mortar lines, dark gritty medieval"`, `transition_description: "dirt and small pebbles over the broken stone edges"`, `transition_size: 0.25`, `tile_size: 16`, `view: "low top-down"`, `shading: "basic shading"`, `detail: "medium detail"`, outline 기본값 (tileset 35e019e3-cb1e-4271-9474-3102277651b9)
   → `tiles_dirt-stone_v01.png` + `.json` (Wang 16장, 모서리 정보. 다운로드 URL은 뺌). 흙이 격자 무늬, 돌이 푸른 회색 작은 벽돌, 경계에 노란 점선 외곽선. 북극성(큰 판석, 따뜻한 빛)과 다름
7. 목업 (무료): `stage3_test_mockup_v01.png` (4배). 6번 타일 위에 low 4방향, high 남·동, 아래에 low 남. 오른쪽은 북극성 v6 일부를 팔라딘 키 33px에 맞춰 줄인 것. low 팔라딘(34px)이 북극성 인물과 비슷한 크기

## 2등신 체형 비교 샘플 (2026-10-14, 생성 AI 미사용, 비용 0)

사람이 PixelLab 1차 결과를 보고 "캐릭터가 못생겼다. 북극성은 분위기·질감 기준으로만 쓰고, 도트 구조는 Tiny Farm RPG와 같게"라고 함. 그 구조에서 종족을 체형으로 구분할지, 체형을 통일하고 직업 도구로만 구분할지 비교하려고 손으로 찍은 샘플.
`uv run tools/art/chibi_sample.py <출력 폴더>` → `chibi_race_sample_v01.png` (4배, 16px 돌바닥 위)

- 구조: 32x32 프레임, 2등신(머리 9px + 몸), 1px 어두운 갈색 외곽선, 재질마다 2~3단 명암. 색은 북극성 v6 기준(따뜻한 갈회색, 그림자에 청색 없음, 금·촛불), 마법사 구슬만 옅은 청백
- 모든 안에서 같음: 직업 도구와 옷(팔라딘 투구·연 방패, 성직자 두건·촛불 지팡이, 약초사 챙 모자·낫, 시프 두건·단검 둘, 마법사 은발·빛 구슬, 아처 장궁, 광부 램프 모자·곡괭이, 룬마스터 쇠모자·룬 망치, 기술자 고글·렌치)
- A안: 전원 인간 체형(키 20px), 종족 표시 없음
- A'안: 같은 체형 + 엘프 뾰족 귀, 드워프 수염
- B안: 종족별 체형(인간 20, 엘프 23, 드워프 17px. 팔라딘은 인간 키에 몸통 폭 14)
- 아래 두 줄은 A안과 B안의 실루엣(검은 그림자만)

## PixelLab 2차 시험 (2026-10-14, 2등신 + 생활은 아기자기·위협은 음울, 12회 사용)

R18 구조(Tiny Farm 2등신)에 사람이 더한 톤 컨셉을 시험: 캐릭터·생활·꾸미기는 아기자기하게, 외부 위협(적·오염)은 기존 음울한 색. 사람이 "시험 진행"을 지시했고 약 10회로 알렸으나 12회를 썼다 (잔액 27 → 15, 항목 합은 11회).
공통: PixelLab MCP `create_character`, `view: "low top-down"`, `outline: "single color black outline"`, `detail: "medium detail"`.

1. `chibi_paladin_std_v01_rotations.png` (1회): `mode: "standard"`, `n_directions: 4`, `proportions: chibi 프리셋`, `shading: "basic shading"`, `size: 24` → 36x36 캔버스 (character 3982c44e-85f0-4c7e-8720-a7c74771f537)
   description: "cute chibi human paladin, closed steel great helm with a narrow visor, worn steel plate armour with warm gold trim, ash-grey tabard with a single gold stripe, tall plain kite shield with no emblem on his left arm, cozy warm colours"
   → 투구가 열려 얼굴이 보이고, 방패에 문장이 생기고, 북쪽이 뒷모습이 아니라 앞모습. 키 26px. 탈락
2. `chibi_paladin_v01_rotations.png` (2회): `mode: "v3"`(레퍼런스 없음, 8방향 생성 중 남·동·북·서만 보관), `size: 32` (character 7adfefc5-c5c7-4b5b-a80c-f757d8df40b5)
   description: "cute chibi human paladin, about two heads tall with a big head and small body, closed round steel helm with a narrow dark visor slit, steel plate armour with warm gold trim, ash-grey tabard with one gold stripe, tall plain kite shield on his left arm, completely blank steel with no emblem or marks, cozy warm colours, friendly"
   → 2등신, 닫힌 투구, 민무늬 방패가 왼팔. 방향 정확. 다만 32 캔버스를 거의 채움(키 약 30px, 목표 20px)
3. `chibi_paladin_v01_walk_south.png` (1회): 2번에 `template_animation_id: "walking-6-frames"`, 남쪽만 (group 98d380ed-f3e1-43a4-9f76-844943d46699)
   → 체형·투구는 유지. 방패가 6프레임 중 2프레임에서 사라지고, 투구 윗부분이 프레임 위에서 잘림
4. `chibi_archer_v01_rotations.png` (2회): 2번과 같은 설정 (character 504f22b7-81d2-4912-a0ab-7b93f20dbc31)
   description: "cute chibi elf archer, about two heads tall with a big head and small body, long pointed elf ears clearly sticking out of the hair, long ash-blond hair, earth-brown hooded cloak with the hood down, longbow taller than the shoulders, quiver of arrows, leather bracers, no green clothing, cozy warm colours, friendly"
   → 엘프 귀가 두건 밖으로 또렷함. 큰 눈의 귀여운 얼굴. 두건은 올라갔고(문구와 다름) 활은 짧게 나옴
5. `chibi_heretic_v01_rotations.png` (2회): 2번과 같은 설정 (character d47d48fa-80c0-412e-9792-3c7d4490d4dd)
   description: "chibi heretic cultist enemy, about two heads tall with a big head and small hunched body, tattered dark ash-grey hooded robe, sickly grey skin with thin dark bruise-violet veins, small dim violet glowing eyes in the hood shadow, crude bone charm on a cord, rusty curved knife, grim and menacing, desaturated ash, bone and dark violet colours, no blue"
   → 잿빛 두건, 창백한 얼굴, 보라 눈·맥. 아군과 색 대비가 분명
6. `tiles_grass-corruption_v01.png` + `.json` (3~4회): `create_topdown_tileset`, `lower_description: "corrupted grey cracked earth with thin dark bruise-violet veins and dull olive mould patches, grim and lifeless"`, `upper_description: "cozy soft green meadow grass with tiny warm flowers, cute and lively"`, `transition_description: "grass edge withering into grey ash"`, `transition_size: 0.25`, `tile_size: 16`, `view: "low top-down"`, `outline: "lineless"`, `shading: "basic shading"`, `detail: "medium detail"` (tileset 289a074d-a6e9-4913-be35-d89b832b6a28)
   → 풀밭과 오염 땅의 대비는 분명. 풀이 형광 연두로 밋밋하고 꽃이 없음. 오염 땅은 보라가 면 전체에 퍼짐(북극성은 가는 맥)
7. 목업 (무료): `stage3_cozy_grim_mockup_v01.png` (3배). 왼쪽 풀밭에 팔라딘·아처, 오른쪽 오염 땅에 이단 둘. 아래 줄은 팔라딘 남·동·북·서(생성)와 동쪽을 좌우 반전한 서쪽. 반전하면 방패가 몸 뒤로 숨는다

## PixelLab 3차 시험 (2026-10-14, 20px 키·걷기·풀 색, 9회 사용)

2차의 남은 문제 세 가지를 사람이 승인한 약 9회로 시험. 잔액 15 → 6.

1. 20px 팔라딘 (2회)
   - 입력 준비 (무료): 2차 `chibi_paladin_v01_rotations.png`의 남쪽(그림 28x30)을 48x48 회색(220,220,220) 캔버스에 발 y=45로 놓고 10배(nearest)로 키움 → 480px
   - `image_to_pixelart` (1회): `output_width/height: 32`, `faithful: false`, `init_image_strength: 150`, `seed: 1` (job c701bd0f-7baf-4ca8-99c3-cb4f90667926) → `arttool.py cutout --tol 24` → `chibi_paladin_20px_v01_ref.png` (그림 18x20)
   - `create_character` (1회): `mode: "v3"`, 레퍼런스 = 위 그림, `n_directions: 4`, `view: "low top-down"` (character c6b46406-4be5-43d2-8231-cd30da8b2f9a) → `chibi_paladin_20px_v01_rotations.png` (남·동·북·서)
   - 결과: Tiny Farm 크기(키 20px)에서도 투구 눈구멍·금 테두리·방패가 읽힌다. 방패 위치는 방향마다 맞다. 30px보다 덩어리지고 동쪽은 뭉개짐
2. 걷기 skeleton-v3 (3회): 1번 캐릭터에 `template_animation_id: "walking-6-frames"`, `mode: "skeleton-v3"`, 남쪽만 (group 7173b7f6-d3a2-47e5-9b06-712d3836f878) → `chibi_paladin_20px_v01_walk_south_skeleton.png` (48x48 6프레임)
   - 결과: 방패·투구가 6프레임 모두 유지. 하지만 거의 움직이지 않는다. 첫 프레임과 다른 픽셀 수가 0·13·27·0·7·7 (2차 템플릿 걷기는 380~425). 걷기로 못 쓴다
3. 풀밭↔오염 타일 v02 (3~4회): 2차와 같은 설정에 `lower_description: "dead ash-grey cracked earth, mostly flat grey with only a few thin dark violet cracks, grim and lifeless"`, `upper_description: "cozy meadow grass in soft warm sage and olive greens with straw-yellow tufts and a few tiny cream and pink flowers, muted earthy colours, cute"` (tileset fe7bfb85-8339-4e1f-9492-e7755ab300f8) → `tiles_grass-corruption_v02.png` + `.json`
   - 결과: 풀은 차분한 올리브에 작은 크림·분홍 꽃으로 좋아짐. 오염 땅은 "대부분 회색"이라고 해도 면 전체가 연보라로 나옴
4. 목업 (무료): `stage3_cozy_grim_mockup_v02.png` (3배). 위: 20px 팔라딘 남·동·서·북, 아래: 2차 30px 팔라딘·아처(크기 비교), 오른쪽: 이단(30px). 아래 줄은 20px 팔라딘 남·동·북·서(생성)와 동쪽 반전

## PixelLab 4차 (2026-10-14, 30px 걷기 손질·오염 땅 색, 1.1회 사용)

사람이 키를 약 30px로 정하고(R20) 걷기와 오염 땅 색을 진행하라고 함. 잔액 6 → 4.

1. 남쪽 걷기 방패 복원 (무료): 2차 `chibi_paladin_v01_walk_south.png`(템플릿 걷기)에서 방패가 빠진 2·3번째 프레임(인덱스 1·2)에 1번째 프레임(인덱스 0)의 방패 픽셀을 복사. 영역은 32x32 프레임 좌표로 y=12는 x≥26, y=13~21은 x≥20, y=22~23은 x≥21, y=24~26은 x≥22 (프레임마다 123픽셀) → `chibi_paladin_v01_walk_south_fixed.png`
2. 동쪽 걷기 (1회): 2차 팔라딘(character 7adfefc5-c5c7-4b5b-a80c-f757d8df40b5)에 `template_animation_id: "walking-6-frames"`, 동쪽만, 같은 group 98d380ed-f3e1-43a4-9f76-844943d46699 → `chibi_paladin_v01_walk_east_west.png` (위 줄 동쪽 6프레임, 아래 줄은 좌우 반전한 서쪽). 다리가 교차하며 움직이고(프레임당 230~290픽셀 변화) 방패가 모든 프레임에 있다. 반전한 서쪽도 자연스럽다
3. 오염 땅 색 (0.1회): `reduce_colors`, 입력 `tiles_grass-corruption_v02.png`, `palette_image` = `palette_grass_threat_v01.png` (v02 풀 타일의 색 13개, 보라 기운 색은 뺌 + 북극성 위협 색 #1a1714 #2e2a26 #4a423a #6b5e4f #8c7b66 #3b1f4d #5e2d7a #6f8f3a #d8d2c0), `dithering: "none"` (job ddc99b3b-4c41-4706-9916-7f37dfe602f4) → `tiles_grass-corruption_v03.png` (타일 배치는 v02의 .json과 같다)
   - 결과: 오염 땅이 연보라에서 잿빛 갈색으로, 금은 어두운 보라 맥으로. 풀은 그대로. 두 잿빛 사이에 얼룩이 조금 생김
4. 목업 (무료): `stage3_cozy_grim_mockup_v03.png` (3배). v03 타일 위 30px 팔라딘·아처·이단, 오른쪽에 걷기 남(복원)·동·서(반전)
