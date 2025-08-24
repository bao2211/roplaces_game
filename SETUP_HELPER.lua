-- Setup Helper Script for Teleportation System
-- Run this script in Roblox Studio Command Bar to automatically create the required ModuleScripts
-- Copy and paste this entire script into the Command Bar and press Enter

local ServerScriptService = game:GetService("ServerScriptService")

-- Clean up any existing modules first
local existingConfig = ServerScriptService:FindFirstChild("Config")
local existingGameData = ServerScriptService:FindFirstChild("GameData")

if existingConfig then
	existingConfig:Destroy()
	print("🧹 Removed existing Config module")
end

if existingGameData then
	existingGameData:Destroy()
	print("🧹 Removed existing GameData module")
end

-- Create Config ModuleScript
local configModule = Instance.new("ModuleScript")
configModule.Name = "Config"
configModule.Parent = ServerScriptService

-- Config module content
configModule.Source = [[-- Configuration for Teleportation System
-- Update these values according to your setup

local Config = {}

-- Google Apps Script Configuration
Config.GOOGLE_SCRIPT_URL =
	"https://script.google.com/macros/s/AKfycbwvg1Z42qkoO-qTTPqy65c2XETWF1CSgn5UH1pQGuLuZA0tU_nE0ob12WdlUwCJjtfDhw/exec" -- Your Google Apps Script URL

-- Cache Settings
Config.CACHE_DURATION = 300 -- 5 minutes in seconds
Config.MAX_RETRIES = 3 -- Maximum number of retry attempts for failed requests

-- Part Detection Settings
Config.PART_TYPE_KEYWORD = "tp" -- Parts with part_type attribute containing this will be teleport parts
Config.REQUIRED_ATTRIBUTES = {
	"part_type", -- Must contain "tp"
	"part_key", -- Must have a unique identifier
}

-- GUI Settings
Config.GUI_SETTINGS = {
	ANIMATION_DURATION = 0.3,
	BACKGROUND_COLOR = Color3.fromRGB(45, 45, 45),
	PRIMARY_COLOR = Color3.fromRGB(67, 181, 129),
	SECONDARY_COLOR = Color3.fromRGB(88, 101, 242),
	DANGER_COLOR = Color3.fromRGB(220, 53, 69),
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	COPY_FEEDBACK_DURATION = 1, -- seconds
}

-- Teleportation Settings
Config.TELEPORT_SETTINGS = {
	ALLOWED_DOMAINS = {
		"roblox.com",
		"www.roblox.com",
	},
	TIMEOUT_DURATION = 10, -- seconds before teleport attempt fails
}

-- Debug Settings
Config.DEBUG_MODE = true -- Set to true for additional logging

-- Validation function for URLs
function Config.validateTeleportUrl(url)
	if not url or url == "" then
		return false, "URL is empty"
	end

	-- Check if URL contains roblox domain
	local isValid = false
	for _, domain in ipairs(Config.TELEPORT_SETTINGS.ALLOWED_DOMAINS) do
		if string.find(url:lower(), domain) then
			isValid = true
			break
		end
	end

	if not isValid then
		return false, "URL must be from a valid Roblox domain"
	end

	-- Check for place ID
	local placeId = string.match(url, "games/(%d+)") or string.match(url, "placeId=(%d+)")
	if not placeId then
		return false, "Could not extract place ID from URL"
	end

	return true, "Valid URL"
end

-- Validation function for Discord URLs
function Config.validateDiscordUrl(url)
	if not url or url == "" then
		return true, "Discord URL is optional" -- Discord URL is optional
	end

	if not string.find(url:lower(), "discord") then
		return false, "Must be a Discord URL"
	end

	return true, "Valid Discord URL"
end

-- Function to log debug messages
function Config.debugLog(message)
	if Config.DEBUG_MODE then
		print("[TP System Debug] " .. tostring(message))
	end
end

return Config]]

-- Create GameData ModuleScript
local gameDataModule = Instance.new("ModuleScript")
gameDataModule.Name = "GameData"
gameDataModule.Parent = ServerScriptService

-- GameData module content
gameDataModule.Source = [[-- GameData module for teleportation system
-- This module defines the structure of game data from Google Sheets

local GameData = {}

-- Type definition for game data
export type GameInfo = {
	part_key: string, -- Unique identifier for the teleport part
	tp_url: string, -- Roblox game URL for teleportation
	dc_url: string, -- Discord server invite URL
	title: string, -- Game/Server title
	active: boolean, -- Whether the game is currently active
	last_updated: string, -- Last update timestamp
	server_down: number, -- Server status (0 = up, 1 = down, etc.)
	image_url: string?, -- Optional image URL
	description: string?, -- Optional game description
}

-- Example game data structure
GameData.ExampleData = {
	part_key = "trlx_tp",
	tp_url = "https://www.roblox.com/games/123456789",
	dc_url = "https://discord.gg/trlx",
	title = "TRLX Games",
	active = true,
	last_updated = "08/21/2025, 20:3",
	server_down = 3,
	image_url = "https://example.com/image.png",
	description = "Experience amazing adventures in the TRLX gaming universe with friends and explore countless worlds.",
}

-- Function to validate game data
function GameData.validateGameInfo(data: any): GameInfo?
	if type(data) ~= "table" then
		return nil
	end

	local requiredFields = { "part_key", "tp_url", "dc_url", "title" }
	for _, field in ipairs(requiredFields) do
		if not data[field] or type(data[field]) ~= "string" then
			warn("Missing or invalid field: " .. field)
			return nil
		end
	end

	return data :: GameInfo
end

-- Function to sanitize URLs
function GameData.sanitizeUrl(url: string): string
	if not url or url == "" then
		return ""
	end

	-- Remove any potentially harmful characters
	url = string.gsub(url, "[<>\"']", "")

	return url
end

-- Function to format display text
function GameData.formatDisplayText(text: string, maxLength: number?): string
	if not text then
		return ""
	end

	maxLength = maxLength or 50

	if string.len(text) > maxLength then
		return string.sub(text, 1, maxLength - 3) .. "..."
	end

	return text
end

return GameData]]

print("✅ Successfully created Config and GameData ModuleScripts in ServerScriptService!")
print("� Created modules:")
print("   - Config: " .. tostring(ServerScriptService:FindFirstChild("Config") ~= nil))
print("   - GameData: " .. tostring(ServerScriptService:FindFirstChild("GameData") ~= nil))
print("🎯 Your server script should now work without errors!")
print("📝 The Google Apps Script URL is already configured")
print("🚀 Ready to test the teleportation system!")
