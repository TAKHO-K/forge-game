-- UI-1c 3단계 마을 명예의 전당 게시판(I v1 §1-1 · sheet_02): 게시판 파트만 세운다(겉면 그림 · [E] = 클라 HallBoardView).
--   hub_hall 메시에는 게시판 파트가 없어(HubArtMeta parts = Body · Columns · Door · …) 데이터 크기(UiLayoutData.hall.board: 1200 × 800 ÷ 50 = 24 × 16 stud)로 새로 세운다.
--   자리 = 명예의 전당 자리 표시(Spot = "hallOfFame") 기준 오프셋 · 스위치 UiV2Flags.hall 끔 = 안 세움.
local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if not require(ReplicatedStorage.Shared.data.UiV2Flags).hall then
	return
end

local B = require(ReplicatedStorage.Shared.data.UiLayoutData).hall.board
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local function findSpot()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst:GetAttribute("Spot") == "hallOfFame" then
			return inst
		end
	end
	return nil
end

task.spawn(function()
	local spot
	for _ = 1, 60 do
		spot = findSpot()
		if spot then
			break
		end
		task.wait(1)
	end
	if not spot then
		warn("[UI-1c] 명예의 전당 자리(Spot = hallOfFame)를 60초 동안 못 찾음 - 게시판 없음")
		return
	end
	local w, h = B.canvas[1] / B.pps, B.canvas[2] / B.pps
	local model = Instance.new("Model")
	model.Name = "HallBoard"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Material = Enum.Material.Wood
	board.Color = Color3.fromHex(B.wood)
	board.Size = Vector3.new(w, h, B.depth)
	local at = spot.CFrame * CFrame.new(B.offset[1], 0, B.offset[3]) * CFrame.Angles(0, math.rad(B.yawDeg), 0)
	local bottom = WorldMapData.floorTopY + B.liftStuds
	board.CFrame = CFrame.new(at.Position.X, bottom + h / 2, at.Position.Z) * at.Rotation
	board.Parent = model
	model.PrimaryPart = board
	model.Parent = Workspace
	print(("[UI-1c] 명예의 전당 게시판 %d × %d stud · 자리 %s"):format(w, h, tostring(board.Position)))
end)
