-- QUEUE-MENU2 D: 스킬 쿨 기록(옛 SkillServer lastCastTick · os.clock = 서버마다 다름) → 서버 공용 시각(GetServerTimeNow) · 마지막 시전 시각 + 그때 쿨 길이.
--   메뉴 왕복 · 강제 종료 · 재접속 · 다른 서버 접속에서 같은 값으로 복원(CharacterRuntime이 캐릭터 저장 classState.runtime.cooldownEnds에 넣고 꺼낸다).
--   클라 표시 = Player Attribute SkillCooldowns(JSON { [칸] = { e = 끝 시각, t = 길이 } }) - 복원 · 전환 때만 쏜다(평소 시전 표시는 SkillCastResult 그대로).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local SkillCooldowns = {}
local casts = {} -- [Player][칸] = { at = 서버 시각, total = 초 }
local pendingTotal = {} -- [Player][칸] = 이번 요청에서 계산한 쿨 길이(isOnCooldown → mark)

local function now()
	return workspace:GetServerTimeNow()
end

function SkillCooldowns.isOnCooldown(player, slot, cooldownSeconds)
	pendingTotal[player] = pendingTotal[player] or {}
	pendingTotal[player][slot] = cooldownSeconds
	local c = casts[player] and casts[player][slot]
	return c ~= nil and (now() - c.at) < cooldownSeconds
end

function SkillCooldowns.mark(player, slot)
	casts[player] = casts[player] or {}
	casts[player][slot] = { at = now(), total = pendingTotal[player] and pendingTotal[player][slot] or 0 }
end

function SkillCooldowns.clear(player)
	casts[player] = nil
	pendingTotal[player] = nil
end

-- 저장용: 아직 도는 쿨만 { [칸] = { endsAt, total } }
function SkillCooldowns.export(player)
	local out = {}
	local t = now()
	for slot, c in pairs(casts[player] or {}) do
		local endsAt = c.at + (c.total or 0)
		if endsAt > t then
			out[slot] = { endsAt = endsAt, total = c.total }
		end
	end
	return out
end

local function publish(player)
	local view = {}
	for slot, e in pairs(SkillCooldowns.export(player)) do
		view[slot] = { e = e.endsAt, t = e.total }
	end
	player:SetAttribute("SkillCooldowns", HttpService:JSONEncode(view))
end

-- 복원(로드 · 전환): 끝난 쿨은 버린다 · 클라 표시에 한 번 알린다
function SkillCooldowns.import(player, saved)
	casts[player] = {}
	local t = now()
	for slot, e in pairs(type(saved) == "table" and saved or {}) do
		if type(e) == "table" and tonumber(e.endsAt) and tonumber(e.total) and e.endsAt > t then
			casts[player][slot] = { at = e.endsAt - e.total, total = e.total }
		end
	end
	if typeof(player) == "Instance" then
		publish(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	SkillCooldowns.clear(player)
end)

return SkillCooldowns
