-- QUEUE-ALL2 P5 사운드 시트 재생(09 문서 C). 효과음 = 파일 3개(SoundSheetData - 절차 합성 · 피크 −1dB) · 재생 = Sound.PlaybackRegion(시작 ~ 시작 + 길이).
--   QUEUE-ALL7 C: 믹스 규칙 = shared/data/SoundMixData(한 곳) - SoundGroup 4(Music · Ambient · SFX · UI) 기준 음량 × 설정 · 중요도 단계 음량 · 남의 소리 × 0.5(T1 · T2 예외)
--     · 같은 큐 동시 3 · 최소 간격 0.06 · SFX 전체 동시 12(넘치면 낮은 단계부터 버림) · 타격류 음높이 ±5% · 초월 덕킹(Music · Ambient 3초 50%).
--   SoundSheet.play(cueId, opts) - opts.part(3D 자리 · 거리 감쇠) · opts.volume(곱) · opts.other(남의 소리) · opts.pitch · opts.minInterval(같은 큐 연타 간격).
--   SoundSheet.playRaw(soundId, opts) - 시트 밖 소리(같은 그룹 · 같은 제한 · opts.tier 필수) · SoundSheet.stats = 검증용 집계.
--   에셋 id = ArtAssetIds["audio/sfx_*"](upload.py) · 없으면 소리 없음(오류 없음).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SoundSheetData = require(ReplicatedStorage.Shared.data.SoundSheetData)
local Mix = require(ReplicatedStorage.Shared.data.SoundMixData)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)

local SoundSheet = {}

SoundSheet.otherScale = Mix.otherScale
SoundSheet.rollOffMax = Mix.rollOffMaxDistance
local GROUP_ATTR = { SFX = "SoundVolumeSfx", UI = "SoundVolumeUi", Ambient = "SoundVolumeAmbient", Music = "SoundVolumeMusic" }
local QUIET_OTHERS_ATTR = "QuietOthersSfx" -- 설정 "다른 플레이어 효과음 줄이기"(SettingsData quietOthersSfx)

local player = Players.LocalPlayer
local groups = {}
local duckUntil = 0
local folder = Instance.new("Folder")
folder.Name = "SoundSheet"
folder.Parent = SoundService

-- 검증용 집계(QUEUE-ALL7 C4): 지금 동시 재생 · 최대 · 버린 수(이유별) · 재생 수
SoundSheet.stats = { playing = 0, maxPlaying = 0, played = 0, dropped = { interval = 0, perCue = 0, sfxFull = 0 }, evicted = 0 }

local function groupName(name)
	return Mix.groupAlias[name] or name or "SFX"
end

local function applyGroup(name)
	local g = groups[name]
	if not g then
		return
	end
	local attr = GROUP_ATTR[name]
	local v = attr and player:GetAttribute(attr)
	local setting = type(v) == "number" and math.clamp(v, 0, 1) or 1
	local duck = (os.clock() < duckUntil and table.find(Mix.duck.groups, name)) and Mix.duck.scale or 1
	g.Volume = (Mix.groups[name] or 1) * setting * duck
end

local function group(name)
	name = groupName(name)
	local g = groups[name]
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
		groups[name] = g
		local attr = GROUP_ATTR[name]
		if attr then
			player:GetAttributeChangedSignal(attr):Connect(function()
				applyGroup(name)
			end)
		end
		applyGroup(name)
	end
	return g
end
for name in pairs(Mix.groups) do
	group(name)
end
SoundSheet.group = group

local function duck()
	duckUntil = os.clock() + Mix.duck.seconds
	for _, name in ipairs(Mix.duck.groups) do
		applyGroup(name)
	end
	task.delay(Mix.duck.seconds + 0.05, function()
		for _, name in ipairs(Mix.duck.groups) do
			applyGroup(name)
		end
	end)
end

local function sheetId(sheetKey)
	local sheet = SoundSheetData.sheets[sheetKey]
	local e = sheet and ArtAssetIds[sheet.file]
	return e and e.id and ("rbxassetid://" .. tostring(e.id)) or nil
end

-- 동시 재생 관리: active = { { sound, key, tier(숫자 - 클수록 덜 중요), sfx } }
local active = {}
local lastAt = {}
local function tierRank(tier)
	return type(tier) == "number" and tier or (tier == "ui" and 6 or 7)
end
local function removeActive(s)
	for i = #active, 1, -1 do
		if active[i].sound == s then
			table.remove(active, i)
		end
	end
	SoundSheet.stats.playing = #active
end

-- 반환: 재생해도 되는가(필요하면 낮은 단계 SFX 하나를 멈춘다)
local function admit(key, tier, isSfx, minInterval)
	local now = os.clock()
	local gap = minInterval or Mix.minIntervalDefault
	if lastAt[key] and now - lastAt[key] < gap then
		SoundSheet.stats.dropped.interval += 1
		return false
	end
	local same = 0
	for _, a in ipairs(active) do
		if a.key == key then
			same += 1
		end
	end
	if same >= Mix.perCueMax then
		SoundSheet.stats.dropped.perCue += 1
		return false
	end
	if isSfx then
		local count, worst = 0, nil
		for _, a in ipairs(active) do
			if a.sfx then
				count += 1
				if not worst or tierRank(a.tier) > tierRank(worst.tier) then
					worst = a
				end
			end
		end
		if count >= Mix.sfxMax then
			if worst and tierRank(worst.tier) > tierRank(tier) then
				SoundSheet.stats.evicted += 1
				worst.sound:Destroy()
				removeActive(worst.sound)
			else
				SoundSheet.stats.dropped.sfxFull += 1
				return false
			end
		end
	end
	lastAt[key] = now
	return true
