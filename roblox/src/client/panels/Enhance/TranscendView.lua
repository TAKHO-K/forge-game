-- QUEUE-ALL10 2-7 강화 창의 초월 모드(강화 탭 본문을 바꿔 끼운다 - init.lua가 모드를 고른다). 서버 진실 = TranscendRequest 화면 표(TranscendService.view) - 여기는 그리기만.
--   "inherit" 모드 = 태초 +30(계승 가능): 설명 · 보상 · [초월 계승](확인 창 2단계: 무엇이 바뀌는지 → 되돌릴 수 없음)
--   "transcend" 모드 = 초월 무기: 초월 강화 +N · 10칸 진행 막대 · [칸 납입 비용] · 초월 보석 목록([장착] · [추출])
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Confirm = require(script.Parent.Parent.Parent.ui.kit.Confirm)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)

local TranscendView = {}
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TranscendRequest")

-- 지금 모드: nil(초월 아님 - 보통 강화) | "inherit" | "transcend" - Attribute로 바로 판정(서버 표를 기다리지 않는다)
function TranscendView.mode()
	if player:GetAttribute("All10On") ~= true then
		return nil
	end
	if player:GetAttribute("TranscendLevel") ~= nil then
		return "transcend"
	end
	if player:GetAttribute("WeaponGrade") == 6 and (player:GetAttribute("WeaponLevel") or 0) >= 30 then
		return "inherit"
	end
	return nil
end

local function whyText(why)
	local key = "transcend.why." .. tostring(why)
	local text = Text.get(key)
	if text == key or text == nil or text == "" then
		return Text.get("transcend.why.generic", { why = tostring(why) })
	end
	return text
end

local function pct(v)
	return ("%.1f"):format(v * 100)
end

