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

## PixelLab 5차 시험 (2026-10-14, 기본 몸 + 클래스 표식 레이어, 90회 사용)

R21·R22(외형은 꾸미기, 클래스는 표식 장비)를 시험. 슬라이스 4클래스의 표식(팔라딘 방패, 광부 곡괭이, 아처 큰 활, 성직자 후광)을 같은 기본 몸에 레이어로 겹친다. Tier 1(월 2,000회)로 올린 뒤 사람이 100회 상한을 승인. 잔액 2,000 → 1,910.
공통: PixelLab MCP, `view: "low top-down"`. 레이어 도구는 `tools/art/layers.py` (diff, segment, bow, halo).

1. 기본 몸 (4회): `create_character`, `mode: "v3"`(레퍼런스 없음), `size: 32`, `outline: "single color black outline"`, `detail: "medium detail"`, 같은 설정으로 2개
   description: "cute chibi young adventurer, about two heads tall with a big head and small body, short tousled brown hair, bare head, plain warm beige linen tunic with a simple brown belt, brown trousers, small brown boots, empty hands, no weapon, no hat, no cape, no backpack, cozy warm colours, friendly"
   - A (character 7b5aed6a-683a-474e-91b2-fa7caffe75a6) → `base_body_v01_rotations.png` (남·동·북·서). 채택. 키 31px, 띠는 어깨에 거는 끈으로 나옴
   - B (character 27043ce2-27fc-4aae-9533-6d2dc2cf137f) → `base_body_v01b_rotations.png`. 맨손이라고 했는데 등에 나무 몽둥이 같은 것이 붙음. 탈락
2. 동작 (6회): A에 템플릿 `walking-6-frames` 남·동·북 (group ee598de4-733c-4238-9004-9e1aabb36301) → `base_body_v01_walk.png` (줄: 남·동·북, 6프레임), `breathing-idle` 남·동·북 (group 42d1d45e-0ab9-4172-a6f6-3fb2d9013eb2) → `base_body_v01_idle.png` (4프레임)
   - 걷기는 키 28px(y 0~27)로 회전 그림(31px)보다 작다. idle은 발 y가 방향마다 26~29로 다르다. 동쪽 idle 눈에 초록 픽셀, 북쪽 idle 옆머리에 붉은 얼룩
   - 모든 프레임에서 머리 꼭대기가 y=0이다. 32 프레임 그대로면 모자 자리가 없다. 발을 y=31에 맞춰 다시 놓으면 걷기는 머리 위로 3~4px가 생긴다
3. 팔라딘 방패, `edit_image` (10회): 입력 16프레임(회전 남·동·북 + 걷기 남 6 + 걷기 동 6 + 걷기 북 1번), `seed: 5` (job 70a15f19-32c7-4ac8-9210-ba7e2994b599) → `sig_paladin_shield_v01_edit_raw.png` (입력 순서)
   description: "add a large plain steel kite shield with a thin warm gold rim, completely blank with no emblem and no marks, strapped to the character's left forearm. Keep the character's body, face, hair, clothes, colours and pose exactly the same; only add the shield."
   - 방패 모양은 좋다. 하지만 남·북은 몸 전체를 다시 그려 몸 픽셀의 22~38%만 원래와 같다(1~2px 이동 포함). 차이로 레이어를 뗄 수 없다
   - 동쪽은 몸이 거의 그대로다(RGB 차 합 60을 넘는 몸 픽셀 1개) → `layers.py diff --tol 60 --ymin 10`으로 깨끗하게 떼어짐
   - 남쪽 방패는 몸에 없는 색(쇠 회색)이라 `layers.py segment`로 떼어짐. 나무처럼 몸과 비슷한 색은 이 방법이 안 된다
4. `inpaint_image` (70회, 7장 × 10회): 템플릿 걷기 첫 프레임에 사각 마스크로 표식을 붙임. 모두 `seed: 5`. 마스크 밖은 그대로라 `layers.py diff --tol 40`으로 깨끗한 레이어가 나온다 (몸 픽셀은 하나도 바뀌지 않음)
   - 곡괭이 → `sig_miner_pickaxe_v01.png` (남·동·북)
     - 남 (job e855b8bf-db40-4adc-ac0d-13e7cb63cef2, 마스크 x19 y3 13×20): "the iron head of a pickaxe sticking up behind the character's left shoulder, its wooden handle going diagonally down behind the back, carried on the back with a strap"
     - 동 (job 5572f7f7-4bdc-4dd0-9181-d042a771780a, x1 y3 14×22): "a pickaxe carried on the character's back, seen from the side: wooden handle strapped diagonally across the back, the iron pickaxe head sticking up above the shoulder behind the head"
     - 북 (job d5ddeb16-ff57-4da7-8ffe-efe66353cfc6, x6 y4 22×22): "a pickaxe strapped diagonally across the character's back, seen from behind: wooden handle from the lower left hip up to the right shoulder, iron pickaxe head across the top above the right shoulder, leather strap"
   - 큰 활 → `sig_archer_bow_v01.png` (남·동·북)
     - 남 (job e19afc35-c9a5-4079-aea9-1aebe29ca6f0, x0 y1 12×26): "a large wooden longbow slung on the character's back, seen from the front: the tall curved wooden bow limb rises behind the shoulder above the head height and runs down beside the body to the hip, thin bowstring"
     - 동 (job e90032b8-4f1f-48c0-99e6-b15850f53df2, x0 y0 13×28): "a large wooden longbow carried on the character's back, seen from the side: a tall curved wooden bow standing upright behind the back, from above the head down to the knees, with a thin bowstring"
     - 북 (job c3066965-1ab5-4b31-9c72-903cd1334f00, x5 y2 24×25): "a large wooden longbow slung diagonally across the character's back, seen from behind: a long curved wooden bow from above the right shoulder down to the left hip, held by a leather strap"
   - 방패 북 (job 28a9e936-1f8d-44f6-8c45-080d626ac9d6, x2 y11 12×17): "a large plain steel kite shield with a thin warm gold rim strapped to the character's left arm, seen from behind: the back of the shield, no emblem"
   - `sig_paladin_shield_v01.png`: 1줄 남 걷기 6프레임(3번 segment), 2줄 동 걷기 6프레임(3번 diff), 3줄 북 1장(이 inpaint)
