# 미구현 목록 (AUDIT1 B-4 · 2026-10-04)

> 항목마다 "사용자 조언" 칸에 의견을 적어 주시면 됩니다.
> 기준 시점은 master `f639a73e`입니다. 코드는 `roblox/src` 기준 경로입니다.
> 상태 판정 규칙: **구현 코드를 찾은 것만 "완료"**로 적었습니다. 문서에만 있으면 "자리만" 또는 "없음"입니다.
> 상태는 코드 grep과 읽기로 확인했습니다. Studio Play는 하지 않았습니다.
> 예상 시간은 지금까지의 실측 속도(단계당 1~2시간)를 기준으로 잡은 추정입니다. 사용자 확인 시간과 Creator Hub 작업 시간은 넣지 않았습니다.

## 요약

| 출시 필요도 | 개수 | 예상 시간 합계 |
|---|---|---|
| 출시 필수 | 9 | **약 40.8시간**(ALL10 30시간 포함 · ALL10을 빼면 10.8시간) |
| 권장 | 19 | 약 55.5시간 |
| 출시 후 | 18 | 약 85시간 이상(미정 항목 포함) |
| 폐기 후보 | 7 | 0시간(결정만 필요) |
| 완료로 확인 | 40여 개 | 맨 끝 표 |

- 꼭 알아 둘 것 1: `docs/STATE.md` 63줄에는 "C5-4·5·6(복귀 · 자동 이동 · 세대) = 자리만, 미배선"이라고 적혀 있습니다. 이 기록은 낡았습니다. 커밋 `92a761d`에서 배선됐고, 코드에서도 동작합니다(아래 완료 표).
- 꼭 알아 둘 것 2: 출석 2일차 보상인 **환생 무료권은 지급만 되고 쓰는 곳이 없습니다**(F6).
- 꼭 알아 둘 것 3: 친구 공개 시험(launch-checklist 2-5의 2단계)을 라이브 서버에서 하면, 그 시험 기록이 명예의 전당 · 세계 번호에 그대로 남습니다(F5).
- 지시 목록 대조 메모(QUEUE-N1004 B-4): "K 직업 옵션" = 직업별 스킬 변형(K4 · `SkillVariantData` · IdRegistry `skillVariant`)과 직업 고유 능력(`TrainingData` abilities)으로 구현됨 - 완료 표 K4 · 수련 줄 참고. "전투력 연출" · "주간 의뢰판" · "귀환 취소"도 완료 표에 있다(귀환 중 대시만 했을 때 = R9).

---

## 출시 필수

### F1 상품 · 게임패스 ID 채우기(29칸)
- 설명: 개발자 상품과 게임패스 id가 전부 0이어서, 상점의 로벅스 버튼이 모두 회색 "준비 중"으로 나옵니다.
- 출처: `docs/phase/launch-checklist.md` 0절 2 · 1-2 · 3절 19 · `docs/design/monetization-p4c.md` §9
- 현재 상태: **자리만**
  - `shared/data/MonetizationData.lua:23-50`: 상품 `productId = 0` 23줄
  - 같은 파일 `:90-96`: 게임패스 `passId = 0` 6줄
  - 0이면 막히는 곳: `server/MonetizationService.lua`의 `not_ready`
- 출시 필요도: 필수 — 0이면 수익화가 하나도 동작하지 않습니다.
- 의존: Creator Hub에서 상품을 만드는 작업(사용자) · F4(가격 · 묶음)
- 예상 시간: 1시간(코드 입력 + Play 로그 확인. Creator Hub 작업은 별도)
- 구현 방식:
  - ① 체크리스트 1-3절 순서대로 숫자를 넣고, Play에서 `[B2] 상품 등록 거부` 0줄인지 확인
  - ② 출시 공개 단계(`release = 1`) 상품만 먼저 채우기
  - 추천: ②. 2단계 상품은 공개 때 채웁니다.
- 사용자 조언:

### F2 시즌 1 시작일
- 설명: 시작일이 비어 있으면 리더보드 시즌과 시즌 패스(8주)가 영원히 1시즌에 멈춥니다.
- 출처: `launch-checklist.md` 2-1 · `roadmap-v2.md` P6
- 현재 상태: **없음** — `shared/data/LeaderboardConfig.lua:22` `firstSeasonDateKst = nil`
- 출시 필요도: 필수 — 서버가 시작할 때마다 경고가 뜨고, 시즌이 넘어가지 않습니다.
- 의존: 오픈일 결정. 협동 목표 때문에 월요일 오픈을 추천합니다(`launch-checklist.md` 3절 11).
- 예상 시간: 0.2시간
- 구현 방식: ① 오픈일 `{ 년, 월, 일 }` 한 줄 입력. 추천: ①
- 사용자 조언:

### F3 게임 이름
- 설명: 메인 메뉴 로고 자리와 설명 초안의 게임 이름이 자리값 "NAME"으로 남아 있습니다.
- 출처: `launch-checklist.md` 6절 3 · `QUEUE-ALL9C-report.md` 8절 6
- 현재 상태: **자리만** — `shared/data/GameInfoData.lua:4` `name = "NAME"`. `check_textdata.py`가 경고를 냅니다.
- 출시 필요도: 필수 — 플레이어 첫 화면에 "NAME"이 보입니다.
- 의존: 이름 결정(사용자) · 설명 초안 · 썸네일 글자
- 예상 시간: 0.3시간
- 구현 방식: ① 데이터 한 줄 + 설명 초안 `{게임 이름}` 바꾸기. 추천: ①
- 사용자 조언:

### F4 상점 출시일 자리값 · 대장장이 묶음 가격
- 설명: 상점 NEW 표시의 기준 날짜가 자리값입니다. 또 대장장이 묶음(499)이 구성품 합계(447)보다 비쌉니다.
- 출처: `QUEUE-ALL9C-report.md` 8절 4
- 현재 상태: **자리만**
  - `MonetizationData.lua:68` `releaseStageStartUtc = { [1] = 1790985600 } -- 2026-10-03(자리)`
  - `:50` `bundle_blacksmith` 499 · `proposal = true`(2단계라 아직 비공개)
- 출시 필요도: 필수(날짜) — 묶음은 2단계 상품이라 출시 후에 정해도 됩니다.
- 의존: F2(오픈일)
- 예상 시간: 0.3시간
- 구현 방식:
  - ① 날짜를 오픈일로 바꾸고, 묶음은 447 미만(예 399)으로
  - ② 묶음 구성품을 바꿔 가격을 맞추기
  - 추천: ①
- 사용자 조언:

### F5 launchEpoch — 명예의 전당 · 세계 번호 시험 기록 분리
- 설명: Studio는 `test_` 키를 쓰지만, 라이브 비공개 · 친구 시험은 실제 키를 씁니다. 그래서 출시 전 시험에서 나온 태초 · 초월 세계 번호와 명예의 전당 기록이 출시 뒤에도 남습니다. 협동 목표 · 리더보드도 같은 문제가 있습니다(체크리스트 3절 11이 경고).
- 출처: `QUEUE-N1004-prompt.md` 83줄 · `launch-checklist.md` 2-5 · 3절 11
- 현재 상태: **없음**
  - 코드에 `epoch`가 0건입니다.
  - `server/PrimordialRegistry.lua:46-51` `keyFor`는 Studio일 때만 시험 접두어를 붙입니다.
  - `server/HallOfFame.lua`는 그 키를 그대로 읽습니다.
