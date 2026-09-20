-- 플레이어 쉴드 층 상태(S13b). 대상 하나당 층 목록(shared/ShieldLayers.lua가 규칙을 안다) - 이 모듈은 대상별 목록을 들고, 총량을 Attribute "Shield"로 클라(내 체력바 · 파티 HUD)에 알린다.
-- PlayerState(HP)와 같은 자리의 상태다 - 피해는 PlayerDamage.takeDamage가 여기 absorb를 먼저 거친 뒤 HP를 깎는다(그 밖에서 쉴드를 직접 깎지 않는다).
-- target = 실제 Player 또는 검증의 스탠드인(테이블 - Attribute는 Player에만 쓴다). now(선택) = 시계 주입(기본 os.clock() - PlayerState의 만료 시각들과 같은 시계).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShieldLayers = require(ReplicatedStorage.Shared.ShieldLayers)

local PlayerShield = {}

-- 만료 직후 총량을 다시 알린다(만료 시각과 같은 틱에 task.delay가 깨면 아직 만료 판정 전일 수 있다).
local EXPIRY_SYNC_PAD_SECONDS = 0.05

local states = {} -- [target] = layers

local function sync(target, now)
	local layers = states[target]
	local total = layers and ShieldLayers.total(layers, now or os.clock()) or 0
	if typeof(target) == "Instance" and target.Parent then
		target:SetAttribute("Shield", total)
	end
	return total
end

-- 쉴드를 건다. amount = 반감 전 양. 반환은 ShieldLayers.add의 결과(applied · replaced · halved · amount · layerCount · reason).
function PlayerShield.add(target, caster, amount, durationSeconds, now)
	now = now or os.clock()
	local layers = states[target]
	if not layers then
		layers = {}
		states[target] = layers
	end
	local result = ShieldLayers.add(layers, caster, amount, durationSeconds, now)
	if result.applied then
		sync(target, now)
		-- 층이 만료돼 사라지는 순간 클라 막대가 줄어들게 한다(교체 · 흡수로 이미 바뀐 층의 옛 지연은 그냥 다시 동기화만 한다 - 멱등).
		task.delay(durationSeconds + EXPIRY_SYNC_PAD_SECONDS, function()
			sync(target)
		end)
	end
	return result
end

-- 피해를 쉴드가 먼저 흡수한다. 반환: 쉴드가 못 막은 나머지 피해, 흡수한 양.
function PlayerShield.absorb(target, damage, now)
	local layers = states[target]
	if not layers or #layers == 0 then
		return damage, 0
	end
	local remaining, absorbed = ShieldLayers.absorb(layers, damage, now or os.clock())
	sync(target, now)
	return remaining, absorbed
end

function PlayerShield.getTotal(target, now)
	local layers = states[target]
	return layers and ShieldLayers.total(layers, now or os.clock()) or 0
end

function PlayerShield.getLayerCount(target, now)
	local layers = states[target]
	return layers and ShieldLayers.count(layers, now or os.clock()) or 0
end

-- 죽음 · 리스폰 · 퇴장 때 통째로 지운다.
function PlayerShield.clear(target)
	if states[target] == nil then
		return
	end
	states[target] = nil
	if typeof(target) == "Instance" and target.Parent then
		target:SetAttribute("Shield", 0)
	end
end

return PlayerShield
