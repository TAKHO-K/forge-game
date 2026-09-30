-- 새 아이템 알림(QUEUE-ALL2 P2 ref 17 "가방 버튼 빨간 점 → 칸 빨간 점 → 한 번 보면 사라짐"). 클라 전용 · 이 세션만 기억한다(저장 구조 변경 없음 - 서버 프로필에 "새 것" 개념이 없다).
--   아이템에는 고유 id가 없어서 Loot.itemSignature(등급 · 부위 · 레벨 · 옵션 굴림 · 주운 스테이지)를 열쇠로 "알고 있는 개수"를 센다(가방 + 착용 합산 - 착용 · 해제로 칸을 옮겨도 새 것이 되지 않는다).
--   첫 스냅샷(접속 직후)은 전부 아는 것으로 시작한다. 그 뒤 서버 스냅샷(InventorySync)마다 update() - 아는 개수보다 많아진 열쇠의 몫만큼 가방 끝쪽(새로 주운 것이 붙는 자리) 칸에 표시를 단다.
--   본 것: 그 칸에 마우스를 올리거나(PC) 고르면 바로 · 가방 칸을 본 창을 닫으면(S.bagViewed) 나머지 전부.
--   LocalPlayer Attribute "InventoryNewCount" = 아직 안 본 새 아이템 수(hud/MenuBar의 가방 버튼 빨간 점이 읽는다 - 클라에서만 쓰는 값이라 복제되지 않아도 된다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loot = require(ReplicatedStorage.Shared.Loot)

local NewItems = {}
NewItems.attribute = "InventoryNewCount"

-- create(S) -> { update(), isNew(index), markSeen(index) -> 바뀌었나, markAllSeen(), count(), countFor(part | nil) }
--   onChanged(콜백 · 선택): 표시가 바뀔 때마다(탭 점 다시 칠하기)
function NewItems.create(S, onChanged)
	local player = Players.LocalPlayer
	local known -- 열쇠 -> 아는 개수. nil = 첫 스냅샷 전
	local createdAt = os.clock()
	local flags = {} -- 가방 index -> true
	local self = {}

	local function publish()
		player:SetAttribute(NewItems.attribute, self.count())
		if onChanged then
			onChanged()
		end
	end

	local function currentCounts()
		local counts = {}
		local function add(item)
			if type(item) == "table" then
				local key = Loot.itemSignature(item)
				counts[key] = (counts[key] or 0) + 1
			end
		end
		for _, item in ipairs(S.inventory) do
			add(item)
		end
		for _, item in pairs(S.equippedByPart()) do
			add(item)
		end
		return counts
	end

	-- 서버 스냅샷을 받은 뒤(S.inventory · 착용이 새 값일 때) 부른다. 점검이 가짜 가방을 넣고 다시 그릴 때는 부르지 않는다(아는 개수가 망가진다).
	function self.update()
		local current = currentCounts()
		flags = {}
		if not known then
			-- Play 3 수정: 접속 직후 빈 가방(서버 스냅샷 전 기본값)으로 기준을 잡으면 첫 실제 스냅샷이 전부 "새 것"(19)이 됐다 → 처음 10초 안의 빈 스냅샷은 기준으로 안 쓴다
			if #S.inventory == 0 and next(current) == nil and os.clock() - createdAt < 10 then
				return
			end
			known = current
			publish()
			return
		end
		for key, n in pairs(known) do
			local now = current[key] or 0
			if now < n then
				known[key] = now > 0 and now or nil -- 판매 · 분해로 줄었다 - 같은 모양을 다시 주우면 새 것이다
			end
		end
		local excess = {}
		for key, n in pairs(current) do
			local extra = n - (known[key] or 0)
			if extra > 0 then
				excess[key] = extra
			end
		end
		for index = #S.inventory, 1, -1 do
			local key = Loot.itemSignature(S.inventory[index])
			if (excess[key] or 0) > 0 then
				flags[index] = true
				excess[key] -= 1
			end
		end
		for key, extra in pairs(excess) do
			if extra > 0 then
				known[key] = (known[key] or 0) + extra -- 가방 밖(곧바로 착용)은 표시할 칸이 없다 - 아는 것으로 친다
			end
		end
		publish()
	end

	function self.isNew(index)
		return flags[index] == true
	end

	function self.markSeen(index)
		if not flags[index] then
			return false
		end
		flags[index] = nil
		local item = S.inventory[index]
		if item and known then
			local key = Loot.itemSignature(item)
			known[key] = (known[key] or 0) + 1
		end
		publish()
		return true
	end

	function self.markAllSeen()
		local any = false
		for index in pairs(flags) do
			local item = S.inventory[index]
			if item and known then
				local key = Loot.itemSignature(item)
				known[key] = (known[key] or 0) + 1
			end
			any = true
		end
		flags = {}
		if any then
			publish()
		end
	end

	function self.count()
		local n = 0
		for index in pairs(flags) do
			if S.inventory[index] then
				n += 1
			end
		end
		return n
	end

	-- 필터 탭 점: part = nil(전체) | 부위 id
	function self.countFor(part)
		local n = 0
		for index in pairs(flags) do
			local item = S.inventory[index]
			if item and (part == nil or (item.part or "armor") == part) then
				n += 1
			end
		end
		return n
	end

	return self
end

return NewItems
