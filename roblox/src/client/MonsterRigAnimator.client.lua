-- M2 잡몹 몸체 전조 포즈(연출만 · 판정 없음): 모델 Attribute MonsterRig(종 id) + MobWindup(전조 초 - 서버 MonsterAI가 켜고 끈다)을 보고
--   MonsterSpeciesData.species[id].windup.poses(관절 이름 → { y = 올림 stud · rx/ry/rz = 도 })로 Motor6D.Transform을 전조 시간 동안 채우고, 끝나면 되돌린다.
--   Transform은 PreSimulation에 써야 물리 단계에 들어간다(W1) · 관절은 BossRig.build가 만든 Motor6D(이름 = MonsterRigSpec 관절 이름).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)

local active = {} -- [Model] = { started, seconds, motors = { [Motor6D] = CFrame 목표 } }
local RELEASE_SECONDS = 0.15

local function poseCFrame(p)
	return CFrame.new(0, p.y or 0, 0) * CFrame.Angles(math.rad(p.rx or 0), math.rad(p.ry or 0), math.rad(p.rz or 0))
end

local function motorsFor(model, poses)
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and poses[d.Name] then
			out[d] = poseCFrame(poses[d.Name])
		end
	end
	return out
end

local function watch(model)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("MobWindup"):Connect(function()
		local id = model:GetAttribute("MonsterRig")
		local def = id and MonsterSpeciesData.species[id]
		local windup = def and def.windup
		if not windup then
			return
		end
		local seconds = model:GetAttribute("MobWindup")
		if seconds then
			active[model] = { started = os.clock(), seconds = seconds, motors = motorsFor(model, windup.poses) }
		elseif active[model] then
			active[model].releaseAt = os.clock() -- 때림 · 헛침: 짧게 되돌린다
		end
	end)
end

for _, model in ipairs(CollectionService:GetTagged("Monster")) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal("Monster"):Connect(watch)

RunService.PreSimulation:Connect(function()
	local now = os.clock()
	for model, st in pairs(active) do
		if not model.Parent then
			active[model] = nil
			continue
		end
		local alpha
		if st.releaseAt then
			alpha = 1 - math.clamp((now - st.releaseAt) / RELEASE_SECONDS, 0, 1)
		else
			local t = math.clamp((now - st.started) / math.max(st.seconds, 0.05), 0, 1)
			alpha = 1 - (1 - t) * (1 - t) -- 빨리 들고 끝에서 멈춤(전조 → 동작)
		end
		for motor, goal in pairs(st.motors) do
			motor.Transform = CFrame.identity:Lerp(goal, alpha)
		end
		if st.releaseAt and alpha <= 0 then
			active[model] = nil
		end
	end
end)
