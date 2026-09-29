-- A2-N2 2-1 구역 조명 · 분위기 프리셋(ArtStyleV1 스위치 뒤 · 클라 전용 - client/ArtV1ZoneLighting). 끄면 서버가 적용한 CartoonStyleData 프로필 값으로 되돌린다.
--   층 규칙(art-direction §3-1): 배경(하늘 · 먼 곳 = Atmosphere Haze로 채도 · 명도를 누름) < 플레이 바닥(지형 색) < 캐릭터 · 몬스터 < 드랍 · 이펙트(Neon만 번지는 Bloom Threshold ≥ 1.4).
--   값 = Lighting 속성 · Lighting 자식 효과(Atmosphere · CartoonColorCorrection · Bloom - 서버 CartoonStyle이 만든 이름 그대로) · Sky 별 · 해 크기. 색 = {R, G, B}.
--   ClockTime은 서버 관리 밖 속성 - 클라에서만 바꾸고 끌 때 켜기 전 값으로 되돌린다(서버 snapshotUnmanaged는 서버 값만 본다).
--   구역 판정 = WorldMapLayout.inHub / zoneAt(구역 원) - 원 밖(길)은 fallback. 보스전 중(Player Attribute BossEncounterId)에는 전환하지 않는다(보스 연출 우선).
--   지형 재질 색 · 물 = 전역 한 벌이라 서버 프로필(CartoonStyleData artV1.materialColors · terrain)에 둔다. 구역 프리셋의 terrain = 그 구역 안에서만 덮는 재질 색(클라 Terrain:SetMaterialColor - 복제 안 됨 · 다른 구역 · 끄면 프로필 값으로 되돌림).

local function preset(t)
	return t
end

return {
	tweenSeconds = 2.5, -- 구역 진입 전환(부드럽게)
	pollSeconds = 0.5,
	fallback = "hub",

	-- 구역 프리셋: ClockTime · 조명 · Atmosphere · 색 보정 · 블룸 · 하늘(별 수 · 해 크기)
	zones = {
		-- Play 1(A2-N2) 실측 조정: 처음 값(밝기 2.5 ~ 2.8 · 채도 +0.08)은 평면 재질에서 잔디 · 모래 · 보라 바닥이 형광처럼 떠 캐릭터 · 몬스터보다 먼저 보였다 → 밝기 1.9 ~ 2.3 · 채도 ≤ 0 · 안개 두껍게.
		--   해질녘(ClockTime ≥ 17.4)은 몬스터가 안 보이거나(T5) 해가 정면에서 번져(T2) 16.6 이하로.
		-- 허브 큰 나무 마을: 따뜻한 한낮
		hub = preset({
			clock = 14, brightness = 2.2, ambient = { 96, 100, 110 }, outdoor = { 142, 148, 152 }, shiftTop = { 240, 234, 220 },
			atmosphere = { density = 0.16, offset = 0.05, color = { 196, 218, 236 }, decay = { 146, 176, 206 }, haze = 1.0, glare = 0 },
			cc = { brightness = -0.01, contrast = 0.1, saturation = -0.06, tint = { 255, 252, 244 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 11 },
		}),
		-- T1 석조 평원: 맑은 한낮 - 차분한 풀 · 푸른 먼 산
		tier1 = preset({
			clock = 12.5, brightness = 2.1, ambient = { 92, 96, 106 }, outdoor = { 136, 142, 146 }, shiftTop = { 236, 232, 218 },
			atmosphere = { density = 0.2, offset = 0.05, color = { 192, 214, 228 }, decay = { 140, 170, 196 }, haze = 1.2, glare = 0 },
			cc = { brightness = -0.02, contrast = 0.1, saturation = -0.08, tint = { 250, 255, 246 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 11 },
		}),
		-- T2 수정 동굴: 보라 늦은 오후 - 먼 곳은 짙은 보라 안개 · 수정(청록)만 튄다
		tier2 = preset({
			clock = 15.2, brightness = 1.9, ambient = { 104, 100, 120 }, outdoor = { 140, 134, 156 }, shiftTop = { 240, 232, 252 },
			atmosphere = { density = 0.24, offset = 0.1, color = { 150, 130, 196 }, decay = { 96, 76, 150 }, haze = 1.6, glare = 0 },
			cc = { brightness = 0.02, contrast = 0.1, saturation = -0.08, tint = { 248, 244, 255 } },
			bloom = { intensity = 0.5, size = 20, threshold = 1.4 },
			sky = { stars = 0, sun = 6 },
		}),
		-- T3 수몰 사원: 밝은 청록 한낮
		tier3 = preset({
			clock = 12, brightness = 2.2, ambient = { 92, 112, 124 }, outdoor = { 140, 160, 170 }, shiftTop = { 232, 250, 255 },
			atmosphere = { density = 0.16, offset = 0.06, color = { 170, 226, 238 }, decay = { 88, 170, 204 }, haze = 1.0, glare = 0 },
			cc = { brightness = -0.01, contrast = 0.08, saturation = -0.06, tint = { 238, 252, 255 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 11 },
			terrain = { Grass = { 86, 138, 118 }, LeafyGrass = { 72, 122, 108 } }, -- 검토: T3 사냥터가 T1과 같은 잔디라 구역 정체성이 없었다 → 물가 청록 이끼(이 구역 안에서만)
		}),
		-- T4 모래 유적: 오후 - 따뜻한 햇빛 · 모래먼지 원경(해 반사 줄기가 생겨 Glare 0)
		tier4 = preset({
			clock = 14.8, brightness = 2.3, ambient = { 120, 106, 92 }, outdoor = { 178, 160, 134 }, shiftTop = { 255, 226, 182 },
			atmosphere = { density = 0.16, offset = 0.08, color = { 238, 214, 172 }, decay = { 200, 150, 100 }, haze = 1.2, glare = 0 },
			cc = { brightness = 0.01, contrast = 0.1, saturation = -0.06, tint = { 255, 246, 230 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 12 },
		}),
		-- T5 폭풍 첨탑: 먹구름 늦은 오후 - 가장 어둡지만 캐릭터 · 몬스터는 읽히게(환경광 유지)
		tier5 = preset({
			clock = 16.6, brightness = 1.9, ambient = { 112, 114, 142 }, outdoor = { 142, 146, 178 }, shiftTop = { 220, 225, 255 },
			atmosphere = { density = 0.2, offset = 0.12, color = { 132, 136, 170 }, decay = { 70, 70, 120 }, haze = 1.2, glare = 0 },
			cc = { brightness = 0.03, contrast = 0.12, saturation = -0.1, tint = { 236, 238, 255 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 4 },
			-- T5 바닥 = Ground(흙길과 공유 재질). 검토: 회청 바닥 + 남보라 안개 + 파랑 임프가 한 덩어리 → 바닥만 따뜻한 회색(색상 반대쪽)으로 이 구역 안에서만
			terrain = { Ground = { 118, 112, 110 }, Cobblestone = { 88, 84, 86 } },
		}),
		-- T6 빙하 동굴: 차가운 오전 - 눈 과노출을 대비 · 밝기로 누른다
		tier6 = preset({
			clock = 11, brightness = 1.8, ambient = { 104, 114, 134 }, outdoor = { 150, 166, 190 }, shiftTop = { 234, 246, 255 },
			atmosphere = { density = 0.15, offset = 0.06, color = { 210, 232, 250 }, decay = { 156, 198, 236 }, haze = 1.0, glare = 0 },
			cc = { brightness = -0.06, contrast = 0.16, saturation = 0.04, tint = { 242, 250, 255 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 9 },
		}),
	},
}
