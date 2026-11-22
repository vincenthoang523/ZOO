--!nonstrict
-- ZooClient: HUD, windows, the draw editor, the intro cinematic and the walking animals. All UI is built here in code,
-- in the stud style: white studded sheets, thick black outlines, chunky lipped buttons and burning gradients.
-- Icons are FOLK icon pack images whose ids live in Config.ICONS.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")

local player = Players.LocalPlayer
local Zoo = ReplicatedStorage:WaitForChild("Zoo")
local Config = require(Zoo:WaitForChild("Config"))
local Render = require(Zoo:WaitForChild("Render"))
local Remotes = Zoo:WaitForChild("Remotes")
local World = workspace:WaitForChild("Zoo")

local rgb, U, S, O = Color3.fromRGB, UDim2.new, UDim2.fromScale, UDim2.fromOffset
local hex = Color3.fromHex
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local CENTER = Vector2.new(0.5, 0.5)
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
local FONT = Enum.Font.FredokaOne

-- burning colours only, as { top, bottom, lip }. Dark shades are for lips and outlines, never faces.
local P = {
	lime = { hex("8CFF00"), hex("12E600"), hex("00A81A") },
	green = { hex("A8FF00"), hex("2BE000"), hex("129E00") },
	blue = { hex("00BFFF"), hex("0062FF"), hex("003BB3") },
	cyan = { hex("3DF5FF"), hex("00B2F5"), hex("006FA8") },
	purple = { hex("CC00FF"), hex("8A00F0"), hex("5E00B0") },
	pink = { hex("FF2BD6"), hex("C800FF"), hex("6A00B8") },
	red = { hex("FF1F2A"), hex("D8000F"), hex("9E0008") },
	gold = { hex("FFE600"), hex("FF8A00"), hex("B85A00") },
	orange = { hex("FFB000"), hex("FF6A00"), hex("A33F00") },
	-- the one soft palette: upgrade and purchase buttons, a calm mint-to-green with no studs
	calm = { hex("9BEDB5"), hex("3DBE72"), hex("268A52") },
}
local C = { yellow = hex("FFE600"), cash = hex("6BFF3A"), red = hex("FF1F2A"), line = hex("D6D6D6"), canvas = rgb(44, 58, 88) } -- dark canvas: the grey base colour and pale paints stand out on it
local RARITY_PAL = { P.cyan, P.lime, P.blue, P.purple, P.gold, P.red } -- Common .. Mythic
local MUT_PAL = { -- Normal, Gold, Diamond, Rainbow, Matrix (Config.MUTATIONS order)
	{ hex("EEF2F8"), hex("9AA4B5"), hex("5C6575") }, P.gold, { hex("C9FDFF"), hex("2EC4FF"), hex("1677B3") },
	ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("FF2B2B")), ColorSequenceKeypoint.new(0.2, hex("FF9A00")), ColorSequenceKeypoint.new(0.4, hex("FFE600")),
		ColorSequenceKeypoint.new(0.6, hex("2BE000")), ColorSequenceKeypoint.new(0.8, hex("00BFFF")), ColorSequenceKeypoint.new(1, hex("CC00FF")) }),
	{ hex("8CFFAE"), hex("00C853"), hex("006B2B") },
}
local STUD = "rbxassetid://3014551673" -- 2 x 2 studs per tile
local ICON = Config.ICONS or {}

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then return string.format("%dh %dm", sec // 3600, sec % 3600 // 60) end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

----- stud UI kit -----
local function new(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
	return o
end
local function ink(o, t, col)
	return new("UIStroke", { Name = "Outline", Thickness = t or 4, Color = col or BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function grad(o, pal, rot)
	o.BackgroundColor3 = WHITE
	return new("UIGradient", { Rotation = rot or 90, Color = typeof(pal) == "ColorSequence" and pal or ColorSequence.new(pal[1], pal[2]) }, o)
end
local function studs(o, tr, tile, r)
	local s = new("ImageLabel", { Name = "Studs", BackgroundTransparency = 1, Image = STUD, ScaleType = Enum.ScaleType.Tile, TileSize = tile or O(48, 48),
		ImageTransparency = tr or 0.65, Size = S(1, 1) }, o)
	if r then round(s, r) end
	return s
end

-- Matrix mutation: a pulsing green aura round the animal; the drawing keeps its own colours (roll screen and zoo).
-- The white rim Render.draw puts round every drawing (its ZIndex 1 frames) turns green, and wider copies of it in two
-- CanvasGroups make the glow (a group fades as one, so overlapping copies don't stack into blotches). Each group is 1.25x
-- the drawing so the glow isn't cut off at the drawing's edge; its inner frame lines up with the drawing again.
local function matrixAura(drawing)
	local layers = {}
	for i, g in { { 6, 0.35 }, { 14, 0.7 } } do
		local cg = new("CanvasGroup", { Name = "Aura", BackgroundTransparency = 1, Position = S(-0.125, -0.125), Size = S(1.25, 1.25), ZIndex = 0, GroupTransparency = g[2] }, drawing)
		layers[i] = new("Frame", { BackgroundTransparency = 1, Position = S(0.1, 0.1), Size = S(0.8, 0.8) }, cg)
		TweenService:Create(cg, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { GroupTransparency = g[2] + 0.25 }):Play()
	end
	for _, o in drawing:GetChildren() do
		if o:IsA("Frame") and o.ZIndex == 1 then
			o.BackgroundColor3 = hex("8CFFAE")
			for i, g in { 6, 14 } do
				local f = o:Clone()
				f.BackgroundColor3, f.Position, f.Size = hex("3CFF6E"), o.Position - O(g, g), o.Size + O(2 * g, 2 * g)
				f.Parent = layers[i]
			end
		end
	end
end

-- idle life: rays spin, hero art floats, tags wiggle, best offers glint
local anim = {}
local function live(o, kind) table.insert(anim, { o = o, k = kind, base = kind == "float" and o.Position, rot = kind == "wiggle" and o.Rotation }) end
local reduced = false
pcall(function() reduced = GuiService.ReducedMotionEnabled end)
RunService.RenderStepped:Connect(function()
	if reduced then return end
	local t = os.clock()
	for i = #anim, 1, -1 do
		local a = anim[i]
		local o = a.o
		if not o.Parent then
			table.remove(anim, i)
		elseif a.k == "spin" then o.Rotation = (t * 22) % 360
		elseif a.k == "float" then o.Position = a.base + O(0, math.sin(t * 2 + i) * 4)
		elseif a.k == "wiggle" then o.Rotation = a.rot + math.sin(t * 3 + i) * 6
		elseif a.k == "glint" then o.Color = C.yellow:Lerp(WHITE, (math.sin(t * 5) + 1) / 2)
		end
	end
end)

-- every label: white Fredoka with a black 3.7 stroke and Bevel joins (Round closes O and 0, Miter throws spikes). 30px and up gets a hard drop.
local function label(parent, str, size, props, noDrop)
	local l = new("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = str, Font = FONT, TextSize = size, TextColor3 = WHITE, RichText = true,
		Size = U(1, 0, 0, math.ceil(size * 1.3)) }, parent)
	new("UIStroke", { Name = "UIStroke", Thickness = size >= 16 and 3.7 or 2.6, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	for k, v in props or {} do l[k] = v end
	if size >= 30 and not noDrop then
		local d = l:Clone()
		d.Name = l.Name .. "Drop"
		d.RichText = false
		d.Text = l.ContentText
		d.TextColor3 = BLACK
		d.Position = l.Position + O(0, 4)
		d.Parent = parent
		l.Parent = nil
		l.Parent = parent
		l:GetPropertyChangedSignal("Text"):Connect(function() d.Text = l.ContentText end)
		l:GetPropertyChangedSignal("Visible"):Connect(function() d.Visible = l.Visible end)
	end
	return l
end
local function goldText(l) new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("FFF35C"), hex("FFAA00")) }, l) end

-- flat art gets a black outline and a hard shadow, so it reads on vivid cards
local function sticker(parent, key, size, pos, float)
	local h = new("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = CENTER, Position = pos, Size = O(size, size) }, parent)
	local id = ICON[key]
	if not id or id == "" then -- no image id in Config.ICONS: leave the slot empty rather than fall back to an emoji
		warn("[Zoo] no icon uploaded for", key)
	else
		for _, d in { { 0, 6, 0.5 }, { -3, 0, 0 }, { 3, 0, 0 }, { 0, -3, 0 }, { 0, 3, 0 } } do
			new("ImageLabel", { Name = "Ink", BackgroundTransparency = 1, Image = id, ImageColor3 = BLACK, ImageTransparency = d[3], Position = O(d[1], d[2]),
				Size = S(1, 1), ScaleType = Enum.ScaleType.Fit }, h)
		end
		new("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = id, Size = S(1, 1), ScaleType = Enum.ScaleType.Fit }, h)
	end
	if float then live(h, "float") end
	return h
end
-- light rays drawn from frames: thin bars through the centre that fade out toward both ends (no image, so no asset permission to break)
local RAY_FADE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) })
local function rays(parent, size, pos, col)
	local r = new("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = CENTER, Position = pos, Size = O(size, size) }, parent)
	for i = 0, 7 do
		local bar = new("Frame", { AnchorPoint = CENTER, Position = S(0.5, 0.5), Size = U(1, 0, 0.13, 0), Rotation = i * 22.5, BackgroundColor3 = col or WHITE }, r)
		new("UIGradient", { Transparency = RAY_FADE }, bar)
	end
	live(r, "spin")
	return r
end
local function tag(parent, str, pos, col)
	local t = new("Frame", { Name = "Tag", AnchorPoint = CENTER, Position = pos, Size = O(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = col or C.red, Rotation = 8 }, parent)
	round(t, 8)
	ink(t, 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, t)
	label(t, str, 20, { Size = U(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X })
	live(t, "wiggle")
	return t
end
local function shadow(parent, size, pos, r)
	return round(new("Frame", { Name = "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, Size = size, Position = pos + O(0, 6) }, parent), r)
end

local BACK = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.07, Enum.EasingStyle.Quad)
-- pressable: black outline, dark lip, gradient face, studs. Centre anchored so hover and press grow from the middle.
-- opt: text, icon, iconSize, vertical, plain (no studs: the X and the calm buy buttons), vivid (keep lime bright), lip, r, name
local function button(parent, str, pal, size, pos, callback, opt)
	opt = opt or {}
	if pal == P.lime and not opt.vivid then pal, opt.plain = P.calm, true end -- every green action button is the calm buy style
	local r = opt.r or 12
	local b = new("TextButton", { Name = opt.name or "Button", Text = "", AutoButtonColor = false, AnchorPoint = CENTER, Position = pos, Size = size,
		BackgroundColor3 = pal[3] }, parent)
	round(b, r)
	ink(b, 4)
	local face = new("Frame", { Name = "Face", Size = U(1, 0, 1, -(opt.lip or 5)) }, b)
	round(face, r - 1)
	grad(face, pal)
	studs(face, 0.62, nil, r - 1).Visible = not opt.plain
	if opt.plain then b:SetAttribute("Plain", true) end
	local row = new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = S(1, 1) }, face)
	new("UIListLayout", { FillDirection = opt.vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, opt.vertical and -4 or 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local icon
	if opt.icon then
		local isz = opt.iconSize or 44
		local holder = new("Frame", { Name = "IconSlot", BackgroundTransparency = 1, Size = O(isz, isz), LayoutOrder = 1 }, row)
		icon = sticker(holder, opt.icon, isz, S(0.5, 0.5))
	end
	if str then
		local ts = opt.text or 26
		local l = label(row, str, ts, { Size = O(0, math.ceil(ts * 1.15)), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 }, true)
		if str:find("\n") then l.Size = O(0, math.ceil(ts * 2.2)) end
	end
	local pop = new("UIScale", { Name = "Pop" }, b)
	b.MouseEnter:Connect(function()
		TweenService:Create(pop, BACK, { Scale = 1.06 }):Play()
		if icon then TweenService:Create(icon, BACK, { Rotation = 8 }):Play() end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(pop, BACK, { Scale = 1 }):Play()
		if icon then TweenService:Create(icon, BACK, { Rotation = 0 }):Play() end
	end)
	b.MouseButton1Down:Connect(function() TweenService:Create(pop, QUICK, { Scale = 0.94 }):Play() end)
	b.MouseButton1Up:Connect(function() TweenService:Create(pop, BACK, { Scale = 1.06 }):Play() end)
	if callback then b.Activated:Connect(callback) end
	return b
end
local function setLabel(b, str)
	local l = b.Face.Row:FindFirstChild("Label")
	if l then l.Text = str end
end
local function paint(b, pal)
	-- green always means the calm buy style (no studs); any other colour brings the studs back unless the button was built plain
	if pal == P.lime then pal = P.calm end
	b.Face.Studs.Visible = pal ~= P.calm and not b:GetAttribute("Plain")
	b.BackgroundColor3 = pal[3]
	b.Face.UIGradient.Color = ColorSequence.new(pal[1], pal[2])
end
-- a finished button stays burning: flat lime, white text, no studs and no lip, so it no longer looks pressable
local function setDone(b, done, str)
	b.Face.Studs.Visible = not done and not b:GetAttribute("Plain")
	b.Face.Size = U(1, 0, 1, done and 0 or -5)
	b.Active = not done
	if done then paint(b, P.lime) end
	if str then setLabel(b, str) end
end
-- for grid layouts: the layout owns the holder, and the button inside keeps its centre anchor
local function cellButton(parent, str, pal, callback, opt, order)
	local holder = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order or 0 }, parent)
	return button(holder, str, pal, S(1, 1), S(0.5, 0.5), callback, opt)
end
-- a read-only vivid card: shadow, black outline, lip, gradient face with studs. Top-left positioned.
local function card(parent, pal, size, pos, r, rot)
	r = r or 14
	local sh = shadow(parent, size, pos, r)
	local f = round(new("Frame", { Name = "Card", Size = size, Position = pos, BackgroundColor3 = typeof(pal) == "table" and pal[3] or BLACK }, parent), r)
	ink(f, 4)
	local face = round(new("Frame", { Name = "Face", Size = U(1, 0, 1, -6) }, f), r - 1)
	grad(face, pal, rot)
	studs(face, 0.74, nil, r - 1)
	return f, face, sh
end
local WELL = hex("1C2850") -- the recessed dim navy inside every window, so vivid cards pop forward
local function sheetPanel(parent, size, pos)
	local f = round(new("Frame", { Size = size, Position = pos, BackgroundColor3 = hex("2B3B70") }, parent), 14)
	ink(f, 4)
	studs(f, 0.86, O(50, 46), 13)
	return f
end
-- drawings sit on a dark display box: the grey base colour and pale paints vanish on light faces
local DISPLAY = hex("1E2840")
local function display(parent, size, pos, r)
	local f = round(new("Frame", { Name = "Display", Size = size, Position = pos, BackgroundColor3 = DISPLAY }, parent), r or 10)
	ink(f, 3)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, f)
	return f
end
local function heading(parent, str, y, w)
	label(parent, str, 30, { Position = O(0, y), Size = O(w, 40) })
	new("Frame", { Name = "Line", BackgroundColor3 = C.line, Size = O(w, 3), Position = O(0, y + 44) }, parent)
	return y + 58
end

local gui = new("ScreenGui", { Name = "ZooGui", ResetOnSpawn = false, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
pcall(game:GetService("StarterGui").SetCoreGuiEnabled, game:GetService("StarterGui"), Enum.CoreGuiType.PlayerList, false) -- the Roblox player list sits over the DAILY button and eats its clicks; the Top Earners board replaces it

-- Everything is laid out for a 1280x720 screen and scaled to fit, so phones, tablets and PCs get the same layout.
local scales = {}
local function scaled(o)
	table.insert(scales, new("UIScale", { Name = "Fit" }, o))
	return o
end
local function rescale()
	local vp = gui.AbsoluteSize -- the area under the top bar, not the whole camera, so tall windows never run off the bottom
	local k = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.35, 1.6)
	for _, s in scales do s.Scale = k end
end

local toasts = scaled(new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = U(0.5, 0, 0, 4), Size = O(900, 200), BackgroundTransparency = 1, ZIndex = 40 }, gui))
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }, toasts)
local function toast(str, color)
	local l = label(toasts, str, 30, { TextColor3 = color or WHITE }, true)
	task.delay(3.5, function() l:Destroy() end)
end
Remotes.Notify.OnClientEvent:Connect(toast)

----- windows: a white studded sheet, title letters centred on the top border, icon over the corner, X overhanging -----
local blur = Lighting:FindFirstChild("ZooBlur") or new("BlurEffect", { Name = "ZooBlur", Size = 0 }, Lighting)
-- dims the world and HUD behind an open window; pushed up over the top-bar inset so the whole screen darkens
local dim = new("Frame", { Name = "Dim", BackgroundColor3 = BLACK, BackgroundTransparency = 1, Position = O(0, -80), Size = U(1, 0, 1, 80), ZIndex = 9, Visible = false }, gui)
local windows, refreshers = {}, {}
local current
local hideWhileOpen = {} -- the side rails, so a window never sits on top of them
local function setOpen(name, on)
	local w = windows[name]
	if on then
		w.root.Visible = true
		w.pop.Scale = 0.8
		TweenService:Create(w.pop, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if refreshers[name] then refreshers[name]() end
	else
		local tw = TweenService:Create(w.pop, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.8 })
		tw.Completed:Once(function() if current ~= name then w.root.Visible = false end end) -- reopening during the close wins
		tw:Play()
	end
end
local function open(name)
	local was = current
	if was then setOpen(was, false) end
	current = was ~= name and name or nil
	if current then setOpen(current, true) end
	for _, f in hideWhileOpen do f.Visible = current == nil end
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = current and 14 or 0 }):Play()
	if current then dim.Visible = true end
	local fade = TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = current and 0.45 or 1 })
	fade.Completed:Once(function() if not current then dim.Visible = false end end)
	fade:Play()
end
local function close(name)
	if current == name then open(name) end
