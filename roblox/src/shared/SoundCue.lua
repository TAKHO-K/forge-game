-- B4 사운드 순수 계산(게임 서비스 없음 - 로컬 luau 테스트 가능). 재생은 client/SoundHooks.client.lua.
--   resolve(eventId, soundData, categoryVolumes) → 재생할 { soundId, volume, pitch, category } | nil(표에 없음 · 빈 ID · 최종 음량 0).
--   categoryVolumes[category] = 0 ~ 1(설정값 - 없으면 1). 최종 음량 = 이벤트 volume × 카테고리 음량.
local SoundCue = {}

local function clamp01(v)
	if type(v) ~= "number" or v ~= v then
		return 1
	end
	return math.clamp(v, 0, 1)
end

function SoundCue.finalVolume(baseVolume, categoryVolume)
	local base = (type(baseVolume) == "number" and baseVolume == baseVolume) and math.max(baseVolume, 0) or 1
	return base * clamp01(categoryVolume)
end

function SoundCue.resolve(eventId, soundData, categoryVolumes)
	local entry = soundData.events[eventId]
	if not entry or type(entry.soundId) ~= "string" or entry.soundId == "" then
		return nil
	end
	local volume = SoundCue.finalVolume(entry.volume, categoryVolumes and categoryVolumes[entry.category])
	if volume <= 0 then
		return nil
	end
	return { soundId = entry.soundId, volume = volume, pitch = entry.pitch or 1, category = entry.category }
end

-- 드랍 등급 → 이벤트 id(표에 없으면 nil)
function SoundCue.dropEvent(gradeId, soundData)
	return gradeId ~= nil and soundData.dropGradeEvents[gradeId] or nil
end

-- 강화 결과 payload.result → 이벤트 id. greatFromLevel = 대성공 기준 단계(EnhanceConfig.announceFromLevel - 서버 방송과 같은 선).
-- 성공 · 실패가 아닌 결과(max · 골드 부족 · 재료 부족 · 규제)는 nil.
local FAIL = { maintain = true, down1 = true, down2 = true, reset = true }
function SoundCue.enhanceEvent(result, level, greatFromLevel)
	if result == "success" then
		if type(level) == "number" and type(greatFromLevel) == "number" and level >= greatFromLevel then
			return "enhanceGreat"
		end
		return "enhanceSuccess"
	elseif FAIL[result] then
		return "enhanceFail"
	end
	return nil
end

-- 레벨업 판정: 같은 직업에서 레벨이 올랐을 때만(첫 값 · 직업 전환 · 환생으로 내려감 = 아님)
function SoundCue.isLevelUp(prevLevel, newLevel, prevClassId, newClassId)
	return type(prevLevel) == "number" and type(newLevel) == "number" and newLevel > prevLevel and prevClassId == newClassId
end

-- 펫 부화 판정: 누적 부화 수가 늘었을 때(첫 동기화 = 기준값만)
function SoundCue.isHatch(prevCount, newCount)
	return type(prevCount) == "number" and type(newCount) == "number" and newCount > prevCount
end

-- 연타 간격(minInterval 없음 = 제한 없음)
function SoundCue.intervalOk(lastAt, now, minInterval)
	return lastAt == nil or minInterval == nil or now - lastAt >= minInterval
end

return SoundCue
