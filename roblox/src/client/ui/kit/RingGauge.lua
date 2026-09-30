-- QUEUE-ALL1 01 B 매끈한 원형 게이지(활강 링 등): 얇은 조각 segments개를 원둘레에 이어 붙여 링처럼 보이게(이미지 없음). 12시에서 시계 방향으로 채운다.
--   RingGauge.build(parent, diameter, thickness, segments) → { root, set(fraction, color, trackColor) }
local RingGauge = {}

function RingGauge.build(parent, diameter, thickness, segments)
	segments = segments or 48
	local root = Instance.new("Frame")
	root.Name = "RingGauge"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(diameter, diameter)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Parent = parent
	local r = diameter / 2 - thickness / 2
	local len = 2 * r * math.sin(math.pi / segments) + 1.2 -- 이음새가 안 보이게 조금 겹친다
	local parts = {}
	for i = 1, segments do
		local a = (i - 0.5) / segments * 2 * math.pi -- 12시에서 시계 방향
		local seg = Instance.new("Frame")
		seg.BorderSizePixel = 0
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.Size = UDim2.fromOffset(len, thickness)
		seg.Position = UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r)
		seg.Rotation = math.deg(a)
		seg.Parent = root
		parts[i] = seg
	end
	local function set(fraction, color, trackColor)
		local lit = fraction * segments
		for i, seg in ipairs(parts) do
			seg.BackgroundColor3 = i <= lit + 1e-6 and color or trackColor
		end
	end
	return { root = root, set = set }
end

return RingGauge
