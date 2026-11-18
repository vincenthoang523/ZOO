--!nonstrict
-- Render: turns a saved drawing into GUI frames. Used by the editor, the inventory and the animals in the world.
-- A design is { n = name, g = grid string, e = { {x, y, style, size} }, s = { {x, y, sticker, size} } }
local Config = require(script.Parent.Config)
local W, H = Config.W, Config.H
local Render = {}

-- Drawings are saved run-length encoded: "~" then one run per stretch of same-coloured cells, written as
-- <colour char><count>. (colour char = 48 + palette index). 240 x 168 = 40320 cells is 40 KB raw; a typical animal is 1-3 KB like this.
function Render.encode(cells)
	local out, n, i = { "~" }, #cells, 1
	while i <= n do
		local v, j = cells[i], i
		while j < n and cells[j + 1] == v do j += 1 end
		table.insert(out, string.char(48 + v) .. (j - i + 1) .. ".")
		i = j + 1
	end
	return table.concat(out)
end

-- Strict reader for encoded drawings: nil unless every run is a real palette colour and the runs fill exactly `total` cells.
local function unpackRuns(g, total)
	local cells, i = table.create(total, 0), 0
	for ch, count in string.gmatch(string.sub(g, 2), "(.)(%d+)%.") do
		local v, c = string.byte(ch) - 48, tonumber(count)
		if v < 0 or v > #Config.PALETTE or not c or c < 1 or i + c > total then return nil end
		for k = i + 1, i + c do cells[k] = v end
		i += c
	end
	if i ~= total then return nil end
	return cells
end

function Render.decode(g)
	if string.sub(g, 1, 1) == "~" then return unpackRuns(g, W * H) or table.create(W * H, 0) end
	local cells = table.create(W * H, 0)
	if #g ~= W * H then -- saved on an older, coarser grid: scale it up (each cell takes its nearest old cell)
		for _, size in Config.OLD_GRIDS do
			local OW, OH = size[1], size[2]
			if #g == OW * OH then
				for y = 0, H - 1 do
					local row = math.floor(y * OH / H) * OW
					for x = 0, W - 1 do
						cells[y * W + x + 1] = (string.byte(g, row + math.floor(x * OW / W) + 1) or 48) - 48
					end
				end
				return cells
			end
		end
	end
	for i = 1, W * H do cells[i] = (string.byte(g, i) or 48) - 48 end
	return cells
end

-- Merges same-coloured cells into as few rectangles as possible, so an animal is ~100 frames instead of 1120.
local function rects(cells, W, H) -- W, H: the grid being merged (the full grid, or a coarser copy)
	local out, used = {}, {}
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local i = y * W + x + 1
			local v = cells[i]
			if v ~= 0 and not used[i] then
				local w = 1
				while x + w < W and cells[i + w] == v and not used[i + w] do w += 1 end
				local h = 1
				while y + h < H do
					local ok = true
					for k = 0, w - 1 do
						local j = i + h * W + k
						if cells[j] ~= v or used[j] then ok = false break end
					end
					if not ok then break end
					h += 1
				end
				for dy = 0, h - 1 do for k = 0, w - 1 do used[i + dy * W + k] = true end end
				table.insert(out, { x, y, w, h, v })
			end
		end
	end
	return out
end

local function circle(parent, color, size, pos, z)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size, f.Position, f.BackgroundColor3, f.BorderSizePixel, f.ZIndex = size, pos, color, 0, z
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	f.Parent = parent
	return f
end

-- 12 eye styles; 1-6 are the originals, so saved animals keep their look.
-- [1], [2] pupil offset, [3] pupil size; hl = shine dot; lid / low = top / bottom eyelid (fraction covered);
-- sx = oval eye (width factor); ring = double ring; dot = a plain black dot with no white
local EYES = {
	{ 0, 0, 0.5, hl = true }, { 0.2, 0, 0.5 }, { -0.2, 0, 0.5 }, { 0, -0.2, 0.5 }, { 0, 0, 0.72, hl = true }, { 0, 0.1, 0.28 },
	{ 0, 0.14, 0.48, lid = 0.42 }, { -0.12, 0.1, 0.42, lid = 0.3, low = 0.22 }, { 0.05, -0.16, 0.5, sx = 0.7, hl = true },
	{ 0, 0, 0, dot = true }, { 0, 0, 0.36, ring = true }, { 0.24, 0.04, 0.46, sx = 0.78, hl = true },
}
local BLACK, WHITE, LID = Color3.new(0, 0, 0), Color3.new(1, 1, 1), Color3.fromRGB(170, 178, 192)
local MID = UDim2.fromScale(0.5, 0.5)

