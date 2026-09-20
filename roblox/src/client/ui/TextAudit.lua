-- 글씨 자체 점검 공용(COMMON.md §2: 글씨 크기는 TextSize × 조상 UIScale 누적 배율 = 실제 화면 px로 판정, 12 미만 금지).
-- 점검 스크립트들(SocialSelfCheck · PanelFitCheck)이 같은 잣대를 쓰게 "보이는 글 요소 훑기"와 "실효 12 미만 목록"을 한 곳에 둔다.

local Theme = require(script.Parent.kit.Theme)

local TextAudit = {}

-- root 아래 보이는 글 요소(TextLabel · TextButton): 자기와 조상(root 포함)이 모두 보이고, 글이 있고, 폭이 0보다 큰 것.
function TextAudit.visibleTexts(root)
	local result = {}
	for _, inst in ipairs(root:GetDescendants()) do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" and inst.AbsoluteSize.X > 0 then
			local shown = true
			local node = inst
			while node and node ~= root.Parent do
				if (node:IsA("GuiObject") and not node.Visible) or (node:IsA("ScreenGui") and not node.Enabled) then
					shown = false
					break
				end
				node = node.Parent
			end
			if shown then
				table.insert(result, inst)
			end
		end
	end
	return result
end

-- 보이는 글의 실효 최소 크기와 12 미만 목록. low의 항목은 "이름=명목×배율(글 앞 10자)". TextScaled 글은 TextSize 속성이 실제 크기가 아니라 잴 수 없다 - scaled에 이름만 모은다.
function TextAudit.report(root)
	local report = { count = 0, minEffective = math.huge, low = {}, scaled = {} }
	for _, inst in ipairs(TextAudit.visibleTexts(root)) do
		if inst.TextScaled then
			table.insert(report.scaled, inst.Name)
			continue
		end
		local effective = Theme.effectiveTextSize(inst)
		report.count += 1
		report.minEffective = math.min(report.minEffective, effective)
		if effective < Theme.minTextSize - 0.01 then
			table.insert(report.low, ("%s=%g×%.2f(%s)"):format(inst.Name, inst.TextSize, effective / inst.TextSize, inst.Text:gsub("<[^>]+>", ""):sub(1, 10)))
		end
	end
	return report
end

return TextAudit
