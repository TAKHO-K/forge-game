# -*- coding: utf-8 -*-
"""절차 합성 효과음 시트 생성기 (docs/design/v2/09-visual-gui-sound.md C절).

설치 없이 numpy + 표준 wave 모듈만 쓴다.
효과음 여러 개를 시트 파일 하나에 이어 붙이고(사이 무음 >= 0.25 s),
게임은 Sound.PlaybackRegion(start .. start + duration)으로 구간 재생한다.

출력
  roblox/art/audio/sfx_combat.wav · sfx_loot.wav · sfx_ui.wav (44100 Hz · 모노 · 16비트)
  roblox/art/audio/sfx_sheet.json (큐별 시트 · 시작 · 길이 · 권장 음량 · 소리 그룹 · 설명)
  roblox/src/shared/data/SoundSheetData.lua (JSON과 같은 내용의 Luau 데이터)

실행: python roblox/tools/audio/make_sfx.py   (결과는 난수 시드 고정이라 매번 같다)
각 큐는 피크 -1 dBFS로 정규화한다. 작게 들려야 하는 큐(UI 딸깍 등)는 데이터 volume으로 줄인다.
"""
import json
import os
import wave

import numpy as np

SR = 44100
GAP = 0.3  # 큐 사이 무음(초) - 요구 >= 0.25
LEAD = 0.25  # 시트 맨 앞 무음(초)
PEAK = 10 ** (-1 / 20)  # -1 dBFS
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT_DIR = os.path.join(ROOT, "roblox", "art", "audio")
LUA_PATH = os.path.join(ROOT, "roblox", "src", "shared", "data", "SoundSheetData.lua")

rng = np.random.default_rng(20261001)


# ---------- 기본 조각 ----------
def n2f(n):
	"""MIDI 음 번호 → 주파수"""
	return 440.0 * 2 ** ((n - 69) / 12)


def tt(dur):
	return np.arange(int(dur * SR)) / SR


def tone(dur, f0, f1=None, wave_="sine", curve="exp"):
	"""주파수 f0 → f1로 미끄러지는 음(위상 적분이라 끊김 없음)"""
	n = int(dur * SR)
	if f1 is None:
		f1 = f0
	x = np.linspace(0, 1, n, endpoint=False)
	if curve == "exp" and f0 > 0 and f1 > 0:
		f = f0 * (f1 / f0) ** x
	else:
		f = f0 + (f1 - f0) * x
	ph = 2 * np.pi * np.cumsum(f) / SR
	if wave_ == "sine":
		return np.sin(ph)
	if wave_ == "soft_square":  # 둥근 사각파(카툰 삑)
		return np.tanh(3 * np.sin(ph)) / np.tanh(3)
	if wave_ == "tri":
		return 2 / np.pi * np.arcsin(np.sin(ph))
	raise ValueError(wave_)


def fm(dur, fc, ratio, index, index_decay=6.0):
	"""FM 벨(지수 감쇠하는 변조 지수)"""
	t = tt(dur)
	idx = index * np.exp(-index_decay * t)
	return np.sin(2 * np.pi * fc * t + idx * np.sin(2 * np.pi * fc * ratio * t))


def noise(dur):
	return rng.uniform(-1, 1, int(dur * SR))


def env(dur, a=0.005, d=0.2, shape=1.0):
	"""빠른 어택 + 지수 감쇠"""
	t = tt(dur)
	e = np.exp(-t / max(d, 1e-4)) ** shape
	if a > 0:
		e *= np.clip(t / a, 0, 1)
	return e


def adsr(dur, a, d, s, r):
	n = int(dur * SR)
	na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
	ns = max(n - na - nd - nr, 0)
	e = np.concatenate([
		np.linspace(0, 1, na, endpoint=False),
		np.linspace(1, s, nd, endpoint=False),
		np.full(ns, s),
		np.linspace(s, 0, nr),
	])
	return fit(e, n)


def fit(x, n):
	if len(x) >= n:
		return x[:n]
	return np.concatenate([x, np.zeros(n - len(x))])


