-- EnclosureBuilder: rebuilds workspace.Zoo.Art.Enclosure1..7 around each plot's Pen.
-- Run from the command bar:  require(game.ServerStorage.EnclosureBuilder:Clone()).buildAll()
-- Then check it:              print(require(game.ServerStorage.EnclosureCheck:Clone()).run())
-- Everything is laid out in Pen-local space: x across, -z toward the plaza/pad, y up from the ground (y = 0).
-- The pen floor top stays at y ~0.46 (animals are placed relative to Pen), and nothing tall enters the
-- animals' wander box (|x| <= 11.25, |z| <= 7.5).

local Builder = {}

local Z = workspace:WaitForChild("Zoo")
local ART = Z:WaitForChild("Art")

local hex = Color3.fromHex
local C = {
	stone = hex("d9d4c7"), stoneDark = hex("b9b2a2"), cream = hex("fff6e1"),
	wood = hex("8c5a32"), woodDark = hex("6e4526"), woodLight = hex("c38e55"),
	grass = hex("7cc86e"), grassLight = hex("8fd67f"), leaf = hex("46a050"), leafLight = hex("6fcb5f"),
	sand = hex("f4e0aa"), water = hex("6fc8f0"), waterDeep = hex("4fb2e3"), foam = hex("eaf8ff"),
	rock = hex("cbc5b6"), rockDark = hex("b7b0a1"), rockLight = hex("e2ddd1"),
	yellow = hex("ffd046"), hay = hex("e8c45a"), lamp = hex("ffe08a"),
}
-- one accent per plot, same as the old enclosures
local ACCENTS = { hex("ff5f5f"), hex("ffa53c"), hex("ffd746"), hex("5ac878"), hex("46bee6"), hex("8278f0"), hex("f078c8") }

local SMOOTH = Enum.Material.SmoothPlastic

