-- 보석 탭 · 상세 시트에 남은 변환 · 리롤 진입점이 "보석상인에게서 가능"이라고 알리는 통로(S20e). 누르면 무반응이던 자리가 토스트 + [위치 안내]가 된다.
--   Hint.toast() = 창 위 토스트 "보석상인에게서 가능 [위치 안내]"(뒤 조각을 누르면 Guide.show) · Hint.locate() = 바로 마커(토스트 없이 - 안내 줄의 [위치 안내]가 쓴다).
-- 변환 · 리롤 자체는 보석상인의 "보석 공방" 창(panels/GemWorkshop)에서만 한다 - 여기는 알리기만 한다.

local Text = require(game:GetService("ReplicatedStorage").Shared.Text)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local Guide = require(script.Parent.Guide)

local Hint = {}

function Hint.locate()
	return Guide.show()
end

function Hint.toast()
	local text, locateText = Text.get("forge.workshop.hint"), Text.get("forge.workshop.hintLocate")
	Toast.push("TC", {
		text = text .. " " .. locateText,
		richParts = {
			{ text = text .. " ", colorName = "textPrimary" },
			{ text = locateText, colorName = "success", bold = true, onActivate = Hint.locate },
		},
		grade = "notice", -- 창 위(가방 창이 열려 있어도 보인다)
		seconds = 5,
		groupKey = "gemMerchantHint",
	})
end

return Hint
