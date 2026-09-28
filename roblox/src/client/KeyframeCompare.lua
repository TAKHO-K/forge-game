-- W3a 제작 방식 비교: 대검 1 ~ 3타 한 세트를 키프레임 애니메이션(KeyframeSequence)으로 만들어 Animator로 재생한다(코드 모션 = WeaponVisual과 나란히 비교).
--   포즈 값 = PlayerMotionData(코드 모션과 같은 키 포즈) + 키프레임판에서만 쓰는 것: 따라 휘두름 끝 멈춤(hold - 무게) · 관절마다 이징(칼끝이 끌려가듯 Cubic Out).
--   재생 = KeyframeSequenceProvider:RegisterKeyframeSequence(Studio 전용 임시 id - 업로드 없음). 라이브에 쓰려면 Animation Editor로 가져와 게시(보고서 C3 §모션 - 사용자 작업 순서).
--   재생하는 동안 WeaponVisual은 포즈를 쓰지 않는다(외부 재생 표시 st.external) - 무기는 손에 붙고 왼손 = 보조 손 IK만 그대로(코드판과 같은 잡기).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
local PoseRig = require(script.Parent.PoseRig)

local KeyframeCompare = {}

-- 관절 → 그 관절이 움직이는 파트(Pose 이름) · 부모 파트
local JOINT_PART = {
	Root = { "LowerTorso", "HumanoidRootPart" }, Waist = { "UpperTorso", "LowerTorso" }, Neck = { "Head", "UpperTorso" },
	RightShoulder = { "RightUpperArm", "UpperTorso" }, RightElbow = { "RightLowerArm", "RightUpperArm" }, RightWrist = { "RightHand", "RightLowerArm" },
	LeftShoulder = { "LeftUpperArm", "UpperTorso" }, LeftElbow = { "LeftLowerArm", "LeftUpperArm" }, LeftWrist = { "LeftHand", "LeftLowerArm" },
	RightHip = { "RightUpperLeg", "LowerTorso" }, RightKnee = { "RightLowerLeg", "RightUpperLeg" }, RightAnkle = { "RightFoot", "RightLowerLeg" },
	LeftHip = { "LeftUpperLeg", "LowerTorso" }, LeftKnee = { "LeftLowerLeg", "LeftUpperLeg" }, LeftAnkle = { "LeftFoot", "LeftLowerLeg" },
}
local ORDER = { "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle" }
local HOLD_SECONDS = 0.06 -- 키프레임판만: 따라 휘두름 끝에서 칼 무게로 잠깐 멈춤

local function addKeyframe(kfs, time, pose, style, direction)
	local kf = Instance.new("Keyframe")
	kf.Time = time
	local rootPose = Instance.new("Pose")
	rootPose.Name = "HumanoidRootPart"
	rootPose.Weight = 0
	rootPose.Parent = kf
	local made = { HumanoidRootPart = rootPose }
	for _, joint in ipairs(ORDER) do
		local part, parent = JOINT_PART[joint][1], JOINT_PART[joint][2]
		local p = Instance.new("Pose")
		p.Name = part
		p.CFrame = pose[joint] and PoseRig.rot(pose[joint]) or CFrame.identity
		p.Weight = 1
		p.EasingStyle = style or Enum.PoseEasingStyle.Cubic
		p.EasingDirection = direction or Enum.PoseEasingDirection.Out
		made[part] = p
		p.Parent = made[parent] -- ORDER가 부모를 먼저 만든다
	end
	kf.Parent = kfs
end

-- 대검 1 → 2 → 3타(코드판과 같은 키 포즈 · 시각 = 각 타 ant/act/rec + hold). 반환 KeyframeSequence, 길이(초)
function KeyframeCompare.build()
	local w = PlayerMotionData.weapons.greatsword
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = "GreatswordCombo_KF"
	kfs.Loop = false
	kfs.Priority = Enum.AnimationPriority.Action4
	local t = 0
	addKeyframe(kfs, t, w.stance)
	t += 0.12
	for _, clip in ipairs(w.attacks) do
		addKeyframe(kfs, t, clip.cocked, Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut) -- 전조 끝(들어 올림)
		t += clip.ant
		addKeyframe(kfs, t, clip.contact, Enum.PoseEasingStyle.Linear) -- 타격(1프레임 - 서버 즉시 판정과 같은 순간)
		t += clip.act
		addKeyframe(kfs, t, clip.through, Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.Out) -- 칼끝이 무게에 끌려가 멈춘다
		t += HOLD_SECONDS
		addKeyframe(kfs, t, clip.through, Enum.PoseEasingStyle.Constant)
		t += math.max(clip.rec - HOLD_SECONDS, 0.05)
		addKeyframe(kfs, t, clip.settle, Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut)
	end
	return kfs, t
end

local cached = nil
function KeyframeCompare.play(character, speed)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	if not cached then
		local kfs, length = KeyframeCompare.build()
		cached = { id = KeyframeSequenceProvider:RegisterKeyframeSequence(kfs), length = length }
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = cached.id
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(0.1, 1, speed or 1)
	return track, cached.length / (speed or 1)
end

return KeyframeCompare
