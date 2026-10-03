-- QUEUE-ALL2 P2 새 창 부트(캐릭터 C · 수련 U · 지도 M) - 창을 미리 지어 UIManager에 등록(단축키 · 왼쪽 메뉴가 이 등록을 연다). 퀘스트 창(QuestsUI)과 같은 모양.
require(script.Parent.panels.Character).init()
require(script.Parent.panels.Training).init()
require(script.Parent.panels.WorldMapPanel).init()
require(script.Parent.panels.Attendance).init() -- 7일 출석 · 첫 접속 보상(하루 첫 접속 자동 1회)
require(script.Parent.panels.SeasonBoard).init(require(script.Parent.panels.Attendance).hasClaimable) -- QUEUE-ALL9B 5 시즌 출석판(접속 보상 창 다음 · 그 창이 없는 날은 혼자)
