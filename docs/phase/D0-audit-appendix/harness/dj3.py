import math
g=196.2; h1=7.2; v1=math.sqrt(2*g*h1); T1=2*v1/g
def run(h2,cap=None,base=0.0,N=600,dt=0.001):
    out=[]
    for i in range(1,N):
        tau=T1*i/N
        y1=v1*tau-0.5*g*tau*tau
        h2e=h2 if cap is None else min(h2,max(cap-y1,0))
        v2=math.sqrt(2*g*h2e)
        pts=[];t=0
        while True:
            if t<tau: y=v1*t-0.5*g*t*t
            else:
                s=t-tau; y=y1+v2*s-0.5*g*s*s
            if y<0 and t>0: break
            pts.append((t,base+y)); t+=dt
        out.append((tau,pts))
    return out
def stats(h2,cap):
    o=run(h2,cap)
    Tm=max(len(p)*0.001 for _,p in o)
    m65=max(sum(0.001 for t,y in p if y>6.5) for _,p in o)
    m45=max(sum(0.001 for t,y in p if y>4.5) for _,p in o)
    pk=max(max(y for t,y in p) for _,p in o)
    return Tm,m65,m45,pk
for h2 in (3.6,4.32,5.04):
    print("cap7.2",h2,["%.3f"%x for x in stats(h2,7.2)])
# wall crossing from dais (base 3.5), wall top 14, dais edge >=20 from wall inner face, thickness 4, body half 1
def wallspeed(h2,cap=None,dash=False):
    best=1e9
    for tau,pts in run(h2,cap,base=3.5,N=300,dt=0.002):
        ts=[t for t,y in pts if y>14.0]
        if not dash:
            if not ts: continue
            ta,tb=min(ts),max(ts)
            # need center reach 25 by tb and be at 19 at >=ta: speed s>=25/tb and s*(tb-ta)>=6
            s=max(25/tb,6/(tb-ta) if tb>ta else 1e9)
            best=min(best,s)
        else:
            # dash when root (=feet+3) > 14 -> feet>11 ; dash moves 16 in 0.3 at const height; need end center >=25 -> start >=9 from edge
            ts2=[t for t,y in pts if y>11.0]
            if not ts2: continue
            tb=max(ts2)
            best=min(best,9/tb)
    return best
for h2 in (3.6,4.32,5.04):
    print("fixed",h2,"walk-over speed %.1f"%wallspeed(h2),"dash-through walk speed %.1f"%wallspeed(h2,dash=True))
for cap in (7.9,7.2):
    print("cap",cap,"dash-through %.1f"%wallspeed(5.04,cap,True),"walk-over",wallspeed(5.04,cap))
print("single dais peak root",3.5+7.2+3)
