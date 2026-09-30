"""A2-N3 Open Cloud 에셋 일괄 업로드 (표준 라이브러리만).

사용: python roblox/tools/opencloud/upload.py [--dry] <roblox/art 기준 경로 또는 글롭>...
  예) python roblox/tools/opencloud/upload.py weapons/greatsword_legendary.fbx icons/weapons/greatsword_legendary.png
      python roblox/tools/opencloud/upload.py "monsters/*.fbx"
  .fbx → assetType Model · .png → Decal. 결과 = roblox/art/asset-ids.json(경로 · 해시 · assetId · 상태)
  + roblox/src/shared/data/ArtAssetIds.lua(코드가 읽는 표 - gen_lua()가 매번 전부 다시 쓴다).
  --images <json> = Decal의 이미지 id 기록(Studio LoadAsset로 읽은 값) · --refresh = 심사 대기 상태 다시 읽기 · --gen = 표만 다시 쓰기.
  같은 해시 = 건너뜀(재개 가능) · 해시가 바뀐 Model = 같은 assetId에 새 버전(PATCH) · 429 · 5xx = 지수 백오프.

보안: API 키는 환경 변수 ROBLOX_ASSETS_KEY(없으면 Windows 사용자 환경 변수)에서만 읽고 x-api-key 헤더에만 쓴다.
  키 · 요청 헤더는 어디에도 출력하지 않는다(오류는 상태 코드 + 응답 본문만).
"""
import glob
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))  # roblox/
ART = os.path.join(ROOT, "art")
IDS = os.path.join(ART, "asset-ids.json")
LUA = os.path.join(ROOT, "src", "shared", "data", "ArtAssetIds.lua")
API = "https://apis.roblox.com/assets/v1"
CREATOR_USER_ID = "11595243049"  # game.CreatorId (사전 확인 4)
TYPES = {".fbx": ("Model", "model/fbx"), ".png": ("Decal", "image/png")}


def api_key():
    k = os.environ.get("ROBLOX_ASSETS_KEY")
    if not k:
        try:
            import winreg

            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                k = winreg.QueryValueEx(h, "ROBLOX_ASSETS_KEY")[0]
        except OSError:
            k = None
    if not k:
        sys.exit("ROBLOX_ASSETS_KEY = NOT SET")
    return k


def load_ids():
    if os.path.exists(IDS):
        with open(IDS, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_ids(ids):
    with open(IDS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(ids.items())), f, ensure_ascii=False, indent=1)
        f.write("\n")
    gen_lua(ids)


def gen_lua(ids):
    lines = [
        "-- 생성 파일(roblox/tools/opencloud/upload.py) - 손으로 고치지 않는다. 원본 = roblox/art/asset-ids.json.",
        "-- 키 = roblox/art 기준 경로(확장자 뺌) · id = Open Cloud assetId(Model · Decal) · image = Decal의 이미지 id(ImageLabel용) · status = 업로드 · 심사 상태.",
        "return {",
    ]
    for path, e in sorted(ids.items()):
        if not e.get("assetId"):
            continue
        key = os.path.splitext(path)[0]
        img = e.get("imageId")
        lines.append(
            '\t["%s"] = { id = %s, kind = "%s"%s, status = "%s" },'
            % (key, e["assetId"], e["assetType"], (", image = %s" % img) if img else "", e.get("status", ""))
        )
    lines.append("}")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def request(method, url, key, body=None, ctype=None, tries=6):
    delay = 2.0
    for attempt in range(tries):
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("x-api-key", key)
        if ctype:
            req.add_header("Content-Type", ctype)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.status, json.loads(r.read().decode("utf-8") or "{}")
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")[:400]
            if e.code == 429 or e.code >= 500:
                print("  %s %d - %.0f초 뒤 재시도(%d)" % (method, e.code, delay, attempt + 1))
                time.sleep(delay)
                delay = min(delay * 2, 120)
                continue
            return e.code, {"error": text}
        except urllib.error.URLError as e:
            print("  네트워크 %s - %.0f초 뒤 재시도" % (type(e.reason).__name__, delay))
            time.sleep(delay)
            delay = min(delay * 2, 120)
    return 0, {"error": "재시도 한도"}


def multipart(req_json, path, mime):
    b = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    parts = [
        ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % b).encode(),
        json.dumps(req_json).encode(),
        ("\r\n--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
         % (b, os.path.basename(path), mime)).encode(),
        data,
        ("\r\n--%s--\r\n" % b).encode(),
    ]
    return b"".join(parts), "multipart/form-data; boundary=%s" % b


def moderation_of(resp):
    m = (resp or {}).get("moderationResult") or {}
    return m.get("moderationState") or "Unknown"


def poll(op_id, key, limit=90):
    t0 = time.time()
    delay = 1.0
    while time.time() - t0 < limit:
        code, body = request("GET", "%s/operations/%s" % (API, op_id), key)
        if code == 200 and body.get("done"):
            return body
        if code not in (200,):
            return {"error": body.get("error"), "code": code}
        time.sleep(delay)
        delay = min(delay * 1.5, 8)
    return None


