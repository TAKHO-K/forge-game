# 하드코딩 문자열 전수 목록 (QUEUE-10h Q15 · 2026-09-29)

> 검색 = 스크래치 `scan_ko.py`(roblox/src의 .lua에서 한글이 든 문자열 리터럴 · 주석 · print/warn/error/reply 로그 · 검증 · DevTools · TextData 제외). **합계 2,073개 · 178파일 · 데이터 파일(shared/data) 472 · 서식 자리(% 또는 {})가 있는 동적 문자열 454.**

## 옮기는 순서(추천)
1. **동적 문자열 454**(`("%s 강화"):format(...)` 꼴) - Roblox 자동 번역은 화면에 뜬 글을 통째로 모으므로 숫자 · 이름이 바뀔 때마다 새 글로 잡혀 번역이 안 붙는다 → TextData 키 + `{자리}`로(`Text.get`은 이미 `{name}` 치환을 한다).
2. 창 · HUD 고정 글(버튼 · 제목) - 자동 번역이 잡지만 용어집과 어긋나기 쉽다 → 키로.
3. 데이터 표시 이름(보스 · 지역 · 스킬 · 옵션 이름 472) - 데이터에 `nameKey` 칸을 두고 TextData로(값 자체는 지금처럼 한국어 원문 유지 - 번역 표의 원문).
4. 이미 옮긴 것: Q7 이후 새 창(퀘스트 · 알 · 펫 · 확률 · 설정 · 이정표 · 출석) 전부 `TextData` · 이번 Q15에서 스킬 변형 줄(`variant.*`) 옮김.

## 이미지 속 글자 · 동적 문자열
- 이미지 속 글자: 없음(규칙 - UI 도형 · 아이콘만 · MoveUnlockPopup도 도형 그림). 아트 납품 규칙에 "그림에 글자 금지" 유지.
- 동적 문자열 대표: 드랍 피드(`client/hud/DropFeed` 65) · 보상 띠(`client/StageRewardBand` 66) · 스킬 툴팁(`shared/SkillTooltipText` 124 - 수치 조합) · 파티 교차 서버(`server/PartyCrossServer` 52 - 서버가 만든 알림 글).

## 사용자 할 일(Creator Hub)
- 게임 설정 → Localization → **자동 번역(Automatic Translation) 켜기** · 원문 언어 = 한국어 · 대상 언어(영어 먼저).
- "텍스트 자동 수집(Capture text)" 켜기 → 번역 표에서 용어집(glossary.md) 단어를 먼저 고정 번역으로 등록.

