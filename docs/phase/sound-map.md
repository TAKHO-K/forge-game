# 소리 지도 (QUEUE-ALL7 C1 · 2026-10-02)

> 규칙: 소리를 추가 · 바꾸면 이 표와 `shared/data/SoundMixData.lua`(단계 · gain)를 같이 고친다(COMMON §2 한 줄). 재생 입구 = `client/SoundSheet`(`play` · `playRaw`) 하나 - 다른 곳에서 `Instance.new("Sound")`를 만들지 않는다.
> 시트 = `combat`(10.84초) · `loot`(24.42초) · `ui`(8.29초) - 절차 합성 · 피크 −1 dBFS(`roblox/tools/audio/make_sfx.py`). 크기 = Play에서 Volume 1 · 그룹 없이 재생하며 `PlaybackLoudness` 0.05초 간격(2회 중 최대 · 평균). `PlaybackLoudness`는 Volume과 무관한 원본 값이다(0.5로 줄여도 최대 187 그대로).
> 최종 크기 = 그룹(Music 0.35 · Ambient 0.25 · SFX 0.6 · UI 0.4) × 설정 음량 × 단계(T1 1.0 · T2 0.85 · T3 0.7 · T4 0.5 · T5 0.35 · UI 0.3 · 환경 1.0) × gain(원본 평균을 140에 맞춘 값 · 0.5 ~ 1.5) × 남의 소리 0.5(T1 · T2 예외 · 설정 "다른 플레이어 효과음 줄이기" = 0.25).

## 1. 이벤트 → 소리

