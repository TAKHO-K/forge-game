import math
g=196.2; h1=7.2; v1=math.sqrt(2*g*h1); T1=2*v1/g; ta=v1/g
DASH=0.3
def traj(tau,h2,cap=None,dt=0.0005):
    # simulate feet height; returns list of (t,y)
    y1=v1*tau-0.5*g*tau*tau
    if cap is not None:
        h2e=min(h2,max(cap-y1,0))
    else: h2e=h2
    v2=math.sqrt(2*g*h2e)
    T=tau+(v2+math.sqrt(v2*v2+2*g*y1))/g
    pts=[]
    t=0
    while t<=T:
        if t<tau: y=v1*t-0.5*g*t*t
        else:
            s=t-tau; y=y1+v2*s-0.5*g*s*s
        pts.append((t,y)); t+=dt
    return T,pts,y1,h2e
def above(pts,thr,dt=0.0005):
    return sum(dt for t,y in pts if y>thr)
def span(pts,thr):
    ts=[t for t,y in pts if y>thr]
    return (min(ts),max(ts)) if ts else (None,None)
print("v1=%.3f T1=%.4f apex=%.4f"%(v1,T1,ta))
# single jump
T,pts,_,_=traj(T1,0)
print("single: T=%.3f >8 %.3f >6.5 %.3f >4.5 %.3f"%(T1,0,above([(t,v1*t-.5*g*t*t) for t,_ in pts],6.5),above([(t,v1*t-.5*g*t*t) for t,_ in pts],4.5)))
res={}
for name,cap in (("fixed",None),("cap7.9",7.9)):
  for h2 in (3.6,4.32,5.04,0.8):
    best=None
    rows=[]
    for i in range(0,1081):
        tau=0.05+ (T1-0.051)*i/1080
        T,pts,y1,h2e=traj(tau,h2,cap,0.001)
        peak=max(y for t,y in pts)
        rows.append((tau,T,peak,above(pts,8,0.001),above(pts,6.5,0.001),above(pts,10.5,0.001),above(pts,4.5,0.001)))
    Tmax=max(rows,key=lambda r:r[1]); Pmax=max(rows,key=lambda r:r[2])
    ap=min(rows,key=lambda r:abs(r[0]-ta))
    m8=max(r[3] for r in rows); m65=max(r[4] for r in rows); m105=max(r[5] for r in rows); m45=max(r[6] for r in rows)
    print(f"{name} h2={h2}: apex tau={ap[0]:.3f} T={ap[1]:.3f} peak={ap[2]:.2f} >8={ap[3]:.3f} >6.5={ap[4]:.3f} | Tmax={Tmax[1]:.3f}@tau{Tmax[0]:.3f} peak{Tmax[2]:.2f} | peakmax={Pmax[2]:.2f} | max>8={m8:.3f} max>6.5={m65:.3f} maxdais>10.5={m105:.3f} max>4.5={m45:.3f} | Tmax+dash={Tmax[1]+DASH:.3f}")
    res[(name,h2)]=Tmax[1]
# formula check
for h2 in (3.6,4.32,5.04):
    print(h2, "T1+2sqrt(2h2/g)=%.4f"%(T1+2*math.sqrt(2*h2/g)))
