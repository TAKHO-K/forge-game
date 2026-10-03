-- 방어구 조각 색(A2-N3 · QUEUE-ALL1 P2 v3) - 원래 client/ArmorWearView 안에 있던 함수를 그대로 옮겼다(QUEUE-ALL9C 2-4: 직업 선택 무대 캐릭터 client/ClassStage도 같은 색).
--   colorOf(조각 이름, 구역, 등급) = 옛 구역 메시 색 · colorOfV3 = 직업 메시(<부위>_<직업>_<외형>) 세트 3색(ArtImportData.armorSetColors) → (Color3, 네온 여부)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.ArtImportData)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)

local ArmorColors = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function rank(grade)
	return table.find(ArmorData.gradeOrder, grade) or 1
end

function ArmorColors.colorOf(pieceName, zone, grade)
	local Z = Data.armorZoneColors[zone] or Data.armorZoneColors.tier1
	local gc = GradeColor.of(grade)
	local base, trim, gradeC, glow = rgb(Z.base), rgb(Z.accent), gc, rgb(Data.armorGlow)
	if rank(grade) >= rank("epic") then
		trim = gc
	end
	if grade == "primordial" then
		base = rgb(Data.armorPrimordialBase)
		glow = gc
	elseif grade == "transcendent" then
		local T = Data.armorTranscendent
		base, trim, gradeC, glow = rgb(T.base), rgb(Z.accent), rgb(T.grade), rgb(T.glow)
	end
	if pieceName:match("_Glow$") then
		return glow, true
	elseif pieceName:match("_Grade$") then
		return gradeC, false
	elseif pieceName:match("_Trim$") then
		return trim, false
	end
	return base, false
end

-- QUEUE-ALL1 P2 v3: 직업 메시(<부위>_<직업>_<외형>)의 색 = 세트 3색(ArtImportData.armorSetColors)
function ArmorColors.colorOfV3(pieceName, zone, grade)
	local Z = Data.armorSetColors[zone] or Data.armorSetColors.tier1
	local main, sub, accent, glow = rgb(Z.main), rgb(Z.sub), rgb(Z.accent), rgb(Data.armorGlow)
	if grade == "transcendent" then
		local T = Data.armorTranscendent
		main, sub, accent, glow = rgb(T.base), rgb(Z.main), rgb(T.grade), rgb(T.glow)
	elseif grade == "primordial" then
		main, accent, glow = rgb(Data.armorPrimordialBase), GradeColor.of(grade), GradeColor.of(grade)
	elseif rank(grade) >= rank("legendary") then
		glow = GradeColor.of(grade) -- 보석 = 등급 색
	end
	local N = Data.armorNeutral[grade] or Data.armorNeutral
	if pieceName:match("_Glow$") then
		return glow, true
	elseif pieceName:match("_Grade$") then
		return accent, false
	elseif pieceName:match("_Trim$") then
		return sub, false
	elseif pieceName:match("_Steel$") then
		return rgb(N.steel), false
	elseif pieceName:match("_Leather$") then
		return rgb(N.leather), false
	end
	return main, false
end

return ArmorColors
