-- 저장 시스템 수치. DataStore 이름·재시도 횟수·자동저장 주기처럼 "얼마나/몇 번"에 해당하는
-- 값만 여기 둔다. 스키마 자체(기본값·migrate)는 core/save.js와 같은 역할을 하는
-- server/SaveSystem.lua에 있다 - 그건 로직이라 core/에 안 둔다.

return {
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
	saveVersion = 10,

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
