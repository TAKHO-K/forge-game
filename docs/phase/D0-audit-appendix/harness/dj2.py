import math
g=196.2; h1=7.2; v1=math.sqrt(2*g*h1); T1=2*v1/g
def fall(y,v):  # time to reach 0 from height y with vertical velocity v
    return (v+math.sqrt(v*v+2*g*y))/g
def state(t,y0,v0): return y0+v0*t-0.5*g*t*t, v0-g*t
def best(h2,dash=True,N=300):
    v2=math.sqrt(2*g*h2); best=(0,None)
    # order A: jump -> double at tau -> dash at s after double
    for i in range(N):
        tau=T1*i/N
        y,v=state(tau,0,v1)
        if y<0: continue
        Tnd=tau+fall(y,v2)
        if Tnd>best[0]: best=(Tnd,("nodash",tau))
        if not dash: continue
        tf=fall(y,v2)
        for j in range(N):
            s=tf*j/N; yd,_=state(s,y,v2)
            if yd<0: continue
            T=tau+s+0.3+math.sqrt(2*yd/g)
            if T>best[0]: best=(T,("A",tau,s,yd))
    if dash:
      # order B: jump -> dash at td -> (v=0 at y) -> double at s after dash end
      for i in range(N):
        td=T1*i/N; y,_=state(td,0,v1)
        if y<0: continue
        tf=math.sqrt(2*y/g)
        for j in range(N):
            s=tf*j/N; yy,vv=state(s,y,0)
            T=td+0.3+s+fall(yy,v2)
            if T>best[0]: best=(T,("B",td,s,yy))
    return best
for h2 in (3.6,4.32,5.04):
    print(h2, "nodash", best(h2,False), "dash", best(h2,True))
# single jump + dash (current)
b=(0,None)
for i in range(1000):
    td=T1*i/1000; y,_=state(td,0,v1)
    T=td+0.3+math.sqrt(2*max(y,0)/g)
    if T>b[0]: b=(T,td,y)
print("single+dash",b)
