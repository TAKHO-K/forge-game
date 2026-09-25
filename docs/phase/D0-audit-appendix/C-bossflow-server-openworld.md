# 감사 (d) 보스전 흐름 · (j) 서버·소셜 · (k) 오픈월드

읽기 전용 조사(2026-09-25, 커밋 c4ed73b 기준). 경로는 `roblox/src/` 기준. 확인 못 한 것은 [추정].

---

## (d) 보스전 흐름

### 1. 현재 흐름 순서도

```
[스테이지 선택 창] 보스 칸(5의 배수) 클릭 → 띠(StageRewardBand)만 채움 → [도전] 클릭
   client/StageSelectPanel.lua:582-604 (보스 칸은 선택만), :454-456 onChallenge → StageMoveRequest:FireServer(stage)
        │
        ▼
[서버 StageServer.server.lua:44 OnServerEvent]
   ① 범위: 1 ≤ target ≤ best+1 (:56-60)  ② safeStageCap (:64)  ③ 바로 아래 보스 미클리어면 boss_locked (:74-78)
   ④ 파티 + 보스 스테이지 + 아직 보스전 아님 → 리더 아니면 party_not_leader(:84-88) / 전원 checkPartyEntry(:89-98)
        │ (솔로)                                 │ (파티)
        ▼                                        ▼
   performMove() 바로                      PartyVote.start (StageServer :139-150, PartyVote.lua:58-109)
                                            리더 포함 2명 동의면 성립(:81, :129), 제한시간 뒤 판정(:100-106)
                                            다른 입장 멤버가 없으면 즉시 성립(:70-73)
        │                                        │ passed
        ▼                                        ▼
   performMove (StageServer :104-133): setInfiniteStage(리더/솔로만 - :106) → isBossStage면
     솔로 BossEncounter.spawnFor (:119, BossEncounter.lua:327) / 파티 spawnForParty (:117, BossEncounter.lua:409)
        │
        ▼
[spawnEncounter BossEncounter.lua:277-323] 슬롯 배정 allocateSlot(:134) → BossArenaMap.dress(테마·구조물, :280)
   → 멤버 전원 아레나 입장점 텔레포트(:283-285) → 보스 스폰(:290) → encounter{startedAt=os.clock()}(:303)
   → ArenaKit(:313) → 입장 유예 2초(:314) → 힌트 단계(:316-319) → Containment(:320) → startedListeners(:321)
        │
        ▼
[전투] MonsterAI/BossPatterns. 사망 → Humanoid.Died → task.defer(resetFor) (:624-628)
   · resetFor(:570-611): 생존자 >0 이면 유지(:576-580). 생존자 0(전멸) → 보스 HP 풀회복·패턴 리셋·
     **startedAt = os.clock()(:587, 기록 시간 초기화)** · 구조물 재생성 resetObstacles(:588) · 힌트 단계 +1(:591-600) · 중앙 복귀
   · 리스폰: CharacterAdded 훅이 encounter.slot이 있으면 아레나로 다시 텔레포트(:630-643). 재도전 횟수 제한 없음(:566 주석)
        │
        ▼
[처치] CombatResolution.resolveHit → handleBossDeath (CombatResolution.lua:362-363, :193-289)
   보상(기여 ≥ 임계값 멤버 각자 1인분, :208-221) → 진도 판정 evaluateClear(:227-251) → Leaderboard.onBossCleared(:268-280)
   → BossEncounter.clearForModel(:283) → endEncounter(:472-502): 멤버 전원 **huntingGroundReturnPosition = 원점(리스폰 마을) +5**(:161-163, :486)
   → 슬롯 반납·장식 철거(:495-500) → 가방 가득 드랍은 복귀 자리 발밑(:285)
```

**클리어 후 어디로 가는가**: 다음 스테이지로 자동 이동하지 않는다. 멤버 전원이 사냥터 원점(리스폰 마을, `WorldConfig.huntingGround.center` = (0,0,0))으로 텔레포트된다(BossEncounter.lua:161-163, :486). 스테이지 값은 그대로 보스 스테이지(예: 5)로 남는다. performMove가 스테이지를 바꾸는 곳은 리더/솔로 본인뿐이고(StageServer:106), 처치 쪽은 `raiseInfiniteBest`만 부른다(CombatResolution.lua:246). 다음 스테이지(6)는 플레이어가 직접 골라야 한다.

**파티원의 스테이지**: spawnForParty/spawnEncounter는 파티원의 `infiniteStage`를 바꾸지 않는다(BossEncounter.lua:277-323에 setInfiniteStage 호출이 없음). 파티원은 자기 스테이지 값(예: 3)을 그대로 가진 채 아레나에 있다.