end
local function window(name, title, iconKey, w, h, rim) -- rim: { top, middle, bottom } colours of the frame (default blue)
	rim = rim or { hex("5CE6FF"), hex("0A86F0"), hex("0743B0") }
	local root = scaled(new("Frame", { Name = name, AnchorPoint = CENTER, Position = S(0.5, 0.53), Size = O(w, h), BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, gui))
	local stage = new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = S(1, 1) }, root)
	local pop = new("UIScale", { Name = "Pop" }, stage) -- separate from the fit scale, so a resize mid-pop can't leave a wrong size
	new("TextButton", { Size = S(1, 1), BackgroundTransparency = 1, Text = "" }, stage) -- swallows clicks so the camera doesn't move behind the window
	round(new("Frame", { Name = "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, Size = U(1, 4, 1, 4), Position = O(-2, 6) }, stage), 18)
	-- rim: bright blue frame whose top is a header band (gloss strip, shine streaks, faint paws); the content sits in a dark recessed well
	local sheet = round(new("Frame", { Name = "Sheet", Size = S(1, 1), BackgroundColor3 = WHITE }, stage), 16)
	ink(sheet, 5)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rim[1]), ColorSequenceKeypoint.new(55 / h, rim[2]),
		ColorSequenceKeypoint.new(1, rim[3]) }) }, sheet)
	studs(sheet, 0.72, O(50, 46), 15)
	round(new("Frame", { Name = "Gloss", BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, Position = O(18, 5), Size = U(1, -36, 0, 7) }, sheet), 4)
	for i, x in { 250, 228 } do
		new("Frame", { Name = "Shine", BackgroundColor3 = WHITE, BackgroundTransparency = 0.7 + i * 0.05, AnchorPoint = CENTER, Position = O(w - x, 23), Size = O(i == 1 and 12 or 6, 40), Rotation = 24 }, sheet)
	end
	if ICON.paw then
		for _, p in { { 120, 22, 30, -18 }, { 172, 30, 22, 14 }, { 204, 14, 18, -6 }, { 300, 24, 24, 10 } } do
			new("ImageLabel", { Name = "Paw", BackgroundTransparency = 1, Image = ICON.paw, ImageColor3 = WHITE, ImageTransparency = 0.78, AnchorPoint = CENTER,
				Position = O(w - p[1], p[2]), Size = O(p[3], p[3]), Rotation = p[4] }, sheet)
		end
	end
	local well = round(new("Frame", { Name = "Well", BackgroundColor3 = WELL, Position = O(8, 44), Size = U(1, -16, 1, -52) }, sheet), 12)
	ink(well, 3)
	studs(well, 0.9, O(50, 46), 12)
	local inner = round(new("Frame", { Name = "InnerShadow", BackgroundColor3 = BLACK, Size = U(1, 0, 0, 22) }, well), 12)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.45, 1) }, inner)
	sticker(stage, iconKey, 86, O(28, -2))
	label(stage, title, 48, { Name = "Title", Size = O(0, 60), AutomaticSize = Enum.AutomaticSize.X, Position = O(76, -32), TextXAlignment = LEFT })
	button(stage, "X", P.red, O(64, 68), O(w - 20, -4), function() close(name) end, { plain = true, text = 44, name = "Close" })
	local body = new("Frame", { Name = "Body", Size = U(1, -40, 1, -66), Position = O(20, 46), BackgroundTransparency = 1, ZIndex = 2 }, sheet)
	windows[name] = { root = root, pop = pop }
	return body, stage
end

local state = { luckLevel = 0, capLevel = 0, capacity = Config.CAP_START, animals = {}, dailyDay = 0, dailyWait = 0, boostLeft = 0, passes = {}, freeClaimed = false }
local stateAt = os.clock()
local showOffline, pendingOffline, introDone
Remotes.State.OnClientEvent:Connect(function(s)
	state, stateAt = s, os.clock()
	if current and refreshers[current] then refreshers[current]() end
	if s.offline then
		pendingOffline = s.offline
		if introDone then showOffline(s.offline) end
	end
end)

----- buying -----
local function buy(kind, key)
	local id = (kind == "pass" and Config.PASSES or Config.PRODUCTS)[key]
	if not id or id == 0 then return toast("Coming soon!") end
	if kind == "pass" then MarketplaceService:PromptGamePassPurchase(player, id) else MarketplaceService:PromptProductPurchase(player, id) end
end
local passButtons = {}
local function priceButton(parent, kind, key, size, pos, ts, prefix)
	local b
	b = button(parent, "...", P.calm, size, pos, function()
		if kind == "pass" and state.passes[key] then return end
		buy(kind, key)
	end, { icon = "robux", iconSize = math.floor(size.Y.Offset * 0.6), text = ts or 30, plain = true })
	if prefix then
		label(b.Face.Row, prefix, ts or 30, { Size = O(0, math.ceil((ts or 30) * 1.15)), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 0, Name = "Prefix" }, true)
	end
	local id = (kind == "pass" and Config.PASSES or Config.PRODUCTS)[key]
	if id and id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
			setLabel(b, ok and info and info.PriceInRobux and tostring(info.PriceInRobux) or "BUY")
		end)
	else
		setLabel(b, "SOON")
	end
	if kind == "pass" then
		passButtons[key] = passButtons[key] or {}
		table.insert(passButtons[key], b)
	end
	return b
end

----- HUD -----
local hud = new("Frame", { Name = "HUD", Size = S(1, 1), BackgroundTransparency = 1 }, gui)

-- bottom left: luck, cash and income as big stroked text, no panel
local stats = scaled(new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = U(0, 12, 1, -8), Size = O(440, 156), BackgroundTransparency = 1 }, hud))
sticker(stats, "clover", 50, O(30, 26))
local luckLabel = label(stats, "1x", 38, { Size = O(0, 48), AutomaticSize = Enum.AutomaticSize.X, Position = O(62, 2), TextXAlignment = LEFT })
goldText(luckLabel)
sticker(stats, "cash", 68, O(36, 86))
local cashLabel = label(stats, "$0", 56, { Size = O(0, 70), AutomaticSize = Enum.AutomaticSize.X, Position = O(76, 50), TextXAlignment = LEFT, TextColor3 = C.cash })
local rateLabel = label(stats, "+$0/s", 28, { Size = O(0, 36), AutomaticSize = Enum.AutomaticSize.X, Position = O(10, 120), TextXAlignment = LEFT })

-- side menus: two mirrored columns at the same height, same button size and gap, so their rows line up across the screen
local RAIL_W, RAIL_H, RAIL_GAP = 186, 56, 12
local RAIL_SIZE = O(RAIL_W + 8, 4 * RAIL_H + 3 * RAIL_GAP + 8)
local function rail(anchorX, posX)
	return scaled(new("Frame", { AnchorPoint = Vector2.new(anchorX, 0.5), Position = U(anchorX, posX, 0.46, 0), Size = RAIL_SIZE, BackgroundTransparency = 1 }, hud))
end
local function railButton(bar, i, str, pal, callback, opt)
	return button(bar, str, pal, O(RAIL_W, RAIL_H), O(RAIL_W / 2 + 4, 4 + RAIL_H / 2 + (i - 1) * (RAIL_H + RAIL_GAP)), callback, opt)
end

-- left: shop, upgrades, my zoo, free
local leftBar = rail(0, 14)
local railButtons = {}
for i, b in { { "SHOP", P.lime, "shop", "Shop" }, { "UPGRADES", P.blue, "upgrade", "Upgrades" }, { "MY ZOO", P.pink, "paw", "Inventory" }, { "FREE", P.orange, "luck", "Free" } } do
	railButtons[b[4]] = railButton(leftBar, i, b[1], b[2], function() open(b[4]) end, { icon = b[3], iconSize = 44, text = 26, name = b[4], vivid = true })
end
tag(railButtons.Free, "2x", O(30, RAIL_H - 6), P.purple[2])
local upgradeAlert = tag(railButtons.Upgrades, "!", O(RAIL_W, 6))
upgradeAlert.Visible = false

-- right: daily, boost, draw, starter pack
local rightBar = rail(1, -14)
local dailyBtn = railButton(rightBar, 1, "DAILY", P.cyan, function() open("Daily") end, { icon = "calendar", iconSize = 44, text = 26 })
local dailyAlert = tag(dailyBtn, "!", O(RAIL_W - 4, 4))
dailyAlert.Visible = false
local boostBtn = railButton(rightBar, 2, "BOOST", P.purple, function() open("Boost") end, { icon = "bolt", iconSize = 44, text = 26 })
tag(boostBtn, "2x", O(28, RAIL_H - 6), P.lime[3])
-- the boost countdown sits beside its button, so it doesn't open a gap in the column
local boostTimer = label(boostBtn, "", 22, { AnchorPoint = Vector2.new(1, 0.5), Position = U(0, -8, 0.5, 0), Size = O(110, 28), TextXAlignment = RIGHT, TextColor3 = C.yellow })
railButton(rightBar, 3, "DRAW AN\nANIMAL", P.gold, function() open("Editor") end, { icon = "pencil", iconSize = 46, text = 20 })
local starterBtn = railButton(rightBar, 4, "STARTER\nPACK", P.blue, function() open("Starter") end, { icon = "chest", iconSize = 46, text = 20 })
live(starterBtn.Face.Row.IconSlot.Icon, "float")
hideWhileOpen = { leftBar, rightBar }

local function upgradeReady(cash)
	return (state.luckLevel < Config.MAX_LUCK_LEVEL and cash >= Config.luckCost(state.luckLevel))
		or (state.capacity < Config.CAP_MAX and cash >= Config.capCost(state.capLevel))
end
-- the cash readout counts toward the real value instead of jumping: it closes most of the gap within ~0.4 s
local shownCash, cashTarget = nil, 0
RunService.RenderStepped:Connect(function(dt)
	if not shownCash or shownCash == cashTarget then return end
	local gap = cashTarget - shownCash
	shownCash = if math.abs(gap) < 1 then cashTarget else shownCash + gap * math.min(1, dt * 8)
	cashLabel.Text = "$" .. Config.format(shownCash)
end)
local function refreshCash()
	local cash = player:GetAttribute("Cash") or 0
	cashTarget = cash
	if not shownCash then
		shownCash = cash
		cashLabel.Text = "$" .. Config.format(cash)
	end
	rateLabel.Text = "+$" .. Config.format(player:GetAttribute("Rate") or 0) .. "/s"
	luckLabel.Text = (player:GetAttribute("Luck") or 1) .. "x"
	upgradeAlert.Visible = upgradeReady(cash)
end
for _, a in { "Cash", "Rate", "Luck" } do player:GetAttributeChangedSignal(a):Connect(refreshCash) end
refreshCash()

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "DrawPrompt" then open("Editor") elseif prompt.Name == "UpgradePrompt" then open("Upgrades") elseif prompt.Name == "SellPrompt" then open("Sell") elseif prompt.Name == "RacePrompt" then open("Race") end
end)

----- Odds -----
do
	local body = window("Odds", "Odds", "rainbowclover", 560, 500)
	local head = label(body, "", 24, { Position = O(0, 0), Size = O(520, 32) })
	local rows = {}
	for i, info in Config.RARITIES do
		local f, face = card(body, RARITY_PAL[i], O(520, 56), O(0, 40 + (i - 1) * 64), 12)
		label(face, info.name:upper(), 24, { Position = O(16, 0), Size = U(0, 220, 1, 0), TextXAlignment = LEFT })
		rows[i] = label(face, "", 24, { Position = O(220, 0), Size = U(0, 150, 1, 0), TextColor3 = C.yellow })
		label(face, "$" .. Config.format(info.rate) .. "/s", 22, { Position = O(370, 0), Size = U(0, 136, 1, 0), TextXAlignment = RIGHT, TextColor3 = C.cash })
		f.Name = info.name
	end
	refreshers.Odds = function()
		local luck = player:GetAttribute("Luck") or 1
		head.Text = "Your odds for each drawing at <font color=\"#FFE600\">" .. luck .. "x</font> luck"
		for i, p in Config.chances(luck) do
			local pct = p * 100
			rows[i].Text = (pct >= 1 and string.format("%.1f", pct) or string.format("%.3f", pct)) .. "%"
		end
	end
end

----- Upgrades -----
do
	local body = window("Upgrades", "Upgrades", "upgrade", 800, 520)
	local function chips(face, count, text)
		local list = {}
		for i = 1, count do
			local c = round(new("Frame", { Size = O(58, 32), Position = O(16 + (i - 1) * 64, 150) }, face), 8)
			grad(c, P.blue)
			ink(c, 3)
			label(c, text(i), 18, { Size = S(1, 1) })
			list[i] = c
		end
		return list
	end
	local function paintChips(list, at)
		for i, c in list do
			c.UIGradient.Color = ColorSequence.new(table.unpack(i < at and { P.lime[1], P.lime[2] } or i == at and { P.cyan[1], P.cyan[2] } or i == at + 1 and { P.gold[1], P.gold[2] } or { P.blue[1], P.blue[2] }))
			c.Outline.Color = i == at and WHITE or BLACK
			c.Outline.Thickness = i == at and 4 or 3
		end
	end
	local function row(y, pal, icon, title, sub, kind)
		local _, face = card(body, pal, O(760, 204), O(0, y))
		rays(face, 210, O(84, 78), WHITE)
		sticker(face, icon, 116, O(84, 78), true)
		label(face, title, 40, { Position = O(164, 6), Size = O(300, 50), TextXAlignment = LEFT })
		label(face, sub, 20, { Position = O(166, 52), Size = O(300, 26), TextXAlignment = LEFT, TextColor3 = C.yellow })
		local level = label(face, "", 40, { Position = O(164, 78), Size = O(320, 52), TextXAlignment = LEFT })
		local cost = label(face, "", 24, { Position = O(540, 10), Size = O(200, 30), TextColor3 = C.cash })
		local btn = button(face, "UPGRADE", P.calm, O(200, 66), O(640, 82), function() Remotes.Upgrade:FireServer(kind) end, { text = 32, plain = true })
		return level, cost, btn
	end
	local luckLevel, luckCost, luckBtn = row(0, P.green, "clover", "Luck", "Draw rarer animals", "luck")
	local luckChips = chips(luckBtn.Parent, Config.MAX_LUCK_LEVEL + 1, function(i) return 2 ^ (i - 1) .. "x" end)
	local capLevel, capCost, capBtn = row(222, P.orange, "house", "Enclosure Size", "More room in your pen", "cap")
	local capChips = chips(capBtn.Parent, Config.CAP_MAX - Config.CAP_START + 1, function(i) return tostring(Config.CAP_START + i - 1) end)
	button(luckBtn.Parent, "ODDS", P.blue, O(100, 52), O(486, 84), function() open("Odds") end, { text = 24 })
	refreshers.Upgrades = function()
		local l = state.luckLevel
		local maxed = l >= Config.MAX_LUCK_LEVEL
		luckLevel.Text = maxed and ("MAX  " .. 2 ^ l .. "x") or (2 ^ l .. "x  →  <font color=\"#FFE600\">" .. 2 ^ (l + 1) .. "x</font>")
		luckCost.Text = maxed and "" or "$" .. Config.format(Config.luckCost(l))
		if maxed then setDone(luckBtn, true, "MAXED") end
		paintChips(luckChips, l + 1)
		maxed = state.capacity >= Config.CAP_MAX
		capLevel.Text = maxed and ("MAX  " .. state.capacity) or (state.capacity .. "  →  <font color=\"#FFE600\">" .. state.capacity + 1 .. "</font>")
		capCost.Text = maxed and "" or "$" .. Config.format(Config.capCost(state.capLevel))
		if maxed then setDone(capBtn, true, "MAXED") end
		paintChips(capChips, state.capacity - Config.CAP_START + 1)
	end
end

----- Shop: passes and boosts scroll, side tabs jump to each section -----
do
	local W, H = 900, 580
	local body, stage = window("Shop", "Shop", "shop", W, H)
	local scroll = new("ScrollingFrame", { Size = S(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("9A9A9A"),
		TopImage = "", BottomImage = "", BorderSizePixel = 0, CanvasSize = U(), ScrollingDirection = Enum.ScrollingDirection.Y }, body)
	local c = new("Frame", { BackgroundTransparency = 1, Size = O(840, 10), Position = O(0, 4) }, scroll)
	local cw = 836
	local sections = {}
	local y = 0
	sections[1] = y
	y = heading(c, "PASSES", y, cw)

	-- VIP hero
	local _, vip = card(c, { hex("8A00F0"), hex("FF7A00"), hex("5E00B0") }, O(cw, 184), O(0, y), 16, 0)
	rays(vip, 250, O(112, 88), C.yellow)
	sticker(vip, "crown", 156, O(112, 88), true)
	local vt = label(vip, "VIP", 56, { Position = O(226, 8), Size = O(200, 66), TextXAlignment = LEFT })
	goldText(vt)
	label(vip, "<font color=\"#6BFF3A\">+20%</font> money", 34, { Position = O(228, 72), Size = O(360, 44), TextXAlignment = LEFT })
	label(vip, "From every animal in your zoo, forever!", 20, { Position = O(230, 118), Size = O(360, 28), TextXAlignment = LEFT })
	tag(vip, "BEST!", O(cw - 40, 10))
	priceButton(vip, "pass", "VIP", O(230, 74), O(690, 92), 34)
	y += 200

	local _, money = card(c, P.gold, O(410, 214), O(0, y))
	rays(money, 180, O(88, 74), WHITE)
	sticker(money, "cash", 124, O(88, 74), true)
	label(money, "x2", 30, { Position = O(118, 96), Size = O(60, 40), Rotation = -10 })
	label(money, "x2 Money", 36, { Position = O(170, 10), Size = O(230, 46) })
	label(money, "Every animal earns\n<font color=\"#6BFF3A\">x2</font> money!", 20, { Position = O(170, 62), Size = O(230, 56) })
	priceButton(money, "pass", "Money2x", O(380, 60), O(205, 168), 30)

	local _, luck = card(c, P.cyan, O(410, 214), O(426, y))
	rays(luck, 180, O(88, 74), WHITE)
	sticker(luck, "luck", 124, O(88, 74), true)
	label(luck, "x2 Luck", 36, { Position = O(170, 10), Size = O(230, 46) })
	label(luck, "<font color=\"#6BFF3A\">x2</font> luck on top\nof your upgrades!", 20, { Position = O(170, 62), Size = O(230, 56) })
	button(luck, "ODDS", P.blue, O(110, 60), O(75, 168), function() open("Odds") end, { text = 24 })
	priceButton(luck, "pass", "Luck2x", O(256, 60), O(270, 168), 30)
	y += 232

	sections[2] = y
	y = heading(c, "BOOSTS", y, cw)
	local _, boost = card(c, P.green, O(cw, 160), O(0, y))
	rays(boost, 210, O(96, 76), WHITE)
	sticker(boost, "luck", 120, O(96, 76), true)
	label(boost, "2x Luck Boost", 38, { Position = O(190, 18), Size = O(380, 48), TextXAlignment = LEFT })
	label(boost, Config.LUCK_BOOST_MINUTES .. " minutes of 2x luck. Buy more to stack the time!", 20, { Position = O(192, 74), Size = O(380, 52), TextXAlignment = LEFT, TextWrapped = true })
	priceButton(boost, "product", "LuckBoost", O(230, 70), O(690, 76), 32)
	y += 176

	sections[3] = y
	y = heading(c, "BUNDLES", y, cw)
	local _, pack = card(c, { hex("FF2BD6"), hex("FF8A00"), hex("A33F00") }, O(cw, 160), O(0, y), 14, 0)
	rays(pack, 210, O(96, 76), C.yellow)
	sticker(pack, "chest", 124, O(96, 76), true)
	label(pack, "Starter Pack", 38, { Position = O(190, 18), Size = O(380, 48), TextXAlignment = LEFT })
	label(pack, "$" .. Config.format(Config.STARTER_PACK.cash) .. " cash + " .. Config.STARTER_PACK.luckMin .. " min of 2x luck", 20, { Position = O(192, 74), Size = O(380, 30), TextXAlignment = LEFT })
	priceButton(pack, "product", "StarterPack", O(230, 70), O(690, 76), 32)
	y += 176

	c.Size = O(cw, y)
	scroll.CanvasSize = O(0, y + 12)

	local tabs = {}
	local function select(i)
		for k, t in tabs do
			t.Outline.Color = k == i and WHITE or BLACK
			t.Outline.Thickness = k == i and 5 or 4
		end
	end
	local jumping = false
	for i, t in { { "PASSES", "crown", P.orange }, { "BOOSTS", "bolt", P.purple }, { "BUNDLES", "chest", P.blue } } do
		tabs[i] = button(stage, t[1], t[3], O(136, 84), O(W + 84, 74 + (i - 1) * 96), function()
			jumping = true
			select(i)
			local goal = math.min(sections[i], math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y))
			local tw = TweenService:Create(scroll, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, goal) })
			tw.Completed:Once(function() jumping = false end)
			tw:Play()
		end, { icon = t[2], iconSize = 48, text = 20, vertical = true })
	end
	select(1)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if jumping then return end
		local yy, best = scroll.CanvasPosition.Y, 1
		for i, sy in sections do if sy <= yy + 60 then best = i end end
		if yy >= scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y - 4 then best = #sections end -- the last heading may never reach the top
		select(best)
	end)
	refreshers.Shop = function()
		for key, list in passButtons do
			for _, b in list do
				if state.passes[key] then setDone(b, true, "OWNED") end
			end
		end
	end
