# 보안 · Remote · RequestGate · 운영 명령 감사 (읽기 전용 · 2026-10-04)

범위: `roblox/src/server` · `roblox/src/shared`의 클라 → 서버 Remote 전부, `RequestGate.lua` · `RequestLimitConfig.lua`, 운영 명령(`OpsServer` · `OpsRollback` · `OpsConfig` · `AuditTrail` · `SuspicionMonitor` · `SecurityOpsConfig`), 개발 명령(`DevTools.server.lua` · `DevToolsConfig.lua`), 하네스 4개, 문서 2개.
방법: 코드를 직접 읽음. Studio · 하네스는 실행하지 않음(읽기 전용 감사). 아래 모든 근거는 실제로 읽은 파일:줄이다. 확실하지 않은 것은 "확인 필요"로 적었다.

요약: **치명 0 · 높음 1 · 중간 3 · 낮음 9.** 전반적으로 방어가 촘촘하다. 보상 · 가격 · 확률 · 피해 · 위치 판정은 서버가 계산하고, 인덱스 인자는 `type` 검사 → `math.floor` → 표 조회 → 잠금 · 초월 검사 순서를 지킨다. 골드 · 아이템 복제나 서버 중단으로 이어지는 입구는 찾지 못했다.

---

## 1. 즉시 확인 (치명)

**치명 등급 문제 없음.**

치명에 가장 가까운 것은 아래 H1(높음)이다. 보스전 중에 직업을 바꾸면 진입 검사를 건너뛰고, 다른 직업의 첫 클리어 보상을 미리 받는다. 복제는 아니지만 진행도를 건너뛰는 구멍이라 출시 전에 막는 것을 권한다.

개발 명령(`/gg`)은 라이브 서버에서 쓸 수 없다. `DevTools.server.lua:20` `if not RunService:IsStudio() then return end`가 Remote · 명령 등록보다 먼저 실행된다. 개발 명령용 UserId 우회도 없다(`DevToolsConfig.allowedUserIds = {}`, `DevTools.server.lua:126-136`).

---

## 2. Remote 전수 표 (클라 → 서버 입구)

라이브 입구는 61개다(RemoteEvent 46 · RemoteFunction 15). Studio 전용 3개는 표 아래에 따로 적었다. 서버 → 클라 전용 Remote(약 85개)는 핸들러가 없어서 표에서 뺐다.
- "RequestGate" 열: **있음** = `RequestGate.allow/invoke` 사용. **자체** = 모듈 안 자체 간격 · 쿨다운. **없음** = 제한 없음.
- 문서 `docs/design/security-audit-launch.md` 3-1절은 "58(RE 44 · RF 14)"이라 적었다. 실제는 61개이므로 문서 갱신이 필요하다(어느 3개가 새로 생겼는지는 확인 필요. 후보: `MenuTiming`, `AutoProcessRequest`, `BossRewardPreviewRequest`).

