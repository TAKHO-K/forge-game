-- 보스 공통 뼈대의 클라 표시(29-1, PRD 20.73 [2-8]) - 잡힘/구출 UI와 파훼 게이트 표식. 이 스크립트는
-- 두 모듈을 켜기만 한다(레지스터 200 한계 - UI 로직은 처음부터 모듈에 둔다, 20.71 [4]).
local BossTrapView = require(script.Parent.BossTrapView)
local BossGateView = require(script.Parent.BossGateView)

BossTrapView.start()
BossGateView.start()
