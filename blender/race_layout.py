"""Animal race layout: where the start line, starting grid, boost rings and obstacles sit on the gravel loop.
Angles are degrees round the zoo centre in Blender XY (Roblox: x = r*cos(a), z = -r*sin(a)); lateral = studs from the
centre line (150), + = outward. Racers run toward increasing angle (anticlockwise seen from above in Blender, which is
clockwise seen from above in Studio). ZooRace.server.luau carries the same numbers."""
import math

CENTRE_R = 150.0
START_A = 84.0                                     # start/finish line, just east of the gate (gate is at 90)
GRID = [(START_A - 2.0 - 2.4 * row, lat) for row in range(2) for lat in (-7.5, -2.5, 2.5, 7.5)]
RINGS = [(110, -7), (140, 7), (175, 0), (205, -8), (235, 6), (270, -6), (300, 8), (330, -2), (355, 7), (25, -7), (52, 5)]
OBSTACLES = [("RaceLog", 125, 6), ("RaceHay", 152, -8), ("RaceMud", 160, 4), ("RaceRocks", 190, 8), ("RaceLog", 220, -6),
             ("RaceMud", 250, 0), ("RaceHay", 262, 9), ("RaceRocks", 285, -9), ("RaceLog", 315, 5), ("RaceMud", 345, -5),
             ("RaceHay", 10, 2), ("RaceRocks", 40, -9), ("RaceLog", 66, -5)]
PAD = (30.0, -100.0, 90.0)                         # sign-up pad, Roblox x, z and yaw (board on the east side, facing the path)


def spot(a_deg, lat):
    """Blender (x, y) of a point on the track."""
    a = math.radians(a_deg)
    return ((CENTRE_R + lat) * math.cos(a), (CENTRE_R + lat) * math.sin(a))


if __name__ == "__main__":
    # self-check: nothing on the grid, rings and obstacles keep 9 studs apart along the loop
    pts = [("ring", a, l) for a, l in RINGS] + [(n, a, l) for n, a, l in OBSTACLES] + [("grid", a, l) for a, l in GRID]
    for i, p in enumerate(pts):
        for q in pts[i + 1:]:
            if p[0] == q[0] == "grid": continue
            d = math.dist(spot(p[1], p[2]), spot(q[1], q[2]))
            assert d > 9, (p, q, round(d, 1))
    assert all(abs(l) <= 9 for _, l in RINGS) and all(abs(l) <= 9 for _, _, l in OBSTACLES)
    print("layout ok:", len(RINGS), "rings,", len(OBSTACLES), "obstacles")
