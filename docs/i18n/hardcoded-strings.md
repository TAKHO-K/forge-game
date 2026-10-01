# 하드코딩 문자열 전수 목록 (QUEUE-10h Q15 · 2026-09-29 → QUEUE-ALL4 E 갱신 · 2026-10-01)

> 검색 = 스크래치 `scan_ko.py`(roblox/src의 .lua에서 한글이 든 문자열 리터럴 · 주석 · print/warn/error/reply 로그 · 검증 · DevTools · TextData* 제외 - 자체 점검 함수(selfTest · selfCheck) 안의 줄은 이 검색이 못 거른다).
> **QUEUE-ALL4 E 전: 합계 2,301개 · 208파일 → 후: 1,425개 · 140파일(약 876개 옮김 · 새 키 744개).** 남은 1,425 = 데이터 파일(shared/data) 617 · client 373 · server 228 · shared 203 · first 4.

## 언어 구조 (QUEUE-ALL4 E)
- 문장 = `shared/data/TextData.lua`(ko 본문 631) + `TextData_en.lua`(그 631의 en) + 화면별 분할 7개(`TextData_hud` · `_scene` · `_inv` · `_forge` · `_panels` · `_shared` · `_server` = 각 `{ ko, en }` 짝 · 접두사 `hud.` `scene.` `gear.` `forge.` `ui.` `desc.` `srv.`). 합계 ko 1,374 = en 1,374.
- `shared/Text.get(key, args)` = 클라는 설정 `language`(SettingsData - 기본 "ko" · "en" · "auto") · 서버는 ko. 서버가 한 사람에게 보내는 문장 = `Text.getFor(player, key, args)`. en에 없는 키 = ko 대체 + 경고 1회.
- 짝 검사 = `python roblox/tools/i18n/check_textdata.py`(ko만 · en만 · 겹침 · {자리} 다름 · 코드에 쓴 없는 키 = 0이어야 통과).

## 남은 것 - 화면에 나오는데 아직 안 옮긴 것(다음 작업)
| 무엇 | 위치 | 왜 남았나 |
|---|---|---|
| 귀환 · 이동 알림 37 · 토벌 거절 사유 표 | `server/Travel.lua` · `server/BossGate.lua` `raidReasonText`(Travel 740줄이 표 값을 그대로 보냄) | 작업 시각에 다른 작업자(보안)가 Travel 수정 중 - 건너뜀 |
| 관전 알림 5 · 주간 도전 2 | `server/SpectateService.server.lua` · `server/WeeklyChallengeService.lua` | 같은 이유(다른 작업자 수정 중) |
| 로드 실패 킥 문장 | `server/SaveServer.server.lua` 30줄 | 저장 감사 작업자 파일 |
| 로딩 팁 4 | `first/LoadingTips.lua` | ReplicatedFirst - Shared보다 먼저 떠서 Text를 못 부른다(언어 Attribute도 아직 없음) |
| 선물 보낸 이 "운영" · "친구 초대" | `server/GiftService.lua` · `server/SocialRewardService.lua` | 선물 기록 `from`에 **저장**되는 글 - 바꾸려면 저장 구조 변경(결정 필요) |
| 방송 문장(모두에게 같은 글) | 보물상자 등장 · 소멸 · 열림(`MonsterSpawner` · `CombatResolution` FireAllClients) · 관문 · 상점 · 강화대 ProximityPrompt(`BossGate` · `HuntingGround` · `EnhanceStation`) · 명예의 전당 판(`HallOfFame`) · 정거장 · 전망대 명판(`WorldMapLayout` → 서버 WorldMap 빌보드) | 키는 만들었지만 서버가 ko로 완성해 보낸다 - 키 + 인자로 보내고 클라가 Text.get 하도록 프로토콜 변경 필요 |
| 데이터 표시 이름 617 | `shared/data/*`(BossData 99 · WorldMapData 85 · QuestData · CodexData · EggData · SkillData 이름 · ArmorData 등급 이름 · DropNoticeData " 외 %d" · CodexData.text 템플릿 등) | 범위가 커서 보고만 - 데이터에 `nameKey` 칸 + TextData 키 방식(값은 지금처럼 ko 원문 유지). en 화면에서도 `{grade}` · `{part}` · `{boss}` 자리에 한국어 이름이 들어간다 |
| 자체 점검 · 검증 줄 | `DropFeed` 63 · `StageRewardBand` 41 · `SystemToasts` 28 · `UiGallery/*` · `RuleCheck` · `A1UiMockups` · `ScreenMap`(슬롯 설명) · `InputDiag` · `*Check` · `*Sim` · `MeshImport*` 등 | 플레이어 화면 아님 - 옮기지 않음 |
| 한국어 비교 자체 점검 | `client/hud/DropFeed.client.lua` 356줄("서버를 떠난 플레이어") · `client/P3bUiCheck.client.lua` 123 · 138줄("불러오는 중…") | ko에서는 통과 · en으로 켜면 점검이 실패한다(점검 쪽을 키 비교로 바꿔야 함) |
| 로드 때 한 번 정해지는 글 | `PanelRegistry.menuLabel` · `UIManager.blockedTexts` · StageSelect `blockedText` · 창 제목 · `Store.SORT_LABELS` · `OddsView ROWS` · `Inherit STAT_ROWS` · `PartyAway.reconnectTitle` · MenuBar 더보기 · 상점 · `WorldMapLayout.stations()` 캐시 | 접속 중 언어를 바꾸면 재접속해야 바뀐다(언어 Attribute가 늦게 오면 ko로 굳을 수 있음 - 영어 켜기 전 확인) |

