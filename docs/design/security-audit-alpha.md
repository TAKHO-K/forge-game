# 보안 · 치트 감사 (알파 전 · 2026-09-29)

> 범위: `roblox/src` 서버 · 클라 코드 정적 읽기(코드 변경 0 · Play 미실행). 방법 = `Instance.new("RemoteEvent"/"RemoteFunction")` 전수 → `OnServerEvent`/`OnServerInvoke` 핸들러와 그 아래 판정 함수(PlayerProfile · GemCraftRequest · ItemEquip · Quest 등)를 따라가 인자 검사 · 소유권 · 거리 · 쿨을 확인. 클라 `FireServer`/`InvokeServer` 호출부로 실제 인자 모양을 대조.
> 결론 한 줄: **치명 0 · 중요 5 · 낮음 10.** 피해 · 재화 · 드랍 · 퀘스트 · 부활 · 영혼 · 펫 · 설정은 전부 서버 권위다. 남은 구멍은 "클라 신호를 그대로 믿는 한 곳(낙하)"과 "속도 제한 없는 remote의 비용 증폭"이다.

## 1. Remote 전수

### 1-1. 개수
| 구분 | 개수 | 비고 |
|---|---|---|
| 서버가 만드는 Remote 전체 | 123 | RemoteEvent 112 · RemoteFunction 11 |
| 클라 → 서버(라이브에서 받는 입구) | 51 | RemoteEvent 40 · RemoteFunction 11 |
| 서버 → 클라 전용(서버 핸들러 없음) | 71 | 표시 · 동기화 신호. 클라가 쏴도 처리하는 코드가 없다 |
| Studio 전용 | 3 | `BossAnimPreview` · `UiDevCommand`(DevTools 첫머리 가드 뒤) · `P3aTelegraphAck`(검증 블록이 필요할 때만 생성) |
| 채팅 명령(Remote 아님) | 2 | `/gg`(DevTools - Studio 전용) · `/ops`(라이브 - `OpsConfig.userIds`만, 허용 밖은 조용히 무시 · 로그도 안 남김) |

위험도 분포(클라 → 서버 입구 51개 기준, 지금 남은 위험): **치명 0 · 중요 4 · 낮음 47.**

