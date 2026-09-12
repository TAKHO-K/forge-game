-- 스킬 슬롯(Q/E) 아이콘 에셋 매핑(19-2 [5]). 기능은 아직 안 붙는다 - HUD 표시 전용.
-- Studio에 업로드 완료된 8개 rbxassetid를 여기 한 곳에만 둔다 - SkillSlots.client.lua는
-- 이 테이블만 읽는다(나중에 아이콘을 다시 그려 교체할 때 이 파일만 고치면 된다).

return {
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
