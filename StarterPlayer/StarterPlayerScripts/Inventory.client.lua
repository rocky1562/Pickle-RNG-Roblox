-- LocalScript: StarterPlayer > StarterPlayerScripts > InventoryUI
-- Displays server-owned counts. Saving between sessions is not implemented yet.
local player = game:GetService("Players").LocalPlayer
local function make(class, properties, parent)
	local object = Instance.new(class)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end
local function round(object)
	make("UICorner", {CornerRadius = UDim.new(0, 12)}, object)
end
local function label(parent, text, size, position)
	return make("TextLabel", {
		Text = text, Size = size, Position = position,
		BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(240, 240, 245),
		Font = Enum.Font.GothamBold, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end
local gui = make("ScreenGui", {
	Name = "ScrapInventory", ResetOnSpawn = false, DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))
local button = make("TextButton", {
	Name = "InventoryButton", Text = "Inventory",
	Position = UDim2.new(0, 16, 0.5, -24), Size = UDim2.fromOffset(140, 48),
	BackgroundColor3 = Color3.fromRGB(255, 210, 60),
	TextColor3 = Color3.fromRGB(22, 25, 32),
	Font = Enum.Font.GothamBold, TextSize = 18, BorderSizePixel = 0,
}, gui)
round(button)
local panel = make("Frame", {
	Name = "InventoryPanel", Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.75),
	BackgroundColor3 = Color3.fromRGB(22, 25, 32), BorderSizePixel = 0,
}, gui)
round(panel)
make("UISizeConstraint", {MaxSize = Vector2.new(520, 440)}, panel)
label(panel, "YOUR SCRAP", UDim2.new(1, -90, 0, 36), UDim2.fromOffset(20, 12))
local summary = label(panel, "0 items collected", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 48))
summary.TextSize = 14
summary.TextColor3 = Color3.fromRGB(165, 175, 190)
local close = make("TextButton", {
	Text = "X", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -56, 0, 10),
	BackgroundColor3 = Color3.fromRGB(45, 50, 62), BorderSizePixel = 0,
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 18,
}, panel)
round(close)
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 1, -104),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6,
}, panel)
make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, list)
local empty = label(panel, "No scrap yet. Search the pile to find loot!",
	UDim2.new(1, -48, 0, 80), UDim2.fromOffset(24, 96))
empty.TextWrapped = true
empty.TextXAlignment = Enum.TextXAlignment.Center
local colors = {
	["Rusty Bolt"] = Color3.fromRGB(200, 200, 200),
	["Copper Wire"] = Color3.fromRGB(200, 200, 200),
	["Broken Phone"] = Color3.fromRGB(90, 230, 120),
	["Old Graphics Card"] = Color3.fromRGB(100, 170, 255),
	["Alien Battery"] = Color3.fromRGB(255, 210, 60),
}
local inventory
local connections = {}
local rows = {}
local function render()
	for _, row in ipairs(rows) do row:Destroy() end
	table.clear(rows)
	local counts = {}
	if inventory then
		for _, value in ipairs(inventory:GetChildren()) do
			if value:IsA("IntValue") and value.Value > 0 then table.insert(counts, value) end
		end
	end
	table.sort(counts, function(a, b) return a.Name < b.Name end)
	local total = 0
	for index, value in ipairs(counts) do
		total = total + value.Value
		local row = make("Frame", {
			Size = UDim2.new(1, -10, 0, 60), LayoutOrder = index,
			BackgroundColor3 = Color3.fromRGB(36, 41, 52), BorderSizePixel = 0,
		}, list)
		round(row)
		local name = label(row, value.Name, UDim2.new(0.7, -16, 1, 0), UDim2.fromOffset(12, 0))
		name.TextColor3 = colors[value.Name] or Color3.new(1, 1, 1)
		name.TextWrapped = true
		name.TextSize = 16
		local quantity = label(row, "x" .. tostring(value.Value),
			UDim2.new(0.3, -12, 1, 0), UDim2.fromScale(0.7, 0))
		quantity.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, row)
	end
	summary.Text = tostring(total) .. " items collected"
	empty.Visible = #counts == 0
end
local function bind(folder)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	inventory = folder
	if folder then
		local function watch(value)
			if value:IsA("IntValue") then
				table.insert(connections, value:GetPropertyChangedSignal("Value"):Connect(render))
				table.insert(connections, value:GetPropertyChangedSignal("Name"):Connect(render))
			end
		end
		table.insert(connections, folder.ChildAdded:Connect(function(value) watch(value); render() end))
		table.insert(connections, folder.ChildRemoved:Connect(render))
		for _, value in ipairs(folder:GetChildren()) do watch(value) end
	end
	render()
end
button.Activated:Connect(function() panel.Visible = not panel.Visible end)
close.Activated:Connect(function() panel.Visible = false end)
player.ChildAdded:Connect(function(child)
	if child.Name == "Inventory" and child:IsA("Folder") then bind(child) end
end)
player.ChildRemoved:Connect(function(child)
	if child == inventory then bind(nil) end
end)
-- The server creates this folder on the first successful search.
bind(player:FindFirstChild("Inventory"))
