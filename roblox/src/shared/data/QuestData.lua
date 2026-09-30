-- QUEUE-10h Q6 G3 퀘스트 한 시스템(일간 · 주간 · 일일 첫 접속 보상 · 일일 완료 상자 · 메인 퀘스트). 계산 = shared/Quest.lua(순수) · 서버 = server/QuestService.lua · 저장 = profile.quests(SAVE v50).
--   §7-6: 기존 출석 · 의뢰판 · 시즌 미션 코드는 없었다(검색 0) → 이 파일이 단일 시스템. Q12 FTUE · 7일 출석도 여기 events · rewards를 재사용한다.
--   날짜 = 서버 UTC 날짜(os.date("!*t")) · 주 = 월요일 시작 UTC. 일간 = pool에서 dailyCount개(날짜 시드 - 모두에게 같은 목록) · 주간 = weekly 전부.
--   이벤트 이름(QuestService.note가 받는 것): kill(잡몹 처치) · bossClear(보스 처치 - 첫 클리어 · 재도전 · 토벌) · raidClear · enhance(강화 시도) · gem(보석 장착 · 재련) · egg(알 획득) · train(수련 · 능력 구매) · sparkle(반짝이 처치).
--   보상 = { gold = 몇 마리분(GoldCost "quest" × 계정 최고 스테이지), enhanceStone = n, egg = n(구역 = tier1 · 등급 보통 - 펫 단계에서 구역 선택), sparkleShard = n(반짝 조각 - 새 재화 자리), passExp = n(시즌 패스 경험치 자리) }.
return {
	dailyCount = 3,
	dailyPool = {
		{ id = "d_kill", event = "kill", target = 150, name = "몬스터 {n}마리 처치", reward = { gold = 120, passExp = 20 } },
		{ id = "d_boss", event = "bossClear", target = 1, name = "보스 {n}번 처치", reward = { gold = 150, enhanceStone = 3, passExp = 20 } },
		{ id = "d_enhance", event = "enhance", target = 3, name = "무기 강화 {n}번 시도", reward = { gold = 60, enhanceStone = 5, passExp = 20 } },
		{ id = "d_gem", event = "gem", target = 1, name = "보석 장착 · 재련 {n}번", reward = { gold = 80, sparkleShard = 1, passExp = 20 } },
		{ id = "d_egg", event = "egg", target = 1, name = "둥지에서 알 {n}개 줍기", reward = { gold = 80, passExp = 20 } },
		{ id = "d_train", event = "train", target = 1, name = "수련 · 직업 능력 {n}번 올리기", reward = { gold = 60, passExp = 20 } },
	},
	weekly = {
		{ id = "w_kill", event = "kill", target = 3000, name = "몬스터 {n}마리 처치", reward = { gold = 900, passExp = 100 } },
		{ id = "w_boss", event = "bossClear", target = 15, name = "보스 {n}번 처치", reward = { gold = 900, enhanceStone = 20, passExp = 100 } },
		{ id = "w_raid", event = "raidClear", target = 3, name = "토벌 {n}번", reward = { gold = 600, sparkleShard = 3, passExp = 100 } },
		{ id = "w_enhance", event = "enhance", target = 20, name = "무기 강화 {n}번 시도", reward = { gold = 400, enhanceStone = 25, passExp = 100 } },
		{ id = "w_sparkle", event = "sparkle", target = 1, name = "반짝이 몬스터 {n}마리 처치", reward = { gold = 600, egg = 1, passExp = 100 } },
	},
	loginReward = { gold = 100, enhanceStone = 2, passExp = 10 }, -- 일일 첫 접속(날짜가 바뀐 뒤 첫 접속 - 받기 버튼)
	dailyChest = { gold = 300, enhanceStone = 10, egg = 1, sparkleShard = 2, passExp = 50 }, -- 그날 일간 전부 완료 뒤 1회
	-- Q12 P4a 첫 5분 이정표(보상 없음 - 보상은 위 메인 퀘스트 한 곳 · 중복 금지 §7-6). 이벤트가 오면 다음 단계(순서대로) · 끝나면 nil.
	--   funnel = 온보딩 퍼널 이벤트 이름(Q15 Telemetry가 받는다) · fillUlt = 이 단계에 들어서면 궁극기 게이지를 한 번 가득(맛보기) · card = 스킬 안내 카드 1장(TextData 키).
	--   동선(사냥터 길 안내 · 대장간 위치)은 H1 배치 뒤 조정 - 지금은 글 안내만. 상점은 이정표에 안 나온다.
	ftue = {
		{ id = "g_fight", event = "kill", text = "guide.fight", funnel = "ftue_fight" },
		{ id = "g_pickup", event = "pickup", text = "guide.pickup", funnel = "ftue_drop" },
		{ id = "g_equip", event = "equip", text = "guide.equip", funnel = "ftue_equip" },
		{ id = "g_skill", event = "skill", text = "guide.skill", card = "guide.skillCard", funnel = "ftue_skill" },
		{ id = "g_enhance", event = "enhance", text = "guide.enhance", funnel = "ftue_enhance" },
		{ id = "g_gem", event = "gem", text = "guide.gem", funnel = "ftue_gem" },
		{ id = "g_ult", event = "ult", text = "guide.ult", fillUlt = true, funnel = "ftue_ult" },
		{ id = "g_boss", event = "bossClear", text = "guide.boss", funnel = "ftue_boss" },
	},
	-- Q12 누적 7일 출석(신규 계정마다 - 서버 UTC 날짜 · 접속한 날만 센다 · 빠진 날은 건너뛰지 않고 다음 칸). 보상 지급 = QuestService.grant 한 곳.
	--   rebirthTicket = 환생 무료권(자리 - 지금 환생은 비용이 없다 → 쓰는 곳 없음 · 결정 필요) · 성장 곡선은 무료권 없이 맞춘다(EconSim 무관).
	attendance = {
		{ day = 1, reward = { egg = 1 } },
		{ day = 2, reward = { rebirthTicket = 1 } },
		{ day = 3, reward = { gold = 200, enhanceStone = 5 } },
		{ day = 4, reward = { sparkleShard = 2 } },
		{ day = 5, reward = { gold = 300, enhanceStone = 10 } },
		{ day = 6, reward = { egg = 1 } },
		{ day = 7, reward = { gold = 500, sparkleShard = 5 } },
	},
	-- QUEUE-ALL3 Q3(10 문서 3절 · 9-A): 초반 여정 = 메인 퀘스트 사슬(한 번에 하나 · 끝나면 다음). 첫 약 2시간(견습 → 첫 보스 → 강화 · 수련 → 구역 2 → 알 · 부화 · 도감 → 보스 스테이지 → 첫 환생 → 새 스킬 · 파티 · 균열)을
	--   실제 해금 순서대로 + 탐험 단계(체크포인트 · 전망대 · 사냥 지대 둘러보기)를 사이사이에 · 그 뒤 = 옛 환생 단계.
	--   cond: tutorial · bossCleared(value) · weaponLevel(value) · gemSocketed · eggs · rebirth · level · checkpoints(= 사실 - 서버 PlayerProfile.getQuestFacts) / event(event · target = 이 단계에 들어선 뒤 센 수 - quests.mainN · SAVE v60).
	--   guide = [길 안내] 목적지(client/QuestGuide가 자리로 바꾼다): gate(지금 보스 관문) · hunt(지금 구역 사냥 지대) · forge · altar(환생 제단) · hub · lookout(큰 나무 전망대) · zone:<key> · checkpoint(가장 가까운 안 찾은 입구 캠프) · nil = 창.
	--   보상 = 단계가 오를수록 커진다(골드 = 몇 마리분 × 계정 최고 스테이지 GoldCost "quest" · 강화석 늘어남) + 그 구간에 필요한 도움 재화(새 재화 없음):
	--   알 줍기 직후 = 알 1 · 보석 첫 장착 = 보석 가루 · 첫 환생 직전 = 강화석 묶음 · 하락 구간(+19) 앞 = 하락 방지권 1 · 합계 골드 = 5560마리분(옛 10단계 3,450 · 두 번째 환생까지 3,460 vs 옛 1,450 · EconSim 모형 밖 = 옛 메인도 모형 밖).
	--   옛 저장(main = 옛 10단계 번호)은 v60 이관이 같은 id의 새 번호로 옮긴다(SaveSystem - legacyMainIds).
	legacyMainIds = { "m_ftue", "m_boss1", "m_enhance", "m_gem", "m_egg", "m_rebirth1", "m_rebirth2", "m_rebirth3", "m_rebirth4", "m_rebirth5" },
	main = {
		{ id = "m_ftue", cond = "tutorial", name = "견습 과정 마치기", guide = nil, reward = { gold = 40, enhanceStone = 2 } },
		{ id = "m_hunt20", cond = "event", event = "kill", target = 20, name = "사냥터에서 몬스터 {n}마리 처치", guide = "hunt", reward = { gold = 40, enhanceStone = 2 } },
		{ id = "m_equip", cond = "event", event = "equip", target = 1, name = "주운 장비 입기(가방 G)", guide = nil, reward = { gold = 40, enhanceStone = 2 } },
		{ id = "m_boss1", cond = "bossCleared", value = 5, name = "첫 보스(스테이지 5) 처치", guide = "gate", reward = { gold = 60, enhanceStone = 3 } },
		{ id = "m_enhance3", cond = "weaponLevel", value = 3, name = "무기 강화 +{n}", guide = "forge", reward = { gold = 60, enhanceStone = 3 } },
		{ id = "m_train1", cond = "event", event = "train", target = 1, name = "수련 1번 하기(U)", guide = nil, reward = { gold = 60, enhanceStone = 3 } },
		{ id = "m_boss10", cond = "bossCleared", value = 10, name = "보스 스테이지 {n} 처치", guide = "gate", reward = { gold = 80, enhanceStone = 4 } },
		{ id = "m_zone2", cond = "event", event = "zone:tier2", target = 1, name = "두 번째 구역(수정 동굴) 가 보기", guide = "zone:tier2", reward = { gold = 80, enhanceStone = 4 } },
		{ id = "m_checkpoint3", cond = "checkpoints", value = 3, name = "체크포인트 {n}곳 찾기", guide = "checkpoint", reward = { gold = 80, enhanceStone = 4 } },
		{ id = "m_egg", cond = "eggs", value = 1, name = "둥지에서 알 줍기", guide = nil, reward = { gold = 90, egg = 1 } },
		{ id = "m_hatch", cond = "event", event = "hatch", target = 1, name = "알 부화하기", guide = "hub", reward = { gold = 90, enhanceStone = 5 } },
		{ id = "m_codex", cond = "event", event = "codexClaim", target = 1, name = "도감 칸 1개 받기(K)", guide = nil, reward = { gold = 90, enhanceStone = 5 } },
		{ id = "m_enhance6", cond = "weaponLevel", value = 6, name = "무기 강화 +{n}", guide = "forge", reward = { gold = 100, enhanceStone = 6 } },
		{ id = "m_lookout", cond = "event", event = "lookout", target = 1, name = "큰 나무 전망대에 오르기", guide = "lookout", reward = { gold = 100, enhanceStone = 6 } },
		{ id = "m_boss15", cond = "bossCleared", value = 15, name = "보스 스테이지 {n} 처치", guide = "gate", reward = { gold = 110, enhanceStone = 6 } },
		{ id = "m_gem", cond = "gemSocketed", value = 1, name = "무기에 보석 장착", guide = "forge", reward = { gold = 110, gemDust = 30 } },
		{ id = "m_grounds", cond = "event", event = "ground", target = 3, name = "사냥 지대 {n}곳 둘러보기", guide = "hunt", reward = { gold = 110, enhanceStone = 7 } },
		{ id = "m_boss20", cond = "bossCleared", value = 20, name = "보스 스테이지 {n} 처치", guide = "gate", reward = { gold = 120, enhanceStone = 7 } },
		{ id = "m_enhance10", cond = "weaponLevel", value = 10, name = "무기 강화 +{n}", guide = "forge", reward = { gold = 120, enhanceStone = 8 } },
		{ id = "m_boss25", cond = "bossCleared", value = 25, name = "보스 스테이지 {n} 처치", guide = "gate", reward = { gold = 130, enhanceStone = 8 } },
		{ id = "m_level25", cond = "level", value = 25, name = "레벨 {n} 달성", guide = "hunt", reward = { gold = 140, enhanceStone = 20 } }, -- 첫 환생 직전 = 강화석 묶음
		{ id = "m_rebirth1", cond = "rebirth", value = 1, name = "첫 환생(환생 제단)", guide = "altar", reward = { gold = 200, sparkleShard = 2 } },
		{ id = "m_skillE", cond = "event", event = "skill:E", target = 1, name = "새 스킬 E 써 보기", guide = nil, reward = { gold = 150, enhanceStone = 8 } },
		{ id = "m_partyBoss", cond = "event", event = "partyBoss", target = 1, name = "파티로 보스 1번 잡기(P)", guide = "gate", reward = { gold = 180, enhanceStone = 10, sparkleShard = 1 } },
		{ id = "m_rift", cond = "event", event = "riftKill", target = 10, name = "균열 시간에 몬스터 {n}마리", guide = "hunt", reward = { gold = 180, enhanceStone = 10 } },
		{ id = "m_boss50", cond = "bossCleared", value = 50, name = "보스 스테이지 {n} 처치", guide = "gate", reward = { gold = 200, enhanceStone = 12 } },
		{ id = "m_enhance15", cond = "weaponLevel", value = 15, name = "무기 강화 +{n}", guide = "forge", reward = { gold = 200, enhanceStone = 12, protectDrop = 1 } }, -- 하락 구간(+19) 앞 = 하락 방지권 1
		{ id = "m_rebirth2", cond = "rebirth", value = 2, name = "두 번째 환생", guide = "altar", reward = { gold = 300, sparkleShard = 2 } },
		{ id = "m_skillR", cond = "event", event = "skill:R", target = 1, name = "새 스킬 R 써 보기", guide = nil, reward = { gold = 200, enhanceStone = 12 } },
		{ id = "m_rebirth3", cond = "rebirth", value = 3, name = "세 번째 환생", guide = "altar", reward = { gold = 500, sparkleShard = 3 } },
		{ id = "m_rebirth4", cond = "rebirth", value = 4, name = "네 번째 환생", guide = "altar", reward = { gold = 600, sparkleShard = 3 } },
		{ id = "m_rebirth5", cond = "rebirth", value = 5, name = "다섯 번째 환생", guide = "altar", reward = { gold = 1000, sparkleShard = 5 } },
	},
}
