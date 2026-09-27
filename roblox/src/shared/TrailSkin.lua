-- W2 궤적 스킨 규칙(순수 - 서버 · 클라 · 검증 공통). 데이터 = shared/data/TrailData.
--   check(skin) = 금지 색(주황 · 빨강 계열 · 흰 + 자홍) · 허용 칸(색 · 질감 · 파티클만 - 굵기 · 밝기 단계 · 모양 · 시각 칸이 있으면 X).
--   resolve(id) = 쓸 스킨(없거나 검사 X면 기본). 소유 확인(누가 어떤 스킨을 쓸 수 있나)은 서버 server/TrailSkinService.
local TrailData = require(script.Parent.data.TrailData)

local TrailSkin = {}

local function inHueRange(hueDeg, fromDeg, toDeg)
	if fromDeg <= toDeg then
		return hueDeg >= fromDeg and hueDeg <= toDeg
	end
	return hueDeg >= fromDeg or hueDeg <= toDeg -- 0°를 넘는 구간(빨강)
end

-- 색 → (색상 0 ~ 360, 채도 0 ~ 1, 명도 0 ~ 1)
function TrailSkin.hsv(color)
	local h, s, v = color:ToHSV()
	return h * 360, s, v
end

-- 반환: ok, 이유 목록
function TrailSkin.check(skin)
	local reasons = {}
	if type(skin) ~= "table" or typeof(skin.core) ~= "Color3" or typeof(skin.edge) ~= "Color3" then
		return false, { "core · edge 색 없음" }
	end
	local F = TrailData.forbidden
	for key in pairs(skin) do
		if not F.allowedFields[key] then
			table.insert(reasons, ("허용 안 된 칸 %s(스킨은 색 · 질감 · 파티클만)"):format(tostring(key)))
		end
	end
	for _, key in ipairs({ "core", "edge", "particle" }) do
		local c = skin[key]
		if typeof(c) == "Color3" then
			local h, s = TrailSkin.hsv(c)
			if s >= F.warmHue.minSaturation and inHueRange(h, F.warmHue.fromDeg, F.warmHue.toDeg) then
				table.insert(reasons, ("%s 주황 · 빨강 계열(색상 %.0f° · 채도 %.2f - 보스 경고와 혼동)"):format(key, h, s))
			end
		end
	end
	local P = F.primordial
	local _, cs, cv = TrailSkin.hsv(skin.core)
	local eh, es = TrailSkin.hsv(skin.edge)
	if cv >= P.whiteMinValue and cs <= P.whiteMaxSaturation and es >= P.magentaMinSaturation and inHueRange(eh, P.magentaFromDeg, P.magentaToDeg) then
		table.insert(reasons, "흰 + 자홍 = 태초 전용 조합")
	end
	if skin.material ~= nil and not pcall(function()
		return Enum.Material[skin.material]
	end) then
		table.insert(reasons, ("재질 %s 없음"):format(tostring(skin.material)))
	end
	return #reasons == 0, reasons
end

function TrailSkin.resolve(id)
	local skin = TrailData.skins[id or ""]
	if skin and TrailSkin.check(skin) then
		return skin, id
	end
	return TrailData.skins[TrailData.defaultSkin], TrailData.defaultSkin
end

return TrailSkin