5. 손으로 그림 (무료): 활 `layers.py bow` → `sig_archer_bow_hand_v01.png` (inpaint와 비교용. 읽히지만 거칠다). 후광 `layers.py halo` → `sig_cleric_halo_v01.png` (12×5, 모든 방향에 한 장. 32 프레임 밖 머리 위에 띄우고 6프레임 중 3프레임 1px 올림)
6. 목업 (무료): 단단한 레이어(한 방향 한 장)는 프레임마다 몸통 줄(y 13~22)을 첫 프레임에 맞춰 찾은 위치에 붙였다(거의 0, 동쪽 4번째 프레임만 위로 1px). 남·동에서는 등 장비를 몸 뒤에, 북에서는 몸 앞에 그렸다. 서쪽은 동쪽 합성을 좌우 반전. 바닥은 `tiles_grass-corruption_v03.png`의 풀 타일
   - `stage3_signature_layers_v01.png`: 줄은 기본 몸·팔라딘·광부·아처·성직자, 칸은 남·동·서(반전)·북. 4배
   - `stage3_signature_lineup_v01.png`: 남쪽을 보는 넷을 1배·3배로
   - `stage3_signature_walk_v01.gif`: 넷의 걷기 6프레임, 남·동·서·북, 3배, 프레임당 120ms
   - 결과: 같은 외형이어도 넷이 구분된다. 1배에서도 방패(회색)와 후광(금색)은 확실하고, 곡괭이·활은 약하다. 동쪽 방패는 몸 앞뒤로 테두리만 보여 고리처럼 읽힌다. 단단한 레이어는 걸을 때 흔들리지 않는다(몸이 거의 위아래로 움직이지 않아 어색하지는 않음)

## PixelLab 6차 시험 (2026-10-15, 약초사 씨앗주머니 레이어, 30회 사용)

R23에서 약초사가 슬라이스 다섯 번째 클래스가 되어, 5차에서 빠진 허리 표식(씨앗주머니, R21)을 같은 방법으로 시험. 사람이 30회를 승인. 잔액 1,910 → 1,880.
공통: 5차 기본 몸(character 7b5aed6a-683a-474e-91b2-fa7caffe75a6)의 템플릿 걷기 첫 프레임에 `inpaint_image`, `seed: 5`, 사각 마스크 11×12. 색은 생활 쪽 녹색(brief §4 ○ R23)으로 했다.

1. `inpaint_image` (30회, 3장 × 10회) → `sig_herbalist_pouch_v01_raw.png` (남·동·북, inpaint 결과 그대로)
   - 남 (job 5234e97f-77b7-4406-a8a5-805b2dbb483f, 마스크 x2 y16): "a big round fresh leaf-green cloth seed pouch with a drawstring top tied with a cord and a tiny bright green sprout with two leaves poking out of its top, hanging from the belt at the character's right hip (left side of the image), bulging out beyond the side of the body, thin dark outline"
   - 동 (job 200898fa-6b88-4055-af1f-9e009f851974, 마스크 x6 y16): "a big round fresh leaf-green cloth seed pouch with a drawstring top tied with a cord and a tiny bright green sprout with two leaves poking out of its top, hanging from the belt on the character's hip, seen from the side, bulging out behind the hip, thin dark outline"
   - 북 (job 6285332a-fabf-42b6-9ecb-5fc19183852a, 마스크 x19 y16): "a big round fresh leaf-green cloth seed pouch with a drawstring top tied with a cord and a tiny bright green sprout with two leaves poking out of its top, hanging from the belt at the character's right hip (right side of the image), seen from behind, bulging out beyond the side of the body, thin dark outline"
   - 셋 다 마스크 밖 몸 픽셀은 그대로라 `layers.py diff --tol 40`으로 떼어짐 (남 25px, 동 33px, 북 48px)
   - 동·북은 둥근 주머니에 새싹까지 나왔다. 동쪽은 엉덩이 뒤로 2~4px 튀어나온다
   - 남은 폭 4px로 가늘고 손 자리를 덮었을 뿐 몸 밖으로 나오지 않았다. 탈락
2. `sig_herbalist_pouch_v01.png` (레이어, 남·동·북): 남 = 북 레이어 좌우 반전(앞에서 본 오른쪽 엉덩이), 동·북 = inpaint 차이. 셋 다 몸 앞에 그린다
3. 목업 (무료): 5차 목업과 같은 방법에 약초사 줄을 더함
   - `stage3_signature_layers_v02.png`: 줄은 기본 몸·팔라딘·광부·아처·성직자·약초사, 칸은 남·동·서(반전)·북. 4배
   - `stage3_signature_lineup_v02.png`: 다섯 클래스를 1배·3배로. 위 줄은 남, 아래 줄은 동
   - `stage3_signature_walk_v02.gif`: 다섯의 걷기 6프레임, 남·동·서·북, 3배, 프레임당 120ms