### 1-2. 클라 → 서버 입구(51)
| # | 이름(파일:줄) | 클라가 보내는 인자 | 서버 검증(타입 · 범위 · 소유권 · 거리 · 쿨) | 속도 제한 | 위험도 |
|---|---|---|---|---|---|
| 1 | AttackRequest (AttackServer.server.lua:633) | aimPoint(Vector3) · clientAir(bool) · seq(number) | aimPoint Vector3 아니면 버림 · 원거리는 NaN · 2,000 stud 넘으면 버림 · 사거리 · 대상 · 피해 · 치명 전부 서버 계산 · 구역 = 서버 루트 위치(ZoneBounds) · 영혼 · 채널 · 잡힘 거부 · 원거리 도달 순간 재검증 · clientAir는 서버 공중 세션이 있을 때만 의미 | 공격 템포(간격 − 여유, 서버 시각) | 낮음 |
| 2 | SkillRequest (SkillServer.server.lua:770) | slot("Q"/"E"/"R"/"T") · aimPoint | 슬롯 화이트리스트 · 쿨(SkillStats.cooldown) · 궁극기 게이지 = 서버 표(UltimateService) · 덫 · 화살비 조준점 = Vector3 · NaN · 거리 | 스킬 쿨 | 낮음(F8) |
| 3 | DashRequest (DashServer.server.lua:117) | 없음 | 방향 = 서버가 본 MoveDirection · 거리 · 도착점 서버 계산 · 충전 · 공중 횟수 서버 세션 | MoveRules.tryDash 쿨 | 낮음 |
| 4 | FallLanded (FallServer.lua:173) | speed(number) · flags{water, ladder, server} | 숫자 · NaN · 속도는 서버 궤적 값으로 대체 · **flags.server · flags.water를 그대로 믿음** | 0.3초 | **중요(F1)** |
| 5 | AirMoveFx (MovementServer.server.lua:34) | kind(문자열) | KINDS 화이트리스트 · 생존 | 종류별 0.08초 | **중요(F4)** |
| 6 | PlayerGetup (MovementServer.server.lua:90) | 없음 | 서버가 건 발사 1건당 1회만 무적(consumeForcedLaunch) | minGapSeconds | 낮음 |
| 7 | GlideState (MovementServer.server.lua:110) | on(bool) | true + 해금 + 서버 공중 세션일 때만 켬 | 0.15초 | 낮음 |
| 8 | LedgeClimb (MovementServer.server.lua:198) | ledgePoint(Vector3) · wallDir(Vector3) | 타입 · 장갑 보유 · 공중 · 체공당 1회 · 서버 레이캐스트 · 수평 12 stud · 높이 상한 | 0.3초 | 낮음(F15) |
| 9 | LaunchPermitRequest (LaunchPermit.lua:127) | part(Instance) | 등록된 발판만 · 서버 위치 기록으로 발판 위였음을 확인 | 0.1초 + 쿨 0.25초 | 낮음 |
| 10 | LatencyEcho (RangedLagAssist.lua:22) | token(number) | 서버가 보낸 토큰만 · RTT 상한 lagMaxSeconds | 토큰당 1회 | 낮음(F9) |
| 11 | BossGrabStruggle (BossAirGrab.lua:617) | 없음 | 서버 붙잡힘 기록이 있을 때만 | maxPressesPerSecond | 낮음 |
| 12 | BossLingerChoice (BossLinger.lua:182) | choice(문자열) | 잔류 중 · town/next/retry · next = canGoNext | 상태 전이 1회 | 낮음 |
| 13 | BossGiveUp (BossLinger.lua:178) | 없음 | 보스전 중 · 견습 제외 · 파티면 투표 | 상태 전이 1회 | 낮음 |
| 14 | RaidRequest (BossGate.lua:171) | bossId(문자열) | 문자열 · BossData 존재 · raidCheck(관문 등록 · 견습 · 파티) | 1초 | 낮음 |
| 15 | TravelRequest (Travel.lua:596) | kind · targetUserId | hub/back/party만 · 파티원만 · 보스전 · 전투 중 · 잠긴 구역 | 내부 쿨 | 낮음 |
| 16 | StageMoveRequest (StageServer.server.lua:200) | targetStage(number) | 숫자 · NaN · 내림 · 1 ~ 최고+1 · 안전 · 하드 상한 · 보스 관문 · 파티 리더 · 보스 생존 중 거절 | stageChangeCooldownSeconds | 낮음(F10) |
| 17 | AutoStageSetting (AutoStage.server.lua:38) | presetId | 프리셋 존재 | 즉시 저장 스로틀만 | 낮음 |
| 18 | SettingsSave (SettingsService.lua:82) | key · value | 키 존재 · 종류별 타입(boolean · 프리셋) | 키별 0.1초(trailing) | 낮음 |
| 19 | TutorialChallengeBossRequest (TutorialState.lua:286) | 없음 | 견습 진행 중 · 서버 Attribute TutorialCanChallenge · 보스전 아님 | 상태 | 낮음 |
| 20 | ClassSelectRequest (ClassServer.server.lua:32) | classId | 존재하는 직업 · 같은 직업이면 무시 | **없음** | 낮음(F6) |
| 21 | EnhanceRequest (EnhanceServer.server.lua:25) | useDropTicket · useResetTicket | boolean true만 · 강화대 거리 · 비용 서버 · 확인 → 차감 사이 yield 없음 · EnhancePolicy | 요청 쿨 | 낮음 |
| 22 | ProtectionTicketBuyRequest (ProtectionTicketServer.server.lua:25) | kind | 종류 · 강화대 거리 · 가격 서버 | 없음(골드 소모) | 낮음 |
| 23 | RebirthRequest (RebirthServer.server.lua:25) | 없음 | RebirthAccess(서버 위치 · 보스전 · 강화 중) | 1초 | 낮음 |
| 24 | EquipRequest (InventoryServer.server.lua:49) | action · arg | ItemEquip 모양 검사 · 가방 index(내림) / 부위 문자열 | **없음** | 낮음(F6) |
| 25 | SellRequest (InventoryServer.server.lua:65) | action · arg | sell = 숫자 내림 · 잠금 · 초월 거부 · 가격 서버 / sellBulk · dismantleBulk = 등급 상한 · 잠금 제외 | 없음(즉시 저장만 스로틀) | 낮음 |
| 26 | LockRequest (InventoryServer.server.lua:101) | index · locked · confirmToken | 숫자 · boolean · 태초 · 초월 해제는 토큰(클라 상수 - 이중 확인 UX용, 보안 아님) | **없음** | 낮음(F6) |
| 27 | BulkSellCutoffRequest (InventoryServer.server.lua:152) | gradeId | 등급 존재 · bulkSellMaxGrade 이하 | 없음 | 낮음 |
| 28 | SetInventoryWindowPosition (InventoryServer.server.lua:192) | x · y | number만(NaN · inf 통과 → 저장 직전 sanitizeForSave가 되돌림) | 없음 | 낮음 |
| 29 | AwakenRequest (InventoryServer.server.lua:119) | kind · key · expectedNo | bag/equip · 타입 · 비용 서버 | 0.5초 | 낮음 |
| 30 | AutoProcessRequest (InventoryServer.server.lua:144) | enabled · maxGrade | boolean · 선택지 목록 | 없음 | 낮음 |
| 31 | InheritRequest (InventoryServer.server.lua:183) | part · bagIndex · keep | validShape · keep 문자열 · Inherit.blockReason | 없음 | 낮음 |
| 32 | DismantleRequest (GemServer.server.lua:79) | index | 숫자 내림 · 잠금 등 PlayerProfile | 없음 | 낮음 |
| 33 | GemEquipRequest (GemServer.server.lua:93) | slot · gemInventoryIndex | 숫자 내림 · PlayerProfile.equipGem | 없음 | 낮음 |
| 34 | GemRerollRequest (GemServer.server.lua:103) | kind · key | 모양 · 보석상인 반경(서버 위치) | 없음(변환권 소모) | 낮음 |
| 35 | BuyRerollTicketRequest (GemServer.server.lua:114) | gradeId | ancient/primordial · 반경 · 가격 서버 | 없음(골드 소모) | 낮음 |
| 36 | GemCraftRequest (GemServer.server.lua:60) | action · a · b · c | isIndex(유한 · 1 이상) · same_gem 등 이유 코드 | 없음 | 낮음 |
| 37 | PetRequest (PetService.lua:155) | action · a · b | 동작 화이트리스트 · 숫자 · 알 at 대조 · 부화 시각 · 굴림 서버 | 동작별 0.2초 | 낮음 |
| 38 | QuestRequest (QuestService.lua:238) | action · a · b | 동작별 타입 · Quest.claim이 진행 · 날짜 · 받음 표시를 서버에서 확인 | 동작별 0.2초(**제한 표 키 = 임의 문자열**) | **중요(F5)** |
| 39 | PartyRequest (PartyServer.server.lua:87) | action · arg | 동작별 타입 · 리더 · 멤버 · 보스전 · 견습 | **없음** | **중요(F3)** |
| 40 | BossRewardPreviewRequest (BossRewardPreviewServer.server.lua:18) | stages(표) | validate · pcall | minIntervalSeconds | 낮음 |
| 41 | ClassSummaryFetch (RF · ClassServer.server.lua:28) | 없음 | 본인 요약만 | **없음** | 낮음(F7) |
| 42 | DropTableQuery (RF · DropTableServer.server.lua:23) | tierIndex | 정수 · 범위 | 0.2초 | 낮음 |
| 43 | GemFetch (RF · GemSync.lua:54) | 없음 | 본인 것만 | **없음** | 낮음(F7) |
| 44 | InheritPreview (RF · InventoryServer.server.lua:178) | part · bagIndex | validShape | **없음** | 낮음(F7) |
| 45 | InventoryFetch (RF · InventorySync.lua:90) | 없음 | 본인 것만 | **없음** | 낮음(F7) |
| 46 | LeaderboardRequest (RF · Leaderboard.lua:809) | action · boardId · key | boardId 존재 · card 키 길이 50 · 패턴 · 캐시 300초 | 동작별 1 ~ 10초(키 = 임의 action) | 낮음(F5 · F11) |
| 47 | MilestoneFetch (RF · MilestoneNotice.lua:25) | 없음 | 본인 것만 | **없음** | 낮음(F7) |
| 48 | PartyFriendsFetch (RF · PartyServer.server.lua:76) | 없음 | 캐시 | joinPollSeconds | 낮음 |
| 49 | InspectPlayer (RF · PlayerInspect.lua:109) | targetUserId | 정수 · 같은 서버 · 공개 필드만 스냅샷 | minIntervalSeconds | 낮음 |
| 50 | ProtectionTicketPriceRequest (RF · ProtectionTicketServer.server.lua:36) | 없음 | 서버 가격 | **없음** | 낮음(F7) |
| 51 | SkillInfoRequest (RF · SkillStats.lua:172) | 없음 | 본인 스탯 | **없음** | 낮음(F7) |

