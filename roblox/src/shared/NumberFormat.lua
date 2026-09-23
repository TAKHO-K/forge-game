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

-- S21-0 A1(docs/stage-scaling-audit.md §1-2 ⑤): scaled가 inf가 되면 `while scaled >= STEP`
-- 루프가 끝나지 않는다(inf/1000도 inf). nan은 애초에 그 루프를 안 돌지만(`nan >= 1000`이
-- 항상 false) `%.1f` 포맷터가 "nan" 문자열을 그대로 찍는다 - 둘 다 여기서 값을 보기도
-- 전에 즉시 가로챈다. 경고는 호출 위치당(그 NumberFormat.format을 부른 코드 줄) 1회만.
local warnedCallSites = {}
local function warnOnce(kind, value)
	-- level 1=warnOnce 자신, level 2=NumberFormat.format, level 3=format을 부른 코드.
	local source, line = debug.info(3, "sl")
	local key = (source or "?") .. ":" .. tostring(line)
	if warnedCallSites[key] then
		return
	end
	warnedCallSites[key] = true
	warn(("[NumberFormat] %s 값 입력(%s:%s) - 화면에는 %s로 표시"):format(
		kind, tostring(source), tostring(line), kind == "nan" and "\"—\"" or "\"∞\""))
end

function NumberFormat.format(value)
	if value ~= value then
		warnOnce("nan", value)
		return "—"
	end
	if value == math.huge then
		warnOnce("inf", value)
		return "∞"
	end
	if value == -math.huge then
		warnOnce("-inf", value)
		return "-∞"
	end

	local n = math.floor(value)
	if n < MIN_VALUE then
		return withCommas(n)
	end

	local scaled = n
	local stepIndex = -1
	local truncateSlack = 1 -- 버림 직전 배율(K · M · B · T 구간은 1 = P2 전 그대로)
	if n < STEP ^ (#UNITS + 1) then
		-- K · M · B · T 구간(1e15 미만) - P2 전 코드 그대로(표시가 한 글자도 안 바뀐다).
		while scaled >= STEP do
			scaled = scaled / STEP
			stepIndex += 1
		end
	else
		-- P2 C3: 알파벳 단위 구간(1e15 이상)은 1000으로 수십 번 나누면 오차가 쌓여 1e45가 "999.9aj"(정답 "1ak"), 1e308이 "99.9dt"(정답 "100dt")로 찍혔다.
		-- 단위 칸을 먼저 정하고 한 번만 나눈다(STEP^k는 반올림 한 번뿐 - 10의 거듭제곱이 정확히 1 · 10 · 100으로 떨어진다).
		stepIndex = #UNITS - 1
		while n >= STEP ^ (stepIndex + 2) do
			stepIndex += 1
		end
		scaled = n / STEP ^ (stepIndex + 1)
		if scaled >= STEP then -- STEP^k가 반올림으로 n보다 한 칸 크게 나온 경계(예: 1000.0000…) - 다음 단위로 올린다
			scaled = scaled / STEP
			stepIndex += 1
		end
		-- 나눗셈 · 거듭제곱의 반올림으로 7.7e245가 769.99999…가 되어 "769.9cy"로 버려지는 경계 - 상대 1e-9만큼 올려서 버린다(표시 0.1 자리보다 훨씬 작다).
		truncateSlack = 1 + 1e-9
	end

	local factor = 10 ^ DECIMALS
	local truncated = math.floor(scaled * factor * truncateSlack) / factor
	if truncated >= STEP then -- 여유가 999.99999…를 1000.0으로 올린 경우(알파벳 구간만 가능) - "1000aj"가 아니라 "1ak"
		truncated = math.floor(truncated / STEP * factor) / factor
		stepIndex += 1
	end
	local text
	if truncated == math.floor(truncated) then
		text = tostring(math.floor(truncated))
	else
		text = string.format("%." .. DECIMALS .. "f", truncated)
	end

	return text .. unitLabel(stepIndex)
end

return NumberFormat
