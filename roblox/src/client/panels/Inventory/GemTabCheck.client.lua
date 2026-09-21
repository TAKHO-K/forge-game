-- S20b 자체 점검 [S20][UI][보석 탭] - 보석 탭을 InventoryUI에서 panels/Inventory/GemTab.lua로 옮긴 뒤(동작 변경 0)의 구조 · 갱신 경로. Studio에서 DevToolsConfig.verify에 "S20(UI)"가 있을 때만(또는 회귀 전체) 돈다.
-- 자체 점검은 클릭을 못 한다(드래그 시작 · 탭 전환 · 닫기 중 취소는 실제 클릭 Play에서 본다). 여기서는 ① 본문 · 홈 5 · 행 5가 그대로 지어졌는가 ② 창을 열면 갱신 경로(GemTab.update)가 돌아 행 글이 채워지고 보유 보석 칸이 서버 스냅샷(GemFetch)과 같은 수인가
-- ③ 닫으면 드래그 유령이 없는가를 잰다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S20(UI)")) then
	return
end

local UIManager = require(script.Parent.Parent.Parent.UIManager)
local Gem = require(ReplicatedStorage.Shared.Gem)

local player = Players.LocalPlayer
local START_DELAY = 78 -- 창을 여는 다른 점검(S12(UI) 패널 전수 · S12b(UI) 장비창 글씨)과 S20(UI) 요청 배너 점검이 끝난 뒤

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20][UI][보석 탭] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20b(UI) 검증 시작(보석 탭 이동)===")

	local playerGui = player:WaitForChild("PlayerGui")
	UIManager.open("inventory")
	task.wait(1)
	local gui = playerGui:FindFirstChild("InventoryGui")
	local content = gui and gui:FindFirstChild("Window") and gui.Window:FindFirstChild("Content")
	local gemBody = content and content:FindFirstChild("GemBody")
	check("GemBody가 장비창 Content 아래에 있음(장비 탭이 열려 있어 숨김)", gemBody ~= nil and gemBody.Visible == false)
	if not gemBody then
		print("===S20b(UI) 검증 끝=== 0/1 통과")
		UIManager.close("inventory")
		return
	end

	local structureOk = gemBody:FindFirstChild("WeaponPane") ~= nil and gemBody:FindFirstChild("InfoPane") ~= nil
	local sockets, rows = 0, 0
	for slot = 1, Gem.slotCount do
		if gemBody:FindFirstChild("Socket" .. slot, true) then
			sockets += 1
		end
		if gemBody:FindFirstChild("SlotRow" .. slot, true) then
			rows += 1
		end
	end
	check(("본문 구조: WeaponPane · InfoPane %s · 홈 버튼 %d(기대 %d) · 홈 행 %d(기대 %d)"):format(tostring(structureOk), sockets, Gem.slotCount, rows, Gem.slotCount),
		structureOk and sockets == Gem.slotCount and rows == Gem.slotCount)

	-- 창을 연 직후 onOpen → GemTab.update()가 돌았다: 행마다 글이 있다("N번 홈 · 상한 … " 또는 "잠김")
	local labelsFilled = 0
	for slot = 1, Gem.slotCount do
		local row = gemBody:FindFirstChild("SlotRow" .. slot, true)
		local label = row and row:FindFirstChildOfClass("TextLabel")
		if label and label.Text ~= "" then
			labelsFilled += 1
		end
	end
	check(("창을 열면 행 글이 채워진다(GemTab.update): %d/%d"):format(labelsFilled, Gem.slotCount), labelsFilled == Gem.slotCount)

	-- 보유 보석 칸 수 = 서버 스냅샷의 gemInventory 수. 같은 Play의 서버 (나) 블록(S20c(나))이 이 시각에 보석칸을 잠깐 시험 상태로 바꿨다가 되돌리므로(GemSync 두 번)
	-- 한 번 어긋나 보일 수 있다 - 칸이 다시 그려질 시간을 주며 몇 번 다시 읽고, 끝내 안 맞으면 X(검증 쪽 경합을 거르는 것이지 비교 기준을 낮춘 것이 아니다).
	local cellCount, expected = -1, -2
	for _ = 1, 5 do
		local ok, snapshot = pcall(function()
			return ReplicatedStorage.GemFetch:InvokeServer()
		end)
		cellCount = 0
		for _, child in ipairs(gemBody:GetDescendants()) do
			if child:IsA("TextButton") and child.Name:match("^GemCell%d+$") then
				cellCount += 1
			end
		end
		expected = ok and snapshot and #snapshot.gemInventory or -1
		if cellCount == expected then
			break
		end
		task.wait(0.6)
	end
	check(("보유 보석 칸 %d = 서버 스냅샷 %d"):format(cellCount, expected), cellCount == expected)

	-- 닫으면 드래그 유령 0
	UIManager.close("inventory")
	task.wait(0.6)
	local ghost = gui:FindFirstChild("GemDragProxy")
	check("창을 닫은 뒤 드래그 유령(GemDragProxy) 0개", ghost == nil)

	print(("===S20b(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20][UI][보석 탭] 점검 에러: " .. tostring(err))
		UIManager.close("inventory", true)
	end
end)
