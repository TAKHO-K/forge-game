# QUEUE-10h 진행 상태 (커밋마다 갱신)

> 재시작 때는 이 파일 + `QUEUE-10h-prompt.md`만 읽고 이어서 진행. 공통 규칙 실제 경로 = `docs/sonnet/COMMON.md`.
> 시작: 2026-09-29 06:17(이 PC 시계)

## 완료
| 항목 | 커밋 | 메모 |
|---|---|---|
| Q0-1 지시서 저장 · Q0-2 상태 파일 · Q0-3 COMMON §7-6 | 14911d9 · d8ff32e | docs/phase 규칙 = `<이름>-prompt/state/report.md` |

| Q0-4 · 5 · 6 결정 1 · 2 · 알림 감사 | d699bb9 | 개수 = killUnits × 티어 보정 · 태초 2/3/3 · 첫 클리어 0.1% · 태초 명예의 전당 · 칭호 제거 · QueueVerify Q0(가) 18/18 로컬 |

| Q1 푸른 드래곤 | bbc2c4a | 종 · 리그 14 · 공격 3종(모양 공격 조각) · 포효 · 추적 상한 · 스폰 T6 88 · 아트 자료 · QueueVerify 29/29 로컬 |

| Q2 일반 몹 드랍표 | 2572e7b | `docs/design/field-drop-tables.md` · 판매가 0 버그 수정(옛 칸 없는 조합) · 공정성 로그 새 식 · 시간당 위력 0.985 ~ 1.000 |

| Q3 보스 드랍표 | ddac156 | `docs/design/boss-drop-tables.md` · 수정 여왕 강화석 60% → 같은 단위(rewardKillUnits) · QueueVerify 32/32 |

| Q0 · Q1 리뷰 반영 + Q4 판매가 스위치 | 1348f50 | 몸 반경 도달 공용(`Reach.withinModel` - 조준 · 스킬 원 · 선 · 채널 · 화살) · 전조 상태 정리 · 거리 맞춘 공격 · 넉백 공통 입구(`BossPatterns.launchPlayer`) · 눈금 · 분신 · 은퇴 이름 · 눈토끼 색 · 결번 · 판매가 `sellPriceMode = current` · QueueVerify 36/36 |

| Q4 장비 점검 | 698eaea | `docs/design/equipment-audit.md` · 계승 잠금 · 초월 계승 금지 · 초월 계승비 · 판매 불가 표시 · 무기 등급 · 초월 즉시 저장 · QueueVerify 40/40 |
| Play A | (Play - 코드 변경 없음) | 아래 결과 |

## Play A 결과(06:49 ~ 06:55 · 1회 · 재Play 없음)
| 항목 | 결과 | 근거 |
|---|---|---|
| QueueVerify Q0(가) | O 36/36 | `===Q 검증 끝(가)=== 36/36 통과` |
| 태초(보스 출처 · 잡몹 출처) 알림 | O 같은 서버만 | `[Q0][알림] primordial 출처=boss 범위=server 명예의 전당 대상=false 칭호 대상=false` · 태초 토픽 수신 0 · 채팅 줄 "★ 세계 112번째 태초" |
| 초월 알림 | O 전 서버 | `범위=global 명예의 전당 대상=true` · 초월 토픽(TranscendentFound_studio) 수신 1(로그 "발송=0"은 발급 직후에 센 시점 차 - DevTools 대기 추가) |
| 줄 세우기 스크린샷(허브 광장 · 가림 없음) | O | `Claude outputs/QUEUE-10h/playA-lineup.png` - 12종 + 드래곤(체력바 겹침 = 기록) |
| 드래곤 공격 3종 전조 · 예고 | O | `playA-dragon-montage.png` - 원(돌풍 · 날개 펼침) · 앞 부채꼴(숨결) · 뒤 반원(꼬리) |
| 드래곤 쓰러짐 | △ 경로 O · 연출 캡처 놓침 | `[killtest] 푸른 드래곤 처치 - 골드 +9 · 경험치 +70` |
| 드래곤 무리 1 ~ 2(자연 스폰) | 미확인(T6로 서버 이동 불가 - 클라 이동은 서버가 되돌림) | 데이터 · 하네스 O |
| R 4종 | △ 대검 O(`[K2] 전장의 포효 도발 1`) · 쌍검 · 활 · 치유사 로그 없음 | 직업 전환 = 그 직업 진행(치유사 Lv 2)이라 R 잠김 추정 - 다음 Play는 직업마다 레벨 · 환생 맞춘 뒤 |
| G-1 ~ 3 · 비상 공중 초기화 | 미확인(시간) | 다음 Play 목록 |
| 보스 선택 창 보상 띠 | △ 창 스크린샷만(`playA-stage-panel.png`) · 보스 칸 클릭 못 함 | 단일 소스 = QueueVerify Q3 O |
| 스크립트 오류 | 0 | 로그 Error = MCP 마우스 도구뿐 |

