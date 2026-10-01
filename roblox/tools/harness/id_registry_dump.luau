-- QUEUE-ALL5 A3: 지금 데이터의 저장 id 목록을 줄마다 "IDS <종류> <id>"로 찍는다(roblox/tools/ids/id_registry.py가 읽는다).
local lists = MODS.IdRegistry.lists()
for _, kind in ipairs(MODS.IdRegistry.kinds) do
	for _, id in ipairs(lists[kind]) do
		print("IDS " .. kind .. " " .. id)
	end
end
print("IDS-END")
