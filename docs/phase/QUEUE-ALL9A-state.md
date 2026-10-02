# QUEUE-ALL9A 상태

> 재개: "QUEUE-ALL9A 이어서" → 이 파일의 다음 항목부터. 시작 2026-10-03 01:58(로컬) · 1시간 45분 경계 = 03:43.

| 항목 | 상태 | 커밋 | 메모 |
|---|---|---|---|
| 1 시즌 패스 수치 | 완료(Play: 주말 배너 · 접속 10 → 20 · 패스 창 주말 줄 · 보너스 줄 · 출석 한 줄) | 67606b2f | expPerTier 170 · 주말 2배(QuestService.grant 한 곳) · 보너스 칸 = claimedFree/Paid "41"+ · 출석 한 줄 · /gg weekend |
| 2 판매 창 | 완료(Play: 새 말투 · 2개 확인 → 가방 바뀜 → 안내 + 4개로 다시) | f94cd354 | 말투 · 분해하기(N개) · count_mismatch = 같은 SellRequest로 결과 → 안내 + 확인 창 다시 · check_textdata 문어체 검사(기존 1건 환생한다 → 환생하기) |
| 3 지도 이름 · 게시판 · 폰 | 완료 | 4485e8f8 | 지도 ×10 ko · en 16 → 15(재봉사 → 재봉집 하나) · 상점 50 · 명예의 전당 98 stud라 25 규칙 밖(결정 필요) · 게시판 = Panel.create(UIManager) · 폰 TC 줄 181 ~ 558(미니맵 567) · 회색 상자 = 기능 자리 기둥 4(숨기지 않음) |
| 4 나무 껍질 | 완료 | (이 커밋) | Decal 2(tree_bark · tree_plank · Approved) · Texture 780(껍질 조각 171 × 4면 + 발코니 96 × 윗면) · 껍질 타일 24 → 48(24는 결이 가늘고 어지러움) · 아트 끔 O(ArtStyleV1Force 끝나고 nil) |
| 5 검증 · 보고 | 대기 | | |

## 결정 로그

- 1-2 배너 "1회" 기록 = 설정 키 `weekendBannerAt`(kind stamp - 본 창의 시작 시각). 설정 표는 "없는 키 = 기본값"이라 SAVE_VERSION 그대로.
- 1-3 보너스 칸 받음 = 기존 `claimedFree` · `claimedPaid` 집합의 "41" · "42" …(저장 구조 그대로 · 시즌이 바뀌면 같이 비워짐). 화면 = 패스 창 맨 아래 "보너스 N회" 줄(무료 · 유료 받기 버튼이 다음 안 받은 칸 하나씩).
- 1-2 남은 시간 = 클라 `workspace:GetServerTimeNow()`(서버 시각 동기) - 클라 os.time · 시간대 안 씀.
- 1-5 하네스 가정: 접속 = 한국 20:00(UTC 11:00) · 접속한 날 = 접속 + 일간 전부 + 상자 · 주간 = 1 ~ 6주 차 끝.
- 3-1 실측(수평 stud): 재봉사 자리 ↔ 재봉집 ≈ 20 · 상점 자리 ↔ 상점 건물 ≈ 50 · 명예의 전당 석판 자리 ↔ 명예의 전당 건물 ≈ 98 → 25 규칙으로는 재봉만 합쳐짐. 셋 다 합치려면 HubServiceData.ownBuildingRadius 25 → 100(숫자 하나).
- 3-3 폰 = Toast.setRightLimit("TC", 미니맵 왼쪽 - gap, 미니맵 위 끝) - 왼쪽 끝 그대로 · 폭만 줄임(480 → 377 · 843 × 592). 미니맵이 줄 아래면 제한 없음.
- 3-4 회색 상자 = Workspace.Ground.Hub.Spot_* (6 × 7 × 2 Concrete · 자리 표시 기둥 - 이름표 · 프롬프트 붙는 곳). 메시가 덮은 자리는 이미 투명, 보이는 것 = hatchery · partyBoard · rankBoard · hallOfFame 4개. 기능 자리라 숨기지 않음(에셋화 다음 큐).
- MCP 제약: execute_luau는 게임 모듈 require · RemoteEvent Fire 불가(Capabilities) - 검증은 실제 키 · 클릭 · /gg 명령으로.
- 4 무늬 = roblox/tools/mapgen/bark_texture.py(PIL · 3 × 3 그려 가운데 자름) · 데이터 = HubPropsData.treeTexture(뿌리 tree_root 제외) · 코드 = HubArt.placeScaled → dressTreeTexture. 바탕 조각 색도 무늬 톤(178,120,80 · 204,154,102)으로 - 무늬가 안 덮는 윗면 · 아랫면도 한 톤 밝게.
