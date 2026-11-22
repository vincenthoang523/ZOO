"""Draw a Zoo - low-poly kit builder. Run inside Blender (5.x):
    exec(open(r"...\\blender\\build_zoo_kit.py").read())
Builds every piece in its own scene "ZooKit" (never touches other scenes), writes
export/ZooKit.glb, export/ZooKit_stats.json and renders/<Piece>.png.

Conventions: 1 Blender unit = 1 stud, Z up, +Y is the FRONT of a piece (Roblox -Z).
Each piece is an Empty with one child mesh per colour, named "<Piece>__<colour>";
Studio sets MeshPart.Color from that suffix, so plots can re-tint "accent"/"glow".
Look: 1-segment bevel + weighted normals = flat faces with a soft highlight on every edge.
"""
import bpy, bmesh, math, json, os, random
from mathutils import Vector, Matrix

OUT = os.path.join(r"C:\Users\polli\Downloads\claude files and projects\roblox\zoo", "blender")
PAL = dict(grass="7CC86E", grassDark="5FB35A", leaf="46A050", leafLight="6FCB5F", sand="F4E0AA", sandDark="E3C98A",
           wood="8C5A32", cream="FFF6E1", stone="D9D4C7", sky="96D6EB", yellow="FFD046", red="E8574F",
           dark="3C2D23", iron="4A4E57", accent="FF9A3C", glow="FFE08A", earth="D9C48A", rock="BDB7A8", bush="3F9A4A", water="6FC8F0", paw="FFF6E1", cap="8C5A32", leafDark="2F8A45", woodDark="6E4526", pink="FF7FB0",
           plank="D6A161", plankAlt="C38E55", ink="26262B", zebra="F7F3EA", rope="C9A46A", hay="F2C94C",
           khaki="DEC696", khakiDark="B89B62", olive="6E7A3E", oliveDark="4F5A2B", brass="E0B040", glass="9ED8F0",
           screen="1E2840", blue="4AA3F0", dirt="D9A066", gold="F2B233", bulb="FFF1C2",
           cliff="E6E1D3", cliffDark="C9C2B2", moss="7CC86E", waterDeep="4FB2E3", foam="EAF8FF", ripple="EAF8FF",
           gravel="BDB19C", gravelDark="AEA18B", pebble="8E8474", pebbleLight="DDD5C4", mud="7A5235", mudWet="5A3A24",
           boost="3FD8FF", boostLight="E8FBFF", meadow="8DC266", meadowDark="7AB257")
I = Matrix.Identity(4)


def T(x=0.0, y=0.0, z=0.0): return Matrix.Translation((x, y, z))
def Rx(d): return Matrix.Rotation(math.radians(d), 4, 'X')
def Ry(d): return Matrix.Rotation(math.radians(d), 4, 'Y')
def Rz(d): return Matrix.Rotation(math.radians(d), 4, 'Z')
def S(x, y, z): return Matrix.Diagonal((x, y, z, 1))


def rrect(w, d, r, n=3):
    """Rounded rectangle outline in XY, centred."""
    pts = []
    for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def mat(color):
    h = PAL[color]
    m = bpy.data.materials.get("Zoo_" + color)
    if m:   # keep it in step with PAL, so a retuned colour shows up in renders saved with the .blend
        m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*[((int(h[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4)], 1)
        return m
    m = bpy.data.materials.new("Zoo_" + color)
    lin = [((int(h[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4)]
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = 0.85
    if color == "glow":
        b.inputs["Emission Color"].default_value = (*lin, 1)
        b.inputs["Emission Strength"].default_value = 2.0
    return m


class Piece:
    def __init__(self, name, bevel=0.15, flat=(), bevels=None):
        self.name, self.parts, self.bevel, self.flat, self.bevels = name, {}, bevel, set(flat), bevels or {}

    def _take(self, color, bm, M):
        bm.transform(M)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me); bm.free()
        self.parts.setdefault(color, bmesh.new()).from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, color, size, M=I):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bm.transform(S(*size))
        self._take(color, bm, M)

    def ico(self, color, r, sub, M=I, jitter=0.0, seed=0):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
        rnd = random.Random(seed)
        for v in bm.verts: v.co *= 1 + rnd.uniform(-jitter, jitter)
        self._take(color, bm, M)

    def blob(self, r, sub, M=I, lobes=6, amp=0.3, seed=0, floor=-0.5, colors=("leafLight", "leaf", "leafDark"), up=0.72, down=-0.3, sharp=3):
        """One continuous leaf mass, never stacked spheres: an icosphere pushed out by a few soft lobes and
        flattened underneath. Faces are coloured by facing (light on top, dark below) but share every vertex,
        so it still reads as one shape. Returns the surface vertices as (position, normal) for seating details."""
        rnd = random.Random(seed)
        L = []
        for _ in range(lobes):
            a, el = rnd.uniform(0, 2 * math.pi), rnd.uniform(-0.15, 1.25)
            L.append((Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el))), rnd.uniform(0.6, 1.0)))
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1)
        for v in bm.verts:
            d = v.co.normalized()
            v.co = d * (1 + amp * sum(w * max(0.0, d.dot(l)) ** sharp for l, w in L))
            v.co.z = max(v.co.z, floor)
        bm.transform(M @ S(r, r, r))
        bm.normal_update()
        surface = [(v.co.copy(), v.normal.copy()) for v in bm.verts]
        for color in colors:
            part = bm.copy()
            want = {"top": lambda n: n > up, "low": lambda n: n < down, "mid": lambda n: down <= n <= up}
            keep = want[("top", "mid", "low")[colors.index(color)]]
            bmesh.ops.delete(part, geom=[f for f in part.faces if not keep(f.normal.z)], context='FACES')
            bmesh.ops.delete(part, geom=[v for v in part.verts if not v.link_faces], context='VERTS')
            me = bpy.data.meshes.new("tmp")   # no normal recalculation: an open patch could flip, the sphere's winding is already outward
            part.to_mesh(me); part.free()
            self.parts.setdefault(color, bmesh.new()).from_mesh(me)
            bpy.data.meshes.remove(me)
        bm.free()
        return surface

    def lathe(self, color, prof, seg, M=I, closed=False):
        """Revolve (radius, z) points around Z. r=0 collapses to one vertex; open ends get caps."""
        bm = bmesh.new()
        rings = []
        for r, z in prof:
            if r <= 1e-6: rings.append([bm.verts.new((0, 0, z))])
            else: rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
        pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
        for A, B in pairs:
            for i in range(seg):
                j = (i + 1) % seg
                if len(A) == 1 and len(B) == 1: continue
                if len(A) == 1: bm.faces.new((A[0], B[i], B[j]))
                elif len(B) == 1: bm.faces.new((A[i], A[j], B[0]))
                else: bm.faces.new((A[i], A[j], B[j], B[i]))
        if not closed:
            for ring in (rings[0], rings[-1]):
                if len(ring) > 1: bm.faces.new(ring)
        self._take(color, bm, M)

    def extrude(self, color, pts, depth, M=I, plane='XZ'):
        """Extrude a 2D outline. XZ: silhouette, centred on Y. XY: slab from z=0 to depth."""
        bm = bmesh.new()
        if plane == 'XZ':
            a = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
            b = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
        else:
            a = [bm.verts.new((x, y, 0)) for x, y in pts]
            b = [bm.verts.new((x, y, depth)) for x, y in pts]
        bm.faces.new(a); bm.faces.new(b)
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
        self._take(color, bm, M)

    def mesh(self, color, verts, faces, M=I):
        """Raw geometry: vertex list + faces as index tuples (winding is fixed up afterwards)."""
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in verts]
        for f in faces: bm.faces.new([vs[i] for i in f])
        self._take(color, bm, M)

    def limb(self, color, a, b, r1, r2, seg=6):
        """Tapered trunk/branch segment from point a to point b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        self.lathe(color, [(r1, 0), (r2, d.length)], seg, Matrix.Translation(a) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())

    def tube(self, color, pts, radii, seg=7):
        """One continuous tapered trunk through several points. Each joint gets a single shared ring tilted
        halfway between the two segments, so bends have no gaps or notches."""
        P = [Vector(p) for p in pts]
        tangents = []
        for i in range(len(P)):
            a, b = P[max(i - 1, 0)], P[min(i + 1, len(P) - 1)]
            tangents.append((b - a).normalized())
        side = tangents[0].orthogonal().normalized()
        bm = bmesh.new()
        rings = []
        for i, (c, t, r) in enumerate(zip(P, tangents, radii)):
            side = (side - t * side.dot(t)).normalized()   # carry the frame along, so the tube never twists
            fwd = t.cross(side)
            rings.append([bm.verts.new(c + (side * math.cos(2 * math.pi * k / seg) + fwd * math.sin(2 * math.pi * k / seg)) * r) for k in range(seg)])
        for A, B in zip(rings, rings[1:]):
            for k in range(seg):
                j = (k + 1) % seg
                bm.faces.new((A[k], A[j], B[j], B[k]))
        bm.faces.new(rings[0]); bm.faces.new(rings[-1])
        self._take(color, bm, I)

    def frame(self, color, outer, inner, h, M=I):
        """A flat ring (curb) between two XY outlines with the same point count, from z=0 to h."""
        bm = bmesh.new()
        rings = [[bm.verts.new((x, y, z)) for x, y in pts] for pts, z in ((outer, 0), (outer, h), (inner, h), (inner, 0))]
        n = len(outer)
        for A, B in zip(rings, rings[1:] + rings[:1]):
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((A[i], A[j], B[j], B[i]))
        self._take(color, bm, M)

    def build(self, origin, coll):
        root = bpy.data.objects.new(self.name, None)
        root.location = origin
        root.empty_display_size = 2
        coll.objects.link(root)
        objs = []
        for color, bm in self.parts.items():
            me = bpy.data.meshes.new(f"{self.name}__{color}")
            bm.to_mesh(me); bm.free()
            ob = bpy.data.objects.new(me.name, me)
            coll.objects.link(ob)
            ob.parent = root
            me.materials.append(mat(color))
            flat = color in self.flat
            for p in me.polygons: p.use_smooth = not flat
            if not flat:
                w = self.bevels.get(color, self.bevel)
                if w > 0:
                    m = ob.modifiers.new("Bevel", "BEVEL")
                    m.width, m.segments, m.limit_method, m.angle_limit, m.harden_normals = w, 1, 'ANGLE', math.radians(40), True
                ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL").keep_sharp = False
            objs.append(ob)
        return root, objs


# ----------------------------------------------------------------- pieces
WF_X, WF_LIP = -7.4, 7.2            # waterfall centre x and the height of its lip (Studio reads these for the VFX)
POND_Y = -9.9                        # pond centre y (front/back), pond surface top at z 0.72


def _remeshed(bm, voxel, ratio):
    """Fuse overlapping shells into ONE closed surface (voxel remesh), then collapse it down to big low-poly facets."""
    me = bpy.data.meshes.new("tmp_fuse"); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("tmp_fuse", me)
    bpy.context.scene.collection.objects.link(ob)
    r = ob.modifiers.new("Remesh", "REMESH"); r.mode, r.voxel_size, r.adaptivity = 'VOXEL', voxel, 0.0
    d = ob.modifiers.new("Decimate", "DECIMATE"); d.ratio = ratio
    f = ob.modifiers.new("Facets", "DECIMATE"); f.decimate_type, f.angle_limit = 'DISSOLVE', math.radians(9)   # slivers -> broad facets
    bpy.context.view_layer.update()
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    out = bmesh.new(); out.from_mesh(ev.to_mesh()); ev.to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True); bpy.data.meshes.remove(me)
    return out


def _paint(p, bm, pick):
    """Split one surface into colour meshes face by face (pick(face) -> colour); vertices stay where they are."""
    bm.normal_update()
    bm.faces.index_update()
    want = [pick(f) for f in bm.faces]
    for color in set(want):
        part = bm.copy()
        part.faces.ensure_lookup_table()
        bmesh.ops.delete(part, geom=[f for f in part.faces if want[f.index] != color], context='FACES')
        bmesh.ops.delete(part, geom=[v for v in part.verts if not v.link_faces], context='VERTS')
        me = bpy.data.meshes.new("tmp"); part.to_mesh(me); part.free()
        p.parts.setdefault(color, bmesh.new()).from_mesh(me)
        bpy.data.meshes.remove(me)
    bm.free()


def _rock_wall(p):
    """Back cliff: a solid backbone wall with low-poly boulders pushed half into its face and crest, fused into one
    rock surface. A flat-bottomed notch at WF_X is the waterfall's channel. Grass tops, two stone tones on the sides."""
    def crest(x):
        base = 8.4 + 1.1 * math.sin(x * 0.45 + 0.8) + 2.0 * (abs(x) / 16) ** 2
        w = min(1.0, max(0.0, (2.4 - abs(x - WF_X)) / 0.8))      # 1 inside the channel, easing out over 0.8 studs
        return base - (base - WF_LIP) * w
    bm = bmesh.new()
    xs = [-16.2 + 32.4 * i / 40 for i in range(41)]
    prof = [(-16.2, 0.3)] + [(x, crest(x)) for x in xs] + [(16.2, 0.3)]
    a = [bm.verts.new((x, -14.3, z)) for x, z in prof]
    b = [bm.verts.new((x, -11.4, z)) for x, z in prof]
    bm.faces.new(a); bm.faces.new(b)
    for i in range(len(prof)):
        j = (i + 1) % len(prof)
        bm.faces.new((a[i], a[j], b[j], b[i]))
    rnd = random.Random(7)

    def boulder(c, r, sq=(1.25, 0.85, 1.0)):
        t = bmesh.new()
        bmesh.ops.create_icosphere(t, subdivisions=1, radius=r)
        for v in t.verts: v.co *= 1 + rnd.uniform(-0.18, 0.18)
        t.transform(T(*c) @ Rz(rnd.uniform(-25, 25)) @ S(*sq))
        me = bpy.data.meshes.new("tmp"); t.to_mesh(me); t.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    gap = lambda x, w: abs(x - WF_X) < w
    x = -15.2
    while x < 15.6:                                              # crest boulders, half sunk into the top
        if not gap(x, 2.3): boulder((x, rnd.uniform(-13.3, -12.3), crest(x) - 0.4), rnd.uniform(1.7, 2.3))
        x += rnd.uniform(2.3, 3.0)
    for s in (-1, 1): boulder((WF_X + s * 2.9, -12.0, crest(WF_X + s * 2.9) + 0.3), 1.9, (1.0, 0.9, 1.2))   # gorge walls
    # back of the pool: rock rising behind the channel, so the water wells out of the cliff instead of a cut-off slab
    boulder((WF_X, -13.7, WF_LIP + 1.0), 1.8, (1.35, 0.9, 1.0))
    for s in (-1, 1): boulder((WF_X + s * 1.5, -13.4, WF_LIP + 0.4), 1.4, (1.0, 0.9, 1.0))
    x = -14.8
    while x < 15.4:                                              # face boulders, centres on the wall face
        for z in (2.6, 5.4):
            if not gap(x, 2.6) and z < crest(x) - 1.2:
                boulder((x + rnd.uniform(-0.6, 0.6), -11.5, z + rnd.uniform(-0.5, 0.5)), rnd.uniform(1.5, 2.0))
        x += rnd.uniform(2.6, 3.4)
    for x in (-15.0, -1.4, 1.8, 5.2, 8.8, 12.4, 15.0):            # foot boulders, kept out of the pond
        boulder((x, -10.9, 0.5), rnd.uniform(1.1, 1.5), (1.3, 1.0, 0.8))
    surf = _remeshed(bm, 0.5, 0.05)

    def pick(f):
        n, cz = f.normal, f.calc_center_median().z
        if n.z > 0.8 and cz > 2.0: return "moss"
        return "cliffDark" if n.z < -0.05 or f.index % 4 == 0 else "cliff"
    _paint(p, surf, pick)