| 이벤트(입구) | 큐 · 시트 구간(초) | 2D/3D | 그룹 | 단계 · gain | 누구에게 | 분당(추정) | 원본 최대/평균 | 판정 | 이유 |
|---|---|---|---|---|---|---|---|---|---|
| 내 공격 적중 `AttackResult` | hit_light combat 0.25+0.18 | 2D | SFX | T5 · 1.25 · ±5% | 나만 | 100 ~ 150 | 187/112 | 유지 | 필수(타격) · 가장 잦아 T5 |
| 내 치명타 `AttackResult` | hit_crit combat 1.40+0.43 | 2D | SFX | T4 · 1.5 · ±5% | 나만 | 10 ~ 30 | 309/79 | 유지 | 필수 · 원본이 작아 보정 최대 |
| 작은 피격 `HurtEdge` | hurt_small combat 2.67+0.20 | 2D | SFX | T5 · 0.85 · ±5% | 나만 | 10 ~ 60 | 421/166 | 줄임 | 원본이 커서 보정 0.85 · 간격 0.25 |
| 큰 피격(전조 있는 공격) `HurtEdge` | hurt_big combat 3.17+0.52 | 2D | SFX | T4 · 1.05 · ±5% | 나만 | 0 ~ 6 | 369/134 | 유지 | 간격 0.3 |
| 보스 몸 피격 `BossBodyFx` | hurt_big(pitch 0.75) | 3D 70 | SFX | T4 · 1.05 | 주변 | 보스전 | 같음 | 유지 | 기존 간격 0.15 |
| 체력 낮음 `HurtEdge` | heartbeat combat 3.99+0.47 | 2D | SFX | T5 · 0.8 | 나만 | 0 ~ 10 | 450/178 | 줄임 | 원본 큼 |
| 보스 강공격 · 패턴 예고 `BossPatternEvent`(bubble · envTelegraph · regrowTelegraph) | warning combat 4.76+0.36 | 2D | SFX | T2 · 0.5 | 아레나 멤버 | 6 ~ 12 | **610/412** | 줄임(단계는 T2) | 원본이 가장 큼 → 보정 최소 0.5 · 전조 있는 스킬만(평타 소리 예고 없음) · 간격 0.4 |
| 보스 등장 `BossEncounterId` | boss_appear combat 5.42+1.14 | 2D | SFX | T3 · 0.65 | 나만 | 보스전 1 | 430/210 | 유지 | |
| 보스 처치 `BossLingerClient` | boss_death combat 6.86+2.08 | 2D | SFX | T2 · 1.05 | 나만 | 보스전 1 | 447/134 | 유지 | |
| 판 털기 로켓 반짝 `BossRocketView` | rocket_twinkle combat 9.64+0.90 | 2D | SFX | T3 · 1.2 | 아레나(남 = × 0.5) | 드묾 | 308/117 | 유지 | E3 - 옛 남 0.6 → 남의 소리 배율 |
| 대시 · 회피 `DashResult`(새) | swing combat 2.13+**0.14** | 2D | SFX | T5 · 0.7 · ±5% | 나만 | ~7 | 295/204 | 새 자리(재사용) | 필수 자리가 비어 있었다 · 안 쓰던 휘두름 바람 소리 앞 0.14초 · 사용자: 자주 쓰니 짧고 작게 |
| 땅 드랍 `ItemDrop DropGrade` 일반 | (없음) | - | - | - | - | 많음 | - | **삭제** | 일반 드랍 소리 없음 |
| 〃 희귀 | drop_common loot 0.76+0.37 | 3D 70 | SFX | T5 · 0.6 | 주변(남 × 0.5) | 몇 | 380/141 | 줄임 | 아주 작은 1음 |
| 〃 영웅 | drop_epic loot 2.16+0.94 | 3D | SFX | T4 · 1.2 | 주변 | 드묾 | 322/118 | 유지 | 영웅부터 차임 |
| 〃 전설 · 유물 · 고대 | drop_legendary · relic · ancient | 3D | SFX | T3 · 1.2 · 1.05 · 0.95 | 주변 | 드묾 | 307 · 307 · 314 / 116 · 133 · 148 | 유지 | 등급이 오를수록 층 추가 |
| 〃 태초 | drop_primordial loot 7.44+1.29 | 3D | SFX | T2 · 1.15 | 주변(남도 그대로) | 아주 드묾 | 277/124 | 유지 | |
| 〃 초월 | drop_transcendent loot 9.03+2.52 | 3D | SFX | T1 · 1.4 · **덕킹** | 주변(남도 그대로) | 아주 드묾 | 339/99 | 유지 | Music · Ambient 3초 50% |
| 낱개 줍기 `PickupOrb` | pickup loot 0.25+0.21 | 2D | SFX | T5 · 0.65 · ±5% | 나만 | 20 ~ 60 | 361/209 | **묶음** | 0.2초 안 여러 개 = 1번 |
| 보상 날아감 `HitEffects` | reward_fly loot 22.30+0.30 | 2D | UI→SFX 단계 T5 | T5 · 1.2 | 나만 | 몇 | 371/118 | 유지 | 도감 · 보상 받기 |
| 강화 성공 `EnhanceResult` | enhance_success loot 11.85+0.78 | 2D | UI | T3 · 1.05 | 나만 | 강화 때 | 392/131 | 유지 | |
| 강화 유지(실패) · 하락 · 초기화 · 방지권 | enhance_fail · drop · reset · protect_ticket | 2D | UI | T4 · 0.75 / T3 · 0.75 / T3 · 1.0 / T4 · 1.45 | 나만 | 강화 때 | 420 · 449 · 555 · 327 / 186 · 184 · 143 · 98 | 유지 | |
| 레벨업 `CharacterLevel` | level_up loot 17.63+1.12 | 2D | UI | T3 · 0.75 | 나만 | 드묾 | 323/190 | 유지 | |
| 환생 · 칭호 `RebirthResult` · `Titles` | title_get loot 19.97+0.96 | 2D | UI | T3 · 0.85 | 나만 | 드묾 | 280/166 | 유지 | |
| 퀘스트 받을 것 · 합동 목표 단계(새) | quest_complete loot 21.23+0.78 | 2D | UI | T3 · 0.75 | 나만 | 몇 | 405/193 | 유지(+자리) | 합동 목표 단계 소리가 없었다 → 같은 징글 |
| 도감 칸 완료 · 펫 부화 | codex_cell loot 19.05+0.62 | 2D | UI | T3 · 1.15 | 나만 | 몇 | 343/124 | 유지 | |
| 창 열기 · 닫기 `UIManager.changed` | button_press · close ui 0.25 · 0.64 | 2D | UI | UI 0.3 | 나만 | 몇 | (짧아 표본 부족) | 유지 | 클릭만 · 호버 소리 0 |
| 귀환 · 체크포인트 집중(반복) | recall_channel · checkpoint_channel | 2D | Ambient | 환경 · 0.65 · 0.5 | 나만 | 귀환 때 | 371 · 454 / 218 · 321 | 줄임 | 둘은 같은 시간에 안 겹친다(한 채널) |
| 귀환 완료 | recall_done ui 2.84+0.95 | 2D | SFX | T4 · 1.05 | 나만 | 몇 | 337/131 | 유지 | |
| 체크포인트 발견 | checkpoint_found ui 4.09+0.66 | 2D | SFX | T3 · 0.95 | 나만 | 드묾 | 298/151 | 유지 | |
| 균열 시작 `RiftActive` | rift_start ui 6.87+1.12 | 2D | SFX | T3 · 0.5 | 서버 전체(각자 2D) | 드묾 | 435/274 | 줄임 | 원본 큼 |
| 보스 기믹 신호 `BossGimmick13View` | rbxasset 핑 · 클릭(시트 밖) | 2D | SFX(**옛 그룹 없음**) | T2 | 나만 | 기믹 때 | - | 줄임(그룹 안으로) | `playRaw` - 그룹 없는 소리 0 |
| 태초 연출 `PrimordialFx` | (자리값 - id 없음) | 2D | SFX | T2 | - | - | - | 유지(그룹 안으로) | id 생기면 재생 |
| (안 씀) hit_heavy · footstep_soft · skill_unlock · drop_rare | 시트에 있음 | - | - | 표에만 | - | 0 | 361 · 118 · 321 · 361 | 안 씀 | 지금 부르는 곳 없음(지우지 않음 - 시트 구간) |

