-- A2-N2 2-4 보스 전조 공통 규칙(클라 · ArtStyleV1 스위치 뒤 · 판정 무관 - 모양 · 크기 · 시간은 각 연출 코드 그대로). 값 = ArtV1FxData.telegraph.
--   모든 위험색 전조(원판 · 선 · 부채꼴 조각)에 같은 언어를 입힌다: 채움 = 기존(옅게 시작해 진해짐) · 테두리 = 진한 위험색 · 두께 고정(rimStuds) · 처음부터 보인다
--   → 채움이 거의 투명한 예고 첫 순간에도 모양 · 크기가 읽힌다(폰 가독성) · 터지기 직전(채움이 진해진 뒤 = 투명도 ≤ blinkBelow)에만 테두리가 깜빡인다.
--   테두리 = HandleAdornment(파트 추가 없음 · 충돌 · 조회 없음): 원 = CylinderHandleAdornment(InnerRadius) · 선 = 가장자리 BoxHandleAdornment 4개.
--   register(part) = 각 연출 코드의 newPart가 위험색 파트를 만들 때 부른다(스위치가 꺼져 있으면 아무것도 안 한다). 파트가 사라지면 같이 사라진다(자식).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData)

local T = FxData.telegraph
local TelegraphStyle = {}

local live = {} -- [part] = { kind, rims = { adornment }, lastSize }

local function adorn(className, part)
	local a = Instance.new(className)
	a.Name = "TelegraphRim"
	a.Adornee = part
	a.Color3 = T.rimColor
	a.Transparency = T.rimTransparency
	a.AlwaysOnTop = false
	a.ZIndex = 1
	a.Parent = part
	return a
end

local function layout(part, st)
	local s = part.Size
	if st.kind == "disc" then
		local r = math.max(s.Y, s.Z) / 2
		local a = st.rims[1]
		a.Radius = r
		a.InnerRadius = math.max(0, r - T.rimStuds)
		a.Height = s.X + T.rimHeight
		a.CFrame = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 파트 높이 축 = 로컬 X · 어돈먼트 높이 축 = Z
	else
		local w, l, h = s.X, s.Z, s.Y + T.rimHeight
		local e = T.rimStuds
		local specs = {
			{ CFrame.new(-(w - e) / 2, 0, 0), Vector3.new(e, h, l) },
			{ CFrame.new((w - e) / 2, 0, 0), Vector3.new(e, h, l) },
			{ CFrame.new(0, 0, -(l - e) / 2), Vector3.new(w, h, e) },
			{ CFrame.new(0, 0, (l - e) / 2), Vector3.new(w, h, e) },
		}
		for i, a in ipairs(st.rims) do
			a.CFrame, a.Size = specs[i][1], specs[i][2]
		end
	end
	st.lastSize = s
end

function TelegraphStyle.register(part)
	if Workspace:GetAttribute(ArtStyleV1Data.attribute) ~= true or live[part] then
		return
	end
	local s = part.Size
	local st
	if part.Shape == Enum.PartType.Cylinder then
		st = { kind = "disc", rims = { adorn("CylinderHandleAdornment", part) } }
	elseif s.Y <= 0.5 and math.min(s.X, s.Z) >= T.rimStuds * 2.5 then -- 바닥에 누운 판(선 · 부채꼴 조각) - 너무 가는 조각은 테두리가 채움을 덮어서 뺀다
		st = { kind = "box", rims = {} }
		for i = 1, 4 do
			st.rims[i] = adorn("BoxHandleAdornment", part)
		end
	else
		return
	end
	layout(part, st)
	live[part] = st
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for part, st in pairs(live) do
		if not part.Parent then
			live[part] = nil
			continue
		end
		if part.Size ~= st.lastSize then
			layout(part, st) -- 자라는 원(진동파) 따라가기
		end
		-- 채움이 진해진 뒤(터지기 직전) 깜빡임 · 채움이 사라지는 중(투명도 ↑)이면 테두리도 같이 흐려진다
		local fill = part.Transparency
		local t = T.rimTransparency
		if fill <= T.blinkBelow then
			t = (math.floor(now * T.blinkHz * 2) % 2 == 0) and T.rimTransparency or 0.55
		end
		if st.peak and fill > st.peak + 0.05 then
			t = math.max(t, fill)
		end
		st.peak = math.min(st.peak or fill, fill)
		for _, a in ipairs(st.rims) do
			a.Transparency = t
		end
	end
end)

return TelegraphStyle
