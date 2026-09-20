-- 쉴드 층 목록의 순수 규칙(S13b). 서버(PlayerShield)와 측정 모형(PartyShieldSim)이 같은 함수를 쓴다 - 플레이어 · Attribute · 시계를 모른다(now를 인자로 받는다).
--   layers = 만료 시각(expiresAt) 오름차순 배열, 층 = { amount, expiresAt, caster }. 피해는 앞(만료가 가장 빠른 층)에서부터 깎는다.
--   · 양이 0이 된 층은 즉시 지운다. 만료된 층은 남은 양과 함께 지운다(먼저 건 쉴드부터 사라진다 - 다 깎였으면 사라질 것도 없다).
--   · 대상 1명당 최대 ShieldConfig.maxLayers겹. 5겹째는 걸리지 않는다.
--   · 시전 순간 대상에게 이미 halveFromExistingLayers겹 이상이면 새 쉴드량 × halveMultiplier(3 · 4번째 층 반감).
--   · 같은 시전자가 같은 대상에게 다시 걸면 새 층을 만들지 않고 자기 층을 새 쉴드로 교체한다(시전자당 대상별 1겹). 교체할 때 반감 판정은 자기 층을 뺀 겹 수로 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShieldConfig = require(ReplicatedStorage.Shared.data.ShieldConfig)

local ShieldLayers = {}

-- 만료 시각이 now 이하인 층을 남은 양과 함께 지운다.
function ShieldLayers.purge(layers, now)
	local index = 1
	while index <= #layers do
		if layers[index].expiresAt <= now then
			table.remove(layers, index)
		else
			index += 1
		end
	end
end

function ShieldLayers.count(layers, now)
	ShieldLayers.purge(layers, now)
	return #layers
end

function ShieldLayers.total(layers, now)
	ShieldLayers.purge(layers, now)
	local sum = 0
	for _, layer in ipairs(layers) do
		sum += layer.amount
	end
	return sum
end

-- amount = 반감 전 쉴드량. 반환 { applied, replaced, halved, amount(실제 들어간 양), layerCount(넣은 뒤), reason("full" | "empty" - applied가 false일 때) }.
function ShieldLayers.add(layers, caster, amount, durationSeconds, now)
	ShieldLayers.purge(layers, now)
	if amount <= 0 or durationSeconds <= 0 then
		return { applied = false, replaced = false, halved = false, amount = 0, layerCount = #layers, reason = "empty" }
	end

	local ownIndex
	for index, layer in ipairs(layers) do
		if layer.caster == caster then
			ownIndex = index
			break
		end
	end
	if not ownIndex and #layers >= ShieldConfig.maxLayers then
		return { applied = false, replaced = false, halved = false, amount = 0, layerCount = #layers, reason = "full" }
	end

	local otherCount = #layers - (ownIndex and 1 or 0)
	local halved = otherCount >= ShieldConfig.halveFromExistingLayers
	local finalAmount = halved and amount * ShieldConfig.halveMultiplier or amount
	if ownIndex then
		table.remove(layers, ownIndex)
	end

	local expiresAt = now + durationSeconds
	local insertAt = #layers + 1
	for index, layer in ipairs(layers) do
		if layer.expiresAt > expiresAt then
			insertAt = index
			break
		end
	end
	table.insert(layers, insertAt, { amount = finalAmount, expiresAt = expiresAt, caster = caster })
	return { applied = true, replaced = ownIndex ~= nil, halved = halved, amount = finalAmount, layerCount = #layers }
end

-- 피해를 앞 층부터 깎는다. 반환: 쉴드가 못 막은 나머지 피해, 쉴드가 흡수한 양.
function ShieldLayers.absorb(layers, damage, now)
	ShieldLayers.purge(layers, now)
	local remaining = damage
	local absorbed = 0
	while remaining > 0 and layers[1] do
		local layer = layers[1]
		if layer.amount > remaining then
			layer.amount -= remaining
			absorbed += remaining
			remaining = 0
		else
			remaining -= layer.amount
			absorbed += layer.amount
			table.remove(layers, 1)
		end
	end
	return remaining, absorbed
end

return ShieldLayers
