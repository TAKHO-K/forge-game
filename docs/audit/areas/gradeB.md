# 등급 B 검수(소넷 시기 ≥ 50% 모듈) - 읽기 전용 감사

검수일 2026-10-04 · 범위 = `docs/audit/model-map.md` "### 등급 B" 표 중 저장 · 결제 · 보안 · 경제 · 전투 핵심을 뺀 것. 코드는 고치지 않았다. 숫자 표기는 로컬 `luau.exe`로 실제 실행해 확인했다(아래 표시).

## 0. 검수한 파일

**꼼꼼히 읽음(전체 또는 핵심 경로 전부)**

| 구분 | 파일 |
|---|---|
| 서버 | `server/TutorialState.lua` · `server/BuffState.lua` · `server/PartyVote.lua` · `server/StuckArrowState.lua` · `server/HuntingGround.server.lua` |
| 공용 | `shared/NumberFormat.lua`(luau 실행 확인) · `shared/Gem.lua` · `shared/ItemDescribe.lua` · `shared/GradeColor.lua` · `shared/data/ItemVisualData.lua` · `shared/data/WorldConfig.lua` · `shared/data/TutorialData.lua` · `shared/data/EnhanceMaterialData.lua` |
| 클라 | `client/UIManager.lua` · `client/ui/kit/Toast.lua` · `client/ui/kit/Panel.lua` · `client/StageSelectPanel.lua`(1~140 · 480~794) · `client/panels/Party.lua`(340~645) · `client/panels/Enhance/init.lua`(200~449) · `client/panels/Enhance/Controller.lua` · `client/hud/DropFeed.client.lua`(1~140) · `client/hud/RequestBanner.lua`(160~424) · `client/hud/PartyRequests.client.lua`(60~132) · `client/TutorialHud.client.lua` · `client/MaterialHud.client.lua` · `client/StuckArrows.client.lua` · `client/InputDiag.client.lua`(머리) |

**부분 확인(연결 · 생명주기 · 특정 함수만)**

`client/panels/Inventory/BulkSell.lua`(140~240 · 325~360) · `GemTab.lua`(395~600) · `GemBag.lua`(120~160) · `Store.lua`(150~200) · `Shell.lua`(175~225) · `BagTab.lua`(360~390) · `client/StageRewardBand.lua`(isBossStage · 300~335) · `client/panels/GemWorkshop/Guide.lua`(120~145) · `client/HelpTooltip.lua` · `client/ui/kit/HelpToggle.lua` · `client/hud/SystemToasts.client.lua`(연결만) · `client/ui/WindowPositions.lua`(머리) · `client/ui/TextAudit.lua`(참조) · `server/TeleportPad.lua`(참조) · `shared/data/ArmorData.lua`(등급 · 일괄 설정) · `server/InventoryServer.server.lua`(판매 · 분해 핸들러 대조용) · `server/ProtectionTickets.lua`(방지권 폐지 대조용) · `shared/Text.lua`(번역 경로 대조용)

**자동 점검**: 등급 B 119개 중 모듈(.lua) 전부에 대해 "검증 · 점검 스크립트를 뺀 참조 수"를 grep으로 셌다(→ 5절). 반복 호출 함수 안의 `:Connect(` 휴리스틱 스캔도 돌렸다(Party · GemBag · BulkSell · HelpTooltip · Guide - 전부 새 인스턴스에 거는 것이거나 끊는 짝이 있어 누수 아님).

**못 본 것(다음 차례 권장)**: `client/SkillSlots.client.lua` · `client/AttackInput.client.lua`(전투 입력 - 전투 담당과 겹침) · `client/WeaponEnhanceVisual.lua` · `client/PlayerHealthBar.client.lua` · `client/Projectiles.lua` · `client/HudIcons.lua` · `client/hud/PartyListView.lua` · `client/InventoryUI.client.lua` · `client/panels/GemWorkshop/init.lua` · `shared/data/SkillData.lua` 본문.

## 1. 즉시 확인(치명)

없음. 저장을 망가뜨리거나 보안 구멍이 되는 것은 이번 범위에서 찾지 못했다. 서버 모듈(BuffState · PartyVote · StuckArrowState · TutorialState)은 클라 값을 그대로 믿지 않는다(TutorialState.requestChallenge가 서버 Attribute를 다시 본다 · PartyVote.cast가 대상자 목록을 대조한다).

## 2. 버그 표

