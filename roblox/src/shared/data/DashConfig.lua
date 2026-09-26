-- 대시(21-2 [2]). 21-1이 확인한 대로 로블록스판엔 대시가 어느 플랫폼에도 없었다 - HUD의
-- SHIFT 슬롯은 18-2 목업의 데모 쿨다운만 도는 장식이었다(PRD 20.42 항목 11). 명세는 웹
-- PRD-forge-game.md 5.4를 그대로 따른다: 이동 거리 "캐릭터 4칸", 0.3초, 쿨다운 8초(남발 방지),
-- 대시 중 받는 피해 50% 감소(완전 무적이 아니다 - "일단 대시하고 보자"와 "제대로 피하자"
-- 사이의 고민을 남기려는 의도). 키만 다르다 - 웹은 스페이스바지만 로블록스에서 Space는
-- 점프(19-2 점프 버퍼가 이미 그 전제)라 PC는 LeftShift, 모바일은 HUD 대시 버튼이다.
return {
	-- 캐릭터 폭 약 4stud × 4칸 = 16stud(옛 값 - 21-2). 웹 160px을 pxPerStud로 기계 환산한 게 아니라 "캐릭터 4칸"이라는 명세를 stud로 다시 읽은 값이었다.
	-- MV1(사용자 지시 - 기본 대시 거리 +30 ~ 50%): 16 → 22(+37.5%). 옛 원칙 "회피기가 대검 관통돌진(18)보다 멀리 가면 안 된다"는 깨진다(결정 요청 - MV1 보고서).
	-- 못 넘는 틈 · 둥지 · 점프맵 기준 = docs/design/movement-metrics.md v3(JumpMath.unjumpableGapStuds가 이 값을 읽는다).
	rangeStuds = 22,
	-- MV1: 이동 속도 비례 - 대시 거리 = rangeStuds × clamp(장비 걷기 배율(JumpMath.moveSpeedMultiplier - 신발 + 신속 합), 1, speedScaleMax).
	--   하한 1 = 감속(회전베기 등 PlayerState 배율)은 대시를 줄이지 않는다(회피기). 상한 ×1.4 = 이속 상한 ×1.5(24 stud/s)에서도 30.8stud.
	speedScaleMax = 1.4,
	-- MV1 태초 신발 = 2단 대시(D1-2의 거리 상한 ×1.125 = 18stud는 폐기 - 이동 속도 비례가 대신한다): 연속 charges회 · 첫 대시 뒤 chainWindowSeconds 안에 두 번째(지상 · 공중) ·
	--   쿨다운은 두 번째를 쓴 순간부터(창을 놓치면 첫 대시 때 시작한 쿨다운 그대로). 공중에서도 한 체공에 charges회.
	primordialShoes = { charges = 2, chainWindowSeconds = 1.5 },
	-- MV1 입력: 누른 채 glideHoldSeconds가 지나면(공중에서만) 활강 · 그 전에 떼면 대시(지상은 누르는 즉시 대시 - 지상 길게 누름 = 일반 대시). 폰 대시 버튼도 같은 판정.
	--   지시의 "짧게 약 0.2초 미만 / 길게 약 0.25초 이상"은 경계 하나(0.25)로 읽었다 - 그 사이(0.2 ~ 0.25)에 뗀 것도 대시(입력이 사라지지 않게).
	input = { glideHoldSeconds = 0.25 },
	durationSeconds = 0.3, -- PRD 5.4 그대로. MV1: 22stud/0.3초 ≈ 73stud/s(이속 상한 30.8stud ≈ 103stud/s).
	cooldownSeconds = 8, -- PRD 5.4 그대로.
	incomingDamageMultiplier = 0.5, -- PRD 5.4 "대시 중 피격 데미지 50% 감소".
}
