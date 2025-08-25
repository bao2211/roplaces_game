-- Server script for teleportation parts system
--
-- SETUP INSTRUCTIONS:
-- 1. Place this script as a ServerScript in ServerScriptService
-- 2. Place Config.luau as a ModuleScript named "Config" in ServerScriptService
-- 3. Place GameData.luau as a ModuleScript named "GameData" in ServerScriptService
-- 4. Place init.client.luau as a LocalScript in StarterPlayer > StarterPlayerScripts
--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Import server-side modules (now secure)
-- Check if modules exist before requiring them
local Config, GameData

local configModule = script.Parent:FindFirstChild("Config")
local gameDataModule = script.Parent:FindFirstChild("GameData")

if not configModule then
	error(
		"❌ SETUP ERROR: Config ModuleScript not found in ServerScriptService! Please create a ModuleScript named 'Config' in ServerScriptService and copy the content from src/server/Config.luau"
	)
end

if not gameDataModule then
	error(
		"❌ SETUP ERROR: GameData ModuleScript not found in ServerScriptService! Please create a ModuleScript named 'GameData' in ServerScriptService and copy the content from src/server/GameData.luau"
	)
end

Config = require(configModule)
GameData = require(gameDataModule)

print("✅ Teleport System: Successfully loaded Config and GameData modules")

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

local reportServerRemote = Instance.new("RemoteEvent")
reportServerRemote.Name = "ReportServer"
reportServerRemote.Parent = remoteEvents

local showLoadingRemote = Instance.new("RemoteEvent")
showLoadingRemote.Name = "ShowLoading"
showLoadingRemote.Parent = remoteEvents

local regeneratePartsRemote = Instance.new("RemoteEvent")
regeneratePartsRemote.Name = "RegenerateParts"
regeneratePartsRemote.Parent = remoteEvents

-- Cache for game data
local gameDataCache = {}
local lastCacheUpdate = 0

-- Cooldown system to prevent multiple GUI shows
local playerCooldowns = {} -- Track cooldowns per player
local playersOnParts = {} -- Track which players are currently on teleport parts
local COOLDOWN_DURATION = 3 -- seconds before player can trigger GUI again

-- Server report cooldown system
local playerReportCooldowns = {} -- Track report cooldowns per player per gamemode/server
local REPORT_COOLDOWN_DURATION = 30 * 60 -- 30 minutes in seconds

