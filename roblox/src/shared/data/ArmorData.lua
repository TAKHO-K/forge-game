-- 갑옷 드랍 데이터(12-1). 이번 범위는 갑옷 1종·등급 2종(일반/희귀)뿐이다 - 장갑·신발·
-- 무기 드랍, 랜덤/특수 옵션, 전 등급(영웅~태초)은 다음이다(지시 [1] "하지 말 것").
--
-- 등급 배율 출처: PRD-forge-game.md 7.0의 `ARMOR_DEFENSE_GRADE_MULTIPLIER`
-- (1.184/2.397/3.903/5.866/8.347/11.25/15.0, 일반~태초). `git log`/grep으로 확인한 결과
-- 이 표는 `data/items.js`에 실제 구현된 적이 없다(그 파일은 여전히 범용 ITEM_GRADES.
-- multiplier 1.0/1.4/2.0/...를 쓴다) - PRD 자체가 "방어구 전용 표를 새로 만든다"는
-- 설계 문구 그대로이고 웹 코드가 아직 안 따라간 상태이므로, "PRD가 나중"이 아니라
-- "PRD만 있고 웹은 구현한 적이 없다" - 비교할 웹 값 자체가 없으니 PRD를 그대로 쓴다.
--
-- 드랍률(dropChance)·등급별 확률(gradeRollTable)은 PRD 7.1/7.2 값을 그대로 쓴다 - PRD
-- 표(몬스터 등급1: 일반90%/희귀10%)와 웹 data/monsters.js(dropChance=0.25 전 몬스터 공통,
-- data/items.js DROP_GRADE_TABLE[0]={normal:0.90,rare:0.10})가 이미 서로 일치해서
-- 어느 쪽이 나중인지 따질 필요가 없었다(classes.js 때와 달리 이번엔 누락이 아니었다).
-- 로블록스 몬스터가 아직 tier1 하나뿐이라 그 표의 첫 줄(등급1 몬스터)만 옮긴다.
--
-- baseDefense=5는 CombatConfig.playerDefense와 같은 값이다 - 우연이 아니라, "일반 등급
-- 갑옷 하나가 지금 기본 방어력만큼을 더해준다"는 체감 기준으로 의도적으로 맞췄다(웹
-- ITEM_PART_BASE_STAT.armor.base=2는 웹 자체 파워 스케일 기준이라 그대로 옮기면 안
-- 된다 - ClassData critRate 주석과 같은 "출처가 다른 두 값" 원칙).
--
-- 스테이지 스케일링(12-1 [2] 판단): 갑옷 방어력은 등급뿐 아니라 "주운 스테이지"에도
-- 비례한다(InfiniteStage의 growthRate 재사용, PRD-forge-game-roblox.md 20.11-4
-- "defenseFlat도 k로 키워야 방어력/몬스터공격력 비율이 스테이지 무관 상수로 수렴한다"와
-- 같은 이유) - 등급에만 의존하면 1단계에서 주운 희귀템이 영원히 가치를 유지해 "더 높은
-- 단계에서 파밍할 이유"가 사라진다. 실제 계산·검증은 Loot.lua와 이번 세션 커밋 메시지 참고.

local CombatConfig = require(script.Parent.CombatConfig)

return {
	baseDefense = CombatConfig.playerDefense,

	gradeOrder = { "normal", "rare" },

	grades = {
		normal = {
			id = "normal",
			displayName = "일반",
			defenseGradeMultiplier = 1.184,
		},
		rare = {
			id = "rare",
			displayName = "희귀",
			defenseGradeMultiplier = 2.397,
		},
	},

	-- 슬롯1 드랍 확률(PRD 7.1 dropChance 임시값). 슬롯2(30%p 보너스)는 이번 범위 밖 -
	-- "몬스터당 최대 2개" 다중 드랍은 다음이다.
	dropChance = 0.25,

	-- 몬스터 등급1 줄(PRD 7.2 DROP_GRADE_TABLE[0])만 옮긴다 - 로블록스 몬스터가 tier1
	-- 하나뿐이라 등급별 분기 자체가 아직 필요 없다.
	gradeRollTable = {
		{ grade = "normal", chance = 0.90 },
		{ grade = "rare", chance = 0.10 },
	},
}
