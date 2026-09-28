-- M2 도감(자리 - 묶음 F1): 종마다 수집 항목 · 힌트 · 획득처 · 번역 키. 화면(U1)과 저장(첫 만남 · 처치 수 - K 이후 SAVE 버전과 함께)은 아직 없다.
--   번역 키 규칙: "codex.<종 id>.name" · ".hint" · ".where" - 문구는 TextData로 옮길 때 이 키를 쓴다(지금은 아래 기본 문구).
--   collect = 수집 항목(첫 만남 · 처치 10/100/1,000 · 반짝이 처치 · 태초 드랍) - 달성 판정은 서버(저장 필드 자리 = firstMetField · killsField).
local MonsterSpeciesData = require(script.Parent.MonsterSpeciesData)

local C = {}

-- 첫 만남 반응 개인 저장 자리(SAVE 버전을 올리지 않는다 - 필드 이름만 예약 · 실제 저장은 도감 화면 단계에서 migrate와 같이)
C.firstMetField = "codex.firstMet" -- { [종 id] = unix 초 }
C.killsField = "codex.kills" -- { [종 id] = 처치 수 }
C.collect = {
	{ id = "met", label = "첫 만남" },
	{ id = "kill10", label = "10마리 처치", kills = 10 },
	{ id = "kill100", label = "100마리 처치", kills = 100 },
	{ id = "kill1000", label = "1,000마리 처치", kills = 1000 },
	{ id = "sparkle", label = "반짝이 처치" },
	{ id = "primordial", label = "태초 장비 드랍" },
}

local HINTS = {
	moss_slime = { hint = "맞으면 통통 튀어 반격해요. 납작해지면 뛰어들 신호!", where = "석조 평원" },
	rock_boar = { hint = "코로 땅을 파다 12 걸음 안에 들어오면 돌진해요.", where = "석조 평원" },
	crystal_beetle = { hint = "등의 수정이 커지면 조각을 쏘려는 거예요.", where = "수정 동굴" },
	amethyst_bat = { hint = "멀리서도 찾아와요. 날개를 접으면 급강하!", where = "수정 동굴" },
	hermit_knight = { hint = "앞쪽 껍데기는 단단해요. 큰 집게를 들면 옆으로 피하세요.", where = "수몰 사원" },
	bubble_jelly = { hint = "몸이 오므라들면 주변에 전기가 퍼져요.", where = "수몰 사원" },
	sand_scorpion = { hint = "꼬리 끝이 앞으로 넘어오면 직선 찌르기예요.", where = "모래 유적" },
	cactus_imp = { hint = "선인장 밭의 진짜 선인장 사이에 숨어 있어요.", where = "모래 유적" },
	bolt_imp = { hint = "폭풍 속을 뛰어다니며 쫓아와요. 두 손을 들면 번개!", where = "폭풍 첨탑" },
	cloud_sheep = { hint = "털이 어두워지면 주변에 낙뢰가 떨어져요.", where = "폭풍 첨탑" },
	ice_golem = { hint = "느리지만 한 방이 커요. 두 주먹을 들면 멀리 떨어지세요.", where = "빙하 동굴" },
	snow_rabbit = { hint = "한 마리를 때리면 무리 전체가 달려들어요.", where = "빙하 동굴" },
}

C.entries = {}
for id, def in pairs(MonsterSpeciesData.species) do
	local h = HINTS[id] or {}
	C.entries[id] = {
		id = id, tier = def.tier, name = def.displayName, hint = h.hint, where = h.where,
		nameKey = ("codex.%s.name"):format(id), hintKey = ("codex.%s.hint"):format(id), whereKey = ("codex.%s.where"):format(id),
	}
end

return C
