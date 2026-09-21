-- 보스 체력바 HUD(S19b A). 보스전 중에만 화면 상단 가운데(ScreenMap TC.bossBar)에 보스 이름 + 체력바를 그린다. 머리 위 보스 바는 없다(서버 MonsterSpawner가 안 만든다).
-- 전달 방식: 서버가 보스 모델 Attribute BossHpRatio(0 ~ 1)와 BossName을 걸고(HP 계산은 서버만), 이 HUD는 읽어서 표시만 한다. RemoteEvent를 안 쓴다.
-- "내 보스": 서버(BossEncounter)가 보스 모델과 멤버 Player에 같은 번호 BossEncounterId를 건다 - 내 Attribute와 같은 번호의 Monster 태그 모델이 내 보스다(다른 파티의 보스 · 구출 대상은 번호가 다르다).
-- 갱신은 0.1초(= 초당 최대 10회)마다 한 번만 읽는다. 값 변화는 Gauge가 0.15초 트윈으로 부드럽게 채운다.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Gauge = require(script.Parent.Parent.ui.kit.Gauge)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local REFRESH_SECONDS = 0.1
local NAME_HEIGHT = 22
local GAP = 2

local player = Players.LocalPlayer

local function build()
	local slot = ScreenMap.slot("TC", "bossBar")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BossBarGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = slot.instanceName
	root.BackgroundTransparency = 1
	root.Size = slot.size
	root.Visible = false
	ScreenMap.place(root, "TC", "bossBar")
	root.Parent = screenGui

	local nameLabel = Theme.label(root, "", "header", "textPrimary")
	nameLabel.Name = "BossName"
	nameLabel.Size = UDim2.new(1, 0, 0, NAME_HEIGHT)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextStrokeTransparency = 0.5 -- 3D 화면 위에 그려지므로 글씨 외곽선

	local gauge = Gauge.build({
		parent = root,
		name = "BossHpGauge",
		height = 16,
		width = slot.size.X.Offset,
		position = UDim2.new(0, 0, 0, NAME_HEIGHT + GAP),
		value = 1,
	})
	return { root = root, nameLabel = nameLabel, gauge = gauge }
end

local refs = build()
local boss = nil -- 지금 표시 중인 보스 모델
local shownRatio = nil

local function findBoss(id)
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		if model:GetAttribute("BossEncounterId") == id then
			return model
		end
	end
	return nil
end

local function hide()
	boss = nil
	shownRatio = nil
	refs.root.Visible = false
end

local function refresh()
	local id = player:GetAttribute("BossEncounterId")
	if id == nil then
		hide()
		return
	end
	if not boss or not boss.Parent or boss:GetAttribute("BossEncounterId") ~= id then
		boss = findBoss(id)
		shownRatio = nil
	end
	if not boss then
		refs.root.Visible = false
		return
	end
	local ratio = math.clamp(boss:GetAttribute("BossHpRatio") or 1, 0, 1)
	refs.nameLabel.Text = boss:GetAttribute("BossName") or boss.Name
	if ratio ~= shownRatio then
		shownRatio = ratio
		refs.gauge.setValue(ratio, ("%d%%"):format(math.ceil(ratio * 100))) -- 올림: 남아 있는 보스가 0%로 보이지 않는다
	end
	refs.root.Visible = true
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated >= REFRESH_SECONDS then
		accumulated = 0
		refresh()
	end
end)
