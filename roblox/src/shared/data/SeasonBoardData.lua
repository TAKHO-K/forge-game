-- QUEUE-ALL9B 5 시즌 출석판(메이플 출석 이벤트식). 시즌(56일 - SeasonPassService.currentSeason과 같은 시계)마다 새 판 · 하루 첫 접속(서버 UTC 날짜) = 한 칸 · 32칸(= 주 4일 × 8주 - 며칠 빠져도 끝까지).
--   규칙 = shared/Quest.lua(roll · claim "board" · "boardBonus") · 지급 = QuestService.grant 한 곳 · 저장 = profile.quests.board(SAVE v67) · 창 = client/panels/SeasonBoard.
--   보상: 꾸미기 토큰 · 알(무료 획득 = 유료 랜덤 아님) · 강화석 소량 · 16칸 = 칭호 장식(seasonRegular) · 32칸 = 출석판 전용 소품(starCrown - boardOnly · 토큰 · 상점 · 선물 X).
--   32칸 다 받은 뒤 남은 날 = 하루 접속마다 after(꾸미기 토큰 1 - 비성장 재화만 · 골드 · 강화석 X). 로벅스로 칸을 사는 기능 없음.
--   토큰 합 = 칸 78 + 남은 날 1/일(토큰 유입 모형 · 499급 가격 근거에 포함 - docs/phase/QUEUE-ALL9B-report.md).
local cells = {}
for i = 1, 32 do
	local col = (i - 1) % 4 + 1
	local row = (i - 1) // 4 + 1
	local cell
	if i == 16 then
		cell = { title = "seasonRegular" }
	elseif i == 32 then
		cell = { cosmeticItem = "starCrown" }
	elseif col == 2 then
		cell = row % 2 == 1 and { egg = 1 } or { enhanceStone = 10 }
	elseif col == 4 then
		cell = { sparkleShard = 5 }
	else
		cell = { sparkleShard = 3 }
	end
	cells[i] = cell
end

return {
	cells = cells,
	after = { sparkleShard = 1 }, -- 32칸 뒤 남은 날(하루 1번)
	growthKinds = { gold = true, highEnhanceStone = true, gemDust = true, protectDrop = true }, -- 검사: 출석판에 넣지 않는 성장 재화(강화석 소량만 허용)
}
