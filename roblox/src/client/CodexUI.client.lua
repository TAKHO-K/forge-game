-- QUEUE-ALL1 P5 도감 v2 창 부트(panels/Codex) - 창을 미리 지어 UIManager에 등록(K 단축키 · 메뉴바 칸이 이 등록을 연다) + 첫 화면 표 요청.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CodexPanel = require(script.Parent.panels.Codex)
CodexPanel.init()
ReplicatedStorage:WaitForChild("CodexRequest"):FireServer("view")
