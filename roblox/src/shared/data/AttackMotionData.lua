-- 클래스별 무기 모양·평타 스윙 곡선(14-2). 무기 모델이 아직 없어(WeaponData는 id·강화
-- 단계만 저장하고 실물 인스턴스가 없다) 기본 파트로 직접 만든다 - 몬스터·아이템 드랍과
-- 같은 "도형으로 표현" 방식, 화려함보다 "움직임이 보이는가"가 기준이다.
--
-- 스윙은 Roblox 애니메이션 에셋(Animation/AnimationTrack)이 아니라 파트 CFrame을 매 프레임
-- 직접 계산한다(WeaponVisual.lua) - 이유 셋: (1) 이 프로젝트에 애니메이션 에셋이 하나도
-- 없고 R15 Motor6D를 직접 다루면 팔 관절에 결합돼 걷기 애니메이션과 충돌할 위험이 있다.
-- (2) 캐릭터가 스윙 도중에도 계속 움직이므로(최대 0.4초 스윙 동안 16stud/s면 6.4stud
-- 이동), 무기가 손을 매 프레임 따라가야 한다 - TweenService로 절대 CFrame을 한 번
-- 목표로 잡으면 그 사이 캐릭터가 이동한 만큼 무기가 손에서 떨어져 보인다. (3) 클래스별로
-- 곡선(키프레임)만 다르게 정의하면 재사용되는 계산 로직(WeaponVisual.playSwing)은
-- 하나로 충분하다.
--
-- 스윙 길이는 그 클래스의 공격 쿨다운(CombatConfig.attackCooldownSeconds / class.atkSpeed)의
-- 일정 비율이다 - 공속이 클래스마다 다르므로 모션 길이도 자동으로 따라간다(지시 사항).
-- swingDurationRatio를 1.0 미만으로 둬 다음 공격 전 짧은 "정지" 구간을 남긴다 - 그래야
-- 연속 공격 시 스윙이 뭉개져 보이지 않는다.

return {
	greatsword = {
		swingDurationRatio = 0.8,
		parts = {
			{
				name = "Blade",
				size = Vector3.new(0.35, 3.0, 0.6),
				color = Color3.fromRGB(190, 190, 200),
				gripOffset = CFrame.new(0.15, -0.1, -0.1),
				restRotationDeg = Vector3.new(-40, 0, 15), -- 어깨 뒤로 살짝 들어 올린 대기 자세
				swingAxis = "X", -- 세로로 크게 내려찍는 축
				keyframes = {
					{ t = 0.0, angle = 0 },
					{ t = 0.30, angle = -110 }, -- 크게 젖혀 들어올림(휘두르기 전 예비 동작)
					{ t = 0.65, angle = 140 }, -- 내려찍는 정점
					{ t = 1.0, angle = 0 },
				},
			},
		},
	},

	dualblade = {
		swingDurationRatio = 0.85,
		parts = {
			{
				name = "BladeLeft",
				size = Vector3.new(0.2, 1.7, 0.4),
				color = Color3.fromRGB(210, 210, 220),
				gripOffset = CFrame.new(-0.25, -0.05, -0.05),
				restRotationDeg = Vector3.new(0, 0, -20),
				swingAxis = "Y", -- 수평으로 빠르게 베는 축
				keyframes = {
					{ t = 0.0, angle = 0 },
					{ t = 0.5, angle = -75 },
					{ t = 1.0, angle = 0 },
				},
			},
			{
				name = "BladeRight",
				size = Vector3.new(0.2, 1.7, 0.4),
				color = Color3.fromRGB(210, 210, 220),
				gripOffset = CFrame.new(0.25, -0.05, -0.05),
				restRotationDeg = Vector3.new(0, 0, 20),
				swingAxis = "Y",
				-- 반대 손은 반대 방향으로 - 두 자루가 엇갈려 베는 "X"자 인상을 준다.
				keyframes = {
					{ t = 0.0, angle = 0 },
					{ t = 0.5, angle = 75 },
					{ t = 1.0, angle = 0 },
				},
			},
		},
	},

	bow = {
		swingDurationRatio = 0.9,
		parts = {
			-- 활 몸체 자체는 거의 안 움직인다(당기는 건 화살 쪽) - 대기 각도만 유지.
			{
				name = "BowBody",
				size = Vector3.new(0.15, 2.0, 0.15),
				color = Color3.fromRGB(120, 80, 50),
				gripOffset = CFrame.new(0.2, 0, -0.3),
				restRotationDeg = Vector3.new(0, 0, 0),
				swingAxis = "Z",
				keyframes = {
					{ t = 0.0, angle = 0 },
					{ t = 1.0, angle = 0 },
				},
			},
			-- 화살 - 당겼다(뒤로) 놓는다(앞으로 쏘아짐 + 사라짐은 WeaponVisual이 투명도로 처리).
			{
				name = "Arrow",
				size = Vector3.new(0.08, 0.08, 1.4),
				color = Color3.fromRGB(230, 210, 150),
				gripOffset = CFrame.new(0.2, 0, -0.3),
				restRotationDeg = Vector3.new(0, 0, 0),
				swingAxis = "ArrowShoot", -- 회전이 아니라 전후 이동 - WeaponVisual이 특수 처리
				keyframes = {
					{ t = 0.0, offset = 0 },
					{ t = 0.45, offset = -0.9 }, -- 당김
					{ t = 0.55, offset = -0.9 }, -- 정점에서 살짝 멈춤(조준감)
					{ t = 0.85, offset = 2.5 }, -- 발사(활 앞으로 튀어나감)
					{ t = 1.0, offset = 0 }, -- 다음 발사를 위해 원위치(투명도로 순간 리셋을 가린다)
				},
			},
		},
	},

	healer = {
		swingDurationRatio = 0.75,
		parts = {
			{
				name = "Staff",
				size = Vector3.new(0.15, 2.2, 0.15),
				color = Color3.fromRGB(220, 200, 120),
				gripOffset = CFrame.new(0.15, -0.1, -0.15),
				restRotationDeg = Vector3.new(-15, 0, 0),
				swingAxis = "X",
				-- 다른 클래스보다 훨씬 작은 각도 - 힐러는 지팡이로 짧게 내지르는 정도(약한
				-- 타격감이 오히려 "직접 때리는 딜러가 아니다"라는 직업 정체성과 맞는다).
				keyframes = {
					{ t = 0.0, angle = 0 },
					{ t = 0.4, angle = -35 },
					{ t = 0.7, angle = 20 },
					{ t = 1.0, angle = 0 },
				},
			},
		},
	},
}
