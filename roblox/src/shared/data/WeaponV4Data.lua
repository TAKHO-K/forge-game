-- FINAL-1 2 WEAPON-HOLD: 무기 32종 v4 메시(claude-design-handoff 40_gear _3d remesh → tools/blender/weapon_kit.py → art/weapons/v4) - 겉모습만(능력치 · 등급 무변경).
--   메시 키 = ArtAssetIds "weapons/v4/<종류>_g<n>"(쌍검 왼손 = "_L" 좌우 대칭 사본) · 아틀라스 = "<키>_atlas1".
--   원점 = 손잡이(Grip - 손바닥 점이 오는 자리) · 축 = WeaponRigSpec(칼 +Z 끝 · 지팡이 +Y 머리 · 활 X 날개 · +Z 시위 쪽).
--   rows = 등급마다 다시 잰 손잡이 표(weapon_v4_data.py가 meta.json에서 다시 쓴다 - 손으로 고치지 않는다):
--     length = 끝 축 길이(stud) · refScale = length ÷ WeaponRigSpec refLength(단검만 등급마다 다름 - 규격 검사 · 길이 맞춤이 이 배율을 쓴다)
--     gripFrom · gripTo = 손잡이 구간(자루 끝 0 → 끝 1 비율) · gripThickness = 손잡이 두께(stud) · attachments = 부착점(모델 로컬 · Glow = 보석 · 룬 자리 추정)
local M = {}

M.enabled = true -- 끄면 옛 경로(GearV3 · A2-N1 메시 · 지금 메시) 그대로
M.prefix = "weapons/v4/"
M.classKey = { greatsword = "gs", dualblade = "db", bow = "bow", healer = "staff" }
-- 무기 등급(ArmorData.gradeOrder) → 메시 단계(g1 ~ g8)
M.gradeIndex = { normal = 1, rare = 2, epic = 3, legendary = 4, relic = 5, ancient = 6, primordial = 7, transcendent = 8 }
M.mirrorSuffix = "_L" -- 쌍검 왼손 조각(BladeLeft)
M.priorityOnly = true -- 서버 메시 로더 우선 묶음(weapons/)에 v4만 넣는다(옛 무기 메시는 나머지 묶음 - 첫 순간 기본 도형 시간 단축)

-- 발광 = 보석 · 룬 자리(Glow 부착점)에 작은 빛만 - 무기 전체를 Neon으로 만들지 않는다. 색 = 등급 색(GradeColor) · minGrade 미만은 빛 없음
M.glow = { minGrade = 4, brightness = 0.8, range = 3.5 }
-- g7(태초) 마젠타 발광 노브: enabled = false면 위 등급 색 규칙을 따른다
M.primalGlow = { enabled = true, grade = 7, color = Color3.fromRGB(255, 60, 220), brightness = 1.6, range = 5 }

