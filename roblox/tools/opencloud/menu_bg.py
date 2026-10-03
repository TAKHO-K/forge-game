"""QUEUE-ALL9C 2-3 메인 메뉴 배경(키 아트 한 장) 교체 - 시스템 python + Pillow(설치 없음) + 같은 폴더 upload.py.

사용: python roblox/tools/opencloud/menu_bg.py roblox/art/ui/<이름>.png   # 나누기 → 업로드 → (이미지 id가 있으면) MenuBootData 쓰기
      python roblox/tools/opencloud/menu_bg.py --gen <이름>               # 이미지 id를 기록한 뒤(upload.py --images) MenuBootData만 다시 쓰기
  · 로블록스 이미지는 한 변 최대 1024px로 줄어든다 → 가로가 1024보다 크면 좌우 2장(각 1024 이하)으로 나눈다.
    이음매: 두 장이 가운데 OVERLAP px씩 같은 픽셀을 겹쳐 가져가고, 화면에서도 같은 자리에 겹쳐 놓는다(틈 · 반 픽셀 줄 없음).
    세로가 1024보다 크거나 반쪽이 1024보다 넓으면 비율을 지켜 줄인다.
  · 결과 = roblox/art/ui/<이름>_L.png · <이름>_R.png(한 장이면 <이름>_part.png) + <이름>.meta.json → upload.py(Decal) → asset-ids.json.
    그림마다 다른 이름(키)이라 옛 그림 기록 · 파일은 그대로 남는다(되돌리기 = --gen <옛 이름>).
  · Decal의 이미지 id는 Studio에서 읽는다(InsertService:LoadAsset(decal).Decal.Texture → upload.py --images) - 그 뒤 --gen.
  · 모든 장이 심사 통과(Approved)일 때만 쓴다 - 아니면 빈 parts(가림막 = 하늘 그라데이션만)로 쓰고 알린다(--refresh 뒤 다시 --gen).
  · 쓰는 곳 = roblox/src/first/MenuBootData.lua의 "-- BEGIN menu_bg.py" ~ "-- END menu_bg.py" 사이(가림막이 접속 즉시 불러와 서서히 표시 · 화면 꽉 채움).
"""
import json
import os
import re
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))  # roblox/
ART = os.path.join(ROOT, "art")
IDS = os.path.join(ART, "asset-ids.json")
BOOT = os.path.join(ROOT, "src", "first", "MenuBootData.lua")
MAX_SIDE = 1024
OVERLAP = 2  # 가운데에서 두 장이 함께 가지는 픽셀 열(한쪽마다)


def meta_path(stem):
    return os.path.join(ART, "ui", stem + ".meta.json")


def split(src):
    stem = os.path.splitext(os.path.basename(src))[0]
    im = Image.open(src).convert("RGB")
    w, h = im.size
    parts_count = 1 if w <= MAX_SIDE else 2
    scale = min(1.0, MAX_SIDE / h, (MAX_SIDE * parts_count - 2 * OVERLAP * (parts_count - 1)) / w)
    if scale < 1.0:
        w, h = max(1, round(w * scale)), max(1, round(h * scale))
        im = im.resize((w, h), Image.LANCZOS)
    if parts_count == 1:
        ranges = [("_part", 0, w)]
    else:
        half = w // 2
        ranges = [("_L", 0, min(w, half + OVERLAP)), ("_R", max(0, half - OVERLAP), w)]
    parts = []
    for suffix, x0, x1 in ranges:
        rel = "ui/%s%s.png" % (stem, suffix)
        im.crop((x0, 0, x1, h)).save(os.path.join(ART, rel), optimize=True)
        parts.append({"file": rel, "x0": x0, "x1": x1})
        print("O %s %dx%d (x %d ~ %d)" % (rel, x1 - x0, h, x0, x1))
    with open(meta_path(stem), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"source": os.path.basename(src), "width": w, "height": h, "parts": parts}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return stem, [p["file"] for p in parts]


def write_block(width, height, lines, note):
    block = "\t-- BEGIN menu_bg.py(생성 - 손으로 고치지 않는다 · %s)\n\tbackground = {\n\t\twidth = %d,\n\t\theight = %d,\n\t\tparts = {\n%s\t\t},\n\t},\n\t-- END menu_bg.py\n" % (
        note, width, height, "".join(l + "\n" for l in lines))
    text = open(BOOT, encoding="utf-8").read()
    new, n = re.subn(r"\t-- BEGIN menu_bg\.py.*?-- END menu_bg\.py\n", lambda _: block, text, flags=re.S)
    if n != 1:
        print("MenuBootData.lua에 BEGIN/END menu_bg.py 자리가 없음")
        return 1
    with open(BOOT, "w", encoding="utf-8", newline="\n") as f:
        f.write(new)
    return 0


def gen(stem):
    meta = json.load(open(meta_path(stem), encoding="utf-8"))
    ids = json.load(open(IDS, encoding="utf-8"))
    lines, missing, pending = [], [], []
    for p in meta["parts"]:
        e = ids.get(p["file"]) or {}
        if not e.get("imageId"):
            missing.append(p["file"])
        elif e.get("status") != "Approved":
            pending.append("%s(%s)" % (p["file"], e.get("status")))
        else:
            lines.append('\t\t\t{ image = "rbxassetid://%d", x0 = %d, x1 = %d },' % (e["imageId"], p["x0"], p["x1"]))
    if missing:
        print("이미지 id 없음(Studio LoadAsset → upload.py --images 뒤 --gen %s): %s" % (stem, ", ".join(missing)))
        return 1
    if pending:
        print("심사 미통과 - 빈 배경(하늘 그라데이션)으로 씀 · upload.py --refresh 뒤 다시 --gen: " + ", ".join(pending))
        return write_block(0, 0, [], meta["source"] + " 심사 대기")
    r = write_block(meta["width"], meta["height"], lines, meta["source"])
    if r == 0:
        print("O MenuBootData.lua background = %s %d장 · %dx%d" % (meta["source"], len(lines), meta["width"], meta["height"]))
    return r


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--gen":
        return gen(args[1])
    if len(args) != 1 or args[0].startswith("--"):
        print(__doc__)
        return 1
    stem, files = split(args[0])
    r = subprocess.run([sys.executable, os.path.join(HERE, "upload.py")] + files)
    if r.returncode != 0:
        return r.returncode
    return gen(stem)


if __name__ == "__main__":
    sys.exit(main())
