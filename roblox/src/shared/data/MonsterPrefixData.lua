-- 몬스터 접두사 변종(22-2 [1]). 기본형(MonsterData.tierN.displayName - 슬라임·고블린…)에
-- 접두사가 붙어 "단단한 슬라임"처럼 이름이 바뀌고 HP·이동속도·크기가 달라진다.
--
-- 조사 결과(22-2 [0]) - 웹에는 접두사 시스템이 없다. 웹 data/monsters.js는 tier마다
-- "물몸형/탱커형/재료형"을 서로 다른 몬스터 id(말랑꼬물이/딱딱꼬물이 등)로 갖고 있을 뿐,
-- 이름 앞에 붙어 스탯을 바꾸는 수식어 구조는 아니다(19-4가 반짝이만 이식한 게 맞다 -
-- 이식할 접두사가 애초에 없었다, RareMonsterConfig.lua 주석과 같은 결론). 그래서 이
-- 표는 웹 값을 옮긴 게 아니라 이번에 새로 정한 것이다.
--
-- 공평성(16-6 원칙 그대로): 오래 걸리면 더 주고, 빨리 죽으면 덜 준다.
--   보상 배율 = HP 배율 (골드·경험치·드랍 확률 전부 같은 배율)
--   시간당보상 = 보상배율 / HP배율 = 1  (접두사 무관 - 아래 fairnessCheck가 실제로 계산)
-- 이동속도는 처치 시간에 영향이 없다(플레이어가 때리는 동안 몬스터가 빠르든 느리든
-- HP를 깎는 속도는 같다) - 그래서 보상에는 안 들어간다. 속도는 "느낌"(연약한 놈은
-- 재빠르고 단단한 놈은 굼뜨다)과 어그로 후 도달 시간만 바꾼다.
--
-- 넘을 수 있는 기존 관계식 확인(PRD 20.42 규칙):
--   · 몬스터 속도 < 플레이어 속도(16): 10 × 1.3 = 13 < 16 - 가장 빠른 변종도 뿌리칠 수 있다.
--   · 드랍 확률 상한 1.0: 0.25 × 3 = 0.75 ≤ 1 - 거대한 변종도 확률이 넘치지 않는다.
--   · 어그로/리쉬 거리(25.6/38.4)는 속도와 무관 - 안 건드린다.
--   · 공격력은 안 바꾼다(지시 - HP·이동속도만). 생존 타수 앵커(7타)에 영향 없음.
--
-- 구별(지시 - "색·크기 중"): **크기**로 한다. 색은 이미 tier 팔레트(MonsterData.bodyColor)가
-- 쓰고 있어 접두사까지 색으로 만들면 "무슨 tier인지"와 "무슨 변종인지"가 한 축에서
-- 충돌하고, 최종 모델(텍스처)로 바꾸면 색 틴트가 안 먹을 수 있다 - 크기(스케일)는 어떤
-- 모델에도 그대로 적용된다. 반짝이가 쓰던 크기 배율(19-4)은 22-2 [2]에서 이펙트 레이어로
-- 옮겨 크기 축을 비웠다.
--
-- 확률: 합 10% - 구역 9마리 중 평균 0.9마리. 기본형이 압도적 다수(90%)여야 변종이
-- 특별하다(지시). 거대한 변종은 가장 드물게(2%) - HP 3배라 "저건 오래 걸린다"가 사건이
-- 되도록.
local prefixes = {
	{
		id = "frail",
		displayName = "연약한",
		hpMultiplier = 0.5,
		moveSpeedMultiplier = 1.3,
		sizeMultiplier = 0.8,
		chance = 0.04,
	},
	{
		id = "sturdy",
		displayName = "단단한",
		hpMultiplier = 2.0,
		moveSpeedMultiplier = 0.8,
		sizeMultiplier = 1.2,
		chance = 0.04,
	},
	{
		id = "giant",
		displayName = "거대한",
		hpMultiplier = 3.0,
		moveSpeedMultiplier = 0.7,
		sizeMultiplier = 1.45,
		chance = 0.02,
	},
}

local MonsterPrefixData = {
	prefixes = prefixes,
	byId = {},
	-- 공평성 검증표(HuntingGround.server.lua가 서버 시작 시 로그로 찍는다 - MonsterData.
	-- fairnessCheck와 같은 관례). 보상 배율은 HP 배율과 같으므로 시간당보상은 항상 1이어야
	-- 한다 - 코드가 계산한 값이 실행 시점에 실제로 1인지 확인한다.
	fairnessCheck = {},
}

local totalChance = 0
for _, prefix in ipairs(prefixes) do
	MonsterPrefixData.byId[prefix.id] = prefix
	totalChance += prefix.chance
	local rewardMultiplier = prefix.hpMultiplier
	table.insert(MonsterPrefixData.fairnessCheck, {
		id = prefix.id,
		displayName = prefix.displayName,
		hpMultiplier = prefix.hpMultiplier,
		rewardMultiplier = rewardMultiplier,
		rewardPerTime = rewardMultiplier / prefix.hpMultiplier,
	})
end
MonsterPrefixData.totalChance = totalChance -- 0.10, 기본형 확률 = 1 - 이 값.

-- 보상 배율 - 골드·경험치·드랍 확률이 전부 이 하나를 곱한다(단일 출처). HP 배율과 같은
-- 값이라는 것이 공평성의 정의 자체다.
function MonsterPrefixData.getRewardMultiplier(prefix)
	return prefix and prefix.hpMultiplier or 1
end

return MonsterPrefixData
