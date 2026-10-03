-- QUEUE-ALL9C 2-4 직업 변신 연출(client/ClassTransform): 직업을 고르면 내 아바타가 그 직업으로 "변신"(2 ~ 3초 · 누르면 건너뛰기).
--   순서 = 연기 펑 → 방어구 v3 조각이 날아와 철컥 → 무기가 떨어져 받음 → 직업별 웃긴 한 박자(ClassData.cards[].transform) → 포즈.
--   단순 버전(연기 펑 → 완성 포즈) = 체형 극단 · 레이어드 옷 · 큰 액세서리(조각이 몸에서 떠 보이거나 겹친다) · 연출 끔(FxLevel off).
--   아이 연령: 맞거나 넘어지는 동작 없음 · 조롱 없음 · 화면 번쩍임 없음(빛 = 작은 반짝이만).
-- 사용자 10-03 확정: 플레이어 아바타 변신은 쓰지 않는다(아바타마다 깨짐) → 직업 선택 무대의 전용 캐릭터(client/ClassStage)로 대체 · 이 연출 = 스위치로 끔(코드 남김).
return {
	enabled = false,
	seconds = { smoke = 0.35, armor = 0.65, weapon = 0.45, beat = 0.9, pose = 0.45 }, -- 합 2.8초
	armorStagger = 0.04, -- 조각마다 출발 간격
	armorFly = { distance = { 5, 8 }, up = 3 }, -- 조각 출발 자리(몸에서 떨어진 거리 · 위로)
	weaponDropHeight = 9, -- 무기가 떨어지기 시작하는 높이(손 위 stud)
	camera = { distance = 11, height = 1.5, lookHeight = 0.4, fov = 45 }, -- 캐릭터 정면 · 연출 동안만(끝나면 원래 카메라)
	simple = { minScale = 0.85, maxScale = 1.3, accessoryMaxStuds = 3.5 }, -- 체형 배율(높이 · 너비 · 머리 · 깊이) · 액세서리 손잡이 가장 긴 변
	previewLook = "tier1|normal", -- 입은 방어구가 없는 부위 = 그 직업 기본 모양을 연출 동안만 입혀 보여 주고 끝에 서서히 사라진다
	previewFadeSeconds = 0.5,
	bodyPart = { LeftHand = "gloves", RightHand = "gloves", LeftFoot = "shoes", RightFoot = "shoes" }, -- 조각이 붙은 몸 파트 → 방어구 부위(없으면 armor) - 미리보기 부위만 사라지게
	smoke = { puffs = 9, size = { 2.5, 4.5 }, color = Color3.fromRGB(235, 236, 240), seconds = 0.6 },
	sparkle = { count = 8, color = Color3.fromRGB(255, 226, 120), size = 0.6, seconds = 0.5 },
	props = {
		appleColor = Color3.fromRGB(220, 52, 52),
		leafColor = Color3.fromRGB(70, 170, 70),
		arrowColor = Color3.fromRGB(150, 110, 70),
		arrowFrom = 22, -- 화살이 날아오는 거리(옆에서)
		dustColor = Color3.fromRGB(196, 170, 130),
		daggerColor = Color3.fromRGB(200, 205, 215),
		juggleHeight = 3.2,
		flowerColors = { Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 230, 120), Color3.fromRGB(170, 210, 255), Color3.fromRGB(255, 255, 255) },
		flowers = 7,
	},
	-- 소리 = SoundSheetData 큐
	sounds = { smoke = "recall_done", clank = "protect_ticket", catch = "pickup", heavy = "hit_heavy", juggle = "swing", apple = "hit_light", flowers = "codex_cell", pose = "title_get" },
}