def _waterfall(p):
    """Water sheet that starts inside the channel, rolls over the lip and drops into the pond; foam on the lip and at
    the base, a ripple ring Studio animates, and a stone-rimmed pond that runs back into the cliff foot."""
    path = [(-12.7, WF_LIP + 0.15), (-11.7, WF_LIP + 0.2), (-11.0, WF_LIP + 0.05), (-10.6, WF_LIP - 0.6),
            (-10.45, WF_LIP - 1.6), (-10.4, 3.0), (-10.4, 0.5)]
    verts, faces, th = [], [], 0.14
    for i, (y, z) in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        t = Vector((b[0] - a[0], b[1] - a[1])).normalized()
        n = Vector((-t.y, t.x)) if -t.y >= 0 else Vector((t.y, -t.x))      # sheet normal in (y, z), pointing to the front
        w = 1.4 + 0.3 * (1 - z / WF_LIP)                                       # widens a little as it falls
        for sx in (-1, 1):
            for sn in (1, -1):
                verts.append((WF_X + sx * w, y + n.x * th * sn, z + n.y * th * sn))
    for i in range(len(path) - 1):
        q, r = 4 * i, 4 * i + 4
        for k0, k1 in ((0, 2), (2, 3), (3, 1), (1, 0)):
            faces.append((q + k0, q + k1, r + k1, r + k0))
    last = 4 * (len(path) - 1)
    faces += [(0, 1, 3, 2), (last, last + 2, last + 3, last + 1)]
    p.mesh("water", verts, faces)
    p.tube("foam", [(WF_X - 1.7, -11.05, WF_LIP + 0.1), (WF_X, -10.95, WF_LIP + 0.28), (WF_X + 1.7, -11.05, WF_LIP + 0.1)], [0.32, 0.42, 0.32], 6)
    p.lathe("foam", [(1.3, 0.6), (2.0, 0.66), (1.9, 0.98), (1.2, 0.86)], 10, T(WF_X, -10.2, 0) @ S(1.25, 0.75, 1), closed=True)
    p.lathe("ripple", [(2.3, 0.66), (2.55, 0.66), (2.55, 0.76), (2.3, 0.76)], 14, T(WF_X, -10.0, 0) @ S(1.25, 0.75, 1), closed=True)
    inner = rrect(9.6, 4.6, 1.6)
    p.frame("stone", rrect(10.8, 5.4, 2.0), inner, 0.48, T(WF_X, POND_Y - 0.4, 0.42))
    p.extrude("waterDeep", inner, 0.3, T(WF_X, POND_Y - 0.4, 0.42), 'XY')


def enclosure():
    """Animal pen laid out in the plot's Pen space (Blender x = Pen x, Blender -y = Pen z, z up; front is +y).
    Stone curb with a cream cap, a rounded fence with lantern corner pillars, the rock cliff and waterfall at the back,
    and a gateway of round pillars, curved knee braces, a beam, a scalloped awning and a paw sign. "accent" is re-tinted
    per plot in Studio. Every piece overlaps the next one; floating_report() must come back empty."""
    p = Piece("Enclosure", bevel=0.12, flat=("cliff", "cliffDark", "moss"),
              bevels={"stone": 0.2, "cream": 0.12, "wood": 0.15, "woodDark": 0.12, "accent": 0.06, "yellow": 0.0, "glow": 0.0,
                      "water": 0.04, "waterDeep": 0.0, "foam": 0.0, "ripple": 0.0, "grass": 0.0, "sand": 0.0, "leafLight": 0.0,
                      "plank": 0.06, "hay": 0.0, "paw": 0.0})
    disc = lambda col, x, y, z, r, h=0.06, sx=1.0, seg=14: p.lathe(col, [(r, 0), (r, h)], seg, T(x, y, z) @ S(sx, 1, 1))
    off = lambda pts, dy: [(x, y + dy) for x, y in pts]

    # plinth, curb (pen at y -10.5..10.5 inside, back curb under the cliff), cream cap, lawn
    p.extrude("stone", rrect(36.8, 26.8, 1.6), 0.42, T(0, -1.5, 0), 'XY')
    p.frame("stone", rrect(36.0, 26.0, 1.4), off(rrect(31.0, 21.0, 0.8), 1.5), 1.15, T(0, -1.5, 0.3))
    p.frame("cream", rrect(36.4, 26.4, 1.5), off(rrect(30.6, 20.6, 0.7), 1.5), 0.35, T(0, -1.5, 1.4))
    p.extrude("grass", rrect(31.2, 21.2, 0.9), 0.16, T(0, 0, 0.3), 'XY')
    disc("sand", 4.6, 2.2, 0.44, 3.1, sx=1.3)
    disc("sand", 8.6, 4.6, 0.44, 1.7, sx=1.2)
    disc("leafLight", -4.6, 4.0, 0.44, 2.4, h=0.05, sx=1.3)
    disc("leafLight", 1.0, -3.8, 0.44, 1.6, h=0.05, sx=1.2)

    # fence: round posts with an accent collar and a cream dome, two round rails running through every post
    FY, SX, CAP = 10.95, 16.7, 1.75

    def post(x, y):
        p.lathe("wood", [(0.42, CAP - 0.1), (0.42, 3.75), (0, 3.75)], 8, T(x, y, 0))
        p.lathe("accent", [(0.52, 3.45), (0.52, 3.8), (0, 3.8)], 8, T(x, y, 0))
        p.lathe("cream", [(0.5, 3.75), (0.5, 3.95), (0.34, 4.25), (0, 4.38)], 8, T(x, y, 0))
    for x in (-12.5, -8.3, -4.15, 0, 4.15, 8.3, 12.5): post(x, FY)
    for y in (6.5, 2.0, -2.5, -7.0):
        for s in (-1, 1): post(s * SX, y)
    for z in (2.5, 3.25):
        p.limb("plank", (-SX, FY, z), (SX, FY, z), 0.2, 0.2, 8)
        for s in (-1, 1): p.limb("plank", (s * SX, FY, z), (s * SX, -11.8, z), 0.2, 0.2, 8)
    # front corner pillars with lanterns
    for s in (-1, 1):
        L = T(s * SX, FY, 0)
        p.lathe("stone", [(1.0, CAP - 0.1), (1.0, 2.1), (0.8, 2.35), (0.8, 4.9), (0, 4.9)], 10, L)
        p.lathe("accent", [(0.9, 3.4), (0.9, 3.9), (0, 3.9)], 10, L)
        p.lathe("cream", [(1.05, 4.85), (1.05, 5.2), (0, 5.2)], 10, L)
        p.lathe("woodDark", [(0.6, 5.15), (0.6, 5.4), (0, 5.4)], 8, L)
        p.lathe("glow", [(0, 5.3), (0.42, 5.45), (0.5, 5.95), (0.4, 6.35), (0, 6.45)], 8, L)
        p.lathe("woodDark", [(0.78, 6.25), (0.78, 6.42), (0, 7.0)], 8, L)

    _rock_wall(p)
    _waterfall(p)

    # feeding trough against the left fence
    tx, ty = -13.4, -1.0
    for dx in (-0.75, 0.75):
        for dy in (-1.4, 1.4): p.box("woodDark", (0.34, 0.34, 0.75), T(tx + dx, ty + dy, 0.75))
    p.box("wood", (2.0, 3.5, 0.85), T(tx, ty, 1.45))
    p.box("plank", (2.25, 3.75, 0.2), T(tx, ty, 1.9))
    p.box("hay", (1.6, 3.1, 0.3), T(tx, ty, 2.05))

    # gateway over the back: round pillars, knee braces, beam, cornice, awning, sign, finials
    PY = -12.5
    for s in (-1, 1):
        L = T(s * 17, PY, 0)
        p.lathe("stone", [(1.7, CAP - 0.1), (1.7, 2.6), (1.3, 3.0), (0, 3.0)], 12, L)
        p.lathe("cream", [(1.2, 2.9), (1.2, 16.2), (0, 16.2)], 12, L)
        for z in (6.0, 11.0): p.lathe("accent", [(1.32, z), (1.32, z + 0.6), (0, z + 0.6)], 12, L)
        p.lathe("woodDark", [(1.25, 15.5), (1.65, 16.0), (1.65, 16.65), (0, 16.65)], 12, L)
        brace = [(15.95, 12.6), (15.95, 16.6), (12.5, 16.6)] + [(12.5 + 3.45 * math.cos(math.radians(a)), 12.6 + 4.0 * math.sin(math.radians(a))) for a in range(80, 0, -16)]
        p.extrude("wood", [(s * x, z) for x, z in brace], 0.8, T(0, PY, 0))
        p.lathe("yellow", [(0, 19.2), (0.8, 19.5), (1.1, 20.2), (0.8, 20.9), (0, 21.2)], 10, T(s * 17, PY, 0))
    p.box("wood", (39.0, 3.0, 2.4), T(0, PY, 17.7))
    p.box("cream", (40.0, 3.5, 0.5), T(0, PY, 19.08))
    p.box("cream", (39.0, 0.5, 0.35), T(0, -11.05, 16.55))
    for k in range(14):
        cx = -13 + 2 * k
        pts = [(cx - 1, 16.6), (cx - 1, 15.6)] + [(cx + math.cos(math.radians(a)), 15.6 + math.sin(math.radians(a))) for a in range(200, 360, 20)] + [(cx + 1, 15.6), (cx + 1, 16.6)]
        p.extrude("accent" if k % 2 == 0 else "cream", pts, 0.45, T(0, -10.85, 0))
    p.extrude("cream", [(x, z + 18.2) for x, z in rrect(14.6, 3.6, 0.8)], 0.4, T(0, -10.75, 0))
    p.extrude("accent", [(x, z + 18.2) for x, z in rrect(13.6, 2.8, 0.6)], 0.3, T(0, -10.5, 0))
    fdisc = lambda x, z, r: p.lathe("paw", [(r, 0), (r, 0.16)], 10, T(x, -10.42, z) @ Rx(-90))
    fdisc(0, 17.75, 0.72)
    for dx, dz in ((-0.95, 0.75), (-0.35, 1.2), (0.35, 1.2), (0.95, 0.75)): fdisc(dx, 17.75 + dz, 0.32)

    # welcome pad in front, with a paw print
    p.extrude("cream", rrect(23.6, 9.6, 1.6), 0.25, T(0, 16.4, 0), 'XY')
    p.extrude("accent", rrect(22.0, 8.0, 1.3), 0.24, T(0, 16.4, 0.1), 'XY')
    disc("paw", 0, 17.4, 0.33, 1.6, h=0.07, sx=1.25, seg=12)
    for x, y in ((-2.0, 15.4), (2.0, 15.4), (-0.75, 14.5), (0.75, 14.5)): disc("paw", x, y, 0.33, 0.65, h=0.07, seg=10)
    return p


