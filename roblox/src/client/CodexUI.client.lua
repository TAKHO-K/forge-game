-- QUEUE-ALL1 P5 도감 v2 창 부트(panels/Codex) - 창을 미리 지어 UIManager에 등록(K 단축키 · 메뉴바 칸이 이 등록을 연다) + 첫 화면 표 요청.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CodexPanel = require(script.Parent.panels.Codex)
CodexPanel.init()
ReplicatedStorage:WaitForChild("CodexRequest"):FireServer("view")

-- QUEUE-ALL3 Q1 검증 훅(Studio): 클라 execute_luau의 require는 모듈 사본이라 창 상태가 없다 → PlayerGui.CodexCheckHook:Invoke(action, arg)
--   "empty" = CodexPanel.debugEmptyPictureCount()(빈 그림 칸 수 · 탭별 · 칸 수 · 빈 칸 id) · "tab", id = 탭 바꾸기 · "open" = 창 열기
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "CodexCheckHook"
	hook.OnInvoke = function(action, arg)
		if action == "empty" then
			return CodexPanel.debugEmptyPictureCount()
		elseif action == "tab" then
			CodexPanel.setTab(arg)
			return true
		elseif action == "open" then
			return CodexPanel.open()
		end
		return nil
	end
	hook.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end
