-- SEC-FIX-1 9: 로거 한 곳(단계 = shared/data/LogConfig). 라이브 서버 파일은 맨 위에서 `local print = require(…Shared.Log).info`로 옛 print를 INFO로 돌린다
--   (줄마다 고치지 않아 형식 · 검증 로그가 그대로 - Studio = DEBUG라 지금과 같이 찍힌다). 하네스 sec_log_static이 라이브 파일의 가림 줄을 검사한다.
local RunService = game:GetService("RunService")
local LogConfig = require(script.Parent.data.LogConfig)

local Log = {}
local LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, OFF = 4 }
Log.LEVELS = LEVELS

-- 순수: 그 환경의 단계 번호
function Log.levelFor(isStudio)
	return LEVELS[isStudio and LogConfig.studioLevel or LogConfig.liveLevel] or LEVELS.WARN
end

local current = Log.levelFor(RunService:IsStudio())

function Log.level()
	return current
end

-- 운영 · 검증용(그 서버에서만 · 저장 안 함)
function Log.setLevel(name)
	if LEVELS[name] then
		current = LEVELS[name]
		return true
	end
	return false
end

function Log.debug(...)
	if current <= LEVELS.DEBUG then
		print(...)
	end
end

function Log.info(...)
	if current <= LEVELS.INFO then
		print(...)
	end
end

function Log.warn(...)
	if current <= LEVELS.WARN then
		warn(...)
	end
end

return Log
