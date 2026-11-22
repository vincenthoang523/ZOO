--!nonstrict
-- ZooAdmin: everything admins (ZooServer's isAdmin: Config.ADMINS or the group owner) can do, used by two front ends:
--   * the Admin Panel in ZooClient, through the Remotes.Admin RemoteFunction (created here). Every call re-checks
--     isAdmin on the server and validates every argument, so a client that fires it itself gets nothing.
--   * the old chat commands, kept as a shortcut: /give cash 1.5m | luck 30 | money 30 | animal mythic rainbow 5 |
--     pass vip, and /take pass vip.
-- Moderation (Mod tab): KICK (Players tab), WIPE a save and BAN / UNBAN, also for offline players by username or UserId.
-- Nobody can wipe or ban themselves or another admin. Bans live in the ZooBansV1 DataStore (checked on join) and are
-- also sent to Players:BanAsync, which blocks them before they even join (and their alts) when Roblox allows it.
-- Passes given this way are a flag in that player's save only: no real purchase is made or touched.
-- Admins get the Admin attribute (true) so their client shows the panel button; it is only a hint for the UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local GroupService = game:GetService("GroupService")

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
	-- taking only undoes an admin grant: a pass the player bought with Robux stays theirs
	for _, name in list do s.passes[name], s.data.passGrants[name] = owned or s.bought[name] == true, owned or nil end
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

----- moderation -----
-- shortcut: every ban sits in one key (fine up to a few thousand bans); split it per user if the list ever gets that big
local banStore = DataStoreService:GetDataStore("ZooBansV1")
local BAN_KEY = "all"
local TOPIC = "ZooModeration" -- tells other servers to kick a banned player or restart a wiped one

local function activeBan(list, id) -- list[userId] = { n = name, r = reason, by = admin name, at = os.time(), ends = os.time() or 0 forever }
	local b = list[tostring(id)]
	if b and (b.ends == 0 or b.ends > os.time()) then return b end
	return nil
end

local function banList() -- nil if the DataStore couldn't be read
	local ok, list = pcall(banStore.GetAsync, banStore, BAN_KEY)
	if not ok then return nil end
	return typeof(list) == "table" and list or {}
end

local function editBans(edit) -- returns ok; drops expired bans while it's at it
	return (pcall(banStore.UpdateAsync, banStore, BAN_KEY, function(list)
		list = typeof(list) == "table" and list or {}
		for id in list do
			if not activeBan(list, id) then list[id] = nil end
		end
		edit(list)
		return list
	end))
end

local function banText(b)
	local text = "You are banned from Draw a Zoo"
	if b.ends > 0 then text ..= " until " .. os.date("!%Y-%m-%d %H:%M UTC", b.ends) end
	return text .. (b.r ~= "" and (": " .. b.r) or ".")
end

local function broadcast(msg)
	local ok, err = pcall(MessagingService.PublishAsync, MessagingService, TOPIC, msg)
	if not ok then warn("[ZooAdmin] couldn't reach other servers:", err) end
end

-- a username ("@name" works) or UserId -> userId, username; or nil, why not
local function resolve(q)
	q = short(q, 30)
	q = q and q:match("^%s*@?(.-)%s*$")
	if not q or q == "" then return nil, "Type a username or UserId" end
	local id = tonumber(q)
	if not id then
		if not q:match("^[%w_]+$") then return nil, "Usernames only have letters, numbers and _" end
		local ok, found = pcall(Players.GetUserIdFromNameAsync, Players, q)
		if not ok or not found then return nil, "No Roblox user called " .. q end
		id = found
	end
	id = math.floor(id)
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
	if not ok then return nil, "No Roblox user with id " .. id end
	return id, name
end

-- isAdmin for someone who may be offline. Unsure (the group lookup failed) counts as an admin, so nothing happens to them.
local function isAdminId(id)
	local p = Players:GetPlayerByUserId(id)
	if p then return Api.isAdmin(p) end
	if table.find(Config.ADMINS, id) then return true end
	if game.CreatorType ~= Enum.CreatorType.Group then return id == game.CreatorId end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, id)
	if not ok then return true end
	for _, g in groups do
		if g.Id == game.CreatorId then return g.Rank == 255 end
	end
	return false
end

local function refuse(admin, id, verb) -- why `admin` may not `verb` this user, or nil
	if id == admin.UserId then return "You can't " .. verb .. " yourself" end
	if isAdminId(id) then return "You can't " .. verb .. " an admin" end
	return nil
end

-- every panel action: function(admin, payload) -> ok, message[, data]
local actions = {}