end

----- My Zoo: enclosure slots on top, your animals below, the selected one on the right -----
do
	local body = window("Inventory", "My Zoo", "paw", 900, 600)
	local info = label(body, "", 24, { Position = O(0, 0), Size = O(860, 30), TextXAlignment = LEFT })
	local slots = new("Frame", { BackgroundTransparency = 1, Position = O(0, 38), Size = O(860, 70) }, body)
	local count = label(body, "", 28, { Position = O(0, 116), Size = O(400, 36), TextXAlignment = LEFT, TextColor3 = C.yellow })
	goldText(count)
	button(body, "EQUIP BEST", P.lime, O(190, 50), O(486, 134), function() Remotes.EquipBest:FireServer() end, { text = 24 })
	local list = new("ScrollingFrame", { Position = O(0, 168), Size = O(598, 360), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("9A9A9A"),
		TopImage = "", BottomImage = "", BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = U() }, body)
	new("UIGridLayout", { CellSize = O(138, 150), CellPadding = O(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }, list)
	local empty = new("Frame", { BackgroundTransparency = 1, Position = O(0, 200), Size = O(598, 200), Visible = false }, body)
	label(empty, "No animals yet!", 34, { Position = O(0, 20), Size = O(598, 44) })
	button(empty, "DRAW ONE", P.gold, O(240, 70), O(299, 120), function() open("Editor") end, { icon = "pencil", iconSize = 50, text = 30 })

	-- the selected animal's card
	local panel, pface, pshadow = card(body, P.cyan, O(250, 412), O(610, 116), 16)
	local pRarity = label(pface, "", 22, { Position = O(0, 8), Size = O(250, 28) })
	local pName = label(pface, "", 30, { Position = O(0, 34), Size = O(250, 40) }, true)
	local thumb = round(new("Frame", { Position = O(15, 84), Size = O(220, 154), BackgroundColor3 = DISPLAY }, pface), 12)
	ink(thumb, 4)
	local pRate = label(pface, "", 26, { Position = O(0, 246), Size = O(250, 34), TextColor3 = C.cash })
	local selected
	local equipBtn = button(pface, "EQUIP", P.lime, O(220, 60), O(125, 306), function()
		if selected then Remotes.Equip:FireServer(selected) end
	end, { text = 30 })
	local releaseBtn
	releaseBtn = button(pface, "RELEASE", P.red, O(220, 50), O(125, 366), function()
		if not selected then return end
		if releaseBtn:GetAttribute("Sure") then
			Remotes.Release:FireServer(selected)
			selected = nil
		else
			releaseBtn:SetAttribute("Sure", true)
			setLabel(releaseBtn, "SURE?")
		end
	end, { icon = "trash", iconSize = 34, text = 24 })

	local function find(id)
		for _, a in state.animals do if a.id == id then return a end end
		return nil
	end
	local function showSelected()
		local a = selected and find(selected)
		panel.Visible = a ~= nil
		pshadow.Visible = a ~= nil
		if not a then return end
		local r = Config.RARITIES[a.r]
		local pal = RARITY_PAL[a.r]
		panel.BackgroundColor3 = pal[3]
		pface.UIGradient.Color = ColorSequence.new(pal[1], pal[2])
		local m = Config.MUTATIONS[a.m or 1]
		pRarity.Text = (a.m or 1) > 1 and string.format('<font color="#%s">%s</font> %s', m.color:ToHex(), m.name:upper(), r.name:upper()) or r.name:upper()
		pName.Text = a.d.n
		pRate.Text = "+$" .. Config.format(Config.income(a)) .. "/s"
		thumb:ClearAllChildren()
		round(thumb, 12)
		ink(thumb, 4)
		Render.draw(thumb, a.d, true, 3)
		setLabel(equipBtn, a.eq and "UNEQUIP" or "EQUIP")
		paint(equipBtn, a.eq and P.red or P.lime)
		releaseBtn:SetAttribute("Sure", nil)
		setLabel(releaseBtn, "RELEASE")
	end
	refreshers.Inventory = function()
		for _, ch in list:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
		for _, ch in slots:GetChildren() do ch:Destroy() end
		local active, rate = 0, 0
		local eq = {}
		for _, a in state.animals do
			if a.eq then
				active += 1
				rate += Config.income(a)
				table.insert(eq, a)
			end
		end
		table.sort(eq, function(x, z) return Config.income(x) > Config.income(z) end)
		if selected and not find(selected) then selected = nil end
		if not selected and state.animals[1] then selected = state.animals[1].id end
		-- one slot per possible enclosure spot: animals, open spots, then spots that need the Enclosure Size upgrade
		for i = 1, Config.CAP_MAX do
			local a = eq[i]
			local unlocked = i <= state.capacity
			local f = round(new("Frame", { Position = O((i - 1) * 71 + 2, 2), Size = O(64, 64) }, slots), 10)
			ink(f, 3)
			if a then
				f.BackgroundColor3 = DISPLAY -- dark so the drawing reads; the outline carries the rarity colour
				f.Outline.Color = Config.RARITIES[a.r].color
				local t = new("Frame", { BackgroundTransparency = 1, Position = O(4, 10), Size = O(56, 40) }, f)
				Render.draw(t, a.d, true, 3)
			elseif unlocked then
				f.BackgroundColor3 = WHITE
				studs(f, 0.7, nil, 9)
				label(f, "+", 34, { Size = S(1, 1), TextColor3 = C.cash }, true)
			else
				grad(f, P.blue)
				sticker(f, "lock", 40, S(0.5, 0.5))
			end
		end
		for i, a in state.animals do
			local r = Config.RARITIES[a.r]
			local b = cellButton(list, nil, RARITY_PAL[a.r], function()
				selected = a.id
				refreshers.Inventory()
			end, { lip = 5 }, (a.eq and 0 or 1000) - a.r * 100 + i)
			Render.draw(display(b.Face, O(120, 84), O(9, 8)), a.d, true, 3)
			label(b.Face, a.d.n, 20, { Position = O(0, 96), Size = O(138, 24) })
			label(b.Face, "$" .. Config.format(Config.income(a)) .. "/s", 16, { Position = O(0, 120), Size = O(138, 20), TextColor3 = C.yellow })
			if (a.m or 1) > 1 then -- mutation tag in the corner
				local mt = round(new("Frame", { Position = O(-6, -8), Size = O(0, 24), AutomaticSize = Enum.AutomaticSize.X }, b), 8)
				grad(mt, MUT_PAL[a.m], typeof(MUT_PAL[a.m]) == "ColorSequence" and 0 or nil)
				ink(mt, 3)
				new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, mt)
				label(mt, Config.MUTATIONS[a.m].name:upper(), 15, { Size = U(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X })
			end
			if a.eq then
				local e = round(new("Frame", { Position = O(104, -8), Size = O(40, 28) }, b), 8)
				grad(e, P.lime)
				ink(e, 3)
				label(e, "E", 20, { Size = S(1, 1) })
			end
			if a.id == selected then
				b.Outline.Color = C.yellow -- gold: white would vanish against the sheet
				b.Outline.Thickness = 6
			end
		end
		empty.Visible = #state.animals == 0
		info.Text = string.format("Enclosure <font color=\"#FFE600\">%d/%d</font>   ·   Earning <font color=\"#6BFF3A\">+$%s/s</font>", active, state.capacity, Config.format(rate))
		count.Text = string.format("YOUR ANIMALS  %d/%d", #state.animals, Config.MAX_INVENTORY)
		showSelected()
	end
end

----- Daily rewards -----
local dailyClaimable = false
do
	local body = window("Daily", "Daily Rewards", "calendar", 960, 560)
	local colors = { P.cyan, P.cyan, P.cyan, P.pink, P.pink, P.gold }
	local cards = {}
	local function rewardBits(reward)
		if reward.cash and reward.luckMin then return "giftpurple", "$" .. Config.format(reward.cash), "+ " .. reward.luckMin .. " MIN 2x LUCK" end
		if reward.cash then return reward.cash >= 15000 and "cashbundle" or "cash", "+$" .. Config.format(reward.cash), "CASH" end
		return "potion", reward.luckMin .. " MIN", "2x LUCK"
	end
	local CW, CH = 204, 236
	for i, reward in Config.DAILY do
		local icon, amount, kind = rewardBits(reward)
		if i < #Config.DAILY then
			local x, y = ((i - 1) % 3) * (CW + 14), ((i - 1) // 3) * (CH + 16)
			local _, face = card(body, colors[i], O(CW, CH), O(x, y))
			label(face, "DAY " .. i, 36, { Position = O(0, 6), Size = O(CW, 44) })
			sticker(face, icon, 92, O(CW / 2 - 20, 104), true)
			label(face, amount, 28, { Position = O(60, 108), Size = O(140, 36), TextXAlignment = RIGHT }, true)
			label(face, kind, 22, { Position = O(0, 146), Size = O(CW, 28) })
			cards[i] = button(face, "LOCKED", P.red, O(176, 48), O(CW / 2, 200), function() Remotes.ClaimDaily:FireServer() end, { text = 24 })
		else
			local f, face = card(body, ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("FF2BD6")), ColorSequenceKeypoint.new(0.5, hex("FF8A00")), ColorSequenceKeypoint.new(1, hex("FFE600")) }),
				O(264, CH * 2 + 16), O(3 * (CW + 14) + 2, 0), 16)
			f.BackgroundColor3 = hex("A33F00")
			local glow = ink(f, 5, C.yellow)
			live(glow, "glint")
			local t = label(face, "DAY " .. i, 48, { Position = O(0, 8), Size = O(264, 58) })
			goldText(t)
			rays(face, 320, O(132, 200), WHITE)
			sticker(face, "giftpurple", 180, O(132, 200), true)
			label(face, "MEGA GIFT", 36, { Position = O(0, 300), Size = O(264, 44) })
			label(face, "$" .. Config.format(reward.cash or 0) .. " + " .. (reward.luckMin or 0) .. " MIN\n2x LUCK", 22, { Position = O(0, 346), Size = O(264, 56) })
			cards[i] = button(face, "LOCKED", P.red, O(220, 54), O(132, 446), function() Remotes.ClaimDaily:FireServer() end, { text = 26 })
		end
	end
	refreshers.Daily = function()
		local wait = state.dailyWait - (os.clock() - stateAt)
		local today = state.dailyDay % #cards + 1
		for i, b in cards do
			setDone(b, false)
			if i < today then setDone(b, true, "CLAIMED")
			elseif i > today then paint(b, P.red) setLabel(b, "LOCKED")
			elseif wait <= 0 then paint(b, P.lime) setLabel(b, "CLAIM!")
			else paint(b, P.blue) setLabel(b, fmtTime(wait)) end
		end
	end
	task.spawn(function()
		while task.wait(1) do
			dailyClaimable = state.dailyWait - (os.clock() - stateAt) <= 0
			dailyAlert.Visible = dailyClaimable
			local boost = state.boostLeft - (os.clock() - stateAt)
			boostTimer.Text = boost > 0 and fmtTime(boost) or ""
			if current == "Daily" then refreshers.Daily() end
			if current == "Boost" and refreshers.Boost then refreshers.Boost() end
		end
	end)
end

----- Luck boost -----
do
	local body = window("Boost", "Luck Boost!", "bolt", 660, 430)
	rays(body, 230, O(140, 90), C.yellow)
	sticker(body, "luck", 150, O(140, 90), true)
	local t = label(body, "2x LUCK", 66, { Position = O(240, 30), Size = O(0, 80), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = LEFT })
	goldText(t)
	label(body, "for " .. Config.LUCK_BOOST_MINUTES .. " min each, and it stacks!", 22, { Position = O(244, 112), Size = O(360, 28), TextXAlignment = LEFT })
	local pill = round(new("Frame", { Position = O(60, 176), Size = O(500, 50) }, body), 14)
	grad(pill, P.blue)
	ink(pill, 3)
	local status = label(pill, "", 22, { Size = S(1, 1) })
	priceButton(body, "product", "LuckBoost", O(300, 80), O(310, 290), 38)
	label(body, "Stacks with the x2 Luck pass and your upgrades.", 18, { Position = O(0, 342), Size = O(620, 24) })
	refreshers.Boost = function()
		local left = state.boostLeft - (os.clock() - stateAt)
		status.Text = left > 0 and ("Boost active: <font color=\"#FFE600\">" .. fmtTime(left) .. "</font> left") or ("No boost yet: get 2x luck for " .. Config.LUCK_BOOST_MINUTES .. " minutes!")
	end
end

----- Free reward: join the group and favorite the game for a free luck boost -----
do
	local hasGroup = (Config.GROUP_ID or 0) ~= 0
	local body = window("Free", "Free Reward!", "gift", 660, hasGroup and 520 or 440)
	rays(body, 210, O(150, 74), C.yellow)
	sticker(body, "luck", 130, O(150, 74), true)
	local t = label(body, "2x LUCK", 62, { Position = O(240, 24), Size = O(0, 76), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = LEFT })
	goldText(t)
	label(body, "for " .. (Config.FREE_LUCK_MINUTES or 30) .. " minutes!", 22, { Position = O(244, 100), Size = O(300, 28), TextXAlignment = LEFT })
	local done = { group = not hasGroup, fav = false }
	local claim
	local function refreshClaim()
		if state.freeClaimed then return setDone(claim, true, "CLAIMED") end
		paint(claim, (done.group and done.fav) and P.lime or P.blue)
	end
	local y = 160
	local function step(n, text, btnText, key, action)
		local _, face = card(body, P.blue, O(620, 72), O(0, y), 14)
		local badge = round(new("Frame", { Position = O(14, 12), Size = O(42, 42) }, face), 21)
		grad(badge, P.gold)
		ink(badge, 3)
		label(badge, tostring(n), 24, { Size = S(1, 1) })
		label(face, text, 24, { Position = O(72, 0), Size = U(0, 330, 1, 0), TextXAlignment = LEFT })
		local b
		b = button(face, btnText, P.lime, O(180, 52), O(512, 33), function()
			action(function(ok)
				if ok then
					done[key] = true
					setDone(b, true, "DONE!")
					refreshClaim()
				end
			end)
		end, { text = 24 })
		y += 84
		return b
	end
	if hasGroup then
		local gb = step(1, "Join our group", "JOIN", "group", function(cb)
			pcall(function() GroupService:PromptJoinAsync(Config.GROUP_ID) end)
			local ok, inGroup = pcall(player.IsInGroup, player, Config.GROUP_ID)
			cb(ok and inGroup)
		end)
		task.spawn(function()
			local ok, inGroup = pcall(player.IsInGroup, player, Config.GROUP_ID)
			if ok and inGroup then
				done.group = true
				setDone(gb, true, "DONE!")
			end
		end)
	end
	local favCb
	AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
		if favCb then favCb(result == Enum.AvatarPromptResult.Success) favCb = nil end
	end)
	step(hasGroup and 2 or 1, "Favorite the game", "FAVORITE", "fav", function(cb)
		if RunService:IsStudio() then return cb(true) end -- shortcut: the favorite prompt never answers in Studio, so testing skips it
		favCb = cb
		local ok = pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
		if not ok then favCb = nil cb(true) end -- shortcut: prompt unavailable (e.g. Studio), so don't block the player on it
	end)
	label(body, hasGroup and "Do both, then claim your reward!" or "Favorite the game, then claim your reward!", 20, { Position = O(0, y + 2), Size = O(620, 26) })
	claim = button(body, "CLAIM", P.blue, O(300, 76), O(310, y + 80), function()
		if state.freeClaimed then return end
		if not (done.group and done.fav) then return toast(hasGroup and "Join and favorite first!" or "Favorite the game first!") end
		Remotes.ClaimFree:FireServer()
	end, { text = 36 })
	refreshers.Free = refreshClaim
end

----- Starter pack -----
do
	local body = window("Starter", "Starter Pack", "chest", 820, 480)
	local _, face = card(body, { hex("00E1FF"), hex("0062FF"), hex("003BB3") }, O(780, 268), O(0, 0), 16)
	tag(face, "BEST VALUE!", O(700, 14))
	local function item(x, icon, text)
		rays(face, 260, O(x, 106), WHITE)
		sticker(face, icon, 160, O(x, 106), true)
		local plate = round(new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = O(x, 200), Size = O(300, 48) }, face), 12)
		grad(plate, P.gold)
		ink(plate, 4)
		label(plate, text, 26, { Size = S(1, 1) })
	end
	item(200, "cash", "$" .. Config.format(Config.STARTER_PACK.cash) .. " CASH")
	label(face, "+", 64, { Position = O(340, 70), Size = O(100, 80) })
	item(580, "potion", Config.STARTER_PACK.luckMin .. " MIN 2x LUCK")
	priceButton(body, "product", "StarterPack", O(480, 90), O(390, 350), 38, "BUY BUNDLE  ")
end

----- Welcome back: what the zoo earned while you were away (the server already paid it) -----
do
	local body = window("Welcome", "Welcome Back!", "goldpaw", 660, 414)
	label(body, "While you were away, your animals earned", 24, { Position = O(0, 6), Size = O(620, 30) })
	sticker(body, "cash", 120, O(170, 112), true)
	local amount = label(body, "", 64, { Position = O(250, 72), Size = O(0, 80), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = LEFT, TextColor3 = C.cash })
	local away = label(body, "", 22, { Position = O(0, 182), Size = O(620, 28) })
	label(body, "Your animals earn up to " .. (Config.OFFLINE_HOURS or 3) .. " hours of money while you're away.", 16, { Position = O(0, 214), Size = O(620, 22), TextColor3 = hex("FFFFFF") })
	button(body, "COLLECT", P.blue, O(270, 80), O(160, 296), function() close("Welcome") end, { text = 36 })
	priceButton(body, "product", "OfflineDouble", O(270, 80), O(460, 296), 34, "2X ")
	showOffline = function(o)
		amount.Text = "+$" .. Config.format(o.earned)
		away.Text = string.format("Away for %s (you get the first %d hours)", fmtTime(o.away), Config.OFFLINE_HOURS or 3)
		task.delay(0.5, function() if not current then open("Welcome") end end)
	end
