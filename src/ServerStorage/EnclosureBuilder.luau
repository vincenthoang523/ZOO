-- EnclosureBuilder: rebuilds workspace.Zoo.Art.Enclosure1..7 around each plot's Pen from the Blender mesh
-- ServerStorage.ZooKit.Enclosure (blender/build_zoo_kit.py, enclosure()), then adds props and the waterfall VFX.
-- Run from the command bar:  require(game.ServerStorage.EnclosureBuilder:Clone()).buildAll()
-- Then check it:              print(require(game.ServerStorage.EnclosureCheck:Clone()).run())
-- Pen-local space: x across, -z toward the plaza/pad, y up from the ground (y = 0). Pen floor top is y 0.46 and
-- nothing tall enters the animals' wander box (|x| <= 11.25, |z| <= 7.5).
-- The part-built version this replaced is kept in ServerStorage.OldEnclosures.EnclosureBuilder_PartsV1.

local Builder = {}

local Z = workspace:WaitForChild("Zoo")
local ART = Z:WaitForChild("Art")
local KIT = game:GetService("ServerStorage"):WaitForChild("ZooKit")
local CS = game:GetService("CollectionService")

local hex = Color3.fromHex
local ACCENTS = { hex("ff5f5f"), hex("ffa53c"), hex("ffd746"), hex("5ac878"), hex("46bee6"), hex("8278f0"), hex("f078c8") }
local FLOOR = 0.46

-- waterfall, from build_zoo_kit.py (WF_X, WF_LIP); Pen z = -Blender y
local WX, LIP = -7.4, 7.2
-- textures from blender/make_water_textures.py (docs/ASSETS.md)
local BODY = "rbxassetid://76830687438614"   -- soft wavy bands for the body of the water
local WISPS = "rbxassetid://123457945444194" -- thin tapered wisps
local FOAM = "rbxassetid://81721995905362"   -- 2x2 flipbook of foam puffs
local DROPS = "rbxassetid://74750638253978"  -- 2x2 flipbook of droplets

local NS, CS_ = NumberSequence.new, ColorSequence.new
local function ns(...) -- ns(t0, v0, t1, v1, ...) or ns({t, v, envelope}, ...) for per-particle variation
	local a, k = { ... }, {}
	if type(a[1]) == "table" then
		for _, p in a do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	else
		for i = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	end
	return NS(k)
end