def band(x, lo=None, hi=None, soft=1.3):
	"""FFT 대역 필터(부드러운 경사)"""
	X = np.fft.rfft(x)
	f = np.fft.rfftfreq(len(x), 1 / SR) + 1e-9
	g = np.ones_like(f)
	if lo:
		g *= 1 / (1 + (lo / f) ** (2 * soft))
	if hi:
		g *= 1 / (1 + (f / hi) ** (2 * soft))
	return np.fft.irfft(X * g, len(x))


def sweep_lp(x, f0, f1):
	"""시간에 따라 차단 주파수가 f0 → f1로 움직이는 1극 저역 통과(휘두름 · 바람)"""
	n = len(x)
	fc = f0 * (f1 / f0) ** np.linspace(0, 1, n)
	a = 1 - np.exp(-2 * np.pi * fc / SR)
	y = np.empty(n)
	s = 0.0
	for i in range(n):
		s += a[i] * (x[i] - s)
		y[i] = s
	return y


def mix(*parts, at=None):
	"""(신호, 시작 초) 여러 개를 겹쳐 더한다"""
	if at is None:
		at = [0] * len(parts)
	n = max(int(o * SR) + len(p) for p, o in zip(parts, at))
	y = np.zeros(n)
	for p, o in zip(parts, at):
		i = int(o * SR)
		y[i:i + len(p)] += p
	return y


def seq(notes):
	"""notes = [(시작초, 신호), ...]"""
	return mix(*[s for _, s in notes], at=[o for o, _ in notes])


def pluck(f, dur=0.35, bright=0.4, decay=0.12):
	"""카툰 톤 발음(사인 + 약한 배음)"""
	s = tone(dur, f) + bright * 0.5 * tone(dur, 2 * f) + bright * 0.2 * tone(dur, 3 * f)
	return s * env(dur, 0.003, decay)


def bell(f, dur=0.8, decay=0.25, bright=1.0):
	"""맑은 종(비정수 배음 + FM)"""
	s = fm(dur, f, 3.5, 1.2 * bright, 8) * env(dur, 0.002, decay)
	s += 0.35 * tone(dur, f * 2.76) * env(dur, 0.002, decay * 0.5)
	s += 0.2 * tone(dur, f * 5.4) * env(dur, 0.002, decay * 0.25) * bright
	return s


def sparkle(dur=0.4, n=6, lo=84, hi=100, spread=None):
	"""반짝이(높은 짧은 종 여러 개 - 6 kHz를 넘지 않게 음 범위 제한)"""
	spread = spread or dur * 0.6
	parts, at = [], []
	for _ in range(n):
		note = rng.integers(lo, hi)
		parts.append(0.4 * bell(n2f(note), 0.25, 0.06))
		at.append(rng.uniform(0, spread))
	return mix(*parts, at=at)


def thump(dur, f0, f1, decay, click=0.3):
	"""낮은 쿵(사인 하강 + 짧은 잡음 클릭)"""
	s = tone(dur, f0, f1) * env(dur, 0.002, decay)
	c = band(noise(0.03), 200, 2500) * env(0.03, 0.0005, 0.008) * click
	return mix(s, c)


def whoosh(dur, f0, f1, amp_peak=0.5):
	"""휘두름 · 바람(필터 스윕 잡음 + 가운데 볼록 포락선)"""
	x = sweep_lp(noise(dur), f0, f1)
	x = band(x, 150, None)
	t = np.linspace(0, 1, len(x))
	e = np.where(t < amp_peak, np.sin(np.pi / 2 * t / amp_peak) ** 2, np.cos(np.pi / 2 * (t - amp_peak) / (1 - amp_peak)) ** 2)
	return x * e


def chord(notes, dur, a=0.01, d=0.2, s=0.6, r=0.3, voice="pluck"):
	parts = []
	for n in notes:
		f = n2f(n)
		if voice == "pad":
			v = tone(dur, f) + 0.3 * tone(dur, 2 * f) + 0.15 * tone(dur, f * 1.003) + 0.15 * tone(dur, f * 0.997)
		else:
			v = tone(dur, f, wave_="tri") + 0.3 * tone(dur, 2 * f)
		parts.append(v * adsr(dur, a, d, s, r))
	return mix(*parts)


