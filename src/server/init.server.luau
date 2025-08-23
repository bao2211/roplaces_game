-- Server script for teleportation parts system
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Import shared modules from ReplicatedStorage
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameData = require(Shared:WaitForChild("GameData"))

-- Create RemoteEvents for client-server communication
local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "RemoteEvents"
remoteEvents.Parent = ReplicatedStorage

local showTpGuiRemote = Instance.new("RemoteEvent")
showTpGuiRemote.Name = "ShowTpGui"
showTpGuiRemote.Parent = remoteEvents

local teleportPlayerRemote = Instance.new("RemoteEvent")
teleportPlayerRemote.Name = "TeleportPlayer"
teleportPlayerRemote.Parent = remoteEvents

local teleportFailedRemote = Instance.new("RemoteEvent")
teleportFailedRemote.Name = "TeleportFailed"
teleportFailedRemote.Parent = remoteEvents

-- Cache for game data
local gameDataCache = {}
local lastCacheUpdate = 0

-- Cooldown system to prevent multiple GUI shows
local playerCooldowns = {} -- Track cooldowns per player
local COOLDOWN_DURATION = 3 -- seconds before player can trigger GUI again

-- Function to fetch game data from Google Sheets
local function fetchGameData()
	Config.debugLog("Attempting to fetch game data from Google Sheets")

	local success, result = pcall(function()
		local response = HttpService:GetAsync(Config.GOOGLE_SCRIPT_URL)
		return HttpService:JSONDecode(response)
	end)

	if success and result and type(result) == "table" then
		-- Validate each game data entry
		local validatedData = {}
		for _, gameInfo in ipairs(result) do
			local validatedGameInfo = GameData.validateGameInfo(gameInfo)
			if validatedGameInfo then
				table.insert(validatedData, validatedGameInfo)
			end
		end

		gameDataCache = validatedData
		lastCacheUpdate = tick()
		Config.debugLog("Game data cache updated successfully with " .. #validatedData .. " entries")
		return validatedData
	else
		warn("Failed to fetch game data from Google Sheets: " .. tostring(result))
		return gameDataCache -- Return cached data if available
	end
end

-- Function to get game data with caching
local function getGameData()
	if tick() - lastCacheUpdate > Config.CACHE_DURATION or #gameDataCache == 0 then
		return fetchGameData()
	end
	return gameDataCache
end

-- Function to find game data by part key
local function findGameDataByKey(partKey)
	local data = getGameData()
	for _, gameInfo in ipairs(data) do
		if gameInfo.part_key == partKey then
			return gameInfo
		end
	end
	return nil
end

-- Function to update server_down count for invalid games
local function updateServerDownCount(partKey)
	local success, result = pcall(function()
		local requestData = {
			action = "update_server_down",
			part_key = partKey
		}
		
		local response = HttpService:PostAsync(
			Config.GOOGLE_SCRIPT_URL, 
			HttpService:JSONEncode(requestData),
			Enum.HttpContentType.ApplicationJson
		)
		return HttpService:JSONDecode(response)
	end)
	
	if success then
		Config.debugLog("Updated server_down count for: " .. partKey)
	else
		warn("Failed to update server_down count for: " .. partKey)
	end
end

-- Function to check if a place exists and is accessible
local function checkPlaceValidity(placeId)
	local success, result = pcall(function()
		-- Try to get place info using MarketplaceService
		local MarketplaceService = game:GetService("MarketplaceService")
		local productInfo = MarketplaceService:GetProductInfo(placeId, Enum.InfoType.Asset)
		return productInfo ~= nil and productInfo.Name ~= nil
	end)
	
	return success and result
end

-- Function to handle part touched
local function onPartTouched(hit, part)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then
		return
	end

	-- Check cooldown to prevent multiple GUI shows
	local currentTime = tick()
	local playerKey = player.UserId
	if playerCooldowns[playerKey] and currentTime - playerCooldowns[playerKey] < COOLDOWN_DURATION then
		return -- Player is still in cooldown
	end

	local partType = part:GetAttribute("part_type")
	if not partType or not string.find(partType, Config.PART_TYPE_KEYWORD) then
		return
	end

	local partKey = part:GetAttribute("part_key")
	if not partKey then
		warn("Teleport part missing part_key attribute: " .. part.Name)
		return
	end

	-- Set cooldown for this player
	playerCooldowns[playerKey] = currentTime

	Config.debugLog("Player " .. player.Name .. " touched teleport part: " .. partKey)

	local gameData = findGameDataByKey(partKey)
	if gameData then
		-- Sanitize URLs before sending to client
		local sanitizedData = {
			part_key = gameData.part_key,
			tp_url = GameData.sanitizeUrl(gameData.tp_url),
			dc_url = GameData.sanitizeUrl(gameData.dc_url),
			title = GameData.formatDisplayText(gameData.title, 30),
			active = gameData.active,
			last_updated = gameData.last_updated,
			server_down = gameData.server_down,
			image_url = gameData.image_url and GameData.sanitizeUrl(gameData.image_url) or nil,
		}

		-- Send game data to client to show GUI
		showTpGuiRemote:FireClient(player, sanitizedData)
		Config.debugLog("Sent game data to client for: " .. partKey)
	else
		warn("No game data found for part_key: " .. partKey)
	end
end

-- Function to handle teleportation
local function onTeleportPlayer(player, tpUrl, partKey)
	Config.debugLog("Teleport request from " .. player.Name .. " to: " .. tostring(tpUrl))

	-- Validate the URL
	local isValid, message = Config.validateTeleportUrl(tpUrl)
	if not isValid then
		warn("Invalid teleport URL for player " .. player.Name .. ": " .. message)
		teleportFailedRemote:FireClient(player, "Invalid game link", partKey)
		return
	end

	-- Extract place ID from TP-URL
	local placeId = string.match(tpUrl, "roblox://placeId=(%d+)")
	if not placeId then
		placeId = string.match(tpUrl, "games/(%d+)")
	end

	if placeId then
		placeId = tonumber(placeId)
		if placeId then
			-- Check if the place is valid before attempting teleport
			local isPlaceValid = checkPlaceValidity(placeId)
			if not isPlaceValid then
				Config.debugLog("Place " .. placeId .. " appears to be invalid or removed")
				teleportFailedRemote:FireClient(player, "This game has been removed or is no longer available. A request has been sent to admins to update this link. Please try other games.", partKey)
				updateServerDownCount(partKey)
				return
			end

			Config.debugLog("Attempting to teleport " .. player.Name .. " to place ID: " .. placeId)

			local success, errorMessage = pcall(function()
				TeleportService:Teleport(placeId, player)
			end)

			if not success then
				warn("Failed to teleport player " .. player.Name .. ": " .. errorMessage)
				-- Check if error indicates the game is removed/private
				if string.find(errorMessage:lower(), "place") and 
				   (string.find(errorMessage:lower(), "not") or string.find(errorMessage:lower(), "invalid")) then
					teleportFailedRemote:FireClient(player, "This game has been removed or is no longer available. A request has been sent to admins to update this link. Please try other games.", partKey)
					updateServerDownCount(partKey)
				else
					teleportFailedRemote:FireClient(player, "Failed to join game: " .. errorMessage, partKey)
				end
			else
				Config.debugLog("Successfully initiated teleport for " .. player.Name)
			end
		else
			warn("Invalid place ID extracted from URL: " .. tpUrl)
			teleportFailedRemote:FireClient(player, "Invalid game link format", partKey)
		end
	else
		warn("Could not extract place ID from URL: " .. tpUrl)
		teleportFailedRemote:FireClient(player, "Could not extract game ID from link", partKey)
	end
end

-- Function to setup teleport parts
local function setupTeleportParts()
	-- Find all parts with part_type attribute containing the keyword
	local function findTeleportParts(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("BasePart") then
				local partType = child:GetAttribute("part_type")
				if partType and string.find(partType, Config.PART_TYPE_KEYWORD) then
					-- Validate required attributes
					local hasAllAttributes = true
					for _, attribute in ipairs(Config.REQUIRED_ATTRIBUTES) do
						if not child:GetAttribute(attribute) then
							warn("Teleport part " .. child.Name .. " missing required attribute: " .. attribute)
							hasAllAttributes = false
						end
					end

					if hasAllAttributes then
						-- Connect touched event
						child.Touched:Connect(function(hit)
							onPartTouched(hit, child)
						end)
						Config.debugLog(
							"Setup teleport part: "
								.. child.Name
								.. " (key: "
								.. (child:GetAttribute("part_key") or "unknown")
								.. ")"
						)
					end
				end
			end

			-- Recursively search in children
			findTeleportParts(child)
		end
	end

	findTeleportParts(workspace)
end

-- Setup teleport parts when server starts
setupTeleportParts()

-- Also setup for any new parts added to workspace
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		local partType = descendant:GetAttribute("part_type")
		if partType and string.find(partType, Config.PART_TYPE_KEYWORD) then
			-- Check for required attributes
			local partKey = descendant:GetAttribute("part_key")
			if partKey then
				descendant.Touched:Connect(function(hit)
					onPartTouched(hit, descendant)
				end)
				Config.debugLog("Setup new teleport part: " .. descendant.Name .. " (key: " .. partKey .. ")")
			else
				warn("New teleport part " .. descendant.Name .. " missing part_key attribute")
			end
		end
	end
end)

-- Connect remote events
teleportPlayerRemote.OnServerEvent:Connect(function(player, tpUrl, partKey)
	onTeleportPlayer(player, tpUrl, partKey)
end)

-- Clean up cooldowns when players leave
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
	Config.debugLog("Cleaned up cooldown data for player: " .. player.Name)
end)

-- Initialize game data cache
if Config.GOOGLE_SCRIPT_URL ~= "YOUR_GOOGLE_APPS_SCRIPT_URL_HERE" then
	fetchGameData()
else
	warn("Please configure your Google Apps Script URL in the Config module!")
end

print("Teleportation system initialized! Debug mode: " .. tostring(Config.DEBUG_MODE))