**전멸**: 위 resetFor. 아레나에 남아 바로 재도전한다(나가려면 스테이지를 옮겨야 한다, :25-27 주석).

**재도전 시 시간 초기화**: 전멸 리셋 때만 `startedAt` 갱신(:587). 첫 시작은 스폰 시각(:303)이고 입장 유예 2초(:314)가 시간에 포함된다.

**파티 탈퇴 · 접속 끊김**
- 탈퇴·추방: PartyState.onMemberRemoved → 그 사람만 leaveFor(BossEncounter.lua:656-666). "disband"(혼자 남아 자동 해산)는 남은 사람이 솔로로 계속(:661-664). HP 배수는 입장 순간 고정(:516-518).
- leaveFor(:519-544): 멤버 목록에서 빼고 잡힘·예고·끼임을 풀고 원점으로 텔레포트. 마지막 한 명이면 endEncounter(true)로 보스 삭제.
- 접속 끊김: Players.PlayerRemoving → leaveFor(BossEncounter.lua:648-651, StageServer:156-158에서 중복 호출. 두 번째는 encounterOf가 nil이라 아무것도 안 함). 파티 쪽 PartyState.disconnect는 유예를 주지만 리스너에는 "disconnect"를 즉시 알린다(PartyState.lua:566-600) → 보스전에서는 즉시 빠진다.
- 재접속: 저장된 스테이지가 보스 스테이지면 **솔로 보스를 다시 스폰**(StageServer:165-176). 파티원은 자기 스테이지가 보스 스테이지가 아니므로 대부분 재스폰되지 않는다. 리더가 재접속하면 솔로 보스가 새로 뜬다.
- 진행 중 투표는 멤버 제거 시 취소(PartyVote.lua:140-144).
- 보스전 중에는 파티 초대·합류를 막는다: PartyJoinRules.checkJoinable in_boss(PartyJoinRules.lua:16), 원격 초대(PartyServer:109), 추방(PartyServer:229), 크로스서버 도착 대기(PartyCrossServer.lua:448-451, bossActive는 :873-885).

**보스가 살아 있을 때 스테이지 이동 가능 여부 — 현재 막지 않는다**
- 솔로: 보스 스테이지에서 일반 스테이지로 이동 → performMove의 `isBossStage(previousStage)` 분기 → despawnFor → 보스 삭제·원점 복귀(StageServer:121-127). 즉 **스테이지 이동 = 포기**.
- 파티 리더가 일반 스테이지로 이동 → despawnFor(:126) → 파티 전원 복귀.
- 파티원이 이동 → leaveFor(:123-124). **단, 파티원 자신의 previousStage가 보스 스테이지일 때만** 이 분기를 탄다. 파티원의 스테이지는 파티 보스 진입 때 안 바뀌므로(위 참고) 파티원이 3→4처럼 일반→일반으로 옮기면 두 분기 모두 안 타서 **아레나에 남는다**(스테이지 값만 바뀜). 고칠 대상 1.
- 솔로가 보스 5 전투 중 보스 10으로 이동 요청: 게이트(:74-78)가 5 미클리어로 막는다. 이미 5를 깼다면 이론상 불가(전투 중인 보스가 5면 best ≥ 10이 되기 어려움). 다만 같은 보스 스테이지를 다시 요청하면 spawnFor가 encounter 존재로 조용히 무시한다(:331-333).
- 클라는 보스전 중 이동 버튼을 막지 않는다. 서버가 판정한다는 원칙(StageSelectPanel.lua:600-603 주석).

### 2. 리더보드 클리어 시간

| 항목 | 위치 |
|---|---|
| 시작 | `encounter.startedAt = os.clock()` - 스폰 시(BossEncounter.lua:303). 투표가 끝난 뒤 스폰되므로 투표 시간은 빠지고 입장 유예 2초는 들어간다 |
| 재시작 | 전멸 리셋 때 `startedAt = os.clock()`(BossEncounter.lua:587) |
| 끝 | 처치 처리 안에서 `os.clock() - encounter.startedAt`(CombatResolution.lua:272) |
| 이론 최소 시간 검사 | `Leaderboard.onBossCleared`(Leaderboard.lua:238-256). 피해를 넣은 사람 전원(현재 멤버 + 도중에 빠진 기여자, CombatResolution.lua:262-267, :278)의 `memberDpsCap`(Leaderboard.lua:192-202) 합으로 `LeaderboardRules.minClearSeconds`(LeaderboardRules.lua:71-80, 보스 최대 HP ÷ DPS 합)를 계산. 이보다 빠르면 전부 거절(too_fast) |
| 쓰기 조건 | `evaluateClear`(LeaderboardRules.lua:19-43)가 "도전 스테이지 = 자기 최고 다음 보스 스테이지 ∧ 본인 기여 ≥ 임계값"일 때만 advanced. 개인/직업 저장소는 advanced ∧ eligible일 때만(Leaderboard.lua:261-276). 파티 기록은 전원 advanced ∧ 전원 eligible일 때만(:279-293). 정렬 값은 "더 좋을 때만" 오르는 UpdateAsync(:106-121) |

