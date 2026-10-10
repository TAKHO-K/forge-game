-- SEC-FIX-1 6 폴링 사이 순간이동 공격 재현 하네스(실제 HeightGuard 순수 판정 - 폴링 evaluateHorizontal과 같은 상태 표).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=HeightGuard ECON_RES=res_secmove.txt python build_run.py sec_move_test.luau
-- 옛 코드 실패 확인 = ECON_SRC=<옛 src>(옛 = 요청 순간 검사 없음 → 요청은 늘 통과 · 폴링만 0.25초마다). 끝 줄 "[SECMOVE] 끝 n/m".
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECMOVE] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local HG, MC = MODS.HeightGuard, MODS.MovementConfig
	local MG = MC.moveGuard
	-- 옛 = 요청 순간 검사 없음(공격 · 스킬 입구가 위치를 안 봄) → 통과
	local requestOk = HG.requestPositionOk or function() return true, 0, math.huge end
	local walk = MC.walkSpeedStuds * MC.moveSpeedMaxMultiplier * MG.walkMargin
	local ctx = { rate = walk, exempt = false, grace = false }
	local function polled(now)
		local st = HG.newState()
		HG.evaluateHorizontal(st, { pos = Vector3.new(0, 0, 0) }, now - 1, ctx) -- 기준 잡기
		HG.evaluateHorizontal(st, { pos = Vector3.new(0, 0, 0) }, now - 0.1, ctx) -- 0.1초 전 폴링(제자리 = 통 가득)
		return st
	end
	local now = 100
	local st = polled(now)
	local ok1, d1, a1 = requestOk(st, Vector3.new(200, 0, 0), now, ctx)
	check("6 폴링 0.1초 뒤 200 stud 떨어진 자리에서 공격 = 거절(옛 = 통과 → 치고 다음 폴링 전에 돌아옴)", not ok1, ("거리 %.0f · 허용 %.1f"):format(d1, a1))
	local ok2, d2, a2 = requestOk(st, Vector3.new(40, 0, 0), now, ctx)
	check("6 통 가득(약 42 stud)이어도 40 stud 순간이동 공격 = 거절(옛 = 통과)", not ok2, ("거리 %.0f · 허용 %.1f"):format(d2, a2))
	local ok3 = requestOk(st, Vector3.new(walk * 0.1, 0, 0), now, ctx)
	check("6 걷기 0.1초분 이동 뒤 공격 = 통과(정상)", ok3)
	local ok4 = requestOk(st, Vector3.new(walk * 0.6, 0, 0), now, ctx)
	check("6 지연 흔들림(0.5초분 더) 안 = 통과(정상 · 오탐 없음)", ok4)
	HG.bankAt(st, 30 * MG.dashMargin, MG.dashWindowSeconds, now - 0.05)
	local ok5, d5, a5 = requestOk(st, Vector3.new(30 + walk * 0.1, 0, 0), now, ctx)
	check("6 서버가 준 대시(30 stud) 직후 공격 = 통과(대시 허가)", ok5, ("거리 %.0f · 허용 %.1f"):format(d5, a5))
	local okEx = requestOk(st, Vector3.new(500, 0, 0), now, { rate = walk, exempt = true })
	local okGr = requestOk(st, Vector3.new(500, 0, 0), now, { rate = walk, grace = true })
	local okNo = requestOk(HG.newState(), Vector3.new(500, 0, 0), now, ctx)
	check("6 붙잡힘 예외 · 서버 순간이동 유예 · 기준 없음(첫 폴링 전) = 통과(폴링과 같은 계약)", okEx and okGr and okNo)
	local stFast = polled(now)
	local okLaunch = requestOk(stFast, Vector3.new(80, 0, 0), now, { rate = MG.permitSpeed })
	check("6 보스 발사 허가(초속 400) 중 80 stud = 통과", okLaunch)
	check("6 검사 함수 = 입구가 부르는 것(checkRequest)", HG.checkRequest ~= nil)
end)
if not okRun then print("[SECMOVE] 하네스 에러 " .. tostring(err)) end
print(("[SECMOVE] 끝 %d/%d"):format(pass, total))
