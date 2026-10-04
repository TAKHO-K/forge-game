-- QUEUE-MENU2 F(방향 변경 · 사용자 10-04 밤): 직업 선택 화면 = 2D 전설 일러스트만. 그리는 곳 = client/ui/LegendPlayer(재생기 자리) · 연결 = ClassSelectUI.
--   그림 · 움직임은 설계 담당이 넘긴다: 투명 PNG(직업별 대기 포즈 · 액션 포즈) = roblox/art/ui/legends/ · 움직임 JSON = roblox/art/ui/legends/legend_anim.json(형식은 넘길 때 같이).
--   받으면: PNG → upload.py → 이미지 id를 classes[직업].idle / action에 · JSON → anim에 옮긴다(재생기 = 데이터만 읽어 TweenService로 실행). 지금은 임시 실루엣 + temp 값.
return {
	-- 스위치(삭제 대신 끔 - 코드 · 에셋 · 데이터 id 그대로 · 되살리기 = true)
	avatarPreview = false, -- ClassSelectAvatarPreview: 내 로블록스 아바타 미리보기(ViewportFrame) - 사용 안 함
	transform = false, -- ClassSelectTransform: 변신 연출(ALL9C 전용 캐릭터 ClassStage 변신 포함) - 사용 안 함

	artFolder = "roblox/art/ui/legends/",
	animFile = "roblox/art/ui/legends/legend_anim.json",
	-- 직업별 그림(이미지 id - 없으면 임시 실루엣)
	classes = {
		greatsword = { idle = nil, action = nil },
		dualblade = { idle = nil, action = nil },
		bow = { idle = nil, action = nil },
		healer = { idle = nil, action = nil },
	},
	-- 움직임 데이터(legend_anim.json을 옮길 자리 - nil = 아래 temp만). 재생기가 읽는 꼴(받은 형식에 맞춰 LegendPlayer 한 곳만 고친다):
	--   anim = { states = { idle = { tracks = { { part = "figure"|"weapon"|"glow"|"sparkle", prop = "Size"|"Position"|"Rotation"|"ImageTransparency", to = 값, seconds, easing, direction, repeats, reverses, delay } } }, select = {...}, confirm = {...} } }
	anim = nil,
	-- 임시 연출(그림 · 움직임이 오기 전): 고를 때 앞으로 살짝(크기) · 확정 섬광 → 액션 포즈 유지 → 진입
	temp = { selectScale = 1.04, selectSeconds = 0.2, flashSeconds = 0.15, actionHoldSeconds = 0.6 },
}
