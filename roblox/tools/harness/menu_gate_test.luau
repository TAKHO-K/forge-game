-- 메인 메뉴 버그(10-05) 하네스: 메뉴 항상 표시 · 테스트 플래그만 건너뜀 · 접속 = 캐릭터 미스폰 · 입장 = 그때 스폰 · [메인 메뉴로] → 이어하기.
-- 실행: LUAU=<luau.exe> EXTRA_SERVER=SlotSwitch,SlotSave ECON_RES=res_menu.txt python build_run.py menu_gate_test.luau
--   소스 검사(옛 건너뛰기 경로를 다시 읽지 않는가)는 menu_gate_static.py(run_all이 같이 돈다).
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[MENU] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local G = MODS.MenuGate
	-- 1. 건너뛰기 판정(순수)
	check("플래그 없음(Studio) = 메뉴 표시", G.shouldSkip({ isStudio = true, now = 1000, flagUntil = nil }) == false)
	check("플래그 만료(Studio) = 메뉴 표시", G.shouldSkip({ isStudio = true, now = 1000, flagUntil = 999 }) == false)
	check("플래그 켬(Studio · 만료 전) = 건너뜀", G.shouldSkip({ isStudio = true, now = 1000, flagUntil = 1001 }) == true)
	check("라이브 서버 = 플래그가 있어도 메뉴 표시", G.shouldSkip({ isStudio = false, now = 1000, flagUntil = 99999 }) == false)
	check("옛 값(true · 문자열)은 플래그가 아님 = 메뉴 표시", G.shouldSkip({ isStudio = true, now = 1000, flagUntil = true }) == false and G.shouldSkip({ isStudio = true, now = 1000, flagUntil = "9999" }) == false)
	local skips = 0
	for now = 1, 200 do
		if G.shouldSkip({ isStudio = now % 2 == 0, now = now, flagUntil = nil }) then
			skips += 1
		end
	end
	check("플래그 꺼짐 200회 접속 = 건너뛰기 0회", skips == 0, tostring(skips))

	-- 2. 접속 → 메뉴(캐릭터 미스폰) → 입장 스폰 → [메인 메뉴로] → 이어하기(서버 SlotSwitch 실제 코드)
	local restores = 0
	LOADERS["PlayerProfile"] = function() return { getProfile = function() return { classId = "bow", classes = { bow = {} } } end } end
	LOADERS["CharacterRuntime"] = function() return { restore = function() restores += 1 end } end
	local SW = MODS.SlotSwitch
	local loads = 0
	local p = { Name = "M", UserId = 1, attrs = {}, Character = nil }
	function p:GetAttribute(k) return self.attrs[k] end
	function p:SetAttribute(k, v) self.attrs[k] = v end
	function p:LoadCharacter() loads += 1 self.Character = { name = "body" .. loads } end
	SW.holdAtJoin(p)
	check("접속: 메뉴에 있음(InMainMenu) · 캐릭터 0", p.attrs.InMainMenu == true and p.Character == nil and loads == 0)
	local ok1 = SW.enterWorld(p)
	check("입장(이어하기): 그때 스폰 1 · 접속 첫 입장은 위치 복원 중복 없음(첫 로드가 이미 걸어 둠)", ok1 == true and loads == 1 and restores == 0 and p.attrs.InMainMenu == nil)
	local ok2, why2 = SW.enterWorld(p)
	check("월드에 있는데 다시 입장 = 아무것도 안 함(스폰 0)", ok2 == false and why2 == "in_world" and loads == 1)
	-- [메인 메뉴로] 흉내(저장 · 파티는 SlotSwitch.toMenu - 여기서는 결과 상태만): 메뉴로 → 캐릭터 빼기
	p.attrs.InMainMenu = true
	p.Character = nil
	local ok3 = SW.enterWorld(p)
	check("메뉴 → 이어하기: 다시 스폰 1 · 쿨 · 위치 복원 1", ok3 == true and loads == 2 and restores == 1 and p.Character ~= nil)
end)
if not okRun then
	print("[MENU] 하네스 에러 " .. tostring(err))
end
print(("[MENU] 끝 %d/%d"):format(pass, total))
