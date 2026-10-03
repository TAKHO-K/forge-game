-- D1(사용자 결정) 칭호 데이터 - 확장 가능한 구조: id · 이름 · 등급(장비 7등급 색 재사용 - GradeColor) · 획득 조건(설명 · 부여하는 곳).
-- 이름표 위 칭호 한 줄(client/Nameplate)은 nameplateOrder에 든 칭호 중 가진 것 하나(앞이 우선)만 그린다 - 이번엔 "태초의 선택"만(선택 UI · 도감 = U1).
-- 최상위 등급(topGrades)은 흰 + 자홍 그라데이션이 천천히 흐른다. 획득 저장 = 프로필 titles(v39 - { [id] = true }) · 클라 = Player Attribute Titles(쉼표 목록).
-- 기존 칭호(호기심 대장 · 둥지 칭호)의 부여 코드는 그대로(WorldMapData · NestData) - 여기에 이름 · 등급 · 조건만 모았다.

local T = {
	titles = {
		-- D1-2(사용자 결정): 획득 조건을 데이터로 구분(acquire) - 드랍 태초 장비의 최초 획득만. 태초 보석(환생 1번 홈 지급 · 분해 · 재련)과 무기 환생 태초 · 계승 결과로는 안 깨진다.
		--   acquire.kind = "dropPrimordial"(PrimordialRegistry.titleEarnedBy가 읽는다) · sources = 드랍 출처 태그(item.source.kind) 중 인정하는 것 · parts = 장비 부위.
		primordialChosen = { id = "primordialChosen", name = "태초의 선택", grade = "primordial",
			condition = "드랍 태초 장비(세계 번호가 붙는 태초)를 처음 얻는다 - 태초 보석 · 무기 환생 태초 · 계승 결과는 해당 없음",
			acquire = { kind = "dropPrimordial", sources = { "boss", "raid", "field", "sparkle" }, parts = { "armor", "gloves", "shoes" } },
			grantedBy = "server/PrimordialRegistry.onRolled" }, -- QUEUE-10h Q0-6: 새로 주지 않는다(칭호 = 초월부터 · DropNoticeData.globalGrades) - 이미 가진 계정은 표시 유지
		-- C5-7 초월자: 드랍 초월 장비(세계 번호)를 처음 얻는다 - 흑금 그라데이션(topGrades).
		transcendentOne = { id = "transcendentOne", name = "초월자", grade = "transcendent",
			condition = "드랍 초월 장비(세계 번호가 붙는 초월)를 처음 얻는다",
			acquire = { kind = "dropPrimordial", sources = { "boss", "raid", "field", "sparkle" }, parts = { "armor", "gloves", "shoes" } },
			grantedBy = "server/PrimordialRegistry.onRolled" },
		weeklyChampion = { id = "weeklyChampion", name = "주간 챔피언", grade = "ancient", condition = "주간 도전 한 주 1위(처치 시간)", grantedBy = "server/WeeklyChallengeService" }, -- QUEUE-ALL1 P4 §3
		communityHero = { id = "communityHero", name = "모두의 영웅", grade = "legendary", condition = "주간 합동 목표 100% 달성 주에 기여하고 받기(한정)", grantedBy = "server/CommunityGoalService" }, -- QUEUE-ALL1 P3 §4
		seasonRegular = { id = "seasonRegular", name = "시즌 출석 개근", grade = "rare", condition = "시즌 출석판 16칸 받기", grantedBy = "server/QuestService(시즌 출석판 - QUEUE-ALL9B 5)" },
		curiousCaptain = { id = "curiousCaptain", name = "호기심 대장", grade = "rare", condition = "봉인 입구 틈까지 올라간다", grantedBy = "server/Travel" },
		nestSeeker = { id = "nestSeeker", name = "둥지 탐험가", grade = "epic", condition = "비밀 둥지를 처음 찾는다", grantedBy = "server/NestServer" },
		secretKeeper = { id = "secretKeeper", name = "비밀 수집가", grade = "legendary", condition = "비밀 둥지 10곳을 찾는다", grantedBy = "server/NestServer" },
	},
	nameplateOrder = { "transcendentOne", "primordialChosen" }, -- 이름표에 보이는 칭호(앞이 우선 - C5-7 초월자) · 둘 다 없으면 고른 칭호(Player Attribute SelectedTitle - QUEUE-ALL1 P5)
	topGrades = { primordial = true, transcendent = true }, -- 흰 글자 위로 무지개 띠가 훑고 지나감(사용자 결정)
	gradientSeconds = 2.6, -- 띠가 한 번 지나가는 시간(천천히)
	offsetStuds = 1.15, -- 이름표 위로
	maxDistanceStuds = 80, -- 멀면 숨김
}

-- QUEUE-ALL1 P5 도감 v2 줄 칭호(장비 등급 6 · 세트 6 · 펫 · 탐험 · 몬스터 · 보스 각 6 · 직업 4 = 40 - shared/CodexRules.titles가 데이터에서 만든다)
for id, t in pairs(require(script.Parent.Parent.CodexRules).titles()) do
	T.titles[id] = t
end
return T
