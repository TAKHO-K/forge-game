-- 파티 목록 HUD(S18 - 옛 PartyHud.client.lua의 [1] 목록 + S09 경험치 칩. 24-1, PRD 20.47 [5](다) 4번 "파티원 HP 바").
-- 서버 신호(PartyStateChanged)와 Attribute를 읽어 hud/PartyListView.lua에 넘긴다. 초대 · 투표 · 알림은 PartyRequests.client.lua.
-- 실제 파티원의 HP · 레벨 · 직업 · 스테이지는 서버가 Player Attribute(Hp/MaxHp/Shield/CharacterLevel/ClassId/InfiniteStage/HealerBuffActive/RebirthCount - 전 클라에 복제된다)로 이미 내보내고 있어 그대로 읽는다.
-- 더미 멤버(DevTools)만 스냅샷에 실려 온 값(member.dummy)을 쓴다. 파티가 없거나 멤버 0이면 목록이 숨는다.
-- 자리는 ScreenMap ML.partyList(세로 중앙 · 메뉴바 오른쪽 옆) - 로블록스 채팅창(좌상단)을 가리지 않고 모바일 대시 버튼(좌하단)과 겹치지 않게 한다(모바일 축약형 · 위로 밀기 - PartyListView).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local PartyListView = require(script.Parent.PartyListView)
local PartyAway = require(script.Parent.PartyAway)

local partyStateChanged = ReplicatedStorage:WaitForChild("PartyStateChanged")

local player = Players.LocalPlayer
local REFRESH_SECONDS = 0.2

script:SetAttribute("Signals", "PartyStateChanged") -- 자체 점검(PartyHudCheck)이 연결을 대조한다

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartyHudGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local view = PartyListView.build({ parent = screenGui, compact = Theme.isMobile })

local currentState = nil

local function classNameOf(classId)
	local class = classId and ClassData.classes[classId]
	return class and class.displayName or "-"
end

-- 멤버 하나의 표시 데이터. 실제 Player는 Attribute, 더미는 스냅샷 값.
local function readMember(member)
	local hp, maxHp, level, stage, classId, buffActive, rebirth, shield
	local displayName = member.name -- 서버 기록은 username - 살아 있는 Player면 DisplayName으로 바꾼다(S12b D)
	local awayText = PartyAway.text(member, Theme.isMobile) -- S19b: 연결 끊김 유예 중 - Player가 없으니 끊기기 직전 값(member.last)으로 그리고 체력은 0
	if awayText then
		local last = member.last or {}
		level, stage, classId, rebirth = last.level, last.stage, last.classId, last.rebirth
		displayName = last.displayName or displayName
	elseif member.isDummy then
		hp, maxHp = member.dummy.hp or 1, member.dummy.maxHp or 1
		level, stage, classId = member.dummy.level, member.dummy.stage, member.dummy.classId
	else
		local target = Players:GetPlayerByUserId(member.userId)
		if target then
			hp, maxHp = target:GetAttribute("Hp"), target:GetAttribute("MaxHp")
			shield = target:GetAttribute("Shield") -- S13b: 서버 PlayerShield가 올리는 쉴드 총량
			level, stage, classId = target:GetAttribute("CharacterLevel"), target:GetAttribute("InfiniteStage"), target:GetAttribute("ClassId")
			-- 24-3(PRD 20.64) 힐러 버프 - 누가 버프를 받고 있는지 구분되게. BuffState.lua가 올려주는 Attribute.
			buffActive = target:GetAttribute("HealerBuffActive")
			rebirth = target:GetAttribute("RebirthCount")
			displayName = target.DisplayName
		end
	end
	return {
		-- S12b D: 이름 줄 = "★n Lv.35 표시이름"(파티장은 금색 - 옛 "★ " 표시는 환생 ★n과 헷갈려 뺐다)
		nameText = displayName .. (member.isDummy and " (더미)" or "") .. (buffActive and " ✚" or ""),
		level = level,
		rebirth = rebirth,
		classId = classId,
		className = classNameOf(classId),
		stage = stage,
		ratio = (hp and maxHp and maxHp > 0) and math.clamp(hp / maxHp, 0, 1) or 0,
		shieldRatio = (shield and maxHp and maxHp > 0) and math.clamp(shield / maxHp, 0, 1) or 0,
		buffActive = buffActive == true,
		isLeader = member.isLeader == true,
		awayText = awayText,
	}
end

local function refresh()
	local members = {}
	if currentState then
		for _, member in ipairs(currentState.members) do
			table.insert(members, readMember(member))
		end
	end
	view.setMembers(members)
	view.applyPosition(screenGui.AbsoluteSize.Y)
end

partyStateChanged.OnClientEvent:Connect(function(state)
	currentState = PartyAway.stamp(state)
	refresh()
end)

-- 30-0 S09(PRD 20.73 [6]): 경험치 칩 - 서버가 PartyState에서 내려주는 Attribute PartyExpBonus(0 / 0.10 / 0.15 / 0.20 - 같은 서버의 실제 Player 인원 기준)를 그대로 읽는다.
local function refreshExpChip()
	view.setExpBonus(player:GetAttribute("PartyExpBonus") or 0)
	view.applyPosition(screenGui.AbsoluteSize.Y)
end
player:GetAttributeChangedSignal("PartyExpBonus"):Connect(refreshExpChip)
refreshExpChip()

-- P3d F3: 치유사 파티 버프 칩 - 내가 버프를 받는 동안(서버 BuffState가 올리는 HealerBuffActive) 값을 보인다. 값은 툴팁과 같은 소스(PartyConfig).
local function refreshBuffChip()
	view.setHealerBuff(player:GetAttribute("HealerBuffActive") == true and PartyConfig.healerBuffFraction or nil)
	view.applyPosition(screenGui.AbsoluteSize.Y)
end
player:GetAttributeChangedSignal("HealerBuffActive"):Connect(refreshBuffChip)
refreshBuffChip()

screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	view.applyPosition(screenGui.AbsoluteSize.Y)
end)

-- HP는 Attribute 변화 신호를 멤버마다 따로 걸기보다 0.2초마다 한 번 다시 읽는다 - 최대 4명이라 비용이 없고, 멤버가 바뀔 때 연결을 붙였다 뗐다 할 필요가 없다.
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	if not currentState then
		return
	end
	accumulated += dt
	if accumulated >= REFRESH_SECONDS then
		accumulated = 0
		refresh()
	end
end)
