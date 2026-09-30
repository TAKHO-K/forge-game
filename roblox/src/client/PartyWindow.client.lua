-- 파티창(S12b E) 시작점 - 창(panels/Party)과 HUD [파티] 버튼을 짓는다. 로직은 전부 panels/Party.lua에 있다.
require(script.Parent.panels.Party).init()
require(script.Parent.panels.PartyBoard).init() -- A2-N4 §4-4 같은 서버 모집 게시판(파티창 [모집 게시판] 버튼)