-- eyelid: a circle the size of the eye, cropped by a rectangle to the top (or bottom) h of it, with a black edge line
local function lid(white, h, bottom)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency, holder.ClipsDescendants, holder.ZIndex = 1, true, 11
	holder.Size = UDim2.fromScale(1, h)
	holder.Position = UDim2.fromScale(0, bottom and 1 - h or 0)
	holder.Parent = white
	circle(holder, LID, UDim2.fromScale(1, 1 / h), UDim2.fromScale(0.5, bottom and 1 - 0.5 / h or 0.5 / h), 11)
	local half = math.sqrt(math.max(0, 0.25 - (0.5 - h) ^ 2)) -- the circle's half-width at that height
	local line = Instance.new("Frame")
	line.BorderSizePixel, line.BackgroundColor3, line.ZIndex, line.AnchorPoint = 0, BLACK, 12, Vector2.new(0.5, 0.5)
	line.Size = UDim2.fromScale(half * 2, 0.07)
	line.Position = UDim2.fromScale(0.5, bottom and 1 - h or h)
	line.Parent = white
end

-- Draws eyes and stickers on top of a container that has the grid's aspect ratio
function Render.items(container, design)
	for _, e in design.e or {} do
		local s = Config.EYE_SIZES[e[4]] or Config.EYE_SIZES[1]
		local st = EYES[e[3]] or EYES[1]
		local sx = st.sx or 1
		local eye = circle(container, BLACK, UDim2.fromScale(s * H / W * sx, s), UDim2.fromScale(e[1], e[2]), 5)
		eye.Name = "Item"
		if st.dot then
			eye.Size = UDim2.fromScale(s * 0.62 * H / W, s * 0.62)
			circle(eye, WHITE, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.34, 0.32), 6)
		else
			local white = circle(eye, WHITE, UDim2.fromScale(0.82, 0.82), MID, 6)
			local host = white
			if st.ring then host = circle(circle(white, BLACK, UDim2.fromScale(0.74, 0.74), MID, 7), WHITE, UDim2.fromScale(0.78, 0.78), MID, 8) end
			local ps = st[3]
			local pupil = circle(host, BLACK, UDim2.fromScale(math.min(0.95, ps / sx), ps), UDim2.fromScale(0.5 + st[1], 0.5 + st[2]), 9) -- / sx keeps it round in an oval eye
			if st.hl then circle(pupil, WHITE, UDim2.fromScale(0.34, 0.34), UDim2.fromScale(0.32, 0.3), 10) end
			if st.lid then lid(white, st.lid, false) end
			if st.low then lid(white, st.low, true) end
		end
	end
	for _, s in design.s or {} do
		local size = Config.STICKER_SIZES[s[4]] or Config.STICKER_SIZES[1]
		local l = Instance.new("ImageLabel")
		l.Name = "Item"
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size, l.Position = UDim2.fromScale(size * H / W, size), UDim2.fromScale(s[1], s[2])
		l.BackgroundTransparency, l.ZIndex, l.ScaleType = 1, 8, Enum.ScaleType.Fit
		l.Image = Config.ICONS[Config.STICKERS[s[3]] or ""] or ""
		l.Parent = container
	end
end

-- Draws the whole design, centred inside `parent`. Returns the container.
-- step > 1 draws a coarser copy: each step x step block shows its first painted cell. Animals in the world and small
-- thumbnails don't need every pixel, and it keeps their frame count down on phones.
function Render.draw(parent, design, outline, step)
	local c = Instance.new("Frame")
	c.Name = "Drawing"
	c.AnchorPoint, c.Position, c.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	c.BackgroundTransparency = 1
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = W / H
	ar.Parent = c
	local cells = Render.decode(design.g)
	local w, h = W, H
	step = step or 1
	if step > 1 then
		local full = cells
		w, h = W // step, H // step
		cells = table.create(w * h, 0)
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local v = 0
				for dy = 0, step - 1 do
					local row = (y * step + dy) * W + x * step
					for dx = 1, step do
						v = full[row + dx]
						if v ~= 0 then break end
					end
					if v ~= 0 then break end
				end
				cells[y * w + x + 1] = v
			end
		end
	end
	local function put(list, z, fixed)
		for _, r in list do
			local f = Instance.new("Frame")
			f.BorderSizePixel, f.ZIndex = 0, z
			f.Position = UDim2.fromScale(r[1] / w, r[2] / h)
			f.Size = UDim2.new(r[3] / w, 1, r[4] / h, 1) -- +1px hides seams between neighbours
			f.BackgroundColor3 = fixed or Config.PALETTE[r[5]] or Config.PALETTE[1]
			f.Parent = c
		end
	end
	if outline then -- white rim 1/40 of the width thick (same on screen at any grid); a row pass then a column pass keeps it cheap
		local R = math.max(1, math.round(w / 40))
		local rows = table.create(w * h, 0)
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				for dx = -R, R do
					local nx = x + dx
					if nx >= 0 and nx < w and cells[y * w + nx + 1] ~= 0 then rows[y * w + x + 1] = 1 break end
				end
			end
		end
		local mask = table.create(w * h, 0)
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				for dy = -R, R do
					local ny = y + dy
					if ny >= 0 and ny < h and rows[ny * w + x + 1] == 1 then mask[y * w + x + 1] = 1 break end
				end
			end
		end
		put(rects(mask, w, h), 1, Color3.new(1, 1, 1))
	end
	put(rects(cells, w, h), 2)
	Render.items(c, design)
	c.Parent = parent
	return c
