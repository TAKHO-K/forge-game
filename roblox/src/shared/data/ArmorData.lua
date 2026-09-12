-- 갑옷 드랍 데이터(12-1, 17-1부터 7등급 전부 실제 드랍). 장갑·신발도 16-6부터 드랍된다 -
-- 랜덤/특수 옵션만 아직 범위 밖이다.
--
-- 등급 배율 출처: PRD-forge-game.md 7.0의 `ARMOR_DEFENSE_GRADE_MULTIPLIER`
-- (1.184/2.397/3.903/5.866/8.347/11.25/15.0, 일반~태초). `git log`/grep으로 확인한 결과
-- 이 표는 `data/items.js`에 실제 구현된 적이 없다(그 파일은 여전히 범용 ITEM_GRADES.
-- multiplier 1.0/1.4/2.0/...를 쓴다) - PRD 자체가 "방어구 전용 표를 새로 만든다"는
-- 설계 문구 그대로이고 웹 코드가 아직 안 따라간 상태이므로, "PRD가 나중"이 아니라
-- "PRD만 있고 웹은 구현한 적이 없다" - 비교할 웹 값 자체가 없으니 PRD를 그대로 쓴다.
--
-- 드랍률(dropChance)은 PRD 7.1 값을 그대로 쓴다 - 몬스터 전체 공통, tier와 무관하다.
-- 등급별 확률은 17-1부터 tier마다 다르다 - MonsterData.dropGradeTableByTier(16-6이 계산만
-- 해 뒀던 표)를 Loot.rollArmorDrop이 tierIndex로 직접 읽는다. 이 파일엔 더 이상 등급 확률
-- 표를 안 둔다(중복 출처 방지) - grades 아래의 defenseGradeMultiplier만 여기 남는다.
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

	-- 17-1부터 7등급 전부 실제로 드랍된다(16-6이 미뤄 뒀던 "드랍표 연결"). 오름차순 순서 -
	-- Loot.rollArmorDrop이 이 순서로 tier별 확률표를 굴리고(MonsterData.dropGradeTableByTier의
	-- 각 줄은 맵이라 순회 순서가 없다 - 이 배열이 결정적 순서를 정한다),
	-- Loot.rollBossArmorDrop의 "마지막 항목", 인벤토리 일괄판매 컷오프도 전부 이 배열을 본다.
	gradeOrder = { "normal", "rare", "epic", "legendary", "relic", "ancient", "primordial" },

	-- defenseGradeMultiplier - 몬스터 tier 공정성 계산(MonsterData.lua, 16-6)의 입력이자
	-- Loot.getArmorDefense의 갑옷 배율이다.
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

	-- 판매가 회수율(13-1). Loot.getSellPrice가 쓰는 유일한 상수 -
	--   판매가 = (1 / (dropChance × 그 등급 확률)) × 그 스테이지 처치당 골드 × sellRecoveryRate
	-- 이 관계식 자체가 "등급·드랍 스테이지가 바뀌어도 판매가가 자동으로 따라온다"는 지시를
	-- 만족시킨다 - 숫자를 등급표에 박지 않고 이 배율 하나만 조정하면 전체 판매가가 같이 움직인다.
	--
	-- 0.3으로 정한 근거(13-1 - 등급 2종뿐이던 시절 산출값): 인벤토리 20칸을 가득 채워 전부
	-- 파는 "한 사이클"의 총 판매 수익은 등급별로 (그 사이클의 총 처치 수)×(처치당 골드)×
	-- sellRecoveryRate로 수렴한다(기대 처치 수와 드랍 개수가 서로 상쇄되기 때문 - 어느 등급이든
	-- 같은 사이클 안에서 등가). 희귀·9단계(12-1에서 실제 검증한 방어보너스 37.96짜리 아이템)
	-- 하나를 팔면 228골드로 EnhanceConfig.goldCost의 +7강→+8강(200골드)을 넉넉히 감당한다.
	-- 검증 수치는 13-1 세션 PRD-forge-game-roblox.md 20.21 참고. 17-1부터 7등급 전부
	-- 드랍되면서 "한 사이클 등가" 전제(등급 2종)가 더는 정확히 성립하지 않는다 - 재검증은
	-- 다음 밸런스 세션 몫으로 남긴다.
	sellRecoveryRate = 0.3,
}
