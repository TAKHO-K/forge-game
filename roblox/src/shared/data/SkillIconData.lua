-- 스킬 슬롯(Q/E) 아이콘 에셋 매핑(19-2 [5]). 기능은 아직 안 붙는다 - HUD 표시 전용.
-- Studio에 업로드 완료된 8개 rbxassetid를 여기 한 곳에만 둔다 - SkillSlots.client.lua는
-- 이 테이블만 읽는다(나중에 아이콘을 다시 그려 교체할 때 이 파일만 고치면 된다).

-- QUEUE-ALL3 Q9: 새 아이콘(레퍼런스 스타일 · 직업색 3톤 · 굵은 외곽선 - roblox/tools/icons/make_ui_icons_v2.py → upload.py Decal)
--   images[슬롯] = roblox/art 경로(ArtAssetIds 이미지 id - 클라 ArtImage.get) · 없으면 옛 rbxassetid(q · e) 그대로.
--   short[직업][슬롯] = 정보 카드 한 줄(40자 이하 · 한 문장 한 행동) · unlockRebirth[슬롯] = 그 칸이 열리는 환생 횟수(지금 규칙 = 전부 0 · Q · E · R · T 처음부터 열림 -
--   docs/design/ftue-attendance-q12.md 3번 "잠긴 칸 2개는 미래 자리" · 10 문서 "잠금 규칙 데이터는 그대로") - 값이 생기면 잠긴 칸 = 회색 + 자물쇠 + "환생 n" · 해금 순간 연출.
local SLOTS = { "q", "e", "r", "t", "dash" }
local images = {}
for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
	images[classId] = {}
	for _, slot in ipairs(SLOTS) do
		images[classId][slot] = slot == "dash" and ("icons/skills/dash_" .. classId) or ("icons/skills/" .. classId .. "_" .. slot)
	end
end

return {
	images = images,
	unlockRebirth = { q = 0, e = 0, r = 0, t = 0, dash = 0 },
	short = {
		greatsword = { q = "앞으로 돌진하며 길 위의 적을 모두 베요", e = "제자리에서 돌며 주변 적을 여러 번 베요", r = "주변 적을 끌어오고 파티 공격력을 올려요", t = "잠시 거대해져 모든 공격이 강해져요", dash = "빠르게 짧은 거리를 이동해요" },
		dualblade = { q = "분신을 남겨 시선을 끌고 확정 치명을 얻어요", e = "한 대상을 아주 빠르게 여러 번 베요", r = "대상 뒤로 이동해 치명 확률을 올려요", t = "표식을 새겨 모은 피해를 한 번에 터뜨려요", dash = "빠르게 짧은 거리를 이동해요" },
		bow = { q = "깊게 당겨 관통하는 큰 화살을 쏴요", e = "뒤로 물러나며 다음 화살을 강화해요", r = "덫을 놓아 몬스터를 묶고 피해를 줘요", t = "고른 곳에 화살비를 쏟아부어요", dash = "빠르게 짧은 거리를 이동해요" },
		healer = { q = "나와 파티원의 체력을 회복해요", e = "켜면 평타가 강해지고 체력이 줄어요", r = "주변 파티를 크게 회복하고 되살려요", t = "성역 안의 파티를 계속 지켜 줘요", dash = "빠르게 짧은 거리를 이동해요" },
	},
	greatsword = {
		q = "rbxassetid://72161143839174",
		e = "rbxassetid://111909793732983",
	},
	dualblade = {
		q = "rbxassetid://71418656247570",
		e = "rbxassetid://123889161585485",
	},
	bow = {
		q = "rbxassetid://92066543264846",
		e = "rbxassetid://101933602047602",
	},
	healer = {
		q = "rbxassetid://125956537626044",
		e = "rbxassetid://118394912051290",
	},
}