def arp(notes, step, note_dur, voice=pluck, **kw):
	return seq([(i * step, voice(n2f(n), note_dur, **kw)) for i, n in enumerate(notes)])


# ---------- 큐 정의 ----------
def c_hit_light():
	body = tone(0.16, 320, 110) * env(0.16, 0.001, 0.045)
	pop = band(noise(0.05), 400, 3000) * env(0.05, 0.0005, 0.01) * 0.5
	return mix(body, pop)


def c_hit_heavy():
	body = tone(0.35, 180, 50) * env(0.35, 0.001, 0.1)
	crunch = band(noise(0.12), 150, 1800) * env(0.12, 0.0005, 0.03) * 0.7
	sub = tone(0.3, 70, 45) * env(0.3, 0.005, 0.12) * 0.6
	return mix(body, crunch, sub)


def c_hit_crit():
	return mix(c_hit_light() * 0.9, 0.55 * bell(n2f(91), 0.4, 0.09), 0.35 * bell(n2f(96), 0.35, 0.07), at=[0, 0.01, 0.04])


def c_swing():
	return whoosh(0.24, 500, 3500, 0.45) + 0.15 * tone(0.24, 300, 700) * env(0.24, 0.05, 0.08)


def c_hurt_small():
	s = tone(0.18, 260, 150, wave_="soft_square") * env(0.18, 0.002, 0.05) * 0.5
	return band(mix(s, band(noise(0.05), 200, 1500) * env(0.05, 0.001, 0.012) * 0.4), None, 2500)


def c_hurt_big():
	return mix(thump(0.5, 140, 40, 0.14, 0.8), band(noise(0.2), 80, 900) * env(0.2, 0.001, 0.05) * 0.6,
		0.3 * tone(0.35, 220, 110, wave_="soft_square") * env(0.35, 0.005, 0.08))


def c_heartbeat():
	b = lambda: band(thump(0.25, 70, 42, 0.07, 0.1), None, 400)
	return mix(b(), 0.75 * b(), at=[0, 0.2])


def c_warning():
	# 두 음 짧게(사이렌 아님) - 둥근 사각파 · 중음역
	a = tone(0.14, n2f(74), wave_="soft_square") * adsr(0.14, 0.005, 0.03, 0.7, 0.05)
	b = tone(0.2, n2f(69), wave_="soft_square") * adsr(0.2, 0.005, 0.04, 0.6, 0.1)
	return band(mix(a, b, at=[0, 0.16]), 200, 2200)


def c_boss_appear():
	horn_n = [45, 52]  # 저음 뿔(5도)
	dur = 1.1
	horn = mix(*[(tone(dur, n2f(n), wave_="soft_square") + 0.4 * tone(dur, 2 * n2f(n))) for n in horn_n])
	horn = band(horn, None, 1200) * adsr(dur, 0.08, 0.2, 0.7, 0.5)
	drum = thump(0.7, 110, 38, 0.2, 0.9)
	return mix(drum, 0.5 * horn, 0.6 * thump(0.5, 100, 40, 0.15, 0.6), at=[0, 0.02, 0.35])


def c_boss_death():
	impact = mix(thump(0.9, 120, 30, 0.3, 1.0), band(noise(0.6), 60, 2000) * env(0.6, 0.001, 0.15) * 0.8)
	fall = tone(0.9, 500, 90, wave_="tri") * adsr(0.9, 0.02, 0.2, 0.5, 0.5) * 0.35
	chime = mix(*[0.35 * bell(n2f(n), 1.0, 0.35) for n in (84, 88, 91)], at=[0, 0.08, 0.16])
	return mix(impact, fall, chime, at=[0, 0.1, 0.9])


def c_pickup():
	return mix(pluck(n2f(84), 0.12, 0.5, 0.04), pluck(n2f(91), 0.16, 0.5, 0.05), at=[0, 0.05])