end

----- Draw editor -----
do
	local W, H, N = Config.W, Config.H, Config.W * Config.H
	-- old layout used top-left positions; buttons are centre anchored now
	local function at(size, pos) return pos + U(size.X.Scale / 2, size.X.Offset / 2, size.Y.Scale / 2, size.Y.Offset / 2) end
	local function btn(parent, str, pal, size, pos, cb, opt) return button(parent, str, pal, size, at(size, pos), cb, opt) end
	local body, stage = window("Editor", "Draw Your Animal", "pencil", 1240, 700)
	local nameBox = new("TextBox", { Size = O(380, 50), Position = O(590, -26), BackgroundColor3 = WHITE, PlaceholderText = "Name your animal...", Text = "", Font = FONT,
		TextSize = 26, TextColor3 = BLACK, PlaceholderColor3 = rgb(150, 150, 150), ClearTextOnFocus = false }, stage)
	round(nameBox, 12)
	ink(nameBox, 4)
	btn(stage, "RANDOM", P.blue, O(150, 52), O(982, -27), function() nameBox.Text = Config.NAMES[math.random(#Config.NAMES)] end, { text = 26 })

	local ed = { cells = table.create(N, 0), eyes = {}, stickers = {}, tab = 1, tool = "brush", size = 2, color = 3, eye = 1, sticker = 1, undo = {}, redo = {} }
	local function pick(group, chosen) -- highlights one button of a group
		for _, b in group do
			b.Outline.Color = b == chosen and C.yellow or BLACK
			b.Outline.Thickness = b == chosen and 6 or 4
		end
	end

	-- canvas
	local centre = sheetPanel(body, O(650, 536), O(268, 64))
	local canvas = new("Frame", { Size = O(630, 441), Position = O(10, 66), BackgroundColor3 = C.canvas, ClipsDescendants = true }, centre) -- 630:441 = the grid's 240:168
	ink(canvas, 3)
	label(canvas, "< HEAD", 18, { Size = O(90, 22), Position = U(0, 6, 0.5, -11), TextColor3 = rgb(120, 170, 200) }).UIStroke.Enabled = false
	label(canvas, "TAIL >", 18, { Size = O(90, 22), Position = U(1, -96, 0.5, -11), TextColor3 = rgb(120, 170, 200) }).UIStroke.Enabled = false
	-- 240 x 168 = 40320 cells. The finished picture is drawn as merged rectangles (a few hundred frames); only cells the
	-- current stroke touches get a frame of their own, and they fold back into rectangles when the finger lifts.
	local baseLayer = new("Frame", { Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, canvas)
	local liveLayer = new("Frame", { Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, canvas)
	local itemLayer = new("Frame", { Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, canvas)
	local pad = new("TextButton", { Size = S(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 20 }, canvas)
	local live, liveCount = {}, 0

	local function drawItems()
		itemLayer:ClearAllChildren()
		Render.items(itemLayer, { e = ed.eyes, s = ed.stickers })
	end
	local function redraw()
		liveLayer:ClearAllChildren()
		table.clear(live)
		liveCount = 0
		baseLayer:ClearAllChildren()
		Render.draw(baseLayer, { g = Render.encode(ed.cells) }, false)
		drawItems()
	end
	local function paintCell(i)
		local f = live[i]
		if not f then
			local x, y = (i - 1) % W, (i - 1) // W
			f = new("Frame", { Size = U(1 / W, 1, 1 / H, 1), Position = S(x / W, y / H) }, liveLayer) -- +1px hides seams
			live[i] = f
			liveCount += 1
		end
		local v = ed.cells[i]
		f.BackgroundColor3 = v == 0 and C.canvas or Config.PALETTE[v] -- an erased cell covers the old rectangle underneath
	end
	local function copyList(l)
		local out = {}
		for i, v in l do out[i] = table.clone(v) end
		return out
	end
	-- undo steps keep the compressed drawing, not a 40320-entry table: 30 steps would otherwise be ~20 MB on a phone
	local function snapshot() return { g = Render.encode(ed.cells), eyes = copyList(ed.eyes), stickers = copyList(ed.stickers) } end
	local function restore(s)
		ed.cells = s.cells or Render.decode(s.g)
		ed.eyes, ed.stickers = s.eyes, s.stickers
		redraw()
	end
	local function pushUndo()
		table.insert(ed.undo, snapshot())
		if #ed.undo > 30 then table.remove(ed.undo, 1) end
		ed.redo = {}
	end
	local function step(from, to)
		if #from == 0 then return end
		table.insert(to, snapshot())
		restore(table.remove(from))
	end
	btn(centre, "UNDO", P.blue, O(200, 48), O(10, 9), function() step(ed.undo, ed.redo) end, { text = 24 })
	btn(centre, "REDO", P.blue, O(200, 48), O(225, 9), function() step(ed.redo, ed.undo) end, { text = 24 })
	btn(centre, "CLEAR", P.red, O(200, 48), O(440, 9), function()
		pushUndo()
		restore({ cells = table.create(N, 0), eyes = {}, stickers = {} })
	end, { icon = "trash", iconSize = 32, text = 24 })

	-- drawing operations
	local BRUSH_RADIUS = { 1, 4, 8, 14 } -- S is a fine pen 3 cells wide; M/L/XL keep about the same on-screen size as before
	local function stamp(cx, cy)
		local r = BRUSH_RADIUS[ed.size]
		for dy = -r, r do
			for dx = -r, r do
				local x, y = cx + dx, cy + dy
				if dx * dx + dy * dy <= r * r + r and x >= 0 and x < W and y >= 0 and y < H then
					local i = y * W + x + 1
					local v = ed.cells[i]
					local nv = v
					if ed.tab == 1 then
						if ed.tool == "erase" then nv = 0 elseif v == 0 then nv = 1 end
					elseif v ~= 0 then -- painting never leaves the shape
						nv = ed.tool == "erase" and 1 or ed.color
					end
					if nv ~= v then
						ed.cells[i] = nv
						paintCell(i)
					end
				end
			end
		end
	end
	local function fill(cx, cy)
		local start = cy * W + cx + 1
		local target = ed.cells[start]
		local nv
		if ed.tab == 1 then
			if target ~= 0 then return end
			nv = 1
		else
			if target == 0 then return end
			nv = ed.color
		end
		if nv == target then return end
		local stack = { start }
		while #stack > 0 do
			local i = table.remove(stack)
			if ed.cells[i] == target then
				ed.cells[i] = nv
				local x = (i - 1) % W
				if x > 0 then table.insert(stack, i - 1) end
				if x < W - 1 then table.insert(stack, i + 1) end
				if i > W then table.insert(stack, i - W) end
				if i <= N - W then table.insert(stack, i + W) end
			end
		end
		redraw() -- a fill can change thousands of cells: redraw as rectangles in one go
	end
	local function place(list, max, kind, fx, fy, word)
		for i, it in list do
			if math.abs(it[1] - fx) < 0.05 and math.abs(it[2] - fy) < 0.07 then
				table.remove(list, i)
				return drawItems()
			end
		end
		if #list >= max then return toast("That's plenty of " .. word .. "!") end
		local cx, cy = math.clamp(math.floor(fx * W), 0, W - 1), math.clamp(math.floor(fy * H), 0, H - 1)
		if ed.cells[cy * W + cx + 1] == 0 then return toast("Put it on your animal!") end -- the server drops anything off the drawing too
		table.insert(list, { fx, fy, kind, math.min(ed.size, 3) })
		drawItems()
	end

	local drawing, last = false, nil
	local function cellAt(input)
		local rel = (Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition) / canvas.AbsoluteSize
		return math.clamp(math.floor(rel.X * W), 0, W - 1), math.clamp(math.floor(rel.Y * H), 0, H - 1), math.clamp(rel.X, 0, 1), math.clamp(rel.Y, 0, 1)
	end
	local function isPress(input) return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch end
	pad.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local cx, cy, fx, fy = cellAt(input)
		pushUndo()
		if ed.tab == 3 then place(ed.eyes, Config.MAX_EYES, ed.eye, fx, fy, "eyes")
		elseif ed.tab == 4 then place(ed.stickers, Config.MAX_STICKERS, ed.sticker, fx, fy, "stickers")
		elseif ed.tool == "fill" then fill(cx, cy)
		else
			drawing, last = true, { cx, cy }
			stamp(cx, cy)
		end
	end)
	pad.InputChanged:Connect(function(input)
		if not drawing or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end
		local cx, cy = cellAt(input)
		-- fill the gap between two pointer samples so fast strokes stay solid; stamps half a brush apart are enough
		local reach = math.max(math.abs(cx - last[1]), math.abs(cy - last[2]))
		local steps = math.max(1, math.ceil(reach / math.max(1, BRUSH_RADIUS[ed.size] * 0.5)))
		for t = 1, steps do
			stamp(math.round(last[1] + (cx - last[1]) * t / steps), math.round(last[2] + (cy - last[2]) * t / steps))
		end
		last = { cx, cy }
		if liveCount > 3000 then redraw() end -- a long XL stroke: fold it into rectangles before the frame count gets heavy
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) and drawing then
			drawing = false
			redraw()
		end
	end)

	-- left panels (one per tab)
	local panels = {}
	local function panel(title, hint)
		local p = sheetPanel(body, O(260, 536), O(0, 64))
		p.Visible = false
		label(p, title, 28, { Size = O(236, 36), Position = O(12, 8), TextXAlignment = LEFT }, true)
		label(p, hint, 18, { Size = O(236, 70), Position = U(0, 12, 1, -80), TextWrapped = true })
		local grid = new("Frame", { Size = O(240, 330), Position = O(12, 52), BackgroundTransparency = 1 }, p)
		table.insert(panels, p)
		return grid
	end
	local function gridOf(parent, cell, gap)
		new("UIGridLayout", { CellSize = O(cell, cell), CellPadding = O(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
	end
	local g = panel("TEMPLATES", "Pick an animal shape or draw your own.")
	new("UIGridLayout", { CellSize = O(116, 76), CellPadding = O(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, g) -- 2 x 4 wide cards, the drawings are 80:56
	for i, t in Config.TEMPLATES do
		local shape = Config.templateGrid(t, false)
		local b = cellButton(g, nil, P.blue, function()
			pushUndo()
			ed.cells = table.clone(shape)
			redraw()
		end, { plain = true }, i)
		-- the button shows the template in its real colours, so you can tell which animal it is
		local box = new("Frame", { BackgroundTransparency = 1, AnchorPoint = CENTER, Position = S(0.5, 0.5), Size = U(1, -12, 1, -12) }, b.Face)
		Render.draw(box, { g = Render.encode(Config.templateGrid(t, true)), e = {}, s = {} }, false, 3)
	end

	g = panel("COLOURS", "Paint stays inside your shape.")
	gridOf(g, 35, 5)
	local swatches = {}
	for i = 2, #Config.PALETTE do
		local col = Config.PALETTE[i]
		local b
		b = cellButton(g, nil, { col, col, col:Lerp(BLACK, 0.4) }, function()
			ed.color = i
			pick(swatches, b)
		end, { plain = true, lip = 3, r = 8 }, i)
		table.insert(swatches, b)
	end
	pick(swatches, swatches[2])

	g = panel("EYES", "Tap your animal to stick an eye on. Tap an eye again to take it off.")
	gridOf(g, 72, 10)
	local eyeButtons = {}
	for i = 1, Config.EYE_STYLES do
		local b
		b = cellButton(g, nil, P.blue, function()
			ed.eye = i
			pick(eyeButtons, b)
		end, nil, i)
		-- Render.items wants a grid-shaped container, so give it an oversized invisible one centred on the button
		local box = new("Frame", { AnchorPoint = CENTER, Position = S(0.5, 0.5), Size = O(240 * W / H, 240), BackgroundTransparency = 1 }, b.Face)
		Render.items(box, { e = { { 0.5, 0.5, i, 3 } } })
		table.insert(eyeButtons, b)
	end
	pick(eyeButtons, eyeButtons[1])

	g = panel("STICKERS", "Tap your animal to stick a sticker on. Tap it again to take it off.")
	gridOf(g, 54, 7)
	local stickerButtons = {}
	for i, key in Config.STICKERS do
		local b
		b = cellButton(g, nil, P.blue, function()
			ed.sticker = i
			pick(stickerButtons, b)
		end, nil, i)
		sticker(b.Face, key, 40, S(0.5, 0.5))
		table.insert(stickerButtons, b)
	end
	pick(stickerButtons, stickerButtons[1])

	-- right panel: tools, size, confirm
	local right = sheetPanel(body, O(260, 536), O(926, 64))
	local toolsTitle = label(right, "TOOLS", 28, { Size = O(236, 36), Position = O(12, 8), TextXAlignment = LEFT }, true)
	local toolButtons = {}
	-- icon pack has no bucket or eraser: the potion bottle pours paint, the cross rubs it out
	for i, t in { { "brush", "BRUSH", "pencil" }, { "fill", "FILL", "potion" }, { "erase", "ERASE", "cross" } } do
		local b
		b = btn(right, t[2], P.blue, O(74, 84), O(12 + (i - 1) * 81, 50), function()
			ed.tool = t[1]
			pick(toolButtons, b)
		end, { text = 16, icon = t[3], iconSize = 34, vertical = true })
		table.insert(toolButtons, b)
	end
	pick(toolButtons, toolButtons[1])
	label(right, "SIZE", 28, { Size = O(236, 32), Position = O(12, 146), TextXAlignment = LEFT }, true)
	local sizeButtons = {}
	for i, l in { "S", "M", "L", "XL" } do
		local b
		b = btn(right, l, P.blue, O(54, 54), O(12 + (i - 1) * 61, 184), function()
			ed.size = i
			pick(sizeButtons, b)
		end, { text = 26 })
		table.insert(sizeButtons, b)
	end
	pick(sizeButtons, sizeButtons[2])
	btn(right, "FINISH\nDRAWING", P.gold, O(236, 110), O(12, 414), function()
		local filled = 0
		for _, v in ed.cells do if v ~= 0 then filled += 1 end end
		if filled < Config.MIN_CELLS then return toast("Draw your animal first!") end
		Remotes.Create:FireServer({ n = nameBox.Text, g = Render.encode(ed.cells), e = ed.eyes, s = ed.stickers })
		close("Editor")
		nameBox.Text = ""
		ed.undo, ed.redo = {}, {}
		restore({ cells = table.create(N, 0), eyes = {}, stickers = {} })
	end, { icon = "paw", iconSize = 56, text = 30 })

	-- tabs
	local tabButtons = {}
	local function setTab(i)
		ed.tab = i
		pick(tabButtons, tabButtons[i])
		for k, p in panels do p.Visible = k == i end
		local draws = i <= 2
		toolsTitle.Visible = draws
		for _, b in toolButtons do b.Visible = draws end
		sizeButtons[4].Visible = draws
		if not draws and ed.size > 3 then
			ed.size = 3
			pick(sizeButtons, sizeButtons[3])
		end
	end
	for i, name in { "1  SHAPE", "2  PAINT", "3  EYES", "4  STICKERS" } do
		tabButtons[i] = btn(body, name, P.lime, O(294, 54), O((i - 1) * 302, 0), function() setTab(i) end, { text = 26 })
	end
	setTab(1)
end

----- Animal Trader: Safari Sam at the centre stall buys animals for Config.SELL_SECONDS of their income -----
do
	local body = window("Sell", "Animal Trader", "cashbundle", 760, 560)
	label(body, string.format('Safari Sam pays <font color="#6BFF3A">%d seconds</font> of an animal\'s income.', Config.SELL_SECONDS), 24, { Size = O(720, 30) })
	local list = new("ScrollingFrame", { Position = O(0, 40), Size = O(720, 370), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("9A9A9A"),
		TopImage = "", BottomImage = "", AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = U() }, body)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 12) }, list)
	local empty = label(body, "No animals to sell yet!", 30, { Position = O(0, 180), Size = O(720, 40) })
	local sellAll = button(body, "SELL ALL UNEQUIPPED", P.gold, O(460, 64), O(360, 456), function() Remotes.SellAll:FireServer() end, { icon = "cashbundle", iconSize = 44, text = 26 })
	refreshers.Sell = function()
		for _, ch in list:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
		local spare = 0
		for i, a in state.animals do
			local price = Config.sellPrice(a)
			if not a.eq then spare += price end
			local holder = new("Frame", { BackgroundTransparency = 1, Size = O(700, 98), LayoutOrder = (a.eq and 1000 or 0) + i }, list)
			local _, face = card(holder, RARITY_PAL[a.r], O(696, 90), O(0, 0), 14)
			Render.draw(display(face, O(110, 70), O(10, 7)), a.d, true, 3)
			local m = Config.MUTATIONS[a.m or 1]
			label(face, a.d.n, 28, { Position = O(134, 6), Size = O(280, 36), TextXAlignment = LEFT }, true)
			label(face, ((a.m or 1) > 1 and m.name:upper() .. " " or "") .. Config.RARITIES[a.r].name:upper() .. "  ·  $" .. Config.format(Config.income(a)) .. "/s" .. (a.eq and "  ·  IN ZOO" or ""),
				18, { Position = O(134, 46), Size = O(330, 24), TextXAlignment = LEFT })
			local b
			b = button(face, "SELL $" .. Config.format(price), P.lime, O(210, 58), O(580, 40), function()
				if a.eq and not b:GetAttribute("Sure") then -- selling an animal that is earning takes a second tap
					b:SetAttribute("Sure", true)
					setLabel(b, "SURE?")
					return
				end
				Remotes.Sell:FireServer(a.id)
			end, { text = 24 })
		end
		empty.Visible = #state.animals == 0
		setLabel(sellAll, "SELL ALL UNEQUIPPED  $" .. Config.format(spare))
		sellAll.Visible = spare > 0
	end
end

----- the roll: after FINISH DRAWING the server rolls rarity and mutation and judges the drawing; this screen plays it back -----
local function fmtX(v)
	if v >= 1000 then return Config.format(v) end
	return (string.format("%.2f", v):gsub("%.?0+$", ""))
end
local function odds(p)
	if p >= 0.05 then return string.format("%d%%", math.floor(p * 100 + 0.5)) end
	return "1 in " .. Config.format(math.floor(1 / math.max(p, 1e-9) + 0.5))
end
do
	local layer = new("Frame", { Name = "Roll", Size = S(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, gui)
	new("TextButton", { Name = "Dim", Position = O(0, -200), Size = U(1, 0, 1, 200), Text = "", AutoButtonColor = false, BackgroundColor3 = hex("10162A"), BackgroundTransparency = 0.35 }, layer) -- swallows clicks behind the screen, and reaches up under the top bar
	local root = scaled(new("Frame", { AnchorPoint = CENTER, Position = S(0.5, 0.5), Size = O(1280, 720), BackgroundTransparency = 1 }, layer))
	local stage = new("Frame", { Name = "Stage", Size = S(1, 1), BackgroundTransparency = 1 }, root)
	local pop = new("UIScale", { Name = "Pop" }, stage) -- separate from the fit scale on root

	-- left: the animal's name over a glass bubble whose ring takes the rarity colour
	local nameL = label(stage, "", 56, { Position = O(26, 58), Size = O(400, 72) })
	local raysF = rays(stage, 600, O(226, 391), WHITE)
	local bubble = new("Frame", { AnchorPoint = CENTER, Position = O(226, 391), Size = O(390, 390), BackgroundColor3 = DISPLAY, BackgroundTransparency = 0.15 }, stage)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, bubble)
	local ring = new("UIStroke", { Thickness = 8, Color = WHITE }, bubble)
	local ringInk = new("Frame", { AnchorPoint = CENTER, Position = O(226, 391), Size = O(406, 406), BackgroundTransparency = 1 }, stage)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ringInk)
	ink(ringInk, 4)
	round(new("Frame", { AnchorPoint = CENTER, Position = O(110, 96), Size = O(150, 40), Rotation = -32, BackgroundColor3 = WHITE, BackgroundTransparency = 0.5 }, bubble), 20)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, new("Frame", { AnchorPoint = CENTER, Position = O(290, 300), Size = O(30, 30), BackgroundColor3 = WHITE, BackgroundTransparency = 0.45 }, bubble))
	local art = new("Frame", { AnchorPoint = CENTER, Position = O(195, 195), Size = O(300, 214), BackgroundTransparency = 1, ZIndex = 2 }, bubble)

	-- right: two strips that spin and stop on the rolled result
	local TILE, GAP, BOX_W = 172, 10, 712
	local function strip(title, y)
		label(stage, title, 32, { Position = O(519, y), Size = O(400, 40), TextXAlignment = LEFT })
		local box = round(new("Frame", { Position = O(519, y + 44), Size = O(BOX_W, 100), BackgroundColor3 = hex("1A2135") }, stage), 22)
		ink(box, 4)
		local clip = round(new("CanvasGroup", { Size = S(1, 1), BackgroundTransparency = 1 }, box), 22) -- clips the tiles to the rounded box
		return new("Frame", { Name = "Track", BackgroundTransparency = 1, Size = U(0, 0, 1, 0) }, clip)
	end
	local rTrack, mTrack = strip("RARITY", 62), strip("MUTATION", 206)
	local function tileX(k) return (k - 1) * (TILE + GAP) + 8 + TILE / 2 end
	local function centreOn(k) return O(BOX_W / 2 - tileX(k), 0) end
	-- the list repeated `cycles` times; the result sits in the second-to-last cycle so there are tiles on both sides when it stops
	local function fill(track, list, pals, pick, cycles)
		track:ClearAllChildren()
		local tiles = {}
		for c = 0, cycles - 1 do
			for i, item in list do
				local k = c * #list + i
				local pal = pals[i]
				local f = round(new("Frame", { Name = "Tile", AnchorPoint = CENTER, Position = O(tileX(k), 50), Size = O(TILE, 84), BackgroundColor3 = typeof(pal) == "table" and pal[3] or BLACK }, track), 16)
				ink(f, 3)
				local face = round(new("Frame", { Name = "Face", Size = U(1, 0, 1, -5) }, f), 15)
				grad(face, pal, typeof(pal) == "ColorSequence" and 0 or nil) -- rainbow runs sideways
				studs(face, 0.7, nil, 15)
				local l = label(face, item.name:upper(), 22, { Size = S(1, 1) }, true)
				new("UIScale", {}, f)
				tiles[k] = { f = f, l = l }
			end
		end
		return tiles, (cycles - 2) * #list + pick
	end
	local function land(t, chance)
		t.f.Outline.Color = WHITE
		t.f.Outline.Thickness = 6
		t.l.Text = t.l.Text .. "\n" .. chance
		t.f.UIScale.Scale = 1.15
		TweenService:Create(t.f.UIScale, BACK, { Scale = 1 }):Play()
	end

	-- the judge: five bars, five stars, a verdict, then the income multiplier and how it was made
	local review = label(stage, "THE JUDGE'S REVIEW", 38, { Position = O(519, 360), Size = O(600, 48), TextXAlignment = LEFT })
	goldText(review)
	local bars = {}
	for i, name in Config.JUDGE do
		local x = 519 + (i - 1) * 145
		label(stage, name, 22, { Position = O(x, 410), Size = O(132, 28) })
		local track = round(new("Frame", { Position = O(x, 440), Size = O(132, 20), BackgroundColor3 = WHITE }, stage), 10)
		ink(track, 3)
		local f = round(new("Frame", { Size = U(0, 0, 1, 0) }, track), 10)
		grad(f, P.lime)
		bars[i] = f
	end
	local stars = {}
	for i = 1, 5 do
		local s = sticker(stage, "star", 72, O(555 + (i - 1) * 84, 514))
		new("UIScale", {}, s)
		stars[i] = s
	end
	local function starLook(s, on)
		local a = s:FindFirstChild("Art")
		if a then
			a.ImageColor3 = on and WHITE or BLACK -- an unearned star is a dark silhouette
			a.ImageTransparency = on and 0 or 0.5
		elseif s:FindFirstChild("Label") then s.Label.TextTransparency = on and 0 or 0.7 end
	end
	local verdict = label(stage, "", 46, { Position = O(980, 484), Size = O(280, 60), TextXAlignment = LEFT })
	goldText(verdict)
	local incomeL = label(stage, "", 64, { Position = O(519, 552), Size = O(740, 84), TextXAlignment = LEFT })
	goldText(incomeL)
	local breakdown = label(stage, "", 26, { Position = O(519, 640), Size = O(740, 34), TextXAlignment = LEFT, TextColor3 = hex("BFD6FF") })

	local rollId = 0
	local doneBtn = button(stage, "AWESOME!", P.lime, O(270, 72), O(226, 650), function()
		rollId += 1
		layer.Visible = false
		hud.Visible = true
		if not current then TweenService:Create(blur, TweenInfo.new(0.25), { Size = 0 }):Play() end
	end, { text = 34 })

	Remotes.Rolled.OnClientEvent:Connect(function(res)
		rollId += 1
		local id = rollId
		local rinfo, minfo = Config.RARITIES[res.r], Config.MUTATIONS[res.m]
		if current then close(current) end
		layer.Visible = true
		hud.Visible = false
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = 14 }):Play()
		nameL.Text = res.name
		art:ClearAllChildren()
		Render.draw(art, res.d, true, 2)
		if minfo and minfo.name == "Matrix" then matrixAura(art.Drawing) end
		ring.Color = WHITE
		raysF.Visible = false
		for _, b in bars do b.Size = U(0, 0, 1, 0) end
		for _, s in stars do starLook(s, false) end
		verdict.Text, incomeL.Text, breakdown.Text = "", "", ""
		doneBtn.Visible = false
		pop.Scale = 0.85
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

		local rTiles, rT = fill(rTrack, Config.RARITIES, RARITY_PAL, res.r, 5)
		local mTiles, mT = fill(mTrack, Config.MUTATIONS, MUT_PAL, res.m, 7)
		rTrack.Position, mTrack.Position = centreOn(2), centreOn(2)
		local function spin(dur) return TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) end
		TweenService:Create(rTrack, spin(2.4), { Position = centreOn(rT) }):Play()
		task.delay(0.35, function()
			if id == rollId then TweenService:Create(mTrack, spin(2.6), { Position = centreOn(mT) }):Play() end
		end)

		task.spawn(function()
			local function still(t) -- waits, and says whether this roll is still the one on screen
				task.wait(t)
				return id == rollId
			end
			if not still(2.45) then return end
			land(rTiles[rT], odds(res.rChance))
			ring.Color = rinfo.color
			raysF.Visible = res.r >= 4 -- Epic and up get light rays
			for _, bar in raysF:GetChildren() do bar.BackgroundColor3 = rinfo.color end
			if not still(0.55) then return end
			land(mTiles[mT], odds(res.mChance))
			if not still(0.4) then return end
			for i, b in bars do
				local sc = res.scores[i] or 0
				local pal = sc >= 0.5 and P.lime or P.red
				b.UIGradient.Color = ColorSequence.new(pal[1], pal[2])
				TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = U(math.max(sc, 0.06), 0, 1, 0) }):Play()
				if not still(0.12) then return end
			end
			if not still(0.3) then return end
			for i = 1, res.stars do
				starLook(stars[i], true)
				stars[i].UIScale.Scale = 1.5
				TweenService:Create(stars[i].UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				if not still(0.18) then return end
			end
			verdict.Text = Config.VERDICTS[res.stars] or ""
			if not still(0.25) then return end
			local t0 = os.clock()
			repeat -- count the multiplier up from x1
				local a = math.min(1, (os.clock() - t0) / 0.7)
				incomeL.Text = "INCOME x" .. fmtX(1 + (res.mult - 1) * a * a * (3 - 2 * a))
				RunService.RenderStepped:Wait()
				if id ~= rollId then return end
			until a >= 1
			breakdown.Text = string.format("%d star%s x%s  ·  %s x%s  ·  %s x%s  ·  <font color=\"#6BFF3A\">+$%s/s</font>", res.stars, res.stars == 1 and "" or "s",
				fmtX(res.starMult), rinfo.name, fmtX(res.rarityMult), minfo.name, fmtX(res.mutMult), Config.format(res.inc))
			doneBtn.Visible = true
		end)
	end)
end

----- animals walking in the world -----
-- world labels stay TextScaled so they read at any distance
local function wtext(parent, str, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = str, Font = FONT, TextColor3 = WHITE, TextScaled = true,
		TextStrokeTransparency = 0, TextStrokeColor3 = BLACK, Size = S(1, 1) }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end
local animals = {}
-- extra look for a mutation's animals walking in the zoo, by mutation name
local MUT_FX = {
	Matrix = function(part)
		part.Size *= Vector3.new(1.25, 1.25, 1) -- room on the cutout for the aura; the drawing shrinks back to its own size
		for _, sg in part:GetChildren() do
			if sg:IsA("SurfaceGui") then
				sg.Drawing.Size = S(0.8, 0.8)
				matrixAura(sg.Drawing)
			end
		end
		new("PointLight", { Color = hex("3CFF6E"), Range = 8, Brightness = 1 }, part)
		new("ParticleEmitter", { Color = ColorSequence.new(hex("3CFF6E")), LightEmission = 1, Rate = 8, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(0.35, 0), Transparency = NumberSequence.new(0.2, 1) }, part)
	end,
}

local function addAnimal(part)
	if animals[part] or not part:IsDescendantOf(workspace) then return end
	local ok, design = pcall(HttpService.JSONDecode, HttpService, part:GetAttribute("Design"))
	local pen = part.Parent.Parent:FindFirstChild("Pen")
	if not ok or not pen then return end
	local rarity = part:GetAttribute("Rarity") or 0
	local k = 1 + rarity * 0.12
	-- a paper-thin cutout: the drawing is on both faces, so from behind it shows mirrored like a real cardboard cutout,
	-- and from the side it is a sliver. The size change is local; the server's part stays a 1-stud marker.
	part.Size = Vector3.new(8 * k, 5.6 * k, 0.05)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = new("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.25,
			MaxDistance = 300, Adornee = part }, part)
		Render.draw(sg, design, true, 2) -- 120 x 84 is plenty at world size
	end
	local tagGui = new("BillboardGui", { Size = U(9, 0, 2.2, 0), StudsOffset = Vector3.new(0, 2.8 * k + 1.4, 0), LightInfluence = 0, MaxDistance = 80, Adornee = part }, part)
	wtext(tagGui, design.n or "", { Size = S(1, 0.5) })
	local info = Config.RARITIES[rarity]
	local mut = Config.MUTATIONS[part:GetAttribute("Mutation") or 1]
	if mut and MUT_FX[mut.name] then MUT_FX[mut.name](part) end
	if info then
		local prefix = mut and mut.name ~= "Normal" and mut.name:upper() .. " " or ""
		wtext(tagGui, prefix .. info.name:upper() .. "  $" .. Config.format(part:GetAttribute("Income") or info.rate) .. "/s", { Size = S(1, 0.42), Position = S(0, 0.52), TextColor3 = prefix ~= "" and mut.color or info.color })
	end
	local at = pen.CFrame:PointToObjectSpace(part.Position)
	local yaw = math.random() < 0.5 and 0 or math.pi
	animals[part] = { pen = pen, x = at.X, z = at.Z, y = 2.8 * k + 0.4, wait = math.random() * 3, seed = math.random() * 10, yaw = yaw, goal = yaw }
end
CollectionService:GetInstanceAddedSignal("ZooAnimal"):Connect(addAnimal)
for _, p in CollectionService:GetTagged("ZooAnimal") do addAnimal(p) end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for part, a in animals do
		if not part.Parent then
			animals[part] = nil
			continue
		end
		local hop = 0
		if a.tx then
			local dx, dz = a.tx - a.x, a.tz - a.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < 0.2 then
				a.tx, a.wait = nil, 1 + math.random() * 3
			else
				local move = math.min(dist, 3.5 * dt)
				a.x += dx / dist * move
				a.z += dz / dist * move
				hop = math.abs(math.sin(now * 8 + a.seed)) * 0.6
				a.goal = math.atan2(-dz, dx) -- heads are drawn on the left edge, which is the cutout's +X: point +X along the walk
			end
		else
			a.wait -= dt
			if a.wait <= 0 then
				a.tx, a.tz = (math.random() - 0.5) * a.pen.Size.X * 0.75, (math.random() - 0.5) * a.pen.Size.Z * 0.75
			end
		end
		local turn = (a.goal - a.yaw + math.pi) % (2 * math.pi) - math.pi
		a.yaw += turn * math.min(1, dt * 6)
		part.CFrame = a.pen.CFrame * CFrame.new(a.x, a.y + hop, a.z) * CFrame.Angles(0, a.yaw, 0)
	end
end)

