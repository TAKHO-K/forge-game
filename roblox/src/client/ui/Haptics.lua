-- UI-1 0단계 ⑨ 진동 한 곳: HapticService:IsVibrationSupported 검사 뒤에만 진동(지원 안 하는 기기 · PC = 아무것도 안 함). 설정 진동 끄기 = Attribute VibrationOff(7b 설정).
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")

local Haptics = {}
local INPUT = Enum.UserInputType.Gamepad1

function Haptics.supported()
	local ok, yes = pcall(function()
		return HapticService:IsVibrationSupported(INPUT) and HapticService:IsMotorSupported(INPUT, Enum.VibrationMotor.Large)
	end)
	return ok and yes == true
end

-- 짧은 진동 한 번(세기 0 ~ 1 · 초)
function Haptics.pulse(strength, seconds)
	local lp = Players.LocalPlayer
	if (lp and lp:GetAttribute("VibrationOff") == true) or not Haptics.supported() then
		return false
	end
	pcall(function()
		HapticService:SetMotor(INPUT, Enum.VibrationMotor.Large, strength or 0.5)
	end)
	task.delay(seconds or 0.12, function()
		pcall(function()
			HapticService:SetMotor(INPUT, Enum.VibrationMotor.Large, 0)
		end)
	end)
	return true
end

return Haptics
