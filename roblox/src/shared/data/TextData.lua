-- 플레이어가 보는 문장 원문(G1-1 - shared/Text.get이 읽는다). 키 = "화면.용도" · 값 = 한 문장 전체 템플릿({이름} = 인자).
-- 규칙(COMMON §2): 한 문장은 한 템플릿이다(조각 이어붙이기 금지) · 인자는 이름으로 · 숫자는 호출하는 쪽이 형식을 정해 문자열로 넘긴다.
-- G1-1부터 새로 쓰거나 고친 문장만 여기 있다. 옛 문장은 L(번역) 단계에서 옮긴다.
return {
	ko = {
		-- ? 도움말 2단(HelpTooltip)
		["help.more"] = "눌러서 자세히 ▼",
		["help.less"] = "접기 ▲",

		-- C4-3 치명 옵션 툴팁 한 줄(오버치명 전환 - CombatConfig.overCrit)
		["item.critOverflowNote"] = "치명 확률 100% 초과분은 공격력으로 바뀜",
		-- C5-7b 초월 특수 옵션 툴팁 한 줄(TranscendentData - 숫자는 ItemDescribe가 넘긴다)
		["transcendent.special.phantom"] = "환영: 기본 공격 {chance}% 확률로 환영 추가타 · 3번째마다 강공격",
		["transcendent.special.frenzy"] = "광폭: 전투 중 이속 · 공속 +{speed}% · 대시 쿨 −{dash}%",
		["transcendent.special.soar"] = "비상: 공중 강공격 적중 시 공중 행동 초기화(쿨 {cd}초)",

		-- 강화대
		["enhance.help.short"] = "실패할 때마다 불씨가 차고, 가득 차면 다음 강화는 반드시 성공합니다.",
		["enhance.help.detail"] = "0~{safeTo}강은 실패해도 단계가 그대로입니다. {dropFrom}강부터 실패하면 단계가 내려갈 수 있고, {resetFrom}강부터는 실패 시 {resetTo}강으로 초기화될 수 있습니다.",
		["enhance.odds.headResult"] = "결과",
		["enhance.odds.headProb"] = "확률",
		["enhance.odds.headLevel"] = "단계",
		["enhance.odds.success"] = "성공 시",
		["enhance.odds.maintain"] = "실패 시 · 유지",
		["enhance.odds.down1"] = "실패 시 · 1강 하락",
		["enhance.odds.down2"] = "실패 시 · 2강 하락",
		["enhance.odds.reset"] = "실패 시 · 초기화",

		-- 보석 가공(재련)
		["gemForge.help.short"] = "재련: 레벨이 더 높은 재료 보석을 넣으면 대상 보석이 그 레벨이 됩니다.",
		["gemForge.help.detail"] = "재료 보석은 사라집니다. 대상의 옵션 종류 · 자리는 그대로이고 수치만 새 레벨로 다시 계산됩니다.\n분해: 보석을 보석 가루로 바꿉니다. 가루는 재련 · 변환권 구매에 씁니다.",
		["gemForge.fodderHeader"] = "재료 보석 - 레벨을 대상에 넘겨주고 사라집니다(대상보다 레벨이 높은 가방 보석 {count}개)",
		["gemForge.fodderPick"] = "재료로",
		["gemForge.pickFodder"] = "재료 보석을 고르세요",

		-- 보석 공방 · 가방 보석 탭
		["gemWorkshop.help.short"] = "고대 · 태초 장비 · 보석의 옵션을 변환권으로 다시 굴립니다.",
		["gemWorkshop.help.detail"] = "변환권은 이곳에서 골드와 보석 가루로 삽니다.\n보석 장착 · 교체는 어디서나 됩니다(가방 → 보석 탭).",
		["gemHeader.help.short"] = "옵션 변환 · 다시 굴리기는 커뮤니티 센터의 보석상인에게서 합니다.",
		["gemHeader.help.detail"] = "환생의 제단 옆입니다. 보석 장착 · 교체는 어디서나 됩니다.",

		-- 장비 계승
		["inherit.help.short"] = "착용 중인 장비의 옵션을 새 장비로 옮깁니다.",
		["inherit.help.detail"] = "옵션 종류와 자리가 옮겨지고, 수치는 새 장비의 등급 · 레벨로 다시 계산됩니다. 착용 중이던 장비는 분해한 것처럼 돌려받습니다(영웅 이상 = 보석 1개, 그 아래 = 판매 골드).",

		-- 성장 보상
		["milestones.help.short"] = "환생 {rebirths}회를 마친 직업은 레벨이 오를 때 능력치 보상과 시스템 해금을 받습니다.",
		["milestones.help.detail"] = "레벨 {firstLevel}에 큰 보상({stat} +{big}%)과 첫 해금, 그 뒤 {interval}레벨마다 작은 보상(+{small}%). 능력치 보상은 모두 합쳐 +{cap}%(몬스터가 약 10스테이지 강해지는 만큼)에서 멈춥니다.\n레벨 {unlockFrom}부터 {unlockEvery}레벨마다 시스템 해금이 하나씩 열립니다(계정 공유 · 한 번만).",

		-- 순위
		["leaderboard.help.short"] = "보스 스테이지 돌파 기록의 순위입니다(약 90초마다 갱신).",
		["leaderboard.help.detail"] = "지금 내 기록보다 한 단계 위 보스를 처음 깼을 때만 기록됩니다. 본인이 보스 피해의 10% 이상을 넣어야 합니다.",

		-- 파티
		["party.help.short"] = "몬스터 피해의 {percent}% 이상을 넣어야 파티 보상을 받습니다.",

		-- 스테이지 선택 보상 띠(StageRewardBand)
		["band.every.head"] = "매번",
		["band.every.body"] = "골드·경험치 {units}마리분",
		["band.stone"] = "{name} ≈{count}",
		["band.retry.head"] = "재도전",
		["band.retry.body"] = "장비 1개({grades})",
		["band.gradeChance"] = "{grade} {percent}",

		-- 가방 자동 처리(G1-2)
		["bag.autoProcess.off"] = "자동 처리: 끔",
		["bag.autoProcess.on"] = "자동 처리: {grade} 이하",
		["toast.autoDismantle"] = "자동 분해: {item} → 보석",
		["toast.autoSell"] = "자동 판매: {item} +{gold}골드",

		-- MV1 환생 해금(18번 시트 규칙 - 40자 이하 · 한 문장 = 한 행동 · 숫자는 인자로)
		["moveUnlock.popup.title"] = "새 이동 기술",
		["moveUnlock.popup.ok"] = "확인",
		["moveUnlock.popup.1"] = "공중에서 점프를 한 번 더! 공중 공격도 열렸어요",
		["moveUnlock.popup.2"] = "공중에서 대시를 길게 누르면 활강해요",
		["moveUnlock.popup.3"] = "공중 점프 2회! 공중 3타 = 강공격",
		["moveUnlock.popup.4"] = "활강이 길어지고 공중 대시가 더 멀리 가요",
		["moveUnlock.popup.5"] = "무기가 태초 등급이 됐어요",
		["moveUnlock.rewardHeader"] = "환생 보상",
		["moveUnlock.reward.1"] = "환생 1: 공중 점프 1 · 공중 공격",
		["moveUnlock.reward.2"] = "환생 2: 활강(공중에서 대시 길게)",
		["moveUnlock.reward.3"] = "환생 3: 공중 점프 2 · 공중 3타 강공격",
		["moveUnlock.reward.4"] = "환생 4: 활강 +{seconds}초 · 공중 대시 ×{mult}",
		["moveUnlock.reward.5"] = "환생 5: 무기 태초(보석 홈 {slots}칸 장착)",

		-- 환생(G1-3)
		["rebirth.confirm.title"] = "환생 - 레벨이 1로 돌아갑니다",
		["rebirth.confirm.body"] = "레벨 {level} → 1 · 스테이지 {stage} → 1(되돌릴 수 없음) - 높은 스테이지에서는 레벨만큼 약해집니다.\n얻는 것(영구): 무기 등급 +1 · 보석 칸 +1 · 경험치 ×{expFrom} → ×{expTo}\n필요 레벨 {required} · 환생 {count}/{max}회",
		["rebirth.confirm.done"] = "환생 {count}/{max}회 완료 - 더 이상 환생할 수 없습니다.",
		["rebirth.weaponPrimordialRule"] = "무기 태초 = 환생 {max}회 + 보석 홈 {slots}칸 전부 장착(마지막 환생 때 마지막 홈이 채워지며 함께 달성)", -- D1-2: 코드 조건(PlayerProfile.rebirth)과 같은 값 - 데이터에서 채운다
		["rebirth.confirm.ok"] = "환생한다",
		["rebirth.confirm.cancel"] = "취소",
		["rebirth.confirm.close"] = "닫기",
		["rebirth.levelShort"] = "레벨이 부족합니다(필요 레벨 {required})",
		["rebirth.tab.where"] = "환생은 커뮤니티 센터의 환생 제단에서 합니다(마을 한가운데 건물 앞).",
		["rebirth.tab.status"] = "환생 {count}/{max}회 · 현재 레벨 {level} · 필요 레벨 {required} · 경험치 ×{expFrom} → ×{expTo}",
		["world.communityCenter"] = "커뮤니티 센터",

		-- 보스맵 잔류(G1-4)
		["linger.title"] = "보스 처치!",
		["linger.line"] = "스테이지 {stage} 보스를 잡았습니다. {seconds}초 뒤 스테이지 {next}(으)로 자동 이동합니다.",
		["linger.lineNoNext"] = "스테이지 {stage} 보스를 잡았습니다. {seconds}초 뒤 마을로 돌아갑니다.",
		["linger.next"] = "다음 스테이지",
		["linger.retry"] = "다시 도전",
		["linger.retryVote"] = "재도전 투표",
		["linger.town"] = "마을",
		["linger.noNextReason"] = "이 보스 기록이 오르지 않아 다음 스테이지로 갈 수 없습니다",
		["linger.leaderOnly"] = "파티 리더만 신청합니다",
		["linger.cannotNext"] = "다음 스테이지로 갈 수 없어 마을로 돌아갑니다(이 보스 기록이 오르지 않았습니다)",

		-- 보스 생존 중 이동 제한 · 포기(G1-5)
		["giveup.title"] = "보스전 중에는 이동할 수 없습니다",
		["combat.stealLockHint"] = "다른 유저가 사냥중이에요", -- C1 마무리: 잠긴 몹을 처음 때렸을 때 1회 말풍선(저장 hints.stealLockSeen)
		["giveup.body"] = "포기하고 스테이지 {stage}(으)로 내려가 마을로 돌아갈까요?",
		["giveup.bodyParty"] = "포기 투표를 열까요? 통과하면 파티 전원이 스테이지 {stage}(으)로 내려가 마을로 돌아갑니다.",
		["giveup.ok"] = "포기",
		["giveup.cancel"] = "계속 싸우기",
		["giveup.reason"] = "보스전 중에는 이동할 수 없습니다(포기하면 한 스테이지 아래 마을로)",
		["vote.enter.title"] = "스테이지 이동 투표",
		["vote.giveup.title"] = "보스 포기 투표",
		["vote.giveup.leaderBody"] = "스테이지 {stage} 보스 포기 투표 중(1명 동의 시 성립)",
		["vote.giveup.body"] = "스테이지 {stage} 보스를 포기하고 한 스테이지 아래 마을로 갈까요?",
		["vote.retry.title"] = "재도전 투표",
		["vote.retry.leaderBody"] = "스테이지 {stage} 보스 재도전 투표 중(1명 동의 시 성립)",
		["vote.retry.body"] = "스테이지 {stage} 보스에 다시 도전할까요?",
		["boss.blockedInvite"] = "보스전 중에는 파티 초대를 받을 수 없습니다",
		-- BR1 대공 잡기
		["boss.grab.struggle"] = "대공 잡기 - 다 같이 점프를 연타해 발악!",
		["boss.grab.warn"] = "착지!",
		["boss.bubble.struggle"] = "공중에 갇혔다 - 점프를 연타해 탈출!",

		-- 설정 · 시점(M1-0)
		["settings.title"] = "설정",
		["settings.autoStage"] = "자동 스테이지 이동(비율 1.3 넘으면 위로)", -- C5-4
		["autoStage.moved"] = "자동 이동: 스테이지 {from} → {to}", -- C5-4
		["autoStage.bossGate"] = "보스 관문(스테이지 {stage})이 기다려요 - 도전해 보세요!", -- C5-4
		["comeback.welcome"] = "돌아온 걸 환영해요! 60분 동안 ×1.5", -- C5-5
		["generation.enter"] = "{index}세대 · {name} 몬스터가 나타납니다", -- C5-6 세대 진입(내 스테이지 기준)
		["settings.cameraTopDown"] = "탑다운 시점(위에서 내려다보기)",
		["settings.cameraTopDownHint"] = "끄면 로블록스 기본 카메라입니다. 이번 접속 동안 유지됩니다.",
		["settings.dimOthersTrail"] = "다른 유저 공격 궤적 흐리게",
		["settings.screenShake"] = "화면 흔들림(타격 · 스킬 · 보스)",
		["settings.shiftLockHint"] = "시점 고정: PC는 왼쪽 Ctrl, 모바일은 대시 버튼 옆 고정 버튼입니다.",
		["shiftLock.button"] = "고정",
		["shiftLock.chipKey"] = "[Ctrl]",
		["shiftLock.chipName"] = "시점 고정",
		["shiftLock.on"] = "ON",
		["shiftLock.off"] = "OFF",

		-- 채팅 · 알림
		["chat.primalDrop"] = "★ {name}님이 <font color=\"{color}\">{item}</font>을 얻었습니다",

		-- 덩굴 리프트 · 나무 입구 안내판(M1-2c)
		["lift.locked"] = "🔒 덩굴 리프트\nLv.{level} 필요",
		["lift.action"] = "타기",
		["lift.lockedNotice"] = "덩굴 리프트 - 역대 최고 레벨 {level}부터 첫 정거장이 열린다",
		["lift.open"] = "덩굴 리프트\n정거장 {station} · 높이 {meters}m",
		["lift.prompt"] = "타기 · 정거장 {station} (높이 {meters}m)",
		["lift.unlockToast"] = "덩굴 리프트 - 정거장 {station}({name} · 높이 {meters}m)이 열렸습니다. 길 안내를 따라가세요",
		["board.title"] = "나무 정거장 안내",
		["board.row"] = "{station}. {name} · Lv.{level} · 높이 {meters}m",
		["board.rowOpen"] = "{station}. {name} · Lv.{level} · 높이 {meters}m · 열림",
		["board.footer"] = "덩굴 리프트(줄기 옆 바구니 [F])는 가장 높은 열린 정거장으로 갑니다",

		-- 둥지 · 알(M1-3)
		["nest.action"] = "알 줍기",
		["nest.object"] = "둥지",
		["nest.gotEgg"] = "{grade} {egg} 획득! 후보: {a} / {b}",
		["nest.discovered"] = "비밀 둥지 발견! 발견 도감 {count}곳",
		["nest.title"] = "칭호 획득 - {name}",
		["nest.full"] = "알 가방이 가득 찼다({cap}개) - 더 주울 수 없다",
		["egg.title"] = "알 가방 ({count}/{cap})",
		["egg.empty"] = "아직 알이 없다 - 바위 위 · 신전 · 숨은 곳의 둥지에서 알을 주울 수 있다",
		["egg.row"] = "{egg} · {grade}",
		["egg.candidates"] = "후보 {a} / {b} (반반)",
		["egg.hatchHeader"] = "부화 결과 확률(사전 고지) - 알 등급별",
		["egg.hatchCol"] = "{grade} 알",
		["egg.dex"] = "비밀 둥지 발견 {count}곳",
		["egg.chip"] = "알",
		["guide.now"] = "지금 할 일 {index}/{total}: {text}",
		["guide.fight"] = "몬스터를 공격해 쓰러뜨리세요 (이동 WASD · 공격 클릭)",
		["guide.pickup"] = "쓰러진 몬스터가 떨군 장비를 주우세요",
		["guide.equip"] = "가방(B)에서 주운 장비를 장착하세요",
		["guide.skill"] = "스킬 Q · E · R을 한 번씩 써 보세요",
		["guide.skillCard"] = "스킬: Q · E · R = 직업 기술(쿨다운) · T = 궁극기(게이지가 차면)",
		["guide.enhance"] = "무기를 한 번 강화해 보세요",
		["guide.gem"] = "무기에 보석을 장착해 보세요",
		["guide.ult"] = "궁극기가 가득 찼어요! T를 눌러 써 보세요",
		["guide.boss"] = "스테이지 5의 첫 보스에 도전하세요",
		["guide.done"] = "첫 걸음 완료! 이제 퀘스트 창(J)의 메인 퀘스트를 따라가세요",
		["attendance.title"] = "7일 출석 ({count}/7일)",
		["attendance.day"] = "{day}일차 · {reward}",
		["attendance.reward.1"] = "펫 알 1개",
		["attendance.reward.2"] = "환생 무료권 1장",
		["attendance.reward.3"] = "골드 · 강화석 5",
		["attendance.reward.4"] = "반짝 조각 2",
		["attendance.reward.5"] = "골드 · 강화석 10",
		["attendance.reward.6"] = "펫 알 1개",
		["attendance.reward.7"] = "골드 · 반짝 조각 5",
		["prob.title"] = "확률 공개",
		["prob.row"] = "드랍 · 강화 · 옵션 · 스킬 변형 · 부화 확률(서버 굴림과 같은 표)",
		["prob.open"] = "확률 보기",
		["prob.field"] = "잡몹 장비 등급(장비 1개당 · 감쇠 전)",
		["prob.boss"] = "보스 보상 등급(모든 보스 같은 표)",
		["prob.firstClear"] = "첫 클리어: ",
		["prob.raid"] = "토벌 · 재도전(전투 {sec}초 이상 기준 · 더 짧으면 고대 이상 몫이 비례해 영웅으로): ",
		["prob.sparkle"] = "반짝이 몬스터: ",
		["prob.enhance"] = "무기 강화(게이지 · 방지권 없이)",
		["prob.option"] = "옵션 리롤 · 드랍 옵션(내 직업 풀 - 균등)",
		["prob.optionOff"] = "지금 꺼진 옵션: {list}",
		["prob.variant"] = "스킬 변형(영웅 이상 장비의 {appear} · 리롤 = 몬스터 {kills}마리분 골드)",
		["prob.hatch"] = "부화 결과(부화 레벨 × 알 등급 - 일반/고급/희귀/영웅 %)",
		["prob.version"] = "표 버전 {version}",
		["pet.hatch"] = "부화",
		["pet.hatchingHeader"] = "부화 중 {n}/{cap}",
		["pet.left"] = "{s}초 남음",
		["pet.ready"] = "부화 완료",
		["pet.claim"] = "받기",
		["pet.listHeader"] = "펫 {n}/{cap} · 자동 줍기 {auto}",
		["pet.autoOn"] = "켜짐(펫 동행)",
		["pet.autoOff"] = "Lv.{level}에 열림",
		["pet.equip"] = "데리고 다니기",
		["pet.unequip"] = "내려놓기",
		["pet.levelHeader"] = "부화 레벨 {level}(누적 부화 {count}) - 레벨별 결과 확률(일반/고급/희귀/영웅 %)",
		["pet.levelRow"] = "Lv.{level}(부화 {hatches}회~): {rows}",

		-- 도움말(백과사전) 항목 - 창 UI는 P4(목록 = HelpCodexData)
		["codex.stealLock.title"] = "다른 유저가 사냥중인 몬스터",
		["codex.stealLock.body"] = "체력바가 회색이고 자물쇠가 보이면 다른 유저가 먼저 사냥 중인 몬스터예요. 공격이 튕겨 나가요. 그 유저가 잠시 떠나면 자물쇠가 풀려요. 비슷한 성장 단계(같은 환생 · 가까운 레벨 · 가까운 스테이지)끼리는 같이 공격할 수 있고, 몬스터 체력의 {percent}% 이상 깎으면 보상을 받아요.", -- percent = CombatConfig.contributionRewardThreshold × 100(창이 넘긴다)
		-- C2 권장 전투력(자리만 - 최종 스타일 U1): 스테이지 선택 · 구역 입구
		["combat.recommend"] = "권장 전투력 {rec} / 내 전투력 {mine}", -- rec · mine = NumberFormat.format(CombatFormula.display(...))
		-- QUEUE-10h Q7 장비 툴팁 줄(ItemDescribe.item note)
		["item.setLine"] = "세트: {name}",
		["item.sourceLine"] = "출처: {source}",
		-- QUEUE-10h Q6 · Q7 퀘스트 · 수련 창(panels/Quests)
		["quests.title"] = "퀘스트 · 수련",
		["quests.login"] = "오늘의 첫 접속 보상",
		["quests.main"] = "메인 퀘스트 {index}/{total} - {name}",
		["quests.mainUnlock"] = "열리는 것: {unlock}",
		["quests.mainDone"] = "메인 퀘스트를 모두 마쳤습니다",
		["quests.daily"] = "일간 퀘스트(매일 UTC 0시 초기화)",
		["quests.weekly"] = "주간 퀘스트(월요일 초기화)",
		["quests.chest"] = "일간 완료 상자",
		["quests.progress"] = "{name} ({n}/{target})",
		["quests.claim"] = "받기",
		["quests.claimed"] = "받음",
		["quests.training"] = "공용 수련(모든 직업)",
		["quests.abilities"] = "직업 고유 능력(지금 직업)",
		["quests.trainRow"] = "{name} {level}/{cap} · 단계당 +{per}%",
		["quests.trainButton"] = "{cost} 골드",
		["quests.trainCap"] = "상한",
		["quests.currencies"] = "반짝 조각 {shard} · 시즌 패스 경험치 {pass}",
	},
}
