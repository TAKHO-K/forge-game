# QUEUE-ALL9E1 0-6: 몹 곡선 CSV · 로그 눈금 PNG + 1,000스테이지당 시간 표(4프로필 · 끔/켬 · 2배 넘는 벽 표시)
import os, io
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
SP = os.path.dirname(os.path.abspath(__file__))
DOC = r"C:\Users\xkrgh\vibe\game\docs\design"
TAG = "_g430000_fin"
REF_S0 = 8570

rows = [l.strip().split("|")[1:] for l in open(os.path.join(SP, "r_mob.txt"), encoding="utf-8") if l.startswith("CSV|")]
hdr, data = rows[0], rows[1:]
with io.open(os.path.join(DOC, "mob-curve.csv"), "w", encoding="utf-8", newline="\n") as f:
    f.write("# QUEUE-ALL9E1 0-6 실제 몹 곡선(shared/MonsterStats = 서버 · 몹 정보 UI · EconSim 같은 함수) · off = 스위치 끔 · on = 켬(전역 재조정 · 계승 안 한 사람) · onRef = 켬 + 중앙값 계승자(계승 %d · 돌파 계수 break 포함 체력)\n" % REF_S0)
    f.write(",".join(hdr) + "\n")
    for r in data:
        f.write(",".join(r) + "\n")

def col(mode, name):
    i = hdr.index(name)
    xs, ys = [], []
    for r in data:
        if r[1] == mode:
            try:
                v = float(r[i])
            except ValueError:
                continue
            if v == v and v > 0:
                xs.append(int(r[0])); ys.append(v)
    return xs, ys

fig, axes = plt.subplots(1, 3, figsize=(19, 5.5), dpi=110)
for ax, kind, title in ((axes[0], "hp", "체력(HP)"), (axes[1], "atk", "공격(ATK)")):
    for mode, style in (("off", "--"), ("on", "-"), ("onRef", ":")):
        for name, color in (("t1_" + kind, "#4C78A8"), ("t6_" + kind, "#F58518"), ("boss_" + kind, "#B92F48")):
            xs, ys = col(mode, name)
            ax.plot(xs, ys, style, color=color, lw=1.4, label="%s %s" % (name, mode))
    ax.set_yscale("log")
    ax.axvspan(REF_S0, REF_S0 + 1500, color="#D8B96E", alpha=0.25, label="돌파 구간(중앙값 계승 %d~%d)" % (REF_S0, REF_S0 + 1500))
    ax.axvline(16000, color="#888", lw=0.8)
    ax.set_title("몹 %s - 끔(--) · 켬(─) · 켬+중앙값 계승자(··)" % title, fontname="Malgun Gothic")
    ax.set_xlabel("스테이지", fontname="Malgun Gothic")
    ax.grid(True, which="major", alpha=0.3)
axes[0].legend(fontsize=6, ncol=3, prop={"family": "Malgun Gothic", "size": 6})
ax = axes[2]
for name, color in (("t1_hp", "#4C78A8"), ("boss_hp", "#B92F48"), ("t1_atk", "#54A24B")):
    xo, yo = col("off", name)
    base = dict(zip(xo, yo))
    for mode, style in (("on", "-"), ("onRef", ":")):
        xs, ys = col(mode, name)
        pts = [(x, y / base[x]) for x, y in zip(xs, ys) if x in base and base[x] > 0]
        ax.plot([p[0] for p in pts], [p[1] for p in pts], style, color=color, lw=1.6, label="%s %s ÷ 끔" % (name, mode))
ax.set_yscale("log")
ax.axvspan(REF_S0, REF_S0 + 1500, color="#D8B96E", alpha=0.25)
ax.axvline(16000, color="#888", lw=0.8)
ax.set_title("켬 ÷ 끔 배수(돌파 구간 ÷2.4 · 16,000부터 전역 재조정 · 중앙값 기준 빌드)", fontname="Malgun Gothic", fontsize=9)
ax.set_xlabel("스테이지", fontname="Malgun Gothic")
ax.grid(True, which="both", alpha=0.3)
ax.legend(prop={"family": "Malgun Gothic", "size": 7})
fig.tight_layout()
fig.savefig(os.path.join(DOC, "mob-curve.png"))

def load(path):
    out = []
    for l in open(path, encoding="utf-8", errors="replace"):
        p = l.split("|")
        if p[0] == "ROW":
            out.append((float(p[1]), int(p[2])))
    return out

def tAt(rows, s):
    for t, r in rows:
        if r >= s:
            return t
    return None

lines = ["# 1,000스테이지당 시간(QUEUE-ALL9E1 0-6 · 실제 EconSim · 시간 h · 켬 = All10Economy + ResetMinus4 켬 · levelKills 43만 · 끔 = 바꾸기 전 게임)", "",
         "> ★ = 그 구간이 바로 앞 구간보다 2배 넘게 느림(벽). 원자료 = 스크래치 r_a10_<프로필>_on%s.txt · _off_e1.txt" % TAG, ""]
for prof, name in (("casual", "캐주얼"), ("normal", "일반"), ("top", "상위 1%"), ("unluckyP90", "운 나쁜 P90")):
    on = load(os.path.join(SP, "r_a10_%s_on%s.txt" % (prof, TAG)))
    off = load(os.path.join(SP, "r_a10_%s_off_e1.txt" % prof))
    lines.append("## %s" % name)
    lines.append("")
    lines.append("| 구간 | 끔 h | 켬 h | 켬 ÷ 끔 |")
    lines.append("|---|---|---|---|")
    prevOn = prevOff = None
    for a in range(0, 25300, 1000):
        b = min(a + 1000, 25300)
        def seg(rows):
            ta, tb = tAt(rows, max(a, 1)), tAt(rows, b)
            return (tb - ta) if ta is not None and tb is not None else None
        so, sn = seg(off), seg(on)
        wallOff = "★" if prevOff and so and so > 2 * prevOff else ""
        wallOn = "★" if prevOn and sn and sn > 2 * prevOn else ""
        lines.append("| %d ~ %d | %s%s | %s%s | %s |" % (a, b, "%.1f" % so if so is not None else "-", wallOff, "%.1f" % sn if sn is not None else "-", wallOn,
                                                     "%.2f" % (sn / so) if so and sn else "-"))
        prevOn, prevOff = sn, so
    lines.append("")
io.open(os.path.join(DOC, "stage-hours-per-1000.md"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
print("ok")