- 출시 필요도: 필수 — "세계 첫 초월 #1"이 시험 기록이 되면 되돌릴 수 없습니다(데이터 삭제 금지 규칙).
- 의존: F2(오픈일)
- 예상 시간: 2시간
- 구현 방식:
  - ① 데이터 `launchEpoch = "v1"` 한 칸을 두고, 카운터 · 최근 목록 · 협동 목표 · 시즌 키 앞에 붙이기. 출시 직전에 값만 바꿉니다.
  - ② 오픈 시각(UTC) 이전 기록을 읽을 때 걸러내기(키는 그대로)
  - 추천: ①. 옛 키를 지우지 않고 새 키로 넘어가므로 삭제 금지 규칙과 맞습니다.
- 사용자 조언:

### F6 환생 무료권 쓰는 곳
- 설명: 7일 출석 2일차에 주는 "환생 무료권"이 지급만 되고 쓸 수 없습니다. 아이템 설명도 "곧 열림"입니다.
- 출처: `docs/design/ftue-attendance-q12.md` · `QUEUE-10h-report.md` §10 결정 1 · §14
- 현재 상태: **일부**(지급만)
  - 지급: `server/QuestService.lua:200-202`, Attribute `RebirthTicket` `:155`
  - 소비 코드 0곳(`RebirthServer`)
  - `shared/data/QuestData.lua:39` 주석 "자리 - 쓰는 곳 없음"
  - `TextData_items.lua:25` "곧 열림"
- 출시 필요도: 필수 — 신규 유저 이틀째 보상이 쓸모없는 아이템이 됩니다.
- 의존: 결정 Q12-1
- 예상 시간: 2시간
- 구현 방식:
  - ① (가) 환생 요구 레벨 −10% 1회(EconSim: 환생 1 34분 → 31분, 나머지 곡선 영향 0)
  - ② 2일차 보상을 다른 기존 재화로 바꾸기
  - 추천: ①(이미 측정됨)
- 사용자 조언:

### F7 폰 HUD 필수 수정(P4e) 남은 9건 판정
- 설명: 폰 800×360 기준 겹침과 크기 점검입니다. 두 건만 확인됐고, 아홉 건은 확인 기록이 없습니다.
- 출처: `QUEUE-10h-extra-prompt.md` Q14 · `QUEUE-10h-report.md` §12-5 · `QUEUE-10h-state.md:155`
- 현재 상태: **일부**
  - 완료 2건: 직업 변경 버튼(`ClassSelectUI.client.lua:422`) · 메뉴바 × 대시(`hud/MenuBar.client.lua`)
  - 미확인 9건: 친구 부르기 · 파티 HUD 690 · 알림 행 24 · 태초 띠 524 · 폰 태초 알림 12 · 도감 띠 · 점 · 큰 화면 대시 · 모바일 요청 배너 · 채팅 × 메뉴바
  - 관련 코드는 있습니다(`PartyListView.lua` compact · `panels/Party.lua:320` · `hud/RequestBanner.lua`).
- 출시 필요도: 필수 — 로블록스 사용자 다수가 폰입니다. 다만 대부분 "판정만" 하면 되는 일입니다.
- 의존: 없음(ALL9C의 폰 캡처 자산 재사용 가능)
- 예상 시간: 3시간(판정 1.5 + 수정 1.5)
- 구현 방식:
  - ① Play에서 폰 강제(TEMP-PHONE) + 800×360 캡처로 9건을 표로 판정
  - ② `RequestBannerCheck`식 자체 점검 숫자 검사를 추가
  - 추천: ① 먼저, 실패한 건만 ②
- 사용자 조언:

### F8 다중 클라 · 폰 실기 성능
- 설명: PC 4인 보스, 필드 12인, 폰 fps/p95가 한 번도 측정되지 않았습니다. Studio MCP로는 클라 1개만 됩니다.
- 출처: `QUEUE-ALL1-report.md` §10 · §13-10 · `QUEUE-ALL2-report.md` §5 · `QUEUE-ALL9C-report.md` 7절 2
- 현재 상태: **없음**(측정 기록 없음)
- 출시 필요도: 필수 — 서버 크기 16명 결정의 근거가 서버 쪽 측정뿐입니다.
- 의존: 친구 · 테스터 공개(체크리스트 2-5의 2단계) · F5(시험 기록 분리)
- 예상 시간: 2시간(측정 정리. 사람 손 필요)
- 구현 방식:
  - ① 친구 공개 때 F9 콘솔 + Telemetry로 측정
  - ② 실기 폰 1대로 필드 · 보스만 측정
  - 추천: ① + ②
- 사용자 조언:

### F9 ALL10 초월 계승(통합 밸런스)
- 설명: 태초 +30 → 초월 +0 계승, 초월 강화 0~20, 고급 수련 51~100, 방어 수련, 초월 보석, 고스테이지 몹 곡선 재조정, 후반 골드 소모처를 한 번에 넣는 큰 묶음입니다(R1~R21 · D1~D17).
- 출처: `QUEUE-N1004-prompt.md` 블록 C · 부록 · `docs/design/transcend-inherit-baseline.md` · `docs/design/econ-baseline-pre-all10.md` · `QUEUE-ALL9C-report.md` 6절(ALL10 이관 6건)
- 현재 상태: **없음**
  - 계승 · 고급 수련 · 초월 보석 코드 0
  - `shared/data/StatSheetData.lua:4` 주석에만 예고가 있습니다.
  - 설계와 시뮬은 N1004 블록 C(제안서 단계)입니다.
- 출시 필요도: 필수 — 사용자 결정 D14가 "출시 전 구현 + 기능 스위치"입니다. 후반 골드가 2^53을 넘는 문제(R11)도 이 묶음으로 해결합니다.
- 의존: N1004 블록 C 제안서 → 사용자 결정 → R11
- 예상 시간: 약 30시간(설계 확정 뒤 구현 · 저장 버전 · 하네스 · UI · Play)
- 구현 방식:
  - ① 제안서 숫자대로 한 번에 구현하고 기능 스위치로 끈 채 출시한 뒤, 켜기
  - ② 계승 + 초월 강화만 먼저(P2a), 고급 수련 · 보석은 다음(P2b)
  - 추천: ②. 저장 변경을 두 번에 나누면 롤백 위험이 줄어듭니다.
- 사용자 조언:

---

## 권장

### R1 보스 평타 "내려찍기" 변형
- 설명: 평타 변형 2~3가지(좌→우 · 우→좌 · 내려찍기) 가운데 내려찍기가 없습니다.
- 출처: `docs/design/v2/01-fix-queue.md` C-1 · `QUEUE-ALL1-report.md` §2 · §11-6
- 현재 상태: **일부**
  - 좌우 2가지만 있습니다: `server/MonsterAI.server.lua:382-409`
  - 같은 변형은 연속 2회까지: `shared/data/BossData.lua:1469` `basicSwingMaxRepeat = 2`
  - 원인: 모션 클립이 없습니다.