----- server events everyone sees: admin boost events and countdowns as strips under the weather banner, and admin announcements -----
-- topStack holds the weather banner and these strips in one column at the top; toasts drop under whatever it shows
local topStack = scaled(new("Frame", { Name = "TopStack", AnchorPoint = Vector2.new(0.5, 0), Position = U(0.5, 0, 0, 6), Size = O(560, 320), BackgroundTransparency = 1 }, hud))
local topLayout = new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, topStack)
do
	local function strip(order, icon, col)
		local f = new("Frame", { Name = "Strip", Size = O(460, 56), BackgroundColor3 = col:Lerp(BLACK, 0.55), Visible = false, LayoutOrder = order }, topStack)
		round(f, 14)
		ink(f, 4)
		local face = round(new("Frame", { Name = "Face", Size = U(1, 0, 1, -5) }, f), 13)
		grad(face, { col:Lerp(WHITE, 0.35), col })
		studs(face, 0.7, nil, 13)
		sticker(face, icon, 44, O(32, 25), true)
		local title = label(face, "", 24, { Position = O(62, 0), Size = U(1, -170, 1, 0), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd })
		local time = label(face, "", 26, { Position = U(1, -112, 0, 0), Size = U(0, 100, 1, 0), TextXAlignment = RIGHT, TextColor3 = C.yellow })
		local pop = new("UIScale", { Name = "Pop" }, f)
		return { f = f, title = title, time = time, pop = pop }
	end
	local function show(s, on)
		if on == s.f.Visible then return end
		s.f.Visible = on
		if on then
			s.pop.Scale = 0.6
			TweenService:Create(s.pop, BACK, { Scale = 1 }):Play()
		end
	end
	local strips = {}
	for i, e in Config.BOOST_EVENTS do
		local s = strip(1 + i, e.icon, e.color)
		s.title.Text = e.text .. " FOR EVERYONE"
		strips[i] = s
		Zoo:GetAttributeChangedSignal(e.attr):Connect(function()
			local left = (Zoo:GetAttribute(e.attr) or 0) - workspace:GetServerTimeNow()
			if left > 1 then toast("ADMIN EVENT! " .. e.text .. " for everyone for " .. fmtTime(left) .. "!", e.color) end
		end)
	end
	local timer = strip(10, "clock", hex("FF4FD8"))
	local timerDone = true
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			for i, e in Config.BOOST_EVENTS do
				local left = (Zoo:GetAttribute(e.attr) or 0) - now
				show(strips[i], left > 0)
				strips[i].time.Text = fmtTime(left)
			end
			local ends = Zoo:GetAttribute("TimerEnds")
			local left = (ends or 0) - now
			if ends and left > 0 then
				timer.title.Text = Zoo:GetAttribute("TimerTitle") or "Countdown"
				timer.time.Text = fmtTime(math.ceil(left))
				timerDone = false
			elseif not timerDone then
				timerDone = true
				if ends then toast((Zoo:GetAttribute("TimerTitle") or "Countdown") .. ": NOW!", C.yellow) end
			end
			show(timer, ends ~= nil and left > 0)
			local h = topLayout.AbsoluteContentSize.Y
			toasts.Position = U(0.5, 0, 0, h > 4 and h + 14 or 4) -- toasts drop under the banners
			task.wait(0.25)
		end
	end)

	-- announcement: a big card that pops in over the upper middle of the screen for AnnounceSeconds
	local holder = scaled(new("Frame", { Name = "Announcement", AnchorPoint = Vector2.new(0.5, 0), Position = U(0.5, 0, 0.17, 0), Size = O(760, 150),
		BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, hud))
	local card0 = new("Frame", { Name = "Card", Size = S(1, 1), BackgroundColor3 = P.red[3] }, holder)
	round(card0, 18)
	ink(card0, 5)
	local face = round(new("Frame", { Name = "Face", Size = U(1, 0, 1, -7) }, card0), 17)
	grad(face, { hex("FF5A3D"), hex("D8000F") })
	studs(face, 0.7, nil, 17)
	rays(face, 190, O(86, 70), C.yellow)
	sticker(face, "newspaper", 104, O(86, 70), true)
	local head = label(face, "ANNOUNCEMENT", 26, { Position = O(160, 8), Size = O(560, 32), TextXAlignment = LEFT })
	goldText(head)
	local text = label(face, "", 30, { Position = O(160, 38), Size = O(580, 76), TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
		TextScaled = true }, true)
	new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 16 }, text)
	local from = label(face, "", 20, { Position = O(160, 112), Size = O(580, 26), TextXAlignment = RIGHT, TextColor3 = C.yellow })
	local pop = new("UIScale", { Name = "Pop" }, card0)
	local shownId = Zoo:GetAttribute("AnnounceId") -- an announcement made before you joined is not replayed
	Zoo:GetAttributeChangedSignal("AnnounceId"):Connect(function()
		local id = Zoo:GetAttribute("AnnounceId")
		if id == shownId then return end
		shownId = id
		text.Text = Zoo:GetAttribute("AnnounceText") or ""
		from.Text = "- " .. (Zoo:GetAttribute("AnnounceFrom") or "Admin")
		holder.Visible = true
		pop.Scale = 0.5
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(Zoo:GetAttribute("AnnounceSeconds") or 8, function()
			if shownId ~= id then return end -- a newer announcement took over
			local tw = TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.5 })
			tw.Completed:Once(function() if shownId == id then holder.Visible = false end end)
			tw:Play()
		end)
	end)
