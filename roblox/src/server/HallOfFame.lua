-- D1 ④ 명예의 전당: 허브 커뮤니티 광장 석판 - 최근 태초 20건 + 세계 번호. 원본 = PrimordialRegistry.readRecent(DataStore) - 서버 시작 · 5분마다 다시 읽는다
-- (전 서버 알림이 유실돼도 여기서 복원된다). 이 서버에 알림이 오면 바로 한 줄 더한다(다음 읽기가 원본으로 덮는다).
-- 자리 = WorldMapData 커뮤니티 광장 spots의 "hallOfFame"(Spot Attribute가 붙은 자리 표시 기둥) 옆. 이름은 기록 때 필터한 것(PrimordialRegistry.claim).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local PrimordialStamp = require(ReplicatedStorage.Shared.PrimordialStamp)
local PrimordialRegistry = require(script.Parent.PrimordialRegistry)

local HallOfFame = {}

local SLAB_SIZE = Vector3.new(16, 12, 1)
local ROWS_PER_COLUMN = 10

local slab, rowLabels, emptyLabel
local entries = {} -- 최신이 앞
local lastReadOk = nil -- 마지막 DataStore 읽기 성공 여부(검증)

local function findSpot()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst:GetAttribute("Spot") == "hallOfFame" then
			return inst
		end
	end
	return nil
end

local function makeFace(face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HallGui" .. face.Name
	gui.Face = face
	gui.CanvasSize = Vector2.new(800, 600)
	gui.LightInfluence = 0
	gui.Parent = slab
	local paper = Instance.new("Frame") -- 조명과 무관한 흰 바탕(석판 파트 색은 햇빛에 푸르게 보인다)
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = Color3.fromRGB(246, 243, 250)
	paper.BorderSizePixel = 0
	paper.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 44
	title.TextColor3 = PrimordialData.accentColor
	title.Text = "★ 명예의 전당 · 태초 ★"
	title.Parent = gui
	local labels = {}
	for i = 1, PrimordialData.recentKeep do
		local column = (i - 1) // ROWS_PER_COLUMN
		local row = (i - 1) % ROWS_PER_COLUMN
		local label = Instance.new("TextLabel")
		label.Position = UDim2.new(0, 20 + column * 390, 0, 80 + row * 50)
		label.Size = UDim2.new(0, 370, 0, 46)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 21 -- 두 줄(이름 · 날짜와 출처)이 칸 높이 46에 들어가게
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.TextColor3 = Color3.fromRGB(40, 36, 52)
		label.Text = ""
		label.Parent = gui
		labels[i] = label
	end
	local empty = Instance.new("TextLabel")
	empty.Position = UDim2.new(0, 0, 0, 260)
	empty.Size = UDim2.new(1, 0, 0, 60)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.GothamBold
	empty.TextSize = 28
	empty.TextColor3 = Color3.fromRGB(90, 84, 110)
	empty.Text = "아직 기록이 없어요 - 첫 태초의 주인은?"
	empty.Parent = gui
	return labels, empty
end

local function build()
	local spot = findSpot()
	if not spot then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "HallOfFame"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	slab = Instance.new("Part")
	slab.Name = "Slab"
	slab.Anchored = true
	slab.Material = Enum.Material.SmoothPlastic
	slab.Color = Color3.fromRGB(236, 232, 244) -- 흰 석판 + 자홍 테두리(태초 색)
	slab.Size = SLAB_SIZE
	slab.CFrame = spot.CFrame * CFrame.new(0, SLAB_SIZE.Y / 2 + 4, 0) -- 자리 표시 기둥(높이 5) 위로
	slab.Parent = model
	local rim = Instance.new("SelectionBox") -- 테두리(외곽선 풀과 별개 - Highlight가 아니다)
	rim.Adornee = slab
	rim.LineThickness = 0.12
	rim.Color3 = PrimordialData.accentColor
	rim.SurfaceTransparency = 1
	rim.Parent = slab
	rowLabels, emptyLabel = {}, {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local labels, empty = makeFace(face)
		table.insert(rowLabels, labels)
		table.insert(emptyLabel, empty)
	end
	model.PrimaryPart = slab
	model.Parent = Workspace
	return true
end

local function lineFor(entry)
	local head = ("#%s %s"):format(tostring(entry.no or "?"), tostring(entry.name or PrimordialData.fallbackName))
	local sourceText = PrimordialStamp.sourceText(entry.source)
	local date = PrimordialStamp.dateText(entry.at)
	local tail = table.concat({ date or "", sourceText or "" }, " · ")
	return head .. "\n" .. tail
end

local function redraw()
	if not slab then
		return
	end
	for faceIndex, labels in ipairs(rowLabels) do
		for i, label in ipairs(labels) do
			local entry = entries[i]
			label.Text = entry and lineFor(entry) or ""
		end
		emptyLabel[faceIndex].Visible = #entries == 0
	end
	slab:SetAttribute("HallCount", #entries)
	slab:SetAttribute("HallTop", entries[1] and entries[1].no or 0)
end

-- 원본에서 다시 읽는다(서버 시작 · 5분마다 · 검증). 반환 = 읽기 성공 여부.
function HallOfFame.refresh()
	local list = PrimordialRegistry.readRecent()
	lastReadOk = list ~= nil
	if list then
		entries = list
		redraw()
	end
	return lastReadOk
end

-- 이 서버에 알림이 온 순간: 같은 번호가 없으면 앞에 넣는다.
local function onAnnounce(entry)
	for _, row in ipairs(entries) do
		if row.no == entry.no then
			return
		end
	end
	table.insert(entries, 1, entry)
	while #entries > PrimordialData.recentKeep do
		table.remove(entries)
	end
	redraw()
end

-- 검증용: 지금 석판이 보여 주는 목록(번호 배열)
function HallOfFame.shownNumbers()
	local list = {}
	for _, entry in ipairs(entries) do
		table.insert(list, entry.no)
	end
	return list
end

-- 검증용: 알림 없이 목록을 비웠다가(알림 누락 흉내) 원본에서 복원
function HallOfFame.debugForget()
	entries = {}
	redraw()
end

function HallOfFame.start()
	PrimordialRegistry.onAnnounce(onAnnounce)
	task.spawn(function()
		local spotWait = 0
		while not build() and spotWait < 60 do -- 허브가 다 지어지기 전이면 기다린다
			task.wait(2)
			spotWait += 2
		end
		if not slab then
			warn("[D1] 명예의 전당 자리(Spot = hallOfFame)를 60초 동안 못 찾음 - 석판 없음(목록은 계속 읽는다)")
		end
		while true do
			HallOfFame.refresh()
			task.wait(PrimordialData.hallRefreshSeconds)
		end
	end)
end

return HallOfFame
