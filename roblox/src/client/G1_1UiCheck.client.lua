-- G1-1 클라 자체 점검 [G1-1][UI] - Studio에서 DevToolsConfig.verify에 "G1-1(UI)"가 있을 때만(또는 회귀 전체).
-- ① 3타 고리: 서버 ComboUpdate와 같은 호출로 칸 채움 · 다음 타 강타면 조준 외곽선 색 신호 · 2초 뒤 저절로 꺼짐 ② ? 도움말 2단: 처음엔 짧은 줄 + 안내 · 터치 44 이상
-- ③ 강화 확률표 행 이름 "성공 시 · 실패 시". 펼치기(누르기)는 자체 점검이 못 누른다 - 스크린샷 Play에서 실제 클릭으로 본다(COMMON §2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "G1-1(UI)")) then
	return
end

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local ComboRing = require(script.Parent.ComboRing)
local AimTarget = require(script.Parent.AimTarget)
local HelpTooltip = require(script.Parent.HelpTooltip)
local OddsView = require(script.Parent.panels.Enhance.OddsView)

local player = Players.LocalPlayer

local function run()
	local passed, total = 0, 0
	local function check(label, ok)
		total += 1
		passed += ok and 1 or 0
		print(("[G1-1][UI] %s %s"):format(label, ok and "O" or "X"))
	end
	print("===G1-1 검증 시작(UI)===")

	-- ① 3타 고리
	local ok, err = pcall(function()
		local discs = {}
		for i = 1, CombatConfig.comboHitEvery do
			discs[i] = Workspace.CurrentCamera:FindFirstChild("ComboRingDisc" .. i)
		end
		local function onCount()
			local n = 0
			for _, disc in ipairs(discs) do
				n += (disc and disc.Color == UIColors.ember) and 1 or 0
			end
			return n
		end
		ComboRing.onCombo(101, false) -- 누적 101 = 사이클 2번째(3의 배수 + 2)
		task.wait(0.05)
		local two, heavyReady = onCount(), AimTarget.debugHeavyReady()
		ComboRing.onCombo(102, true)
		task.wait(0.05)
		local heavyColor = discs[1] and discs[1].Color ~= UIColors.ember and discs[1].Transparency == 0
		local readyAfterHeavy = AimTarget.debugHeavyReady()
		task.wait(CombatConfig.comboResetWindowSeconds + 0.3)
		local off = true
		for _, disc in ipairs(discs) do
			off = off and disc.Transparency > 0.5
		end
		check(("3타 고리: 칸 %d개 · 누적 101 → 켜진 칸 %d(기대 2) · 다음 타 강타 신호 %s(기대 true) · 강타 → 강타 색 %s · 신호 %s(기대 false) · %.1f초 뒤 전부 꺼짐 %s"):format(
			#discs, two, tostring(heavyReady), tostring(heavyColor), tostring(readyAfterHeavy), CombatConfig.comboResetWindowSeconds + 0.3, tostring(off)),
			#discs == CombatConfig.comboHitEvery and two == 2 and heavyReady == true and heavyColor and readyAfterHeavy == false and off and AimTarget.debugHeavyReady() == false)
	end)
	if not ok then
		check("3타 고리 에러: " .. tostring(err), false)
	end

	-- ② ? 도움말 2단
	ok, err = pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "G11HelpCheck"
		gui.Parent = player:WaitForChild("PlayerGui")
		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(0, 100, 0, 30)
		holder.Parent = gui
		local button = HelpTooltip.attach(holder, UDim2.new(0, 10, 0, 10), { short = "짧은 줄", detail = "상세 줄" }, "right", { toggleOnly = true, panelSize = Vector2.new(240, 120), panelTextSize = 12 })
		local panel = button:FindFirstChild("HelpPanel")
		local hint = panel and panel:FindFirstChild("DetailHint")
		local toggle = panel and panel:FindFirstChild("DetailButton")
		local textLabel = nil
		for _, child in ipairs(panel and panel:GetChildren() or {}) do
			if child:IsA("TextLabel") and child.Name ~= "DetailHint" then
				textLabel = child
			end
		end
		check(("? 도움말 2단: 처음 글 [%s](기대 짧은 줄만) · 안내 [%s] · 누를 자리 %s · 접힌 높이 %d(기대 ≥ 44)"):format(textLabel and textLabel.Text or "?", hint and hint.Text or "?",
			tostring(toggle ~= nil), panel and panel.Size.Y.Offset or -1),
			textLabel ~= nil and textLabel.Text == "짧은 줄" and hint ~= nil and hint.Text == Text.get("help.more") and toggle ~= nil and panel.Size.Y.Offset >= 44)
		gui:Destroy()
	end)
	if not ok then
		check("? 도움말 에러: " .. tostring(err), false)
	end

	-- ③ 강화 확률표 이름
	ok, err = pcall(function()
		local frame = Instance.new("Frame")
		local refs = OddsView.buildTable(frame, 0, 0, 300)
		local s, m = refs.rows.success.label.Text, refs.rows.maintain.label.Text
		check(("강화 확률표: [%s] · [%s](기대 '성공 시' · '실패 시 · 유지' - '되는 단계' 없음)"):format(s, m), s == "성공 시" and m == "실패 시 · 유지")
		frame:Destroy()
	end)
	if not ok then
		check("강화 확률표 에러: " .. tostring(err), false)
	end

	print(("===G1-1 검증 끝(UI)=== %d/%d 통과"):format(passed, total))
end

task.delay(12, run)
