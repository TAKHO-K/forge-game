-- 몬스터 · 보스 겉모습 조립(G1-1 - 서버 MonsterSpawner에서 꺼냈다). 서버 모델과 나중의 클라 뷰포트(보스 미리보기 - BR-8)가 같은 함수로 같은 모양을 짓는다.
-- 판정과 무관하다(보이는 파트만 - 크기 · 색 · 자리). 옛 MonsterSpawner.buildModel의 루트 · 몸통 · 머리 · 부착물 코드를 그대로 옮겼다(값 · 순서 · 이름 불변 -
-- BossGimmick5Verify가 분신과 보스의 하위 인스턴스 수를 대조한다).
-- look = { sizeScale, bodyColor, headColor, bodyAspect(Vector3, 기본 1,1,1), attachments(BossData SPECIES의 부착물 표 - 없으면 nil) }.
local BossLook = {}

-- 루트(투명) · 몸통 · 머리를 model 아래에 짓는다. position = 루트 자리. 반환: root, body, head.
-- 높이(bodyAspect.Y)가 바뀌어도 발이 원래 자리(position.Y - 1.5 × sizeScale)에 붙도록 몸통 중심을 다시 잡는다(23-6).
function BossLook.buildCore(model, look, position)
	local sizeScale = look.sizeScale or 1
	local bodyAspect = look.bodyAspect or Vector3.new(1, 1, 1)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * sizeScale
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model

	local bodyHalfHeight = 1.5 * sizeScale * bodyAspect.Y
	local bodyBottomY = position.Y - 1.5 * sizeScale
	local bodyCenterY = bodyBottomY + bodyHalfHeight

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.4 * bodyAspect.X, 3 * bodyAspect.Y, 1.2 * bodyAspect.Z) * sizeScale
	body.Anchored = true
	body.CanCollide = false -- 21-3 · 22-5: 몸통 · 머리는 캐릭터와 충돌하지 않는다(판정은 전부 거리 기반 - MonsterSpawner 옛 주석)
	body.Color = look.bodyColor
	body.Position = Vector3.new(position.X, bodyCenterY, position.Z)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6) * sizeScale
	head.Anchored = true
	head.CanCollide = false
	head.Color = look.headColor
	head.Position = Vector3.new(position.X, bodyBottomY + 2 * bodyHalfHeight + 0.8 * sizeScale, position.Z)
	head.Parent = model

	return root, body, head
end

-- 23-6 [3] 보스 실루엣 부착물(기존 파트 조합만). anchor "body" | "head" - 그 파트의 실제 위치를 기준으로 offset(사이즈 배율 전 stud)만큼. CanCollide = false라 판정과 무관.
function BossLook.buildAttachments(model, look, bodyPosition, headPosition)
	local sizeScale = look.sizeScale or 1
	for _, spec in ipairs(look.attachments or {}) do
		local part
		if spec.kind == "wedge" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			if spec.kind == "ball" then
				part.Shape = Enum.PartType.Ball
			end
		end
		part.Name = spec.name or "BossAttachment"
		part.Size = spec.size * sizeScale
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Color = (spec.color == "head") and look.headColor or look.bodyColor
		local anchorPosition = (spec.anchor == "head") and headPosition or bodyPosition
		local rot = spec.rotationDeg or Vector3.new(0, 0, 0)
		part.CFrame = CFrame.new(anchorPosition + spec.offset * sizeScale) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		part.Parent = model
	end
end

return BossLook
