-- 플레이어가 보는 문장 원문(G1-1 - shared/Text.get이 읽는다). 키 = "화면.용도" · 값 = 한 문장 전체 템플릿({이름} = 인자).
-- 규칙(COMMON §2): 한 문장은 한 템플릿이다(조각 이어붙이기 금지) · 인자는 이름으로 · 숫자는 호출하는 쪽이 형식을 정해 문자열로 넘긴다.
-- G1-1부터 새로 쓰거나 고친 문장만 여기 있다. 옛 문장은 L(번역) 단계에서 옮긴다.
return {
	ko = {
		-- ? 도움말 2단(HelpTooltip)
		["help.more"] = "눌러서 자세히 ▼",
		["help.less"] = "접기 ▲",

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

		-- 환생(G1-3)
		["rebirth.confirm.title"] = "환생 - 레벨이 1로 돌아갑니다",
		["rebirth.confirm.body"] = "레벨 {level} → 1 · 스테이지 {stage} → 1(되돌릴 수 없음) - 높은 스테이지에서는 레벨만큼 약해집니다.\n얻는 것(영구): 무기 등급 +1 · 보석 칸 +1 · 경험치 ×{expFrom} → ×{expTo}\n필요 레벨 {required} · 환생 {count}/{max}회",
		["rebirth.confirm.done"] = "환생 {count}/{max}회 완료 - 더 이상 환생할 수 없습니다.",
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
		["boss.grab.struggle"] = "대공 잡기 - 점프를 연타해 발버둥!",
		["boss.grab.warn"] = "착지!",

		-- 설정 · 시점(M1-0)
		["settings.title"] = "설정",
		["settings.cameraTopDown"] = "탑다운 시점(위에서 내려다보기)",
		["settings.cameraTopDownHint"] = "끄면 로블록스 기본 카메라입니다. 이번 접속 동안 유지됩니다.",
		["settings.shiftLockHint"] = "시점 고정: PC는 왼쪽 Ctrl, 모바일은 대시 버튼 옆 고정 버튼입니다.",
		["shiftLock.button"] = "고정",
		["shiftLock.chipKey"] = "[Ctrl]",
		["shiftLock.chipName"] = "시점 고정",
		["shiftLock.on"] = "ON",
		["shiftLock.off"] = "OFF",

		-- 채팅 · 알림
		["chat.primalDrop"] = "★ {name}님이 <font color=\"{color}\">{item}</font>을 얻었습니다",
	},
}
