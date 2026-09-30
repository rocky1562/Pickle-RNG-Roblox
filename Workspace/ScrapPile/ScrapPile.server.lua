local pile = script.Parent
local prompt = pile:WaitForChild("ProximityPrompt")
local Players = game:GetService("Players")
local random = Random.new()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rollEvent = ReplicatedStorage:FindFirstChild("ScrapRollResult")
if not rollEvent then
	rollEvent = Instance.new("RemoteEvent")
	rollEvent.Name = "ScrapRollResult"
	rollEvent.Parent = ReplicatedStorage
end
assert(rollEvent:IsA("RemoteEvent"), "ScrapRollResult must be a RemoteEvent")

local cooldowns = {}
local cooldownSeconds = 5.5 -- 3.5-second spin + 1.5-second result + a small buffer.

-- Weights add up to 100, so these are percentage chances.
local items = {
	{name = "Rusty Bolt", weight = 50, color = Color3.fromRGB(200, 200, 200)},
	{name = "Copper Wire", weight = 30, color = Color3.fromRGB(200, 200, 200)},
	{name = "Broken Phone", weight = 15, color = Color3.fromRGB(90, 230, 120)},
	{name = "Old Graphics Card", weight = 4, color = Color3.fromRGB(100, 170, 255)},
	{name = "Alien Battery", weight = 1, color = Color3.fromRGB(255, 210, 60)},
}

local function chooseItem()
	local roll = random:NextInteger(1, 100)
	local total = 0

	for _, item in ipairs(items) do
		total = total + item.weight
		if roll <= total then
			return item
		end
	end
end

-- Only the server chooses and awards loot; the client animates the result.
local function showResult(player, item)
	rollEvent:FireClient(player, item, items)
end

prompt.Triggered:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not prompt.Enabled or not root or not humanoid then
		return
	end

	if humanoid.Health <= 0 then
		return
	end

	if (root.Position - pile.Position).Magnitude > prompt.MaxActivationDistance then
		return
	end

	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < cooldownSeconds then
		return
	end
	cooldowns[player] = now

	local item = chooseItem()

	-- Store item counts in a temporary inventory.
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		inventory = Instance.new("Folder")
		inventory.Name = "Inventory"
		inventory.Parent = player
	end

	local count = inventory:FindFirstChild(item.name)
	if not count then
		count = Instance.new("IntValue")
		count.Name = item.name
		count.Parent = inventory
	end

	count.Value = count.Value + 1
	showResult(player, item)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
