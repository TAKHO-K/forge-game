-- QUEUE-ALL6R 3: 서버가 지은 월드 글자(명판 · 강화대 · 제단 · 상인 · 몹 · 드랍 이름표 · 명예의 전당 머리글)를 내 언어로 다시 쓴다.
--   서버 = Text.bindLabel(키 + 인자) · Text.bindName(데이터 이름) - 속성만 붙이고 글은 ko. 여기 = Text.applyLabel(언어마다 한 번 - 몹 이름표의 세대 앞말은 GenerationView가 WorldTextPrefix로 남긴다).
--   리뷰: Language 속성은 프로필 로드 뒤에 붙는다 → 접속 순간 ko로 쓴 뒤 en이 오면 다시 쓴다(설정 변경 · Studio TextLanguageDev도 같다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Text = require(ReplicatedStorage.Shared.Text)

local function applyAll()
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("TextLabel") then
			Text.applyLabel(d)
		end
	end
end

applyAll()
Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("TextLabel") then
		Text.applyLabel(d)
	end
end)
Players.LocalPlayer:GetAttributeChangedSignal(Text.languageAttribute):Connect(applyAll)
Workspace:GetAttributeChangedSignal(Text.devLanguageAttribute):Connect(applyAll)
