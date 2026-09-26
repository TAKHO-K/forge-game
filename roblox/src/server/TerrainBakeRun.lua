-- M1-3 Studio edit 모드 굽기 실행기. edit 모드의 require는 한 번 불러온 모듈을 Studio를 닫을 때까지 캐시한다(Rojo가 소스를 바꿔도 옛 코드가 돈다 - M1-3 실측).
-- 그래서 부를 때마다 TerrainBake와 그 의존 모듈(ReplicatedStorage.Shared …)을 소스에서 새로 불러온다(loadstring - edit 명령줄 · MCP 플러그인 권한에서만 된다).
-- 사용(명령줄): require(game.ServerScriptService.TerrainBakeRun)("tier1")  -- 또는 "hub" · "all" · { "check" }
--   → 굽기 결과 표 · 끝나면 place 저장(파일 → 저장 / 게시). Play 중에는 쓰지 않는다(/gg terrain build = 일반 require).
return function(key, opts)
	local cache = {}
	local function load(ms)
		if cache[ms] ~= nil then
			return cache[ms]
		end
		local fn = assert(loadstring(ms.Source, "=" .. ms:GetFullName()))
		local env = setmetatable({
			script = ms,
			require = function(m)
				if typeof(m) == "Instance" and m:IsA("ModuleScript") then
					return load(m)
				end
				return require(m)
			end,
		}, { __index = getfenv(1) })
		setfenv(fn, env)
		local result = fn()
		cache[ms] = result
		return result
	end
	local TerrainBake = load(script.Parent.TerrainBake)
	if key == "all" then
		return TerrainBake.buildAll(opts)
	elseif key == "check" then
		local WorldStructures = load(game:GetService("ReplicatedStorage").Shared.WorldStructures)
		local bad, checked = TerrainBake.capsuleCheck(WorldStructures.nestList())
		return { capsuleChecked = checked, capsuleBlocked = bad, version = TerrainBake.checkVersion() }
	elseif key == "clear" then
		return TerrainBake.clear()
	end
	return TerrainBake.build(key, opts)
end