### 1-3. 서버 → 클라 전용(71)
AttackResult · AttackLaunched · AttackMotion · AttackShotRelay · HitboxDebug · GoldGained · LevelUp · AirHeavyFx · ComboUpdate · PrimordialGlovesBolt · ZoneBlockedNotice · SystemNotice · BossArenaObstacleBreak · BossArenaEncase · BossIntroEvent · BossIntroCinema · BossGateRegistered · BossLinger · BossPatternEvent · BossRewardPreviewResult · BossRescueHoldBroken · BuffUpdate · MaterialGained · OwnedMobBlocked · SparkleCoinFountain · DamageFeed · DashResult · BossAnimPreview(Studio) · UiDevCommand(Studio) · DropNotice · EnhanceResult · EnhanceAnnounce · FriendJoinedNotice · GemEquipResult · GemWorkshopResult · GemCraftResult · GemSync · PartyHealReceived · EquipResult · AwakenResult · InheritResult · InventorySync · AutoProcessed · InventoryFull · ItemPickedUp · MilestoneReached · TreasureChestNotice · NestSync · NestPicked · OpsReply · PartyStateChanged · PartyInviteNotice · PartyNotice · PartyVoteNotice · PetSync · PlayerHitFeedback · PrimordialBanner · PrimordialFx · ProtectionTicketBuyResult · ProtectionTicketGranted · QuestUpdate · RebirthResult · SaveNotice · SkillCastResult · StageMoveResult · StuckArrowAttach · StuckArrowResult · StuckArrowClear · TranscendentEvent · TutorialStepNotice · HazardPush