def drop_base(root, tier):
	"""등급별 드랍 - tier 0(일반) ~ 6(태초). 유물(4) 이상은 반짝이 · 화음 · 저음 부풀기 층이 쌓인다."""
	major = [0, 4, 7, 12, 16, 19, 24]
	nn = 2 + min(tier, 4)
	step = 0.07 - 0.005 * tier
	notes = [root + major[i] for i in range(nn)]
	layers = [arp(notes, step, 0.3, bright=0.3 + 0.1 * tier, decay=0.08 + 0.02 * tier)]
	at = [0]
	end = step * nn
	if tier >= 2:
		layers.append(0.5 * bell(n2f(root + 24), 0.7, 0.18 + 0.03 * tier))
		at.append(end)
	if tier >= 4:  # 유물+: 반짝이
		layers.append(0.6 * sparkle(0.6 + 0.1 * tier, 5 + 2 * tier))
		at.append(end)
	if tier >= 5:  # 고대+: 화음 패드
		cd = 0.9 + 0.2 * (tier - 5)
		layers.append(0.35 * chord([root, root + 4, root + 7, root + 12], cd, 0.05, 0.3, 0.5, 0.4, voice="pad"))
		at.append(end - 0.05)
	if tier >= 6:  # 태초: 저음 부풀기
		bd = 1.2
		layers.append(0.6 * tone(bd, n2f(root - 24)) * adsr(bd, 0.25, 0.2, 0.6, 0.6))
		at.append(0)
	return mix(*layers, at=at)


def c_drop_transcendent():
	# 암전 저음 쿵 → 상승 스윕 → 밝은 화음(약 2.5 s)
	boom = mix(thump(1.0, 80, 28, 0.35, 0.5), band(noise(0.8), 30, 300) * env(0.8, 0.01, 0.25) * 0.6)
	rd = 1.0
	rise = tone(rd, 110, 880, wave_="tri") * adsr(rd, 0.3, 0.2, 0.9, 0.05) * 0.3
	rise += 0.4 * sweep_lp(noise(rd), 200, 5000) * np.linspace(0, 1, int(rd * SR)) ** 2
	root = 72
	final = 0.45 * chord([root, root + 4, root + 7, root + 12, root + 16], 1.1, 0.01, 0.3, 0.55, 0.55, voice="pad")
	final += 0.5 * bell(n2f(root + 12), 1.1, 0.4)
	final = mix(final, 0.5 * sparkle(0.9, 12), 0.5 * tone(1.1, n2f(root - 24)) * adsr(1.1, 0.01, 0.3, 0.5, 0.6), at=[0, 0.05, 0])
	return mix(boom, rise, final, at=[0, 0.45, 1.4])


def c_enhance_success():
	return mix(arp([72, 76, 79], 0.06, 0.25, bright=0.5, decay=0.08), 0.6 * bell(n2f(84), 0.6, 0.18), 0.4 * sparkle(0.4, 5), at=[0, 0.18, 0.2])


def c_enhance_fail():
	# 둔탁한 "푹" + 짧게 내려가는 두 음(슬프지만 가볍게)
	thud = band(thump(0.25, 160, 80, 0.06, 0.6), None, 1500)
	s = mix(pluck(n2f(64), 0.2, 0.2, 0.06), pluck(n2f(60), 0.3, 0.2, 0.1), at=[0, 0.1])
	return mix(thud, 0.7 * s, at=[0, 0.05])


def c_enhance_drop():
	# 등급 하락 - 슬픈 하강(단조 3음 + 미끄럼)
	s = arp([67, 63, 60], 0.13, 0.35, bright=0.2, decay=0.12)
	slide = tone(0.5, n2f(60), n2f(48), wave_="tri") * adsr(0.5, 0.02, 0.1, 0.5, 0.3) * 0.3
	return mix(s, slide, at=[0, 0.3])


def c_enhance_reset():
	# 큰 추락 - 긴 하강 + 무거운 쿵
	fall = tone(0.8, 700, 70, wave_="soft_square") * adsr(0.8, 0.01, 0.2, 0.6, 0.3) * 0.25
	fall = band(fall, None, 2000)
	wind = whoosh(0.7, 3000, 300, 0.3) * 0.5
	return mix(fall, wind, thump(0.7, 120, 32, 0.22, 1.0), band(noise(0.3), 60, 1200) * env(0.3, 0.001, 0.07) * 0.5, at=[0, 0, 0.72, 0.72])


