-- 이동 수치(G2a - 맵 그레이박스 M1의 기준). 근거 · 파생 표 = docs/design/movement-metrics.md.
-- 1단 점프 · 걷기 · 중력은 place 설정(StarterPlayer.CharacterJumpHeight 7.2 · CharacterWalkSpeed 16 · Workspace.Gravity 196.2)과 같은 값을 적어 둔다 -
-- 코드는 place 값을 바꾸지 않고, 계산(2단 속도 · 체공 · 서버 높이 허용치)만 이 값을 읽는다. place 값을 바꾸면 여기도 같이 바꾼다.
return {
	gravity = 196.2,
	jumpHeightStuds = 7.2, -- 1단 발 최고 높이(이륙 지면 기준). TerrainConfig.heightToleranceStuds 8(같은 층) · 아레나 벽 14의 전제
	walkSpeedStuds = 16, -- WorldConfig.playerWalkSpeedStuds · PlayerProfile BASE_WALK_SPEED_STUDS와 같은 값
	rootAboveFeetStuds = 3, -- 발 = 루트 − 3(HipHeight 2 + 루트 반높이 1)

	-- 공중 점프(M1-0 - 사용자 결정: 겐지 · 한조식 스택형, 필드 · 보스 아레나 같은 규칙): 공중에서 점프 버튼을 누를 때마다 충전 1을 쓰고 지금 높이에서 1단 × heightFraction만큼 더 오른다.
	-- 충전은 바닥을 밟으면 charges로 돌아온다. 공중대시는 한 체공에 1회이고 공중 점프와 어느 순서로든 섞는다(G2a의 상한형 · 대시 택일 · 아레나 전용 제한은 폐기).
	-- 최대 발 높이 = 1단 × (1 + charges × heightFraction) = 7.2 × 2.7 = 19.44(정점마다 누를 때). 0.85 = 80 ~ 90% 중 가운데(표 = docs/design/movement-metrics.md v2).
	-- newPressGapSeconds: 누른 채로 있으면 JumpRequest가 반복된다 - 직전 요청과 이만큼 떨어진 요청만 새 누름. minAirSeconds: 이륙 직후의 같은 누름을 공중 점프로 읽지 않게.
	-- dashPendingSeconds: 공중대시를 요청한 뒤 결과(서버 왕복)가 올 때까지 공중 점프를 막는 여유(결과가 오면 트윈 끝 시각으로 덮는다 - 트윈이 끝나며 속도 0이라 그 사이 점프는 충전만 날아간다).
	airJump = { charges = 2, heightFraction = 0.85, newPressGapSeconds = 0.1, minAirSeconds = 0.05, dashPendingSeconds = 0.5 },

	-- 공중 점프 · 공중대시 모션(클라가 그린다 - 판정 없음). 루트 관절(Motor6D) C0에 회전을 더한다: 공중 점프 = 앞으로 한 바퀴(flipSeconds), 공중대시 = 앞으로 기울임(leanDeg · 대시 시간 동안).
	-- 입력 즉시 시작(준비 동작 없음). 남에게는 서버가 중계한다(relayMinGapSeconds보다 잦은 요청은 버린다).
	airMotion = { flipSeconds = 0.32, leanDeg = 22, relayMinGapSeconds = 0.08 },

	-- 점프력 옵션(펫 두 번째 옵션 예정 - 아직 출처 없음): "점프 높이 +%"로 정의한다(속도 %면 높이가 제곱으로 커진다). 합산 상한 +10%. 공중 점프도 이 높이의 비율이라 같이 커진다(최대 발 21.38).
	-- M1-0: 보스 아레나도 적용한다(G2a의 아레나 무시는 벽 14 · 한 체공 두 박자 여유 때문이었다 - 공중 점프 자유화로 둘 다 전제가 사라졌다).
	jumpHeightBonusCap = 0.10,

	-- 이동속도 합산 상한(신발 + 신속 옵션 · 보석): 걷기 배율 ≤ ×1.5(= 24 stud/s). 공격 속도(같은 신속 값)는 상한 없이 그대로다 - 상한을 넘는 몫은 공속으로만 남는다.
	-- 옛 값: 상한 없음(태초 신발 +549% ≈ 104 stud/s). 결정 필요(G2a 보고서 - 넘는 몫 처리 방식).
	moveSpeedMaxMultiplier = 1.5,

	-- 구조물이 부서질 때 윗면에 서 있던 사람(피해 · 튕김 없는 무너짐 - 지진파 · 모래 구덩이 · 끼임 해제 · 상한 교체): 클라가 아래로 이 속도를 준다(3.5 높이 0.19초 → 0.08초).
	-- 이번 낙하에는 공중 점프를 못 쓴다(G2a - 넉백 뒤와 같다, 착지하면 풀린다).
	structureDropSpeedStuds = 40,

	-- 서버 높이 검증(D0 부록 I §5): 발 − 마지막으로 서 있던 발 높이 > 최대 도달(JumpMath.maxReachStuds - 점프력 상한 · 공중 점프 전부) + toleranceStuds가 strikes번 이어지면 서 있던 자리로 되돌린다(+ 보스전이면 그 판 리더보드 무효).
	-- tolerance 1.0 = 복제 지연 · 보간 여유. 허용치를 넘으면 루트에서 아래로 (3 + 허용치 + probeStuds) 광선을 쏴 발 바로 아래 지면을 기준으로 다시 잰다(폴링이 짧은 착지를 놓친 경우 · FloorMaterial 지연).
	-- teleportResetStuds: 한 폴링(0.25초)에 이만큼 넘게 움직이면 순간이동으로 보고 기준을 새로 잡는다(정상 최대 = 24 × 0.25 + 대시 16 = 22). graceSeconds = 그 뒤 유예.
	-- exemptExtraSeconds: 넉백 · 회오리 · 파편 튕김은 서버가 보낸 순간부터 체공 + 이만큼 검사를 건너뛴다.
	heightGuard = { toleranceStuds = 1.0, strikes = 2, probeStuds = 3.5, teleportResetStuds = 50, graceSeconds = 1.0, exemptExtraSeconds = 0.5 },

	-- 카메라(M1-0 - 사용자 결정): 기본 = 로블록스 기본 카메라(회전 · 줌 · 각도 자유)에 줌 범위만 건다(캐릭터가 작아 보이지 않게 기본 거리를 가깝게). 설정의 "탑다운 시점"을 켠 사람만
	-- G2a 값(55° · 45 · 각 40 ~ 70 · 줌 25 ~ 70)으로 각을 조인다. 줌 최소 10 = 1인칭 · 코앞 금지(조준 · 캐릭터 가림). spawnSnapSeconds = 스폰 직후 기본 거리(탑다운이면 각도도)로 맞추는 시간.
	camera = {
		free = { zoomStuds = 22, zoomMinStuds = 10, zoomMaxStuds = 60 },
		topDown = { pitchDeg = 55, pitchMinDeg = 40, pitchMaxDeg = 70, zoomStuds = 45, zoomMinStuds = 25, zoomMaxStuds = 70 },
		spawnSnapSeconds = 0.3,
		-- M1-0 결정 ②(사용자 확정): 보스전 중에만(Player Attribute BossEncounterId) 내려다보는 각 최소 30° - 누운 카메라에서 장판이 납작해지고 앞 장판이 뒤를 가린다. 필드는 자유.
		bossPitchMinDeg = 30,
	},

	-- 시점 고정(자체 구현 - 기본 Shift Lock은 끈다 · 대시 LeftShift와 충돌 0): 켜면 마우스를 화면 가운데에 묶고 캐릭터가 카메라 방향을 본다. 카메라는 오른쪽 어깨 너머(cameraOffsetStuds).
	shiftLock = { cameraOffsetStuds = Vector3.new(1.75, 0, 0) },
}
