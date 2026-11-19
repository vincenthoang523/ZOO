-- StallBuilder: swaps Safari Sam's stall art for the imported TraderStall mesh (trader_stall() in blender/build_zoo_kit.py).
-- Run from the command bar, with the imported kit model as the argument:
--   require(game.ServerStorage.StallBuilder:Clone()).build(game.ServerStorage.ZooKit.TraderStall_v2)
-- Then check it:  print(require(game.ServerStorage.StallCheck:Clone()).run())
-- The stall faces +Z (toward the spawn), so piece space maps to the world with no turn: world = ORIGIN + (-x, z, y).
-- The old art is kept in ServerStorage.OldSafariStall.

local Builder = {}

local ORIGIN = Vector3.new(0, 0.1, 26.3) -- piece origin: plaza top (y 0.1) under the stall centre
local DECK_TOP = 0.71 -- deck boards top in piece space (Sam stands here)
local COUNTER_TOP = 4.45
local SIGN = Vector3.new(0, 5.78, 15.1) -- Sign part centre in piece space (TRADER_SIGN in the kit)

-- each colour mesh's bounding-box centre and size in piece space, from the Blender build
local MESHES = {
	stone = { c = Vector3.new(0, 0, 0.8), s = Vector3.new(19.6, 12.4, 1.6), hex = "D9D4C7" },
	cream = { c = Vector3.new(0, 0.46, 8.76), s = Vector3.new(19.8, 14.68, 17.52), hex = "FFF6E1" },
	plank = { c = Vector3.new(0, -0.25, 3.735), s = Vector3.new(18.3, 10.5, 6.53), hex = "D6A161" },
	plankAlt = { c = Vector3.new(0, 0.425, 3.735), s = Vector3.new(18.3, 10.15, 6.53), hex = "C38E55" },
	red = { c = Vector3.new(-0.49, 0, 9.4128), s = Vector3.new(17.42, 13.76, 16.2144), hex = "E8574F" },
	woodDark = { c = Vector3.new(0, 0.0375, 9.225), s = Vector3.new(19, 10.975, 17.25), hex = "6E4526" },
	wood = { c = Vector3.new(0, 0.207, 10.2143), s = Vector3.new(17.6, 10.3141, 14.0486), hex = "8C5A32" },
	paw = { c = Vector3.new(0, 2.0019, 8.6603), s = Vector3.new(15.86, 5.1962, 13.8395), hex = "FFF6E1" },
	yellow = { c = Vector3.new(0, 2.5726, 11.825), s = Vector3.new(20.44, 6.5148, 14.25), hex = "FFD046" },
	iron = { c = Vector3.new(0, 4.5, 11.51), s = Vector3.new(8.77, 0.866, 2.18), hex = "4A4E57" },
	glow = { c = Vector3.new(0, 4.5, 11.025), s = Vector3.new(8.64, 0.7275, 1.05), hex = "FFE08A" },
	rope = { c = Vector3.new(-4.78, 0.7106, 2.965), s = Vector3.new(2.76, 7.2613, 4.57), hex = "C9A46A" },
	leafLight = { c = Vector3.new(-0.0137, 4.7876, 3.8231), s = Vector3.new(19.3179, 3.0898, 3.1538), hex = "6FCB5F" },
	brass = { c = Vector3.new(-1.8, 3.6, 4.85), s = Vector3.new(0.877, 0.877, 0.8), hex = "E0B040" },
	glass = { c = Vector3.new(-0.15, -3.7, 3.9), s = Vector3.new(4.02, 0.72, 1), hex = "9ED8F0" },
	cap = { c = Vector3.new(-0.15, -3.7, 4.465), s = Vector3.new(3.8247, 0.5247, 0.17), hex = "8C5A32" },
	hay = { c = Vector3.new(-5.4, -2, 2.3), s = Vector3.new(3, 1.8, 3.2), hex = "F2C94C" },
	leaf = { c = Vector3.new(0.021, 5.4546, 2.1077), s = Vector3.new(19.5134, 1.9755, 1.3155), hex = "46A050" },
	leafDark = { c = Vector3.new(0.021, 5.4546, 1.65), s = Vector3.new(19.5134, 1.9755, 0.4), hex = "2F8A45" },
}