4. 결과
   - 3배에서는 엉덩이에 찬 초록 주머니로 읽히고, 걸어도 다섯이 구분된다. 화면 배율은 아직 정하지 않았다. 북극성 도트 재현(brief §5.0)처럼 480×270 화면을 1080p에 띄우면 4배라, 그 경우 3배가 실제 크기에 가깝다
   - 1배에서는 다섯 중 가장 약하다. 기본 몸과 거의 구분되지 않는다(곡괭이·활보다 약함). 주머니가 6~7px이고, 다리와 겹치는 낮은 자리이며, 풀밭 위에서 초록끼리 묻힌다
   - 색만 바꿔 봄 (무료, 파일 없음): 주머니를 녹슨 주황빛 빨강으로 바꾸고 새싹만 초록으로 두었다. 남쪽이 조금 나아졌지만 갈색 바지·신발과 섞여 1배에서는 여전히 약하다. 색보다 크기와 자리가 문제다

## PixelLab 7차 시험 (2026-10-15, 큰 씨앗주머니, 30회 사용)

6차 주머니가 1배에서 약해, 사람이 "크게 다시 그리기"(30회)를 승인. 잔액 1,880 → 1,850.
공통: 6차와 같은 몸·프레임·`seed: 5`. 마스크를 12~13×14로 키우고 위로 올렸다(y 14~27). 풀밭과 겹치지 않게 중간 톤 초록 대신 진한 초록에 밝은 하이라이트를 넣었다.

1. `inpaint_image` (30회, 3장 × 10회) → `sig_herbalist_pouch_v02_raw.png` (남·동·북)
   - 남 (job f5407536-51ca-4fcd-a0d1-d87cae7a4522, 마스크 x0 y14 12×14): "a large round deep-green cloth seed pouch, about as big as the character's torso, hanging from the belt at the character's right hip (left side of the image) and bulging far out to the side of the body, its top gathered with a drawstring cord, a small bright green two-leaf sprout poking out of the top, light green highlight on the round belly of the pouch, thin dark outline"
   - 동 (job c7dd640f-72fd-46d1-9c06-8d6d70bad782, 마스크 x3 y14 13×14): "a large round deep-green cloth seed pouch, about as big as the character's torso, hanging from the belt at the character's hip, seen from the side, bulging far out behind the hip and lower back, its top gathered with a drawstring cord, a small bright green two-leaf sprout poking out of the top, light green highlight on the round belly of the pouch, thin dark outline"
   - 북 (job 22fe70d7-e9c5-4395-8995-ce7c81e1d5e6, 마스크 x20 y14 12×14): "a large round deep-green cloth seed pouch, about as big as the character's torso, hanging from the belt at the character's right hip (right side of the image), seen from behind, bulging far out to the side of the body, its top gathered with a drawstring cord, a small bright green two-leaf sprout poking out of the top, light green highlight on the round belly of the pouch, thin dark outline"
   - `layers.py diff --tol 40`으로 떼어짐 (남 46px, 동 94px, 북 89px. 6차의 2~3배). 셋 다 허리띠에서 발 높이(y 27)까지 내려온다. 큰 주머니라 무게로 처진 모양이다
   - 동은 폭 10px의 둥근 공 모양으로 엉덩이 뒤에 크게 나온다. 북은 몸 옆으로 길고 매듭이 보인다. 남은 동보다 작지만(폭 6px) 둥글고 새싹이 있다
2. `sig_herbalist_pouch_v02.png` (레이어, 남·동·북 모두 inpaint 차이, 몸 앞에 그린다)
   - 남을 북 레이어 반전으로 바꾼 것도 비교했다(무료). 더 크지만 어둡고, 뒤에서 본 매듭이 앞모습에 보여 원래 남쪽을 골랐다
3. 목업 (무료, 6차와 같은 방법): `stage3_signature_layers_v03.png`, `stage3_signature_lineup_v03.png` (위 남, 아래 동), `stage3_signature_walk_v03.gif`
4. 결과
   - 1배: 동쪽은 확실히 보인다(풀밭 위 진한 초록 공). 남·북은 6차보다 낫고 곡괭이·활 정도로 약하게 보인다. 방패·후광만큼은 아니다
   - 3배: 세 방향 모두 씨앗주머니로 읽히고, 걸어도 흔들림 없이 붙어 있다
   - 허리 표식은 "몸통 절반 크기, 발 높이까지 처져도 됨"이어야 1배에서 보인다. 시프 쌍검·기술자 망치(2단계)도 이 크기를 기준으로 본다

## 발 맞춤 (2026-10-17, brief §5.6 ○ 발 맞춤, 무료)

5차 기본 몸 애니메이션의 발을 프레임 바닥(y=31)에 맞췄다. 도구는 `tools/art/layers.py pivot` (방향마다 모든 프레임을 같은 만큼 내려 가장 낮은 픽셀이 y=31에 오게 함, 방향 안의 움직임은 그대로). 생성 없음.

| 시트 | 남 | 동 | 북 | 머리 위 빈 줄 (남·동·북) |
|---|---:|---:|---:|---|
| `base_body_v02_walk.png` (← v01 걷기) | +4 | +3 | +4 | 4 · 3 · 4 |
| `base_body_v02_idle.png` (← v01 idle) | +5 | +2 | +3 | 5 · 3 · 3 |
| `base_body_v02_rotations.png` (← v01 회전, 4방향 한 줄) | +1 | +1 | +1 | 1~2 (회전은 키 30~31px라 게임에는 걷기·idle을 쓴다) |

