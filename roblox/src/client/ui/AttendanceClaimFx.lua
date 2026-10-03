-- QUEUE-ALL9B A 출석 받기 연출(공통 하나 - 일일 접속 보상 창 · 신규 7일 출석 창 · 시즌 출석판 창이 같은 함수를 부른다 · §7).
--   서버가 확정한 지급 표(QuestClaimResult)로만 그린다 - 클라가 미리 보상을 그리지 않는다. 전체 ≤ 1.0초(QUEUE-ALL9C 1-12 X5 - 옛 약 1.5초):
--   ① 0 ~ 0.25초 받은 칸에 도장(✓) "쾅" - 칸이 1.08배로 커졌다 돌아옴(번쩍임 줄이기 = 칸 색만 초록으로)
--   ② 0.15초 ~ 보상 아이콘 + "+개수"가 칸 위로 떠오름(0.12초) - 여러 개면 0.04초 간격(옛 0.25초 · 0.2초 간격)
--   ③ 떠오른 아이콘이 실제로 들어가는 곳으로 날아감(골드 · 토큰 · 강화석 … = 오른쪽 위 재화 칸 Cur_<id> · 알 = 알 칩 · 칭호 · 치장 = 상점 버튼) → 도착한 칸 한 번 반짝(번쩍임 줄이기 = 색만)
--   ④ 다음 칸(내일)에 은은한 금 테 + "내일 보상" 꼬리표 + 남은 시간(서버 UTC 자정까지) · 목록이 길면 다음 칸이 보이게 자동 스크롤
--   연출 중 화면을 한 번 더 누르면 ① ~ ④를 바로 끝 상태로(지급은 이미 서버가 끝냈다 - 표시만).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Text = require(ReplicatedStorage.Shared.Text)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local RewardIcons = require(script.Parent.RewardIcons)
local ArtImage = require(script.Parent.ArtImage)

local AttendanceClaimFx = {}

local player = Players.LocalPlayer
local CURRENCY = { gold = true, sparkleShard = true, enhanceStone = true, highEnhanceStone = true, gemDust = true }
local ORDER = { "gold", "sparkleShard", "enhanceStone", "highEnhanceStone", "gemDust", "egg", "title", "cosmeticItem", "passExp", "rebirthTicket" }

local gui, rootFrame, active
-- QUEUE-ALL9C 1-12 X5 시간(사용자 10-03): 아이콘 하나 = 떠오름 + 날아감 0.35 ~ 0.45초 · 간격 0.04초 · 전체 ≤ 1.0초 · 누르면 즉시 끝(재화 숫자는 바로 바뀌어 같이 끝난다 - 카운트업 없음)
local T_START, T_RISE, T_FLY, T_GAP, T_MAX = 0.15, 0.12, 0.28, 0.04, 1.0
AttendanceClaimFx.timing = { start = T_START, rise = T_RISE, fly = T_FLY, gap = T_GAP, max = T_MAX }
-- n개 보상의 전체 길이(초) - 마지막 아이콘 도착 + 0.05 · 상한 T_MAX(간격을 줄여 맞춘다)
function AttendanceClaimFx.totalSeconds(n)
	local gap = n > 1 and math.min(T_GAP, (T_MAX - 0.05 - T_START - T_RISE - T_FLY) / (n - 1)) or 0
	return math.min(T_MAX, T_START + math.max(0, n - 1) * gap + T_RISE + T_FLY + 0.05), gap
end

-- 연출 루트(전용 ScreenGui · 창 overlay 대역 위). 좌표 = 다른 창의 AbsolutePosition - 루트 AbsolutePosition(Fly 모듈과 같은 방식 - 인셋 차이 없음)
local function ensureGui()
	if gui and gui.Parent then
		return rootFrame
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "AttendanceFxGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 270
	gui.Parent = player:WaitForChild("PlayerGui")
	rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.BackgroundTransparency = 1
	rootFrame.Size = UDim2.fromScale(1, 1)
	rootFrame.Parent = gui
	return rootFrame
end
local function rel(v)
	local o = rootFrame.AbsolutePosition
	return UDim2.fromOffset(v.X - o.X, v.Y - o.Y)
end

local function reduced()
	return player:GetAttribute("ReduceFlashes") == true
end

-- 보상 키 → 날아갈 곳(절대 중심 · 반짝일 GuiObject)
function AttendanceClaimFx.targetFor(key)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local target
	if CURRENCY[key] then
		local stack = pg:FindFirstChild("CurrencyStack", true)
		local item = stack and stack:FindFirstChild("Cur_" .. key, true)
		local drawer = stack and stack:FindFirstChild("CurrencyDrawer")
		if item and item:IsDescendantOf(drawer or item) and drawer and not drawer.Visible then
			item = stack:FindFirstChild("GoldChip") -- 서랍이 접혀 있으면 재화 칸으로
		end
		target = item
	elseif key == "egg" then
		target = pg:FindFirstChild("EggButton", true)
	elseif key == "title" or key == "cosmeticItem" then
		target = pg:FindFirstChild("MenuButton_shop", true)
	end
	if not target or not target:IsA("GuiObject") or target.AbsoluteSize.X <= 0 then
		return nil
	end
	return target.AbsolutePosition + target.AbsoluteSize / 2, target
