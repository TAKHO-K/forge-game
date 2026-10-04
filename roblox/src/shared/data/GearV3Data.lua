-- QUEUE-ALL9E1 블록 1 장비 v3(규격 = docs/design/gear-art-v3.md 3 · 4 · 6 · 7절). 등급 색(메인 · 밝은 · 어두운) = ItemVisualData.gradeVisuals 한 곳 - 여기는 세트 · 단계 · 구역 규칙만.
--   스위치 GearV3Meshes(enabled · Studio에서만 ReplicatedStorage Attribute "GearV3Meshes"가 덮는다) - 끄면 지금 모습(직업 v3.1 메시 · ArmorColors.colorOfV3).
--   메시 = armor/<부위>_<직업>_<단계>(s1 ~ s5) · 무기 = weapons/<무기>_<단계> · 문장 = armor/emblem_<세트> - 조각 이름 = <조각>_<구역>[_<문>]
--   구역(Body · Trim · Inner · Attach · Gem · CoreGem · Float · Crack)을 코드가 칠한다(8등급 × 6세트) · 문(Ep · An · Tr) = 그 등급에서만 보이는 작은 부품.
return {
	enabled = true,
	-- 등급 → 모양 단계(4절): S1 일반 / S2 희귀 · 영웅 / S3 전설 / S4 유물 · 고대 / S5 태초 · 초월
	stageOfGrade = { normal = "s1", rare = "s2", epic = "s2", legendary = "s3", relic = "s4", ancient = "s4", primordial = "s5", transcendent = "s5" },
	-- 문 = 같은 단계 안 위 등급 전용 부품(4절: 영웅 = 희귀 + 보석 2 · 이중 테두리 / 고대 = 유물 + 관 · 깃 층 / 초월 = 태초 + 균열 선)
	gateGrade = { Ep = "epic", Re = "relic", An = "ancient", Tr = "transcendent" }, -- Re = 유물 루비 오벌(고대 = An 에메랄드 스텝 컷과 자리 공유)
	-- 세트(구역 tier1 ~ 6) 부착물 색(3절 hex): color1 = 천 띠 · 테두리(Attach) · color2 = 보조 보석 · 장식(Gem · Emblem) · emblem = 문장 메시 키
	sets = {
		tier1 = { name = "석조 평원", color1 = { 102, 131, 74 }, color2 = { 168, 121, 69 }, emblem = "stone" }, -- #66834A · #A87945
		tier2 = { name = "수정 동굴", color1 = { 168, 138, 224 }, color2 = { 242, 181, 213 }, emblem = "crystal" }, -- #A88AE0 · #F2B5D5
		tier3 = { name = "수몰 사원", color1 = { 56, 185, 176 }, color2 = { 242, 231, 208 }, emblem = "shell" }, -- #38B9B0 · #F2E7D0
		tier4 = { name = "모래 유적", color1 = { 216, 188, 131 }, color2 = { 198, 154, 69 }, emblem = "sun" }, -- #D8BC83 · #C69A45(문장 테두리만)
		tier5 = { name = "폭풍 첨탑", color1 = { 53, 79, 145 }, color2 = { 198, 209, 227 }, emblem = "storm" }, -- #354F91 · #C6D1E3
		tier6 = { name = "빙하 동굴", color1 = { 143, 215, 237 }, color2 = { 213, 225, 232 }, emblem = "frost" }, -- #8FD7ED · #D5E1E8
	},
	-- 3절 겹칠 때 규칙: 같은 계열 = 부착물 밝게(밝기 배수) · 예약 조합(흰 + 자홍 = 태초만 · 검정 + 금 = 초월만 · 초월 + 모래 = 금 대신 모래)
	sameFamily = { ancient_tier3 = 1.18, epic_tier2 = 1.1, rare_tier5 = 1.12, rare_tier6 = 1.12 },
	transcendSandSwap = true, -- 초월 + 모래 유적: Gem(금 #C69A45) 대신 모래 color1
	-- 핵심 보석(CoreGem · 2-1절 · S4 · S5): 등급별 색 · 속심(Neon) - 유물 루비 · 고대 에메랄드(속심만 빛) · 태초 다이아(자홍 받침) · 초월 블랙 다이아(금 균열)
	coreGem = {
		relic = { body = { 185, 47, 72 }, core = { 240, 107, 118 } }, -- #B92F48 · 속심 #F06B76
		ancient = { body = { 8, 127, 130 }, core = { 75, 212, 194 } }, -- #087F82 · 속심 #4BD4C2
		primordial = { body = { 247, 245, 239 }, core = { 233, 91, 200 } }, -- #F7F5EF · 받침 #E95BC8
		transcendent = { body = { 32, 33, 39 }, core = { 216, 185, 110 } }, -- #202127 · 균열 #D8B96E
	},
	crack = { 216, 185, 110 }, -- 초월 균열 · 부유(초월) Neon(#D8B96E)
	-- 무기(세트 없음 · shared/GearV3.weaponColor): 날 = 강철 #E8ECF4(옛 무기 메타 날 색)에 등급 메인 bodyTint만큼 · 태초 · 초월 손잡이 = 흑요석 그늘
	weapon = { steel = { 232, 236, 244 }, bodyTint = 0.25, darkGrip = { 38, 36, 42 } },
	-- QUEUE-ALL9E1 LOOK2(10-04 밤 · 설계 담당 결정 - gear-art-v3.md 3-1절): 등급색 = 주 판금 에나멜만(가슴 · 어깨 · 허리 아래 판 · 허벅지/무릎 판) · 테두리 · 리벳 · 버클 = 등급대 금속 ·
	--   아래층(가죽 · 천) = 전 등급 공통 중립 · 장갑 · 신발 = 가죽 + 금속 커프(등급색 = 커프 띠 Band만) · 초월 = 흑요석 판 + 흑금 테 · 태초 = 백색 판 + 백금 테 + 자홍 띠
	look2 = {
		trimMetal = { -- 금속 테두리 · 커프 · 버클(Trim · 팔/정강이 커프)
			normal = { 201, 206, 214 }, rare = { 201, 206, 214 }, epic = { 201, 206, 214 }, -- 강철 #C9CED6
			legendary = { 226, 180, 90 }, relic = { 226, 180, 90 }, ancient = { 226, 180, 90 }, -- 금 #E2B45A
			primordial = { 236, 236, 242 }, -- 백금(자홍 #E95BC8 = 커프 띠 · 받침 포인트)
			transcendent = { 216, 185, 110 }, -- 흑금 #D8B96E
		},
		leather = { 90, 62, 43 }, -- 가죽 #5A3E2B(벨트 · 장갑 · 장화)
		cloth = { navy = { 43, 53, 80 }, cream = { 232, 220, 192 } }, -- 천(진남색 #2B3550 · 크림 #E8DCC0) - 직업별 하나(baseLayer와 같은 색)
		-- 등급별 에나멜 밝기 보정(4번 - 색상 유지 · 밝기만): Soft 조명 · 그늘 면이 아이콘보다 0.76 ~ 0.88배 어둡게 찍혔다(look1-survey 3절)
		brightness = { normal = 1.06, rare = 1.12, epic = 1.12, legendary = 1.1, relic = 1.12, ancient = 1.15, primordial = 1.0, transcendent = 1.0 },
	},
	-- LOOK2 보정 1 바닥층(갑옷 착용 중 2D 옷 = 누빔 상의 + 바지 · 등급색 없음): 직업 → 색(textures/gear_v3/base_<색>_shirt|pants · ArtAssetIds image)
	baseLayer = { greatsword = "navy", dualblade = "navy", bow = "cream", healer = "cream" },
	-- 착용(6절) · 예산(7절): 하네스 · 메시 스크립트가 같은 값(artlib 쪽 숫자는 make_gear_v3.py가 이 표를 미러 - 바뀌면 둘 다)
	budget = { armor = 1500, glovesPair = 500, shoesPair = 500, weapon = 800, float = 300, coreGem = 120, meshPartsPerPlayer = 24 },
}
