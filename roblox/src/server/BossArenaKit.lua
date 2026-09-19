-- 보스별 아레나 지형지물 kit(29-2 훅, PRD 20.73 [2-7]). 아레나는 슬롯(12개)당 하나이고 보스 종과 무관하게
-- 재사용되므로(BossEncounter.buildArena - 한 번 지으면 서버가 꺼질 때까지 유지), 보스별 정적 지형(단·경사로·
-- 피뢰침·벽 수정·유사·장식)은 **보스전이 시작될 때 짓고 끝날 때 치운다**. 6종을 슬롯마다 미리 지어 두면
-- 12 × 6 × 40 = 2,880파트라 기각됐다.
--
-- kit 정의는 BossData.bosses[id].arenaKit(29-3 전갈 여왕 · 29-4 심해 군주·폭풍 군주):
--   arenaKit = { parts = { { name, size(Vector3), offset(Vector3 - 아레나 중심·바닥 윗면 기준), rotationDeg?(Vector3),
--                           color(Color3 - 기존 색만), material?(Enum.Material), ground?(bool), collide?(bool),
--                           shape?("cylinder" - 29-3 유사 웅덩이 같은 원판), tag?·radiusStuds?(스킬이 읽는 논리 구역) }, ... } }
--   ground = true면 GroundProbe 폴더에 둔다 - 보스 지면 추적·돌진 Y·드랍 스냅이 그 위를 "땅"으로 본다(단·경사로).
-- 상한(20.73 [2-7]): 정적 ≤ 40파트. 넘으면 짓지 않고 경고만 낸다 - 12인 예산("보스 아레나 몫 ≤ 900파트")의 전제다.
-- 움직이는 지형(얼음 기둥·물 평면·먹구름)은 여기가 아니다 - 서버는 논리 상태만 갖고 클라가 그린다.

local Workspace = game:GetService("Workspace")

local GroundProbe = require(script.Parent.GroundProbe)

local BossArenaKit = {}

local MAX_STATIC_PARTS = 40

-- 반환: 지은 파트 목록(없으면 빈 목록). zone = WorldConfig.zones[bossArenaN], floorTopY = 아레나 바닥 윗면 Y.
function BossArenaKit.build(kit, zone, floorTopY)
	local built = {}
	if not kit or not kit.parts then
		return built
	end
	if #kit.parts > MAX_STATIC_PARTS then
		warn(("[forge-game] 아레나 kit이 상한(%d파트)을 넘는다: %d - 짓지 않는다"):format(MAX_STATIC_PARTS, #kit.parts))
		return built
	end
	local origin = Vector3.new(zone.center.X, floorTopY, zone.center.Z)
	for _, spec in ipairs(kit.parts) do
		local part = Instance.new("Part")
		part.Name = spec.name or "BossArenaKitPart"
		part.Anchored = true
		part.CanCollide = spec.collide ~= false
		part.Material = spec.material or Enum.Material.Slate
		part.Color = spec.color
		part.Size = spec.size
		if spec.shape == "cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		local rotation = spec.rotationDeg or Vector3.zero
		part.CFrame = CFrame.new(origin + spec.offset) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		part.Parent = spec.ground and GroundProbe.folder() or Workspace
		table.insert(built, part)
	end
	return built
end

function BossArenaKit.destroy(built)
	for _, part in ipairs(built or {}) do
		part:Destroy()
	end
end

return BossArenaKit
