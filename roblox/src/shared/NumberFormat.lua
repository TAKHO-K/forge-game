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

local function unitLabel(stepIndex)
	if stepIndex < #UNITS then
		return UNITS[stepIndex + 1]
	end

	local idx = stepIndex - #UNITS
	if idx < #TWO_LETTER_FIRST * 26 then
		return twoLetterCode(idx)
	end

	-- 세 글자 이상 구간: PRD가 정확한 글자 배정 규칙까지 확정하지 않았고, 이중
	-- 정밀도 상한(약 1.8×10^308)을 이미 넘어선 값이라 실제로는 도달하지 않는다.
	-- 에러 없이 큰 값임만 알 수 있게 표시해 둔다.
	return "dz+"
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
