-- W2-3 서버 확정 피해 방송(프로토타입 - DamageNumberData.enabled 꺼짐이면 아무것도 안 보낸다).
--   emit(target, hitPosition, amount, kind, attacker, isCrit) = 실제로 들어간 피해(applyDamage의 dealt)만. 부른 곳 = AttackServer(근접 · 원거리 도달) · SkillServer(스킬 타격).
--   이벤트 DamageFeed:FireClient(받는 사람, target, hitPosition, amount, kind, attackerUserId, isCrit) - 대상에서 sendStuds 안의 사람에게만.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageNumberData = require(ReplicatedStorage.Shared.data.DamageNumberData)

local DamageFeed = {}

local event = Instance.new("RemoteEvent")
event.Name = "DamageFeed"
event.Parent = ReplicatedStorage

DamageFeed.debugHook = nil -- 검증(W2(나)): function(record) - 플래그와 무관하게 받는다

function DamageFeed.kindOf(isComboHit, isSkill)
	if isSkill then
		return "skill"
	end
	return isComboHit and "heavy" or "normal"
end

function DamageFeed.emit(target, hitPosition, amount, kind, attacker, isCrit)
	if not amount or amount <= 0 or typeof(hitPosition) ~= "Vector3" then
		return
	end
	local record = { target = target, hitPosition = hitPosition, amount = amount, kind = kind, attackerUserId = attacker and attacker.UserId or 0, isCrit = isCrit == true }
	if DamageFeed.debugHook then
		DamageFeed.debugHook(record)
	end
	local isBoss = DamageNumberData.bossFeed and typeof(target) == "Instance" and (target:GetAttribute("BossRig") ~= nil or target:GetAttribute("IsBoss") == true)
	if not DamageNumberData.enabled and not isBoss then
		return -- QUEUE-ALL2 P4 ④: 꺼짐이어도 보스 대상은 보낸다(bossFeed)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - hitPosition).Magnitude <= DamageNumberData.sendStuds then
			event:FireClient(other, target, hitPosition, amount, kind, record.attackerUserId, record.isCrit)
		end
	end
end

return DamageFeed