→ **지금은 스테이지마다 "첫 클리어 한 번"의 시간만 기록된다.** 같은 보스를 다시 잡으면 reason "not_next"라서 기록하지 않는다.

### 3. 새 규칙 적용 시 바뀌는 파일·함수와 위험

#### 현재 보스 반복 처치 · 보상 규칙 (전제)
- **반복 처치는 지금도 가능하다.** 깬 보스 칸도 [도전]으로 이동 요청이 나가고(StageSelectPanel.lua:454-456), 서버는 target ≤ best+1이면 허용하며(StageServer:57), 처치 뒤 encounter가 지워져 있으므로 spawnFor가 새로 스폰한다(BossEncounter.lua:331). 재접속으로도 재스폰된다(StageServer:173-174).
- 장비: 직업별 첫 클리어는 `rollBossFirstClearDrop`(등급 상승) 1회. 이후에는 `rollBossRetryDrop`으로 **매번 확정 1개**(등급표 tier1, CombatResolution.lua:156-166, Loot.lua:191-202, 기록 `bossFirstClearStages`(PlayerProfile.lua:1112-1128)).
- 골드·경험치·재료: 매 처치(재료 killUnits = 보스 hpMultiplier, CombatResolution.lua:141-148).
- 방지권: 계정 단위 스테이지별 1회(ProtectionTickets.lua:64-72). 도감: 1회성 도장(CombatResolution.lua:215).
- PRD 8360행은 "첫 클리어 확정 지급은 1회"를 근거로 무한 보상 경로가 없다고 판정했다. 그 뒤 28-1에서 재도전 확정 1개(PRD 11353-11358)가 들어왔다. **재도전의 속도 상한은 지금 "원점 복귀 → 스테이지 창 → 도전" 동선뿐이다.**

#### (가) 클리어 후 보스맵 잔류 → 유저가 고르면 다음 스테이지(일반 사냥)로
| 파일 · 함수 | 변경 |
|---|---|
| `CombatResolution.handleBossDeath`(:283-285) | `clearForModel` 대신 "클리어 잔류" 상태로 전환하는 새 함수를 호출. `flushDeferredBossDrops`는 복귀 텔레포트 뒤를 전제로 한다(:78-81, :285). 잔류하면 아레나 바닥에 떨어진다. 떠날 때 흘리거나, 잔류 동안 가방 우선 + 나갈 때 발밑으로 미뤄야 한다 |
| `BossEncounter.endEncounter`(:472-502) 분리 | "보스 정리(model·encounterByModel·힌트)"와 "멤버 복귀 + 슬롯 반납 + undress"를 나눈다. 잔류 중에는 `encounterOf[member]`와 slot을 유지하고 model만 nil로 둔다 |
| `BossEncounter.getActive`(:186-189) 호출부 | getActive가 model을 돌려주는 계약이다. 잔류 중 nil이면 PartyJoinRules(:16) · PartyServer(:109, :160, :187, :207, :229) · TutorialState(:189, :255) · StageServer(:83)의 "보스전 중" 판정이 모두 "아님"이 된다. 잔류 상태를 따로 조회하는 함수가 필요하다 |
| CharacterAdded 훅(:630-643) · Died 훅(:624-628) · resetFor(:570) | 잔류 중 죽으면 resetFor가 `model.Parent` nil로 조용히 반환(:573-575)해서 안전. 리스폰은 slot이 있으므로 아레나로 간다(의도대로) |
| `PartyCrossServer` onEncounterEnded(:878-885) | bossActive 해제와 도착 대기자 부착이 "종료" 시점에 걸려 있다. 잔류가 길어지면 합류자가 계속 대기한다 |
| `StageServer.performMove`(:121-127) | "다음 스테이지" 선택 = 기존 이동 요청(target = boss+1) 그대로 쓴다. previousStage가 보스 스테이지라 despawnFor 경로 → 복귀. 복귀 위치를 원점이 아니라 사냥 구역으로 바꾸려면 huntingGroundReturnPosition(:161)을 바꾼다 |
| 클라 | 잔류 중 선택지 UI(새 패널이나 BossBar 옆 버튼). 화면 체력바는 `BossEncounterId` Attribute를 본다(:59-72). 잔류 동안 지울지 정해야 한다 |
| 방치 타이머 | 잔류에 제한 시간이 없으면 슬롯을 영구 점유한다(아래 슬롯 위험) |

