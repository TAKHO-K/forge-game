-- 플레이어가 보는 문장의 단일 진입점(G1-1 - COMMON §2 "번역 가능한 문자열"). 문장 원문은 shared/data/TextData.lua에 키로 둔다.
-- Text.get(key, args): 템플릿의 {이름} 자리를 args.이름으로 채운다(순서가 아니라 이름 - 언어마다 어순이 달라도 같은 인자를 쓴다).
-- 문장 조각을 `..`로 이어붙이지 않는다(조사 · 어순이 언어마다 달라 번역이 깨진다). 숫자 형식은 호출하는 쪽이 문자열로 만들어 넘긴다.
-- QUEUE-ALL4 E 언어: 설정 키 language(SettingsData - "ko" 기본 · "en" · "auto" = 로블록스 계정 언어)를 Player Attribute로 읽는다.
--   클라 = 내 설정 · 서버 = Text.getFor(player, ...)로 그 플레이어 설정(서버가 보내는 문장) · 서버 Text.get = ko(여러 사람에게 같은 문장).
--   Studio 전용 확인: Workspace Attribute TextLanguageDev("ko" | "en")가 있으면 그 값이 우선(캡처용 - 창을 짓기 전에 정해진다).
--   en에 없는 키 = ko로 대체 + 경고 1회.
-- QUEUE-ALL6 A4 데이터 이름(보스 · 구역 · 몬스터 · 펫 · 등급 · 칭호 · 스킬 · 퀘스트 · 상품 …): 데이터에는 한국어 원문 그대로 두고 shared/data/TextData_names.lua
--   (원문 → 영어 사전 · 용어집 docs/i18n/glossary.md와 같은 말)로 화면에서 바꾼다. Text.name(원문) = 지금 언어의 이름(사전에 없으면 원문).
--   Text.get · getFor의 인자 값이 사전에 있는 원문이면 자동으로 바꾼다({boss} · {grade} · {part} 자리에 한국어가 들어가던 것).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")
local TextData = require(ReplicatedStorage.Shared.data.TextData)
local NameData = require(ReplicatedStorage.Shared.data.TextData_names)
local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)

local LANGUAGE_DEF = SettingsData.keys.language
local DEV_ATTRIBUTE = "TextLanguageDev"

local Text = {}

local warnedFallback = {}

-- 설정값 → 실제 언어("ko" | "en"). auto = 계정 언어가 한국어면 ko, 아니면 en.
local function resolve(setting, localeId)
	if setting == "auto" then
		return (type(localeId) == "string" and localeId:sub(1, 2) == "ko") and "ko" or "en"
	end
	if TextData[setting] ~= nil then
		return setting
	end
	return LANGUAGE_DEF.default
end

local function devOverride()
	if RunService:IsStudio() then
		local dev = workspace:GetAttribute(DEV_ATTRIBUTE)
		if dev ~= nil and TextData[dev] ~= nil then
			return dev
		end
	end
	return nil
end

-- 그 플레이어의 언어(서버 · 클라 둘 다). player 생략 = 클라의 내 언어(서버에서는 기본값).
function Text.languageFor(player)
	local dev = devOverride()
	if dev then
		return dev
	end
	if player == nil then
		if not RunService:IsClient() then
			return LANGUAGE_DEF.default
		end
		player = Players.LocalPlayer
		if player == nil then
			return LANGUAGE_DEF.default
		end
	end
	local setting = player:GetAttribute(LANGUAGE_DEF.attrs[1]) or LANGUAGE_DEF.default
	if setting ~= "auto" then
		return resolve(setting)
	end
	if RunService:IsClient() and player == Players.LocalPlayer then
		return resolve(setting, LocalizationService.RobloxLocaleId)
	end
	return resolve(setting, player.LocaleId)
end