local function waterfallFX(model, F)
	local sheet = model:FindFirstChild("water")
	-- a Beam bends toward each attachment's Axis (CurveSize) and lays its width along the SecondaryAxis
	local function att(name, pos, axis, secondary)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = sheet
		a.WorldPosition = F * pos
		a.WorldAxis = F:VectorToWorldSpace(axis.Unit)
		a.WorldSecondaryAxis = F:VectorToWorldSpace(secondary.Unit)
		return a
	end
	local X, UP, FWD = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)
	local function beam(name, a0, a1, tex, color, speed, length, transp, z, w0, w1, curve)
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture, b.TextureMode, b.TextureLength, b.TextureSpeed = tex, Enum.TextureMode.Wrap, length, speed
		b.Color, b.Transparency = CS_(color), transp
		b.Width0, b.Width1 = w0, w1
		b.CurveSize0, b.CurveSize1 = curve or 0, 0
		b.Segments, b.ZOffset = 16, z
		b.FaceCamera = false
		b.LightEmission, b.LightInfluence = 0.15, 0.8
		b.Parent = sheet
	end
	-- TextureSpeed > 0 scrolls toward Attachment1. The pool on top drifts slowly to the lip; the fall has a body layer
	-- and two wisp layers at different speeds and scales, so nothing lines up and it reads as moving water.
	local poolBack = att("PoolBack", Vector3.new(WX, LIP + 0.42, 12.4), FWD, X)
	local poolLip = att("PoolLip", Vector3.new(WX, LIP + 0.42, 11.05), FWD, X)
	beam("PoolFlow", poolBack, poolLip, BODY, Color3.fromRGB(190, 235, 255), 0.5, 2.5, ns(0, 0.6, 0.3, 0.3, 1, 0.3), 0.04, 2.9, 3.0)
	beam("PoolWisps", poolBack, poolLip, WISPS, Color3.new(1, 1, 1), 0.8, 2.2, ns(0, 0.8, 0.4, 0.45, 1, 0.4), 0.08, 2.7, 3.0)
	local top = att("FallTop", Vector3.new(WX, LIP + 0.25, 10.85), Vector3.new(0, -0.4, -1), X)
	local bottom = att("FallBottom", Vector3.new(WX, 0.75, 10.05), UP, X)
	beam("Body", top, bottom, BODY, Color3.fromRGB(175, 228, 255), 1.0, 7, ns(0, 0.15, 1, 0.35), 0.03, 2.9, 3.4, 1.1)
	beam("Wisps", top, bottom, WISPS, Color3.new(1, 1, 1), 2.0, 5, ns(0, 0.2, 0.85, 0.15, 1, 0.7), 0.08, 2.8, 3.4, 1.1)
	beam("WispsFast", top, bottom, WISPS, Color3.fromRGB(235, 250, 255), 3.4, 8.5, ns(0, 0.5, 0.8, 0.4, 1, 0.85), 0.13, 2.4, 3.0, 1.1)

	local function emitter(parent, name, props)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		-- every foam/droplet particle shows its own random frame of the 2x2 sheet and keeps it
		e.FlipbookLayout, e.FlipbookMode, e.FlipbookFramerate, e.FlipbookStartRandom =
			Enum.ParticleFlipbookLayout.Grid2x2, Enum.ParticleFlipbookMode.Loop, NumberRange.new(0), true
		e.Rotation = NumberRange.new(0, 360)
		e.LightInfluence = 0.45 -- a little sun shading keeps overlapping puffs readable as separate lumps
		for k, v in props do e[k] = v end
		e.Parent = parent
		return e
	end
	local white, pale = CS_(Color3.new(1, 1, 1)), CS_(Color3.fromRGB(225, 246, 255))

	-- foam rolling over the lip
	local lip = att("LipFX", Vector3.new(WX, LIP + 0.25, 10.9), FWD, UP)
	emitter(lip, "LipFoam", { Texture = FOAM, Color = white, Size = ns({ 0, 0.4, 0.15 }, { 1, 0.9, 0.3 }), Transparency = ns(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.6), Rate = 16, Speed = NumberRange.new(1, 2.2), SpreadAngle = Vector2.new(70, 15),
		EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -12, 0), RotSpeed = NumberRange.new(-90, 90) })

	-- the plunge, at the water surface
	local base = att("BaseFX", Vector3.new(WX, 0.85, 10.0), X, UP)
	emitter(base, "Splash", { Texture = FOAM, Color = white, Size = ns({ 0, 0.7, 0.3 }, { 0.35, 1.7, 0.5 }, { 1, 2.6, 0.6 }),
		Transparency = ns(0, 0.05, 0.6, 0.25, 1, 1), Squash = ns({ 0, 0, 0.2 }, { 0.5, 0.25, 0.25 }, { 1, -0.15, 0.2 }),
		Lifetime = NumberRange.new(0.5, 1.1), Rate = 22, Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -12, 0), Drag = 1.5, RotSpeed = NumberRange.new(-90, 90) })
	emitter(base, "Spray", { Texture = FOAM, Color = pale, Size = ns({ 0, 0.3, 0.15 }, { 1, 0.75, 0.25 }), Transparency = ns(0, 0.1, 0.7, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.4, 0.75), Rate = 18, Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(80, 25),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -32, 0), RotSpeed = NumberRange.new(-180, 180) })
	emitter(base, "Droplets", { Texture = DROPS, Color = pale, Size = ns({ 0, 0.4, 0.15 }, { 1, 0.25, 0.1 }), Transparency = ns(0, 0, 0.8, 0.1, 1, 1),
		Lifetime = NumberRange.new(0.5, 1.0), Rate = 20, Speed = NumberRange.new(6, 11), SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -35, 0), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(0) })
	emitter(base, "Mist", { Texture = FOAM, Color = pale, Size = ns({ 0, 3, 0.8 }, { 1, 7, 1.5 }), Transparency = ns(0, 0.86, 0.5, 0.88, 1, 1),
		Lifetime = NumberRange.new(2, 3), Rate = 2, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Drag = 1, LightEmission = 0.1, RotSpeed = NumberRange.new(-15, 15) })
	-- foam spreading flat across the pond
	local churn = att("ChurnFX", Vector3.new(WX, 0.8, 9.6), X, UP)
	emitter(churn, "Churn", { Texture = FOAM, Color = white, Size = ns({ 0, 1, 0.3 }, { 1, 3.4, 0.6 }), Transparency = ns(0, 0.3, 0.6, 0.55, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.4), Rate = 6, Speed = NumberRange.new(0.1), Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, RotSpeed = NumberRange.new(-30, 30) })
	-- irregular bursts, fired at random moments by Art.WaterfallFX on clients
	local burst = emitter(base, "Burst", { Texture = FOAM, Color = white, Size = ns({ 0, 1.0, 0.4 }, { 1, 2.8, 0.7 }), Transparency = ns(0, 0, 0.7, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.6, 1.0), Rate = 0, Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -25, 0), RotSpeed = NumberRange.new(-120, 120) })
	local burstDrops = emitter(base, "BurstDrops", { Texture = DROPS, Color = pale, Size = ns({ 0, 0.45, 0.15 }, { 1, 0.3, 0.1 }), Transparency = ns(0, 0, 1, 0.8),
		Lifetime = NumberRange.new(0.6, 1.1), Rate = 0, Speed = NumberRange.new(8, 13), SpreadAngle = Vector2.new(45, 45),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -35, 0), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(0) })
	CS:AddTag(burst, "WaterfallBurst")
	CS:AddTag(burstDrops, "WaterfallBurst")
	-- the ripple ring is pulsed outwards by Art.WaterfallFX on clients
	CS:AddTag(model:FindFirstChild("ripple"), "WaterfallRipple")
