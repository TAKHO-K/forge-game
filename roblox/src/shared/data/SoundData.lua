-- B4 사운드 훅 자리값 표(음원 없이 뼈대만). 재생 = client/SoundHooks.client.lua · 계산(음량 곱 · 빈 ID 무시 · 드랍 등급 매핑) = shared/SoundCue.lua.
--   categories[id].settingKey = SettingsData 키(음량 설정 · Attribute는 그 키의 attrs[1]).
--   events[id] = { category, soundId = "" (자리값 - 비어 있으면 재생 안 함 · 오류 없음), volume(음원 기본 음량), pitch(PlaybackSpeed), minInterval(같은 이벤트 연타 간격 - 초) }.
--   음원을 넣을 때는 soundId만 "rbxassetid://..."로 채운다. 소리는 보조 단서다 - 시각 전조를 지우지 않는다(docs/design/sound-accessibility-check.md).
return {
	categories = {
		sfx = { settingKey = "volumeSfx" },
		music = { settingKey = "volumeMusic" },
		ui = { settingKey = "volumeUi" },
		bossCue = { settingKey = "volumeBossCue" },
	},
	categoryOrder = { "sfx", "music", "ui", "bossCue" }, -- 설정 창 줄 순서
	spatialMaxDistance = 80, -- 자리가 있는 소리(땅 드랍)가 들리는 최대 거리(스터드 - Sound.RollOffMaxDistance)
	events = {
		hit = { category = "sfx", soundId = "", volume = 0.5, pitch = 1, minInterval = 0.05 }, -- 기본 공격 적중(AttackResult)
		hitCrit = { category = "sfx", soundId = "", volume = 0.7, pitch = 1, minInterval = 0.05 }, -- 치명 적중
		enhanceSuccess = { category = "ui", soundId = "", volume = 0.8, pitch = 1 }, -- 강화 성공(EnhanceResult)
		enhanceGreat = { category = "ui", soundId = "", volume = 1, pitch = 1 }, -- 강화 대성공(= 성공 + 서버 방송 단계 EnhanceConfig.announceFromLevel 이상)
		enhanceFail = { category = "ui", soundId = "", volume = 0.8, pitch = 1 }, -- 강화 실패(유지 · 하락 · 초기화)
		dropLow = { category = "sfx", soundId = "", volume = 0.4, pitch = 1, minInterval = 0.1 }, -- 땅 드랍(일반 · 희귀)
		dropMid = { category = "sfx", soundId = "", volume = 0.6, pitch = 1, minInterval = 0.1 }, -- 영웅 · 전설
		dropHigh = { category = "sfx", soundId = "", volume = 0.8, pitch = 1 }, -- 유물 · 고대
		dropTop = { category = "sfx", soundId = "", volume = 1, pitch = 1 }, -- 태초 · 초월
		levelUp = { category = "ui", soundId = "", volume = 0.8, pitch = 1 }, -- 캐릭터 레벨업(Attribute CharacterLevel)
		rebirth = { category = "ui", soundId = "", volume = 1, pitch = 1 }, -- 환생 성공(RebirthResult)
		bossCue = { category = "bossCue", soundId = "", volume = 1, pitch = 1, minInterval = 0.2 }, -- 보스 전조(BossPatternEvent - 아래 bossCueKinds)
		petHatch = { category = "ui", soundId = "", volume = 0.9, pitch = 1 }, -- 펫 부화(PetSync hatchCount 증가)
	},
	-- 드랍 등급(ArmorData.grades[].id) → 이벤트. 표에 없는 등급 = 소리 없음.
	dropGradeEvents = {
		normal = "dropLow",
		rare = "dropLow",
		epic = "dropMid",
		legendary = "dropMid",
		relic = "dropHigh",
		ancient = "dropHigh",
		primordial = "dropTop",
		transcendent = "dropTop",
	},
	-- 보스 전조로 보는 BossPatternEvent 종류. bubble = 모든 스킬이 전조 시작 순간 한 번 보내는 말풍선(server/BossPatterns.lua startSkill) ·
	-- envTelegraph = 환경 변화 전조(BossEnvironment - 스킬 밖 일정) · regrowTelegraph = 지형 재생성 전조(스킬 밖 일정).
	bossCueKinds = { bubble = true, envTelegraph = true, regrowTelegraph = true },
}
