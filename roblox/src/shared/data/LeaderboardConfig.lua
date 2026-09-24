-- 리더보드 L1(P3a B) 설정. 규칙(사용자 확정 - docs/phase/P3a-log.md):
--   · 기록 = 보스 클리어만. "자기 최고 다음 보스 스테이지"를 깨고 본인이 보스에게 실제 피해 10% 이상을 넣었을 때만 개인 최고가 오른다(파티 포함 · 치유사도 피해만).
--   · 개인 순위 = 클리어한 보스 스테이지 최고 / 직업별 = 스테이지 높은 순, 같으면 클리어 시간 짧은 순(클리어 당시 직업) /
--     파티 = 그 클리어로 파티원 전원의 개인 최고가 오를 때만.
--   · 시간 = 서버가 잰 시간(보스전 시작 ~ 처치)만. 시즌별 저장소(시즌 ID는 여기 상수, 기간은 설정값).
-- 저장소 이름 = namePrefix(.. "_verify" - 수동 Play 모드의 검증 저장 분리, COMMON §3) .. "_s<시즌>_<종류>". DataStore 이름 상한 50자(공식 문서).

return {
	namePrefix = "ForgeLB_v1",

	-- 시즌: seasonId를 올리면 새 저장소(빈 순위표)로 넘어간다. 기간은 운영 설정값(결정 필요 - 기본 4주). 자동 전환은 L1 범위 밖이다 -
	-- 지금은 seasonStartUnix + seasonLengthDays로 "남은 기간"만 계산해 내려준다(0이면 시작일 미정).
	seasonId = 1,
	seasonLengthDays = 28,
	seasonStartUnix = 0,

	-- 직업별 · 파티 값 인코딩(정렬 저장소는 키마다 숫자 1개): value = stage × stageScale + (timeCapUnits − 1 − 클리어 시간 단위).
	-- 시간 단위 0.1초 · 상한 timeCapUnits − 1 = 9,999,999단위(약 277.8시간) - 넘으면 상한으로 자른다(더 오래 걸린 기록은 모두 같은 꼴찌 시간).
	-- 최댓값 = 안전 상한 스테이지(34,230) × 10^7 + 9,999,999 ≈ 3.4 × 10^11 < 2^53(Luau 숫자가 정확한 정수 범위) - 검증 (가)가 경계를 잰다.
	timeUnitSeconds = 0.1,
	timeCapUnits = 10000000,
	stageScale = 10000000,

	-- 읽기: 서버가 순위표마다 상위 topN을 refreshSeconds마다 한 번 가져와 캐시한다(클라는 캐시만 받는다).
	topN = 100,
	refreshSeconds = 90,

	-- 클라 요청 최소 간격(초, 요청자별). board = 캐시 읽기(저장소 요청 0) · me = 내 기록 1회 읽기 · card = 무기 카드 1회 읽기(캐시 cardCacheSeconds).
	requestIntervalSeconds = { board = 1, me = 10, card = 2 },
	cardCacheSeconds = 300,

	-- 쓰기 실패 재시도(초) - 3번 다 실패하면 로그만 남기고 버린다(다음 기록 때 다시 쓴다 - 개인 · 직업 값은 UpdateAsync로 "더 좋을 때만" 올린다).
	writeRetryDelaysSeconds = { 1, 3, 6 },

	-- 부정 방지: 이론 최소 클리어 시간 = 보스 최대 HP ÷ Σ(멤버의 이론 최대 DPS). 이보다 빠른 기록은 물리적으로 불가능 - 거절 · 로그.
	-- 멤버 이론 최대 DPS = 공격력 × 치명 피해 최대(직업 치명 피해 + 옵션 + 확정 치명 초과분) × 초당 공격 횟수(공속 버프 최대) × burstFactor
	--   × 파훼 창의 보스 받는 피해 배율(최대) × 치유사 버프 최대. burstFactor = 스킬 · 다중 타격을 모두 덮는 여유(평타 DPS의 몇 배까지를 "가능"으로 보는가).
	antiCheat = {
		burstFactor = 12,
		maxBuffSpeedMultiplier = 2.5,
	},

	-- 기록 제외 계정(라이브의 개발 · 운영 계정 UserId). Studio는 수동 Play면 전부 제외 · 검증 모드면 _verify 저장소로만 쓴다(Leaderboard.writeMode).
	excludedUserIds = {},
}
