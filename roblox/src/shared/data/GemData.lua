-- 무기 보석 슬롯 데이터(23-2, PRD-forge-game-roblox.md 20.38 [2]). 밸런스 수치를 새로
-- 만들지 않는다는 지시에 따라, 여기 있는 값은 전부 구조 정의(어느 슬롯이 어느 등급인가)와
-- 기존 표(ArmorData.gradeOrder, PRD-forge-game.md 7.3-2)를 그대로 옮긴 이름뿐이다 - 숫자
-- 배율은 Gem.lua가 ItemVisualData.gradeVisuals(statMultiplier)에서 매번 계산한다(단일 출처).

return {
	-- 환생 5회 = 슬롯 5칸(1:1). slot i(1~5)가 열리는 시점 = 환생 i회.
	maxRebirthCount = 5,

	-- 23-4: "등급 고정"에서 "등급 상한"으로 바뀌었다(지시 - "높은 등급 홈에는 그 이하 등급
	-- 보석을 모두 장착할 수 있고, 낮은 등급 홈에는 더 높은 등급 보석을 장착할 수 없다").
	-- slot i가 받아들이는 최고 등급 - 그 이하 등급 보석은 전부 그 슬롯에 꽂을 수 있다
	-- (Gem.canSocket). 슬롯 번호(1~5)는 무기에서 눈에 덜 띄는 자리(1)부터 가장 두드러지는
	-- 자리(5)까지의 "시각적 존재감" 순서이지, 등급 상한 순서와 더 이상 같지 않다 - 이번
	-- 세션 지시로 **1번 홈만 예외로 태초 상한**을 받는다("1번만 환생으로 태초까지 등급
	-- 올려주고 태초보석을 받는 것까지다") - 슬롯이 열리자마자(환생1회) 바로 태초 보석
	-- 하나가 확정 지급된다(Gem.buildGrantedGem이 그 슬롯의 상한 등급으로 채운다). 2~5번은
	-- "홈 숫자가 커질수록 이펙트는 더 좋은 위치에 박히지만, 실제로 플레이하며 조건을
	-- 지켜야 하므로 태초 달성이 좀 더 어렵다"는 컨셉의 자리표시자 값이다 - 정확한 값과
	-- 해금 조건은 나중에 설계한다(지시 원문). 지금은 태초에 못 미치는 임시값만 오름차순으로
	-- 채워 뒀다 - 나중에 이 표의 값만 올리면 되고 코드(Gem.lua)는 손댈 필요가 없다.
	slotGradeCap = { "primordial", "epic", "legendary", "relic", "ancient" },

	-- 슬롯이 열리는 데 필요한 환생 횟수(현재는 slot i = 환생 i회, 기존 동작 그대로 유지 -
	-- "구조만 만들고 조건은 나중에 설계"라는 지시를 "지금 있는 값을 유지"로 해석했다. 전부
	-- 열어 버리면 20.58 [3]에서 이미 확인한 "환생마다 하나씩 열린다" 설계가 퇴행한다).
	-- 실제 해금 여부는 이 값에서 매번 다시 계산하지 않고 PlayerProfile.rebirth가 그 순간
	-- classState.weapon.slotUnlocked에 기록해 저장한다(Gem.isSlotUnlocked 참고) - 나중에
	-- 환생 횟수만으로 표현 못 하는 조건(예: 특정 보스 처치)이 추가돼도 저장 필드 구조를
	-- 다시 바꿀 필요가 없게 하기 위한 대비다.
	slotUnlockRequiredRebirth = { 1, 2, 3, 4, 5 },

	-- 고대·태초 전용 특수 옵션 이름 풀(PRD-forge-game.md 7.3-2 무기 행 4개 그대로 재사용).
	-- 원 설계는 이 넷이 각자 다른 "규칙형" 전투 로직(예: 연속격 = 3타 강타 발동 간격 변경)을
	-- 갖는데, 그 문서 자체가 "목록·방향 확정, 수치는 전부 TBD"라 그 로직은 구현하지 않는다
	-- (23-2 세션 그대로 유지). 대신 23-3부터는 넷을 서로 다른 **기존 스탯 축**에 배정한다
	-- (지시 "5칸이 같은 효과를 내면 그 보상이 성립하지 않는다") - 새 스탯을 만들지 않고,
	-- 이미 PlayerCombat/PlayerProfile에 있는 축(공격력%·공속·방어력·최대체력) 중 넷을
	-- 고른 것뿐이다. 축 배정 근거(원래 규칙형 설계의 flavor와 최대한 가깝게):
	--   연속격(3타 강타 간격 단축 → "더 자주 세게 때린다") → 공격력%
	--   속사의 흔적(연사 → "더 빨리 쏜다")                 → 공속%(신발과 같은 축, 이동속도도 같이 오른다)
	--   심판의 표식(적중 시 확정 처형 → 생존 축과 대비되는 "더 안 맞는다")→ 방어력%
	--   삼위일체(하나로 합쳐진 전체 → "몸 자체가 단단해진다")→ 최대체력%
	-- 영웅·전설·유물 등급(슬롯1~3)엔 옵션 풀이 없다 - purchases.optionRerollTickets 자체가
	-- ancient/primordial 두 종류뿐이라(20.37 [6] 저장 스키마), 옵션 변환권으로 바꿀 대상이
	-- 애초에 이 두 등급에만 있다는 뜻이다. 그 3등급 보석은 지금처럼 공격력%만 준다(축 선택
	-- 자체가 없다 - 이름 있는 옵션이 아니라서 Gem.attackPercentBonusForGrade를 그대로 쓴다).
	optionPoolByGrade = {
		ancient = { "연속격", "속사의 흔적" },
		primordial = { "심판의 표식", "삼위일체" },
	},

	-- 옵션 → 스탯 축. Gem.lua의 totalXxxPercentBonus들이 이 표로 "이 보석이 지금 어느 축을
	-- 담당하는가"를 판정한다. 슬롯이 비었거나(optionId=nil, 23-3부터 자동 지급/분해가 옵션을
	-- 굴리지 않는다 - 아래 [옵션 배정] 주석과 PlayerProfile.rerollGemOption 참고) 이름이
	-- 이 표에 없으면 어떤 축에도 기여하지 않는다.
	optionAxis = {
		["연속격"] = "attackPercent",
		["속사의 흔적"] = "speedPercent",
		["심판의 표식"] = "defensePercent",
		["삼위일체"] = "maxHpPercent",
	},

	-- 축 표시 이름(한국어 UI용, InventoryUI.client.lua 보석 탭). 23-4: "공격력%"류 축 이름이
	-- 곧 UI에 보이는 스탯명과 같아 다른 장비 스탯 문구와 헷갈린다는 지시로 짧은 고유 이름으로
	-- 바꿨다 - 효과·수치(Gem.magnitudeForGrade)는 전혀 안 바뀐다, 표시 이름만 교체.
	axisDisplayNames = {
		attackPercent = "위력",
		speedPercent = "신속",
		defensePercent = "방어",
		maxHpPercent = "건강",
	},

	-- [옵션 배정] 23-2에선 슬롯 자동 지급(rebirth)과 분해(dismantle) 둘 다 Gem.rollOption을
	-- 불러 옵션을 즉시 무작위로 채웠다 - 그런데 고대·태초 등급 방어구(보스 첫 처치 확정
	-- 드랍 등급표에 태초가 포함된다, Loot.rollBossFirstClearDrop)를 분해하면 매번 새
	-- 무작위 옵션이 나와, 옵션 변환권을 한 장도 안 사고 "분해→장착→마음에 안 들면 버리고
	-- 다시 분해"를 반복해 옵션 변환권 경제 자체를 무력화할 수 있었다(23-3 지시 "등급은
	-- 환생 최대진행시 태초보석 하나 남고 옵션변환권으로 돌릴 수만 있게"). 23-3부터 자동
	-- 지급·분해 둘 다 optionId=nil(옵션 미배정)로만 만든다 - 오직 PlayerProfile.
	-- rerollGemOption(변환권 1장 소모)만 옵션을 굴린다. 미배정 보석은 해당 축 보너스가
	-- 0이다(Gem.lua sumBonusForAxis) - 슬롯을 열었어도 변환권을 써야 실제 효과가 켜진다.

	-- 방어력 축 보정 계수(23-3, "각 축의 1단위가 DPS나 생존에 얼마를 기여하는지 환산" 지시).
	-- 방어력은 피해감소식 D/(D+αA)가 수확체감이라, 공격력·공속·최대체력과 같은 "+r%"를 그대로
	-- 주면 생존 기여도가 r%보다 작다. 앵커점(레벨100·itemLevel100·스테이지100, CombatConfig.
	-- damageReductionAlpha 주석과 같은 기준점)에서 생존 타수가 정확히 7(CombatConfig.
	-- damageReductionAlpha 자체가 이 값에 맞춰 역산됐다)이라는 사실로부터 감소율
	-- ρ=1-maxHp/(7×몬스터공격력)을 구할 수 있다(직접 실행 없이 CombatConfig.playerMaxHp=10,
	-- maxHpBonusBase=300, CharacterLevelConfig의 레벨100 itemLevel계수, MonsterData.tier1.attack=8,
	-- InfiniteStageConfig.growthRate=1.155로 계산, 보고서 "기대 가치 환산표" 참고) - ρ≈0.5885.
	-- 방어력 보너스는 생존 타수에 ×(1+r×ρ)로만 반영되므로, 다른 축과 같은 만큼(+r) 생존을
	-- 올리려면 실제로는 r/ρ만큼 방어력을 올려야 한다 - Gem.lua가 defensePercent 축에만
	-- 이 역수를 곱한다. 새 상수가 아니라 기존 CombatConfig/MonsterData/InfiniteStageConfig
	-- 값으로 앵커 식을 풀어 나온 값이다.
	survivalReductionAtAnchor = 0.5885,

	-- 옵션 변환권 가격 배수(20.37 [5] "가격 = 그 순간 몬스터 1마리당 골드 × N, N≈30~50 -
	-- 정확한 N은 구현 후 실측"). 40은 그 범위의 중간값이다 - PRD가 이미 준 범위 안에서 고른
	-- 확정값이라 새 밸런스 상수를 만든 게 아니다(보고서 "임의 결정" 목록 참고). 서버
	-- (GemServer.server.lua)와 클라이언트(EnhanceUI.client.lua 표시용) 둘 다 이 값 하나만
	-- 본다 - 가격 계산 자체는 여전히 서버가 매번 다시 한다(클라이언트 값을 믿지 않는다).
	rerollTicketGoldMultiplier = 40,
}
