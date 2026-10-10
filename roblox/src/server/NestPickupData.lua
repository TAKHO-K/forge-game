-- SEC-FIX-1 4b: 둥지 줍기 서버 검증 기준(서버 전용 - 옛 = shared/data/NestData.pickup). 쓰는 곳 = server/NestServer.
-- 줍기 서버 검증(M1-2c 위치 기록 + 둥지 전용 궤적): ① 최근 presentSeconds 동안의 서버 표본(발사 허가 위치 기록)이 전부 둥지 반경 radius · 높이 dyMin ~ dyMax 안이고 minSamples장 이상
--   ② 둥지 전용 궤적(trailHz로 trailSeconds 보관 - 발사 허가 기록은 0.6초뿐이라 "순간이동 → 0.6초 기다림"이 뚫렸다: M1-3 리뷰)에 초속 maxSpeedStuds를 넘는 이동이 없다(순간이동 · 속도 핵 차단 -
--   걷기 상한 24 · 대시 53 · 나무 점프대 약 120보다 넉넉히).
return { radius = 9, promptDistance = 8, presentSeconds = 0.25, minSamples = 3, dyMin = -4, dyMax = 8, trailSeconds = 3, trailHz = 10, maxSpeedStuds = 160, requestGapSeconds = 0.5 }
