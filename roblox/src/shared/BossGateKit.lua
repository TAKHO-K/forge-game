-- M1-4 보스 관문 = 공통 틀 + 보스별 장식 모듈(사용자: 신규 보스 재사용 · 카툰 교체 대비). 순수(도형 명세만) - 부르는 곳 = WorldMapLayout.buildBossGates.
--   공통 틀(모든 보스 같음 - 판정 · 등록 표시가 여기 묶여 있다): 계단 받침 · 기둥(밑동 · 몸통 · 머리) · 들보 + 박공 + 쐐기돌 · 안쪽 빛 테 · 빛 막 ·
--     문양(GateEmblem - 등록 전 꺼짐 / 뒤 켜짐 = 클라 BossGateMarks) · 발판(BossGate · BossId - 밟으면 입장) · 등록 프롬프트 자리(PromptAnchor · GatePrompt) · 빛기둥(GatePillars · Persistent).
--   장식 모듈(DECOR[style] - BossData gate.style · 없으면 default): 틀 위에 얹는 모양만(판정 없음 · 충돌 없음이 원칙). 새 보스 = style 하나 추가 또는 default.
--   카툰 교체: 틀 모양은 이 파일 · 장식은 Gate_<style>_* 소품으로 옮길 수 있다(docs/art/asset-pipeline.md §1-4).
-- 로컬 좌표: cf = 관문 바닥 가운데(flatYaw) · −Z = 바깥(관문이 보는 쪽) · +Z = 허브 쪽(프롬프트 · 등록하는 사람) · +X = 오른쪽.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local Kit = {}
local D = WorldMapData

local function mul(c, k)
	return { math.floor(math.clamp(c[1] * k, 0, 255)), math.floor(math.clamp(c[2] * k, 0, 255)), math.floor(math.clamp(c[3] * k, 0, 255)) }
end
local function mix(a, b, t)
	return { math.floor(a[1] + (b[1] - a[1]) * t), math.floor(a[2] + (b[2] - a[2]) * t), math.floor(a[3] + (b[3] - a[3]) * t) }
end
Kit.mul, Kit.mix = mul, mix

