-- 도움말(백과사전) 데이터 - 창 = client/panels/Help.lua(QUEUE-ALL2 P2 · ref 18). 문구는 TextData(번역 가능 문자열 규칙 - 키 = 한 문장 전체)에만 둔다.
-- 번역 규칙(ref 18 ③): 한 줄 40자 이하 · 한 문장 한 행동 · 관용구 금지 · 숫자 · 키는 문장 밖 칩(chip)으로 · 색만 쓰지 말고 색 + 모양.
--   categories  왼쪽 분류 목록(그림 = ArtAssetIds 아이콘 경로). gimmicks = true인 분류는 항목이 gimmickCards에서 나온다(보스 순서 = gimmickOrder).
--   entries     오른쪽 한 항목 = 그림 하나(pic) + 짧은 줄 5개 이하(lines).
--               pic = { icon = 아이콘 경로 } 또는 { draw = BossIntroDiagram.drawPicture 종류 }.
--               lines[i] = { key = TextData 키, chip = 칩 글(PanelRegistry.hotkeySheet의 text 키면 그 줄의 keys, 아니면 TextData 키) }.
--               args = Help 창이 숫자를 끼우는 규칙 이름(창의 ARGS 표 - 값은 늘 원본 데이터에서 읽는다. 여기 숫자를 적지 않는다).
--               bodyKey · bodyArgs(C1 마무리 - 옛 긴 설명 한 덩어리)는 그대로 둔다.
--   gimmickCards 보스 전멸기 카드 = 그림 3컷(① 보이는 것 → ② 할 일 → ③ 실패하면) + 40자 이하 한 줄(lineKey).
--               panels[i] = { pic = BossIntroDiagram 컷 종류, captionKey = 컷 아래 짧은 말(8자 안팎), chip = 칩 규칙(선택) }.
--               fail = 실패 숫자를 **BossData에서 읽는** 규칙(표시 전용 - 밸런스 값은 BossData 그대로):
--                 { mechanics = "gimmickFail" }          → mechanics.gimmickFail 첫 회 ~ 그 뒤(구간 수호자 낙하)
--                 { skill = 이름, perTick = true }        → skills[이름].tickFraction × ticks(서리 포효 - 틱마다)
--                 { skill = 이름 }                        → skills[이름].failMaxHpFraction
--               chip = "rods" → 번개 조준경 필요 피뢰침 수(인원별 - BossIntroCard와 같은 식).
return {
	categories = {
		{ id = "controls", titleKey = "help.cat.controls", icon = "icons/hud/character" },
		{ id = "enhance", titleKey = "help.cat.enhance", icon = "icons/hud/forge" },
		{ id = "bossGimmick", titleKey = "help.cat.bossGimmick", icon = "icons/codex/tab_boss", gimmicks = true },
		{ id = "combat", titleKey = "help.cat.combat", icon = "icons/codex/tab_monster" },
		{ id = "pet", titleKey = "help.cat.pet", icon = "icons/hud/pet" },
		{ id = "egg", titleKey = "help.cat.egg", icon = "icons/reward/egg" },
	},

	entries = {
		{
			id = "move", category = "controls", titleKey = "help.move.title", pic = { icon = "icons/hud/character" },
			lines = {
				{ key = "help.move.walk", chip = "help.chip.wasd" },
				{ key = "help.move.jump", chip = "help.chip.space" },
				{ key = "help.move.dash", chip = "help.chip.shift" },
				{ key = "help.move.skill", chip = "hotkeys.skills" },
				{ key = "help.move.interact", chip = "hotkeys.interact" },
			},
		},
		{
			id = "windows", category = "controls", titleKey = "help.windows.title", pic = { icon = "icons/hud/more" },
			lines = {
				{ key = "help.windows.bag", chip = "hotkeys.bag" },
				{ key = "help.windows.character", chip = "hotkeys.character" },
				{ key = "help.windows.map", chip = "hotkeys.map" },
				{ key = "help.windows.recall", chip = "hotkeys.recall" },
				{ key = "help.windows.close", chip = "hotkeys.close" },
			},
		},
		{
			id = "enhance", category = "enhance", titleKey = "help.enhance.title", pic = { icon = "icons/reward/enhanceStone" }, args = "enhance",
			lines = {
				{ key = "help.enhance.where" },
				{ key = "help.enhance.safe" },
				{ key = "help.enhance.drop" },
				{ key = "help.enhance.reset" },
				{ key = "help.enhance.pity" },
			},
		},
		{ -- C1 마무리: 잠긴 몹(스틸 규칙) - bodyArgs = CombatConfig 키(× 100)
			id = "stealLock", category = "combat", titleKey = "codex.stealLock.title", bodyKey = "codex.stealLock.body", bodyArgs = { percent = "contributionRewardThreshold" },
			pic = { draw = "stealLock" }, args = "stealLock",
			lines = {
				{ key = "help.stealLock.see" },
				{ key = "help.stealLock.bounce" },
				{ key = "help.stealLock.free" },
				{ key = "help.stealLock.together" },
				{ key = "help.stealLock.reward" },
			},
		},
		{
			id = "pet", category = "pet", titleKey = "help.pet.title", pic = { icon = "icons/hud/pet" }, args = "pet",
			lines = {
				{ key = "help.pet.hatch" },
				{ key = "help.pet.follow" },
				{ key = "help.pet.pickup" },
				{ key = "help.pet.level" },
				{ key = "help.pet.cap" },
			},
		},
		{
			id = "egg", category = "egg", titleKey = "help.egg.title", pic = { icon = "icons/reward/egg" },
			lines = {
				{ key = "help.egg.get" },
				{ key = "help.egg.nest" },
				{ key = "help.egg.hatch" },
				{ key = "help.egg.time" },
			},
		},
	},

	-- 보스 순서 = BossData.placement.laps[1](구역 순서)
	gimmickOrder = { "section_guardian", "crystal_queen", "abyssal_lord", "scorpion_queen", "storm_lord", "frost_giant" },
	gimmickCards = {
		section_guardian = {
			titleKey = "gimmick.section_guardian.title", lineKey = "gimmick.section_guardian.line",
			fail = { mechanics = "gimmickFail" },
			panels = {
				{ pic = "slicesSee", captionKey = "gimmick.section_guardian.see" },
				{ pic = "slicesMove", captionKey = "gimmick.section_guardian.do" },
				{ pic = "slicesFail", captionKey = "gimmick.section_guardian.fail" },
			},
		},
		frost_giant = {
			titleKey = "gimmick.frost_giant.title", lineKey = "gimmick.frost_giant.line",
			fail = { skill = "roar", perTick = true },
			panels = {
				{ pic = "pillarSee", captionKey = "gimmick.frost_giant.see" },
				{ pic = "pillarHide", captionKey = "gimmick.frost_giant.do" },
				{ pic = "pillarFail", captionKey = "gimmick.frost_giant.fail" },
			},
		},
		abyssal_lord = {
			titleKey = "gimmick.abyssal_lord.title", lineKey = "gimmick.abyssal_lord.line",
			fail = { skill = "colors" },
			panels = {
				{ pic = "platformSee", captionKey = "gimmick.abyssal_lord.see" },
				{ pic = "platformStand", captionKey = "gimmick.abyssal_lord.do" },
				{ pic = "platformFail", captionKey = "gimmick.abyssal_lord.fail" },
			},
		},
		crystal_queen = {
			titleKey = "gimmick.crystal_queen.title", lineKey = "gimmick.crystal_queen.line",
			fail = { skill = "orgel" },
			panels = {
				{ pic = "bellsSee", captionKey = "gimmick.crystal_queen.see" },
				{ pic = "bellsHit", captionKey = "gimmick.crystal_queen.do" },
				{ pic = "bellsFail", captionKey = "gimmick.crystal_queen.fail" },
			},
		},
		scorpion_queen = {
			titleKey = "gimmick.scorpion_queen.title", lineKey = "gimmick.scorpion_queen.line",
			fail = { skill = "sandSearch" },
			panels = {
				{ pic = "moundSee", captionKey = "gimmick.scorpion_queen.see" },
				{ pic = "moundHit", captionKey = "gimmick.scorpion_queen.do" },
				{ pic = "moundFail", captionKey = "gimmick.scorpion_queen.fail" },
			},
		},
		storm_lord = {
			titleKey = "gimmick.storm_lord.title", lineKey = "gimmick.storm_lord.line",
			fail = { skill = "rods" },
			panels = {
				{ pic = "rodSee", captionKey = "gimmick.storm_lord.see" },
				{ pic = "rodLure", captionKey = "gimmick.storm_lord.do", chip = "rods" },
				{ pic = "rodFail", captionKey = "gimmick.storm_lord.fail" },
			},
		},
	},
}
