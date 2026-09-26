-- D1 태초 각인 · 출처 문구(배너 · 장비 상세 · 명예의 전당이 같은 함수). 데이터 = item.primordial · item.source(server/PrimordialRegistry 주석).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local PrimordialStamp = {}

local zoneNames = {}
for _, zone in pairs(WorldMapData.zones) do
	if type(zone) == "table" and zone.key then
		zoneNames[zone.key] = zone.theme or zone.key
	end
end

-- 출처 → "전갈 여왕 · 스테이지 20" / "모래 유적 · 스테이지 20" / "토벌: 전갈 여왕 · 스테이지 20"
function PrimordialStamp.sourceText(source)
	if type(source) ~= "table" then
		return nil
	end
	local where
	if source.bossId then
		local boss = BossData.bosses[source.bossId]
		where = boss and boss.displayName or source.bossId
		if source.kind == "raid" then
			where = "토벌: " .. where
		end
	elseif source.zone then
		where = zoneNames[source.zone] or source.zone
		if source.kind == "sparkle" then
			where = where .. "(반짝이)"
		end
	elseif source.kind == "dev" then
		where = "시험"
	end
	if not where then
		return nil
	end
	return source.stage and ("%s · 스테이지 %d"):format(where, source.stage) or where
end

-- 번호 줄: "세계 37번째 태초" · 옛 태초 = "이전 태초" · 번호 확정 실패 = "태초(번호 없음)"
function PrimordialStamp.numberText(stamp)
	if type(stamp) ~= "table" then
		return nil
	end
	if stamp.legacy then
		return "이전 태초"
	end
	if stamp.no then
		return ("세계 %d번째 태초"):format(stamp.no)
	end
	if stamp.pending then
		return "태초(세계 번호 확인 중)"
	end
	return "태초(번호 없음)"
end

function PrimordialStamp.dateText(at)
	if type(at) ~= "number" or at <= 0 then
		return nil
	end
	return os.date("!%Y-%m-%d", at)
end

-- 상세 한 줄: "★ 세계 37번째 태초 · 최초 획득 호영 · 2026-10-02 · 전갈 여왕 · 스테이지 20"
function PrimordialStamp.detailLine(stamp)
	local head = PrimordialStamp.numberText(stamp)
	if not head then
		return nil
	end
	local parts = { "★ " .. head }
	if stamp.ownerName and not stamp.legacy then
		table.insert(parts, "최초 획득 " .. stamp.ownerName)
	end
	for _, piece in ipairs({ PrimordialStamp.dateText(stamp.at) or false, PrimordialStamp.sourceText(stamp.source) or false }) do
		if piece then
			table.insert(parts, piece)
		end
	end
	return table.concat(parts, " · ")
end

return PrimordialStamp
