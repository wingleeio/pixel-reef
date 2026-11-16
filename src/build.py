# Builds ../reef_wgsl.luau: lays out the reef (seeded, so it is the same every
# time) as WGSL constant tables, and assembles the shader sources beside this
# file (common.wgsl into ground.wgsl and live.wgsl, then show.wgsl) into one
# Luau module.
#
#   python3 src/build.py
import math, os, random, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else "../reef_wgsl.luau"
rnd = random.Random(11)
def fl(x):
    s = ("%.4f" % x).rstrip("0")
    return s + "0" if s.endswith(".") else s
def vec(a): return "vec%d<f32>(%s)" % (len(a), ", ".join(fl(x) for x in a))
def table(name, rows):
    ty = "vec%d<f32>" % len(rows[0])
    return "const %s: array<%s, %d> = array<%s, %d>(\n\t%s\n);\n" % (name, ty, len(rows), ty, len(rows), ",\n\t".join(vec(r) for r in rows))
def floor_y(x, z): return -0.75 + 0.08 * math.sin(0.9 * x + 1.0) * math.sin(0.7 * z + 0.5)
def hx(h): return [int(h[i:i+2], 16) / 255 for i in (1, 3, 5)]

# The palette: a ramp per family of things, darkest first.
TEAL = ['#050a14','#0a1730','#102848','#183c5e','#235672','#37768a','#5a9aa6','#8cbfc0','#c2e2d8','#f0faee']
WARM = ['#2a161c','#522a24','#8c5034','#c48852','#e8c08a','#f8ecd0']
GREEN = ['#0c2422','#184238','#2c6a50','#5c9c74','#a0cca4']
PINK = ['#2a1832','#562c4c','#904c6c','#c4829a','#ecbcc6']
VIOLET = ['#1c1c3e','#38346a','#62609e','#9896c8','#d0cdec']
BLUE = ['#0e2046','#1a3a70','#2e5c9c','#5888c0','#98bee2']
YELLOW = ['#4e3e24','#947840','#d0b06a','#f0deac']
PAL = TEAL + WARM + GREEN + PINK + VIOLET + BLUE + YELLOW

rocks = [
    # left tower
    (-2.55,-0.55,-0.7, .75,.5,.6), (-2.2,-0.1,-0.9,.55,.45,.5), (-2.6,0.3,-1.0,.45,.4,.42), (-2.25,0.62,-1.05,.34,.3,.32),
    (-2.5,0.9,-1.1,.22,.2,.2), (-1.7,-0.6,-0.4,.4,.28,.36), (-3.1,-0.3,-0.2,.5,.6,.5),
    # right outcrop
    (2.5,-0.55,-1.2,.8,.5,.65), (2.75,-0.05,-1.4,.55,.45,.5), (2.3,0.2,-1.5,.36,.3,.34), (1.75,-0.62,-0.9,.38,.26,.34), (3.2,-0.2,-0.6,.5,.7,.5),
    # scattered
    (-0.7,-0.72,0.6,.22,.14,.2), (0.5,-0.7,-0.6,.28,.18,.24), (1.1,-0.74,0.9,.16,.1,.15), (-0.2,-0.72,-1.8,.35,.2,.3), (-1.2,-0.74,-1.4,.2,.13,.2),
    # far off
    (-3.6,0.1,-4.6,1.3,1.6,1.1), (-1.2,-0.3,-5.4,1.2,.9,1.0), (1.8,-0.1,-5.0,1.0,1.3,.9), (4.0,0.3,-4.2,1.3,1.9,1.1),
]

