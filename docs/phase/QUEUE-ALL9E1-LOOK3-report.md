# QUEUE-ALL9E1 LOOK3 보고서(3D를 아이콘 수준으로 + 아이콘 다시 굽기 · 2026-10-04 밤)

> 지시 = `docs/phase/QUEUE-ALL9E1-prompt.md` 끝 "LOOK2 판정 → LOOK3". A(판정 기록 · 캐주얼 재측정) = 커밋 64c82faf(`docs/design/all10-p3-decisions.md` 끝 절). 차이 목록 = `docs/design/look3-diff.md`. 규격 = `docs/design/gear-art-v3.md` 3-2절.

## 사용자 판정 필요(맨 위)

> **판정 받음(10-04 밤)**: 1 = 임시 확정(장비 3D 반복 수정 중단) · 2 = 예 · 3 = 갑옷만 LOOK3 아이콘 · 4 = 사용자가 PERF1 때 측정(1벌 텍스처 7.9MB 주의). 기록 = `docs/design/gear-art-v3.md` 3-3절.

1. **LOOK3 3D - 이 정도면 충분한가?** (의견: **"갑옷은 충분 · 장갑/신발은 다음 손질 대상"**)
   - 3칸 비교(아이콘 | LOOK2 | LOOK3 · 4직업 × 영웅 · 전설 · 태초 · 초월): `docs/phase/all9e1/captures/look3/look3_compare_icon_look2_look3_4classes.jpg`
   - 8등급 앞 · 뒤(대검): `look3_ladder_8grades_front_back.jpg` · 간단 메시 단계: `look3_lod_near_far.jpg`
   - 좋아진 점: 어깨 겹판(1.3배 돔 + 곡면 겹판 2 → 전설+ 3) · 판마다 굵은 금속 테 · 패싯 보석 + 발광(EmissiveMask) · 손그림 음영을 구운 색 지도 · 등급마다 장식이 늘어남(리벳 → 이중 테 · 보석 → 필리그리 · 금 → 루비 · 부유 → 왕관 마루 · 목깃 → 태초 날개 · 자홍 띠 → 초월 금 균열) · 직업 실루엣(망토 · 비대칭 어깨 · 후드 · 로브 치마).
   - 남은 약점: ① 장갑 · 신발은 R15 손 · 발이 납작한 판이라 커프 고리가 주가 되고 등급색은 띠만(3-1절 규칙) - 멀리서 등급이 갑옷만큼 안 읽힘 ② 장갑 · 신발은 4직업이 같은 모양(직업 차이는 갑옷에만) ③ 무지개 띠(태초)는 넣지 않음(자홍 띠만).
2. **어깨판을 윗팔 → 윗몸통(UpperTorso)에 붙임**(6절 "어깨판은 UpperArm에" 규칙 변경): 1.3배 큰 어깨를 쓰고 갑옷 조각을 3개로 줄이려고 R15 어깨 장신구 자리(윗몸통)에 붙였다. 팔을 크게 들면 팔이 겹판 안으로 들어간다. **이대로 둘지** 판정 필요(추천: 예 - 다른 Roblox 어깨 장신구와 같은 방식).
3. **아이콘 다시 굽기(C) - 어느 쪽을 쓸지**: 비교 시트 `docs/art/ref/compare/icons-look3-vs-current.png`(부위마다 지금 아이콘 1줄 + LOOK3 4직업 4줄 × 8등급). 추천: **갑옷 = LOOK3 아이콘으로 교체 · 장갑/신발 = 지금 아이콘 유지**(LOOK3 장갑 · 신발 아이콘은 커프 원통이 주라 지금 것보다 덜 읽힘). 선택 전까지 게임은 옛 아이콘 그대로(새 아이콘 96장 = `roblox/art/icons/gear_v3_look3/` - 업로드 · 연결 안 함).
4. **16인 · 4인 프레임은 직접 측정 필요**(아래 7절 방법). Studio MCP는 클라 1개만 띄우고, Studio 메모리 통계는 캐시 때문에 LOOK3 ↔ LOOK2 전환 전후가 같은 값(109.2MB)으로 나와 비교에 못 썼다.