| 이름 | 파일:줄(핸들러) | RequestGate 있음 | 인자 검사 | 소유 검사 | 문제 |
|---|---|---|---|---|---|
| AttackRequest | AttackServer.server.lua:640(본문 199) | 자체(공격 간격 242) | aimPoint `typeof Vector3`(315) · 원거리 NaN · 2000 stud(329) · seq 정수화(229) | 자기 캐릭터 · 서버 사거리 · 구역(358) | 근접 분기는 NaN aimPoint를 안 거르지만 AimPicker가 무해하게 처리한다(낮음 L1) |
| AutoStageSetting | AutoStage.server.lua:39 | 있음 | 문자열 · 프리셋 존재 | 본인 설정 | 없음 |
| BossGrabStruggle | BossAirGrab.lua:630(본문 593) | 자체(초당 maxPresses) | 인자 없음 | 잡힌 기록 본인만 | 없음 |
| RaidRequest | BossGate.lua:177 | 자체 1초 | 문자열 · BossData 존재 | raidCheck(관문 · 진행) | 요청마다 print(183) |
| BossGiveUp | BossLinger.lua:178 | **없음** | 인자 없음 | 본인 encounter · 견습 제외 | 연타 제한 없음(낮음 L3) |
| BossLingerChoice | BossLinger.lua:182 | **없음** | 문자열 · 3종 분기 | 본인 encounter · 리더만 retry | 연타 제한 없음(L3) |
| BossRewardPreviewRequest | BossRewardPreviewServer.server.lua:18 | 자체(minInterval) | validate(stages) | 본인 기록 | pcall 보호 |
| ClassSummaryFetch (RF) | ClassServer.server.lua:29 | 있음(invoke) | 없음 | 본인 | 없음 |
| StatSheetFetch (RF) | ClassServer.server.lua:39 | 있음(invoke) | 없음 | 본인 | 없음 |
| ClassSelectRequest | ClassServer.server.lua:45 | 있음(1/s · 통 2) | 문자열 · ClassData 존재 | 본인 | **보스전 · 영혼 · 채널링 중 전환을 막지 않음 → H1** |
| CodexRequest | CodexService.lua:236 | 자체 0.2초 | action · arg 문자열 | done · claimed 서버 기록 | 없음 |
| CommunityGoalClaim (RF) | CommunityGoalService.lua:202 | 있음(invoke) | number · tiers 존재 | 기여 ≥ 1 · claimed | 문서 R3(넘친 요청 = 마지막 결과 표시) |
| DashRequest | DashServer.server.lua:117 | 자체(MoveRules.tryDash 쿨) | 인자 없음(방향 = 서버 Humanoid.MoveDirection) | 본인 | 없음 |
| DropTableQuery (RF) | DropTableServer.server.lua:23 | **없음** | 정수 · 범위 | 읽기만 | 읽기 전용 · 계산 가벼움(L3) |
| EmoteRequest | EmoteService.server.lua:29 | 있음(0.5/s) | 문자열 · fromUserId 대조 | 파티원 · 거리 · 보스전/영혼 제외 | 없음 |
| EnhanceRequest | EnhanceServer.server.lua:25 | 있음 + 서비스 0.5초 | 방지 플래그 = resolveProtectionFlags | 강화대 근처 · 골드 · 재료 서버 확인(EnhanceService.lua:62-155) | 없음 |
| FallLanded | FallServer.lua:173(본문 84) | 자체 0.3초 | speed number · NaN · flags는 water · ladder만 복사 | 서버 체공 세션 · 서버 속도로 덮어씀(108-113) | 물 · 사다리는 서버 판정(FallServer.lua:37-38) |
| GemCraftRequest | GemServer.server.lua:61 | 있음 | isIndex · 문자열(GemCraftRequest.lua:18-) | 본인 보석 · 같은 보석 거부(GemCraft.lua:72) | 없음 |
| DismantleRequest | GemServer.server.lua:83 | 있음 | number → floor | 잠금 · 등급 · 초월(PlayerProfile.lua:1128-1154) | 없음 |
| GemEquipRequest | GemServer.server.lua:100 | 있음 | number 둘(GemEquip.lua) | 본인 | 없음 |
| GemRerollRequest | GemServer.server.lua:113 | 있음 | kind · key 모양(GemWorkshop.lua:16-22) | 보석상인 근처 | 없음 |
| BuyRerollTicketRequest | GemServer.server.lua:127 | 있음 | ancient/primordial만 | 가격 서버 계산 · 근처 | 없음 |
| GemFetch (RF) | GemSync.lua:55 | 있음(invoke) | 없음 | 본인 | 없음 |
| EquipRequest | InventoryServer.server.lua:50 | 있음 | ItemEquip.handle(number · string) | 본인 가방 · 부위 | 없음 |
| SellRequest | InventoryServer.server.lua:69 | 있음 | number · 확인값 signature 대조(84) · sellGrades 40자 · 허용 등급 · 개수 대조(PlayerProfile.lua:2338-) | 잠금 · 초월 · 착용품 제외 | 없음(attack_test 연타 100회 확인) |
| LockRequest | InventoryServer.server.lua:119 | 있음 | number · boolean · 토큰 | 태초 · 초월 해제 = 확인 토큰(PlayerProfile.lua:2747) | 토큰은 상수다(UI 이중 확인용이지 보안 장치가 아님 - 정보) |
| AwakenRequest | InventoryServer.server.lua:140 | 자체 0.5초 | kind 2종 · number/string · expectedNo 대조 | 본인 · 세계 번호 대조 · 골드 | 없음 |
| AutoProcessRequest | InventoryServer.server.lua:165 | 있음 | boolean · 등급 목록(PlayerProfile.lua:1840) | 본인 설정 | 없음 |
| BulkSellCutoffRequest | InventoryServer.server.lua:176 | 있음 | 문자열 · 상한 등급(PlayerProfile.lua:2464) | 본인 설정 | 없음 |
| InheritPreview (RF) | InventoryServer.server.lua:205 | 있음(invoke) | validShape(ItemInherit.lua) | 본인 | 없음 |
| InheritRequest | InventoryServer.server.lua:212 | 있음 | 부위 일치 · 잠금 · 초월 · keep(Inherit.lua:74-104) | 본인 | 없음 |
| SetInventoryWindowPosition | InventoryServer.server.lua:224 | 있음(20/s) | number · NaN 거부(PlayerProfile.lua:2501) | 본인 | inf는 통과하지만 저장 직전 sanitizeForSave가 0으로 바꾼다(SaveSystem.lua:1585-1598) |
| InventoryFetch (RF) | InventorySync.lua:110 | 있음(invoke) | 없음 | 본인 | 없음 |
| LaunchPermitRequest | LaunchPermit.lua:127(본문 96) | 자체(requestGap · 쿨) | `typeof Instance` · 등록된 발판만 | 서버 위치 기록 대조 | 없음 |
| LeaderboardRequest (RF) | Leaderboard.lua:894(본문 685) | 자체(동작별 간격) | 동작 · 보드 화이트리스트 | 본인 기록만 읽기 | `me`는 DataStore GetAsync + 재시도(본인 호출만 멈춤 · 서버 영향 없음) |
| MilestoneFetch (RF) | MilestoneNotice.lua:26 | 있음(invoke) | 없음 | 본인 | 없음 |
| ShopRequest | MonetizationService.lua:504(본문 429) | 있음(4/s · 통 8) | 동작 화이트리스트 · 인자 타입별 | 가격 서버 · 소유 · 시즌 canClaim · 선물 본인 우편함 | 없음 |
| AirMoveFx | MovementServer.server.lua:34 | 자체(종류별 + 초당 8) | KINDS 화이트리스트 | 근처 220 stud만 중계 | 없음 |
| PlayerGetup | MovementServer.server.lua:101(본문 75) | 자체(minGap) | 인자 없음 | 서버 강제 발사 기록 1회 소비 | 중계가 전 서버 대상(거리 무관)이지만 발사당 1회라 영향 작음(L5) |
| GlideState | MovementServer.server.lua:122 | 자체 0.15초 | `on == true` | 해금 · 서버 공중 | 없음 |
| LedgeClimb | MovementServer.server.lua:224(본문 190) | 자체 0.3초 | Vector3 · NaN · inf 거부(201-202) | 장갑 해금 · 서버 광선 | 거절마다 print(227) · 클라가 초당 약 3줄 유발 가능(L6) |
| PartyFriendsFetch (RF) | PartyServer.server.lua:83 | 자체(joinPoll 간격 · 약한 키 표) | 없음 | 본인 친구 | GetFriendsAsync 웹 호출(본인 호출만 멈춤) |
| PartyRequest | PartyServer.server.lua:121 | 있음 + 동작별 간격 | 동작 화이트리스트(118) · number/string | 리더만 kick(PartyState.lua:690) · 친구만 원격 초대 · 보스전 차단 | 없음 |
| PetRequest | PetService.lua:160 | 자체 0.2초(동작별) | 화이트리스트 · number | 본인 알 · at 대조(PlayerProfile.lua:2705-2714) | 없음 |
| InspectPlayer (RF) | PlayerInspect.lua:109(본문 77) | 자체(minInterval) | 정수 · NaN | 같은 서버 대상 공개 정보만 | 없음 |
| ProtectionTicketBuyRequest | ProtectionTicketServer.server.lua:26 | 있음 | ProtectionTickets.tryBuy가 바로 "discontinued" | - | 폐지된 기능(정리 후보) · 결과에 클라 kind를 그대로 되돌려 보냄(무해) |
| ProtectionTicketPriceRequest (RF) | ProtectionTicketServer.server.lua:40 | 있음(invoke) | 없음 | 본인 | 없음 |
| QuestRequest | QuestService.lua:378 | 있음 + 동작별 0.2초 | 화이트리스트 · 문자열 | 서버 facts · 견습 제외 · 알 가방 확인(QuestService.lua:281-310) | 없음 |
| LatencyEcho | RangedLagAssist.lua:22 | 자체(서버가 낸 토큰만) | number 토큰 | 본인 | 클라가 일부러 늦게 돌려주면 조준 보정 반경이 상한까지 커짐(L7) |
| RebirthRequest | RebirthServer.server.lua:25 | 자체 1초(약한 키 표) | 인자 없음 | RebirthAccess(위치 · 보스전 · 강화 중) | 없음 |
| SettingsSave | SettingsService.lua:108 | 자체(키별 0.1초 trailing) | 키 화이트리스트 · sanitize | 본인 | 요청마다 ImmediateSave.request(6초 스로틀이 막음) |
| SkillRequest | SkillServer.server.lua:777(본문 671) | 자체(스킬 쿨다운 724) | 슬롯 4종 · 영혼 · 사망 · 잡힘 | 서버 판정 | 사냥꾼의 덫이 aimPoint의 Y를 검사하지 않음(L8) |
| SkillInfoRequest (RF) | SkillStats.lua:172 | 자체 0.3초(약한 키 표) | 없음 | 본인 | 없음 |
| RedeemCode (RF) | SocialRewardService.lua:53 | 자체(3초 · 분당 8) | normalize · 코드 표 · 만료 | 계정당 1회(지급 전 표시) | 문서 R2(긴 문자열 처리 후 길이 검사) |
| SpectateRequest | SpectateService.server.lua:17 | 있음(20초 1번) | 문자열 8~64 · 이 서버 아님 | 보스전 거부 | 문서 R4 |
| StageMoveRequest | StageServer.server.lua:201(본문 51) | 자체(stageChangeCooldown) | number · NaN · floor · 범위 · 상한 | 최고 +1 · 보스 게이트 · 파티 리더 | 없음 |
| MenuTiming | Telemetry.lua:191(본문 168) | 자체(1회) | 표 · 0~600000 정수 | 본인 | 없음 |
| TravelRequest | Travel.lua:839 | 있음(+ 견습 바로 가기 별도 통) | kind 분기 · 체크포인트 id | 파티원만 · 발견한 체크포인트 · 보스전 · 전투 중 거부 | 없음 |
| TutorialChallengeBossRequest | TutorialState.lua:292(본문 187) | **없음** | 인자 없음 | 활성 견습 단계 · Attribute · 보스전 중 거부 | 연타 제한 없음. encounterOf 검사가 동기라 중복 스폰은 막힘(BossEncounter.lua:612) |
| WeeklyChallengeStart | WeeklyChallengeService.lua:63 | 있음(0.5/s) | 인자 없음 | entryBlocked | 문서 D2(규칙 결정 대기) |
| WeeklyChallengeTop (RF) | WeeklyChallengeService.lua:143 | 있음(invoke) + 공용 캐시 | 없음 | 본인 기록 | 없음 |