end

local function start(s, key, tier, isSfx, seconds)
	table.insert(active, { sound = s, key = key, tier = tier, sfx = isSfx })
	SoundSheet.stats.played += 1
	SoundSheet.stats.playing = #active
	SoundSheet.stats.maxPlaying = math.max(SoundSheet.stats.maxPlaying, #active)
	s:Play()
	if tier == Mix.duck.tier then
		duck()
	end
	task.delay(seconds + 0.2, function()
		removeActive(s)
		s:Destroy()
	end)
	s.Destroying:Connect(function()
		removeActive(s)
	end)
end

-- 최종 음량(그룹 밖 - Sound.Volume): 단계 × gain × opts.volume × 남의 소리 배율
local function volumeOf(spec, opts)
	local tierVol = Mix.tierVolume[spec.tier] or 0.5
	local other = 1
	if opts.other and not Mix.otherExemptTiers[spec.tier] then
		other = player:GetAttribute(QUIET_OTHERS_ATTR) == true and Mix.otherQuietScale or Mix.otherScale
	end
	return tierVol * (spec.gain or 1) * (opts.volume or 1) * other
end

local function place(s, opts, groupKey)
	s.SoundGroup = group(groupKey)
	if opts.part then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMaxDistance = SoundSheet.rollOffMax
		s.Parent = opts.part
	else
		s.Parent = folder
	end
end

function SoundSheet.play(cueId, opts)
	opts = opts or {}
	local cue = cueId and SoundSheetData.cues[cueId]
	local id = cue and sheetId(cue.sheet)
	if not id then
		return nil
	end
	local spec = Mix.cues[cueId] or { tier = 4 }
	local groupKey = groupName(cue.group or "Effects")
	local isSfx = groupKey == "SFX"
	if not admit(cueId, spec.tier, isSfx, opts.minInterval) then
		return nil
	end
	local pitch = opts.pitch or 1
	if spec.jitter then
		pitch *= 1 + (math.random() * 2 - 1) * spec.jitter
	end
	local s = Instance.new("Sound")
	s.Name = cueId
	s.SoundId = id
	s.PlaybackRegionsEnabled = true
	local length = spec.maxSeconds and math.min(cue.duration, spec.maxSeconds) or cue.duration -- 믹스 표가 앞부분만 쓰게 자를 수 있다(대시 = 짧게)
	s.PlaybackRegion = NumberRange.new(cue.start, cue.start + length)
	s.Volume = volumeOf(spec, opts)
	s.PlaybackSpeed = pitch
	place(s, opts, groupKey)
	start(s, cueId, spec.tier, isSfx, length / pitch)
	return s
end

-- 시트 밖 소리(보스 기믹 임시 핑 등) - 같은 그룹 · 같은 제한. opts.tier · opts.group(기본 SFX) · opts.seconds(길이 - 모르면 2)
function SoundSheet.playRaw(soundId, opts)
	opts = opts or {}
	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end
	local spec = { tier = opts.tier or 4 }
	local groupKey = groupName(opts.group or "SFX")
	local isSfx = groupKey == "SFX"
	if not admit(soundId, spec.tier, isSfx, opts.minInterval) then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Raw"
	s.SoundId = soundId
	s.Volume = volumeOf(spec, opts)
	s.PlaybackSpeed = opts.pitch or 1
	place(s, opts, groupKey)
	-- 리뷰: 길이를 모르는 소리는 끝날 때 지운다(정해 둔 초에 자르지 않는다 - 안전 상한 opts.maxSeconds 또는 10초)
	start(s, soundId, spec.tier, isSfx, opts.seconds or (opts.maxSeconds or 10))
	if not opts.seconds then
		s.Ended:Connect(function()
			removeActive(s)
			s:Destroy()
		end)
	end
	return s
end

function SoundSheet.has(cueId)
	return SoundSheetData.cues[cueId] ~= nil
end

-- 검증 훅(Studio): 클라 execute_luau가 같은 모듈 사본으로 재생 · 집계를 본다(require 사본 문제 - 훅으로 이 인스턴스를 부른다)
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "SoundSheetHook"
	hook.OnInvoke = function(action, a, b)
		if action == "play" then
			return SoundSheet.play(a, b)
		elseif action == "stats" then
			return SoundSheet.stats
		elseif action == "reset" then
			SoundSheet.stats = { playing = #active, maxPlaying = #active, played = 0, dropped = { interval = 0, perCue = 0, sfxFull = 0 }, evicted = 0 }
			return true
		elseif action == "groups" then
			local out = {}
			for name, g in pairs(groups) do
				out[name] = g.Volume
			end
			return out
		end
		return nil
	end
	hook.Parent = folder
end

return SoundSheet