end

----- weather: the server picks random weathers (ZooWeather); every client tweens the sky, drops the falling code and shows the banner -----
do
	local banner = new("Frame", { Name = "Weather", Size = O(460, 78), BackgroundColor3 = BLACK, Visible = false, LayoutOrder = 1 }, topStack)
	round(banner, 16)
	ink(banner, 4)
	local face = round(new("Frame", { Name = "Face", Size = U(1, 0, 1, -5) }, banner), 15)
	local faceGrad = grad(face, P.lime)
	studs(face, 0.65, nil, 15)
	local iconSlot = new("Frame", { BackgroundTransparency = 1, Size = O(76, 72) }, face)
	local title = label(face, "", 30, { Position = O(76, 2), Size = O(374, 38), TextXAlignment = LEFT })
	local sub = label(face, "", 20, { Position = O(78, 42), Size = O(374, 26), TextXAlignment = LEFT, TextColor3 = C.yellow })

	-- falling code: columns of characters behind the HUD, bright at the bottom (the head) and fading up
	local rainGui = new("ScreenGui", { Name = "ZooWeatherRain", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -1, Enabled = false }, player:WaitForChild("PlayerGui"))
	local drops = {}
	for i = 1, 26 do
		local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 20, TextTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 1),
			Size = O(22, 340), TextYAlignment = Enum.TextYAlignment.Bottom }, rainGui)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, l)
		drops[i] = { l = l, x = 0, y = 2, v = 0 }
	end
	local function resetDrop(d, w, anywhere)
		local s = table.create(16, "")
		for k = 1, 16 do
			local n = math.random(#w.rain)
			s[k] = w.rain:sub(n, n)
		end
		d.l.Text, d.l.TextColor3 = table.concat(s, "\n"), w.color
		d.x, d.y, d.v = math.random(), anywhere and math.random() * 1.5 or 0, 0.25 + math.random() * 0.35
	end

	-- Lighting: remember each property's own value the first time a weather changes it, and tween back to it after
	local saved = {}
	local function applyLook(look)
		local goals = {}
		for inst, props in saved do goals[inst] = table.clone(props) end
		for name, props in look or {} do
			local inst = name == "Lighting" and Lighting or Lighting:FindFirstChild(name)
			if inst then
				saved[inst] = saved[inst] or {}
				goals[inst] = goals[inst] or {}
				for k, v in props do
					if saved[inst][k] == nil then saved[inst][k] = inst[k] end
					goals[inst][k] = v
				end
			end
		end
		for inst, g in goals do TweenService:Create(inst, TweenInfo.new(3, Enum.EasingStyle.Sine), g):Play() end
	end

	local weatherNow
	local function refresh()
		local w = Config.weather(Zoo:GetAttribute("Weather"))
		applyLook(w and w.look)
		banner.Visible = w ~= nil
		rainGui.Enabled = w ~= nil and w.rain ~= nil and not reduced
		if w then
			banner.BackgroundColor3 = w.color:Lerp(BLACK, 0.5)
			faceGrad.Color = ColorSequence.new(w.color:Lerp(WHITE, 0.4), w.color)
			iconSlot:ClearAllChildren()
			sticker(iconSlot, w.icon, 58, S(0.5, 0.5), true)
			title.Text = w.name:upper() .. " WEATHER"
			if w.rain then for _, d in drops do resetDrop(d, w, true) end end
			toast(w.name:upper() .. " WEATHER! " .. w.mutation .. " mutations are way more likely!", w.color)
		elseif weatherNow then
			toast("The weather cleared up.")
		end
		weatherNow = w
	end
	Zoo:GetAttributeChangedSignal("Weather"):Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function(dt)
		if not rainGui.Enabled then return end
		for _, d in drops do
			d.y += d.v * dt
			if d.y > 1.6 then resetDrop(d, weatherNow) end
			d.l.Position = S(d.x, d.y)
		end
	end)
	task.spawn(function()
		while true do
			if weatherNow then
				local left = (Zoo:GetAttribute("WeatherEnds") or 0) - workspace:GetServerTimeNow()
				sub.Text = string.format("%d%% %s mutation  ·  %s left", math.round(weatherNow.chance * 100), weatherNow.mutation, fmtTime(left))
			end
			task.wait(0.5)
		end
	end)
end

