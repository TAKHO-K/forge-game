-- QUEUE-UI2 UI2-2 버튼 손맛 판정(순수 - 하네스가 그대로 부른다). 00 디자인 시스템 spec "버튼 상태 5개 · 동작 규칙" = prototype/buttons-prototype.html 동작.
--   일반(release) = 버튼 위에서 뗄 때만 발동 · 누른 채 밖으로 = 누름 풀림(떼도 발동 X) · 다시 안으로 = 누름 복귀 · 꾹 눌러도 뗄 때 1번.
--   스크롤 목록 안(inList) = 누른 뒤 dragCancel px 넘게 움직이면 취소(스크롤 우선 · 떼도 발동 X).
--   전투(instant) = 누르는 순간 발동 · 누름 모양만 같음. 비활성 = 흔들림만(발동 X).
--   키보드 · 게임패드(key) = 확인 키 누름 = 같은 누름 모양 · 일반은 뗄 때 · 전투는 누를 때 발동.
--   결과 = { paint = "pressed" | "normal" | nil(그대로), fire = true | nil, shake = true | nil }
local ButtonPress = {}
ButtonPress.__index = ButtonPress

function ButtonPress.new(opts)
	opts = opts or {}
	return setmetatable({
		mode = opts.mode or "release",
		inList = opts.inList == true,
		dragCancel = opts.dragCancel or 8,
		disabled = false,
		down = false,
	}, ButtonPress)
end

function ButtonPress:setDisabled(on)
	self.disabled = on == true
	if self.disabled then
		self.down = false
	end
end

function ButtonPress:pressBegan(x, y)
	if self.disabled then
		return { shake = true }
	end
	self.down, self.inside, self.cancel, self.x0, self.y0 = true, true, false, x or 0, y or 0
	return { paint = "pressed", fire = self.mode == "instant" or nil }
end

-- 누른 채 움직임: insideNow = 지금 위치가 버튼 안인가
function ButtonPress:pressMoved(x, y, insideNow)
	if not self.down or self.cancel then
		return {}
	end
	if self.inList and (math.abs((y or 0) - self.y0) > self.dragCancel or math.abs((x or 0) - self.x0) > self.dragCancel) then
		self.cancel = true
		return { paint = "normal" }
	end
	if insideNow ~= self.inside then
		self.inside = insideNow
		return { paint = insideNow and "pressed" or "normal" }
	end
	return {}
end

-- 뗌: insideNow = 뗀 위치가 버튼 안인가 · ok = false면 입력 취소(포커스 잃음 등)
function ButtonPress:pressEnded(insideNow, ok)
	if not self.down then
		return {}
	end
	if insideNow ~= nil then
		self.inside = self.inside and insideNow
	end
	local fire = ok ~= false and self.inside and not self.cancel and self.mode ~= "instant"
	self.down = false
	return { paint = "normal", fire = fire or nil }
end

-- 키보드 · 게임패드 확인 키
function ButtonPress:keyBegan()
	if self.disabled then
		return { shake = true }
	end
	if self.keyDown then
		return {}
	end
	self.keyDown = true
	return { paint = "pressed", fire = self.mode == "instant" or nil }
end

function ButtonPress:keyEnded()
	if not self.keyDown then
		return {}
	end
	self.keyDown = false
	return { paint = "normal", fire = self.mode ~= "instant" or nil }
end

return ButtonPress
