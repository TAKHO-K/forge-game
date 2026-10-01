-- QUEUE-ALL6 K: 도감 반짝 조각 흐름표(실제 CodexRules.build · CodexData.shardsFor). 실행 = build_run.py(의존 없음)
local CodexRules, CodexData = MODS.CodexRules, MODS.CodexData
local nests = {}
for _, spec in ipairs(MODS.SecretNestData) do -- CodexService와 같은 거르기(트랙 C · 마을 제외)
	if spec.track == "C" and spec.sub ~= "village" and CodexData.zoneShort[spec.zone] then
		nests[spec.zone] = nests[spec.zone] or {}
		table.insert(nests[spec.zone], spec.id)
	end
end
local book = CodexRules.build(nests)
local per, cnt = {}, {}
local cells = {}
for _, c in ipairs(book.cells) do
	if c.score > 0 then
		local s = CodexData.shardsFor(c)
		per[c.kind] = (per[c.kind] or 0) + s
		cnt[c.kind] = (cnt[c.kind] or 0) + 1
		-- 어려움(0 = 쉬움): 장비 등급 · 펫 부화 등급 · 몬스터 단계 · 보스 횟수 · 직업 무기 등급 순번
		local d = 0
		if c.kind == "armor" then d = table.find(CodexData.armor.grades, c.grade) - 1
		elseif c.kind == "pet" then d = ({ common = 0, uncommon = 1, rare = 3, epic = 5 })[c.hatch]
		elseif c.kind == "nest" then d = 2
		elseif c.kind == "monster" then d = ({ met = 0, k10 = 1, k100 = 2, k1000 = 4, sparkle = 4 })[c.step]
		elseif c.kind == "boss" then d = table.find(CodexData.boss.steps, c.need) - 1
		elseif c.kind == "class" then d = c.weaponGrade end
		table.insert(cells, { s = s, d = d, kind = c.kind, k = #cells })
	end
end
local total = 0
for kind, s in pairs(per) do
	print(("[K] %s 칸 %d · 조각 합 %d"):format(kind, cnt[kind], s))
	total += s
end
print(("[K] 전체 점수 %d · 조각 합 %d · 절반 %d점"):format(book.totalScore, total, book.totalScore // 2))
table.sort(cells, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.k < b.k end)
local half = book.totalScore // 2
local acc, rows = 0, {}
for i, c in ipairs(cells) do
	acc += c.s
	if i % 30 == 0 or i == half then
		table.insert(rows, ("%d점 %d"):format(i, acc))
	end
end
print("[K] 쉬운 칸부터: " .. table.concat(rows, " · "))
-- 무작위 순서 100번 평균(절반 점수)
local sum = 0
local rng = Random.new(20261002)
for _ = 1, 100 do
	local order = table.clone(cells)
	for i = #order, 2, -1 do local j = rng:NextInteger(1, i) order[i], order[j] = order[j], order[i] end
	local a = 0
	for i = 1, half do a += order[i].s end
	sum += a
end
print(("[K] 무작위 순서 100번 평균(%d점) = %.1f"):format(half, sum / 100))