- `HitboxDebug`는 라이브에도 있지만 서버가 Player Attribute `DebugHitbox`(`/gg hitbox`만 세움)가 있을 때만 쏜다 → 라이브에서는 안 나간다.

## 2. 클라가 정하면 안 되는 값
| 값 | 누가 정하나 | 근거 | 판정 |
|---|---|---|---|
| 피해량 · 치명 | 서버 | AttackServer.server.lua:367 ~(PlayerCombat.getAttack · 치명 판정) · SkillStats.attack · 원거리 도달 순간 재검증 | O |
| 위치 · 이동 속도 | 클라 물리(엔진 구조) + 서버 사후 검사 | HeightGuard(높이 · 수평 속도 · 공중 정체 → 되돌림) · 대시 거리 서버 계산 · 발사 허가 | △ F2(헤엄 상태 위조로 수평 상한 +18 stud/s) · 벽 통과(noclip) 검사는 없음 |
| 궁극기 게이지 · 스킬 쿨 | 서버 | UltimateService 게이지 표(U.get/U.set) · 충전 = onDealt · SkillServer isOnCooldown | O |
| 골드 · 재화 | 서버 | PlayerProfile.addGold/trySpendGold · 판매가 · 강화비 · 변환권 가격 전부 서버 재계산 | O |
| 드랍 결과 | 서버 | CombatResolution · 서버 RNG · 줍기는 서버 거리 판정(ItemDropServer - "주웠다" 신호 경로 없음) | O |
| 퀘스트 완료 | 서버 | QuestService.note는 서버 사건만 부름 · claim은 Quest.claim이 진행 · 날짜(os.time) · 받음 표시 확인 | O |
| 부활 · 리스폰 | 서버 | BossEncounter · SoulService(pending → consumePending) | O |
| 영혼 상태(SoulState) | 서버 | 판정 = 서버 표 `souls`(SoulService.isSoul) · Attribute는 화면용 | O |
| 펫 Attribute | 서버 | PetService.applyAttributes(PetSpecies · PetBody · PetZone · PetGrade) · 부화 굴림 서버 | O |
| 설정 Attribute | 서버 | SettingsService.sanitize 뒤 SetAttribute | O |
| 알 줍기 · 둥지 | 서버 | NestServer.tryPickup = 쿨 + 서버 위치 기록(checkPresence) | O |

**서버가 논리에 읽는 Attribute**: `FrenzyAttackBonus`(TranscendentService) · `DebugHitbox`(/gg) · `BossEncounterId` · `AutoStage`(SettingsService) · `TutorialCanChallenge` · Character `Gliding`(GlideState 핸들러가 서버 검사 뒤) · `UltTransform`. 전부 서버가 쓴다. 클라가 자기 Player/Character에 SetAttribute 해도 서버로 복제되지 않으므로 이 경로로는 속일 수 없다.
**서버가 읽는 클라 권한 값(엔진이 복제)**: HumanoidRootPart 위치 · Humanoid 상태(Swimming 등) · MoveDirection · FloorMaterial. 위치는 HeightGuard가 검사, MoveDirection은 방향만(거리 서버), **Swimming은 F2**, FloorMaterial은 발밑 광선(probe)과 함께 쓰여 단독 위조 효과는 작다(확인 필요 - 클라 전용 파트 위에 선 경우 서버 FloorMaterial 값은 실측 안 함).

## 3. 속도 제한 커버리지
| 구분 | remote |
|---|---|
| 서버 제한 있음 | AttackRequest · SkillRequest · DashRequest · FallLanded · AirMoveFx(종류별) · PlayerGetup · GlideState · LedgeClimb · LaunchPermitRequest · LatencyEcho · BossGrabStruggle · RaidRequest · TravelRequest · StageMoveRequest · SettingsSave · EnhanceRequest · RebirthRequest · AwakenRequest · PetRequest · QuestRequest · BossRewardPreviewRequest · DropTableQuery · LeaderboardRequest · PartyFriendsFetch · InspectPlayer |
| 상태로 막힘(1회성) | BossLingerChoice · BossGiveUp · TutorialChallengeBossRequest |
| **제한 없음** | ClassSelectRequest · EquipRequest · SellRequest · LockRequest · BulkSellCutoffRequest · SetInventoryWindowPosition · AutoProcessRequest · InheritRequest · DismantleRequest · GemEquipRequest · GemRerollRequest · BuyRerollTicketRequest · GemCraftRequest · ProtectionTicketBuyRequest · AutoStageSetting · **PartyRequest** · RF 7개(ClassSummaryFetch · GemFetch · InheritPreview · InventoryFetch · MilestoneFetch · ProtectionTicketPriceRequest · SkillInfoRequest) |

