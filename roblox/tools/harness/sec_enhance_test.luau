Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- SEC-FIX-1 13 장비 상세 [강화] 서버 경로(실제 EnhanceService.handleRequest): 강화대 밖 = 이제 강화됨(05 spec 결정 #12) · 보스전 중 = boss_fight 거절(골드 · 단계 그대로).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,EnhanceService,EnhancePolicy,ImmediateSave) ECON_RES=res_secenh.txt python build_run.py sec_enhance_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECENH] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local BOSS = {}
LOADERS["BossEncounter"] = function() return { classChangeBlocked = function(p) return BOSS[p] == true end, getEncounter = function() return nil end, getActive = function() return nil end } end
local ok, err = pcall(function()
	local Enhance, SaveSystem, PlayerProfile, WorldConfig = MODS.Enhance, MODS.SaveSystem, MODS.PlayerProfile, MODS.WorldConfig
	local station = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	local function makePlayer(name, id, pos)
		local attrs = {}
		local root = { Position = pos }
		local character = { FindFirstChild = function(_, n) return n == "HumanoidRootPart" and root or nil end, FindFirstChildOfClass = function() return nil end }
		return setmetatable({ Name = name, UserId = id, Parent = true, Character = character, DisplayName = name }, { __index = function(_, k)
			if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
			if k == "GetAttribute" then return function(_, n) return attrs[n] end end
			if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "IsA" then return function() return false end end
			if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
			return nil
		end })
	end
	local ES = MODS.EnhanceService
	local function clearCooldown() local t0 = os.clock(); while os.clock() - t0 < ES.requestCooldownSeconds + 0.05 do end end
	local far = makePlayer("FarEnh", 81, station + Vector3.new(800, 0, 800)) -- 강화대에서 먼 곳(가방 상세에서 연 창)
	PlayerProfile.init(far, SaveSystem.migrate({}))
	PlayerProfile.setClassId(far, "bow")
	PlayerProfile.setWeaponLevel(far, 3)
	local cost = Enhance.getCost(3, PlayerProfile.getAccountBestStage(far), false, false)
	PlayerProfile.addGold(far, cost * 3)
	ES.debugRolls[far] = 0.0 -- 성공 칸
	clearCooldown()
	local g0 = PlayerProfile.getGold(far)
	local res = ES.handleRequest(far, false, false)
	check("13 강화대 밖(가방 상세 [강화]) = 강화됨 · 비용 차감(옛 = 조용히 무시 nil)", res ~= nil and res.result == "success" and PlayerProfile.getGold(far) == g0 - cost and PlayerProfile.getWeapon(far).level == 4,
		res and ("%s · 골드 %d → %d · +%d"):format(tostring(res.result), g0, PlayerProfile.getGold(far), PlayerProfile.getWeapon(far).level) or "nil")
	BOSS[far] = true
	clearCooldown()
	local g1, l1 = PlayerProfile.getGold(far), PlayerProfile.getWeapon(far).level
	local rb = ES.handleRequest(far, false, false)
	check("13 보스전 중 = boss_fight 거절 · 골드 · 단계 그대로(옛 = 이유 없이 무시)", rb ~= nil and rb.result == "boss_fight" and PlayerProfile.getGold(far) == g1 and PlayerProfile.getWeapon(far).level == l1,
		rb and tostring(rb.result) or "nil")
	BOSS[far] = nil
	local near = makePlayer("NearEnh", 82, station)
	PlayerProfile.init(near, SaveSystem.migrate({}))
	PlayerProfile.setClassId(near, "bow")
	PlayerProfile.setWeaponLevel(near, 3)
	PlayerProfile.addGold(near, cost * 3)
	ES.debugRolls[near] = 0.0
	clearCooldown()
	local rn = ES.handleRequest(near, false, false)
	check("13 강화대 옆(대장간 NPC 창) = 그대로 강화됨", rn ~= nil and rn.result == "success")
end)
if not ok then print("[SECENH] 에러 " .. tostring(err)) end
print(("[SECENH] 끝 %d/%d"):format(pass, total))
