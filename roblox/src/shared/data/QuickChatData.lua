-- UI-1 7c 파티 빠른 말(F v2.1 · H §5): 정해진 말 8 + 이모트 4 · 자유 입력 없음(아이 채팅 제한) · 말풍선 = 그 사람 머리 위 3초 · 같은 말 3번 연속 = 5초 쉬기.
--   글 = TextData(ui1.qc.<n> · ko + en) · 이모트 그림 = ArtAssetIds(ui/party/emote-*) · 받는 사람 = 같은 파티(파티 없음 = 나만) · 규칙 = shared/QuickChatRules.
return {
	phrases = { "ui1.qc.1", "ui1.qc.2", "ui1.qc.3", "ui1.qc.4", "ui1.qc.5", "ui1.qc.6", "ui1.qc.7", "ui1.qc.8" },
	emotes = {
		{ id = "wave", image = "ui/party/emote-wave", label = "ui1.qc.emote.wave" },
		{ id = "thumb", image = "ui/party/emote-thumb", label = "ui1.qc.emote.thumb" },
		{ id = "heart", image = "ui/party/emote-heart", label = "ui1.qc.emote.heart" },
		{ id = "laugh", image = "ui/party/emote-laugh", label = "ui1.qc.emote.laugh" },
	},
	bubbleSeconds = 3,
	repeatLimit = 3, -- 같은 말(종류 + 번호)을 이만큼 연속으로 보내면
	repeatPause = 5, -- 이만큼 쉬기(초)
	minGap = 0.4, -- 아무 말이든 최소 간격(초)
}
