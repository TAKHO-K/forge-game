#!/usr/bin/env bash
# QUEUE-ALL5 G: 로컬 하네스 전부를 한 번에(Studio 없이). 사용: LUAU=<luau.exe> bash roblox/tools/harness/run_all.sh
#   결과 = 하네스마다 "끝 n/m" 줄(boss_motion은 "total jumps") · 상세 = %TEMP%/res_*.txt
set -u
H="$(cd "$(dirname "$0")" && pwd)"
cd "$H"
: "${LUAU:?LUAU=<luau.exe 경로>를 주세요}"
export LUAU PYTHONIOENCODING=utf-8
T="${TEMP:-/tmp}"
run() { # 이름 결과파일 의존 테스트파일 [prelude]
	local name="$1" res="$2" deps="$3" test="$4" prelude="${5:-server_prelude.luau}"
	PRELUDE="$prelude" EXTRA_SERVER="$deps" ECON_RES="$res" ECON_OUT="out_$res.luau" python build_run.py "$test" >/dev/null
	printf "%-22s %s\n" "$name" "$(grep -a -E '끝 [0-9]+/[0-9]+|결과 [0-9]+/[0-9]+ 통과|total jumps|하네스 에러' "$T/$res" | tail -1) $(case "$name" in dupe) printf "O %s · X %s" "$(grep -a -c '^\[DUPE\].* O$' "$T/$res")" "$(grep -a -c '^\[DUPE\].* X$' "$T/$res")";; esac)"
}
ATTACK=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,SettingsService,FallServer,InventoryServer.server)
run security_launch res_sec.txt "$(python deps.py SocialRewardService,CodexService,CommunityGoalService,WeeklyChallengeService,SpectateService.server,RequestGate,QuestService,PlayerProfile,SaveSystem,Travel)" security_launch_test.luau
run save_launch res_launch.txt SaveSystem,SlotSave,SaveCoordinator,ImmediateSave save_launch_test.luau
run save_lock res_lock.txt SaveSystem,SlotSave save_lock_test.luau
run migrate_curve res_curve.txt SaveSystem,SlotSave migrate_curve_test.luau
run id_quarantine res_quar.txt SaveSystem,SlotSave id_quarantine_test.luau
run slot_save res_slot.txt SaveSystem,SlotSave,SkillCooldowns,MenuBlock slot_save_test.luau # QUEUE-MENU2 B 캐릭터 칸 저장(이관 · 분리 · 중복 · 상한 · 보관 · 두 서버 · 스위치 끔/켬 · 크기 · 새 계정)
run monetize res_mon.txt "$(python deps.py MonetizationService,SaveSystem,OpsServer.server,InventorySync)" monetize_test.luau
run dupe res_dupe.txt "$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,MonetizationService)" dupe_test.luau
run multiplayer res_multi.txt "$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem)" multiplayer_test.luau
run attack res_attack.txt "$ATTACK" attack_test.luau
run request_gate res_gate.txt "$ATTACK,RequestGate" request_gate_test.luau
run mesh_import res_mesh.txt "" mesh_import_test.luau
run ops_security res_ops.txt OpsRollback,SuspicionMonitor,AuditTrail ops_security_test.luau # QUEUE-ALL6 F 되돌리기 · 차단 · 탐지 · 감사
run season_pass res_season.txt "" season_pass_test.luau # QUEUE-ALL9A 1-5 패스 패턴 6종 × 8주 · 주말 경계
run economy_all9b res_all9b.txt SecretNestData economy_all9b_test.luau # QUEUE-ALL9B 판매가 · 수련 · 토큰 · 패스 가치 · 출석판
run enhance_g res_g.txt "$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,EnhanceService,EnhancePolicy,ImmediateSave)" enhance_g_test.luau # QUEUE-ALL9B G 강화 최상위 · 초기화 바닥 · 방지 옵션 · 방지권 환산
run bignum res_big.txt "$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem)" bignum_test.luau # QUEUE-ALL9B 큰 숫자 · ALL9C 0-2: 2^53 정밀도 4건 = "알려진 문제"(이름 고정 - 통과 수에서 빠짐)
run bulk_sell res_bulk.txt "$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,MonetizationService,InventorySync)" bulk_sell_test.luau # QUEUE-ALL9C 1-9 등급 체크 일괄 판매 75칸
run stat_sheet res_sheet.txt "$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem)" stat_sheet_test.luau # QUEUE-ALL9C 1-2 상세 능력치 합계 = 전투 값 · 줄/출처 = StatSheetData
run all10 res_all10.txt "$(python deps.py TranscendService,TranscendFirsts,PlayerProfile,PetService,QuestService,SaveSystem,BaseLayer)" all10_test.luau # QUEUE-ALL10 초월 계승(스위치 끔 = 지금 게임 · 저장 v70 · 계승 · 초월 강화 · 수련 · 보석 · 몹 곡선)
EXTRA_FILES=client/ArmorColors.lua,shared/MeshMeta/armor_wear.lua run gear_v3 res_gear.txt "" gear_v3_test.luau # QUEUE-ALL9E1 1-1 장비 v3 48조합 예약 색 · 문 부품 · 무기 색 · 메시 메타 60 + 문장 6 · 1인 MeshPart ≤ 24
EXTRA_FILES=client/ItemIcons.lua run gem_home res_gemhome.txt "" gem_home_test.luau # QUEUE-ALL9E1 기능: 보석 탭 무기 키 · 보석 아이콘 한 소스 · 초월 이펙트 단계
run monster_stats res_mstat.txt "" monster_stats_test.luau # QUEUE-N1004 C-4 몹 스탯 공용 함수 값 불변(골든 1,736값 · 31지점 · 오차 0)
run dash_modes res_dash.txt "" dash_modes_test.luau # FINAL-1 3 MOVE-2 대시 모드(긴 · 짧은 · 기울기) · 두 번 연속 누름 · 거리 식
run boss_feel res_feel.txt "$(python deps.py BossHandlersBR1,PlayerCC)" boss_feel_test.luau # BOSS-NIGHT-3 보스 손맛 · 공정성(분신 줄 겹침 · 새 몸 스킬 곡선 · CC · 투사체 · 범위)
run menu_gate res_menu.txt SlotSwitch,SlotSave menu_gate_test.luau # 메인 메뉴 버그(10-05): 테스트 플래그만 건너뜀 · 접속 미스폰 · 입장 스폰 · 메뉴 왕복
printf "%-22s %s\n" menu_gate_src "$(python menu_gate_static.py 2>&1 | grep -a -E '끝 [0-9]+/[0-9]+' | tail -1)"
printf "%-22s %s\n" hud_v5_src "$(python hud_v5_static.py 2>&1 | grep -a -E '끝 [0-9]+/[0-9]+' | tail -1)" # QUEUE-UI2 UI2-4 환생 진입 경로 · 메뉴 창 = PanelRegistry · 키 칩 · 빨강
EXTRA_FILES=first/MenuArtFit.lua,first/MenuBootData.lua run ui_v2 res_uiv2.txt SlotSave ui_v2_test.luau # QUEUE-UI UI-0 토큰 · 좌표 표 · 아이콘 표 · 배율 · 신직업 = 데이터 추가만
run hud_layout res_hudlayout.txt "" hud_layout_test.luau # UI-1 0단계 02 v6 배치: 해상도 7 × 평상시 · 보스전 · 화면 밖 · 상단 바 · 터치 44 · 접기 · 폰 전투 버튼(겹침 = 목록)
run ui1_parts res_ui1parts.txt "" ui1_parts_test.luau # UI-1 1단계 A 부품: 상태 아이콘 39 · 그림 기록 · ko/en 짝 · 색 3개 · 잡힘 종류
run codex_box res_codexbox.txt SecretNestData codex_box_test.luau # UI-1 5단계 도감 진행 상자 10 = 옛 점수판 29단계 총량 · 두 번 안 받음 · 토큰 600 + 140
run ui_rules res_ui.txt "" ui_rules_test.luau # QUEUE-ALL9C 블록 1 화면 규칙(순위 상위 약 n% 등 순수 함수)
run community_goal res_goal.txt "" community_goal_test.luau # QUEUE-ALL7 B5 합동 목표 00 · ±25% · 문턱 순서
run boss_motion res_motion.txt "" boss_motion_test.luau motion_prelude.luau
printf "%-22s %s\n" require_path "$(python require_path_test.py 2>&1 | grep -a -E '^\[REQ\] (X|끝)' | tail -3 | tr '\n' ' ')" # BOSS-NIGHT-2 D: require 경로 = 실제 파일(Rojo 매핑) - 하네스는 이름으로 묶어 틀린 경로도 통과시킨다
printf "%-22s %s\n" regrow_timing "$(python regrow_timing_test.py 2>&1 | grep -a -E '끝 [0-9]+/[0-9]+' | tail -1)"
(cd ../meshswap_harness && python mk_mesh.py test_mesh.luau >/dev/null && printf "%-22s %s\n" meshswap "$("$LUAU" mesh_run.luau 2>&1 | grep -a -E '===MESH 하네스' | tail -1)")
printf "%-22s %s\n" id_registry "$(python ../ids/id_registry.py | tail -1)"
