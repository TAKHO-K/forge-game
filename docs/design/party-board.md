# 파티 모집 게시판 (A2-N4 §4-4)

## 1단계 - 같은 서버(구현)

- 서버 `server/PartyBoard.lua` · 클라 `client/panels/PartyBoard.lua`(파티창 [모집 게시판]) · 데이터 `PartyConfig.board`.
- 글 = 태그만(자유 글 없음 → 필터 · 신고 부담 0): 스테이지(올린 사람의 지금 무한 스테이지 - 서버가 채움) · 역할(누구나 · 딜러 = 치유사 빼고 · 치유사) · 목표 인원(2 · 3 · 4).
- 올리기 = 리더 또는 솔로(파티를 만든다 - `PartyState.create`) · 보스전 중 금지 · 2초 간격.
- 빠른 참가 = 초대 · 수락과 같은 금지 조건(`PartyJoinRules.checkJoinable` · 보스전 · 합류 중 · 프로필) + 역할 → 코드 합류와 같은 마지막 단계(`PartyState.attachMember`) · 잔류 중이면 잔류에서 먼저 빠진다(초대 수락과 같다).
- 글은 목표 인원 도달 · 파티 해산 · 주인이 리더 아님 · 5분(ttlSeconds) · 퇴장이면 지운다. 목록은 바뀔 때 전원에게(`PartyBoardSync`).

## 2단계 - 서버 간 매칭(설계만)

| 항목 | 설계 |
|---|---|
| 저장소 | MemoryStore SortedMap `ForgePartyBoard_v1`(검증 무장 시 `_verify` - COMMON §3) · 키 = 파티 코드(24-2 `PartyCrossServer.ensureCode`) · 값 = { stage, role, size, count, jobId, expiresAt } · 정렬 키 = 스테이지 구간(보스 간격 5 단위)로 가까운 글 먼저 |
| 올리기 | 같은 서버 글과 같은 태그 + 파티 코드 · 30초마다 하트비트(`PartyConfig.heartbeatSeconds`) · 목록 수명 = recordTtlSeconds(90) |
| 찾기 | 내 스테이지 ± 파티 입장 밴드(`BossRules.partyEntryBand`) 구간만 GetRangeAsync(최대 20) · 15초 캐시 |
| 참가 | 기존 코드 합류 파이프라인 그대로(`PartyCrossServer.requestJoin` - 좌석 예약 → 저장 → 텔레포트) |
| 한도 | MemoryStore 요청 한도(서버당 분당 1,000 + 100 × 인원)의 10% 이하 - 목록 조회는 창이 열려 있을 때만 |
| 남용 | 글 1개 / 사람 · 올리기 30초 간격 · 태그만(자유 글 없음) |