#### (나) 같은 스테이지 재입장 → 보스 재생성 · 파티는 재투표
| 파일 · 함수 | 변경 |
|---|---|
| `StageServer` OnServerEvent(:83) | 지금은 `not getActive(player)`일 때만 파티 검사·투표를 한다. 잔류 상태에서 같은 스테이지를 요청하면 검사와 투표를 다시 타게 분기해야 한다 |
| `BossEncounter.spawnFor/spawnForParty`(:331, :413) | `encounterOf`가 있으면 무시한다. "잔류 encounter의 slot을 재사용해 재스폰"하는 경로(새 함수)가 필요하다: dress(새 시드) · kit 재생성 · startedAt · hintOwner · size(N) 재계산 |
| `PartyVote`(:40-53) | 실패 문구가 입장 전용으로 고정돼 있다(:50). 반대한 멤버를 처리해야 한다. 현재는 투표에 반대해도 spawnForParty가 `getEntryMembers` 전원을 텔레포트한다(BossEncounter.lua:416, :283). 재투표에서는 반대자를 빼고 (라) 경로로 보내는 규칙을 정해야 한다 |
| 보상 | 첫 클리어/재도전 분기는 그대로 동작한다(bossFirstClearStages). **위험: 반복 파밍 속도가 오른다.** 동선이 "원점 → 창 → 도전"에서 "아레나 안 버튼 1번"으로 줄어든다. 재도전 확정 1개 + 골드·경험치·재료(killUnits = hpMultiplier)가 분당 기대치로 커진다. 대책 후보: 재도전 확정 드랍에 스테이지별 쿨다운/일일 횟수, 재입장 대기 시간, 또는 EconSim에 "보스 반복" 경로를 넣어 시간당 보상 ≤ 잡몹 사냥이 맞는지 먼저 확인 [추정 - 현재 EconSim이 보스 반복을 모델링하는지 확인 안 함] |
| 지형 정리 | `BossArenaMap.dress`가 맨 먼저 `undress`를 부르므로(BossArenaMap.lua:849-851) 같은 슬롯 재dress는 안전하다. 추가로 정리할 것: `BossArenaKit.destroy(encounter.kitParts)`(BossEncounter.lua:495), `BossPatterns.clearProps`(:474), `BossTrap.releaseAll`(:473), `BossArenaMap.releaseMember`(:484), `BossArenaContainment.untrack/track`(:498, :320), 텔레그래프 정리(:483). 이 순서는 endEncounter에만 모여 있으니 재사용 가능한 함수로 분리해야 빠뜨리지 않는다. 땅에 떨어진 드랍(ItemDropSpawner는 Workspace 직속, ItemDropSpawner.lua:138)은 undress로 안 지워진다 |

#### (다) 보스 생존 중 스테이지 이동 제한
| 파일 · 함수 | 변경 |
|---|---|
| `StageServer` OnServerEvent(:44 이후) | `BossEncounter.getActive(player)`가 있고 보스가 살아 있으면 reject("in_boss")를 추가한다. 포기(라)는 별도 경로 |
| `client/StageSelectPanel.lua`(:46 REASON 표) · `StageUI.client.lua`(:169-178) | 거절 사유 문구 추가 |
| 우회로 점검 | `/gg stage`(DevTools)는 검사를 안 거친다(StageServer:62-63 주석, 개발 전용). PartyServer 합류 수락이 솔로 보스를 despawnFor한다(:160-161, :187-188, :207-208). 즉 "파티 초대 수락 = 보스 탈출" 우회로가 남는다. 견습 진입(TutorialState:255-256)도 despawnFor한다 |
| 위험 | 재접속 복원(StageServer:165-176)과 결합하면 **못 이기는 보스에 갇힌다**. 저장 스테이지가 보스 스테이지면 접속할 때마다 보스 앞에 서고 이동이 막힌다. (라)의 포기 경로가 반드시 같이 들어가야 한다. 앞 절의 파티원 edge(일반→일반 이동 시 아레나 잔류)도 이 검사로 함께 닫힌다 |

