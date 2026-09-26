-- MV1 무기 모델 규격(사용자 지시 - 잡는 방식부터 다시): 무기마다 "어떻게 쥐는가"를 모델과 따로 적는다. 새 무기 모델은 이 규격(손잡이 점 · 축 · 기준 크기)만 맞추면
-- 모션(W1)을 다시 만들지 않아도 된다. 기준 = 전통 사용법: 대검 양손 · 쌍검 양손 각 1자루 · 활 = 왼손 활 + 오른손 시위 · 지팡이 양손 · 성기사(출시 후) = 왼손 작은 방패 + 오른손 뿅망치.
--   hands          "both"(양손 한 자루) | "pair"(양손 각 1자루) | "bow"(왼손 활 · 오른손 시위) | "shieldHammer"(왼손 방패 · 오른손 망치)
--   pieces[]       무기 조각마다(한 자루 = 1개 · 쌍검 = 2 · 성기사 = 방패 + 망치):
--     name           WeaponModelData 조각 이름(없으면 무기 하나)
--     hand           쥐는 손(RightHand | LeftHand)
--     grip           손잡이 점 = 모델 로컬 좌표(원본 메시 단위 - 배율 전). 손은 이 점을 쥔다(Grip attachment 자리 - 새 모델은 이 이름의 Attachment를 두면 된다).
--     tipAxis        날 · 화살 · 머리 방향(모델 로컬 축 - "+Z" 등). 휘두르기 · 궤적 · 이펙트 자리가 이 축을 따른다.
--     refLength      기준 크기(끝에서 끝 · stud) - 지금 메시의 원본 길이(nativeLength)에서 배율 = refLength ÷ nativeLength(균일).
--     nativeLength   지금 메시의 원본 길이(측정 - MV1 눈금 스크린샷). 새 모델로 바꾸면 그 모델의 길이로 적는다.
--     edgeRollDeg    날 축을 도는 각 - 날 선(칼날)이 앞을 보게(지금 칼 메시는 넓은 면이 앞을 봐서 손이 날을 관통해 보였다 - 사용자 지적).
--     readyTiltDeg   준비 자세 - 칼끝을 앞으로 기울이는 각(휘두르기 호 전체가 이만큼 앞으로 · 대기 키프레임 20°와 합쳐 약 25° 앞 - 대기 · 공격 모션 자체는 W1).
--     support        양손 무기의 보조 손(LeftHand) 자리 = 모델 로컬 좌표(배율 전) - 팔 자세(IK)는 W1(지금은 규격만).
--     sheath         비전투 시 자리: mount = "back"(UpperTorso) | "hip"(LowerTorso) · offset = 그 몸 파트 기준 CFrame(W1에서 넣고 빼기 모션과 함께 쓴다 - 지금은 규격만).
-- MV1 적용 범위(사용자): 지금 모델을 규격대로 "잡는 방식만" 고친다(손 · 손잡이 점 · 배율) - 대기 · 공격 · 공중 모션은 W1, 스킬 모션은 K, 최종 다듬기는 A2.
local SWORD_NATIVE = 3.3 -- "Dual Bronze Sword" 칼날 메시 원본 길이(칼끝 z ≈ +2.1 · 가드 ≈ −0.6 · 자루 끝 ≈ −1.2 - MV1 눈금 측정)
local SWORD_GRIP = Vector3.new(0, 0, -1.3) -- 자루 가운데(가드 아래 - −0.95는 가드를 쥐었다: MV1 스크린샷으로 한 번 더 내림)
local STAFF_NATIVE = 5.0 -- 지팡이 메시 원본 길이(스크린샷 - 캐릭터 키 약 5와 비슷)

return {
	greatsword = {
		hands = "both",
		pieces = {
			{ hand = "RightHand", grip = SWORD_GRIP, tipAxis = "+Z", refLength = 5.5, nativeLength = SWORD_NATIVE, edgeRollDeg = 90, readyTiltDeg = 45,
				support = Vector3.new(0, 0, -1.6), -- 오른손 바로 아래(자루 끝 쪽) - 양손 대검
				sheath = { mount = "back", offset = CFrame.new(0, 0, 0.7) * CFrame.Angles(0, 0, math.rad(40)) } },
		},
	},
	dualblade = {
		hands = "pair",
		pieces = {
			{ name = "BladeRight", hand = "RightHand", grip = SWORD_GRIP, tipAxis = "+Z", refLength = 2.6, nativeLength = SWORD_NATIVE, edgeRollDeg = 90, readyTiltDeg = 45,
				sheath = { mount = "hip", offset = CFrame.new(0.9, 0, 0.3) * CFrame.Angles(math.rad(-20), 0, 0) } },
			{ name = "BladeLeft", hand = "LeftHand", grip = SWORD_GRIP, tipAxis = "+Z", refLength = 2.6, nativeLength = SWORD_NATIVE, edgeRollDeg = 90, readyTiltDeg = 45,
				sheath = { mount = "hip", offset = CFrame.new(-0.9, 0, 0.3) * CFrame.Angles(math.rad(-20), 0, 0) } },
		},
	},
	bow = {
		hands = "bow",
		pieces = {
			-- 활 손잡이 = 가운데 마디(WeaponModelData.bow.limbs[3]) · 시위는 몸 쪽(오른손이 당긴다 - W1)
			{ hand = "LeftHand", grip = Vector3.new(0, 0, -0.67), tipAxis = "+Z", refLength = 5.7, nativeLength = 5.7,
				stringHand = "RightHand",
				sheath = { mount = "back", offset = CFrame.new(0, 0, 0.6) * CFrame.Angles(0, 0, math.rad(-30)) } },
		},
	},
	healer = {
		hands = "both",
		pieces = {
			-- 지팡이 = 아래 1/3쯤(오른손 - 지금 메시 원점이 이미 그 자리) · 왼손은 그 위 1 stud(양손 지팡이). 지팡이 메시는 로컬 +Y가 머리(WeaponModelData 주석).
			{ hand = "RightHand", grip = Vector3.new(0, 0, 0), tipAxis = "+Y", refLength = 5.0, nativeLength = STAFF_NATIVE,
				support = Vector3.new(0, 1.0, 0),
				sheath = { mount = "back", offset = CFrame.new(0, 0, 0.7) * CFrame.Angles(0, 0, math.rad(-35)) } },
		},
	},
	-- 성기사(출시 후 - 직업 · 모델 없음): 규격만. 방패 = 팔 안쪽 손잡이 · 망치 = 자루 끝에서 1/4.
	paladin = {
		hands = "shieldHammer",
		pieces = {
			{ name = "Shield", hand = "LeftHand", grip = Vector3.new(0, 0, 0), tipAxis = "+Z", refLength = 2.4, nativeLength = 2.4,
				sheath = { mount = "back", offset = CFrame.new(0, 0, 0.6) } },
			{ name = "Hammer", hand = "RightHand", grip = Vector3.new(0, 0, -0.6), tipAxis = "+Z", refLength = 3.0, nativeLength = 3.0,
				sheath = { mount = "hip", offset = CFrame.new(0.9, 0, 0.2) } },
		},
	},
}
