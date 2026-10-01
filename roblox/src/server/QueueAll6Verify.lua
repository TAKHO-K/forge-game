-- QUEUE-ALL6 자동 검증(나) - docs/phase/QUEUE-ALL6-report.md. 블록 id "ALL6(나)"(VerifyOnly로 단독 실행 - 무거운 블록과 같은 Play 금지).
--   B2: 체크포인트 강제 발견 → 전투 중 요청 = 거절(combat) · 정신 집중 중 피격 = 취소(hit) · 거절 · 취소는 체크포인트 쿨을 쓰지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local QueueAll6Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[ALL6][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end
QueueAll6Verify.newRecorder = newRecorder

-- B2: 체크포인트 거절 · 취소 · 쿨 미소모
local function checkpointSection(r, player)
	local Travel = require(script.Parent.Travel)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local CP = WorldMapData.checkpoints
	local rec = PlayerProfile.getCheckpoints(player)
	local oldFound = table.clone(rec.found)
	local oldAttr = workspace:GetAttribute(CP.attribute)
	workspace:SetAttribute(CP.attribute, true)
	-- 개발 명령 /gg cp all과 같은 일(강제 발견)
	table.clear(rec.found)
	local target
	for _, cp in ipairs(CP.list) do
		table.insert(rec.found, cp.id)
		if cp.hub then
			target = target or cp.id -- 허브 체크포인트(구역 잠금과 무관)
		end
	end
	target = target or CP.list[1].id
	Travel.onCheckpointsLoaded(player)
	local hp0 = PlayerState.getHp(player)
	PlayerState.setIncomingDamageMultiplierUntil(player, 1, 60, "all6cp") -- 다른 출처의 피해 배율(god 등)이 남아 있어도 이 시험 동안 실제 피해
	-- ① 전투 중(방금 피격) 요청 = 거절
	PlayerDamage.takeDamage(player, math.max(1, (PlayerState.getMaxHp(player) or 100) * 0.05), {})
	task.wait(0.6) -- Travel 0.25초 순회가 피격(hurtAt)을 기록
	local ok1, why1 = Travel.requestCheckpoint(player, target)
	r.check(("① 전투 중 체크포인트 요청: %s(%s) · 기대 false · combat"):format(tostring(ok1), tostring(why1)), ok1 == false and why1 == "combat")
	-- ② 전투가 끝난 뒤(가상 시각 +9초 = combatLockSeconds 8 밖) = 정신 집중 시작
	local future = os.clock() + WorldMapData.travel.combatLockSeconds + 1
	local ok2, why2 = Travel.requestCheckpoint(player, target, future)
	r.check(("② 전투 뒤 요청 = 정신 집중: %s(%s)"):format(tostring(ok2), tostring(why2)), ok2 == true and why2 == "casting")
	-- ③ 정신 집중 중 피격 = 취소(hit) · 순간이동 없음
	PlayerDamage.takeDamage(player, math.max(1, (PlayerState.getMaxHp(player) or 100) * 0.05), {})
	local result = Travel.pollRecall(player, future + 0.5)
	task.wait(0.3)
	r.check(("③ 집중 중 피격 = 취소: poll %s · 시전 중 %s(기대 hit · false)"):format(tostring(result), tostring(player:GetAttribute("RecallCastUntil") ~= nil)),
		(result == "hit" or result == nil) and player:GetAttribute("RecallCastUntil") == nil and player:GetAttribute("RecallCastUntil") == nil)
	-- ④ 거절 · 취소는 쿨을 안 쓴다: 다시 요청(전투 밖 가상 시각) = 쿨이 아니라 정신 집중
	local ok4, why4 = Travel.requestCheckpoint(player, target, os.clock() + WorldMapData.travel.combatLockSeconds + 2)
	r.check(("④ 거절 · 취소 뒤 다시 요청 = %s(%s) · 기대 casting(cooldown 아님)"):format(tostring(ok4), tostring(why4)), ok4 == true and why4 == "casting")
	Travel.cancelRecall(player, "key")
	-- 되돌리기
	PlayerState.clearIncomingDamageMultiplierSource(player, "all6cp")
	if hp0 then
		PlayerState.setHp(player, hp0)
	end
	table.clear(rec.found)
	for _, id in ipairs(oldFound) do
		table.insert(rec.found, id)
	end
	Travel.onCheckpointsLoaded(player)
	workspace:SetAttribute(CP.attribute, oldAttr)
	r.check(("되돌림: 찾은 체크포인트 %d개(원래 %d) · 시전 없음"):format(#rec.found, #oldFound), #rec.found == #oldFound and player:GetAttribute("RecallCastUntil") == nil)
end

function QueueAll6Verify.runLive(player, env)
	print("===ALL6 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	r.section("B2 체크포인트", function()
		checkpointSection(r, player)
	end)
	for _, extra in ipairs(QueueAll6Verify.extraSections) do
		r.section(extra.name, function()
			extra.fn(r, player, env)
		end)
	end
	env.restore(player)
	local pass, total = r.summary()
	print(("===ALL6 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

-- 다른 항목(F · G 등)이 붙이는 절(같은 Play · 같은 블록) - { name, fn(r, player, env) }
QueueAll6Verify.extraSections = {}

return QueueAll6Verify
