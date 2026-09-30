-- Script: ServerScriptService > UpgradeSystem
-- Session-only upgrades. The server checks prices, balance, and distance.
local Players = game:GetService("Players")
local costs = {50, 150, 400}
local speeds = {1.25, 1.5, 2}
local function initialize(player)
	if player:GetAttribute("SearchLevel") == nil then
		player:SetAttribute("SearchLevel", 0)
	end
end
Players.PlayerAdded:Connect(initialize)
for _, player in ipairs(Players:GetPlayers()) do initialize(player) end

local station = workspace:WaitForChild("UpgradeStation", 30)
if not station or not station:IsA("BasePart") then
	warn("UpgradeSystem: Add a Part named UpgradeStation directly inside Workspace.")
	return
end
local prompt = station:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.Parent = station
end
prompt.ActionText = "Buy Next Search Upgrade"
prompt.ObjectText = "Search Speed"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 1
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Enabled = true

local sign = Instance.new("BillboardGui")
sign.Name = "UpgradePrices"
sign.Adornee = station
sign.Size = UDim2.fromOffset(300, 110)
sign.StudsOffset = Vector3.new(0, station.Size.Y / 2 + 3, 0)
sign.AlwaysOnTop = true
sign.MaxDistance = 35
sign.Parent = station
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
label.BackgroundTransparency = 0.15
label.TextColor3 = Color3.fromRGB(255, 210, 60)
label.TextSize = 18
label.Font = Enum.Font.GothamBold
label.Text = "SEARCH SPEED\nLevel 1: 50 Coins (1.25x)\nLevel 2: 150 Coins (1.5x)\nLevel 3: 400 Coins (2x)"
label.Parent = sign

local function notify(player, message)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local old = playerGui:FindFirstChild("UpgradeMessage")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UpgradeMessage"
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


local lastPurchase = {}
prompt.Triggered:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not prompt.Enabled or not root or not humanoid or humanoid.Health <= 0 then return end
	if (root.Position - station.Position).Magnitude > prompt.MaxActivationDistance then return end
	local now = os.clock()
	if lastPurchase[player] and now - lastPurchase[player] < 1.2 then return end
	lastPurchase[player] = now
	local level = player:GetAttribute("SearchLevel") or 0
	if level >= #costs then
		notify(player, "Search speed is MAX LEVEL (2x)!")
		return
	end
	local nextLevel = level + 1
	local cost = costs[nextLevel]
	if not cost then return end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins or not coins:IsA("IntValue") then
		notify(player, "Coins are not ready yet. Try again.")
		return
	end
	if coins.Value < cost then
		notify(player, "Level " .. nextLevel .. " costs " .. cost
			.. " Coins. You need " .. (cost - coins.Value) .. " more!")
		return
	end
	-- No yielding between checking funds, charging, and granting the level.
	coins.Value = coins.Value - cost
	player:SetAttribute("SearchLevel", nextLevel)
	notify(player, "Search level " .. nextLevel .. " purchased! "
		.. speeds[nextLevel] .. "x animation speed (-" .. cost .. " Coins)")
end)
Players.PlayerRemoving:Connect(function(player)
	lastPurchase[player] = nil
end)
