# 출시 코드 (QUEUE-ALL5 F · QUEUE-STUDIO 0-2 갱신 2026-10-01)

> 코드 표는 한 곳 = `roblox/src/shared/data/SocialRewardData.lua`의 `codes`. 서버 검증 = `roblox/src/server/SocialRewardService.lua`(`find` · `RedeemCode`), 게시판 표시 = `roblox/src/client/UpdateBoard.client.lua`(`validCodes`).
> 사용자 결정(10-01): 출시 코드 = **"출시 기념" · "좋아요 목표" 2개**. `FIRSTBOSS`는 넣지 않는다. 옛 `RIFTOPEN`은 뺐다.

## 1. 지금 코드

| 코드 | 보상(한국어) | Reward (English) | 마감(데이터) | 실제 끝나는 때 | 게시판 | 메모 |
|---|---|---|---|---|---|---|
| `FORGE2026` | 강화석 15 · 반짝 조각 20 | 15 Enhance Stones + 20 Sparkle Shards | `{ 2026, 12, 31 }` | UTC 2026-12-31 23:59:59 = **한국 2027-01-01 오전 8:59:59** | 보임 | 출시 기념(`update.board.code.launch`) |
| `LIKES1K` | 강화석 10 · 반짝 조각 10 | 10 Enhance Stones + 10 Sparkle Shards | `{ 2027, 1, 31 }` | UTC 2027-01-31 23:59:59 = **한국 2027-02-01 오전 8:59:59** | **숨김**(`hidden = true`) | 좋아요 목표 달성 감사(`update.board.code.likes`) |
| `LIKES5K` | 강화석 15 · 반짝 조각 15(자리값) | 15 Enhance Stones + 15 Sparkle Shards | `{ 2027, 6, 30 }`(자리값) | - | **꺼짐**(`inactive = true` - 입력도 안 됨) | 좋아요 2단계 5,000(QUEUE-ALL6 A5) |
| `LIKES10K` | 강화석 20 · 반짝 조각 20(자리값) | 20 Enhance Stones + 20 Sparkle Shards | `{ 2027, 12, 31 }`(자리값) | - | **꺼짐**(`inactive = true`) | 좋아요 3단계 10,000(QUEUE-ALL6 A5) |

- `inactive = true` = 없는 코드와 같다(입력 거절 · 게시판 안 보임). 앞 단계를 달성하면 다음 단계 줄의 `inactive`를 지우고(보상 · 기한 확정) 그 단계 달성 공지 때 `hidden`을 지운다.
- 보상은 작게(데이터 머리 주석 "경제를 흔들지 않게"): 좋아요 목표 코드는 출시 기념보다 작다.
- `hidden = true` = 게시판에 안 보이지만 입력은 된다. 좋아요 목표 1단계 1,000(QUEUE-ALL6 A5 사용자 확정 · 다음 5,000 · 10,000)을 넘기면 공지와 함께 `hidden`을 지우고 업데이트한다. 이름 `LIKES1K`의 숫자를 목표에 맞게 바꾸려면 **공지 전에** 바꾼다(받은 기록이 코드 이름으로 남는다).
- 마감 규칙: `expires = { 년, 월, 일 }` = **그날 UTC 끝까지**(`SocialRewardService.find` - 23:59:59까지 유효). 한국 시간으로는 **다음 날 오전 9시 직전**에 끝난다. 게시판도 UTC로 계산한다(QUEUE-ALL5 C - `DateTime.fromUniversalTime`).
- 계정당 1번(`profile.redeemedCodes` - SAVE v58) · 대소문자 · 앞뒤 공백 무시 · 3 ~ 24자 영문 · 숫자만 · 1인 3초에 1번 · 분당 8번(`codeCooldownSeconds` · `codePerMinute`).
- 입력하는 곳: 설정 → 게임 탭 → 코드 입력(`client/panels/Settings.lua`).
- 보상 지급 = `QuestService.grant`(강화석 · 반짝 조각 등 - 결과 줄은 `srv.reward.*` 키라 영어도 나온다).

## 2. 바꾸는 법
1. `SocialRewardData.lua`의 `codes`에서 줄을 더하거나 `expires` · `hidden`을 고친다. 게시판 설명은 `noteKey`(TextData ko/en 한 쌍)로 단다.
2. 지난 코드는 지우지 않아도 된다 - 마감이 지나면 서버는 "기한이 지난 코드예요"로 거절하고 게시판은 안 보여 준다. 다만 표가 길어지면 정리.
3. 받은 기록(`redeemedCodes`)은 저장에 남으므로 같은 코드 이름을 나중에 다시 쓰면 이미 받은 사람은 못 받는다 - 새 이벤트는 새 이름으로.

## 3. 번역
- 게시판 제목 · 코드 머리글 · 소식 · 코드 설명 = TextData `update.board.*`(ko/en - QUEUE-STUDIO 0-2).
- 남음: 코드 **결과 문장**(`SocialRewardData.text.ok` · `bad` · `expired` · `used` · `slow` - 서버가 보내는 한국어 완성 문장)은 아직 키가 아니다(영어를 켜도 한국어 - `ok`의 보상 요약만 영어).
