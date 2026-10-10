-- UI-1c 4단계 도감 v3 탭 그리기(I v1 §2 · pc_03 ~ pc_06 · ph_02 ~ ph_04 · 스위치 UiV2Flags.codexV3): 창(panels/Codex)이 탭 본문 ScrollingFrame에 그린다.
--   무기 = 4종 × 8등급 32칸 한 화면(PC 칸 89 × 160 세로 그림 · 폰 정사각 44 = 가방과 같은 weapon-* 그림) · 보스 = 처치 1 · 3 · 5 · 10 · 20회 단계 테(등급색과 다른 색 · 20 = 무지개 + 빛줄기) ·
--   탐험 = 구역별 번호 알(번호 알약 늘 보임 · 찾음 = 알 + 체크 · 못 찾음 = ?) · 칭호 = 모은 n / 전체 · 못 얻은 칭호 = ???(서버가 이름 · 조건을 안 보냄).
--   칸 id · 받기 = 옛 그리드와 같은 칸 id(CodexCell) · S.select · S.claim(서버 판정 그대로). 좌표 · 색 = UiLayoutData.codexV3.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local CodexRules = require(ReplicatedStorage.Shared.CodexRules)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local Text = require(ReplicatedStorage.Shared.Text)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).codexV3
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)
local V9 = require(script.Parent.Parent.Parent.ui.v2.UiV9)
local BossPortrait = require(script.Parent.Parent.Parent.ui.v2.BossPortrait)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local Info = require(script.Parent.Info)

local V3 = {}
local hex, px, frame, label, corner, stroke = V9.hex, V9.px, V9.frame, V9.label, V9.corner, V9.stroke
local C = L.colors
local player = Players.LocalPlayer

local WEAPON_STEM = { greatsword = "gs", dualblade = "db", bow = "bow", healer = "staff" }
local WEAPON_ICON = { greatsword = "atk-sword", dualblade = "atk-dagger", bow = "atk-bow", healer = "atk-staff" }

local function P(S)
	return S.phone and L.phone or L.pc
end

local function redDot(parent, size)
	local d = Instance.new("Frame")
	d.Name = "Dot"
	d.AnchorPoint = Vector2.new(1, 0)
	d.Position = UDim2.new(1, -3, 0, 3)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
	d.ZIndex = 5
	d.Parent = parent
	corner(d, "pill")
	return d
end

-- 탭 진행 %(그 탭 칸 중 완료) · 받을 것 있음
function V3.tabStats(view, tabId)
	local done, total, claim = 0, 0, false
	for _, c in pairs(view.cells) do
		if c.tab == tabId then
			total += 1
			if c.done then
				done += 1
				claim = claim or not c.claimed
			end
		end
	end
	if tabId == "title" then
		local have = 0
		for _, t in ipairs(view.titles or {}) do
			have += t.hidden and 0 or 1
		end
		return view.titleTotal and view.titleTotal > 0 and math.floor(have / view.titleTotal * 100) or nil, false
	end
	return total > 0 and math.floor(done / total * 100) or nil, claim
end

-- ═══ 무기(직업) 탭 ═══
local function lineOfClass(view, classId)
	for id, l in pairs(view.lines) do
		if l.tab == "class" and id:find(classId, 1, true) then
			return l
		end
	end
	return nil
end