스팸 비용:
- **DataStore 쓰기**: 안전. 모든 remote의 저장은 `ImmediateSave.request` 하나로 모이고 플레이어당 6초 leading + trailing 스로틀이다(1인 분당 최대 10회). 연타해도 DataStore 호출이 늘지 않는다.
- **DataStore 읽기**: LeaderboardRequest `card`만 캐시 밖 키마다 GetAsync(2초 1회/인 · F11).
- **MemoryStore · MessagingService**: PartyRequest `invite_remote` · `create` · `joincode`가 제한 없이 호출된다(F3) - 한도가 서버 · 경험 단위라 한 사람이 다른 사람의 크로스서버 파티까지 막을 수 있다.
- **서버 CPU · 대역폭**: 제한 없는 상태 변경 remote는 매번 `InventorySync.push`/`GemSync.push`(가방 전체 스냅샷)를 요청자에게 다시 보낸다(F6). AirMoveFx는 요청 하나를 서버 전원에게 중계한다(F4).

## 4. DevTools · 디버그 훅 관문
| 항목 | 관문 | 판정 |
|---|---|---|
| DevTools.server.lua `/gg` | 20줄 `if not RunService:IsStudio() then return end` - 명령 · Remote · 훅이 전부 그 뒤에서 만들어진다 | O |
| allowedUserIds | shared/data/DevToolsConfig.lua:23 = `{}`(빈 목록 = Studio 안 아무나 - DevTools.server.lua:132) | 낮음(F13) - 라이브 영향 없음 · Team Create 다중 접속만 |
| verifyArmed | DevToolsConfig.lua:175 = `IsStudio() and VerifyArmedUntil` | O |
| DevCommandHook · UiDevCommand · BossAnimPreview | DevTools 첫머리 가드 뒤(3125 · 3130 · 25) | O |
| AttackHook · DashHook · W1GetupHook · LedgeClimbHook · SkillCastDebug · OpsHook · StageServer 225 훅 | 각각 `IsStudio()` 블록 안 | O |
| AutoStageHook(AutoStage.server.lua:138) · AutoStageMoveHook(StageServer.server.lua:215) | 가드 없음 · ServerStorage | 정보(F14) - ServerStorage는 클라에 복제되지 않고 Bindable은 경계를 못 넘는다 → 클라 접근 불가. AutoStageMoveHook은 라이브 자동 이동이 실제로 쓴다 |
| P3aTelegraphAck | P3aArenaVerify.ensureAck(검증 블록 D - DevTools 체인에서만) · 클라 쪽도 `verifyArmed` 가드 | O |
| PerfProbe(모든 RemoteEvent에 리스너) | DevTools만 require · `assert(IsStudio())` | O |
| 클라 자체 점검 스크립트(*Check.client.lua 15개 · InputDiag · P3aTelegraphLog) | 전부 `IsStudio()`(P3aTelegraphLog = `verifyArmed` - 역시 IsStudio 포함) 가드(UiGalleryBoot은 Studio 전용 Remote를 10초 기다렸다 없으면 끝) | O |
| TranscendentService.debug* · MonsterState C3Immortal · Travel DebugZonesUnlocked · TrailSkinService 개발 계정 | 전부 `IsStudio()` | O |
| TerrainBakeRun loadstring | edit 명령줄 전용(라이브에서 require 경로 없음) | O |
| `/ops`(OpsServer) | 라이브 · `OpsConfig.userIds`(서버 전용 모듈 - 클라에 복제 안 됨) · 허용 밖 = nil(로그 · DataStore 쓰기 없음) | O |

라이브에서 닿는 디버그 Remote: **없음**.

