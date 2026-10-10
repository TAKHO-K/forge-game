#!/usr/bin/env bash
# QUEUE-ALL5 G: 로컬 하네스 전부를 한 번에(Studio 없이). 사용: LUAU=<luau.exe> bash roblox/tools/harness/run_all.sh
#   결과 = 하네스마다 "끝 n/m" 줄(boss_motion은 "total jumps") · 상세 = %TEMP%/res_*.txt
#   UI-1b 0절(VERIFY-5): "끝 a/b"의 b는 실제 돈 검사 수라 중간에 멈춰도 a = b가 된다 → 하네스마다 기대 검사 수(EXP)를 고정해 두고
#   다르면 X · 실행 전에 결과 파일을 지움(이전 실행 결과가 통과로 찍히지 않게) · 종료 코드 · 에러 문구는 ERR_RE 하나로 판정.
#   검사를 늘리거나 줄였으면 EXP도 같이 고친다. 끝 줄 = "전체 n개 · X m"(X 0이어야 통과).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
cd "$H"
: "${LUAU:?LUAU=<luau.exe 경로>를 주세요}"
export LUAU PYTHONIOENCODING=utf-8
T="${TEMP:-/tmp}"
# 에러 문구 = "[태그] 에러 …" · "[태그] 하네스 에러 …" · "[태그] 스레드 에러 …"(하네스가 pcall로 잡은 것) + luau가 못 잡은 에러(stacktrace:)
ERR_RE='^\[[A-Za-z0-9_]+\] ([^ ]+ )?에러 |^stacktrace:'
declare -A EXP=( # 기대 검사 수(끝 a/b의 b) · require_path는 최소값(require가 늘면 같이 늘어남)
	[security_launch]=47 [save_launch]=65 [save_lock]=12 [migrate_curve]=24 [id_quarantine]=15 [slot_save]=74 [monetize]=86 [dupe]=11
	[multiplayer]=12 [attack]=10 [request_gate]=7 [mesh_import]=34 [ops_security]=34 [season_pass]=13 [economy_all9b]=34 [enhance_g]=25
	[bignum]=67 [bulk_sell]=11 [stat_sheet]=9 [all10]=57 [gear_v3]=10 [gem_home]=25 [monster_stats]=5 [dash_modes]=19 [boss_feel]=13
	[menu_gate]=14 [menu_gate_src]=11 [hud_v5_src]=10 [ui1_static]=9 [ui1c_static]=13 [ui_v2]=77 [hud_layout]=18 [ui1_parts]=11 [codex_box]=35
	[ember_view]=8 [hud_edit]=16 [pet_ui]=7 [quick_chat]=6 [ui_rules]=4 [window_layers]=7 [help_data]=6 [train_bundle]=5 [community_goal]=24 [require_path]=5542 [regrow_timing]=8
	[sec_save]=13 [sec_shop]=6 [sec_secret]=6
)
NALL=0; NBAD=0
verdict() { # 이름 결과파일 종료코드 → 한 줄 출력
	local name="$1" f="$2" rc="$3" line bad="" a b exp="${EXP[$1]:-}"
	line="$(grep -a -E '끝 [0-9]+/[0-9]+|결과 [0-9]+/[0-9]+ 통과|total jumps|===MESH 하네스|결과: ' "$f" 2>/dev/null | tail -1)"
	[ "$name" = dupe ] && line="O $(grep -a -c '^\[DUPE\].* O$' "$f") · X $(grep -a -c '^\[DUPE\].* X$' "$f")"
	if [ ! -s "$f" ] || [ -z "$line" ]; then bad=" · X 결과 없음"
	else
		[ "$rc" != 0 ] && bad="$bad · X 종료 코드 $rc"
		grep -a -q -E "$ERR_RE" "$f" && bad="$bad · X 하네스 에러(중간 멈춤): $(grep -a -m1 -E "$ERR_RE" "$f" | cut -c1-120)"
		if [[ "$line" =~ ([0-9]+)/([0-9]+) ]]; then a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"
			[ "$a" != "$b" ] && bad="$bad · X 실패 $((b - a))"
			if [ -n "$exp" ]; then
				if [ "$name" = require_path ]; then [ "$b" -lt "$exp" ] && bad="$bad · X 검사 수 $b < 최소 $exp"
				elif [ "$b" != "$exp" ]; then bad="$bad · X 검사 수 $b ≠ 기대 $exp"; fi
			fi
		fi
		case "$name" in
			dupe) [[ "$line" == "O $exp · X 0" ]] || bad="$bad · X 기대 O $exp · X 0";;
			boss_motion) [[ "$line" == *"total jumps 0"* ]] || bad="$bad · X 튐";;
			meshswap) [[ "$line" == *"하네스 O"* ]] || bad="$bad · X";;
			id_registry) [[ "$line" == *"통과"* ]] || bad="$bad · X";;
		esac
	fi
	NALL=$((NALL + 1)); [ -n "$bad" ] && NBAD=$((NBAD + 1))
	printf "%-22s %s%s\n" "$name" "$line" "$bad"
}
run() { # 이름 결과파일 의존 테스트파일 [prelude]
	local name="$1" res="$2" deps="$3" test="$4" prelude="${5:-server_prelude.luau}" out rc
	rm -f "$T/$res"
	out="$(PRELUDE="$prelude" EXTRA_SERVER="$deps" ECON_RES="$res" ECON_OUT="out_$res.luau" python build_run.py "$test" 2>&1)"; rc=$?
	[[ "$out" =~ ^exit\ ([0-9]+) ]] && [ "$rc" = 0 ] && rc="${BASH_REMATCH[1]}" # python은 성공 · luau 종료 코드는 "exit n"
	verdict "$name" "$T/$res" "$rc"
}
pyrun() { # 이름 명령… (python 정적 하네스 · 출력을 결과 파일로)
	local name="$1"; shift
	rm -f "$T/res_py_$name.txt"
	"$@" > "$T/res_py_$name.txt" 2>&1
	verdict "$name" "$T/res_py_$name.txt" "$?"
}
ATTACK=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,SettingsService,FallServer,InventoryServer.server)
run security_launch res_sec.txt "$(python deps.py SocialRewardService,CodexService,CommunityGoalService,WeeklyChallengeService,SpectateService.server,RequestGate,QuestService,PlayerProfile,SaveSystem,Travel)" security_launch_test.luau
run save_launch res_launch.txt SaveSystem,SlotSave,SaveCoordinator,ImmediateSave save_launch_test.luau
run save_lock res_lock.txt SaveSystem,SlotSave save_lock_test.luau
run migrate_curve res_curve.txt SaveSystem,SlotSave migrate_curve_test.luau
run id_quarantine res_quar.txt SaveSystem,SlotSave id_quarantine_test.luau
run slot_save res_slot.txt SaveSystem,SlotSave,SkillCooldowns,MenuBlock slot_save_test.luau # QUEUE-MENU2 B 캐릭터 칸 저장(이관 · 분리 · 중복 · 상한 · 보관 · 두 서버 · 스위치 끔/켬 · 크기 · 새 계정)
run sec_save res_secsave.txt SaveSystem,SlotSave,SaveCoordinator,ImmediateSave,SlotSwitch,SaveServer.server sec_save_test.luau # SEC-FIX-1 1 · 2 칸 전환 중 자동저장 · 계정 키 먼저 · 같은 서버 재접속(옛 = X · ECON_SRC로 옛 스냅샷 확인)
run monetize res_mon.txt "$(python deps.py MonetizationService,SaveSystem,OpsServer.server,InventorySync)" monetize_test.luau
run sec_shop res_secshop.txt "$(python deps.py MonetizationService,SaveSystem,OpsServer.server,InventorySync)" sec_shop_test.luau # SEC-FIX-1 3 · 8 결제 지급 에러 잠금 해제 · 패스 따라잡기(옛 = X)
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
pyrun menu_gate_src python menu_gate_static.py
pyrun hud_v5_src python hud_v5_static.py # QUEUE-UI2 UI2-4 환생 진입 경로 · 메뉴 창 = PanelRegistry · 키 칩 · 빨강
pyrun ui1_static python ui1_static.py # UI-1 7c 전투력 = 한 함수(HUD · 캐릭터 · 관문 · 가방)
pyrun ui1c_static python ui1c_static.py # UI-1c 매머드 이름 = 데이터 한 곳 · 기여 알약 · 순위 · 도감 v3 · 장비 상세(단계마다 늘어남)
pyrun sec_secret python sec_secret_static.py # SEC-FIX-1 4 클라 복제 폴더(shared · client · first)에 교환 코드 · 서버 전용 설정 없음(옛 = X)
EXTRA_FILES=first/MenuArtFit.lua,first/MenuBootData.lua run ui_v2 res_uiv2.txt SlotSave ui_v2_test.luau # QUEUE-UI UI-0 토큰 · 좌표 표 · 아이콘 표 · 배율 · 신직업 = 데이터 추가만
run hud_layout res_hudlayout.txt "" hud_layout_test.luau # UI-1 0단계 02 v6 배치: 해상도 7 × 평상시 · 보스전 · 화면 밖 · 상단 바 · 터치 44 · 접기 · 폰 전투 버튼(겹침 = 목록)
run ui1_parts res_ui1parts.txt "" ui1_parts_test.luau # UI-1 1단계 A 부품: 상태 아이콘 39 · 그림 기록 · ko/en 짝 · 색 3개 · 잡힘 종류
run codex_box res_codexbox.txt SecretNestData codex_box_test.luau # UI-1 5단계 도감 진행 상자 10 = 옛 점수판 29단계 총량 · 두 번 안 받음 · 토큰 600 + 140
run ember_view res_ember.txt "" ember_view_test.luau # UI-1 6단계 불씨 칸 = spec 표(+24 = 17칸) · 가득까지 n번 · 하락 = 칸만 다시 나눔
run hud_edit res_hudedit.txt "" hud_edit_test.luau # UI-1 7b HUD 편집 배치 = 서버와 같은 검사(화면 밖 · 상단 바 · 로블록스 버튼 · id 화이트리스트) · 요소 8
run pet_ui res_petui.txt "" pet_ui_test.luau # UI-1 7c 알 확률 합 100(알 × 부화 레벨) · 펫 놓아주기 판정(데리고 다님 · 잠금 거절)
run quick_chat res_qchat.txt "" quick_chat_test.luau # UI-1 7c 파티 빠른 말(번호만 · 같은 말 3번 연속 = 5초 쉬기)
run window_layers res_wlay.txt "" window_layers_test.luau # UI-1b 1-b 10 창 층 표 · 나중에 연 창이 위
run help_data res_help.txt "" help_data_test.luau # UI-1b [?] 도움말 · 재화 설명 문구 키 ko · en
run train_bundle res_tbun.txt "" train_bundle_test.luau # UI-1b 1-b 17 수련 · 능력 묶음 = 비용 합 같음 · 상한 같음
run ui_rules res_ui.txt "" ui_rules_test.luau # QUEUE-ALL9C 블록 1 화면 규칙(순위 상위 약 n% 등 순수 함수)
run community_goal res_goal.txt "" community_goal_test.luau # QUEUE-ALL7 B5 합동 목표 00 · ±25% · 문턱 순서
run boss_motion res_motion.txt "" boss_motion_test.luau motion_prelude.luau
pyrun require_path python require_path_test.py # BOSS-NIGHT-2 D: require 경로 = 실제 파일(Rojo 매핑) - 하네스는 이름으로 묶어 틀린 경로도 통과시킨다
pyrun regrow_timing python regrow_timing_test.py
pyrun meshswap bash -c 'cd ../meshswap_harness && python mk_mesh.py test_mesh.luau >/dev/null && "$LUAU" mesh_run.luau'
pyrun id_registry python ../ids/id_registry.py
printf "%-22s %s\n" "전체" "${NALL}개 · X ${NBAD}$([ "$NBAD" = 0 ] && printf ' · 통과')"
[ "$NBAD" = 0 ]
