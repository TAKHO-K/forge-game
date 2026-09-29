# 소리 없이 풀 수 있는가 — 보스 기믹 점검 목록 (B4)

> 목적: 소리를 끄거나(설정 창 음량 0) 못 듣는 사람도 모든 보스 기믹을 풀 수 있는지 확인한다.
> 점검 시점: B4(사운드 훅 뼈대 - `shared/data/SoundData.lua`의 `soundId`가 전부 비어 있어 게임 안의 효과음은 아래 "기존 소리 2곳"뿐).
> 방법: `shared/data/BossData.lua`의 스킬(primitive) · 환경 변화(environment) · 공통 조각을 훑고, 서버가 보내는 `BossPatternEvent` 종류가 클라에서 어떤 그림으로 그려지는지(`client/BossPatternVisuals.client.lua` 분기 → 각 View 모듈) 파일:줄로 적었다.

## 규칙 (앞으로 소리를 넣을 때)

- **소리는 보조 단서다. 시각 전조를 지우거나 약하게 바꾸지 않는다** — 새 음원을 넣는 작업은 `SoundData.events[*].soundId`만 채우고, View 모듈의 그림(장판 · 말풍선 · 화면 글씨 · 표식)은 그대로 둔다. 소리로만 알리는 새 기믹(예: "소리를 듣고 박자 맞추기")을 만들 때는 같은 정보를 화면에도 그린다.

## 공통 전조 (모든 스킬)

| 단서 | 위치 | 소리 의존 |
|---|---|---|
| 전조 말풍선(보스 머리 위 그림 글자 ! ‼ ? ◎ ✚ ❄ ✖ 등 - 모든 스킬이 전조 시작 순간 한 번) | 서버 `server/BossPatterns.lua:2166`(`send "bubble"`) → `client/BossPatternVisuals.client.lua:203`(`showBubble`) · 그림 표 `:166`(`BUBBLES`) | 없음 |
| 보스 예비 동작(때리는 순간에 맞춘 모션) | `server/BossPatterns.lua:2172`(`BossActAt` · `BossActHit` Attribute) → `client/BossAnimator.client.lua` | 없음 |
| 첫 만남 전멸기 카드(도식 + 한 줄) | `client/BossIntroCard.client.lua:32`(`show`) | 없음 |
| 잡힘 · 구출 패널(상태 이름 + 남은 시간 막대) | `client/BossTrapView.lua:109` | 없음 |
| 파훼 게이트 표식(◈) · 힌트 화살표 | `client/BossGateView.lua:19`(`refresh`) · `:67`(`showHintArrows`) | 없음 |

## 기믹 · 패턴별

