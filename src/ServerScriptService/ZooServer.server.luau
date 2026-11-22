--!nonstrict
-- ZooServer: owns all player data, plots, income, rarity rolls and purchases. Clients only ask; the server decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TextService = game:GetService("TextService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")

local Zoo = ReplicatedStorage:WaitForChild("Zoo")
local Config = require(Zoo.Config)
local Render = require(Zoo.Render)
local Remotes = Zoo.Remotes
local World = workspace:WaitForChild("Zoo")
local Api = require(script.Parent.ZooApi) -- filled in at the bottom, for ZooRace

-- shortcut: no session locking, a player in two servers at once could overwrite data; move to ProfileStore if trading is ever added
local store = DataStoreService:GetDataStore("ZooV1")
local sessions = {} -- [Player] = { data, loaded, plot, passes, lastCreate, lastCall }
local rng = Random.new()

local function newData()
	return { cash = 0, luckLevel = 0, capLevel = 0, animals = {}, dailyDay = 0, dailyAt = 0, boostUntil = 0, moneyUntil = 0, lastSeen = 0, freeClaimed = false, introDone = false, passGrants = {} }
end

----- maths -----
local function capacity(s) return math.min(Config.CAP_MAX, Config.CAP_START + s.data.capLevel) end

-- an Admin Panel boost event (Config.BOOST_EVENTS[i]) is running: its attribute holds the server time it ends
local function boostOn(i) return (Zoo:GetAttribute(Config.BOOST_EVENTS[i].attr) or 0) > workspace:GetServerTimeNow() end

local function luck(s)
	local l = 2 ^ s.data.luckLevel
	if s.passes.Luck2x then l *= 2 end
	if s.data.boostUntil > os.time() then l *= 2 end
	if boostOn(1) then l *= 2 end -- admin event: 2x luck for everyone
	return l
end

local function rate(s)
	local r = 0
	for _, a in s.data.animals do
		if a.eq then r += Config.income(a) end
	end
	if s.passes.Money2x then r *= 2 end
	if s.passes.VIP then r *= 1.2 end
	if s.data.moneyUntil > os.time() then r *= 2 end -- race prize
	if boostOn(2) then r *= 2 end -- admin event: 2x money for everyone
	return math.floor(r)
end

local function equippedCount(s)
	local n = 0
	for _, a in s.data.animals do if a.eq then n += 1 end end
	return n
end

----- replication -----
local function sync(player, full)
	local s = sessions[player]
	if not s then return end
	player:SetAttribute("Cash", s.data.cash)
	player:SetAttribute("Rate", rate(s))
	player:SetAttribute("Luck", luck(s))
	if full then
		Remotes.State:FireClient(player, {
			luckLevel = s.data.luckLevel, capLevel = s.data.capLevel, capacity = capacity(s), animals = s.data.animals,
			dailyDay = s.data.dailyDay, dailyWait = math.max(0, s.data.dailyAt + Config.DAILY_COOLDOWN - os.time()),
			boostLeft = math.max(0, s.data.boostUntil - os.time()), moneyLeft = math.max(0, s.data.moneyUntil - os.time()), passes = s.passes, freeClaimed = s.data.freeClaimed,
			offline = s.offlineNotice, -- sent once, for the Welcome Back popup
		})
		s.offlineNotice = nil
	end
end

local function spawnAnimal(folder, design, rarity, mutation, income)
	local p = Instance.new("Part")
	p.Name = "Animal"
	p.Size, p.Transparency, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = Vector3.one, 1, true, false, false, false
	local pen = folder.Parent.Pen
	p.CFrame = pen.CFrame * CFrame.new(rng:NextNumber(-0.35, 0.35) * pen.Size.X, 3, rng:NextNumber(-0.35, 0.35) * pen.Size.Z)
	p:SetAttribute("Design", HttpService:JSONEncode(design))
	p:SetAttribute("Rarity", rarity)
	p:SetAttribute("Mutation", mutation)
	p:SetAttribute("Income", income)
	CollectionService:AddTag(p, "ZooAnimal")
	p.Parent = folder
