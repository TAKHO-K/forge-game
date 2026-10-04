-- QUEUE-ALL6 A4 데이터 이름 사전(원문 → 언어별 이름). 데이터 파일(shared/data/*)에는 한국어 원문을 그대로 두고 화면에서 shared/Text.name(원문)으로 바꾼다.
--   용어집 = docs/i18n/glossary.md(같은 말 · 고정). 이름 40자 이내 · 아이 대상 쉬운 말. 없는 원문 = 원문 그대로(경고 없음 - 플레이어 이름 등 사전 밖 값이 인자로 많이 지나간다).
--   Text.get 인자 값이 이 사전의 원문이면 자동으로 바뀐다({boss} · {grade} · {part} 자리). " · "로 이어진 이름은 조각이 전부 있을 때 조각별로 바뀐다.
--   짝 검사 = roblox/tools/i18n/check_names.py(데이터 이름 목록 대비 빠진 것 · 40자 넘침).
local en = {
	-- ═══ 장비 등급(ArmorData) · 부위(ItemVisualData) ═══
	["일반"] = "Common", ["희귀"] = "Rare", ["영웅"] = "Epic", ["전설"] = "Legendary", ["유물"] = "Relic", ["고대"] = "Ancient", ["태초"] = "Primordial", ["초월"] = "Transcendent",
	["갑옷"] = "Armor", ["장갑"] = "Gloves", ["신발"] = "Shoes", ["무기"] = "Weapon", ["장비"] = "Gear",
	["기본 무기"] = "Basic Weapon",

	-- ═══ 직업 · 무기(ClassData - 화면 키 class.name.* 와 같은 말) ═══
	["검사"] = "Swordsman", ["도적"] = "Rogue", ["궁수"] = "Archer", ["치유사"] = "Healer", ["성기사"] = "Paladin",
	["대검"] = "Greatsword", ["쌍검"] = "Dual Blades", ["활"] = "Bow", ["뿅망치"] = "Squeaky Hammer", ["지팡이"] = "Staff",

	-- ═══ 강화 재료(EnhanceMaterialData) ═══
	["강화석"] = "Enhance Stone", ["상급 강화석"] = "Greater Enhance Stone",
	["하락 방지권"] = "Drop Protection Ticket", ["초기화 방지권"] = "Reset Protection Ticket", -- EnhanceConfig.protection

	-- ═══ 옵션 · 세트 축(OptionData · GemData) ═══
	["위력"] = "Might", ["신속"] = "Haste", ["치명"] = "Crit", ["건강"] = "Vitality", ["방어"] = "Guard", ["성장"] = "Growth", ["재생"] = "Regen", ["흡혈"] = "Lifesteal",
	-- 보석 특수(GemData)
	["연속격"] = "Combo Strike", ["속사의 흔적"] = "Rapid Mark", ["심판의 표식"] = "Judgment Mark", ["삼위일체"] = "Trinity",
	-- 초월 특수(TranscendentData)
	["환영"] = "Phantom", ["광폭"] = "Frenzy", ["비상"] = "Soar",
	-- 스킬 변형(SkillVariantData)
	["넓게"] = "Wide", ["재빠르게"] = "Swift", ["묵직하게"] = "Heavy", ["멀리"] = "Far",

	-- ═══ 스킬 · 궁극기(SkillData · UltimateData) ═══
	["관통돌진"] = "Piercing Dash", ["회전베기"] = "Spin Slash", ["강궁"] = "Power Shot", ["백스텝샷"] = "Backstep Shot", ["그림자분신"] = "Shadow Clone", ["난무"] = "Blade Flurry",
	["치유"] = "Heal", ["딜링모드"] = "Battle Mode", ["암영 표식"] = "Shadow Mark", ["사냥꾼의 덫"] = "Hunter's Trap", ["전장의 포효"] = "Battle Roar", ["구원의 기도"] = "Prayer of Salvation",
	["파괴의 화신"] = "Avatar of Ruin", ["천궁의 폭우"] = "Sky Arrow Storm", ["죽음의 계약"] = "Death Pact", ["생명의 성역"] = "Sanctuary of Life",

	-- ═══ 수련 · 직업 능력(TrainingData) ═══
	["공격 수련"] = "Attack Training", ["체력 수련"] = "HP Training", ["방어 수련"] = "Guard Training",
	["대검 숙련"] = "Greatsword Mastery", ["강철 체력"] = "Iron Body", ["철벽"] = "Iron Wall",
	["쌍검 숙련"] = "Dual Blade Mastery", ["질긴 몸"] = "Tough Body", ["잔걸음"] = "Quick Steps",
	["활 숙련"] = "Bow Mastery", ["단련된 몸"] = "Trained Body", ["빠른 시위"] = "Quick Draw",
	["치유사 숙련"] = "Healer Mastery", ["성스러운 몸"] = "Holy Body", ["은총"] = "Grace",

	-- ═══ 성장 보상(MilestoneData) ═══
	["가방 칸 +5"] = "Bag Slots +5", ["계승 비용 -10%"] = "Inherit Cost -10%", ["보석 칸 +1(예약)"] = "Socket +1 (coming)", ["장비 프리셋 칸 +1(예약)"] = "Gear Preset +1 (coming)", ["펫 칸 +1(예약)"] = "Pet Slot +1 (coming)",

	-- ═══ 구역(WorldMapData · CodexData tier) · 세트(SetData = 구역 + " 세트") ═══
	["석조 평원"] = "Stone Plains", ["수정 동굴"] = "Crystal Cave", ["수몰 사원"] = "Sunken Temple", ["모래 유적"] = "Sand Ruins", ["폭풍 첨탑"] = "Storm Spire", ["빙하 동굴"] = "Glacier Cave",
	["석조 평원 세트"] = "Stone Plains Set", ["수정 동굴 세트"] = "Crystal Cave Set", ["수몰 사원 세트"] = "Sunken Temple Set", ["모래 유적 세트"] = "Sand Ruins Set", ["폭풍 첨탑 세트"] = "Storm Spire Set", ["빙하 동굴 세트"] = "Glacier Cave Set",
	["석조 평원 사냥터"] = "Stone Plains Hunt", ["수정 굴 사냥터"] = "Crystal Cave Hunt", ["수몰 사원 사냥터"] = "Sunken Temple Hunt", ["모래 유적 사냥터"] = "Sand Ruins Hunt", ["폭풍 첨탑 사냥터"] = "Storm Spire Hunt", ["빙하 동굴 사냥터"] = "Glacier Cave Hunt",
	["수호자의 석조 평원"] = "Guardian Plains",
	["수호자의 석조 평원 세트"] = "Guardian Plains Set", -- SetBonus.setName(tier1 테마)
	["%s 관문 등록! 이제 어디서든 입장할 수 있어요."] = "%s Gate saved! Now you can enter from anywhere.",
	["편함"] = "Easy", ["끄기"] = "Off", -- AutoStageData 프리셋
	["석조 평원 입구"] = "Stone Plains Gate", ["수정 동굴 입구"] = "Crystal Cave Gate", ["수몰 사원 입구"] = "Sunken Temple Gate", ["모래 유적 입구"] = "Sand Ruins Gate", ["폭풍 첨탑 입구"] = "Storm Spire Gate", ["빙하 동굴 입구"] = "Glacier Cave Gate",
	-- 허브
	["큰 나무 마을"] = "Big Tree Village", ["대장간 거리"] = "Forge Street", ["시장"] = "Market", ["커뮤니티 광장"] = "Community Plaza", ["포탈 광장"] = "Portal Plaza",
	["재련대"] = "Refine Bench", ["보석 가공대"] = "Gem Bench", -- QUEUE-ALL8 A: 정식 이름만
	["판매"] = "Sell", ["부화장"] = "Hatchery", ["파티 게시판"] = "Party Board", ["순위판"] = "Rankings", ["명예의 전당"] = "Hall of Fame",
	["재봉사"] = "Tailor", ["마을 게시판"] = "Village Board", ["도전 기사"] = "Challenge Knight", ["대장장이"] = "Blacksmith", -- QUEUE-ALL7B 2 · 3
	["대장간"] = "Forge", ["상점"] = "Shop", ["상인"] = "Merchant", ["게시판지기"] = "Board Keeper", ["재봉집"] = "Tailor", -- QUEUE-ALL7B 4 지도 이름 · ALL8 D4: "Tailor's House" → 짧게(×10에서 자리가 없어 숨었다)
	["하루 1회 보상"] = "Daily Gift", ["덩굴 리프트"] = "Vine Lift",
	-- 큰 나무 구간 · 정거장
	["뿌리 가지"] = "Root Branch", ["덩굴 숲"] = "Vine Woods", ["말랑 열매 골"] = "Squishy Fruit Gully", ["점프대 가지"] = "Bounce Branch", ["높은 가지"] = "High Branch", ["정상 오르기"] = "Climb to the Top",
	["뿌리 정거장"] = "Root Stop", ["첫 가지 정거장"] = "First Branch Stop", ["구름 아래 정거장"] = "Below-Cloud Stop", ["구름층 정거장"] = "Cloud Stop", ["높은 가지 정거장"] = "High Branch Stop",
	-- QUEUE-ALL6R 3: 서버가 짓는 월드 명판(강화대 · 제단 · 상인 = 용어집) · 길 표지판(shared/RoadNet)
	["강화대"] = "Forge", ["환생의 제단"] = "Rebirth Altar", ["보석상인"] = "Gem Merchant",
	["캠프 · 관문 →"] = "Camp · Gate →", ["관문 ↑ · 전망 ↗"] = "Gate ↑ · Lookout ↗",
	-- 사냥터 둘러보기 자리(explore)
	["절벽 위 전망"] = "Cliff Lookout", ["폐허 망루 꼭대기"] = "Ruined Tower Top", ["바위 굴"] = "Rock Cave", ["폭포 뒤"] = "Behind the Falls",
	["수정 굴"] = "Crystal Hollow", ["큰 수정 기둥"] = "Giant Crystal Pillar", ["수정 언덕 위"] = "Crystal Hilltop", ["수정 탑 꼭대기"] = "Crystal Tower Top", ["빛 폭포 뒤"] = "Behind the Light Falls",
	["사원 폭포 뒤"] = "Behind the Temple Falls", ["잠긴 종탑 꼭대기"] = "Sunken Bell Tower Top", ["제단 언덕"] = "Altar Hill", ["물길 굴"] = "Water Tunnel",
	["모래 언덕 위"] = "Dune Top", ["무너진 지하 통로"] = "Fallen Tunnel", ["오벨리스크 꼭대기"] = "Obelisk Top", ["모래 폭포 뒤"] = "Behind the Sand Falls",
	["바람 탑 꼭대기"] = "Wind Tower Top", ["낙뢰 절벽(아래에서 올려다보기)"] = "Lightning Cliff (look up)", ["구름 고원"] = "Cloud Plateau", ["번개 굴"] = "Thunder Cave",
	["빙벽"] = "Ice Wall", ["얼음 굴"] = "Ice Cave", ["빙하 고원"] = "Glacier Plateau", ["언 폭포 뒤"] = "Behind the Frozen Falls", ["얼음 탑 꼭대기"] = "Ice Tower Top",
	-- QUEUE-ALL6 L 세부 지역(WorldMapData.subAreas)
	["이끼 입구"] = "Moss Gate", ["슬라임 연못"] = "Slime Pond", ["멧돼지 들판"] = "Boar Field", ["망루 언덕"] = "Watchtower Hill", ["돌기둥 마루"] = "Monolith Ridge",
	["반짝 입구"] = "Sparkle Gate", ["딱정벌레 굴"] = "Beetle Hollow", ["보라 수정 숲"] = "Amethyst Grove", ["박쥐 골짜기"] = "Bat Valley", ["여왕의 문"] = "Queen's Door",
	["물가 입구"] = "Shore Gate", ["소라게 해변"] = "Crab Beach", ["해파리 웅덩이"] = "Jelly Pool", ["잠긴 회랑"] = "Sunken Hall", ["신전 둑길"] = "Temple Causeway",
	["모래 입구"] = "Sand Gate", ["전갈 사막"] = "Scorpion Dunes", ["선인장 밭"] = "Cactus Field", ["오벨리스크 길"] = "Obelisk Road", ["피라미드 앞"] = "Pyramid Steps",
	["바람 입구"] = "Wind Gate", ["번개 들판"] = "Thunder Field", ["구름 양 언덕"] = "Cloud Sheep Hill", ["낙뢰 절벽"] = "Lightning Cliff", ["첨탑 아래"] = "Spire Base",
	["눈 입구"] = "Snow Gate", ["골렘 설원"] = "Golem Snowfield", ["얼음 굴 길"] = "Ice Cave Path", ["용의 빙원"] = "Dragon Icefield", ["거인의 문"] = "Giant's Door",
	-- 봉인 입구(아직 안 연 곳)
	["태엽 시계탑"] = "Clockwork Tower", ["거인의 부엌"] = "Giant's Kitchen", ["인형 극장"] = "Puppet Theater", ["구름 고래 하늘섬"] = "Cloud Whale Isle", ["두더지 광산"] = "Mole Mine",
	["…아직 잠들어 있다."] = "...Still asleep.",

	-- ═══ 보스(BossData) · 기믹 카드 ═══
	["구간 수호자"] = "Section Guardian", ["서리 거인"] = "Frost Giant", ["심해 군주"] = "Abyssal Lord", ["수정 여왕"] = "Crystal Queen", ["전갈 여왕"] = "Scorpion Queen", ["폭풍 군주"] = "Storm Lord",
	["지반 붕괴"] = "Ground Collapse", ["체력이 절반 아래면 땅이 조각조각 무너진다 - 금 간 조각 밖으로!"] = "Below half HP the floor breaks. Leave cracked tiles!",
	["눈보라 포효"] = "Blizzard Roar", ["포효가 울리면 얼음 기둥 뒤에 숨어라 - 기둥이 부서지면 옮겨 숨어라"] = "On the roar, hide behind an ice pillar. Move if it breaks!",
	["색 맞추기"] = "Color Match", ["머리 위 표시(●빨강 / ▲파랑)와 같은 색 발판에 서라 - 밟을 때마다 색이 바뀐다"] = "Stand on the tile matching your mark (● red / ▲ blue)!",
	["수정 오르골"] = "Crystal Music Box", ["수정 종이 울리는 순서를 기억해, 똑같이 두드려라!"] = "Remember the bell order and hit them the same way!",
	["틀리면 처음부터! 실패하면… 여왕의 수정 장식품이 됩니다."] = "Miss and start over! Fail... and become her crystal statue.",
	["진짜 전갈 찾기"] = "Find the Real Scorpion", ["빛나는 꼬리를 찾아 때려라!"] = "Find the glowing tail and hit it!",
	["번개 조준경"] = "Lightning Sight", ["번개 조준경을 피뢰침으로 유인하세요! 피뢰침 {N}개를 충전하면 폭풍을 막습니다."] = "Lure the sight to the rods! Charge {N} rods to stop the storm.",
	-- 보스 공격 이름(맞은 공격 · 패턴 줄)
	["강공격"] = "Heavy Strike", ["진동파"] = "Shockwave", ["낙석"] = "Falling Rocks", ["돌진"] = "Charge", ["십자 화염"] = "Cross Flame",
	["방패 후려치기"] = "Shield Bash", ["움켜쥐기"] = "Grab", ["방패 거울"] = "Shield Mirror", ["원 안 내려찍기"] = "Inner Smash",
	["쌍권 연타"] = "Twin Fist Combo", ["추적 광구"] = "Seeker Orb", ["대지 가르기"] = "Earth Split",
	["빙하 균열"] = "Glacier Crack", ["빙결 강타"] = "Frost Slam", ["낙빙"] = "Falling Ice", ["얼음 가시"] = "Ice Spikes",
	["서리 주먹"] = "Frost Fist", ["서리 손아귀"] = "Frost Grip", ["얼음 거울"] = "Ice Mirror", ["원 안 짓밟기"] = "Inner Stomp", ["얼음 창"] = "Ice Spear", ["발 구르기"] = "Stomp", ["눈덩이"] = "Snowball",
	["판 털기"] = "Plate Shake", ["꼬리 휩쓸기"] = "Tail Sweep", ["해일"] = "Tidal Wave", ["물기둥"] = "Water Spout", ["색 맞추기 실패"] = "Color Miss",
	["지느러미 베기"] = "Fin Slash", ["꼬리 감기"] = "Tail Wrap", ["물의 장막"] = "Water Veil", ["꼬리 반원"] = "Tail Arc", ["소용돌이"] = "Whirlpool", ["거품탄"] = "Bubble Shot", ["삼지창"] = "Trident",
	["수정 부수기"] = "Crystal Break", ["파편 폭발"] = "Shard Burst", ["수정 낙하"] = "Crystal Drop", ["에네르기파"] = "Energy Beam", ["오르골 전기"] = "Music Box Shock", ["공동 책임"] = "Shared Fault",
	["수정 장식품"] = "Crystal Statue", ["수정 채찍"] = "Crystal Whip", ["수정 손"] = "Crystal Hand", ["프리즘 반사막"] = "Prism Shield", ["수정 가시"] = "Crystal Spikes", ["수정 파편"] = "Crystal Shards", ["분신 돌격"] = "Clone Rush",
	["개미지옥"] = "Antlion Pit", ["모래 구덩이"] = "Sand Pit", ["집게 강타"] = "Claw Slam", ["독침 낙하"] = "Stinger Drop", ["잠행 찌르기"] = "Sneak Sting", ["모래 폭발"] = "Sand Blast", ["모래 폭풍"] = "Sandstorm",
	["집게 찰싹"] = "Claw Slap", ["집게 낚아채기"] = "Claw Snatch", ["가시 반격"] = "Thorn Counter", ["독침 찌르기"] = "Stinger Jab", ["모래 잠복"] = "Sand Ambush", ["집게 휘두르기"] = "Claw Swing",
	["돌풍"] = "Gust", ["방전 고리"] = "Shock Ring", ["회오리"] = "Twister", ["낙뢰"] = "Lightning", ["폭풍"] = "Storm",
	["지팡이 휘두르기"] = "Staff Swing", ["바람 손"] = "Wind Hand", ["번개 결계"] = "Thunder Barrier", ["원 안 낙뢰"] = "Inner Lightning", ["회오리 이동"] = "Twister Dash", ["천둥 고리"] = "Thunder Ring", ["뇌격 창"] = "Thunder Spear",
	["느림 · 느림(공중) · 빠름"] = "Slow · Slow (air) · Fast", ["두 겹 시간차 · 빠름 → 보통 → 느림"] = "Two layers · Fast → Mid → Slow",
	["천둥 · 공중 메아리 · 천둥"] = "Thunder · Air Echo · Thunder", ["느린 고리 · 공중 · 느린 고리"] = "Slow Ring · Air · Slow Ring",

	-- ═══ 몬스터(MonsterData · MonsterSpeciesData · MonsterPrefixData) ═══
	["슬라임"] = "Slime", ["고블린"] = "Goblin", ["오크"] = "Orc", ["트롤"] = "Troll", ["골렘"] = "Golem", ["드래곤"] = "Dragon",
	["이끼 슬라임"] = "Moss Slime", ["바위 멧돼지"] = "Rock Boar", ["수정 딱정벌레"] = "Crystal Beetle", ["자수정 박쥐"] = "Amethyst Bat", ["소라게 기사"] = "Hermit Crab Knight", ["물방울 해파리"] = "Bubble Jelly",
	["모래 전갈"] = "Sand Scorpion", ["선인장 꼬마"] = "Cactus Kid", ["번개 임프"] = "Thunder Imp", ["구름 양"] = "Cloud Sheep", ["얼음 골렘"] = "Ice Golem", ["눈토끼"] = "Snow Bunny", ["푸른 드래곤"] = "Blue Dragon",
	["연약한"] = "Weak", ["단단한"] = "Tough", ["거대한"] = "Giant",
	["반짝이 몬스터"] = "Sparkle Monster", ["반짝 조각"] = "Style Token", ["꾸미기 토큰"] = "Style Token",

	-- ═══ 알 · 펫(EggData · PetData) ═══
	["석조 평원 알"] = "Stone Plains Egg", ["수정 동굴 알"] = "Crystal Cave Egg", ["수몰 사원 알"] = "Sunken Temple Egg", ["모래 유적 알"] = "Sand Ruins Egg", ["폭풍 첨탑 알"] = "Storm Spire Egg", ["빙하 동굴 알"] = "Glacier Cave Egg",
	["돌 거북"] = "Stone Turtle", ["이끼 토끼"] = "Moss Hare", ["조약돌 두더지"] = "Pebble Mole", ["폐허 올빼미"] = "Ruin Owl",
	["수정 박쥐"] = "Crystal Bat", ["프리즘 도마뱀"] = "Prism Lizard", ["반짝 달팽이"] = "Gleam Snail", ["석영 여우"] = "Quartz Fox",
	["산호 수달"] = "Reef Otter", ["소라 게"] = "Shell Crab", ["물결 개구리"] = "Tide Frog", ["연꽃 물고기"] = "Lotus Fish",
	["사막 여우"] = "Fennec Fox", ["선인장 고슴도치"] = "Cactus Hedgehog", ["쇠똥구리"] = "Scarab Beetle", ["햇빛 도마뱀붙이"] = "Sun Gecko",
	["불꽃 족제비"] = "Spark Ferret", ["천둥 매"] = "Thunder Hawk", ["돌풍 다람쥐"] = "Gale Squirrel",
	["서리 펭귄"] = "Frost Penguin", ["눈 올빼미"] = "Snow Owl", ["얼음 물범"] = "Ice Seal", ["오로라 여우"] = "Aurora Fox",
	["보통"] = "Normal", ["좋은"] = "Good", ["고급"] = "Uncommon",
	["보통 알"] = "Common Egg", ["반짝 알"] = "Sparkly Egg", ["신비한 알"] = "Mystic Egg", -- QUEUE-N1004 A-3 알 등급 화면 이름(EggData.gradeNames)
	["강아지"] = "Puppy", ["고양이"] = "Kitty", ["새끼 용"] = "Baby Dragon",

	-- ═══ 칭호(TitleData · NestData · CodexData 줄 칭호 틀) ═══
	["태초의 선택"] = "Primordial Chosen", ["초월자"] = "Transcender", ["초월 계승자"] = "Transcendent Heir", ["주간 챔피언"] = "Weekly Champion", ["모두의 영웅"] = "Everyone's Hero",
	["호기심 대장"] = "Curious Captain", ["둥지 탐험가"] = "Nest Explorer", ["비밀 수집가"] = "Secret Collector", ["모험가"] = "Adventurer",
	["%s 수집가"] = "%s Collector", ["%s 정복자"] = "%s Conqueror", ["%s 사육사"] = "%s Keeper", ["%s 탐험가"] = "%s Explorer", ["%s 탐구자"] = "%s Scholar", ["%s 사냥꾼"] = "%s Hunter", ["%s 장인"] = "%s Master",

	-- ═══ 도감(CodexData · MonsterCodexData) ═══
	["첫 만남"] = "First Meet", ["10마리"] = "10 Defeated", ["100마리"] = "100 Defeated", ["1,000마리"] = "1,000 Defeated", ["반짝이"] = "Sparkle",
	["10마리 처치"] = "Defeat 10", ["100마리 처치"] = "Defeat 100", ["1,000마리 처치"] = "Defeat 1,000", ["반짝이 처치"] = "Defeat a Sparkle", ["태초 장비 드랍"] = "Primordial Drop",
	["펫"] = "Pets", ["탐험"] = "Explore", ["몬스터"] = "Monsters", ["보스"] = "Bosses", ["직업"] = "Classes", ["점수판"] = "Score", ["칭호"] = "Titles",
	["도감"] = "Codex", ["모두 받기"] = "Claim All", ["받기"] = "Claim", ["받음"] = "Claimed", ["진행 중"] = "In Progress",
	["도감 점수 %d / %d"] = "Codex Score %d / %d", ["알 가방이 가득 차서 못 받은 칸이 있어요"] = "Egg bag is full. Some rewards are waiting.",
	["초월 완성"] = "Transcendent Done", ["줄 완성! 칭호 「%s」"] = "Row done! Title 「%s」", ["도감 보상: %s"] = "Codex reward: %s",
	["칭호 안 보이기"] = "Hide Title", ["이름표 우선순위 = 초월자 > 태초의 선택 > 고른 칭호"] = "Name tag shows: Transcender > Primordial Chosen > your title", ["비밀 둥지 %d"] = "Secret Nest %d",
	-- 몬스터 도감 힌트
	["맞으면 통통 튀어 반격해요. 납작해지면 뛰어들 신호!"] = "Bounces back when hit. Flat means it's about to jump!",
	["코로 땅을 파다 12 걸음 안에 들어오면 돌진해요."] = "Digs with its nose. Get within 12 steps and it charges.",
	["등의 수정이 커지면 조각을 쏘려는 거예요."] = "When its back crystal grows, it's about to shoot.",
	["멀리서도 찾아와요. 날개를 접으면 급강하!"] = "Finds you from far away. Folded wings = dive!",
	["앞쪽 껍데기는 단단해요. 큰 집게를 들면 옆으로 피하세요."] = "Its front shell is hard. Big claw up? Step aside!",
	["몸이 오므라들면 주변에 전기가 퍼져요."] = "When it shrinks, electricity spreads around it.",
	["꼬리 끝이 앞으로 넘어오면 직선 찌르기예요."] = "Tail tip comes forward = straight sting!",
	["선인장 밭의 진짜 선인장 사이에 숨어 있어요."] = "It hides among the real cactuses.",
	["폭풍 속을 뛰어다니며 쫓아와요. 두 손을 들면 번개!"] = "Runs through storms. Both hands up = lightning!",
	["털이 어두워지면 주변에 낙뢰가 떨어져요."] = "Dark fur means lightning falls nearby.",
	["느리지만 한 방이 커요. 두 주먹을 들면 멀리 떨어지세요."] = "Slow but hits hard. Fists up? Back away!",
	["한 마리를 때리면 무리 전체가 달려들어요."] = "Hit one and the whole group rushes in.",
	["목을 젖히면 앞으로 서리 숨결, 꼬리를 들면 뒤를 쓸어요. 날개를 펴면 밀려나요."] = "Head back = frost breath. Tail up = sweep. Wings = push!",

	-- ═══ 퀘스트 이름(QuestData - {n} 자리는 그대로) ═══
	["몬스터 {n}마리 처치"] = "Defeat {n} monsters", ["보스 {n}번 처치"] = "Defeat {n} bosses", ["무기 강화 {n}번 시도"] = "Try weapon enhance {n} times",
	["보석 장착 · 재련 {n}번"] = "Socket or refine gems {n} times", ["둥지에서 알 {n}개 줍기"] = "Pick up {n} eggs from nests", ["수련 · 직업 능력 {n}번 올리기"] = "Raise Training {n} times",
	["토벌 {n}번"] = "Raid {n} times", ["반짝이 몬스터 {n}마리 처치"] = "Defeat {n} Sparkle Monsters", ["견습 과정 마치기"] = "Finish the Apprentice course",
	["사냥터에서 몬스터 {n}마리 처치"] = "Defeat {n} monsters in a hunt zone", ["주운 장비 입기(가방 G)"] = "Wear gear you found (Bag G)", ["첫 보스(스테이지 5) 처치"] = "Defeat the first boss (Stage 5)",
	["무기 강화 +{n}"] = "Enhance weapon to +{n}", ["수련 1번 하기(U)"] = "Train once (U)", ["보스 스테이지 {n} 처치"] = "Clear boss stage {n}",
	["두 번째 구역(수정 동굴) 가 보기"] = "Visit zone 2 (Crystal Cave)", ["체크포인트 {n}곳 찾기"] = "Find {n} checkpoints", ["둥지에서 알 줍기"] = "Pick up an egg from a nest",
	["알 부화하기"] = "Hatch an egg", ["도감 칸 1개 받기(K)"] = "Claim 1 Codex reward (K)", ["큰 나무 전망대에 오르기"] = "Climb to the Big Tree lookout",
	["무기에 보석 장착"] = "Socket a gem in your weapon", ["사냥 지대 {n}곳 둘러보기"] = "Explore {n} hunt spots", ["레벨 {n} 달성"] = "Reach level {n}",
	["첫 환생(환생 제단)"] = "First Rebirth (Rebirth Altar)", ["새 스킬 E 써 보기"] = "Try your new skill E", ["파티로 보스 1번 잡기(P)"] = "Beat a boss in a party (P)",
	["균열 시간에 몬스터 {n}마리"] = "{n} monsters during a Rift", ["두 번째 환생"] = "Second Rebirth", ["새 스킬 R 써 보기"] = "Try your new skill R",
	["세 번째 환생"] = "Third Rebirth", ["네 번째 환생"] = "Fourth Rebirth", ["다섯 번째 환생"] = "Fifth Rebirth",

	-- ═══ 합동 목표 · 주간 도전 · 균열(CommunityGoalData · WeeklyChallengeData · RiftData) ═══
	["강화석 40"] = "Enhance Stone 40", ["알 1"] = "Egg 1", ["한정 칭호 「모두의 영웅」"] = "Limited title 「Everyone's Hero」",
	["주간 합동 목표 %d%%"] = "Weekly Team Goal %d%%", ["주간 합동 목표 · 목표 계산 중"] = "Weekly Team Goal · counting", ["[전 서버] 주간 합동 목표 %d%% 달성! 보상: %s"] = "[All servers] Team Goal %d%% done! Reward: %s",
	["주간 합동 목표"] = "Weekly Team Goal", ["모든 서버의 보스 처치 수 + 초월 획득(큰 칸)"] = "Boss kills on all servers + Transcendent drops", ["미달성"] = "Not yet",
	["이번 주 기여가 있어야 받습니다"] = "Help this week to claim",
	["분신 2배"] = "Double Clones", ["번개 2배"] = "Double Lightning", ["바닥 붕괴 빨라짐"] = "Faster Floor Collapse", ["파편 유도 강화"] = "Stronger Seeking Shards",
	["주간 도전"] = "Weekly Challenge", ["도전"] = "Fight", ["이번 주 순위(처치 시간)"] = "This week's ranks (clear time)", ["아직 기록 없음"] = "No records yet",
	["주간 도전 완료! %.1f초"] = "Weekly Challenge clear! %.1fs", ["지난주 주간 도전 %d위 보상"] = "Last week's challenge reward: #%d",
	["균열이 열렸다! 20분 동안 골드 · 전설 · 유물 · 고대 확률 증가"] = "A Rift opened! 20 min of more gold and rare drops", ["균열이 닫혔다"] = "The Rift closed", ["균열 %d:%02d"] = "Rift %d:%02d",

	-- ═══ 꾸미기 · 상품(CosmeticSlotData · MonetizationData) ═══
	["별빛"] = "Starlight", ["불씨"] = "Ember", ["서리꽃"] = "Frost Bloom", ["말랑 젤리"] = "Squishy Jelly",
	["꽃잎 글라이더"] = "Petal Glider", ["연 글라이더"] = "Kite Glider", ["푸른 드래곤 날개"] = "Blue Dragon Wings", ["구름 고래"] = "Cloud Whale", ["구름 고래 물결"] = "Cloud Whale Wake", ["초원 별빛"] = "Meadow Starlight", ["보랏빛 별"] = "Violet Star", ["오로라 서리"] = "Aurora Frost", ["소다 젤리"] = "Soda Jelly", ["달빛 불씨"] = "Moonlit Embers",
	["민트 낙하산"] = "Mint Parachute", ["베리 낙하산"] = "Berry Parachute", ["비취 날개"] = "Jade Wings", ["자수정 날개"] = "Amethyst Wings", ["대장장이 세트"] = "Blacksmith Set", ["별빛 왕관"] = "Starlight Crown", ["모험가의 은빛 날"] = "Adventurer's Silver Edge", ["모험가 별빛 궤적"] = "Adventurer's Star Trail", ["시즌 출석 개근"] = "Season Regular",
	["골드"] = "Gold", ["보석"] = "Gem", ["랜덤 옵션"] = "Random Option", ["전투력"] = "Power", ["강화 보호"] = "Enhance Protection", ["행운 부스트"] = "Luck Boost", ["경험치 배수"] = "EXP Multiplier", ["골드 배수"] = "Gold Multiplier",
	-- 다른 서버 초월 알림 설정
	["전체"] = "Full", ["배너만"] = "Banner only", ["끔"] = "Off",

	-- ═══ QUEUE-ALL6 H 꾸미기(CosmeticSlotData) ═══
	["망치와 모루"] = "Hammer & Anvil", ["할로윈 박쥐"] = "Halloween Bats", ["슬라임 낙하산"] = "Slime Parachute",
	["로켓 반짝"] = "Rocket Twinkle", ["풍선 펑"] = "Balloon Pop", ["수정 결정 무기"] = "Crystal Weapon", ["황금 망치"] = "Golden Hammer",
	["대장간 화로"] = "Forge Braziers", ["하이파이브"] = "High Five", ["펫 왕관"] = "Pet Crown",
	["+30 증표"] = "+30 Mark", ["환생 없는 초월자"] = "Unreborn Transcendent", ["최초의 초월 +10"] = "First Transcendent +10", ["최초의 초월 +15"] = "First Transcendent +15", ["최초의 초월 +20"] = "First Transcendent +20", -- QUEUE-ALL9E1 0-2
}

return { en = en }