function TranscendView.build(parent, width, pad, footerHeight, buttonY, resultY, panelId)
	local refs = { view = nil, busy = false }
	local innerWidth = width - pad * 2
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "TranscendScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -footerHeight)
	scroll.ScrollBarThickness = Theme.isMobile and 6 or 4
	scroll.ScrollBarImageColor3 = Theme.colors.textSecondary
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop = UDim.new(0, pad), UDim.new(0, pad), UDim.new(0, 4)
	padding.Parent = scroll
	refs.scroll = scroll

	local function line(name, order, size, color)
		local l = Theme.label(scroll, "", size or "body", color or "textPrimary")
		l.Name = name
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.TextWrapped = true
		return l
	end
	refs.title = line("TransTitle", 1, "header", "textPrimary")
	refs.body = line("TransBody", 2, "caption", "textSecondary")
	refs.reward = line("TransReward", 3, "caption", "gold")
	-- 10칸 진행 막대(분할 납입)
	local bar = Instance.new("Frame")
	bar.Name = "SlotBar"
	bar.LayoutOrder = 4
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, Theme.isMobile and 20 or 16)
	bar.Parent = scroll
	refs.bar = bar
	refs.cells = {}
	refs.slotsText = line("SlotText", 5, "caption", "textSecondary")
	refs.note = line("TransNote", 6, "caption", "textSecondary")
	refs.gemTitle = line("GemTitle", 7, "body", "textPrimary")
	local gemBox = Instance.new("Frame")
	gemBox.Name = "GemRows"
	gemBox.LayoutOrder = 8
	gemBox.BackgroundTransparency = 1
	gemBox.Size = UDim2.new(1, 0, 0, 0)
	gemBox.AutomaticSize = Enum.AutomaticSize.Y
	gemBox.Parent = scroll
	local gemList = Instance.new("UIListLayout")
	gemList.SortOrder = Enum.SortOrder.LayoutOrder
	gemList.Padding = UDim.new(0, 4)
	gemList.Parent = gemBox
	refs.gemBox = gemBox

	local footer = Instance.new("Frame")
	footer.Name = "TranscendFooter"
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 0, 1, -footerHeight)
	footer.Size = UDim2.new(1, 0, 0, footerHeight)
	footer.Parent = parent
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Theme.colors.rim
	divider.BackgroundTransparency = Theme.colors.rimTransparency
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Parent = footer
	refs.result = Theme.label(footer, "", "caption", "textPrimary")
	refs.result.Name = "TransResult"
	refs.result.TextXAlignment = Enum.TextXAlignment.Center
	refs.result.Position = UDim2.new(0, pad, 0, resultY)
	refs.result.Size = UDim2.new(0, innerWidth, 0, Theme.textSize("caption") + 4)

	local function call(action, arg)
		if refs.busy then
			return nil
		end
		refs.busy = true
		local ok, res = pcall(function()
			return remote:InvokeServer(action, arg)
		end)
		refs.busy = false
		if ok and type(res) == "table" then
			if res.view then
				refs.view = res.view
			end
			return res
		end
		return nil
	end

	local function doInherit()
		local prep = call("prepare")
		if not prep or not prep.ok then
			refs.result.Text = whyText(prep and prep.why or "generic")
			refs.result.TextColor3 = Theme.color("danger")
			return
		end
		local args = { level = tostring(prep.fromLevel), mult = ("%.2f"):format(prep.weaponMultiplier), n = tostring(prep.rewardGems) }
		Confirm.ask({ title = Text.get("transcend.inherit.title"), body = Text.get("transcend.inherit.confirm1", args), primaryText = Text.get("transcend.inherit.next"),
			secondaryText = Text.get("transcend.inherit.cancel"), parentId = panelId }, function(step1)
			if not step1 then
				return
			end
			task.defer(function()
				Confirm.ask({ title = Text.get("transcend.inherit.confirm2Title"), body = Text.get("transcend.inherit.confirm2"), primaryText = Text.get("transcend.inherit.do"),
					secondaryText = Text.get("transcend.inherit.cancel"), danger = true, parentId = panelId }, function(step2)
					if not step2 then
						return
					end
					task.spawn(function()
						local res = call("confirm", prep.token)
						if res and res.ok then
							refs.result.Text = Text.get("transcend.inherit.done")
							refs.result.TextColor3 = Theme.color("success")
							Toast.push("TC", { text = Text.get("transcend.inherit.done"), grade = "important", colorName = "gold" })
						else
							refs.result.Text = whyText(res and res.why or "generic")
							refs.result.TextColor3 = Theme.color("danger")
						end
						TranscendView.render(refs)
					end)
				end)
			end)
		end)
	end

	refs.button = Button.build({ parent = footer, name = "TranscendButton", kind = "primary", width = 220, text = "",
		anchorPoint = Vector2.new(0.5, 0), position = UDim2.new(0.5, 0, 0, buttonY), onActivated = function()
			local mode = TranscendView.mode()
			if mode == "inherit" then
				task.spawn(doInherit)
			elseif mode == "transcend" then
				task.spawn(function()
					local res = call("enhance")
					if res and res.ok then
						local v = refs.view
						refs.result.Text = res.leveled and Text.get("transcend.enh.leveled", { level = tostring(res.level) })
							or Text.get("transcend.enh.paid", { slot = tostring(res.slot), slots = tostring(v and v.slots or 10) })
						refs.result.TextColor3 = Theme.color(res.leveled and "gold" or "success")
					else
						refs.result.Text = whyText(res and res.why or "generic")
						refs.result.TextColor3 = Theme.color("danger")
					end
					TranscendView.render(refs)
				end)
			end
		end })
	refs.call = call
	return refs
end

local function rebuildCells(refs, slots, filled)
	if #refs.cells ~= slots then
		for _, c in ipairs(refs.cells) do
			c:Destroy()
		end
		refs.cells = {}
		local gap = 3
		for i = 1, slots do
			local cell = Instance.new("Frame")
			cell.Name = "Cell" .. i
			cell.BorderSizePixel = 0
			cell.Size = UDim2.new(1 / slots, -gap, 1, 0)
			cell.Position = UDim2.new((i - 1) / slots, 0, 0, 0)
			cell.Parent = refs.bar
			Theme.corner(cell, 3)
			refs.cells[i] = cell
		end
	end
	for i, cell in ipairs(refs.cells) do
		cell.BackgroundColor3 = i <= filled and Theme.color("gold") or Theme.color("slot")
		cell.BackgroundTransparency = i <= filled and 0 or 0.2
	end
end

