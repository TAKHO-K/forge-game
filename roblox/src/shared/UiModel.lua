-- QUEUE-UI UI-0 화면이 읽는 게임 데이터 모양(순수 - 하네스가 그대로 부른다). 직업 · 스킬 · 아이콘은 여기서만 게임 데이터를 읽는다 →
--   신직업 = ClassData(order · classes · cards) · SkillData · UltimateData · UiIconData.classArt에 줄 추가만으로 메뉴 · 카드 · 직업 선택에 나타난다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local IconData = require(ReplicatedStorage.Shared.data.UiIconData)
local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)

local UiModel = {}

-- 화면 루트 배율: 화면 크기 · 폰 여부 → 기준 크기(PC 1920×1080 · 폰 800×360) · UIScale = min(화면W/기준W, 화면H/기준H)
function UiModel.fit(viewW, viewH, isPhone)
	local base = isPhone and Tokens.base.phone or Tokens.base.pc
	return base, math.min(viewW / base.w, viewH / base.h)
end

-- 무기 등급 번호(0부터 - 저장값 weapon.grade) → 등급 id
function UiModel.gradeId(gradeIndex)
	return ArmorData.gradeOrder[(tonumber(gradeIndex) or 0) + 1] or ArmorData.gradeOrder[1]
end

-- 직업 무기 아이콘 키(ArtAssetIds) - 이어하기 카드 무기 칸 · 공격 버튼(UiIconData.attackUsesWeaponIcon)
function UiModel.weaponIconKey(classId, gradeIndex)
	if not classId or classId == "" then
		return nil
	end
	return ("icons/weapons/%s_%s"):format(classId, UiModel.gradeId(gradeIndex))
end

-- 직업 한 개의 화면 모양(직업 선택 목록 · 정보 창)
function UiModel.classInfo(classId)
	local c = ClassData.classes[classId]
	if not c then
		return nil
	end
	local card = ClassData.cards and ClassData.cards[classId] or {}
	local sd = SkillData[classId] or {}
	local ult = UltimateData.skills and UltimateData.skills[classId]
	local art = IconData.classArt[classId] or {}
	local tend = {}
	for _, key in ipairs(ClassData.tendencyKeys or {}) do
		table.insert(tend, { key = key, value = card.tendency and card.tendency[key] or 3 })
	end
	return {
		id = classId,
		name = c.displayName or classId,
		role = card.role or "melee",
		difficulty = card.difficulty or 1,
		skills = { q = sd.Q and sd.Q.name, e = sd.E and sd.E.name, ult = ult and ult.name },
		tendency = tend,
		legend = art.legend, -- ArtAssetIds 키(없으면 임시 실루엣)
		face = art.face,
		faceRect = art.faceRect,
		placeholder = art.placeholder, -- 전설 그림 대기 중 자리표시 그림(UI2-3)
		temp = art.legend == nil, -- "임시" 표시(그림 없음)
	}
end

-- 직업 선택 목록(출시 직업 순서)
function UiModel.classList()
	local out = {}
	for _, id in ipairs(ClassData.order) do
		local info = UiModel.classInfo(id)
		if info then
			table.insert(out, info)
		end
	end
	return out
end