- 출시 필요도: 권장 — 평타가 단조롭게 보입니다. 피해 · 간격은 같습니다.
- 의존: 보스 모션 클립(`BossMotionData`)
- 예상 시간: 3시간
- 구현 방식:
  - ① `BossMotionData`에 절차 모션 smash 변형 추가(6종 공용)
  - ② 보스별 Blender 클립
  - 추천: ①
- 사용자 조언:

### R2 판정 대 모션 도달 0.9~1.1 남은 스킬
- 설명: 몸 크기나 대기 자세 때문에 판정보다 크게 보이는 스킬이 남아 있습니다. "맞은 줄 알았는데 안 맞음" 혼란이 생길 수 있습니다.
- 출처: `01-fix-queue.md` C-2 · `QUEUE-ALL2-report.md` §7 · §8-7 · 8
- 현재 상태: **일부**
  - 기준을 넘는 스킬: 서리 강화 평타 1.61 · 원 안 짓밟기 1.75 · 빙결 강타 1.19 · 수호자 원 안 내려찍기 1.16 · 폭풍 강화 평타 1.18 · 원 안 낙뢰 1.27 · 전갈 모래 잠복 1.84
  - 측정 하네스 `reach_test`가 레포에 없습니다(스크래치에만 있었음).
- 출시 필요도: 권장
- 의존: 결정(대기 자세 · visualScale 변경 vs 그대로) · 강공격 땅 고리 0.26 타격감 결정
- 예상 시간: 4시간(하네스 레포 등록 1 + 조정 3)
- 구현 방식:
  - ① 대기 자세 · visualScale 조정
  - ② 땅 치기 이펙트를 판정 원 안에서 퍼지게(`BossBodyFx`)
  - 추천: ② 먼저(판정과 겉모습이 같아짐), ①은 서리만
- 사용자 조언:

### R3 몬스터 첫 만남 "!" 표시
- 설명: 새 종을 처음 볼 때 "!" + 도감 칸 연출을 하려던 것입니다. 서버 신호는 있지만 클라가 그리지 않습니다.
- 출처: `docs/plan/open-plan.md` 제안 2 · M2(BUNDLE-6h)
- 현재 상태: **자리만**
  - 서버 `server/MonsterTemperament.lua:116` `MobAlert`, 종 4개 `alertMotion = "mark"`
  - 클라 `client/MonsterRigAnimator.client.lua:61-66`은 포효 자세만 그립니다.
  - `MonsterCodexData.firstMetField`는 참조 0입니다.
  - 도감 칸 기록은 완료입니다(`CodexService.lua:327`, 첫 만남 = 첫 처치).
- 출시 필요도: 권장
- 의존: 없음
- 예상 시간: 2시간
- 구현 방식:
  - ① 경계할 때마다 머리 위 작은 "!" (클라)
  - ② 도감에 없는 종을 처음 볼 때만 큰 "!" + "새 몬스터" 토스트
  - 추천: ②(피로 금지 규칙)
- 사용자 조언:

### R4 파티 토벌
- 설명: 토벌(재도전 보상)이 솔로만 됩니다. 파티로 시도하면 "파티 토벌은 곧 열립니다"가 뜹니다.
- 출처: `QUEUE-10h-prompt.md` Q5 · `QUEUE-10h-report.md` §4-10
- 현재 상태: **일부**
  - 솔로: `server/BossGate.lua:92` `raidCheck` · `:193` `enterRaid`
  - 파티 거절: `:197-199` `party_later`
  - 문구: `TextData_server.lua:52`
- 출시 필요도: 권장 — 화면에 "곧 열립니다"가 보이는 약속이라, 출시 뒤 오래 비면 불만이 생깁니다.
- 의존: 토벌 시간 공정성(결정 4) · 파티 기여 규칙
- 예상 시간: 5시간
- 구현 방식:
  - ① 파티 토벌 스테이지 = 파티원 중 가장 낮은 "최근 클리어 보스 스테이지"
  - ② 출시 때는 문구만 "솔로 전용"으로 바꾸기
  - 추천: 출시는 ②, 출시 후 ①
- 사용자 조언:

### R5 환생 보상표 한 장
- 설명: 환생할 때 무엇이 열리고 무엇을 받는지 한 화면에 보여 주는 표입니다.
- 출처: `QUEUE-10h-prompt.md` Q7-8 · `QUEUE-10h-report.md` §5
- 현재 상태: **일부**
  - `client/panels/Enhance/RebirthView.lua:69-82`가 글자 한 칸이고, 주석에 "보상 줄 UI는 U1"이라고 적혀 있습니다.
  - `panels/Milestones.lua`는 레벨 마일스톤 표입니다.
- 출시 필요도: 권장 — 환생 1(약 35분)이 첫 큰 결정 순간입니다.
- 의존: 없음(`MovementUnlockData` · 마일스톤 데이터 재사용)
- 예상 시간: 2.5시간
- 구현 방식:
  - ① 환생 확인 창에 1~5회 줄 표(이동 해금 · 보상 · 되찾기 배수)
  - ② 도움말 백과에 분류 추가
  - 추천: ①
- 사용자 조언:

### R6 R · T 스킬 모션 표준
- 설명: 궁극기와 R 스킬이 원 · 링 · 오라 표시뿐입니다. 캐릭터가 전조 → 동작 → 회복 모션과 리본을 하지 않습니다.
- 출처: `docs/plan/open-plan.md` 제안 8 · `docs/design/motion-standard.md` · `BUNDLE-6h-report.md`
- 현재 상태: **일부**
  - `client/hud/UltGauge.client.lua:187-208`
  - `SkillInput`의 `ultHit`는 `playHits`만 부릅니다.
  - 대검 변신 몸 ×1.15 연출도 없습니다.
- 출시 필요도: 권장 — 궁극기가 "보이는 한 방"이 되지 않습니다.
- 의존: 판정 시각 불변 확인(W3b 방식)
- 예상 시간: 6시간
- 구현 방식:
  - ① `PlayerMotionData`에 T 4종 · R 4종 포즈를 추가하고 판정 시각에 맞춤
  - ② T만 먼저
  - 추천: ②
- 사용자 조언:

### R7 K 리뷰 지적 남은 것 확인
- 설명: BUNDLE-6h 리뷰에서 나온 지적 가운데 반영 여부를 확인하지 못한 것이 있습니다.
  - 쌍검 처치 반환이 despawn이나 남의 처치에도 +50이 되는지
  - R · T 거부 로그에 빈도 제한이 없음
  - 포효 `tauntSeconds` 필드가 grep에 안 걸림
- 출처: `BUNDLE-6h-report.md`(리뷰) · `docs/plan/open-plan.md` §3 보안
- 현재 상태: **미확인**(코드 근거 부족 - AUDIT1 버그 표에서 판정 필요)
- 출시 필요도: 권장
- 의존: AUDIT1 B-3 검수
- 예상 시간: 2시간
- 구현 방식:
  - ① 하네스로 재현한 뒤 고치기
  - ② 거부 로그만 `RequestGate` 빈도 제한 재사용
  - 추천: ①
- 사용자 조언:

### R8 상점 [확률] 탭
- 설명: 확률 공개 창이 퀘스트 창 버튼 하나로만 열립니다. 설계는 "상점이 생기면 [확률] 탭이 표준"입니다.
- 출처: `docs/design/bag-disclosure-q13.md:35` · `QUEUE-10h-report.md` §10-11
- 현재 상태: **일부**
  - 한 소스: `shared/Disclosure.lua`
  - 여는 곳: `client/panels/Quests.lua:360-364`뿐
  - 상점 탭: `Shop/init.lua:39`(확률 탭 없음)
- 출시 필요도: 권장 — 유료 랜덤이 0개라 규정상 필수는 아닙니다. 찾기 쉬움의 문제입니다.
- 의존: 없음
- 예상 시간: 1.5시간
- 구현 방식:
  - ① 상점 탭 하나 추가(같은 `Probability` 창 재사용)
  - ② 도움말 백과에서 링크
  - 추천: ①
- 사용자 조언:

### R9 귀환 중 대시만 했을 때 취소
- 설명: 귀환 집중 중에 이동 입력 없이 대시만 하면 취소되지 않습니다. 주석은 "대시 = 취소"라고 적고 있습니다.
- 출처: `docs/design/v2/10-ingame-feedback-1001.md` §6
- 현재 상태: **일부**
  - `client/WorldClient.client.lua:366`: 주석만 있고 `DashAt`을 읽지 않습니다.
  - 그 밖(B 다시 누름 · 이동 · 점프 · 피격)은 완료입니다.
- 출시 필요도: 권장(작은 버그)
- 의존: 없음
- 예상 시간: 0.5시간
- 구현 방식: ① Heartbeat 검사에 `DashAt` 변화 추가. 추천: ①
- 사용자 조언:

### R10 펫 부화 대기열 해금 기준 통일
- 설명: 자동 줍기는 계정 최고 레벨(peakLevel)을 기준으로 열리는데, 부화 대기열 +1(Lv 300)은 지금 레벨을 기준으로 해서 환생하면 다시 잠깁니다.
- 출처: `QUEUE-10h-report.md` §10-2(결정 = peakLevel)
- 현재 상태: **일부**
  - `server/PetService.lua:47,68` `getCharacterLevel`
  - 자동 줍기는 `:50,132-138` peakLevel
- 출시 필요도: 권장(결정과 어긋난 코드)
- 의존: 없음
- 예상 시간: 0.5시간
- 구현 방식: ① peakLevel로 통일. 추천: ①
- 사용자 조언:

### R11 골드 예산표 · 후반 골드 소모처
- 설명: 목표는 골드 사용처 비율(강화 45 · 수련 25 · 기타 20 · 상점 10)입니다. 실제로는 상위 1% · 일반의 후반 잉여율이 99.9%이고, 6개월이면 2^53을 넘습니다.
- 출처: `docs/design/gold-budget-g3.md:45-54` · `QUEUE-10h-report.md` §4-1 · §14 · `QUEUE-ALL9B-report.md` §10 · `docs/phase/all9b/goldcheck.md`
- 현재 상태: **없음**(문서와 EconSim만 · 목표 미달)
- 출시 필요도: 권장(구현은 F9 안에서 합니다)
- 의존: F9 ALL10
- 예상 시간: 0시간 추가(F9에 포함)
- 구현 방식:
  - ① ALL10 초월 강화 · 고급 수련을 "수입 비례 소모처"로
  - ② 비율 목표를 전반(≤ 5,000)으로만 좁히기
  - 추천: ① + ②
- 사용자 조언:

### R12 장비 아트 마감(ALL9E 이관)
- 설명: 다음이 남아 있습니다.
  - 아이콘 112장 재렌더 · 업로드, 키를 `gear_v3`로 전환
  - 장갑 · 신발 메시가 통 모양
  - 무기가 대검 하나로 4칸
  - 변신 무대 장비 문제 3건
  - 3D 장비 옛 색 23곳
- 출처: `QUEUE-ALL9C-report.md` 6절 ALL9E 이관 · `docs/design/gear-art-v3.md`
- 현재 상태: **일부**(틀 · 16장 확인까지 · 2-5)
- 출시 필요도: 권장 — 가방을 열 때마다 보이는 그림입니다.
- 의존: 사용자 검수(GPT 시안)
- 예상 시간: 12시간
- 구현 방식:
  - ① `icons_v3.py`로 일괄 재생성 → upload.py → 키 전환
  - ② 출시는 지금 아이콘, 메시만 먼저
  - 추천: ①(아이콘이 가장 많이 보임)
- 사용자 조언:

### R13 허브 회색 기능 기둥 4개 에셋화
- 설명: 부화장 · 파티 게시판 · 순위판 · 명예의 전당 자리가 회색 콘크리트 기둥으로 보입니다.
- 출처: `QUEUE-ALL9A-report.md` §4 · §8
- 현재 상태: **없음**
  - `shared/data/HubArtData.lua`에 4자리 모델 매핑이 없습니다.
  - `PetData.lua:25` `hatchery placeholder = true`
- 출시 필요도: 권장 — 마을 첫인상입니다.
- 의존: 없음(Blender 소품 파이프라인)
- 예상 시간: 3시간
- 구현 방식:
  - ① 소품 4개 제작 + `HubArtData` 한 줄씩
  - ② 기존 게시판 메시 재사용
  - 추천: ②로 먼저 가리고 ①은 나중
- 사용자 조언:

### R14 영어 번역 잔여 · 넘침
- 설명: 다음이 남아 있습니다.
  - 데이터 표시 이름 · 서버 방송 문장 · 로드 때 정해지는 글이 일부 한국어로 남음
  - 넘침 상위(`hud.band.gear*`는 ko도 넘침 · `inv.act.reroll`)
  - 한국어 비교 자체 점검 2곳
- 출처: `docs/i18n/hardcoded-strings.md` 남은 것 · `docs/i18n/overflow-risk-v2.md` §4 · `QUEUE-ALL4-report.md` §10 · `QUEUE-ALL6-report.md` §11
- 현재 상태: **일부**(ALL4 E 876개 · ALL6 A4 데이터 이름 · ALL6R 서버 문장 키화 진행)
- 출시 필요도: 권장 — 영어권 유입 전에 필요합니다.
- 의존: 없음
- 예상 시간: 6시간
- 구현 방식:
  - ① 남은 표 순서대로 키화
  - ② Creator Hub 자동 번역에 맡기고 넘침만 수정
  - 추천: 넘침과 첫 화면은 ①, 나머지는 ②
- 사용자 조언:

### R15 큰 창 크기 · 버튼 대비 · 842 상점 겹침
- 설명: 다음 세 가지입니다.
  - 순위 창이 720×480으로 잘림. 다른 큰 창 HUD 기준 크기도 일괄 적용이 필요함
  - 게임 전체 주 버튼(주황 위 흰 글자) 대비가 2.23:1
  - 842 폭 상점 제목줄에 위치 표시가 겹침
