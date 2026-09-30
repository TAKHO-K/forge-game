local SandShell = {}

-- A2-N4 §2-7 전갈 여왕 "진짜 전갈 찾기" 야바위 이동(순수 - 위치 · 시각만 바꾼다 · 서버 BossSandSearch와 검증 A2-N4(가)가 같은 함수를 부른다). mounds[i] = { position, model? } · sand = { center, realIndex, shell? }.
--   한 판 = 멈춤(holdSeconds) → 둔덕 순서를 한 칸 돌린 자리로 동시에 출발(burstSpeed) → 다 닿으면 다시 멈춤. 진짜가 가짜와 overlapStuds 안에 maxOverlapSeconds 넘게 있으면 그 가짜를 비켜 세운다.
function SandShell.step(sand, spec, mounds, now, dt, rng)
	local S = spec.shell
	local shell = sand.shell
	if not shell then
		shell = { phase = "hold", untilAt = now + rng:NextNumber(S.holdSeconds[1], S.holdSeconds[2]), overlapSince = {} }
		sand.shell = shell
	end
	if shell.phase == "hold" then
		if now >= shell.untilAt and #mounds >= 2 then
			-- 자리 바꾸기: 무작위 순열(고정점 없이 - 모두 움직인다) · 목표는 지금 자리(반경 안)
			local order = {}
			for i = 1, #mounds do
				order[i] = i
			end
			for i = #order, 2, -1 do
				local j = rng:NextInteger(1, i - 1) -- Sattolo(한 바퀴 순환 = 고정점 없음)
				order[i], order[j] = order[j], order[i]
			end
			local speed = rng:NextNumber(S.burstSpeed[1], S.burstSpeed[2])
			for i, m in ipairs(mounds) do
				m.target = mounds[order[i]].position
				m.speed = speed
			end
			shell.phase = "move"
		end
	else
		local moving = false
		for _, m in ipairs(mounds) do
			if m.target then
				local to = Vector3.new(m.target.X - m.position.X, 0, m.target.Z - m.position.Z)
				local step = m.speed * dt
				if to.Magnitude <= step then
					m.position = Vector3.new(m.target.X, m.position.Y, m.target.Z)
					m.target = nil
				else
					m.position += to.Unit * step
					moving = true
				end
			end
		end
		if not moving then
			shell.phase = "hold"
			shell.untilAt = now + rng:NextNumber(S.holdSeconds[1], S.holdSeconds[2])
		end
	end
	-- 추적 보장: 진짜와 겹친 가짜
	local real = mounds[sand.realIndex]
	if real then
		for i, m in ipairs(mounds) do
			if i ~= sand.realIndex then
				local d = Vector3.new(m.position.X - real.position.X, 0, m.position.Z - real.position.Z)
				if d.Magnitude < S.overlapStuds then
					shell.overlapSince[i] = shell.overlapSince[i] or now
					if now - shell.overlapSince[i] >= S.maxOverlapSeconds - 0.1 then
						local away = d.Magnitude > 1e-3 and d.Unit or Vector3.new(1, 0, 0)
						m.position = real.position + away * S.pushStuds
						local fromCenter = Vector3.new(m.position.X - sand.center.X, 0, m.position.Z - sand.center.Z)
						if fromCenter.Magnitude > spec.wanderRadiusStuds then -- 떠돌기 반경 안으로(반대쪽으로 비킨다)
							m.position = real.position - away * S.pushStuds
						end
						m.target = m.target and (m.target + away * S.pushStuds) or nil
						shell.overlapSince[i] = nil
					end
				else
					shell.overlapSince[i] = nil
				end
			end
		end
	end
end

return SandShell
