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
run save_launch res_launch.txt SaveSystem,SaveCoordinator,ImmediateSave save_launch_test.luau
run save_lock res_lock.txt SaveSystem save_lock_test.luau
run migrate_curve res_curve.txt SaveSystem migrate_curve_test.luau
run id_quarantine res_quar.txt SaveSystem id_quarantine_test.luau
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
run all10 res_all10.txt "$(python deps.py SaveSystem)" all10_test.luau # QUEUE-ALL10 초월 계승(스위치 끔 = 지금 게임 · 저장 v70 · 계승 · 초월 강화 · 수련 · 보석 · 몹 곡선)
run monster_stats res_mstat.txt "" monster_stats_test.luau # QUEUE-N1004 C-4 몹 스탯 공용 함수 값 불변(골든 1,736값 · 31지점 · 오차 0)
run ui_rules res_ui.txt "" ui_rules_test.luau # QUEUE-ALL9C 블록 1 화면 규칙(순위 상위 약 n% 등 순수 함수)
run community_goal res_goal.txt "" community_goal_test.luau # QUEUE-ALL7 B5 합동 목표 00 · ±25% · 문턱 순서
run boss_motion res_motion.txt "" boss_motion_test.luau motion_prelude.luau
printf "%-22s %s\n" regrow_timing "$(python regrow_timing_test.py 2>&1 | grep -a -E '끝 [0-9]+/[0-9]+' | tail -1)"
(cd ../meshswap_harness && python mk_mesh.py test_mesh.luau >/dev/null && printf "%-22s %s\n" meshswap "$("$LUAU" mesh_run.luau 2>&1 | grep -a -E '===MESH 하네스' | tail -1)")
printf "%-22s %s\n" id_registry "$(python ../ids/id_registry.py | tail -1)"
