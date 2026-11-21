--!nonstrict
-- ZooWeather: random server-wide weather (Config.WEATHERS). The current one lives in two attributes on ReplicatedStorage.Zoo:
-- Weather (its name, nil when clear) and WeatherEnds (workspace:GetServerTimeNow() when it stops). ZooServer's roll reads
-- Weather to boost that weather's mutation; ZooClient reads both to draw the sky, the rain and the banner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Zoo = ReplicatedStorage:WaitForChild("Zoo")
local Config = require(Zoo.Config)
local Api = require(script.Parent.ZooApi)
local rng = Random.new()

local phaseEnd = 0 -- os.clock() when the current weather (or calm gap) is over

local function start(w)
	local secs = rng:NextInteger(w.duration[1], w.duration[2])
	Zoo:SetAttribute("WeatherEnds", workspace:GetServerTimeNow() + secs) -- before Weather, so clients see both together
	Zoo:SetAttribute("Weather", w.name)
	phaseEnd = os.clock() + secs
end

local function clear()
	Zoo:SetAttribute("Weather", nil)
	Zoo:SetAttribute("WeatherEnds", nil)
	phaseEnd = os.clock() + rng:NextInteger(Config.WEATHER_GAP[1], Config.WEATHER_GAP[2])
end

local function pick()
	local total = 0
	for _, w in Config.WEATHERS do total += w.weight end
	local roll = rng:NextNumber() * total
	for _, w in Config.WEATHERS do
		roll -= w.weight
		if roll < 0 then return w end
	end
	return Config.WEATHERS[1]
end

-- /weather [name]: admins start a weather now (the first one if no name), /weather off clears it. For testing.
local command = Instance.new("TextChatCommand")
command.Name = "ZooWeatherCommand"
command.PrimaryAlias = "/weather"
command.Parent = TextChatService
command.Triggered:Connect(function(source, text)
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player or not Api.isAdmin or not Api.isAdmin(player) then return end
	local arg = (text:match("^%S+%s+(%S+)") or ""):lower()
	if arg == "off" then return clear() end
	for _, w in Config.WEATHERS do
		if arg == "" or w.name:lower() == arg then return start(w) end
	end
	Api.notify(player, "No weather called " .. arg)
end)

clear()
while true do
	task.wait(1)
	if os.clock() >= phaseEnd then
		if Zoo:GetAttribute("Weather") then clear() else start(pick()) end
	end
end
