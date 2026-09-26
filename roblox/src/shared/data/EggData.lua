-- M1-3 구역 알(팰월드 알처럼 - 구역마다 다른 색 · 다른 개체 풀). 이번 범위 = 데이터 구조 · 겉모습 · 확률표 틀(부화 · 펫 기능은 펫 단계).
--   알 하나 = 그 구역 풀에서 개체 후보 candidates(2)종 · 부화 때 50:50(candidateWeights).
--   알 등급 = 겉모습: normal(무늬 없음) · good(무늬) · rare(빛남 - 부화 결과 등급 보정이 좋다). 결과 등급 확률은 사전 고지(hatch 표 - 알 정보창에 공개).
--   트랙별 알 등급 저점 · 분포(grades) = 줍는 순간 서버가 뽑는다(사람마다 · 둥지마다 · 줍기 회차마다 고정 - 다시 들어와도 같은 알).
--   ★ 확률 숫자는 제안값(M1-3 보고서 표 - 확정은 사용자).
return {
	-- 알 색 = 구역 보스 관문 색(BossData gate.color - 이미 있는 색) · 무늬 색 = 같은 색을 어둡게 · 빛 = 같은 색
	zones = {
		tier1 = { name = "석조 평원 알", pool = { "stoneTurtle", "mossHare", "pebbleMole", "ruinOwl" } },
		tier2 = { name = "수정 동굴 알", pool = { "crystalBat", "prismLizard", "gleamSnail", "quartzFox" } },
		tier3 = { name = "수몰 사원 알", pool = { "reefOtter", "shellCrab", "tideFrog", "lotusFish" } },
		tier4 = { name = "모래 유적 알", pool = { "duneFennec", "cactusHedgehog", "scarabBeetle", "sunGecko" } },
		tier5 = { name = "폭풍 첨탑 알", pool = { "sparkFerret", "cloudSheep", "thunderHawk", "galeSquirrel" } },
		tier6 = { name = "빙하 동굴 알", pool = { "frostPenguin", "snowOwl", "iceSeal", "auroraFox" } },
	},
	-- 개체 이름(자리 표시 - 펫 단계에서 모형 · 기능 · 이름 확정. 유틸 전용 · 전투 기능 없음 · 이후 탑승)
	species = {
		stoneTurtle = "돌 거북", mossHare = "이끼 토끼", pebbleMole = "조약돌 두더지", ruinOwl = "폐허 올빼미",
		crystalBat = "수정 박쥐", prismLizard = "프리즘 도마뱀", gleamSnail = "반짝 달팽이", quartzFox = "석영 여우",
		reefOtter = "산호 수달", shellCrab = "소라 게", tideFrog = "물결 개구리", lotusFish = "연꽃 물고기",
		duneFennec = "사막 여우", cactusHedgehog = "선인장 고슴도치", scarabBeetle = "쇠똥구리", sunGecko = "햇빛 도마뱀붙이",
		sparkFerret = "불꽃 족제비", cloudSheep = "구름 양", thunderHawk = "천둥 매", galeSquirrel = "돌풍 다람쥐",
		frostPenguin = "서리 펭귄", snowOwl = "눈 올빼미", iceSeal = "얼음 물범", auroraFox = "오로라 여우",
	},
	candidates = 2,
	candidateWeights = { 50, 50 },
	gradeOrder = { "normal", "good", "rare" },
	gradeNames = { normal = "보통", good = "좋은", rare = "희귀" },
	-- 겉모습(월드 · 창 같은 규칙): size = 알 크기(stud) · pattern = 무늬 띠 수 · glow = 빛(PointLight 밝기 · 범위)
	look = {
		size = Vector3.new(1.8, 2.4, 1.8),
		normal = { pattern = 0, glow = nil },
		good = { pattern = 3, glow = nil },
		rare = { pattern = 3, glow = { brightness = 1.6, range = 10 } },
		patternDarken = 0.55,
	},
	-- 트랙별 등급 분포(%) - 저점 = 0이 아닌 가장 낮은 등급. Ahigh = 직접 오른 높은 곳 · Btop = B 최상위(하루 1회).
	-- M1-3 결정 2(사용자 확정 2026-09-26): A 높은 곳 = 저점 보통 · 좋은 약 40 · 희귀 거의 없음 / B = 저점 좋은 · 희귀 약 10 / C-필드 = 저점 좋은 · 희귀 약 20 /
	--   C-진짜 히든 = 저점 좋은 · 희귀 50(하루 구역당 켜지는 진짜 히든이 hiddenFullRareMaxPerZone곳 이하일 때만 - 넘으면 ChiddenCrowded 25 ~ 30) / C-마을 = C-필드보다 한 단계 낮게(저점 보통).
	--   Btop · A · C-마을은 이번 결정에 없어 그대로.
	grades = {
		A = { normal = 80, good = 18, rare = 2 },
		Ahigh = { normal = 59, good = 40, rare = 1 },
		Cvillage = { normal = 75, good = 23, rare = 2 },
		B = { normal = 0, good = 90, rare = 10 },
		Btop = { normal = 0, good = 65, rare = 35 },
		Cfield = { normal = 0, good = 80, rare = 20 },
		Chidden = { normal = 0, good = 50, rare = 50 },
		ChiddenCrowded = { normal = 0, good = 72, rare = 28 },
	},
	hiddenFullRareMaxPerZone = 1,
	-- 부화 결과 등급 확률(사전 고지 · 알 정보창) - 펫 등급 이름은 자리 표시(펫 단계에서 확정)
	hatchGrades = { "common", "uncommon", "rare", "epic" },
	hatchGradeNames = { common = "일반", uncommon = "고급", rare = "희귀", epic = "영웅" },
	hatch = {
		normal = { common = 70, uncommon = 25, rare = 4.5, epic = 0.5 },
		good = { common = 45, uncommon = 40, rare = 13, epic = 2 },
		rare = { common = 20, uncommon = 45, rare = 28, epic = 7 },
	},
}
