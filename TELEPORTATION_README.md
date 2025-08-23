# Roblox Teleportation System

A comprehensive teleportation system for Roblox that allows players to touch parts and see a GUI with game information, Discord links, and join functionality. Data is managed through Google Sheets and served via Google Apps Script.

## Features

- **Touch-based Teleportation**: Players touch parts with special attributes to trigger the system
- **Dynamic GUI**: Beautiful, animated GUI showing game information and Discord server
- **Copy Functionality**: Players can copy Discord URLs directly from the GUI
- **One-click Join**: Direct teleportation to other Roblox games
- **Google Sheets Integration**: Manage all game data through a Google Sheet
- **Real-time Updates**: Data is cached and updated from Google Sheets automatically
- **Validation**: Built-in URL validation and error handling
- **Debug Mode**: Comprehensive logging system for troubleshooting

## Setup Instructions

### 1. Google Sheets Setup

1. Create a new Google Sheet with the following columns:
   - **Part Key** (Column A): Unique identifier for each teleport part (e.g., "trlx_tp")
   - **TP-URL** (Column B): Roblox game URL (e.g., "https://www.roblox.com/games/123456789")
   - **DC-URL** (Column C): Discord server invite URL (e.g., "https://discord.gg/trlx")
   - **Title** (Column D): Display name for the game (e.g., "TRLX Games")
   - **Active** (Column E): Boolean indicating if the game is active (TRUE/FALSE)
   - **Last Updated** (Column F): Timestamp of last update
   - **Server Down** (Column G): Status indicator (0 = up, 1 = down, etc.)
   - **Image URL** (Column H): Optional image URL for the game

2. Copy your Google Sheet ID from the URL (the long string between `/d/` and `/edit`)

### 2. Google Apps Script Setup

1. Open [Google Apps Script](https://script.google.com/)
2. Create a new project
3. Replace the default code with the contents of `GoogleAppsScript.js`
4. Update the `SHEET_ID` variable with your Google Sheet ID
5. Update the `SHEET_NAME` variable if your sheet has a different name
6. Save the project
7. Deploy as a web app:
   - Click "Deploy" > "New deployment"
   - Choose "Web app" as the type
   - Set execute as "Me"
   - Set access to "Anyone"
   - Click "Deploy"
8. Copy the deployment URL

### 3. Roblox Configuration

1. Open `src/shared/Config.luau`
2. Replace `YOUR_GOOGLE_APPS_SCRIPT_URL_HERE` with your deployment URL
3. Adjust other settings as needed (cache duration, colors, etc.)
4. Set `DEBUG_MODE = true` for initial testing

### 4. Setting up Teleport Parts

1. Create parts in your Roblox workspace
2. Add the following attributes to each part:
   - **part_type**: Set to any value containing "tp" (e.g., "tp", "teleport", "tp_pad")
   - **part_key**: Set to match the Part Key in your Google Sheet (e.g., "trlx_tp")

#### Example Part Setup:
```lua
-- In Roblox Studio, select your part and run this in the command bar:
local part = game.Selection:Get()[1]
part:SetAttribute("part_type", "tp")
part:SetAttribute("part_key", "trlx_tp")  -- This should match your Google Sheet
```

### 5. Testing

1. Enable HTTP requests in your Roblox game:
   - Game Settings > Security > Allow HTTP Requests = ON
2. Test the system:
   - Touch a configured part
   - Verify the GUI appears with correct data
   - Test the copy functionality
   - Test the join button

## File Structure

```
src/
├── client/
│   └── init.client.luau     # Client-side GUI and event handling
├── server/
│   └── init.server.luau     # Server-side logic and Google Sheets integration
└── shared/
    ├── Config.luau          # Configuration settings
    ├── GameData.luau        # Game data types and validation
    └── Hello.luau           # Original file (can be removed)
```

## Configuration Options

### Config.luau Settings

- **GOOGLE_SCRIPT_URL**: Your Google Apps Script deployment URL
- **CACHE_DURATION**: How long to cache data (in seconds)
- **PART_TYPE_KEYWORD**: Keyword to identify teleport parts
- **GUI_SETTINGS**: Colors, animation duration, etc.
- **DEBUG_MODE**: Enable/disable debug logging

### Google Apps Script Functions

- **doGet()**: Returns all game data as JSON
- **doPost()**: Handles updates, additions, and specific queries
- **createSampleData()**: Creates sample data in your sheet
- **formatSheet()**: Formats the sheet for better appearance
- **testScript()**: Test function to verify setup

## Troubleshooting

### Common Issues

1. **"Please configure your Google Apps Script URL"**
   - Update the URL in `Config.luau`

2. **GUI not appearing**
   - Check part attributes (`part_type` and `part_key`)
   - Verify the `part_key` exists in your Google Sheet
   - Check server console for error messages

3. **"Failed to fetch game data"**
   - Verify HTTP requests are enabled
   - Check your Google Apps Script deployment permissions
   - Ensure the Google Sheet is accessible

4. **Teleportation not working**
   - Verify the TP-URL format is correct
   - Check TeleportService permissions
   - Ensure the target game allows teleportation

### Debug Mode

Enable debug mode in `Config.luau` to see detailed logging:
```lua
Config.DEBUG_MODE = true
```

This will show:
- Part touch events
- Data fetching attempts
- Teleportation requests
- Cache updates

## Customization

### GUI Appearance
Modify colors and styles in `Config.GUI_SETTINGS`:
```lua
Config.GUI_SETTINGS = {
    BACKGROUND_COLOR = Color3.fromRGB(45, 45, 45),
    PRIMARY_COLOR = Color3.fromRGB(67, 181, 129),
    -- Add your custom colors here
}
```

### Part Detection
Change how parts are detected by modifying:
```lua
Config.PART_TYPE_KEYWORD = "tp"  -- Change to your preferred keyword
```

### Cache Settings
Adjust data caching behavior:
```lua
Config.CACHE_DURATION = 300  -- 5 minutes (adjust as needed)
```

## Security Considerations

- Google Apps Script runs with your Google account permissions
- URLs are sanitized before display
- Only Roblox.com domains are allowed for teleportation
- Input validation is performed on all data

## Sample Data

The Google Apps Script includes a `createSampleData()` function that will populate your sheet with example data. Run this function once to get started quickly.

## Support

If you encounter issues:
1. Check the debug console output
2. Verify all URLs and IDs are correct
3. Test the Google Apps Script directly
4. Ensure HTTP requests are enabled in Roblox

## License

This project is provided as-is for educational and development purposes.
