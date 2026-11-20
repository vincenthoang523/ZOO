"""Render preview shots of the race loop placed round the real zoo (layout exported from Studio to export/zoo_layout.json).
Run after build_zoo_kit.run(): blender -b DrawAZoo_Kit.blend --python race_preview.py   -> renders/RacePreview_*.png
Kit pieces are placed as linked copies; Studio pivot (x, y, z, yaw) maps to Blender (x, -z, y) with the same yaw."""
import bpy, json, math, os, re, sys
from mathutils import Vector

D = r"C:\Users\polli\Downloads\claude files and projects\roblox\zoo\blender"
sys.path.insert(0, D)
import race_layout as L

kit = bpy.data.scenes["ZooKit"]
roots = {o.name: o for o in kit.collection.all_objects if o.type == 'EMPTY'}
sc = bpy.data.scenes.get("RacePreview")
if sc:
    for o in list(sc.collection.all_objects): bpy.data.objects.remove(o, do_unlink=True)
else:
    sc = bpy.data.scenes.new("RacePreview")
coll = sc.collection


def place(name, x, y, z, yaw_deg, scale=1.0):
    root = roots.get(name)
    if not root: return False
    for ch in root.children:
        o = ch.copy()                                        # shares the mesh (and evaluated modifiers)
        o.parent = None
        o.matrix_world = __import__("mathutils").Matrix.Translation((x, y, z)) @ __import__("mathutils").Matrix.Rotation(math.radians(yaw_deg), 4, 'Z') \
            @ __import__("mathutils").Matrix.Diagonal((scale, scale, scale, 1)) @ (root.matrix_world.inverted() @ ch.matrix_world)
        coll.objects.link(o)
    return True


missing = set()
for name, x, y, z, yaw, s in json.load(open(os.path.join(D, "export", "zoo_layout.json"))):
    base = re.sub(r"\d+$", "", name)
    if not place(base, x, -z, y, yaw, s): missing.add(base)
place("RaceTrack", 0, 0, 0, 0)
sa = math.radians(L.START_A)
x, y = L.spot(L.START_A, 0); place("RaceStart", x, y, -0.85, L.START_A)
for a, l in L.RINGS:
    x, y = L.spot(a, l); place("BoostRing", x, y, -0.85, a)
for n, a, l in L.OBSTACLES:
    x, y = L.spot(a, l); place(n, x, y, -0.85, a + (90 if n == "RaceMud" else 0))
place("RacePad", L.PAD[0], -L.PAD[1], 0, L.PAD[2])
# plain round the island (Studio's Horizon part) so the outskirts don't float in sky
bpy.ops.mesh.primitive_plane_add(size=1400, location=(0, 0, -3.5))
plain = bpy.context.active_object
for c in plain.users_collection: c.objects.unlink(plain)
coll.objects.link(plain)
pm = bpy.data.materials.new("PreviewPlain"); pm.use_nodes = True
pm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.68, 0.33, 1)
plain.data.materials.append(pm)

for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
    try:
        sc.render.engine = eng; break
    except TypeError: pass
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
sc.view_settings.view_transform = 'Standard'
sc.world = bpy.data.worlds.get("ZooWorld") or bpy.data.worlds.new("ZooWorld")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes.get("Background")
bg.inputs[0].default_value, bg.inputs[1].default_value = (0.62, 0.8, 1.0, 1), 1.0
sun = bpy.data.objects.new("PrevSun", bpy.data.lights.new("PrevSun", 'SUN'))
sun.data.energy, sun.rotation_euler = 3.4, (math.radians(40), 0, math.radians(30))
sun.data.angle = math.radians(3)
cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
cam.data.clip_end = 6000
coll.objects.link(sun); coll.objects.link(cam)
sc.camera = cam


def shot(name, loc, look, lens=30):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(look) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    sc.render.filepath = os.path.join(D, "renders", "RacePreview_" + name + ".png")
    bpy.ops.render.render(write_still=True, scene=sc.name)


def along(a, lat, h):
    x, y = L.spot(a, lat); return (x, y, h)


shot("1_overview", (0, -40, 560), (0, 0, 0), 26)
gx, gy = L.spot(L.START_A, 0)
shot("2_start_gate", (gx + 70, gy + 65, 38), (gx - 8, gy - 4, 0), 28)
shot("3_racer_view", along(100, -2, 7), along(118, -2, 3), 24)
shot("4_obstacles", along(140, 0, 32), along(168, 0, 0), 26)
shot("5_far_side", along(228, 30, 26), along(258, -2, 0), 26)
print("MISSING", sorted(missing))
