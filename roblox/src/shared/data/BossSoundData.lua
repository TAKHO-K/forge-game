-- BOSS-FRAMEWORK 6 보스별 소리 자리(음원은 비워 둠 - 로블록스 공식 라이선스 오디오 예외 규칙 · SFX 후보표에서 고른 뒤 "rbxassetid://…"만 채운다).
--   빈 문자열 = 재생 안 함(오류 없음). 재생 = client/BossAnimator(새 몸 리그 v2 보스만 - 옛 몸은 공통 큐 그대로) → client/SoundSheet.playRaw(tier · 3D 자리).
--   roar = 등장 포효 · 50% 변신 포효 · step = 발 디딤(무게 큰 보스) · transform = 변신 동작 시작 · skills[id] = { windup = 전조 시작, hit = 접촉(판정 시각) }.
--   tier = SoundMixData 중요도(보스 소리 기본 3 - 전조 경고 warning(2)보다 낮게: 소리는 보조 단서 · 시각 전조를 지우지 않는다).
local D = { tier = 3, minInterval = 0.1 }

local function skills(list)
	local out = {}
	for _, id in ipairs(list) do
		out[id] = { windup = "", hit = "" }
	end
	return out
end

D.bosses = {
	section_guardian = { roar = "", step = "", transform = "", skills = skills({ "heavy", "shockwave", "meteor", "charge", "cross", "swipe", "grab", "mirror", "innerSmash", "fists", "orbs", "earthSplit" }) },
	frost_giant = { roar = "", step = "", transform = "", skills = skills({ "slam", "icefall", "spike", "roar", "swipe", "grab", "mirror", "innerSmash", "spear", "stomp", "snowball" }) },
	abyssal_lord = { roar = "", step = "", transform = "", skills = skills({ "sweep", "tide", "spout", "colors", "swipe", "grab", "mirror", "tailSweep", "vortex", "bubbles", "tridentThrow" }) },
	crystal_queen = { roar = "", step = "", transform = "", skills = skills({ "burst", "drop", "energyBeam", "orgel", "swipe", "grab", "mirror", "spikes", "shards", "mirrorDash" }) },
	scorpion_queen = { roar = "", step = "", transform = "", skills = skills({ "claw", "sting", "stab", "sandSearch", "swipe", "grab", "armadillo", "stingJab", "ambush", "clawSweep" }) },
	storm_lord = { roar = "", step = "", transform = "", skills = skills({ "discharge", "whirl", "strike", "rods", "swipe", "grab", "mirror", "innerSmash", "tornado", "thunderRing", "boltSpear" }) },
}

return D
