# 스테이지 도달 h 비교: python reach.py <OUT_DIR> <태그,…> <프로필,…>
import sys
out=sys.argv[1]; tags=sys.argv[2].split(","); profs=sys.argv[3].split(",")
ST=[1000,2000,3000,4000,5000,7500,10000,15000,20000,25300]
for p in profs:
    print("|", p, "|", " | ".join("{:,}".format(s) for s in ST), "| 계승 |")
    for t in tags:
        rt={}; inh="-"
        for l in open("%s/r_cr_%s_%s.txt"%(out,p,t),encoding="utf-8",errors="replace"):
            if l.startswith("ROW|"):
                v=l.split("|"); h=float(v[1]); r=int(v[2])
                for s in ST:
                    if r>=s and s not in rt: rt[s]=h
            elif l.startswith("INH|"): inh=l.strip()[4:]
        print("|", t, "|", " | ".join("%.1f"%rt.get(s,0) for s in ST), "|", inh, "|")
