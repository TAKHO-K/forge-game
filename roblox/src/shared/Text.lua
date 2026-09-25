-- 플레이어가 보는 문장의 단일 진입점(G1-1 - COMMON §2 "번역 가능한 문자열"). 문장 원문은 shared/data/TextData.lua에 키로 둔다.
-- Text.get(key, args): 템플릿의 {이름} 자리를 args.이름으로 채운다(순서가 아니라 이름 - 언어마다 어순이 달라도 같은 인자를 쓴다).
-- 문장 조각을 `..`로 이어붙이지 않는다(조사 · 어순이 언어마다 달라 번역이 깨진다). 숫자 형식은 호출하는 쪽이 문자열로 만들어 넘긴다.
-- 나중에(L 번역 단계) 이 함수 안에서 로블록스 Translator:FormatByKey로 바꿔 끼운다 - 호출하는 쪽은 그대로.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextData = require(ReplicatedStorage.Shared.data.TextData)

local Text = {}

function Text.get(key, args)
	local template = TextData.ko[key]
	if template == nil then
		warn(("[Text] 없는 키: %s"):format(tostring(key)))
		return tostring(key)
	end
	if args == nil then
		return template
	end
	return (template:gsub("{([%w_]+)}", function(name)
		local value = args[name]
		return value ~= nil and tostring(value) or ("{" .. name .. "}")
	end))
end

return Text
