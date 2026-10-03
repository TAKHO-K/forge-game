-- QUEUE-10h Q14 P4d 설정 저장(계정 - SAVE v54 profile.settings). 서버 = server/SettingsService.lua(검증 · 저장 · Player Attribute로 적용) · 창 = client/panels/Settings.
--   키마다 attrs = 적용할 Player Attribute(클라 코드는 전부 이 Attribute만 읽는다 - 저장 전과 같은 입구) · default · kind(boolean | preset | volume).
--   B4 사운드: kind volume(0 ~ 1 숫자) = 카테고리별 음량(SoundData.categories가 settingKey로 가리킨다 · 클라 SoundHooks가 Attribute로 읽는다). 저장은 같은 settings 표(없는 키 = 기본값 - 이관 없음).
--   reduceFlashes = 번개 · 태초 화면 섬광 끄기(관문 날씨 섬광 끔 · 피뢰침 방전은 흰 번쩍 대신 밝기만 · 태초 연출의 화면 밝아짐 없음 - 보스 경고 표시는 그대로).
return {
	order = { "cameraTopDown", "reduceFlashes", "screenShake", "dimOthersTrail", "autoStage", "volumeSfx", "volumeMusic", "volumeUi", "volumeBossCue", "transcendNotice", "fxLevel", "volumeAmbient", "muteSfx", "muteUi", "muteAmbient", "muteMusic", "windowPositions", "graphics", "language", "quietOthersSfx", "minimapOn", "minimapRotate", "minimapFar", "mapHintSeen", "hubIntroRank", "hubIntroBoard", "hubIntroChallenge", "hubIntroTailor", "bulkSellGrades", "sellHintSeen", "weekendBannerAt" },
	keys = {
		cameraTopDown = { kind = "boolean", default = false, attrs = { "CameraTopDown" } },
		reduceFlashes = { kind = "boolean", default = false, attrs = { "ReduceFlashes" } },
		screenShake = { kind = "boolean", default = true, attrs = { "SettingScreenShake", "SettingBossScreenShake" } },
		dimOthersTrail = { kind = "boolean", default = false, attrs = { "SettingDimOthers" } },
		quietOthersSfx = { kind = "boolean", default = false, attrs = { "QuietOthersSfx" } }, -- QUEUE-ALL7 C3 다른 플레이어 효과음 줄이기(켬 = 남 소리 × SoundMixData.otherQuietScale · 끔 = × otherScale) - 없는 키 = 기본값(이관 없음)
		-- QUEUE-ALL7 D3 · ALL7B 1: 미니맵 = 기본 꺼짐(지도 창 M의 토글 · 미니맵 톱니 메뉴) · 회전(내 방향이 위) · 멀리(반경 × 2) · 지도 창 첫 안내 본 적 있음 - 없는 키 = 기본값(이관 없음)
		minimapOn = { kind = "boolean", default = false, attrs = { "MinimapOn" } },
		minimapRotate = { kind = "boolean", default = false, attrs = { "MinimapRotate" } },
		minimapFar = { kind = "boolean", default = false, attrs = { "MinimapFar" } },
		mapHintSeen = { kind = "boolean", default = false, attrs = { "MapHintSeen" } },
		-- QUEUE-ALL7B 2: 마을 기능 지점 첫 소개 한 줄을 봄(HubServiceData.services[].intro - Attribute = HubIntroSeen_<서비스 id>) - 없는 키 = 기본값(이관 없음)
		hubIntroRank = { kind = "boolean", default = false, attrs = { "HubIntroSeen_hallOfFame" } },
		hubIntroBoard = { kind = "boolean", default = false, attrs = { "HubIntroSeen_noticeBoard" } },
		hubIntroChallenge = { kind = "boolean", default = false, attrs = { "HubIntroSeen_challengeKnight" } },
		hubIntroTailor = { kind = "boolean", default = false, attrs = { "HubIntroSeen_tailor" } },
		-- QUEUE-ALL8 G1: 가방 등급별 일괄 판매 체크(ArmorData.bulkSellGrades 조합 · 순서 = 등급 순 · 쉼표) - 없는 키 = 기본값(이관 없음)
		sellHintSeen = { kind = "boolean", default = false, attrs = { "SellHintSeen" } }, -- QUEUE-ALL8 G4 첫 판매 안내 본 적 있음(없는 키 = 기본값)
		weekendBannerAt = { kind = "stamp", default = 0, attrs = {} }, -- QUEUE-ALL9A 1-2 주말 패스 2배 배너를 본 창의 시작 시각(서버가 쓴다 · 없는 키 = 기본값 - 이관 없음)
		bulkSellGrades = { kind = "choice", default = "normal,rare", options = { "normal", "rare", "epic", "normal,rare", "normal,epic", "rare,epic", "normal,rare,epic" }, attrs = { "BulkSellGrades" } },
		autoStage = { kind = "preset", attrs = { "AutoStage" } }, -- 값 = AutoStageData.presets[].id · 기본 = AutoStageData.default
		volumeSfx = { kind = "volume", default = 1, attrs = { "SoundVolumeSfx" } }, -- B4 효과음
		volumeMusic = { kind = "volume", default = 1, attrs = { "SoundVolumeMusic" } }, -- B4 음악
		volumeUi = { kind = "volume", default = 1, attrs = { "SoundVolumeUi" } }, -- B4 UI
		volumeBossCue = { kind = "volume", default = 1, attrs = { "SoundVolumeBossCue" } }, -- B4 보스 전조
		-- QUEUE-ALL1 P3 §1: 다른 서버 초월 알림 = full(전체 - 풀 연출 조건이면 하늘 갈라짐까지) · banner(배너만) · off(끔 - 채팅 한 줄만) · kind choice(값 = options 중 하나)
		transcendNotice = { kind = "choice", default = "full", options = { "full", "banner", "off" }, attrs = { "TranscendNotice" } },
		-- QUEUE-ALL2 P2 B-4 ⑤ · 09 문서 B-2: 연출 세기 하나로 흔들림 · 번쩍임 · 남의 효과를 함께 줄인다(client/FxSettings가 옛 Attribute로 풀어 준다 - 흔들림 끔 = 옛 screenShake false와 같음)
		fxLevel = { kind = "choice", default = "normal", options = { "normal", "low", "off" }, attrs = { "FxLevel" } },
		volumeAmbient = { kind = "volume", default = 1, attrs = { "SoundVolumeAmbient" } }, -- QUEUE-ALL2 P5 환경음(SoundGroup Ambient)
		-- QUEUE-ALL9C 1-7 L4 그룹별 음소거(음량 값은 그대로 두고 0으로 - 풀면 원래 음량) · 없는 키 = 기본값(이관 없음)
		muteSfx = { kind = "boolean", default = false, attrs = { "SoundMuteSfx" } },
		muteUi = { kind = "boolean", default = false, attrs = { "SoundMuteUi" } },
		muteAmbient = { kind = "boolean", default = false, attrs = { "SoundMuteAmbient" } },
		muteMusic = { kind = "boolean", default = false, attrs = { "SoundMuteMusic" } },
		-- QUEUE-ALL9C 1-8 창 위치(PC · 태블릿): "id:x,y;id:x,y"(화면 가운데 기준 픽셀 · client/ui/WindowPositions) · 빈 글 = 전부 기본 자리 · 없는 키 = 기본값(이관 없음)
		windowPositions = { kind = "positions", default = "", attrs = { "WindowPositions" } },
		-- 가벼움 = 먼 산 LOD · 나무 바람 · 풀 덤불 끔(게임 쪽 부담만 - 로블록스 품질 설정은 그대로). QUEUE-ALL6 A2: 기본 "auto"(안 고름 - 저장 안 됨) = 클라 GraphicsMode가 기기로 판별(graphicsAuto).
		--   고를 수 있는 값은 options(normal · lite)뿐 - 설정 창에서 바꾸면 그 값이 저장되고 이후 유지.
		graphics = { kind = "choice", default = "auto", options = { "normal", "lite" }, attrs = { "GraphicsMode" } },
		-- QUEUE-ALL4 E 화면 언어(shared/Text가 읽는다): ko(기본 - 영어 켜기는 사용자 결정 전까지 꺼짐) · en(강제) · auto(로블록스 계정 언어 - 한국어면 ko, 아니면 en).
		--   설정 창 줄은 아직 없다(바꾸는 곳 = 개발 /gg lang). 같은 settings 표 - 없는 키 = 기본값(이관 없음).
		language = { kind = "choice", default = "ko", options = { "ko", "en", "auto" }, attrs = { "Language" } },
	},
	-- QUEUE-ALL6 A2 첫 접속 기본 그래픽(아직 안 고른 사람): 폰(터치 전용) · 로블록스 품질을 1 ~ 3으로 직접 낮춘 기기 = lite, 그 밖(PC) = normal
	graphicsAuto = { liteWhenTouchOnly = true, liteAtSavedQualityAtMost = 3 },
	volumeStep = 0.1, -- B4 설정 창 [−] [+] 한 번에 바뀌는 양
}