----- Admin Panel: only built for players the server marks Admin. Every button goes through Remotes.Admin, which re-checks admin on the server. -----
do
	local SLATE = { hex("7A8196"), hex("3A3F52"), hex("1A1D27") } -- idle tabs and off toggles
	local RED_RIM = { hex("FF6A5C"), hex("E0101C"), hex("8E0610") }
	local CW, CH = 744, 534 -- content area right of the tabs
	local built = false

	local function build()
		built = true
		local remote = Remotes:WaitForChild("Admin")
		local function call(action, payload)
			local ok, good, msg, data = pcall(remote.InvokeServer, remote, action, payload or {})
			if not ok then
				toast("Admin request failed", C.red)
				return false
			end
			if msg then toast(msg, good and C.cash or C.red) end
			return good, data
		end

		local body = window("Admin", "Admin Panel", "hammer", 1000, 600, RED_RIM)

		-- kit bits only the panel uses
		local function input(parent, size, pos, placeholder, text, digits)
			local box = new("TextBox", { Size = size, Position = pos, BackgroundColor3 = DISPLAY, PlaceholderText = placeholder or "", Text = text or "", Font = FONT,
				TextSize = 26, TextColor3 = WHITE, PlaceholderColor3 = hex("7D88A8"), ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd }, parent)
			round(box, 10)
			ink(box, 3)
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, box)
			if digits then
				box:GetPropertyChangedSignal("Text"):Connect(function()
					local clean = box.Text:gsub("%D", ""):sub(1, 6)
					if clean ~= box.Text then box.Text = clean end
				end)
			end
			return box
		end
		local function caption(parent, str, pos, w)
			return label(parent, str, 24, { Position = pos, Size = O(w or 300, 32), TextXAlignment = LEFT, TextColor3 = C.yellow })
		end
		local function title(parent, str)
			label(parent, str, 36, { Position = O(0, 0), Size = O(CW, 44) })
		end
		local function mark(b, on) -- the picked chip or tile gets a white outline
			b.Outline.Color = on and WHITE or BLACK
			b.Outline.Thickness = on and 5 or 4
		end
		local function scroller(parent, pos, size)
			local s = new("ScrollingFrame", { Position = pos, Size = size, BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("9A9A9A"),
				TopImage = "", BottomImage = "", CanvasSize = U(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, parent)
			return s
		end

		-- left: the tab column; right: one page per tab
		local tabs, pages, refresh = {}, {}, {}
		local active
		local function show(name)
			active = name
			for n, b in tabs do
				paint(b, n == name and P.green or SLATE)
				pages[n].Visible = n == name
			end
			if refresh[name] then task.spawn(refresh[name]) end
		end
		local TAB_LIST = { { "Players", "group" }, { "Give", "gift" }, { "Events", "cloud" }, { "Announce", "newspaper" }, { "Timer", "clock" }, { "Server", "gear" } }
		for i, t in TAB_LIST do
			tabs[t[1]] = button(body, t[1], SLATE, O(196, 60), O(100, 34 + (i - 1) * 72), function() show(t[1]) end,
				{ icon = t[2], iconSize = 38, text = 26, name = t[1] .. "Tab" })
			pages[t[1]] = new("Frame", { Name = t[1], Position = O(216, 0), Size = O(CW, CH), BackgroundTransparency = 1, Visible = false }, body)
		end
		label(body, "Only admins see this", 18, { Position = O(0, 34 + 6 * 72 - 20), Size = O(200, 24), TextColor3 = hex("9AA6C8") })
		new("Frame", { Name = "Divider", BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, Position = O(205, 0), Size = O(3, CH) }, body)

		----- Players -----
		local roster = {} -- last list from the server
		local target -- userId the Give tab acts on (nil = me)
		local renderGive -- set by the Give tab
		do
			local page = pages.Players
			local count = label(page, "", 30, { Position = O(0, 0), Size = O(500, 44), TextXAlignment = LEFT })
			button(page, "REFRESH", P.blue, O(150, 46), O(CW - 79, 22), function() task.spawn(refresh.Players) end, { text = 22 })
			local list = scroller(page, O(0, 56), O(CW, CH - 56))
			new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
			new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, list)
			local rows = {}
			local function row(p, i)
				local f = rows[p.userId]
				if f then f:Destroy() end
				f = round(new("Frame", { Size = U(1, 0, 0, 80), BackgroundColor3 = i % 2 == 1 and hex("2B3B70") or hex("24325F"), LayoutOrder = i }, list), 14)
				ink(f, 3, p.userId == player.UserId and C.yellow or BLACK)
				rows[p.userId] = f
				local av = round(new("ImageLabel", { Size = O(62, 62), Position = O(9, 9), BackgroundColor3 = hex("3A4A72"),
					Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.userId .. "&w=150&h=150" }, f), 31)
				ink(av, 3)
				local name = label(f, p.displayName, 26, { Position = O(82, 6), Size = O(250, 34), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd })
				if p.admin then name.TextColor3 = hex("FF8A80") end
				label(f, "@" .. p.name, 16, { Position = O(83, 38), Size = O(250, 20), TextXAlignment = LEFT, TextColor3 = hex("B8C2E0"), TextTruncate = Enum.TextTruncate.AtEnd })
				label(f, "$" .. Config.format(p.cash) .. "  ·  <font color=\"#6BFF3A\">+$" .. Config.format(p.rate) .. "/s</font>  ·  " .. p.animals .. " animals", 16,
					{ Position = O(83, 56), Size = O(260, 20), TextXAlignment = LEFT, TextColor3 = C.yellow })
				local x = 352
				local function act(str, pal, w, cb)
					local b = button(f, str, pal, O(w, 50), O(x + w / 2, 38), cb, { text = 20 })
					x += w + 8
					return b
				end
				act("GIVE", P.cyan, 84, function()
					target = p.userId
					show("Give")
				end)
				act("GO TO", P.blue, 86, function() call("player", { target = p.userId, op = "goto" }) end)
				act("BRING", P.purple, 88, function() call("player", { target = p.userId, op = "bring" }) end)
				local armed = false
				local kick
				kick = act("KICK", P.red, 78, function()
					if not armed then -- first press arms it, the second within 3 seconds kicks
						armed = true
						setLabel(kick, "SURE?")
						task.delay(3, function()
							armed = false
							if kick.Parent then setLabel(kick, "KICK") end
						end)
						return
					end
					if call("player", { target = p.userId, op = "kick" }) then task.delay(0.5, refresh.Players) end
				end)
				if p.admin then -- admins can't be kicked: a flat badge sits where KICK would be
					kick.Visible = false
					local badge = round(new("Frame", { AnchorPoint = CENTER, Position = O(x - 47, 38), Size = O(78, 40), BackgroundColor3 = P.red[2] }, f), 10)
					ink(badge, 3)
					label(badge, "ADMIN", 18, { Size = S(1, 1) })
				end
			end
			refresh.Players = function()
				local ok, data = call("players")
				if not ok or not data then return end
				roster = data.players
				for id, f in rows do f:Destroy() rows[id] = nil end
				for i, p in roster do row(p, i) end
				count.Text = #roster .. (#roster == 1 and " player" or " players") .. " in this server"
				if renderGive then renderGive() end
				if refresh.ServerInfo then refresh.ServerInfo(data.info) end
			end
			task.spawn(function() -- keep cash and income fresh while the tab is open
				while true do
					task.wait(4)
					if current == "Admin" and active == "Players" then refresh.Players() end
				end
			end)
		end

		----- Give -----
		do
			local page = pages.Give
			local s = scroller(page, O(0, 0), O(CW, CH))
			local c = new("Frame", { BackgroundTransparency = 1, Size = O(CW - 16, 640) }, s)
			local W = CW - 16

			-- who it goes to
			local bar = sheetPanel(c, O(W, 76), O(0, 4))
			local av = round(new("ImageLabel", { Size = O(58, 58), Position = O(10, 7), BackgroundColor3 = hex("3A4A72") }, bar), 29)
			ink(av, 3)
			caption(bar, "Giving to", O(80, 4), 200)
			local who = label(bar, "", 30, { Position = O(80, 30), Size = O(330, 38), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd })
			button(bar, "ME", P.blue, O(80, 50), O(W - 236, 36), function()
				target = nil
				renderGive()
			end, { text = 24 })
			button(bar, "PICK PLAYER", P.cyan, O(170, 50), O(W - 99, 36), function() show("Players") end, { text = 22 })
			local function targetId() return target or player.UserId end
			local function give(kind, a, b, cc)
				local ok = call("give", { target = targetId(), kind = kind, a = a, b = b, c = cc })
				if ok then task.delay(0.3, refresh.Players) end
				return ok
			end

			-- cash
			local y = 90
			caption(c, "CASH", O(0, y + 12), 90)
			local cash = input(c, O(200, 52), O(90, y + 2), "1m, 2.5b, -500k", "1m")
			for i, q in { "1M", "1B", "1T" } do
				button(c, q, P.gold, O(64, 50), O(314 + (i - 1) * 70, y + 28), function() cash.Text = q:lower() end, { text = 22 })
			end
			button(c, "GIVE", P.lime, O(110, 52), O(W - 170, y + 28), function() give("cash", cash.Text) end, { text = 24, vivid = true })
			button(c, "TAKE", P.red, O(100, 52), O(W - 55, y + 28), function()
				local n = cash.Text:gsub("^%-", "")
				give("cash", "-" .. n)
			end, { text = 24 })

			-- boosts
			y += 70
			caption(c, "BOOSTS", O(0, y + 12), 90)
			local minutes = input(c, O(110, 52), O(90, y + 2), "min", "30", true)
			label(c, "minutes", 20, { Position = O(206, y + 14), Size = O(80, 28), TextXAlignment = LEFT })
			button(c, "2x LUCK", P.gold, O(170, 52), O(380, y + 28), function() give("luck", minutes.Text) end, { icon = "clover", iconSize = 32, text = 22 })
			button(c, "2x MONEY", P.green, O(190, 52), O(570, y + 28), function() give("money", minutes.Text) end, { icon = "cash", iconSize = 32, text = 22, vivid = true })

			-- animal: rarity, mutation, stars
			y += 74
			new("Frame", { BackgroundColor3 = C.line, BackgroundTransparency = 0.6, Size = O(W, 2), Position = O(0, y - 8) }, c)
			caption(c, "ANIMAL", O(0, y), 200)
			local pick = { r = 6, m = 1, st = 5 }
			local function chipRow(yy, list, pals, key, w, text, icon)
				local bs = {}
				for i, e in list do
					local pal = pals[i]
					local rainbow = typeof(pal) == "ColorSequence"
					local b
					b = button(c, text(e, i), rainbow and P.pink or pal, O(w, 46), O(w / 2 + (i - 1) * (w + 8), yy + 23), function()
						pick[key] = i
						for j, o in bs do mark(o, j == i) end
					end, { text = 20, vivid = true, icon = icon, iconSize = 26 })
					if rainbow then b.Face.UIGradient.Color, b.Face.UIGradient.Rotation = pal, 0 end
					bs[i] = b
					mark(b, i == pick[key])
				end
			end
			chipRow(y + 34, Config.RARITIES, RARITY_PAL, "r", 112, function(e) return e.name:upper() end)
			chipRow(y + 88, Config.MUTATIONS, MUT_PAL, "m", 136, function(e) return e.name:upper() end)
			chipRow(y + 142, { 1, 2, 3, 4, 5 }, { P.gold, P.gold, P.gold, P.gold, P.gold }, "st", 76, function(_, i) return tostring(i) end, "star")
			button(c, "GIVE ANIMAL", P.lime, O(250, 54), O(W - 125, y + 165), function()
				give("animal", tostring(pick.r), tostring(pick.m), tostring(pick.st))
			end, { icon = "paw", iconSize = 34, text = 24, vivid = true })

			-- game passes (a flag in their save, no purchase)
			y += 206
			new("Frame", { BackgroundColor3 = C.line, BackgroundTransparency = 0.6, Size = O(W, 2), Position = O(0, y - 8) }, c)
			caption(c, "GAME PASSES", O(0, y), 300)
			label(c, "Test flag in their save, no Robux", 16, { Position = O(W - 300, y + 4), Size = O(300, 24), TextXAlignment = RIGHT, TextColor3 = hex("9AA6C8") })
			local passBtns = {}
			local PASS_ORDER = { { "VIP", "crown" }, { "Money2x", "cash" }, { "Luck2x", "clover" } }
			for i, pinfo in PASS_ORDER do
				local key = pinfo[1]
				local w = (W - 16) / 3
				passBtns[key] = button(c, key, SLATE, O(w, 52), O(w / 2 + (i - 1) * (w + 8), y + 58), function()
					local owned = passBtns[key]:GetAttribute("On")
					give(owned and "takepass" or "pass", key:lower())
				end, { icon = pinfo[2], iconSize = 36, text = 22 })
			end
			c.Size = O(W, y + 88)

			renderGive = function()
				local me = targetId()
				local p
				for _, r in roster do if r.userId == me then p = r end end
				if not p and target then target = nil return renderGive() end -- they left: back to me
				who.Text = p and p.displayName or player.DisplayName
				who.TextColor3 = me == player.UserId and WHITE or C.cash
				av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. me .. "&w=150&h=150"
				for key, b in passBtns do
					local on = p and p.passes[key] == true
					b:SetAttribute("On", on)
					paint(b, on and P.green or SLATE)
					setLabel(b, key .. (on and ": ON" or ": OFF"))
				end
			end
			refresh.Give = refresh.Players -- refreshing the roster also redraws this tab
		end

		----- Events: a tile per weather and per boost event, a duration, Start and Stop -----
		do
			local page = pages.Events
			title(page, "Events")
			local list = {}
			for _, w in Config.WEATHERS do table.insert(list, { name = w.name, text = w.name:upper(), icon = w.icon, color = w.color, weather = true }) end
			for _, e in Config.BOOST_EVENTS do table.insert(list, { name = e.name, text = e.text, icon = e.icon, color = e.color, attr = e.attr }) end
			local chosen = list[1]
			local row = new("Frame", { BackgroundTransparency = 1, Position = O(0, 58), Size = O(CW, 190) }, page)
			local gap = 18
			local tw = math.min(220, (CW - gap * (#list - 1)) / #list)
			local x0 = (CW - (#list * tw + (#list - 1) * gap)) / 2
			local tiles = {}
			for i, e in list do
				local col = e.color
				local pal = { col:Lerp(WHITE, 0.15), col:Lerp(BLACK, 0.5), col:Lerp(BLACK, 0.7) } -- bright top fading dark, like the reference tiles
				local b
				b = button(row, nil, pal, O(tw, 170), O(x0 + tw / 2 + (i - 1) * (tw + gap), 92), function()
					chosen = e
					for _, t in tiles do mark(t.b, t.e == e) end
				end, { r = 14, lip = 7 })
				rays(b.Face, 170, O(tw / 2, 62), WHITE)
				sticker(b.Face, e.icon, 84, O(tw / 2, 62), true)
				label(b.Face, e.text, 28, { Position = O(0, 106), Size = O(tw, 36) })
				local time = label(b.Face, "", 20, { Position = O(0, 138), Size = O(tw, 24), TextColor3 = C.yellow })
				local on = tag(b, "ON", O(tw - 14, 8), P.lime[3])
				on.Visible = false
				tiles[i] = { b = b, e = e, time = time, on = on }
				mark(b, i == 1)
			end
			caption(page, "Event Duration (seconds)", O(0, 266), CW).TextXAlignment = Enum.TextXAlignment.Center
			local dur = input(page, O(300, 64), O((CW - 300) / 2, 302), "150", "150", true)
			dur.TextSize, dur.TextXAlignment = 38, Enum.TextXAlignment.Center
			button(page, "START", P.green, O(230, 64), O(CW / 2 - 140, 420), function()
				call("event", { name = chosen.name, seconds = tonumber(dur.Text) or 0 })
			end, { text = 32, vivid = true })
			button(page, "STOP", P.red, O(230, 64), O(CW / 2 + 140, 420), function()
				call("event", { name = chosen.name, op = "stop" })
			end, { text = 32 })
			label(page, "Weather tiles boost their mutation. 2x events stack with players' own boosts.", 16,
				{ Position = O(0, 470), Size = O(CW, 22), TextColor3 = hex("9AA6C8") })
			task.spawn(function()
				while true do
					if current == "Admin" and active == "Events" then
						local now = workspace:GetServerTimeNow()
						for _, t in tiles do
							local left
							if t.e.weather then
								left = Zoo:GetAttribute("Weather") == t.e.name and (Zoo:GetAttribute("WeatherEnds") or 0) - now or 0
							else
								left = (Zoo:GetAttribute(t.e.attr) or 0) - now
							end
							t.on.Visible = left > 0
							t.time.Text = left > 0 and fmtTime(left) .. " left" or ""
						end
					end
					task.wait(0.5)
				end
			end)
		end

		----- Announce -----
		do
			local page = pages.Announce
			title(page, "Announcement")
			local box = input(page, O(CW, 170), O(0, 58), "Type a message for the whole server...", "")
			box.MultiLine, box.TextWrapped, box.TextTruncate = true, true, Enum.TextTruncate.None
			box.TextXAlignment, box.TextYAlignment = LEFT, Enum.TextYAlignment.Top
			box.UIPadding.PaddingTop, box.UIPadding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
			local counter = label(page, "0/150", 18, { Position = O(CW - 120, 232), Size = O(120, 24), TextXAlignment = RIGHT, TextColor3 = hex("9AA6C8") })
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if #box.Text > 150 then box.Text = box.Text:sub(1, 150) end
				counter.Text = #box.Text .. "/150"
			end)
			caption(page, "Show it for", O(0, 262), 200)
			local secs = 8
			local chips = {}
			for i, n in { 5, 8, 15, 30 } do
				chips[i] = button(page, n .. "s", P.blue, O(84, 48), O(196 + (i - 1) * 94, 278), function()
					secs = n
					for j, b in chips do mark(b, j == i) end
				end, { text = 22 })
				mark(chips[i], n == secs)
			end
			button(page, "SEND TO EVERYONE", P.green, O(340, 66), O(CW / 2, 380), function()
				if call("announce", { text = box.Text, seconds = secs }) then box.Text = "" end
			end, { icon = "newspaper", iconSize = 42, text = 28, vivid = true })
			label(page, "It pops up for every player with your name on it. Roblox's chat filter runs on it first.", 16,
				{ Position = O(0, 430), Size = O(CW, 22), TextColor3 = hex("9AA6C8") })
		end

		----- Timer: a countdown strip every player sees -----
		do
			local page = pages.Timer
			title(page, "Timer Countdown")
			caption(page, "Title", O(0, 66), 200)
			local name = input(page, O(CW - 140, 54), O(140, 58), "Event starts in", "Event starts in")
			caption(page, "Seconds", O(0, 140), 200)
			local secs = input(page, O(180, 54), O(140, 132), "60", "60", true)
			for i, q in { { "30s", 30 }, { "1m", 60 }, { "5m", 300 }, { "10m", 600 } } do
				button(page, q[1], P.blue, O(86, 50), O(380 + (i - 1) * 96, 159), function() secs.Text = tostring(q[2]) end, { text = 22 })
			end
			local status = label(page, "", 26, { Position = O(0, 220), Size = O(CW, 34), TextColor3 = C.yellow })
			button(page, "START", P.green, O(230, 64), O(CW / 2 - 140, 320), function()
				call("timer", { title = name.Text, seconds = tonumber(secs.Text) or 0 })
			end, { text = 32, vivid = true })
			button(page, "STOP", P.red, O(230, 64), O(CW / 2 + 140, 320), function() call("timer", { op = "stop" }) end, { text = 32 })
			label(page, "Shows under the weather banner for everyone, then says NOW! when it hits zero.", 16,
				{ Position = O(0, 370), Size = O(CW, 22), TextColor3 = hex("9AA6C8") })
			task.spawn(function()
				while true do
					if current == "Admin" and active == "Timer" then
						local left = (Zoo:GetAttribute("TimerEnds") or 0) - workspace:GetServerTimeNow()
						status.Text = left > 0 and ("Running: " .. (Zoo:GetAttribute("TimerTitle") or "") .. "  " .. fmtTime(math.ceil(left))) or "No countdown running"
					end
					task.wait(0.25)
				end
			end)
		end

		----- Server options -----
		do
			local page = pages.Server
			title(page, "Server Options")
			local panel = sheetPanel(page, O(CW, 120), O(0, 58))
			local stats = {}
			for i, k in { "Players", "Uptime", "Version" } do
				local x = (i - 1) * CW / 3
				caption(panel, k:upper(), O(x, 14), CW / 3).TextXAlignment = Enum.TextXAlignment.Center
				stats[k] = label(panel, "-", 40, { Position = O(x, 52), Size = O(CW / 3, 50) })
			end
			local weatherBtn
			weatherBtn = button(page, "RANDOM WEATHER: ON", P.green, O(CW, 64), O(CW / 2, 230), function()
				local on = not weatherBtn:GetAttribute("On")
				local ok, data = call("server", { op = "weather", on = on })
				if ok and data then refresh.ServerInfo(data) end
			end, { icon = "cloud", iconSize = 40, text = 26, vivid = true })
			button(page, "STOP ALL EVENTS", P.red, O((CW - 12) / 2, 64), O((CW - 12) / 4, 310), function() call("server", { op = "stopall" }) end,
				{ icon = "cross", iconSize = 36, text = 24 })
			button(page, "RESPAWN EVERYONE", P.blue, O((CW - 12) / 2, 64), O(CW - (CW - 12) / 4, 310), function() call("server", { op = "respawn" }) end,
				{ icon = "house", iconSize = 36, text = 24 })
			label(page, "Stop all ends the weather, 2x events and the countdown. Random weather off keeps the sky clear unless you start one.", 16,
				{ Position = O(0, 356), Size = O(CW, 44), TextColor3 = hex("9AA6C8"), TextWrapped = true })
			refresh.ServerInfo = function(info)
				if not info then return end
				stats.Players.Text = info.players .. "/" .. info.maxPlayers
				stats.Uptime.Text = fmtTime(info.uptime)
				stats.Version.Text = "v" .. info.version
				weatherBtn:SetAttribute("On", not info.weatherPaused)
				paint(weatherBtn, info.weatherPaused and SLATE or P.green)
				setLabel(weatherBtn, "RANDOM WEATHER: " .. (info.weatherPaused and "OFF" or "ON"))
			end
			refresh.Server = refresh.Players
		end

		refreshers.Admin = function() show(active or "Players") end
	end

	-- the hammer button sits under the left menu, for admins only (above it, Roblox's chat window would eat its clicks)
	local adminBtn = railButton(leftBar, 5, "ADMIN", P.red, function()
		if not built then build() end
		open("Admin")
	end, { icon = "hammer", iconSize = 46, text = 26, name = "Admin" })
	local function update()
		local on = player:GetAttribute("Admin") == true
		adminBtn.Visible = on
		if not on and current == "Admin" then close("Admin") end
	end
	player:GetAttributeChangedSignal("Admin"):Connect(update)
	update()
end

----- plot signs: each plot's upgrade sign and draw easel show live info for whoever owns it -----
do
	local GREY = hex("6B7280")
	local function face(part)
		for _, g in part:GetChildren() do if g:IsA("SurfaceGui") then g:Destroy() end end
		return new("SurfaceGui", { Name = "SignGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
			LightInfluence = 0, MaxDistance = 150 }, part)
	end
	local function bind(plot)
		local sign, easel = plot:WaitForChild("UpgradeSign"), plot:WaitForChild("Easel")
		local sg = face(sign)
		local pad = new("Frame", { BackgroundTransparency = 1, Size = U(1, -28, 1, -20), Position = O(14, 10) }, sg)
		wtext(pad, "UPGRADE ZOO", { Size = S(1, 0.3) })
		local sub = wtext(pad, "", { Size = S(1, 0.17), Position = S(0, 0.32), TextColor3 = C.cash })
		local bar = round(new("Frame", { Size = S(1, 0.42), Position = S(0, 0.56) }, pad), 14)
		local barGrad = grad(bar, P.calm) -- same calm green as every buy button
		ink(bar, 3)
		sticker(bar, "upgrade", 58, U(0, 42, 0.5, 0))
		local cost = wtext(bar, "", { Size = U(1, -86, 0.76, 0), Position = U(0, 78, 0.12, 0) })
		local esg = face(easel)
		local function refresh()
			local owner = plot:GetAttribute("Owner")
			local cap, lvl, nextCost = plot:GetAttribute("Capacity"), plot:GetAttribute("CapLevel"), plot:GetAttribute("NextCost")
			if owner and cap then
				sub.Text, sub.TextColor3 = string.format("Level %d  ·  %d animals", (lvl or 0) + 1, cap), C.cash
				bar.Visible = true
				local maxed = (nextCost or 0) <= 0
				cost.Text = maxed and "MAXED" or "$" .. Config.format(nextCost)
				bar.BackgroundColor3, barGrad.Enabled = maxed and GREY or WHITE, not maxed
			else
				sub.Text, sub.TextColor3 = "Empty plot", rgb(190, 196, 206)
				bar.Visible = false
			end
			-- easel: the owner's newest drawing, or an invitation to draw
			esg:ClearAllChildren()
			local ok, design = false, nil
			local latest = plot:GetAttribute("Latest")
			if owner and latest then ok, design = pcall(HttpService.JSONDecode, HttpService, latest) end
			if ok and design then
				local holder = new("Frame", { BackgroundTransparency = 1, Size = U(1, -24, 1, -64), Position = O(12, 10) }, esg)
				Render.draw(holder, design, true, 3)
				wtext(esg, design.n or "", { Size = U(1, -24, 0, 44), Position = U(0, 12, 1, -52) })
			else
				sticker(esg, "pencil", 92, S(0.5, 0.38))
				wtext(esg, "DRAW AN ANIMAL!", { Size = U(1, -30, 0, 46), Position = U(0, 15, 1, -66), TextColor3 = C.yellow })
			end
		end
		for _, a in { "Owner", "Capacity", "CapLevel", "NextCost", "Latest" } do plot:GetAttributeChangedSignal(a):Connect(refresh) end
		refresh()
	end
	for _, plot in World.Plots:GetChildren() do task.spawn(bind, plot) end
end

----- Top Earners board: one row per player (max 7), rank badge, avatar, name, $/s. Fixed text sizes, not TextScaled. -----
do
	local board = World:WaitForChild("Showcase"):WaitForChild("Board")
	local header = World.Showcase:WaitForChild("BoardHeader")
	local BADGE = { hex("FFC81E"), hex("D5DCE6"), hex("E0904A") } -- gold, silver, bronze
	local ROW_A, ROW_B = hex("2A3656"), hex("243050")
	local function surface(part, face, ppu)
		return new("SurfaceGui", { Name = "BoardGui", Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = ppu,
			LightInfluence = 0, MaxDistance = 500 }, part)
	end
	local lists = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		-- 23 px/stud: the layout below is designed at 990 x 570 px, which is the board's 42.9 x 24.7 stud screen
		local t = surface(header, face, 23)
		label(t, "TOP EARNERS", 92, { Size = S(1, 1), TextYAlignment = Enum.TextYAlignment.Center }, true)
		goldText(t.Label)
		local s = surface(board, face, 23)
		local list = new("Frame", { BackgroundTransparency = 1, Size = U(1, -40, 1, -24), Position = O(20, 12) }, s)
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		table.insert(lists, { list = list })
	end
	local function refresh()
		local ok, rows = pcall(HttpService.JSONDecode, HttpService, board:GetAttribute("Top") or "[]")
		if not ok then rows = {} end
		for _, l in lists do
			for _, c in l.list:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
			for i = 1, 7 do -- all 7 slots always show; open ones are dimmed, so the board never looks half-built
				local r = rows[i] or { 0, "-", nil }
				-- 7 rows of 72 + 6 gaps of 6 fill the 546 px list exactly (the server caps players at 7)
				local row = round(new("Frame", { Size = U(1, 0, 0, 72), BackgroundColor3 = i % 2 == 1 and ROW_A or ROW_B, LayoutOrder = i }, l.list), 14)
				if r[1] == player.UserId then ink(row, 3, C.yellow) end
				local badge = round(new("Frame", { Size = O(58, 58), Position = O(10, 7), BackgroundColor3 = BADGE[i] or hex("4A5A82") }, row), 29)
				ink(badge, 3)
				label(badge, tostring(i), 36, { Size = S(1, 1) }, true)
				local av = round(new("ImageLabel", { Size = O(58, 58), Position = O(80, 7), BackgroundColor3 = hex("3A4A72"),
					Image = r[3] and "rbxthumb://type=AvatarHeadShot&id=" .. r[1] .. "&w=150&h=150" or "" }, row), 29)
				ink(av, 3)
				label(row, r[2], 40, { Size = U(1, -410, 1, 0), Position = O(154, 0), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, true)
				label(row, r[3] and "$" .. Config.format(r[3]) .. "/s" or "", 40, { Size = O(240, 72), Position = U(1, -256, 0, 0), TextXAlignment = RIGHT, TextColor3 = C.cash }, true)
				if not r[3] then row.BackgroundTransparency, badge.BackgroundTransparency = 0.5, 0.55 end
			end
		end
	end
	board:GetAttributeChangedSignal("Top"):Connect(refresh)
	refresh()
end

----- Animal race: pick an animal at the pad inside the gate, ride its cutout round the outskirts, the winner spins the prize wheel -----
do
	local R = Config.RACE
	local race = { phase = "idle", ends = 0, queue = {}, racers = {}, min = R.MIN_PLAYERS, max = R.MAX_PLAYERS, laps = R.LAPS }
	local function mine(list) return table.find(list, player.UserId) ~= nil end
	local function ordinal(n)
		local s = (n % 100 >= 11 and n % 100 <= 13) and "th" or ({ "st", "nd", "rd" })[n % 10] or "th"
		return n .. s
	end

	-- the window: your animals on the left, the one you'll ride and the queue on the right
	local body = window("Race", "Animal Race", "rocket", 900, 600)
	local info = label(body, "", 24, { Size = O(860, 30), TextXAlignment = LEFT })
	label(body, "Two laps round the zoo. Everyone runs at the same speed: fly through the boost rings to win!", 18,
		{ Position = O(0, 34), Size = O(860, 24), TextXAlignment = LEFT, TextColor3 = hex("BFD3FF") })
	local list = new("ScrollingFrame", { Position = O(0, 70), Size = O(598, 456), BackgroundTransparency = 1, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("9A9A9A"),
		TopImage = "", BottomImage = "", BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = U() }, body)
	new("UIGridLayout", { CellSize = O(138, 150), CellPadding = O(8, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }, list)
	local empty = new("Frame", { BackgroundTransparency = 1, Position = O(0, 160), Size = O(598, 200), Visible = false }, body)
	label(empty, "Draw an animal to race on!", 32, { Position = O(0, 20), Size = O(598, 44) })
	button(empty, "DRAW ONE", P.gold, O(240, 70), O(299, 120), function() open("Editor") end, { icon = "pencil", iconSize = 50, text = 30 })

	local _, pface = card(body, P.purple, O(250, 456), O(610, 70), 16)
	label(pface, "YOUR RACER", 22, { Position = O(0, 8), Size = O(250, 28) })
	local thumb = new("Frame", { BackgroundTransparency = 1, Position = O(15, 42), Size = O(220, 154) }, pface)
	local pName = label(pface, "", 28, { Position = O(0, 202), Size = O(250, 36) }, true)
	local status = label(pface, "", 20, { Position = O(10, 244), Size = O(230, 70), TextWrapped = true })
	local selected
	local joinBtn = button(pface, "JOIN RACE", P.lime, O(220, 66), O(125, 350), function()
		if selected then Remotes.RaceJoin:FireServer(selected) end
	end, { text = 30 })
	local leaveBtn = button(pface, "LEAVE QUEUE", P.red, O(220, 52), O(125, 414), function() Remotes.RaceLeave:FireServer() end, { text = 22 })

	local function find(id)
		for _, a in state.animals do if a.id == id then return a end end
		return nil
	end
	local function ensureSelected()
		if selected and not find(selected) then selected = nil end
		if not selected then -- default: the best earner, it looks the part
			local best
			for _, a in state.animals do if not best or Config.income(a) > Config.income(best) then best = a end end
			selected = best and best.id
		end
		return selected and find(selected)
	end
	refreshers.Race = function()
		for _, ch in list:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
		ensureSelected()
		for i, a in state.animals do
			local b = cellButton(list, nil, RARITY_PAL[a.r], function()
				selected = a.id
				refreshers.Race()
			end, { lip = 5 }, -a.r * 100 + i)
			Render.draw(display(b.Face, O(120, 84), O(9, 8)), a.d, true, 3)
			label(b.Face, a.d.n, 20, { Position = O(0, 96), Size = O(138, 24) })
			label(b.Face, Config.RARITIES[a.r].name:upper(), 16, { Position = O(0, 120), Size = O(138, 20), TextColor3 = C.yellow })
			if a.id == selected then
				b.Outline.Color = C.yellow
				b.Outline.Thickness = 6
			end
		end
		empty.Visible = #state.animals == 0
		local a = selected and find(selected)
		thumb:ClearAllChildren()
		if a then Render.draw(display(thumb, O(220, 154), O(0, 0), 12), a.d, true, 3) end
		pName.Text = a and a.d.n or "-"
		local inQueue, racing = mine(race.queue), mine(race.racers)
		joinBtn.Visible = not inQueue and not racing and a ~= nil
		leaveBtn.Visible = inQueue or racing
		setLabel(leaveBtn, racing and "QUIT RACE" or "LEAVE QUEUE")
		local n = #race.queue
		if racing then
			status.Text = "You're racing!"
		elseif inQueue then
			status.Text = race.phase == "racing" and "Queued for the next race" or string.format("In the queue: %d/%d\nNeeds %d to start", n, race.max, race.min)
		else
			status.Text = n > 0 and string.format("%d waiting to race", n) or "Pick an animal and join!"
		end
		info.Text = race.phase == "racing" and string.format('Race on! <font color="#FFE600">%d</font> racing right now', #race.racers)
			or race.phase == "countdown" and "A race is starting!"
			or string.format('Queue <font color="#FFE600">%d/%d</font>   ·   starts with %d racer%s', n, race.max, race.min, race.min == 1 and "" or "s")
	end

	-- walking out through the gate asks once: join the next race on your racer? (CHANGE opens the full picker)
	local RL = require(Zoo:WaitForChild("RaceLayout"))
	local ask = window("RaceAsk", "Race Time!", "rocket", 620, 400)
	label(ask, "Would you like to join the next race?", 30, { Position = O(0, 4), Size = O(580, 40) })
	local askThumb = new("Frame", { BackgroundTransparency = 1, Position = O(20, 64), Size = O(200, 140) }, ask)
	local askName = label(ask, "", 28, { Position = O(240, 76), Size = O(330, 36), TextXAlignment = LEFT }, true)
	local askInfo = label(ask, "", 20, { Position = O(240, 116), Size = O(330, 50), TextXAlignment = LEFT, TextWrapped = true, TextColor3 = hex("BFD3FF") })
	local change = button(ask, "CHANGE", P.blue, O(150, 46), O(315, 190), function() open("Race") end, { text = 22 })
	local yes = button(ask, "YES, RACE!", P.lime, O(250, 72), O(150, 284), function()
		if selected then Remotes.RaceJoin:FireServer(selected) end
		close("RaceAsk")
	end, { text = 30 })
	button(ask, "NO THANKS", P.red, O(220, 64), O(430, 284), function() close("RaceAsk") end, { text = 26 })
	refreshers.RaceAsk = function()
		local a = ensureSelected()
		askThumb:ClearAllChildren()
		if a then Render.draw(display(askThumb, O(200, 140), O(0, 0), 12), a.d, true, 3) end
		askName.Text = a and a.d.n or "No animals yet!"
		local n = #race.queue
		askInfo.Text = not a and "Draw an animal at any easel to race on it." or race.phase == "racing" and "A race is on: you'll be in the next one."
			or n > 0 and string.format("%d already waiting. Two laps, boost rings, prizes!", n) or "Two laps round the zoo. Win a spin of the prize wheel!"
		yes.Visible, change.Visible = a ~= nil, a ~= nil
	end
	task.spawn(function()
		local half, centre = RL.GATE_ZONE.size / 2, RL.GATE_ZONE.centre
		local inside, lastAsk = false, -100
		while true do
			task.wait(0.2)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local d = hrp and hrp.Position - centre
			local now = d ~= nil and math.abs(d.X) < half.X and math.abs(d.Y) < half.Y and math.abs(d.Z) < half.Z
			-- only on the way out (heading away from the park, -Z), and not again for a while if they said no
			if now and not inside and hrp.AssemblyLinearVelocity.Z < -2 and not current and os.clock() - lastAsk > 20
				and not mine(race.queue) and not mine(race.racers) then
				lastAsk = os.clock()
				open("RaceAsk")
			end
			inside = now
		end
	end)

	-- race HUD: place and lap pill at the top, big pop-up words in the middle (countdown, GO!, BOOST!, your place)
	local hudR = scaled(new("Frame", { Name = "RaceHud", AnchorPoint = Vector2.new(0.5, 0), Position = U(0.5, 0, 0, 70), Size = O(440, 66), BackgroundTransparency = 1, Visible = false }, gui))
	local pill = round(new("Frame", { Size = S(1, 1), BackgroundColor3 = WHITE }, hudR), 18)
	grad(pill, P.purple)
	ink(pill, 4)
	local placeL = label(pill, "", 36, { Position = O(18, 6), Size = O(200, 50), TextXAlignment = LEFT }, true)
	goldText(placeL)
	local lapL = label(pill, "", 30, { Position = O(220, 8), Size = O(200, 46), TextXAlignment = RIGHT }, true)
	local big = scaled(new("Frame", { Name = "RacePop", AnchorPoint = CENTER, Position = S(0.5, 0.36), Size = O(800, 190), BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, gui))
	local bigScale = new("UIScale", { Name = "Pop" }, big)
	local bigL = label(big, "", 130, { Size = S(1, 1) }, true)
	local popId = 0
	local function pop(text, color, hold)
		popId += 1
		local id = popId
		bigL.Text, bigL.TextColor3, big.Visible, bigScale.Scale = text, color or WHITE, true, 0.3
		TweenService:Create(bigScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(hold or 0.8, function() if popId == id then big.Visible = false end end)
	end
	local camera = workspace.CurrentCamera
	local function zoom(seconds) -- speed kick: widen the view, then ease back over the boost
		TweenService:Create(camera, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { FieldOfView = 84 }):Play()
		task.delay(0.15, function() TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { FieldOfView = 70 }):Play() end)
	end

	local shown
	Remotes.RaceState.OnClientEvent:Connect(function(s)
		local before = race.phase
		race = s
		local racing = mine(s.racers)
		hudR.Visible = racing and s.phase == "racing"
		if racing and current == "Race" then close("Race") end
		if racing and s.phase == "racing" and before == "countdown" then pop("GO!", C.cash) end
		if not racing then shown = nil end
		if current == "Race" then refreshers.Race() end
	end)
	RunService.Heartbeat:Connect(function()
		if race.phase ~= "countdown" or not mine(race.racers) then return end
		local left = math.ceil(race.ends - workspace:GetServerTimeNow())
		if left >= 1 and left ~= shown then
			shown = left
			pop(tostring(left), C.yellow, 0.9)
		end
	end)
	Remotes.RaceInfo.OnClientEvent:Connect(function(i)
		if i.place then
			placeL.Text = ordinal(i.place) .. " / " .. i.count
			lapL.Text = "LAP " .. i.lap .. "/" .. i.laps
		end
		if i.boost then
			pop("BOOST!", hex("3DF5FF"), 0.6)
			zoom(i.boost)
		end
		if i.mud then toast("Mud! Slowed down...", hex("D9A066")) end
		if i.finished then
			hudR.Visible = false
			pop(ordinal(i.finished) .. " PLACE!", i.finished == 1 and C.yellow or WHITE, 2)
		end
	end)

	-- prize wheel: five spokes on a dial, a pointer at the top. The server has already paid; this plays it back.
	local wb = window("Wheel", "Prize Wheel", "star", 660, 600)
	local n = #R.WHEEL
	local dial = new("Frame", { AnchorPoint = CENTER, Position = O(310, 205), Size = O(370, 370), BackgroundColor3 = WHITE }, wb)
	round(dial, 185)
	ink(dial, 6)
	grad(dial, P.blue)
	for i, s in R.WHEEL do
		local arm = new("Frame", { AnchorPoint = CENTER, Position = S(0.5, 0.5), Size = S(1, 1), BackgroundTransparency = 1, Rotation = (i - 1) * 360 / n }, dial)
		local slab = round(new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = U(0.5, 0, 0, 12), Size = O(96, 112), BackgroundColor3 = hex(s.color) }, arm), 16)
		ink(slab, 4)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, hex("BBBBBB")) }, slab)
		label(slab, s.label, 20, { Position = O(4, 8), Size = U(1, -8, 0, 60), TextScaled = true })
	end
	local hub = round(new("Frame", { AnchorPoint = CENTER, Position = S(0.5, 0.5), Size = O(130, 130), BackgroundColor3 = WHITE }, dial), 65)
	grad(hub, P.gold)
	ink(hub, 5)
	sticker(hub, "star", 80, S(0.5, 0.5))
	local pointer = new("Frame", { AnchorPoint = CENTER, Position = O(310, 24), Size = O(40, 40), Rotation = 45, BackgroundColor3 = WHITE, ZIndex = 3 }, wb)
	round(pointer, 6)
	ink(pointer, 4)
	grad(pointer, P.red)
	local result = label(wb, "", 44, { Position = O(0, 396), Size = O(620, 54), TextColor3 = C.cash })
	local collect = button(wb, "COLLECT", P.lime, O(240, 70), O(310, 486), function() close("Wheel") end, { text = 32 })
	Remotes.RaceSpin.OnClientEvent:Connect(function(i, text)
		result.Text, collect.Visible, dial.Rotation = "", false, 0
		if current ~= "Wheel" then open("Wheel") end
		local slice = 360 / n
		local target = -(i - 1) * slice - 360 * 5 + (math.random() - 0.5) * slice * 0.6
		local tw = TweenService:Create(dial, TweenInfo.new(4.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = target })
		tw.Completed:Once(function()
			result.Text, collect.Visible = text, true
			pop("YOU WON!", C.yellow, 1.2)
		end)
		tw:Play()
	end)

	-- the cutouts racers ride (built by the server, drawn here), hopping while they run; boost rings turn slowly
	local mounts, rings = {}, {}
	local function addMount(part)
		if mounts[part] then return end
		local ok, design = pcall(HttpService.JSONDecode, HttpService, part:GetAttribute("Design") or "")
		if not ok or typeof(design) ~= "table" then return end
		mounts[part] = { seed = math.random() * 10 }
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local sg = new("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.25, MaxDistance = 300, Adornee = part }, part)
			Render.draw(sg, design, true, 2)
		end
		local weld = part:WaitForChild("MountWeld", 5)
		if weld and mounts[part] then mounts[part].weld, mounts[part].base = weld, weld.C0 end
	end

	-- driving your own car: the VehicleSeat reads WASD, arrows, a gamepad or the thumbstick as throttle and steer.
	-- It pulls away slowly and builds up to the server's "Top" speed, coasts down when you let go, and steers like a
	-- car: the wheel follows the stick with a lag and you can't turn on the spot. Bumping into something costs speed.
	local function drive(car)
		if car:GetAttribute("Owner") ~= player.UserId then return end
		local body, seat = car:WaitForChild("Body", 5), car:WaitForChild("Seat", 5)
		local lv, ao = body and body:WaitForChild("LinearVelocity", 5), body and body:WaitForChild("AlignOrientation", 5)
		if not (lv and ao and seat) then return end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end
		local look = body.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local speed, steer = 0, 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not car.Parent then
				conn:Disconnect()
				if hum and hum.Parent then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
				return
			end
			if body.Anchored then return end -- still on the grid
			local top = car:GetAttribute("Top") or 0
			local throttle, input = seat.ThrottleFloat, seat.SteerFloat
			if RunService:IsStudio() then -- shortcut: test hook so a script can drive in Studio playtests
				throttle, input = car:GetAttribute("TestThrottle") or throttle, car:GetAttribute("TestSteer") or input
			end
			steer += (input - steer) * math.min(1, dt / R.STEER_LAG)
			if speed > top then
				speed = math.max(top, speed - R.BRAKE * dt) -- mud, or a boost running out
			elseif throttle > 0 then
				local a = top > R.TOP_SPEED and R.BOOST_ACCEL or R.ACCEL
				speed = math.min(top, speed + a * dt * (1 - 0.6 * math.max(speed, 0) / top)) -- strong pull at first, easing off near the top
			elseif throttle < 0 then
				speed = math.max(-R.REVERSE_SPEED, speed - R.BRAKE * dt)
			else
				speed -= math.sign(speed) * math.min(math.abs(speed), R.COAST * dt)
			end
			local fwd = CFrame.Angles(0, yaw, 0).LookVector
			local actual = body.AssemblyLinearVelocity:Dot(fwd)
			if speed > 6 and actual < speed - 8 then speed = math.max(actual + 3, 0) end -- hit something: lose the speed
			-- no turning on the spot: full turn rate once rolling, and only a little when crawling (enough to nose out of a crash)
			local grip = math.clamp(math.abs(speed) / 14, throttle ~= 0 and 0.3 or 0, 1)
			yaw -= steer * math.rad(R.TURN) * grip * dt * (speed >= 0 and 1 or -1)
			local rot = CFrame.Angles(0, yaw, 0)
			ao.CFrame = rot
			lv.PlaneVelocity = Vector2.new(rot.LookVector.X, rot.LookVector.Z) * speed
		end)
	end
	local function addRing(m)
		if rings[m] then return end
		local centre = m:GetPivot() * CFrame.new(0, 5.1, 0) -- the hoop's centre (boost_ring(): R + r/2)
		local parts = {}
		for _, k in { "boost", "boostLight" } do
			local p = m:WaitForChild(k, 5)
			if p then parts[p] = centre:ToObjectSpace(p.CFrame) end
		end
		rings[m] = { centre = centre, parts = parts }
	end
	for tagName, fn in { RaceMount = addMount, BoostRing = addRing, RaceCar = drive } do
		CollectionService:GetInstanceAddedSignal(tagName):Connect(function(o) task.spawn(fn, o) end)
		CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(o) mounts[o], rings[o] = nil, nil end)
		for _, o in CollectionService:GetTagged(tagName) do task.spawn(fn, o) end
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for part, m in mounts do
			if not part.Parent then mounts[part] = nil continue end
			local hrp = m.weld and m.weld.Part0
			if hrp then
				local moving = hrp.AssemblyLinearVelocity.Magnitude > 3
				local s = math.sin(t * 9 + m.seed)
				m.weld.C0 = m.base * CFrame.new(0, moving and math.abs(s) * 0.35 or 0, 0) * CFrame.Angles(0, 0, moving and s * 0.04 or 0)
			end
		end
		local turn = CFrame.Angles(0, 0, t * 0.8)
		for m, r in rings do
			for p, rel in r.parts do p.CFrame = r.centre * turn * rel end
		end
	end)
end

----- intro cinematic -----
local function intro()
	local cam = workspace.CurrentCamera
	hud.Visible = false
	-- own ScreenGui that ignores the top-bar inset, so the letterbox bars reach the real screen edges
	local introGui = new("ScreenGui", { Name = "ZooIntro", IgnoreGuiInset = true, DisplayOrder = 20, ResetOnSpawn = false }, player.PlayerGui)
	local layer = new("Frame", { Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 50 }, introGui)
	new("Frame", { Size = S(1, 0.1), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 51 }, layer)
	new("Frame", { Size = S(1, 0.1), Position = S(0, 0.9), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 51 }, layer)
	local caption = wtext(layer, "", { AnchorPoint = CENTER, Position = S(0.5, 0.76), Size = S(0.8, 0.14), ZIndex = 52, TextColor3 = C.yellow })
	local pop = new("UIScale", {}, caption)
	-- each caption's icon sits above it; scaled() keeps it the same size on every screen
	local iconBox = scaled(new("Frame", { AnchorPoint = CENTER, Position = S(0.5, 0.6), Size = O(96, 96), BackgroundTransparency = 1, ZIndex = 52 }, layer))
	local iconPop = new("UIScale", {}, iconBox)
	local fade = new("Frame", { Size = S(1, 1), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 53 }, layer)
	local skipped = false
	local skipBox = scaled(new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = U(1, -16, 1, -16), Size = O(150, 56), BackgroundTransparency = 1, ZIndex = 54 }, layer))
	button(skipBox, "SKIP", P.orange, S(1, 1), S(0.5, 0.5), function() skipped = true end, { text = 26, icon = "skip", iconSize = 34 })
	rescale()

	local V = Vector3.new
	local plots = World.Plots
	local p1 = plots.Plot1.Pen.CFrame
	local function look(from, lookAt) return CFrame.lookAt(from, lookAt) end
	local shots = {
		{ "Welcome to Draw a Zoo!", look(V(-60, 70, 150), V(0, 5, 0)), look(V(70, 55, 125), V(0, 5, 0)), 4, "paw" },
		{ "Draw animals!", look(V(-20, 7, 36), V(0, 4, 0)), look(V(20, 7, 36), V(0, 4, 0)), 3.5, "pencil" },
		{ "Collect money!", look((p1 * CFrame.new(-12, 10, -48)).Position, (p1 * CFrame.new(0, 10, 10)).Position), look((p1 * CFrame.new(8, 7, -28)).Position, (p1 * CFrame.new(0, 10, 10)).Position), 3.5, "cash" },
		-- bird's-eye orbit over the whole park; a function shot gets 0..1 and returns the camera
		{ "Upgrade your zoo!", function(a)
			local ang = math.rad(25 + 120 * a)
			return look(V(math.sin(ang) * 115, 175, math.cos(ang) * 115), V(0, 0, 0))
		end, nil, 5, "upgrade" },
	}
	for _, shot in shots do
		if skipped then break end
		caption.Text = shot[1]
		pop.Scale = 0.5
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		iconBox:ClearAllChildren()
		iconPop = new("UIScale", { Scale = 0.3 }, iconBox)
		sticker(iconBox, shot[5], 96, S(0.5, 0.5))
		TweenService:Create(iconPop, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local t, dur = 0, shot[4]
		while t < dur and not skipped do
			cam.CameraType = Enum.CameraType.Scriptable -- re-asserted every frame: the default camera script resets it on spawn
			local a = t / dur
			cam.CFrame = if typeof(shot[2]) == "function" then shot[2](a) else shot[2]:Lerp(shot[3], a * a * (3 - 2 * a))
			fade.BackgroundTransparency = math.clamp(math.min(t, dur - t) / 0.35, 0, 1)
			t += RunService.RenderStepped:Wait()
		end
	end
	cam.CameraType = Enum.CameraType.Custom
	-- hand back to the player looking straight at their own zoo: behind the character, on the pad-to-pen line
	RunService.RenderStepped:Wait() -- the camera module reads CFrame after it has taken over again
	local head = player.Character and player.Character:FindFirstChild("Head")
	for _, plot in plots:GetChildren() do
		if head and plot:GetAttribute("Owner") == player.UserId and plot:FindFirstChild("Pad") and plot:FindFirstChild("Pen") then
			local d = plot.Pen.Position - plot.Pad.Position
			d = V(d.X, 0, d.Z).Unit
			cam.CFrame = CFrame.lookAt(head.Position - d * 20 + V(0, 8, 0), head.Position)
			-- the camera module keeps its own zoom, so pin min = max for a few frames to land at this distance
			local minZ, maxZ = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
			player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 21.5, 21.5
			for _ = 1, 3 do RunService.RenderStepped:Wait() end
			player.CameraMinZoomDistance, player.CameraMaxZoomDistance = minZ, maxZ
		end
	end
	introGui:Destroy()
	hud.Visible = true
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
rescale()
-- The server sets IntroDone once the save has loaded (and back to false after /reset).
-- The intro only counts as seen when it finishes here, so leaving mid-intro replays it next time.
local introPlaying = false
local function checkIntro()
	local done = player:GetAttribute("IntroDone")
	if done == nil or introPlaying then return end
	if done then
		hud.Visible = true
		return
	end
	introPlaying = true
	intro()
	introPlaying = false
	Remotes.IntroDone:FireServer()
end
hud.Visible = false -- hidden until the server says whether this player still needs the intro
task.delay(10, function() if player:GetAttribute("IntroDone") == nil then hud.Visible = true end end)
player:GetAttributeChangedSignal("IntroDone"):Connect(checkIntro)
checkIntro()
introDone = true
if pendingOffline then showOffline(pendingOffline) end