function actions.lookup(admin, p)
	local id, name = resolve(p.user)
	if not id then return false, name end
	local list = banList()
	return true, nil, { userId = id, name = name, here = Players:GetPlayerByUserId(id) ~= nil, admin = isAdminId(id),
		me = id == admin.UserId, ban = list and activeBan(list, id) }
end

function actions.wipe(admin, p)
	local id, name = resolve(p.user)
	if not id then return false, name end
	local no = refuse(admin, id, "wipe")
	if no then return false, no end
	local ok, err = Api.wipe(id)
	if not ok then return false, "Wipe failed: " .. err end
	local here = Players:GetPlayerByUserId(id)
	if here then
		Api.notify(here, "An admin wiped your save - starting fresh.", BAD)
	else
		broadcast({ op = "wipe", id = id }) -- if they're in another server, that server must drop the copy it would save back
	end
	return true, "Wiped " .. name .. "'s save"
end

local BAN_DAYS = { [0] = true, [1] = true, [7] = true } -- 0 = forever
function actions.ban(admin, p)
	local id, name = resolve(p.user)
	if not id then return false, name end
	local no = refuse(admin, id, "ban")
	if no then return false, no end
	local days = tonumber(p.days) or -1
	if not BAN_DAYS[days] then return false, "Pick how long" end
	local reason = typeof(p.reason) == "string" and p.reason:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
	if #reason > 100 then return false, "Reason: 100 characters at most" end
	if reason ~= "" then
		reason = filtered(admin, reason) -- the banned player sees it
		if not reason then return false, "Couldn't check that reason, try again" end
	end
	local record = { n = name, r = reason, by = admin.Name, at = os.time(), ends = days == 0 and 0 or os.time() + days * 86400 }
	if not editBans(function(list) list[tostring(id)] = record end) then return false, "Couldn't save the ban, try again" end
	local ok, err = pcall(Players.BanAsync, Players, { UserIds = { id }, ApplyToUniverse = true, Duration = days == 0 and -1 or days * 86400,
		DisplayReason = reason ~= "" and reason or "Banned by an admin", PrivateReason = "Admin Panel: " .. admin.Name .. " (" .. admin.UserId .. ")",
		ExcludeAltAccounts = false })
	if not ok then warn("[ZooAdmin] BanAsync failed (the game's own ban list still keeps them out):", err) end
	local here = Players:GetPlayerByUserId(id)
	if here then here:Kick(banText(record)) else broadcast({ op = "kick", id = id, text = banText(record) }) end
	return true, "Banned " .. name .. (days == 0 and " forever" or " for " .. days .. (days == 1 and " day" or " days"))
end

function actions.unban(admin, p)
	local id, name = resolve(p.user)
	if not id then return false, name end
	if not editBans(function(list) list[tostring(id)] = nil end) then return false, "Couldn't save, try again" end
	local ok, err = pcall(Players.UnbanAsync, Players, { UserIds = { id }, ApplyToUniverse = true })
	if not ok then warn("[ZooAdmin] UnbanAsync failed:", err) end
	return true, "Unbanned " .. name
end

function actions.bans()
	local list = banList()
	if not list then return false, "Couldn't read the ban list" end
	local rows = {}
	for id, b in list do
		if activeBan(list, id) then table.insert(rows, { userId = tonumber(id), name = b.n, reason = b.r, by = b.by, at = b.at, ends = b.ends }) end
	end
	table.sort(rows, function(a, b) return a.at > b.at end)
	return true, nil, rows
end

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
	Zoo:SetAttribute("AnnounceUserId", admin.UserId) -- clients show the announcer's headshot
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
	local admin = Api.isAdmin(p)
	p:SetAttribute("Admin", admin or nil)
	local list = not admin and banList() -- if the ban list can't be read, let them in rather than lock everyone out
	local b = list and activeBan(list, p.UserId)
	if b then p:Kick(banText(b)) end
end
Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end

task.spawn(function() -- bans and wipes made in other servers
	local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(m)
		local d = m.Data
		local p = typeof(d) == "table" and Players:GetPlayerByUserId(tonumber(d.id) or 0)
		if not p then return end
		if d.op == "kick" and typeof(d.text) == "string" then
			p:Kick(d.text)
		elseif d.op == "wipe" and Api.wipe(p.UserId) then
			Api.notify(p, "An admin wiped your save - starting fresh.", BAD)
		end
	end)
	if not ok then warn("[ZooAdmin] cross-server moderation is off:", err) end
end)