-- 공통 틀. prim = WorldMapLayout 도형 함수(list, model, name, size, cf, color, opts). 반환 dims(장식이 쓰는 치수)
function Kit.frame(list, prim, g, cf)
	local G = D.bossGate
	local L = D.layout
	local model = "BossGate_" .. g.bossId
	local half = G.width / 2
	local H, P, BEAM = G.height, G.postSize, G.beam
	local color = g.color
	local dark = mul(color, 0.42)
	local stone = mix(mul(color, 0.3), { 120, 118, 124 }, 0.55) -- 돌(보스 색이 살짝 스민 회색)
	local stoneLight = mix(stone, { 200, 198, 204 }, 0.35)
	local mat = { material = "Slate" }
	-- 계단 받침(두 단 · 기둥 밑과 문 앞 · 발판은 그 위에 얹힌다)
	prim(list, model, "GateStep", Vector3.new(G.width + P + 16, 1.2, P + 14), cf * CFrame.new(0, 0.1, 0), stone, mat)
	prim(list, model, "GateStep", Vector3.new(G.width + P + 8, 1.2, P + 8), cf * CFrame.new(0, 1.0, 0), stoneLight, mat)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * half
		prim(list, model, "BossGatePostBase", Vector3.new(P + 4, 4, P + 4), cf * CFrame.new(x, 3.6, 0), stone, mat)
		prim(list, model, "BossGatePost", Vector3.new(P, H - 5, P), cf * CFrame.new(x, 1.6 + (H - 1.6) / 2 + 1, 0), dark, { material = "SmoothPlastic" })
		prim(list, model, "BossGatePostBand", Vector3.new(P + 1.2, 1.6, P + 1.2), cf * CFrame.new(x, H * 0.55, 0), stoneLight, mat)
		prim(list, model, "BossGateCapital", Vector3.new(P + 3, 3, P + 3), cf * CFrame.new(x, H - 0.5, 0), stone, mat)
		-- 기둥 안쪽 모서리 빛 테(보스 색 - 늘 켜짐 · 아치 윤곽)
		prim(list, model, "BossGateTrim", Vector3.new(1.2, H - 6, 1.2), cf * CFrame.new(sx * (half - P / 2 - 0.6), 3 + (H - 6) / 2, P / 2 + 0.2), color, { collide = false, neon = true })
	end
	-- 들보 · 박공(삼각 지붕 - 쐐기 두 개) · 쐐기돌
	local beamY = H + BEAM / 2 + 1
	prim(list, model, "BossGateTop", Vector3.new(G.width + P + 8, BEAM, P + 3), cf * CFrame.new(0, beamY, 0), dark, { material = "SmoothPlastic" })
	prim(list, model, "BossGateCornice", Vector3.new(G.width + P + 12, 1.4, P + 5), cf * CFrame.new(0, beamY + BEAM / 2 + 0.7, 0), stoneLight, mat)
	local gableH, gableW = 11, (G.width + P + 10) / 2
	for _, sx in ipairs({ -1, 1 }) do
		-- 쐐기: 높은 쪽 = 가운데(로컬 −Z가 높은 면이 되도록 돌린다)
		prim(list, model, "BossGateGable", Vector3.new(P + 2, gableH, gableW), cf * CFrame.new(sx * gableW / 2, beamY + BEAM / 2 + 1.4 + gableH / 2, 0) * CFrame.Angles(0, math.rad(-sx * 90), 0),
			stone, { material = "Slate", shape = "Wedge" })
	end
	local keyY = beamY + BEAM / 2 + 1.4 + gableH * 0.45
	prim(list, model, "BossGateKeystone", Vector3.new(G.emblem + 4, G.emblem + 4, P + 3), cf * CFrame.new(0, keyY, 0) * CFrame.Angles(0, 0, math.rad(45)), dark, { material = "SmoothPlastic" })
	-- 문양(허브 쪽 면 = 로컬 +Z): 마름모 + 가로 띠 - 등록 전 꺼짐 · 뒤 켜짐(클라)
	prim(list, model, "BossGateEmblem", Vector3.new(G.emblem, G.emblem, 1), cf * CFrame.new(0, keyY, P / 2 + 2.2) * CFrame.Angles(0, 0, math.rad(45)), color,
		{ collide = false, neon = true, attrs = { GateEmblem = g.bossId } })
	prim(list, model, "BossGateEmblem", Vector3.new(G.width * 0.7, 1.4, 1), cf * CFrame.new(0, beamY, P / 2 + 1.9), color,
		{ collide = false, neon = true, attrs = { GateEmblem = g.bossId } })
	prim(list, model, "BossGateTrim", Vector3.new(G.width - P, 1.2, 1.2), cf * CFrame.new(0, H - 1.2, P / 2 + 0.2), color, { collide = false, neon = true })
	-- 안쪽 빛 막(문 안 - 통과 · 흐릿하게)
	prim(list, model, "BossGateVeil", Vector3.new(G.width - P, H - 3, 0.4), cf * CFrame.new(0, 2 + (H - 3) / 2, 0), color, { collide = false, neon = true, transparency = 0.8 })
	-- 발판(밟으면 입장 - 서버 거리 폴링) · 등록 프롬프트 자리(허브 쪽 · 발판 반경 밖)
	local base = cf.Position
	prim(list, model, "BossGatePad", Vector3.new(0.4, L.gate.radius * 2, L.gate.radius * 2), CFrame.new(base.X, base.Y + 0.45, base.Z) * CFrame.Angles(0, 0, math.rad(90)), color,
		{ shape = "Cylinder", material = "SmoothPlastic", attrs = { BossGate = g.zoneKey or g.bossId, BossId = g.bossId } })
	prim(list, model, "PromptAnchor", Vector3.new(2, 2, 2), cf * CFrame.new(0, 5, G.promptOffset), color, { collide = false, transparency = 1, attrs = { GatePrompt = g.bossId } })
	-- 빛기둥(Persistent · 보스 색 - 등록 전 흐리게 깜빡 · 뒤 밝게 꾸준히 = 클라)
	local PL = D.gatePillar
	prim(list, "GatePillars", "GatePillar", Vector3.new(PL.width, PL.height, PL.width), CFrame.new(base.X, base.Y + PL.height / 2, base.Z), color,
		{ collide = false, neon = true, transparency = PL.transparency, attrs = { GatePillar = g.zoneKey or g.bossId, BossId = g.bossId } })
	return { model = model, half = half, H = H, P = P, beamY = beamY, keyY = keyY, gableH = gableH, color = color, dark = dark, stone = stone, stoneLight = stoneLight }
end

-- ─────────────────────────── 보스별 장식(충돌 없음 · 모양만) ───────────────────────────
local DECOR = {}
Kit.decor = DECOR

-- 기본: 기둥 앞 깃발 두 장(보스 색)
function DECOR.default(list, prim, g, cf, d)
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, d.model, "GateBanner", Vector3.new(4, 14, 0.3), cf * CFrame.new(sx * d.half, d.H * 0.6, d.P / 2 + 0.6), mul(d.color, 0.8), { collide = false, material = "Fabric" })
	end