end

local function pulse(target, tracks)
	if not target then
		return
	end
	if reduced() then
		local ok = pcall(function()
			local old = target.BackgroundColor3
			target.BackgroundColor3 = UIColors.success
			task.delay(0.25, function()
				if target.Parent then
					target.BackgroundColor3 = old
				end
			end)
		end)
		return ok
	end
	local scale = target:FindFirstChild("ClaimFxScale") or Instance.new("UIScale")
	scale.Name = "ClaimFxScale"
	scale.Parent = target
	local t = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Scale = 1.12 })
	table.insert(tracks, t)
	t:Play()
end

-- ④ 다음 칸(내일) 표시: 금 테 + "내일 보상 · 남은 시간" 꼬리표 · 목록 안에 보이게 스크롤(창이 칸을 다시 그린 뒤에도 부른다)
function AttendanceClaimFx.markNext(nextCell, resetIn, scroll)
	if not nextCell or not nextCell.Parent then
		return
	end
	local stroke = nextCell:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = UIColors.gold
		stroke.Thickness = 2
	end
	local tag = nextCell:FindFirstChild("TomorrowTag")
	if not tag then
		tag = Instance.new("TextLabel")
		tag.Name = "TomorrowTag"
		tag.BackgroundColor3 = UIColors.gold
		tag.BackgroundTransparency = 0.1
		tag.TextColor3 = UIColors.panel
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 11
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.Size = UDim2.fromOffset(0, 16)
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.new(0.5, 0, 1, -2)
		tag.ZIndex = 5
		tag.Parent = nextCell
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = tag
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = tag
	end
	local left = math.max(0, resetIn or 0)
	tag.Text = Text.get("claimFx.tomorrow", { h = tostring(math.floor(left / 3600)), m = tostring(math.floor(left % 3600 / 60)) })
	if scroll and scroll:IsA("ScrollingFrame") then
		local top = nextCell.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		local bottom = top + nextCell.AbsoluteSize.Y
		local view = scroll.AbsoluteSize.Y
		if bottom > scroll.CanvasPosition.Y + view or top < scroll.CanvasPosition.Y then
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.max(0, bottom - view + 6))
		end
	end
end

function AttendanceClaimFx.isPlaying()
	return active ~= nil
end