def _screen(p, M):
    """Rounded frame with a dark screen set into it. Frame 7.0 x 5.0 x 0.5 deep, screen 6.0 x 4.0; the screen's front face
    is 0.31 in front of the frame centre (Studio puts the sign's SurfaceGui there)."""
    p.extrude("wood", rrect(7.0, 5.0, 0.75), 0.5, M)
    p.extrude("screen", rrect(6.0, 4.0, 0.45), 0.12, M @ T(0, 0.25, 0))


EASEL_TILT, EASEL_Z = 10, 4.3   # Studio reads these to put the drawing on the screen
SIGN_Z = 5.3


def easel():
    """Draw canvas: a screen leaning back on an A-frame, with a paint tray. Every part overlaps the next."""
    p = Piece("Easel", bevel=0.08, bevels={"screen": 0.03, "red": 0.04, "yellow": 0.04, "blue": 0.04})
    B = T(0, 0, EASEL_Z) @ Rx(EASEL_TILT)
    _screen(p, B)
    p.box("wood", (0.6, 0.35, 0.45), B @ T(0, 0, 2.6))                       # top peg, sunk into the frame
    p.box("plankAlt", (7.9, 1.25, 0.3), B @ T(0, 0.45, -2.6))                # tray, its back edge inside the frame
    p.box("plankAlt", (7.9, 0.18, 0.3), B @ T(0, 1.0, -2.36))                # tray lip
    for x, col in ((-2.2, "red"), (-0.9, "yellow"), (0.4, "blue")):
        p.box(col, (1.0, 0.55, 0.16), B @ T(x, 0.45, -2.38))                # paint chips lying in the tray
    # front legs run from the ground up the frame sides and into the top corners
    top = (B @ Vector((0, -0.05, 2.2))).to_3d()
    for sx in (-1, 1):
        p.limb("wood", (sx * 3.72, 1.35, 0), (sx * 3.66, top.y, top.z), 0.27, 0.22, 6)
    back = (B @ Vector((0, -0.12, 1.6))).to_3d()                                # back leg ends inside the frame
    p.limb("wood", (0, -2.5, 0), (0, back.y, back.z), 0.24, 0.2, 6)
    p.limb("wood", (0, -1.55, 2.2), (0, (B @ Vector((0, -0.1, -1.6))).y, (B @ Vector((0, -0.1, -1.6))).z), 0.13, 0.13, 5)  # brace
    return p


def signboard():
    """Upgrade sign: the same screen on two posts, with a glowing step-on pedestal in front."""
    p = Piece("SignBoard", bevel=0.08, bevels={"screen": 0.03, "glow": 0.0})
    _screen(p, T(0, 0, SIGN_Z))
    p.box("wood", (0.6, 0.35, 0.45), T(0, 0, SIGN_Z + 2.6))
    for sx in (-1, 1):
        p.box("stone", (1.1, 1.1, 0.5), T(sx * 2.4, -0.05, 0.25))             # footing
        p.lathe("wood", [(0.42, 0.45), (0.42, 0.7), (0.32, 0.85), (0.32, SIGN_Z - 1.0), (0, SIGN_Z - 1.0)], 8, T(sx * 2.4, -0.05, 0))
    # step-on pedestal: stone base, a glowing band that stands proud of the stone, stone cap
    p.lathe("stone", [(1.9, 0), (1.9, 0.35), (0, 0.35)], 16, T(0, 2.6, 0))
    p.lathe("glow", [(2.0, 0.3), (2.0, 0.85), (0, 0.85)], 16, T(0, 2.6, 0))
    p.lathe("stone", [(1.9, 0.8), (1.9, 1.05), (1.7, 1.15), (0, 1.15)], 16, T(0, 2.6, 0))
    return p


PLANT_FLAT = ("leaf", "leafLight", "leafDark", "wood", "woodDark", "pink", "yellow", "cream")


def tree_round():
    """Oak: bending trunk with root flares and two branches, one lumpy canopy mass, dark underneath, light on top."""
    p = Piece("TreeRound", bevel=0.0, flat=PLANT_FLAT)
    pts, radii = [(0, 0, 0), (0.35, 0, 3.2), (-0.25, 0.2, 6.4), (0.2, 0, 9.4)], [1.5, 1.1, 0.9, 0.7]
    p.tube("wood", pts, radii, 7)
    for a in (20, 140, 260):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.limb("woodDark", (0.5 * c, 0.5 * s, 1.1), (2.2 * c, 2.2 * s, -0.1), 0.6, 0.18, 5)
    p.limb("woodDark", (-0.2, 0.2, 6.0), (-3.3, 0.9, 9.6), 0.5, 0.28, 5)
    p.limb("woodDark", (0.1, 0, 7.4), (3.1, -0.7, 10.3), 0.45, 0.25, 5)
    p.blob(4.4, 3, T(0, 0, 10.6) @ S(1.15, 1.1, 0.95), lobes=8, amp=0.5, seed=51, floor=-0.5, sharp=5)
    return p


def tree_acacia():
    """Acacia: trunk forking into three flat canopies on clearly separate levels, spaced so none sit on another."""
    p = Piece("TreeAcacia", bevel=0.0, flat=PLANT_FLAT)
    pts, radii = [(0, 0, 0), (0.6, 0, 3.4), (0.9, 0, 6.0)], [1.25, 0.85, 0.6]
    p.tube("wood", pts, radii, 7)
    pads = [((-6.8, -2.0, 8.6), 3.0, 0.5), ((6.6, 2.2, 10.6), 2.9, 0.48), ((0.4, 0.2, 13.6), 2.6, 0.42)]
    for i, (c, r, rr) in enumerate(pads):
        # each branch is one tube that starts inside the trunk, thinner than it, and leaves through the trunk top at the
        # trunk's own width, so it reads as the trunk splitting instead of a stick pushed into it
        fork, tip = Vector(pts[2]), Vector((c[0] * 0.85, c[1] * 0.85, c[2] - 0.3))
        mid = fork + (tip - fork) * 0.45 + Vector((0, 0, 0.6))
        p.tube("wood", [pts[1], fork, mid, tip], [0.7, 0.58, rr * 0.85, rr * 0.55], 6)
        p.blob(r, 2, T(*c) @ S(1.55, 1.4, 0.34), lobes=5, amp=0.18, seed=60 + i, floor=-0.35, up=0.6)
    return p


def _frond(p, color, top, yaw, R=6.5):
    """One palm leaf: a closed three-sided blade (so it is visible from both sides) arching out and down."""
    widths, n = [0.5, 1.25, 1.0, 0.55], 4
    verts, faces = [], []
    for i in range(n):
        s = i / n
        out, z, w = R * s, 2.2 * math.sin(math.pi * s * 0.9) - 3.0 * s * s, widths[i]
        verts += [(out, w, z), (out, -w, z), (out, 0, z + 0.35 * w + 0.1)]
    verts.append((R, 0, 2.2 * math.sin(math.pi * 0.9) - 3.0))
    tip = len(verts) - 1
    faces.append((0, 1, 2))
    for i in range(n - 1):
        a, b = 3 * i, 3 * i + 3
        faces += [(a, a + 2, b + 2, b), (a + 2, a + 1, b + 1, b + 2), (a + 1, a, b, b + 1)]
    a = 3 * (n - 1)
    faces += [(a, a + 2, tip), (a + 2, a + 1, tip), (a + 1, a, tip)]
    p.mesh(color, verts, faces, T(*top) @ Rz(yaw))


