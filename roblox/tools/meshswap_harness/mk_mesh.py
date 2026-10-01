# A2-N2 3절 MeshSwap 하네스 조립: 실제 모듈 소스를 sources.<이름>으로 감싸 한 파일로(Play 없이 메타 정렬 · 회전 파트 관절 검사).
# 사용: python mk_mesh.py test_mesh.luau && luau mesh_run.luau  (luau.exe = github.com/luau-lang/luau 릴리스 - 저장소에 두지 않는다)
#   test_mesh.luau 첫 줄 REALMETA = roblox/art/monsters/*.meta.json 값(메타가 바뀌면 다시 뽑는다).
import sys, os
SRC = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src"))
mods = {
    "MeshImportCheckData": "shared/data/MeshImportCheckData.lua",
    "MonsterRigSpec": "shared/data/MonsterRigSpec.lua",
    "BossRigSpec": "shared/data/BossRigSpec.lua",
    "BossDetailSpec": "shared/data/BossDetailSpec.lua",  # QUEUE-ALL4 G: BossRigSpec 의존(A2-M1)
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