def c_protect_ticket():
	shield = mix(bell(n2f(79), 0.7, 0.22), 0.5 * bell(n2f(86), 0.6, 0.18))
	return mix(0.4 * whoosh(0.15, 800, 4000, 0.5), shield, at=[0, 0.08])


def c_level_up():
	a = arp([60, 64, 67, 72, 76, 79], 0.065, 0.3, bright=0.5, decay=0.1)
	top = 0.5 * chord([72, 76, 79, 84], 0.7, 0.01, 0.2, 0.5, 0.35)
	return mix(a, top, 0.4 * sparkle(0.5, 6), at=[0, 0.4, 0.42])


def c_codex_cell():
	return mix(bell(n2f(81), 0.6, 0.16), 0.6 * bell(n2f(88), 0.55, 0.14), at=[0, 0.07])


def c_title_get():
	# 짧은 팡파르: 딴-딴-따-다안
	notes = [(0, 67, 0.12), (0.12, 67, 0.12), (0.24, 72, 0.12), (0.36, 76, 0.6)]
	parts = [(o, (tone(d, n2f(n), wave_="soft_square") * 0.5 + tone(d, n2f(n - 12), wave_="tri") * 0.4) * adsr(d, 0.005, 0.05, 0.7, 0.06)) for o, n, d in notes]
	fan = band(seq(parts), None, 3000)
	return mix(fan, 0.4 * chord([60, 64, 67, 72], 0.6, 0.01, 0.2, 0.5, 0.3), 0.3 * sparkle(0.5, 6), at=[0, 0.36, 0.38])


def c_quest_complete():
	return mix(arp([72, 79, 76, 84], 0.09, 0.3, bright=0.4, decay=0.1), 0.35 * chord([72, 76, 79], 0.5, 0.01, 0.2, 0.5, 0.25), at=[0, 0.28])


def c_reward_fly():
	return mix(0.6 * whoosh(0.22, 600, 4000, 0.6), pluck(n2f(88), 0.14, 0.4, 0.04), at=[0, 0.16])


def c_skill_unlock():
	rise = tone(0.45, n2f(60), n2f(84), wave_="tri") * adsr(0.45, 0.05, 0.1, 0.7, 0.1) * 0.35
	reveal = mix(bell(n2f(84), 0.8, 0.25), 0.6 * bell(n2f(91), 0.7, 0.2), 0.5 * sparkle(0.6, 9))
	return mix(rise, reveal, at=[0, 0.42])


def c_button_press():
	return pluck(n2f(79), 0.07, 0.3, 0.015) + 0.3 * band(noise(0.07), 1000, 4000) * env(0.07, 0.0005, 0.004)


def c_button_close():
	return band(pluck(n2f(72), 0.08, 0.15, 0.018), None, 2500)


def c_recall_channel():
	# 반복 재생 가능한 약 1.5 s 반짝 웅(앞뒤 끝 음량을 맞춰 이음매가 튀지 않게)
	d = 1.5
	t = tt(d)
	pad = sum(tone(d, n2f(n)) * (0.6 + 0.4 * np.sin(2 * np.pi * (1 / d) * k * t + k)) for k, n in enumerate([72, 76, 79], 1))
	sh = 0.35 * sparkle(d, 10, 86, 98, d * 0.9)
	sh = fit(sh, len(t))
	return (0.4 * pad + sh) * (0.85 + 0.15 * np.cos(2 * np.pi * t / d))


def c_recall_done():
	w = whoosh(0.5, 400, 5000, 0.7)
	zap = tone(0.5, 200, 1400, wave_="tri") * adsr(0.5, 0.2, 0.1, 0.8, 0.1) * 0.3
	return mix(w + zap, 0.6 * bell(n2f(84), 0.5, 0.15), at=[0, 0.45])


def c_checkpoint_found():
	return mix(arp([76, 81, 88], 0.08, 0.4, voice=lambda f, d, **k: bell(f, d, 0.2)), 0.4 * sparkle(0.4, 5), at=[0, 0.2])


def c_checkpoint_channel():
	# 집중 웅 - 낮은 화음 + 느린 흔들림(반복 가능)
	d = 1.5
	t = tt(d)
	hum = tone(d, n2f(48)) + 0.6 * tone(d, n2f(55)) + 0.3 * tone(d, n2f(60) * 1.004)
	hum *= 0.8 + 0.2 * np.sin(2 * np.pi * 4 / d * t)
	return band(hum, None, 1500)


