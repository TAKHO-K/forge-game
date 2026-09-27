-- W2 공격 잔상(무기 발광 대신): 무기 끝을 따라 흐르다 사라지는 리본(로블록스 Trail) - 그리기 = client/WeaponVisual(칼날 부착점) · client/Projectiles(화살 · 구슬 꼬리) ·
--   스킨 = shared/TrailSkin · 적중 불꽃 = client/AttackTrail.spark. (W2 1차의 "판정 도형을 그리는 흔적"은 폐기 - 판정 도형은 /gg hitbox 디버그 전용.)
-- 리본은 휘두르는 동작 구간(act)에만 켠다(전후 번짐 없음). 판정 일치 = 모션이 판정 범위를 쓸고 지나가게(판정 값은 그대로).
-- 스킨은 색 · 질감 · 빛남만. 너비 · 수명 · 강공격 규칙(아래 ribbon · projectile)은 모든 스킨 동일.
local T = {}

T.defaultSkin = "default"

-- 칼날 리본(대검 = 넓고 묵직한 호 · 쌍검 = 양손 칼날 각각 얇은 리본 · 활 · 지팡이 = 가까운 대상 휘두르기에만 - W2-4)
T.ribbon = {
	lifetime = 0.2, -- 0.15 ~ 0.25
	startTransparency = 0.35, -- 1 · 2타(얇고 은은하게) - 끝 = 1(서서히 사라짐)
	lightEmission = 0.35,
	widthTaper = 0.1, -- 끝으로 갈수록 가늘어짐(WidthScale 1 → 이 값)
	heavy = { -- 3타 · 공중 3타 강공격: 더 넓고 밝게 + 바깥 옅은 두 번째 리본(광택) + 적중 불꽃 + 짧은 히트스톱(AttackInput 0.08 - 서버 확정 뒤)
		startTransparency = 0.1, lightEmission = 0.8,
		gloss = { outerStuds = 0.9, transparency = 0.65, lifetime = 0.25 }, -- 칼끝 바깥으로 이만큼 더 나간 옅은 리본
	},
	classes = { greatsword = true, dualblade = true, paladin = true }, -- 근접 리본을 켜는 직업
	closeClasses = { bow = true, healer = true }, -- W2-4: 대상이 아주 가까워 휘두를 때만(PlayerMotionData.closeSwing) 켜는 직업 - 규칙(너비 · 수명 · 강공격)은 위와 같다
}

-- 투사체 꼬리(화살 = 가늘고 밝게 + 촉 빛 · 지팡이 = 굵게 + 옅은 파티클) - 강공격 = 더 길고 밝게
T.projectile = {
	arrow = { lifetime = 0.35, width = 0.18, startTransparency = 0.15, lightEmission = 0.7, heavyLifetime = 0.55, heavyWidth = 0.3, tipLight = { brightness = 1.2, range = 5 } },
	orb = { lifetime = 0.3, width = 0.6, startTransparency = 0.2, lightEmission = 0.8, heavyLifetime = 0.5, heavyWidth = 0.85, particles = { rate = 14, lifetime = 0.35, size = 0.25 } },
}

-- 적중 불꽃(강공격 적중 · 투사체 적중 - 서버 적중 지점) - 조각 수(성능 메모: 풀 상한 client/AttackTrail POOL)
T.spark = { heavyCount = 6, projectileCount = 4, seconds = 0.3, speed = 14 }

-- 스킨(판매 대비 - 상품 · 가격은 P4c): core = 리본 색 · edge = 끝쪽 색(ColorSequence) · material = 불꽃 질감 · particle = 파티클 색 · devOnly = 개발 전용(판매 X)
T.skins = {
	default = { core = Color3.fromHex("#E6F2FF"), edge = Color3.fromHex("#7898C2"), material = "Neon" }, -- W2 확인: 추천 가장자리 #9FB8D6은 눈 바닥에서 안 보여 한 단계 어둡게
	devMint = { core = Color3.fromHex("#D8FFEC"), edge = Color3.fromHex("#5FBF8F"), material = "Neon", particle = Color3.fromHex("#9CF0C4"), devOnly = true }, -- 개발 예시 1(민트)
	devIndigo = { core = Color3.fromHex("#D9DCFF"), edge = Color3.fromHex("#5A63C8"), material = "Glass", particle = Color3.fromHex("#8E97FF"), devOnly = true }, -- 개발 예시 2(남색 유리 질감)
}

-- 스킨 금지 색(TrailSkin.check): 주황 · 빨강 계열(보스 경고 장판과 혼동) · 흰 + 자홍(태초 전용 조합).
T.forbidden = {
	warmHue = { fromDeg = 330, toDeg = 50, minSaturation = 0.35 },
	primordial = { whiteMinValue = 0.93, whiteMaxSaturation = 0.08, magentaFromDeg = 285, magentaToDeg = 330, magentaMinSaturation = 0.3 },
	allowedFields = { core = true, edge = true, material = true, particle = true, devOnly = true, texture = true },
}

-- 설정: "다른 유저 궤적 흐리게"(파티 전투 화면 정리) - 켜면 남의 리본 · 꼬리 시작 투명도에 이만큼 더한다(세션 메모리 - 저장은 P4-4).
T.dimOthers = { default = false, extraTransparency = 0.5 }

-- 남의 투사체 꼬리 중계 거리(서버 AttackShotRelay가 이 안만 보낸다)
T.othersDrawStuds = 120

return T