M.rows = {
-- rows:begin
	["bow_g1"] = { length = 5.740, refScale = 1.000, tris = 2878, gripFrom = 0.412, gripTo = 0.588, gripThickness = 0.452, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 1.1575), StringNock = Vector3.new(0.0000, 0.0000, 1.1575), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g2"] = { length = 5.740, refScale = 1.000, tris = 3004, gripFrom = 0.412, gripTo = 0.588, gripThickness = 0.463, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 1.2145), StringNock = Vector3.new(0.0000, 0.0000, 1.2145), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g3"] = { length = 5.740, refScale = 1.000, tris = 3012, gripFrom = 0.425, gripTo = 0.575, gripThickness = 0.453, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 1.2437), StringNock = Vector3.new(0.0000, 0.0000, 1.2437), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g4"] = { length = 5.740, refScale = 1.000, tris = 5000, gripFrom = 0.438, gripTo = 0.575, gripThickness = 0.431, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8341, 0.0000, 0.9646), StringNock = Vector3.new(0.0000, 0.0000, 0.9646), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g5"] = { length = 5.740, refScale = 1.000, tris = 4999, gripFrom = 0.450, gripTo = 0.550, gripThickness = 0.411, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 0.8067), StringNock = Vector3.new(0.0000, 0.0000, 0.8067), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g6"] = { length = 5.740, refScale = 1.000, tris = 5000, gripFrom = 0.450, gripTo = 0.550, gripThickness = 0.363, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 0.9431), StringNock = Vector3.new(0.0000, 0.0000, 0.9431), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g7"] = { length = 5.740, refScale = 1.000, tris = 5000, gripFrom = 0.438, gripTo = 0.562, gripThickness = 0.251, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 1.1391), StringNock = Vector3.new(0.0000, 0.0000, 1.1391), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["bow_g8"] = { length = 5.740, refScale = 1.000, tris = 5000, gripFrom = 0.450, gripTo = 0.550, gripThickness = 0.300, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(2.8700, 0.0000, 0.3612), StringNock = Vector3.new(0.0000, 0.0000, 0.3612), Glow = Vector3.new(0.0000, 0.0000, 0.0000) } },
	["db_g1"] = { length = 1.802, refScale = 0.693, tris = 3079, gripFrom = 0.013, gripTo = 0.362, gripThickness = 0.238, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.4641), Butt = Vector3.new(0.0000, 0.0000, -0.3379), Glow = Vector3.new(0.0000, 0.0000, 0.4235) } },
	["db_g2"] = { length = 1.836, refScale = 0.706, tris = 2799, gripFrom = 0.013, gripTo = 0.287, gripThickness = 0.166, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.5606), Butt = Vector3.new(0.0000, 0.0000, -0.2754), Glow = Vector3.new(0.0000, 0.0000, 0.3626) } },
	["db_g3"] = { length = 2.028, refScale = 0.780, tris = 2799, gripFrom = 0.062, gripTo = 0.412, gripThickness = 0.228, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.5463), Butt = Vector3.new(0.0000, 0.0000, -0.4817), Glow = Vector3.new(0.0000, 0.0000, 0.4766) } },
	["db_g4"] = { length = 2.150, refScale = 0.827, tris = 3052, gripFrom = 0.013, gripTo = 0.300, gripThickness = 0.171, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.8141), Butt = Vector3.new(0.0000, 0.0000, -0.3359), Glow = Vector3.new(0.0000, 0.0000, 0.4381) } },
	["db_g5"] = { length = 2.192, refScale = 0.843, tris = 2903, gripFrom = 0.100, gripTo = 0.250, gripThickness = 0.130, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.8084), Butt = Vector3.new(0.0000, 0.0000, -0.3836), Glow = Vector3.new(0.0000, 0.0000, 0.2959) } },
	["db_g6"] = { length = 2.236, refScale = 0.860, tris = 2944, gripFrom = 0.100, gripTo = 0.312, gripThickness = 0.134, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.7748), Butt = Vector3.new(0.0000, 0.0000, -0.4612), Glow = Vector3.new(0.0000, 0.0000, 0.3717) } },
	["db_g7"] = { length = 2.280, refScale = 0.877, tris = 3006, gripFrom = 0.013, gripTo = 0.263, gripThickness = 0.207, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 1.9665), Butt = Vector3.new(0.0000, 0.0000, -0.3135), Glow = Vector3.new(0.0000, 0.0000, 0.4218) } },
	["db_g8"] = { length = 2.600, refScale = 1.000, tris = 3005, gripFrom = 0.113, gripTo = 0.263, gripThickness = 0.128, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 2.1125), Butt = Vector3.new(0.0000, 0.0000, -0.4875), Glow = Vector3.new(0.0000, 0.0000, 0.3510) } },
	["gs_g1"] = { length = 5.500, refScale = 1.000, tris = 3027, gripFrom = 0.113, gripTo = 0.275, gripThickness = 0.390, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2094), Butt = Vector3.new(0.0000, 0.0000, -1.2906), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.7769) } },
	["gs_g2"] = { length = 5.500, refScale = 1.000, tris = 2755, gripFrom = 0.062, gripTo = 0.237, gripThickness = 0.261, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.4500), Butt = Vector3.new(0.0000, 0.0000, -1.0500), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.8112) } },
	["gs_g3"] = { length = 5.500, refScale = 1.000, tris = 2904, gripFrom = 0.125, gripTo = 0.263, gripThickness = 0.323, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2094), Butt = Vector3.new(0.0000, 0.0000, -1.2906), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.7081) } },
	["gs_g4"] = { length = 5.500, refScale = 1.000, tris = 4999, gripFrom = 0.113, gripTo = 0.250, gripThickness = 0.315, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2781), Butt = Vector3.new(0.0000, 0.0000, -1.2219), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.7081) } },
	["gs_g5"] = { length = 5.500, refScale = 1.000, tris = 4999, gripFrom = 0.125, gripTo = 0.263, gripThickness = 0.363, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2094), Butt = Vector3.new(0.0000, 0.0000, -1.2906), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.7081) } },
	["gs_g6"] = { length = 5.500, refScale = 1.000, tris = 5000, gripFrom = 0.125, gripTo = 0.250, gripThickness = 0.286, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2438), Butt = Vector3.new(0.0000, 0.0000, -1.2562), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.6737) } },
	["gs_g7"] = { length = 5.500, refScale = 1.000, tris = 5000, gripFrom = 0.113, gripTo = 0.275, gripThickness = 0.298, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2094), Butt = Vector3.new(0.0000, 0.0000, -1.2906), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.7769) } },
	["gs_g8"] = { length = 5.500, refScale = 1.000, tris = 5000, gripFrom = 0.113, gripTo = 0.250, gripThickness = 0.283, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 0.0000, 4.2781), Butt = Vector3.new(0.0000, 0.0000, -1.2219), Support = Vector3.new(0.0000, 0.0000, -0.4500), Glow = Vector3.new(0.0000, 0.0000, 0.7081) } },
	["staff_g1"] = { length = 5.600, refScale = 1.000, tris = 3092, gripFrom = 0.362, gripTo = 0.613, gripThickness = 0.256, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 2.8700, 0.0000), Butt = Vector3.new(0.0000, -2.7300, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.3100, 0.0000) } },
	["staff_g2"] = { length = 5.600, refScale = 1.000, tris = 2951, gripFrom = 0.338, gripTo = 0.537, gripThickness = 0.258, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.1500, 0.0000), Butt = Vector3.new(0.0000, -2.4500, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.5900, 0.0000) } },
	["staff_g3"] = { length = 5.600, refScale = 1.000, tris = 2964, gripFrom = 0.250, gripTo = 0.650, gripThickness = 0.318, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.0800, 0.0000), Butt = Vector3.new(0.0000, -2.5200, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.5200, 0.0000) } },
	["staff_g4"] = { length = 5.600, refScale = 1.000, tris = 5000, gripFrom = 0.250, gripTo = 0.650, gripThickness = 0.320, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.0800, 0.0000), Butt = Vector3.new(0.0000, -2.5200, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.5200, 0.0000) } },
	["staff_g5"] = { length = 5.600, refScale = 1.000, tris = 5000, gripFrom = 0.263, gripTo = 0.650, gripThickness = 0.265, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.0450, 0.0000), Butt = Vector3.new(0.0000, -2.5550, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.4850, 0.0000) } },
	["staff_g6"] = { length = 5.600, refScale = 1.000, tris = 4999, gripFrom = 0.287, gripTo = 0.550, gripThickness = 0.330, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.2550, 0.0000), Butt = Vector3.new(0.0000, -2.3450, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.6950, 0.0000) } },
	["staff_g7"] = { length = 5.600, refScale = 1.000, tris = 4999, gripFrom = 0.338, gripTo = 0.537, gripThickness = 0.258, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.1500, 0.0000), Butt = Vector3.new(0.0000, -2.4500, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.5900, 0.0000) } },
	["staff_g8"] = { length = 5.600, refScale = 1.000, tris = 5000, gripFrom = 0.325, gripTo = 0.562, gripThickness = 0.347, attachments = { Grip = Vector3.new(0.0000, 0.0000, 0.0000), Tip = Vector3.new(0.0000, 3.1150, 0.0000), Butt = Vector3.new(0.0000, -2.4850, 0.0000), Support = Vector3.new(0.0000, 0.9000, 0.0000), Glow = Vector3.new(0.0000, 2.5550, 0.0000) } },
-- rows:end
}

function M.key(classId, gradeId, left)
	local kind, n = M.classKey[classId], M.gradeIndex[gradeId]
	if not kind or not n then
		return nil
	end
	return M.prefix .. kind .. "_g" .. n .. (left and M.mirrorSuffix or ""), kind .. "_g" .. n, n
end

return M