def c_rift_start():
	# 공간 뒤틀림 - 떨리는 하강 · 상승 스윕 + 필터 잡음
	d = 1.1
	t = tt(d)
	f = 300 * (2 ** np.sin(2 * np.pi * 0.9 * t)) * (1 + 0.04 * np.sin(2 * np.pi * 9 * t))
	w = np.sin(2 * np.pi * np.cumsum(f) / SR)
	w = (np.tanh(2 * w) + 0.4 * np.sin(2 * 2 * np.pi * np.cumsum(f) / SR)) * adsr(d, 0.1, 0.2, 0.8, 0.4) * 0.4
	return mix(w, 0.5 * whoosh(d, 300, 3000, 0.5), 0.5 * thump(0.5, 90, 40, 0.15, 0.3), at=[0, 0, 0])


def c_footstep_soft():
	return band(noise(0.08), 150, 1200) * env(0.08, 0.002, 0.018) + 0.5 * tone(0.08, 120, 70) * env(0.08, 0.001, 0.02)


# (id, 함수, 권장 음량, 소리 그룹, 설명)
SHEETS = {
	"combat": [
		("hit_light", c_hit_light, 0.55, "Effects", "일반 타격 - 톡 튀는 둔탁음"),
		("hit_heavy", c_hit_heavy, 0.7, "Effects", "내 강공격 적중 - 더 낮고 묵직함"),
		("hit_crit", c_hit_crit, 0.7, "Effects", "치명타 - 타격음 위에 반짝이는 종"),
		("swing", c_swing, 0.4, "Effects", "휘두름 바람 소리"),
		("hurt_small", c_hurt_small, 0.45, "Effects", "내가 작은 피해를 받음 - 부드럽게"),
		("hurt_big", c_hurt_big, 0.75, "Effects", "전조 있는 큰 공격에 맞음 - 무거운 쿵"),
		("heartbeat", c_heartbeat, 0.35, "Effects", "체력 낮음 심장 박동 - 낮은 두 번 쿵(은은하게)"),
		("warning", c_warning, 0.6, "Effects", "보스 전조 주의 - 짧은 두 음(사이렌 아님)"),
		("boss_appear", c_boss_appear, 0.85, "Effects", "보스 등장 - 저음 뿔 + 북"),
		("boss_death", c_boss_death, 0.9, "Effects", "보스 처치 - 큰 충격 + 하강 + 차임"),
		("footstep_soft", c_footstep_soft, 0.2, "Effects", "부드러운 발소리(선택)"),
	],
	"loot": [
		("pickup", c_pickup, 0.5, "Effects", "아이템 줍기 - 짧은 두 음 삑"),
		("drop_common", lambda: drop_base(72, 0), 0.4, "Effects", "일반 등급 드랍"),
		("drop_rare", lambda: drop_base(74, 1), 0.45, "Effects", "희귀 등급 드랍"),
		("drop_epic", lambda: drop_base(76, 2), 0.55, "Effects", "영웅 등급 드랍 - 종 추가"),
		("drop_legendary", lambda: drop_base(77, 3), 0.6, "Effects", "전설 등급 드랍"),
		("drop_relic", lambda: drop_base(72, 4), 0.7, "Effects", "유물 등급 드랍 - 반짝이 층 추가"),
		("drop_ancient", lambda: drop_base(74, 5), 0.8, "Effects", "고대 등급 드랍 - 반짝이 + 화음 층"),
		("drop_primordial", lambda: drop_base(76, 6), 0.9, "Effects", "태초 등급 드랍 - 반짝이 + 화음 + 저음 부풀기"),
		("drop_transcendent", c_drop_transcendent, 1.0, "Effects", "초월 등급 드랍 - 암전 저음 쿵 → 상승 스윕 → 밝은 화음"),
		("enhance_success", c_enhance_success, 0.8, "UI", "강화 성공 - 오르는 세 음 + 종"),
		("enhance_fail", c_enhance_fail, 0.7, "UI", "강화 실패(유지) - 둔탁음 + 내려가는 두 음"),
		("enhance_drop", c_enhance_drop, 0.75, "UI", "강화 등급 하락 - 슬픈 하강"),
		("enhance_reset", c_enhance_reset, 0.85, "UI", "강화 초기화 - 긴 추락 + 무거운 쿵"),
		("protect_ticket", c_protect_ticket, 0.7, "UI", "보호권 사용 - 방패 딩"),
		("level_up", c_level_up, 0.8, "UI", "레벨업 - 오르는 아르페지오"),
		("codex_cell", c_codex_cell, 0.6, "UI", "도감 칸 채움 - 수집 딩"),
		("title_get", c_title_get, 0.8, "UI", "칭호 획득 - 짧은 팡파르"),
		("quest_complete", c_quest_complete, 0.7, "UI", "퀘스트 완료 - 짧은 징글"),
		("reward_fly", c_reward_fly, 0.45, "UI", "보상 아이콘 날아감 - 쉭 + 삑"),
		("skill_unlock", c_skill_unlock, 0.8, "UI", "스킬 해금 - 반짝이는 공개음"),
	],
	"ui": [
		("button_press", c_button_press, 0.35, "UI", "UI 버튼 누름 - 부드러운 딸깍"),
		("button_close", c_button_close, 0.3, "UI", "창 닫기 - 더 낮고 부드러운 딸깍"),
		("recall_channel", c_recall_channel, 0.4, "Ambient", "귀환 시전 중 - 반복 가능한 반짝 웅(약 1.5초)"),
		("recall_done", c_recall_done, 0.7, "Effects", "귀환 완료 - 순간이동 쉭"),
		("checkpoint_found", c_checkpoint_found, 0.7, "Effects", "체크포인트 발견 - 발견 차임"),
		("checkpoint_channel", c_checkpoint_channel, 0.4, "Ambient", "체크포인트 등록 중 - 집중 웅(약 1.5초 · 반복 가능)"),
		("rift_start", c_rift_start, 0.8, "Effects", "균열 시작 - 뒤틀리는 스윕"),
	],
}

