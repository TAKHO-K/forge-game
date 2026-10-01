-- QUEUE-ALL2 P4 1순위 ⑥(초월 세트 줄) · 2순위(도감 칸 완성 · 줄 칭호 크게): 도감 창과 같은 CodexUpdate 표를 한 번 더 듣고 "바뀐 순간"만 알린다(판정 · 받기 없음).
--   첫 표 = 기준(알림 없음) · 그다음 표에서 done이 false → true가 된 칸 · 줄만 본다. 창(panels/Codex)은 건드리지 않는다.
--   칸 완성 = 작은 배너(그림 + "도감 칸 완성: 이름 [외 n]" · 1.6초 · cellBatchSeconds 안은 한 장) ·
--   줄 칭호 = 금 배너(2.5초) + 발밑 금 링 · 초월 세트 줄(초월 기록이 있는 구역의 armorZone 줄) = 흑금 배너(3초) + 발밑 흑금 링 2겹. 전 화면 번쩍임 없음.
--   소리 = SoundHooks가 이미 낸다(칭호 = title_get · 받을 칸 생김 = codex_cell) - 여기서는 안 낸다. 아트 끔 = 없음 · 연출 세기 끔 = 배너만(팝 · 광택 · 링 없음).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local CodexRules = require(ReplicatedStorage.Shared.CodexRules)
local Text = require(ReplicatedStorage.Shared.Text)
local CX = require(ReplicatedStorage.Shared.data.FxMomentData).codex
local FxMoment = require(script.Parent.FxMoment)
local ArtV1Fx = require(script.Parent.ArtV1Fx)
local ArtImage = require(script.Parent.ui.ArtImage)
local Info = require(script.Parent.panels.CodexV2.Info) -- 칸 그림 · 이름(읽기만 - 창과 같은 규칙)

local player = Players.LocalPlayer
local lastView = nil
local pendingCells = {}
local batchOpen = false

local function feetRing(size, seconds, color, thick)
	local pos = ArtV1Fx.feetOf(player.Character)
	if pos then
		ArtV1Fx.ring(pos, size, seconds, color, thick or 0.14, 0.1)
	end
end

local function cellName(view, id)
	local c = view.cells[id]
	if c and c.label then
		return Text.name(c.label)
	end
	local m = Info.meta(id)
	return m and (Info.detailName(view, m)) or id
end

local function cellImage(view, id)
	local m = Info.meta(id)
	if not m then
		return nil
	end
	local pic = Info.picture(view, m)
	return { image = ArtImage.get(pic.key), silhouette = pic.silhouette }
end

local function flushCells()
	batchOpen = false
	local ids = pendingCells
	pendingCells = {}
	local view = lastView
	if #ids == 0 or not view then
		return
	end
	local name = cellName(view, ids[1])
	local text = #ids > 1 and Text.get("moment.cellDoneMore", { name = name, n = #ids - 1 }) or Text.get("moment.cellDone", { name = name })
	FxMoment.banner("cell", text, nil, cellImage(view, ids[1]))
end

local function onLineDone(view, id, l)
	local zone = id:match("^armorZone:(.+)$")
	local name = l.titleName and CodexRules.titleText(l.titleId, l.titleName) or l.titleId or id
	local strength = FxMoment.scale()
	if zone and type(view.trans) == "table" and view.trans[zone] then
		FxMoment.banner("trans", Text.get("moment.transTitle"), Text.get("moment.transSub", { zone = CodexData.zoneShort[zone] or zone, name = name }))
		if strength > 0 then
			local R = CX.transRing
			feetRing(R.size * (0.6 + 0.4 * strength), R.seconds, R.color, 0.2)
			feetRing(R.size * 0.6 * (0.6 + 0.4 * strength), R.seconds * 0.8, R.innerColor, 0.24)
		end
	else
		FxMoment.banner("line", Text.get("moment.lineTitle", { name = name }))
		if strength > 0 then
			local R = CX.lineRing
			feetRing(R.size * (0.6 + 0.4 * strength), R.seconds, R.color)
		end
	end
end

local function onView(view)
	if type(view) ~= "table" or type(view.cells) ~= "table" or type(view.lines) ~= "table" then
		return
	end
	local prev = lastView
	lastView = view
	Info.indexNests(view)
	if not prev or not FxMoment.isOn() then
		return -- 첫 표 = 기준
	end
	for id, l in pairs(view.lines) do
		local was = prev.lines[id]
		if l.done and was and not was.done then
			onLineDone(view, id, l)
		end
	end
	for id, c in pairs(view.cells) do
		local was = prev.cells[id]
		if c.done and was and not was.done then
			table.insert(pendingCells, id)
		end
	end
	if #pendingCells > 0 and not batchOpen then
		batchOpen = true
		task.delay(CX.cellBatchSeconds, flushCells)
	end
end

local update = ReplicatedStorage:WaitForChild("CodexUpdate")
update.OnClientEvent:Connect(onView)

-- 기준 표: CodexUI가 시작 때 "view"를 보내지만 프로필이 늦으면 답이 없다 → 아직 표가 없으면 한 번 더(두 번까지)
task.spawn(function()
	local request = ReplicatedStorage:WaitForChild("CodexRequest")
	for _, delaySeconds in ipairs({ CX.firstViewDelay, CX.retryViewSeconds }) do
		task.wait(delaySeconds)
		if lastView then
			return
		end
		request:FireServer("view")
	end
end)
