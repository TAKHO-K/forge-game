# 감사 (g) 텍스트·번역 · (i) 3타 강타 표시

- 대상: `roblox/src/`(client · server · shared · shared/data · first), 커밋 c4ed73b 시점 작업 트리. 읽기 전용 조사(저장소 파일 수정 없음, Studio MCP 미사용).
- 세는 스크립트: 스크래치패드 `count.py` · `count2.py` · `panelchars.py` · `vis.py` · `helplen.py`(Lua 토크나이저로 주석을 빼고 문자열 리터럴만 셈. `"..."` · `'...'` · `[[...]]`).
- "개발용" = 파일 이름에 `Verify|Check|Sim|DevTools|UiGallery|Report|Diag|Probe|TelegraphLog|TextAudit|EconSim|BalanceAnchor`가 들어간 파일. 이 파일들의 문자열은 플레이어가 보지 않는다(검증 로그 · 자체 점검).
- [추정] 표시는 코드로 끝까지 확인하지 못한 것.

---

## 1. UI 문자열 수

### 1-1. 한글이 들어간 문자열 리터럴 수

| 영역 | 전체 | 개발용 제외(플레이어 쪽 파일) | 플레이어 쪽 한글 글자 수 |
|---|---|---|---|
| client | 1,381 | 821 | 8,521 |
| server | 2,812 | 287 | 2,836 |
| shared(데이터 제외) | 190 | 188 | 1,345 |
| shared/data | 205 | 124 | 705 |
| first(ReplicatedFirst) | 5 | 5 | 90 |
| **합계** | **4,593** | **1,425** | **13,497** |

- 전체의 69%(3,168개)가 검증 · 개발 도구 문자열이다(`server/DevTools.server.lua` 한 파일에만 529개).
- 플레이어 쪽 821개 중 `client/ui/ScreenMap.lua`(28개 · 912자)는 좌표표의 `note` 설명이라 화면에 안 나온다(`client/ui/ScreenMap.lua:1-7`). `UIManager` · `PanelRegistry` · `ui/kit/*`의 `assert` 문구도 개발자용이다.
- server 플레이어 쪽 287개 중 135개가 `print/warn/error` 로그다(줄 문맥으로 분류).

### 1-2. 파일별 상위 15 (개발용 제외)

**client**

| 순위 | 파일 | 개수 |
|---|---|---|
| 1 | client/hud/DropFeed.client.lua | 75 (자체 점검 블록 포함 - `DropFeed.client.lua:268` 등) |
| 2 | client/StageRewardBand.lua | 55 |
| 3 | client/panels/Inherit.lua | 48 |
| 4 | client/panels/GemForge.lua | 47 |
| 5 | client/panels/Party.lua | 39 |
| 6 | client/panels/Inventory/DetailSheet.lua | 39 |
| 7 | client/panels/Leaderboard.lua | 35 |
| 8 | client/hud/SystemToasts.client.lua | 32 (자체 점검 문구 포함 - `SystemToasts.client.lua:144`) |
| 9 | client/hud/MenuBar.client.lua | 31 |
| 10 | client/panels/Enhance/init.lua | 31 |
| 11 | client/panels/GemWorkshop/init.lua | 30 |
| 12 | client/ui/ScreenMap.lua | 29 (화면에 안 나옴) |
| 13 | client/panels/Milestones.lua | 25 |
| 14 | client/panels/Inspect.lua | 22 |
| 15 | client/StageSelectPanel.lua | 20 |

(개발용 포함 시 1위는 `client/hud/RequestBannerCheck.client.lua` 90개.)

**server**

| 순위 | 파일 | 개수 | 성격 |
|---|---|---|---|
| 1 | server/PartyCrossServer.lua | 68 | 거절 사유표 12개(`:65-76`) + 알림 + DataStore/MessagingService 호출 라벨(`call("레코드 갱신"...)` `:150` 등 - 로그용) |
| 2 | server/Leaderboard.lua | 29 | 대부분 재시도 로그 라벨(`:109`, `:405`) + 가짜 이름 10개(`:699` - 검증 더미) |
| 3 | server/PartyServer.server.lua | 21 | 거절 사유표 14개(`:34-47`) + 알림(`:101`, `:128`, `:145`, `:166`) |
| 4 | server/PartyState.lua | 19 | 알림(`:397`, `:442`, `:478`, `:496`, `:639`) |
| 5 | server/CombatResolution.lua | 17 | 로그 다수 + 알림 2(`:248`, `:312`) |
| 6 | server/BossPatterns.lua | 14 | 로그 |
| 7 | server/BossArenaMap.lua | 12 | 로그 + 구조물 이름(`:742`, `:768`) |
| 8 | server/ZoneTerrain.lua | 11 | 지형 검사 사유(`:503-520` - 검증용) |
| 9 | server/BossEncounter.lua | 10 | 로그 + 알림 1(`:435`) |
| 10 | server/BossMechanics.lua | 10 | 로그 |
| 11 | server/HuntingGround.server.lua | 9 | 월드 글씨(`:145` "커뮤니티 센터 (준비 중)", `:400` "중앙 복귀") |
| 12 | server/MonsterSpawner.lua | 8 | 보물상자 이름 · 전 서버 알림(`:273`, `:493`, `:515`, `:527`) |
| 13 | server/SaveCoordinator.lua | 6 | 저장 실패 알림(`:109`, `:112`) |
| 14 | server/SaveSystem.lua | 5 | 로그 |
| 15 | server/TutorialState.lua | 5 | 졸업 알림(`:236`) |

**shared**

| 순위 | 파일 | 개수 |
|---|---|---|
| 1 | shared/SkillTooltipText.lua | 124 (1,078자 - 전 파일 중 한글 최다) |
| 2 | shared/data/BossData.lua | 37 |
| 3 | shared/EquipCompare.lua | 30 |
| 4 | shared/BossSkillMath.lua | 12 |
| 5 | shared/data/GemData.lua | 12 |
| 6 | shared/ItemDescribe.lua | 11 |
| 7 | shared/data/BossArenaMapData.lua | 9 |
| 8 | shared/data/OptionData.lua | 8 |
| 9 | shared/data/SkillData.lua | 8 |
| 10 | shared/data/TutorialData.lua | 8 (298자 - 문장이 길다) |
| 11 | shared/data/ArmorData.lua | 7 |
| 12 | shared/data/WorldConfig.lua | 7 |
| 13 | shared/data/MonsterData.lua | 6 |
| 14 | shared/BossRules.lua | 5 |
| 15 | shared/data/MilestoneData.lua | 5 |