-- Function to fetch game data from Google Sheets
local function fetchGameData()
	Config.debugLog("Attempting to fetch game data from Google Sheets")
	Config.debugLog("Using URL: " .. Config.GOOGLE_SCRIPT_URL)
	Config.debugLog("HttpService.HttpEnabled: " .. tostring(HttpService.HttpEnabled))

	local success, result = pcall(function()
		local response = HttpService:GetAsync(Config.GOOGLE_SCRIPT_URL)
		Config.debugLog("HTTP Response received: " .. string.sub(response, 1, 200) .. "...")
		return HttpService:JSONDecode(response)
	end)

	Config.debugLog("HTTP Request success: " .. tostring(success))
	if not success then
		Config.debugLog("HTTP Request error: " .. tostring(result))
	end

	if success and result and type(result) == "table" then
		-- Validate each game group entry
		local validatedData = {}
		for _, gameGroup in ipairs(result) do
			if gameGroup and gameGroup.part_key and gameGroup.games then
				-- Validate each game within the group
				local validatedGames = {}
				for _, gameInfo in ipairs(gameGroup.games) do
					local validatedGameInfo = GameData.validateGameInfo(gameInfo)
					if validatedGameInfo then
						table.insert(validatedGames, validatedGameInfo)
					end
				end

				-- Only include the group if it has valid games
				if #validatedGames > 0 then
					table.insert(validatedData, {
						part_key = gameGroup.part_key,
						games = validatedGames,
						has_multiple_modes = gameGroup.has_multiple_modes or #validatedGames > 1,
					})
				end
			end
		end

		gameDataCache = validatedData
		lastCacheUpdate = tick()
		Config.debugLog("Game data cache updated successfully with " .. #validatedData .. " groups")
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

-- Function to update BillBoard decal with image from game data
local function updateBillBoardDecal(part, imageUrl)
	if not imageUrl or imageUrl == "" then
		Config.debugLog("No image URL provided for BillBoard update")
		return
	end
	
	-- Find BillBoard part within the teleport part
	local billBoard = part:FindFirstChild("BillBoard")
	if not billBoard then
		Config.debugLog("BillBoard part not found in: " .. part.Name)
		return
	end
	
	-- Find Decal within BillBoard
	local decal = billBoard:FindFirstChildOfClass("Decal")
	if not decal then
		Config.debugLog("Decal not found in BillBoard of: " .. part.Name)
		return
	end
	
	-- Update decal texture with image URL
	decal.Texture = imageUrl
	Config.debugLog("Updated BillBoard decal for " .. part.Name .. " with image: " .. imageUrl)
end

-- Function to find game data by part key
local function findGameDataByKey(partKey)
	local data = getGameData()
	for _, gameGroup in ipairs(data) do
		if gameGroup.part_key == partKey then
			return gameGroup
		end
	end
	return nil
end

-- Function to update server_down count for invalid games
local function updateServerDownCount(partKey, gameTitle)
	local success, responseData = pcall(function()
		local requestData = {
			action = "update_server_down",
			part_key = partKey,
			game_title = gameTitle,
		}

		local httpResponse = HttpService:PostAsync(
			Config.GOOGLE_SCRIPT_URL,
			HttpService:JSONEncode(requestData),
			Enum.HttpContentType.ApplicationJson
		)
		return HttpService:JSONDecode(httpResponse)
	end)

	if success then
		Config.debugLog("Updated server_down count for: " .. partKey .. " (" .. tostring(gameTitle) .. ")")
	else
		warn(
			"Failed to update server_down count for: "
				.. partKey
				.. " ("
				.. tostring(gameTitle)
				.. ") - Error: "
				.. tostring(responseData)
		)
	end
end

-- Function to handle server reports from players

function onServerReport(player, tpUrl, partKey, gameTitle)
	local playerKey = player.UserId
	local currentTime = tick()
	local reportKey = tostring(player.UserId) .. "_" .. tostring(partKey) .. "_" .. tostring(tpUrl)

	-- Debug print: show what is being received and used for cooldown
	print("[TP Server Debug] onServerReport called with:")
	print("tpUrl:", tpUrl)
	print("partKey:", partKey)
	print("gameTitle:", gameTitle)
	print("reportKey:", reportKey)

	-- Check if player is on cooldown for this gamemode/server
	if playerReportCooldowns[reportKey] then
		local timeSinceLastReport = currentTime - playerReportCooldowns[reportKey]
		if timeSinceLastReport < REPORT_COOLDOWN_DURATION then
			-- Player is still on cooldown for this gamemode/server
			local timeLeft = REPORT_COOLDOWN_DURATION - timeSinceLastReport
			local minutesLeft = math.ceil(timeLeft / 60)

			Config.debugLog(
				"Player "
					.. player.Name
					.. " tried to report but is on cooldown for this gamemode/server for "
					.. minutesLeft
					.. " more minutes"
			)
			-- Could send error back to client if needed
			return
		end
	end

	-- Set cooldown for this player for this gamemode/server
	playerReportCooldowns[reportKey] = currentTime

	Config.debugLog(
		"Player "
			.. player.Name
			.. " reported server issue for: "
			.. tostring(gameTitle)
			.. " (Key: "
			.. tostring(partKey)
			.. ")"
	)

	-- Update server down count (now with gameTitle)
	updateServerDownCount(partKey, gameTitle)

	-- Log the report for admin tracking
	print(
		"SERVER REPORT: Player "
			.. player.Name
			.. " ("
			.. player.UserId
			.. ") reported "
			.. tostring(gameTitle)
			.. " (TP: "
			.. tostring(tpUrl)
			.. ") at "
			.. os.date("%Y-%m-%d %H:%M:%S")
	)

	-- Optional: Send confirmation back to client (already handled on client side)
	-- reportServerRemote:FireClient(player, true, "Report sent successfully! Admin will update this link soon.")
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

	local partType = part:GetAttribute("part_type")
	if not partType or not string.find(partType, Config.PART_TYPE_KEYWORD) then
		return
	end

	local partKey = part:GetAttribute("part_key")
	if not partKey then
		warn("Teleport part missing part_key attribute: " .. part.Name)
		return
	end

	-- Check if player is already on this specific part to prevent duplicate triggers
	local playerKey = player.UserId
	local partPlayerKey = playerKey .. "_" .. partKey

	if playersOnParts[partPlayerKey] then
		-- Player is already on this part, don't retrigger
		return
	end

	-- Check global cooldown to prevent rapid switching between parts
	local currentTime = tick()
	if playerCooldowns[playerKey] and currentTime - playerCooldowns[playerKey] < COOLDOWN_DURATION then
		return -- Player is still in cooldown
	end

	-- Mark player as on this part
	playersOnParts[partPlayerKey] = currentTime
	-- Set cooldown for this player
	playerCooldowns[playerKey] = currentTime

	Config.debugLog("Player " .. player.Name .. " touched teleport part: " .. partKey)

	-- Show loading screen to player immediately
	showLoadingRemote:FireClient(player, true, "Loading game data...")

	-- Always fetch fresh data from Google Sheets (no caching)
	Config.debugLog("Fetching fresh game data for player: " .. player.Name)
	local freshGameData = fetchGameData()
	
	-- Find game data for this specific part
	local gameData = nil
	if freshGameData then
		for _, gameGroup in ipairs(freshGameData) do
			if gameGroup.part_key == partKey then
				gameData = gameGroup
				break
			end
		end
	end
	
	Config.debugLog("Fresh game data found for " .. partKey .. ": " .. tostring(gameData ~= nil))

	if gameData then
		Config.debugLog("Game data has games: " .. tostring(gameData.games ~= nil))
		if gameData.games then
			Config.debugLog("Number of games: " .. #gameData.games)
		end
	end

	if gameData and gameData.games and #gameData.games > 0 then
		-- Prepare games array to send to client
		local gamesArray = {}

		-- Process all games for this part key
		for _, game in ipairs(gameData.games) do
			local sanitizedGame = {
				partKey = gameData.part_key, -- Add partKey to each game for client reference
				tp_url = GameData.sanitizeUrl(game.tp_url),
				discordUrl = GameData.sanitizeUrl(game.dc_url), -- Rename to match client expectations
				title = game.title, -- Use the full, original title for cooldown key uniqueness
				status = game.status or "Unknown", -- New: Admin-controlled status
				last_updated = game.last_updated or "", -- New: Admin update timestamp
				last_down_vote = game.last_down_vote or "", -- New: Last player report timestamp
				server_down = game.server_down or 0, -- Number of down reports
				imageUrl = game.image_url and GameData.sanitizeUrl(game.image_url) or nil, -- Rename to match client expectations
				description = game.description or "",
			}
			table.insert(gamesArray, sanitizedGame)
		end

		-- Update BillBoard decal with the first game's image (representative image for the part)
		local firstGame = gameData.games[1]
		if firstGame and firstGame.image_url then
			local sanitizedImageUrl = GameData.sanitizeUrl(firstGame.image_url)
			updateBillBoardDecal(part, sanitizedImageUrl)
		end

		-- Send game array directly to client to show GUI
		showTpGuiRemote:FireClient(player, gamesArray)
		-- Hide loading screen
		showLoadingRemote:FireClient(player, false)
		Config.debugLog("Sent fresh game data to client for: " .. partKey .. " with " .. #gamesArray .. " game modes")
	else
		-- Hide loading screen and show error
		showLoadingRemote:FireClient(player, false)
		warn("No game data found for part_key: " .. partKey)
	end
end

-- Function to handle teleportation
local function onTeleportPlayer(player, tpUrl, partKey, gameTitle)
	Config.debugLog(
		"Teleport request from "
			.. player.Name
			.. " to: "
			.. tostring(tpUrl)
			.. " (Game: "
			.. tostring(gameTitle)
			.. ")"
	)

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
				teleportFailedRemote:FireClient(
					player,
					"This game has been removed or is no longer available. A request has been sent to admins to update this link. Please try other games.",
					partKey
				)
				updateServerDownCount(partKey, gameTitle)
				return
			end

			Config.debugLog("Attempting to teleport " .. player.Name .. " to place ID: " .. placeId)

			local success, errorMessage = pcall(function()
				TeleportService:Teleport(placeId, player)
			end)

			if not success then
				warn("Failed to teleport player " .. player.Name .. ": " .. errorMessage)
				-- Check if error indicates the game is removed/private
				if
					string.find(errorMessage:lower(), "place")
					and (string.find(errorMessage:lower(), "not") or string.find(errorMessage:lower(), "invalid"))
				then
					teleportFailedRemote:FireClient(
						player,
						"This game has been removed or is no longer available. A request has been sent to admins to update this link. Please try other games.",
						partKey
					)
					updateServerDownCount(partKey, gameTitle)
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

						-- Connect touch ended event to track when players leave
						child.TouchEnded:Connect(function(hit)
							local humanoid = hit.Parent:FindFirstChild("Humanoid")
							if not humanoid then
								return
							end

							local player = Players:GetPlayerFromCharacter(hit.Parent)
							if not player then
								return
							end

							local partKey = child:GetAttribute("part_key")
							if partKey then
								local playerKey = player.UserId
								local partPlayerKey = playerKey .. "_" .. partKey
								playersOnParts[partPlayerKey] = nil -- Remove player from this part
								Config.debugLog("Player " .. player.Name .. " left teleport part: " .. partKey)
							end
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

				-- Connect touch ended event for dynamically added parts
				descendant.TouchEnded:Connect(function(hit)
					local humanoid = hit.Parent:FindFirstChild("Humanoid")
					if not humanoid then
						return
					end

					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if not player then
						return
					end

					local playerKey = player.UserId
					local partPlayerKey = playerKey .. "_" .. partKey
					playersOnParts[partPlayerKey] = nil -- Remove player from this part
					Config.debugLog("Player " .. player.Name .. " left teleport part: " .. partKey)
				end)

				Config.debugLog("Setup new teleport part: " .. descendant.Name .. " (key: " .. partKey .. ")")
			else
				warn("New teleport part " .. descendant.Name .. " missing part_key attribute")
			end
		end
	end
end)

-- Connect remote events
teleportPlayerRemote.OnServerEvent:Connect(function(player, tpUrl, partKey, gameTitle)
	onTeleportPlayer(player, tpUrl, partKey, gameTitle)
end)

reportServerRemote.OnServerEvent:Connect(function(player, tpUrl, partKey, gameTitle)
	onServerReport(player, tpUrl, partKey, gameTitle)
end)

-- Clean up cooldowns when players leave
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
	playerReportCooldowns[player.UserId] = nil

	-- Clean up all part tracking for this player
	local playerKey = player.UserId
	for key, _ in pairs(playersOnParts) do
		if string.find(key, "^" .. playerKey .. "_") then
			playersOnParts[key] = nil
		end
	end

	Config.debugLog("Cleaned up cooldown and part tracking data for player: " .. player.Name)
end)

-- Function to update all BillBoard decals with fresh game data
local function updateAllBillBoardDecals()
	local gameData = fetchGameData()
	if not gameData then
		Config.debugLog("No game data available for BillBoard updates")
		return
	end
	
	-- Find all teleport parts in workspace
	local function searchForTeleportParts(parent)
		for _, child in ipairs(parent:GetChildren()) do
			-- Check if this is a teleport part
			local partType = child:GetAttribute("part_type")
			local partKey = child:GetAttribute("part_key")
			
			if partType and string.find(partType, Config.PART_TYPE_KEYWORD) and partKey then
				-- Find matching game data for this part
				for _, gameGroup in ipairs(gameData) do
					if gameGroup.part_key == partKey and gameGroup.games and #gameGroup.games > 0 then
						-- Use first game's image as representative image for the part
						local firstGame = gameGroup.games[1]
						if firstGame and firstGame.image_url then
							local sanitizedImageUrl = GameData.sanitizeUrl(firstGame.image_url)
							updateBillBoardDecal(child, sanitizedImageUrl)
						end
						break
					end
				end
			end
			
			-- Recursively search children
			searchForTeleportParts(child)
		end
	end
	
	searchForTeleportParts(workspace)
	Config.debugLog("Updated all BillBoard decals with fresh game data")
end

-- Function to automatically generate teleport parts based on Google Sheet data
local function generateTeleportParts()
	-- Find the template part
	local templatePart = workspace:FindFirstChild("TP_Part")
	if not templatePart then
		warn("Template part 'TP_Part' not found in workspace!")
		return
	end
	
	-- Verify template part has correct attributes
	local templatePartType = templatePart:GetAttribute("part_type")
	if not templatePartType or templatePartType ~= "tp" then
		warn("Template part 'TP_Part' missing or incorrect part_type attribute!")
		return
	end
	
	Config.debugLog("Found template part: " .. templatePart.Name)
	
	-- Fetch game data to get all unique part keys
	local gameData = fetchGameData()
	if not gameData then
		Config.debugLog("No game data available for part generation")
		return
	end
	
	-- Get template part position for spacing
	local spacing = 20 -- Distance between parts (adjust as needed)
	local currentOffset = 0
	
	-- Track existing parts to avoid duplicates
	local existingPartKeys = {}
	
	-- Check what part keys already exist
	local function findExistingParts(parent)
		for _, child in ipairs(parent:GetChildren()) do
			local partType = child:GetAttribute("part_type")
			local partKey = child:GetAttribute("part_key")
			
			if partType and string.find(partType, Config.PART_TYPE_KEYWORD) and partKey then
				existingPartKeys[partKey] = true
				Config.debugLog("Found existing part with key: " .. partKey)
			end
			
			-- Recursively search children
			findExistingParts(child)
		end
	end
	
	findExistingParts(workspace)
	
	-- Generate parts for each unique part_key in game data
	for _, gameGroup in ipairs(gameData) do
		local partKey = gameGroup.part_key
		
		if not existingPartKeys[partKey] then
			-- Create new part for this part_key
			local newPart = templatePart:Clone()
			newPart.Name = "TP_Part_" .. partKey
			newPart:SetAttribute("part_key", partKey)
			newPart:SetAttribute("part_type", "tp")
			
			-- Parent to workspace first
			newPart.Parent = workspace
			
			-- Calculate offset for positioning
			currentOffset = currentOffset + spacing
			local offsetVector = Vector3.new(currentOffset, 0, 0)
			
			-- Move the main part
			newPart.CFrame = newPart.CFrame + offsetVector
			
			-- Move all child parts that are BaseParts
			local function moveChildParts(parent)
				for _, child in ipairs(parent:GetChildren()) do
					if child:IsA("BasePart") then
						child.CFrame = child.CFrame + offsetVector
					end
					-- Recursively check children of children
					moveChildParts(child)
				end
			end
			
			-- Move all child parts
			moveChildParts(newPart)
			
			Config.debugLog("Generated new teleport part: " .. newPart.Name .. " for part_key: " .. partKey)
			Config.debugLog("Moved part and children by offset: " .. tostring(offsetVector))
			
			-- Mark this part_key as existing
			existingPartKeys[partKey] = true
		else
			Config.debugLog("Part already exists for part_key: " .. partKey)
		end
	end
	
	Config.debugLog("Teleport part generation complete!")
end

-- Function to regenerate parts (can be called when Google Sheet is updated)
local function regenerateTeleportParts()
	Config.debugLog("Regenerating teleport parts from updated Google Sheet data...")
	generateTeleportParts()
	updateAllBillBoardDecals()
	Config.debugLog("Teleport parts regeneration complete!")
end

-- Connect RemoteEvent for parts regeneration
regeneratePartsRemote.OnServerEvent:Connect(function(player)
	-- Only allow certain players to regenerate parts (optional security check)
	Config.debugLog("Player " .. player.Name .. " requested parts regeneration")
	regenerateTeleportParts()
end)

-- Initialize game data cache
if Config.GOOGLE_SCRIPT_URL ~= "YOUR_GOOGLE_APPS_SCRIPT_URL_HERE" then
	fetchGameData()
	-- Generate teleport parts based on Google Sheet data
	generateTeleportParts()
	-- Update all BillBoard decals with initial game data
	updateAllBillBoardDecals()
	print("✅ Teleportation system initialized! Debug mode: " .. tostring(Config.DEBUG_MODE))
else
	warn("⚠️  CONFIGURATION NEEDED: Please configure your Google Apps Script URL in the Config module!")
	print("📋 Setup Status: Teleport system loaded but needs Google Script URL configuration")
end

-- Final setup verification
print("🎯 Teleport System Setup Complete!")
print("📁 Files loaded: Config ✅, GameData ✅, RemoteEvents ✅")
print("🔧 Next steps: Configure Google Script URL in Config module if not done yet")
