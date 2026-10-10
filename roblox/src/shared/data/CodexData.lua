-- QUEUE-ALL1 P5 도감 v2(docs/design/v2/06 - A2-N4 세트 도감 1차 대체). 분류 6 + 점수 보상판 · 칸 완료 → [받기] · 한 줄 완성 → 칭호 · 점수 합계 → 보상판.
--   칸 판정 · 줄 · 점수 = shared/CodexRules(순수) · 기록 · 지급 = server/CodexService · 저장 = profile.codex(SAVE v59).
--   골드 = 칸이 완료된 순간의 계정 최고 스테이지로 고정(done[칸] = 스테이지) × 잡몹 1마리 골드(InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 스테이지)) × goldKills.
--   영구 능력치 없음(06 §3). 이 표의 골드 몫은 EconSim이 econ.goldShare 상한으로 넣어 본다(캐주얼 26 ~ 32h).
local C = {}

C.enabled = true

-- 장비 빙고판: 가로 = 등급 6 · 세로 = 세트(구역) 6 · 칸 = 부위 3. 부위 완료 횟수 = 드랍으로 주운 수(자동 판매 · 분해 포함 · 계승 · 변환권 · 환생 제외)
C.armor = {
	grades = { "normal", "rare", "epic", "legendary", "relic", "ancient" },
	need = { normal = 6, rare = 5, epic = 4, legendary = 3, relic = 1, ancient = 1 },
	goldKills = { normal = 3, rare = 4, epic = 5, legendary = 6, relic = 8, ancient = 10 },
	enhanceStone = { normal = 1, rare = 1, epic = 2, legendary = 3, relic = 4, ancient = 5 },
	-- 보너스 줄(점수 없음): 태초 = 세트당 1칸(아무 부위 1회)
	primordialReward = { enhanceStone = 10 },
}

-- 펫: 구역 알 4종 × 부화 등급 4(EggData.hatchGrades) = 구역 16칸 · 6구역 96
C.pet = { reward = { egg = 1 } } -- 반짝 조각은 아래 C.shards(QUEUE-ALL6 K)
-- 탐험(비밀 둥지): 구역마다 필드 1 + 숨은 5(마을 둥지 = 허브라 줄 밖 · 기존 둥지 칭호는 그대로)
C.nest = { reward = {} } -- 반짝 조각은 아래 C.shards(QUEUE-ALL6 K - 옛 10개 → 분류별 배분)
-- 몬스터: 사냥 구역 종(WorldMapData.zones[].hunt) × 5
C.monster = {
	steps = {
		{ id = "met", label = "첫 만남", kills = 1 },
		{ id = "k10", label = "10마리", kills = 10 },
		{ id = "k100", label = "100마리", kills = 100 },
		{ id = "k1000", label = "1,000마리", kills = 1000 },
		{ id = "sparkle", label = "반짝이", sparkle = true },
	},
	reward = { goldKills = 5, gemDust = 1 },
	bigReward = { goldKills = 5, gemDust = 3 }, -- 1,000마리 · 반짝이
}
-- 보스: 6종 × 처치(기여 10% 이상 - 보스 도장과 같은 조건) 1 · 3 · 5 · 10 · 20
C.boss = { steps = { 1, 3, 5, 10, 20 }, reward = { goldKills = 20, gemDust = 5 } }
-- 직업: 4직업 × 무기 등급 도달(0 일반 ~ 6 태초 - 환생으로 오른 등급만 · 견습 대여 제외)
C.class = { grades = 7, stonePerGrade = 5, stoneBase = 5 }
-- FINAL-1b 결정 6: 4직업 × 8칸 - 8번째 = 무기 초월(계승) 칸(weaponGrade 7 · 그 직업 무기를 초월한 순간 채움 = codex.clsT · 환생 등급 칸 규칙과 따로) · 보상 = 같은 식(5 + 5 × 7 = 강화석 40)
C.class.transcendCell = true

-- 점수 보상판(칸 1개 = 1점 · 보너스 줄 제외): 5점 간격 → 10 → 20 · 최상위는 한 분류(최대 108)로 못 채움
C.board = {}
for t = 5, 50, 5 do
	table.insert(C.board, t)
end
for t = 60, 150, 10 do
	table.insert(C.board, t)
end
for t = 170, 330, 20 do
	table.insert(C.board, t)
end
function C.boardReward(threshold)
	return { goldKills = 30 + threshold, enhanceStone = 3 + math.floor(threshold / 10) } -- QUEUE-ALL6 K: 점수판 반짝 조각 5 → 0(칸 쪽 C.shards로 옮김)
