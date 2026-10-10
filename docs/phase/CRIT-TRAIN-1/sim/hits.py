# 스테이지별(±5% 창 중앙값) 치명 확률 · 비치명 / 치명 / 기대 타수: python hits.py <OUT_DIR> <태그,…> <프로필,…> <스테이지,…>
import sys,statistics
out=sys.argv[1]
H="t_h|reach|stage|tier|level|rebirth|rate|rawRate|base|lv|rb|opt|trn|critDmg|dmgRaw|overAtk|apb|atk|hitScale|mobHp|hitsNon|hitsCrit|hitsAvg|repHits|trRate|trDmg|trAtk|perm".split("|")
ST=[int(x) for x in sys.argv[4].split(",")]
for p in sys.argv[3].split(","):
  for t in sys.argv[2].split(","):
    cr=[dict(zip(H,map(float,l.strip().split("|")[1:]))) for l in open("%s/r_cr_%s_%s.txt"%(out,p,t),encoding="utf-8",errors="replace") if l.startswith("CR|")]
    cells=[]
    for s in ST:
        w=[c for c in cr if s*0.95<=c["reach"]<=s*1.05+3] or [min(cr,key=lambda c:abs(c["reach"]-s))]
        md=lambda k: statistics.median(c[k] for c in w)
        cells.append("%.0f%% · %.1f / %.1f / %.1f"%(md("rate")*100, md("hitsNon"), md("hitsCrit"), md("hitsAvg")))
    print("|",p,t,"|"," | ".join(cells),"|")
