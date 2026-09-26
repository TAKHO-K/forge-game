-- M1-4 길(사용자: 직각 도로 → 구역 테마 시골 커브길 · 지형 높이를 따라가는 길 · Terrain 재질 띠 · 갈림길 표지판). 식 = shared/RoadNet(순수 · 결정적).
-- 길목(허브 끝 → 결계 문 → 캠프 → 사냥 지대 1 · 2 · 3 → 관문)은 그대로(WorldMapLayout.route - 길 안내 · 거리 표 id) - 그 사이를 곡선(Catmull-Rom) + 구불거림(사인 · 길목 근처 0)으로 잇는다.
-- 높이 = 자연 지형(TerrainShape.naturalAt)을 폭 방향 평균 → 창(smoothStuds) 평균 → 캠프 · 사냥 지대 · 관문 근처는 평지로 → 경사 상한(designGradeDeg - 앞뒤 두 번 깎기).
-- 길 = 파트가 아니라 **Terrain 재질 띠**(구역마다 흙 · 자갈) - 지형 굽기가 칠한다. 길 모양을 바꾸면 모든 구역 TerrainGenData.version을 올리고 다시 굽는다.
return {
	half = 7, -- 길 반폭(재질 띠 = 14)
	shoulder = 3, -- 띠 밖 맞춤 폭(길 높이로 맞추는 가장자리)
	blend = 24, -- 그 밖에서 원래 지형으로
	step = 8, -- 곡선 표본 간격
	smoothStuds = 56, -- 높이 창 평균 길이
	designGradeDeg = 12, -- 설계 경사 상한(걷기 편하게) · 검사 상한 = capGradeDeg
	capGradeDeg = 25, -- 사용자: 경사 상한 약 25°
	-- 길목 둘레 곧은 반경(구불거림 0 · 높이 = 평지): 캠프 · 사냥 지대 · 관문 판과 맞물린다
	clearAt = { hubEdge = 30, barrierGate = 40, camp = 70, ground = 130, gate = 80, landmark = 50, shore = 40 },
	flatAt = { barrierGate = 30, camp = 70, ground = 150, gate = 90, shore = 24 }, -- 이 반경 안은 평지(평탄 마스크와 같은 값 - TerrainGenData.flatten)
	-- 막힘 회피(구불거림을 줄여 비껴간다): 둥지 받침 · 옛 지형 · 구조물 + 여유
	avoidMargin = 18, nestAvoid = 26, -- nestAvoid = 둥지 자리(구역 좌표) 둘레 반경
	taperStuds = 80, -- 길목 곧은 반경 밖에서 구불거림이 다 커지기까지
	-- 구역 스타일: amp = 구불거림 폭 · lambda = 파장 · material = 길 재질(흙 · 자갈) · edge = 가장자리 재질(없으면 같음)
	zones = {
		tier1 = { amp = 34, lambda = 230, material = "Ground" }, -- 초원 흙길
		tier2 = { amp = 26, lambda = 170, material = "Asphalt" }, -- 어두운 자갈길(수정 동굴)
		tier3 = { amp = 30, lambda = 210, material = "Mud" }, -- 물가 진흙길
		tier4 = { amp = 44, lambda = 300, material = "Salt" }, -- 모래 위 다진 밝은 길(길게 휘어짐 - 사암은 비탈 재질이라 안 쓴다)
		tier5 = { amp = 30, lambda = 140, material = "Limestone" }, -- 폭풍 지대 밝은 돌길(잦은 굽이 - 자갈은 비탈 재질)
		tier6 = { amp = 24, lambda = 180, material = "Ground" }, -- 눈 위 흙길
	},
	-- 갈림길: 관문 → 랜드마크(사용자: 허브 → 구역 입구 → 관문 → 랜드마크 연결) · 표지판 = 갈림길 · 캠프
	landmarkBranch = { fromBeforeGate = 140, midR = 20, midLat = 80, forkClear = 20, midClear = 30 }, -- 관문 앞 이만큼에서 갈라져 랜드마크로(가운데 점 = 관문 반경 + midR · 옆 midLat)
	sign = { height = 7, labelMaxDistance = 160, offset = 4 }, -- offset = 길 가장자리에서 표지판까지
}
