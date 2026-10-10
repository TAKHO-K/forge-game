-- QUEUE-ALL1 01 A-1 보스전 하단 배치(아트 켬 - ArtStyleV1): 아래부터 내 체력바(ScreenMap BC healthBar) → 보스 체력바 → 이름 · % 줄 → 기믹 안내 한 줄.
--   수치 = ArtV1UiData.bossHud(bottom*). 기믹 안내(BossEnvironmentView · BossGimmick13View · BossRodsView)는 gimmickLabel()로 자리를 받고, 글씨가 바뀐 뒤 fadeSeconds 지나면 흐려진다.
--   끔(아트 스위치) = 각자 옛 자리 그대로(부르는 쪽이 fallback 위치를 넘긴다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local H = require(ReplicatedStorage.Shared.data.ArtV1UiData).bossHud
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local BossHudLayout = {}

function BossHudLayout.enabled()
	return Workspace:GetAttribute("ArtStyleV1") == true
end

function BossHudLayout.barHeight()
	return Theme.isMobile and H.barHeightMobile or H.barHeightPc
end

-- 화면 아래에서 보스 바 밑변 · 이름 줄 위 끝까지(px)
function BossHudLayout.barBottom()
	return H.healthBarTopFromBottom + H.gapAboveHealth
end
function BossHudLayout.blockTop()
	return BossHudLayout.barBottom() + BossHudLayout.barHeight() + H.nameGap + H.nameHeight
end
-- 보스 블록(바 + 이름 줄 + 기믹 한 줄)이 켜진 동안 BC의 다른 슬롯을 올리는 양
function BossHudLayout.shift()
	return BossHudLayout.blockTop() + H.gimmickGap + H.gimmickHeight - H.healthBarTopFromBottom
end

-- FINAL-1b 결정 6: FUN-1 자리(지금 그리지 않음) - BREAK 게이지 · "내 기여 n%"의 { 아래 끝(화면 아래에서 px) · 높이 · 오른쪽 끝(바 오른쪽 끝 기준 px · 음수 = 안쪽) · 폭(nil = 바 폭) }
function BossHudLayout.reserved()
	local R = H.reserved
	return {
		breakGauge = { bottom = BossHudLayout.barBottom() - R.breakGap - R.breakHeight, height = R.breakHeight, right = 0, width = nil },
		contribution = { bottom = BossHudLayout.barBottom() + BossHudLayout.barHeight() + H.nameGap, height = H.nameHeight, right = -(R.percentWidth + R.contributionGap), width = R.contributionWidth },
	}
end

-- 기믹 안내 글씨: 아트 켬 = 보스 이름 줄 바로 위 가운데(아래 기준) · 끔 = fallback(부르는 쪽의 옛 자리 · 기준점)
function BossHudLayout.gimmickLabel(label, fallbackPosition, fallbackAnchor)
	if BossHudLayout.enabled() then
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -(BossHudLayout.blockTop() + H.gimmickGap))
		if require(ReplicatedStorage.Shared.data.UiV2Flags).hud then -- UI-1 2단계(02 v6 §5): 보스 바 위 가운데 → 기믹 줄 = 보스 바 아래 한 줄
			local V6 = require(ReplicatedStorage.Shared.data.UiLayoutData).hud.v6
			local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
			local spec = Theme.isMobile and V6.phone.bossBar or V6.pc.bossBar
			local P = Theme.isMobile and V6.bossBar.phone or V6.bossBar.pc
			local view = Workspace.CurrentCamera.ViewportSize
			local m = HudPlace.scale(view.X, view.Y, Theme.isMobile)
			local r = HudPlace.screenRect(spec, spec.anchor, view.X, view.Y, m, Theme.isMobile)
			local sg = label:FindFirstAncestorOfClass("ScreenGui")
			local inset = (sg and not sg.IgnoreGuiInset) and game:GetService("GuiService"):GetGuiInset().Y or 0
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Position = UDim2.new(0.5, 0, 0, math.floor(r[2] + (P.name + P.bar + 4) * m - inset))
		end
		if not label:GetAttribute("BossHudFade") then
			label:SetAttribute("BossHudFade", true)
			local serial = 0
			local lastKey = nil
			local function fresh()
				local key = label.Text:gsub("%d", "") -- 리뷰 5: 남은 초만 바뀌는 글씨(매초 카운트다운)는 새 안내가 아니다 - 흐림 시계를 다시 세지 않는다
				if key == lastKey then
					return
				end
				lastKey = key
				serial += 1
				local mine = serial
				label.TextTransparency = 0
				task.delay(H.gimmickFadeSeconds, function()
					if mine == serial and label.Parent then
						label.TextTransparency = H.gimmickFadedTransparency
					end
				end)
			end
			label:GetPropertyChangedSignal("Text"):Connect(fresh)
			fresh()
		end
	else
		label.AnchorPoint = fallbackAnchor or Vector2.new(0.5, 0)
		label.Position = fallbackPosition
	end
end

return BossHudLayout
