-- 이동 수치(G2a - 맵 그레이박스 M1의 기준). 근거 · 파생 표 = docs/design/movement-metrics.md.
-- 1단 점프 · 걷기 · 중력은 place 설정(StarterPlayer.CharacterJumpHeight 7.2 · CharacterWalkSpeed 16 · Workspace.Gravity 196.2)과 같은 값을 적어 둔다 -
-- 코드는 place 값을 바꾸지 않고, 계산(2단 속도 · 체공 · 서버 높이 허용치)만 이 값을 읽는다. place 값을 바꾸면 여기도 같이 바꾼다.
return {
	gravity = 196.2,
	jumpHeightStuds = 7.2, -- 1단 발 최고 높이(이륙 지면 기준). TerrainConfig.heightToleranceStuds 8(같은 층) · 아레나 벽 14의 전제
	walkSpeedStuds = 16, -- WorldConfig.playerWalkSpeedStuds · PlayerProfile BASE_WALK_SPEED_STUDS와 같은 값
	rootAboveFeetStuds = 3, -- 발 = 루트 − 3(HipHeight 2 + 루트 반높이 1)

	-- 이단점프(D0 결정 3 B 상한형 · 사용자 확정): 같은 점프 버튼을 공중에서 한 번 더. 2단 오름 = 1단 × heightFraction, 단 발이 "이륙 지면 + 1단 높이"를 넘지 않게 줄인다 -
	-- 발 최고 높이는 1단과 같고(판정 8 · 벽 14 · 사냥터 층 그대로) 체공만 0.54 → 최대 0.93초로 는다. 0.5 = 50 ~ 60% 중 여유가 큰 쪽(진동파 2→3박 한 번에 넘기 여유 0.15초 -
	-- 60%면 0.12, 점프력 옵션 상한을 겹치면 0.07로 0.1 아래). 1단 정점 근처에서 누르면 거의 안 오르므로 minRiseStuds보다 못 오르면 누름을 쓰지 않는다(헛입력 방지).
	-- newPressGapSeconds: 누른 채로 있으면 JumpRequest가 반복된다 - 직전 요청과 이만큼 떨어진 요청만 새 누름. minAirSeconds: 이륙 직후의 같은 누름을 2단으로 읽지 않게.
	doubleJump = { heightFraction = 0.5, minRiseStuds = 0.5, newPressGapSeconds = 0.1, minAirSeconds = 0.05 },

	-- 공중대시(21-3)와 이단점프는 한 번의 체공에 둘 중 하나만(사용자 확정 - D0 결정 3 가). 대시 0.3초 동안 높이를 붙잡는다(DashConfig.durationSeconds).

	-- 점프력 옵션(펫 두 번째 옵션 예정 - 아직 출처 없음): "점프 높이 +%"로 정의한다(속도 %면 높이가 제곱으로 커진다). 합산 상한 +10% = 7.92 < 판정 층 8(사냥터 불변식).
	-- 보스 아레나는 이 옵션을 무시하고 7.2로 뛴다(단상 3.5 + 7.92 + 3 = 루트 14.42 > 벽 14 → 대시 광선이 벽을 넘는다 · 파동 박자 여유가 0.1 아래로 준다). 결정 필요(G2a 보고서).
	jumpHeightBonusCap = 0.10,

	-- 이동속도 합산 상한(신발 + 신속 옵션 · 보석): 걷기 배율 ≤ ×1.5(= 24 stud/s). 공격 속도(같은 신속 값)는 상한 없이 그대로다 - 상한을 넘는 몫은 공속으로만 남는다.
	-- 옛 값: 상한 없음(태초 신발 +549% ≈ 104 stud/s). 결정 필요(G2a 보고서 - 넘는 몫 처리 방식).
	moveSpeedMaxMultiplier = 1.5,

	-- 구조물이 부서질 때 윗면에 서 있던 사람(피해 · 튕김 없는 무너짐 - 지진파 · 모래 구덩이 · 끼임 해제 · 상한 교체): 클라가 아래로 이 속도를 준다(3.5 높이 0.19초 → 0.08초).
	-- 이번 낙하에는 2단을 못 쓴다(발판이 사라진 높이를 기준으로 2단이 뜨면 아레나 바닥 기준 8을 넘는다).
	structureDropSpeedStuds = 40,

	-- 서버 높이 검증(D0 부록 I §5): 발 − 마지막으로 서 있던 발 높이 > 1단 × (1 + 점프력 상한) + toleranceStuds가 strikes번 이어지면 서 있던 자리로 되돌린다(+ 보스전이면 그 판 리더보드 무효).
	-- tolerance 1.0 = 복제 지연 · 보간 여유. 허용치를 넘으면 루트에서 아래로 (3 + 허용치 + probeStuds) 광선을 쏴 발 바로 아래 지면을 기준으로 다시 잰다(폴링이 짧은 착지를 놓친 경우 · FloorMaterial 지연).
	-- teleportResetStuds: 한 폴링(0.25초)에 이만큼 넘게 움직이면 순간이동으로 보고 기준을 새로 잡는다(정상 최대 = 24 × 0.25 + 대시 16 = 22). graceSeconds = 그 뒤 유예.
	-- exemptExtraSeconds: 넉백 · 회오리 · 파편 튕김은 서버가 보낸 순간부터 체공 + 이만큼 검사를 건너뛴다.
	heightGuard = { toleranceStuds = 1.0, strikes = 2, probeStuds = 3.5, teleportResetStuds = 50, graceSeconds = 1.0, exemptExtraSeconds = 0.5 },

	-- 카메라(로블록스 기본 Classic 카메라 위에 각도 · 줌 범위만 건다 - 좌우 회전은 자유). 각도 = 수평에서 내려다보는 각(도).
	-- 기본 55° · 45stud에서 PC(16:9)와 폰(800 × 360) 화면에 보이는 땅의 범위 = docs/design/movement-metrics.md §6. 줌 25 미만(1인칭 · 코앞)은 막는다.
	camera = { pitchDeg = 55, pitchMinDeg = 40, pitchMaxDeg = 70, zoomStuds = 45, zoomMinStuds = 25, zoomMaxStuds = 70, spawnSnapSeconds = 0.3 }, -- spawnSnapSeconds = 스폰 직후 기본 거리 · 각도로 맞추는 시간
}
