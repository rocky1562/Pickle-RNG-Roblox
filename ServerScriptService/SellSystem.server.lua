-- Script: ServerScriptService > SellSystem
-- Session-only Coins and server-validated selling.
local Players = game:GetService("Players")

local prices = {
	["Dill Pickle"] = 1,
	["Sweet Pickle"] = 3,
	["Spicy Pickle"] = 10,
	["Golden Pickle"] = 50,
	["Cosmic Pickle"] = 250,
}
local function setupCoins(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local coins = stats:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = stats
	end
	return coins
end
Players.PlayerAdded:Connect(setupCoins)
for _, player in ipairs(Players:GetPlayers()) do setupCoins(player) end

local station = workspace:WaitForChild("SellStation", 30)
if not station or not station:IsA("BasePart") then
	warn("SellSystem: Add a Part named SellStation directly inside Workspace.")
	return
end
-- The sell pad uses a server-side zone above its top surface.
for _, child in ipairs(station:GetDescendants()) do
	if child:IsA("ProximityPrompt") then child:Destroy() end
end
local inside = {}
local function isOnPad(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	local position = station.CFrame:PointToObjectSpace(root.Position)
	local half = station.Size / 2
	return math.abs(position.X) <= half.X
		and math.abs(position.Z) <= half.Z
		and position.Y >= half.Y - 0.5
		and position.Y <= half.Y + 6
end

local function notify(player, message)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local old = playerGui:FindFirstChild("SellMessage")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SellMessage"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.new(0.85, 0, 0, 64)
	label.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextWrapped = true
	label.Text = message
	label.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(520, 64)
	constraint.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	gui.Parent = playerGui
	task.delay(3, function() gui:Destroy() end)
end

local function sellAll(player)
	if not isOnPad(player) then return end
	local inventory = player:FindFirstChild("Inventory")
	local coins = setupCoins(player)
	local sold = {}
	local total, quantity = 0, 0
	if inventory then
		for _, count in ipairs(inventory:GetChildren()) do
			local price = prices[count.Name]
			if count:IsA("IntValue") and price and count.Value > 0 then
				total = total + count.Value * price
				quantity = quantity + count.Value
				table.insert(sold, count)
			end
		end
	end
	if total == 0 then
		notify(player, "No pickles to sell. Search the barrel first!")
		return
	end
	-- No yielding between reading, clearing, and crediting the inventory.
	-- Unknown items are kept instead of being deleted without payment.
	for _, count in ipairs(sold) do count.Value = 0 end
	coins.Value = coins.Value + total
	notify(player, "Sold " .. quantity .. " pickles for +" .. total .. " Coins!")
end

Players.PlayerRemoving:Connect(function(player)
	inside[player] = nil
end)

-- Sell once on entry, not repeatedly while a player stands on the pad.
-- Position checks avoid multiple limb touch events and missed spawn-on-pad events.
while station:IsDescendantOf(workspace) do
	for _, player in ipairs(Players:GetPlayers()) do
		local onPad = isOnPad(player)
		local character = player.Character
		if onPad then
			if inside[player] ~= character then
				inside[player] = character
				sellAll(player)
			end
		else
			inside[player] = nil
		end
	end
	task.wait(0.15)
end
