--!nonstrict
-- ZooRace: animal races round the gravel loop on the outskirts. Players queue at the pad inside the gate with one of
-- their animals; once enough are queued they are put on the starting grid, seated on a cutout of that animal built as a
-- little car, a countdown runs, and they race Config.RACE.LAPS laps. The driver's client steers the car (it owns its
-- physics); the server sets each car's top speed ("Top": normal, boost or mud), so boost rings make the difference, mud
-- slows you down and logs, hay and rocks are in the way. The winner spins the prize wheel, every other finisher gets cash.
-- The server owns progress, rings, mud, places and prizes, and counts no progress faster than a boost could go.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Zoo = ReplicatedStorage:WaitForChild("Zoo")
local Config = require(Zoo.Config)
local L = require(Zoo.RaceLayout)
local Remotes = Zoo.Remotes
local Api = require(script.Parent.ZooApi)
local R = Config.RACE
local RACE = workspace:WaitForChild("Zoo"):WaitForChild("Race")

-- shortcut: in Studio one tester may race alone; live servers need R.MIN_PLAYERS
local MIN = RunService:IsStudio() and 1 or R.MIN_PLAYERS
local LAP_DEG = 360

while not Api.session do task.wait() end -- ZooServer fills the API in when it starts

local ringFrames, mudFrames = {}, {}
for _, r in L.RINGS do table.insert(ringFrames, L.frame(r[1], r[2])) end
for _, o in L.OBSTACLES do if o[1] == "RaceMud" then table.insert(mudFrames, L.frame(o[2], o[3])) end end

local queue = {} -- { { player, id } } in join order
local racers = {} -- [player] = racer
local finished = {} -- players in finishing order
local phase, phaseEnds = "idle", 0
local lastCall = {}

local function now() return workspace:GetServerTimeNow() end
local function queued(player)
	for i, q in queue do if q.player == player then return i end end
	return nil
end

----- status: one broadcast for everyone, the pad board, and a per-racer line -----
local boardText
local function board(text)
	if text == boardText then return end
	boardText = text
	for _, d in RACE.Pad:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Status" then d.Text = text end
	end
end