| Q5 BR2 | 2dc3f61 | 세트(`SetData` · `SetBonus` - 옵션 합산 공통 입구 · 스위치 기본 끔) · `item.setZone` SAVE v49(출처 태그로 이관) · 토벌 입장(관문 발판 · `RaidRequest` · `BossEncounter.spawnRaidFor` - 솔로) · 개발 `/gg tp` `/gg set` `/gg raid` · QueueVerify 46/46 |

## Play B 결과(07:03 ~ 07:08 · 1회)
| 항목 | 결과 | 근거 |
|---|---|---|
| QueueVerify(Q5 이관 · 세트 · 토벌 규칙 포함) | O 46/46 | `===Q 검증 끝(가)=== 46/46 통과` · `이관 v48 → v49 ... O` |
| 저장 왕복(옛 v48 → 새 v49 · 종료 저장 → 원본 읽기) | O | `_verify` 원본 version 49 · 토벌 드랍 legendary source=raid(section_guardian) setZone=tier1 |
| 세트 3부위 효과 | O | 켬 `tier1 3부위 · 최대 체력 0.050 · 최종 피해 0.050` · 끔 0.000 |
| 토벌 입장 · 거부 | O | 원격 미등록 → gate_unregistered · 발판 경로 → raid_entered(토벌 스테이지 45) · 처치 = 전설(토벌 표) · 진도 not_next · 잔류 없이 종료 |
| 보스 출처 태그 | O | 위 저장 원본 source.kind = raid |
| /gg tp tier6 · 드래곤 자연 스폰 | O | 지점 1 곁 도착 · 드래곤 무리 1마리(규칙 1 ~ 2) · 골렘 무리 3 |
| 스크립트 오류 | 0 | |

## 지금
- Q6 G3(수련 · 직업 능력 · 퀘스트 · 메인 퀘스트 · 골드 예산)

## Play A 계획(12분 이내 · 재Play 금지)
0. 체크리스트: ① Rojo 동기화(script_grep launchPlayer · [Q0][알림] O) ② 지연 0(IncomingReplicationLag 기본) ③ 순간이동 = /gg stage · TeleportArrival 경로 ④ 표본 몹 = /gg m2 windup(DevFrozen · C3Immortal) ⑤ 계정 = 개발 계정 그대로(검증 켬 = _verify 저장)
1. VerifyArmedUntil + VerifyOnly "Q0(가)" → QueueVerify 줄
2. /gg drop force primordial armor boss → [Q0][알림] 범위=server 발송=0 · /gg drop force transcendent gloves → 범위=global
3. /gg m2 lineup(허브 밖 넓은 곳 - /gg stage로 T6 사냥터) → 스크린샷 · /gg m2 windup blue_dragon → 전조 3종 캡처 · /gg m2 spawn blue_dragon 20 2 → 무리 · 쓰러짐
4. 지난 묶음: /gg gear transcendent 46 shoes → 공중 강공격(비상) · /gg class * + R · G-1 ~ 3
5. 보스 선택 창 보상 띠 스크린샷 1장

## 기대값 갱신 필요(옛 검증 블록 - §7-1: 돌리지 않음)
- D1Verify(첫 클리어 태초 0.0001 · 토벌 옛 값) · LootRuleVerify [4](개수 = dropChance × r(t)) · [9](공정성 공통값 1.23728) · G1_2Verify(옛 개수 식) · P2Verify E2 · P25cVerify 태초 비 · M1_2Verify · M1_4Verify · M1_3TVerify(지점 수 = 구역 × 80 → T6 88) · BalanceDecisionVerify · DropNoticeVerify(태초 등록 등급) · G1_1Verify

## 다음 할 일
- Q1 → Q2 → Q3 → Q4 → Play A

## Q0 측정(20,000h · 스크래치 q0_r_*.txt)
| 항목 | 목표 | 변경 전(HEAD) | 변경 후 | 판정 |
|---|---|---|---|---|
| 1인 태초 기대 시간 | 1,440 ~ 2,160h | 일반 669 · 캐주얼 1,011h | 일반 1,984 · 상위 1% 1,567 · 캐주얼 2,557h | O(일반 기준 - 옛 결정 3) |
| 태초 보스 출처 비중 | ≥ 60% | 2.0% | 일반 60.5 · 상위 52.4 · 캐주얼 66.8% | O(일반) |
| 첫 태초(P ≥ 1 50%) | - | 일반 444h | 일반 104h · 상위 52h · 캐주얼 190h | 기록(일찍 - 보스 첫 클리어 0.1%) |
| 고대 보스 출처 비중 | 측정만 | - | 일반 6.8 · 상위 3.6 · 캐주얼 10.8% | 값 그대로 · 조정안 2개(보고서) |
| 티어별 시간당 장비 위력(k1 1.35 · 무리) | 0.95 ~ 1.00 | T6 0.40 | T1 ~ T5 1.000 · T6 1.092(Q1 전 무리 3.45 - Q1 뒤 재측정) | Q1 뒤 확인 |
| 상위 1% 25,300 | 2,250 ~ 2,750h | - | 2,540h | O |
| 캐주얼 1,000 | 31 ~ 38.5h | **27.5h** | 28.5h | X(변경 전부터 - M2 등급표) |
| 일반 환생 5 · 환생 1 | ≈ 10h · 30 ~ 45분 | 8.80h · 34분 | 8.68h · 34분 | 환생 5 약간 빠름 |
| 상위 1% 5,000 | 70 ~ 110h | - | 83.9h | O |

