-- QUEUE-UI UI-0 하네스(순수): 토큰 · 좌표 표 규칙 · 아이콘 표 · 화면 배율 · 직업 데이터 → 화면 모양 · 신직업 = 데이터 추가만으로 메뉴 · 카드 · 직업 선택에 나타남.
-- 실행: LUAU=<luau.exe> EXTRA_SERVER=SlotSave ECON_RES=res_uiv2.txt python build_run.py ui_v2_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[UIV2] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local T = MODS.UiTokens
	local L = MODS.UiLayoutData
	local I = MODS.UiIconData
	local M = MODS.UiModel

	-- 1. 토큰
	local badHex = 0
	for _, hex in pairs(T.colors) do
		if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then
			badHex += 1
		end
	end
	check("색 토큰 = 6자리 hex · 01 spec 21색 + 바탕 2", badHex == 0 and T.colors.accent == "FFC83D" and T.colors["accent.lip"] == "C9901A", tostring(badHex))
	local small = {}
	for name, t in pairs(T.text) do
		if t.phone < T.minPhoneText then
			table.insert(small, name)
		end
	end
	check("폰 글자 12 이상(토큰)", #small == 0, table.concat(small, ","))

	-- 2. 좌표 표: 모든 rect = 숫자 4개 · 기준 화면 안 · 폰 버튼 44 이상
	local bad, out, touch = {}, {}, {}
	local function walk(screenName, device, tbl, path)
		for k, v in pairs(tbl) do
			if type(v) == "table" and #v == 4 and type(v[1]) == "number" then
				local base = T.base[device]
				if v[1] < 0 or v[2] < 0 or v[1] + v[3] > base.w + 2 or v[2] + v[4] > base.h + 2 then
					local inside = path ~= "" -- 창 안 좌표(부모 기준)는 화면 경계 검사 제외
					if not inside then
						table.insert(out, screenName .. "." .. device .. "." .. k)
					end
				end
				if device == "phone" and (k:match("Close") or k:match("Back") or k:match("More") or k:match("Archive") or k:match("Start") or k:match("Cancel") or k:match("Ok")) and v[4] > 0 and math.min(v[3], v[4]) < T.minTouch then
					table.insert(touch, k)
				end
			elseif type(v) == "table" then
				walk(screenName, device, v, path .. k .. ".")
			elseif type(v) ~= "number" and type(v) ~= "boolean" then
				table.insert(bad, k)
			end
		end
	end
	for screenName, screen in pairs(L) do
		for _, device in ipairs({ "pc", "phone" }) do
			walk(screenName, device, screen[device], "")
		end
	end
	check("좌표 표 = 숫자만 · 화면 밖 0", #bad == 0 and #out == 0, table.concat(bad, ",") .. table.concat(out, ","))
	check("폰 버튼(닫기 · 돌아가기 · ⋯ · 보관함 · 시작 · 취소 · 확인) 44 이상", #touch == 0, table.concat(touch, ","))
	local pm = L.mainMenu.phone
	check("폰 메뉴 버튼 높이 44 이상 · 카드 줄 44 이상", pm.menu.items.h >= 44 and pm.menu.main.h >= 44 and pm.slotList.lockedH >= 44 and pm.slotList.emptyH >= 44 and pm.classList.h >= 44)
	check("왼쪽 위 로블록스 버튼 자리 비움(PC 132×60 · 폰 140×52) - 메뉴 · 제목이 안 겹침",
		L.mainMenu.pc.menu.x >= 132 - 36 and L.mainMenu.pc.title[2] >= 60 and pm.title[2] >= 52 and pm.slotWindow[2] >= 52)
	check("이어하기 창 오른쪽 끝 = PC 1012 · 폰 482(얼굴 · 대검 안 가림 - 01 spec)", L.mainMenu.pc.slotWindow[1] + L.mainMenu.pc.slotWindow[3] <= 1012 and pm.slotWindow[1] + pm.slotWindow[3] <= 482)

	-- 3. 아이콘 표
	local noFallback = {}
	for id, d in pairs(I.icons) do
		if not d.fallback or type(d.tint) ~= "boolean" or not d.file then
			table.insert(noFallback, id)
		end
	end
	check("아이콘 표: 모든 아이콘 = file · tint 스위치 · 임시 글자(그림 오기 전)", #noFallback == 0, table.concat(noFallback, ","))
	check("01 아이콘 9종 표에 있음", I.icons.close and I.icons.lock and I.icons.plus and I.icons.more and I.icons.archive and I.icons.back and I.icons.play and I.icons.info and I.icons.star and true or false)

	-- 4. 배율
	local b1, s1 = M.fit(1920, 1080, false)
	local b2, s2 = M.fit(800, 360, true)
	local _, s3 = M.fit(1052, 592, false)
	check("배율: PC 1920×1080 = 1 · 폰 800×360 = 1 · Studio 1052×592 = min", s1 == 1 and s2 == 1 and b1.w == 1920 and b2.w == 800 and math.abs(s3 - math.min(1052 / 1920, 592 / 1080)) < 1e-9)

	-- 5. 직업 데이터 → 화면 모양
	local list = M.classList()
	check("직업 목록 = ClassData.order 순서 · 이름 = displayName(하드코딩 아님)", #list == #MODS.ClassData.order and list[1].name == MODS.ClassData.classes[MODS.ClassData.order[1]].displayName)
	local gs = M.classInfo("greatsword")
	check("직업 정보: 스킬 Q · E · 궁극기 = SkillData · UltimateData · 성향 4줄", gs.skills.q ~= nil and gs.skills.e ~= nil and #gs.tendency == 4, ("%s/%s/%s"):format(tostring(gs.skills.q), tostring(gs.skills.e), tostring(gs.skills.ult)))
	check("무기 아이콘 키 = icons/weapons/<직업>_<등급>", M.weaponIconKey("bow", 3) == "icons/weapons/bow_legendary" and M.weaponIconKey(nil, 1) == nil and M.weaponIconKey("bow", nil) == "icons/weapons/bow_normal")
	check("조사: 검사 · 궁수 · 치유사 = 로 · 도적 = 으로 · 활 = 로", M.josaRo("검사") == "로" and M.josaRo("궁수") == "로" and M.josaRo("치유사") == "로" and M.josaRo("도적") == "으로" and M.josaRo("활") == "로")

	-- 6. 이어하기 줄: 마지막 플레이 맨 위 · 같은 직업만 ① ② · 빈 칸 · 잠긴 칸
	local rows = M.slotRows({ { classId = "bow", createdAt = 1, lastPlayedAt = 5 }, { classId = "greatsword", createdAt = 2, lastPlayedAt = 9 }, false, { classId = "bow", createdAt = 3, lastPlayedAt = 1 } }, 4, 1)
	check("줄: 마지막 플레이(검사) 맨 위 · 궁수 ① ② · 검사 번호 없음 · 빈 칸 1 · 잠긴 칸 1",
		rows[1].summary.classId == "greatsword" and rows[1].number == nil and rows[2].summary.classId == "bow" and rows[2].number == 1 and rows[3].number == 2 and rows[4].kind == "empty" and rows[5].kind == "locked" and #rows == 5)
	local zero = M.slotRows({ false, false, false, false }, 4, 1)
	check("캐릭터 0개 = 빈 칸 4 + 잠긴 칸 1", #zero == 5 and zero[1].kind == "empty" and zero[5].kind == "locked")

	-- 7. 신직업 = 데이터 추가만: ClassData · SkillData · UltimateData에 줄 추가 → 목록 · 칸 수 · 무기 아이콘 · 직업 선택 정보
	local CD = MODS.ClassData
	table.insert(CD.order, "lancer")
	CD.classes.lancer = { id = "lancer", displayName = "창술사", atk = 1, atkSpeed = 1, def = 1, rangeMultiplier = 1 }
	CD.cards.lancer = { role = "melee", difficulty = 2, tendency = { atk = 4, def = 3, move = 4, support = 2 } }
	MODS.SkillData.lancer = { Q = { name = "찌르기" }, E = { name = "도약" } }
	if MODS.UltimateData.skills then
		MODS.UltimateData.skills.lancer = { name = "천창" }
	end
	local list2 = M.classList()
	local last = list2[#list2]
	check("신직업: 직업 선택 목록 끝에 나타남 · 이름 · 스킬 · 성향 = 데이터", #list2 == #list + 1 and last.id == "lancer" and last.name == "창술사" and last.skills.q == "찌르기" and last.tendency[1].value == 4)
	check("신직업: 그림 없음 = 임시 실루엣(temp)", last.temp == true)
	check("신직업: 칸 수 +1(SlotSave.slotCount = 출시 직업 수)", MODS.SlotSave.slotCount() == #list + 1, tostring(MODS.SlotSave.slotCount()))
	local rowsNew = M.slotRows({ { classId = "lancer", createdAt = 1, lastPlayedAt = 1 } }, MODS.SlotSave.slotCount(), 1)
	check("신직업: 이어하기 카드 · 빈 칸 수 = 칸 수 − 1", rowsNew[1].summary.classId == "lancer" and #rowsNew == MODS.SlotSave.slotCount() + 1)
	check("신직업: 무기 아이콘 키 = 데이터 규칙", M.weaponIconKey("lancer", 0) == "icons/weapons/lancer_normal")
end)
if not okRun then
	print("[UIV2] 하네스 에러 " .. tostring(err))
end
print(("[UIV2] 끝 %d/%d"):format(pass, total))
