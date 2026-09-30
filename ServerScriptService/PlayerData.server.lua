-- Script: ServerScriptService > PlayerData
-- Owns Coins, Inventory, and SearchLevel initialization.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local storeName = RunService:IsStudio() and "PickleRNG_Studio_v1" or "PickleRNG_Live_v1"
local dataStore = DataStoreService:GetDataStore(storeName)
local sessions = {}
local closing = false
local loading = 0
local LEASE = 180

local function integer(value, maximum)
	return type(value) == "number" and value == value and value >= 0
		and value <= maximum and value % 1 == 0
end
local function valid(data)
	if type(data) ~= "table" or data.Version ~= 1
		or not integer(data.Coins, 1e12) or not integer(data.SearchLevel, 3)
		or type(data.Inventory) ~= "table" then return false end
	for name, count in pairs(data.Inventory) do
		if type(name) ~= "string" or not integer(count, 1e9) then return false end
	end
	return true
end
local function blank()
	return {Version = 1, Coins = 0, SearchLevel = 0, Inventory = {}}
end
local function snapshot(player)
	local inventory = {}
	for _, count in ipairs(player.Inventory:GetChildren()) do
		if count:IsA("IntValue") then inventory[count.Name] = count.Value end
	end
	return {
		Version = 1, Coins = player.leaderstats.Coins.Value,
		SearchLevel = player:GetAttribute("SearchLevel"), Inventory = inventory,
	}
end

local function save(player, release)
	local session = sessions[player]
	if not session then return false end
	if release then
		player:SetAttribute("DataLoaded", false)
		session.ending = true
	end
	while session.busy do task.wait(0.05) end
	if sessions[player] ~= session then return false end
	if session.ending and not release then return false end
	session.busy = true
	local data = session.finalData or snapshot(player)
	if release then session.finalData = data end
	local success = false
	if valid(data) then
		for attempt = 1, 3 do
			local accepted = false
			local ok, result = pcall(function()
				return dataStore:UpdateAsync(session.key, function(old)
					accepted = false
					if type(old) ~= "table" or type(old.Session) ~= "table"
						or old.Session.Id ~= session.id then return nil end
					local nextData = table.clone(data)
					nextData.LastSave = os.time()
					if not release then
						nextData.Session = {Id = session.id, Expires = os.time() + LEASE}
					else
						nextData.Session = nil
						nextData.LastRelease = session.id
					end
					accepted = true
					return nextData
				end)
			end)
			if ok and accepted and result then success = true; break end
			-- A previous release might have committed despite a lost response.
			if ok and not accepted then break end
			warn("[PlayerData] Save attempt failed for " .. player.UserId .. ": " .. tostring(result))
			if attempt < 3 then task.wait(attempt) end
		end
	else
		warn("[PlayerData] Invalid in-memory data; refusing to overwrite save for " .. player.UserId)
	end
	session.busy = false
	if success then
		session.lastSuccess = os.clock()
		print("[PlayerData] Saved " .. player.Name .. " (" .. storeName .. ")")
	end
	if release then sessions[player] = nil end
	return success
end

local function loadPlayer(player)
	if sessions[player] then return end
	loading = loading + 1
	player:SetAttribute("DataLoaded", false)
	local id = HttpService:GenerateGUID(false)
	local key = "Player_" .. player.UserId
	local loaded
	for attempt = 1, 5 do
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, function(old)
				local data = old
				if data == nil then data = blank() end
				if not valid(data) then error("Unrecognized saved data; load cancelled") end
				if data.Session and data.Session.Id ~= id
					and data.Session.Expires > os.time() then return nil end
				data = table.clone(data)
				data.Session = {Id = id, Expires = os.time() + LEASE}
				return data
			end)
		end)
		if ok and result and result.Session and result.Session.Id == id then
			loaded = result
			break
		end
		warn("[PlayerData] Load pending/failed for " .. player.UserId .. ": " .. tostring(result))
		if closing or player.Parent ~= Players then break end
		task.wait(2)
	end
	if not loaded then
		loading = loading - 1
		if player.Parent == Players then
			player:Kick("Your progress could not be loaded safely. Please rejoin in a moment.")
		end
		return
	end
	local session = {key = key, id = id, busy = false, lastSuccess = os.clock()}
	sessions[player] = session
	if closing or player.Parent ~= Players then
		session.finalData = loaded
		save(player, true)
		loading = loading - 1
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = loaded.Coins
	coins.Parent = stats
	stats.Parent = player
	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	for name, amount in pairs(loaded.Inventory) do
		local count = Instance.new("IntValue")
		count.Name = name
		count.Value = amount
		count.Parent = inventory
	end
	inventory.Parent = player
	player:SetAttribute("SearchLevel", loaded.SearchLevel)
	player:SetAttribute("DataLoaded", true)
	loading = loading - 1
	print("[PlayerData] Loaded " .. player.Name .. " (" .. storeName .. ")")
	task.spawn(function()
		while sessions[player] == session and not closing and not session.ending do
			task.wait(30)
			if sessions[player] ~= session or closing or session.ending then break end
			if not save(player, false) and os.clock() - session.lastSuccess > 90 then
				player:SetAttribute("DataLoaded", false)
				player:Kick("Saving is temporarily unavailable. Please rejoin shortly.")
				break
			end
		end
	end)
end
Players.PlayerAdded:Connect(loadPlayer)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, player) end
Players.PlayerRemoving:Connect(function(player)
	save(player, true)
end)
game:BindToClose(function()
	closing = true
	for player in pairs(sessions) do
		player:SetAttribute("DataLoaded", false)
		task.spawn(save, player, true)
	end
	local deadline = os.clock() + 25
	while (next(sessions) or loading > 0) and os.clock() < deadline do task.wait(0.1) end
end)
