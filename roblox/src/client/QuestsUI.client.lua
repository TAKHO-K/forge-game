-- QUEUE-10h Q7 퀘스트 · 수련 창 부트(panels/Quests) - 창을 미리 지어 UIManager에 등록(J 단축키 · 메뉴바 칸이 이 등록을 연다) + 첫 화면 표 요청.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestsPanel = require(script.Parent.panels.Quests)
QuestsPanel.init()
ReplicatedStorage:WaitForChild("QuestRequest"):FireServer("view")
