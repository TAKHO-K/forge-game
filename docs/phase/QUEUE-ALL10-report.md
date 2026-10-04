# QUEUE-ALL10 보고서

> 2026-10-04 · 지시 = `docs/phase/QUEUE-ALL10-prompt.md` · 상태 = `docs/phase/QUEUE-ALL10-state.md` · 캡처 = `docs/phase/all10/captures/`

## 1. 블록 0 긴급 수정 + 결정 반영

| 항목 | 원인 · 수정 | 하네스 · 확인 | 커밋 |
|---|---|---|---|
| 0-1 결제 이중 지급(AUDIT1 즉시-1) | 저장 실패 때 영수증 기록만 지우고 지급은 메모리에 남아, 다음 자동저장이 "영수증 없는 지급"을 저장 → 재시도가 이미 가진 것으로 보고 토큰 환산을 또 줬다. → `captureUndo`: 이번 처리가 **실제로 새로 넣은 것**(applyReward granted 목록)과 영수증 기록을 함께 되돌리고 NotProcessedYet · 지급과 기록은 같은 프로필 표라 어느 저장에든 함께 들어간다 · 중간 grant 실패도 전부 되돌림(부분 지급 금지) · 처리 중 같은 사람의 토큰 구매 · 시즌 받기 · 선물 받기 busy 거절 · 칸 건너뛰기 표시 영수증별 | `monetize_test` 85/85(새 60경우 = 상품 6 × 실패 패턴 10: 정상 · 1회 · 2회 · 자동저장 끼어듦 · 재접속 · 자동저장+재접속 · 서버 죽음 재접속 · 지급 뒤 재호출 · 대기 중 자동저장 뒤 죽음/퇴장 + 부분 지급 · 장착 · 겹친 영수증 · 퇴장 중 · 게임패스) · 옛 코드에 같은 하네스 = 3 X(버그 재현) · 리뷰어 검토 2회 | 7710795a · 487a3ab6 |
| 0-2 보스전 직업 전환(AUDIT1 즉시-2) | 직업 전환 요청에 보스전 검사가 없었다. → 서버 거절 + 안내(`srv.class.inBoss`) · 직업 창 [이 직업으로] 비활성 + 이유 한 줄(서버 토스트는 창(DisplayOrder 310) 뒤에 가려 Play에서 안 보였다) · 입장 순간 직업을 UserId로 기록 · 첫 클리어 = 입장 직업과 같을 때만(다르면 재도전 표) | `multiplayer_test` 12/12(막타 직전 변경 · 파티원 변경 · 재접속 다른 직업 · 스탠드인) · Play: 보스전 중 클릭 → 직업 그대로 + 안내 · PC · 842 · 작은 폰 캡처 | 8c80ec38 · b4b1e6bf |
| 0-3 AUDIT1 높음(이름표 세트 패스) | `includes`를 펼치는 서버 코드가 없어 79R$ 세트 패스로 색 · 배지 장착이 `no_pass`. → `Monetization.passOwned`(패스 또는 그 키를 includes한 패스) - hasPass · 장착 · Attribute · 화면 owned 한 함수. 같은 원인 중간 등급 없음 | `monetize_test` 세트 패스 줄 | a4f9c821 |
| 0-4 가방 상한(결정 3) | 마일스톤 +5까지 75로 잘라 유료 칸 5칸이 사라졌다(AUDIT1 중간 5도 같은 결함). → 상한 = 유료 75 + 마일스톤 칸(최대 80) · 칸은 매번 계산이라 옛 계정도 다음 접속에 복구 | `monetize_test` 8조합 잘림 0 · 옛 저장 다시 로드 80 | eee6b14a |
| 0-5 자동 정리 첫 안내 기본(결정 5) | 첫 가득 참 안내 [켜기] = 희귀 이하(`ArmorData.autoProcessHintDefault`) · 태초 · 초월 · 보스 출처 제외 그대로 · 설정에서 변경 가능 · 안내 문구 합쇼체 | `bulk_sell_test` 11/11 | b33c141e · b4b1e6bf |
| 0-6 주황 버튼 대비(결정 6) | 밝은 채움 위 밝은 글자(주황 2.23 · 초록 1.7). → 토큰 `UIColors.textOnAccent` - 버튼 부품 primary 7.28 · claim 9.66 · 비활성 5.64 · 토글 ✓ · 직접 만든 버튼 · 배지 5곳 | 자동 대비 검사 ⑤(부품 전 상태 + 밝은 채움 글자 객체 전수) 통과 · 캡처(PC · 작은 폰) | 03f7dd2e |

### 결제 경로 전수 표(수정 뒤)

| 상품 종류 | 지급 함수 | 멱등 · 1회 보장 |
|---|---|---|
| 치장(테마 · 글라이더 · 소품) · 묶음 | `processReceipt` → `applyReward("product")` → `CosmeticService.grant` | 영수증 id 기록 + 지급이 같은 프로필 표(같은 저장) · 저장 실패 = 영수증 + 이번에 새로 넣은 치장만 되돌림(장착 중이면 장착도) · 이미 전부 가짐 = 토큰 환산(되돌림 대상) |
| 스타터 팩(가방 칸 + 치장 2) | 같음 + `bagSources.starter = true` | 출처 bool(한 번) + 영수증 · 실패 = 출처 · 치장 되돌림(퇴장 중에도 오류 없음) |
| 시즌 유료 줄 | `SeasonPassService.setPremium` | bool + 영수증 · 지난 시즌 영수증 = 환산(promptSeason) · 되돌림은 이번 처리가 켠 경우만(겹친 영수증의 유료 줄 보존) |
| 칸 건너뛰기(1 · 5) | `SeasonPassService.applySkip`(수량형) | 영수증 + 실패 = 이 영수증이 표시한 칸만 `revertSkip` · 상한 넘음 = 환산 |
| 토큰 환산(이미 가짐 · 지난 시즌 · 상한 넘음) | `QuestService.grant(sparkleShard)`(수량형) | 영수증 + 실패 = 회수 · 처리 중 토큰 구매 busy 거절(써 버려 회수가 0에서 막히던 구멍) |
| 게임패스 | `PromptGamePassPurchaseFinished` → `UserOwnsGamePassAsync` 확인 → `gamepasses[key] = true` · 접속 때 `refreshPasses` | Roblox 소유 조회가 진실 · bool 캐시(영수증 없음) · 세트 패스 = `passOwned` |
| 토큰 구매 | `buyWithTokens` → `spendShards` → `applyReward("token")` | yield 없는 차감 · 지급 · `ownsAll` 거부 · 영수증 처리 중 busy 거절 |
| 선물 | `GiftService.send` → `claim` → `applyReward("gift")` | gift.id + `mailbox.claimedIds` · 영수증 처리 중 받기 busy 거절 |
| 시즌 줄 받기 | `SeasonPassService.claim` → `applyReward` | `claimedFree` · `claimedPaid` 키 · 영수증 처리 중 busy 거절 |

- 남은 낮음(리뷰): 칸 건너뛰기 영수증 두 건이 겹쳐 앞 건이 실패하면 표시 칸 번호가 한 칸 어긋날 수 있다(칸 수 · 경험치는 정확 · 재시도 때 맞춰짐).
