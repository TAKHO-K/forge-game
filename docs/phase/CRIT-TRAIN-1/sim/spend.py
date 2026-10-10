# 구간별 수련 골드 비중 · 치명 수련 끝 단계 도달 스테이지: python spend.py <OUT_DIR> <태그,…> <프로필,…>
import sys,re
out=sys.argv[1]
H="t_h|reach|stage|tier|level|rebirth|rate|rawRate|base|lv|rb|opt|trn|critDmg|dmgRaw|overAtk|apb|atk|hitScale|mobHp|hitsNon|hitsCrit|hitsAvg|repHits|trRate|trDmg|trAtk|perm".split("|")
for p in sys.argv[3].split(","):
  for t in sys.argv[2].split(","):
    rows=[];cr=[]
    for l in open("%s/r_cr_%s_%s.txt"%(out,p,t),encoding="utf-8",errors="replace"):
        if l.startswith("ROW|"):
            v=l.strip().split("|"); sp=dict(kv.split("=") for kv in v[17].split(",") if "=" in kv); rows.append((float(v[1]),int(v[2]),{k:float(x) for k,x in sp.items()}))
        if l.startswith("CR|"): cr.append(dict(zip(H,map(float,l.strip().split("|")[1:]))))
    def at(s):
        return next(r for r in rows if r[1]>=s)
    out_=[]
    for a,b in [(1,2000),(2000,5000),(5000,10000),(10000,25300)]:
        ra,rb=at(a),at(b)
        tot=sum(rb[2].values())-sum(ra[2].values()); tr=rb[2].get("training",0)-ra[2].get("training",0)
        out_.append("%d~%d 수련 %.1f%%"%(a,b,100*tr/tot if tot else 0))
    full_r=next((c for c in cr if c["trRate"]>=25),None); full_d=next((c for c in cr if c["trDmg"]>=50),None)
    mx=max(c["dmgRaw"] for c in cr)
    print(p,t," · ".join(out_), "| 확률 25단계 s%s · 피해 50단계 s%s | 치명 피해 추가분 최대 +%.2f"%(int(full_r["reach"]) if full_r else "-", int(full_d["reach"]) if full_d else "-", mx))
