-- QUEUE-ALL3 Q1 도감 그림 · 보상판(10 문서 1절): 칸 id → 그림 · 이름 · 등급 · 어디서 · 보상 · 3D 모델 키. 인스턴스를 만들지 않는다(창 = panels/Codex · 칸 = CodexV2/Grid · 상세 = CodexV2/Detail).
--   그림 표 = roblox/art/icons/codex/_map.json을 규칙으로 옮긴 것(328칸 + 무기 28 전부 같은 규칙 - 파일과 한 칸도 안 어긋남을 대조함):
--     armor:<구역>:<등급>:<부위> → icons/armor/<부위>_<구역>_<등급> · prim:<구역> → icons/armor/armor_<구역>_primordial · pet:<종>:<부화등급> → icons/codex/pet_<종>_<부화등급>
--     mon:<종>:* → icons/codex/monster_<종> · boss:<id>:* → icons/codex/boss_<id> · cls:<직업>:<n> → icons/codex/class_<직업> + icons/weapons/<직업>_<무기 등급 n>
--     탐험(둥지) = 사진 없음(아직) → 찾은 둥지 = 탐험 탭 그림 + 구역 색 바탕 · 못 찾은 둥지 = 흐린 타일 + 구역 이름만(위치 누설 금지).
--   칸 속성(구역 · 종 · 단계)은 서버와 같은 CodexRules.build로 만든다(서버가 둥지 id는 안 보내므로 둥지는 화면 표의 줄 "nest:<구역>" 순서로 번호를 붙인다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GradeColor = require(game:GetService("ReplicatedStorage").Shared.GradeColor) -- QUEUE-ALL9C 2-2 등급 색 쓰임별(text · border)
local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local CodexRules = require(ReplicatedStorage.Shared.CodexRules)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
local MonsterCodexData = require(ReplicatedStorage.Shared.data.MonsterCodexData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)

local Info = {}

local BUILT = CodexRules.build({})
local META = BUILT.byId
Info.parts = { "armor", "gloves", "shoes" }

-- 탭(그림 = icons/codex/tab_<이름>)
Info.tabs = {
	{ id = "armor", icon = "equipment" }, { id = "pet", icon = "pet" }, { id = "nest", icon = "explore" }, { id = "monster", icon = "monster" },
	{ id = "boss", icon = "boss" }, { id = "class", icon = "class" }, { id = "board", icon = "rewards" }, { id = "title", icon = "title" },
}
Info.V2 = require(ReplicatedStorage.Shared.data.UiV2Flags).codex -- UI-1 5단계 도감 v2(08 v4-codex): 점수판 탭 없음(진행 상자 10개가 대신)
if Info.V2 then
	for i = #Info.tabs, 1, -1 do
		if Info.tabs[i].id == "board" then
			table.remove(Info.tabs, i)
		end
	end
end

Info.zones = {}
local zoneIndex, bossZone = {}, {}
for _, z in ipairs(WorldMapData.zones) do
	if CodexData.zoneShort[z.key] then
		table.insert(Info.zones, z)
		zoneIndex[z.key] = #Info.zones
		bossZone[z.bossId] = z
	end
end
local classIndex = {}
for i, c in ipairs(ClassData.order) do
	classIndex[c] = i
end

-- 등급 글자색(QUEUE-ALL9C 2-2: shared/GradeColor.text - 대비 4.5:1 · 펫 등급 → 장비 색 = ItemVisualData.petGradeColorOf)
function Info.gradeColor(grade)
	return ItemVisualData.gradeVisuals[grade] and GradeColor.text(grade) or Color3.fromRGB(200, 200, 210)
end

function Info.zone(key)
	return Info.zones[zoneIndex[key] or 0]
end

-- 줄 정렬 순서(구역 · 보스 구역 · 직업 순)
function Info.lineOrder(lineId)
	local suffix = lineId:match(":(.+)$") or ""
	return zoneIndex[suffix] or (bossZone[suffix] and zoneIndex[bossZone[suffix].key]) or (classIndex[suffix] and 100 + classIndex[suffix]) or 999
end

-- 둥지 칸 = { zone, index }(화면 표 줄 순서)
local nests = {}
function Info.indexNests(view)
	nests = {}
	for id, l in pairs(view.lines) do
		local zk = id:match("^nest:(.+)$")
		if zk then
			for i, cid in ipairs(l.cells) do
				nests[cid] = { zone = zk, index = i }
			end
		end
	end
end

function Info.meta(id)
	local m = META[id]
	if m then
		return m
	end
	local n = nests[id]
	if n then
		return { id = id, kind = "nest", zone = n.zone, index = n.index, need = 1 }
	end
	return nil
end

local function cellV(view, id)
	local c = view and view.cells[id]
	return c and c.v or 0
end

-- 아직 못 만난 것(몬스터 · 보스 · 펫) = 검은 실루엣
function Info.unknown(view, m)
	if m.kind == "monster" then
		return cellV(view, ("mon:%s:met"):format(m.species)) < 1
	elseif m.kind == "boss" then
		return cellV(view, ("boss:%s:1"):format(m.bossId)) < 1
	elseif m.kind == "pet" then
		return cellV(view, m.id) < 1
	end
	return false
end

-- 그림: { key, overlay, silhouette, dim, tint(바탕색) }
function Info.picture(view, m)
	local k = m.kind
	if k == "armor" then
		return { key = ("icons/armor/%s_%s_%s"):format(m.part, m.zone, m.grade) }
	elseif k == "prim" then
		return { key = ("icons/armor/armor_%s_primordial"):format(m.zone) }
	elseif k == "pet" then
		return { key = ("icons/codex/pet_%s_%s"):format(m.species, m.hatch), silhouette = Info.unknown(view, m) }
	elseif k == "monster" then
		return { key = "icons/codex/monster_" .. m.species, silhouette = Info.unknown(view, m) }
	elseif k == "boss" then
		if require(ReplicatedStorage.Shared.data.UiV2Flags).codexNewLook then -- UI-1b 1-b 18: 보스 칸 그림 = F 초상(옛 몸 렌더 icons/codex/boss_* 대신)
			local e = require(ReplicatedStorage.Shared.data.BossPortraitData).bosses[m.bossId]
			if e and e.image then
				return { key = e.image, silhouette = Info.unknown(view, m) }
			end
		end
		return { key = "icons/codex/boss_" .. m.bossId, silhouette = Info.unknown(view, m) }
	elseif k == "class" then
		return { key = "icons/codex/class_" .. m.classId, overlay = ("icons/weapons/%s_%s"):format(m.classId, ArmorData.gradeOrder[m.weaponGrade + 1]) }
	elseif k == "nest" then
		local z = Info.zone(m.zone)
		local t = z and z.floorTint or { 140, 150, 140 }
		return { key = "icons/codex/tab_explore", dim = cellV(view, m.id) < 1, tint = Color3.fromRGB(t[1], t[2], t[3]):Lerp(Color3.fromRGB(96, 160, 90), 0.35) }
	end
	return { key = "icons/codex/tab_title" }
end

-- 칸 한 줄 이름(짧게)
function Info.shortName(view, m)
	local k = m.kind
	if k == "prim" then
		return Text.get("codex.v2.primName", { zone = CodexData.zoneShort[m.zone] })
	elseif k == "pet" then
		return Info.unknown(view, m) and "?" or Text.name(EggData.species[m.species])
	elseif k == "monster" then
		if Info.unknown(view, m) then
			return "?"
		end
		for _, s in ipairs(CodexData.monster.steps) do
			if s.id == m.step then
				return Text.name(s.label)
			end
		end
	elseif k == "boss" then
		return Info.unknown(view, m) and "?" or Text.get("codex.v2.bossStep", { n = tostring(m.need) })
	elseif k == "class" then
		return Text.get("codex.v2.weapon", { grade = ArmorData.grades[ArmorData.gradeOrder[m.weaponGrade + 1]].displayName })
	elseif k == "nest" then
		return cellV(view, m.id) >= 1 and Text.get("codex.v2.nest", { n = tostring(m.index) }) or Text.name(CodexData.zoneShort[m.zone])
	end
	return m.id
end

-- 상세: 이름 · 등급 글 · 등급 색
function Info.detailName(view, m)
	local k = m.kind
	if k == "armor" then
		return Text.get("codex.v2.bingoName", { zone = CodexData.zoneShort[m.zone], grade = ArmorData.grades[m.grade].displayName }), Text.name(ArmorData.grades[m.grade].displayName), Info.gradeColor(m.grade)
	elseif k == "prim" then
		return Info.shortName(view, m), Text.name(ArmorData.grades.primordial.displayName), Info.gradeColor("primordial")
	elseif k == "pet" then
		return Info.shortName(view, m), Text.name(EggData.hatchGradeNames[m.hatch]), Info.gradeColor(GradeColor.petGrade(m.hatch))
	elseif k == "monster" then
		local spec = MonsterSpeciesData.species[m.species]
		return Info.unknown(view, m) and "?" or (spec and Text.name(spec.displayName) or m.species), Info.unknown(view, m) and "?" or Info.shortName(view, m), m.big and Info.gradeColor("legendary") or Info.gradeColor("rare")
	elseif k == "boss" then
		return Info.unknown(view, m) and "?" or Text.name(BossData.bosses[m.bossId].displayName), Text.get("codex.v2.bossStep", { n = tostring(m.need) }), Info.gradeColor("epic")
	elseif k == "class" then
		local g = ArmorData.gradeOrder[m.weaponGrade + 1]
		return Text.get("class.name." .. m.classId), Info.shortName(view, m), Info.gradeColor(g)
	elseif k == "nest" then
		local found = cellV(view, m.id) >= 1
		return found and Info.shortName(view, m) or Text.get("codex.v2.nestUnknown"), Text.name(CodexData.zoneShort[m.zone]), Info.gradeColor("rare")
	end
	return m.id, "", Info.gradeColor("normal")
end

-- 설명 글(상세 칸에만): 몬스터 = 도감 힌트(만난 뒤)
function Info.hint(view, m)
	if m.kind == "monster" and not Info.unknown(view, m) then
		local e = MonsterCodexData.entries[m.species]
		return e and Text.name(e.hint) or nil
	end
	return nil
end

-- 어디서: { place(글), position(Vector3 - 지도 조각), zone(구역 키), guide = { quest = 키 } | { pos, label } }
function Info.where(m)
	local k = m.kind
	if k == "class" then
		local f = WorldMapData.hub.facilities.community
		return { place = f.displayName, position = WorldMapLayout.facility("community"), guide = { quest = "altar" } }
	end
	local z = Info.zone(m.zone)
	if not z then
		return nil
	end
	if k == "monster" then
		local g = WorldMapLayout.grounds(z)[1]
		return { place = z.hunt.name, zone = z.key, position = g.center, guide = { pos = g.center, label = z.hunt.name } }
	elseif k == "boss" then
		local gate = WorldMapLayout.bossGate(m.bossId)
		if gate then
			return { place = gate.name, zone = z.key, position = gate.position, guide = { pos = gate.position, label = gate.name } }
		end
	end
	return { place = z.theme, zone = z.key, position = WorldMapLayout.camp(z), guide = { quest = "zone:" .. z.key } }
end

-- 보상 표(그림 + 수량) + 골드 글자. 골드 = 계정 최고 스테이지 기준 어림(서버는 완료 순간 스테이지로 고정)
function Info.reward(m)
	local stage = Players.LocalPlayer:GetAttribute("AccountBestStage") or 1
	local r = CodexRules.reward(m, stage, function(s)
		return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, s)
	end)
	if not r then
		return nil, nil
	end
	r.eggZone = nil
	return r, r.gold and NumberFormat.format(r.gold) or nil
end

-- 3D 미리보기 모델 키(ArtMeshCache - 없으면 2D 그림): 몬스터 · 보스(만난 뒤) · 직업 무기
function Info.model(view, m)
	if (m.kind == "monster" or m.kind == "boss") and Info.unknown(view, m) then
		return nil
	end
	if m.kind == "monster" then
		return { key = "monsters/" .. m.species }
	elseif m.kind == "boss" then
		return { key = "bosses/" .. m.bossId }
	elseif m.kind == "class" then
		return { weapon = m.classId, grade = ArmorData.gradeOrder[m.weaponGrade + 1] }
	end
	return nil
end

return Info