local function world(v) return ORIGIN + Vector3.new(-v.X, v.Z, v.Y) end

function Builder.build(kit)
	local stall = workspace.Zoo.SafariStall
	local art = Instance.new("Model")
	art.Name = "StallArt"
	local found = {}
	for _, src in kit:GetDescendants() do
		if src:IsA("MeshPart") then
			local colour = src.Name:match("__(.+)$") or src.Name
			local info = MESHES[colour]
			assert(info, "unknown mesh " .. src.Name)
			local p = src:Clone()
			p.Name = colour
			-- the importer maps piece axes (x, y, z) to mesh (-x, z, y); a size mismatch means the axes are off
			local want = Vector3.new(info.s.X, info.s.Z, info.s.Y)
			assert((p.Size - want).Magnitude < 0.05, colour .. " size " .. tostring(p.Size) .. " want " .. tostring(want))
			p.CFrame = CFrame.new(world(info.c))
			p.Color = Color3.fromHex(info.hex)
			p.Material = colour == "glow" and Enum.Material.Neon or colour == "glass" and Enum.Material.Glass or Enum.Material.SmoothPlastic
			p.Transparency = colour == "glass" and 0.2 or 0
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.CastShadow = colour ~= "glow"
			p.Parent = art
			found[colour] = true
		end
	end
	for colour in MESHES do assert(found[colour], "mesh missing from kit: " .. colour) end

	-- keep the old art
	local old = game.ServerStorage:FindFirstChild("OldSafariStall") or Instance.new("Folder")
	old.Name = "OldSafariStall"
	old.Parent = game.ServerStorage
	local prev = stall:FindFirstChild("StallArt")
	if prev then
		prev.Name = "StallArt_" .. os.date("!%Y%m%d%H%M")
		prev:SetAttribute("SignCFrame", stall.Sign.CFrame)
		prev.Parent = old
	end
	art.Parent = stall

	-- sign board sits in the cream frame on the roof; SurfaceGui stays on its Back (+Z) face
	stall.Sign.CFrame = CFrame.new(world(SIGN))
	-- invisible colliders follow the new shape
	local deckTop = ORIGIN.Y + DECK_TOP
	stall.Deck.Size = Vector3.new(19.6, deckTop - ORIGIN.Y, 12.4)
	stall.Deck.CFrame = CFrame.new(ORIGIN.X, (ORIGIN.Y + deckTop) / 2, ORIGIN.Z)
	stall.Counter.Size = Vector3.new(14.2, 4.0 - DECK_TOP, 2.2)
	stall.Counter.CFrame = CFrame.new(world(Vector3.new(0, 3.2, (DECK_TOP + 4.0) / 2)))
	stall.CounterTop.Size = Vector3.new(15.6, 0.45, 3.2)
	stall.CounterTop.CFrame = CFrame.new(world(Vector3.new(0, 3.4, COUNTER_TOP - 0.225)))
	for _, w in stall:GetChildren() do
		if w.Name == "Wall" then w:Destroy() end
	end
	local function wall(size, centre)
		local w = stall.Deck:Clone()
		w.Name = "Wall"
		w.Size = size
		w.CFrame = CFrame.new(world(centre))
		w.Parent = stall
	end
	wall(Vector3.new(14.0, 6.4, 0.3), Vector3.new(0, -4.5, 3.8)) -- back wall
	for _, sx in { -1, 1 } do wall(Vector3.new(0.35, 3.0, 8.2), Vector3.new(sx * 7.5, 0, 2.1)) end -- side walls

	-- Sam stands on the deck boards
	local sam = stall:FindFirstChild("SafariSam")
	if sam then
		local feet = math.huge
		for _, d in sam:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				feet = math.min(feet, d.Position.Y - d.Size.Y / 2)
			end
		end
		sam:PivotTo(sam:GetPivot() + Vector3.new(0, deckTop - feet, 0))
	end
	return art
end

return Builder