**Studio 전용(라이브에 없음):**
- `CosAuditFire` · `UiDevCommand` · `BossAnimPreview`: DevTools.server.lua:5139 · 3404 · 26. 첫 줄 가드(20) 뒤에 만들어진다.
- `P3aTelegraphAck`: P3aArenaVerify.lua:341. DevTools만 require한다(DevTools.server.lua:4450).
- `PerfProbe` 리스너: PerfProbe.lua:42. `assert(IsStudio)`(209 · 395)가 있다.

**InvokeClient는 쓰지 않는다**(grep 0건). 서버가 클라 응답을 기다리다 멈출 일이 없다.

**RemoteFunction 안의 yield:** LeaderboardRequest(`me` = GetAsync 재시도), PartyFriendsFetch(GetFriendsAsync), WeeklyChallengeTop(캐시 밖 DataStore)이 yield한다. 셋 다 요청한 클라의 호출만 기다리게 하고 서버 전체를 멈추지는 않는다.

---

## 3. 버그 표

| 심각도 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|
| **높음 H1** | ClassServer.server.lua:45-80 · CombatResolution.lua:147-148 · 199-211 · 300-341 · BossEncounter.lua:533-556 | ① 직업 A(최고 200)가 보스 스테이지 X(≤ 200)로 내려가 보스전을 시작한다(아래 이동은 자유 - StageServer.server.lua:69-75). ② 보스 HP가 거의 다 깎였을 때 `ClassSelectRequest("B")`를 보낸다(B = 레벨 1 · 진행 0). 서버는 직업 존재 여부 · RequestGate만 본다. ③ 막타를 B로 친다. 기여 표가 직업이 아니라 Player 기준(`contributions[member]` · CombatResolution.lua:311)이라 A가 넣은 피해가 B 몫으로 센다. | B가 **그 직업의 보스 X 첫 클리어 보상**을 받는다. 드랍 기준 = 보스 스테이지(`dropStage` · 148), 직업별 첫 클리어 표(199-211: 태초 · 초월 확률표, 그 직업 첫 보스면 확정 전설)가 적용된다. 파티 진입 밴드(BossEncounter.lua:530-531 주석 "캐리 = 리더보드 조작")를 직업 전환으로 건너뛴다. A가 X를 계속 다시 잡으며 B · C · D로 돌리면 직업마다 보스 스테이지별 첫 클리어 굴림을 미리 당겨 받는다. 복제는 아니다. 진행 기록(bestBossCleared)은 "다음 보스 스테이지"일 때만 오르므로(LeaderboardRules.evaluateClear) 대부분 안 오른다. 경험치 · 골드는 받는 직업의 스테이지 기준이라(147 · 165) 영향이 작다. | (가) ClassServer에서 `BossEncounter.getEncounter(player) ~= nil`(잔류 포함) · `SoulService.isSoul` · `PlayerState.isChanneling/isTrapped`이면 거부 + 결과 알림(추천 · 가장 작음). (나) 또는 보스 진입 순간 멤버별 classId를 encounter에 적어 두고, 보상 때 지금 classId가 다르면 제외한다. 하네스: attack_test에 "보스전 중 직업 전환 거부" 1줄 추가. | 30분 + 하네스 20분 |
| 중간 M1 | PlayerDamage.lua:93 · MonsterSpawner.lua:587 · CombatResolution.lua:258 · 265 · EnhanceService.lua:138 | 라이브 서버에서 플레이어가 맞을 때마다, 몹이 죽을 때마다, 드랍마다, 강화마다 print 1줄이 찍힌다. 30명 서버의 보스 장판 · 광역 사냥이면 초당 수십 ~ 수백 줄이다. | 서버 로그(개발자 콘솔)가 의미 있는 경고를 묻는다. 문자열 포맷 비용도 생긴다. 보안 구멍은 아니지만 운영 진단을 막는다. | data에 로그 단계 스위치(예: `DevToolsConfig`나 새 `LogConfig.verbose`, 기본 false)를 두고 위 줄들을 감싼다. IsStudio이면 켠다. | 1시간 |
| 중간 M2 | docs/design/security-audit-launch.md 3-1 · 5절 R5 | 문서는 입구 58개, 자체 제한은 "Codex · Quest · RedeemCode · SettingsSave 4개"라고 적었다. 실제는 61개이고 RequestGate 없이 자체 제한만 쓰거나 제한이 없는 입구가 29개다(위 표의 "자체" · "없음"). | 다음 감사 · 출시 체크리스트가 낡은 숫자를 믿게 된다. 버린 요청 탐지(`suspect_requests`, SuspicionMonitor.lua:63-68)는 RequestGate만 세므로 자체 제한 입구의 폭주는 탐지되지 않는다. | 문서 표 갱신 + 위 2절 표를 문서로 옮긴다. 탐지가 필요하면 자체 제한에서 버릴 때도 `SuspicionMonitor.noteGateDrop`을 부른다(선택). | 문서 30분 |
| 중간 M3 | tools/harness 전체 | 하네스가 다루는 입구: attack_test(Sell · Quest · Pet · Settings · Fall), request_gate_test(Lock · ClassSelect · Sell · Equip · BulkSell · InheritPreview), security_launch_test(RedeemCode · 초대 · Codex · CommunityGoal · Weekly · Travel · Spectate), ops_security_test(OpsRollback 순수 함수 · 차단 설정 · 탐지 기준). 잘못된 인자 시험이 없는 입구: AttackRequest · SkillRequest · DashRequest · ClassSelect(보스전 중) · LeaderboardRequest · PartyRequest 동작별 · EmoteRequest · BossLingerChoice · BossGiveUp · Gem 5종 · Awaken · Inherit · ShopRequest(monetize_test가 일부를 다룰 수 있음 - 확인 필요). 문서 R6은 옛 하네스가 시작 전에 멈춘다고 적었다(지금 고쳐졌는지 확인 필요 - 이번에 실행 안 함). | 회귀가 생겨도 하네스가 못 잡는다. 특히 H1 같은 상태 검사 누락. | attack_test에 "입구별 잘못된 인자 10종 + 상태(보스전 · 영혼 · 사망)" 표 구동 시험을 추가한다. | 2시간 |
| 낮음 L1 | AttackServer.server.lua:315 · 329 · 343 | 근접 직업이 NaN 성분 Vector3를 aimPoint로 보낸다. | AimPicker.pick(shared/AimPicker.lua:18-54)에서 direction이 NaN → dot 비교가 거짓 → 최근접 대상으로 대체된다. 피해 없음. | 원거리와 같은 NaN 검사를 분기 앞으로 옮긴다(일관성). | 5분 |
| 낮음 L2 | OpsServer.server.lua:173-201 | 운영자가 `/ops revoke <id> gold inf`를 입력한다. `amount ~= amount`는 NaN만 거른다. | takeGold(inf) 뒤 `%d` 포맷 에러 → pcall이 잡아 "error"로 보고된다. 실제 골드 변화는 확인 필요. 운영자만 가능하다. | `amount == math.huge` 거부 · 정수 상한 추가 | 5분 |
| 낮음 L3 | BossLinger.lua:178 · 182 · TutorialState.lua:292 · DropTableServer.server.lua:23 | 클라가 초당 수백 번 쏜다. | 각 핸들러가 상태 검사로 금방 끝나서 실해는 없다. SuspicionMonitor의 요청 폭주 탐지에서 빠진다. | `RequestGate.allow(player, "<이름>")` 한 줄씩 추가(기본 통) | 15분 |
| 낮음 L4 | OpsServer.server.lua:100-120 | 미리보기만 하고 confirm을 안 하면 `pendingConfirm` 항목이 남는다. | 서버 수명 동안 몇 개 쌓일 뿐이다(운영자만 만듦). | issueToken 때 만료 항목 청소 | 10분 |
| 낮음 L5 | MovementServer.server.lua:90-94 | 서버가 강제 발사를 건 뒤 클라가 PlayerGetup을 보낸다. | 거리와 무관하게 서버 전원에게 "getup" 모션이 중계된다. 발사 1건당 1회라 증폭은 없다. | AirMoveFx처럼 relayRangeStuds 안만 보내기 | 10분 |
| 낮음 L6 | MovementServer.server.lua:224-229 | 장갑 없는 클라가 LedgeClimb을 0.3초마다 보낸다. | 거절 print가 초당 약 3줄 찍힌다(로그 스팸). | 거절 로그를 사람당 초당 1줄로(SoulService.rejectAction 방식) 또는 M1 스위치 | 10분 |
| 낮음 L7 | RangedLagAssist.lua:22-35 | 클라가 LatencyEcho 응답을 일부러 늦게 보낸다. | 왕복 핑이 lagMaxSeconds 상한까지 부풀어 원거리 조준 보정 반경이 상한만큼 넓어진다. 판정 · 피해 · 사거리는 서버라 영향이 작다. | 표시만 하고 둔다(설계상 허용 범위). 필요하면 서버 GetNetworkPing 대조 | - |
| 낮음 L8 | SkillServer.server.lua:532 | 사냥꾼의 덫 aimPoint의 Y를 아주 크게(또는 inf) 보낸다. horizontalDistance만 검사한다. | 덫 파트가 지도 밖 높이에 생긴다. 발동 판정이 수평이면 층이 다른 대상에 걸릴 수 있다(확인 필요). | aimPoint.Y를 시전자 발 ± 허용치로 자르거나 지면 광선으로 내린다 | 15분 |
| 낮음 L9 | DevToolsConfig.allowedUserIds = {} (shared/data/DevToolsConfig.lua) | Studio "로컬 서버 + 여러 클라" 테스트 · Team Create에 들어온 아무나 `/gg`를 쓸 수 있다. | 라이브와는 무관하다(IsStudio). 공유 Studio 세션에서 남이 개발 계정 세션 메모리를 바꿀 수 있다. DevTools는 저장을 막지만(SaveCoordinator) 영향 범위는 확인 필요. | 지금대로 둔다(로컬 다중 클라는 음수 UserId라 목록을 넣으면 시험이 막힌다). 기록만. | - |