def coral(base, h):
    a_rows, b_rows = [], []
    def cap(a, b, ra, rb): a_rows.append((*a, ra)); b_rows.append((*b, rb))
    top = (base[0], base[1] + h * 0.25, base[2])
    cap(base, top, 0.05, 0.04)
    mids = []
    for k in range(5):
        ang = (k - 2) * 0.5 + rnd.uniform(-0.12, 0.12)
        zz = rnd.uniform(-0.3, 0.3)
        ln = h * rnd.uniform(0.6, 0.8)
        tip = (top[0] + math.sin(ang) * ln, top[1] + math.cos(ang) * ln * 0.95, top[2] + zz * ln)
        cap(top, tip, 0.038, 0.02)
        mids.append((k, ang, tip))
    for k, ang, tip in mids + [mids[1]]:
        mid = tuple(top[i] + (tip[i] - top[i]) * 0.55 for i in range(3))
        a2 = ang + rnd.choice([-0.7, 0.7])
        ln = h * rnd.uniform(0.25, 0.38)
        cap(mid, (mid[0] + math.sin(a2) * ln, mid[1] + math.cos(a2) * ln, mid[2] + rnd.uniform(-0.1, 0.1)), 0.026, 0.015)
    return a_rows[:12], b_rows[:12], (base[0], base[1] + h * 0.6, base[2], h * 0.8 + 0.12)
corals = [coral((-1.6, -0.38, -0.3), 0.55), coral((1.7, -0.4, -0.85), 0.5), coral((-2.15, 0.28, -0.72), 0.42)]

brains = [(0.5, -0.5, -0.55, 0.19), (-0.78, -0.66, 0.62, 0.13), (2.15, floor_y(2.15, -0.3) + 0.1, -0.3, 0.17), (-1.15, -0.66, -1.3, 0.12)]
tubes = [(1.0, floor_y(1.0, 0.25) - 0.03, 0.25, 0.36), (1.14, floor_y(1.14, 0.15) - 0.03, 0.15, 0.27), (0.94, floor_y(0.94, 0.08) - 0.03, 0.08, 0.2),
         (-3.0, 0.2, -0.15, 0.3), (-2.88, 0.2, -0.05, 0.22)]
anc = (-0.45, floor_y(-0.45, -0.45) + 0.03, -0.45)
an_a, an_b = [], []
for k in range(16):
    ring = 0 if k < 10 else 1
    a = k * (6.283 / 10 if ring == 0 else 6.283 / 6) + ring * 0.4
    r0, r1, hh = (0.1, 0.22, 0.2) if ring == 0 else (0.04, 0.09, 0.26)
    hh += rnd.uniform(-0.03, 0.04)
    an_a.append((anc[0] + math.cos(a) * r0, anc[1] + 0.06, anc[2] + math.sin(a) * r0))
    an_b.append((anc[0] + math.cos(a) * r1, anc[1] + hh, anc[2] + math.sin(a) * r1))
fans = [(2.35, 0.86, -1.42, 0.36), (-2.7, 0.98, -0.85, 0.3)]
buds = [(x, floor_y(x, z) - 0.01, z) for x, z in [(-1.0, 0.9), (0.2, 0.3), (1.5, 0.55), (-0.3, -1.2), (0.9, -1.5), (-1.9, 0.5), (2.0, 0.3), (0.0, 1.3)]]

