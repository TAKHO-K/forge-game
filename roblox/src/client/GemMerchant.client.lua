-- 보석상인 진입점(S20e) - 월드의 ProximityPrompt(GemMerchantPrompt, PC E · 모바일 탭)를 누르면 "보석 공방" 창(station)을 연다. 창 본체는 client/panels/GemWorkshop/ 이고 이 스크립트는 그것을 시작할 뿐이다.
-- 변환 · 리롤을 해도 되는지는 서버가 요청 시점의 위치로 다시 잰다(GemWorkshop → GemMerchantAccess) - 여기 거리는 표시 편의일 뿐이다.

require(script.Parent.panels.GemWorkshop).start()
