-- 클래스별 무기 실제 형태(14-2 재작업). 1차 버전(회색 블록 하나)이 저퀄리티라는 피드백을
-- 받고 무료 크리에이터 스토어 에셋으로 교체한다.
--
-- 코드로 재현 가능한 것만 가져왔다 - 이유: 이 프로젝트는 Rojo가 파일만 Studio에
-- 반영한다(CLAUDE.md) - Studio에 직접 삽입한 에셋 인스턴스는 다음 Rojo 동기화에서
-- 그대로 사라진다(파일로 존재하지 않으므로). 그래서 MeshPart.MeshId·SpecialMesh.MeshId
-- 처럼 순수 문자열 프로퍼티로 참조 가능한 것만 쓴다 - UnionOperation(CSG로 구운
-- 지오메트리, 코드로 재현 불가)이 핵심 형태인 에셋은 후보에서 제외했다("Simple Sword"가
-- 이래서 탈락 - 칼날이 Union이었다). 활은 애초에 순수 Part 조합이라 원본 에셋의 실측
-- 좌표를 그대로 옮기면 에셋 참조 자체가 필요 없다.
--
-- 출처(전부 Creator Store 무료 등록 에셋 - search_asset priceFilter=free로 확인 후
-- 삽입, 판매 등록 자체가 "누구나 자신의 게임에 넣어 쓸 수 있다"는 조건이다):
--   - 대검·쌍검 칼날: "Dual Bronze Sword"(barbariandon), assetId 18113548241의
--     Handle 메시(rbxassetid://12221720) - 대검엔 크게, 쌍검엔 작게 재사용한다(같은
--     칼날 메시를 스케일만 다르게 쓰는 건 흔한 재사용 기법이라 문제 삼지 않는다).
--   - 활: "Simple Bow Weapon Archery Arrow Fantasy"(Dawn_Flame201657), assetId
--     125666435239922 - 전부 Part(Cylinder)라 좌표만 그대로 옮겼다.
--   - 지팡이: "garnet staff"(camtii11), assetId 11472500의 Handle 메시
--     (rbxassetid://10757531 + 텍스처 10890584) - Tool로 딸려온 스크립트·파티클
--     (Sparkles)은 가져오지 않는다, 메시 하나만 쓴다.

-- 그립 방향 규칙(실제 플레이 확인 버그 - "대검을 반대로 들고 있다" - 를 고치며 확정) :
-- 무기의 로컬 좌표계에서 그립(자루)은 원점 부근에 있고, gripOffset의 회전이 0이라면
-- 날/촉 끝은 로컬 +Z를 향해야 한다. hand.CFrame은 대기 자세에서 로컬 +Y가 대략 월드
-- 위쪽이므로(UpVector 실측 확인), 무기가 위를 향해 들리게 하려면 gripOffset에 X축
-- -90도 회전을 얹어 로컬 +Z를 로컬 +Y로 옮긴다.
-- 이 축을 두 번 잘못 짚었다 - 처음엔 로컬 Y로 추측만 했고(trailTop/trailBottom을
-- Y로 뒀었다), Edit 모드 좌표축 마커 실측 후 "로컬 -Z"로 결론 냈다가 그 부호도 틀렸다
-- (실제 장착된 무기에 마커를 직접 붙여 캐릭터 팔과 헷갈린 걸 재확인하고 나서야 +Z가
-- 맞다는 걸 확인했다). 재현되는 버그를 그럴듯한 설명으로 덮지 않고(CLAUDE.md) 매번
-- 실측으로 재확인한 끝에 얻은 결론이다 - 지팡이(healer) 메시는 이미 로컬 Y가 날(지팡이
-- 머리) 방향이라 손대지 않았다(같은 방식으로 실측 확인).
local GREATSWORD_GRIP_ROTATION = CFrame.Angles(math.rad(-90), 0, 0)

return {
	greatsword = {
		kind = "mesh",
		meshId = "rbxassetid://12221720",
		size = Vector3.new(1.3, 5.5, 0.4),
		color = Color3.fromRGB(180, 182, 192),
		gripOffset = CFrame.new(0.15, -0.1, -0.1) * GREATSWORD_GRIP_ROTATION,
		trailTop = Vector3.new(0, 0, 2.6), -- 칼끝(로컬 +Z 방향) - Trail 두 Attachment 중 하나
		trailBottom = Vector3.new(0, 0, 0.3), -- 칼밑(가드 근처)
	},

	dualblade = {
		kind = "mesh_pair",
		meshId = "rbxassetid://12221720",
		size = Vector3.new(0.5, 2.0, 0.18),
		color = Color3.fromRGB(205, 232, 232),
		-- 같은 메시라 그립 방향 규칙도 greatsword와 같다. 손 배정(hand)을 부위별로 명시한다 -
		-- 예전엔 둘 다 RightHand였다("젓가락질" 버그의 원인) - WeaponVisual.lua가 이 필드로
		-- RightHand/LeftHand를 갈라 붙인다.
		parts = {
			{ name = "BladeLeft", hand = "LeftHand", gripOffset = CFrame.new(-0.05, -0.05, -0.05) * GREATSWORD_GRIP_ROTATION },
			{ name = "BladeRight", hand = "RightHand", gripOffset = CFrame.new(0.05, -0.05, -0.05) * GREATSWORD_GRIP_ROTATION },
		},
		trailTop = Vector3.new(0, 0, 0.95),
		trailBottom = Vector3.new(0, 0, 0.1),
	},

	bow = {
		kind = "bow",
		color = Color3.fromRGB(160, 132, 79),
		-- 원본 활의 곡선은 X-Z 평면에 눕혀 있었다(활을 손에 쥐면 세로로 서야 하니
		-- Z축으로 90도 돌려 세운다 - X 스프레드가 Y 세로축이 된다).
		gripOffset = CFrame.new(0.35, 0, -0.3) * CFrame.Angles(0, 0, math.rad(90)),
		-- 활 몸체를 이루는 나무 마디 7개 - "Simple Bow Weapon Archery Arrow Fantasy" 원본의
		-- 실측 좌표(피벗 기준 상대 위치·Y축 회전) 그대로. 처음엔 Z축 회전으로 잘못 옮겨서
		-- (JSON 직렬화가 키 순서를 뒤섞어 표시해 rx/ry/rz를 착각했다) 활 모양이 뒤죽박죽
		-- 나왔었다 - 진단용 모션 스트립 스크린샷으로 발견하고 바로잡았다.
		limbs = {
			{ size = Vector3.new(1.0095, 0.2524, 0.2524), relPos = Vector3.new(-0.9161, 0.0151, -0.5650), relRotYDeg = 15 },
			{ size = Vector3.new(1.0095, 0.2524, 0.2524), relPos = Vector3.new(-1.8146, 0.0151, -0.1915), relRotYDeg = 30 },
			{ size = Vector3.new(1.0625, 0.3028, 0.3180), relPos = Vector3.new(0.0038, 0, -0.6735), relRotYDeg = 0 },
			{ size = Vector3.new(1.0095, 0.2524, 0.2524), relPos = Vector3.new(0.9540, 0.0151, -0.5474), relRotYDeg = -15 },
			{ size = Vector3.new(1.0095, 0.2524, 0.2524), relPos = Vector3.new(1.8095, 0.0151, -0.1991), relRotYDeg = -30 },
			{ size = Vector3.new(1.0095, 0.2524, 0.2524), relPos = Vector3.new(-2.5616, 0.0151, 0.3788), relRotYDeg = 45 },
			{ size = Vector3.new(1.0095, 0.2524, 0.2524), relPos = Vector3.new(2.5616, 0.0151, 0.3763), relRotYDeg = -45 },
		},
		-- 시위 양 끝(원본 활의 시위 파트 실측 끝점, relPos±size.X/2) - 이 세션에서 시위를
		-- 고정 직선 하나에서 "두 끝 고정 + 중간(nock) 이동"으로 바꿔서 당기는 게 보이게 했다.
		stringTopTip = Vector3.new(2.87, 0, 0.7347),
		stringBottomTip = Vector3.new(-2.87, 0, 0.7347),
		stringRestNock = Vector3.new(0, 0, 0.7347),
		stringThickness = 0.05,
		stringColor = Color3.fromRGB(235, 235, 235),
		arrowSize = Vector3.new(0.06, 0.06, 1.5),
		arrowColor = Color3.fromRGB(200, 180, 140),
	},

	healer = {
		kind = "specialmesh",
		meshId = "rbxassetid://10757531",
		textureId = "rbxassetid://10890584",
		size = Vector3.new(1, 1, 5.6),
		color = Color3.fromRGB(215, 200, 235),
		gripOffset = CFrame.new(0.15, -0.1, -0.15),
	},
}