end

-- UI-1 5단계 도감 v2(08 v4-codex §5): 점수판 29단계 → 진행 상자 10개(전체 진행 10%마다 · 진행 = 채운 점수 칸 ÷ 전체 점수 칸).
--   보상 = 옛 점수판 29단계 골드 몫(goldKills) · 강화석 합을 ÷ 10(나머지 = 100% 상자) - 총량 그대로(하네스 codex_box) · 60% · 70% 상자 = 꾸미기 토큰 tokensAt(사용자 10-10 각 70).
--   이미 점수판을 받은 사람 = 받은 점수판 몫만큼 상자 보상에서 뺀다(같은 몫을 두 번 받지 않음 · CodexRules.boxPay). 스위치 = UiV2Flags.codex(끄면 옛 점수판).
C.boxes = { count = 10, tokensAt = { [6] = 70, [7] = 70 } }
-- 성장 별(무기 칸 · 보상 · 능력치 없음): ★1 = 얻음 · ★2 = 그 등급에서 강화 +10 · ★3 = +20(기록 = codex.stars[직업][등급 번호])
C.stars = { levels = { 10, 20 } }

-- QUEUE-ALL9B 3-6(사용자 "도감 업데이트 = 토큰 증가"): 꾸미기 토큰(id sparkleShard)을 칸 수에서 자동 계산 - 새 도감 칸 · 줄이 생기면 얻을 수 있는 총 토큰이 저절로 는다.
--   칸 = 점수 칸(score > 0)마다 perCell · 줄 완성 = 그 줄 칸 수 × linePerCell(올림 - CodexService가 칭호와 함께 지급).
--   도감 1칸 추가 = perCell + linePerCell × (그 칸이 속한 줄 수) = 1.5토큰(장비 칸 = 등급 줄 + 세트 줄 = 2토큰). 옛 분류별 값(QUEUE-ALL6 K - 합 310)은 이 식으로 바뀌었다(합 = CodexRules.totalTokens).
C.tokens = { perCell = 1, linePerCell = 0.5 }
function C.shardsFor(c)
	return (c.score == nil or c.score > 0) and c.kind ~= "board" and C.tokens.perCell or 0
end
function C.lineTokens(cellCount)
	return math.ceil((cellCount or 0) * C.tokens.linePerCell)
end

-- 줄 칭호 이름(구역 이름 = WorldMapData.zones[].theme 앞 짧은 이름 · 등급 = ArmorData 이름 · 보스 = BossData 이름 · 직업 = ClassData 이름)
C.zoneShort = { tier1 = "석조 평원", tier2 = "수정 동굴", tier3 = "수몰 사원", tier4 = "모래 유적", tier5 = "폭풍 첨탑", tier6 = "빙하 동굴" }
C.titleFormat = {
	armorGrade = "%s 수집가", armorZone = "%s 정복자", pet = "%s 사육사", nest = "%s 탐험가",
	monster = "%s 탐구자", boss = "%s 사냥꾼", class = "%s 장인",
}
C.titleGrade = { armorGrade = "epic", armorZone = "legendary", pet = "rare", nest = "rare", monster = "rare", boss = "epic", class = "legendary" }

C.tabs = {
	{ id = "armor", label = "장비" }, { id = "pet", label = "펫" }, { id = "nest", label = "탐험" },
	{ id = "monster", label = "몬스터" }, { id = "boss", label = "보스" }, { id = "class", label = "직업" },
	{ id = "board", label = "점수판" }, { id = "title", label = "칭호" }, -- UI-1 5단계: 스위치 codex 켬 = 점수판 탭 숨김(진행 상자 10개가 대신)
}

-- EconSim: 도감 골드 = 잡몹 처치 골드의 이 비율 이하(상한 가정 - 모든 칸 골드를 그때 스테이지로 받았다고 본 값)
C.econ = { goldShare = 0.2 }

C.text = {
	title = "도감", claimAll = "모두 받기", claim = "받기", claimed = "받음", locked = "진행 중",
	score = "도감 점수 %d / %d", -- QUEUE-ALL6R 3: 알림 문장(eggFull · lineDone · got) = TextData_server srv.codex.*(키 + 인자)
	transcendBorder = "초월 완성",
	titleNone = "칭호 안 보이기", titleHint = "이름표 우선순위 = 초월자 > 태초의 선택 > 고른 칭호",
	nestHidden = "비밀 둥지 %d",
}

return C