## 5. 발견 목록(우선순위)
| ID | 등급 | 위치 | 공격 시나리오 | 수정 제안 |
|---|---|---|---|---|
| — | **치명** | — | 없음(재화 복제 · 임의 피해 · 임의 보상 · 디버그 Remote 노출 경로를 찾지 못함) | — |
| F1 | **중요** | FallServer.lua:95 · :33 · :173 ~ 175 | `FallLanded:FireServer(0, {server = true, water = true})`를 낙하 도중 보낸다 → `flags.server`가 "서버 착지 대기(pending)" 분기를 건너뛰고, `inWater = flags.server and flags.water`로 물 제외가 성립 → `fallHandled = true`가 되어 실제 서버 착지 처리도 건너뜀 = **낙하 피해 · 쓰러짐 면제** | Remote 핸들러에서 flags를 `{ water = flags.water == true, ladder = flags.ladder == true }`로 새로 만들어 넘기고 `server`는 절대 받지 않는다(서버 내부 호출만 세 번째 인자 따로). context의 inWater는 서버 판정만 |
| F2 | **중요** | HeightGuard.lua:239 | 클라가 Humanoid 상태를 Swimming으로 바꿔 두면(상태는 클라 권한 · 복제됨) 수평 상한이 걷기 + 18 stud/s(약 1.7배)로 오른다 → 속도 핵 여유. 높이 쪽(384 ~ 385)은 이미 "실제 물속일 때만"으로 고쳐져 있는데 수평 쪽이 빠졌다 | 239를 `WorldHazards.inWater(root.Position)`만으로(385와 같은 규칙) |
| F3 | **중요** | PartyServer.server.lua:87(104 · 131 · 151) · PartyCrossServer.lua:759 | ① `invite_remote`를 초당 수십 번 → 매번 MessagingService PublishAsync(서버 한도 150 + 60 × 인원/분) → 그 서버 전체의 크로스서버 파티 초대 · 합류 알림이 막힌다. ② targetUserId가 친구인지 확인하지 않아 **아무 UserId에게나 초대 팝업 스팸**. ③ `create` ↔ `leave` 반복 = 코드 발급 UpdateAsync, `joincode` 반복 = GetAsync → 경험 전체 MemoryStore 한도 소모 | PartyRequest 전체에 동작별 간격(예: 초대 · 생성 · 합류 2초, 나머지 0.3초) + invite_remote는 GetFriendsAsync 캐시(partyFriendsFetch 결과)에 든 userId만 |
| F4 | **중요** | MovementServer.server.lua:34 ~ 53 · MovementConfig.lua:74 | 제한이 "종류별" 0.08초라 6종을 번갈아 쏘면 초당 75건 → 각각 서버의 **다른 모든 플레이어**에게 FireClient(거리 제한 없음). 20명 서버면 한 사람이 초당 1,500건을 만들어 전원의 수신 대역폭 · 애니메이션 처리를 잡아먹는다 | 사람 단위 합계 제한(예: 초당 8건) + AttackMotion처럼 거리(MOTION_SEND_STUDS) 안 사람에게만 중계 |
| F5 | **중요** | QuestService.lua:240 (같은 모양: Leaderboard.lua:591 ~ 599 · 613) | 제한 표 키가 `tostring(action)` - 동작을 검사하기 전에 표에 넣는다 → 매번 다른 긴 문자열을 보내면 `lastRequest[player]`가 끝없이 커진다(퇴장 때만 정리). PetService는 같은 문제를 화이트리스트로 이미 막았다(리뷰 주석) | 동작 화이트리스트(`view` · `claim` · `train`) 검사 뒤에 표에 넣는다. Leaderboard도 `requestIntervalSeconds[action]`이 없는 action은 표에 넣기 전에 거절 |
| F6 | 낮음 | ClassServer.server.lua:32 · InventoryServer.server.lua:49 · 101 · 144 · 152 · 192 · GemServer.server.lua 60 ~ 114 등(3절 "제한 없음") | 장착 · 잠금 · 직업 전환을 초당 수백 번 → 매번 능력치 재계산 + 가방 · 보석 전체 스냅샷 재전송. DataStore는 안전(ImmediateSave 6초). 직업 전환은 버프 · 화살 · 분신 정리 + 스탯 재계산이라 가장 무겁다 | 공통 헬퍼 하나로 사람당 초당 N건(예: 10) 제한. 직업 전환은 1초 |
| F7 | 낮음 | InventorySync.lua:90 · GemSync.lua:54 · ClassServer.server.lua:28 · SkillStats.lua:172 · MilestoneNotice.lua:25 · ProtectionTicketServer.server.lua:36 · InventoryServer.server.lua:178 | 스로틀 없는 RemoteFunction - 가방 전체 · 4직업 요약 · 스킬 스탯을 초당 수백 번 계산 · 전송 | DropTableQuery와 같은 0.2초 간격 + 간격 안이면 마지막 결과 캐시 반환 |
| F8 | 낮음 | SkillServer.server.lua:529 · 563 · UltimateService.lua:167 · 215 | 사냥꾼의 덫 · 궁극기 화살비는 **조준점의 구역**으로 대상을 거른다 → 평타가 막는 "구역 밖(안전지대 · 담장 밖)에서 안쪽 쏘기"가 설치형으로는 된다. 덫은 수평 거리만 봐서 Y가 무제한(표시 파트가 하늘 · 땅속에 생김 - 판정은 sameLayer라 무해) | 시전자 위치의 구역 = 조준점 구역일 때만 허용(ZoneBounds.isInside(rootPart.Position, …)) · 덫 Y는 서버 지면 레이캐스트로 |
| F9 | 낮음 | RangedLagAssist.lua:22 ~ 33 | 클라가 LatencyEcho 응답을 일부러 늦추면 왕복 지연이 lagMaxSeconds까지 부풀어 원거리 보정 반경(몹 속도 × 편도 지연)이 넓어진다 - 빗맞은 화살이 맞는 폭이 조금 커짐 | 현재 상한으로 충분 - 알파 계측에서 보정 반경 분포만 본다 |
| F10 | 낮음(설계 확인) | StageServer.server.lua:71 | "최고 + 1까지 이동"이라 처치 없이 쿨마다 한 칸씩 다음 보스 관문까지 올라갈 수 있다(최고 기록이 이동만으로 오름) | 의도라면 그대로(자동 이동과 같은 규칙). 리더보드 · 보상이 infiniteBest를 쓰면 처치 조건 추가 검토 |
| F11 | 낮음 | Leaderboard.lua:663 ~ 697 | `card`를 매번 다른 `u<숫자>` 키로 → 캐시 밖이면 GetAsync(2초 1회/인). 여러 명이 하면 서버 읽기 예산(60 + 10 × 인원/분)을 나눠 씀 | 상위 topN · 파티 키처럼 캐시에 있는 키만 조회 허용 |
| F12 | 낮음(확인) | (StarterGui ResetButtonCallback 미설정 - 코드 검색 0건) | 캐릭터 초기화로 붙잡힘 · 쓰러짐 · 보스 기믹에서 빠질 수 있는지 미확인 | 보스전 · 붙잡힘 중 초기화 동작을 한 번 Play로 확인하거나 SetCore("ResetButtonCallback", false) |
| F13 | 낮음 | shared/data/DevToolsConfig.lua:23 | allowedUserIds 빈 목록 = Team Create Studio 참가자 누구나 /gg(라이브 무관) | 개발 계정 UserId 한 줄 넣기 |
| F14 | 정보 | AutoStage.server.lua:138 · StageServer.server.lua:215 | 가드 없는 Bindable이지만 ServerStorage라 클라가 못 닿음 | 그대로 |
| F15 | 낮음(확인) | MovementServer.server.lua:155 ~ 165 · 167 | ledgePoint에 NaN 좌표 → 수평 거리 비교가 NaN이라 통과 → NaN 원점 Raycast(에러면 로그 스팸 · 결과는 MoveRules.ledgeClimbValid가 NaN 거절) | handleLedge 첫머리에 `ledgePoint == ledgePoint` · 유한 검사 |

