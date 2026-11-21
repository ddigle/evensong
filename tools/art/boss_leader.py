# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""보스 이단의 지도자 스프라이트 손질 (2026-11-21, 03-pixel/prompts.md "PixelLab 17차"와 "17차 다시 뽑기"). 생성 없음, 다시 돌리면
같은 파일. 한 번 돌리면 v02(17차, 그대로 같은 바이트)와 v03(다시 뽑기 다섯 판을 넣은 판) 둘 다 쓴다.

실행 (어디서 돌려도 된다. 경로는 이 파일 기준. 고정 버전은 boss_leader.py.lock):
    uv run -q --python 3.14.6 --script tools/art/boss_leader.py
    또는 uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/boss_leader.py
    (--python 3.14.6을 빼면 SSH·샌드박스 셸에서 uv가 3.14 바로가기를 못 읽을 수 있다, os error 448)
    raw <폴더>  PixelLab 캐릭터 zip(character 3779a044-d935-4f6d-ab24-9ded137c8ec8, get_character가 알려 주는 download)을
               <폴더>에 푼 것(metadata.json + Idle/...)에서 raw 시트(v01)를 묶는다. 픽셀은 옮기기만 한다

읽는 것 (03-pixel, PixelLab에서 받은 그대로. 칸 = 그 동작에서 가장 큰 생성 캔버스, 프레임은 칸 왼쪽 위 (0, 0)에 두고 오른쪽·아래는
투명으로 채움. 방향마다 캔버스 크기는 RAW 표):
    boss_leader_v01_rotations.png     회전 남·동·북·서 (48칸, 서는 생성된 그대로. v02에서는 동 반전을 쓴다)
    boss_leader_v01_{walk,idle,hurt,death}.png    템플릿, 줄 남·동·북, 48칸 (6 · 4 · 6 · 7 프레임)
    boss_leader_v01_{cleave,cast,slam}.png         v3 9장(첫 장 = 걷기 첫 프레임), 줄 남·동·북
    boss_leader_v01_hurt_v3.png                    v3 7장, 줄 동·북 (남은 만들지 않음)
    boss_leader_v01_{cleave_r2,hurt_r2,cast_r2,death_r2}.png   다시 뽑기 v3 (휘두르기 남 9장, 피격 북 7장, 시전 남·동 9장,
                                                 사망 남 7장. 첫 장 = 걷기 첫 프레임)
    base_body_v02_idle.png, heretic_v02_idle.png, merchant_v02_idle.png   크기 비교용
쓰는 것 (03-pixel):
    boss_leader_v02_{idle,walk,hurt,death}.png   몸 칸 BODY(W×H), 줄 남·동·북, 발 = 칸 맨 아래 줄 (BODY[1]-1)
    boss_leader_v02_{attack,cast}.png            동작 칸 ACT(W×H), 9열(첫 열 = 시작 그림 = 손질한 걷기 첫 프레임, 재생은 1열부터),
                                                 줄 남·동·북. 몸 칸을 ACT_AT에 둔 좌표라 발 줄이 모든 시트에서 같다
    boss_leader_v02_rotations.png                몸 칸 4열 남·동·북·서 (서 = 동 좌우 반전, R19)
    boss_leader_v02_<시트>_emissive.png          같은 크기의 불꽃 마스크: 불꽃 픽셀만 A=255, RGB = 빛 세기(EMISSIVE, 04-env candB와 같은 형식)
    boss_leader_v02_anims.gif                    줄 남·동·북·서(동 반전), 칸 idle·걷기·공격·시전·피격·사망, 3배, 게임 이단의 틱 시간(GIF_TICKS).
                                                 공격·시전은 게임 boss_sim처럼 맞는 열(HIT_COLUMN) 앞 열을 예고 동안 붙잡는다
    boss_leader_v02_scale_check.png              위 1배, 아래 4배. 줄 남·동, 칸마다 기본 몸 · 이단 · 상인 · 보스 idle 첫 프레임.
                                                 빨간 선 = 발 줄. 글자는 그리지 않는다
    boss_leader_v03_{idle,walk,hurt,death,attack,cast}.png (+ _emissive), boss_leader_v03_anims.gif
                                                 v02와 같은 칸·규칙. 바뀐 줄(COLUMNS_V03)만 다르고 나머지 줄은 v02와 픽셀까지 같다:
                                                 공격 남 = cleave_r2, 시전 동 = cast_r2, 피격 북 = hurt_r2(자루 손질), 사망 남 = death_r2.
                                                 시전 남은 v02 줄(cast_r2 남은 예고가 약해 넣지 않음, CAST_SOUTH_R2).
                                                 GIF의 예고 붙잡기는 HIT_COLUMN_V03. 회전·scale_check는 v02 그대로라 v03을 쓰지 않는다

손질 순서 (프레임마다. 좌표는 raw 캔버스 좌표):
 1 지우기 (ERASE, raw 좌표 상자, 양 끝 포함): 걷기 동 4·5번의 몸 오른쪽 긴 검은 창, 피격(템플릿) 동 0~5번의 둘째 지팡이와 그 작은 불꽃.
   손(창·지팡이를 쥔 주먹)은 상자 밖에 남기고, 드러난 가장자리는 8의 외곽선이 닫는다. v03: 사망 남(death_r2) 1번의 칸 밖 지팡이 끝,
   공격 남(cleave_r2) 4번 두건 오른쪽에 붙어 남은 불 조각, 피격 북(hurt_r2) 1번 몸 가장자리의 짙은 줄(SHAFT의 빈 줄 자리).
   시전 동 예고 두 장(CHARGE): hurt_v3 동 1번의 불 줄기를 뿌리 둘레 반지름 2.5 · 4.5px 안만 남긴다 (손에 모이는 불)
 1b 옮겨 그리기 (v03 손질, 같은 판의 다른 프레임에서 raw 픽셀을 옮김, 우리 손질): SHAFT = 피격 북(hurt_r2) 1번의 빠진 아래 자루를
   시작 그림(0번)의 자루 픽셀로(같은 자리: 1번 몸 가장자리 짙은 줄을 ERASE로 지워 시작 그림처럼 몸과 자루 사이에 빈 줄), FLAME = 시전 동(cast_r2) 6번의 꺼진 화로에 5번의
   불꽃 마스크 픽셀을 6번이 투명한 자리에만. 옮긴 픽셀도 3~8을 그대로 거친다
 2 떨어진 덩어리 (DETACHED, 상자 하나 또는 여럿): 공격 남 2·3번(raw cleave 남) 머리 위 왼쪽의 붉은 점들, 다시 뽑기의 떠 있는 불티·불
   조각(cleave_r2 3·5·6, death_r2 3, 쓰지 않는 cast_r2 남 2·3·4·7). 상자에 닿는, 가장 큰 덩어리가 아닌 덩어리를 지운다
 3 떨어진 점 (SPECK px 이하 8방향 덩어리)을 지운다 (불티 1~2px 포함. 시전의 불 고리 조각은 3px 이상이라 남는다)
 4 불꽃 마스크 (fire_mask, raw 색으로 정함. 마스크는 그 뒤 모든 옮김을 같이 따라간다):
   씨앗 = 밝은 주황·노랑(색상 15~75°, 채도 >= 0.45, HLS 밝기 >= 0.5)의 8방향 덩어리 중 SEED_MIN px 이상인 것.
   거기서 이웃으로 넓힌다: 붉은 불 가장자리(색상 350~20°, 채도 >= 0.35, 밝기 >= 0.3)와 씨앗 색은 EDGE_RINGS 겹까지, 뜨거운 심
   (HLS 밝기 >= 0.78, 흰빛·옅은 노랑)은 HOT_RINGS 겹까지 넓힌 뒤 마스크에 이어진 심을 몇 겹이든 채운다. FIRE_MIN px보다 작은
   마스크 덩어리는 뺀다. 끝으로 씨앗에서 먼 불 조각(불 고리·불 꼬리): 붉은·주황 불빛(색상 <40° 또는 >=340°, 채도 >= 0.35,
   밝기 >= 0.3) 덩어리 중 FLAME_BIT_MIN px 이상이고 1/3 이상이 투명에 닿는 것(옷의 붉은 장식은 원본 외곽선 안이라 닿지 않는다).
   그래서 눈(1~2px)·가슴의 금빛 점·옷의 붉은 줄은 불꽃이 아니고, 화로 불꽃·불 줄기·땅의 불·불 고리·불 꼬리는 불꽃이다
 5 색 (recolour): 불꽃 마스크 픽셀은 raw L* 띠(FIRE_BANDS)로 악마 주황 넷(● brief §5.7 R49 이단 쪽 불 = candB), 나머지는
   묶음(family)별 사다리에서 밝기(L*)가 가장 가까운 색으로. 팔레트는 이단(heretic.py)의 위협 쪽 23색에서 쓰는 것 + brief §4
   악마 줄(피빛 장식·불) + 주황 눈·가슴 보석의 #ff7a1a(EMBER_MAX px 이하 덩어리만) + 옅은 금빛 장식의 #f4c95d("촛불 금빛은 양쪽에
   쓴다" §5.6). 푸른 기운(색상 150~250°)은 잿빛·뼈로 가서 남쪽 허리띠의 청록 점과 푸른 회색 쇠가 없어진다
 6 칸에 놓기: 가로는 방향마다 걷기 6장의 몸 무게중심 평균(body_centroid_x: 가장 낮은 픽셀에서 위로 BODY_ROWS줄의 불꽃 아닌
   픽셀, STAFF_CUT 지팡이 열은 뺌)이 몸 칸 가운데 축((W-1)/2)에 오게 한 값(DX)을 그 방향의 모든 시트에 쓴다 (creatures.py
   "가로 맞춤". 지팡이까지 넣으면 남은 몸이 4px 오른쪽, 북은 3px 왼쪽에 서서 남↔북으로 돌 때 7px 튄다).
   세로: 걷기·idle은 방향마다 모든 프레임 중 가장 낮은 픽셀을, 피격·사망(템플릿)은 첫 프레임의
   가장 낮은 픽셀을 칸 맨 아래 줄에 두고 칸 밖으로 나가는 프레임만 올린다(heretic.py와 같음), 회전은 그림마다 가장 낮은 픽셀.
   v3 프레임(공격·시전·피격 북, v03의 사망 남)은 v3 첫 장에서 걷기 첫 프레임(raw)이 놓인 자리(locate, 픽셀까지 같음)를 찾아,
   걷기 첫 프레임의 발이 칸 맨 아래 줄에 오는 자리에 둔다. 몸 칸의 v3 프레임은 템플릿과 같이 칸 밖으로 나가는 프레임만 올린다
   (v03 사망 남의 누운 4~6번: 바닥에 누운 지팡이가 발 줄 5px 아래). KEY 열(v3 동작의 첫 열·끝 열, 피격 북 끝 열, v03 사망 남 첫 열)은
   손질한 걷기 첫 프레임
 7 두건 끝 (TIP): 템플릿은 그림이 캔버스 윗줄(y=0)에 닿아 두건 끝이 잘린 프레임이 있다. 잘린 윗줄의 불꽃 아닌 덩어리(폭 n >= 3)
   위에 폭 n-2 줄을 한 줄 더하고(가운데에서 두건이 기운 쪽으로), 8의 외곽선이 그 위를 닫는다 (작은 손질, 뾰족한 모양은 다 살리지 못함)
 7b 땅의 불 (GROUND, 동작 칸의 v3 프레임만): 발 줄(y 53) 아래의 불꽃 아닌 픽셀 중 raw 색이 불빛(색상 < 75° 또는 >= 340°,
   채도 >= GROUND_CH, 밝기 >= GROUND_L)인 것을 불꽃으로(마스크에 넣고 FIRE_BANDS 색). 발 줄 아래에는 몸이 없고 지팡이 끝·화로는
   어둡거나 잿빛이다. 4의 크기 문턱보다 작은 불 고리 조각·노란 불티가 8에서 외곽선 검정이 되거나 촛불 금빛이 되던 것
 8 외곽선: 칸 좌표에서 실루엣 가장자리(4방향 이웃이 투명)의 불꽃 아닌 픽셀: 어두우면(L* < DARK_L) 그 자리를, 밝으면 바깥 1px를
   #1a1714로. 칸 경계·발 줄 아래로는 더하지 않고 그 자리를 외곽선으로. 불꽃은 외곽선을 두르지 않는다 (04-env 불꽃처럼)
 9 검사: 칸 안, 반투명 0, 팔레트 밖 색 0, 불꽃 아닌 실루엣 가장자리 100% 외곽선, 어두운 색 중 B > R+5는 보라 맥뿐
