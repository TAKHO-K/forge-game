-- QUEUE-ALL1 P5 도감 v2 규칙(순수 - 서버 · 하네스 공용). 데이터 = shared/data/CodexData.
--   칸 목록 · 줄 · 칭호 id를 데이터에서 만든다(새 구역 · 종 · 보스 · 직업 = 그 데이터 추가만으로 칸이 생긴다).
--   기록(profile.codex): armor["구역|등급|부위"] = 횟수 · prim[구역] · trans[구역] · pet["종|부화등급"] · mkill[종] · msparkle[종] · boss[id] · cls[직업] = 최고 등급.
--   둥지 = profile.world.nestDex(기존 기록 그대로 - 서버가 구역별 둥지 id 목록을 넘긴다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
local Text = require(ReplicatedStorage.Shared.Text)

local CodexRules = {}
local PARTS = { "armor", "gloves", "shoes" }
local titleParts = {} -- [칭호 id] = { 틀 종류, 이름 원문 } - titleText(화면용)가 틀과 이름을 따로 바꿔 끼운다

local function zones()
	local out = {}
	for _, z in ipairs(WorldMapData.zones) do
		if CodexData.zoneShort[z.key] then
			table.insert(out, z)
		end
	end
	return out
end

-- 줄 칭호 표(TitleData가 합친다): [id] = { id, name, grade, condition, grantedBy }
function CodexRules.titles()
	local out = {}
	local function add(kind, key, label)
		local id = ("codex_%s_%s"):format(kind, key)
		out[id] = { id = id, name = CodexData.titleFormat[kind]:format(label), grade = CodexData.titleGrade[kind], condition = "도감 줄 완성", grantedBy = "server/CodexService" }
		titleParts[id] = { kind, label }
		return id
	end
	for _, g in ipairs(CodexData.armor.grades) do
		add("armorGrade", g, ArmorData.grades[g].displayName)
	end
	for _, z in ipairs(zones()) do
		local short = CodexData.zoneShort[z.key]
		add("armorZone", z.key, short)
		add("pet", z.key, short)
		add("nest", z.key, short)
		add("monster", z.key, short)
		add("boss", z.bossId, BossData.bosses[z.bossId].displayName)
	end
	for _, classId in ipairs(ClassData.order) do
		add("class", classId, ClassData.classes[classId].displayName)
	end
	return out
end

-- 화면용 칭호 이름(지금 언어 - QUEUE-ALL6 A4). 도감 줄 칭호 = 틀("%s 수집가")과 이름(직업 · 구역 · 등급 · 보스)을 따로 바꿔 끼운다(합친 이름은 사전에 없다).
--   칭호 id · TitleData name · 서버가 보내는 name(한국어)은 그대로 둔다 - 보여 줄 때만 쓴다. 도감 칭호가 아니면 name을 Text.name으로.
function CodexRules.titleText(titleId, name)
	if next(titleParts) == nil then
		CodexRules.titles()
	end
	local p = titleParts[titleId]
	if p then
		return Text.name(CodexData.titleFormat[p[1]]):format(Text.name(p[2]))
	end
	return Text.name(name)
end

-- 칸 · 줄 만들기. nestsByZone = { [구역] = { 둥지 id, ... } }(서버만 안다 - 클라에는 칸 id만 간다)
local CODEX_V2 = require(ReplicatedStorage.Shared.data.UiV2Flags).codex
function CodexRules.build(nestsByZone)
	local cells, lines, byId = {}, {}, {}
	local function line(id, tab, titleKind, titleKey)
		local l = { id = id, tab = tab, cells = {}, titleId = ("codex_%s_%s"):format(titleKind, titleKey) }
		lines[id] = l
		return l
	end
	local function cell(c, ...)
		c.score = c.score == nil and 1 or c.score
		table.insert(cells, c)
		byId[c.id] = c
		for _, l in ipairs({ ... }) do
			table.insert(l.cells, c.id)
		end
	end
	local zs = zones()
	local gradeLines = {}
	for _, g in ipairs(CodexData.armor.grades) do
		gradeLines[g] = line("armorGrade:" .. g, "armor", "armorGrade", g)
	end
	for _, z in ipairs(zs) do
		local zl = line("armorZone:" .. z.key, "armor", "armorZone", z.key)
		for _, g in ipairs(CodexData.armor.grades) do
			for _, p in ipairs(PARTS) do
				cell({ id = ("armor:%s:%s:%s"):format(z.key, g, p), tab = "armor", kind = "armor", zone = z.key, grade = g, part = p, need = CodexData.armor.need[g] }, gradeLines[g], zl)
			end
		end
		cell({ id = "prim:" .. z.key, tab = "armor", kind = "prim", zone = z.key, need = 1, score = 0 })
		local pl = line("pet:" .. z.key, "pet", "pet", z.key)
		for _, sp in ipairs(EggData.zones[z.key].pool) do
			for _, hg in ipairs(EggData.hatchGrades) do
				cell({ id = ("pet:%s:%s"):format(sp, hg), tab = "pet", kind = "pet", zone = z.key, species = sp, hatch = hg, need = 1, label = ("%s(%s)"):format(EggData.species[sp], EggData.hatchGradeNames[hg]) }, pl)
			end
		end
		local nl = line("nest:" .. z.key, "nest", "nest", z.key)
		for i, nestId in ipairs((nestsByZone and nestsByZone[z.key]) or {}) do
			cell({ id = "nest:" .. nestId, tab = "nest", kind = "nest", zone = z.key, nestId = nestId, need = 1, label = CodexData.text.nestHidden:format(i) }, nl)
		end
		local ml = line("monster:" .. z.key, "monster", "monster", z.key)
		for _, m in ipairs(z.hunt and z.hunt.monsters or {}) do
			local spec = MonsterSpeciesData.species[m.species]
			for _, step in ipairs(CodexData.monster.steps) do
				cell({ id = ("mon:%s:%s"):format(m.species, step.id), tab = "monster", kind = "monster", zone = z.key, species = m.species, step = step.id, need = step.kills or 1, sparkle = step.sparkle,
					big = step.id == "k1000" or step.sparkle == true, label = ("%s · %s"):format(spec and spec.displayName or m.species, step.label) }, ml)
			end
		end
		local bl = line("boss:" .. z.bossId, "boss", "boss", z.bossId)
		for _, n in ipairs(CodexData.boss.steps) do
			cell({ id = ("boss:%s:%d"):format(z.bossId, n), tab = "boss", kind = "boss", zone = z.key, bossId = z.bossId, need = n, label = ("%s · %d번"):format(BossData.bosses[z.bossId].displayName, n) }, bl)
		end
	end
	for _, classId in ipairs(ClassData.order) do
		local cl = line("class:" .. classId, "class", "class", classId)
		for g = 0, CodexData.class.grades - 1 do
			cell({ id = ("cls:%s:%d"):format(classId, g), tab = "class", kind = "class", classId = classId, weaponGrade = g, need = 1,
				label = ("%s · 무기 %s"):format(ClassData.classes[classId].displayName, ArmorData.grades[ArmorData.gradeOrder[g + 1]].displayName) }, cl)
		end
		if CodexData.class.transcendCell then -- FINAL-1b 결정 6: 초월 칸(8번째)
			local tg = CodexData.class.grades -- 7 = transcendent
			cell({ id = ("cls:%s:t"):format(classId), tab = "class", kind = "class", classId = classId, weaponGrade = tg, transcend = true, need = 1,
				label = ("%s · 무기 %s"):format(ClassData.classes[classId].displayName, ArmorData.grades[ArmorData.gradeOrder[tg + 1]].displayName) },
				not CODEX_V2 and cl or nil) -- UI-1 5단계(D 도감 v2): 줄 칭호 = 일반 ~ 태초 7칸 완성 · 초월 칸 = 따로 "초월 완성" 왕관(줄 토큰 ⌈7 × 0.5⌉ = 4로 같음)
		end
	end
	local total = 0
	for _, c in ipairs(cells) do
		total += c.score
	end
	return { cells = cells, lines = lines, byId = byId, totalScore = total }
end

-- 칸 진행(현재 값, 완료 여부). rec = profile.codex · nestDex = profile.world.nestDex
function CodexRules.progress(rec, nestDex, c)
	local v = 0
	if c.kind == "armor" then
		if rec.trans and rec.trans[c.zone] then
			return c.need, true -- 초월 = 그 세트 세로줄 즉시 완료
		end
		v = tonumber(rec.armor and rec.armor[("%s|%s|%s"):format(c.zone, c.grade, c.part)]) or 0
	elseif c.kind == "prim" then
		v = (rec.prim and rec.prim[c.zone]) and 1 or 0
	elseif c.kind == "pet" then
		v = (rec.pet and rec.pet[c.species .. "|" .. c.hatch]) and 1 or 0
	elseif c.kind == "nest" then
		v = (nestDex and nestDex[c.nestId]) and 1 or 0
	elseif c.kind == "monster" then
		if c.sparkle then
			v = (rec.msparkle and rec.msparkle[c.species]) and 1 or 0
		else
			v = tonumber(rec.mkill and rec.mkill[c.species]) or 0
		end
	elseif c.kind == "boss" then
		v = tonumber(rec.boss and rec.boss[c.bossId]) or 0
	elseif c.kind == "class" and c.transcend then
		v = (rec.clsT and rec.clsT[c.classId]) and 1 or 0 -- FINAL-1b: 초월 칸 = 그 직업 무기 초월 기록
	elseif c.kind == "class" then
		local best = rec.cls and tonumber(rec.cls[c.classId])
		v = (best and best >= c.weaponGrade) and 1 or 0
	end
	return math.min(v, c.need), v >= c.need
end

-- 칸 보상(골드 = 완료 순간 스테이지 · goldPerKill(스테이지) 함수는 호출부가 준다 - 서버 = 잡몹 골드)
function CodexRules.reward(c, stage, goldPerKill)
	local r
	if c.kind == "armor" then
		r = { goldKills = CodexData.armor.goldKills[c.grade], enhanceStone = CodexData.armor.enhanceStone[c.grade] }
	elseif c.kind == "prim" then
		r = table.clone(CodexData.armor.primordialReward)
	elseif c.kind == "pet" then
		r = table.clone(CodexData.pet.reward)
		r.eggZone = c.zone
	elseif c.kind == "nest" then
		r = table.clone(CodexData.nest.reward)
	elseif c.kind == "monster" then
		r = table.clone(c.big and CodexData.monster.bigReward or CodexData.monster.reward)
	elseif c.kind == "boss" then
		r = table.clone(CodexData.boss.reward)
	elseif c.kind == "class" then
		r = { enhanceStone = CodexData.class.stoneBase + CodexData.class.stonePerGrade * c.weaponGrade }
	elseif c.kind == "board" then
		r = CodexData.boardReward(c.threshold)
	end
	local shards = CodexData.shardsFor(c) -- QUEUE-ALL6 K: 분류별 반짝 조각
	if r and shards > 0 then
		r.sparkleShard = (r.sparkleShard or 0) + shards
	end
	if r and r.goldKills then
		r.gold = require(ReplicatedStorage.Shared.GoldCost).niceReward(math.floor(r.goldKills * goldPerKill(stage or 1))) -- QUEUE-ALL6 D: 보기 좋은 숫자(서버 지급 · 도감 창 미리보기 같은 함수)
		r.goldKills = nil
	end
	return r
end

-- UI-1 5단계 진행 상자: 옛 점수판 29단계 합(goldKills · enhanceStone)
function CodexRules.boardTotals()
	local t = { goldKills = 0, enhanceStone = 0 }
	for _, th in ipairs(CodexData.board) do
		local r = CodexData.boardReward(th)
		t.goldKills += r.goldKills or 0
		t.enhanceStone += r.enhanceStone or 0
	end
	return t
end

-- 상자 n(1 ~ 10)의 보상 몫: 합 ÷ 10(내림) · 나머지 = 마지막 상자 · 토큰 = tokensAt
function CodexRules.boxShare(n)
	local total, count = CodexRules.boardTotals(), CodexData.boxes.count
	local r = {}
	for k, v in pairs(total) do
		local each = math.floor(v / count)
		r[k] = each + (n == count and (v - each * count) or 0)
	end
	r.sparkleShard = CodexData.boxes.tokensAt[n]
	return r
end

-- 상자 n까지 몫의 누적(골드 몫 · 강화석)
function CodexRules.boxCumulative(n)
	local c = { goldKills = 0, enhanceStone = 0 }
	for i = 1, n do
		local s = CodexRules.boxShare(i)
		c.goldKills += s.goldKills
		c.enhanceStone += s.enhanceStone
	end
	return c
end

-- 이미 받은 점수판 몫(boardClaimed 키 = 점수) → 상자 n을 받을 때 실제로 줄 몫 = max(0, 누적(n) − 받은 몫) − max(0, 누적(n − 1) − 받은 몫) · 토큰은 새 몫이라 그대로
function CodexRules.boxPay(n, boardClaimed)
	local paid = { goldKills = 0, enhanceStone = 0 }
	for key, yes in pairs(boardClaimed or {}) do
		if yes then
			local r = CodexData.boardReward(tonumber(key) or 0)
			paid.goldKills += r.goldKills or 0
			paid.enhanceStone += r.enhanceStone or 0
		end
	end
	local now, before = CodexRules.boxCumulative(n), CodexRules.boxCumulative(n - 1)
	local out = {}
	for k in pairs(paid) do
		out[k] = math.max(0, now[k] - paid[k]) - math.max(0, before[k] - paid[k])
	end
	out.sparkleShard = CodexData.boxes.tokensAt[n]
	return out
end

-- 상자 n이 열리는 점수(전체 점수 칸 × n × 10% · 올림)
function CodexRules.boxThreshold(n, totalScore)
	return math.ceil(totalScore * n / CodexData.boxes.count)
end

-- QUEUE-ALL9B 3-6 · 3-7: 이 도감에서 얻을 수 있는 토큰 합(칸 + 줄 완성). 도감 업데이트 소식 "토큰 +n" = totalTokens(새) - totalTokens(옛).
function CodexRules.totalTokens(book)
	local sum = 0
	for _, c in ipairs(book.cells) do
		sum += CodexData.shardsFor(c)
	end
	for _, l in pairs(book.lines) do
		sum += CodexData.lineTokens(#l.cells)
	end
	return sum
end

-- QUEUE-MENU2 B2: 이 칸 보상을 지금 캐릭터가 받을 수 있는가(r.doneBy[칸] = 완료한 캐릭터 번호 · 없음 = 옛 기록 → 누구나)
function CodexRules.cellMine(r, id, charId)
	local by = type(r.doneBy) == "table" and r.doneBy[id] or nil
	return by == nil or by == charId
end

return CodexRules
