local pile = script.Parent
local prompt = pile:WaitForChild("ProximityPrompt")
local Players = game:GetService("Players")
local random = Random.new()

local cooldowns = {}
local cooldownSeconds = 3

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

local function showResult(player, item)
	local playerGui = player:WaitForChild("PlayerGui")

	-- Replace this player's previous result.
	local previous = playerGui:FindFirstChild("ScrapResult")
	if previous then
		previous:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ScrapResult"
	billboard.Adornee = pile
	billboard.Size = UDim2.fromOffset(320, 80)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	label.BackgroundTransparency = 0.2
	label.Text = "You found:\n" .. item.name
	label.TextColor3 = item.color
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	billboard.Parent = playerGui

	task.delay(3, function()
		billboard:Destroy()
	end)
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
