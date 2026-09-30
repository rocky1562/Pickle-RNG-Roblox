local pile = script.Parent
local prompt = pile:WaitForChild("ProximityPrompt")
prompt.ActionText = "Search for Pickles"
prompt.ObjectText = "Pickle Barrel"
local Players = game:GetService("Players")
local random = Random.new()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rollEvent = ReplicatedStorage:FindFirstChild("PickleRollResult")
if not rollEvent then
	rollEvent = Instance.new("RemoteEvent")
	rollEvent.Name = "PickleRollResult"
	rollEvent.Parent = ReplicatedStorage
end
assert(rollEvent:IsA("RemoteEvent"), "PickleRollResult must be a RemoteEvent")

local cooldowns = {}
local cooldownSeconds = 5.5 -- 3.5-second spin + 1.5-second result + a small buffer.

-- Weights add up to 100, so these are percentage chances.
local items = {
	{name = "Dill Pickle", weight = 50, color = Color3.fromRGB(200, 200, 200)},
	{name = "Sweet Pickle", weight = 30, color = Color3.fromRGB(200, 200, 200)},
	{name = "Spicy Pickle", weight = 15, color = Color3.fromRGB(90, 230, 120)},
	{name = "Golden Pickle", weight = 4, color = Color3.fromRGB(100, 170, 255)},
	{name = "Cosmic Pickle", weight = 1, color = Color3.fromRGB(255, 210, 60)},
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

local searchAnimation = Instance.new("Animation")
searchAnimation.Name = "SearchPickles"
searchAnimation.AnimationId = "rbxassetid://71576008338045"
searchAnimation.Parent = script

local function playSearch(player, character, humanoid, root)
	local track
	local wasAnchored = root.Anchored
	local wasAutoRotate = humanoid.AutoRotate
	local function isValid()
		return player:GetAttribute("DataLoaded") == true
			and player.Parent == Players and player.Character == character
			and character.Parent ~= nil and humanoid.Health > 0
			and root.Parent ~= nil and pile.Parent ~= nil
	end

	local ok, problem = pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		track = animator:LoadAnimation(searchAnimation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false

		-- Loading has a time limit so an unavailable asset cannot lock the player.
		local loadDeadline = os.clock() + 5
		while track.Length == 0 and os.clock() < loadDeadline do
			if not isValid() then return end
			task.wait(0.05)
		end
		if track.Length == 0 then
			error("Search animation did not load. Check asset permissions and rig type.")
		end
		if not isValid() then return end

		-- Face the pile and hold position only while searching.
		local target = Vector3.new(pile.Position.X, root.Position.Y, pile.Position.Z)
		humanoid.AutoRotate = false
		if (target - root.Position).Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, target)
		end
		root.Anchored = true
		local speeds = {[0] = 1, [1] = 1.25, [2] = 1.5, [3] = 2}
		local speed = speeds[player:GetAttribute("SearchLevel") or 0] or 1
		track:Play(0.15, 1, speed)
		local finishDeadline = os.clock() + math.min(track.Length / speed, 15)
		repeat
			task.wait(0.05)
		until not isValid() or not track.IsPlaying or os.clock() >= finishDeadline
	end)

	-- Always restore movement, including after death, reset, or a loading error.
	if track then
		pcall(function()
			track:Stop(0.15)
			track:Destroy()
		end)
	end
	if root.Parent then root.Anchored = wasAnchored end
	if humanoid.Parent then humanoid.AutoRotate = wasAutoRotate end
	if not ok then warn("[PickleSearch] " .. tostring(problem)) end

	-- If the animation fails to load, searching still works.
	return isValid() and prompt.Enabled
		and (root.Position - pile.Position).Magnitude <= prompt.MaxActivationDistance
end

-- Only the server chooses and awards loot; the client animates the result.
local function showResult(player, item)
	rollEvent:FireClient(player, item, items)
end

prompt.Triggered:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
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
	-- Block repeat prompts during loading and playback.
	cooldowns[player] = math.huge
	local completed = playSearch(player, character, humanoid, root)
	if not completed then
		cooldowns[player] = nil
		return
	end
	-- The reel cooldown starts after the character animation ends.
	cooldowns[player] = os.clock()

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
