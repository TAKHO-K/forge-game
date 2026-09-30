# -*- coding: utf-8 -*-
# QUEUE-ALL3 Q5 허브 NPC 배치 안 3개(위에서 본 그림 + 걷는 시간). 입력 = WorldMapData 허브 수치(손으로 옮김 - 아래 FACILITIES) · 출력 = Claude outputs/QUEUE-ALL3/hub_layout/*.png
#   걷기 16 stud/초(기본 WalkSpeed) · 10초 = 160 stud 원. 나무 줄기 · 뿌리 = r 100 안(지나갈 수 없음 - 돌아감) · 허브 경계 = r 400.
import math, os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "Claude outputs", "QUEUE-ALL3", "hub_layout")
os.makedirs(OUT, exist_ok=True)
S = 900
SCALE = S / 900.0  # 1 px = 1 stud(가운데 = 허브 중심 · ±450)
FONT = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 20)
SMALL = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 16)
WALK = 16.0


def pos(angle, r):
    a = math.radians(angle)
    return (math.cos(a) * r, math.sin(a) * r)


def px(p):
    return (S / 2 + p[0] * SCALE, S / 2 + p[1] * SCALE)


def draw(name, title, cp, places, note):
    img = Image.new("RGB", (S, S + 120), (34, 40, 52))
    d = ImageDraw.Draw(img)
    c = px((0, 0))
    d.ellipse([c[0] - 400, c[1] - 400, c[0] + 400, c[1] + 400], fill=(92, 150, 84), outline=(230, 220, 150), width=3)  # 허브 경계 r 400
    d.ellipse([c[0] - 100, c[1] - 100, c[0] + 100, c[1] + 100], fill=(96, 70, 50))  # 나무 줄기 · 뿌리
    d.text((c[0] - 30, c[1] - 12), "큰 나무", font=SMALL, fill=(255, 240, 210))
    cpp = px(cp)
    d.ellipse([cpp[0] - 160, cpp[1] - 160, cpp[0] + 160, cpp[1] + 160], outline=(120, 220, 255), width=3)  # 10초 원
    d.ellipse([cpp[0] - 12, cpp[1] - 12, cpp[0] + 12, cpp[1] + 12], fill=(120, 220, 255))
    d.text((cpp[0] + 14, cpp[1] - 10), "체크포인트", font=SMALL, fill=(200, 245, 255))
    worst = 0
    for label, p, color in places:
        q = px(p)
        d.rounded_rectangle([q[0] - 26, q[1] - 16, q[0] + 26, q[1] + 16], radius=8, fill=color, outline=(30, 27, 46), width=3)
        dist = math.dist(p, cp)
        # 나무를 가로지르면 돌아가는 몫(대략): 선분이 r 100 원을 지나면 + 40%
        mid = ((p[0] + cp[0]) / 2, (p[1] + cp[1]) / 2)
        if math.hypot(*mid) < 100:
            dist *= 1.4
        worst = max(worst, dist / WALK)
        d.text((q[0] - 26, q[1] + 18), "%s %.1f초" % (label, dist / WALK), font=SMALL, fill=(255, 255, 255))
    d.text((20, S + 10), title, font=FONT, fill=(255, 230, 140))
    d.text((20, S + 45), "가장 먼 시설까지 %.1f초(목표 10초 이하) · %s" % (worst, note), font=SMALL, fill=(230, 230, 240))
    img.save(os.path.join(OUT, name))
    return worst


FORGE, MARKET, ALTAR, PORTAL, BOARD = (230, 140, 60), (240, 200, 70), (170, 120, 230), (90, 170, 230), (200, 200, 210)
# 지금(WorldMapData.hub.facilities): 대장간 −25° r255 · 시장(보석상인 · 상점) 90° r255 · 커뮤니티(환생 제단) 210° r255 · 포탈 −90° r250 · 스폰 −60° r120 · 명예의 전당(업데이트 게시판) ≈ 커뮤니티 쪽
now = [("대장간", pos(-25, 255), FORGE), ("상점", pos(90, 255), MARKET), ("제단", pos(210, 255), ALTAR), ("포탈", pos(-90, 250), PORTAL), ("게시판", pos(230, 300), BOARD)]
results = {}
results["now"] = draw("0_now.png", "지금 배치(체크포인트 = 스폰 자리 −60° r120)", pos(-60, 120), now, "참고")
# 안 A(작게 바꿈): 시설은 그대로 · 체크포인트를 시설 셋의 가운데 쪽(나무 앞)으로 + 게시판 · 수련 표지 · 알 부화 표지를 체크포인트 곁으로
a = [("대장간", pos(-25, 255), FORGE), ("상점", pos(90, 255), MARKET), ("제단", pos(210, 255), ALTAR), ("포탈", pos(-90, 250), PORTAL), ("게시판", pos(-50, 170), BOARD)]
results["A"] = draw("A_small.png", "안 A: 시설 그대로 · 게시판만 체크포인트 곁", pos(-60, 130), a, "시설 3곳이 120° 간격이라 10초 불가")
# 안 B(한쪽 반원): 체크포인트 = −60° r300 · 대장간 −25° r240 · 상점 −100° r300 · 제단 −45° r380? → 허브 경계 안쪽 반원에 모음(포탈 −90° r250 그대로)
b = [("대장간", pos(-20, 250), FORGE), ("상점", pos(-105, 300), MARKET), ("제단", pos(-60, 380), ALTAR), ("포탈", pos(-90, 250), PORTAL), ("게시판", pos(-40, 320), BOARD)]
results["B"] = draw("B_half.png", "안 B: 관문 쪽 반원 바깥에 모음(대장간 −20° · 상점 −105° · 제단 −60° 바깥)", pos(-60, 300), b, "나무 둘레 한쪽 · 첫 관문 가는 길 위")
# 안 C(추천 · 적용): 나무 앞(관문 쪽) 반경 170 ~ 250에 모음 - 대장간 −20° r170 · 시장 −115° r175 · 커뮤니티(제단 · 부화장 · 게시판 · 명예의 전당) −60° r250 · 포탈 −90° r250 그대로 · 체크포인트 −65° r180
c = [("대장간", pos(-20, 170), FORGE), ("상점", pos(-115, 175), MARKET), ("제단", pos(-60, 250), ALTAR), ("포탈", pos(-90, 250), PORTAL), ("게시판", pos(-60, 280), BOARD)]
results["C"] = draw("C_ring.png", "안 C(추천 · 적용): 나무 앞 반경 170 ~ 250에 모음", pos(-65, 180), c, "게시판 · 부화장 = 커뮤니티 광장 안")
print(results)