"""
import colorsys
import json
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")
NAME = "boss_leader"

DIRS = ("south", "east", "north")
ROT_DIRS = ("south", "east", "north", "west")
T = (48, 48)
# raw 묶음: 파일 이름 -> (PixelLab animation_name, 방향, 프레임 수, 방향마다 받은 캔버스 (W, H))
RAW = {
    "walk": ("leader_walk", DIRS, 6, {d: T for d in DIRS}),
    "idle": ("leader_idle", DIRS, 4, {d: T for d in DIRS}),
    "hurt": ("leader_hurt", DIRS, 6, {d: T for d in DIRS}),
    "death": ("leader_death", DIRS, 7, {d: T for d in DIRS}),
    "cleave": ("leader_cleave", DIRS, 9, {"south": (68, 68), "east": (56, 60), "north": (56, 68)}),
    "cast": ("leader_cast", DIRS, 9, {"south": (72, 76), "east": (48, 60), "north": (52, 68)}),
    "slam": ("leader_slam", DIRS, 9, {"south": (56, 72), "east": (48, 60), "north": (56, 72)}),
    "hurt_v3": ("leader_hurt_v3", ("east", "north"), 7, {"east": (52, 56), "north": (52, 68)}),
    # 17차 다시 뽑기 (v3, 방향마다 1회. prompts.md "17차 다시 뽑기"). 시전 동은 남과 같은 이름으로 만들어 zip 폴더 이름이
    # leader_cast_r2-22892eb4(그 group id의 앞 8자)라 방향마다 이름을 적는다
    "cleave_r2": ("leader_cleave_r2", ("south",), 9, {"south": (64, 76)}),
    "hurt_r2": ("leader_hurt_r2", ("north",), 7, {"north": (52, 72)}),
    "cast_r2": ({"south": "leader_cast_r2", "east": "leader_cast_r2-22892eb4"}, ("south", "east"), 9,
                {"south": (56, 72), "east": (52, 56)}),
    "death_r2": ("leader_death_r2", ("south",), 7, {"south": (60, 68)}),
}
TEMPLATES = ("walk", "idle", "hurt", "death")

# --- 채택 (prompts.md 17차 표). 열마다 (raw 묶음, 프레임) 또는 KEY(손질한 걷기 첫 프레임) ---
KEY = ("key", 0)
BODY_ANIMS = ("idle", "walk", "hurt", "death")
COLUMNS = {
    "idle": {d: [("idle", i) for i in range(4)] for d in DIRS},
    "walk": {d: [("walk", i) for i in range(6)] for d in DIRS},
    # 피격: 남·동은 템플릿(동은 둘째 지팡이를 지움), 북은 v3 피격(템플릿 북은 지팡이가 사라지고 두건 끝이 줄어듦).
    # 북은 게임에서 지팡이가 같은 쪽(오른쪽)에 있는 1·5번만 쓴다: 1, 5, 5, 1, 1, 시작 그림. 2~4번은 지팡이를 두건 왼쪽으로 넘겨,
    # boss_sim이 맞을 때 보여 주는 0~2열과 기절 동안 붙잡는 1열(SKILL_STUN_FRAME)에서 지팡이가 좌우로 건너뛰었다
    "hurt": {"south": [("hurt", i) for i in range(6)], "east": [("hurt", i) for i in range(6)],
             "north": [("hurt_v3", 1), ("hurt_v3", 5), ("hurt_v3", 5), ("hurt_v3", 1), ("hurt_v3", 1), KEY]},
    "death": {d: [("death", i) for i in range(7)] for d in DIRS},
    # v3 동작은 모두 첫 열과 끝 열이 시작 그림(손질한 걷기 첫 프레임). 끝 그림을 넣어 만든 판의 끝 장은 시작 그림과 19~53px만
    # 다르고, 공격 남(끝 그림 없이 만듦)의 8번은 지팡이가 사라져 손에 불만 남는다
    # 공격 = 지팡이 휘두르기(cleave)
    "attack": {d: [KEY] + [("cleave", i) for i in range(1, 8)] + [KEY] for d in DIRS},
    # 시전(불 화살·불타는 땅): 남 = cast 남 1~3(지팡이를 머리 위로 들어 올림, 예고) + slam 남 3~6(오른쪽 앞 땅에 불이 솟음).
    # 동 = hurt_v3 동(가슴 앞에서 앞으로 뿜는 불 줄기). 예고 두 장은 1번의 줄기를 손 둘레의 작은 불로 줄인 것(CHARGE).
    # 북 = slam 북 1~7(머리 위로 불 호가 돌아 몸을 감쌈)
    "cast": {"south": [KEY, ("cast", 1), ("cast", 2), ("cast", 3), ("slam", 3), ("slam", 4), ("slam", 5), ("slam", 6), KEY],
             "east": [KEY, ("charge", 0), ("charge", 1)] + [("hurt_v3", i) for i in range(1, 6)] + [KEY],
             "north": [KEY] + [("slam", i) for i in range(1, 8)] + [KEY]},
}
# 예고(CHARGE): hurt_v3 동 1번에서 불꽃 마스크 픽셀 중 줄기 뿌리 CHARGE_ROOT(raw 좌표)에서 반지름 r보다 먼 것을 지운 두 장
# (손 둘레에 모이는 불 -> 커짐). 시트에서는 hurt_v3 동과 같은 자리에 둔다
CHARGE_FROM = ("hurt_v3", "east", 1)
CHARGE_BOX = (28, 24, 51, 40)     # 줄기가 있는 상자 (x0, y0, x1, y1, 양 끝 포함). 얼굴 앞 화로 불꽃은 상자 밖이라 그대로
CHARGE_ROOT = (32, 31)
CHARGE_RADII = (2.5, 4.5)
PLACE_AS = {"charge": "hurt_v3"}
ACTIONS = ("attack", "cast")
# 맞는 열 후보 (○, 게임이 정함): 이 열부터 타격. 그 앞 열이 예고 그림 (게임 boss_sim은 맞는 열 바로 앞 열을 예고 동안 붙잡는다).
# 지금 게임은 이단의 맞는 열(Config.HERETIC_HIT_COLUMN 남 3 · 동 4 · 북 5)을 보스에도 쓴다
HIT_COLUMN = {"attack": {"south": 3, "east": 3, "north": 3}, "cast": {"south": 4, "east": 3, "north": 3}}

# --- v03 (17차 다시 뽑기, prompts.md "17차 다시 뽑기"): COLUMNS에서 네 줄만 바꾼다. 나머지 줄은 v02와 픽셀까지 같다 ---
COLUMNS_V03 = {anim: dict(rows) for anim, rows in COLUMNS.items()}
# 공격 남 = cleave_r2 남 1~7 (큰 원으로 휘두르기: 1·2 지팡이를 머리 옆으로 듦, 3 오른쪽 가슴 높이로, 4·5 오른쪽 아래, 6 앞 아래, 7 왼쪽 아래)
COLUMNS_V03["attack"]["south"] = [KEY] + [("cleave_r2", i) for i in range(1, 8)] + [KEY]
# 시전 동 = cast_r2 동 1~7 (화로를 팔 길이 앞으로 내밀어 3~6번에 얼굴이 보임, 3~5 앞으로 짧은 불. 6번 꺼진 화로는 FLAME)
COLUMNS_V03["cast"]["east"] = [KEY] + [("cast_r2", i) for i in range(1, 8)] + [KEY]
# 시전 남은 v02 줄 그대로 (cast_r2 남은 넣지 않음). cast_r2 남은 내리꽂는 장(3~6: 몸이 곧고 지팡이가 보이는 불기둥·땅의 불)은
# v02보다 낫지만, 예고 장(1 지팡이를 듦: 화로가 시작 그림보다 3px 위, 2 화로를 두건 옆으로 당김)이 1배에서 서 있는 그림과 갈리지
# 않는다. 게임은 화염 일제 예고 42틱 동안 맞는 열 앞 열들을, 불바닥의 서 있는 24틱 내내 들어 올림 열만 보이고 타격 장은 일제의
# 12틱뿐이라, 화면에 머무는 시간으로는 예고 장이 5배 넘게 길다. v02의 예고(지팡이를 머리 위 왼쪽으로 크게 기울여 듦)가 그 시간에
# 읽혀서 v02 줄을 남겼다. 사람이 cast_r2 남을 고르면 COLUMNS_V03["cast"]["south"] = CAST_SOUTH_R2 한 줄을 더하고
# HIT_COLUMN_V03 시전 남을 3으로 바꾼다(붙잡는 2열이 가장 높이 든 1번이 되게 1·2를 바꾼 줄. CHANGED_V03은 COLUMNS_V03에서
# 저절로 셈. 손질 표 DETACHED·ERASE의 cast_r2 남 항목은 그때 쓰려고 남김)
CAST_SOUTH_R2 = [KEY, ("cast_r2", 2), ("cast_r2", 1)] + [("cast_r2", i) for i in range(3, 8)] + [KEY]
# 피격 북 = hurt_r2 북. 게임은 맞을 때 0~2열(번쩍임), 기절 때 1열만 보인다: 0~2열 모두 1번(움찔, 아래 자루는 SHAFT로 시작 그림에서
# 옮김). 3·4열은 생성된 회복 장 5번(화로가 두건 옆, 자루 없음: 게임은 보이지 않음), 끝 열 시작 그림. 2~4번은 지팡이가 사라지거나
# 화로가 왼쪽 어깨로 건너가 쓰지 않음
COLUMNS_V03["hurt"]["north"] = [("hurt_r2", 1), ("hurt_r2", 1), ("hurt_r2", 1), ("hurt_r2", 5), ("hurt_r2", 5), KEY]
# 사망 남 = death_r2 남: 첫 열 시작 그림 + 1~6 (1·2 선 채 지팡이가 기울고, 3 무너짐, 4~6 엎드려 누움·지팡이가 바닥에 눕고 화로가
# 오른쪽에서 옆으로 탐). 누운 4~6번은 칸 밖(발 줄 5px 아래)이라 올린다(6의 세로 규칙)
COLUMNS_V03["death"]["south"] = [KEY] + [("death_r2", i) for i in range(1, 7)]
# 맞는 열 후보 (○, 게임이 정함). 바뀐 줄만 v02와 다르다. 공격 남 5: 예고 동안 1~3열(듦 -> 오른쪽으로 휘둘러 냄)을 지나 4열
# (화로를 오른쪽 아래로 젖힘)을 붙잡고, 타격 5·6·7열 = 오른쪽 아래 -> 앞 아래 -> 왼쪽 아래(앞의 부채꼴을 가로지름). 다른 후보 3은
# 2열(머리 옆으로 듦)을 붙잡아 예고는 또렷하지만 보이는 3·4·5열이 오른쪽에만 있어 앞을 지나지 않는다. 시전 동 3: 붙잡는 2열 =
# 화로를 얼굴에서 앞으로 밀어냄, 타격 3열 = 팔 길이 앞의 화로와 앞으로 나간 불. 시전 남은 v02 줄이라 v02의 4 그대로.
# 게임(BossSim.HIT_COLUMN_ATTACK)도 공격 남 5다(검토에서 6과 견줌: 6열의 화로는 발 앞 아래라 남쪽 대상에 가린다. game/README
# "M12 보스 그림" 다시 뽑기 (v03)). 게임에서 맞는 열을 바꾸면 이 표도 같이 바꿔 GIF를 다시 쓴다
HIT_COLUMN_V03 = {"attack": {"south": 5, "east": 3, "north": 3}, "cast": {"south": 4, "east": 3, "north": 3}}

# --- 칸 (그림은 1배 그대로, 4의 배수) ---
BODY = (56, 48)            # 몸 칸 (W, H): 발 = 맨 아래 줄 y=47, 몸 가운데 축 x=27.5
ACT = (64, 64)             # 동작 칸 (W, H)
ACT_AT = (4, 6)            # 동작 칸 속 몸 칸의 왼쪽 위: 축 x=31.5, 발 줄 y = 6 + 47 = 53 (발 아래 10줄: 땅의 불·불 고리가 8줄까지)
# 가로 맞춤의 몸: 걷기 프레임마다 가장 낮은 픽셀에서 위로 BODY_ROWS줄(로브 아랫부분)의 불꽃 아닌 픽셀, 지팡이 열은 뺌.
# 지팡이는 오른손에 들어 남쪽에서는 그림 왼쪽(raw x <= 13), 북쪽에서는 오른쪽(raw x >= 34)에 늘 있다. 동쪽은 얼굴 앞이라 빼지 않음
BODY_ROWS = 18
STAFF_CUT = {"south": (">", 13), "east": None, "north": ("<", 34)}   # 남기는 열 (raw x)

# --- 1~3 손질 표 (raw 좌표, 양 끝 포함) ---
ERASE = {
    # 걷기 동 4·5: 몸 오른쪽 위아래로 긴 검은 창. 주먹(4번 y 19~24, 5번 y 21~27)은 남김.
    # 5번은 창의 왼쪽 외곽선(x 30, y 6~12: 화로 불꽃 오른쪽)까지 지운다. y 13~16의 x 30은 몸의 외곽선이라 남김
    ("walk", "east", 4): [(32, 0, 47, 18), (33, 25, 47, 47)],
    ("walk", "east", 5): [(30, 0, 47, 12), (31, 13, 47, 21), (31, 28, 47, 47)],
    # 피격 동: 얼굴 앞 화로와 따로, 오른쪽에 작은 불꽃을 얹은 둘째 지팡이. 불꽃·사발·자루를 지우고 쥔 주먹은 남김.
    # 0번은 둘째 사발의 왼쪽 외곽선(x 34, y 9~12: 얼굴 앞 불꽃 오른쪽)까지
    ("hurt", "east", 0): [(35, 0, 47, 17), (34, 9, 34, 12), (37, 18, 47, 24), (36, 25, 47, 47)],
    ("hurt", "east", 1): [(35, 0, 47, 14), (38, 22, 47, 47)],
    ("hurt", "east", 2): [(29, 0, 47, 8), (30, 9, 47, 12), (31, 13, 47, 47)],
    ("hurt", "east", 3): [(27, 0, 47, 9), (29, 10, 47, 14), (30, 15, 47, 28), (31, 29, 47, 35), (30, 36, 47, 47)],
    ("hurt", "east", 4): [(33, 0, 47, 11), (35, 12, 47, 12), (36, 13, 47, 18), (35, 19, 47, 47)],
    ("hurt", "east", 5): [(35, 0, 47, 10), (37, 11, 47, 17), (37, 24, 47, 47)],
    # v03 사망 남 1번: 기우는 지팡이 끝(x 16~18)이 발 줄(raw y 50) 1px 아래. 칸 밖이라 프레임째 올리면 선 몸이 1px 뛰어서 그 3px만 지움
    ("death_r2", "south", 1): [(16, 51, 18, 51)],
    # v03 공격 남 cleave_r2 4번: 3번의 큰 불 꼬리가 지나간 뒤 두건 오른쪽(얼굴 옆)에 붙어 남은 불 조각 6px(x 40~42, y 30~31)와 그
    # 아래 붉은 꼬리·외곽선 3px(y 32). 두건 외곽선(x 39)에 닿아 DETACHED·SPECK에 걸리지 않고, 어둠에서 얼굴 옆에 홀로 빛나는 점이
    # 된다(게임은 맞는 열 5에서 이 4열을 예고 동안 18틱 붙잡음). y 32까지 지우지 않으면 붉은 꼬리가 외곽선 두른 돌기로 남음
    ("cleave_r2", "south", 4): [(40, 30, 42, 32)],
    # v03 피격 북 hurt_r2 1번: 몸 외곽선(x 35) 오른쪽의 짙은 줄(x 36, 손 아래 y 40~48). 지우고 SHAFT를 같은 자리(x 37~39)에 덮어
    # 시작 그림(0번)처럼 몸과 자루 사이에 빈 줄을 둔다(1px 왼쪽에 덮던 것은 자루가 몸 외곽선에 붙어 두꺼운 로브 가장자리로 읽힘)
    ("hurt_r2", "north", 1): [(36, 40, 36, 48)],
    # 시전 남 cast_r2 3번 (v03에는 쓰지 않음, CAST_SOUTH_R2용): 지운 불 고리(DETACHED) 끝에 붙어 왼쪽 어깨 위로 나온 붉은·녹빛·잿빛
    # 4px(x 20, y 21~23과 x 21, y 23).
    # 어깨 외곽선에 닿아 떨어진 덩어리가 아니라서 상자로 지운다(지우지 않으면 타격 열 어깨에 외곽선 두른 붉은 돌기)
    ("cast_r2", "south", 3): [(20, 21, 21, 23)],
}
DETACHED = {
    ("cleave", "south", 2): (0, 0, 24, 22), ("cleave", "south", 3): (0, 0, 24, 19),
    # v03: 다시 뽑기의 떠 있는 불티·불 조각 (raw 좌표, 덩어리 크기). 불꽃 마스크의 불 조각·땅의 불 규칙이 이것들을 불꽃(빛남)으로
    # 만들어 게임의 빛 자리를 끌지 않게 지운다. cast_r2 남은 v03에 쓰지 않지만(CAST_SOUTH_R2) 사람이 고를 때를 위해 남김
    ("cleave_r2", "south", 3): (17, 19, 24, 27),    # 머리 왼쪽 위에 남은 노란 불 덩이 17px
    ("cleave_r2", "south", 5): (45, 34, 50, 39),    # 불 꼬리 옆 노란 불티 4px
    ("cleave_r2", "south", 6): (42, 51, 47, 56),    # 불 꼬리 옆 노란 불티 4px
    ("cast_r2", "south", 2): (6, 14, 14, 23),       # 화로 왼쪽의 붉은 불티 4 · 3px
    ("cast_r2", "south", 3): (6, 12, 20, 28),       # 머리 왼쪽 위에 떠 있는 붉은 불 고리 35px와 불티 4 · 2 · 2 · 2px
    ("cast_r2", "south", 4): [(10, 12, 22, 22), (42, 36, 47, 41)],   # 머리 왼쪽 위 불티, 지팡이 오른쪽 불티 3px
    ("cast_r2", "south", 7): (30, 42, 49, 59),      # 발치에 흩어진 붉은 불티 5 · 5 · 4 · 4 · 3 · 2 · 2 · 1 · 1px
    ("death_r2", "south", 3): (13, 16, 30, 27),     # 무너지는 몸 위에 떠 있는 불티 3 · 3 · 2 · 2px
}
SPECK = 2
# 1b 옮겨 그리기 (v03, 우리 손질). SHAFT: (판, 방향, 프레임) -> (옮겨 올 프레임, raw 상자 (x0, y0, x1, y1, 양 끝 포함), (dx, dy)).
# 그 프레임의 상자 안 불투명 픽셀을 (dx, dy) 옮겨 덮어쓴다. 피격 북 1번(움찔)은 화로·목·손(x 36~38, y 34~38)까지만 있고 아래 자루가
# 없다. 시작 그림(0번)의 자루(x 37~39: 외곽선 · 심 · 외곽선, 손 아래 y 39~50)를 같은 자리에 덮는다. 1번의 몸 가장자리 짙은 줄(x 36)은
# ERASE로 지워 시작 그림처럼 몸 외곽선(x 35)과 자루 사이가 빈 줄(x 36)이다. 1번의 화로 목은 시작 그림보다 2px 왼쪽이지만 손(x 37)에서
# 아래로 자루 심(x 38)이 이어져 기운 지팡이로 읽힌다. 처음 손질은 1px 왼쪽에 덮어 자루가 몸 외곽선에 붙어 두꺼운 로브 가장자리로
# 읽혔다(검토에서 찾음)
SHAFT = {("hurt_r2", "north", 1): (0, (37, 39, 39, 50), (0, 0))}
# FLAME: (판, 방향, 프레임) -> (옮겨 올 프레임, raw 상자). 그 프레임(떨어진 점을 지운 뒤)의 불꽃 마스크 픽셀 중 상자 안이고 이 프레임이
# 투명한 자리에만 붙인다. 시전 동 6번은 화로를 팔 길이 앞에 그대로 든 채 불꽃이 없다(5번과 7번에는 있음). 5번 화로는 같은 자리라
# 그 불꽃이 6번 화로 입(x 38~39) 오른쪽에 붙는다(x 40~41, y 24~30의 12px). 화로 입의 흰 심 6px는 붙인 불에 이어져 4의 심 채우기로
# 불꽃이 된다(6번 불꽃 18px). 상자를 화로 위·아래(y 22~23, 32~33)까지 넓히면 5번 불꽃의 붉은 가장자리 8px가 6번에서는 씨앗과 멀어
# 불꽃 마스크 밖의 피빛 점(외곽선 두름)이 되어 넣지 않았다
FLAME = {("cast_r2", "east", 6): (5, (38, 24, 44, 31))}

# --- 4 불꽃 마스크 ---
SEED_MIN = 4
HOT_RINGS = 3
EDGE_RINGS = 2
FIRE_MIN = 6
FLAME_BIT_MIN = 5
FIRE_CORE_L = 60
EMBER_MAX = 4
# 땅의 불 (GROUND, 동작 칸): 발 줄 아래(몸이 없는 곳)의 불꽃 아닌 픽셀 중 raw 색이 불빛(색상 < 75° 또는 >= 340°, 채도 >= GROUND_CH,
# HLS 밝기 >= GROUND_L)인 것은 불꽃. slam의 불 고리·땅의 불에서 떨어진 3~4px 조각과 노란 불티(위 마스크 규칙의 크기 문턱 아래)가
# 외곽선 검정이나 촛불 금빛이 되지 않게
GROUND_CH = 0.2
GROUND_L = 0.3

# --- 5 팔레트 ---


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


RAMPS = {
    "outline": ["#1a1714"],
    # 숯빛 옷·두건 (이단의 멍든 자줏빛 회색 옷 사다리, R >= B) + 밝은 끝 한 칸(이단 피부의 어두운 색, 두건 밝은 면)
    "robe": ["#2a2027", "#3a2c37", "#4d3d49", "#61515d", "#7f7580"],
    # 잿빛 (이단 두건의 잿빛 사다리): 쇠 화로·자루, 푸른 회색과 청록 점
    "ash": ["#2f2b29", "#46413e", "#5d5854", "#77716c", "#928c86", "#b0aaa3"],
    # 창백한 피부 (이단 피부 사다리 + 그림자 한 칸)
    "skin": ["#61515d", "#7f7580", "#a69da6", "#ccc5c9"],
    # 피빛 장식 (brief §4 악마 줄)
    "blood": ["#2a0808", "#5c1010", "#8f1a1a", "#c8321f"],
    # 가는 맥 (brief §4 타락 줄의 어두운 둘)
    "violet": ["#3b1f4d", "#5e2d7a"],
    "rust": ["#4a1c16", "#7a2f20", "#a3492c"],
    "bone": ["#a39c8c", "#d8d2c0"],
    # 불꽃이 아닌 작은 불빛: 주황 눈·가슴 보석은 악마 주황, 옅은 금빛 장식은 촛불 금빛("촛불 금빛은 양쪽에 쓴다" §5.6)
    "ember": ["#ff7a1a", "#f4c95d"],
    # 불꽃 (마스크): 이단 쪽 불 = 악마 주황(● brief §5.7 R49, 04-env candB와 같은 넷). 흰빛·노랑 심도 #ff7a1a로 간다
    "fire": ["#5c1010", "#8f1a1a", "#c8321f", "#ff7a1a"],
}
OUT = hx(RAMPS["outline"][0])
PALETTE = {hx(c) for r in RAMPS.values() for c in r}
# 불꽃 색: raw L* 띠. FIRE_CORE_L 60 이상(흰빛·노랑·주황) -> #ff7a1a, 46~60(주황빛 빨강) -> #c8321f, 34~46(빨강) -> #8f1a1a,
# 그 아래 -> #5c1010. L*가 가장 가까운 색(경계 55.6 · 38.6 · 26)보다 빨강 쪽 경계를 올려 불꽃 가장자리가 한 단 어둡다.
# 72로 올리면 주황까지 #c8321f가 되어 불꽃이 어두워져(시험) 60으로 두었다. 흰 심이 많은 slam 남 3번 불기둥은 #ff7a1a 덩어리가 된다
FIRE_BANDS = ((FIRE_CORE_L, "#ff7a1a"), (46, "#c8321f"), (34, "#8f1a1a"), (0, "#5c1010"))
# 불꽃 마스크의 빛 세기 = 04-env flame_heretic_*_candB_v01_emissive와 같은 값
EMISSIVE = {hx("#ff7a1a"): 205, hx("#c8321f"): 150, hx("#8f1a1a"): 100, hx("#5c1010"): 60}
DARK_L = 30


def lstar(c):
    def lin(v):
        v = v / 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
    return 116 * (y ** (1 / 3) if y > 216 / 24389 else (24389 / 27 * y + 16) / 116) - 16


RAMP_L = {k: [lstar(hx(c)) for c in v] for k, v in RAMPS.items()}


def hlc(c):
    """(색상°, HLS 밝기, 채도 = (max-min)/255)"""
    h, l, _ = colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)
    return h * 360, l, (max(c) - min(c)) / 255


def family(c):
    """raw 색 -> 묶음 (불꽃 마스크 밖의 픽셀)"""
    hue, l, ch = hlc(c)
    if l < 0.11:
        return "outline"
    if (hue < 30 or hue >= 300) and 0.02 <= ch < 0.10 and 0.75 <= l < 0.90:
        return "skin"                            # 분홍빛 흰 회색 = 얼굴의 밝은 면 (뼈 부적의 흰빛은 l >= 0.90)
    if ch < 0.06:
        return "bone" if l >= 0.80 else "ash"
    if 150 <= hue < 250:                         # 푸른 기운: 청록 점, 푸른 회색 쇠, 푸른 흰빛
        return "bone" if l >= 0.78 else "ash"
    if 15 <= hue < 75:                           # 주황·노랑·갈색
        if ch >= 0.45 and l >= 0.45:
            return "ember"                       # 주황 눈·가슴 보석 (-> #ff7a1a), 아주 밝은 노랑 (-> #f4c95d)
        if l >= 0.70:
            return "ember" if ch >= 0.25 else "bone"
        if ch >= 0.2 and lstar(c) < 58:
            return "rust"
        return "bone" if lstar(c) >= 58 else "ash"
    if hue < 15 or hue >= 330:                   # 빨강·진홍 (밝은 빨강도 피빛 사다리의 #c8321f까지)
        if l >= 0.55 and ch < 0.40:
            return "skin"                        # 옅은 분홍 (손·얼굴의 밝은 면)
        if ch >= 0.2:
            return "blood"
        return "skin" if l >= 0.35 else "robe"
    if hue < 290:                                # 250~290: 보랏빛 숯 회색 (두건·옷과 그 밝은 면)
        if l >= 0.60:
            return "skin"
        return "robe" if ch < 0.2 else "violet"
    if ch >= 0.22:                               # 290~330: 진한 것은 피빛 그림자
        return "blood"
    return "skin" if l >= 0.40 else "robe"


def nearest(fam, c):
    L = lstar(c)
    return hx(RAMPS[fam][int(np.argmin([abs(L - x) for x in RAMP_L[fam]]))])


_cache = {}


def fire_colour(c):
    """불꽃 마스크 픽셀: raw L* 띠로 FIRE 사다리 (FIRE_BANDS: 이 L* 이상이면 그 색, 위에서부터)"""
    L = lstar(c)
    for lo, col in FIRE_BANDS:
        if L >= lo:
            return hx(col)
    return hx(FIRE_BANDS[-1][1])


def map_colour(c, fire):
    key = (c, fire)
    if key not in _cache:
        fam = "fire" if fire else family(c)
        _cache[key] = (fam, fire_colour(c) if fire else nearest(fam, c))
    return _cache[key]


# --- 미리보기 ---
GIF_SCALE = 3
# 게임 이단의 틱 시간 (60틱/초): HereticSim.IDLE_FRAME_TICKS 12, WALK_FRAME_TICKS 7, Config.HERETIC_ATTACK_FRAME_TICKS 6(공격·시전),
# HERETIC_HURT_FRAME_TICKS 3, HERETIC_DEATH_FRAME_TICKS 6. 한 번 하는 동작은 끝 프레임에서 GIF_HOLD틱 머문 뒤 다시 (반복 336틱 = 5.6초)
GIF_TICKS = {"idle": 12, "walk": 7, "attack": 6, "cast": 6, "hurt": 3, "death": 6}
GIF_HOLD = {"hurt": 30, "death": 42}
# 공격·시전은 게임 boss_sim.attack_frame처럼: 맞는 열(HIT_COLUMN) 앞 열을 예고 틱까지 붙잡고, 그 뒤 6틱씩, 끝 열에서 머문 뒤 다시.
# 예고 틱 = Config.BOSS_ATTACKS의 휘두르기 telegraph 36 (공격), 불덩이 telegraph 42 (시전. 불바닥은 cast_ticks 24). 한 번 = GIF_ACT_SPAN틱
GIF_TELEGRAPH = {"attack": 36, "cast": 42}
GIF_ACT_SPAN = 84
GIF_LOOP = 336
BG = (52, 48, 46, 255)          # 미리보기 바탕 (어두운 던전 바닥 쪽)
CHECK_BG = (120, 140, 90, 255)  # scale_check 바탕 (풀빛, merchant·creatures와 같음)
FEET_LINE = (220, 40, 40, 255)


def load(name):
    return np.array(Image.open(os.path.join(PIX, name)).convert("RGBA"))


def save(a, name):
    Image.fromarray(np.ascontiguousarray(a.astype(np.uint8))).save(os.path.join(PIX, name))
    print("wrote", name, a.shape[1], "x", a.shape[0])


# =====================================================================================
# raw 묶기
# =====================================================================================
def raw_cell(clip):
    sizes = RAW[clip][3].values()
    return max(w for w, _ in sizes), max(h for _, h in sizes)


def pack_raw(src):
    with open(os.path.join(src, "metadata.json"), encoding="utf-8") as fh:
        st = json.load(fh)["states"][0]
    assert st["character"]["id"] == "3779a044-d935-4f6d-ab24-9ded137c8ec8"
    frames = st["frames"]
    rot = np.zeros((48, 48 * 4, 4), np.uint8)
    for i, d in enumerate(ROT_DIRS):
        a = np.array(Image.open(os.path.join(src, frames["rotations"][d])).convert("RGBA"))
        assert a.shape == (48, 48, 4), (d, a.shape)
        rot[:, i * 48:(i + 1) * 48] = a
    save(rot, f"{NAME}_v01_rotations.png")
    for clip, (anim, dirs, n, canv) in RAW.items():
        cw, ch = raw_cell(clip)
        sheet = np.zeros((ch * len(dirs), cw * n, 4), np.uint8)
        for r, d in enumerate(dirs):
            paths = frames["animations"][anim if isinstance(anim, str) else anim[d]][d]
            assert len(paths) == n, (clip, d, len(paths))
            for i, p in enumerate(paths):
                a = np.array(Image.open(os.path.join(src, p)).convert("RGBA"))
                assert a.shape[:2] == (canv[d][1], canv[d][0]), (clip, d, i, a.shape)
                sheet[r * ch:r * ch + a.shape[0], i * cw:i * cw + a.shape[1]] = a
        save(sheet, f"{NAME}_v01_{clip}.png")


def load_raw():
    """{(clip, dir): [frame, ...]}, 프레임은 받은 캔버스 크기"""
    out = {}
    for clip, (_, dirs, n, canv) in RAW.items():
        sheet = load(f"{NAME}_v01_{clip}.png")
        cw, ch = raw_cell(clip)
        assert sheet.shape == (ch * len(dirs), cw * n, 4), (clip, sheet.shape)
        for r, d in enumerate(dirs):
            w, h = canv[d]
            out[(clip, d)] = [sheet[r * ch:r * ch + h, i * cw:i * cw + w].copy() for i in range(n)]
            # 패딩 자리는 투명이어야 한다 (묶음이 맞는지)
            for i in range(n):
                cell = sheet[r * ch:(r + 1) * ch, i * cw:(i + 1) * cw, 3]
                assert cell[h:].max(initial=0) == 0 and cell[:, w:].max(initial=0) == 0, (clip, d, i)
    rot = load(f"{NAME}_v01_rotations.png")
    out[("rot", "all")] = [rot[:, i * 48:(i + 1) * 48].copy() for i in range(4)]
    return out


# =====================================================================================
# 1~4 raw 손질
# =====================================================================================
def components(op):
    h, w = op.shape
    lab = np.zeros((h, w), int)
    sizes = [0]
    n = 0
    for y0, x0 in zip(*np.nonzero(op)):
        if lab[y0, x0]:
            continue
        n += 1
        stack = [(y0, x0)]
        lab[y0, x0] = n
        size = 0
        while stack:
            y, x = stack.pop()
            size += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and op[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n
                        stack.append((yy, xx))
        sizes.append(size)
    return lab, sizes


def erase(f, boxes):
    n = 0
    for x0, y0, x1, y1 in boxes:
        blk = f[y0:y1 + 1, x0:x1 + 1]
        n += int((blk[..., 3] > 0).sum())
        blk[:] = 0
    return n


def drop_detached(f, box):
    lab, sizes = components(f[..., 3] > 0)
    main = int(np.argmax(sizes))
    x0, y0, x1, y1 = box
    n = 0
    for k in range(1, len(sizes)):
        if k != main and (lab[y0:y1 + 1, x0:x1 + 1] == k).any():
            f[lab == k] = 0
            n += sizes[k]
    return n


def drop_specks(f):
    lab, sizes = components(f[..., 3] > 0)
    n = 0
    for k in range(1, len(sizes)):
        if sizes[k] <= SPECK:
            f[lab == k] = 0
            n += sizes[k]
    return n


def fire_mask(f):
    op = f[..., 3] > 0
    h, w = op.shape
    seed = np.zeros((h, w), bool)
    hot = np.zeros((h, w), bool)
    edge = np.zeros((h, w), bool)
    for y, x in zip(*np.nonzero(op)):
        hue, l, ch = hlc(tuple(int(v) for v in f[y, x, :3]))
        seed[y, x] = 15 <= hue < 75 and ch >= 0.45 and l >= 0.5
        hot[y, x] = l >= 0.78
        edge[y, x] = (hue < 20 or hue >= 350) and ch >= 0.35 and l >= 0.3
    lab, sizes = components(seed)
    m = np.zeros((h, w), bool)
    for k in range(1, len(sizes)):
        if sizes[k] >= SEED_MIN:
            m |= lab == k
    for ring in range(max(HOT_RINGS, EDGE_RINGS)):
        grow = np.zeros_like(m)
        grow[1:] |= m[:-1]
        grow[:-1] |= m[1:]
        grow[:, 1:] |= m[:, :-1]
        grow[:, :-1] |= m[:, 1:]
        grow[1:, 1:] |= m[:-1, :-1]
        grow[1:, :-1] |= m[:-1, 1:]
        grow[:-1, 1:] |= m[1:, :-1]
        grow[:-1, :-1] |= m[1:, 1:]
        ok = np.zeros_like(m)
        if ring < HOT_RINGS:
            ok |= hot
        if ring < EDGE_RINGS:
            ok |= edge | seed
        m |= grow & ok & op
    # 심 채우기: 마스크에 8방향으로 이어진 뜨거운 심(흰빛·옅은 노랑)은 몇 겹이든 (slam 남 3번 불기둥의 큰 흰 심)
    if m.any():
        lab, _ = components((hot & op) | m)
        keep = np.unique(lab[m])
        m |= np.isin(lab, keep[keep > 0]) & hot
    lab, sizes = components(m)
    for k in range(1, len(sizes)):
        if sizes[k] < FIRE_MIN:
            m[lab == k] = False
    # 불 조각: 씨앗에서 먼 붉은 불 고리·불 꼬리. 붉은·주황 불빛 덩어리 중 FLAME_BIT_MIN px 이상이고 1/3 이상이 투명에 닿는 것
    # (몸의 붉은 장식은 원본 외곽선 안에 있어 투명에 닿지 않는다)
    hotc = np.zeros((h, w), bool)
    for y, x in zip(*np.nonzero(op & ~m)):
        hue, l, ch = hlc(tuple(int(v) for v in f[y, x, :3]))
        hotc[y, x] = (hue < 40 or hue >= 340) and ch >= 0.35 and l >= 0.3
    p = np.pad(op, 1)
    touch = op & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    lab, sizes = components(hotc)
    for k in range(1, len(sizes)):
        part = lab == k
        if sizes[k] >= FLAME_BIT_MIN and 3 * int((part & touch).sum()) >= sizes[k]:
            m |= part
    return m


def recolour(f, fire, fams):
    """5: 묶음별 사다리. 주황 불빛(ember, 색상 < 40°)은 밝은 빨강·주황(피빛 중 HLS 밝기 >= 0.4, 채도 >= 0.45 포함)과
    8방향으로 이어진 덩어리가 EMBER_MAX px 이하일 때만 #ff7a1a (눈·가슴 보석). 더 크면 옷의 붉은 장식 줄이라 피빛 사다리로
    (사망 동의 로브 장식 줄이 눈과 같은 raw 주황 #e6541a로 그려져 있다)"""
    out = np.zeros_like(f)
    pts = list(zip(*np.nonzero(f[..., 3] > 0)))
    got = {}
    warm = np.zeros(f.shape[:2], bool)
    orange = np.zeros(f.shape[:2], bool)
    for y, x in pts:
        c = tuple(int(v) for v in f[y, x, :3])
        fam, col = map_colour(c, bool(fire[y, x]))
        got[(y, x)] = (c, fam, col)
        if fam == "ember" or fam == "blood":
            hue, l, ch = hlc(c)
            orange[y, x] = fam == "ember" and hue < 40
            warm[y, x] = orange[y, x] or (fam == "blood" and l >= 0.4 and ch >= 0.45)
    lab, sizes = components(warm)
    for y, x in pts:
        c, fam, col = got[(y, x)]
        if orange[y, x] and sizes[lab[y, x]] > EMBER_MAX:
            fam, col = "blood", nearest("blood", c)
        out[y, x, :3] = col
        out[y, x, 3] = 255
        fams[fam] += 1
    return out


def make_charge(raw, log):
    """시전 동쪽 예고 두 장 (CHARGE): hurt_v3 동 1번의 불 줄기를 뿌리 둘레 반지름 r 안으로 줄인다 (raw 좌표, 손으로 정한 표)"""
    clip, d, i = CHARGE_FROM
    src = raw[(clip, d)][i].copy()
    drop_specks(src)
    fire = fire_mask(src)
    out = []
    rx, ry = CHARGE_ROOT
    for r in CHARGE_RADII:
        f = src.copy()
        ys, xs = np.nonzero(fire)
        x0, y0, x1, y1 = CHARGE_BOX
        far = ((xs - rx) ** 2 + (ys - ry) ** 2 > r * r) & (xs >= x0) & (xs <= x1) & (ys >= y0) & (ys <= y1)
        f[ys[far], xs[far]] = 0
        log.append(f"charge r {r}: {int(far.sum())} jet px of {clip} {d} {i} removed")
        out.append(f)
    return out


def clean_raw(raw, log):
    """1~5: 손질한 raw 프레임과 불꽃 마스크 {(clip, dir): [(frame, fire), ...]}"""
    fams = Counter()
    out = {}
    for (clip, d), frames in raw.items():
        res = []
        for i, f in enumerate(frames):
            f = f.copy()
            tag = f"{clip} {d} {i}"
            boxes = ERASE.get((clip, d, i))
            if boxes:
                log.append(f"{tag}: erased {erase(f, boxes)} px (ERASE {boxes})")
            if (clip, d, i) in SHAFT:
                src_i, (x0, y0, x1, y1), (ox, oy) = SHAFT[(clip, d, i)]
                src = frames[src_i]
                n = 0
                for y in range(y0, y1 + 1):
                    for x in range(x0, x1 + 1):
                        if src[y, x, 3]:
                            n += int(f[y + oy, x + ox, 3] == 0 or (f[y + oy, x + ox] != src[y, x]).any())
                            f[y + oy, x + ox] = src[y, x]
                log.append(f"{tag}: SHAFT {n} px changed, frame {src_i} box {(x0, y0, x1, y1)} moved {(ox, oy)}")
            if (clip, d, i) in FLAME:
                src_i, (x0, y0, x1, y1) = FLAME[(clip, d, i)]
                src = frames[src_i].copy()
                drop_specks(src)
                sm = fire_mask(src)
                sel = np.zeros_like(sm)
                sel[y0:y1 + 1, x0:x1 + 1] = True
                sel &= sm & (f[..., 3] == 0)
                f[sel] = src[sel]
                log.append(f"{tag}: FLAME {int(sel.sum())} fire px of frame {src_i} pasted in {(x0, y0, x1, y1)}")
            box = DETACHED.get((clip, d, i))
            if box:
                n = sum(drop_detached(f, b) for b in (box if isinstance(box, list) else [box]))
                log.append(f"{tag}: detached {n} px removed in {box}")
            n = drop_specks(f)
            if n:
                log.append(f"{tag}: {n} speck px removed")
            fire = fire_mask(f)
            res.append((recolour(f, fire, fams), fire))
        out[(clip, d)] = res
    log.append("colour families (px over every raw frame): " + ", ".join(f"{k} {v}" for k, v in fams.most_common()))
    return out


# =====================================================================================
# 6~8 칸
# =====================================================================================
def bottom(a):
    return int(np.nonzero(a[..., 3] > 0)[0].max())


def top(a):
    return int(np.nonzero(a[..., 3] > 0)[0].min())


def centroid_x(a):
    return float(np.nonzero(a[..., 3] > 0)[1].mean())


def body_centroid_x(a, fire, d, ox=0):
    """몸 무게중심 x: 가장 낮은 픽셀에서 위로 BODY_ROWS줄의 불꽃 아닌 픽셀, STAFF_CUT 열(raw x + ox)은 뺌"""
    op = (a[..., 3] > 0) & ~fire
    ys, xs = np.nonzero(op)
    sel = ys > ys.max() - BODY_ROWS
    cut = STAFF_CUT[d]
    if cut:
        sel &= (xs > cut[1] + ox) if cut[0] == ">" else (xs < cut[1] + ox)
    return float(xs[sel].mean())


def place(f, fire, W, H, ox, oy, tag):
    out = np.zeros((H, W, 4), np.uint8)
    fo = np.zeros((H, W), bool)
    ys, xs = np.nonzero(f[..., 3] > 0)
    if not (xs.min() + ox >= 0 and xs.max() + ox < W and ys.min() + oy >= 0 and ys.max() + oy < H):
        raise SystemExit(f"{tag}: leaves the {W}x{H} cell (x {xs.min() + ox}..{xs.max() + ox}, y {ys.min() + oy}..{ys.max() + oy})")
    out[ys + oy, xs + ox] = f[ys, xs]
    fo[ys + oy, xs + ox] = fire[ys, xs]
    return out, fo


def locate(big, small):
    H, W = big.shape[:2]
    h, w = small.shape[:2]
    so = small[..., 3] > 0
    for y in range(H - h + 1):
        for x in range(W - w + 1):
            win = big[y:y + h, x:x + w]
            if np.array_equal(win[..., 3] > 0, so) and np.array_equal(win[..., :3][so], small[..., :3][so]):
                return x, y
    raise SystemExit("start frame not found in the v3 frame 0")


def tip_fix(cell, fire, raw_top, log, tag):
    """7: raw 윗줄(y=0)에 닿아 잘린 두건. cell 좌표에서 그 줄(raw_top)의 불꽃 아닌 덩어리 위에 한 줄을 더한다"""
    row = cell[raw_top]
    op = (row[:, 3] > 0) & ~fire[raw_top]
    xs = np.nonzero(op)[0]
    if not len(xs) or raw_top == 0:
        return 0
    runs, start = [], xs[0]
    for a, b in zip(xs, xs[1:]):
        if b != a + 1:
            runs.append((start, a))
            start = b
    runs.append((start, xs[-1]))
    added = 0
    for x0, x1 in runs:
        n = x1 - x0 + 1
        if n < 3:
            continue
        # 두건이 기운 쪽: 그 아래 4줄의 덩어리 가운데가 어느 쪽으로 가는지(위로 갈수록 오른쪽이면 +)
        below = [np.nonzero((cell[raw_top + k, x0:x1 + 1, 3] > 0))[0] for k in range(1, 5)]
        mids = [x0 + b.mean() for b in below if len(b)]
        lean = 1 if mids and (x0 + x1) / 2 - np.mean(mids) > 0.25 else (-1 if mids and (x0 + x1) / 2 - np.mean(mids) < -0.25 else 0)
        a0, a1 = x0 + 1 + max(lean, 0), x1 - 1 + min(lean, 0)
        if a1 < a0:
            continue
        # 새 줄의 색: 아래 줄의 같은 x 색 (외곽선이면 그 아래)
        for x in range(a0, a1 + 1):
            c = cell[raw_top, x]
            if tuple(c[:3]) == OUT and cell[raw_top + 1, x, 3]:
                c = cell[raw_top + 1, x]
            cell[raw_top - 1, x] = c
            added += 1
    if added:
        log.append(f"{tag}: hood tip clipped at the raw top, {added} px added above")
    return added


def ground_fire(cell, fire, rawf, ox, oy, floor):
    """땅의 불 (GROUND): 칸의 발 줄(floor) 아래 불꽃 아닌 픽셀 중 raw 색(같은 raw 자리, rawf)이 불빛인 것을 불꽃으로 (마스크에 넣고
    FIRE_BANDS 색으로). 칸 좌표 = raw 좌표 + (ox, oy)"""
    n = 0
    ys, xs = np.nonzero((cell[..., 3] > 0) & ~fire)
    for y, x in zip(ys, xs):
        if y <= floor:
            continue
        c = tuple(int(v) for v in rawf[y - oy, x - ox, :3])
        hue, l, ch = hlc(c)
        if (hue < 75 or hue >= 340) and ch >= GROUND_CH and l >= GROUND_L:
            fire[y, x] = True
            cell[y, x, :3] = fire_colour(c)
            n += 1
    return n


def outline(cell, fire, floor):
    out = cell.copy()
    op = cell[..., 3] > 0
    h, w = op.shape
    add, recol = set(), []
    for y, x in zip(*np.nonzero(op)):
        if fire[y, x]:
            continue
        c = tuple(int(v) for v in cell[y, x, :3])
        if c == OUT:
            continue
        outside, border = [], False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if not (0 <= xx < w and 0 <= yy < h) or (yy > floor and not op[yy, xx]):
                border = True
            elif not op[yy, xx]:
                outside.append((xx, yy))
        if not outside and not border:
            continue
        if lstar(c) < DARK_L or border:
            recol.append((x, y))
        else:
            add.update(outside)
    for x, y in recol:
        out[y, x, :3] = OUT
    for x, y in add:
        out[y, x] = (*OUT, 255)
    return out, len(recol), len(add)


def edge_stats(cell, fire):
    op = cell[..., 3] > 0
    p = np.pad(op, 1)
    edge = op & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]) & ~fire
    bad = edge & np.any(cell[..., :3] != OUT, axis=2)
    return int(edge.sum()), int(bad.sum())


