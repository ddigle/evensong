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
