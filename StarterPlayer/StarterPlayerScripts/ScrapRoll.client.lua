-- LocalScript: StarterPlayer > StarterPlayerScripts > ScrapRoll
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("ScrapRollResult")
local random = Random.new()
local activeGui
local activeTween
local rollId = 0

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function text(parent, value, size, position, color)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = value,
		TextColor3 = color or Color3.fromRGB(240, 240, 245),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextWrapped = true,
	}, parent)
end

event.OnClientEvent:Connect(function(winner, items)
	rollId = rollId + 1
	local thisRoll = rollId
	if activeTween then activeTween:Cancel() end
	if activeGui then activeGui:Destroy() end

	local gui = make("ScreenGui", {
		Name = "ScrapRoll",
		ResetOnSpawn = false,
		DisplayOrder = 20,
	}, player:WaitForChild("PlayerGui"))
	activeGui = gui

	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 260),
		BackgroundColor3 = Color3.fromRGB(22, 25, 32),
		BorderSizePixel = 0,
	}, gui)
	make("UISizeConstraint", {MaxSize = Vector2.new(660, 260)}, panel)
	make("UICorner", {CornerRadius = UDim.new(0, 16)}, panel)
	text(panel, "PICKLE RNG", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 8))
	local status = text(panel, "Rolling...", UDim2.new(1, -24, 0, 44),
		UDim2.new(0, 12, 1, -52))

	local window = make("Frame", {
		Position = UDim2.new(0, 12, 0, 68),
		Size = UDim2.new(1, -24, 0, 132),
		BackgroundColor3 = Color3.fromRGB(12, 15, 20),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, panel)
	local strip = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, window)

	-- Weighted filler is visual only. The server already awarded the winner.
	local function previewItem()
		local total = 0
		for _, item in ipairs(items) do total = total + item.weight end
		local roll = random:NextNumber(0, total)
		for _, item in ipairs(items) do
			roll = roll - item.weight
			if roll <= 0 then return item end
		end
		return items[#items]
	end

	local winningIndex = 32
	for i = 1, winningIndex + 2 do
		local item = if i == winningIndex then winner else previewItem()
		local card = make("Frame", {
			Position = UDim2.new((i - 1) / 3, 4, 0, 8),
			Size = UDim2.new(1 / 3, -8, 1, -16),
			BackgroundColor3 = Color3.fromRGB(36, 41, 52),
			BorderSizePixel = 0,
		}, strip)
		make("UICorner", {CornerRadius = UDim.new(0, 10)}, card)
		local label = text(card, item.name, UDim2.new(1, -12, 1, -32),
			UDim2.fromOffset(6, 4), item.color)
		label.TextSize = 18
		text(card, tostring(item.weight) .. "%", UDim2.new(1, 0, 0, 24),
			UDim2.new(0, 0, 1, -28), item.color).TextSize = 14
	end

	-- Fixed center marker: the item underneath it is the result.
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 210, 60),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, window)

	local endX = 0.5 - (winningIndex - 0.5) / 3
	local tween = TweenService:Create(strip,
		TweenInfo.new(3.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{Position = UDim2.fromScale(endX, 0)})
	activeTween = tween
	tween:Play()
	tween.Completed:Wait()
	if thisRoll ~= rollId then return end
	status.Text = "You found: " .. winner.name
	status.TextColor3 = winner.color
	task.wait(1.5)
	if thisRoll == rollId then
		gui:Destroy()
		activeGui = nil
		activeTween = nil
	end
end)