- 출처: `QUEUE-ALL9C-report.md` 8절 5 · 7 · `QUEUE-ALL9C-F-report.md` 결정 4 · 5
- 현재 상태: **없음**(결정 대기)
- 출시 필요도: 권장
- 의존: 사용자 확인(색)
- 예상 시간: 2.5시간
- 구현 방식:
  - ① 순위만 창별 `maxSize` → 나머지 일괄 · `Button.lua` 한 곳에서 대비 4.5:1 · 창이 열리면 위치 표시 숨김
  - 추천: ①
- 사용자 조언:

### R16 치장 출시 공개 미달 11종 결정
- 설명: 치장 감사에서 공개 기준에 못 미친 것이 11종입니다(소리 0 · 메시 미달 3종: dragonWing · slimeParachute · crystalBlade).
- 출처: `QUEUE-ALL9C-report.md` 8절 3 · `docs/art/cosmetics-audit/README.md`
- 현재 상태: **없음**(결정 대기 · `MonetizationData.release` = 1단계 공개 상태)
- 출시 필요도: 권장 — 품질이 낮은 유료 상품은 환불 · 평판 위험이 있습니다.
- 의존: F1
- 예상 시간: 1시간(공개 단계 숫자 조정)
- 구현 방식:
  - ① 메시 미달 3종만 `release = 2`로 미루기
  - ② 전부 공개 유지
  - 추천: ①
- 사용자 조언:

### R17 옛 검증 블록 기대값 갱신
- 설명: 방지권 폐지 · 판 털기 로켓 · 29-x 등으로 기대값이 낡은 Studio 검증 블록이 회귀에서 빠지거나 실패합니다.
- 출처: `QUEUE-ALL9B-report.md` 9절 6 · `QUEUE-ALL6-report.md` 10절 2 · `BR1-4a-report.md`(결정 ④) · `QUEUE-10h-report.md` §5
- 현재 상태: **일부**(S03 · S05 · P25c(나) 회귀 제외 · BR1-4b(나) · M1-2c(나) 옛 기대값)
- 출시 필요도: 권장 — 회귀 그물에 구멍이 있습니다.
- 의존: 없음
- 예상 시간: 2시간
- 구현 방식:
  - ① 새 규칙으로 기대값 갱신
  - ② 로컬 하네스가 덮으면 블록 폐기(스위치로 제외 유지)
  - 추천: ②(삭제 금지 → 제외 목록)
- 사용자 조언:

### R18 첫 보스까지 12분 → 목표 10분
- 설명: 맵 이동을 넣은 실제 첫 보스 시간이 약 12분(계산 10.8분)입니다. 목표는 10분입니다.
- 출처: `docs/design/v2/00-README.md` 초반 곡선 · `QUEUE-ALL1-report.md` R1 · `QUEUE-ALL2-report.md` P0
- 현재 상태: **일부**
- 출시 필요도: 권장 — 초반 이탈 지점입니다.
- 의존: 신규 계정 실측 Play 1회
- 예상 시간: 1.5시간
- 구현 방식:
  - ① 견습 처치 수 · 경험치 소폭 압축
  - ② 졸업 도착점을 관문에 더 가깝게
  - 추천: 실측 뒤 ②
- 사용자 조언:

### R19 심해 삼지창 던지기 전조 팔 튐
- 설명: charge 동작에서 오른 위팔 속도가 1.85배로 급변합니다(겉모습만).
- 출처: `QUEUE-ALL4-report.md` §10
- 현재 상태: **없음**(미처리)
- 출시 필요도: 권장(작음)
- 의존: 없음
- 예상 시간: 0.5시간
- 구현 방식: ① `BossMotionData` 키프레임 보간 수정. 추천: ①
- 사용자 조언:

---

## 출시 후

### L1 세대 관문 보스 변이 · 세대 칭호 · 세대 세트 고유 옵션
- 설명: 스테이지 17,000 이후 세대마다 관문 보스 변이 · 칭호 · 고유 옵션을 주는 계획입니다.
- 출처: `docs/design/growth-curve-v2.md` §7 · `docs/plan/open-plan.md` 제안 9
- 현재 상태: **자리만**
  - `shared/data/StageGenerationData.lua:10-14`에서 5세대 모두 `gateBossId` · `mutationId` · `titleId = nil`
  - `setOptionId` 참조 0
  - 틴트 · 이름 · 세트 배율은 완료입니다.
- 출시 필요도: 출시 후 — 17,000 도달은 상위 유저 수백 시간 뒤의 일입니다.
- 의존: F9(고스테이지 몹 곡선) · NB 보스 규칙
- 예상 시간: 10시간
- 구현 방식:
  - ① 변이 = 기존 보스 + 패턴 배율 변형(주간 도전 변형 틀 재사용)
  - ② 새 보스(L5)와 통합
  - 추천: ①
- 사용자 조언:

### L2 펫 레벨 해금 400 · 500
- 설명: 둥지 약한 힌트(Lv 400)와 보관함 · 합성 추천(Lv 500)입니다.
- 출처: `QUEUE-10h-extra-prompt.md` Q11 · `docs/design/pets-q11.md`
- 현재 상태: **자리만** — `shared/data/PetData.lua:21-22`에 키만 있고 참조 0
- 출시 필요도: 출시 후
- 의존: 펫 설계 확장
- 예상 시간: 4시간
- 구현 방식:
  - ① 힌트 = 기존 둥지 단서(반딧불) 반경을 넓히기
  - ② 보관함은 펫 확장 때
  - 추천: ①부터
- 사용자 조언:

### L3 펫 탑승 · 활강
- 설명: 펫에 타고 이동하는 기능입니다(설계 "나중에 탑승").
- 출처: `docs/phase/roadmap-v2.md` 펫 · `PetData.lua:1`
- 현재 상태: **없음**
- 출시 필요도: 출시 후
- 의존: 이동 보안(HeightGuard 허가) · 아트
- 예상 시간: 8시간
- 구현 방식:
  - ① 탑승 = 이동 속도 치장(능력치 없음)
  - ② 활강 대체
  - 추천: ①
- 사용자 조언:

### L4 성기사 직업 + 탱커 훅
- 설명: 다섯 번째 직업입니다(방패 가림 · 패링 · 도발). 보스 쪽 훅은 자리만 있습니다.
- 출처: `roadmap-v2.md` 출시 후 1 · `shared/data/BossData.lua:198` · `server/BossMechanics.lua:120`
- 현재 상태: **자리만**
  - 선택 창 실루엣: `ClassData.lua:30`
  - 무기 아이콘 업로드됨(`ArtAssetIds.lua:551`)
  - 모션 자리: `PlayerMotionData.lua:258`
- 출시 필요도: 출시 후
- 의존: 영혼 · 도발 규칙 · DPS 비 1.32
- 예상 시간: 15시간
- 구현 방식:
  - ① effects 조각 조합으로 Q · E · R · T
  - ② 탱커 훅 먼저
  - 추천: ② → ①
- 사용자 조언:

### L5 NB 신규 보스(스테이지 200 이후 구간)
- 설명: 같은 6종 반복을 깨는 새 보스 6종입니다.
- 출처: `roadmap-v2.md` 출시 후 2
- 현재 상태: **없음**
- 출시 필요도: 출시 후
- 의존: BR 규칙 · L1
- 예상 시간: 15시간 이상(1종당 약 2.5시간)
- 구현 방식:
  - ① 1종씩 업데이트로 출시
  - ② 6종 묶음
  - 추천: ①(업데이트 게시판 소재)