- 결과는 v01을 픽셀 그대로 옮긴 것이다(걷기로 확인). idle·피격·사망·던지기는 뒤의 "손질"에서 몇 픽셀 고쳐 v01과 다르다
- `base_body_v02_pivot_check.png`: 걷기·idle 첫 프레임의 v01(위)과 v02(아래). 보라 = 머리 위 빈 줄(모자 자리), 빨간 선 = 발 줄 y=31. 6배
- idle 남쪽은 걷기 남쪽보다 1px 작아서(키 27px), idle과 걷기를 오갈 때 머리가 1px 움직인다. idle 남쪽 상의에는 걷기에 없는 어깨끈이 있다(5차에 적은 동쪽 눈 초록 픽셀, 북쪽 옆머리 얼룩과 같은 템플릿 차이)
- 표식 레이어(5~7차 `sig_*`)는 v01 걷기 첫 프레임에 그렸으므로 v02에서는 걷기와 같이 남 +4, 동 +3, 북 +4 옮긴다. 남·동·북이 칸으로 놓인 시트는 `layers.py pivot <시트> --out <새 시트> --axis col --shift 4,3,4`, 줄로 놓인 시트(`sig_paladin_shield_v01.png`)는 `--shift 4,3,4`. 레이어 파일은 그대로 두고 붙일 때 옮긴다
- `stage3_signature_y31_check.png`: v02 걷기 첫 프레임에 다섯 클래스 표식을 위 이동값으로 붙여 본 것(줄은 남·동·북, 4배). 모두 제자리에 붙는다. 후광은 머리 꼭대기 기준이라 따로 옮기지 않는다

## PixelLab 8차 시험 (2026-10-17, 슬라이스 몸 동작 1차, 10회 사용)

brief §5.6 ○ 슬라이스 몸 동작 11개 중 걷기·idle 다음 셋(템플릿)과 템플릿이 없는 동작 하나(v3)의 품질을 먼저 봤다. 사람이 10회를 승인. 잔액 1,850 → 1,840.
공통: 5차 기본 몸(character 7b5aed6a-683a-474e-91b2-fa7caffe75a6), `animate_character`. 동시 작업 칸이 8개라 9방향을 한 번에 못 넣어 던지기는 나눠 넣었다(같은 group으로 이어 붙임).

1. 템플릿 (방향당 1회, 9회). 원본은 `base_body_v01_<동작>.png`(줄 남·동·북), 발을 y=31로 옮긴 것은 `base_body_v02_<동작>.png` (`layers.py pivot`)
   - 피격 `taking-punch` 6프레임 (group 36553185-838f-4a60-b580-e8e94e6e2017) → `base_body_v0{1,2}_hurt.png`. 이동 남 +4, 동 +5, 북 +4
   - 사망 `falling-back-death` 7프레임 (group 8adaeff8-56fd-4715-a20d-bf7b460c84cd) → `base_body_v0{1,2}_death.png`. 이동 +3, +4, +5
   - 던지기 `throw-object` 7프레임 (group ae9e5f61-5fe5-4ef4-9663-b93dab5f877f) → `base_body_v0{1,2}_throw.png`. 이동 +4, +4, +3
   - 셋 다 동작이 읽힌다. 피격은 옆에서 뒤로 젖혀지고 앞에서는 주먹을 든 자세(펀치 맞기 템플릿이라 권투 자세가 섞임), 사망은 세 방향 모두 뒤로 넘어져 눕고, 던지기는 뒤로 젖혔다 던진다
   - 흠: 피격 남쪽 눈이 보라색으로 바뀜, 사망 남쪽 5번째 프레임에 노란 점, 던지기 동쪽 마지막 프레임은 다른 자세(정면에 가깝고 어두움). 손질 필요
   - 키는 걷기·idle과 비슷하다(27~29px)
2. 검 v3 (1회): `mode: "v3"`, 남쪽, `frame_count: 8` (group 7d037964-4237-4f1b-84f1-2e0750811c61) → `base_body_v01_sword_v3_south.png` (48×48 칸 9장, 첫 장은 기준 그림)
   - action_description: "slashing a short sword held in the right hand in one wide horizontal arc, then returning to a ready stance"
   - 칼(흰 날, 금빛 자루)을 그려 넣고 몸 앞을 가로질러 휘두른다. 몸은 거의 서 있고 팔만 움직여 베기가 약하게 읽힌다. 7번째 프레임에 떨어진 점 하나
   - 캔버스가 48×48로 커졌다(칼이 32 프레임 밖으로 나감). 몸은 키 31px로 템플릿 동작(27~29px)보다 3px 크다. v3는 회전 그림(31px)에서 시작하기 때문이다
3. `base_body_v02_anims.gif`: idle·걷기·피격·사망·던지기(남·동·북) + 검 v3(남)을 발 줄에 맞춰 나란히, 3배, 프레임당 130ms (42프레임 반복이라 idle·검은 반복 지점에서 끊긴다)
4. 다음에 볼 것
   - v3 동작은 `custom_start_frame_base64`에 걷기·idle 첫 프레임을 넣어 시작하면 템플릿 동작과 키가 맞을 것이다 (같은 값, 방향당 1회)
   - 무기가 32 프레임 밖으로 나간다. brief §5.6 "도구와 표식 장비는 레이어로 얹는다"대로라면 몸 동작은 32 안에 두고 무기는 따로 그린 스프라이트로 얹어야 한다. v3로 무기를 든 채 뽑은 뒤 무기 색(쇠·금)만 `layers.py segment`로 떼어내는 방법을 시험할 수 있다

## PixelLab 9차 시험 (2026-10-17, v3 시작 그림 바꾸기, 2회 사용)