function V3.renderClass(S, scroll)
	local view = S.view
	local W = P(S).weapon
	local phone = S.phone
	local y = 0
	if not phone then -- 머리 줄: 무기 · 등급 + 등급 알약 8 + 줄 칭호
		label(scroll, Text.get("ui1c.codex.weaponGrade"), px(15), C.muted, { rect = { 16, 0, W.headW, W.gradeRowH } })
		for g = 0, 7 do
			local gradeId = ArmorData.gradeOrder[g + 1]
			local x = 8 + W.headW + g * (W.cw + W.gap)
			local pill = label(scroll, Text.name(ArmorData.grades[gradeId].displayName), px(15), "FFFFFF", { name = "Grade" .. g, align = Enum.TextXAlignment.Center, rect = { x + 4, 4, W.cw - 8, W.gradeRowH - 8 } })
			pill.BackgroundTransparency = 0
			pill.BackgroundColor3 = GradeColor.border(gradeId)
			local c3 = pill.BackgroundColor3
			if 0.299 * c3.R + 0.587 * c3.G + 0.114 * c3.B > 0.7 then -- 밝은 등급(태초 흰색 등) = 어두운 글자
				pill.TextColor3 = hex("1A1F33")
			end
			corner(pill, "pill")
		end
		label(scroll, Text.get("ui1c.codex.lineTitle"), px(15), C.muted, { rect = { 8 + W.headW + 8 * (W.cw + W.gap) + 6, 0, W.titleW, W.gradeRowH } })
		y = W.gradeRowH + 6
	end
	for _, classId in ipairs(ClassData.order) do
		local stem = WEAPON_STEM[classId] or "gs"
		local starRec = view.stars and view.stars[classId] or {}
		local got, stars = 0, 0
		local cells = {}
		for g = 0, 7 do
			local id = g == 7 and ("cls:%s:t"):format(classId) or ("cls:%s:%d"):format(classId, g)
			local cv = view.cells[id]
			if cv and cv.done then
				got += 1
				stars += math.clamp(tonumber(starRec[tostring(g)]) or 1, 1, 3)
			end
			table.insert(cells, { id = id, cv = cv, g = g })
		end
		local rowW = W.headW + 8 * (W.cw + W.gap) + (phone and 0 or (W.titleW + 12))
		local row = frame(scroll, { 0, y, rowW + 8, W.ch + W.rowGap }, phone and nil or "232A44", "Row_" .. classId)
		corner(row, 10)
		if got >= 7 and not phone then -- 줄 완성 = 금 바탕 + 금 테
			row.BackgroundColor3 = hex("4A3A14")
			stroke(row, C.gold, 2)
		end
		-- 줄 머리
		local hx = phone and 0 or 14
		if WEAPON_ICON[classId] and UiKit.hasIcon(WEAPON_ICON[classId]) then
			local ic = UiKit.icon(row, WEAPON_ICON[classId], phone and 24 or 40)
			ic.Position = UDim2.fromOffset(hx, phone and math.floor((W.ch - 24) / 2) or 14)
		end
		if phone then
			label(row, ("%d/8"):format(got), px(13), got >= 7 and C.gold or "FFFFFF", { name = "Count", rect = { 28, 0, W.headW - 30, W.ch } })
		else
			label(row, Text.get("class.name." .. classId), px(22), got >= 7 and C.gold or "FFFFFF", { name = "Name", rect = { hx, 62, W.headW - 20, 28 } })
			label(row, ("%d / 8"):format(got), px(20), got >= 7 and C.gold or "FFFFFF", { name = "Count", font = "number", rect = { hx, 94, W.headW - 20, 24 } })
			label(row, ("★ %d / 24"):format(stars), px(16), C.gold, { name = "Stars", rect = { hx, 122, W.headW - 20, 20 } })
		end
		for i, e in ipairs(cells) do
			local x = W.headW + (i - 1) * (W.cw + W.gap)
			local done = e.cv and e.cv.done
			local gradeId = ArmorData.gradeOrder[e.g + 1]
			local b = Instance.new("TextButton")
			b.Name = "Cell"
			b.Text = ""
			b.AutoButtonColor = false
			b.Position = UDim2.fromOffset(x, math.floor(W.rowGap / 2))
			b.Size = UDim2.fromOffset(W.cw, W.ch)
			b.BackgroundColor3 = done and hex("1A1F33") or hex("3A4262")
			b.ClipsDescendants = true
			b:SetAttribute("CodexCell", e.id)
			b:SetAttribute("CodexState", done and (e.cv.claimed and "done" or "claim") or "idle")
			b.Parent = row
			corner(b, phone and 6 or 10)
			local sel = S.selected and S.selected.id == e.id
			stroke(b, sel and "FFFFFF" or (done and GradeColor.border(gradeId) or hex("5A6280")), sel and 3 or 2)
			local img = Instance.new("ImageLabel")
			img.Name = "Pic"
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			if W.square then -- 폰 = 가방과 같은 정사각 그림(못 얻음 = 검은 실루엣)
				img.ScaleType = Enum.ScaleType.Fit
				img.Image = ArtImage.get(("ui/weapon/weapon-%s-g%d"):format(stem, e.g + 1)) or ""
				if not done then
					img.ImageColor3 = Color3.new(0, 0, 0)
					img.ImageTransparency = 0.35
				end
			else
				img.ScaleType = Enum.ScaleType.Stretch
				img.Image = ArtImage.get(("ui/codex/codex_%s_g%d_%s"):format(stem, e.g + 1, done and "color" or "silhouette")) or ""
			end
			img.Parent = b
			if not W.square then -- 아래 띠 22: 별 3(얻음) · 얻는 곳(못 얻음)
				local band = frame(b, { 0, W.ch - W.band, W.cw, W.band }, "0E1120", "Band")
				band.BackgroundTransparency = 0.2
				if done then
					local n = math.clamp(tonumber(starRec[tostring(e.g)]) or 1, 1, 3)
					for k = 1, 3 do
						local s = Instance.new("ImageLabel")
						s.BackgroundTransparency = 1
						s.Image = ArtImage.get(k <= n and "ui/codex/codex-star-on" or "ui/codex/codex-star-off") or ""
						s.Size = UDim2.fromOffset(14, 14)
						s.AnchorPoint = Vector2.new(0.5, 0.5)
						s.Position = UDim2.new(0.5, (k - 2) * 17, 0.5, 0)
						s.Parent = band
					end
				else
					label(band, Text.get(e.g == 7 and "ui1.codex.hintTranscend" or "ui1.codex.hintRebirth", { n = tostring(e.g) }), px(15), C.muted, { align = Enum.TextXAlignment.Center, rect = { 0, 0, W.cw, W.band } })
				end
			end
			if done and not e.cv.claimed then
				redDot(b, phone and 8 or 12)
			end
			b.Activated:Connect(function()
				S.select({ kind = "cell", id = e.id })
			end)
		end
		if not phone then -- 줄 칭호 칩 1개(글자 1.3에서도 1개 - spec 0-1)
			local l = lineOfClass(view, classId)
			local chip = frame(row, { W.headW + 8 * (W.cw + W.gap) + 6, 14, W.titleW, 68 }, l and l.done and "4A3A14" or "1B2133", "LineTitle")
			corner(chip, 8)
			stroke(chip, l and l.done and C.gold or C.stroke, 2)
			local ic = ArtImage.label(chip, "icons/reward/title", UDim2.fromOffset(22, 22), "")
			ic.Position = UDim2.fromOffset(10, 10)
			label(chip, l and CodexRules.titleText(l.titleId, l.titleName) or "", px(18), l and l.done and C.gold or "FFFFFF", { name = "Title", rect = { 38, 6, W.titleW - 44, 28 } })
			label(chip, l and l.done and Text.get("ui1c.codex.lineDone") or Text.get("ui1c.codex.lineProgress", { n = tostring(got) }), px(15), C.muted, { name = "State", rect = { 12, 36, W.titleW - 20, 24 } })
		end
		y += W.ch + W.rowGap + (phone and 0 or 6)
	end
	scroll.CanvasSize = UDim2.fromOffset(0, y)
