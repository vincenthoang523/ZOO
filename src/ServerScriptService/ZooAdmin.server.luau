--!nonstrict
-- ZooAdmin: everything admins (ZooServer's isAdmin: Config.ADMINS or the group owner) can do, used by two front ends:
--   * the Admin Panel in ZooClient, through the Remotes.Admin RemoteFunction (created here). Every call re-checks
--     isAdmin on the server and validates every argument, so a client that fires it itself gets nothing.
--   * the old chat commands, kept as a shortcut: /give cash 1.5m | luck 30 | money 30 | animal mythic rainbow 5 |
--     pass vip, and /take pass vip.
-- Passes given this way are a flag in that player's save only: no real purchase is made or touched.
-- Admins get the Admin attribute (true) so their client shows the panel button; it is only a hint for the UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local Zoo = ReplicatedStorage:WaitForChild("Zoo")
local Config = require(Zoo.Config)
local Render = require(Zoo.Render)
local Api = require(script.Parent.ZooApi)

local GOOD, BAD = Color3.fromRGB(120, 255, 120), Color3.fromRGB(255, 90, 90)
local HELP = "/give cash 1m | luck 30 | money 30 | animal <rarity> [mutation] [stars] | pass <vip/money2x/luck2x/all>  -  /take pass <name/all>"
local SUFFIX = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
local MAX_EVENT_SECONDS = 6 * 3600

local function amount(arg) -- "1.5m" -> 1500000; nil if it isn't a sane number
	local num, suffix = tostring(arg or ""):lower():match("^(%-?%d+%.?%d*)([kmbt]?)$")
	local n = num and tonumber(num) * SUFFIX[suffix]
	if not n or math.abs(n) > 1e15 then return nil end
	return math.floor(n)
end

local function byName(list, arg) -- a Config list entry by name (any case) or by its number
	if not arg then return nil end
	local i = tonumber(arg)
	if i then return list[i] and i end
	for j, e in list do
		if e.name:lower() == tostring(arg):lower() then return j end
	end
	return nil
end

local function names(list)
	local out = {}
	for _, e in list do table.insert(out, e.name) end
	return table.concat(out, ", ")
end

local function passNames(arg) -- the Config.PASSES keys `arg` means
	arg = arg and tostring(arg):lower()
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

----- giving: each returns ok, and either what was given ("$1.5M") or why not -----
local function setPasses(target, s, arg, owned)
	local list = passNames(arg)
	if not list then
		local all = {}
		for name in Config.PASSES do table.insert(all, name:lower()) end
		return false, "Pass names: " .. table.concat(all, ", ") .. ", all"
	end
	for _, name in list do s.passes[name], s.data.passGrants[name] = owned, owned end
	Api.changed(target)
	return true, table.concat(list, ", ")
end

local function give(target, s, kind, a, b, c)
	if kind == "cash" then
		local n = amount(a)
		if not n then return false, "Cash amount like 1m, 2.5b or -500k" end
		s.data.cash = math.max(0, s.data.cash + n)
		Api.changed(target)
		return true, (n < 0 and "-$" or "$") .. Config.format(math.abs(n))
	elseif kind == "luck" or kind == "money" then
		local minutes = amount(a)
		if not minutes or minutes < 1 or minutes > 1440 then return false, "Minutes of 2x " .. kind .. ": 1-1440" end
		if kind == "luck" then Api.addLuck(target, minutes) else Api.addMoney(target, minutes) end
		return true, string.format("%d min of 2x %s", minutes, kind)
	elseif kind == "animal" then
		local r = byName(Config.RARITIES, a)
		local m = if b then byName(Config.MUTATIONS, b) else 1
		local st = if c then tonumber(c) else 5
		if not r then return false, "Rarity: " .. names(Config.RARITIES) end
		if not m then return false, "Mutation: " .. names(Config.MUTATIONS) end
		if not st or not Config.STAR_MULT[st] then return false, "Stars: 1-5" end
		-- a random showcase template, built the same way as the showcase animals in ZooServer
		local t = Config.TEMPLATES[math.random(#Config.TEMPLATES)]
		local eyes = {}
		for i, e in t.eyes do eyes[i] = { e[1], e[2], 2, 2 } end
		local design = { n = t.name, g = Render.encode(Config.templateGrid(t, true)), e = eyes, s = {} }
		local inc = math.floor(Config.STAR_MULT[st] * Config.RARITIES[r].rate * Config.MUTATIONS[m].mult)
		local animal = { id = HttpService:GenerateGUID(false), d = design, r = r, m = m, st = st, inc = inc }
		if not Api.addAnimal(target, animal) then return false, target.DisplayName .. "'s zoo is full" end
		return true, string.format("a %s %s %s (%d stars, $%s/s)", Config.MUTATIONS[m].name, Config.RARITIES[r].name, t.name, st, Config.format(inc))
	elseif kind == "pass" then
		return setPasses(target, s, a, true)
	elseif kind == "takepass" then
		local ok, what = setPasses(target, s, a, false)
		return ok, ok and ("removed " .. what) or what
	end
	return false, HELP
end

-- runs a give for `admin` on `target` and tells both of them how it went
local function giveTo(admin, target, ...)
	local s = Api.session(target)
	if not s then return false, target.DisplayName .. " is still loading" end
	local ok, what = give(target, s, ...)
	if not ok then
		Api.notify(admin, what, BAD)
	elseif target == admin then
		Api.notify(admin, "Gave you " .. what, GOOD)
	else
		Api.notify(admin, "Gave " .. target.DisplayName .. " " .. what, GOOD)
		Api.notify(target, "An admin gave you " .. what .. "!", GOOD)
	end
	return ok, what
end

----- chat commands -----
local function command(alias, handler)
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = "Zoo" .. alias:sub(2, 2):upper() .. alias:sub(3) .. "Command"
	cmd.PrimaryAlias = alias
	cmd.Parent = TextChatService
	cmd.Triggered:Connect(function(source, text)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player or not Api.session or not Api.session(player) or not Api.isAdmin(player) then return end -- everyone else: nothing
		local args = {}
		for word in text:gmatch("%S+") do table.insert(args, word:lower()) end
		handler(player, args[2], args[3], args[4], args[5])
	end)
end
command("/give", function(player, kind, a, b, c)
	if kind ~= "cash" and kind ~= "luck" and kind ~= "money" and kind ~= "animal" and kind ~= "pass" then return Api.notify(player, HELP) end
	giveTo(player, player, kind, a, b, c)
end)
command("/take", function(player, kind, a)
	if kind == "pass" then return giveTo(player, player, "takepass", a) end
	Api.notify(player, "Usage: /take pass <vip/money2x/luck2x/all>  (for cash: /give cash -1m)", BAD)
end)

----- server-wide state the panel changes (attributes on ReplicatedStorage.Zoo, so every client and late joiner sees them) -----
-- Boost events: Config.BOOST_EVENTS[i].attr = server time it ends (ZooServer's luck() and rate() read it).
-- Announcement: AnnounceText / AnnounceFrom / AnnounceSeconds, then AnnounceId bumps so clients show it once.
-- Countdown: TimerTitle and TimerEnds (server time).
local function filtered(player, text)
	local ok, result = pcall(TextService.FilterStringAsync, TextService, text, player.UserId, Enum.TextFilterContext.PublicChat)
	if not ok then return nil end
	local ok2, out = pcall(result.GetNonChatStringForBroadcastAsync, result)
	return ok2 and out or nil
end

local function boostEvent(name)
	for _, e in Config.BOOST_EVENTS do
		if e.name == name then return e end
	end
	return nil
end

local function stopEvent(name)
	local e = boostEvent(name)
	if e then
		Zoo:SetAttribute(e.attr, nil)
	elseif Config.weather(name) and Zoo:GetAttribute("Weather") == name then
		Api.clearWeather()
	end
end

local startedAt = os.time()
local function info()
	return {
		players = #Players:GetPlayers(), maxPlayers = Players.MaxPlayers, uptime = os.time() - startedAt, version = game.PlaceVersion,
		weatherPaused = Api.weatherPaused and Api.weatherPaused() or false,
	}
end

local function playerList()
	local rows = {}
	for _, p in Players:GetPlayers() do
		local s = Api.session(p)
		local zoo = 0
		if s then zoo = #s.data.animals end
		table.insert(rows, {
			userId = p.UserId, name = p.Name, displayName = p.DisplayName, admin = p:GetAttribute("Admin") == true,
			cash = s and s.data.cash or 0, rate = p:GetAttribute("Rate") or 0, luck = p:GetAttribute("Luck") or 1, animals = zoo,
			passes = s and table.clone(s.passes) or {},
		})
	end
	table.sort(rows, function(a, b) return a.displayName:lower() < b.displayName:lower() end)
	return rows
end

local function root(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function short(v, max) -- a remote argument that must be a short string or a number
	local t = typeof(v)
	if t == "number" then return v == v and math.abs(v) < 1e15 and tostring(v) or nil end
	if t ~= "string" or #v > max then return nil end
	return v
end

-- every panel action: function(admin, payload) -> ok, message[, data]
local actions = {}

function actions.players() return true, nil, { players = playerList(), info = info() } end

function actions.give(admin, p)
	local target = Players:GetPlayerByUserId(tonumber(p.target) or 0)
	if not target then return false, "That player left" end
	local kind = short(p.kind, 12)
	if kind ~= "cash" and kind ~= "luck" and kind ~= "money" and kind ~= "animal" and kind ~= "pass" and kind ~= "takepass" then return false, "Unknown gift" end
	local a, b, c = short(p.a, 24), short(p.b, 24), short(p.c, 24)
	return (giveTo(admin, target, kind, a, b, c)) -- giveTo already told the admin how it went
end

function actions.player(admin, p)
	local target = Players:GetPlayerByUserId(tonumber(p.target) or 0)
	if not target then return false, "That player left" end
	local op = p.op
	if op == "goto" or op == "bring" then
		if target == admin then return false, "That's you!" end
		local from, to = root(admin), root(target)
		if op == "bring" then from, to = to, from end
		if not (from and to) then return false, "No character to move" end
		from.AssemblyLinearVelocity = Vector3.zero
		from.CFrame = to.CFrame * CFrame.new(0, 0, 4)
		return true, (op == "goto" and "Went to " or "Brought ") .. target.DisplayName
	elseif op == "kick" then
		if target == admin or Api.isAdmin(target) then return false, "You can't kick an admin" end
		target:Kick("You were removed from this server by an admin.")
		return true, "Kicked " .. target.DisplayName
	end
	return false, "Unknown action"
end

function actions.event(admin, p)
	local name = short(p.name, 30)
	if p.op == "stop" then
		if not name then return false, "Pick an event" end
		stopEvent(name)
		return true, "Stopped " .. name
	end
	local secs = math.floor(tonumber(p.seconds) or 0)
	if secs < 10 or secs > MAX_EVENT_SECONDS then return false, "Duration: 10 to " .. MAX_EVENT_SECONDS .. " seconds" end
	local e = boostEvent(name)
	if e then
		Zoo:SetAttribute(e.attr, workspace:GetServerTimeNow() + secs)
		return true, e.text .. " for everyone started!"
	elseif Config.weather(name) then
		Api.startWeather(Config.weather(name), secs)
		return true, name .. " weather started!"
	end
	return false, "Pick an event"
end

function actions.announce(admin, p)
	local text = typeof(p.text) == "string" and p.text:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
	if #text < 1 or #text > 150 then return false, "Write 1-150 characters" end
	local clean = filtered(admin, text)
	if not clean then return false, "Couldn't check that message, try again" end
	Zoo:SetAttribute("AnnounceText", clean)
	Zoo:SetAttribute("AnnounceFrom", admin.DisplayName)
	Zoo:SetAttribute("AnnounceSeconds", math.clamp(math.floor(tonumber(p.seconds) or 8), 3, 30))
	Zoo:SetAttribute("AnnounceId", (Zoo:GetAttribute("AnnounceId") or 0) + 1)
	return true, "Announcement sent"
end

function actions.timer(admin, p)
	if p.op == "stop" then
		Zoo:SetAttribute("TimerEnds", nil)
		Zoo:SetAttribute("TimerTitle", nil)
		return true, "Countdown stopped"
	end
	local secs = math.floor(tonumber(p.seconds) or 0)
	if secs < 5 or secs > MAX_EVENT_SECONDS then return false, "Countdown: 5 to " .. MAX_EVENT_SECONDS .. " seconds" end
	local title = typeof(p.title) == "string" and p.title:match("^%s*(.-)%s*$") or ""
	if #title > 40 then return false, "Title: 40 characters at most" end
	local clean = title == "" and "Countdown" or filtered(admin, title)
	if not clean then return false, "Couldn't check that title, try again" end
	Zoo:SetAttribute("TimerTitle", clean)
	Zoo:SetAttribute("TimerEnds", workspace:GetServerTimeNow() + secs)
	return true, "Countdown started"
end

function actions.server(admin, p)
	if p.op == "weather" then
		Api.setWeatherPaused(p.on ~= true)
		return true, p.on == true and "Random weather is on" or "Random weather is off", info()
	elseif p.op == "stopall" then
		for _, e in Config.BOOST_EVENTS do Zoo:SetAttribute(e.attr, nil) end
		if Zoo:GetAttribute("Weather") then Api.clearWeather() end
		Zoo:SetAttribute("TimerEnds", nil)
		Zoo:SetAttribute("TimerTitle", nil)
		return true, "Stopped every event", info()
	elseif p.op == "respawn" then
		for _, pl in Players:GetPlayers() do task.spawn(pl.LoadCharacter, pl) end
		return true, "Respawned everyone", info()
	end
	return false, "Unknown option"
end

local remote = Zoo.Remotes:FindFirstChild("Admin") or Instance.new("RemoteFunction")
remote.Name = "Admin"
remote.Parent = Zoo.Remotes
local lastCall = {}
remote.OnServerInvoke = function(admin, action, payload)
	if not Api.isAdmin or not Api.isAdmin(admin) then return false, "Admins only" end -- checked on every single call
	local now = os.clock()
	if now - (lastCall[admin] or 0) < 0.15 then return false, "Slow down" end
	lastCall[admin] = now
	local handler = typeof(action) == "string" and actions[action]
	if not handler or typeof(payload) ~= "table" then return false, "Bad request" end
	local ok, okOrErr, msg, data = pcall(handler, admin, payload)
	if not ok then
		warn("[ZooAdmin]", action, okOrErr)
		return false, "Something went wrong"
	end
	return okOrErr, msg, data
end

local function onJoin(p)
	while not Api.isAdmin do task.wait(0.2) end
	p:SetAttribute("Admin", Api.isAdmin(p) or nil)
end
Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end
