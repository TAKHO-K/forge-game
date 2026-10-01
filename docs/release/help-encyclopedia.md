# 도움말 백과사전 항목 초안 (QUEUE-ALL5 F · 2026-10-01)

> 게임 안 도움말 창(`client/panels/Help.lua` · 항목 데이터 `shared/data/HelpCodexData.lua`)에 넣을 **글 초안**이다. 지금 창에 있는 분류(기본 조작 · 강화 · 보스 기믹 · 사냥 규칙 · 펫 · 알)에 더해 장비 등급 · 보석 · 직업 · 파티 · 체크포인트/귀환 · 시즌 패스 · 치장을 새로 쓴다.
> 모든 숫자는 아래 "근거" 파일에서 읽었다. 실제로 넣을 때는 **숫자를 문장에 박지 말고** `{자리}`로 두고 Help 창의 ARGS 규칙이 데이터에서 읽게 한다(HelpCodexData 머리 주석 규칙). 한 줄 40자 이하 · 한 문장 한 행동 규칙을 따랐다.
> 용어는 `docs/i18n/glossary.md`(QUEUE-ALL5 F 결정 포함)를 따른다.

---

## 1. 강화 / Enhance
근거: `shared/data/EnhanceConfig.lua`(maxLevel 30 · probability · downFloorLevel 18 · resetToLevel 12 · gauge · protection)

| 한국어 | English |
|---|---|
| 강화대에서 무기를 최대 +30까지 강화해요. | Enhance your weapon at the Forge, up to +30. |
| 0 ~ 18강은 실패해도 단계가 그대로예요. | At +0 to +18, a fail keeps your level. |
| 19강부터는 실패하면 단계가 내려갈 수 있어요. | From +19, a fail can drop your level. |
| 22강부터는 실패하면 12강이 될 수 있어요. | From +22, a fail can reset you to +12. |
| 실패할 때마다 불씨가 차요. 가득 차면 다음 강화는 꼭 성공해요. | Each fail fills the Ember. When full, your next try always works. |
| 하락 방지권(19강부터)과 초기화 방지권(22강부터)은 실제로 막았을 때만 1장 써요. | Drop Guard (from +19) and Reset Guard (from +22) are used only when they block. |
| 방지권은 골드로만 사요. | Protection Tickets cost gold only. |

## 2. 장비 등급 / Gear Grades
근거: `shared/data/ArmorData.lua`(grades · bulkSellMaxGrade = legendary) · `shared/data/TranscendentData.lua` · `shared/data/PrimordialData.lua`

| 한국어 | English |
|---|---|
| 등급은 아래부터 일반 · 희귀 · 영웅 · 전설 · 유물 · 고대 · 태초 · 초월이에요. | Grades from low to high: Common · Rare · Epic · Legendary · Relic · Ancient · Primordial · Transcendent. |
| 부위는 갑옷 · 장갑 · 신발이에요. 무기는 강화로 키워요. | Gear slots are Armor, Gloves, and Shoes. Your weapon grows by Enhance. |
| 태초 장비에는 세계 몇 번째인지 번호가 새겨져요. | Primordial gear is stamped with its world number. |
| 초월 장비가 나오면 모든 서버에 알림이 가요. | When Transcendent gear drops, every server is told. |
| 일괄 판매는 전설 등급 이하만 고를 수 있어요. | Sell All works on Legendary and below. |
| 잠근 장비는 분해 · 판매 · 계승 재료로 쓸 수 없어요. | Locked gear can't be salvaged, sold, or used to Inherit. |

## 3. 보석 / Gems
근거: `shared/data/GemData.lua`(maxRebirthCount 5 · slotGradeCap · slotUnlockRequiredRebirth) · `shared/data/TextData_forge.lua`(재련 · 변환권 문구)

| 한국어 | English |
|---|---|
| 무기에는 보석 홈이 5개 있어요. | Your weapon has 5 Sockets. |
| 환생할 때마다 홈이 하나씩 열려요(1번 홈 = 환생 1회). | Each Rebirth opens one Socket (Socket 1 = Rebirth 1). |
| 홈마다 받을 수 있는 최고 등급이 있어요. 그 아래 보석은 다 들어가요. | Each Socket has a max grade. Any gem up to it fits. |
| 1번 홈이 열리면 태초 보석 하나를 바로 받아요. | When Socket 1 opens, you get a Primordial gem. |
| 재련: 레벨이 더 높은 보석을 넣으면 대상 보석이 그 레벨이 돼요. | Refine: Add a higher-level gem to raise the target to that level. |
| 분해하면 보석 가루가 나와요. 가루로 재련하고 변환권을 사요. | Salvage gems for Gem Dust. Use it to Refine and buy Reroll Tickets. |
| 고대 · 태초 보석의 옵션은 보석상인에게서 변환권으로 다시 굴려요. | Reroll Ancient and Primordial options at the Gem Merchant with a Reroll Ticket. |

