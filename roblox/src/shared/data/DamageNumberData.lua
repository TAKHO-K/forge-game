-- W2-3 몬스터 피해 숫자 준비(표시는 나중 - 최종 스타일은 U1). 구조만: 서버가 확정한 피해만 보낸다(클라 예측 숫자 금지).
--   이벤트(DamageFeed) = { target(몬스터 모델) · hitPosition(서버 적중 지점) · amount(확정 피해) · kind · attackerUserId } - 서버 server/DamageFeed.
--   kind = "normal" | "crit" | "heavy"(3타 강공격) | "skill". 치명 + 강공격이면 heavy 우선(강공격은 궤적 · 히트스톱이 이미 알린다 - 숫자는 치명 색을 겹친다: crit = true 칸).
--   표시(client/DamageFeedView - 프로토타입 · 플래그 꺼짐): 같은 대상 mergeSeconds 안 피해 합치기 · 동시 상한 · 풀링 · 남이 준 피해는 작게 또는 끄기.
local D = {}

D.enabled = false -- 프로토타입 플래그(서버 방송 + 클라 표시 둘 다). 켜는 시점 = U1(옛 DamageNumbers는 그대로 둔다 - 켜면 옛 것은 끈다)
-- QUEUE-ALL2 P4 ④(09 B-2 보스 "누가 언제 때렸는지"): 보스 대상만 방송 · 클라는 남의 피해만 그린다(내 피해 = 옛 DamageNumbers 크고 밝게) · 남 = 작고 옅게 + 파티원 색(PartyColors) + 작은 적중 불꽃
D.bossFeed = true

D.sendStuds = 120 -- 대상에서 이 거리 안의 사람에게만(대역폭 - PrimordialGlovesBolt와 같은 원칙)
D.mergeSeconds = 0.1 -- 같은 대상 · 같은 공격자에게 이 시간 안에 들어온 피해는 한 숫자로 합친다
D.maxShown = 24 -- 동시에 떠 있는 숫자 상한(넘으면 가장 오래된 것을 재사용)
D.lifeSeconds = 0.8 -- 떠오르며 사라지는 시간
D.riseStuds = 2.5
D.others = { mode = "small", scale = 0.6, transparency = 0.35 } -- mode = "small"(작게) | "off"(끄기) | "full"
D.minePx = 26 -- 내 피해 글씨 크기(px - 최종 스타일 U1)

-- 표시 시각 규칙(지연 감안)은 제안 단계 - docs/phase/W2-report.md W2-3(U1에서 확정 후 여기에 수치로).

return D