## 6. 공격 하네스 제안
실행 방식: (가) 판정 함수를 직접 부를 수 있는 것(ItemEquip.handle · GemCraftRequest.handle · ItemInherit.handle · FallServer.onLanded · Leaderboard.handle · PlayerInspect.handle · BossRewardPreview.handle · SkillCastDebug · AttackHook · DashHook · LedgeClimbHook)은 서버 검증 블록에서 직접 호출. (나) 핸들러 안에 판정이 있는 것(QuestRequest · PartyRequest · PetRequest · SellRequest · StageMoveRequest)은 Studio 가드 클라 점검 스크립트(`*Check.client.lua`와 같은 모양)가 실제 `FireServer`로 쏘고 서버 블록이 전후 상태(골드 · 가방 길이 · 표 크기 · 로그 카운터)를 대조. 공통 기대: **에러 없음 · 상태 변화 0 · 저장 요청 증가 0(ImmediateSave.getRequestCount)**.

| # | remote | 넣을 입력 | 기대 거절 |
|---|---|---|---|
| 1 | AttackRequest | aimPoint = "x" · {} · Vector3(NaN, 0, 0) · Vector3(1e308, 0, 1e308) · 사거리 밖 몹 좌표 / clientAir = "true" · 1 / seq = NaN · 2^40 / 100건/초 | 문자열 · 표 = 무시(가까운 대상) · NaN · 먼 값 = 바라보는 방향 · 사거리 밖 = 헛스윙 · seq = nil · 초당 적중 수 ≤ 1 ÷ 간격(템포) · 피해 합이 정상 연타와 같음 |
| 2 | SkillRequest | slot = "X" · 1 · nil · "t"(소문자) / T 조준점 NaN · 5,000 stud · 구역 밖 / 게이지 0에서 T / 100건/초 | 슬롯 무시 · aim · gauge 거절 · 쿨 거절(cooldown) · 스킬 1회만 발동 |
| 3 | FallLanded | (0, {server = true, water = true}) 낙하 중 · (NaN) · (1e9) · ("50") · flags = "x" / 100건/초 | **지금은 F1로 면제됨 → 수정 뒤** 서버 궤적 속도로 피해 · NaN · 문자열 = none · 0.3초 제한 |
| 4 | StageMoveRequest | NaN · -1 · 0 · 1.5 · 1e9 · "5" · 최고 + 2 · 못 깬 보스 위 / 연타 | range · safe_cap · hard_cap · boss_locked · too_fast · 스테이지 변화 없음 |
| 5 | SellRequest | ("sell", 0 · -1 · NaN · 1e9 · 잠긴 칸 · 초월 칸) · ("sellBulk", "primordial" · "") · ("x", 1) / 100건/초 | not_found · locked · transcendent · 상한 등급 거부 · 골드 증가 0 · 저장 요청은 6초 스로틀 |
| 6 | GemCraftRequest | ("refine", "slot", 1, 1) · ("refine", "bag", 2, 2) 같은 보석 · b/c = NaN · inf · 0 · 1.5 · 가방 길이 + 1 · ("sell", 착용 중 홈) · action = {} | same_gem · invalid · not_found · 가루 · 골드 변화 0 |
| 7 | InheritRequest / InheritPreview | part = "weapon" · "hat" · nil / bagIndex = NaN · 0 · 999 / keep = 5 · "" / Preview 100건/초 | invalid · 두 장비 · 골드 불변 · Preview는 F7 수정 뒤 간격 거절 |
| 8 | PetRequest | ("hatch", 1, 틀린 at) · ("hatch", NaN, 0) · ("claim", 대기열 밖 · 아직 안 된 칸) · ("equip", 999 · "1") · ("x" × 1,000종) / 100건/초 | no_egg · no_hatch · not_ready · 장착 불변 · 제한 표 크기 ≤ 4 |
| 9 | QuestRequest | ("claim", "daily", 없는 id) · ("claim", "attendance", "1.5" · "0x1" · "99") · ("claim", "main") 조건 미달 · 같은 보상 2회 · action = 매번 다른 1KB 문자열 1,000개 | unknown · not_done · claimed · 보상 1회 · **지금은 F5로 표가 1,000칸 커짐 → 수정 뒤 0칸** |
| 10 | PartyRequest | ("invite", 자기 · 없는 id · NaN) · ("invite_remote", 친구 아닌 임의 id) · ("kick", 리더 아님) · ("joincode", "" · 길이 틀림 · 1KB) · create/leave 반복 · 100건/초 | self · not_leader · party_not_found · **지금은 F3로 발행 수가 요청 수와 같음 → 수정 뒤 간격당 1건 · 비친구 거절** |

