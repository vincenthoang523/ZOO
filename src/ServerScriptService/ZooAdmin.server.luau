--!nonstrict
-- ZooAdmin: /give and /take chat commands so admins (ZooServer's isAdmin: Config.ADMINS or the group owner) can give
-- themselves things for testing. Chat commands run on the server, so there is no remote a client could fire.
--   /give cash 1.5m            cash (K M B T suffixes; a minus amount takes cash away)
--   /give luck 30              minutes of 2x luck        /give money 30   minutes of 2x money
--   /give animal mythic rainbow 5   an animal: rarity, mutation (default Normal), stars 1-5 (default 5)
--   /give pass vip             a game pass (vip, money2x, luck2x or all); /take pass ... removes it
-- Passes given this way are a flag in the admin's save only: no real purchase is made or touched.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local Zoo = ReplicatedStorage:WaitForChild("Zoo")
local Config = require(Zoo.Config)
local Render = require(Zoo.Render)
local Api = require(script.Parent.ZooApi)

local GOOD, BAD = Color3.fromRGB(120, 255, 120), Color3.fromRGB(255, 90, 90)
local HELP = "/give cash 1m | luck 30 | money 30 | animal <rarity> [mutation] [stars] | pass <vip/money2x/luck2x/all>  -  /take pass <name/all>"
local SUFFIX = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12 }

local function amount(arg) -- "1.5m" -> 1500000; nil if it isn't a sane number
	local num, suffix = (arg or ""):lower():match("^(%-?%d+%.?%d*)([kmbt]?)$")
	local n = num and tonumber(num) * SUFFIX[suffix]
	if not n or math.abs(n) > 1e15 then return nil end
	return math.floor(n)
end

local function byName(list, arg) -- a Config list entry by name (any case) or by its number
	if not arg then return nil end
	local i = tonumber(arg)
	if i then return list[i] and i end
	for j, e in list do
		if e.name:lower() == arg:lower() then return j end
	end
	return nil
end

local function names(list)
	local out = {}
	for _, e in list do table.insert(out, e.name) end
	return table.concat(out, ", ")
end

local function passNames(arg) -- the Config.PASSES keys `arg` means
	if arg == "all" then
		local all = {}
		for name in Config.PASSES do table.insert(all, name) end
		return all
	end
	for name in Config.PASSES do
		if arg and name:lower() == arg then return { name } end
	end
	return nil
end

local function setPasses(player, s, arg, owned)
	local list = passNames(arg)
	if not list then
		local all = {}
		for name in Config.PASSES do table.insert(all, name:lower()) end
		return Api.notify(player, "Pass names: " .. table.concat(all, ", ") .. ", all", BAD)
	end
	for _, name in list do s.passes[name], s.data.passGrants[name] = owned, owned end
	Api.changed(player)
	Api.notify(player, (owned and "Gave you " or "Took away ") .. table.concat(list, ", "), GOOD)
end

local function give(player, s, kind, a, b, c)
	if kind == "cash" then
		local n = amount(a)
		if not n then return Api.notify(player, "Usage: /give cash 1m", BAD) end
		s.data.cash = math.max(0, s.data.cash + n)
		Api.changed(player)
		Api.notify(player, (n < 0 and "Took $" or "Gave you $") .. Config.format(math.abs(n)), GOOD)
	elseif kind == "luck" or kind == "money" then
		local minutes = amount(a)
		if not minutes or minutes < 1 or minutes > 1440 then return Api.notify(player, "Usage: /give " .. kind .. " 30  (minutes, 1-1440)", BAD) end
		if kind == "luck" then Api.addLuck(player, minutes) else Api.addMoney(player, minutes) end
		Api.notify(player, string.format("Gave you %d min of 2x %s", minutes, kind), GOOD)
	elseif kind == "animal" then
		local r = byName(Config.RARITIES, a)
		local m = if b then byName(Config.MUTATIONS, b) else 1
		local st = if c then tonumber(c) else 5
		if not r then return Api.notify(player, "Rarity: " .. names(Config.RARITIES), BAD) end
		if not m then return Api.notify(player, "Mutation: " .. names(Config.MUTATIONS), BAD) end
		if not st or not Config.STAR_MULT[st] then return Api.notify(player, "Stars: 1-5", BAD) end
		-- a random showcase template, built the same way as the showcase animals in ZooServer
		local t = Config.TEMPLATES[math.random(#Config.TEMPLATES)]
		local eyes = {}
		for i, e in t.eyes do eyes[i] = { e[1], e[2], 2, 2 } end
		local design = { n = t.name, g = Render.encode(Config.templateGrid(t, true)), e = eyes, s = {} }
		local inc = math.floor(Config.STAR_MULT[st] * Config.RARITIES[r].rate * Config.MUTATIONS[m].mult)
		local animal = { id = HttpService:GenerateGUID(false), d = design, r = r, m = m, st = st, inc = inc }
		if not Api.addAnimal(player, animal) then return Api.notify(player, "Your zoo is full! Release an animal first.", BAD) end
		Api.notify(player, string.format("Gave you a %s %s %s (%d stars, $%s/s)", Config.MUTATIONS[m].name, Config.RARITIES[r].name, t.name, st, Config.format(inc)), GOOD)
	elseif kind == "pass" then
		setPasses(player, s, a, true)
	else
		Api.notify(player, HELP)
	end
end

local function command(alias, handler)
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = "Zoo" .. alias:sub(2, 2):upper() .. alias:sub(3) .. "Command"
	cmd.PrimaryAlias = alias
	cmd.Parent = TextChatService
	cmd.Triggered:Connect(function(source, text)
		local player = Players:GetPlayerByUserId(source.UserId)
		local s = player and Api.session and Api.session(player)
		if not s or not Api.isAdmin(player) then return end -- everyone else: the command does nothing
		local args = {}
		for word in text:gmatch("%S+") do table.insert(args, word:lower()) end
		handler(player, s, args[2], args[3], args[4], args[5])
	end)
end

command("/give", give)
command("/take", function(player, s, kind, a)
	if kind == "pass" then return setPasses(player, s, a, false) end
	Api.notify(player, "Usage: /take pass <vip/money2x/luck2x/all>  (for cash: /give cash -1m)", BAD)
end)