-- opts = { cell = 받은 칸(GuiObject), nextCell = 내일 칸(nil 가능), scroll = 칸 목록 ScrollingFrame(nil 가능), granted = { 키 = 개수 }, resetIn = 다음 초기화까지 초, onDone = 끝 콜백 }
function AttendanceClaimFx.play(opts)
	if active then
		active.finish()
	end
	-- Studio 전용: 단계별 캡처용 느린 재생(player Attribute DebugFxSlow = 배율 · 출시 = 1)
	local k = game:GetService("RunService"):IsStudio() and tonumber(player:GetAttribute("DebugFxSlow")) or 1
	local function T(sec, ...)
		return TweenInfo.new(sec * k, ...)
	end
	local root = ensureGui()
	local temp, tracks, done = {}, {}, false
	local cell, nextCell = opts.cell, opts.nextCell
	local function add(inst)
		table.insert(temp, inst)
		return inst
	end
	-- ④ 끝 상태(건너뛰기 · 정상 끝 공통)
	local function settleNext()
		AttendanceClaimFx.markNext(nextCell, opts.resetIn, opts.scroll)
	end
	local function finish()
		if done then
			return
		end
		done = true
		for _, t in ipairs(tracks) do
			t:Cancel()
		end
		for _, inst in ipairs(temp) do
			inst:Destroy()
		end
		if cell and cell.Parent then
			local s = cell:FindFirstChild("ClaimFxScale")
			if s then
				s.Scale = 1
			end
		end
		settleNext()
		active = nil
		if opts.onDone then
			task.defer(opts.onDone)
		end
	end
	active = { finish = finish }
	-- 건너뛰기: 연출 중 화면 아무 곳이나 한 번 더 누르면 끝 상태로
	local skip = add(Instance.new("TextButton"))
	skip.Name = "SkipCatcher"
	skip.Text = ""
	skip.BackgroundTransparency = 1
	skip.Size = UDim2.fromScale(1, 1)
	skip.ZIndex = 1
	skip.Parent = root
	skip.Activated:Connect(finish)

	-- ① 도장
	if cell and cell.Parent then
		local center = cell.AbsolutePosition + cell.AbsoluteSize / 2
		local stamp = add(Instance.new("TextLabel"))
		stamp.Name = "Stamp"
		stamp.BackgroundTransparency = 1
		stamp.Text = "✓"
		stamp.Font = Enum.Font.GothamBold -- GothamBlack에는 ✓ 글자가 없다(빈칸)
		stamp.TextColor3 = UIColors.gold -- 초록 받기 버튼 위에서도 보이게(금 + 진한 외곽선)
		stamp.TextStrokeColor3 = Color3.fromRGB(30, 24, 10)
		stamp.TextStrokeTransparency = 0
		stamp.TextSize = 44
		stamp.AnchorPoint = Vector2.new(0.5, 0.5)
		stamp.Position = rel(center)
		stamp.Size = UDim2.fromOffset(60, 60)
		stamp.ZIndex = 3
		stamp.Parent = root
		if reduced() then
			stamp.TextTransparency = 0.2
		else
			local s = Instance.new("UIScale")
			s.Scale = 1.8
			s.Parent = stamp
			local t = TweenService:Create(s, T(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			table.insert(tracks, t)
			t:Play()
			local cs = cell:FindFirstChild("ClaimFxScale") or Instance.new("UIScale")
			cs.Name = "ClaimFxScale"
			cs.Parent = cell
			local t2 = TweenService:Create(cs, T(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Scale = 1.08 })
			table.insert(tracks, t2)
			t2:Play()
		end
		local fade = TweenService:Create(stamp, T(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.9), { TextTransparency = 1 })
		table.insert(tracks, fade)
		fade:Play()
	end

	-- ② · ③ 보상 떠오름 → 날아감
	local keys = {}
	for _, k in ipairs(ORDER) do
		if opts.granted and opts.granted[k] then
			table.insert(keys, k)
		end
	end
	local from = cell and cell.Parent and (cell.AbsolutePosition + Vector2.new(cell.AbsoluteSize.X / 2, 0)) or (root.AbsolutePosition + root.AbsoluteSize / 2)
	local total, gap = AttendanceClaimFx.totalSeconds(#keys)
	for i, key in ipairs(keys) do
		task.delay((T_START + (i - 1) * gap) * k, function()
			if done then
				return
			end
			local v = opts.granted[key]
			local pop = add(Instance.new("Frame"))
			pop.Name = "Pop_" .. key
			pop.BackgroundTransparency = 1
			pop.AnchorPoint = Vector2.new(0.5, 1)
			pop.AutomaticSize = Enum.AutomaticSize.X
			pop.Size = UDim2.fromOffset(0, 26)
			pop.Position = rel(from)
			pop.ZIndex = 4
			pop.Parent = root
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0, 4)
			layout.Parent = pop
			local icon = ArtImage.label(pop, "icons/reward/" .. (RewardIcons.icon[key] or key), UDim2.fromOffset(24, 24), "")
			icon.ZIndex = 4
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.AutomaticSize = Enum.AutomaticSize.X
			label.Size = UDim2.fromOffset(0, 24)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 16
			label.TextColor3 = UIColors.gold
			label.TextStrokeTransparency = 0.4
			label.Text = type(v) == "number" and ("+" .. NumberFormat.currency(v, Text.languageFor())) or ""
			label.ZIndex = 4
			label.Parent = pop
			local rise = TweenService:Create(pop, T(T_RISE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = rel(from - Vector2.new(0, 22)) })
			table.insert(tracks, rise)
			rise:Play()
			task.delay(T_RISE * k, function()
				if done then
					return
				end
				local to, target = AttendanceClaimFx.targetFor(key)
				if not to then -- 들어갈 칸이 화면에 없는 보상(패스 경험치 등) = 제자리에서 흐려짐
					for _, d in ipairs(pop:GetDescendants()) do
						if d:IsA("TextLabel") or d:IsA("ImageLabel") then
							local fade = TweenService:Create(d, T(T_FLY), d:IsA("TextLabel") and { TextTransparency = 1, TextStrokeTransparency = 1 } or { ImageTransparency = 1 })
							table.insert(tracks, fade)
							fade:Play()
						end
					end
					return
				end
				local fly = TweenService:Create(pop, T(T_FLY, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = rel(to + Vector2.new(0, 12)) })
				table.insert(tracks, fly)
				fly.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed then
						pop.Visible = false
						pulse(target, tracks)
					end
				end)
				fly:Play()
			end)
		end)
	end
	-- ④ + 끝(전체 ≤ 1.0초 - 마지막 아이콘 도착 뒤)
	task.delay(total * k, finish)
	return active
end

-- 지금 연출 중이면 끝 상태로(창이 닫힐 때 등)
function AttendanceClaimFx.finish()
	if active then
		active.finish()
	end
end

return AttendanceClaimFx
