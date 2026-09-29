-- B4 사운드 훅(음원 없이 뼈대만 - SoundData.events의 soundId가 전부 ""라 지금은 아무 소리도 안 난다 · 오류 없음).
-- 서버에 새 Remote를 만들지 않는다: 클라가 이미 받는 Remote · Attribute를 여기서 한 번 더 듣는다(아트 · VFX 파일은 안 고친다).
--   타격 · 치명 = AttackResult · 강화 = EnhanceResult · 드랍 = Workspace ItemDrop 모델의 DropGrade Attribute(DropLightning과 같은 신호)
--   레벨업 = Player Attribute CharacterLevel(+ ClassId) · 환생 = RebirthResult · 보스 전조 = BossPatternEvent(SoundData.bossCueKinds) · 펫 부화 = PetSync hatchCount
-- 음량 = SoundData 이벤트 volume × 카테고리 음량(SettingsData volume 키의 Attribute - 서버 SettingsService가 저장값을 건다). 계산은 shared/SoundCue.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundData = require(ReplicatedStorage.Shared.data.SoundData)
local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local SoundCue = require(ReplicatedStorage.Shared.SoundCue)

local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "SoundHooks"
folder.Parent = SoundService

local function categoryVolumes()
	local volumes = {}
	for id, category in pairs(SoundData.categories) do
		local def = SettingsData.keys[category.settingKey]
		local value = def and player:GetAttribute(def.attrs[1])
		volumes[id] = type(value) == "number" and value or (def and def.default or 1)
	end
	return volumes
end

local lastAt = {} -- [eventId] = os.clock()
local function play(eventId, parentPart)
	if not eventId then
		return
	end
	local cue = SoundCue.resolve(eventId, SoundData, categoryVolumes())
	if not cue then
		return -- 표에 없음 · 빈 ID(자리값) · 음량 0
	end
	local now = os.clock()
	if not SoundCue.intervalOk(lastAt[eventId], now, SoundData.events[eventId].minInterval) then
		return
	end
	lastAt[eventId] = now
	local sound = Instance.new("Sound")
	sound.Name = eventId
	sound.SoundId = cue.soundId
	sound.Volume = cue.volume
	sound.PlaybackSpeed = cue.pitch
	if parentPart then
		sound.RollOffMaxDistance = SoundData.spatialMaxDistance
	end
	sound.Parent = parentPart or folder
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function onRemote(name, handler)
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild(name, 30)
		if remote then
			remote.OnClientEvent:Connect(handler)
		end
	end)
end

-- 타격 · 치명(기본 공격 결과 - 빗나감은 소리 없음)
onRemote("AttackResult", function(_, _, isCrit, _, _, missed)
	if not missed then
		play(isCrit and "hitCrit" or "hit")
	end
end)

-- 강화 성공 · 대성공 · 실패
onRemote("EnhanceResult", function(data)
	if type(data) == "table" then
		play(SoundCue.enhanceEvent(data.result, data.level, EnhanceConfig.announceFromLevel))
	end
end)

-- 환생 성공
onRemote("RebirthResult", function(data)
	if type(data) == "table" and data.success then
		play("rebirth")
	end
end)

-- 보스 전조(시각 예고를 그리는 종류와 같은 목록)
onRemote("BossPatternEvent", function(kind)
	if SoundData.bossCueKinds[kind] then
		play("bossCue")
	end
end)

-- 펫 부화(누적 부화 수 증가 - 첫 동기화는 기준값만)
local hatchCount = nil
onRemote("PetSync", function(view)
	if type(view) ~= "table" or type(view.hatchCount) ~= "number" then
		return
	end
	if SoundCue.isHatch(hatchCount, view.hatchCount) then
		play("petHatch")
	end
	hatchCount = view.hatchCount
end)

-- 레벨업(같은 직업에서 오를 때만 - 직업 전환 · 환생은 아님)
local level = player:GetAttribute("CharacterLevel")
local classId = player:GetAttribute("ClassId")
player:GetAttributeChangedSignal("CharacterLevel"):Connect(function()
	local newLevel = player:GetAttribute("CharacterLevel")
	local newClassId = player:GetAttribute("ClassId")
	if SoundCue.isLevelUp(level, newLevel, classId, newClassId) then
		play("levelUp")
	end
	level, classId = newLevel, newClassId
end)

-- 땅 드랍(등급별 - 모델 자리에서 3D로)
local function onDropGrade(model)
	local grade = model:GetAttribute("DropGrade")
	if grade == nil then
		return false
	end
	play(SoundCue.dropEvent(grade, SoundData), model.PrimaryPart)
	return true
end
Workspace.ChildAdded:Connect(function(inst)
	if inst:IsA("Model") and inst.Name == "ItemDrop" then
		if not onDropGrade(inst) then
			local connection
			connection = inst:GetAttributeChangedSignal("DropGrade"):Connect(function()
				connection:Disconnect()
				onDropGrade(inst)
			end)
		end
	end
end)
