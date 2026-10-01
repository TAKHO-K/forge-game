-- 스킬 툴팁 글(P3b D) - 순수 함수. 규칙 · 사거리 · 틱 수 같은 고정 값은 SkillData(스킬 단일 출처)에서, 내 능력치에 따른 수치(공격력 · 1타 피해 · 쿨다운 · 치명 · 버프 값)는
-- 서버 SkillStats.info(스킬 판정이 쓰는 함수 그대로)가 준 info에서만 가져온다 - 이 파일은 곱셈 · 나눗셈으로 피해를 다시 계산하지 않는다(표시 형식만 만든다).
-- 반환 = { title, keyText, lines = { { id, label, text, colorName? } } }. 줄 순서: 설명 · 계수 · 예상 피해 · 쿨타임 · 발동 · 사거리/범위 · 최대 타격 · 관통 · 치명 · 최종 데미지 버킷 · 치유사(모드 · 버프) · 규칙.
-- QUEUE-ALL4 E: 글 = Text 키(desc.skill.* - TextData_shared) · id = 줄 머리 키의 끝(cooldown · expected · effect …) - 언어와 무관하게 줄을 고를 때 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ShieldConfig = require(ReplicatedStorage.Shared.data.ShieldConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)

local SkillTooltipText = {}

local function pct(value)
	local text = ("%.1f"):format(value * 100)
	return (text:gsub("%.0$", "")) .. "%"
end
SkillTooltipText.pct = pct -- P3d F3: 파티 칩이 툴팁과 같은 모양으로 쓴다

local function num(value)
	if value == nil then
		return "-"
	end
	if value < 100 then
		return (("%.1f"):format(value):gsub("%.0$", ""))
	end
	return NumberFormat.format(value)
end

local function seconds(value)
	return Text.get("desc.skill.seconds", { n = (("%.1f"):format(value):gsub("%.0$", "")) })
end

local function int(value)
	return ("%d"):format(value)
end

-- 발동 글 키(desc.skill.act.<shape>) - 표에 없는 모양은 모양 id를 그대로 보여 준다.
local ACTIVATION = {
	line = true,
	circle = true,
	selfBuff = true,
	dash = true,
	summon = true,
	singleChannel = true,
	heal = true,
	toggle = true,
}