def build(cleaned, raw, log, columns):
    """columns = COLUMNS (v02) 또는 COLUMNS_V03"""
    W, H = BODY
    floor = H - 1
    axis = (W - 1) / 2
    # 6 가로 맞춤: 걷기 6장의 몸(body_centroid_x: 로브 아랫부분, 지팡이 열 뺌) 무게중심 평균을 축에
    dx = {}
    for d in DIRS:
        cs = [body_centroid_x(f, fire, d) for f, fire in cleaned[("walk", d)]]
        dx[d] = int(round(axis - sum(cs) / len(cs)))
        log.append(f"body centroid (raw x) walk {d}: {[round(c, 2) for c in cs]}, mean {sum(cs) / len(cs):.2f}")
    # 걷기 세로 (v3 시작 그림 자리의 기준)
    # 걷기 세로는 아래 몸 칸 동작에서(모든 프레임 중 가장 낮은 픽셀). 시작 그림(걷기 첫 프레임)은 따로 그 발을 칸 맨 아래 줄에:
    # v3 프레임(공격·시전·피격 북)과 첫 열은 이 자리라 발 줄이 모든 시트에서 같다. 북은 걷기 템플릿이 1·2번 디딤발을
    # 2px 아래로 그려 걷기 시트의 0번이 이보다 2px 위에 있다 (남·동은 같은 자리)
    key_dy = {d: floor - bottom(cleaned[("walk", d)][0][0]) for d in DIRS}
    log.append(f"DX (cell x = raw x + DX): {dx}; start picture DY: {key_dy}")

    sheets, fires, info = {}, {}, {}
    stats = Counter()

    def finish(cell, fire, tag, raw_top=None):
        if raw_top is not None:
            stats["tip"] += tip_fix(cell, fire, raw_top, log, tag)
        # 발 줄: 몸 칸 H-1, 동작 칸 ACT_AT[1] + H-1
        g, recol, added = outline(cell, fire, floor if cell.shape[0] == H else ACT_AT[1] + floor)
        stats["recol"] += recol
        stats["added"] += added
        return g, fire

    # 손질한 걷기 첫 프레임 (몸 칸, 외곽선까지). v3 첫 열과 끝 그림
    key = {}
    for d in DIRS:
        f, fire = cleaned[("walk", d)][0]
        c, fo = place(f, fire, W, H, dx[d], key_dy[d], f"key {d}")
        key[d] = finish(c, fo, f"key {d}", key_dy[d] if top(f) == 0 else None)

    # --- 몸 칸 동작
    for anim in BODY_ANIMS:
        rows, frows = [], []
        for d in DIRS:
            cols = columns[anim][d]
            # v3 줄: 시작 그림(KEY)이 아닌 첫 열의 판이 템플릿이 아니면 (피격 북, v03 사망 남은 첫 열이 KEY)
            clip = next(c_ for c_, _ in cols if c_ != "key")
            is_v3 = clip not in TEMPLATES
            srcs = None if is_v3 else [cleaned[(c_, d)][i] for c_, i in cols]
            out, fout = [], []
            if is_v3:
                # v3 (피격 북, v03 사망 남): 걷기 첫 프레임 자리로. KEY 열은 손질한 걷기 첫 프레임.
                # 칸 밖(맨 아래 줄 아래)으로 나가는 프레임만 그 가장 낮은 픽셀이 맨 아래 줄에 오게 올린다 (템플릿과 같은 규칙)
                sx, sy = locate(raw[(clip, d)][0], raw[("walk", d)][0])
                ox, oy = dx[d] - sx, key_dy[d] - sy
                dys = []
                for c_, i in cols:
                    if c_ == "key":
                        g, fo = key[d][0].copy(), key[d][1].copy()
                        dys.append(None)
                    else:
                        f, fire = cleaned[(c_, d)][i]
                        dy = min(oy, floor - bottom(f))
                        dys.append(dy)
                        c, fo = place(f, fire, W, H, ox, dy, f"{anim} {d} {c_} {i}")
                        g, fo = finish(c, fo, f"{anim} {d} {c_} {i}")
                    out.append(g)
                    fout.append(fo)
                info[(anim, d)] = f"{clip} start picture at ({sx}, {sy}), cell offset ({ox}, {oy}), DY per column {dys}"
            else:
                if anim in ("walk", "idle"):
                    dys = [floor - max(bottom(f) for f, _ in srcs)] * len(srcs)
                else:
                    base = floor - bottom(srcs[0][0])
                    dys = [min(base, floor - bottom(f)) for f, _ in srcs]
                for (c_, i), (f, fire), dy in zip(cols, srcs, dys):
                    c, fo = place(f, fire, W, H, dx[d], dy, f"{anim} {d} {i}")
                    g, fo = finish(c, fo, f"{anim} {d} {i}", dy if top(f) == 0 else None)
                    out.append(g)
                    fout.append(fo)
                info[(anim, d)] = f"DY {dys}"
            rows.append(out)
            frows.append(fout)
        sheets[anim], fires[anim] = rows, frows

    # --- 동작 칸 (공격·시전): 몸 칸 좌표 + ACT_AT
    AW, AH = ACT
    ax, ay = ACT_AT
    for anim in ACTIONS:
        rows, frows = [], []
        for d in DIRS:
            out, fout = [], []
            for clip, i in columns[anim][d]:
                if clip == "key":
                    g = np.zeros((AH, AW, 4), np.uint8)
                    fo = np.zeros((AH, AW), bool)
                    g[ay:ay + H, ax:ax + W] = key[d][0]
                    fo[ay:ay + H, ax:ax + W] = key[d][1]
                else:
                    sx, sy = locate(raw[(PLACE_AS.get(clip, clip), d)][0], raw[("walk", d)][0])
                    f, fire = cleaned[(clip, d)][i]
                    ox, oy = ax + dx[d] - sx, ay + key_dy[d] - sy
                    c, fo = place(f, fire, AW, AH, ox, oy, f"{anim} {d} {clip} {i}")
                    n = ground_fire(c, fo, raw[(clip, d)][i], ox, oy, ay + floor)
                    if n:
                        stats["ground"] += n
                        log.append(f"{anim} {d} {clip} {i}: {n} px under the feet line made fire (GROUND)")
                    g, fo = finish(c, fo, f"{anim} {d} {clip} {i}")
                    info[(anim, d, clip)] = f"start picture at ({sx}, {sy}) in the {clip} canvas"
                out.append(g)
                fout.append(fo)
            rows.append(out)
            frows.append(fout)
        sheets[anim], fires[anim] = rows, frows

    # --- 회전 (남·동·북 + 서 = 동 반전)
    rot, rfire = [], []
    for r, d in enumerate(DIRS):
        f, fire = cleaned[("rot", "all")][r]
        c, fo = place(f, fire, W, H, dx[d], floor - bottom(f), f"rotation {d}")
        g, fo = finish(c, fo, f"rotation {d}")
        rot.append(g)
        rfire.append(fo)
    rot.append(rot[1][:, ::-1].copy())
    rfire.append(rfire[1][:, ::-1].copy())
    sheets["rotations"], fires["rotations"] = [rot], [rfire]
    log.append(f"outline: {stats['recol']} edge px recoloured, {stats['added']} px added outside; hood tips +{stats['tip']} px; "
               f"ground fire +{stats['ground']} px")
    return sheets, fires, info, dx


