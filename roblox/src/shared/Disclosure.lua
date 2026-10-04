-- QUEUE-10h Q13 P4b 확률 공개(한 소스): 서버 굴림이 읽는 표 · 함수를 그대로 모아 화면 표로 만든다(새 확률 상수 없음).
--   드랍 = DropTable.disclosure · 강화 = Enhance.getOutcomeTable · 옵션 리롤 = Option.poolFor(비활성 스위치 반영) · 스킬 변형 = SkillVariant.disclosure · 부화 = Pet.disclosure.
--   version = 표 전체 숫자의 지문(문자열) - 서버 시작 때 로그 한 줄 · 창 아래 표시(표가 바뀌면 값이 바뀐다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local Option = require(ReplicatedStorage.Shared.Option)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillVariant = require(ReplicatedStorage.Shared.SkillVariant)
local SkillVariantData = require(ReplicatedStorage.Shared.data.SkillVariantData)
local Pet = require(ReplicatedStorage.Shared.Pet)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)

local Disclosure = {}

-- 옵션 리롤(보석 · 장비 변환권 · 드랍 · 환생 같은 풀): 직업마다 균등(1 / 풀 크기)
function Disclosure.optionPool(classId)
	local pool = Option.poolFor(classId)
	local rows = {}
	for _, id in ipairs(pool) do
		table.insert(rows, { id = id, chance = 1 / #pool }) -- 풀이 비면 행 없음(rollFor = 옵션 없음)
	end
	return rows
end

function Disclosure.enhanceRows()
	local rows = {}
	for level = 0, EnhanceConfig.maxLevel - 1 do
		local t = Enhance.getOutcomeTable(level, false, false, false)
		if t then
			table.insert(rows, { level = level, success = t.success, maintain = t.maintain, down1 = t.down1, down2 = t.down2, reset = t.reset })
		end
	end
	return rows
end

-- QUEUE-ALL9E1 0-4 초월 강화(+6 ~): 서버 판정과 같은 표(All10Data.transcendEnhance.bands) · 스위치(All10Economy) 끔이면 행 없음
function Disclosure.transcendRows()
	local All10 = require(ReplicatedStorage.Shared.All10)
	local rows = {}
	if not All10.enabled() then
		return rows
	end
	local d = All10.data.transcendEnhance
	for _, band in ipairs(d.bands) do
		table.insert(rows, { fromLevel = band.fromLevel, toLevel = band.toLevel, chance = band.chance, ceiling = band.ceiling, extendStage = band.fromLevel > d.baseMaxLevel and d.extendStage or nil })
	end
	return rows
end

function Disclosure.build()
	local options = {}
	for _, classId in ipairs(ClassData.order) do
		options[classId] = Disclosure.optionPool(classId)
	end
	local bossIds = {}
	for id in pairs(BossData.bosses) do
		table.insert(bossIds, id)
	end
	table.sort(bossIds)
	local out = {
		drop = DropTable.disclosure(), -- 잡몹(티어별) · 보스 첫 클리어 · 토벌 · 반짝이 - 보스는 종과 무관하게 같은 표(bossIds = 적용 보스 목록)
		bossIds = bossIds,
		enhance = Disclosure.enhanceRows(),
		transcend = Disclosure.transcendRows(), -- QUEUE-ALL9E1 0-4
		options = options,
		optionDisabled = OptionData.disabled,
		variants = SkillVariant.disclosure(),
		variantRerollKills = SkillVariantData.rerollKills,
		hatch = Pet.disclosure(),
		firstBossMinGrade = require(game:GetService("ReplicatedStorage").Shared.data.DropTableData).firstBossMinGrade, -- QUEUE-ALL1 P3: 첫 보스 확정 등급(공개 = 실제 굴림)
	}
	out.version = Disclosure.fingerprint(out)
	return out
end

-- 지문: 표 안 숫자 · 문자열을 정해진 순서로 이어 32비트 해시(FNV-1a) → 8자리 16진수
function Disclosure.fingerprint(t)
	local h = 2166136261
	local function feed(s)
		for i = 1, #s do
			h = bit32.bxor(h, string.byte(s, i))
			local lo, hi = h % 65536, (h - h % 65536) / 65536 -- 리뷰: 2^53 넘는 곱을 16비트로 나눠 정확한 32비트 곱
			h = (lo * 16777619 + ((hi * 16777619) % 65536) * 65536) % 4294967296
		end
	end
	local function walk(v)
		local ty = type(v)
		if ty == "table" then
			local keys = {}
			for k in pairs(v) do
				if k ~= "version" then
					table.insert(keys, k)
				end
			end
			table.sort(keys, function(a, b)
				return tostring(a) < tostring(b)
			end)
			for _, k in ipairs(keys) do
				feed(tostring(k))
				walk(v[k])
			end
		elseif ty == "number" then
			feed(("%.9g"):format(v))
		else
			feed(tostring(v))
		end
	end
	walk(t)
	return ("%08x"):format(h)
end

return Disclosure
