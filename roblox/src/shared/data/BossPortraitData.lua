-- UI-1 3단계 보스 초상(08 v5-auto-boss §5): 보스 id → 그림(ArtAssetIds 키) · 대표 색. 판(원 · UIGradient · UIStroke)은 UI가 그린다 - 그림에 테 · 바탕 없음.
--   form2 = 2폼 그림 · 색(폭풍 군주만) · 새 보스 = 줄 추가(그림 없으면 대표 색 원만).
return {
	bosses = {
		section_guardian = { image = "ui/boss/boss-portrait-guardian", color = "7B5CC4" },
		crystal_queen = { image = "ui/boss/boss-portrait-crystal", color = "B48BE8" },
		abyssal_lord = { image = "ui/boss/boss-portrait-abyssal", color = "3FB5B0" },
		scorpion_queen = { image = "ui/boss/boss-portrait-scorpion", color = "E0A245" },
		storm_lord = { image = "ui/boss/boss-portrait-storm", color = "5B8BFF", form2 = { image = "ui/boss/boss-portrait-storm2", color = "8FE6FF" } },
		frost_giant = { image = "ui/boss/boss-portrait-mammoth", color = "8FD8FF" },
	},
	fallbackColor = "8FD8FF",
	dark = 0.35, -- 원 바깥 = 대표 색 × 이 밝기(UIGradient 가운데 → 바깥)
	-- 크기(§5): 진입 카드 PC 300 · 폰 132 · 도감 줄 머리 64 · 첫 만남 56 · 잔류 88 / 48 · 2폼 카드 140
	size = { intro = { pc = 300, phone = 132 }, codex = 64, firstMeet = { pc = 56, phone = 36 }, linger = { pc = 88, phone = 48 }, form2 = { pc = 140, phone = 72 } },
	-- §6 진입 카드
	intro = { pc = { left = 120, bottom = 150, corner = 48, name = 64, top = 18, form = 30, loadW = 180 }, phone = { left = 40, bottom = 60, corner = 20, name = 30, top = 12, form = 22, loadW = 110 },
		foldAfter = 1.6, maxHold = 5, foldSeconds = 0.3 },
	-- §7 2폼 카드
	form2 = { y = { pc = 190, phone = 130 }, seconds = 2.5, stroke = 3 },
	-- §8 첫 만남 카드
	firstMeet = { bg = "161A2B", bgTransparency = 0.04, stroke = "3A4466", topLine = 6 },
}
