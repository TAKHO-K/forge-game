# 모션 기준 (W3a · W3b 확정 - K의 R · T 스킬도 이 기준을 따른다)

> 데이터 = `roblox/src/shared/data/PlayerMotionData.lua` · 재생 = `client/WeaponVisual.lua`(+ `client/PoseRig.lua`) · 시각 = `shared/MotionTiming.lua`. 애니메이션 에셋 업로드 없음(코드 모션 - C3 결정 9).

## 1. 여섯 가지 원칙

| 원칙 | 뜻 | 데이터에서 |
|---|---|---|
| 힘의 사슬 | 발 → 허리 → 어깨 → 팔 → 무기. 팔만 휘두르지 않는다 | 모든 키 포즈에 `body(dy, stride, yaw, lean)`(무릎 · 체중 · 온몸 돌림 · 숙임) + `Waist` 비틀기 |
| 무게 | 무거운 무기일수록 준비가 크고 따라 휘두름이 길다 | 대검 act 0.17 ~ 0.22 · rec 0.23 ~ 0.36 / 쌍검 act 0.12 · 지팡이 act 0.06 |
| 손 | 양손 무기는 양손(보조 손 IK) · 빈손은 의미 있는 자세(시전 손 · 균형 · 땅 짚기) | `ik = "support"` · 지팡이 왼손 = 시전 손바닥 |
| 손목만 금지 | 무기 각 θ = 어깨 x + 팔꿈치 x + 손목 x - 손목 혼자 45° 넘게 바꾸지 않는다 | 키 사이 어깨 · 허리가 같이 움직인다 |
| 세 구간 | 전조(ant) → 동작(act) → 회복(rec) · 키 포즈 4개(cocked · contact · through · settle) · 앞 동작의 회복 = 다음 동작의 준비 | 선형 보간 금지: ant = inQuad · act = outCubic · rec = inOutSine |
| 판정 불변 | 판정 시각 · 값은 절대 안 바꾼다. 모션이 판정에 맞춘다 | 근접 타격 = 1프레임 · 원거리 = 서버 발사 상수 · 대시 스킬 = 시전 순간 · 채널 = 서버 틱 시계 |

적중 순간 짧은 히트스톱(평타 0.05 · 3타 0.08 · 스킬 0.12초). 채널 스킬은 포즈만 멈추고 시계는 그대로(틱 시각이 밀리지 않게).

## 2. 스킬 하나를 만드는 법 (R · T 포함)

1. **판정 유형부터 본다**(SkillServer): 즉시(대시 · 버프 · 소환 · 토글) → 한 번 동작 / 채널(틱) → `channel` 표.
2. `PlayerMotionData.skills[직업][슬롯]`에 넣는다(새 함수 금지 - 데이터만):
   - 한 번 동작: `{ ant, act, rec, cocked, contact, through, settle, trail = 리본 여부, draw = 활 당김 {0,1,1,0}, ik = false면 IK 끔 }`
   - 대시형: 전조를 짧게(0.03 ~ 0.06) · act = 서버 대시 시간(SkillData `durationSeconds`) 동안 찌른/뛴 자세로 미끄러짐
   - 채널형: `channel = { spinDeg = 틱당 온몸 회전(음수 = 오른쪽), wobbleDeg = 틱 순간 가속 }` 또는 `{ alternate = { 포즈 A, 포즈 B } }`(틱마다 한 번) - 길이 · 틱 간격은 SkillData에서 읽는다(복사 금지)
3. 무기 무게 규칙(1절)에 맞게 시간을 고른다. 준비가 너무 짧으면 "손목만" 보인다 → 전조 포즈에서 몸을 먼저 감는다.
4. 확인: `/gg anim <직업> skillq|skille [반복]` · 스크린샷 정면 · 옆 · `/gg hitbox on`으로 리본-판정 겹침.

## 3. 그 밖의 모션 목록(W3b)

| 분류 | 동작 | 방식 | 확인 |
|---|---|---|---|
| 피격 | 움찔(한 대 < 최대 체력 12%) · 큰 피격(≥ 12% - 뒤로 밀림) | 덧씌움(`overlay.flinch` · `big`) - 지금 포즈 위에 곱한다 | `/gg anim <직업> flinch` · `bighit` |
| 넉백 | 체공 중 뒤로 젖힘(AirLocked) → 착지 = 넘어짐 → 일어나기 | 덧씌움 `knockAir` + `getup` | `/gg anim <직업> knock` |
| 기절 | 비틀 → 휘청(sway) → 회복 | 보스 `playerStun` → `WeaponVisual.playStun` | `/gg anim <직업> stun` |
| 넘어짐 → 일어나기 | 튕김 → 누움 → 무기 짚고 한쪽 무릎(`getupKneel`) → 무기 들며 섬 → 전투 자세 | 전체 0.78초 · 무적 0.68 · 입력 버퍼 0.8(불변) | `/gg anim <직업> getup` |
| 이동 | 대시(온몸 숙여 박참) · 2단 대시(비틀기) · 도약 · 코요테 점프 · 공중 점프(무릎 안기) · 활강 시작/끝 · 착지(무릎 받기 · "쿵") | 대시 = 무기별 자세 · 나머지 = 덧씌움. 착지 = 착지 직전 아래 속도 22 / 60 이상 | `dash` · `dash2` · `takeoff` · `coyote` · `airjump` · `glidein` · `glideout` · `land` · `landheavy` |
| 사망 · 부활 | 비틀 → 무릎 → 엎어짐(무기 쥔 채) · 부활 = 한쪽 무릎 → 일어남 → 전투 자세 | 서버 `BreakJointsOnDeath = false` | `death` · `respawn` |
| 꺼내기 · 넣기 | 손이 수납 자리(W1 규격)로 - 몸이 비틀어 따라간다 | `reach.back` · `reach.hip` | `draw` · `sheathe` |

## 4. 남의 화면

- 평타 = 서버 중계 `AttackMotion` · 스킬 = `AirMoveFx` `skillQ` · `skillE` · 대시 = `dash` · `dash2` · 공중 점프 = `flip`(덧씌움 같이) · 일어나기 = `getup`.
- 착지 · 도약 · 사망 · 부활 = 각 클라가 복제된 속도 · 체력 · 캐릭터로 스스로 감지(중계 없음).
- 작은 · 큰 피격은 서버가 맞은 사람에게만 알린다 → 내 화면만(남의 피격 반응은 중계 없음 - 필요하면 K 이후).