## 1. 구조(장식은 한 메시로 합침)
| 부위 | 조각(붙는 파트) | MeshPart |
|---|---|---|
| 갑옷 | Main(UpperTorso: 가슴 · 목깃 · 벨트 · 어깨판 · 천 · 부유) · Tasset(LowerTorso) · 세트 문장(LOOK2 메시 그대로) | 3 |
| 장갑 | Glove_L/R(손) · Bracer_L/R(아래팔) | 4 |
| 신발 | Boot_L/R(발) · Greave_L/R(정강이 + 무릎 판) | 4 |
| 1벌 | | **11**(≤ 16) |
- 메시 = 등급마다(4직업 × 3부위 × 8등급 = 96벌 · LOOK2의 단계 + 문 부품 대신) - `roblox/tools/blender/make_gear_look3.py` · FBX 96 업로드(Approved 96).
- 색 = 조각마다 SurfaceAppearance 1개(같은 부위 조각은 한 지도 공유): 에나멜(등급 메인 × 밝기) · 금속(등급대) · 가죽 · 보석 · 균열을 지도에 구움 + 윗면 빛 · 모서리 밝은 선 · 틈 그림자. **세트 천 = 지도 알파(AlphaMode Overlay) → 파트 Color = 세트 색1**이 비침(세트 6 × 지도 1장) · **발광 = EmissiveMaskContent**(Neon 파트 없음 · 세기 2).
- 템플릿 = `roblox/src/shared/GearV3Look3.rbxmx`(`look3_looks.py` - Rojo로 EmissiveMaskContent · EmissiveStrength가 그대로 들어가는 것 확인) · 지도 = `look3_maps.py`(색 96 + 발광 68 · 업로드 164).
- 게임 = `client/ArmorWearView`(등급 메시가 있으면 LOOK3 · 크기 = 붙는 파트 실측 ÷ 기준 체형) · 스위치 `GearV3Data.look3.enabled`(Studio = ReplicatedStorage Attribute `GearV3Look3`).
- Play에서 찾아 고친 것: ① 세트 문장이 등급색으로 칠해져 가슴판에 묻힘(조각 이름 "Emblem"에 구역 접미사가 없어 `armorColor`가 등급색으로 떨어짐 - LOOK2부터 있던 동작) → LOOK3 경로에서 세트 색2로 ② 스위치를 꺼도 LOOK3가 남음(입힐 때 옛 LOD 상태를 다시 씀) → 입힐 때마다 다시 판정.

## 2. 간단 메시(LOD 2단)
- 간단 단계 = LOOK2 단계 메시(같은 색 구역 · 바닥층 · 토글은 서버라 두 단계 같다).
- 간단으로 가는 조건: 그래픽 품질 저장값 1 ~ 3(자동 = 높음 취급) · 터치 전용 기기(폰) · 남의 캐릭터가 카메라에서 70 stud 밖(복귀 60 · 1초마다 판정 · 내 캐릭터는 항상 LOOK3).
- Play 확인: 더미 8명 앞 30 stud = LOOK3 몸통 조각 9(더미 8 + 나) · 110 stud = 1(나만) - `look3_lod_near_far.jpg`. 품질 · 폰 분기는 코드 판정만(Studio에서 품질 저장값을 바꿀 수 없음 - 미검증).
- 직업 선택 무대(ClassStage)는 LOOK2 그대로(이번 범위 밖) · 장비창 캐릭터 그림은 월드 조각을 복제하므로 LOOK3가 그대로 보인다.

