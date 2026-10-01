-- B4 사운드 훅 → QUEUE-ALL2 P5: 절차 합성 사운드 시트(SoundSheet · SoundSheetData)로 실제 소리를 낸다. 서버에 새 Remote를 만들지 않는다 - 클라가 이미 받는 Remote · Attribute를 한 번 더 듣는다.
--   타격 · 치명 = AttackResult · 강화 = EnhanceResult(성공 · 유지 · 하락 · 초기화 · 방지권) · 드랍 = Workspace ItemDrop DropGrade(등급별 층층이 - 3D) · 레벨업 = CharacterLevel · 환생 = RebirthResult
--   보스 전조 = BossPatternEvent(SoundData.bossCueKinds - 짧은 두 음) · 보스 등장 = BossEncounterId · 펫 부화 = PetSync · 귀환 · 체크포인트 집중 = RecallCastUntil(+ Kind) · 발견 = CheckpointFound
--   균열 시작 = Workspace RiftActive · 칭호 = Titles · 퀘스트 받을 것 생김 = QuestClaimable · 도감 칸 완료 = CodexClaimable · 창 열기 · 닫기 = UIManager.changed(UI 그룹)
--   음량 = SoundGroup(효과 · UI · 환경 · 음악 - 설정 음량 4) × 큐 기본 음량. 소리는 보조 단서 - 시각 전조를 지우지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SoundData = require(ReplicatedStorage.Shared.data.SoundData)
local SoundSheetData = require(ReplicatedStorage.Shared.data.SoundSheetData)
local SoundCue = require(ReplicatedStorage.Shared.SoundCue)
local SoundSheet = require(script.Parent.SoundSheet)
local UIManager = require(script.Parent.UIManager)

local player = Players.LocalPlayer
local play = SoundSheet.play

local function onRemote(name, handler)
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild(name, 30)
		if remote then
			remote.OnClientEvent:Connect(handler)
		end
	end)
end

-- 타격 · 치명(내 기본 공격 결과 - 빗나감은 소리 없음)
onRemote("AttackResult", function(_, _, isCrit, _, _, missed)
	if not missed then
		play(isCrit and "hit_crit" or "hit_light", { minInterval = 0.05 })
	end
end)

-- 강화: 성공 · 유지(실패) · 하락 · 초기화 · 방지권이 막음
local ENHANCE_CUE = { success = "enhance_success", maintain = "enhance_fail", down1 = "enhance_drop", down2 = "enhance_drop", reset = "enhance_reset" }
onRemote("EnhanceResult", function(data)
	if type(data) ~= "table" then
		return
	end
	if data.blockedBy then
		play("protect_ticket")
	else
		play(ENHANCE_CUE[data.result])
	end
end)

onRemote("RebirthResult", function(data)
	if type(data) == "table" and data.success then
		play("title_get")
	end
end)

onRemote("BossPatternEvent", function(kind)
	if SoundData.bossCueKinds[kind] then
		play("warning", { minInterval = 0.4 })
	end
end)

local hatchCount = nil
onRemote("PetSync", function(view)
	if type(view) ~= "table" or type(view.hatchCount) ~= "number" then
		return
	end
	if SoundCue.isHatch(hatchCount, view.hatchCount) then
		play("codex_cell")
	end
	hatchCount = view.hatchCount
end)

onRemote("CheckpointFound", function()
	play("checkpoint_found")
end)

-- 레벨업(같은 직업에서 오를 때만)
local level = player:GetAttribute("CharacterLevel")
local classId = player:GetAttribute("ClassId")
player:GetAttributeChangedSignal("CharacterLevel"):Connect(function()
	local newLevel = player:GetAttribute("CharacterLevel")
	local newClassId = player:GetAttribute("ClassId")
	if SoundCue.isLevelUp(level, newLevel, classId, newClassId) then
		play("level_up")
	end
	level, classId = newLevel, newClassId
end)

-- 귀환 · 체크포인트 정신 집중(환경 그룹 · 3초 = 두 번) · 끝나서 이동하면 쉭(취소면 없음)
local channelToken = 0
player:GetAttributeChangedSignal("RecallCastUntil"):Connect(function()
	channelToken += 1
	local untilAt = player:GetAttribute("RecallCastUntil")
	if not untilAt then
		return
	end
	local mine = channelToken
	local cue = player:GetAttribute("RecallCastKind") == "checkpoint" and "checkpoint_channel" or "recall_channel"
	local cancelAt = player:GetAttribute("RecallCancelAt")
	task.spawn(function()
		while mine == channelToken and Workspace:GetServerTimeNow() < untilAt - 0.2 do
			play(cue)
			task.wait(SoundSheetData.cues[cue].duration)
		end
		task.wait(0.3)
		if player:GetAttribute("RecallCancelAt") == cancelAt then
			play("recall_done")
		end
	end)
end)

-- QUEUE-ALL7 C3: 대시 · 회피(필수 소리 자리 - 안 쓰던 휘두름 바람 소리 재사용) · 합동 목표 단계 달성(퀘스트 완료 징글 재사용)
onRemote("DashResult", function(data)
	if type(data) == "table" and data.ok then
		play("swing", { pitch = 0.85 })
	end
end)
onRemote("CommunityGoalBanner", function(info)
	if type(info) == "table" then
		play("quest_complete")
	end
end)

-- 보스 등장(보스전 시작 순간)
player:GetAttributeChangedSignal("BossEncounterId"):Connect(function()
	if player:GetAttribute("BossEncounterId") ~= nil then
		play("boss_appear")
	end
end)

-- 균열 시작
Workspace:GetAttributeChangedSignal("RiftActive"):Connect(function()
	if Workspace:GetAttribute("RiftActive") == true then
		play("rift_start")
	end
end)

-- 칭호 획득(목록이 늘 때) · 퀘스트 받을 것 생김 · 도감 칸 완료(받을 칸 생김)
local titleCount = #string.split(tostring(player:GetAttribute("Titles") or ""), ",")
player:GetAttributeChangedSignal("Titles"):Connect(function()
	local n = #string.split(tostring(player:GetAttribute("Titles") or ""), ",")
	if n > titleCount then
		play("title_get")
	end
	titleCount = n
end)
local function risingEdge(attr, cue)
	local last = player:GetAttribute(attr) == true
	player:GetAttributeChangedSignal(attr):Connect(function()
		local now = player:GetAttribute(attr) == true
		if now and not last then
			play(cue)
		end
		last = now
	end)
end
risingEdge("QuestClaimable", "quest_complete")
risingEdge("CodexClaimable", "codex_cell")

-- 창 열기 · 닫기(UI 그룹 · 부드럽게)
UIManager.changed:Connect(function(_, isOpen)
	play(isOpen and "button_press" or "button_close", { minInterval = 0.08 })
end)

-- 땅 드랍(등급별 층층이 - 모델 자리에서 3D · 남의 드랍은 작게)
local function onDropGrade(model)
	local grade = model:GetAttribute("DropGrade")
	if grade == nil then
		return false
	end
	local owner = model:GetAttribute("OwnerUserId")
	local cue = require(ReplicatedStorage.Shared.data.SoundMixData).dropGradeCues[grade] -- QUEUE-ALL7 C3: 일반 = 소리 없음 · 희귀 = 작은 1음 · 영웅부터 차임
	if cue then
		play(cue, { part = model.PrimaryPart, other = owner ~= nil and owner ~= player.UserId, minInterval = 0.08 })
	end
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
