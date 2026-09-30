-- QUEUE-ALL2 P4 ①(09 문서 B-2 피로 금지 · docs/visual-audit.md 1순위 1): 화면 흔들림 · 번쩍임 한 통로(client/CameraShake)의 종류별 규칙.
--   세기 = 호출 값 × kinds[종류].scale × 설정 연출 세기(LocalPlayer FxScale: 보통 1 · 약 0.5 · 끔 0) · 설정 "화면 흔들림" 끔(SettingScreenShake false)이면 climax만 빼고 없음.
--   budgetSeconds = 흔들림 · 번쩍임은 같은 N초 안에 1번까지(종류 budget = true만 센다 - climax는 예외: 강화 대성공 · 태초 · 초월 · 보스 첫 처치 등 클라이맥스).
--   일반 사냥 = 흔들림 0(내 강공격 적중 heavy만 아주 약하게). 판정 · 시간 불변(카메라 로컬 연출만).
return {
	budgetSeconds = 3,
	kinds = {
		heavy = { scale = 0.5, budget = true }, -- 내 강공격 적중(3타 · 공중 내려찍기 착지 · 비장의 한 발 적중) - 아주 약하게
		hurt = { scale = 0.7, budget = true }, -- 큰 전조 공격에 맞음(넘어짐 등)
		boss = { scale = 1, budget = true }, -- 보스 패턴 근처(BossFx - 데이터 값)
		climax = { scale = 1, budget = false }, -- 클라이맥스(설정 끔이면 없음)
	},
	flash = { budget = true }, -- 화면 번쩍임도 같은 N초 안에 1번(클라이맥스 = kind climax로 부르면 예외)
}