local function gemRows(refs, v)
	for _, child in ipairs(refs.gemBox:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not v.inherited then
		refs.gemTitle.Text = Text.get("transcend.gem.title") .. " · " .. Text.get("transcend.gem.locked")
		return
	end
	refs.gemTitle.Text = Text.get("transcend.gem.title")
	if #v.gems == 0 then
		local l = Theme.label(refs.gemBox, Text.get("transcend.gem.none"), "caption", "textSecondary")
		l.Size = UDim2.new(1, 0, 0, Theme.textSize("caption") + 6)
		return
	end
	for i, gem in ipairs(v.gems) do
		local row = Instance.new("Frame")
		row.Name = "Gem_" .. gem.id
		row.LayoutOrder = i
		row.BackgroundColor3 = Theme.color("slot")
		row.BackgroundTransparency = 0.3
		row.Size = UDim2.new(1, 0, 0, Theme.buttonHeight + 8)
		row.Parent = refs.gemBox
		Theme.corner(row, 8)
		local desc = ItemDescribe.gem({ grade = "transcendent", itemLevel = gem.itemLevel, option = gem.option }, player:GetAttribute("ClassId"))
		local name = Theme.label(row, desc.title, "caption", "textPrimary")
		name.Position = UDim2.fromOffset(6, 0)
		name.Size = UDim2.new(1, -(Button.minWidth + 18), 1, 0)
		name.TextWrapped = true
		local socketed = gem.socket ~= nil
		local b = Button.build({ parent = row, name = "GemButton", kind = "secondary", width = Button.minWidth,
			text = socketed and Text.get("transcend.gem.extract") or Text.get("transcend.gem.equip"),
			anchorPoint = Vector2.new(1, 0.5), position = UDim2.new(1, -4, 0.5, 0), onActivated = function()
				task.spawn(function()
					local res = refs.call(socketed and "extractGem" or "equipGem", gem.id)
					if res and not res.ok then
						refs.result.Text = whyText(res.why)
						refs.result.TextColor3 = Theme.color("danger")
					end
					TranscendView.render(refs)
				end)
			end })
		b.setEnabled(v.transcend or socketed)
	end
end

-- 화면 표로 다시 그리기(표가 없으면 받아 온다)
function TranscendView.render(refs)
	local mode = TranscendView.mode()
	local v = refs.view
	if not v then
		task.spawn(function()
			if refs.call("view") then
				TranscendView.render(refs)
			end
		end)
		return
	end
	if mode == "inherit" then
		refs.title.Text = Text.get("transcend.inherit.title")
		refs.body.Text = Text.get("transcend.inherit.body", { mult = ("%.2f"):format(1.25) })
		refs.reward.Text = Text.get("transcend.inherit.reward", { n = "1" })
		refs.reward.Visible, refs.bar.Visible, refs.slotsText.Visible, refs.note.Visible = true, false, false, false
		refs.button.setText(Text.get("transcend.inherit.button"))
		refs.button.setEnabled(true)
	elseif mode == "transcend" then
		local level, slot = v.level or 0, v.slot or 0
		local maxed = level >= (v.maxLevel or 20)
		refs.title.Text = Text.get("transcend.enh.title", { level = tostring(level) })
		refs.body.Text = Text.get("transcend.enh.effect", { now = pct((level + slot / v.slots) * v.perLevel), step = pct(v.perLevel / v.slots) })
		refs.reward.Visible, refs.bar.Visible, refs.slotsText.Visible, refs.note.Visible = false, not maxed, not maxed, true
		rebuildCells(refs, v.slots, slot)
		refs.slotsText.Text = Text.get("transcend.enh.slots", { slot = tostring(slot), slots = tostring(v.slots) })
		refs.note.Text = Text.get("transcend.enh.note")
		if maxed then
			refs.button.setText(Text.get("transcend.enh.max", { level = tostring(level) }))
			refs.button.setEnabled(false)
		else
			refs.button.setText(Text.get("transcend.enh.button", { cost = NumberFormat.currency(v.slotCost, Text.languageFor()) }))
			refs.button.setEnabled((player:GetAttribute("Gold") or 0) >= v.slotCost, Text.get("transcend.why.no_gold"))
		end
	end
	gemRows(refs, v)
end

return TranscendView
