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
-- Copy ScrapInventory into StarterGui first. Rename its children as documented.
local gui = player:WaitForChild("PlayerGui"):WaitForChild("ScrapInventory")
local button = gui:WaitForChild("InventoryButton")
local panel = gui:WaitForChild("InventoryPanel")
local summary = panel:WaitForChild("Summary")
local close = panel:WaitForChild("CloseButton")
local list = panel:WaitForChild("ItemList")
local empty = panel:WaitForChild("EmptyMessage")
panel.Visible = false

-- Remove any sample loot rows captured when copying the UI during a playtest.
for _, child in ipairs(list:GetChildren()) do
	if child:IsA("Frame") then child:Destroy() end
end
-- Layout, colors, fonts, and button text come from your StarterGui objects.
-- Item rows are still generated from the live inventory below.
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
