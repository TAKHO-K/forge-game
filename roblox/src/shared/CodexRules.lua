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

return CodexRules
