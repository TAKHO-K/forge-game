# 30_hub-art _ref — 마을(큰 나무 마을) 현재 모습 자료집

- 만든 날: 2026-10-05 · QUEUE-UI2 끼워 넣기 ART-REF(읽기 전용 - 코드 · 데이터 · 에셋 변경 0)
- 목적: 마을 아트 재작업(결정 문서 world-art-track - 저장소에는 없음) 전에 "지금 모습"을 한곳에 모은다.
- 촬영: Studio Play(아트 스위치 ArtStyleV1 = 켬 · 출시 기본값) · 클라 카메라 고정(Scriptable) · 화면 UI 숨김 · 월드 이름표(빌보드)는 그대로 · 뷰포트 1841×1036(16:9) · 낮 조명.
- 그림 = 이 폴더(PNG 26장) · 저장소 = 이 ref.md만(`docs/design/handoff/30_hub-art/_ref/ref.md`).
- 좌표 = 월드 stud(허브 원점 = 큰 나무 줄기) · 크기 = 모델 경계 상자(폭 × 높이 × 깊이) · 데이터 출처 = `roblox/src/shared/data/`.

## 1. 마을 전체(4방향 + 위 + 마을 높이)
| 파일 | 카메라 | 보이는 것 |
|---|---|---|
| hub_overview_1_north.png | 북(−Z) 760 · 높이 260 | 정면 전경 - 원형 잔디 경계(반경 400 · 등불 32) · 마을 시설이 전부 이쪽 반원에 몰림 · 거대 나무 수관 |
| hub_overview_2_east.png | 동(+X) 720 · 높이 260 | 대장간 거리 · 광장 2개가 수관 아래 가장자리에 작게 보임 |
| hub_overview_3_south.png | 남(+Z) 640 · 높이 260 | 마을 뒤쪽 - 수관 + 빈 잔디(시설 없음) |
| hub_overview_4_west.png | 서(−X) 660 · 높이 260 | 시장 쪽이 줄기 뒤로 가려짐 · 뿌리 |
| hub_overview_5_top.png | 바로 위 1500 | 수관이 마을을 덮음(위에서는 마을이 안 보임) · 둘레 6구역 지형 색(풀 · 모래 · 사막 · 눈 · 어둠) |
| hub_overview_6_village-level.png | 수관 아래 높이 75 | 플레이어가 실제로 보는 마을 - 포탈 광장 · 커뮤니티 광장 · 시장 일부 |

## 2. 거리 · 광장 전경(참고)
| 파일 | 대상 | 데이터 | 메모 |
|---|---|---|---|
| street_1_forge.png | 대장간 거리(각 −20° r 170) | WorldMapData.hub.facilities.forge | 강화대(모루 + 화로 굴뚝) · 대장장이 · 재련대 · 집 3채 |
| street_2_market.png | 시장(−115° r 175) | facilities.market | 노점 2 · 상점(파란 지붕) · 재봉집(보라) · 보석상인(옛 상자 모양) |
| street_3_community-plaza.png | 커뮤니티 광장(−60° r 250 · 원판 50) | facilities.community | 명예의 전당 · 환생 제단 · 순위판(분홍 빌보드) · 게시판 · 도전 기사 · **회색 상자 4개 = 부화장 · 파티 게시판 · 순위판 자리 표시(아트 없음)** |
| street_4_portal-plaza.png | 포탈 광장(−90° r 250 · 반경 46) | facilities.portal · portalRingRadius 38 | 구역 포탈 6 = 바닥 파란 원판뿐(문 · 기둥 없음) |