-- 데이터 이름 바꾸기(언어를 정해 놓고). 통째로 없으면 " · "로 나뉜 조각을 하나씩(조각이 전부 사전에 있을 때만).
function Text.nameIn(language, s)
	if type(s) ~= "string" or language == "ko" then
		return s
	end
	local dict = NameData[language]
	if not dict then
		return s
	end
	local hit = dict[s]
	if hit then
		return hit
	end
	if s:find(" · ", 1, true) then
		local parts = s:split(" · ")
		for i, part in ipairs(parts) do
			parts[i] = dict[part]
			if parts[i] == nil then
				return s
			end
		end
		return table.concat(parts, " · ")
	end
	return s
end

-- 지금(내) 언어의 데이터 이름
function Text.name(s)
	return Text.nameIn(Text.languageFor(nil), s)
end

-- 그 플레이어 언어의 데이터 이름(서버)
function Text.nameFor(player, s)
	return Text.nameIn(Text.languageFor(player), s)
end

-- 언어를 정해 놓고 채우기(테스트 · 넘침 점검이 쓴다)
function Text.format(language, key, args)
	local template = TextData[language] and TextData[language][key]
	if template == nil and language ~= "ko" then
		template = TextData.ko[key]
		if template ~= nil and not warnedFallback[key] then
			warnedFallback[key] = true
			warn(("[Text] %s 없는 키 → ko 대체: %s"):format(language, tostring(key)))
		end
	end
	if template == nil then
		warn(("[Text] 없는 키: %s"):format(tostring(key)))
		return tostring(key)
	end
	if args == nil then
		return template
	end
	return (template:gsub("{([%w_]+)}", function(name)
		local value = args[name]
		if type(value) == "string" then
			value = Text.nameIn(language, value) -- QUEUE-ALL6 A4: 데이터 이름 인자 자동 번역
		end
		return value ~= nil and tostring(value) or ("{" .. name .. "}")
	end))
end

function Text.get(key, args)
	return Text.format(Text.languageFor(nil), key, args)
end

-- 서버가 한 플레이어에게 보내는 문장(그 플레이어 언어)
function Text.getFor(player, key, args)
	return Text.format(Text.languageFor(player), key, args)
end

-- QUEUE-ALL6R 3 월드 글자(서버가 짓는 BillboardGui · SurfaceGui의 TextLabel - 모든 클라에 같은 글로 복제된다): 서버는 키 + 인자(또는 데이터 이름)를 속성으로 붙이고
--   기본 글 = ko로 채운다 · 클라(client/WorldTextView)가 내 언어로 한 번 다시 쓴다. 속성: TextKey + TextArg_<이름>(문자열) · 또는 TextName(데이터 이름 하나).
function Text.bindLabel(label, key, args)
	label:SetAttribute("TextKey", key)
	for name, value in pairs(args or {}) do
		label:SetAttribute("TextArg_" .. name, tostring(value))
	end
	label.Text = Text.format("ko", key, args)
end
function Text.bindName(label, name)
	label:SetAttribute("TextName", name)
	label.Text = name
end
-- 클라: 붙은 속성대로 내 언어 글을 만든다(없으면 nil - 손대지 않는다)
function Text.labelText(label)
	local key = label:GetAttribute("TextKey")
	if type(key) == "string" then
		local args = {}
		for attr, value in pairs(label:GetAttributes()) do
			local name = attr:match("^TextArg_(.+)$")
			if name then
				args[name] = value
			end
		end
		return Text.get(key, args)
	end
	local name = label:GetAttribute("TextName")
	return type(name) == "string" and Text.name(name) or nil
end
-- 클라: 한 번만 바꿔 쓴다(WorldTextApplied = 이 클라에만 - 복제 안 됨). 몹 이름표는 GenerationView가 세대 앞말을 붙이기 전에 이걸 먼저 부른다(뒤에서 앞말을 덮지 않게).
function Text.applyLabel(label)
	if not label:IsA("TextLabel") or label:GetAttribute("WorldTextApplied") then
		return
	end
	local text = Text.labelText(label)
	if text then
		label:SetAttribute("WorldTextApplied", true)
		label.Text = text
	end
end

return Text