-- 이어하기 창 줄 목록: slots = 계정 요약(칸 → 요약 | false) · slotCount = 출시 직업 수 · lockedPreview = 끝 잠긴 칸 수
--   → { { kind = "card"|"empty"|"locked", slot, summary, number(같은 직업 ① ②) } … } · 마지막 플레이 캐릭터가 맨 위
function UiModel.slotRows(slots, slotCount, lockedPreview)
	local cards, empties = {}, {}
	local perClass = {}
	for i = 1, slotCount do
		local s = slots[i]
		if s then
			table.insert(cards, { kind = "card", slot = i, summary = s })
			perClass[s.classId] = (perClass[s.classId] or 0) + 1
		else
			table.insert(empties, { kind = "empty", slot = i })
		end
	end
	-- 같은 직업 번호 = 만든 순서(createdAt)
	local byClass = {}
	for _, r in ipairs(cards) do
		byClass[r.summary.classId] = byClass[r.summary.classId] or {}
		table.insert(byClass[r.summary.classId], r)
	end
	for classId, list in pairs(byClass) do
		table.sort(list, function(a, b)
			return (a.summary.createdAt or 0) < (b.summary.createdAt or 0) or ((a.summary.createdAt or 0) == (b.summary.createdAt or 0) and a.slot < b.slot)
		end)
		for n, r in ipairs(list) do
			r.number = perClass[classId] > 1 and n or nil -- 1개면 번호 없음
		end
	end
	table.sort(cards, function(a, b)
		return (a.summary.lastPlayedAt or 0) > (b.summary.lastPlayedAt or 0) or ((a.summary.lastPlayedAt or 0) == (b.summary.lastPlayedAt or 0) and a.slot < b.slot)
	end)
	local rows = {}
	for _, r in ipairs(cards) do
		table.insert(rows, r)
	end
	for _, r in ipairs(empties) do
		table.insert(rows, r)
	end
	for _ = 1, lockedPreview or 0 do
		table.insert(rows, { kind = "locked" })
	end
	return rows
end

-- "○○로 / ○○으로 시작" - 받침 있으면 "으로"(ㄹ 받침 = "로")
function UiModel.josaRo(name)
	local last = utf8.codepoint(name, utf8.offset(name, -1))
	if last < 0xAC00 or last > 0xD7A3 then
		return "로"
	end
	local jong = (last - 0xAC00) % 28
	return (jong == 0 or jong == 8) and "로" or "으로"
end

-- QUEUE-UI2 UI2-2 글자 크기: 토큰 이름 → 기준 px(PC/폰 · scale 이름 따라감)
function UiModel.textToken(name, isPhone)
	local t = Tokens.text[name] or Tokens.textScale[name] -- 화면 이름(cardInfo 등) 또는 단계 이름(body · heading 등)
	if type(t) == "string" then
		t = Tokens.textScale[t]
	end
	assert(type(t) == "table", "UiModel.textToken: UiTokens.text에 없는 글자 - " .. tostring(name))
	return math.max(isPhone and t.phone or t.pc, isPhone and Tokens.minPhoneText or 0)
end

-- 글자 배율 = max(설정 글자 크기 단계, 로블록스 PreferredTextSize 배율) - 둘을 곱하지 않는다(두 번 커지지 않게)
function UiModel.textMul(stepKey, platformName)
	local user = Tokens.textScaleSteps[stepKey or "normal"] or 1
	local platform = Tokens.platformTextScale[platformName or "Medium"] or 1
	return math.max(user, platform)
end

-- 실제 TextSize(UiRoot UIScale 안): 토큰 × 글자 배율 × 루트 배율 보정(작은 창에서 글자만 덜 줄임 - 화면 글자 = 토큰 × max(루트, textMinRootScale))
function UiModel.textPx(name, isPhone, stepKey, platformName, rootScale)
	local base = UiModel.textToken(name, isPhone)
	local s = tonumber(rootScale) or 1
	local comp = s > 0 and math.max(1, Tokens.textMinRootScale / s) or 1
	return math.floor(base * UiModel.textMul(stepKey, platformName) * comp + 0.5)
end

-- QUEUE-UI1F-1 소식 빨간 점: 가장 큰 소식 id · 본 id(설정 lastSeenNewsId - 옛 저장 = nil = 0)보다 크면 점
function UiModel.newsLatestId(news)
	local best = 0
	for _, n in ipairs(news or {}) do
		best = math.max(best, tonumber(n.id) or 0)
	end
	return best
end
function UiModel.newsDot(news, seenId)
	return UiModel.newsLatestId(news) > (tonumber(seenId) or 0)
end

return UiModel
