-- 부품 전시장 · 규칙 검사 진입점(30-0 S06, 개발 전용). DevTools `/gg ui gallery` · `/gg ui check`가 ReplicatedStorage의 UiDevCommand RemoteEvent로 신호를 보낸다.
-- 프로덕션에는 DevTools가 죽어 있어 그 RemoteEvent가 없다 - 10초 기다려도 안 생기면 조용히 끝난다(전시장 모듈은 신호가 올 때 처음 불러온다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local command = ReplicatedStorage:WaitForChild("UiDevCommand", 10)
if not command then
	return
end

command.OnClientEvent:Connect(function(name)
	local gallery = require(script.Parent.Parent.panels.UiGallery)
	if name == "gallery" then
		gallery.open()
	elseif name == "check" then
		task.spawn(gallery.runRuleCheck)
	elseif name == "close" then
		gallery.close()
	end
end)
