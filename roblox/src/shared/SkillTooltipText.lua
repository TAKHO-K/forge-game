-- 스킬 툴팁 글(P3b D) - 순수 함수. 규칙 · 사거리 · 틱 수 같은 고정 값은 SkillData(스킬 단일 출처)에서, 내 능력치에 따른 수치(공격력 · 1타 피해 · 쿨다운 · 치명 · 버프 값)는
-- 서버 SkillStats.info(스킬 판정이 쓰는 함수 그대로)가 준 info에서만 가져온다 - 이 파일은 곱셈 · 나눗셈으로 피해를 다시 계산하지 않는다(표시 형식만 만든다).
-- 반환 = { title, keyText, lines = { { label, text, colorName? } } }. 줄 순서: 설명 · 계수 · 예상 피해 · 쿨타임 · 발동 · 사거리/범위 · 최대 타격 · 관통 · 치명 · 최종 데미지 버킷 · 치유사(모드 · 버프) · 규칙.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ShieldConfig = require(ReplicatedStorage.Shared.data.ShieldConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local SkillTooltipText = {}

local function pct(value)
	local text = ("%.1f"):format(value * 100)
	return (text:gsub("%.0$", "")) .. "%"
end

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
	return (("%.1f"):format(value):gsub("%.0$", "")) .. "초"
end

local ACTIVATION = {
	line = "즉발 · 돌진",
	circle = "채널링",
	selfBuff = "즉발 · 자기 버프",
	dash = "즉발 · 뒤로 도약 + 다음 평타 강화",
	summon = "즉발 · 소환",
	singleChannel = "채널링 · 단일 대상",
	heal = "즉발 · 치유",
	toggle = "토글(켜기 / 끄기)",
}

-- classId · slot("Q" | "E") · info = SkillStats.info 응답(없으면 수치 줄은 "불러오는 중").
function SkillTooltipText.build(classId, slot, info)
	local def = SkillData[classId] and SkillData[classId][slot]
	if not def then
		return nil
	end
	local stats = info and info.slots and info.slots[slot]
	local lines = {}
	local function add(label, text, colorName)
		table.insert(lines, { label = label, text = text, colorName = colorName })
	end
	local optionText = stats and stats.optionBonus and math.abs(stats.optionBonus) > 1e-9 and (" (옵션 %+.0f%% 포함)"):format(stats.optionBonus * 100) or ""
	local critText = info and ("치명 확률 %s · 치명 피해 ×%s"):format(pct(math.min(1, info.critRate)), num(info.critDmg)) or "-"
	local shape = def.shape
	local ticks = def.tickCount or 1

	-- 설명
	if shape == "line" then
		add("설명", ("바라보는 방향으로 %s 스터드 돌진하며 경로 위의 적을 모두 벤다."):format(num(def.rangeStuds)))
	elseif shape == "circle" then
		add("설명", ("%s 동안 제자리에서 돌며 반경 안의 적을 %d번 벤다. 이동 속도 ×%s · 받는 피해 ×%s."):format(seconds(def.channelSeconds), ticks, num(def.channelMoveSpeedMultiplier), num(def.incomingDamageMultiplier)))
	elseif shape == "selfBuff" then
		add("설명", ("%s 동안 공격 속도가 빨라진다. 그동안 명중한 평타마다 화살이 꽂혀 %s 뒤 터진다."):format(seconds(def.durationSeconds), seconds(def.stuckArrowDelaySeconds)))
	elseif shape == "dash" then
		add("설명", ("뒤로 %s 스터드 물러나고, 다음 평타 %d발이 강해진다."):format(num(def.rangeStuds), def.chargesGranted))
	elseif shape == "summon" then
		add("설명", "제자리에 분신을 남겨 적의 시선을 끈다. 분신이 있는 동안 평타 · 스킬이 확정 치명이다.")
	elseif shape == "singleChannel" then
		add("설명", ("%s 동안 한 대상을 %d번 연타한다."):format(seconds(def.channelSeconds), ticks))
	elseif shape == "heal" then
		add("설명", ("자신의 체력을 최대 체력의 %s 회복한다. 파티가 있으면 파티원 전원도 각자 최대 체력의 %s 회복한다."):format(pct(def.healPercentOfMaxHp), pct(def.healPercentOfMaxHp)))
	elseif shape == "toggle" then
		add("설명", "딜링모드를 켜고 끈다. 켜진 동안 평타가 강해지고 체력이 조금씩 줄어든다(끄면 치유모드).")
	end

	-- 계수 · 예상 피해
	if def.coefficient then
		local perHit = stats and stats.hitCoefficient
		if ticks > 1 then
			add("계수", ("공격력의 %s(1타 %s × %d타)%s"):format(pct(stats and stats.castCoefficient or def.coefficient), pct(perHit or def.coefficient / ticks), ticks, optionText))
		else
			add("계수", ("공격력의 %s%s"):format(pct(perHit or def.coefficient), optionText))
		end
		if stats and stats.hitDamage then
			local total = ticks > 1 and (" · 대상 1명에 %d타 %s"):format(ticks, num(stats.castDamage)) or ""
			add("예상 피해", ("1타 %s · 치명 %s%s"):format(num(stats.hitDamage), num(stats.critHitDamage), total), "ember")
		else
			add("예상 피해", "불러오는 중…", "textTertiary")
		end
	elseif shape == "selfBuff" then
		add("효과", stats and ("공격 속도 ×%s(상한 ×%s)%s"):format(num(stats.speedMultiplier), num(def.attackSpeedCap), optionText) or "불러오는 중…", "ember")
		add("예상 피해", stats and ("꽂힌 화살 1개 %s(공격력의 %s)"):format(num(stats.arrowDamage), pct(def.stuckArrowDamageCoefficient)) or "불러오는 중…", "ember")
	elseif shape == "dash" then
		add("효과", ("다음 평타 %d발: 치명 확률 +%s · 추가 피해 공격력의 %s · 사거리 ×%s"):format(def.chargesGranted, pct(def.critRateBonus), pct(def.damageCoefficient), num(def.rangeMultiplier)))
		add("예상 피해", stats and stats.bonusDamage and ("평타 1발에 +%s"):format(num(stats.bonusDamage)) or "불러오는 중…", "ember")
	elseif shape == "summon" then
		add("효과", stats and ("분신 · 확정 치명 %s%s"):format(seconds(stats.duration), optionText) or "불러오는 중…", "ember")
	elseif shape == "heal" then
		add("회복량", stats and ("%s · 치명 ×%s"):format(num(stats.heal), num(stats.critHealMultiplier)) or "불러오는 중…", "success")
	elseif shape == "toggle" then
		add("효과", stats and ("평타 ×%s(기본 ×%s × 투자 배율 ×%s)"):format(num(stats.attackMultiplier), num(def.attackMultiplier), num(stats.investmentScale)) or "불러오는 중…", "ember")
		add("소모", stats and ("초당 최대 체력의 %s%s"):format(pct(stats.drainPerSecond), optionText) or "-")
	end

	add("쿨타임", stats and (stats.cooldown > 0 and seconds(stats.cooldown) or "없음(바로 다시 쓸 수 있다)") or seconds(def.cooldownSeconds))
	add("발동", (ACTIVATION[shape] or shape) .. (def.channelSeconds and (" %s"):format(seconds(def.channelSeconds)) or ""))

	-- 사거리 · 범위 / 최대 타격 수 / 관통
	if shape == "line" then
		add("사거리 · 범위", ("돌진 %s · 경로 좌우 %s"):format(num(def.rangeStuds), num(def.hitRadiusStuds)))
		add("최대 타격", "경로 위의 적 전원 · 대상마다 1타(마릿수 제한 없음)")
		add("관통", "관통한다(경로 위 전원)")
	elseif shape == "circle" then
		add("사거리 · 범위", ("나를 중심으로 반경 %s"):format(num(def.radiusStuds)))
		add("최대 타격", ("틱마다 반경 안의 적 전원 · 대상마다 %d타"):format(ticks))
		add("관통", "범위 공격(해당 없음)")
	elseif shape == "singleChannel" then
		add("사거리 · 범위", ("사거리 %s(가장 가까운 적 1명을 고정)"):format(num(def.rangeStuds)))
		add("최대 타격", ("대상 1명 · %d타"):format(ticks))
		add("관통", "관통하지 않는다(한 대상만)")
	elseif shape == "dash" then
		add("사거리 · 범위", ("뒤로 %s 스터드"):format(num(def.rangeStuds)))
	end

	-- 치명 · 최종 데미지 버킷
	if def.coefficient then
		add("치명", "적용 - " .. critText)
		add("최종 데미지", "적용(강화 · 옵션의 최종 데미지가 공격력에 들어 있다)")
	elseif shape == "heal" then
		add("치명", ("회복에도 치명 굴림(%s) - 치명이면 회복 ×%s"):format(info and pct(math.min(1, info.critRate)) or "-", stats and num(stats.critHealMultiplier) or "-"))
		add("최종 데미지", "치유량에 적용")
	elseif shape == "selfBuff" or shape == "dash" then
		add("치명", "평타 치명 굴림을 그대로 쓴다 - " .. critText)
		add("최종 데미지", "적용(평타 · 화살 피해의 공격력에 들어 있다)")
	elseif shape == "toggle" then
		add("치명", "평타 치명 굴림을 그대로 쓴다 - " .. critText)
		add("최종 데미지", "적용(평타 공격력에 들어 있다)")
	elseif shape == "summon" then
		add("치명", ("치명 확률이 100%%를 넘으면 확정 치명 대신 치명 피해 +%s"):format(num(CombatConfig.guaranteedCritOverflowBonus)))
	end

	-- 치유사 모드 · 버프
	if classId == "healer" and shape == "heal" then
		add("치유모드", ("치유모드면 회복 · 딜링모드이고 파티가 있으면 회복 대신 쉴드(회복량의 %s · %s · 최대 %d겹)"):format(pct(def.shield.healRatio), seconds(def.shield.durationSeconds), ShieldConfig.maxLayers or 4))
		add("파티 버프", info and ("파티가 있으면 전원 최종 피해 +%s(지속 = 쿨타임 × %s)"):format(pct(info.healerBuff), num(def.partyBuffDurationMultiplier)) or "-")
	elseif classId == "healer" and shape == "toggle" then
		add("치유모드", stats and (stats.active and "지금: 딜링모드(켜짐)" or "지금: 치유모드(꺼짐 - 평타 ×1)") or "-")
	elseif def.coefficient then
		add("치유모드", info and ("치유사 파티 버프를 받으면 최종 피해 ×%s(모드와 무관)"):format(num(1 + info.healerBuff)) or "-")
	end

	-- 설명 없이는 알기 어려운 규칙
	if shape == "line" then
		add("규칙", "판정은 서버가 캐릭터가 바라보는 방향으로 한다 · 벽에 막히면 그 자리까지")
	elseif shape == "circle" then
		add("규칙", "채널 중에는 평타를 못 쓴다 · 맞아도 끊기지 않는다")
	elseif shape == "singleChannel" then
		add("규칙", ("대상이 죽거나 사거리를 벗어나면 남은 타격은 사라진다 · 사거리 안에 적이 없으면 쿨타임 없이 취소 · 분신 중이면 첫 %d타만 확정 치명"):format(def.guaranteedCritHits or 1))
	elseif shape == "selfBuff" then
		add("규칙", ("공격 속도 = (1 + 직업 치명 확률 × %s) × (1 + 옵션), 상한 ×%s · 화살은 몬스터마다 최대 %d개"):format(num(def.attackSpeedCritCoefficient), num(def.attackSpeedCap), def.stuckArrowMaxPerMonster))
	elseif shape == "dash" then
		add("규칙", "강해진 평타는 맞든 빗나가든 쏠 때 1발씩 줄어든다 · 늘어난 사거리는 몬스터 인식 범위를 넘지 않는다")
	elseif shape == "summon" then
		add("규칙", "분신은 스스로 공격하지 않는다")
	elseif shape == "toggle" then
		add("규칙", "체력 소모는 쉴드로 막을 수 없다 · 켜고 끄기에 쿨타임이 없다")
	end

	return { title = def.name, keyText = slot, lines = lines }
end

return SkillTooltipText