end

local function refreshPlot(player)
	local s = sessions[player]
	if not s or not s.plot then return end
	s.plot.Animals:ClearAllChildren()
	for _, a in s.data.animals do
		if a.eq then spawnAnimal(s.plot.Animals, a.d, a.r, a.m, Config.income(a)) end
	end
	s.plot.Arch.OwnerGui.Rate.Text = "$" .. Config.format(rate(s)) .. "/s"
	-- the plot's upgrade sign and easel read these (ZooClient builds the sign faces)
	local cap = capacity(s)
	s.plot:SetAttribute("CapLevel", s.data.capLevel)
	s.plot:SetAttribute("Capacity", cap)
	s.plot:SetAttribute("NextCost", cap < Config.CAP_MAX and Config.capCost(s.data.capLevel) or 0)
	local newest = s.data.animals[#s.data.animals]
	s.plot:SetAttribute("Latest", newest and HttpService:JSONEncode(newest.d) or nil)
end

local function changed(player)
	refreshPlot(player)
	sync(player, true)
end

local function notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

----- plots -----
local function claimPlot(player)
	for i = 1, 7 do
		local plot = World.Plots["Plot" .. i]
		if not plot:GetAttribute("Owner") then
			plot:SetAttribute("Owner", player.UserId)
			local gui = plot.Arch.OwnerGui
			gui.OwnerName.Text = player.DisplayName
			task.spawn(function()
				local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				if ok and plot:GetAttribute("Owner") == player.UserId then gui.Avatar.Image = img end
			end)
			return plot
		end
	end
	return nil
end

local function freePlot(plot)
	plot:SetAttribute("Owner", nil)
	for _, k in { "CapLevel", "Capacity", "NextCost", "Latest" } do plot:SetAttribute(k, nil) end
	plot.Animals:ClearAllChildren()
	local gui = plot.Arch.OwnerGui
	gui.OwnerName.Text, gui.Rate.Text, gui.Avatar.Image = "Empty Plot", "", ""
end

local function toPlot(player, character)
	local s = sessions[player]
	if s and s.plot then
		task.wait(0.1)
		character:PivotTo(s.plot.Pad.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.pi, 0))
	end
end

----- data -----
local function save(player)
	local s = sessions[player]
	if not s or not s.loaded then return end -- never overwrite a save we failed to read
	s.data.lastSeen = os.time()
	local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), s.data)
	if not ok then warn("[Zoo] save failed for", player.Name, err) end
end

local function ownsPass(player, id)
	if id == 0 then return false end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	return ok and owns
end

local function onJoin(player)
	local s = { data = newData(), loaded = false, passes = {}, lastCreate = 0, lastCall = 0 }
	for attempt = 1, 3 do
		local ok, saved = pcall(store.GetAsync, store, tostring(player.UserId))
		if ok then
			if typeof(saved) == "table" then
				for k, v in newData() do if saved[k] == nil then saved[k] = v end end
				s.data = saved
			end
			s.loaded = true
			break
		end
		warn("[Zoo] load attempt", attempt, "failed:", saved)
		task.wait(attempt)
	end
	-- false = the client plays the intro; it only becomes true when the client reports the intro finished
	player:SetAttribute("IntroDone", s.data.introDone)
	for name, id in Config.PASSES do
		local grant = s.data.passGrants[name] -- set by an admin's /give pass or /take pass (ZooAdmin), for testing
		if grant == nil then s.passes[name] = ownsPass(player, id) else s.passes[name] = grant end
	end
	-- offline earnings: pay up to OFFLINE_HOURS of income for the time away; the client popup only reports it
	if s.loaded and s.data.lastSeen > 0 then
		local away = os.time() - s.data.lastSeen
		local earned = math.floor(rate(s) * math.min(away, Config.OFFLINE_HOURS * 3600))
		if away >= 60 and earned > 0 then
			s.data.cash += earned
			s.offlinePending = earned -- what the OfflineDouble product pays again
			s.offlineNotice = { earned = earned, away = away }
		end
	end
	if not player.Parent then return end -- left while loading
	s.plot = claimPlot(player)
	sessions[player] = s
	if not s.loaded then notify(player, "Couldn't load your save - progress won't be saved this session.", Color3.fromRGB(255, 90, 90)) end
	player.CharacterAdded:Connect(function(c) toPlot(player, c) end)
	if player.Character then toPlot(player, player.Character) end
	changed(player)
