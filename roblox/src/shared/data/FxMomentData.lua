-- QUEUE-ALL2 P4 1순위 ⑥ · 2순위 연출 수치(docs/visual-audit.md 3-1 ⑥⑦ · 3-2). 판정 없음 - 클라 그리기 전용 · 전부 ArtStyleV1 스위치 뒤.
--   세기 = 값 × LocalPlayer FxScale(보통 1 · 약 0.5 · 끔 0 = 꾸밈 연출 없음) · ReduceFlashes = 흰 번쩍 · 광택 스윕 없음.
--   시간 규칙(09 B-2): 일반 ≤ 0.6초 · 클라이맥스 ≤ 2.5초 · 배너 ≤ 3초. 흔들림은 client/CameraShake 한 통로(3초 규칙).
local C = Color3.fromRGB
local TRANS = require(script.Parent.ItemVisualData).gradeVisuals.transcendent -- QUEUE-ALL9C 2-2 초월 금 = 등급 색 한 곳

return {
	-- 상단 가운데 배너 한 줄(client/FxMoment): 중앙 금지 구역(40% × 50%) 위 · ScreenMap TC bossBar 자리(아트 켬이면 보스바는 아래로 가서 비어 있다)
	banner = {
		top = 12, height = 44, width = 360, -- 위 끝 12 · 아래 끝 56(bossBar 슬롯 52와 같은 선 - 폰 388 높이의 금지 구역 위 끝 97보다 위)
		inSeconds = 0.18, outSeconds = 0.25, popScale = 1.15, -- 들어올 때 1.15 → 1(Back)
		shineSeconds = 0.45, -- 광택 한 번 지나감(ReduceFlashes = 없음)
		displayOrder = 40, -- HUD 위 · 창(UIManager window)보다 아래
		styles = {
			stamp = { seconds = 1.0, bg = C(28, 10, 10), bgTransparency = 0.15, rim = C(255, 196, 70), text = C(255, 236, 200), textSize = 30, popScale = 1.6 }, -- 보스 처치 도장
			trans = { seconds = 3.0, bg = C(16, 13, 10), bgTransparency = 0.05, rim = TRANS.border, text = TRANS.text, sub = C(200, 186, 150), textSize = 22 }, -- 초월 세트 줄(TranscendentData.banner 흑금)
			line = { seconds = 2.5, bg = C(40, 30, 10), bgTransparency = 0.2, rim = C(240, 180, 41), text = C(255, 222, 120), sub = C(230, 220, 200), textSize = 20 }, -- 줄 칭호
			cell = { seconds = 1.6, bg = C(18, 22, 30), bgTransparency = 0.2, rim = C(120, 200, 140), text = C(235, 245, 235), textSize = 16, height = 36, width = 300, picture = 30 }, -- 도감 칸 완성(작게)
		},
	},

	-- 보스 처치 도장(BossLingerClient): 잔류 신호 뒤 stampDelay초에 도장 → 도장이 끝난 뒤(windowDelay초) 잔류 창. 서버 남은 초는 그대로(창만 늦게 연다)
	bossStamp = { stampDelay = 0.6, windowDelay = 1.6, sound = "boss_death" },

	-- 강화 22강 이상 → 12강 초기화(ArtV1View playFail reset): 하락보다 무겁게 - 무기 빛이 떨어져 꺼짐 · 쇳조각 2배 · 어두운 링 1.5배 · 채도 빠짐(밝기 변화 없음 = 번쩍임 아님)
	enhanceReset = {
		pieces = 16, pieceSpeed = 11, pieceSize = 0.45, pieceColor = C(120, 118, 132),
		shards = 6, shardColor = C(230, 196, 120), shardSize = 0.3, shardSpeed = 14, -- 금빛 파편(무기 빛이 깨짐)
		ringScale = 1.5, ringSeconds = 0.9,
		glow = { size = 1.4, color = C(255, 200, 90), dropStuds = 2.2, seconds = 0.7 }, -- 모루 위 무기 빛 공이 떨어지며 어두워짐
		desaturate = { saturation = -0.5, seconds = 0.4, holdSeconds = 0.15 }, -- ColorCorrection Saturation(밝기 0)
		shake = { seconds = 0.35, studs = 0.3 }, -- CameraShake climax(설정 "화면 흔들림" 끔 = 없음)
	},

	-- 강화 패널(panels/Enhance/ResultFx)
	enhancePanel = {
		successPop = { scale = 1.25, seconds = 0.25 }, -- 단계 숫자 팝(Back)
		resultPop = { scale = 1.15, seconds = 0.15 }, -- 결과 줄 확대
		failRoll = { seconds = 0.4 }, -- 하락: 제목 단계 숫자가 굴러 내려감
		resetRoll = { seconds = 0.8 }, -- 초기화: 22 → 12 굴림
		failShake = { pixels = 6, seconds = 0.2, cycles = 3 }, -- 결과 줄 좌우 흔들기(UI만 · 카메라 아님)
		shield = { color = C(110, 180, 255), size = 5.5, seconds = 0.5, thick = 0.14 }, -- 방지권 방패 링(모루 위 · 3D)
		ticketPop = { scale = 1.08, seconds = 0.25 }, -- 방지권 줄(전체 폭)이라 작게
	},

	-- 레벨업(LevelHud · ExpBar)
	levelUp = {
		chipPop = { scale = 1.3, seconds = 0.3 },
		rimFlash = C(255, 250, 220), -- 칩 테두리 잠깐 밝게(ReduceFlashes = 없음)
		sweep = { seconds = 0.3, width = 0.18, transparency = 0.35 }, -- 경험치바: 가득 → 0 흰 스윕
	},

	-- 내 체력바 잔상(PlayerHealthBar): 보스바 lag와 같은 방식(ArtV1UiData.hud.bossBar lagHoldSeconds · lagSeconds와 같은 값)
	hpLag = { holdSeconds = 0.4, seconds = 0.45, color = C(255, 255, 255), transparency = 0.35, minDelta = 0.01 },

	-- 도감(CodexMoments)
	codex = {
		cellBatchSeconds = 0.6, -- 이 안에 완성된 칸은 한 장으로 묶음("외 n")
		firstViewDelay = 6, retryViewSeconds = 12, -- 접속 뒤 기준 표를 받으려 한 번 "view" 요청(도감 창과 같은 요청)
		lineRing = { size = 9, seconds = 0.6, color = C(240, 180, 41) }, -- 줄 칭호 발밑 금 링
		transRing = { size = 12, seconds = 0.9, color = TRANS.border, innerColor = C(16, 13, 10) }, -- 초월 줄 발밑 흑금 링 2겹
	},

	-- 장비 줍기 빛 구슬(PickupOrb): 드랍 자리(화면 투영) → 가방 버튼
	pickupOrb = {
		minGrade = 3, -- ArmorData.gradeOrder 순번(3 = 영웅) 이상만
		seconds = 0.4, size = 18, arcPixels = 60, -- 위로 휘는 곡선
		matchSeconds = 0.6, -- 줍기 신호와 드랍 모델 사라짐을 짝짓는 창
		maxLive = 4, -- 동시에 나는 구슬 상한(폰 부담)
		arrivePop = { scale = 1.25, seconds = 0.2 },
	},
}