| 심각도 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|
| 중간 | `client/panels/Inventory/BulkSell.lua:171-176` (서버 `server/InventoryServer.server.lua:104-111`) | 일괄 판매 확인창을 연 채로 영웅 장비를 줍는다(자동 줍기 포함) → [분해]를 누른다 | 확인창이 보여 준 개수에 없던 영웅 장비까지 보석으로 분해된다(되돌릴 수 없음). 판매 쪽은 QUEUE-ALL8 F 리뷰에서 "보여 준 개수"를 같이 보내 막았지만(`BulkSell.lua:184-191` · 서버 `count_mismatch`) 분해는 기준 등급만 보낸다 | 판매와 같게 확인창의 분해 개수를 같이 보내고 서버 `dismantleItemsUpTo`가 다시 센 수와 다르면 거절 + `count_mismatch` 회신 | 1시간 |
| 중간 | `server/TutorialState.lua:164-171` · `client/TutorialHud.client.lua:124` · `shared/data/TutorialData.lua:63-` | 언어 en으로 새 계정 시작 | 견습 안내 본문(lessonText) · 친구 한 줄(friendHintText)이 한국어 그대로 나온다. 서버가 데이터 문장을 그대로 보내고 클라가 `Text.name`도 안 거친다(TextData_names에도 없음 - grep 0건) | 문장을 TextData 키로 옮기고 서버는 키만 보내 클라가 `Text.get`, 또는 `Text.getFor(player, …)`로 서버에서 번역 | 1시간 |
| 낮음 | `client/panels/Inventory/GemTab.lua:520` vs `shared/ItemDescribe.lua:72` | 치명 옵션 보석을 홈에 끼우고 홈 줄과 툴팁을 비교 | 같은 값이 홈 줄은 `치피+11.50`(×100, % 없음), 툴팁은 `치피 +0.12`로 다르게 보인다(critDmgBase 0.115 - `OptionData.lua:60`) | 둘 중 하나로 통일(한 함수 - ItemDescribe.optionLines를 홈 줄도 쓰게) | 30분 |
| 낮음 | `client/hud/PartyRequests.client.lua:100-104` | 파티 보스 [다시 도전] · [포기] 투표가 통과/무산 | 결과 배너 제목이 항상 "보스 입장 투표"(`vote.enter.title`)로 바뀐다. 서버 `PartyVote.finish`(`server/PartyVote.lua:48-49`)가 kind를 안 실어 클라가 구분 못 한다 | finish 페이로드에 kind를 싣고 제목 키를 kind로 고른다 | 30분 |
| 낮음 | `server/PartyVote.lua:141-149` | 투표 도중 파티원이 탈퇴 · 추방 | `cancel`이 클라에 아무것도 안 보내 투표 배너가 남은 시간 동안 떠 있고, 누른 표는 서버가 조용히 버린다 | cancel 때 남은 대상자에게 `{ result = "failed" }`(또는 "cancelled") 한 번 | 20분 |
| 낮음 | `shared/NumberFormat.lua:62-66` (luau 실행 확인) | `NumberFormat.format(-123456)` · `commas(-999999)` | `-,123,456`이 나온다(자릿수가 3의 배수인 음수). 또 `format`은 음수를 줄이지 않아 `-1e20` = `-,100,000,…`(26자). 지금 호출부는 대부분 절댓값을 넘겨(`EquipCompare.lua:103` · `DamageNumbers.lua:122`) 잠복 상태 | `withCommas`에서 부호를 떼고 붙이기 + `format`도 음수면 `"-" .. format(-n)`(currency와 같은 방식) | 20분 |
| 낮음 | `client/ui/kit/Toast.lua:505-518` | `groupKey` + `fadeSeconds` 알림이 흐려지는 도중(대기열 단축 passOn으로 seconds가 0까지 줄 때) 같은 키가 다시 온다 | 진행 중인 흐림 트윈을 안 멈춰 합쳐진 행(×2)이 투명한 채 자리만 차지했다가 사라진다. 지금 TR(대기열 없음)에서는 합침 창(1초) < 표시 시간이라 잘 안 난다 | tryMerge에서 `row.fading`이면 `restoreVisual(row)` 먼저 | 15분 |
| 낮음 | `server/TutorialState.lua:214` | 견습 보스 모델에 PrimaryPart가 없는 채 처치 판정(메시 교체 · 아트 스위치 등) | `target.PrimaryPart.Position` nil 접근으로 졸업 · 다음 단계 진행이 통째로 멈춘다(확인 필요 - 지금 MonsterSpawner는 PrimaryPart를 준다고 가정) | `target:GetPivot().Position`으로 | 10분 |
| 낮음 | `server/TutorialState.lua:296-310` | Studio에서 플레이어가 모듈 로드보다 먼저 들어온 경우 | `PlayerAdded`만 걸고 이미 있는 플레이어를 안 돈다 - 견습 재개가 안 걸릴 수 있다(라이브에서는 드묾 · 확인 필요) | 끝에 `for _, p in Players:GetPlayers()` 한 번 | 10분 |
| 낮음 | `server/BuffState.lua:77-89` · `:204-208` | 파티 버프(healerBuff · warcryBuff)가 퇴장 직후의 멤버에게 걸린다(지연 콜백) | PlayerRemoving 뒤에 `buffs[player]`가 다시 생겨 남고, 0.5초 스윕이 떠난 Player에게 FireClient를 시도한다(확인 필요 - 오류 여부) | apply 첫 줄에 `if not player.Parent then return end` | 10분 |
| 낮음 | `client/panels/Enhance/init.lua:430-443` | 강화대 반경 안에서 가방(window)을 연 채 서 있는다 | 매 Heartbeat마다 `ensureBuilt` → `Theme.recompute()` + `UIManager.open`(window 때문에 실패)을 반복한다(성능만) | open이 window 때문에 막히면 그 프레임은 건너뛰는 플래그, 또는 `UIManager.changed`로 다시 시도 | 20분 |
| 낮음 | `client/UIManager.lua:418` · `client/StageSelectPanel.lua:703` | 언어 설정 Attribute가 모듈 로드 뒤 도착 | `blockedTexts` · `blockedText`를 로드 시점에 한 번 만들어 그 뒤 언어와 다를 수 있다(확인 필요 - 언어 변경 = 재접속 규칙이면 무해) | 쓰는 순간 `Text.get` | 10분 |
| 낮음 | `server/HuntingGround.server.lua:100-108` · `:182-202` · `shared/data/WorldConfig.lua:248-249` · `:260-261` | 언어 en | 서버가 만든 프롬프트(환생 제단 · 보석상인 · 상점)의 ObjectText/ActionText가 한국어 고정(이름표 TextLabel은 `bindName`으로 번역되는데 프롬프트는 빠짐). 허브 서비스 프롬프트는 클라가 다시 쓴다(`client/HubServices.client.lua:53-54`) | 클라 쪽에서 세 프롬프트도 relabel(HubServices 패턴) | 30분 |
| 낮음 | `client/panels/Inventory/BulkSell.lua:205-210` | 언어 en · 일괄 분해 합계 줄 | "영웅 3 · 전설 1"을 한국어 displayName으로 이어 붙여 넘긴다 - `Text.nameIn`은 " · " 조각이 사전에 있을 때만 바꾸므로 "영웅 3"은 안 바뀐다 | 등급 이름을 `Text.name`으로 바꾼 뒤 이어 붙이기 | 10분 |

