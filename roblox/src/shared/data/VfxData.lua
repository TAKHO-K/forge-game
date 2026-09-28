-- W3c 스킬 · 공격 VFX 수치(연출만 - 판정 · 피해 · 판정 시각과 무관). 그리기 = client/SkillVfx(모듈 하나 - A2 카툰 교체 때 여기 수치 · 그 모듈만 바꾼다).
--   색 규칙: 보스 경고색(주황 · 빨강 - TrailData.forbidden.warmHue 330 ~ 50°)과 태초 전용(흰 + 자홍 285 ~ 330°)에 안 겹치게. 보라 = 색상 약 260°(자홍보다 파랑 쪽).
--   파티클 절제: 한 번 터짐 = Emit(개수) 한 번 · 상시 방출은 구슬 하나당 1개 · 모든 조각은 풀(재사용).
--   화면 흔들림 = client/CameraShake(설정 "화면 흔들림" 끄면 없음 - LocalPlayer Attribute SettingScreenShake).
local V = {}

-- W3c-1 대검 공중 내려찍기: 적중(타격 프레임) 히트스톱 · 공중 공격 뒤 착지 = 발밑 먼지 고리 + "쿵" 착지 + 작은 흔들림(내 화면)
V.greatswordAir = {
	hitstopSeconds = 0.09, -- 평타 0.05 · 3타 강공격 0.08보다 조금 길게(모션만 멈춤 - 판정 시각 불변)
	landWindowSeconds = 1.5, -- 공중 공격 뒤 이 안에 착지하면 먼지 고리
	readyRiseSpeed = 28, -- 체공 중 칼 들어 올림 가중치 = 1 − (상승 속도 ÷ 이 값) - 정점에 가까울수록 크게 들어 올린다
	dustRing = { color = Color3.fromRGB(196, 186, 164), fromStuds = 2, toStuds = 11, seconds = 0.4, startTransparency = 0.25, thickness = 0.25, puffs = 10, puffSpeed = 9, puffSize = 1.1 },
	shake = { seconds = 0.12, studs = 0.22 },
}

-- W3c-2 궁수 E 백스텝샷 = "비장의 한 발"(E를 쓴 뒤 첫 평타 1발 - 나머지 충전 4발은 옛 "강화 화살" 그대로)
V.bowFinisher = {
	armSeconds = 8, -- E를 쓴 뒤 이 안의 첫 평타가 비장의 한 발(서버 버프가 실제로 붙은 발만 큰 화살 - isBuffedShot)
	arrowScale = 3.4, -- 화살 크기(평타 1 · 강화 화살 2.4 · 강궁 1.8)
	trailWidthScale = 2.6, -- 꼬리 폭(강화 · 강궁 1.6)
	trailLifetime = 0.5,
	color = Color3.fromRGB(170, 240, 255), -- 청백
	critColor = Color3.fromRGB(235, 250, 255),
	light = { brightness = 4, range = 14 },
	gather = { color = Color3.fromRGB(160, 235, 255), count = 14, lightBrightness = 3, lightRange = 8 }, -- 준비: 활 · 화살촉에 빛이 모임(전조 = 기존 발사 시각 안)
	airRing = { color = Color3.fromRGB(200, 245, 255), fromStuds = 1, toStuds = 6, seconds = 0.25, startTransparency = 0.2, thickness = 0.12, rings = 2, gapStuds = 3 }, -- 발사: 공기를 가르는 고리(총구 앞으로 rings개)
	shake = { seconds = 0.12, studs = 0.18 }, -- 발사 순간(작게)
	impact = { color = Color3.fromRGB(190, 245, 255), count = 16, speed = 22, size = 0.8, flashStuds = 5, flashSeconds = 0.14, pushStuds = 3 }, -- 적중: 큰 충격 + 쏜 방향으로 밀리는 조각(넉백 강조 - 몹은 안 움직인다)
	hitstopSeconds = 0.1, -- 적중 히트스톱(강화 화살 0.05 · 3타 강공격 0.08보다 길게)
	hitShake = { seconds = 0.14, studs = 0.28 },
	streak = { color = Color3.fromRGB(170, 240, 255), widthStuds = 0.35, seconds = 0.45, beyondStuds = 10 }, -- 관통(강궁 버프 중 = 관통 1)이면 경로에 남는 빛줄기
}

-- W3c-3 치유사 딜링모드 = "어둠을 해방한" 구슬(치유모드 = 기존 밝은 구슬)
V.healerDark = {
	core = Color3.fromRGB(14, 8, 24), -- 검은 핵
	rim = Color3.fromRGB(165, 110, 255), -- 밝은 보라 테두리(어두운 맵에서도 보이게 - 색상 262°)
	rimCrit = Color3.fromRGB(215, 185, 255),
	coreStuds = 0.75, shellScale = 1.5, shellTransparency = 0.45,
	light = { brightness = 3, range = 9 },
	trail = { color = Color3.fromRGB(70, 40, 110), edge = Color3.fromRGB(15, 8, 25), width = 0.9, lifetime = 0.45, startTransparency = 0.15 }, -- 어둠 연기 리본(빛 없음)
	motes = { color = Color3.fromRGB(40, 20, 70), rate = 22, lifetime = 0.35, size = 0.35 }, -- 주변을 도는 어둠 입자(안쪽으로 감김)
	cast = { color = Color3.fromRGB(120, 70, 220), dark = Color3.fromRGB(30, 15, 55), count = 18, seconds = 0.7, lightBrightness = 2.5, lightRange = 7 }, -- E 켜는 순간: 손 끝에 검보라 소용돌이
	impact = { burstStuds = 2.6, burstSeconds = 0.08, implodeSeconds = 0.2, count = 10 }, -- 적중: 작게 터졌다(burst) → 안으로 빨려 사라짐(implode)
}

return V