- 사용자 조언:

### L6 서버 간 파티 매칭 · 파티 음성
- 설명: 같은 서버 게시판을 넘는 매칭과 파티 음성 채널입니다.
- 출처: `docs/design/v2/05-social.md` §1 · `roadmap-v2.md` 출시 후 3 · `v2/00-README.md` 결정 4
- 현재 상태: **없음**(같은 서버 파티 게시판 · 크로스서버 합류는 완료)
- 출시 필요도: 출시 후(동접을 보고 결정)
- 의존: 동접 데이터
- 예상 시간: 미정(약 6시간 이상)
- 구현 방식:
  - ① MemoryStore 대기열
  - ② 로블록스 기본 매치메이킹 가중치
  - 추천: ② 먼저
- 사용자 조언:

### L7 성장 일지
- 설명: 내 성장 기록(첫 보스 · 첫 태초 · 환생 날짜 등)을 모아 보는 창입니다.
- 출처: `QUEUE-N1004-prompt.md` 80줄(U1 목록)
- 현재 상태: **없음** — 설계 문서도 없습니다.
- 출시 필요도: 출시 후
- 의존: 설계
- 예상 시간: 4시간
- 구현 방식:
  - ① 도감 탭 하나 추가(기존 기록 필드 재사용)
  - ② 프로필에 이벤트 로그 필드(SAVE 변경)
  - 추천: ①
- 사용자 조언:

### L8 게임 안 용어집
- 설명: 환생 · 태초 · 초월 · 토벌 · 영혼 같은 용어를 게임 안에서 찾아보는 화면입니다.
- 출처: `QUEUE-10h-extra-prompt.md` Q15 · `docs/i18n/glossary.md`
- 현재 상태: **일부** — 번역 고정어로만 쓰입니다(`TextData_names`). 게임 안 창은 없습니다(도움말 백과 `shared/data/HelpCodexData.lua` 분류 6개에 없음).
- 출시 필요도: 출시 후
- 의존: 없음
- 예상 시간: 1.5시간
- 구현 방식: ① 도움말 백과에 "용어" 분류 추가. 추천: ①
- 사용자 조언:

### L9 스킬 가속 · 궁극기 충전 옵션
- 설명: 계산식은 있지만 옵션 풀에 없어서 값이 늘 0입니다.
- 출처: `QUEUE-10h-extra-prompt.md` Q10 · `QUEUE-10h-report.md` §10-9
- 현재 상태: **스위치 꺼짐에 해당**
  - `server/SkillStats.lua:84-87` `skillHaste`
  - `server/UltimateService.lua:58` `ultCharge`
  - `OptionData`에 없음
- 출시 필요도: 출시 후
- 의존: 결정(영웅 이상 부가 옵션 5% 추천) · EconSim(스킬 DPS 모형 없음)
- 예상 시간: 3시간
- 구현 방식:
  - ① 부가 옵션으로 추가
  - ② 폐기
  - 추천: ①(출시 후 밸런스 패치)
- 사용자 조언:

### L10 통계 구매 분류
- 설명: Telemetry의 `purchase` 분류가 꺼져 있고, 함수도 없습니다. 지금은 구매를 custom 이벤트로 보냅니다.
- 출처: `launch-checklist.md` 3절 8 · `TelemetryData.lua:4`
- 현재 상태: **스위치 꺼짐** — `shared/data/TelemetryData.lua:14`
- 출시 필요도: 출시 후(custom 이벤트로 이미 측정됨)
- 의존: F1
- 예상 시간: 1시간
- 구현 방식:
  - ① AnalyticsService 상품 이벤트 연결
  - ② custom 유지
  - 추천: ②
- 사용자 조언:

### L11 유저 간 로벅스 선물
- 설명: 친구에게 로벅스 상품을 선물하는 기능입니다.
- 출처: `docs/design/monetization-p4c.md` · `launch-checklist.md` 3절 16
- 현재 상태: **스위치 꺼짐** — `MonetizationData.lua:117` `userToUser.enabled = false`
- 출시 필요도: 출시 후
- 의존: F1 · 선물함
- 예상 시간: 4시간
- 구현 방식: ① 대상 UserId를 서버에 맡긴 뒤 프롬프트(주석 설계). 추천: ①
- 사용자 조언:

### L12 그룹 가입 보상
- 설명: 그룹(커뮤니티)에 가입하면 주는 보상입니다.
- 출처: `docs/design/v2/05-social.md` §2
- 현재 상태: **스위치 꺼짐** — `SocialRewardData.lua:26` `groupRewardEnabled = false`(그룹 없음)
- 출시 필요도: 출시 후(그룹을 만든 뒤)
- 의존: 그룹 이름 결정(소유권 이전은 금지)
- 예상 시간: 1시간
- 구현 방식: ① 기존 코드 보상 틀 재사용. 추천: ①
- 사용자 조언:

### L13 새벽 깃 날개 · 별의 수호룡 치장
- 설명: 계획된 치장 2종입니다.
- 출처: `QUEUE-ALL9C-report.md` 6절 · `docs/phase/all9c/block1.md:57`
- 현재 상태: **없음** — 코드 정의 0건. `MonetizationData.lua:62` 주석에 "상품 자리 없음 - ALL9E 이후"만 있습니다.
- 출시 필요도: 출시 후
- 의존: R12(ALL9E) · 메시 제작
- 예상 시간: 4시간(2종)
- 구현 방식:
  - ① `CosmeticSlotData` gliderSkin + 상품 2단계 공개
  - ② 시즌 패스 대표 보상으로
  - 추천: ②(L15와 묶기)
- 사용자 조언:

### L14 배경 음악
- 설명: 음악 그룹 자리만 있고 음원이 없습니다.
- 출처: `QUEUE-ALL2-report.md` §6 · §8-6 · `launch-checklist.md` 2-7
- 현재 상태: **자리만** — `shared/data/SoundSheetData.lua:54` Music 그룹
- 출시 필요도: 출시 후(사용자 결정)
- 의존: 음원 선택 · 오디오 심사
- 예상 시간: 2시간
- 구현 방식:
  - ① 로블록스 라이선스 음원
  - ② 직접 제작
  - 추천: ①
- 사용자 조언:

### L15 2시즌 대표 보상
- 설명: 시즌 패스 2시즌의 대표 치장이 비어 있습니다. 검사기가 경고를 냅니다.
- 출처: `QUEUE-ALL9B-report.md` 9절 7 · `shared/data/SeasonPassData.lua:70`
- 현재 상태: **없음**(1시즌만 채움)
- 출시 필요도: 출시 후(8주 안에)
- 의존: L13
- 예상 시간: 1시간(데이터)
- 구현 방식: ① L13 치장을 `seasonLimited[2]`에. 추천: ①
- 사용자 조언:

