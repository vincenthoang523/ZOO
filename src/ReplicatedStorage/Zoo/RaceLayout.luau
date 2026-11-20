-- RaceLayout: where the gravel race loop and everything on it sits. Same numbers as blender/race_layout.py.
-- An "angle" is degrees round the zoo centre measured like Blender's XY plane: world x = r*cos(a), world z = -r*sin(a).
-- Racers run toward increasing angle. "lat" is studs across the track from the centre line (+ = outward).
local L = {}

L.CENTRE_R = 150
L.TOP = -0.85 -- gravel surface height
L.START_A = 84 -- start/finish line, just east of the gate (the gate is at 90)
L.GRID = {} -- 8 starting spots, two rows of four behind the line
for row = 0, 1 do
	for _, lat in { -7.5, -2.5, 2.5, 7.5 } do table.insert(L.GRID, { L.START_A - 2 - 2.4 * row, lat }) end
end
L.RINGS = { { 110, -7 }, { 140, 7 }, { 175, 0 }, { 205, -8 }, { 235, 6 }, { 270, -6 }, { 300, 8 }, { 330, -2 }, { 355, 7 }, { 25, -7 }, { 52, 5 } }
L.OBSTACLES = { { "RaceLog", 125, 6 }, { "RaceHay", 152, -8 }, { "RaceMud", 160, 4 }, { "RaceRocks", 190, 8 }, { "RaceLog", 220, -6 },
	{ "RaceMud", 250, 0 }, { "RaceHay", 262, 9 }, { "RaceRocks", 285, -9 }, { "RaceLog", 315, 5 }, { "RaceMud", 345, -5 },
	{ "RaceHay", 10, 2 }, { "RaceRocks", 40, -9 }, { "RaceLog", 66, -5 } }
L.PAD = { x = 30, z = -100, yaw = 90 } -- sign-up pad inside the gate, board on its east side
L.MUD_RX, L.MUD_RZ = 3.6, 5.0 -- mud ellipse half sizes: across the track, along it
L.BORDER_R = 176 -- border fence round the loop (border_fence() in build_zoo_kit.py)
-- walking out through the gate (this box, in world space) asks the player if they want to join the next race
L.GATE_ZONE = { centre = Vector3.new(0, 2, -133), size = Vector3.new(22, 10, 8) }

-- gravel edges (inner, outer radius) at an angle; must match track_edges() in build_zoo_kit.py
function L.edges(aDeg: number): (number, number)
	local a = math.rad(aDeg)
	return 137 + 0.9 * math.sin(7 * a + 1) + 0.6 * math.sin(13 * a), 163 + 1.0 * math.sin(5 * a + 2) + 0.7 * math.sin(11 * a + 0.5)
end

-- a point on the gravel, facing along the track; its X axis points outward across the track
function L.frame(aDeg: number, lat: number?): CFrame
	local a, r = math.rad(aDeg), L.CENTRE_R + (lat or 0)
	return CFrame.new(r * math.cos(a), L.TOP, -r * math.sin(a)) * CFrame.Angles(0, a, 0)
end

-- angle of a world position, 0..360
function L.angle(p: Vector3): number
	return math.deg(math.atan2(-p.Z, p.X)) % 360
end

return L