end

-- The Judge's Review: five 0..1 scores (Config.JUDGE order) read from the drawing itself, and 1-5 stars from their sum.
-- Runs on the server, so a better drawing really earns more.
function Render.judge(design)
	local cells = Render.decode(design.g)
	local filled, colours, edges, used = 0, 0, 0, {}
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local i = y * W + x + 1
			local v = cells[i]
			if v ~= 0 then
				filled += 1
				if not used[v] then used[v] = true colours += 1 end
				-- edges between two different colours = painted detail
				if x + 1 < W and cells[i + 1] ~= 0 and cells[i + 1] ~= v then edges += 1 end
				if y + 1 < H and cells[i + W] ~= 0 and cells[i + W] ~= v then edges += 1 end
			end
		end
	end
	-- the biggest connected blob: stray dots and scribbles make a drawing less neat
	local seen, biggest = {}, 0
	for i = 1, W * H do
		if cells[i] ~= 0 and not seen[i] then
			local stack, n = { i }, 0
			seen[i] = true
			while #stack > 0 do
				local j = table.remove(stack)
				n += 1
				local x, y = (j - 1) % W, (j - 1) // W
				for _, k in { x > 0 and j - 1, x < W - 1 and j + 1, y > 0 and j - W, y < H - 1 and j + W } do
					if k and cells[k] ~= 0 and not seen[k] then
						seen[k] = true
						table.insert(stack, k)
					end
				end
			end
			biggest = math.max(biggest, n)
		end
	end
	local eyes = 0
	for _, e in design.e or {} do
		local cx, cy = math.clamp(math.floor(e[1] * W), 0, W - 1), math.clamp(math.floor(e[2] * H), 0, H - 1)
		eyes += cells[cy * W + cx + 1] ~= 0 and 1 or 0.5 -- an eye floating off the body counts half
	end
	local scores = {
		math.min(1, filled / (W * H * 0.3)), -- size: about a third of the canvas is full marks
		math.clamp((colours - 1) / 3, 0, 1), -- colours: 4 or more
		math.min(1, edges / (W * 1.5) + #(design.s or {}) * 0.25), -- detail: painted patterns and stickers (edge counts grow with the grid width)
		math.min(1, eyes / 2), -- eyes: two on the body
		filled > 0 and (biggest / filled) ^ 2 or 0, -- neat: one solid animal
	}
	local sum = 0
	for _, s in scores do sum += s end
	return scores, math.clamp(math.floor(sum + 0.4), 1, 5) -- +0.4, not +0.5: an untouched template (2.5) is 2 stars, effort earns the 3rd
end

-- Server-side check of anything a client sends as a drawing. Returns a clean copy or nil.
function Render.sanitize(d)
	if typeof(d) ~= "table" or typeof(d.g) ~= "string" or #d.g > Config.MAX_DRAWING_CHARS or string.sub(d.g, 1, 1) ~= "~" then return nil end
	local cells = unpackRuns(d.g, W * H)
	if not cells then return nil end
	local filled = 0
	for _, v in cells do if v ~= 0 then filled += 1 end end
	if filled < Config.MIN_CELLS then return nil end
	local function list(src, max, kinds)
		local out = {}
		if typeof(src) ~= "table" then return out end
		for i = 1, math.min(#src, max) do
			local it = src[i]
			if typeof(it) ~= "table" then return nil end
			local x, y, k, s = it[1], it[2], it[3], it[4]
			if typeof(x) ~= "number" or typeof(y) ~= "number" or typeof(k) ~= "number" or typeof(s) ~= "number" then return nil end
			if x ~= x or y ~= y or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
			if k % 1 ~= 0 or k < 1 or k > kinds or s % 1 ~= 0 or s < 1 or s > 3 then return nil end
			out[i] = { x, y, k, s }
		end
		return out
	end
	local e, s = list(d.e, Config.MAX_EYES, Config.EYE_STYLES), list(d.s, Config.MAX_STICKERS, #Config.STICKERS)
	if not e or not s then return nil end
	-- eyes and stickers only count where they sit on the drawing itself; anything in the empty space is dropped
	local function onBody(items)
		local kept = {}
		for _, it in items do
			local cx, cy = math.clamp(math.floor(it[1] * W), 0, W - 1), math.clamp(math.floor(it[2] * H), 0, H - 1)
			if cells[cy * W + cx + 1] ~= 0 then table.insert(kept, it) end
		end
		return kept
	end
	e, s = onBody(e), onBody(s)
	local n = typeof(d.n) == "string" and d.n:sub(1, 20) or ""
	return { n = n, g = Render.encode(cells), e = e, s = s } -- re-encoded, so only clean runs are ever saved
end

return Render
