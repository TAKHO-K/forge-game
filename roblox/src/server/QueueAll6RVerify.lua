-- QUEUE-ALL6R 자동 검증(나) - docs/phase/QUEUE-ALL6R-report.md. 블록 id "ALL6R(나)"(VerifyOnly).
--   3: 서버가 지은 월드 글자(TextKey · TextName 속성) 전부를 en으로 조합 → 한글이 남는 것 0(사전 · 키 빠짐을 여기서 잡는다) · 도감 알림 키 3종 en 있음.
--   2-8: 영구 차단 · 초월 회수 = 미리보기 + 확인 번호(실행 안 함) · 없는 번호 = 실행 안 함 · 내보내기 메시지(OpsKick_v1_verify)를 이 서버가 받는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")

local QueueAll6RVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[ALL6R][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function hasHangul(s)
	return type(s) == "string" and s:find("[\234-\237][\128-\191][\128-\191]") ~= nil
end

local function worldTextSection(r)
	local Text = require(ReplicatedStorage.Shared.Text)
	local seen, missing, count, keys, names = {}, {}, 0, 0, 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("TextLabel") and (d:GetAttribute("TextKey") or d:GetAttribute("TextName")) then
			count += 1
			local key = d:GetAttribute("TextKey")
			local id
			local en
			if key then
				keys += 1
				local args = {}
				for attr, value in pairs(d:GetAttributes()) do
					local name = attr:match("^TextArg_(.+)$")
					if name then
						args[name] = value
					end
				end
				en = Text.format("en", key, args)
				id = key .. "|" .. en
			else
				names += 1
				en = Text.nameIn("en", d:GetAttribute("TextName"))
				id = "name|" .. tostring(d:GetAttribute("TextName"))
			end
			if not seen[id] then
				seen[id] = true
				if hasHangul(en) then
					table.insert(missing, en)
				end
			end
		end
	end
	table.sort(missing)
	r.check(("월드 글자 %d개(키 %d · 이름 %d) en 조합 → 한글 남음 %d종%s"):format(count, keys, names, #missing, #missing > 0 and (": " .. table.concat(missing, " / ", 1, math.min(#missing, 40))) or ""), count > 0 and #missing == 0)
	local codex = {}
	for _, key in ipairs({ "srv.codex.lineDone", "srv.codex.got", "srv.codex.eggFull", "srv.mob.prefixed", "srv.drop.plate", "srv.world.sealedPlaque" }) do
		local en = Text.format("en", key, { title = "도감 수집가", summary = "Gold 500", grade = "전설", part = "갑옷", level = "12", prefix = "단단한", name = "이끼 슬라임" })
		if hasHangul(en) or en == key then
			table.insert(codex, key .. "=" .. en)
		end
	end
	r.check(("도감 알림 · 합성 키 6종 en(인자 사전 번역 포함) - 한글 남음 %d%s"):format(#codex, #codex > 0 and (": " .. table.concat(codex, " / ")) or ""), #codex == 0)
end

local function opsSection(r, player)
	local hook = game:GetService("ServerStorage"):FindFirstChild("OpsHook")
	assert(hook, "OpsHook 없음(Studio 전용)")
	if not table.find(require(script.Parent.OpsConfig).userIds, player.UserId) then
		r.check("운영 허용 계정 아님 - 운영 절 건너뜀", true)
		return
	end
	local uid = tostring(player.UserId)
	local preview = hook:Invoke(player, "/ops ban " .. uid .. " perm 검증 미리보기")
	r.check(("영구 차단 = 미리보기만(실행 안 함): %s"):format(tostring(preview):sub(1, 90)), type(preview) == "string" and preview:find("/ops ban confirm", 1, true) ~= nil and player.Parent ~= nil)
	local noBan = hook:Invoke(player, "/ops ban confirm 000000")
	r.check(("없는 확인 번호 = 차단 안 함: %s"):format(tostring(noBan)), tostring(noBan):find("no_pending", 1, true) ~= nil)
	local noItem = hook:Invoke(player, "/ops revoke " .. uid .. " t999999")
	r.check(("초월 회수 - 없는 번호 = 확인 번호도 안 냄: %s"):format(tostring(noItem)), noItem == "no_item")
	local noRevoke = hook:Invoke(player, "/ops revoke confirm 000000")
	r.check(("초월 회수 없는 확인 번호 = 실행 안 함: %s"):format(tostring(noRevoke)), tostring(noRevoke):find("no_pending", 1, true) ~= nil)
	-- 내보내기 메시지: 이 서버도 같은 토픽을 듣는다(없는 사람 = 내보내기 0) - 로그 줄로 수신 확인
	local cfg = require(ReplicatedStorage.Shared.data.SecurityOpsConfig).rollback
	local topic = cfg.kickTopic .. (require(ReplicatedStorage.Shared.data.DevToolsConfig).verifyArmed and "_verify" or "")
	local got = false
	local conn = LogService.MessageOut:Connect(function(message)
		if message:find("운영 내보내기 요청 받음: userId 1 ", 1, true) then
			got = true
		end
	end)
	local okPub, err = pcall(function()
		game:GetService("MessagingService"):PublishAsync(topic, { userId = 1 })
	end)
	local t0 = os.clock()
	while not got and os.clock() - t0 < 8 do
		task.wait(0.25)
	end
	conn:Disconnect()
	r.check(("내보내기 메시지 %s 발행 %s · 이 서버 수신 %s(%.1f초) · 대상 없음 = 아무도 안 나감"):format(topic, okPub and "O" or tostring(err), tostring(got), os.clock() - t0), okPub and got and player.Parent ~= nil)
end

function QueueAll6RVerify.runLive(player, env)
	print("===ALL6R 검증 시작(나)===")
	local r = newRecorder("나")
	r.section("3 월드 글자", function()
		worldTextSection(r)
	end)
	r.section("2-8 운영 확인 번호 · 내보내기", function()
		opsSection(r, player)
	end)
	local pass, total = r.summary()
	print(("===ALL6R 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return QueueAll6RVerify