## 파일별 목록
| 파일 | 한글 문자열 | 예(줄: 글) |
|---|---|---|
| `shared/SkillTooltipText.lua` | 124 | 31: 초 · 35: 즉발 · 돌진 |
| `shared/data/BossData.lua` | 98 | 422: 강공격 · 435: 느림 · 느림(공중) · 빠름 |
| `shared/data/WorldMapData.lua` | 78 | 59: 큰 나무 마을 · 66: 대장간 거리 |
| `client/panels/UiGallery/Sections.lua` | 68 | 32: 버튼 - 종류 3 × 상태 4 · 33: 주 |
| `client/StageRewardBand.lua` | 66 | 111: 장비 1개 확정(%s 이상 · Lv %d~%d) [직업] · 113:  ✓ 받음 |
| `client/hud/DropFeed.client.lua` | 65 | 30: 장비 · 89: 님이  |
| `client/A1UiMockups.lua` | 52 | 146: A1 목업 ① HUD 버튼(가방 B · 성장 M · 지도 N) - · 147: 가방 |
| `server/PartyCrossServer.lua` | 52 | 65: 그 코드의 파티가 없습니다(해산됐거나 코드가 틀립니다) · 66: 파티가 가득 찼습니다(최대 4인) |
| `client/panels/Inherit.lua` | 48 | 37: 잘못된 요청입니다 · 38: 직업을 먼저 고르세요 |
| `client/panels/GemForge.lua` | 43 | 38: 잘못된 요청입니다 · 39: 직업을 먼저 고르세요 |
| `client/panels/Inventory/DetailSheet.lua` | 40 | 31:  · 굴림 %.0f%% / %.0f%% · 33:  · 굴림 %.0f%% |
| `client/panels/Party.lua` | 39 | 68: 파티 · 135: 내 파티 |
| `shared/BossSkillMath.lua` | 38 | 53: 무작위  · 53: 박  |
| `shared/data/EggData.lua` | 37 | 9: 석조 평원 알 · 10: 수정 동굴 알 |
| `client/panels/Leaderboard.lua` | 34 | 36: 전체 · 37: 직업별 |
| `client/ui/ScreenMap.lua` | 32 | 43: 로블록스 채팅창 - 손대지 않는다 · 44: 시스템 토스트 줄(저장 · 레벨업 · 구역 차단 · 보물상자 -  |
| `server/Travel.lua` | 32 | 243: 허브 귀환 · 266: 돌아가기 |
| `shared/data/MonsterCodexData.lua` | 32 | 12: 첫 만남 · 13: 10마리 처치 |
| `shared/data/QuestData.lua` | 31 | 9: 몬스터 {n}마리 처치 · 10: 보스 {n}번 처치 |
| `client/hud/SystemToasts.client.lua` | 30 | 30: 레벨업! Lv.%d · 44: 장비 |
| `shared/EquipCompare.lua` | 30 | 88: 방어력 %s · 90: 공격력 +%.1f%% |
| `shared/WorldMapLayout.lua` | 30 | 392: 1단 · 393: 공중1 |
| `client/panels/Enhance/init.lua` | 29 | 37: 골드가 부족합니다 · 38: 강화대에서 너무 멀리 떨어졌습니다 |
| `client/panels/GemWorkshop/init.lua` | 29 | 63: 보석상인에게서 너무 멀어 요청이 거절되었습니다 · 64: 캐릭터를 찾을 수 없습니다 |
| `client/panels/UiGallery/RuleCheck.lua` | 29 | 66: ① window(전시장) 열림: 스택 %s · DisplayOrd · 73: ② 전시장을 연 채 가방 열기: 스택 %s(기대 [inventor |
| `client/hud/MenuBar.client.lua` | 28 | 334: 등록 표: 메뉴 칸 %s(기대 inventory(B) · part · 346: 칸 6개 = error %s · 5개 = 통과 %s · 금지 키( |
| `server/C1Sim.lua` | 28 | 565: 주의 · 590: 강한 계정 스테이지 1 → 높은 몹 대신 깎기(받는 사람 B) |
| `shared/WorldCheck.lua` | 27 | 33: %s 길 %.0f · 33: 본 |
| `client/panels/Milestones.lua` | 24 | 32: 성장 보상 - 환생 후 레벨 마일스톤 · 131: 환생 %d회 · 지금 레벨 %d |
| `client/panels/Inspect.lua` | 22 | 37: 잠시 뒤 다시 시도하세요 · 38: 서버를 떠난 플레이어입니다 |
| `client/hud/PartyRequests.client.lua` | 21 | 34: 돌아가기 · 37: 나중에 |
| `client/panels/Inventory/GemTab.lua` | 20 | 96: 내 무기 - 홈 5칸 · 112: 홈 상세 (등급 상한 이하는 전부 장착 가능) |
| `server/PartyServer.server.lua` | 20 | 35: 자기 자신은 초대할 수 없습니다 · 36: 이미 다른 파티에 속한 플레이어입니다 |
| `server/Leaderboard.lua` | 19 | 110: 쓰기 %s/%s · 126: 쓰기 %s/%s |
| `shared/data/MonsterSpeciesData.lua` | 19 | 20: 이끼 슬라임 · 23: 바위 멧돼지 |
| `client/StageSelectPanel.lua` | 18 | 48: 그 스테이지로는 아직 갈 수 없습니다(최고 도달 스테이지 + 1까 · 49: 바로 아래 보스를 먼저 깨야 갈 수 있습니다 |
| `client/WorldClient.client.lua` | 18 | 46: 🔒 %s\n%s 보스를 처음 잡으면 열린다 · 46: 이전 구역 |
| `client/panels/Enhance/Controller.lua` | 17 | 66: 최대 강화 단계입니다 · 68: 보유한 방지권이 없습니다 |
| `client/InputDiag.client.lua` | 15 | 28: %s(우선순위 %s · 스택 %s) · 33: 없음 |
| `shared/data/TrainingData.lua` | 15 | 12: 공격 수련 · 13: 체력 수련 |
| `client/panels/Inventory/GearTab.lua` | 14 | 42: 착용 중 · 100: 옵션 보너스 |
| `client/BossTrapView.lua` | 12 | 30: 빙결 · 31: 침수 |
| `shared/data/GemData.lua` | 12 | 50: 연속격 · 50: 속사의 흔적 |
| `shared/data/SkillData.lua` | 12 | 17: 관통돌진 · 46: 회전베기 |
| `shared/BossJumpCourseMath.lua` | 11 | 16: 1단 · 17: 공중 1 |
| `shared/ItemDescribe.lua` | 11 | 71: 치확 %+.1f%%p · 72: 치피 %+.2f |
| `client/PrimordialFx.client.lua` | 10 | 33: 초월 · 33: 태초 |
| `client/panels/PlayerMenu.lua` | 10 | 64: 친구 추가 · 69: 친구 요청 창을 열 수 없습니다 |
| `client/panels/Inventory/Shell.lua` | 10 | 38: 가방 · 260: 가방 |
| `server/BossGate.lua` | 10 | 156: 토벌 - 보스를 한 번 이상 클리어하면 열립니다 · 157: 토벌 - 아직 깨지 않은 보스 스테이지에서는 토벌할 수 없습니다 |
| `shared/WeaponRigCheck.lua` | 10 | 75: 규격 없음 또는 모델 아님 · 80: Model이면 PrimaryPart(강화 이펙트 · 발사 자리가  |
| `shared/data/MovementConfig.lua` | 10 | 111: 걷기(이속 상한 24) · 111: 대시 · 공중 대시 · 태초 2단 대시(서버 대시 허가) |
| `shared/data/StageGenerationData.lua` | 10 | 10: 잿빛 · 10: 잿빛 |
| `shared/data/TitleData.lua` | 10 | 10: 태초의 선택 · 11: 드랍 태초 장비(세계 번호가 붙는 태초)를 처음 얻는다 - 태초  |
| `client/ClassSelectUI.client.lua` | 9 | 40: 직업을 선택하세요 · 69: 친구와 레벨이 달라도 바로 같이 사냥할 수 있어요. 직업은 언제든 |
| `shared/PrimordialStamp.lua` | 9 | 26: 토벌:  · 31: (반짝이) |
| `shared/data/BossArenaMapData.lua` | 9 | 66: 구조물 파편 · 115: 솟는 바위 |
| `client/panels/Inventory/GemActions.lua` | 8 | 33: %d번 홈은 환생 %d회 뒤에 열립니다 · 36: %d번 홈은 %s 이하 보석만 받습니다 |
| `client/panels/Inventory/PrimordialActions.lua` | 8 | 19: 각성 · 27: 각성 완료 - 아이템 레벨 %d |
| `server/BossMechanics.lua` | 8 | 116: 성공 · 116: 실패 |
| `server/ZoneTerrain.lua` | 8 | 503: 경사 45° 초과 · 504: 단차 2 초과(절벽) |
| `shared/data/ArmorData.lua` | 8 | 89: 일반 · 96: 희귀 |
| `shared/data/OptionData.lua` | 8 | 55: 위력 · 56: 신속 |
| `shared/data/TerrainGenData.lua` | 8 | 95: 수호자 봉 · 107: 수정 왕관 봉 |
| `shared/data/TutorialData.lua` | 8 | 63: 이동(WASD/조이스틱)과 클릭·탭 공격을 배워보세요. 슬라임을  · 65: 친구가 있다면 지금 불러도 됩니다 - 레벨이 달라도 같은 슬라임을 |
| `client/UIManager.lua` | 7 | 342: 확인창을 먼저 닫아 주세요 · 342: 지금은 열 수 없습니다 |
| `client/panels/Enhance/RebirthView.lua` | 7 | 23: 환생 성공! %d회차 · 25: 레벨이 부족합니다(필요 레벨 %d) |
| `server/CombatResolution.lua` | 7 | 240: 보스 · 240: 반짝이 |
| `server/QuestService.lua` | 7 | 101: 골드 %d · 105: 강화석 %d |
| `client/TutorialHud.client.lua` | 6 | 118: 견습 졸업 · 121: 견습 %d/%d단계 - %s 구역 |
| `client/panels/Inventory/BulkSell.lua` | 6 | 96: 판매한다 · 112: 취소 |
| `client/panels/UiGallery/init.lua` | 6 | 43: station은 비모달이다 - 열린 채로 걸을 수 있다. wind · 56: UI 전시장 |
| `server/BossPatterns.lua` | 6 | 225: 넉백 · 765: 보스 발사(%s%s) |
| `server/PartyState.lua` | 6 | 413: 파티가 해산되었습니다 · 458: 파티에 복귀했습니다 |
| `shared/BossDifficultySim.lua` | 6 | 259: 환경 · 335:  오답 |
| `shared/data/ClassData.lua` | 6 | 30: 성기사 · 30: 뿅망치 |
| `shared/data/MonsterData.lua` | 6 | 120: 슬라임 · 121: 고블린 |
| `client/BossGimmick13View.lua` | 5 | 153: 빛나는 꼬리를 찾아 때려라! %d · 251: ♪ 순서를 기억하라! |
| `client/panels/Enhance/CostView.lua` | 5 | 36: 골드 · 37: 재료 |
| `client/panels/Enhance/OddsView.lua` | 5 | 97: 합계 · 131: 불씨 |
| `client/panels/Inventory/ItemActions.lua` | 5 | 29: 가방이 가득 차 해제할 수 없습니다 - 칸을 비우세요 · 31: 직업을 먼저 고르세요 |
| `client/panels/Inventory/Layout.lua` | 5 | 47: 장비 · 47: 가방 |
| `server/AcquisitionAudit.lua` | 5 | 254: 태초 %s(번호 %s · %s) · 310: 태초 %d개 · λ %.3g · P(X ≥ %d) = %.3g < |
| `server/MonsterSpawner.lua` | 5 | 238: 보물상자 · 452: 보물상자 |
| `shared/BossRules.lua` | 5 | 133: %d번째 바퀴: 알 수 없는 보스 id %s · 135: %d번째 바퀴: %s 중복 |
| `shared/MotionTiming.lua` | 5 | 97: 1타 · 97: 2타 |
| `shared/TrailSkin.lua` | 5 | 25: core · edge 색 없음 · 30: 허용 안 된 칸 %s(스킨은 색 · 질감 · 파티클만) |
| `shared/data/A1PrototypeData.lua` | 5 | 19: 달림 · 20: 몸 낮춤 |
| `shared/data/MilestoneData.lua` | 5 | 20: 가방 칸 +5 · 21: 계승 비용 -10% |
| `client/hud/PartyAway.lua` | 4 | 38: 끊김 · 38: 연결 끊김 |
| `client/panels/Inventory/BagTab.lua` | 4 | 34: 보관함 · 269: 일괄판매 예상 +%s |
| `client/ui/PanelRegistry.lua` | 4 | 21: 가방 · 22: 파티 |
| `first/LoadingTips.lua` | 4 | 4: 레벨이 달라도 괜찮아요. 같이 때리면 전원이 자기 기준의 보상을  · 5: 보상은 나눠 갖지 않습니다. 옆에 친구가 있으면 그냥 더 빠릅니다 |
| `server/OpsServer.server.lua` | 4 | 138: none(이 서버 기록) · 146: failed: 저장소 읽기 |
| `server/StageServer.server.lua` | 4 | 109: 보스 스테이지는 파티 리더만 열 수 있습니다 · 115: 보스 스테이지는 파티 리더만 열 수 있습니다 |
| `server/TerrainBake.lua` | 4 | 339: %s(버전 %s/%s · 서명 %s/%s) · 387: 점 %d 옆 %s |
| `server/TrailSkinService.lua` | 4 | 29: 없는 스킨 · 33: 금지 검사 X:  |
| `shared/Awaken.lua` | 4 | 35: 장비를 찾을 수 없어요 · 36: 각성은 태초 · 초월 장비만 할 수 있어요 |
| `shared/data/AutoStageData.lua` | 4 | 7: 편함 · 8: 보통 |
| `shared/data/BossJumpMapData.lua` | 4 | 30: 나선 계단 · 44: 지그재그 탑 |
| `shared/data/ItemVisualData.lua` | 4 | 109: 갑옷 · 110: 장갑 |
| `shared/data/SkillVariantData.lua` | 4 | 10: 넓게 · 11: 재빠르게 |
| `shared/data/TranscendentData.lua` | 4 | 27: 환영 · 27: 광폭 |
| `shared/data/UltimateData.lua` | 4 | 22: 파괴의 화신 · 28: 천궁의 폭우 |
| `shared/data/WorldConfig.lua` | 4 | 248: 환생의 제단 · 249: 환생 |
| `client/BossRodsView.lua` | 3 | 102: ⚡ 피뢰침 %d/%d · 남은 방전 %d · 143: ⚡ 내가 표적! |
| `client/DamageNumbers.lua` | 3 | 66: 무효 · 110:  (흡수 %s) |
| `client/MilestoneToast.client.lua` | 3 | 16: 성장 보상 Lv.%d ·  · 19: %s +%.1f%%(합)  |
| `client/hud/PartyListView.lua` | 3 | 89: %s · 스테이지 %s · 238: ✚ 피해 + |
| `client/hud/RequestBanner.lua` | 3 | 68: 가 · 270: 수락 |
| `client/panels/Inventory/Store.lua` | 3 | 45: 등급순 · 45: 레벨순 |
| `client/ui/FeedLayout.lua` | 3 | 72: 터치  · 77: 중앙 금지 구역 |
| `client/ui/kit/Confirm.lua` | 3 | 103: 확인 · 104: 확인 |
| `server/BossAirGrab.lua` | 3 | 390: 아무도 안 걸림 · 409: 전원 탈출 |
| `server/BossArenaMap.lua` | 3 | 479: 파편 튕김 · 1025: 구조물 |
| `server/BossEnvironment.lua` | 3 | 343:  - 낙사 · 353: 무너진 조각 가장자리 |
| `server/HallOfFame.lua` | 3 | 48: ✦ 명예의 전당 · 초월 ✦ · 74: 아직 기록이 없어요 - 첫 태초의 주인은? |
| `server/SaveCoordinator.lua` | 3 | 106: 없음 · 109: 다른 서버에 더 최근 저장이 있어 지금 상태는 저장하지 않았습니다 |
| `shared/data/MonsterPrefixData.lua` | 3 | 35: 연약한 · 43: 단단한 |
| `shared/data/PetData.lua` | 3 | 34: 강아지 · 34: 고양이 |
| `client/BossEnvironmentView.lua` | 2 | 353: 수정까지 날아가는 발판이 생겼어요! · 353: 도움 발판이 생겼어요! |
| `client/BossGateMarks.client.lua` | 2 | 74: 관문 등록 - 버튼을 눌러요 · 74: 관문 등록 [F] |
| `client/BossIntroCard.client.lua` | 2 | 76: %s  %s · 전멸기 · 101: 확인 |
| `client/BossSonicView.lua` | 2 | 147: 가려짐! 0 · 152: 음파! |
| `client/InventoryUI.client.lua` | 2 | 171: 보유 골드  · 199: 인벤토리가 가득 찼습니다 - 땅에 있는 아이템을 주울 수 없습니다 |
| `client/SkillSlots.client.lua` | 2 | 139: 공격 · 507: JUMP\n(모의) |
| `client/StageUI.client.lua` | 2 | 112: 최고 기록 - · 127: 최고 기록 %d |
| `client/WeaponVisual.lua` | 2 | 1578: 없음 · 1604: 없음 |
| `client/ZoneBoundaryWarning.client.lua` | 2 | 110: %s 구역 진입 - tier %d · 119: %s 진입 |
| `client/hud/UltGauge.client.lua` | 2 | 62: T 궁극기 · 93: 궁극기 |
| `client/panels/Probability.lua` | 2 | 87: +%d → +%d %s · 유지 %s · -1 %s · -2 %s · 115: Lv.%d(%d회~) %s |
| `client/panels/GemWorkshop/Hint.lua` | 2 | 10: 보석상인에게서 가능 · 11: [위치 안내] |
| `client/panels/Inventory/GemHeader.lua` | 2 | 81: 변환 · 리롤은 보석상인에게서 · 82: 변환 · 리롤은 커뮤니티 센터 보석상인에게서 - 눌러서 [위치 안 |
| `server/AttackServer.server.lua` | 2 | 159: 구역 안으로 들어가야 공격할 수 있습니다 · 200: 공격 |
| `server/BossArenaContainment.lua` | 2 | 118: 스폰 자리 · 118: 안전 지점(스폰 자리가 막힘) |
| `server/BossEncounter.lua` | 2 | 535: band(권장 %d+%d) · 574: 파티가 보스전에 들어갔습니다 |
| `server/BossGimmicks.lua` | 2 | 111: 감전 구출 · 137: 얼음 |
| `server/BossJumpCourse.lua` | 2 | 110: 수정 · 192: 수정 부수기  |
| `server/BossLightningRods.lua` | 2 | 162: 번개 · 189: 방전 번개 |
| `server/EnhanceService.lua` | 2 | 143: , 방지권  · 143:  소모 |
| `server/FallServer.lua` | 2 | 51: 낙하 쓰러짐 → 마지막 안전 지점 · 141: 낙하 %.0f |
| `server/HeightGuard.lua` | 2 | 447: (공중 정체 %.1f초) · 448: 없음 |
| `server/SkillServer.server.lua` | 2 | 629: 구원의 기도 · 672: 스킬  |
| `server/SoulService.lua` | 2 | 94: 성역 · 100: 성역 |
| `shared/CartoonStyle.lua` | 2 | 174: (없음) · 214: (없음) |
| `shared/Milestone.lua` | 2 | 78: 최대 체력 · 78: 공격력 |
| `shared/RoadNet.lua` | 2 | 401: 캠프 · 관문 → · 410: 관문 ↑ · 전망 ↗ |
| `shared/data/EnhanceConfig.lua` | 2 | 79: 하락 방지권 · 80: 초기화 방지권 |
| `shared/data/EnhanceMaterialData.lua` | 2 | 14: 강화석 · 15: 상급 강화석 |
| `shared/data/NestData.lua` | 2 | 142: 둥지 탐험가 · 142: 비밀 수집가 |
| `client/BossBR13View.lua` | 1 | 422: ✋ 공격 멈춤 |
| `client/BossRegrowView.lua` | 1 | 137: 탈출! %d타 |
| `client/EnhanceAnnounceClient.client.lua` | 1 | 13: %s님이 +%d 강화에 성공했습니다 |
| `client/FallFx.client.lua` | 1 | 97: 쿵! |
| `client/hud/PartyList.client.lua` | 1 | 64:  (더미) |
| `client/panels/Enhance/TicketView.lua` | 1 | 46: 구매 |
| `client/panels/Inventory/GemSlotRows.lua` | 1 | 68: 리롤 |
| `server/AlphaStats.lua` | 1 | 38: 끌어오기 %d회 · 합 %.1f초 · 평균 %.2f초 · 약하게  |
| `server/BossColorMatch.lua` | 1 | 110:  - 공동 책임 |
| `server/BossOrgel.lua` | 1 | 48: 수정 종  |
| `server/BossSandSearch.lua` | 1 | 64: 모래 둔덕 |
| `server/BossTrap.lua` | 1 | 282: 구출 |
| `server/EnhanceStation.server.lua` | 1 | 45: 강화대 |
| `server/HealCast.lua` | 1 | 110: 치유 버프 |
| `server/HuntingGround.server.lua` | 1 | 206: %s %d(장식 %d) |
| `server/MonsterAI.server.lua` | 1 | 270: 잡몹 넉백 |
| `server/NestServer.lua` | 1 | 248:  · 비밀 둥지 발견  |
| `server/PartyVote.lua` | 1 | 50: 투표가 성립하지 않았습니다(제한시간 초과 - 아무도 동의하지 않음 |
| `server/PlayerDamage.lua` | 1 | 92:  (쉴드 흡수 %.2f) |
| `server/SaveServer.server.lua` | 1 | 30: 저장 데이터를 불러오지 못했습니다. 이번 접속에서의 변경사항은 저 |
| `server/TutorialState.lua` | 1 | 241: 견습 졸업! 무한 모드가 열렸습니다. |
| `server/WorldHazards.lua` | 1 | 142: 선인장 |
| `shared/MoveRules.lua` | 1 | 194: HeightGuard 허가(source = ledge) |
| `shared/data/CosmeticSlotData.lua` | 1 | 11: (없음 - D1-3에서 태초 발자국 삭제) |
| `shared/data/DropNoticeData.lua` | 1 | 25:  외 %d |
| `shared/data/PrimordialData.lua` | 1 | 17: 모험가 |
| `shared/data/SetData.lua` | 1 | 14:  세트 |
| `shared/data/WeaponData.lua` | 1 | 23: 기본 무기 |