### L16 메인 메뉴 측정 집계(ALL9F)
- 설명: `MenuTiming`(메뉴 표시 · 입장 시간 · 상한 도달 · 건너뛰기)을 집계하는 일입니다.
- 출처: `QUEUE-ALL9C-report.md` 6절
- 현재 상태: **일부**(이벤트 이름만 정해짐 · 집계 없음)
- 출시 필요도: 출시 후
- 의존: Telemetry
- 예상 시간: 1시간
- 구현 방식: ① Telemetry custom으로 보내고 대시보드에서 봄. 추천: ①
- 사용자 조언:

### L17 전조 난이도 계층
- 설명: 고스테이지(세대)에서 몹 전조를 짧게 해 "읽고 피하는 실력"이 오르게 하는 제안입니다.
- 출처: `docs/plan/open-plan.md` 제안 6
- 현재 상태: **없음**
- 출시 필요도: 출시 후
- 의존: L1
- 예상 시간: 3시간
- 구현 방식: ① 세대 표에 `windupScale` 칸. 추천: ①
- 사용자 조언:

### L18 스킬 변형 T 포함 · 옛 효과 없는 칸 교환
- 설명: 스킬 변형이 Q · E · R에만 붙습니다. 옛 드랍 중 효과 없는 칸은 처리하지 않았습니다.
- 출처: `QUEUE-10h-report.md` §10-5 · `QUEUE-10h-extra-prompt.md` Q9
- 현재 상태: **결정 대기**(`shared/data/SkillVariantData.lua` T 제외)
- 출시 필요도: 출시 후
- 의존: 결정
- 예상 시간: 1시간
- 구현 방식:
  - ① T 제외 유지 + 옛 칸은 리롤 무료권으로 교환
  - 추천: ①
- 사용자 조언:

---

## 폐기 후보

### X1 체력바 비선형 표시
- 설명: 체력이 많을 때와 적을 때 줄어드는 속도를 다르게 보이게 하는 표시입니다(U1 계획).
- 출처: `QUEUE-10h-prompt.md` Q7-5
- 현재 상태: **없음** — `client/PlayerHealthBar.client.lua` · `hud/BossBar.client.lua`는 둘 다 선형입니다.
- 출시 필요도: 폐기 후보 — 잔상 · 30% 심장 박동(ALL2 P4)이 같은 역할을 합니다. 비선형은 실제 남은 양을 오해하게 할 위험이 있습니다.
- 의존: 없음
- 예상 시간: 0시간(폐기 시)
- 구현 방식:
  - ① 폐기
  - ② 보스 바만 구간 눈금
  - 추천: ①
- 사용자 조언:

### X2 피해 숫자 새 표시
- 설명: 새 피해 숫자 표시(DamageFeed)를 켜려던 계획입니다.
- 출처: `launch-checklist.md` 3절 15 · `STATE.md` W2
- 현재 상태: **스위치 꺼짐**
  - `shared/data/DamageNumberData.lua:7` `enabled = false`
  - 보스 피드만 켜져 있습니다(`:9`).
  - 옛 `client/DamageNumbers.lua`가 지금 쓰이고 있습니다(ALL2에서 치명 금 외곽선 등을 반영).
- 출시 필요도: 폐기 후보 — 옛 표시가 이미 다듬어졌습니다.
- 의존: 없음
- 예상 시간: 0시간
- 구현 방식:
  - ① 스위치 끈 채 유지(삭제 금지)
  - 추천: ①
- 사용자 조언:

### X3 세트 도감 탭(옛 A2-N4)
- 설명: 장비창 안에 있던 옛 세트 도감 탭입니다.
- 출처: `launch-checklist.md` 3절 14 · `v2/00-README.md` 결정 6
- 현재 상태: **스위치 꺼짐** — `shared/data/SetData.lua:21` `codex.enabled = false`. 도감 v2가 대체했습니다.
- 출시 필요도: 폐기 후보
- 의존: 없음
- 예상 시간: 0시간
- 구현 방식: ① 끈 채 유지. 추천: ①
- 사용자 조언:

### X4 플레이어 아바타 직업 변신
- 설명: 플레이어 아바타가 직접 직업으로 변신하는 연출입니다.
- 출처: `QUEUE-ALL9C-report.md` 4절
- 현재 상태: **스위치 꺼짐** — `shared/data/ClassTransformData.lua:7`. 아바타마다 깨져서 전용 캐릭터(`client/StageMascot`)로 대체했습니다.
- 출시 필요도: 폐기 후보
- 의존: 없음
- 예상 시간: 0시간
- 구현 방식: ① 끈 채 유지. 추천: ①
- 사용자 조언:

### X5 메인 메뉴 배경 교차 전환 · 등급 빛줄기
- 설명: 메인 메뉴의 장소 사진 교차 전환과 등급 빛줄기입니다.
- 출처: `QUEUE-ALL9C-report.md` 5절(사용자 10-03 결정으로 끔)
- 현재 상태: **스위치 꺼짐** — `shared/data/MainMenuData.lua` `backgroundCrossfade = false` · `lights.enabled = false`
- 출시 필요도: 폐기 후보
- 의존: 없음
- 예상 시간: 0시간
- 구현 방식: ① 끈 채 유지. 추천: ①
- 사용자 조언:

### X6 표준 체형
- 설명: 모든 아바타를 표준 체형으로 맞추는 기능입니다.
- 출처: `launch-checklist.md` 3절 2 · `v2/00-README.md` 결정 3(끔 유지)
- 현재 상태: **스위치 꺼짐** — `shared/data/ArtStyleV1Data.lua:44`. 방어구 v3 부위 맞춤으로 해결했습니다.
- 출시 필요도: 폐기 후보
- 의존: 없음
- 예상 시간: 0시간
- 구현 방식: ① 끈 채 유지. 추천: ①
- 사용자 조언:

### X7 골드 직접 옵션 리롤
- 설명: "옵션 리롤(골드)" 계획입니다.
- 출처: `QUEUE-10h-prompt.md` Q6-6
- 현재 상태: **다른 방식으로 완료** — 변환권을 골드 + 보석 가루로 사서 1장으로 리롤합니다.
  - 가격: `server/GemServer.server.lua:74-77` · `PlayerProfile.lua:1376`
  - 리롤: `:1400` · `:1431` · `:1460`
  - 고대 · 태초만 대상입니다.
- 출시 필요도: 폐기 후보(직접 골드 리롤을 따로 만들 필요 없음)
- 의존: 없음
- 예상 시간: 0시간
- 구현 방식: ① 지금 방식 유지. 추천: ①
- 사용자 조언:

---

## 완료로 확인된 것(근거)

