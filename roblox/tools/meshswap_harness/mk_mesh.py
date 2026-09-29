# MeshSwap 하네스 조립: 실제 모듈 소스를 sources.<이름>으로 감싸 한 파일로
import sys, os
SRC = r"C:\Users\xkrgh\vibe\game\roblox\src"
mods = {
    "MeshImportCheckData": "shared/data/MeshImportCheckData.lua",
    "MonsterRigSpec": "shared/data/MonsterRigSpec.lua",
    "BossRigSpec": "shared/data/BossRigSpec.lua",
    "MeshImportCheck": "shared/MeshImportCheck.lua",
    "MeshSwap": "shared/MeshSwap.lua",
}
here = os.path.dirname(os.path.abspath(__file__))
out = [open(os.path.join(here, "mesh_prelude.luau"), encoding="utf-8").read()]
for name, rel in mods.items():
    src = open(os.path.join(SRC, rel), encoding="utf-8").read()
    out.append(f"sources.{name} = function()\n{src}\nend\n")
out.append(open(os.path.join(here, sys.argv[1]), encoding="utf-8").read())
open(os.path.join(here, "mesh_run.luau"), "w", encoding="utf-8").write("\n".join(out))