### 1-3. 서버가 만들어 클라로 보내는 문구 비율

- 통로: `PartyState.notify`(`server/PartyState.lua:321`, RemoteEvent `PartyNotice` `:44`) · `SaveCoordinator.notify`(`server/SaveCoordinator.lua:54`) · `treasureChestNotice:FireAllClients`(`server/MonsterSpawner.lua:515`, `:527`, `server/CombatResolution.lua:312`) · `zoneBlockedNotice:FireClient`(`server/AttackServer.server.lua:88`) · 튜토리얼 졸업 문구(`server/TutorialState.lua:236`) · 파티 이동 보류 문구(`server/PartyCrossServer.lua:643-645`, `:721-725`).
- 서버 쪽에서 완성된 한국어 문장으로 클라에 가는 것: **약 58개**(알림 · 거절 사유) + 서버가 만든 월드 글씨 · 이름 **약 10개**(`EnhanceStation.server.lua:45` "강화대", `HuntingGround.server.lua:145`, `:400`, `BossTrap.lua:248` "구출", `BossGimmicks.lua:137` "얼음", `HealCast.lua:102`, `MonsterSpawner.lua:273`/`:493` "보물상자", `BossArenaMap.lua:742`/`:768` "구조물") = **약 68개**.
- 플레이어가 보는 문자열(1,425 − ScreenMap 28 ≈ 1,397) 중 **약 4.9%** 가 서버발이다. 나머지 95%는 클라/shared에서 만든다.
- 좋은 점: 드랍 알림 · 마일스톤 · 친구 입장은 서버가 **구조화된 payload**만 보내고 문장은 클라가 만든다(`server/DropNotice.lua:1-4` 주석 "어디에 어떻게 그리는지는 클라", `server/MilestoneNotice.lua:2`, `server/FriendNotice.lua:34`). 강화 · 보석 · 계승 · 환생도 서버는 reason 코드만 보내고 클라가 표로 바꾼다(`client/panels/Enhance/init.lua:36-38`, `client/panels/GemForge.lua:36-45`, `client/panels/Enhance/RebirthView.lua:24-34`).
- 번역에 불리한 점: 파티 계열(`PartyServer.server.lua:34-47`, `PartyCrossServer.lua:65-76`)은 **서버가 사유 코드를 문장으로 바꿔서** 보낸다. 서버는 받는 사람의 언어를 모르므로(Translator는 Player별로 얻어야 함) 이 약 68개는 코드 전송 + 클라 번역 구조로 바꾸는 게 맞다.

---

## 2. 하드코딩 위치 유형 · 문자열 테이블

| 유형 | 문자열 수(플레이어 쪽) | 예 |
|---|---|---|
| shared/data(데이터 파일) | 124 (705자) | 장비/보스/보석 이름 · 튜토리얼 문장(`shared/data/TutorialData.lua`) · 보스 힌트(`shared/data/BossData.lua`) |
| shared 로직 모듈 | 188 (1,345자) | 스킬 툴팁 문장 조립(`shared/SkillTooltipText.lua`) · 비교 문구(`shared/EquipCompare.lua`) |
| client 코드 | 821 (8,521자) | 각 패널 · HUD 파일에 흩어진 라벨 · 사유표 · 도움말 |
| server 코드 | 약 68 (화면에 나오는 것) | 1-3 참고 |

- **로컬라이제이션 모듈 · 문자열 테이블: 없다.** `LocalizationService` · `Translator` · `LocalizationTable` · `AutoLocalize` 사용 0건(`grep` 결과 없음).
- 사실상의 "사유표"가 파일마다 따로 있다: `client/panels/Enhance/init.lua:36-38`, `client/panels/GemForge.lua:36-45`, `client/panels/GemWorkshop/init.lua:62-72`, `server/PartyServer.server.lua:34-47`, `server/PartyCrossServer.lua:65-76`, `client/panels/Inherit.lua:46`(REASON_TEXT) 등. 같은 문장이 중복된다: "골드가 부족합니다"(`Enhance/Controller.lua:130`, `Enhance/init.lua:36`, `:76`, `GemForge.lua:42`, `GemWorkshop/init.lua:66`), "보석 가루가 부족합니다 - 보석을 분해하면 얻습니다"(`GemForge.lua:43`, `GemWorkshop/init.lua:67`), "파티가 가득 찼습니다(최대 4인)"(`PartyServer.server.lua:38`, `PartyCrossServer.lua:66`).
- 데이터 쪽에 모인 비율은 문자 수 기준 **약 5%**(705 / 13,497 - 개발 제외 기준으로는 705 / 약 13,400)에 그친다. CLAUDE.md의 "밸런스 수치는 data/"와 달리 문구는 규칙이 없어 코드에 흩어져 있다.

---

## 3. 문자열 이어붙이기 · format · 조사

- **`..` 이어붙이기(한글 포함, 로그 · assert 제외): 51줄**(개발용 제외 파일). 한글 여부 무관 문자열 인접 `..`는 162줄.
- **`("..."):format(...)` 형태(한글 포함, 로그 제외): 314줄**. `string.format(` 형태는 **1줄**뿐이다. 즉 이 프로젝트의 정식 패턴은 메서드형 `:format`이다.
- `%s` 뒤에 한국어 조사가 붙는 포맷 문자열(개발용 제외): 약 25곳.

### 대표 예 10개 (이어붙이기 · 조립)

