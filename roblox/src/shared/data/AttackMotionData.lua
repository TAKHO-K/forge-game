-- 클래스별 평타 스윙 곡선(14-2 재작업). 1차 버전은 전 구간 선형보간이었다 - 등속 회전은
-- "응원봉 흔드는 것 같다"는 피드백의 정확한 원인이다(실제 휘두르기는 천천히 들어올렸다가
-- 급격히 가속해서 멈춘다). 이번엔 구간마다 다른 easing을 쓴다 - TweenService:GetValue
-- (Instance 없이 alpha 하나만 넣으면 이징된 alpha를 돌려주는 API)로 로블록스 내장
-- easing 곡선을 매 프레임 직접 계산하는 내 방식(WeaponVisual.lua, 이유는 그쪽 주석
-- 참고 - 손을 매 프레임 따라가야 해서 TweenService의 절대 CFrame 방식을 못 쓴다) 안에
-- 그대로 넣을 수 있다.
--
-- 모든 스윙을 예비동작(windup) -> 타격(strike) -> 후속(followThrough) 세 구간으로
-- 나눈다 - "뽑는 모션이 없다"(대검)는 지적이 정확히 예비동작 부재였다. 각 구간의
-- easing 성격:
--   예비동작 - Sine/Quad In(느리게 시작해서 가속) - 무기를 들어올리는 무게감
--   타격     - Quad/Back Out(시작하자마자 빠르게, 못 박듯 급정지) - "급격한 가속"
--   후속     - Quad Out(감속하며 정지) - 관성으로 자연스럽게 멎는 느낌
--
-- 전체 길이는 1차 버전(쿨다운의 75~90%, 0.14~0.32초)이 "예비동작이 안 보일 만큼
-- 짧다"는 지적을 받아 재검토했다 - 클래스 공속 비율은 유지하되(쌍검이 가장 짧고
-- 대검이 가장 길다는 순서), 절대 길이는 눈에 읽히는 수준으로 올렸다. 그 결과 일부
-- 클래스(특히 대검)는 스윙 길이가 실제 공격 쿨다운을 넘는다 - 그다음 공격이 들어오면
-- 이전 스윙 애니메이션을 끊고 새로 시작한다(콤보 캔슬처럼 보인다, 액션 게임에서
-- 흔한 처리라 어색하지 않다고 판단했다). "모션을 다시 보여줄지"를 서버 쿨다운이 아니라
-- 클라이언트가 판단하는 구조(AttackInput.client.lua)는 그대로 유지한다.
--
-- 검기(Trail)는 타격(strike) 구간에서만 켠다 - trailWindow가 그 구간의 [시작,끝] t값.

local TweenService = game:GetService("TweenService")

local IN_SINE = { style = Enum.EasingStyle.Sine, direction = Enum.EasingDirection.In }
local OUT_QUAD = { style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out }
local OUT_BACK = { style = Enum.EasingStyle.Back, direction = Enum.EasingDirection.Out }