## 3. 건물 · 소품 8
| # | 파일 | 대상 | 모델(HubArtData · HubArtMeta) | 위치 | 크기(stud) | 관찰 |
|---|---|---|---|---|---|---|
| 1 | bld_01_forge.png | 대장간 | HubBuilding_hub_forge | (190, −69) | 31 × 28 × 25 | 빨간 지붕 · 반목조 벽 · 망치 간판 · 굴뚝 연기 |
| 2 | bld_02_shop.png | 상점 | hub_shop | (−87, −186) | 29 × 27 × 23 | 파란 지붕 + 줄무늬 차양 · 금화 간판 · **지붕 위 나무 막대 2개가 떠 있음** |
| 3 | bld_03_tailor.png | 재봉집 | hub_tailor | (−57, −200) | 23 × 21 × 21 | 보라 지붕 · 실패 간판 |
| 4 | bld_04_hall-of-fame.png | 명예의 전당 | hub_hall | (158, −275) | 34 × 27 × 26 | 흰 신전(기둥 6) · 금 별 박공 |
| 5 | bld_05_house-a.png | 집 A(×3) | hub_house_a | 거리마다 1채 | 23 × 20 × 20 | 초록 지붕 · 간판 없음 |
| 6 | bld_06_house-b.png | 집 B(×2) | hub_house_b | 대장간 · 광장 | 25 × 21 × 20 | 빨간 지붕 · **벽돌 굴뚝이 지붕과 떨어져 있음** · 옆 갈색 판자 더미 = 허브 유적 구조물(Struct_hub_ruins 4개 중 하나로 추정 - 확인 안 함) |
| 7 | bld_07_notice-board.png | 마을 게시판 | HubProp_board(props/hub_board) | (82, −214) | 9 × 8 × 3 | 지붕 달린 나무 판 + 업데이트 소식 글(SurfaceGui) · 게시판지기 곁 |
| 8 | bld_08_workbenches.png | 대장간 작업대 | prop_gem_bench · prop_refine_furnace · EnhanceStation | (144, −95) · (150, −80) · (160, −58) | 4 × 4 · 3 × 5 · 4 × 4 | 보석 가공대(탁자 + 보석) · 재련대(화로 + 도가니) · 강화대(나무 그루터기 모루 + 굴뚝 + 망치 표지) |

추가(8에 안 셈): prop_1_rebirth-altar.png = 환생 제단(RebirthAltar · (125, −217) · 6 × 5 × 6) - 남색 원판 3단 + 떠 있는 노란 결정(옛 상자 계열 모양).

## 4. NPC 7
| # | 파일 | 대상 | 모델 | 자리(spot) | 높이 | 대기 동작(HubArtData.motion) | 관찰 |
|---|---|---|---|---|---|---|---|
| 1 | npc_1_smith.png | 대장장이 | props/npc_smith | smith (155, −65) | 6 | 망치질(오른팔 X ±35°) | 앞치마 · 짧은 머리 · 손에 망치 |
| 2 | npc_2_merchant.png | 상인 | props/npc_merchant | shop (−39, −175) | 7 | 손님 부르기(오른팔 Z) · 고개 좌우 | 밀짚모자 · 파란 옷 |
| 3 | npc_3_tailor.png | 재봉사 | props/npc_tailor | tailor (−55, −181) | 6 | 가위질 | 보라 옷 + 금 띠 · 가위 |
| 4 | npc_4_challenge-knight.png | 도전 기사 | props/npc_knight | challengeKnight (142, −246) | 7 | 둘러보기 · 왼팔 | 회색 갑옷 · 빨간 깃 · 방패 · 검 |
| 5 | npc_5_board-keeper.png | 게시판지기 | props/npc_keeper | noticeBoard 옆(5.5, −1.5) | 6 | 두루마리 보이기 | 초록 옷 · 베레모 · 두루마리 |
| 6 | npc_6_gem-merchant.png | 보석상인 | **workspace.GemMerchant(옛 모양 - 파트 4개: Stall · Body · Head · Gem)** | 시장 가운데 (−74, −158) | 6 | 없음 | ArtStyleV1 메시 NPC가 아님 - 검은 상자 노점 + 남색 몸통 + 공 머리 + 네온 보석. 다른 NPC와 화풍이 다름 |
| 7 | npc_7_player-scale-ref.png | (크기 기준) 플레이어 캐릭터 | 로블록스 기본 아바타 + 방어구 v3 | - | 5.5 | - | NPC(6 ~ 7)와 플레이어(5.5)의 크기 비교용 |

## 5. 지금 눈에 띄는 것(판단 아님 - 사실만)
- 화풍이 두 갈래: 건물 · NPC 5 = 메시 카툰풍(ArtStyleV1) · 보석상인 · 환생 제단 · 포탈 · 광장 자리 표시 = 기본 도형(옛 모양).
- 수관이 마을 전체를 덮어 위 · 먼 거리에서 마을이 거의 안 보인다(1 · 5번).
- 시설이 북쪽 반원(−20° ~ −115°)에 몰려 있고 남쪽 반은 빈 잔디(3번).
- 포탈 6개 = 바닥 원판만(세로 구조물 없음) · 커뮤니티 광장 회색 상자 4개 = 아트 없는 자리.
- 상점 지붕 막대 · 집 B 굴뚝이 몸체와 떨어져 보임(메시 조각 위치).
- 촬영하지 않은 것: 밤 · 계절(봄 벚꽃) · 비 · 나무 점프맵 위쪽 · 먼 6구역 관문(BossGate - 31_bosses 참고).
