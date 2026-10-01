-- QUEUE-ALL7 C 소리 믹스(손으로 고치는 표 - SoundSheetData는 생성 파일이라 건드리지 않는다). 적용 = client/SoundSheet 한 곳 · 소리 지도 = docs/phase/sound-map.md.
--   최종 Sound.Volume = tierVolume[cue 단계] × gain(측정으로 체감 크기 맞춤) × 호출 opts.volume × (남의 소리면 otherScale - T1 · T2 예외)
--   SoundGroup.Volume = groups[이름] × 설정 음량(SoundVolumeSfx · Ui · Ambient · Music) × 덕킹(초월 동안 Music · Ambient)
return {
	-- SoundGroup 4개(시트 데이터의 Effects = SFX)
	groups = { Music = 0.35, Ambient = 0.25, SFX = 0.6, UI = 0.4 },
	groupAlias = { Effects = "SFX" },
	-- 중요도 단계 → 상대 크기(SFX 안) · ui = UI 그룹 안 · ambient = 환경 그룹 안
	tierVolume = { [1] = 1.0, [2] = 0.85, [3] = 0.7, [4] = 0.5, [5] = 0.35, ui = 0.3, ambient = 1.0 },
	-- 큐 → 단계 · gain(측정 맞춤 - sound-map.md) · jitter(음높이 ± 무작위 - 반복 피로)
	cues = {
		drop_transcendent = { tier = 1 },
		drop_primordial = { tier = 2 },
		boss_death = { tier = 2 },
		warning = { tier = 2 }, -- 보스 강공격 · 패턴 예고(전조 있는 공격만 - BossPatternEvent bubble · envTelegraph · regrowTelegraph)
		level_up = { tier = 3 },
		enhance_success = { tier = 3 },
		enhance_reset = { tier = 3 },
		enhance_drop = { tier = 3 },
		drop_legendary = { tier = 3 },
		drop_relic = { tier = 3 },
		drop_ancient = { tier = 3 },
		quest_complete = { tier = 3 }, -- 퀘스트 완료 · 합동 목표 단계 달성
		title_get = { tier = 3 },
		skill_unlock = { tier = 3 },
		rocket_twinkle = { tier = 3 }, -- E3 판 털기 로켓 반짝
		rift_start = { tier = 3 },
		checkpoint_found = { tier = 3 },
		boss_appear = { tier = 3 },
		codex_cell = { tier = 3 }, -- 도감 칸 · 펫 부화
		hit_crit = { tier = 4, jitter = 0.05 },
		hurt_big = { tier = 4, jitter = 0.05 }, -- 전조 있는 큰 공격에 맞음(작은 피격보다 한 단계 위)
		drop_epic = { tier = 4 }, -- 영웅부터 차임
		enhance_fail = { tier = 4 },
		protect_ticket = { tier = 4 },
		recall_done = { tier = 4 },
		swing = { tier = 5, jitter = 0.05, gain = 0.7, maxSeconds = 0.14 }, -- 대시 · 회피(휘두름 바람 소리 재사용 - 새 업로드 없음) · 사용자: 자주 쓰니 거슬리지 않게 짧게 = T5 · × 0.7 · 앞 0.14초만
		reward_fly = { tier = 5 }, -- 도감 · 보상 받기 날아감
		hit_light = { tier = 5, jitter = 0.05 },
		hit_heavy = { tier = 5, jitter = 0.05 },
		hurt_small = { tier = 5, jitter = 0.05 },
		heartbeat = { tier = 5 },
		pickup = { tier = 5, jitter = 0.05 },
		footstep_soft = { tier = 5, jitter = 0.05 },
		drop_rare = { tier = 5 }, -- (안 씀 - 희귀 = drop_common 1음)
		drop_common = { tier = 5 }, -- 희귀 드랍 = 아주 작은 1음 · 일반 = 소리 없음
		button_press = { tier = "ui" },
		button_close = { tier = "ui" },
		recall_channel = { tier = "ambient" },
		checkpoint_channel = { tier = "ambient" },
	},
	otherScale = 0.5, -- 남이 낸 소리(같은 단계라도)
	otherQuietScale = 0.25, -- 설정 "다른 플레이어 효과음 줄이기" 켬
	otherExemptTiers = { [1] = true, [2] = true }, -- 초월 · 태초 · 보스 예고는 남 것도 그대로(알림 규칙)
	rollOffMaxDistance = 70, -- 3D 소리 최대 거리(stud)
	-- 동시 재생 제한
	perCueMax = 3,
	minIntervalDefault = 0.06,
	sfxMax = 12, -- SFX 전체 동시(넘치면 가장 낮은 단계부터 버림 - T5 → T4 …)
	-- 초월(T1) 덕킹: 재생 동안 Music · Ambient 그룹 × duckScale 을 duckSeconds
	duck = { tier = 1, groups = { "Music", "Ambient" }, scale = 0.5, seconds = 3 },
	-- 묶음: 낱개 줍기 = 이 시간 안 여러 번이면 소리 1번
	pickupBundleSeconds = 0.2,
	-- 드랍 등급 → 큐(nil = 소리 없음) - 시트의 dropGradeCues 대신(일반 = 없음 · 희귀 = 작은 1음 · 영웅부터 차임)
	dropGradeCues = {
		rare = "drop_common",
		epic = "drop_epic",
		legendary = "drop_legendary",
		relic = "drop_relic",
		ancient = "drop_ancient",
		primordial = "drop_primordial",
		transcendent = "drop_transcendent",
	},
}
