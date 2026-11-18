-- Client-only: pulses each waterfall's ripple ring outwards across the pond (three staggered copies).
-- The rings are tagged "WaterfallRipple" by ServerStorage.EnclosureBuilder.
local CS = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local PERIOD = 1.8

local function animate(ring)
	local base = ring.Size
	ring.Transparency = 1 -- the template ring stays still; its copies do the moving
	for k = 0, 2 do
		local r = ring:Clone()
		r.Name = "RippleFX"
		CS:RemoveTag(r, "WaterfallRipple")
		r.Parent = ring.Parent
		task.spawn(function()
			task.wait(k * PERIOD / 3)
			local info = TweenInfo.new(PERIOD, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			while r.Parent do
				r.Size, r.Transparency = Vector3.new(base.X * 0.55, base.Y, base.Z * 0.55), 0.15
				local t = TweenService:Create(r, info, { Size = Vector3.new(base.X * 1.35, base.Y, base.Z * 1.35), Transparency = 1 })
				t:Play()
				t.Completed:Wait()
			end
		end)
	end
end

for _, ring in CS:GetTagged("WaterfallRipple") do task.spawn(animate, ring) end
CS:GetInstanceAddedSignal("WaterfallRipple"):Connect(animate)

-- Irregular gushes: every waterfall's "Burst" emitters (Rate 0, tagged "WaterfallBurst") fire a random handful at random
-- moments, so the splash never settles into a steady loop.
local rng = Random.new()
local function gush(emitter)
	while emitter.Parent do
		task.wait(rng:NextNumber(0.25, 1.2))
		emitter:Emit(rng:NextInteger(2, 9))
	end
end
for _, e in CS:GetTagged("WaterfallBurst") do task.spawn(gush, e) end
CS:GetInstanceAddedSignal("WaterfallBurst"):Connect(gush)