#### (라) 포기 투표 · 파티 탈퇴 → 도전 스테이지 −1 사냥 구역 스폰
| 파일 · 함수 | 변경 |
|---|---|
| 새 Remote + `PartyVote` 확장 | 파티당 투표 1개(:59)라 입장/포기 투표 종류를 구분해야 한다. 솔로는 즉시 |
| `BossEncounter.leaveFor/despawnFor`(:508-544) | 복귀 위치가 원점 고정이다(:486, :535). "stage−1"을 넣으려면 `PlayerProfile.setInfiniteStage(player, stage-1)`과 복귀 위치를 함께 바꾼다 |
| **"stage−1 사냥 구역"의 정의가 없다** | 사냥 구역은 tier1~6(몬스터 종류)의 3×3 고정 배치이고(WorldConfig.lua:67-75), 스테이지는 위치가 아니라 **수치 배율**이다(MonsterState.lua:9-22, 공격자/대상 스테이지로 계산). 스테이지→구역 대응표는 코드에 없다(grep 결과 없음). "stage−1로 설정 + 원점(또는 선택한 tier 구역 입구) 스폰"으로 해석하는 게 현실적이다. 구역을 정하려면 새 데이터(스테이지→tier 권장 구역)가 필요하다 |
| 접속 끊김 처리 순서 | PlayerRemoving에 BossEncounter(:648) · StageServer(:156) · 저장(SaveServer)이 각각 연결돼 있다. 끊길 때 stage−1을 적용하려면 저장보다 먼저 값이 바뀌어야 한다. 연결 순서는 보장되지 않는다 [추정 - SaveServer의 PlayerRemoving 처리 시점 미확인]. 대안: 재접속 복원(StageServer:172-175)에서 "보스 스테이지면 stage−1로 낮춰 사냥터에서 시작"으로 처리(저장 순서와 무관). 이 경우 재접속 재스폰 동작(:160-164 주석)이 없어지고 PRD 결정 변경이 필요하다 |
| 파티 탈퇴 | onMemberRemoved(:656-666)에서 leaveFor 뒤 stage−1을 적용한다. disband 예외는 유지할지 정한다 |
| 파티원 스테이지 | 파티원은 보스 스테이지에 있지 않을 수 있다(스테이지 미동기화). "도전 스테이지−1"은 encounter.stage − 1로 계산해야 한다(개인 stage − 1 아님). 파티원의 현재 스테이지가 그보다 낮으면 올려도 되는지(도달 best+1 규칙, StageServer:57) 확인이 필요하다 |

#### 아레나 슬롯 점유
- 슬롯 12개(`BOSS_ARENA_SLOT_COUNT = 12`, WorldConfig.lua:135), 서버 설계 상한 16(PartyConfig.serverCapacity, PRD 20.63 [2]).
- 슬롯이 모자라면 1번을 같이 쓴다(allocateSlot fallback, BossEncounter.lua:134-138). 아레나와 구조물이 겹치고, `BossArenaMap.dress(zoneKey)`가 먼저 `undress`를 불러 **앞 팀의 구조물을 지운다**(BossArenaMap.lua:850). 공유는 "불편할 뿐"이 아니라 앞 보스전을 망가뜨린다. PRD 8879행은 "현실적 최악 12"로 판정했다.
- 잔류(가)가 들어가면 "클리어하고 서 있는 사람"이 슬롯을 계속 잡는다. 16인 서버에서 솔로 13명 이상이 보스전·잔류 중이면 공유 fallback에 걸린다. **대책**: 잔류 제한 시간(예: 60~120초 뒤 자동 원점 복귀), 슬롯 부족 시 새 입장 거절(대기), 슬롯 수를 16으로(파트 비용: 아레나 기반은 슬롯마다 한 번 짓고 남는다, BossArenaMap.lua:79-122).