8차 v3 검이 회전 그림(31px)에서 시작해 템플릿 동작(27~29px)보다 컸다. 시작 그림만 걷기 첫 프레임(v01, 32×32)으로 바꾸고, 설명·프레임 수는 8차와 같게 했다. 사람이 2회를 승인. 잔액 1,840 → 1,838.
공통: `animate_character`, `mode: "v3"`, `frame_count: 8`, `custom_start_frame_base64` = `base_body_v01_walk.png`의 해당 방향 첫 프레임, action_description은 8차와 같음("slashing a short sword held in the right hand in one wide horizontal arc, then returning to a ready stance")

1. 남 (group 1b775ea5-5ab0-4265-9614-47e0dad33a66) → `base_body_v01_sword_v3_start_south.png` (40×48 칸 9장)
   - 키 26~28px로 템플릿 동작과 맞는다
   - 칼을 들어 올렸다가 몸 앞으로 내려 벤다. 8차보다 베기가 잘 읽힌다
   - 흠: 눈 둘레에 붉은 얼룩, 4번째 프레임에서 칼날이 얼굴을 가림
2. 동 (group e08866b5-88dc-4a54-b239-a1e154ba4478) → `base_body_v01_sword_v3_start_east.png` (48×68 칸 9장)
   - 키 28~29px로 맞는다
   - 앞 세 프레임은 거의 안 움직이고, 칼을 낮게 앞으로 내미는 정도라 베기가 약하다
   - 흠: 상의가 베이지에서 주황으로 바뀜(3~7번째), 입가에 붉은 점, 7번째 프레임에 멀리 떨어진 점 둘
3. `base_body_sword_v3_compare.png`: 8차(회전 그림 시작)와 9차 남·동을 발 줄(빨강)에 맞춰 나란히. 보라 선은 키 28px. 8차만 선 위로 나온다. 4배
4. 무기 떼어내기 (무료): `layers.py segment`로 칼만 색으로 떼어 보았다. 8차는 `--thr 20`이면 칼날 대부분이 떨어지지만 몸에 칼 외곽선이 몇 px씩 남았다. 9차는 v3가 몸 색도 새로 칠해(붉은 얼룩, 흰 하이라이트) 몸 픽셀이 같이 딸려 오고, 흰 칼날이 상의 하이라이트와 비슷해 칼이 덜 떨어졌다. AI 공격 동작에서 무기 레이어를 색으로 떼는 방법은 쓸 수 없다
5. 정리
   - v3는 시작 그림을 걷기 첫 프레임으로 주면 키가 맞는다. 값은 같다(방향당 1회, 방향마다 따로 호출)
   - v3 결과는 방향마다 품질 차이가 크고 색이 바뀐다. 다시 뽑기를 셈에 넣어야 한다

## PixelLab 10차 (2026-10-17, 슬라이스 도구·공격 동작, 30회 사용)

사람이 "무기를 동작에 그려 넣기"(슬라이스 한정, 9차 뒤 선택)와 30회를 승인. 잔액 1,838 → 1,808. 첫 판 20회 + 다시 뽑기 10회.
공통: `animate_character`, `mode: "v3"`, 방향마다 따로 호출, `custom_start_frame_base64` = `base_body_v01_walk.png`의 해당 방향 첫 프레임(9차와 같음). 설명이 같은 요청은 새로 뽑지 않고 기존 결과를 돌려준다(값도 안 받음). 다시 뽑으려면 설명을 바꿔야 한다.

결과 시트: `base_body_v02_<동작>.png`. 줄은 남·동·북, 64×64 칸. 칸 좌표는 v02 32 프레임(발 y=31)을 (16, 16)에 둔 것과 같다(발 줄 y=47). 첫 칸은 시작 그림(걷기 첫 프레임)이다. v3 캔버스는 방향마다 32~40 × 48~56으로 달라서, 첫 프레임에서 시작 그림 위치를 찾아(모두 픽셀 단위로 일치) 맞췄다. 곡괭이가 바닥을 칠 때 발 아래로 나가 48칸에서는 잘려 64칸으로 했다.

| 동작 | 프레임 | 채택 (group) | description |
|---|---|---|---|
| 곡괭이 | 6 | 남 ab6990c3-5f18-4d1c-958c-9dc789bc00b4, 동 f5e21854-6dc1-4291-9600-9b941435ec80, 북 3865ca15-2b58-483c-90d7-4718e57a3a46 | "swinging an iron pickaxe with a T-shaped pointed head on a wooden handle: lifting it high over the head with both hands, then striking down hard at the ground in front, then lifting it back up" |
| 괭이 | 6 | 남 ffdb29d7-c06a-4c58-8803-6d0bd67e4ffd, 동 88d92134-e4bc-4aad-9ca0-0bd5f6fdb791 (b), 북 42f1f898-19de-4a98-a12e-8148a9946e51 (a) | a "raising a garden hoe with both hands and chopping it down into the soil in front to till the ground, then pulling it back", b "lifting a long-handled wooden garden hoe high with both hands and chopping its flat iron blade down into the soil in front, then pulling it back toward the body" |
| 낫 | 6 | 남 c0abc66f-996d-4676-aa4a-70c82e5f81a8, 동 863c88e5-c34e-4dbc-8b68-44781b53e844, 북 0f9093f6-738d-4818-8509-0c90846756e8 | "holding a small curved sickle in the right hand and sweeping it low in front in a quick cut, as if harvesting crops, then returning" |
| 물주기 | 8 | 남 a3ded5ec-f018-493f-bf56-006de3f50f7d, 동 32e0e448-6e3f-4ee1-8f49-c1718155dd82 (b), 북 ff022d30-0cfc-4eef-9ff9-42905c44d230 (a) | a "holding a small watering can in front with both hands and tilting it forward to pour water onto the ground, then tilting it back", b "holding a round metal watering can with a long spout out in front at chest height and tipping it so water sprinkles from the spout onto the ground in front, then tipping it back" |
| 활 | 8 | 남 4f0c1abf-0c65-4a13-b380-7859b28a188a (b), 동 a8ba5d50-ea15-48c2-a225-9169da46b7e6, 북 223da274-6404-4c9b-8a45-c7140503ed69 (a) | a "raising a wooden longbow in the left hand, drawing the string back with the right hand, aiming forward and releasing an arrow", b(남) "facing the viewer, holding a tall wooden longbow upright in front of the body with the left hand, pulling the string back toward the chest with the right hand, then releasing an arrow toward the viewer" |
| 마법 | 6 | 남 53f49573-c0a8-4ff9-b3a1-0189a0364d17, 동 703d2e11-26e2-42f5-b97f-e15c566ade72, 북 6aec12da-3495-4478-b0fb-c1bf4bf8eb2e | "raising both open hands forward and casting a softly glowing golden healing light, then lowering the hands" |
| 검 | 8 | 남 1b775ea5-5ab0-4265-9614-47e0dad33a66 (9차), 동 ca06c79e-8981-4ec7-961e-904d12c7e7f0, 북 f4424b0c-5d04-4d07-aad8-a935718638df | 남·북 9차 설명, 동 "raising a short sword held in the right hand high and swinging it in a big fast slash down and forward, then returning to a ready stance" |