| 기믹(보스 · BossData 줄) | 전조 이벤트 | 시각 단서(파일:줄) | 소리 의존 |
|---|---|---|---|
| 강공격 · 원 안 강공격 · 빙결 강타 · 꼬리 휩쓸기 · 파편 폭발(circleBoss - 공통 418 · 384, 서리 709, 심해 829, 수정 947) | `heavyTelegraph` | 보스 중심 위험 원 `client/BossPatternVisuals.client.lua:300` | 없음 |
| 진동파 · 해일 · 방전 고리 · 천둥 고리(ring - 공통 431, 심해 840, 폭풍 1240 · 1333) | `shockTelegraph` · `shockwave` | 전조 고리 `BossPatternVisuals.client.lua:319` · 내 발밑 "점프 틈" 조이는 흰 고리 `client/BossRhythmView.lua:55` · 예비 동작 `client/BossMotionView.lua`(`slamWindup`) | 없음 |
| 낙석 · 쌍권 · 낙빙 · 물기둥 · 수정 낙하/가시 · 독침 낙하 · 모래 잠복 · 회오리 · 낙뢰(circleTarget - 공통 450 · 485, 서리 720, 심해 860, 수정 957 · 1020, 전갈 1108 · 1189, 폭풍 1260 · 1276) | `meteor` · `ambushDig` | 대상 발밑 원 `BossPatternVisuals.client.lua:529`(`meteor`) · `:555`(`meteorLock`) · 잠복 먼지 `client/BossBR1View.lua:496` · 낙뢰 `client/BossStormView.lua:40` | 없음 |
| 돌진 · 잠행 찌르기(charge - 공통 460, 전갈 1119) | `focus` | 대상 표시 `BossPatternVisuals.client.lua:482` · 경로선 `:506` · 대상 머리 위 ‼ `client/BossRhythmView.lua:113` | 없음 |
| 십자 화염 · 얼음 가시 · 집게 강타 · 독침 찌르기(line - 공통 472, 서리 729, 전갈 1100 · 1175) | `cross` · `chain` | 십자 · 직선 띠 `BossPatternVisuals.client.lua:621` · 연쇄선 `client/BossBR1View.lua:471` | 없음 |
| 강화 평타 · 대지 가르기 · 발 구르기 · 꼬리 반원 · 집게 휘두르기(sector - 공통 321 · 510, 서리 769, 심해 886, 전갈 1199) | `sector` | 부채꼴 장판 `client/BossBR1View.lua:122` · 흰 테두리 두 줄 + 무기 번쩍 `client/BossBR13View.lua:157` | 없음 |
| 추적 광구 · 얼음 창 · 눈덩이 · 거품탄 · 수정 파편 · 회오리 이동 · 뇌격 창(projectile - 공통 499, 서리 758 · 778, 심해 902, 수정 1028, 폭풍 1322 · 1345) | `projTelegraph` | 모이는 구체 · 조준 표식 · 굴러갈 띠 `client/BossBR1View.lua:172` · 비행 `:220` | 없음 |
| 공중 가둠(거품 · 회오리 - trapOnHits, 심해 909 · 폭풍 1328) | `bubbleTrap` | 거품 그림 `client/BossGrabView.lua:349` · 구출 패널 `client/BossTrapView.lua:109` · 화면 글씨 `boss.bubble.struggle` `client/BossTrapView.lua:252` | 없음 |
| 대공 잡기(grab - 공통 336) | `grabTelegraph` · `grabMark` | 큰 손바닥 ✋ + "점프하지 마" `client/BossGrabView.lua:115` · `:152` · 머리 위 차오르는 손바닥 · 내 것 "착지!" `:221` | 없음 |
| 투사체 반사 · 가시 반격(reflect - 공통 400, 전갈 1165) | `reflectTelegraph` · `spikeMark` | 결계 · 되돌아올 경로 바닥 선 `client/BossBR1View.lua:531` · `:547` · 갑각 `client/BossBR13View.lua:389` · 가시 자리 `:432` | 없음 |
| 소용돌이(vortex - 심해 895) | `vortex` | 물결 띠 + 폭발 원 `client/BossBR1View.lua:437` | 없음 |
| 에네르기파(sweep - 수정 970) | `sweepTelegraph` | 앞서 도는 바닥 띠 · 회전 화살표 · 안전 원 · ↻ `client/BossBR13View.lua:206` | 없음 |
| 분신 돌격(boomerang - 수정 1040) | `boomTelegraph` | 위험선 + 분신 실루엣 · 화살표 `client/BossBR13View.lua:332` | 없음 |
| 눈보라 포효(sonic - 서리 742 · 엄폐 기둥) | `sonicTelegraph` · `sonicTick` | 좁혀 오는 고리 3개 + 기둥 자리 흰 테 `client/BossSonicView.lua:109` · 가려짐 "0" / 붉은 번쩍 `:120` | 없음 |
| 색 맞추기(colorMatch - 심해 871) | `colorStart` · `colorFlip` | 발판 색판 + 모양 기호(빨강 ● · 파랑 ▲ - 색약 대비) · 머리 위 표시 · 남은 시간 막대 `client/BossColorView.lua:49` · `:113` | 없음 |
| 수정 오르골(orgel - 수정 990) | `orgelStart` · `orgelRing` · `orgelHit` | 종마다 색 번쩍 + 크게 흔들림 `client/BossGimmick13View.lua:209`(`flashBell`) · `:254` · 화면 글씨 "순서를 기억하라 · n/m · 남은 초" `:251` · `:270` · 틀림 = 빨강 번쩍 + 줄기 `:286` · `:291` | **소리 있음(보조)** - 종마다 음높이 `:260` · 틀림 삐빅 `:287`. 순서는 색 번쩍 + 흔들림으로도 보인다 → 소리 없이 풀 수 있음 |
| 진짜 전갈 찾기(sandSearch - 전갈 1145) | `sandDig` · `sandStart` | 파고드는 먼지 · 진짜 둔덕 뒤 발자국 · 꼬리 끝 빛(서버 파트) `client/BossGimmick13View.lua:138` · `:148` · 화면 글씨 "빛나는 꼬리를 찾아 때려라! n" `:153` | 없음 |
| 번개 조준경 · 피뢰침(lightningRods - 폭풍 1304) | `rodsStart` · `rodsTarget` · `rodsLock` | 피뢰침 흰 테 · 화면 "피뢰침 0/N" `client/BossRodsView.lua:91` · 표적 머리 위 ⚡ + 조준경 `:124` · 멈춘 조준경 `:156` | 없음 |
| 환경 변화: 지반 붕괴 · 빙하 균열 · 판 털기 · 수정 부수기(점프 코스) · 개미지옥 · 돌풍(environment - 구간 수호자 667, 서리 692, 심해 816, 수정 938, 전갈 1068, 폭풍 1229) | `envTelegraph` | 구역 위험색 + 금 번짐 + 스타일별 강조 `client/BossEnvironmentView.lua:532` · 붕괴 `:441` · 판 흔들림 `:480` · 코스 도움 `:339` | 없음 |
| 지형 재생성 · 끼임 | `regrowTelegraph` | 자라는 그림자 원 + 위험색 테두리 + 흰 금 `client/BossRegrowView.lua:24` | 없음 |
| 근접 원형 구역 평타(서리 · 폭풍 · 구간 수호자) | `basicSweep` | 보스 발밑 파랑 원(늘 따라감) `client/BossInnerCircleView.lua:25` · 붉은 호 `:70` | 없음 |
| 기절(맞으면) | `playerStun` | 머리 위 표시 `client/BossBR13View.lua:474` · 비틀 모션 `client/WeaponVisual.lua`(`playStun`) | 없음 |
| 29-x 기믹(안전 기둥 · 안전 구역 · 안전 자리 - gimmickTelegraph를 쓰는 보스) | `gimmickTelegraph` | 전역 전조 `client/BossArenaPropsView.lua:176` · 가라앉는 단 `client/BossFloodView.lua:64` · 힌트 화살표 `client/BossGateView.lua:67` | 없음 |

## 결과

- **소리에만 의존하는 기믹: 0개.** 모든 기믹 · 패턴의 전조가 장판 · 말풍선 · 화면 글씨 · 표식으로 보인다.
- 지금 게임에서 소리를 내는 곳은 두 곳뿐이다: ① 수정 오르골(`client/BossGimmick13View.lua:64` `play` - 내장 `rbxasset` 소리 · 음높이만 바꿈 · 보조) ② 태초 드랍 연출(`client/PrimordialFx.client.lua:111` `playSound` - `PrimordialData.soundId`).
- 참고(후속): 위 두 곳은 B4 카테고리 음량(`SoundVolumeBossCue` · `SoundVolumeSfx`)을 아직 따르지 않는다 - 아트 · VFX 파일이라 B4에서 건드리지 않았다. 음원을 넣는 단계에서 `SoundHooks`/`SoundCue.resolve` 경로로 옮기거나 음량 Attribute를 곱한다.
- B4 사운드 훅의 보스 전조 소리(`SoundData.events.bossCue`)는 `bubble`(모든 스킬 전조 시작) · `envTelegraph` · `regrowTelegraph`에 한 번 걸린다 - 위 표의 시각 전조와 같은 순간이다.