# What moves.
fish_a = [(0, .5, .25, .12), (0, .4, .2, .1), (1, .62, .34, .1), (2, .5, .32, .08), (1, .46, .25, .08), (3, 1.05, .46, .28), (2, .4, .26, .065)]
fish_b = [(0, 0, 0, .5), (0, 0, 0, .62), (.1, .8, .4, .3), (.55, .2, -.9, .2), (.8, 1.5, -2.3, .26), (.3, .05, -2.9, .1), (.15, .55, 1.2, .24)]
fish_c = [(1, 0, 1, .44), (-1, 2.4, 1, .33), (1, 1, 0, 0), (-1, 2, 0, 0), (-1, 3, 0, 0), (1, 4, 0, 0), (1, 5, 0, 0)]
jellies = [(-1.35, -1.9, 0.2, 1.0), (1.25, 0.3, 0.15, 3.3), (2.6, -2.7, 0.24, 5.1)]
kelp, klo, khi = [], [], []
for (x, z, h) in [(-2.95, 0.5, 1.7), (-2.4, 0.9, 1.25), (-1.95, -1.6, 1.5), (2.9, 0.3, 1.9), (2.3, 0.8, 1.2), (1.9, -1.9, 1.6), (0.35, -2.6, 1.3), (-0.9, -2.9, 1.0)]:
    y0 = floor_y(x, z) - 0.05
    pts = [(x, y0, z)]
    for j in range(1, 6):
        x += rnd.uniform(-0.07, 0.07); z += rnd.uniform(-0.05, 0.05)
        pts.append((x, y0 + h * j / 5, z))
    kelp += pts
    m = 0.2 + 0.08 * h * h
    xs = [p[0] for p in pts]; zs = [p[2] for p in pts]
    klo.append((min(xs) - m, y0 - 0.02, min(zs) - m)); khi.append((max(xs) + m, y0 + h + 0.08, max(zs) + m))
shafts = [(-2.7 + k * 1.05 + rnd.uniform(-0.2, 0.2), rnd.uniform(-2.2, 1.0), rnd.uniform(0.09, 0.16), rnd.uniform(0.07, 0.12)) for k in range(6)]

T = []
T.append("const N_PAL: i32 = %d;\n" % len(PAL) + table("K_PAL", [hx(c) for c in PAL]))
T.append("const N_ROCK: i32 = %d;\n" % len(rocks) + table("K_ROCK_C", [r[:3] for r in rocks]) + table("K_ROCK_R", [r[3:] for r in rocks]))
T.append("const N_CORAL: i32 = %d;\n" % len(corals) + table("K_CORAL", [c[2] for c in corals]) + table("K_BR_A", sum([c[0] for c in corals], [])) + table("K_BR_B", sum([c[1] for c in corals], [])))
T.append("const N_BRAIN: i32 = %d;\n" % len(brains) + table("K_BRAIN", brains))
T.append("const N_TUBE: i32 = %d;\n" % len(tubes) + table("K_TUBE", tubes))
T.append("const K_AN_C: vec3<f32> = %s;\n" % vec(anc) + table("K_AN_A", an_a) + table("K_AN_B", an_b))
T.append("const N_FAN: i32 = %d;\n" % len(fans) + table("K_FAN", fans))
T.append("const N_BUD: i32 = %d;\n" % len(buds) + table("K_BUD", buds))
T.append("const N_FISH: i32 = %d;\n" % len(fish_a) + table("K_FISH_A", fish_a) + table("K_FISH_B", fish_b) + table("K_FISH_C", fish_c))
T.append("const N_JELLY: i32 = %d;\n" % len(jellies) + table("K_JELLY", jellies))
T.append("const N_KELP: i32 = %d;\n" % len(klo) + table("K_KELP", kelp) + table("K_KELP_LO", klo) + table("K_KELP_HI", khi))
T.append("const N_SHAFT: i32 = %d;\n" % len(shafts) + table("K_SHAFT", shafts))
T.append("const K_VENT_A: vec3<f32> = vec3<f32>(1.0, -0.4, 0.25);\nconst K_VENT_B: vec3<f32> = vec3<f32>(-0.2, -0.55, -1.75);\n")

common = open("common.wgsl").read().replace("/*TABLES*/", "\n".join(T))
ground = common + "\n" + open("ground.wgsl").read()
live = common + "\n" + open("live.wgsl").read()
show = open("show.wgsl").read()
head = open("head.txt").read()
open(OUT, "w").write(head + "local M = {}\n\nM.GROUND = [==[\n" + ground + "]==]\n\nM.LIVE = [==[\n" + live + "]==]\n\nM.SHOW = [==[\n" + show + "]==]\n\nreturn M\n")
print("ground", len(ground), "live", len(live))
