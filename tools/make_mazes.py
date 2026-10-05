#!/usr/bin/env python3
"""Generates maze_data.gd: the pacman clone's extra mazes (Ms. Pac-Man style).

Maze 0 is the original maze (read from maze_grid_array.gd). Mazes 1.. keep the
original's fixed skeleton - ghost house, tunnel row 13, the middle band rows
8-18 (so NO_UP cells, spurs, start strip and power-pill spots stay valid) -
and re-generate the top (rows 1-7) and bottom (rows 19-28) areas with random
wall blocks (left half mirrored), plus per-maze extra side corridors.

Rules checked here and again by _selftest.gd: every free cell reachable, no
dead ends, no 2x2 free area, power pills + start strip free.

  python3 tools/make_mazes.py          # rewrites maze_data.gd
"""
import random, re, sys, collections, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
COLS = ROWS = 30

def base_grid():
    src = (ROOT / "maze_grid_array.gd").read_text()
    m = re.search(r"const GRID := \[(.*?)\n\]\n", src, re.S)
    rows = re.findall(r"\[([0-9, ]+)\]", m.group(1))
    return [[int(v) for v in r.split(",")] for r in rows]

BASE = base_grid() if "GRID := [" in (ROOT / "maze_grid_array.gd").read_text() else None

def load_base():
    if BASE:
        return BASE
    data = (ROOT / "maze_data.gd").read_text()
    first = re.search(r'MAZE_0 := \[(.*?)\]\n', data, re.S).group(1)
    rows = re.findall(r'"([#.]+)"', first)
    return [[0 if c == "." else 1 for c in r] for r in rows]

BASEG = load_base()

REQUIRED_FREE = [(2, 3), (27, 3), (2, 25), (27, 25)] + \
    [(x, 7) for x in (7, 13, 16, 22)] + [(x, 19) for x in (7, 10, 19, 22)] + \
    [(x, 22) for x in range(7, 23)]

def free(g, x, y):
    return 0 <= x < COLS and 0 <= y < ROWS and g[y][x] == 0

def neighbors(g, x, y):
    return sum(free(g, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))

def connected(g):
    cells = [(x, y) for y in range(ROWS) for x in range(COLS) if g[y][x] == 0]
    seen = {cells[0]}
    q = collections.deque([cells[0]])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n[1] == 13 and n[0] == -1: n = (COLS - 1, 13)
            if n[1] == 13 and n[0] == COLS: n = (0, 13)
            if free(g, *n) and n not in seen:
                seen.add(n); q.append(n)
    return len(seen) == len(cells)

def region(y):
    return (1 <= y <= 7) or (19 <= y <= 28)

def dead_ends(g):
    bad = []
    for y in range(ROWS):
        for x in range(COLS):
            if g[y][x] == 0 and region(y) and neighbors(g, x, y) <= 1:
                bad.append((x, y))
    return bad

def two_by_two(g):
    out = []
    for y in range(1, 28):
        for x in range(1, 29):
            if all(free(g, x + a, y + b) for a in (0, 1) for b in (0, 1)) and (region(y) or region(y + 1)):
                if not (11 <= x <= 18 and 10 <= y <= 15):
                    out.append((x, y))
    return out

def mirror(g):
    for y in range(ROWS):
        for x in range(15):
            g[y][29 - x] = g[y][x]

def pick(rnd, required, optional, lo, hi, min_gap=3):
    """Random corridor positions in [lo, hi]: all `required`, plus a random
    subset of `optional`, neighbours at least `min_gap` apart (so every wall
    block is >= 2 thick)."""
    chosen = set(required)
    opts = list(optional); rnd.shuffle(opts)
    for o in opts:
        if rnd.random() < 0.6 and all(abs(o - c) >= min_gap for c in chosen):
            chosen.add(o)
    return sorted(chosen)

