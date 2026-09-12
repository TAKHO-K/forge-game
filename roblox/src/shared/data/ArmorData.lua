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
-- 레벨 스케일링(13-2로 12-1의 판단을 되돌림): 갑옷 방어력은 등급뿐 아니라 "획득 시점
-- 캐릭터 레벨"(itemLevel)에도 비례한다(CharacterLevel.getItemLevelMultiplier,
-- PRD-forge-game-roblox.md 20.11-4 "defenseFlat도 k로 키워야 방어력/몬스터공격력 비율이
-- 스테이지 무관 상수로 수렴한다"). 12-1 시점엔 로블록스에 캐릭터 레벨 축 자체가 없어
-- "주운 스테이지"(dropStage)를 대체재로 썼었다 - 20.22가 이 대체가 "막히면 아래에서
-- 파밍한다"는 설계와 어긋남을 확인했고(낮은 스테이지에서 주운 장비가 영구히 무력해짐),
-- 13-2가 캐릭터 레벨 축을 만들면서 원래 설계(itemLevel 기준)로 되돌렸다. 등급에만
-- 의존하면 레벨1에서 주운 희귀템이 영원히 가치를 유지해 "레벨을 올릴 이유"가 사라진다는
-- 점은 그대로다 - 축의 이름만 dropStage에서 itemLevel로 바뀌었다. 실제 계산·검증은
-- Loot.lua와 PRD 20.23 참고.

local CombatConfig = require(script.Parent.CombatConfig)

return {
	baseDefense = CombatConfig.playerDefense,

	-- 실제로 드랍되는 등급은 여전히 이 둘뿐이다(16-6 지시 - "드랍표 연결은 다음 작업").
	-- gradeRollTable(아래)이 굴리는 등급, Loot.rollBossArmorDrop의 "마지막 항목", 인벤토리
	-- 일괄판매 컷오프가 전부 이 배열만 본다 - 여기 없는 등급은 실제로 드랍될 수 없다.
	gradeOrder = { "normal", "rare" },

	-- grades 테이블 자체는 7등급 전부 채워 둔다(아래) - defenseGradeMultiplier가 몬스터
	-- tier 공정성 계산(MonsterData.lua, 16-6)의 입력으로 쓰이기 때문에, 실제로 안 드랍되는
	-- 등급도 배율값은 알아야 한다. gradeOrder에 없으므로 드랍·판매·장비창 어디에도 등장하지
	-- 않는다 - "값 정의"와 "실제로 나온다"를 이 두 테이블로 분리했다.
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
		-- 아래 5등급은 PRD-forge-game.md 7.0 각주의 ARMOR_DEFENSE_GRADE_MULTIPLIER 표를
		-- 그대로 옮긴 값이다(1.184/2.397/3.903/5.866/8.347/11.25/15.0, 일반~태초) - 16-5
		-- 조사에서 이미 확인했고 이번에 값만 채운다. 새로 만든 숫자가 아니다.
		epic = {
			id = "epic",
			displayName = "영웅",
			defenseGradeMultiplier = 3.903,
		},
		legendary = {
			id = "legendary",
			displayName = "전설",
			defenseGradeMultiplier = 5.866,
		},
		relic = {
			id = "relic",
			displayName = "유물",
			defenseGradeMultiplier = 8.347,
		},
		ancient = {
			id = "ancient",
			displayName = "고대",
			defenseGradeMultiplier = 11.25,
		},
		primordial = {
			id = "primordial",
			displayName = "태초",
			defenseGradeMultiplier = 15.0,
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

	-- 판매가 회수율(13-1). Loot.getSellPrice가 쓰는 유일한 상수 -
	--   판매가 = (1 / (dropChance × 그 등급 확률)) × 그 스테이지 처치당 골드 × sellRecoveryRate
	-- 이 관계식 자체가 "등급·드랍 스테이지가 바뀌어도 판매가가 자동으로 따라온다"는 지시를
	-- 만족시킨다 - 숫자를 등급표에 박지 않고 이 배율 하나만 조정하면 전체 판매가가 같이 움직인다.
	--
	-- 0.3으로 정한 근거: 등급이 2종(normal/rare)뿐이라, 인벤토리 20칸을 가득 채워 전부 파는
	-- "한 사이클"의 총 판매 수익은 등급별로 (그 사이클의 총 처치 수)×(처치당 골드)×
	-- sellRecoveryRate로 수렴한다(기대 처치 수와 드랍 개수가 서로 상쇄되기 때문 - 어느 등급이든
	-- 같은 사이클 안에서 등가). 등급이 2종이므로 전부 팔면 직접 처치 골드 대비 대략
	-- 2×sellRecoveryRate만큼 수입이 늘어난다 - 0.3이면 +60%로, 직접 사냥 골드가 여전히 더
	-- 크게 남아 "사냥보다 판매가 주 수입"(비율 100% 이상)이 되는 지점과는 충분히 떨어져 있다.
	-- 반대로 0.3은 낱개로 봐도 의미 있다 - 희귀·9단계(12-1에서 실제 검증한 방어보너스
	-- 37.96짜리 아이템) 하나를 팔면 228골드로 EnhanceConfig.goldCost의 +7강→+8강(200골드)을
	-- 넉넉히 감당한다. 일반·1단계(가장 흔한 잡템) 하나는 8골드로 +0강→+1강(10골드)에 근접한다 -
	-- "팔 이유가 없어 버리게 된다"는 반대쪽 실패 조건도 피한다. 검증 수치는 이번 세션(13-1)
	-- PRD-forge-game-roblox.md 20.21 참고.
	sellRecoveryRate = 0.3,
}