- 버린 판(그룹은 계정에 남아 있음): 곡괭이 a 남 9e09ef1e-10a3-438b-947a-c41ad54cf261·동 998a7913-9a19-431e-8c07-f9e88817bb3d·북 f3529e26-754e-4e04-85f3-a1c7157f0611 (곡괭이 머리가 초승달처럼 휘어 낫으로 보임), 괭이 a 남 46ac059c-82a2-46d4-8d38-0ad713315a7d·동 422f5ace-f8f2-47a1-930d-323562fffd5a (도구가 작고 동작이 약함), 괭이 b 북 09c4b2fd-2340-4158-aba7-10f3ee9deada·c 북 6c5a9c73-cec6-44b2-8c9e-27a5859e7271 (c: "seen from behind, lifting a long-handled garden hoe up over the head so its iron blade shows above the head, then chopping it down hard into the soil in front, then pulling it back". 둘 다 도구가 안 보이거나 다리 사이 막대로 보임), 물주기 a 남 2c3c6b69-1cc0-4f9f-929f-b628d101acc1·동 b31c0d4b-6528-463a-b911-e4aa679bd3da (물뿌리개 없이 허리에서 물줄기가 나옴), 활 a 남 21f0d1d4-ef28-4773-9fbe-3c94403d7f09 (활이 거의 안 보임), 검 동 e08866b5 (9차)
- 판정
  - 잘 읽힘: 곡괭이(남쪽은 T자 머리가 머리 위로 올라갔다 바닥을 침), 낫, 활 동·북, 마법(손에 금빛이 모임), 검
  - 약함: 괭이(남·동은 읽히지만 북은 흙만 튐), 물주기 동(물뿌리개가 몸 뒤에 있고 물은 앞에 떨어짐), 활 남(활을 든 모습은 보이나 당기는 동작이 작음)
  - 공통 흠: 마법 동쪽은 몸 전체가 주황빛으로 바뀜(빛 효과가 몸에 칠해짐), 프레임마다 눈 둘레 붉은 얼룩, 북·동 몇 장에서 몸이 정면 쪽으로 돈다. 키는 26~29px(곡괭이·괭이 휘두를 때 도구 포함 33px까지)
- `base_body_v02_actions.gif`: 일곱 동작 남·동·북을 발 줄에 맞춰 나란히, 2배, 프레임당 130ms (63프레임 반복)

## 손질 (2026-10-17, 생성 없음, 무료)

슬라이스 몸 동작 시트의 작은 흠을 손으로 고쳤다. 같은 파일(`base_body_v02_<동작>.png`)을 고쳐 썼고, 고치기 전 판은 git 기록(커밋 c9fd913)에 있다. 방법은 Python 픽셀 편집(색 바꾸기, 이웃 색 채우기, 프레임 복사)이다. 좌표는 각 칸 안의 좌표다.

| 시트 | 방향·프레임 | 흠 | 고침 |
|---|---|---|---|
| 피격 | 남 0~5 | 왼눈이 보라 | 기본 몸 남쪽 눈 색(짙은 갈적, 자줏빛 갈색). 0번 허리띠의 보라 점 1개는 이웃 색 |
| idle | 동 0~3 | 눈이 초록, 2번에 진홍 점 | 걷기 동쪽 눈 색(흰 하이라이트, 짙은 갈색, 붉은 눈꺼풀) |
| idle | 북 0~3 | 10~11줄 옆머리 돌기에 외곽선이 없어 번져 보임 | 걷기 북쪽처럼 돌기 끝 픽셀을 외곽선 색으로 |
| 사망 | 남 4 | 목에 노란 점 2개 | 이웃 색 |
| 던지기 | 동 6 | 다른 각도에 몸이 어두움 | 0번(같은 선 자세) 복사 |
| 곡괭이 | 동 4 | 발 아래 떨어진 점 1개 (35, 47) | 지움 |
| 곡괭이 | 북 6 | 뒷머리에 회색 얼룩(곡괭이 날 자국) | 0번(시작 그림)의 머리 픽셀 |
| 낫 | 동 5 | 떨어진 점 1개 (40, 46) | 지움 |
| 괭이 | 남 3~6 | 흙이 핏빛(짙은 빨강) | 괭이 북쪽의 흙 갈색 3단 |
| 검 | 남 4~8 | 왼눈이 하늘색, 오른눈이 분홍 덩어리 | 짙은 눈 + 기본 몸의 눈꺼풀 자줏빛 |
| 마법 | 동 3·4 | 3번은 머리·몸 전체가 불빛 주황, 4번은 색이 바래고 얼굴 외곽선이 없음 | 몸은 5번으로. 3번은 손 앞의 빛 덩어리(턱 아래, x 36 이상의 밝은 픽셀)만 남김 |