def tree_palm():
    """Palm: leaning trunk of stacked two-tone segments, seven arching fronds and a few coconuts.
    The lean is strongest at the base and eases off to vertical at the top, so the trunk flows into the upright crown."""
    p = Piece("TreePalm", bevel=0.0, flat=PLANT_FLAT)
    pts = [(3.9 * math.sin(math.pi / 2 * k / 7), 0, 1.75 * k) for k in range(8)]
    for k in range(7):
        r = 1.05 - 0.07 * k
        p.limb("wood" if k % 2 == 0 else "woodDark", pts[k], pts[k + 1], r, r + 0.16, 6)
    top = pts[7]
    for i in range(7): _frond(p, "leaf" if i % 2 == 0 else "leafLight", (top[0], top[1], top[2] - 0.1), i * 360 / 7 + 12, 6.0 + (i % 3) * 0.6)
    for i in range(3): p.ico("woodDark", 0.6, 1, T(top[0] + 0.75 * math.cos(i * 2.1), 0.75 * math.sin(i * 2.1), top[2] - 0.7))
    p.ico("leafDark", 1.0, 1, T(*top) @ S(1, 1, 0.7))
    return p


def _bush(p, seed):
    return p.blob(1.8, 3, T(0, 0, 0.95) @ S(1.25, 1.1, 0.9), lobes=8, amp=0.5, seed=seed, floor=-0.45, sharp=5)


def bush():
    p = Piece("Bush", bevel=0.0, flat=PLANT_FLAT)
    _bush(p, 60)
    return p


