-- 겹침 자동 검사(30-0 S06, PRD 20.81 [D-2] 마지막 문단). Studio에서만 돈다. 접속 8초 뒤 PlayerGui에서 ScreenMap 슬롯 표에 이름이 있는 **보이는** HUD 프레임을 모아
--   ① 서로 교차하는 쌍  ② C 구역(화면 중앙 40% × 50%)을 침범한 것  을 클라 콘솔에 찍는다: `[S06][UI] 겹침 n쌍 · 중앙 침범 m건`. 창(window · station · overlay)은 제외.
-- 참고로 "new" 슬롯(아직 안 그려진 자리 - 드랍 피드 · 메뉴바)이 지금 보이는 HUD와 겹치는지도 별도 줄(`[S06][UI][계획]`)로 찍는다 - 점수에는 안 넣는다(PRD 20.88 미결).
-- 이 검사는 HUD 코드를 고치지 않는다. 화면에 안 보이는(Visible = false · 크기 0) 프레임은 세지 않으므로, 일시 토스트끼리 겹치는 것은 그 순간 같이 떠 있을 때만 잡힌다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local ScreenMap = require(script.Parent.ScreenMap)

local CHECK_DELAY = 8

local function isShown(inst)
	local node = inst
	while node and node ~= game do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function rectOf(inst)
	return { min = inst.AbsolutePosition, max = inst.AbsolutePosition + inst.AbsoluteSize }
end

local function intersects(a, b)
	return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Y < b.max.Y and b.min.Y < a.max.Y
end

local function describe(rect)
	return ("(%d, %d) %d × %d"):format(rect.min.X, rect.min.Y, rect.max.X - rect.min.X, rect.max.Y - rect.min.Y)
end

-- 슬롯 표만으로 계산한 자리(아직 안 그려진 슬롯용). size가 없으면 nil.
local function plannedRect(slot, screen)
	if not slot.size then
		return nil
	end
	local width = slot.size.X.Scale * screen.X + slot.size.X.Offset
	local height = slot.size.Y.Scale * screen.Y + slot.size.Y.Offset
	local x = slot.position.X.Scale * screen.X + slot.position.X.Offset - slot.anchor.X * width
	local y = slot.position.Y.Scale * screen.Y + slot.position.Y.Offset - slot.anchor.Y * height
	return { min = Vector2.new(x, y), max = Vector2.new(x + width, y + height) }
end

local function run()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- 이름 → 인스턴스(첫 번째 GuiObject) 색인.
	local wanted = {}
	for _zone, _name, slot in ScreenMap.each() do
		if slot.instanceName then
			wanted[slot.instanceName] = true
		end
	end
	local found = {}
	local screenSize
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("ScreenGui") and not screenSize and inst.AbsoluteSize.X > 0 then
			screenSize = inst.AbsoluteSize
		end
		if inst:IsA("GuiObject") and wanted[inst.Name] and not found[inst.Name] then
			found[inst.Name] = inst
		end
	end
	screenSize = screenSize or Vector2.new(1280, 720)

	local shown = {} -- { label, rect }
	for zone, name, slot in ScreenMap.each() do
		local inst = slot.instanceName and found[slot.instanceName]
		if inst and isShown(inst) and inst.AbsoluteSize.X > 0 and inst.AbsoluteSize.Y > 0 then
			table.insert(shown, { label = zone .. "." .. name, rect = rectOf(inst), slot = slot })
		end
	end

	local center = ScreenMap.centerRect(screenSize)
	local overlapCount, centerCount = 0, 0
	for _, entry in ipairs(shown) do
		print(("[S06][UI] 슬롯 %s %s"):format(entry.label, describe(entry.rect)))
	end
	for index = 1, #shown do
		for other = index + 1, #shown do
			if intersects(shown[index].rect, shown[other].rect) then
				overlapCount += 1
				print(("[S06][UI] 겹침: %s %s × %s %s"):format(shown[index].label, describe(shown[index].rect), shown[other].label, describe(shown[other].rect)))
			end
		end
		if intersects(shown[index].rect, center) then
			centerCount += 1
			print(("[S06][UI] 중앙 침범: %s %s (C 구역 %s)"):format(shown[index].label, describe(shown[index].rect), describe(center)))
		end
	end
	print(("[S06][UI] 겹침 %d쌍 · 중앙 침범 %d건 (검사한 보이는 슬롯 %d개 · 화면 %d × %d)"):format(overlapCount, centerCount, #shown, screenSize.X, screenSize.Y))

	-- 참고: 아직 안 그려진 "new" 슬롯이 지금 보이는 HUD와 겹치는가.
	for zone, name, slot in ScreenMap.each() do
		local drawn = slot.instanceName and found[slot.instanceName]
		if slot.status == "new" and not (drawn and isShown(drawn)) then
			local planned = plannedRect(slot, screenSize)
			if planned then
				for _, entry in ipairs(shown) do
					if intersects(planned, entry.rect) then
						print(("[S06][UI][계획] 새 슬롯 %s.%s %s가 보이는 %s %s와 겹친다"):format(zone, name, describe(planned), entry.label, describe(entry.rect)))
					end
				end
			end
		end
	end
end

task.delay(CHECK_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S06][UI] 겹침 검사 에러: " .. tostring(err))
	end
end)
