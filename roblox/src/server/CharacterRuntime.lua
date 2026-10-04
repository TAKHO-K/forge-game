-- QUEUE-MENU2 D: 캐릭터 런타임 유지(사용자 확정) - 쿨(서버 공용 시각) · 궁 게이지(값 그대로) · 마지막 위치를 캐릭터 저장(classState.runtime)에 넣고 꺼낸다.
--   capture = 저장 직전(SaveSystem 런타임 훅 - 모든 저장 경로) · restore = 로드 · 캐릭터 전환 직후(ProfileBoot).
--   보스방 안(보스전 · 잔류)에서는 위치를 새로 적지 않는다 → 돌아오면 들어가기 전 자리(관문 앞). 보스 입장 때 게이지 0 등 기존 규칙은 그대로(UltimateService).
local SkillCooldowns = require(script.Parent.SkillCooldowns)

local CharacterRuntime = {}

local function bossBusy(player)
	local ok, BossEncounter = pcall(require, script.Parent.BossEncounter)
	return ok and BossEncounter.getEncounter(player) ~= nil
end

function CharacterRuntime.capture(player, classState)
	if type(classState) ~= "table" or typeof(player) ~= "Instance" then
		return
	end
	local rt = type(classState.runtime) == "table" and classState.runtime or {}
	classState.runtime = rt
	rt.cooldownEnds = SkillCooldowns.export(player)
	rt.ultGauge = require(script.Parent.UltimateService).get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and not bossBusy(player) and player:GetAttribute("TutorialCompleted") ~= false then -- 견습 중 자리는 적지 않는다(견습 구역)
		local p = root.Position
		rt.lastPos = { x = math.floor(p.X * 10) / 10, y = math.floor(p.Y * 10) / 10, z = math.floor(p.Z * 10) / 10 }
	end
end

-- restorePosition = 이어하기(메뉴 → 게임) · 재접속 - 캐릭터가 생긴 뒤 마지막 자리로
function CharacterRuntime.restore(player, classState, restorePosition)
	local rt = type(classState) == "table" and type(classState.runtime) == "table" and classState.runtime or {}
	SkillCooldowns.import(player, rt.cooldownEnds)
	require(script.Parent.UltimateService).set(player, tonumber(rt.ultGauge) or 0)
	local pos = rt.lastPos
	if restorePosition and type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) and tonumber(pos.z) then
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			if not character:WaitForChild("HumanoidRootPart", 10) or not player.Parent then
				return
			end
			task.wait(0.5)
			require(script.Parent.Travel).teleport(player, Vector3.new(pos.x, pos.y + 1, pos.z), "lastPosition")
		end)
	end
end

return CharacterRuntime
