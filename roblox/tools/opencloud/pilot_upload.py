"""ART-PILOT-1 시범 업로드 - upload.py의 요청 함수를 빌려 쓰되 결과는 시범 폴더 json에만 적는다(asset-ids.json · ArtAssetIds.lua = 게임 데이터 안 건드림).

사용: python roblox/tools/opencloud/pilot_upload.py <이름=파일 경로>...
  예) python roblox/tools/opencloud/pilot_upload.py boar_b1=C:/.../withSkin.fbx boar_b1_tex=C:/.../texture_0.png
  .fbx → Model · .png → Decal. 결과 = roblox/art/pilot/art_pilot_1/pilot-asset-ids.json(이름 · 파일 이름 · 해시 · assetId · 상태). 같은 해시 = 건너뜀.
  소유 = upload.CREATOR_USER_ID(게임 소유자와 같음). 키 = upload.api_key()(출력 안 함). 실패해도 재시도는 대상당 1번(ART-PILOT-1 규칙).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import upload as U  # noqa: E402

OUT = os.path.join(U.ART, "pilot", "art_pilot_1", "pilot-asset-ids.json")


def main():
    ids = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
    key = U.api_key()
    for arg in sys.argv[1:]:
        name, path = arg.split("=", 1)
        ext = os.path.splitext(path)[1].lower()
        atype, mime = U.TYPES[ext]
        h = U.sha(path)
        e = ids.get(name) or {}
        if e.get("sha256") == h and e.get("assetId"):
            print("같음 %s → %s(%s)" % (name, e["assetId"], e.get("status")))
            continue
        size = os.path.getsize(path)
        req = {"assetType": atype, "displayName": ("art_pilot_" + name)[:50], "description": "forge-game ART-PILOT-1 test: %s" % name,
               "creationContext": {"creator": {"userId": U.CREATOR_USER_ID}}}
        for attempt in range(2):
            body, ctype = U.multipart(req, path, mime)
            code, op = U.request("POST", "%s/assets" % U.API, key, body, ctype, tries=2)
            if code != 200:
                print("X 업로드 %s(%d바이트): %d %s" % (name, size, code, (op.get("error") or "")[:300]))
                e = {"file": os.path.basename(path), "sha256": h, "assetType": atype, "assetId": None, "status": "failed:%d" % code}
                continue
            op_id = op.get("operationId") or (op.get("path") or "").split("/")[-1]
            done = U.poll(op_id, key, limit=180)
            if done is None or done.get("error"):
                print("X 작업 %s: %s" % (name, (done or {}).get("error") or "시간 초과 op=%s" % op_id))
                e = {"file": os.path.basename(path), "sha256": h, "assetType": atype, "assetId": None, "status": "failed:op"}
                continue
            resp = done.get("response") or {}
            e = {"file": os.path.basename(path), "sha256": h, "assetType": atype, "bytes": size,
                 "assetId": int(resp.get("assetId") or 0) or None, "status": U.moderation_of(resp)}
            print("O %s → %s(%s)" % (name, e["assetId"], e["status"]))
            break
        ids[name] = e
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w", encoding="utf-8", newline="\n") as f:
            json.dump(ids, f, ensure_ascii=False, indent=1)
            f.write("\n")


if __name__ == "__main__":
    main()