return {
	greatsword = {
		totalDurationSeconds = 0.55, -- 공격 쿨다운(0.4초)보다 길다 - 의도적(위 주석)
		trailWidth = 1.4,
		trailColor = Color3.fromRGB(220, 235, 255),
		parts = {
			{
				name = "Blade",
				swingAxis = "X",
				-- 각도는 raw 숫자를 그대로 보간한다(쿼터니언 최短경로가 아니다) - windup=-150→
				-- strike=165는 315°를 휩쓸어 사실상 풍차처럼 돈다는 게 첫 실측에서 드러났다
				-- (스크린샷으로 확인 - 칼끝이 카메라 쪽을 향해 거의 한 바퀴 돌아 있었다).
				-- strike를 40으로 낮춰 windup→strike 190°(젖힌 자세에서 크게 한 번 내려찍는
				-- 정도), rest→windup 170°(크게 들어올림)로 조정했다.
				keyframes = {
					{ t = 0.0, angle = 20 }, -- 대기 자세(칼을 몸 옆에 살짝 세워 든다)
					{ t = 0.35, angle = -150, easing = IN_SINE }, -- 예비동작: 크게 젖혀 들어올림(뽑는 느낌)
					{ t = 0.55, angle = 40, easing = OUT_BACK }, -- 타격: 급격히 내려찍음(Back으로 살짝 튕기는 임팩트)
					{ t = 1.0, angle = 20, easing = OUT_QUAD }, -- 후속: 감속하며 대기 자세로
				},
				trailWindow = { 0.35, 0.60 },
			},
		},
		-- 어깨 관절 자체를 흔드는 스윙(14-2 2차 - "무기만 손 주위를 돌고 캐릭터는 가만히
		-- 서 있다" 버그 수정). 무기 각도(위 keyframes)와 별개 축이다 - 정밀 튜닝은 이번
		-- 범위 밖이라 무기 스윙과 같은 t/이징을 그대로 재사용했다("어색하지만 움직인다"가
		-- 이번 통과 기준, 지시 사항).
		armSwing = {
			{ side = "Right", swingAxis = "X", keyframes = {
				{ t = 0.0, angle = 0 },
				{ t = 0.35, angle = -55, easing = IN_SINE },
				{ t = 0.55, angle = 45, easing = OUT_BACK },
				{ t = 1.0, angle = 0, easing = OUT_QUAD },
			} },
		},
	},

	dualblade = {
		totalDurationSeconds = 0.32,
		trailWidth = 0.6,
		trailColor = Color3.fromRGB(200, 245, 245),
		-- swingAxis가 Y에서 X로 바뀌었다(대검 방향 수정과 같은 세션) - WeaponModelData.lua의
		-- 그립 방향 수정으로 칼이 대기 자세에서 위(로컬 Y)를 향하게 됐는데, swingAxis="Y"는
		-- 그립 프레임 기준 Y축(수정 후엔 손의 앞뒤 축과 같아진다)으로 회전해 칼이 위를 향한
		-- 채 좌우로 눕는 이상한 동작이 된다. 대검처럼 X축(손의 Y-Z 평면, 위→앞 내려베기)으로
		-- 돌려야 자연스러운 슬래시가 나온다 - 실제 플레이 스크린샷으로 확인 후 확정했다.
		parts = {
			{
				name = "BladeLeft",
				swingAxis = "X",
				keyframes = {
					{ t = 0.0, angle = -15 },
					{ t = 0.3, angle = 35, easing = IN_SINE }, -- 예비동작(뒤로 살짝 당김)
					{ t = 0.5, angle = -95, easing = OUT_BACK }, -- 타격(빠르게 베기)
					{ t = 1.0, angle = -15, easing = OUT_QUAD },
				},
				trailWindow = { 0.3, 0.55 },
			},
			{
				name = "BladeRight",
				swingAxis = "X",
				-- 반대 손은 반대 방향 - 두 자루가 엇갈려 X자로 베는 인상.
				keyframes = {
					{ t = 0.0, angle = 15 },
					{ t = 0.3, angle = -35, easing = IN_SINE },
					{ t = 0.5, angle = 95, easing = OUT_BACK },
					{ t = 1.0, angle = 15, easing = OUT_QUAD },
				},
				trailWindow = { 0.3, 0.55 },
			},
		},
		-- 쌍검은 양팔이 교차한다 - 왼팔·오른팔을 반대 부호로 함께 흔든다(greatsword 주석 참고).
		armSwing = {
			{ side = "Right", swingAxis = "X", keyframes = {
				{ t = 0.0, angle = 0 },
				{ t = 0.3, angle = 30, easing = IN_SINE },
				{ t = 0.5, angle = -50, easing = OUT_BACK },
				{ t = 1.0, angle = 0, easing = OUT_QUAD },
			} },
			{ side = "Left", swingAxis = "X", keyframes = {
				{ t = 0.0, angle = 0 },
				{ t = 0.3, angle = -30, easing = IN_SINE },
				{ t = 0.5, angle = 50, easing = OUT_BACK },
				{ t = 1.0, angle = 0, easing = OUT_QUAD },
			} },
		},
	},

	-- 활은 회전이 아니라 "당김"(nock 오프셋, +Z 방향 stud 값 - 시위 양 끝은
	-- WeaponModelData.lua의 stringTopTip/BottomTip이 실측한 실제 좌표계 기준이다)이다 -
	-- WeaponVisual이 swingAxis 대신 이 값으로 활시위 중간점과 화살 위치를 계산한다.
	bow = {
		totalDurationSeconds = 0.55,
		parts = {
			{
				name = "Arrow",
				swingAxis = "Draw",
				keyframes = {
					{ t = 0.0, offset = 0 },
					{ t = 0.55, offset = 1.15, easing = IN_SINE }, -- 예비동작: 천천히 당김
					{ t = 0.72, offset = 1.15 }, -- 정점에서 짧게 멈춤(조준감)
					{ t = 0.80, offset = 0, easing = OUT_BACK }, -- 타격: 시위가 급격히 튕겨나감(발사)
					{ t = 1.0, offset = 0 },
				},
			},
		},
		-- 화살이 시위를 떠나는 시점(t) - 이 지점 이후 활에 걸린 화살은 숨기고, 같은
		-- 순간 실제로 날아가는 화살(Projectiles.lua)이 서버가 확인해 준 대상을 향해
		-- 발사된다(아래 releaseT, AttackInput.client.lua가 사용).
		releaseT = 0.78,
		-- 시위를 당기는 오른팔 - 당김 구간(위 drawOffset)과 같은 타이밍으로 뒤로 당겼다가
		-- 발사 시점에 앞으로 풀린다.
		armSwing = {
			{ side = "Right", swingAxis = "X", keyframes = {
				{ t = 0.0, angle = 0 },
				{ t = 0.55, angle = -35, easing = IN_SINE },
				{ t = 0.8, angle = 10, easing = OUT_BACK },
				{ t = 1.0, angle = 0, easing = OUT_QUAD },
			} },
		},
	},

	healer = {
		totalDurationSeconds = 0.35,
		trailWidth = 0.5,
		trailColor = Color3.fromRGB(230, 200, 255),
		parts = {
			{
				name = "Staff",
				swingAxis = "X",
				keyframes = {
					{ t = 0.0, angle = -10 },
					{ t = 0.35, angle = -55, easing = IN_SINE }, -- 예비동작: 살짝 당김
					{ t = 0.55, angle = 30, easing = OUT_QUAD }, -- 타격: 짧게 내지름(구슬 발사 시점)
					{ t = 1.0, angle = -10, easing = OUT_QUAD },
				},
				trailWindow = { 0.35, 0.55 },
			},
		},
		-- 구슬이 지팡이 끝을 떠나는 시점 - 활과 같은 개념.
		releaseT = 0.55,
		armSwing = {
			{ side = "Right", swingAxis = "X", keyframes = {
				{ t = 0.0, angle = 0 },
				{ t = 0.35, angle = -20, easing = IN_SINE },
				{ t = 0.55, angle = 30, easing = OUT_QUAD },
				{ t = 1.0, angle = 0, easing = OUT_QUAD },
			} },
		},
	},

	-- WeaponVisual.lua가 이징을 계산할 때 쓰는 헬퍼 - 데이터 파일이지만 이징 계산
	-- 자체는 여기 한 곳에만 있어야 클래스마다 다른 계산식이 생기지 않는다.
	evalEase = function(alpha, easing)
		if not easing then
			return alpha -- easing 지정이 없는 구간은 선형(주로 "정지 유지" 구간에 씀)
		end
		return TweenService:GetValue(alpha, easing.style, easing.direction)
	end,
}
