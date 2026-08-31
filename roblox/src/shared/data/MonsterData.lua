-- 몬스터 데이터. 밸런스 수식(피해감소율·등급 배율·스킬 계수)은 넣지 않는다 - 자리만 만든다.
--
-- hp = 80은 검증용 잠정값이다(웹 스테이지1 값도, PRD 확정 곡선값도 아니다). 근거:
-- 원래 여기 있던 38,896은 PRD-forge-game-roblox.md 20.11-4의 무한 모드 HP(N=1) 값인데,
-- 그건 "무한 모드 진입 시점"(정상 모드 250+ 스테이지를 다 지난 시점) 기준이라 지금
-- Roblox에 있는 초기값 공격력 10(10-2부터 WeaponData.weapons.starter_sword.baseAttack,
-- 그전엔 CombatConfig.playerAttackPower - data/balance.js BALANCE.playerAttack과 같은 값)과
-- 짝지으면 안 되는 값이었다 - 두 값 다 각자 맥락에서는 맞지만
-- 서로 다른 진행도를 섞어 쓴 게 원인.
-- 웹 실제 스테이지1 몬스터(data/monsters.js)로 확인한 타수: BALANCE.playerAttack=10을
-- 클래스 배율 없이 그대로 쓰면 larva_soft(hp=40,def=0)=4대, larva_tank(hp=90,def=4)=15대로
-- 목표(5~10대) 어느 쪽도 정확히 안 맞는다. 실제 게임은 클래스 배율(0.6~2.0배)이 항상
-- 붙어서 대부분 5~9대 사이로 들어간다(예: 대검×물몸형=3대, 대검×탱커형=8대,
-- 활×탱커형=6대) - 이게 "5~10대" 체감의 실제 근거다. Roblox는 아직 클래스가 없어서
-- 같은 체감을 내는 hp=80(=8대, attack=10 그대로)을 잠정값으로 둔다.
local CombatConfig = require(script.Parent.CombatConfig)

return {
	tier1 = {
		id = "tier1",
		displayName = "잔챙이",
		hp = 80, -- 검증용 잠정값. 위 주석 참고 - 확정 곡선 아님.
		attack = 8, -- 반격 데미지 계산에 쓴다(CombatConfig.damageReductionAlpha 비율식).
		radiusPx = 12,

		-- 처치 골드(10-1). 웹 tier1 두 종(data/monsters.js larva_soft=4, larva_tank=8)의
		-- 평균 - 여긴 아직 soft/tank로 안 갈라서 hp=80 잠정값(위 주석)과 같은 이유로
		-- 대푯값 하나만 쓴다. 클래스 배율은 아직 없다(gold도 attack·hp처럼 배율 미적용).
		goldDrop = 6,

		-- 플레이어(16stud/s)보다 느려야 도망이 성립한다(9-4). 60% 속도로 잡아 쫓기긴 하되
		-- 꾸준히 거리를 벌리면 확실히 따돌릴 수 있게 했다.
		moveSpeedStuds = 10,

		-- 근접 사거리는 플레이어 평타와 같은 척도(둘 다 "붙어서 때리는" 근접전이라
		-- 별도 값을 새로 만들 이유가 없다).
		attackRangeStuds = CombatConfig.attackRangeStuds,

		-- 플레이어(0.28s)보다 느긋한 반격 속도.
		attackCooldownSeconds = 1.0,
	},
}