## 3. 예산 · 성능
| 항목 | 상한(사용자 승인) | LOOK3 실제 |
|---|---|---|
| 부위 삼각형 일반 ~ 영웅 | 2,500 | 최대 2,472(영웅 갑옷) |
| 부위 삼각형 전설 ~ 고대 | 4,000 | 최대 3,872 |
| 부위 삼각형 태초 · 초월 | 6,000 | 최대 4,384 |
| 1벌(무기 제외) | 15,000 | 최대 7,760(대검 태초) · LOOK2 최대 2,086 |
| 메시 1개 | 20,000 | 최대 3,952(대검 태초 갑옷 Main) |
| MeshPart 부위 / 1벌 | 4 / 16 | 4 / 11(문장 포함) |
| 텍스처 | ≤ 1024 | 갑옷 1024 · 장갑/신발 512 · 발광 마스크 = 절반 |
| 1벌 텍스처 메모리(RGBA 압축 전) | - | 최대 7.9MB(+ 문장 0.26MB) · LOOK2 3.4MB · GPU 압축 시 약 ¼ |
| 16인 최악(전원 다른 등급 · 가까이) | - | 약 126MB(압축 전) · 70 stud 밖은 LOOK2(3.4MB) |
| 디스크(지도 164장) | - | 43.7MB |
- 하네스 `gear_v3` 10/10(새 줄: LOOK3 96벌 · 부위당 ≤ 4 · 1벌 ≤ 16 · 삼각형 상한 · 메시 ≤ 20,000).

## 4. 아이콘 다시 굽기(C)
- `make_icons_look3.py`(LOOK3 메시 + 구운 지도 · 툰 매트캡 · 같은 각도) → `icons_look3.py`(256 · 80% 맞춤 · 외곽선 = icons_v3.post 그대로) → 96장 + 비교 시트.
- 다른 점 1개: 장갑 · 신발은 15° 위에서 보면 팔 · 다리 절단면 뚜껑이 아이콘 절반을 차지해 높이 각을 2°로 낮춤.
- 천(세트 자리) = 직업 바닥층 색(중립 - 세트 구분은 칸 배지). 무기는 LOOK3 대상이 아니라(3D 무기 그대로) 다시 굽지 않음.

## 5. 검증
- `run_all` 전부 통과(security_launch 45/45 · save_launch 65/65 · … · all10 57/57 · gear_v3 10/10 · id_registry 통과) · `check_textdata` 통과.
- Play: 4직업 × 4등급 LOOK3 / LOOK2 전환 · 8등급 앞 · 뒤 · LOD 거리 전환 · 로그 게임 에러 0(경고 2 = 기존 NestSync · BossGateRegistered 무한 대기 · 엔진 에셋 오류 = 오디오 심사 중 등 LOOK3 무관).

## 6. 남은 것 · 다음
- 판정 1 · 2 · 3 결과에 따라: 장갑 · 신발 형태 보강(직업별 모양 · 손등 판 키우기) · 아이콘 연결(갑옷만 또는 전부).
- 원래 순서: 1-2 남은 부분 → 블록 2 → 3(+ 보석 홈 추가 항목) → 4 → ADD F → MENU2.

## 7. 4인 · 16인 프레임 측정 방법(사용자용)
1. Studio 상단 **테스트** 탭 → "클라이언트 및 서버" 영역에서 **로컬 서버**를 고르고 플레이어 수를 **4**(보스전) 또는 **16**(허브)으로 놓고 **시작**.
2. 서버 창 명령줄에서 모두 같은 장비로 맞춘다(가장 무거운 경우): `for _,p in game.Players:GetPlayers() do for _,s in {"armor","gloves","shoes"} do p:SetAttribute("ArmorLook_"..s,"tier1|primordial") end p:SetAttribute("ClassId","greatsword") end`
3. 클라이언트 창 하나에서 **Shift + F5**(성능 통계)와 **Ctrl + Shift + F2**(마이크로프로파일러) - 확인할 수치: **FPS** · **Render**(ms) · **GPU**(ms) · 메모리 **GraphicsTexture** · **GraphicsMeshParts**(F9 개발자 콘솔 → Memory).
4. 같은 측정을 LOOK2로: 서버 창에서 `game.ReplicatedStorage:SetAttribute("GearV3Look3", false)` → 다시 3번. 두 값의 차이가 LOOK3 비용.
5. 기준(제안): 4인 보스전 FPS 하락 ≤ 10% · 16인 허브 GraphicsTexture 증가 ≤ 150MB. 넘으면 `GearV3Data.look3.lodDistance`(70)를 낮춘다(데이터 한 줄).

## 커밋
64c82faf(A) · (이 커밋) B + C
