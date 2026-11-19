-- EnclosureCheck: proves no enclosure part is floating.
-- Every visible BasePart is a node; two nodes are linked when their oriented boxes touch or overlap
-- (separating-axis test, 0.02 stud tolerance). A node is grounded when its lowest point reaches the
-- ground (y <= 0.02). Anything not connected to a grounded node is reported as floating.
-- Usage: require(game.ServerStorage.EnclosureCheck:Clone()).run()  -> report string

local Check = {}

local EPS = 0.02

local function axes(cf)
	return { cf.RightVector, cf.UpVector, -cf.LookVector }
end

local function touching(a, b)
	local A, B = axes(a.CFrame), axes(b.CFrame)
	local ha, hb = a.Size / 2, b.Size / 2
	local ea, eb = { ha.X, ha.Y, ha.Z }, { hb.X, hb.Y, hb.Z }
	local d = b.CFrame.Position - a.CFrame.Position
	local function sep(L)
		if L.Magnitude < 1e-6 then return false end
		L = L.Unit
		local ra = math.abs(A[1]:Dot(L)) * ea[1] + math.abs(A[2]:Dot(L)) * ea[2] + math.abs(A[3]:Dot(L)) * ea[3]
		local rb = math.abs(B[1]:Dot(L)) * eb[1] + math.abs(B[2]:Dot(L)) * eb[2] + math.abs(B[3]:Dot(L)) * eb[3]
		return math.abs(d:Dot(L)) > ra + rb + EPS
	end
	for i = 1, 3 do
		if sep(A[i]) or sep(B[i]) then return false end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if sep(A[i]:Cross(B[j])) then return false end
		end
	end
	return true
end

local function lowestY(p)
	local cf, h = p.CFrame, p.Size / 2
	return cf.Position.Y - (math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z)
end

-- skip (optional): an instance whose parts are left out, e.g. an NPC standing in the model
-- ground (optional): the height of the surface the model stands on (default 0)
function Check.model(m, skip, ground)
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and not (skip and d:IsDescendantOf(skip)) then table.insert(parts, d) end
	end
	local n = #parts
	local adj = table.create(n)
	for i = 1, n do adj[i] = {} end
	local unanchored = {}
	local index = {}
	for i, p in parts do index[p] = i end
	local function link(i, j)
		table.insert(adj[i], j)
		table.insert(adj[j], i)
	end
	-- box-vs-box: exact separating-axis test
	for i = 1, n do
		if not parts[i].Anchored then table.insert(unanchored, parts[i]:GetFullName()) end
		local pi = parts[i]
		if not pi:IsA("MeshPart") then
			local ri = pi.Size.Magnitude / 2
			for j = i + 1, n do
				local pj = parts[j]
				if not pj:IsA("MeshPart") and (pi.Position - pj.Position).Magnitude <= ri + pj.Size.Magnitude / 2 + EPS and touching(pi, pj) then
					link(i, j)
				end
			end
		end
	end
	-- meshes: use the real collision geometry (a bounding box would hide gaps under rounded rocks)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { m }
	local saved = {}
	for _, p in parts do saved[p] = p.CanQuery; p.CanQuery = true end
	for i, p in parts do
		if p:IsA("MeshPart") then
			for _, hit in workspace:GetPartsInPart(p, params) do
				local j = index[hit]
				if j and j ~= i then link(i, j) end
			end
		end
	end
	for p, v in saved do p.CanQuery = v end
	local seen, queue = {}, {}
	for i = 1, n do
		if lowestY(parts[i]) <= (ground or 0) + EPS then seen[i] = true; table.insert(queue, i) end
	end
	local h = 1
	while h <= #queue do
		for _, j in adj[queue[h]] do
			if not seen[j] then seen[j] = true; table.insert(queue, j) end
		end
		h += 1
	end
	local floating = {}
	for i = 1, n do
		if not seen[i] then
			local p = parts[i]
			table.insert(floating, string.format("%s at y=%.2f", p:GetFullName(), p.Position.Y))
		end
	end
	return n, floating, unanchored
end

function Check.run()
	local art = workspace.Zoo.Art
	local lines, bad = {}, 0
	for i = 1, 7 do
		local m = art:FindFirstChild("Enclosure" .. i)
		if not m then
			table.insert(lines, "Enclosure" .. i .. ": MISSING"); bad += 1
		else
			local n, floating, unanchored = Check.model(m)
			bad += #floating + #unanchored
			table.insert(lines, string.format("Enclosure%d: %d parts, %d floating, %d unanchored", i, n, #floating, #unanchored))
			for _, f in floating do table.insert(lines, "  FLOATING " .. f) end
			for _, u in unanchored do table.insert(lines, "  UNANCHORED " .. u) end
		end
	end
	table.insert(lines, bad == 0 and "RESULT: CLEAN" or ("RESULT: " .. bad .. " problems"))
	return table.concat(lines, "\n")
end

return Check