local function broadcast()
	local q, r = {}, {}
	for _, e in queue do table.insert(q, e.player.UserId) end
	for p in racers do table.insert(r, p.UserId) end
	Remotes.RaceState:FireAllClients({ phase = phase, ends = phaseEnds, queue = q, racers = r, min = MIN, max = R.MAX_PLAYERS, laps = R.LAPS })
	if phase == "idle" then
		board(#queue == 0 and "Race on your animal!" or string.format("%d/%d racers - need %d", #queue, R.MAX_PLAYERS, MIN))
	elseif phase == "countdown" then
		board("Starting now!")
	else
		board(string.format("Race on! %d racing", #r))
	end
end

----- the ride: a car built round a cutout of the animal; the player sits on its back -----
local function unmount(player, rc)
	local hum = rc.hum
	if rc.car then rc.car:Destroy() end -- the seat goes with it, so the player is standing again
	if hum and hum.Parent then hum.JumpHeight, hum.JumpPower = rc.saved.jumpH, rc.saved.jumpP end
end

local function mount(player, animal, cf)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) or hum.Health <= 0 then return nil end
	local k = 1 + (animal.r or 1) * 0.06
	local w, h = 7.5 * k, 5.2 * k
	local car = Instance.new("Model")
	car.Name = "RaceCar"
	-- body: the only part that collides, a low box under the cutout with no friction, so it glides on the gravel
	local body = Instance.new("Part")
	body.Name, body.Size, body.Transparency, body.Anchored = "Body", Vector3.new(3.2, 2, w * 0.85), 1, true
	body.CanQuery, body.CanTouch = false, false
	body.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	body.CFrame = cf * CFrame.new(0, 1.15, 0)
	body.Parent = car
	-- the drawing (ZooClient draws both faces and makes it hop); its +X edge is the head, turned to face forward
	local cut = Instance.new("Part")
	cut.Name, cut.Size, cut.Transparency, cut.Massless = "RaceMount", Vector3.new(w, h, 0.05), 1, true
	cut.CanCollide, cut.CanQuery, cut.CanTouch = false, false, false
	cut.CFrame = cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)
	cut:SetAttribute("Design", HttpService:JSONEncode(animal.d))
	cut:SetAttribute("Rarity", animal.r)
	local mw = Instance.new("Weld")
	mw.Name, mw.Part0, mw.Part1, mw.C0 = "MountWeld", body, cut, body.CFrame:ToObjectSpace(cut.CFrame)
	mw.Parent = cut
	cut.Parent = car
	-- the seat rides on the cutout's back, so the rider hops with it; VehicleSeat gives the client throttle and steer
	local seat = Instance.new("VehicleSeat")
	seat.Name, seat.Size, seat.Transparency, seat.Massless = "Seat", Vector3.new(2, 0.4, 2), 1, true
	seat.CanCollide, seat.CanQuery, seat.CanTouch = false, false, false
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed, seat.HeadsUpDisplay = 0, 0, 0, false
	seat.CFrame = cf * CFrame.new(0, h - 0.15, 0.4)
	local sw = Instance.new("WeldConstraint")
	sw.Part0, sw.Part1 = cut, seat
	sw.Parent = seat
	seat.Parent = car
	-- the client drives these two: speed along the ground (gravity stays free) and the heading, kept upright
	local att = Instance.new("Attachment")
	att.Parent = body
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0, lv.RelativeTo, lv.VelocityConstraintMode = att, Enum.ActuatorRelativeTo.World, Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis, lv.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	lv.MaxForce, lv.PlaneVelocity = 60000, Vector2.zero
	lv.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Mode, ao.Attachment0, ao.MaxTorque, ao.Responsiveness, ao.CFrame = Enum.OrientationAlignmentMode.OneAttachment, att, 1e7, 30, cf.Rotation
	ao.Parent = body
	car.PrimaryPart = body
	car:SetAttribute("Owner", player.UserId)
	car:SetAttribute("Top", 0)
	car.Parent = RACE
	CollectionService:AddTag(cut, "RaceMount")
	CollectionService:AddTag(car, "RaceCar")
	local saved = { jumpH = hum.JumpHeight, jumpP = hum.JumpPower }
	hum.JumpHeight, hum.JumpPower = 0, 0
	char:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
	seat:Sit(hum)
	return { car = car, body = body, seat = seat, hum = hum, saved = saved }
end

----- joining -----
local function addRacer(entry, slot)
	local player = entry.player
	local animal = Api.findAnimal(player, entry.id)
	if not animal then
		Api.notify(player, "That animal isn't in your zoo any more.")
		return false
	end
	local g = L.GRID[slot]
	local rc = mount(player, animal, L.frame(g[1], g[2]))
	if not rc then
		Api.notify(player, "Couldn't start your race - respawn and try again.")
		return false
	end
	rc.slot, rc.lastA, rc.lastPos = slot, g[1], rc.body.Position
	rc.progress = ((g[1] - L.START_A + 180) % 360) - 180 -- just behind the line: a little negative
	rc.boostUntil, rc.ringAt, rc.speed, rc.name = 0, {}, 0, animal.d.n
	racers[player] = rc
	return true
end

local function fillGrid()
	local used = {}
	for _, rc in racers do used[rc.slot] = true end
	while #queue > 0 do
		local slot
		for i = 1, math.min(R.MAX_PLAYERS, #L.GRID) do if not used[i] then slot = i break end end
		if not slot then return end
		local entry = table.remove(queue, 1)
		if entry.player.Parent and addRacer(entry, slot) then used[slot] = true end
	end
end

local function drop(player, why)
	local rc = racers[player]
	if not rc then return end
	racers[player] = nil
	unmount(player, rc)
	if why then Api.notify(player, why) end
end

----- prizes -----
local function pickSlice()
	local total = 0
	for _, s in R.WHEEL do total += s.weight end
	local roll = Random.new():NextNumber() * total
	for i, s in R.WHEEL do
		roll -= s.weight
		if roll < 0 then return i end
	end
	return #R.WHEEL
end

local function income(player) return math.max(Api.rate(player), Config.BASE_RATE) end -- a fresh zoo still wins something

local function spin(player)
	local i = pickSlice()
	local s = R.WHEEL[i]
	local text
	if s.cash then
		local amount = math.floor(income(player) * s.cash)
		Api.giveCash(player, amount)
		text = "+$" .. Config.format(amount)
	elseif s.luck then
		Api.addLuck(player, s.luck)
		text = "2x LUCK for " .. s.luck .. " min!"
	elseif s.money then
		Api.addMoney(player, s.money)
		text = "2x MONEY for " .. s.money .. " min!"
	end
	Remotes.RaceSpin:FireClient(player, i, text) -- the reward is already paid; the client just plays the wheel
end

local function finish(player, rc)
	table.insert(finished, player)
	local place = #finished
	drop(player)
	Remotes.RaceInfo:FireClient(player, { finished = place })
	if place == 1 then
		phaseEnds = math.min(phaseEnds, now() + R.AFTER_WINNER)
		spin(player)
		for p in racers do Api.notify(p, player.DisplayName .. " won! Finish for a prize!", Color3.fromRGB(255, 220, 80)) end
	else
		local amount = math.floor(income(player) * R.CONSOLATION_SECONDS)
		Api.giveCash(player, amount)
		Api.notify(player, string.format("You finished #%d! +$%s", place, Config.format(amount)), Color3.fromRGB(120, 255, 120))
	end
end

local function endRace()
	for p in racers do drop(p, "Time's up! Finish faster next race.") end
	finished = {}
	phase, phaseEnds = "idle", 0
	broadcast()
end

----- remotes -----
local function limited(player)
	local t = os.clock()
	if t - (lastCall[player] or 0) < 0.3 then return true end
	lastCall[player] = t
	return false
end

Remotes.RaceJoin.OnServerEvent:Connect(function(player, id)
	if limited(player) or typeof(id) ~= "string" or not Api.session(player) then return end
	if racers[player] or queued(player) then return end
	if not Api.findAnimal(player, id) then return Api.notify(player, "Pick one of your animals first!") end
	table.insert(queue, { player = player, id = id })
	Api.notify(player, phase == "racing" and "Queued for the next race!" or "You're in the race queue!", Color3.fromRGB(120, 255, 120))
	broadcast()
end)

Remotes.RaceLeave.OnServerEvent:Connect(function(player)
	if limited(player) then return end
	local i = queued(player)
	if i then table.remove(queue, i) end
	if racers[player] then drop(player, "You left the race.") end
	broadcast()
end)

Players.PlayerRemoving:Connect(function(player)
	local i = queued(player)
	if i then table.remove(queue, i) end
	local rc = racers[player]
	if rc and rc.car then rc.car:Destroy() end
	racers[player] = nil
	lastCall[player] = nil
end)

----- the race loop, ten times a second -----
local function ringPass(rc, a0, a1, i)
	-- crossed the ring's plane going forward (+Z to -Z in the ring's frame) inside the hoop
	if not (a0.Z >= 0 and a1.Z < 0) then return false end
	local t = a0.Z / (a0.Z - a1.Z)
	local x, y = a0.X + (a1.X - a0.X) * t, a0.Y + (a1.Y - a0.Y) * t
	return math.abs(x) < 4.8 and y < 11
end

local function step(dt)
	local t = now()
	for player, rc in racers do
		if not (player.Parent and rc.body.Parent and rc.hum.Parent and rc.hum.Health > 0) then
			racers[player] = nil -- died, reset or left
			if rc.car then rc.car:Destroy() end
			continue
		end
		if rc.seat.Occupant ~= rc.hum then -- hopped off somehow: back in the saddle
			rc.hum.Parent:PivotTo(rc.seat.CFrame * CFrame.new(0, 2.5, 0))
			rc.seat:Sit(rc.hum)
		end
		local pos = rc.body.Position
		local a = L.angle(pos)
		local r = Vector2.new(pos.X, pos.Z).Magnitude
		local d = ((a - rc.lastA + 180) % 360) - 180
		-- only count what a racer could really have run: on the loop, and no faster than a boost
		local maxDeg = math.deg(R.BOOST_SPEED * dt * 1.6 / 130) + 0.5
		if r > 125 and r < 195 and math.abs(d) <= maxDeg then rc.progress += d end
		rc.lastA = a
		if phase == "racing" then
			for i, f in ringFrames do
				if t - (rc.ringAt[i] or 0) > 3 and ringPass(rc, f:PointToObjectSpace(rc.lastPos), f:PointToObjectSpace(pos), i) then
					rc.ringAt[i], rc.boostUntil = t, t + R.BOOST_SECONDS
					Remotes.RaceInfo:FireClient(player, { boost = R.BOOST_SECONDS })
				end
			end
			local inMud = false
			for _, f in mudFrames do
				local p = f:PointToObjectSpace(pos)
				if (p.X / L.MUD_RX) ^ 2 + (p.Z / L.MUD_RZ) ^ 2 < 1 then inMud = true break end
			end
			local speed = t < rc.boostUntil and R.BOOST_SPEED or inMud and R.MUD_SPEED or R.TOP_SPEED
			if speed ~= rc.speed then
				rc.speed = speed
				rc.car:SetAttribute("Top", speed) -- the driver's client accelerates or slows toward it
				if inMud and speed == R.MUD_SPEED then Remotes.RaceInfo:FireClient(player, { mud = true }) end
			end
			if rc.progress >= LAP_DEG * R.LAPS then finish(player, rc) end
		end
		rc.lastPos = pos
	end
end

local function places()
	local list = {}
	for p, rc in racers do table.insert(list, { p, rc.progress }) end
	table.sort(list, function(x, y) return x[2] > y[2] end)
	for i, e in list do
		local rc = racers[e[1]]
		Remotes.RaceInfo:FireClient(e[1], { place = #finished + i, count = #finished + #list, lap = math.clamp(math.floor(rc.progress / LAP_DEG) + 1, 1, R.LAPS), laps = R.LAPS })
	end
end

task.spawn(function()
	local last, lastInfo, lastBroadcast = os.clock(), 0, 0
	while true do
		task.wait(0.1)
		local c = os.clock()
		local dt = c - last
		last = c
		if phase == "idle" then
			if #queue >= MIN then
				phase, phaseEnds = "countdown", now() + R.COUNTDOWN
				fillGrid()
				if next(racers) == nil then phase = "idle" end
				broadcast()
			end
		elseif phase == "countdown" then
			fillGrid() -- late joiners still get a spot while the lights count down
			if next(racers) == nil then
				phase = "idle"
				broadcast()
			elseif now() >= phaseEnds then
				phase, phaseEnds = "racing", now() + R.TIME_LIMIT
				for p, rc in racers do -- release the cars and hand each one's physics to its driver
					rc.speed = R.TOP_SPEED
					rc.car:SetAttribute("Top", R.TOP_SPEED)
					rc.body.Anchored = false
					pcall(rc.body.SetNetworkOwner, rc.body, p)
				end
				broadcast()
			end
		end
		step(dt)
		if phase == "racing" then
			if next(racers) == nil or now() >= phaseEnds then endRace() end
		end
		if phase ~= "idle" and c - lastInfo > 0.5 then
			lastInfo = c
			places()
		end
		if c - lastBroadcast > 2 then -- late joiners to the server catch up
			lastBroadcast = c
			broadcast()
		end
	end
end)