function Builder.build(i)
	local plot = Z.Plots["Plot" .. i]
	local pen = plot.Pen
	local F = CFrame.new(pen.Position.X, 0, pen.Position.Z) * (pen.CFrame - pen.CFrame.Position)
	local accent = ACCENTS[i]
	local mx = (i % 2 == 0) and -1 or 1 -- mirror the inside decor on every other plot
	local rng = Random.new(1000 + i)

	local model = Instance.new("Model")
	model.Name = "Enclosure" .. i

	local function part(name, color, size, lcf, shape, mat)
		local p = Instance.new("Part")
		p.Name = name
		if shape then p.Shape = shape end
		p.Size = size
		p.CFrame = F * lcf
		p.Color = color
		p.Material = mat or SMOOTH
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false -- matches the old art; the Plot's own parts handle gameplay
		p.CanTouch = false
		p.Parent = model
		return p
	end
	local function box(name, color, x0, x1, y0, y1, z0, z1, mat)
		return part(name, color, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), nil, mat)
	end
	-- flat disc lying on a surface (cylinder axis turned to vertical)
	local function disc(name, color, x, z, d, y0, y1)
		return part(name, color, Vector3.new(y1 - y0, d, d), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	end
	-- disc standing upright, facing -z (for things mounted on a front face)
	local function faceDisc(name, color, x, y, z, d, depth)
		return part(name, color, Vector3.new(depth, d, d), CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0), Enum.PartType.Cylinder)
	end
	-- rotated box whose lowest point sits `sink` below baseY; returns the part and its top height
	local function rockAt(name, color, x, z, size, yaw, pitch, roll, baseY, sink)
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
		local up = rot:VectorToObjectSpace(Vector3.yAxis)
		local hy = math.abs(up.X) * size.X / 2 + math.abs(up.Y) * size.Y / 2 + math.abs(up.Z) * size.Z / 2
		local cy = baseY - sink + hy
		local p = part(name, color, size, CFrame.new(x, cy, z) * rot)
		return p, cy + hy
	end
	local function prop(name, scale, x, z, yaw, baseY)
		local src = ART:FindFirstChild(name)
		if not src then return nil end
		local m = src:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanTouch = false end
		end
		m:ScaleTo(scale)
		m:PivotTo(F * CFrame.new(x, 10, z) * CFrame.Angles(0, yaw, 0))
		local cf, size = m:GetBoundingBox()
		local bottom = cf.Position.Y - size.Y / 2
		local center = F:PointToObjectSpace(cf.Position)
		-- put the bbox centre on (x, z) and its bottom 0.1 into the surface
		m:TranslateBy(F:VectorToWorldSpace(Vector3.new(x - center.X, 0, z - center.Z)) + Vector3.new(0, (baseY - 0.1) - bottom, 0))
		m.Parent = model
		return m
	end

	local ledges
	local FLOOR = 0.46 -- pen floor top
	local CAP = 1.75 -- curb cap top

	------------------------------------------------------------------ plinth
	box("Base", C.stone, -18, 18, 0, 0.42, -11.5, 14.5)
	box("Floor", C.grass, -15.5, 15.5, 0.38, FLOOR, -10.5, 10.5)
	-- curb walls
	box("Curb", C.stone, -18, 18, 0.4, 1.5, -11.5, -10.4)
	box("Curb", C.stone, -18, -15.4, 0.4, 1.5, -11.5, 14.5)
	box("Curb", C.stone, 15.4, 18, 0.4, 1.5, -11.5, 14.5)
	box("Curb", C.stone, -18, 18, 0.4, 1.5, 10.4, 14.5)
	-- cream cap with a small overhang
	box("Cap", C.cream, -18.2, 18.2, 1.45, CAP, -11.7, -10.25)
	box("Cap", C.cream, -18.2, -15.25, 1.45, CAP, -11.7, 14.7)
	box("Cap", C.cream, 15.25, 18.2, 1.45, CAP, -11.7, 14.7)
	box("Cap", C.cream, -15.3, 15.3, 1.45, CAP, 10.25, 14.7)
	-- darker skirt around the bottom
	box("Skirt", C.stoneDark, -18.3, 18.3, 0, 0.6, -11.8, -11.3)
	box("Skirt", C.stoneDark, -18.3, -17.8, 0, 0.6, -11.8, 14.8)
	box("Skirt", C.stoneDark, 17.8, 18.3, 0, 0.6, -11.8, 14.8)
	box("Skirt", C.stoneDark, -18.3, 18.3, 0, 0.6, 14.3, 14.8)

	------------------------------------------------------------------ fence
	local function post(x, z)
		box("Post", C.wood, x - 0.45, x + 0.45, CAP - 0.05, 4.0, z - 0.45, z + 0.45)
		box("PostCap", accent, x - 0.62, x + 0.62, 3.95, 4.35, z - 0.62, z + 0.62)
		box("PostTop", C.cream, x - 0.35, x + 0.35, 4.3, 4.6, z - 0.35, z + 0.35)
	end
	local FZ = -10.95 -- front curb centre line
	local SX = 16.7 -- side curb centre line
	for _, x in { -12.5, -8.3, -4.15, 0, 4.15, 8.3, 12.5 } do post(x, FZ) end
	for _, z in { -6.5, -2, 2.5, 7 } do post(-SX, z); post(SX, z) end
	for _, y in { 2.6, 3.5 } do
		box("Rail", C.woodLight, -SX, SX, y - 0.22, y + 0.22, FZ - 0.18, FZ + 0.18)
		box("Rail", C.woodLight, -SX - 0.18, -SX + 0.18, y - 0.22, y + 0.22, FZ, 10.9)
		box("Rail", C.woodLight, SX - 0.18, SX + 0.18, y - 0.22, y + 0.22, FZ, 10.9)
	end
	-- front corner pillars with lanterns
	for _, s in { -1, 1 } do
		local x = s * SX
		box("CornerPillar", C.stone, x - 0.85, x + 0.85, CAP - 0.05, 5.0, FZ - 0.85, FZ + 0.85)
		box("CornerBand", accent, x - 0.95, x + 0.95, 3.4, 3.9, FZ - 0.95, FZ + 0.95)
		box("CornerTop", C.cream, x - 1.0, x + 1.0, 4.95, 5.3, FZ - 1.0, FZ + 1.0)
		box("LanternBase", C.woodDark, x - 0.6, x + 0.6, 5.25, 5.5, FZ - 0.6, FZ + 0.6)
		box("Lantern", C.lamp, x - 0.4, x + 0.4, 5.45, 6.35, FZ - 0.4, FZ + 0.4, Enum.Material.Neon)
		for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			local px, pz = x + c[1] * 0.45, FZ + c[2] * 0.45
			box("LanternFrame", C.woodDark, px - 0.09, px + 0.09, 5.45, 6.4, pz - 0.09, pz + 0.09)
		end
		box("LanternRoof", C.woodDark, x - 0.75, x + 0.75, 6.35, 6.7, FZ - 0.75, FZ + 0.75)
		box("LanternTop", accent, x - 0.3, x + 0.3, 6.65, 6.95, FZ - 0.3, FZ + 0.3)
	end

	------------------------------------------------------------------ rock cliff along the back
	-- built from the zoo's own faceted Rock mesh, scaled up and stacked; each tier sinks well into the one below
	local function jitter(a) return (rng:NextNumber() * 2 - 1) * a end
	local STONE = { hex("d9d4c7"), hex("cbc5b6"), hex("e2ddd1") }
	local function boulder(scale, x, z, yaw, baseY, sink, k)
		local m = prop("Rock", scale, x, z, yaw, baseY - sink + 0.1)
		m.Name = "Boulder"
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.Color = STONE[(k % #STONE) + 1] end
		end
		local cf, size = m:GetBoundingBox()
		return cf.Position.Y + size.Y / 2
	end
	local lowTops = {}
	for k, x in { -11.6, -3.9, 3.9, 11.6 } do
		lowTops[k] = boulder(2.4 + jitter(0.15), x + jitter(0.3), 13.2 + jitter(0.2), math.rad(jitter(14)), CAP, 0.6, k)
	end
	local midTops = {}
	for k, x in { -7.8, 0, 7.8 } do
		local base = math.min(lowTops[k], lowTops[k + 1])
		midTops[k] = boulder(1.9 + jitter(0.12), x + jitter(0.3), 13.6, math.rad(180 + jitter(16)), base, 1.6, k + 1)
	end
	boulder(1.5, -2.6 * mx, 13.9, math.rad(jitter(20)), math.min(midTops[1], midTops[2]), 1.4, 2)
	ledges = { { -11.6, lowTops[1] }, { 11.6, lowTops[4] }, { 6.0 * mx, math.min(midTops[2], midTops[3]) } }
	-- low rocks at the cliff foot hide the seam with the floor
	for k, x in { -13.4, 13.4 } do
		boulder(0.9, x, 10.0, math.rad(rng:NextInteger(0, 359)), FLOOR, 0.15, k)
	end

	------------------------------------------------------------------ waterfall + pond (mirrored per plot)
	local wx = -7.4 * mx
	local function mbox(name, color, x0, x1, y0, y1, z0, z1, mat)
		local a, b = x0 * mx, x1 * mx
		return box(name, color, math.min(a, b), math.max(a, b), y0, y1, z0, z1, mat)
	end
	mbox("Pond", C.water, -12.2, -2.6, 0.4, 0.53, 7.7, 10.6)
	mbox("PondDeep", C.waterDeep, -10.4, -4.4, 0.45, 0.55, 8.5, 10.6)
	local wTop = lowTops[mx == 1 and 2 or 3] - 1.4 -- just under the rock it pours from
	box("Waterfall", C.water, wx - 1.3, wx + 1.3, 0.45, wTop, 9.0, 10.9)
	box("WaterfallLip", C.foam, wx - 1.5, wx + 1.5, wTop - 0.3, wTop + 0.2, 8.9, 10.9)
	for j = -1, 1 do
		part("Foam", C.foam, Vector3.new(1.1, 0.5, 1.1), CFrame.new(wx + j * 0.95, 0.7, 8.8) * CFrame.Angles(0, math.rad(25 + j * 20), 0))
	end
	-- pebbles along the pond's front edge
	for j, px in { -11.4, -9.2, -6.6, -4.2 } do
		local size = Vector3.new(1.4 + jitter(0.2), 0.55, 0.9 + jitter(0.15))
		rockAt("Pebble", (j % 2 == 0) and C.rockLight or C.rock, px * mx, 7.75 + jitter(0.1), size, math.rad(jitter(25)), 0, 0, FLOOR, 0.12)
	end

	------------------------------------------------------------------ inside decor
	-- round sand and grass blobs on the floor (flat discs, overlapping into soft shapes)
	for _, b in { { 4.6, -2.2, 6.2 }, { 7.4, -4.4, 3.6 } } do
		disc("Sand", C.sand, b[1] * mx, b[2], b[3], FLOOR - 0.02, FLOOR + 0.05)
	end
	for _, b in { { -5.6, -3.6, 4.8 }, { -1.8, 3.8, 3.2 } } do
		disc("GrassPatch", C.grassLight, b[1] * mx, b[2], b[3], FLOOR - 0.02, FLOOR + 0.04)
	end

	-- feeding trough against the side fence
	local tx = -13.4 * mx
	for _, c in { { -0.75, -1.4 }, { -0.75, 1.4 }, { 0.75, -1.4 }, { 0.75, 1.4 } } do
		local lx, lz = tx + c[1], 1 + c[2]
		box("TroughLeg", C.woodDark, lx - 0.17, lx + 0.17, FLOOR - 0.05, 1.1, lz - 0.17, lz + 0.17)
	end
	box("Trough", C.wood, tx - 1.0, tx + 1.0, 1.0, 1.85, -0.75, 2.75)
	box("TroughRim", C.woodLight, tx - 1.12, tx + 1.12, 1.8, 2.0, -0.87, 2.87)
	box("Hay", C.hay, tx - 0.8, tx + 0.8, 1.9, 2.2, -0.55, 2.55)
	for j = 0, 2 do
		part("HayTuft", C.yellow, Vector3.new(0.9, 0.35, 0.6), CFrame.new(tx + jitter(0.3), 2.25, 0 + j * 1.0) * CFrame.Angles(0, math.rad(jitter(40)), math.rad(jitter(15))))
	end

	-- props reused from the zoo's own art so they match exactly
	prop("TreePalm", 0.72, 12.4 * mx, 8.4, math.rad(200), FLOOR)
	prop("Bush", 0.55, ledges[1][1], 12.6, math.rad(10), ledges[1][2] - 1.0)
	prop("BushFlower", 0.5, ledges[2][1], 12.6, math.rad(-30), ledges[2][2] - 1.0)
	prop("Bush", 0.45, ledges[3][1], 13.0, math.rad(45), ledges[3][2] - 1.0)
	prop("BushFlower", 0.48, -13.0 * mx, -8.0, math.rad(15), FLOOR)
	prop("Bush", 0.5, 13.1 * mx, -8.2, math.rad(-20), FLOOR)
	prop("Bush", 0.42, 13.3 * mx, 4.4, math.rad(60), FLOOR)
	prop("Rock", 0.75, -1.2 * mx, 9.1, math.rad(40), FLOOR)
	prop("Rock", 0.6, -13.5 * mx, 6.2, math.rad(-30), FLOOR)
	for _, g in { { -13.6, -4.5 }, { 13.6, -1.2 }, { -0.2, -8.8 }, { 6.5, -8.9 }, { -7.5, -8.9 }, { 9.3, 9.6 }, { 13.4, 7.0 }, { -13.6, 4.0 } } do
		prop("GrassTuft", 0.55, g[1] * mx, g[2], math.rad(rng:NextInteger(0, 359)), FLOOR)
	end
	prop("Flowers", 0.6, -10.8 * mx, -9.0, math.rad(10), FLOOR)
	prop("Flowers", 0.6, 10.6 * mx, -9.0, math.rad(-20), FLOOR)
	prop("Flowers", 0.55, 4.3 * mx, 9.2, math.rad(70), FLOOR)

	------------------------------------------------------------------ gateway arch over the back
	for _, s in { -1, 1 } do
		local x = s * 17
		box("PillarFoot", C.stoneDark, x - 1.6, x + 1.6, CAP - 0.05, 2.9, 10.9, 14.1)
		box("Pillar", C.cream, x - 1.2, x + 1.2, 2.85, 16.0, 11.3, 13.7)
		box("PillarBand", accent, x - 1.35, x + 1.35, 6.0, 6.6, 11.15, 13.85)
		box("PillarBand", accent, x - 1.35, x + 1.35, 11.0, 11.6, 11.15, 13.85)
		box("PillarHead", C.woodDark, x - 1.5, x + 1.5, 15.9, 16.6, 11.0, 14.0)
	end
	box("Beam", C.wood, -19.5, 19.5, 16.5, 18.9, 11.0, 14.0)
	box("BeamCap", C.woodDark, -20, 20, 18.85, 19.35, 10.8, 14.2)
	box("BeamTrim", C.cream, -19.5, 19.5, 16.35, 16.65, 10.85, 11.3)
	-- striped scalloped awning hanging off the beam's front
	for j = 0, 14 do
		local x = -14 + j * 2
		local col = (j % 2 == 0) and accent or C.cream
		box("Awning", col, x - 1, x + 1, 15.3, 16.55, 10.6, 11.15)
		faceDisc("Scallop", col, x, 15.3, 10.875, 2.0, 0.5)
	end
	-- sign with a paw on the beam
	box("SignBack", C.cream, -7.4, 7.4, 16.5, 19.9, 10.55, 10.95)
	box("Sign", accent, -7, 7, 16.75, 19.65, 10.3, 10.65)
	faceDisc("Paw", C.cream, 0, 17.7, 10.15, 1.4, 0.35)
	for _, t in { { -0.95, 18.55, 0.6 }, { 0.95, 18.55, 0.6 }, { -0.35, 19.0, 0.6 }, { 0.35, 19.0, 0.6 } } do
		faceDisc("Toe", C.cream, t[1], t[2], 10.15, t[3], 0.35)
	end
	for _, s in { -1, 1 } do
		part("Finial", C.yellow, Vector3.new(1.4, 1.4, 1.4), CFrame.new(s * 18.4, 19.95, 12.5), Enum.PartType.Ball)
		box("Star", C.yellow, s * 4.6 - 0.45, s * 4.6 + 0.45, 17.75, 18.65, 10.1, 10.35)
	end

	------------------------------------------------------------------ welcome pad in front
	box("PadRim", C.cream, -11.8, 11.8, 0, 0.25, -21.2, -11.6)
	box("Pad", accent, -11, 11, 0.2, 0.32, -20.4, -12.4)
	disc("PadPaw", C.cream, 0, -17.6, 3.4, 0.3, 0.38)
	for _, t in { { -2.2, -15.5, 1.5 }, { 2.2, -15.5, 1.5 }, { -0.8, -14.6, 1.5 }, { 0.8, -14.6, 1.5 } } do
		disc("PadToe", C.cream, t[1], t[2], t[3], 0.3, 0.38)
	end

	return model
end

function Builder.buildAll()
	local SS = game:GetService("ServerStorage")
	local backup = SS:FindFirstChild("OldEnclosures")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "OldEnclosures"
		backup.Parent = SS
	end
	for i = 1, 7 do
		local old = ART:FindFirstChild("Enclosure" .. i)
		if old then
			if old:GetAttribute("Rebuilt") then
				old:Destroy() -- a previous run of this builder
			elseif not backup:FindFirstChild(old.Name) then
				old.Parent = backup -- keep the original art, never destroy it
			else
				old:Destroy()
			end
		end
		local m = Builder.build(i)
		m:SetAttribute("Rebuilt", true)
		m.Parent = ART
		task.wait()
	end
end

return Builder