| # | 위치 | 코드 | 번역 문제 |
|---|---|---|---|
| 1 | client/InventoryUI.client.lua:171 | `"보유 골드 " .. NumberFormat.format(gold)` | 숫자가 들어간 문장이 매번 다른 문자열이 됨(ATC가 값마다 따로 잡음) |
| 2 | client/panels/Inventory/BagTab.lua:269 | `displayName .. " 이하 ▾"` | 어순 고정("Epic or lower") |
| 3 | client/panels/Inventory/DetailSheet.lua:497 / :536 | `described.title .. " (가방)"` / `" (착용 중)"` | 장비 이름 + 상태 합성 |
| 4 | client/panels/Inventory/DetailSheet.lua:573 | `described.meta .. " · 강화대에서 강화"` | 조각 연결 |
| 5 | client/panels/Enhance/Controller.lua:213 | `config.displayName .. " 구매"` | 어순("Buy X") |
| 6 | client/StageSelectPanel.lua:425 / :427 | `"◀ 이전 " .. STEP` / `"다음 " .. STEP .. " ▶"` | 숫자 끼움 |
| 7 | client/StageRewardBand.lua:129 / :131 | `table.concat(segments, " · ") .. " [계정]"` / `.. " ✓ 받음"` + RichText 태그(`:87`) | 태그 안 문장 조각 |
| 8 | client/panels/Party.lua:149 | `table.concat(bonusParts, " · ") .. ". 장비의 경험치 옵션과 곱해집니다."` | 문장 중간을 코드가 만듦 |
| 9 | server/StageServer.server.lua:96 | `"파티 보스 입장 불가 - " .. table.concat(names, ", ")` | 서버발 + 이름 목록 |
| 10 | shared/SkillTooltipText.lua:31 / :136 | `(...):format(value) .. "초"` / `"적용 - " .. critText` | 단위 · 설명 조각(툴팁 전체가 이 방식으로 조립됨) |

### 한국어 조사 처리

- **조사 자동 선택 코드(받침 판별 등): 없다.** "을/를", "이/가", "josa" 검색 0건.
- 병기형 1곳: `client/ClassSelectUI.client.lua:148`, `:163`, `:166` `"%s(으)로 전환합니다"`.
- 고정 조사가 `%s` 뒤에 붙은 곳(받침이 없으면 틀림):
  - `client/hud/DropFeed.client.lua:34` `"★ %s님이 %s %s을 얻었습니다"` - `partName`이 `shared/data/ItemVisualData.lua:97-102`의 갑옷 · 장갑 · 신발 · **무기**. "무기을"이 될 수 있다 [추정: 태초 드랍 알림에 part = weapon이 오는 경로가 있는지는 미확인. 기본값 "장비"(`DropFeed.client.lua:28`)도 "장비을"].
  - `client/panels/Enhance/Controller.lua:133` · `client/panels/Enhance/init.lua:80` `"%s이 부족합니다"` - 현재 재료 이름은 "강화석"/"상급 강화석"(`shared/data/EnhanceMaterialData.lua:14-15`)이라 맞지만 재료를 추가하면 깨진다.
  - `client/panels/Enhance/init.lua:64` `"%s이 막았습니다"`, `:88` `"%s을 샀습니다"` - "…방지권"(`shared/data/EnhanceConfig.lua:79-80`)이라 현재는 맞음.
  - `client/panels/GemForge.lua:402` `"%s의 레벨이 Lv.%d → Lv.%d가 됩니다"` - `%d가`는 숫자 끝자리에 따라 "Lv.30가"처럼 어색(숫자 읽기 "삼십이"가 맞음).
  - `client/panels/GemForge.lua:420` `"가루 %s로"`, `:451`/`:453`/`:455` `"%s를 얻었습니다"`(숫자) · `client/panels/Inventory/DetailSheet.lua:762` `"골드 %s를"` - 숫자 뒤 조사는 읽는 법에 따라 달라짐(예: "가루 10를"→"10을"이 맞음).
- 영어 등으로 번역할 때 이 조사 문제는 사라지지만, 한국어 원문을 유지하는 한 "받침 판별 헬퍼" 또는 조사 없는 문형("획득: %s")으로 바꾸는 게 필요하다.

---

## 4. 이미지 속 글자

- 코드가 참조하는 이미지 에셋은 **스킬 아이콘 8개**뿐이다(`shared/data/SkillIconData.lua:6-21`, 사용처 `client/SkillSlots.client.lua:241`, `:461`). 무기 메시(`shared/data/WeaponModelData.lua:39`, `:50`, `:99-100`)는 3D 메시/텍스처.
- 스킬 아이콘 원본으로 보이는 `Claude outputs/skill_*.png` 4장(대검 E · 치유사 Q · 활 E · 쌍검 Q)을 직접 열어 봤다: **글자 없음**(도형 + 단색 배경). 나머지 4장도 같은 제작물이라 글자가 없을 것으로 본다 [추정: 업로드된 rbxassetid 내용과 로컬 PNG의 동일성은 미확인].
- HUD · 장비 아이콘은 이미지가 아니라 Frame 조합이다(`client/HudIcons.lua:1-16` "이미지 에셋 없이", `client/ItemIcons.lua:1-12`).
- 예약만 된 자리: 광장 문양 데칼 `shared/data/ZoneTerrainData.lua:64`, `:258`(`plazaMark.textureId` 비어 있음). 나중에 문양에 글자를 넣으면 번역 대상 밖이 된다 [추정].
- 결론: **이미지 속 글자 위험은 지금 0.** 대신 글자가 전부 TextLabel이라 번역 대상은 넓다.

---

## 5. 로블록스 자동 번역 조사 · 준비도

### 5-1. 공식 문서 요지