- 남긴 것
  - 마법 남 1·2와 북 2~5는 몸 전체가 금빛으로 밝아진다. 고르게 금빛이라 시전 빛으로 보고 두었다. 동쪽은 손 앞 빛 덩어리라 방향마다 표현이 다르다
  - 눈가 붉은 기: 기본 몸도 눈 위 자줏빛 픽셀과 붉은 볼이 있으므로, 기본 몸에 없는 색(하늘색, 분홍 덩어리, 보라, 초록)만 고쳤다
  - idle 남쪽 어깨끈(걷기에는 없음), 몸이 정면 쪽으로 도는 프레임(검 동 3~8 등), 약한 셋(괭이 북, 물주기 동, 활 남)은 손질로 안 되고 다시 뽑아야 한다
- `base_body_v02_cleanup_check.png`: 고친 곳 열두 군데의 전(위)·후(아래), 6배. 미리보기 `base_body_v02_anims.gif`와 `base_body_v02_actions.gif`는 고친 시트로 다시 만들었다

## PixelLab 11차 (2026-10-17, 약한 셋 다시 뽑기, 6회 사용)

10차에서 약했던 괭이 북, 물주기 동, 활 남을 다시 뽑았다. 사람이 3~6회를 승인. 잔액 1,808 → 1,802.
공통: 10차와 같음(`animate_character`, `mode: "v3"`, 방향마다 따로, `custom_start_frame_base64` = `base_body_v01_walk.png`의 해당 방향 첫 프레임). 첫 판 3회를 보고 남은 3회로 한 번씩 더 뽑았다.

| 동작 | 판 | group | description | 판정 |
|---|---|---|---|---|
| 괭이 북 | d | 09927905-36a9-4882-bbce-36f2dfebb020 | "seen from behind, swinging a long-handled garden hoe with a flat rectangular iron blade up over the right shoulder so the handle and blade stay visible to the right of the head, then chopping it down hard into the ground in front, then lifting it back" | 도구는 보이지만 주황 지팡이 같고 거의 안 움직임 |
| 괭이 북 | e (채택) | 320d0d4b-dd31-498c-bdf8-817442d7491f | "seen from behind, holding a wooden hoe with a grey iron blade off to the right side of the body, raising it high beside the right shoulder until the blade is above head height, then chopping it down to the ground on the right side, then raising it again" | 날을 머리 옆으로 들었다가 오른쪽 땅을 찍음. 3~5번에 위쪽 끝에도 흰 날이 남아 날이 둘로 보여서, 위쪽 날(흰색과 외곽선)만 손으로 지움 |
| 물주기 동 | c | bf404a19-8d0d-4866-963d-5d2f8b0baf13 | "facing right, holding a round metal watering can by its handle with both hands out in front of the chest on the facing side, the long spout pointing forward to the right, tilting it forward so water pours from the spout onto the ground ahead, then tilting it back" | 물은 앞으로 떨어지지만 물뿌리개가 안 보이고 손에서 물이 나옴 |
| 물주기 동 | d (채택) | 64d954e1-b708-451c-849f-70f5e1170f8f | "facing right, a grey metal watering can with a long spout held out in front of the body with both hands and clearly visible, tipping the can forward so a stream of water falls from the end of the spout onto the ground in front, then tipping it back upright; same clothes and colours throughout" | 회색 물뿌리개를 허리 앞에 들고 주둥이에서 물이 떨어짐. 1번 얼굴에 검은 덩어리가 있어 0번(시작 그림)으로 바꿈 |
| 활 남 | c | dde9b770-1acf-45ea-9a46-d24a073ea647 | "facing the viewer, raising a wooden longbow upright in front of the chest with the left hand and drawing the string far back with the right hand until the right elbow sticks out wide to the side, holding the aim for a moment, then releasing an arrow straight toward the viewer and lowering the bow" | 2번부터 상의가 붉은 갈색 조끼로 바뀜 |
| 활 남 | d (채택) | 727f9c42-cab6-47db-9b4a-bb3e5135e6cf | "facing the viewer, lifting a wooden bow upright in front of the body with the left hand, pulling the bowstring back with the right hand to the cheek so both arms spread wide apart, letting the arrow fly toward the viewer, then lowering the bow; same clothes and colours throughout" | 옷 색을 지키고 두 팔을 넓게 벌려 당김. 눈가 자줏빛은 기본 몸과 같은 정도라 둠 |

- 채택한 판은 10차와 같은 방법으로 64칸에 맞춰(`custom_start_frame` 위치 찾기, 모두 픽셀 단위로 일치) `base_body_v02_hoe.png` 북 줄, `base_body_v02_watering.png` 동 줄, `base_body_v02_bow.png` 남 줄을 바꿨다. 버린 판의 group은 계정에 남아 있다
- `base_body_v02_reroll11_compare.png`: 세 줄의 전(10차)·후(11차), 3배. `base_body_v02_actions.gif`를 다시 만들었다
- 요령: 뒷모습 도구는 "몸 오른쪽에 들고 어깨 옆으로 올린다"처럼 몸 밖에 두게 쓰면 보였다. 설명 끝에 "same clothes and colours throughout"을 붙인 두 판은 옷 색이 바뀌지 않았다(한 판씩이라 확실하지는 않다)

