# 출시 코드 (QUEUE-ALL5 F · 2026-10-01)

> 코드 표는 한 곳 = `roblox/src/shared/data/SocialRewardData.lua`의 `codes`. 서버 검증 = `roblox/src/server/SocialRewardService.lua`(`find` · `RedeemCode`), 게시판 표시 = `roblox/src/client/UpdateBoard.client.lua`(`validCodes`).
> 지금 있는 2개는 **그대로 둔다**. 세 번째는 **제안만**(코드에 넣지 않았다).

## 1. 지금 코드

| 코드 | 보상(한국어) | Reward (English) | 마감(데이터) | 실제 끝나는 때 | 메모 |
|---|---|---|---|---|---|
| `FORGE2026` | 강화석 15 · 반짝 조각 20 | 15 Enhance Stones + 20 Sparkle Shards | `{ 2026, 12, 31 }` | UTC 2026-12-31 23:59:59 = **한국 2027-01-01 오전 8:59:59** | 출시 기념 |
| `RIFTOPEN` | 반짝 조각 30 | 30 Sparkle Shards | `{ 2026, 11, 30 }` | UTC 2026-11-30 23:59:59 = **한국 2026-12-01 오전 8:59:59** | 균열 시간 열림 |

- 마감 규칙: `expires = { 년, 월, 일 }` = **그날 UTC 끝까지**(`SocialRewardService.find` - 23:59:59까지 유효). 한국 시간으로는 **다음 날 오전 9시 직전**에 끝난다. 공지에 "12월 31일까지"라고 쓰면 한국 플레이어에게는 하루 9시간 더 열려 있는 셈이라 손해 보는 사람은 없다.
- 계정당 1번(`profile.redeemedCodes` - SAVE v58) · 대소문자 · 앞뒤 공백 무시 · 3 ~ 24자 영문 · 숫자만 · 1인 3초에 1번 · 분당 8번(`codeCooldownSeconds` · `codePerMinute`).
- 입력하는 곳: 설정 → 게임 탭 → 코드 입력(`client/panels/Settings.lua`).
- 보상 지급 = `QuestService.grant`(강화석 · 반짝 조각 등 - 결과 줄은 `srv.reward.*` 키라 영어도 나온다).

## 2. 제안(넣지 않음) - 0 ~ 1개

| 코드 | 보상 | 마감 제안 | 왜 |
|---|---|---|---|
| `FIRSTBOSS` | 강화석 10 | `{ 2027, 1, 31 }`(한국 2027-02-01 오전 9시 직전) | 첫 보스(스테이지 5)까지 가는 새 플레이어를 붙잡는 작은 보상. 데이터 머리 주석의 원칙("보상 = 작게(강화석 · 반짝 조각) - 경제를 흔들지 않게")에 맞춰 기존 두 코드보다 작게. 게시판 · 디스코드 첫 주 이벤트용 |

- 넣는다면 `codes` 표에 한 줄: `{ code = "FIRSTBOSS", reward = { enhanceStone = 10 }, expires = { 2027, 1, 31 }, note = "첫 보스 응원" },`(코드는 대문자로 적는다 - 입력은 `normalize`가 대문자로 바꿔 비교).
- 필요 없으면 안 넣는다(2개로 충분 - 결정 필요).

## 3. 바꾸는 법
1. `SocialRewardData.lua`의 `codes`에서 줄을 더하거나 `expires`를 고친다. 다른 파일은 안 건드린다(서버 검증 · 게시판이 같은 표를 읽는다).
2. 지난 코드는 지우지 않아도 된다 - 마감이 지나면 서버는 "기한이 지난 코드예요"로 거절하고 게시판은 안 보여 준다. 다만 표가 길어지면 정리.
3. 받은 기록(`redeemedCodes`)은 저장에 남으므로 같은 코드 이름을 나중에 다시 쓰면 이미 받은 사람은 못 받는다 - 새 이벤트는 새 이름으로.

## 4. 확인할 것(번역 · 시간)
- 코드 결과 문장(`SocialRewardData.text.ok` · `bad` · `expired` · `used` · `slow`)과 게시판 제목(`text.board` · `text.codes`) · 코드 메모(`note`)는 **TextData 키가 아닌 한국어 완성 문장**이다 - 영어를 켜도 한국어로 나온다(`ok`의 보상 요약 부분만 영어). 영어 출시 전에 키로 옮겨야 한다(결정 필요 - 이번 범위 밖).
- 게시판의 "지금 쓸 수 있는 코드" 목록은 **클라이언트**가 `os.time(표)`로 마감을 계산한다(`UpdateBoard.client.lua` `validCodes`). 서버 주석은 "`os.time(표)`는 지역 시간 해석 - 로블록스 서버는 UTC"라 했는데, 클라이언트가 한국 시간으로 해석하면 게시판에서는 서버보다 **9시간 일찍** 사라질 수 있다(코드는 그때도 서버에서 받아진다). Studio에서 한 번 확인 필요.
