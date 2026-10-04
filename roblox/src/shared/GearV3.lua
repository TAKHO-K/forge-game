-- QUEUE-ALL9E1 1-1 장비 v3 계산 한 곳(순수 - 클라 착용 · 무기 · 무대 · 하네스 공용). 숫자 = shared/data/GearV3Data · 등급 색 = ItemVisualData.gradeVisuals(규격 docs/design/gear-art-v3.md 2 · 3절).
--   스위치 GearV3Meshes(데이터 · Studio에서만 ReplicatedStorage Attribute가 덮는다) - 끄면 호출부가 지금 모습(직업 v3.1 메시 · 옛 무기)을 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GearV3Data = require(ReplicatedStorage.Shared.data.GearV3Data)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)

local GearV3 = {}
GearV3.data = GearV3Data

function GearV3.enabled()
	if RunService:IsStudio() then
		local override = ReplicatedStorage:GetAttribute("GearV3Meshes")
		if type(override) == "boolean" then
			return override
		end
	end
	return GearV3Data.enabled == true
end

-- 조각 이름 <조각>_<구역>[_<문>] → 구역, 문(없으면 nil)
function GearV3.zone(pieceName)
	local last = pieceName:match("_(%w+)$")
	if last and GearV3Data.gateGrade[last] then
		return pieceName:match("_(%w+)_%w+$"), last
	end
	return last, nil
end

-- 문 부품은 그 등급에서만 보인다(영웅 Ep · 유물 Re · 고대 An · 초월 Tr)
function GearV3.visible(pieceName, grade)
	local _, gate = GearV3.zone(pieceName)
	return gate == nil or GearV3Data.gateGrade[gate] == grade
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function scale(c, f)
	return Color3.new(math.min(1, c.R * f), math.min(1, c.G * f), math.min(1, c.B * f))
end

local function rank(grade)
	return table.find(ArmorData.gradeOrder, grade) or 1
end

-- 방어구 구역 색(8등급 × 6세트): Body = 등급 메인 · Trim = 밝은 · Inner = 어두운(태초 = 자홍 에나멜 · 초월 = 흑요석 그늘) · Attach = 세트 색1 · Gem · Emblem = 세트 색2
--   CoreGem = 등급 보석 · Float · Crack = Neon. 같은 계열 = 부착물 밝게 · 초월 + 모래 = 금 대신 모래(예약 조합 검정 + 금 = 초월 본체만). → (Color3, 네온 여부)
function GearV3.armorColor(pieceName, setZone, grade)
	local zone = GearV3.zone(pieceName)
	local gv = ItemVisualData.gradeVisuals[grade] or ItemVisualData.gradeVisuals.normal
	local set = GearV3Data.sets[setZone] or GearV3Data.sets.tier1
	local bright = GearV3Data.sameFamily[tostring(grade) .. "_" .. tostring(setZone)] or 1
	if zone == "Body" then
		return gv.color, false
	elseif zone == "Trim" then
		return gv.light, false
	elseif zone == "Inner" then
		return grade == "transcendent" and scale(gv.color, 0.75) or gv.dark, false
	elseif zone == "Attach" then
		return scale(rgb(set.color1), bright), false
	elseif zone == "Gem" or zone == "Emblem" then
		local c = set.color2
		if grade == "transcendent" and setZone == "tier4" and GearV3Data.transcendSandSwap then
			c = set.color1
		end
		return scale(rgb(c), bright), zone == "Gem" and rank(grade) >= rank("rare") -- 희귀 이상 보조 보석 = 은은한 Neon(2-1절 발광 1)
	elseif zone == "CoreGem" then
		local g = GearV3Data.coreGem[grade]
		return g and rgb(g.body) or gv.light, false
	elseif zone == "Float" then
		local g = GearV3Data.coreGem[grade]
		return grade == "transcendent" and rgb(GearV3Data.crack) or (g and rgb(g.core) or gv.light), true
	elseif zone == "Crack" then
		return rgb(GearV3Data.crack), true
	end
	return gv.color, false
end

-- 무기 구역 색(세트 없음): 날 · 몸(Body) = 강철에 등급 메인을 조금(weaponBodyTint) · 태초 = 백색 금속 · 초월 = 흑요석(보라 금지 - 5절 ⑤)
--   Trim = 등급 메인(가드 · 장식) · Inner = 손잡이(어두운 - 태초 · 초월은 흑요석 그늘) · CoreGem = 등급 보석(없으면 밝은) · Float · Crack = Neon
function GearV3.weaponColor(pieceName, grade)
	local zone = GearV3.zone(pieceName)
	local gv = ItemVisualData.gradeVisuals[grade] or ItemVisualData.gradeVisuals.normal
	local W = GearV3Data.weapon
	if zone == "Body" then
		if grade == "primordial" or grade == "transcendent" then
			return gv.color, false
		end
		local s, t = rgb(W.steel), W.bodyTint
		return Color3.new(s.R + (gv.color.R - s.R) * t, s.G + (gv.color.G - s.G) * t, s.B + (gv.color.B - s.B) * t), false
	elseif zone == "Trim" then
		return grade == "transcendent" and gv.light or gv.color, false
	elseif zone == "Inner" then
		return (grade == "primordial" or grade == "transcendent") and rgb(W.darkGrip) or gv.dark, false
	elseif zone == "CoreGem" then
		local g = GearV3Data.coreGem[grade]
		return g and rgb(g.body) or gv.light, rank(grade) >= rank("rare")
	elseif zone == "Float" then
		local g = GearV3Data.coreGem[grade]
		return grade == "transcendent" and rgb(GearV3Data.crack) or (g and rgb(g.core) or gv.light), true
	elseif zone == "Crack" then
		return rgb(GearV3Data.crack), true
	end
	return gv.color, false
end

return GearV3