| 항목 | 내용 | 출처 |
|---|---|---|
| 자동 번역 지원 언어 | 문서 기준 **18개**(아랍어 · 중국어 간체/번체 · 영어 · 프랑스어 · 독일어 · 힌디어 · 인도네시아어 · 이탈리아어 · 일본어 · **한국어** · 폴란드어 · 포르투갈어 · 러시아어 · 스페인어 · 태국어 · 터키어 · 베트남어). 2024년 공지 시점엔 16개 언어 **상호** 번역(그 전에는 영어 → 다른 언어만) | [Automatic translation](https://create.roblox.com/docs/production/localization/automatic-translations), [16개 언어 공지](https://devforum.roblox.com/t/automatic-translation-now-available-between-16-languages/2912942) |
| 원문 언어 | 게임당 원문 언어 1개. 자동 번역은 "원문 문자열이 게임의 원문 언어라고 가정" | [Localization 개요](https://create.roblox.com/docs/production/localization) |
| 자동 텍스트 캡처(ATC) | 플레이 중 사용자 · Studio 테스트에서 만난 UI 글씨를 번역 표에 추가. 반영에 **며칠** 걸릴 수 있고, Studio 캡처 도구로는 1~2분 | [Automatic translation](https://create.roblox.com/docs/production/localization/automatic-translations) |
| AutoLocalize | ATC는 AutoLocalize가 켜진 텍스트 객체만 잡는다. 이름 · 고유 문자열은 끄라고 안내 | 같은 문서 · [개요](https://create.roblox.com/docs/production/localization) |
| 자동 번역 안 되는 것 | 이미지 속 글자, 배지/패스 이름, 리더보드, 채팅, 동적 콘텐츠 등 | [Automatic translation](https://create.roblox.com/docs/production/localization/automatic-translations) |
| 수동 번역 우선 | 자동 번역은 **빈 칸만** 채우고 수동 번역을 덮어쓰지 않는다. CSV 내려받기/올리기 · Context 열 | 같은 문서 · [Manual translations](https://create.roblox.com/docs/production/localization/manual-translations) |
| 동적 문자열 | `LocalizationService:GetTranslatorForPlayerAsync`(pcall 권장) → `Translator:FormatByKey("Key", {100})` 또는 이름 인자 `{AmountCash=500}`, 표에서 `{1:int}` 형식 지정 | [Localize with scripting](https://create.roblox.com/docs/production/localization/localize-with-scripting) |
| 이미지 교체 | 언어별 에셋 ID를 표에 넣고 FormatByKey로 받아 `Image`에 넣는 방식 | 같은 문서 |
| ATC 2.0 | 오프라인 일괄 처리 추가 · 안 쓰는 자동 수집 문자열 정리 · 원문 전체를 보고 동적 조각을 덜 깨뜨림(단 예외 케이스 남음) | [ATC 2.0 공지](https://devforum.roblox.com/t/automatic-text-capture-20/2643775) |
| 알려진 문제 | 루프에서 동적으로 넣는 글씨가 캡처 안 되는 사례, 한국어 대상 번역에 한자 섞임 · 깨짐 보고 | [루프 캡처 문제](https://devforum.roblox.com/t/localizationtable-auto-capture-not-registering-ui-strings-generated-in-a-loop/4715459), [한국어 깨짐](https://devforum.roblox.com/t/automatic-translation-issue-when-translated-into-korean-the-letters-are-broken-or-chinese-characters-are-mixed/3900944) |

### 5-2. 이 게임의 준비도

| 구분 | 자동으로 되는 것 | 수작업이 필요한 것 |
|---|---|---|
| 고정 라벨(버튼 · 탭 · 제목: "강화", "재련", "취소" 등) | ATC가 잡아 자동 번역 가능 - AutoLocalize 기본값이 켜짐이고 끈 곳이 0건 | 짧은 단어는 문맥이 없어 오역 위험("강화"=Enhance/Reinforce) → Context 열 · 수동 검수 |
| 숫자 · 이름이 들어간 문장(`:format` 314줄 · `..` 51줄) | 값마다 다른 문자열로 캡처됨("보유 골드 1,234" / "보유 골드 1,240"…) → 표가 오염되고 번역이 거의 안 맞음 [추정: ATC 2.0이 일부 완화] | **Translator:FormatByKey로 전환**(키 + `{1}` 인자) |
| 서버발 문장(약 68개) | 클라 TextLabel/토스트에 그려지면 ATC 대상이 되긴 함 | 문장 대신 코드 + 인자를 보내 클라가 FormatByKey |
| 채팅 시스템 메시지(`client/EnhanceAnnounceClient.client.lua:13`, `client/hud/DropFeed.client.lua:99` - `DisplaySystemMessage`) | 문서상 채팅은 자동 번역 제외 | 클라에서 Translator로 번역 후 전송 |
| 플레이어 이름 · 가짜 이름 · 파티 코드(`client/Nameplate.client.lua:35`, `client/panels/Party.lua:185`, `:365`, 순위표) | - | **AutoLocalize = false** 지정 필요(지금 0곳 → 이름이 "번역"될 위험) |
| RichText 조립(`RichText = true` 8곳: `client/ui/kit/Toast.lua:460`, `client/StageRewardBand.lua:190` 등) | 태그 포함 문자열로 캡처 [추정] | 태그 · 색 조각을 키 인자로 분리 |
| 월드 글씨(BillboardGui · ProximityPrompt `ActionText` - `server/BossTrap.lua:248`) | GuiObject는 ATC 대상, ProximityPrompt도 AutoLocalize 속성이 있다 [추정] | 확인 필요 |
| 이미지 속 글자 | 해당 없음(4절) | - |
| 레이아웃 | - | 영어는 같은 뜻이 한국어보다 길다 [추정 일반론]. 고정 폭 칸(`client/panels/Enhance/OddsView.lua:26` 되는 단계 열 74px, 탭 버튼 폭 112 `GemForge.lua:123`, 확인창 280×140 `RebirthView.lua:100`)에서 잘림 위험. `TextTruncate.AtEnd`(`client/ui/kit/Confirm.lua:46`)는 잘린 걸 숨긴다 |
| 조사 | - | 한국어 원문을 쓰는 한 3절의 고정 조사 정리 |

- 종합: **"켜기만 하면 고정 라벨은 번역되지만, 숫자가 섞인 문장이 대부분이라 체감 번역률은 낮다"** [추정]. 한글 문자열의 다수(314 + 51줄)가 조립형이다.

### 5-3. 필요한 작업 목록 (순서대로)

1. `shared/Strings.lua`(또는 `shared/data/Text*.lua`) 같은 문자열 테이블 1곳 만들기 - 키 → 한국어 원문. 규칙은 CLAUDE.md "밸런스 수치는 data/"와 같은 방식으로 "화면 문구는 data/".
2. 클라 공용 `T(key, args)` 헬퍼: `GetTranslatorForPlayerAsync`(pcall) → `FormatByKey`, 실패하면 원문 표로 폴백.
3. 서버발 약 68개를 **코드 + 인자** 전송으로 전환(`PartyState.notify` · `SaveCoordinator.notify` · 보물상자 알림 등). 이미 코드로 보내는 강화 · 보석 쪽 패턴을 따름.
4. `:format` 314줄 · `..` 51줄을 키 + 인자로 옮김(패널 단위로 나눠 진행 - 7절 우선순위 표의 정보량 많은 창부터).
5. 이름 · 코드 · 숫자만 있는 라벨에 `AutoLocalize = false`.
6. 중복 사유 문장 통합(2절).
7. 고정 폭 UI의 글자 길이 여유 확인(가장 긴 언어 기준) · `TextScaled` 대신 폭 늘리기.
8. 로블록스 번역 표 CSV 내보내기 → 검수 → 올리기 흐름 정리.

### 5-4. 번역 경로 제안: 한국어 원문 → 검수한 영어 기준본 → 다른 언어 자동 번역

로블록스 번역 표에서 **원문 언어(Source)** 를 무엇으로 둘지:

| 기준 | 원문 = 한국어 | 원문 = 영어 |
|---|---|---|
| 개발 흐름 | 지금 코드 그대로 원문. 추가 작업 적음 | 코드의 원문을 영어로 바꾸거나 표의 Source를 영어로 관리해야 함(한국어는 "번역"이 됨) |
| 한국어 플레이어 | 원문 그대로 보임 - 품질 최고 | 한국어도 번역 칸이 되므로 수동 한국어 번역을 다 채워야 함(안 채우면 영→한 자동 번역이 보임 - 한국어 깨짐 보고 있음) |
| 다른 언어 자동 번역 품질 | 한→X 직역. 2024년에야 상호 번역이 열렸고 대부분의 모델 학습이 영어 중심이라 품질이 낮을 가능성 [추정] | 영→X가 로블록스 자동 번역의 원래 경로(공지: "이전엔 영어 → 다른 언어만") - 가장 검증된 경로 |
| "검수한 영어 기준본" 활용 | 영어는 수동 번역 칸에 넣을 수 있지만, 다른 언어 자동 번역은 **원문(한국어)** 에서 나온다 → 영어 검수본이 다른 언어 품질에 기여하지 않음 [추정: 문서가 "원문 문자열을 원문 언어로 가정"하고 번역한다고만 적음] | 검수한 영어가 곧 원문이라 모든 자동 번역이 그 영어에서 출발 → 제안한 경로와 정확히 일치 |
| 용어 일관성(강화 · 재련 · 불씨 등 고유어) | 한국어 신조어가 언어마다 제각각 번역될 위험 | 영어 용어집을 한 번 정하면 전 언어에 전파 |
| 유지 비용 | 새 문구 추가 시 한국어만 쓰면 끝 | 새 문구마다 영어 원문 + 한국어 번역 두 벌 |

- 추천 [판단]: **제안한 3단 경로를 쓰려면 원문을 영어로 두는 편이 맞다.** 원문을 한국어로 두면 "검수한 영어"는 영어 칸 하나만 좋아지고, 다른 언어는 여전히 한국어에서 자동 번역된다. 절충안: 코드 원문은 한국어 유지 + 문자열 테이블에 `ko`/`en` 두 벌을 두고, 로블록스 표에는 **영어를 Source, 한국어를 수동 번역**으로 CSV 업로드(한국어 칸이 채워져 있으면 자동 번역이 덮지 않음).

---

## 6. 문구 문제 위치

### 6-1. 보석 "재련에 먹일 보석"

- **정확히 "재련에 먹일 보석"이라는 문자열은 없다**(`grep "재련에 먹일"` 0건, PRD에도 없음). 가장 가까운 것은 보석상인 창이 아니라 **보석 가공 창(GemForge)의 [재련] 탭**이다:
  - `client/panels/GemForge.lua:263` `"먹일 보석(대상보다 레벨이 높은 가방 보석 %d개 - 먹인 보석은 사라집니다)"`
  - `client/panels/GemForge.lua:319` `"먹일 보석을 고르세요"`(비용 줄)
  - `client/panels/GemForge.lua:41` `no_gain = "먹일 보석의 레벨이 대상보다 높아야 합니다"`, `:40` `"같은 보석은 먹일 수 없습니다"`
  - 행 버튼 `"먹이기"`(`GemForge.lua:270`), 확인창 `"먹인 보석(%s)은 사라집니다"`(`:402`), 도움말 `"더 높은 레벨의 보석을 먹여"`(`:112`)
- 참고: 보석상인 창(`client/panels/GemWorkshop/init.lua`)은 변환권 구매 · 리롤만 하고 "먹이" 문구가 없다(`GemWorkshop/init.lua:221-258`, `:304`). 보석 가공 창은 가방 상세 시트의 [재련] 버튼이 연다(`client/panels/Inventory/DetailSheet.lua:237`, `:874`).
- 기능(코드): 대상 보석 A와 재료 보석 B를 고르면, B의 레벨이 A보다 높을 때만(`shared/GemCraft.lua:75`) A의 `itemLevel`을 **B의 레벨로 바꾸고**(`shared/GemCraft.lua:95` `gem.itemLevel = fodder.itemLevel`) A의 옵션 종류 · 굴림은 그대로 둔 채 수치만 새 레벨로 다시 계산된다. B는 사라지고 골드 + 가루를 낸다(`GemForge.lua:398`, `:401-405`). 즉 "B를 소모해 A의 레벨을 B 레벨까지 끌어올림". B의 등급은 조건에 안 들어간다.
- 대체 문구 제안:
  1. **"재료 보석(대상보다 레벨 높은 보석 %d개 · 사용하면 사라짐)"** / 비용 줄 "재료로 쓸 보석을 고르세요" / 행 버튼 "재료로"
  2. **"레벨을 넘겨줄 보석(%d개 · 넘겨준 보석은 사라짐)"** / 비용 줄 "레벨을 넘겨줄 보석을 고르세요" / 행 버튼 "선택" - 결과("대상 레벨이 이 보석의 레벨이 된다")가 문구에 바로 드러남.

### 6-2. 강화대 "되는 단계"

- 화면에 보이는 곳은 **1곳**: `client/panels/Enhance/OddsView.lua:79` `local header = { ..., level = "되는 단계" }`(확률표 3열 머리).
- 그 밖의 출현(화면 아님):
  - 코드 주석: `client/panels/Enhance/OddsView.lua:2`, `:26`, `shared/Enhance.lua:137`(`:122`의 "위험이 시작되는 단계"는 다른 뜻)
  - 검증 로그: `server/EnhanceOddsVerify.lua:3`, `:76`, `:84`
  - 문서: `PRD-forge-game-roblox.md` 8곳(11223, 11241, 11528, 14892, 15913 등), `docs/sonnet/S07-enhance-ui.md` 3곳, `docs/sonnet/README.md:25`
- 주의 [판단]: 이 열은 5행 전부(성공 · 유지 · 1강 하락 · 2강 하락 · 초기화 - `OddsView.lua:15-19`)의 결과 단계를 보여준다. 머리를 "성공 시"로 바꾸면 실패 행에도 "성공 시"가 걸려 틀린 뜻이 된다. "성공 시"로 통일하려면:
  - 안 A: 3열 머리를 **"결과"**(또는 "강화 후")로, 행 이름을 "성공 시 · 실패 시(유지) · 실패 시(1강 하락)…"로 바꿈(`OddsView.lua:15-19`, `:79`).
  - 안 B: 1열 머리 "결과" → "경우", 3열 "되는 단계" → "→ 단계".
  - 문서 · 주석 · 검증 로그 문구(`EnhanceOddsVerify.lua:84`)는 화면 변경 뒤 함께 맞춤.
- 관련 문구: 창 제목 `"%s 등급 · +%d → +%d · 최대 +%d"`(`client/panels/Enhance/init.lua:101`)이 이미 "성공 시 +N+1"을 화살표로 보여준다.

### 6-3. 환생 "레벨 1 초기화" 안내

| 위치 | 문구 | 글씨 크기 · 색 |
|---|---|---|
| 강화대 환생 탭 정보 줄 `client/panels/Enhance/RebirthView.lua:153` | "환생 %d/%d회 · 현재 레벨 %d\n필요 레벨 %d - **레벨을 1로 초기화하고** 무기 등급·보석 슬롯을 1단계 올립니다.\n경험치 배수 ×%g → ×%g" | TextSize 16, Gotham, **흰색**(`:49-51`) - 다른 줄과 똑같은 모양, 강조 없음 |
| 강화대 환생 확인창 `RebirthView.lua:14`(+ `:103-125`) | "정말 환생하시겠습니까?\n레벨과 무한 스테이지가 1로 초기화됩니다 - 되돌릴 수 없습니다." | TextSize **15**, Gotham, 흰색(`:109-112`) · 창 280×140(`:100`) · 확인 버튼 "환생한다"가 **금색**(200,160,40 - `:123`) - 위험 버튼 모양 아님 |
| 환생 제단 확인창 `client/RebirthAltar.client.lua:36-43` | 위 confirmText + "환생 %d/%d회 · 현재 레벨 · 필요 레벨 · 경험치 배수" | 공용 Confirm의 본문 = `body` 단(14, 모바일 16 - `client/ui/kit/Theme.lua:19`, `:53`), `textPrimary`(`client/ui/kit/Confirm.lua:42`), `danger = true`라 주 버튼만 빨강 |

- 강도 평가 [판단]: 확인창에 "1로 초기화" + "되돌릴 수 없습니다"가 **있다**. 하지만 ① 본문과 같은 흰 글씨 한 줄, ② 강화대 경로는 주 버튼이 금색(보상 느낌), ③ 무엇이 유지되는지(골드 · 장비 · 강화 단계 · 최고 기록)가 없어 "다 날아가나?" 불안과 "레벨만?" 과소평가가 둘 다 생김. 서버 실제 동작: 경험치 0 · 무한 스테이지 1 · 최고 기록 유지 · 무기 등급 = 회차 · 새 슬롯 보석 지급(`server/PlayerProfile.lua:725-744`).
- 제안 문구(확인창):
  - 제목: **"환생 - 레벨이 1이 됩니다"**
  - 1줄(danger 색): **"레벨 %d → 1 · 무한 스테이지 %d → 1 (되돌릴 수 없음)"**
  - 2줄(success 색): "얻는 것: 무기 등급 +1 · 보석 칸 1개 + 보석 1개 · 경험치 ×%g → ×%g"
  - 3줄(보조 색): "유지: 골드 · 가방 · 강화 단계 · 최고 스테이지 기록" [추정: 골드 · 가방 · 강화 단계 유지는 `PlayerProfile.rebirth`가 해당 필드를 건드리지 않는 것(`:709-744`)으로 판단 - 다른 경로 미확인]
  - 강화대 경로 확인 버튼도 Confirm 킷의 danger 모양으로 통일.
- 덤(문구와 별개로 발견): 제단 확인창의 경험치 배수는 `×%d → ×%d`에 `rebirthCount + 1, rebirthCount + 2`를 **직접 계산**(`client/RebirthAltar.client.lua:38-39`)하고, 강화대는 `CharacterLevel.getRebirthExpMultiplier`를 쓴다(`RebirthView.lua:153-155`). 지금 값표가 `{1,2,3,4,5,6}`(`shared/data/CharacterLevelConfig.lua:115`)이라 우연히 같지만 표를 바꾸면 두 창이 다른 숫자를 보인다.

### 6-4. ? 도움말 버튼 목록

| # | 위치 | 본문 길이(공백 포함) | 명쾌하지 않은 곳 [판단 근거] |
|---|---|---|---|
| 1 | 강화대 `client/panels/Enhance/init.lua:50`(→ `:243`) | 약 98자(값 대입 후) | "22강부터 초기화(12강)" - 괄호가 "12강으로 떨어진다"는 뜻인지 모호 → "22강부터 실패 시 12강으로 초기화" |
| 2 | 보석 가공 `client/panels/GemForge.lua:112` | 141자 | "레벨이 **낮아진** 보석" - 보석 레벨이 떨어지는 규칙이 없는데(`GemCraft.refinedGem`은 올리기만) 낮아졌다는 표현, "굴림 위치" · "먹여" 은어 |
| 3 | 보석 공방(상인) `client/panels/GemWorkshop/init.lua:304` | 90자 | "변환권은 이곳에서 **골드로** 삽니다" - 실제 가격은 골드 + 보석 가루(`GemWorkshop/init.lua:221`, `:230`). 사실과 다름 |
| 4 | 장비 계승 `client/panels/Inherit.lua:102` | 92자 | "굴림 위치" 은어 · "분해 재료로 돌려받습니다" - 무엇(가루? 골드?)을 받는지 없음 |
| 5 | 가방 옵션 합계 `client/panels/Inventory/GearTab.lua:105-106` | 35자 | 명확 |
| 6 | 가방 보석 탭 머리 `client/panels/Inventory/GemHeader.lua:57-59` | 81자 | 명확(장소 안내) |
| 7 | 순위표 `client/panels/Leaderboard.lua:145` | 84자 | "자기 최고 다음 보스를 깨고" - "지금 기록보다 한 단계 위 보스" 뜻이 바로 안 읽힘 |
| 8 | 성장 보상 `client/panels/Milestones.lua:33-35` | 템플릿 172자 · 값 대입 후 약 180자 | "한 버킷에 더해지고" · "스테이지 10칸분" - 개발 용어(버킷) · 설명 없는 단위. 두 문단이 한 덩어리 |
| 9 | 파티 창 `client/panels/Party.lua:145-154` | 템플릿 252자(4개 소제목) | 가장 김. 280×176 패널(`:154`)에 12px 약 22자/줄 → 12줄 이상으로 빠듯 [추정]. "기여 %d%%"가 무엇의 %인지 첫 줄에 없음 |
| 10 | 스테이지 보상 띠 `client/StageRewardBand.lua:197`(본문 `:65-70`) | 등급별 "이름 확률%" 줄(약 5~6줄 · 50자 안팎 [추정]) | 명확(확률표) |
| 공용 | `client/ui/kit/Panel.lua:93-96`(help 속성 → `HelpToggle` `client/ui/kit/HelpToggle.lua:12`) | - | - |

### 6-5. 글자 수 기준 정보량 과다 화면 상위 10

- 방법: 화면(패널)을 이루는 파일들의 한글 글자 수를 셈. "상한"은 파일 안 모든 한글(사유표 · 결과 문구 포함), "상시 추정"은 사유표(`key = "..."`) · 상태 · 토스트 · 확인창 본문 · 로그를 뺀 값(`vis.py`). **한 번에 보이는 양은 [추정]**.

| 순위 | 화면 | 상한(자) | 상시 추정(자) | 비고 |
|---|---|---|---|---|
| 1 | 스킬 툴팁(Q/E) `shared/SkillTooltipText.lua` + `client/hud/SkillTooltip.lua` | 1,078 | 1,045 (8개 스킬 → 툴팁 1개당 약 130) | 조립형 문장(`SkillTooltipText.lua:136-145`) |
| 2 | 가방(장비/보석/상세) `client/panels/Inventory/*` + `shared/EquipCompare.lua` + `shared/ItemDescribe.lua` | 821 | 517 | 탭 여러 개 합 |
| 3 | 스테이지 선택 + 보상 띠 `client/StageSelectPanel.lua` + `client/StageRewardBand.lua` | 605 | 457 | 보상 줄 조립 |
| 4 | 파티 창 `client/panels/Party.lua` | 412 | 410 | 도움말 252자 포함 |
| 5 | 견습 튜토리얼 `shared/data/TutorialData.lua` + `client/TutorialHud.client.lua` | 323 | 319 | 문장당 길다(8개 문자열 298자) |
| 6 | 성장 보상 `client/panels/Milestones.lua` + `shared/data/MilestoneData.lua` | 317 | 215 | 도움말 약 180자 |
| 7 | 보석 가공 `client/panels/GemForge.lua` | 534 | 203 | 사유 · 확인창 많음 |
| 8 | 순위표 `client/panels/Leaderboard.lua` | 413 | 192 | |
| 9 | 강화대(강화 탭) `client/panels/Enhance/{init,Controller,OddsView,CostView,TicketView}.lua` | 488 | 128 + 도움말 98 | 확률표 5행 + 안내 2줄(`Controller.lua:156`, `:159`, `OddsView.lua:167`) |
| 10 | 장비 계승 `client/panels/Inherit.lua` | 436 | 112 + 도움말 92 | |
| (참고) | 강화대 환생 탭 `RebirthView.lua` 170/107 · 보석 공방 355/99 · 살펴보기 134/77 · 직업 선택 113/113 | | | |

---

## 7. 3타 강타 표시 - 현재 구현

- **표시(클라)**: `client/AttackInput.client.lua:34-91`. 점 3개(`COMBO_PIP_COUNT = CombatConfig.comboHitEvery`, 크기 10px · 간격 6px - `:40-45`)를 `Frame + UICorner`로 만들어 `PlayerHealthBarGui.ComboPipsAnchor`(`:39`)에 붙인다. 앵커는 **화면 하단 내 체력바 바로 위의 ScreenGui 프레임**(`client/PlayerHealthBar.client.lua:71`, `:90-99`) - 월드 공간이 아니다.
- 갱신: 서버 `ComboUpdate`(comboCount, isHeavyHit) 수신 시 `((comboCount-1) % 3)+1`개를 켬 - 켠 색은 `UIColors.ember`, 3번째(강타)면 노랑(255,230,90)(`AttackInput.client.lua:79-91`).
- **서버 규칙 정의**: `server/AttackServer.server.lua:62-66`(카운터 선언), `:134-143`(갱신 · 판정 · `comboUpdate:FireClient`), `:180-183`(`base *= CombatConfig.comboHitMultiplier`). 수치는 `shared/data/CombatConfig.lua:73-77`(`comboHitEvery = 3`, `comboHitMultiplier = 1.8`, `comboResetWindowSeconds = 2`).
- 어떤 직업/평타: 모든 직업의 **평타 요청(AttackRequest) 한 곳**에서 처리 - 직업 분기 없음(`AttackServer.server.lua:134-143`는 classId와 무관). 클라 모션 예측은 `AttackInput.client.lua:101-118`.
- 설계상 중요한 성질:
  1. 카운터는 **공격자별**(`comboCounts[player]`)이고 **대상별이 아니다**. 헛스윙(대상 없음)도 센다(`:62-64` 주석, `:134` "헛스윙도 포함"). 3번째 스윙이 어느 몹에 맞든 강타다.
  2. 본인에게만 보낸다(`FireClient(player, ...)` `:143`) - 다른 파티원은 내 점을 못 본다.
  3. **2초 리셋이 화면에 반영되지 않는다**: 클라에는 리셋 타이머가 없어(`:79-91`은 이벤트 때만 갱신) 2초 넘게 쉬면 점 2개가 켜진 채 남아 있다가, 다음 공격에서 갑자기 1개로 바뀐다 [코드로 확인, 실제 화면 미확인].
  4. PRD 기록상 콤보 점 자리가 화면 중앙(C 구역)을 10px 침범하는 미결이 있다(`PRD-forge-game-roblox.md:15835`, `:15852`).

## 8. 탑다운 카메라용 대안

### 8-1. 사례

- LoL 베인 은화살(Silver Bolts): 같은 대상에 3타 누적 시 추가 피해, **대상에 누적 표식**, 다른 대상을 치면 초기화 - [LoL Wiki Vayne](https://wiki.leagueoflegends.com/en-us/Vayne), [Silver Bolts 데이터](https://wiki.leagueoflegends.com/en-us/Template:Data_Vayne/Silver_Bolts). (위키 검색 결과로는 표식 모양 설명을 확인 못 함 - 대상 머리 위 원형 표식 [추정: 플레이 경험 기반 일반 지식])
- WoW 콤보 포인트: **대상 이름표 위** 또는 **개인 자원 표시(내 캐릭터 발 아래/아래쪽)** 중 고름 - [WoW 포럼: 대상 이름표 콤보 포인트](https://us.forums.blizzard.com/en/wow/t/combo-points-on-nameplate/2231621), [MMO-Champion 토론](https://www.mmo-champion.com/threads/2494573-Combo-points-on-target-nameplate-resource-display)
- 디아블로 · 로스트아크: 3타 평타 체인/스택형 자원을 **내 캐릭터 기준 HUD 또는 캐릭터 주변 이펙트**로 보이는 방식 [추정: 공식 링크 미확보]

- 핵심 판단: 이 게임의 강타는 **대상 누적(베인형)이 아니라 공격자 리듬(WoW 개인 자원형)** 이다(7절 성질 1). "대상 발밑 고리"는 대상을 바꾸면 누적이 끊긴다는 잘못된 신호를 준다 → 규칙을 대상별로 바꾸지 않는 한 **내 캐릭터 기준 표시**가 맞다.

### 8-2. 비교표

| 안 | 모습 | 가독성(탑다운) | 12인 파티 "누구 것" 구분 | 12인 성능 | 규칙과의 일치 |
|---|---|---|---|---|---|
| 현재: 체력바 위 점 3개(ScreenGui) | 화면 하단 점 | 눈이 캐릭터 → 화면 하단을 오가야 함, 10px 작음 | 본인만 봄 → 혼동 없음 | 인스턴스 7개(프레임 4 + 코너 3 + 레이아웃) · 본인만 → 사실상 0 | 일치 |
| A: **내 캐릭터 발밑 3칸 고리** | 발밑 원을 3조각, 한 타마다 한 조각, 3번째에 고리 전체 번쩍 | 시선이 캐릭터에 머무름 - 탑다운에 가장 잘 맞음 | **로컬 클라에서만 만들면** 남에겐 안 보임 → 혼동 0. 남에게도 보여야 하면 색/두께로 "내 것"만 강조 | 파트 1개 + 텍스처/데칼 3장(또는 SurfaceGui 1개), 로컬 1세트 → 12인이어도 클라당 1세트 | 일치 |
| B: 대상 발밑/머리 위 누적 고리(베인형) | 맞은 몹에 1~3 표식 | 대상에 집중할 때 좋음 | 같은 몹을 여럿이 치면 **누구 누적인지 구분 불가**(12인에서 최악). 로컬 전용으로 해도 "헛스윙 · 대상 바꿔도 유지" 규칙과 어긋남 | 몹마다 BillboardGui → 몹 수 × 1개, 기존 이름표 · 데미지 숫자 BillboardGui(13곳에서 생성)와 겹쳐 비용 증가 | **불일치**(규칙을 대상별로 바꿔야 함) |
| C: 조준 대상 하이라이트 색 변경 | 3번째 스윙 준비 시 지금 조준 중인 몹의 Highlight 색을 강타색으로 | 추가 UI 없이 "다음 타가 강타"만 알림 | 로컬 전용 → 혼동 0 | 이미 있는 조준 Highlight 재사용(`client/AimTarget.lua:1-4`) → 인스턴스 +0 | 대체로 일치(1·2타 진행도는 못 보임) |

- 성능 참고: BillboardGui는 개수가 많을 때 프레임 하락 보고가 여럿 있다 - [BillboardGui vs SurfaceGui](https://devforum.roblox.com/t/difference-in-performance-between-surfacegui-and-billboardgui/582933), [BillboardGui 부하](https://devforum.roblox.com/t/are-billboard-guis-performance-heavy/1836884), [SurfaceGui vs 텍스처](https://devforum.roblox.com/t/which-is-less-laggy-surfacegui-or-textures/3982685). 정량 비교는 미확보 [추정: 로컬 1세트면 어느 방식이든 무시 가능한 수준].

### 8-3. 추천

- **A(내 발밑 3칸 고리, 로컬 전용) + C(3번째 준비 시 조준 하이라이트 색)** 조합. 규칙(공격자별 · 헛스윙 포함)과 일치하고, 12인에서 누구 것인지 헷갈릴 일이 없으며(본인 화면에만 있음), 인스턴스는 클라당 1세트다.
- 구현 시 함께 고칠 것: 2초 리셋을 클라에서도 타이머로 반영(7절 성질 3). 그리기는 CLAUDE.md 규칙상 표시 전용 모듈 한 곳에 둔다. 고리 반경 · 색은 `shared/data/`에 둔다.
- B(베인형)는 강타 규칙을 "같은 대상 3타"로 바꾸는 **게임 설계 결정**이 먼저 필요 - 사용자 결정 사항.