**정보(버그 아님, 확인한 것):**
- 운영 명령 권한은 `OpsConfig.userIds`(OpsServer.server.lua:40-42 · OpsConfig.lua:3)만 본다. 허용 밖 요청은 조용히 무시하고(490-493), 모든 시도를 `OpsLog_v1`에 기록한다(44-65). 대상 감사 기록도 남긴다(515-517). 되돌리기 · 영구 차단 · 초월 회수는 확인 번호가 필요하고, 그 번호는 발급한 운영자만 쓸 수 있으며 300초 뒤 만료된다(110-120). 채팅 명령의 신원은 `textSource.UserId`(서버 값)다.
- 약한 키(`__mode = "k"`) 표에 Player를 쓰는 곳이 28곳 있다(SaveCoordinator.lua:23-52 저장 잠금 포함 · ImmediateSave.lua:18-23 · RebirthServer:23 · PartyServer:80-95 · Travel.lua:36 · EnhancePolicy.lua:17 등). 프로젝트 주석 2곳(SuspicionMonitor.lua:11 · BossGate.lua:173)은 "약한 키 Player 항목이 조용히 사라졌다(M1-2c 실측)"고 적었다. 다만 `PlayerProfile.profiles`(PlayerProfile.lua:58)가 Player를 강한 키로 쥐고 있으므로, 접속 중에는 항목이 사라지지 않는 것으로 본다. 확인 필요: M1-2c 실측이 Player였는지 파트였는지. EnhancePolicy는 항목이 없으면 "제한됨"으로 처리해 안전하다(EnhancePolicy.lua:56).
- `RequestGate.invoke`는 넘친 요청에 그 인자의 마지막 결과를 돌려준다(RequestGate.lua:45-57). CommunityGoalClaim은 ok = true를 다시 보여줄 수 있지만 지급은 하지 않는다(문서 R3).