## 3. 설계와 어긋난 코드

| 파일:줄 | 무엇 | 지금 결정 | 비고 |
|---|---|---|---|
| `client/MaterialHud.client.lua:1-3` | 머리 주석이 "보스 첫 클리어로 방지권을 받을 때 '+1 하락 방지권' 팝업" | 방지권 폐지(QUEUE-ALL9B G) - 지급은 골드(`server/ProtectionTickets.lua:78-80`) | 코드는 재료 2종만 띄워 동작은 맞다. 주석만 옛것 |
| `client/panels/Enhance/Controller.lua:5` · `:173` · `client/panels/Enhance/init.lua:3` · `:281` · `OddsView.lua:167` · `ResultFx.lua:3` · `client/StageRewardBand.lua:4` · `:31` | "방지권 토글 · 방지권 2줄" 용어 | 방지권 폐지 → "하락 방지 · 초기화 방지" 옵션(× k 골드) | 동작은 새 규칙(Controller 24행 주석과 `Enhance.getCost(..., useDrop, useReset)`). `Controller.ticketKinds` · `TicketView` 이름과 주석이 옛 개념 |
| `shared/data/ItemVisualData.lua:87-97` | 태초 색 설명이 "청록 → 진한 자홍"(G1-1) | QUEUE-ALL9C 2-2: 태초 = 흰 #F7F5EF + 자홍 외곽선(같은 파일 99-103행) | 주석이 값과 반대. 8등급 색 자체는 GradeColor 단일 출처로 맞다 |
| `shared/data/ItemVisualData.lua:124-127` · `:17` | "지금은 armor만 드랍 · 7등급 전부" | 3부위 드랍 · 8등급(초월) | 주석만 옛것 |
| `shared/data/ItemVisualData.lua:142` | "값은 InventoryUI.client.lua의 RAINBOW_SEQUENCE와 같다" | 실제 사본은 `client/panels/Inventory/Store.lua:161-169` | 4절 중복 참고 |
| `client/UIManager.lua:451-462` | `setBossFight`(보스전 중 window 딤 끄기 - PRD 20.81 [D-1]) | 주석 스스로 "부르는 감시자(BossFightWatcher)는 만들지 않았다" | 게임 코드에서 부르는 곳 0(`UiGallery/RuleCheck.lua`만). 설계 요구가 연결 안 된 상태 - 확인 필요(결정이 바뀌었으면 함수 정리 대상) |
| `server/HuntingGround.server.lua:3` | "포탈 패드(TeleportPad) 모듈은 남아 있다 - 검증 · 개발 명령 일부가 읽는다" | grep 결과 `require` 0건 | 5절 정리 후보 |

