# 31_bosses _ref — 보스 6 현재 모습 자료집

- 만든 날: 2026-10-05 · QUEUE-UI2 끼워 넣기 ART-REF(읽기 전용 - 코드 · 데이터 · 에셋 변경 0)
- 목적: 보스 아트 재작업(결정 문서 world-art-track - 저장소에는 없음) 전에 "지금 모습"을 모은다.
- 촬영: Studio Play · `/gg boss anim <보스 id> idle`(전시 리그 = 이 클라에만 · 판정 · 전조 · 아레나 없음) · 마을 잔디 위 · 아트 스위치 ArtStyleV1 켬 · 화면 UI 숨김 · 뷰포트 1841×1036.
- 보스마다 2장: `_a` = 리그 LookVector 반대쪽 3/4 · `_b` = LookVector 쪽 3/4(대기 동작 중이라 머리 · 팔 방향이 장마다 다를 수 있음).
- 그림 = 이 폴더(PNG 12장) · 저장소 = 이 ref.md만(`docs/design/handoff/31_bosses/_ref/ref.md`).
- 데이터 출처 = `roblox/src/shared/data/BossData.lua`(이름 · 구역 · sizeScale · 몸 색 = 구역 색 tierColor) · 높이 = 리그의 보이는 파트 경계(바닥 ~ 꼭대기, stud) 실측.

| # | 파일 | 보스(id) | 구역 | sizeScale | 높이(실측) | 관찰(사실만) |
|---|---|---|---|---|---|---|
| 1 | boss_1_section-guardian_a/b.png | 구간 수호자(section_guardian) | tier1 | 3 | 22.4 | 보라 · 검정 바위 갑옷 · 머리 보라 결정 다발 · 가슴 결정 · 분홍 빛 눈 · 큰 주먹 |
| 2 | boss_2_frost-giant_a/b.png | 서리 거인(frost_giant) | tier6 | 3.3 | 30.0 | 파랑 · 흰 얼음 갑옷 · 얼음 뿔 왕관 · 흰 빛 눈 띠 · 얼음 대검 · 6마리 중 가장 큼 |
| 3 | boss_3_abyssal-lord_a/b.png | 심해 군주(abyssal_lord) | tier3 | 3 | 19.7 | 남색 몸 + 청록 비늘 · 굵은 꼬리 · 청록 네온 가슴 · 머리 산호 가시 · 지팡이 |
| 4 | boss_4_crystal-queen_a/b.png | 수정 여왕(crystal_queen) | tier2 | 3 | 21.0 | 분홍 드레스 + 하늘색 치마 · 수정 날개 4 · 흰 다이아 장식 · **왕관 빛이 블룸으로 하얗게 날아가 얼굴이 안 보임** |
| 5 | boss_5_scorpion-queen_a/b.png | 전갈 여왕(scorpion_queen) | tier4 | 2.8 | 17.5 | 갈색 납작한 몸 · 꼬리 여러 갈래(끝 노란 빛) · 다리 · 금 조각이 주위에 떠 있음 · 유일하게 사람형 아님 |
| 6 | boss_6_storm-lord_a/b.png | 폭풍 군주(storm_lord) | tier5 | 3 | 21.9 | 남색 갑옷 · 노란 번개 날개(막대) · 어깨 노란 빛 · 긴 창/지팡이 |

## 지금 눈에 띄는 것(판단 아님 - 사실만)
- 5마리는 같은 계열의 사람형 블록 몸(머리 · 몸통 · 팔다리 상자) + 부위 장식으로 보임 · 전갈 여왕만 다른 몸.
- 몸 색 = 보스 구역 색(tierColor)이라 같은 계열 구역 몹 · 지형과 색이 가깝다(예: 심해 군주 남색 · 폭풍 군주 남색).
- 빛 부위(네온)가 커서 블룸에 흰색으로 뭉개지는 곳: 수정 여왕 왕관 · 폭풍 군주 어깨 · 심해 군주 어깨.
- 촬영하지 않은 것: 실제 아레나 조명 · 등장 연출 · 스킬 연출 · 쓰러짐(전시 리그는 판정 없음 - 실전 촬영은 별도) · 구역 관문(BossGate - 마을에서 약 2400 stud).