end

-- ═══ 보스 탭 ═══
local lastTier = {} -- [보스] = 마지막으로 그린 단계(오를 때 = 토스트 + 테 바뀜 연출)
local beamConns = {}

local function tierOf(kills)
	local idx = 1
	for i, t in ipairs(L.bossTiers) do
		if kills >= t.n then
			idx = i
		end
	end
	return idx
end

local function killsOf(view, bossId)
	if view.bossKills and view.bossKills[bossId] then
		return view.bossKills[bossId]
	end
	local c = view.cells[("boss:%s:20"):format(bossId)]
	return c and c.v or 0
end

function V3.renderBoss(S, scroll)
	for _, c in ipairs(beamConns) do
		c:Disconnect()
	end
	table.clear(beamConns)
	local view = S.view
	local B = P(S).boss
	local phone = S.phone
	local x = 0
	for _, z in ipairs(Info.zones) do
		local bossId = z.bossId
		local kills = killsOf(view, bossId)
		local ti = tierOf(kills)
		local T = L.bossTiers[ti]
		local known = kills > 0
		local card = Instance.new("TextButton")
		card.Name = "Boss_" .. bossId
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Position = UDim2.fromOffset(x, 0)
		card.Size = UDim2.fromOffset(B.cardW, B.cardH)
		card.ClipsDescendants = true
		card:SetAttribute("CodexCell", "boss:" .. bossId)
		card.Parent = scroll
		corner(card, phone and 10 or 18)
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(hex(T.bg[1]), hex(T.bg[2]))
		g.Parent = card
		local st = stroke(card, T.stroke, phone and math.max(2, math.floor(T.sw * 0.6)) or T.sw)
		if T.rainbow then -- 20 = 무지개 테
			local keys = {}
			for i, h in ipairs(T.rainbow) do
				table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#T.rainbow - 1), hex(h)))
			end
			local rg = Instance.new("UIGradient")
			rg.Color = ColorSequence.new(keys)
			rg.Rotation = 45
			rg.Parent = st
			-- 빛줄기(초상 뒤 · 천천히 회전)
			local beam = frame(card, { math.floor(B.cardW / 2 - B.cardH * 0.6), math.floor(B.portrait * 0.5 - B.cardH * 0.6), math.floor(B.cardH * 1.2), math.floor(B.cardH * 1.2) }, "FFFFFF", "Beam")
			beam.BackgroundTransparency = 0.85
			local bg2 = Instance.new("UIGradient")
			bg2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) })
			bg2.Parent = beam
			table.insert(beamConns, RunService.Heartbeat:Connect(function(dt)
				if beam.Parent then
					bg2.Rotation = (bg2.Rotation + T.beamDegPerSec * 60 * dt) % 360
				end
			end))
		end
		if T.frame then -- 9-slice 테 장식(잎 · 별 · 금 점)
			local fr = Instance.new("ImageLabel")
			fr.Name = "TierFrame"
			fr.BackgroundTransparency = 1
			fr.Image = ArtImage.get(T.frame) or ""
			fr.ScaleType = Enum.ScaleType.Slice
			fr.SliceCenter = Rect.new(24, 24, 104, 104)
			fr.SliceScale = phone and 0.5 or 1
			fr.Size = UDim2.fromScale(1, 1)
			fr.ZIndex = 3
			fr.Parent = card
		end
		-- 초상(안 만난 보스 = 실루엣)
		local p = BossPortrait.make(card, bossId, B.portrait)
		p.AnchorPoint = Vector2.new(0.5, 0)
		p.Position = UDim2.new(0.5, 0, 0, phone and 8 or 20)
		if not known then
			for _, d in ipairs(p:GetDescendants()) do
				if d:IsA("ImageLabel") then
					d.ImageColor3 = Color3.new(0, 0, 0)
					d.ImageTransparency = 0.25
				elseif d:IsA("UIStroke") then
					d.Transparency = 1
				end
			end
			if p:IsA("GuiObject") then
				p.BackgroundTransparency = 1
			end
		end
		local yy = (phone and 8 or 20) + B.portrait + (phone and 2 or 12)
		local boss = BossData.bosses[bossId] or {}
		label(card, known and Text.name(boss.displayName or bossId) or Text.get("ui1c.codex.unknown"), px(B.name), "FFFFFF", { name = "Name", align = Enum.TextXAlignment.Center, rect = { 4, yy, B.cardW - 8, B.name + 8 } })
		yy += B.name + 8
		if B.zone > 0 then
			label(card, Text.name(CodexData.zoneShort[z.key] or ""), px(B.zone), C.muted, { name = "Zone", align = Enum.TextXAlignment.Center, rect = { 4, yy, B.cardW - 8, B.zone + 6 } })
			yy += B.zone + 12
		end
		label(card, Text.get(phone and "ui1c.codex.killsPhone" or "ui1c.codex.kills", { n = tostring(kills) }), px(B.kills), C.gold, { name = "Kills", rich = true, align = Enum.TextXAlignment.Center, rect = { 4, yy, B.cardW - 8, B.kills + 8 } })
		yy += B.kills + (phone and 4 or 14)
		-- 단계 점 5(1 · 3 · 5 · 10 · 20회)
		local n = #L.bossTiers - 1
		local slot = (B.cardW - 16) / n
		for i = 2, #L.bossTiers do
			local t = L.bossTiers[i]
			local reached = kills >= t.n
			local dot = ArtImage.label(card, t.badge, UDim2.fromOffset(B.dot, B.dot), "")
			dot.Name = "Step" .. t.n
			dot.Position = UDim2.fromOffset(math.floor(8 + (i - 2) * slot + (slot - B.dot) / 2), yy)
			if dot:IsA("ImageLabel") and not reached then
				dot.ImageTransparency = 0.6
			end
			if not phone then
				label(card, Text.get("ui1c.codex.tierN", { n = tostring(t.n) }), px(15), reached and "FFFFFF" or C.muted, { align = Enum.TextXAlignment.Center, font = "number", rect = { math.floor(8 + (i - 2) * slot), yy + B.dot + 2, math.floor(slot), 20 } })
			end
		end
		yy += B.dot + (phone and 4 or 30)
		-- "다음 단계까지 n회 더" · 최고 단계 · 처음 처치하면 1단계
		local nextT = L.bossTiers[ti + 1]
		local nextText = kills == 0 and Text.get("ui1c.codex.first") or (nextT and Text.get(phone and "ui1c.codex.nextPhone" or "ui1c.codex.next", { n = tostring(nextT.n - kills) }) or Text.get("ui1c.codex.top"))
		local nx = label(card, nextText, px(phone and 12 or 18), "FFFFFF", { name = "Next", align = Enum.TextXAlignment.Center, rect = { 8, yy, B.cardW - 16, phone and 20 or 40 } })
		nx.BackgroundTransparency = 0.25
		nx.BackgroundColor3 = hex("0E1120")
		corner(nx, 8)
		-- 오른쪽 위 단계 배지
		if T.badge then
			local badge = ArtImage.label(card, T.badge, UDim2.fromOffset(B.badge, B.badge), "")
			badge.Name = "Badge"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -8, 0, 8)
			badge.ZIndex = 4
		end
		-- 받을 칸 = 빨간 점 · 누르면 그 보스 칸 받기
		local claimIds = {}
		for _, step in ipairs(CodexData.boss.steps) do
			local id = ("boss:%s:%d"):format(bossId, step)
			local cv = view.cells[id]
			if cv and cv.done and not cv.claimed then
				table.insert(claimIds, id)
			end
		end
		if #claimIds > 0 then
			redDot(card, phone and 10 or 14).Position = UDim2.new(1, -(B.badge + 12), 0, 6)
		end
		if S.selected and S.selected.id == "boss:" .. bossId then
			stroke(card, "FFFFFF", 3).Name = "Selected"
		end
		card.Activated:Connect(function()
			S.select({ kind = "boss", id = "boss:" .. bossId })
			if #claimIds > 0 then
				S.claim(claimIds)
			end
		end)
		-- 단계 오름 = 토스트 + 테가 아래서 위로 바뀜(D 첫 획득 공개 연출과 같은 0.6초)
		if lastTier[bossId] and ti > lastTier[bossId] then
			local cover = frame(card, { 0, 0, B.cardW, B.cardH }, "FFFFFF", "TierUp")
			cover.ZIndex = 6
			cover.BackgroundTransparency = 0.4
			TweenService:Create(cover, TweenInfo.new(L.tierUpSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(B.cardW, 0), BackgroundTransparency = 1 }):Play()
			Toast.push("TC", { text = Text.get("ui1c.codex.tierUp", { boss = Text.name(boss.displayName or bossId), n = tostring(T.n) }), grade = "notice", seconds = 3 })
		end
		lastTier[bossId] = ti
		x += B.cardW + B.gap
	end
	-- 아래 범례(PC): 단계 5칸 = 테 샘플 + 이름 + 설명
	if B.legendH > 0 then
		local lg = frame(scroll, { 0, B.cardH + 16, x - B.gap, B.legendH }, "1B2133", "Legend")
		corner(lg, 14)
		stroke(lg, C.stroke, 2)
		label(lg, Text.get("ui1c.codex.legend"), px(22), "FFFFFF", { rect = { 20, 12, 160, 32 } })
		label(lg, Text.get("ui1c.codex.legendSub"), px(15), C.muted, { rect = { 150, 12, 900, 32 } })
		local slot = (x - B.gap - 40) / 5
		for i = 2, #L.bossTiers do
			local t = L.bossTiers[i]
			local sx = 20 + (i - 2) * slot
			local box = frame(lg, { sx, 60, 92, 92 }, t.bg[1], "Tier" .. t.n)
			corner(box, 12)
			local s2 = stroke(box, t.stroke, 4)
			if t.rainbow then
				local keys = {}
				for k, h in ipairs(t.rainbow) do
					table.insert(keys, ColorSequenceKeypoint.new((k - 1) / (#t.rainbow - 1), hex(h)))
				end
				local rg = Instance.new("UIGradient")
				rg.Color = ColorSequence.new(keys)
				rg.Parent = s2
			end
			local bi = ArtImage.label(box, t.badge, UDim2.fromOffset(56, 56), "")
			bi.AnchorPoint = Vector2.new(0.5, 0.5)
			bi.Position = UDim2.fromScale(0.5, 0.5)
			label(lg, Text.get("ui1c.codex.tierHead", { n = tostring(t.n) }), px(20), "FFFFFF", { rect = { sx + 104, 72, slot - 110, 28 } })
			label(lg, Text.get("ui1c.codex.tier." .. t.n), px(15), C.muted, { rect = { sx + 104, 102, slot - 110, 24 } })
		end
		scroll.CanvasSize = UDim2.fromOffset(0, B.cardH + 16 + B.legendH)
	else
		scroll.CanvasSize = UDim2.fromOffset(0, B.cardH)
	end
end

-- ═══ 탐험의 알(구역별 번호) ═══
function V3.renderNest(S, scroll)
	local view = S.view
	local E = P(S).egg
	local phone = S.phone
	local y = 0
	if E.headH > 0 then
		label(scroll, Text.get("ui1c.codex.eggHead"), px(22), "FFFFFF", { rect = { 12, 0, 600, E.headH } })
		label(scroll, Text.get("ui1c.codex.eggNote"), px(15), C.sky, { align = Enum.TextXAlignment.Right, rect = { 0, 0, 1270, E.headH } })
		y = E.headH + 4
	end
	for _, z in ipairs(Info.zones) do
		local line = view.lines["nest:" .. z.key]
		local ids = line and line.cells or {}
		local zc = hex(L.zoneColors[z.key] or C.sky)
		local found = 0
		for _, id in ipairs(ids) do
			found += (view.cells[id] and view.cells[id].done) and 1 or 0
		end
		local row = frame(scroll, { 0, y, phone and 488 or 1270, E.rowH - (phone and 2 or 8) }, "1F2540", "Zone_" .. z.key)
		corner(row, phone and 6 or 10)
		local stripe = frame(row, { 0, 0, phone and 4 or 6, E.rowH - (phone and 2 or 8) }, nil, "Stripe")
		stripe.BackgroundTransparency = 0
		stripe.BackgroundColor3 = zc
		label(row, Text.name(CodexData.zoneShort[z.key] or z.key), px(phone and 12 or 20), "FFFFFF", { name = "Name", rect = { phone and 8 or 18, phone and 0 or 10, E.nameW - 20, phone and 16 or 28 } })
		label(row, Text.get("ui1c.codex.eggCount", { have = tostring(found), total = tostring(#ids) }), px(phone and 12 or 18), zc, { name = "Count", font = "number", rect = { phone and 8 or 18, phone and 14 or 40, E.nameW - 20, phone and 14 or 26 } })
		for i, id in ipairs(ids) do
			local cv = view.cells[id]
			local got = cv and cv.done
			local cx = E.nameW + (i - 1) * (E.cell + E.gap)
			local b = Instance.new("TextButton")
			b.Name = "Egg" .. i
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundColor3 = got and zc:Lerp(Color3.new(0, 0, 0), 0.65) or hex(C.unknown)
			b.BackgroundTransparency = got and 0 or 0.4
			b.Position = UDim2.fromOffset(cx, math.floor((E.rowH - (phone and 2 or 8) - E.cell) / 2))
			b.Size = UDim2.fromOffset(E.cell, E.cell)
			b:SetAttribute("CodexCell", id)
			b.Parent = row
			corner(b, phone and 4 or 8)
			local sel = S.selected and S.selected.id == id
			local st = stroke(b, sel and "FFFFFF" or (got and zc or C.muted), sel and 3 or 2, got and 0 or 0.45) -- 못 찾음 = 흐린 테(점선 대신)
			st.Name = got and "FoundStroke" or "MissStroke"
			if got then
				local egg = ArtImage.label(b, "icons/reward/egg", UDim2.fromOffset(E.egg, E.egg), "")
				egg.Name = "Pic"
				egg.AnchorPoint = Vector2.new(0.5, 0.5)
				egg.Position = UDim2.fromScale(0.5, 0.55)
				local ck = label(b, "✓", px(E.check), "FFFFFF", { name = "Check", align = Enum.TextXAlignment.Center, rect = { E.cell - E.check - 2, E.cell - E.check - 2, E.check, E.check } })
				ck.BackgroundTransparency = 0
				ck.BackgroundColor3 = hex(C.check)
				corner(ck, "pill")
			else
				local qx = phone and math.floor(E.cell * 0.4) or 0 -- 폰 = 번호 알약을 피해 오른쪽 아래
				label(b, "?", px(E.q), C.muted, { name = "Q", align = Enum.TextXAlignment.Center, font = "number", rect = { qx, phone and math.floor(E.cell * 0.3) or 2, E.cell - qx, phone and math.floor(E.cell * 0.7) or E.cell } })
			end
			-- 번호 알약(왼쪽 위 · 늘 보임)
			local no = label(b, tostring(i), px(phone and 10 or 15), "FFFFFF", { name = "No", align = Enum.TextXAlignment.Center, font = "number", rect = { 3, 3, E.pill[1], E.pill[2] } })
			no.BackgroundTransparency = 0
			no.BackgroundColor3 = hex("0E1120")
			no.ZIndex = 3
			corner(no, 6)
			stroke(no, zc, 1.5)
			if got and not cv.claimed then
				redDot(b, phone and 6 or 10)
			end
			b.Activated:Connect(function()
				S.select({ kind = "cell", id = id })
			end)
		end
		y += E.rowH
	end
	if not phone then -- 범례
		local lg = frame(scroll, { 0, y + 6, 1270, 50 }, nil, "Legend")
		label(lg, Text.get("ui1c.codex.eggLegendFound"), px(15), C.muted, { rect = { 12, 0, 300, 50 } })
		label(lg, Text.get("ui1c.codex.eggLegendMiss"), px(15), C.muted, { rect = { 330, 0, 500, 50 } })
		y += 60
	end
	scroll.CanvasSize = UDim2.fromOffset(0, y)
end

-- ═══ 칭호 ═══
local function tabOfKind(kind)
	return ({ armorGrade = "armor", armorZone = "armor", pet = "pet", nest = "nest", monster = "monster", boss = "boss", class = "class" })[kind]
end
function V3.condition(t)
	local kind, key = (t.id or ""):match("^codex_(%a+)_(.+)$")
	if kind == "boss" and BossData.bosses[key] then
		return Text.get("ui1c.codex.cond.boss", { name = Text.name(BossData.bosses[key].displayName) })
	elseif kind and tabOfKind(kind) then
		return Text.get("ui1c.codex.cond.line", { tab = Text.get("ui1c.codex.tab." .. tabOfKind(kind)) })
	end
	return t.condition and Text.name(t.condition) or ""
end

function V3.renderTitles(S, scroll)
	local view = S.view
	local T = P(S).titles
	local phone = S.phone
	local list = view.titles or {}
	local have = 0
	for _, t in ipairs(list) do
		have += t.hidden and 0 or 1
	end
	local total = view.titleTotal or #list
	local width = (T.w + T.gap) * T.cols - T.gap
	label(scroll, Text.get("ui1c.codex.titlesHead"), px(phone and 14 or 22), "FFFFFF", { rect = { 4, 0, 200, phone and 18 or 34 } })
	label(scroll, Text.get("ui1c.codex.titlesCount", { have = tostring(have), total = tostring(total) }), px(phone and 12 or 18), "FFFFFF", { rich = true, align = Enum.TextXAlignment.Right, rect = { 0, 0, width, phone and 18 or 34 } })
	local bar = frame(scroll, { 0, phone and 22 or 44, width, phone and 6 or 10 }, "0E1120", "Gauge")
	corner(bar, "pill")
	local fill = frame(bar, { 0, 0, math.floor(width * (total > 0 and have / total or 0)), phone and 6 or 10 }, C.gold, "Fill")
	corner(fill, "pill")
	local y0 = T.headH
	for i, t in ipairs(list) do
		local col = (i - 1) % T.cols
		local rowI = math.floor((i - 1) / T.cols)
		local x, y = col * (T.w + T.gap), y0 + rowI * (T.h + T.gap)
		local equipped = not t.hidden and view.selected == t.id
		local b = Instance.new("TextButton")
		b.Name = "Title_" .. t.id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = t.hidden and hex(C.unknown) or hex("232A44")
		b.Position = UDim2.fromOffset(x, y)
		b.Size = UDim2.fromOffset(T.w, T.h)
		b:SetAttribute("CodexCell", "title:" .. t.id)
		b.Parent = scroll
		corner(b, phone and 8 or 12)
		local picked = S.titlePick == t.id
		stroke(b, (equipped and C.equip) or (picked and "FFFFFF") or (t.hidden and "4A5168" or C.stroke), (equipped or picked) and 3 or 2, t.hidden and 0.3 or 0)
		local cy = math.floor((T.h - T.medal) / 2)
		if t.hidden then -- ??? = 이름 · 조건 · 힌트 모두 숨김(빗금 대신 어두운 바탕)
			local q = label(b, "?", px(phone and 14 or 24), C.muted, { name = "Q", align = Enum.TextXAlignment.Center, font = "number", rect = { phone and 8 or 14, cy, T.medal, T.medal } })
			stroke(q, C.muted, 2, 0.4)
			corner(q, "pill")
			label(b, Text.get("ui1c.codex.unknown"), px(T.name), C.muted, { name = "Name", rect = { T.medal + (phone and 14 or 28), 0, T.w - T.medal - 40, T.h } })
		else
			local medal = ArtImage.label(b, "icons/reward/title", UDim2.fromOffset(T.medal, T.medal), "")
			medal.Name = "Medal"
			medal.Position = UDim2.fromOffset(phone and 8 or 14, cy)
			local nx = T.medal + (phone and 14 or 28)
			label(b, CodexRules.titleText(t.id, t.name), px(T.name), t.grade and Info.gradeColor(t.grade) or "FFFFFF", { name = "Name", rect = { nx, phone and 6 or 22, T.w - nx - 10, T.name + 8 } })
			label(b, V3.condition(t), px(T.cond), C.muted, { name = "Cond", rect = { nx, phone and (T.name + 14) or 58, T.w - nx - 10, T.cond + 8 } })
			if equipped then
				local pill = label(b, Text.get("ui1c.codex.equipped"), px(phone and 11 or 15), "1A1300", { name = "Equipped", align = Enum.TextXAlignment.Center, rect = { T.w - (phone and 60 or 84), 6, phone and 54 or 76, phone and 16 or 24 } })
				pill.BackgroundTransparency = 0
				pill.BackgroundColor3 = hex(C.equip)
				corner(pill, "pill")
			end
		end
		b.Activated:Connect(function()
			S.titlePick = t.id
			S.select({ kind = "title", id = "title:" .. t.id })
		end)
	end
	scroll.CanvasSize = UDim2.fromOffset(0, y0 + math.ceil(#list / T.cols) * (T.h + T.gap))
end

-- 칭호 상세(오른쪽 판): 이름 30 + 조건 + 머리 위 이름표 미리보기 + [장착 해제] [장착]
function V3.titleDetail(S, parent)
	for _, c in ipairs(parent:GetChildren()) do
		if not c:IsA("UIBase") then
			c:Destroy()
		end
	end
	local view = S.view
	if not view then
		return
	end
	local phone = S.phone
	local W = parent.AbsoluteSize.X > 0 and P(S).detail[3] or 500
	local pick
	for _, t in ipairs(view.titles or {}) do
		if t.id == (S.titlePick or view.selected) then
			pick = t
		end
	end
	pick = pick or (view.titles or {})[1]
	if not pick then
		return
	end
	local pad = phone and 8 or 18
	label(parent, Text.get("ui1c.codex.titlePick"), px(phone and 12 or 15), C.muted, { rect = { pad, pad, W - pad * 2, 20 } })
	if pick.hidden then
		label(parent, Text.get("ui1c.codex.titleHidden"), px(phone and 18 or 30), "FFFFFF", { name = "Name", rect = { pad, pad + 24, W - pad * 2, phone and 24 or 40 } })
		label(parent, Text.get("ui1c.codex.titleHiddenLine"), px(phone and 12 or 15), C.muted, { wrap = true, rect = { pad, pad + (phone and 52 or 72), W - pad * 2, 60 } })
		return
	end
	local name = CodexRules.titleText(pick.id, pick.name)
	label(parent, name, px(phone and 18 or 30), "FFFFFF", { name = "Name", rect = { pad, pad + 24, W - pad * 2, phone and 24 or 40 } })
	label(parent, V3.condition(pick), px(phone and 12 or 16), C.muted, { name = "Cond", rect = { pad, pad + (phone and 50 or 68), W - pad * 2, 24 } })
	if not phone then -- 이름표 미리보기 + 아바타
		local box = frame(parent, { pad, 130, W - pad * 2, 230 }, "232A44", "Preview")
		corner(box, 14)
		local plate = frame(box, { math.floor((W - pad * 2) / 2 - 160), 30, 320, 70 }, "0E1120", "Plate")
		corner(plate, 10)
		stroke(plate, C.equip, 3)
		label(plate, name, px(15), C.gold, { align = Enum.TextXAlignment.Center, rect = { 0, 4, 320, 24 } })
		label(plate, player.DisplayName, px(22), "FFFFFF", { align = Enum.TextXAlignment.Center, rect = { 0, 28, 320, 36 } })
		local av = V9.avatar(box, player.UserId, player.DisplayName, 110, C.stroke, 3)
		av.Position = UDim2.fromOffset(math.floor((W - pad * 2) / 2 - 55), 112)
		label(parent, Text.get("ui1c.codex.titlePreview"), px(15), C.muted, { align = Enum.TextXAlignment.Center, rect = { pad, 366, W - pad * 2, 22 } })
	end
	local equipped = view.selected == pick.id
	local bh = phone and 40 or 60
	local by = (phone and P(S).detail[4] or P(S).detail[4]) - bh - pad
	local un = UiKit.button({ kind = "secondary", name = "Unequip", align = Enum.TextXAlignment.Center, padX = phone and 4 or 22, text = Text.get("ui1c.codex.titleUnequip"), parent = parent, rect = { pad, by, math.floor((W - pad * 3) * 0.4), bh }, onActivated = function()
		S.send("title", "")
	end })
	un.setEnabled(equipped)
	if phone then -- 좁은 버튼 = 말줄임 대신 글자 축소(A 규칙)
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = un.title.TextSize
		cap.Parent = un.title
		un.title.TextScaled = true
	end
	local eq = UiKit.button({ kind = "primary", name = "Equip", align = Enum.TextXAlignment.Center, padX = phone and 4 or 22, text = Text.get("ui1c.codex.titleEquip"), parent = parent, rect = { pad * 2 + math.floor((W - pad * 3) * 0.4), by, math.floor((W - pad * 3) * 0.6), bh }, onActivated = function()
		S.send("title", pick.id)
	end })
	eq.setEnabled(not equipped)
end

return V3