def sheet_of(rows):
    h, w = rows[0][0].shape[:2]
    out = np.zeros((h * len(rows), w * len(rows[0])) + rows[0][0].shape[2:], rows[0][0].dtype)
    for r, frames in enumerate(rows):
        for c, f in enumerate(frames):
            out[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    return out


def emissive_of(sheet, fire):
    e = np.zeros(sheet.shape, np.uint8)
    for y, x in zip(*np.nonzero(fire)):
        c = tuple(int(v) for v in sheet[y, x, :3])
        v = EMISSIVE[c]
        e[y, x] = (v, v, v, 255)
    return e


# =====================================================================================
# 미리보기 · 검사
# =====================================================================================
def to_action(f):
    """몸 칸 그림을 동작 칸(ACT_AT)에"""
    if f.shape[:2] == (ACT[1], ACT[0]):
        return f
    g = np.zeros((ACT[1], ACT[0], 4), np.uint8)
    g[ACT_AT[1]:ACT_AT[1] + BODY[1], ACT_AT[0]:ACT_AT[0] + BODY[0]] = f
    return g


def gif_frame_at(sheets, anim, row, tick, hit=HIT_COLUMN):
    frames = sheets[anim][row]
    first = 1 if anim in ACTIONS else 0
    seq = frames[first:]
    n = len(seq)
    per = GIF_TICKS[anim]
    if anim in ACTIONS:
        pre = hit[anim][DIRS[row]] - first
        blow = GIF_TELEGRAPH[anim]
        t = tick % GIF_ACT_SPAN
        i = min(t // per, max(pre - 1, 0)) if t < blow else min(pre + (t - blow) // per, n - 1)
        return seq[i], first + i
    span = n * per + GIF_HOLD.get(anim, 0)
    t = tick % span
    return seq[min(t // per, n - 1)], (first + min(t // per, n - 1))


def anims_gif(sheets, ver="v02", hit=HIT_COLUMN):
    """ver = 파일 이름의 판(v02 / v03), hit = 예고 붙잡기의 맞는 열 표 (HIT_COLUMN / HIT_COLUMN_V03)"""
    order = ("idle", "walk", "attack", "cast", "hurt", "death")
    for anim in order:
        if anim in ACTIONS:
            for d in DIRS:
                pre = hit[anim][d] - 1
                assert GIF_TELEGRAPH[anim] + (len(sheets[anim][0]) - 1 - pre) * GIF_TICKS[anim] <= GIF_ACT_SPAN, (anim, d)
            span = GIF_ACT_SPAN
        else:
            span = len(sheets[anim][0]) * GIF_TICKS[anim] + GIF_HOLD.get(anim, 0)
        assert GIF_LOOP % span == 0, (anim, span)
    AW, AH = ACT
    k = GIF_SCALE
    states, frames = [], []
    for tick in range(GIF_LOOP):
        st = tuple(gif_frame_at(sheets, a, min(r, 2) if r < 3 else 1, tick, hit)[1] for a in order for r in range(4))
        if states and st == states[-1][1]:
            continue
        states.append((tick, st))
    for n, (tick, st) in enumerate(states):
        canvas = np.zeros((4 * AH, len(order) * AW, 4), np.uint8)
        canvas[:] = BG
        for c, anim in enumerate(order):
            for r in range(4):
                src = 1 if r == 3 else r
                f, _ = gif_frame_at(sheets, anim, src, tick, hit)
                f = to_action(f)
                if r == 3:
                    f = f[:, ::-1]
                blk = canvas[r * AH:(r + 1) * AH, c * AW:(c + 1) * AW]
                m = f[..., 3] > 0
                blk[m] = f[m]
        im = Image.fromarray(canvas).convert("RGB").resize((canvas.shape[1] * k, canvas.shape[0] * k), Image.NEAREST)
        frames.append(im.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    # 틱 -> ms (60틱/초), 10ms 단위로 반올림한 누적 시각의 차 (쌓인 오차가 5ms를 넘지 않음)
    ms = [int(round(t * 1000 / 60 / 10)) * 10 for t, _ in states] + [int(round(GIF_LOOP * 1000 / 60 / 10)) * 10]
    durs = [b - a for a, b in zip(ms, ms[1:])]
    frames[0].save(os.path.join(PIX, f"{NAME}_{ver}_anims.gif"), save_all=True, append_images=frames[1:], duration=durs,
                   loop=0, disposal=1, optimize=False)
    print(f"wrote {NAME}_{ver}_anims.gif {frames[0].width} x {frames[0].height}, {len(frames)} frames, "
          f"{GIF_LOOP} ticks = {sum(durs)} ms, frame times {sorted(set(durs))} ms")


def scale_check(sheets):
    """위 1배 띠(남 줄, 동 줄), 아래 4배 두 줄(남, 동). 칸마다 기본 몸 · 이단 · 상인 · 보스 idle 첫 프레임, 빨간 선 = 발 줄"""
    others = [load("base_body_v02_idle.png"), load("heretic_v02_idle.png"), load("merchant_v02_idle.png")]
    gap = 4
    rows = []
    for r in range(2):
        cells = [o[r * 32:(r + 1) * 32, 0:32] for o in others] + [sheets["idle"][r][0]]
        rows.append(cells)
    Hmax = max(c.shape[0] for c in rows[0])
    w_row = sum(c.shape[1] + gap for c in rows[0])
    big = 4
    w1 = w_row * 2 + gap * 4
    w4 = w_row * big
    Wt = max(w1, w4)
    Ht = Hmax + gap + (Hmax * big + gap * big) * 2
    im = Image.new("RGBA", (Wt, Ht), CHECK_BG)
    d = ImageDraw.Draw(im)
    x = 0
    for cells in rows:
        for c in cells:
            im.alpha_composite(Image.fromarray(np.ascontiguousarray(c)), (x, Hmax - c.shape[0]))
            x += c.shape[1] + gap
        x += gap * 4
    d.line([(0, Hmax), (w1, Hmax)], fill=FEET_LINE)
    for n, cells in enumerate(rows):
        y0 = Hmax + gap + n * (Hmax * big + gap * big)
        x = 0
        for c in cells:
            img = Image.fromarray(np.ascontiguousarray(c)).resize((c.shape[1] * big, c.shape[0] * big), Image.NEAREST)
            im.alpha_composite(img, (x, y0 + (Hmax - c.shape[0]) * big))
            x += (c.shape[1] + gap) * big
        d.line([(0, y0 + Hmax * big), (w4, y0 + Hmax * big)], fill=FEET_LINE)
    im.save(os.path.join(PIX, f"{NAME}_v02_scale_check.png"))
    print(f"wrote {NAME}_v02_scale_check.png", Wt, "x", Ht)


def size_of(a, fire=None):
    op = a[..., 3] > 0
    if fire is not None:
        op = op & ~fire
    ys, xs = np.nonzero(op)
    return int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1), int(ys.min()), int(ys.max())


def report(log, sheets, fires, info, dx, ver="v02", names=BODY_ANIMS + ACTIONS + ("rotations",)):
    for line in log:
        print(line)
    for k, v in info.items():
        print("placement", k, v)
    for name in names:
        sheet = sheet_of(sheets[name])
        fire = sheet_of(fires[name])
        cs = {tuple(int(v) for v in p[:3]) for p in sheet.reshape(-1, 4) if p[3]}
        assert cs <= PALETTE, (name, sorted(cs - PALETTE))
        assert not ((sheet[..., 3] > 0) & (sheet[..., 3] < 255)).any()
        cold = [c for c in cs if sum(c) < 200 and c[2] > c[0] + 5]
        edge, bad = edge_stats(sheet, fire)
        print(f"{NAME}_{ver}_{name}.png {sheet.shape[1]}x{sheet.shape[0]}: {len(cs)} colours, dark B > R+5: "
              f"{['#%02x%02x%02x' % c for c in cold]}, silhouette edge px (not fire) {edge}, not outline {bad}, "
              f"fire px {int(fire.sum())}")
    print("size px per anim and direction (whole picture W x H range | without fire H range | feet row per frame)")
    for name in names:
        for r, frames in enumerate(sheets[name]):
            d = ROT_DIRS[r] if name == "rotations" else DIRS[r]
            ss = [size_of(f) for f in frames]
            sn = [size_of(f, fo) for f, fo in zip(frames, fires[name][r])]
            fl = [bottom(f) for f in frames]
            if name == "rotations":
                for i, (s, s2) in enumerate(zip(ss, sn)):
                    print(f"  rotations {ROT_DIRS[i]}: {s[0]}x{s[1]} (top y{s[2]}, bottom y{s[3]}), without fire H {s2[1]}")
                break
            print(f"  {name} {d}: W {min(s[0] for s in ss)}~{max(s[0] for s in ss)}, H {min(s[1] for s in ss)}~"
                  f"{max(s[1] for s in ss)} | no-fire H {min(s[1] for s in sn)}~{max(s[1] for s in sn)} | feet/lowest {fl}")
            cx = [round(centroid_x(f), 1) for f in frames]
            print(f"      centroid x {cx}")
            if name in ("idle", "walk"):
                # 몸만 (지팡이 열 STAFF_CUT을 칸 좌표로 옮겨 뺌): 폭, 몸 무게중심(가로 맞춤과 같은 잼, 축 27.5)
                bw, bc = [], []
                for f, fo in zip(frames, fires[name][r]):
                    op = (f[..., 3] > 0) & ~fo
                    ys, xs = np.nonzero(op)
                    cut = STAFF_CUT[d]
                    if cut:
                        xs = xs[(xs > cut[1] + dx[d]) if cut[0] == ">" else (xs < cut[1] + dx[d])]
                    bw.append(int(xs.max() - xs.min() + 1))
                    bc.append(round(body_centroid_x(f, fo, d, dx[d]), 1))
                print(f"      body only (staff columns cut): W {min(bw)}~{max(bw)}, body centroid x {bc}")
    # 칸에 얼마나 여유가 있는지
    for name in [n for n in names if n not in ACTIONS]:
        H, W = BODY[1], BODY[0]
        xs0 = min(np.nonzero(f[..., 3] > 0)[1].min() for row in sheets[name] for f in row)
        xs1 = max(np.nonzero(f[..., 3] > 0)[1].max() for row in sheets[name] for f in row)
        ys0 = min(np.nonzero(f[..., 3] > 0)[0].min() for row in sheets[name] for f in row)
        print(f"  {name}: used x {xs0}..{xs1} of 0..{W - 1}, top y {ys0} of {H}")
    for name in ACTIONS:
        xs0 = min(np.nonzero(f[..., 3] > 0)[1].min() for row in sheets[name] for f in row)
        xs1 = max(np.nonzero(f[..., 3] > 0)[1].max() for row in sheets[name] for f in row)
        ys0 = min(np.nonzero(f[..., 3] > 0)[0].min() for row in sheets[name] for f in row)
        ys1 = max(np.nonzero(f[..., 3] > 0)[0].max() for row in sheets[name] for f in row)
        print(f"  {name}: used x {xs0}..{xs1} of 0..{ACT[0] - 1}, y {ys0}..{ys1} of 0..{ACT[1] - 1}, "
              f"feet line y {ACT_AT[1] + BODY[1] - 1}")


# v03에서 바뀐 줄 (시트, 줄 번호) = COLUMNS_V03이 COLUMNS와 다른 줄. 나머지 줄은 v02와 픽셀까지 같아야 한다 (check_v03이 저장 전에 확인)
CHANGED_V03 = tuple((name, r) for name in BODY_ANIMS + ACTIONS for r, d in enumerate(DIRS) if COLUMNS_V03[name][d] != COLUMNS[name][d])
TALLEST_PX = 45   # 게임 BossView.TALLEST_PX: 판정 상자 높이 45가 기대는 가장 큰 그림. 어느 그림도 이보다 크면 안 된다


def check_v03(sheets2, fires2, sheets3, fires3):
    """v03을 저장하기 전: 바뀌지 않은 줄 = v02 (픽셀까지), 바뀐 줄은 다름, 가장 큰 그림 <= TALLEST_PX. 어긋나면 v03 파일을 쓰지 않고 멈춘다(v02 16개와 GIF·scale_check는 그 전에 이미 씀)"""
    print(f"v03 changed rows (COLUMNS_V03 vs COLUMNS): {[(name, DIRS[r]) for name, r in CHANGED_V03]}")
    for name in BODY_ANIMS + ACTIONS:
        for r in range(len(DIRS)):
            same = (all(np.array_equal(a, b) for a, b in zip(sheets2[name][r], sheets3[name][r]))
                    and all(np.array_equal(a, b) for a, b in zip(fires2[name][r], fires3[name][r])))
            assert same == ((name, r) not in CHANGED_V03), (name, DIRS[r], same)
    print("v03: every row not in CHANGED_V03 is pixel-identical to v02 (sheet and fire mask)")
    tallest = 0
    for name in BODY_ANIMS + ACTIONS:
        feet = (ACT_AT[1] if name in ACTIONS else 0) + BODY[1]      # 게임의 feet_in_cell y (발 줄 + 1)
        for r in range(len(DIRS)):
            for f in sheets3[name][r]:
                tallest = max(tallest, feet - top(f))
    print(f"v03 tallest picture (feet + 1 - top, fire included) over the six sheets: {tallest} px (limit {TALLEST_PX})")
    assert tallest <= TALLEST_PX, tallest


def report_v03(sheets2, fires2, sheets3, fires3):
    """v03: 바뀐 줄의 열마다 키(게임처럼 발 + 1 - 맨 위 줄, 불 포함)·폭·맨 아래 줄·불꽃 px·불꽃 덩어리 수·떨어진 덩어리,
    맞는 열 후보의 붙잡는 열·타격 열이 공격과 시전에서 다른 픽셀 수(게임 시험은 150 초과)"""
    for name, r in CHANGED_V03:
        feet = (ACT_AT[1] if name in ACTIONS else 0) + BODY[1]
        print(f"  v03 {name} {DIRS[r]} per column: height / width / lowest row / fire px / fire blobs (8-way) / detached parts "
              f"(8-way, besides the body)")
        for c, (f, fo) in enumerate(zip(sheets3[name][r], fires3[name][r])):
            op = f[..., 3] > 0
            ys, xs = np.nonzero(op)
            lab, sizes = components(op)
            main = int(np.argmax(sizes))
            det = [sizes[k] for k in range(1, len(sizes)) if k != main]
            print(f"    col {c}: H {feet - top(f)}  W {int(xs.max() - xs.min() + 1)}  lowest y {bottom(f)} (feet row {feet - 1})  "
                  f"fire {int(fo.sum())}  fire blobs {components(fo)[1][1:]}  detached {det}")
    for name in ACTIONS:
        for r, d in enumerate(DIRS):
            h = HIT_COLUMN_V03[name][d]
            key = sheets3[name][r][0]
            print(f"  v03 {name} {d}: hit column {h}, held column {h - 1} differs from the start picture by "
                  f"{int(np.any(sheets3[name][r][h - 1] != key, axis=2).sum())} px (v02 held {HIT_COLUMN[name][d] - 1}: "
                  f"{int(np.any(sheets2[name][r][HIT_COLUMN[name][d] - 1] != sheets2[name][r][0], axis=2).sum())} px)")
    for r, d in enumerate(DIRS):
        for k, what in ((0, "held"), (1, "blow")):
            ca = HIT_COLUMN_V03["attack"][d] - 1 + k
            cc = HIT_COLUMN_V03["cast"][d] - 1 + k
            n = int(np.any(sheets3["attack"][r][ca] != sheets3["cast"][r][cc], axis=2).sum())
            print(f"  v03 {d} {what}: attack column {ca} vs cast column {cc} differ by {n} px (game test: > 150)")


def main(argv):
    if argv and argv[0] == "raw":
        pack_raw(argv[1])
        return
    log = []
    raw = load_raw()
    # 회전은 걷기와 따로 (방향 줄이 없는 묶음): 남·동·북만
    raw_rot = raw.pop(("rot", "all"))
    raw[("charge", "east")] = make_charge(raw, log)
    cleaned = clean_raw(raw, log)
    rot_clean = clean_raw({("rot", "all"): raw_rot[:3]}, log)
    cleaned[("rot", "all")] = rot_clean[("rot", "all")]
    sheets, fires, info, dx = build(cleaned, raw, log, COLUMNS)
    for name in BODY_ANIMS + ACTIONS + ("rotations",):
        sheet = sheet_of(sheets[name])
        save(sheet, f"{NAME}_v02_{name}.png")
        save(emissive_of(sheet, sheet_of(fires[name])), f"{NAME}_v02_{name}_emissive.png")
    anims_gif(sheets)
    scale_check(sheets)
    # v03: 같은 손질 결과(cleaned)에서 COLUMNS_V03으로. 회전·scale_check는 v02 그대로라 쓰지 않는다
    log3 = []
    sheets3, fires3, info3, _ = build(cleaned, raw, log3, COLUMNS_V03)
    check_v03(sheets, fires, sheets3, fires3)
    for name in BODY_ANIMS + ACTIONS:
        sheet = sheet_of(sheets3[name])
        save(sheet, f"{NAME}_v03_{name}.png")
        save(emissive_of(sheet, sheet_of(fires3[name])), f"{NAME}_v03_{name}_emissive.png")
    anims_gif(sheets3, "v03", HIT_COLUMN_V03)
    report(log, sheets, fires, info, dx)
    print("=== v03")
    report(log3, sheets3, fires3, info3, dx, "v03", BODY_ANIMS + ACTIONS)
    report_v03(sheets, fires, sheets3, fires3)


if __name__ == "__main__":
    main(sys.argv[1:])
