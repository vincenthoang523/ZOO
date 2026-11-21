--!strict
-- Config: every tunable number for Draw a Zoo lives here.
local rgb = Color3.fromRGB
local Config = {}

Config.W, Config.H = 240, 168 -- drawing grid
Config.OLD_GRIDS = { { 40, 28 }, { 80, 56 }, { 120, 84 } } -- grids of older saves; Render.decode scales them up
Config.MAX_DRAWING_CHARS = 60000 -- longest compressed drawing the server accepts (a normal animal is 1-5 K); keeps saves and attributes small

-- index 1 is the grey "unpainted" colour; the rest are the paint swatches
Config.PALETTE = {
	rgb(196, 200, 208),
	rgb(125, 28, 40), rgb(222, 60, 60), rgb(244, 84, 140), rgb(250, 110, 90), rgb(246, 150, 40), rgb(226, 170, 50),
	rgb(244, 208, 70), rgb(246, 230, 180), rgb(246, 190, 150), rgb(206, 160, 104), rgb(140, 90, 50), rgb(88, 54, 30),
	rgb(130, 140, 44), rgb(160, 210, 70), rgb(190, 230, 150), rgb(70, 180, 96), rgb(34, 110, 64), rgb(150, 226, 196),
	rgb(70, 214, 220), rgb(40, 170, 160), rgb(30, 110, 120), rgb(200, 230, 250), rgb(110, 190, 246), rgb(60, 120, 230),
	rgb(40, 60, 150), rgb(70, 44, 160), rgb(140, 90, 220), rgb(196, 170, 250), rgb(110, 40, 120), rgb(214, 80, 190),
	rgb(250, 160, 200), rgb(250, 250, 250), rgb(200, 204, 210), rgb(120, 126, 136), rgb(64, 66, 74), rgb(24, 24, 28),
}

Config.RARITIES = {
	{ name = "Common", oneIn = 1, rate = 10, color = rgb(230, 230, 230) },
	{ name = "Uncommon", oneIn = 4, rate = 40, color = rgb(120, 230, 120) },
	{ name = "Rare", oneIn = 16, rate = 150, color = rgb(90, 170, 255) },
	{ name = "Epic", oneIn = 64, rate = 600, color = rgb(200, 120, 255) },
	{ name = "Legendary", oneIn = 256, rate = 2500, color = rgb(255, 200, 60) },
	{ name = "Mythic", oneIn = 1024, rate = 10000, color = rgb(255, 90, 120) },
}

-- Every drawing also rolls a mutation, separately from rarity. mult multiplies the animal's income. Normal gets whatever
-- chance the others leave (Config.mutationChances). A chance of 0 means only its weather can roll it. Append new ones at the end:
-- saves store the index.
Config.MUTATIONS = {
	{ name = "Normal", mult = 1, color = rgb(235, 240, 248) },
	{ name = "Gold", chance = 0.06, mult = 3, color = rgb(255, 214, 40) },
	{ name = "Diamond", chance = 0.03, mult = 6, color = rgb(110, 230, 255) },
	{ name = "Rainbow", chance = 0.01, mult = 15, color = rgb(255, 90, 220) },
	{ name = "Matrix", chance = 0, mult = 8, color = rgb(60, 255, 110) }, -- Matrix weather only
}

-- Weather: random server-wide events (ZooWeather.server.luau), one at a time with calm gaps between. While one is on,
-- its mutation rolls at `chance` instead of its normal chance. Seconds are picked at random inside each range.
-- look = Lighting properties every client tweens to: the key is "Lighting" or the name of a Lighting child.
-- rain = characters that fall in columns over the screen (leave it out for no rain). icon = a Config.ICONS key.
Config.WEATHER_GAP = { 360, 720 }
Config.WEATHERS = {
	{ name = "Matrix", mutation = "Matrix", chance = 0.1, weight = 1, duration = { 120, 180 }, icon = "cloud", color = rgb(60, 255, 110),
		rain = "0123456789ABCDEFXZ$#%&*+=<>",
		look = {
			Lighting = { ClockTime = 21, Brightness = 1.5, Ambient = rgb(40, 100, 60), OutdoorAmbient = rgb(60, 150, 90) },
			Atmosphere = { Density = 0.36, Color = rgb(30, 140, 70), Decay = rgb(0, 40, 15), Haze = 1.2, Glare = 0 },
			CartoonGrade = { TintColor = rgb(170, 255, 190), Saturation = 0.1, Contrast = 0.2 },
		},
	},
}