def upload_one(rel, ids, key, dry):
    path = os.path.join(ART, rel)
    ext = os.path.splitext(rel)[1].lower()
    if ext not in TYPES:
        print("건너뜀(형식) %s" % rel)
        return
    atype, mime = TYPES[ext]
    h = sha(path)
    e = ids.get(rel)
    if e and e.get("sha256") == h and e.get("assetId") and not e.get("status", "").startswith("op:"):
        print("같음 %s → %s(%s)" % (rel, e["assetId"], e.get("status")))
        return
    if os.path.getsize(path) > 20 * 1024 * 1024:
        ids[rel] = {"sha256": h, "assetType": atype, "assetId": None, "status": "failed:20MB 초과"}
        return
    if dry:
        print("올릴 것 %s(%s · %s)" % (rel, atype, "새 버전" if e and e.get("assetId") else "새로"))
        return
    name = os.path.splitext(os.path.basename(rel))[0][:50]
    op = None
    if e and e.get("status", "").startswith("op:"):
        op = {"operationId": e["status"][3:]}
    elif e and e.get("assetId") and atype == "Model":
        body, ctype = multipart({"assetId": str(e["assetId"])}, path, mime)
        code, op = request("PATCH", "%s/assets/%s" % (API, e["assetId"]), key, body, ctype)
        if code != 200:
            print("X 갱신 %s: %d %s" % (rel, code, op.get("error")))
            e["status"] = "failed:update %d" % code
            return
    else:
        req = {
            "assetType": atype,
            "displayName": name,
            "description": "forge-game A2-N3 art: %s" % rel,
            "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
        }
        body, ctype = multipart(req, path, mime)
        code, op = request("POST", "%s/assets" % API, key, body, ctype)
        if code != 200:
            print("X 업로드 %s: %d %s" % (rel, code, op.get("error")))
            ids[rel] = {"sha256": h, "assetType": atype, "assetId": None, "status": "failed:%d %s" % (code, (op.get("error") or "")[:120])}
            return
    op_id = op.get("operationId") or (op.get("path") or "").split("/")[-1]
    done = poll(op_id, key)
    entry = ids.get(rel) or {}
    entry.update({"sha256": h, "assetType": atype})
    if done is None:
        entry["status"] = "op:%s" % op_id
        print("… 처리 중 %s(op 기록 - 다음 실행 때 이어서)" % rel)
    elif done.get("error"):
        entry["status"] = "failed:op %s" % done.get("code")
        print("X 작업 %s: %s" % (rel, done.get("error")))
    else:
        resp = done.get("response") or {}
        entry["assetId"] = int(resp.get("assetId") or entry.get("assetId") or 0) or None
        entry["status"] = moderation_of(resp)
        print("O %s → %s(%s)" % (rel, entry["assetId"], entry["status"]))
    ids[rel] = entry


def refresh(ids, key):
    """심사 상태 다시 읽기(Reviewing · Unknown만)."""
    for rel, e in ids.items():
        if e.get("assetId") and e.get("status") in ("Reviewing", "Unknown", "MODERATION_STATE_REVIEWING"):
            code, body = request("GET", "%s/assets/%s?readMask=moderationResult" % (API, e["assetId"]), key)
            if code == 200:
                e["status"] = moderation_of(body)
                print("상태 %s → %s" % (rel, e["status"]))


def main():
    args = sys.argv[1:]
    dry = "--dry" in args
    do_refresh = "--refresh" in args
    args = [a for a in args if not a.startswith("--") and not a.endswith(".json")]
    ids = load_ids()
    if "--gen" in sys.argv:
        gen_lua(ids)
        return
    if "--images" in sys.argv:
        # Decal → 이미지 id(Studio InsertService:LoadAsset(decal).Decal.Texture에서 읽은 값) 기록: --images <json 파일 {"icons/..png": 이미지id}>
        src = sys.argv[sys.argv.index("--images") + 1]
        with open(src, encoding="utf-8") as f:
            m = json.load(f)
        for rel, img in m.items():
            if rel in ids:
                ids[rel]["imageId"] = int(img)
        save_ids(ids)
        print("이미지 id %d개 기록" % len(m))
        return
    key = None if dry else api_key()
    files = []
    for a in args:
        hits = sorted(glob.glob(os.path.join(ART, a)))
        files += [os.path.relpath(p, ART).replace("\\", "/") for p in hits]
    for i, rel in enumerate(files):
        upload_one(rel, ids, key, dry)
        if not dry and (i % 5 == 4):
            save_ids(ids)
    if do_refresh and key:
        refresh(ids, key)
    if not dry:
        save_ids(ids)
    ok = sum(1 for r in files if (ids.get(r) or {}).get("assetId"))
    print("합계 %d개 중 assetId %d" % (len(files), ok))


if __name__ == "__main__":
    main()
