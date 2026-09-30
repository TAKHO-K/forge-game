-- QUEUE-ALL1 01 A-2 전수 보정: 글씨 있는 버튼(TextButton · TextBox)의 UIStroke가 기본값 Contextual이면 버튼 테두리가 아니라 글씨에 회색 외곽선이 그려진다
--   (가방 머리 버튼 "회색 판" - Play 전수 조사 14종: 가방 각성 · 제작 · 계승 · 도움말 · 스테이지 등급 도움말 · 친구 초대 등). 바탕이 보이는 버튼(BackgroundTransparency < 0.9)의
--   UIStroke = 테두리 의도 → Border로. 바탕이 거의 투명한 버튼(글씨 외곽선 의도일 수 있음)은 그대로. 지금 있는 것 + 나중에 생기는 것 모두.
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function fix(stroke)
	if not stroke:IsA("UIStroke") or stroke.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Contextual then
		return
	end
	local b = stroke.Parent
	if b and (b:IsA("TextButton") or b:IsA("TextBox")) and b.BackgroundTransparency < 0.9 then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
end

for _, d in ipairs(playerGui:GetDescendants()) do
	fix(d)
end
playerGui.DescendantAdded:Connect(function(d)
	if d:IsA("UIStroke") then
		task.defer(fix, d) -- 부모 · 바탕 투명도가 정해진 뒤
	end
end)
