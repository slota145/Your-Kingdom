"""Euler angles for the crossbow bone (crossbowman spec), per key, from target axes in the world:
the stock along y, the bolt groove along z (rig.euler = Ry @ Rz @ Rx, branch z near -pi).
Run in the spec folder: python3 ../../../../xbow_angles.py crossbowman.yaml"""
import sys, itertools, numpy as np
from spritekiln import spec as S
from spritekiln.anim import frames_of
from spritekiln.rig import Ctx, euler
sp = S.load(sys.argv[1])
def target(Y, Z):
    Y = np.array(Y, float); Y /= np.linalg.norm(Y); Z = np.array(Z, float); Z -= Y * (Z @ Y); Z /= np.linalg.norm(Z)
    return np.stack([np.cross(Y, Z), Y, Z], 1)
def solve(Rl):
    best = (9, None)
    g = np.arange(-np.pi, np.pi, 0.2)
    for a, b, c in itertools.product(g, g, np.arange(-3.6, -2.6, 0.1)):
        e = np.linalg.norm(euler([a, b, c]) - Rl)
        if e < best[0]: best = (e, (a, b, c))
    e, p = best; p = np.array(p); step = 0.1
    for _ in range(60):
        for i in range(3):
            for d in (-step, step):
                q = p.copy(); q[i] += d; ee = np.linalg.norm(euler(q) - Rl)
                if ee < e: e, p = ee, q
        step *= 0.85
    return e, p
REST = ([0, -0.6, 0.8], [0, 0.8, 0.6]); AIM = ([0, 0.04, 1], [0, 1, 0])
T = {('idle', None): REST, ('walk', None): REST,
     ('attack', 0): AIM, ('attack', 1): AIM, ('attack', 2): ([0, 0.15, 1], [0, 1, 0]),
     ('attack', 3): ([0, -0.7, 0.7], [0, 0.7, 0.7]), ('attack', 4): ([0, -0.95, 0.3], [0, -0.3, -0.95]),
     ('attack', 5): ([0, -0.95, 0.3], [0, -0.3, -0.95]), ('attack', 6): ([0, -0.2, 0.98], [0, 0.98, 0.2]), ('attack', 7): AIM}
for (anim, fi), (Y, Z) in T.items():
    frs = frames_of(sp, anim, 0.0); idx = [0, len(frs)//2] if fi is None else [fi]
    for k in idx:
        c = Ctx(sp, frs[k][0]); Rw = c.frame('torso_rot', 'x').R
        e, p = solve(Rw.T @ target(Y, Z))
        print(anim, k, round(e, 3), np.round(p, 2).tolist())