판매 NPC 제거: 서버 · 클라에 판매 NPC · 판매 거리 판정 흔적 없음(`sellNpc` · `SellStation` 등 grep 0건) - 판매는 가방(`SellRequest`)뿐이라 결정과 맞다. 펫 등급 표시명 · 8등급 색: `GradeColor.petGrade` → `ItemVisualData.petGradeColorOf`로 한 곳, 옛 펫 색표(HATCH_COLOR) 잔재 없음.

## 4. 단일 소스 위반 · 중복 구현

| 무엇 | 위치 | 내용 | 권장 |
|---|---|---|---|
| 무지개 ColorSequence 두 벌 | `shared/data/ItemVisualData.lua:146-154` · `client/panels/Inventory/Store.lua:161-169` | 같은 7개 키프레임 사본. GradeFrame · Nameplate · Toast는 데이터 쪽을 읽는다 | Store가 `ItemVisualData.rainbowSequence`를 읽게(5분) |
| 견습 안내 토스트 독자 구현 | `client/TutorialHud.client.lua:23-115` | kit `Toast`(줄 · 대기열 · 등급 · 창 위 올림 규칙)를 안 쓰고 ScreenGui · Frame · 트윈을 직접 만든다. 글꼴 · 크기(14/13) · 위치(y 160)도 하드코딩 - Toast 머리 주석 "새 알림은 Toast.push로만"과 어긋남 | `Toast.push("TC", { grade = "important", … })` 로 대체(30분) |
| 숫자 표기 두 규칙 | `shared/NumberFormat.lua:93`(format: 1만 미만 그대로 · K/M) · `:180`(currency: 1천부터 K · ko는 만/억) | 같은 9,999가 format = "9,999", currency(en) = "9.9K". 쓰는 곳 format 64 · currency 26 · commas 7(grep) | 의도된 분리(재화 칸만 currency)라면 머리 주석에 "어디에 어느 것"을 한 줄. 아니면 한쪽으로 |
| 창 위치 저장 두 경로 | `client/panels/Inventory/Shell.lua:184-220`(Profile `InventoryWindowX/Y` · `SetInventoryWindowPosition`) · `client/ui/WindowPositions.lua`(설정 `windowPositions`) | 끌기 · 화면 안 자르기 · 저장 로직이 두 벌. WindowPositions 머리 주석이 "가방은 옛 저장 그대로"라고 인정 | 가방도 WindowPositions로 옮기면 한 벌(저장 필드는 지우지 말고 읽기 전용 이관만). 저장 구조 변경이라 SAVE_VERSION 규칙 확인 필요 |
| 피해 숫자 두 체계 | `client/DamageNumbers.lua`(StuckArrows · 공격 결과가 직접 띄움 - `client/StuckArrows.client.lua:103`) · `client/DamageFeedView.client.lua` + `server/DamageFeed.lua`(W2-3 프로토타입, `DamageNumberData.enabled` 꺼짐) | 꽂힌 화살 폭발은 두 경로 모두에 피해를 보낸다(`server/StuckArrowState.lua:94` + `:96`). 지금은 프로토타입이 꺼져 화면에 한 번만 | 프로토타입을 켤 때 두 번 그려지는지 확인 필요. 켜기 결정 전까지는 메모만 |
| 견습 중 판정 두 곳 | `client/StageSelectPanel.lua:677-679` · `client/TutorialHud.client.lua:221-223` | 같은 식(`TutorialCompleted ~= true and TutorialStep > 0`)을 각자 가진다 | 작아서 급하지 않다 - 한 곳으로 모을 때 같이 |
| 등급 이름 하드코딩 폴백 | `client/panels/Enhance/Controller.lua:86` | `or "일반"` - 데이터(`ArmorData.grades.normal.displayName`)를 안 거친다 | 데이터 값으로(5분) |

