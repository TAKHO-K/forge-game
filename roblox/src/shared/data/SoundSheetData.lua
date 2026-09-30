-- 생성 파일(roblox/tools/audio/make_sfx.py) - 손으로 고치지 않는다. 원본 JSON = roblox/art/audio/sfx_sheet.json.
-- 사운드 시트: 짧은 효과음 여러 개를 파일 하나에 이어 붙였다(docs/design/v2/09-visual-gui-sound.md C절 - 오디오 업로드 한도 절약).
--   sheets[id].file = roblox/art 기준 경로(확장자 뺌). 업로드 뒤 에셋 id는 shared/data/ArtAssetIds.lua의 같은 키("audio/sfx_combat" 등)에서 읽는다.
--   cues[id] = { sheet, start(초), duration(초), volume(권장 기본 음량 0 ~ 1), group(SoundGroup 이름) }.
--   재생 = 시트 Sound의 PlaybackRegion = NumberRange.new(start, start + duration) (PlaybackRegionsEnabled = true). 큐 사이 무음 0.3초.
--   모든 큐는 피크 -1 dBFS로 맞췄다 - 크기 차이는 volume으로만 준다.
return {
	sheets = {
		combat = { file = "audio/sfx_combat", length = 9.64 },
		loot = { file = "audio/sfx_loot", length = 24.4244 },
		ui = { file = "audio/sfx_ui", length = 8.2854 },
	},
	cues = {
		hit_light = { sheet = "combat", start = 0.25, duration = 0.18, volume = 0.55, group = "Effects" }, -- 일반 타격 - 톡 튀는 둔탁음
		hit_heavy = { sheet = "combat", start = 0.73, duration = 0.37, volume = 0.7, group = "Effects" }, -- 내 강공격 적중 - 더 낮고 묵직함
		hit_crit = { sheet = "combat", start = 1.4, duration = 0.43, volume = 0.7, group = "Effects" }, -- 치명타 - 타격음 위에 반짝이는 종
		swing = { sheet = "combat", start = 2.13, duration = 0.24, volume = 0.4, group = "Effects" }, -- 휘두름 바람 소리
		hurt_small = { sheet = "combat", start = 2.67, duration = 0.2, volume = 0.45, group = "Effects" }, -- 내가 작은 피해를 받음 - 부드럽게
		hurt_big = { sheet = "combat", start = 3.17, duration = 0.52, volume = 0.75, group = "Effects" }, -- 전조 있는 큰 공격에 맞음 - 무거운 쿵
		heartbeat = { sheet = "combat", start = 3.99, duration = 0.47, volume = 0.35, group = "Effects" }, -- 체력 낮음 심장 박동 - 낮은 두 번 쿵(은은하게)
		warning = { sheet = "combat", start = 4.76, duration = 0.36, volume = 0.6, group = "Effects" }, -- 보스 전조 주의 - 짧은 두 음(사이렌 아님)
		boss_appear = { sheet = "combat", start = 5.42, duration = 1.14, volume = 0.85, group = "Effects" }, -- 보스 등장 - 저음 뿔 + 북
		boss_death = { sheet = "combat", start = 6.86, duration = 2.08, volume = 0.9, group = "Effects" }, -- 보스 처치 - 큰 충격 + 하강 + 차임
		footstep_soft = { sheet = "combat", start = 9.24, duration = 0.1, volume = 0.2, group = "Effects" }, -- 부드러운 발소리(선택)
		pickup = { sheet = "loot", start = 0.25, duration = 0.2101, volume = 0.5, group = "Effects" }, -- 아이템 줍기 - 짧은 두 음 삑
		drop_common = { sheet = "loot", start = 0.7601, duration = 0.37, volume = 0.4, group = "Effects" }, -- 일반 등급 드랍
		drop_rare = { sheet = "loot", start = 1.4301, duration = 0.43, volume = 0.45, group = "Effects" }, -- 희귀 등급 드랍
		drop_epic = { sheet = "loot", start = 2.1601, duration = 0.94, volume = 0.55, group = "Effects" }, -- 영웅 등급 드랍 - 종 추가
		drop_legendary = { sheet = "loot", start = 3.4002, duration = 0.975, volume = 0.6, group = "Effects" }, -- 전설 등급 드랍
		drop_relic = { sheet = "loot", start = 4.6751, duration = 1.0071, volume = 0.7, group = "Effects" }, -- 유물 등급 드랍 - 반짝이 층 추가
		drop_ancient = { sheet = "loot", start = 5.9822, duration = 1.1595, volume = 0.8, group = "Effects" }, -- 고대 등급 드랍 - 반짝이 + 화음 층
		drop_primordial = { sheet = "loot", start = 7.4417, duration = 1.2869, volume = 0.9, group = "Effects" }, -- 태초 등급 드랍 - 반짝이 + 화음 + 저음 부풀기
		drop_transcendent = { sheet = "loot", start = 9.0287, duration = 2.52, volume = 1, group = "Effects" }, -- 초월 등급 드랍 - 암전 저음 쿵 → 상승 스윕 → 밝은 화음
		enhance_success = { sheet = "loot", start = 11.8486, duration = 0.78, volume = 0.8, group = "UI" }, -- 강화 성공 - 오르는 세 음 + 종
		enhance_fail = { sheet = "loot", start = 12.9287, duration = 0.47, volume = 0.7, group = "UI" }, -- 강화 실패(유지) - 둔탁음 + 내려가는 두 음
		enhance_drop = { sheet = "loot", start = 13.6987, duration = 0.82, volume = 0.75, group = "UI" }, -- 강화 등급 하락 - 슬픈 하강
		enhance_reset = { sheet = "loot", start = 14.8187, duration = 1.4278, volume = 0.85, group = "UI" }, -- 강화 초기화 - 긴 추락 + 무거운 쿵
		protect_ticket = { sheet = "loot", start = 16.5465, duration = 0.78, volume = 0.7, group = "UI" }, -- 보호권 사용 - 방패 딩
		level_up = { sheet = "loot", start = 17.6265, duration = 1.12, volume = 0.8, group = "UI" }, -- 레벨업 - 오르는 아르페지오
		codex_cell = { sheet = "loot", start = 19.0465, duration = 0.62, volume = 0.6, group = "UI" }, -- 도감 칸 채움 - 수집 딩
		title_get = { sheet = "loot", start = 19.9665, duration = 0.9591, volume = 0.8, group = "UI" }, -- 칭호 획득 - 짧은 팡파르
		quest_complete = { sheet = "loot", start = 21.2256, duration = 0.7787, volume = 0.7, group = "UI" }, -- 퀘스트 완료 - 짧은 징글
		reward_fly = { sheet = "loot", start = 22.3043, duration = 0.3, volume = 0.45, group = "UI" }, -- 보상 아이콘 날아감 - 쉭 + 삑
		skill_unlock = { sheet = "loot", start = 22.9044, duration = 1.22, volume = 0.8, group = "UI" }, -- 스킬 해금 - 반짝이는 공개음
		button_press = { sheet = "ui", start = 0.25, duration = 0.09, volume = 0.35, group = "UI" }, -- UI 버튼 누름 - 부드러운 딸깍
		button_close = { sheet = "ui", start = 0.64, duration = 0.08, volume = 0.3, group = "UI" }, -- 창 닫기 - 더 낮고 부드러운 딸깍
		recall_channel = { sheet = "ui", start = 1.02, duration = 1.52, volume = 0.4, group = "Ambient" }, -- 귀환 시전 중 - 반복 가능한 반짝 웅(약 1.5초)
		recall_done = { sheet = "ui", start = 2.84, duration = 0.95, volume = 0.7, group = "Effects" }, -- 귀환 완료 - 순간이동 쉭
		checkpoint_found = { sheet = "ui", start = 4.0901, duration = 0.6553, volume = 0.7, group = "Effects" }, -- 체크포인트 발견 - 발견 차임
		checkpoint_channel = { sheet = "ui", start = 5.0454, duration = 1.52, volume = 0.4, group = "Ambient" }, -- 체크포인트 등록 중 - 집중 웅(약 1.5초 · 반복 가능)
		rift_start = { sheet = "ui", start = 6.8654, duration = 1.12, volume = 0.8, group = "Effects" }, -- 균열 시작 - 뒤틀리는 스윕
	},
	groups = { "Effects", "UI", "Ambient", "Music" }, -- Music = 자리만(배경 음악은 사용자 결정)
	-- ArmorData 등급 id → 드랍 큐
	dropGradeCues = {
		normal = "drop_common",
		rare = "drop_rare",
		epic = "drop_epic",
		legendary = "drop_legendary",
		relic = "drop_relic",
		ancient = "drop_ancient",
		primordial = "drop_primordial",
		transcendent = "drop_transcendent",
	},
	-- 기존 SoundData.events id → 시트 큐(훅을 이 표로 옮길 때 참고)
	legacyEvents = {
		hit = "hit_light",
		hitCrit = "hit_crit",
		enhanceSuccess = "enhance_success",
		enhanceGreat = "enhance_success",
		enhanceFail = "enhance_fail",
		levelUp = "level_up",
		bossCue = "warning",
		rebirth = "title_get",
		petHatch = "codex_cell",
	},
}