---

## 4. 출시 빌드에 남으면 안 되는 것 · 확인 목록

| 항목 | 위치 | 상태 | 조치 |
|---|---|---|---|
| 개발 명령 `/gg` | DevTools.server.lua:20 | **라이브에서 꺼짐 확인**: IsStudio 가드가 TextChatCommand(3384-3393) · Remote(26 · 3404 · 5137) 생성보다 앞에 있다 | 없음 |
| 개발 명령 UserId 우회 | DevToolsConfig.allowedUserIds = {} · DevTools.server.lua:126-136 | 하드코딩 없음 | 없음 |
| 운영 계정 하드코딩 | OpsConfig.lua:3 `userIds = { 11595243049 }`(HoddyForge) | 의도된 라이브 권한. 서버 전용(ServerScriptService - 클라에 복제 안 됨) | 이 계정에 2단계 인증 필수 · 계정이 털리면 ban · rollback · gift 전부 가능 → 운영자를 늘릴 때 그룹 랭크 방식 검토(결정 필요). Studio에서도 `/ops`가 실제 DataStore를 고친다(restore · rollback = opsWriteProfile) - 운영 절차서에 적어 둘 것 |
| Studio 검증 훅(BindableFunction) | AttackServer:641 · DashServer:118 · MovementServer:102 · 211 · OpsServer:537 · StageServer:236 | 전부 IsStudio 가드 + ServerStorage(클라 접근 불가) | 없음 |
| 가드 없는 훅 | StageServer.server.lua:221-230 `AutoStageMoveHook` | 라이브 AutoStage가 쓰는 정식 경로 · ServerStorage | 없음(이름만 "Hook") |
| 강화 결과 주입 | EnhanceService.lua:120 `debugRolls` | IsStudio 가드 | 없음 |
| 검증 저장 키 `_verify` | DevToolsConfig.lua:177-178 | IsStudio 가드 | 없음 |
| 메뉴 건너뛰기 | client/MainMenu.client.lua:825 `DevSkipMainMenu` | 클라 전용 · ReplicatedStorage Attribute(서버만 씀) | 없음 |
| DevToolsConfig가 클라에 복제됨 | shared/data/DevToolsConfig.lua(약 36KB) | 검증 목록 · 스위치가 클라에서 보인다. 비밀 값은 없음 | 정보(낮음) |
| TEMP 값 - 임시 안전 상한 | InfiniteStageConfig.lua:49 `safeStageCap = 34230` · :59 `hardMaxStage = 25300` | 임시 상한이 하드 상한보다 커서 사실상 죽은 값 | 출시 전 하나로 정리할지 결정(삭제 아님 - 값 확인만) |
| TEMP 값 - 상품 id | MonetizationData.lua:23-34 `productId = 0`(스타터 · 테마 · 글라이더 · 시즌 유료 줄 전부) | validProducts가 거르는 것으로 보임(확인 필요) | 출시 전 실제 상품 id 입력 |
| TEMP 값 - 시즌 시작일 | LeaderboardConfig.lua:16 `seasonStartUnix = 0` · :22 `firstSeasonDateKst = nil` | 서버 시작 때 경고(MonetizationService.lua:491-493). 시즌 패스가 한 시즌에 멈춘다 | 출시 체크리스트 P6 |
| 폐지 코드 | ProtectionTickets.lua:44 `if true then return false, "discontinued" end` | 아래 줄은 죽은 코드 | 정리 후보(5절) |
| 임시 모델 | HuntingGround.server.lua:52 · 116 · WorldConfig.lua:241 · 252 (환생 제단 · 보석상인 "모델은 임시") | 보안 무관 | 아트 일정 |
| 디버그 print | 라이브 서버 경로 print 약 237줄(Verify · DevTools · EconSim · PerfProbe 제외). 많은 파일: BossEncounter 16 · BossPatterns 14 · PartyState 13 · PartyCrossServer 12 · CombatResolution 8 | 잦은 것: PlayerDamage.lua:93(피격마다) · MonsterSpawner.lua:587(몹 사망마다) · CombatResolution.lua:258 · 265(드랍마다) · EnhanceService.lua:138(강화마다) · MovementServer.lua:227(거절 · 클라 유발) · BossGate.lua:183(토벌 요청마다) · InventoryServer.lua:110 · GemServer.lua:93 | M1 로그 스위치 |
| 검증 모듈 | server/*Verify.lua 71개 | 라이브에서 require되지 않음(DevTools만 부른다 - grep 확인) · 서버 전용이라 클라 노출 없음 | 그대로 둔다(파일 삭제 금지 원칙) |

---

## 5. 정리 후보 (삭제 제안 아님 - 저장 필드 · 데이터 id · 에셋 · DataStore는 손대지 않는다)

1. **자체 제한을 RequestGate로 모으기**: 29개 입구가 각자 간격 표를 들고 있다(위 표 "자체" · "없음"). `RequestLimitConfig.remotes`에 키를 추가해 한 입구로 모으면 수치는 data/ 한 곳에 있고, 버린 요청 탐지도 일관된다. 동작은 그대로 둔다.
2. **약한 키 표 통일**: Player 키 표를 SuspicionMonitor처럼 "강한 표 + PlayerRemoving 정리"로 맞춘다. 대상: PartyServer:80-95 · RebirthServer:23 · SkillStats:171 · PlayerInspect:29(퇴장 정리 없음) · ImmediateSave · SaveCoordinator. 지금 버그는 아니다(3절 정보). 프로젝트 안에 두 방식이 섞여 있어 다음 사람이 헷갈린다.
3. **방지권 Remote 2개**(ProtectionTicketBuyRequest · PriceRequest): 옛 클라 호환으로 남아 있다. 지울 필요는 없다. 결과에 클라가 보낸 `kind`를 되돌리는 대신 서버 상수를 보내도록 바꿀 수 있다.
4. **로그 단계 스위치**(M1): 출시 전에 하나 만들어 잦은 print를 감싼다.
5. **문서 갱신**: security-audit-launch.md 3-1(입구 수) · 5절 R5(자체 제한 목록) · R6(하네스 상태)를 이 표 기준으로 갱신한다.
6. **Ops 확인 번호 표 청소**(L4) · revokeCurrency inf 거부(L2).

---

## 부록: 읽은 하네스 · 문서

- `tools/harness/attack_test.luau`(97줄): 판매 잘못된 인자 11종 · 연타 100회 · 확인값 위조 · 퀘스트 6종 · 펫 7종 · 설정 3종 · 낙하 server 표시 위조.
- `request_gate_test.luau`(75줄): 통 크기 · 사람별 · Remote별 · 충전 · RF 넘침 = 마지막 결과.
- `security_launch_test.luau`(454줄): RedeemCode · 초대 · Codex · CommunityGoal · Weekly · Travel · Spectate.
- `ops_security_test.luau`(145줄): 버전 고르기 · 시각 파싱 · 덮은 저장 · 차단 설정 · 확인 번호 대상 · 탐지 기준(정상 플레이 = 기록 0).
- 이번 감사에서는 하네스를 **실행하지 않았다**(읽기 전용).
- `docs/design/security-audit-launch.md`(132줄) · `docs/phase/security-runbook.md`(57줄): 운영 권한 = OpsConfig.userIds(runbook:3 · 48)로 코드와 일치한다. 입구 수 · 자체 제한 목록은 낡았다(M2).