## 4. 직업 / Classes
근거: `shared/data/ClassData.lua`(order · displayName · rangeMultiplier) · `shared/data/SkillData.lua` · `shared/data/TextData_panels.lua`(`ui.class.hint`)

| 한국어 | English |
|---|---|
| 직업은 검사 · 도적 · 궁수 · 치유사 4개예요. | There are 4 classes: Swordsman, Rogue, Archer, and Healer. |
| 검사는 단단하고 한 방이 세요. | The Swordsman is tough and hits hard. |
| 도적은 사거리가 가장 짧지만 혼자 때리는 힘이 가장 세요. | The Rogue has the shortest reach but the best single-target damage. |
| 궁수와 치유사는 멀리서 공격해요. | The Archer and Healer attack from far away. |
| 치유사는 파티를 회복하고 파티 피해를 올려 줘요. | The Healer heals the party and boosts party damage. |
| 스킬은 Q · E · R, 궁극기는 T예요. 궁극기 게이지는 적을 치면 차요. | Skills are Q, E, R. T is your Ultimate. Hit enemies to fill its gauge. |
| 직업은 언제든 바꿀 수 있어요. 골드와 가방은 그대로예요. | You can change class anytime. Your gold and bag stay. |

> 메모: 직업 영어 이름(Swordsman · Rogue · Archer · Healer)은 출시 설명 초안(`Claude outputs/QUEUE-ALL2/launch/description-drafts.md`)의 표기를 따랐다. `glossary.md`의 "대검 · 쌍검 · 활 = Greatsword · Dual Blades · Bow"는 옛 표시 이름이라 정리 필요(결정 대기 - 직업 이름은 `ClassData.displayName`이라 TextData 밖).

## 5. 보스 기믹 / Boss Mechanics
근거: `shared/data/BossData.lua`(bosses · intro · stageInterval 5) · `shared/data/HelpCodexData.lua`(gimmickCards) · `shared/data/TextData_en.lua`(`gimmick.*`)

| 한국어 | English |
|---|---|
| 5스테이지마다 관문 보스가 있어요. | A gate boss waits every 5 stages. |
| 보스마다 전멸 기술(기믹)이 하나씩 있어요. 처음 만나면 카드로 알려 줘요. | Each boss has one big Mechanic. A card shows it the first time. |
| 구간 수호자 - 금 간 조각이 무너져요. 옆 조각으로 가요! | Section Guardian - Cracked tiles fall. Move to a safe one! |
| 서리 거인 - 포효가 오면 얼음 기둥 뒤에 숨어요! | Frost Giant - When it roars, hide behind ice pillars! |
| 심해 군주 - 머리 위와 같은 색 · 모양 발판에 서요! | Abyssal Lord - Stand on the tile that matches the sign! |
| 수정 여왕 - 종이 울린 순서대로 똑같이 쳐요! | Crystal Queen - Hit the bells in the order they rang! |
| 전갈 여왕 - 꼬리가 빛나는 둔덕을 따라가 때려요! | Scorpion Queen - Follow the glowing tail. Hit that mound! |
| 폭풍 군주 - 조준경을 피뢰침 곁으로 끌고 가요! | Storm Lord - Lead the target to a lightning rod! |
| 보상 띠의 [기믹 도움말]에서 언제든 다시 볼 수 있어요. | Tap [Mechanics] on the reward band to see it again. |

## 6. 파티 / Party
근거: `shared/data/PartyConfig.lua`(maxMembers 4 · expBonusByMemberCount 0.10 / 0.15 / 0.20) · `shared/data/CombatConfig.lua`(contributionRewardThreshold 0.10) · `shared/data/TextData_panels.lua`(`ui.party.help.*`)

| 한국어 | English |
|---|---|
| 파티는 최대 4명이에요. | A party can have up to 4 players. |
| 함께 사냥하면 경험치가 늘어요(2명 +10% · 3명 +15% · 4명 +20%). | Hunting together gives more EXP (2: +10% · 3: +15% · 4: +20%). |
| 몬스터 체력의 10% 이상을 깎아야 보상을 받아요. | Deal 10% or more of a monster's HP to get rewards. |
| 보스 스테이지는 리더가 신청하고 1명이 동의하면 다 같이 가요. | For boss stages, the leader asks and one member agrees. Then all go. |
| 다른 서버 친구는 파티 코드나 친구 초대로 불러요. | Bring friends from other servers with a party code or an invite. |
| 유물 등급 이상이 나오면 파티 전원에게 보여요. | Relic or better drops are shown to the whole party. |

## 7. 체크포인트 · 귀환 / Checkpoints · Recall
근거: `shared/data/WorldMapData.lua`(travel.recall castSeconds 3 · backSeconds 300 · hubReturnCooldownSeconds 60 · checkpoints 7곳 · channelSeconds 3 · cooldownSeconds 30) · `client/ui/PanelRegistry.lua`(hubReturn = B)