def bush_flower():
    """Bush with eight low-poly blossoms."""
    p = Piece("BushFlower", bevel=0.0, flat=PLANT_FLAT)
    surface = _bush(p, 70)
    # blossoms sit on real surface vertices, facing out along the normal, spread round the upper half
    upper = sorted([sv for sv in surface if sv[1].z > 0.25], key=lambda sv: math.atan2(sv[0].y, sv[0].x))
    for i in range(8):
        pos, n = upper[i * len(upper) // 8]
        p.lathe("pink" if i % 3 else "yellow", [(0, -0.12), (0.36, 0.05), (0, 0.24)], 5, T(*(pos + n * 0.05)) @ n.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    return p


def flowers():
    """Three flowers on stems with two base leaves."""
    p = Piece("Flowers", bevel=0.0, flat=PLANT_FLAT)
    for (x, y, h, lean, col) in ((0, 0, 2.5, (0.25, 0.1), "pink"), (0.8, 0.5, 1.8, (0.5, 0.35), "yellow"), (-0.7, 0.3, 2.0, (-0.45, 0.2), "cream")):
        head = Vector((x + lean[0], y + lean[1], h))
        p.limb("leafDark", (x, y, 0), head, 0.1, 0.07, 3)
        d = (head - Vector((x, y, 0))).normalized()
        Mh = T(*head) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        p.lathe(col, [(0, -0.08), (0.62, 0.06), (0, 0.2)], 6, Mh)
        p.lathe("yellow" if col != "yellow" else "cream", [(0, 0.1), (0.22, 0.24), (0, 0.42)], 4, Mh)
    for a in (40, 200):
        p.lathe("leaf", [(0.28, 0), (0, 1.3)], 3, Rz(a) @ T(0.3, 0, 0) @ Ry(48))
    return p


def rock():
    p = Piece("Rock", bevel=0.0, flat=("stone",))
    p.ico("stone", 1.7, 1, T(0, 0, 0.8) @ S(1.3, 1, 0.7), 0.16, 10)
    p.ico("stone", 0.95, 1, T(1.8, 0.6, 0.4) @ S(1.1, 1, 0.75), 0.16, 11)
    return p


def grass_tuft():
    p = Piece("GrassTuft", bevel=0.0, flat=("leafLight",))
    for i, (tilt, h) in enumerate(((0, 2.1), (24, 1.6), (-22, 1.7), (32, 1.25), (-34, 1.15), (16, 1.9), (-12, 1.4))):
        p.lathe("leafLight", [(0.22, 0), (0, h)], 3, Rz(i * 51.4) @ T(0.2 + 0.05 * i, 0, 0) @ Ry(tilt))
    return p


LAMP_GLOW_Z = 10.1   # Studio puts the PointLight here


def lamp_post():
    """Victorian street lamp: stepped octagonal plinth tapering into a thin pole, a six-sided lantern that widens upward,
    a peaked cap and a spike. One lathe profile per material, each overlapping the next."""
    p = Piece("LampPost", bevel=0.05, flat=("glow",), bevels={"iron": 0.05})
    p.lathe("iron", [(1.0, 0), (1.0, 0.7), (0.86, 0.85), (0.86, 1.55), (0.72, 1.75), (0.56, 3.9), (0.64, 4.0), (0.64, 4.25),
                     (0.22, 4.3), (0.18, 4.3), (0.17, 8.7), (0.32, 8.8), (0.32, 9.25), (0.6, 9.3), (0.6, 9.5), (0, 9.5)], 8)
    p.lathe("glow", [(0.52, 9.45), (0.78, 10.75), (0, 10.75)], 6)
    for k in range(6):                                                             # cage bars on the glass corners
        a = math.radians(60 * k)
        p.limb("iron", (0.52 * math.cos(a), 0.52 * math.sin(a), 9.45), (0.78 * math.cos(a), 0.78 * math.sin(a), 10.75), 0.07, 0.07, 4)
    p.lathe("iron", [(0.92, 10.7), (0.92, 10.92), (0.42, 11.35), (0.16, 11.4), (0, 12.25)], 6)
    return p


def bench():
    """Park bench: two cast-iron side frames, each one solid silhouette (leg, seat bracket, back upright, leg), with
    the seat and back slats resting on and against them."""
    p = Piece("Bench", bevel=0.06, bevels={"iron": 0.04})
    side = [(0.75, 0), (1.05, 0), (1.05, 1.25), (1.15, 1.25), (1.15, 1.5), (-0.75, 1.5), (-0.95, 3.55), (-1.25, 3.55),
            (-1.15, 0), (-0.85, 0), (-0.85, 1.2), (0.75, 1.2)]
    for sx in (-1, 1):
        p.extrude("iron", side, 0.3, T(sx * 2.4, 0, 0) @ Rz(90))
    for y in (0.75, 0.15, -0.45):
        p.box("wood", (6.0, 0.55, 0.2), T(0, y, 1.59))                        # bottoms sink 0.01 into the brackets
    lean = math.degrees(math.atan2(0.2, 2.05))
    for z in (2.4, 3.15):
        y_edge = -0.75 - 0.2 * (z - 1.5) / 2.05                                  # front edge of the upright at this height
        p.box("wood", (6.0, 0.2, 0.55), T(0, y_edge + 0.08, z) @ Rx(lean))     # pushed 0.02 into the upright
    return p


def hedge():
    p = Piece("Hedge", bevel=0.6, bevels={"stone": 0.2})
    n = 18
    pts = [(-16.4, 0.5)] + [(-16.4 + 32.8 * i / n, 5.6 + 1.0 * abs(math.sin(i / n * math.pi * 3))) for i in range(n + 1)] + [(16.4, 0.5)]
    p.extrude("leaf", pts, 4.4)
    p.box("stone", (33.2, 5.2, 0.7), T(0, 0, 0.35))
    return p


def hedge_post():
    p = Piece("HedgePost", bevel=0.2, bevels={"yellow": 0.0})
    p.lathe("stone", [(1.75, 0), (1.75, 0.9), (1.3, 1.35), (1.3, 7.2), (1.75, 7.65), (1.75, 8.3), (0, 8.3)], 8)
    p.lathe("yellow", [(0, 8.1), (0.75, 8.4), (1.05, 9.15), (0.75, 9.9), (0, 10.2)], 8)
    return p


def gate():
    p = Piece("Gate", bevel=0.25, bevels={"yellow": 0.0, "cream": 0.1})
    pillar = [(2.9, 0), (2.9, 1.2), (2.2, 1.9), (2.2, 13), (2.9, 13.7), (2.9, 14.6), (0, 14.6)]
    for sx in (-1, 1):
        p.lathe("stone", pillar, 12, T(sx * 10.5, 0, 0))
        p.lathe("yellow", [(0, 14.4), (1.1, 14.9), (1.5, 16.0), (1.1, 17.1), (0, 17.6)], 8, T(sx * 10.5, 0, 0))
    arc = [(13.6 * math.cos(math.pi * (1 - i / 14)), 14.2 + 5.2 * math.sin(math.pi * (1 - i / 14))) for i in range(15)]
    p.extrude("wood", arc, 1.6)
    for sy in (-1, 1): p.box("cream", (17, 0.4, 2.8), T(0, sy * 0.85, 16.1))
    for sx in (-1, 1):
        H = T(sx * 8.2, 0, 0) @ Rz(-sx * 90) @ T(-sx * 8.2, 0, 0)      # door half swung open 90 degrees about its pillar hinge, into the park (+y once placed)
        for k in range(4): p.box("wood", (1.3, 0.5, 9.4 - (k % 2) * 0.8), H @ T(sx * (1.0 + k * 2.0), 0, 4.9 - (k % 2) * 0.4))
        for z in (2.6, 7.4): p.box("wood", (8.0, 0.7, 0.6), H @ T(sx * 4.2, 0, z))
    return p


def hill():
    p = Piece("Hill", bevel=0.0, flat=("grassDark",))
    p.ico("grassDark", 50, 2, S(1, 1, 0.42), 0.07, 12)
    return p


BOARD_Z, BOARD_W, BOARD_H = 27.0, 36.0, 22.0        # board centre height and outer frame size
SCREEN_W, SCREEN_H, SCREEN_D = 33.0, 19.0, 1.7       # dark screen, both faces 0.85 from the centre (Studio GUI goes there)
PLAQUE_Z, PLAQUE_W, PLAQUE_H = BOARD_Z + 11.6, 22.0, 5.0


def leaderboard():
    """Top Earners board: a framed double-sided screen on two posts, a header plaque with a crown, and marquee bulbs
    round the frame. Built at full size (no scaling in Studio); every part overlaps its neighbour."""
    p = Piece("Leaderboard", bevel=0.25, flat=("yellow",), bevels={"screen": 0.08, "gold": 0.12, "red": 0.15, "bulb": 0.0})
    # one central column (the board stands in the middle of the map): stepped stone footing, a tapering wooden pole
    # with gold collars, and two angled braces from a collar up into the frame so the wide board looks held
    bottom = BOARD_Z - BOARD_H / 2
    p.lathe("stone", [(4.2, 0), (4.2, 1.0), (3.5, 1.4), (2.7, 1.4), (2.7, 2.6), (2.2, 3.0), (0, 3.0)], 12)
    p.lathe("wood", [(1.7, 2.9), (1.45, 4.0), (1.25, bottom + 1.0), (0, bottom + 1.0)], 12)
    for z in (4.2, bottom - 4.0): p.lathe("gold", [(1.65, z), (1.65, z + 0.9), (0, z + 0.9)], 12)
    for sx in (-1, 1):
        p.limb("wood", (sx * 0.6, 0, bottom - 3.6), (sx * 9.5, 0, bottom + 0.8), 0.45, 0.4, 6)
    # frame and screen (the screen is a slab through the frame, so it shows on both sides)
    # upright slab: rounded outline (w x h) centred at height z, `d` thick and centred on y = 0
    # (Rx(90) turns the outline's y into height and its thickness into -y, so the slab is shifted +d/2 to centre it)
    def slab(col, w, h, r, d, z):
        p.extrude(col, rrect(w, h, r), d, T(0, d / 2, z - h / 2) @ Rx(90) @ T(0, h / 2, 0), 'XY')
    slab("wood", BOARD_W, BOARD_H, 2.2, 1.6, BOARD_Z)
    slab("screen", SCREEN_W, SCREEN_H, 1.2, SCREEN_D, BOARD_Z)
    slab("gold", BOARD_W + 0.8, BOARD_H + 0.8, 2.5, 0.9, BOARD_Z)
    # marquee bulbs set into the frame face, front and back
    for sy in (-1, 1):
        for k in range(15):
            x = -15.4 + k * 2.2
            for z in (BOARD_Z + BOARD_H / 2 - 0.7, BOARD_Z - BOARD_H / 2 + 0.7):
                p.ico("bulb", 0.32, 1, T(x, sy * 0.78, z))
        for k in range(1, 8):
            for sx in (-1, 1):
                p.ico("bulb", 0.32, 1, T(sx * (BOARD_W / 2 - 0.7), sy * 0.78, BOARD_Z - BOARD_H / 2 + 0.7 + k * 2.58))
    # header plaque riding on the frame top, with a crown on top of it
    slab("red", PLAQUE_W, PLAQUE_H, 1.6, 2.2, PLAQUE_Z)
    slab("gold", PLAQUE_W + 0.6, PLAQUE_H + 0.6, 1.9, 1.6, PLAQUE_Z)
    cz = PLAQUE_Z + PLAQUE_H / 2 - 0.1
    crown = [(-3.0, 0), (3.0, 0), (3.0, 1.2), (3.4, 3.4), (1.7, 1.9), (0, 4.0), (-1.7, 1.9), (-3.4, 3.4), (-3.0, 1.2)]
    p.extrude("yellow", [(x, cz + z) for x, z in crown], 1.4)
    for x, z in ((-3.4, 3.4), (0, 4.0), (3.4, 3.4)): p.ico("red", 0.5, 1, T(x, 0, cz + z))
    return p


def plaza():
    p = Piece("Plaza", bevel=0.05)
    p.lathe("cream", [(58.5, -0.4), (58.5, 0.06), (0, 0.06)], 48)
    p.lathe("sand", [(56, -0.3), (56, 0.11), (0, 0.11)], 48)
    p.lathe("sandDark", [(30, 0), (33, 0), (33, 0.14), (30, 0.14)], 48, closed=True)
    for i in range(7):
        a = i / 7 * 2 * math.pi
        # Roblox plot i sits at (sin a, cos a) * R  ->  Blender (sin a, -cos a)
        M = T(math.sin(a) * 61, -math.cos(a) * 61, 0) @ Rz(math.degrees(a))
        p.extrude("sand", rrect(10, 9, 1.5), 0.08, M, 'XY')
    return p


def showcase():
    p = Piece("Showcase", bevel=0.2)
    p.lathe("grassDark", [(19.4, 0), (19.4, 0.31), (0, 0.31)], 32)
    p.lathe("cream", [(18.9, 0), (20.5, 0), (20.5, 1.3), (20.15, 1.7), (19.25, 1.7), (18.9, 1.3)], 32, closed=True)
    return p


def island():
    p = Piece("Island", bevel=0.0)
    p.lathe("grass", [(134, -0.9), (132, 0), (0, 0)], 64)
    p.lathe("earth", [(162, -3.3), (140, -1.0), (120, -1.0)], 64)
    return p


RACE_TRACK_Y, RACE_TRACK_LEN, RACE_TRACK_W = 95, 150, 30


def race_grounds():
    """Path out of the main gate to a strip of land for animal racing (decoration only for now).
    Origin = the gate's centre on the ground; +Y runs out of the park. The island's grass ends 6 past the gate and slopes
    down to the plain 3.3 below, so the path is a raised causeway and the land a two-tier plateau."""
    p = Piece("RaceGrounds", bevel=0.15, bevels={"grass": 0.0, "earth": 0.0, "dirt": 0.0, "zebra": 0.0, "ink": 0.0, "sand": 0.05})
    # causeway: sand path with cream curbs on an earth bank
    p.box("sand", (14, 64, 0.3), T(0, 26, -0.03))
    for sx in (-1, 1): p.box("cream", (0.6, 64, 0.5), T(sx * 7.3, 26, 0.0))
    p.box("earth", (16.4, 52, 3.6), T(0, 32, -1.8))
    # plateau: grass top tier, earth cliff below
    p.extrude("grass", rrect(190, 80, 12), 0.9, T(0, RACE_TRACK_Y, -0.9), 'XY')
    p.extrude("earth", rrect(198, 88, 15), 2.75, T(0, RACE_TRACK_Y, -3.6), 'XY')
    p.box("sand", (14, 8, 0.3), T(0, 58, -0.03))                             # path runs onto the plateau
    # track: dirt slab, white lane lines, start line and a checkered finish
    L, Wd, Y = RACE_TRACK_LEN, RACE_TRACK_W, RACE_TRACK_Y
    p.box("dirt", (L, Wd, 0.2), T(0, Y, 0.0))
    for k in (-1, 0, 1): p.box("zebra", (L - 4, 0.35, 0.06), T(0, Y + k * 7.5, 0.12))
    p.box("zebra", (0.8, Wd, 0.06), T(-L / 2 + 3, Y, 0.12))
    n = 20
    for i in range(n):
        for j in range(2):
            p.box("ink" if (i + j) % 2 == 0 else "zebra", (0.8, Wd / n, 0.06), T(L / 2 - 3.4 + j * 0.8, Y - Wd / 2 + (i + 0.5) * Wd / n, 0.12))
    # start and finish arches with a banner (Studio writes the text on the banner)
    for x in (-L / 2 + 3, L / 2 - 3):
        for sy in (-1, 1): p.box("wood", (1.2, 1.2, 10.4), T(x, Y + sy * 16.2, 5.0))
        p.box("wood", (1.4, 34.0, 1.4), T(x, Y, 10.3))
        p.box("red", (0.5, 22.0, 3.2), T(x, Y, 8.25))
        for sy in (-1, 1): p.lathe("yellow", [(0, 10.9), (0.7, 11.2), (0.95, 11.9), (0.7, 12.6), (0, 12.9)], 8, T(x, Y + sy * 16.2, 0))
    # fences along both long sides
    for sy in (-1, 1):
        yy = Y + sy * 17.5
        for k in range(16):
            p.box("wood", (0.5, 0.5, 2.6), T(-L / 2 + k * L / 15, yy, 1.2))
        for z in (1.3, 2.2): p.box("cream", (L, 0.3, 0.35), T(0, yy, z))
    # bleachers on the near side, either side of where the path arrives
    for x in (-34, 34):
        for k, h in enumerate((1.0, 2.0, 3.0)):
            p.box("stone", (28, 2.6, h), T(x, Y - 21 - k * 2.4, h / 2))
            p.box("red" if k % 2 == 0 else "yellow", (28, 1.0, 0.25), T(x, Y - 21 - k * 2.4, h + 0.1))
    # pennant poles along the far side
    for k in range(7):
        x = -60 + k * 20
        p.lathe("iron", [(0.18, 0), (0.18, 9), (0, 9.2)], 6, T(x, Y + 22, 0))
        p.extrude("red" if k % 2 == 0 else "yellow", [(0, 8.9), (2.6, 8.1), (0, 7.3)], 0.12, T(x, Y + 22, 0))
    return p


# ----------------------------------------------------------------- animal race (outskirts loop)
TRACK_TOP = -0.85                     # gravel surface height (Roblox Y); the island's flat earth is at -1.0
TRACK_R0, TRACK_R1 = 137.0, 163.0     # inner and outer edge radius before the wobble; centre line 150


def track_edges(a):
    """Inner and outer gravel edge radius at angle a (radians, Blender XY). Studio's race script uses the same formula."""
    return (TRACK_R0 + 0.9 * math.sin(7 * a + 1.0) + 0.6 * math.sin(13 * a),
            TRACK_R1 + 1.0 * math.sin(5 * a + 2.0) + 0.7 * math.sin(11 * a + 0.5))


def _raw(p, color, verts, faces):
    """Add an open surface without recalculating normals (faces are already wound counter-clockwise from outside)."""
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces: bm.faces.new([vs[i] for i in f])
    bmesh.ops.delete(bm, geom=[v for v in vs if not v.link_faces], context='VERTS')   # glTF drops loose verts; keep stats in step
    me = bpy.data.meshes.new("tmp"); bm.to_mesh(me); bm.free()
    p.parts.setdefault(color, bmesh.new()).from_mesh(me); bpy.data.meshes.remove(me)


def race_track():
    """Gravel loop round the outside of the hedge, origin = zoo centre at ground level. A flat gravel band blotched in two
    tones, sprinkled with pebbles and edged with low stones, with a lip tucked under the island's earth on the inside and
    an earth shoulder running down to the plain on the outside, so nothing hangs in the air. Studio builds the collision
    (a ring of boxes); this mesh is visual only."""
    p = Piece("RaceTrack", bevel=0.0, flat=("gravel", "gravelDark", "earth", "pebble", "pebbleLight", "rock"))
    N, ROWS = 480, 12                                     # ~2-stud faces, so the tone blotches read as patches, not tiles
    verts, rings = [], []
    for i in range(N):
        a = 2 * math.pi * i / N
        r0, r1 = track_edges(a)
        prof = [(r0 - 1.6, TRACK_TOP - 0.35)] + [(r0 + (r1 - r0) * k / ROWS, TRACK_TOP) for k in range(ROWS + 1)] + \
               [(r1 + 2.4, TRACK_TOP - 0.9), (r1 + 8.5, -3.75)]
        rings.append([len(verts) + k for k in range(len(prof))])
        verts += [(r * math.cos(a), r * math.sin(a), z) for r, z in prof]
    M = len(rings[0])
    faces = {"gravel": [], "gravelDark": [], "earth": []}
    for i in range(N):
        A, B = rings[i], rings[(i + 1) % N]
        for k in range(M - 1):
            f = (A[k], A[k + 1], B[k + 1], B[k])          # outward then forward in angle: counter-clockwise seen from above
            c = "gravelDark" if k == 0 else "earth" if k >= ROWS + 1 else "gravel"   # one even tone: face blotches read as tiles; pebbles give the grain
            faces[c].append(f)
    for c, fs in faces.items(): _raw(p, c, verts, fs)
    return p   # the pebbles and edging stones are race_stones(): one huge scattered mesh renders broken in Roblox


STONE_SECTORS = 8


def _track_scatter():
    """Pebbles and edging stones as (colour, radius, matrix, jitter, seed, angle), in the same random order as always."""
    rnd, out = random.Random(42), []
    for k in range(1300):                                    # pebbles: flat chips pressed into the surface
        a = rnd.uniform(0, 2 * math.pi)
        r0, r1 = track_edges(a)
        r = rnd.uniform(r0 + 0.6, r1 - 0.6)
        out.append(("pebbleLight" if k % 3 == 0 else "pebble", rnd.uniform(0.22, 0.55),
                    T(r * math.cos(a), r * math.sin(a), TRACK_TOP + 0.05) @ Rz(rnd.uniform(0, 360)) @ S(1.3, 1.0, 0.38), 0.2, k, a))
    for edge in (0, 1):                                      # low edging stones, a bit under half sunk: deeper leaves only slivers showing
        n = 150 if edge == 0 else 175
        for k in range(n):
            a = 2 * math.pi * (k + rnd.uniform(-0.3, 0.3)) / n
            # outer stones sit just inside the edge, never out over the shoulder slope
            r = track_edges(a)[edge] + (rnd.uniform(-0.3, 0.2) if edge == 0 else rnd.uniform(-0.2, 0.4) - 0.5)
            out.append(("rock", rnd.uniform(0.7, 1.25),
                        T(r * math.cos(a), r * math.sin(a), TRACK_TOP + 0.1) @ Rz(rnd.uniform(0, 360)) @ S(1.35, 1.0, 0.6), 0.22, 1000 + k + edge * 500, a))
    return out


def race_stones(s):
    """One 45-degree sector of the track's pebbles and edging stones, origin = zoo centre like RaceTrack.
    Split up because Roblox draws a single mesh with thousands of loose chips spread over 320 studs with stray triangles."""
    p = Piece("RaceStones%d" % (s + 1), bevel=0.0, flat=("pebble", "pebbleLight", "rock"))
    for color, r, M, jitter, seed, a in _track_scatter():
        if int((a % (2 * math.pi)) / (2 * math.pi) * STONE_SECTORS) == s:
            p.ico(color, r, 0, M, jitter, seed)
    return p


def race_start():
    """Start/finish arch across the track. Origin = centre line on the gravel; x runs across the track (+x outward),
    the track runs along y. Posts stand off both edges and reach down past the shoulder; a chequered strip on the gravel."""
    p = Piece("RaceStart", bevel=0.15, flat=("ink", "zebra"), bevels={"red": 0.1})
    for sx, foot in ((-1, -0.6), (1, -2.9)):
        x = sx * 15.6
        p.lathe("stone", [(1.3, foot), (1.3, 0.5), (0.95, 0.9), (0.95, 1.2), (0, 1.2)], 8, T(x, 0, 0))
        p.lathe("wood", [(0.75, foot), (0.75, 11.6), (0, 11.6)], 8, T(x, 0, 0))
        p.lathe("yellow", [(0, 12.0), (0.75, 12.3), (1.05, 13.0), (0.75, 13.7), (0, 14.0)], 8, T(x, 0, 0))
    p.box("wood", (33.4, 1.3, 1.3), T(0, 0, 11.6))
    p.box("red", (20.0, 0.5, 3.4), T(0, 0, 9.4))                       # banner: Studio writes START / FINISH on both faces
    for sx in (-1, 1): p.box("rope", (0.25, 0.25, 0.9), T(sx * 8.6, 0, 11.0))
    n = 16
    for i in range(n):
        for j in range(2):
            p.box("ink" if (i + j) % 2 == 0 else "zebra", (25.0 / n, 1.0, 0.06), T(-12.5 + (i + 0.5) * 25.0 / n, (j - 0.5) * 1.0, 0.03))
    return p


def race_log():
    """Fallen log lying along x: bark body, pale cut ends with a ring, a snapped branch and a moss cap."""
    p = Piece("RaceLog", bevel=0.12, bevels={"plank": 0.05})
    L, R = 9.0, 1.15
    p.tube("woodDark", [(-L / 2, 0, R * 0.92), (-L / 6, 0.1, R * 0.95), (L / 6, -0.1, R * 0.93), (L / 2, 0, R * 0.9)], [R, R * 1.03, R * 0.98, R * 0.95], 8)
    for sx, rr in ((-1, R * 0.9), (1, R * 0.85)):
        M = T(sx * (L / 2 - 0.05), 0, R * 0.92) @ Ry(90 * sx)
        p.lathe("plank", [(rr, 0), (rr, 0.18), (0, 0.18)], 8, M)
        p.lathe("wood", [(rr * 0.5, 0.17), (rr * 0.62, 0.17), (rr * 0.62, 0.22), (rr * 0.5, 0.22)], 8, M, closed=True)
    p.limb("woodDark", (0.8, 0.3, R * 1.5), (1.9, 1.5, R * 2.4), 0.38, 0.22, 6)
    p.blob(0.9, 1, T(-1.6, 0, R * 1.75) @ S(1.6, 0.9, 0.45), lobes=4, amp=0.2, seed=5)
    return p


def race_hay():
    """Hay bale stack: two bales side by side, one on top, each with two rope straps."""
    p = Piece("RaceHay", bevel=0.3, bevels={"rope": 0.05})
    for x, z in ((-1.3, 1.1), (1.3, 1.1), (0.0, 3.3)):
        p.box("hay", (2.5, 4.0, 2.2), T(x, 0, z))
        for y in (-1.1, 1.1): p.box("rope", (2.62, 0.22, 2.32), T(x, y, z))
    return p


def race_rocks():
    """Low boulder cluster, pushed into each other and into the ground."""
    p = Piece("RaceRocks", bevel=0.0, flat=("rock", "stone"))
    p.ico("rock", 2.0, 1, T(0, 0, 0.9) @ S(1.3, 1.0, 0.85), 0.16, 21)
    p.ico("stone", 1.4, 1, T(2.1, 0.7, 0.55) @ S(1.1, 1.0, 0.8), 0.16, 22)
    p.ico("rock", 1.1, 1, T(-2.0, -0.6, 0.4) @ S(1.2, 1.0, 0.75), 0.16, 23)
    return p


def race_mud():
    """Mud patch, flush with the gravel: a wobbly brown pool with a darker wet middle and two splats beside it."""
    p = Piece("RaceMud", bevel=0.0, flat=("mud", "mudWet"))
    def outline(rx, ry, n, seed):
        rnd = random.Random(seed)
        return [((rx + rnd.uniform(-0.6, 0.6)) * math.cos(2 * math.pi * i / n), (ry + rnd.uniform(-0.5, 0.5)) * math.sin(2 * math.pi * i / n)) for i in range(n)]
    p.extrude("mud", outline(5.0, 3.6, 18, 31), 0.1, T(0, 0, -0.02), 'XY')
    p.extrude("mudWet", outline(3.2, 2.1, 14, 32), 0.1, T(0.3, 0.2, 0.0), 'XY')
    for x, y, r in ((5.6, 2.6, 0.9), (-5.2, -2.4, 0.7)):
        p.extrude("mud", outline(r, r * 0.8, 9, int(abs(x) * 10)), 0.1, T(x, y, -0.02), 'XY')
    return p


def boost_ring():
    """Speed-boost hoop standing on the gravel: a thin candy-striped torus (axis along y, the running direction) whose
    bottom sinks a hair into the gravel, so it stands on its own with no base block."""
    p = Piece("BoostRing", bevel=0.0)
    R, r, SEG, SIDE, BANDS = 5.0, 0.2, 72, 6, 16
    for band in range(BANDS):
        verts, faces = [], []
        i0, i1 = band * SEG // BANDS, (band + 1) * SEG // BANDS
        for i in range(i0, i1 + 1):
            u = 2 * math.pi * i / SEG
            for j in range(SIDE):
                v = 2 * math.pi * j / SIDE
                d = R + r * math.cos(v)
                verts.append((d * math.cos(u), r * math.sin(v), R + r * 0.5 + d * math.sin(u)))
        for i in range(i1 - i0):
            for j in range(SIDE):
                a, b = i * SIDE + j, i * SIDE + (j + 1) % SIDE
                faces.append((a, b, b + SIDE, a + SIDE))
        faces.append(tuple(range(SIDE))); faces.append(tuple(range((i1 - i0) * SIDE, (i1 - i0 + 1) * SIDE)))
        p.mesh("boost" if band % 2 == 0 else "boostLight", verts, faces)
    return p


def race_pad():
    """Race sign-up pad inside the gate: a round stone step with a glowing inset ring and a signboard behind it
    (Studio writes ANIMAL RACES on the board). Origin = pad centre on the ground; the board stands at -y."""
    p = Piece("RacePad", bevel=0.15, bevels={"glow": 0.05})
    p.lathe("stone", [(6.2, 0), (6.2, 0.45), (5.8, 0.7), (0, 0.7)], 24)
    p.lathe("glow", [(4.6, 0.66), (5.2, 0.66), (5.2, 0.8), (4.6, 0.8)], 24, closed=True)
    p.lathe("red", [(3.8, 0.66), (3.8, 0.76), (0, 0.76)], 24)
    for sx in (-1, 1):
        p.lathe("wood", [(0.45, 0), (0.45, 8.2), (0, 8.2)], 8, T(sx * 4.4, -7.4, 0))
        p.lathe("yellow", [(0, 8.1), (0.5, 8.4), (0.7, 8.9), (0.5, 9.4), (0, 9.6)], 8, T(sx * 4.4, -7.4, 0))
    p.box("wood", (10.0, 0.6, 3.6), T(0, -7.4, 6.0))
    p.box("cream", (9.0, 0.7, 2.8), T(0, -7.4, 6.0))                    # board face: Studio puts the text on its +y side
    return p


GROUND_TOP = -3.3                     # the plain round the island (Roblox Y): outskirt props stand on this


def map_ground():
    """The plain the zoo sits on, cut to the foliage: a wobbly low-poly disc of meadow (radius about 410, just past the outer
    hills, which Studio pulls in to fit) with a rounded grass lip and a rocky underside tapering to a point, like a floating island.
    Origin = zoo centre at Y 0. Visual only; Studio adds a cylinder for collision."""
    p = Piece("MapGround", bevel=0.0, flat=("meadow", "meadowDark", "earth", "sandDark"))
    N = 96
    def R(a): return 410 + 6 * math.sin(5 * a + 0.4) + 4 * math.sin(11 * a + 2.1)
    rnd = random.Random(9)
    prof = lambda a: [(R(a) - 6, GROUND_TOP), (R(a), GROUND_TOP - 0.4), (R(a) + 1.2, GROUND_TOP - 1.6),
                      (R(a) + 0.4 + rnd.uniform(-1, 1), GROUND_TOP - 7 + rnd.uniform(-1, 1)),
                      (R(a) * 0.86 + rnd.uniform(-4, 4), GROUND_TOP - 22 + rnd.uniform(-3, 3)),
                      (R(a) * 0.55 + rnd.uniform(-6, 6), GROUND_TOP - 48 + rnd.uniform(-4, 4))]
    rings, verts = [], [(0, 0, GROUND_TOP)]
    for i in range(N):
        a = 2 * math.pi * i / N
        pr = prof(a)
        rings.append([len(verts) + k for k in range(len(pr))])
        verts += [(r * math.cos(a), r * math.sin(a), z) for r, z in pr]
    tip = len(verts); verts.append((0, 0, GROUND_TOP - 95))
    faces = {"meadow": [], "meadowDark": [], "earth": [], "sandDark": []}
    for i in range(N):
        A, B = rings[i], rings[(i + 1) % N]
        faces["meadow"].append((0, A[0], B[0]))                     # top fan, counter-clockwise from above
        for k in range(len(A) - 1):
            f = (A[k], A[k + 1], B[k + 1], B[k])
            c = "meadow" if k == 0 else "meadowDark" if k == 1 else ("sandDark" if (i + k) % 3 == 0 or k >= 4 else "earth")
            faces[c].append(f)
        faces["sandDark"].append((A[-1], tip, B[-1]))
    for c, fs in faces.items(): _raw(p, c, verts, fs)
    return p


BORDER_R = 176.0                      # border fence radius, just outside the track's earth shoulder


def border_fence():
    """Rustic post-and-rail fence round the whole race loop, standing on the plain. Origin = zoo centre at Y 0. Rails run
    post to post in straight spans, each slotted into both posts. Studio adds a tall invisible wall for collision."""
    p = Piece("BorderFence", bevel=0.08, bevels={"woodDark": 0.12})
    n = 140
    pts = [(BORDER_R * math.cos(2 * math.pi * i / n), BORDER_R * math.sin(2 * math.pi * i / n)) for i in range(n)]
    for i, (x, y) in enumerate(pts):
        p.lathe("woodDark", [(0.42, GROUND_TOP - 0.6), (0.42, GROUND_TOP + 4.3), (0.26, GROUND_TOP + 4.6), (0, GROUND_TOP + 4.6)], 6, T(x, y, 0))
        x2, y2 = pts[(i + 1) % n]
        mx, my, L = (x + x2) / 2, (y + y2) / 2, math.hypot(x2 - x, y2 - y)
        yaw = math.degrees(math.atan2(y2 - y, x2 - x))
        for z in (1.7, 3.5):
            p.box("wood", (L + 0.5, 0.32, 0.42), T(mx, my, GROUND_TOP + z) @ Rz(yaw))
    return p


def _crate(p, x, y, z, s=1.0):
    p.box("plank", (1.8 * s, 1.8 * s, 1.6 * s), T(x, y, z + 0.8 * s))
    for sx in (-1, 1):
        for sy in (-1, 1): p.box("plankAlt", (0.26 * s, 0.26 * s, 1.64 * s), T(x + sx * 0.82 * s, y + sy * 0.82 * s, z + 0.8 * s))
    for zz in (0.2, 1.4): p.box("plankAlt", (1.86 * s, 1.86 * s, 0.22 * s), T(x, y, z + zz * s))


def trader_stall():
    """Safari Sam's market stall. Front +Y, ground at z=0. The roof is striped canvas with a scalloped valance; the counter
    front is a framed zebra panel built from clean, evenly spaced stripes."""
    p = Piece("TraderStall", bevel=0.1, flat=("hay",), bevels={"ink": 0.0, "zebra": 0.0, "red": 0.04, "cream": 0.04, "rope": 0.0, "glass": 0.0, "glow": 0.0, "brass": 0.03,
                                                               "plankAlt": 0.04, "cap": 0.02, "iron": 0.03, "yellow": 0.0, "leafLight": 0.0})
    # deck: dark frame, ten boards in two shades
    p.box("woodDark", (18.4, 11.4, 0.35), T(0, 0, 0.175))
    for k in range(10):
        p.box("plank" if k % 2 == 0 else "plankAlt", (18.0, 1.0, 0.25), T(0, -4.95 + k * 1.1, 0.475))
    # posts with stone plinths, beams, knee braces
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box("stone", (1.5, 1.5, 0.6), T(sx * 7.5, sy * 4.5, 0.9))
            p.box("wood", (0.9, 0.9, 12.6), T(sx * 7.5, sy * 4.5, 7.5))
            p.box("woodDark", (1.15, 1.15, 0.35), T(sx * 7.5, sy * 4.5, 4.3))
        p.box("wood", (0.7, 9.8, 0.7), T(sx * 7.5, 0, 13.55))
        for sy in (-1, 1):
            p.limb("woodDark", (sx * 7.5, sy * 4.5, 11.2), (sx * 5.7, sy * 4.5, 13.3), 0.22, 0.22, 4)
    for sy in (-1, 1): p.box("wood", (16.4, 0.7, 0.7), T(0, sy * 4.5, 13.55))
    # roof: eight canvas strips alternating cream / red, ridge cap, scalloped valance front and back
    prof = [(-6.4, 13.85), (0, 16.9), (6.4, 13.85), (6.4, 13.5), (0, 16.55), (-6.4, 13.5)]
    for k in range(8):
        p.extrude("cream" if k % 2 == 0 else "red", prof, 2.45, T(-8.575 + k * 2.45, 0, 0) @ Rz(90))
    p.box("woodDark", (20.0, 0.7, 0.45), T(0, 0, 17.05))
    for sy in (-1, 1):
        for k in range(8):
            x0 = -9.8 + k * 2.45
            arc = [(x0 + 2.45 * (1 - math.cos(math.pi * j / 8)) / 2, 13.55 - 0.85 * math.sin(math.pi * j / 8)) for j in range(9)]
            p.extrude("red" if k % 2 == 0 else "cream", [(x0, 13.85)] + arc[::-1][:0] + [(x0 + 2.45, 13.85)] + arc[::-1], 0.14, T(0, sy * 6.45, 0))
    # counter: dark body, plank top, framed zebra front
    p.box("woodDark", (15.0, 2.4, 3.4), T(0, 3.2, 2.3))
    p.box("plank", (16.2, 3.2, 0.45), T(0, 3.2, 4.225))
    p.box("plankAlt", (16.4, 0.3, 0.3), T(0, 4.75, 4.1))
    p.box("wood", (15.2, 0.25, 0.5), T(0, 4.48, 0.85))
    p.box("wood", (15.2, 0.25, 0.4), T(0, 4.48, 3.8))
    for x in (-7.25, 0, 7.25): p.box("wood", (0.5, 0.25, 3.4), T(x, 4.48, 2.3))
    for sx in (-1, 1): p.box("zebra", (6.75, 0.06, 2.5), T(sx * 3.625, 4.43, 2.35))
    # zebra print: smooth S-curved bands, thick where they start and tapering to a point, alternating from top and bottom
    reach = [0.92, 0.62, 0.85, 0.7, 0.95, 0.58]
    for sx in (-1, 1):
        for k in range(6):
            xc = sx * (0.75 + k * 1.1)
            down = (k + (sx > 0)) % 2 == 0
            zb, span = (3.6, -2.5) if down else (1.1, 2.5)
            sway = 0.3 * (1 if k % 2 else -1)
            left, right = [], []
            for i in range(9):
                t = reach[k] * i / 8
                cx = xc + sway * math.sin(math.pi * t)
                w = 0.42 * (1 - t / reach[k]) ** 0.8 + 0.01
                z = zb + span * t
                left.append((cx - w, z)); right.append((cx + w, z))
            p.extrude("ink", left + right[::-1], 0.05, T(0, 4.48, 0))
    # sign frame (the sign text stays a Roblox SurfaceGui on the board inside it) and its hanging ropes
    for z in (9.75, 12.85): p.box("wood", (12.8, 0.55, 0.3), T(0, 5.5, z))
    for sx in (-1, 1):
        p.box("wood", (0.3, 0.55, 3.4), T(sx * 6.25, 5.5, 11.3))
        p.limb("rope", (sx * 5.2, 5.5, 13.0), (sx * 5.0, 4.6, 13.2), 0.07, 0.07, 4)
    # lanterns on the front posts
    for sx in (-1, 1):
        x = sx * 6.6
        p.limb("iron", (sx * 7.1, 4.5, 11.6), (x, 5.15, 11.6), 0.08, 0.08, 4)
        p.lathe("iron", [(0.55, 10.5), (0.55, 10.62), (0, 10.62)], 6, T(x, 5.15, 0))
        p.box("glow", (0.7, 0.7, 0.85), T(x, 5.15, 11.05))
        for dx in (-1, 1):
            for dy in (-1, 1): p.box("iron", (0.1, 0.1, 0.9), T(x + dx * 0.37, 5.15 + dy * 0.37, 11.05))
        p.lathe("iron", [(0.6, 11.48), (0.25, 11.85), (0, 11.85)], 6, T(x, 5.15, 0))
    # on the counter: two crates, a fruit basket and a brass bell
    _crate(p, 5.4, 3.0, 4.45)
    _crate(p, 3.6, 3.3, 4.45, 0.7)
    p.lathe("rope", [(0.9, 4.45), (1.2, 5.25), (1.1, 5.25), (0.8, 4.6), (0, 4.6)], 10, T(-4.6, 3.2, 0))
    for i, (dx, dy, col) in enumerate(((-0.35, -0.2, "red"), (0.35, 0.1, "yellow"), (0, 0.4, "leafLight"), (-0.1, -0.5, "red"))):
        p.ico(col, 0.4, 1, T(-4.6 + dx, 3.2 + dy, 5.35 + (i % 2) * 0.12))
    p.lathe("brass", [(0.45, 4.45), (0.45, 4.52), (0.32, 4.6), (0.3, 4.9), (0.12, 5.05), (0.08, 5.25), (0, 5.25)], 8, T(-1.8, 3.6, 0))
    # back shelf behind Sam: two boards, crates and jars
    for z in (3.2, 6.0):
        p.box("plank", (13.0, 1.3, 0.25), T(0, -4.0, z))
    for sx in (-1, 1): p.box("wood", (0.3, 1.3, 6.2), T(sx * 6.4, -4.0, 3.4))
    _crate(p, -4.4, -4.0, 3.33, 0.7)
    _crate(p, 4.2, -4.0, 6.13, 0.65)
    for i, x in enumerate((-1.8, -0.7, 0.4, 1.5)):
        p.lathe("glass", [(0.32, 3.33), (0.36, 3.6), (0.36, 4.2), (0.25, 4.35), (0, 4.35)], 8, T(x, -4.0, 0))
        p.lathe("cap", [(0.27, 4.33), (0.27, 4.5), (0, 4.5)], 8, T(x, -4.0, 0))
    # hay bales stacked by the back post
    for z, w in ((0.6, 3.2), (2.2, 2.6)):
        p.box("hay", (w, 1.8, 1.6), T(-6.0, -1.8, z + 0.8))
        for dx in (-0.7, 0.7): p.box("rope", (0.12, 1.84, 1.64), T(-6.0 + dx * w / 3.2, -1.8, z + 0.8))
    return p


def sam_hat():
    """Safari Sam's bush hat. Origin = centre of Sam's Head part, front +Y."""
    p = Piece("SamHat", bevel=0.02, bevels={"red": 0.0})
    M = S(1.0, 1.08, 1.0)
    p.lathe("khaki", [(0.88, 0.74), (1.6, 0.68), (1.98, 0.56), (2.0, 0.5), (1.6, 0.6), (0.88, 0.66)], 18, M, closed=True)
    p.lathe("khaki", [(0.99, 0.66), (0.97, 1.2), (0.88, 1.62), (0.6, 1.84), (0, 1.9)], 18, M)
    p.lathe("woodDark", [(0.97, 0.72), (1.03, 0.72), (1.03, 1.0), (0.97, 1.0)], 18, M, closed=True)
    p.extrude("red", [(0, 0), (0.18, 0.35), (0.12, 0.85), (0, 1.1), (-0.12, 0.85), (-0.18, 0.35)], 0.05, T(-1.04, 0.15, 0.8) @ Rz(90) @ Ry(-20))
    return p


def sam_outfit():
    """Vest, neckerchief, belt, binoculars and backpack for Safari Sam. Origin = centre of his UpperTorso, front +Y
    (the torso is 2.62 x 1.36 deep x 2.29 tall; the LowerTorso sits 1.35 below)."""
    p = Piece("SamOutfit", bevel=0.025, bevels={"glass": 0.0, "brass": 0.0})
    # vest: two front panels with a V neck, sides, back and shoulders
    for sx in (-1, 1):
        panel = [(sx * 1.37, 1.19), (sx * 0.5, 1.19), (sx * 0.14, 0.05), (sx * 0.14, -1.16), (sx * 1.37, -1.16)]
        p.extrude("olive", panel if sx < 0 else panel[::-1], 0.12, T(0, 0.75, 0))
        p.box("olive", (0.12, 1.5, 2.35), T(sx * 1.37, 0, 0.015))
        p.box("olive", (0.86, 1.5, 0.12), T(sx * 0.93, 0, 1.19))
        for z in (0.35, -0.6):
            p.box("khakiDark", (0.56, 0.08, 0.5), T(sx * 0.74, 0.85, z))
            p.box("oliveDark", (0.62, 0.12, 0.18), T(sx * 0.74, 0.87, z + 0.24))
            p.lathe("brass", [(0.06, 0), (0.06, 0.04), (0, 0.04)], 6, T(sx * 0.74, 0.93, z + 0.2) @ Rx(-90))
    p.box("olive", (2.86, 0.12, 2.35), T(0, -0.75, 0.015))
    # shirt collar and red neckerchief in the V
    for sx in (-1, 1):
        pts = [(sx * 0.1, 1.2), (sx * 0.62, 1.2), (sx * 0.34, 0.78)]
        p.extrude("khaki", pts if sx > 0 else pts[::-1], 0.06, T(0, 0.83, 0))
    p.extrude("red", [(-0.4, 1.12), (0.4, 1.12), (0, 0.5)], 0.06, T(0, 0.71, 0))
    p.ico("red", 0.16, 1, T(0, 0.8, 1.08))
    # belt with buckle and a side pouch
    p.box("woodDark", (2.8, 1.5, 0.32), T(0, 0, -1.2))
    p.box("brass", (0.46, 0.08, 0.38), T(0, 0.78, -1.2))
    p.box("woodDark", (0.24, 0.1, 0.18), T(0, 0.8, -1.2))
    p.box("khakiDark", (0.52, 0.28, 0.5), T(0.95, 0.85, -1.38))
    p.box("oliveDark", (0.56, 0.3, 0.16), T(0.95, 0.87, -1.15))
    # binoculars on a neck strap
    for sx in (-1, 1):
        p.lathe("ink", [(0.16, 0.0), (0.21, 0.08), (0.21, 0.42), (0.25, 0.5), (0.25, 0.56), (0, 0.56)], 10, T(sx * 0.27, 0.8, -0.12) @ Rx(-90))
        p.lathe("glass", [(0.19, 0), (0.19, 0.02), (0, 0.02)], 10, T(sx * 0.27, 1.365, -0.12) @ Rx(-90))
        p.tube("woodDark", [(sx * 0.4, 0.95, 0.05), (sx * 0.62, 0.84, 0.75), (sx * 0.48, 0.5, 1.22), (sx * 0.3, 0.0, 1.3)], [0.05] * 4, 4)
    p.box("ink", (0.3, 0.3, 0.2), T(0, 1.05, -0.12))
    # backpack with a rolled bedroll and shoulder straps
    p.box("olive", (2.0, 0.95, 2.05), T(0, -1.25, -0.05))
    p.box("oliveDark", (2.04, 0.99, 0.55), T(0, -1.25, 0.72))
    p.box("khakiDark", (1.2, 0.12, 0.6), T(0, -1.78, -0.4))
    p.lathe("cream", [(0.36, -1.1), (0.36, 1.1)], 10, T(0, -1.2, 1.32) @ Ry(90))
    for sx in (-1, 1):
        p.box("woodDark", (0.14, 0.8, 0.8), T(sx * 0.7, -1.2, 1.32))
        p.tube("oliveDark", [(sx * 0.6, -0.8, 1.05), (sx * 0.62, 0.0, 1.27), (sx * 0.6, 0.8, 0.95), (sx * 0.62, 0.82, -0.75)], [0.08] * 4, 4)
    return p


PIECES = [enclosure, easel, signboard, tree_round, tree_acacia, bush, rock, grass_tuft, lamp_post, bench,
          hedge, hedge_post, gate, hill, leaderboard, plaza, showcase, island, tree_palm, bush_flower, flowers, trader_stall, sam_hat, sam_outfit, race_grounds,
          race_track, race_start, race_log, race_hay, race_rocks, race_mud, boost_ring, race_pad,
          map_ground, border_fence] + [lambda s=s: race_stones(s) for s in range(STONE_SECTORS)]
SPACING = 400.0


def floating_report(objs, deps, tol=0.03):
    """Every loose mesh shell of a piece must touch the ground or, through a chain of touching shells, something that does.
    Two shells touch when their triangles intersect (one is pushed into the other) or a vertex of one lies within `tol`
    of the other's surface. Returns the shells that float (want: [])."""
    from mathutils.bvhtree import BVHTree
    shells = []  # (colour, min, max, verts, tree)
    for ob in objs:
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        bm = bmesh.new(); bm.from_mesh(me); ev.to_mesh_clear()
        bm.transform(ob.matrix_world)
        seen = set()
        for v in bm.verts:
            if v.index in seen: continue
            stack, members = [v], []
            seen.add(v.index)
            while stack:
                u = stack.pop()
                members.append(u)
                for e in u.link_edges:
                    w = e.other_vert(u)
                    if w.index not in seen:
                        seen.add(w.index); stack.append(w)
            local = {u.index: k for k, u in enumerate(members)}
            faces = {f for u in members for f in u.link_faces}
            co = [u.co.copy() for u in members]
            polys = [[local[x.index] for x in f.verts] for f in faces]
            mn = [min(c[k] for c in co) for k in range(3)]
            mx = [max(c[k] for c in co) for k in range(3)]
            shells.append((ob.name.split("__")[-1], mn, mx, co, BVHTree.FromPolygons(co, polys) if polys else None))
        bm.free()
    if not shells: return []
    ground = min(s[1][2] for s in shells)
    parent = list(range(len(shells)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    def near(a, b):
        if not b[4]: return False
        for c in a[3]:
            hit = b[4].find_nearest(c, tol)
            if hit[0] is not None: return True
        return False
    for i in range(len(shells)):
        for j in range(i + 1, len(shells)):
            a, b = shells[i], shells[j]
            if find(i) == find(j): continue
            if not all(a[1][k] <= b[2][k] + tol and b[1][k] <= a[2][k] + tol for k in range(3)): continue
            if (a[4] and b[4] and a[4].overlap(b[4])) or near(a, b) or near(b, a):
                parent[find(i)] = find(j)
    grounded = {find(i) for i, s in enumerate(shells) if s[1][2] <= ground + 0.05}
    return [f"{s[0]}@{[round(c, 2) for c in s[1]]}" for i, s in enumerate(shells) if find(i) not in grounded]


def run(render=True, only=None, name="ZooKit"):
    """only = piece names to export/render (everything is still built, so the .blend stays whole)."""
    old = bpy.data.scenes.get("ZooKit")
    if old:
        for ob in list(old.collection.all_objects): bpy.data.objects.remove(ob, do_unlink=True)
        for me in list(bpy.data.meshes):   # orphans from the last run would push new names to "<Piece>__<colour>.001"
            if me.users == 0: bpy.data.meshes.remove(me)
        scene = old
    else:
        scene = bpy.data.scenes.new("ZooKit")
    scene.unit_settings.system = 'NONE'
    if bpy.context.window: bpy.context.window.scene = scene   # no window when run with blender --background
    coll = scene.collection
    os.makedirs(os.path.join(OUT, "export"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "renders"), exist_ok=True)

    built = []
    for i, fn in enumerate(PIECES):
        root, objs = fn().build((i * SPACING, 0, 0), coll)
        built.append((root, objs))
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()

    stats = {"spacing": SPACING, "pieces": []}
    for root, objs in built:
        entry = {"name": root.name, "root": list(root.location), "tris": 0, "meshes": []}
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for ob in objs:
            ev = ob.evaluated_get(deps)
            me = ev.to_mesh()
            me.calc_loop_triangles()
            mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
            for v in me.vertices:
                w = ev.matrix_world @ v.co
                for k in range(3): mn[k], mx[k] = min(mn[k], w[k]), max(mx[k], w[k])
            tris = len(me.loop_triangles)
            ev.to_mesh_clear()
            entry["meshes"].append({"name": ob.name, "tris": tris, "center": [round(c, 4) for c in (mn + mx) / 2], "size": [round(c, 4) for c in mx - mn]})
            entry["tris"] += tris
            for k in range(3): lo[k], hi[k] = min(lo[k], mn[k]), max(hi[k], mx[k])
        entry["size"] = [round(c, 3) for c in hi - lo]
        entry["bbox_center"] = [round(c, 3) for c in (lo + hi) / 2]
        if only is None or root.name in only:
            entry["floating"] = floating_report(objs, deps)
        stats["pieces"].append(entry)
    with open(os.path.join(OUT, "export", "ZooKit_stats.json"), "w") as f: json.dump(stats, f, indent=1)

    # export only this scene: the window may still point at the user's own scene during this call
    vl = scene.view_layers[0]
    for root, objs in built:
        chosen = only is None or root.name in only
        for ob in [root] + objs: ob.select_set(chosen, view_layer=vl)
    with bpy.context.temp_override(scene=scene, view_layer=vl):
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "export", name + ".glb"), export_format='GLB', use_active_scene=True, use_selection=True,
                                  export_apply=True, export_yup=True, export_cameras=False, export_lights=False, export_normals=True)

    if render:
        for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
            try:
                scene.render.engine = eng
                break
            except TypeError: pass
        scene.render.resolution_x, scene.render.resolution_y = 720, 540
        scene.view_settings.view_transform = 'Standard'
        if not scene.world: scene.world = bpy.data.worlds.new("ZooWorld")
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes.get("Background")
        bg.inputs[0].default_value, bg.inputs[1].default_value = (0.55, 0.75, 1.0, 1), 0.9
        sun = bpy.data.objects.new("ZooSun", bpy.data.lights.new("ZooSun", 'SUN'))
        sun.data.energy, sun.rotation_euler = 3.2, (math.radians(50), 0, math.radians(35))
        cam = bpy.data.objects.new("ZooCam", bpy.data.cameras.new("ZooCam"))
        cam.data.clip_end = 5000
        coll.objects.link(sun); coll.objects.link(cam)
        scene.camera = cam
        for e in stats["pieces"]:
            if only and e["name"] not in only: continue
            c, s = Vector(e["bbox_center"]), Vector(e["size"])
            dist = max(s.x, s.y, s.z * 1.3) * 1.9 + 6
            cam.location = c + Vector((0.55, 0.75, 0.42)).normalized() * dist   # 3/4 view from the front
            cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
            for root, objs in built:
                for ob in objs: ob.hide_render = root.name != e["name"]
            scene.render.filepath = os.path.join(OUT, "renders", e["name"] + ".png")
            bpy.ops.render.render(write_still=True, scene=scene.name)
        for root, objs in built:
            for ob in objs: ob.hide_render = False
        bpy.data.objects.remove(sun, do_unlink=True); bpy.data.objects.remove(cam, do_unlink=True)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "DrawAZoo_Kit.blend"))
    return {"total_tris": sum(e["tris"] for e in stats["pieces"]), "pieces": {e["name"]: [e["tris"], len(e["meshes"]), e["size"]] for e in stats["pieces"]}}
