-- 패널 화면 안 검사(S12 사전 작업 2, COMMON.md §2 "패널 높이 화면 제한"). Studio에서만, DevToolsConfig.verify에 "S12(UI)"가 있을 때(또는 회귀 전체)만 돈다.
-- 접속 10초 뒤 UIManager에 등록된 window · station 전부와 스테이지 선택 패널(등록 없이 fitToScreen을 직접 부른다)을 하나씩 열어 프레임이 화면(ScreenGui 영역) 안에 있는지 잰다.
-- 같은 자리에서 열린 패널마다 실효 글씨(TextSize × 조상 UIScale 누적 배율, COMMON.md §2)의 12 미만 목록도 찍는다(`[S12][UI][글씨]` - 보고용이라 통과 · 실패에 세지 않는다). 패널을 다 돈 뒤 HUD 전체도 한 번 훑는다.
-- 강화 패널은 강화대 근처에서만 지어지므로 여기 없다(Play에서 강화대로 옮긴 뒤 같은 잣대로 잰다 - PRD 기록). 결과: `[S12][UI] 패널 … O/X` + 요약 `===S12 검증 끝(UI)=== n/m 통과`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S12(UI)")) then
	return
end

local StageRewardBand = require(script.Parent.Parent.StageRewardBand)
local StageSelectPanel = require(script.Parent.Parent.StageSelectPanel)
local TextAudit = require(script.Parent.TextAudit)
local Theme = require(script.Parent.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local CHECK_DELAY = 10
local STEP_WAIT = 0.4 -- 열림 트윈(0.12초) + 레이아웃
local TOLERANCE = 1 -- px

local function run()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local pass, total = 0, 0
	print("===S12 검증 시작(UI: 패널 화면 안)===")

	local function measure(label, frame, gui)
		local top = frame.AbsolutePosition.Y
		local bottom = top + frame.AbsoluteSize.Y
		local screenTop = gui.AbsolutePosition.Y
		local screenBottom = screenTop + gui.AbsoluteSize.Y
		local outside = math.max(0, screenTop - top - TOLERANCE, bottom - screenBottom - TOLERANCE)
		local ok = outside == 0
		total += 1
		if ok then
			pass += 1
		end
		print(("[S12][UI] 패널 %s: 위 %.0f · 아래 %.0f · 높이 %.0f / 화면 영역 위 %.0f · 아래 %.0f · 높이 %.0f(기대 화면 밖으로 나간 양 0) → 나간 양 %.0f %s"):format(
			label, top, bottom, frame.AbsoluteSize.Y, screenTop, screenBottom, gui.AbsoluteSize.Y, outside, ok and "O" or "X"))
	end

	-- 실효 글씨 12 미만 목록(보고용).
	local function textReport(label, root)
		local report = TextAudit.report(root)
		local listed = #report.low > 0 and (" [" .. table.concat(report.low, " · ", 1, math.min(#report.low, 8)) .. (#report.low > 8 and " · …" or "") .. "]") or ""
		print(("[S12][UI][글씨] %s: 보이는 글 %d개 · 실효 최소 %.1f px · 실효 12 미만 %d개%s · TextScaled(잴 수 없음) %d개%s"):format(
			label, report.count, report.count > 0 and report.minEffective or 0, #report.low, listed, #report.scaled, #report.scaled > 0 and (" [" .. table.concat(report.scaled, ",", 1, math.min(#report.scaled, 4)) .. "]") or ""))
	end

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.zero
	print(("[S12][UI] 화면: 뷰포트 %d × %d · 모바일 판정용 ForceTouchLayout=%s"):format(viewport.X, viewport.Y, tostring(Players.LocalPlayer:GetAttribute("ForceTouchLayout"))))

	for _, id in ipairs(UIManager.getIds()) do
		local kind = UIManager.getKind(id)
		if kind == "window" or kind == "station" then
			UIManager.closeAll()
			task.wait(STEP_WAIT)
			local opened = UIManager.open(id)
			task.wait(STEP_WAIT)
			local frame, gui = UIManager.getParts(id)
			if opened and gui and frame then
				measure(("%s(%s)"):format(id, kind), frame, gui)
				textReport(("%s(%s)"):format(id, kind), gui)
			else
				total += 1
				print(("[S12][UI] 패널 %s(%s): 열리지 않았거나 프레임을 못 찾음(열림=%s) X"):format(id, kind, tostring(opened)))
			end
			UIManager.closeAll()
		end
	end

	-- 스테이지 선택 패널(등록 없음).
	StageSelectPanel.open()
	task.wait(STEP_WAIT)
	local stageGui = playerGui:FindFirstChild("StageSelectGui")
	if stageGui then
		measure("StageSelectGui", stageGui.Panel, stageGui)
		textReport("StageSelectGui", stageGui)
		local body = stageGui.Panel:FindFirstChild("Body")
		print(("[S12][UI] StageSelectGui 본문 스크롤: 창 높이 %.0f · 캔버스 %.0f(창이 캔버스보다 낮으면 스크롤된다)"):format(body.AbsoluteSize.Y, body.CanvasSize.Y.Offset))

		-- 사전 작업 3: 도감 점 터치 상자(모바일 44 × 44 이상 · PC 22) + 위치로 점을 정하는 순수 함수.
		local dot = body:FindFirstChild("RewardBand") and body.RewardBand:FindFirstChild("CodexDot1")
		total += 1
		local expectWidth = Theme.isMobile and 44 or 22
		local dotOk = dot ~= nil and math.abs(dot.AbsoluteSize.X - expectWidth) < 1 and (not Theme.isMobile or dot.AbsoluteSize.Y >= 44)
		if dotOk then
			pass += 1
		end
		print(("[S12][UI] 도감 점 터치 상자(%s): %s × %s(기대 %d × %s) %s"):format(Theme.isMobile and "모바일" or "PC",
			dot and ("%.0f"):format(dot.AbsoluteSize.X) or "없음", dot and ("%.0f"):format(dot.AbsoluteSize.Y) or "없음", expectWidth, Theme.isMobile and "44 이상" or "무관", dotOk and "O" or "X"))
		total += 1
		local idxOk = StageRewardBand.dotIndexAt(95, 100, 22, 6) == 1 and StageRewardBand.dotIndexAt(121, 100, 22, 6) == 1 and StageRewardBand.dotIndexAt(122, 100, 22, 6) == 2
			and StageRewardBand.dotIndexAt(231, 100, 22, 6) == 6 and StageRewardBand.dotIndexAt(245, 100, 22, 6) == 6
		if idxOk then
			pass += 1
		end
		print(("[S12][UI] dotIndexAt(95 · 121 · 122 · 231 · 245) = %d · %d · %d · %d · %d(기대 1 · 1 · 2 · 6 · 6 - 양 끝 바깥은 끝 점) %s"):format(
			StageRewardBand.dotIndexAt(95, 100, 22, 6), StageRewardBand.dotIndexAt(121, 100, 22, 6), StageRewardBand.dotIndexAt(122, 100, 22, 6),
			StageRewardBand.dotIndexAt(231, 100, 22, 6), StageRewardBand.dotIndexAt(245, 100, 22, 6), idxOk and "O" or "X"))
	else
		total += 1
		print("[S12][UI] StageSelectGui를 못 찾음 X")
	end
	StageSelectPanel.close()

	-- 패널이 모두 닫힌 상태의 HUD: 화면에 지금 보이는 글만 잰다(평소 숨어 있는 토스트 · 배너 · 강화 패널은 안 보이면 못 잰다).
	task.wait(STEP_WAIT)
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled and gui.DisplayOrder < 10 and (#TextAudit.report(gui).low > 0 or #TextAudit.report(gui).scaled > 0) then
			textReport("HUD " .. gui.Name, gui)
		end
	end
	print("[S12][UI][글씨] HUD 훑기 끝(실효 12 미만이 있는 ScreenGui만 위에 찍는다 - 없으면 줄 없음)")

	print(("===S12 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
end

task.delay(CHECK_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S12][UI] 패널 화면 안 검사 에러: " .. tostring(err))
	end
end)
