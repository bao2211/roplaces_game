-- Configuration for Teleportation System
-- Update these values according to your setup

local Config = {}

-- Google Apps Script Configuration
Config.GOOGLE_SCRIPT_URL =
	"https://script.google.com/macros/s/AKfycbwvg1Z42qkoO-qTTPqy65c2XETWF1CSgn5UH1pQGuLuZA0tU_nE0ob12WdlUwCJjtfDhw/exec" -- Replace with your deployed Google Apps Script URL

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
Config.DEBUG_MODE = false -- Set to true for additional logging

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

return Config
