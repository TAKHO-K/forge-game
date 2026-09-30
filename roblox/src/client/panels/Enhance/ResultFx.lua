-- QUEUE-ALL2 P4 2순위: 강화 패널 결과 연출(docs/visual-audit.md 9 · 10 · 11 · 1순위 ⑥ 패널 쪽). 판정 · 문구 없음 - 결과 줄 · 제목을 잠깐 움직이기만 한다. 수치 = FxMomentData.enhancePanel.
--   성공 = 제목(단계 숫자) 팝 + 결과 줄 확대 · 하락 = 제목 단계 숫자가 굴러 내려감(0.4초) + 결과 줄 좌우 흔들기 · 초기화 = 22 → 12 굴림(0.8초, 떨어질수록 빨라짐) ·
--   유지 = 결과 줄 흔들기 · 방지권이 막음 = 결과 줄 초록 + 그 방지권 줄 팝(3D 방패 링은 ArtV1View).
--   아트 끔 · 연출 세기 끔(FxScale 0) = 아무것도 안 함(옛 모습). 굴리는 동안은 refresh가 제목을 덮지 않는다(ResultFx.rolling).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local P = require(ReplicatedStorage.Shared.data.FxMomentData).enhancePanel
local FxMoment = require(script.Parent.Parent.Parent.FxMoment)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local ResultFx = {}
local player = Players.LocalPlayer

-- 결과 직전 단계(서버는 WeaponLevel을 먼저 바꾸고 결과를 보낸다 - 바뀌기 전 값을 기억)
local prevLevel = player:GetAttribute("WeaponLevel") or 0
local curLevel = prevLevel
player:GetAttributeChangedSignal("WeaponLevel"):Connect(function()
	prevLevel = curLevel
	curLevel = player:GetAttribute("WeaponLevel") or 0
end)

local rollToken = 0
local rollingUntil = 0
function ResultFx.rolling()
	return os.clock() < rollingUntil
end

local function fromLevel(data)
	local result, level = data.result, data.level or curLevel
	if result == "success" then
		return level - 1
	elseif result == "down1" then
		return level + 1
	elseif result == "down2" then
		return level + 2
	elseif result == "reset" then
		local from = (curLevel == level) and prevLevel or curLevel
		local _, resetFrom = Enhance.getRiskStartLevels()
		return from > level and from or resetFrom
	end
	return level
end

-- 제목 단계 숫자 굴림: from → to. 누적 시간 = sqrt(i / n) × seconds(처음 느리고 떨어질수록 빨라짐)
local function roll(refs, from, to, seconds, titleFor, onDone)
	rollToken += 1
	local mine = rollToken
	rollingUntil = os.clock() + seconds + 0.05
	local steps = math.max(1, from - to)
	task.spawn(function()
		local t0 = os.clock()
		for i = 1, steps do
			local at = math.sqrt(i / steps) * seconds
			local wait = at - (os.clock() - t0)
			if wait > 0 then
				task.wait(wait)
			end
			if mine ~= rollToken or not refs.panel.titleLabel.Parent then
				return
			end
			refs.panel.titleLabel.Text = titleFor(from - i)
		end
		rollingUntil = 0
		onDone()
	end)
end

-- 결과 줄 좌우 흔들기(UI만)
local basePos = setmetatable({}, { __mode = "k" }) -- 연타로 흔들기가 겹쳐도 원래 자리로 돌아오게
local function shake(label, strength)
	local S = P.failShake
	basePos[label] = basePos[label] or label.Position
	local base = basePos[label]
	local frames = S.cycles * 2
	task.spawn(function()
		for i = 1, frames do
			local amp = S.pixels * strength * (1 - (i - 1) / frames) * (i % 2 == 1 and 1 or -1)
			label.Position = base + UDim2.fromOffset(amp, 0)
			task.wait(S.seconds / frames)
		end
		label.Position = base
	end)
end

-- data = EnhanceResult payload · titleFor(level) = 그 단계로 쓴 제목 문구 · refresh = 패널 다시 그리기(굴림 끝)
function ResultFx.play(refs, data, titleFor, refresh)
	local k = FxMoment.scale()
	if k <= 0 or type(data) ~= "table" then
		return
	end
	local result = data.result
	if data.blockedBy then
		refs.resultLabel.TextColor3 = Theme.color("success")
		FxMoment.pop(refs.resultLabel, P.resultPop.scale, P.resultPop.seconds, k)
		local row = refs.tickets and refs.tickets[data.blockedBy]
		if row then
			FxMoment.pop(row.toggle.root, P.ticketPop.scale, P.ticketPop.seconds, k)
		end
		return
	end
	if result == "success" then
		FxMoment.pop(refs.panel.titleLabel, P.successPop.scale, P.successPop.seconds, k)
		FxMoment.pop(refs.resultLabel, P.resultPop.scale, P.resultPop.seconds, k)
	elseif result == "maintain" then
		shake(refs.resultLabel, k)
	elseif result == "down1" or result == "down2" or result == "reset" then
		shake(refs.resultLabel, k)
		local from, to = fromLevel(data), data.level or EnhanceConfig.resetToLevel
		if from > to then
			refs.panel.titleLabel.Text = titleFor(from)
			roll(refs, from, to, (result == "reset" and P.resetRoll or P.failRoll).seconds, titleFor, function()
				refresh()
				if result == "reset" then
					FxMoment.pop(refs.panel.titleLabel, P.resultPop.scale, P.resultPop.seconds, k) -- 12에 떨어져 멈춤
				end
			end)
		end
	end
end

return ResultFx
