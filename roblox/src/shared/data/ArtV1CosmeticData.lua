-- A2-N2 2-3 치장 외형(4칸 × 테마 3 - CosmeticSlotData.sets의 looks 자리가 가리키는 값). 외형만 - 능력치 · 판정 0(판매 금지 규칙 docs/design/monetization-p4c.md §1).
--   그리기 = client/ArtV1Cosmetics(ArtStyleV1 스위치 뒤 · 내 캐릭터 + 남의 캐릭터(입자 × 0.5 · 거리 120 안)) · 장착 = Player Attribute Cosmetic_<칸>(서버 CosmeticService) = 세트 id.
--   색 규칙 = 공격 궤적 스킨과 같은 금지(shared/TrailSkin.check: 주황 · 빨강 330 ~ 50° 채도 ≥ 0.35 = 보스 경고색 · 흰 + 자홍 = 태초) · 초월(검정 + 금) 흉내 금지.
--   불씨 = 금노랑 불씨(색상 51 ~ 56° - 위험색 경계 밖) · 별빛 = 남색 → 보라 + 흰 별 · 서리꽃 = 옅은 청록 + 흰 결정.
local C = Color3.fromRGB

local D = {
	themes = {
		-- QUEUE-ALL6 H #42 망치와 모루: 대시 = 금노랑 불꽃 튐(위험색 경계 51° 위) · 점프 = "깡!" 고리(글자 = TextData cos.anvil.clang) · 활강 = 불씨 줄 · 발자국 = 망치 자국(shape hammer)
		anvil = {
			core = C(255, 240, 140), edge = C(250, 224, 70), particle = C(255, 236, 110),
			dash = { width = 1.6, lifetime = 0.22, transparency = { 0.15, 1 }, drops = { every = 0.06, size = 0.35, seconds = 0.5, neon = true } },
			jump = { ring = 5, particles = 12, speed = 12, gravity = 30, size = 0.3, spread = 60, labelKey = "cos.anvil.clang" },
			glide = { width = 0.5, lifetime = 0.8, particles = 8, particleLife = 0.9, gravity = 4, size = 0.25 },
			footstep = { size = 1.3, seconds = 1.4, shape = "hammer", neon = false },
		},
		-- QUEUE-ALL6 H #50 할로윈 박쥐(10월 판매): 보라 · 짙은 보라(태초 흰+자홍 · 초월 검정+금 밖) · 대시 = 박쥐 떼(dash.bats) · 발자국 = 보라 호박 실루엣(QUEUE-ALL6R - 주황은 공중 박쥐 눈 · 작은 호박만)
		halloween = {
			core = C(150, 96, 200), edge = C(86, 52, 128), particle = C(120, 80, 170),
			-- QUEUE-ALL6R 결정 5(사용자): 주황은 공중 요소에만 - 박쥐 눈(eye) · 박쥐 떼 사이 작은 호박 장식(ornament - pumpkinEvery번째마다 하나). 바닥 효과(발자국 · 점프 고리)는 보라.
			dash = { width = 1.8, lifetime = 0.3, transparency = { 0.2, 1 }, bats = { every = 0.1, size = 0.9, seconds = 0.9, eye = C(255, 150, 40), pumpkinEvery = 4 } },
			jump = { ring = 5, particles = 8, speed = 8, gravity = 6, size = 0.4, spread = 80 },
			glide = { width = 0.6, lifetime = 1.0, particles = 6, particleLife = 1.2, gravity = -1, size = 0.35, bats = { every = 0.35, size = 0.8, seconds = 1.1, eye = C(255, 150, 40), pumpkinEvery = 3 } },
			ornament = { pumpkin = C(255, 140, 40), stem = C(70, 110, 70), size = 0.55 }, -- 공중 작은 호박(주황 - 공중이라 바닥 위험 표시와 안 겹친다)
			footstep = { size = 1.3, seconds = 1.4, shape = "pumpkin", neon = false, pumpkin = C(112, 72, 156), stem = C(70, 42, 104) } -- QUEUE-ALL6R 결정 5: 보라 호박 실루엣(꼭지까지 짙은 보라) · 옛 Play 1 갈색(132, 112, 96),
		},
		-- QUEUE-ALL1 P6 말랑 젤리(07 문서 · 199): 라임 + 민트(색상 80 ~ 160° - 위험색 · 태초 · 초월 밖). 대시 = 방울이 튀며 잠깐 남음(dash.drops) · 점프 = 발밑 "뽀잉" 찌그러지는 고리(jump.squash) · 활강 = 방울 거품 줄 · 발자국 = 작은 젤리 웅덩이(shape puddle)
		jelly = {
			core = C(206, 250, 150), edge = C(120, 226, 170), particle = C(190, 250, 200),
			dash = { width = 2.0, lifetime = 0.3, transparency = { 0.1, 1 }, drops = { every = 0.07, size = 0.7, seconds = 0.9 } },
			jump = { ring = 5.5, particles = 10, speed = 7, gravity = 10, size = 0.5, spread = 70, squash = { widen = 1.5, seconds = 0.3 } },
			-- QUEUE-ALL6R 5(사용자: 거품이 작고 옅다 - 조금 키우고 진하게 · 피로 금지 범위): 크기 0.34 → 0.46 · 발광 1 → 0.2(밝은 바닥에서 하얗게 날아가던 것) · 색 = 테 민트(옅은 particle 대신) · 개수 · 수명 그대로(번쩍임 · 흔들림 없음)
			glide = { width = 0.7, lifetime = 0.9, particles = 7, particleLife = 1.1, gravity = -2, size = 0.46, particleLightEmission = 0.2, particleColor = C(120, 226, 170), particleSpeed = { 2.5, 4.5 }, -- QUEUE-ALL7 E1: 거품이 몸에 가려 안 보였다 → 몸 밖으로 퍼지게(속도만)
				-- QUEUE-ALL8 E1: 풀 위에서 민트가 묻혔다 → 거품 그림(진한 민트 몸 + 얇은 진한 청록 테 + 하이라이트 - roblox/tools/fx/bubble_texture.py) · 그림 색 그대로(입자 색 흰 · 발광 0)
				particleTexture = "fx/jelly_bubble", particleTextureColor = C(255, 255, 255), particleTextureLightEmission = 0 },
			footstep = { size = 1.4, seconds = 1.3, shape = "puddle", neon = false },
		},
		ember = {
			core = C(255, 238, 130), edge = C(250, 222, 60), particle = C(255, 236, 110), -- 2차 패스: 크림색이 불씨로 안 읽혔다 → 금노랑(테 색상 51° - 위험색 밖)
			dash = { width = 2.2, lifetime = 0.35, transparency = { 0, 1 } },
			jump = { ring = 6, particles = 12, speed = 8, gravity = -3, size = 0.42, spread = 60 }, -- 불씨가 위로 흩날린다
			glide = { width = 0.8, lifetime = 0.9, particles = 5, particleLife = 0.9, gravity = -1.5, size = 0.22 },
			footstep = { size = 1.2, seconds = 1.0, shape = "disc", neon = true },
		},
		starlight = {
			core = C(214, 226, 255), edge = C(96, 110, 230), particle = C(240, 244, 255),
			dash = { width = 2.2, lifetime = 0.38, transparency = { 0, 1 } },
			jump = { ring = 6.5, particles = 12, speed = 9, gravity = 2, size = 0.45, spread = 180 }, -- 별이 사방으로 반짝
			glide = { width = 0.9, lifetime = 1.1, particles = 6, particleLife = 1.2, gravity = 0, size = 0.26 },
			footstep = { size = 1.3, seconds = 1.2, shape = "star", neon = true },
		},
		frost = {
			core = C(236, 252, 255), edge = C(120, 214, 236), particle = C(206, 246, 255),
			dash = { width = 2.1, lifetime = 0.33, transparency = { 0, 1 } },
			jump = { ring = 6, particles = 12, speed = 6, gravity = 8, size = 0.42, spread = 80 }, -- 결정이 튀었다 떨어진다
			glide = { width = 0.8, lifetime = 1.0, particles = 5, particleLife = 1.0, gravity = 4, size = 0.24 },
			footstep = { size = 1.3, seconds = 1.4, shape = "disc", neon = false },
		},
	},
	-- 감지(남의 캐릭터도 같은 식 - 입력 신호가 없어 속도로 읽는다): 대시 = 수평 속도 ≥ dashSpeed(대시 ≈ 73 · 활강 30 · 걷기 ≤ 24) · 점프 = 위 속도가 한 틱에 jumpImpulse 넘게 늘어남
	detect = { dashSpeed = 50, dashHoldSeconds = 0.3, jumpImpulse = 18, footstepStuds = 3.4, footstepMinSpeed = 6, footstepMax = 10 },
	-- QUEUE-ALL1 P6 글라이더 스킨 모양(client/GlideView - look id · 판정 · 속도 불변 · ArtStyleV1 꺼짐 = 기본 잎)
	gliders = {
		-- QUEUE-ALL6 H #55 슬라임 낙하산(메시 없음 - 파트로 짓는다 procedural): 머리 위 반투명 젤리 덮개 + 눈 둘 + 어깨로 내려오는 줄 넷 · 천천히 출렁(판정 · 속도 불변)
		slimeParachute = { procedural = true, color = C(120, 214, 126), eye = C(30, 40, 30), width = 6.2, height = 2.4, above = 4.4, wobbleHz = 0.9, wobble = 0.06 },
		dragonWing = { mesh = "monsters/blue_dragon", parts = { "Wing_L", "Wing_R" }, color = C(70, 130, 205), wingLength = 3.4, side = 0.55, up = 0.9, back = 0.55, flapDeg = 16, flapHz = 0.7 }, -- 천천히 날갯짓
		cloudWhale = { mesh = "extras/cloud_whale", scale = 0.62, colors = { Body = C(126, 186, 240), Tail = C(126, 186, 240), Belly = C(240, 238, 226), Fins = C(104, 164, 226), Eyes = C(34, 44, 70), Cloud = C(236, 244, 252) }, -- 파트 색 = tools/blender/make_cosmetics.py와 같게(캐시 메시 = 회색)
			 offset = { 0, -1.6, 0.4 }, bobStuds = 0.25, bobHz = 0.5,
			splash = { color = C(200, 236, 255), rate = 28, size = 0.35, life = 0.8, speed = 5 } }, -- 물보라 궤적 = 꼬리 입자
	},
	bossOpacity = 0.5, -- 보스전 중 투명도 하한(아군 연출 ≤ 50% - §5)
	trailEmission = 0.6, jumpRingThick = 0.25, -- Play 3: 가산 발광 1 · 두께 0.1은 잔디 위에서 거의 안 보였다
	-- QUEUE-ALL6 H 꾸미기 소품 겉모습(CosmeticSlotData.items[].look)
	items = {
		crystal = { color = C(176, 132, 236), transparency = 0.3, reflectance = 0.15, material = "Glass", clearTexture = true },
		starterEdge = { color = C(206, 216, 230), transparency = 0, reflectance = 0.22, material = "Metal" }, -- QUEUE-ALL9C 1-6 스타터: 은빛 금속 + 은은한 광택(흰+자홍 태초 · 검정+금 초월 흉내 없음) -- 수정 결정 무기: 몸 파트만 반투명 자수정(Neon = 등급 빛은 그대로)
		crown = { color = C(250, 216, 92), gem = C(120, 190, 255), height = 0.45, width = 0.9 }, -- 펫 왕관: 머리 크기 비율(머리 파트 X 크기 × width)
	},
}

