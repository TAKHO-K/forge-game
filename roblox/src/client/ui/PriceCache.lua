-- QUEUE-ALL9C 1-6(K1) 사용자별 지역 가격: 개발자 상품 = MarketplaceService:GetDeveloperProductsAsync(한 번에 목록 - 처음 쓸 때 1회) · 게임패스 = GetProductInfoAsync(InfoType.GamePass - 하나씩).
--   가격이 없거나(0 · 실패 · id 0) 아직 안 왔으면 데이터 값(MonetizationData robux - 호출부가 fallback으로 넘김). 캐시 = 이 접속 동안 · 요청 = 하나씩 MIN_GAP초 간격(요청 제한) · 실패 = RETRY_SECONDS 뒤 다시.
--   값이 들어오면 changed:Fire() - 상점이 다시 그린다.
local MarketplaceService = game:GetService("MarketplaceService")

local PriceCache = {}
PriceCache.changed = Instance.new("BindableEvent")

local MIN_GAP = 0.35
local RETRY_SECONDS = 60
local cache = {} -- [key] = 가격(number) | false(요청 중 · 실패)
local failedAt = {}
local queue, pumping = {}, false
local productsListed = false

local function pump()
	if pumping then
		return
	end
	pumping = true
	task.spawn(function()
		while #queue > 0 do
			local job = table.remove(queue, 1)
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(job.id, job.kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
			end)
			local price = ok and type(info) == "table" and tonumber(info.PriceInRobux)
			if price and price > 0 then
				cache[job.key] = price
				PriceCache.changed:Fire()
			else
				failedAt[job.key] = os.clock()
			end
			task.wait(MIN_GAP)
		end
		pumping = false
	end)
end

-- 개발자 상품 목록 한 번(지역 가격 포함) - 목록에 없는 상품만 하나씩 묻는다
local function listProducts()
	if productsListed then
		return
	end
	productsListed = true
	task.spawn(function()
		local ok = pcall(function()
			local pages = MarketplaceService:GetDeveloperProductsAsync()
			while true do
				for _, item in ipairs(pages:GetCurrentPage()) do
					local id, price = tonumber(item.ProductId), tonumber(item.PriceInRobux)
					if id and price and price > 0 then
						cache["product:" .. id] = price
					end
				end
				if pages.IsFinished then
					break
				end
				pages:AdvanceToNextPageAsync()
			end
		end)
		if ok then
			PriceCache.changed:Fire()
		end
	end)
end

-- kind = "product" | "pass" · id = Creator Hub 번호(0 = 아직 없음) · fallback = 데이터 가격. 반환 = 지금 보일 가격.
function PriceCache.get(kind, id, fallback)
	if type(id) ~= "number" or id == 0 then
		return fallback
	end
	local key = kind .. ":" .. id
	local value = cache[key]
	if type(value) == "number" then
		return value
	end
	if kind == "product" then
		listProducts()
	end
	if value == nil or (failedAt[key] and os.clock() - failedAt[key] > RETRY_SECONDS) then
		cache[key] = false
		failedAt[key] = nil
		table.insert(queue, { kind = kind, id = id, key = key })
		pump()
	end
	return fallback
end

return PriceCache