## 옮긴 것 (QUEUE-ALL4 E - 파일 · 키)
- HUD(`hud.` 63): DropFeed · StageRewardBand · SystemToasts · PartyRequests · PartyListView · PartyAway · RequestBanner · MenuBar · UltGauge · SkillTooltip(줄 고르기를 한국어 줄 머리 → 줄 id로 바꿈).
- 장면(`scene.` 89): WorldClient · PrimordialFx · Boss*View 7 · ZoneBoundaryWarning · TutorialHud · StageUI · MilestoneToast · AutoWalk · DamageNumbers · SkillSlots · EnhanceAnnounceClient · BossGateMarks · FallFx · CommunityGoalView · UpdateBoard · MapPins · QuestGuide.
- 가방(`gear.` 75): panels/Inventory/* 13파일 · InventoryUI.
- 강화 · 보석 · 계승(`forge.` 149): Inherit · GemForge · GemWorkshop/* · Enhance/*.
- 창(`ui.` 172): Party · Leaderboard · Milestones · Inspect · StageSelectPanel · PlayerMenu · Probability · Quests · UIManager · kit/Confirm · ClassSelectUI · PanelRegistry · RewardIcons.
- shared 문장(`desc.` 127): SkillTooltipText · EquipCompare · ItemDescribe · PrimordialStamp · Awaken · Milestone · WorldMapLayout(명판 3).
- 서버(`srv.` 69): PartyCrossServer · PartyServer · PartyState · BossGate · StageServer · PartyVote · CombatResolution · MonsterSpawner · QuestService · CodexService · TutorialState · HallOfFame · HuntingGround.
- 이유 코드 → 문장 표는 **키 표**로 바꿨다(`REASON_KEY` 류) - 표시하는 순간의 언어를 따른다.

## 용어집에 더할 후보(번역 작업자가 정한 것 - 확정 필요)
분해 = Salvage · 변환권 = Reroll Ticket · 리롤 = Reroll · 불씨 = Ember · 홈 = Socket · 기믹 = Mechanics · 원격 입장 = Teleport · 세트 축(위력 Might · 신속 Haste · 방어 Guard · 성장 Growth · 재생 Regen · 건강 Vitality) · 펫 등급(일반 · 고급 · 희귀 · 영웅 = Common · Good · Rare · Epic - 알 등급 Good과 겹침).

## 사용자 할 일(Creator Hub)
- 게임 설정 → Localization → **자동 번역(Automatic Translation) 켜기** · 원문 언어 = 한국어 · 대상 언어(영어 먼저).
- "텍스트 자동 수집(Capture text)" 켜기 → 번역 표에서 용어집(glossary.md) 단어를 먼저 고정 번역으로 등록.
- 코드 쪽 en(TextData en)을 쓰면 키로 옮긴 문장은 자동 번역을 거치지 않는다 - 데이터 이름 · 방송 문장처럼 남은 ko는 자동 번역이 받는다.

## 파일별 남은 목록 (QUEUE-ALL4 E 뒤 재검색)
| 파일 | 한글 문자열 | 예(줄: 글) |
|---|---|---|
| `shared/data/BossData.lua` | 99 | 440: 강공격 · 453: 느림 · 느림(공중) · 빠름 |
| `shared/data/WorldMapData.lua` | 85 | 59: 큰 나무 마을 · 70: 대장간 거리 |
| `client/panels/UiGallery/Sections.lua` | 68 | 32: 버튼 - 종류 3 × 상태 4 · 33: 주 |
| `client/hud/DropFeed.client.lua` | 63 | 155: 유물러 · 170: 고대러 |
| `client/A1UiMockups.lua` | 52 | 146: A1 목업 ① HUD 버튼(가방 B · 성장 M · 지도 N) - · 147: 가방 |
| `shared/data/QuestData.lua` | 43 | 9: 몬스터 {n}마리 처치 · 10: 보스 {n}번 처치 |
| `client/StageRewardBand.lua` | 41 | 484: 방지권 표시 45 / 50 / 75 / 100 = 없음 / 하락  · 485: 방지권 |
| `shared/data/CodexData.lua` | 39 | 26: 첫 만남 · 27: 10마리 |
| `shared/BossSkillMath.lua` | 38 | 53: 무작위  · 53: 박  |
| `server/Travel.lua` | 37 | 430: 체크포인트  · 443: 허브 귀환 |
| `shared/data/EggData.lua` | 37 | 9: 석조 평원 알 · 10: 수정 동굴 알 |
| `client/ui/ScreenMap.lua` | 34 | 43: 로블록스 채팅창 - 손대지 않는다 · 44: 시스템 토스트 줄(저장 · 레벨업 · 구역 차단 · 보물상자 -  |
| `shared/MeshImportCheck.lua` | 33 | 238: 규격 · 모델 · 238: 리그 id %s 없음 또는 기술자 아님 |
| `shared/data/MonsterCodexData.lua` | 32 | 12: 첫 만남 · 13: 10마리 처치 |
| `server/PartyCrossServer.lua` | 31 | 158: 레코드 갱신 · 219: 레코드 삭제 |
| `client/panels/UiGallery/RuleCheck.lua` | 29 | 66: ① window(전시장) 열림: 스택 %s · DisplayOrd · 73: ② 전시장을 연 채 가방 열기: 스택 %s(기대 [inventor |
| `client/hud/SystemToasts.client.lua` | 28 | 92: %s %s 획득 (Lv.%d) · 94: 저장에 반복 실패했습니다. 지금까지의 변경사항이 저장되지 않았을  |
| `server/C1Sim.lua` | 28 | 565: 주의 · 590: 강한 계정 스테이지 1 → 높은 몹 대신 깎기(받는 사람 B) |
| `shared/WorldCheck.lua` | 27 | 33: %s 길 %.0f · 33: 본 |
| `shared/WorldMapLayout.lua` | 27 | 393: 1단 · 394: 공중1 |
| `shared/data/SkillIconData.lua` | 20 | 22: 앞으로 돌진하며 길 위의 적을 모두 베요 · 22: 제자리에서 돌며 주변 적을 여러 번 베요 |
| `server/Leaderboard.lua` | 19 | 110: 쓰기 %s/%s · 126: 쓰기 %s/%s |
| `shared/data/MonsterSpeciesData.lua` | 19 | 20: 이끼 슬라임 · 23: 바위 멧돼지 |
| `client/InputDiag.client.lua` | 15 | 28: %s(우선순위 %s · 스택 %s) · 33: 없음 |
| `shared/Monetization.lua` | 15 | 29: 종류 없음 · 33: 판매 금지: %s(%s) |
| `shared/data/TrainingData.lua` | 15 | 12: 공격 수련 · 13: 체력 수련 |
| `shared/data/TitleData.lua` | 14 | 10: 태초의 선택 · 11: 드랍 태초 장비(세계 번호가 붙는 태초)를 처음 얻는다 - 태초  |
| `shared/data/SocialRewardData.lua` | 13 | 13: 친구 초대로 왔어요! 환영 보상 · 13: 초대한 친구가 처음 왔어요! 보상 |
| `shared/data/CommunityGoalData.lua` | 12 | 22: 강화석 40 · 23: 알 1 |
| `shared/data/GemData.lua` | 12 | 50: 연속격 · 50: 속사의 흔적 |
| `shared/data/SkillData.lua` | 12 | 17: 관통돌진 · 46: 회전베기 |
| `shared/BossJumpCourseMath.lua` | 11 | 16: 1단 · 17: 공중 1 |
| `shared/WeaponRigCheck.lua` | 10 | 75: 규격 없음 또는 모델 아님 · 80: Model이면 PrimaryPart(강화 이펙트 · 발사 자리가  |
| `shared/data/MonetizationData.lua` | 10 | 9: 골드 · 9: 장비 |
| `shared/data/MovementConfig.lua` | 10 | 111: 걷기(이속 상한 24) · 111: 대시 · 공중 대시 · 태초 2단 대시(서버 대시 허가) |
| `shared/data/StageGenerationData.lua` | 10 | 10: 잿빛 · 10: 잿빛 |
| `shared/data/WeeklyChallengeData.lua` | 10 | 11: 분신 2배 · 12: 번개 2배 |
| `shared/data/BossArenaMapData.lua` | 9 | 66: 구조물 파편 · 115: 솟는 바위 |
| `shared/data/CosmeticSlotData.lua` | 9 | 11: (없음 - D1-3에서 태초 발자국 삭제) · 19: 별빛 |
| `server/BossMechanics.lua` | 8 | 116: 성공 · 116: 실패 |
| `server/ZoneTerrain.lua` | 8 | 503: 경사 45° 초과 · 504: 단차 2 초과(절벽) |
| `shared/MeshSwap.lua` | 8 | 54: [MeshSwap] 리그 %s 규격 또는 루트 없음 X · 78: [MeshSwap] 메타 정렬: 파트 %d · 가장 큰 어긋남 % |
| `shared/data/ArmorData.lua` | 8 | 89: 일반 · 96: 희귀 |
| `shared/data/OptionData.lua` | 8 | 55: 위력 · 56: 신속 |
| `shared/data/TerrainGenData.lua` | 8 | 95: 수호자 봉 · 107: 수정 왕관 봉 |
| `shared/data/TutorialData.lua` | 8 | 63: 이동(WASD/조이스틱)과 클릭·탭 공격을 배워보세요. 슬라임을  · 65: 친구가 있다면 지금 불러도 됩니다 - 레벨이 달라도 같은 슬라임을 |
| `client/panels/Enhance/init.lua` | 7 | 203: 모바일 · 204: 스크롤됨 |
| `shared/BossDifficultySim.lua` | 7 | 259: 환경 · 335:  오답 |
| `shared/data/TranscendentData.lua` | 7 | 27: 환영 · 27: 광폭 |
| `client/panels/UiGallery/init.lua` | 6 | 43: station은 비모달이다 - 열린 채로 걸을 수 있다. wind · 56: UI 전시장 |
| `server/BossPatterns.lua` | 6 | 225: 넉백 · 767: 보스 발사(%s%s) |
| `shared/data/ClassData.lua` | 6 | 30: 성기사 · 30: 뿅망치 |
| `shared/data/MonsterData.lua` | 6 | 120: 슬라임 · 121: 고블린 |
| `client/UIManager.lua` | 5 | 450: UIManager: gameProcessedEvent=true라  · 466: canOpen 없음 |
| `client/panels/Inventory/DetailSheet.lua` | 5 | 334: 보석 · 345: 판매 |
| `server/AcquisitionAudit.lua` | 5 | 254: 태초 %s(번호 %s · %s) · 310: 태초 %d개 · λ %.3g · P(X ≥ %d) = %.3g < |
| `server/CombatResolution.lua` | 5 | 251: 보스 · 251: 반짝이 |
| `server/SpectateService.server.lua` | 5 | 22: 잠시 뒤에 다시 · 26: 보스전 중에는 갈 수 없어요 |
| `shared/BossRules.lua` | 5 | 133: %d번째 바퀴: 알 수 없는 보스 id %s · 135: %d번째 바퀴: %s 중복 |
| `shared/MotionTiming.lua` | 5 | 97: 1타 · 97: 2타 |
| `shared/TrailSkin.lua` | 5 | 25: core · edge 색 없음 · 30: 허용 안 된 칸 %s(스킨은 색 · 질감 · 파티클만) |
| `shared/data/A1PrototypeData.lua` | 5 | 19: 달림 · 20: 몸 낮춤 |
| `shared/data/MilestoneData.lua` | 5 | 20: 가방 칸 +5 · 21: 계승 비용 -10% |
| `first/LoadingTips.lua` | 4 | 4: 레벨이 달라도 괜찮아요. 같이 때리면 전원이 자기 기준의 보상을  · 5: 보상은 나눠 갖지 않습니다. 옆에 친구가 있으면 그냥 더 빠릅니다 |
| `server/BossGate.lua` | 4 | 162: 토벌 - 보스를 한 번 이상 클리어하면 열립니다 · 163: 토벌 - 아직 깨지 않은 보스 스테이지에서는 토벌할 수 없습니다 |
| `server/OpsServer.server.lua` | 4 | 139: none(이 서버 기록) · 156: failed: 저장소 읽기 |
| `server/TerrainBake.lua` | 4 | 339: %s(버전 %s/%s · 서명 %s/%s) · 387: 점 %d 옆 %s |
| `server/TrailSkinService.lua` | 4 | 29: 없는 스킨 · 33: 금지 검사 X:  |
| `shared/data/AutoStageData.lua` | 4 | 7: 편함 · 8: 보통 |
| `shared/data/BossJumpMapData.lua` | 4 | 30: 나선 계단 · 44: 지그재그 탑 |
| `shared/data/ItemVisualData.lua` | 4 | 109: 갑옷 · 110: 장갑 |
| `shared/data/SkillVariantData.lua` | 4 | 10: 넓게 · 11: 재빠르게 |
| `shared/data/UltimateData.lua` | 4 | 22: 파괴의 화신 · 28: 천궁의 폭우 |
| `shared/data/WorldConfig.lua` | 4 | 248: 환생의 제단 · 249: 환생 |
| `client/panels/Inventory/Shell.lua` | 3 | 406: 장비 · 408: 가방 |
| `client/ui/FeedLayout.lua` | 3 | 72: 터치  · 77: 중앙 금지 구역 |
| `server/BossAirGrab.lua` | 3 | 391: 아무도 안 걸림 · 410: 전원 탈출 |
| `server/BossArenaMap.lua` | 3 | 582: 파편 튕김 · 1200: 구조물 |
| `server/BossEnvironment.lua` | 3 | 342:  - 낙사 · 352: 무너진 조각 가장자리 |
| `server/CosmeticService.lua` | 3 | 161: 나무 정거장  · 167: 비밀 둥지 도감  |
| `server/SaveCoordinator.lua` | 3 | 128: 없음 · 131: 다른 서버에 더 최근 저장이 있어 지금 상태는 저장하지 않았습니다 |
| `shared/CodexRules.lua` | 3 | 32: 도감 줄 완성 · 101: %s · %d번 |
| `shared/EquipCompare.lua` | 3 | 123: 옵션 · 124: 옵션 |
| `shared/data/MonsterPrefixData.lua` | 3 | 35: 연약한 · 43: 단단한 |
| `shared/data/PartyConfig.lua` | 3 | 123: 누구나 · 123: 딜러 |
| `shared/data/PetData.lua` | 3 | 34: 강아지 · 34: 고양이 |
| `shared/data/RiftData.lua` | 3 | 31: 균열이 열렸다! 20분 동안 골드 · 전설 · 유물 · 고대 확률 · 31: 균열이 닫혔다 |
| `client/Wayfinder.lua` | 2 | 466:  관문 · 480: 검사 |
| `client/WeaponVisual.lua` | 2 | 1712: 없음 · 1738: 없음 |
| `client/panels/Inventory/ItemConfirm.lua` | 2 | 113: 판매 · 114: 판매 |
| `server/AttackServer.server.lua` | 2 | 159: 구역 안으로 들어가야 공격할 수 있습니다 · 200: 공격 |
| `server/BossArenaContainment.lua` | 2 | 118: 스폰 자리 · 118: 안전 지점(스폰 자리가 막힘) |
| `server/BossEncounter.lua` | 2 | 550: band(권장 %d+%d) · 589: 파티가 보스전에 들어갔습니다 |
| `server/BossGimmicks.lua` | 2 | 111: 감전 구출 · 137: 얼음 |
| `server/BossJumpCourse.lua` | 2 | 110: 수정 · 193: 수정 부수기  |
| `server/BossLightningRods.lua` | 2 | 162: 번개 · 189: 방전 번개 |
| `server/EnhanceService.lua` | 2 | 143: , 방지권  · 143:  소모 |
| `server/FallServer.lua` | 2 | 51: 낙하 쓰러짐 → 마지막 안전 지점 · 141: 낙하 %.0f |
| `server/HeightGuard.lua` | 2 | 447: (공중 정체 %.1f초) · 448: 없음 |
| `server/MonetizationService.lua` | 2 | 70: (이미 있음) · 76: 시즌 유료 줄 |
| `server/MonsterSpawner.lua` | 2 | 278: 보물상자 · 492: 보물상자 |
| `server/SkillServer.server.lua` | 2 | 630: 구원의 기도 · 673: 스킬  |
| `server/SoulService.lua` | 2 | 94: 성역 · 100: 성역 |
| `server/WeeklyChallengeService.lua` | 2 | 58: 지금은 시작할 수 없어요 · 64: 지금은 시작할 수 없어요 |
| `shared/CartoonStyle.lua` | 2 | 182: (없음) · 222: (없음) |
| `shared/RoadNet.lua` | 2 | 409: 캠프 · 관문 → · 418: 관문 ↑ · 전망 ↗ |
| `shared/data/EnhanceConfig.lua` | 2 | 79: 하락 방지권 · 80: 초기화 방지권 |
| `shared/data/EnhanceMaterialData.lua` | 2 | 14: 강화석 · 15: 상급 강화석 |
| `shared/data/NestData.lua` | 2 | 142: 둥지 탐험가 · 142: 비밀 수집가 |
| `client/A2M1Probe.client.lua` | 1 | 92: 대상 없음:  |
| `client/DropLookV2.lua` | 1 | 35: %s*사냥터$ |
| `client/SkillSlots.client.lua` | 1 | 561: JUMP\n(모의) |
| `client/StageSelectPanel.lua` | 1 | 747: S11(가) |
| `client/hud/PartyList.client.lua` | 1 | 64:  (더미) |
| `client/hud/RequestBanner.lua` | 1 | 70: 가 |
| `client/panels/Enhance/Controller.lua` | 1 | 82: 일반 |
| `client/panels/Inventory/GemTab.lua` | 1 | 550: 보석 |
| `server/AlphaStats.lua` | 1 | 38: 끌어오기 %d회 · 합 %.1f초 · 평균 %.2f초 · 약하게  |
| `server/BossColorMatch.lua` | 1 | 110:  - 공동 책임 |
| `server/BossOrgel.lua` | 1 | 48: 수정 종  |
| `server/BossSandSearch.lua` | 1 | 67: 모래 둔덕 |
| `server/BossTrap.lua` | 1 | 282: 구출 |
| `server/EnhanceStation.server.lua` | 1 | 45: 강화대 |
| `server/GiftService.lua` | 1 | 36: 운영 |
| `server/HealCast.lua` | 1 | 110: 치유 버프 |
| `server/HuntingGround.server.lua` | 1 | 224: %s %d(장식 %d) |
| `server/MeshImportDev.lua` | 1 | 17: /gg mesh check <리그id> [모델경로] / swap  |
| `server/MonsterAI.server.lua` | 1 | 293: 잡몹 넉백 |
| `server/NestServer.lua` | 1 | 252:  · 비밀 둥지 발견  |
| `server/PartyState.lua` | 1 | 726: 더미%d |
| `server/PlayerDamage.lua` | 1 | 92:  (쉴드 흡수 %.2f) |
| `server/SaveServer.server.lua` | 1 | 48: 저장 데이터를 불러오지 못했습니다. 이번 접속에서의 변경사항은 저 |
| `server/SocialRewardService.lua` | 1 | 144: 친구 초대 |
| `server/WorldHazards.lua` | 1 | 142: 선인장 |
| `shared/MoveRules.lua` | 1 | 194: HeightGuard 허가(source = ledge) |
| `shared/PrimordialStamp.lua` | 1 | 75: 최초 획득  |
| `shared/data/DropNoticeData.lua` | 1 | 25:  외 %d |
| `shared/data/PrimordialData.lua` | 1 | 17: 모험가 |
| `shared/data/SetData.lua` | 1 | 14:  세트 |
| `shared/data/WeaponData.lua` | 1 | 23: 기본 무기 |
