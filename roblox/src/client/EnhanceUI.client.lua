-- 강화 UI 진입점(10-2 → 28-1 S07). 화면 본체는 client/panels/Enhance/(GUI 공통 틀 위의 station 패널)로 옮겼다 - 이 스크립트는 그것을 시작할 뿐이다.
-- 확률 · 비용 표시는 shared/Enhance의 조회 함수로 계산하고 실제 판정은 서버 전용이다(EnhanceService). 강화대 근처에서만 열린다(WorldConfig.enhance.interactionRangeStuds - 서버와 같은 값).

require(script.Parent.panels.Enhance).start()
