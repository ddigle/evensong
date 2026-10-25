# Evensong 게임 프로젝트 (Godot 4.7.2)

수직 슬라이스를 만드는 진짜 게임 폴더다 (`prototypes/engine-spike/`는 버리는 시험이고, 여기 코드는 새로 짰다).
지금은 **M1 "첫 단계: 이동 · 타일 · 제단 빛 · 2인 접속"**의 세 단계 G1(뼈대 + 월드), G2(캐릭터 + 빛), G3(2인 네트워크)가 모두 들어 있고, 검증에서 나온 지적을 반영했다. 그 위에 H1(다지기: 늦은 참가 = 월드 스냅샷, 호스트가 정하는 바라보기, 호스트 멈춤 뒤 입력 따라잡기, 테스트 기반, 제단 옆 겹침, 내 캐릭터를 틱 사이에 그리기, `session.gd` 나누기)을 더했고, H1 검토 지적을 반영했다(H-fix: 실제 세션에서 듣지 않던 호스트 멈춤 따라잡기를 고침, 테스트 포트 확인을 IPv4까지, 세션 시험 `stall` 추가 등. [검토 반영 (H-fix)](#검토-반영-h-fix-2026-10-22)). 단계 상태와 알려진 문제는 [맨 아래](#m1-범위와-단계-상태).
그 위에 **M2a "아이템 · 핫바 · 마우스 조준 · 몸 동작"**(혼자 할 때 먼저)을 더했다: 타입 있는 아이템 표(도구 6 · 재료 1 · 채집물 15), 플레이어마다 인벤토리 + 핫바, 마우스 조준(바라보기와 목표 칸, 칸 표시), 도구를 들고 좌클릭하면 그 도구의 몸 동작(64칸 동작 시트를 발에 맞춰, 손에 든 표식은 숨기고 나머지 표식은 레이어로, ● R25~R27), 최소 HUD(핫바 줄, Tab 인벤토리). 동작은 아직 월드를 바꾸지 않고 목표 칸만 알린다. [아이템 · 조준 · 동작 (M2a)](#아이템--조준--동작-m2a).
그 위에 **M2b "네트워크 + 월드"**를 더했다: M2a가 더한 것을 모두 호스트가 정한다(클라이언트는 입력 프레임에 바라보기(조준)와 요청 하나(사용 · 줍기 · 핫바 고르기 · 디버그 버리기 · 디버그 주기)를 실어 보내고, 호스트가 그 프레임의 자리에서 검사하고 적용한다. 몸 동작과 든 아이템은 상태 묶음에, 월드 변화는 번호 붙은 편집으로, 인벤토리는 호스트에 있고 주인에게만 간다. 자기 동작 시작은 이동처럼 예측한다). 지상에 시드로 채집물(야생 약초 3종 · 버섯 · 돌)을 흩고 F로 줍는다(약초사가 캐면 상급 ● §3.4), 땅에 떨어진 아이템(디버그 F7로 버리기, F로 줍기), 늦은 참가 스냅샷에 채집물과 드롭이 들어간다. [M2b: 네트워크 + 월드](#m2b-네트워크--월드). M2b 검토 지적을 반영했다(M2-fix: 타일 선 위의 발 칸, 고르기 바로잡기, 사용의 바라보기, 동작 중 표시, 클라이언트 F7·`--give`, 빠진 시험. [검토 반영 (M2-fix)](#검토-반영-m2-fix-2026-10-22)).
그 위에 **M3a "지도 · 첫 던전 · 채굴 · 횃불"**(혼자 할 때 먼저)을 더했다: 지도 번호(지상 0, 첫 던전 1)로 지도마다 WorldData와 GameWorld를 따로 두고 플레이어는 늘 한 지도에 있다. 시드로 만드는 던전(방·통로·부서지는 벽·구리/철 광맥·기반암 테두리·이단의 제단 자리·출구 계단, 04-env 절벽 타일셋을 dual grid로, 벽 앞면 24px), 지상의 던전 입구(F로 내려가고, 던전의 계단에서 F로 입구 옆으로 올라온다), 벽 충돌(벽과 그 앞면 칸), 채굴(● R11: 누구나 1×1·느리게·경도 상한, 광부 3×3·빠르게·상위 경도. 칠 때마다 쌓이는 타격, 금 3단계, 깨지면 돌·광석이 인벤토리로, 다 차면 그 칸에 드롭), 어두운 던전과 횃불(디버그로 받아 바닥 칸에 놓는 빛, 벽 횃불 장식). 세션은 지상만이다(입구는 호스트가 "dungeon offline only"로 거부, 세션 흐름은 M2b 그대로). [M3a: 지도 · 던전 · 채굴 · 횃불](#m3a-지도--던전--채굴--횃불).
그 위에 **M3b "세션의 지도"**를 더했다: M3a가 혼자 할 때 더한 것(지도 둘, 던전, 채굴, 횃불, 그 드롭)을 세션에서 모두 호스트가 정한다. 플레이어마다 지도 번호가 호스트 상태이고, 입구·계단의 F는 요청(TRAVEL)이며 호스트가 손 닿는지 보고 그 플레이어를 다른 지도의 도착점으로 옮긴다. **클라이언트는 자기가 있는 지도 하나만 갖는다**: 지도에 들어갈 때 그 지도를 늦은 참가와 같은 스냅샷 길로 받고(조각 → 지도 들어옴 메시지 → 그동안의 편집), 그 뒤로는 그 지도의 번호 붙은 편집만 받는다. 상태 묶음의 상태마다 지도 번호가 있어 자기 지도의 플레이어만 그린다. 타일을 겨누는 요청은 겨눈 지도를 함께 보내고 호스트가 다른 지도면 거부한다. 전송 형식 버전 4. [M3b: 세션의 지도](#m3b-세션의-지도). M3 검토 지적을 반영했다(M3-fix: 광부의 3×3이 출구 계단 둘레를 파던 것, 도착 방이 어둡던 벽 횃불 자리 고르기, 꽉 찬 F5 묶음, 호스트를 잃은 클라이언트의 던전·채굴, 벽 속 디버그 드롭, 빠진 시험과 README 문장. [검토 반영 (M3-fix)](#검토-반영-m3-fix-2026-10-22)).
그 위에 **M4a "체력 · 대시 · 기본 공격 · 사망 · 이단"**(혼자 할 때 먼저. 세션에서는 적·피해·대시가 아직 꺼져 있고 M2b·M3b 흐름 그대로, M4b에서 켠다)을 더했다: 공유 시뮬레이션(`PlayerSim.step`, 혼자·호스트·예측 공통)에 HP·스태미나·대시(Space, 걷기와 같은 충돌)·경직·다운·사망·부활 시간을 넣었다(`actors/vitals.gd`). 클래스마다 기본 공격 하나를 핫바 무기로(● §2.1 에임형, 좌클릭 = 든 아이템 사용 그대로): 팔라딘 검(근접 호), 아처 활(화살), 성직자 성광(마법 동작, 빛 탄, 새 아이템), 광부 곡괭이(근접. 벽을 겨누면 채굴만), 약초사 낫(근접, 임시값). 혼자 할 때 클래스 무기가 핫바 8번에 있다. 0 HP면 다운(사망 시트, 누움), 아군이 F를 누르고 있으면 소생(성직자 즉시, 다른 클래스 5초), 30초 지나면 사망(혼자면 F 1초로 포기), 사망 자리에 재료·소모품 일부가 든 가방(● §2.6, 절반 규칙, 상수 하나로 무작위 3종), 5초 뒤 제단에서 부활. 적 하나: 이단(근접, 03-pixel heretic_v02 시트 다섯, 서쪽 = 동쪽 반전): 빛 밖의 가장 가까운 플레이어를 쫓아 칼을 드는 예고 뒤 맞는 열에서 친다, 제단 빛에는 들어가지 않고 가장자리에서 4초 지켜보다 돌아간다, 오염 구역 둘레와 던전의 도착 방에서 먼 곳에 생기고 빛 안에는 생기지 않는다. 던전의 이단의 제단은 전투로 부서지고(● §3.0), 부서지면 던전 스폰이 멈춘다. 최소 HUD(HP·스태미나 막대, 다운·소생 막대, 부활 카운트다운, 적·제단 HP 막대). [M4a: 체력 · 대시 · 기본 공격 · 사망 · 이단](#m4a-체력--대시--기본-공격--사망--이단).
그 위에 **M4b "세션의 전투"**를 더했다: M4a가 혼자 할 때 더한 것을 세션에서 모두 호스트가 정한다(HP·스태미나·다운/사망, 이단의 스폰·AI·HP·공격, 화살·빛 탄, 피해, 소생, 부활, 가방, 이단의 제단). 프레임 코드에 대시와 F 누르고 있기를 넣고(1바이트 그대로), USE에 조준을, 상태에 vitals 블록(쉬는 중이면 없음)을 더했다. 클라이언트는 자기 이동·대시·공격 동작·타이머·부활을 예측하고(피해는 호스트의 사건), 이단은 지도마다 그 지도의 사람에게만 적 묶음으로(공격 시작은 그 틱에 바로, 예고는 늦추지 않고 그림), 화살은 쏨·멈춤 사건 + 클라이언트 비행으로 받는다. 판정은 호스트 시간, 되감기 없음(예고 500ms에 한 방향 지연 50ms면 예고를 본 뒤 400ms 안에 대시하면 피함, 잼). 세션에서도 클래스 무기가 핫바 8번에 들어온다. 전송 형식 v5. [M4b: 세션의 전투](#m4b-세션의-전투).
그 위에 M4 검토 지적을 반영했다(**M4-fix**): 소생은 F를 누른 사람 중 가장 빠른 사람 기준이라 성직자가 있으면 자리 순서와 상관없이 즉시(● §2.6), 활·성광은 화살이 그려져 나가는 점에서 마우스로 쏘고 그린 화살이 그린 이단 몸에 닿으면 맞음(전에는 발 근처를 눌러야 맞았다), 빛 가장자리의 이단은 빛 안에서 맞아도 지켜보기를 다시 세지 않아 4초 뒤 집으로, 사람이 떠난 지도는 한 번 비움(예고 중인 공격은 칼 없이 끝, 날던 화살 없앰, 스폰 시계 처음부터: 계단으로 도망쳤다 돌아오자마자 맞던 것), 클라이언트의 vitals·동작 시계를 호스트 시간에 묶음(앞서지 못하고 30틱 넘게 뒤처지지 못함: 서 있다 맞으면 바로 호스트가 진행하던 것, 가끔 보내 다운을 버티던 것, 쌓아 둔 프레임으로 경직·대시 쿨다운을 줄이던 것), 벽 모서리 틈으로 빠지던 화살, 가득 찬 드롭에 빈 가방, 지난 부활 시각, 오가기의 대시, 이단의 제단 자리를 화살 걸음마다 맵 전체에서 찾던 것, 빠진 시험(두 소생자, 던전 사망·부활 대기, 실제 세션 `fightlag`)과 README. [검토 반영 (M4-fix)](#검토-반영-m4-fix-2026-10-22).
그 위에 **M6a "제작 · 조제대 · 물약 · 약제 투척 · 효과"**(혼자 할 때 먼저. 세션에서는 제작·마시기·던지기·효과가 아직 꺼져 있고 M4b 흐름 그대로, M6b에서 켠다)를 더했다: M7이 그대로 쓸 제작 틀(설치물마다 작업대 종류, 레시피 = 입력(아이템·수·등급) → 출력(아이템·수·등급)과 만들 수 있는 클래스, 모두 아니면 하나도 아님, 자리가 없으면 거부, 처음 얻은 재료로 레시피 해금 스위치), 조제대(04-env `alchemy_table_v05`, 3×1 자리, 막음, 디버그 아이템 `alchemy_table`을 횃불처럼 놓음), 작업대 옆에서 **Tab** = 제작 창(코드로 그린 작은 창, 마우스·키), 물약 셋(● 작물 하나에 하나: 회복·버프·독, 야생 약초 둘 → 하나, 등급은 입력을 따름, 상급과 독은 약초사만 ● §3.0), **마시기**(물약을 골라 좌클릭, 마법 동작을 빌려 씀: 회복은 HP, 버프는 걷기 속도, 독은 마신 사람을 중독), **약제 투척**(약초사가 **1**: 마우스 쪽으로 던지기 동작 `base_body_v02_throw`, 병이 벽에 막히며 날아가 터짐: 회복·버프는 그 둘레의 아군에게, 독은 이단에게, 아군 사격 끔), 효과 둘(버프 하나 = 걷기 속도, 상태이상 하나 = 독: 공유 시뮬레이션 `PlayerSim`과 `Arena` 안이라 혼자 = 호스트 = 예측, 쓰러지면 끝남, 독으로 죽은 이단은 다른 처치처럼 셈)과 머리 위·HUD 표시. [M6a: 제작 · 조제대 · 물약 · 약제 투척 · 효과](#m6a-제작--조제대--물약--약제-투척--효과).
그 위에 **M6b "세션의 제작 · 물약"**을 더했다: M6a가 혼자 할 때 더한 것을 세션에서 모두 호스트가 정한다. 제작은 새 요청 CRAFT(레시피 번호: 호스트가 그 사람의 자리에서 작업대·해금·클래스·등급·입력·자리를 보고 그 사람의 인벤토리에 만든다), 조제대 놓기는 횃불처럼 그 지도의 편집(M6a의 세션 거부를 없앰), 마시기는 물약 칸의 USE(호스트가 가득 찬 HP 등을 다시 봄), 던지기는 새 요청 THROW(던진 점을 싣고 호스트가 96px로 자름). 클라이언트는 마시기·던지기 동작만 예측하고 효과는 호스트의 것을 받는다: 플레이어의 버프·독은 vitals 블록 뒤 **효과 블록**(7B, 효과가 있을 때만: 쉬는 상태는 17B 그대로), 이단의 독은 적 묶음의 표시 비트(0B), 던진 병은 화살처럼 **"던짐"·"터짐" 사건 + 클라이언트 비행**(호스트와 같은 걸음 함수라 그리는 병 = 호스트의 점). 효과는 타이머라 호스트 시간으로 흐른다(클라이언트가 효과 동안 프레임을 보냄). 늦은 참가·지도 들어옴은 효과·독·날고 있는 병·조제대를 그대로 받는다. 전송 형식 v6. 던진 회복이 다운된 사람을 일으키는지는 임시값(기본 아니오). [M6b: 세션의 제작 · 물약](#m6b-세션의-제작--물약).
그 위에 M6 검토 지적을 반영했다(**M6-fix**): 조제대는 사람이 걷지 않고 나타나는 자리(지도의 도착점, 제단 둘레 부활·참가 자리 아홉)를 덮을 수 없다(그 위에 도착하거나 부활한 사람이 막는 탁자 속에 섰다. 임시값), 던진 병을 unshaded로(어두운 던전에서 거의 안 보였다), 호스트의 제작 검사는 레시피의 작업대 종류 중 손 닿는 것(가장 가까운 작업대 하나만 보지 않음)이고 작업대 찾기는 자리 크기에 상관없음, 작업대 아이콘·클래스 거부 문구·자리 크기를 작업대·설치물 값마다 표로, 쓰러진 뒤 끝난 독이 남기던 필드(`EFFECTS_END_ON_DOWN`을 끌 때), 무기로 죽은 이단의 독, 독 틱을 무기 맞음과 따로 셈(`poison_hits`, 로그 `POISON`), 사용·마시기·던지기는 동작이 시작될 때만 한 것으로 셈(같은 프레임의 Space), 던질 점을 혼자 할 때도 정수 px로(전송 형식과 같게), 이름 없던 숫자·낡은 주석·끊긴 줄 잇기, 빠진 시험(나타나는 자리, 큰 자리의 작업대, 마시는 중 사라진 물약, 효과의 끝과 지도 옮김, 사거리 밖 던지기, 리그 시간으로 그려 본 남의 표시가 꺼짐, THROW + Space), 문서에 없던 규칙을 임시값 줄로(플레이어의 독은 다운·사망까지, 빈 지도의 병과 독, 제작 창이 열린 동안), 두 창 그림 다시. [검토 반영 (M6-fix)](#검토-반영-m6-fix-2026-10-22).
그 위에 **M5a "밭 · 씨앗 · 물주기 · 자라기 · 수확 · 시듦"**(혼자 할 때 먼저. 세션에서는 농사가 꺼져 있고 M6b 흐름 그대로, M5c에서 켠다)을 더했다: 괭이가 제단 빛 안의 풀을 일군 흙으로(바닥 편집, 채굴처럼 지도의 편집. M1 생성기의 흙 덩어리는 이미 밭), 씨앗 셋(04-env 작은 것 띠의 씨앗 봉투, 좌클릭으로 심기: 회복·버프 약초는 누구나, 독초 씨앗은 약초사만 ● R37), 물뿌리개(칸이 젖고 60초 뒤 마름, 04-env 물 준 흙을 칸별 덧칠로 ● R29), 자라기(젖은 동안만, 0~4단계 = 04-env `crops_v03`, 약초사가 심은 것은 두 배 빠름), 낫으로 수확(작물을 겨누면 수확만, 아니면 무기 그대로: 야생 약초와 같은 아이템 둘 + 씨앗 하나, 등급은 거두는 사람 = 약초사면 상급), 시듦(빛 밖이거나 오염이 2칸 안이면 그 틱에 시들어 멈추고, 원인이 사라지는 틱에 되살아남, 밭은 남음), 야생 약초를 캐면 그 작물의 씨앗 하나. 작물의 보이는 상태는 월드의 식생 레이어 값이라 스냅샷·해시·편집 기록이 그대로 덮고, 자라는 시간·물 시간은 지도마다의 `Farm`이 틱으로 센다(시계·난수 없음: 혼자 = 호스트(M5c)). 시험 플래그 `--test-field`, 창 그림 검사 `fields`, 스모크 `farm=`. [M5a: 밭 · 씨앗 · 물주기 · 자라기 · 수확 · 시듦](#m5a-밭--씨앗--물주기--자라기--수확--시듦).
그 위에 **M5b "정화 · 성수 · 제단 옮기기"**(혼자 할 때 먼저. 세션에서는 꺼져 있고 M5a 흐름 그대로, M5c에서 켠다)를 더했다: 성수(04-env `item_holy_water_a_v02`, ● §3.0 누구나: 고르고 좌클릭 = 목표 칸 둘레 3×3의 오염 칸을 정화, 마법 동작을 빌려 씀, 얻는 길은 아직 `--give`뿐), 팔라딘의 광역 정화 채널링(● §3.0: 재 위나 바로 옆에서 주울 것이 없을 때 **F** = 정화 시작, 3초 서 있으면 발 칸 둘레 반지름 3칸 원판의 오염 칸이 풀로, 움직이기·대시·사용·맞음·다운이면 끊김, 마법 동작을 되풀이하고 둘레에 금빛 점), 정화된 칸 = 풀(바닥 재 → 풀, 오염 → 0: 월드 편집이라 스냅샷·해시·편집 기록이 그대로 덮음. 재가 걷히는 모습은 잠깐의 재 얼룩(04-env `decal_ashcreep`)과 금빛 테두리로만), 이단의 스폰 칸이 오염을 따라 다시 계산되고(`Arena.sync_world`) 오염 옆에서 시든 작물은 다음 틱에 되살아남(M5a 규칙). 제단 옮기기(● §9.3 위치·이동 자유): 누구나 제단 칸을 겨누고 **F를 2초** 누르고 있으면 든다(제단 칸이 월드에서 빠진다: 그동안 빛·안전 반경·스폰 억제·부활 자리가 없고 죽은 사람은 기다린다, 든 사람 머리 위에 작은 제단), **좌클릭** = 겨눈 쪽 두 칸 앞에 내려놓기(열린 땅이고 오염·설치물·채집물·밭·드롭·누구의 발·도착점이 아니고, 부활 자리 아홉이 설 수 있고, 새 빛 안에 살아 있는 이단이 없을 때. 놓일 자리를 금빛/짙은 빨강 테두리와 빛 가장자리 점으로 보임). 든 사람은 오가기·채널링·도구 사용을 못 하고, 다운되면 가까운 놓을 수 있는 자리에 저절로 놓인다. 놓으면 빛·안전 반경·이단의 빛 규칙과 스폰 칸·부활 자리 아홉·비워 두는 자리·제단 옆 띠·밭의 빛이 모두 새 자리를 따른다(옛 밭은 남아 시들고 새 빛 안의 밭은 자람, 더미도 새 자리로). 제단 자리는 설치물 레이어의 칸에서 다시 읽어서(`WorldData.refresh_altar_rect`) M5c도 전송 형식을 바꾸지 않아도 된다. [M5b: 정화 · 성수 · 제단 옮기기](#m5b-정화--성수--제단-옮기기).
그 위에 **M5c "세션의 농사 · 정화 · 제단"**을 더했다: M5a·M5b가 혼자 할 때 더한 것을 세션에서 모두 호스트가 정한다(● game-concept §13 호스트 권한). 호스트가 지도마다 `Farm`을 매 틱 돌리고(혼자 할 때와 같은 규칙·순서: 플레이어 → 아레나 → 농장), 일구기·심기·물주기·수확·성수·채널링·제단 들기·놓기는 입력 프레임에 붙는 요청을 호스트가 그 프레임의 자리에서 검사해 적용한다(심기는 씨앗 칸의 USE, 성수는 성수 칸의 USE, 괭이·물뿌리개·낫은 도구 동작의 맞는 프레임, 새 요청 CHANNEL·ALTAR_LIFT·ALTAR_PLACE). 밭·작물·정화된 땅·제단 자리는 그 지도의 번호 붙은 편집이고(늦은 참가·지도 들어옴은 스냅샷으로), 채널링은 상태의 동작 비트에, 든 제단은 상태의 든 아이템 바이트에 실린다(상태는 17B 그대로, 프레임은 1바이트 그대로). 클라이언트는 몸 동작과 채널링만 예측하고 결과(자람·정화·제단 자리)는 받는다. 제단을 들고 있는 동안 아무도 부활하지 않고, 그동안 참가하는 사람은 든 자리 둘레에 나타나며, 든 사람이 다운되거나 나가면 가까이 내려놓인다. 전송 형식 v7. [M5c: 세션의 농사 · 정화 · 제단](#m5c-세션의-농사--정화--제단).
그 위에 **M7a "작업대 체인 · 1티어 장비 · 내구도 · 공유 창고"**(혼자 할 때 먼저. 세션에서는 새 작업대·창고 놓기와 새 레시피를 호스트가 거부하고 갑옷·마모가 꺼져 있다, M7c에서 켠다)를 더했다: M6의 제작 틀 위에 작업대 셋(기본 작업대 → 모루 → 성물 제작대, 04-env `workbench_v03`·`anvil_v03`·`relic_bench_v03` + 공유 작은 불꽃)과 손 레시피(작업대 없는 곳의 Tab, 통나무로 기본 작업대), 레시피 열넷(널판, 모루, 창고, 모루의 제련 1 : 1, 1티어 장비 여섯, 성물 제작대, 성물 제작대의 횃불)과 수리 여섯, 재료 셋까지 그리고 스크롤하는 제작 창, 1티어 무기 다섯(클래스 기본 무기마다 하나: 같은 동작·공격 모양·채굴·수확, 피해 150%, ● §3.5 누구나 모루에서)과 갑옷 한 벌(인벤토리 밖 갑옷 칸, 고르고 클릭 = 입기, 칼 한 번에 4를 덜 받음), 내구도(1티어만: 공격마다·맞은 칼마다 1, 죽으면 지닌 장비 모두 20%, ● §2.6 장비는 남고 닳음, 부서지면 기본 아이템처럼, 모루에서 재료 하나로 수리, 칸의 막대), 공유 창고(04-env `storage_chest_v02`, 제단 빛 안에만, 칸 16, F = 인벤토리 위의 창고 창, 클릭으로 넣기·꺼내기, 내용물은 지도의 것이고 월드 해시가 덮음). 시험 셋, 창 그림 검사 셋, 스크린샷 셋. [M7a: 작업대 체인 · 1티어 장비 · 내구도 · 공유 창고](#m7a-작업대-체인--1티어-장비--내구도--공유-창고).

기준 문서: `docs/game-concept.md` §2 §3 §7 §9.3 §9.7 §10 §11 §12 §13, `docs/gameplay-design.md` §1 §2.1 §2.2 §2.3 §2.4 §2.5 §2.6 §3.0 §3.1 §3.2 §3.4 §3.5 §3.8 §5 (M4b: §2.1 실시간·에임형, §2.6 사망 흐름, §3.0 팔라딘 줄, §3.1 ○ "타일 동기화가 던전 안 인원끼리만", game-concept §13 호스트 권한. M6a: §1 ○ "Tab 인벤토리·제작", §2.2 ? 스킬 킷과 ○ 약초사 정체성 스킬 = 약제 투척, §2.4 ○ 상태이상, §3.0 ● R11 약초사 줄, §3.4 ● 상급, §3.5 ○ 제작·해금, game-concept §9.7 ○ 조제대, §12 ● 작물 셋 R28. M6b: game-concept §13 ● 호스트 권한, §2.6 ● 소생(던진 회복과의 관계), 나머지는 M6a와 같음), `docs/concept-art-brief.md` §4 §5.6 §5.7(M6a: ● R29 물약 색), `assets/concept/03-pixel/prompts.md`(8~12차, 몸 동작. M4a: 8차 피격·사망, 13차 이단과 "M4에 넘길 것"), `assets/concept/04-env/prompts.md`("본 제작", 채집물, M3a: 던전 바닥↔벽 타일, 광맥, 벽 금, 던전 입구, 이단의 제단, 소품. M6a: 조제대 v05, 작은 것 묶음 `items_v04_strip`의 물약).
M5a 기준 문서: `docs/game-concept.md` §9.3(● 제단 = 빛·안전 반경, 위치·이동 자유), §9.7(○ 농사 줄기, 밭은 빛 안에서만, 시듦과 되살아남, 밭은 남음, R37 슬라이스 줄), §10(톤 이원화), §11, §12(● 작물 셋 R28, ● R37 누가 무엇을 심나), `docs/gameplay-design.md` §1(○ 키), §2.6, §3.0(● R11 약초사·팔라딘 줄), §3.4(● 상급), §3.7(○ 정화: M5b), §3.8(○ 농사, ● R37 줄), `docs/concept-art-brief.md` §5.7(● R28 작물, ● R29 시든 작물·물 준 흙 칸별 덧칠·독초 색), `assets/concept/04-env/prompts.md`(1차 시험 손질: 흙 v03·물 준 흙·흙 변형, `crops_v03`, 씨앗 봉투 #18~#20).
M5c 기준 문서: `docs/game-concept.md` §9.3(● 위치·이동 자유, 안전 반경 = 빛·스폰 억제·오염 저항, ● 팔라딘의 정화가 반경 밖 땅을 되찾음), §9.7(○ 농사 줄기, 밭은 빛 안에서만, 제단을 옮기면 밭은 남아 빛 밖, 시든 작물을 정화가 되살림, R37 슬라이스 줄), §10, §11, §12(● 작물 셋, ● R37 누가 무엇을 심나), §13(● 호스트 권한), `docs/gameplay-design.md` §1(○ F "정화 시작"), §2.6(● 부활 = 제단, 제단을 옮기면 부활 지점도), §3.0(● R11 팔라딘·약초사 줄), §3.7(○ 정화), §3.8(○ 농사, ● R37 줄), `docs/concept-art-brief.md` §5.7(● R28·R29).
M5b 기준 문서: `docs/game-concept.md` §5(○ 오염과 정화: 슬라이스는 확산 없는 고정 구역), §9.3(● 제단 위치·이동 자유, 안전 반경 = 빛·스폰 억제·오염 저항, 팔라딘의 정화가 반경 밖 땅을 되찾음), §9.7(○ 제단을 옮기면 밭은 남고 빛 밖, 시든 작물을 정화가 되살림), §10, §11, §12(고정 오염 구역 2~3곳, 팔라딘 정화), `docs/gameplay-design.md` §1(○ F "정화 시작"), §2.6(● 부활 지점 = 제단; §5 ○ "제단을 옮기면 부활 지점도 옮겨진다"), §3.0(● R11 팔라딘 줄: 누구나 성수로 타일 몇 개, 클래스 전용 광역 정화 채널링, 상점 성수 = 대체 수단), §3.7(○ 정화: 채널링 반경 N, 원천을 부숴야 재오염이 멈춤, 슬라이스는 확산 없음), §3.8, `docs/concept-art-brief.md` §5.7, `assets/concept/04-env/prompts.md`(묶음 2 #58~#60 성수, "오염 장식" `decal_ashcreep`).
M7a 기준 문서: `docs/gameplay-design.md` §2.4(○ 방어력), §2.6(● R12 사망 = 내구도 손상 + 일부 아이템 드롭, ○ "일부"의 세부), §3.0(● R11 표: 룬마스터 줄 "누구나 모루에서 1~2티어 제작. 룬 슬롯 없음", 기술자 줄 "누구나 벽·바닥·문·작업대 건설"), §3.1(레이어), §3.3(○ 건설, ● R37 건설 벽은 돌만: M7b), §3.5(○ 작업대 근처에서 Tab, 처음 얻은 재료로 해금, 작업대 체인, ● 1티어는 누구나 모루에서), §5(○ 공유 창고: 제단 옆), `docs/game-concept.md` §9.3(제단, 안전 반경), §12(작업대 체인 2~3단계, ● R37 나무 1종·○ 도끼, ● R21 기본 외형만, 판정 기준), `docs/concept-art-brief.md` §5.7(작업대 줄, 건설 ● R37, "나무" 줄), `assets/concept/04-env/prompts.md`(본 제작: 기본 작업대·모루·공유 창고, 본 제작 손질 2: `workbench_v03`·`anvil_v03`·`relic_bench_v03`의 공유 작은 불꽃 자리·아이템 v02/v03, 묶음 2 #42·#44·#46·#62).
문서의 ●는 그대로 따르고, ○·?는 정하지 않고 [임시값](#임시값-사람-확인-필요)으로 둔다.

## 준비

- Godot 4.7.2 stable 콘솔 빌드: `C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe` (AGENTS.md "엔진")
- 내보내기 템플릿: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
- 아래 명령은 **저장소 루트에서 Git Bash** 기준이다. `< /dev/null`은 stdin을 기다리지 않게, `timeout`은 멈췄을 때 끊으려고 붙인다

```bash
GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
```

PowerShell에서는 `& "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/run_all.gd` 처럼 쓴다.

## 명령

### 임포트

클론 직후, `.godot/`을 지운 뒤, PNG나 `class_name` 스크립트를 추가한 뒤에 한 번. `*.import`, `*.uid`가 생기면 커밋한다.

```bash
timeout 300 "$GODOT" --headless --path game --import < /dev/null
```

- 종료 코드는 GDScript 오류가 있어도 0이다. 스크립트가 컴파일되는지는 테스트(`test_core.gd`가 모든 `.gd`를 불러 봄)로 본다
- 에디터 언어가 한국어라 진행 줄이 한국어(색 코드 포함)로 나온다

### 전체 테스트

```bash
timeout 600 "$GODOT" --headless --path game --script res://tests/run_all.gd < /dev/null
```

- 출력: 첫 줄 `EVENSONG_TESTS start: 27 file(s) in res://tests, ports 24621-24640`(M6a: 19, M6b: 21, M5a: 22, M5b: 24, M5c: 27, M7a: 30. 전체가 약 365~380초라 위 명령의 `timeout`은 600(M5c에서 900으로 돌렸다))(이 실행이 쓰는 테스트 포트 묶음, 아래 "테스트 포트"), 파일마다 `PASS test_x.gd (n checks, ms)` 또는 `FAIL ...`과 실패 한 줄씩(`  - `), 측정값(`  * `), 경고(`  ! `). 끝에 `EVENSONG_TESTS done: ...`
- 종료 코드: 모두 통과 0, 하나라도 실패 1 (불러오기 실패·시간 초과·테스트 파일 없음·시작 중 오류·마지막 파일 뒤 오류도 1)
- 통과하는 실행에도 오류 묶음이 **8개** 찍힌다. 모두 테스트가 `allow_error()`로 미리 알리고 일부러 낸 것이다 (각 묶음 아래 `at:`·backtrace 줄이 붙는다):
  - `ERROR: Character: unknown class 'wizard'` 1개: `test_actors.gd`가 모르는 클래스 이름을 거부하는지 확인
  - `ERROR: Character: 0 is not a body action` 1개 (M2a): `test_actions.gd`가 걷기를 몸 동작으로 보여 달라는 요청을 거부하는지 확인
  - `SCRIPT ERROR: Parse Error: ... (Warning treated as error.)` 5개: `test_core.gd`가 "경고를 오류로" 설정 5종이 실제로 컴파일을 막는지 확인
  - `ERROR: Couldn't create an ENet host.` 1개: `test_net.gd`가 같은 포트에 호스트를 하나 더 열어 실패가 시그널로 오는지 확인. 빈 포트 찾기는 이제 `UDPServer`로 해서(쓰는 포트면 오류 줄 없이 코드만 돌려준다) 포트가 막혀 있어도 이 줄이 늘지 않는다
  - 이 밖의 `ERROR`·`SCRIPT ERROR` 줄은 문제다. 러너가 실패로 세므로 어느 파일의 FAIL 아래(또는 `FAIL (startup)`, `FAIL (after the last file)` 아래)에 같은 내용이 나온다
  - `ERROR`로 grep하면 `  * child logs: 14 instances, ... lines scanned for ERROR:` 측정 줄도 걸린다. 오류가 아니다
- 자식 프로세스(러너 자체 시험, `test_net_session.gd`의 세션)의 오류는 화면에 찍히지 않는다. 테스트가 출력이나 로그를 받아서 검사한다

### 테스트 하나만

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=world < /dev/null      # test_world.gd
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=core,world < /dev/null
```

- 파일당 제한 시간(초, 기본 120): `-- --timeout=300`
- 러너 자체 시험: `-- --dir=res://tests/fixtures --prefix=case_ --timeout=2` (2개 PASS, 9개 FAIL, 종료 1이 정상)와 `-- --dir=res://tests/fixtures --prefix=late_ --timeout=2` (파일은 PASS, 그 뒤 `FAIL (after the last file)`, 종료 1이 정상). `test_core.gd`가 자식 프로세스로 둘 다 돌려 확인한다. 자식은 `OS.create_process` + `--log-file`로 띄우고 0.05초마다 살아 있는지 보다가 마감(60초)이 지나면 죽이고 실패로 센다(예전 `OS.execute`는 자식이 멈추면 테스트 전체가 같이 멈췄다). 마감이 실제로 듣는지는 30초 걸릴 자식(`case_timeout.gd`를 `--timeout=60`으로)을 2초 마감으로 띄워 죽는 것으로 매번 확인한다

### 테스트 포트

네트워크 테스트는 UDP 포트 20개 한 묶음을 쓴다. 러너가 실행마다 한 번 정해서 넘겨준다(테스트 파일은 `Runner.port_first`/`port_last`, 자식 프로세스는 `--host=<포트>` 같은 명시 포트나 `--ports-from-parent=<첫 포트>`).

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --port-base=25000 < /dev/null   # 25000-25019
EVENSONG_TEST_PORT_BASE=25100 timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd < /dev/null
```

- 기본은 24621-24640. 그 묶음을 다른 실행이 잡고 있으면 위로 20씩(24641, 24661, ... 10묶음까지) 옮긴다. `--port-base`나 환경 변수로 준 묶음이 잡혀 있으면 옮기지 않고 `FAIL (startup)`으로 끝난다. 이때 테스트 파일은 하나도 돌리지 않는다(첫 줄이 `..., no test ports claimed`, 끝 줄 `EVENSONG_TESTS done: 0 passed, 0 failed ... no file ran: test ports not claimed`, 종료 1. H-fix 전에는 쥐지 않은 기본 묶음으로 모든 파일을 돌렸다)
- "잡혀 있다" = 그 묶음의 잠금(TCP `127.0.0.1:<첫 포트>` 듣기)을 다른 러너가 쥐고 있거나, 묶음 안 UDP 포트 하나라도 누가 쓰고 있다. 러너는 잠금을 실행 내내 쥐고 있다. 듣기는 운영체제가 하나만 받아 주는 일이라 두 러너가 같은 때 시작해도 한쪽만 잡고, 러너가 끝나거나 죽으면 운영체제가 푼다. 그래서 두 작업 트리에서 테스트를 동시에 돌려도 서로 다른 묶음을 쓴다
- UDP 포트는 주소 세 개로 확인한다: `*`(IPv6 이중 스택, 호스트가 듣는 주소), `0.0.0.0`, `127.0.0.1` (`Runner.PROBE_ADDRESSES`). Windows는 이중 스택 소켓이 다른 프로그램의 IPv4 소켓과 같은 포트를 같이 쓰게 해 주고, 그러면 테스트 클라이언트가 127.0.0.1로 보낸 것은 그 프로그램이 받는다. 이 데스크탑에서 재 보니 `0.0.0.0`을 잡은 소켓은 `0.0.0.0` 확인만, `127.0.0.1`을 잡은 소켓은 `127.0.0.1` 확인만 실패했다(`*` 확인은 둘 다 통과). H-fix 전에는 `*` 하나로만 확인해서 IPv4만 잡은 프로그램이 있는 포트를 비었다고 보고 세션 테스트가 120초 뒤 실패했다
- 남은 경합: 러너가 아닌 다른 프로그램(또는 이 잠금이 없는 예전 러너)이 묶음을 확인한 뒤에 그 안의 포트를 잡으면 막을 수 없다. 그러면 세션 테스트가 그 포트에 호스트를 못 열고 실패한다(빈 포트는 세션마다 다시 찾으므로 묶음 안 다른 포트로 비켜 가는 경우가 많다)

### 네트워크 테스트

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net < /dev/null           # 한 프로세스 안 (약 2초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session < /dev/null   # 실제 세션 (약 85초, M3b부터)
timeout 400 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-full --timeout=300 < /dev/null   # + 10프로세스 상한 시험
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-exe=build/evensong.console.exe < /dev/null   # 자식을 내보낸 exe로
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_session --net-sessions=cave,four < /dev/null   # 그 세션만 (M3b)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_maps < /dev/null      # M3b 단위 시험 (약 4초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_combat < /dev/null    # M4b 한 프로세스 전투 (약 10초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_fight < /dev/null     # M4b 실제 세션 fight·fight4·fightlag(M4-fix) (약 65초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_fight --net-exe=build/evensong.console.exe < /dev/null   # 자식을 내보낸 exe로
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_potions < /dev/null   # M6b 한 프로세스 제작·물약 (약 5초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_brew < /dev/null      # M6b 실제 세션 brew·brew4 (약 55초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_brew --net-exe=build/evensong.console.exe < /dev/null   # 자식을 내보낸 exe로
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_fields < /dev/null    # M5c 한 프로세스 농사·정화·제단 (약 6~20초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_farm < /dev/null      # M5c 실제 세션 farm·farm4 (약 35초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_purify < /dev/null    # M5c 실제 세션 purify·altar (약 50초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_farm,net_purify --net-exe=build/evensong.console.exe < /dev/null   # 자식을 내보낸 exe로
```

- `test_net.gd`: 전송 형식(왕복, 잘린 패킷 전부, 무작위 바이트 2,000개), 인원 상한(진짜 9명: 10번째 거부, 빈 자리 다시 쓰기), 호스트 입력 검사(순서·중복·속도 제한·고르게 적용·따라잡기는 틱당 4개까지, 실제 시간 시계 `InputGate.ticks_between`과 그 시계로 두 배 빨리 보내는 클라이언트, 호스트가 1초 멈췄다 따라잡기를 두 순서로: 물리 틱 안에서 멈춤 / 틱 밖에서 멈춰 Godot이 따라잡기 틱 뒤에 네트워크를 읽음, 멈춤 크레딧이 쌓이지 않고 사라짐), 호스트가 바라보기를 방향에서 정하기(클라이언트 예측과 프레임마다 같음), 호스트의 묶음/키프레임/조용함 판단, 클라이언트 예측을 지연·손실 있는 가짜 연결로 호스트와 맞춰 보기(지연 0·5·9틱, 손실 0·25%, 위치와 바라보기), 보간, 월드 스냅샷(여섯 레이어 왕복, 조각 크기·순서·틱당 개수, 받는 쪽 검사: 빠진 조각·바뀐 바이트·다른 월드·크기, 크기 상한 `MAX_SIDE`·`MAX_PACKED`, 크기·md5가 맞는 무작위 조각도 풀기 단계에서 거부), 스냅샷 뒤의 편집 기록, 스냅샷 크기와 참가 시간(128×96, 512×512 합성, 512×512 무작위), 봇 스크립트, CLI, RPC 표(누가 부를 수 있는지·채널·신뢰성), 전송(ENet 호스트+참가를 한 프로세스에서, 양쪽 연결의 패킷 조절 설정, Steam은 신호로 unavailable)
- `test_world_items.gd` (M2b): 채집물 표와 등급 규칙(● §3.4), 줍기·버리기·사용·주기 규칙(손 닿는 칸, 발이 타일 선 위일 때의 발 칸, 가득 찬 인벤토리, 드롭 일부만 줍기, 주기 개수 0 = `bad count`, 클라이언트의 300개 주기 = 요청 255 + 45), 호스트 요청 검사(진짜 `NetSession` + `SessionHost.run_frame`, 전송 없이: 손 닿지 않음, 틀린 칸, 빈 칸, 도구 아님, 동작 중, 마구 보내기 = rate, 클라이언트 주기·버리기 끔, 고르기는 예산 밖, 거부된 고르기는 인벤토리를 돌려보냄, 바라보기와 다른 쪽 칸의 사용은 칸 쪽을 봄), 같은 틱에 둘이 같은 것을 줍기(채집물·드롭 모두 정확히 하나, 손으로 부른 `run_frame`과 `SessionHost.tick` 자체: 게이트에 자리 2를 먼저 넣어도 자리 1이 가짐), 드롭의 월드 해시·스냅샷(왕복, 거부 9가지, `MAX_DROPS`에서 버리기 거부 + 그 월드의 스냅샷 왕복)·편집 기록(스냅샷 + 뒤 편집 = 호스트 월드), 그림(ItemView) = 데이터, 인벤토리 전송 형식, 몸 동작 예측을 지연·손실 있는 가짜 연결로 호스트 `run_frame`과 맞춰 보기(오차·동작 보정 0, 호스트가 거부한 사용은 보정), 서서 조준만 하는 클라이언트(바라보기가 바뀌는 틱만 프레임을 기록하고 호스트도 같은 쪽을 봄), 호스트의 인벤토리 위에 아직 처리 안 된 고르기를 다시 얹기(`SessionClient.on_inventory`: 프레임에 실린 것·아직 줄에 있는 것, ack가 덮으면 호스트 것), 남의 동작 보간, 혼자 할 때 `main.tscn`에서 F 줍기 · F7 버리기
- `test_net_maps.gd` (M3b): 지도 들어옴 메시지(왕복, 잘린 것 전부, 없는 지도, 다른 지도의 자기 상태), 지도를 적은 편집, 스냅샷 머리말의 지도 번호(기대한 지도가 아니면 받는 쪽이 거부), 두 지도를 섞지 않는 보간, 봇 `waitmap`. 호스트 요청 검사(진짜 `NetSession` + `SessionHost`, 전송 없이): 멀리서·길 아닌 칸·맵 밖 TRAVEL, 마구 보내는 TRAVEL(`rate`), 지도를 받는 중의 TRAVEL(`still loading`), 입구에 PICKUP(`a way to another map`), 다른 지도를 겨눈 사용·횃불·줍기·버리기·TRAVEL(`wrong map`, 예산을 쓰지 않음), 멀리 있는 칸을 캐는 악의 클라이언트(2·3·40칸, 맵 밖), 휘두르는 동안 매 프레임 사용(`busy`), 기반암 테두리와 출구 위 기반암(공용·광부 모두 `too hard`, 편집 없음. M3-fix: 광부가 계단을 세 번 쳐도 편집 0·던전 그대로), (M3-fix) 한 틱에 횃불 USE 열 번(하나 놓고 예산 4번, 나머지 `rate`). 같은 틱 채굴 경주(`SessionHost.tick`, 자리 2를 먼저 넣음): 한 번 남은 칸(자리 1이 깨고 돌, 자리 2는 `no wall`), 두 번 남은 칸(둘 다 맞고 자리 2가 깨고 돌), 광부 둘의 3×3 겹침(겹친 칸마다 한 번씩만 깨지고 아이템은 깬 쪽 하나). 잡은 전송으로 전체 흐름(`CaptureSession`이 호스트의 진짜 메시지를 잡아 진짜 `SessionClient`에 채널 순서대로): 지상의 A는 던전 편집을 하나도 안 받고 아래의 호스트를 그리지 않음 → A가 내려가 호스트의 던전 그대로(금·횃불·드롭, 동굴 그림 해시 같음. M3-fix: 지도 들어옴 그 자체가 아래에 있던 호스트를 보이게 함, `draw_others` 전에) → 실시간 편집 → B가 둘 다 아래일 때 늦게 참가(지상에서 아무도 안 그림) → B가 1바이트 조각으로 내려가는 동안 호스트가 캔 편집은 B의 지도 들어옴 뒤에 → 지상 편집이 B에게 오면 잘못된 메시지 → A가 올라감(지상 = 호스트, 떠난 던전 = 호스트) → 위치·지도 해시 같음. 예측: 호스트가 이미 깬 벽을 클라이언트가 아직 모를 때(편집이 0·30·90틱 늦게, 대칭 지연) 그동안과 편집 뒤 상태 하나쯤까지만 보정되고 그 뒤로는 없음, 같은 마지막 위치(비대칭 순서는 위 "M3b 예측"). 지도 전환: 다른 지도의 상태는 맞추지 않음, 전환은 호스트 상태에서 그 뒤 프레임을 새 지도에서 다시 돌림, 옛 지도를 겨눈 사용은 다시 돌릴 때 동작을 시작하지 않음
- `test_net_fields.gd`·`test_net_farm.gd`·`test_net_purify.gd` (M5c): 한 프로세스와 실제 세션의 농사·정화·제단(아래 "M5c: 세션의 농사 · 정화 · 제단"의 "시험"). `test_net_farm.gd`(`farm`·`farm4`)와 `test_net_purify.gd`(`purify`·`altar`)는 `test_net_session.gd`의 도구로 돌고, 파일 하나 제한 120초 안에 들게 둘로 나눴다
- `test_net_potions.gd`·`test_net_brew.gd` (M6b): 한 프로세스와 실제 세션의 제작·물약(아래 "M6b: 세션의 제작 · 물약"의 "시험"). `test_net_brew.gd`는 `test_net_session.gd`의 도구로 `brew`·`brew4`(약 55초, 파일 하나 제한 120초 안)
- `test_net_combat.gd` (M4b): 한 프로세스에서 진짜 `SessionHost`·`SessionClient`로 싸움 흐름 전부(아래 "M4b: 세션의 전투"의 "시험"). `test_net_fight.gd` (M4b): `test_net_session.gd`의 도구로 실제 세션 `fight`·`fight4`·(M4-fix) `fightlag`(파일 하나의 제한 시간 120초 안에 들게 따로 둠. 셋이 약 65초)
- `test_net_session.gd`: 이 프로젝트를 헤드리스 프로세스 여러 개(`main.tscn` + `--host`/`--join` + `--bot`)로 띄워 localhost ENet으로 실제 세션을 돌린다. 세션마다 모든 인스턴스가 결과 JSON을 쓰고 호스트와 비교한다 (아래 "네트워크 (G3)"의 "테스트가 확인하는 것")
  - `pair`: 호스트 + 클라이언트 1이 같이 걷고 멈춤 → (M2b) 호스트가 곡괭이를 3번 휘두르고 야생 약초(47,51)까지 걸어가 줍고(c1은 그것이 사라지는 편집을 받는다) 돌 5개를 그 칸에 버림, c1은 검을 달라고 요청해(주기 요청) 핫바 세 칸을 연달아 골라 검으로 돌아오고(매 프레임 고르기 3번, 모두 처리) 2번 휘두른 뒤 서서 남쪽을 조준만 한다(바라보기만 바뀌는 프레임: 호스트·c2도 c1이 남쪽을 보는지): 서로의 든 아이템과 동작을 본다 → 호스트가 월드 편집 → 늦은 참가자. 늦은 참가자는 `--test-perturb-generator`로 자기 생성기가 다른 월드를 만들게 해서 띄운다(다른 아키텍처 흉내): 그래도 호스트의 월드 해시·바닥 그림으로 끝나야 하고, 진단은 `generator=differs`. (M2b) 이 약초사는 주운 약초가 빠지고 돌 드롭이 있는 스냅샷을 받아(welcome `gatherables=73 drops=1`) 그 돌을 줍고, 약초 하나를 더 캐서 상급을 받는다. 옆에서 아무도 없는 포트에 참가 → 실패해야 함
  - `four`: 호스트 + 클라이언트 3 (상한을 `--max-players=4`로 낮춤) → 하나가 나감 → 늦은 참가자가 그 자리를 받음 → 다섯 번째는 "full"로 거부. (M2b) c1이 나가기 전에 호스트가 돌 5개를 (63,53)에 버리고, 세 클라이언트가 그 칸의 다른 세 옆에 서서 버리기 전부터 1.5초 동안 매 틱 F를 누른다(경주 + 요청 마구 보내기): 정확히 하나가 갖고, 나머지는 "rate"·"nothing there"로 거부된다. 이 호스트는 `--test-snapshot-chunk-bytes=32`로 스냅샷을 32바이트 조각 18개(M2b 월드 약 563B. M1에서는 11개·두 틱)로 잘라 세 틱에 걸쳐 보낸다(보통 월드는 1KB 조각 하나라 여러 조각·여러 틱 길을 실제 세션에서 지나게 하려고). 세 틱(= ⌈18/8⌉)인지는 호스트가 센 조각 보낸 틱 수(결과 JSON `streams`)로 확인한다
  - `lag`: 클라이언트 쪽에서 왕복 120ms 지연 + 15% 손실을 흉내 (`--net-lag`, `--net-loss`). 옆에서 `drop`: 호스트가 사라졌을 때 사람처럼 띄운 클라이언트(`--net-out` 없음)가 혼자 계속하는지
  - `stall` (H-fix): 호스트 + 걷는 클라이언트 1. 호스트가 봇 `stall:700`으로 물리 틱 밖(`_process`)에서 0.7초 멈춘다(긴 프레임 흉내). 그 뒤 클라이언트 입력 대기열이 따라잡아야 한다(속도 제한에 걸린 틱 ≤ 2, 멈춤 크레딧을 썼음). 이어서 호스트가 4틱마다 월드를 편집하는(60번) 동안 늦은 참가자 c2가 1바이트 조각 341~345개(43~44틱, M2b부터 채집물 때문에 약 567개·71틱)로 월드를 받는다: 받는 동안 생긴 편집이 welcome 뒤에 가야 하고(`catch_up_edits` > 0) c2의 월드·편집 수가 호스트와 같아야 한다. (M2b) 편집 10번마다 호스트가 돌 하나를 버려서(드롭 6개) 받는 도중의 드롭도 welcome 뒤 편집으로 가고, c2의 드롭 목록이 호스트와 같아야 한다
  - `cave` (M3b, 시드 1): 호스트(광부) + c1(성직자) + 늦은 c2(약초사). 호스트가 입구로 내려가 횃불을 놓고 도착 방 서쪽 바위를 3×3 한 번 쳐서 금이 가게 한다. 그동안 c1은 지상: 그 편집을 하나도 받지 않고 호스트를 그리지 않는다(표시 파일 `c1.alone`). c1이 내려가면 지도 스냅샷에 금 6칸과 횃불이 있다. 둘이 같이 캔다: 호스트가 3×3을 깨고 돌을 버리고, c1이 방 동쪽 바위를 4번 쳐서 금 2단계를 내고 횃불을 놓는다. 서로의 편집이 실시간으로 간다. c2가 둘 다 아래일 때 참가해 지상에서 아무도 그리지 않고(`c2.alone`), c1이 계단으로 올라오는 것을 보고(`c2.sees`), 내려가서 그때까지의 깸·금·횃불 둘·드롭을 스냅샷으로 받는다(`c2.down`: 호스트는 그리고 c1은 안 그림). 봇은 `waitmap`으로 서로를 기다린다. 끝에 모든 지도의 해시를 비교한다: c1의 지상, c2의 던전, c1이 떠날 때의 던전(호스트 로그의 같은 편집 번호 뒤 해시)
  - `four`에 더한 것 (M3b): M2b 경주 뒤 c2(아처)와 c3(성직자)가 곡괭이(`--give`)를 들고 내려가(32바이트 조각이라 던전이 10조각·2틱) 같은 바위를 두 쪽에서(c3은 그 앞면을) 친다: 정확히 한 번 깨지고, 돌은 깬 쪽 하나에. c4는 둘이 아래일 때 늦게 참가해 둘을 그리지 않는다
  - `--net-full`(선택): 진짜 상한 9명 = 호스트 + 클라이언트 8, 열 번째 거부. 프로세스 10개라 기본에서는 뺐다
  - (M4b) 모든 세션 인스턴스가 `--test-no-spawns`로 뜬다: M2b·M3b 세션은 하던 것만 본다(이단이 끼어들면 위치·예측·거부 검사가 흔들린다). 싸움은 `test_net_fight.gd`의 `fight`·`fight4`가 `--test-heretic`으로 놓은 이단으로 본다
- 자식 프로세스 로그(`--log-file`)에 `ERROR:` 줄이 하나라도 있으면 실패. 끝까지 남은 프로세스는 죽이고 실패. 통과하면 실행 폴더(`%APPDATA%/Godot/app_userdata/Evensong/net_test/run_*`)를 지우고, 실패하거나 `--net-keep`이면 남긴다 (로그·결과 JSON·표시 파일)
- 포트는 러너의 테스트 포트 묶음(위 "테스트 포트") 안에서 세션마다 빈 것을 찾는다

### 타일셋 다시 만들기

`art/tiles/`의 PNG·JSON이나 `world/tileset_builder.gd`를 바꿨을 때만. 같은 입력이면 같은 파일이 나온다(두 번 만들어 md5 같음을 확인했다).

```bash
timeout 120 "$GODOT" --headless --path game --script res://tools/build_tileset.gd < /dev/null
```

- 출력 `EVENSONG_TILESET res://world/tilesets/surface.tres error=0 sources=11 tiles=40 exact_keys=31 md5=...`와 (M3a) `EVENSONG_TILESET res://world/tilesets/dungeon.tres error=0 sources=2 tiles=30 exact_keys=21 md5=...`
- 결과 `world/tilesets/surface.tres`, `world/tilesets/dungeon.tres`를 커밋한다. 커밋된 파일이 새로 만든 것과 다르면 `test_world.gd`(지상)·`test_dungeon.gd`(던전)가 실패한다 (`ext_resource` id는 저장 위치에 따라 달라서 경로로 바꿔 비교한다)

### 캐릭터 기준점 표 다시 만들기

`art/chars/base_body_v02_*.png`나 `actors/rig_measure.gd`(재는 규칙)를 바꿨을 때만. 같은 시트면 같은 파일이 나온다.

```bash
timeout 120 "$GODOT" --headless --path game --script res://tools/build_rig_anchors.gd < /dev/null
```

- 애니메이션(걷기·idle + 몸 동작 8개, M2a)·방향마다 `EVENSONG_ANCHORS walk south torso=[...] head=[...]` 한 줄(30줄), 끝에 `EVENSONG_ANCHORS saved res://actors/rig_anchors.gd error=0 md5=...`. 이 데스크탑 약 2.6초
- 결과 `actors/rig_anchors.gd`(생성 파일, 손으로 고치지 않음)를 커밋한다. `test_actors.gd`가 시트에서 다시 재서 커밋된 표·파일 내용과 다르면 실패한다

### 내보내기 (Windows release, pck 내장, 콘솔 래퍼)

```bash
mkdir -p game/build/arm64
timeout 600 "$GODOT" --headless --path game --export-release "Windows Desktop" build/evensong.exe < /dev/null
timeout 600 "$GODOT" --headless --path game --export-release "Windows ARM64" build/arm64/evensong.exe < /dev/null
timeout 60 game/build/evensong.console.exe --headless -- --smoke < /dev/null
```

- 경로는 `game/` 기준이다 → `game/build/evensong.exe`(+ `evensong.console.exe`), `game/build/arm64/evensong.exe`
- ARM64는 `build/arm64` 폴더가 없으면 "주어진 내보내기 경로는 존재하지 않습니다"로 실패한다 (그래서 `mkdir`). 이 데스크탑(x86_64)에서는 실행해 볼 수 없다
- `tests/`, `tools/`는 내보내기에서 뺀다. `build/`는 `.gdignore`가 있어 임포트하지 않고 커밋하지 않는다
- 마지막 줄은 `EVENSONG_SMOKE ok exported=true ... gatherables=74 dungeon=64x48 hash=8dda0ad69ad9 ores=47 dungeon_seeds=acc0a9bc2359 dungeon_map=319B items=48 actions=8 combat=30/3 spawn_tiles=678 potions=6/1 farm=4800/2 purify=11+4/648 altar=49,45 chain=20/7 gear=21/8/96 chest=16 ... combat_wire=25B potion_wire=40B/46B fields_wire=17B/11B net=v7 checks=384`을 찍고 0으로 끝나야 한다(M3-fix에서 던전 해시 둘이 바뀌었다: 벽 횃불 자리 고르기. M4a·M4b·M6a·M6b·M5a·M5b·M5c·M7a에서 항목이 늘었다(M7a: `items=48`). 지상·던전 해시는 M6a·M6b·M5a·M5b·M5c·M7a에서 그대로). 아래 "스모크" 참조

### 실행

```bash
"$GODOT" --path game                                   # main.tscn: 월드 + 제단 + 내 캐릭터 + 다른 네 클래스
"$GODOT" --path game -- --class=cleric --no-evening    # 성직자로, 저녁 어둠 끈 채 시작
"$GODOT" --path game res://scenes/world.tscn -- --seed=7 --overlay   # 맵 보기 (자유 카메라, 캐릭터 없음)
game/build/evensong.exe -- --class=miner               # 내보낸 빌드
timeout 60 "$GODOT" --headless --path game --quit-after 120 < /dev/null   # 그리지 않고 120프레임 (오류 확인용)
"$GODOT" --path game -- --class=miner --give=pickaxe,hoe,sickle,watering_can,sword,bow,wild_healing:12,stone_a:30   # M2a: 도구를 들고 시작
"$GODOT" --path game -- --class=miner --give=pickaxe,torch:10 --start-map=dungeon   # M3a: 던전 도착점에서, 곡괭이(1번)와 횃불(2번)
"$GODOT" --path game -- --class=archer --test-select=8                              # M4a: 아처, 활(핫바 8번)을 든 채로. 북쪽 오염 구역(약 27칸)으로 걸어가면 이단
"$GODOT" --path game -- --class=paladin --test-at=72,26 --test-heretic=75,26 --test-select=8   # M4a: 오염 구역 옆, 이단 하나와 바로 붙어서
"$GODOT" --path game -- --class=herbalist --give=alchemy_table,wild_healing:4,wild_buff:4,wild_poison:4   # M6a: 조제대(핫바 1번)를 들고. 남쪽을 조준하고 좌클릭 = 놓기, 그 옆에서 Tab
"$GODOT" --path game -- --class=herbalist --give=potion_poison:3:fine,potion_healing:2,potion_buff:2 --test-at=63,53 --test-heretic=63,57   # M6a: 빛 남쪽 가장자리, 빛 밖에 이단 하나. 1번 칸(독)을 고른 채 이단을 조준하고 1
"$GODOT" --path game -- --class=herbalist --give=hoe,watering_can,seed_healing:5,seed_buff:5,seed_poison:5   # M5a: 괭이 1번·물뿌리개 2번·씨앗 3~5번. 빛 안 풀을 조준해 괭이 → 씨앗 → 물뿌리개, 익으면 Q로 낫(8번)
"$GODOT" --path game -- --class=paladin --give=sickle --test-field=59,45:healing:4/58,46:buff:3:wet/57,47:poison:2   # M5a: 빛 안 밭에 시험 작물(익은 회복 약초 등)을 놓고 시작, 낫(1번)으로 거둔다
"$GODOT" --path game -- --class=paladin --test-at=60,15 --give=holy_water:5 --test-no-spawns   # M5b: 북쪽 오염 구역 동쪽 가장자리. 서쪽(재)을 조준하고 F = 정화 채널링 3초, 성수(1번)를 고르고 재를 조준해 좌클릭 = 3×3 정화
"$GODOT" --path game -- --class=miner --test-at=63,49   # M5b: 제단 바로 남쪽. 북쪽(제단)을 조준하고 F를 2초 누르고 있으면 듦, 빈 땅을 조준하고 좌클릭 = 내려놓기
"$GODOT" --path game -- --class=miner --give=log:9,stone_a:10,ore_iron:6,ore_copper:4   # M7a: 작업대 없는 곳의 Tab = 손 제작 창(작업대). 작업대를 고르고 좌클릭 = 놓기, 그 옆 Tab = 널판·모루 …
"$GODOT" --path game -- --class=paladin --give=workbench,anvil,relic_bench,storage_chest,planks:20,ingot_iron:8,ingot_copper:6   # M7a: 작업대 셋과 창고(빛 안)를 바로 놓아 봄
"$GODOT" --path game -- --class=paladin --give=sword_t1,armor_t1 --test-durability=1:30 --test-wear=2 --test-at=63,56 --test-heretic=65,56   # M7a: 닳은 1티어 검(1번)과 입은 갑옷, 빛 밖 이단 하나
```

- `main.tscn`(실행 장면): WASD 또는 방향키로 8방향 걷기, 카메라는 내 캐릭터 가운데(맵 밖은 안 보이게 가장자리에서 멈춤). 제단 둘레에 나머지 네 클래스가 제단을 보고 서 있다(움직이지 않는 더미, 표식 다섯 가지가 한 화면에 보이게)
- F4로 저녁 어둠 + 제단 빛 켜고 끄기, F3으로 디버그 선(맵 테두리, 청크 경계, 제단 자리, 임시 안전 반경) 켜고 끄기
- M2a (키는 모두 임시값): 마우스를 움직이면 1초 동안 캐릭터가 마우스 쪽을 보고 발 옆의 목표 칸에 금빛 모서리 표시가 뜬다. 좌클릭 = 고른 핫바 칸의 도구 사용(그 도구의 몸 동작, 누르고 있으면 반복), Q / E = 핫바 왼쪽 / 오른쪽, Tab = 인벤토리 칸 전부 보기. 인벤토리는 비어서 시작한다: **F5**(디버그)가 도구 6개와 채집물·재료 묶음을 주고, `--give=`로도 준다. **F6**(디버그)은 들고 있는 것과 상관없이 몸 동작 8개를 차례로 한다(아이템이 없는 마법·던지기도 여기서 본다). 콘솔에 `EVENSONG_ACTION start item=pickaxe action=pickaxe facing=east target=61,48`
- M2b (키는 모두 임시값): **F** = 목표 칸의 채집물(없으면 드롭)을 줍기, **F7**(디버그) = 고른 칸의 묶음을 목표 칸에 버리기. 혼자 할 때는 바로, 세션에서는 요청으로 간다. 콘솔에 `EVENSONG_ITEMS pickup item=wild_buff count=1 grade=common at=47,51`. 채집물은 제단 빛 밖(가장 가까운 것이 약 13타일)에 있다
- M3a (키는 M2 그대로, 혼자 할 때): 지상 제단 동쪽(시드 1: 제단 가운데에서 약 10타일, 처음 화면 오른쪽 끝)의 **던전 입구**를 조준하고 **F** = 던전 도착점으로 내려간다. 던전 도착점 바로 북쪽의 **계단**을 조준하고 F = 입구 바로 남쪽으로 올라온다. 곡괭이를 들고 벽(또는 벽 앞면)을 조준하고 좌클릭(누르고 있으면 반복) = 채굴, 휘두르기 4번째 프레임에 맞는다. 광부는 3×3. 횃불(F5 묶음의 7번째 칸 = 핫바 7번, `--give=torch:<수>`)을 고르고 좌클릭 = 목표 칸(빈 바닥)에 놓는다(누르고 있어도 한 번). F4는 던전에서 어둠과 횃불 빛을 같이 끈다. 콘솔에 `EVENSONG_MAP travel to=dungeon feet=608,252`, `EVENSONG_MINE at=46,19 class=miner hit=9 broken=5 gained={ &"stone_a": 5 } ...`, `EVENSONG_ITEMS place item=torch ...`
- M3b: 세션에서도 같다(입구·계단 F로 오가기, 채굴, 횃불). 모두 호스트에게 가는 요청이고 호스트가 정한다(아래 "M3b: 세션의 지도", "두 기기에서 M3 해 보기")
- M3a: F5 디버그 묶음에 횃불 10개가 들어갔다(핫바 7번). M3-fix: 묶음은 24칸 중 22칸만 채우고 2칸을 비워 둔다(오염 쪽 돌 둘 `stone_veined`·`stone_mould`를 뺐다, 지상의 재 구역에서 주울 수 있다). 그래서 F5 뒤에도 약초사가 처음 캔 상급 약초 두 종류, 또는 캔 광석 두 종류가 인벤토리에 들어간다(M3a에서는 24칸이 다 차서 둘 다 `inventory full`, 광석은 드롭이었다). 채굴만 해 보려면 여전히 `--give=pickaxe,torch:10`이 낫다
- M4a (혼자 할 때, 키는 임시값): 클래스 무기가 **핫바 8번**에 있다(시작할 때 고른 칸은 1번 그대로라 **Q 한 번**으로 고른다). 무기를 들고 좌클릭 = 기본 공격(마우스 쪽, 누르고 있으면 반복), **Space** = 대시(스태미나), 다운되면 **F를 1초 누르고 있으면** 포기(바로 사망). 혼자서는 소생해 줄 사람이 없다(`--test-ally=<클래스>:down`으로 누운 동료를 옆에 두고 F를 누르고 있으면 소생을 볼 수 있다). 왼쪽 위에 HP(붉은)·스태미나(금빛, 대시 비용 밑이면 어두운 금빛) 막대. 이단은 지도에 들어간 뒤 8초마다 하나씩(지상 4, 던전 6까지) 오염 구역 둘레나 던전의 먼 방에 생긴다. 제단 빛 안으로 도망치면 이단은 빛 가장자리에서 멈춰 4초 지켜보다 돌아간다. M4-fix: 활·성광은 마우스 쪽으로, 그린 화살이 마우스 커서를 지나가게 쏜다(이단 그림 어디를 눌러도 맞는다). 콘솔에 `EVENSONG_COMBAT hit item=sword class=paladin hits=1 shrine_hp=0`, `EVENSONG_COMBAT hurt who=LocalPlayer amount=12 hp=88`, `EVENSONG_DEATH died who=LocalPlayer map=surface bag=66,58 items=17`, `EVENSONG_DEATH respawn who=LocalPlayer feet=962,768`, `EVENSONG_COMBAT shrine broken at=22,39`
- M4b (세션, 키는 M4a 그대로): 세션에서도 같다. 접속하면(호스트도) 클래스 무기가 핫바 8번에 있다. 공격·대시·F 누르고 있기는 프레임으로 호스트에게 가고 호스트가 정한다. 자기 동작·대시는 바로 보이고, 맞음·다운·소생은 호스트 상태가 오면(왕복 뒤) 보인다. 이단은 호스트가 지도마다 돌리고 같은 지도의 사람에게만 보낸다. 콘솔(호스트)에 `EVENSONG_NET host hit slot=1 map=0 heretic=2 amount=12 hp=28`, `heretic_attack map=0 heretic=3 slot=1`, `hurt slot=1 map=0 amount=12 hp=0 DOWN`, `revived slot=1 map=0 hp=30`, `died slot=1 map=surface bag=66,58 items=17`, `respawn slot=1 feet=1070,768`
- M6a (혼자 할 때, 키는 임시값: 임시값 "M6a 키"): 조제대는 디버그 아이템이다(`--give=alchemy_table`, F5 묶음에는 없다: 핫바에 빈 칸이 없어서). 고르고 좌클릭 = 목표 칸이 가운데인 3×1 자리에 놓는다(그 자리가 빈 바닥이고 아무도 서 있지 않을 때, 그래서 보통 위·아래를 조준). 조제대에서 2칸 안에 서서 **Tab** = 제작 창(오른쪽 위)과 인벤토리, 그동안 캐릭터는 서 있다. **W / S**(↑ / ↓) = 줄 고르기, **F** 또는 **Enter** = 만들기(마우스: 줄 위에 올리면 고르고 좌클릭 = 만들기), **Tab** 또는 **Esc** = 닫기. 멀어지거나 쓰러지면 닫힌다. 다른 곳의 Tab은 M2a 그대로 인벤토리. 레시피는 그 약초를 한 번이라도 얻어야 보인다(임시값 "M6a 레시피 해금"). 물약을 고르고 **좌클릭** = 마시기(누르고 있어도 한 번), **1** = 약초사가 고른 물약을 마우스 쪽으로 던짐(최대 6칸, 병이 날아가 터진 둘레 1.5칸). 머리 위와 HP 막대 밑에 버프(호박색 화살)·독(노란 방울) 표시. 콘솔에 `EVENSONG_CRAFT open station=alchemy at=59,48 recipes=6`, `EVENSONG_CRAFT made recipe=potion_healing_common item=potion_healing count=1 grade=common`, `EVENSONG_CRAFT refused recipe=potion_poison_common: herbalist only`, `EVENSONG_POTION drink item=potion_buff grade=common hp=100 buff=1200 poison=0`, `EVENSONG_POTION throw item=potion_poison grade=fine from=1016,858 to=1016,910`, `EVENSONG_POTION splash item=potion_poison at=1016,910 players=0 heretics=1`, `EVENSONG_POTION drink refused: full hp`
- M6a 세션(M6b에서 바뀜): M6a에서는 바뀐 것이 없었다(Tab은 인벤토리, 1과 물약 좌클릭은 아무것도 하지 않고, 조제대 놓기는 `alchemy table offline only`로 거부)
- M6b (세션, 키는 M6a 그대로): 세션에서도 같다. 조제대 옆 Tab = 제작 창, 줄을 만들면 호스트에게 요청이 가고 만든 물약은 호스트가 보낸 인벤토리로 들어온다(왕복 뒤). 물약 좌클릭 = 마시기, 1 = 던지기: 동작은 바로 보이고 효과(HP, 버프·독 표시)는 호스트 상태가 오면. 던진 병은 모두의 화면에서 날아가 터진다. 콘솔(호스트)에 `EVENSONG_NET host craft slot=1 map=0 recipe=potion_poison_fine item=potion_poison count=1 grade=fine station=64,50`, `throw slot=1 map=0 item=potion_poison grade=fine id=4 from=1016,854 to=1016,926`, `splash map=0 id=4 item=potion_poison at=1016,926 why=landed players=0 heretics=1`, `drink slot=2 map=0 item=potion_healing grade=common hp=70 buff=0 poison=0`, `request_refused slot=2 craft map=0 recipe=4: herbalist only n=1`, 클라이언트에 `EVENSONG_CRAFT request recipe=...`, 늦은 참가자에 `welcome_effects {"1":"alive hp=90 ... buff=140/1608 ..."}`
- M5a (혼자 할 때, 키는 M2a 그대로: 좌클릭 = 고른 것 사용): **괭이**를 들고 빛 안의 풀을 조준해 좌클릭 = 일구기(동작 4번째 프레임에, 누르고 있으면 되풀이), **씨앗**을 고르고 일군 흙에 좌클릭 = 심기(한 번, 동작 없음), **물뿌리개** 좌클릭 = 물주기(동작 6번째 프레임에), **낫**(약초사는 핫바 8번, 다른 클래스는 `--give=sickle`)으로 작물을 조준하고 좌클릭 = 수확(익은 것만. 작물을 겨눈 낫은 공격하지 않는다). 야생 약초를 F로 캐면 그 작물의 씨앗 하나가 같이 들어온다. 씨앗은 `--give=seed_healing:5` 등으로도 받는다(F5 묶음에는 없다). 콘솔에 `EVENSONG_FARM till at=62,51 class=herbalist field=none`, `EVENSONG_FARM plant at=62,51 class=herbalist item=seed_healing field=healing stage=0 fast`, `EVENSONG_FARM water at=62,51 class=herbalist field=healing stage=0 wet fast`, `EVENSONG_FARM grew at=62,51 crop=healing stage=1`, `EVENSONG_FARM harvest at=.. class=herbalist item=wild_poison count=2 grade=fine seeds=1 dropped=0 lost=0 field=soil`, `EVENSONG_FARM withered at=74,25 crop=healing stage=4`, `EVENSONG_FARM revived ...`, `EVENSONG_FARM seed from=wild_buff item=seed_buff count=1`, `EVENSONG_FARM plant refused at=..,.. class=paladin: herbalist only`
- M5a 세션(M5c에서 바뀜): M5a에서는 바뀐 것이 없었다(씨앗 좌클릭은 아무것도 하지 않고, 괭이·물뿌리개는 M2b처럼 동작만, 낫은 무기, 야생 약초에 씨앗 없음. 호스트는 씨앗 칸의 USE를 `farming offline only`로 거부)
- M5b (혼자 할 때, 키는 임시값 "M5b 키"): **성수**(`--give=holy_water:5`, F5 묶음에는 없다)를 고르고 오염(재)을 조준해 좌클릭 = 붓기(마법 동작, 4번째 프레임에 목표 칸 둘레 3×3의 오염 칸이 풀이 되고 하나 씀. 오염이 없으면 `holy water refused: nothing to purify`, 아무것도 안 씀). **팔라딘**이 재 위나 바로 옆에서 **F**(목표 칸에 주울 것이 없을 때) = 정화 채널링 시작(서서 3초, 마법 동작을 되풀이, 둘레의 금빛 점이 하나씩 켜짐, 끝나면 발 칸 둘레 반지름 3칸 원판의 오염 칸이 풀로. 걷기·Space·좌클릭·맞음이면 끊김). 정화된 칸에는 잠깐 재 얼룩과 금빛 테두리. **제단**을 조준하고 **F를 2초** 누르고 있음 = 들기(누구나. 빛이 꺼지고 머리 위에 작은 제단, 놓을 자리가 금빛(됨)/짙은 빨강(안 됨) 테두리와 빛 가장자리 점으로 보임), 들고 있는 동안 **좌클릭** = 겨눈 쪽 두 칸 앞(3×3의 가까운 변이 목표 칸)에 내려놓기. 들고 있는 동안 입구·계단의 F, 채널링, 도구·물약 사용이 없다. 콘솔에 `EVENSONG_PURIFY channel start at=60,15 class=paladin ticks=180`, `EVENSONG_PURIFY channel at=60,15 class=paladin tiles=9 corrupted_left=304 spawn_tiles=666`, `EVENSONG_PURIFY channel broken: moved`, `EVENSONG_PURIFY holy water at=53,10 class=paladin tiles=2 corrupted_left=299 spawn_tiles=653`, `EVENSONG_ALTAR picked up who=LocalPlayer class=herbalist from=62,46`, `EVENSONG_ALTAR place refused at=58,15 who=LocalPlayer: corrupted ground`, `EVENSONG_ALTAR placed at=49,45 who=LocalPlayer light=808,744`, `EVENSONG_ALTAR set down at=48,51 ...`(든 사람이 다운), `EVENSONG_DEATH respawn waits who=Ally_archer: no altar (carried)`, `EVENSONG_MAP travel refused to=dungeon: carrying the altar`
- M5b 세션(M5c에서 바뀜): M5b에서는 바뀐 것이 없었다(성수 좌클릭은 프레임을 만들지 않고, F는 M2b 줍기 그대로, F를 누르고 있어도 제단은 그대로. 호스트는 성수 칸의 USE를 `purification offline only`로 거부)
- M5c (세션, 키는 M5a·M5b 그대로): 세션에서도 같다. 괭이·물뿌리개·낫의 동작과 성수의 붓는 동작은 바로 보이고(예측), 흙·작물·젖음·정화된 땅은 호스트의 편집이 오면(왕복 뒤) 바뀐다. 씨앗 좌클릭은 요청(심기는 호스트가, 예측 없음). 팔라딘의 F(주울 것이 없고 오염 옆)는 CHANNEL 요청이 되어 채널링이 바로 시작되고(예측), 정화는 호스트가 끝나는 틱에. 제단을 조준하고 F를 2초 누르고 있으면 ALTAR_LIFT 요청이 가고 호스트의 상태가 오면 든 것이 되며(머리 위 작은 제단, 놓을 자리 표시), 좌클릭은 ALTAR_PLACE 요청. 다른 사람의 채널링 점과 머리 위 제단도 보인다. 야생 약초를 캐면 씨앗이 호스트 인벤토리로 들어온다. 콘솔(호스트)에 `EVENSONG_NET host farm slot=1 map=0 what=till at=62,49 class=paladin field=soil`, `farm slot=1 map=0 what=plant at=62,49 class=paladin item=seed_healing field=healing,stage=0`, `farm slot=0 map=0 what=harvest at=62,49 class=herbalist item=wild_healing count=2 grade=fine seeds=1 dropped=0 lost=0 field=soil,wet`, `field map=0 at=62,49 healing stage=3 wet`, `farm_refused slot=1 map=0 what=till at=..: outside the light`, `request_refused slot=1 use map=0 slot=2 at=62,49 aim=29: herbalist only n=1`, `seed slot=2 from=wild_buff item=seed_buff count=1`, `channel slot=1 map=0 start at=60,15`, `purify slot=1 map=0 what=channel at=60,15 tiles=9 corrupted_left=304 spawn_tiles=666`, `purify slot=1 map=0 what=holy_water at=56,15 tiles=..`, `channel slot=1 map=0 broken`, `altar slot=0 map=0 picked_up from=62,46`, `altar slot=0 map=0 placed at=49,45 light=808,744`, `altar slot=1 map=0 set_down at=..`, `respawn_waits slot=1: no altar (carried)`, 늦은 참가자에 `welcome ... altar=49,45 tilled=21 crops=4 withered=4 corrupted=313 generator=match`
- M7a (혼자 할 때, 키는 임시값 "M7a" 줄): 작업대 셋(`--give=workbench,anvil,relic_bench`)은 조제대처럼 고르고 좌클릭 = 놓기, 그 2칸 안에서 **Tab** = 그 작업대의 제작 창(M6a 키 그대로). 작업대 없는 곳의 **Tab**은 통나무를 한 번이라도 가진 뒤로 손 제작 창(기본 작업대 = 통나무 4)과 인벤토리. 1티어 무기는 기본 무기처럼 고르고 좌클릭. 갑옷을 고르고 **좌클릭** = 입기(핫바 왼쪽 갑옷 칸에 보임), 인벤토리를 열고 갑옷 칸 **클릭** = 벗기. 창고 상자(`--give=storage_chest`)는 제단 빛 안에만 놓이고, 그 칸을 조준하고 **F** = 창고 창 + 인벤토리(인벤토리 칸 클릭 = 넣기, 창고 칸 클릭 = 꺼내기, Tab·Esc·F = 닫기). 닳은 장비 칸에 막대. 콘솔에 `EVENSONG_CRAFT open station=anvil at=62,51 recipes=9`, `EVENSONG_CRAFT made recipe=sword_t1 item=sword_t1 count=1 grade=none`, `EVENSONG_GEAR equip item=armor_t1 durability=100/100`, `EVENSONG_COMBAT hurt who=LocalPlayer amount=8 hp=92`, `EVENSONG_GEAR death wear who=LocalPlayer items=2`, `EVENSONG_GEAR broke item=sword_t1 who=LocalPlayer`, `EVENSONG_CHEST open at=62,51 items=`, `EVENSONG_CHEST store item=stone_a count=40 left=0`, `EVENSONG_ITEMS place refused at=..: outside the light`
- M7a 세션(M7c에서 바뀜): 작업대 셋·창고 놓기는 호스트가 `workbench chain offline only`·`storage offline only`로, 체인·수리 레시피의 CRAFT는 `workbench chain offline only`로 거부한다. 갑옷 클릭은 프레임을 만들지 않고, 1티어 무기는 기본 무기처럼 치고 닳지 않으며, 손 제작 창은 열리지 않는다
- `world.tscn`: WASD 또는 방향키로 자유 카메라 이동 (제단·빛은 있고 캐릭터는 없다)
- 창 기본 1920×1080(4배). `-- --scale=3`이면 1440×810
- `--quit-after` 같은 Godot 인자는 `--` **앞에** 쓴다

### 둘이 하기 (G3)

창 두 개 (이 데스크탑 한 대):

```bash
"$GODOT" --path game -- --host --scale=2                                  # 창 1: 호스트 (팔라딘), 포트 24600
"$GODOT" --path game -- --join=127.0.0.1 --class=cleric --scale=2         # 창 2: 참가 (성직자)
```

- 두 창 모두 WASD/방향키로 걷는다(포커스가 있는 창만 키를 받는다). 창 제목에 `Evensong (host, paladin)` / `(client, cleric)`
- 클라이언트에서 지연을 느껴 보려면 창 2에 `--net-lag=120 --net-loss=5` (왕복 120ms, 손실 5% 흉내). 자기 캐릭터는 바로 움직이고(예측), 호스트 캐릭터는 100ms 뒤에서 부드럽게 따라온다(보간)
- 늦은 참가 보기: 창 1을 `-- --host --bot="wait:180;edit:62,50,soil"`로 띄우면(봇이 키 대신 움직인다) 3초 뒤 제단 아래 풀 한 칸이 흙이 된다. 그 뒤에 창 2를 띄우면 흙이 된 칸이 보인다. 참가자는 월드를 시드로 다시 만들지 않고 **호스트에게서 받는다**(아래 "네트워크"의 늦은 참가). 콘솔에 `welcome ... world_bytes=341 raw=73749 chunks=1 ... generator=match`
- 셋 이상: 창 3, 4 ... 를 같은 `--join`으로. 9명까지, 열 번째는 "full"로 거부된다 (콘솔에 `EVENSONG_NET client ended reason="refused: full" code=3`)
- 호스트 창을 닫으면 클라이언트는 다른 사람을 지우고 혼자 계속 걷는다 (콘솔에 `lost the host`, `offline playing on alone`). M2b: 그때부터 마지막으로 받은 인벤토리가 자기 것이 되고 줍기·버리기는 혼자 할 때처럼 바로 된다
- M2b: 두 창 모두 마우스로 조준하고 좌클릭으로 들고 있는 도구를 휘두르고(상대 창에 그 동작이 보인다), F로 줍고, Q/E로 고른다. 도구는 F5(디버그 묶음)로 받는다: 에디터로 띄운 호스트(디버그 빌드)는 클라이언트의 주기·버리기(F7) 요청을 받아 준다. 내보낸 exe 호스트는 `--test-allow-give`를 붙여야 한다(없으면 `give off`·`drop off`로 거부)

두 기기 (데스크탑 호스트 + 서피스 스냅드래곤, Tailscale. 스파이크에서 사람이 한 구성):

```bash
# 데스크탑: 내보내기 (아래 "내보내기") 후
game/build/evensong.console.exe -- --host
# 서피스: game/build/arm64/evensong.exe 와 evensong.console.exe 를 옮겨서 (저장소 README "기기 간 파일 옮기기")
evensong.console.exe -- --join=<데스크탑의 Tailscale 이름 또는 100.x 주소> --class=cleric
```

- 포트는 UDP 24600 (`--host=<port>`, `--join=<주소>:<port>`로 바꾼다). 호스트는 모든 인터페이스에서 듣는다. 처음 호스트를 열 때 Windows 방화벽 창이 뜨면 허용한다 (스파이크 때와 같은 일)
- `evensong.console.exe`로 띄우면 콘솔에 `EVENSONG_NET ...` 줄이 나온다 (접속, 거부 이유, 끊김). `evensong.exe`는 콘솔이 없다
- 접속이 10초 안에 받아들여지지 않으면 `failed: not admitted within 10 s`, 종료 코드 4로 끝난다 (주소·포트·방화벽 확인)
- **월드는 호스트가 보낸다** (H1): 서피스(ARM64)는 자기 생성기로 월드를 만들지 않고 데스크탑이 보낸 월드(레이어 6장, zstd로 압축, 조각으로)를 받아 그린다. 그래서 ARM64의 float 노이즈가 데스크탑과 달라도 참가는 된다. 콘솔의 `welcome ... generator=match`/`generator=differs (local ..., host ...)`가 서피스 생성기가 같은 월드를 만들었을지를 알려 주는 진단이다(실패 아님). 서피스에서 `evensong.console.exe --headless -- --smoke`의 `seed 1 world hash` 결과도 같은 것을 말해 준다
- 종료 코드 5는 이제 "받은 월드가 검사를 통과하지 못함"(조각 수·크기·md5·월드 해시)이다. 정상 연결에서는 나오지 않는다
- H-fix부터 ENet 패킷 조절을 끈다(아래 "네트워크"). localhost에서만 재 봤으니, 두 기기에서 서로의 캐릭터가 걷는 동안 몇 초씩 멈췄다 튀지 않는지 본다
- 스파이크(2026-10-21)에서 사람이 느낀 "서피스 쪽 자기 캐릭터 반응이 조금 늦음"은 이제 예측으로 푼다. 이번에도 사람이 두 기기로 다시 해 보지 않았다 (아래 "G3에서 확인하지 않은 것")

두 기기에서 M2b 해 보기 (사람이 할 것):

```bash
# 데스크탑: 내보낸 뒤 (내보낸 exe는 release라 클라이언트의 F5·F7을 받으려면 --test-allow-give)
game/build/evensong.console.exe -- --host --test-allow-give --class=miner
# 서피스:
evensong.console.exe -- --join=<데스크탑 주소> --class=herbalist
```

1. 둘 다 F5로 디버그 묶음을 받는다(핫바 1번 = 곡괭이). 서피스 콘솔에 오류가 없고 핫바가 차는지(호스트가 보낸 인벤토리)
2. 마우스를 움직여 목표 칸 표시가 마우스 쪽 발 옆 칸에 뜨는지(스폰 자리처럼 발이 타일 선 위에 있을 때도 동쪽·서쪽 조준이 발과 같은 줄인지, M2-fix), 좌클릭을 누르고 있으면 곡괭이를 계속 휘두르는지, 휘두르는 동안 마우스를 돌려도 표시가 치는 칸에 머무는지. **상대 화면에서도** 그 사람이 그쪽을 보고 휘두르는지, 끊기지 않는지. 서서 마우스만 돌렸을 때 상대 화면에서도 그쪽을 보는지
3. Q/E로 검·활·물뿌리개로 바꿔 휘둘러 본다: 상대 화면의 동작이 바뀌는지. 자기 화면에서 클릭과 동작 사이가 늦지 않은지(예측). Q/E를 빠르게 여러 번 눌러도 핫바가 상대 화면의 든 아이템과 어긋나지 않는지
4. 제단 빛 밖으로 걸어가(시드 1에서 가장 가까운 채집물은 제단 북쪽 약 13타일 칸 (62,34)의 버섯, 야생 약초는 서쪽 칸 (47,51)·동북쪽 (77,39)) F로 줍는다: 내 인벤토리에 들어오고 **상대 화면에서도 사라지는지**. 약초사(서피스)가 야생 약초를 캐면 핫바 칸 왼쪽 위에 금빛 점(상급)이 있는지, 광부가 캐면 없는지(● §3.4)
5. F7로 고른 묶음을 버리고 상대가 F로 주울 수 있는지, 둘이 같은 드롭에 동시에 F를 누르면 한 사람만 갖는지
6. 그 상태에서 세 번째 창(또는 서피스를 닫고 다시 참가)을 띄우면 주운 채집물은 없고 드롭은 있는지. 다시 참가하면 인벤토리는 빈 것이 맞다(이어지지 않음, 임시값)
7. 이상하면 두 콘솔의 `EVENSONG_NET ... request_refused ...` 줄(거부 이유)과 `action`·`pickup` 줄을 남겨 둔다

두 기기에서 M3 해 보기 (사람이 할 것, M3b):

```bash
# 데스크탑: 내보낸 뒤 (내보낸 exe는 release라 클라이언트의 --give를 받으려면 --test-allow-give)
game/build/evensong.console.exe -- --host --test-allow-give --class=miner --give=pickaxe,torch:10
# 서피스: 먼저 생성기 비교, 그다음 참가
evensong.console.exe --headless -- --smoke      # dungeon=64x48 hash=8dda0ad69ad9, dungeon_seeds=acc0a9bc2359 인지 (M3-fix 값)
evensong.console.exe -- --join=<데스크탑 주소> --class=cleric --give=pickaxe,torch:5
```

1. 둘 다 제단 동쪽 약 10타일의 던전 입구로 가서 입구를 조준하고 F: 내려가는지, 화면이 던전으로 바뀌기까지 걸리는 시간(왕복 + 지도 조각 하나), 바뀌는 순간 튀거나 멈칫하는지(서피스는 던전을 그리는 데 한 프레임이 길 수 있다)
2. 한 사람만 내려가 캔다: 지상에 남은 쪽 화면에 내려간 사람이 보이지 않는지. 그다음 지상 쪽이 내려가면 판 자리·금·놓은 횃불이 그대로 보이는지
3. 둘이 옆에서 캔다(곡괭이 = 핫바 1번, 횃불 = 2번): 상대의 금(앞면의 금이 잘 보인다)과 깨짐이 바로 보이는지, 같은 바위를 둘이 칠 때 한 번만 깨지고 돌이 한 사람에게만 가는지(데스크탑 콘솔 `mine slot=.. broken=1`)
4. 서피스(클라이언트) 쪽 휘두르기가 늦지 않은지(시작은 바로, 깨짐은 왕복 뒤), 데스크탑이 막 깬 자리로 서피스가 바로 걸어 들어갈 때 걸리거나 뒤로 당겨지는지(편집이 오기 전 잠깐만 그래야 한다)
5. 계단(도착점 바로 북쪽)으로 올라오기: 지상이 그대로인지, 그동안 상대가 지상에서 주운 것이 반영됐는지
6. 둘 다 던전에 있을 때 세 번째로 참가(또는 서피스를 닫고 다시 참가): 지상에 도착하고 던전의 사람은 안 보이는지, 내려가면 다 있는지
7. 이상하면 두 콘솔의 `travel`, `map entered`, `entered peer=`, `request_refused ... (wrong map|still loading|out of reach)`, `mine` 줄을 남겨 둔다
8. (M3-fix) 데스크탑(광부)이 도착점에서 계단을 몇 번 쳐 본다: 아무것도 깨지지 않아야 한다(콘솔에 `mine` 줄 없음, 결과는 `too hard`). 도착 방 계단 양옆의 벽 횃불이 보이는지, 앞면 옆에 섰을 때 캐릭터와 앞면이 어색하게 겹치지 않는지(알려진 문제 "벽은 엔티티 아래")
9. (M3-fix) 서피스(약초사로 다시 참가해도 됨)가 F5를 받고 야생 약초를 캐면 상급 점이 있는 새 칸에 들어가는지(묶음이 2칸을 비워 둔다)
10. (M3-fix) 둘 다 던전에 있을 때 데스크탑 창을 닫는다: 서피스가 혼자 계속 캐고 횃불을 놓을 수 있는지(콘솔 `offline playing on alone`). 한 번도 내려가지 않은 채 호스트를 잃으면 입구 F가 콘솔에 `travel refused to=dungeon: that map was never received`를 찍고 지상에 남는 것이 맞다

혼자, 그리고 창 둘로 M4 해 보기 (사람이 할 것):

1. 혼자 `"$GODOT" --path game -- --class=paladin`: Q 한 번으로 검(핫바 8번), 북쪽 오염 구역(제단에서 약 27칸)으로 가서 이단과 싸운다. 칼을 드는 예고(0.5초)를 보고 Space로 피해지는지, 맞으면 경직(0.3초)·붉은 깜빡임·HP 막대가 읽히는지, 제단 빛으로 도망치면 이단이 빛 가장자리에 멈춰 지켜보다 돌아가는지(빛이 '안전'으로 읽히는가, game-concept §12)
2. 혼자 `-- --class=archer --start-map=dungeon`: 가장 먼 방의 이단의 제단을 부순다(화살 13대쯤, 검이면 11번). 부서진 뒤 던전에 이단이 더 생기지 않는지(8초마다였다)
3. 혼자: 이단에게 일부러 맞아 다운 → F 1초로 포기 → 가방 → 5초 뒤 제단 → 돌아가 F로 가방 되찾기. 다운·사망 중 HUD(다운 시간·카운트다운)가 읽히는지
4. 창 둘(이 데스크탑): `-- --host --scale=2` 와 `-- --join=127.0.0.1 --class=archer --scale=2 --net-lag=120 --net-loss=5` 로 같이 싸운다. 클라이언트 창에서 예고를 보고 바로 대시하면 피해지는지(잰 값: 한 방향 60ms면 예고를 본 뒤 약 380ms 안), 자기 화살이 쏜 뒤 약간(왕복) 늦게 나타나는 것이 거슬리는지, 상대 화면에서 이단의 HP가 같이 주는지, 다운 → 상대가 F 5초로 소생(성직자면 즉시). (M4-fix) 클라이언트가 1초 넘게 가만히 서 있다가 맞아 본다: 호스트 콘솔에 `host_steps`, 클라이언트 콘솔에 `vitals_correction` 줄이 없어야 한다. 셋이면 다운된 사람 옆에서 팔라딘과 성직자가 같이 F를 누를 때 즉시 일어나는지
5. (M4-fix) 혼자 아처로 이단 그림의 몸통 가운데를 눌러 쏜다: 그린 화살이 커서를 지나 몸에 맞는지(전에는 발 근처를 눌러야 맞고 몸을 누르면 화살이 머리 위로 지나갔다). 옆으로 쏠 때 머리 위를 누르면 빗나가는지
6. (M4-fix) 혼자: 이단을 빛 가장자리까지 꾀어 온 뒤 빛 안에 서서 쏜다. 맞아도 약 4초 뒤 돌아서 집으로 가는지, 그동안·집으로 가는 동안·집에 서 있는 동안 빛 안에서 맞지 않고 칠 수 있다는 것이 "빛 = 안전"을 어떻게 읽히게 하는지(임시값 "M4-fix 빛 안에서 쏘인 이단"을 정할 근거)
7. (M4-fix) 혼자 던전 도착점에서 이단이 칼을 드는 순간 계단으로 올라갔다가 바로 내려온다: 내려오자마자 맞지 않고, 이단이 처음부터(쉼 뒤 새 예고) 다시 치는지

두 기기에서 M4 해 보기 (사람이 할 것, M4b):

```bash
# 데스크탑: 내보낸 뒤. 이단 셋을 제단 남쪽 빛 밖에 놓고 스폰은 끔(스폰을 보려면 --test-no-spawns를 뺀다)
game/build/evensong.console.exe -- --host --class=paladin --test-heretic=54,57/63,61/74,58 --test-no-spawns
# 서피스: 먼저 생성기·규칙 비교, 그다음 참가
evensong.console.exe --headless -- --smoke      # combat=30/3 spawn_tiles=678 net=v5 인지
evensong.console.exe -- --join=<데스크탑 주소> --class=archer
```

1. 둘 다 Q 한 번으로 핫바 8번(클래스 무기)을 고른다. 서피스(아처)가 빛 안 (63,53) 쯤에서 남쪽 이단(63,61)을 쏜다: 화살이 쏘는 순간과 거의 같이(왕복 뒤) 나타나 이단에 맞고 멈추는지, 이단의 HP 막대가 줄고 죽는 그림이 데스크탑 화면과 같은지
2. 데스크탑(팔라딘)이 서쪽 이단(54,57)에 다가가 검으로 친다: 서피스 화면에서 그 이단이 칼을 드는 예고가 보이고 데스크탑 화면과 같은 박자인지. 서피스가 다가가 예고를 보고 Space로 피해 본다: 왕복 지연이 있어도 예고를 보고 바로 누르면 피해지는지(시험의 잰 값: 한 방향 50ms면 예고를 본 뒤 400ms, 100ms면 300ms 안)
3. 서피스가 다른 이단(74,58)에게 가서 맞는다: HP 막대가 줄고, 경직 때 잠깐 멈추는지(자기 화면에서 튀지 않는지), 다운되면 눕고 위쪽에 다운 시간 막대가 생기는지. 데스크탑이 그 이단을 죽이고 옆에서 F를 5초 누르고 있으면 서피스가 일어나는지(서피스 화면의 소생 진행 막대)
4. 반대로 데스크탑이 다운되고 서피스가 F로 일으켜 보기. 서피스를 성직자로 다시 참가하면 즉시 소생인지
5. 다운된 채 F를 1초 눌러 포기: 가방이 생기고 상대가 F로 가방을 주울 수 있는지, 5초 뒤 제단에서 일어나는지(자기 화면에서 순간이동이 튀지 않는지)
6. 둘이 던전으로 내려가 이단의 제단을 부순다: 부서진 그림이 둘 다에게 보이는지. 그동안 지상에 남은 사람이 있으면(세 번째 창) 던전의 이단·화살이 그쪽 콘솔·트래픽에 없어야 한다
7. 싸우는 도중에 세 번째로 참가: 이단의 HP·예고 중인 공격·누운 동료가 그대로 보이는지
8. 이상하면 두 콘솔의 `hit`·`hurt`·`heretic_attack`·`revived`·`died`·`respawn`·`host_steps`·`vitals_correction`·`map_emptied` 줄을 남겨 둔다(`vitals_correction`·`host_steps`는 한 방향 약 200ms까지의 정상 연결에서 나오지 않아야 한다. M4-fix 전에는 서 있다 맞으면 나왔다)
9. (M4-fix) 서피스가 1초 넘게 가만히 서서 이단에게 맞는다(피하지 않고): 데스크탑 콘솔에 `host_steps`, 서피스 콘솔에 `vitals_correction`이 없는지. 데스크탑이 다운되고 서피스(성직자로 다시 참가)와 세 번째 창(팔라딘)이 같이 F를 누르면 즉시 일어나는지

혼자, 그리고 창 둘로 M6 해 보기 (사람이 할 것, M6b):

```bash
"$GODOT" --path game -- --host --scale=2 --class=herbalist --give=alchemy_table,wild_poison:4:fine,wild_healing:4:fine,potion_healing:2:fine,potion_buff:2:fine --test-heretic=63,58 --test-no-spawns
"$GODOT" --path game -- --join=127.0.0.1 --class=paladin --scale=2 --give=wild_healing:2,wild_poison:2 --net-lag=120 --net-loss=5
```

1. 창 1(호스트, 약초사): 핫바 1번(조제대)을 고르고 발 아래 칸을 조준해 좌클릭: 두 창 모두에 탁자가 보이는지. 그 옆에서 Tab → 제작 창, 상급 독을 만들면(F 또는 클릭) 핫바에 들어오는지(호스트 자신도 요청으로 간다: 콘솔 `host craft slot=0 ...`)
2. 창 2(클라이언트, 팔라딘)가 탁자 옆에서 Tab: 회복·독 줄이 보이고 독 줄은 어두운지. 일반 회복을 만들면 약간(왕복) 뒤에 핫바에 들어오는지, 독 줄에서 F를 누르면 아무것도 안 생기고 호스트 콘솔에 `request_refused ... craft ...: herbalist only`인지. 창이 열린 동안 WASD로 안 움직이는지
3. 호스트가 클라이언트를 조준하고 버프를 고른 채 1: 두 화면에서 병이 날아가 터지고, 클라이언트 머리 위 호박색 화살과 HUD 표시, 클라이언트가 걸을 때 빨라지고 자기 화면에서 튀지 않는지
4. 호스트가 빛 밖 이단(63,58)에게 독(1): 두 화면에서 이단 머리 위 노란 방울, 0.5초마다 HP 막대가 주는지. 클라이언트가 그 이단과 싸우다 맞으면 호스트가 회복을 던져 HP가 오르는지(클라이언트 화면은 왕복 뒤)
5. 클라이언트가 다운되면(맞아서) 회복을 던져도 일어나지 않는지(임시값 "M6b 던진 회복과 다운"). F로 일으키면 일어나는지
6. 클라이언트가 물약을 마셔 본다(물약 칸을 고르고 좌클릭): 마시는 동작은 바로, HP는 왕복 뒤. HP가 가득일 때는 아무것도 안 하는지
7. 셋째 창을 늦게 띄운다(독이 도는 동안, 또는 병이 날 때): 버프·독 표시와 탁자가 처음부터 보이는지
8. (M6-fix) 호스트가 조제대를 하나 더 받아(`--give=alchemy_table:2`) 제단 남쪽 부활 자리(발이 서는 자리, 예 (61,50)) 위에 놓아 본다: 놓이지 않고 콘솔에 `request_refused ... use ...: where players appear`인지(임시값 "M6-fix 조제대가 비워 두는 자리"). 혼자 할 때는 `EVENSONG_ITEMS place refused at=...: where players appear`. 이 규칙이 너무 넓거나 좁은지(놓고 싶은 자리가 막히는지) 본다
9. (M6-fix) 빛 밖 어둠에서 던진 병이 잘 보이는지(이제 unshaded: 터짐처럼 제 색). 너무 밝아 거슬리는지

혼자 M5a 해 보기 (사람이 할 것, 세션은 M5c):

```bash
"$GODOT" --path game -- --class=herbalist --give=hoe,watering_can,seed_healing:5,seed_buff:5,seed_poison:5
"$GODOT" --path game -- --class=paladin --give=hoe,watering_can,seed_healing:3,seed_poison:3,sickle
```

1. 약초사(첫 명령): 괭이(핫바 1번)로 제단 빛 안의 풀을 몇 칸 일군다. 흙 가장자리 그림이 둘레 칸과 이어 붙는지, 빛 가장자리에서 어디까지 일구어지는지(칸의 네 모서리가 모두 빛 안: 임시값 "M5a 밭은 빛 안에서만")가 화면의 빛 테두리(디더)와 어긋나 보이지 않는지. 더 밖은 콘솔에 `till refused ...: outside the light`
2. 씨앗 셋(3~5번)을 심고 물뿌리개(2번)로 몇 칸에만 물을 준다: 젖은 칸의 칸별 덧칠이 저녁에 빛 띠와 헷갈리지 않는지(04-env "남은 흠"에 적힌 걱정), 작물 밑 흙더미 색(코드의 색 표)이 마른·젖은 흙에 붙어 보이는지
3. 기다린다: 약초사의 작물은 젖은 시간 80초에 익는다(물 두 번, 60초마다 마른다). 단계가 바뀌는 것이 보이는지, 시간이 너무 길거나 짧은지(임시값 "M5a 자라기", "M5a 물"). 익으면 Q로 낫(8번)을 골라 작물을 조준하고 좌클릭: 상급 점이 있는 약초 둘 + 씨앗 하나가 들어오는지, 그 옆 조제대(`--give=alchemy_table`)에서 상급 물약이 되는지
4. 팔라딘(둘째 명령): 독초 씨앗을 심으면 콘솔에 `plant refused ...: herbalist only`이고 아무것도 안 생기는지, 회복 약초는 심어지는지(● R37). 익은 것을 낫(5번)으로 거두면 일반 등급인지. 팔라딘의 작물은 약초사의 두 배 걸린다(160초)
5. 야생 약초(빛 밖, 시드 1의 가장 가까운 것은 서쪽 (47,51))를 F로 캐면 씨앗 하나가 같이 들어오는지. "캘 때마다 하나"가 너무 후한지(임시값 "M5a 씨앗 얻기")
6. 위 "스크린샷"의 `m5_withered.png` 명령으로 빛 밖 오염 옆의 시든 밭을 본다: 시든 그림이 어린 작물에도 다 자란 것으로 나오는 것이 거슬리는지(자리 표시), "빛 안의 밭이 지킬 이유가 되는가"(game-concept §12 판정)를 이 대비가 보여 주는지
7. 낫을 든 채 작물이 아닌 곳을 겨누면 무기, 작물을 겨누면 수확만인 규칙(임시값 "M5a 낫 규칙")이 싸울 때 헷갈리지 않는지

혼자 M5b 해 보기 (사람이 할 것):

```bash
"$GODOT" --path game -- --class=paladin --test-at=60,15 --give=holy_water:5 --test-no-spawns
"$GODOT" --path game -- --class=herbalist --test-field=57,45:healing:4/58,45:buff:3:wet/59,46:poison:4:fast:wet
```

1. 팔라딘(첫 명령): 서쪽 재를 조준하고 F: 3초 동안 서서 마법 동작을 되풀이하고 둘레의 금빛 점이 하나씩 켜지는지, 끝나면 반지름 3칸 원판의 재가 풀이 되고 잠깐 재 얼룩과 금빛 테두리가 보이는지(작아서 안 보일 수 있다: 임시값 "M5b 그림 자리 표시"). 중간에 걸으면 끊기는지(`channel broken: moved`). 성수(1번)로 남은 재 가장자리를 좌클릭: 3×3이 풀이 되는지. 3초·3칸·3×3이 손맛에 맞는지(임시값 "M5b 채널링 시간·반지름", "M5b 성수")
2. 약초사(둘째 명령): 제단 남쪽에서 제단을 조준하고 F를 2초: 빛이 꺼지고 머리 위에 작은 제단, 놓을 자리 표시(금빛/짙은 빨강)가 마우스를 따라오는지. 들고 있는 동안 밭이 모두 시드는지. 서쪽 13칸쯤 빈 풀에 좌클릭: 제단·빛·더미가 옮겨지고 옛 밭은 시든 채 남는지(○ §9.7, 기본값), 새 빛 안에 밭을 일굴 수 있는지. "들고 있는 동안 빛이 없다"(임시값 "M5b 들고 있는 동안")가 읽히는지
3. 들고 북쪽 오염 구역 옆으로 가서 재 위에 놓아 보기: `place refused ...: corrupted ground`이고 표시가 빨간지
4. (M5-fix) 그 구역 바로 옆 풀에 놓아 본다(됨: 임시값 "M5-fix 빛 아래 오염"). 빛이 재를 덮어도 재가 그대로인 것, 빛 가장자리 바로 밖에서 이단이 나타나는 것(스폰을 켜려면 `--test-no-spawns`를 빼고 띄운다), 그 빛 안의 밭이 재 2칸 안이면 시드는 것이 "제단을 옮겨 새 지역으로 전진"(§9.3)으로 읽히는지, 아니면 오염 옆에는 놓을 수 없어야(끄면) 하는지. 팔라딘으로 그 옆에서 채널링해 시든 밭이 되살아나는지
5. (M5-fix) F 하나가 하는 일이 셋(줍기·채널링·소생, 누르고 있으면 제단 들기)이다: 제단을 겨눈 F는 채널링하지 않고, 채널링·소생 중에는 제단이 들리지 않는다(임시값 "M5b 키"). `--test-ally=archer:down`으로 다운된 동료 옆에서 제단을 겨누고 F를 누르고 있어 보기: 5초 소생이 먼저 끝나고 그 뒤 2초에 들리는지, 헷갈리는지

창 둘로 M5 해 보기 (사람이 할 것, M5c):

```bash
"$GODOT" --path game -- --host --scale=2 --class=herbalist --give=hoe,watering_can,seed_healing:3,seed_poison:3 --test-crop-ticks=240
"$GODOT" --path game -- --join=127.0.0.1 --class=paladin --scale=2 --give=hoe,watering_can,seed_healing:2,seed_poison:1,holy_water:3,sickle --net-lag=120 --net-loss=5
```

1. 창 2(클라이언트, 팔라딘): 빛 안의 풀을 괭이로 일구고(1번) 회복 씨앗(3번)을 심고 물뿌리개(2번)로 물을 준다: 괭이·물뿌리개 동작은 바로, 흙·작물·젖은 덧칠은 왕복 뒤에 나타나는지. 독초 씨앗(4번)은 아무것도 안 생기고 호스트 콘솔에 `request_refused ...: herbalist only`인지(● R37)
2. 창 1(호스트, 약초사)도 옆 칸에 독초를 심고 물을 준다. `--test-crop-ticks=240`이라 단계마다 4초(약초사의 것은 2초): 두 창 모두 같은 때 자라는지. 익으면 서로의 작물을 낫으로 거둔다: 약초사가 거둔 것은 상급 점, 팔라딘이 거둔 것은 일반(임시값 "M5a 수확 등급")
3. 창 2가 북쪽 오염 구역(제단에서 약 30칸)으로 가서 재 옆에서 F: 채널링이 바로 시작되고(클라이언트 창), 창 1에도 그 팔라딘이 마법 동작과 금빛 점으로 보이는지. 3초 뒤 두 창 모두 원판이 풀이 되고 금빛 테두리가 보이는지. 성수(5번)도 부어 본다
4. 창 1이 제단을 들고(F 2초) 서쪽으로 옮겨 놓는다: 창 2의 빛·제단이 같이 옮겨지는지, 창 2가 옛 빛 자리에 서 있으면 이제 빛 밖인지, 옛 밭이 시드는지. 들고 있는 동안 창 2에서 호스트 머리 위에 작은 제단이 보이는지
5. 셋째 창을 그 뒤에 띄운다: 시든 밭과 옮긴 제단이 처음부터 보이는지. 제단을 든 동안 띄우면 든 자리 둘레에 나타나는지(임시값 "M5c 들고 있는 동안 참가"). (M5-fix) 든 동안 창 2가 든 자리의 부활 자리에 조제대(`--give=alchemy_table`)를 놓으려 하면 `where players appear`로 거부되는지
6. (M5-fix) 창 1이 제단을 든 채 창 1을 닫는다: 창 2가 혼자 계속하며 제단이 마지막 자리에 돌아오는지(콘솔 `EVENSONG_ALTAR restored`, 임시값 "M5c 호스트를 잃었을 때 제단"), 빛과 부활이 되는지

두 기기에서 M5 해 보기 (사람이 할 것, M5c):

```bash
# 데스크탑: 내보낸 뒤 (클라이언트의 --give를 받으려면 --test-allow-give)
game/build/evensong.console.exe -- --host --test-allow-give --class=herbalist --give=hoe,watering_can,seed_healing:3,seed_poison:3 --test-crop-ticks=600
# 서피스: 먼저 전송 형식 비교, 그다음 참가
evensong.console.exe --headless -- --smoke      # fields_wire=17B/11B net=v7 인지
evensong.console.exe -- --join=<데스크탑 주소> --class=paladin --give=hoe,watering_can,seed_healing:2,holy_water:3
```

1. 서피스(팔라딘)가 빛 안에서 일구고 심고 물을 준다: 동작은 바로, 흙·작물은 왕복 뒤. 그 지연이 거슬리는지(심기는 예측하지 않는다: 알려진 문제)
2. 데스크탑의 작물이 자라는 것이 서피스에서도 같은 때 보이는지(편집, `--test-crop-ticks=600`이면 단계마다 10초)
3. 서피스가 오염 구역 가장자리에서 F: 채널링이 바로 시작되고 3초 뒤 정화되는지. 서피스 콘솔에 `vitals_correction`, 데스크탑 콘솔에 `host_steps`가 없어야 한다
4. 데스크탑이 제단을 들어 옮긴다: 서피스의 빛이 들고 있는 동안 꺼지고 놓으면 새 자리에 켜지는지(M5-fix: 빛 텍스처를 새로 만들지 않아 놓는 순간 멈칫하지 않아야 한다. 가득 찬 밭이 한꺼번에 시들거나 되살아나는 틱은 아직 길 수 있다: 알려진 문제)
5. 서피스가 제단을 들어 본다(F 2초): 왕복 뒤에 머리 위 제단이 생기는지, 들기 진행이 보이지 않아 헷갈리는지(알려진 문제). 그대로 서피스 창을 닫으면 데스크탑에서 제단이 서피스가 섰던 자리 가까이에 놓이는지(임시값 "M5c 든 사람이 나감")
6. 이상하면 두 콘솔의 `farm`·`farm_refused`·`field`·`seed`·`channel`·`purify`·`purify_refused`·`altar`·`respawn_waits`·`request_refused` 줄을 남겨 둔다

두 기기에서 M6 해 보기 (사람이 할 것, M6b):

```bash
# 데스크탑: 내보낸 뒤 (클라이언트의 --give를 받으려면 --test-allow-give)
game/build/evensong.console.exe -- --host --test-allow-give --class=herbalist --give=alchemy_table,wild_poison:4:fine,potion_healing:2:fine,potion_buff:2:fine --test-heretic=63,58 --test-no-spawns
# 서피스: 먼저 전송 형식 비교, 그다음 참가
evensong.console.exe --headless -- --smoke      # potion_wire=40B/46B net=v6 인지
evensong.console.exe -- --join=<데스크탑 주소> --class=herbalist --give=wild_poison:4:fine
```

1. 데스크탑이 조제대를 놓고, 서피스(약초사)가 그 옆에서 Tab으로 상급 독 둘을 만든다: 만든 물약이 들어오기까지 걸리는 시간(왕복), 제작 창이 그동안 어떻게 보이는지
2. 서피스가 빛 가장자리(63,53)에 선다. 데스크탑이 서피스를 조준하고 회복(1)과 버프(1)를 던진다: 서피스 화면에서 병이 날아오고 HP가 오르고 걸음이 빨라지는지, 튀거나 멈칫하지 않는지
3. 서피스가 이단에게 독을 둘 던진다: 자기 병이 손에서 나타나기까지의 지연(왕복)이 거슬리는지, 데스크탑 화면에서 같은 곳에 터지는지, 이단이 독으로 죽고 둘 다 같은 때 죽는 그림을 보는지(데스크탑 콘솔 `hit slot=1 ... KILLED`)
4. 버프가 도는 동안 서피스가 가만히 서 있어 본다: 데스크탑 콘솔에 `host_steps`, 서피스 콘솔에 `vitals_correction`이 없어야 한다(M6-fix에 적음: 서피스가 0.5초 넘게 멈추면(창 끌기 등) 버프 동안 호스트가 직접 진행하고 그 상태들이 `vitals_correction`으로 찍힌다. 알려진 문제, 위 "M6b: 세션의 제작 · 물약"의 "예측")
5. 이상하면 두 콘솔의 `craft`·`throw`·`splash`·`drink`·`request_refused`·`potion_refused`·`welcome_effects`·`vitals_correction`·`host_steps` 줄을 남겨 둔다

### 스크린샷

```bash
timeout 120 "$GODOT" --path game -- --screenshot=shots/main_evening.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --no-evening --screenshot=shots/main_evening_off.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game res://scenes/world.tscn -- --screenshot=shots/world.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game res://scenes/world.tscn -- --overlay --screenshot=shots/world_overlay.png --frames=30 < /dev/null
```

- `--frames`(기본 10) 프레임 뒤 루트 뷰포트를 PNG로 저장하고 끝난다. 출력 `EVENSONG_SCREENSHOT shots/world.png 480x270 window=960x540 error=0`
- 렌더러가 필요해서 `--headless` 없이 돌린다 (`--headless`와 같이 주면 종료 코드 2)
- 화면비가 expand라 창이 16:9가 아니면 뷰포트가 넓어진다 (처음 찍었을 때 1024×768 화면에 맞춰 줄어든 창이라 480×349가 나왔다). 그래서 `--scale` 없이 찍으면 화면에 들어가는 가장 큰 정수 배(1~4) 창으로 맞춰 늘 480×270으로 찍는다
- 상대 경로는 `game/` 기준. 내보낸 exe에서는 exe 폴더 기준이다
- `shots/`는 `.gdignore`로 임포트하지 않는다. 지금 들어 있는 그림 (모두 시드 1, 480×270):
  - `shots/main_evening.png`: 실행 장면. 가운데가 내 캐릭터(기본 팔라딘, 남쪽을 봄), 제단 둘레에 광부·아처·성직자·약초사 더미, 저녁 어둠과 제단 빛(디더 테두리)
  - `shots/main_evening_off.png`: 같은 장면, 저녁 어둠·제단 빛 끔 (그림 원래 색)
  - `shots/world.png`: 맵 보기 장면, 제단 가운데, 저녁 어둠 켬. `shots/world_overlay.png`: 같은 화면 + 디버그 선 (노란 원 = 임시 안전 반경이 빛 테두리와 겹친다)
  - `shots/net_host.png`, `shots/net_client.png` (G3, H1에서 다시 찍음): 세션 하나의 두 창. 호스트(팔라딘)와 클라이언트(성직자)가 각자 자기 캐릭터 가운데 카메라로 같은 장면을 본다. 클라이언트의 월드는 호스트가 보낸 스냅샷이다(로그 `welcome ... world_bytes=342 chunks=1 ... generator=match`). 성직자는 서쪽으로 걸어 제단 동쪽 면에 붙어 섰고, 몸이 제단 그림 뒤로 들어가지 않는다(제단 옆 띠). 찍은 명령 (호스트는 찍은 뒤에도 `--keep-running`으로 남아 있어야 클라이언트 화면에 나온다):

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24639 --scale=2 --bot="move:1,1,40;wait:3000" --screenshot=shots/net_host.png --frames=420 --keep-running --net-timeout=14 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24639 --class=cleric --scale=2 --bot="move:-1,0,30;wait:3000" --screenshot=shots/net_client.png --frames=360 < /dev/null
```
- 더미의 idle 프레임은 찍는 순간에 따라 달라서 같은 명령도 픽셀까지 같지는 않다
- M2b 두 창 그림 `shots/m2b_host.png`, `shots/m2b_client.png`: 세션 하나의 두 화면. 호스트(팔라딘, 검)는 동쪽을, 클라이언트(광부, 곡괭이, 호스트에게 주기 요청으로 받음)는 서쪽을 조준하고 누르고 있어 계속 휘두른다. 두 화면 모두 두 사람이 각자의 도구를 든 동작으로 보인다(찍는 순간의 동작 프레임은 실행마다 다르다). 클라이언트는 찍고 나면 나가므로 호스트가 먼저 찍게 프레임 수를 맞췄다(처음에 호스트 420프레임으로 찍었더니 클라이언트가 이미 나가서 호스트 화면에 혼자였다). 찍은 명령 (봇이 마우스·클릭 대신, 호스트는 찍은 뒤에도 남아 있게):

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24638 --scale=2 --give=sword --bot="aim:24,0;use:3000" --screenshot=shots/m2b_host.png --frames=330 --keep-running --net-timeout=14 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24638 --class=miner --scale=2 --give=pickaxe --bot="aim:-24,0;use:3000" --screenshot=shots/m2b_client.png --frames=300 < /dev/null
```
- M2a 그림 4장 (마우스 대신 `--test-aim`으로 조준을 고정하고, 동작은 `--test-action`으로 한 프레임에 멈춘다). M1 그림(`main_evening*.png`)은 HUD가 생기기 전에 찍었다:
  - `shots/m2_hotbar.png`: 광부, 디버그 묶음과 같은 아이템 23칸(`--give=`), Tab으로 연 인벤토리(아래 줄 = 핫바, 고른 칸 1 = 곡괭이, 금빛 테), 묶음 수(3×5 숫자), 상급 약초 칸의 금빛 점, 동쪽 목표 칸 표시
  - `shots/m2_aim.png`: 아처가 활을 고르고 서쪽(약간 아래)을 조준: 서쪽을 보고(동쪽 반전), 발 서쪽 칸에 표시
  - `shots/m2_use.png`: 광부가 곡괭이 동작 4번째 프레임으로 동쪽 표시 칸을 친다 (등의 곡괭이 레이어는 숨김, ● R27)
  - `shots/m2_actions_miner.png`: 광부의 몸 동작 8개(곡괭이·괭이·낫·물주기·검·활·마법·던지기) 가운데 프레임, 윗줄 남쪽 · 아랫줄 동쪽, 저녁 끔. 곡괭이 동작만 등의 곡괭이가 없다

```bash
timeout 120 "$GODOT" --path game -- --give=pickaxe,hoe,sickle,watering_can,sword,bow,wild_healing:12,mushroom_a:5,stone_a:30,stone_block:8,wild_healing:3:fine,wild_buff:4,wild_poison:2,herb_clump:6,mushroom_b:3,mushroom_c:2,mushroom_d,mushroom_ash:2,stone_b:4,stone_c:4,stone_mossy:2,stone_veined,stone_mould --test-select=1 --test-inventory --test-aim=40,8 --class=miner --screenshot=shots/m2_hotbar.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --give=pickaxe,hoe,sickle,watering_can,sword,bow,wild_healing:12,stone_a:30 --test-select=6 --test-aim=-28,10 --class=archer --screenshot=shots/m2_aim.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --give=pickaxe,hoe,sickle,watering_can,sword,bow --test-select=1 --test-aim=30,4 --test-action=pickaxe:4 --class=miner --screenshot=shots/m2_use.png --frames=30 < /dev/null
timeout 120 "$GODOT" --path game -- --test-action-lineup --class=miner --no-evening --screenshot=shots/m2_actions_miner.png --frames=30 < /dev/null
```

- M3a 그림 3장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때 `--bot`이 키·마우스 대신. `--max-fps 60`이라 프레임 수 ≈ 물리 틱 수):
  - `shots/m3_surface_entrance.png`: 저녁의 지상, 제단 빛 밖 동쪽의 던전 입구(아치 + 내려가는 계단 + 둘레 잔해 장식). 팔라딘이 입구 바로 남쪽에서 입구를 조준하고 서 있다(입구 앞에 그려짐)
  - `shots/m3_dungeon_torch.png`: 던전 도착점, 어둠(`DUNGEON_DARK_COLOR`). 약초사가 횃불 둘을 놓았다(남쪽 칸, 서쪽으로 걸어가 한 칸 더). 북쪽 벽 앞면의 출구 계단(임시 그림: 아치 + 뒤집은 계단) 양옆에 벽 횃불(불꽃 4프레임, 작은 빛). 핫바 1번 = 횃불 아이콘(코드 그림)
  - `shots/m3_miner_mining.png`: 광부가 통로에 횃불을 놓고 북쪽 벽 앞면을 곡괭이로 친다: 왼쪽에 3번 휘둘러 판 3×3 구멍(앞면이 세 칸 위로 물러남), 오른쪽은 한 번·두 번 맞은 3×3이 겹쳐 금 1·2단계(앞면의 금이 보인다. 바위 윗면의 금은 그림이 옅어 어둠 속에서 잘 안 보인다, 알려진 문제), 찍는 순간 곡괭이 동작 중. 핫바에 돌 a 9개

```bash
timeout 120 "$GODOT" --max-fps 60 --path game -- --bot="walkto:70,49;walkto:72,48;aimat:72,47" --screenshot=shots/m3_surface_entrance.png --frames=240 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --start-map=dungeon --class=herbalist --give=torch:3 --test-select=1 --bot="aim:0,30;use:2;wait:20;move:-1,0,25;aim:-20,0;use:2;wait:20;aim:off;move:1,0,20" --screenshot=shots/m3_dungeon_torch.png --frames=150 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=miner --start-map=dungeon --give=pickaxe,torch:2 --test-select=2 --bot="walkto:46,17;aim:20,0;use:2;wait:4;select:1;walkto:45,17;aimat:45,16;use:108;walkto:48,17;aimat:48,16;use:36;walkto:49,17;aimat:49,16;use:60" --screenshot=shots/m3_miner_mining.png --frames=372 < /dev/null
```

- M3b 두 창 그림 `shots/m3b_host.png`, `shots/m3b_client.png`: 세션 하나의 두 화면, 둘 다 던전. 호스트(광부)는 도착 방 서쪽 바위를, 클라이언트(성직자, 후광)는 동쪽 위 벽 앞면을 누르고 있어 계속 친다. 둘 다 내려오자마자 횃불을 하나씩 놓았다: 호스트는 남쪽, 클라이언트는 남서쪽 칸(랜턴 둘. M3-fix: 전에는 두 봇이 같은 칸을 겨눠 클라이언트의 횃불이 `not open floor`로 거부돼 랜턴이 하나였는데 설명은 둘이라 했다). 호스트 화면 왼쪽은 광부의 3×3이 깬 자리. 클라이언트의 던전은 호스트가 보낸 지도다(로그 `map entered map=dungeon ... bytes=345 ... torches=1`. M3-fix에서 다시 찍음: 호스트 로그 `place slot=0 ... at=38,16`, `place slot=1 ... at=37,16`, 두 로그 오류 줄 0, 클라이언트 핫바 횃불 2). 클라이언트는 찍고 나가므로 호스트가 먼저 찍게 프레임 수를 맞췄다(호스트는 2초 먼저 떠서 700프레임 ≈ 클라이언트 600프레임보다 조금 앞). 클라이언트에 `--keep-running`을 주면 호스트가 끝난 뒤 혼자 남아 `timeout`이 죽일 때 엔진 종료 오류 줄이 찍힌다(그래서 뺐다). 찍은 명령:

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24637 --scale=2 --class=miner --give=pickaxe,torch:3 --bot="walkto:70,49;walkto:73,48;aimat:73,47;pick;wait:20;select:2;aim:0,24;use:2;wait:10;select:1;walkto:34,15;aimat:33,15;use:3000" --screenshot=shots/m3b_host.png --frames=700 --keep-running --net-timeout=16 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24637 --class=cleric --scale=2 --give=pickaxe,torch:3 --bot="walkto:70,49;walkto:73,48;aimat:73,47;pick;wait:20;select:2;aim:-20,24;use:2;wait:10;select:1;walkto:40,15;aimat:41,14;use:3000" --screenshot=shots/m3b_client.png --frames=600 < /dev/null
```

- M4a 그림 5장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때 봇과 M4a 시험 플래그로 장면을 세움. 동작·화살·카운트다운은 찍는 프레임에 따라 다르다: 화면 프레임 수와 물리 틱이 처음에 몇 틱 어긋나서 같은 명령도 한두 틱 다른 순간이 찍힐 수 있다):
  - `shots/m4_surface_heretic.png`: 저녁의 지상, 북쪽 오염 구역(재) 남쪽 가장자리, 제단 빛 밖(빛은 약 27칸 남쪽이라 화면 밖). 팔라딘이 검으로 이단을 한 번 베어 이단 머리 위에 HP 막대가 있고, 이단이 칼을 앞으로 뻗어(맞는 열 다음) 팔라딘이 피격 자세로 젖혀졌다. 왼쪽 위 HP 막대가 88 (M4-fix에서 같은 명령으로 다시 찍었더니 바이트까지 같은 그림)
  - `shots/m4_dungeon_arrow.png`: 던전 도착 방 아래 통로, 어둠과 횃불 빛(놓은 횃불 + 계단 양옆 벽 횃불). 아처가 활을 쏘아 화살(코드 그림)이 동쪽에서 다가오는 이단에게 날아가는 중. M4-fix에서 다시 찍음(조준이 화살이 그려져 나가는 점에서: 화살이 이단 몸 높이로 난다). 프레임 46은 이번에 이미 맞은 뒤가 찍혀(위 "한두 틱 다른 순간") 45로 찍었다
  - `shots/m4_revive.png`: 제단 빛 바로 남쪽 밖(빛의 디더 가장자리가 위에 보임). 누운 아처(사망 시트 마지막 프레임, 표식 숨김) 위에 남은 다운 시간(녹빛)과 소생 진행(금빛, 절반쯤) 막대, 옆에서 팔라딘이 F를 누르고 있다(5초 소생의 2.5초쯤)
  - `shots/m4_death_bag.png`: 약초사가 다운된 채 F 1초로 포기해 죽은 뒤. 몸은 그리지 않고 죽은 칸에 가방(04-env 작은 자루), 화면 위쪽 가운데에 부활 카운트다운 `4`(3배 숫자), 핫바의 돌·약초·버섯·횃불은 절반이 줄었다(콘솔 `bag=66,58 items=17`)
  - `shots/m4_shrine_broken.png`: 던전 가장 먼 방, 벽 횃불 둘과 놓은 횃불. 팔라딘이 검으로 이단의 제단을 부쉈다: 해골 더미가 사라진 제단 판 위에 무너진 뼈 더미(04-env 뼈 더미를 얹은 임시 그림). 불은 꺼진 그대로 (M4-fix에서 같은 명령으로 다시 찍음. `m4_revive.png`, `m4_death_bag.png`은 조준과 상관없어 그대로)

- M4b 두 창 그림 `shots/m4b_host.png`, `shots/m4b_client.png`: 세션 하나의 두 화면, 지상 제단 남쪽 빛 밖. 호스트(팔라딘)가 이단(63,57) 옆에서 검으로 싸우고(이단이 호스트를 노려 칼을 휘두름), 클라이언트(아처)는 빛 가장자리 (66,53)에서 그 이단에게 활을 쏜다. 두 화면 모두 서로를 보고 같은 이단을 본다(클라이언트의 이단은 호스트가 보낸 적 묶음). 이단과 플레이어는 겹칠 수 있다(충돌 없음, M4a). M4-fix에서 다시 찍음: 봇은 이단 그림 가운데를 겨누고(`Combat.body_centre`), 클라이언트에 `--keep-running --net-timeout=12`를 주어 찍은 뒤에도 남아 있게 했다(전에는 클라이언트가 찍고 나가는 때가 호스트의 372프레임과 겨우 10프레임 차이라, 검토가 다시 찍었을 때 호스트 그림에 아처가 없었다. 클라이언트는 호스트보다 먼저 `--net-timeout`으로 스스로 끝난다: 종료 코드 6, 오류 줄 없음). 이번 그림: 호스트 로그 `hit slot=0 ... hp=26`, `hit slot=1 ... hp=14` 뒤 처치 전에 호스트가 찍었고, 클라이언트의 `left` 줄은 그 뒤에 나온다(두 로그 오류 줄 0). 찍은 명령:

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24636 --scale=2 --class=paladin --test-no-spawns --test-heretic=63,57 --bot="select:8;wait:200;fight:3000,0,20" --screenshot=shots/m4b_host.png --frames=372 --keep-running --net-timeout=16 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24636 --class=archer --scale=2 --bot="select:8;walkto:66,53;wait:100;fight:3000,0" --screenshot=shots/m4b_client.png --frames=262 --keep-running --net-timeout=12 < /dev/null
```

```bash
timeout 120 "$GODOT" --max-fps 60 --path game -- --test-at=72,26 --test-heretic=75,26 --bot="select:8;aimat:75,26;wait:20;use:600" --screenshot=shots/m4_surface_heretic.png --frames=66 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --start-map=dungeon --class=archer --give=torch:2 --test-at=40,17 --test-heretic=47,17 --bot="aim:16,0;use:2;wait:6;select:8;aimat:47,17;use:600" --screenshot=shots/m4_dungeon_arrow.png --frames=45 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=paladin --test-at=63,56 --test-ally=archer:down --bot="aim:18,0;hold:900" --screenshot=shots/m4_revive.png --frames=150 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --test-at=66,58 --give=stone_a:20,wild_healing:6,mushroom_a:4,torch:3 --test-down --bot="hold:70" --screenshot=shots/m4_death_bag.png --frames=120 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --start-map=dungeon --test-at=23,41 --test-shrine-hp=28 --give=torch:2 --bot="aim:-16,0;use:2;wait:4;select:8;aimat:23,40;use:80;aim:off;move:1,0,30;aimat:23,39;wait:600" --screenshot=shots/m4_shrine_broken.png --frames=200 < /dev/null
```

- M6a 그림 4장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때 봇. 물약 아이콘·조제대는 04-env 그림, 병이 터지는 그림·머리 위 표시·제작 창은 코드 그림 임시):
  - `shots/m6_crafting.png`: 저녁, 제단 서쪽 스폰 자리의 약초사가 남쪽에 조제대를 놓고(제단 빛 안) Tab으로 제작 창을 열었다. 오른쪽 위 창에 레시피 여섯 줄(회복·버프·독 × 일반·상급, 처음 얻은 약초로 해금), 입력 약초 2개 → 물약, 약초사 표시(금빛 = 이 클래스가 만들 수 있음), 만들 수 없는 줄은 어둡게(상급 버프 약초를 다 써서, 독 상급 약초가 없어서), 고른 줄(3, 일반 버프)은 금빛 테. 아래에 인벤토리가 같이 열리고 핫바에 만든 물약 셋(일반 회복, 상급 버프는 금빛 점, 일반 버프). 콘솔 `EVENSONG_CRAFT made ...` 세 줄
  - `shots/m6_throw_poison.png`: 저녁, 약초사가 제단 빛 남쪽 가장자리 안에서 빛 밖의 이단(빛 안의 사람을 노리지 않아 제자리에 선다)에게 상급 독을 던졌다(1, 던지기 동작 중). 이단 둘레에 노란 방울과 녹 반점의 터짐(첫 프레임), 이단 머리 위에 독 표시가 생긴 순간. 콘솔 `throw ... to=1016,910`, `splash ... heretics=1`
  - `shots/m6_poisoned_heretic.png`: 같은 장면을 저녁 끄고(`--no-evening`, 색이 보이게) 160프레임에: 독이 세 번 들어간 이단의 HP 막대와 머리 위 독 표시(막대 위). 이단은 맞아도 경직하지 않고 서 있다(독은 경직이 없다)
  - `shots/m6_buff.png`: 저녁, 팔라딘이 버프 물약을 마시고(마법 동작을 빌려 씀) 동쪽으로 걸었다: 머리 위 호박색 화살, 왼쪽 위 HP·스태미나 막대 밑의 같은 표시와 남은 시간 1px 막대. 핫바 1번에 남은 버프 물약 하나

```bash
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --give=alchemy_table,wild_healing:4,wild_buff:4,wild_poison:3,wild_healing:2:fine,wild_buff:2:fine --bot="aim:0,20;use:1;wait:10;aim:off;tab;wait:6;craft:1;wait:4;craft:4;wait:4;craft:3;wait:30" --screenshot=shots/m6_crafting.png --frames=70 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --test-at=63,53 --test-heretic=63,57 --give=potion_poison:3:fine --bot="aimfoe;wait:4;throw;wait:200" --screenshot=shots/m6_throw_poison.png --frames=40 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --test-at=63,53 --test-heretic=63,57 --give=potion_poison:3:fine --no-evening --bot="aimfoe;wait:4;throw;wait:200" --screenshot=shots/m6_poisoned_heretic.png --frames=160 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=paladin --give=potion_buff:2 --bot="use:1;wait:40;move:1,0,30;wait:10" --screenshot=shots/m6_buff.png --frames=90 < /dev/null
```

- M6b 두 창 그림 `shots/m6b_host.png`, `shots/m6b_client.png` (M6-fix에 다시 찍음): 세션 하나의 두 화면, 저녁, 지상 제단 빛 남쪽 가장자리. 호스트(약초사)가 빛 안 (63,53)에서 빛 밖 이단에게 상급 독을 던지고(1, `aimfoe`), 클라이언트(팔라딘)는 그 이단 동쪽 곁에 서서 2초 기다린 뒤 검으로 싸운다(`wait:120`. M6b 그림은 팔라딘이 둘째 병 전에 이단을 죽여, 호스트 그림의 이단이 죽는 붉은 프레임이고 HP 막대·독 표시가 없었다: README 설명이 틀렸다). 호스트 화면: 둘째 병이 빛 밖 어둠에서 이단 머리 곁으로 날고 있다(unshaded라 제 색. M6b는 어둡게 그려졌다), 이단은 HP 막대(첫 병의 독 한 번, 37)와 머리 위 독 표시, 팔라딘은 그 곁에 서 있음, 호스트의 목표 칸 표시. 클라이언트 화면: 같은 병이 약초사의 손을 막 떠난 순간(남의 병은 100ms 뒤에 그리고, 두 창의 프레임이 정확히 같은 때는 아니다), 이단의 HP 막대와 독 표시, 자기(팔라딘). 클라이언트의 병은 호스트가 보낸 던짐 사건으로 날린 것이다. 프레임 수를 바꿔 가며 찍어(호스트 365·374, 클라이언트 256~305) 두 화면 모두 병이 날고 이단이 살아 독에 걸린 쌍을 골랐다. 찍은 뒤 셋째 병까지 던지고 팔라딘이 이단을 죽인다(호스트 로그 `hit slot=1 ... hp=0 KILLED`, 그 앞의 독 틱 줄은 ` POISON`). 두 로그 오류 줄 0. 포트는 테스트 묶음 밖 24690. 찍은 명령:

```bash
timeout 60 "$GODOT" --max-fps 60 --path game -- --host=24690 --scale=2 --class=herbalist --test-no-spawns --test-heretic=63,57 --give=potion_poison:4:fine --bot="select:1;walkto:63,53;wait:200;aimfoe;wait:4;throw;wait:56;throw;wait:56;throw;wait:3000" --screenshot=shots/m6b_host.png --frames=374 --keep-running --net-timeout=16 < /dev/null &
sleep 2
timeout 60 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24690 --class=paladin --scale=2 --bot="select:8;walkto:66,57;wait:120;fight:3000,0,22" --screenshot=shots/m6b_client.png --frames=280 --keep-running --net-timeout=12 < /dev/null
```

- M5a 그림 4장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때. 작물은 `--test-field`로 놓고(다 자라는 데 몇 분이 걸려서), 일구기·심기·물주기는 봇이 실제로 한다):
  - `shots/m5_field_evening.png`: 저녁, 제단 빛 안. 서쪽 흙 덩어리(M1 생성기)와 남쪽 덩어리, 동남쪽 세 칸에 회복·버프·독초가 0~4단계로 자란다(서쪽 덩어리 가운데 줄과 남쪽 덩어리 일부는 젖은 흙: 칸별로 어두운 덧칠). 약초사가 물뿌리개로 물을 주는 중(동작 가운데 프레임). 더미 넷이 제단 둘레에 서 있다(아처 더미가 남쪽 덩어리 일부를 가린다)
  - `shots/m5_watered.png`: 저녁 끔(색이 보이게). 약초사가 봇으로 빛 안 풀 세 칸(동쪽 세로줄)을 괭이로 일구고 회복 둘·버프 하나를 심고 위·아래 칸에 물을 주었다: 위·아래 칸이 젖은 흙(어둡고 물기 반짝임, 흙더미도 젖은 색), 가운데 칸이 마른 흙. 서쪽 두 덩어리는 `--test-field`로 마른 칸과 젖은 칸을 번갈아 놓았다(작물 칸 포함). 핫바: 괭이·물뿌리개·회복 씨앗 3·버프 씨앗 4·낫
  - `shots/m5_withered.png`: 저녁, 제단 빛 밖 북동쪽 오염 구역(재) 바로 남쪽. `--test-field`로 놓은 작물 여섯(회복·버프·독초, 1~4단계, 둘은 젖음)이 첫 틱에 시들었다(빛 밖 + 오염 2칸 안: 병든 올리브와 잿빛 시든 그림). 팔라딘이 남쪽에 횃불을 놓아 그 빛으로 보인다(횃불은 빛만, 안전 반경이 아님). `shots/m5_withered_off.png`: 같은 장면 저녁 끔(시든 그림의 색이 보이게)

```bash
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --give=watering_can --test-field=57,45:healing:0/58,45:healing:1/59,45:healing:2/57,46:buff:2:wet/58,46:buff:3:wet/59,46:buff:4:wet/57,47:poison:3:fast/58,47:poison:4:fast/59,47:healing:4/58,49:healing:3:wet/59,49:buff:1:wet/60,49:poison:2:fast:wet/58,50:soil:wet/59,50:buff:0/60,50:healing:4/65,51:poison:4:fast/66,51:buff:4/67,51:healing:4:wet --bot="select:1;aimat:59,47;use:30" --screenshot=shots/m5_field_evening.png --frames=36 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --no-evening --class=herbalist --test-at=61,52 --give=hoe,watering_can,seed_healing:5,seed_buff:5 --test-field=58,49:soil:wet/59,49:soil/60,49:soil:wet/58,50:healing:4/59,50:healing:4:wet/60,50:buff:3/57,45:soil:wet/58,45:soil/59,45:buff:2:wet/57,46:soil/58,46:soil:wet/59,46:buff:2 --bot="select:1;aimat:62,51;use:1;wait:40;aimat:62,52;use:1;wait:40;aimat:62,53;use:1;wait:40;select:3;aimat:62,51;use:1;wait:6;aimat:62,52;use:1;wait:6;select:4;aimat:62,53;use:1;wait:6;select:2;aimat:62,51;use:1;wait:52;aimat:62,53;use:1;wait:60" --screenshot=shots/m5_watered.png --frames=330 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=paladin --test-at=72,26 --test-no-spawns --give=torch:2 --test-field=74,25:healing:4/75,25:buff:3:wet/76,25:poison:4/77,25:healing:2/78,25:buff:4:wet/79,24:poison:1/73,25:soil:wet --bot="select:1;aimat:72,27;use:1;wait:20;aimat:76,25;wait:30" --screenshot=shots/m5_withered.png --frames=60 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --no-evening --class=paladin --test-at=72,26 --test-no-spawns --give=torch:2 --test-field=74,25:healing:4/75,25:buff:3:wet/76,25:poison:4/77,25:healing:2/78,25:buff:4:wet/79,24:poison:1/73,25:soil:wet --bot="select:1;aimat:72,27;use:1;wait:20;aimat:76,25;wait:30" --screenshot=shots/m5_withered_off.png --frames=60 < /dev/null
```

- M5b 그림 6장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때 봇. 정화와 제단 옮기기는 봇이 실제로 한다(F, F 누르고 있기, 좌클릭), 작물은 `--test-field`. 채널링 점·금빛 테두리·든 제단·놓을 자리 표시는 코드 그림 자리 표시, 재 얼룩은 04-env 장식):
  - `shots/m5b_purify_channel.png`: 저녁, 북쪽 오염 구역 동쪽 가장자리. 팔라딘이 (60,15)에서 서쪽 재를 겨누고 F로 첫 채널링을 마친 뒤(재 가장자리 9칸이 풀로: 위쪽의 패인 자리) 남쪽 (58,19)로 걸어가 두 번째 채널링을 하는 중: 마법 동작(되풀이)과 반지름 둘레의 금빛 점(진행만큼 켜짐, 저녁에도 제 색)
  - `shots/m5b_purified.png`: 같은 봇, 첫 채널링이 끝난 직후: 정화된 9칸에 줄어드는 금빛 테두리와 재 얼룩, 재 가장자리가 물러났다. `shots/m5b_purified_off.png`: 같은 순간 저녁 끔(풀이 된 칸과 재 얼룩의 색이 보이게)
  - `shots/m5b_altar_carried.png`: 저녁, 약초사가 제단 남쪽에서 F를 2초 눌러 제단을 들고 서쪽으로 걸어가는 중: 빛이 없어 온통 어둡고, 머리 위에 작은 제단, 왼쪽에 놓일 자리(금빛 3×3 테두리 = 놓을 수 있음)와 새 빛 가장자리의 점. 더미 넷은 옛 자리에 있고, 옛 밭(오른쪽 M1 흙)과 새 밭(아래)이 모두 시들었다(빛이 없음)
  - `shots/m5b_altar_moved.png`: 저녁, 제단을 13칸 서쪽 (49,45)에 내려놓은 뒤: 새 자리에 제단과 빛, 더미 넷이 새 부활 자리에서 제단을 보고, 새 빛 안의 밭(아래 두 덩어리, `--test-field`로 처음부터 있던 것: 빛 밖이라 시들었다가 놓은 틱에 되살아남)이 자라고, 옛 빛 자리의 밭(오른쪽, M1 흙)은 빛 밖이라 시든 채 남는다. `shots/m5b_altar_moved_off.png`: 같은 장면 저녁 끔(시든 그림과 자라는 작물의 색)

```bash
BOT="aimat:59,15;wait:2;pick;wait:185;walkto:58,19;aimat:57,19;wait:2;pick;wait:400"
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=paladin --test-at=60,15 --test-no-spawns --bot="$BOT" --screenshot=shots/m5b_purify_channel.png --frames=362 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=paladin --test-at=60,15 --test-no-spawns --bot="$BOT" --screenshot=shots/m5b_purified.png --frames=189 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --no-evening --class=paladin --test-at=60,15 --test-no-spawns --bot="$BOT" --screenshot=shots/m5b_purified_off.png --frames=189 < /dev/null
FIELDS="57,45:healing:4/58,45:buff:3:wet/59,45:poison:4:fast/57,46:healing:2/58,46:buff:4/59,46:healing:3:wet/57,47:poison:2:fast/58,47:buff:1/59,47:healing:4/58,49:healing:4:wet/59,49:buff:3/60,49:poison:4:fast/46,50:healing:3:wet/47,50:buff:4/48,50:poison:4:fast/53,50:healing:4/54,50:buff:2:wet"
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --test-no-spawns --test-field="$FIELDS" --bot="walkto:63,49;aimat:63,48;hold:125;aimat:50,47;walkto:52,48;wait:400" --screenshot=shots/m5b_altar_carried.png --frames=345 < /dev/null
BOT2="walkto:63,49;aimat:63,48;hold:125;walkto:50,48;aimat:50,47;wait:8;use:1;wait:300"
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --test-no-spawns --test-field="$FIELDS" --bot="$BOT2" --screenshot=shots/m5b_altar_moved.png --frames=430 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --no-evening --class=herbalist --test-no-spawns --test-field="$FIELDS" --bot="$BOT2" --screenshot=shots/m5b_altar_moved_off.png --frames=430 < /dev/null
```

- M5c 두 창 그림 `shots/m5c_host.png`, `shots/m5c_client.png`: 세션 하나의 두 화면, 저녁, 시드 1, 스폰 끔. 호스트(약초사)는 제단 빛 안에서 밭을 돌본다(M1 흙의 `--test-field` 작물 다섯, 자기가 심은 독초 (60,49), 클라이언트가 일구고 심은 회복 약초 (62,49): `--test-crop-ticks=240`이라 단계가 다름). 찍는 순간 물뿌리개 동작 중이고 핫바 2번(물뿌리개). 클라이언트(팔라딘)는 같은 밭에 일구고 심은 뒤 북쪽 오염 구역 동쪽 가장자리 (60,15)까지 걸어가 F로 채널링하는 중: 마법 동작과 반지름 둘레의 금빛 점(약 4할 켜짐). 둘 다 같은 세션이다(호스트 로그 `farm slot=1 ... what=till at=62,49`, `channel slot=1 map=0 start at=60,15`, 찍은 뒤 `purify slot=1 ... tiles=9 ... spawn_tiles=666`). 두 로그 오류 줄 0. 클라이언트·호스트는 `--net-timeout`으로 끝난다(종료 코드 6, M4b 두 창 그림과 같음). 포트는 테스트 묶음 밖 24691. 찍은 명령:

```bash
HB="wait:30;walkto:59,48;select:1;aimat:60,49;use:1;wait:10;select:2;aimat:60,49;use:2;wait:40;aimat:60,50;use:3000"
CB="wait:30;walkto:66,51;walkto:61,51;walkto:61,49;select:1;aimat:62,49;use:2;wait:40;select:2;use:1;wait:10;walkto:66,49;walkto:66,16;walkto:60,15;aimat:59,15;pick;wait:400"
timeout 90 "$GODOT" --max-fps 60 --path game -- --host=24691 --scale=2 --class=herbalist --test-no-spawns --give=seed_poison:3,watering_can --test-crop-ticks=240 --test-field=57,45:healing:3:wet/58,45:buff:4:wet/57,46:poison:2:fast:wet/58,49:healing:1/59,49:buff:2 --bot="$HB" --screenshot=shots/m5c_host.png --frames=1100 --keep-running --net-timeout=24 < /dev/null &
sleep 2
timeout 90 "$GODOT" --max-fps 60 --path game -- --join=127.0.0.1:24691 --class=paladin --scale=2 --give=hoe,seed_healing:1 --bot="$CB" --screenshot=shots/m5c_client.png --frames=980 --keep-running --net-timeout=20 < /dev/null
```

- M7a 그림 3장 (모두 시드 1, 480×270, 창 960×540, 혼자 할 때 봇. 작업대·창고는 04-env 그림, 아이콘·막대·갑옷 칸·창고 창은 코드 그림 자리 표시):
  - `shots/m7_stations.png`: 저녁, 제단 빛 안 남쪽 줄(51)에 광부가 봇으로 놓은 기본 작업대(59..61)·모루(62..63)·성물 제작대(65..67, 촛불이 탐). 모루 바로 남쪽에서 Tab: 오른쪽 위 모루 창(98px, 줄 아홉: 구리·철 제련, 1티어 검·활·성광·곡괭이·낫, 갑옷, 성물 제작대. 재료 셋인 줄까지, 만들 수 없는 줄은 어둡게, 첫 줄 금빛 테)과 열린 인벤토리(핫바 왼쪽에 빈 갑옷 칸 윤곽). 더미 셋이 작업대 앞에 선다. 콘솔 `place item=workbench ... at=60,51` 등 셋, `EVENSONG_CRAFT open station=anvil at=62,51 recipes=9`
  - `shots/m7_chest.png`: 저녁, 약초사가 제단 남쪽 빛 안 (62..64, 51)에 창고를 놓고 F로 열어 돌 40·상급 회복 약초 6·닳은 1티어 검(50/120, 호박색 막대)·철 주괴 3을 넣었다(봇 `store`). 인벤토리 격자 위에 창고 창(머리 = 창고 아이콘), 인벤토리에 남은 통나무·구리광석, 핫바 8번 낫
  - `shots/m7_worn_gear.png`: 저녁, 빛 밖 남쪽. 팔라딘이 닳은 1티어 검으로 이단을 치는 중(첫 칼에 맞아 HP 92: 갑옷이 12 → 8). 핫바: 1티어 검(70/120 → 휘두른 뒤 69, 금빛 막대)·1티어 활(40, 호박색)·1티어 성광(0, 부서짐: 녹빛 막대 전체)·빈 칸(갑옷을 입어서)·1티어 낫(15, 녹빛)·…·8번 기본 검. 핫바 왼쪽 갑옷 칸에 입은 갑옷(30/100, 호박색 막대). 1티어 아이콘의 왼쪽 위 금빛 표시

```bash
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=miner --give=workbench,anvil,relic_bench,planks:12,ingot_iron:6,ingot_copper:4,ore_copper:3,ore_iron:2 --bot="select:1;walkto:60,52;aimat:60,51;use:1;wait:6;select:2;walkto:63,52;aimat:63,51;use:1;wait:6;select:3;walkto:66,52;aimat:66,51;use:1;wait:6;walkto:63,52;aim:off;wait:10;tab;wait:400" --screenshot=shots/m7_stations.png --frames=330 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=herbalist --give=storage_chest,stone_a:40,wild_healing:6:fine,sword_t1,log:12,ingot_iron:3,ore_copper:7 --test-durability=4:50 --bot="select:1;walkto:63,52;aimat:63,51;use:1;wait:6;pick:1;wait:6;store:2;wait:2;store:3;wait:2;store:4;wait:2;store:6;wait:400" --screenshot=shots/m7_chest.png --frames=150 < /dev/null
timeout 120 "$GODOT" --max-fps 60 --path game -- --class=paladin --give=sword_t1,bow_t1,holy_light_t1,armor_t1,sickle_t1 --test-durability=1:70/2:40/3:0/4:30/5:15 --test-wear=4 --test-select=1 --test-at=63,56 --test-heretic=65,56 --test-no-spawns --bot="aimfoe;use:600" --screenshot=shots/m7_worn_gear.png --frames=62 < /dev/null
```

### 그림 검사 (창, 렌더러 필요)

헤드리스 테스트는 더미 렌더러라 화면을 못 본다. 빛·불꽃·캐릭터 레이어·y 정렬이 **실제로 그려진 픽셀**을 보는 검사는 따로 창을 띄워 돌린다 (창이 3초쯤 떴다 닫힌다).

```bash
timeout 180 "$GODOT" --path game --script res://tools/check_render.gd < /dev/null
```

- 부분마다 `EVENSONG_RENDER <부분> ok|FAIL ...`, 끝에 `EVENSONG_RENDER done ok failed_parts=0`. 종료 코드 0 / 하나라도 틀리면 1 (차이 그림을 `game/build/render_check/`에 남김) / `--headless`면 2
- `-- --save`를 붙이면 통과해도 찍은 그림(바닥 저녁 켬·끔, 리그 10장, y 정렬)을 모두 남긴다. 사람이 표식 위치를 눈으로 볼 때 쓴다 (`rig_<walk|idle>_<프레임>_got.png`: 칸 = 클래스, 줄 = 남·동·북·서)
- `ground`: 제단 둘레 화면 480×270 픽셀 전부를 저녁 켬·끔으로 두 번 찍어 색 비율로 밝음/어둠을 가르고, 바닥 빛 텍셀(= 규칙, `test_light.gd`가 텍셀마다 확인)과 비교. 테두리 띠 ±8px 고리(약 2만 픽셀)는 따로 센다. 반경 밖에 밝은 픽셀 0
- `flames`: 불꽃 81픽셀이 저녁에도 원본 색 그대로 (채널 차 0)
- `actor`: 반경선이 몸을 지나가게 세운 캐릭터의 픽셀마다 밝음 = `is_in_safe_zone(픽셀 중심)` (캐릭터는 디더가 아니라 hard 빛)
- `rig`: 5클래스 × 4방향 × (걷기 6 + idle 4 + M2a 몸 동작 8개의 55) 프레임을 저녁 끈 화면에 세워, 배경 + 시트에서 CPU로 합친 그림과 픽셀까지 비교 (그리기 순서, v01→v02 이동 + 기준점, 서쪽 반전, 64칸 동작의 발 맞춤, 손에 든 표식 숨기기). 한 화면에 캐릭터 20명, 65화면
- 일부러 깨 본 것 (M2a): 캐릭터가 64칸 동작 칸의 (16, 16)을 빼먹고 32칸처럼 놓음 → `rig` FAIL(65화면 중 불일치 655,477픽셀)·종료 1
- M4a: `rig`이 피격 6·사망 7프레임까지 78화면이 됐다(사망 프레임은 표식을 숨긴 합성과 비교). `heretic`: 이단 시트 다섯의 모든 프레임을 네 방향(한 화면에 32명: 줄 = 남·동·북·서, 칸 = 프레임)으로 세워 배경 + CPU 합성(그 줄의 시트 칸, 32칸은 (16, 32)·64칸은 (32, 48)을 발에, 서쪽은 동쪽 반전)과 픽셀까지 비교하고, 반쯤 다친 이단의 HP 막대(unshaded)를 그 픽셀까지. `bars`: HUD의 HP 60/100·스태미나 20(대시 비용 밑이라 어두운 금빛) 막대 396픽셀과 사망 뒤 카운트다운 숫자(3배) 81픽셀이 정한 색 그대로. 일부러 깨 본 것은 아래 "측정"의 M4a
- `combat_net` (M4b): 세션 클라이언트가 그리는 호스트의 싸움. 이단 다섯(예고 중·피격 중 HP 막대와 깜빡임·죽는 중·쫓는 중·가장자리 대기), 화살과 빛 탄, 다운된 플레이어(다운·소생 막대)를 호스트의 `CombatView`가 자기 아레나로 그린 화면과, 클라이언트가 전송 형식(적 묶음, 화살 사건, vitals 블록이 있는 상태)을 풀어 `NetCombat`·Player로 그 틱에 그린 화면이 픽셀까지 같아야 한다(그리고 배경과 2,000픽셀 넘게 달라야: 실제로 그렸다). 일부러 깨 본 것: 클라이언트가 이단의 깜빡임을 버림 → 불일치 725, 남의 vitals를 안 그림 → 544, 화살 방향 1/16바퀴 어긋남 → 53. 셋 다 FAIL·종료 1
- `crafting` (M6a): HUD의 제작 창을 약초사(여섯 줄 모두 만들 수 있게 약초를 줌)와 팔라딘(넷이 어둡게)으로 열어, 창이 그리는 불투명 픽셀(바깥·안쪽 테, 조제대 아이콘과 금빛 밑줄, 줄마다 입력·출력 칸의 테와 아이콘(수·상급 점 자리 빼고), 수 숫자 자리, 상급 점, 화살표, 약초사 표시, 고른 줄의 금빛 테) 3,818개가 그 자리 그 색인지, 어두운 줄의 밝은 픽셀(아이콘·화살표·숫자, 943개)이 모두 원래보다 어두운지. 반투명 바탕(`Hud.FILL`)은 섞기 반올림 때문에 보지 않는다(`bars`와 같은 이유)
- `potions` (M6a): 저녁 끄고 한 화면에 세계 편집으로 놓은 조제대, 독 걸린 이단(시트 프레임 + 머리 위 독 표시), 반쯤 날아간 병(물약 아이콘, 포물선 높이), 터짐 둘(0·1프레임)을 그려 배경 + 각각의 CPU 합성과 픽셀까지 비교(조제대 자리는 `FixtureView.table_origin`을 쓰지 않고 그림의 마지막 불투명 줄을 재서 따로 계산). 그다음 버프·독이 걸린 성직자의 머리 위 표시 둘과 HUD의 효과 아이콘·남은 시간 막대 126픽셀이 그 자리 그 색인지. 일부러 깨 본 것: 화살표를 금빛으로(`crafting` 불일치 72), 터짐 1px(`potions` 135), 머리 위 표시 1px 아래(23 · 표시 35), 조제대 그림 1px 위(484). 넷 다 FAIL·종료 1. 조제대는 처음에 기대 그림을 같은 함수로 만들어 통과해 버렸고(M4a의 교훈과 같은 실수), 따로 계산하게 고쳤다. M6-fix: 그다음 저녁을 켜고 같은 화면을 다시 찍어, 병·터짐의 불투명 픽셀 197개(병 92)가 제 색 그대로(unshaded)이고 둘레 바닥은 어두워졌는지(8px 간격 표본 2,039개가 저녁 끔의 66% 밑). 일부러 깨 봄: 병을 shaded로 되돌리면 `dark_mismatches=92`로 FAIL·종료 1
- `potions_net` (M6b): 세션 클라이언트가 그리는 호스트의 물약. 기록을 켠 진짜 호스트 아레나에서 약초사가 병 둘을 던졌다(하나는 몇 틱 전에 터져 터짐이 보이고, 하나는 날고 있음), 독 걸린 이단, 버프·독이 걸린 성직자. 호스트의 `CombatView`·Player가 그린 화면과, 클라이언트가 전송 형식(독 표시가 든 적 묶음, 던짐·터짐 사건, 효과 블록이 든 상태)을 풀어 `NetCombat`·Player로 그 틱에 그린 화면이 픽셀까지 같아야 하고, 병·터짐이 하나씩, 이단의 독 표시와 성직자의 표시 둘이 있어야 한다. 그다음 월드 스냅샷으로 받은 조제대 옆에서 인벤토리 메시지로 받은 인벤토리로 연 제작 창 = 혼자 할 때 같은 인벤토리로 연 창(픽셀, 줄 넷). 일부러 깨 본 것은 아래 "측정"의 M6b
- `fields` (M5a): 저녁 끄고 제단 둘레 화면에서 빛 안의 칸을 모두 흙으로(풀이면 바닥 편집으로 일굼, 시드 1: 120칸 중 101칸) 만들고 엔티티를 숨겨 찍은 바닥 = 그림 칸마다 그 칸이 그린 타일을 **PNG 파일에서 읽어** 붙인 CPU 합성(흙이 흙으로 그려짐). 그다음 작물 열여덟(세 작물 × 0~4단계·시듦, 넷에 하나는 젖음)과 젖은 빈 흙 여섯을 놓아 찍은 화면 = 그 바닥 + 젖은 칸마다 네 사분면(그 꼭짓점 둘레 그림 칸이 그린 타일의 물 준 PNG에서) + 작물(시트 PNG의 그 칸, 흙더미 색은 이 검사에 따로 적은 색 표로 마른·물 준 흙에 맞춤), 픽셀까지. 그다음 저녁을 켜고 빛 안쪽(반경 − 테두리 띠 − 4px)의 젖은 칸·작물 픽셀이 모두 밝은지(물 준 덧칠은 바닥 빛 레이어, 작물은 캐릭터 빛 레이어). 일부러 깨 본 것은 아래 "측정"의 M5a
- `purify` (M5b): 저녁 끄고 오염 구역의 남쪽 가장자리에서(엔티티 숨김) 채널링 하나가 정화할 칸을 월드 편집으로 정화한 바닥 = 그림 칸마다 그 칸이 그린 타일을 PNG에서 읽어 붙인 CPU 합성(정화된 칸은 풀, 구역의 새 가장자리는 풀↔재 타일). 그다음 정화 첫 프레임: 그 바닥 + 정화된 칸마다 재 얼룩(04-env 장식 PNG, 이 검사에 따로 적은 고르기 규칙, 칸 가운데) + 칸 테두리 금빛 1px, 픽셀까지. 저녁을 켜면 금빛은 제 색 그대로(unshaded), 재 얼룩은 어두워짐(바닥 빛 레이어). 그다음 채널링 마지막 틱의 점 16개(2×2 금빛, 왼쪽 위 상아빛)가 반지름 + 0.5칸 고리의 이 검사에 따로 적은 자리에 있고 그 64픽셀만 바뀜(저녁 켬). 일부러 깨 본 것은 아래 "측정"의 M5b
- `altar` (M5b): 제단을 월드 편집으로 13칸 서쪽에 옮기고(엔티티는 제단만) 새 자리 둘레 화면 픽셀 전부를 저녁 켬·끔으로 찍어 밝음 = 새 영역의 바닥 빛 텍셀(`ground`와 같은 규칙. 화면 안의 옛 영역 픽셀 약 3.9만 개는 모두 어두움, 불꽃 81픽셀은 제 색). 그다음 제단을 든 플레이어의 머리 위 표시 46픽셀이 이 검사에 따로 적은 문자 지도 그대로 그 자리에(저녁 켬·끔 둘 다, unshaded), 놓을 자리 표시의 테두리와 빛 가장자리 점이 금빛(됨)·짙은 빨강(안 됨)으로 그 자리에. 끝나면 제단을 제자리로
- `fields_net` (M5c): 세션 클라이언트가 그리는 호스트의 밭·정화·든 제단. 호스트 월드를 진짜 규칙으로 농사짓고(`Farm`: 네 클래스가 일구고 심고, 물 주고, `stage_ticks_base` 20으로 70틱 자람) 반쯤에서 찍은 지상 스냅샷으로 클라이언트 월드를 만들고, 나머지(제단을 들어 13칸 서쪽에 놓음 → 밭이 시듦, 북쪽 구역 가장자리의 채널링 정화)를 실시간 편집으로(클라이언트는 `SessionClient.on_edit`처럼 오염 0 편집에서 깜빡임). 호스트의 운반자·채널링하는 팔라딘과, 상태 묶음(든 비트, 동작 비트의 채널링)을 풀어 만든 클라이언트의 그 둘 + 채널링 점. 옛 밭 둘레와 구역 가장자리에서 두 화면이 픽셀까지 같고(저녁 끔) 맨 월드와 1,500픽셀 넘게 다르고, 클라이언트의 점 11개가 제 자리 제 색. 일부러 깨 본 것은 아래 "측정"의 M5c
- `stations` (M7a): 저녁 끄고 월드 편집으로 기본 작업대·모루·성물 제작대·창고를 한 줄에 놓아(불꽃은 0프레임에 붙잡음) 찍은 화면 = 배경 + 각 그림을 이 검사에 따로 적은 자리(자리 가운데, 그림에서 잰 마지막 불투명 줄이 자리의 마지막 픽셀 줄)에 붙인 것 + 성물 제작대 그림의 (37, −4)에 작은 불꽃 0프레임, 픽셀까지. 일부러 깨 본 것은 아래 "측정"의 M7a
- `gear_hud` (M7a): 닳은 1티어 장비(가득·금빛·호박색·녹빛·부서짐)를 든 핫바와 입은 갑옷(30/100)의 HUD: 막대 140픽셀(14×2, 색과 너비 규칙은 이 검사에 따로 적음)과 갑옷 칸(핫바 왼쪽 6px, 테·아이콘)이 그 자리 그 색, 가득 찬 칸에는 막대 없음
- `m7_panels` (M7a): 인벤토리를 연 채 창고 창(자리 = 인벤토리 격자 위, 테·머리 아이콘·밑줄·칸 16·아이콘·수 빼고·닳은 활의 막대)과, 모루 창(재료 하나·둘·셋인 줄과 닳은 검의 수리 줄, 98px로 넓어진 창의 자리, 칸·화살표는 이 검사에 따로 적은 배치)의 불투명 픽셀 전부(만들 수 없어 어두운 줄은 빼고)
- `items` (M2b): 채집물이 가장 많이 보이는 화면(시드 1: 9개)과 드롭 하나를 저녁 끈 채 찍어, 그것들을 숨긴 화면 + 각자의 그림(월드 그림 / 아이콘)을 그 칸에 놓은 것과 픽셀까지 비교. 일부러 깨 봄: 그림을 1px 내리면 FAIL(불일치 1,054픽셀)
- `cave` (M3a): 시드 1 던전의 도착 방 둘레를 어둠 끄고(엔티티 숨김) 찍어, 그림 칸마다 `CaveView.drawn_at`의 절벽 타일 + 광맥·금 오버레이를 CPU로 합친 그림과 픽셀까지 비교. 그 전에 벽을 깎아 둔다(앞면이 있는 벽 셋에 금 1·2·3단계, 옆 벽 하나에 1단계, 앞면 벽 하나는 깨서 앞면이 한 칸 위로). 지상 월드는 그동안 숨긴다
- `dark` (M3a): 같은 던전에 횃불 하나를 놓고(다른 빛은 끄고 다른 엔티티는 숨김) 어둠 켬·끔 두 번 찍어, 횃불 반경 밖 픽셀은 모두 어둡고(비율 ≤ 0.3) 첫 단계(반경의 45%) 안 픽셀은 모두 밝은지(≥ 0.75), 그 자리가 안전 반경이 아닌지(빛일 뿐)
- `cave_net` (M3b): 세션 클라이언트가 받는 던전. 호스트의 시드 1 던전을 진짜 규칙(`Mining.strike`: 광부 3×3 금 1단계, 공용 3·5번으로 금 2·3단계, 광부 3×3 깸)으로 캐며 편집마다 호스트 그림에 적용하고, 반쯤에서 찍은 지도 스냅샷(`WorldSnapshot` → `Receiver.finish`(던전))으로 만든 클라이언트 월드에 나머지를 실시간 편집으로 적용한다. 두 화면(어둠 끔, 엔티티 숨김)이 픽셀까지 같고 클라이언트 데이터의 CPU 합성(타일 + 광맥·금 오버레이)과도 같아야 한다
- `ysort`: 겹친 두 캐릭터(나중에 추가한 쪽이 뒤), 제단 뒤·앞의 캐릭터가 발 y 순서대로 그려지는지. 트리 순서로 그렸다면 틀렸을 픽셀(지금 516개)이 0보다 커야(= 검사가 실제로 겹침을 본다) 통과
- `ysort`는 H1부터 캐릭터 둘을 더 세운다: `Movement`로 제단 서쪽·동쪽 면까지 걸어가 붙은 광부(동쪽을 봄)와 아처(서쪽을 봄). 제단 뒤에 그려지지만 그 픽셀이 제단 그림에 하나도 겹치지 않아야 한다(`side_pixels_hidden=0`)
- 일부러 깨 본 것 (G2, 커밋하지 않음): 서쪽 반전 끄기, 한 프레임의 표식 1px 밀기, 캐릭터 빛을 디더로, 캐릭터를 월드 빛 레이어로, 불꽃 shaded, 빛 `texture_scale` 1.02, 빛 위치 1px, y 정렬 끄기. 8개 모두 해당 부분이 FAIL·종료 1. H1: 제단 옆 띠를 0으로 → `ysort` FAIL(`side_pixels_hidden=27`)·종료 1

### 명령줄 인자 (`--` 뒤, `core/cli_options.gd`)

| 인자 | 뜻 | 지금 |
|---|---|---|
| `--smoke` | 스모크 검사 후 한 줄 출력, 통과 0 / 실패 1 | 동작 |
| `--seed=<n>` | 월드 시드 (기본 1) | 동작 |
| `--screenshot=<파일.png>` `--frames=<n>` | 위 스크린샷 | 동작 |
| `--scale=<n>` | 창 = 480×270 × n (헤드리스에서는 무시) | 동작 |
| `--overlay` | 디버그 선을 켠 채 시작 | 동작 |
| `--no-evening` | 저녁 어둠과 제단 빛을 끈 채 시작 (F4로 다시 켬) | 동작 |
| `--keep-running` | `--screenshot`을 찍은 뒤 끝내지 않고 계속 (세션 창 두 개를 찍을 때 먼저 찍은 쪽이 나가지 않게) | 동작 (G3) |
| `--class=<paladin\|miner\|archer\|cleric\|herbalist>` | 내 클래스 (기본 paladin). 혼자일 때 나머지 넷은 더미 | 동작 |
| `--host[=<port>]`, `--join=<주소>[:<port>]` | 호스트 / 참가 (기본 포트 24600, IPv6는 `[::1]:24600`). 세션에서는 더미가 없다 | 동작 (G3) |
| `--transport=<enet\|steam>` | 전송 계층 (기본 enet). steam은 M1에서 자리만 있어 "unavailable"로 실패한다 | 동작 |
| `--bot=<스크립트>` | 내 캐릭터를 키 대신 스크립트로: `wait:<틱>`, `move:<dx>,<dy>,<틱>`, `edit:<x>,<y>,<grass\|soil>`(호스트만), `mark:<이름>`, `leave`(클라이언트), `stall:<ms>`(테스트 전용, H-fix: 그 틱 뒤 `_process`에서 프로세스를 1..5000ms 멈춤 = 긴 프레임), `;`로 잇는다 (`net/net_bot.gd`). M2b: `walkto:<x>,<y>[,<틱>]`(그 칸 가운데로 걸어감), `aim:<dx>,<dy>`·`aim:off`(발에서 그만큼 떨어진 곳을 조준 / 끔), `aimat:<x>,<y>`(그 칸 가운데를 조준), `use:<틱>`(좌클릭을 누르고 있음), `pick[:<번>]`(매 틱 F), `select:<1..8>`, `drop[:<개수>]`, `give:<id>[:<수>[:<등급>]]` | 동작 |
| `--start-map=<surface\|dungeon>` | 혼자 할 때 그 지도에서 시작(던전이면 도착점) | 동작 (M3a) |
| `--bot=` `waitmap:<인원>,<지도>[,<틱>]` | M3b: 이 기기가 아는 그 지도(`surface`/`dungeon`/0/1)의 플레이어가 그 수 이상일 때까지 서서 기다림(기본 최대 1800틱). `pick`(F)은 입구·계단을 겨누면 지도를 옮긴다(세션에서는 TRAVEL 요청) | 동작 (M3b) |
| `--bot=<스크립트>` (혼자 할 때) | M3a: 세션이 아니어도 봇이 키·마우스 대신 내 캐릭터를 움직인다(`pick`은 F와 같아서 입구·계단에서는 지도를 옮긴다). 스크린샷·테스트용 | 동작 (M3a) |
| `--bot=` `dash:<dx>,<dy>`, `hold:<틱>` | M4a: 이 틱에 Space(그 방향을 누른 채, 0,0이면 바라보는 쪽) / 그 틱 수만큼 F를 누르고 서 있음(소생, 다운 중이면 포기). M4b부터 세션에서도 | 동작 (M4a, 세션 M4b) |
| `--bot=` `aimfoe`, `fight:<틱>[,<n>[,<px>]]`, `closein:<px>[,<틱>]`, `waitfoe:<n>[,<틱>]`, `waitlife:<alive\|down\|dead>[,<틱>]`, `waitdown:<n>[,<틱>]`, `walkdown[:<틱>]` | M4b(혼자 할 때도): 이 기기가 그리는 이단 기준. 가장 가까운 살아 있는 이단을 계속 조준 / 그 이단을 조준하고 좌클릭을 누르고 있음(살아 있는 이단이 n마리 이하가 되거나 틱이 다할 때까지, px를 주면 그보다 멀면 다가감 = 근접) / px 안까지 다가감 / 살아 있는 이단이 n마리 이하가 될 때까지 / 내 캐릭터가 그 상태가 될 때까지 / 이 지도에 다운된 사람이 n명 이상일 때까지 / 가장 가까운 다운된 사람 옆(12px)으로 걸어감 | 동작 (M4b, 세션 시험·스크린샷용) |
| `--bot=` `tab`, `craft:<줄>`, `throw` | M6a: 이 틱에 Tab(조제대 옆이면 제작 창, 아니면 인벤토리) / 열린 제작 창의 그 줄(1 = 맨 위) 만들기 / 이 틱에 스킬 키 1(약초사가 고른 물약을 지금 조준 쪽으로 던짐. `aimfoe`·`aim`·`aimat`과 같이). M6b: 세션에서도(Tab·만들기는 `NetSession.bot_ui`로 Main에, 만들기는 CRAFT 요청, 던지기는 THROW 프레임) | 동작 (M6a; 세션 M6b, 스크린샷·시험용) |
| `--test-at=<x>,<y>` | 혼자 할 때 시작 지도의 그 칸에 내 캐릭터(발은 칸 아래쪽, 도착점 규칙) | 동작 (스크린샷·시험용, M4a) |
| `--test-heretic=<x>,<y>[/<x>,<y>...]` | 시작할 때 시작 지도의 그 칸들에 이단 | 동작 (스크린샷·시험용, M4a) |
| `--test-down` | 내 캐릭터가 다운된 채(0 HP) 시작 | 동작 (스크린샷용, M4a) |
| `--test-ally=<클래스>[:down]` | 내 옆(18px 동쪽)에 입력 없는 동료 플레이어, `:down`이면 다운된 채 | 동작 (스크린샷·시험용, M4a) |
| `--test-shrine-hp=<n>` | 던전 시작이면 이단의 제단 HP를 n으로. M4b: 호스트면 던전 아레나의 제단 HP. M4-fix: n은 1..`SHRINE_HP`(150), 넘으면 CLI 오류 | 동작 (스크린샷용, M4a; 호스트 M4b) |
| `--test-heretic=...` (호스트) | M4b: 호스트면 지상 아레나의 그 칸들에 이단 | 동작 (세션 시험·스크린샷용, M4b) |
| `--test-dungeon-heretic=<x>,<y>[/...]` | 던전의 그 칸들에 이단(혼자 할 때, 호스트) | 동작 (시험용, M4b) |
| `--test-no-spawns` | 이단 스폰 끔(혼자 할 때, 호스트. 시험 이단은 그대로) | 동작 (시험용, M4b) |
| `--test-start-hp=<클래스>:<hp>[,...]` | 호스트: 그 클래스의 멤버가 그 HP로 시작(한 번 맞으면 다운되게) | 동작 (세션 시험용, M4b) |
| `--test-field=<x>,<y>:<soil\|healing\|buff\|poison>[:<0..4>][:wet][:fast][/...]` | M5a: 시작할 때 시작 지도의 그 칸들을 일군 흙으로, 그리고 그 작물(단계, 젖음, 약초사가 심음)을. 농사 규칙을 건너뛴다(빛 밖도 됨), 재 옆(그림 규칙)만 거부. 빛 밖·오염 옆의 작물은 첫 농장 틱에 시든다. M5c: 호스트면 그 지상에(참가자는 스냅샷으로 받는다) | 동작 (스크린샷·시험용, M5a; 호스트 M5c) |
| `--test-crop-ticks=<1..2400>` | M5c: 작물 한 단계에 드는 자란 틱을 `CROP_STAGE_TICKS` 대신 이 값으로(약초사의 것은 그대로 `CROP_HERBALIST_GROWTH_PCT`만큼 빠름). 혼자 할 때와 호스트의 농장(`Farm.stage_ticks_base`). 세션 시험이 몇 초 안에 익는 것을 보려고 | 동작 (시험·스크린샷용, M5c) |
| `--bot=` `waitfield:<x>,<y>,<soil\|0..4>[,<틱>]` | M5c: 이 기기의 월드에서 그 칸이 일군 흙이거나(soil) 그 단계 이상의 시들지 않은 작물일 때까지 서서 기다림(기본 최대 1800틱). 혼자 할 때도 | 동작 (M5c, 세션 시험·스크린샷용) |
| `--test-durability=<1..24>:<n>[/...]` | M7a: 시작할 때(`--give` 뒤) 인벤토리 그 칸(1부터) 아이템의 남은 내구도(내구도 있는 것만, 최대치까지) | 동작 (스크린샷·시험용, M7a) |
| `--test-wear=<1..8>` | M7a: 시작할 때 핫바 그 칸의 갑옷을 입는다(`--test-durability` 뒤) | 동작 (스크린샷용, M7a) |
| `--bot=` `store:<n>`, `take:<n>`, `unequip` | M7a(혼자 할 때): 열린 창고 창에서 인벤토리 칸 n(1 = 핫바 첫 칸) 클릭 = 넣기 / 창고 칸 n 클릭 = 꺼내기 / 갑옷 칸 클릭 = 벗기 | 동작 (M7a, 스크린샷·시험용) |
| `--max-players=<1..9>` | 호스트: 인원 상한을 낮춘다 (테스트용. 9보다 높일 수 없다) | 동작 |
| `--net-out=<폴더>`, `--net-name=<이름>` | 테스트 인스턴스: 결과 JSON·표시 파일을 쓰고 세션이 끝나면 종료 | 동작 |
| `--net-start=<n>`, `--net-expect=<n>`, `--net-expect-refused=<n>` | 호스트: 클라이언트 n명이 오면 봇 시작 / n명이 봇을 마치거나 나가고 n번 거부했으면 세션 끝 | 동작 (테스트) |
| `--net-timeout=<초>` | 그 시간이 지나면 종료 코드 6 (테스트가 멈춰 있지 않게) | 동작 |
| `--net-lag=<ms>`, `--net-loss=<%>` | 클라이언트: 왕복 지연·손실 흉내 (unreliable 입력·상태만) | 동작 |
| `--test-perturb-generator` | 이 프로세스의 생성기가 같은 시드로 다른 월드를 만든다(재 가장자리 노이즈 시드를 바꿈, `SurfaceGen.test_perturb`). 다른 아키텍처 흉내 | 동작 (테스트 전용, H1) |
| `--test-snapshot-chunk-bytes=<1..1024>` | 호스트: 월드 스냅샷을 이 크기 조각으로 자른다(`WorldSnapshot.chunk_bytes`, 기본 1024). 작은 월드도 여러 조각·여러 틱으로 보내 보려고 | 동작 (테스트 전용, H1) |
| `--give=<id>[:<수>[:<등급>]],...` | 디버그: 시작할 때 내 인벤토리에 아이템을 넣는다. id는 아래 "아이템 표", 등급 `common`/`fine`은 약초만(M6a: 물약도, 예 `potion_poison:3:fine`. 조제대는 `alchemy_table`). 예 `--give=pickaxe,stone_a:30,wild_healing:3:fine`. 게임 안에서는 F5가 디버그 묶음을 준다. M2b: 호스트는 자기 인벤토리에 바로, 클라이언트는 호스트에게 주기 요청을 보낸다(호스트가 디버그 빌드이거나 `--test-allow-give`일 때만 받아 준다). 요청 하나의 개수는 1바이트라 255개를 넘으면 여러 요청으로 나눈다(M2-fix: 전에는 300이 44로 잘렸다). 기다리는 요청은 `NET_LOCAL_OPS_MAX` 64개까지, 넘는 것은 `request_dropped` 줄을 찍고 버린다 | 동작 (M2a, M2b) |
| `--test-allow-give` | 호스트: 내보낸(release) 빌드에서도 클라이언트의 디버그 주기·버리기(F7) 요청을 받아 준다 (세션 시험을 내보낸 exe로 돌릴 때, 사람이 두 기기로 해 볼 때) | 동작 (M2b, 버리기는 M2-fix) |
| `--test-select=<1..8>` | 시작할 때 핫바 칸 고르기 | 동작 (스크린샷용, M2a) |
| `--test-inventory` | 인벤토리 칸 전부 보기(Tab)를 연 채 시작 | 동작 (스크린샷용, M2a) |
| `--test-aim=<dx>,<dy>` | 마우스 대신 발에서 이만큼(px) 떨어진 곳을 늘 조준 | 동작 (스크린샷·테스트용, M2a) |
| `--test-action=<동작>[:<프레임>]` | 내 캐릭터가 그 몸 동작(`pickaxe`·`hoe`·`sickle`·`watering`·`sword`·`bow`·`magic`·`throw`)의 한 프레임(1부터, 기본 가운데)에 멈춘다. 입력은 받지 않는다 | 동작 (스크린샷용, M2a) |
| `--test-action-lineup[=<프레임>]` | 더미 대신 내 클래스가 몸 동작 8개를 두 줄(남쪽·동쪽)로 한 프레임(1..6, 기본 동작마다 가운데)에 멈춰 서 있고, 내 캐릭터는 숨긴다 | 동작 (스크린샷용, M2a) |

아는 인자의 값이 틀리면 `EVENSONG_CLI error: ...`를 찍고 종료 코드 2. 모르는 인자는 무시한다 (테스트 러너의 `--only=` 등이 같은 명령줄로 들어오기 때문).
세션 종료 코드: 0 끝남·나감, 3 거부됨, 4 접속 실패·호스트 잃음(`--net-out`일 때), 5 받은 월드가 검사를 통과하지 못함(조각 수·크기·md5·월드 해시), 6 `--net-timeout`.
테스트 러너 인자(`run_all.gd`, `--` 뒤): `--only=`, `--timeout=`, `--dir=`, `--prefix=`, `--port-base=<n>`(테스트 포트 묶음), `--ports-from-parent=<n>`(자식 러너용: 부모가 잡은 묶음), `--net-exe=`, `--net-full`, `--net-keep`, `--net-sessions=<a,b>`(M3b: 그 세션만, pair·four·lag·stall·cave·full. M4b: `test_net_fight.gd`의 fight·fight4, M4-fix: fightlag).

### 스모크 (`--smoke`, `core/smoke.gd`)

고정 문자열이 아니라 실제로 확인한다. 하나라도 틀리면 `EVENSONG_SMOKE FAIL <n> failure(s) ...`과 종료 코드 1.
엔진 4.7.2, 렌더러 설정 forward_plus, 루트 창에 실제로 적용된 480×270·viewport·integer·expand·Nearest·픽셀 스냅, 기본 창 1920×1080, 이동 키 배치,
커밋된 타일셋(소스 11, 타일 40, 그림 있는 코너 키 31, 키마다 그림 유무가 규칙과 같은지), 기본 시드 월드(크기, 제단 자리, 흙·재 있음, 흙+재 칸 0, 월드 해시 = `SurfaceGen.GOLDEN_HASH`)를
실제로 그려서 그림 칸 12,513개 전부의 코너가 데이터와 같은지(대체 타일 0, 빈 칸 0),
캐릭터 시트 크기와 클래스 다섯의 표식 레이어(리그를 만들어 표식이 보이는지), 기준점 표의 모양(이제 걷기·idle + 몸 동작 8개), `main.tscn`이 불러지는지,
M2a: 몸 동작 시트 8장의 크기(칸 × (시작 칸 + 프레임), 칸 × 3줄), 아이템 22개의 아이콘(16×16, 그림 또는 코드로 그린 것)과 월드 그림, 도구 6개의 몸 동작, M2a 입력 액션 6개,
M2b: 기본 월드의 채집물 수(= 임시값 표의 합 74), 채집물 15종의 월드 그림, F·F7 입력 액션, 드롭이 든 스냅샷 왕복, 요청이 붙은 입력 프레임 왕복,
M3a: 기본 월드의 던전 입구, 던전 타일셋(소스 2, 타일 30, 그림 있는 코너 키 21), 시드 1 던전(크기, 해시 = `DungeonGen.GOLDEN_HASH`, 출구 계단, 도착점에 설 수 있음, 제단 자리)을 동굴 그림으로 그려 그림 칸·오버레이 전부 = 데이터,
M3b: 시드 1~8 던전의 해시 묶음(`DungeonGen.SEEDS_GOLDEN`, 출력 `dungeon_seeds=acc0a9bc2359`(M3-fix): 다른 기기의 던전 생성기가 같은지 보는 값), 캔 던전(금·깸·횃불·드롭)을 지도 스냅샷 길로 보내 받은 것 = 원본이고 동굴 그림 = 데이터(`dungeon_map=319B`), 전송 형식 v4(지도가 든 상태, 지도를 적은 TRAVEL, 지도를 적은 편집, 지도 들어옴 메시지),
M4a: 도구 7개(성광 더함)·입력 액션 `dash`, 피격·사망 시트와 이단 시트 다섯의 크기, 클래스 무기 다섯의 공격, 기본 월드의 지상 스폰 칸이 모두 빛 밖(출력 `spawn_tiles=678`), 시드 1 던전에서 짧은 싸움(이단이 예고 30틱 뒤 한 번 맞히고, 검 세 번에 죽고, 제단이 부서지면 던전 스폰이 멈춤, 출력 `combat=30/3`),
M4b: 대시·F 누르고 있기·USE 조준이 든 프레임 왕복, vitals 블록이 든 상태 왕복, 진짜 아레나의 적 묶음을 클라이언트 `NetCombat`이 받아 호스트 자리·HP·예고 프레임 그대로 그림(출력 `combat_wire=25B`: 이단 하나 묶음 크기), 화살 사건 왕복, `net=v5`,
M6a: 아이템 30개(물약 셋 아이콘은 띠의 16×16 칸, 조제대 아이콘은 코드), 입력 액션 `skill_1`, 레시피 여섯과 약초사 전용 규칙, 일반 회복 물약 만들기(약초 둘 → 하나), 조제대 그림 48×32와 시드 1 제단 남쪽에 놓기(편집 셋, 작업대로 찾힘), 회복 물약, 독 한 번에 다운, 던진 상급 독이 이단에 닿음(출력 `potions=6/1`: 레시피 수 / 닿은 이단),
M6b: THROW·CRAFT 프레임 왕복, 효과 블록이 든 상태 왕복(40B), 기록을 켠 아레나가 던진 독의 던짐·터짐 사건을 클라이언트 `NetCombat`이 받아 호스트가 날린 모든 틱에 호스트 점 그대로 날림, 독 걸린 이단을 클라이언트가 독 표시로 그림(출력 `potion_wire=40B/46B`: 효과가 있는 상태 / 병 하나의 사건 둘), `net=v6`,
M5a: 씨앗 아이템 셋(종류 SEED), 작물 시트 112×48과 물 준 흙 그림 셋, 시드 1 지상의 첫 빛 안 흙 칸에 약초사가 심은 회복 약초를 젖은 채 두면 4,800틱(네 단계 × 1,200, 이 검사에 따로 적은 셈)에 익고 낫으로 상급 약초 둘 + 씨앗 하나(출력 `farm=4800/2`),
M5c: 전송 형식 v7(프레임의 CHANNEL·ALTAR_LIFT·ALTAR_PLACE, 채널링과 든 제단이 든 17B 상태), 호스트 농장의 자람과 제단을 든 뒤의 시듦이 편집으로 클라이언트 월드에 가서 같은 월드(출력 `fields_wire=17B/11B`: 채널링하는 운반자의 상태 / 작물 단계 편집 하나), `net=v7`,
M7a: 작업대 셋·창고·작은 불꽃 그림, 통나무·돌·철광석에서 손 작업대 → 널판 → 모루 → 제련 → 1티어 검(7번 만듦), 시드 1 제단 남쪽에 작업대 놓기, 1티어 검 21·갑옷 너머 칼 8·사망 뒤 검 96, 제단 북쪽 빛 안에 창고 → 넣으면 월드 해시가 바뀜(출력 `chain=20/7 gear=21/8/96 chest=16`: 체인·수리 레시피 수 / 만든 수, 1티어 검 피해 / 갑옷 너머 칼 / 사망 뒤 검 내구도, 창고 칸), 도구 12개(M7a: 1티어 무기 다섯),
M5b: 성수 아이템(종류 CONSUMABLE)과 아이콘, 재 얼룩 그림 셋, 시드 1 지상의 첫 오염 칸에서 끝난 채널링이 원판의 오염 칸(이 검사에 따로 적은 셈)을 깨끗한 풀로(흙 + 재 0, 오염 칸 수가 그만큼 줆), 성수가 3×3 안을 정화하고 하나 씀, 스폰 칸이 줆, 제단을 들면 제단·안전 반경 없음, 13칸 서쪽 근처에 내려놓으면 그 자리에 제단과 빛, 부활 자리가 따라감(출력 `purify=11+4/648 altar=49,45`: 채널링 칸 + 성수 칸 / 그 뒤 스폰 칸, 옮긴 제단의 왼쪽 위 칸),
기본 월드의 안전 반경 hard 빛 텍스처 226×226 텍셀 전부 = `is_in_safe_zone()`, 불꽃 마스크 81픽셀,
네트워크(G3): 물리 틱 60, ENet 호스트가 루프백 빈 포트에서 열리고 닫힘(방화벽 창이 뜨지 않게 127.0.0.1만), Steam 가용성 = GodotSteam 유무, 상태 묶음 왕복, 늦은 참가 월드 스냅샷 왕복(H1: 이 빌드의 zstd로 압축 → 조각 → 받기 → 같은 월드), 9명 뒤 열 번째 거부, `main.tscn`에 `Net` 노드.
내보낸 exe에서 돌면 pck 안의 타일셋·그림까지 확인하는 셈이다. 월드 해시는 이 데스크탑(x86_64)에서 만든 값이라, 다른 기기(서피스 ARM64)에서 `--smoke`가 해시로 FAIL이면 그 기기는 같은 시드로 다른 월드를 만든다는 뜻이다. 늦은 참가는 이제 호스트의 월드를 받으므로 그래도 된다(H1). 다만 그 기기가 호스트가 되면 같은 시드라도 데스크탑과 다른 월드가 된다.
`test_core.gd`는 같은 창 검사가 설정이 다른 창에서는 실패하는 것도 확인한다.

## 폴더

```
game/                           Godot 프로젝트 루트 (= res://)
  project.godot                 이름 "Evensong", 메인 장면 res://scenes/main.tscn, 오토로드 Cli, 설정은 아래 "규칙"
  export_presets.cfg            "Windows Desktop" (x86_64) + "Windows ARM64", release, pck 내장, 콘솔 래퍼, tests/·tools/ 제외
  core/                         cli.gd (오토로드 Cli), cli_options.gd (인자), config.gd (상수: ● / 임시값 / 구현 선택), smoke.gd,
                                main.gd (main.tscn 루트: 내 플레이어 + 더미 + 카메라 + HUD + 목표 칸 표시, 키, 테스트 플래그)
  items/                        item_db.gd (아이템 표, M2a), item_stack.gd (한 칸의 묶음), inventory.gd (인벤토리 + 핫바),
                                item_icons.gd (아이콘: 그림 불러오기 + 도구 임시 아이콘을 코드로), world_items.gd (M2b:
                                채집물 표, 줍기·버리기·사용·주기 규칙과 거부 이유, 등급 규칙, M3a: 횃불 놓기·입구 거부),
                                mining.gd (채굴 규칙, M3a), M6a: crafting.gd (작업대·레시피·해금·만들기 규칙), potions.gd
                                (물약: 마시기·던지기 규칙, 효과 수치, 아이템 꺼내기), M5a: farming.gd (농사 규칙: 밭의 식생
                                값, 빛·오염, 일구기·심기·물주기·수확 검사, 낫 규칙), M5b: purify.gd (정화 규칙: 성수 3×3,
                                채널링 원판과 시작 조건, 정화 편집), altar_move.gd (제단 들기·놓기 규칙, 놓을 자리,
                                다운 때 내려놓을 자리), M7a: gear.gd (1티어 장비·갑옷·내구도: 기본 아이템, 피해, 방어, 마모,
                                입기·벗기, 가장 닳은 것), storage.gd (공유 창고: 빛 안 규칙, 열기, 넣기·꺼내기)
  ui/                           hud.gd (핫바 줄 · Tab 인벤토리 칸 · 3×5 숫자, 자기 캔버스 레이어; M4a: HP·스태미나·다운 막대,
                                부활 카운트다운; M6a: 효과 아이콘; M7a: 내구도 막대, 갑옷 칸), crafting_panel.gd (M6a: 제작 창;
                                M7a: 재료 셋까지, 수리 줄, 스크롤), chest_panel.gd (M7a: 창고 창)
  combat/                       (M4a) combat.gd (공격 표·조준 코드·근접 호·시야 선·곡괭이 규칙·적의 빛 규칙), heretic_sim.gd
                                (이단 하나의 상태와 그림 시간), arena.gd (지도 하나의 전투: 이단·화살과 빛 탄·제단 HP·소생·스폰),
                                combat_view.gd (그리기: 이단 노드, 날아가는 것, 제단·다운 막대). M6a: arena.gd에 던진 병·터짐·이단의 독
  world/                        terrain.gd (지형·코너 키), world_data.gd (레이어 6장), tileset_builder.gd, wang_table.gd,
                                surface_gen.gd (생성기), ground_view.gd (청크 dual grid), game_world.gd (world.tscn 루트),
                                altar.gd (제단 그림 + 불꽃), debug_overlay.gd, target_marker.gd (조준 목표 칸 표시, M2a),
                                item_view.gd (채집물·드롭 그림, M2b), M3a: walls.gd (벽 바이트·앞면·경도 규칙),
                                dungeon_gen.gd (던전 생성기), cave_table.gd (절벽 타일 조회: 코너 + 둘레), cave_view.gd
                                (던전 dual grid + 광맥·금 오버레이), fixture_view.gd (입구·계단·제단·횃불 그림과 빛),
                                M5a: farm.gd (지도 하나의 농장: 자라기·물·시듦의 틱과 네 동작), field_view.gd (물 준 흙 덧칠,
                                작물 그림과 흙더미 색), M5b: purify_view.gd (재 얼룩·금빛 테두리·채널링 점), altar_ghost.gd
                                (놓을 자리 표시),
                                tilesets/surface.tres, tilesets/dungeon.tres (만든 타일셋, 커밋)
  actors/                       character.gd (레이어 캐릭터), rig_data.gd (리그 표), rig_anchors.gd (생성된 기준점 표),
                                rig_measure.gd (기준점 재기), movement.gd (이동 규칙), player.gd (+ M2a 조작: 조준·사용·동작
                                시간, M2b: 프레임 만들기·진행), player_sim.gd (M2b: 프레임 하나를 진행하는 규칙, 호스트·예측·혼자 공통),
                                aim.gd (조준 규칙과 창 늘이기 계산, M2a), player_camera.gd, free_camera.gd (world.tscn 맵 보기용),
                                M4a: vitals.gd (HP·스태미나·대시·경직·다운/사망; M6a: 버프·독), heretic.gd (이단 그림 + HP 막대),
                                M6a: effect_marks.gd (머리 위 효과 표시와 그 아이콘), M5b: altar_mark.gd (든 제단 표시)
  light/                        safe_zone.gd (안전 반경 규칙), light_gen.gd (빛 텍스처·불꽃 마스크), altar_light.gd, lighting.gd,
                                torch_light.gd (횃불 빛 텍스처, M3a)
  net/                          session.gd (세션 노드 Net: 두 역할이 같이 쓰는 상태·RPC 표·틱 나누기), session_host.gd
                                (호스트 흐름; M5c: 지도마다 농장, 농사·정화·제단 요청), session_client.gd (클라이언트 흐름), session_bots.gd (봇·테스트 흐름: go/done/
                                finish, 결과), world_snapshot.gd (늦은 참가 월드 스냅샷), transport.gd (전송 인터페이스), enet_transport.gd,
                                steam_transport.gd (자리만), transports.gd (이름 → 전송), protocol.gd (전송 형식; M6b: THROW·CRAFT, 효과 블록, 독 표시, 병 사건;
                                M5c: CHANNEL·ALTAR_LIFT·ALTAR_PLACE, 상태의 채널링·든 제단),
                                roster.gd (인원 상한·스폰 자리), input_gate.gd (호스트 입력 검사), state_broadcast.gd
                                (묶음/키프레임/조용함), prediction.gd (클라이언트 예측·보정), interpolation.gd (남의 캐릭터
                                보간 + 호스트 시계), edit_log.gd (월드 편집 기록), net_member.gd (세션 안 플레이어 하나),
                                net_bot.gd (--bot), link_sim.gd (지연·손실 흉내), net_stats.gd (트래픽), session_report.gd
                                (테스트 결과 JSON·표시 파일), net_combat.gd (M4b: 클라이언트가 받은 적·화살을 트랙으로
                                모아 거울 아레나에 그리기; M6b: 던진 병 트랙 `FlaskTrack`과 터짐, 이단의 독 표시)
  scenes/                       main.tscn (실행 장면: 월드 + 카메라 + Net), world.tscn (월드 + 제단 + 빛 + 자유 카메라 + 디버그 선)
  art/tiles/, art/chars/, art/env/, art/items/, art/enemies/ (M4a)   우리 PNG·JSON 사본 (아래 "그림 출처")
  tests/                        run_all.gd (러너), base_test.gd (기반 클래스), test_core.gd, test_world.gd, test_actors.gd,
                                test_light.gd, test_net.gd, test_net_session.gd (다중 프로세스), test_items.gd, test_aim.gd,
                                test_actions.gd (M2a), test_world_items.gd (M2b), test_dungeon.gd, test_mining.gd (M3a),
                                test_net_maps.gd (M3b: 세션의 지도, 한 프로세스), test_combat.gd, test_heretic.gd (M4a),
                                test_net_combat.gd (M4b: 세션의 전투, 한 프로세스), test_net_fight.gd (M4b: 실제 세션
                                fight·fight4·fightlag, test_net_session.gd를 이어 씀), test_crafting.gd, test_potions.gd (M6a),
                                test_net_potions.gd (M6b: 세션의 제작·물약, 한 프로세스, test_net_combat.gd를 이어 씀),
                                test_net_brew.gd (M6b: 실제 세션 brew·brew4, test_net_session.gd를 이어 씀), test_farming.gd (M5a),
                                test_purify.gd, test_altar_move.gd (M5b), test_net_fields.gd (M5c: 세션의 농사·정화·제단,
                                한 프로세스, test_net_potions.gd를 이어 씀), test_net_farm.gd, test_net_purify.gd (M5c: 실제 세션
                                farm·farm4, purify·altar, test_net_session.gd를 이어 씀), test_workbench.gd, test_gear.gd,
                                test_storage.gd (M7a),
                                fixtures/ (러너 자체 시험)
  tools/                        build_tileset.gd (타일셋 빌더), build_rig_anchors.gd (기준점 표), check_render.gd (창 그림 검사)
  shots/                        스크린샷 (.gdignore)
  build/                        내보내기 결과 (커밋 안 함, .gdignore만 커밋)
```

## 월드 데이터

- `WorldData`는 칸마다 1바이트씩 **레이어 6장**(● gameplay-design §3.1: 바닥 / 벽 / 광맥 / 식생 / 오염 / 설치물)을 `PackedByteArray`로 들고 있다. M1은 바닥(풀 0 / 일군 흙 1 / 재 2), 오염(구역 번호 1.., 0 = 깨끗), 설치물(제단 = 1)만 쓰고, 벽·광맥은 0으로 둔다. M2b부터 식생 = 채집물(1 + `WorldItems.GATHERABLES` 순서, 0 = 없음), 그리고 레이어 밖에 **드롭 목록**(번호 → 아이템·개수·등급·픽셀 자리)이 있다. 월드 해시(`content_hash`)는 드롭까지 덮는다
- 바닥 레이어가 곧 **꼭짓점 격자**(dual grid)다. 월드 칸 (x, y)의 바닥 값 = 그 칸 가운데 꼭짓점의 지형. 그림 칸은 반 칸 밀려 있어서 그림 칸 (dx, dy)의 NW·NE·SW·SE 코너가 꼭짓점 (dx, dy), (dx+1, dy), (dx, dy+1), (dx+1, dy+1)이다. W×H 월드는 그림 칸 (W+1)×(H+1)개(-1..W-1)이고, 맵 밖 꼭짓점은 풀로 읽는다. 괭이질 한 칸 = 그 칸 가운데 16×16 흙 덩어리 (스파이크 RESULTS §2의 (b))
- 코너 키 = NW + 3·NE + 9·SW + 27·SE (0..80). 우리 그림은 풀↔흙, 풀↔재 두 벌뿐이라 키 81개 중 31개만 그림이 있고, 흙과 재가 한 칸에 섞이는 50개는 없다. 그래서 **흙과 재는 같은 그림 칸의 코너가 되면 안 된다**(꼭짓점 8방향 이웃 금지). `WorldData.set_terrain()`이 거부하고, 생성기는 거리로 떼어 둔다. 그래도 생기면(규칙을 거치지 않고 쓴 데이터) 가장 가까운 키의 타일로 그리고 `GroundView.verify()`가 "fallbacks"로 센다
- 같은 코너의 타일이 여럿이면(풀 5, 흙 3, 재 4) 칸 위치 해시로 고른다. 같은 데이터 → 같은 그림
- `GroundView`는 그림 칸 32×32개마다 `TileMapLayer` 하나(청크)를 둔다. 128×96 맵 = 청크 20개. 렌더링 사분면은 8칸. `set_terrain(꼭짓점, 값)`은 그 꼭짓점을 코너로 가진 그림 칸 4개만 다시 그린다 (청크 경계에서는 여러 청크에 걸쳐)
- 생성기(`SurfaceGen.generate(seed)`): 맵 가운데 제단 자리(3×3, 설치물 레이어), 제단 빛 반경 안에만 일군 흙 3덩어리(칸의 네 모서리까지 반경 안, 제단 둘레 1칸 비움, 덩어리끼리 안 붙음), 반경 + 4타일 밖에 고정 오염(재) 구역 3곳(노이즈로 가장자리를 흔든 원). 같은 기기에서 같은 시드 → 같은 월드(PCG32 + FastNoiseLite + 정수 해시). FastNoiseLite는 float 계산이라 다른 아키텍처(ARM64)에서도 같은지는 확인하지 못했다. 늦은 참가는 이것에 기대지 않는다(H1: 호스트가 월드를 보낸다, 아래 "네트워크"). 시드 1의 해시(x86_64 결과)를 `SurfaceGen.GOLDEN_HASH`로 고정해서 `test_world.gd`와 `--smoke`가 비교한다. **M2b에서 바뀌었다**: `e04258e54b02b0ed09ce02c9a92c11a8` → `ff2e1d90c4dc12d6dfad926584d440d0` (채집물 74개를 흩는 4단계와, 해시가 드롭 목록까지 덮게 된 것. 흙·재는 그대로: 채집물은 그 뒤에 같은 난수열에서 뽑는다) 이 값은 생성 결과가 모르게 바뀌는 것을 잡을 뿐이고, 생성 규칙이 맞는지는 `test_world.gd`의 40시드 규칙 검사가 본다
- 제단은 설치물 레이어의 자리(3×3) 위에 `Altar` 노드로 놓인다 (아래 "빛과 제단"). 걷기 충돌은 설치물 레이어를 본다
- **M3a**: 생성기 5단계가 던전 입구(설치물 `PLACEABLE_ENTRANCE`, 2×1)를 넣는다. 그래서 `SurfaceGen.GOLDEN_HASH`가 **다시 바뀌었다**: `ff2e1d90c4dc12d6dfad926584d440d0` → `1d9f92c7b5ef2a715f95cc32d7424b36` (입구 칸 2개뿐. 난수를 쓰지 않고 4단계 뒤에 놓아서 채집물 74개는 M2b 자리 그대로다, `test_dungeon.gd`가 확인). 늦은 참가 스냅샷 원본이 그만큼 바뀌어 세션 시험의 압축 크기·조각 수가 조금 달라졌다(시험은 수를 스스로 센다). 설치물 중 막는 것은 제단·입구·계단·이단의 제단(`WorldData.placeable_blocks`), 횃불은 막지 않는다
- **M3a 지도**: 지도마다 WorldData가 따로다(`map_id`: 지상 `Config.MAP_SURFACE` 0, 첫 던전 `MAP_DUNGEON` 1. 해시·스냅샷에는 들어가지 않는다). 던전은 벽(WALL)·광맥(ORE)·설치물만 쓰고 바닥 레이어는 0이다. 벽 바이트 = 종류(아래 4비트: 0 없음, 1 바위, 2 기반암) | 맞은 횟수(위 4비트), 광맥 = 0 없음 / 1 구리 / 2 철 (`world/walls.gd`). 그래서 채굴 한 번이 보통 칸 편집 하나이고 스냅샷·해시·편집 기록이 반쯤 깬 벽까지 그대로 덮는다
- **M5a 밭**: 일군 칸 = 바닥 레이어 흙(괭이질은 M1 디버그 편집과 같은 바닥 편집 하나). 작물·젖은 흙은 식생 레이어의 값 `Config.FIELD_BASE`(64) + 작물(0 없음·1 회복·2 버프·3 독초) × 40 + 단계(0~4) × 8 + 표지(시듦 4, 젖음 2, 약초사가 심음 1). 0 = 마른 빈 흙, 66 = 젖은 빈 흙. 채집물 값(1..15)과 겹치지 않는다. 그래서 스냅샷·월드 해시·편집 기록이 밭을 그대로 덮고, 세션의 전송 형식(v6)도 바꿀 것이 없다. 자라는 틱·남은 물 틱은 월드가 아니라 지도마다의 `Farm`에 있다(아래 "M5a")
- **M5b 정화·제단**: 정화된 칸 = 바닥 풀 + 오염 0(칸 편집 둘, 재를 거치는 모습은 그림뿐). 제단 자리(`altar_rect`)는 이제 설치물 레이어에서 다시 읽는다: 들기·놓기는 제단 칸 아홉의 칸 편집이고, `EditLog.apply_to_data`가 제단 칸이 바뀔 때 `WorldData.refresh_altar_rect()`로 다시 계산한다(제단 칸이 한 3×3일 때만 그 자리, 아니면 없음 = 들고 있음·반쯤 옮김). 스냅샷 머리말의 제단 자리와 해시는 그 값을 그대로 담는다(시험: 편집을 전송 형식으로 보낸 사본·스냅샷이 같은 제단 자리와 해시)

## 캐릭터 (G2)

- `Character`(actors/character.gd) = 기본 몸 한 벌 + 클래스 표식 레이어 하나 (● brief §5.6 R21). 노드 위치 = 두 발 사이(프레임 바닥 가운데, 발 줄 y=31 바로 아래)라 y 정렬 부모(`Entities`) 아래에서 **발 기준으로 정렬**된다. 속성: `class_id`(paladin|miner|archer|cleric|herbalist), `direction`(남·동·북·서), `walking`(걷기 6프레임 / idle 4프레임)
- 구조: `Rig`(서쪽이면 `scale.x = -1`) 아래 `Body` + 슬롯 `Back`(곡괭이·활) · `Arm`(방패) · `Waist`(씨앗주머니) · `Float`(후광). 방향마다 순서표(`RigData.DRAW_ORDER`)대로 자식 순서를 바꾼다: 등 장비는 남·동(·서)에서 몸 뒤, 북에서 몸 앞. 방패·주머니·후광은 늘 앞. `z_index`는 쓰지 않는다(다른 캐릭터·바닥과의 순서까지 바뀐다)
- 서쪽 = 동쪽 좌우 반전 (● R19). 프레임 32px가 발 가운데 기준이라 반전해도 정수 픽셀이다
- 표식 위치 = v01 걷기 첫 프레임 기준 위치 + v01→v02 발 맞춤 이동(걷기 남 +4 동 +3 북 +4, idle 남 +5 동 +2 북 +3) + 그 프레임의 기준점 이동(+ 후광은 걷기 2~4프레임에서 1px 뜸)
- 기준점(● R27, brief §5.6 "위치"): 프레임마다 **걷기 첫 프레임**의 몸통 줄(v01 y 13~22)·머리 줄(y 0~11)이 가장 많이 겹치는 이동(RGB 차 합 < 60인 픽셀 수, 몸통 ±4px, 머리 ±8px, 같으면 작은 이동). 두 프레임을 각자의 발 맞춤 이동을 되돌린 v01 좌표에서 비교한다. 방패·곡괭이·활·주머니는 몸통, 후광은 머리를 따른다. `tools/build_rig_anchors.gd`가 재서 `actors/rig_anchors.gd`에 표로 쓰고, 테스트가 다시 잰다
  - 걷기 기준점은 스파이크와 같다 (몸통: 북 1·2프레임 아래로 1px, 머리: 남 2~5프레임 위로 1px, 나머지 0)
  - idle: 몸통 남 0 / 동 (0,2)(−1,2)(−1,2)(0,2) / 북 (0,1)×4, 머리 남 (−1,0)(0,0)(−1,0)(−1,0) / 동 (−1,2)(0,2)(−1,2)(0,1) / 북 (0,1)×4. idle은 다른 템플릿이라 걷기와 몸 모양이 조금 달라서 0이 아니다. 창 검사 `--save`로 남긴 걷기·idle 전 프레임(5클래스 × 4방향)을 2배로 모아 봤을 때 표식은 제자리에 붙어 보였다(동쪽 idle에서 표식이 좌우로 1px 흔들린다). 기준점은 재는 법에 따라 1px씩 달라질 수 있으니(스파이크 notes/chars.md) **사람이 보고 고정하는 편이 낫다**
- 방패 시트(`sig_paladin_shield_v01.png`)는 남·동 줄에 걷기 프레임마다 떼어 낸 칸이 6개씩 있지만, "단단한 파츠는 방향당 1장 + 기준점"(● R27)대로 **줄마다 첫 칸만** 쓴다 (R27 동작 시험이 쓴 칸과 같다)
- `Player`(actors/player.gd) = 시뮬레이션(발 위치 float, 4방향 바라보기) + `Character`. `_physics_process`(60Hz 고정)에서 키를 읽어 `apply_input()`(= `Movement.step()` + `Movement.facing_for()`)을 돌린다. 노드는 정수 픽셀에 둔다. `PlayerCamera`도 정수 픽셀에서 내 캐릭터 가운데를 따라가고 맵 가장자리에서 멈춘다(맵이 화면보다 작은 축은 가운데). 그래서 내 캐릭터와 카메라가 같이 1픽셀씩 움직인다
- **틱 사이에 그리기** (H1): 물리 틱으로 움직이는 플레이어(혼자일 때 내 캐릭터, 호스트가 시뮬레이션하는 모든 플레이어, 클라이언트의 예측된 내 캐릭터)는 `_process`에서 지난 틱 위치와 이번 틱 위치 사이를 `Engine.get_physics_interpolation_fraction()`만큼 간 곳에, 정수 픽셀로 반올림해 그린다(`Player.draw_position`). 60Hz보다 빠른 모니터에서 0·1·2px로 튀던 걸음이 0·1px로 고르다(테스트: 144Hz 흉내에서 2px 뜀 10번 → 0번). 시뮬레이션 위치(`sim_position`)·네트워크 상태·위치 해시는 그대로이고 그림만 최대 한 틱(1/60초) 뒤에 있다. 호스트의 보정(틱이 아닌 `show_state`)은 그리는 구간 전체를 옮겨서 튀지 않고, 같은 상태면 아무것도 바꾸지 않는다. 남의 캐릭터(클라이언트)는 원래 보간된 상태를 매 프레임 받으므로 그대로 그린다. 카메라는 `process_priority` 1로 플레이어 다음에 따라간다
  - 한 틱에 두 걸음(2.4px)보다 많이 움직인 플레이어는 그 틱 끝 위치에 그린다(H-fix, `Player.MAX_DRAWN_STEP_PX` 3px). 호스트가 밀린 클라이언트의 프레임을 한 틱에 여러 개 적용할 때(아래 "호스트가 멈췄다 돌아올 때")다: 두 끝을 잇는 직선은 걸음이 돌아간 모서리를 가로질러 제단 안을 지날 수 있다(테스트: 제단 북서 모서리를 도는 90걸음 틱이 반이 지난 때 직선 위면 제단 안, 실제로는 11번 그려 모두 틱 끝). 그래서 따라잡기는 그림에서 걸음당 한 칸씩이 아니라 틱마다 최대 4걸음씩 뛰어 보인다. 보통(틱당 1걸음)은 그대로다(144Hz 시험 같은 수)
- 이동 규칙(`Movement`, 순수 함수, 결정적: G3에서 호스트와 클라이언트 예측이 같은 함수를 쓴다): 입력은 축마다 −1/0/1인 8방향, 속력은 대각선도 `WALK_SPEED`. 발 상자(가로 10 × 세로 4px)가 맵(위쪽은 머리 자리 28px 남김) 안, 장애물 밖에 있어야 한다. 장애물 = 막힌 칸(설치물 = 제단 3×3)과 **제단 옆 띠**(H1, `Movement.side_bands`): 제단 자리 서쪽·동쪽 면 옆으로 `ALTAR_SIDE_CLEARANCE`(서 5, 동 3px) 폭, 자리 위 변부터 아래 변 4px 위까지. 발이 제단 자리 높이에 있을 때(= 제단 뒤에 그려질 때)만 걸려서, 옆면에 붙은 캐릭터의 몸(발에서 좌우 9px)이 제단 그림(48px 자리 중 불투명 열 0~46) 뒤로 들어가지 않는다. 북쪽·남쪽 면은 전처럼 발 상자가 딱 붙어 멈춘다(모서리에서는 띠 폭만큼 면이 넓어진 셈). 이 폭은 `test_actors.gd`가 시트와 제단 그림에서 다시 재서 비교한다. x 먼저, 그다음 y로 움직이고 부딪힌 곳에 딱 붙어 멈추므로 대각선은 벽을 따라 미끄러진다. 바라보기는 4방향: 한 축이면 그쪽, 대각선이면 지금 바라보는 쪽이 두 축 중 하나일 때 그대로, 아니면 가로
- `main.tscn`: 내 캐릭터는 스폰 자리 0(제단 서쪽), 나머지 네 클래스는 자리 1~4에 제단을 보고 선 idle 더미. 스폰 자리 9개(`Config.SPAWN_SLOTS`)는 모두 안전 반경 안, 제단 밖이고 서로 겹치지 않는다 (세션에서는 호스트가 가장 작은 빈 자리를 준다, 아래 "네트워크")

## 아이템 · 조준 · 동작 (M2a)

혼자 할 때(`main.tscn`, `--host`/`--join` 없음)의 내 캐릭터에 붙었다. 문서의 ●는 그대로 따르고, 나머지는 [임시값](#임시값-사람-확인-필요) 표에 있다.

### 아이템 표 (`items/item_db.gd`)

- 종류: 도구(핫바에서 들고 좌클릭하면 그 도구의 몸 동작), 재료, 채집물(세상에서 줍는 것. 줍기는 아직 없다). 아이템마다 id, 종류, 아이콘, (채집물) 월드 그림, 묶음 크기, 등급이 있는지, (도구) 몸 동작
- 도구 6 (묶음 1, 등급 없음, 아이콘은 코드로 그린 임시): `pickaxe` → 곡괭이 동작, `hoe` → 괭이, `sickle` → 낫, `watering_can` → 물주기, `sword` → 검, `bow` → 활. 손에 드는 도구를 동작에 그려 넣은(● R25) 동작마다 하나다. 마법(성직자 기도·치료)과 던지기(약초사 약제 투척)는 손에 드는 도구가 없고 그것을 부르는 것(스킬·약제)이 M2 밖이라 아이템이 없다. F6과 `--test-action`으로 본다
- 재료 1 (묶음 99): `stone_block` (04-env 묶음 2 #61 "건설 재료 덤", 3/4 아이콘 v02)
- 채집물 15 (묶음 99): 약초 `wild_healing`·`wild_buff`·`wild_poison`(아이콘 = 꺾은 가지 `item_sprig_*`, 월드 그림 = 자라는 풀 `item_wild_*`)과 `herb_clump`(덤불, 아이콘 = 월드 그림), 버섯 `mushroom_a`·`b`·`c`·`d`·`ash`(ash는 오염 쪽), 돌 `stone_a`·`b`·`c`·`mossy`·`veined`·`mould`(뒤의 둘은 오염 쪽)
- 등급: 약초 넷만 일반(`common`)·상급(`fine`)이 있다 (● gameplay-design §3.4 원칙 "약초를 약초사가 캐면 상급 등급, 다른 클래스는 일반 등급"). 등급이 다르면 한 칸에 쌓지 않는다. 버섯·돌·도구의 등급은 문서에 없어서 두지 않았다(임시값). 캐는 일이 없으니 등급은 지금 `--give`로만 생긴다
- 그림: 채집물·재료는 04-env "본 제작"(2026-10-21) 손질판 v02이고 모두 **채택 후보, 사람 확인 전**이다. 임시 그림으로 쓴다 (아래 "그림 출처")
- M3a: 재료에 광석 둘(`ore_copper`, `ore_iron`, 채굴로 생김), 새 종류 "놓는 것"(`torch`, 아이콘은 코드). 표는 25개이고 뒤에 더해서 M2의 번호(전송 형식이 쓰는 순서)는 그대로다

### 인벤토리와 핫바 (`items/inventory.gd`)

- 플레이어마다 24칸, 앞 8칸이 핫바(임시값). 넣기는 같은 아이템·등급 묶음부터 채우고(칸 순서라 핫바 먼저) 그다음 앞쪽 빈 칸, 못 넣은 수를 돌려준다. F5 디버그 묶음은 못 넣은 것을 버린다
- 나누기는 묶음 일부를 첫 빈 칸으로 옮긴다(빈 칸이 없거나 수가 틀리면 아무것도 안 함). 옮기기는 빈 칸이면 옮기고, 같은 아이템·등급이면 들어가는 만큼 합치고, 아니면 맞바꾼다. 화면에서 끌어 옮기는 조작은 아직 없다(함수와 테스트만)
- Q / E = 핫바 왼쪽 / 오른쪽, 끝에서 반대쪽 끝으로 돈다. 키 초안(gameplay-design §1 ○)의 숫자 키 1 2 3은 스킬이라 핫바에 쓰지 않았다. F(상호작용)는 상호작용할 것이 없어 아직 묶지 않았다(M2b에서 F = 줍기로 묶음)
- M2a에서는 인벤토리를 네트워크로 보내지 않았다. M2b부터 인벤토리는 호스트에 있고 주인에게만 간다 (아래 "M2b")

### 조준 (`actors/aim.gd`, `Player.tick_controls`)

- 정해진 것은 ● 에임형(gameplay-design §2.1 R12: 마우스 방향 스킬샷)뿐이고, 아래 규칙은 모두 임시값이다
  - 조준 중 = 마우스가 지난 1초(`AIM_HOLD_SEC`) 안에 움직였거나, 사용 버튼을 누르고 있거나, 동작 중. 조준 중이면 마우스 쪽을 본다(4방향, 큰 축 쪽, 정확한 대각선은 남·북). 아니면 M1 그대로 걷는 방향을 본다(`Movement.facing_for`). 테스트: 조준 없이 600틱 무작위로 걸으면 위치·바라보기·걷기가 매 틱 M1 규칙과 같다(M2-fix: 비교 대상을 M1의 `apply_input` 그대로, 곧 `Movement.step` + `Movement.facing_for`를 테스트에 적은 것으로 바꿨다. 전에는 `apply_input`도 M2b의 `PlayerSim.step`을 불러 같은 함수끼리 비교하는 셈이라 `PlayerSim`의 바라보기 규칙을 바꿔도 통과했다)
  - 기준점은 발이다. 발 → 마우스 방향을 45° 8구역(축과 대각선이 가운데, 경계 ±22.5°)으로 나누고, 목표 칸 = 발 칸의 그 방향 이웃 칸(○ gameplay-design §3.2 "마우스 방향의 인접 타일을 타격", 채굴에 쓴 말). 마우스가 정확히 발 위면 앞의 구역·바라보기를 둔다
  - **발 칸** = 발 상자(발에서 위로 `FEET_HEIGHT` 4px)의 가운데가 있는 칸(`Aim.feet_cell`, M2-fix). 발 점은 그림의 아래 끝이라 타일 선 위에 있으면 그 점은 아래 줄 칸에 속하는데, 그려진 발(4px)은 모두 위 줄에 있다. 전에는 발 점의 칸을 써서 발이 타일 선에서 3px 아래까지일 때 목표 칸·표시·손 닿는 칸이 한 줄 아래였다(스폰 자리 0·1이 바로 그 자리 y = 768 = 48×16이라, 처음 동쪽·서쪽을 조준하면 발 옆이 아니라 대각선 아래 칸에 표시가 떴다). 호스트·예측·혼자가 같은 함수를 쓴다
- 마우스 → 월드: 게임은 엔진의 `get_global_mouse_position()`(캔버스 변환 = 카메라 + 창 늘이기)을 쓴다. `Aim.view_size`·`view_scale`·`view_margin`·`window_to_view`는 엔진 계산(`Window::_update_viewport_size`: 480×270, viewport, 정수배, expand, 32비트 float)을 그대로 옮긴 것이고, 테스트가 창 크기 6가지에서 엔진과 비교한다(**헤드리스에서만**: 창을 띄우면 루트 뷰포트가 주입한 마우스 이벤트 대신 OS 커서를 읽어 `test_aim.gd`의 `main.tscn` 마우스 검사가 실패한다. M2-fix 검토가 창으로 돌려 확인. 창의 y축 늘이기 계산은 엔진과 같았다. 진짜 마우스로 조준해 보는 것은 사람이 할 일): 1920×1080 → 480×270 4배, 960×540 → 2배, 1000×700 → 480×336 2배 + 검은 띠 (20, 14), 1366×768 → 480×270 2배 + 띠 (203, 114), 1000×703 → 480×337, 세로 500×1000 → 480×960 1배. 띠 위의 마우스는 뷰포트 밖 좌표가 되고(1000×700의 창 (0, 0) = 뷰포트 (−10, −7)) 조준은 그대로 된다
- 목표 칸 표시(`world/target_marker.gd`): 16px 칸 네 모서리의 금빛(#f4c95d) ㄱ자(팔 4px)와 그 안쪽 잿빛 검정(#1a1714) 띠. 코드로 그리고 unshaded라 저녁에도 보인다. Main이 World의 Ground와 Entities 사이에 넣어 바닥 위·캐릭터 아래다. 조준 중이고 칸이 맵 안일 때만 보인다. 동작 중에는 동작의 목표 칸(`Player.action_cell`)에 머문다(M2-fix: 전에는 동작 중에도 마우스를 따라가서 치는 칸을 떠났다). 발 북쪽 줄(북·북동·북서) 칸은 캐릭터 몸이 가린다

### 몸 동작 (`RigData`, `Character.show_action`, `Player`)

- 시트 8장(`art/chars/base_body_v02_<동작>.png`, 03-pixel 10~12차): 프레임 수는 곡괭이·괭이·낫·마법 6, 물주기·활·검 8, 던지기 7 (brief §5.6). 도구를 든 일곱은 64×64 칸이고 32 프레임을 칸의 (16, 16)에 둔 좌표라 발 줄이 y=47이다(● R26 "동작 칸"). 첫 칸은 생성의 시작 그림(= 걷기 첫 프레임)이라 재생은 둘째 칸부터다. 던지기는 도구 없는 템플릿 동작이라 32×32 칸, 시작 칸 없이 7프레임, 발 y=31(줄마다 +4 +4 +3 옮긴 판)
- 발 맞춤: 64칸은 칸의 (32, 48)을 발 점에 놓는다(32칸은 (16, 32)). 테스트: 일곱 장 × 세 줄의 시작 칸을 이 규칙으로 놓으면 걷기 첫 프레임을 걷기 규칙으로 놓은 것과 픽셀까지 같다
- 표식(● R27): 그 동작에서 손에 들지 않는 표식은 걷기용 표식 레이어 한 장을 동작 프레임마다 기준점(몸통 이동, 후광은 머리 이동)에 붙인다. 손에 든 도구가 곧 그 클래스의 표식이면 숨긴다: 광부의 곡괭이 동작과 아처의 활 동작 두 경우뿐이다(`RigData.HELD_SIGNATURE`). 그리기 순서는 걷기와 같다(등 장비는 북쪽을 볼 때만 몸 앞)
- 기준점: 걷기·idle과 같은 규칙(● R27, `RigMeasure`)으로 동작 55프레임 × 3줄을 재서 `actors/rig_anchors.gd`에 더했다(생성 파일, 이 데스크탑 약 2.1초). `test_actors.gd`가 다시 잰다
- 재생: 핫바에서 고른 아이템이 도구일 때 좌클릭하면 그 동작을 한다. 시간은 시뮬레이션 틱으로 센다: 프레임당 6틱(0.1초)이라 곡괭이 0.6초, 검 0.8초, 던지기 0.7초. 동작 중에는 걷지 않고 바라보기·목표 칸은 시작한 틱의 것이다. 누르고 있으면 끝나는 틱에 다시 시작한다. 셋 다 임시값. 재료·채집물·빈 손은 아무것도 하지 않는다
- 월드 효과는 없다(채굴·농사는 다음 단계). `Player.action_started(아이템, 동작, 목표 칸)` 시그널로 알리고 Main이 `EVENSONG_ACTION start ...` 줄을 찍는다
- 세션: M2a에서는 세션의 플레이어가 `controls`가 꺼져 있고 조준·동작이 없었다. **M2b부터 세션에서도 켜지고 호스트가 정한다** (아래 "M2b")

### HUD (`ui/hud.gd`)

- 자기 캔버스 레이어(10)라 카메라와 저녁 어둠의 영향을 받지 않는다. 핫바 8칸이 화면 아래 가운데(바닥에서 4px), 칸 18px(아이콘 16 + 테 1), 간격 2px. 고른 칸은 금빛 테(#f4c95d 바깥, #9c6a1f 안쪽), 나머지는 #1a1714 / #4a423a 테에 조금 비치는 #2e2a26 바탕. 2개 이상이면 오른쪽 아래에 3×5 숫자(#efe3c6, 그림자 #1a1714), 상급이면 왼쪽 위에 금빛 점 2×2. 글꼴은 쓰지 않는다. Tab이면 나머지 16칸을 핫바 위에 두 줄로 보인다(보기만). 아이템 이름은 보이지 않는다
- 성화 UI(game-concept §10, 2차)가 아니다. 색은 brief §4의 기반·신앙 줄만 썼다

## M2b: 네트워크 + 월드

M2a(혼자 할 때의 아이템·조준·동작)를 세션으로 가져오고, 지상에 채집물과 떨어진 아이템을 더했다. 문서의 ●는 그대로 따르고(호스트 권한 ● game-concept §13, 등급 ● gameplay-design §3.4), 나머지는 [임시값](#임시값-사람-확인-필요) 표의 "M2b" 줄이다.

### 한 가지 규칙: 프레임 (`actors/player_sim.gd`, `Player.make_frame` / `step_frame`)

- 플레이어 시뮬레이션은 이제 **입력 프레임 하나를 한 번 진행하는 규칙 하나**다(`PlayerSim.step`): 방향(8방향), **바라보기(look)**(조준 중이면 마우스 쪽 4방향, 아니면 -1 = M1처럼 걷는 방향), 그 프레임에 시작할 몸 동작(사용이 풀린 결과)과 목표 칸. 순서는 M2a의 `tick_controls` 그대로다(동작 진행·끝 → 사용이면 시작(목표 칸 쪽을 봄: look이 그 칸 쪽이면 look, 아니면 칸의 방향 `Aim.use_facing`, M2-fix) → 동작이 잠그지 않으면 이동 → 동작이 없으면 바라보기는 look 또는 걷는 방향). 동작은 **프레임으로** 센다(프레임당 `ACTION_FRAME_TICKS`)
- 혼자 할 때 `tick_controls` = `make_frame`(키·마우스·사용 버튼 → 프레임, 조준 갱신) + `step_frame`. 호스트는 모든 플레이어를 `step_frame`으로, 클라이언트 예측은 같은 `PlayerSim.step`으로 진행한다. M2a 테스트(동작 시간·잠금·반복)는 그대로 통과한다. 조준 없이 걷는 600틱 시험은 M2-fix에서 M1 규칙을 테스트에 따로 적은 것과 비교하게 바꿨다(위 "조준")
- 세션에서도 내 플레이어는 `controls`가 켜져 있다(마우스 조준, 목표 칸 표시). F6(디버그 동작 차례로)은 혼자 할 때만

### 요청 (`NetProtocol` 입력 패킷, `SessionHost.run_frame`, `items/world_items.gd`)

- 클라이언트가 보내는 것은 여전히 입력 패킷 하나뿐이다(RPC 표에서 클라이언트가 부를 수 있는 것은 hello·입력·done 그대로). **프레임은 1바이트 그대로**이고 코드에 바라보기를 넣었다: 코드 = 방향(0..8) + 9 × (look + 1), 0..44. look이 없으면(-1) M1의 0..8과 같다
- 요청은 그 프레임에 붙는다(프레임 하나에 하나). 패킷 끝에 요청이 있을 때만 `u8 개수` + 요청마다 `u8 프레임 위치, u8 종류, 필드`: 사용 USE(핫바 칸, 목표 칸 s16×2), 줍기 PICKUP(목표 칸), 고르기 SELECT(핫바 칸), 디버그 버리기 DROP(칸, 개수 0=전부, 목표 칸), 디버그 주기 GIVE(아이템 번호 또는 255 = 디버그 묶음, 개수, 등급). 확인 안 된 프레임과 함께 다시 담겨서 잃어도 다음 패킷이 메운다. 요청이 없는 패킷은 M1과 같은 크기다
- 호스트는 **그 프레임을 처리할 때, 그 프레임의 자리에서** 요청을 검사하고 적용한 뒤 프레임을 진행한다(`run_frame`). 호스트 자신의 프레임도 같은 길(키·마우스·봇 → `make_frame`)이다:
  - 사용: 그 칸에 도구가 있어야 하고(빈 칸 `empty slot`, 도구 아님 `not a tool`), 목표 칸이 발 칸의 바로 옆이어야 하고(`out of reach`), 동작이 아직 이어지면 안 된다(`busy`). 거부된 사용은 시작하지 않는다(클라이언트 예측은 다음 상태에서 보정된다). 받아 준 사용의 바라보기는 호스트가 목표 칸에서 정한다(M2-fix: 프레임의 look이 칸 쪽이 아니면 칸 쪽을 본다. 전에는 서쪽을 보며 동쪽 칸을 칠 수 있었다. 같은 규칙이 `PlayerSim.step`에 있어 예측도 같다)
  - 고르기: 예산 밖이다(M2-fix). 프레임 하나에 하나뿐이고 프레임은 입력 게이트가 묶고, 월드를 바꾸지 않으며(상태 묶음의 든 아이템만), 클라이언트가 바로 예측하므로 `rate`로 거부하면 클라이언트 핫바만 다른 칸에 남았다(검토가 패킷 하나를 잃은 실제 세션에서 재현). 핫바 밖 칸(`no such slot`)처럼 거부된 고르기는 그 틱 끝에 주인에게 인벤토리(호스트의 고른 칸 + ack)를 보내 바로잡는다. 받아 준 고르기는 아무것도 돌려보내지 않는다(예측이 맞으므로)
  - 줍기·버리기·주기: 플레이어마다 요청 예산(`NET_OP_INTERVAL_TICKS` 6틱에 하나, 몰아서 `NET_OP_BURST` 4개)을 넘으면 `rate`. 줍기·버리기는 목표 칸이 맵 안·발 옆이어야 하고(`outside the map`, `out of reach`), 줍기는 그 칸에 채집물이 있으면 그것, 없으면 가장 작은 번호의 드롭(`nothing there`), 인벤토리에 안 들어가면 `inventory full`(채집물은 그대로, 드롭은 들어가는 만큼만 줍고 나머지는 남는다). 버리기는 제단 칸이 아니고(`blocked`) 땅의 드롭이 `MAX_DROPS` 256개보다 적어야 한다. 클라이언트의 주기·버리기(디버그 F5·F7)는 호스트가 디버그 빌드이거나 `--test-allow-give`일 때만(`give off`, `drop off`. 버리기는 M2-fix: 전에는 내보낸 release 호스트도 클라이언트의 F7을 받아서, 버리고 줍기를 되풀이하면 지워지지 않는 편집 기록이 초당 약 10개씩 늘었다); 호스트 자신의 주기·버리기(F5, F7, `--give`)는 늘 된다
  - 결과: 월드 변화는 M1의 편집 기록으로(번호 붙은 편집이 모두에게, 늦은 참가자에게는 스냅샷 뒤 편집으로), 인벤토리가 바뀐 플레이어에게는 그 틱 끝에 **자기 인벤토리만** 보낸다(`ack` = 호스트가 처리한 그 플레이어의 마지막 프레임). 거부는 결과 JSON `ops`에 모두 세고, 호스트 로그 `request_refused slot=.. <요청>: <이유> n=<그 이유로 거부된 수>`는 플레이어·이유마다 처음 8줄(`NET_REFUSAL_LOG_FIRST`), 그다음은 60번째마다(`NET_REFUSAL_LOG_EVERY`)만 찍는다(M2-fix: 매 프레임 거부되는 사용을 보내는 클라이언트가 로그를 초당 60줄씩 채웠다)
- 같은 틱의 경주: 호스트는 플레이어를 자리 순서로, 프레임을 번호 순서로 처리하고 편집을 바로 적용한다. 둘이 같은 틱에 같은 것을 주우면 자리 번호가 작은 쪽이 갖고, 다른 쪽은 `nothing there`다(단위 시험: `run_frame`을 손으로 부른 것과, M2-fix부터 `SessionHost.tick` 자체에 자리 2의 프레임을 먼저 넣은 것 + `four` 세션)
- 클라이언트의 키 요청(F, F7, F5, Q/E, `--give`)은 기다리는 줄(`NET_LOCAL_OPS_MAX` 64개, 넘으면 `request_dropped` 줄)에 들어갔다가 줍기·버리기·주기는 호스트와 같은 예산으로, 고르기는 다음 빈 프레임에 하나씩 붙는다. 그래서 호스트가 제때 받으면 사람이 누른 것은 `rate`로 버려지지 않는다. 다만 패킷을 잃어 다음 패킷에 몰려 오거나 호스트가 멈췄다 따라잡으면(틱당 최대 4프레임) 예산 4개를 넘는 줍기·버리기·주기가 `rate`로 거부될 수 있다(M2-fix 검토가 재현. 이것들은 예측하지 않으므로 아무 일도 일어나지 않고 호스트 로그에 남는다. 다시 누르면 된다). 봇의 요청은 그 틱에 바로 붙는다(마구 보내기 시험이 진짜로 매 프레임 보내도록)

### 예측과 보이는 것

- 클라이언트는 자기 사용(동작 시작)을 이동처럼 바로 예측한다(자기 인벤토리 사본으로 도구를 알아본다). 동작이 이어지는 동안은 서 있어도 매 틱 프레임을 기록해 보내서 호스트와 클라이언트가 같은 프레임에서 동작을 끝낸다. 호스트 상태가 오면 (위치·바라보기·동작·동작 프레임)에서 확인 안 된 프레임을 다시 돌린다. `action_corrections`가 예측과 호스트가 다른 상태 수다(세션 시험에서 0). 핫바 고르기도 바로 바꾸고, 호스트의 인벤토리가 오면 호스트가 아직 처리하지 않은 고르기(ack 뒤 프레임에 실린 것, 아직 줄에 있는 것)를 그 위에 다시 얹는다(M2-fix부터 단위 시험이 있다). 서 있어도 조준(look)이 바라보기를 바꾸는 틱에는 프레임을 기록해 보내서 호스트도 같은 쪽을 본다(단위 시험 + `pair`의 c1). 줍기·버리기·주기는 예측하지 않는다(호스트의 편집·인벤토리가 오면 바뀐다)
- 상태 묶음(20Hz, 바뀔 때만 + 키프레임은 그대로)에 플레이어마다 **몸 동작과 그 프레임 수, 든 아이템**을 더했다(14 → 16B: flags 3~6비트 = 동작, u8 동작 프레임, u8 든 아이템). 다른 클라이언트는 보간된 시각에 동작을 시작 틱부터 그린다(두 상태 사이에서 시작해도). 동작 중에는 상태가 매 틱 바뀌므로 동작하는 동안 묶음이 20Hz로 나간다
- 든 아이템은 지금 그림이 없다: 슬라이스는 도구를 몸 동작에 그려 넣었고(● R25) 서 있을 때·걸을 때 손에 든 도구 레이어는 2단계(○ brief §5.6)다. 그래서 다른 사람에게는 **동작할 때 그 도구가 보이고**, 든 아이템은 상태·결과 JSON에만 있다(나중에 도구 레이어가 생기면 쓴다)

### 채집물 (`SurfaceGen`, `WorldItems`, `world/item_view.gd`)

- 생성기의 4단계: `Config.GATHER_ON_GRASS`(야생 회복·버프·독초 8개씩, 버섯 a~d 4개씩, 돌 a·b·c·이끼 6·5·5·4)를 깨끗한 풀에, `GATHER_ON_ASH`(재 버섯 6, 금 간 돌 4, 곰팡이 돌 4: 04-env의 "오염 쪽")를 재에 흩는다. 칸 가운데가 안전 반경 + 1타일 밖, 맵 가장자리에서 2칸 안쪽(`GATHER_EDGE_TILES`), 다른 채집물의 8이웃이 아닌 칸. 시드 1: 74개, 제단에서 가장 가까운 것이 약 13타일. 덤불(herb_clump)은 아이템 표에 있지만 흩지 않는다. 모두 임시값
- 채집물은 **식생(VEGETATION) 레이어**에 산다: 값 = 1 + `WorldItems.GATHERABLES`의 순서(0 = 없음). 그래서 스냅샷·월드 해시·편집 기록이 그대로 덮는다. 줍기 = 그 칸의 식생을 0으로 하는 편집. 다시 자라지 않는다(문서에 없음)
- 등급(● gameplay-design §3.4, §3.0 표 "공용 수행 … 일반 등급 약초만"): 약초사가 캐면 약초 넷은 상급, 다른 클래스는 일반. 버섯·돌은 등급이 없다(M2a 임시값 그대로)
- 그림: `ItemView`가 채집물마다 월드 그림(04-env v02, M2a에서 복사한 것), 드롭마다 아이콘을 `Entities`(발 y 정렬) 아래 Sprite2D로 둔다. 노드는 그 칸의 아래 변에 있어서 그 칸 안에 발이 있는 캐릭터는 채집물 뒤, 남쪽 칸의 캐릭터는 앞에 그려진다. 캐릭터와 같은 hard 빛 레이어. 걸음을 막지 않는다(문서에 없음)

### 떨어진 아이템 (드롭, `WorldData.drops`)

- 디버그 F7(임시값 키)이 고른 칸의 묶음 전부를 목표 칸 가운데에 버린다(봇 `drop[:<개수>]`). 칸 하나에 여러 개가 쌓일 수 있고, F는 번호가 가장 작은 것부터 줍는다
- 누가 버렸든 **먼저 주운 사람 것**이다(○ gameplay-design §5 "드롭은 주운 사람 것", 임시값). 보스 드롭 분배는 M2 밖
- 드롭은 타일이 아니라 월드의 목록(번호, 아이템, 개수, 등급, 픽셀 자리)이다. 월드 해시가 덮고, 스냅샷 원본 끝에 `u16 개수 + 11B × 드롭`으로 들어가고(받는 쪽이 아이템·개수·등급·맵 안·번호 중복을 검사), 편집 기록에 "드롭 놓기/바꾸기"(절대값, 16B)와 "드롭 사라짐"(9B) 편집이 더해졌다. 그래서 스냅샷을 보내는 도중에 생긴 드롭도 welcome 뒤 편집으로 간다(`stall` 세션)

### 늦은 참가 (M2b)

- 참가자는 스냅샷으로 채집물(식생 레이어)과 드롭을, welcome의 플레이어 정보로 모두의 든 아이템·동작을 받는다. 그 뒤의 줍기·버리기는 편집으로 온다. welcome 로그에 `gatherables=.. drops=..`
- **다시 참가해도 인벤토리는 이어지지 않는다**: M1에 다시 참가 기억이 없어서 새 참가자는 빈 인벤토리로 시작하고, 나간 플레이어의 인벤토리는 호스트에서 사라진다(저장은 M2 밖)

### 전송 형식 버전 3 (`NetProtocol.VERSION`)

입력 프레임 코드(바라보기), 입력 패킷의 요청, 상태 16B·정보 17B, 인벤토리 메시지(호스트 → 주인, 채널 0 reliable, 6 + 3B × 24칸 = 78B), 드롭 편집, 스냅샷의 드롭. 버전 2 클라이언트는 `version`으로 거부된다.

## M3a: 지도 · 던전 · 채굴 · 횃불

혼자 할 때 먼저(M3a 지시). 문서의 ●는 그대로 따르고(채굴 3단 접근 ● gameplay-design §3.0 R11, 레이어 ● §3.1, 16px ● R18), 나머지는 [임시값](#임시값-사람-확인-필요) 표의 "M3a" 줄이다. 세션(`--host`/`--join`)은 지상 하나뿐이고 M2b 그대로 돈다(아래 "세션에서").

### 지도 (`GameWorld.map_id`, `Main.worlds`, `Main.travel`)

- 지도 하나 = `world.tscn` 하나(GameWorld: 데이터, 바닥/동굴 그림, 엔티티, 빛). `main.tscn`의 `World`가 지상이고, 혼자 할 때 Main이 같은 장면을 하나 더 만들어 `Dungeon`(`map_id` 1)으로 둔다. 한 번에 하나만 보인다: 숨긴 지도의 `CanvasModulate`(어둠)와 빛은 적용되지 않고(F4·F3도 보이는 지도만 받는다), 먼저 숨기고 나서 보인다(두 `CanvasModulate`가 한순간도 같이 보이지 않게 고른 순서다. M3-fix: 전에는 "순서가 바뀌면 어둠이 흰색으로 풀린다"고 적었지만 시험이 없고, 검토가 순서를 바꿔 창으로 오가 봤을 때 차이가 없었다. 그 문장은 확인한 것이 아니라 뺐다)
- 내 캐릭터는 늘 한 지도에 있다: `travel()`이 Player 노드를 그 지도의 `Entities`로 옮기고 `Player.data`를 그 지도의 데이터로 바꾸고(`Player.set_world`: 남쪽을 보고, 동작은 멈춤), 도착점에 세운다. 카메라 경계, 목표 칸 표시(그 지도의 바닥과 엔티티 사이로 옮김)도 같이 바뀐다. 더미는 지상에 남는다
- 도착점: 던전은 출구 계단 바로 남쪽 두 칸의 가운데(`DungeonGen.arrival_point`), 지상은 입구 바로 남쪽(`DungeonGen.arrival_below`). 발은 그 칸 아래 끝에서 `ARRIVAL_FEET_INSET_PX`(4px) 위다(M3-fix에서 이름을 붙임, 값은 M3a 그대로)
- F(M2의 상호작용 키)가 목표 칸이 입구·계단(`WorldItems.is_portal`)이고 손이 닿으면 다른 지도로, 아니면 M2의 줍기

### 던전 생성 (`world/dungeon_gen.gd`)

- `DungeonGen.generate(seed)`: 같은 시드 → 같은 던전. 정수 난수(PCG32)와 칸 계산뿐이라 지상의 FastNoiseLite와 달리 다른 아키텍처에서도 같을 것이다(재 보지는 않았다). 시드 1의 해시 `DungeonGen.GOLDEN_HASH` = `8dda0ad69ad9747c3eadf30abde6524c` (x86_64, M3-fix. M3a는 `009e7147...`)
- 순서: 바위로 채우고 테두리 2칸 기반암 → 방 7개(7~12 × 6~9, 서로·테두리에서 3칸) → 방마다 이미 이은 가장 가까운 방과 3칸 너비 L자 통로 → 출구 계단(방 위쪽 줄의 앞면 칸 2개, 그 위 바위는 기반암) → 도착 방에서 가장 먼 방 가운데에 이단의 제단 자리(3×2) → 도착 방의 벽 횃불(계단 양옆) → 광맥(구리 9 · 철 5, 2~5칸, 걸을 수 있는 바닥 옆 바위에서 시작, 도착 방의 벽 횃불 칸에는 들어가지 않음) → 다른 방마다 북쪽 벽에 벽 횃불(6칸마다, 광석 칸 아님). 도착 방 = 통로를 낸 뒤 계단 자리가 남은 첫 방
- 벽 횃불 자리 (M3-fix): 벽 횃불은 "앞면 있는 맨 바위"(광석·설치물 없음, 아래 칸이 앞면이고 계단이 아님, `DungeonGen.wall_torch_spot_ok`)에만 단다. 원하는 자리(6칸마다 / 계단 양옆, 아치가 계단보다 넓어 계단 옆 한 칸씩은 비움)가 그런 칸이 아니면(통로가 뚫린 자리, 광석, 아래가 앞면이 아님) 같은 북쪽 벽의 가장 가까운 자리로 옮긴다: 6칸마다의 것은 ±2칸 안에서, 계단 옆의 것은 먼저 그쪽 벽 전체에서, 없으면 벽 어디서든. 횃불끼리는 한 칸을 띄운다. 그래도 하나도 없는 방은 벽 가운데에서 가장 가까운 자리에 하나. 출구 계단은 둘레에 벽 횃불 자리가 남는 곳을 먼저 고른다(그런 방이 없을 때만 M3a처럼 계단 자리가 남은 첫 방). 그래서 도착 방은 늘 벽 횃불이 하나 이상이다. M3a는 맞지 않는 자리를 그냥 건너뛰어서, 시드 1~400 중 82개(20.5%)의 도착 방에 벽 횃불이 없었다(검토가 잼, 다시 재 봄). 지금은 시드 1~3,000에서 도착 방에 둘 2,865 · 하나 135 · 없음 0, 방 20,987개 중 벽 횃불이 없는 373개는 북쪽 벽에 맞는 칸이 하나도 없는 방(통로가 북쪽 벽을 거의 다 뚫음)이다. 광맥은 바뀐 것이 없게 했다: 광맥의 출발 칸 목록과 난수는 M3a 그대로이고, 도착 방의 벽 횃불 칸에 닿을 때만 건너뛴다. 시드 1은 출구·광맥(47칸)이 M3a와 같고 벽 횃불만 8 → 10개(두 방에 새로)
- 시험(40시드): 기반암 테두리, 계단은 앞면 칸이고 그 위는 깰 수 없음, 도착점에 설 수 있고 계단 바로 남쪽, 제단 자리는 바닥이고 도착점에서 닿음, 열린 바닥 전부가 한 덩어리(갇힌 곳 없음), 광맥마다 걸어서 닿는 칸에서 캘 수 있음, 두 광석이 다 있음, 벽 횃불은 앞면 있는 바위 위, (M3-fix) 북쪽 벽에 자리가 있는 방은 모두 벽 횃불이 있고 도착 방은 늘 있으며 자리가 있는 계단 쪽마다 그쪽에 하나, 바닥 레이어 0, 동굴 그림 = 규칙. 시드 1: 방 7, 광석 칸 47, 벽 횃불 10(M3a 8), 열린 칸 511

### 벽과 앞면 (`world/walls.gd`, `world/cave_view.gd`)

- 04-env 던전 타일셋은 절벽(cliff) 셋이다: 코너 값이 바닥(lower)·벽 윗면(upper)·앞면(transition) 셋이고, JSON이 "앞면은 경계 **아래** 칸을 차지한다"고 적어 둔 규칙대로 쓴다. 꼭짓점(= 월드 칸 가운데) 값 = 벽 칸이면 벽, 벽 바로 아래 바닥 칸이면 앞면, 아니면 바닥, 맵 밖은 벽(`Walls.vertex`). 그림 칸·청크·반 칸 밀림은 지상 dual grid 그대로다(`CaveView`, 청크 32)
- 벽의 앞면(24px, 타일에서 잼: 벽 칸 가운데 줄 3px 아래부터)은 벽 아래 칸 위에 그려진다. 그래서 **그 앞면 칸은 막힌다**(`Walls.blocks`, 걷기 충돌 = 그려진 것). 앞면 칸을 조준하면 그 위의 벽을 친다(`Walls.owner_of`). 남쪽에서 벽 쪽으로 걸으면 발이 앞면 아래 끝에 딱 붙어 서서 캐릭터가 앞면 앞에 그려지고, 북쪽에서 붙으면 벽 윗면이 발 아래(남쪽)라 겹치지 않는다. 그래서 벽(`CaveView`)을 y 정렬하지 않고 늘 엔티티 아래에 그린다. M3-fix: "벽이 캐릭터를 가릴 일이 없다"는 말은 너무 넓었다. 앞면 칸의 옆 칸(같은 줄)에 선 캐릭터의 그림이 앞면 쪽으로 삐져나오면 앞면 위에 그려지고, 앞면이 다음 줄로 3px 내려온 부분도 그 바로 남쪽에 선 캐릭터 아래에 그려진다. 창에서만 보이는 일이라 사람이 본다(알려진 문제)
- 결과: 가로 굴은 두 줄 이상이어야 들어갈 수 있다(위 줄은 윗벽의 앞면). 광부의 3×3은 자연히 그렇고, 다른 클래스는 두 줄을 판다. 세로 굴은 한 줄도 된다
- 타일 고르기(`CaveTable`): 코너 키 81개 중 셋에 그림이 있는 21개, 키 넷은 타일이 둘이라 위·아래 꼭짓점(JSON `pattern_4x4`의 바깥 줄, "context")이 맞는 쪽을 쓴다(예: 벽의 서쪽 가장자리 위 끝 t1_10과 그냥 t1_4). 속 타일 변형(바닥 3, 벽 윗면 2)은 지상처럼 칸 위치 해시로. 셋에 없는 키(앞면 바로 아래 벽 윗면, 한 줄 차이로 끝나는 두 벽 등)는 가장 가까운 키(코너마다 앞면↔벽 1, 앞면↔바닥 1, 벽↔바닥 2)로 그리고 `verify()`가 fallback으로 센다. 생성된 던전 40개에 모두 19칸, 마구 깬 뒤에는 많아진다(시드 1에서 무작위 편집 120번 뒤 111칸): 깬 자리의 모양에 따라 앞면이 짧게 끊겨 보이고, 대각선으로만 이어진 자리(코너가 앞면·바닥·바닥·벽인 그림 칸)는 실제로는 막혔는데 바닥이 이어진 통로처럼 보일 수 있다(M3-fix 검토, 알려진 문제. 충돌은 맞다: 대각선으로 빠져나가지 못한다)
- M3-fix: 꼭짓점 값의 앞면은 `Walls.is_face`와 같다. 전에는 맵 맨 윗줄의 바닥 칸을 "맵 밖 = 벽" 아래라고 앞면으로 그렸지만 걷기는 열려 있었다(그린 것 ≠ 막힘). 이제 바닥으로 그린다. 생성된 던전에는 없는 경우다(기반암 테두리는 깨지지 않는다)
- 광맥 그림: 04-env `tiles_ore_*_v02`는 벽 윗면 타일에 광석을 박은 16×16이라, 같은 윗면 타일과 다른 픽셀(22~36개)만 떼어 벽 칸 위에 얹는다(앞면 있는 벽은 앞면 위까지만). 구리·철 a/b는 칸 해시로
- 금: 맞은 벽은 `Walls.crack_stage`(최대 타격의 1/3씩, 1~3단계)의 04-env `wall_crack_top_v01`을 윗면에, 앞면이 보이는 벽은 `wall_crack_face_v01`을 앞면에도 얹는다(04-env 던전 목업의 자리)
- 편집 하나를 다시 그리는 범위: 그 칸과 아래 칸이 코너나 둘레에 드는 그림 칸(가로 2 × 세로 5)과 위·아래 칸의 오버레이. 무작위 편집 120번을 제자리에서 다시 그린 그림 = 새로 그린 그림(시험)

### 채굴 (`items/mining.gd`)

- ● gameplay-design §3.0 R11 광부 줄: 공용 = "누구나 채굴. 느리고 1×1, 경도 상한", 전용 = "3×3 고속, 상위 경도". 그대로 광부만 3×3, 광부의 휘두르기는 타격 2배, 경도 상한은 공용 1 · 광부 2. 숫자는 임시값: 경도 바위 1 · 구리 1 · 철 2 · 기반암 깰 수 없음, 깨지는 타격 바위 6 · 구리 8 · 철 10, 휘두르기 한 번 공용 1 · 광부 2타. 그래서 바위 한 칸에 공용 6번(3.6초), 광부는 3번에 3×3 아홉 칸. 철은 광부만
- 곡괭이 등급 (M3-fix에서 바로 적음): gameplay-design §3.1의 줄(●/○ 표시 없음)은 "벽 타일에 경도 등급. 곡괭이 등급이 경도 이상이어야 파괴 (테라리아). 상위 광석은 상위 곡괭이 → 광부 개인 트랙의 축"이다. M3에는 곡괭이가 하나(등급 없음)뿐이라 **곡괭이 등급은 만들지 않았고**, 그 자리를 ● R11의 클래스 상한("경도 상한" / "상위 경도", `HARDNESS_CAP_*`)이 대신한다. 전에는 이 줄의 앞 절반만 "○ §3.1"로 적어 뒤 절반(곡괭이 등급)을 바꾼 것이 드러나지 않았다. 곡괭이 등급을 넣을지는 사람이 정한다(임시값 "M3a 경도·타격")
- ○ §3.2의 "마우스 방향의 인접 타일을 타격, 홀드하면 연속"은 M2의 목표 칸·누르고 반복 그대로. 휘두르기는 곡괭이 동작의 4번째 프레임(`MINING_IMPACT_FRAME` 3, 18틱째)에 맞는다(M2 `m2_use.png`의 그 프레임이 땅을 친다)
- 3×3이 어디로 뻗는지는 문서에 없다(임시값 `MINER_AREA_AWAY`): 친 칸에서 시작해 플레이어 반대쪽으로 3칸, 휘두르는 방향의 가로로는 가운데. 대각선은 그 구석에서 뻗는다. false면 친 칸 가운데
- 맞은 칸은 타격이 쌓이고(벽 바이트 위 4비트), 최대에 닿으면 깨진다: 바위 → 돌 a(`MINED_ROCK_ITEM`), 광석 칸 → 구리/철 광석. 인벤토리에 넣고, 안 들어가면 그 칸 가운데에 드롭(○ §3.2 "채굴 시 드롭은 인벤토리로 자동"에서 가득 찼을 때는 임시값), 땅의 드롭이 `MAX_DROPS`면 사라짐. 벽 횃불은 그 벽과 같이 없어진다
- 아무것도 깰 수 없는 곳(기반암 테두리, 계단 위 바위, 그 클래스에 너무 단단한 칸, 벽이 아닌 곳)은 휘두르기만 하고 아무 일도 없다. **광부의 3×3도 같다**(M3-fix): 친 칸(앞면이면 그 위 벽)을 그 클래스가 깰 수 없으면 3×3 전체가 아무 일도 하지 않는다. 전에는 3×3이 깰 수 없는 칸 둘레의 바위를 깨서, 시드 1에서 광부가 계단을 세 번 치면 계단 옆과 기반암 뚜껑 뒤의 바위 13칸이 깨지고 계단이 홀로 선 기둥이 됐다(검토 탐침, 다시 재 봄). 깰 수 있는 바위를 쳐서 그 3×3이 기반암을 덮는 것은 그대로다(기반암 칸만 건너뜀). 그래서 계단 옆 바위를 일부러 치면 뚜껑 둘레를 파낼 수는 있다(계단과 뚜껑은 남는다, 알려진 문제). 지상에는 벽이 없으니 곡괭이는 M2 그대로다
- 이단의 제단은 벽이 아니라 칠 수 없다(파괴는 M4)

### 횃불 (`WorldItems.place`, `world/fixture_view.gd`, `light/torch_light.gd`)

- ● gameplay-design §3.0 R11 표의 "기본 키트 (횃불, 발판)"의 횃불. 상인(M8) 대신 디버그(F5 묶음 10개, `--give=torch:<수>`)로 받는다. 아이템 종류 "놓는 것"(`ItemDB.Kind.PLACEABLE`), 묶음 99(재료와 같은 값 `STACK_MATERIAL`). 둘 다 임시값이다(M3-fix에서 임시값 표 "M3a 횃불" 줄에 올림)
- 핫바에서 고르고 좌클릭 = 목표 칸에 하나 놓는다(누르고 있어도 한 번). 놓을 수 있는 칸: 손 닿는 칸, 벽·앞면·설치물·채집물이 없는 바닥(드롭은 있어도 됨). 걸음을 막지 않고 다시 줍지 못한다(임시값). 지상에도 놓을 수 있다
- 빛만이다: 안전 반경(`SafeZone`)은 여전히 제단 하나다(횃불이 안전인지는 문서에 없다). 횃불 빛 = 반경 80px의 딱딱한 네 단계(1 / 0.7 / 0.45 / 0.22, 디더 없음), 바닥과 캐릭터를 다 비춤. 벽 횃불은 48px
- 그림: 횃불 아이템 그림이 없어서 놓은 횃불은 04-env 땅 랜턴 켜짐판(`prop_lantern_ground_v03_lit`, 목업에서 플레이어가 놓은 빛)과 그 빛 마스크(unshaded), 아이콘은 코드로 그린 작은 랜턴(임시)

### 어둠

- 던전은 `DUNGEON_DARK_COLOR`(0.13, 0.11, 0.10) 하나이고 제단 빛이 없다. 빛은 놓은 횃불과 벽 횃불뿐. F4는 어둠과 횃불 빛을 같이 끈다(그림 원래 색)

### 세션에서 (M3a, M3b에서 끝남)

- (M3b에서 바뀜: 아래 "M3b: 세션의 지도") M3a의 세션은 M2b 그대로 지상만이었다: 던전 GameWorld를 만들지 않고, 입구에 F(줍기 요청)를 보내면 호스트가 `dungeon offline only`로 거부했다. 전송 형식은 v3 그대로
- 같은 규칙을 호스트도 쓴다: 횃불 USE는 호스트가 놓고(요청 예산은 줍기와 같음, 편집 + 인벤토리. M3-fix: 예산에 시험이 없었다. `test_net_maps`가 한 틱에 열 번 보내 4번만 예산을 쓰고 나머지는 `rate`인지 본다), 곡괭이가 맞는 틱에 호스트가 채굴한다(지상엔 벽이 없어 아무 일도 없다). 클라이언트는 횃불 놓기를 예측하지 않는다
- 세션의 지도(플레이어마다 지도 번호, 던전 스냅샷, 지도별 편집과 상태)는 M3b에서 넣었다

### 시험 (M3a)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=dungeon,mining < /dev/null   # 약 9초
```

- `test_dungeon.gd`: 던전 타일셋(새로 만든 것 = 커밋된 것, 절벽 타일 25장의 코너·둘레, context로 고르기, 없는 키의 fallback), 생성 규칙 40시드(위 "던전 생성"), 같은 시드 = 같은 던전과 황금 해시, 지상 입구 40시드(하나, 막힘, 빛 밖, 남쪽에 설 수 있음, 시드 1은 원래 자리, 채집물 74개 그대로), 동굴 그림 = 규칙과 무작위 편집 120번을 제자리에서 다시 그린 것 = 새로 그린 것, 충돌(벽·앞면이 막음, 북쪽으로 걸으면 앞면 아래 끝에 딱 붙음, 서쪽 벽, 대각선 미끄러짐, 횃불은 안 막음, 위 벽을 깨면 앞면이 한 칸 위로), 예측(던전에서 1,500틱 무작위로 걸으며 벽에 부딪혀도 호스트 `PlayerSim`과 6틱 늦은 보정이 늘 0), 던전 월드 장면(동굴 그림, 제단 없음, 어둠, 계단·제단·벽 횃불과 빛, F4), 지상 월드 장면(입구와 잔해 장식), `main.tscn`에서 F로 내려가고 올라오기(지도·플레이어 부모·데이터·도착점·카메라 경계·표시·더미), (M3-fix) 호스트를 잃은 클라이언트(빈 던전 월드 + 세션이 만든 Player): 입구 F가 받지 못한 던전으로 가지 않음, 던전을 받았으면 내려가서 혼자 캐고 횃불을 놓음, 세션 호스트가 멤버를 내려보내고 올려보냄
- `test_mining.gd`: 벽 바이트, 앞면과 맞는 벽, 경도·타격 수, 금 단계 표, (M3-fix) 맨 윗줄 바닥은 바닥으로 그려지고 막지 않음, 3×3 모양(동·북동·앞면 너머 북), 공용(한 칸, 6번에 깨짐, 금 1·1·2·2·3, 철은 너무 단단함, 두 칸 떨어진 벽은 못 침), 광부(매번 3×3 아홉 칸, 3번에 바위 8칸이 깨지고 철은 남음, 철 광석), 가득 찬 인벤토리 → 드롭, `MAX_DROPS` → 사라짐, 벽 횃불이 벽과 같이, 계단 위 바위·기반암은 안 깨짐, (M3-fix) 광부·공용이 계단을 여섯 번씩 쳐도 맞은 칸 0·던전 그대로, 디버그 드롭은 앞면·바위에 거부되고 바닥에는 됨, 지상에서 곡괭이는 아무 일 없음, 금 오버레이 자리, 횃불 놓기 규칙 8가지와 `make_frame`(클릭에 한 번), 횃불 그림과 빛(안전 반경 아님), 호스트 `run_frame`(클라이언트의 횃불 USE, 곡괭이가 18틱째에 맞음, 그림이 편집을 따라감), `main.tscn`에서 봇으로 광부가 앞면 위 바위를 깸
- 창 그림 검사 `cave`·`dark` (위 "그림 검사")

## M3b: 세션의 지도

M3a가 혼자 할 때 더한 것(지도 둘, 던전, 채굴, 횃불, 그 드롭)을 세션으로 가져왔다. ● 호스트 권한(game-concept §13)대로 M3가 더한 것을 모두 호스트가 정한다. 새 임시값은 "M3b" 줄이고, 그 밖은 [구현에서 고른 값](#구현에서-고른-값-설계-결정-아님)의 "M3b" 줄이다.

### 지도 번호와 오가기 (`NetMember.map_id`, `SessionHost._travel`, `WorldItems.travel`)

- 플레이어마다 지도 번호가 **호스트 상태**다. 호스트는 지도마다 GameWorld를 가진다(`NetSession.worlds`: `main.tscn`이 지상 `World`와 던전 `Dungeon`을 만들고, 호스트는 던전을 자기 생성기로 만든다). 멤버의 Player 노드는 그 지도의 `Entities` 아래에 있고 그 지도의 데이터 위에서 걷는다(벽 충돌)
- 입구·계단의 F는 요청이다: 클라이언트(와 호스트 자신)의 F(PICKUP)가 자기 지도의 입구·계단 칸을 겨누면 프레임에 붙을 때 `TRAVEL`(지도 + 칸)로 바뀐다(`SessionHost.attach_local_op`). 호스트는 그 프레임의 자리에서 검사한다: 겨눈 지도가 그 멤버의 지도가 아니면 `wrong map`, 줍기와 같은 요청 예산(`rate`), 그 멤버에게 앞 지도를 아직 보내는 중이면 `still loading`, 그다음 `WorldItems.travel`(맵 안, 손 닿는 칸(`REACH_TILES`), 그 칸의 길이 가는 지도: 입구 → 던전, 계단 → 지상. 아니면 `no way there`). 혼자 할 때 `Main.pick_up`도 같은 함수다
- 받아 주면 바로 옮긴다(`move_to_map`): 지도 번호, 노드를 그 지도의 `Entities`로, 도착점에 남쪽을 보고 동작은 멈춤(`Player.set_world`, M3a와 같은 자리). 그 프레임의 걸음은 새 지도에서 진행된다. 호스트 자신이면 바로 그 지도를 보인다(`local_map_changed` → `Main._show_map`). 클라이언트에게는 그 지도를 보낸다(아래). 입구에 PICKUP이 오면 `a way to another map`(줍는 것이 아님)
- 클라이언트는 오가기를 예측하지 않는다: F 뒤에도 지도 들어옴 메시지가 올 때까지(localhost 한두 프레임, 실제 망에서는 왕복 + 지도 조각) 옛 지도에서 걷는다. 메시지가 오면 새 지도로 바뀌고 그동안의 프레임을 새 지도에서 다시 돌린다(아래 "예측")
- 늦은 참가자는 지금처럼 지상에 도착한다. 다시 참가해도 지도는 이어지지 않는다(지상에서 시작, 인벤토리처럼)

### 지도 보내기: 클라이언트는 자기 지도만 (`SessionHost._stream`, `_enter_map`, `SessionClient.on_map_entry`)

**정한 것: 클라이언트는 자기가 있는 지도만 받는다. 들어갈 때 그 지도의 스냅샷을 받고, 그 뒤로는 그 지도의 편집만 받는다.** (다른 길: 모든 지도의 모든 편집을 모두에게 보내고 참가 스냅샷에 지도를 다 넣기)

- 트래픽: 편집이 가장 많은 일은 채굴이다(광부 휘두르기 한 번 = 칸 편집 최대 9개 + 광석·벽 횃불·드롭 편집, 0.6초마다). 고른 방식에서는 지상에 있는 사람이 던전의 채굴 편집을 하나도 받지 않는다(`cave` 세션: 호스트가 내려가 판 편집 7개가 지상의 c1에게 0개). 그 대신 들어갈 때마다 지도 전체를 받는다: 시드 1 던전 64×48 = 원본 18.4KB → 압축 309~345B, 조각 1개(지상은 566~582B). 던전이 여러 개가 되거나 커지면(슬라이스 밖) 차이가 더 벌어진다
- 단순함: 늦은 참가 스냅샷 길(H1, PR #48)을 그대로 쓴다. 같은 `WorldSnapshot`(머리말에 지도 번호만 더함, M3b) · 같은 조각 크기와 틱당 8조각 · 같은 받는 쪽 검사(조각 수·크기·md5·월드 해시 + 기대한 지도 번호) · "스냅샷 위치 + 그 뒤 편집" 규칙. welcome 대신 **지도 들어옴** 메시지(지도, 그 지도 편집 기록의 스냅샷 위치, 스냅샷 수, 그 지도에서의 자기 상태)를 보내고, 받는 동안 생긴 그 지도의 편집은 그 뒤에 번호대로 보낸다. 클라이언트는 떠난 지도의 편집 기록을 버리고 다음에 들어올 때 지도를 새로 받으며(그 지도의 데이터는 그때 바뀐다), "그동안 무엇을 놓쳤나"를 따로 계산하지 않는다. M3-fix: 전에는 "데이터·편집 기록을 버리고"라고 적었지만 실제로 버리는 것은 편집 기록뿐이다. 떠난 지도의 GameWorld는 옛 데이터와 그림(바닥·동굴, 아이템, 설치물, 횃불 빛)을 숨긴 채 들고 있고, 그 지도에 있는 다른 플레이어의 `Player.data`도 옛 데이터를 가리킨다. 아무도 읽지 않아 해는 없다. 들어갈 때마다 지도 그림을 새로 만든다(던전 약 60ms, 그 프레임이 길다)
- 순서: 채널 0(reliable) 하나라 "그 지도의 조각 → 지도 들어옴 → 그 지도의 편집"이 순서대로 온다. 그 플레이어는 받는 동안에도 상태 묶음·출입은 받는다(늦은 참가와 다른 점). 받는 중인 멤버에게는 그 지도의 실시간 편집을 보내지 않는다(`peers_on`). 단위 시험: 1바이트 조각 309개(39틱)로 받는 동안 호스트가 캔 편집이 지도 들어옴 뒤에 간다
- 편집 기록은 지도마다 따로다(`NetSession.log_for`, 번호도 지도마다 0부터). 편집 메시지에 지도 번호를 더했다: 클라이언트는 자기 지도가 아닌 편집을 잘못된 메시지로 센다(호스트는 보내지 않는다)
- 클라이언트의 지도 들어옴: 조각을 검사해 그 지도의 GameWorld에 올리고(`load_data`: 동굴 그림, 횃불, 드롭), 자기와 남의 Player 노드를 그 월드로 옮기고, 예측을 새 데이터로 바꾸고(`Prediction.switch_map`), Main에 알린다(`local_map_changed`: 지도·카메라·표시·어둠). 로그 `map entered map=dungeon world=... bytes=345 raw=18456 chunks=1 edits=7 drops=0 torches=1 cracked=6 build_ms=62.3`, 떠난 지도는 `map_left map=dungeon edits=.. world=..`

### 상태와 그리기 (`NetProtocol` 상태 17B, `Interpolation`, `SessionClient.draw_others`)

- 상태 묶음의 상태마다 지도 번호(u8)를 더했다(16 → 17B, 정보 18B). 묶음은 여전히 모든 플레이어를 담아 모두에게 간다: 자기 지도의 사람만 그리고(`Player.visible`), 다른 지도의 사람은 위치만 따라간다(결과 JSON의 위치 해시가 지도까지 같은지 본다). 지도별로 나눠 보내지 않은 이유: 묶음이 작고(사람당 17B), 누가 지도를 옮겼는지가 묶음·키프레임 흐름에 그대로 실려 따로 메시지가 필요 없다. 지상의 c1은 호스트가 던전에서 캘 때 초당 약 1.07KB(상태만)를 받는다(아래 측정). 9인이 지도 둘에 흩어지면 지도별 묶음이 더 싸다(알려진 문제)
- 보간: 다른 지도의 상태가 오면 그 사람의 버퍼를 비우고 새 지도에서 다시 시작한다. 두 지도 사이를 섞어 그리지 않는다(단위 시험)
- 늦은 참가자의 welcome에도 플레이어마다 지도가 있어 던전에 있는 사람은 지상에 그리지 않는다(`cave` c2, `four` c4. 로그 `welcome ... elsewhere=2`)
- 호스트 화면도 같다: 다른 지도의 멤버는 숨긴 GameWorld 안에 있어 그려지지 않는다

### 채굴·횃불·드롭 (호스트 검사)

- 채굴은 두 번 검사한다. 사용(USE): 그 칸에 곡괭이, 목표 칸이 발 옆, 동작 중이 아님(`busy`: 휘두르기 하나가 끝나야 다음, 그래서 동작 길이가 채굴의 속도 제한이다), 겨눈 지도가 그 멤버의 지도. 맞는 틱(`Mining.impact_tick`): 그 멤버의 지도 데이터에서 `Mining.strike`(벽인지, 친 칸이 그 클래스의 경도 상한 안인지, 3×3). 아무것도 못 깬 휘두르기는 이유별로 센다(결과 JSON `swings_missed`: `no wall`, `too hard`). 기반암 테두리·출구 위 기반암은 공용·광부 모두 `too hard`(편집 없음. 광부는 M3-fix부터, 위 "채굴"). `Mining.strike`에도 손 닿는 칸 검사가 있지만 세션에서는 걸릴 수 없다: 사용이 시작될 때 이미 봤고 `ACTION_LOCKS_MOVEMENT`(임시값 true)가 맞을 때까지 발을 묶는다. 그 임시값을 끄면 쓰이는 방어 검사로 남겼다(M3-fix 검토: 지워도 시험이 통과한다는 지적)
- 금(맞은 횟수)·깸·광석·벽 횃불이 떨어지는 것·가득 찼을 때 드롭은 모두 그 지도의 번호 붙은 편집이다(벽 바이트 위 4비트 = 맞은 횟수라 금이 다른 사람에게 그대로 보인다). 횃불 놓기(요청 예산)도 같다
- 같은 칸을 같은 틱에 둘이 치면: 호스트는 자리 순서로 처리하고 편집을 바로 적용한다. 그 칸이 한 번 남았으면 자리가 작은 쪽이 깨고 돌을 갖고, 다른 쪽 휘두르기는 `no wall`(그 앞면을 쳤다면 위 벽이 없어져 앞면도 아니다). 두 번 남았으면 둘 다 맞고 두 번째가 깨고 갖는다. 광부 둘의 3×3이 겹치면 겹친 칸마다 한 번씩만 깨지고 아이템은 그 칸을 깬 쪽 하나에. 규칙: **그 칸을 깬 타격의 주인이 갖는다** (`test_net_maps.gd`의 세 경우, `four` 세션은 실제 세션에서 정확히 한 번 깨짐과 깬 쪽의 돌을 본다. 실제 세션에서 같은 틱은 맞추지 못했다: c2·c3가 4틱 차이로 맞았다)

### 예측 (`Prediction`)

- 예측은 클라이언트가 가진 그 지도의 데이터(호스트 편집이 적용되는 같은 `WorldData`)로 걷는다. 데이터는 호스트보다 늦을 뿐 벽이 생기지는 않으므로(벽은 깨지기만 한다) 보통은 클라이언트가 "호스트가 이미 깬 벽"에 막힌다. 그동안은 호스트 상태가 보정하고, 다시 돌릴 때 그 벽 안에서 시작해도 이미 겹친 장애물은 무시해서(`Movement`) 빠져나온다. M3-fix에서 바로 적음: 보정은 편집이 온 **뒤 상태 하나쯤까지** 이어진다(확인 안 된 프레임의 결과는 보정할 때만 다시 계산하므로 편집 뒤 첫 상태가 한 번 더 보정한다). 또 편집(reliable)이 상태보다 먼저 오면, 호스트가 벽이 아직 있을 때 처리한 프레임을 클라이언트는 벽 없이 다시 돌려 **잠깐 앞서 나갔다가** 당겨진다. 검토의 실제 세션 탐침(호스트가 클라이언트 앞의 벽 9칸을 깸): 대칭 지연 6/6/6 보정 1번 최대 2.4px, reliable 0 · 상태 8 · 입력 8 지연 2번 3.6px, reliable 10 · 상태 2 · 입력 2 지연 1번 1.2px, localhost 1번 1.2px, 모두 같은 위치에서 끝남. 단위 시험(편집 0·30·90틱 늦게, 대칭 6틱 지연)은 보정 0·2·3번이고 편집 뒤 2 × 지연 + 3틱이 지나면 0번, 마지막 위치 같음. 비대칭 순서와 지연 + 남이 깬 벽을 같이 도는 세션 시험은 없다(알려진 문제)
- 지도를 옮기는 동안: 클라이언트의 상태 중 다른 지도의 것(지도 들어옴보다 먼저 온 묶음)은 맞추지 않고 센다(`other_map`). 지도 들어옴의 상태(그 플레이어가 마지막으로 처리된 프레임 뒤)에서 확인 안 된 프레임을 새 지도에서 다시 돌린다(`switch_map`, 보정으로 세지 않음). 옛 지도를 겨눈 사용은 호스트가 `wrong map`으로 거부하므로 다시 돌릴 때도 동작을 시작하지 않는다(`Prediction.anim_on_map`)

### 전송 형식 버전 4 (`NetProtocol.VERSION`)

상태 17B(+ 지도), 정보 18B, 타일 요청(USE 6B, PICKUP 5B, DROP 7B)에 겨눈 지도 u8, 새 요청 TRAVEL(지도 u8 + 칸 s16×2 = 5B), 편집 메시지에 지도 u8(칸 11B, 드롭 놓기 17B, 드롭 사라짐 10B), 스냅샷 머리말에 지도 번호(22B), 새 RPC `_rpc_map`(지도 들어옴 66B: 지도, 편집 위치, 원본·압축 크기, 조각 수, md5 둘, 자기 상태). 입력 프레임은 1바이트 그대로다(TRAVEL도 프레임에 붙는 요청). 버전 3 클라이언트는 `version`으로 거부된다.

### 시험 (M3b)

- `test_net_maps.gd` (위 "네트워크 테스트"), `test_net_session.gd`의 `cave` 세션과 `four`의 던전 경주. `_check_agreement`가 지도별로 바뀌었다: 모든 인스턴스의 모든 지도(호스트는 전부, 클라이언트는 자기 지도)가 그림 = 데이터(지상은 대체 타일 0, 던전은 대체 타일을 세지 않음), 클라이언트의 지도 = 호스트의 그 지도(해시, 그림 해시, 편집 수, 채집물, 드롭), 위치 해시에 지도까지
- `test_dungeon.gd`의 세션 시험은 "입구 거부" 대신 "호스트가 멤버를 내려보내고 올려보냄"이다. 시드 1~8 던전 해시 묶음
- 창 그림 검사 `cave_net`, 스모크 M3b 항목

## M4a: 체력 · 대시 · 기본 공격 · 사망 · 이단

혼자 할 때 먼저(M4a 지시, M3a가 던전에서 한 것처럼). (**M4b에서 세션에도 켰다**: 아래 [M4b: 세션의 전투](#m4b-세션의-전투). 이 문단의 세션 이야기는 M4a 때의 것이다.) **세션(`--host`/`--join`)에서는 적·피해·대시·시작 무기·사망 가방이 꺼져 있고 M2b·M3b 흐름 그대로다**(M4b에서 켠다): 세션은 아레나를 만들지 않고, 입력 프레임의 새 칸(대시·F 누르고 있기·조준 코드)은 전송 형식에 싣지 않는다(v4 그대로). 그래서 세션에서 검·활을 휘두르면 M2b처럼 몸 동작만 보인다. 문서의 ●는 그대로 따랐다: 실시간 에임형(● gameplay-design §2.1 R12), 사망 = 일부 아이템 드롭(● §2.6 R12, 내구도는 M7), 오염 원천은 누구나 전투로 파괴(● §3.0 팔라딘 줄), 부활 지점 = 제단(§2.6), 적은 위협 쪽 색(● game-concept §10 R19, 13차 시트 그대로). ○·?와 문서에 없는 것은 모두 [임시값](#임시값-사람-확인-필요) 표의 "M4a" 줄이다.

### 공유 시뮬레이션 (`actors/vitals.gd`, `PlayerSim.step`)

- 플레이어 상태에 **Vitals**를 더했다: HP, 스태미나(쉬는 시간·회복 틱), 대시(남은 틱·방향·쿨다운), 경직(피격 틱)·피격 무적 틱, 삶(서 있음 / 다운 / 사망)과 그 시간, 소생 진행, F 누르고 있은 시간. `PlayerSim.step`은 여전히 혼자·호스트·예측이 같이 쓰는 규칙 하나이고, 인자 셋을 뒤에 더했다(대시, F 누르고 있기, 조준 코드). 순서: 다운이면 다운 시간만 센다(`DOWN_TICKS` 또는 F를 `GIVE_UP_HOLD_TICKS` 누르면 사망), 사망이면 부활 시간만(`RESPAWN_TICKS`에 한 번 RESPAWN), 서 있으면 무적·쿨다운·스태미나 → M2b의 동작 진행 → 대시 중이면 대시만 → 경직 중이면 아무것도 → 이 프레임의 대시 시작 → M2b의 사용 시작(이제 조준 코드를 같이 담음) → 이동·바라보기
- 대시: Space. 스태미나 `DASH_STAMINA`, `DASH_TICKS` 동안 `DASH_SPEED`(240px/s, 10틱에 40px)로 누른 방향(없으면 바라보는 쪽), **걷기와 같은 `Movement.step`**(속도 인자만 더함)이라 벽·앞면·제단·입구·계단·제단 옆 띠를 지나지 못한다(틱당 4px, 막는 것은 모두 16px 이상이라 건너뛰지 못함). 동작·경직·다운 중에는 시작하지 않는다. 대시 동안 무적(`DASH_INVULNERABLE`). M4-fix: 다른 지도로 가면(입구·계단의 F, `Player.set_world`) 하던 대시가 끝난다(쿨다운은 이어짐). 전에는 계단 앞에서 Space 뒤 F를 누르면 도착점에서 대시가 이어졌다
- 피해는 밖에서 온다: `PlayerSim.hurt(양)`(서 있고 무적이 아닐 때만 HP를 깎고, 하던 동작·대시를 끊고, 경직 + 피격 무적. 0이면 다운). `Player.take_hit`이 부르고 `hurt` 시그널을 낸다
- 그림: 경직 중 `base_body_v02_hurt`, 다운 중 `base_body_v02_death`(마지막 프레임 = 누움, 표식은 숨김), 사망 중 그리지 않음, 맞은 순간 붉은 깜빡임(코드). 피격·사망은 아이템이 부르지 않는 "자세"라 `RigData.POSE_ANIMS`(액션 8개와 따로)이고, 기준점 표·창 검사 `rig`이 같이 잰다
- 결정성 시험: 같은 프레임(걷기·대시·검 사용·F)과 같은 피해를 혼자(`Player.step_frame`)·호스트(`SessionHost.run_frame`, 전송 없음)·예측(`Prediction.step_frame`)에 1,500틱 넣으면 Vitals까지 매 틱 같다(`PlayerSim.same_all`). Vitals는 아직 상태 묶음에 없다(`same_as`는 M3b 그대로): 세션에서는 늘 가득이라 어긋날 것이 없고, M4b가 묶음에 넣는다

### 기본 공격 (`combat/combat.gd`, `Config.CLASS_WEAPONS`, `WEAPON_ATTACKS`)

- 클래스마다 하나: 팔라딘 검(근접 호), 아처 활(화살), 성직자 성광(새 도구 아이템 `holy_light`, 마법 동작, 빛 탄), 광부 곡괭이(근접), 약초사 낫(근접, 문서에 없음). M2의 규칙("좌클릭 = 핫바에서 든 아이템 사용")을 그대로 쓴다: 무기는 도구 아이템이고, 누구나 어떤 무기든 쓸 수 있다(임시값). 혼자 할 때는 클래스 무기가 **핫바 8번**(`START_WEAPON_SLOT`)에 들어 있다: F5 묶음과 `--give`가 M2·M3의 칸 번호(곡괭이 1번, 횃불 7번)를 그대로 쓰게 맨 끝 칸이고, 고른 칸은 1번 그대로다(그래서 Q 한 번). 세션에서는 아직 주지 않는다
- 공격은 무기의 맞는 프레임(`Player.action_impact`, `Combat.impact_tick`)에 시작할 때의 조준(M4-fix: 화살이 그려져 나가는 점 `Combat.aim_origin` = 몸 점 12px 위 → 마우스 각도를 0..255로, `PlayerSim.action_aim`. 전에는 발 → 마우스) 쪽으로 나간다. 근접: 발끼리 사거리 안, 조준 둘레 호 안, 두 몸 점(발 상자 가운데) 사이에 막는 칸이 없는 모든 이단(과 서 있는 이단의 제단). 화살·빛 탄: 공격자 몸 점에서 조준 쪽으로 무기 속도, 틱마다 2px씩 나아가며(M4-fix: 두 걸음 사이에 지나는 칸도 모두, `Combat.cells_on_line`. 벽 모서리끼리만 닿은 틈으로 빠지지 않고, 걸음 사이 칸에서 멈추면 그 앞 점에서 선다) 처음 닿는 막는 칸(벽·앞면·제단·입구·계단·이단의 제단 = 걷기를 막는 것, 맵 밖)이나 이단(M4-fix: 그린 화살이 그린 몸 상자 안, `Combat.shot_hits_body`: 발 좌우 8px, 발에서 위로 28px. 전에는 발 상자 가운데에서 8px)에서 멈추고, 사거리를 다 가면 사라진다. 그래서 그린 화살은 마우스 커서를 지나가고, 이단 그림 어디를 눌러도 맞는다(임시값 "M4-fix 화살 조준·맞는 상자"). 그림은 바닥 점에서 12px 위에 그린다(화살: 코드로 그린 10×3, 각도대로 돌림. 빛 탄: 6×6 금빛, unshaded)
- 아군 사격 끔(`FRIENDLY_FIRE`): 플레이어의 공격은 플레이어에게 닿지 않는다(화살은 아군을 지나 뒤의 이단에 맞는다)
- **광부의 곡괭이**는 무기이자 채굴 도구다(○ §1). 한 번의 휘두르기가 둘 다 하지 않게: **목표 칸이 벽이나 벽의 앞면이면 채굴만**(M3 그대로, 옆의 이단은 맞지 않음), **아니면 공격만**(벽은 그대로). 맞는 틱은 M3의 채굴 프레임 그대로(`MINING_IMPACT_FRAME`) 하나다. 세션의 호스트 채굴은 M3b 그대로다
- 공격 속도는 동작 길이다(`ACTION_FRAME_TICKS` 6틱 × 프레임 수, 누르고 있으면 반복): 검·활 0.8초, 성광·곡괭이·낫 0.6초

### 다운 · 소생 · 사망 · 부활 (● gameplay-design §2.6, 숫자는 임시값 줄)

- 0 HP → 다운: 못 움직이고 동작·대시·F 줍기·F7이 없고, 이단의 표적이 아니다. 다른 플레이어가 24px 안에서 F를 누르고 있으면(그 사람은 서 있고 동작·대시·경직 중이 아님) 소생: 성직자는 그 틱에 바로, 다른 클래스는 5초(300틱), 놓으면 처음부터, 그동안에도 다운 시간은 흐른다. 여럿이 누르고 있으면 가장 빠른 사람 기준이다(M4-fix: 성직자가 하나라도 누르면 즉시, ● §2.6 "성직자는 즉시". 전에는 플레이어 순서(세션에서는 자리 번호)의 첫 사람 기준이라 팔라딘 호스트 + 성직자 클라이언트가 5초 걸렸다). 소생하면 HP 30, 맞은 뒤와 같은 30틱 무적(`HURT_INVULN_TICKS`). 30초 지나면 사망. 혼자일 때는 소생해 줄 사람이 없어 30초를 기다리거나 **F를 1초 누르고 있으면 포기**(바로 사망)
- 사망 → **가방**(● §2.6 "인벤토리의 재료·소모품 중 일부가 죽은 자리에 가방으로", `WorldItems.death_drop`): 도구(무기 포함)를 뺀 칸(재료·채집물·횃불)에서 '일부'를 뗀다. `DEATH_DROP_RULE` 하나로 바꾼다: 절반 규칙(지금, 칸마다 절반 올림) / 무작위 3종 규칙(종류 셋을 시드로 골라 그 칸 전부). 가방은 죽은 칸(그 칸에 설치물·채집물·드롭이 있으면 3칸 안 가장 가까운 빈 칸)의 **설치물 `PLACEABLE_BAG` + 그 칸 가운데의 보통 드롭(칸마다 하나)**이다. 그래서 M2b·M3b의 월드 기계(레이어 칸 편집, 드롭 편집, 스냅샷, 해시)를 그대로 지난다: M4b는 가방에 새 전송 형식 없이 지금의 편집을 보내면 된다(시험: 같은 편집을 데이터에 바로 적용한 것과 해시 같음, 스냅샷 왕복). 그림은 04-env 작은 자루(임시)이고 그 칸의 드롭 아이콘은 그리지 않는다. 걸음을 막지 않는다
- 가방 되찾기: F로 그 칸을 겨누면 그 칸의 드롭을 모두(들어가는 만큼, 번호 순) 줍고, 다 비면 가방이 사라진다. 누구나 주울 수 있고(구출 플레이), 저절로 사라지지 않는다. 땅의 드롭이 `MAX_DROPS`에 가까우면 들어가는 칸만 떨어지고 나머지는 인벤토리에 남는다. 하나도 들어가지 않으면(이미 `MAX_DROPS`) 가방 없이 아무것도 잃지 않는다(M4-fix: 전에는 빈 가방이 생겼다, `too many drops`). 빈 칸을 못 찾으면 가방 없이 아무것도 잃지 않는다
- 부활: 사망 5초 뒤 지상 제단의 자기 스폰 자리(혼자: 자리 0)에 남쪽을 보고, HP·스태미나 가득. M4-fix: 부활 때가 되면 누가 부활시킬 때까지 매 프레임 알린다(사망 틱은 거기서 멈춤): 그 때가 지난 채 넘어온 사망 상태(던전에서 죽어 지상을 기다리던 클라이언트가 호스트를 잃고 혼자 계속)도 다음 틱에 부활한다(전에는 그 틱에 딱 한 번이라 영영 죽어 있었다). 던전에서 죽어도 지상 제단으로 올라온다(가방은 던전에 남음). 사망 중에는 몸을 그리지 않고 카메라는 죽은 자리에 남는다
- HUD(`ui/hud.gd`): 왼쪽 위 HP(붉은)·스태미나(금빛, 대시 비용 밑이면 어두운 금빛) 막대, 다운 중 위쪽 가운데에 남은 다운 시간(녹빛)·소생 진행(금빛)·포기 누르기(상아빛, 누를 때만), 사망 중 위쪽 가운데에 부활까지 초(3배 숫자). 월드에는 누운 플레이어 위에 다운 시간·소생 막대(`CombatView`), 다친 이단과 이단의 제단 위에 HP 막대. 모두 코드로 그린 임시 그림이다

### 이단 (`combat/heretic_sim.gd`, `combat/arena.gd`, `actors/heretic.gd`)

- 시트(03-pixel 13차 채택 후보, `art/enemies/`에 그대로 복사): 걷기 6·idle 4·피격 6·사망 7(32칸, 발 y=31, 첫 열 0), 공격 8(64칸 9열, 첫 열 = 시작 그림, 발 y=47). 줄 남·동·북, 서쪽 = 동쪽 줄 반전(`Rig` scale.x = -1, 플레이어와 같음). 노드 = 발(32칸의 (16, 32), 64칸의 (32, 48)), `Entities` y 정렬, 캐릭터 빛 레이어. 앵커·SHIFT는 쓰지 않는다(표식이 없음)
- 상태: 집에서 idle → 표적이 보이면 쫓기(걷기) → 22px 안이면 공격 → 피격(경직) / 사망(사망 프레임, 2초 뒤 사라짐) / 빛 가장자리에서 지켜보기 / 집으로. 표적 = 같은 지도의 서 있는(다운·사망 아님) 플레이어 중 112px 안, 벽 없이 보이는, (빛에 안 들어가는 동안) 빛 밖의 가장 가까운 사람(○ §2.3 어그로 대신, M9까지). 집에서 256px 넘게 끌려가면 표적을 버리고 돌아간다. 이동은 플레이어와 같은 `Movement.step`(벽·앞면·설치물·제단 충돌, 속도만 46px/s), 8방향 직선이고 길 찾기는 없다(벽에 막히면 미끄러지거나 선다)
- 공격과 예고: 공격을 시작하면 표적 쪽 4방향을 보고, **맞는 열 앞의 열들**(칼을 든 그림)을 `HERETIC_ATTACK_FRAME_TICKS`씩 보여 주다 그 마지막 열을 붙잡아 **예고가 모든 방향에서 30틱(0.5초)**이 되게 한다. 30틱째에 맞는 열(남 3·동 4·북 5열, 13차 후보 쌍의 앞, ?)을 보이며 칼이 떨어진다: 그 순간 공격 방향 둘레 120°, 28px 안, 벽 없이 닿는 서 있는 모든 플레이어(빛 안의 사람은 빼고)에게 12. 나머지 열을 보이고 45틱 쉰다. 칼은 공격에만 그려진다(13차 "칼은 공격에만") = 예고. 대시(무적, 또는 사거리 밖으로)로 피할 수 있다. 맞아도 이미 시작한 공격은 끊기지 않는다(`HERETIC_HURT_INTERRUPTS_ATTACK` 끔: 검 두 번이면 예고가 늘 끊겨 이단이 영영 못 치던 것을 시험이 보여서)
- **빛과 이단** (game-concept §9.3 안전 반경 = 빛·스폰 억제·오염 저항): 기본값은 `HERETIC_ENTERS_LIGHT` 끔 — 발 상자가 빛에 한 픽셀도 들어가지 않고(걸음을 축 하나로 줄이거나 서 있음), 빛 안의 플레이어를 노리지 않고, 공격 중 플레이어가 빛 안으로 들어가면 칼이 닿지 않는다. 쫓던 사람이 빛으로 들어가면 **가장자리에 서서 4초(`HERETIC_LIGHT_EDGE_WAIT_SEC`) 그 사람을 바라보다 집으로 간다**. 이 기본값을 고른 이유: 판정 기준 "제단의 빛이 '안전'으로 읽히는가"(game-concept §12)를 시험하려면 빛이 실제로 안전해야 하고(안에서는 맞지 않는다), 그것이 화면에서 읽혀야 한다. 바로 돌아서면 "빛이 막았다"인지 "흥미를 잃었다"인지 구분되지 않지만, 빛 테두리에서 딱 멈춰 지켜보는 이단은 빛이 경계라는 것을 보여 준다. 끝없이 지키면 빛에 갇히므로 4초 뒤 돌아간다. M4-fix: 4초는 지켜보기 시작부터 센다. 빛 안에서 쏘아 맞혀도(그 경직도 센다) 다시 세지 않아서 4초가 차면 집으로 간다(전에는 맞을 때마다 처음부터라 빛 안의 아처가 가장자리의 이단을 죽을 때까지 쏠 수 있었다: 검토 탐침 61발, 끝까지 가장자리). 그래도 빛 안의 사람은 표적이 아니어서, 가장자리 4초·집으로 가는 동안·사거리 안 집에 서 있는 동안의 이단은 빛 안에서 맞지 않고 칠 수 있다(맞은 이단이 물러날지 빛 안을 노릴지는 정하지 않았다: 임시값 "M4-fix 빛 안에서 쏘인 이단", 사람이 정함). 횃불 빛은 안전이 아니다(M3a 줄 그대로, `TORCH_LIGHT_IS_SAFE` 끔. 켜면 횃불 반경도 같은 규칙)
- 스폰(`Arena.try_spawn`): 플레이어가 있는 지도만 시간이 흐른다(아무도 없는 지도의 이단은 그대로 기다림. M4-fix: 마지막 사람이 떠날 때 한 번 비운다, 아래 "빈 지도"). 그 지도에 들어간 뒤 480틱(8초)마다 한 번(M4-fix: 다시 들어와도 그때부터 480틱. 전에는 떠날 때 멈춘 시계가 이어져 들어오자마자 생길 수 있었다), 살아 있는 수가 상한(지상 4, 던전 6) 밑이면 후보 칸에서 24번(`HERETIC_SPAWN_TRIES`)까지 뽑는다: 지상은 오염 구역(재)과 그 둘레 2칸, 던전은 도착점에서 걸어서 14칸 이상인 바닥(도착 방에서 먼 방·통로). 발 상자가 빛에 닿지 않고(후보 목록과 스폰 검사 두 번), 모든 플레이어에서 160px 이상. 난수는 월드 시드 + 지도 번호(같은 시드 = 같은 스폰)
- 지도: 아레나는 지도마다 하나(`Main.arenas`), 이단은 지도를 옮기지 않는다
- **빈 지도** (M4-fix, 임시값 "M4-fix 빈 지도", `Arena.idle_tick`·`on_emptied`): 지도의 마지막 사람이 떠나면(오가기, 던전에서 죽어 지상 부활, 세션에서 나감) 그 지도의 아레나를 한 번 비운다: 진행 중인 공격은 칼 없이 끝나고 공격 뒤 쉼(45틱)이 이어진다, 경직이 끝난다, 모든 이단이 표적과 빛 가장자리 지켜보기를 잊는다(집으로 가던 것은 그대로), 날던 화살·빛 탄이 사라진다, 스폰 시계가 0부터, 시체는 남는다. 그다음은 예전처럼 사람이 올 때까지 기다린다. 이유: 계단으로 도망치는 사람은 계단 앞(돌아올 때의 도착점)에서 떠나므로, 예고 중에 멈춘 공격이 다음에 오는 사람에게 남은 예고만큼만 보이고 떨어졌다(검토 탐침: 돌아온 지 8틱 뒤). 혼자 할 때도 같다(`Main.step_combat`가 떠난 지도를 비움)

### 이단의 제단 (● gameplay-design §3.0 "오염 원천은 누구나 전투로 파괴 가능")

- 서 있는 제단(M3a 자리 3×2)은 HP 150이고 근접 호(가장 가까운 점이 사거리·호 안, 벽 없이)와 화살·빛 탄(그 칸에 닿으면)에 맞는다. 맞으면 깜빡이고 위에 HP 막대. 0이 되면 자리 여섯 칸이 `PLACEABLE_SHRINE_BROKEN` 편집이 된다(월드 기계 그대로, M4b용). 부서진 제단은 여전히 막고(임시값), 그림은 제단 판 + 04-env 뼈 더미를 얹은 임시 그림, 불은 꺼진 그대로(? 이단 쪽 불 색). 부서지면 던전 스폰이 멈춘다(`SHRINE_STOPS_SPAWNS`, 문서는 "첫 던전 = 첫 오염 원천"까지라 결과는 임시값). 제단 자체는 공격하지 않는다

### 시험 (M4a)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=combat,heretic < /dev/null   # 약 10초
```

- `test_combat.gd`: 대시(거리·스태미나·쿨다운·회복 대기·입력 없을 때·동작/경직/다운 중 안 됨·무적, 벽에 딱 붙어 멈춤, 던전과 제단 둘레 6,000틱 무작위 대시가 막힌 곳에 한 번도 안 섬), 경직(HP·경직·무적, 동작 끊김, 피격 자세와 깜빡임, 경직 중 못 걸음, 6프레임), 다운·사망(다운 중 못 움직임, 사망 자세 → 누움, 표식 숨김, 30초에 사망, 5초 뒤 부활 한 번, F 1초 포기와 놓으면 처음부터), 소생(팔라딘 5초·성직자 즉시, 사거리 밖·놓기·너무 늦은 소생·다운된 성직자), 무기 표(클래스 다섯, 맞는 프레임, 곡괭이 = 채굴 프레임, 조준 코드 왕복, 격자 선 걷기), 근접 셋(사거리 안·밖, 호 끝 안·밖, 뒤, 벽 너머), 화살·빛 탄(속도, 첫 이단, 사거리 끝, 벽, 제단), 아군 사격 끔, 곡괭이 규칙, 가방(절반 규칙 정확한 수, 3종 규칙 40시드, 도구 남음, 도구뿐이면 없음, 같은 칸 두 번째 가방, 거의 찬·가득 찬 인벤토리, `MAX_DROPS`, 빈 칸 없음), 가방의 월드 기계(GameWorld 편집 = 데이터 편집 해시, 그림, 스냅샷 왕복, 되찾으면 그림에서도 사라짐), 공유 시뮬레이션 1,500틱(혼자 = 호스트 = 예측), `main.tscn`(시작 무기, 검으로 이단을 죽이고 먼저 맞음, 다운 중 F 줍기 없음, 혼자 포기 → 가방 → 5초 뒤 제단 → 가방 되찾기, 던전에서 죽어도 지상 제단·가방은 던전에)
- `test_heretic.gd`: 그림(다섯 상태 × 네 방향의 줄·반전·발 원점, HP 막대, 시트 크기·프레임·칸), 공격(네 방향: 바로 시작, 바라보기, 30틱째 맞음, 맞는 열 그림, 예고 프레임, 길이, 쉼), 대시로 피하기, 쫓기(가장 가까운 사람, 속도), 시야·벽·다운된 사람, 끈, 빛(가장자리에서 안 들어감·안 맞음·지켜보다 돌아감, 다시 나오면 맞음, 공격 중 빛으로 들어간 사람은 안 맞음, 빛 테두리를 가로지르는 추격도 안 들어감), 20,000틱 긴 실행(스폰 켬, 플레이어가 이단을 꾀어내고 빛 가장자리로 돌아오기를 되풀이: 이단이 빛에 한 번도 안 들어감, 빛 안에서 맞은 적 0), 30시드 지상 스폰 칸·스폰(빛 밖, 오염 둘레, 플레이어에서 멀리), 스폰 검사 자체가 빛 안 158곳을 모두 거부, 던전 10시드 스폰 칸이 도착 방에서 먼 곳, 스폰 시각·상한·플레이어 없는 지도, 제단(HP, 검으로 부숨, 부서진 자리, 스폰 멈춤, 계속 막음, 화살·빛 탄, 막대, 부서진 그림, 불 없음), `main.tscn`(지상에 있으면 던전은 안 흐름, 광부: 벽을 겨누면 채굴만 하고 호 안의 이단은 안 맞음, 바닥을 겨누면 이단만 맞고 월드 그대로)
- 창 그림 검사 `rig`(피격·사망 더함)·`heretic`·`bars`(위 "그림 검사"), 스모크 M4a 항목
- M4-fix에서 더한 것: `test_combat` — 두 소생자 두 순서(성직자가 있으면 첫 틱), 부활 알림(때부터 매 프레임, 지난 사망 상태), 오가기가 대시를 끝냄, 화살 조준(`make_frame`의 마우스로 활·성광 360발: 그림 위 2~26px 모두 맞음, 옆으로 머리 위는 빗나감), 모서리 벽 줄에 1,625발(넘어간 것 0), 아레나 한 틱 비용(note), `MAX_DROPS`에서 가방 없음, 예측 리플레이 = 예측 상태(`same_all`). `test_heretic` — 빛 안에서 1·2초마다 쏘아도 지켜보기 시작 240틱 뒤 집으로, 빈 지도(공격 취소·쉼·경직 끝·화살 없앰·스폰 시계·두 번째는 그대로·돌아와도 예고 한 번 안에 안 맞음·다시 480틱 뒤 첫 스폰), `main.tscn`에서 예고 중 입구로 내려갔다 올라옴, 거울 아레나의 제단 자리가 편집마다 따라감

## M4b: 세션의 전투

M4a가 혼자 할 때 더한 것(HP·스태미나·대시, 기본 공격, 경직·다운·소생·사망·가방·부활, 이단과 그 스폰, 이단의 제단 파괴)을 세션으로 가져왔다. ● 호스트 권한(game-concept §13)대로 **싸움의 결과는 모두 호스트가 정한다**: HP·스태미나·다운/사망, 적(스폰·AI·HP·공격), 날아가는 것, 피해, 소생, 부활, 가방, 이단의 제단. 클라이언트는 자기 이동·대시·공격 동작과 그 타이머를 M2 방식으로 예측하지만(`PlayerSim.step`) 피해는 만들지 않는다. 새 임시값은 [임시값](#임시값-사람-확인-필요) 표의 "M4b" 줄, 그 밖은 [구현에서 고른 값](#구현에서-고른-값-설계-결정-아님)의 "M4b" 줄이다. 스킬(1·2·3)·시그니처(R)·우클릭 보조·클래스 자원·"가장 가까운"을 넘는 어그로·방어 수치·내구도·상태이상·포션은 여전히 없다(M4 밖).

### 호스트 (`net/session_host.gd`)

- **아레나는 지도마다 하나**(`SessionHost.arenas`, 혼자 할 때와 같은 `Arena`)이고 그 뷰(`CombatView`)가 호스트 화면에 그린다. 매 틱 모든 멤버의 프레임을 돌린 뒤 **사람이 있는 지도의 아레나만** 돈다(M4a와 같은 순서: 소생 → 이단 → 날아가는 것 → 치우기 → 스폰). 스폰 난수는 그 지도 데이터의 시드라 혼자 할 때와 같은 열이다
- **입력**: 프레임 코드에 대시(Space를 누른 틱)와 F 누르고 있기를 더했다(코드 0..179, **1바이트 그대로**). USE 요청에 조준 코드(u8, `Combat.aim_code`)를 더했다(USE 6 → 7B). 호스트는 그 프레임을 처리할 때 검사한다: 다운·사망 중의 타일 요청(사용·줍기·버리기·오가기)은 `down`, 대시·경직 중의 사용은 `busy`(M2b의 `busy`·손 닿는 칸·도구 검사는 그대로). 고르기(Q/E)와 디버그 주기는 다운 중에도 된다
- **공격**: 무기의 맞는 프레임(`Combat.impact_tick`)에 호스트가 **그 틱의 자기 상태**로 푼다(`Arena.player_attack`: 그 플레이어의 호스트 위치에서 사거리·호·벽, 프레임이 실어 온 조준). 클라이언트가 어디 있다고 주장할 길이 없다(위치는 늘 호스트가 프레임으로 정한 것). 곡괭이는 M4a 규칙 그대로(벽·앞면을 겨누면 채굴만, 아니면 공격만. 공격이 된 곡괭이 휘두르기는 M3b처럼 `no wall`로 센다)
- **시작 무기**: 접속하면(호스트 자신도) 클래스 무기가 핫바 8번에 들어온다(`Main.give_start_weapon`, 혼자 할 때와 같다). 인벤토리는 M2b처럼 주인에게 간다
- **사망·가방·부활**: 사망하면 호스트가 `WorldItems.death_drop`으로 가방을 만든다(그 지도의 번호 붙은 편집 = 그 지도의 모두에게, 늦게 오는 사람에게는 스냅샷으로). 주인에게 인벤토리를 보낸다. 사망 5초 뒤 그 멤버의 스폰 자리(지상)에 `PlayerSim.respawn`(혼자·호스트·예측이 같이 쓰는 규칙). 던전에서 죽었으면 지상으로 옮기고(`move_to_map`) 클라이언트에게 지상을 보낸다. 그 클라이언트에게 앞 지도를 아직 보내는 중이면 끝날 때까지 기다린다
- **클라이언트의 시계** (M4-fix, `SessionHost.run_client_frames`, 구현 표 "클라이언트 시계"): 멤버가 "시간을 쓰는" 동안(vitals 타이머가 돎 = `Vitals.idle` 아님: 경직·무적·대시·쿨다운·다운·사망·스태미나 회복, 또는 몸 동작이 진행 중) 호스트는 그 멤버의 시계 빚을 센다: 호스트 틱마다 +1, 돌린 프레임마다 −1. (1) 빚이 0이면 그 틱에는 그 멤버의 프레임을 더 돌리지 않고 다음 틱으로 미룬다(`InputGate.put_back`): 쌓아 둔 프레임을 한꺼번에 보내도 경직·대시 쿨다운·동작이 호스트 시간보다 빨리 끝나지 않는다(검토 탐침: 맞은 뒤 30프레임을 한 패킷으로 보내면 5틱 만에 걸었고, 41프레임 떨어진 대시 둘이 12틱 간격으로 나갔다). (2) vitals가 도는 동안 빚이 `NET_HOST_STEPS_AFTER_TICKS`(30틱)를 넘으면 호스트가 빈 프레임으로 틱마다 직접 진행한다(로그 `host_steps`): 보내기를 멈추거나 가끔(20틱마다 하나씩) 보내도 다운 시간·무적·부활은 호스트 시간으로 흐른다(검토 탐침: 20틱마다 한 프레임이면 1,890틱 뒤에도 다운 94틱째였다). (3) 쉬면 빚은 0이다: 서 있던 클라이언트가 맞으면 그 사실을 알고 프레임을 보내기 시작할 때까지(왕복 + 묶음 간격)만 빚진다. 한 방향 약 200ms까지는 30틱 안이라 호스트가 진행하지 않고 보정도 없다(시험: 3·9틱 지연, 실제 세션 `fightlag`). M4b 규칙은 프레임이 없던 틱을 서 있는 동안까지 세어, 1초 서 있다 맞으면 바로 다음 틱부터 호스트가 진행하고 그 뒤 온 클라이언트 프레임도 돌려 타이머가 두 번 흘렀다(호스트에서 경직·무적·다운이 왕복만큼 일찍 끝나고 클라이언트는 `vitals_correction`). 남는 것: 서 있다 맞은 클라이언트의 경직·무적은 호스트에서 왕복만큼 늦게 시작해 그만큼 늦게 끝난다(알려진 문제)
- 로그 줄: `hit slot=<누가> map= heretic=<번호> amount= hp=<남은 HP>[ KILLED]`, `hurt slot= map= amount= hp=[ DOWN]`, `revived`, `died ... bag=x,y items=n`, `respawn`, `heretic_attack map= heretic= slot=<표적>`, `shrine_broken`, `host_steps slot=<s>: <n> ticks behind the host while ...`, (M4-fix) `map_emptied map= heretics= attacks_cancelled=`
- **빈 지도** (M4-fix): 지도의 마지막 사람이 떠난 틱에 그 아레나를 한 번 비운다(위 M4a "빈 지도"). 그 지도의 뷰도 그때 한 번 그리고, 그 뒤 아무도 없는 동안은 그리지 않는다(바뀌는 것이 없다. 전에는 매 틱 모든 지도의 뷰를 그렸다)

### 전송 형식 버전 5 (`NetProtocol.VERSION`)

- 입력 프레임 코드 = 방향 + 9 × (look + 1) + 45 × 대시 + 90 × F 누르고 있기(0..179, 0..44는 M2b 코드 그대로). USE 요청 + u8 조준
- **상태의 vitals 블록**: flags 7번 비트가 서 있으면 상태 뒤에 16B(HP, 스태미나, 삶, 스태미나 쉬는 틱, 회복 틱, 대시 남은 틱, 대시 방향 0..8, 대시 쿨다운, 경직, 무적, 맞은 깜빡임, 포기 누르기, u16 삶의 틱, u16 소생 진행). **쉬는 중(가득·일어섬·타이머 없음, `Vitals.at_rest`)이면 블록이 없다**: 싸움이 없는 세션은 M3b와 같은 17B 상태다. HP는 저절로 차지 않으므로 맞은 플레이어는 그 뒤로 33B. 받는 쪽은 필드마다 그 Config 상한을 넘으면 거부하고, 쉬는 값의 블록(보내지 않는 것)도 거부한다. 정보(welcome·들어옴) 18 또는 34B, 지도 들어옴 66 또는 82B
- **적 묶음**(새, `_rpc_enemies` 채널 3 unreliable / `_rpc_enemy_keyframe` 채널 0): 호스트 틱, 지도, 이단의 제단 HP(u16, 서 있는 것이 없으면 0), 이단마다 17B(u32 번호, f32 위치 둘, 바라보기·걷기·상태 비트, **상태가 시작된 틱의 하위 16비트**, HP, 깜빡임 남은 틱). 묶음에 없는 이단은 사라진 것. 한 묶음 최대 64마리
- **화살·빛 탄 사건**(새, `_rpc_shots` 채널 0 reliable): 지도, 사건 수, "쏨"(u32 번호, 무기, 쏜 사람 자리, 틱, 출발점 f32 둘, 조준 = 20B), "멈춤"(번호, 틱, 자리 f32 둘, 이유 = 18B)
- 버전 4 클라이언트는 `version`으로 거부된다

### 적: 지도마다, 그 지도의 사람에게만 (`SessionHost._send_enemies`, `StateBroadcast.decide_encoded`)

- 지도마다 적 묶음을 **그 지도에서 지도 들어옴이 끝난 사람(`peers_on`)에게만** 보낸다(M3b 편집과 같은 길, gameplay-design §3.1 ○ "타일 동기화가 던전 안 인원끼리만"과 같은 생각). 지상에 있는 사람은 던전의 적·화살 메시지를 하나도 받지 않는다(시험 두 곳)
- 플레이어 묶음과 같은 판단(`StateBroadcast`를 지도마다 하나): 20Hz에 바뀐 것이 있으면 unreliable, 멈추면 reliable 키프레임 한 번, 그다음 조용함. 시간으로 흐르는 상태(공격·피격·사망·가장자리 지켜보기)는 **시작 틱**을 보내서 흐르는 동안 묶음 내용이 바뀌지 않는다: 서서 공격하는 이단은 공격이 바뀔 때만 묶음을 낸다. idle·걷기 그림 프레임은 클라이언트 시계로 돈다(보내지 않음)
- **공격이 시작된 틱에는 20Hz를 기다리지 않고 그 틱에 보낸다**(`NET_ENEMY_SEND_ON_ATTACK`): 예고가 최대 2틱 빨리 간다
- 늦은 참가·지도 들어옴: welcome / 지도 들어옴과 그 뒤 편집 바로 다음(채널 0 순서)에 그 지도의 적 키프레임과 날고 있는 화살·빛 탄("쏨" 사건)을 보낸다. 가방·부서진 제단은 월드 데이터라 스냅샷 안에 있고, 다운·사망한 플레이어는 welcome의 플레이어 정보와 상태 묶음의 vitals 블록에 있다. 이단의 제단 HP는 적 묶음 머리말에 있다

### 클라이언트가 그리는 것 (`net/net_combat.gd`)

- 받은 묶음을 이단마다 트랙으로 모으고, 매 프레임 거울 아레나(`Arena.mirror`: 데이터만, 돌리지 않음)에 채워 혼자 할 때와 같은 `CombatView`가 그린다(이단·HP 막대·깜빡임, 화살·빛 탄, 이단의 제단 막대, 다운된 플레이어의 막대). 창 그림 검사 `combat_net`이 호스트가 그린 것과 픽셀까지 같은지 본다
- **그리는 시각** (임시값 "M4b 적 그리기"): 위치·HP·피격·사망·깜빡임과 남의 화살은 다른 플레이어처럼 `NET_INTERP_DELAY_MS`(100ms) 뒤에, **공격(칼을 든 예고)은 아는 가장 새 시각에 바로**(`NET_ENEMY_WINDUP_FRESH`), 자기 화살은 사건이 오는 대로 바로. 예고가 피하기의 전부라 100ms를 아낀다. 어긋나는 것: 걷던 이단이 멈춰 공격할 때 위치가 그 100ms(최대 4.6px) 동안 따라오면서 공격 프레임이 시작된다. 지연된 위치 표본이 아직 공격 안인데 공격이 끝났으면 쫓는 그림으로 보인다
- **화살·빛 탄 (정한 것: 호스트 사건 + 클라이언트 비행)**: 호스트가 쏜 틱에 "쏨"(출발점·조준·무기·틱)을, 멈춘 틱에 "멈춤"(자리·이유)을 reliable로 보내고, 클라이언트는 그 사이를 같은 조준 벡터(`Combat.aim_vector`)·무기 속도로 날린다. 멈춤이 오면 그 틱에 그 자리에서 끝낸다(오지 않으면 사거리 끝까지). 위치를 묶음으로 복제하는 길과 비교한 이유: 트래픽 — 화살 하나가 사건 둘 38B(+ 메시지 머리 2B)다. 위치 복제는 활이 날 수 있는 0.73초 동안 20Hz × 약 13B ≈ 190B이고 날고 있는 동안 적 묶음이 매번 바뀌어 나간다. 맞음 — 같은 함수·같은 벡터라 60Hz로 매끄럽고 출발점과 멈춘 자리가 호스트 것 그대로다(위치 복제는 20Hz 계단에 보간 지연이 붙고, 3틱보다 짧게 난 화살은 아예 안 보일 수 있다). 사건은 잃으면 화살이 안 보이거나 벽을 지나 보이므로 reliable이다. 클라이언트는 자기 화살을 예측하지 않는다(왕복 뒤에 나타난다, 알려진 문제)
- 적 메시지가 지금 지도가 아닌 것(지도 들어옴을 앞질러 온 unreliable 묶음)은 적용하지 않고 센다. 잘못된 적·화살 메시지는 잘못된 메시지로 센다

### 판정: 호스트 시간, 되감기 없음 (임시값 "M4b 판정")

- **모든 맞음은 호스트가 그 틱에 자기 상태로 푼다**: 이단의 칼은 호스트의 플레이어 위치와 무적(대시·피격 뒤)으로, 플레이어의 공격·화살은 호스트의 이단 위치로. 되감기(lag compensation)는 없다. 코드: `Arena._knife`·`player_attack`·`_step_shot`을 `SessionHost.tick`이 호스트 상태로 부른다
- 고른 이유: 혼자 할 때·호스트·예측의 규칙이 하나이고, 클라이언트가 보낸 시각이나 위치를 믿을 일이 없다(속일 길이 없다). 이단이 느리고(46px/s) 근접 사거리가 넓어(26px, 120°) 되감기로 얻는 것이 작다. 늦는 만큼 손해는 "예고를 보고 피할 시간"이 준다는 것이다
- **잰 효과** (`test_net_combat.gd`, 한 프로세스, 한 방향 지연을 틱으로 고정, 한 번에 피하는지 맞는지를 틱마다 시험): 예고는 500ms(30틱). 클라이언트는 공격이 시작된 뒤 **한 방향 지연만큼** 지나 예고를 그린다(그 틱에 보내고 바로 그리므로). 그때부터 대시를 눌러 피할 수 있는 마지막 순간은 (29 − 2 × 지연 틱)틱 뒤다: 한 방향 0ms → 500ms 안에, 50ms → 400ms, 100ms → 300ms, 150ms → 200ms. 예고를 다른 것처럼 100ms 뒤에 그렸다면 각각 100ms 짧다(400 / 300 / 200 / 100ms). 시험이 지연 0·3·6·9틱마다 그 마지막 틱에는 피하고(HP 그대로) 한 틱 뒤에는 맞는 것을 확인한다. 사람 반응(약 200~250ms)으로 보면 한 방향 100ms(왕복 200ms)까지는 피할 수 있고 150ms면 빠듯하다. 이 수는 가정 위의 것이다(M4-fix 검토): 시험은 클라이언트가 그리는 시각을 "호스트 틱 − 지연"으로 정해 준다(`RemoteClock`이 정확하다고 봄. 그래서 "예고를 본 때 = 지연"은 잰 것이 아니라 정한 것), 지도에 막 들어온 클라이언트는 지도를 그리는 시간(던전 약 57~70ms, 그동안 화면이 멈춤)만큼 더 짧다(M4-fix 전에는 그 자리에서 멈춰 있던 예고가 이어져 훨씬 짧았다, 위 "빈 지도"), 실제 세션의 `LinkSim`은 unreliable만 늦춘다(적 키프레임·화살 사건은 지연 없이)
- 공격 쪽: 3틱(50ms) 지연에서 쫓아오는 이단을 클라이언트는 호스트 위치에서 최대 6.9px 떨어진 곳에 그린다(속도 × (지연 + 보간)). 그 그림(의 가운데, M4-fix)을 겨눈 아처가 화살로 이단을 죽였다(맞는 상자: 발 좌우 8px, 위로 28px). 서서 싸우는 이단은 0px

### 예측 (`Prediction`, M4b)

- 예측 상태가 Vitals까지다. 호스트 상태가 vitals를 실어 오고(쉬는 중이 아니면), 확인 안 된 프레임을 거기서 다시 돌린다. 대시·경직의 끝·다운 시간·사망·**부활**(지상이면 같은 프레임에 같은 스폰 자리)을 이동처럼 예측한다. 던전에서 죽었으면 호스트가 지상을 보내고 지도 들어옴이 이어 받는다(M3b `switch_map`)
- 프레임 기록: M2b 조건에 더해 F를 누르는 동안과 뗀 프레임, 대시 프레임, **vitals 타이머가 도는 동안 매 틱**(그 프레임들이 호스트에서 그 플레이어의 시계다). 서서 쉬면(HP가 덜 차 있어도) 여전히 아무것도 안 보낸다
- **호스트 사건**: 맞음·소생·소생 진행은 호스트만 안다. 호스트 상태의 HP·삶·소생 진행이 예측과 다르면 사건 보정(`event_corrections`, `max_event_error_px`)으로 세고 오차(`max_error_px`)·바라보기·동작 보정에는 넣지 않는다. 그 밖의 vitals 차이는 `vitals_corrections`(생기면 로그 `vitals_correction`). M4-fix: 시험에서 늘 0이고, 서 있다 맞은 클라이언트도 한 방향 9틱(150ms)까지 0이다(한 프로세스 시험, 실제 세션 `fightlag` 왕복 120ms·손실 5%). M4b README는 "늘 0"이라 했지만 시험 봇이 늘 걷거나 공격하는 중에 맞아서였고, 서 있다 맞으면 3틱 지연에서 2번, 9틱에서 6번 났다(검토)
- 다른 플레이어는 상태의 vitals로 그린다(피격·다운·누움 자세, 깜빡임, 다운·소생 막대). HUD는 자기 예측의 vitals다

### 시험 (M4b)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_combat < /dev/null   # 한 프로세스 (약 10초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_fight < /dev/null    # 실제 세션 셋 (약 65초, M4-fix에서 fightlag 더함)
```

- `test_net_combat.gd` (한 프로세스, 진짜 `SessionHost`·`SessionClient`, 호스트 메시지를 잡아 클라이언트에 순서대로 주고 클라이언트 입력 패킷을 호스트에, 필요하면 한 방향 지연 고정): 악의 클라이언트(70px 밖에서 휘두르기는 호스트 위치로 재서 안 맞음, 4칸 밖 칸은 `out of reach`, 한 패킷 40프레임 사용은 휘두르기 하나 나머지 `busy`·맞음 최대 하나, 다운 중 사용·줍기·버리기·오가기 `down`·대시·걸음 없음, 60px 밖 F는 소생 진행 0이고 20px 안은 정확히 300틱, 지상에서 던전 가방 줍기 `wrong map`); 둘이 이단 하나와 싸움(클라이언트가 받은 묶음마다 그 틱의 호스트 HP와 같고 본 HP 순서가 호스트 순서를 따름); 아처 화살만으로 처치(3틱 지연, 쏨·멈춤 사건, 화살 그림); 다운 → 호스트가 소생(정확히 300틱, 클라이언트가 진행과 HP 30을 봄), 거꾸로, 성직자 즉시; 포기 → 가방(모두의 월드 = 호스트) → 다른 사람이 가방 전부 → 같은 프레임 부활 예측; 클라이언트 둘이 이단의 제단을 부숨 → 편집으로 둘에게, 그 뒤 세 스폰 간격 동안 던전 스폰 0, 나중에 내려간 사람은 스냅샷에 부서진 제단; 지상에 남은 사람은 던전 적·화살 메시지 0; 싸움 도중 늦은 참가(다운된 호스트·예고 중인 이단이 호스트 그대로); 넷이 이단 둘과 3틱 지연으로(모두 HP 순서·마지막 적 그림·위치가 호스트와 같고 시체가 사라짐); 예고 대 지연(위 "판정"); 조용한 클라이언트(무적이 호스트 시간으로 끝남, 다운인 채 조용하면 제때 사망, 다시 보내면 부활). M4-fix: 두 소생자(팔라딘 호스트 + 성직자 클라이언트, 다운된 아처 호스트 옆의 팔라딘·성직자 클라이언트 두 자리 순서: 모두 3틱 안), 서 있다 맞기(3·9틱 지연: 호스트 진행 0, 보정은 호스트 사건뿐), 20틱마다 한 프레임 보내는 다운 클라이언트(다운 시간 + 30틱 안에 사망), 몰아 보낸 프레임(맞은 뒤 30프레임: 경직 18틱 전에는 못 걸음, 대시 둘은 40틱 이상 떨어짐), 예고 중에 던전을 떠났다 돌아옴(빈 지도: 칼 없음, 화살 없음, 빈 지도에 급한 적 묶음 없음, 돌아온 뒤 예고 한 번 안에 안 맞음), 던전에서 사망(가방은 던전, 지상 스폰 자리 부활, 클라이언트도 지상, 예측 오차 0), 지도를 받는 중의 부활(1바이트 조각으로 던전을 받는 동안 부활 시각: 받기가 끝난 뒤에 부활하고 지상으로)
- `test_net_fight.gd` (실제 세션, `test_net_session.gd`의 도구를 그대로 씀): `fight` — 호스트(팔라딘) + c1(아처, `--test-start-hp=archer:12`) + 늦은 c2(성직자), 이단 셋을 지상에 놓고 스폰 끔: c1이 빛 안에서 화살만으로 H2를 죽이고, H3에게 다가가 한 번에 다운, 호스트가 다가가 H3을 죽이고 c1을 소생, 호스트가 H1을 한 번 친 뒤 서 있는 동안 c2가 참가(싸움 도중), 셋이 H1을 죽임. 확인: 세션 공통 검사 전부(위치·월드·그림·예측 오차·빈 번호 등), 호스트 로그의 맞음·다운·소생·처치, c1·c2가 본 H1의 HP 순서가 호스트 것을 따름(c2는 처음부터 다친 H1), 마지막 적 그림 해시 = 호스트, vitals 보정 0, c1의 사건 보정 ≥ 2. `fight4` — 호스트 + 셋(아처·광부·성직자)이 이단 둘과 끝까지: 셋 이상이 맞힘, 모두의 HP 순서·마지막 적 그림 = 호스트. 둘 다 트래픽을 note로 남긴다. `fightlag` (M4-fix) — 호스트(성직자) + c1(광부, `--net-lag=120 --net-loss=5`)이 이단 하나 옆에 9초 서 있는다: 맞을 때마다 그 전에 쉬고 있던 클라이언트다. 확인: 다섯 번쯤 맞음, 호스트가 c1을 직접 진행한 틱 0, c1의 vitals 보정 0·사건 보정 ≥ 맞은 수, 세션 공통 검사
- 바꾼 기존 시험(M4b가 규칙을 일부러 넓혀서): `test_net.gd` 프레임 코드 45 → 180개, USE 크기, RPC 표 18개(새 셋), vitals·적·화살 전송 형식 시험 추가. `test_net_maps.gd` 버전 5, 지도 들어옴 뒤 적 키프레임, 스폰 끔(M3b 검사라). `test_net_session.gd` pair의 늦은 약초사 인벤토리에 시작 무기(낫), 모든 세션 인스턴스에 `--test-no-spawns`(M2b·M3b 세션은 하던 것만)
- 창 그림 검사 `combat_net`, 스모크 M4b 항목

## M6a: 제작 · 조제대 · 물약 · 약제 투척 · 효과

혼자 할 때 먼저(M6a 지시, M3a·M4a처럼). (**M6b에서 세션에도 켰다**: 아래 [M6b: 세션의 제작 · 물약](#m6b-세션의-제작--물약). 이 문단의 세션 이야기는 M6a 때의 것이다.) **세션(`--host`/`--join`)에서는 제작·마시기·던지기·효과가 꺼져 있고 M4b 그대로다**: 세션의 플레이어는 `Player.potions_on`이 꺼져 있어 물약 좌클릭과 1이 아무 프레임도 만들지 않고, 호스트는 물약의 USE를 `not a tool`(도구 아님, M2b 검사 그대로)로, 조제대 놓기를 `alchemy table offline only`로 거부하고(M3a의 "dungeon offline only"처럼), Tab은 늘 인벤토리다. 전송 형식은 v5 그대로이고 효과는 vitals 블록에 없다(M6b). 문서의 ●는 그대로 따랐다: 작물 셋 = 물약 셋(회복·버프·상태이상, ● game-concept §12 R28), 상급·상태이상 물약은 약초사만(● gameplay-design §3.0 R11 약초사 줄 "상급·최상급 약제, 상태이상 약제"), 약초사가 캔 약초가 상급(● §3.4, M2b 그대로), 물약 색 = 작물 색(● brief §5.7 R29: 회복 빨강, 버프 호박, 독 = 독초 노랑 + 녹 반점), 에임형(● §2.1). ○·?와 문서에 없는 것은 모두 [임시값](#임시값-사람-확인-필요) 표의 "M6a" 줄이다. 농사·씨앗·자라기·물주기·정화(M5), 작업대·모루·성물 제작대 레시피와 도구·무기 만들기(M7), 건설, 상인·상점 물약(M8), 다른 스킬·스킬 키, 클래스 자원, 기도, 효과 둘 밖의 것, 새 적, Steam, 저장은 M6a가 아니다.

### 제작 틀 (`items/crafting.gd`, M7이 이어 쓴다)

- **작업대** = 놓는 설치물 하나(`Crafting.STATION_OF`: 설치물 값 → 작업대 종류, M6-fix: `STATION_ICON`: 종류 → 제작 창 머리의 아이콘, 자리 크기는 `WorldItems.FOOTPRINT_OF`). M6a는 조제대(`WorldData.PLACEABLE_ALCHEMY` → `alchemy`) 하나다. 플레이어의 발 칸이 그 자리에서 `STATION_REACH_TILES`(2칸, 체비셰프) 안이면 그 작업대에 있다(`station_near`: 가장 가까운 것 = Tab이 여는 창, 같으면 자리 왼쪽 위 칸이 줄 순서로 앞인 것. `station_of_kind_near`(M6-fix): 그 종류 중 가장 가까운 것 = 호스트의 CRAFT 검사. `still_at`: 창을 연 그 작업대가 아직 그 자리에 있고 손 닿는지(M6-fix: 다른 작업대가 더 가까워져도 닫히지 않음)). M6-fix: 발 칸 둘레 2칸 안의 칸을 모두 보고 거기 걸친 자리 전체를 재므로 자리 크기에 상관없다(M6b는 3칸 자리에 맞춘 창에서 자리의 왼쪽 위 칸만 봐서 5칸 자리를 놓쳤다)
- **M7이 새 작업대에 더할 것** (M6-fix에 적음. M6b의 "값을 더하면 된다"는 너무 넓었다): `STATION_OF`·`STATION_ICON`·`FOOTPRINT_OF`의 값과 레시피, 그리고 아직 조제대만 아는 곳: `FixtureView`의 그림(탁자만 그림), 제작 창의 줄 모양(입력 하나만 그림, 클래스 표시는 약초사 주머니 하나), 창 자리·스크롤(여섯 줄에 142px). 클래스 거부 문구는 레시피의 클래스에서 만든다(`Recipe.class_refusal`: 약초사면 `herbalist only`). 한 화면에 종류가 다른 작업대 둘이 붙으면 Tab은 가장 가까운 것의 창만 연다(호스트는 손 닿는 어느 것이든 받는다). M7a가 이것들을 했다: `FixtureView.FURNITURE`(작업대마다 그림), 제작 창의 재료 셋·수리 줄·스크롤(아래 "M7a")
- **레시피** = 작업대, 입력(아이템·수·등급: 정확한 등급 또는 −1 = 아무 등급), 출력(아이템·수·등급), 만들 수 있는 클래스(비면 누구나). `Crafting.recipes()`가 순서대로(작업대마다, 회복·버프·독, 일반 → 상급)
- **만들기** (`craft`, 모두 아니면 하나도 아님): 해금됐고, 클래스가 되고, 입력이 다 있고, 입력을 뺀 뒤에 출력이 들어가야 한다(`refusal`이 인벤토리 사본에서 해 봄). 그다음 입력을 **뒤 칸부터** 빼고(가방 칸이 핫바보다 먼저, 핫바의 묶음이 오래 남게. 구현 선택) 출력을 넣는다(M2a의 넣기 규칙: 같은 묶음 먼저, 그다음 앞쪽 빈 칸 = 핫바부터). 하나라도 안 되면 아무것도 바꾸지 않고 이유를 돌려준다: `locked`, `herbalist only`, `missing inputs`, `no room`(자리가 없으면 거부, 땅에 떨어뜨리지 않음: 임시값)
- **해금** (○ §3.5 "레시피는 재료를 처음 획득했을 때 해금"): `RECIPES_UNLOCK_ON_FIRST_GET` 켬이면 그 레시피의 입력 아이템을 모두 한 번이라도 가져 본 플레이어에게만 보인다(아무 등급). 인벤토리가 넣은 적 있는 아이템을 기억한다(`Inventory.seen`, 없어져도 남음, 저장 없음). 기본값을 켬으로 둔 이유: 문서가 내놓은 유일한 규칙이고, 슬라이스에서는 입력이 야생 약초라 줍기가 고리의 첫걸음이어서 비용이 없다(사람이 해 보고 정하게). 끄면 모든 레시피가 처음부터 보인다

### 조제대 (`WorldItems.place`, `world/fixture_view.gd`)

- ○ game-concept §9.7 "조제는 연금술대 자리의 조제대에서 한다". 그림은 04-env `alchemy_table_v05.png`(4단계 1차 시험의 정렬형 c를 다듬고 44색 → 24색, 채택 후보)를 그대로 복사. 자리는 3×1(`ALCHEMY_FOOTPRINT`): 48×32 그림의 불투명 줄 3~27 중 다리·앞 판이 자리 칸에, 뒤 판과 병이 그 위 칸에 걸친다(이단의 제단·던전 입구처럼 그림이 자리보다 높다). 노드는 자리 아래 변(y 정렬), 월드 빛 레이어
- **막는다**(다른 설치물처럼, `WorldData.placeable_blocks`): 걷기·대시·화살·던진 병·시야가 지나지 못한다
- **얻는 길 (임시값 "M6a 조제대 얻기")**: 문서에 없다. 디버그 아이템 `alchemy_table`(종류 "놓는 것", 아이콘은 코드로 그린 작은 탁자)을 `--give=alchemy_table`로 받아 횃불처럼 좌클릭으로 놓는다. 고른 길과 이유: 생성기에 넣지 않았다(지상 해시·세션 시험의 봇 길·렌더 검사·스폰 자리 둘레가 모두 흔들리고, 놓을 자리를 정하는 것 자체가 설계라서). F5 묶음에도 넣지 않았다(핫바 8칸이 도구 6·횃불·시작 무기로 차서 가방 칸에 들어가면 놓을 수 없다). 다른 길: 제단 둘레에 하나를 생성(지상 해시 갱신), 상인(M8), 작업대에서 만들기(M7)
- **놓기 규칙** (`WorldItems.place` + `place_rect`): 목표 칸이 자리 아래 줄의 가운데다(그래서 보통 위·아래를 조준). 자리 세 칸이 모두 맵 안의 빈 바닥(벽·앞면·설치물·채집물·드롭 없음), 놓는 사람의 발 상자와 다른 몸(같은 지도의 다른 플레이어·이단의 발)이 자리에 겹치지 않음(`someone stands there`), 다른 조제대에 한 칸도 닿지 않음(`too close to another`: 붙으면 `WorldData.footprint_at`이 둘을 한 자리로 읽는다). 편집은 칸마다 하나(세 개)라 스냅샷·해시·편집 기록을 그대로 지난다. 횃불 규칙은 그대로
- **M6-fix: 사람이 나타나는 자리는 비워 둔다** (임시값 "M6-fix 조제대가 비워 두는 자리"): 사람이 걷지 않고 나타나는 발 자리(`WorldItems.reserved_feet`: 그 지도의 도착점 = 지상 입구·던전 출구 계단 바로 아래, 제단이 있는 지도면 `SPAWN_SLOTS` 아홉 자리 = 참가·부활)의 발 상자를 덮으면 `where players appear`. 전에는 그 순간 서 있는 몸만 봐서, 시드 1 던전의 도착 칸(38,15)·지상 도착 칸(73,48)·아홉 자리 모두에 탁자가 놓였고 거기 도착하거나 부활한 사람은 막는 탁자 속에 서서 몇 쪽으로만 걸어 나갈 수 있었다. **놓은 조제대는 다시 줍거나 부술 수 없다**(지우는 규칙이 없다: 채굴은 보지 않고 F는 아무것도 안 함)

### 물약 셋 (`ItemDB`, `items/potions.gd`)

- `potion_healing`·`potion_buff`·`potion_poison`: 새 종류 `POTION`, 등급 있음(일반·상급), 묶음 `STACK_POTION`(10). 아이콘은 04-env 작은 것 묶음 `items_v04_strip.png`(16칸 18개, 파일을 그대로 복사)의 4·5·6번째 칸(빨강·호박·독 노랑 + 녹 마개)을 잘라 쓴다(`ItemDB.STRIP_POTIONS`, 시험이 픽셀까지 비교). 표 끝에 더해서 아이템 번호(전송 형식)는 그대로다(아이템 30개)
- 레시피 여섯 = 물약 셋 × 등급 둘: 야생 약초(`wild_healing`·`wild_buff`·`wild_poison`, M2b 채집물) `POTION_HERBS`(2)개 → 물약 하나, **등급은 입력을 따른다**(일반 약초 → 일반 물약, 상급 → 상급. 섞이지 않음: 레시피의 입력 등급이 정확함). 만들 수 있는 클래스: 상급 셋과 독 둘은 약초사만(●), 일반 회복·버프는 누구나(`COMMON_POTIONS_ANYONE`, 임시값: §3.0 표의 "공용 수행" 칸은 동사가 아니라 등급을 막는다고 읽음). 다른 클래스는 상급 약초를 캘 수 없지만(M2b) 받거나 주울 수는 있어서 클래스 검사가 따로 있다

### 마시기 (`Player.make_frame`, `Main.potion_impact`)

- 핫바에서 물약을 고르고 **좌클릭**(누르고 있어도 한 번) = 마시기. 마시는 그림이 없어서(03-pixel에 없다) **마법 동작을 빌려 쓴다**(`DRINK_ANIM`, brief §5.6 표의 "성직자 기도·치료" 동작, 0.6초). 물약은 4번째 프레임(`DRINK_EFFECT_FRAME`, 18틱째)에 쓰인다: 그 전에 맞아 동작이 끊기면 아무것도 쓰지 않는다. 쓰이는 순간 한 번 더 검사한다(그 사이 HP가 가득 찼으면 거부, 쓰지 않음)
- 효과(값은 등급별): 회복 `POTION_HEAL_HP` 30 / 50(최대를 넘지 않음), 버프 = 걷기 속도 `BUFF_SPEED_PCT` 125% / 140%를 `BUFF_TICKS` 20초 / 30초, 독 물약 = 마신 사람이 중독(`DRINK_POISON_HARMS` 켬: M6a에서 플레이어가 독에 걸리는 유일한 길, 아군 사격이 꺼져 있으므로). 거부: HP가 가득일 때의 회복(`DRINK_AT_FULL_HP` 끔, 쓰지 않음), 다운·사망 중(동작이 시작되지 않음). 콘솔 `EVENSONG_POTION drink ...` / `drink refused: full hp`

### 약제 투척 (○ gameplay-design §2.2 약초사의 정체성 스킬, `Arena.throw_potion`)

- **1**(임시값 "M6a 키": §1 키 초안에서 1 2 3이 스킬이고 §2.2 추천의 1번 칸이 정체성 스킬이라. 우클릭은 §1이 클래스 보조 동작에 준 키라 쓰지 않았다) = 고른 물약을 마우스 쪽으로 던진다. 약초사만(`THROW_HERBALIST_ONLY`, 임시값: §3.0이 약제를 약초사에게 두고 §2.2가 투척을 약초사의 정체성 스킬로 둠. 다른 클래스는 `herbalist only` 로그). 던지기 동작(03-pixel `base_body_v02_throw`, 7프레임 0.7초)으로 마우스 쪽을 보고, 4번째 프레임(`THROW_RELEASE_FRAME`)에 병이 손을 떠난다(그 순간 물약 하나를 쓴다. 그 전에 맞으면 아무것도 안 던짐)
- 병: 몸 점에서 마우스 점(커서가 떨어지는 자리)을 향해 땅 위로 `THROW_SPEED`(192px/s), 최대 `THROW_RANGE_PX`(96px = 6칸, 더 멀면 그 방향의 96px). **몸 위로 넘어가고**(던져 올림: 사이의 이단·플레이어에 멈추지 않음) **벽에 막힌다**(화살과 같은 칸 검사: 벽·앞면·막는 설치물·맵 밖, 두 걸음 사이의 칸도 모두. 막히면 그 앞에서 터진다). 그림은 그 물약의 아이콘을 화살 높이(12px) + 포물선(가운데에서 10px 더, `THROW_ARC_PX`)에 그린다(임시 그림. M6-fix: unshaded라 저녁·던전 어둠에서도 제 색으로 보인다. M6b까지는 화살처럼 shaded라 빛 없는 던전에서 날아가는 병이 배우들만큼 어두워 1배 화면에서 거의 안 보였다)
- **터짐**: 떨어진(또는 막힌) 점에서 `THROW_SPLASH_RADIUS_PX`(24px = 1.5칸) 안, 몸 점까지 벽 없이 닿는 모두에게: **회복·버프는 서 있는 플레이어**(던진 사람 자신도, 다운된 사람은 아님: 소생은 F), **독은 살아 있는 이단**(플레이어는 아군 사격이 꺼져 있어 안 걸림. `FRIENDLY_FIRE`를 켜면 플레이어도). 터짐 그림은 그 색 방울(독은 녹 반점)이 반경까지 퍼지는 코드 그림 3프레임(18틱, unshaded). 콘솔 `EVENSONG_POTION throw ...`, `splash ... players=n heretics=n`

### 효과 둘 (`Vitals`, `PlayerSim._tick_effects`, `Arena._tick_poison`)

- **버프 하나 = 걷기 속도**(임시값: 고른 이유는 혼자서도 바로 보이고, 공유 시뮬레이션의 한 곳(`PlayerSim.walk_speed`)이라 혼자·호스트·예측이 같다. 대시는 그대로). **상태이상 하나 = 독**(○ §2.4 약초사 상태이상 넷 중 첫째): `POISON_INTERVAL_TICKS`(30틱)마다 `POISON_DAMAGE` 2 / 3, `POISON_TICKS` 5초(10번). 첫 피해는 한 간격 뒤. 독 피해는 HP만 깎는다: 경직·무적이 없고 무적(대시·피격 뒤)에 막히지 않고 방어가 없고, 하던 동작(플레이어)·공격(이단)을 끊지 않는다(맞은 깜빡임은 있음)
- 이미 걸린 사람에게 또: 남은 시간은 긴 쪽, 세기는 큰 쪽(`EFFECT_REFRESH_KEEPS_STRONGER`, 겹치지 않음). 독은 박자를 이어 간다
- **플레이어**: `Vitals`에 버프(퍼센트·남은 틱)와 독(피해·남은 틱·다음 피해까지)을 더하고 `PlayerSim.step`이 서 있는 플레이어의 효과를 맨 먼저 센다. 그래서 혼자(`Player.step_frame`)·호스트(`SessionHost.run_frame`)·예측(`Prediction.step_frame`)이 같다(시험: 2,400틱 무작위 걷기·대시·물약 셋·피해·소생에 매 틱 `same_all`). 독으로 0이 되면 다운(그 뒤는 M4 흐름: 30초 뒤 사망. 혼자면 일으킬 사람이 없어 사망·가방까지 간다: 임시값 "M6-fix 플레이어의 독"). **다운·사망하면 효과가 끝나고**(`EFFECTS_END_ON_DOWN`) 부활에도 없다. 끝난 독은 필드를 남기지 않는다(M6-fix: 스위치를 끄면 마지막 독 틱에 다운된 사람의 피해·박자가 남아 소생 뒤에도 `has_effects()`가 늘 참이었다). **지도를 옮겨도 효과는 이어진다**(`Player.set_world`는 vitals를 그대로 둔다. M6-fix에 적음). 독 피해는 `hurt` 시그널(로그·HUD)로도 알린다
- **이단**: `HereticSim`에 독(피해·남은 틱·다음까지·던진 사람)을 더하고 `Arena`가 살아 있는 이단의 독을 맨 먼저 센다. 독으로 죽으면 **다른 처치처럼 센다**(`killed` + `poison_kills`, 기록 켬이면 던진 사람의 `Hit`(KILLED): 호스트가 그 사람의 처치로 센다 = M6b). 죽은 이단의 독은 끝난다(M6-fix: 무기로 죽어도. 전에는 독으로 죽을 때만 지워져 무기로 죽인 시체가 `poisoned()`였다. 이제 `HereticSim.poisoned()`는 살아 있을 때만). 사람이 떠난 지도를 비울 때(M4-fix) 날던 병과 터짐은 없애고 이단의 독은 남긴다(그 지도가 다시 돌 때 이어 셈). M6-fix에 적음(임시값 "M6-fix 빈 지도의 병과 독"): 날던 병의 물약은 손을 떠날 때 이미 쓰였으니 터짐 없이 사라진다. 멈춘 독은 다시 돌 때 남은 만큼 다 들어가고 그 처치는 처음 던진 사람의 것이다(그 사람이 떠났어도, 세션에서 나갔으면 자리 −1)
- **표시** (코드 그림 임시, `actors/effect_marks.gd`): 머리 위(발에서 44px 위, 성직자 후광·이단 HP 막대 위) 7×7 표시: 버프 = 호박색 위 화살, 독 = 독초 노랑 방울 + 녹 점(unshaded). HUD에서는 HP·스태미나 막대 밑에 같은 표시와 남은 시간 1px 막대

### 제작 창 (`ui/crafting_panel.gd`)

- 코드로 그린 60px 너비 창, 화면 오른쪽 위(480×270에서 여섯 줄이면 높이 142px). 맨 위에 조제대 아이콘과 금빛 밑줄, 줄마다 입력 칸(아이콘·수·상급 점) → 화살표 → 출력 칸, 약초사 전용 줄에 3×5 주머니 표시(금빛 = 이 클래스가 만들 수 있음, 녹빛 = 아님), 지금 만들 수 없는 줄(입력 부족·클래스·자리)은 어둡게, 고른 줄에 금빛 테. 글꼴 없음(HUD의 3×5 숫자). 인벤토리가 바뀌면 다시 읽는다(해금·어두운 줄)
- 열려 있는 동안 캐릭터는 서 있다(`Player.ui_locked`: 걷기·대시·사용·F·1 없음, Q/E는 됨). 마우스: 줄 위에 올리면 고르고 좌클릭 = 만들기, 창 밖 클릭은 아무것도 안 함

### 시험 (M6a)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=crafting,potions < /dev/null   # 약 2초
```

- `test_crafting.gd`: 레시피 여섯(작업대, 입력 약초·수·등급, 출력 등급 = 입력 등급, 클래스 다섯마다 만들 수 있는지: 상급·독은 약초사만), 만들기(약초 둘 → 물약 하나, 뒤 칸부터 뺌, 출력은 핫바 첫 빈 칸, 입력 부족 = 아무것도 안 바뀜, 등급이 다른 약초는 안 됨, 상급 약초를 든 성직자도 `herbalist only`, 독은 팔라딘이 못 만듦, 일반 버프는 아처도, 묶음 10), 자리 없음(가득 찬 인벤토리에서 거부·아무것도 안 바뀜, 입력이 빠진 칸에 출력이 들어가는 경우는 됨, 자리 있는 물약 묶음), 해금(빈 인벤토리 0줄 → 버프 약초 하나로 버프 둘, 없어져도 남음, 잠긴 레시피 거부, 여섯 줄 순서), 작업대 손 닿음(17×13칸 전부 2칸 안/밖, 둘 중 가까운 것, 멀어짐·없어짐), 조제대 놓기(자리 = 아래 줄 가운데, 놓는 사람 발·남의 발·손 닿지 않음·맵 밖·벽·채집물·드롭·조제대 위 거부, 붙음·대각선 붙음 거부, 한 칸 띄우면 됨, 횃불은 그대로), 막음(세 칸이 걷기·화살을 막고 뒤 칸은 안 막음, 남쪽으로 걸으면 딱 붙어 섬, 화살이 멈춤), 그림(제단 남쪽에 놓으면 FixtureView 노드가 자리 아래 변에, 그림 가운데 맞춤, 불투명 맨 아래 줄이 자리의 마지막 픽셀 줄, `verify` 0), `main.tscn`(Tab = 인벤토리, 좌클릭으로 조제대 놓기, 그 옆 Tab = 제작 창 + 서 있음, 약초를 얻으면 넷 해금, 열린 동안 걷기·대시·사용 없음, S·W·F로 만들기, 독은 팔라딘이 못 만듦, 클릭으로 만들기, 창 밖 클릭 없음, Tab으로 닫힘, 멀어지면 닫힘, 다운되면 닫힘), 세션(호스트가 조제대를 `alchemy table offline only`, 물약 USE를 `not a tool`로 거부)
- `test_potions.gd`: 마시기 규칙(가득 찬 HP 거부, 다운 거부, 등급별 회복·최대 넘지 않음·다운된 사람 안 됨, 버프 퍼센트·시간이 정확히 `BUFF_TICKS`, 더 센 쪽 유지, 독 물약), 마시기 조작(가득 찬 HP 클릭 = 프레임 없음 + 거부 로그, 클릭 = 마법 동작, 칸·등급 기억, 누르고 있어도 한 번, 효과 프레임 한 번, 세션처럼 꺼짐, 다운 중 없음, 물약 꺼내기), 버프 속도(2초에 144px → 125%, 대시는 그대로), 플레이어 독(30틱마다 열 번, 걸으며, 경직·무적 없음, 무적 통과, 휘두르기 안 끊김, 두 번째 독 틱에 다운 + 효과 끝 → 30초 뒤 사망, 맞아서 다운돼도 끝, 다운 중 안 걸림, 부활에 없음, `hurt` 시그널), 이단 독(열 번, 경직 없음, 무기 맞음으로 안 셈, `Hit` 기록·던진 사람, 독 죽음 = 처치·독 처치·던진 사람의 KILLED, 공격 안 끊김, 더 센 쪽), 병(사거리 자르기, 날아가는 틱 = 거리 / 속도, 벽 바로 앞에서 터짐·벽 뒤 이단 안 걸림, 가까운 이단 위로 넘어가 먼 이단에), 터짐(반경 안·밖, 던진 사람, 다운된 사람, 버프, 독은 이단만·벽 뒤 안 됨·플레이어 안 됨, 18틱 보임), 던지기 조작(약초사 1 = 던지기 동작·목표 자르기·마우스 쪽, 팔라딘 거부, 검은 못 던짐), 표시(머리 위 둘·자리·unshaded, 다운되면 사라짐, 이단 독 표시, HUD 남은 시간 막대), 공유 시뮬레이션 2,400틱(혼자 = 호스트 = 예측, 효과 포함), `main.tscn`(가득 찬 HP 거부·쓰지 않음, 효과 프레임 전에는 안 쓰임·그 프레임에 하나, 맞아 끊기면 안 쓰임, 효과 프레임에 HP 가득이면 거부, 빛 안에서 빛 밖 이단에게 1로 상급 독 → 독 표시·터짐 그림 → 독으로 죽음 = 처치 + 독 처치, 버프 마시기 → 머리 위·HUD)
- 바꾼 기존 시험: `test_items.gd` 아이템 수·종류별 수(놓는 것 2, 물약 3)와 물약 아이콘 = 띠의 칸(픽셀), `test_actors.gd` 그림 출처에 새 파일 둘. 스모크 M6a 항목, 창 그림 검사 `crafting`·`potions`
- M6-fix에 더한 것: `test_crafting.gd` 나타나는 자리(시드 1 지상의 도착점과 부활 자리 아홉, 던전의 도착점: 자리마다 그 발 상자를 덮는 모든 자리를 옆 칸의 놓는 사람이 놓아 봄 → `where players appear`가 있고 놓인 것 0, 도착점 두 칸 남쪽은 놓임), 작업대 찾기(5칸 자리의 동쪽 끝 2칸 = 있음·3칸 = 없음, 종류로 찾기, 둘이 같이 가까우면 줄 순서로 앞의 것, 창을 연 작업대에 그대로, 다른 지도). `test_potions.gd` 던질 점 = 자른 점의 정수 px, 효과 틱 전에 사라진 물약(`the potion is gone`, 회복 없음), 그 칸에 다른 등급이 있으면 같은 등급의 다른 묶음에서, 아레나 없는 던지기(`no arena`), 쓰러진 채 끝난 독은 필드를 남기지 않음, 마지막 독 틱에 다운 → 소생 = 효과 없음, 지도를 옮겨도 버프·독이 이어지고 계속 셈, 무기로 죽은 이단에 독 없음, 비운 지도의 날던 병은 터짐 없이 사라지고 이단의 독은 기다림

## M6b: 세션의 제작 · 물약

M6a가 혼자 할 때 더한 것(제작 틀·조제대·물약 셋·마시기·약제 투척·효과 둘)을 세션으로 가져왔다. ● 호스트 권한(game-concept §13)대로 **M6가 더한 것은 모두 호스트가 정한다**: 제작(작업대·레시피·클래스·등급·입력·자리), 조제대 놓기, 마시기와 던지기의 시작·효과, 병의 비행·터짐, 버프·독. 클라이언트는 마시기·던지기 **동작**만 M2b·M4b처럼 예측하고 효과는 예측하지 않는다(호스트의 상태·인벤토리·사건이 온다). 새 임시값은 [임시값](#임시값-사람-확인-필요) 표의 "M6b" 줄 하나(던진 회복이 다운된 사람을 일으키는가)이고, 그 밖은 [구현에서 고른 값](#구현에서-고른-값-설계-결정-아님)의 "M6b" 줄이다. M6a의 범위 밖(농사·작업대 셋·건설·상인·다른 스킬·클래스 자원·효과 둘 밖·새 적)은 그대로 없다.

### 요청 (`NetProtocol.Op`, `SessionHost.run_frame`)

- **마시기 = 물약이 든 칸의 USE**(M2b의 사용 그대로, 새 요청 없음). 호스트가 그 칸에서 정한다: 물약이면 `_drink`(손 닿는 칸 = 목표 칸이 발 옆, 바쁘지 않음(`busy`: 동작·대시·경직 중), `Potions.drink_refusal`을 **호스트의 vitals로**: 가득 찬 HP의 회복은 `full hp`), 아니면 도구(M2b), 놓는 것(M3a)
- **던지기 = 새 요청 THROW**(스킬 키 1): 지도 u8, 핫바 칸 u8, 목표 칸 s16×2(바라보기만 정함), 조준 u8, **던진 점** s16×2(월드 px, 정수) = 11B. 떨어질 점은 마우스라 호스트가 정할 수 없어서 싣는다(README "규칙"의 "보내지 않는 값" 원칙: 호스트가 정할 수 있는 것은 보내지 않음). 호스트 검사(`_throw`): 그 칸에 물약, 약초사(`Potions.throw_refusal`, 임시값 `THROW_HERBALIST_ONLY` 그대로), 손 닿는 칸, 바쁘지 않음. M6-fix: 혼자 할 때도 `Player.make_frame`이 던진 점을 정수 px로 만든다(전송 형식이 싣는 값): 그래서 마우스가 사거리 밖이어도 혼자 = 호스트(전에는 혼자는 float 점, 호스트는 반올림한 점을 다시 잘라 최대 0.7px 달랐다). **거리는 호스트가 자른다**: 손을 떠나는 틱에 `Arena.throw_potion`이 호스트가 가진 그 사람의 몸 점에서 `THROW_RANGE_PX`(96px)로 자른다(클라이언트가 400px 밖을 보내도 96px. 시험). M6a의 던지기 프레임은 USE였다(전송 형식에 떨어질 점이 없었다)
- **제작 = 새 요청 CRAFT**: 지도 u8, 레시피 번호 u8(`Crafting.recipes()`의 순서) = 2B. 줍기와 같은 요청 예산(`rate`). 호스트 검사(`_craft`): 있는 레시피(`no such recipe`, 디코더도 범위 밖 번호를 거부), **호스트가 가진 그 사람의 자리에서** 그 레시피의 작업대가 `STATION_REACH_TILES` 안(`no station`. M6-fix: `Crafting.station_of_kind_near`: 그 종류의 작업대 중 손 닿는 것, 다른 종류가 더 가까워도. M6b는 가장 가까운 작업대 하나만 봐서 M7에서 종류가 다른 작업대가 더 가까우면 거부할 뻔했다. 지금은 종류가 하나라 시험으로 만들 수 없다), 그다음 M6a의 `Crafting.craft`를 그 사람의 인벤토리에(해금 `locked`, 클래스 `herbalist only`(● §3.0), 그 등급의 입력 `missing inputs`, 자리 `no room`, 모두 아니면 하나도 아님). 결과는 그 사람에게만 인벤토리로(M2b). 등급은 레시피가 정한다(일반 약초 → 일반, 상급 → 상급): 클라이언트가 등급을 고를 길이 없다
- 셋 다 **지도를 싣는다**(M3b 규칙): 다른 지도면 `wrong map`, 다운·사망 중이면 `down`(M4b), 그다음 위 검사. 클라이언트가 보내는 요청 수는 M2b처럼 프레임 하나에 하나
- **조제대 놓기**: M6a의 세션 거부(`alchemy table offline only`)를 없앴다. 횃불처럼 USE → `WorldItems.place`, 그 지도의 몸(다른 플레이어·이단의 발, 혼자 할 때와 같음)을 넘겨서 자리가 몸을 덮으면 `someone stands there`. 편집 셋이 그 지도의 번호 붙은 편집으로 그 지도의 사람에게(M3b), 늦게 오거나 그 지도에 들어오는 사람에게는 스냅샷으로(설치물 레이어). 조제대는 여전히 디버그 아이템이다(임시값 "M6a 조제대 얻기")
- 손을 떠나는 틱·효과 틱(`Potions.impact_tick`, 둘 다 18틱째)에 호스트가 **`Potions.release`**(혼자 할 때 `Main.potion_impact`가 부르는 것과 같은 규칙 하나)를 부른다: 마시기는 그때 다시 거부될 수 있고(그 사이 HP가 가득 참: 쓰지 않음), 물약 하나를 쓰고 효과를 준다. 던지기는 하나를 쓰고 병을 그 지도의 아레나에 놓는다. 주인에게 인벤토리. 로그 `drink slot= map= item= grade= hp= buff= poison=`, `throw slot= map= item= grade= id= from= to=`, `splash map= id= item= at= why= players= heretics=`, `craft slot= map= recipe= item= count= grade= station=`, 거부는 `request_refused ... throw|craft ...: <이유>`·`potion_refused`. M6-fix: 사용·마시기·던지기는 그 프레임에서 동작이 시작될 때만 한 것(`ops_done`)으로 센다(같은 프레임에 Space를 누르면 대시가 이겨 아무것도 안 던지고 물약도 안 쓰는데 `throw`로 셌다). 이단의 독 틱은 던진 사람의 `poison_hits`로 세고 로그 `hit ... hp=<n> POISON[ KILLED]`(M6-fix: 전에는 무기 맞음 `hits`와 섞였다. 처치는 그대로 `kills`)

### 효과의 전송 (`NetProtocol` 효과 블록, 적 묶음의 독 표시)

- **플레이어**: vitals 블록(M4b, 16B) 뒤에 **효과 블록 7B**(버프 % u8, 버프 남은 틱 u16, 독 피해 u8, 독 남은 틱 u16, 다음 독까지 u8). **버프나 독이 도는 동안에만** 붙는다: 표시는 vitals 블록의 삶 바이트 7번 비트(상태의 flags 바이트는 이미 다 씀). 그래서 상태는 쉬면 17B(M3b 그대로), 다쳤으면 33B(M4b 그대로), 효과가 있으면 40B. 받는 쪽은 효과 필드마다 그 Config 상한(가장 센 등급)을 넘으면 거부하고, 표시가 있는데 효과가 하나도 없는 블록(보내지 않는 것)도 거부한다. welcome·들어옴·지도 들어옴의 정보도 같다(정보 18 / 34 / 41B)
- **효과는 타이머다**(`Vitals.idle`에 들어감): 버프·독이 도는 동안 클라이언트는 서 있어도 매 틱 프레임을 기록하고(M4b의 vitals 타이머와 같음), 호스트는 그 프레임으로 그 사람의 효과를 센다(M4-fix의 시계 빚: 앞서지 못함, 30틱 넘게 늦으면 호스트가 직접 진행). 그래서 버프·독도 호스트 시간으로 흐르고, 조용한 클라이언트가 독을 버티지 못한다. 대가는 트래픽이다(아래 "측정", 알려진 문제)
- **이단**: 적 묶음의 이단마다 flags 6번 비트 = 독(0B 더함). 독의 남은 시간·세기는 호스트만 알고(HP는 이미 묶음에), 클라이언트는 머리 위 독 표시만 그린다(`NetCombat.sample_foe`). 표시가 바뀌는 때(걸림·끝남·죽음)와 독이 HP를 깎는 때(30틱마다, 맞은 깜빡임)에 묶음이 나간다. 죽은 이단에 독 표시가 있는 묶음은 거부
- 늦은 참가·지도 들어옴: 플레이어의 효과는 welcome / 지도 들어옴의 상태에, 이단의 독은 그 뒤 적 키프레임에 있다. 클라이언트 로그 `welcome_effects {"<자리>": "<vitals>"}`(결과 JSON `effects_on_welcome`)

### 던진 병 (정한 것: 호스트 사건 + 클라이언트 비행, M4b의 화살과 같은 길)

- 호스트의 아레나가 병을 날리고 터뜨린다(M6a 그대로). `logging`이면 손을 떠난 틱에 **"던짐" 사건**(번호, 물약, 던진 사람 자리, 틱, 손을 떠난 점·떨어질 점 f32×2 = 27B), 터진 틱에 **"터짐" 사건**(번호, 물약, 틱, 터진 점 f32×2, 이유 `landed`/`wall` = 19B)을 화살 사건과 같은 reliable 메시지(`_rpc_shots`, 새 RPC 없음)로 그 지도의 사람에게 보낸다
- 클라이언트(`NetCombat.FlaskTrack`)는 던짐 사건에서 **호스트와 같은 걸음 함수**(`Arena.flask_points`: 호스트의 `_step_flask`가 벽을 보는 것만 빼고 같은 float 연산)로 틱마다의 점을 미리 계산해 두고 그 사이를 그리며, 터짐 사건의 틱부터 그 점에 터짐(`SPLASH_SHOW_TICKS` 18틱)을 그린다. 그래서 그리는 병은 틱마다 호스트의 점 그대로다(시험: 호스트가 날린 모든 틱에 클라이언트 트랙의 점 = 호스트의 점, 창 그림 검사 `potions_net`: 픽셀까지 같음). 그리는 시각은 화살과 같다: **자기 병은 아는 가장 새 시각, 남의 병은 100ms 뒤**(임시값 "M4b 적 그리기"의 화살 규칙 그대로)
- 고른 이유(위치 복제 대신): 화살과 같다(M4b "화살·빛 탄"): 병 하나 = 사건 둘 46B(+ 머리 2B), 날아가는 0.5초 동안 20Hz 위치 복제는 그보다 크고 적 묶음을 매번 바꾼다. 같은 함수라 60Hz로 매끄럽고 터진 점이 호스트 것 그대로다. 터짐은 잃으면 안 보이므로 reliable
- 늦은 참가·지도 들어옴: 적 키프레임 뒤에 **날고 있는 병은 던짐 사건으로, 보이는 터짐은 터짐 사건으로** 보낸다(`send_combat_snapshot`). 던짐 없이 터짐만 받으면 터짐만 그린다
- 클라이언트는 자기 병을 예측하지 않는다: 던지는 동작은 바로, 병은 호스트의 던짐 사건이 와야(왕복 뒤) 손에서 나타난다(화살과 같은 알려진 문제)

### 예측 (`Prediction`, M6b)

- 마시기(USE + 물약)·던지기(THROW)는 `Player.make_frame`이 혼자 할 때처럼 만들고(세션의 자기 플레이어도 `potions_on`), 예측이 그 동작을 바로 시작한다. 호스트가 거부하면(그 사이 맞음, 가득 찬 HP 등) 다음 상태에서 동작 보정이 된다
- 효과는 예측하지 않는다: 회복·버프·독이 **걸리는 것**(마시기의 효과 틱, 터짐, 더 길거나 센 것으로 바뀜)은 호스트 사건이다(`Prediction.effect_event`: 맞음·소생처럼 `event_corrections`로 세고 오차·vitals 보정에 넣지 않음). 걸린 효과가 **줄어드는 것**(버프 시간, 독의 박자와 피해)은 공유 시뮬레이션이라 예측이 호스트와 같이 센다: 호스트보다 오래 남은 효과는 예측의 잘못(`vitals_corrections`)이다. 버프 걸음 속도도 예측한다(시험: 버프가 걸린 클라이언트가 1초 걸은 거리 = 140%, 호스트 위치 그대로)
- **호스트가 직접 진행한 상태** (M6-fix에 적음, 알려진 문제): 효과가 타이머라 버프·독이 도는 클라이언트가 `NET_HOST_STEPS_AFTER_TICKS`(30틱) 넘게 조용하면(또는 서 있는 클라이언트에 한 방향 약 16틱(267ms) 넘게 늦게 버프 병이 터지면) 호스트가 직접 진행한다(M4-fix 시계). 예측은 그 상태를 가려내지 못해(`effect_event`는 걸림·더 셈만 사건으로 봄) 그동안의 상태를 `vitals_corrections`로 센다. 상태는 맞춰지고 어긋나지 않는다. M4b의 대시·경직도 같은 셈이지만 그 창은 1초 안팎이고, 버프는 20~30초라 싸움 없이도 생긴다(검토의 탐침: 지연 2틱에 60틱 조용 → `host_steps` 38·보정 14, M4 대시 기준 31·11. 서 있는 클라이언트에 한 방향 12·14·16틱으로 버프 → 보정 0·0·3). 그래서 `vitals_corrections` 0과 `host_steps`·`vitals_correction` 로그는 정상 연결(한 방향 약 200ms까지)에서만 깨끗한 신호다. 고치는 길(호스트가 자기가 진행한 상태에 표시를 달고 예측이 그것을 사건으로 셈)은 전송 형식을 바꿔서 하지 않았다
- 제작·놓기는 예측하지 않는다(줍기처럼): 인벤토리는 호스트의 답이 와야 바뀐다. 클라이언트의 제작 창은 그 인벤토리로 다시 읽힌다
- **해금 기억**: 클라이언트는 호스트가 보낸 인벤토리에 든 아이템을 본 것으로 적는다(`SessionClient.take_inventory` → `Inventory.seen`). 호스트의 `seen`이 기준이고(제작 검사), 클라이언트의 것은 창에 보일 줄만 정한다. 한 틱 안에 들어왔다 나간 아이템은 클라이언트가 못 본다(알려진 문제: 그때 클라이언트 창에 줄이 덜 보일 뿐, 더 보이지는 않음)

### 제작 창 (세션)

- 혼자 할 때와 같은 키(임시값 "M6a 키"). Tab은 자기가 가진 그 지도의 데이터에서 작업대를 찾는다(조제대는 스냅샷·편집으로 와 있다). 줄을 만들면 `EVENSONG_CRAFT request recipe=...`과 CRAFT 요청(다음 빈 프레임, M2b의 키 요청 줄)
- 열린 동안 캐릭터는 서 있다: 세션의 입력(`SessionBots.local_action`)이 `ui_locked`이면 걷기·사용·대시·F·1을 지운다. 봇의 `tab`·`craft`는 `NetSession.bot_ui` 시그널로 Main에 간다(프레임을 만들기 전)
- 멀어지거나 다운되거나 지도를 옮기면 닫힌다(`Main._check_crafting`, 세션에서도 매 틱)

### 전송 형식 버전 6 (`NetProtocol.VERSION`)

새 요청 THROW(11B)·CRAFT(2B), vitals 블록의 효과 블록(삶 바이트 7번 비트 + 7B), 적 묶음 flags 6번 비트(독), 화살 사건 메시지의 새 종류 2 "던짐"(27B)·3 "터짐"(19B). 입력 프레임은 1바이트 그대로(코드 0..179), RPC 표 그대로(18개). 버전 5 클라이언트는 `version`으로 거부된다.

### 시험 (M6b)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_potions < /dev/null   # 한 프로세스 (약 5초)
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_brew < /dev/null      # 실제 세션 brew·brew4 (약 55초)
```

- `test_net_potions.gd` (한 프로세스, `test_net_combat.gd`의 리그를 이어 씀: 진짜 `SessionHost`·`SessionClient`, 메시지를 잡아 순서대로, 필요하면 한 방향 지연): 전송 형식(THROW·CRAFT 왕복과 정수 px, 범위 밖 슬롯·지도·레시피, 모든 자른 길이; 효과 블록 17/33/40B, 필드 여섯의 상한, 빈 효과 블록, 정보 41B·지도 들어옴; 독 표시 왕복, 독 걸린 시체 거부; 던짐·터짐 왕복, 물약 아닌 것, 사거리 밖, NaN, 이유, 모든 자른 길이). 악의 클라이언트(`run_frame`에 바로): 제작 — 6칸 밖 `no station`, 팔라딘의 독·상급 `herbalist only`, 한 번도 얻지 않은 약초 `locked`, 던전을 적은 요청 `wrong map`, 레시피 200 `no such recipe`, 한 틱에 열 번(넷은 예산, 여섯은 `rate`, 하나 만들고 셋은 `missing inputs`), 다운 중 `down`, 가득 찬 인벤토리 `no room`(약초 그대로), 호스트가 놓은 조제대가 다른 사람 발 위면 거부·옆이면 편집 셋. 던지기 — 400px 밖을 보내도 호스트가 96px로 자름, 40프레임 연속 THROW는 하나만(나머지 39 `busy`, 물약 하나), 4칸 밖 목표 칸 `out of reach`, 낫 `not a potion`, 던전을 적음 `wrong map`, 팔라딘 `herbalist only`, 다운 중 `down`, 던전 벽 너머의 이단에게 던지면 벽 앞에서 터지고(`wall`) 이단은 안 걸림. 마시기 — 가득 찬 HP `full hp`(안 씀), 매 프레임 USE는 마시기 하나(+30, 하나 씀, 나머지 `busy`), 다운 중 `down`. 흐름 — 빛 안의 약초사 클라이언트가 빛 밖 이단에게 상급 독 둘(30 + 30 > 40): 독으로 죽고, 호스트가 그 클라이언트의 처치로 셈, 클라이언트 트랙의 병이 호스트가 날린 모든 틱에 호스트 점 그대로, 병·터짐을 그림, 독 표시(머리 위)를 그림, HP 순서가 호스트를 따라 0까지. 호스트 약초사 → 다친 팔라딘 클라이언트에 상급 회복(40 → 90, 호스트 사건), 버프(예측이 호스트 버프를 가짐, 1초 걸음 = 140%, 다른 클라이언트도 버프와 머리 위 표시를 봄), 다운된 팔라딘에 회복: 다운 그대로(`THROW_HEAL_REVIVES` 끔). 호스트가 놓은 조제대(참가 전): 참가자의 스냅샷에 있고 그려짐, 클라이언트가 받은 인벤토리로 해금(두 줄), 클라이언트의 CRAFT(전송 형식으로)가 상급 회복을 만듦, 9칸 밖 클라이언트는 `no station`. 늦은 참가: 버프된 플레이어(welcome)와 머리 위 표시, 독 걸린 이단(키프레임)과 표시, 날고 있는 병(던짐 사건)과 그 터짐, 적 그림 = 호스트. 던전에 놓은 조제대가 지도 들어옴에 있고 그려짐. 넷(3틱 지연): 약초사 둘이 버프와 독, 둘이 싸움, 두 이단이 죽고 모두 HP 순서·마지막 적 그림·위치·vitals와 효과가 호스트와 같음, 예측은 호스트 사건만. 공유 시뮬레이션 1,500틱: 혼자 = 호스트(전송 형식을 지난 마시기·던지기 프레임, 호스트의 `Potions.release`) 매 틱 `same_all`과 병 위치, 예측(6틱 늦은 상태로 맞춤)은 걸음·바라보기·동작·타이머 보정 0이고 사건만. 세션의 입력: 창이 열리면 봇의 걸음·F·1이 지워지고 Tab·제작 줄은 Main으로
- `test_net_brew.gd` (실제 세션, `test_net_session.gd`의 도구): `brew` — 호스트(약초사)가 조제대를 클릭으로 놓고, c1(약초사)이 걸어가 Tab·제작 줄 둘로 상급 독 둘을 만들고(CRAFT 둘, 거부 0), 빛 가장자리에 서면 호스트가 상급 회복(c1 40 → 90)과 버프를 던지고, c1이 빛 밖 이단에게 독을 던짐, 그동안 c2(성직자)가 늦게 참가(welcome에 c1 버프, 독 걸린 이단을 봄), c1의 두 번째 독이 이단을 죽임: 마지막 한 방이 독 3, c1의 처치. 모두: 세션 공통 검사, 적 그림 = 호스트, HP 순서, vitals 보정 0, c1의 병 사건 8개·호스트 사건 2개 이상. `brew4` — 호스트·c1(약초사 둘)이 빛 가장자리에서 독을 던지고 c2(아처)·c3(팔라딘)이 싸움: 두 이단이 죽고, 둘 다 던졌고, 독이 맞았고, 모두 같은 것을 봄
- 바꾼 기존 시험(M6b가 규칙을 일부러 바꿔서): `test_net.gd` 적 묶음의 "모르는 flags 비트"가 6번(이제 독) 대신 7번, `test_net_maps.gd` 버전 6, `test_crafting.gd` 세션 시험이 "조제대 거부·물약 USE `not a tool`" 대신 "조제대를 놓음(편집 셋)·가득 찬 HP의 마시기 `full hp`·HP 40이면 마시기 시작", `test_potions.gd` 던지기 프레임이 USE 대신 THROW
- 창 그림 검사 `potions_net`, 스모크 M6b 항목
- M6-fix에 더한 것: `test_net_potions.gd` THROW + Space 한 프레임(대시, 던지기 `done` 그대로, 병·물약 그대로, 지금까지의 `done` = 던진 병 수), 독 처치 흐름에서 독 틱은 `poison_hits`이고 `hits` 0, 남의 버프 표시는 **리그 시간으로 그려** 다운으로 끝나면 사라짐·늦은 참가자도 버프가 다 되면 사라짐(1,100틱 더. 리그는 실제 시간보다 훨씬 빨라 클라이언트의 `RemoteClock`이 마지막 묶음 근처에 머물러, 모두 쉬면 옛 상태를 계속 그렸다: 그래서 M6b 시험의 "표시를 그림"은 끝나는지는 보지 못했다), 공유 시뮬레이션 1,500틱의 마우스를 131틱마다 번갈아 사거리 밖(±220px, 정수 아닌 점)으로: 사거리 밖 던지기 2번 이상에도 병 위치 0.01px까지 같음. `test_net_brew.gd` 마지막 한 방의 줄이 ` POISON KILLED`, 조제대 자리를 (62..64, 50)으로 옮김(전 자리 (64..66, 50)은 부활 자리 4의 발 위라 이제 거부)

## M5a: 밭 · 씨앗 · 물주기 · 자라기 · 수확 · 시듦

혼자 할 때 먼저(M5a 지시, M3a·M4a·M6a처럼). (M5c에서 바뀜: 세션에서도 호스트가 같은 규칙으로 돌린다, 아래 "M5c") **세션(`--host`/`--join`)에서는 농사가 꺼져 있고 M6b 흐름 그대로다**(M5c에서 켠다): 세션은 농장을 돌리지 않는다. 세션의 플레이어는 `Player.farming_on`이 꺼져 있어 씨앗 좌클릭이 프레임을 만들지 않고, 호스트는 씨앗 칸의 USE를 `farming offline only`로 거부하고(M3a의 "dungeon offline only"처럼), 괭이·물뿌리개는 M2b처럼 동작만 하고 아무것도 바꾸지 않고, 낫은 약초사의 무기 그대로(세션에는 작물이 없다), 야생 약초를 캐도 씨앗이 없다. 전송 형식은 v6 그대로(밭은 식생 레이어 값이라 M5c도 형식을 바꾸지 않아도 된다). 문서의 ●는 그대로 따랐다: 작물 셋(회복 약초·버프 약초·독초, ● game-concept §12 R28) = 물약 셋(M6)의 약초, 누가 무엇을 심나(● §12 R37: 회복·버프 약초는 누구나 일반 등급으로 심고 거둔다, 독초 씨앗은 약초사만), 시든 작물 = 병든 올리브 + 잿빛(● brief §5.7 R29, `crops_v03`의 시듦 칸), 물 준 흙은 칸별 덧칠(● R29, 둘째 흙 타일셋 없음), 약초사가 캔 야생 약초는 상급(● §3.4, M2b 그대로). ○·?와 문서에 없는 것은 모두 [임시값](#임시값-사람-확인-필요) 표의 "M5a" 줄이다. 정화·성수·제단 옮기기(M5b), 세션의 농사(M5c), 나무·도끼·작업대·건설(M7), 상인·상점(M8), 다른 스킬, 클래스 자원, 기도, 제단 업그레이드(M12), 오염 확산·재오염, 새 적, Steam, 저장은 M5a가 아니다.

### 밭 = 바닥 흙 + 식생 값 (`items/farming.gd`, `world/farm.gd`)

- 일군 칸 = 바닥 레이어의 흙(`Terrain.SOIL`). **M1 생성기의 흙 세 덩어리(빛 안)는 이미 일군 밭**이라 바로 심는다(시드 1: 19칸). 괭이질 = 바닥 편집 하나(M1 디버그 편집과 같은 "칸 = 값", 채굴처럼 그 지도의 편집): dual grid가 그 꼭짓점 둘레 그림 칸 넷을 다시 그린다
- 작물·젖음은 식생 레이어 값(`Farming.Field`): `Config.FIELD_BASE`(64) + 작물 × 40 + 단계 × 8 + 표지(시듦 4, 젖음 2, 약초사가 심음 1). 0 = 마른 빈 흙, 66 = 젖은 빈 흙. 채집물 값(1..15)과 겹치지 않아 `WorldItems.gatherable_for`가 빈 값을 주고, 식생 ≠ 0을 "무언가 자람"으로 읽는 규칙(횃불·조제대·가방 자리)은 작물과 젖은 칸을 같이 막는다. F는 작물을 줍지 않는다(그 칸의 드롭만). 그래서 스냅샷·월드 해시·편집 기록이 밭을 그대로 덮는다(시험: 스냅샷 왕복의 해시가 같음)
- **보이지 않는 시간**(그 단계에서 자란 틱, 남은 물 틱)은 지도마다의 `Farm`에 있다(월드가 아니다). `Farm`의 메서드는 데이터를 쓰지 않고 편집을 돌려주고, Main이 바로 `GameWorld.apply_edit`(데이터 + 그림)로 적용한다. 같은 월드로 새로 만든 `Farm`(받은 월드, 호스트를 잃은 클라이언트)은 그 단계의 처음부터, 젖은 칸은 물이 가득 찬 채 시작한다(`Farm.setup`)
- 혼자 할 때 Main이 지도마다 `Farm`을 두고 매 물리 틱 플레이어 다음에 모든 지도를 한 틱씩 진행한다(`Main.step_farms`, `FARM_RUNS_WITHOUT_PLAYERS`: 던전에 내려가 있어도 지상 밭이 자란다)

### 일구기 (괭이)

- 괭이 동작의 4번째 프레임(`HOE_IMPACT_FRAME`, 18틱째: 날이 흙에 닿는 그림)에 목표 칸을 일군다(누르고 있으면 되풀이, M2a). 조건(`Farming.till_refusal`, 이 순서): 맵 안·손 닿는 칸(`outside the map`, `out of reach`), 지상(던전은 바닥을 그리지 않는다: `no ground to till`), 풀(흙이면 `already tilled`, 재면 `corrupted ground`), 설치물 없음(제단·입구·횃불·조제대·가방: `blocked`), 식생 없음(채집물: `something grows there`), **빛 안**(`TILL_ONLY_IN_LIGHT`: 칸의 네 모서리 모두 안전 반경 안, M1 생성기의 흙 규칙과 같다, `Farming.in_light`. 아니면 `outside the light`), 재 옆이 아님(그림 규칙 `WorldData.can_set_terrain`: `too close to corruption`, 빛 안에서는 생기지 않는다)
- 시드 1에서 빛 안의 칸은 129칸(제단 9칸 포함)이다. 가운데만 빛 안이고 모서리 하나가 밖인 칸은 일굴 수 없다(시험)
- 사람이 나타나는 자리(지도의 도착점, 제단 둘레 부활·참가 자리 아홉: M6-fix)도 일굴 수 있다: 흙과 작물은 걸음을 막지 않는다(막는 조제대와 다르다, 시험)
- 흙을 풀로 되돌리는 일은 없다(괭이로도, 저절로도. 문서에 없음). 디버그 바닥 편집(봇 `edit`)도 작물·젖은 칸이 있는 흙을 풀로 바꾸지 못한다(`EditLog.check`: `a field lies there`)

### 씨앗 (`ItemDB` 종류 `SEED`)

- `seed_healing`·`seed_buff`·`seed_poison`: 아이콘은 04-env 작은 것 띠 `items_v04_strip.png`의 첫 세 칸(씨앗 봉투 #18~#20, 띠 색 = 작물 색. M6a 물약처럼 그 칸을 잘라 씀, `ItemDB.STRIP_SEEDS`). 등급 없음, 묶음 99(`STACK_SEED`). 표 끝에 더해서 다른 아이템 번호는 그대로다(아이템 33개)
- **얻는 길 (임시값 "M5a 씨앗 얻기")**: 문서에 없다(상인은 M8). 고른 길: ① 야생 약초를 그 자리에서 캐면 그 작물의 씨앗 하나(`SEEDS_PER_WILD_HERB`, 혼자 할 때. 떨어진 약초를 주우면 없음, 인벤토리에 자리가 없으면 없음) ② 수확하면 씨앗 하나가 돌아온다(`CROP_HARVEST_SEEDS`) ③ 시험용 `--give=seed_healing:5`. 이유: 야생 약초가 그 작물의 야생판이라(game-concept §9.7 "채집", M2b의 야생 약초 셋) 씨앗이 거기서 나오는 것이 가장 짧은 고리이고, 늘 하나라 난수가 없어 M5c의 호스트가 그대로 같다. 수확이 씨앗을 돌려줘서 한 번 심은 밭은 계속 간다. 독초 씨앗은 누구나 얻지만 약초사만 심는다(넘겨줄 수 있다). F5 묶음에는 넣지 않았다(M3-fix가 비워 둔 칸을 채우면 약초사가 처음 캔 상급 약초가 들어갈 자리가 없어진다)
- **심기**: 씨앗을 고르고 목표 칸에 좌클릭(누르고 있어도 한 번, 횃불처럼 동작 없이 놓는 프레임 → `Player.place_requested` → `Main`). 조건(`Farming.plant_refusal`, 이 순서): 씨앗(`not a seed`), 맵 안·손 닿는 칸, **● 클래스**(독초 씨앗은 약초사만: `herbalist only`), 일군 흙(`not tilled`), 작물 없음(`already planted`), 설치물 없음(`blocked`), 그리고 시들 자리가 아님(`PLANT_ONLY_WHERE_IT_GROWS`: 빛 밖 `outside the light`, 오염 2칸 안 `too close to corruption`). 씨앗 하나를 쓰고 그 칸에 0단계 작물(젖은 흙이었으면 젖은 채, 물 시간 이어짐), 약초사가 심으면 "약초사가 심음" 표지

### 물주기 (물뿌리개)

- 물뿌리개 동작의 6번째 프레임(`WATER_IMPACT_FRAME`, 30틱째: 물이 땅에 닿는 그림)에 목표 칸(일군 흙: 빈 칸이든 작물이든)이 젖는다. 이미 젖은 칸은 물 시간이 처음부터(편집 없음). `WATER_TICKS`(60초) 뒤 마른다(편집). 시든 작물의 물도 마른다. 물뿌리개는 비지 않는다(물 긷기는 문서에 없다). 풀·재는 `not tilled`
- 그림 (`world/field_view.gd`): 젖은 칸은 바닥 위에 04-env 물 준 흙 사본(`tiles_grass-soil_v03_watered.png`, `tiles_soil_var_{1,2}_v01_watered.png`: 흙 픽셀만 다르고 배치는 마른 것과 같다)을 칸별로 덧칠한다(● R29). 바닥이 dual grid라 월드 칸 하나 = 그 꼭짓점을 모서리로 가진 그림 칸 넷의 그 모서리 쪽 8×8 넷이고, 그림 칸마다 지금 그린 타일(`GroundView.drawn_at`)의 물 준 사본에서 그 사분면을 가져온다(`FieldView.wet_quad`). 옆 칸을 일구면 그 그림 칸의 타일이 바뀌므로 둘레의 젖은 칸을 다시 만든다. 젖은 칸 하나 = 노드 하나(캔버스 아이템 하나가 받는 빛이 15개까지라 바닥처럼 작게), 바닥 빛 레이어(디더 빛)

### 자라기

- 매 틱(`Farm.step`, 칸 줄 순서): ① 시듦·되살아남(아래) ② 젖었고 시들지 않았고 익지 않은 작물은 한 틱 자람, `CROP_STAGE_TICKS`(40초)가 모이면 다음 단계(편집) ③ 젖은 칸의 물이 한 틱 줆, 0이면 마름. 단계 0(씨앗) → 1 → 2 → 3 → 4(익음) = `crops_v03`의 0~4칸. 익은 작물은 그대로 익어 있다(썩지 않음)
- 약초사가 심은 작물은 `CROP_HERBALIST_GROWTH_PCT`(200%)로 자란다(단계마다 20초). 일반 작물은 다 자라는 데 젖은 시간 160초(물 세 번), 약초사의 것은 80초(두 번)
- 시계·난수가 없다: 같은 월드에 같은 틱에 같은 동작이면 같은 결과다(시험: 20,000틱 대본 두 번이 500틱마다 월드 해시·타이머 해시까지 같다)

### 수확 (낫)

- 낫은 약초사의 무기다(M4a). **작물이 있는 칸을 겨누면 수확만**(단계·시듦 무관: 곡괭이가 벽을 겨누면 채굴만인 것과 같은 규칙, `Farming.is_harvest_swing`), 아니면 공격 그대로. 맞는 프레임(4번째, 18틱째)에: 익었으면(4단계, 시들지 않음) 그 작물의 약초 `CROP_HARVEST_HERBS`(2)개 + 씨앗 `CROP_HARVEST_SEEDS`(1)개, 칸은 빈 흙(젖었으면 젖은 채). 익지 않음(`not ripe`)·시듦(`withered`)은 아무 일 없음(그 칸에 선 이단도 맞지 않음, 시험)
- 약초는 **야생 약초와 같은 아이템**(`wild_healing` 등)이라 M6의 레시피가 그대로 조제한다(시험: 수확한 일반 회복 약초 둘 → 일반 회복 물약). 따로 만들지 않은 이유: 문서의 물약은 작물 하나에 하나이고(● §12 R28) 야생 약초 = 그 작물이라, 아이템이 둘이면 같은 약초가 레시피 둘·인벤토리 두 칸이 된다
- **등급은 거두는 사람**(`CROP_GRADE_BY_HARVESTER` 켬): 약초사가 거두면 상급, 다른 클래스는 일반(누가 심었든). 고른 이유: §9.7 "약초사는 … 상급 등급을 거두며"의 동사가 거두기이고, ● §3.4가 야생 약초의 등급을 캐는 사람으로 정했고, ● §3.0 표의 "공용 수행 … 일반 등급 약초만"이 다른 클래스의 손에 상급을 주지 않는다(심은 사람이 정하면 팔라딘이 약초사의 밭에서 상급을 거둔다). 끄면 심은 사람(약초사가 심은 작물은 누가 거둬도 상급)
- 인벤토리에 안 들어가는 것은 그 칸 가운데에 드롭(약초 하나, 씨앗 하나), 땅의 드롭이 `MAX_DROPS`면 사라짐(채굴 M3a와 같은 규칙)

### 시듦 (○ §9.7 → 임시값 "M5a 시듦")

- 규칙: **그 칸이 빛 밖이거나**(위의 `Farming.in_light`: 네 모서리 중 하나라도 밖) **오염된 칸이 2칸 안에 있으면**(`CROP_CORRUPTION_REACH_TILES`, 체비셰프, 자기 칸 포함, 오염 레이어) 그 틱에 시든다(편집). 시든 작물은 자라지 않고 거둘 수 없고 시든 그림(`crops_v03`의 시듦 칸)이다. **원인이 모두 사라지는 틱에 되살아난다**(단계와 그 단계에서 자란 틱은 그대로 이어감): 빛이 돌아오거나(제단이 돌아옴, M5b) 오염이 걷히면(팔라딘의 정화, M5b). 물은 시든 동안에도 마른다
- "닿은"을 2칸으로 둔 이유: 그림에 흙 + 재 모서리 타일이 없어서 흙은 재에서 한 칸 떨어져야 한다(`WorldData.can_set_terrain`). 밭이 오염에 가장 가까이 있을 수 있는 거리가 2칸이라, "옆" = 1칸이면 시들 일이 없다
- 밭은 남는다(○ §9.7 "제단을 옮기면 밭은 남고 빛 밖이 된다"를 기본값으로 구현, 임시값 "M5a 시듦". M5-fix: ●로 잘못 적었던 것을 고침. §9.7은 "○ 제안, R23" 절이다): 흙·작물은 빛 밖이 되어도 지워지지 않고 시들어 기다린다. M5a에는 제단을 옮기는 일이 없어서(M5b) 빛 밖·오염 옆의 밭은 시험 플래그 `--test-field`로만 생긴다(빛 밖은 일굴 수 없으므로). 시험은 데이터의 제단 자리를 옮겨 본다

### 시험 (M5a)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=farming < /dev/null   # 약 5초
```

- `test_farming.gd`: 밭 값(작물 × 단계 × 표지 120개가 한 바이트 안에서 모두 다르고 되돌아옴, 채집물 값·0·64는 밭이 아님), 빛(제단 둘레 441칸에서 `in_light` = 이 시험에 따로 적은 "네 모서리가 반경 안", M1 흙은 모두 빛 안, 제단 없는 지도는 빛 없음), 오염(자기 칸·2칸·대각선 2칸은 닿음, 3칸은 아님, 흙이 재에 가장 가까이 갈 수 있는 거리 = 2), 일구기(빛 안 풀 → 흙 편집 하나, 걸음 안 막음, 흙·M1 흙은 `already tilled`, 제단·횃불·조제대·가방 `blocked`, 채집물, 손 닿지 않음·발 칸·맵 밖, 가운데만 빛 안인 칸 거부·줄 끝의 빛 안 칸 됨, 재, 먼 풀, 던전, 사람이 나타나는 자리는 일굼), 씨앗(클래스 다섯 × 씨앗 셋 = 15가지, 이 시험에 따로 적은 ● R37과 같음: 11가지 됨, 거부면 씨앗을 안 씀, 약초사만 "약초사가 심음"), 심기(풀·약초·빈 칸·없는 칸·손 닿지 않음·이미 심음·횃불, 젖은 흙에 심으면 젖은 채 물 시간 이어짐, 빛 밖·오염 2칸 안 거부), 물주기(빈 흙이 젖음, 정확히 `WATER_TICKS`에 마름, 반쯤에 다시 주면 처음부터·편집 없음, 풀 거부, 작물도 젖음), 자라기(계속 젖은 일반·약초사 작물의 단계 틱 = [S, 2S, 3S, 4S], 약초사 = 200%, 익으면 그대로, 마르면 3단계 시간 동안 편집 0, 한 번 준 물만큼 자라고 마르면 멈추고 다시 주면 모자란 틱 뒤 다음 단계), 수확(약초사 = 상급 둘 + 씨앗, 다른 클래스 넷 = 일반(약초사의 작물이어도), 팔라딘의 작물을 약초사가 = 상급, 젖은 칸은 젖은 채, 익지 않음·시듦·빈 흙 거부, 가득 찬 인벤토리 → 드롭 둘, `MAX_DROPS` → 사라짐, 수확물로 회복 물약 조제), 낫 규칙(단계 0~4·시듦 = 수확 동작, 빈 흙·젖은 빈 흙·풀·검은 아님, 맞는 프레임들), 시듦(3칸 오염은 아님, 2칸이면 다음 틱에 시듦·자람 멈춤·물은 마름, 오염을 걷으면 다음 틱에 되살아나 이어 자람, 제단 자리를 옮기면 시들고 밭은 남고 돌아오면 되살아남, 재 남쪽 2칸의 작물은 첫 틱에), 결정성(20,000틱 대본 두 번이 500틱마다 같음, 120 작물의 한 틱 비용, 스냅샷 왕복 = 같은 해시와 새 `Farm`), 편집(전송 왕복, 디버그 바닥 편집 거부, 진행은 돌려준 편집으로만), 그림(물 준 칸·작물 = 데이터, 사분면마다 그 그림 칸 타일의 물 준 사본, 옆 칸을 일구면 따라감, 작물의 시트 칸·젖은/마른 시트·자리, 시듦 칸, 흙더미 색이 흙 타일의 색이고 수확 칸은 그대로), `main.tscn`(약초사: 괭이는 그 프레임에 일굼, 독초 씨앗 클릭, 물뿌리개, 매 틱 자람, 익지 않은 작물에 낫 = 공격 없음, 익은 작물 = 상급 둘 + 씨앗, 풀에 낫 = 그 칸의 이단을 침, 야생 약초에 씨앗·떨어진 약초는 없음, `--test-field`(빛 밖은 첫 틱에 시듦, 틀린 값 여섯 거부)), 세션(플레이어의 씨앗 클릭은 프레임 없음, 위조한 씨앗 USE는 `farming offline only`, 괭이는 동작만 하고 월드·편집 기록 그대로)
- 바꾼 기존 시험: `test_items.gd`(아이템 33개, 종류별 수에 SEED 3, 씨앗이 표 끝, 씨앗 아이콘 = 띠의 칸 픽셀), `test_actors.gd`(그림 출처 4개 더함, 83). 스모크 M5a 항목, 창 그림 검사 `fields`

### 알려진 문제·자리 표시 (M5a)

- 시든 그림은 다 자란 작물 하나뿐이라, 어린 작물(0~3단계)이 시들어도 다 자란 시든 그림이 된다(크기가 갑자기 커진다). 자리 표시(임시값 "M5a 그림 자리 표시")
- 작물 흙더미 색을 흙에 맞추는 것(04-env prompts.md "작물 흙더미 색은 이 흙 색에 맞춰 바꿔 쓴다(물 준 칸에서는 물 준 색으로)")은 코드의 색 표(`FieldView.MOUND_*`, 흙 타일에서 잰 색)로 한다. 그림이 아니라 사람이 화면으로 볼 것
- 물 준 덧칠은 칸 경계에서 직선으로 끊긴다(칸별 덧칠, ● R29가 정한 방식)
- `crops_v03`의 수확 다발 칸은 쓰지 않는다(수확물은 야생 약초 아이템과 그 아이콘). 야생 독초 그림 `crop_poison_wild_v01`도 쓰지 않았다(지상의 야생 독초는 M2b의 `item_wild_poison_v02` 그대로). 성수 그림·오염 장식(04-env)은 M5b(정화)에서
- 괭이·물뿌리개·낫 아이콘은 M2a의 코드 그림 그대로
- 작물이 많을 때의 시간: 젖은 작물 120개(빛 안 + 빛 밖)에 한 틱 약 0.3~0.4ms(측정). (M5-fix에서 바꿈) 시듦 원인은 제단 자리나 오염 레이어(해시)가 바뀐 틱에만 다시 구하고, 시듦 표지가 원인과 맞는 마른 작물은 그 틱에 아무것도 하지 않아 건너뛴다(`Farm.step`): 옮긴 제단이 남긴 마른 작물 1,000개가 한 틱 약 3~4.8ms → 0.11ms. 젖은 작물은 자라거나 마르므로 그대로 매 틱 본다
- 디버그 바닥 편집(봇 `edit`)은 흙을 풀로 되돌릴 수 있다(밭이 없는 흙만). 게임 규칙으로는 되돌릴 수 없다

## M5b: 정화 · 성수 · 제단 옮기기

혼자 할 때 먼저(M5b 지시, M5a처럼). (M5c에서 바뀜: 세션에서도 호스트가 같은 규칙으로, 아래 "M5c") **세션(`--host`/`--join`)에서는 꺼져 있고 M5a 흐름 그대로다**(M5c에서 켠다): 세션의 플레이어는 `Player.purify_on`이 꺼져 있어 성수 좌클릭이 프레임을 만들지 않고 F가 채널링을 시작하지 않으며, 호스트는 성수 칸의 USE를 `purification offline only`로 거부하고(M5a의 씨앗처럼), F를 누르고 있어도 제단은 그대로다(제단 들기는 혼자 할 때의 `Main.step_altar_hold`만 센다). 전송 형식은 v6 그대로(정화·제단은 칸 편집이고, 채널링 상태는 아직 전송 형식에 없다). 문서의 ●는 그대로 따랐다: 누구나 성수로 타일 몇 개를 정화하고 광역 정화 채널링은 팔라딘의 것(● gameplay-design §3.0 R11 팔라딘 줄), 제단의 위치·이동 자유(● game-concept §9.3), 부활 지점 = 제단(● §2.6). 밭은 남는다는 ○ §9.7을 기본값으로 구현했다(M5-fix: ●로 잘못 적었던 것을 고침). ○·?와 문서에 없는 것은 모두 [임시값](#임시값-사람-확인-필요) 표의 "M5b" 줄이다. 오염 확산·재오염(○ §3.7 슬라이스), 원천 봉인·반경 확장(팔라딘 전용 칸의 나머지), 상인·상점 성수(M8), 다른 스킬, 클래스 자원, 기도, 제단 업그레이드(M12), 새 적, 나무·건설(M7), 저장, 세션(M5c)은 M5b가 아니다.

### 성수 (`items/purify.gd`, `ItemDB` 종류 `CONSUMABLE`)

- `holy_water`: 04-env 묶음 2 #58 성수 병(`item_holy_water_a_v02.png`, 판정 "좋음" 둘 중 첫째; b·c는 쓰지 않음), 새 종류 `CONSUMABLE`(목표 칸에 써서 없어지는 것), 묶음 10(`STACK_HOLY_WATER`), 등급 없음, 표 끝(아이템 34개, 다른 번호 그대로)
- **얻는 길 (임시값 "M5b 성수 얻기")**: `--give=holy_water:<n>`뿐(M6a의 조제대처럼 디버그 아이템). 문서의 대체 수단은 상점의 성수(M8)이고, 공용 수행 칸은 "누구나 성수로"라고만 하며 만드는 법이 없다. 조제대 레시피로 두지 않은 이유: 재료가 문서에 없고(약초로 만들면 정화가 약초사 고리에 묶임), 상점이 생기면 그쪽이 문서의 길이다. F5 묶음에도 넣지 않았다(M3-fix가 비워 둔 칸)
- **붓기**: 성수를 고르고 목표 칸에 좌클릭(누르고 있어도 한 번) → 마법 동작(`HOLY_WATER_ANIM`, 마시기처럼 빌려 씀) → 4번째 프레임(`HOLY_WATER_EFFECT_FRAME`, 18틱째)에 하나를 쓰고 목표 칸 둘레 체비셰프 1칸(3×3, `HOLY_WATER_RADIUS_TILES`)의 오염 칸을 정화한다. 조건(`Purify.holy_water_refusal`): 맵 안, 손 닿는 칸, 그 3×3에 오염 칸이 있음(없으면 `nothing to purify`, 동작도 시작하지 않고 아무것도 안 씀). 쓰이는 프레임에 다시 본다(`Purify.pour`: 그동안 정화됐으면 거부·안 씀, 그 칸의 성수가 없으면 다른 칸의 것, 하나도 없으면 `the holy water is gone`). 그 전에 맞으면 동작이 끊겨 아무것도 안 씀

### 팔라딘의 정화 채널링 (`PlayerSim` 채널, `Purify.channel_*`)

- **시작**: **F**(임시값 "M5b 키", ○ §1 "F … 정화 시작"). F는 먼저 줍기(M2b)이고, 목표 칸에 주울 것이 없을 때(`nothing there`) 팔라딘(● 클래스 전용)의 발 칸이나 그 8이웃(`PURIFY_START_REACH_TILES` 1)에 오염 칸이 있으면 다음 프레임에 채널링을 시작한다(`Main.pick_up` → `Player.request_channel` → 프레임의 `channel`(전송 형식에 없는 해석 필드) → `PlayerSim.step`). 서 있고(그 프레임에 걷지 않음) 동작·대시·경직·다운이 아니고 제단을 들고 있지 않아야 한다. 다른 클래스의 F는 줍기 그대로. M5-fix: 목표 칸이 제단 칸이면 채널링을 시작하지 않는다(그 F는 제단의 것: 누르고 있으면 든다. 임시값 "M5b 키". 세션은 `SessionHost.wants_channel`이 같은 규칙)
- **진행**: 공유 시뮬레이션(`PlayerSim.channel_tick`/`channel_cell`)이라 혼자 할 때와 (M5c의) 호스트·예측이 같은 규칙이다. `PURIFY_CHANNEL_TICKS`(180틱, 3초, 시작 프레임 포함) 동안 서 있고, 끝나는 틱에 `CHANNEL_DONE` → 발 칸 가운데에서 반지름 `PURIFY_RADIUS_TILES`(3칸) 안에 가운데가 드는 칸(원판 29칸) 중 오염 칸을 정화한다(`Purify.channel_done`: 그때 남은 것만, 없으면 `nothing to purify`). 그동안 마법 동작을 되풀이해 보이고(`PURIFY_ANIM`, 자리 표시), 반지름 둘레의 금빛 점 16개가 진행만큼 켜진다
- **끊김**: 그 프레임의 움직이기·대시·사용(끊고 그 프레임은 평소처럼 걷거나 대시하거나 동작을 시작), 맞음(`PlayerSim.hurt`), 다운(독 틱 포함, `_go_down`), 다른 지도로 감(`Player.set_world`). 아무것도 정화되지 않는다. 콘솔 `EVENSONG_PURIFY channel broken: moved|dash|use|hit|down`

### 정화된 땅 (임시값 "M5b 정화된 땅")

- 정화 = 칸마다 편집 둘(`Purify.edits_for`): 오염 레이어 0, 바닥 재 → 풀(**그 자리에서 풀**). 구역의 새 가장자리는 풀↔재 dual grid 타일(오염 v05)이 그린다(풀은 무엇과도 닿을 수 있어 흙 + 재 금지 규칙이 늘 지켜짐, 시험)
- "재를 거쳐 풀"은 월드에 두지 않고 그림으로만 보인다(`world/purify_view.gd`): 정화된 칸마다 04-env 재 얼룩(`decal_ashcreep_1~3`, 풀 쪽 경계의 잿빛 얼룩, 칸 해시로 셋 중 하나, 칸 가운데, 바닥 빛 레이어)이 1초(`PURIFY_ASH_TICKS`), 칸 테두리의 금빛 1px 사각형이 0.5초(`PURIFY_FLASH_TICKS`) 동안 안으로 줄어든다(코드 그림, unshaded)
- 정화된 칸 위의 채집물(재 버섯·금 간 돌·곰팡이 돌)은 그대로 있다. 재오염·확산은 없다

### 정화가 바꾸는 것

- **이단의 스폰 칸**: `Arena.sync_world`가 매 `step()` 처음에(그리고 Main이 정화를 적용한 뒤에) 제단 자리와 오염 칸 수가 바뀌었으면 빛 규칙과 지상 스폰 칸(오염 구역과 그 둘레 2칸, M4a 규칙)을 다시 계산한다. 정화된 구역 둘레에는 스폰 칸이 없어지고, 오염이 모두 걷히면 스폰 칸 0 → 지상 스폰 없음. 이미 있는 이단은 그대로. 생성된 월드 그대로의 스폰 칸은 678개(스모크 `spawn_tiles=678` 그대로)
- **시든 작물**: M5a 규칙 그대로(오염이 2칸 안이면 시듦) 그 오염이 걷히면 다음 농장 틱에 되살아난다(단계·자란 틱 이어감, 시험)
- **던전**: 오염 레이어가 비어 있어 정화할 것이 없다. 이단의 제단은 M4 전투 그대로

### 제단 들고 옮기기 (`items/altar_move.gd`)

- **들기**: 누구나(`ALTAR_MOVE_ANYONE`) 손 닿는 제단 칸을 겨누고 F를 `ALTAR_PICKUP_HOLD_TICKS`(120틱, 2초) 누르고 있으면 든다(놓거나 다른 데를 겨누면 처음부터, 동작 중이거나 다운이면 세지 않음). M5-fix: 채널링이 도는 동안(그래서 든 채 채널링이 끝나 정화하는 일이 없다. 호스트는 처음부터 거부했다), 소생 거리(`REVIVE_REACH_PX`, 발과 발) 안에 다운된 사람이 있는 동안(그 F는 소생: 비성직자의 5초 소생 중 2초에 제단이 들려 빛이 꺼지던 것)도 세지 않고 처음부터. 규칙 하나 `AltarMove.hold_counts`를 혼자 할 때·클라이언트·호스트가 같이 쓴다(임시값 "M5b 키"). 지상만, 비용 없음. 제단 칸 아홉이 "설치물 없음" 편집 → 제단이 월드에 없다
- **들고 있는 동안** (임시값 "M5b 들고 있는 동안", 고른 쪽: **안전 반경 없음**): 빛·안전 반경·이단의 빛 규칙·스폰 억제·부활 자리·조제대가 비워 두는 부활 자리가 없다(제단을 읽는 모든 것이 "제단 없음"을 읽음). 밭은 모두 빛 밖이라 시든다. 죽은 사람의 부활은 제단이 놓일 때까지 기다린다(`EVENSONG_DEATH respawn waits`, 놓으면 다음 틱에 새 자리로). 든 사람: 머리 위에 작은 제단(`AltarMark`), 좌클릭은 내려놓기만(도구·마시기·성수·던지기 없음), 입구·계단의 F 거부(`carrying the altar`), 채널링 없음. 걷기·대시·F 줍기는 그대로(속도도 그대로), 제작 창(Tab)·버리기(F7)·핫바 고르기도 그대로다(M5-fix: 여기와 임시값 줄이 "걷기·대시·F 줍기만"이라 했으나 혼자 할 때도 호스트도 이 셋을 막지 않는다. 고친 것은 문구). 다른 길(놓을 때까지 옛 빛이 남음)은 고르지 않았다: 빛을 들고 다니면 "빛 = 제단이 있는 곳"이 흐려지고, 옮기는 동안의 위험이 "제단을 옮겨 새 지역으로 전진"(§9.3)을 팀 일로 만든다
- **내려놓기**: 좌클릭 → 목표 칸(발 칸의 8이웃)이 가까운 변이 되는 3×3(가운데가 발 칸에서 그 방향으로 두 칸, `AltarMove.place_rect`). 조건(`AltarMove.place_refusal`, 이 순서): 지상(`the altar stays on the surface`), 맵 안, 모든 칸이 열린 땅(설치물·벽·드롭 없음: 입구·횃불·조제대·가방 위는 안 됨 `not open ground`), 오염·재 아님(`corrupted ground`), 식생 없음(채집물·작물·젖은 흙 `something grows there`; 마른 빈 흙은 됨), 누구의 발도 아래에 없음(`someone stands there`), 사람이 나타나는 자리(입구 도착점) 아님(`where players appear`), 새 부활 자리 아홉이 모두 설 수 있음(맵 안, 막는 것 없음 `no room around it`), 새 빛 안(발 상자)에 살아 있는 이단이 없음(`a heretic is in the light`: 이단은 빛에 들어가지 않는다는 M4a 규칙이 놓는 순간에도 지켜지게). 들고 있는 동안 놓일 자리가 금빛(됨)/짙은 빨강(안 됨) 테두리와 새 빛 가장자리 점(6°마다)으로 보인다(`AltarGhost`). **M5-fix: 새 빛이 오염 칸을 덮어도 된다**(임시값 "M5-fix 빛 아래 오염", `ALTAR_LIGHT_MAY_COVER_CORRUPTION` 켬, ○ game-concept §5 "밀어낸다"·§9.3 "오염 저항"을 정하지 않고 지금 동작을 적음): 그 오염은 그대로 남고(밀어내지 않음, 확산도 없음: 정화로만 걷힘), 그 구역의 스폰 고리가 빛 가장자리 바로 밖까지 오고(빛 안에는 없음, M4a), 빛 안이라도 오염 2칸 안의 작물은 시든다. 생성된 제단은 재까지 풀 4칸(`ASH_CLEARANCE_TILES`)을 두지만 옮긴 제단에는 그 여유가 없다(시드 1 구역 옆 (52,6): 빛 안 오염 17칸, 빛 가장자리 1.5칸 안 스폰 칸 19개). 끄면 오염 칸 가운데가 새 가운데에서 안전 반경 + 4칸 안에 있는 자리를 거부(`corruption in its light`, `AltarMove.light_corruption_refusal`)
- **든 사람이 다운되면**(맞음·독): 그 틱의 전투가 끝난 뒤(M5-fix: `Main.check_carriers`, 호스트의 `_check_carriers`와 같은 자리. 전에는 맞는 순간 아레나 걸음 한가운데서 놓아 호스트와 순서가 달랐다) 그 발 칸에서 가까운 고리부터(체비셰프, 64칸까지, 고리 안은 줄 순서) 내려놓기 규칙(손 닿음 빼고)으로 처음 되는 자리에 저절로 놓인다(`AltarMove.set_down_fallback`, `EVENSONG_ALTAR set down`). 없으면 이단을 빼고 한 번 더, 그래도 없으면 마지막으로 서 있던 자리(`GameWorld.last_altar_rect`) 둘레(그 자리가 아직 되면 그 자리, 이단과 함께·빼고). **어느 길이든 놓기 규칙을 지나야 해서 무엇 위에도 놓이지 않는다**(M5-fix: 전에는 들었던 자리를 검사 없이 덮어 그동안 놓인 횃불·조제대를 지울 수 있었고, 호스트를 잃은 클라이언트에서는 그 자리가 비어 제단이 사라졌다). 그래도 없으면 든 채로 있고(`set down failed`, 64칸 안에 놓을 곳이 하나도 없을 때뿐) 다시 일어날 때까지 찾지 않는다
- **옮긴 제단을 따르는 것**(모두 그때그때 월드의 제단 자리를 읽는다): 빛(`AltarLight`, M5-fix: 텍스처 한 쌍을 모든 자리가 같이 씀), 안전 반경(`GameWorld.safe_zone`), 제단 노드·불꽃, 제단 옆 띠(걷기 충돌), 이단의 빛 규칙·가장자리 지켜보기·스폰 칸(`Arena.sync_world`), 부활·참가 자리 아홉(`GameWorld.spawn_point`), 조제대가 비워 두는 자리(`WorldItems.reserved_feet`), 밭의 빛(`Farming.in_light`: 옛 밭은 남아 시들고, 새 빛 안의 밭은 일구고 자라고, 돌아오면 되살아남), 더미(새 부활 자리 1~4에서 제단을 봄)
- **제단 자리 = 설치물 레이어**: 들기·놓기는 칸 편집 아홉이고 `EditLog.apply_to_data`가 `WorldData.refresh_altar_rect`로 제단 자리를 다시 읽는다(제단 칸 아홉이 한 3×3일 때만 그 자리, 반쯤이면 없음). `GameWorld.apply_edit`가 자리가 바뀌면 안전 반경·제단 노드·빛을 다시 놓고(저녁이 꺼져 있으면 꺼진 채) `altar_moved`를 낸다. 그래서 스냅샷·해시·편집 기록이 제단 자리를 그대로 덮고 M5c도 전송 형식을 바꾸지 않아도 된다

### 시험 (M5b)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=purify,altar_move < /dev/null   # 약 2초
```

- `test_purify.gd`: 넓이(성수 3×3, 채널링 원판 29칸: 이 시험에 따로 적은 원판과 칸마다 비교), 성수(가장자리에서 됨, 2칸 멀리·맵 밖·깨끗한 풀 거부, 붓기는 편집만 돌려줌, 3×3의 오염 칸(따로 셈)만 풀로, 칸마다 편집 둘, 하나 씀, 오염 수, 채집물은 그대로, 흙 + 재 0, 거부면 안 씀, 없으면 `gone`, 다른 칸의 것을 씀, 효과 프레임), 채널링 규칙(클래스 다섯 × 위·옆·2칸: 팔라딘만, 깨끗한 풀·던전은 `nothing to purify`, 원판의 오염 칸(따로 셈), 두 번째는 없음), 공유 시뮬레이션(시작 프레임·발 칸, 정확히 180프레임, 그동안 안 움직임, 움직이기·대시·사용이 끊고 그 프레임은 평소대로, 맞음·독 다운이 끊음, 걷는 중·동작 중·경직·다운이면 시작 안 함, `copy`·`same_all`에 있고 `same_as`(전송)에는 없음), 스폰 칸(생성 월드 678, 구역 하나를 정화하면 `sync_world` → 새로 계산한 규칙과 같고 줄고 모든 스폰 칸이 오염 2칸 안(따로 셈), `step()`이 스스로 따라감, 오염이 없으면 스폰 칸·스폰 0이고 있던 이단은 그대로), 되살아남(빛 안 흙 2칸 옆에 재를 놓으면 시들고 안 자람, 성수로 걷으면 다음 틱에 같은 단계로 되살아나 이어 자람), 결정성(성수와 채널링 대본 2,000틱 두 번이 50틱마다 해시까지 같음, 정화 편집의 전송 형식 왕복 = 같은 월드, 스냅샷), 그림(정화한 바닥 = 데이터, 재 얼룩이 칸마다 가운데·바닥 빛 레이어, 금빛 unshaded, 테두리 60픽셀 → 2×2 → 없음, 재는 60틱, 점 16개가 고리 위·첫 점이 위, 켜지는 수, `load_data`가 비움), `main.tscn`(팔라딘: F 뒤 다음 프레임에 시작, 마법 동작과 점, 마지막 틱 전에는 그대로·마지막 틱에 원판, 깜빡임, 아레나 스폰 칸, 걷기로 끊김, 재 위 채집물은 F로 주움(채널 없음), 성수: 좌클릭에 붓는 동작·효과 프레임에 3×3·하나 씀, 깨끗한 풀은 동작 없음, 성직자의 F는 채널 없음), 세션(성수 클릭은 프레임 없음, 위조한 USE는 `purification offline only`·안 씀, 채널 없음, 월드·편집 기록 그대로)
- `test_altar_move.gd`: 들기(클래스 다섯 모두, 2칸 멀리·발 칸·풀·맵 밖·던전 거부, 편집 아홉, 들면 제단·안전 반경·옆 띠 없음), 놓을 자리(여덟 방향과 발 칸: 이 시험에 따로 적은 3×3), 놓기 규칙(옛 자리·서쪽 풀은 됨, 횃불·드롭·채집물·작물·젖은 흙 거부, 마른 흙은 됨, 재 3×3, 입구 위, 입구 도착점 위, 누구의 발, 옆의 발은 됨, 부활 자리의 조제대, 맵 가장자리(부활 자리가 맵 밖), 맵 밖, 빈 자리, 새 빛 안의 이단·바로 밖의 이단, 던전, 가장 가까운 자리: 더 가까운 고리에 되는 자리가 없음), 다시 읽기(놓는 편집 여덟까지는 제단 없음, 아홉째에 그 자리, 한 칸 빠지면 없음), 월드 그림(`altar_moved` 두 번, 들면 제단 노드·빛 없음, 놓으면 노드·바닥 가운데·안전 반경·빛 자리와 텍스처, 새 자리 텍스처 둘, 부활 자리 아홉, 비워 두는 자리 = 도착점 + 새 부활 자리, 옆 띠, 걷기: 옛 자리 비고 새 자리 막힘, 남쪽에서 걸으면 남면에 딱 붙어 멈춤, 저녁 끈 채 돌아오면 빛 꺼진 채·켜면 켜짐, 돌아오면 새 텍스처 없음, 바닥 그대로), 밭(빛 안 작물이 들면 다음 틱에 시들고, 멀리 놓으면 시든 채 남고 흙·작물 그대로, 새 빛 안에 일구고 심고 물 준 밭은 자람, 옛 자리 옆 풀은 이제 빛 밖, 돌아오면 되살아남), 아레나(들면 빛 규칙 없음·옛 자리 옆에 스폰 가능, 구역 가장자리 옆에 놓으면 새 빛 안 스폰 칸 0·줄어듦·새 빛 안 스폰 거부, 빛 가장자리 안쪽의 플레이어를 쫓던 이단이 300틱 동안 한 번도 빛에 안 들어가고 가장자리에서 기다리고 플레이어는 안 맞음), 결정성(같은 옮기기 두 번 = 같은 해시·자리, 편집을 전송 형식으로 보낸 사본 = 같은 자리·해시, 스냅샷), `main.tscn`(F 한 틱 모자라면 그대로, 놓으면 처음부터, 120틱에 듦, 제단 노드·빛 없음, 머리 위 표시, 놓을 자리 표시가 겨눈 자리, 들고 있는 동안 좌클릭은 놓기만(검 안 휘두름), 오가기 거부, 죽은 동료의 부활이 기다림, 재를 겨눈 놓기 거부·붉은 표시, 채널링 없음, 서쪽에 놓기: 제단·빛·더미 넷·기다리던 동료의 부활(새 자리 1번)·아레나의 빛, 죽은 플레이어는 새 자리 0번에 부활, 다시 들고 다운 = 3칸 안에 저절로 놓임·발 위는 아님), 세션(F를 누르고 있어도 제단 그대로, 편집 없음). (M5-fix) 빛 아래 오염(구역 옆 자리 됨, 다른 규칙이면 거부할 자리, 서쪽 풀·집은 아님, 놓은 뒤 빛 안 오염 칸이 그대로, 빛 안 스폰 칸 0, 재 때문에 시들 빛 안 칸이 있음), 내려놓기의 마지막 길(맵 밖 먼 점: 들었던 자리, 모르면 없음, 그 위의 횃불·사람이면 그 옆, 발 둘레 먼저, "집 먼저", 이단의 빛 밖), 되놓기(`Main.restore_altar_at`: 마지막 자리, 그 위 조제대면 옆에·조제대 그대로), 빛 텍스처 한 쌍(새 자리·집에 돌아와도 새 텍스처 0), 마른 작물도 시들고 되살아남·밖에서 놓은 마른 작물도 다음 틱에 시듦, `main.tscn`(구역 옆 제단: 제단을 겨눈 F는 채널링 없음, 옆을 겨눈 F로 시작한 채널링 내내 F를 제단에 = 안 듦·끝까지 돌아 정화, 그 뒤 120틱에 듦; 다운된 동료 옆에서 제단을 겨눈 F = 소생 먼저(299틱), 들기는 그 120틱 뒤; 든 사람이 다운 = 맞는 순간이 아니라 `check_carriers`에서)
- 바꾼 기존 시험: `test_items.gd`(아이템 34개, 종류별 수에 CONSUMABLE 1, 성수가 씨앗 뒤 표 끝, 앞 번호 그대로), `test_actors.gd`(그림 출처 4개 더함, 87). 스모크 M5b 항목, 창 그림 검사 `purify`·`altar`

### 알려진 문제·자리 표시 (M5b)

- 채널링 자세(마법 동작 되풀이), 정화의 금빛 테두리와 점, 든 제단 표시, 놓을 자리 표시는 모두 코드 그림 자리 표시다(임시값 "M5b 그림 자리 표시"). 재 얼룩은 풀 쪽 경계용 04-env 장식을 빌려 쓴다. 효과가 작아서(테두리 1px, 점 2×2) 화면에서 잘 안 보일 수 있다: 사람이 볼 것
- 오염 구역 자체의 흩뿌린 장식(04-env 뼈·곰팡이·금·맥 `decal_*`)은 아직 없다. 구역은 M1처럼 재 타일만
- (M5-fix에서 풂) 빛 텍스처 캐시가 제단이 처음 놓이는 자리마다 둘(226×226) 늘던 것: 그림은 제단 가운데의 4px 위상과 소수부에만 달리고(가운데는 늘 16의 배수 + 8) 노드가 가운데에 서므로, 캐시 열쇠를 위상으로 바꿔 한 쌍을 모든 자리가 쓴다(`AltarLight.cache_key`, 시험이 바이트로 비교). 놓는 순간 약 38ms → 0.2ms, 텍스처는 더 늘지 않는다
- 들고 있는 동안 죽은 동료는 놓일 때까지 부활하지 않는다(혼자 할 때는 든 사람이 다운되면 먼저 놓이므로 막히지 않는다)
- 내려놓을 때 새 빛 안에 이단이 있으면 거부라, 이단에게 쫓기는 중에는 놓을 수 없다(다운 때의 저절로 놓기는 이단이 없는 더 먼 자리를 찾는다)
- 세션에서는 아무것도 바뀌지 않는다(M5c에서 풂: 아래 "M5c")

## M5c: 세션의 농사 · 정화 · 제단

M5a·M5b가 혼자 할 때 더한 것(밭·씨앗·물주기·자라기·수확·시듦, 성수·팔라딘의 정화 채널링, 제단 들기·옮기기)을 세션으로 가져왔다. ● 호스트 권한(game-concept §13)대로 **결과는 모두 호스트가 정한다**: 일구기·심기·물주기·수확(손 닿는 칸, 지도, 클래스 규칙 ● R37, 인벤토리), 작물의 자람과 시듦(호스트가 지도마다 농장을 돌림), 정화(성수 붓기, 채널링의 시작·진행·끊김·끝), 정화된 칸과 이단의 스폰 칸, 제단 들기·놓기와 그것을 따르는 모든 것(빛·안전 반경·부활 자리·비워 두는 자리·이단의 빛 규칙·밭의 빛). 클라이언트는 몸 동작과 채널링을 M2b·M4b처럼 예측하고 **결과는 예측하지 않는다**. 규칙은 M5a·M5b의 것 하나다(`items/farming.gd`, `world/farm.gd`, `items/purify.gd`, `items/altar_move.gd`를 혼자 할 때의 Main과 호스트가 같이 부름). 문서에 없는 새 규칙은 세션에서만 생기는 것들이고 [임시값](#임시값-사람-확인-필요)의 "M5c" 줄이다(들고 있는 동안 참가하는 사람의 자리, 든 사람이 나갈 때, M5-fix에서 더한 호스트를 잃었을 때의 제단). 나머지 고른 것은 [구현에서 고른 값](#구현에서-고른-값-설계-결정-아님)의 "M5c" 줄이다. 나무·도끼·작업대·건설(M7), 상인·상점 성수(M8), 다른 스킬, 클래스 자원, 기도, 제단 업그레이드(M12), 확산·재오염, 새 적, Steam, 저장은 M5c가 아니다.

### 호스트 (`net/session_host.gd`)

- **농장은 지도마다 하나**(`SessionHost.farms`, `farm_of`: 혼자 할 때와 같은 `Farm`). 매 틱 모든 멤버의 프레임 → 늦은 부활 → 아레나 → 든 사람 검사 → **농장**(`_step_farms`, `FARM_RUNS_WITHOUT_PLAYERS`: 모든 지도) 순서다. 혼자 할 때의 Main(플레이어 → 전투 → 농장)과 같은 순서라 같은 틱에 같은 결과다. 농장의 편집(단계, 시듦·되살아남, 마름)은 다른 편집처럼 그 지도의 번호 붙은 편집으로 그 지도의 사람에게 간다(`apply_world_edit`). 단계·시듦이 바뀌면 로그 `field map= at= <작물>`
- **심기 = 씨앗 칸의 USE**(M5a의 프레임 그대로, 새 요청 없음): 줍기와 같은 요청 예산(`rate`), 그다음 `Farm.plant`를 **호스트가 가진 그 사람의 자리·클래스·인벤토리로**(손 닿는 칸, ● 독초 씨앗은 약초사만 `herbalist only`, 일군 흙, 작물 없음, 시들 자리 아님). 주인에게 인벤토리. 로그 `farm slot= map= what=plant at= class= item= field=`
- **일구기·물주기·수확 = 도구 동작의 맞는 프레임**: 괭이·물뿌리개·낫의 USE는 M2b의 도구 사용 그대로 검사되고(손 닿는 칸, 바쁨), 맞는 프레임(`Farming.impact_tick`, 낫은 `Combat.impact_tick`)에 호스트가 그때의 자기 상태로 `Farm.till`·`water`·`harvest`(빛 안, 일군 흙, 익음·시듦, 등급 = 거두는 사람). 낫은 작물을 겨누면 수확만(M5a 규칙, `Farming.is_harvest_swing`): 그 칸의 이단을 베지 않는다. 아무것도 못 한 휘두르기는 채굴처럼 이유별로 센다(`swings_missed`: `outside the light`, `not ripe`, `withered` ...), 로그 `farm_refused`
- **야생 약초의 씨앗**: 호스트의 줍기가 그 자리의 야생 약초를 캐면 그 작물의 씨앗을 넣는다(`Farming.seeds_from_wild`: M5a의 `Main.seed_from_wild` 규칙을 둘이 같이 씀). 로그 `seed slot= from= item= count=`
- **성수 = 성수 칸의 USE**: `Purify.holy_water_refusal`(맵 안, 손 닿는 칸, 그 3×3에 오염)과 바쁨을 보고 `HOLY_WATER_ANIM`을 시작한다. 효과 프레임에 `Purify.pour`(다시 봄, 하나 씀, 3×3 정화)
- **채널링 = 새 요청 CHANNEL**: `Purify.channel_refusal`(● 팔라딘, 발 칸이나 그 옆의 오염)을 호스트가 가진 자리로 보고, 바쁘거나 이미 채널링 중이면 `busy`. 받아 주면 그 프레임의 `channel`을 켜고 `PlayerSim.step`이 서 있을 때 시작한다(혼자 할 때와 같은 공유 규칙). 그 뒤는 멤버의 프레임으로 센다: 클라이언트가 채널링 동안 매 틱 프레임을 보내고(행동처럼), 호스트는 그 프레임마다 한 틱(`timed`에 채널링을 넣음: 앞서지 못함). `CHANNEL_DONE` 프레임에 `Purify.channel_done`(그때 남은 오염만), 움직임·대시·사용·맞음·다운이면 끊김(`channel_broken`을 셈, 로그 `channel slot= map= broken: moved|dash|use|hit|down`. M5-fix: 멤버의 `Player.channel_broken` 시그널로 세서, 아레나의 칼이 프레임 사이에(`Player.take_hit`) 끊은 것도 센다. 전에는 프레임 안의 끊김만 셌다)
- **정화된 칸**: 칸마다 편집 둘(오염 0, 재 → 풀)이 그 지도의 사람에게 가고, 호스트 화면에 금빛 테두리·재 얼룩, 그 지도의 아레나가 바로 따라간다(`Arena.sync_world`: 빛 규칙과 스폰 칸. 매 `step()` 처음에도). 로그 `purify slot= map= what=channel|holy_water at= tiles= corrupted_left= spawn_tiles=`
- **제단 들기 = 새 요청 ALTAR_LIFT**: 요청 예산, 그다음 **호스트가 직접 센 F 누른 프레임 수**(`NetMember.altar_hold`: F를 누르고 `AltarMove.hold_counts`(살아 있음, 동작·채널링 없음, 소생 거리 안에 다운된 사람 없음)이고 **그 프레임의 발에서 손 닿는 제단 칸이 있는**(`AltarMove.altar_in_reach`, M5-fix) 프레임이 이어진 수)가 `ALTAR_PICKUP_HOLD_TICKS`(120) 이상(`F not held long enough`), 동작·채널링 중이 아님(`busy`), `AltarMove.pickup_refusal`(지상, 손 닿는 칸, 제단 칸, 클래스). 받으면 제단 칸 아홉이 "설치물 없음" 편집이고 그 사람이 든다(`Player.carrying_altar`, 호스트 상태). 클라이언트는 F를 누르고 제단을 겨눈 프레임을 같은 `hold_counts`로 세다가 120번째 프레임에 요청을 싣는다(`SessionHost.hold_altar`, 혼자 할 때 `Main.step_altar_hold`의 규칙. 다운된 사람은 클라이언트가 그린 대로 봐서 호스트와 한 틱쯤 다르면 거부되고 다시 2초). 호스트가 따로, 손 닿는 곳에서만 세므로 악의 클라이언트가 멀리서 F를 누르고 있다가 손 닿는 첫 프레임에 들 수 없다(M5-fix: 전에는 F만 이어 누르면 어디서든 셌다). 겨눈 칸은 프레임마다 오지 않아 요청의 칸으로만 본다: 손 닿는 제단 칸이 있는 자리에서 2초를 센 뒤 다른 제단 칸을 겨눠 드는 것은 막지 않는다(결과가 같다)
- **내려놓기 = 새 요청 ALTAR_PLACE**(든 사람의 좌클릭): 들고 있음(`not carrying the altar`), 요청 예산, 목표 칸이 발 옆, 그다음 `AltarMove.place_refusal`을 **호스트의 몸(그 지도의 플레이어 발)과 살아 있는 이단으로**. 받으면 제단 칸 아홉 편집 → 빛·안전 반경·부활 자리·비워 두는 자리가 모든 기기에서 따라간다(M5b의 `refresh_altar_rect`). 로그 `altar slot= map= picked_up from=` / `placed at= light=` / `set_down at=`
- **들고 있는 사람**: 사용·던지기·채널링·오가기·들기는 `carrying the altar`로 거부(M5b의 "좌클릭은 놓기만"을 호스트가 다시 봄. 입구·계단으로 던전에 들고 갈 수 없다). 다운되면(맞음·독) 그 틱 끝에 가까운 놓을 자리에 저절로(`_check_carriers` → `AltarMove.set_down_fallback`, 이단을 빼고 한 번 더, 그래도 없으면 든 자리 둘레: M5b "든 사람이 다운되면"), **세션을 나가면** 그 발 둘레에 같은 규칙으로(임시값 "M5c 든 사람이 나감", 끄면 든 자리부터). M5-fix: 어느 길이든 놓기 규칙을 지나야 해서 그동안 든 자리에 놓인 조제대·횃불·가방·드롭이나 사람 위에 놓지 않는다(전에는 마지막 길과 "끄면"이 든 자리를 검사 없이 덮었다). 놓을 곳이 하나도 없으면 다운된 사람은 든 채로(일어나면 다시 찾음), 나가는 사람은 들고 나간다(알려진 문제)
- **들고 있는 동안**: 부활은 기다린다(`respawn_waits slot=..: no altar (carried)`, 놓이면 다음 틱에 새 자리. 던전에서 죽은 사람도 그동안 던전에서 기다림). 그동안 참가하는 사람은 든 자리의 부활 자리에 나타난다(임시값 "M5c 들고 있는 동안 참가", `SessionHost.spawn_feet`). M5-fix: 그 아홉 자리는 들고 있는 동안에도 비워 둔다(`SessionHost.carried_reserved_feet` → `WorldItems.place`의 `where players appear`, 서 있는 제단의 부활 자리와 같은 M6-fix 규칙). 전에는 그동안 조제대를 그 위에 놓을 수 있었고 다음 참가자가 탁자 속에 나타났다. 그래도 막힌 자리(규칙 밖: "끄면"의 든 사람 둘레)는 슬롯 순서로 다음 설 수 있는 자리, 하나도 없으면 지상 도착점

### 전송 형식 버전 7 (`NetProtocol.VERSION`)

- 새 요청 셋(프레임에 붙음, 지도를 실음): **CHANNEL**(지도 u8 = 1B), **ALTAR_LIFT**(지도 u8 + 칸 s16×2 = 5B), **ALTAR_PLACE**(같은 5B). 디코더가 지도 범위를 먼저 본다. 입력 프레임은 **1바이트 그대로**(코드 0..179): 채널링은 프레임 비트가 아니라 요청이다(비트를 더하면 360코드라 한 바이트를 넘는다)
- **상태의 채널링**: 동작 비트(flags 3~6)가 15(`CHANNEL_ACTION`, 어떤 몸 동작도 15가 아님)이면 채널링 중이고 동작 프레임 바이트가 그 틱 수(1..179). 채널링과 몸 동작은 같이 돌 수 없고 채널링은 움직이지 않으므로 정화할 칸은 발 칸에서 다시 구한다(`Aim.feet_cell(pos)`). 0B 더함
- **든 제단**: 상태의 든 아이템 바이트 7번 비트(`CARRYING_FLAG`, 아이템 번호는 128 아래). 0B 더함. 그래서 상태는 17 / 33 / 40B 그대로, 정보도 그대로
- 밭·작물·젖음·시듦·정화된 땅·제단 자리는 M5a·M5b처럼 월드 레이어 값이라 편집(칸 11B)과 스냅샷이 그대로 나른다. 새 RPC 없음(18개 그대로). 버전 6 클라이언트는 `version`으로 거부된다

### 작물 상태 = 편집 (잰 것과 이유)

과제의 다른 길은 "작물 상태 묶음" 같은 작은 메시지였다. 편집으로 충분하다고 재서 정했다(`test_net_fields.gd`의 측정, 한 프로세스, ENet 페이로드 바이트, 호스트 → 클라이언트 둘):
- 서 있기만: 0 B/s(M6b와 같음: 묶음도 편집도 없음)
- M1 흙 19칸 모두에 젖은 작물이 실제 `Config` 시간으로 75초 자람: 편집 48개(단계 19 + 마름 19 + 그 사이), **14.1 B/s**, 한 틱에 가장 많은 편집 19개(모두 같은 틱에 심어서 같은 틱에 자람). 단계 편집 하나 = 11B(번호 4 + 지도 1 + 칸 편집 6). 작물마다 단계 4번 + 물 한 번 마름이 전부라 작물 수 × 5편집 / 수 분이다. 작은 메시지(작물마다 바이트 하나씩 묶음)로 바꿔도 아낄 것이 초당 수십 바이트이고, 대신 스냅샷·편집 기록·해시와 다른 둘째 길이 생긴다
- 채널링 한 번(3초, 9칸 정화): **2.3 KB/s**(상태 2.15 KB/s: 채널링 중에는 상태가 매 틱 바뀌어 걷는 것처럼 20Hz, 편집 124 B/s = 정화 편집 18개가 한 번에, 키프레임 35 B/s). M3b의 둘이 걷기 1.07 KB/s(플레이어 묶음 하나)와 같은 길이고 채널링 동안만이다
- 실제 세션 수(전체 실행의 `_fight_traffic_notes`, 아래 "측정"): `farm` 둘이 동작 중(act2/3) 약 3.3 KB/s, 아무도 안 움직임 0/3 약 150 B/s

### 늦은 참가 · 지도 들어옴

- 밭(흙 = 바닥 레이어, 작물·단계·젖음·시듦·약초사 표지 = 식생 레이어), 정화된 땅(오염·바닥), 제단 자리(설치물 레이어 + 스냅샷 머리말의 제단 자리, 든 동안은 없음)는 모두 스냅샷에 있다. 받는 쪽은 `GameWorld.load_data`로 밭 그림·제단·빛을 그대로 만든다. welcome 로그에 `altar=<x,y|none> tilled= crops= withered= corrupted=`
- 다른 사람이 들고 있는 제단은 welcome의 플레이어 정보(상태의 든 아이템 바이트)로 머리 위에 그린다. 채널링 중인 사람도 상태로
- 호스트의 농장 시계(그 단계에서 자란 틱, 남은 물)는 보내지 않는다: 클라이언트는 농장을 돌리지 않고 편집만 받는다. 호스트를 잃고 혼자 계속하면 받은 월드로 새 농장(M5a `Farm.setup`: 단계의 처음부터, 젖은 칸은 물 가득)

### 예측과 보이는 것 (`Prediction`, `SessionClient`, `Main`)

- 괭이·물뿌리개·낫·성수의 **동작**은 M2b처럼 바로(예측), 결과는 편집이 오면. 심기는 예측하지 않는다(줍기·횃불처럼)
- **채널링**: F(주울 것이 없고 오염 옆, 제단을 들지 않았고 제단 칸을 겨누지 않음(M5-fix), `SessionHost.wants_channel`)가 CHANNEL 요청이 되는 프레임에 예측도 시작한다(`Prediction.channel_on_map`). 채널링 동안 매 틱 프레임을 기록해 보낸다(호스트의 시계). 상태의 채널링 틱과 예측이 다르면 동작 보정으로 센다(시험에서 0). 정화는 예측하지 않는다
- **든 제단**: 자기 상태의 든 아이템 바이트가 오면 든 것이 되고(`Player.set_carrying_altar`), 그때부터 좌클릭이 ALTAR_PLACE이고 놓을 자리 표시가 이 기기의 월드로 그려진다(`Main._show_altar_ghost`: 금빛/빨강은 이 기기의 판단, 호스트가 다시 정함). 남의 머리 위 제단은 보간된 상태로
- **부활**: 예측의 부활 자리는 이 기기 월드의 제단 자리에서 그때 구한다(`Prediction.respawn_feet`, 자리 번호 = 슬롯). 제단이 없으면(든 동안) 예측도 기다린다
- **정화의 깜빡임**: 오염 칸이 0이 되는 편집이 오면 그 칸에 재 얼룩·금빛 테두리(`SessionClient.on_edit` → `PurifyView.flash`, 결과 JSON `purify_flashes`). 채널링 점은 그 지도 사람들의 채널링 틱으로(`Main._show_purify`, 세션에서도 매 틱)

### 시험 (M5c)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=net_fields,net_farm,net_purify < /dev/null   # 약 105초
```

- `test_net_fields.gd` (한 프로세스, `test_net_potions.gd`·`test_net_combat.gd`의 리그: 진짜 `SessionHost`·`SessionClient`, 메시지를 잡아 순서대로, 필요하면 한 방향 지연): 전송 형식 v7(세 요청 왕복·크기·모든 자른 길이·범위 밖 지도, 채널링 상태 17B·틱 0과 다 찬 틱 거부, 든 사람 + 마지막 아이템 + vitals 왕복, 든 비트 + 모르는 아이템 거부, 정보 18B, 프레임은 여전히 180코드). 악의 클라이언트(`run_frame`에 바로): **빛 밖 일구기**(괭이는 휘두르고 흙은 안 됨, `outside the light` 하나, 편집 0), 빛 안은 편집 하나, **팔라딘의 독초 씨앗**(`herbalist only`, 씨앗 그대로), 회복 씨앗은 됨(일반 속도), **익지 않은 작물 수확**(`not ripe`, 작물 그대로, 그 칸의 이단은 안 맞음), 3칸 밖 낫 `out of reach`, **한 틱 씨앗 USE 열 번**(심음 하나·이미 심음 셋·`rate` 여섯, 씨앗 하나만), 던전을 적음 `wrong map`, 물뿌리개, 야생 약초의 씨앗, 다운 중 `down`. 정화: **3칸 밖 성수** `out of reach`, 깨끗한 땅 `nothing to purify`(둘 다 동작·소모 없음), 아처의 채널링 `paladin only`, 제단 옆 팔라딘 `nothing to purify`, 던전을 적은 채널링 `wrong map`, 걷는 프레임의 CHANNEL은 시작 안 함, 42프레임에 한 걸음 = 끊김·정화 0, **CHANNEL 40프레임 연속**(하나 시작·39 `busy`), 끝나면 원판의 오염 칸(이 시험에 따로 적은 원판)만 정화·스폰 칸 줆, 성수 USE 열 번 = 붓기 하나·`busy` 아홉. 제단: 한 프레임 F의 ALTAR_LIFT `F not held long enough`, 두 칸 밖(M5-fix: 손 닿는 제단 칸이 없는 자리의 F는 세지 않아 `F not held long enough`; 손 닿는 자리에서 먼 칸을 겨누면 `out of reach`), 들지 않은 ALTAR_PLACE, **던전에서 들기**(M5-fix: 던전에는 제단이 없어 F를 세지 않음 → `F not held long enough`. `the altar stays on the surface`는 `test_altar_move.gd`의 규칙 시험), 120프레임 뒤 들기(편집 아홉, 든 자리 기억), 든 사람의 오가기(던전으로 들고 가기)·채널링·사용·던지기 거부, **입구 도착점 위에 놓기** `where players appear`, 재 위 `corrupted ground`, 아처 발 위 `someone stands there`, 한 틱 열 번 = `rate` 여섯, 빈 땅에 놓음(부활 자리·안전 반경이 따라감), 든 사람이 다운 = 가까이 내려놓음, 든 사람이 나감 = 내려놓음. 흐름: 둘이 한 밭(팔라딘 클라이언트가 일구고 회복을 심고 물 줌, 약초사 호스트가 독초, `stage_ticks_base` 30: 클라이언트가 두 작물의 0..4단계를 편집으로 모두 봄, 약초사가 거둔 것은 상급, 팔라딘이 거둔 것은 일반, 인벤토리 = 호스트 사본, 월드 같음, 예측 보정 0), 팔라딘 클라이언트의 채널링(F → 예측에서 바로 시작, 호스트도, 다른 클라이언트가 그 채널링을 봄, 원판만 정화, 스폰 칸 줆, 두 클라이언트가 칸마다 깜빡임, 예측 보정 0, 그다음 서쪽으로 걸어가 성수), 호스트가 제단을 옮김(아처 클라이언트가 옛 빛 안에 서 있는 동안 이단은 베지 않음, 든 동안 클라이언트 월드에 제단·빛 없음·호스트의 머리 위 제단을 그림, 13칸 서쪽에 놓자 클라이언트의 빛·안전 반경·부활 자리·비워 두는 자리가 따라감, 이단이 와서 다운, 포기, 새 자리에 부활(예측과 같은 점)), 든 동안 죽은 사람은 기다림(호스트·예측 둘 다, 놓으면 새 자리), 늦은 참가(옮긴 뒤 = 시든 밭·옮긴 제단·그 빛·부활 자리, 든 동안 = 든 자리의 부활 자리에 나타나고 호스트의 머리 위 제단), 넷(3틱 지연: 호스트 독초, 팔라딘 채널링, 아처 일구기·심기, 광부 물주기, 모두의 월드·위치 같음, 예측 보정 0), 트래픽(위 "작물 상태 = 편집". M5-fix: 시험 밭을 `--test-field`처럼 기록 밖으로 넣지 않고 호스트 편집으로 넣어, 심은 뒤와 끝에 두 클라이언트 월드 = 호스트 월드). (M5-fix) 들기 규칙: 8칸 밖에서 F 130프레임 = 호스트 셈 0·손 닿는 곳의 ALTAR_LIFT 거부, 다운된 아처 옆 = 셈 0·거부, 클라이언트 `hold_altar`(혼자 1, 다운된 사람 옆 0, 채널링 중 0), `wants_channel`(오염 옆 = CHANNEL, 든 사람·제단 칸 = 아님, 옆 칸 = CHANNEL); 구역 옆으로 옮긴 제단(`test_altar_move.gd`의 `by_zone`): 맞음이 끊은 채널링을 호스트가 셈, 채널링 내내 F를 누르고 있어도 셈 ≤ 1·그동안의 ALTAR_LIFT 거부·채널링은 끝나 정화, 그 뒤 들기; 들고 있는 동안: 든 자리의 부활 자리 아홉 = 비워 둔 자리, 월드 규칙만으로는 되는 조제대가 `where players appear`로 거부, 규칙 밖으로 막은 자리는 `spawn_feet`가 건너뜀, 참가자는 설 수 있는 곳에, 클라이언트 월드가 마지막 자리를 기억하고 `Main.restore_altar_at`이 거기 되놓음(빛·안전 반경)
- `test_net_farm.gd` (실제 세션, `--test-crop-ticks=60`): `farm` — 호스트(약초사) + c1(팔라딘) + 늦은 c2(아처): c1이 (62,49)를 일구고 독초를 심어 보고(`herbalist only`) 회복을 심고 물 줌, 호스트가 M1 흙 (60,49)에 독초. 확인: 호스트 로그의 일구기·거부·심기·물주기·두 작물 익음, c1 로그에 두 작물의 값 여섯씩이 모두 편집으로(심음·젖음·1~4단계), 약초사 호스트가 거둔 c1의 작물 = 상급 둘 + 씨앗, c1이 거둔 호스트의 작물 = 일반 둘 + 씨앗, c1 인벤토리 = 호스트 사본, c2의 welcome에 작물 둘·일군 흙, 모두의 밭이 같음 + 세션 공통 검사. `farm4` — 호스트 + c1(아처) + c2(광부) + c3(팔라딘)을 하나씩 참가(자리 1·2·3에서 걷는 길이 제단을 돌아가게): 아처가 일구고 심음, 광부가 물 줌, 팔라딘이 채널링, 둘 다 익음, 모두 같은 밭·오염
- `test_net_purify.gd` (실제 세션): `purify` — 호스트(성직자) + c1(팔라딘): c1이 북쪽 구역 가장자리 (60,15)에서 F → 호스트 로그 `channel ... start`, `purify ... what=channel ... spawn_tiles=`가 678보다 작음(호스트가 스폰 고리가 줄어드는 것을 봄), c1이 원판 안으로 걸어가 성수(56,15), c1의 깜빡임 수 = 정화 칸 수, 오염 편집 수 같음, 거부 0. `altar` — 호스트(약초사, M1 흙에 시험 작물 넷) + c1(아처, HP 12) + 이단 하나(c1 남쪽 6칸, 빛 밖) + 늦은 c2: 호스트가 F 2초로 들어 13칸 서쪽에 놓음. 확인: 들기·놓기 로그, c1의 첫 `hurt`가 들기 뒤(빛 안에서는 안 맞음), c1이 새 자리 둘레의 자기 부활 자리에 부활(호스트 로그 `respawn slot=1 feet=`), c2의 welcome에 `altar=49,45`·작물 넷·시든 넷, 모두의 제단 자리·밭 같음, c1이 들기·놓기 편집을 봄
- 바꾼 기존 시험(M5c가 규칙을 일부러 바꿔서): `test_farming.gd`·`test_purify.gd`·`test_altar_move.gd`의 세션 시험이 "거부·꺼짐" 대신 호스트가 심고·일구고·붓고·채널링하고·드는지, `test_purify.gd`의 `same_as`가 이제 채널링을 봄(전송 형식에 있음), `test_altar_move.gd`의 든 사람 클릭이 `ALTAR_PLACE` 요청, `test_net_maps.gd` 버전 7
- 창 그림 검사 `fields_net`, 스모크 M5c 항목, 두 창 그림 `shots/m5c_host.png`·`m5c_client.png`

### 알려진 문제 (M5c)

- 심기·일구기·수확·정화·들기의 **결과는 왕복 뒤**에 보인다(동작은 바로). 심기는 동작이 없어 클릭과 작물 사이가 왕복만큼 빈다. 두 기기에서 사람이 볼 것
- 제단 들기의 진행(F를 누르는 2초)은 화면에 없다(M5b부터, 혼자 할 때도). 세션에서는 클라이언트가 세고 호스트도 따로 센다: 한 방향 지연이 크면 클라이언트가 120번째 프레임에 요청을 실어도 그 프레임까지는 같아서 거부되지 않지만, 프레임을 잃어 호스트가 F를 뗀 것으로 보면(F 누른 프레임은 확인될 때까지 다시 보내므로 잃지 않는다) 거부된다. 거부되면 다시 2초
- 제단을 든 클라이언트의 놓을 자리 표시는 이 기기의 월드·몸·이단으로 그린다: 호스트와 몇 틱 어긋난 이단이나 사람 때문에 금빛인데 거부될 수 있다(`request_refused ... altar_place ...`)
- (M5-fix에서 풂) 호스트(나 다른 클라이언트)가 제단을 든 채 호스트를 잃으면 혼자 계속하는 클라이언트의 월드에 제단이 없어, 죽으면 부활을 영영 기다리고 밭이 모두 시들었다. 이제 그 클라이언트가 마지막으로 본 자리(`GameWorld.last_altar_rect`: 들기 편집이 오면 떠난 자리를 기억)에 되놓는다(`Main._go_offline_combat` → `restore_altar`, 놓기 규칙으로: 안 되면 그 둘레, 임시값 "M5c 호스트를 잃었을 때 제단"). 든 동안 참가해 제단을 본 적이 없으면 자기 발 둘레에. 클라이언트가 든 채 호스트를 잃으면 혼자 할 때처럼 그 클라이언트가 놓는다(다운 때 내려놓기의 마지막 길도 그 자리. 전에는 그 길이 빈 자리라 제단이 사라졌다). 실제로 호스트를 죽여 보는 세션 시험은 없다(`drop`은 제단을 들지 않음): 한 프로세스 리그의 클라이언트 월드로 시험
- 농장의 시계(단계 안에서 자란 틱, 남은 물)는 호스트만 가진다. 호스트를 잃고 혼자 계속하면 새 농장으로 다시 센다(M5a의 "새 `Farm`은 단계의 처음부터")
- (M5-fix에서 풂) 제단을 처음 놓는 자리마다 모든 기기가 빛 텍스처 둘을 만들던 것(약 38ms): 한 쌍을 모든 자리가 같이 써서 놓는 순간 약 0.2ms(M5b 알려진 문제)
- 제단을 들거나 놓아 가득 찬 밭이 한 틱에 모두 시들거나 되살아나면 작물마다 편집 하나라 그 틱이 길다(검토가 잰 값: 작물 104개, 한 프로세스에 클라이언트 셋, 보통 틱 0.68ms → 약 51ms. 호스트 `apply_world_edit` 약 12~14ms, 클라이언트마다 `on_edit` 약 12~16ms, 편집 로그 줄의 월드 해시 104번 약 8ms). 기기마다로는 약 15~25ms 한 번이다. **그대로 둠**(M5-fix에서 거절): 편집 로그 줄의 `world=` 해시는 세션 시험이 편집 번호마다 같은 월드인지 보는 길이고(`test_net_session.gd`의 `cave`), 묶어 보내기는 전송 형식을 바꾼다
- 트래픽 통계(`NetSession._count_traffic`)는 채널링을 걷기·몸 동작으로 세지 않아 채널링하는 동안의 바이트가 "0/n"(아무도 안 움직임) 묶음에 섞인다(`purify`의 0/2가 426 B/s). 잰 값은 위 "측정"의 한 프로세스 값
- 실제 세션 시험의 봇은 틱 수(`wait`)와 `waitfield`로 서로를 맞춘다. 아주 느린 기계에서 어긋나면 시험이 실패로 알린다
- 전체 테스트가 약 370초가 됐다(새 파일 셋, 약 105초 더함)

## M7a: 작업대 체인 · 1티어 장비 · 내구도 · 공유 창고

혼자 할 때 먼저(M7a 지시, M5a·M6a처럼). **세션(`--host`/`--join`)에서는 새것이 꺼져 있거나 거부되고 M5c 흐름 그대로다**(M7c에서 켠다): 호스트가 작업대 셋·창고 놓기를 `workbench chain offline only`·`storage offline only`로, M7 레시피(작업대 체인과 수리)의 CRAFT를 `workbench chain offline only`로 거부하고, 세션의 플레이어는 `Player.gear_on`이 꺼져 있어 갑옷 클릭이 프레임을 만들지 않고 칼을 덜 받지 않으며, 1티어 무기는 호스트에서 기본 무기처럼 친다(보너스·마모 없음: `Arena.player_attack`에 피해를 넘기지 않음), 손 제작 창은 열리지 않는다. 전송 형식은 v7 그대로다(아이템 번호는 표 끝에 붙였고, 레시피 번호는 물약 여섯 뒤에 붙였고, 내구도는 인벤토리 전송에 아직 없다). 문서의 ●는 그대로 따랐다: 1티어 무기·방어구는 누구나 모루에서(● gameplay-design §3.5, §3.0 R11 룬마스터 줄 "누구나 모루에서 1~2티어 제작. 룬 슬롯 없음"), 사망 = 장착 장비는 유지하되 내구도 손상 + 일부 아이템 가방(● §2.6 R12, 가방 규칙은 M4a 그대로), 외형은 기본값만(● game-concept §12 R21: 장비가 모습을 바꾸지 않음), 작업대 체인은 2~3단계(● §12, 셋), 목재는 나무 한 종(● §12 R37: 나무와 도끼는 M7b라 통나무는 아직 `--give`로만). ○·?와 문서에 없는 것은 모두 [임시값](#임시값-사람-확인-필요) 표의 "M7a" 줄이다. 나무·도끼·벌목(M7b), 건설(벽·바닥·문·조명, ● R37 돌만), 세션(M7c), 상인(M8), 클래스 스킬(M9), 기도(M10), 컬렉션(M11), 보스·제단 업그레이드·광부 지형 요소(M12), 저장(M13), 룬 슬롯·인챈트·기술자 장치·3티어 이상, 오염 확산, 새 적, 장비의 새 모습은 M7a가 아니다.

### 작업대 체인 (`items/crafting.gd`, `Config.STATION_RECIPES`)

- **작업대 셋**: 기본 작업대(`WorldData.PLACEABLE_WORKBENCH`, 3×1, 04-env `workbench_v03`), 모루(`PLACEABLE_ANVIL`, 2×1, `anvil_v03`), 성물 제작대(`PLACEABLE_RELIC`, 3×1, `relic_bench_v03` + 공유 작은 불꽃 `flame_small_v01`). M6의 제작 틀 그대로다: `Crafting.STATION_OF`·`STATION_ICON`·`WorldItems.FOOTPRINT_OF`에 값을 더하고, 발 칸이 자리에서 2칸 안이면 Tab = 그 작업대의 창(가장 가까운 것, 같으면 자리 왼쪽 위 칸이 줄 순서로 앞인 것). 종류가 다른 작업대는 서로 붙여 놓을 수 있다(`footprint_at`이 값으로 자리를 나눈다). 놓기는 조제대와 같은 규칙(`WorldItems.place`: 아래 줄 가운데가 목표 칸, 빈 바닥, 아무 발도 덮지 않음, 사람이 나타나는 자리 아님, 같은 종류끼리 안 붙음)이고 던전에도 놓인다. 막는다. 다시 줍거나 부술 수 없다(조제대와 같음)
- **얻는 길**: 앞 작업대에서 만든다. 기본 작업대는 **손 레시피**(`Crafting.HAND`: 작업대 없이 Tab, 통나무 4)다. 작업대에서 멀리서 Tab을 누르면 손 레시피가 해금된 플레이어(통나무를 한 번이라도 가짐)에게는 손 제작 창(머리 = 통나무)과 인벤토리가, 아니면 M2a 그대로 인벤토리가 열린다(임시값 "M7a 기본 작업대 얻기"). 모두 `--give=workbench` 등으로도 받는다
- **레시피** (임시값 "M7a 작업대 체인", 누구나 만든다: ● §3.5 1티어는 누구나 모루에서, 체인의 나머지도 클래스 전용이 아님):

| 작업대 | 만드는 것 | 재료 |
|---|---|---|
| 손 | 기본 작업대 1 | 통나무 4 |
| 기본 작업대 | 널판 2 | 통나무 1 |
| 기본 작업대 | 모루 1 | 돌(`stone_a`, 캔 바위) 10, 철광석 2, 널판 2 |
| 기본 작업대 | 창고 상자 1 | 널판 8, 철 주괴 1 |
| 모루 | 구리 주괴 1 / 철 주괴 1 (제련) | 구리광석 1 / 철광석 1 |
| 모루 | 1티어 검 / 활 / 성광 / 곡괭이 / 낫 | 철 주괴 2 + 널판 1 / 널판 3 + 구리 주괴 1 / 구리 주괴 2 + 철 주괴 1 / 철 주괴 2 + 널판 2 / 철 주괴 1 + 구리 주괴 1 + 널판 1 |
| 모루 | 1티어 갑옷 1 | 철 주괴 3, 구리 주괴 1 |
| 모루 | 성물 제작대 1 | 널판 4, 구리 주괴 2, 철 주괴 1 |
| 모루 | 수리 (장비마다) | 철 주괴 1(검·곡괭이·갑옷) / 구리 주괴 1(활·성광·낫) |
| 성물 제작대 | 횃불 4 | 구리 주괴 1, 널판 1 |

- 제련은 모루에서 한다(화로가 문서에 없어서, 임시값 "M7a 제련"). 성물 제작대는 횃불 하나만 만든다: 슬라이스의 성물(기도 물품·제단 업그레이드·컬렉션)은 다른 단계라 셋째 작업대로 두고 최소 레시피를 줬다(임시값 "M7a 성물 제작대 레시피", 다른 길: 둘에서 멈춤)
- 해금(○ §3.5, M6a 그대로): 통나무를 가지면 손의 작업대와 작업대의 널판, 돌·철광석·널판을 가지면 모루, 주괴를 가지면 장비와 성물 제작대가 보인다. 그래서 체인이 한 단계씩 열린다(시험)
- 레시피 번호(CRAFT 요청의 번호, M6b)는 물약 여섯(0~5) 그대로이고 체인은 6부터, 수리는 끝이다
- 나뭇가지: 슬라이스에 나뭇가지 아이템이 없다(M2b 채집물에도 없고, 04-env `item_sticks_*`는 쓰지 않았다). 그래서 레시피는 통나무·널판·돌·광석·주괴만 쓴다
- **제작 창** (`ui/crafting_panel.gd`): 줄마다 그 레시피의 재료를 다(셋까지, 칸 사이 1px) 그리고 창 너비는 가장 긴 줄에 맞춘다(조제대는 60px 그대로, 재료 셋이면 98px). 수리 줄은 닳은 장비(막대 그대로) + 재료 → 가득 찬 장비. 화면에 안 들어가는 줄은 스크롤되고(고른 줄이 늘 보임) 위·아래에 더 있으면 창 가장자리에 금빛 1px 표시

### 1티어 장비 (`items/gear.gd`, `Config.GEAR_T1_*`, `ARMOR_*`)

- **무기**: 클래스 기본 무기마다 하나(`sword_t1`·`bow_t1`·`holy_light_t1`·`pickaxe_t1`·`sickle_t1`, 종류 TOOL). `Gear.base`가 기본 무기를 돌려주고 공격 모양·맞는 프레임·몸 동작·채굴·수확은 모두 기본 무기를 읽는다: 1티어 곡괭이는 곡괭이와 똑같이 캐고(같은 휘두르기 → 같은 월드, 시험), 1티어 낫은 작물을 겨누면 거둔다. 다른 것은 피해(`GEAR_T1_DAMAGE_PCT` 150%: 검 21, 활 18, 성광 15, 곡괭이 15, 낫 12)와 내구도. 혼자 할 때 Main이 그 칸의 묶음에서 피해를 구해 `Arena.player_attack`에 넘긴다. 누구나 어떤 무기든 쓴다(M4a 그대로). 아이콘은 기본 무기의 코드 아이콘 + 왼쪽 위 금빛 3×3 표시(자리 표시). 모습은 기본 무기 그대로(● R21: 동작 시트에 그려진 무기)
- **갑옷**: 한 벌(`armor_t1`, 새 종류 ARMOR). 인벤토리 칸이 아닌 **갑옷 칸 하나**(`Inventory.armor`). 핫바에서 고르고 좌클릭 = 입기(입던 것이 그 칸으로: 맞바꿈, 동작 없음), 인벤토리를 연 채 갑옷 칸 클릭 = 벗기(첫 빈 칸으로, 빈 칸이 없으면 거부). HUD에서 갑옷 칸은 핫바 왼쪽 6px 떨어져, 인벤토리가 열렸거나 갑옷을 입었을 때만 보인다(빈 칸은 옅은 갑옷 윤곽). 입고 있고 부서지지 않았으면 이단의 칼 한 번에 `ARMOR_T1_DEFENCE`(4)를 덜 받는다(12 → 8, `ARMOR_MIN_DAMAGE` 1 밑으로는 안 내려감, `Player.take_hit`의 `armored`). 독은 덜지 않는다(M6a: 독은 방어가 없음). 클래스 다섯 모두 같다

### 내구도 (● §2.6 R12, 수치는 임시값)

- 내구도가 있는 것은 **1티어 장비뿐**이다(`GEAR_DURABILITY`: 무기 120, 갑옷 100). 기본 도구·무기는 닳지 않는다(만드는 길이 없어서, 임시값 "M7a 내구도가 있는 것"). `ItemStack.durability`에 남은 값이 있고, 그런 아이템은 묶음 1이라 두 내구도가 섞이지 않는다. 새로 만든 것은 가득
- **사용 마모**: 무기는 맞는 프레임의 공격마다 1(맞든 빗나가든), 1티어 곡괭이의 채굴·1티어 낫의 수확은 닳지 않는다. 갑옷은 실제로 들어간 칼마다 1(무적 중이면 없음). 콘솔 `EVENSONG_GEAR broke item=sword_t1 who=LocalPlayer`
- **사망 마모**: 죽으면 지닌 내구도 있는 것 모두(입은 갑옷과 핫바·가방의 1티어 장비)가 제자리에 남고 최대치의 20%(올림: 무기 24, 갑옷 20)를 잃는다. 가방은 M4a 규칙 그대로이고 장비(도구·무기·갑옷)는 가방에 들어가지 않는다. 콘솔 `EVENSONG_GEAR death wear who=LocalPlayer items=3`
- **부서짐**(0): 쓸 수 있고 기본 아이템처럼 된다(`GEAR_BROKEN_UNUSABLE` 끔: 부서진 1티어 검 = 기본 검 14, 부서진 갑옷 = 방어 0). 켜면 부서진 것은 좌클릭해도 아무것도 하지 않는다
- **수리**: 모루의 수리 줄(장비마다 재료 하나)이 지닌 것 중 가장 닳은 하나(입은 갑옷 포함)를 가득 채운다. 닳은 것이 있을 때만 줄이 보이고, 없으면 `nothing to repair`(아무것도 안 바뀜). 문서의 수리는 기술자 일감인데 기술자가 슬라이스에 없어서 누구나 모루에서(임시값 "M7a 수리")
- **표시**: 핫바·인벤토리·창고·제작 창의 칸에 닳은 것만 14×2px 막대(칸 아래쪽, 반 넘으면 금빛, 4분의 1 넘으면 호박색, 그 밑은 녹빛, 부서지면 막대 전체가 녹빛). 코드 그림 자리 표시
- 드롭은 내구도를 싣지 않아서 닳은 장비는 F7로 버리지 못한다(`worn gear stays`)

### 공유 창고 (`items/storage.gd`, `ui/chest_panel.gd`, `WorldData.chests`)

- 창고 상자(`storage_chest`, 04-env `storage_chest_v02`, 3×1, 막음)는 조제대처럼 놓고, 자리 전체가 **제단 빛 안**이어야 한다(`CHEST_ONLY_IN_LIGHT`: 칸마다 네 모서리, 밭과 같은 `Farming.in_light`. 아니면 `outside the light`: 빛 밖, 반쯤 빛, 제단을 든 동안, 던전). 여러 개 놓을 수 있고 칸 16(`CHEST_SLOTS`)
- **내용물은 지도의 것**이다(`WorldData.chests`: 자리 왼쪽 위 칸 → 칸 16. 플레이어 것이 아님). 월드 해시는 무언가 든 창고만 덮어서(아이템·수·등급·내구도) 빈 창고나 창고 없는 월드의 해시는 그대로다(생성 해시 그대로). 늦은 참가 스냅샷은 아직 창고를 싣지 않는다(M7a 세션에는 창고가 없다, M7c)
- **열기**: 손 닿는 창고 칸을 겨누고 F = 창고 창(인벤토리 격자 위, 핫바 너비, 머리 = 창고 아이콘)과 인벤토리, 캐릭터는 서 있다(`ui_locked`). 인벤토리 칸 클릭 = 그 묶음 넣기, 창고 칸 클릭 = 꺼내기. 같은 아이템·등급 묶음을 먼저 채우고 그다음 빈 칸, 들어가는 만큼만 옮기고 나머지는 제자리(일부 옮김), 하나도 안 들어가면 `chest full`·`inventory full`(아무것도 안 바뀜). 내구도·등급은 그대로 간다. Tab·Esc·F = 닫기, 다운·지도 옮김·창고가 없어지면 닫힘(`Storage.still_at`). 콘솔 `EVENSONG_CHEST open at=62,51 items=...`, `EVENSONG_CHEST store item=stone_a count=40 left=0`, `EVENSONG_CHEST take refused: inventory full`
- **제단을 옮기면**: 창고는 그 자리에 남고 내용물도 그대로이며 계속 열린다(빛 밖이어도). 새 창고는 새 빛 안에만 놓인다. 제단은 창고 위에 놓이지 않고(`not open ground`), 부활 자리 아홉이 창고에 막히는 자리도 거부된다(`no room around it`, M5b 규칙 그대로). 창고는 사람이 나타나는 자리를 덮지 못한다(M6-fix 규칙 그대로)

### 키 (임시값 "M7a" 줄)

- 작업대 셋 = M6a의 Tab(창), 손 제작 창 = 작업대가 없는 곳의 Tab(해금 뒤), 갑옷 = 고르고 좌클릭 / 갑옷 칸 클릭, 창고 = F, 창고 창에서 칸 클릭, Tab·Esc·F 닫기

### 시험 (M7a)

```bash
timeout 300 "$GODOT" --headless --path game --script res://tests/run_all.gd -- --only=workbench,gear,storage < /dev/null   # 약 3초
```

- `test_workbench.gd`: 레시피 열넷(작업대·재료·수·출력, 누구나, M7 레시피), 체인(작업대마다 앞 작업대에서, 손의 작업대), 레시피 번호(물약 그대로, 체인은 6부터), 해금 단계(빈 인벤토리 → 통나무 → 널판·돌·철광석 → 철 주괴 → 구리 주괴, 없어져도 남음), 모든 레시피가 모두 아니면 하나도 아님(재료 그대로면 만들고 재료 모두 씀·다른 것 그대로·새 장비는 가득, 재료마다 하나 모자라면 `missing inputs`·그대로, 가득 찬 인벤토리면 `no room`·그대로, 한 번도 없던 재료면 `locked`), 제련(구리 열 번, 열한 번째 거부, 1 : 1), 손 닿음(작업대 셋의 자리 크기마다 20×14칸 전부를 따로 적은 체비셰프와 비교, 한 줄의 셋: 가장 가까운 것·같으면 앞의 것·종류로 찾기, 손 작업대), 놓기(셋마다: 아래 줄 가운데, 편집 수, 같은 종류 붙음 거부, 제단·채집물·작물·드롭·발 거부, 마른 흙은 됨, 부활 자리 아홉을 덮는 모든 자리 거부, 던전에 모루), 그림(자리 아래 변, 가운데, 그림에서 잰 맨 아래 줄, 성물 제작대 불꽃 자리·unshaded·5프레임, `verify` 0), `main.tscn`(통나무 없을 때 Tab = 인벤토리, 통나무를 가지면 손 창 → 작업대 → 클릭으로 놓기 → 널판·모루 → 놓기 → 제련·1티어 검·성물 제작대 → 놓기 → 횃불, 셋이 한 줄), 세션(작업대 셋·창고 놓기 거부와 편집 0, 데이터에 놓은 모루 옆 제련 CRAFT 거부·광석 그대로), 결정성(같은 체인 두 번 = 같은 단계·인벤토리·월드 해시)
- `test_gear.gd`: 클래스 다섯의 기본·1티어 무기(같은 공격·맞는 프레임, 피해 14/21·12/18·10/15·10/15·8/12를 따로 적어 비교, 기본 도구는 내구도 없음), 아레나에서 클래스마다 두 무기의 실제 피해(근접은 바로, 화살·빛 탄은 날아가 맞을 때), 피해를 넘기지 않으면 기본 피해(세션), 1티어 곡괭이 = 채굴·1티어 낫 = 수확, 갑옷(클래스 다섯: 검은 아님·빈 칸·입기·맞바꿈·벗기·없음·가방 칸에서는 안 됨·가득 차면 못 벗음), 방어(클래스 다섯: 12 / 8과 마모 1, 무적이면 아무것도, 부서진 갑옷 12·마모 없음, `gear_on` 끔 12, 최소 1, 아레나의 칼 8, 독은 그대로·마모 없음), 사용 마모(다섯 번 115, 기본 검 안 닳음, 다른 아이템 안 닳음, 0에서 멈춤, 사본·생성의 내구도), 사망 마모(넷이 닳고 부서진 것은 그대로, 120 → 96, 10 → 0, 갑옷 100 → 80, 가방 칸 예비 갑옷 60 → 40, 가방은 장비를 안 가져감, 돌은 절반), 수리(재료 하나, 가장 닳은 것, 둘째, 닳은 것이 없으면 줄 없음·거부·그대로, 재료 없음, 부서진 갑옷, 본 적 없으면 잠김), 부서짐(기본 피해, 여전히 휘두름, 방어 0, 1이면 방어 그대로, 닳은 장비 F7 거부·새것은 됨), `main.tscn`(클래스 다섯이 1티어 무기로 이단에게 1티어 피해·마모 1, 빗나간 공격도 1, 갑옷 클릭으로 입기·동작 없음, 갑옷 칸 클릭으로 벗기, 죽음: 갑옷 80·검 96·돌 절반), 던전 `main.tscn` 두 번(곡괭이와 1티어 곡괭이가 같은 벽을 깨면 같은 월드, 채굴은 안 닳음), 세션(1티어 검이 14, 안 닳음, 호스트 플레이어의 갑옷은 덜지 않음), 결정성(갑옷 입은 600틱 싸움 두 번이 25틱마다 같음)
- `test_storage.gd`: 놓기(빛 안 됨·3×1·편집 셋·막음, 제단 둘레 21×21 목표 칸 전부: 따로 적은 "네 모서리가 반경 안"이 아니면 하나도 안 놓임, 반쯤 빛, 제단을 든 동안, 던전, 부활 자리, 작물·젖은 흙·제단·발·다른 창고 거부, 모루와 붙는 것은 됨, 작업대가 아님), 옮기기(가득 찬 묶음 통째로, 등급 따로, 닳은 검의 내구도, 빈 칸, 합치기, 꺼내기·내구도, 가득 찬 창고 거부·그대로, 일부 넣기 30·69 남음, 일부 꺼내기 20·79 남음, 가득 찬 인벤토리 거부, 칸 하나에 장비 하나, 창고 없음), 월드(생성 해시 = 골든, 자리의 모든 칸이 한 창고, 빈 창고는 해시에 아무것도, 내용물·수·내구도는 해시에, 같은 내용물 = 같은 해시, 둘째 창고는 따로), 제단 옮기기(창고·내용물이 남고 빛 밖에서도 열림, 옛 빛에 새 창고 거부·새 빛은 됨, 제단은 창고 위에 안 놓임, 바로 북쪽은 부활 자리가 막힐 때만 거부, 다운 때 저절로 놓기도 창고를 피함), `main.tscn`(클릭으로 놓기·그림, F로 열기·인벤토리·서 있음, 인벤토리 칸 클릭으로 넣기·닳은 검, 창고 칸 클릭으로 꺼내기, 창 밖 클릭 없음, 창이 인벤토리 격자 위·화면 안, 열린 동안 못 걸음, Tab 닫기, F로 다시 열고 닫기, 다운이면 닫힘, 내용물은 지도의 것), 결정성
- 바꾼 기존 시험(M7a가 일부러 바꿔서): `test_items.gd`(아이템 48개, 종류별 수 12/7/15/6/3/3/1/1, M7 아이템의 종류·아이콘·내구도·기본 무기, 성수 번호 33 그대로, 한 동작에 기본 도구 하나), `test_crafting.gd`(레시피 수 = 물약 6 + 체인 + 수리, 조제대에는 물약 여섯만), `test_actors.gd`(그림 출처 9개 더함, 96), 스모크(도구 12, 조제대 레시피 6, M7a 항목). 창 그림 검사 `stations`·`gear_hud`·`m7_panels`

### 알려진 문제·자리 표시 (M7a)

- 자리 표시(임시값 "M7a 그림 자리 표시"): 작업대·창고 아이콘은 놓은 그림을 16×16으로 줄인 것(점 몇 개가 빠진다), 1티어 무기 아이콘은 기본 무기 아이콘 + 금빛 표시, 갑옷 아이콘·갑옷 칸·내구도 막대·창고 창은 코드 그림. 성물 제작대의 촛불은 불꽃만 있고 빛(PointLight)은 없다
- 놓은 작업대·창고는 다시 줍거나 부술 수 없다(조제대와 같음). 잘못 놓으면 그대로다
- 창고 내용물은 늦은 참가 스냅샷·편집 기록에 아직 없다(세션에 창고가 없는 M7a에서는 문제가 아님. M7c가 싣는다). 그래서 무언가 든 창고가 있는 월드는 스냅샷 왕복 해시가 다르다
- 내구도는 인벤토리 전송에 없다: 호스트를 잃고 혼자 계속하는 클라이언트의 1티어 장비는 가득 찬 채 시작한다
- 창고 창의 넣기·꺼내기는 마우스 클릭과 봇(`store`·`take`)뿐이고 키보드로 칸을 고르는 길은 없다
- 손 제작 창은 Tab 한 번에 열려서, 통나무를 가진 뒤로는 작업대 없는 곳의 Tab이 인벤토리만 여는 일이 없다(창과 인벤토리가 같이 열림, Tab 한 번 더 = 둘 다 닫음)
- 기본 작업대를 만드는 데 통나무가 필요한데 나무는 M7b라, 지금은 `--give=log:<n>`로만 체인을 시작한다

## 빛과 제단 (G2)

- **규칙은 하나**: `SafeZone.is_in_safe_zone(pos)` = 제단 가운데에서 반경(임시 7타일 = 112px) 안 (경계 포함). 게임 로직은 `GameWorld.is_in_safe_zone()`로 이것을 부르고, 빛 텍스처는 같은 함수를 텍셀 가운데마다 불러 만든다
- `AltarLight` = `PointLight2D` 두 개, 제단 가운데(정수 픽셀), `texture_scale` 1(텍셀 하나 = 월드 픽셀 하나):
  - `GroundLight`: 디더 테두리. 반경 − 16px까지 꽉 차고, 그 띠에서 월드 좌표에 고정된 4×4 Bayer 무늬로 사라진다. 켜진 텍셀은 모두 안전 반경 안이다. 빛 레이어 1(바닥 청크, 제단)만 비춘다
  - `ActorLight`: 같은 반경의 hard 테두리 사본. 빛 레이어 2(캐릭터 스프라이트)만 비춘다. 경계 위 캐릭터 얼굴에 체커보드가 생기지 않는다(스파이크 RESULTS §4)
  - 텍스처는 영역 모양마다 한 번 만들어 static 캐시에 붙잡아 둔다(226×226, GDScript 약 26ms. M5-fix: 열쇠 = 테두리·띠·반경과 가운데의 4px 위상·소수부, `AltarLight.cache_key`: 그림이 가운데에 그만큼만 달려서 제단이 어디 있든 한 쌍). 4.7.2에서 `PointLight2D.texture`를 바꾸며 옛 텍스처가 풀리면 엔진 오류 줄이 나서(스파이크) 한 번 만든 텍스처는 놓지 않는다. 같은 월드를 다시 만들거나 F4로 껐다 켜도 텍스처는 그대로다(테스트)
- 저녁: `CanvasModulate` 따뜻한 회색(임시). 빛 안은 저녁 + 빛 ≈ 그린 색(약 1.05 / 0.97 / 0.90배), 밖은 저녁색 그대로. F4·`--no-evening`은 저녁과 제단 빛을 **같이** 끈다(빛만 남기면 빛 안이 하얗게 뜬다). 낮밤 순환은 만들지 않았다(? 지상의 빛 미정)
- 제단(`Altar`, world/altar.gd): 그림 `altar_v04.png`(48×57, 불투명 x 0~46, y 5~47)의 왼쪽 위를 자리 3×3의 왼쪽 위에 둔다. 그림의 맨 아래 외곽선 줄이 자리의 마지막 픽셀 줄에 온다. 노드는 자리 바닥 가운데라 y 정렬에서 발이 자리 아래 변보다 아래(남쪽)인 캐릭터는 제단 앞, 위인 캐릭터는 제단 뒤에 그려진다
- 불꽃: `altar_v04.png`와 `altar_v04_unlit.png`가 다르고 밝기 148 이상인 픽셀 = 81개(등잔 9 × 9). 같은 자리에 unshaded로 한 번 더 그려서 저녁에도 원본 색 그대로다(창 검사에서 채널 차 0). brief §5.7은 불꽃을 손으로 그려 빛 마스크와 함께 두라고 하는데 그 그림이 아직 없어서 켜짐·꺼짐 차이로 만든다
- 디버그 선(F3)도 unshaded라 저녁에 어두워지지 않는다
- **M5b**: 제단이 옮겨지면(위 "M5b") `GameWorld._altar_moved`가 안전 반경을 새로 만들고 제단 노드와 `AltarLight`를 새 가운데에 다시 놓는다(텍스처는 `texture_for` 캐시: M5-fix부터 모든 자리가 같은 한 쌍을 씀(전에는 처음 가는 자리마다 둘을 새로 만들었다). 저녁이 꺼져 있으면 꺼진 채). 들고 있는 동안은 제단·빛·안전 반경이 없다(`SafeZone.for_world` 반지름 0). 디버그 선도 새 자리를 그린다

## 네트워크 (G3)

● 호스트 권한 협동 (game-concept §13), 2인부터, 구조는 ● 9인 (`Config.MAX_PLAYERS`). Godot 내장 고수준 멀티플레이(SceneMultiplayer RPC) 위에 직접 짰다. `MultiplayerSpawner`·`MultiplayerSynchronizer`는 쓰지 않는다 (스파이크 RESULTS §5: always는 서 있어도 보내고 on_change는 걸을 때 더 비싸다).

- **노드 하나**: `main.tscn`의 `Net`(`NetSession`)이 모든 RPC를 받는다. 모든 기기에서 경로가 같다(`/root/Main/Net`). 혼자 할 때(`--host`/`--join` 없음)는 아무것도 하지 않는다
- **전송 계층**(`NetTransport`): `configure(options)` 뒤 `host(api)` / `join(api)`. 결과는 시그널(`opened` / `open_failed(이유)`)로, 호출 안이 아니라 나중에 한 번. ENet(`EnetTransport`)이 지금 쓰는 것, `SteamTransport`는 GodotSteam이 없으면(지금) "unavailable"로 실패하는 자리다. 실제 Steam 로비 흐름은 M1이 아니다. 클라이언트끼리는 통하지 않는다(`server_relay = false`, Steam 기본과 같음)
- **접속**: 클라이언트가 hello(프로토콜 버전, 클래스)를 보내면 호스트가 `Roster`로 받거나 거부한다. 거부 이유: `full`(인원 상한), `version`, `class`(슬라이스 클래스가 아님), `class_taken`(같은 클래스 금지일 때만, 지금은 꺼짐). **상한은 전송이 아니라 호스트가 센다** (ENet은 연결을 16개까지 받아서 열 번째에게 이유를 말해 줄 수 있다. Steam peer에는 상한 인자가 없다). 받으면 가장 작은 빈 스폰 자리(나간 사람 자리를 다시 씀), 거부하면 이유를 보내고 클라이언트가 스스로 끊는다(호스트가 바로 끊으면 ENet이 보낼 메시지를 버린다. 2초 지나도 남아 있으면 호스트가 끊는다). hello 없이 5초 있는 연결도 끊는다
- **늦은 참가 = 월드 스냅샷** (H1, game-concept §13 ○ "늦은 참가 스냅샷 스트리밍"): 호스트는 참가자를 받는 순간의 월드(`WorldData` 레이어 6장 전부 + 크기·시드·제단 자리)를 `WorldSnapshot`으로 묶어 zstd로 압축하고, 1KB(`NET_SNAPSHOT_CHUNK_BYTES`) 조각으로 잘라 틱마다 최대 8개(`NET_SNAPSHOT_CHUNKS_PER_TICK`, 틱당 8KB = 480KB/s)씩 reliable 채널 0으로 보낸다. 마지막 조각을 보낸 그 틱에 welcome(자리, 지금의 플레이어들, 스냅샷의 편집 기록 위치, 원본·압축 크기, 조각 수, 압축 바이트 md5, 월드 md5, 진단용 생성기 해시. 시드는 스냅샷 머리말에만 있다)을 보내고, 스냅샷 뒤에 생긴 편집을 번호와 함께 이어서 보낸다. 그때부터 그 참가자는 묶음·편집·출입·go를 받는다(그 전에는 받지 않아서, 채널 0 하나의 순서대로 "월드 → welcome → 나머지"가 된다). 클라이언트는 조각을 순서대로 모으고(순서가 틀리거나 1KB를 넘거나 상한을 넘으면 끊음), welcome에서 조각 수·크기·md5를 맞춰 본 뒤 풀어서 월드를 만들고 그 `content_hash()`가 호스트의 월드 md5와 같은지 확인하고(다르면 종료 코드 5) 그 월드를 그린다(`GameWorld.load_data`). **자기 생성기로 만들지 않는다.** 시드와 생성기 해시는 진단뿐이다: 자기 생성기로 스냅샷 머리말의 시드로 월드를 만들어 호스트 생성기 해시와 비교해 `generator=match|differs`를 찍는다(실패 아님. 결과 JSON의 클라이언트 `generator_hash`는 welcome 전에는 빈 값). M1 월드 128×96 = 73,749B → 341~342B, 조각 1개. 받는 쪽 크기 상한(H-fix): 한 변 `MAX_SIDE` 512칸(M1 맵 가로의 4배), 압축 바이트 `MAX_PACKED` 약 1.6MB. 압축이 전혀 안 되는 최대 월드도 틱당 8KB로 약 3.3초라 접속 제한 10초 안에 다 오고 `load_data`가 1초 안쪽이다(예전 2048은 약 25MB라 받을 수 없는 크기까지 받아 주었다). 접속 제한에 걸렸는데 조각이 오고 있었으면 이유가 `not admitted`가 아니라 `world not complete within 10 s (<조각> chunks, <바이트> B so far)`다 편집은 "칸 = 값" 절대값이라 두 번 적용해도 같다. M1에는 게임 편집이 없어서 호스트의 디버그 편집(봇 `edit:`, 풀 ↔ 흙만)으로 길을 시험한다
- **이동은 호스트가 정한다**: 클라이언트는 입력 프레임(번호, 8방향)만 보낸다. **바라보기는 보내지 않는다** (H1): 호스트가 방향에서 클라이언트와 같은 규칙(`Movement.facing_for`, `Player.apply_input`)으로 정한다. 프레임 하나 = 1바이트(코드 0..8, 9 이상은 버림). **M2b에서 바뀜**: 조준 중에는 마우스 쪽 바라보기(look)를 프레임 코드에 실어 보낸다(코드 0..44, 아래 "M2b"의 "요청"). look이 없는 프레임의 바라보기는 지금도 호스트가 방향에서 정한다. 클라이언트 예측은 호스트가 이 프레임 뒤에 정할 바라보기를 미리 계산해 두고, 호스트 상태와 다르면 `facing_corrections`로 센다(테스트에서 늘 0). 움직이는 동안과 멈춘 첫 틱에만 프레임이 생기고(서 있으면 아무것도 안 보냄), 2틱마다(30Hz) 호스트가 아직 확인하지 않은 프레임을 전부 다시 담아 unreliable로 보낸다(패킷 하나를 잃어도 다음 패킷에 들어 있다). 호스트(`InputGate`)는 번호 순서대로 한 번씩만, 축마다 −1..1로, **실제로 흐른 시간** 한 틱마다 토큰 하나(최대 30개 모아 둠)만큼만 적용해서 실제 시간보다 빨리 걸을 수 없다. 받은 프레임은 틱마다 하나씩(3개 넘게 밀리면 더, 단 틱당 최대 4개 `NET_INPUT_CATCH_UP_FRAMES`, H-fix) 적용해서 다른 사람 눈에 고르게 걷고, 밀렸을 때는 걷는 속도의 4배까지로 따라잡는다(한 번에 뛰지 않음). 호스트 자신의 캐릭터는 키를 바로 적용한다
- **호스트가 멈췄다 돌아올 때** (H1, H-fix에서 고침): 토큰은 `take()` 횟수가 아니라 실제 시간(호스트 틱 사이 `Time.get_ticks_usec`, `InputGate.ticks_between`)으로 채운다. 긴 프레임으로 틱을 놓치면 그 시간만큼(한 번에 최대 64틱) 채우고, 기다리는 프레임 수만큼은 모아 두는 상한(30)을 넘어도 된다(그 프레임들은 정말 그만큼 오래된 것이라). **그런데 Godot은 한 프레임에서 물리 틱(따라잡기 틱 포함)을 먼저 돌리고 네트워크는 그 뒤 process 단계에서 읽는다**(`SceneTree.process`의 multiplayer poll). 그래서 멈춤이 물리 틱 밖(그리기, `_process`, RPC 처리, 운영체제)에서 났으면, 놓친 시간을 재는 첫 따라잡기 틱에는 멈춘 동안 온 프레임이 아직 대기열에 없고, 상한이 채울 시간을 버렸다. 프레임은 그다음 poll에 한꺼번에 들어와 걷는 동안 내내 약 30프레임(0.5초) 뒤처졌다(H1 검토가 실제 세션에서 찾음. H1의 단위 시험은 프레임을 따라잡기 틱 전에 넣어서 물리 틱 안의 멈춤만 흉내 냈다). H-fix: 놓친 틱의 채움 중 상한이 자른 몫을 **멈춤 크레딧**(`hitch_credit`)으로 실제 시간 30틱(`InputGate.HITCH_CREDIT_TICKS`, 0.5초) 동안 들고 있다가, 그동안 들어와 상한 위에서 기다리는 프레임에 쓴다. 크레딧은 더해지지 않고 더 큰 멈춤이 바꿔 넣으며(30fps 호스트에서 서 있는 클라이언트가 모을 수 있는 크레딧은 1틱), 토큰은 여전히 실제 시간에서만(바로, 또는 크레딧으로 조금 늦게, 한 번만) 나오므로 "실제 시간 + 30프레임보다 빨리 못 걷는다"는 그대로다. 멈춘 동안 서 있다가 몰아 보내는 클라이언트도 멈춘 시간만큼만 더 간다(단위 시험). 결과: 실제 세션(`stall`: 0.7초 멈춤, 대기열 최고 42프레임)에서 속도 제한에 걸린 틱이 194~204 → 0, 크레딧 약 39틱 사용. 단위 모형(1초 멈춤)은 두 순서 모두 30틱 뒤 대기열 4 이하, 제한 0. 크레딧 없이(H1 규칙) 돌리면 틱 밖 순서에서 대기열 31, 제한 409틱으로 시험이 실패한다
  - 한계: 멈춤이 약 1초(64틱)를 넘으면 대기열 상한 64를 넘는 프레임은 버린다(`overflow`). 클라이언트는 확인 안 된 프레임 중 새 32개만 다시 보내므로, 더 길게 멈추면 버린 프레임이 다시 오지 않아 빈 번호가 생기고 그 클라이언트의 자기 캐릭터가 한 번 크게 보정된다(아래 측정의 모형 값). M1에서 호스트가 1초 넘게 멈출 일은 없다고 보고 두었다
- **묶음 상태**(`StateBroadcast`): 호스트는 3틱마다(20Hz, 임시값) 모든 플레이어의 상태(자리, float32 위치 그대로, 바라보기, 걷기, 확인한 마지막 프레임 번호)를 한 패킷(5 + 14B × 인원, M2b부터 16B: 동작·든 아이템)에 담아, **바뀐 것이 있을 때만** unreliable로 보낸다. 바뀐 것이 없어지면 같은 상태를 reliable 키프레임으로 한 번 더 보내고(마지막 묶음을 잃어도 맞게), 그다음에는 누가 다시 움직일 때까지 아무것도 보내지 않는다. 남는 것은 ENet 자체의 유지 패킷(클라이언트 하나당 초당 약 5개)뿐이다
- **자기 캐릭터 예측**(`Prediction`): 클라이언트는 입력을 그 틱에 바로 같은 `Movement.step`으로 적용한다(왕복을 기다리지 않음). 호스트 상태가 오면 "프레임 n까지 처리한 위치"에서 시작해 아직 확인 안 된 프레임을 다시 돌린다. 같은 코드·같은 float32·같은 순서라 다시 돌린 결과가 예측과 같다: 테스트에서 오차는 늘 0.0px (지연 120ms + 손실 15% 흉내에서도). 호스트와 다르면(프레임을 못 받았거나 호스트가 옮겼거나) 호스트가 이기고 오차로 센다
- **남의 캐릭터 보간**(`Interpolation`): 호스트 틱 번호가 찍힌 상태를 모아 두고 100ms(임시값, 묶음 2개) 뒤를 선형으로 그린다. 마지막 상태 뒤는 앞질러 추측하지 않고 멈춘다. 조용하던 사람이 다시 움직이면 직전 상태를 한 간격 앞에 다시 넣어 조용했던 동안 미끄러지지 않게 한다. 호스트 틱은 묶음 도착 시각에서 가장 덜 늦은 값으로 추정한다(`RemoteClock`)
- **채널**: 0 reliable (hello, 월드 조각, welcome, 거부, 들어옴·나감, 편집, 키프레임, M2b 인벤토리, M3b 지도 들어옴, M4b 적 키프레임·화살 사건(M6b: 던진 병의 던짐·터짐도 같은 메시지), 테스트용 go/done/finish), 1 unreliable ordered (입력), 2 unreliable ordered (상태), 3 unreliable ordered (M4b 적 묶음: 상태와 다른 채널이라 서로를 밀어내지 않는다). 클라이언트가 부를 수 있는 RPC는 hello·입력·done 셋뿐이고 나머지는 호스트만(authority) 부를 수 있다 (`test_net.gd`가 RPC 표를 확인)
- **파일** (H1): `session.gd`(753줄)를 흐름별로 나눴다. `session.gd`(427줄, 그중 RPC 받기·보내기가 절반)는 두 역할이 같이 쓰는 상태(플레이어, 편집 기록, 전송, 끝내기, 로그)와 RPC 표만 가진다. 각 `@rpc` 받는 함수는 역할을 보고 흐름에 넘기기만 하고, 흐름은 `send_*`로 보낸다. 호스트 흐름 `session_host.gd`(285줄), 클라이언트 흐름 `session_client.gd`(246줄), 봇·테스트 흐름 `session_bots.gd`(155줄). 동작은 그대로다(같은 세션 테스트가 통과). H-fix 뒤 445 / 295 / 253 / 155줄 (테스트 멈춤, 스트림 기록, 접속 제한 이유)
- **ENet 패킷 조절(throttle)을 끔** (H-fix, `Config.NET_ENET_THROTTLE` = (5000, 2, 0), `EnetTransport`가 연결마다 `throttle_configure`): ENet은 reliable 메시지의 확인 왕복 시간이 지난 주기의 최소 + 변동 2배보다 길 때마다 연결의 조절 값을 낮추고, 낮은 값만큼 unreliable 패킷(우리 상태 묶음)을 버리고 reliable 창도 줄인다. 두 쪽이 60Hz로 네트워크를 읽으면 왕복 시간이 프레임 단위(localhost에서 약 16 / 33ms)로 뛰고 두 프로세스의 프레임 위상에 따라 흘러서, reliable 메시지가 잦으면(호스트가 4틱마다 편집) 조절 값이 약 1.5초 만에 0이 되어 걷는 클라이언트가 몇 초 동안 상태 묶음을 하나도 못 받았다(`stall` 세션이 가끔 실패해서 찾음: 걷는 4초 동안 확인 5번, 확인 안 된 프레임 128개 넘김. 계측해 보니 조절 값 32 → 0). 감속 0이면 낮아지지 않는다: 같은 흉내 6번에서 조절 값 653번 재어 모두 32(전에는 6번 중 5번 32 밑으로, 1번은 0까지). M1 트래픽은 9인 걸을 때도 약 23 KB/s라 혼잡 제어를 잃는 값이 작다고 봤다. 실제 인터넷에서 혼잡할 때 덜 버리는 대신 늦어질 수 있다(두 기기 시험에서 볼 것)
- **나감**: 호스트는 그 자리를 비우고 남은 사람에게 알린다. 클라이언트가 호스트를 잃으면: 테스트 인스턴스(`--net-out`)는 종료 코드 4, 사람이 띄운 것은 다른 플레이어를 지우고 혼자 계속 걷는다
- 전송 형식은 모두 `PackedByteArray` 하나에 직접 쓴다(`NetProtocol`, 버전 2, M2b부터 3). 디코더는 크기·범위를 먼저 보고 틀리면 버리고 센다(엔진 오류 없이). 스냅샷은 zstd다: Godot의 zstd 풀기는 잘못된 입력에 빈 배열을 돌려주지만 deflate는 엔진 오류 줄을 낸다
- 트래픽 통계(`NetStats`)는 "걷는 사람/전체" 묶음별이고, 호스트가 참가자에게 월드를 보내는 틱(과 그 뒤 두 틱)은 따로 "joining" 묶음에 넣는다(참가 비용이 서 있을 때 트래픽에 섞이지 않게). 다만 늦은 참가자의 ENet 연결 인사(호스트가 그 peer를 알기 전, 약 135B·패킷 3개)는 그때의 묶음에 들어간다(H-fix에서 잼: 둘이 서 있기만 하는 세션에 참가자를 하나 붙이면 0/2 묶음이 패킷 3개·약 135B 는다). pair의 0/2 구간(약 1.45초)에 이것이 떨어지면 0/2가 약 110 → 약 195~225 B/s가 된다(아래 측정)

### 테스트가 확인하는 것 (`test_net_session.gd`)

모든 인스턴스가 끝에 결과 JSON을 쓴다. 호스트와 비교하는 것: **위치 해시**(플레이어마다 자리·클래스·float32 위치 그대로·바라보기의 md5), **월드 해시**, **바닥 그림 해시**(`GroundView.view_hash`, H1), 플레이어 수. 그 밖에 바닥 그림 = 데이터(`GroundView.verify`), 모든 참가자가 월드를 스냅샷으로 받음(호스트가 보낸 스냅샷 수 ≥ 참가자 수), 클라이언트 예측 오차 ≤ 0.5px(실제로는 0.0)와 바라보기 보정 0(H1), 확인 안 된 프레임 0, 늦은 참가자: 편집 기록 위치(M1 1, M2b부터 pair·four 모두 3), 호스트의 편집된 월드(시드만의 월드와 다름), welcome에 호스트 생성기 해시, 생성기 진단(pair의 흔든 생성기는 `differs`, 나머지는 `match`), 참가 시간, `four`의 32바이트 조각(M1 11개, M2b 18개), 나간 자리를 늦은 참가자가 받음, 거부 이유 `full`, 잘못된 메시지 0, 호스트 입력 검사의 빈 번호·잘못된 패킷 0, 조용함(아무도 12틱 넘게 안 움직였는데 보낸 묶음 0), 헤드리스 자식의 틱이 실제 시간을 따라감(테스트 멈춤 시간은 빼고), 종료 코드, 자식 로그에 `ERROR:` 0, 남은 프로세스 0.
M2b에서 더한 것: 아이템 그림 = 데이터(`items_view`, 모든 인스턴스), 클라이언트의 동작 보정 0, 남은 채집물 수와 드롭 목록이 호스트와 같음, `pair`: 모두가 보는 각자의 든 아이템(호스트 = 돌, c1 = 요청해서 받은 검), 호스트가 돌린 c1의 검 동작 수 = c1이 예측한 수, c1이 본 호스트 곡괭이 동작 수 = 호스트의 수(3), 호스트가 주운 약초(일반)와 버린 돌이 c1에 실시간 편집으로 감, 늦은 참가자의 스냅샷에 줍힌 약초가 없고 드롭이 있음(welcome `gatherables=73 drops=1`), 그 참가자가 드롭을 줍고 약초를 상급으로 캠, 클라이언트 인벤토리 = 호스트의 사본, 거부된 요청 0, `four`: 버린 돌 5개를 정확히 한 클라이언트가 가짐(호스트 로그의 줍기 한 줄, 그 클라이언트의 인벤토리), 마구 누른 F가 `rate`와 `nothing there`로 거부됨, 늦은 참가자 스냅샷의 편집 위치 3, `stall`: 스트림 도중의 드롭 6개가 c1·c2에 호스트와 같은 목록으로 있음(그중 일부는 welcome 뒤 편집으로).
M2-fix에서 더한 것: `pair`의 c1이 매 프레임 고른 핫바 3번을 호스트가 모두 처리함(`ops` done select 3, 거부 0), 서서 조준만 한 c1이 호스트·c1·c2 모두에서 남쪽을 봄(바라보기만 바뀐 프레임을 기록하지 않게 깨면 셋 다 서쪽으로 남아 실패).
M4b에서 더한 것: 예측 오차·바라보기·동작 보정은 호스트 사건(맞음·소생)을 뺀 것이고(`Prediction.event_corrections`로 따로), 결과 JSON에 `combat`(호스트: 지도마다 적 그림 해시·이단 수·제단 HP·아레나 통계·묶음 수, 멤버마다 맞음·다운·사망·소생·처치·호스트가 직접 진행한 틱. 클라이언트: 받은 적·화살 메시지를 지도별로, 이단마다 본 HP 순서, 마지막 적 그림 해시), 플레이어마다 HP와 삶. 세션이 끝나려면 적 묶음도 조용해야 한다(`SessionHost.combat_quiet`).
M6b에서 더한 것: 결과 JSON의 클라이언트 `effects_on_welcome`(welcome에서 효과가 있던 플레이어), `combat.flask_events`(받은 병 사건 수)·`combat.poisoned_seen`(독 걸린 채 본 이단), 플레이어의 `vitals`에 버프·독. `brew`·`brew4`가 이것과 호스트 로그의 `craft`·`throw`·`splash`·`hit`을 본다.
M5c에서 더한 것: 결과 JSON의 지도마다 `altar`(제단 자리, 든 동안 `none`)·`fields`(일군 칸 수, 작물을 칸마다 `describe`, 시듦·익음·젖음 수)·`corrupted`, 플레이어마다 `carrying`·`channel`, 호스트의 `fields`(지도마다 농장 통계, 정화한 칸, 들기·놓기 수, 든 자리), 클라이언트의 `purify_flashes`. `farm`·`farm4`·`purify`·`altar`가 이것과 호스트 로그의 `farm`·`field`·`channel`·`purify`·`altar`·`respawn` 줄, 늦은 참가자의 welcome 줄(`altar= tilled= crops= withered=`)을 본다.
H-fix에서 더한 것: 호스트 입력 토큰이 실제 시간을 따라감(게이트마다 채운 시간이 호스트 틱 수의 0.9~1.1배 + 멈춘 시간. 호스트가 시계를 잘못 재면 실패한다), 모든 스냅샷이 틱당 8조각으로 나감(호스트가 센 틱 수 = ⌈조각/8⌉, `four`의 c4는 M1 2틱, M2b 18조각이라 3틱), `stall` 세션(위 "네트워크 테스트": 멈춤 뒤 속도 제한 틱 ≤ 2와 크레딧 사용, 받는 도중 편집이 welcome 뒤에 감, 편집 수와 월드가 호스트와 같음).

## 규칙

- **타입을 붙인 GDScript만**. `project.godot`에서 경고 5종(`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`)을 **오류**로 켰다. 걸리면 그 스크립트가 컴파일되지 않는다. 자주 걸리는 것: `int(v)`·`float(v)`에 Variant를 넣기(→ `var n: int = v`로 먼저 받기), Variant를 `as T`로 바꾸기(→ 타입 있는 변수에 대입), `Dictionary.get()` 결과를 바로 인자로 넘기기, `Script.new()`(→ `GDScript`로 받기). 데이터는 타입 없는 Dictionary 대신 타입 있는 Dictionary나 작은 클래스로
- Godot 4 API만 (`TileMapLayer`, `@export`·`@onready`, Callable 시그널). C# 없음. 줄바꿈 LF
- 게임 클래스는 `class_name`을 쓴다 (새 파일을 추가하면 임포트를 한 번 돌려 클래스 캐시를 갱신). `tests/`의 스크립트는 `class_name` 없이 경로로 `extends "res://tests/base_test.gd"` (내보내기에서 빠지는 폴더라서)
- 게임 코드는 오토로드 이름 `Cli`를 직접 쓰지 않고 `CliOptions.current()`를 쓴다. `--script`로 시작하는 도구는 오토로드가 등록되기 전에 컴파일돼서 `Cli`를 못 찾는다 (G1에서 실제로 겪음)
- 상수는 `core/config.gd`에 모은다. 주석으로 ●(문서 결정) / `PROVISIONAL`(○·?, 문서 위치) / `IMPL`(에이전트 선택)을 구분한다. 임시값을 새로 만들면 아래 표에도 적는다
- 기계가 읽는 출력 줄은 `EVENSONG_` 접두어 (`EVENSONG_SMOKE`, `EVENSONG_SCREENSHOT`, `EVENSONG_TESTS`, `EVENSONG_TILESET`, `EVENSONG_ANCHORS`, `EVENSONG_RENDER`, `EVENSONG_CLI`, `EVENSONG_NET <인스턴스> <사건> ...`)
- 네트워크: 게임 상태를 바꾸는 것은 호스트만 한다. 클라이언트가 보내는 RPC는 `any_peer`로 열고 호스트가 검사한다(지금은 hello·입력·done). 클라이언트가 보내는 값은 호스트가 스스로 정할 수 있으면 보내지 않는다(M1의 바라보기. M2b부터 조준 중의 바라보기 look은 마우스라 호스트가 정할 수 없어 보낸다. 그래도 사용의 바라보기는 호스트가 목표 칸에서 정한다). 새 메시지는 `NetProtocol`에 크기 고정 형식으로 넣고 디코더가 크기·범위를 먼저 본다. RPC는 `session.gd`에 받는 함수와 `send_*`를 두고 처리는 흐름 파일에 둔다. 이동 규칙을 바꾸면 호스트와 예측이 같이 바뀐다(`Movement` 하나). 월드를 바꾸는 일은 `EditLog`를 거친다(이미 있는 참가자에게 번호 붙은 편집으로 가고, 늦은 참가자는 스냅샷과 그 뒤 편집으로 같은 월드를 받도록. M3b: 그 지도의 기록으로, `SessionHost.apply_world_edit(편집, 지도)`, 그 지도에 있는 사람에게만). 타일을 겨누는 새 요청은 지도 번호를 싣고 호스트가 그 멤버의 지도와 맞춰 본다(M3b). 월드 레이어를 늘리거나 바꾸면 `WorldSnapshot`의 머리말·`decode_raw` 검사도 같이 본다
- 싸움 (M4b): 피해·소생·사망·가방·부활·적·날아가는 것은 호스트만 정한다(`SessionHost`가 지도마다 `Arena`를 돌림). 클라이언트에 보내는 것은 결과다: 플레이어 상태의 vitals, 지도마다 적 묶음(그 지도의 사람에게만, `peers_on`), 화살 사건. 플레이어 시뮬레이션에 새 상태를 더하면 `PlayerSim.copy`·`same_all`·`Vitals.same_wire`와 vitals 블록(`NetProtocol.put_vitals`/`get_vitals`)을 같이 본다(예측이 호스트 상태에서 다시 돌리므로 빠진 필드는 보정이 된다)
- 물약·제작 (M6b): 효과를 걸고(마시기의 효과 틱·터짐) 아이템을 만드는 것(제작)은 호스트만 한다. 혼자 할 때와 호스트가 같은 규칙 함수를 부른다(`Potions.release`, `Crafting.craft`, `WorldItems.place`). 플레이어의 효과 필드를 늘리면 `Vitals.has_effects`·`same_effects`와 효과 블록(`NetProtocol.put_vitals`/`get_vitals`/`effects_valid`), 예측의 `Prediction.effect_event`를 같이 본다. 던진 병의 걸음을 바꾸면 `Arena.flask_points` 하나만 바꾼다(호스트의 비행과 클라이언트의 그림이 같이 쓴다)
- 농사 (M5a): 밭의 보이는 상태(흙, 작물·단계·젖음·시듦·약초사가 심음)는 월드(바닥·식생 레이어)에만 두고 편집으로만 바꾼다. 보이지 않는 시간은 `Farm`에 두고, `Farm`의 메서드는 데이터를 쓰지 않고 편집을 돌려준다: 받은 편집을 다음 호출 전에 적용한다(`GameWorld.apply_edit`. 적용 전에 다시 부르면 그 칸을 옛 값으로 읽는다: 스모크를 처음 짤 때 물주기가 심기 편집 전의 빈 흙을 읽어 작물을 덮었다). 규칙 검사는 `items/farming.gd`의 순수 함수(혼자 할 때와 M5c의 호스트가 같이 쓴다). 시계·난수를 쓰지 않는다
- 세션의 농사·정화·제단 (M5c): 호스트만 결과를 정한다(`SessionHost`: 지도마다 `Farm`, `_plant`·`_farm_impact`·`_pour`·`_channel`·`_altar_lift`·`_altar_place`). 규칙 함수는 혼자 할 때와 같은 것을 부른다(새로 쓰지 않는다). 새 요청은 프레임에 붙이고(CHANNEL·ALTAR_LIFT·ALTAR_PLACE, 지도를 실음) 호스트가 다시 정한다(`frame.channel`은 호스트가 덮어씀, 들기는 호스트가 센 F 프레임으로). 플레이어에 새 상태를 더하면 상태 바이트에 자리가 남았는지 먼저 본다(채널링은 동작 비트 15, 든 제단은 든 아이템 바이트 7번 비트를 썼다: flags 바이트는 다 찼다)
- 정화·제단 (M5b): 정화(오염 0, 재 → 풀)와 제단 들기·놓기(설치물 칸)는 월드 편집이다(`items/purify.gd`, `items/altar_move.gd`의 순수 함수가 편집을 돌려주고 부른 쪽이 `GameWorld.apply_edit`으로 적용). 제단 자리를 쓰는 코드는 저장한 값이 아니라 `data.altar_rect`·`SafeZone.for_world(data)`를 그때그때 읽는다(빛 규칙·스폰 칸을 저장해 두는 `Arena`는 `sync_world`로 따라감. 새로 저장해 두는 곳을 만들면 같이 따라가게). 채널링 상태는 `PlayerSim`(공유 규칙)에 두고 전송 형식에는 아직 없다(M5c에서 `same_as`·상태 묶음에 더함)
- 요청 (M2b): 클라이언트의 새 요청은 새 RPC가 아니라 입력 프레임에 붙인다(`NetProtocol.Op`, 필드 크기 고정, 디코더가 범위를 먼저 봄). 호스트는 그 프레임을 처리할 때 검사·적용한다(`SessionHost.run_frame`). 검사 규칙은 `items/world_items.gd`의 순수 함수로 두어 호스트와 혼자 할 때(`Main`)가 같이 쓴다. 플레이어의 프레임 규칙은 `PlayerSim.step` 하나다(호스트·예측·혼자). 드롭은 `WorldData.drops`와 편집으로만 바꾼다
- 빛 레이어: 바닥·제단·건물 = `Config.LIGHT_LAYER_WORLD`(1, 기본값), 캐릭터 스프라이트와 채집물·드롭(M2b) = `LIGHT_LAYER_ACTORS`(2). `light_mask`는 자식에게 물려지지 않으니 스프라이트마다 넣는다
- 빛 텍스처(`PointLight2D.texture`)는 실행 중에 새로 만들어 갈아 끼우지 않는다. `AltarLight.texture_for()`의 캐시를 쓴다
- 스프라이트 안의 그리기 순서는 트리 순서로, 다른 물체와의 순서는 y 정렬(발 = 노드 위치)로 정한다. `z_index`는 디버그 선에만 쓴다
- 그림은 `assets/concept`의 우리 PNG·JSON만 `art/`로 복사한다 (바이트까지 같게). 남의 에셋은 넣지 않는다. `game/` 아래 PNG는 LFS 규칙(`assets/concept/**`) 밖이라 작은 것만
- `const`로 둔 타입 있는 컨테이너의 원소가 packed 배열이고(`Dictionary[StringName, PackedStringArray]`, `Array[PackedStringArray]`) 값을 배열 리터럴로 쓰면, 4.7.2에서 읽을 때 엉뚱한 값(빈 문자열 24개)이 나오고 그것으로 이미지를 만들다 크래시가 났다 (M2a에서 잼, 스크래치 시험으로 재현). 이런 상수는 원소를 `Array`로 둔다(`ItemIcons.MAPS`, `Hud.DIGITS`). `const X: PackedStringArray = [...]`처럼 packed 배열 자체인 상수는 괜찮다
- `get_stack()`은 GDScript 내장 함수라 같은 이름의 메서드를 만들면 클래스 안에서 부를 때 내장이 불린다(인벤토리 칸 읽기는 `stack_at`)
- 테스트가 `tree.root.size`를 바꾸면(창 늘이기 시험, `test_aim.gd`) 끝에 원래대로 돌려놓는다
- 생성기나 그 상수를 일부러 바꾸면 `world/surface_gen.gd`의 `GOLDEN_HASH`를 새 값으로 바꾼다 (실패 메시지에 새 값이 나온다. `test_world.gd`와 스모크가 이 값을 본다). 늦은 참가는 이제 호스트의 월드를 받지만(H1), 같은 시드가 같은 월드라는 것(시드 공유, 혼자 할 때)은 여전히 이 값이 지킨다

### 테스트 쓰는 법

`tests/test_<이름>.gd` 하나 = 러너가 찾는 테스트 파일 하나.

```gdscript
extends "res://tests/base_test.gd"

func run() -> Array[String]:
	check_eq(1 + 1, 2, "덧셈")
	var node: Node2D = add_node(Node2D.new()) as Node2D   # 루트에 붙이고, 끝나면 러너가 지운다
	await await_frames(2)                                 # await 해도 된다
	allow_error("Node not found")                         # 일부러 내는 오류는 먼저 알린다 (기본 정확히 1번)
	node.get_node("missing")
	note("측정값 한 줄")                                   # PASS/FAIL 아래 "  * "로 찍힌다
	return failures
```

- 헬퍼: `check`, `check_eq`(int/float는 수로, String/StringName은 글자로 비교), `check_ne`, `check_between`, `check_has`, `fail`, `note`, `allow_error(패턴, 횟수)`(-1 = 아무 횟수), `add_node`, `await_frames`
- 그 파일이 도는 동안(정리와 그 뒤 2프레임 포함) 로그에 찍힌 **엔진 오류, `push_error()`, GDScript 실행 오류, 셰이더 오류는 모두 실패**다 (OS `Logger`로 받는다. 다른 스레드에서 난 것도). `allow_error()`로 알린 것만 통과하고, 알렸는데 안 나오거나 횟수가 다르면 그것도 실패다. 경고는 세지 않고 `  ! `로 찍기만 한다
- 파일 밖의 오류도 실패다: 첫 파일 전 `FAIL (startup)`, 마지막 파일이 끝난 뒤 10프레임 안 `FAIL (after the last file) ... logged after <파일> finished`, 두 파일 사이(다른 스레드만 가능)는 다음 파일의 실패로 `logged after <앞 파일> finished, before this file started:`를 붙여 센다 (다음 파일의 `allow_error()`로는 통과하지 않는다)
- 네트워크 포트가 필요하면 러너의 묶음 안에서 `Runner.free_port(Runner.port_first, Runner.port_last)`로 찾는다(`const Runner := preload("res://tests/run_all.gd")`, 쓰는 포트면 오류 줄 없이 건너뛴다)
- 노드는 `add_node()`로 붙인다. 정리 뒤 루트 아래에 새 노드가 남아 있으면 그 파일이 실패하고(`left <이름> (<클래스>) under the root after cleanup()`), 러너가 그 노드를 지운다 (다음 파일 시간에 오류를 내지 않게)
- 러너가 못 잡는 것: 파일이 남긴 타이머·스레드·시그널 콜백이 그보다 늦게 내는 오류. 그때 돌고 있는 파일의 실패로 세지고, 마지막 파일 뒤 10프레임보다 늦으면 놓친다
- 러너가 실패를 놓치지 않는지는 `tests/fixtures/case_*.gd` 11개(check 실패, 알리지 않은 push_error, 엔진 오류, await 뒤 오류, 실행 오류, 시간 초과, 기반 클래스 아님, 알렸는데 안 나온 오류, 루트에 남긴 노드 / 통과 2개)와 `late_error.gd`(마지막 파일 뒤 오류, 따로 돌림)로 `test_core.gd`가 매번 확인한다
- 시간 측정은 예열 한 번 + 여러 번 재고 범위로 적는다. 테스트가 확인하지 않은 것은 주장하지 않는다

## 임시값 (사람 확인 필요)

문서가 ○(제안)이거나 ?(미정)이거나 문서에 없는데 M1(아래 M2a·M2b 줄은 그 단계)에 값이 필요해서 넣은 것. 대부분 `core/config.gd`의 `PROVISIONAL` 상수다. 상수가 아닌 줄은 "코드" 칸에 적힌 곳에 있다: 키 배치(`project.godot`), 제단 그림(`art/env/`, `world/altar.gd`), 8방향 이동·4방향 바라보기 규칙(`Movement`), 카메라 가장자리 멈춤(`PlayerCamera`), 디버그 월드 편집(`net/net_bot.gd`), M2a의 조준 규칙(`actors/aim.gd`), 도구 아이콘(`items/item_icons.gd`), 아이템 표(`items/item_db.gd`), 그림(`art/items/`), 세션에서 끄기(`Player.controls`, `core/main.gd`), M2b의 줍기·드롭 규칙(`items/world_items.gd`)과 키(`project.godot`). 정해지면 그 값이나 코드를 바꾸고, 생성기에 닿는 값이면 `SurfaceGen.GOLDEN_HASH`를 갱신한다.

| 무엇 | 코드 | 지금 값 | 문서 |
|---|---|---|---|
| 지상 시작 구역 크기 | `MAP_SIZE` | 128 × 96 타일 (2048 × 1536 px) | ○ gameplay-design §3.1 (경계 있는 연속 맵, 크기 없음) |
| 제단 안전 반경 | `SAFE_RADIUS_TILES` | 7타일 = 112 px (스파이크 값). 지름 14칸이 화면 세로 약 17칸 안에 들어간다 | ? 반경 미정 (game-concept §7 화면 배율 줄: "제단 빛 반경을 정할 때 화면 세로 약 17칸 안에 들어오는지 함께 본다") |
| 제단 바닥 차지 | `ALTAR_FOOTPRINT` | 3 × 3 타일, 맵 한가운데 | ○ concept-art-brief §5.7 (R29) |
| 밭(일군 흙) | `SOIL_PATCH_COUNT`, `SOIL_PATCH_MIN`/`MAX` | 빛 반경 안에 3덩어리, 2×2 ~ 4×3, 제단 둘레 1칸 비움 | ○ "빛 안의 밭" game-concept §9.7·§12 판정 기준, gameplay-design §3.8 |
| 고정 오염 구역 수 | `ASH_ZONE_COUNT` | 3 | ○ 2~3곳 (game-concept §12: "제안" 절의 표시 없는 줄). 그 안의 수도 미정 |
| 오염 구역 크기 | `ASH_ZONE_RADIUS_MIN`/`MAX` | 반지름 5~8타일 (+ 가장자리 노이즈 ±3타일) | 문서에 없음 |
| 빛과 오염 사이 거리 | `ASH_CLEARANCE_TILES` | 안전 반경 밖 4타일부터 재 | 문서에 없음 (흙·재가 닿지 않게 하는 풀 띠이기도 하다) |
| 키 배치 | `project.godot` 입력 `move_*`, `debug_overlay`, `toggle_evening` | WASD + 방향키 (물리 키), F3 디버그 선, F4 저녁 켜고 끄기 | ○ gameplay-design §1 키 배치 초안 (F3·F4는 개발용, 초안에 없음) |
| 걷기 속도 | `WALK_SPEED` | 72 px/s (4.5타일/초), 8방향 같은 속력 | 문서에 없음 (M1 지시: 64~80 px/s) |
| 지상의 빛 | `EVENING_COLOR` | 늘 저녁 하나, `CanvasModulate` (0.40, 0.34, 0.31) 따뜻한 회색 (스파이크 값). 낮밤 순환 없음 | ? 낮밤 / 영원한 황혼 (gameplay-design §3.1, game-concept §7) |
| 제단 빛 색·세기 | `ALTAR_LIGHT_COLOR`, `ALTAR_LIGHT_ENERGY` | (1.0, 0.97, 0.91) × 0.65, 더하기 (스파이크 값. 빛 안 ≈ 그린 색) | 문서에 없음 |
| 안전 반경 테두리 | `SAFE_EDGE_BAND_PX`, `AltarLight` | 바닥: 반경 안쪽 16px 디더 띠 / 캐릭터: 같은 반경 hard 사본 (스파이크 제안) | 문서에 없음 (concept-art-brief §7 체크리스트의 "디더링으로 사라지는 빛 원"과 같은 쪽) |
| 제단 그림 | `art/env/altar_v04.png`, `altar_v04_unlit.png` | 4단계 채택 후보를 임시 그림으로. 등잔 9개 모두 켜짐 | ○ R29 채택 후보 (concept-art-brief §5.7), 켜진 등잔 수 메커닉은 ○ game-concept §9.3 |
| 8방향 이동 + 4방향 바라보기 | `Movement` | 위 "캐릭터" 참조 | 문서에 없음 (M1 지시) |
| 카메라 가장자리 | `PlayerCamera.clamp_center` | 내 캐릭터 가운데, 단 맵 가장자리에서는 맵 밖이 안 보이게 멈춘다 (맵이 화면보다 작은 축은 맵 가운데). 그래서 가장자리 근처에서는 캐릭터가 화면 가운데에서 벗어난다 | ● gameplay-design §1 "카메라는 각 플레이어 중심"에서 가장자리만 벗어난다 (멈출지는 문서에 없음). 늘 가운데로 하려면 `Main._follow`에서 `bounds`를 비우면 된다 |
| 상태 묶음 빈도 | `NET_STATE_HZ` | 20Hz (3틱마다), 바뀐 것이 있을 때만 | 문서에 없음 (M1 지시: 20~30Hz) |
| 남의 캐릭터 보간 지연 | `NET_INTERP_DELAY_MS` | 100ms (묶음 2개) | 문서에 없음 (M1 지시: 약 100ms) |
| 같은 클래스 둘 | `NET_UNIQUE_CLASSES` | 허용 (false). true면 호스트가 `class_taken`으로 거부 | ? 정해지지 않음 (gameplay-design §5 ○ 파티 UI 3×3은 클래스당 한 명 같지만 M1은 5클래스라 9인을 막게 된다) |
| 스폰 (혼자·호스트·참가자) | `SPAWN_FACING`, `Roster`, `SPAWN_SLOTS`(자리 9곳은 아래 구현 표) | 제단 둘레 자리 중 가장 작은 빈 자리, 남쪽(`SPAWN_FACING`)을 보고 선다 | 접속 스폰은 문서에 없음. 가까운 것은 "부활 지점: 제단" (gameplay-design §2.6, §5 ○) |
| 디버그 월드 편집 | 봇 `edit:<x>,<y>,<grass\|soil>` | 호스트만, 바닥 풀 ↔ 흙(괭이질)만 | 문서에 없음 (M1에 게임 편집이 없어 늦은 참가 길을 시험하려고. 키는 만들지 않았다) |
| M2a 키 | `project.godot` 입력 `use_item`, `hotbar_prev`·`hotbar_next`, `toggle_inventory`, `debug_give`, `debug_action` | 좌클릭 = 들고 있는 도구 사용, Q / E = 핫바 왼쪽 / 오른쪽, Tab = 인벤토리(보기만). 숫자 키는 핫바에 안 씀(초안에서 1 2 3은 스킬), F 상호작용은 아직 안 묶음(할 것이 없음). F5 디버그 아이템 묶음, F6 다음 몸 동작. **M6a에서 더함** (이 줄의 값은 그대로): 작업대 옆의 Tab은 제작 창, 1 = 약제 투척, 물약 좌클릭 = 마시기(아래 "M6a 키") | ○ gameplay-design §1 키 배치 초안 (F5·F6은 개발용, 초안에 없음) |
| 핫바·인벤토리 크기 | `HOTBAR_SLOTS`, `INVENTORY_SLOTS` | 핫바 8칸 = 인벤토리 24칸의 앞 8칸 | 문서에 없음 (gameplay-design §1 ○ "무기와 도구는 핫바로 전환"에 칸 수 없음) |
| 묶음 크기 | `STACK_TOOL`, `STACK_MATERIAL`, `STACK_GATHERABLE` | 도구 1, 재료 99, 채집물 99. M3a: 광석 둘은 재료(99), 횃불도 `STACK_MATERIAL`(99, 아래 "M3a 횃불") | 문서에 없음 |
| 조준 중 (마우스 쪽 보기) | `AIM_HOLD_SEC`, `Player.tick_controls` | 마우스가 1초 안에 움직였거나, 사용 버튼을 누르고 있거나, 동작 중이면 마우스 쪽을 봄. 아니면 M1 그대로 걷는 방향 | 문서에 없음 (● gameplay-design §2.1 R12는 "에임형 (마우스 방향 스킬샷)"까지) |
| 조준 기준·구역·바라보기 | `Aim.sector`, `Aim.facing`, `Aim.feet_cell` | 기준점 = 발, 45° 8구역(축·대각선이 가운데), 마우스 쪽 바라보기는 4방향(큰 축, 정확한 대각선은 남·북), 마우스가 발 위면 그대로. **발 칸 = 발 상자(발 위 4px)의 가운데가 있는 칸** (M2-fix: 전에는 발 점의 칸이라 발이 타일 선 위면 그려진 발보다 한 줄 아래였다. 스폰 자리 0·1이 그렇다. 목표 칸·표시·손 닿는 칸이 모두 이것을 쓴다) | 문서에 없음 (● §2.1 에임형) |
| 목표 칸 | `Aim.target_cell` | 발 칸의 마우스 방향 이웃 칸(8방향). 맵 밖이면 표시를 숨김 | ○ gameplay-design §3.2 "마우스 방향의 인접 타일을 타격" (채굴에 쓴 말) |
| 몸 동작 길이 | `ACTION_FRAME_TICKS` | 프레임당 6틱(0.1초): 6프레임 0.6초, 8프레임 0.8초, 던지기 0.7초 | 문서에 없음 |
| 동작 중 이동 | `ACTION_LOCKS_MOVEMENT` | 동작이 끝날 때까지 걷지 않고 바라보기·목표 칸도 시작 때 것 | 문서에 없음 |
| 누르고 있기 | `ACTION_REPEAT_WHILE_HELD` | 누르고 있으면 동작이 끝나는 틱에 다시 시작 | ○ gameplay-design §3.2 "홀드하면 연속" (채굴에 쓴 말) |
| 도구 아이콘 | `items/item_icons.gd` `MAPS` | 16×16 코드 그림 6개 (brief §4 갈흑 외곽선·신앙 금빛·나무색, 04-env 철·구리 색) | 그림 없음 (assets/에 도구 아이콘이 없다. 사람이 그림을 정하면 바꾼다) |
| 마법·던지기를 부르는 아이템 | `ItemDB` (없음) | 아이템 없음. F6·`--test-action`으로만 본다. **M4a에서 바뀜**: 마법은 성직자의 기본 공격 `holy_light`가 부른다(아래 "M4a 기본 공격"). 던지기는 그대로 없음. **M6a에서 바뀜**: 던지기는 약초사의 약제 투척(스킬 키 1)이, 마법은 마시기도 빌려 쓴다(아래 "M6a 투척"·"M6a 마시기"). 두 동작을 아이템의 `action`으로 부르는 것은 여전히 없다(물약은 `Potions`가 부름) | 문서에 없음 (마법 = 성직자 기도·치료, 던지기 = 약초사 약제 투척, brief §5.6 표. 스킬 ? gameplay-design §2.2, 약제 ○ game-concept §12. 둘 다 M2 밖) |
| 등급이 있는 아이템 | `ItemDef.graded` | 약초 4개만 일반·상급. 버섯·돌·도구는 등급 없음 | 약초는 ● gameplay-design §3.4 원칙, 나머지는 문서에 없음 |
| 재료 아이콘 시점 | `stone_block` = `item_stone_block_v02.png` | 3/4 아이콘 v02 | ○ brief §5.7 "떨어진 재료 아이콘을 정면 정렬(v03)로 할지 3/4(v02)로 둘지" |
| 채집물·재료 그림 | `art/items/` | 04-env 본 제작 손질판 v02 19장 (아래 "그림 출처") | ○ 채택 후보, 사람 확인 전 (brief §5.7 "결과 (R32)", 04-env/prompts.md "본 제작") |
| 시작 인벤토리 | `Main` | 비어 있음 (F5, `--give`로 넣음). **M4a에서 혼자 할 때 바뀜**: 클래스 무기 하나가 핫바 8번(아래 "M4a 시작 무기"). 세션은 이 값 그대로. **M4b에서 세션도 바뀜**: 접속할 때 호스트가 클래스 무기를 핫바 8번에 넣는다 | 문서에 없음 |
| 세션의 조준·동작·인벤토리 | `Player.controls`, `Main` | M2a: 세션에서는 조준·동작 끔, 인벤토리는 보내지 않고 각자 자기 화면에서만. **M2b에서 이 줄은 끝났다**: M2b 지시(M2가 더한 것은 모두 호스트 권한)대로 세션에서도 켜고 호스트가 정한다(위 "M2b") | 문서에 없음 (M2a 지시: 혼자 할 때 먼저) → ● 호스트 권한 game-concept §13 |
| M2b 채집물 수 | `GATHER_ON_GRASS`, `GATHER_ON_ASH` | 풀에 야생 회복·버프·독초 8개씩, 버섯 a~d 4개씩, 돌 a 6·b 5·c 5·이끼 4 / 재에 재 버섯 6, 금 간 돌 4, 곰팡이 돌 4 = 74개 (128×96 맵, 맵 크기와 상관없이 같은 수) | ○ brief §5.7 범위 표 "야생 약초·균류 채집물", game-concept §12 (무엇이 있는지만, 수·밀도 없음). **돌은 문서에 없다**: 에이전트가 04-env/prompts.md 묶음 2의 "칸 0~19 채집물"에서 가져왔다(M2-fix에서 바로 적음. 전에는 이 줄과 `config.gd`가 돌까지 §5.7 표와 ● R28로 덮은 것처럼 적었다. §5.7 표는 약초·균류만, R28은 작물 3종이다). 오염 쪽 셋은 04-env/prompts.md "오염 쪽" |
| M2b 채집물 자리 | `GATHER_CLEARANCE_TILES`, `GATHER_EDGE_TILES`(M2-fix: `SurfaceGen`의 표시 없는 상수에서 옮김, 값 그대로), `SurfaceGen.gatherable_spot_ok` | 칸 가운데가 안전 반경 + 1타일 밖, 맵 가장자리에서 2칸 안쪽, 다른 채집물의 8이웃이 아님. 덤불(herb_clump)은 흩지 않음 | 문서에 없음 (4단계 목업이 채집물을 빛 밖에, 밭을 빛 안에 둔 것을 따름) |
| M2b 채집물이 다시 자라는지 | (없음) | 다시 자라지 않는다 | 문서에 없음 |
| M2b 채집물·드롭이 걸음을 막는지 | `Movement` (그대로) | 막지 않는다 (밟고 지나간다) | 문서에 없음 |
| M2b 손 닿는 칸 | `REACH_TILES` | 줍기·사용·버리기는 목표 칸(발 칸 `Aim.feet_cell`의 8이웃, M2a의 목표 칸)만. 호스트가 그보다 먼 칸·발 칸을 거부 | ○ gameplay-design §3.2 "마우스 방향의 인접 타일", §3.4 "F로 식물·드롭 줍기" |
| M2b 키 | `project.godot` 입력 `interact`, `debug_drop` | F = 목표 칸의 채집물, 없으면 드롭 줍기 / F7(개발용) = 고른 칸의 묶음 전부를 목표 칸에 버리기 | ○ gameplay-design §1 키 배치 초안 "F 상호작용 (줍기 …)" (F7은 초안에 없음) |
| M2b 드롭 주인 | `WorldItems.pickup` | 누구나 어떤 드롭이든 주울 수 있고 먼저 주운 사람 것. 인벤토리에 다 안 들어가면 들어가는 만큼 줍고 나머지는 남는다 | ○ gameplay-design §5 "드롭은 주운 사람 것" (일부만 줍기는 문서에 없음) |
| M3a 던전 크기 | `DUNGEON_SIZE` | 64 × 48 타일 (화면 약 2 × 3) | ○ game-concept §12 "첫 던전 1개", gameplay-design §3.1 ○ "던전 = 별도 맵" (크기 없음) |
| M3a 방·통로 | `DUNGEON_ROOM_COUNT`, `DUNGEON_ROOM_MIN`/`MAX`, `DUNGEON_ROOM_GAP`, `DUNGEON_CORRIDOR_WIDTH` | 방 7개(배치되는 만큼), 7~12 × 6~9 (윗줄은 북쪽 벽 앞면), 방 사이·테두리 3칸, 통로 3칸 너비 L자 | 문서에 없음 |
| M3a 기반암 테두리 | `DUNGEON_BORDER_TILES` | 2칸, 깰 수 없음 | 문서에 없음 (M3a 지시 "map border unbreakable") |
| M3a 광맥 | `DUNGEON_VEINS`, `DUNGEON_VEIN_SIZE_MIN`/`MAX` | 구리 9 · 철 5 줄기, 2~5칸, 걸을 수 있는 바닥 옆 바위에서 시작 | ○ brief §5.7 "광맥 1~2종" (종류·수 없음. 04-env 채택 후보가 구리·철) |
| M3a 벽 횃불 장식 | `DUNGEON_WALL_TORCH_SPACING`, `DungeonGen._place_wall_torches` | 방 북쪽 벽(앞면 있는 맨 바위, 광석 아님)에 6칸마다, 도착 방은 계단 양옆. 작은 빛. 값은 그대로이고 M3-fix에서 규칙을 지키게 고침: 맞지 않는 자리는 같은 벽의 가까운 자리로 옮기고(6칸마다의 것은 ±2칸, 계단 옆은 그쪽 벽 → 벽 어디든), 자리가 있는 방은 적어도 하나, 도착 방은 늘 하나 이상(출구를 횃불 자리가 남는 곳에 먼저 둠, 도착 방 횃불을 광맥보다 먼저). M3a는 맞지 않는 자리를 건너뛰어 도착 방 다섯에 하나가 어두웠다 | 문서에 없음 (04-env 던전 목업이 방 북쪽 벽에 횃불 둘) |
| M3a 이단의 제단 자리 | `SHRINE_FOOTPRINT`, `DungeonGen._place_shrine` | 3 × 2, 도착 방에서 (가운데 기준) 가장 먼 방 가운데. 불 꺼짐, 부술 수 없음. **M4a에서 바뀜**: 전투로 부술 수 있다(아래 "M4a 이단의 제단") | ○ game-concept §12 "첫 던전 1개 (= 첫 오염 원천)", ? 이단 쪽 불 색 (brief §5.7) |
| M3a 던전 입구 | `ENTRANCE_FOOTPRINT`, `ENTRANCE_OFFSET_TILES`, `SurfaceGen.entrance_spot_ok` | 2 × 1, 제단 자리 왼쪽 위 칸에서 (10, 1) 타일 (시드 1: 제단 가운데 동쪽 약 10타일, 빛 밖). 막혀 있으면 가까운 데서 찾음(빛 + 1타일 밖, 가장자리 2칸 안, 채집물·설치물·흙 없음) | ○ gameplay-design §3.1 "지상의 입구로 진입" (자리 없음) |
| M3a 출구 계단과 도착점 | `EXIT_FOOTPRINT`, `ARRIVAL_FEET_INSET_PX`, `DungeonGen.arrival_point`, `arrival_below` | 도착 방 북쪽 벽 앞면 2칸(위 바위는 기반암), 도착점은 그 바로 남쪽 두 칸의 가운데, 발은 그 칸 아래 끝에서 4px 위(M3-fix에서 상수로 이름만 붙임). 지상으로는 입구 바로 남쪽(같은 규칙). M3-fix: 출구는 둘레에 벽 횃불 자리가 남는 방·자리를 먼저 고른다(위 줄) | 문서에 없음 |
| M3a 앞면 칸이 막힘 | `Walls.blocks`, `Walls.owner_of` | 벽 아래 칸(앞면이 그려진 칸)은 걷지 못하고, 조준하면 위 벽을 친다. 가로 굴은 두 줄이어야 들어간다 | 문서에 없음 (그림에서 나온 구현 선택이지만 놀이에 닿아서 여기 적음) |
| M3a 경도·타격 | `HARDNESS_*`, `HARDNESS_CAP_*`, `WALL_HITS_*`, `MINING_POWER_*`, `Mining.strike` | 경도 바위 1 · 구리 1 · 철 2, 상한 공용 1 · 광부 2, 깨지는 타격 바위 6 · 구리 8 · 철 10, 한 번에 공용 1 · 광부 2. **곡괭이 등급은 없다**: 곡괭이는 하나(등급 없음)이고 깰 수 있는지는 클래스 상한이 정한다(§3.1의 "곡괭이 등급이 경도 이상이어야 파괴"를 클래스 상한으로 바꿔 둠, M3-fix에서 바로 적음). 광부의 3×3은 친 칸을 깰 수 있을 때만 둘레에 닿는다(M3-fix) | ● 공용 "느리고 1×1, 경도 상한" / 광부 "3×3 고속, 상위 경도" (gameplay-design §3.0 R11). gameplay-design §3.1 줄 "벽 타일에 경도 등급. 곡괭이 등급이 경도 이상이어야 파괴 (테라리아). 상위 광석은 상위 곡괭이 → 광부 개인 트랙의 축"은 ●/○ 표시가 없다(M3a는 앞 절반만 ○로 적었다). 숫자 없음. 곡괭이 등급을 둘지는 사람이 정한다 |
| M3a 맞는 프레임 | `MINING_IMPACT_FRAME` | 곡괭이 동작 4번째 프레임(18틱째) | 문서에 없음 |
| M3a 3×3 방향 | `MINER_AREA_AWAY` | 친 칸에서 플레이어 반대쪽으로 3칸, 가로로는 가운데 (false = 친 칸 가운데) | ● 3×3 (R11), 어디로 뻗는지는 문서에 없음 |
| M3a 금 단계 | `Walls.crack_stage` | 최대 타격의 1/3마다 1·2·3단계 (올림) | 문서에 없음 (04-env 금 그림이 3단계) |
| M3a 깨진 칸이 주는 것 | `MINED_ROCK_ITEM`, `Walls.ORE_ITEMS` | 바위 → 돌 a 1개, 광석 칸 → 그 광석 1개(돌은 안 줌). 인벤토리에 안 들어가면 그 칸에 드롭, 드롭이 `MAX_DROPS`면 사라짐 | ○ gameplay-design §3.2 "채굴 시 드롭은 인벤토리로 자동" (가득 찼을 때는 문서에 없음) |
| M3a 던전 어둠 | `DUNGEON_DARK_COLOR` | (0.13, 0.11, 0.10), 제단 빛 없음 | 문서에 없음 (04-env 던전 목업은 어둡게 하지 않았다) |
| M3a 횃불 | `TORCH_LIGHT_*`, `WALL_TORCH_LIGHT_*`, `TorchLight.STEP_*`, `WorldItems.place`, `ItemDB` 횃불, `Mining.strike` | 놓은 횃불 반경 80px · 세기 0.95, 벽 횃불 48px · 0.8, 색 (1, 0.86, 0.62), 딱딱한 네 단계. 손 닿는 빈 바닥에 하나씩(누르고 있어도 한 번), 막지 않음, 다시 줍지 못함. 안전 반경 아님. 아이템: 종류 "놓는 것"(`PLACEABLE`), 묶음 99(`STACK_MATERIAL`). 벽 횃불은 그 벽을 깨면 같이 없어진다(아이템을 주지 않음). M3-fix에서 마지막 두 문장을 이 표에 올림(값은 M3a 그대로) | ● 기본 키트에 횃불 (gameplay-design §3.0 R11), 빛의 크기·안전 여부·놓는 규칙·묶음 크기·벽 횃불이 떨어지는지는 문서에 없음 |
| M3a 횃불 그림 | `FixtureView` 횃불, `ItemIcons.MAPS["torch"]` | 놓은 횃불 = 04-env 땅 랜턴 켜짐판 v03, 아이콘 = 코드로 그린 작은 랜턴 | 그림 없음 (04-env에 횃불 아이템이 없다. ○ brief §5.7 랜턴 = 건설 조명) |
| M3a 출구 계단 그림 | `FixtureView._add_exit` | 임시: 던전 입구 아치 + 내려가는 계단 그림을 위아래 뒤집어 올라가는 계단처럼 | 그림 없음 (brief §5.7 범위에 던전 안 계단이 없다) |
| M3a 세션 | `WorldItems.pickup`, `Main` | M3a: 세션은 지상만, 입구는 호스트가 거부(`dungeon offline only`). **M3b에서 이 줄은 끝났다**: 세션에서도 오가고 캔다(위 "M3b", 아래 "M3b 지도 오가기") | M3a 지시 "local / offline first" → ● 호스트 권한 game-concept §13 (M3b 지시) |
| M3b 지도 오가기 (세션) | `WorldItems.travel`, `SessionHost._travel` | 입구·계단을 손 닿는 칸(`REACH_TILES`)에서 F. 요청 예산은 줍기와 같고 따로 기다리는 시간(쿨다운)은 없다. 도착점·남쪽 바라보기·동작 멈춤은 M3a 그대로. 여럿이 오면 같은 도착점에 겹쳐 선다(플레이어끼리 충돌 없음, M1부터) | ○ gameplay-design §3.1 "지상의 입구로 진입", 나머지는 문서에 없음 |
| M3b 다른 지도의 플레이어 | `SessionClient.draw_others` | 그리지 않고 화면에 아무 표시도 없다(누가 던전에 있는지 알 수 없다) | 문서에 없음 (파티 UI는 ○ gameplay-design §5 "파티 UI 3×3") |
| M3b 다시 참가할 때의 지도 | `SessionHost.on_hello` | 늘 지상 스폰 자리에서(던전에서 나갔어도) | 문서에 없음 (M2b "다시 참가" 줄과 같은 이유: 다시 참가 기억이 없다) |
| M4a 체력·방어 | `PLAYER_HP_MAX`, `PLAYER_DEFENCE` | HP 100, 방어 0(받은 피해 그대로. 방어구는 M7). M7a: 이 값은 그대로이고 갑옷의 방어는 따로 더한다(`ARMOR_T1_DEFENCE`, 아래 "M7a 갑옷") | ○ gameplay-design §2.4 "HP + 방어력(피해 감소)" (숫자 없음) |
| M4a 스태미나 | `STAMINA_MAX`, `STAMINA_REGEN_TICKS`, `STAMINA_REGEN_DELAY_TICKS` | 100, 쓴 뒤 30틱(0.5초) 쉬고 2틱마다 1(초당 30) | ○ §2.4 "스태미나(대시·방패)" |
| M4a 대시 | `DASH_STAMINA`, `DASH_TICKS`, `DASH_SPEED`, `DASH_COOLDOWN_TICKS`, `DASH_INVULNERABLE` | 한 번 35, 10틱 동안 240px/s(40px), 끝난 뒤 30틱 쿨다운, 대시 중 무적. 걷기와 같은 충돌, 입력 없으면 바라보는 쪽, 동작·경직·다운 중 안 됨 | ○ §2.5 "모두 대시 1회 (스태미나)" |
| M4a 경직·피격 무적 | `HURT_TICKS`, `HURT_FRAME_TICKS`, `HURT_INVULN_TICKS` | 맞으면 18틱(0.3초) 못 움직이고 새 동작·대시 없음, 하던 동작은 끊김, 피격 시트 6프레임 3틱씩, 그 뒤 30틱 무적 | 문서에 없음 |
| M4a 다운·소생·사망 시간 | `DOWN_TICKS`, `REVIVE_TICKS`, `REVIVE_TICKS_CLERIC`, `DEATH_FRAME_TICKS` | 0 HP → 다운(사망 시트 7프레임 6틱씩, 그 뒤 누움), 30초(1,800틱) 뒤 사망, 아군 F 누르고 있기: 성직자 즉시(0) · 다른 클래스 5초(300틱), 소생 중에도 다운 시간은 흐르고 놓으면 처음부터 | 흐름과 30초·즉시·5초는 ● gameplay-design §2.6 R12 본문("다운 상태 → 아군이 F 홀드로 소생 (성직자는 즉시, 다른 클래스는 5초) → 30초 넘기면 사망"). 숫자를 상수로 둔 것이라 여기 적음. 소생 중 시간이 멈추는지, 놓으면 처음부터인지는 문서에 없음. **M4-fix**: 여럿이 F를 누르면 가장 빠른 사람 기준(성직자가 있으면 즉시). 값은 그대로, ●를 자리 순서와 상관없이 지키게 고침 |
| M4a 소생 거리·HP | `REVIVE_REACH_PX`, `REVIVE_HP` | 발끼리 24px 안, 소생하면 HP 30 | 문서에 없음 |
| M4a 소생 뒤 무적 (M4-fix에서 표에 올림) | `PlayerSim.revive` (`HURT_INVULN_TICKS`) | 소생하면 맞은 뒤와 같은 30틱 무적(새 상수 없음, M4a 값 그대로) | 문서에 없음 (M4a부터 그랬는데 표에 없었다) |
| M4a 다운 중 | `PlayerSim.step`, `Main.pick_up`, `Arena.can_target` | 못 움직이고 동작·대시·F 줍기·F7 없음, 이단의 표적이 아님 | 문서에 없음 |
| M4a 포기 | `GIVE_UP_HOLD_TICKS` | 다운 중 F를 1초(60틱) 누르고 있으면 바로 사망 | 문서에 없음 (혼자 하면 소생해 줄 사람이 없어서) |
| M4a 부활 | `RESPAWN_TICKS`, `RESPAWN_HP`, `Main._on_respawn_due` | 사망 5초 뒤 지상 제단의 자기 스폰 자리(혼자 = 자리 0)에 `SPAWN_FACING`을 보고, HP·스태미나 가득. 던전에서 죽어도 지상 | ● §2.6 "부활 지점: 제단" (§5 ○ 같은 말), 시간·HP는 문서에 없음 |
| M4a 사망 가방 '일부' | `DEATH_DROP_RULE`(`DEATH_DROP_HALF` / `DEATH_DROP_KINDS`), `DEATH_DROP_RANDOM_KINDS` | 절반 규칙: 도구가 아닌 칸마다 절반(올림). 상수 하나를 바꾸면 무작위 3종(그 종류의 칸 전부). 도구(무기 포함)는 남고, 재료·채집물·놓는 것(횃불 = 소모품으로 읽음)이 대상. M7a: 규칙 그대로, 갑옷(새 종류)도 도구처럼 남는다(장비는 내구도가 닳음: "M7a 사망 마모") | ● §2.6 R12 "일부 아이템 드롭", ○ §2.6 "장착·퀘스트 아이템 제외, 스택마다 절반 또는 무작위 3종. 슬라이스에서 정한다" |
| M4a 가방 자리·주인·사라짐 | `WorldItems.bag_cell`, `open_bag`, `BAG_SEARCH_TILES` | 죽은 칸(설치물·채집물·드롭이 있으면 3칸 안 가장 가까운 빈 칸, 없으면 가방 없이 아무것도 안 잃음), 누구나 F로 전부(들어가는 만큼), 저절로 사라지지 않음, 걸음을 막지 않음. **M4-fix**: 땅에 이미 `MAX_DROPS`(구현 값 256)가 있으면 가방 없이 아무것도 안 잃음(전에는 빈 가방) | ● §2.6 "되찾을 수 있다 (구출 플레이)", 나머지는 문서에 없음 (○ §5 "드롭은 주운 사람 것"과 같은 쪽) |
| M4a 기본 공격 (클래스 무기) | `CLASS_WEAPONS`, `ItemDB` `holy_light` | 팔라딘 검(근접 호), 아처 활(화살), 성직자 성광(새 도구 아이템, 마법 동작, 빛 탄), 광부 곡괭이(근접), 약초사 낫(근접. 문서에 없음). 무기 = 도구 아이템이고 누구나 어떤 무기든 쓴다 | ● §2.1 실시간·에임형 R12, ○ §1 "좌클릭: 기본 공격 / 들고 있는 도구 사용", "무기와 도구는 핫바로 전환 … 광부는 곡괭이가 무기이자 도구", ? §2.2 스킬 킷(정하지 않음) |
| M4a 무기 수치 | `WEAPON_ATTACKS` | 피해·사거리·호·맞는 프레임(0부터)·속도: 검 14·26px·120°·4, 곡괭이 10·22px·90°·3(= 채굴 프레임), 낫 8·22px·120°·3, 활 12·160px·6·220px/s, 성광 10·128px·3·150px/s. 공격 속도 = 동작 길이(`ACTION_FRAME_TICKS`, 누르고 있으면 반복) | 문서에 없음 |
| M4a 곡괭이 규칙 | `Combat.is_mining_swing` | 목표 칸이 벽·앞면이면 채굴만(호 안의 이단도 안 맞음), 아니면 공격만(벽 그대로) | ○ §1 "광부는 곡괭이가 무기이자 도구" (둘 다일 때는 문서에 없음) |
| M4a 아군 사격 | `FRIENDLY_FIRE` | 끔 (근접 호도, 화살도 플레이어에게 닿지 않음) | 문서에 없음 |
| M4a 시작 무기 | `START_WEAPON_SLOT`, `Main.give_start_weapon` | 혼자 할 때 클래스 무기가 핫바 8번(맨 끝), 고른 칸은 1번 그대로. 세션은 M4b. 위 M2a "시작 인벤토리"를 혼자 할 때만 바꿈. **M4b**: 세션에서도 접속할 때(호스트 자신도) 같은 칸에(`SessionHost._equip`) | 문서에 없음 |
| M4a 키 | `project.godot` 입력 `dash`, `interact` | Space = 대시. F를 누르고 있기 = 옆의 다운된 사람 소생 / 다운 중이면 포기 (눌렀을 때의 줍기는 M2b 그대로) | ○ gameplay-design §1 키 초안 ("Space 대시·구르기 (스태미나)", "F 상호작용") |
| M4a 이단 체력·피해·속도 | `HERETIC_HP`, `HERETIC_DAMAGE`, `HERETIC_SPEED` | 40, 12, 46px/s(걷기보다 느려 도망칠 수 있음) | 문서에 없음 (game-concept §12 "이단 적 1종(근접)"은 03-pixel 13차 줄) |
| M4a 이단 표적·시야·끈 | `HERETIC_SIGHT_PX`, `HERETIC_LEASH_PX` | 같은 지도의 서 있는 플레이어 중 112px 안, 벽 없이 보이는, 빛 밖의 가장 가까운 사람. 집에서 256px 넘으면 집으로 | ○ §2.3 어그로(위협 수치) → M9까지 "가장 가까운" |
| M4a 이단 공격 | `HERETIC_ATTACK_RANGE_PX`, `HERETIC_HIT_REACH_PX`, `HERETIC_HIT_ARC_DEG`, `HERETIC_ATTACK_COOLDOWN_TICKS` | 22px 안이면 시작, 맞는 순간 28px·120° 안 벽 없이 닿는 서 있는 모두, 끝나고 45틱 쉼 | 문서에 없음 |
| M4a 맞는 열 | `HERETIC_HIT_COLUMN` | 남 3 · 동 4 · 북 5열 (서 = 동) | ? 03-pixel/prompts.md 13차 "공격이 맞는 순간 후보 (○, M4에서 사람이 정함): 남 3~4열, 동 4~5열, 북 5~6열" — 쌍의 앞 열 |
| M4a 이단 프레임 시간·예고 | `HERETIC_TELEGRAPH_TICKS`, `HERETIC_ATTACK_FRAME_TICKS`, `HERETIC_HURT_FRAME_TICKS`, `HERETIC_DEATH_FRAME_TICKS`, `HERETIC_CORPSE_TICKS`, `HereticSim.WALK_FRAME_TICKS`·`IDLE_FRAME_TICKS` | 예고 30틱(0.5초, 모든 방향: 맞는 열 앞 열들을 6틱씩, 마지막 것을 붙잡음), 맞은 뒤 6틱씩, 피격 3틱, 사망 6틱, 시체 120틱 뒤 사라짐. 걷기·idle은 플레이어와 같은 7·12틱 | 03-pixel 13차 "공격·피격·사망 프레임 시간은 임시값으로" (13차는 6틱이면 예고가 남 0.2·동 0.3·북 0.2초라고 적었다) |
| M4a 이단 경직 | `HERETIC_HURT_INTERRUPTS_ATTACK` | 맞으면 피격 경직(쫓기 멈춤), 이미 시작한 공격은 안 끊김 | 문서에 없음 |
| M4a 빛과 이단 | `HERETIC_ENTERS_LIGHT` | 들어가지 않음: 발 상자가 빛에 닿지 않고, 빛 안의 사람을 노리거나 때리지 않음 | game-concept §9.3 "안전 반경(빛, 스폰 억제, 오염 저항)" — 적이 들어오는지는 문서에 없음. 기본값 이유는 위 "M4a: 이단" |
| M4a 빛 가장자리 | `HERETIC_LIGHT_EDGE_WAIT_SEC` | 쫓던 사람이 빛으로 들어가면 가장자리에 서서 4초 바라보다 집으로 (0 = 바로 돌아섬). **M4-fix**: 4초는 지켜보기 시작부터(맞아도 다시 세지 않음, 아래 "M4-fix 빛 안에서 쏘인 이단"). 값은 그대로 | 문서에 없음 (기본값 이유: 위 "M4a: 이단", game-concept §12 판정 기준 "제단의 빛이 '안전'으로 읽히는가") |
| M4a 횃불 빛 | `TORCH_LIGHT_IS_SAFE` | 끔: 횃불은 이단에게도 빛일 뿐 (켜면 횃불 반경 80px도 제단 빛 규칙) | 문서에 없음 (M3a "횃불" 줄 그대로) |
| M4a 스폰 | `HERETIC_CAP_SURFACE`·`_DUNGEON`, `HERETIC_SPAWN_INTERVAL_TICKS`, `HERETIC_SPAWN_MIN_PLAYER_PX`, `HERETIC_SPAWN_ASH_REACH_TILES`, `HERETIC_SPAWN_ARRIVAL_MIN_TILES` | 지상 4 · 던전 6, 그 지도에 들어간 뒤 480틱(8초)마다 한 번, 모든 플레이어에서 160px, 지상은 오염 구역과 둘레 2칸, 던전은 도착점에서 걸어서 14칸 이상(M4-fix: 코드 그대로 `>=`, 문장만 고침). 늘 빛 밖. 플레이어가 있는 지도만 흐름(M4-fix: 다시 들어와도 그때부터 480틱, 아래 "M4-fix 빈 지도") | game-concept §9.3 "스폰 억제"(제단 반경), ○ §5 "오염원 … 슬라이스에서는 고정 오염 구역". 나머지 문서에 없음 |
| M4a 이단의 제단 | `SHRINE_HP`, `SHRINE_STOPS_SPAWNS`, `WorldData.PLACEABLE_SHRINE_BROKEN` | HP 150, 근접·화살·빛 탄에 맞음, 0이면 부서진 제단(여전히 막음), 부서지면 던전 스폰 멈춤. 불은 꺼진 그대로 | ● §3.0 팔라딘 줄 "오염 원천은 누구나 전투로 파괴 가능", ○ game-concept §12 "첫 던전 1개 (= 첫 오염 원천)" (부순 뒤는 문서에 없음), ? 이단 쪽 불 색 (brief §5.7) |
| M4a 쓰러진 몸의 표식 | `RigData.hides_signature` | 사망 시트(다운·누움)에서 표식 레이어를 숨김 | 문서에 없음. ● R21 "클래스는 표식 장비로 읽는다"와 어긋나는 쪽이라 사람이 본다 (03-pixel "동작 중 표식 붙이기 시험": 눕는 몸에 선 표식은 이동만으로 붙일 수 없음) |
| M4a 세션 | `Main`(아레나는 혼자 할 때만), 전송 형식 v4 그대로 | 세션에서는 적·피해·대시·시작 무기·사망 가방 없음, 공격은 M2b처럼 몸 동작만. **M4b에서 이 줄은 끝났다**: 세션에서도 호스트가 정한다(위 "M4b: 세션의 전투", 아래 M4b 줄) | M4a 지시 "local / offline first" (M3a 세션 줄과 같음) → ● 호스트 권한 game-concept §13 (M4b 지시) |
| M4a 그림 자리 표시 | `CombatView`, `FixtureView`, `Hud`, `Player.HIT_FLASH`, `ItemIcons` `holy_light` | 화살·빛 탄·맞은 깜빡임·HP와 다운 막대·카운트다운·성광 아이콘 = 코드 그림. 가방 = 04-env `prop_sack_small_v03`, 부서진 제단 = `heretic_shrine_v02` 판 + `prop_bone_pile_a_v02` | 그림 없음 (assets/에 없다. 사람이 그림을 정하면 바꾼다) |
| M4b 판정 | `SessionHost.tick` → `Arena._knife`·`player_attack`·`_step_shot` (호스트 상태로) | **호스트 시간, 되감기 없음**: 이단의 칼은 호스트의 플레이어 위치·무적으로, 플레이어의 공격은 호스트의 이단 위치로 그 틱에 푼다. 잰 효과: 예고 500ms에서 예고를 본 뒤 대시로 피할 수 있는 시간 = 한 방향 지연 0 / 50 / 100 / 150ms에 500 / 400 / 300 / 200ms. 3틱 지연에서 쫓는 이단을 최대 6.9px 떨어져 그림 | 문서에 없음 (● gameplay-design §2.1 실시간·에임형, ● game-concept §13 호스트 권한. 되감기를 할지는 문서에 없음) |
| M4b 적 그리기 | `NET_ENEMY_WINDUP_FRESH`, `NetCombat.sample` (`NET_INTERP_DELAY_MS` 그대로) | 위치·HP·피격·사망·깜빡임·남의 화살은 다른 플레이어처럼 100ms 뒤, **공격(예고)과 자기 화살은 바로**. 끄면 예고도 100ms 뒤(피할 시간이 100ms 짧아짐, 위 줄) | 문서에 없음 |
| M4b 다운 중 요청 | `SessionHost.run_frame` (`WHY_DOWN`) | 다운·사망 중 타일 요청(사용·줍기·버리기·오가기)은 `down`으로 거부, 고르기(Q/E)·디버그 주기는 됨. 대시·경직 중 사용은 `busy` | 문서에 없음 (M4a "다운 중" 줄을 호스트 검사로) |
| M4b 세션의 싸우는 지도 | `SessionHost._step_arenas` | 사람이 있는 지도의 아레나만 흐른다(혼자 할 때와 같음): 아무도 없는 지도의 이단은 기다리고 스폰도 없다. **M4-fix**: 기다리기 전에 한 번 비운다(아래 "M4-fix 빈 지도"). 이 줄의 값은 그대로 | 문서에 없음 (M4a "스폰"·"아레나 시간" 줄 그대로) |
| M4-fix 화살 조준·맞는 상자 | `Combat.aim_origin`, `Combat.shot_hits_body`, `BODY_HIT_RADIUS_PX`, `SHOT_DRAW_LIFT_PX`, `BODY_HIT_HEIGHT_PX` | 조준(조준 코드) = 화살이 그려져 나가는 점(몸 점 = 발 2px 위, 그 12px 위 = 발 14px 위) → 마우스. 화살은 바닥 점 12px 위에 그리고, 그린 화살이 그린 몸 상자(발 좌우 8px, 발에서 위로 28px = 이단 걷기 그림의 불투명 3~31행에서 잼) 안에 들면 맞음. 그래서 그린 화살이 마우스 커서를 지나고 이단 그림 어디를 눌러도 맞는다. 8px·12px는 M4a 구현 표 "맞는 점"·"화살 그리기"의 값 그대로 이 줄로 옮김(맞는지를 정하는 값이라), 28px는 새 값. 근접은 그대로(발끼리 거리·호, 조준만 이 점에서) | 문서에 없음 (● gameplay-design §2.1 R12 "에임형(스킬샷)"의 에이전트 해석: 보이는 화살이 마우스를 지나고 보이는 몸에 닿으면 맞는다) |
| M4-fix 빈 지도 | `Arena.idle_tick`·`on_emptied` (`SessionHost._step_arenas`, `Main.step_combat`) | 지도의 마지막 사람이 떠나면 그 아레나를 한 번 비운다: 진행 중인 공격은 칼 없이 끝(공격 뒤 쉼 45틱이 이어짐), 경직 끝, 표적·가장자리 지켜보기 잊음(집으로 가던 것은 그대로), 날던 화살·빛 탄 없앰, 스폰 시계 0부터(그 지도에 다시 들어간 뒤 480틱), 시체는 남음. 그다음은 "M4b 세션의 싸우는 지도"대로 기다림 (M6-fix: 날던 병·이단의 독은 아래 "M6-fix 빈 지도의 병과 독") | 문서에 없음 (계단으로 도망쳤다 돌아오는 사람이 멈춰 있던 예고에 바로 맞지 않게. 다른 길: 공격이 끝날 때까지 지도를 더 돌리기, 막 들어온 사람에게 잠깐 무적) |
| M4-fix 빛 안에서 쏘인 이단 | `Arena._step_heretic` (`HereticSim.watch_ticks`) | 가장자리 지켜보기 4초는 지켜보기 시작부터 센다. 빛 안에서 맞은 경직 동안도 세고 맞아도 처음부터 세지 않아 4초가 차면 집으로 간다. 표적이 없는(집에 서 있던, 집으로 가던, 지켜보기를 마친) 이단은 빛 안에서 맞아도 쫓지 않는다(빛 안의 사람은 표적이 아님). 그래서 빛 안의 아처·성직자는 가장자리 4초·집으로 가는 동안·사거리 안 집에 선 이단을 맞지 않고 칠 수 있다(시험: 2초마다 맞혀도 240틱 뒤 집으로) | 문서에 없음. "M4a 빛 가장자리"(4초 그대로)의 뜻을 코드가 지키게 함. **판정 기준 "제단의 빛이 '안전'으로 읽히는가"(game-concept §12)에 바로 닿으니 사람이 본다**: 빛 안에서 쏘면 이단이 물러날지(빛 밖에서 표적을 버림), 쏜 사람을 빛 밖에서 기다릴지, 지금처럼 둘지 |
| M4b 던전에서 죽으면 | `SessionHost._respawn` | 지상의 자기 스폰 자리에서 부활하고 클라이언트는 지상을 받는다(지도 들어옴). 그 클라이언트에게 앞 지도를 보내는 중이면 끝날 때까지 기다림. 가방은 던전에 | ● §2.6 "부활 지점: 제단" (M4a "부활" 줄과 같음) |
| M2b 디버그 주기·버리기 | `NetSession.gives_allowed` | 클라이언트의 주기 요청(F5, `--give`)과 버리기 요청(F7, M2-fix)은 호스트가 디버그 빌드(에디터 실행)이거나 `--test-allow-give`일 때만 | 문서에 없음 (M2b 지시 "debug give in test builds only". 버리기도 디버그 키라 같이 묶었다) |
| M2b 다시 참가 | `SessionHost` | 다시 참가해도 인벤토리가 이어지지 않는다(새 참가자는 빈 인벤토리, 나간 사람의 인벤토리는 사라짐) | 문서에 없음 (M1에 다시 참가 기억이 없음, 저장은 M2 밖) |
| M6a 키 | `project.godot` 입력 `skill_1`(새), `toggle_inventory`·`move_up`/`move_down`·`interact`·`ui_cancel`(제작 창이 열린 동안, `Main._crafting_input`), `Player.make_frame` | Tab = 작업대 2칸 안이면 제작 창(+ 인벤토리), 아니면 M2a 그대로 인벤토리. 창이 열린 동안 W / S(↑ / ↓) = 줄 고르기, F 또는 Enter = 만들기, 마우스 올리기 = 고르기·좌클릭 = 만들기, Tab 또는 Esc = 닫기, 캐릭터는 서 있음(Q/E는 됨). 물약을 고르고 좌클릭 = 마시기(누르고 있어도 한 번). **1 = 약제 투척**(고른 물약을 마우스 쪽으로). 우클릭은 쓰지 않음. **M6b**: 세션에서도 같은 키(창이 열린 동안 세션의 입력도 서 있음, 만들기는 호스트에게 가는 요청). M7a: 값 그대로, 작업대 셋도 같은 Tab이고 작업대 없는 곳의 Tab은 손 레시피가 해금된 뒤 손 제작 창(+ 인벤토리, 혼자 할 때만: "M7a 기본 작업대 얻기") | ○ gameplay-design §1 키 초안("Tab 인벤토리·제작", "1 2 3 스킬", "우클릭 보조 동작 (클래스별)", "F 상호작용 (… 작업대 …)"), ○ §2.2 추천 "1. 정체성 스킬 — 약초사 약제 투척". 1을 던지기에 쓴 것은 초안의 "1 = 스킬"과 맞추고, 우클릭(클래스 보조 동작)은 비워 둠. 창이 열린 동안 W/S·F를 창이 가져가는 것과 Enter·Esc는 초안에 없음 |
| M6a 작업대 손 닿음 | `STATION_REACH_TILES`, `Crafting.station_near` | 발 칸에서 작업대 자리까지 2칸(체비셰프) 안, 가장 가까운 작업대. 멀어지거나 다운되거나 지도를 옮기면 창이 닫힘 | ○ gameplay-design §3.5 "작업대 근처에서 Tab" (거리 없음) |
| M6a 레시피 해금 | `RECIPES_UNLOCK_ON_FIRST_GET`, `Inventory.seen` | **켬**: 입력 아이템을 모두 한 번이라도 인벤토리에 넣어 본 플레이어에게 그 레시피가 보인다(아무 등급, 없어져도 남음, 저장 없음). 끄면 처음부터 모두 보임. 기본값 이유: 문서가 내놓은 유일한 규칙이고, 슬라이스의 입력은 야생 약초라 줍기가 고리의 첫걸음이어서 비용이 없다(해 보고 사람이 정하게) | ○ gameplay-design §3.5 "레시피는 재료를 처음 획득했을 때 해금 (그라운디드 분석기 방식)" |
| M6a 자리가 없을 때 | `Crafting.refusal`, `craft` | 입력을 뺀 뒤에도 출력이 들어갈 자리가 없으면 거부하고 아무것도 바꾸지 않음(땅에 떨어뜨리지 않음). 입력은 뒤 칸부터 뺌 | 문서에 없음 |
| M6a 조제대 | `ALCHEMY_FOOTPRINT`, `WorldData.PLACEABLE_ALCHEMY`, `WorldItems.place`·`place_rect`, `FixtureView` | 3×1 자리, 막음, 04-env `alchemy_table_v05` 그림(불투명 맨 아래 줄이 자리 아래 변, 뒤 판·병이 위 칸에 걸침). 목표 칸 = 자리 아래 줄 가운데, 세 칸 모두 빈 바닥·드롭 없음, 몸(놓는 사람·다른 플레이어·이단의 발)과 겹치지 않음, 다른 조제대에 닿지 않음. **M6-fix**: 사람이 나타나는 자리도 덮지 않음, 놓으면 영구(아래 "M6-fix 조제대가 비워 두는 자리") | ○ game-concept §9.7 "조제는 연금술대 자리의 조제대", ○ brief §5.7 범위 표 "약초사 조제대" (크기·놓는 규칙은 문서에 없음) |
| M6a 조제대 얻기 | `ItemDB` `alchemy_table`(종류 "놓는 것", 묶음 99, 아이콘 코드), `--give` | 디버그 아이템을 `--give=alchemy_table`로 받아 횃불처럼 놓는다. 생성기·F5 묶음에는 없음(지상 해시 그대로). 세션에서는 호스트가 `alchemy table offline only`로 거부(M6b). **M6b에서 바뀜**: 세션에서도 놓는다(호스트가 `WorldItems.place`로 검사, 그 지도의 편집). 얻는 길(디버그 아이템)은 그대로 | 문서에 없음. 다른 길: 제단 둘레에 하나 생성(지상 해시 갱신), 상인(M8), 작업대에서 만들기(M7) |
| M6a 물약과 레시피 | `POTION_HERBS`, `STACK_POTION`, `Crafting.recipes` | 물약 셋(회복·버프·독), 야생 약초 2개 → 물약 1개, 등급은 입력을 따름(일반 → 일반, 상급 → 상급, 섞지 않음), 묶음 10 | ● 물약 = 작물 하나에 하나(game-concept §12 R28), ○ "약제 2~3종"(§12). 수·묶음은 문서에 없음. 야생 약초를 쓴 것은 M6 지시(농사 작물은 M5) |
| M6a 누가 만드나 | `COMMON_POTIONS_ANYONE`, `Crafting.herbalist_only` | 상급 셋과 독(일반·상급)은 약초사만(●). 일반 회복·버프는 **누구나**(켬) | ● gameplay-design §3.0 R11 약초사 줄 "상급·최상급 약제, 상태이상 약제"는 클래스 전용. 일반 물약을 다른 클래스가 만들 수 있는지는 문서에 없다: 같은 줄의 "공용 수행 … 일반 등급 약초만"을 동사가 아니라 등급을 막는 것으로 읽음. 끄면 모두 약초사만 |
| M6a 마시기 | `DRINK_ANIM`, `DRINK_EFFECT_FRAME`, `DRINK_AT_FULL_HP`, `DRINK_POISON_HARMS`, `Potions.drink_refusal` | 좌클릭(한 번), **마법 동작을 빌려 씀**(마시는 그림 없음), 4번째 프레임에 쓰임(그 전에 맞으면 안 쓰임), 가득 찬 HP의 회복은 거부(쓰지 않음, 효과 프레임에서도 다시 봄), 다운·사망 중 안 됨, 독 물약은 마신 사람을 중독(끄면 거부. 그 독이 다운·사망까지 갈 수 있음은 아래 "M6-fix 플레이어의 독") | 문서에 없음 (gameplay-design §3.8 "마시거나 던진다"까지. 마시는 동작은 brief §5.6 슬라이스 몸 동작 11개에 없다) |
| M6a 회복·버프 수치 | `POTION_HEAL_HP`, `BUFF_SPEED_PCT`, `BUFF_TICKS` | 회복 30 / 50 HP(일반 / 상급, 최대를 넘지 않음). 버프 = **걷기 속도**(대시는 그대로) 125% / 140%, 20초 / 30초 | 문서에 없음 (버프 하나를 고르라는 M6 지시: 걷기 속도를 고른 이유는 혼자서도 바로 보이고 공유 시뮬레이션의 한 곳이라서) |
| M6a 독 | `POISON_DAMAGE`, `POISON_INTERVAL_TICKS`, `POISON_TICKS` | 30틱(0.5초)마다 2 / 3, 5초(10번, 합 20 / 30. 이단 HP 40), 첫 피해는 한 간격 뒤. 독 피해는 HP만: 경직·무적·방어 없음, 무적에 막히지 않음, 동작·공격을 끊지 않음(플레이어를 0으로 만들면: 아래 "M6-fix 플레이어의 독") | ○ gameplay-design §2.4 "상태이상: 약초사 담당. 중독·둔화·취약·출혈 4종으로 시작" (수치 없음. M6a는 독 하나) |
| M6a 효과 겹침·끝남 | `EFFECT_REFRESH_KEEPS_STRONGER`, `EFFECTS_END_ON_DOWN` | 다시 걸리면 남은 시간은 긴 쪽, 세기는 큰 쪽(겹치지 않음, 독은 박자 이어 감). 플레이어는 다운(따라서 사망)에 효과가 끝나고 부활에도 없음, 이단의 독은 죽으면 끝. 다운·사망 중에는 걸리지 않음. **지도를 옮겨도 이어짐**(M6-fix에 적음: `Player.set_world`는 vitals를 그대로 둔다, 시험 `test_potions.gd`) | 문서에 없음 |
| M6a 투척 | `THROW_HERBALIST_ONLY`, `THROW_RANGE_PX`, `THROW_SPEED`, `THROW_SPLASH_RADIUS_PX`, `THROW_RELEASE_FRAME`, `Arena.throw_potion`·`_step_flask`·`_splash` | 약초사만, 고른 물약을 마우스 쪽으로 최대 96px(6칸), 192px/s로 몸 위를 넘어 날고 벽(화살이 멈추는 칸)에 막힘, 던지기 동작 4번째 프레임에 손을 떠남(그때 하나 씀), 터지면 반경 24px(1.5칸) 안 벽 없이 닿는 몸: 회복·버프는 서 있는 플레이어(던진 사람도), 독은 이단(아군 사격 끔이라 플레이어 안 됨) | ○ gameplay-design §2.2 추천 "정체성 스킬 — 약초사 약제 투척", ● §2.1 에임형, M4a "아군 사격" 줄 그대로. 사거리·속도·반경·누가 던지는지는 문서에 없음. M6-fix에 적음: ○ §2.1의 "힐과 버프만 '가까운 아군 자동 대상'"과 다르다: 회복·버프 병도 마우스 점에 떨어져 반경 안을 맞히는 에임형이고 자동 대상 길은 없다(사람이 정할 것: 자동 대상으로 하면 `Potions.throw_target`이 가까운 아군의 몸 점을 고르게 된다) |
| M6a 세션 | `Player.potions_on`, `SessionHost._place`, `WorldItems.use_action` | 세션에서는 제작·마시기·던지기·효과 없음(Tab은 인벤토리, 1·물약 좌클릭은 프레임을 만들지 않음, 호스트는 물약 USE를 `not a tool`, 조제대를 `alchemy table offline only`로 거부). 전송 형식 v5 그대로(효과는 vitals 블록에 없음). M6b에서 켠다. **M6b에서 이 줄은 끝났다**: 세션에서도 호스트가 정한다(위 "M6b: 세션의 제작 · 물약", 아래 M6b 줄) | M6a 지시 "local / offline first" (M3a·M4a 세션 줄과 같음) → ● 호스트 권한 game-concept §13 (M6b) |
| M6a 그림 자리 표시 | `ItemIcons.MAPS["alchemy_table"]`, `CombatView` 병·터짐, `EffectMarks`, `CraftingPanel`, `ItemDB.STRIP_POTIONS` | 조제대 아이콘(작은 탁자 + 물약 셋), 날아가는 병(그 물약 아이콘을 포물선에), 터짐(색 방울 3프레임), 머리 위·HUD의 버프·독 표시(7×7), 제작 창 = 코드 그림. 물약 아이콘은 04-env 작은 것 묶음 v04 띠에서 자름 | 그림 없음 (assets/에 날아가는 병·터짐·효과 표시·UI가 없다. 마시는 동작도 없다. 사람이 그림을 정하면 바꾼다) |
| M6b 던진 회복과 다운 | `THROW_HEAL_REVIVES`, `Arena.splash_revives` | **끔**: 던진 회복 물약은 서 있는 플레이어만 낫게 하고 다운된 사람은 일으키지 않는다(다운된 사람은 F 소생 그대로, M6a의 터짐 규칙 그대로). 켜면 터짐 안의 다운된 사람이 일어나(`revive_now`: HP 30, 무적) 그 물약의 회복을 받는다 | 문서에 없음 (● gameplay-design §2.6이 소생을 "아군이 F 누르고 있기, 성직자는 즉시" 하나로 둠. 기본값을 끔으로 둔 이유: 6칸 밖에서 일으키는 물약은 §2.6의 소생 흐름에 없는 두 번째 길이고, 성직자의 즉시 소생과 겹친다) |
| M6-fix 조제대가 비워 두는 자리 | `WorldItems.reserved_feet`·`WHY_RESERVED` (`WorldItems.place`) | 막는 설치물(조제대)은 사람이 걷지 않고 나타나는 발 자리의 발 상자를 덮을 수 없다(`where players appear`): 그 지도의 도착점(지상 입구·던전 출구 계단 바로 아래, `DungeonGen.arrival_below`)과 제단이 있는 지도의 `SPAWN_SLOTS` 아홉 자리(참가·부활). **놓은 조제대는 영구**: 줍기·부수기·채굴로 지울 수 없다(지우는 규칙이 없음) | 문서에 없음 (조제대를 놓는 규칙 자체가 문서에 없다, 위 "M6a 조제대". 다른 길: 그 자리를 덮게 두고 나타나는 사람을 가장 가까운 빈 칸으로 옮기기, 조제대를 줍거나 부술 수 있게 하기) |
| M6-fix 플레이어의 독 | `PlayerSim._poison_hit`, `DRINK_POISON_HARMS`, `Potions.drink_refusal` | **독은 플레이어를 다운시킬 수 있다**(0 HP = 다운, 그 뒤 M4 흐름: 30초 뒤 사망·가방. 혼자면 일으킬 사람이 없어 사망까지). 지금 플레이어가 독에 걸리는 길은 독 물약을 마시는 것뿐이고(아군 사격 끔), 그 마시기는 HP가 낮아도 거부하지 않는다(다른 물약과 같은 좌클릭: 던지려고 독을 든 약초사가 1 대신 좌클릭하면 스스로 중독). 일반 독 20(2 × 10)이면 HP 20 이하는 누구든 다운, 상급 30 | 문서에 없음 (○ gameplay-design §2.4 상태이상은 약초사 담당이라고만. 다른 길: 독은 HP 1에서 멈춤, 다운시킬 독 마시기는 거부, 독 물약은 늘 마실 수 없음 `DRINK_POISON_HARMS` 끔) |
| M6-fix 빈 지도의 병과 독 | `Arena.on_emptied`, `HereticSim.poison_*` | 지도의 마지막 사람이 떠나 아레나를 비울 때(M4-fix): **날던 병은 터짐 없이 사라지고 그 물약은 돌려주지 않는다**(손을 떠날 때 이미 쓰였다. 사건도 보내지 않음: 볼 사람이 없다), **이단의 독은 멈췄다가** 누가 돌아와 그 지도가 다시 돌 때 남은 만큼 들어간다(그 처치는 처음 던진 사람의 것: 그 사람이 떠났거나 세션에서 나갔어도. 나갔으면 로그 자리 −1). 경직·깜빡임은 비울 때 끝나지만 독은 끝나지 않는다 | 문서에 없음 (M4-fix의 빈 지도 규칙을 병·독에 이은 것. 다른 길: 비울 때 독도 끝냄, 날던 병은 비울 때 그 자리에서 터뜨림) |
| M6-fix 제작 창이 열린 동안 | `Player.ui_locked`, `Main._crafting_input`, `Main._check_crafting`, `SessionBots.local_action` | 창이 열린 동안 캐릭터는 서 있고 막을 수 없다: 걷기·대시·사용·F·1 없음(Q/E는 됨). 창은 Tab·Esc, 다운, 지도 옮김, 작업대가 없어지거나 손 닿지 않을 때만 닫히고 **맞아도 닫히지 않는다**(맞은 사람은 Tab·Esc를 누를 때까지 서 있다) | ○ gameplay-design §3.5 "작업대 근처에서 Tab"까지 (열린 동안 움직일 수 있는지·맞으면 닫히는지는 문서에 없음. 구현 표의 "제작 창이 열린 동안" 줄에서 옮김. 다른 길: 맞으면 닫힘, 열린 채 걷기는 되고 멀어지면 닫힘) |
| M5a 밭은 빛 안에서만 | `TILL_ONLY_IN_LIGHT`, `Farming.in_light` | 켬: 칸의 네 모서리가 모두 안전 반경 안(M1 생성기의 흙 규칙과 같다. 시드 1: 129칸, 제단 포함). 끄면 지상의 어느 풀이든(재 옆은 그림 규칙으로 여전히 안 됨) | ○ game-concept §9.7·gameplay-design §3.8 "밭은 제단 빛(반경) 안에서만 일군다". "안"이 칸 전체인지 가운데인지는 문서에 없다 |
| M5a 일굴 수 있는 칸 | `Farming.till_refusal` | 지상의 풀만(설치물·채집물 없음). M1 생성기의 흙 덩어리는 이미 일군 밭(바로 심음). 재 `corrupted ground`, 던전 `no ground to till`. 사람이 나타나는 자리도 일굼(흙은 막지 않음) | 문서에 없음 |
| M5a 되돌리기·흙이 마르는지 | (없음), `EditLog.check` | 일군 흙은 풀로 돌아가지 않는다(괭이로 되돌리기 없음, 저절로 없음). 디버그 바닥 편집도 밭이 있는 흙은 거부 | 문서에 없음 |
| M5a 씨앗 | `ItemDB` `seed_*`(종류 `SEED`, 등급 없음), `STACK_SEED` | 작물마다 하나, 묶음 99, 아이콘 = 04-env 띠의 씨앗 봉투 | ● 작물 셋(game-concept §12 R28). 씨앗 아이템·묶음·등급은 문서에 없음 |
| M5a 씨앗 얻기 | `SEEDS_PER_WILD_HERB`, `Main.seed_from_wild`(M5c: `Farming.seeds_from_wild`, 호스트도 같은 규칙), `CROP_HARVEST_SEEDS` | 야생 약초를 그 자리에서 캐면 그 작물 씨앗 1(혼자 할 때. 떨어진 약초를 주우면 없음), 수확하면 1, 시험은 `--give`. F5 묶음에는 없음 | 문서에 없음(상인 M8). 다른 길: 확률로(시드로 정한 난수), 상인, 처음부터 인벤토리에 |
| M5a 심기 | `Farming.plant_refusal`, `PLANT_ONLY_WHERE_IT_GROWS` | 좌클릭 한 번에 씨앗 하나, 일군 흙·작물 없음·설치물 없음. 시들 자리(빛 밖·오염 2칸 안)는 거부(켬). 끄면 어느 흙이든(심자마자 시듦) | ● 누가 무엇을 심나(game-concept §12 R37) 그대로: 회복·버프 약초는 누구나, 독초 씨앗은 약초사만. 시들 자리 거부는 문서에 없음 |
| M5a 물 | `WATER_TICKS`, `WATER_IMPACT_FRAME`, `Farm.water` | 60초 젖음, 다시 주면 처음부터, 빈 흙도 젖음, 물뿌리개는 비지 않음, 물뿌리개 동작의 6번째 프레임 | ○ §9.7·§3.8 "물주기". 시간·물 긷기는 문서에 없음 |
| M5a 자라기 | `CROP_STAGE_TICKS`, `Farm.step` | 젖고 시들지 않은 동안만 자람, 단계마다 40초(0 → 4 = 160초), 익으면 그대로(썩지 않음) | ○ §9.7 "씨앗 → 성장 4~6단계 → 수확물"(04-env `crops_v03`은 0~4단계). 시간은 문서에 없음 |
| M5a 약초사의 빠른 성장 | `CROP_HERBALIST_GROWTH_PCT`, 식생 값의 "약초사가 심음" 표지 | 약초사가 **심은** 작물이 200%(단계마다 20초) | ○ §9.7·§3.8 "약초사는 성장이 빠르고". 얼마나, 누구 기준(심은 사람·물 준 사람)인지는 문서에 없음 |
| M5a 수확 등급 | `CROP_GRADE_BY_HARVESTER`, `Farming.harvest_grade`, `Farming.harvest_refusal`(클래스 검사 없음) | 거두는 사람(켬): 약초사가 거두면 상급, 다른 클래스 일반. 끄면 심은 사람. **누가 거두나**(M5-fix에서 적음, 동작은 그대로): 누구나 어느 작물이든 거둔다, 약초사가 심은 독초도(약초사는 상급, 다른 클래스 일반) | ○ §9.7 "약초사는 … 상급 등급을 거두며", ● gameplay-design §3.4(야생 약초는 캐는 사람), ● §3.0 "공용 수행 … 일반 등급 약초만", ● R37 "누구나 일반 등급으로 심고 거둔다". R37은 독초 씨앗을 **심는** 사람만 약초사로 정했고 독초를 누가 거두는지는 문서에 없다. 다른 길: 독초는 약초사만 거둠 |
| M5a 수확물 | `CROP_HARVEST_HERBS`, `CROP_HARVEST_SEEDS`, `Farming.HERBS` | 야생 약초와 같은 아이템 2개 + 씨앗 1개, 안 들어가면 그 칸에 드롭(`MAX_DROPS`면 사라짐) | ● 물약 = 작물 하나에 하나(game-concept §12 R28). 수·드롭은 문서에 없음 |
| M5a 낫 규칙 | `Farming.is_harvest_swing`, `Main._on_action_impact` | 작물이 있는 칸(어느 단계든, 시들어도)을 겨눈 낫은 수확만(익지 않음·시듦은 거부, 공격 없음), 아니면 무기 | ○ gameplay-design §3.8 "낫으로 수확", M4a 임시값 "약초사 낫"(무기) |
| M5a 시듦 | `CROP_CORRUPTION_REACH_TILES`, `Farming.withers_at`, `Farm.step` | 빛 밖(네 모서리 중 하나라도 밖)이거나 오염 2칸 안(체비셰프, 자기 칸 포함)이면 그 틱에 시듦: 자람 멈춤, 거둘 수 없음, 물은 마름. 원인이 모두 사라지는 틱에 되살아남(단계·자란 틱 이어감). 밭은 남음 | ○ §9.7·§3.8 "빛 밖에 남은 밭이나 오염에 닿은 작물은 시든다. 팔라딘이 정화하면 되살아난다". "닿은"·때·되살아나는 조건은 문서에 없음. ○ §9.7 "밭은 남고"(구현한 기본값. M5-fix: ●로 잘못 적었던 것을 고침, §9.7은 "○ 제안, R23" 절) |
| M5a 시간이 흐르는 지도 | `FARM_RUNS_WITHOUT_PLAYERS`, `Main.step_farms` | 모든 지도에서 매 틱(켬). 끄면 사람이 있는 지도만(이단처럼) | 문서에 없음 |
| M5a 일구기 프레임 | `HOE_IMPACT_FRAME` | 괭이 동작의 4번째 프레임(18틱째) | 문서에 없음 (03-pixel 괭이 시트에서 날이 흙에 닿는 칸) |
| M5a 세션 (M5c에서 대체: 아래 "M5c" 줄, 세션에서도 호스트가 같은 규칙) | `Player.farming_on`, `SessionHost.run_frame` (`Farming.WHY_OFFLINE`) | 세션은 농장이 없다: 씨앗 USE 거부, 괭이·물뿌리개는 동작만, 낫은 무기, 야생 약초에 씨앗 없음. M5c에서 켬 | (M5a 지시) |
| M5a 그림 자리 표시 | `FieldView` | 시든 그림은 다 자란 것 하나(어린 작물도 그것), 작물 흙더미 색은 코드 색 표, 수확 다발 칸은 안 씀 | ● brief §5.7 R29 시든 작물 색. 어린 작물의 시든 그림은 없다 |
| M5b 성수 | `ItemDB` `holy_water`(종류 `CONSUMABLE`), `STACK_HOLY_WATER`, `HOLY_WATER_RADIUS_TILES`, `HOLY_WATER_ANIM`·`HOLY_WATER_EFFECT_FRAME`, `Purify.pour` | 하나가 목표 칸 둘레 체비셰프 1칸(3×3)의 오염 칸을 정화. 손 닿는 칸, 그 안에 오염이 없으면 거부(안 씀). 묶음 10, 등급 없음. 마법 동작의 4번째 프레임에 씀(그 전에 맞으면 안 씀) | ● gameplay-design §3.0 R11 "누구나 성수로 타일 몇 개 정화". 몇 개·붓는 동작·묶음은 문서에 없음 |
| M5b 성수 얻기 | `--give=holy_water:<n>` | 디버그로만(M6a 조제대처럼). F5 묶음·레시피·상점 없음 | ● §3.0 대체 수단 "상점의 성수 (소량 정화, 비쌈)"(상인 M8). 공용 수행은 "성수로"만 말하고 만드는 법이 없다. 다른 길: 조제대 레시피(재료가 문서에 없다), 시작 인벤토리, F5 묶음 |
| M5b 채널링 시작 | `PURIFY_START_REACH_TILES`, `Main.pick_up`, `Player.request_channel`, `Purify.channel_refusal` | F는 먼저 줍기(M2b). 목표 칸에 주울 것이 없고(`nothing there`) 팔라딘의 발 칸이나 그 8이웃에 오염 칸이 있으면 다음 프레임에 시작. 서 있고 동작·대시·경직·다운이 아니고 제단을 들지 않았을 때 | ● §3.0 "클래스 전용: 광역 정화 채널링"(팔라딘). ○ §1 "F 상호작용 (… 정화 시작)", ○ §3.7 "오염 타일 위에서 채널링". 옆에서도 되는지는 문서에 없음 |
| M5b 채널링 시간·반지름 | `PURIFY_CHANNEL_TICKS`, `PURIFY_RADIUS_TILES`, `Purify.channel_area` | 180틱(3초) 서 있으면 발 칸 가운데에서 3칸 안에 가운데가 드는 칸(원판 29칸)의 오염 칸을 정화 | ○ §3.7 "반경 N타일"(N·시간은 문서에 없음) |
| M5b 채널링이 끊기는 것 | `PlayerSim.step`·`hurt`·`_go_down`, `Player.set_world` | 그 프레임의 움직이기·대시·사용(그 프레임은 평소대로), 맞음, 다운(독 틱도), 다른 지도. 끊기면 아무것도 정화 안 함 | 문서에 없음 (§3.6 기도의 "방해받으면 중단"과 같은 쪽) |
| M5b 채널링 자세 | `PURIFY_ANIM`, `Player.channel_frame` | 마법 동작(성직자 기도·치료)을 되풀이 | 그림 없음 (brief §5.6 표에 정화 동작이 없다) |
| M5b 정화된 땅 | `Purify.edits_for` | 오염 0 + 바닥 재 → 풀(그 자리에서). 그 위 채집물(재 버섯·금 간 돌·곰팡이 돌)은 그대로. 재오염·확산 없음 | ○ game-concept §5·§9.3 "정화가 반경 밖의 땅을 되찾는다", ○ §3.7 "슬라이스: 확산 없음". 재를 거쳐(시간을 두고) 풀이 되는지, 채집물이 어떻게 되는지는 문서에 없음. 다른 길: 깨끗한 재(바닥 재, 오염 0)로 두었다가 시간이 지나 풀, 채집물을 없앰 |
| M5b 제단 들기 | `ALTAR_PICKUP_HOLD_TICKS`, `ALTAR_MOVE_ANYONE`, `AltarMove.pickup_refusal`, `Main.step_altar_hold` | 누구나 손 닿는 제단 칸을 겨누고 F를 2초(120틱) 누르고 있으면 듦(놓거나 다른 데를 겨누면 처음부터). 지상만, 비용 없음 | ● game-concept §9.3 "위치 자유, 이동 자유". 누가·어떻게·비용·시간은 문서에 없음(§9.3 "제단을 옮겨 새 지역으로 전진"이 팀 이벤트). 다른 길: 팔라딘만(`ALTAR_MOVE_ANYONE` 끔), 재료 비용, 채널링처럼 끊기는 들기 |
| M5b 들고 있는 동안 | `WorldData.refresh_altar_rect`(제단 없음), M5c: `SessionHost._respawn`(호스트도 부활을 기다림), `Main._on_respawn_due`, `Player.carrying_altar` | **안전 반경 없음**(고른 쪽): 빛·안전 반경·이단의 빛 규칙·스폰 억제·부활 자리·조제대가 비워 두는 부활 자리가 없음, 밭은 모두 시듦, 죽은 사람은 놓일 때까지 부활을 기다림. 든 사람은 걷기·대시·F 줍기와 제작 창·버리기·핫바 고르기를 하고(M5-fix: "걷기·대시·F 줍기만"이라 적었던 문구를 고침, 동작은 그대로), 좌클릭 = 내려놓기(도구·물약·성수·던지기·채널링·오가기 없음), 속도 그대로 | 문서에 없음. 다른 길: 놓을 때까지 옛 자리의 빛이 남음, 든 사람이 느려짐 |
| M5b 내려놓기 | `AltarMove.place_rect`·`place_refusal` | 좌클릭: 목표 칸이 가까운 변인 3×3(가운데가 발 칸에서 그 방향으로 두 칸). 지상, 맵 안, 열린 땅(설치물·벽·드롭 없음), 오염·재 아님, 식생 없음(채집물·작물·젖은 흙. 마른 빈 흙은 됨), 누구의 발도 아래에 없음, 도착점 아님, 새 부활 자리 아홉이 설 수 있음, 새 빛 안에 살아 있는 이단 없음. 새 빛이 오염 칸을 덮는 것은 됨(M5-fix: 아래 "M5-fix 빛 아래 오염") | 문서에 없음 (M6-fix 조제대 규칙 + 이단은 빛에 들어가지 않는다는 M4a 규칙을 놓는 순간에도 지키려고) |
| M5b 든 사람이 다운되면 | `ALTAR_SET_DOWN_SEARCH_TILES`, `AltarMove.set_down_fallback`, `Main.check_carriers`·`set_altar_down`, `SessionHost._check_carriers` | 그 틱의 전투가 끝난 뒤(M5-fix: 혼자 할 때도 호스트와 같은 자리) 그 발 칸에서 가까운 고리부터(체비셰프 64칸까지, 고리 안은 줄 순서) 내려놓기 규칙(손 닿음 빼고)으로 처음 되는 자리에 저절로. 없으면 이단을 빼고, 그래도 없으면 마지막으로 서 있던 자리(그 자리가 되면 그 자리, 아니면 그 둘레). M5-fix: 어느 길도 놓기 규칙을 건너뛰지 않음(전에는 들었던 자리를 검사 없이 덮었다). 모두 없으면 든 채(일어나면 다시 찾음) | 문서에 없음. 다른 길: 들었던 자리로 돌아감, 그 자리에 떨어뜨려 아무나 다시 들게 |
| M5b 키 | `project.godot` 입력 `interact`, `use_item` (그대로), `AltarMove.hold_counts`, `Main.pick_up`·`SessionHost.wants_channel` | F = 줍기, 주울 것이 없으면 팔라딘의 채널링(M5-fix: 제단 칸을 겨눈 F는 채널링이 아님) / F 누르고 있기 = 제단 들기(M5-fix: 채널링이 도는 동안과 소생 거리 `REVIVE_REACH_PX` 안에 다운된 사람이 있는 동안은 세지 않음: 그 F는 소생이다. 비성직자의 5초 소생이 2초 들기보다 길어 소생 중에 제단이 들려 빛이 꺼졌다) / 성수 좌클릭 = 붓기 / 들고 있는 동안 좌클릭 = 내려놓기 | ○ gameplay-design §1 "F 상호작용 (줍기, 문, 작업대, 기도, 정화 시작)", ● §2.6 "아군이 F 홀드로 소생". F 하나가 여러 일일 때 무엇이 먼저인지는 문서에 없다. 다른 길: 제단 들기를 다른 키로, 소생보다 들기가 먼저 |
| M5b 세션 (M5c에서 대체: 아래 "M5c" 줄, 세션에서도 호스트가 같은 규칙) | `Player.purify_on`, `SessionHost.run_frame` (`Purify.WHY_OFFLINE`), `Main.step_altar_hold`(혼자 할 때만) | 세션은 정화·제단 옮기기가 없다: 성수 USE 거부, F 채널링 없음, F를 누르고 있어도 제단 그대로. M5c에서 켬 | (M5b 지시) |
| M5b 그림 자리 표시 | `PurifyView`, `AltarMark`, `AltarGhost`, `PURIFY_ANIM` | 채널링 자세(마법 동작), 정화의 금빛 테두리·점, 재 얼룩(04-env 풀 쪽 경계 장식을 빌려 씀), 든 제단 표시, 놓을 자리 표시 | 그림 없음 (정화 효과·든 제단·놓을 자리 그림이 04-env·03-pixel에 없다) |
| M5-fix 빛 아래 오염 | `ALTAR_LIGHT_MAY_COVER_CORRUPTION`, `AltarMove.light_corruption_refusal` | 켬: 제단은 자리(3×3)만 깨끗하면 놓여서 빛이 오염 칸을 덮을 수 있다. 그 오염은 남고(밀어내지 않음, 확산 없음: 정화로만 걷힘), 그 구역의 스폰 고리가 빛 가장자리 바로 밖까지 오고(빛 안은 아님, M4a), 빛 안이라도 오염 2칸 안의 작물은 시든다(시드 1 구역 옆 (52,6): 빛 안 오염 17칸, 빛 가장자리 1.5칸 안 스폰 칸 19개). 끄면 오염 칸 가운데가 새 가운데에서 안전 반경 + `ASH_CLEARANCE_TILES`(4칸, M1 생성기가 두는 여유) 안이면 거부(`corruption in its light`) | ○ game-concept §5 "제단(코어)의 안전 반경은 오염을 밀어낸다", ○ §9.3 "안전 반경(빛, 스폰 억제, 오염 저항)": 옮긴 빛이 오염 위에 오면 어떻게 되는지는 문서에 없다(M5b가 말없이 "그대로 둠"을 골랐던 것을 M5-fix에서 줄로). 켠 이유: ○ §9.7 "슬라이스는 … 고정 오염 구역 옆 밭으로 시험한다"는 빛이 구역 옆에 와야 되고(생성된 제단은 재까지 4칸이라 빛 안 밭이 오염에 닿을 일이 없다), 끄면 "오염에 닿은 작물 → 정화로 되살림" 고리가 플레이에서 생기지 않는다. 다른 길: 빛이 덮은 오염을 걷어 냄(밀어내기), 끔 |
| M5c 들고 있는 동안 참가 | `ALTAR_CARRIED_JOIN_AT_HOME`, `SessionHost.spawn_feet` | 켬: 제단을 든 동안 참가하는 사람은 **든 자리**(마지막으로 들어 올린 자리) 둘레의 부활·참가 자리에 나타난다. 끄면 든 사람의 발 둘레. M5-fix: 그 자리들은 들고 있는 동안에도 막는 설치물이 덮지 못하고(`SessionHost.carried_reserved_feet` → `where players appear`, 켰을 때), 그래도 막힌 자리는 슬롯 순서로 다음 설 수 있는 자리, 하나도 없으면 지상 도착점 | 문서에 없음 (● gameplay-design §2.6 "부활 지점: 제단"을 참가 자리에도 쓴 M1 규칙. 든 동안은 제단이 없어서 세션에서만 생기는 경우) |
| M5c 든 사람이 나감 | `ALTAR_SET_DOWN_WHEN_CARRIER_LEAVES`, `SessionHost.on_peer_disconnected` | 켬: 제단을 든 사람이 세션을 나가면 그 발 둘레에 다운 때와 같은 규칙으로 저절로 놓인다(M5b "든 사람이 다운되면"). 끄면 든 자리부터(M5-fix: 그 자리가 놓기 규칙으로 안 되면 그 둘레, 그다음 발 둘레. 전에는 검사 없이 덮었다). 놓을 곳이 하나도 없으면 들고 나간다(알려진 문제) | 문서에 없음 (세션에서만 생기는 경우: 제단이 그 사람과 같이 사라지면 안 된다) |
| M5c 호스트를 잃었을 때 제단 | `GameWorld.last_altar_rect`, `Main._go_offline_combat` → `restore_altar` | (M5-fix) 다른 사람이 제단을 든 채 호스트를 잃고 혼자 계속하면, 그 클라이언트의 월드가 마지막으로 본 제단 자리에 되놓는다(놓기 규칙, 안 되면 그 둘레, 본 적이 없으면 자기 발 둘레). 자기가 들고 있었으면 그대로 들고 혼자 놓는다 | 문서에 없음 (세션에서만 생기는 경우: 전에는 제단이 없어 죽으면 부활을 영영 기다렸다). 다른 길: 지상 도착점에 부활만 하고 제단은 없음, 자기 발 옆에 놓음 |
| M7a 작업대 체인 | `Config.STATION_RECIPES`, `Crafting._build_chain`, `WorldData.PLACEABLE_WORKBENCH`·`ANVIL`·`RELIC` | **세 단계**: 손(작업대 없음) → 기본 작업대 → 모루 → 성물 제작대. 레시피 열넷(아래 "M7a" 절의 표): 손에서 작업대(통나무 4), 작업대에서 널판(통나무 1 → 2)·모루(돌 10 + 철광석 2 + 널판 2)·창고(널판 8 + 철 주괴 1), 모루에서 제련 둘·1티어 장비 여섯·성물 제작대(널판 4 + 구리 주괴 2 + 철 주괴 1), 성물 제작대에서 횃불(구리 주괴 1 + 널판 1 → 4). 모두 누구나. 작업대마다 앞 작업대에서 만든다 | ○ gameplay-design §3.5 "기본 작업대 → 모루(대장간) → 성물 제작대 → (이후 티어)", ● game-concept §12 "작업대 체인 2~3단계"(셋을 골랐다: 문서의 체인 이름 셋이 다 있고, 성물 제작대 그림이 있어서). 재료·수·레시피는 문서에 없음 |
| M7a 기본 작업대 얻기 | `Crafting.HAND`, `Main.toggle_tab`, `--give=workbench` | **손 레시피**: 작업대에서 멀리서 Tab을 누르면, 손 레시피가 하나라도 해금됐을 때(통나무를 한 번이라도 가짐) 손 제작 창(머리 = 통나무 아이콘)과 인벤토리가 열린다. 해금 전에는 M2a 그대로 인벤토리. 세션에서는 열지 않음. 시험용 `--give=workbench`도 됨. F5 묶음에는 없음 | 문서에 없음. 고른 이유: 나무(M7b)가 들어오면 벤 통나무에서 바로 체인이 시작돼야 하고, 디버그 아이템만이면 M7b가 다시 손대야 한다. F5 묶음은 M3-fix가 비워 둔 칸이라 넣지 않았다. 다른 길: 디버그 아이템만(조제대처럼), 생성기에 하나 |
| M7a 성물 제작대 레시피 | `Config.STATION_RECIPES`의 "relic" 줄 | **횃불 하나만**(구리 주괴 1 + 널판 1 → 횃불 4) | ○ §3.5 이름만 있고 무엇을 만드는지는 문서에 없다. 슬라이스에서 성물 제작대가 만들 법한 것(기도 물품 M10, 제단 업그레이드 M12, 컬렉션 M11)은 모두 다른 단계라, 체인의 셋째 작업대로 두고 최소 레시피 하나를 줬다: 놓은 횃불의 그림이 04-env 놋쇠 랜턴이고 성물 제작대 그림에 만들다 만 놋쇠 등잔이 있으며, 조명은 누구나 짓는 것(○ §3.3). 성수는 넣지 않았다(● §3.0 팔라딘 줄의 대체 수단 = 상점 성수, M5b가 레시피를 두지 않은 이유 그대로). 다른 길: 체인을 둘(작업대 → 모루)로 멈춤 |
| M7a 제련 | `Config.STATION_RECIPES`의 `ingot_*` 줄 | 모루에서 광석 1 → 주괴 1(구리·철 따로). 새 화로 없음 | 문서에 없음(화로가 문서에 없어서 모루 = 대장간에 둠). 시드 1 던전의 광맥 칸은 47개(구리가 철보다 많다)라 1 : 1 |
| M7a 작업대 자리·그림 | `WORKBENCH_FOOTPRINT` 3×1, `ANVIL_FOOTPRINT` 2×1, `RELIC_BENCH_FOOTPRINT` 3×1, `FixtureView.FURNITURE` | 그림이 서는 자리(그림 너비 42·28·44px). 놓기 규칙은 조제대 그대로(빈 바닥, 발 없음, 사람이 나타나는 자리 아님, 같은 종류끼리 안 붙음, 다른 종류는 붙어도 됨, 던전도 됨). 막는다. 다시 줍거나 부술 수 없음 | 문서에 없음 (● R37 "건설 벽은 돌만"은 건설이라 M7b) |
| M7a 1티어 무기 | `GEAR_T1_BASE`, `GEAR_T1_DAMAGE_PCT`, `Gear.base`·`attack_damage` | 클래스 기본 무기마다 하나(`sword_t1`·`bow_t1`·`holy_light_t1`·`pickaxe_t1`·`sickle_t1`): 같은 몸 동작·같은 공격 모양·같은 맞는 프레임, 피해 **150%**(검 14 → 21, 활 12 → 18, 성광 10 → 15, 곡괭이 10 → 15, 낫 8 → 12). 1티어 곡괭이는 곡괭이와 똑같이 캐고(채굴력 그대로), 1티어 낫은 낫처럼 거둔다. 누구나 어떤 무기든(M4a 그대로). 모습은 기본 무기 그대로 | ● gameplay-design §3.5·§3.0 R11 "1티어는 누구나 모루에서"(수치·아이템은 문서에 없음), ● game-concept §12 R21 기본 외형만 |
| M7a 갑옷 | `ARMOR_T1_DEFENCE` 4, `ARMOR_MIN_DAMAGE` 1, `Inventory.armor`, `Gear.equip`·`unequip`·`after_armor` | 한 벌(`armor_t1`). 인벤토리 밖 **갑옷 칸 하나**(핫바 왼쪽에 보임). 핫바에서 고르고 좌클릭 = 입기(입던 것과 맞바꿈), 열린 인벤토리의 갑옷 칸 클릭 = 벗기(빈 칸이 없으면 거부). 입고 있고 부서지지 않았으면 이단의 칼 한 번에 4를 덜 받음(12 → 8, 1 밑으로는 안 내려감). 독은 덜지 않음 | ○ gameplay-design §2.4 "HP + 방어력(피해 감소)"(숫자·칸 없음). 외형 칸 분류(● game-concept §3 R21: 모자·상의 …)는 꾸미기라 쓰지 않았다 |
| M7a 내구도가 있는 것 | `GEAR_DURABILITY`, `ItemDB.ItemDef.durability`, `ItemStack.durability` | **1티어 장비만**(무기 120, 갑옷 100). M2~M4의 기본 도구·무기(곡괭이·괭이·낫·물뿌리개·검·활·성광)는 닳지 않는다 | ● §2.6 R12 "장착 장비는 유지하되 내구도 손상"(무엇이 닳는지·수치는 없음). 고른 이유: 기본 도구는 만드는 레시피가 없어서(상인 M8 전) 닳으면 클래스가 기본 공격·곡괭이를 잃는다 |
| M7a 사용 마모 | `GEAR_WEAR_PER_ATTACK` 1, `GEAR_WEAR_PER_HIT` 1, `Gear.wear_weapon`·`wear_armor` | 무기: 맞는 프레임의 공격마다 1(맞든 빗나가든. 1티어 곡괭이의 채굴·1티어 낫의 수확은 안 닳음). 갑옷: 맞은 칼(실제로 들어간 것)마다 1. 독·무적 중의 칼은 안 닳음 | 문서에 없음 |
| M7a 사망 마모 | `GEAR_DEATH_WEAR_PCT` 20, `Gear.wear_on_death` | 죽으면 지닌 내구도 있는 것 모두(입은 갑옷과 인벤토리의 1티어 무기)가 제자리에 남고 최대치의 20%(올림)를 잃는다(0 밑은 없음). 가방 규칙(M4a)은 그대로: 장비는 가방에 안 들어감 | ● §2.6 R12 "장착 장비는 유지하되 내구도 손상"(양은 없음). "장착"을 지닌 장비 전부로 읽음(핫바·가방 칸의 무기도) |
| M7a 부서진 장비 | `GEAR_BROKEN_UNUSABLE` | **끔**: 내구도 0이어도 쓸 수 있고 기본 아이템처럼(부서진 1티어 검 = 기본 검 14, 부서진 갑옷 = 방어 0). 켜면 부서진 것은 좌클릭이 아무것도 안 함(`broken`) | 문서에 없음 |
| M7a 수리 | `GEAR_REPAIR_MATERIAL`, `Crafting` `repair_*` 레시피 | 모루에서 누구나, 재료 하나(검·곡괭이·갑옷 = 철 주괴, 활·성광·낫 = 구리 주괴)로 지닌 것 중 가장 닳은 하나(입은 갑옷 포함)를 가득. 닳은 것이 있을 때만 창에 줄이 보임 | ● §2.6 "기술자 수리 = 기술자 일감"(기술자는 슬라이스에 없음, ● game-concept §12 R23) → ● §3.0 공용 수행 "누구나 … 낮은 효율"로 읽어 모루에서 누구나. 비용·장소는 문서에 없음 |
| M7a 디버그 버리기와 내구도 | `WorldItems.drop` (`WHY_WORN`) | 닳은 장비는 F7로 버리지 못함(`worn gear stays`). 드롭은 내구도를 싣지 않아서 주우면 새것이 되기 때문 | 문서에 없음 (디버그) |
| M7a 공유 창고 | `CHEST_SLOTS` 16, `CHEST_ONLY_IN_LIGHT`, `CHEST_FOOTPRINT` 3×1, `Storage`, `WorldData.chests` | 창고 상자 하나(04-env `storage_chest_v02`). 놓기 = 조제대 규칙 + **자리 전체가 제단 빛 안**(칸마다 네 모서리, 밭 규칙). 칸 16. 내용물은 그 지도의 것(놓은 자리마다). 여러 개 놓을 수 있다. 제단을 옮기면 그 자리에 남아 계속 열림(새 창고는 새 빛 안에만). 다시 줍거나 부술 수 없음 | ○ gameplay-design §5 "공유 창고: 제단 옆"("옆" = 빛 안으로 읽음). 크기·칸·개수는 문서에 없음 |
| M7a 창고 열기·옮기기 | `Main.pick_up`·`open_chest`·`chest_store`·`chest_take`, `ChestPanel` | F로 손 닿는 창고 칸을 겨누면 창고 창(인벤토리 위)과 인벤토리가 열리고 캐릭터는 서 있다. 인벤토리 칸 클릭 = 넣기, 창고 칸 클릭 = 꺼내기(같은 아이템·등급 묶음 먼저, 그다음 빈 칸, 들어가는 만큼만, 나머지는 제자리. 하나도 안 들어가면 거부). 내구도·등급은 그대로. Tab·Esc·F = 닫기, 다운·지도 옮김·창고 없어짐이면 닫힘 | 문서에 없음 (○ §1 "F 상호작용") |
| M7a 세션 | `WorldItems.M7_PLACEABLES`, `Crafting.is_m7`·`WHY_OFFLINE`, `Storage.WHY_OFFLINE`, `Player.gear_on`, `SessionHost._place`·`_craft` | 세션에서는 작업대 셋·창고 놓기를 호스트가 `workbench chain offline only`·`storage offline only`로, M7 레시피의 CRAFT를 `workbench chain offline only`로 거부한다. 갑옷은 입지 못하고(세션의 플레이어는 `gear_on` 끔: 클릭이 프레임을 만들지 않음), 1티어 무기는 기본 무기처럼(보너스·마모 없음), 손 제작 창은 열리지 않는다. 전송 형식 v7 그대로(내구도는 인벤토리 전송에 없음). M7c에서 켠다 | 문서에 없음 (단계 나눔, M5a·M6a와 같은 길) |
| M7a 그림 자리 표시 | `ItemIcons` (`fit_icon`, `TIER_MARK`, `armor_t1`), `Hud.draw_durability`, 갑옷 칸, `ChestPanel`, `CraftingPanel` | 작업대·창고 아이콘(놓은 그림을 16×16으로 줄임), 1티어 무기 아이콘(기본 무기 아이콘 + 금빛 표시), 갑옷 아이콘, 내구도 막대, 갑옷 칸, 창고 창, 성물 제작대 불꽃의 빛 없음 | 그림 없음 (도구 아이콘·장비 표시·창고 UI가 04-env에 없다) |

### 구현에서 고른 값 (설계 결정 아님)

| 무엇 | 코드 | 값 | 이유 |
|---|---|---|---|
| 기본 시드 | `DEFAULT_SEED` | 1 | |
| 바닥 청크 크기 | `GROUND_CHUNK` | 그림 칸 32 × 32 | 스파이크: `TileMapLayer`가 클수록 한 칸 편집이 비싸다 (RESULTS §3) |
| 바닥 렌더링 사분면 | `GROUND_QUADRANT` | 8칸 (128 px) | 캔버스 아이템 하나가 받는 빛 15개 한도 (RESULTS §4). G2의 빛은 2개뿐이라 그대로 둠 |
| 속 타일 변형 가중치 | `VARIANT_WEIGHT` | 변형 하나당 0.25 (기본 타일 1) | 풀은 기본 50%, 변형 4개 각 12.5% (테스트가 1만 칸에서 비율 확인) |
| 재 가장자리 노이즈 | `ASH_EDGE_NOISE_TILES`, `ASH_EDGE_NOISE_FREQUENCY` | ±3타일, 0.2 / 타일 | ±2타일은 덩어리가 너무 둥글었다 (스크래치 캡처로 비교) |
| 자유 카메라 속도 | `FREE_CAMERA_SPEED` | 240 px/s | `world.tscn`(맵 보기)에서만. 실행 장면은 플레이어 카메라 |
| 기본 호스트 포트 | `DEFAULT_PORT` | 24600 (UDP) | 테스트는 20개 묶음, 기본 `NET_TEST_PORT_FIRST..LAST` 24621-24640 (스파이크는 24601-24620). 러너가 잠금 + 확인(주소 세 개, `Runner.PROBE_ADDRESSES`)으로 고른다 (위 "테스트 포트") |
| 시뮬레이션 틱 | `NET_TICK_RATE`, `NET_TICK` | 60 (= 물리 틱, 스모크가 확인) | 입력 프레임 하나 = `Movement.step` 한 번 (1/60초) |
| 입력 보내기 | `NET_INPUT_HZ`, `NET_MAX_FRAMES_PER_PACKET` | 30Hz, 확인 안 된 프레임을 최대 32개(0.5초)까지 매번 다시 | 패킷을 잃어도 다음 패킷이 메운다. 움직이기 시작한 틱에는 바로 보낸다 |
| 호스트 속도 제한 | `NET_INPUT_BURST`, `InputGate.take(elapsed_ticks)`, `InputGate.ticks_between` | 실제 시간 한 틱마다 토큰 1, 최대 30 (+ 기다리던 프레임 수), 한 번에 최대 64틱 | 실제 시간보다 빨리 걸을 수 없고, 몰려 온 패킷은 0.5초까지 따라잡는다. 호스트가 멈췄던 시간도 채워서 뒤처진 대기열이 돌아온다 (H1) |
| 멈춤 크레딧 | `InputGate.HITCH_CREDIT_TICKS` | 놓친 틱 중 상한이 자른 몫, 실제 시간 30틱(0.5초) 동안, 더하지 않고 바꿔 넣음 | Godot이 따라잡기 틱 뒤에 네트워크를 읽어서, 멈춘 동안 온 프레임은 다음 틱에야 대기열에 들어온다. 그때 쓸 수 있게 (H-fix) |
| 따라잡기 속도 | `NET_INPUT_CATCH_UP_FRAMES` | 틱당 최대 4프레임 | 밀린 클라이언트가 다른 사람 눈에 한 틱에 수십 걸음 뛰지 않고 4배 속도로 따라잡게 (H-fix) |
| 한 틱에 그리는 구간 | `Player.MAX_DRAWN_STEP_PX` | 3px (두 걸음 2.4px + 여유) | 그보다 많이 움직인 틱(따라잡기)은 끝 위치에 그린다. 두 끝을 잇는 직선이 제단을 지날 수 있어서 (H-fix) |
| 스냅샷 크기 상한 | `WorldSnapshot.MAX_SIDE`, `MAX_PACKED` | 한 변 512칸, 압축 약 1.6MB (`MAX_RAW` + 1/64 + 1KB) | 받는 쪽이 잡을 메모리와 받을 크기의 상한. 이 크기는 압축이 안 돼도 틱당 8KB로 약 3.3초라 접속 제한 10초 안에 오고, 그리기 1초 안쪽. 맵이 커지면 접속 제한과 같이 올린다 (H-fix, 전에는 2048) |
| 입력 프레임의 바라보기 | `NetProtocol` 프레임 코드 0..8 | 보내지 않음, 호스트가 `Movement.facing_for`로 정함. **M2b에서 바뀜**: 아래 "바라보기를 프레임 코드에" 줄(조준 중에는 look을 보냄, 코드 0..44) | 호스트 권한. 클라이언트가 바라보기를 마음대로 정할 수 없고 1바이트 그대로 (H1) |
| 늦은 참가 월드 | `WorldSnapshot`, `NET_SNAPSHOT_CHUNK_BYTES`, `NET_SNAPSHOT_CHUNKS_PER_TICK` | 레이어 6장 + 머리말을 zstd로, 1KB 조각, 틱당 8조각 | 다른 아키텍처에서 생성이 달라도 같은 월드. 조각 하나 + 헤더가 UDP 한 덩어리(약 1400B)에 들어가 ENet이 쪼개지 않고, 큰 맵은 메시지가 아니라 틱 수로 커진다 (H1) |
| 제단 옆 띠 | `ALTAR_SIDE_CLEARANCE` | 서 5px, 동 3px (발 상자 밖으로 더) | 몸이 발에서 좌우 9px까지, 제단 그림 불투명 열 0~46. 옆면에 붙어도 몸이 제단 뒤로 안 들어간다. 테스트가 그림에서 다시 잰다 (H1) |
| 틱 사이에 그리기 | `Player.smooth_draw`, `draw_position` | 켬 (물리 틱으로 움직이는 플레이어) | 60Hz보다 빠른 화면에서 고른 걸음. 시뮬레이션은 그대로, 그림만 최대 1틱 뒤 (H1) |
| 호스트의 고른 적용 | `NET_INPUT_JITTER_FRAMES` | 3프레임 넘게 쌓이면 한 틱에 더 적용 (최대 4, 위) | 30Hz로 오는 입력을 60Hz로 고르게 (다른 사람 눈에) |
| 연결 한도 | `NET_TRANSPORT_PEER_LIMIT` | ENet 16 | 9명을 넘는 사람에게도 "full"을 말해 주려고. 상한은 `Roster`가 센다 |
| ENet 패킷 조절 | `NET_ENET_THROTTLE` | (간격 5000ms, 가속 2, 감속 0) = 낮아지지 않음 | ENet 기본(감속 2)은 60Hz로 뛰는 왕복 시간에 반응해 상태 묶음을 몇 초씩 버렸다(위 "네트워크"). 트래픽이 작아서 끔 (H-fix) |
| 접속 시간 | `NET_CONNECT_TIMEOUT_SEC`, `NET_HELLO_TIMEOUT_SEC`, `NET_REFUSE_GRACE_SEC` | 10초 / 5초 / 2초 | ENet 스스로는 약 31초 뒤에야 실패를 알린다 (이 데스크탑에서 잼). 10초는 월드를 다 받기까지다(스냅샷 크기 상한이 이 안에 들어오게 정함) |
| 위치 전송 | `NetProtocol` | float32 그대로 (4B × 2) | 예측을 다시 돌린 결과가 호스트와 비트까지 같게. 고정소수점으로 줄이면 속도가 조금 바뀐다 |
| 조용함 판정 | `StateBroadcast.QUIET_TICKS` | 12틱 | 테스트용 판정. 마지막 걸음·출입 뒤 12틱이 지나면 묶음을 보내면 안 된다 |
| ENet 압축 | `EnetTransport` | 없음 | 스파이크: range coder로 ENet 바이트 30~45% 줄지만 호스트·클라이언트가 같아야 해서 M1은 단순하게 |
| 호스트를 잃은 클라이언트 | `Main._on_net_ended` | 사람이 띄운 것은 혼자 계속, 테스트 인스턴스는 종료 코드 4 | UI가 없어서 창이 그냥 닫히는 것보다 낫다고 봄 |
| 재 속 타일 | `tiles_ash_var_1~3_v02.png` | 곰팡이·뼈 장식이 그려진 판 | 장식을 흩뿌리는 코드가 아직 없어서. 흩뿌리기를 만들면 `tiles_ash_plain_*`로 바꾼다 (04-env/prompts.md) |
| 두 번째 전부-풀 타일 | 풀↔재 세트의 전부 풀 타일 | 쓰지 않음 | 풀↔흙 세트의 것(= `tiles_grass_base_v02.png`)과 2픽셀만 달라서 한 벌로 |
| 내 클래스 기본값 | `DEFAULT_CLASS` | paladin | `--class`가 없을 때 |
| 애니메이션 속도 | `WALK_FRAME_TIME`, `IDLE_FRAME_TIME` | 걷기 0.12초/프레임 (3단계 걷기 GIF와 같음), idle 0.2초/프레임 | |
| 발 충돌 상자 | `FEET_HALF_WIDTH`, `FEET_HEIGHT` | 발 기준 가로 10 × 세로 4 px (발 위쪽으로) | 30px 캐릭터의 발 폭 정도. 제단 아래 변에 붙으면 몸이 제단 앞면을 가린다 |
| 머리 자리 | `HEAD_ROOM_PX` | 발은 맵 위 끝에서 28px 아래까지만 | 머리(프레임 y=4)가 맵 밖으로 안 나가게 |
| 스폰 자리 | `SPAWN_SLOTS` | 제단 가운데 기준 9곳 (서·동·북·남서·남동·북서·북동·먼 서·먼 동) | 모두 안전 반경 안·제단 밖·서로 안 겹침 (테스트). 자리 0 = 내 캐릭터 |
| 빛 레이어 | `LIGHT_LAYER_WORLD`, `LIGHT_LAYER_ACTORS` | 1, 2 | 바닥용 디더 빛과 캐릭터용 hard 빛을 나누려고 |
| 불꽃 마스크 밝기 | `FLAME_MIN_LUMA` | 148 (0~255) | 켜짐·꺼짐 차이 211픽셀 중 불꽃 81픽셀만 (돌에 비친 빛은 뺌, 스파이크 값) |
| 기준점 재기 | `RigData.ANCHOR_TOLERANCE` 등 | RGB 차 합 < 60, 몸통 ±4 / 머리 ±8px, 기준 = 걷기 첫 프레임 | 반경은 brief §5.6 R27. 색 허용 60은 스파이크 값 |
| 후광 자리 | `RigData.signature_for("cleric")` | v01 좌표 (10, −5), 머리를 따름, 걷기 2~4프레임 1px 위 | 스파이크·5차 목업 값. 머리 꼭대기 바로 위 (테스트) |
| 방패 칸 | `RigData` `LAYOUT_ROW_FIRST` | 방패 시트 줄마다 첫 칸 | ● R27 "방향당 1장 + 기준점"을 따름 (위 "캐릭터") |
| 대각선 바라보기 | `Movement.facing_for` | 지금 방향이 두 축 중 하나면 유지, 아니면 가로 | 대각선에서 방향이 깜빡이지 않게 |
| 제단 그림 자리 | `Altar.setup` | 그림 왼쪽 위 = 자리 왼쪽 위 (맨 아래 외곽선 = 자리 마지막 줄) | 불투명 47×43이 3×3 자리 안에 든다 |
| 인벤토리 넣기·나누기·옮기기 | `Inventory` | 같은 아이템·등급 묶음 먼저, 그다음 앞쪽 빈 칸 / 나누기는 첫 빈 칸으로 / 옮기기는 옮김·합침·맞바꿈 | 흔한 방식(테라리아·코어키퍼). 칸 순서라 새 아이템은 핫바부터 (M2a) |
| 동작 시간을 틱으로 | `Player.action_tick` | 시뮬레이션 틱으로 세고 프레임 = 틱 / `ACTION_FRAME_TICKS` | 그림 속도가 아니라 시뮬레이션이 정하게. 나중에 호스트가 같은 수로 셀 수 있다 (M2a) |
| 목표 칸 표시 모양 | `TargetMarker` | 칸 모서리 ㄱ자 금빛(팔 4px) + 안쪽 갈흑 띠, unshaded, 바닥 위·캐릭터 아래. 동작 중에는 동작의 목표 칸 | 풀·흙 위에서 읽히고 저녁에도 보이게. 칸 가운데를 비워 바닥이 보이게 (M2a). 동작 중에는 목표 칸이 시작 때 것이라 표시도 그 칸에 (M2-fix) |
| HUD 배치 | `Hud` | 칸 18px, 간격 2px, 아래 4px, 캔버스 레이어 10, 3×5 숫자, 상급 = 금빛 점 | 480×270에서 핫바 8칸 = 158px. 글꼴 없이 (M2a) |
| 디버그 묶음 | `ItemDB.debug_kit`, `DEBUG_KIT_FREE_SLOTS` | 도구 6 + 채집물·재료 17묶음 = 23칸 (약초 상급 하나 포함). **M3a**: 도구 뒤(핫바 7번)에 횃불 10개를 넣어 24칸을 다 채움. **M3-fix**: 오염 쪽 돌 둘(`stone_veined`·`stone_mould`)을 빼서 22칸, 2칸이 빈다 | 모든 아이템이 한 번에 보이게 (M2a). 횃불은 핫바에 있어야 쓸 수 있어서 도구 바로 뒤 (M3a). 24칸이 다 차면 약초사가 처음 캔 상급 약초(묶음에는 일반만 있는 `wild_buff`·`wild_poison`)와 캔 광석이 들어갈 칸이 없었다(검토 탐침: `inventory full`). 뺀 둘은 지상 재 구역에 흩어져 있어 주울 수 있다 (M3-fix). **M4a**: 이끼 돌(`stone_mossy`, 지상 풀에 있음)을 더 빼서 21칸(`DEBUG_KIT_FREE_SLOTS` 3). 혼자 할 때의 시작 무기(핫바 8번)가 한 칸을 써도 M3-fix의 빈 칸 2가 남게 (M4a) |
| 조준 마우스 위치 | `Player.mouse_world` | 엔진 `get_global_mouse_position()` | 창 늘이기·카메라를 엔진과 같게. `Aim`의 같은 계산은 테스트가 엔진과 비교하는 데 쓴다 (M2a) |
| 프레임 하나의 규칙 | `PlayerSim.step` | 동작 진행 → 사용이면 시작 → 이동 → 바라보기. 동작은 프레임으로 센다 | 혼자·호스트·예측이 같은 함수라 같은 프레임 줄이면 같은 상태 (M2b) |
| 바라보기를 프레임 코드에 | `NetProtocol.frame_code` | 코드 = 방향 + 9 × (look + 1), 0..44, 1바이트 그대로 | 조준은 클라이언트의 입력(마우스)이라 호스트가 정할 수 없다. look이 없으면 M1 코드 0..8 (M2b) |
| 요청을 프레임에 | `NetProtocol` 입력 패킷 끝 | 프레임 하나에 요청 하나, 확인될 때까지 프레임과 같이 다시 보냄. 새 클라이언트 RPC 없음 | 호스트가 그 프레임의 자리에서 검사해서 예측과 어긋나지 않고(같은 위치, 같은 순서), unreliable이어도 잃지 않는다. 따로 reliable RPC로 보내면 채널이 달라 프레임과 순서가 섞인다 (M2b) |
| 언제 프레임을 기록하나 | `Prediction.step_frame` | 움직일 때·멈춘 첫 틱(M1) + 요청이 있을 때 + 동작이 이어지는 동안 매 틱 + look이 바라보기를 바꿀 때 | 동작이 프레임으로 끝나므로 호스트와 같은 프레임에서 끝나야 한다. 서서 조준만 하면 바라보기가 바뀔 때만 1바이트 (M2b) |
| 요청 예산 | `NET_OP_INTERVAL_TICKS`, `NET_OP_BURST`, `NetMember.op_budget` | 줍기·버리기·주기: 6틱에 하나, 몰아서 4개. 사용은 동작 하나가 묶고(거부된 사용은 검사 한 번과 카운터뿐), 고르기는 예산 밖(M2-fix) | 사람이 누르는 속도보다 넉넉하고 매 프레임 보내는 클라이언트는 막는다. 틱 단위 정수로 센다(실수로 세면 6틱 뒤 0.9999로 모자랐다) (M2b). 고르기는 예측하는 요청이라 rate로 거부하면 클라이언트 핫바만 어긋나고, 월드를 바꾸지 않으며 프레임 수가 묶는다 (M2-fix) |
| 키 요청 줄 세우기 | `NetSession.local_ops`, `take_local_token`, `NET_LOCAL_OPS_MAX` | 클라이언트·호스트 모두 키 요청을 호스트와 같은 예산으로 하나씩 보냄(고르기는 다음 빈 프레임에). 줄은 64개까지, 넘으면 `request_dropped` 줄을 찍고 버림. 봇 요청은 바로 | 호스트가 제때 받으면 사람이 누른 것이 rate로 버려지지 않게(패킷을 잃거나 호스트가 멈춰 몰려 오면 4개 넘는 줍기·버리기·주기는 거부될 수 있다, 위 "요청"). 64는 클라이언트의 `--give` 디버그 묶음 23개(255개 넘는 수는 나뉨)가 다 들어가게. 전에는 코드 안 16에서 말없이 버렸다 (M2b, M2-fix) |
| 거부 로그 줄이기 | `NET_REFUSAL_LOG_FIRST`, `NET_REFUSAL_LOG_EVERY` | 플레이어·이유마다 처음 8줄, 그다음은 60번째마다 (`n=` 개수와 함께). 결과 JSON의 수는 모두 셈 | 매 프레임 거부되는 요청(사용·줍기)을 보내는 클라이언트가 호스트 로그를 초당 60줄씩 채우지 않게 (M2-fix) |
| 사용의 바라보기 | `Aim.use_facing`, `PlayerSim.step` | 프레임의 look이 목표 칸 쪽(칸 방향의 두 축 중 하나)이면 look, 아니면 칸 방향의 큰 축(정확한 대각선은 남·북) | 호스트가 정한다: 서쪽을 보며 동쪽 칸을 치는 프레임을 받지 않게. 정상 클라이언트의 look은 늘 칸 쪽이라 예측과 같다 (M2-fix) |
| 클라이언트 주기 나누기 | `Main.give_requests`, `WorldItems.GIVE_COUNT_MAX` | 255개 넘는 `--give`는 255씩 여러 요청으로 | 전송 형식의 개수가 1바이트라 300이 44로 잘렸다. 혼자·호스트와 같은 수를 받게 (M2-fix) |
| 땅의 드롭 상한 | `MAX_DROPS` | 256 | 스냅샷과 월드가 끝없이 커지지 않게 (M2b) |
| 같은 틱 순서 | `SessionHost.tick` | 플레이어는 자리 순서, 프레임은 번호 순서, 편집은 바로 적용 | 같은 틱에 같은 것을 주우면 자리 번호가 작은 쪽 (M2b. M2-fix부터 `tick` 자체로 시험) |
| 상태에 동작·든 아이템 | `NetProtocol` 상태 16B | flags 3~6비트 = 동작, u8 동작 프레임, u8 든 아이템 | 동작 시작 틱을 알 수 있어 보간이 시작부터 그리고, 예측 보정이 동작까지 맞춘다. 든 아이템은 바뀔 때만 묶음이 나간다 (M2b) |
| 인벤토리 메시지 | `_rpc_inventory` | 바뀐 틱 끝에 주인에게만 전부(78B) + ack | 드물게 바뀌어 차이보다 전부가 단순. ack로 아직 처리되지 않은 고르기를 다시 얹는다 (M2b) |
| 목표 칸 좌표 | 요청 필드 s16 | 부호 있는 16비트 | 맵 0열에 서서 서쪽을 겨누면 목표 칸이 −1이다(혼자 할 때처럼 동작은 된다) (M2b) |
| 채집물·드롭 그림 | `ItemView` | 칸 아래 변에 노드, 그림은 그 칸, `Entities` y 정렬, 캐릭터 빛 레이어 | 발 기준 y 정렬에 같이 들어가고 디더 빛의 바둑판이 작은 물체에 생기지 않게 (M2b) |
| 지도 하나 = GameWorld 하나 | `Main.worlds`, `GameWorld.map_id` | 혼자 할 때 `world.tscn`을 하나 더(던전), 하나만 보임, 플레이어 노드를 옮김 | 지상 코드(세션·스냅샷·테스트)가 `world`를 그대로 쓰고, 숨긴 지도의 어둠·빛이 적용되지 않음 (M3a) |
| 벽 바이트 | `Walls.pack` | 아래 4비트 종류, 위 4비트 맞은 횟수 | 레이어 6장(●)을 늘리지 않고, 채굴 한 번 = 칸 편집 하나라 스냅샷·해시·편집 기록이 그대로 (M3a) |
| 던전 그림 | `CaveView`, `CaveTable` | 꼭짓점 값 3가지(바닥·벽·앞면)의 dual grid, 코너 키 + 둘레(context)로 타일, 없는 키는 가까운 키 | 04-env 절벽 셋의 JSON 규칙 그대로. 지상 `GroundView`·`WangTable`은 손대지 않음 (M3a) |
| 다시 그리는 범위 | `CaveView.redraw_wall` | 그림 칸 가로 2 × 세로 5 + 위·아래 칸 오버레이 | 칸과 아래 칸(앞면)이 코너·둘레에 드는 범위 (M3a) |
| 광맥 그림 | `CaveView.ore_image` | 04-env 광맥 타일 − 같은 윗면 타일 = 광석 픽셀만 | 광맥 타일은 그림 칸(반 칸 밀림)이 아니라 월드 칸 위에 얹어야 해서 (M3a) |
| 횃불·벽 횃불 빛 | `TorchLight` | 반경마다 한 번 만든 텍스처를 붙잡아 둠, 딱딱한 단계 | 제단 빛과 같은 4.7.2 텍스처 규칙, 캐릭터 얼굴에 디더 바둑판이 생기지 않게 (M3a) |
| 벽 횃불 불꽃 | `FixtureView` | `flame_large_v01` 1~4프레임 140ms, unshaded, 횃불마다 위상 | 04-env 목업의 기준점 (9, −4)과 미리보기 GIF 140ms (M3a) |
| 혼자 할 때 봇 | `Main._physics_process` | `--bot`이 있으면 키 대신 봇(`NetBot`)이 `tick_controls`를 부름 | 스크린샷·테스트에서 같은 길(조준·동작·채굴·F)을 지나게 (M3a) |
| 트래픽 묶음 | `NetSession._count_traffic` | `act<n>/<인원>` 동작 중, `req/<인원>` 요청 전후 3틱. M3b: 플레이어가 지도 둘 이상에 있으면 뒤에 ` split`, 지도를 보내는 틱과 그 뒤 두 틱은 `entering` | 동작·요청이 서 있을 때(0/n) 측정에 섞이지 않게 (M2b). 지도 둘에서의 트래픽을 따로 재려고 (M3b) |
| 클라이언트는 자기 지도만 | `SessionHost.peers_on`, `_stream`, `_enter_map`, `SessionClient.on_map_entry` | 지도에 들어갈 때 그 지도의 스냅샷(늦은 참가 길, 같은 조각·틱당 8조각) + 지도 들어옴 + 그동안의 편집, 그 뒤 그 지도의 편집만. 떠난 지도는 버림 | 위 "M3b: 지도 보내기"(트래픽·단순함) (M3b) |
| 지도 번호 | `MAP_COUNT`, `MAP_NAMES` | 2 (지상 0, 던전 1) | 디코더가 다른 번호를 거부한다 (M3b) |
| 타일 요청의 지도 | `NetProtocol` USE·PICKUP·DROP·TRAVEL의 u8 지도 | 그 멤버의 지도가 아니면 `wrong map`, 예산을 쓰기 전에 | 옮긴 뒤 옛 지도에서 만든 프레임이 새 지도의 우연히 맞는 칸에 작용하지 않게. 예측도 같은 규칙으로 다시 돌린다 (M3b) |
| 상태의 지도 | 상태 17B | 모든 플레이어의 상태를 모두에게, 클라이언트가 지도 번호로 그리기만 거름 | 위 "상태와 그리기". 지도 옮김이 묶음·키프레임 흐름에 그대로 실린다 (M3b) |
| 편집 기록 | `NetSession.log_for` | 지도마다 기록과 번호 | 지도를 받을 때 "스냅샷 위치 + 그 뒤 편집"이 지도마다 맞게 (M3b) |
| 받는 중 오가기 | `WorldItems.WHY_LOADING` | 앞 지도를 다 보내기 전에는 TRAVEL 거부 | 한 클라이언트에게 두 지도의 조각이 섞여 가지 않게 (M3b) |
| 오가기 예측 | `Prediction.switch_map` | 예측하지 않음. 지도 들어옴의 상태에서 그 뒤 프레임을 새 지도에서 다시 돌림 | 새 지도 데이터가 오기 전에는 그 지도에서 걸을 수 없다 (M3b) |
| 봇 `waitmap` | `NetBot`, `SessionBots.map_counts` | 이 기기가 아는 지도별 인원까지 기다림 | 세션 시험이 시간 대신 상태로 서로를 기다리게 (M3b) |
| 표시 파일 내용 | `SessionBots.mark`, `SessionReport.seen` | JSON: 틱, 내 지도, 플레이어마다 지도·그려짐 | 그 순간 무엇을 그렸는지 시험이 본다 (M3b) |
| 던전 해시 묶음 | `DungeonGen.SEEDS_GOLDEN`, `seeds_digest` | 시드 1~8 던전 해시의 md5 | 서피스 ARM64와 생성기 비교 (M3b) |
| 던전 난수 섞기 | `DungeonGen.SEED_SALT`, `SEED_MULTIPLIER` | 시드 × 2654435761 + 0x5D0E5 | 던전 난수가 지상과 같은 줄을 되풀이하지 않게. 곱하는 수는 Knuth 곱셈 해시 상수 (M3a, M3-fix에서 이름 붙임) |
| 조준 코드 | `Combat.aim_code`, `aim_vector` | 조준 점 → 마우스 각도를 256단계(0 = 동, 시계 방향), 사용 프레임에 담고 동작 동안 붙잡음. 없으면(세션) 목표 칸 쪽. **M4-fix**: 조준 점이 발에서 `Combat.aim_origin`(화살이 그려져 나가는 점)으로(임시값 "M4-fix 화살 조준·맞는 상자"). 한 단계 1.4°라 120px에서 약 1.5px | M4b에서 1바이트로 실을 수 있게. 예측·호스트가 같은 수 (M4a) |
| 맞는 점 | `Combat.body_point` | 발 상자 가운데(발에서 2px 위): 화살·빛 탄의 바닥 점이 나가는 점, 근접·시야의 벽 선. 근접은 발끼리 거리 + 몸 점 사이 선. **M4-fix**: 화살·빛 탄이 맞는 것은 이 점의 반경이 아니라 그린 몸 상자(임시값 "M4-fix 화살 조준·맞는 상자"로 옮김, `BODY_HIT_RADIUS_PX` 8 그대로) | `Aim.feet_cell`과 같은 점 (M4a) |
| 시야 선 | `Combat.cells_on_line` | 격자 걷기(Amanatides & Woo)로 선이 지나는 칸 전부, 끝이 칸 모서리에 정확히 닿으면 끝 점 아래 칸 | 1px 표본보다 빠르고 빈틈이 없다. 모서리 경우는 일부러 깬 시험이 찾은 것을 고침 (M4a) |
| 화살 걸음 | `SHOT_STEP_PX` | 틱 안에서 2px씩 나아가며 검사. **M4-fix**: 두 걸음 사이에 지나는 칸도 모두(`Combat.cells_on_line`, 시야와 같은 격자 걷기), 걸음 사이 칸이 막으면 그 앞 점에서 멈춤. 12px 그리기(`SHOT_DRAW_LIFT_PX`)는 임시값 줄로 옮김(값 그대로) | y 정렬은 바닥 점으로, 16px 칸을 건너뛰지 않게 (M4a). 모서리끼리 닿은 벽 틈으로 빠지지 않게 (M4-fix: 검토 탐침 5,824발 중 163발이 넘어갔다) |
| 맞은 깜빡임 | `Config.HIT_FLASH_TICKS`, `Player.HIT_FLASH` | 6틱 동안 (1, 0.55, 0.45) 곱하기 | 흰 깜빡임은 셰이더가 필요해 가장 단순하게 (M4a) |
| 이단 사이 충돌 | `Arena` | 없음 (이단끼리, 이단과 플레이어 모두 겹칠 수 있음) | 플레이어끼리도 충돌이 없다(M1) (M4a) |
| 아레나 시간 | `Main.step_combat`, `Arena.step` | 내 캐릭터가 있는 지도의 아레나만, 물리 틱마다 플레이어 다음에 (소생 → 이단 → 날아가는 것 → 치우기 → 스폰) | 아무도 없는 지도의 시뮬레이션 비용을 쓰지 않고, 순서가 정해져 결정적 (M4a) |
| 아레나 난수 | `Arena.setup` | `hash([월드 시드, 지도 번호, 0xC0BA7])`로 PCG32 | 같은 시드 = 같은 스폰. 지도마다 다른 열 (M4a) |
| 이단 집으로 | `Arena._go_home`, `HERETIC_HOME_ARRIVE_PX`, `HERETIC_HOME_STUCK_TICKS`, `HERETIC_HOME_IDLE_PX` | 1.5px 안이면 도착, 60틱 동안 가까워지지 않으면 그 자리를 집으로, 표적이 없을 때 집에서 2px 넘게 떨어져 있으면 집으로 걷고 아니면 idle. M4-fix에서 이름만 붙임(값 그대로) | 벽에 걸려 영영 돌아가려 하지 않게 (M4a) |
| 이단 걸음 축 | `HERETIC_AXIS_DEAD_ZONE_PX` | 표적까지 한 축의 차이가 0.5px 밑이면 그 축으로는 걷지 않음(M4-fix에서 이름만) | 곧은 줄에서 떨지 않게 (M4a) |
| 스폰 시도 수 | `HERETIC_SPAWN_TRIES` | 한 번의 스폰에 후보 칸 24번까지 뽑음(M4-fix에서 이름만) | 후보가 플레이어 가까이에만 있을 때 틱을 오래 쓰지 않게 (M4a) |
| 시체·가방·제단 그림 자리 | `FixtureView.bag_origin`, `SHRINE_SLAB_TOP` 33, `BONES_ON_ROW` 40 | 자루의 맨 아래 줄이 칸 아래 변 2px 위, 판 = 제단 그림 33행부터, 뼈 더미 맨 아래 줄이 제단 그림 40행 | 그림에서 잰 값 (M4a) |
| HUD 막대 배치 | `Hud.BAR_AT`, `HP_BAR`, `STAMINA_BAR`, `DOWN_BAR`, `DOWN_TOP`, `COUNT_TOP`, `COUNT_SCALE` | (4, 4)에서 HP 60×4, 그 밑 스태미나 60×2, 다운 막대 80×3 위쪽 가운데 24px, 카운트다운 위쪽 가운데 40px에 3배 | 480×270에서 핫바·월드를 가리지 않게. 가운데에 두면 죽은 자리의 가방을 가렸다(스크린샷에서 봄) (M4a) |
| 동료 (시험) | `Main.add_ally`, `--test-ally` | 입력 없는 Player, 매 틱 빈 프레임으로 진행(다운·부활 시간), 스폰 자리 1 | 혼자 할 때 소생을 볼 방법 (M4a) |
| vitals 블록 | `NetProtocol` 상태 flags 7번 비트 + 16B (`put_vitals`/`get_vitals`) | 쉬는 중(`Vitals.at_rest`)이면 없음, 아니면 필드 전부(예측이 거기서 다시 돌림) | 싸움 없는 세션은 M3b와 같은 17B 상태. 상태를 늘 33B로 하면 9인이 걸을 때 약 23 KB/s 더 (M4b) |
| 적 묶음 | `NetProtocol.encode_enemies`, `StateBroadcast.decide_encoded`(지도마다 하나) | 그 지도의 이단 전부(17B씩, f32 위치 그대로) + 제단 HP, 20Hz 바뀔 때만 + 키프레임, 시간 상태는 시작 틱(하위 16비트) | 서서 공격하는 이단은 조용하고, 늦게 와도 키프레임 하나로 같은 그림 (M4b) |
| 공격 시작에 바로 보냄 | `NET_ENEMY_SEND_ON_ATTACK` | 켬 | 예고가 20Hz를 기다리지 않음(최대 2틱) (M4b) |
| 화살 사건 + 클라이언트 비행 | `_rpc_shots`, `Arena.shot_events`, `NetCombat.ShotTrack` | 쏨 20B + 멈춤 18B, reliable, 그 사이는 같은 벡터로 날림 | 위 "M4b: 클라이언트가 그리는 것"(트래픽·맞음) (M4b) |
| 클라이언트 시계 (M4b "조용한 클라이언트", M4-fix에서 고침) | `NET_HOST_STEPS_AFTER_TICKS`, `SessionHost.run_client_frames`, `InputGate.put_back` | 멤버가 시간을 쓰는 동안(vitals 타이머 또는 몸 동작) 시계 빚 = 호스트 틱 − 돌린 프레임. 빚이 0이면 그 틱의 남은 프레임은 다음 틱으로(앞서지 못함), vitals가 돌 때 빚이 30틱을 넘으면 호스트가 빈 프레임으로 진행, 쉬면 빚 0 | 다운·무적·부활이 호스트 시간으로 흐르고(가끔 보내도), 쌓아 둔 프레임으로 경직·대시 쿨다운·동작을 줄이지 못하고, 서 있다 맞은 정상 클라이언트는 호스트가 진행하지 않는다(한 방향 약 200ms까지). M4b는 프레임이 없던 틱을 서 있는 동안까지 세고 프레임 하나로 0이 되어 셋 다 틀렸다(검토 넷) (M4b, M4-fix) |
| 빈 지도 그리기 | `SessionHost._step_arenas` | 사람이 없는 지도의 뷰는 비운 틱에 한 번만 그림 | 호스트가 매 틱 모든 지도의 뷰를 그리던 것을 줄임 (M4-fix) |
| 이단의 제단 자리 기억 | `Arena.shrine_rect`, `CombatView._shrine_node` | 처음 한 번 맵 전체에서 찾고, 그 여섯 칸이 그대로인 동안 그 자리. 칸이 바뀌면(편집이 한 칸씩 와도) 다시 찾고, 없어지면 그 데이터에서는 없음. 제단 그림 노드도 한 번 찾아 둠 | 화살 한 걸음마다 맵 전체를 두 번 훑어(지상 128×96 한 번 139µs) 화살 27개면 한 틱 8ms였다(검토). 이제 같은 경우 약 0.24ms (M4-fix) |
| 부활 알림 | `PlayerSim.step` (`RESPAWN`) | 사망 틱이 `RESPAWN_TICKS`에 닿으면 거기서 멈추고, 누가 부활시킬 때까지 매 프레임 RESPAWN | 그 때가 지난 채 넘어온 사망 상태도 부활한다(전에는 딱 그 틱에만 알려서 지나간 상태는 영영 사망) (M4-fix) |
| 오가기와 대시 | `Player.set_world` | 다른 지도로 가면 하던 대시가 끝남(쿨다운은 이어짐). TRAVEL을 거부하지는 않음 | 계단 앞에서 Space 뒤 F를 누르면 도착점에서 대시가 이어지던 것. 거부(`busy`)하면 혼자 할 때 F도 바꿔야 해서 끝내는 쪽 (M4-fix) |
| `--test-shrine-hp` 상한 | `CliOptions` | 1..`SHRINE_HP`, 넘으면 CLI 오류 | 클라이언트가 `SHRINE_HP`를 넘는 적 묶음을 잘못된 메시지로 거부하므로 (M4-fix) |
| 지도 들어옴의 상태 자리, 제단 막대 폭 | `NetProtocol.MAP_ENTRY_STATE_AT`(49), `CombatView.SHRINE_BAR_WIDTH`(30) | 값 그대로 이름만 | 숫자 그대로 쓰던 것 (M4-fix) |
| 예측의 프레임 기록 | `Prediction.step_frame` | M2b 조건 + F 누르는 동안·뗀 프레임, 대시, vitals 타이머가 도는 동안 매 틱 | 그 프레임들이 호스트에서 그 플레이어의 시계라 같은 프레임에 같은 타이머 (M4b) |
| 호스트 사건 보정 | `Prediction.reconcile` (`event_corrections`, `vitals_corrections`) | HP·삶·소생 진행이 다르면 호스트 사건으로 따로 셈 | 맞음·소생은 예측할 수 없다. 나머지 차이는 예측의 잘못이라 시험이 0을 봄 (M4b) |
| 부활 규칙 하나 | `PlayerSim.respawn`, `Player.respawn_at` | 혼자·호스트·예측이 같은 함수 | 같은 프레임에 같은 자리라 보정 없음 (M4b) |
| 대시 방향 지우기 | `PlayerSim._dash_move`, `hurt` | 대시가 끝나거나 끊기면 방향 0 | 대시 중에만 읽는 값이라 시뮬레이션은 그대로, 쉬는 vitals가 블록을 보내지 않게 (M4b) |
| 트래픽 묶음 fight | `NetSession._count_traffic` | 사람이 있는 지도에 쉬지 않는 이단이나 날아가는 것이 있으면 `fight/<인원>`(동작·걷기 묶음보다 앞) | 싸움 트래픽을 따로 재려고 (M4b) |
| 세션 시험의 스폰 | `test_net_session.gd` `_launch` | 모든 인스턴스에 `--test-no-spawns` | M2b·M3b 세션은 하던 것만 본다 (M4b) |
| 봇이 이단을 겨누는 곳 | `NetBot` `aimfoe`·`fight` (`Combat.body_centre`) | 이단 그림 가운데(발 14px 위) | 사람이 그림을 누르듯이. 발을 겨누면 조준 단계 때문에 그림 아래 끝을 반쯤 빗나간다 (M4-fix) |
| 시험 플래그·봇 명령 | `CliOptions`, `NetBot`, `SessionBots` | `--test-start-hp`·`--test-no-spawns`·`--test-dungeon-heretic`, 호스트의 `--test-heretic`·`--test-shrine-hp`, 봇 `aimfoe`·`fight`·`closein`·`waitfoe`·`waitlife`·`waitdown`·`walkdown` | 실제 세션의 싸움을 스크립트로 (M4b) |
| 시험 결과용 기록 상한 | `NET_STREAM_RECORDS_MAX` | 호스트 `streams_done`, 클라이언트 `left_maps` 마지막 64개 | 결과 JSON에만 쓰는 목록인데 release에도 있고 TRAVEL에 쿨다운이 없어 한 클라이언트가 초당 약 9개씩 끝없이 늘릴 수 있었다(검토 탐침: 13.8초에 121번 오감) (M3-fix) |
| 효과를 Vitals에 | `Vitals.buff_*`·`poison_*`, `same_as`·`copy`·`reset`, `PlayerSim._tick_effects`·`walk_speed`·`heal`·`add_buff`·`add_poison` | 플레이어의 효과는 Vitals의 필드이고 `PlayerSim.step`이 서 있는 플레이어의 효과를 맨 먼저 센다. `same_as`(따라서 `same_all`)에 들어감. `idle()`·`at_rest()`·vitals 블록(전송 형식)에는 아직 없음 | M4가 vitals를 둔 공유 시뮬레이션이라 혼자·호스트·예측이 같은 규칙 하나(시험 2,400틱). 세션에서는 효과가 생기지 않으므로 전송은 M6b가 더한다 (M6a) | **M6b**: `idle()`·`at_rest()`·전송 형식(효과 블록)에 들어감(아래 M6b 줄)
| 이단의 독 | `HereticSim.poison_*`, `Arena.poison_heretic`·`_tick_poison`·`_poison_damage` | 이단의 상태에 독, 아레나가 살아 있는 이단의 독을 맨 먼저 셈, 독 죽음은 `killed`·`poison_kills`와 `Hit`(던진 사람)로 | 무기 맞음과 같은 처치 셈·호스트 로그 길을 그대로 지나게 (M6a) |
| 던진 병 = 아레나의 날아가는 것 | `Arena.Flask`·`Splash`, `flasks`·`splashes`, `on_emptied` | 화살처럼 아레나가 틱마다 움직이고(같은 걸음·칸 검사), 터짐은 18틱 보이는 기록. 빈 지도를 비울 때 같이 없앰 | 혼자·호스트가 같은 아레나 규칙. M6b는 화살처럼 사건으로 보내면 된다 (M6a) | **M6b**: 사건으로 보낸다(아래 "병 사건 + 클라이언트 비행")
| 병이 닿는 틱 | `Arena.FLASK_ARRIVE_PX` | 남은 거리가 한 틱 비행 + 0.001px 안이면 이번 틱에 목표 점에 떨어짐 | float 누적 때문에 0.00001px 남아 한 틱 늦던 것을 막으려고 (M6a) |
| 터짐 그림 | `CombatView.SPLASH_HALF`·`SPLASH_FRAMES`·`SPLASH_DROPS`·`SPLASH_COLOURS`, `SPLASH_SHOW_TICKS`, `THROW_ARC_PX` | 55×55 그림 3장(바깥 고리 방울 10개, 둘째부터 가운데 고리 5개, 첫 장에 유리 조각), 18틱, unshaded. 병은 화살 높이 + 가운데 10px 포물선 | 저녁·던전 어둠에서도 읽히게. 그림 검사가 CPU로 같은 그림을 만든다 (M6a) |
| 효과 표시 자리 | `EffectMarks.MARK_Y`·`SIZE`·`GAP`, `Hud.effect_icon_at`·`effect_fill` | 머리 위 44px, 7×7, 1px 간격으로 가운데. HUD는 스태미나 막대 3px 밑에 왼쪽부터, 남은 시간 1px 막대(등급 중 가장 긴 시간 기준) | 성직자 후광(발 위 33~37px)·이단 HP 막대(발 위 32~35px)와 겹치지 않게 (M6a) |
| 제작 창 배치 | `CraftingPanel.PAD`·`HEADER`·`ROW`·`ROW_GAP`·`WIDTH`·`MARGIN`·`DIM` | 오른쪽 위 4px, 60px 너비, 줄 18px + 2px, 만들 수 없는 줄은 #1a1714 62% 덮기 | 480×270에서 가운데 캐릭터·조제대와 아래 인벤토리를 가리지 않게 (M6a) |
| 제작 창이 열린 동안 | `Player.ui_locked`, `Main._crafting_input`, `Main._check_crafting` | 캐릭터의 입력 프레임이 빈 프레임(걷기·대시·사용·F·1 없음), 키는 창이 받음, 매 틱 작업대에 아직 있는지 봄 | W/S·F가 창과 캐릭터에 같이 가지 않게. 열린 동안 움직일 수 없으니 멀어짐은 맞음·지도 옮김·테스트 순간이동뿐 (M6a) | **M6-fix**: 설계 규칙(서 있고 막을 수 없음, 맞아도 안 닫힘)이라 임시값 "M6-fix 제작 창이 열린 동안"으로 옮김(값 그대로)
| 효과·마시기를 켜는 스위치 | `Player.potions_on` | 혼자 할 때 Main이 켬(호스트를 잃고 혼자 계속할 때도), 세션의 플레이어는 꺼짐 | 세션에서 클라이언트가 예측할 수 없는 프레임(마시기·던지기)을 만들지 않게. M6b가 세션에서 켠다 (M6a) | **M6b**: 세션의 자기 플레이어도 켬(호스트 `on_opened`, 클라이언트 welcome)
| 물약 아이콘 자르기 | `ItemDef.icon_region`, `ItemIcons.texture_for` | 띠 그림을 불러 그 16×16 칸을 새 `ImageTexture`로 | 04-env에 물약 파일이 따로 없어서 띠 파일을 바이트 그대로 복사하고(그림 출처 시험) 코드로 자름 (M6a) |
| 조제대 아이템 칸 | `ItemDB` 표 끝 | 물약 셋 다음에 `alchemy_table`(아이템 번호 26~29) | 전송 형식이 아이템을 번호로 보내서 늘 끝에 더함 (M6a) |
| THROW·CRAFT 요청 | `NetProtocol.Op.THROW`(11B)·`CRAFT`(2B), `SessionHost._throw`·`_craft`, `Player.make_frame` | 던지기는 USE가 아니라 자기 요청(던진 점 s16×2, 정수 px), 제작은 레시피 번호. 마시기는 물약 칸의 USE 그대로 | 던질 점은 마우스라 호스트가 정할 수 없다(보내되 호스트가 자기 자리에서 96px로 자름). 레시피 번호 하나로 입력·등급·출력이 정해져 클라이언트가 등급을 고를 길이 없음 (M6b) |
| 효과 블록 | `NetProtocol.put_vitals`/`get_vitals`/`vitals_size`, 삶 바이트 7번 비트 + 7B | 버프·독이 있을 때만(`Vitals.has_effects`) | 상태 flags 바이트가 다 차서 삶 바이트(0..2)의 남는 비트를 씀. 다쳤지만 효과 없는 플레이어는 33B 그대로, 효과가 있을 때만 +7B. 늘 23B 블록이면 다친 플레이어마다 7B씩 더 (M6b) |
| 효과 = 타이머 | `Vitals.idle`(`has_effects`), `Prediction.step_frame`, `SessionHost.timed` | 효과가 도는 동안 idle 아님: 클라이언트가 매 틱 프레임, 호스트 시계 빚 | 효과가 호스트 시간으로 흘러야(조용한 클라이언트가 독을 버티지 못하게) M4-fix의 시계 그대로. 대가: 효과 동안 그 사람의 상태 묶음 20Hz와 입력 30Hz(위 "측정", 알려진 문제) (M6b) |
| 효과가 걸림 = 호스트 사건 | `Prediction.effect_event` | 호스트의 버프·독이 예측보다 길거나 세면 사건(오차·vitals 보정에 안 넣음), 줄어드는 것은 예측이 같이 셈 | 걸림은 호스트만 안다(맞음과 같다). 줄어드는 것은 공유 시뮬레이션이라 예측의 잘못을 그대로 잡는다 (M6b) |
| 이단의 독 표시 | 적 묶음 flags 6번 비트, `NetProtocol.enemy_of`, `NetCombat.sample_foe` | 살아 있는 이단이 독이면 1(0B 더함), 시간·세기는 보내지 않음 | 클라이언트가 그리는 것은 머리 위 표시뿐이고 HP는 이미 묶음에 있다 (M6b) |
| 병 사건 + 클라이언트 비행 | 화살 사건 메시지의 종류 2·3, `Arena.flask_event`·`splash_event`, `Arena.flask_points`·`flask_arrives`, `NetCombat.FlaskTrack` | 던짐(27B)·터짐(19B) reliable, 그 사이는 호스트와 같은 걸음 함수로, 자기 병은 바로·남의 병은 100ms 뒤 | 위 "M6b: 던진 병"(트래픽·맞음). 같은 함수라 그리는 병 = 호스트의 점(시험·창 검사) (M6b) |
| 늦게 온 사람의 병 | `SessionHost.send_combat_snapshot`, `Arena.Flask.owner_slot`·`born`, `Splash.why`·`born` | 날고 있는 병은 던짐 사건, 보이는 터짐은 터짐 사건으로 적 키프레임 뒤에 | 화살(M4b)과 같은 길 (M6b) |
| 클라이언트의 해금 기억 | `SessionClient.take_inventory` | 호스트가 보낸 인벤토리에 든 아이템을 `seen`에 | 호스트의 `seen`이 기준(제작 검사). 클라이언트의 것은 창에 보일 줄만 정함 (M6b) |
| 제작·놓기 예측 안 함 | `Main.craft_row`(세션: CRAFT 요청), `SessionHost._place` | 인벤토리·월드는 호스트의 답으로만 | 줍기와 같음(M2b). 틀린 예측을 되돌릴 일이 없다 (M6b) |
| 제작 요청 예산 | `SessionHost._craft` (`NetMember.take_op`, `NET_OP_INTERVAL_TICKS`·`NET_OP_BURST`) | 줍기·버리기와 같은 예산 | 제작은 인벤토리만 바꾸지만 받아 줄 때마다 주인에게 인벤토리를 보내므로 마구 보내기를 막음 (M6b) |
| 세션의 창 잠금과 봇의 Tab | `SessionBots.local_action`, `NetSession.bot_ui` | 창이 열린 동안 세션 입력의 걸음·사용·대시·F·1을 지움. 봇의 tab·craft는 프레임을 만들기 전에 시그널로 Main에 | 혼자 할 때의 `Player.tick_controls`(M6a)와 같은 규칙을 세션 입력에서 (M6b) |
| 물약 효과 틱 규칙 하나 | `Potions.release` | 혼자 할 때(`Main.potion_impact`)와 호스트(`SessionHost._potion`)가 같은 함수: 다시 거부·하나 쓰기·효과 또는 병 | M2b의 "규칙은 순수 함수 하나" (M6b) |
| welcome의 효과 기록 | `SessionClient.effects_on_welcome`, 로그 `welcome_effects` | 효과가 있는 플레이어의 자리 → vitals | 시험(늦은 참가자가 버프를 봄) (M6b) |
| 작업대 찾기 (M6-fix) | `Crafting._nearest`·`station_near`·`station_of_kind_near`·`still_at` | 발 칸 둘레 `STATION_REACH_TILES` 안의 칸을 모두 보고 작업대 칸이면 `footprint_at`으로 그 자리 전체를 잼(자리 크기 무관). 가장 가까운 것, 같으면 자리 왼쪽 위 칸이 줄 순서로 앞인 것(M6b의 훑는 순서와 같은 결과). 호스트의 CRAFT는 그 레시피의 종류 중에서. `still_at`은 창을 연 그 자리(같은 값·같은 자리·같은 지도)가 손 닿는지 | 검토: 3칸 자리에 맞춘 창은 5칸 자리를 놓쳤고, 가장 가까운 작업대 하나만 보면 종류가 다른 작업대가 더 가까울 때 CRAFT를 거부했다(M7) (M6-fix) |
| 설치물 값마다의 표 (M6-fix) | `WorldItems.FOOTPRINT_OF`·`footprint_of`, `Crafting.STATION_ICON`·`station_icon`, `Recipe.class_refusal` | 자리 크기(없으면 1칸), 작업대 종류 → 창 머리 아이콘 아이템, 클래스 거부 = "<클래스> only" | `place_rect`·제작 창·거부 문구가 조제대·약초사를 이름으로 알던 것을 표로. 그림(`FixtureView`)과 창의 줄 모양은 그대로 조제대만 안다(위 "M7이 새 작업대에 더할 것") (M6-fix) |
| 사람이 나타나는 자리 (M6-fix) | `WorldItems.reserved_feet` | 도착점은 `GameWorld.arrival_point`와 같은 식(지상은 입구, 던전은 출구 계단의 `arrival_below`), 부활·참가 자리는 `altar_center_px() + SPAWN_SLOTS`(= `GameWorld.spawn_point`), 막는 설치물의 자리와 그 발 상자가 겹치면 거부 | WorldItems는 순수 함수라 GameWorld 노드 없이 데이터에서 계산 (규칙 자체는 임시값 "M6-fix 조제대가 비워 두는 자리") (M6-fix) |
| 독 틱의 맞음 기록 (M6-fix) | `Arena.Hit.poison`, `SessionHost._flush_hits` | 독 틱 기록에 표시, 호스트가 던진 사람의 `poison_hits`로 세고(`hits`는 무기 맞음만) 로그 줄 끝에 ` POISON` | 검토: 상급 독 하나가 무기 맞음 열 번으로 셌다 (M6-fix) |
| 요청을 한 것으로 세는 때 (M6-fix) | `SessionHost.run_frame`·`_action_op_name` | 사용·마시기·던지기는 그 프레임의 걸음이 동작을 시작했을 때(`PlayerSim.STARTED`)만 `ops_done`에 | 같은 프레임의 Space는 대시가 이겨 동작이 시작되지 않는다 (M6-fix) |
| 던질 점은 정수 px (M6-fix) | `Player.make_frame` (`Potions.throw_target(...).round()`) | 혼자 할 때도 전송 형식이 싣는 값(정수 px)으로. 손을 떠날 때 아레나가 다시 96px로 자름 | 혼자 = 호스트가 사거리 밖 점에서도 0.01px까지(시험) (M6-fix) |
| 병 사건의 여유 (M6-fix에 이름 붙임) | `NetProtocol.FLASK_RANGE_SLACK_PX`, `NetCombat.FlaskTrack.FLASK_PATH_SPARE_TICKS`·`FLASK_WAIT_BROKE_TICKS` | 던짐 사건의 떨어질 점이 사거리 + 1px보다 멀면 거부, 비행 경로는 사거리를 나는 틱 + 2틱까지, 터짐 사건이 안 온 병은 날고 터질 시간 + 60틱(1초) 뒤 잊음 | float 반올림 여유. 터짐 사건은 reliable이라 잃지 않지만 지도 바뀜이 끊을 수 있다 (값 그대로) |
| 터짐 그림의 고리 (M6-fix에 이름 붙임) | `CombatView.SPLASH_INNER_RING`·`SPLASH_TURN_PER_FRAME`·`SPLASH_INNER_TURN` | 안쪽 고리 반지름 = 바깥의 0.55, 프레임마다 0.3라디안, 안쪽은 0.4 더 돌림 | 방울이 한 줄로 겹치지 않게 (값 그대로) |
| HUD 효과 아이콘 간격 (M6-fix에 이름 붙임) | `Hud.EFFECT_ICON_GAP` | 아이콘 사이와 스태미나 막대에서 아이콘까지 3px | (값 그대로) |
| 병 그림 unshaded (M6-fix) | `CombatView._sync_flasks` (`FixtureView.unshaded_material`) | 날아가는 병도 터짐·표시·빛 탄처럼 unshaded | 검토: 빛 없는 던전에서 병이 배우만큼 어두웠다(가장 밝은 픽셀 #1c1713). 창 그림 검사 `potions`가 저녁 켬에서 병·터짐 픽셀 197개가 제 색인지 본다 (M6-fix) |
| 밭 값 (M5a) | `Config.FIELD_BASE`·`FIELD_KIND_STEP`·`FIELD_STAGE_STEP`, `Farming.Field` | 식생 값 64 + 작물 × 40 + 단계 × 8 + 표지(시듦 4·젖음 2·약초사 1), 0 = 마른 빈 흙, 66 = 젖은 빈 흙. 채집물(1..15)과 겹치지 않고 한 바이트 | 보이는 상태를 레이어에 두면 스냅샷·해시·편집 기록·늦은 참가가 그대로 덮어 M5c가 전송 형식을 바꾸지 않아도 된다. 비트 대신 곱으로 둔 것은 "약초사가 심음"까지 한 바이트에 들게 하려고 |
| 농장의 시간 (M5a) | `Farm.plots`(칸 번호 → 자란 틱·남은 물 틱), `Farm.setup`·`sync_cell` | 월드 밖. 새 `Farm`은 단계의 처음부터·젖은 칸은 물 가득 | 매 틱 바뀌는 것을 월드에 두면 틱마다 편집이 나가야 한다. 보이는 것이 바뀔 때만 편집하고, 시간은 정하는 쪽(혼자 할 때 Main, M5c의 호스트)에만 둔다 |
| 편집을 돌려주는 농장 (M5a) | `Farm.till`·`plant`·`water`·`harvest`·`step` → `Farm.Result`·편집 | 데이터를 쓰지 않음, 부른 쪽이 다음 호출 전에 적용(`Main._apply_farm`, `step_farms`) | 채굴·제작·물약과 같은 길: 혼자 할 때와 호스트가 같은 함수를 부르고 편집을 각자 적용·기록·전송한다 |
| 물 준 덧칠 그리기 (M5a) | `FieldView.WetPatch`, `wet_quad`, `WET_PATHS` | 젖은 칸마다 노드 하나(사분면 넷), 바닥 빛 레이어, `Fields` 노드는 바닥 바로 위 | ● R29 칸별 덧칠을 dual grid 위에 그대로 그리는 방법. 노드를 칸마다 두는 것은 바닥 청크의 사분면 크기와 같은 이유(빛 15개 상한) |
| 작물 그림 (M5a) | `FieldView.crop_sheet`·`crop_region`·`crop_position` | 엔티티 아래 y 정렬, 칸 아래 변(채집물과 같은 자리), 캐릭터 빛 레이어, 시트를 마른·젖은 둘로 색 바꿈 | 채집물(M2b)과 같은 자리·같은 빛이라 캐릭터와 앞뒤가 발로 정해진다 |
| 작물 흙더미 색 (M5a) | `FieldView.MOUND_DRY`·`MOUND_WET`·`SEED_MOUND_*` | `crops_v03` 흙더미 갈색 셋(+ 씨앗 흙더미 둘) → 흙 타일의 어두운 테·채움·밝은 색, 물 준 흙 타일의 같은 자리 색 | 04-env prompts.md가 "작물 흙더미 색은 이 흙 색에 맞춰 바꿔 쓴다(물 준 칸에서는 물 준 색으로)"라고 적어 두었다. 색은 흙 타일에서 잼 |
| 시험 밭 (M5a) | `--test-field`, `Main.apply_test_fields` | 규칙을 건너뛰고 놓음(재 옆만 거부), 농장이 첫 틱에 시듦 판단 | 다 자라는 데 몇 분이 걸리고 빛 밖에는 일굴 수 없어서, 스크린샷·시험이 장면을 바로 세운다 |
| 농사 로그 (M5a) | `EVENSONG_FARM` (`Main._apply_farm`, `_log_field_change`, `seed_from_wild`) | 동작·거부·단계·시듦·되살아남·씨앗 줄. 마름은 찍지 않음 | 다른 `EVENSONG_` 줄처럼 사람이 콘솔로 볼 수 있게. 마름은 물 준 칸마다 나와 너무 잦다 |
| 시듦 검사 비용 (M5a) | `Farming.near_corruption`(오염 레이어 바이트를 바로 읽음), `withers_at`의 `SafeZone` 하나 | 매 틱 작물마다 5×5 칸 + 모서리 넷 | 첫 판은 칸마다 `get_value`를 25번 불렀다: 시험의 20,000틱 대본(밭 12칸, 대본의 동작 포함)이 틱당 191µs → 바꾼 뒤 78µs(잰 값). M5-fix: 원인을 칸마다 기억해 제단 자리나 오염 레이어(해시)가 바뀐 틱에만 다시 구하고(`Farm._withers`), 시듦 표지가 원인과 맞는 마른 작물은 값만 읽고 건너뜀, 칸 번호 정렬은 칸이 생기거나 없어질 때만: 마른 작물 1,000개 약 3~4.8ms(검토) → 0.11ms, 20,000틱 대본 57µs |
| 정화 효과 (M5b) | `PURIFY_FLASH_TICKS`·`PURIFY_ASH_TICKS`·`PURIFY_MOTES`, `PurifyView` | 정화된 칸: 금빛 1px 테두리가 30틱 동안 안으로 줄어듦(unshaded), 재 얼룩(칸 해시로 셋 중 하나, 칸 가운데)이 60틱(바닥 빛 레이어). 채널링: 반지름 + 0.5칸 고리에 점 16개(2×2 금빛, 왼쪽 위 상아빛)가 진행만큼 켜짐 | 재가 걷히는 모습("재를 거쳐 풀")을 월드에 두지 않고 보이기만. 저녁에도 읽히게 |
| 제단 자리 다시 읽기 (M5b) | `WorldData.refresh_altar_rect`, `EditLog.apply_to_data`, `GameWorld._altar_moved`·`altar_moved` | 설치물 칸에서 제단 칸이 한 3×3일 때만 그 자리, 반쯤이면 없음. 제단 칸을 바꾸는 편집마다(첫 칸 찾기와 세기는 네이티브) | 들기·놓기를 기존 칸 편집으로 해서 스냅샷·해시·편집 기록·전송 형식이 그대로(M5c) |
| 아레나가 따라가기 (M5b) | `Arena.sync_world`(`_synced_altar`, `_synced_corruption`) | 매 `step()` 처음에 제단 자리와 오염 칸 수(`count(0)`, 네이티브)를 보고 바뀌었으면 빛 규칙과 지상 스폰 칸을 다시 계산 | 혼자 할 때 Main이, M5c의 호스트가 따로 부르지 않아도 맞게 |
| 더미가 따라가기 (M5b) | `Main._on_altar_moved` | 놓으면 더미 넷이 새 부활 자리 1~4에서 제단을 봄, 들고 있는 동안은 그대로 | M1 더미 = 부활 자리의 클래스 표식 보기 |
| 놓을 자리·든 제단 표시 (M5b) | `AltarGhost.DOT_STEP`, `AltarMark.MAP`·`MARK_Y` | 테두리 1px + 빛 가장자리 6°마다 점(반지름 − 1px), 머리 위 9×6(발 위 53px, 효과 표시 위) | 코드 그림 자리 표시 |
| 채널링 요청 (M5c) | `NetProtocol.Op.CHANNEL`(1B), `SessionHost.wants_channel`·`attach_local_op`, `_channel` | F(PICKUP)를 프레임에 붙일 때 주울 것이 없고 팔라딘이 오염 옆이면 CHANNEL로 바꾸고 `frame.channel`을 켬(예측이 바로 시작). 호스트는 `frame.channel`을 지우고 자기 상태로 다시 정함 | 프레임 코드에 비트를 더하면 1바이트를 넘는다(180 × 2). 혼자 할 때의 "F, 주울 것이 없으면 채널링"(M5b)을 그대로 두고 그 결정만 요청으로 |
| 상태의 채널링 (M5c) | `NetProtocol.CHANNEL_ACTION`(15), 동작 프레임 바이트 = 채널링 틱, `PlayerState.channel`, `Prediction._sim_of` | 동작 비트 15 + 틱 1..179, 칸 = 발 칸 | flags 바이트가 다 찼고, 채널링과 몸 동작은 같이 돌 수 없고, 채널링은 움직이지 않는다. 0B 더함. `PURIFY_CHANNEL_TICKS`가 256을 넘으면 바이트가 모자람(시험이 봄) |
| 상태의 든 제단 (M5c) | `NetProtocol.CARRYING_FLAG`(든 아이템 바이트 7번 비트), `PlayerState.carrying` | 든 사람이면 1 | 아이템이 34개라 7번 비트는 비어 있다(시험이 128 아래인지 봄). 0B 더함 |
| 제단 들기를 호스트가 셈 (M5c) | `NetMember.altar_hold`, `SessionHost._altar_lift`·`hold_altar`, `AltarMove.hold_counts`·`altar_in_reach` | 호스트는 F를 누르고 `hold_counts`이고 그 프레임의 발에서 손 닿는 제단 칸이 있는(M5-fix) 프레임이 이어진 수를 세고, ALTAR_LIFT는 그 수가 `ALTAR_PICKUP_HOLD_TICKS` 이상일 때만. 겨눈 칸은 요청의 칸으로만 봄(호스트는 프레임마다의 조준 칸을 모름) | 클라이언트가 "2초 눌렀다"고 주장할 길을 없앰. M5-fix: 멀리서 누르고 있다가 손 닿는 첫 프레임에 드는 길도(README가 "바로 들 수 없다"고 했으나 그 길이 열려 있었다). 조준은 매 프레임 보내지 않으므로 겨눈 칸은 마지막 프레임의 요청만 |
| 작물 상태 = 편집 (M5c) | `SessionHost._step_farms` → `apply_world_edit` | 농장의 편집을 다른 편집처럼 그 지도의 사람에게 | 위 "작물 상태 = 편집"의 잰 값(자라는 밭 14 B/s). 따로 메시지를 만들지 않아 스냅샷·해시·편집 기록 하나로 끝남 |
| 클라이언트의 정화 깜빡임 (M5c) | `SessionClient.on_edit`, `purify_flashes` | 오염 칸이 0이 되는 편집마다 그 칸을 깜빡임 | 정화를 알리는 사건 메시지를 따로 두지 않으려고. 호스트 화면은 `_purified`에서 같은 칸을 깜빡임 |
| 호스트 틱 순서 (M5c) | `SessionHost.tick` | 프레임 → 늦은 부활 → 아레나 → 든 사람 검사 → 농장 | 혼자 할 때의 Main(플레이어 → 전투 → 농장)과 같은 순서: 같은 틱에 같은 시듦·자람 |
| welcome의 밭 기록 (M5c) | `SessionClient.on_welcome` 로그 | `altar= tilled= crops= withered= corrupted=` | 시험(늦은 참가자가 시든 밭·옮긴 제단을 받음)과 사람이 볼 콘솔 |
| 시험 성장 속도 (M5c) | `--test-crop-ticks`, `Farm.stage_ticks_base`, `Farming.stage_ticks(fast, base)` | 0 = `CROP_STAGE_TICKS` | 세션 시험이 몇 초 안에 익는 것을 보려고. 게임 값(임시값 "M5a 자라기")은 그대로 |
| 빛 텍스처 캐시 (M5b, M5-fix) | `AltarLight.cache_key`·`texture_for` | 열쇠 = 테두리·띠·반경 + 가운데의 4px 위상(round(가운데) mod 4)과 소수부. 제단이 어디 있든 한 쌍(226×226), 놓지 않음 | 4.7.2에서 텍스처를 풀면 엔진 오류(G2). 그림은 가운데에 그만큼만 달리고(디더 무늬가 월드 픽셀 4px 주기, 원판은 가운데 기준) 노드가 가운데에 선다. M5b까지는 열쇠가 가운데 자체라 새 자리마다 둘을 만들고(약 38ms, 모든 기기) 계속 쌓였다. `test_light.gd`가 같은 위상의 다른 자리 = 같은 바이트·같은 열쇠, 다른 위상·소수부 = 다른 그림·다른 열쇠를 본다 |
| 든 사람 검사 자리 (M5-fix) | `Main.check_carriers`(`_physics_process`: 전투 다음, 농장 앞) | 다운되거나 죽은 운반자의 내려놓기를 그 틱 전투가 끝난 뒤 한 번 | 호스트(`SessionHost.tick`: 아레나 다음 `_check_carriers`)와 같은 자리라 같은 틱에 같은 자리를 고른다. 전에는 맞는 순간(`_on_hurt`, 아레나 걸음 가운데: 이단 위치가 반쯤 옮겨진 때)이었다 |
| 채널링 끊김 셈 (M5-fix) | `SessionHost._on_member_channel_broken`(멤버의 `Player.channel_broken`) | 프레임 안의 끊김(움직임·대시·사용·독 다운)과 프레임 사이의 맞음 모두 `channel_broken` 하나·로그 `channel ... broken: <이유>` 한 줄 | `_channel_events`는 프레임 안에서만 봐서 아레나의 칼이 끊은 것을 세지 않았다(README는 "맞음"도 센다고 적었다) |
| 내려놓을 자리 찾기 비용 (M5-fix) | `AltarMove.set_down_rect`·`_refusal`·`_lights_a_heretic` | 비워 두는 자리(입구 찾기 포함)는 찾기마다 한 번, 찾기에서는 이단의 빛 검사를 먼저 | 이단이 운반자 옆에 있으면 후보 수백 개가 저마다 입구를 찾았다(시드 1에서 약 9ms, 검토 17.6·28.9ms) → 0.5~1ms. 찾기는 되는지만 보므로 순서가 결과를 바꾸지 않고, `place_refusal`의 거부 이유 순서는 그대로 |
| 마지막 제단 자리 (M5-fix) | `GameWorld.last_altar_rect` | 들기 편집이면 떠난 자리, 놓기면 새 자리, 받은 월드에 제단이 없으면 빈 칸 | 내려놓기의 마지막 길과 호스트를 잃은 클라이언트의 되놓기가 쓴다. 월드 데이터(스냅샷·해시)가 아니라 그 기기의 기억이라 전송 형식이 그대로다(호스트의 `altar_home`과 같은 값) |
| M7a 아이템 번호 | `ItemDB._build` | 새 아이템 열넷을 표 끝에(성수 33 뒤 34부터): 통나무·널판·주괴 둘, 작업대 셋·창고, 1티어 무기 다섯, 갑옷 | 전송 형식·스냅샷이 아이템을 번호로 보낸다(M2b): 앞 번호 그대로 |
| M7a 레시피 번호 | `Crafting.recipes` | 물약 여섯(0~5) 뒤에 체인 열넷(6~19), 수리 여섯(20~25) | CRAFT 요청이 번호로 보낸다(M6b) |
| M7a 작업대·창고 아이콘 | `ItemIcons.fit_icon`, `ItemDef.icon_fit` | 놓은 그림의 불투명 상자를 16×16에 들어가는 가장 작은 정수 걸음으로 건너뛰어 줄임(최근접, 새 색 없음), 가운데·바닥에 붙임 | 아이콘 그림이 없다. 코드로 새로 그리는 것보다 그 물건으로 읽힌다 |
| M7a 1티어 표시 | `ItemIcons.TIER_MARK` | 기본 무기 아이콘의 왼쪽 위 3×3에 금빛 십자 + 잿빛 검정 모서리 | 같은 모양의 두 무기를 칸에서 가르려고. 등급이 없는 아이템이라 상급 점(칸 2,2)과 겹치지 않음 |
| M7a 내구도 막대 | `Hud.DUR_AT`·`DUR_SIZE`·`DUR_HIGH`·`DUR_MID`·`DUR_LOW`, `Hud.draw_durability` | 칸의 (2, 14)에 14×2, 잿빛 검정 바탕, 반 넘으면 금빛 #f4c95d, 4분의 1 넘으면 호박색 #e0861a, 그 밑 녹빛 #b8432f, 0이면 전체 녹빛, 가득이면 그리지 않음. 남은 비율을 올림한 너비(1px 이상) | 수(오른쪽 아래)와 상급 점(왼쪽 위)을 피해 아이콘 아래쪽. 색은 brief §4 신앙 줄과 물약 색, HP 막대의 녹빛 |
| M7a 갑옷 칸 | `Hud.ARMOR_GAP`, `ARMOR_EMPTY`, `Hud.armor_slot_origin` | 핫바 첫 칸 왼쪽 6px, 인벤토리를 열었거나 갑옷을 입었을 때만, 빈 칸은 갑옷 아이콘을 28% 불투명도로 | 기본 화면(갑옷 없음)이 M6까지와 같게 |
| M7a 창고 창 | `ChestPanel.PAD`·`HEADER`·`GAP_ABOVE` | 핫바 너비(+ 3px 여백), 인벤토리 격자 맨 윗줄 6px 위, 머리 18px, 칸은 HUD 칸 그대로 | 인벤토리 칸과 한 줄로 맞아 옮기는 칸을 찾기 쉽게 |
| M7a 제작 창 넓이·스크롤 | `CraftingPanel.INPUT_GAP`, `width_for`, `rows_fit`, `first` | 재료 칸 사이 1px, 너비 = 가장 긴 줄(재료 하나면 60px 그대로), 화면 높이에 들어가는 줄만 그리고 고른 줄을 따라 스크롤, 위·아래 금빛 1px 표시 | 모루 줄이 많고(아홉 + 수리) 재료가 셋까지라 |
| M7a 창고 해시 | `WorldData.chests_bytes`, `content_hash` | 무언가 든 창고만, 자리 순(줄 순서): u16 x, u16 y, 칸마다 u8 아이템 번호 + 1, u8 수, u8 등급, u16 내구도. 하나도 없으면 해시에 아무것도 더하지 않음 | 창고 없는·빈 창고의 월드 해시가 M5c 그대로(골든 해시 그대로) |
| M7a 입기·벗기 | `Gear.equip`·`unequip` | 입던 갑옷은 새 갑옷이 있던 칸으로(맞바꿈), 벗으면 첫 빈 칸 | 칸이 하나라 |
| M7a 수리 대상 | `Gear.most_worn` | 남은 내구도가 가장 적은 것, 같으면 칸 순서로 앞(입은 갑옷은 맨 뒤) | 한 줄이 한 아이템 종류라 어느 것을 고칠지 정해야 해서 |

## 그림 출처

`art/`의 파일은 모두 `assets/concept`의 우리 파일 그대로다 (`test_actors.gd`가 저장소에서 돌 때 96개 전부 md5 비교, M3a에서 19개, M4a에서 9개, M6a에서 2개, M5a에서 4개, M5b에서 4개, M7a에서 9개 더함). 도구 아이콘 6개는 파일이 아니라 코드다(`items/item_icons.gd`, 임시값).

| 파일 | 원본 |
|---|---|
| `tiles_grass-soil_v03.png`, `tiles_grass-soil_v01.json` | `04-env/` (풀↔일군 흙 Wang 16장, JSON은 v01 배치) |
| `tiles_grass-corruption_v05.png` | `04-env/` (풀↔재) |
| `tiles_grass-corruption_v02.json` | `03-pixel/` (v05 그림의 배치) |
| `tiles_grass_var_1~4_v02.png`, `tiles_soil_var_1~2_v01.png`, `tiles_ash_var_1~3_v02.png` | `04-env/` (속 타일 변형) |
| `chars/base_body_v02_walk.png`, `chars/base_body_v02_idle.png` | `03-pixel/` (기본 몸 걷기 6 / idle 4프레임, 줄 남·동·북, 발 y=31) |
| `chars/sig_paladin_shield_v01.png`, `sig_miner_pickaxe_v01.png`, `sig_archer_bow_v01.png`, `sig_cleric_halo_v01.png`, `sig_herbalist_pouch_v02.png` | `03-pixel/` (클래스 표식 레이어 5종, 걷기 v01 첫 프레임에 그림) |
| `env/altar_v04.png`, `env/altar_v04_unlit.png` | `04-env/` (제단 3×3, 켜짐·꺼짐) |
| `chars/base_body_v02_{pickaxe,hoe,sickle,watering,sword,bow,magic}.png` (M2a) | `03-pixel/` (몸 동작 7개, 64×64 칸, 시작 칸 + 6·8프레임, 줄 남·동·북, 발 y=47. 10~12차 + 손질) |
| `chars/base_body_v02_throw.png` (M2a) | `03-pixel/` (던지기 32×32, 7프레임, 발 y=31. 8차 + 손질) |
| `items/item_sprig_{healing,buff,poison}_v02.png`, `items/item_wild_{healing,buff,poison,herb_clump}_v02.png` (M2a) | `04-env/` (본 제작 묶음 2, size 16: 꺾은 약초 = 아이콘, 자라는 약초·덤불 = 월드 그림. 채택 후보) |
| `items/item_mushroom_{a,b,c,d,ash}_v02.png`, `items/item_stone_{a,b,c,mossy,veined,mould,block}_v02.png` (M2a) | `04-env/` (같은 묶음: 버섯 5, 돌 6, 돌 블록 = 재료. 채택 후보) |
| `tiles/tiles_dungeon_v02.png`, `tiles/tiles_dungeon_v01.json`, `tiles/tiles_dungeon_v02_var.png` (M3a) | `04-env/` (던전 바닥↔벽 절벽 셋 25장 + 속 타일 변형 5장, JSON은 v01 배치. 1차 시험 연장 + 2차 손질, 채택 후보) |
| `tiles/tiles_ore_{copper,iron}_{a,b}_v02.png` (M3a) | `04-env/` (벽 윗면에 박은 광맥, 마지막 손질. 채택 후보) |
| `tiles/wall_crack_top_v01.png`, `tiles/wall_crack_face_v01.png` (M3a) | `04-env/` (부서지는 벽 금 3단계, 윗면 16×16 / 앞면 16×24. 본 제작 손그림) |
| `env/dungeon_entrance_v02.png`, `env/dungeon_entrance_stairs_v01.png`, `env/dungeon_entrance_debris_v01.png` (M3a) | `04-env/` (던전 입구 아치, 내려가는 계단, 둘레 잔해. 출구 계단은 이 아치 + 뒤집은 계단으로 만든 임시) |
| `env/heretic_shrine_v02.png` (M3a) | `04-env/` (이단의 제단, 불 없음) |
| `env/prop_wall_torch_a_v02.png`, `env/flame_large_v01.png` (M3a) | `04-env/` (꺼진 벽 횃불 + 공유 큰 불꽃 5프레임) |
| `env/prop_lantern_ground_v03_lit.png`, `env/prop_lantern_ground_v03_emissive.png` (M3a) | `04-env/` (켜진 땅 랜턴과 빛 마스크, 손질 2. 놓은 횃불의 임시 그림) |
| `items/item_ore_{copper,iron}_a_v02.png` (M3a) | `04-env/` (광석 아이템, 04-env 던전 목업이 쓴 것) |
| `chars/base_body_v02_hurt.png`, `chars/base_body_v02_death.png` (M4a) | `03-pixel/` (기본 몸 피격 6 / 사망 7프레임, 32칸, 발 y=31, 8차 + 손질) |
| `enemies/heretic_v02_{walk,idle,attack,hurt,death}.png` (M4a) | `03-pixel/` (이단 13차 + "검토 뒤 고침", 채택 후보. 걷기 6·idle 4·피격 6·사망 7은 32칸, 공격 8은 64칸 9열) |
| `env/prop_sack_small_v03.png` (M4a) | `04-env/` (작은 자루. 사망 가방의 임시 그림) |
| `env/prop_bone_pile_a_v02.png` (M4a) | `04-env/` (뼈 더미. 부서진 이단의 제단 임시 그림에 얹음) |
| `env/alchemy_table_v05.png` (M6a) | `04-env/` (조제대 48×32, 4단계 1차 시험 정렬형 c를 다듬고 물약 색을 작물에 맞춘 v04를 44색 → 24색으로 줄인 마지막 손질판. 채택 후보) |
| `items/items_v04_strip.png` (M6a) | `04-env/` (작은 것 묶음 16×16 18칸 띠, 1차 시험 마지막 손질판. 4·5·6번째 칸 = 회복·버프·독 물약(#21·#22·#23)을 물약 아이콘으로 잘라 씀(`ItemDB.STRIP_POTIONS`), 나머지 칸은 쓰지 않음. 채택 후보) |
| `tiles/tiles_grass-soil_v03_watered.png`, `tiles/tiles_soil_var_1_v01_watered.png`, `tiles/tiles_soil_var_2_v01_watered.png` (M5a) | `04-env/` (물 준 흙: 일군 흙 v03·흙 변형 둘의 흙 픽셀만 바꾼 사본, 1차 시험 2차 손질. 칸별 덧칠로 씀 ● R29. 채택 후보) |
| `env/crops_v03_sheet.png` (M5a) | `04-env/` (작물 셋 × 0~4단계·수확 다발·시듦, 16칸 7×3, 손그림 v03. 0~4단계와 시듦 칸을 씀, 흙더미 색은 코드에서 흙에 맞춤. 채택 후보) |
| `items/items_v04_strip.png` (M5a에서 더 씀) | 위 M6a 줄의 파일 그대로. 첫 세 칸 = 씨앗 봉투 셋(#18~#20, 회복·버프·독초)을 씨앗 아이콘으로 잘라 씀(`ItemDB.STRIP_SEEDS`) |
| `items/item_holy_water_a_v02.png` (M5b) | `04-env/` (성수 병, 본 제작 묶음 2 #58 "금실 감은 코르크의 작은 유리병, 상아빛 물", 판정 좋음. b·c 판은 쓰지 않음. 채택 후보) |
| `env/decal_ashcreep_{1,2,3}_v01.png` (M5b) | `04-env/` (풀 쪽 경계의 잿빛 얼룩, 흩뿌리는 오염 장식 묶음. 정화된 칸에 잠깐 보이는 재로 빌려 씀(칸 가운데). 채택 후보) |
| `env/workbench_v03.png` (M7a) | `04-env/` (기본 작업대 48×32, 본 제작 정렬형 b → v02 손질 → v03 손그림 망치·톱, "본 제작 손질 2". 채택 후보. v03 = 가장 나중 판) |
| `env/anvil_v03.png` (M7a) | `04-env/` (모루 32×32, 정렬형 b → v02 → v03 쇠 8색을 밝힘: v02가 1배에서 검은 덩어리로 읽히던 약점. 채택 후보) |
| `env/relic_bench_v03.png`, `env/flame_small_v01.png` (M7a) | `04-env/` (성물 제작대 48×32 v03: 정지 불꽃을 지우고 공유 작은 불꽃 자리 (37, −4), 27 → 24색. 작은 불꽃 4 + 1프레임(4×7). 채택 후보) |
| `env/storage_chest_v02.png` (M7a) | `04-env/` (공유 창고 = 긴 낮은 상자 f를 손질한 판, 14색. 채택 후보 ○ "긴 상자 하나") |
| `items/item_log_v02.png`, `items/item_planks_a_v02.png`, `items/item_ingot_copper_a_v02.png`, `items/item_ingot_iron_a_v02.png` (M7a) | `04-env/` (묶음 2 #62 통나무, #46 널판 셋, #42 구리 주괴, #44 철 주괴. 3/4 v02: 돌 블록·광석 아이콘과 같은 판. 정면 v03을 쓸지는 ○ brief §5.7) |

## 측정 (이 데스크탑, `.godot/`을 지운 상태에서)

M7a (2026-10-25):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 4.6초, 종료 0, 오류 줄 0. 새 스크립트 여섯(`.uid`: gear·storage·chest_panel·test_workbench·test_gear·test_storage)과 새 그림 아홉(`.import`)을 커밋. 그림 출처 96개 |
| 전체 테스트 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 30파일 통과, 27,552 / 27,552 checks, 374.0초, 종료 0, 오류 묶음 8개(알린 것 그대로). 그 전 실행(`tools/check_render.gd`만 다름)도 30파일 통과 27,552 checks 376.9초 |
| 새 시험 셋 | `test_workbench.gd` 568 checks 약 0.4~0.8초, `test_gear.gd` 289 checks 약 0.7~1.1초, `test_storage.gd` 85 checks 약 0.3~0.7초 |
| 첫 실행 (고치기 전) | 새 시험의 기대값이 틀린 것들: 가득 찬 인벤토리의 "자리 없음"을 재료 묶음이 비며 칸이 생기는 경우로 시험함, 한 줄의 작업대 셋에서 같은 거리의 둘(앞의 것을 고르는 것이 맞음), 활의 36틱 당기기가 이단의 칼(30틱)에 끊김, 벽이 깨진 뒤의 휘두르기는 공격이라 1티어 곡괭이가 닳음(채굴만 셀 때 0), 손 레시피 창에서 널판 전에는 모루가 안 보임. 코드는 그대로, 시험을 고침. 갑옷 아이콘 첫 판은 외곽선이 1/3에 못 미쳐(아이콘 규칙) 다시 그림 |
| 내보내기 | x86_64 4초, 종료 0, 오류 줄 0 |
| 스모크 (`--smoke`, 에디터 빌드와 내보낸 exe) | 384 checks ok(M5c 341 + M7a), `... chain=20/7 gear=21/8/96 chest=16 ...`, `items=48`, `potions=6/1`(조제대 레시피 수 그대로), 지상·던전 해시(`1d9f92c7b5ef`·`8dda0ad69ad9`)·`spawn_tiles=678` 그대로 |
| 창 그림 검사 `check_render.gd` | 5초, 22부분 모두 ok(M7a 셋 더함: `stations` 그린 픽셀 2,403 불일치 0, `gear_hud` 막대 140·픽셀 394 불일치 0, `m7_panels` 창고 3,416·모루 창 8,528 픽셀 불일치 0, 너비 96). M6a `crafting`은 넓어진 창 코드로도 그대로(6줄, 3,818픽셀) |
| 스크린샷 | `m7_stations.png`·`m7_chest.png`·`m7_worn_gear.png`, 콘솔 오류 줄 0 |
| 일부러 깨 보기 16개 (targeted 시험) | 모두 FAIL·종료 1: 1티어 피해 보너스 없앰(`gear` 15 실패), 갑옷 방어 0(13), 사망 마모 없앰(6), 수리가 내구도를 채우지 않음(6), 1티어 곡괭이를 곡괭이로 안 봄(4), 혼자 할 때 사용 마모 없앰(10), 가방이 갑옷을 가져감(2), 창고의 빛 규칙 없앰(`storage` 6), 창고가 내구도를 버림(3), 창고 내용물을 해시에서 뺌(3), 일부 넣기 대신 모두 아니면 없음(1), 모루 레시피의 철광석 2 → 1(`workbench` 1), 자리 없음 검사를 없앰(2), 호스트가 작업대를 놓아 줌(3), 호스트가 M7 레시피를 만들어 줌(3), 손 제작 창이 안 열림(1). 각각 되돌린 뒤 파일은 바이트까지 그대로 |
| 일부러 깨 보기, 창 그림 4개 | 모두 FAIL·종료 1: 내구도 막대 1px 아래(`gear_hud` 불일치 73, `m7_panels` 창고 26·모루 28), 모루 그림 1px 아래(`stations` 362), 재료 칸 사이 2px(`m7_panels` 모루 2,766), 갑옷 칸 안 그림(`gear_hud` 282) |

M5-fix (2026-10-24):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 4.1초, 종료 0, 오류 줄 0. 새 파일 없음(스크립트·그림 그대로, 그림 출처 87개) |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 27파일 통과, 26,435 / 26,435 checks, 362.3 / 366.0초, 종료 0, 오류 묶음 8개(알린 것 그대로). 바꾼 파일 altar_move 165(M5c 133), net_fields 165(약 6.5초), light 80, farming 579, purify 129 |
| 첫 전체 실행 (고치기 전) | 24 통과 3 실패(mining·net_maps·net_session의 `cave`): 호스트 `_place`의 `[] as Array[Vector2]`를 삼항 연산자 안에 써서 던전의 횃불 놓기가 스크립트 오류(타입 있는 배열에 타입 없는 배열). `if`로 나눠 고친 뒤 위 두 번 |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 80.9초, `net_fight` 270 checks 67.8초, `net_brew` 230 checks 55.0초, `net_farm` 218 checks 31.8초, `net_purify` 149 checks 45.9초 모두 통과, 자식 로그 689 + 224 + 204 + 306 + 191줄에 `ERROR:` 0 |
| 내보내기 | x86_64 3.6초 `evensong.exe` 110,065,024 B, ARM64 3.2초 92,458,880 B, 둘 다 종료 0, 오류 줄 0 |
| 스모크 (`--smoke`, 에디터 빌드와 내보낸 exe) | 341 checks ok, 출력 M5c와 같음(`farm=4800/2 purify=11+4/648 altar=49,45 ... fields_wire=17B/11B net=v7`, 지상·던전 해시·`spawn_tiles=678` 그대로), 두 빌드 모두 종료 0·오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 3.9초, 19부분 모두 ok. `altar`(13칸 서쪽으로 옮긴 빛을 픽셀 전부 비교: 불일치 0)가 이제 집의 텍스처 한 쌍으로 그린 빛이다 |
| 스크린샷 | 바뀐 그림 없음: 규칙이 바뀐 장면(채널링 중 들기, 소생 중 들기, 들고 있는 동안 참가, 호스트 잃음)은 찍힌 그림에 없고, 빛은 같은 텍셀이다. `m5b_altar_moved.png`·`_off`를 같은 명령으로 다시 찍어 보니 같은 장면(다른 픽셀은 더미의 idle 프레임: 위 "스크린샷") |
| 빛 텍스처 | 제단을 새 자리에 놓는 데 0.1~0.2ms(M5c 약 38ms: 텍스처 둘을 만들던 시간), 캐시는 자리가 바뀌어도 그대로(시험) |
| 내려놓을 자리 찾기 (시드 1, 이단이 운반자 1칸 옆, 탐침) | 0.46~1.0ms(고치기 전 같은 탐침 8.9~9.2ms, 검토 17.6·28.9ms), 이단 없으면 0.27ms, 같은 자리를 고름. 놓을 자리 표시의 `place_refusal` 한 번 0.26ms |
| 농장 한 틱 (탐침) | 마른 작물 1,000개 0.11ms(고치기 전 2.45ms, 검토 3.07·4.78ms), 같은 1,000개에 제단이 매 틱 옮겨지는 최악 3.2ms, 젖은 작물 120개 0.31ms, 20,000틱 대본 55µs/틱(M5c 59.6) |
| 일부러 깨 보기 16개 (고친 규칙을 하나씩 되돌려 targeted 시험) | 모두 FAIL·종료 1: 들기 셈의 채널링(혼자 1·세션 3 실패), 소생(혼자 1·세션 3), 호스트의 손 닿는 곳(5), 혼자 할 때 제단을 겨눈 F의 채널링(2), 클라이언트의 같은 것(1), 든 사람의 CHANNEL(1), 들고 있는 동안 비워 둔 자리(2), `spawn_feet`의 설 수 있는 곳(1), 채널링 끊김 시그널(2), 든 자리를 검사 없이(2), 빛 캐시 열쇠 = 가운데(텍스처 수 3 + 4), 맞는 순간 내려놓기(1), 오염 칸 수로 바뀜 보기(`test_farming` 5), 마른 작물을 모두 건너뜀(1: 처음엔 통과해서 시험을 더함), 마지막 자리 기억(2 + 2), 끈 쪽 빛 규칙(1). 되돌린 뒤 같은 시험 모두 통과 |

M5c (2026-10-24):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.9초, 종료 0, 오류 줄 0. 새 스크립트 셋(`.uid`: test_net_fields·test_net_farm·test_net_purify)을 커밋. 새 그림 없음(그림 출처 87개 그대로) |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 27파일 통과, 26,364 / 26,364 checks, 366.3 / 375.6초, 종료 0, 오류 묶음 8개(알린 것 그대로). 새 파일 net_fields 133(약 6초), net_farm 217(약 34초), net_purify 148(약 47초). 바꾼 파일 farming 579, purify 129, altar_move 133(세션 시험이 이제 호스트의 농사·정화·들기), net_maps 135(버전 7), net_session 560, core 300(새 스크립트도 불러 봄). 그 밖(net_combat 127, net_fight 269, net_brew 229, net_potions 175, heretic 14,906 ...)은 그대로 통과 |
| 첫 전체 실행 (고치기 전) | 26 통과 1 실패: `pair`의 늦은 약초사(c2)가 야생 약초를 캐서 이제 씨앗도 받는다(M5c가 일부러 세션에 켠 M5a 규칙). 기대 문자열에 `2:seed_buff x1`을 더해 고친 뒤 위 두 번 |
| 세션 시험 `--net-full` | 통과 826 checks 93.3초(9인 상한 세션 포함). 9인 걸음 호스트 송신 28.2 KB/s(UDP/IP 포함 33.8): M6b(27.2)와 비슷, 쉬는 상태 17B 그대로(채널링·든 제단은 0B) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 81.7초, `net_fight` 270 checks 62.3초, `net_brew` 230 checks 51.9초, `net_farm` 218 checks 32.4초, `net_purify` 149 checks 46.0초 모두 통과, 자식 로그 689 + 211 + 204 + 306 + 191줄에 `ERROR:` 0 |
| 내보내기 | x86_64 4초 `evensong.exe` 110,059,056 B, ARM64 3초 92,452,912 B, 둘 다 종료 0, 오류 줄 0 |
| 스모크 (`--smoke`, 에디터 빌드와 내보낸 exe) | 341 checks ok(M5b 338 + M5c 3), `... farm=4800/2 purify=11+4/648 altar=49,45 ... fields_wire=17B/11B net=v7`, 지상·던전 해시 그대로(`hash=1d9f92c7b5ef`, `hash=8dda0ad69ad9`, `dungeon_seeds=acc0a9bc2359`), `spawn_tiles=678` 그대로, 두 빌드 모두 종료 0·오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 4.0초, 19부분 모두 ok (`fields_net`: 편집 64개 중 42개가 클라이언트 스냅샷 뒤, 같은 데이터, 작물 6·시듦 6·젖음 3, 정화 9칸(클라이언트 깜빡임 9), 든 표시 있음, 채널링 120틱(점 11/11 제 자리 제 색), 호스트 대 클라이언트 0픽셀, 맨 월드와 10,130픽셀 다름). 다른 부분은 M5b와 같은 수 |
| 스크린샷 | 두 창 그림 `shots/m5c_host.png`, `m5c_client.png`(위 "스크린샷"), 두 로그 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r5m5/mut/mutate_m5c.py`: 작업 트리의 파일 하나에서 정확한 문자열 하나를 바꾸고 해당 시험을 돌리고 되돌림) | 헤드리스 30개(`net_fields` 26, 실제 세션 3, 스모크 1)와 창 그림 검사 3개, 모두 FAIL·종료 1 (아래). 처음 돌렸을 때 둘이 살아남았다: "채널링 동안 프레임 기록 안 함"은 기록 조건이 두 곳(앞·뒤)이라 한 곳만 지운 변이가 효과가 없었다(변이를 두 조건을 같이 끄게 고침), "보간이 채널링 틱을 세지 않음"은 시험이 "보인다"만 봤다: 다른 클라이언트가 그린 채널링 틱 = 100ms 전 호스트의 틱을 프레임마다 보게 시험을 더함(그 뒤 둘 다 FAIL) |

일부러 깨 보기 (M5c, 실패 수): 씨앗 USE 예산 없음(`net_fields` 1), 빛 밖 괭이를 세지 않음(2), 작물을 겨눈 낫이 공격(4), 호스트 농장이 돌지 않음(8), 농장 편집을 보내지 않음(7), 야생 약초에 씨앗 없음(1), 클라이언트 깜빡임 없음(2), 채널링이 상태에 없음(14), 든 비트가 상태에 없음(3), 채널링 검사 없음(2), F 프레임 수 검사 없음(12), 놓기 검사 없음(6), 든 사람이 모든 요청 가능(1), 다운된 든 사람이 안 내려놓음(3), 나간 든 사람이 제단을 가져감(1), 호스트 부활이 안 기다림(3), 예측 부활 자리가 옛 자리(2), 든 동안 참가자가 맵 구석(1), 채널링 프레임 기록 안 함(11), 보간이 채널링을 세지 않음(1), F가 채널링을 요청 안 함(11), 클라이언트가 F 2초를 세지 않음(9), 예측이 채널링 안 함(4), 버전 6(1), 성수 검사 없음(4), 정화 뒤 아레나가 안 따라감(1), 실제 세션: F가 채널링 안 함(`net_purify` 6), F 2초 안 셈(`net_purify` 8), 수확 등급 = 심은 사람(`net_farm` 2), 스모크: 든 비트(1). 창: 든 비트(`fields_net` 표시 없음, 46픽셀 다름), 채널링 비트(점 0/1, 451픽셀), `show_state`가 채널링을 버림(점 0/1, 4픽셀). 모두 종료 1, 파일은 되돌렸고 `.bak`은 남지 않았다

트래픽 (M5c):

| 상황 | 호스트 송신 | 비교 |
|---|---|---|
| 서 있음 (한 프로세스, 호스트 + 클라이언트 둘, ENet 페이로드) | 0 B/s | M6b 쉴 때 0 |
| M1 흙 19칸에 젖은 작물이 실제 시간으로 75초 자람 (한 프로세스) | 14.1 B/s(모두 편집: 75초에 48개, 한 틱 최대 19개, 편집 하나 11B) | 플레이어가 움직이지 않는 동안 상태 묶음 0이라 이것이 전부 |
| 채널링 한 번 3초 (한 프로세스, 9칸) | 2.3 KB/s(상태 2.15 KB/s: 채널링 중 상태가 매 틱 바뀜, 편집 124 B/s, 키프레임 35 B/s) | M3b 둘이 걸음 1.07 KB/s(클라이언트 둘이라 약 두 배) |
| 실제 세션 `farm` 둘이 동작 (act2/3) | 3.34 KB/s(4.96 KB/s UDP/IP 포함), 58 pkt/s. c1 수신 1.63 KB/s | M6b `brew` 싸움 2.04~2.10 KB/s |
| `farm` 아무도 안 움직임 (0/3) | 150 B/s(402) | M4b fight 끝 0/3 118~129 |
| `purify` 채널링이 든 구간 (0/2, 9.3초: 채널링은 걷기·몸 동작이 아니라 "0/n" 묶음에 들어간다) | 426 B/s(763). 채널링 3초는 위 한 프로세스 값 | 알려진 문제: 통계 묶음이 채널링을 따로 세지 않음 |
| `altar` 싸움 (fight/2) | 2.18 KB/s(3.45) | M4b fight/2 1.90 KB/s |

M5b (2026-10-24):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 5.1초, 종료 0, 오류 줄 0 (세 번 모두 종료 0·오류 0). 새 그림 4장(`.import`: 성수 병, 재 얼룩 셋)과 새 스크립트 7개(`.uid`: purify·altar_move·purify_view·altar_ghost·altar_mark·test_purify·test_altar_move)를 커밋 |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 24파일 통과, 25,864 / 25,864 checks, 268.1 / 270.3초, 종료 0, 오류 묶음 8개(알린 것 그대로). 새 파일 purify 131(약 0.5초), altar_move 131(약 0.6초), items 1,662(성수 줄), actors 1,691(그림 출처 83 → 87개), core 297(새 스크립트도 불러 봄). 세션 파일(net_session 560, net_fight 269, net_brew 229)과 farming 580·heretic 14,906·combat 555·light 73은 그대로 통과 |
| 스모크 (`--smoke`, 에디터 빌드와 내보낸 exe) | 338 checks ok(M5a 321 + M5b 17), `items=34 ... farm=4800/2 purify=11+4/648 altar=49,45`, 지상·던전 해시 그대로(`hash=1d9f92c7b5ef`, `hash=8dda0ad69ad9`, `dungeon_seeds=acc0a9bc2359`), `spawn_tiles=678` 그대로, 전송 형식 `net=v6` 그대로, 두 빌드 모두 종료 0·오류 줄 0 |
| 내보내기 | x86_64 `evensong.exe` 110,042,480 B, ARM64 92,436,336 B, 둘 다 종료 0, 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 4.5초, 18부분 모두 ok (`purify`: 정화 11칸 모두 풀, 바닥 = PNG 합성 불일치 0, 첫 프레임 불일치 0(금빛 660·재 얼룩 363픽셀), 저녁 켬 금빛 틀림 0·재 얼룩 밝음 0, 점 64픽셀 불일치 0. `altar`: 13칸 서쪽 (49,45), 확인 129,340픽셀 불일치 0, 화면 안의 옛 영역 38,573픽셀 중 밝음 0, 불꽃 81 제 색, 머리 위 표시 46픽셀 불일치 0, 놓을 자리 표시 496픽셀(금빛·빨강) 불일치 0, 제단 제자리로). 다른 부분은 M5a와 같은 수 |
| 스크린샷 | `shots/m5b_purify_channel.png`, `m5b_purified.png`, `m5b_purified_off.png`, `m5b_altar_carried.png`, `m5b_altar_moved.png`, `m5b_altar_moved_off.png` (위 "스크린샷"), 콘솔 오류 줄 0 |
| 제단을 처음 가는 자리에 놓기 (헤드리스, `test_altar_move.gd`의 note) | 칸 편집 아홉 + 제단 노드 + 빛 텍스처 둘 = 약 38ms (37.5 / 37.7). 갔던 자리로 돌아가면 텍스처를 다시 만들지 않음 |
| 일부러 깨 보기 (스크래치 `r5m5/mut/mutate_m5b.py`: 작업 트리의 파일 하나에서 정확한 문자열 하나를 바꾸고 해당 시험을 돌리고 되돌림) | 헤드리스 26개(`purify`·`altar_move` 25, 스모크 1) 모두 FAIL·종료 1, 창 그림 검사 7개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M5b, 실패 수): 성수가 5×5(`purify` 5), 채널링 원판 대신 정사각형(8), 누구나 채널링(13), 시작은 오염 위에서만(10), 재 바닥이 그대로(3), 성수를 안 씀(6), 채널링 한 틱 짧게(2), 걸어도 안 끊김(3), 맞아도 안 끊김(1), 아레나가 따라가지 않음(`purify`·`altar_move` 17), F가 채널링을 시작하지 않음(8), 세션이 성수 USE를 받음(1), 제단 들기 1틱(`altar_move` 2), 재 위에도 놓음(10), 새 빛 안의 이단 무시(1), 부활 자리 검사 없음(2), 도착점 검사 없음(1), 제단 자리를 다시 읽지 않음(51), 빛이 따라가지 않음(7), 들고 있어도 부활(2), 다운돼도 안 내려놓음(3), 더미가 그대로(1), 놓을 자리가 한 칸 멀리(11), 들고 있어도 도구를 씀(11), 들고 오가기(13), 스모크의 원판을 정사각형으로(스모크 FAIL: 11 대신 16칸). 창 그림 검사: 금빛 테두리 한 칸 더 안쪽(`purify` 불일치 1,232), 재 얼룩 1px 오른쪽(202), 정화 효과 shaded(금빛 660·점 64 틀림), 점 고리 반지름 + 0.5칸(128), 머리 위 표시 1px 아래(`altar` 33), 안 되는 자리도 금빛(248), 빛이 옛 자리에(불일치 67,475·옛 영역 밝음 33,687)

M5a (2026-10-24):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.7~4.4초, 종료 0, 오류 줄 0 (세 번). 새 그림 4장(`.import`: 물 준 흙 셋, 작물 시트)과 새 스크립트 4개(`.uid`: farming·farm·field_view·test_farming)를 커밋 |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 22파일 통과, 25,578 / 25,578 checks, 272.1 / 265.9초, 종료 0, 오류 묶음 8개(알린 것 그대로). 새 파일 farming 580 (약 4.4초), items 1,649(씨앗 셋의 표·아이콘 픽셀), actors 1,687(그림 출처 79 → 83개), core 290(새 스크립트 넷도 불러 봄). 세션 파일(net_session 560, net_fight 269, net_brew 229)은 그대로 통과(세션 흐름은 씨앗 USE 거부 한 줄만 더함) |
| 스모크 (`--smoke`, 에디터 빌드와 내보낸 exe) | 321 checks ok(M6b 308 + M5a 13), `items=33 ... farm=4800/2`, 지상·던전 해시 그대로(`hash=1d9f92c7b5ef`, `hash=8dda0ad69ad9`, `dungeon_seeds=acc0a9bc2359`), 전송 형식 `net=v6` 그대로 |
| 내보내기 | x86_64 4초 `evensong.exe` 110,008,584 B, 종료 0, 오류 줄 0 (ARM64는 이번에 내보내지 않았다) |
| 창 그림 검사 `check_render.gd` | 3.7초, 16부분 모두 ok (`fields`: 빛 안 120칸 중 101칸을 일굼, 바닥 = PNG 합성 불일치 0, 작물 18 · 젖은 칸 11, 화면 불일치 0 · 그린 픽셀 4,043, 저녁 켬 밝음 표본 2,539 · 어두움 0). 다른 부분은 M6-fix와 같은 수 |
| 스크린샷 | `shots/m5_field_evening.png`, `m5_watered.png`, `m5_withered.png`, `m5_withered_off.png` (위 "스크린샷"), 콘솔 오류 줄 0 |
| 농장 한 틱 (헤드리스, `test_farming.gd`의 note) | 젖은 작물 120개(그중 75개는 빛 밖이라 시듦) 약 420µs(600틱 평균), 20,000틱 대본(밭 12칸, 대본의 동작 포함) 1.55초 = 틱당 78µs. 오염 레이어를 바이트로 바로 읽기 전에는 대본이 틱당 191µs |
| 일부러 깨 보기 (스크래치 `r5m5/mut/mutate.py`: 작업 트리의 파일 하나에서 정확한 문자열 하나를 바꾸고 해당 시험을 돌리고 되돌림) | 헤드리스 21개(`farming` 20, 스모크 1) 모두 FAIL·종료 1, 창 그림 검사 5개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M5a, 실패 수): 독초를 누구나 심음(`farming` 12), 약초사의 빠른 성장을 뺌(2), 마른 작물도 자람(5), 오염 닿는 거리 1칸(10), 빛 = 모서리 셋(1: 빛 판정이 따로 적은 네 모서리와 4칸 다름), 빛 밖도 일굼(3), 수확 등급 늘 상급(5), 마르는 틱 하나 늦게(5), 되살아남 없음(5), 마름을 자람보다 먼저(2: 다시 준 물의 다음 단계가 1틱 늦음), 물 준 사분면을 반대 모서리에서(1: 사분면 12개), 낫이 작물을 겨눠도 공격(5), 야생 약초에 씨앗 없음(2), 세션이 씨앗 USE를 받음(1), 시들 자리에도 심음(3), 빛 밖도 시들지 않음(4), 익지 않아도 거둠(5), 인벤토리가 차면 수확을 늘 버림(2), 젖은 흙더미를 마른 색으로(1: 273픽셀이 물 준 흙 색이 아님), 스모크의 약초사 빠른 성장을 뺌(스모크 FAIL: 4,800 대신 9,600. 처음에는 스모크가 같은 함수 `Farming.stage_ticks`로 기대값을 셈해서 이 변경에도 통과했다: 기대값을 상수에서 따로 셈하게 고침). 창 그림 검사 `fields`: 물 준 사분면을 반대 모서리에서(불일치 975), 작물 1px 아래(1,627), 물 준 덧칠이 빛을 받지 않음(저녁 어두움 1,653), 젖은 흙더미 색 하나 1 다르게(14), 시든 작물을 수확 다발 칸으로(444)

M6-fix (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 5.2초, 종료 0, 오류 줄 0. 새 스크립트·그림 없음(새 `.import`·`.uid` 없음) |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 21파일 통과 24,953 checks, 283.3 / 269.2초, 종료 0, 오류 묶음 8개(알린 것 그대로). crafting 449 → 467, potions 154 → 166, net_potions 170 → 175(약 4초: 늦은 참가자의 버프가 다 되기까지 1,100틱 더), net_brew 229 그대로(조제대 자리만 옮김) |
| 세션·싸움·물약 세션을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 83.4초, `net_fight` 270 checks 68.6초, `net_brew` 230 checks 51.4초 통과(조제대를 옮긴 `brew` 포함), 자식 로그 667 + 215 + 193줄에 `ERROR:` 0 |
| 내보내기 | x86_64 4.4초 `evensong.exe` 109,974,400 B, ARM64 3.9초 92,368,256 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` | 308 checks ok, 출력 M6b와 같음(`... potions=6/1 ... potion_wire=40B/46B net=v6`, 지상·던전 해시 그대로), 1.3초, 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 3.5초, 15부분 모두 ok (`potions` 화면 불일치 0 · 그린 픽셀 1,306 · 표시 126 불일치 0, M6-fix의 어둠: 병·터짐 픽셀 197(병 92) 불일치 0 · 어두워진 표본 2,039) |
| 스크린샷 | 두 창 그림 `shots/m6b_*.png`만 다시 찍음(병 unshaded, 이단이 살아 독에 걸린 쌍. 위 "스크린샷"), 두 로그 오류 줄 0. `shots/m6_*.png` 넷은 다시 찍어 바이트까지 같았다(병이 날지 않는 프레임이라 unshaded가 닿지 않음) |
| 일부러 깨 보기 (스크래치 `r4m6/fix/mutate_fix.sh`: 작업 트리의 파일 하나를 sed로 바꾸고 해당 시험을 돌리고 되돌림) | 헤드리스 11개 중 10개 FAIL·종료 1, 1개 통과(아래), 창 그림 검사 1개 FAIL·종료 1 |

일부러 깨 보기 (M6-fix, 실패 수): 조제대가 나타나는 자리 위에도(`crafting` 3: 지상 도착점에 놓임), 작업대 찾기 창을 줄임(1), 같은 거리면 뒤의 것(1), `still_at`이 가장 가까운 것(1), 쓰러진 채 끝난 독이 필드를 남김(`potions` 1), 무기로 죽여도 독이 남음(1), 던질 점을 float로(`potions`·`net_potions` 2: 사거리 밖 던지기에서 병 58틱 어긋남), THROW + Space를 던지기로 셈(`net_potions` 2), 독 틱을 무기 맞음으로(1), 리그가 벽시계로 그림(시험 쪽을 M6b로 되돌림: 1, 늦은 참가자가 끝난 버프 표시를 계속 그림), 창 검사: 병을 shaded로(`potions` 92픽셀). **통과한 것**: 호스트의 제작 검사를 "가장 가까운 작업대가 그 종류면"으로 되돌림: 종류가 하나뿐이라 시험이 다른 종류를 만들 수 없다(알려진 문제, M7)

M6b (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 5초, 종료 0, 오류 줄 0. 새 시험 스크립트 둘의 `.uid`(`test_net_potions`·`test_net_brew`)를 커밋. 새 그림 없음 |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 21파일 통과 24,918 checks, 272.8 / 271.7초, 종료 0, 오류 묶음 8개(알린 것 그대로). 새 파일 net_potions 170 (약 4초) · net_brew 229 (54초), crafting 448 → 449, core 284 → 286(새 스크립트 둘도 불러 봄). M6a보다 약 60초 늘었다(대부분 `brew`·`brew4`) |
| 세션 시험 `--net-full` | 통과 826 checks 93.8초 (9인 상한 세션 포함). 9인 걸음 호스트 송신 27.2 KB/s(UDP/IP 포함 32.6): 쉬는 플레이어는 효과 블록이 없어 M4b(27.8~28.1)와 같은 크기 |
| 세션·싸움·물약 세션을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 81.0초, `net_fight` 270 checks 67.6초, `net_brew` 230 checks 51.5초 통과, 자식 로그 687 + 219 + 198줄에 `ERROR:` 0 |
| 내보내기 | x86_64 4초 `evensong.exe` 109,972,512 B, ARM64 4초 92,366,368 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` | 308 checks ok(`... combat_wire=25B potion_wire=40B/46B net=v6`, 지상·던전 해시 그대로), 1초, 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 4초, 15부분 모두 ok (`potions_net` 클라이언트 = 호스트 불일치 0 · 그린 픽셀 1,095 · 병 1 · 터짐 1 · 표시 셋, 받은 인벤토리로 연 창 = 혼자 연 창 불일치 0 · 그린 픽셀 5,911) |
| 두 창 그림 | `shots/m6b_host.png`, `shots/m6b_client.png` (위 "스크린샷"), 두 로그 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r4m6/m6b/mutate_m6b.sh`, `mutate_render_m6b.sh`: 작업 트리의 파일 하나를 sed로 바꾸고 해당 시험을 돌리고 되돌림) | 헤드리스 27개 모두 FAIL·종료 1, 창 그림 검사 4개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M6b, 실패 수): 작업대에서 멀어도 제작(`net_potions` 6), 클래스 검사를 호스트 클래스로(3), 제작 요청 예산 없앰(2), 던지는 중에도 던지기(1: 40번 중 39 `busy`), 손 닿는 칸 검사 없는 던지기(1), 세션에서 가득 찬 HP 마시기(1), THROW·CRAFT가 지도를 안 실음(11: 다운·다른 지도 검사가 빠짐), 세션의 조제대가 몸을 안 봄(2), 효과 블록을 안 보냄(12), 효과가 타이머가 아님(`idle`)(9: 버프된 넷의 예측·혼자 = 호스트·버프 상태 크기. 처음 sed는 줄 이음을 남겨 파싱 오류였다: 동작이 아니라 컴파일을 깬 것이라 `and true`로 다시 해서 셈), 효과가 걸림이 호스트 사건이 아님(4: vitals 보정), 적 묶음에 독 표시 없음(8), 클라이언트가 병 사건을 버림(4), 클라이언트의 병이 한 틱 앞(1: 호스트가 날린 38틱 모두 어긋남), 늦게 온 사람에게 날고 있는 병 없음(1), 터짐 사건 없음(3), 클라이언트가 받은 인벤토리를 기억하지 않음(2), 던진 회복이 일으킴(3), 호스트 자신이 못 던짐(18), 클라이언트가 못 던짐(14), 호스트가 물약 효과 틱을 거부(43), 전송 형식에서 THROW 칸 검사 없음(1), 아무 레시피 번호나(1), 창이 열려도 세션 입력이 걸음(3), 던지기가 다시 USE(38), 봇의 제작 줄이 Main에 안 감(`net_brew` 8). 창 그림(`potions_net`): 클라이언트가 이단의 독 표시를 안 그림(불일치 31), 클라이언트의 병이 한 틱 앞(125), 받은 인벤토리를 기억하지 않음(창 줄 0/4, 불일치 4,629), 터짐이 6틱 늙음(56, 터짐 0)

트래픽 (M6b):

| 상황 | 값 | 비교 |
|---|---|---|
| 셋이 서 있고 하나가 상급 버프 (한 프로세스, ENet 바이트) | 호스트 → 클라이언트 둘 3,160 B/s(상태 묶음 79B × 20Hz × 2), 버프된 클라이언트의 입력 300 B/s. 쉬면 0 | 효과가 타이머라 걷는 것과 같은 길(위 알려진 문제). M3b pair 2/2 걸음 1.07 KB/s |
| 위 + 빛 밖에 서 있는 이단에 상급 독 | 3,535 B/s(+ 적 묶음 275 + 키프레임 100) | 독이 HP를 깎는 30틱마다 묶음(깜빡임) |
| 실제 세션 `brew` 셋이 서 있음, c1이 버프 (0/3) | 4.52~4.54 KB/s (UDP/IP 포함 5.92~5.96), 50 pkt/s, c1 수신 2.24~2.26 KB/s (세 번) | M4b fight 끝 0/3 118~129 B/s (효과 없음) |
| `brew` 둘이 싸움(호스트의 회복·버프 병, c1의 독 병) (fight/2) | 2.04~2.10 KB/s (2.81~2.89) | M4b fight/2 1.90 KB/s |
| `brew4` 넷이 싸움, 약초사 둘이 독 병 (fight/4) | 6.8~8.1 KB/s (9.5~11.1 KB/s ≈ 0.09 Mbps), 95~108 pkt/s, c1 수신 2.3~2.7 KB/s | M4b fight4 fight/4 7.1~8.7 KB/s |
| `brew4` 아무도 안 움직임 (0/4) | 146~309 B/s (505~696) | M4b fight4 0/4 262~293 |
| 병 하나 | 사건 둘 46B(+ 메시지 머리 2B), 화살 사건 메시지와 같이 reliable | 화살 38B |
| 한 프로세스 넷(3틱 지연, 버프 둘·독 병 여덟, 448틱)의 호스트 → 클라이언트 셋 | 상태 49,513B(79%), 적 묶음 7,113 + 키프레임 1,611B(14%), 병·화살 사건 978B(2%), 나머지 5%, 합 62,381B | M4b 넷 싸움(344틱) 28,898B: 버프된 둘의 상태가 20Hz로 계속 |

M6a (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 4.8초, 종료 0, 오류 줄 0. 새 그림 2장(`.import`)과 새 스크립트 7개(`.uid`: crafting·potions·effect_marks·crafting_panel·시험 둘)를 커밋. 처음 `.import`가 없을 때 한 번은 새 그림을 미리 부르는 `FixtureView`가 그림보다 먼저 읽혀 오류 줄이 났다(M4a와 같음, 커밋된 `.import`가 있으면 0) |
| 전체 테스트, 두 번 (마지막 코드, `.godot/`을 지우고 다시 임포트한 뒤) | 두 번 모두 19파일 통과 24,516 checks, 215.6 / 207.2초, 종료 0, 오류 묶음 8개(알린 것 그대로). 새 파일 crafting 448 (0.3초) · potions 154 (0.6초), items 1,612(새 물약·조제대 항목과 물약 아이콘 픽셀 비교), actors 1,681 → 1,683(그림 출처 77 → 79개), core 284(새 스크립트 여섯도 모두 불러 봄). 나머지는 M4-fix와 같은 수 |
| 세션·싸움 시험을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 81.0초, `net_fight` 270 checks 61.5초 통과, 자식 로그 687 + 211줄에 `ERROR:` 0 (세션 흐름은 M6a에서 바뀌지 않았다: 조제대 거부 한 줄뿐) |
| 내보내기 | x86_64 3.6초 `evensong.exe` 109,953,904 B, ARM64 3.6초 92,347,760 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 400프레임 | 304 checks ok(`items=30 ... combat=30/3 spawn_tiles=678 potions=6/1 ... net=v5`, 지상·던전 해시 그대로), 1.1초 / 약초사가 빛 안에서 빛 밖 이단에게 상급 독을 던지고(터짐 `heretics=1`) 버프를 마시고 조제대를 놓아 Tab으로 열고 회복 물약을 만드는 400프레임 3.5초, 둘 다 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 3.4초, 14부분 모두 ok (`crafting` 픽셀 3,818 · 어두운 줄 밝은 픽셀 943 모두 어두움 · 불일치 0, `potions` 화면 불일치 0 · 그린 픽셀 1,306 · 표시 126 불일치 0) |
| 스크린샷 4장 | `shots/m6_*.png` (위 "스크린샷"), 모든 실행 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r4m6/mutate.sh`, `mutate_render.sh`: 작업 트리의 파일 하나를 sed로 바꾸고 해당 시험을 돌리고 되돌림) | 헤드리스 25개 모두 FAIL·종료 1, 창 그림 검사 4개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M6a): 상급 물약을 누구나(`crafting` 13), 만들기의 자리 검사 없앰(assert), 입력을 앞 칸부터(1), 모든 레시피 해금(7), 작업대 손 닿음 한 칸 더(1), 조제대가 몸 위에도(7), 조제대끼리 붙음(4), 조제대가 막지 않음(13), 세션이 조제대를 받음(2), 가득 찬 HP에도 마심(`potions` 6), 최대를 넘는 회복(2), 독 첫 피해가 바로(7), 독이 플레이어를 경직(1), 다운에도 효과가 남음(3), 버프가 속도를 안 올림(2), 독 죽음을 처치로 안 셈(2), 독 터짐이 플레이어에게(1), 벽이 병을 안 막음(3), 던지는 거리 안 자름(4), 벽 너머로 터짐(2), 누구나 던짐(2), 효과 프레임에서 가득 찬 HP를 다시 안 봄(1. 처음엔 시험이 없어 이 검사를 밟지 않았다: 99 HP에서 마시기 시작해 그 사이 가득 차는 경우를 `main.tscn` 시험에 더함), 이단의 독이 경직(2), 혼자 할 때 물약이 두 번 듦(3), 물약 아이콘이 한 칸 밀림(`items` 6). 창 그림: 위 "그림 검사"의 넷(화살표 색 72, 터짐 1px 135, 표시 1px 23·35, 조제대 1px 484). 처음 넷째가 통과했다: 기대 그림을 `FixtureView.table_origin`으로 만들어 같은 함수를 비교했다(M4a에서 한 실수). 그림에서 마지막 불투명 줄을 재서 따로 계산하게 고쳤다

M4-fix (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.9초, 종료 0, 오류 줄 0. 새 스크립트·그림 없음(새 `.import`·`.uid` 없음) |
| 전체 테스트, 네 번 (마지막 두 번은 마지막 코드에서 `.godot/`을 지우고 다시 임포트한 뒤) | 네 번 모두 17파일 통과 23,836 checks, 209.1 / 204.8 / 208.4 / 210.8초, 종료 0, 오류 묶음 8개(알린 것 그대로). combat 537 → 555, heretic 14,883 → 14,906, net 632 → 635, net_combat 94 → 127, net_fight 216 → 269(`fightlag` 더함, 64~70초: 파일 하나 제한 120초 안). M4b 그대로의 코드로 돌린 기준 실행에서 `test_actions`의 "marker on the target tile"이 한 번 실패했다(그 뒤 따로 세 번, 전체 네 번 통과: 재현 안 됨, 알려진 문제) |
| 세션·싸움 시험을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 80.5초, `net_fight` 270 checks 67.4초 통과, 자식 로그 687 + 224줄에 `ERROR:` 0 |
| 내보내기 | x86_64 3.5초 `evensong.exe` 109,905,824 B, ARM64 3.2초 92,299,680 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 291 checks ok, 출력 M4b와 같음(`combat=30/3 spawn_tiles=678 ... combat_wire=25B net=v5`), 1.0초 / 혼자 던전의 아처가 이단에게 활을 쏘는 120프레임 1.5초, 둘 다 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 12부분 모두 ok (`combat_net` 클라이언트 = 호스트 불일치 0), 3.1초 |
| 그림 다시 | `m4_dungeon_arrow`, `m4_shrine_broken`, 두 창 `m4b_host`·`m4b_client` (위 "스크린샷", 두 창 로그 오류 줄 0). `m4_surface_heretic`은 다시 찍어도 바이트까지 같아 그대로 |
| 아레나 한 틱 (시드 1 지상, 9인, `test_combat` note) | 화살 0 / 9 / 27개: 2 / 82 / 240µs (검토 탐침의 M4b: 2µs / 2.6~2.8ms / 7.9~8.7ms). 이단의 제단 자리 한 번 2.7µs(기억, M4b는 지상 139µs·던전 42µs 맵 전체 훑기) |
| 실제 세션 `fightlag` | c1(왕복 120ms, 손실 5%, 링크가 버린 패킷 18~19/430~460)이 서 있다 다섯 번 맞음: 호스트 진행 0, vitals 보정 0. 옛 규칙으로 되돌리면 호스트 진행 40, vitals 보정 11 |
| 일부러 깨 보기 (스크래치 `r4m4/fix/mutate.py`, 게임 폴더에서 하나씩 바꾸고 해당 시험을 돌리고 되돌림) | 14개 모두 FAIL (아래) |

일부러 깨 보기 (M4-fix): 소생을 첫 사람 기준으로(`test_combat` 2, `test_net_combat` 2: 300틱), 빛 가장자리 기다림을 상태 틱으로(맞을 때마다 처음부터: 끝까지 안 감), 빈 지도 비우기 끔(`test_heretic` 9, `test_net_combat` 2: 돌아온 지 18틱에 맞음), 화살을 걸음 점의 칸만 검사(모서리 벽 넘어간 43발), 조준을 발에서(360발 중 빗나감), 맞음을 몸 점 8px로(빗나감), `MAX_DROPS`에서 빈 가방, 부활을 그 틱에만(8: 지난 사망 상태·혼자 할 때 부활 흐름), 오가기에서 대시 그대로, 시계 빚의 바닥 없앰(맞은 뒤 5틱에 걷기, 대시 11틱 간격, 미룬 프레임 0), 프레임 하나로 빚 0(가끔 보내는 다운이 2,100틱), 이단의 제단 자리 기억을 다시 보지 않음(`test_heretic` 6), `--test-shrine-hp` 상한 없앰, M4b의 조용한 클라이언트 규칙 그대로(`test_net_combat` 8: 서 있다 맞으면 3틱 지연 호스트 진행 9·보정 2, 9틱 21·6, 가끔 보내기, 몰아 보내기. 실제 세션 `fightlag`도 FAIL). 시계 빚을 쉬는 동안 세게만 바꾼 것은 끝의 "쉬면 0"이 같은 일을 해서 같은 동작이었다(잡히지 않음: 바꾼 것이 동작을 바꾸지 않음. 위의 "M4b 규칙 그대로"로 대신 확인)

M4b (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.9초, 종료 0, 오류 줄 0. 새 스크립트 셋의 `.uid`(`net/net_combat.gd`, `tests/test_net_combat.gd`, `tests/test_net_fight.gd`)를 커밋. 새 그림 없음 |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 17파일 통과 23,706 checks 188.2~188.3초 종료 0 (actions 1,055 / actors 1,681 / aim 1,094 / combat 537 / core 278 / dungeon 90 / heretic 14,883 / items 1,542 / light 73 / mining 88 / net 632 / net_combat 94 / net_fight 216 / net_maps 135 / net_session 560 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M4a보다 약 62초 늘었다(net_fight 51초, net_combat 9초). 그 전 코드(로그 한 줄 차이)로도 두 번 188.8 / 187.9초 통과 |
| 세션 시험 `--net-full` | 통과 826 checks 91.3초 (9인 상한 세션 포함, 마지막 코드) |
| 세션·싸움 시험을 내보낸 exe 자식으로 (`--net-exe`) | `net_session` 561 checks 79.5초, `net_fight` 217 checks 44.2초 통과, 자식 로그 684 + 202줄에 `ERROR:` 0 |
| 내보내기 | x86_64 3.6초 `evensong.exe` 109,900,880 B, ARM64 3.3초 92,294,736 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 291 checks ok (`combat=30/3 spawn_tiles=678 ... combat_wire=25B net=v5`), 1.0초 / 혼자 던전의 아처가 이단과 싸우는 120프레임 1.4초, 둘 다 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 12부분 모두 ok, `combat_net` 클라이언트 = 호스트 불일치 0 (이단 다섯·화살 둘·다운 하나, 그린 픽셀 2,633) |
| 두 창 그림 | `shots/m4b_host.png`, `shots/m4b_client.png` (위 "스크린샷"), 두 로그 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r4m4/m4b/mutate_m4b.py`, `mutate_render_m4b.py`) | 헤드리스 22개 모두 FAIL·종료 1, 창 그림 3개 모두 FAIL·종료 1 (아래) |

예고 대 지연 (`test_net_combat.gd`, 한 프로세스, 한 방향 지연 고정, 결정적): 예고 30틱 = 500ms, 판정은 호스트 시간.

| 한 방향 지연 | 클라이언트가 예고를 그리는 때 (공격 시작 뒤) | 그 뒤 대시로 피할 수 있는 마지막 | 예고를 100ms 뒤에 그렸다면 |
|---|---|---|---|
| 0 | 0ms | 500ms (30틱) | 400ms |
| 50ms (3틱) | 50ms | 400ms (24틱) | 300ms |
| 100ms (6틱) | 100ms | 300ms (18틱) | 200ms |
| 150ms (9틱) | 150ms | 200ms (12틱) | 100ms |

시험은 지연마다 "예고를 본 다음 틱"과 그 마지막 틱에 누른 대시는 피하고(HP 그대로) 한 틱 늦으면 맞는 것을 본다. 공격 쪽: 3틱 지연에서 클라이언트가 그리는 쫓는 이단은 호스트 위치에서 최대 6.9px(화살 맞음 반경 8px).

트래픽 (M4b, localhost, ENet 바이트, 괄호는 UDP/IP 포함, 호스트 송신. 전체 실행 넷 + `--net-full`, 범위):

| 상황 | 호스트 송신 | 비교 |
|---|---|---|
| fight4 아무도 안 움직이고 이단 둘이 집에 서 있음 (0/4) | 262~293 B/s (615~662 B/s), 13 pkt/s | M3b four 0/4 276~354: 서 있는 이단은 적 메시지를 내지 않는다(키프레임 뒤 조용) |
| fight 끝, 셋이 서 있음 (0/3) | 118~129 B/s (383~425 B/s) | |
| fight 둘이 싸움 (fight/2) | 1.90 KB/s (2.73~2.75 KB/s), 30 pkt/s. c1 수신 1.89 KB/s | M3b pair 2/2 걸음 1.07 KB/s: 맞은 플레이어의 vitals 블록(16B), 적 묶음, 화살 사건 |
| fight 셋이 싸움 (fight/3) | 3.11~3.19 KB/s (4.27~4.38 KB/s), 42 pkt/s. c1 수신 약 1.55~1.60 KB/s | |
| fight4 넷이 싸움 (fight/4) | 7.1~8.7 KB/s (9.7~11.6 KB/s ≈ 0.09 Mbps), 93~104 pkt/s. c1 수신 약 2.4~2.9 KB/s | M3b four 4/4 걸음 5.3 KB/s |
| fight 다운된 c1 옆에 호스트가 서 있음 (0/2) | 1.73~1.74 KB/s | 다운된 플레이어의 삶의 틱이 매 틱 바뀌어 상태 묶음이 20Hz로 나간다(알려진 문제) |
| 9인 걸음 (`--net-full`, 9/9) | 27.8~28.1 KB/s (33.0~33.6 KB/s) | M3b 28.2: 쉬는 vitals는 보내지 않아 그대로 |

한 프로세스 넷 싸움(3틱 지연, 호스트 → 클라이언트 셋, 346틱)의 바이트 나눔: 상태 묶음 20,963 B(73%), 적 묶음 3,039 + 키프레임 1,065 B(14%), 화살 사건 1,134 B(4%), 나머지(참가·인벤토리) 9%. 실제 세션의 적 메시지(한 번): fight 묶음 127~129 · 키프레임 36 · 공격 시작 바로 보냄 3~5, fight4 87~177 · 24~30 · 0~2, 화살 메시지 26 / 30~36. fight4는 실행마다 길이가 조금 달라(싸움 5.7~7.5초) 바이트도 그만큼 다르다.

일부러 깨 보기 (M4b, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 시험을 돌리고 되돌림): 다운 중 요청을 받음, 동작 중(busy) 사용을 받음, 먼 곳에서 소생, 상태에 vitals를 안 실음, 예측이 호스트 vitals를 버림, 타이머가 도는 동안 프레임을 기록하지 않음, 예측이 부활하지 않음, 적 묶음을 모두에게, 예고를 100ms 뒤에 그림, 공격 시작에 바로 보내지 않음, welcome 뒤 적 키프레임 없음, 화살 멈춤 사건 없음, 조용한 클라이언트를 호스트가 진행하지 않음, 세션에 사망 가방 없음, F 누르고 있기가 전송 형식에 없음, USE 조준이 전송 형식에 없음, 세션에 시작 무기 없음, 먼 칸의 사용을 받음, 클라이언트가 사라진 이단을 계속 그림, 적 HP가 전송 형식에 없음, vitals 범위 검사 하나 빠짐, 실제 세션에서 맞음을 다른 자리로 기록 (`net`·`net_combat`·`net_fight`). 22개 모두 FAIL·종료 1. 처음 돌렸을 때 "사라진 이단을 계속 그림"이 통과해서(마지막 적 묶음 해시만 봤다) 클라이언트 그림에서 시체가 사라지는지 보는 검사를 더했다. 창 그림 검사(`combat_net`): 클라이언트가 이단의 깜빡임을 버림(불일치 725), 남의 vitals를 그리지 않음(544), 화살 방향 1/16바퀴(53) 셋 다 FAIL. 처음에는 "남의 vitals"가 통과했다(검사가 호스트 쪽 플레이어도 `show_state`로 그려 둘 다 같이 깨졌다): 호스트 쪽을 자기 상태로 그리게 고쳤다.

M4a (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.3초, 종료 0, 오류 줄 0. 새 그림 9장(`.import`)과 새 스크립트 8개(`.uid`)를 커밋. 처음 `.import`가 없을 때 한 번은 새 그림을 미리 부르는 스크립트가 그림보다 먼저 읽혀 오류 줄이 났다(커밋된 `.import`가 있으면 0) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 15파일 통과 23,197 checks 126.5~126.6초 종료 0 (actions 1,055 / actors 1,681 / aim 1,094 / combat 537 / core 275 / dungeon 90 / heretic 14,883 / items 1,542 / light 73 / mining 88 / net 436 / net_maps 135 / net_session 560 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M3-fix보다 약 7.5초 늘었다(새 파일 둘 약 5초, 나머지는 기존 파일의 흔들림). heretic의 checks가 많은 것은 공격 시험이 틱마다 하나씩 보기 때문 |
| 스모크 (에디터 / 내보낸 exe) | 287 checks ok (`items=26 actions=8 combat=30/3 spawn_tiles=678 ... net=v4`), 내보낸 exe 1.0초 종료 0 |
| 내보내기 | x86_64 3.6초 `evensong.exe` 109,855,400 B, ARM64 3.2초 92,249,256 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe 120프레임 (`--class=archer --start-map=dungeon --give=torch:5 --test-heretic=46,17 --bot=...`) | 1.5초 종료 0, 오류 줄 0 (활 동작 둘) |
| 창 그림 검사 `check_render.gd` | 3.3초, 11부분 모두 ok (`rig` 78화면 불일치 0, `heretic` 이단 32 × 5화면 불일치 0 · 막대 0, `bars` 막대 396픽셀 · 숫자 81픽셀 불일치 0) |
| 세션 시험 | `net_session` 560 checks 84초 통과(세션 흐름·전송 형식은 바꾸지 않았다). 내보낸 exe 자식(`--net-exe`)·`--net-full`은 이번에 돌리지 않았다 |
| 스크린샷 5장 | `shots/m4_*.png` (위 "스크린샷"), 모든 실행 오류 줄 0 |
| 일부러 깨 보기 | 23개 모두 FAIL·종료 1 (헤드리스 시험), 창 그림 검사 3개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M4a, 스크래치 `r4m4/mutate.py`: 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 시험을 돌리고 되돌림): 대시가 벽을 무시함, 대시 쿨다운 없음, 성직자 소생이 즉시가 아님, 다운이 10초 더 김, 다운 중 움직임, 근접이 벽 너머로 닿음, 화살이 벽을 지남, 화살의 아군 사격, 가방 절반을 내림, 가방이 도구도 가져감, 가방 칸의 F가 드롭 하나만 주움, 예측이 대시를 버림(공유 시뮬레이션), 피격 자세 없음 (`combat`); 이단이 빛에 걸어 들어감, 빛 안의 사람을 칼로 침, 스폰 검사에서 빛 빠짐, 맞는 열이 한 칸 밀림, 예고가 10틱 짧음, 끈 없음, 부서진 제단이 스폰을 안 멈춤, 서쪽 반전 없음, 곡괭이가 캐면서 공격도 함, 다른 지도도 흐름 (`heretic`). 처음 돌렸을 때 23개 중 4개가 통과해 버렸다(시험의 빈틈): 이단이 빛에 걸어 들어가기(표적이 빛 안이면 쫓지 않아 이동의 빛 검사를 아무 시험도 밟지 않았다), 빛 안의 사람을 칼로 치기(예고 중에 빛으로 들어가는 경우가 없었다), 스폰 검사에서 빛 빼기(후보 칸 목록이 이미 빛 밖이라), 곡괭이가 캐면서 공격도 하기(옆의 이단이 호 밖에 있었다). 시험 넷을 더했고(빛 테두리를 가로지르는 추격, 공격 중 빛으로 들어감, `spawn_ok`가 빛 안 158곳을 거부, 호 안의 이단), 그중 하나가 실제 버그를 찾았다: 시야 선(`Combat.cells_on_line`)이 칸 모서리에서 정확히 끝나는 선을 끝 칸 위의 칸으로 걸어 막혔다고 보았다(곡괭이 시험의 이단이 벽 앞면 칸 너머로 잘못 가려짐). 고치고 시험 한 줄을 더했다. 지금은 23개 모두 FAIL·종료 1. 창 그림 검사도 둘: 이단 서쪽 반전 없음 → `heretic` FAIL(불일치 14,072픽셀), 64칸 발 원점 1px 밀림 → `heretic` FAIL(8,618. 처음엔 통과했다: 기대 그림을 `Heretic.cell_offset`으로 만들어 같은 함수를 비교하고 있었다. 기대 그림을 13차 값(줄 번호, 발 (16, 32)·(32, 48))으로 따로 적게 고침), HUD HP 막대 채움 1칸 모자람 → `bars` FAIL(6픽셀)

M3-fix (2026-10-22, M3 검토 반영):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 4.3초, 종료 0, 오류 줄 0. 새 스크립트·그림이 없어 `.import`·`.uid` 변화 없음 |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 13파일 통과 7,644 checks 118.8~119.1초 종료 0 (actions 1,055 / actors 1,588 / aim 1,094 / core 267 / dungeon 90 / items 1,510 / light 73 / mining 88 / net 436 / net_maps 135 / net_session 560 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M3b보다 약 2초 늘었다(던전 시험에 호스트 잃은 뒤 혼자 하기) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 561 checks 79.0초 (자식 20개 모두 내보낸 exe, 로그 684줄에 `ERROR:` 0) |
| 내보내기 | x86_64 3.6초 `evensong.exe` 109,761,072 B, ARM64 3.4초 92,154,928 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--class=miner --give=pickaxe,torch:5 --start-map=dungeon`) | 250 checks ok (`dungeon=64x48 hash=8dda0ad69ad9 ores=47 dungeon_seeds=acc0a9bc2359 dungeon_map=319B ... net=v4`), 1.0초 / 1.3초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.9초, 9부분 모두 ok (`cave` 불일치 0, `dark` 반경 밖 밝은 픽셀 0, `cave_net` 클라이언트 = 합성 0 · 호스트 = 클라이언트 0) |
| 두 창 그림 | `shots/m3b_host.png`, `shots/m3b_client.png` 다시 찍음(클라이언트 `aim:-20,24`): 랜턴 둘, 두 로그 오류 줄 0. M3a 그림 3장은 같은 명령으로 다시 찍어 비교만 했다: 다른 픽셀 1,087 / 206 / 203개가 모두 더미 idle·불꽃 프레임 자리(찍는 순간 차이)라 커밋된 그림을 그대로 둠(시드 1 던전에서 바뀐 벽 횃불 둘 (18,27)·(22,36)은 세 화면 밖) |
| 벽 횃불 (탐침, 스크래치 `r4m3/fix/probe_torch.gd`) | 도착 방의 벽 횃불 0 · 1 · 2개: M3a 시드 1~400에서 82 · 108 · 210 → 시드 1~3,000에서 0 · 135 · 2,865. 벽 횃불 없는 방 20,987개 중 373개, 모두 북쪽 벽에 맞는 칸이 없는 방. 40시드 시험: 도착 방 둘 39개 |
| 시드 1 던전 (M3a와 비교, 스크래치 `probe_diff.gd`) | 방·통로·출구 (37,14)·광석 47칸 같음, 다른 칸은 설치물 2칸(새 벽 횃불 (18,27)·(22,36))뿐, 벽 횃불 8 → 10. 시드 2·3도 설치물 2칸·1칸만 다름 |
| 일부러 깨 보기 (스크래치 `r4m3/fix/mutfix.py`, 13개) | 13개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M3-fix, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 13개 모두 FAIL·종료 1): 광부 3×3이 깰 수 없는 칸 둘레에 닿음(`mining`, 호스트 `net_maps` 각각), 디버그 드롭이 벽·앞면에 됨, 디버그 묶음이 다시 24칸, 세션이 만든 Player의 시그널을 잇지 않음, 받지 못한 지도로 travel, 횃불 USE가 요청 예산을 안 씀, 지도 들어옴이 그 지도의 플레이어를 보이지 않음, 벽 횃불 자리를 옮기지 않고 건너뜀(M3a 규칙), 방마다 하나 보장 없음, 6칸마다의 것을 옮기지 않음(황금 해시로만 잡힘), 출구가 횃불 자리를 보지 않음, 맨 윗줄 바닥을 앞면으로 그림(M3a 규칙)

M3b (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.6초, 종료 0, 오류 줄 0 (새 시험 스크립트 `test_net_maps.gd`의 `.uid`, 커밋) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 13파일 통과 7,624 checks 116.9~117.1초 종료 0 (actions 1,055 / actors 1,588 / aim 1,094 / core 267 / dungeon 80 / items 1,510 / light 73 / mining 82 / net 436 / net_maps 131 / net_session 560 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M3a보다 약 33초 늘었다: 세션 시험 약 52 → 82.5초(`cave` 약 25초, `four`의 던전 경주 약 6초), 새 파일 `net_maps` 2.0초. 파일당 제한 120초 안이다. 이 세션의 그 전 전체 실행 하나에서 `test_aim.gd`의 표시 검사가 한 번 실패했다(부하에서 물리 틱 둘이 한 프레임에 돌아 `_process`의 표시가 아직 안 따라옴, 혼자 세 번 통과). 그 검사 앞에 프레임 둘을 기다리게 고쳤다 |
| 세션 시험 `--net-full` | 통과 826 checks 88.0초 (9인 상한 세션 포함) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 561 checks 79.0초 (자식 모두 내보낸 exe, pair·four·cave 호스트에 `--test-allow-give`) |
| 내보내기 | x86_64 3.4초 `evensong.exe` 109,758,464 B, ARM64 3.0초 92,152,320 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--class=miner --give=pickaxe,torch:5 --start-map=dungeon`) | 250 checks ok (`dungeon_seeds=3ec443b95c4c dungeon_map=313B ... net=v4`), 1.0초 / 1.3초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 3.0초, 9부분 모두 ok. `cave_net` 편집 32개(클라이언트 스냅샷 344B 뒤 23개), 금 1·2·3단계, 깬 칸 6, 오버레이 22, 클라이언트 = 합성 불일치 0, 호스트 = 클라이언트 불일치 0 |
| 두 창 그림 | `shots/m3b_host.png`, `shots/m3b_client.png` 480×270 (창 960×540), 두 로그 오류 줄 0 |
| 지도 스냅샷 | 시드 1 던전: 원본 18,456B(드롭 하나면 18,467B) → 압축 309~345B, 조각 1개, 만들기 65~87µs. 클라이언트가 받아 그리기 62~70ms(동굴 그림). 지상으로 돌아올 때 566B |
| 단위 시험 (`test_net_maps.gd`) | 예측과 호스트가 이미 깬 벽: 편집이 0·30·90틱 늦을 때 보정 0·2·3번(마지막 29·41틱), 최대 오차 2.6px, 편집 뒤 0번. 같은 틱 채굴 세 경우 모두 한 번만 깨짐 |
| 세션 `four` 던전 경주 (4번) | 바위는 늘 정확히 한 번 깨짐, 깬 쪽(자리 1 한 번, 자리 2 세 번)에 돌. 두 클라이언트가 같은 틱에 맞은 일은 없었다(c3가 4~15틱 먼저 또는 늦게). 던전은 32바이트 조각 10개·2틱 |
| 일부러 깨 보기 (스크래치 `r4m3/mut/mut3b.py`, 23개 + 창 1개) | 23개 모두 FAIL·종료 1, 창 그림 검사로 1개 FAIL (아래) |

트래픽 (M3b, localhost, ENet 바이트, 괄호는 UDP/IP 포함. 전체 실행 둘 + `--net-exe` + `--net-full`, 호스트 송신, "c1 수신"은 그 묶음 동안 c1이 받은 것):

| 상황 | 호스트 송신 | 비고 |
|---|---|---|
| pair 둘 다 걸음 (2/2) | 1,068~1,078 B/s (1.72~1.74 KB/s), 23 pkt/s | M2b 1,031~1,038: 상태가 16 → 17B(지도) |
| pair 아무도 안 움직임 (0/2) | 166~207 B/s | M2b 167~182 |
| pair 한 사람 동작 중 (act1/2) | 1,072~1,091 B/s | M2b 1,015~1,055 |
| cave 둘 다 서 있고 지도가 다름 (0/2 split, 약 3.6초) | 88~106 B/s (213~247 B/s), 4.5~5 pkt/s. c1 수신 140~146 B/s | 조용하다: 상태 묶음 없음, ENet 유지 패킷 정도. 같은 지도의 pair 0/2보다 낮다(이 묶음엔 편집·연결 인사가 없다) |
| cave 호스트가 던전에서 캠, c1은 지상 (act1/2 split) | 1,070~1,087 B/s. c1 수신 1,070~1,083 B/s | c1은 상태 묶음만 받는다(던전 편집 0개). 같은 지도에서 둘이 걸을 때(2/2)와 같은 크기 |
| cave 둘 다 던전에서 캠 (act2/2) | 1,344~1,387 B/s (2.33~2.40 KB/s), 35~36 pkt/s. c1 수신 1,343~1,362 B/s | 상태 + 서로의 채굴 편집. 지상에 있을 때보다 c1 수신이 약 270~290 B/s 많다 |
| cave 지도를 보내는 틱 (entering, 9틱) | 12.3 KB/s × 0.15초 ≈ 1.8KB | 지도 들어옴 세 번(c1 내려감 345B, 올라옴 566B, c2 내려감 311B) + 그 틱의 상태 |
| four 둘이 던전에서 같은 바위를 침, 나머지 둘은 지상 (act2/4 split) | 5.51~5.56 KB/s (7.70~7.77 KB/s), 78~80 pkt/s | M2b의 four 4/4(걸음) 5.0 KB/s와 비슷하다 |
| four 아무도 안 움직임 (0/4) | 276~354 B/s | M2b 428~580 |
| 9인 걸음 (`--net-full`, 9/9) | 28.2 KB/s (33.8 KB/s ≈ 0.27 Mbps), 200 pkt/s | M2b 26.4: 9명 × 1B × 20Hz × 8 클라이언트 ≈ 1.4 KB/s 더 |

일부러 깨 보기 (M3b, 스크래치 `r4m3/mut/mut3b.py`, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 23개 모두 FAIL·종료 1, 처음 돌린 대로): 호스트가 요청의 지도를 안 봄, TRAVEL 손 닿는 칸 검사 빼기, 받는 중 TRAVEL 허용, TRAVEL 요청 예산 빼기, 아무 칸이나 던전으로 가는 길, 편집을 모든 클라이언트에게(지도 무시), 지도를 받는 중인 클라이언트에게도 편집, 지도 들어옴 뒤 따라잡기 편집 안 보냄, 모든 편집을 지상 기록에, 채굴을 지상 데이터로, 옮긴 멤버가 옛 지도 데이터로 걸음, 클라이언트가 모든 지도의 플레이어를 그림, 클라이언트가 다른 지도의 편집을 적용, 보간이 두 지도를 섞음, 다른 지도의 스냅샷을 받아 줌, 상태에서 지도 빼기(net·net_maps), 예측이 다른 지도의 상태를 맞춤, 다시 돌릴 때 옛 지도를 겨눈 사용을 시작함, 지도 조각이 끝나기 전에 지도 들어옴, 지도 전환 뒤 예측이 옛 데이터로 충돌 — 여기까지 `test_net_maps.gd` — 그리고 실제 세션 `cave`로: 클라이언트 F가 입구에서 TRAVEL이 아니라 PICKUP(둘이 던전에서 캐지 못함), Main이 새 지도를 보이지 않음(그려짐 검사), 프레임이 지도를 늘 지상으로(c1의 던전 사용이 `wrong map`이라 동작 보정 1). 창 그림 검사로: 받은 지도의 금 오버레이를 안 그림(`CaveView.setup`이 광맥 칸만 오버레이) → `cave_net` FAIL(클라이언트 = 합성 불일치 179, 호스트 = 클라이언트 179. `cave`는 그 그림을 편집으로 그려서 통과)

M3a (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.8~3.9초, 종료 0, 오류 줄 0 (새 스크립트 8개의 `.uid`, 새 PNG 18장의 `.import` 생김, 커밋) |
| 타일셋 다시 만들기 | 두 번 만들어 둘 다 같은 md5. 지상 `surface.tres`는 그대로(`ae29305880186ae9c5e6de5f5a813c8e`), 던전 `dungeon.tres` = `4278922a8774b0305fca5f0a28b19fe3` (소스 2, 타일 30, 코너 키 21) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 12파일 통과 7,293 checks 83.1~83.5초 종료 0 (actions 1,055 / actors 1,588 / aim 1,094 / core 266 / dungeon 76 / items 1,510 / light 73 / mining 81 / net 425 / net_session 377 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. M2-fix보다 약 9초 늘었다: 새 파일 둘(6.0 + 2.9초) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 378 checks 49.5초 |
| 던전 생성 / 동굴 그림 (헤드리스, 예열 뒤) | 시드 1 64×48: 생성 24.2~24.3ms, `CaveView.setup` 55~73ms(그림 칸 3,185개 + 광맥 오버레이 47개) |
| 던전 규칙 40시드 | 모든 규칙 통과, fallback 그림 칸 모두 19개. 시드 1: 방 7, 광석 칸 47, 벽 횃불 8, 열린 칸 511 |
| 창 그림 검사 `check_render.gd` | 3.3초, 8부분 모두 ok. `cave` 불일치 0(금 1·2·3단계, 앞면 있는 벽 3, 깬 칸 1, 오버레이 18), `dark` 반경 밖 77,100픽셀 중 밝은 것 0, 첫 단계 안 3,064픽셀 중 어두운 것 0 |
| 내보내기 | x86_64 3.3초 `evensong.exe` 109,740,048 B, ARM64 3.3초 92,133,904 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give=pickaxe,torch:5 --start-map=dungeon`) | 243 checks ok (`dungeon=64x48 hash=009e7147ad79 ores=47 items=25`), 0.75초 / 1.3초 종료 0 오류 줄 0 |
| 지상 월드 | 해시 `1d9f92c7b5ef2a715f95cc32d7424b36`(입구 칸 2개), 스냅샷 원본 73,762B → 압축 576B 근처, 여전히 조각 1개. `stall`의 c2는 1바이트 조각 570개·72틱 |
| 스크린샷 3장 | 위 "스크린샷"의 M3a 명령, 모두 480×270 (창 960×540), 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r4m3/mut/mutate.py`, 25개 + 창 2개) | 25개 모두 FAIL·종료 1 (처음 돌렸을 때 놓친 셋은 아래), 창 그림 검사로 2개 FAIL |

일부러 깨 보기 (M3a, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 `--only=dungeon,mining` 중 해당 파일을 돌리고 되돌림. 25개 모두 FAIL·종료 1, 황금 해시만 틀린 것이 아니라 규칙 검사로): 앞면 칸이 안 막힘, 벽이 안 막힘(걷기), 광부가 1×1, 3×3을 가운데로, 광부 타격이 공용과 같음, 공용 경도 상한 = 광부, 금 단계를 내림으로, 가득 찬 인벤토리면 사라짐(드롭 없음), 벽 횃불이 벽과 같이 안 없어짐, 기반암이 깨짐, 방을 통로로 안 이음, 광맥이 아무 바위에나(바닥 옆 아님), 다시 그리는 범위 세로 3줄, context 무시, 맞는 틱 1틱 늦게, 횃불을 앞면 칸에, 호스트가 횃불 USE 무시, 호스트가 채굴 안 함, F로 안 오감, 벽 편집을 안 다시 그림, 지상 입구 없음, 세션 호스트가 입구 F를 받아 줌, 횃불 빛 텍스처가 반경 너머까지, 앞면을 치면 위 벽에 안 닿음, 계단 위 바위의 보호 빼기(`Walls.hardness`). 처음 돌렸을 때 놓친 셋: 계단 위 바위 보호 빼기(생성기가 그 바위를 기반암으로도 만들어서 행동이 같았다 → 손으로 만든 계단에 바로 시험을 더함), 다시 그리는 범위(무작위 편집 120번에는 context 타일이 바뀌는 경우가 없었다 → 작은 동굴에 촘촘한 편집 800번, 25번마다 새 그림과 비교), 맞는 틱 1틱 늦게(호스트 시험이 `impact_tick()` 자체를 기준으로 셌다 → 동작 시작부터 프레임마다 세어 18틱째인지). 창 그림 검사로: 앞면 금을 1px 아래로 → `cave` FAIL(불일치 129픽셀, 처음엔 합성이 스프라이트 자리를 그대로 써서 놓쳤다 → 합성을 데이터와 따로 적은 자리로), 횃불 빛 `texture_scale` 2 → `dark` FAIL(반경 밖 밝은 픽셀 28,148)

M2-fix (2026-10-22, M2b 검토 반영):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.2초, 종료 0, 오류 줄 0 (새 스크립트 없음, `.uid` 변화 없음) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 10파일 통과 7,053 checks 74.1~74.3초 종료 0 (actions 1,055 / actors 1,569 / aim 1,094 / core 257 / items 1,455 / light 73 / net 425 / net_session 377 / world 429 / world_items 319). 오류 묶음은 알린 8개뿐. `four`의 c4: 563B를 18조각, `stall`의 c2: 567조각 71틱 |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 378 checks 49.0초 |
| 내보내기 | x86_64 3.3초 `evensong.exe` 109,645,520 B, ARM64 3.2초 92,039,376 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give=pickaxe,stone_a:300`) | 227 checks ok, 0.57초 / 1.2초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.4초, 6부분 모두 ok |
| 스크린샷 다시 찍기 | 목표 칸 표시가 보이는 5장(`m2_hotbar`·`m2_aim`·`m2_use`·`m2b_host`·`m2b_client`)을 위 명령 그대로 다시 찍었다. `m2_aim`의 표시가 이제 아처 발 서쪽 같은 줄이다(전에는 남서). 두 창 호스트 로그 `action ... target=61,47`(전에는 61,48, 발은 47줄) |
| 일부러 깨 보기 (스크래치 `r3m2/fix/mut/mutate.sh`, 15개) | 15개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M2-fix, 게임 폴더를 스크래치에 복사해 하나씩 바꾸고 해당 테스트 파일을 돌림. 15개 모두 FAIL·종료 1): 서서 바라보기만 바뀐 프레임을 기록하지 않기(world_items + `pair` 세션 셋 다 c1이 서쪽), `on_inventory`에서 프레임에 실린 고르기 / 줄에 있는 고르기를 다시 얹지 않기(각각), `SessionHost.tick`이 자리를 거꾸로 처리, `MAX_DROPS` 검사 빼기, 목표 칸을 발 점의 칸으로(aim 72개·actions), 손 닿는 칸을 발 점의 칸으로, 사용의 바라보기를 look 그대로, 동작 중 표시를 마우스 칸으로, 고르기를 다시 예산에 넣기, 거부된 고르기에 인벤토리 안 보내기, `PlayerSim`의 대각선 바라보기를 큰 축으로(600틱 중 300틱만 M1과 같음), 클라이언트 주기를 나누지 않기, 클라이언트 버리기 허용, 줄의 고르기도 토큰 기다리기

M2b (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.2초, 종료 0, 오류 줄 0 (새 스크립트 4개의 `.uid` 생김, 커밋) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 10파일 통과 6,979 checks 72.8~73.1초 종료 0 (actions 1,053 / actors 1,569 / aim 1,059 / core 257 / items 1,455 / light 73 / net 425 / net_session 373 / world 429 / world_items 286). 오류 묶음은 알린 8개뿐. M2a보다 약 18초 늘었다: 거의 세션 시험(약 37 → 51~52초: pair의 걷기·줍기·늦은 참가자 걷기, four의 경주, stall의 드롭) |
| 세션 시험 `--net-full` | 통과 602 checks 56.0초 (9인 상한 세션 포함) |
| 세션 시험을 내보낸 exe 자식으로 (`--net-exe`) | 통과 374 checks 50.2초 (자식 17개 모두 내보낸 exe, pair 호스트에 `--test-allow-give`) |
| 내보내기 | x86_64 3.2초 `evensong.exe` 109,644,208 B, ARM64 2.8초 92,038,064 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give` 포함) | 227 checks ok (`gatherables=74 ... net=v3`), 0.67초 / 1.2초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.6초, 6부분 모두 ok. `items` 채집물 9 + 드롭 1, 불일치 0. `ground`는 판정 픽셀이 129,347 → 129,333(제단 화면 오른쪽 위 끝에 채집물 하나가 들어와 어두운 외곽선 픽셀이 빠짐), 불일치 0 |
| 두 창 그림 | `shots/m2b_host.png`, `shots/m2b_client.png` 480×270 (창 960×540), 오류 줄 0 |
| 일부러 깨 보기 (스크래치 `r3m2/m2b/mutate.py`, 22개 + 창 1개) | 22개 모두 FAIL·종료 1, 창 그림 검사로 1개 FAIL (아래) |
| 시드 1 월드 | 원본 73,749 → 73,751B(드롭 개수 2B), 압축 341~342 → 563~576B(채집물 74칸 + 실행 중 드롭), 여전히 조각 1개. 늦은 참가 준비 68~129ms |

트래픽 (M2b, localhost, ENet 바이트, 괄호는 UDP/IP 포함. 세 번 + `--net-full` 한 번):

| 상황 | 호스트 송신 | 비고 |
|---|---|---|
| pair 둘 다 걸음 (2/2) | 1,031~1,038 B/s (1.67~1.70 KB/s), 23 pkt/s | M1 950~970: 상태가 14 → 16B |
| pair 아무도 안 움직임 (0/2) | 167~182 B/s | M1 111 또는 193~225. 이 묶음에 바닥 편집과 늦은 참가자의 연결 인사가 들어 있다(H-fix에서 잰 것과 같은 원인) |
| pair 한 사람 동작 중 (act1/2) | 1,015~1,055 B/s (1.65~1.71 KB/s), 22~23 pkt/s | 동작 중에는 상태가 매 틱 바뀌어 걸을 때처럼 20Hz로 나간다. 그 클라이언트 송신 526~561 B/s(동작 동안 매 틱 프레임) |
| pair 둘 다 동작 (act2/2) | 1,001~1,075 B/s | |
| four 경주 + F 마구 누르기 (req/4) | 5.04~5.11 KB/s (7.05~7.17 KB/s), 72~73 pkt/s | 처리한 프레임의 확인이 묶음으로 나간다(셋 다 걸을 때 4/4의 5.0 KB/s와 같다) |
| four 아무도 안 움직임 (0/4) | 428~580 B/s | M1 458~550 |
| 9인 걸음 (`--net-full`, 9/9) | 26.4 KB/s (31.9 KB/s ≈ 0.26 Mbps), 197 pkt/s | M1 22.0~23.1 KB/s. 9명 × 2B × 20Hz × 8 클라이언트 ≈ 2.9 KB/s 더 |

일부러 깨 보기 (M2b, 스크래치 `r3m2/m2b/mutate.py`, 하나씩 바꾸고 해당 테스트 파일을 돌리고 되돌림. 22개 모두 FAIL·종료 1): 손 닿는 칸 검사 빼기, 줍기 편집을 바로 적용하지 않음(같은 틱 경주에서 둘 다 가짐), 약초사도 일반 등급, 요청 예산 빼기, 동작 중 사용 허용, 클라이언트가 동작을 예측하지 않음(호스트가 돌린 동작 수가 예측과 다름), 동작 중 프레임 기록 안 함(동작 보정 2), 상태에서 동작 빼기, 상태에서 든 아이템 빼기, 스냅샷에서 드롭 빼기, 월드 해시에서 드롭 빼기, 식생 편집 때 그림 안 고침, 보간이 새 상태의 동작 시작을 안 봄, 주기를 늘 허용, 제단 칸에 버리기 허용, 채집물을 빛 안에도, 프레임 코드에서 바라보기 빼기, 드롭이 다 안 들어가도 통째로 줍기, 그리고 실제 세션으로: 주인에게 인벤토리 안 보냄(pair c1이 검을 못 가짐), 상태의 든 아이템을 빈 손으로(pair), 줍기 칸을 한 칸 밀기(pair c2 스냅샷 편집 위치 2), 클라이언트가 드롭 편집을 적용 안 함(pair c2 월드 다름). 창 그림 검사로: 채집물 그림 1px 아래로 → `items` FAIL(불일치 1,054픽셀)·종료 1

M2a (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.0초, 종료 0, 오류 줄 0. 단 새 PNG를 처음 넣고 `.import` 파일이 아직 없을 때의 첫 임포트는 스크립트를 먼저 읽어 `Preload file ... has no resource loaders` 줄 8개가 나왔다(종료 0). 한 번 더 임포트하면 없어지고, `.import`를 커밋했으니 클론에서는 나오지 않는다 |
| 전체 테스트, 세 번 (마지막은 마지막 코드) | 세 번 모두 9파일 통과 6,550 checks 55.1~55.4초 종료 0 (actions 1,053 / actors 1,569 / aim 1,059 / core 253 / items 1,455 / light 73 / net 357 / net_session 302 / world 429). 오류 묶음은 알린 8개뿐. H-fix보다 약 8초 늘었다: 동작 기준점 다시 재기(0.5 → 2.1초), 창 크기 6가지 조준 시험(4.0초), 동작 시험(2.3초) |
| 동작 프레임 그림 (`test_actions.gd`) | 5클래스 × 4방향 × 55프레임 = 1,100개: 노드가 그리는 스프라이트를 CPU로 합친 그림 = 시트 + 문서 규칙으로 합친 그림, 42~47ms |
| 조준 (`test_aim.gd`) | `main.tscn`에서 창 6가지 × (가운데·북서 모서리) × 마우스 9곳(뷰포트 테두리 8 + 검은 띠) = 108곳. 가운데일 때 테두리 8곳이 8구역을 다 낸다 |
| 창 그림 검사 `check_render.gd` | 2.2초, 5부분 모두 ok. `rig` 65화면(그중 몸 동작 55) × 20명, 불일치 0 |
| 내보내기 | x86_64 2.9초 `evensong.exe` 109,599,712 B, ARM64 2.9초 91,993,568 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임(`--give` 포함) | 208 checks ok (`items=22 actions=8`, 기준점 표 모양이 10동작이라 늘었다), 0.46초 / 1.2초 종료 0 오류 줄 0 |
| 세션 테스트를 내보낸 exe 자식으로 (`--net-exe`) | 통과 303 checks 34.8초 (자식 모두 내보낸 exe) |
| 스크린샷 4장 | 위 "스크린샷"의 M2a 명령, 모두 480×270 (창 960×540) |
| 일부러 깨 보기 (스크래치 `mutate.py`, 21개) | 21개 모두 FAIL·종료 1 (아래) |

일부러 깨 보기 (M2a, 스크래치 `r3m2/mutate.py`, 하나씩 바꾸고 해당 테스트 파일을 돌리고 되돌림. 21개 모두 FAIL·종료 1): 곡괭이 시트 재생 첫 칸 1 → 0, 64칸 안의 32 프레임 자리 (16, 16) → (16, 15), 손에 든 표식 숨기기 끄기, 괭이 동작에서도 곡괭이 숨기기, 캐릭터가 동작 칸 자리를 빼먹음, 던지기 옮김 +4 +4 +3 → +4 +3 +4(actions·actors), 기준점 재기가 동작 칸 자리를 빼먹음(actors: 커밋된 표와 다름), 동작 중 이동 잠금 빼기, 프레임 = 틱 / 7, 누르고 있어도 반복 안 함, 조준 없이도 마우스 쪽 보기(M1 바라보기 600틱 중 60틱만 같음), 구역을 round 대신 floor, 목표 칸 한 구역 밀기, 검은 띠 빼기, 조준을 캔버스 변환 대신 창 좌표로, 맵 밖 표시 숨기기 빼기, 등급 무시하고 쌓기, 핫바 Q/E가 끝에서 안 돌기, 묶음 전체 나누기 허용, 도구가 99개씩 쌓임, Q와 E 바꾸기. 창 그림 검사로: 캐릭터가 동작 칸 자리를 빼먹음 → `rig` FAIL(불일치 655,477픽셀)·종료 1

같은 기기라도 실행 때마다 흔들린다. H1 검토 에이전트가 같은 데스크탑에서 잰 값은 아래 H1 표보다 최대 약 1.8배 느렸다(스냅샷 그리기·참가, 전체 테스트 46초). 그래서 H-fix는 이 세션에서 여러 번 돌린 범위로 적는다.

H-fix (2026-10-22, H1 검토 반영):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.2~4.4초, 종료 0, 오류 줄 0 (새 스크립트 없음, `.uid` 변화 없음) |
| 전체 테스트, 두 번 (마지막 코드) | 두 번 모두 6파일 통과 2,592 checks 46.8~47.0초 종료 0 (actors 1,188 / core 243 / light 73 / net 357 / net_session 302 / world 429). 오류 묶음은 알린 7개뿐. 이 세션의 다른 전체 실행은 49~52초. H1보다 약 7초 늘어난 것은 새 `stall` 세션(약 7초)이다 |
| 세션 테스트만 | 35.5~38.0초 (`stall` 포함). 내보낸 exe 자식으로(`--net-exe`) 통과 303 checks 35.2초 |
| 내보내기 | x86_64 3.2초 `evensong.exe` 109,500,872 B, ARM64 2.8초 91,894,728 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 85 checks ok, 0.5초 / 1.1초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 1.5초, 5부분 모두 ok (`_hidden_by`의 줄 잇기만 고침) |
| 호스트 멈춤, 실제 세션 (스크래치 2프로세스 + `stall` 세션) | 0.7초 멈춤(물리 틱 밖), 걷는 클라이언트 대기열 최고 42프레임. H1 규칙: 속도 제한 틱 194~204, 중복 프레임 1,813. H-fix: 0, 중복 885~960(다시 담은 것이 줄었다), 크레딧 39~40틱 사용, 예측 오차 0 |
| 호스트 멈춤, 모형 (`long_stall.gd`, 스크래치: 실제 `Prediction` + `InputGate`, Godot 순서) | 1초(60틱)까지 버림·빈 번호·보정 0. 64틱부터 대기열 상한을 넘은 프레임을 버림(64틱 2개, 90틱 262개), 빈 번호와 보정은 아직 0. 100틱(1.7초)부터 빈 번호 1개 + 보정 한 번: 1.7초 9.6px, 2초 33.6px, 2.5초 69.6px, 3초 이상 98.4px(클라이언트가 확인 안 된 프레임을 128개까지만 들고 있어서 더 커지지 않음) |
| ENet 패킷 조절 (스크래치 2프로세스: 0.7초 멈춤 + 4틱마다 편집 150번, 걷는 클라이언트, 호스트가 6틱마다 조절 값 기록) | ENet 기본: 6번 중 5번 32 밑으로, 1번은 약 7초째부터 0~8로 떨어져 확인 138번(다른 실행 152). 감속 0: 6번 모두 653번 잰 값이 다 32, 확인 152~153 |
| 늦은 참가 연결 인사가 서 있는 묶음에 드는 양 (스크래치: 둘이 서 있는 세션, 참가자 있음/없음 두 번씩) | 참가자가 붙으면 0/2 묶음 패킷 +3, 약 +135B |
| 일부러 깨 보기 (스크래치 `hfix/mutate.py`, 14개) | 14개 모두 FAIL·종료 1 (아래) |

H-fix 범위 (이 세션에서 돌린 전체 테스트 6번과 세션 테스트만 7번):

- `test_net.gd` 스냅샷: 128×96 그리기 20~33ms·참가 21~34ms, 512×512 합성 압축 3.3~4.4ms·그리기 445~742ms·참가 552~853ms, 512×512 무작위 압축 5.1~7.6ms·검사 + 풀기 4.0~5.0ms
- 실제 세션 늦은 참가(에디터 빌드 자식): 접속에서 월드 준비까지 76~116ms(그중 검사 + 풀기 + 그리기 22~41ms). 내보낸 exe 자식은 68~83ms(14~16ms)
- pair 0/2(호스트 송신): 109.8~115.2 B/s 또는 193.5~225.5 B/s. 뒤쪽은 늦은 참가자의 ENet 연결 인사(약 135B)가 그 1.45초 안에 떨어진 실행이다(위 "트래픽 통계"). 이 세션의 세션 실행 14번 중 4번
- 호스트 멈춤 단위 모형(1초): 물리 틱 안 멈춤은 대기열 최고 62 → 30틱 뒤 4 이하, 18틱 동안 여러 개씩 적용, 크레딧 0. 틱 밖 멈춤은 최고 60 → 4 이하, 20틱, 크레딧 59. 둘 다 속도 제한 0, 틱당 최대 4

일부러 깨 보기 (H-fix, 스크래치 `hfix/mutate.py`, 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 14개 모두 FAIL·종료 1): 게이트에서 멈춤 크레딧 빼기(H1 규칙) → 단위 시험(틱 밖 순서 대기열 31·제한 409틱)과 `stall` 세션(제한 191~194틱) 둘 다, `ticks_between`이 1000배 → 단위 시험, 호스트가 게이트에 1000배 시간을 줌 → 세션의 "토큰이 실제 시간을 따라감"(pair 401틱에 25,664틱), 호스트가 실제 시간 대신 틱마다 1(H1 전 규칙) → `stall`, 틱당 따라잡기 상한 빼기, 크레딧이 더해지게(30fps 흉내에서 300틱), 호스트가 스냅샷을 한 틱에 다 보냄 → 세션의 틱 수 검사(`four` 11조각 1틱), welcome 뒤 따라잡기 편집 안 보냄 → `stall`/c2 월드·편집 수·잘못된 메시지 46, 포트 확인을 `*` 하나로 → `test_core`(IPv4만 잡은 포트), 포트를 못 잡아도 파일을 돌림 → `test_core`, 여러 걸음 틱을 직선으로 그림 → `test_actors`(제단 안 5번), `MAX_SIDE` 2048로 → 단위 시험(52초 거리), ENet 조절 설정 빼기 → 단위 시험((5000, 2, 2))

H1 다지기 (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 (`.godot/` 지우고) | 3.1초, 종료 0, 오류 줄 0 (새 스크립트 4개의 `.uid` 생김, 커밋) |
| 전체 테스트, 두 번 | 두 번 모두 6파일 통과 2,459 checks 40.2초 종료 0 (actors 1,184 / core 229 / light 73 / net 326 / net_session 218 / world 429). 오류 묶음은 알린 7개뿐. G3보다 약 5초 느린 것은 러너 자식 마감 시험(2초)과 스냅샷 참가 측정(512×512 그리기 등 약 1.5초)이다 |
| `--net-full` | 통과, 397 checks, 34.3초 |
| 내보낸 exe로 세션 테스트 (`--net-exe=build/evensong.console.exe`) | 통과, 219 checks, 28.0초 (자식 14개 모두 내보낸 exe) |
| 내보내기 | x86_64 3.2초 `evensong.exe` 109,498,424 B, ARM64 3.0초 91,892,280 B, 둘 다 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 85 checks ok (스냅샷 왕복 하나 더, `snapshot=342B/73749B net=v2`), 0.6초 / 1.2초 종료 0 오류 줄 0 |
| 창 그림 검사 `check_render.gd` | 2.8초, 5부분 모두 ok (ysort 캐릭터 6, 제단 옆면 둘 `side_pixels_hidden=0`) |
| 두 창 스크린샷 | `shots/net_host.png`, `shots/net_client.png` 다시 찍음. 클라이언트 `join_ms=114.6` (창 모드, 그리기 56.8ms 포함) |
| 테스트 포트 | 두 러너를 동시에 띄우면 하나는 24621-24640, 하나는 24641-24660(둘 다 통과). `--port-base=25000` → 25000-25019, `EVENSONG_TEST_PORT_BASE=25100` → 25100-25119. 다른 실행이 쥔 묶음을 `--port-base`로 주면 `FAIL (startup) ... no free block`·종료 1 |
| 러너 자식 마감 | 30초 걸릴 자식을 2.05초에 죽이고 실패로 보고 |

늦은 참가 월드 스냅샷 (`test_net.gd`, 한 프로세스 안 ENet localhost로 조각 전송, 호스트처럼 1/60초마다 8조각씩. "참가"는 압축 + 전송 + 받는 쪽 검사·풀기 + 그리기):

| 월드 | 원본 → 압축 (zstd) | 조각 / 틱 | 압축 | 전송 | 검사 + 풀기 | 그리기 | 참가 |
|---|---|---|---|---|---|---|---|
| 128×96 M1 맵 (시드 1) | 73,749 B → 342 B (0.5%) | 1 / 1 | 0.2~0.3ms | 1틱 안 | 0.1~0.2ms | 20~21ms | 약 22ms |
| 512×512 합성 (생성기 + 벽 노이즈 덩어리·광맥·식생, 레이어 6장 다 씀) | 1,572,885 B → 54,210 B (3.4%) | 53 / 7 | 3.3~3.6ms | 102~103ms | 2.9~3.3ms | 441~467ms | 약 550~580ms |
| 512×512 무작위 (위 한계, 모든 칸 무작위) | 1,572,885 B → 약 1,377,950 B (87.6%) | 1,346 / 169 | 5~6ms | 2.8초 (틱 수로 계산, 보내지 않음) | 4~9ms | (안 그림) | 약 2.8초 + 그리기 |

- 실제 세션(헤드리스 자식, localhost): 늦은 참가자가 접속하고 월드가 준비되기까지 71~95ms(hello 왕복과 호스트 틱 기다림 포함, 그중 검사 + 풀기 + 그리기 18~24ms). `four`는 32바이트 조각 11개로 두 틱(M2b부터 채집물 때문에 18개·세 틱). 창 모드 클라이언트는 그리기가 길어 115ms. (H1 한 번의 측정. 여러 번 잰 범위는 위 H-fix)
- 참가 트래픽은 "joining" 묶음으로 따로 센다: pair 두 참가자 1,415 B(패킷 15), four 32바이트 조각으로 4.3~4.4 KB(패킷 75~78), `--net-full` 여덟 참가자 8.8 KB(패킷 113). 그래서 서 있을 때 트래픽은 G3와 같은 값으로 돌아왔다: pair 0/2 111 B/s, four 0/4 458~477 B/s, 9인 0/9 1.47 KB/s. 걸을 때: pair 949 B/s, four 4.4~4.5 KB/s, 9인 22.5 KB/s. (pair 0/2는 늦은 참가자의 연결 인사가 그 구간에 떨어지면 약 195~225 B/s다. H-fix에서 원인을 잼)
- 128×96의 그리기(20ms)는 G2의 "그림 칸 12,513개 그리기 33~36ms"와 같은 일이다(이번 측정이 더 빨리 나왔다. 기기 상태 차이)
- 512×512 무작위는 실제 월드가 아니라 압축이 안 될 때의 위 한계다. 틱당 8KB라 1.3MB는 2.8초 걸린다. 더 큰 맵은 "근처 청크부터"(스파이크 RESULTS §5) 같은 순서가 필요하다(아래 알려진 문제)

그 밖의 H1 측정:

- 호스트 멈춤 (`test_net.gd`): 걷는 클라이언트, 호스트가 60틱(1초) 멈춘 뒤 Godot처럼 따라잡기 틱 8개를 한꺼번에. 대기열 최대 61프레임 → 30틱 뒤부터 최대 1프레임. 예전 규칙(호출마다 토큰 1)으로 바꾸면 25프레임에서 내려오지 않는다(일부러 깨 보기). **H-fix에서 틀렸음이 밝혀짐**: 이 모형은 멈춘 동안의 프레임을 따라잡기 틱 전에 넣었다(물리 틱 안의 멈춤). Godot은 따라잡기 틱 뒤에 네트워크를 읽어서 실제 세션에서는 대기열이 약 30프레임 뒤처진 채였다(위 H-fix)
- 틱 사이에 그리기 (`test_actors.gd`, 144Hz 흉내, 1초 중 50틱 걷기): 프레임 사이 x 걸음 {0px: 84, 1px: 60} (예전 반올림 위치 그리기는 {0: 94, 1: 40, 2: 10}). 시뮬레이션 위치·바라보기·걷기는 모든 틱에서 같음
- 제단 옆 띠: 몸은 발에서 왼쪽 9px·오른쪽 9px까지(모든 방향·프레임), 제단 그림 불투명 열 0~46 → (서 5, 동 3). 옆면 높이의 모든 줄(46줄 × 양쪽)에 붙어 서도 몸 픽셀이 제단 그림에 겹치는 것 0. 장비는 아직 서쪽 6px(광부가 서쪽을 볼 때 곡괭이), 동쪽 7px(광부가 동쪽을 볼 때)까지 제단 가장자리 뒤로 들어갈 수 있다
- 바라보기: 가짜 연결 예측(지연 0·5·9틱, 손실 0·25%)과 모든 세션에서 바라보기 보정 0. 프레임 하나 1바이트 그대로(코드 36개 → 9개)

일부러 깨 보기 (H1, 스크래치 `mutate.py`, 하나씩 바꾸고 해당 테스트를 돌리고 되돌림. 17개 모두 FAIL·종료 1): 클라이언트가 자기 생성기로 월드 만들기(pair/c2 월드·그림 해시 다름), 받는 쪽이 월드 해시 검사 빼기, 보내는 쪽이 틱당 개수 넘기기, 호스트가 마지막 조각 전에 welcome(four/c4 종료 5), 호스트가 클라이언트 바라보기를 정하지 않기(세션 바라보기 보정 21), 예측 다시 돌리기가 바라보기를 안 정하기, 입력 토큰을 예전 규칙으로, 러너 자식 마감 빼기(30초 기다린 뒤 FAIL), 묶음 잠금 빼기, 묶음 UDP 확인 빼기, 제단 옆 띠 0, 서쪽 띠 1px 모자람(몸 픽셀 41개가 제단 그림에 겹침), 틱 사이 그리기 끄기, `begin_tick`이 시작점을 안 남기기, 물리 틱에서 `begin_tick` 안 부르기, 예측 걸음을 보정처럼 다루기, 월드 조각 RPC를 클라이언트가 부를 수 있게. 처음 돌렸을 때 "예측 걸음" 시험 하나는 기대값이 우연히 깬 결과와 같아 못 잡았다. 그 시험을 고치는 중에 진짜 문제를 찾았다: 그리는 시작점을 `apply_input` 안에서 남기면, 호스트에서 어떤 틱에 프레임이 안 온 다른 플레이어가 지난 틱 시작점으로 한 걸음 뒤로 그려진다. 그래서 시작점을 물리 틱마다 모든 플레이어에 남기게(`begin_tick`) 바꾸고 그 경우를 시험에 넣었다

M1 검증 반영 (2026-10-22, 러너·임시값 정리 뒤):

| 단계 | 결과 |
|---|---|
| 임포트 (두 번 했다: 고친 뒤, 주석 하나 더 고친 뒤) | 두 번 모두 3.0초, 종료 0, 오류 줄 0 (새 픽스처 `.uid` 2개 생김, 커밋) |
| 전체 테스트, 임포트마다 두 번 | 네 번 모두 6파일 통과 2,310 checks 35.4~35.6초 종료 0 (actors 1,138 / core 203 / light 73 / net 279 / net_session 188 / world 429). 오류 묶음은 알린 7개뿐 (위 "전체 테스트") |
| 러너 자체 시험 | 픽스처 11개 + `late_error.gd`를 자식 프로세스 둘로, 약 2.9초 |
| 내보내기 (두 번) | x86_64 2.5~2.6초 `evensong.exe` 109,481,520 B, ARM64 2.4~2.5초 91,875,376 B, 모두 종료 0, 오류 줄 0 |
| 내보낸 exe `--smoke` / 120프레임 | 84 checks ok (월드 해시 비교 하나 더), 0.4~0.5초 / 1.1초 종료 0 오류 줄 0. 에디터 빌드 `--smoke`도 84 checks ok |
| 러너 일부러 깨 보기 (커밋 안 함) | 남긴 노드를 지우지 않기, 남긴 노드 검사 빼기, 마지막 파일 뒤 기다림 0프레임, `GOLDEN_HASH` 한 글자. 4개 모두 `test_core.gd`(해시는 `test_world.gd`도) FAIL·종료 1 |
| 검증 에이전트의 탐침 9개 + 변형 1개 (스크래치에서 `tests/`에 잠깐 복사, 지움) | 루트에 노드를 남기는 탐침(3번째 프레임에 오류, 그리고 2번째 프레임으로 바꾼 변형)은 이제 그 파일이 FAIL이고 뒤 파일(통과 탐침)은 PASS, 혼자 돌려도 FAIL. 나머지 7개(알리지 않은 엔진 오류, 워커 스레드 push_error, 지연 호출, 타이머 콜백 실행 오류, `_exit_tree` 오류, 파싱 오류, 횟수 넘친 허용)는 전처럼 FAIL |

G3 (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 + 전체 테스트, 두 번 (흔들림 확인) | 두 번 모두: 임포트 2.9초 종료 0 오류 줄 0, 테스트 6파일 통과 2,297 checks 약 35초 종료 0 (actors 1,136 / core 192 / light 73 / net 279 / net_session 188 / world 429). net_session이 그중 약 28초 |
| `test_net.gd` | 279 checks, 약 0.4초. 가짜 연결 예측: 지연 0·5·9틱(손실 0·0·25%)에서 프레임 329개, 오차 0.000px |
| `test_net_session.gd` | 약 29초 (세션 셋 + drop). `--net-full` 넣으면 약 33초 (자식 10개 세션 하나 더) |
| 내보내기 | x86_64 2.7초 `evensong.exe` 109,481,072 B, ARM64 2.4초 91,874,928 B, 둘 다 종료 0, 오류 줄 0. 내보낸 exe 120프레임(헤드리스) 1.1초 종료 0 오류 줄 0 |
| 내보낸 exe `--smoke` | 83 checks ok (네트워크 8개 더: 물리 틱, ENet 루프백 호스트, Steam 없음, 상태 왕복, 10번째 거부, main.tscn의 Net) |
| 내보낸 exe로 세션 테스트 (`--net-exe=build/evensong.console.exe`) | 통과, 189 checks, 약 28초 (호스트·클라이언트·늦은 참가자·거부되는 다섯 번째·drop 모두 내보낸 exe, 자식 14개) |
| 두 창 스크린샷 (창 모드, `--max-fps 60`) | `shots/net_host.png`(호스트 화면), `shots/net_client.png`(클라이언트 화면), 둘 다 480×270. 같은 순간의 두 화면에 팔라딘(호스트)과 성직자(클라이언트)가 같은 자리에 보인다 |
| 일부러 깨 보기 (스크래치 `mutate.py`, 커밋 안 함) | 15개 모두 잡힘 (아래) |

트래픽 (localhost, ENet 통계 = ENet 헤더 포함·UDP/IP 헤더 제외, 괄호는 UDP/IPv4 28B/패킷을 더한 선로 추정. 봇이 같이 걷는 동안 / 모두 서 있는 동안, 이 세션에서 여러 번 돌린 범위):

| 인원 | 호스트 송신, 모두 걸을 때 | 호스트 송신, 모두 서 있을 때 | 클라이언트 하나 송신 (걸을 때 / 서 있을 때) | 클라이언트 하나 수신 (걸을 때) |
|---|---|---|---|---|
| 2 | 950~970 B/s (1.6 KB/s), 23~24 pkt/s | 111 B/s (266 B/s), 5.5 pkt/s | 760~780 B/s (1.7 KB/s) / 40~53 B/s | 약 960 B/s |
| 4 | 4.5~4.6 KB/s (6.5~6.6 KB/s), 72 pkt/s | 475~550 B/s (1.0~1.1 KB/s) | 730~790 B/s (1.7 KB/s) / 40~47 B/s | 약 1.5 KB/s |
| 9 (`--net-full`) | 22.0~23.1 KB/s (27~28.6 KB/s ≈ 0.23 Mbps), 185~193 pkt/s | 1.5 KB/s (2.6 KB/s) | 680~740 B/s / 42~64 B/s | 약 3.0 KB/s |

- 서 있을 때 세션은 아무것도 보내지 않는다(테스트: 조용함 위반 0). 남는 것은 ENet 유지 패킷(클라이언트 하나당 초당 약 5개)과, 표의 4·9인 "서 있을 때"에 섞인 출입·편집·키프레임 같은 일회성 메시지다
- 스파이크(RESULTS §5, `MultiplayerSynchronizer` always 30Hz)는 4인 6.5 KB/s, 9인 36 KB/s를 서 있어도 똑같이 보냈다. 지금은 20Hz·바뀔 때만이라 걸을 때 4인 4.6 KB/s, 9인 약 23 KB/s, 서 있을 때는 유지 패킷 정도
- 클라이언트 송신이 인원과 상관없이 비슷한 것은 입력만 보내기 때문이다 (30 pkt/s, 확인 안 된 프레임을 다시 담음)
- 9인 수치는 `--net-full` 1.45초 창 하나에서 잰 것이라 거칠다
- 지연 흉내(왕복 120ms, 손실 15%): 클라이언트 입력 패킷 약 129개 중 19개 버림, 호스트에 중복 프레임 수백 개(다시 담은 것), 빈 번호 0, 예측 오차 0.0px. 남의 캐릭터를 그릴 때 가장 새 상태를 지나 버린 프레임 14~23 / 약 90 (100ms 버퍼로 15% 손실을 다 덮지는 못한다. localhost에서는 0)
- 10프로세스(`--net-full`)를 처음 돌렸을 때 클라이언트 하나가 남의 캐릭터를 그린 프레임의 18%에서 새 상태를 지나 버렸다. 호스트 시계 추정을 클라이언트 물리 틱 수로 했더니, CPU를 늦게 받은 프로세스가 틱을 몰아서 따라잡을 때 추정이 앞서 나갔다. 클라이언트 쪽을 실제 시간(`Time.get_ticks_usec`)으로 바꾼 뒤 0

일부러 깨 보기 (G3, 스크래치 `mutate.py`, 파일마다 되돌림): 다시 돌리기 빼기, 서 있을 때도 프레임 기록, 속도 제한 끄기, 중복 프레임 다시 적용, 빈 자리 다시 쓰기 끄기, 인원 상한 끄기, 키프레임 안 보내기, 늘 묶음 보내기, 클라이언트가 편집 무시, welcome에서 편집 기록 빼기, 보간 지연 빼기, 상태의 y에 x 쓰기, 지연 흉내가 안 버림, 호스트가 멈춤 프레임 무시, 호스트 잃은 클라이언트가 종료. 마지막 코드로 다시 돌려 15개 모두 테스트가 FAIL·종료 1. 처음 돌렸을 때 "보간 지연 빼기"만 놓쳐서(세션 테스트가 끝 위치만 봤다) "가장 새 상태를 지나 그린 프레임" 검사를 더했다. 그 과정에서 조용함 판정의 순서 버그(걸음 시작을 그 틱의 묶음 판단 뒤에 기록해서, 조용하다 처음 움직이는 묶음을 위반으로 셈. 세션 테스트가 가끔 실패)도 찾아 고쳤다

G2 (2026-10-22):

| 단계 | 결과 |
|---|---|
| 임포트 | 4.3초, 종료 0, 오류 줄 0 |
| 기준점 표 다시 만들기 | 0.6초, 종료 0, 커밋된 파일과 같음 (테스트가 다시 재서 확인) |
| 전체 테스트 | 4파일 통과, 1,811 checks, 약 9.0초, 종료 0 (actors 1,136 checks 1.3초 중 기준점 다시 재기 0.5초, core 173 checks 2.8초, light 73 checks 0.4초, world 429 checks 4.1초) |
| 창 그림 검사 `check_render.gd` | 2.5초, 5부분 모두 ok, 종료 0 (ground 화면 129,600픽셀 중 129,347개 판정·불일치 0, 테두리 고리 20,900개; flames 81개 차 0; actor 298픽셀 불일치 0; rig 10화면 1,296,000픽셀 불일치 0; ysort 불일치 0) |
| 내보내기 | x86_64 4.0초, `evensong.exe` 109,413,984 B; ARM64 3.9초, 91,807,840 B. 둘 다 종료 0 |
| 내보낸 exe `--smoke` | 0.7초, 75 checks ok, 월드 해시 `e04258e54b02` (에디터 빌드와 같음) |
| 내보낸 exe 120프레임 (헤드리스) | 1.3초, 종료 0, 오류 줄 0 |
| 내보낸 exe 창 스크린샷 (`--class=herbalist`) | 480×270, 종료 0 (G1에서 못 해 본 것) |
| 스크린샷 (main.tscn) | 약 1.9초, 480×270 (이 세션 화면이 1024×768이라 창 960×540) |
| 안전 반경 빛 이미지 226×226 만들기 (GDScript, 영역마다 한 번) | 약 26 ms |
| 생성 128×96 / 그림 칸 12,513개 그리기 / `set_terrain` 한 번 (헤드리스, 예열 뒤 3번) | 2.5~5.4 ms / 32.9~35.8 ms / 약 17 µs |

마지막 줄은 G1(아래)보다 느리게 나왔는데, G1 커밋(`0c1c032`)을 그대로 풀어 같은 때에 돌려도 33.6~34.9 ms, 17.6 µs가 나왔다. 코드가 아니라 그때 기기 상태 차이다. 실행마다 이 정도는 흔들린다고 보면 된다.

G1 (2026-10-21): 임포트 2.5초, 전체 테스트 2파일 580 checks 4.9초, 내보내기 각 2.6초(109,359,360 B / 91,753,216 B), 내보낸 exe 스모크 0.38초 43 checks, 생성 1.3~2.4 ms, 그리기 18.7~22.5 ms, `set_terrain` 약 10 µs.

생성·그리기 수치는 헤드리스(더미 렌더러)라 GPU 쪽 비용은 들어 있지 않다. 실제 창에서의 프레임 시간은 아직 재지 않았다.

일부러 깨 보기 (G2에서 한 번씩, 커밋하지 않음, 스크래치 `mutate.sh`): 테스트로 - 북쪽 그리기 순서, 서쪽 반전 끄기, 기준점 무시, 커밋된 기준점 표 한 값, idle 발 맞춤 이동, 디더 빛이 반경 밖까지, 캐릭터 빛을 디더로, 불꽃 shaded, y 정렬 끄기, 제단 충돌 끄기, 대각선 정규화 빼기, 카메라 가장자리 멈춤 빼기, 머리 자리 빼기, 대각선 바라보기 규칙, 스폰 자리를 제단 위로. 15개 모두 FAIL·종료 1. 창 그림 검사로 - 위 "그림 검사" 8개 모두 FAIL·종료 1.

일부러 깨 보기 (G1에서 한 번, 커밋하지 않음): 그림 칸의 코너를 한 칸 밀기, 편집 때 4칸 중 1칸 안 그리기, 흙을 반경 1.6배까지 놓기, 흙·재 이웃 규칙 끄기, 커밋된 `.tres`의 코너 하나 바꾸기, `project.godot` 화면비를 keep으로, 빌더의 변형 가중치 바꾸기. 7개 모두 테스트가 FAIL·종료 1로 잡았다.

## M1 범위와 단계 상태

M1 = 한 화면에서 이동, 타일, 제단 빛, 2인 접속. 전투·채굴·건설·농사·제작·적·UI 메뉴·Steam은 M1이 아니다.
M2a = 혼자 할 때의 아이템·인벤토리·핫바·마우스 조준·몸 동작 재생과 최소 HUD. 동작의 월드 효과(채굴·농사), 줍기, 전투·피해, 제작, 건설, 상인, 스킬, 기도, 저장, 나무(? game-concept §12)는 M2a가 아니다.
M2b = M2a를 호스트 권한 세션으로 + 지상 채집물과 F 줍기(등급 ● §3.4) + 떨어진 아이템(디버그 버리기) + 늦은 참가에 그것들. 채굴 효과, 농사, 전투·피해, 제작, 건설, 상인, 스킬, 기도, Steam, 저장, 나무·나뭇가지·통나무는 M2b가 아니다.
M3a = 혼자 할 때의 지도 둘(지상 + 첫 던전), 던전 생성·그림, 입구·계단으로 오가기, 벽 충돌, 채굴(공용·광부), 던전 어둠과 횃불. 세션의 던전(M3b), 전투·HP·적·적 생성(M4), 이단의 제단 파괴(M4), 농사, 제작, 건설·벽 놓기, 상인, 스킬, 기도, Steam, 저장, 나무는 M3a가 아니다.
M3b = M3a가 더한 것을 호스트 권한 세션으로(지도 번호, 오가기, 지도 보내기, 지도별 편집·상태·그리기, 채굴·횃불 검사, 늦은 참가). 전투·HP·적·적 생성(M4), 이단의 제단 파괴(M4), 농사, 제작, 건설·벽 놓기, 상인, 스킬, 기도, Steam, 저장, 나무는 M3b가 아니다.
M4b = M4a가 더한 것을 호스트 권한 세션으로(입력·검사·공격 판정·적·화살·소생·사망·가방·부활·제단·늦은 참가·지도 들어옴). 스킬(1·2·3), 시그니처(R), 우클릭 보조(? §2.2), 클래스 자원, "가장 가까운"을 넘는 어그로(M9), 방어구·방어 수치·내구도(M7), 상태이상·포션·약제 던지기(M6), 오염 게이지, 정화·농사(M5), 제작·건설·상인·기도·컬렉션, 보스(M12), 새 적, Steam, 저장은 M4b가 아니다.
M4a = 혼자 할 때의 HP·스태미나·대시(공유 시뮬레이션), 클래스마다 기본 공격 하나(핫바 무기), 경직·다운·소생·사망·부활, 사망 가방(일부 드롭), 이단 한 종(근접)과 그 스폰(빛 밖), 이단의 제단 파괴, 최소 HUD. 세션의 전투(M4b), 1·2·3 스킬, R 시그니처, 우클릭 보조(? §2.2), 클래스 자원, "가장 가까운"을 넘는 어그로(M9), 방어구·방어 수치·내구도(M7), 상태이상·포션·약제 던지기(M6), 오염 게이지·정화·농사(M5), 제작·건설·상인·기도·컬렉션, 보스(M12), 다른 적, Steam, 저장은 M4a가 아니다.
M6b = M6a가 더한 것을 호스트 권한 세션으로(CRAFT 요청과 호스트 검사, 조제대 놓기 편집, 물약 USE = 마시기, THROW 요청, 호스트의 물약 효과 틱, 효과 블록, 이단의 독 표시, 병 사건과 클라이언트 비행, 늦은 참가·지도 들어옴의 효과·병·조제대, 클라이언트의 해금 기억, 세션의 제작 창). 농사·씨앗·자라기·물주기·정화(M5), 작업대·모루·성물 제작대와 도구·무기 만들기(M7), 건설, 상인·상점 물약(M8), 다른 스킬·스킬 키, 클래스 자원, 기도, 효과 둘 밖의 것, 새 적, Steam, 저장은 M6b가 아니다.
M6a = 혼자 할 때의 제작 틀(작업대·레시피·해금·만들기), 조제대(놓기·막기·그림), Tab 제작 창, 물약 셋(야생 약초로, 등급 = 입력), 마시기, 약초사의 약제 투척, 효과 둘(버프 = 걷기 속도, 독)과 그 표시. 세션의 제작·마시기·던지기·효과(M6b), 농사·씨앗·자라기·물주기·정화(M5), 작업대·모루·성물 제작대 레시피와 도구·무기 만들기(M7), 건설, 상인·상점 물약(M8), 다른 스킬·스킬 키, 클래스 자원, 기도, 효과 둘 밖의 것, 새 적, Steam, 저장은 M6a가 아니다.
M5a = 혼자 할 때의 밭(괭이로 빛 안의 풀 일구기), 씨앗 셋(야생 약초·수확에서, 누가 무엇을 심나 ● R37), 물주기(물 준 흙 칸별 덧칠), 자라기(0~4단계, 약초사가 빠름), 낫 수확(야생 약초와 같은 아이템, 거두는 사람의 등급), 시듦과 되살아남(빛 밖·오염 2칸 안), 결정적인 지도별 농장. 세션의 농사(M5c), 정화·성수·제단 옮기기(M5b), 나무·도끼, 작업대·모루·성물 제작대·건설(M7), 상인·상점(M8), 다른 스킬, 클래스 자원, 기도, 제단 업그레이드(M12), 오염 확산·재오염, 새 적, Steam, 저장은 M5a가 아니다.
M5c = M5a·M5b가 더한 것을 호스트 권한 세션으로(지도마다 호스트 농장, 씨앗·성수 USE, 도구의 맞는 프레임, CHANNEL·ALTAR_LIFT·ALTAR_PLACE 요청과 호스트 검사, 상태의 채널링·든 제단, 정화·제단 편집, 들고 있는 동안의 부활 대기·참가 자리, 든 사람이 다운·나감, 늦은 참가에 밭·제단, 클라이언트의 깜빡임·점·놓을 자리 표시). 나무·도끼·작업대·건설(M7), 상인·상점 성수(M8), 다른 스킬, 클래스 자원, 기도, 제단 업그레이드(M12), 확산·재오염, 새 적, Steam, 저장은 M5c가 아니다.
M7a = 혼자 할 때의 작업대 체인(손 → 기본 작업대 → 모루 → 성물 제작대, 레시피 열넷, 제련), 1티어 장비(클래스 무기 다섯 + 갑옷 하나, 갑옷 칸), 내구도(사용·사망 마모, 부서짐, 모루 수리, 막대), 공유 창고(빛 안, 칸 16, F 창, 넣기·꺼내기). 나무·도끼(M7b), 건설, 세션(M7c), 상인·스킬·기도·컬렉션·보스·저장·룬·인챈트·기술자 장치·3티어는 M7a가 아니다.
M5b = 혼자 할 때의 정화(성수 3×3은 누구나, 팔라딘 F 채널링 반지름 3·3초, 정화된 칸 = 풀, 스폰 칸과 시든 작물이 따라감)와 제단 옮기기(F 2초로 들기, 좌클릭으로 놓기, 들고 있는 동안 안전 반경 없음, 다운이면 가까이 내려놓기, 빛·안전 반경·이단·부활 자리·비워 두는 자리·밭의 빛이 따라감). 세션(M5c), 오염 확산·재오염·원천 봉인·반경 확장, 상점 성수(M8), 다른 스킬, 클래스 자원, 기도, 제단 업그레이드(M12), 새 적, 나무·건설(M7), 저장은 M5b가 아니다.

| 단계 | 내용 | 상태 |
|---|---|---|
| G1 뼈대 + 월드 | 프로젝트·설정, 내보내기 2종, CLI·스모크, 테스트 러너(엔진 오류까지 셈, 자체 시험), 타일셋 빌더, 레이어 6장 데이터 + 꼭짓점 격자, dual grid 조회, 시드 생성기, 청크 바닥 그리기와 편집, world.tscn 자유 카메라, 테스트, 스크린샷 | **끝** |
| G2 캐릭터 + 빛 | 캐릭터 리그(5클래스, 걷기·idle 4방향, 서쪽 반전, 표식 레이어 오프셋 + 기준점 표, 발 기준 y 정렬), 이동·충돌(맵 경계, 제단), 플레이어 카메라, 제단 놓기 + 저녁 어둠 + 안전 반경 빛(바닥 디더 + 캐릭터 hard), `is_in_safe_zone()` = 빛, unshaded 불꽃, main.tscn(내 캐릭터 + 더미 넷), 테스트, 창 그림 검사, 스크린샷 | **끝** |
| G3 네트워크 | 전송 계층(ENet + Steam 자리, 시그널로 결과), 호스트·참가, 호스트 권한 이동(입력 프레임 → 호스트 검사·시뮬레이션 → 바뀔 때만 20Hz 묶음 + 키프레임) + 자기 캐릭터 예측·보정 + 남의 캐릭터 100ms 보간, 호스트가 세는 인원 상한 9 + 빈 스폰 자리 다시 쓰기, 클래스, 늦은 참가(시드 + 편집 기록 + 해시 확인, H1에서 스냅샷으로 바꿈), 다중 프로세스 테스트(2인·4인·지연/손실·호스트 잃음, 선택 10프로세스), 대역폭, 두 창·두 기기 명령 | **끝** |
| H1 다지기 | 늦은 참가 = 월드 스냅샷(레이어 6장, zstd, 1KB 조각 틱당 8개, 받는 쪽 검사, 생성기는 진단만, 흔든 생성기 참가자 시험, 128×96·512×512 크기와 참가 시간), 호스트가 바라보기를 정함(프레임에서 뺌), 호스트 멈춤 뒤 입력 대기열 돌아오기(실제 시간으로 토큰), 테스트 기반(러너 자식 마감, 테스트 포트 묶음 고르기·잠금), 제단 옆 겹침(옆 띠), 내 캐릭터를 틱 사이에 그리기, `session.gd` 흐름별로 나누기 | **끝** (사람 확인: 두 기기, 144Hz 화면) |
| H-fix 검토 반영 | 호스트 멈춤 따라잡기를 실제 세션 순서에서도(멈춤 크레딧, 틱당 4프레임, 시계 시험), ENet 패킷 조절 끔, 테스트 포트 IPv4 확인과 못 잡으면 멈춤, 여러 걸음 틱은 끝에 그리기, 스냅샷 크기 상한 512, `stall` 세션(멈춤 + 받는 도중 편집), 스트림 틱 수·토큰 실제 시간 세션 검사, 시험 정리 | **끝** (사람 확인: 두 기기) |
| M2a 아이템 · 조준 · 동작 | 아이템 표(도구 6·재료 1·채집물 15, 등급, 아이콘), 인벤토리 + 핫바(쌓기·나누기·옮기기·Q/E), 마우스 조준(8구역, 목표 칸, 마우스 쪽 바라보기, 창 늘이기 6가지를 엔진과 비교, 목표 칸 표시), 몸 동작 8개(64칸 발 맞춤, 기준점 다시 재기, 손에 든 표식 숨기기, 틱 단위 시간·이동 잠금·누르고 반복), 최소 HUD, 디버그 주기(`--give`, F5)·F6, 테스트 3파일 + 창 그림 검사, 스크린샷 4장. 혼자 할 때만 | **끝** (사람 확인: 마우스로 해 보기, 임시값 줄) |
| M2b 네트워크 + 월드 | 프레임 하나의 규칙(`PlayerSim`), 프레임에 바라보기·요청(사용·줍기·고르기·버리기·주기), 호스트 검사(손 닿는 칸·목표 칸·아이템·동작 중·요청 예산·주기 정책)와 같은 틱 경주, 상태에 동작·든 아이템, 주인에게만 인벤토리, 자기 동작·고르기 예측, 남의 동작 보간, 채집물 74개(식생 레이어, 등급 ● §3.4), 드롭 목록(해시·스냅샷·편집), 늦은 참가에 채집물·드롭·든 아이템, 전송 형식 v3, 봇 명령, 단위 시험 1파일 + 세션 시험 확장 + 창 그림 검사 `items`, 두 창 캡처 | **끝** (사람 확인: 두 기기로 휘두르기·줍기·경주, 임시값 줄) |
| M3a 지도 · 던전 · 채굴 · 횃불 | 지도 번호와 지도별 GameWorld, 던전 생성기(방·통로·광맥·기반암·출구 계단·이단의 제단 자리·벽 횃불, 황금 해시, 40시드 규칙), 던전 타일셋(절벽 셋 + context) 빌더와 동굴 dual grid(앞면, 광맥·금 오버레이), 지상 입구(생성기 5단계, 지상 해시 갱신), F로 오가기, 벽·앞면 충돌, 채굴(1×1/3×3, 경도·타격·금, 돌·광석, 가득 차면 드롭), 횃불(아이템·놓기·빛), 던전 어둠, 호스트 규칙(횃불·채굴, 입구 거부), 혼자 할 때 `--bot`·`--start-map`, 테스트 2파일 + 창 그림 검사 `cave`·`dark`, 스크린샷 3장 | **끝** (사람 확인: 아래 "M3a에서 확인하지 않은 것", 임시값 줄) |
| M3b 세션의 지도 | 플레이어마다 지도 번호(호스트 상태), TRAVEL 요청과 호스트 검사, 지도 보내기(스냅샷 길 + 지도 들어옴 + 그동안 편집, 클라이언트는 자기 지도만), 지도별 편집 기록·편집의 지도, 상태의 지도와 지도별 그리기·보간, 요청의 지도(`wrong map`), 지도 전환 예측, 늦은 참가에 지도, 채굴·횃불·드롭을 지도의 편집으로, 전송 형식 v4, 봇 `waitmap`·표시 파일 JSON, 단위 시험 1파일 + 세션 `cave`·`four` 던전 경주 + 지도별 일치 검사, 창 그림 검사 `cave_net`, 스모크 M3b, 두 창 캡처 | **끝** (사람 확인: 아래 "두 기기에서 M3 해 보기", 임시값 줄) |
| M4b 세션의 전투 | 호스트가 지도마다 아레나를 돌림(맞음·소생·사망·가방·부활·스폰·제단을 호스트가), 시작 무기, 다운 중 요청 거부, 조용한 클라이언트를 호스트가 진행, 전송 형식 v5(프레임의 대시·F·USE 조준, 상태의 vitals 블록, 지도별 적 묶음과 키프레임, 화살 사건), 공격 시작 바로 보내기, 클라이언트 `NetCombat`(트랙·거울 아레나·예고는 바로·자기 화살 바로), 예측의 vitals·부활·호스트 사건, 늦은 참가·지도 들어옴의 적 키프레임, 시험(한 프로세스: 악의 요청·싸움 흐름 여덟·예고 대 지연·조용한 클라이언트, 실제 세션 fight·fight4), 창 검사 `combat_net`, 스모크, 두 창 그림 | **끝** (두 기기 확인은 사람) |
| M4-fix 검토 반영 | 소생은 가장 빠른 사람(성직자 즉시, 자리 순서 무관), 화살 조준 점·그린 몸 상자, 빛 가장자리 4초는 맞아도 이어 셈, 빈 지도(공격 취소·화살 없앰·스폰 시계), 클라이언트 시계를 호스트 시간에 묶음(앞서지 못함·30틱 넘게 뒤처지지 못함·쉬면 0), 화살 칸 걷기, `MAX_DROPS` 빈 가방, 부활 알림, 오가기의 대시, 이단의 제단 자리 기억, `--test-shrine-hp` 상한, 이름 붙인 상수, 시험(두 소생자·서 있다 맞기·가끔 보내기·몰아 보내기·예고 중 떠나기·던전 사망·부활 대기·빈 지도·빛 가장자리 쏘기·화살 조준 360발·모서리 벽 1,625발·대시 오가기·가방·리플레이 비교, 실제 세션 `fightlag`), README, 두 창 그림과 M4a 그림 다시 | **끝** (사람 확인: 새 임시값 줄 셋, 특히 "M4-fix 빛 안에서 쏘인 이단", 예고 읽힘) |
| M6a 제작 · 조제대 · 물약 · 약제 투척 · 효과 | 제작 틀(작업대 = 설치물 종류, 레시피 입력·출력·등급·클래스, 모두 아니면 하나도 아님, 자리 없음 거부, 처음 얻은 재료로 해금 스위치, M7이 그대로 씀), 조제대(04-env 그림, 3×1, 막음, 디버그 아이템을 횃불처럼 놓기: 몸·붙음 검사), Tab 제작 창(코드 그림, 마우스·키, 열린 동안 서 있음, 멀어지면 닫힘), 물약 셋(띠에서 자른 아이콘, 야생 약초 둘 → 하나, 등급 = 입력, 상급·독은 약초사만 ●), 마시기(마법 동작 빌림, 효과 프레임, 가득 찬 HP 거부), 약초사의 약제 투척(1, 던지기 동작, 사거리·벽·반경, 아군 회복·버프와 이단 독, 아군 사격 끔), 효과 둘(버프 = 걷기 속도, 독: 공유 시뮬레이션과 아레나, 다운에 끝남, 독 처치 셈), 머리 위·HUD 표시, 세션은 그대로(꺼짐·거부), 시험 2파일 + 기존 둘 고침 + 창 검사 `crafting`·`potions` + 스모크, 스크린샷 4장, 일부러 깨 보기 25 + 창 4개 | **끝** (사람 확인: 아래 "M6a에서 확인하지 않은 것", 임시값 "M6a" 줄 15개. 세션은 M6b) |
| M6b 세션의 제작 · 물약 | CRAFT·THROW 요청과 호스트 검사(작업대·레시피·클래스·등급·입력·자리, 던질 점 자르기, 손 닿음·바쁨·다운·지도), 물약 USE = 마시기, 호스트의 물약 효과 틱(`Potions.release`, 혼자 할 때와 같은 규칙), 조제대 놓기 편집, 효과 블록(효과가 있을 때만)과 효과 = 타이머, 이단의 독 표시, 병 사건(던짐·터짐) + 클라이언트 비행(호스트와 같은 걸음 함수), 늦은 참가·지도 들어옴의 효과·병·조제대, 클라이언트의 해금 기억, 세션의 제작 창·창 잠금·봇 Tab, 임시값 하나(던진 회복과 다운), 전송 형식 v6, 시험(한 프로세스 1파일 + 실제 세션 `brew`·`brew4`), 스모크, 창 그림 검사 `potions_net`, 두 창 그림, 트래픽 | **끝** (사람 확인: 두 기기, 마우스·키로 세션의 제작·던지기, 버프가 많을 때의 트래픽, 임시값 "M6b 던진 회복과 다운") |
| M6-fix 검토 반영 | 조제대가 비워 두는 자리(도착점·부활 자리 아홉, 임시값), 병 unshaded + 창 검사의 어둠, 호스트 제작 검사 = 레시피 종류의 작업대, 자리 크기에 상관없는 작업대 찾기·`still_at`은 연 그 작업대, 설치물·작업대 값마다의 표(자리 크기·아이콘·클래스 거부), 끝난 독의 필드, 무기로 죽은 이단의 독, 독 틱 = `poison_hits`·로그 `POISON`, 동작이 시작될 때만 `done`, 던질 점 정수 px(혼자도), 이름 붙인 숫자·주석·줄 잇기, 시험(나타나는 자리, 큰 자리·종류·같은 거리의 작업대, 마시는 중 사라진 물약·다른 묶음·아레나 없음, 효과의 끝·지도 옮김·빈 지도, THROW + Space, 독 맞음 셈, 리그 시간으로 그린 표시가 꺼짐, 사거리 밖 던지기), brew 세션의 조제대 자리 옮김, 임시값 새 줄 넷과 문서 칸 고침, README, 두 창 그림 다시 | **끝** (사람 확인: 새 임시값 줄 넷, 특히 "M6-fix 조제대가 비워 두는 자리"·"M6-fix 플레이어의 독", 어둠의 병) |
| M5a 밭 · 씨앗 · 물주기 · 자라기 · 수확 · 시듦 | 밭 = 바닥 흙 + 식생 값(스냅샷·해시·편집이 그대로 덮음), 괭이(빛 안의 풀, 네 모서리), 씨앗 셋(띠의 씨앗 봉투, 야생 약초·수확에서, 독초는 약초사만 ●), 물뿌리개(60초, 물 준 흙 사분면 덧칠), 자라기(0~4단계, 젖은 동안만, 약초사 200%), 낫 수확(작물을 겨누면 수확만, 야생 약초 아이템 둘 + 씨앗, 거두는 사람의 등급, 넘치면 드롭), 시듦(빛 밖·오염 2칸 안, 원인이 사라지면 되살아남, 밭은 남음), 지도별 `Farm`(시계·난수 없음, 혼자 = 호스트 준비), 세션은 끔(씨앗 USE 거부), `--test-field`, 시험 1파일 + 창 그림 검사 `fields` + 스모크 `farm=`, 스크린샷 4장 | **끝** (사람 확인: 위 "혼자 M5a 해 보기", 임시값 "M5a" 줄) |
| M5b 정화 · 성수 · 제단 옮기기 | 성수(CONSUMABLE, 3×3, `--give`), 팔라딘 채널링(F, 공유 시뮬레이션, 3초·반지름 3, 끊김 다섯), 정화된 칸 = 풀(칸 편집 둘), 재 얼룩·금빛 테두리·점(코드 + 04-env 장식), `Arena.sync_world`(빛 규칙·스폰 칸), 제단 들기·놓기(설치물 칸 편집, `refresh_altar_rect`, 놓기 조건 아홉, 다운 때 내려놓기), 따라가는 것(빛·안전 반경·이단·부활 자리·비워 두는 자리·옆 띠·밭·더미), 든 제단·놓을 자리 표시, 세션은 끔(성수 USE 거부), 시험 2파일 + 창 그림 검사 `purify`·`altar` + 스모크 `purify=`·`altar=`, 스크린샷 6장 | **끝** (사람 확인: 위 실행 예, 임시값 "M5b" 줄) |
| M5c 세션의 농사 · 정화 · 제단 | 호스트 농장(지도마다, 틱 순서), 씨앗 USE = 심기·도구 맞는 프레임 = 일구기·물주기·수확(호스트의 자리·클래스·인벤토리), 야생 약초의 씨앗, 성수 USE, CHANNEL(F 변환·예측·호스트 시계)·정화 편집·아레나 따라감, ALTAR_LIFT(호스트가 센 F)·ALTAR_PLACE(호스트의 몸·이단), 든 사람의 금지 요청·다운·나감, 들고 있는 동안 부활 대기·참가 자리(임시값 둘), 전송 형식 v7(새 요청 셋, 상태의 채널링·든 제단 0B), 예측의 채널링·부활 자리, 클라이언트 깜빡임·점·놓을 자리 표시, 시험 3파일(한 프로세스 + 실제 세션 넷) + 기존 셋 고침 + 창 검사 `fields_net` + 스모크, 두 창 그림, 일부러 깨 보기 33 + 창 3 | **끝** (사람 확인: 위 "창 둘로 M5 해 보기", "두 기기에서 M5 해 보기", 임시값 "M5c" 줄) |
| M5-fix 검토 반영 | 빛 아래 오염(지금 동작을 임시값·스위치로, 시험), 들고 있는 동안의 참가 자리(비워 둠, 설 수 있는 곳), 들기 셈 규칙 하나(채널링·소생 중엔 안 셈, 호스트는 손 닿는 곳에서만, 제단을 겨눈 F는 채널링 아님), 채널링 끊김 셈(맞음 포함), 내려놓기 마지막 길(놓기 규칙, 없으면 든 채), 혼자 할 때 내려놓는 때(전투 뒤), 호스트를 잃었을 때 제단 되놓기, 빛 텍스처 한 쌍, 내려놓을 자리 찾기·농장 비용, 문서 표기(○/●, 독초를 누가 거두나, 든 사람이 하는 것), 줄 잇기, 시험(한 프로세스 셋 + 혼자 다섯 + 트래픽 일치), 일부러 깨 보기 16, README | **끝** (사람 확인: 새 임시값 줄 둘 "M5-fix 빛 아래 오염"·"M5c 호스트를 잃었을 때 제단", 바뀐 줄 "M5b 키"·"M5b 든 사람이 다운되면"·"M5c 들고 있는 동안 참가"·"M5c 든 사람이 나감"·"M5a 수확 등급"·"M5b 들고 있는 동안") |
| M4a 체력 · 대시 · 기본 공격 · 사망 · 이단 | 공유 시뮬레이션의 Vitals(HP·스태미나·대시·경직·다운·사망 시간), Space 대시(걷기 충돌), 클래스 무기 다섯(근접 호 셋·화살·빛 탄, 새 아이템 성광, 핫바 8번 시작 무기, 곡괭이 채굴/공격 규칙, 아군 사격 끔), 피격·사망 자세(기준점 표·창 검사), 다운·소생(성직자 즉시)·포기·사망·제단 부활, 사망 가방(절반/3종 규칙, 설치물 칸 + 드롭 = 월드 기계 그대로, F로 되찾기), 이단(시트 다섯, 쫓기·예고·맞는 열·끈·빛 가장자리, 지상·던전 스폰, 지도별 아레나), 이단의 제단 HP와 부서진 그림·스폰 멈춤, HUD 막대·카운트다운, 시험 2파일 + 창 검사 `heretic`·`bars` + 스모크, 스크린샷 5장, 일부러 깨 보기 23개 | **끝** (사람 확인: 아래 "M4a에서 확인하지 않은 것", 임시값 "M4a" 줄. 세션은 M4b) |
| M3-fix 검토 반영 | 광부 3×3은 친 칸을 깰 수 있을 때만(계단 둘레), 벽 횃불 자리 고르기(도착 방은 늘 밝음, 출구·광맥 순서), F5 묶음 2칸 비움, 호스트를 잃은 클라이언트(빈 던전 거부, 채굴·횃불 잇기), 디버그 드롭은 벽·앞면 거부, 맨 윗줄 그림 = 충돌, 결과용 기록 상한, 줄 잇기 넷·`_on_local_map_changed` null, 시험(계단의 광부, 방마다 벽 횃불, 횃불 요청 예산, 지도 들어옴의 보임, 묶음 빈 칸, 호스트 잃은 뒤 혼자), README 고침, 두 창 캡처 다시 | **끝** (사람 확인: "두 기기에서 M3 해 보기", 새로 적은 임시값 문구) |
| M2-fix 검토 반영 | 발 칸 = 발 상자 가운데(타일 선 위의 발), 사용의 바라보기를 호스트가 목표 칸에서, 동작 중 표시는 동작의 칸, 고르기는 예산 밖 + 거부되면 인벤토리로 바로잡기, 클라이언트 F7도 주기처럼, 거부 로그 줄이기, 클라이언트 `--give` 255씩 나누기 + 줄 64개·버린 것 로그, 시험(서서 조준, 인벤토리 다시 얹기, `tick` 순서, `MAX_DROPS`, M1 바라보기를 따로 적은 600틱, 발 칸, 표시, 주기 나누기, 버리기 끔), README 고침, 스크린샷 5장 다시 | **끝** (사람 확인: 두 기기, 새 임시값 표 문구) |
| M7a 작업대 체인 · 1티어 장비 · 내구도 · 공유 창고 | 작업대 셋(설치물·그림·손 닿음)과 손 레시피, 레시피 열넷과 수리 여섯(물약 번호 그대로), 제작 창(재료 셋, 수리 줄, 스크롤), 1티어 무기 다섯(기본 무기를 읽음, 150%)과 갑옷 칸(입기·벗기·방어 4), 내구도(1티어만, 사용·사망 마모, 부서지면 기본, 모루 수리, HUD 막대, F7 거부), 창고(빛 안, 칸 16, 월드의 것, 해시, F 창, 넣기·꺼내기), 세션에서 거부·꺼짐, 시험 셋·창 검사 셋·스크린샷 셋 | 완료 (혼자 할 때) |

### 검토 반영 (M5-fix, 2026-10-24)

M5(M5a + M5b + M5c) 검토 에이전트들의 지적 26개(겹친 것: 들고 있는 동안의 참가 둘, 채널링 중 들기 둘, 채널링 끊김 셈 둘, 내려놓기 마지막 길 셋, 소생 중 들기 둘, 호스트를 잃었을 때 둘, 문서 표기 둘)와 처리. 하나씩 코드를 읽고 고쳤고, 고친 규칙마다 옛 동작으로 되돌리면 실패하는 시험을 붙였다(일부러 깨 보기 16개, 위 "측정"의 M5-fix). 임시값 값은 하나도 바꾸지 않았다(새 줄 둘, 기존 줄 여섯에 문구를 더하거나 고침, 새 스위치 `ALTAR_LIGHT_MAY_COVER_CORRUPTION`은 지금 동작을 켬으로).

- 정함 → 임시값 (중간): 제단을 오염 구역 바로 옆에 놓을 수 있어 그 빛이 오염 칸을 덮었다(시드 1 (72,22): 빛 안 오염 칸 51). 오염은 남고, 스폰 칸이 빛 가장자리에 붙고, 부활 자리가 재 위일 수 있고, 빛 안 작물이 시든다. ○ §5 "밀어낸다"·§9.3 "오염 저항"을 M5b가 말없이 정한 것이었다. 지금 동작을 켬으로 둔 스위치와 임시값 줄 "M5-fix 빛 아래 오염"(켠 이유: ○ §9.7 슬라이스 줄 "고정 오염 구역 옆 밭으로 시험한다", 끄면 "오염에 닿은 작물 → 정화" 고리가 플레이에서 안 생김). 끈 쪽(빛 + M1 여유 4칸 안의 오염이면 거부)도 만들어 두고 함수로 시험. 시험: 구역 옆 자리(시드 1 (52,6)) 됨·끈 규칙이면 거부·서쪽 풀·집은 아님·빛 안 오염 17칸 그대로·빛 안 스폰 칸 0
- 고침 (중간, 겹친 둘): 들고 있는 동안 `reserved_feet`에 부활 자리가 없어(제단이 없으니) 그 자리에 조제대를 놓을 수 있었고, 그동안 참가한 사람이 탁자 속에 나타났다(M6-fix의 "나타나는 자리" 규칙이 깨짐). 호스트가 든 자리의 부활 자리 아홉을 그동안에도 비워 두고(`carried_reserved_feet` → `WorldItems.place`의 `where players appear`), `spawn_feet`는 설 수 없는 자리를 건너뛴다(없으면 지상 도착점). 시험: 월드 규칙만으로는 되는 조제대 자리가 거부, 규칙 밖으로 막은 자리를 건너뜀, 참가자는 설 수 있는 곳
- 고침 (중간, 겹친 둘): 혼자 할 때 채널링 중에도 F를 누르면 들기를 세어 제단이 채널링 도중 들리고 채널링은 든 채 끝나 정화했다(호스트는 `busy`로 거부: 혼자와 호스트가 달랐다. 클라이언트 `hold_altar`도 채널링 중에 세어 거부될 ALTAR_LIFT를 보냈다). 들기 셈을 규칙 하나로(`AltarMove.hold_counts`: 동작·채널링 중이 아님, 다운된 사람이 소생 거리 안에 없음)를 혼자·클라이언트·호스트가 같이 쓰고, 제단을 겨눈 F는 채널링을 시작하지 않는다(`Main.pick_up`, `wants_channel`). 시험: 혼자(구역 옆 제단, 채널링 내내 F를 제단에 = 안 듦·정화됨·그 뒤 듦), 호스트(셈 ≤ 1, 그동안의 ALTAR_LIFT 거부), 클라이언트(`hold_altar` 0)
- 고침 (중간, 겹친 둘): 비성직자의 소생(F 5초)이 손 닿는 제단 칸을 겨누고 있으면 2초에 제단이 들려 빛·안전 반경·부활 자리가 사라졌다(혼자·세션 모두). 다운된 사람이 소생 거리 안에 있는 동안은 세지 않는다(위 `hold_counts`, 임시값 "M5b 키"에 적음). 시험: 혼자(소생 299틱, 들기는 그 120틱 뒤), 호스트(셈 0, 거부), 클라이언트
- 고침 (중간): 빛 텍스처 캐시 열쇠가 제단 가운데 자체라 새 자리마다 모든 기기가 텍스처 둘을 만들고(약 38ms 멈칫) 쌓았는데, 그림은 4px 위상·소수부에만 달린다. 열쇠를 바꿔 한 쌍을 모든 자리가 쓴다(놓는 순간 0.2ms, 쌓이지 않음). `test_light.gd`의 "작은 맵 = 새 쌍"은 그 열쇠를 시험하던 것이라 "같은 위상 = 같은 바이트·같은 쌍, 다른 위상·소수부 = 다른 열쇠"로 바꿨다
- 고침 (중간, 겹친 둘): 호스트(나 다른 클라이언트)가 제단을 든 채 호스트를 잃으면 혼자 계속하는 클라이언트의 월드에 제단이 영영 없었다(죽으면 부활을 영영 기다림, 밭이 모두 시듦, 클라이언트가 든 채면 내려놓기의 마지막 길이 빈 자리라 제단이 사라짐). 월드가 마지막으로 선 자리를 기억하고(`GameWorld.last_altar_rect`) `_go_offline_combat`가 거기 되놓는다(임시값 "M5c 호스트를 잃었을 때 제단"). 시험: 리그 클라이언트의 월드가 그 자리를 기억하고 `Main.restore_altar_at`이 거기(그 위 조제대면 옆에) 되놓음. 실제로 호스트를 죽이는 세션 시험은 없다(알려진 문제)
- 고침 (낮음, 겹친 셋): 내려놓기의 마지막 길(호스트 `_set_altar_down`, 혼자 `set_altar_down`, `ALTAR_SET_DOWN_WHEN_CARRIER_LEAVES` 끔)이 들었던 자리를 검사 없이 덮어 그동안 놓인 조제대·횃불·가방·드롭을 지우거나 사람을 덮을 수 있었다. `AltarMove.set_down_fallback`: 발 둘레(이단과·빼고) → 든 자리 둘레(그 자리 먼저), 모두 놓기 규칙. 하나도 없으면 든 채(일어나면 다시 찾음)·나가는 사람은 들고 나감(알려진 문제). 시험: 맵 밖 먼 점에서 = 든 자리, 모르면 없음, 그 위 횃불·사람이면 옆, 집 먼저
- 고침 (낮음, 겹친 둘): 호스트가 맞음(프레임 사이 아레나의 칼)으로 끊긴 채널링을 세지도 찍지도 않았다. 멤버의 `Player.channel_broken`으로 센다(모든 끊김, 이유를 로그에). 시험: 채널링 중 `take_hit` → `channel_broken` 1·그 뒤 빈 프레임에 그대로
- 고침 (낮음): 호스트의 `altar_hold`가 어디서든 F만 이어 누르면 세어, 악의 클라이언트가 멀리서 누르고 있다가 손 닿는 첫 프레임에 들 수 있었다(README는 "바로 들 수 없다"고 했다). 그 프레임의 발에서 손 닿는 제단 칸이 있을 때만 센다(`altar_in_reach`). 이 때문에 기존 시험 둘의 거부 이유가 바뀌었다(두 칸 밖, 던전: `F not held long enough`). 시험: 8칸 밖 130프레임 = 0, 손 닿는 곳 ALTAR_LIFT 거부
- 고침 (낮음): 혼자 할 때 든 사람이 다운되면 `Player.hurt`에서(아레나 걸음 가운데) 바로 놓아 호스트(아레나 뒤 `_check_carriers`)와 순서가 달랐다. `Main.check_carriers`가 전투 뒤에 한다. 시험: 맞은 순간은 그대로 들고 있고 `check_carriers`에서 놓임
- 고침 (낮음): 내려놓을 자리 찾기가 후보마다 입구를 찾고 이단 검사를 맨 뒤에 해서, 이단이 운반자 옆이면 9~29ms. 찾기마다 비워 두는 자리를 한 번, 이단의 빛 검사를 먼저: 0.5~1ms(같은 자리를 고름)
- 고침 (낮음): 농장이 매 틱 모든 칸의 시듦 원인을 다시 구하고 열쇠를 정렬했다(마른 작물 1,000개 3~4.8ms). 원인을 기억(제단 자리·오염 레이어 해시가 바뀔 때만 다시)하고, 원인과 맞는 마른 작물은 값만 읽고 건너뜀: 0.11ms. 오염 칸 수로 바뀜을 보면(아레나처럼) 한 칸 걷고 한 칸 생긴 틱을 놓친다(`test_farming.gd`의 2칸 시험이 잡음: 일부러 깨 보기). 시험: 마른 작물도 시들고 되살아남, 기억이 있는 동안 밖에서 놓은 마른 작물도 다음 틱에 시듦
- 고침 (낮음, 문서): ○를 ●로 적은 곳(README M5a·M5b·"M5a 시듦" 줄의 "밭은 남는다", `farming.gd`의 도구 순서)을 ○(구현한 기본값)로. 든 사람이 하는 것(제작 창·버리기·고르기도 됨)을 README와 줄에 바로 적음. 독초를 누구나 거둔다(일반 등급)는 것을 "M5a 수확 등급" 줄에(R37은 심기만 정함)
- 고침 (낮음): 클라이언트의 "든 사람은 CHANNEL을 보내지 않음"(`wants_channel`)에 시험이 없었다. 시험: 오염 옆 = CHANNEL, 든 사람·제단 칸 = 아님
- 고침 (낮음): 트래픽 시험이 시험 밭을 기록 밖으로 넣어(`put_test_fields`) 측정 내내 클라이언트 월드가 호스트와 달랐다. 호스트 편집으로 넣고 심은 뒤와 끝에 두 클라이언트 월드 = 호스트 월드를 본다(잰 값 그대로 14.1 B/s)
- 고침 (낮음): `net_bot.gd`의 `waitfield` 검사가 탭으로 이어 붙은 한 줄이었다. `\` 줄 잇기 셋으로
- 일부 고침 (낮음): 제단을 들거나 놓아 가득 찬 밭이 한 틱에 바뀌면 그 틱이 길다. 빛 텍스처 몫(약 40ms)은 위에서 없앴다. 편집 로그 줄의 월드 해시(작물 104개에 약 8ms)와 편집 묶어 보내기는 **그대로 둠**: 해시는 세션 시험이 편집 번호마다 같은 월드인지 보는 길이고, 묶음은 전송 형식을 바꾼다(M5c 알려진 문제)

알려진 문제 (M5-fix):
- 내려놓기를 놓기 규칙이 모두 거부하면(운반자 발과 든 자리 둘레 64칸 안에 놓을 곳이 하나도 없을 때) 다운된 운반자는 든 채로 있고(혼자면 죽어도 부활이 제단을 기다리므로 막힌다), 나가는 운반자는 들고 나간다. 실제 지도에서는 생기지 않는다고 보고 시험은 함수(맵 밖 먼 점)로만 했다
- "이단을 빼고"의 내려놓기는 살아 있는 이단을 새 빛 안에 둘 수 있다. 이단은 빛에 들어가는 걸음을 모두 거부해서(M4a) 그 자리에 선다. 운반자 둘레에 이단이 없는 자리가 64칸 안에 하나도 없을 때뿐이다
- 호스트를 잃었을 때 제단 되놓기는 한 프로세스 리그의 클라이언트 월드로만 시험했다(`drop` 세션은 제단을 들지 않는다). 든 동안 참가해 제단을 본 적이 없는 클라이언트는 자기 발 둘레에 놓는다
- 소생 중엔 들지 않는 규칙에서 클라이언트는 다운된 사람을 자기가 그린 대로 본다: 호스트와 한 틱쯤 다르면 120번째 프레임의 ALTAR_LIFT가 거부되고 다시 2초
- 호스트의 `_altar_lift`의 채널링 `busy` 검사는 이제 셈 규칙에 가려 쓰이지 않는다(되돌려도 시험이 통과: 셈이 먼저 0이 된다). 다른 길로 들어오는 요청을 막으려고 남겨 둠

### 검토 반영 (M6-fix, 2026-10-22)

M6(M6a + M6b) 검토 에이전트들의 지적 20개(겹친 것: 던질 점 반올림 둘, 줄 잇기 둘)와 처리. 하나씩 코드를 읽고 검토의 탐침(스크래치 `r4m6/verify2`, `verify3`)과 새 탐침(`r4m6/fix/probe`)으로 다시 낸 뒤 고쳤고, 고친 규칙마다 옛 동작으로 되돌리면 실패하는 시험을 붙였다(위 "측정"의 M6-fix 일부러 깨 보기). 임시값 값은 하나도 바꾸지 않았다(새 줄 넷, 기존 줄 다섯에 문구를 더함).

- 고침 (중간): 조제대 놓기가 그 순간 서 있는 몸만 봐서, 사람이 걷지 않고 나타나는 자리(던전 도착 칸 (38,15), 지상 도착 칸 (73,48), 제단 둘레 부활·참가 자리 아홉)를 덮을 수 있었다. 거기 도착하거나 부활한 사람은 막는 탁자 속에 서고(`can_stand` 거짓) 몇 쪽으로만 걸어 나갔고, 놓은 탁자는 지울 길이 없다. `WorldItems.reserved_feet`의 발 상자를 덮으면 `where players appear`로 거부(임시값 "M6-fix 조제대가 비워 두는 자리", 문서에 없는 선택이라 줄로, 영구라는 것도 적음). 시험: `_check_reserved_spots`(시드 1의 열한 자리마다 덮는 모든 자리를 옆 칸에서 놓아 봄: 놓인 것 0, 되돌리면 지상 도착점에 놓임). `brew` 세션의 조제대가 부활 자리 4 위였어서 (62..64, 50)으로 옮겼다
- 고침 (중간): 호스트의 CRAFT가 가장 가까운 작업대 하나만 보고(`at.kind != r.station` → `no station`), `station_near`는 조제대 3칸에 맞춘 창에서 자리의 왼쪽 위 칸만 봤다: M7의 둘째 종류·넓은 작업대에서 틀린다. `Crafting.station_of_kind_near`(그 종류 중 손 닿는 것)를 호스트가 쓰고, 찾기는 발 칸 둘레 2칸의 모든 칸에서 그 자리 전체를 잰다(크기 무관, 같은 거리는 줄 순서). `still_at`은 창을 연 그 작업대가 손 닿는지(다른 작업대가 더 가까워져도 닫히지 않음). 시험: 5칸 자리(2칸 = 있음, 3칸 = 없음), 종류로 찾기, 같은 거리, 연 작업대에 그대로. **시험으로 못 만든 것**: 종류가 둘인 경우(종류가 하나뿐: `STATION_OF`가 상수라 시험이 둘째 종류를 만들 수 없음. 되돌려 깨 보기도 통과한다. M7이 둘째 종류와 함께 시험을 더해야 한다, 알려진 문제)
- 일부 고침 (낮음): 제작 틀 안의 조제대·약초사 고정. 작업대 → 창 아이콘(`STATION_ICON`), 설치물 → 자리 크기(`WorldItems.FOOTPRINT_OF`, `place_rect`가 씀), 클래스 거부 문구를 레시피의 클래스에서(`Recipe.class_refusal`). **그대로 둠**: `FixtureView`의 탁자 그림, 제작 창의 줄 모양(입력 하나·약초사 주머니 표시 하나)·자리. README의 "M7은 값을 더하면 된다"를 고쳐 M7이 더할 것을 적었다(위 "제작 틀")
- 고침 (중간, README만): 버프가 걸린 조용한 클라이언트를 호스트가 직접 진행하면 그 상태들이 `vitals_corrections`로 셌다(M4b의 대시와 같은 셈, 창이 20~30초로 넓어짐). 고치는 길(호스트가 자기가 진행한 상태에 표시, 예측이 사건으로 셈)은 전송 형식을 바꿔서 하지 않고 README "M6b 예측"·알려진 문제·두 기기 해 보기 4번에 적었다. `Prediction.reconcile`의 "호스트가 직접 진행한 것도 사건" 주석이 틀려 고쳤다
- 고침 (낮음): 날아가는 병이 shaded라 빛 없는 던전에서 거의 안 보였다. unshaded로(터짐·표시·빛 탄과 같음). 창 그림 검사 `potions`가 저녁 켬에서 병·터짐 픽셀이 제 색인지 본다(되돌리면 92픽셀 FAIL). 두 창 그림을 다시 찍었다
- 고침 (낮음): README의 M6b 두 창 그림 설명이 그림과 달랐다(호스트 그림의 이단은 팔라딘이 이미 죽인 붉은 프레임이었다). 팔라딘이 2초 기다린 뒤 싸우게 다시 찍어, 두 그림 모두 독 걸린 이단(HP 막대·표시)과 날고 있는 병이 보이는 쌍을 골랐다(위 "스크린샷")
- 고침 (낮음, README): 독이 플레이어를 다운·사망까지 보낼 수 있다는 것을 임시값 줄로(새 "M6-fix 플레이어의 독", 다른 길 셋), "M6a 독"·"M6a 마시기"에서 가리킴
- 고침 (낮음): 효과가 지도를 옮겨도 이어진다는 것을 "M6a 효과 겹침·끝남" 줄에 적고 시험(`set_world` 뒤 같은 효과, 다음 틱에 계속 줄어듦)
- 고침 (낮음): `EFFECTS_END_ON_DOWN`을 끄면 마지막 독 틱에 다운된 사람의 독 피해·박자가 남아 소생 뒤 `has_effects()`가 늘 참이었다(늘 idle 아님, 효과 블록 40B가 계속). 독이 다 되면 생명 상태와 상관없이 지운다. 시험: 쓰러진 채 끝난 독(되돌리면 실패), 마지막 독 틱에 다운 → 소생 = 효과 없음(스위치 값과 무관)
- 고침 (낮음, README): §2.1 ○ "힐과 버프만 가까운 아군 자동 대상"과 다르게 회복·버프 병도 에임형이라는 것을 "M6a 투척" 줄의 문서 칸에 적음(자동 대상 길은 없음, 사람이 정함)
- 고침 (낮음): 이단의 독 틱이 던진 사람의 `hits`(무기 맞음)로 세고 `hit` 로그가 무기 맞음과 같았다. `Arena.Hit.poison`, `poison_hits`로 세고 로그 끝에 ` POISON`(처치는 그대로 `kills`). 시험: 독 처치 흐름에서 `hits` 0·`poison_hits` 2 이상, `brew`의 마지막 한 방 줄이 ` POISON KILLED`
- 고침 (낮음, README): 제작 창이 열린 동안 서 있고 막을 수 없는 것(맞아도 안 닫힘)은 설계 규칙이라 구현 표에서 임시값 "M6-fix 제작 창이 열린 동안"으로 옮김(값 그대로, 다른 길 둘)
- 고침 (낮음, 겹친 둘): 혼자 할 때의 던질 점이 float라 마우스가 사거리 밖이면 혼자와 호스트(정수 px를 다시 자름)가 최대 0.7px 달랐다. `Player.make_frame`이 정수 px로 만든다(전송 형식과 같은 값): 혼자 = 호스트. 시험: 공유 시뮬레이션 1,500틱의 마우스를 번갈아 사거리 밖·정수 아닌 점으로(사거리 밖 던지기 2번 이상, 병 위치 0.01px까지 같음, 되돌리면 58틱 어긋남), 던질 점 = 자른 점의 반올림. 빠졌던 시험: `the potion is gone`(효과 틱 전에 버린 물약), 같은 등급의 다른 묶음, `no arena`
- 고침 (낮음): 이름 없던 숫자(던짐 사건 거부 여유 1px, 병 경로 +2틱, 터짐 사건 없는 병을 잊는 1초, 터짐 안쪽 고리 0.55·돌림 0.3·0.4, HUD 효과 아이콘 간격 3px)에 이름을 붙이고 구현 표에(값 그대로). 낡은 주석 둘(`Arena.flask_advance` → `flask_points`, 인벤토리의 "제작은 M6b까지 혼자") 고침, 탭으로 이어 붙은 줄 둘(`protocol.gd`의 던짐 사건 검사, 시험의 `effects_close`)을 `\` 줄 잇기로
- 고침 (낮음): THROW와 Space를 한 프레임에 누르면 대시가 이겨 아무것도 안 던지는데 `ops_done`에 `throw`가 셌다(마시기·사용도 같음). 동작이 시작될 때만 센다. 시험: THROW + Space(대시 하나, `throw` 그대로, 병·물약 그대로, `throw` 수 = 던진 병 수)
- 고침 (낮음, README): 비운 지도의 날던 병(물약은 이미 쓰임, 터짐 없음)과 멈춘 독(돌아오면 다 들어감, 처음 던진 사람의 처치)을 임시값 "M6-fix 빈 지도의 병과 독"으로(정하지 않음: 지금 동작을 적고 다른 길 둘), "M4-fix 빈 지도" 줄에서 가리킴, 시험(아레나 단위)
- 고침 (낮음): 한 프로세스 리그의 그리기 검사가 클라이언트의 벽시계 `RemoteClock`으로 그려, 리그가 실제 시간보다 빨라 모두 쉬면 옛 상태를 계속 그렸다: "표시를 그림"은 끝나는 것을 보지 못했다. 시험이 리그 시간으로 그리고(`draw_at_rig_time`), 남의 버프 표시가 다운으로 끝나면 사라짐·늦은 참가자도 버프가 다 되면 사라짐을 본다(벽시계로 되돌리면 실패)
- 고침 (낮음): 무기로 죽은 이단에 독 필드가 남아 `HereticSim.poisoned()`가 참이었다(보내기·그리기는 `alive()`로 막혀 보이지 않음). 죽이면 독을 지우고 `poisoned()`는 살아 있을 때만. 시험 추가

### 검토 반영 (M4-fix, 2026-10-22)

M4(M4a + M4b) 검토 에이전트들의 지적 26개(겹친 것: 소생 순서 셋, 빛 가장자리 둘)와 처리. 하나씩 코드를 읽고 검토의 탐침(스크래치 `r4m4/verify2`, `verify3`)이나 새 시험으로 다시 낸 뒤 고쳤고, 고친 규칙마다 옛 동작으로 되돌리면 실패하는 시험을 붙였다(위 "측정"의 M4-fix 일부러 깨 보기 14개). 임시값 값은 하나도 바꾸지 않았다(새 줄 셋, 위 "임시값").

- 고침 (높음, 세 검토): 소생 시간을 F를 누른 사람 중 플레이어 순서(세션: 자리 번호)의 첫 사람으로 정해, 팔라딘 호스트(자리 0)와 성직자 클라이언트가 같이 누르면 5초 걸렸다(● §2.6 "성직자는 즉시"와 어긋남, 탐침 300틱). `Arena.reviver_for`가 손 닿는 소생자 중 가장 빠른 사람(같으면 앞사람)을 고르고, `CombatView`의 소생 막대도 같은 것을 쓴다. 시험: `test_combat`(팔라딘·성직자 두 순서, 첫 틱에 일어남), `test_net_combat` `_check_two_revivers`(팔라딘 호스트 + 성직자 클라이언트, 다운된 아처 호스트 옆의 클라이언트 둘 두 자리 순서: 모두 3틱 안)
- 고침 (높음): 조용한 클라이언트 규칙이 프레임 없는 틱을 쉬는 동안까지 세어, 1초 서 있다 맞은 클라이언트를 호스트가 다음 틱부터 직접 진행하고 그 뒤 온 클라이언트 프레임도 돌려 타이머가 두 번 흘렀다(호스트의 경직·무적·다운이 왕복만큼 일찍 끝나고 클라이언트는 `vitals_correction`, 탐침: 3틱 지연 host_steps 7·보정 2, 9틱 19·6, 실제 세션 보정 36). 함께 고친 중간 둘: 20~29틱마다 한 프레임만 보내면 호스트 진행이 시작되지 않아 다운이 20~30배 길었고(탐침: 1,890틱 뒤 다운 94틱째), 쉬는 동안 모은 토큰으로 프레임을 몰아 보내면 틱당 4개까지 돌아 경직 18틱이 5틱, 대시 쿨다운 40틱이 12틱이 됐다. 셋을 하나의 규칙으로 고침: 시간을 쓰는 동안(vitals 타이머 또는 몸 동작)의 시계 빚(호스트 틱 − 돌린 프레임), 빚 0이면 프레임을 다음 틱으로 미룸(`InputGate.put_back`), vitals가 돌 때 30틱을 넘으면 호스트가 진행, 쉬면 0(위 "클라이언트의 시계"). 시험: `_check_idle_then_hit`(3·9틱: 호스트 진행 0, 예측 보정 0), `_check_trickle_client`, `_check_burst_client`, 실제 세션 `fightlag`(왕복 120ms·손실 5%, 다섯 번 맞음: 호스트 진행 0, vitals 보정 0. 옛 규칙이면 호스트 진행 40·보정 11), 기존 `_check_silent_client` 그대로 통과. 검토가 낸 다른 방법(문턱을 왕복에서 정하기, 호스트가 진행한 만큼 클라이언트 프레임을 버리기)은 고르지 않았다: 빚을 쉬는 동안 세지 않으면 서 있다 맞은 정상 클라이언트의 빚은 왕복 + 묶음 간격뿐이라 30틱이 한 방향 약 200ms까지 덮고, 그 위로는 호스트 진행분이 호스트 상태에 들어가 예측이 한 번 받아들이면 그 뒤로 맞는다
- 고침 (높음): 아무도 없는 지도의 아레나가 멈출 때 예고 중인 공격도 그대로 멈춰, 계단으로 도망쳤다 돌아오는 사람(도착점 = 떠난 자리 옆)이 남은 예고만큼만 보고 맞았다(탐침: 돌아온 지 8틱, 지연 0이면 8틱 뒤 칼). 같은 원인의 중간·낮음 셋: 날던 화살이 얼어 있다가 다음에 온 사람에게 이미 끝난 것으로 보내져 안 보이는 화살이 날았고(born 기준), 혼자 할 때도 떠난 지도의 예고가 이어졌고, 비운 지도의 `attacks_started`가 남아 빈 지도의 적 묶음을 매 틱 만들었다. 마지막 사람이 떠날 때 한 번 비운다(`Arena.on_emptied`, 임시값 "M4-fix 빈 지도"): 공격은 칼 없이 끝·쉼 45틱, 경직 끝, 표적·지켜보기 잊음, 날던 화살 없앰, 스폰 시계 0부터, 급한 공격 수 0. 호스트(`_step_arenas`)와 혼자 할 때(`Main.step_combat`)가 같은 함수를 부른다. 시험: `test_heretic` `_check_emptied`(아레나 단위)와 `main.tscn`(입구로 내려갔다 올라옴: 예고 한 번 안에 안 맞음), `test_net_combat` `_check_leave_mid_windup`(던전 계단: 칼 없음·화살 없음·급한 묶음 없음·돌아온 뒤 예고 한 번 안에 안 맞음·클라이언트가 옛 화살을 안 그림)
- 고침 (중간): 화살·빛 탄을 발 → 마우스 쪽으로 쏘고 몸 점(발 2px 위) 8px 안에서만 맞혀, 그린 화살(바닥 점 12px 위)은 커서보다 약 14px 위를 날았고 이단 그림(발 위 28px까지)의 몸을 누르면 머리 위로 지나가 빗나갔다(탐침: 옆으로 40~120px, 발 위 10px 넘게 누르면 빗나감). 조준을 화살이 그려져 나가는 점(`Combat.aim_origin`)에서 재고, 맞음은 그린 화살이 그린 몸 상자 안(`Combat.shot_hits_body`, 발 좌우 8px·위로 28px)으로. 맞는지를 정하는 두 값(8, 12)은 구현 표에서 임시값 줄로 옮기고 28px를 더했다(임시값 "M4-fix 화살 조준·맞는 상자"). 봇은 이단 그림 가운데를 겨눈다(`Combat.body_centre`). 시험: `_check_shot_aim`(활·성광, 40·80·120px, 30°마다, 그림 위 2~26px를 누른 360발 모두 맞음, 옆으로 쏠 때 머리 6px 위는 빗나감. 조준을 발에서 재거나 옛 반경으로 되돌리면 실패)
- 고침 (중간, 낮음 하나 겹침): 빛 안의 플레이어가 빛 가장자리에서 기다리는 이단을 쏘면 맞을 때마다 지켜보기 4초가 처음부터라 이단이 집에 가지 못하고 죽을 때까지 맞았다(탐침 61발). 지켜보기 시간을 따로 세어(`HereticSim.watch_ticks`) 맞은 경직 동안도 세고 다시 세지 않는다: README의 "4초 바라보다 집으로"가 이제 참이다. 남은 것(빛 안에서 맞은 이단이 반응하지 않음, 집에 선 이단을 빛 안에서 칠 수 있음)은 정하지 않고 새 임시값 "M4-fix 빛 안에서 쏘인 이단"에 적었다(판정 기준 "빛이 안전으로 읽히는가"에 닿으니 사람이 정함). 시험: `_check_edge_sniping`(1초·2초마다 맞혀도 240틱 뒤 집으로)
- 고침 (중간): 이단의 제단 자리(`Arena.shrine_rect`)를 부를 때마다 맵 전체를 훑었고, 화살 한 걸음마다 두 번, 뷰는 매 틱 모든 지도에서 불렀다(탐침: 지상 한 번 139µs, 화살 27개면 한 틱 7.9~8.7ms). 자리를 기억하고(여섯 칸이 그대로인 동안), 뷰의 제단 노드도 한 번 찾고, 사람이 없는 지도의 뷰는 비울 때 한 번만 그린다. 같은 경우 한 틱 약 0.24ms(측정). 시험: 거울 아레나에 부서짐 편집이 한 칸씩 와도 기억한 자리가 따라감. **고치지 않음**: 클라이언트 `NetCombat.sample`의 매 프레임 할당(알려진 문제)
- 고침 (낮음): 화살이 2px 걸음마다 그 점의 칸만 봐서 모서리끼리 닿은 벽 사이로 빠졌다(탐침 5,824발 중 163발). 두 걸음 사이 칸을 모두 보고(`Combat.cells_on_line`), 걸음 사이 칸이 막으면 그 앞 점에서 멈춘다. 시험: 대각선 벽 줄에 1,625발, 넘어간 것 0(되돌리면 43)
- 고침 (낮음): 땅에 이미 `MAX_DROPS`가 있을 때 죽으면 드롭 없는 빈 가방이 생겼다. `too many drops`로 거부(가방 없음, 아무것도 안 잃음). 시험 추가
- 고침 (낮음): 지도에 다시 들어오면 멈춰 있던 스폰 시계가 이어져 들어오자마자 생길 수 있었다(README와 어긋남). 빈 지도 규칙으로 0부터. 시험: 479틱 뒤 떠났다 돌아오면 다음 틱에는 안 생기고 480틱 뒤 생김
- 고침 (낮음): 부활을 사망 틱이 정확히 `RESPAWN_TICKS`일 때만 알려, 그 틱이 지난 채 넘어온 사망 상태(던전에서 죽어 지상을 기다리던 클라이언트가 호스트를 잃고 혼자 계속)는 영영 죽어 있었다. 사망 틱을 거기서 멈추고 누가 부활시킬 때까지 매 프레임 알린다(호스트·예측·혼자 같은 규칙). 시험: 지난 사망 상태가 다음 틱에 부활 알림, 알림이 부활할 때까지 이어짐
- 고침 (낮음): 대시 중 TRAVEL이 받아들여지고 `set_world`가 대시를 지우지 않아 도착점에서 대시가 이어졌다. `set_world`가 대시를 끝낸다(구현 표 "오가기와 대시"). 시험 추가
- 고침 (낮음): `--test-shrine-hp`가 `SHRINE_HP`보다 크면 클라이언트가 그 던전의 적 묶음을 모두 잘못된 메시지로 거부했다. 1..`SHRINE_HP`만 받는다(CLI 오류). 시험 추가
- 시험 추가 (낮음): 세션에서 던전 사망(`_check_dungeon_death`: 지상 부활, 클라이언트도 지상, 가방은 던전, 예측 오차 0)과 지도를 받는 중의 부활(`_check_respawn_waits_for_stream`: 1바이트 조각, 받기가 끝난 뒤 부활)
- 고침 (낮음): 참이 될 수밖에 없던 시험 셋. (1) `test_combat`의 "리플레이가 같은 상태"가 base가 있는지만 봤다: 이제 1,418틱 뒤 기록한 프레임을 `Prediction._replay`로 다시 돌려 예측 상태와 `same_all` 비교. (2) `hp_mismatches`는 그 틱의 HP를 바로 기록해 부호화·전달만 본다: 메시지를 그렇게 고침(진짜 시험은 HP 순서 `_follows`). (3) 예고 대 지연 시험이 그리는 시각을 정해 준다: 고치지 않고 시험 주석과 README("판정", 알려진 문제)에 가정이라고 적음
- 고침 (낮음): 이름 없던 숫자(스폰 24번, 집으로 2px·1.5px·60틱, 걸음 축 0.5px, 지도 들어옴의 49, 제단 막대 30)에 이름을 붙이고 구현 표에 적음(값 그대로). README 고침: 던전 스폰 "14칸 넘게" → 이상(코드 `>=`), "160px 넘게" → 이상, "`DASH_SPEED`(40px)" → 240px/s·10틱에 40px, 소생 뒤 무적 줄을 임시값 표에(값 그대로)
- 고침 (낮음): M4b 두 창 캡처 명령이 클라이언트가 찍고 나가는 때에 기대어, 다시 찍으면 호스트 그림에 아처가 없을 수 있었다. 클라이언트에 `--keep-running --net-timeout=12`(위 "스크린샷"), 다시 찍음
- 일부 고침 (낮음): 예고 시험의 충실도. 지연·손실이 있는 실제 싸움 세션 `fightlag`(서 있는 클라이언트)를 더했다. 고치지 않음: 예고 시험을 `SessionClient.draw_others`와 흉내 시계로 돌리기, 지도 들어옴의 그리기 시간을 표에 넣기, `LinkSim`이 reliable도 늦추게 하기(README "판정"과 알려진 문제에 적음)
- 그대로 둠 (낮음): 예고가 맞붙은 플레이어 그림에 가려 읽기 어려움. 그림은 맞고(창 검사 픽셀까지), 쫓기를 사거리에서 멈출지·이단과 플레이어 사이에 간격을 둘지는 설계라 사람이 "혼자 M4 해 보기" 1번에서 정한다(알려진 문제)

### 검토 반영 (M3-fix, 2026-10-22)

M3(M3a + M3b) 검토 에이전트들의 지적 25개(겹친 것 셋 포함)와 처리. 하나씩 코드·탐침으로 다시 확인한 뒤 고쳤고, 고친 규칙마다 깨 보면 실패하는 시험을 붙였다(위 "측정"의 M3-fix 일부러 깨 보기 13개):

- 고침 (중간): 광부의 3×3이 깰 수 없는 칸(출구 계단 = 그 위 기반암 뚜껑)을 쳐도 둘레 바위를 깼다. 시드 1 도착점에서 계단 두 칸을 번갈아 세 번 치면 바위 13칸(뚜껑 뒤 4칸 포함)이 깨져 계단이 홀로 선 기둥이 되고 뒤로 걸어 들어갈 수 있었다(검토 탐침, 같은 결과를 다시 냄). README 두 곳은 반대로 적혀 있었다. `Mining.strike`가 친 칸(앞면이면 그 위 벽)의 경도가 클래스 상한을 넘으면 3×3 전에 `too hard`로 끝난다. 시험: `test_mining`(광부·공용이 계단을 여섯 번씩: 맞은 칸 0, 던전 해시 그대로), `test_net_maps`(호스트에서 광부가 계단 세 번: `too hard`, 편집 0)
- 고침 (중간): 벽 횃불이 맞지 않는 자리(통로가 뚫린 자리·광석·아래가 앞면이 아님)를 그냥 건너뛰어, 시드 1~400의 도착 방 중 82개(20.5%)에 벽 횃불이 없었다(다시 재 봄: 82 · 108 · 210). 도착 방은 `DUNGEON_DARK_COLOR` 0.13 어둠이다. 같은 벽의 가까운 자리로 옮기고, 자리가 있는 방은 하나 이상, 도착 방은 늘 하나 이상이 되게 했다(위 "던전 생성"의 "벽 횃불 자리"). 옮기기만으로는 도착 방의 3%가 여전히 어두웠다: 출구 계단이 아치 네 칸만 남은 벽에 놓여 다른 자리가 없었다. 그래서 출구는 횃불 자리가 남는 곳을 먼저 고르고, 도착 방 횃불은 광맥보다 먼저 단다(광맥은 그 칸만 건너뛰고 출발 목록과 난수는 그대로라 시드 1의 광맥 47칸·출구가 M3a와 같다. 처음엔 모든 횃불을 광맥 앞에 두었다가 시드 1의 광석 92칸이 바뀌어 시험·세션·스크린샷의 고정 칸이 흔들리므로 되돌렸다). 시드 1~3,000에서 도착 방 둘 95.5% · 하나 4.5% · 없음 0. 시험: 40시드에서 자리가 있는 방은 모두 횃불, 도착 방은 늘 횃불이고 자리가 있는 계단 쪽마다 그쪽에 하나. 생성기가 바뀌어 `GOLDEN_HASH`·`SEEDS_GOLDEN`이 바뀌었다(스모크 `hash=8dda0ad69ad9`, `dungeon_seeds=acc0a9bc2359`). 임시값 값은 그대로이고 줄의 설명을 실제 규칙으로 고쳤다
- 고침 (중간): F5 디버그 묶음이 횃불을 넣으며 24칸을 다 채워, 약초사가 묶음에 일반으로만 있는 `wild_buff`·`wild_poison`을 캐면 상급(● §3.4)이 들어갈 칸이 없어 `inventory full`로 거부됐다(오늘 밤 사람이 할 M2 확인 4번). 캔 광석도 모두 땅에 떨어졌다. 오염 쪽 돌 둘을 빼 22칸(2칸 빔)으로(구현 표 "디버그 묶음"). 시험: 묶음 뒤 빈 칸 2, 약초사가 묶음을 든 채 두 약초를 상급으로 캠
- 고침 (중간): 호스트를 잃고 혼자 계속하는 클라이언트(`continue_offline`)가 (a) 한 번도 내려가지 않았으면 입구 F로 데이터 없는 빈 던전으로 옮겨져 스크립트 오류 셋과 멈춘 화면이 됐고, (b) 세션이 만든 Player의 `action_impact`·`place_requested`가 Main에 이어지지 않아 캐지도 횃불을 놓지도 못했다(검토 탐침, 그 탐침으로 다시 냄). `Main.travel`이 데이터 없는 지도를 거부(로그 한 줄), `_on_local_player_ready`가 세 시그널을 잇는다(처리 함수는 세션 중에는 아무것도 안 한다. `_on_action_started`도 세션 중에는 찍지 않게 해 세션 로그는 그대로). 시험: `test_dungeon` `_check_offline_after_host_loss`(빈 던전에 F → 지상 그대로, 던전을 받은 경우 내려가 혼자 바위를 치고 횃불을 놓음). 검토가 낸 "drop 세션에 더하기"는 사람처럼 띄운 그 클라이언트에 봇이 없어 단위 시험으로 했다
- 고침 (낮음, 두 검토): 디버그 F7 드롭이 벽 속·앞면에도 됐다(설치물만 거부). 드롭이 벽 위에 그려지고 옆에서 주울 수 있었다. `WorldItems.drop`이 `Walls.blocks`도 `blocked`로 거부(횃불 놓기와 같음). 채굴이 깬 칸에 떨어뜨리는 드롭은 그대로다(깬 칸은 바닥이거나 새 앞면, 검토 탐침으로 아래 칸에서 주울 수 있음 확인됨). 시험: 앞면·바위 거부, 바닥은 됨
- 고침 (낮음): README의 M3b 두 창 그림 설명이 "랜턴 둘"이라 했지만 두 봇이 같은 칸(`aim:0,24`)을 겨눠 클라이언트의 횃불은 `not open floor`로 거부됐다(그림에도 랜턴 하나, 클라이언트 핫바에 횃불 3). 클라이언트 봇을 `aim:-20,24`(남서)로 바꿔 다시 찍었다(위 "스크린샷")
- 고침 (낮음, 두 검토): §3.1 경도 줄(●/○ 표시 없음)의 뒤 절반 "곡괭이 등급이 경도 이상이어야 파괴 … 상위 광석은 상위 곡괭이"를 클래스 상한으로 바꾼 것이 드러나지 않았고, 표시 없는 줄을 ○로 적었다. 임시값 "M3a 경도·타격" 줄, `Mining`·`config.gd` 주석에 "곡괭이 등급은 없다, 사람이 정한다"와 문서 줄 그대로를 적었다
- 고침 (낮음): 횃불의 묶음 99·종류 "놓는 것"과 "벽 횃불은 벽과 같이 떨어진다"가 코드에서는 임시값인데 표에 없었다. "M3a 횃불"·"묶음 크기" 줄에 올림(값 그대로)
- 고침 (낮음): 주석·README가 확인보다 많이 말한 곳 둘. `Walls.hardness` 주석의 "설치물을 단 벽도 깰 수 없음"(실제로는 막는 설치물 위의 벽만, 벽 횃불은 벽과 같이 깨진다)을 고침. `_show_map`의 "순서가 바뀌면 어둠이 흰색으로 풀린다"는 시험이 없고 검토가 순서를 바꿔 창에서 오가 봐도 차이가 없어서, 고른 순서라는 것만 남겼다(창 시험을 더하지는 않았다)
- 고침 (낮음): 시험이 없던 규칙 셋. (a) 횃불 USE의 요청 예산: `test_net_maps`에 한 틱 열 번(하나 놓고 3번 `not open floor`, 6번 `rate`). (b) `Mining.strike`의 손 닿는 칸 검사는 세션에서 걸릴 수 없다(사용 때 이미 보고, `ACTION_LOCKS_MOVEMENT`가 발을 묶음). 임시값을 끄면 필요해서 방어 검사로 두고, `_mine` 주석과 README에서 "out of reach" 이유를 뺐다. (c) 지도 들어옴의 `_show_others()`: 지도 들어옴 바로 뒤(`draw_others` 전)에 아래에 있던 호스트가 보이는지 본다
- 고침 (낮음): 스크립트로 고치다 줄 잇기(`\` + 줄바꿈)가 공백·탭으로 뭉개진 줄 넷(`player.gd`·`world_items.gd`·`game_world.gd`·`test_net_maps.gd`)을 되돌렸다. 원인은 검토가 짐작한 대로 고치기 스크립트로 보인다(M3 때의 스크립트는 남아 있지 않다. 이번 세션에서 Bash heredoc으로 넘긴 파이썬 문자열의 `\` + 줄바꿈이 줄 잇기로 사라지는 것을 실제로 봤다). 이번 고치기는 줄 잇기가 든 곳을 Edit 도구나 파일로 쓴 스크립트로 고쳤고, 끝에 `grep -P '\S \t'`로 0줄을 확인했다
- 고침 (낮음): `Main._on_local_map_changed`가 `player`가 null인지 보고도 출력에서 썼다. null이면 지도만 보이고 돌아간다
- 고침 (낮음): 도착점의 4px를 `Config.ARRIVAL_FEET_INSET_PX`(임시값 줄 "출구 계단과 도착점"에 적음)로, 던전 난수 섞기 `SEED_SALT`·`SEED_MULTIPLIER`를 IMPL로 이름 붙임(값 그대로, 해시 영향 없음)
- 고침 (낮음): `Walls.vertex`가 맵 맨 윗줄의 바닥을 앞면으로 그렸지만 걷기는 열려 있었다(그린 것 ≠ 막힘). 생성된 던전에는 없는 경우다. 꼭짓점의 앞면 = `Walls.is_face`로 맞추고(바닥으로 그림) 한 줄 시험
- 고침 (낮음): 결과용 기록(`streams_done`, `left_maps`)이 release에도 있고 TRAVEL에 쿨다운이 없어 오갈 때마다 끝없이 늘었다. 마지막 64개만 둔다(`NET_STREAM_RECORDS_MAX`). 편집 기록의 상한(던전 하나에 약 14.5MB까지)은 알려진 문제에 수로 적었다. TRAVEL 쿨다운은 임시값 "M3b 지도 오가기"(없음)를 바꾸는 일이라 넣지 않았다
- README만 고침 (낮음): 클라이언트가 떠난 지도에서 버리는 것은 편집 기록뿐이다(데이터·그림은 숨긴 채 남음). 예측 문장 둘("편집이 오면 다음 상태부터 맞는다", "막힐 수만 있다, 앞서지 않는다")은 실제 흐름에서 상태 하나 늦고, 편집이 상태보다 먼저 오면 잠깐 앞서 나갈 수 있어 검토의 실제 세션 수와 함께 고쳐 적었다. 벽이 캐릭터를 가릴 일이 없다는 말을 좁히고 창에서 사람이 보게 했다. 두 지도에 흩어졌을 때 트래픽(검토가 잰 실제 수), 편집 기록 상한, fallback이 열린 통로처럼 보이는 자리를 알려진 문제에 적음
- 고침 (낮음): `test_dungeon`의 던전 예측 시험은 같은 `PlayerSim`·같은 데이터라 결정성만 본다는 것을 시험 주석에 적었다(남이 깬 벽의 예측은 `test_net_maps`)
- 그대로 둠 (낮음): 지도 들어옴이 2초 넘게 늦을 때의 예측(프레임 상한), 남이 지도를 옮길 때 100ms 일찍 사라지고 나타나는 보간, fallback 코너를 막힌 모양으로 그리기. 이유와 고칠 방법은 알려진 문제에 적었다. 비대칭 순서 + 지연 + 남이 깬 벽 세션 시험도 더하지 않았다(알려진 문제)

### 검토 반영 (M2-fix, 2026-10-22)

M2b 검토 에이전트들의 지적 17개(겹친 것 포함)와 처리. 하나씩 코드·탐침·재현으로 확인한 뒤 고쳤고, 고친 것마다 깨 보면 실패하는 시험을 붙였다(위 "측정"의 M2-fix 일부러 깨 보기 15개):

- 고침 (중간): 발 칸이 발 점(그림 아래 끝)의 칸이라, 발이 타일 선에서 3px 아래까지일 때 목표 칸·표시·손 닿는 칸이 그려진 발보다 한 줄 아래였다. 스폰 자리 0·1(y = 760 + 8 = 768 = 48×16)이 그 자리라 처음 동·서로 조준하면 대각선 아래 칸이 표시됐다(커밋된 `m2_aim.png`, 두 창 로그 `target=61,48`로 확인). `Aim.feet_cell` = 발 상자 가운데의 칸으로 바꾸고 목표 칸·`in_reach`·사용의 바라보기가 모두 이것을 쓴다(호스트·예측·혼자 같은 함수). 시험: 발 칸 표(타일 선 위·아래), 4분의 1px씩 두 칸 높이 128곳에서 발 칸이 그려진 발 줄의 반 이상을 가짐, `main.tscn` 스폰 자리 0에서 동쪽 조준 = 발 픽셀 오른쪽 칸, 타일 선 위 발의 손 닿는 칸. 임시값 "조준 기준" 줄에 적음
- 고침 (중간, 두 검토): 서 있는 클라이언트가 조준만으로 돌 때 프레임을 기록하는 것과, 호스트의 인벤토리가 올 때 아직 처리 안 된 고르기를 다시 얹는 것에 시험이 없었다(검토가 둘 다 지워 봐도 통과). 단위 시험 둘(`_check_look_turns`: `Prediction` + `InputGate` + `run_frame`, 바라보기만 바뀐 틱만 기록·호스트도 같은 쪽 / `_check_inventory_rebase`: 진짜 `SessionClient.on_inventory`, 프레임에 실린 고르기·줄에 있는 고르기가 남고 ack가 덮으면 호스트 것)과 `pair` 세션의 c1 단계(고르기 3번, 휘두른 뒤 서서 남쪽 조준: 호스트·c1·c2 모두 남쪽)를 더했다. 둘 다 지워 보면 실패한다
- 고침 (중간·낮음, 두 검토): 호스트가 고르기를 `rate`로 거부하면 아무것도 돌려보내지 않아, 클라이언트는 예측한 칸을 들고 호스트·다른 사람은 다른 칸을 보았다(검토가 패킷 하나를 잃은 실제 세션·단위 탐침으로 재현). 고르기는 예산 밖으로(프레임당 하나, 월드를 바꾸지 않음), 그래도 거부된 고르기(`no such slot`)는 주인에게 인벤토리를 보내 바로잡는다. 받아 준 고르기는 아무것도 보내지 않는다(전에는 인벤토리 78B를 보냈다). "사람이 누른 것은 `rate`로 버려지지 않는다"는 "호스트가 제때 받으면"으로 고치고, 몰려 오면 줍기·버리기·주기가 거부될 수 있다고 적었다. 검토가 낸 다른 방법(예산을 호스트 틱 대신 프레임 시간으로)은 서 있는 클라이언트의 프레임 번호가 실제 시간을 따르지 않아 고르지 않았다
- 고침 (낮음, 두 검토): 클라이언트의 `--give` 개수가 1바이트라 300이 44로, 256이 0(`unknown item`으로 거부)이 되었고, 기다리는 요청 줄이 코드 안 16에서 말없이 버렸다. 255씩 나눠 보내고(`Main.give_requests`), 줄은 `Config.NET_LOCAL_OPS_MAX` 64(넘으면 `request_dropped` 줄), 개수 0은 `bad count`. CLI에서 255 넘는 수를 거부하는 방법은 혼자·호스트에서 되는 수를 막게 되어 고르지 않았다
- 고침 (낮음): 호스트가 사용의 목표 칸은 검사했지만 프레임의 look과 맞는지는 보지 않아, 서쪽을 보며 동쪽 칸을 칠 수 있었다. 동작을 시작할 때 look이 목표 칸 쪽이 아니면 칸 쪽을 본다(`Aim.use_facing`, `PlayerSim.step` 안이라 호스트가 정하고 예측도 같다. 정상 클라이언트의 look은 늘 칸 쪽이라 바뀌는 것이 없다. 마우스가 정확히 발 위일 때만 다를 수 있었다)
- 고침 (낮음): 동작 중에도 표시가 마우스를 따라가 치는 칸을 떠났다. 동작 중에는 `action_cell`에 그린다(시험: 휘두르는 도중 마우스를 서쪽으로). **그대로 둠**: 조준하지 않을 때(표시가 숨었을 때) F·F7이 쓰는 칸. 지금도 목표 칸은 매 틱 마우스 커서 쪽으로 갱신되므로(커서는 보인다) "보이지 않는 칸"은 아니지만, 조준하지 않을 때 F가 앞(바라보는 쪽) 칸을 써야 할지, 표시를 늘 보일지는 설계 결정(○ gameplay-design §1 "F 상호작용", §3.4)이라 정하지 않고 알려진 문제에 적었다
- 고침 (낮음): README의 낡은 수(`four` 18조각·세 틱, 늦은 참가 편집 위치 3), M1의 "바라보기는 보내지 않는다"·코드 0..8 문장과 규칙·구현 표 줄에 "M2b에서 바뀜", 스모크 주석의 없는 검사, `test_aim`의 창 크기 비교는 헤드리스에서만(창에서는 OS 커서를 읽음. 진짜 마우스는 사람 확인)
- 고침 (낮음): 내보낸 release 호스트가 클라이언트의 디버그 버리기(F7)를 받아, 버리고 줍기를 되풀이하면 편집 기록이 끝없이 늘었다. 클라이언트 버리기도 주기와 같은 조건(`drop off`). 호스트 자신의 F7과 허용된 빌드의 편집 기록은 여전히 줄지 않는다(알려진 문제)
- 고침 (낮음): 같은 틱 경주 "자리 번호가 작은 쪽"을 `SessionHost.tick`으로 시험하지 않았다(손으로 자리 순서대로 불러서 늘 참). 게이트에 자리 2의 프레임을 먼저 넣고 `tick`을 돌려 자리 1이 갖는지 본다(거꾸로 처리하게 깨면 실패)
- 고침 (낮음): 조준 없이 600틱 M1과 같음 시험이 같은 `PlayerSim.step`끼리 비교했다. M1 규칙을 테스트에 따로 적어 비교하고(대각선 틱 100 넘게), README 문장도 고쳤다
- 일부 고침 (낮음): 거부된 사용은 예산을 쓰지 않고 거부마다 로그 한 줄이라 매 프레임 보내면 초당 60줄. 로그를 플레이어·이유마다 처음 8줄 + 60번째마다로 줄였다(카운터는 모두 셈). 거부된 사용에 예산을 물리지는 않았다: 그러면 정상 세션의 이유(`busy` 등)가 `rate`로 섞이고, 남는 비용은 검사 한 번과 정수 하나다
- 고침 (낮음): 호스트의 `too many drops` 거부에 시험이 없었다. `MAX_DROPS`개를 깐 월드에서 버리기 거부 + 그 월드의 스냅샷 왕복·압축
- 고침 (낮음): 요청 줄 상한 16과 `GATHER_EDGE`가 표시 없는 상수였다(`Config.NET_LOCAL_OPS_MAX` IMPL, `Config.GATHER_EDGE_TILES` PROVISIONAL, 값 그대로라 월드 해시 같음, 표에 적음). 돌을 채집물로 흩는 것은 문서에 없고 04-env 묶음 이름에서 온 에이전트 선택이라고 표와 `config.gd`에 바로 적었다

### 검토 반영 (H-fix, 2026-10-22)

H1 검토 에이전트들의 지적 14개와 처리. 하나씩 직접 재현하거나 코드로 확인한 뒤 고쳤다:

- 고침 (높음·중간, 두 검토가 같은 것을 지적): 호스트 멈춤 따라잡기가 실제 세션에서 듣지 않았다. 재현: 2프로세스, 호스트 0.7초 멈춤(물리 틱 밖) → 속도 제한 204틱, 대기열 최고 42. 원인과 고침은 위 "호스트가 멈췄다 돌아올 때"(멈춤 크레딧 + 틱당 4프레임). 단위 시험을 두 순서로 바꿨고(틱 밖 순서는 H1 코드에서 실패: 대기열 31, 제한 409), 실제 세션 시험 `stall`과 테스트 전용 봇 `stall:<ms>`를 더했다. 검토가 낸 다른 방법(호스트가 틱 처음에 직접 네트워크를 읽기)은 RPC 처리가 물리 틱 안으로 들어오고 보내는 시점도 바뀌어서 고르지 않았다
- 고침 (중간): 실제 시간 시계 계산을 시험하는 곳이 없었다. `InputGate.ticks_between`으로 빼서 가짜 시각으로 단위 시험(60Hz 프레임 = 1틱, 같은 시각 = 0, 거꾸로 = 0, 그 시계로 두 배 보내는 클라이언트도 실제 시간 + 30)하고, 모든 세션에서 게이트마다 채운 시간이 호스트 틱 수를 따라가는지 본다(1000배로 깨면 세션도 실패)
- 고침 (중간): 테스트 포트 확인이 `*` 하나라 IPv4만 잡은 프로그램을 못 봤다. 재현: 0.0.0.0·127.0.0.1을 잡은 소켓을 `*` 확인이 통과. 세 주소로 확인하고 `test_core`가 IPv4만 잡은 소켓 두 가지로 시험
- 고침 (낮음): `--port-base` 묶음을 못 잡으면 `FAIL (startup)`을 찍고도 쥐지 않은 기본 묶음으로 모든 파일을 돌렸다. 이제 아무 파일도 돌리지 않고 끝난다(`test_core`가 자식 러너로 시험)
- 고침 (낮음): 스냅샷 크기 상한 2048은 받을 수 없는 크기였다. 512로(위 "늦은 참가"), 접속 제한에 걸린 이유를 "월드를 다 받지 못함"과 구분, 알려진 문제에 적음
- 고침 (낮음): 여러 걸음을 적용한 틱을 두 끝 사이 직선으로 그려 제단 안을 지날 수 있었다. 두 걸음 넘는 틱은 끝에 그린다(시험: 직선은 제단을 지나고 그림은 늘 끝)
- 고침 (낮음): README 측정값이 다시 재면 안 나왔다. 여러 번 잰 범위와 기기 흔들림을 적고, pair 0/2가 두 값으로 갈리는 원인(늦은 참가자의 연결 인사, 잼)과 1초·1.7초를 넘는 멈춤의 한계(모형으로 잼)를 적음
- 고침 (낮음): 호스트가 틱당 8조각을 지키는지 세션 시험이 없었다. 호스트가 스트림마다 조각 보낸 틱 수를 결과에 남기고 모든 세션에서 ⌈조각/8⌉인지, `four`의 c4는 2틱인지 본다(M2b부터 18조각·3틱)
- 고침 (낮음): 받는 도중 편집 길을 지나는 시험이 없었다. `stall` 세션 뒤쪽(1바이트 조각, 4틱마다 편집 60번, welcome 뒤 편집 10~11개)
- 고침 (낮음): 늘 참인 검사 셋. "packed world md5 = content hash"는 뺌, "chunk count"는 기본 조각 크기로 돌아왔는지로 바꿈, 무작위 바이트 시험은 크기·md5가 맞는 조각으로 넣어 실제로 풀기 단계까지 가게(2,000번 중 1,500번 넘게 거기서 거부되는지 셈)
- 고침 (낮음): check_render.gd 352줄의 탭 다섯 개를 줄 잇기로
- 일부 고침 (낮음, 선택): 클라이언트의 생성기 해시는 welcome에서만 정함(전에는 거부된 클라이언트가 자기 시드 월드 해시를 적음), 진단 시드는 스냅샷 머리말에서 가져오고 welcome의 시드 칸(8B)을 뺌(같은 v2 안: 아직 main에 머지 안 된 형식). 참가 클라이언트가 시작할 때 자기 시드로 월드를 만드는 것은 그대로 둠(이유는 알려진 문제)
- 검토 밖에서 찾아 고침: `stall` 세션이 가끔 실패(걷는 클라이언트가 4초 동안 상태 묶음 5개). ENet 패킷 조절이 원인이라 계측으로 확인하고 껐다(위 "네트워크")
- 늦은 참가자의 연결 인사를 "joining" 묶음으로 옮기지는 않았다(호스트가 peer를 알기 전의 바이트라 통계를 몇 틱 늦게 나눠야 한다). 원인을 재서 설명만 적었다(검토가 낸 두 방법 중 하나)

### 검증 반영 (2026-10-22)

검증 에이전트의 지적과 처리:

- 고침 (중간): 러너가 마지막 파일 뒤에 난 오류를 세지 않아 PASS·종료 0으로 끝날 수 있었다. 이제 마지막 파일 뒤 10프레임을 기다려 `FAIL (after the last file)`로 센다. 파일이 루트에 남긴 노드는 그 파일의 실패로 세고 러너가 지운다(늦은 오류가 다음 파일 탓이 되던 주된 길). 파일 사이 오류에는 앞 파일 이름을 붙인다. 정리 뒤 기다림은 1프레임 → 3프레임(1 + `SETTLE_FRAMES` 2)
- 고침 (낮음): 통과하는 실행의 알린 오류 묶음 7개를 위 "전체 테스트"에 모두 적음. 스폰 방향을 `Config.SPAWN_FACING`(임시값)으로 빼고 `SPAWN_SLOTS`에 "자리는 IMPL, 제단 둘레 스폰은 임시값"을 적음. 임시값 표 머리말을 "대부분 config.gd, 아닌 줄은 코드 칸"으로 고침. 오염 구역 수의 ●를 ○로(문서 §12는 "제안" 절의 표시 없는 줄). 카메라 가장자리 멈춤을 임시값 표에 올림(● gameplay-design §1과 가장자리에서 다름). 시드 1 월드 해시를 `SurfaceGen.GOLDEN_HASH`로 옮겨 스모크도 비교하게 하고, "모든 기기에서 같다"를 "x86_64에서만 확인"으로 고침
- 그대로 둠: 해시 고정값이 옳음을 증명하지 않는다는 지적은 맞지만 고정값의 일은 변화 감지다(옳음은 40시드 규칙 검사). 설명만 고쳤다

알려진 문제·남은 일:
- (M5c) 위 "M5c: 세션의 농사 · 정화 · 제단"의 "알려진 문제 (M5c)"
- (M6-fix) 버프·독이 도는 클라이언트가 30틱 넘게 조용하면(창 끌기, 한 방향 약 267ms 넘는 지연으로 서 있다 버프를 받음) 호스트가 직접 진행하고 그 상태들을 예측이 `vitals_corrections`로 센다(M4b의 대시·경직과 같은 셈인데 창이 20~30초로 넓다). 상태는 맞춰진다. 고치려면 호스트가 자기가 진행한 상태에 표시를 달아야 해서(전송 형식) 하지 않았다. 그래서 `vitals_correction`·`host_steps` 로그는 정상 연결에서만 깨끗한 신호다(위 "M6b: 세션의 제작 · 물약"의 "예측")
- (M6-fix) 호스트의 제작 검사가 "그 레시피 종류의 작업대 중 손 닿는 것"인지는 종류가 하나뿐이라 시험으로 못 만든다(`Crafting.STATION_OF`가 상수). 같은 거리·큰 자리·종류로 찾기는 시험한다. M7이 둘째 종류를 더할 때 그 시험(종류가 다른 작업대가 더 가까워도 받음)도 더한다. 제작 창은 Tab 때 가장 가까운 작업대의 것만 연다
- (M6-fix) 제작 틀에서 아직 조제대·약초사만 아는 곳: `FixtureView`의 탁자 그림, 제작 창의 줄 모양(입력 하나, 클래스 표시는 약초사 주머니 하나)과 자리(위 "제작 틀"의 "M7이 새 작업대에 더할 것")
- (M6-fix) 조제대가 비워 두는 자리는 사람이 걷지 않고 나타나는 자리(도착점·부활 자리)뿐이다. 길을 막는 것(도착점 바로 옆을 막아 한쪽으로만 나가게 하기 등)은 그대로 된다(서로 붙지 못해 한 칸 틈은 늘 남는다)
- (M6-fix) 비운 지도의 날던 병은 그 물약과 함께 사라지고, 멈춘 이단의 독은 누가 돌아오면 남은 만큼 들어간다(그 처치는 떠났을 수도 있는 처음 던진 사람의 것). 화살의 "쏘고 계단으로 내려가면 화살이 사라짐"과 같은 길(임시값 "M6-fix 빈 지도의 병과 독")
- (M6b) 버프·독이 도는 플레이어는 서 있어도 쉬지 않는다: 효과가 타이머라(`Vitals.idle`, 호스트 시계) 클라이언트가 매 틱 프레임을 보내고(입력 약 300 B/s) 그 사람의 상태(40B)가 20Hz로 모두에게 간다. 잰 값(한 프로세스, 서 있는 셋 중 하나가 상급 버프): 호스트 → 클라이언트 둘 3,160 B/s, 쉬면 0. 버프가 20~30초라 그동안 걷는 것과 같은 트래픽이다(9인이 모두 버프면 9인 걸음과 비슷, M3b 28 KB/s). 줄이는 길(효과의 끝을 호스트 틱으로 보내고 걸음과 따로 세기)은 예측 규칙을 바꾸므로 하지 않았다(M4b의 "다운된 플레이어 20Hz"와 같은 알려진 문제)
- (M6b) 서 있던 클라이언트에 버프가 걸리면(던진 병) 그 사실을 알고 프레임을 보내기 시작할 때까지(왕복 + 묶음 간격) 호스트에서 그 버프가 줄지 않는다: 그만큼 늦게 끝난다(M4-fix의 "서 있다 맞은 경직"과 같다). 30틱(약 0.5초) 넘게 늦으면 호스트가 직접 센다
- (M6b) 자기 병은 예측하지 않는다: 던지는 동작은 바로, 병은 호스트의 던짐 사건이 와야(왕복 뒤) 손에서 나타난다(화살과 같음). 벽에 막힌 자기 병은 터짐 사건이 오기 전 한두 프레임 벽 쪽으로 더 날아 보일 수 있다(자기 것은 아는 가장 새 시각에 그리므로). 제작·놓기도 왕복 뒤에 보인다(예측하지 않음)
- (M6b) 클라이언트의 해금 기억은 받은 인벤토리에서 온다: 호스트가 한 틱 안에 넣었다 뺀 아이템(지금은 그런 길이 없다)은 클라이언트 창에 그 줄이 안 보일 수 있다(호스트는 받아 준다. 거꾸로 더 보이는 일은 없다)
- (M6b) `brew` 세션은 봇이 틱 수(wait)로 서로를 맞춘다(호스트가 c1이 빛 가장자리에 선 뒤에 던지게 약 100틱 여유). 아주 느린 기계에서 어긋나면 시험이 실패로 알린다
- (M6b) 전체 테스트가 약 290초가 됐다(`brew`·`brew4` 약 55초 더함). README의 전체 테스트 명령 `timeout`을 600으로 올렸다
- (M6a, M6b에서 풂) 세션에서는 제작·마시기·던지기·효과가 꺼져 있다(M6b). 효과는 `Vitals`·`HereticSim`에 있지만 전송 형식(vitals 블록, 적 묶음)과 `Vitals.idle`·`at_rest`에 아직 없다: M6b가 세션에서 켜면 블록에 효과 다섯 필드, 적 묶음에 이단의 독, 던진 병의 사건(화살처럼), 효과가 도는 동안 `idle` 거짓(호스트 시계)을 같이 더해야 한다(지금 세션에서 효과가 생기면 클라이언트는 그것을 받지 못해 예측이 어긋난다)
- (M6a) 조제대는 디버그로만 생긴다(`--give=alchemy_table`, 임시값 "M6a 조제대 얻기"). F5 묶음에도 없어 사람이 해 볼 때는 위 "실행"의 명령을 쓴다
- (M6a) 조제대 자리는 3×1이라 뒤 판·병이 걸친 위 칸에 서면 캐릭터가 탁자 뒤에 그려진다(이단의 제단·입구와 같은 3/4 규칙). 그 칸을 지나는 화살은 탁자 그림을 지나 날아간다(막는 것은 자리 칸뿐)
- (M6a) 놓은 조제대는 다시 줍거나 부술 수 없다(횃불처럼, 문서에 없음). 디버그로 잘못 놓으면 새 월드에서 다시. M6-fix: 그래서 사람이 나타나는 자리(도착점·부활 자리)는 덮지 못한다(임시값 "M6-fix 조제대가 비워 두는 자리")
- (M6a) 마시기는 마법 동작을 빌려 쓴다(마시는 그림 없음): 성직자의 성광과 같은 몸짓이라 마시는 것으로 잘 안 읽힐 수 있다. 그림이 생기면 `Config.DRINK_ANIM`과 시트를 바꾼다
- (M6a) 독은 HP만 깎아 경직이 없어서, 독에 걸린 이단은 맞은 깜빡임만 보인다. 머리 위 독 표시는 이단 HP 막대 위라 맞붙은 플레이어의 머리와 겹쳐 보일 수 있다
- (M6a) 제작 창은 오른쪽 위에 고정이라 화면 오른쪽 끝의 조제대(카메라 가장자리)에서는 탁자를 가릴 수 있다. 줄이 많아지면(M7) 스크롤이 필요하다(여섯 줄에 142px)
- (M6a) 레시피 해금은 플레이어의 인벤토리에 붙어 있고 저장되지 않는다(다시 시작하면 다시 잠김). 세션의 클라이언트 인벤토리는 호스트가 보낸 사본이라 해금 기억이 없다(M6b: 받은 인벤토리에 든 것을 기억한다, 위 M6b 줄)

- (M4b) 판정은 호스트 시간이다(되감기 없음): 예고를 보고 피할 시간이 왕복 지연만큼 준다(한 방향 100ms면 300ms, 150ms면 200ms, 위 "판정"). 화면의 이단은 위치가 100ms + 한 방향 지연 뒤라 걷는 이단을 노린 근접은 그만큼(3틱 지연에서 최대 6.9px) 어긋날 수 있다
- (M4b) 자기 화살·빛 탄은 예측하지 않는다: 쏘는 동작은 바로 보이지만 화살은 호스트의 사건이 와야(왕복 뒤) 출발점에서 나타난다. localhost에서는 한두 프레임
- (M4b) 이단은 걷다 멈춰 공격할 때 100ms 동안 미끄러지며 공격 프레임을 시작한다(예고를 바로 그리는 대가). 공격이 끝났는데 지연된 위치 표본이 아직 공격 안이면 그동안 쫓는 그림이다
- (M4b) 다운된 플레이어는 30초 동안, 죽은 플레이어는 5초 동안 상태가 매 틱 바뀌어 상태 묶음이 20Hz로 나간다(걷는 것과 같은 트래픽). 맞은 플레이어는 HP가 차지 않으므로 그 뒤로 상태가 33B(쉬지 않는 vitals 블록)
- (M4b, M4-fix에서 고침) 클라이언트의 시계는 이제 호스트 시간에 묶인다(위 "클라이언트의 시계"). 남는 것: 서 있던 클라이언트가 맞으면 그 사실을 알고 프레임을 보내기 시작할 때까지(왕복 + 묶음 간격) 호스트에서 그 플레이어의 경직·무적이 멈춰 있다가 이어진다(왕복만큼 늦게 끝남, 걷던 클라이언트는 그렇지 않다). 한 방향 약 200ms를 넘는 회선에서 서 있다 맞으면 빚이 30틱을 넘어 호스트가 몇 틱 진행하고 클라이언트는 `vitals_correction`을 한 번 받는다(그 뒤로는 맞음). 시간을 쓰는 동안(타이머·몸 동작)은 밀린 프레임을 그 동안 쌓인 호스트 틱만큼만 따라잡는다: 그 전부터 지터로 밀려 있던 몇 프레임은 타이머·동작이 끝날 때까지 남는다(그만큼 남의 화면에서 늦음)
- (M4-fix 검토, 사람이 볼 것) 예고(칼을 든 그림)가 맞붙으면 잘 안 읽힌다: 이단은 22px에서 공격을 시작하고 16px쯤까지 다가오며 플레이어와 겹칠 수 있어, 동·서쪽에서는 든 칼(뼈 색)이 플레이어 그림 위·뒤에 그려지고, 저녁 빛 밖에서는 이단과 칼이 어두운 회색이라 480×270에서 0.5초 예고가 잘 안 보인다(남쪽에서만 머리 위로 보임). 그림 자체는 맞다(창 검사 `heretic` 픽셀까지 같음). 사람이 "혼자 M4 해 보기" 1번에서 보고 정한다. 임시값으로 할 수 있는 것: 공격 사거리에서 쫓기를 멈추기, 이단과 플레이어 사이 간격
- (M4-fix 중에 봄) M4b 그대로의 코드로 돌린 전체 테스트 한 번에서 `test_actions.gd`의 "marker on the target tile"(`main.tscn`에 마우스 이벤트를 넣고 곡괭이를 쓴 뒤 목표 칸 표시 자리)이 실패했다. 그 파일만 세 번, 전체 네 번은 통과해 다시 내지 못했다. 앞 파일이 남긴 입력 상태나 프레임 순서에 따른 흔들림으로 보이며 원인은 찾지 않았다
- (M4-fix 검토, 고치지 않음) 클라이언트 `NetCombat.sample`이 매 프레임 이단마다 `HereticSim`, 화살마다 `Arena.Shot`을 새로 만든다. 9인·이단 여럿에서 클라이언트 프레임 시간은 재지 않았다(위 "M4b에서 확인하지 않은 것")
- (M4b) 호스트를 잃은 클라이언트는 혼자 계속하면서 혼자 할 때의 아레나를 새로 만든다: 호스트의 이단은 사라지고 그 지도의 스폰부터 다시 시작한다(다운·사망 중에 잃으면 그 상태에서 혼자 할 때 규칙으로 이어짐)
- (M4b) 같은 클래스 소생 진행 막대: 남의 화면에서 소생 진행은 늘 5초 기준으로 그린다(누가 소생하는지 클래스를 보내지 않음. 성직자는 즉시라 막대가 거의 안 보인다)
- (M4b) 실제 세션 시험(`fight`)은 봇이 그리는 이단을 겨눠 싸운다. 한 기기 localhost라 지연·손실은 한 프로세스 시험(고정 지연)으로만 쟀다. 두 기기·먼 회선에서 예고·대시의 손맛은 사람이 본다. M4-fix: 지연·손실이 있는 실제 세션 `fightlag`(왕복 120ms, 5%)를 더했지만 서 있는 클라이언트가 맞는 것만 본다(피하기는 한 프로세스 시험만). `LinkSim`은 unreliable(입력·상태·적 묶음)만 늦추고 잃는다: 적 키프레임·화살 사건·편집은 지연 없이 간다
- (M4-fix 검토, 알려 둠) 예고 대 지연 시험(`_check_telegraph_window`)은 클라이언트가 그리는 시각을 "호스트 틱 − 지연"으로 정해 준다(`RemoteClock`을 거치지 않음). "예고를 본 때"는 잰 값이 아니라 그 가정에서 나온 값이다. 지도에 막 들어온 클라이언트는 지도를 그리는 시간(던전 약 57~70ms)만큼 더 늦게 본다(표에 없음)
- (M4a, M4b에서 풂) 세션에서는 전투가 없다: 적·피해·대시·시작 무기·가방이 혼자 할 때만이다(M4b). 입력 프레임의 대시·F 누르고 있기·조준 코드와 Vitals는 아직 전송 형식에 없다. 가방·부서진 제단은 지금의 월드 편집(설치물 칸, 드롭)이라 그대로 보낼 수 있다
- (M4a) 이단은 길을 찾지 않는다(8방향 직선 + 벽 미끄러짐). 벽 뒤의 표적에게는 막혀 서 있고, 빛 테두리를 가로질러야 닿는 표적이면 테두리에서 멈춘다(시험이 그렇게 확인한다). 던전의 L자 통로에서는 시야(벽 없이 112px)가 끊겨 금방 포기한다
- (M4a) 이단끼리, 이단과 플레이어가 겹칠 수 있다(충돌 없음, 플레이어끼리와 같음). 공격 사거리 22px라 맞붙으면 그림이 거의 닿는다(`m4_surface_heretic.png`)
- (M4a) 혼자 할 때는 소생을 볼 방법이 `--test-ally=<클래스>:down`뿐이다(동료 노드는 입력이 없다). 소생하는 사람의 바라보기는 바뀌지 않는다(F만 누름)
- (M4a) 다운·누운 몸에서 표식을 숨겨서 누가 쓰러졌는지 표식으로 읽을 수 없다(임시값 "쓰러진 몸의 표식"). 피격 시트에는 표식을 기준점대로 붙였다(사람이 창 검사 `--save`로 볼 것)
- (M4a) 맞은 깜빡임은 붉은 곱하기(코드)라 두 캐릭터가 같이 맞으면 둘 다 붉어진다. 화살은 코드 그림을 각도대로 돌려서 대각선이면 픽셀이 계단진다
- (M4a) 스폰은 플레이어가 있는 지도만 흐르고, 내가 떠난 지도의 이단은 그 자리에 멈춘다(M4-fix: 떠날 때 공격·경직·표적·날던 화살은 비운다, 위 "빈 지도"). 그래서 세션에서 지상에서 화살을 쏘고 바로 입구로 내려가면 그 화살은 사라진다(맞을 것도 안 맞음). 혼자 할 때 부활은 스폰 자리 0이 비었는지 보지 않는다(더미가 서 있지 않은 자리)
- (M4a) 지상의 오염 구역이 시드 1에서 제단 빛에서 약 20칸 밖이라(가장 가까운 재 칸이 가운데에서 약 27칸) 이단을 빛 가장자리까지 꾀어 오려면 한참 걸어야 한다. "빛이 안전으로 읽히는가"를 사람이 해 볼 때 동선이 길다(스폰 범위는 임시값)
- (M4a) 켜 본 시험이 없는 임시값 스위치: `TORCH_LIGHT_IS_SAFE` 켬, `HERETIC_ENTERS_LIGHT` 켬, `FRIENDLY_FIRE` 켬(코드는 있다), `HERETIC_HURT_INTERRUPTS_ATTACK` 켬. 무작위 3종 규칙(`DEATH_DROP_KINDS`)은 규칙 함수만 시험했다(`main.tscn` 경로는 절반 규칙)
- (M4a) 가방의 드롭도 땅의 드롭 상한 `MAX_DROPS` 256을 같이 쓴다(넘치면 일부는 인벤토리에 남는다)
- (M4a) 시작 무기가 핫바 8번이라 처음에는 빈손이다(Q 한 번). 스크린샷은 화면 프레임 수로 찍어 물리 틱과 한두 틱 어긋날 수 있다(같은 명령도 조금 다른 순간)
- (M4a) `--test-at`·`--test-heretic`·`--test-down`·`--test-ally`·`--test-shrine-hp`, 봇 `dash`·`hold`는 내보낸 빌드에도 들어 있다. M4b의 `--test-no-spawns`·`--test-start-hp`·`--test-dungeon-heretic`와 봇 `aimfoe`·`fight`·`closein`·`waitfoe`·`waitlife`·`waitdown`·`walkdown`도 그렇다(호스트의 `--test-start-hp`는 다른 사람의 HP를 바꾸니 사람이 쓸 일은 없다)

- (M3a) 바위 윗면의 금(`wall_crack_top_v01`) 1·2단계는 어두운 바위 위의 어두운 선이라 1배·어둠 속에서 거의 안 보인다(앞면의 금은 보인다, `m3_miner_mining.png`). 그림을 밝게 할지, 금을 다르게 보일지는 사람이 본다
- (M3a) 절벽 셋에 없는 코너 조합(앞면 바로 아래 벽 윗면, 한 줄 차이로 끝나는 이웃 벽)은 가까운 타일로 그려서 앞면이 짧게 끊기거나 이웃 칸과 한 줄 어긋난다. 생성된 던전에는 드물고(40시드에 19칸) 마구 판 뒤에는 많다. 그 조합의 타일을 더 그릴지는 그림 쪽 일이다
- (M3a) 앞면 칸이 막혀서 가로 굴은 두 줄이어야 들어간다(공용 클래스는 앞으로 한 칸 갈 때마다 두 칸을 판다). 앞면이 24px(1.5칸)인 그림에서 나온 것이라, 앞면 칸을 걷게 하면 캐릭터가 앞면 위에 떠 보인다. 사람이 해 보고 정한다(임시값 "앞면 칸이 막힘")
- (M3a, M3-fix에서 풂) F5 묶음이 24칸을 다 채워서 F5 뒤에 캔 광석은 드롭으로 떨어지고, 약초사가 처음 캔 상급 `wild_buff`·`wild_poison`은 `inventory full`로 거부됐다. 이제 묶음은 22칸이다(위 "실행"). 2칸이 다 차면 그 뒤로는 다시 같은 일이 난다(가득 찬 인벤토리 규칙)
- (M3a) 횃불을 다시 줍지 못하고, 하나하나가 `PointLight2D`라 바닥 사분면(128px) 하나에 빛이 15개 넘게 닿으면 넘는 빛은 그 사분면을 비추지 않는다(스파이크 RESULTS §4). 횃불 빛의 단계 모양(딱딱한 네 겹 원)은 임시다
- (M3a) 출구 계단은 임시 그림(아치 + 뒤집은 내려가는 계단)이다. 벽 횃불 불꽃은 늘 켜져 있고(이단의 불이 아니라 공유 불꽃), 이단의 제단은 불이 꺼진 그림이다
- (M3a, M3b에서 풂) 세션은 던전이 없었다(입구 거부). M3b에서 세션도 오가고 캔다. 클라이언트가 횃불을 놓으면 여전히 왕복 시간 뒤에 보인다(예측 안 함)
- (M3b) 오가기는 예측하지 않는다: F 뒤에도 지도 들어옴이 올 때까지(왕복 + 지도 조각) 옛 지도에서 걷다가 새 지도 도착점(+ 그동안 걸은 만큼)으로 바뀐다. 던전을 받아 그리는 데(`load_data`, 동굴 그림) 이 데스크탑에서 약 60~70ms라 들어가는 순간 한 프레임이 길다(로그 `build_ms=62.3`). 두 기기에서 어떻게 느껴지는지는 사람이 본다
- (M3b) 상태 묶음은 모든 플레이어를 모두에게 보낸다: 지상에 있는 사람도 던전 사람의 상태를 받는다(호스트가 던전에서 캐는 동안 지상 c1 수신 약 1.07KB/s, 상태뿐. 편집은 안 받는다). 9인이 지도 둘에 흩어지면 지도별 묶음이 더 싸다. 지금은 단순함을 골랐다. M3-fix 검토가 실제 수로 확인했다: `four` act2/4 split에서 지상의 c4는 두 광부를 하나도 그리지 않는데 1,749 B/s, 던전에서 캐는 c2는 1,799 B/s를 받고 호스트는 5,490 B/s를 보냈다. 9인이 1명 아래 · 8명 위로 나뉘면 지상 클라이언트마다 약 20 × (5 + 9 × 17)B ≈ 3.2KB/s, 호스트 약 25KB/s를 볼 수 없는 사람 몫까지 보낸다. 늘릴 때는 지도별 묶음 + "X가 지도 Y로" 작은 메시지(또는 바뀔 때만 1바이트 지도), 아니면 다른 지도의 사람은 키프레임에만
- (M3b) 지도에 들어갈 때마다 지도 전체를 다시 받는다(던전 309~345B, 지상 566~582B, 각 조각 1개). 떠난 지도를 들고 있다가 차이만 받는 방법은 없다(슬라이스 크기에서는 필요 없다고 봄)
- (M3b) 편집 기록은 지도마다 줄지 않는다. 채굴이 편집을 많이 만든다(광부 휘두르기 한 번에 칸 편집 6~9개). 호스트 메모리에만 쌓이고, 늦은 참가·지도 들어옴은 스냅샷 + 그 뒤 편집만 받는다. 기록 압축은 아직 없다(M2-fix 줄과 같은 문제). M3-fix 검토가 잰 상한: 던전 하나의 기록은 벽 수가 묶는다. 시드 1 던전은 깰 수 있는 벽 2,041칸이라 공용 힘으로 다 캐도 칸 편집 최대 12,376개(광부 힘 6,188개) + 광석 47 · 벽 횃불 편집, 편집 하나가 디버그 빌드에서 약 1.18KB라 다 캔 던전이 호스트에 약 14.5MB(release는 더 작을 것, 재지 않음). 지상의 끝없는 길은 여전히 호스트 자신의 F7 버리기·줍기와 허용된 빌드의 클라이언트 F7뿐이다
- (M3b) 호스트를 잃은 클라이언트가 던전에 있으면 혼자 던전에서 계속한다. 계단으로 올라가면 지상은 그 클라이언트가 지상을 떠날 때의 사본이다(그 뒤의 변화 없음). M3-fix에서 고친 둘: 세션이 만든 내 Player의 휘두르기·횃불 클릭이 Main에 이어지지 않아 혼자가 된 뒤 캐지도 놓지도 못했다(이제 `_on_local_player_ready`에서 잇는다. 세션 중에는 처리 함수가 아무것도 하지 않는다). 한 번도 내려가지 않은 클라이언트는 빈 던전 월드(데이터 없음)만 있어, 입구 F가 그 빈 지도로 옮겨 스크립트 오류 셋과 멈춘 화면이 됐다(검토 탐침). 이제 `Main.travel`이 데이터 없는 지도를 거부하고 `EVENSONG_MAP travel refused to=dungeon: that map was never received`를 찍는다. 그래서 그 클라이언트는 혼자서는 던전에 갈 수 없다(시드로 던전을 만들어 줄지는 정하지 않았다). 시험은 `test_dungeon`의 단위 시험이고 `drop` 세션은 그대로다(사람처럼 띄운 클라이언트에게는 봇이 없다)
- (M3b) 같은 칸을 같은 틱에 둘이 치는 경주는 단위 시험(`SessionHost.tick`)으로만 정확히 맞췄다. 실제 세션(`four`)에서는 두 사람이 몇 틱 차이로 맞고, 한 번만 깨지고 돌은 깬 쪽에 가는 것을 본다. 깬 뒤에도 누르고 있으면 그 칸이 이제 위 벽의 앞면이라 위 벽을 계속 판다(앞면 규칙, M3a)
- (M3b) 다른 지도에 있는 사람이 어디 있는지 화면에 아무 표시가 없다(임시값 "다른 지도의 플레이어")
- (M3-fix 검토, 고치지 않음) 지도 들어옴이 늦게 오는 동안의 예측: 그동안 오는 자기 상태는 모두 새 지도의 것이라 `other_map`으로 건너뛰고, 그 확인(ack)이 확인 안 된 프레임을 지우지 못한다. 지도 들어옴이 4 × 32프레임(약 2.1초)보다 늦고 그동안 계속 걸으면 상한이 오래된 프레임을 버려, `switch_map`이 그 프레임 없이 다시 돌린다: 한 번 틀리고 다음 상태에서 튄다(검토 탐침: 180틱 늦은 지도 들어옴, 최대 프레임 128, 보정 1번 15.9px, 같은 자리로 수렴). 그동안 입력 패킷마다 32프레임이 다 실린다. 보통 지연(20틱 늦은 것까지 8가지)은 보정 0번이다. 2초 넘게 지도가 안 오는 연결에서만이라 남긴다. 고친다면 건너뛴 상태 중 가장 새것을 잠정 기준으로 두고 그 ack까지 지우기
- (M3-fix 검토, 고치지 않음) 남이 지도를 옮길 때의 보간: 새 지도의 첫 상태가 오면 버퍼를 바로 비운다(그리기 시각이 그 틱에 닿기를 기다리지 않음). 옛 지도에서 보던 사람에게는 약 100ms(`NET_INTERP_DELAY_MS`) 일찍 사라져 입구·계단까지 마지막 약 6틱(약 7px)을 못 보고, 새 지도에서는 도착점에 100ms 일찍 나타나 시간이 따라올 때까지 서 있다. 보이는 것만이고 위치 해시는 같다. 고친다면 옛 지도 상태를 경계까지 그리다가 그 틱이 지나면 지도(보임)를 바꾸기
- (M3-fix 검토, 고치지 않음) 그림 칸 fallback이 대각선으로만 이어진 자리를 열린 통로처럼 그릴 수 있다(위 "벽과 앞면"). 충돌은 그린 것과 다르게 맞게 막는다. 그 코너 키를 막힌 모양으로 따로 그릴지, 그림 쪽이 빠진 조합을 그릴지 정하지 않았다
- (M3-fix 검토, 사람이 볼 것) 벽은 엔티티 아래에 그린다. 앞면 칸 옆 칸에 선 캐릭터가 앞면 쪽으로 삐져나오거나, 앞면이 다음 줄로 3px 내려온 자리 바로 남쪽에 선 캐릭터는 앞면 위에 그려진다(헤드리스로는 찍을 수 없어 재지 않음). 창에서 거슬리면 앞면 띠를 y 정렬한다
- (M3-fix) 계단 옆 바위를 일부러 치면 기반암 뚜껑 둘레를 파낼 수 있다(친 칸이 깰 수 있는 바위면 3×3·1×1이 그대로라). 계단 두 칸과 그 위 뚜껑은 남아 오가기는 된다. 계단 둘레를 통째로 보호할지는 정하지 않았다
- (M3-fix) TRAVEL에는 여전히 기다리는 시간(쿨다운)이 없다(임시값 "M3b 지도 오가기", 요청 예산만). 오갈 때마다 지도 전체를 다시 보낸다(던전 약 310~345B). 결과용 기록은 상한을 두었다(구현 표 "시험 결과용 기록 상한")
- (M3a) 던전 지도는 다른 지도로 가도 그대로 남는다(판 자리·놓은 횃불·드롭). 저장은 없어서 프로그램을 끄면 사라진다
- (M2a) 몸 동작의 기준점 중 몇 개가 크게 튄다. 규칙(● R27)대로 잰 값이고 고치지 않았다: 마법 북쪽 머리 (0, 6)(프레임 2·6, 몸 전체가 금빛으로 밝아지는 프레임이라 색이 맞는 픽셀이 적다), 던지기 남쪽 머리 (5, 6)·북쪽 머리 (−6, 4)(5번째 프레임, 크게 젖히는 자세), 마법 북쪽 몸통 (2, −4). 성직자의 후광과 등·허리 표식이 그 프레임에서 몇 px 어긋나 보일 수 있다. 창 그림 검사 `--save`로 남긴 `rig_<동작>_<프레임>_got.png`로 사람이 보고 idle처럼 손으로 고정할지 정한다
- (M2a) 몸 동작은 64칸이라 도구가 몸보다 멀리 나간다(시트에서 잰 값: 발에서 좌우 최대 13px, 몸은 9px. 발 줄 아래로 7px). 제단 옆 띠(몸 기준)는 그대로라 제단 옆면에 붙어 동작하면 도구가 제단 그림 뒤로 들어갈 수 있다. 목표 칸이 제단이면 동작은 그대로 한다(월드 효과가 없으니)
- (M2a, M2b에서 풂) 조준·동작은 혼자 할 때만이었다. M2b에서 입력 프레임에 바라보기와 요청을 넣어 호스트가 정한다(위 "M2b")
- (M2a) 목표 칸 표시는 캐릭터 아래에 그려서 발 북쪽 줄 칸(북·북동·북서)은 몸에 가린다. 마우스가 1초 동안 안 움직이면 표시가 사라진다(조준 끝)
- (M2a) 마법과 던지기는 그것을 부르는 아이템이 없어 F6·`--test-action`으로만 본다. 도구 아이콘은 코드로 그린 임시다
- (M2a) `--test-*` 플래그와 F5·F6 디버그 키는 내보낸 빌드에도 들어 있다

- (M2b) 든 아이템은 그림이 없다. 슬라이스는 도구를 몸 동작에 그려 넣고(● R25) 서 있을 때 손에 든 도구 레이어는 2단계(○ brief §5.6)라, 다른 사람의 도구는 동작할 때만 보인다. 든 아이템은 상태 묶음과 결과 JSON에만 있다
- (M2b) 줍기·버리기·주기는 예측하지 않는다. 클라이언트에서 F를 누르면 왕복 시간 뒤에 채집물이 사라지고 인벤토리에 들어온다(localhost에서는 한두 프레임). 두 기기에서 늦게 느껴지는지는 사람이 본다
- (M2b) 채집물은 시드 1에서 제단에서 가장 가까운 것이 약 13타일이다(빛 밖 + 1타일, 74개를 맵 전체에). 수·자리는 임시값이라 사람이 보고 정한다. 다시 자라지 않아서 다 주우면 끝이다
- (M2b) 드롭은 디버그 F7로만 생긴다(사망 드롭·채굴 드롭은 M2 밖). 칸 하나에 여러 드롭이 겹쳐 그려지고 개수 표시가 없다
- (M2b) 호스트가 거부한 사용은 클라이언트가 이미 그 동작을 시작해 보였다가 다음 상태(최대 왕복 + 50ms 뒤)에 되돌린다. 정상 세션에서는 일어나지 않는다(도구·칸 검사가 양쪽에서 같다)
- (M2b) 세션 시험이 약 37 → 51초로 늘었다(pair·four에 걷기·줍기·경주를 더함). 전체 테스트 약 73초
- (M2b) `--test-allow-give`, 봇 명령들은 내보낸 빌드에도 들어 있다
- (M2-fix 검토, 정하지 않음) 조준하지 않을 때(마우스가 1초 넘게 가만히 있어 표시가 숨었을 때)도 F·F7은 목표 칸, 곧 발 칸에서 마우스 커서 쪽 이웃 칸에 작용한다. 커서는 보이지만 표시는 없다. 그때 F가 바라보는 쪽 칸을 써야 할지, 표시를 늘 보일지는 설계 결정이라 사람이 정한다(○ gameplay-design §1 "F 상호작용", §3.4 "F로 식물·드롭 줍기")
- (M2-fix 검토) 편집 기록(`EditLog`)은 줄지 않는다. `MAX_DROPS`는 땅의 드롭 수를 묶지만 기록은 묶지 않아서, 버리고 줍기를 되풀이하면 호스트 메모리의 기록이 편집마다 늘어난다(늦은 참가자는 스냅샷 + 그 뒤 편집만 받는다). 이제 내보낸 release 호스트는 클라이언트의 F7을 거부하므로(`drop off`) 남는 것은 호스트 자신의 F7과, 디버그 빌드·`--test-allow-give` 호스트에서의 클라이언트 F7이다. 게임 편집(채굴·농사)이 생기면 기록 압축을 같이 정한다
- (M2-fix 검토) 클라이언트 키 요청은 호스트의 예산에 맞춰 보내지만, 패킷을 잃어 다음 패킷에 몰려 오거나 호스트가 멈췄다 따라잡으면 한 틱에 4개 넘는 줍기·버리기·주기가 `rate`로 거부될 수 있다(검토 탐침: 몰려 온 5개 중 1개, 8개 중 4개). 예측하지 않는 요청이라 아무 일도 일어나지 않고 호스트 로그에 남는다. 고르기는 예산 밖이라 해당 없다
- (M2-fix 검토) `test_aim.gd`의 `main.tscn` 마우스 검사(창 크기 6가지)는 헤드리스에서만 맞다. 창을 띄우면 루트 뷰포트가 주입한 이벤트 대신 OS 커서를 읽는다. 진짜 마우스로 조준해 보는 것은 사람이 한다
- 러너는 파일이 남긴 타이머·스레드·시그널 콜백이 늦게 내는 오류를 여전히 엉뚱한 파일 탓으로 세거나(그때 돌던 파일), 마지막 파일 뒤 10프레임보다 늦으면 놓친다. 루트에 남긴 노드만 따로 잡는다
- 다른 아키텍처의 월드 생성: FastNoiseLite가 float 계산이라 ARM64가 다른 월드를 만들 수 있다. H1부터 늦은 참가는 호스트의 월드를 받으므로 그래도 참가는 된다(흔든 생성기로 시험함). 남는 것: 서피스가 **호스트**가 되면 같은 시드라도 데스크탑과 다른 월드가 된다(시드 공유). 서피스 생성기가 같은지는 서피스에서 `evensong.console.exe --headless -- --smoke`(해시가 다르면 `seed 1 world hash` FAIL)나 참가 로그의 `generator=` 진단으로 안다. 다르면 노이즈를 정수 계산으로 바꿀지는 사람이 정할 일
- 스냅샷은 참가를 받는 순간 월드 전체를 한 번에 압축해 참가자마다 들고 있다가 보낸다(128×96은 342B, 512×512 합성 54KB). 큰 맵에서 근처 청크부터 보내기, 받는 동안 미리 걷기는 없다. 틱당 8KB라 압축이 안 되는 1.3MB는 2.8초 걸린다
- 스냅샷 크기 한계 (H-fix): 받는 쪽은 한 변 512칸(`MAX_SIDE`), 압축 1.6MB(`MAX_PACKED`)까지만 받는다. 접속 제한 10초(`NET_CONNECT_TIMEOUT_SEC`)가 월드를 다 받을 때까지라, 틱당 8KB로 약 4.8MB를 넘는 스냅샷은 그 안에 다 올 수 없다(지금 상한은 3.3초 거리). 맵을 512보다 키우면 두 값과 "근처 청크부터"를 같이 정해야 한다. 512×512를 그리는 데(`load_data`) 이 데스크탑에서 0.4~0.8초, 그동안 클라이언트 화면이 멈춘다
- 참가자가 월드를 받는 도중에 호스트가 편집하면 그 편집은 welcome 뒤에 번호대로 따로 간다. H-fix부터 실제 세션(`stall`)에서 지난다: 1바이트 조각 341~345개를 받는 동안 4틱마다 편집해서 welcome 뒤에 간 편집 10~11개, 참가자 월드 = 호스트 월드. M2b: 조각 약 567개(71틱), 그동안의 드롭까지 welcome 뒤 편집 약 20개 이 편집을 보내지 않게 깨 보면 실패한다
- 호스트가 1초(64틱)보다 오래 멈추면 걷던 클라이언트의 프레임 일부가 버려지고, 더 길면 한 번 크게 보정된다 (위 "호스트가 멈췄다 돌아올 때"의 한계)
- 참가하는 클라이언트도 시작할 때 자기 `--seed`(기본 1)로 월드를 한 번 만들어 그린다(`Main._ready`, `GameWorld`). welcome 전에 카메라 경계·바닥·제단이 있어야 해서 그대로 두었다. 이 월드는 welcome에서 받은 월드로 바뀌고 어디에도 쓰지 않는다(H-fix: 이 월드의 해시를 생성기 해시로 적던 것은 뺐다. 클라이언트의 `generator_hash`는 welcome의 진단에서만 정해진다). 그래서 `--test-perturb-generator` 참가자는 welcome 전 잠깐 다른 월드를 보인다
- 제단 옆 띠는 몸(기본 몸, 모든 클래스 같음) 기준이다. 등·팔의 장비(곡괭이·활·방패)는 제단 가장자리 뒤로 서쪽 6px·동쪽 7px까지 들어갈 수 있다(제단을 등지거나 옆으로 볼 때). 장비까지 넣으면 몸과 제단 사이가 7px까지 벌어져 보여서 몸 기준으로 했다. 띠는 제단 자리 위 변까지라 북쪽 면 모서리에서는 띠 폭만큼 면이 넓어진 셈이다(그 높이에서 제단 그림은 5px 아래에서 시작해 겹치지 않는다)
- 틱 사이에 그리기는 그림을 최대 한 틱(16.7ms) 늦게 보여 준다. 고른 걸음을 실제 144Hz 모니터에서 눈으로 본 사람은 아직 없다(시험은 144Hz 프레임 흉내). 이 데스크탑의 화면 주사율은 확인하지 않았다
- `--test-perturb-generator`, `--test-snapshot-chunk-bytes`, 봇 `stall:`은 테스트 전용인데 내보낸 빌드에도 들어 있다(사람이 쓸 일은 없다)
- 테스트 포트: 러너끼리는 잠금으로 겹치지 않지만, 러너가 아닌 프로그램이 확인 뒤에 묶음 안 포트를 잡는 것은 막지 못한다 (위 "테스트 포트"). 확인 전부터 잡고 있는 프로그램은 IPv4만 잡았어도 이제 찾는다(H-fix)
- 임시값 표의 모든 줄(특히 카메라 가장자리, 스폰, 같은 클래스 둘, 오염 구역 수, M2a의 키·조준·동작 줄, M3a·M3b 줄, M4a·M4b·M4-fix 줄 전부)은 사람이 확인해야 한다. M4-fix도 임시값 값을 하나도 바꾸지 않았다: 줄 셋을 더하고("M4-fix 화살 조준·맞는 상자": 구현 표의 8px·12px를 값 그대로 옮기고 28px를 더함, "M4-fix 빈 지도", "M4-fix 빛 안에서 쏘인 이단"), 표에 없던 M4a 동작 하나를 올리고("M4a 소생 뒤 무적"), "M4a 다운·소생·사망 시간"·"M4a 빛 가장자리"·"M4a 스폰"·"M4a 가방 자리"·"M4b 세션의 싸우는 지도"에 고친 동작과 문장을 적었다(값 그대로). M4a는 기존 임시값의 값을 하나도 바꾸지 않았다: "시작 인벤토리"(혼자 할 때 시작 무기), "마법·던지기를 부르는 아이템"(성광), "M3a 이단의 제단 자리"(부술 수 있음)는 줄의 값을 두고 M4a 줄이 대신한다고 적었고, 구현 표 "디버그 묶음"에 이끼 돌을 뺀 것을 적었다. M3-fix도 임시값을 하나도 바꾸지 않았다: 도착점의 4px에 이름(`ARRIVAL_FEET_INSET_PX`)을 붙였고, "M3a 벽 횃불 장식"·"출구 계단과 도착점"은 같은 값으로 적힌 규칙을 지키게 고쳤고(생성기가 바뀌어 던전 해시 둘이 바뀜, 시드 1은 벽 횃불만 8 → 10), "M3a 경도·타격"에 곡괭이 등급이 없다는 것과 문서 줄의 표시를, "M3a 횃불"·"묶음 크기"에 횃불 묶음·종류·벽 횃불이 떨어지는 것을 적었다. M3b도 있던 임시값은 바꾸지 않았다: "M3a 세션" 줄을 끝났다고 적고 줄 셋(지도 오가기, 다른 지도의 플레이어, 다시 참가할 때의 지도)을 더했다. M3a도 있던 임시값은 바꾸지 않고 줄만 더했다(F5 디버그 묶음은 구현 값이라 횃불을 넣었다). H1과 H-fix는 임시값을 하나도 바꾸지 않았다(새 값은 모두 "구현에서 고른 값"). M2a도 있던 임시값은 바꾸지 않고 줄만 더했다. M2-fix도 값은 바꾸지 않았다: "조준 기준" 줄의 발 칸을 그려진 발에 맞게 고쳤고(검토 지적, 사람이 볼 것), "채집물 자리"에 `GATHER_EDGE_TILES`(값 2 그대로)를 옮겨 적고, "디버그 주기"를 "주기·버리기"로 넓히고, "채집물 수"에 돌의 출처를 바로 적었다

M5c에서 확인하지 않은 것: **두 기기**(서피스 ARM64)와 먼 회선에서 농사·정화·제단 옮기기(위 "두 기기에서 M5 해 보기", 사람이 한다. ARM64 exe는 내보내기만 했다), 사람이 키보드·마우스로 세션에서 일구기·심기·F 채널링·F 2초 들기(시험과 두 창 그림은 봇), 실제 손실이 있는 회선에서 F를 누르는 동안 프레임을 잃었을 때의 들기(한 프로세스 시험은 지연만), 9인이 한 밭에서 일할 때의 편집·트래픽(넷까지 쟀다), 내보낸 exe의 창 스크린샷(헤드리스 스모크와 `--net-exe` 세션만).
M6b에서 확인하지 않은 것: **두 기기**(서피스 ARM64)와 먼 회선에서 제작·물약(위 "두 기기에서 M6 해 보기", 사람이 한다. ARM64 exe는 내보내기만 했다), 사람이 키보드·마우스로 세션의 제작 창·마시기·던지기(시험은 봇과 함수, 진짜 마우스·키는 M6a처럼 창에서 보지 않았다), 클라이언트 화면에서 왕복 뒤에 나타나는 자기 병이 거슬리는지(localhost에서는 한두 프레임), 버프된 사람이 많을 때의 트래픽을 실제 인터넷에서, 내보낸 exe의 창 스크린샷(헤드리스 스모크와 `--net-exe` 세션만).
M6a에서 확인하지 않은 것: 사람이 키보드·마우스로 조제대를 놓고 Tab·W/S·F·Enter·클릭으로 만들어 보기(시험은 함수·입력 이벤트·`click_at`와 봇, 진짜 마우스의 줄 고르기는 창에서 보지 않았다), 1배 화면에서 제작 창·머리 위 표시·터짐이 읽히는지(스크린샷은 에이전트가 2~4배로 확대해 봤다. 저녁 빛 밖의 터짐 첫 프레임은 작고 어둡다), 버프 125%·독 5초의 손맛과 균형(이단 HP 40에 상급 독 30), 던지는 거리 6칸·반경 1.5칸이 마우스 조준으로 맞히기 쉬운지, 마법 동작을 빌린 마시기가 마시는 것으로 읽히는지, 세션(바꾸지 않았다. 세션 시험만 다시 돌림), 두 기기, 내보낸 exe의 창 스크린샷(헤드리스 스모크와 120프레임만).

M4-fix에서 확인하지 않은 것: 사람이 마우스로 이단 그림을 눌러 쏘아 보기(시험은 `make_frame`에 마우스 점을 넣어 360발), 빛 안에서 쏘인 이단이 4초 뒤 돌아가는 것이 "빛 = 안전"을 어떻게 읽히게 하는지(사람이 정할 임시값), 한 방향 200ms를 넘는 회선에서 서 있다 맞을 때(`fightlag`는 왕복 120ms), 두 기기, 9인에서 클라이언트 시계 규칙의 비용(멤버마다 틱당 정수 몇 개).

M4b에서 확인하지 않은 것: **두 기기**(서피스 ARM64)와 먼 회선에서 싸움(위 "두 기기에서 M4 해 보기", 사람이 한다. ARM64 exe는 내보내기만 했다), 사람이 키보드·마우스로 세션에서 싸워 보기(시험·두 창 그림은 봇), 실제 손실이 있는 회선에서 적 묶음(unreliable)을 잃었을 때의 그림(한 프로세스 시험은 지연만, `lag` 세션은 싸움이 없다), 9인이 한 지도에서 싸울 때의 트래픽(넷까지 쟀다), 이단 여럿·화살 여럿일 때 클라이언트의 프레임 시간.

M4a에서 확인하지 않은 것: 사람이 키보드·마우스로 싸워 보기(시험·스크린샷은 봇과 함수로), 대시·예고(0.5초)·경직의 손맛, 1배 화면에서 어둠 속 이단과 화살·HP 막대가 읽히는지(스크린샷은 에이전트가 3~4배로 확대해 봤다), 이단 여럿·화살 여럿일 때의 프레임 시간, 960×540 밖의 창 크기에서 HUD 막대(창 검사는 2배 창만), 세션(바꾸지 않았다. 세션 시험만 다시 돌림), 두 기기(ARM64는 이번에도 내보내기만. 서피스의 `--smoke`가 `combat=30/3 spawn_tiles=678`이면 같은 규칙), 내보낸 exe의 창 스크린샷.

M3-fix에서 확인하지 않은 것: 앞면과 캐릭터의 그리기 순서를 창에서 눈으로(헤드리스로는 못 찍는다, 위 알려진 문제), 호스트를 잃은 뒤 혼자 하기를 실제 세션에서(단위 시험만, `drop` 세션의 클라이언트에는 봇이 없다), 새 벽 횃불 자리가 그림으로 어떻게 보이는지(시드 1의 새 둘은 커밋된 스크린샷 밖이다), 두 기기(이번에도 ARM64는 내보내기만. 서피스의 `--smoke`가 `dungeon_seeds=acc0a9bc2359`이면 같은 던전).

M3b에서 확인하지 않은 것: **두 기기**(서피스 ARM64)로 오가기·같이 캐기·늦은 참가(아래 "두 기기에서 M3 해 보기", 사람이 한다. ARM64 exe는 이번에도 내보내기만 했다. 서피스의 `--smoke`가 `dungeon_seeds=3ec443b95c4c`이면 던전 생성기도 같다), 실제 지연에서 지도 들어옴까지 걸리는 시간과 그동안 옛 지도에서 걷는 느낌(localhost에서만), 사람이 마우스·키보드로 두 창에서 캐 보기(시험은 봇), 9인이 지도 둘에 흩어졌을 때 트래픽(9인 시험은 지상에서 걷기만), 같은 틱 채굴 경주를 실제 세션에서(단위 시험만).

M3a에서 확인하지 않은 것: 사람이 키보드·마우스로 던전을 걷고 캐 보기(시험은 봇과 함수로), 금·광석·어둠·횃불 빛이 1배 화면에서 읽히는지(스크린샷 3장은 에이전트가 2~5배로 확대해 봤다), 실제 창에서 던전의 프레임 시간(빛 수십 개), 다른 아키텍처(ARM64)에서 던전 해시가 같은지(정수 계산뿐이라 같을 것으로 봄, 서피스에서 `--smoke`의 `seed 1 dungeon hash`로 알 수 있다), 내보낸 exe의 창 스크린샷(헤드리스 스모크와 120프레임만).

M2b에서 확인하지 않은 것: **두 기기**(서피스 ARM64)로 휘두르기·줍기·경주·늦은 참가(위 "두 기기에서 M2b 해 보기", 사람이 한다. 이번에도 ARM64 exe는 내보내기만 했다), 사람이 마우스·키보드로 두 창에서 해 보기(테스트는 봇으로만), 실제 지연에서 동작 예측이 보정 없이 맞는지(가짜 연결 단위 시험과 localhost 세션만, 세션의 `lag`은 걷기만), 9인이 동시에 동작할 때 트래픽(9인 시험은 걷기만), 동작 중 스크린 그림의 매 프레임(세션 그림은 두 장, 프레임 그림은 M2a 창 검사).

G1에서 확인하지 않은 것: ARM64 exe 실행(이 기기는 x86_64), 실제 창의 프레임 시간, 내보낸 exe의 창 스크린샷(G2에서 확인함), 에디터(`-e`)로 열어 보기(사람이 한다).

G3에서 확인하지 않은 것: **두 기기**(데스크탑 + 서피스, Tailscale)로 새 네트워크 코드를 돌려 보기(사람이 한다. 위 "둘이 하기"), ARM64 exe 실행(이 기기는 x86_64, 내보내기만 함), 실제 인터넷·Steam 릴레이(Steam은 M1 밖), 진짜 지연·손실(자동 시험은 localhost + 클라이언트 쪽 흉내뿐, 호스트 쪽 지연은 흉내 내지 않았다), 사람이 키보드로 두 창에서 걸어 보기(테스트는 봇으로만), 호스트를 처음 열 때 Windows 방화벽 창(이 세션에서는 아무 창도 확인하지 못했다), 다른 아키텍처끼리 월드 해시가 같은지(H1부터 참가에는 상관없다. 서피스에서 `--smoke`나 `generator=` 진단으로 볼 수 있다), 창 모드의 실제 프레임 시간.

H1에서 확인하지 않은 것: 두 기기(서피스 ARM64)로 스냅샷 참가 해 보기(사람이 한다. 이번에도 ARM64 exe는 내보내기만 했다), 60Hz보다 빠른 실제 모니터에서 틱 사이 그리기를 눈으로 보기, 진짜 큰 맵 세션(512×512는 단위 시험의 한 프로세스 전송과 그리기만. 세션은 M1 맵뿐). 받는 도중의 편집과 호스트가 실제로 멈추는 세션은 H-fix의 `stall` 세션이 확인한다(멈춤은 `OS.delay_msec`로 낸 것이고, 실제 무거운 프레임·다른 기기에서는 아니다).

H-fix에서 확인하지 않은 것: 두 기기(서피스 ARM64, Tailscale)에서 ENet 패킷 조절을 끈 연결(localhost에서만 잼. 실제 망에서 상태 묶음이 끊기지 않는지, 혼잡할 때 늦어지지 않는지는 사람이 두 기기로 볼 것), 서피스의 `--smoke`(이번에도 ARM64 exe는 내보내기만 했다), 물리 틱 밖 멈춤이 진짜 무거운 프레임(그리기·RPC)에서 나는 경우(시험은 `_process`의 `OS.delay_msec`), 따라잡기 4배 속도를 사람이 화면으로 보기.

G2에서 확인하지 않은 것: 사람이 키보드로 직접 걸어 보기(테스트는 입력 액션을 눌러 물리 틱으로 확인했다), 실제 창의 프레임 시간, ARM64 exe 실행, 에디터로 열어 보기, idle 기준점을 사람이 보고 고정하기, 화면 캡처는 창 안 렌더 타깃이고 모니터에 나간 그림(스왑체인)은 아니다(스파이크에서 사람이 따로 확인한 방식).
