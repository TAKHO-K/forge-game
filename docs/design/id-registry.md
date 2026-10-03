# 저장 id 등록부 (출시 뒤 삭제 금지 · QUEUE-ALL5 A3)

> 자동 생성 = `python roblox/tools/ids/id_registry.py --write`(직접 고치지 않는다). 원본 = `roblox/tools/ids/id_registry_snapshot.json`.

## 규칙
- 아래 id는 **출시 뒤 데이터에서 지우거나 이름을 바꾸지 않는다.** 안 쓰게 된 것은 드랍 · 판매 · 표시에서만 빼고 데이터 항목은 남긴다.
- 이름을 꼭 바꿔야 하면 새 id를 더하고 SAVE_VERSION을 올려 migrate()에서 옛 id → 새 id로 옮긴다(옛 id 항목도 남긴다).
- 검사: `python roblox/tools/ids/id_registry.py`(사라진 id = 실패). 새 id를 더한 커밋은 `--write`로 등록부를 늘린다.
- 그래도 모르는 id가 저장에 남으면(되돌린 데이터 · 실수) 로드는 실패하지 않고 그 값만 보관 칸 `profile.quarantine`으로 간다(`SaveSystem.quarantineUnknownIds` · 로그 `[SaveSystem] 모르는 id 보관` · 통계 `SaveQuarantined`). 같은 id가 데이터에 다시 생기면 다음 접속 때 제자리로 돌아온다(착용 장비 · 박힌 보석은 가방 · 보석 가방으로).
- 세트 구역(setZone)은 모르면 "세트 아님"으로 동작해 보관하지 않는다(삭제 금지 검사만).

## 종류별 id (2026-10-03 기준)

| 종류 | 저장 자리 | 데이터 | 개수 | id |
|---|---|---|---|---|
| 옵션(`option`) | item.option.id · gem.option.id | `OptionData.options` | 16 | `attackPercent` · `crit` · `defensePercent` · `expGain` · `healingPower` · `lifesteal` · `maxHpPercent` · `skill_bow_E` · `skill_bow_Q` · `skill_dualblade_E` · `skill_dualblade_Q` · `skill_greatsword_E` · `skill_greatsword_Q` · `skill_healer_E` · `skill_healer_Q` · `speedPercent` |
| 재료(`material`) | materials 키 | `EnhanceMaterialData.order` | 2 | `enhanceStone` · `highEnhanceStone` |
| 장비 등급(`grade`) | item.grade | `ArmorData.gradeOrder` | 8 | `ancient` · `epic` · `legendary` · `normal` · `primordial` · `rare` · `relic` · `transcendent` |
| 장비 부위(`part`) | item.part · equipment 키 | `SetData.parts` | 3 | `armor` · `gloves` · `shoes` |
| 세트 구역(`setZone`) | item.setZone | `WorldMapData.zones[].key` | 6 | `tier1` · `tier2` · `tier3` · `tier4` · `tier5` · `tier6` |
| 직업옵션(`skillVariant`) | item.skillVariant.id | `SkillVariantData.templates` | 4 | `far` · `heavy` · `swift` · `wide` |
| 초월 특수(`special`) | item.special | `TranscendentData.specialNames` | 3 | `frenzy` · `phantom` · `soar` |
| 치장 테마(`cosmeticTheme`) | cosmetics.themes 키 · equipped 값 | `CosmeticSlotData.sets[].id` | 12 | `anvil` · `auroraFrost` · `cloudWhaleTrail` · `ember` · `frost` · `halloween` · `jelly` · `meadowStar` · `moonEmber` · `sodaJelly` · `starlight` · `violetStar` |
| 글라이더(`gliderSkin`) | cosmetics.gliderSkins 키 · equipped.gliderSkin | `CosmeticSlotData.gliderSkins[].id` | 9 | `amethystWing` · `berryParachute` · `cloudWhale` · `dragonWing` · `jadeWing` · `kite` · `mintParachute` · `petal` · `slimeParachute` |
| 칭호(`title`) | titles 키 · codex.title | `TitleData.titles(+ CodexRules 줄 칭호)` | 48 | `codex_armorGrade_ancient` · `codex_armorGrade_epic` · `codex_armorGrade_legendary` · `codex_armorGrade_normal` · `codex_armorGrade_rare` · `codex_armorGrade_relic` · `codex_armorZone_tier1` · `codex_armorZone_tier2` · `codex_armorZone_tier3` · `codex_armorZone_tier4` · `codex_armorZone_tier5` · `codex_armorZone_tier6` · `codex_boss_abyssal_lord` · `codex_boss_crystal_queen` · `codex_boss_frost_giant` · `codex_boss_scorpion_queen` · `codex_boss_section_guardian` · `codex_boss_storm_lord` · `codex_class_bow` · `codex_class_dualblade` · `codex_class_greatsword` · `codex_class_healer` · `codex_monster_tier1` · `codex_monster_tier2` · `codex_monster_tier3` · `codex_monster_tier4` · `codex_monster_tier5` · `codex_monster_tier6` · `codex_nest_tier1` · `codex_nest_tier2` · `codex_nest_tier3` · `codex_nest_tier4` · `codex_nest_tier5` · `codex_nest_tier6` · `codex_pet_tier1` · `codex_pet_tier2` · `codex_pet_tier3` · `codex_pet_tier4` · `codex_pet_tier5` · `codex_pet_tier6` · `communityHero` · `curiousCaptain` · `nestSeeker` · `primordialChosen` · `seasonRegular` · `secretKeeper` · `transcendentOne` · `weeklyChampion` |
| 방지권(비활성 - QUEUE-ALL9B G 폐지 · 보유분 골드 환산 v68)(`protectionTicket`) | purchases.protectionTickets 키 | `IdRegistry.retired.protectionTicket` | 2 | `drop` · `reset` |
