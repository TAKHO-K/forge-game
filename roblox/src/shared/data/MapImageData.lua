-- QUEUE-ALL7 D 구운 지도 이미지(roblox/tools/mapgen - 맵을 고치면 다시 굽기 · README 같은 절차) + 좌표식(한 곳 - 미니맵 · 지도 창 · 핀 · 길 안내가 같은 식).
--   이미지 = 2 × 2 타일(각 1024² · 전체 2048² = 세계 2 × edge.radius) · 행 = 위(−Z) → 아래 · 열 = 왼(−X) → 오른. 경로 = ArtAssetIds 키(upload.py).
--   u = (x + half) / (2 · half) · v = (z + half) / (2 · half) (0 ~ 1 · 위 = −Z).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local M = {}
M.half = WorldMapData.edge.radius -- 세계 반폭(stud)
M.tiles = {
	{ "map/world_0_0", "map/world_0_1" },
	{ "map/world_1_0", "map/world_1_1" },
}
M.pixels = 2048 -- 전체 한 변(px)
M.mini = "map/world_mini" -- 미니맵 한 장(1024² - ImageRect로 보이는 칸만 잘라 UICorner 원형 · Rotation 회전 · ClipsDescendants 없이)
M.miniPixels = 1024
M.bakedAt = "2026-10-02" -- 굽은 날(맵을 고치면 다시 굽고 바꾼다)

function M.toUV(x, z)
	return Vector2.new((x + M.half) / (2 * M.half), (z + M.half) / (2 * M.half))
end

function M.toWorld(u, v, y)
	return Vector3.new(u * 2 * M.half - M.half, y or WorldMapData.floorTopY, v * 2 * M.half - M.half)
end

return M
