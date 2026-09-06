-- 무한 모드 스테이지 성장률(11-1). PRD-forge-game-roblox.md 20.9/20.11-4가 확정한
-- k=1.155를 그대로 쓴다 - HP(N)=base×k^(N-1), monsterAttack(N)=base×k^(N-1), 20.9의
-- reward(N)=R0×k^(N-1)까지 전부 같은 k 하나를 재사용하는 게 PRD의 설계 의도다(몬스터가
-- 세지는 속도라는 하나의 축으로 남겨야 한다는 20.11-4 근거를 골드에도 그대로 적용).
--
-- base 값(PRD의 스테이지1 보스체력 38,896·공격력 8)은 여기 그대로 옮기지 않는다 - 그 값은
-- 웹판 레벨·아이템 시스템(무기 Lv25+, 아이템 등급)까지 다 갖춘 시점 기준이고, 로블록스는
-- 아직 그런 시스템이 없다(ClassData.lua critRate 주석과 같은 "출처가 다른 두 값을 뭉뚱그리지
-- 않는다" 원칙). 대신 base는 MonsterData.tier1의 현재 검증된 값(hp=80, attack=8,
-- goldDrop=6)을 스테이지1로 그대로 쓰고, growthRate(k)만 PRD에서 가져온다 - 공격력은
-- 우연히 PRD의 base=8과 이미 일치한다.

return {
	growthRate = 1.155,
}