-- classId · slot("Q" | "E") · info = SkillStats.info 응답(없으면 수치 줄은 "불러오는 중").
function SkillTooltipText.build(classId, slot, info)
	local def = SkillData[classId] and SkillData[classId][slot]
	if not def then
		return nil
	end
	local stats = info and info.slots and info.slots[slot]
	local lines = {}
	local function add(id, text, colorName)
		table.insert(lines, { id = id, label = Text.get("desc.skill.label." .. id), text = text, colorName = colorName })
	end
	local function t(key, args)
		return Text.get("desc.skill." .. key, args)
	end
	local loading = t("loading")
	local optionText = stats and stats.optionBonus and math.abs(stats.optionBonus) > 1e-9 and t("option", { pct = ("%+.0f"):format(stats.optionBonus * 100) }) or ""
	local critText = info and t("critInfo", { rate = pct(math.min(1, info.critRate)), dmg = num(info.critDmg) }) or "-"
	local shape = def.shape
	local ticks = def.tickCount or 1

	-- 설명
	if shape == "line" then
		add("desc", t("desc.line", { range = num(def.rangeStuds) }))
	elseif shape == "circle" then
		add("desc", t("desc.circle", { time = seconds(def.channelSeconds), ticks = int(ticks), move = num(def.channelMoveSpeedMultiplier), taken = num(def.incomingDamageMultiplier) }))
	elseif shape == "selfBuff" then
		add("desc", t("desc.selfBuff", { time = seconds(def.durationSeconds), pierce = int((def.heavyShot and def.heavyShot.pierce or 0) + 1), delay = seconds(def.stuckArrowDelaySeconds) }))
	elseif shape == "dash" then
		add("desc", t("desc.dash", { range = num(def.rangeStuds), charges = int(def.chargesGranted) }))
	elseif shape == "summon" then
		add("desc", t("desc.summon"))
	elseif shape == "singleChannel" then
		add("desc", t("desc.singleChannel", { time = seconds(def.channelSeconds), ticks = int(ticks) }))
	elseif shape == "heal" then
		add("desc", t("desc.heal", { pct = pct(def.healPercentOfMaxHp) }))
	elseif shape == "toggle" then
		add("desc", t("desc.toggle"))
	end

	-- 계수 · 예상 피해
	if def.coefficient then
		local perHit = stats and stats.hitCoefficient
		if ticks > 1 then
			add("coef", t("coefMulti", { total = pct(stats and stats.castCoefficient or def.coefficient), perHit = pct(perHit or def.coefficient / ticks), ticks = int(ticks), option = optionText }))
		else
			add("coef", t("coef", { pct = pct(perHit or def.coefficient), option = optionText }))
		end
		if stats and stats.hitDamage then
			if ticks > 1 then
				add("expected", t("dmgMulti", { hit = num(stats.hitDamage), crit = num(stats.critHitDamage), ticks = int(ticks), total = num(stats.castDamage) }), "ember")
			else
				add("expected", t("dmg", { hit = num(stats.hitDamage), crit = num(stats.critHitDamage) }), "ember")
			end
		else
			add("expected", loading, "textTertiary")
		end
	elseif shape == "selfBuff" then
		add("effect", stats and t("selfBuff.effect", { speed = num(stats.speedMultiplier), cap = num(def.attackSpeedCap), option = optionText, interval = num(def.heavyShot and def.heavyShot.intervalMultiplier or 1) }) or loading, "ember")
		add("expected", stats and t("selfBuff.dmg", { dmg = num(stats.arrowDamage), pct = pct(def.stuckArrowDamageCoefficient) }) or loading, "ember")
	elseif shape == "dash" then
		add("effect", t("dash.effect", { charges = int(def.chargesGranted), crit = pct(def.critRateBonus), dmg = pct(def.damageCoefficient), range = num(def.rangeMultiplier) }))
		add("expected", stats and stats.bonusDamage and t("dash.dmg", { dmg = num(stats.bonusDamage) }) or loading, "ember")
	elseif shape == "summon" then
		add("effect", stats and t("summon.effect", { time = seconds(stats.duration), option = optionText }) or loading, "ember")
	elseif shape == "heal" then
		if stats and stats.shieldMode then
			-- 딜링모드 + 파티: 이번 시전은 회복 대신 쉴드(리뷰 6 - 회복량을 보여 주면 실제와 다르다).
			add("shield", t("heal.shield", { amount = num(stats.shieldAmount), crit = num(stats.critHealMultiplier) }), "success")
		else
			add("heal", stats and t("heal.amount", { amount = num(stats.heal), crit = num(stats.critHealMultiplier) }) or loading, "success")
		end
	elseif shape == "toggle" then
		add("effect", stats and t("toggle.effect", { mult = num(stats.attackMultiplier), base = num(def.attackMultiplier), scale = num(stats.investmentScale) }) or loading, "ember")
		add("cost", stats and t("toggle.cost", { pct = pct(stats.drainPerSecond), option = optionText }) or "-")
	end

	add("cooldown", stats and (stats.cooldown > 0 and seconds(stats.cooldown) or t("cooldownNone")) or seconds(def.cooldownSeconds))
	local activation = ACTIVATION[shape] and t("act." .. shape) or shape
	add("cast", def.channelSeconds and t("actTime", { act = activation, time = seconds(def.channelSeconds) }) or activation)

	-- 사거리 · 범위 / 최대 타격 수 / 관통
	if shape == "line" then
		add("range", t("line.range", { range = num(def.rangeStuds), width = num(def.hitRadiusStuds) }))
		add("maxHits", t("line.maxHits"))
		add("pierce", t("line.pierce"))
	elseif shape == "circle" then
		add("range", t("circle.range", { radius = num(def.radiusStuds) }))
		add("maxHits", t("circle.maxHits", { ticks = int(ticks) }))
		add("pierce", t("circle.pierce"))
	elseif shape == "singleChannel" then
		add("range", t("single.range", { range = num(def.rangeStuds) }))
		add("maxHits", t("single.maxHits", { ticks = int(ticks) }))
		add("pierce", t("single.pierce"))
	elseif shape == "dash" then
		add("range", t("dash.range", { range = num(def.rangeStuds) }))
	end

	-- 치명 · 최종 데미지 버킷
	if def.coefficient then
		add("crit", t("crit.applies", { crit = critText }))
		add("finalDmg", t("final.coef"))
	elseif shape == "heal" then
		add("crit", t("crit.heal", { rate = info and pct(math.min(1, info.critRate)) or "-", mult = stats and num(stats.critHealMultiplier) or "-" }))
		add("finalDmg", t("final.heal"))
	elseif shape == "selfBuff" or shape == "dash" then
		add("crit", t("crit.basic", { crit = critText }))
		add("finalDmg", t("final.arrow"))
	elseif shape == "toggle" then
		add("crit", t("crit.basic", { crit = critText }))
		add("finalDmg", t("final.basic"))
	elseif shape == "summon" then
		add("crit", t("crit.summon", { bonus = num(CombatConfig.guaranteedCritOverflowBonus) }))
	end

	-- 치유사 모드 · 버프
	if classId == "healer" and shape == "heal" then
		add("healMode", t("healMode.heal", { ratio = pct(def.shield.healRatio), time = seconds(def.shield.durationSeconds), layers = int(ShieldConfig.maxLayers or 4) }))
		add("partyBuff", info and t("partyBuff", { pct = pct(info.healerBuff), mult = num(def.partyBuffDurationMultiplier) }) or "-")
	elseif classId == "healer" and shape == "toggle" then
		add("healMode", stats and (stats.active and t("healMode.on") or t("healMode.off")) or "-")
	elseif def.coefficient then
		add("healMode", info and t("healMode.buff", { pct = pct(info.healerBuff) }) or "-")
	end

	-- 설명 없이는 알기 어려운 규칙
	if shape == "line" then
		add("rule", t("rule.line"))
	elseif shape == "circle" then
		add("rule", t("rule.circle"))
	elseif shape == "singleChannel" then
		add("rule", t("rule.single", { n = int(def.guaranteedCritHits or 1) }))
	elseif shape == "selfBuff" then
		add("rule", t("rule.selfBuff", { coef = num(def.attackSpeedCritCoefficient), cap = num(def.attackSpeedCap), max = int(def.stuckArrowMaxPerMonster) }))
	elseif shape == "dash" then
		add("rule", t("rule.dash"))
	elseif shape == "summon" then
		add("rule", t("rule.summon"))
	elseif shape == "toggle" then
		add("rule", t("rule.toggle"))
	end

	return { title = def.name, keyText = slot, lines = lines }
end

return SkillTooltipText
