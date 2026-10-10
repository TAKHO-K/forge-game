-- QUEUE-10h Q14 P4d 설정 저장 서버: Remote SettingsSave(key, value) → 검증(SettingsData) → profile.settings(SAVE v54) → Player Attribute 적용. 로드 때 저장값 전부 적용.
--   자동 스테이지(AutoStage.server)는 Attribute AutoStage를 읽고 그 Remote(AutoStageSetting)가 SettingsService.set으로 저장한다(입구 하나).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)
local AutoStageData = require(ReplicatedStorage.Shared.data.AutoStageData)
local PlayerProfile = require(script.Parent.PlayerProfile)

local SettingsService = {}

local function validPreset(id)
	for _, preset in ipairs(AutoStageData.presets) do
		if preset.id == id then
			return true
		end
	end
	return false
end

local function defaultOf(key)
	local def = SettingsData.keys[key]
	if def.kind == "preset" then
		return AutoStageData.default
	end
	return def.default
end

-- 값 검증: 맞으면 값, 아니면 nil
function SettingsService.sanitize(key, value)
	local def = SettingsData.keys[key]
	if not def then
		return nil
	end
	if def.kind == "boolean" then
		if type(value) == "boolean" then -- (a and b or nil 꼴은 false를 nil로 바꾼다 - "끄기"가 저장 안 되던 것)
			return value
		end
		return nil
	elseif def.kind == "preset" then
		return type(value) == "string" and validPreset(value) and value or nil
	elseif def.kind == "choice" then -- QUEUE-ALL1 P3: 정해진 값 중 하나
		return type(value) == "string" and table.find(def.options, value) and value or nil
	elseif def.kind == "volume" then -- B4 음량: 0 ~ 1 숫자(NaN · 범위 밖 = 거절) · 소수 둘째 자리로 맞춤(0.1 단계 누적 오차)
		if type(value) == "number" and value == value and value >= 0 and value <= 1 then
			return math.floor(value * 100 + 0.5) / 100
		end
		return nil
	elseif def.kind == "positions" then -- QUEUE-ALL9C 1-8 창 위치 "id:x,y;…"(짧은 글 · 모양만 검사 · 좌표 ±10000 · 화면 안 자르기는 클라)
		if type(value) ~= "string" or #value > 800 then
			return nil
		end
		if value == "" then
			return value
		end
		for entry in (value .. ";"):gmatch("([^;]*);") do
			local id, x, y = entry:match("^([%w_]+):(%-?%d+),(%-?%d+)$")
			if not id or #id > 40 or math.abs(tonumber(x)) > 10000 or math.abs(tonumber(y)) > 10000 then
				return nil
			end
		end
		return value
	elseif def.kind == "hudLayout" then -- UI-1 7b HUD 편집 배치: 화면 밖 · 상단 바 · 로블록스 버튼 자리 · 모르는 요소 id = 거절(클라 검사와 같은 함수)
		if require(ReplicatedStorage.Shared.HudEditRules).validate(def.device, value) then
			return value
		end
		return nil
	elseif def.kind == "stamp" then -- QUEUE-ALL9A 1-2: 시각 도장(유닉스 초 정수 - 주말 배너 본 창)
		if type(value) == "number" and value == math.floor(value) and value >= 0 and value < 2 ^ 40 then
			return value
		end
		return nil
	end
	return nil
end

local function apply(player, key, value)
	for _, attr in ipairs(SettingsData.keys[key].attrs) do
		player:SetAttribute(attr, value)
	end
end

function SettingsService.set(player, key, value)
	local v = SettingsService.sanitize(key, value)
	local settings = PlayerProfile.getSettings(player)
	if v == nil or not settings then
		return false
	end
	settings[key] = v
	apply(player, key, v)
	return true
end

function SettingsService.onLoaded(player)
	local settings = PlayerProfile.getSettings(player)
	if not settings then
		return
	end
	for _, key in ipairs(SettingsData.order) do
		local v = SettingsService.sanitize(key, settings[key])
		if v == nil then
			v = defaultOf(key)
		end
		apply(player, key, v)
	end
end

function SettingsService.start()
	local remote = ReplicatedStorage:FindFirstChild("SettingsSave") or Instance.new("RemoteEvent")
	remote.Name = "SettingsSave"
	remote.Parent = ReplicatedStorage
	local last = {} -- [Player][key] = { at, pending } - 리뷰: 키마다 · 너무 빠른 요청은 버리지 않고 마지막 값을 잠시 뒤 적용(trailing)
	remote.OnServerEvent:Connect(function(player, key, value)
		if type(key) ~= "string" or not SettingsData.keys[key] then
			return
		end
		last[player] = last[player] or {}
		local rec = last[player][key] or { at = 0 }
		last[player][key] = rec
		local now = os.clock()
		if now - rec.at >= 0.1 then
			rec.at = now
			SettingsService.set(player, key, value)
			require(script.Parent.ImmediateSave).request(player)
			return
		end
		local scheduled = rec.pending ~= nil
		rec.pending = { value = value }
		if not scheduled then
			task.delay(0.1, function()
				local p = rec.pending
				rec.pending = nil
				if p and player.Parent then
					rec.at = os.clock()
					SettingsService.set(player, key, p.value)
					require(script.Parent.ImmediateSave).request(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return SettingsService
