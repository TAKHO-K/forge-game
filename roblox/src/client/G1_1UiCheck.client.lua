-- G1-1 클라 자체 점검 [G1-1][UI] - Studio에서 DevToolsConfig.verify에 "G1-1(UI)"가 있을 때만(또는 회귀 전체).
-- ① 3타 표시(M1-0 후속 - 무기 발광): 서버 ComboUpdate와 같은 호출로 발광 단계 · 준비 번쩍 · 폰 3칸 막대 · 다음 타 강타면 조준 외곽선 색 신호 ② ? 도움말 2단: 처음엔 짧은 줄 + 안내 · 터치 44 이상
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
local Text = require(ReplicatedStorage.Shared.Text)
local ComboGlow = require(script.Parent.ComboGlow)
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

	-- ① 3타 표시(M1-0 후속: 발밑 고리 → 무기 발광 + 폰 3칸 막대)
	local ok, err = pcall(function()
		local ringGone = Workspace.CurrentCamera:FindFirstChild("ComboRingDisc1") == nil
		ComboGlow.onCombo(100, false) -- 누적 100 = 사이클 1번째
		task.wait(0.1)
		local one = ComboGlow.debugState()
		ComboGlow.onCombo(101, false) -- 누적 101 = 사이클 2번째 → 다음 타 강타
		task.wait(0.05)
		local flash = ComboGlow.debugState()
		local heavyReady = AimTarget.debugHeavyReady()
		task.wait(CombatConfig.comboGlow.flashSeconds + 0.1)
		local ready = ComboGlow.debugState()
		ComboGlow.onCombo(102, true)
		task.wait(0.05)
		local after = ComboGlow.debugState()
		local readyAfterHeavy = AimTarget.debugHeavyReady()
		local g = CombatConfig.comboGlow
		check(("3타 발광: 발밑 고리 없음 %s · 1타 밝기 %.1f(기대 %.1f) · 준비 번쩍 %.1f → %.1f(기대 %.1f → %.1f) · 폰 막대 %d(기대 3) · 강타 신호 %s · 강타 뒤 밝기 %.1f · 신호 %s"):format(
			tostring(ringGone), one.brightness, g.mine.hit.brightness, flash.brightness, ready.brightness, g.flashBrightness, g.mine.ready.brightness, ready.bars, tostring(heavyReady), after.brightness, tostring(readyAfterHeavy)),
			ringGone and math.abs(one.brightness - g.mine.hit.brightness) < 1e-3 and math.abs(flash.brightness - g.flashBrightness) < 1e-3 and math.abs(ready.brightness - g.mine.ready.brightness) < 1e-3
				and ready.bars == CombatConfig.comboHitEvery and heavyReady == true and after.brightness == 0 and readyAfterHeavy == false)
	end)
	if not ok then
		check("3타 발광 에러: " .. tostring(err), false)
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
