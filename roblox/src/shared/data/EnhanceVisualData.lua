-- 강화 단계 → 무기 겉모습(이펙트) · 사거리 보너스 표(30-0 S08, PRD 20.72 [1-9]). 이펙트는 **단계의 함수**다 - 저장하지 않고, 단계가 내려가면 그 단계의 모습으로 돌아간다.
-- 에셋 동결 전제: 파트 · 색 · 로블록스 기본 인스턴스(PointLight · Trail · ParticleEmitter 기본 텍스처 · Highlight)만 쓴다. 색은 전부 UIColors의 **키 이름**이다(Color3 리터럴 0).
-- 에셋 단계(PRD 20.81 [E] 4번)에서 여러 색 · 더 화려한 모습으로 갈아 끼울 때는 이 표만 바꾼다 - 코드(client/WeaponEnhanceVisual.lua · shared/EnhanceEffect.lua)는 그대로다.
--
-- steps: 임계 단계마다 "무엇이 추가/변경되는가"(누적). 단계 L의 모습 = level ≤ L인 모든 step을 앞에서부터 겹친 것(EnhanceEffect.resolveVisual). 같은 필드는 나중 step이 덮어쓴다(light · particle ·
-- highlight는 필드 단위로 덮는다: +10의 light = { range = 8 }은 +5의 색 · 밝기를 그대로 두고 범위만 바꾼다).
--   light          PointLight { color, brightness, range, pulse = { min, max, periodSeconds } }
--   particle       ParticleEmitter(기본 텍스처) { color, colorTo(있으면 수명 동안 color → colorTo), rate }
--   highlight      Highlight { color(외곽선), fillTransparency }
--   trailWidthScale  근접 Trail 폭 배율(활 · 지팡이는 Trail이 없어 빛만 바뀐다)
--   trailColor     Trail 색
--   tint           무기 몸체 파트 색을 color 쪽으로 alpha만큼 보간
--   rainbow        true면 빛 · 파티클 · 외곽선 · Trail(있는 것만)의 색이 무지개로 순환한다(rainbow.cycleSeconds)
--   title          머리 위 칭호 { text, textSize, studsOffsetY }
--   pillarSeconds  이 단계에 **도달하는 순간**의 빛기둥 지속 시간(반짝이 몬스터 기둥 재사용 - RareMonsterConfig의 굵기 · 높이)
-- 사거리(rangeBonusByLevel)는 게임플레이 값이지만 이 파일이 출처다(PRD 20.72 [1-9]): 단계 임계마다 직업별 비율이 **합산**된다(+20의 활 = +0.30 + 0.30 = +60%).
return {
	steps = {
		{ level = 5, light = { color = "textPrimary", brightness = 0.6, range = 6 } },
		{ level = 10, light = { range = 8 }, trailWidthScale = 1.25 },
		{ level = 15, light = { color = "gold" }, tint = { color = "gold", alpha = 0.25 } },
		{ level = 19, particle = { color = "gold", rate = 6 } },
		{ level = 20, light = { color = "ember", pulse = { min = 0.8, max = 1.4, periodSeconds = 1.5 } } },
		{ level = 21, particle = { color = "ember", rate = 12 } },
		{ level = 22, highlight = { color = "ember", fillTransparency = 1 } },
		{ level = 23, particle = { colorTo = "danger", rate = 18 } },
		{ level = 24, light = { color = "danger", range = 12 }, trailColor = "danger" },
		{ level = 25, rainbow = true, title = { text = "+25", textSize = 22, studsOffsetY = 3.2 }, pillarSeconds = 3 },
	},

	-- 무지개 한 바퀴(초). 반짝이 몬스터의 hue 순환(client/SparkleMonsterVisual)과 같은 속도다 - "태초 rainbow와 같은 hue 회전"의 hue 순환 쪽(PRD 20.72 [1-9]).
	rainbow = { cycleSeconds = 2 },

	-- 파티클의 생김새(기본 텍스처). rate · 색은 steps가 정한다. zOffset은 음수 = 무기 뒤(보석 홈을 덮지 않게 - PRD 20.81 [E] 4번).
	particleStyle = {
		lifetime = { min = 0.6, max = 1.0 },
		speed = { min = 0.5, max = 1.5 },
		size = 0.35,
		transparencyStart = 0.1,
		lightEmission = 1,
		zOffset = -1,
	},

	rangeBonusByLevel = {
		[15] = { bow = 0.30, greatsword = 0.10, dualblade = 0.10, healer = 0.20 },
		[20] = { bow = 0.30, greatsword = 0.10, dualblade = 0.10, healer = 0.20 },
	},
}