def make(seed, carve):
    rnd = random.Random(seed)
    for attempt in range(600):
        g = [row[:] for row in BASEG]
        for y in range(ROWS):
            if region(y):
                for x in range(2, 28):
                    g[y][x] = 1
        keep = set(REQUIRED_FREE)
        for (x, y) in carve:
            g[y][x] = 0; g[y][29 - x] = 0
            keep.add((x, y)); keep.add((29 - x, y))
        # lattice of 1-wide corridors, left half; mirrored below
        top_rows = pick(rnd, [1, 7], [3, 4, 5], 1, 7)
        bot_rows = pick(rnd, [19, 22, 28], [25, 26], 19, 28)
        top_cols = pick(rnd, [2, 7, 13], [4, 5, 10, 11], 2, 13)
        bot_cols = pick(rnd, [2, 7, 10], [4, 5, 12, 13], 2, 13)
        segs = []   # list of cell lists (corridor pieces between junctions)
        for rows, cols, (ya, yb) in ((top_rows, top_cols, (1, 7)), (bot_rows, bot_cols, (19, 28))):
            for y in rows:
                for x in range(2, 14):
                    g[y][x] = 0
            for x in cols:
                for y in range(ya, yb + 1):
                    g[y][x] = 0
            for y in rows:                       # horizontal pieces
                xs = [x for x in cols] + [14]
                for i in range(len(cols)):
                    segs.append([(x, y) for x in range(cols[i] + 1, xs[i + 1])])
            for x in cols:                       # vertical pieces
                for i in range(len(rows) - 1):
                    segs.append([(x, y) for y in range(rows[i] + 1, rows[i + 1])])
        for (x, y) in keep:
            g[y][x] = 0
        mirror(g)
        # the centre column pair must stay wall (no 2-wide corridor)
        for y in range(ROWS):
            if region(y):
                g[y][14] = g[y][15] = 1
        for (x, y) in keep:
            g[y][x] = 0
        rnd.shuffle(segs)
        for seg in segs:
            seg = [c for c in seg if c[0] < 14]
            if not seg or any(c in keep for c in seg) or rnd.random() > 0.55:
                continue
            t = [row[:] for row in g]
            for (x, y) in seg:
                t[y][x] = 1
            mirror(t)
            if dead_ends(t) or not connected(t):
                continue
            g = t
        # carve a few short passages through thick wall blocks (loops, like Ms. Pac-Man)
        cands = []
        for y in range(1, 29):
            for x in range(2, 14):
                if not region(y) or g[y][x] != 1:
                    continue
                for (dx, dy) in ((1, 0), (0, 1)):
                    for L in (2, 3):
                        run = [(x + dx * i, y + dy * i) for i in range(L)]
                        ex, ey = x + dx * L, y + dy * L
                        if not (0 <= ex < 14 and ey < 29 and free(g, ex, ey) and free(g, x - dx, y - dy)):
                            continue
                        if any(not region(c[1]) or g[c[1]][c[0]] != 1 for c in run):
                            continue
                        cands.append(run)
        rnd.shuffle(cands)
        carved = 0
        for run in cands:
            if carved >= rnd.randint(2, 4):
                break
            t = [row[:] for row in g]
            for (x, y) in run:
                t[y][x] = 0
            mirror(t)
            if two_by_two(t) or dead_ends(t) or not connected(t):
                continue
            g = t; carved += 1
        if two_by_two(g) or dead_ends(g) or not connected(g):
            continue
        if any(g[y][x] != 0 for (x, y) in REQUIRED_FREE):
            continue
        if g == BASEG:
            continue
        return g
    raise SystemExit("no valid maze for seed %d" % seed)

SPECS = [
    # (seed, extra side corridors (left half, mirrored))
    (11, []),
    (23, [(3, 8), (3, 9), (3, 10), (3, 11), (3, 12), (3, 7)]),
    (37, [(4, 14), (4, 15), (4, 16), (4, 17), (4, 18), (4, 19), (4, 13)]),
    (51, [(3, 8), (3, 9), (3, 10), (3, 11), (3, 12), (3, 7),
          (4, 14), (4, 15), (4, 16), (4, 17), (4, 18), (4, 19)]),
]

def to_rows(g):
    return ["".join("#" if v else "." for v in r) for r in g]

def main():
    mazes = [to_rows(BASEG)]
    for seed, carve in SPECS:
        mazes.append(to_rows(make(seed, carve)))
    out = ["# GENERATED by tools/make_mazes.py - do not edit by hand.",
           "# '#' = wall, '.' = walkable. 30x30 each; MAZE_0 is the original maze.",
           "class_name MazeData", ""]
    for i, rows in enumerate(mazes):
        out.append("const MAZE_%d := [" % i)
        out += ['\t"%s",' % r for r in rows]
        out.append("]\n")
    out.append("const ALL := [MAZE_0, MAZE_1, MAZE_2, MAZE_3, MAZE_4]\n")
    (ROOT / "maze_data.gd").write_text("\n".join(out))
    for i, rows in enumerate(mazes[1:], 1):
        print("maze", i); print("\n".join(rows))

if __name__ == "__main__":
    main()
