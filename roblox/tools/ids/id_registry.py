# QUEUE-ALL5 A3 출시 뒤 id 삭제 금지 검사.
#   지금 데이터의 저장 id(shared/IdRegistry.lists - 옵션 · 재료 · 장비 등급/부위/세트 구역/직업옵션/초월 특수 · 치장 · 칭호)를
#   스냅숏(id_registry_snapshot.json - 지금까지 출시된 id 전부)과 비교한다. 스냅숏에 있는데 데이터에서 사라진 id = 실패(exit 1).
#   사용:
#     python roblox/tools/ids/id_registry.py           # 검사(커밋 전 · 회귀)
#     python roblox/tools/ids/id_registry.py --write   # 새 id를 스냅숏에 더하고 docs/design/id-registry.md를 다시 씀(지우지는 않는다)
#   luau.exe = 환경 변수 LUAU(없으면 harness/luau/luau.exe).
import io, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
HARNESS = os.path.join(HERE, "..", "harness")
SNAP = os.path.join(HERE, "id_registry_snapshot.json")
DOC = os.path.join(ROOT, "docs", "design", "id-registry.md")
KIND_KO = {
    "option": ("옵션", "item.option.id · gem.option.id", "OptionData.options"),
    "material": ("재료", "materials 키", "EnhanceMaterialData.order"),
    "grade": ("장비 등급", "item.grade", "ArmorData.gradeOrder"),
    "part": ("장비 부위", "item.part · equipment 키", "SetData.parts"),
    "setZone": ("세트 구역", "item.setZone", "WorldMapData.zones[].key"),
    "skillVariant": ("직업옵션", "item.skillVariant.id", "SkillVariantData.templates"),
    "special": ("초월 특수", "item.special", "TranscendentData.specialNames"),
    "cosmeticTheme": ("치장 테마", "cosmetics.themes 키 · equipped 값", "CosmeticSlotData.sets[].id"),
    "gliderSkin": ("글라이더", "cosmetics.gliderSkins 키 · equipped.gliderSkin", "CosmeticSlotData.gliderSkins[].id"),
    "title": ("칭호", "titles 키 · codex.title", "TitleData.titles(+ CodexRules 줄 칭호)"),
}


def current_ids():
    env = dict(os.environ, PRELUDE="server_prelude.luau", ECON_RES="res_ids.txt", ECON_OUT="out_ids.luau")
    res = subprocess.run([sys.executable, "build_run.py", "id_registry_dump.luau"], cwd=HARNESS, env=env, capture_output=True, text=True)
    out = io.open(os.path.join(tempfile.gettempdir(), "res_ids.txt"), encoding="utf-8").read()
    if "IDS-END" not in out:
        print(res.stdout, res.stderr, out[-2000:])
        sys.exit(2)
    ids = {}
    for line in out.splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3 and parts[0] == "IDS":
            ids.setdefault(parts[1], set()).add(parts[2])
    return ids


def write_doc(snap, now):
    lines = [
        "# 저장 id 등록부 (출시 뒤 삭제 금지 · QUEUE-ALL5 A3)",
        "",
        "> 자동 생성 = `python roblox/tools/ids/id_registry.py --write`(직접 고치지 않는다). 원본 = `roblox/tools/ids/id_registry_snapshot.json`.",
        "",
        "## 규칙",
        "- 아래 id는 **출시 뒤 데이터에서 지우거나 이름을 바꾸지 않는다.** 안 쓰게 된 것은 드랍 · 판매 · 표시에서만 빼고 데이터 항목은 남긴다.",
        "- 이름을 꼭 바꿔야 하면 새 id를 더하고 SAVE_VERSION을 올려 migrate()에서 옛 id → 새 id로 옮긴다(옛 id 항목도 남긴다).",
        "- 검사: `python roblox/tools/ids/id_registry.py`(사라진 id = 실패). 새 id를 더한 커밋은 `--write`로 등록부를 늘린다.",
        "- 그래도 모르는 id가 저장에 남으면(되돌린 데이터 · 실수) 로드는 실패하지 않고 그 값만 보관 칸 `profile.quarantine`으로 간다(`SaveSystem.quarantineUnknownIds` · 로그 `[SaveSystem] 모르는 id 보관` · 통계 `SaveQuarantined`). 같은 id가 데이터에 다시 생기면 다음 접속 때 제자리로 돌아온다(착용 장비 · 박힌 보석은 가방 · 보석 가방으로).",
        "- 세트 구역(setZone)은 모르면 \"세트 아님\"으로 동작해 보관하지 않는다(삭제 금지 검사만).",
        "",
        "## 종류별 id (" + now + " 기준)",
        "",
        "| 종류 | 저장 자리 | 데이터 | 개수 | id |",
        "|---|---|---|---|---|",
    ]
    for kind in KIND_KO:
        ko, where, data = KIND_KO[kind]
        ids = sorted(snap.get(kind, []))
        lines.append("| %s(`%s`) | %s | `%s` | %d | %s |" % (ko, kind, where, data, len(ids), " · ".join("`%s`" % i for i in ids)))
    lines.append("")
    io.open(DOC, "w", encoding="utf-8", newline="\n").write("\n".join(lines))


def main():
    cur = current_ids()
    snap = {}
    if os.path.exists(SNAP):
        snap = {k: set(v) for k, v in json.load(io.open(SNAP, encoding="utf-8")).items()}
    missing = []
    for kind, ids in snap.items():
        for i in sorted(ids - cur.get(kind, set())):
            missing.append("%s:%s" % (kind, i))
    added = []
    for kind, ids in cur.items():
        for i in sorted(ids - snap.get(kind, set())):
            added.append("%s:%s" % (kind, i))
    print("지금 id %d · 등록부 %d · 새 id %d · 사라진 id %d" % (sum(len(v) for v in cur.values()), sum(len(v) for v in snap.values()), len(added), len(missing)))
    if missing:
        print("사라진 id(삭제 금지 위반): " + ", ".join(missing))
    if "--write" in sys.argv:
        for kind, ids in cur.items():
            snap.setdefault(kind, set()).update(ids)
        json.dump({k: sorted(v) for k, v in sorted(snap.items())}, io.open(SNAP, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
        import datetime
        write_doc(snap, datetime.date.today().isoformat())
        print("등록부 갱신: " + (", ".join(added) if added else "새 id 없음"))
    elif added:
        print("등록부에 없는 새 id(커밋 전에 --write): " + ", ".join(added))
    print("결과: " + ("실패" if missing else "통과"))
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
