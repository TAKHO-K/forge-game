-- QUEUE-ALL6R 3: 서버가 지은 월드 글자(명판 · 강화대 · 제단 · 상인 · 몹 · 드랍 이름표 · 명예의 전당 머리글)를 내 언어로 한 번 다시 쓴다.
--   서버 = Text.bindLabel(키 + 인자) · Text.bindName(데이터 이름) - 속성만 붙이고 글은 ko. 여기 = Text.applyLabel(한 번만 - 몹 이름표의 세대 앞말은 GenerationView가 같은 함수를 먼저 부르고 붙인다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Text = require(ReplicatedStorage.Shared.Text)

for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("TextLabel") then
		Text.applyLabel(d)
	end
end
Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("TextLabel") then
		Text.applyLabel(d)
	end
end)
