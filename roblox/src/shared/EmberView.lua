-- UI-1 6단계 불씨 칸 계산(05 v4 spec §2 · 순수 함수 - 화면 EmberBar · 하네스 ember_view가 같이 읽는다).
--   칸 1개 = 실패 1번 · 칸 수 = 그 단계 0 → 가득 실패 수 = ceil(가득 ÷ 실패 1번 점수(Enhance.getGaugeGain - 서버 판정과 같은 함수)).
--   칠한 칸 = 불씨 ÷ 점수(조각 허용) · 가득까지 n번 = ceil(남은 불씨 ÷ 점수) · 하락 · 초기화 = 불씨 그대로 · 칸 수만 새 단계로 다시 나눔.
local Enhance = require(script.Parent.Enhance)
local EnhanceConfig = require(script.Parent.data.EnhanceConfig)

local EmberView = {}

function EmberView.compute(level, gauge)
	local max = EnhanceConfig.gauge.max
	local gain = Enhance.getGaugeGain(level)
	gauge = math.clamp(gauge or 0, 0, max)
	if gain <= 0 then -- 상한(+30) = 칸 없음
		return { cells = 0, filled = 0, left = 0, pct = math.floor(gauge * 100 / max), full = gauge >= max, gain = 0, gainPct = 0 }
	end
	local cells = math.ceil(max / gain)
	return {
		cells = cells,
		filled = gauge >= max and cells or math.min(cells, gauge / gain), -- 가득 = 칸 전부(마지막 칸은 점수가 칸보다 작아도 꽉 채움)
		left = math.max(0, math.ceil((max - gauge) / gain)),
		pct = math.floor(gauge * 100 / max),
		full = gauge >= max,
		gain = gain,
		gainPct = gain * 100 / max,
	}
end

return EmberView
