-- UI-1b 1-b 10: 창 층 표(WindowLayers) - 나중에 연 창이 위 · 창 > HUD 메뉴 · 설명 창 > 창 · 확인 창(overlay) > 전부 · 대역 상한
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[WLAY] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local W = MODS.WindowLayers
	local L = W.L
	local o = W.stackOrders({ "window", "window" }) -- 출석(자동) → 장비창(나중)
	check("출석 → 장비창 = 장비창이 위", o[2] > o[1], ("%d < %d"):format(o[1], o[2]))
	local o2 = W.stackOrders({ "window", "window", "window" })
	check("세 창 = 연 순서대로 위", o2[1] < o2[2] and o2[2] < o2[3])
	check("창(맨 아래) > HUD 메뉴", W.stackOrders({ "window" })[1] > L.hudMenu, ("%d > %d"):format(W.stackOrders({ "window" })[1], L.hudMenu))
	local many = {}
	for i = 1, 100 do many[i] = "window" end
	local om = W.stackOrders(many)
	check("창 100개여도 대역 상한(설명 창 아래)", om[100] <= L.windowMax and L.windowMax < L.tip, tostring(om[100]))
	check("설명 창 < 확인 창(overlay)", L.tip < L.overlay)
	local o3 = W.stackOrders({ "station", "window", "overlay" })
	check("강화대(station) < 창 < 확인 창", o3[1] < o3[2] and o3[2] < o3[3] and o3[1] < L.hudMenu)
	local o4 = W.stackOrders({ "window", "station" })
	check("나중에 연 station도 창보다 아래(창이 막는 규칙)", o4[2] < o4[1])
end)
if not okRun then
	print("[WLAY] 하네스 에러 " .. tostring(err))
end
print(("[WLAY] 끝 %d/%d"):format(pass, total))