-- QUEUE-ALL9B 4 시즌 패스 전용 치장 = 기존 모양의 색 변형(새 메시 없음). 변형 = 바탕을 깊게 복사한 뒤 색만 바꾼다(위 색 규칙 그대로 - 주황 · 빨강 · 흰+자홍 · 검정+금 안 씀).
--   테마는 그리는 쪽이 이 표의 키로 찾는다(client/ArtV1Cosmetics) · 글라이더는 base = 바탕 모양 이름(client/GlideView가 base로 짓는다).
local function variant(base, colors)
	local out = table.clone(base)
	for k, v in pairs(base) do
		if type(v) == "table" then
			out[k] = table.clone(v)
		end
	end
	for k, v in pairs(colors) do
		out[k] = v
	end
	return out
end
D.themes.meadowStar = variant(D.themes.starlight, { core = C(222, 255, 214), edge = C(96, 196, 120), particle = C(236, 255, 230) }) -- 무료 20칸: 초원 별빛
D.themes.violetStar = variant(D.themes.starlight, { core = C(236, 220, 255), edge = C(150, 96, 230), particle = C(246, 236, 255) }) -- 유료 10칸: 보랏빛 별
D.themes.auroraFrost = variant(D.themes.frost, { core = C(226, 255, 246), edge = C(110, 150, 236), particle = C(196, 236, 250) }) -- 유료 20칸(중간 대표): 오로라 서리
D.themes.sodaJelly = variant(D.themes.jelly, { core = C(196, 236, 255), edge = C(90, 170, 236), particle = C(206, 240, 255) }) -- 유료 25칸: 소다 젤리
D.themes.moonEmber = variant(D.themes.ember, { core = C(236, 242, 255), edge = C(170, 190, 236), particle = C(222, 232, 255) }) -- 유료 30칸: 달빛 불씨
D.themes.cloudWhaleTrail = variant(D.themes.starlight, { core = C(240, 248, 255), edge = C(126, 186, 240), particle = C(236, 244, 252) }) -- 유료 40칸 고래 세트(구름 고래 글라이더와 한 쌍 · 시즌 1 한정)
D.gliders.mintParachute = variant(D.gliders.slimeParachute, { base = "slimeParachute", color = C(150, 230, 210) }) -- 무료 40칸: 민트 낙하산
D.gliders.berryParachute = variant(D.gliders.slimeParachute, { base = "slimeParachute", color = C(150, 124, 230) }) -- 유료 5칸: 베리 낙하산
D.gliders.jadeWing = variant(D.gliders.dragonWing, { base = "dragonWing", color = C(80, 190, 140) }) -- 유료 15칸: 비취 날개
D.gliders.amethystWing = variant(D.gliders.dragonWing, { base = "dragonWing", color = C(150, 100, 210) }) -- 유료 35칸: 자수정 날개
D.themes.starterStar = variant(D.themes.starlight, { core = C(226, 236, 255), edge = C(120, 140, 236), particle = C(244, 248, 255) }) -- QUEUE-ALL9C 1-6 스타터: 짧은 별빛 궤적(대시만)
D.themes.starterStar.dash.lifetime = 0.2 -- "짧은" 궤적(별빛 0.38의 절반 정도)
D.themes.starterStar.dash.width = 1.6
D.items.starCrown = variant(D.items.crown, { base = "crown", color = C(200, 212, 255), gem = C(255, 236, 150) }) -- QUEUE-ALL9B 5 시즌 출석판 32칸: 별빛 왕관(은청 테 + 노란 별 보석)

return D