# 기존 SoundData.events id → 시트 큐 id(연결할 때 참고 · SoundData.lua는 이번에 고치지 않는다)
LEGACY_EVENTS = {
	"hit": "hit_light", "hitCrit": "hit_crit", "enhanceSuccess": "enhance_success", "enhanceGreat": "enhance_success",
	"enhanceFail": "enhance_fail", "levelUp": "level_up", "bossCue": "warning", "rebirth": "title_get", "petHatch": "codex_cell",
}
# ArmorData 등급 id → 드랍 큐
DROP_GRADE_CUES = {
	"normal": "drop_common", "rare": "drop_rare", "epic": "drop_epic", "legendary": "drop_legendary", "relic": "drop_relic",
	"ancient": "drop_ancient", "primordial": "drop_primordial", "transcendent": "drop_transcendent",
}


def finish(x):
	"""큐 마무리: 7 kHz 위 정리 · DC 제거 · 끝 무음 자르기 · 짧은 페이드 · 피크 -1 dBFS"""
	n0 = len(x)
	x = band(np.concatenate([np.asarray(x, dtype=np.float64), np.zeros(int(0.2 * SR))]), 25, 7000, soft=2)
	x -= x.mean()
	thr = np.max(np.abs(x)) * 1e-3
	idx = np.nonzero(np.abs(x) > thr)[0]
	x = x[: min(idx[-1] + 1, n0 + int(0.02 * SR))]  # 필터 꼬리는 원래 길이 + 20 ms까지만(반복 큐 길이 유지)
	fi, fo = int(0.002 * SR), int(0.012 * SR)
	x[:fi] *= np.linspace(0, 1, fi)
	x[-fo:] *= np.linspace(1, 0, fo)
	return x / np.max(np.abs(x)) * PEAK


def write_wav(path, x):
	pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())


def lua_num(v):
	return ("%.4f" % v).rstrip("0").rstrip(".")