같은 기능 이중 구현이 의심됐지만 아닌 것: HelpTooltip/HelpToggle(HelpToggle이 HelpTooltip을 감싼다) · SystemToasts/DropFeed/AutoProcessToast(전부 kit Toast를 부르는 얇은 층) · GradeColor(색 직접 읽기는 `GradeFrame.lua:70` textStroke 1곳뿐).

## 5. 정리 후보

| 경로/이름 | 무엇 | 왜 필요 없나 | 근거(참조 수 · grep) | 지우면 위험 |
|---|---|---|---|---|
| `server/TeleportPad.lua`(125줄) | 옛 3×3 맵 포탈 패드 | M1 큰 세계에서 패드를 안 짓는다(`HuntingGround.server.lua:3`) | `require` 0건(`TeleportPad` 문자열은 HuntingGround 주석 1곳뿐) | 낮음. 주석의 "검증 · 개발 명령이 읽는다"가 사실이 아님을 확인했다. 옛 맵 복원 계획이 있으면 보관 |
| `client/InputDiag.client.lua`(88줄) + `UIManager.inputDiag` 훅(`client/UIManager.lua:477-509`의 diag 분기) | S20 사전 작업 임시 입력 진단 | 스스로 "원인 확인 뒤 제거" - 원인(I · O 키는 엔진이 가로챔, 가방 = B)은 이미 확인됨(메모리 I·O 키 삼킴) | `DevToolsConfig.inputDiag = false`(`shared/data/DevToolsConfig.lua:32`) · 쓰는 곳 = 이 두 파일뿐 | 낮음. 진단을 다시 쓸 일이 있으면 스위치로 꺼 둔 지금 상태도 무해 - 프로젝트 원칙(파일 삭제 대신 스위치)과 맞추려면 그대로 둬도 된다 |
| `UIManager.onEmptyStackAction`(`client/UIManager.lua:45` · `:396-401`) | 열린 창 없을 때 X/Backspace 훅 | 설정창이 생긴 뒤에도 아무도 채우지 않았다 | 대입 0건(grep) | 매우 낮음(nil 검사만 남음) |
| `BuffState.apply`의 `mode = "stack"` 분기(`server/BuffState.lua:83-85`) | 중첩 버프 | 어떤 호출부도 `mode`를 안 준다 | `"stack"` grep = BuffState 주석 · 이 분기만(DevTools의 `option stack`은 다른 뜻) | 매우 낮음. 앞으로 중첩 버프 계획이 있으면 유지 |
| `client/ui/kit/Badge.lua`(51줄) | 배지 kit 부품 | 게임 화면에서 안 쓴다 | 참조 = `UiGallery/Sections.lua` · `UiGallery/RuleCheck.lua`(전시장 · 점검)뿐 | 낮음. kit 전시장의 규칙 점검이 같이 빠져야 한다 - 부품 목록 정책이면 유지 |
| 각 패널 안의 Studio 자체 점검 블록(`client/StageSelectPanel.lua:752-771` · `client/hud/DropFeed.client.lua:134-` 약 330줄) | (가) 자체 점검 | 제품 경로가 아니다(`DevToolsConfig.verify` 조건) | 실행 조건 = `RunService:IsStudio()` + verify 목록 | 중간 - 회귀 검증 체인(S10 · S11)이 쓴다. 지우지 말고 따로 파일로 빼는 정도만 권장 |

저장 필드(`InventoryWindowX/Y` · `tutorial.lendBaseline` · `bossFirstClear` 계열) · 데이터 id(`ticketKinds = drop/reset` 이름, ProtectionTickets 상태 필드) · 에셋은 정리 대상에서 뺐다.

## 맺음

- 건수: 치명 0 · 높음 0 · 중간 2 · 낮음 12(버그 표 기준), 설계 어긋남 7 · 중복 7 · 정리 후보 6.
- 등급 B 서버 모듈은 "서버가 다시 확인한다" 원칙을 잘 지킨다. 문제는 주로 (1) 같은 종류의 구멍을 한쪽만 막은 것(판매는 개수 확인, 분해는 없음), (2) 번역 경로를 안 탄 문장(견습 안내 · 서버 프롬프트), (3) 폐지된 개념(방지권)의 이름 · 주석이 남은 것이다.
