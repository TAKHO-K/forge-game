# 패치 노트 v1.0 초안 (QUEUE-ALL5 F · 2026-10-01)

> 출시 첫 패치 노트. 게임 안에 **지금 있는 것만** 적었다 - 각 줄의 근거 파일을 괄호에 둔다(공개본에서는 괄호를 지운다).
> 게임 이름 `{게임 이름}` · 공개일 `{날짜}`는 결정 대기.

---

## 한국어

### {게임 이름} v1.0 - 출시 ({날짜})

**세계**
- 큰 나무 마을(허브)과 6개 구역: 석조 평원 · 수정 동굴 · 수몰 사원 · 모래 유적 · 폭풍 첨탑 · 빙하 동굴 (`WorldMapData.checkpoints`)
- 5스테이지마다 관문 보스 6종: 구간 수호자 · 서리 거인 · 심해 군주 · 수정 여왕 · 전갈 여왕 · 폭풍 군주 - 보스마다 다른 기믹 (`BossData`)
- 체크포인트 7곳 순간이동 · 마을 귀환(B) + 5분 안 [돌아가기] 1회 (`WorldMapData.travel` · `checkpoints`)
- 덩굴 리프트로 큰 나무 정거장 오르기 (`TextData` `lift.*`)

**성장**
- 직업 4개: 검사 · 도적 · 궁수 · 치유사 - 언제든 바꾸기 (`ClassData`)
- 무기 강화 +30 · 불씨(실패가 쌓이면 확정 성공) · 하락 / 초기화 방지권 (`EnhanceConfig`)
- 장비 8등급(일반 ~ 초월) · 태초 세계 번호 · 초월 전 서버 알림 · 명예의 전당 (`ArmorData` · `TranscendentData`)
- 환생 5회(레벨 25 · 50 · 75 · 100 · 125) - 환생마다 보석 홈 1칸 · 새 이동 기술 (`CharacterLevelConfig.rebirth` · `GemData` · `MovementUnlockData`)
- 보석 5홈 · 재련 · 분해 · 보석상인 리롤 (`GemData`)
- 계승(옵션을 새 장비로 옮기기) · 수련 · 성장 보상 (`InheritConfig` · `TrainingData` · `MilestoneData`)

**함께 하기**
- 파티 최대 4명 · 다른 서버 친구 초대(파티 코드) · 파티 모집 게시판 (`PartyConfig`)
- 균열 시간 매일 2번(한국 10:00 · 20:00, 20분) - 전설 · 유물 · 고대 1.5배 (`RiftData`)
- 전 서버 합동 목표 · 주간 도전 순위 · 시즌 순위 (`CommunityGoalData` · `WeeklyChallengeData` · `LeaderboardConfig`)
- 함께 부수는 보물상자 (`TreasureChestConfig`)

**모으기**
- 도감(장비 · 몬스터 · 보스 · 펫 · 탐험 · 칭호) (`CodexData`)
- 비밀 둥지 · 알 3등급 · 펫 24종 부화 · 펫 동행 (`EggData` · `PetData` · `NestData`)
- 7일 출석 보상 · 일간 / 주간 / 메인 퀘스트 (`QuestData`)

**상점 · 시즌**
- 골드 상점: 방지권 · 변환권(전투력 판매 없음) (`MonetizationData`)
- 치장: 테마 세트 · 글라이더 스킨 - 반짝 조각 또는 로벅스 (`CosmeticSlotData` · `MonetizationData`)
- 편의 패스: 가방 확장 · 줍기 반경 · 빠른 귀환 · 이름표 색 / 배지 - 전투력 · 획득량은 그대로 (`MonetizationData.passes`)
- 시즌 1 패스 40칸(무료 · 유료 줄) - 시즌 한정 구름 고래 글라이더 (`SeasonPassData`)
- 모든 확률은 [확률 공개] 창에서 확인 (`TextData` `prob.*`)

**편의 · 설정**
- 연출 세기 · 화면 흔들림 · 번쩍임 줄이기 · 탑다운 시점 · 소리 5종 (`SettingsData`)
- 폰 화면 버튼 · 길게 눌러 이름 보기 (`TextData` `settings.hotkeysPhone`)
- 도움말 백과사전(보스 기믹 그림 카드 포함) (`HelpCodexData`)

**출시 기념 코드**: `FORGE2026` · `RIFTOPEN` - 자세한 내용은 업데이트 게시판

---

## English

### {Game Name} v1.0 - Launch ({Date})

**World**
- Big Tree Town (hub) and 6 zones: Stone Plains · Crystal Cave · Sunken Temple · Sand Ruins · Storm Spire · Glacier Cave
- 6 gate bosses, one every 5 stages: Section Guardian · Frost Giant · Abyssal Lord · Crystal Queen · Scorpion Queen · Storm Lord - each with its own Mechanic
- Teleport to 7 checkpoints · Recall to town (B) and [Return] once within 5 minutes
- Ride the Vine Lift up the Big Tree

**Growth**
- 4 classes: Swordsman · Rogue · Archer · Healer - switch anytime
- Weapon Enhance up to +30 · Ember (fails add up to a sure success) · Drop / Reset Protection Tickets
- 8 gear grades (Common to Transcendent) · Primordial world numbers · server-wide Transcendent alerts · Hall of Fame
- 5 Rebirths (Lv 25 · 50 · 75 · 100 · 125) - each opens a Socket and a new move
- 5 weapon Sockets · Refine · Salvage · Reroll at the Gem Merchant
- Inherit (move options to new gear) · Training · Growth Rewards

**Play together**
- Parties of up to 4 · invite friends from other servers (party code) · Party Board
- Rift Time twice a day (01:00 · 11:00 UTC, 20 min) - 1.5× Legendary, Relic, Ancient
- Server Co-op Goal · Weekly Challenge ranks · Season ranks
- Treasure chests you break together

**Collect**
- Codex (gear · monsters · bosses · pets · explore · titles)
- Secret nests · 3 egg grades · 24 pets to hatch · a pet that follows you
- 7-day check-in rewards · daily / weekly / main quests

**Shop · Season**
- Gold shop: Protection Tickets and Reroll Tickets (no power for sale)
- Looks: Theme Sets and Glider Skins - Sparkle Shards or Robux
- Perk passes: Bag Upgrade · Pickup Range · Fast Recall · Nameplate Color / Badge - no power or drop boost
- Season 1 Pass with 40 tiers (free and paid tracks) - season-only Cloud Whale glider
- See every drop rate in the [Odds] window

**Settings**
- Effects level · screen shake · fewer flashes · top-down camera · 5 volume sliders
- On-screen buttons for phones · hold a button to see its name
- Help Guide (with picture cards for every boss Mechanic)

**Launch codes**: `FORGE2026` · `RIFTOPEN` - see the update board for details

---

> 메모: 구역 이름 영어(Stone Plains 등)는 TextData에 없는 첫 제안이다(구역 이름 = `EggData.zones` · `WorldMapData.checkpoints`의 한국어 데이터 값). 용어집 등록 전에 정할 것. 소리 "5종" = 설정의 음악 · 효과음 · 환경 · 보스 전조 · UI(`settings.volume.*`).
