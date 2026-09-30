-- QUEUE-ALL2 P5 사운드 시트 재생(09 문서 C). 효과음 38개 = 파일 3개(SoundSheetData - 절차 합성 · 피크 −1dB) · 재생 = Sound.PlaybackRegion(시작 ~ 시작 + 길이).
--   SoundGroup 4 = Effects · UI · Ambient · Music(자리) - 음량 = 설정 Attribute(SoundVolumeSfx · Ui · Ambient · Music - 서버 SettingsService가 저장값을 건다).
--   SoundSheet.play(cueId, opts) - opts.part(3D 자리 · 거리 감쇠) · opts.volume(곱) · opts.other(남의 소리 = × otherScale) · opts.pitch · opts.minInterval(같은 큐 연타 간격).
--   에셋 id = ArtAssetIds["audio/sfx_*"](upload.py) · 없으면 소리 없음(오류 없음).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundSheetData = require(ReplicatedStorage.Shared.data.SoundSheetData)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)

local SoundSheet = {}

SoundSheet.otherScale = 0.45 -- 남의 소리(09 문서 C "남의 효과음은 작게")
SoundSheet.rollOffMax = 90 -- 3D 소리 최대 거리(stud)
local GROUP_ATTR = { Effects = "SoundVolumeSfx", UI = "SoundVolumeUi", Ambient = "SoundVolumeAmbient", Music = "SoundVolumeMusic" }

local player = Players.LocalPlayer
local groups = {}
local folder = Instance.new("Folder")
folder.Name = "SoundSheet"
folder.Parent = SoundService

local function group(name)
	local g = groups[name]
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
		groups[name] = g
		local attr = GROUP_ATTR[name]
		local function apply()
			local v = attr and player:GetAttribute(attr)
			g.Volume = type(v) == "number" and math.clamp(v, 0, 1) or 1
		end
		if attr then
			player:GetAttributeChangedSignal(attr):Connect(apply)
		end
		apply()
	end
	return g
end
for _, name in ipairs(SoundSheetData.groups) do
	group(name)
end

local function sheetId(sheetKey)
	local sheet = SoundSheetData.sheets[sheetKey]
	local e = sheet and ArtAssetIds[sheet.file]
	return e and e.id and ("rbxassetid://" .. tostring(e.id)) or nil
end

local lastAt = {}
function SoundSheet.play(cueId, opts)
	opts = opts or {}
	local cue = cueId and SoundSheetData.cues[cueId]
	local id = cue and sheetId(cue.sheet)
	if not id then
		return nil
	end
	local now = os.clock()
	if opts.minInterval and lastAt[cueId] and now - lastAt[cueId] < opts.minInterval then
		return nil
	end
	lastAt[cueId] = now
	local s = Instance.new("Sound")
	s.Name = cueId
	s.SoundId = id
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(cue.start, cue.start + cue.duration)
	s.Volume = (cue.volume or 1) * (opts.volume or 1) * (opts.other and SoundSheet.otherScale or 1)
	s.PlaybackSpeed = opts.pitch or 1
	s.SoundGroup = group(cue.group or "Effects")
	if opts.part then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMaxDistance = SoundSheet.rollOffMax
		s.Parent = opts.part
	else
		s.Parent = folder
	end
	s:Play()
	task.delay(cue.duration / (opts.pitch or 1) + 0.2, function()
		s:Destroy()
	end)
	return s
end

function SoundSheet.has(cueId)
	return SoundSheetData.cues[cueId] ~= nil
end

return SoundSheet
