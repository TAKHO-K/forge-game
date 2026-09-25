import math
W=4; DMAX=96*(math.sqrt(2)+0.05); STAND=8
P=0.5; AIR=0.54; M=1.25; REJ=P+AIR*M
pats={
 "shockwave":[dict(gap=0,v=24,L=1),dict(gap=1.6,v=24,L=1),dict(gap=1.25,v=24,L=1)],
 "tide":[dict(gap=0,v=30,L=2),dict(gap=1.5,v=24,L=2),dict(gap=1.5,v=18,L=2)],
 "discharge":[dict(gap=0,v=36,L=1),dict(gap=1.3,v=20,L=1)],
}
Tmax={"a50":0.932,"a60":0.965,"a70":0.997,"b50":1.337,"b60":1.374,"b70":1.409,"cur":0.954}
# scenario: 조합금지 => max(double, single+dash 0.954)
scen={"금지50":max(0.932,0.954),"금지60":max(0.965,0.954),"금지70":max(0.997,0.954),"허용50":1.337,"허용60":1.374,"허용70":1.409}
def waves(p):
    out=[];s=1.2
    for i,w in enumerate(p):
        if i>0: s+=w["gap"]
        out.append(dict(s=s,v=w["v"],L=w["L"],lg=W/w["v"]))
    return out
def need(a,b,d):
    first_end=a["s"]+d/a["v"]+W/a["v"]
    last_start=b["s"]+b["lg"]*(b["L"]-1)+d/b["v"]
    return last_start-first_end
def rejump(a,b,d):
    return (b["s"]+d/b["v"])-(a["s"]+a["lg"]*(a["L"]-1)+d/a["v"])
MARGIN=0.10
for name,p in pats.items():
    ws=waves(p)
    for i in range(1,len(ws)):
        a,b=ws[i-1],ws[i]
        nd=min(need(a,b,d) for d in (0,STAND,DMAX)); nd4=need(a,b,STAND)
        rj=min(rejump(a,b,d) for d in (STAND,DMAX))
        line=f"{name} {i}->{i+1}: gap={p[i]['gap']} need(min d0/8/max)={nd:.3f} need(d8)={nd4:.3f} rejump={rj:.3f}(>= {REJ:.3f})"
        for k,T in scen.items():
            delta=max(0,T+MARGIN-nd)
            newgap=math.ceil((p[i]['gap']+delta)*20-1e-9)/20
            line+=f" | {k}:T{T:.3f} {'OK' if T<nd else 'BREAK'} slack{nd-T:+.3f} newgap{newgap:.2f}"
        print(line)
# single input window
for v in (24,30,18,36,20):
    print("band",v,W/v)