- 판정 개수: 유지 22 · 줄임 8 · 묶음 1 · 삭제 1(일반 드랍) · 새 자리(기존 소리 재사용) 2(대시 · 합동 목표 단계) · 안 씀 4. **새 업로드 0**.
- 남의 소리: 지금 남의 공격 · 스킬은 소리를 내지 않는다(드랍 · 보스 몸 · 로켓만 3D/남 배율). 남의 UI 소리 = 0(UI 이벤트는 전부 내 Remote · 내 Attribute).
- Music 그룹 = 자리만(배경 음악 없음) · 구역 환경음 없음(겹침 0).

## 2. 시나리오 측정(C4 · Play)

| 시나리오 | 동시 재생 최대 | 재생 | 버림(간격 · 같은 소리 · 가득) | 섞인 크기 최대 / 평균 |
|---|---|---|---|---|
| 혼자 사냥 60초(타격 2.5/s · 치명 · 줍기 · 대시 · 드랍 · 피격) | 7 | 534 | 0 · 0 · 0 | 316 / 47 |
| 보스전 60초(위 + 예고 5초마다 · 큰 피격 · **남 타격 초당 8 + 강타 2**(흉내)) | **8**(≤ 12) | 597 | 74 · 71 · 0 | 333 / 50 |
| 초월 1회 | - | - | - | Music 0.35 → **0.175** → 0.35 · Ambient 0.25 → **0.125** → 0.25(3초) |

- 섞인 크기 = Σ 원본 PlaybackLoudness × Sound.Volume × 그룹 Volume(0.05초 표본) - 상대 비교용.
