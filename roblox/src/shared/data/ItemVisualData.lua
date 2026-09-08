-- 드랍 아이템의 시각 표현(색·발광·글자 크기)과 부위별 모양 치수(14-1). 밸런스 수치(드랍
-- 확률·스탯)가 아니라 순수 표현 데이터라 ArmorData·Loot과 분리해 여기 둔다.
--
-- 등급 색은 웹 v1 data/items.js ITEM_GRADES.color를 그대로 옮긴다 - "색이 곧 정보다"라는
-- 원칙(PRD-forge-game.md 7.1-1)이 로블록스에서도 그대로 적용돼야 한다. 지금 실제로
-- 드랍되는 건 일반/희귀뿐이다(ArmorData.grades) - 나머지 5등급(영웅~태초)은 색·발광
-- 세기·토스트 크기만 미리 정의해 둔다(드랍 로직·gradeMultiplier 확장은 이번 범위 밖,
-- "새 등급 추가" 금지 지시). 등급이 높을수록 발광이 강해지고(glowBrightness·glowRange)
-- 드랍 순간 연출(burstOnDrop)이 켜진다 - "낮은 등급은 조용해야 한다"는 지시를 정확도
-- 있게 반영한다(일반만 조용함, 희귀부터 연출 켜짐).
return {
	gradeVisuals = {
		normal = {
			color = Color3.fromRGB(230, 230, 230), -- 웹 #e6e6e6
			glowBrightness = 0.5, glowRange = 8,
			burstOnDrop = false,
			toastTextSize = 18,
		},
		rare = {
			color = Color3.fromRGB(77, 166, 255), -- 웹 #4da6ff
			glowBrightness = 1.2, glowRange = 12,
			burstOnDrop = true,
			toastTextSize = 22,
		},
		epic = {
			color = Color3.fromRGB(166, 77, 255), -- 웹 #a64dff
			glowBrightness = 1.8, glowRange = 14,
			burstOnDrop = true,
			toastTextSize = 24,
		},
		legendary = {
			color = Color3.fromRGB(255, 153, 51), -- 웹 #ff9933
			glowBrightness = 2.4, glowRange = 16,
			burstOnDrop = true,
			toastTextSize = 26,
		},
		relic = {
			color = Color3.fromRGB(255, 215, 0), -- 웹 #ffd700
			glowBrightness = 3.0, glowRange = 18,
			burstOnDrop = true,
			toastTextSize = 28,
		},
		ancient = {
			color = Color3.fromRGB(224, 57, 62), -- 웹 #e0393e
			glowBrightness = 3.6, glowRange = 20,
			burstOnDrop = true,
			toastTextSize = 30,
		},
		-- 웹은 태초를 "rainbow"(렌더에서 hue 순환)로 처리한다 - 로블록스에서 태초가 실제로
		-- 드랍 가능해질 때 색상 애니메이션을 붙인다. 지금은 도달 불가능한 등급이라 흰색을
		-- 자리표시자로만 두고 rainbow=true 플래그만 남긴다(미구현, 이번 범위 밖).
		primordial = {
			color = Color3.fromRGB(255, 255, 255),
			glowBrightness = 4.5, glowRange = 24,
			burstOnDrop = true,
			toastTextSize = 34,
			rainbow = true,
		},
	},

	-- 부위별 모양(치수만 - 전부 단일 Part, 몬스터와 같은 "도형으로 표현" 방식). 지금은
	-- armor만 실제로 드랍된다 - 장갑·신발·무기는 부위 자체가 아직 없다(이번 범위 밖,
	-- "새 부위 추가" 금지 지시). 나중에 그 부위가 드랍 가능해질 때 곧바로 쓸 수 있게
	-- 치수만 미리 잡아 둔다.
	partShapes = {
		armor = Vector3.new(1.6, 1.8, 0.7), -- 넓적한 판(조끼) 실루엣
		gloves = Vector3.new(0.9, 0.9, 0.9), -- 주먹만 한 정육면체
		shoes = Vector3.new(1.0, 0.6, 1.6), -- 낮고 긴 신발 밑창 실루엣
		weapon = Vector3.new(0.25, 2.2, 0.25), -- 가늘고 긴 칼날 실루엣
	},

	partDisplayNames = {
		armor = "갑옷",
		gloves = "장갑",
		shoes = "신발",
		weapon = "무기",
	},
}
