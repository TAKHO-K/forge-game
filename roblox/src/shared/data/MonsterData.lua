-- 몬스터 데이터. 밸런스 수식(피해감소율·등급 배율·스킬 계수)은 넣지 않는다 - 자리만 만든다.
-- hp·attack 출처: PRD-forge-game-roblox.md 20.11-4, 무한 모드 N=1 대입값
-- (HP(N)=38,896×1.155^(N-1), monsterAttack(N)=8×1.155^(N-1)).
-- radiusPx 출처: 웹 data/monsters.js의 larva_soft(1등급, 물몸형).

return {
	tier1 = {
		id = "tier1",
		displayName = "잔챙이",
		hp = 38896,
		attack = 8, -- 이번 세션은 전투가 없어 쓰이지 않는다. 자리만 만든다.
		radiusPx = 12,
	},
}
