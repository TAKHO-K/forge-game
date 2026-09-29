-- A2-N2 2-1 구역 조명 · 분위기 프리셋(ArtStyleV1 스위치 뒤 · 클라 전용 - client/ArtV1ZoneLighting). 끄면 서버가 적용한 CartoonStyleData 프로필 값으로 되돌린다.
--   층 규칙(art-direction §3-1): 배경(하늘 · 먼 곳 = Atmosphere Haze로 채도 · 명도를 누름) < 플레이 바닥(지형 색) < 캐릭터 · 몬스터 < 드랍 · 이펙트(Neon만 번지는 Bloom Threshold ≥ 1.4).
--   값 = Lighting 속성 · Lighting 자식 효과(Atmosphere · CartoonColorCorrection · Bloom - 서버 CartoonStyle이 만든 이름 그대로) · Sky 별 · 해 크기. 색 = {R, G, B}.
--   ClockTime은 서버 관리 밖 속성 - 클라에서만 바꾸고 끌 때 켜기 전 값으로 되돌린다(서버 snapshotUnmanaged는 서버 값만 본다).
--   구역 판정 = WorldMapLayout.inHub / zoneAt(구역 원) - 원 밖(길)은 fallback. 보스전 중(Player Attribute BossEncounterId)에는 전환하지 않는다(보스 연출 우선).
--   지형 재질 색 · 물 = 전역 한 벌이라 서버 프로필(CartoonStyleData artV1.materialColors · terrain)에 둔다.

local function preset(t)
	return t
end

return {
	tweenSeconds = 2.5, -- 구역 진입 전환(부드럽게)
	pollSeconds = 0.5,
	fallback = "hub",

	-- 구역 프리셋: ClockTime · 조명 · Atmosphere · 색 보정 · 블룸 · 하늘(별 수 · 해 크기)
	zones = {
		-- 허브 큰 나무 마을: 따뜻한 한낮(A2-S2 artV1 기준값)
		hub = preset({
			clock = 14, brightness = 2.5, ambient = { 100, 102, 116 }, outdoor = { 158, 160, 172 }, shiftTop = { 255, 240, 220 },
			atmosphere = { density = 0.12, offset = 0.05, color = { 196, 222, 250 }, decay = { 150, 182, 225 }, haze = 0.6, glare = 0 },
			cc = { brightness = 0.02, contrast = 0.08, saturation = 0.08, tint = { 255, 252, 244 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 11 },
		}),
		-- T1 석조 평원: 맑은 아침 - 연두 바닥 · 푸른 먼 산
		tier1 = preset({
			clock = 12.5, brightness = 2.6, ambient = { 100, 106, 112 }, outdoor = { 160, 168, 164 }, shiftTop = { 255, 246, 226 },
			atmosphere = { density = 0.11, offset = 0.05, color = { 200, 228, 240 }, decay = { 146, 190, 214 }, haze = 0.5, glare = 0 },
			cc = { brightness = 0.02, contrast = 0.08, saturation = 0.08, tint = { 250, 255, 246 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 11 },
		}),
		-- T2 수정 동굴: 보라 황혼 - 먼 곳은 짙은 보라 안개 · 수정만 번진다
		tier2 = preset({
			clock = 17.4, brightness = 2.0, ambient = { 104, 90, 136 }, outdoor = { 136, 120, 180 }, shiftTop = { 232, 204, 255 },
			atmosphere = { density = 0.2, offset = 0.1, color = { 150, 122, 208 }, decay = { 86, 60, 150 }, haze = 1.4, glare = 0 },
			cc = { brightness = 0.03, contrast = 0.1, saturation = 0.1, tint = { 242, 234, 255 } },
			bloom = { intensity = 0.5, size = 20, threshold = 1.4 },
			sky = { stars = 2500, sun = 8 },
		}),
		-- T3 수몰 사원: 밝은 청록 한낮 - 물빛 반사 느낌(윗면 청백)
		tier3 = preset({
			clock = 12, brightness = 2.6, ambient = { 92, 112, 124 }, outdoor = { 150, 178, 190 }, shiftTop = { 232, 250, 255 },
			atmosphere = { density = 0.14, offset = 0.06, color = { 170, 230, 242 }, decay = { 88, 170, 204 }, haze = 0.9, glare = 0 },
			cc = { brightness = 0.02, contrast = 0.08, saturation = 0.06, tint = { 238, 252, 255 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 11 },
		}),
		-- T4 모래 유적: 늦은 오후 - 주황 햇빛 · 모래먼지 원경
		tier4 = preset({
			clock = 15.8, brightness = 2.8, ambient = { 120, 106, 92 }, outdoor = { 178, 160, 134 }, shiftTop = { 255, 226, 182 },
			atmosphere = { density = 0.16, offset = 0.08, color = { 238, 214, 172 }, decay = { 200, 150, 100 }, haze = 1.2, glare = 0.2 },
			cc = { brightness = 0.01, contrast = 0.1, saturation = 0.05, tint = { 255, 246, 230 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 14 },
		}),
		-- T5 폭풍 첨탑: 먹구름 해질녘 - 가장 어둡지만 캐릭터는 읽히게(Ambient 유지)
		tier5 = preset({
			clock = 17.9, brightness = 1.8, ambient = { 92, 94, 126 }, outdoor = { 120, 124, 164 }, shiftTop = { 204, 206, 255 },
			atmosphere = { density = 0.24, offset = 0.14, color = { 112, 112, 152 }, decay = { 60, 60, 110 }, haze = 2, glare = 0 },
			cc = { brightness = 0.02, contrast = 0.12, saturation = -0.02, tint = { 236, 238, 255 } },
			bloom = { intensity = 0.5, size = 20, threshold = 1.4 },
			sky = { stars = 1500, sun = 6 },
		}),
		-- T6 빙하 동굴: 차가운 맑은 오전 - 눈 반사로 밝지만 대비를 올려 흰 과노출 방지
		tier6 = preset({
			clock = 11, brightness = 2.3, ambient = { 112, 122, 142 }, outdoor = { 168, 184, 208 }, shiftTop = { 234, 246, 255 },
			atmosphere = { density = 0.15, offset = 0.06, color = { 210, 232, 250 }, decay = { 156, 198, 236 }, haze = 1.0, glare = 0 },
			cc = { brightness = -0.02, contrast = 0.1, saturation = 0.02, tint = { 242, 250, 255 } },
			bloom = { intensity = 0.4, size = 18, threshold = 1.5 },
			sky = { stars = 0, sun = 9 },
		}),
	},
}
