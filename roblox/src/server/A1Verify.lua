-- A1 자동 검증(나): CartoonStyle.apply 멱등 · base → cartoon → base 뒤 관리 속성 = base 프로필 · 관리 밖 속성 변화 0 · 서버에 몬스터별 Highlight 없음.
-- 외곽선 풀 슬롯 상한(클라)은 수동 Play로 잰다(docs/phase/A1-report.md). 끝나면 부팅 프로필(CartoonStyleData.active)로 되돌린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local CartoonStyle = require(ReplicatedStorage.Shared.CartoonStyle)
local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)

local V = {}

function V.runLive()
	print("===A1 검증 시작(나)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[A1][나] %s %s"):format(label, ok and "O" or "X"))
	end
	local ok, err = pcall(function()
		CartoonStyle.apply("base")
		local baseManaged = CartoonStyle.snapshotManaged()
		local un0 = CartoonStyle.snapshotUnmanaged()
		check(("부팅 = base 프로필(기대 차이 %d)"):format(#CartoonStyle.diff(baseManaged, CartoonStyle.expected("base"))), #CartoonStyle.diff(baseManaged, CartoonStyle.expected("base")) == 0)
		local t0 = os.clock()
		CartoonStyle.apply("cartoon")
		local ms = (os.clock() - t0) * 1000
		local c1 = CartoonStyle.snapshotManaged()
		CartoonStyle.apply("cartoon")
		local c2 = CartoonStyle.snapshotManaged()
		check(("cartoon 두 번 적용 차이 %d(멱등) · 기대 차이 %d · 적용 %.0fms"):format(#CartoonStyle.diff(c1, c2), #CartoonStyle.diff(c1, CartoonStyle.expected("cartoon")), ms),
			#CartoonStyle.diff(c1, c2) == 0 and #CartoonStyle.diff(c1, CartoonStyle.expected("cartoon")) == 0)
		local unDuring = CartoonStyle.diff(un0, CartoonStyle.snapshotUnmanaged())
		check(("cartoon 중 관리 밖 속성 변화 %d [%s]"):format(#unDuring, table.concat(unDuring, ",")), #unDuring == 0)
		CartoonStyle.apply("base")
		local b = CartoonStyle.snapshotManaged()
		local unAfter = CartoonStyle.diff(un0, CartoonStyle.snapshotUnmanaged())
		check(("base 복귀: base 기대 차이 %d · 관리 밖 변화 %d"):format(#CartoonStyle.diff(b, CartoonStyle.expected("base")), #unAfter), #CartoonStyle.diff(b, CartoonStyle.expected("base")) == 0 and #unAfter == 0)
		local perMob = 0
		for _, model in ipairs(CollectionService:GetTagged("Monster")) do
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("Highlight") and d.Name == "AimHighlight" then
					perMob += 1
				end
			end
		end
		check(("몬스터마다 붙은 꺼진 AimHighlight %d(기대 0 - 외곽선 풀로 통합)"):format(perMob), perMob == 0)
	end)
	if not ok then
		check("실행 중 에러: " .. tostring(err), false)
	end
	CartoonStyle.apply(CartoonStyleData.active)
	print(("===A1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