end

function Builder.build(i)
	local plot = Z.Plots["Plot" .. i]
	local pen = plot.Pen
	local F = CFrame.new(pen.Position.X, 0, pen.Position.Z) * (pen.CFrame - pen.CFrame.Position)
	local accent = ACCENTS[i]
	local rng = Random.new(1000 + i)

	local model = KIT.Enclosure:Clone()
	model.Name = "Enclosure" .. i
	model:PivotTo(F)
	model.accent.Color = accent

	-- props reused from the zoo's own kit, standing on the pen floor (bbox bottom 0.1 into it)
	local function prop(name, scale, x, z, yaw, atPivot)
		local m = KIT[name]:Clone()
		m:ScaleTo(scale)
		if atPivot then -- the pivot is the base (palm trunk foot): put it exactly at (x, z)
			m:PivotTo(F * CFrame.new(x, FLOOR - 0.1, z) * CFrame.Angles(0, yaw, 0))
			m.Parent = model
			return
		end
		m:PivotTo(F * CFrame.new(x, 10, z) * CFrame.Angles(0, yaw, 0))
		local cf, size = m:GetBoundingBox()
		local center = F:PointToObjectSpace(cf.Position)
		m:TranslateBy(F:VectorToWorldSpace(Vector3.new(x - center.X, 0, z - center.Z)) + Vector3.new(0, (FLOOR - 0.1) - (cf.Position.Y - size.Y / 2), 0))
		m.Parent = model
	end
	-- the palm leans along its +x; yaw 112 turns that toward the front and the pen centre, away from the cliff
	prop("TreePalm", 0.72, 12.6, 6.6, math.rad(112), true)
	prop("BushFlower", 0.48, -13.0, -8.0, math.rad(15))
	prop("Bush", 0.5, 13.1, -8.2, math.rad(-20))
	prop("Bush", 0.42, 13.3, 4.4, math.rad(60))
	prop("Flowers", 0.6, -10.8, -9.0, math.rad(10))
	prop("Flowers", 0.6, 10.6, -9.0, math.rad(-20))
	prop("Flowers", 0.55, 3.4, 8.6, math.rad(70))
	for _, g in { { -13.6, -4.5 }, { 13.6, -1.2 }, { -0.2, -8.8 }, { 6.5, -8.9 }, { -7.5, -8.9 }, { 7.0, 8.2 }, { 10.6, 8.8 }, { -13.6, 4.0 } } do
		prop("GrassTuft", 0.55, g[1], g[2], math.rad(rng:NextInteger(0, 359)))
	end

	waterfallFX(model, F)
	return model
end

function Builder.buildAll()
	for i = 1, 7 do
		local old = ART:FindFirstChild("Enclosure" .. i)
		if old then old:Destroy() end -- the original art is already kept in ServerStorage.OldEnclosures
		local m = Builder.build(i)
		m:SetAttribute("Rebuilt", true)
		m.Parent = ART
		task.wait()
	end
end

return Builder