| 한국어 | English |
|---|---|
| 체크포인트는 마을 1곳과 구역 입구 캠프 6곳이에요. | There are 7 checkpoints: the town and 6 zone camps. |
| 가까이 가면 발견돼요. 지도(M)에 표시돼요. | Walk near one to find it. It shows on the map (M). |
| 지도에서 발견한 곳을 누르면 3초 뒤 순간이동해요. | Tap a found place on the map to teleport after 3s. |
| 움직이거나 맞으면 순간이동이 취소돼요. | Moving or getting hit cancels it. |
| 귀환(B)은 3초 뒤 마을로 가요. | Recall (B) takes you to town after 3s. |
| 귀환 뒤 5분 안에 [돌아가기]를 한 번 누르면 원래 자리로 가요. | Within 5 min, tap [Return] once to go back. |
| 귀환은 마을 도착 뒤 60초 동안 다시 못 써요. | After arriving, Recall rests for 60s. |

## 8. 펫 · 알 / Pets · Eggs
근거: `shared/data/EggData.lua`(gradeNames · hatchGradeNames · hatch) · `shared/data/PetData.lua`(hatchSeconds · petCap 60 · levels · unlocks) · `shared/data/NestData.lua`(eggCap 40)

| 한국어 | English |
|---|---|
| 알은 둥지 · 퀘스트 · 출석에서 얻어요. | Get eggs from nests, quests, and check-ins. |
| 둥지는 바위 위 · 신전 · 숨은 곳에 있어요. | Nests hide on rocks, in temples, and in secret spots. |
| 알 등급은 보통 · 좋은 · 희귀예요. 좋은 알일수록 부화가 오래 걸려요(1분 · 3분 · 10분). | Egg grades are Normal, Good, and Rare. Better eggs hatch slower (1 · 3 · 10 min). |
| 알 가방에는 40개까지 들어가요. | Your Egg Bag holds up to 40 eggs. |
| 부화하면 펫이 나와요(일반 · 고급 · 희귀 · 영웅). | Hatching gives a pet (Common · Uncommon · Rare · Epic). |
| 부화를 많이 할수록 좋은 등급이 잘 나와요. | Hatch more for better grades more often. |
| 펫은 60마리까지 보관하고, 하나를 데리고 다녀요. | Keep up to 60 pets. One can follow you. |
| Lv.200부터 펫이 근처 아이템을 주워요. | From Lv.200, your pet picks up nearby items. |

> 확인 필요: `PetData.unlocks.autoPickup = 200`이 "레벨"인지(도움말 `help.pet.pickup` 문구는 Lv.{level}) 출시 전에 한 번 확인.

## 9. 시즌 패스 / Season Pass
근거: `shared/data/SeasonPassData.lua`(tiers 40 · expPerTier 250 · rows) · `shared/data/MonetizationData.lua`(season_premium 399 Robux) · `shared/data/TextData_en.lua`(`shop.help.detail` - 8주)

| 한국어 | English |
|---|---|
| 시즌은 8주마다 새로 시작해요. 칸은 40개예요. | A season lasts 8 weeks and has 40 tiers. |
| 퀘스트를 하면 패스 경험치가 쌓여요. 250마다 한 칸이 올라요. | Quests give Pass EXP. Every 250 moves you up a tier. |
| 무료 줄: 반짝 조각 · 5칸마다 알 · 20칸 별빛 테마 · 40칸 꽃잎 글라이더. | Free track: Sparkle Shards, an egg every 5 tiers, Starlight theme (20), Petal glider (40). |
| 유료 줄: 반짝 조각 더 많이 · 연 글라이더 · 서리꽃 · 불씨 테마 · 시즌 한정 구름 고래. | Paid track: more Shards, Kite glider, Frost and Ember themes, and the season-only Cloud Whale. |
| 유료 줄은 이번 시즌에만 열려요. 시즌마다 다시 사요. | The paid track is for this season only. |
| 패스는 꾸미기만 줘요. 전투력은 오르지 않아요. | The pass gives looks only. It never adds power. |

## 10. 치장 / Looks
근거: `shared/data/CosmeticSlotData.lua`(slots · sets · gliderSkins) · `shared/data/MonetizationData.lua`(products · passes · shardPrices theme 120 · gliderSkin 80)

| 한국어 | English |
|---|---|
| 치장은 반짝 조각이나 로벅스로만 사요. 골드로는 못 사요. | Looks cost Sparkle Shards or Robux. Not gold. |
| 테마 세트를 사면 대시 · 점프 · 활강 · 발자국 4칸이 한 번에 열려요. | A Theme Set opens 4 slots at once: Dash, Jump, Glide, Steps. |
| 칸마다 다른 세트를 섞어 장착할 수 있어요. | You can mix sets slot by slot. |
| 글라이더 스킨은 글라이더 모양만 바꿔요. | A Glider Skin changes only how your glider looks. |
| [입혀 보기]로 사기 전에 몇 초 동안 써 볼 수 있어요. | Use [Try On] to test it for a few seconds first. |
| 이름표 색 · 배지 패스는 이름표만 꾸며요. | Nameplate Color and Badge passes only decorate your name. |
| 치장은 전투력을 올리지 않아요. | Looks never add power. |