function Config.weather(name: string?): any
	for _, w in Config.WEATHERS do
		if w.name == name then return w end
	end
	return nil
end

-- Chance of each mutation while `weather` is on (nil = clear skies). Used by the server roll, so the odds live in one place.
function Config.mutationChances(weather: string?): { number }
	local w = Config.weather(weather)
	local out, rest = table.create(#Config.MUTATIONS, 0), 1
	for i = 2, #Config.MUTATIONS do
		local m = Config.MUTATIONS[i]
		out[i] = if w and w.mutation == m.name then w.chance else m.chance
		rest -= out[i]
	end
	out[1] = rest
	return out
end

-- The Judge's Review: stars (1-5) from how good the drawing is, each with an income multiplier and a verdict
Config.JUDGE = { "SIZE", "COLOURS", "DETAIL", "EYES", "NEAT" }
Config.STAR_MULT = { 1, 1.5, 2.5, 4, 6 }
Config.VERDICTS = { "Good try!", "Nice!", "Great!", "Amazing!", "Masterpiece!" }
Config.BASE_RATE = 10 -- $/s of a 1-star Common Normal animal; rarity multiplier = rarity rate / BASE_RATE

-- $/s of an owned animal. Animals made before the judge existed have no inc and earn their rarity's rate.
function Config.income(a: any): number
	return a.inc or Config.RARITIES[a.r].rate
end

-- Safari Sam (the trader at the centre stall) pays this many seconds of an animal's income.
-- Kept low on purpose: drawing is free, so a high price would make spam-drawing and selling a money printer.
Config.SELL_SECONDS = 30
function Config.sellPrice(a: any): number
	return math.floor(Config.income(a) * Config.SELL_SECONDS)
end

Config.MAX_LUCK_LEVEL = 10 -- luck = 2 ^ level, so 1x .. 1024x
Config.CAP_START = 2
Config.CAP_MAX = 12
Config.MAX_INVENTORY = 50
-- UserIds allowed to use admin chat commands such as /reset (the owner of the group that owns the game is always allowed)
Config.ADMINS = { 213438244, 135018525 } -- 135018525 = exodtust (rank 254 in the group, so not the owner)
Config.CREATE_COOLDOWN = 5
Config.DAILY_COOLDOWN = 20 * 3600
Config.DAILY_RESET = 48 * 3600

Config.DAILY = {
	{ cash = 500 }, { cash = 1500 }, { luckMin = 5 }, { cash = 5000 },
	{ cash = 15000 }, { luckMin = 15 }, { cash = 50000, luckMin = 30 },
}

-- Game pass and developer product ids (created 2026-11-19, docs/ASSETS.md). 0 = not for sale yet ("Coming soon").
Config.PASSES = { VIP = 2096448686, Money2x = 2094550605, Luck2x = 2093692759 }
Config.PRODUCTS = { LuckBoost = 3733847302, StarterPack = 3733847308, OfflineDouble = 3733847314 }
Config.GROUP_ID = 0 -- your Roblox group id: the Free Reward then also asks players to join it
Config.FREE_LUCK_MINUTES = 30 -- one-time Free Reward
Config.OFFLINE_HOURS = 3 -- most hours of income paid for time away

-- FOLK icon pack images used by the GUI (uploaded 2026-11-15). Swap any id to change an icon everywhere.
Config.ICONS = {
	shop = "rbxassetid://115904576228179", upgrade = "rbxassetid://134191535105444", paw = "rbxassetid://140601524674909", goldpaw = "rbxassetid://137211447217108",
	clover = "rbxassetid://129910142491273", luck = "rbxassetid://103597363454180", rainbowclover = "rbxassetid://91811400971511", calendar = "rbxassetid://121109331381725",
	bolt = "rbxassetid://114583506949045", pencil = "rbxassetid://92397333230431", chest = "rbxassetid://120819069934410", cash = "rbxassetid://82687048352982",
	cashbundle = "rbxassetid://71286891714442", crown = "rbxassetid://100803502480858", robux = "rbxassetid://89908545842678", lock = "rbxassetid://105171390568774",
	gift = "rbxassetid://77089024343963", giftpurple = "rbxassetid://88588653226624", potion = "rbxassetid://113177488777224", clock = "rbxassetid://130556675518648",
	house = "rbxassetid://121749266458525", star = "rbxassetid://121266289016863", check = "rbxassetid://114341398540196", heart = "rbxassetid://71701274462438",
	group = "rbxassetid://113057359506650", trash = "rbxassetid://89852632772779", info = "rbxassetid://105117543613672", cross = "rbxassetid://92222283070042",
	-- Free Icon Pack v3.1 (uploaded 2026-11-16): sticker art and the intro skip button
	fire = "rbxassetid://86782236536816", diamond = "rbxassetid://103499339444458", balloon = "rbxassetid://111496235104052",
	strawberry = "rbxassetid://84280958364881", cloud = "rbxassetid://70823404569278", rocket = "rbxassetid://130155476113713", skip = "rbxassetid://102098865538470",
}
Config.LUCK_BOOST_MINUTES = 5

-- Animal races round the outskirts (ZooRace.server.luau, layout in RaceLayout). Racers sit on their animal and drive it
-- like a car (ZooClient's race driving): it pulls away slowly and builds up to TOP_SPEED, and turns are wide and lazy.
-- Everyone has the same car; boost rings are how you win. The winner spins the prize wheel; every other finisher gets
-- CONSOLATION_SECONDS of income. Speeds are studs/second, ACCEL/BRAKE/COAST studs/second each second, TURN degrees/second.
Config.RACE = {
	LAPS = 2, MIN_PLAYERS = 2, MAX_PLAYERS = 8, COUNTDOWN = 5,
	TOP_SPEED = 40, BOOST_SPEED = 62, BOOST_SECONDS = 2.5, MUD_SPEED = 16, REVERSE_SPEED = 10,
	ACCEL = 13, BOOST_ACCEL = 45, BRAKE = 30, COAST = 9,
	TURN = 75, STEER_LAG = 0.3, -- full lock turns 75 deg/s once moving; the wheel takes about STEER_LAG seconds to follow the stick
	TIME_LIMIT = 150, AFTER_WINNER = 25, -- seconds: the whole race, and how long the rest get once someone has won
	CONSOLATION_SECONDS = 120,
	-- prize wheel slices, clockwise from the top. cash = seconds of the winner's income; luck/money = minutes of 2x
	WHEEL = {
		{ label = "10 MIN\nCASH", cash = 600, weight = 30, color = "6BFF3A" },
		{ label = "2x LUCK\n5 MIN", luck = 5, weight = 24, color = "3DF5FF" },
		{ label = "30 MIN\nCASH", cash = 1800, weight = 15, color = "FFB000" },
		{ label = "2x MONEY\n5 MIN", money = 5, weight = 24, color = "FF2BD6" },
		{ label = "JACKPOT\n1 HOUR", cash = 3600, weight = 7, color = "FFE600" },
	},
}
Config.STARTER_PACK = { cash = 25000, luckMin = 30 }

-- stickers are icon-pack images: each entry is a key of Config.ICONS (a saved sticker stores its index here)
Config.STICKERS = { "star", "heart", "bolt", "fire", "crown", "diamond", "balloon", "strawberry", "clover", "cloud", "paw", "rocket" }
Config.EYE_STYLES = 12
Config.EYE_SIZES = { 0.1, 0.15, 0.21 }
Config.STICKER_SIZES = { 0.18, 0.26, 0.36 }
Config.MAX_EYES = 4
Config.MAX_STICKERS = 4
Config.MIN_CELLS = 430

Config.NAMES = { "Biscuit", "Mango", "Pebble", "Waffles", "Ziggy", "Noodle", "Sunny", "Pickle", "Mochi", "Bongo", "Clover", "Tofu", "Pepper", "Dotty", "Rumble", "Peanut" }

-- Templates on the 80 x 56 grid, head on the left. Shapes are painted in order, later ones on top:
--   { "e", cx, cy, rx, ry }          ellipse
--   { "r", x1, y1, x2, y2 }           rectangle
--   { "p", { x1, y1, x2, y2, ... } }  polygon
--   { "l", { {x, y, r}, ... } }       thick line through the points, radius r at each point (legs, necks, tails)
-- c = palette colour (default t.color); cut = true clears the shape instead. eyes = demo eyes for the showcase (0..1).
Config.TEMPLATES = {
	{ name = "Lion", color = 7, eyes = { { 0.19, 0.38 } }, shapes = {
		{ "e", 46, 30, 20, 11 },
		{ "l", { { 31, 36, 3 }, { 31, 50, 3 } } }, { "l", { { 39, 37, 3 }, { 39, 50, 3 } } }, { "l", { { 53, 37, 3 }, { 53, 50, 3 } } }, { "l", { { 61, 35, 3 }, { 61, 50, 3 } } },
		{ "e", 30, 51, 4, 2, c = 9 }, { "e", 38, 51, 4, 2, c = 9 }, { "e", 52, 51, 4, 2, c = 9 }, { "e", 60, 51, 4, 2, c = 9 },
		{ "l", { { 64, 26, 1.4 }, { 71, 20, 1.4 }, { 74, 14, 1.4 } } }, { "e", 74, 13, 3, 3.5, c = 12 },
		{ "e", 20, 23, 14, 15, c = 12 },
		{ "e", 18, 24, 9.5, 9.5, c = 8 }, { "e", 11, 17, 3, 3, c = 8 }, { "e", 25, 16, 3, 3, c = 8 },
		{ "e", 12, 28, 5.5, 4, c = 9 }, { "e", 8, 26, 2.2, 1.6, c = 13 },
	} },
	{ name = "Elephant", color = 34, eyes = { { 0.2, 0.32 } }, shapes = {
		{ "e", 47, 26, 22, 14 },
		{ "r", 30, 34, 37, 51 }, { "r", 40, 34, 47, 51 }, { "r", 54, 34, 61, 51 }, { "r", 63, 33, 69, 51 },
		{ "r", 30, 49, 37, 51, c = 35 }, { "r", 40, 49, 47, 51, c = 35 }, { "r", 54, 49, 61, 51, c = 35 }, { "r", 63, 49, 69, 51, c = 35 },
		{ "l", { { 68, 22, 1 }, { 74, 31, 1 } } }, { "e", 74, 32, 1.6, 2.2, c = 35 },
		{ "e", 19, 22, 11, 10 },
		{ "l", { { 12, 26, 4 }, { 9, 36, 3.2 }, { 9, 44, 2.6 }, { 12, 48, 2.2 }, { 15, 46, 2 } } },
		{ "e", 28, 22, 7, 10, c = 35 },
		{ "p", { 14, 32, 18, 33, 11, 38, 9, 37 }, c = 33 },
	} },
	{ name = "Giraffe", color = 8, eyes = { { 0.21, 0.16 } }, shapes = {
		{ "e", 48, 30, 17, 9 },
		{ "l", { { 36, 35, 2 }, { 36, 53, 1.8 } } }, { "l", { { 43, 36, 2 }, { 43, 53, 1.8 } } }, { "l", { { 55, 36, 2 }, { 55, 53, 1.8 } } }, { "l", { { 61, 35, 2 }, { 61, 53, 1.8 } } },
		{ "r", 34, 51, 38, 54, c = 13 }, { "r", 41, 51, 45, 54, c = 13 }, { "r", 53, 51, 57, 54, c = 13 }, { "r", 59, 51, 63, 54, c = 13 },
		{ "l", { { 64, 27, 0.9 }, { 69, 36, 0.9 } } }, { "e", 69, 37, 1.5, 2.2, c = 13 },
		{ "p", { 21, 9, 27, 8, 40, 24, 32, 30 } },
		{ "e", 19, 10, 7.5, 4.8 }, { "e", 12, 11, 4, 3.4, c = 9 }, { "e", 27, 7, 3.4, 1.6 },
		{ "l", { { 19, 7, 0.8 }, { 19, 2, 0.8 } }, c = 12 }, { "l", { { 23, 7, 0.8 }, { 23, 2, 0.8 } }, c = 12 }, { "e", 19, 2, 1.4, 1.4, c = 12 }, { "e", 23, 2, 1.4, 1.4, c = 12 },
		{ "e", 40, 27, 3.2, 2.6, c = 6 }, { "e", 49, 33, 3, 2.2, c = 6 }, { "e", 56, 26, 3, 2.5, c = 6 }, { "e", 46, 24, 2.2, 1.8, c = 6 },
		{ "e", 61, 31, 2.2, 2, c = 6 }, { "e", 31, 21, 2, 1.8, c = 6 }, { "e", 27, 14, 1.6, 1.6, c = 6 }, { "e", 35, 26, 1.6, 1.4, c = 6 },
	} },
	{ name = "Penguin", color = 37, eyes = { { 0.45, 0.23 }, { 0.55, 0.23 } }, shapes = {
		{ "e", 40, 31, 14, 19 }, { "e", 40, 13, 10, 9 },
		{ "p", { 27, 21, 21, 37, 27, 36 } }, { "p", { 53, 21, 59, 37, 53, 36 } },
		{ "e", 40, 35, 9, 14, c = 33 }, { "e", 36, 13, 4.2, 4.2, c = 33 }, { "e", 44, 13, 4.2, 4.2, c = 33 },
		{ "p", { 37, 17, 43, 17, 40, 21.5 }, c = 6 },
		{ "e", 34, 50, 5, 2.2, c = 6 }, { "e", 46, 50, 5, 2.2, c = 6 },
	} },
	{ name = "Snake", color = 17, eyes = { { 0.13, 0.36 } }, shapes = {
		{ "l", { { 14, 26, 4 }, { 20, 33, 4.2 }, { 29, 41, 4.5 }, { 40, 45, 4.5 }, { 52, 41, 4.2 }, { 61, 35, 3.8 }, { 70, 38, 3 }, { 75, 45, 1.6 } } },
		{ "e", 12, 22, 7.5, 5.5 },
		{ "l", { { 7, 24, 0.6 }, { 2, 26, 0.6 } }, c = 3 },
		{ "e", 24, 37, 1.8, 1.8, c = 18 }, { "e", 34, 44, 2, 2, c = 18 }, { "e", 46, 44, 2, 2, c = 18 }, { "e", 57, 37, 1.8, 1.8, c = 18 }, { "e", 67, 37, 1.5, 1.5, c = 18 },
		{ "e", 14, 19, 1.3, 1.3, c = 18 }, { "e", 17, 23, 1.2, 1.2, c = 18 },
	} },
	{ name = "Turtle", color = 15, eyes = { { 0.13, 0.43 } }, shapes = {
		{ "l", { { 29, 32, 3.2 }, { 29, 41, 3 } } }, { "l", { { 55, 32, 3.2 }, { 55, 41, 3 } } },
		{ "e", 28, 42, 4.5, 2, c = 15 }, { "e", 56, 42, 4.5, 2, c = 15 },
		{ "l", { { 17, 28, 3.5 }, { 25, 30, 3.5 } } }, { "e", 13, 26, 7, 5.5 },
		{ "e", 42, 30, 21, 15, c = 18 }, { "r", 18, 30, 66, 46, cut = true },
		{ "p", { 61, 28, 71, 32, 61, 34 } },
		{ "l", { { 29, 32, 3.2 }, { 29, 41, 3 } } }, { "l", { { 55, 32, 3.2 }, { 55, 41, 3 } } }, { "e", 28, 42, 4.5, 2 }, { "e", 56, 42, 4.5, 2 },
		{ "r", 21, 28, 63, 31, c = 11 },
		{ "e", 42, 21, 6, 4.5, c = 17 }, { "e", 31, 24, 4, 3.4, c = 17 }, { "e", 53, 24, 4, 3.4, c = 17 }, { "e", 37, 18, 3, 2.2, c = 17 }, { "e", 48, 18, 3, 2.2, c = 17 },
	} },
	{ name = "Monkey", color = 12, eyes = { { 0.46, 0.26 }, { 0.54, 0.26 } }, shapes = {
		{ "l", { { 51, 40, 1.6 }, { 62, 45, 1.6 }, { 71, 39, 1.6 }, { 69, 30, 1.6 }, { 64, 32, 1.6 } } },
		{ "l", { { 33, 26, 2.6 }, { 26, 36, 2.6 }, { 24, 44, 2.6 } } }, { "l", { { 51, 26, 2.6 }, { 58, 36, 2.6 }, { 60, 44, 2.6 } } },
		{ "l", { { 37, 40, 3.2 }, { 34, 51, 3 } } }, { "l", { { 47, 40, 3.2 }, { 50, 51, 3 } } },
		{ "e", 42, 32, 11, 12.5 },
		{ "e", 29, 14, 3.8, 3.8 }, { "e", 51, 14, 3.8, 3.8 }, { "e", 29, 14, 2, 2, c = 10 }, { "e", 51, 14, 2, 2, c = 10 },
		{ "e", 40, 15, 10.5, 9.5 },
		{ "e", 40, 17, 7.5, 6.5, c = 10 }, { "e", 40, 21, 5, 3.2, c = 9 }, { "e", 42, 33, 6.5, 8.5, c = 10 },
		{ "e", 24, 45, 2.8, 2.2, c = 10 }, { "e", 60, 45, 2.8, 2.2, c = 10 }, { "e", 32, 52, 4, 2, c = 10 }, { "e", 52, 52, 4, 2, c = 10 },
	} },
	{ name = "Blob", color = 24, eyes = { { 0.42, 0.47 }, { 0.58, 0.47 } }, shapes = {
		{ "e", 30, 47, 6.5, 3.2 }, { "e", 50, 47, 6.5, 3.2 },
		{ "e", 40, 30, 22, 17 },
		{ "l", { { 40, 14, 1 }, { 43, 6, 1 } }, c = 25 }, { "e", 43, 5, 2.8, 2.8, c = 8 },
		{ "e", 29, 34, 3.2, 2, c = 32 }, { "e", 51, 34, 3.2, 2, c = 32 },
	} },
}

local function inside(s: any, px: number, py: number): boolean
	local kind = s[1]
	if kind == "e" then
		local dx, dy = (px - s[2]) / s[4], (py - s[3]) / s[5]
		return dx * dx + dy * dy <= 1
	elseif kind == "r" then
		return px >= s[2] and px <= s[4] + 1 and py >= s[3] and py <= s[5] + 1
	elseif kind == "p" then -- even-odd rule
		local v, hit, n = s[2], false, #s[2]
		local j = n - 1
		for i = 1, n, 2 do
			local xi, yi, xj, yj = v[i], v[i + 1], v[j], v[j + 1]
			if (yi > py) ~= (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi then hit = not hit end
			j = i
		end
		return hit
	else -- "l": distance to each segment against the radius interpolated along it
		local pts = s[2]
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local ex, ey = b[1] - a[1], b[2] - a[2]
			local t = math.clamp(((px - a[1]) * ex + (py - a[2]) * ey) / (ex * ex + ey * ey), 0, 1)
			local dx, dy = px - (a[1] + ex * t), py - (a[2] + ey * t)
			local r = a[3] + (b[3] - a[3]) * t
			if dx * dx + dy * dy <= r * r then return true end
		end
		return false
	end
end

local function bounds(s: any): (number, number, number, number)
	local kind = s[1]
	if kind == "e" then return s[2] - s[4], s[3] - s[5], s[2] + s[4], s[3] + s[5] end
	if kind == "r" then return s[2], s[3], s[4] + 1, s[5] + 1 end
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	if kind == "p" then
		local v = s[2]
		for i = 1, #v, 2 do x0, y0, x1, y1 = math.min(x0, v[i]), math.min(y0, v[i + 1]), math.max(x1, v[i]), math.max(y1, v[i + 1]) end
	else
		for _, q in s[2] do x0, y0, x1, y1 = math.min(x0, q[1] - q[3]), math.min(y0, q[2] - q[3]), math.max(x1, q[1] + q[3]), math.max(y1, q[2] + q[3]) end
	end
	return x0, y0, x1, y1
end

local gridCache: { [string]: { number } } = {}
-- Fills a template into a flat grid (0 = empty). colored = its real colours (showcase, thumbnails); otherwise the grey shape the editor starts from.
-- Templates are authored on an 80 x 56 grid and sampled onto the real grid, so they stay the same when the grid changes.
function Config.templateGrid(t: any, colored: boolean?): { number }
	local key = t.name .. (if colored then "+" else "-")
	local hit = gridCache[key]
	if hit then return table.clone(hit) end
	local W, H = Config.W, Config.H
	local sx, sy = 80 / W, 56 / H
	local cells = table.create(W * H, 0)
	for _, s in t.shapes do
		local v = if s.cut then 0 elseif colored then s.c or t.color else 1
		local x0, y0, x1, y1 = bounds(s) -- only test cells inside the shape's box
		for y = math.max(0, math.floor(y0 / sy)), math.min(H - 1, math.ceil(y1 / sy)) do
			for x = math.max(0, math.floor(x0 / sx)), math.min(W - 1, math.ceil(x1 / sx)) do
				if inside(s, (x + 0.5) * sx, (y + 0.5) * sy) then cells[y * W + x + 1] = v end
			end
		end
	end
	gridCache[key] = cells
	return table.clone(cells)
end

-- Upgrade prices, one per level (index = level + 1). Fitted by tools/balance_sim.py so an active player with no
-- game passes is fully maxed (luck 10/10, capacity 12/12) after about 24 hours of play, with upgrades spaced from
-- minutes apart at the start to about two hours apart at the end. Re-run the sim after changing any income number.
Config.LUCK_COSTS = { 810e3, 17e6, 75e6, 270e6, 940e6, 1.9e9, 3.9e9, 7.8e9, 13e9, 24e9 }
Config.CAP_COSTS = { 39e3, 5.4e6, 38e6, 160e6, 540e6, 1.1e9, 2.9e9, 5.9e9, 11e9, 20e9 }

function Config.luckCost(level: number): number
	return Config.LUCK_COSTS[level + 1]
end

function Config.capCost(level: number): number
	return Config.CAP_COSTS[level + 1]
end

-- Chance of each rarity for a luck multiplier. Used by the server roll AND the odds screen, so they can never disagree.
function Config.chances(luck: number): { number }
	local out = table.create(#Config.RARITIES, 0)
	local remaining = 1
	for i = #Config.RARITIES, 1, -1 do
		local p = math.min(1, luck / Config.RARITIES[i].oneIn) * remaining
		out[i] = p
		remaining -= p
	end
	return out
end

function Config.format(n: number): string
	n = math.floor(n)
	for _, s in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.2f", n / s[1]):gsub("%.?0+$", "") .. s[2] end
	end
	return (tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

return Config
