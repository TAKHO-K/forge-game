-- UI-1 7b단계 HUD 편집 배치 규칙 하네스(순수 - 서버 SettingsService.sanitize "hudLayout"과 같은 함수): 옮길 요소 8 · 기본 자리 통과 · 화면 밖 · 상단 바 · 로블록스 버튼 · 모르는 id · 같은 id 두 번 = 거절 · 왕복 · 겹침 = 경고만.
-- 실행: LUAU=<luau.exe> ECON_RES=res_hudedit.txt python build_run.py hud_edit_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[HUDE] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local R = MODS.HudEditRules
	local ids = {}
	for _, dev in ipairs({ "pc", "phone" }) do
		for _, e in ipairs(R.elements(dev)) do
			ids[e.id] = true
		end
	end
	local n = 0
	for _ in pairs(ids) do
		n += 1
	end
	check("옮길 요소 8(PC + 폰 합)", n == 8, tostring(n))
	for _, dev in ipairs({ "pc", "phone" }) do
		local all = {}
		for _, e in ipairs(R.elements(dev)) do
			all[e.id] = { e.rect[1], e.rect[2] }
		end
		local s = R.serialize(all, dev)
		check(dev .. " 기본 자리 전부 = 통과", R.validate(dev, s), s)
		local back = R.parse(s)
		local same = true
		for id, p in pairs(all) do
			same = same and back[id] and back[id][1] == p[1] and back[id][2] == p[2]
		end
		check(dev .. " 왕복(serialize → parse)", same)
	end
	check("빈 글 = 처음 위치 = 통과", R.validate("pc", ""))
	check("화면 밖(오른쪽) = 거절", not R.validate("pc", "nextGoal:1800,198"))
	check("음수 = 거절", not R.validate("pc", "leftMenu:-10,96"))
	check("상단 바(58) 침범 = 거절", not R.validate("pc", "nextGoal:900,40"))
	check("로블록스 버튼 자리(상단 바 아래 58 ~ 60 · x < 132) = 거절", not R.validate("pc", "minimap:10,58") and R.validate("pc", "minimap:140,58"))
	check("모르는 요소 id = 거절", not R.validate("pc", "hacker:100,100"))
	check("같은 id 두 번 = 거절", not R.validate("pc", "nextGoal:900,198;nextGoal:900,300"))
	check("폰 전용 요소(skillRow)를 PC 값에 = 거절", not R.validate("pc", "skillRow:600,200"))
	check("형식 틀림 = 거절", not R.validate("pc", "nextGoal:9x,1") and not R.validate("pc", 5))
	check("모르는 기기 = 거절", not R.validate("tablet", ""))
	local ov = R.overlaps("pc", { nextGoal = { 1516, 106 } })
	check("겹침 = 목록(경고만 - 저장은 validate가 받음)", #ov >= 1 and R.validate("pc", "nextGoal:1516,106"), tostring(#ov))
end)
if not okRun then
	print("[HUDE] 하네스 에러 " .. tostring(err))
end
print(("[HUDE] 끝 %d/%d"):format(pass, total))