end

-- 심해 군주: 산호 뿔 · 물결 볏 · 조개 문양 테 · 해초 - 수몰 사원 맵 색(짙은 청록 → 밝은 청록 타일)
function DECOR.abyss(list, prim, g, cf, d)
	local teal, tealLight, coral = { 60, 150, 160 }, { 120, 210, 210 }, { 230, 120, 140 }
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * d.half
		-- 산호 뿔(기둥 머리에서 비스듬히 두세 가닥)
		for k, spec in ipairs({ { 1.2, 10, 25 }, { 1, 7, -20 }, { 0.8, 6, 50 } }) do
			prim(list, d.model, "GateCoral", Vector3.new(spec[1], spec[2], spec[1]), cf * CFrame.new(x + sx * (k - 1) * 1.5, d.H + spec[2] / 2 - 0.5, (k - 2) * 1.8) * CFrame.Angles(math.rad(spec[3] * 0.4), 0, math.rad(-sx * spec[3])),
				k == 2 and coral or tealLight, { collide = false, material = "SmoothPlastic" })
		end
		-- 해초(기둥 밑 - 늘어진 가닥)
		for k = 1, 3 do
			prim(list, d.model, "GateSeaweed", Vector3.new(0.5, 6 + k * 1.5, 0.5), cf * CFrame.new(x + (k - 2) * 2.2, 5 + k, d.P / 2 + 2.6) * CFrame.Angles(0, 0, math.rad((k - 2) * 12)), { 50, 120, 90 }, { collide = false, material = "Grass" })
		end
	end
	-- 물결 볏(박공 위 - 세 겹 곡선 흉내: 기울인 판)
	for k = -2, 2 do
		prim(list, d.model, "GateWave", Vector3.new(6, 1.2, 2), cf * CFrame.new(k * 6, d.keyY + d.gableH * 0.55 - math.abs(k) * 2.2, 0) * CFrame.Angles(0, 0, math.rad(-k * 14)), k % 2 == 0 and tealLight or teal, { collide = false, material = "SmoothPlastic" })
	end
	-- 쐐기돌 둘레 조개 테(부채꼴 판 5)
	for k = -2, 2 do
		prim(list, d.model, "GateShell", Vector3.new(1.4, 7, 0.6), cf * CFrame.new(0, d.keyY, d.P / 2 + 1.4) * CFrame.Angles(0, 0, math.rad(k * 26)) * CFrame.new(0, 4.5, 0), tealLight, { collide = false, material = "SmoothPlastic" })
	end
end

-- 폭풍 군주: 피뢰 뿔(가는 금속 막대) · 톱니 번개 무늬(지그재그 판) · 노란 전기 줄(보스맵 "회청 금속 + 노란 전기 줄") - 위험색(빨강 · 주황) 없음
function DECOR.storm(list, prim, g, cf, d)
	local metal, yellow = { 150, 160, 180 }, { 255, 236, 110 }
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * d.half
		prim(list, d.model, "GateRod", Vector3.new(0.8, 14, 0.8), cf * CFrame.new(x, d.H + 8, 0), metal, { collide = false, material = "Metal" })
		prim(list, d.model, "GateRodTip", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(x, d.H + 15.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), metal, { collide = false, material = "Metal" })
		-- 기둥 면 지그재그 전기 줄(노란 네온 · 가늘게)
		for k = 0, 3 do
			local y = 8 + k * 7
			prim(list, d.model, "GateBolt", Vector3.new(0.5, 7.6, 0.5), cf * CFrame.new(x + ((k % 2 == 0) and 1.4 or -1.4), y + 3.5, d.P / 2 + 0.4) * CFrame.Angles(0, 0, math.rad((k % 2 == 0) and 22 or -22)), yellow, { collide = false, neon = true })
		end
	end
	-- 박공 위 톱니 볏(삼각 판 5 - 폭풍 첨탑 실루엣)
	for k = -2, 2 do
		local h = 7 - math.abs(k) * 1.5
		prim(list, d.model, "GateSpike", Vector3.new(2, h, 2), cf * CFrame.new(k * 5, d.keyY + d.gableH * 0.5 + h / 2 - math.abs(k) * 2.2, 0) * CFrame.Angles(0, math.rad(45), 0), d.dark, { collide = false, material = "Slate" })
	end
end

-- 틀 + 장식
function Kit.build(list, prim, g, cf)
	local d = Kit.frame(list, prim, g, cf)
	local fn = DECOR[g.style or "default"] or DECOR.default
	fn(list, prim, g, cf, d)
	return d
end

return Kit
