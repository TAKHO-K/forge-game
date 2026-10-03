# 메인 메뉴 배경(키 아트) 교체 절차 - QUEUE-ALL9C 2-3

1. 그림 파일 하나를 `roblox/art/ui/<새 이름>.png`에 넣고 `python roblox/tools/opencloud/menu_bg.py roblox/art/ui/<새 이름>.png` 한 줄 → 가로 1024 초과면 좌우 2장(가운데 4px 겹침)으로 나눠 upload.py가 올리고 asset-ids.json · ArtAssetIds에 기록.
2. 이미지 id는 Studio Edit에서 `InsertService:LoadAsset(<Decal id>)` → `Decal.Texture`를 읽어 `upload.py --images <json>`으로 기록 → `menu_bg.py --gen <새 이름>`이 `roblox/src/first/MenuBootData.lua`의 BEGIN/END 사이를 다시 쓴다(심사 통과 전이면 빈 배경 = 하늘 그라데이션).
3. 옛 그림으로 되돌리기 = `menu_bg.py --gen <옛 이름>`(파일 · 기록은 그림마다 따로 남는다) · 세로 기준점 `focusY` · 어두운 띠 `shadeKeys` = MenuBootData · 메뉴 자리(왼쪽 35%) 확인 = `python roblox/tools/blender/menu_safe_zone.py` → `docs/art/ref/menu-safe-zone.png`.
