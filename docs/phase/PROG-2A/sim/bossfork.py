# PROG-2A BossSim 설계 사본: 원본 src를 스크래치 폴더로 복사한 뒤 shared/BossDifficultySim.lua 몇 줄만 바꾼다(원본 파일은 안 바뀜).
#   options.hpExtra(보스 HP 배율 · 처치 시간 목표) · options.dmgExtra(받는 피해 배율) · options.failHeal(기믹 실패 = 피해 대신 보스 HP 회복 비율)
#   options.gimmickHitScale(기믹 실패 확률 배율 - 넉넉한 제한 시간) · options.limit(판 시간 상한). 옵션이 없으면 원본과 같은 계산.
# 사용: python bossfork.py <대상 폴더>  → <대상>/src (ECON_SRC로 build_run.py에 넘긴다)
import io, os, shutil, sys
SP = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(SP, "..", "..", "..", "..", "roblox", "src"))
dst = os.path.join(sys.argv[1], "src")
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(SRC, dst)
p = os.path.join(dst, "shared", "BossDifficultySim.lua")
s = io.open(p, encoding="utf-8").read()

def sub(old, new, count=1):
    global s
    assert s.count(old) == count, (old, s.count(old))
    s = s.replace(old, new)

sub("local maxHp = sim.referenceKillSeconds * hpScale", "local maxHp = sim.referenceKillSeconds * (options.hpExtra or 1) * hpScale")
sub("\tlocal hp = maxHp\n", "\tlocal hp = maxHp\n\tlocal healN = 0\n")
sub("local dealt = (current_ and m.hp * share or share) * protect", "local dealt = (current_ and m.hp * share or share) * protect * (options.dmgExtra or 1)")
sub("\t\t\t\t\t\t\t\tdamage(m, fraction, nil, j.id)\n",
    "\t\t\t\t\t\t\t\tif options.failHeal then hp = math.min(maxHp, hp + options.failHeal * maxHp); healN += 1 else damage(m, fraction, nil, j.id) end\n")
sub("\t\t\t\t\t\t\tdamage(m, j.fraction, nil, j.id)\n",
    "\t\t\t\t\t\t\tif options.failHeal then hp = math.min(maxHp, hp + options.failHeal * maxHp); healN += 1 else damage(m, j.fraction, nil, j.id) end\n")
sub("\t\t\tif j.color then\n\t\t\t\tbase *= 1 + cfg.colorPartyPenalty * (n - 1)\n\t\t\tend\n",
    "\t\t\tif j.color then\n\t\t\t\tbase *= 1 + cfg.colorPartyPenalty * (n - 1)\n\t\t\tend\n\t\t\tbase *= (options.gimmickHitScale or 1)\n")
sub("\tlocal limit = 400\n", "\tlocal limit = options.limit or 400\n")
sub("takenAverage = takenSum / n, counts = counts,", "takenAverage = takenSum / n, heals = healN, counts = counts,")
sub("\tlocal times, taken, wipes, killed, anyDead = {}, 0, 0, 0, 0\n", "\tlocal times, taken, wipes, killed, anyDead = {}, 0, 0, 0, 0\n\tlocal heals, timeouts = 0, 0\n")
sub("\t\ttaken += r.takenAverage\n", "\t\ttaken += r.takenAverage\n\t\theals += r.heals or 0\n\t\ttimeouts += (not r.wiped and not r.killed) and 1 or 0\n")
sub("runs = runs, wipeRate = wipes / runs,", "runs = runs, healsPerRun = heals / runs, timeoutRate = timeouts / runs, wipeRate = wipes / runs,")
io.open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", p)
