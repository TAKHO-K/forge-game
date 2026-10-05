-- BOSS-FRAMEWORK 스위치 · 공통 수치(바이블 §1-2 ~ §1-4). 게임 판정 · 스킬 수치는 여기 없다(BossData 그대로).
local D = {}

-- 어느 보스가 새 몸(리그 v2)으로 뜨는가.
--   live = 실전(라이브 포함) - **설계 담당이 수호자 시험을 검수한 뒤에만 채운다**(지금 비어 있음 = 6보스 모두 옛 몸).
--   studioTrial = Studio에서 workspace Attribute BossFrameworkTrial = true일 때만(시험 · 촬영 · 하네스) - 라이브 서버에서는 무시.
D.live = {}
D.studioTrial = { section_guardian = "v2" }
D.trialAttribute = "BossFrameworkTrial"

-- GUARDIAN-V2 몸 가장자리 기준 근접 반경(바이블 §5 - 공통 장치 · 보스별 · 기본 끔 = 표에 없음): 새 몸(리그 v2 · edgeHalfWidth)이 뜰 때만
--   반경 = 기존 값 + 늘어난 몸 반지름(BossFramework.edgeGrowth - 서버 spawnEncounter가 인스턴스 사본에 얹는다 · BossData 원본 무변경).
--   skills = { [스킬 id] = true }(보스 중심 원 · 부채 반경 · 안쪽 반경 · 대상 거리 조건 · 반사 결계 반경) · innerSafe = 근접 원형 구역 · chaseStop = 추격 정지 거리.
D.bodyEdge = {
	section_guardian = { skills = { heavy = true, innerSmash = true, swipe = true, mirror = true }, innerSafe = true, chaseStop = true },
}

-- 예산(바이블 §1-4) - 하네스 · /gg boss frame check가 검사한다
D.budget = {
	joints = 60, meshParts = 90, outlines = 12, neon = 10, tris = 30000, partTris = 5000, outlineTris = 8000, atlases = 3, atlasSize = 1024,
	queryVolumeTolerance = 0.2, -- 판정 사본 부피 = 옛 몸 ±20%
	queryParts = 3, -- Body · Head + 큰 몸이면 1개
}

-- 타격 정지(히트스톱) 범위(초 - 무게 곱한 뒤) · 클립 세트를 묶을 때 이 범위로 맞춘다(전조 · 판정 시각 무관 - 보이는 몸만)
D.hitstop = { min = 0.05, max = 0.08 }

-- 번쩍임(때리는 부위 흰 테): 전조 끝(판정 시각) 직전 seconds초 · 흰색만(빨강 · 진한 주황 금지 - 바이블 §1-2)
D.flash = { seconds = 0.15, color = Color3.fromRGB(255, 255, 255), fillPeak = 0.55, outline = 0 }

-- 2차 움직임 스프링(관절 사슬 - 클라 client/BossSpring): kind별 강성 k · 감쇠 c · 몸 가속 반응 gain · 회전 반응 turnGain · 다음 마디로 전달 carry · 최대 각(도)
D.springs = {
	tail = { k = 38, c = 6.5, gain = 1.0, turnGain = 9, carry = 0.85, max = 40 },
	wing = { k = 55, c = 7, gain = 0.8, turnGain = 6, carry = 0.7, max = 30 },
	cape = { k = 30, c = 5.5, gain = 1.2, turnGain = 10, carry = 0.9, max = 45 },
	trunk = { k = 34, c = 6, gain = 1.0, turnGain = 8, carry = 0.85, max = 35 },
	fur = { k = 70, c = 8, gain = 0.6, turnGain = 4, carry = 0.6, max = 18 },
	crystal = { k = 140, c = 9, gain = 0.35, turnGain = 2, carry = 0.5, max = 8 },
	cloth = { k = 60, c = 7, gain = 0.9, turnGain = 5, carry = 0.7, max = 25 },
}
-- 폰 · 낮은 그래픽(GraphicsMode lite): 스프링을 이 배율로 갱신(0.5 = 절반 - 두 프레임에 한 번)
D.springLiteRate = 0.5

-- 빠짐 검사(BossClipSet.coverage): 동작 세트마다 꼭 있어야 하는 동작 이름. 스킬은 BossData 스킬표 전부(빠지면 실패).
D.requiredClips = { "idle", "walk", "intro", "death", "env", "flinch", "stun" }
D.requiredOnce = { "transform" } -- 세트 묶음(변신 전/후)에 한 번
-- 변신(겉모습 - 서버 무변경): 겉모습 격노 순간(BossMotionData.enrage.phaseAt) 뒤 진행 중인 스킬이 끝나면 변신 동작 1회(최대 대기 maxWait초 뒤엔 바로)
D.transform = { maxWait = 3.0 }

return D
