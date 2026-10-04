-- QUEUE-ALL9E1 2-2 무기 이펙트 단계 판정(한 곳 - 아이콘 · 3D 이펙트 · 하네스가 같이 부른다). 표 = shared/data/WeaponFxStepData.
--   stepOf(무기 등급 id, 강화 단계, 초월 강화 단계) →
--     { kind = "transcend", step = 0 ~ 25, row = 표 줄 } | { kind = "enhanceHigh", step = 강화 단계, band = 띠 줄 } | nil(+20 미만 일반 무기)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.data.WeaponFxStepData)

local WeaponFx = {}
WeaponFx.data = Data

function WeaponFx.transcendRow(level)
	local n = math.clamp(math.floor(tonumber(level) or 0), 0, #Data.transcend - 1)
	return Data.transcend[n + 1]
end

function WeaponFx.stepOf(gradeId, weaponLevel, transcendLevel)
	if gradeId == "transcendent" then
		local row = WeaponFx.transcendRow(transcendLevel)
		return { kind = "transcend", step = row.step, row = row }
	end
	local level = tonumber(weaponLevel) or 0
	local band = nil
	for _, b in ipairs(Data.enhanceHigh) do
		if level >= b.fromLevel then
			band = b
		end
	end
	return band and { kind = "enhanceHigh", step = level, band = band } or nil
end

return WeaponFx