## 동작 중 표식 붙이기 시험 (2026-10-17, 생성 없음, 무료)

brief §5.6 ? 동작 중 다른 표식(R25)을 정하기 위해, 5~7차 표식 레이어를 동작 프레임에 그대로 붙여 보았다. 레이어는 걷기 v01 첫 프레임에 그린 것이고(`sig_paladin_shield_v01.png` 각 줄 첫 칸, `sig_miner_pickaxe_v01.png`, `sig_archer_bow_v01.png`, `sig_herbalist_pouch_v02.png`, `sig_cleric_halo_v01.png`), 동작 시트의 첫 칸(시작 그림 = 걷기 첫 프레임)과 위치가 같다.

- 위치: 프레임마다 시작 그림의 몸통 줄(v01 y 13~22)과 머리 줄(y 0~11)이 가장 많이 겹치는 이동을 찾았다(색이 맞는 픽셀 수가 가장 많은 곳, 몸통 ±4px, 머리 ±8px). 방패·곡괭이·활·씨앗주머니는 몸통 이동, 후광은 머리 이동을 따른다. 처음에 색 차이 평균으로 찾았더니 도구에 가리거나 빛에 물든 프레임에서 몸통이 8px씩 튀어서, 맞는 픽셀 수로 바꿨다
- 순서: 5차 목업과 같다(곡괭이·활은 남·동에서 몸 뒤, 북에서 몸 앞. 방패·주머니·후광은 앞). 광부의 곡괭이 동작과 아처의 활 동작에서는 등 표식을 숨긴다(손에 든 도구가 그 표식이다)
- `stage3_signature_actions_v01_{south,east,north}.gif`: 줄은 팔라딘·광부·아처·성직자·약초사, 칸은 괭이·물주기·낫·피격·사망·자기 동작(검·곡괭이·활·마법·던지기), 2배, 프레임당 130ms (56프레임 반복이라 6프레임 동작은 반복 지점에서 끊긴다)
- 결과
  - 서 있는 동작(괭이·물주기·낫·검·활·마법·던지기)은 다섯 표식 모두 따라 움직이며 제자리에 붙는다. 후광은 머리를 따라가고, 주머니는 엉덩이에 붙어 있다
  - 피격 동쪽처럼 몸이 뒤로 크게 젖혀지는 프레임에서는 등 뒤에 그린 곡괭이가 몸에 가려 잠깐 사라진다
  - 사망은 몸이 눕는데 표식은 선 채로 남는다(방패가 서 있고 후광이 누운 몸 위에 뜬다). 이동만으로는 붙일 수 없다
  - 옆모습 방패는 걷기 때처럼 고리로 읽힌다(5차와 같음). 두 손 도구 동작에서 방패는 팔을 따라가지 않고 옆구리에 머문다

## PixelLab 12차 (2026-10-17, 검 동쪽 옆모습, 3회 사용)

10차 검 동(ca06c79e)은 3~8번에서 몸이 정면 쪽으로 돌았다(다른 동작의 동·북은 옆·뒷모습을 지킴). 사람이 1~3회를 승인. 잔액 1,802 → 1,799.
공통: 10차와 같음(`animate_character`, `mode: "v3"`, 동쪽, `frame_count: 8`, `custom_start_frame_base64` = `base_body_v01_walk.png` 동쪽 첫 프레임).

| 판 | group | 바꾼 것 | 판정 |
|---|---|---|---|
| c | fdad142c-6b70-45eb-a0e6-63fb3397fb6f | 설명을 "seen from the side facing right the whole time, raising a short sword held in the right hand high above the head, then swinging it in a big fast slash down and forward to the right, then returning to a ready stance; the body and face stay in side view, never turning toward the viewer; same clothes and colours throughout"로 | 1~4번은 옆모습, 5~8번에서 다시 정면 쪽으로 돎 |
| d | 95781d97-2790-49ea-b909-fcbf5fc3d7bb | c와 같은 설명 + `end_frame_base64` = 시작 그림 | 8장 모두 옆모습. 칼이 주황색이고 발치에서 낮게 휘둘러 칼로 잘 안 읽힘 |
| e (채택) | f43b4631-660a-4df1-9232-0f25cec67cb9 | d + 설명 "holding a short steel sword with a shiny grey blade in the right hand, raising it high above the head, then slashing it down and forward to the right at chest height, then returning to a ready stance; the body and face stay in side view, never turning toward the viewer; same clothes and colours throughout" | 8장 모두 옆모습. 회색 칼을 머리 뒤로 들었다가 앞으로 베고 돌아옴. 떨어진 점 없음 |

- e판을 10차와 같은 방법으로 64칸에 맞춰 `base_body_v02_sword.png` 동 줄을 바꿨다. 전후 비교 `base_body_v02_reroll12_compare.png`(3배), `base_body_v02_actions.gif` 다시 만듦
- 요령: v3에서 몸이 정면으로 도는 것은 설명("never turning toward the viewer")만으로는 막히지 않았고, `end_frame_base64`에 시작 그림을 넣어 시작·끝을 같은 옆모습으로 묶자 막혔다. 값은 같다(방향당 1회). 대신 끝이 시작 자세로 돌아오므로 동작이 제자리로 돌아오는 동작에만 쓴다