def write_lua(meta):
	L = []
	L.append("-- 생성 파일(roblox/tools/audio/make_sfx.py) - 손으로 고치지 않는다. 원본 JSON = roblox/art/audio/sfx_sheet.json.")
	L.append("-- 사운드 시트: 짧은 효과음 여러 개를 파일 하나에 이어 붙였다(docs/design/v2/09-visual-gui-sound.md C절 - 오디오 업로드 한도 절약).")
	L.append("--   sheets[id].file = roblox/art 기준 경로(확장자 뺌). 업로드 뒤 에셋 id는 shared/data/ArtAssetIds.lua의 같은 키(\"audio/sfx_combat\" 등)에서 읽는다.")
	L.append("--   cues[id] = { sheet, start(초), duration(초), volume(권장 기본 음량 0 ~ 1), group(SoundGroup 이름) }.")
	L.append("--   재생 = 시트 Sound의 PlaybackRegion = NumberRange.new(start, start + duration) (PlaybackRegionsEnabled = true). 큐 사이 무음 0.3초.")
	L.append("--   모든 큐는 피크 -1 dBFS로 맞췄다 - 크기 차이는 volume으로만 준다.")
	L.append("return {")
	L.append("\tsheets = {")
	for sid in SHEETS:
		L.append("\t\t%s = { file = \"audio/sfx_%s\", length = %s }," % (sid, sid, lua_num(meta["sheets"][sid]["length"])))
	L.append("\t},")
	L.append("\tcues = {")
	for sid, cues in SHEETS.items():
		for cid, _, vol, grp, desc in cues:
			c = meta["cues"][cid]
			L.append("\t\t%s = { sheet = \"%s\", start = %s, duration = %s, volume = %s, group = \"%s\" }, -- %s" % (
				cid, sid, lua_num(c["start"]), lua_num(c["duration"]), lua_num(vol), grp, desc))
	L.append("\t},")
	L.append("\tgroups = { \"Effects\", \"UI\", \"Ambient\", \"Music\" }, -- Music = 자리만(배경 음악은 사용자 결정)")
	L.append("\t-- ArmorData 등급 id → 드랍 큐")
	L.append("\tdropGradeCues = {")
	for g, c in DROP_GRADE_CUES.items():
		L.append("\t\t%s = \"%s\"," % (g, c))
	L.append("\t},")
	L.append("\t-- 기존 SoundData.events id → 시트 큐(훅을 이 표로 옮길 때 참고)")
	L.append("\tlegacyEvents = {")
	for e, c in LEGACY_EVENTS.items():
		L.append("\t\t%s = \"%s\"," % (e, c))
	L.append("\t},")
	L.append("}")
	with open(LUA_PATH, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(L) + "\n")


def main():
	os.makedirs(OUT_DIR, exist_ok=True)
	meta = {"sampleRate": SR, "peakDbfs": -1, "gapSeconds": GAP, "sheets": {}, "cues": {}}
	for sid, cues in SHEETS.items():
		chunks = [np.zeros(int(LEAD * SR))]
		pos = len(chunks[0])
		for cid, fn, vol, grp, desc in cues:
			x = finish(fn())
			assert not np.isnan(x).any(), cid
			meta["cues"][cid] = {
				"sheet": sid, "file": "sfx_%s.wav" % sid,
				"start": round(pos / SR, 4), "duration": round(len(x) / SR, 4),
				"startSample": pos, "samples": len(x),
				"volume": vol, "group": grp, "description": desc,
			}
			chunks += [x, np.zeros(int(GAP * SR))]
			pos += len(x) + int(GAP * SR)
		sheet = np.concatenate(chunks)
		path = os.path.join(OUT_DIR, "sfx_%s.wav" % sid)
		write_wav(path, sheet)
		meta["sheets"][sid] = {"file": "sfx_%s.wav" % sid, "length": round(len(sheet) / SR, 4)}
		print("%-8s %2d cues  %6.2f s  %s" % (sid, len(cues), len(sheet) / SR, path))
	meta["dropGradeCues"] = DROP_GRADE_CUES
	meta["legacyEvents"] = LEGACY_EVENTS
	with open(os.path.join(OUT_DIR, "sfx_sheet.json"), "w", encoding="utf-8") as f:
		json.dump(meta, f, ensure_ascii=False, indent=1)
	write_lua(meta)
	print("cues:", len(meta["cues"]))


if __name__ == "__main__":
	main()
