# 보안 대응 절차서 (QUEUE-ALL6 F · 2026-10-02)

> 대상 = 운영자(허용 계정 `server/OpsConfig.lua` userIds). 명령 = 게임 안 채팅 `/ops …`(결과는 명령한 사람에게만 시스템 줄로 온다 · 모든 실행은 `OpsLog_v1`에 남는다).
> 원칙: **자동 처벌은 없다.** 서버는 조용히 기록(의심 · 감사)만 하고, 사람이 증거를 보고 판단한다. 이동 이상은 처벌 대신 "마지막 정상 위치로 되돌림"만 한다.
> 위험 목록 · 지금 방어 = `docs/design/security-audit-launch.md` 8절. 탐지 기준값 = `roblox/src/shared/data/SecurityOpsConfig.lua`(한 곳).

## 0. 명령 요약

| 명령 | 하는 일 | 주의 |
|---|---|---|
| `/ops inspect <userId>` | 프로필 요약(레벨 · 스테이지 · 골드 · 태초/초월 수 · 환생) + 최근 의심 기록 + 감사 기록 | 접속 중이면 메모리 값 · 아니면 저장값 |
| `/ops versions <userId>` | 저장 버전 목록(최근 10 · 30일 보관) | |
| `/ops rollback <userId> <버전 또는 UTC 시각>` | 그 시점 저장으로 **미리보기**(지금 vs 그때 차이) + 확인 번호 | 아직 아무것도 안 바뀜 |
| `/ops rollback confirm <확인 번호>` | 실행: 접속 중이면 이 서버에서 내보냄 → 지금 저장본을 백업 저장소에 복사 → 그 버전으로 덮기 → 다른 서버 저장은 낡은 세션으로 거절됨 | 백업 실패 = 실행 안 함 |
| `/ops revoke <userId> <번호|rollId>` | 태초 회수(옛 명령 그대로 - 결번 · 칭호 정리) | |
| `/ops revoke <userId> t<번호>` | **가짜 초월** 회수: 아이템 삭제 · 세계 번호 결번(명예의 전당에서 빠짐) · 초월자 칭호 · 도감 초월 줄 정리 | 접속 중일 때만(이 서버) |
| `/ops revoke <userId> <재화> <수량>` | 재화 회수(gold · sparkleShard · enhanceStone · highEnhanceStone · gemDust) - 0 아래로는 안 내려감 | 접속 중일 때만 |
| `/ops leaderboard remove <userId>` | 개인 · 직업 순위 + 이번 주 주간 도전 기록 제거 | 옛 `/ops lbremove`도 그대로 |
| `/ops ban <userId> <기간> <사유>` | 로블록스 기본 차단(`Players:BanAsync` · 경험 전체 · 부계정 포함) · 기간 = `1d` · `7d` · `30d` · `perm` | 사유는 사용자에게 보이는 글(짧게) |
| `/ops unban <userId>` | 차단 풀기(`Players:UnbanAsync`) | |

## 1. 핵 신고를 받았을 때
1. **증거 받기**: 신고자에게 영상 · 스크린샷 · 시각(대략) · 상대 이름을 받는다. 이름 → userId는 로블록스 프로필 주소에서.
2. `/ops inspect <userId>`: 의심 기록(이동 되돌림 · 골드/분 · 처치/분 · 요청 폭주 · 드랍 운 · 보스 처치 시간)이 신고 시각 근처에 있는지 본다.
3. **판단 기준**
   - 의심 기록 0 + 증거가 애매 → 기록만 남기고 지켜본다(아무것도 안 함).
   - 이동 되돌림만 반복(속도 · 비행) → 서버가 이미 막고 있다. 반복이 많고 영상이 분명하면 7일 차단.
   - 골드 · 드랍 · 보스 기록이 이론 최대를 넘음 → 4로.
4. **조치 고르기**(가벼운 것부터): 순위 정리(`leaderboard remove`) → 부정 이득 회수(`revoke`) → 그래도 안 되면 그 시점으로 되돌리기(`rollback` - 그 사람만) → 반복 · 악의 = 차단(`ban 7d` → 재범 `perm`).
5. 순위 · 주간 도전 기록에 남아 있으면 `/ops leaderboard remove`.
6. 결과를 운영 메모(날짜 · userId · 증거 · 조치)에 적는다(명령 자체는 OpsLog에 자동 기록).

## 2. 복제(dupe) 버그를 발견했을 때
1. **버그 먼저 막는다**: 원인 경로를 기능 스위치로 끄거나(아래 3) 패치를 퍼블리시한다. 되돌리기는 그 뒤.
2. **영향 계정만 찾는다**(전체 되돌리기 금지): 감사 기록(`AuditTrail_v1` - 태초/초월 획득 · 강화 +20 이상 · 큰 골드 변화 · 상점 구매 · 코드/초대/선물)에서 그 버그 시간대 · 그 종류 기록을 가진 userId를 모은다. Studio Edit 모드 `execute_luau`로 `DataStoreService:GetDataStore("AuditTrail_v1"):GetAsync("u<userId>")`(키 목록은 의심 신고 · 순위 상위부터).
3. 계정마다: `/ops inspect` → 복제로 늘어난 것만 `revoke`(재화 · 아이템). 넓게 꼬였으면 그 사람만 `rollback`(버그 직전 버전).
4. 정상 이득까지 잃는 사람이 생기면 `/ops gift`로 보상(치장 · 조각만).

## 3. 서버 전체 문제(크래시 · 연출 폭주 · 경제 구멍)
- 아트 끄기: Workspace Attribute `ArtStyleV1Force = false`(카툰 스타일 → base) - 퍼블리시 없이 Studio에서 값 바꿔 퍼블리시하거나 다음 업데이트에.
- 기능 끄기: 데이터 스위치(`CheckpointTeleport` · `RiftForce = false` · 상품 `productId = 0`) → 패치 퍼블리시 → 서버 재시작(Creator Hub "Shut down all servers"는 마지막 수단).
- 저장 이상(대량 손상)이면 퍼블리시를 멈추고 `docs/design/save-audit-launch.md` 절차.

## 4. 하지 말 것
- **전체 롤백**(모든 사람을 같은 시점으로) - 정상 플레이어의 진행이 사라진다.
- **증거 없는 차단** - 의심 기록은 "볼 이유"이지 증거가 아니다(기준은 오탐을 줄이게 넉넉히 잡았지만 0은 아니다).
- 접속 중인 사람에게 `restore`(옛 명령)를 쓰지 말 것 - `rollback confirm`은 먼저 내보낸다.
- 운영 계정을 늘릴 때 코드(`OpsConfig.userIds`)만 바꾸고 채팅으로 권한을 주지 말 것.

## 5. 기록이 남는 곳(보관)
| 저장소 | 내용 | 보관 |
|---|---|---|
| `AuditReview_v1`(키 `u<userId>`) | 의심 기록 · 검토 대기(태초 확률 · 처치 속도 · 이동 · 골드 · 요청 · 보스 시간) | 최근 30개 |
| `AuditTrail_v1`(키 `u<userId>`) | 감사 기록(획득 · 강화 · 큰 골드 · 구매 · 지급 · 운영) | 최근 200개 · 90일 지난 것 버림 |
| `OpsLog_v1`(키 `log`) | 운영 명령 전부 | 최근 200개 |
| `OpsRollbackBackup_v1`(키 `u<userId>_<시각>`) | 되돌리기 직전 저장본 | 수동 정리 |
| 저장 버전(DataStore) | 프로필 버전 | 30일(로블록스) |
