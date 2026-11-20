-- RaceBuilder: lays the animal race out round the zoo from the Blender pieces in ServerStorage.ZooKit
-- (blender/build_zoo_kit.py: race_track, race_start, race_log, race_hay, race_rocks, race_mud, boost_ring, race_pad)
-- at the spots in ReplicatedStorage.Zoo.RaceLayout. Builds workspace.Zoo.Race:
--   Track (visual mesh), Collision (ring of invisible boxes under the gravel), Start, Rings (tagged "BoostRing"),
--   Obstacles, Pad (with the RacePrompt and a live status board).
-- Run from the command bar:  require(game.ServerStorage.RaceBuilder:Clone()).build()
local Builder = {}

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local L = require(game:GetService("ReplicatedStorage").Zoo.RaceLayout)

local KIT = ServerStorage:WaitForChild("ZooKit")
local Z = workspace:WaitForChild("Zoo")

local function place(name, cf, parent, collide)
	local m = KIT[name]:Clone()
	m:PivotTo(cf)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = collide == true
			p.CanTouch = false
			p.CanQuery = collide == true
			if collide then p.CollisionFidelity = Enum.CollisionFidelity.Hull end
		end
	end
	m.Parent = parent
	return m
end

local function box(parent, name, cf, size)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Transparency, p.Size, p.CFrame = name, true, 1, size, cf
	p.CanTouch, p.CastShadow = false, false
	p.Parent = parent
	return p
end

local function sign(part, text, size, color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Face, g.SizingMode, g.PixelsPerStud, g.LightInfluence = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 0.3
		local t = Instance.new("TextLabel")
		t.Name, t.BackgroundTransparency, t.Size, t.Font, t.Text = "Text", 1, UDim2.fromScale(1, 1), Enum.Font.FredokaOne, text
		t.TextScaled, t.TextColor3, t.TextStrokeTransparency, t.RichText = true, color or Color3.new(1, 1, 1), 0, true
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0.04, 0), UDim.new(0.04, 0), UDim.new(size, 0), UDim.new(size, 0)
		pad.Parent = t
		t.Parent = g
		g.Parent = part
	end
end

function Builder.build()
	local old = Z:FindFirstChild("Race")
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "Race"

	place("RaceTrack", CFrame.new(), root)

	-- collision: 120 overlapping boxes, top flush with the gravel, wide enough to cover the wobbly edges
	local col = Instance.new("Folder")
	col.Name = "Collision"
	col.Parent = root
	local n = 120
	for i = 0, n - 1 do
		local a = 360 * (i + 0.5) / n
		local r0, r1 = L.edges(a)
		local mid, w = (r0 + r1) / 2 + 1, r1 - r0 + 3
		local len = 2 * math.pi * (mid + w / 2) / n + 0.6
		box(col, "Gravel", CFrame.new(mid * math.cos(math.rad(a)), L.TOP - 1, -mid * math.sin(math.rad(a))) * CFrame.Angles(0, math.rad(a), 0), Vector3.new(w, 2, len))
	end

	-- start / finish arch: the mesh has no collision (its hull would close the track); two boxes stand in for the posts
	local start = place("RaceStart", L.frame(L.START_A), root)
	start.Name = "Start"
	sign(start.red, "START  ·  FINISH", 0.12)
	for _, sx in { -1, 1 } do box(start, "PostCollider", L.frame(L.START_A, sx * 15.6) * CFrame.new(0, 6, 0), Vector3.new(1.6, 14, 1.6)).CanCollide = true end

	local rings = Instance.new("Folder")
	rings.Name = "Rings"
	rings.Parent = root
	for i, r in L.RINGS do
		local m = place("BoostRing", L.frame(r[1], r[2]), rings)
		m.Name = "Ring" .. i
		m.boost.Material = Enum.Material.Neon
		m:SetAttribute("Index", i)
		CollectionService:AddTag(m, "BoostRing")
	end

	local obs = Instance.new("Folder")
	obs.Name = "Obstacles"
	obs.Parent = root
	for i, o in L.OBSTACLES do
		local mud = o[1] == "RaceMud"
		local m = place(o[1], L.frame(o[2], o[3]) * CFrame.Angles(0, mud and math.pi / 2 or 0, 0), obs, not mud)
		m.Name = o[1] .. i
		if mud then m.mudWet.Reflectance = 0.12 end
	end

	-- sign-up pad: walk up and press E (ZooClient opens the Race window on "RacePrompt")
	local pad = place("RacePad", CFrame.new(L.PAD.x, 0, L.PAD.z) * CFrame.Angles(0, math.rad(L.PAD.yaw), 0), root, true)
	pad.Name = "Pad"
	pad.glow.Material = Enum.Material.Neon
	-- board: title on top, a status line underneath that ZooRace keeps up to date (every TextLabel named "Status")
	sign(pad.cream, '<font color="#FF8A00">ANIMAL</font> RACES', 0.06, Color3.fromHex("3C2D23"))
	for _, g in pad.cream:GetChildren() do
		g.Text.TextStrokeTransparency, g.Text.Size = 1, UDim2.fromScale(1, 0.6)
		local s = g.Text:Clone()
		s.Name, s.Text, s.RichText, s.Position, s.Size, s.TextColor3 = "Status", "Race on your animal!", false, UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.4), Color3.fromHex("8C5A32")
		s.Parent = g
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance, prompt.HoldDuration = "RacePrompt", "Join Race", "Animal Races", 12, 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad.stone

	root.Parent = Z
	return root
end

return Builder
