-- 생성 파일(roblox/tools/blender/make_tree.py) - 손으로 고치지 않는다. QUEUE-ALL8 H 큰 나무 겉모습 메시 표(키 = props/<이름> · bounds = w, h, d · parts = 조각 색 · tris = 삼각형).
return {
	tree_branch = { bounds = { 1.03, 0.951, 0.96 }, budget = 200, parts = { Bark = { rgb = { 142, 90, 60 } }, Rings = { rgb = { 166, 110, 74 } } }, tris = 156 },
	tree_deck = { bounds = { 34, 5, 42 }, budget = 300, parts = { Deck = { rgb = { 176, 124, 78 } }, Lines = { rgb = { 126, 84, 52 } }, Rail = { rgb = { 126, 84, 52 } } }, tris = 148 },
	tree_root = { bounds = { 125, 29.5, 22 }, budget = 400, parts = { Bark = { rgb = { 110, 68, 46 } } }, tris = 172 },
	tree_stem = { bounds = { 1, 1.06, 1 }, budget = 200, parts = { Bark = { rgb = { 110, 68, 46 } } }, tris = 108 },
	tree_trunk_base = { bounds = { 149.507, 34, 132.111 }, budget = 2000, parts = { Bark = { rgb = { 142, 90, 60 } }, Hole = { rgb = { 58, 36, 26 } }, Moss = { rgb = { 104, 156, 74 } }, MushCap = { rgb = { 222, 86, 70 } }, MushStem = { rgb = { 240, 228, 206 } } }, tris = 1236 },
	tree_trunk_section = { bounds = { 2, 1, 2 }, budget = 600, parts = { Bark = { rgb = { 166, 110, 74 } } }, tris = 388 },
}
