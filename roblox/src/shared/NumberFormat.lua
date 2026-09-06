-- 큰 숫자 축약 표기. PRD-forge-game-roblox.md 20.9-1 "표시 계층" 표기 규칙을 그대로 옮긴다.
-- 화면 표시 문자열만 만든다 - 내부 계산에는 절대 쓰지 않는다.

local NumberFormat = {}

local MIN_VALUE = 10000 -- 이 밑은 원래 숫자 그대로(천단위 콤마)
local STEP = 1000
local DECIMALS = 1
local UNITS = { "K", "M", "B", "T" }

-- 두 글자 코드(aa~dz): 첫 글자는 a~d만 쓴다(이중 정밀도 상한이 d그룹 안에서 끝나므로
-- e~z는 쓸 일이 없다). 둘째 글자는 a~z 전체. idx 0=aa, 103=dz.
local TWO_LETTER_FIRST = { "a", "b", "c", "d" }
local ALPHABET = "abcdefghijklmnopqrstuvwxyz"

local function twoLetterCode(idx)
	local firstIdx = math.floor(idx / 26)
	local secondIdx = idx % 26
	return TWO_LETTER_FIRST[firstIdx + 1] .. ALPHABET:sub(secondIdx + 1, secondIdx + 1)
end

-- 세 글자 이상: 두 글자 구간(a~d, 26x4=104개)을 다 쓰고 나면 다시 a부터, 글자 수
-- 제한 없이 반복한다(PRD-forge-game-roblox.md 20.9-1 "표기 규칙" - "이 승격 규칙은
-- 글자 수 제한 없이 반복된다"). 두 글자 구간과 달리 첫 글자를 a~d로 제한하지
-- 않는다 - 그 제한은 이중 정밀도 상한이 d그룹 안에서 끝나기 때문이었는데, 세
-- 글자 이상은 애초에 그 상한 너머라(실제로 도달하지 않는다) 제한할 이유가 없다.
-- idx는 0-기반 순수 자릿수 카운트(0=aaa, 1=aab, ..., 25=aaz, 26=aba, ..., 17575=zzz,
-- 17576=aaaa, ...) - 자리 수가 꽉 차면 자동으로 한 글자 늘어난다.
local function longCode(idx)
	local n = idx
	local length = 3
	local capacity = 26 ^ length
	while n >= capacity do
		n -= capacity
		length += 1
		capacity = 26 ^ length
	end

	local code = ""
	for i = 1, length do
		local pow = 26 ^ (length - i)
		local digit = math.floor(n / pow) % 26
		code = code .. ALPHABET:sub(digit + 1, digit + 1)
	end
	return code
end

local function unitLabel(stepIndex)
	if stepIndex < #UNITS then
		return UNITS[stepIndex + 1]
	end

	local idx = stepIndex - #UNITS
	local twoLetterCapacity = #TWO_LETTER_FIRST * 26
	if idx < twoLetterCapacity then
		return twoLetterCode(idx)
	end

	return longCode(idx - twoLetterCapacity)
end

local function withCommas(n)
	local s = tostring(n)
	local reversed = s:reverse():gsub("(%d%d%d)", "%1,")
	return (reversed:reverse():gsub("^,", ""))
end

function NumberFormat.format(value)
	local n = math.floor(value)
	if n < MIN_VALUE then
		return withCommas(n)
	end

	local scaled = n
	local stepIndex = -1
	while scaled >= STEP do
		scaled = scaled / STEP
		stepIndex += 1
	end

	local factor = 10 ^ DECIMALS
	local truncated = math.floor(scaled * factor) / factor
	local text
	if truncated == math.floor(truncated) then
		text = tostring(math.floor(truncated))
	else
		text = string.format("%." .. DECIMALS .. "f", truncated)
	end

	return text .. unitLabel(stepIndex)
end

return NumberFormat