## 추가 대기열
- **Q8~Q15 대기 중** (`QUEUE-10h-extra-prompt.md`) - 앞 대기열 "마무리"까지 끝난 뒤에 Q8부터. Play = E · F · G 3회만.

## 이름 결정(Q1)
| 대상 | 기존 규칙 | 푸른 드래곤 |
|---|---|---|
| docs/art/ref 파일 | `NN_영문소문자_T범위.png`(00 ~ 07 구역 · 10 ~ 18 주제 · 밑줄 · 티어 = 대문자 T + 숫자 · 범위 = 하이픈) | `19_monsters_T6_blue_dragon.md`(다음 번호 19 · 주제 monsters · 문서라 .md) |
| 종 ID | 영문 snake_case(`ice_golem` · `snow_rabbit`) | `blue_dragon` |
| 표시 이름 | 한글(얼음 골렘) | 푸른 드래곤 |
| 리그 파트 | 영문 파스칼 + `_L/R` · `_FL..` · 번호 마디(`Tail1`) · 관절 Body = RootJoint · Head = Neck | Body · Neck1 · Head · Jaw · Eyes · Wing_L/R · Tail1~3 · Leg_FL/FR/BL/BR |
| 매핑표 | `monster-body-draft.md` 표(종(티어) · 부위(파트 수) · 전조) | "푸른 드래곤(T6) `blue_dragon`" 줄 · 눈토끼 줄 = retired → 푸른 드래곤 |

## 결정 필요 누적
1. **캐주얼 1,000 = 28.5h(목표 31 ~ 38.5)** - 변경 전 HEAD부터 27.5h(M2 등급표가 T1 ~ T3에 영웅 · 전설을 줌). 드랍 개수 전체 배율 0.6 ~ 1.0으로는 안 움직임 → Q6 수련 가격 · 상한으로 맞춤(지시 규칙) 예정.
2. 첫 태초가 일찍 옴(일반 104h 50%) - 보스 첫 클리어 0.1%가 주 공급. 범위 안이라 보정 안 함.
3. **docs/art/ref는 .gitignore 대상** - 아트 자료 `19_monsters_T6_blue_dragon.md` · art-spec 색인 줄은 로컬에만 있다(푸시 안 됨). 추천 = `.gitignore`에 `!docs/art/ref/*.md` 예외(문서만 추적).
10. **세트 스위치(SetData.enabled 기본 끔)** - 2부위 최대 체력 +5% · 3부위 최종 피해 +5% · 세대 ×(1 + 0.1 × 세대). 성장 예산 재측정(Q6) 때 켤지 결정. 추천 = 켬(최종 피해 버킷 상한 1.05 안).
11. **파티 토벌** - 이번엔 솔로만(RaidRules.partyBossStage 자리 있음) · 관문 발판 = 비보스 스테이지에서 밟으면 토벌 입장(실수 입장 가능성 - 관문은 구역 밖 전용 구조물).
12. 토벌 빛기둥 · 길 안내 = U1(스테이지 창 [토벌] 버튼 + BossGate 길 안내 재사용)로 이월.
9. **초월 고유 효과 상속 · 옵션 상한 · 딜 부위 표시**(equipment-audit §5 1 ~ 3).
4. 태초의 선택 칭호 - 이미 가진 계정은 유지(저장 데이터 손실 금지) · 새 지급만 중단.
5. 드래곤 공격 배율(숨결 2.2 · 꼬리 1.9 · 돌풍 1.0 = 한 사람 초당 피해 ≤ 평타) · 크기(키 2.2배 · 길이 4.6배) · 판정 상자 5.7 × 8.4 × 10.7 - Play 체감 확인.
7. **판매가 티어 무관화**(옛 표 역산 → 같은 등급이 티어마다 4 ~ 10배 차 · 등급 역전 T6 전설 15 < 일반 120골드) - Q4에서 스위치로.
8. 고대 보스 출처 6.8%(목표 60%는 측정만) - 조정안 1 · 2(field-drop-tables §5).
6. 얼음 골렘 무리 1 ~ 2 → 3 ~ 4(드래곤 규칙이 드래곤으로 돌아감 - 묶음 결정 B-1 해제).