#### 리더보드 시간 — 재도전 기록 방식 제안 2개
1. **현행 유지(첫 돌파만)**: "자기 최고 다음 보스" 처치만 기록한다(LeaderboardRules.evaluateClear). 재입장(나)은 기록과 무관하고 전멸 리셋만 시간을 초기화한다. 장점: 코드 변경 0, 파밍으로 기록을 갱신할 수 없다. 단점: 같은 스테이지에서 더 빨리 깨도 반영이 안 된다. 재입장 버튼으로 새 encounter를 만들면 `startedAt`은 재스폰 시각으로 새로 잡아야 한다(잔류 시간이 섞이지 않게).
2. **최고 스테이지 재도전 최단 기록 허용**: `stage == bestBossCleared`(이미 최고로 깬 스테이지) 재처치도 class/party 저장소에 쓰고, UpdateAsync "더 좋을 때만"(Leaderboard.lua:106-121) + encode(같은 스테이지면 짧을수록 큼, LeaderboardRules.lua:51-53)로 최단만 남긴다. 변경 지점: evaluateClear에 "retry_best" 사유 추가, onBossCleared 쓰기 조건. 위험: 장비가 오를수록 옛 기록이 계속 갱신돼 "돌파 경쟁"이 "파밍 속도 경쟁"이 된다. 파티 구성을 바꿔 가며 반복하면 쓰기량이 늘어난다(DataStore 쓰기 한도). 이론 최소 시간 검사는 그대로 적용된다.

---

## (j) 서버 · 소셜

### 4. 서버 최대 인원
- **설계값**: 매치메이킹 정원 12 = 4인 × 3파티(PartyConfig.lua:47-51 `partiesPerServer = 3`), 서버 상한 16 = 12 + 파티 1팀(`crossServerExtraSlots = maxMembers`, :52-54). 근거 PRD 20.63 [2](8844-8863행).
- **코드**: 크로스서버 합류 상한 `min(PartyConfig.serverCapacity, Players.MaxPlayers)`(PartyCrossServer.lua:103-107). 부팅 때 MaxPlayers/PreferredPlayers가 설계값과 다르면 경고를 찍는다(:971-976).
- **place 설정 기록**: PRD 8822행 "Studio 실측: 현재 Place는 MaxPlayers=60, PreferredPlayers=60(로블록스 기본값)". 대시보드에서 16/12로 **수동 변경이 필요**하다(8853행). 코드로는 못 바꾼다. 이후 변경했다는 기록은 찾지 못했다 [추정 - 미변경].
- **12인 성능 예산(docs/perf/baseline.md, 1인 Studio 실측)**:
  - 서버 Heartbeat 평균: 마을 0.43~0.68ms · 사냥 0.46~0.68ms · 보스전 0.56~0.66ms(재측정 0.35~0.42ms). 16.7ms 예산의 약 4%(baseline.md B1, B3).
  - 워크스페이스 파트 약 1,040~1,069. 동시 몬스터 54(+보스). 클라 삼각형 마을 57,600 / 보스전 7,904.
  - 보스 스폰 1.7~2.5ms · +25 인스턴스, 파괴 0.8~1.0ms · −19(B2). 일반 스테이지 전환은 약 0ms · 인스턴스 0.
  - 제안 예산: 동시 몬스터 ≤ 60, 플레이어당 서버→클라 ≤ 20/초(16명 320/초), 폰 사냥 렌더 CPU 최대 13.2ms가 첫 확인 자리(B3).
  - PRD 12인·16인 표: Heartbeat 12인 ≈ 3~5ms / 16인 4~6.7ms, 클라 스트리밍 파트 16인 1,456 / 상한 1,500(여유 2.9%), 화면 삼각형 16인 최악 145,924 / 150,000(PRD 8876행, 9260-9261행).

### 5. 음성 채팅
- **코드**: `VoiceChat`, `AudioDeviceInput`, `voice` 흔적 없음(roblox/src 전체 grep 0건). PRD에도 음성 관련 절 없음. 채팅은 `/gg` 개발 명령 정도만 있다.
- **공식 요건**
  - 이용자: 13세 이상 + 연령 확인(ID 인증 또는 얼굴 연령 추정). "To turn on Voice Chat for the first time, you need to be at least 13 years old, and you must first verify your ID, or complete Facial Age Estimation." 2025-11 이후 채팅 기능 전반에 연령 확인이 필수다. **전화 인증만으로는 열리지 않는다**(2026 기준, 공식 FAQ 문구는 미확인이라 [추정]). 국가 제한도 있다(한국 가용 여부는 [추정 - 미확인]).
    - https://en.help.roblox.com/hc/en-us/articles/34506487825428-How-do-I-turn-on-Voice-Chat
    - https://en.help.roblox.com/hc/en-us/articles/4405807645972-Voice-FAQ
    - https://en.help.roblox.com/hc/en-us/articles/39143693116052-Understanding-Age-Checks-on-Roblox
    - https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat
  - 경험 활성화: Studio File → Experience Settings → Communication → Enable Voice Chat. 최대 인원 100 이하인 place만 가능(16이면 충족). `VoiceChatService.EnableDefaultVoice`, `UseAudioApi`(오디오 API로 근접·파티 채널 제어), `IsVoiceEnabledForUserIdAsync`. https://create.roblox.com/docs/chat/voice-chat
  - 매치메이킹 기본 신호에 "Voice Chat"(가중치 1)이 있다. 음성 사용자끼리 묶는 경향이 이미 있다(scoring 문서).
