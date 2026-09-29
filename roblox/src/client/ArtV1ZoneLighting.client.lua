-- A2-N2 2-1 구역 조명 · 분위기 전환(클라 전용 · ArtStyleV1 스위치 뒤 · 값 = shared/data/ArtV1ZoneData).
--   켜짐: 내 캐릭터가 있는 구역(허브 · T1 ~ T6)의 프리셋으로 Lighting · Atmosphere · 색 보정 · 블룸 · 하늘을 tweenSeconds 동안 부드럽게 옮긴다.
--   꺼짐: 서버가 적용한 프로필(Workspace Attribute CartoonStyle → CartoonStyleData)의 같은 값 + 켜기 전 ClockTime · 하늘 · 구역이 덮은 지형 색을 되돌린다 = 지금 게임과 같다.
--   효과 인스턴스는 서버 CartoonStyle이 만든 것(Atmosphere · Bloom · CartoonColorCorrection)을 로컬에서만 바꾼다(클라 변경은 복제 안 됨).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local ZoneData = require(ReplicatedStorage.Shared.data.ArtV1ZoneData)
local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local player = Players.LocalPlayer

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function effect(className, name)
	local inst = Lighting:FindFirstChild(name)
	if inst and inst:IsA(className) then
		return inst
	end
	return Lighting:FindFirstChildOfClass(className)
end

local function sky()
	return Lighting:FindFirstChildOfClass("Sky")
end

local saved = nil -- 켜기 전 관리 밖 값(ClockTime · 하늘)
local overridden = {} -- [재질 이름] = true: 지금 구역 terrain이 덮은 재질(떠날 때 · 끌 때 프로필 색으로)

-- 프로필이 칠한 재질 색(서버 CartoonStyle.apply와 같은 값 - 없으면 지금 색 유지)
local function profileColor(material)
	local profile = CartoonStyleData.profiles[Workspace:GetAttribute("CartoonStyle") or "base"]
	local c = profile and profile.materialColors and profile.materialColors[material]
	return c and (typeof(c) == "table" and c3(c) or c) or nil
end

local function setTerrain(zoneTerrain)
	local terrain = Workspace.Terrain
	for material in pairs(overridden) do
		if not (zoneTerrain and zoneTerrain[material]) then
			local c = profileColor(material)
			if c then
				terrain:SetMaterialColor(Enum.Material[material], c)
			end
			overridden[material] = nil
		end
	end
	for material, c in pairs(zoneTerrain or {}) do
		terrain:SetMaterialColor(Enum.Material[material], c3(c))
		overridden[material] = true
	end
end
local current = nil -- 지금 적용한 구역 키
local tweens = {}

local function play(inst, props)
	if not inst then
		return
	end
	local tw = TweenService:Create(inst, TweenInfo.new(ZoneData.tweenSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	table.insert(tweens, tw)
	tw:Play()
end

local function stopTweens()
	for _, tw in ipairs(tweens) do
		tw:Cancel()
	end
	table.clear(tweens)
end

local function applyZone(key)
	local z = ZoneData.zones[key] or ZoneData.zones[ZoneData.fallback]
	stopTweens()
	play(Lighting, {
		ClockTime = z.clock, Brightness = z.brightness, Ambient = c3(z.ambient), OutdoorAmbient = c3(z.outdoor), ColorShift_Top = c3(z.shiftTop),
	})
	local a = z.atmosphere
	play(effect("Atmosphere", "Atmosphere"), { Density = a.density, Offset = a.offset, Color = c3(a.color), Decay = c3(a.decay), Haze = a.haze, Glare = a.glare })
	play(effect("ColorCorrectionEffect", "CartoonColorCorrection"), { Brightness = z.cc.brightness, Contrast = z.cc.contrast, Saturation = z.cc.saturation, TintColor = c3(z.cc.tint) })
	play(effect("BloomEffect", "Bloom"), { Intensity = z.bloom.intensity, Size = z.bloom.size, Threshold = z.bloom.threshold })
	local s = sky()
	if s then
		s.StarCount = z.sky.stars
		play(s, { SunAngularSize = z.sky.sun })
	end
	setTerrain(z.terrain)
end

-- 서버 프로필 값으로 되돌림(CartoonStyle.apply가 쓴 것과 같은 값 · 같은 키만)
local function restore()
	stopTweens()
	local profile = CartoonStyleData.profiles[Workspace:GetAttribute("CartoonStyle") or "base"]
	if profile then
		for _, key in ipairs(CartoonStyleData.managed.lighting) do
			local v = profile.lighting[key]
			Lighting[key] = typeof(v) == "table" and c3(v) or v
		end
		for name, spec in pairs(CartoonStyleData.managed.effects) do
			local inst = effect(spec.class, name)
			local values = profile.effects[name]
			if inst and values then
				for _, prop in ipairs(spec.props) do
					local v = values[prop]
					if v ~= nil then
						inst[prop] = typeof(v) == "table" and c3(v) or v
					end
				end
			end
		end
	end
	setTerrain(nil)
	if saved then
		Lighting.ClockTime = saved.clock
		local s = sky()
		if s and saved.stars then
			s.StarCount, s.SunAngularSize = saved.stars, saved.sun
		end
		saved = nil
	end
	current = nil
end

local function zoneKey()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return current
	end
	if player:GetAttribute("BossEncounterId") ~= nil then
		return current -- 보스전 중 = 그대로(보스 연출 우선)
	end
	if WorldMapLayout.inHub(root.Position) then
		return "hub"
	end
	local zone = WorldMapLayout.zoneAt(root.Position)
	return zone and ZoneData.zones[zone.key] and zone.key or ZoneData.fallback
end

-- 서버가 프로필을 다시 적용하면(/gg art · /gg style) 복제된 값이 로컬 값을 덮는다 → 복제가 끝난 뒤 지금 구역을 다시 입힌다
Workspace:GetAttributeChangedSignal("CartoonStyle"):Connect(function()
	task.delay(1, function()
		current = nil
	end)
end)

while true do
	local on = Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
	if on then
		if not saved then
			local s = sky()
			saved = { clock = Lighting.ClockTime, stars = s and s.StarCount, sun = s and s.SunAngularSize }
		end
		local key = zoneKey() or ZoneData.fallback
		if key ~= current then
			current = key
			applyZone(key)
		end
	elseif saved then
		restore()
	end
	task.wait(ZoneData.pollSeconds)
end
