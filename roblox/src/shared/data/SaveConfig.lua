-- 저장 시스템 수치. DataStore 이름·재시도 횟수·자동저장 주기처럼 "얼마나/몇 번"에 해당하는
-- 값만 여기 둔다. 스키마 자체(기본값·migrate)는 core/save.js와 같은 역할을 하는
-- server/SaveSystem.lua에 있다 - 그건 로직이라 core/에 안 둔다.

return {
	-- 29(30-0 S11) - 보스 도감 도장: purchases.bossCodex = { [bossId] = true }(키는 BossData.bosses의 id 문자열 - 계정 공유, 빈 집합에서 시작. 기여 10% 이상으로 그 보스를 처치한 순간
	-- 찍힌다 - 표시는 스테이지 선택 패널의 보상 띠 한 곳뿐). 기존 세이브는 빈 집합으로 시작한다(이미 깬 보스에서 역산하지 않는다 - 한 번 더 깨면 찍힌다). SaveSystem.migrate()의 v28->v29 참고.
	-- 28(30-0 S05 후속) - 스키마 필드 변화 없음. 스테이지 · 단계 번호를 키로 쓰는 저장 집합 두 곳(classes[*].stageProgress.bossFirstClearStages · tutorial.granted)의 키를
	-- 전부 문자열로 통일한다 - DataStore 왕복이 숫자 키를 문자열로 바꿔 돌려주므로(배열처럼 이어진 1 ~ n 키는 숫자로 남기도 한다) 숫자 키 조회가 재접속 뒤 깨졌다.
	-- 이제 쓰고 읽는 쪽이 tostring 키를 쓴다. SaveSystem.migrate()의 v27->v28 참고.
	-- 27(30-0 S05) - 방지권: purchases.protectionTickets = { drop, reset }(0 이상 정수) · purchases.protectionClaimedStages = { ["보스 스테이지"] = true }(문자열 키 - DataStore가 숫자 키를 문자열로 바꾼다. 계정 공유 - 보스
	-- 계정 첫 클리어 지급을 이미 받은 스테이지 집합, 직업별 bossFirstClearStages와 별개) 필드 신설. 기존 세이브는 0장 · 빈 집합으로 시작한다(이미 깬 보스도 한 번 더
	-- 깨면 받는다 - PRD 20.72 [1-7]). SaveSystem.migrate()의 v26->v27 참고.
	-- 26(30-0 S04) - 강화 재료 보유량 profile.materials = { enhanceStone, highEnhanceStone }(0 이상 정수, 계정 공유 - gold · purchases와 같은 층) 필드 신설.
	-- 기존 세이브는 전부 0으로 시작한다. SaveSystem.migrate()의 v25->v26 참고.
	-- 25(30-0 S03) - 강화 천장("불씨") 게이지 weapon.enhanceGauge(0 ~ 1000 정수, 직업별 무기에 딸림) 필드 신설. 기존 무기는 전부 0으로 시작한다.
	-- 강화 단계(weapon.level)는 그대로 둔다(소급 없음 - PRD 20.72 [1-7]). SaveSystem.migrate()의 v24->v25 참고.
	-- 24(30-0 S02) - 스키마 필드 변화 없음. 옛 규칙(itemLevel = 레벨 × tier 보너스)으로 부풀려진 장비의 itemLevel을
	-- min(itemLevel, dropStage + 2)로 자른다(PRD 20.72 [2-7] - 되돌릴 수 없는 값 이관). 가방 + 모든 직업의 착용
	-- 장비 3부위만 대상이고 보석 · 무기 · 옵션 · 등급은 그대로다. SaveSystem.migrate()의 v23->v24 참고.
	-- 23(26-1) - 보석·장비 옵션 통합(PRD 20.67 [13]). item(가방·착용)에 option 필드 신설
	-- (없으면 nil), gem(홈·보유)은 optionId 필드가 option({id, roll, roll2})으로 바뀐다.
	-- SaveSystem.migrate()의 v22->v23 참고.
	-- 22(25-1) - 캐릭터 레벨 곡선을 "목표 마릿수 역산" 하나로 통일(회차별 두 곡선 폐지). 스키마
	-- 필드 변화는 없고 characterExp 값을 옛 곡선의 레벨·진행률 그대로 새 곡선 위치로 옮긴다.
	-- SaveSystem.migrate()의 v21->v22 참고.
	-- 19(23-2) - 옵션 변환권(purchases.optionRerollTickets = {ancient, primordial}) 필드
	-- 신설. 계정 전체 공유. SaveSystem.migrate()의 v18->v19 참고.
	-- 18(23-2) - 무기 보석 슬롯(weapon.gems, 5칸) + 보석 인벤토리(classState.gemInventory)
	-- 필드 신설. 직업별(무기에 딸린 자산이라 gold와 다른 층). SaveSystem.migrate()의
	-- v17->v18 참고.
	-- 17(23-1) - 견습 모드 진행도(tutorial = {completed, step, granted, lendBaseline}) 필드
	-- 신설. 계정 전체 공유(gold와 같은 층) - 무한 모드 stageProgress.infinite와 완전히
	-- 독립이다. SaveSystem.migrate()의 v16->v17 참고.
	-- 16(20-4) - 보스 첫 처치 확정 드랍 기록(stageProgress.bossFirstClearStages) + 환생
	-- 횟수 스텁(rebirthCount) 필드 신설. SaveSystem.migrate()의 v15->v16 참고.
	-- 15(20-3) - 일괄판매 기준 등급 선택(bulkSellCutoffGrade) 필드 신설. 이전엔 선택 개념
	-- 자체가 없었다(항상 "잠긴 것만 빼고 전부"). SaveSystem.migrate()의 v14->v15 참고.
	-- 14(20-1) - 무기 등급 축 신설. classes[classId].weapon에 grade 필드(0~6) 추가.
	-- 기존 무기는 전부 0(일반)으로 소급 채운다. SaveSystem.migrate()의 v13->v14 참고.
	-- 13(19-1) - 직업별 저장 분리. characterExp·무기·착용 장비 3부위·무한 모드 진행도가
	-- 최상위에서 profile.classes[classId] 아래로 옮겨간다(직업마다 따로). gold·인벤토리는
	-- 계정 전체 공유로 최상위에 그대로 남는다. classId 필드 자체는 없어지지 않는다 - "현재
	-- 활성 직업" 포인터로 의미가 바뀔 뿐이다. SaveSystem.migrate()의 v12->v13 참고.
	-- 12(17-1) - 인벤토리·착용 아이템에 없던 tierIndex 필드를 1로 소급 채움(드랍표를
	-- tier별로 실제 연결하면서 생긴 필드 - 그 전엔 전부 tier1 표 하나로만 굴렸다).
	-- SaveSystem.migrate()의 v11->v12 참고.
	-- 11(17-1) - 캐릭터 레벨 EXP 곡선 26+ 구간 공비를 1.216->1.155로 재보정(몬스터 HP
	-- 공비와 맞춤). 기존 characterExp를 옛 공식으로 레벨을 구한 뒤 새 공식의 그 레벨
	-- 임계값으로 다시 맞춰 레벨이 그대로 유지되게 한다. SaveSystem.migrate()의
	-- v10->v11 참고.
	-- 10(16-6) - 기존 아이템(인벤토리·착용 갑옷)에 없던 part 필드를 "armor"로 소급 채움 -
	-- 16-6 전엔 갑옷만 드랍돼 부위 구분이 없었다. SaveSystem.migrate()의 v9->v10 참고.
	-- 9(16-6) - equipment.boots(항상 nil이던 죽은 필드명)를 equipment.shoes로 정리 + 장갑·
	-- 신발이 실제로 드랍·장착 가능해짐. SaveSystem.migrate()의 v8->v9 참고.
	-- 8(15-1) - 보스 처치 기록(stageProgress.bestBossCleared) 필드 추가. SaveSystem.migrate()의
	-- v7->v8 참고.
	-- 7(13-2) - characterExp 필드 신설 + 인벤토리 아이템에 itemLevel 필드 추가(기존
	-- dropStage 기반 방어력 스케일링을 되돌림). SaveSystem.migrate()의 v6->v7 참고.
	-- 6(13-1) - 인벤토리 아이템에 locked 필드 추가. SaveSystem.migrate()의 v5->v6 참고.
	-- 5(12-1) - 인벤토리(갑옷 드랍) 배열 필드 추가. SaveSystem.migrate()의 v4->v5 참고.
	-- 4(11-1) - 무한 모드 스테이지 진행도(현재/최고 구분) 추가. 3(10-3) - 클래스 선택
	-- 필드(classId) 추가.
	-- 30(30-0 S20e) - 계정 안내 플래그 표 hints 신설(hints.gemMerchantUsed = 보석상인에서 변환 · 리롤을 한 번이라도 성공했는가). SaveSystem.migrate()의 v29->v30 참고.
	-- 31(P2.5b C) - 보석 가루 profile.gemDust(0 이상 정수, 계정 공유 - 보석 분해로 늘고 재련 · 변환권 구매가 쓴다) 신설. 기존 세이브는 0. SaveSystem.migrate()의 v30->v31 참고.
	-- 32(P2.5b D) - 환생 후 레벨 마일스톤: classes[*].milestones = { [tostring(환생 회차)] = 그 회차에서 받은 마지막 능력치 마일스톤 레벨 }(직업별 · 문자열 키) ·
	-- profile.milestoneUnlocks = 받은 해금 개수(계정 공유 0 이상 정수) 신설. 기존 세이브는 빈 표 · 0 - 지금 회차의 지금 레벨까지는 접속할 때 채운다(지난 회차는 기록이 없어 소급하지 않는다).
	-- SaveSystem.migrate()의 v31->v32 참고.
	-- 33(P2.5c B2) - 마일스톤 재설계: classes[*].milestones(회차별 표)를 지우고 classes[*].milestoneLevel(받은 마지막 능력치 마일스톤 레벨, 0 이상 정수)을 신설.
	-- 기존 세이브는 0 - 환생 5회를 마친 직업은 접속 때 지금 레벨까지 채운다. milestoneUnlocks는 그대로. SaveSystem.migrate()의 v32->v33 참고.
	-- 34(P3a B3) - 계정 단위 leaderboardTainted(boolean) 신설 - /gg가 돈 계정은 리더보드에 쓰지 않는다. 기존 세이브는 보스 클리어가 하나라도 있으면 true(진도 출처를 가릴 수 없다), 없으면 false.
	-- SaveSystem.migrate()의 v33->v34 참고.
	-- 35(P3c C4) - 필드 변경 없음, 값 이관: 레벨 126부터 필요 경험치 × 레벨별 배수(CharacterLevel.getExpScale - 133.3에서 레벨마다 ×0.99, 1에서 멈춤). classes[*].characterExp를
	-- 옛 곡선(배수 없음)으로 읽은 레벨 · 진행률 그대로 새 곡선의 값으로 옮긴다. SaveSystem.migrate()의 v34->v35 참고.
	-- 39(M1 봉인 입구) - titles = { [칭호 id 문자열] = true }(계정 공유 - 전투력 없음) 신설. 기존 세이브는 빈 표. SaveSystem.migrate()의 v38->v39 참고.
	-- 38(M1) - world = { portals = { [구역 키] = true } }(입구 캠프 첫 방문으로 연 포탈 - 계정 공유) · peakLevel(역대 최고 캐릭터 레벨 - 환생해도 안 내려간다 · 나무 가지 정거장 기준)
	-- 신설. 기존 세이브: portals 빈 표 · peakLevel = 지금 직업들 레벨 중 최대(환생 전 기록은 저장에 없어 복원 불가). SaveSystem.migrate()의 v37->v38 참고.
	-- 37(BR1-2) - hints.bossIntroSeen(보스 id 문자열 키 집합) 신설 - 처음 만난 보스의 전멸기 카드를 한 번만 띄운다. 기존 세이브는 빈 표. SaveSystem.migrate()의 v36->v37 참고.
	saveVersion = 39, -- M1: titles(칭호 - 호기심 대장) · v38 world.portals · peakLevel

	-- Studio 재시작이나 배포 채널이 섞여도 예전 세이브 파일과 충돌하지 않게 버전을 이름에 박는다.
	dataStoreName = "ForgeGamePlayerData_v1",

	-- 자동저장 주기(초). DataStore 쓰기(SetAsync/UpdateAsync 계열) 요청 예산은 로블록스 공식
	-- 문서 기준 분당 60 + 인원수×10 - 인원 100명이어도 분당 1060회다. 60초 주기면 1인당 분당
	-- 1회씩만 쓰므로 100명이어도 분당 100회 = 예산의 약 9.4%다.
	-- [9-5, 10-1 개정 - 원래 300초였다] 5분 주기는 예산상 여유(300초=1인당 분당 20회=1.9%)가
	-- 훨씬 넉넉했지만, 화면엔 이미 골드가 올라가 있는데 크래시로 최대 5분치가 사라지면
	-- 유저는 "분명 있었는데 없어졌다"로 받아들인다 - 신뢰를 깎는 종류의 손실이라 60초로
	-- 좁혔다. 반대로 몬스터 처치마다 저장하면 공격 쿨다운(0.28초)만으로 1인당 분당 최대
	-- 약 214회라 그 자체로 예산을 넘는다 - "처치 즉시 저장"은 여전히 안 한다(주기+퇴장+
	-- BindToClose 조합). 강화처럼 되돌릴 수 없는 사건은 주기와 무관하게 즉시 저장한다
	-- (10-2, EnhanceServer.server.lua의 스로틀 로직·예산 검산 참고).
	autosaveIntervalSeconds = 60,

	-- 저장/불러오기 재시도 횟수(첫 시도 이후 추가로 몇 번 더 시도하는지)와 시도 사이 대기(초).
	-- 배열 길이 = 재시도 횟수와 같아야 한다(총 시도 = 1 + 재시도 횟수, 대기는 시도 사이에만
	-- 있으니 시도 횟수-1이 아니라 재시도 횟수만큼 정확히 발생한다 - 마지막 재시도 뒤에도
	-- "한 번 더 시도하기 전 대기"가 있기 때문). 마지막 시도까지 실패하면 재시도를 멈추고
	-- 플레이어에게 알린다(SaveServer.server.lua).
	saveRetryCount = 3,
	saveRetryDelaysSeconds = { 1, 3, 6 },

	-- 인벤토리 칸 수 초기값. 웹에는 대응하는 상수가 없어 잠정값이다 - 상점에서 칸 확장을
	-- 만들 때 실제 기준(가격 곡선 등)과 함께 재조정한다.
	defaultInventorySlots = 20,
}