- 제안(출시 후): 코드 없이 설정 토글만으로 기본 근접 음성이 켜진다. 파티 전용 채널은 UseAudioApi + AudioDeviceInput 라우팅이 필요하다(보스 아레나 z = −3000 이하로 떨어져 있어 근접 음성이면 파티끼리만 들린다 [추정]).

### 6. 커스텀 매치메이킹 (출시 후 과제)
- 기본 설정 신호와 가중치: Friends 15 · Latency 3 · Text Chat 3 · Occupancy 2 · Play History 2 · **Language 2** · Age 1 · Voice Chat 1 · Device 0. https://create.roblox.com/docs/matchmaking/scoring
  → **언어는 기본 신호로 이미 들어가 있다.** 가중치 조정만으로 강화할 수 있다.
- 커스텀 신호: "Currently only 2 custom signals are allowed per matchmaking scoring configuration." Numerical(참가자 값과 서버 집계값의 차이) / Categorical(서버 안에서 같은 값의 비율). https://devforum.roblox.com/t/custom-matchmaking-is-now-available-to-all-experiences-on-roblox/4051419 · https://create.roblox.com/docs/matchmaking/attributes-and-signals
- 속성 제공 방식:
  - **플레이어 속성**은 DataStore API로 관리한다(DataStore에 저장된 값을 매치메이커가 읽는다. 대시보드에서 데이터 스토어·키 경로 지정 [추정 - 정확한 키 경로 형식 미확인]).
  - **서버 속성**은 `MatchmakingService`(SetServerAttribute 계열)로 관리하고 서버 수명 동안만 유지된다.
- 스테이지대로 묶기: Numerical 신호 1개 = 플레이어 속성 "최고 도달 스테이지(또는 bestBossCleared)" vs 서버 평균. 현재 저장은 프로필 한 덩어리(SaveSystem)라 매치메이커가 읽을 **숫자 필드가 별도 키로 존재해야** 한다. 스테이지 수치가 무한 모드라 1e308/bignum 구간에서는 로그 스케일 값을 따로 써야 한다 [추정].
- 한계: 공개 서버에만 적용(예약 서버 제외), 친구 따라가기·파티 합류는 매치메이킹을 우회한다. 서버 생성 시점은 제어 불가. 크로스서버 파티(PartyCrossServer의 TeleportToPlaceInstance 좌석)는 영향 없음 [추정].
- 과제 정리: (1) 대시보드 MaxPlayers 16 / Preferred 12 먼저 설정 (2) 언어 가중치 상향 (3) 커스텀 신호 1 = 스테이지대(Numerical), 신호 2 = 예비(직업 비율 등 Categorical) (4) 매치메이커용 DataStore 키에 스테이지 요약값 기록 → SAVE_VERSION 영향 없는 별도 저장소 권장.

---

## (k) 오픈월드

### 7. 현재 사냥 구역 구조
- **한 서버 = 3×3 구역 하나의 공용 맵**: 가운데 리스폰 마을, 강화소·커뮤니티 광장, tier1~6 구역 6개(WorldConfig.lua:67-75). 맵 한 변 832(WorldConfig.lua:39-42 식, 44행 주석). 구역마다 몬스터 격자 9칸 → **상시 54마리**(HuntingGround.server.lua:293-306, :363-367, baseline.md B1).
- **몬스터는 공유 인스턴스, 스테이지는 개인 수치**: 구역은 "몬스터 종류(tier)"이고 스테이지는 "배율"이다. 몬스터 인스턴스에는 스테이지가 없다. HP는 공용 비율 풀(hpRatio)이고, 때린 사람의 스테이지 기준 유효 최대 HP로 나눈 비율만큼 깎인다. 공격력·골드·경험치는 "그 순간 대상 플레이어의 stage"로 계산한다(MonsterState.lua:9-22, :303, :314-343; MonsterAI.server.lua:228-229, :289-290).
  → 스테이지가 다른 유저끼리 **같은 공간에서 같은 몬스터를 보고 같이 때린다**. 각자 받는 피해·보상이 자기 스테이지 기준으로 다르다. 개인별 스폰이 아니다.
