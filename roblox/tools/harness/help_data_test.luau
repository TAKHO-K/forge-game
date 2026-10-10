-- UI-1b 1절 3 · 15 · 16: [?] 도움말(HelpData) · 재화 설명(CurrencyInfo) 문구 키 = ko · en 둘 다 · 틀(제목 + 줄 "항목: 글") · id 목록
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[HELP] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local T = MODS.TextData
	local H, CI = MODS.HelpData, MODS.CurrencyInfo
	local miss = {}
	local function need(key)
		if T.ko[key] == nil or T.en[key] == nil then
			table.insert(miss, key)
		end
	end
	local n = 0
	for _, id in ipairs(H.order) do
		local e = H.ids[id]
		need(e.title)
		for _, r in ipairs(e.rows) do
			need(r[1])
			need(r[2])
			n += 1
		end
	end
	check("도움말 키 ko · en(제목 + 줄)", #miss == 0, table.concat(miss, ","))
	check("도움말 id 10곳 = order와 ids 같음", #H.order == 10 and (function()
		for _, id in ipairs(H.order) do
			if not H.ids[id] then return false end
		end
		return true
	end)())
	miss = {}
	for id, e in pairs(CI.ids) do
		need(e.name)
		for _, r in ipairs(CI.rows) do
			need("ui1b.info.row." .. r)
			need("ui1b.cur." .. id .. "." .. r)
		end
	end
	check("재화 설명 키 ko · en(이름 · 획득처 · 사용처)", #miss == 0, table.concat(miss, ","))
	check("재화 설명 틀 = 획득처 → 사용처(사용자 10-10)", CI.rows[1] == "where" and CI.rows[2] == "use" and #CI.rows == 2 and T.ko["ui1b.info.row.where"] == "획득처" and T.ko["ui1b.info.row.use"] == "사용처")
end)
if not okRun then
	print("[HELP] 하네스 에러 " .. tostring(err))
end
print(("[HELP] 끝 %d/%d"):format(pass, total))
