-- QUEUE-10h Q14 P4d 설정 저장(계정 - SAVE v54 profile.settings). 서버 = server/SettingsService.lua(검증 · 저장 · Player Attribute로 적용) · 창 = client/panels/Settings.
--   키마다 attrs = 적용할 Player Attribute(클라 코드는 전부 이 Attribute만 읽는다 - 저장 전과 같은 입구) · default · kind(boolean | preset).
--   reduceFlashes = 번개 · 태초 화면 섬광 끄기(관문 날씨 섬광 끔 · 피뢰침 방전은 흰 번쩍 대신 밝기만 · 태초 연출의 화면 밝아짐 없음 - 보스 경고 표시는 그대로).
return {
	order = { "cameraTopDown", "reduceFlashes", "screenShake", "dimOthersTrail", "autoStage" },
	keys = {
		cameraTopDown = { kind = "boolean", default = false, attrs = { "CameraTopDown" } },
		reduceFlashes = { kind = "boolean", default = false, attrs = { "ReduceFlashes" } },
		screenShake = { kind = "boolean", default = true, attrs = { "SettingScreenShake", "SettingBossScreenShake" } },
		dimOthersTrail = { kind = "boolean", default = false, attrs = { "SettingDimOthers" } },
		autoStage = { kind = "preset", attrs = { "AutoStage" } }, -- 값 = AutoStageData.presets[].id · 기본 = AutoStageData.default
	},
}