- 보스만 개인/파티 전용 인스턴스이고, 먼 아레나 슬롯(z = −3000부터, WorldConfig.lua:135-157)에 있다.
- 구역 사이는 걸어서 이동하거나 텔레포트 패드로 이동한다(HuntingGround.server.lua:369-404). ZoneTerrain은 지형 장식 담당이다(buildZoneTerrain, :82 / ZoneTerrain.lua).

### 8. 넓은 맵 + StreamingEnabled — 제안만
- **현재 설정**: StreamingEnabled **이미 true**(PRD 6196행 실측, ModelStreamingMode=Default). `default.project.json`에는 Workspace 노드가 없어(roblox/default.project.json) 스트리밍 설정이 커밋되지 않는다. place 파일에만 있다. `StreamingTargetRadius`는 스크립트로 못 쓴다. 권장값 600(WorldConfig.lua:44-53)은 기록만 하고 적용은 Studio 수동이다(HuntingGround.server.lua:319-327 부팅 안내). 현재 반경이 600으로 적용됐는지는 미확인 [추정 - 기본값일 가능성].
- 몬스터 모델은 Atomic 스트리밍(MonsterSpawner.lua:129-131).
- **클라가 Workspace 인스턴스를 전제로 하는 곳**(client grep):
  - 이름으로 찾기 4곳: `BossFloodView.lua:54` Workspace "Ground", `P3aTelegraphLog.client.lua:52` "Ground"(검증용), `BossStormView.lua:214` Workspace:GetChildren으로 피뢰침 이름 탐색, `GemWorkshopCheck.client.lua:152-165`(검증용 앵커, 클라 자체 생성).
  - 태그 기반 12곳(스트리밍 안전 패턴): `GetTagged("Monster")` 5곳(AimTarget:112, BossGateView:60, BossMotionView:46, BossPatternVisuals:139, hud/BossBar:77), ArenaObstacle(BossArenaMapView:79), BossArenaMound 4곳(BossArenaPropsView:71,175 · BossPatternVisuals:87,102), BossArenaDais(BossRhythmView:50), Sparkle(SparkleMonsterVisual:105). `GetTagged`는 스트리밍된 것만 돌려주므로 AddedSignal 연결이 함께 있어야 한다(일부만 확인 [추정]).
  - 보석상인 안내는 이미 스트리밍을 가정해 좌표로 그린다(client/panels/GemWorkshop/Guide.lua:3).
  - 아레나 쪽 이름 탐색(Ground, 피뢰침)은 플레이어가 그 아레나 안에 있을 때만 쓰므로 반경 안이다. 위험은 낮다.
- **넓은 맵 전환 시 비용·위험**
  - 성능: 파트 예산 Workspace ≤ 6,000 · 화면 ≤ 1,500(PRD 6208행). 16인 클라 스트리밍 파트가 이미 1,456/1,500(PRD 9260행)이다. 맵을 넓히면 반경 축소(600 → 400대)가 필수다. 서버는 전 구역 몬스터를 상시 돌리므로 구역 수에 비례해 Heartbeat가 는다(54마리 ≈ 0.5ms → 구역 2배면 약 1ms, 선형 [추정]). 여유는 크다.
  - 설계 충돌: 지금 "스테이지 = 수치, 구역 = 종류"라서 넓은 맵은 "스테이지대별 구역"이라는 새 대응표가 필요하다. 공용 hpRatio 풀은 서로 다른 스테이지가 한 몬스터를 때리는 것을 전제로 한다. 구역을 스테이지대로 나누면 단순해지지만 (라)의 "stage−1 사냥 구역"과 함께 설계해야 한다.
  - 스트리밍 위험: 텔레포트 직후 도착지가 아직 안 스트리밍돼 낙하한다. 아레나·구역 이동에 `Player:RequestStreamAroundAsync`(서버)를 텔레포트 전에 불러야 한다(현재 코드에 0건). 서버 판정용 지면 Raycast는 서버라 영향 없다. 클라 연출이 먼 파트를 참조하는 곳(BossStormView 피뢰침 등)은 nil 가드를 확인해야 한다. 스폰 마을 등 핵심 랜드마크는 `ModelStreamingMode.Persistent`를 고려한다.
  - 운영: 반경·모드는 place 설정이라 git diff로 추적되지 않는다. default.project.json에 Workspace 속성을 넣어 Rojo로 관리하는 것을 권장한다(단, 스크립트 쓰기 불가 속성의 Rojo 반영 가능 여부는 [추정]. 실행 중 rojo는 프로젝트 파일 변경을 반영 안 하므로 재시작 필요).