| 항목 | 근거(코드) |
|---|---|
| 강공격 빈도(전조 간격 6.0초 · 초반 완화 ≤ 50 · 강공격 ×0.8) | `shared/data/BossData.lua:240,244,246` · `shared/BossScheduler.lua:106-126,200` · `shared/BossRules.lua:244-264` |
| 전갈 야바위 강화(불 꺼짐 3 → 2초 · 겹침 0.8 · 도달 보장 · 둔덕 · 꼬리 뜸) | `BossData.lua:1171,1194-1199` · `server/BossSandSearch.lua:89-141,238-257` · `shared/SandShell.lua` |
| 심해 삼지창 던지기 · 판 털기 낙사 제거 | `BossData.lua:839-849,940-949` · `server/BossHandlersBR1.lua:962-1031` · `client/BossBR13View.lua` |
| 폭풍 표적 노란 "!" | `client/BossRodsView.lua:125-161` |
| 평타 바닥 전조 없음 · 0.25초 예비 동작(아트 끔도) · 휘두르는 동안 궤적 | `MonsterAI.server.lua:423-491` · `client/BossAnimator.client.lua:447-462` · `client/BossInnerCircleView.lua:69-104` (내려찍기 변형만 R1) |
| 판정 > 모션 쪽 · 심해 꼬리 대상 쪽 · 모션 > 판정 1차 축소 | `BossMotionData.lua:106,150,176,762-768,809` (남은 것 R2) |
| 이동 게이지 새 디자인(대시 링 · 점 · 점프 점 · 활강 링) | `client/SkillSlots.client.lua:385,453-502` · `client/AirChargeDots.client.lua` · `client/GlideController.lua:137-164` (아트 켬일 때만) |
| 허브 나무 3종 + 상징 나무 · 들판 카툰 나무 | `shared/data/TreeArtData.lua:22-33` · `server/TreeSkin.lua:79-130` · `server/PropLibrary.lua:195-210` |
| 보스 체력바 하단 가운데 · 내 체력 초록 · 기믹 한 줄 | `client/hud/BossHudLayout.lua` · `client/PlayerHealthBar.client.lua:60,343` |
| 원 안 강공격 원 크기 · 평타 타이밍 | `BossData.lua:402,1469` · `shared/BossSkillMath.lua:740` |
| BR1-4a 전멸기 · 기믹 고정 % | `server/PlayerDamage.lua:209` · `server/BR14aVerify.lua` |
| BR1-4b 보스 관절 리그 · 모션 | `shared/BossRig` · `shared/data/BossMotionData.lua` · `client/BossAnimator.client.lua` |
| M2 성향 카드 | `shared/data/MonsterSpeciesData.lua` · `server/MonsterTemperament.lua` |
| M2 티어 드랍(정수 가중치 3구간 · killUnits · 태초 2/3/3) | `shared/data/DropTableData.lua:43-49,122` |
| 보스 첫 만남 전멸기 카드 · 도감 첫 만남 칸 | `client/BossIntroCard.client.lua` · `server/BossEncounter.lua:306` · `server/CodexService.lua:327` |
| BR2 세트 효과(켬) · setZone · 장비창 표시 | `shared/data/SetData.lua:7` · `server/CombatResolution.lua:242` · `GearTab.lua:172` |
| 토벌 드랍 표 · 시간 공정성 | `DropTableData.lua:90` · `shared/DropTable.lua:89` |
| 보스 선택 창 보상 = DropTable 단일 소스 | `client/StageRewardBand.lua:57-69` · `CombatResolution.lua:203-207` |
| 칭호 UI(이름표 · 도감 칭호 탭) | `client/Nameplate.client.lua:31-48` · `client/panels/CodexV2/Grid.lua:385` |
| 도움말 백과(게임 안) | `client/panels/Help.lua` · `shared/data/HelpCodexData.lua` |
| 전투력 숫자 + 오를 때 연출 | `client/CombatPowerHud.client.lua` · `server/CombatPowerSync.server.lua` |
| 기믹 3컷 카드 | `client/BossIntroDiagram.lua` |
| 파티원 곁으로 이동 · 미니맵 파티원 점 | `server/Travel.lua:545-552` · `client/WorldClient.client.lua:380` |
| 미출시 직업 실루엣(성기사 · 곧 공개) | `client/ClassSelectUI.client.lua:292-330` · `shared/data/ClassData.lua:30` |
| 장비창 각인 · 각성 · 세트 · 보석 홈 5 | `panels/Inventory/DetailCard.lua:193` · `DetailSheet.lua:39` · `GearTab.lua:172` · `GemSlots.lua` |
| K 궁극기 T 4직업 | `shared/data/UltimateData.lua` · `server/UltimateService.lua` · `client/hud/UltGauge.client.lua` |
| K R 스킬 4직업(판정) | `shared/data/SkillData.lua:289-308` · `server/SkillServer.server.lua:597` |
| K3 영혼 상태 | `shared/data/SoulData.lua:7` · `server/SoulService.lua` · `client/SoulView.client.lua` |
| K4 스킬 변형 | `shared/data/SkillVariantData.lua` · `shared/SkillVariant.lua` |
| K5 재조정(DPS 비 1.310 · 관통돌진 24) | `server/BalanceDecisionVerify.lua:134-137` · `SkillData.lua:38` |
| P4a FTUE 이정표 · 메인 퀘스트 32단계 · 7일 출석 | `shared/data/QuestData.lua:29-48` · `server/QuestService.lua` · `client/panels/Attendance.lua` (무료권 소비만 F6) |
| P4b 확률 공개 한 소스 | `shared/Disclosure.lua` · `server/DropTableServer.server.lua:19` · `client/panels/Probability.lua` |
| P4c 통계 수집 | `shared/data/TelemetryData.lua:6` · `server/Telemetry` (구매 분류만 L10) |
| P4d 주간 의뢰(퀘스트 주간 5종) · 설정 저장 | `QuestData.lua:16-22` · `server/SettingsService.lua` |
| 펫 자동 줍기(Lv 30 · peakLevel) · 부화 대기열 +1 | `server/PetService.lua:50,132-138` · `shared/Pet.lua:75-76` |
| 세대 틴트 · 이름 · 세트 이름 · 세대 세트 배율 | `shared/StageGeneration.lua` · `client/GenerationView.client.lua` · `shared/SetBonus.lua:50-63` |
| 복귀 부스트(7일 → 60분 ×1.5) | `PlayerProfile.lua:541-561` · `SaveServer.server.lua:68-76` · `CombatResolution.lua:226` |
| 자동 스테이지 이동(기본 "보통") | `server/AutoStage.server.lua` · `StageServer.server.lua:215-224` · `shared/data/AutoStageData.lua` |
| 되찾기(환생 뒤 경험치 배수) | `PlayerProfile.lua:747-749,1065` · `shared/CharacterLevel.lua:264` |
| 이동 효과: 공중 점프 어느 단계든 jumpFx | `client/ArtV1Cosmetics.client.lua:302-306` · `ArtV1CosmeticData.lua:61` |
| 이동 효과 부위별 조합(4칸 따로 장착) | `shared/data/CosmeticSlotData.lua:36` · `server/CosmeticService.lua:160-198` |
| 귀환 B 키 · 취소 · 발밑 진행 | `client/WorldClient.client.lua:355-385` · `server/Travel.lua:209-216,443-450` · `client/TravelChannelView.client.lua` (대시만 취소는 R9) |

### 문서와 코드가 어긋난 곳(참고)
- `docs/STATE.md:63`: "C5-4·5·6 자리만 · 미배선"은 낡은 기록입니다(커밋 `92a761d`에서 배선).
- `shared/data/PetData.lua:5` 주석 "자동 줍기 200"은 낡았습니다. 실제 값은 30입니다(`:21`).
- `client/WorldClient.client.lua:366` 주석 "대시 = 취소"는 코드와 다릅니다(R9).