end

local function onLeave(player)
	local s = sessions[player]
	if not s then return end
	save(player)
	if s.plot then freePlot(s.plot) end
	sessions[player] = nil
end

----- remotes -----
-- every remote goes through here: needs a loaded session and at most ~8 calls a second per player
local function on(name, handler)
	Remotes[name].OnServerEvent:Connect(function(player, ...)
		local s = sessions[player]
		if not s then return end
		local now = os.clock()
		if now - s.lastCall < 0.12 then return end
		s.lastCall = now
		handler(player, s, ...)
	end)
end

on("IntroDone", function(player, s)
	s.data.introDone = true
	player:SetAttribute("IntroDone", true)
end)

----- admin commands -----
local function isAdmin(player)
	if table.find(Config.ADMINS, player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank == 255
	end
	return player.UserId == game.CreatorId
end

-- /reset: wipes the admin's own save and restarts them as a brand-new player (intro included), for testing
local resetCommand = Instance.new("TextChatCommand")
resetCommand.Name = "ZooResetCommand"
resetCommand.PrimaryAlias = "/reset"
resetCommand.Parent = TextChatService
resetCommand.Triggered:Connect(function(source)
	local player = Players:GetPlayerByUserId(source.UserId)
	local s = player and sessions[player]
	if not s or not isAdmin(player) then return end
	local ok, err = pcall(store.RemoveAsync, store, tostring(player.UserId))
	if not ok then return notify(player, "Reset failed: " .. tostring(err), Color3.fromRGB(255, 90, 90)) end
	s.data, s.loaded, s.offlinePending, s.offlineNotice = newData(), true, nil, nil
	notify(player, "Save wiped - starting fresh.", Color3.fromRGB(255, 220, 80))
	changed(player)
	if player.Character then task.spawn(toPlot, player, player.Character) end
	player:SetAttribute("IntroDone", false)
end)

local function findAnimal(s, id)
	if typeof(id) ~= "string" then return nil end
	for i, a in s.data.animals do
		if a.id == id then return a, i end
	end
	return nil
end

on("Create", function(player, s, raw)
	local design = Render.sanitize(raw)
	if not design then return notify(player, "Draw your animal first!") end
	if #s.data.animals >= Config.MAX_INVENTORY then return notify(player, "Your zoo is full! Release an animal first.") end
	local now = os.clock()
	if now - s.lastCreate < Config.CREATE_COOLDOWN then return notify(player, "Your pencil needs a short rest...") end
	s.lastCreate = now
	-- names are shown to everyone, so they must go through the text filter
	local name = Config.NAMES[rng:NextInteger(1, #Config.NAMES)]
	if design.n:match("%S") then
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(design.n, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if ok and not filtered:find("#", 1, true) then name = filtered end
	end
	if not sessions[player] then return end
	design.n = name
	-- roll 1: rarity, boosted by luck
	local chances, roll, rarity = Config.chances(luck(s)), rng:NextNumber(), 1
	for i = #chances, 1, -1 do
		roll -= chances[i]
		if roll < 0 then rarity = i break end
	end
	-- roll 2: mutation; the current weather (ZooWeather) boosts its own mutation
	local mChances, mroll, mutation = Config.mutationChances(Zoo:GetAttribute("Weather")), rng:NextNumber(), 1
	for i, p in mChances do
		mroll -= p
		if mroll < 0 then mutation = i break end
	end
	-- the judge scores the drawing itself; income = base x stars x rarity x mutation
	local scores, stars = Render.judge(design)
	local starMult, rarityMult, mutMult = Config.STAR_MULT[stars], Config.RARITIES[rarity].rate / Config.BASE_RATE, Config.MUTATIONS[mutation].mult
	local mult = starMult * rarityMult * mutMult
	local income = math.floor(Config.BASE_RATE * mult)
	local animal = { id = HttpService:GenerateGUID(false), d = design, r = rarity, m = mutation, st = stars, inc = income, eq = equippedCount(s) < capacity(s) }
	table.insert(s.data.animals, animal)
	Remotes.Rolled:FireClient(player, {
		name = name, d = design, r = rarity, m = mutation, rChance = chances[rarity], mChance = mChances[mutation],
		scores = scores, stars = stars, starMult = starMult, rarityMult = rarityMult, mutMult = mutMult, mult = mult, inc = income,
	})
	changed(player)
end)

on("Equip", function(player, s, id)
	local a = findAnimal(s, id)
	if not a then return end
	if not a.eq and equippedCount(s) >= capacity(s) then return notify(player, "Enclosure full! Upgrade capacity.") end
	a.eq = not a.eq
	changed(player)
end)

on("EquipBest", function(player, s)
	local sorted = table.clone(s.data.animals)
	table.sort(sorted, function(a, b) return Config.income(a) > Config.income(b) end)
	for i, a in sorted do a.eq = i <= capacity(s) end
	changed(player)
end)

on("Release", function(player, s, id)
	local _, i = findAnimal(s, id)
	if not i then return end
	table.remove(s.data.animals, i)
	changed(player)
end)

-- Safari Sam's stall: selling pays Config.sellPrice; the client only names which animal
on("Sell", function(player, s, id)
	local a, i = findAnimal(s, id)
	if not a then return end
	table.remove(s.data.animals, i)
	local price = Config.sellPrice(a)
	s.data.cash += price
	notify(player, string.format("Sold %s for $%s!", a.d.n, Config.format(price)), Color3.fromRGB(120, 255, 120))
	changed(player)
end)

on("SellAll", function(player, s)
	local keep, total, n = {}, 0, 0
	for _, a in s.data.animals do
		if a.eq then
			table.insert(keep, a)
		else
			total += Config.sellPrice(a)
			n += 1
		end
	end
	if n == 0 then return end
	s.data.animals = keep
	s.data.cash += total
	notify(player, string.format("Sold %d animal%s for $%s!", n, n == 1 and "" or "s", Config.format(total)), Color3.fromRGB(120, 255, 120))
	changed(player)
end)

on("Upgrade", function(player, s, kind)
	local d = s.data
	if kind == "luck" and d.luckLevel < Config.MAX_LUCK_LEVEL then
		local cost = Config.luckCost(d.luckLevel)
		if d.cash < cost then return notify(player, "Not enough cash!") end
		d.cash -= cost
		d.luckLevel += 1
	elseif kind == "cap" and capacity(s) < Config.CAP_MAX then
		local cost = Config.capCost(d.capLevel)
		if d.cash < cost then return notify(player, "Not enough cash!") end
		d.cash -= cost
		d.capLevel += 1
	else
		return
	end
	notify(player, "Upgraded!", Color3.fromRGB(120, 255, 120))
	changed(player)
end)

local function addBoost(s, minutes)
	s.data.boostUntil = math.max(s.data.boostUntil, os.time()) + minutes * 60
end

on("ClaimDaily", function(player, s)
	local d, now = s.data, os.time()
	if now - d.dailyAt < Config.DAILY_COOLDOWN then return end
	if now - d.dailyAt > Config.DAILY_RESET then d.dailyDay = 0 end -- missed a day: streak restarts
	local reward = Config.DAILY[d.dailyDay % #Config.DAILY + 1]
	d.cash += reward.cash or 0
	if reward.luckMin then addBoost(s, reward.luckMin) end
	d.dailyDay += 1
	d.dailyAt = now
	notify(player, "Daily reward claimed!", Color3.fromRGB(255, 220, 80))
	sync(player, true)
end)

on("ClaimFree", function(player, s)
	if s.data.freeClaimed then return end
	if Config.GROUP_ID ~= 0 then
		local ok, inGroup = pcall(player.IsInGroup, player, Config.GROUP_ID)
		if not (ok and inGroup) then return notify(player, "Join the group first!") end
	end
	-- shortcut: the server can't see favorites, so that step is on trust; fine for a one-time free boost
	s.data.freeClaimed = true
	addBoost(s, Config.FREE_LUCK_MINUTES)
	notify(player, "Free 2x luck claimed!", Color3.fromRGB(120, 255, 120))
	sync(player, true)
end)

----- purchases -----
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
	local s = sessions[player]
	if not (bought and s) then return end
	for name, passId in Config.PASSES do
		if passId == id then s.passes[name], s.data.passGrants[name] = true, nil end
	end
	changed(player)
end)

-- shortcut: grants into session data and trusts the leave-save; save before returning PurchaseGranted once products are live at volume
MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local s = player and sessions[player]
	if not s or not s.loaded then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if receipt.ProductId == Config.PRODUCTS.LuckBoost then
		addBoost(s, Config.LUCK_BOOST_MINUTES)
	elseif receipt.ProductId == Config.PRODUCTS.StarterPack then
		s.data.cash += Config.STARTER_PACK.cash
		addBoost(s, Config.STARTER_PACK.luckMin)
	elseif receipt.ProductId == Config.PRODUCTS.OfflineDouble and (s.offlinePending or 0) > 0 then
		s.data.cash += s.offlinePending
		s.offlinePending = 0
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	sync(player, true)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

----- API for the other server scripts (ZooRace); never exposed to clients -----
function Api.session(player) return sessions[player] end
Api.isAdmin = isAdmin
function Api.findAnimal(player, id)
	local s = sessions[player]
	return s and findAnimal(s, id)
end
function Api.rate(player)
	local s = sessions[player]
	return s and rate(s) or 0
end
function Api.giveCash(player, amount)
	local s = sessions[player]
	if not s then return end
	s.data.cash += math.floor(amount)
	sync(player, true)
end
function Api.addLuck(player, minutes)
	local s = sessions[player]
	if not s then return end
	addBoost(s, minutes)
	sync(player, true)
end
function Api.addMoney(player, minutes)
	local s = sessions[player]
	if not s then return end
	s.data.moneyUntil = math.max(s.data.moneyUntil, os.time()) + minutes * 60
	sync(player, true)
end
Api.notify = notify
Api.changed = changed
-- adds a finished animal (ZooAdmin's /give animal); equips it if there is room. false = the zoo is full
function Api.addAnimal(player, animal)
	local s = sessions[player]
	if not s or #s.data.animals >= Config.MAX_INVENTORY then return false end
	animal.eq = equippedCount(s) < capacity(s)
	table.insert(s.data.animals, animal)
	changed(player)
	return true
end

----- loops -----
Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end

game:BindToClose(function()
	for _, p in Players:GetPlayers() do task.spawn(save, p) end
	task.wait(2)
end)

-- showcase animals so the park is never empty (and the intro has something to film)
for _, t in Config.TEMPLATES do
	local eyes = {}
	for i, e in t.eyes do eyes[i] = { e[1], e[2], 2, 2 } end
	local design = { n = t.name, g = Render.encode(Config.templateGrid(t, true)), e = eyes, s = {} }
	spawnAnimal(World.Showcase.Animals, design, 0)
end

task.spawn(function() -- income + leaderboard, once a second
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		local rows = {}
		for player, s in sessions do
			local r = rate(s)
			s.data.cash += r
			sync(player, false)
			table.insert(rows, { player.UserId, player.DisplayName, r })
		end
		table.sort(rows, function(a, b) return a[3] > b[3] end)
		-- the board's faces are drawn by each client (ZooClient "Top Earners board"); only send when the ranking changes
		local json = HttpService:JSONEncode(rows)
		if World.Showcase.Board:GetAttribute("Top") ~= json then World.Showcase.Board:SetAttribute("Top", json) end
		if tick % 120 == 0 then
			for player in sessions do task.spawn(save, player) end
		end
	end
end)
