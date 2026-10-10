-- UI-1b 0절(VERIFY-5 상3) 실제 화면 겹침 검사(Studio 전용): 표 사각형(hud_layout 하네스)이 못 잡는 겹침을 실제 GUI 인스턴스 자리로 잰다.
--   실행 = 클라에서 LocalPlayer:SetAttribute("DebugHudRealCheck", 번호) → 결과 = 같은 플레이어 Attribute "DebugHudRealResult"(글) + 출력 [HUDREAL] 줄.
--   대상 = UiLayoutData.realCheck.units(보이는 것만 · each = 직속 자식마다) · 판정 = shared/HudRealRules(하네스와 같은 함수).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

if not RunService:IsStudio() then
	return
end

local C = require(ReplicatedStorage.Shared.data.UiLayoutData).realCheck
local HudRealRules = require(ReplicatedStorage.Shared.HudRealRules)
local player = Players.LocalPlayer

local function shown(o)
	while o and o:IsA("GuiObject") do
		if not o.Visible then
			return false
		end
		o = o.Parent
	end
	return o == nil or not o:IsA("ScreenGui") or o.Enabled
end

local function find(path)
	local node = player.PlayerGui
	for part in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

local function rectOf(id, o)
	local p, s = o.AbsolutePosition, o.AbsoluteSize
	if s.X < 1 or s.Y < 1 then
		return nil
	end
	-- 보이는 직속 자식(메뉴 버튼 아래 이름표 · 점 등)까지 합친 범위 = 화면에 실제로 그려지는 자리
	local x0, y0, x1, y1 = p.X, p.Y, p.X + s.X, p.Y + s.Y
	for _, c in ipairs(o:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible and c.AbsoluteSize.X >= 1 and c.AbsoluteSize.Y >= 1 and (not c:IsA("TextLabel") or c.Text ~= "") then
			x0, y0 = math.min(x0, c.AbsolutePosition.X), math.min(y0, c.AbsolutePosition.Y)
			x1, y1 = math.max(x1, c.AbsolutePosition.X + c.AbsoluteSize.X), math.max(y1, c.AbsolutePosition.Y + c.AbsoluteSize.Y)
		end
	end
	return { id = id, x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

local function run()
	local rects = {}
	for _, u in ipairs(C.units) do
		local node = find(u.path)
		if node and node:IsA("GuiObject") and shown(node) then
			if u.each then
				-- 투명 묶음 틀(그림 · 글 없는 Frame + 자식 있음 = 폰 메뉴 줄 TopRow 등)은 안쪽 자식마다 잰다
				local function each(prefix, parent)
					for _, c in ipairs(parent:GetChildren()) do
						if c:IsA("GuiObject") and c.Visible then
							local group = c.ClassName == "Frame" and c.BackgroundTransparency >= 1 and #c:GetChildren() > 0
							local kids = 0
							for _, k in ipairs(c:GetChildren()) do
								if k:IsA("GuiObject") then
									kids += 1
								end
							end
							if group and kids > 0 then
								each(prefix .. c.Name .. "/", c)
							else
								table.insert(rects, rectOf(prefix .. c.Name, c))
							end
						end
					end
				end
				each(u.id .. "/", node)
			else
				local r = rectOf(u.id, node)
				if r then
					r.topbarOk = u.topbarOk
				end
				table.insert(rects, r)
			end
		end
	end
	local view = workspace.CurrentCamera.ViewportSize
	local inset = GuiService:GetGuiInset().Y
	local res = HudRealRules.check(rects, { w = view.X, h = view.Y - inset }, C.allow)
	local lines = { ("view %dx%d · 칸 %d · 겹침 %d · 화면 밖 %d · 상단 바 %d"):format(view.X, view.Y, #rects, #res.overlaps, #res.offscreen, #res.topbar) }
	for _, o in ipairs(res.overlaps) do
		table.insert(lines, ("겹침 %s ↔ %s %dx%d"):format(o[1], o[2], o[3], o[4]))
	end
	for _, id in ipairs(res.offscreen) do
		table.insert(lines, "화면 밖 " .. id)
	end
	for _, id in ipairs(res.topbar) do
		table.insert(lines, "상단 바 " .. id)
	end
	for _, l in ipairs(lines) do
		print("[HUDREAL] " .. l)
	end
	player:SetAttribute("DebugHudRealResult", table.concat(lines, "\n"))
end

player:GetAttributeChangedSignal("DebugHudRealCheck"):Connect(function()
	if player:GetAttribute("DebugHudRealCheck") then
		run()
	end
end)
