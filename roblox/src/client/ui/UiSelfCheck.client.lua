-- 겹침 자동 검사(30-0 S06, PRD 20.81 [D-2] 마지막 문단). Studio에서만 돈다. 접속 8초 뒤 PlayerGui에서 ScreenMap 슬롯 표에 이름이 있는 **보이는** HUD 프레임을 모아
--   ① 서로 교차하는 쌍  ② C 구역(화면 중앙 40% × 50%)을 침범한 것  을 클라 콘솔에 찍는다: `[S06][UI] 겹침 n쌍 · 중앙 침범 m건`. 창(window · station · overlay)은 제외.
-- 참고로 "new" 슬롯(아직 안 그려진 자리 - 드랍 피드 · 메뉴바)이 지금 보이는 HUD와 겹치는지도 별도 줄(`[S06][UI][계획]`)로 찍는다 - 점수에는 안 넣는다(PRD 20.88 미결).
-- 표에 없는 HUD를 찾는 전수 조사도 같이 돈다(`[S06][UI][미등록]`).
-- 이 검사는 HUD 코드를 고치지 않는다. 화면에 안 보이는 프레임(Visible = false · 크기 0 · 배경 · 글 · 이미지가 전부 투명)은 세지 않으므로, 일시 토스트끼리 겹치는 것은 그 순간 같이 떠 있을 때만 잡힌다.
-- 중앙(C 구역)은 화면 높이 비례(가운데 40% × 50%)라 창이 작을수록 바닥 HUD가 걸린다 - 결과 줄에 화면 크기를 같이 적는다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local ScreenMap = require(script.Parent.ScreenMap)
local Theme = require(script.Parent.kit.Theme)

local CHECK_DELAY = 8
local ENGINE_GUIS = { TouchGui = true, Freecam = true } -- 로블록스 · Studio가 만드는 ScreenGui(우리 HUD가 아니다)

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

-- 자기 자신이 화면에 그려지는가(배경 · 글 · 이미지 중 하나가 불투명하다). 토스트 HUD들은 Visible을 안 끄고 투명도로 숨기므로 이 검사가 필요하다.
local function drawsItself(inst)
	if inst:IsA("GuiObject") and inst.BackgroundTransparency < 1 then
		return true
	end
	if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" and inst.TextTransparency < 1 then
		return true
	end
	if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.Image ~= "" and inst.ImageTransparency < 1 then
		return true
	end
	return false
end

-- 프레임 자신이나 보이는 자손 중 하나라도 그려지면 true(칩 스택처럼 자기는 투명하고 자식이 그려지는 컨테이너 포함).
local function draws(inst)
	if drawsItself(inst) then
		return true
	end
	for _, descendant in ipairs(inst:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.Visible and drawsItself(descendant) and isShown(descendant) then
			return true
		end
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
	if not slot.size or slot.below then -- below 슬롯은 다른 슬롯의 아래 끝을 따라 정해지므로 표만으로는 자리를 못 잰다
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
		if inst and isShown(inst) and inst.AbsoluteSize.X > 0 and inst.AbsoluteSize.Y > 0 and draws(inst) then
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

	-- S16: 메뉴바 아래 끝 × 모바일 BL 터치 예약 구역(좌 40% × 하 45%). 모바일 판정이면 실제 자리로 잰다(겹치면 X 표시). PC는 예약 구역이 없어 겹쳐도 무방하지만, 같은 화면 크기를 폰이라고 가정한 값도 같이 찍는다
	-- (ScreenMap.mobileMenuBarShiftUp - 겹침이 0이 되는 최소 이동 후의 아래 끝).
	local menuBar = found.MenuBar
	if menuBar and isShown(menuBar) and menuBar.AbsoluteSize.Y > 0 then
		local reserved = ScreenMap.rectFromFractions(ScreenMap.mobileReserved.BL, screenSize)
		local rect = rectOf(menuBar)
		local touching = intersects(rect, reserved)
		if Theme.isMobile then
			print(("[S06][UI][모바일] 메뉴바 %s × BL 터치 예약 구역 %s: %s %s"):format(describe(rect), describe(reserved), touching and "겹침" or "겹침 0", touching and "X" or "O"))
		else
			local mobileHeight = 3 * ScreenMap.menuBar.mobileButton + 2 * ScreenMap.menuBar.gap
			local shift = ScreenMap.mobileMenuBarShiftUp(screenSize.Y, mobileHeight)
			local bottom = screenSize.Y / 2 + mobileHeight / 2 - shift
			print(("[S06][UI][모바일] PC 화면(예약 구역 없음): 메뉴바 %s · 폰이라면(3칸 %d) 위로 %d 밀어 아래 끝 %d ≤ BL 예약 구역 위 끝 %d %s"):format(
				describe(rect), mobileHeight, shift, bottom, reserved.min.Y, bottom <= reserved.min.Y + 0.5 and "O" or "X"))
		end
	end

	-- 전수 조사(COMMON.md §2 "새 UI를 놓기 전에 표에 없는 기존 HUD가 있는지 먼저 확인한다"): 화면에 그려지는 HUD(ScreenGui 중 DisplayOrder 10 미만의 직계 GuiObject)가 표에 없으면 찍는다.
	-- 창(DisplayOrder 10 이상 · ScreenMap.windowNames)과 로블록스 내장 ScreenGui는 뺀다. 일시 토스트는 그 순간 그려질 때만 잡히므로 표에 있는지는 위 표의 이름으로도 본다.
	local unregistered = {}
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled and gui.DisplayOrder < 10 and not ENGINE_GUIS[gui.Name] then
			for _, child in ipairs(gui:GetChildren()) do
				if child:IsA("GuiObject") and not wanted[child.Name] and not ScreenMap.windowNames[child.Name] and isShown(child) and child.AbsoluteSize.X > 0 and child.AbsoluteSize.Y > 0 and draws(child) then
					table.insert(unregistered, gui.Name .. "." .. child.Name)
					print(("[S06][UI][미등록] %s.%s %s [%s]가 슬롯 표에 없다"):format(gui.Name, child.Name, describe(rectOf(child)), child.ClassName))
				end
			end
		end
	end
	print(("[S06][UI][미등록] 표에 없는 보이는 HUD %d개(기대 0)"):format(#unregistered))

	-- 참고: 아직 안 그려진 "new" 슬롯이 지금 보이는 HUD와 겹치는가.
	for zone, name, slot in ScreenMap.each() do
		local drawn = slot.instanceName and found[slot.instanceName]
		if slot.status == "new" and not (drawn and isShown(drawn) and draws(drawn)) then
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
