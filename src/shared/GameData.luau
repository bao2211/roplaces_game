-- GameData module for teleportation system
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

return GameData