추가로 한 줄씩: LedgeClimb(NaN · 먼 점 · 땅 위) → no_ledge · not_air · 에러 로그 0 / AirMoveFx(6종 번갈아 100건/초) → 수정 뒤 다른 클라 수신 ≤ 초당 8 / LeaderboardRequest(action 1,000종 · card 키 51자 · 패턴 밖) → bad_request · 표 크기 불변.

## 7. 다음 행동(권장 순서)
1. F1 · F2 - 한두 줄 수정(판정 규칙을 서버 값으로) + FallLanded · 헤엄 위조를 하네스 3번과 Play 한 번으로 확인.
2. F3 · F4 · F5 - 제한 표 · 화이트리스트 · 중계 거리(각 핸들러 몇 줄).
3. F6 · F7 - 공통 사람당 요청 제한 헬퍼 하나로 "제한 없음" 목록을 덮는다(데이터 = CombatConfig 옆 새 설정 표 · core 하드코딩 금지 규칙).
4. F8 · F10 · F12는 설계 확인 뒤 결정.

## 8. 반영(QUEUE-6h-b R3 · 같은 날)
| ID | 처리 | 위치 |
|---|---|---|
| F1 | 수정 - Remote 핸들러가 flags를 `{ water, ladder }` 새 표로만 넘김(server 표시 위조 불가) | FallServer.lua `FallServer.start` |
| F2 | 수정 - 수평 상한 = 실제 물속(`WorldHazards.inWater`)일 때만(헤엄 상태 무시) | HeightGuard.lua |
| F3 | 수정 - 파티 요청 허용 동작 목록 + 동작별 간격(`PartyConfig.requestGapSeconds` - 초대 · 원격 초대 · 생성 · 코드 합류 2초 · 나감 1초 · 나머지 0.3초) + 원격 초대 = 친구 목록(PartyFriendsFetch 캐시)에 든 사람만 | PartyServer.server.lua · PartyConfig.lua |
| F4 | 수정 - 공중 모션 중계 사람당 초당 8건 + 거리 220 stud 안 사람에게만(`MovementConfig.airMotion.relayMaxPerSecond · relayRangeStuds`) | MovementServer.server.lua · MovementConfig.lua |
| F5 | 수정 - 퀘스트 요청 허용 동작 확인 뒤에만 제한 표(Leaderboard는 같은 모양이지만 간격 표에 없는 동작이 이미 거절돼 표 증가 폭이 작음 - 기록만) | QuestService.lua |
| F15 | 수정 - 모서리 잡기 좌표 NaN · inf 거절 | MovementServer.server.lua |
| (R2) 판매 칸 밀림 | 수정 - 판매 · 일괄 판매 · 일괄 분해 요청 사이 0.3초 | InventoryServer.server.lua |
| F6 · F7 · F8 · F9 · F10 · F11 · F12 · F13 | 기록만(낮음 - 결정 필요 목록) | - |
- 공격 하네스(로컬 · 실제 서버 핸들러 호출): `roblox/tools/harness/attack_test.luau` 6/6 - 판매 잘못된 인자 8종 · 판매 연타 100회 = 1개 · 퀘스트 잘못된 인자 6종 · 펫 NaN · 거대 · 음수 · 남의 알 7종 · 설정 잘못된 값 3종 · 낙하 server 표시 위조.
- Studio 실측(Play)은 Rojo 연결이 끊겨 이번 대기열에서 못 함(Studio 코드 = 1ba5273 일부 이전) - 다음 Play 목록.
