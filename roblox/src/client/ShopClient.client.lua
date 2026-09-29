-- 상점 진입점(QUEUE-B1 B2 UI) - 보석상인 좌판의 ShopPrompt(서버 HuntingGround가 만든다)를 누르면 상점 창(station)을 연다 + 선물함 팝업(GiftPopup)을 듣는다.
-- 창 본체는 client/panels/Shop/ 이고 이 스크립트는 그것을 시작할 뿐이다(보석 공방 GemMerchant.client.lua와 같은 모양).

require(script.Parent.panels.Shop).start()
