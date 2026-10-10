# 업데이트 게시판 첫 글 초안 (QUEUE-ALL5 F · 2026-10-01)

> 허브 업데이트 게시판(`client/UpdateBoard.client.lua` - 데이터 `shared/data/SocialRewardData.lua`의 `news` · `codes`)과 커뮤니티(그룹 · 디스코드) 공지에 같이 쓰는 글.
> 바탕 = `Claude outputs/QUEUE-ALL2/launch/description-drafts.md`의 첫 글 + 지금 `news` 2줄. 그 초안과 달라진 점: 균열 시간은 **매일 2번**(UTC 01:00 · 11:00 = 한국 10:00 · 20:00 - `RiftData.windowsUtc`), 귀환 키는 **B**(`PanelRegistry` hubReturn), 강화하는 곳 이름 = 강화대(Forge).
> 게임 이름이 아직 없어 `{게임 이름}` · `{Game Name}`으로 둔다. 날짜 `{날짜}`는 공개일.

---

## 한국어

**{게임 이름} 문이 열렸습니다! ({날짜})**

안녕하세요! 오늘부터 누구나 큰 나무 마을에서 모험을 시작할 수 있어요.

**처음 오셨다면**
1. 화면의 **오늘의 목표**를 따라가 보세요. 퀘스트 창은 **J**예요.
2. 길을 모르면 **M**(지도)에서 가고 싶은 곳을 누르세요. 발견한 체크포인트로 순간이동도 돼요.
3. 무기는 **강화대**에서 강화해요. 19강부터는 실패하면 내려갈 수 있으니 방지권을 챙기세요.
4. 막히면 **B**로 마을에 귀환! 5분 안에 [돌아가기]를 누르면 원래 자리로 가요.

**새로 들어온 것**
- **균열 시간** - 매일 2번(한국 시간 오전 10시 · 저녁 8시), 20분 동안 전설 · 유물 · 고대 확률 1.5배
- **전 서버 합동 목표** - 모든 서버가 함께 채우는 게이지
- **주간 도전** - 이번 주 보스를 가장 빨리 잡는 사람은?
- **방어구 외형 v3** - 직업마다 다른 모습, 보스 아레나 바닥도 새 단장

**출시 기념 코드** (설정 → 게임 → 코드 입력)
- `FORGE2026` - 강화석 15 · 반짝 조각 20 (2026년 12월 31일까지)
- (좋아요 목표 달성 때 공개) `THANKS1K7Q` - 강화석 10 · 반짝 조각 10 (2027년 1월 31일까지)
- 마감일은 세계 표준시(UTC) 기준이라 **한국 시간으로는 다음 날 오전 9시**에 끝나요.

첫 초월 장비의 주인공은 누가 될까요? 뜨는 순간, 전 서버가 봅니다! 🌟

---

## English

**{Game Name} is open! ({Date})**

Hi! Starting today, anyone can begin their adventure in Big Tree Town.

**New here?**
1. Follow **Today's Goals** on your screen. Press **J** for quests.
2. Lost? Press **M** for the map and tap where you want to go. You can teleport to checkpoints you found.
3. Enhance your weapon at the **Forge**. From +19 a fail can drop a level, so bring Protection Tickets.
4. Stuck? Press **B** to Recall to town. Tap [Return] within 5 minutes to go back.

**What's new**
- **Rift Time** - twice a day (01:00 and 11:00 UTC), 20 minutes of 1.5× Legendary, Relic and Ancient odds
- **Server Co-op Goal** - one gauge every server fills together
- **Weekly Challenge** - who can beat this week's boss the fastest?
- **Armor looks v3** - each class looks different, and boss arenas got new floors

**Launch codes** (Settings → Game → Enter code)
- `FORGE2026` - 15 Enhance Stones + 20 Sparkle Shards (until Dec 31, 2026)
- (revealed when we hit our like goal) `THANKS1K7Q` - 10 Enhance Stones + 10 Sparkle Shards (until Jan 31, 2027)
- Codes end at the end of that day in UTC.

Who will get the first Transcendent item? When it drops, every server sees it! 🌟

---

## 게시판(`news`)에 넣을 짧은 줄 제안 - 지금 구조(`{ date, text }`)는 한국어 한 줄뿐
| 날짜 | 한국어(지금 형식) | English |
|---|---|---|
| 2026-10-01 | 균열 시간(매일 2번 · 20분) · 전 서버 합동 목표 · 주간 도전 추가! | Rift Time (2× daily · 20 min) · Server Co-op Goal · Weekly Challenge added! |
| 2026-10-01 | 방어구 외형 v3 - 직업마다 다른 모습 · 보스 아레나 바닥 새 단장 | Armor looks v3 - a new look for each class · new boss arena floors |

> 번역(QUEUE-STUDIO 0-2): 게시판 소식 · 제목 · 코드 설명 = TextData `update.board.*`(ko/en). 소식을 더할 때는 `news`에 `{ date, textKey }` 한 줄 + ko/en 키 한 쌍.
