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
local STREAKS = "rbxassetid://71013397557210"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local NS, CS_ = NumberSequence.new, ColorSequence.new
local function ns(...) -- ns(t0, v0, t1, v1, ...)
	local a, k = { ... }, {}
	for i = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
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
	local X = Vector3.new(1, 0, 0)
	-- TextureSpeed > 0 scrolls toward Attachment1 (the bottom). Two streak layers down the face of the sheet: slow blue-white flow, faster sparse foam on top
	local top = att("FallTop", Vector3.new(WX, LIP + 0.25, 10.85), Vector3.new(0, -0.4, -1), X)
	local bottom = att("FallBottom", Vector3.new(WX, 0.75, 10.05), Vector3.new(0, 1, 0), X)
	local function beam(name, color, speed, length, transp, z, w0, w1)
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = top, bottom
		b.Texture, b.TextureMode, b.TextureLength, b.TextureSpeed = STREAKS, Enum.TextureMode.Wrap, length, speed
		b.Color, b.Transparency = CS_(color), transp
		b.Width0, b.Width1 = w0, w1
		b.CurveSize0, b.CurveSize1 = 1.1, 0
		b.Segments, b.ZOffset = 16, z
		b.FaceCamera = false
		b.LightEmission, b.LightInfluence = 0.25, 0.7
		b.Parent = sheet
	end
	beam("Flow", Color3.fromRGB(205, 240, 255), 1.4, 3.5, ns(0, 0.35, 0.85, 0.3, 1, 0.8), 0.06, 2.9, 3.4)
	beam("Foam", Color3.new(1, 1, 1), 2.4, 5.5, ns(0, 0.5, 0.8, 0.35, 1, 0.9), 0.12, 2.6, 3.2)

	local function emitter(parent, name, props)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		for k, v in props do e[k] = v end
		e.Parent = parent
	end
	-- foam rolling over the lip
	local lip = att("LipFX", Vector3.new(WX, LIP + 0.2, 10.9), Vector3.new(0, 0, -1), X)
	emitter(lip, "LipFoam", { Texture = SMOKE, Color = CS_(Color3.new(1, 1, 1)), Size = ns(0, 0.5, 1, 1.1), Transparency = ns(0, 0.35, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.55), Rate = 12, Speed = NumberRange.new(0.8, 1.4), SpreadAngle = Vector2.new(60, 10),
		Acceleration = Vector3.new(0, -9, 0), LightEmission = 0.2, Rotation = NumberRange.new(0, 360) })
	-- the plunge: foam puffs scattering sideways, droplets thrown up, a soft mist hiding the join
	local base = att("BaseFX", Vector3.new(WX, 0.85, 10.0), X, Vector3.new(0, 1, 0))
	emitter(base, "Splash", { Texture = SMOKE, Color = CS_(Color3.new(1, 1, 1)), Size = ns(0, 0.9, 1, 2.3), Transparency = ns(0, 0.35, 0.7, 0.65, 1, 1),
		Lifetime = NumberRange.new(0.5, 0.9), Rate = 16, Speed = NumberRange.new(2.5, 4.5), SpreadAngle = Vector2.new(55, 55),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -7, 0), Drag = 2.5, LightEmission = 0,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60) })
	emitter(base, "Droplets", { Texture = SPARK, Color = CS_(Color3.fromRGB(225, 248, 255)), Size = ns(0, 0.35, 1, 0.1), Transparency = ns(0, 0, 1, 0.6),
		Lifetime = NumberRange.new(0.55, 0.85), Rate = 14, Speed = NumberRange.new(5, 8), SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -26, 0), LightEmission = 0.5 })
	emitter(base, "Mist", { Texture = SMOKE, Color = CS_(Color3.fromRGB(235, 250, 255)), Size = ns(0, 3, 1, 6.5), Transparency = ns(0, 0.7, 0.5, 0.75, 1, 1),
		Lifetime = NumberRange.new(1.6, 2.6), Rate = 4, Speed = NumberRange.new(0.6, 1.5), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Drag = 1, LightEmission = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15) })
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
	local function prop(name, scale, x, z, yaw)
		local m = KIT[name]:Clone()
		m:ScaleTo(scale)
		m:PivotTo(F * CFrame.new(x, 10, z) * CFrame.Angles(0, yaw, 0))
		local cf, size = m:GetBoundingBox()
		local center = F:PointToObjectSpace(cf.Position)
		m:TranslateBy(F:VectorToWorldSpace(Vector3.new(x - center.X, 0, z - center.Z)) + Vector3.new(0, (FLOOR - 0.1) - (cf.Position.Y - size.Y / 2), 0))
		m.Parent = model
	end
	prop("TreePalm", 0.72, 12.4, 8.2, math.rad(200))
	prop("BushFlower", 0.48, -13.0, -8.0, math.rad(15))
	prop("Bush", 0.5, 13.1, -8.2, math.rad(-20))
	prop("Bush", 0.42, 13.3, 4.4, math.rad(60))
	prop("Flowers", 0.6, -10.8, -9.0, math.rad(10))
	prop("Flowers", 0.6, 10.6, -9.0, math.rad(-20))
	prop("Flowers", 0.55, 3.4, 8.6, math.rad(70))
	for _, g in { { -13.6, -4.5 }, { 13.6, -1.2 }, { -0.2, -8.8 }, { 6.5, -8.9 }, { -7.5, -8.9 }, { 7.0, 8.2 }, { 13.4, 6.4 }, { -13.6, 4.0 } } do
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
