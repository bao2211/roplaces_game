/**
 * Google Apps Script for Roblox Teleportation System
 * This script serves game data from a Google Sheet to your Roblox game
 * 
 * Setup Instructions:
 * 1. Create a new Google Sheet with columns: Part Key, TP-URL, DC-URL, Title, Status, Last Updated, Last Down Vote, Server Down, Image URL, Description
 * 2. Replace SHEET_ID with your Google Sheet ID
 * 3. Deploy this script as a web app with execute permissions for "Anyone"
 * 4. Copy the deployment URL and use it in your Roblox server script
 * 
 * Column Descriptions:
 * - Status: Admin-controlled server status (Online/Down/Maintenance) - READ ONLY for game
 * - Last Updated: Admin update timestamp - READ ONLY for game  
 * - Last Down Vote: Player report timestamp - UPDATED by game when players report
 */

// Configuration
const SHEET_ID = '1mIeT4PzQMZF0OfeEEvq9PJWq4i__udt3CRNYEy3-fPg'; // Replace with your actual Google Sheet ID
const SHEET_NAME = 'Page1'; // Replace with your sheet name if different

/**
 * Main function to handle GET requests
 * Returns game data as JSON
 */
function doGet(e) {
  try {
    const gameData = getGameData();
    
    return ContentService
      .createTextOutput(JSON.stringify(gameData))
      .setMimeType(ContentService.MimeType.JSON);
      
  } catch (error) {
    console.error('Error in doGet:', error);
    
    return ContentService
      .createTextOutput(JSON.stringify({
        error: 'Failed to fetch game data',
        message: error.toString()
      }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Fetch game data from Google Sheet
 * Groups games by part_key to handle multiple games per teleport part
 */
function getGameData() {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  
  if (!sheet) {
    throw new Error(`Sheet "${SHEET_NAME}" not found`);
  }
  
  const data = sheet.getDataRange().getValues();
  
  if (data.length < 2) {
    return []; // No data rows (only header or empty sheet)
  }
  
  // Assuming first row contains headers
  const headers = data[0].map(header => {
    const normalized = header.toString().toLowerCase().replace(/[^a-z0-9]/g, '_');
    // Fix specific field mappings
    if (normalized === 'server_down_') return 'server_down';
    if (normalized === 'tp_url_') return 'tp_url';
    if (normalized === 'dc_url_') return 'dc_url';
    if (normalized === 'image_url_') return 'image_url';
    return normalized;
  });
  const gameDataMap = new Map(); // Use Map to group by part_key
  
  // Process each data row
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const gameInfo = {};
    
    // Map each column to the corresponding field
    for (let j = 0; j < headers.length && j < row.length; j++) {
      const header = headers[j];
      let value = row[j];
      
      // Convert specific fields to appropriate types
      if (header === 'active') {
        value = Boolean(value);
      } else if (header === 'server_down') {
        value = Number(value) || 0;
      } else if (value instanceof Date) {
        value = value.toLocaleDateString() + ', ' + value.toLocaleTimeString();
      } else {
        value = value.toString();
      }
      
      gameInfo[header] = value;
    }
    
    // Only include rows with required fields
    if (gameInfo.part_key && gameInfo.tp_url && gameInfo.dc_url && gameInfo.title) {
      const partKey = gameInfo.part_key;
      
      if (!gameDataMap.has(partKey)) {
        // First game for this part_key
        gameDataMap.set(partKey, {
          part_key: partKey,
          games: [gameInfo],
          has_multiple_modes: false
        });
      } else {
        // Additional game for existing part_key
        const existingData = gameDataMap.get(partKey);
        existingData.games.push(gameInfo);
        existingData.has_multiple_modes = true;
      }
    }
  }
  
  // Convert Map to Array for return
  return Array.from(gameDataMap.values());
}

/**
 * Function to update a specific game's data
 * Can be called from Roblox or other external sources
 */
function doPost(e) {
  try {
    const requestData = JSON.parse(e.postData.contents);
    const action = requestData.action;
    
    switch (action) {
      case 'update_game':
        return updateGameData(requestData);
      case 'add_game':
        return addGameData(requestData);
      case 'get_game':
        return getSpecificGame(requestData.part_key);
      case 'update_server_down':
        // Pass game_title if provided for precise row matching
        return updateServerDown(requestData.part_key, requestData.game_title);
      default:
        throw new Error('Invalid action: ' + action);
    }
    
  } catch (error) {
    console.error('Error in doPost:', error);
    
    return ContentService
      .createTextOutput(JSON.stringify({
        success: false,
        error: error.toString()
      }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Update existing game data
 */
function updateGameData(requestData) {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  
  // Find the row with matching part_key
  let rowIndex = -1;
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === requestData.part_key) { // Assuming part_key is in first column
      rowIndex = i + 1; // Sheet rows are 1-indexed
      break;
    }
  }
  
  if (rowIndex === -1) {
    throw new Error('Game with part_key "' + requestData.part_key + '" not found');
  }
  
  // Update the row with new data
  const updateData = [];
  for (let j = 0; j < headers.length; j++) {
    let header = headers[j].toString().toLowerCase().replace(/[^a-z0-9]/g, '_');
    // Fix specific field mappings
    if (header === 'server_down_') header = 'server_down';
    if (header === 'tp_url_') header = 'tp_url';
    if (header === 'dc_url_') header = 'dc_url';
    if (header === 'image_url_') header = 'image_url';
    
    updateData.push(requestData[header] || data[rowIndex - 1][j]);
  }
  
  // Update last_updated timestamp
  const lastUpdatedIndex = headers.findIndex(h => h.toString().toLowerCase().includes('updated'));
  if (lastUpdatedIndex !== -1) {
    updateData[lastUpdatedIndex] = new Date();
  }
  
  sheet.getRange(rowIndex, 1, 1, updateData.length).setValues([updateData]);
  
  return ContentService
    .createTextOutput(JSON.stringify({
      success: true,
      message: 'Game data updated successfully'
    }))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Add new game data
 */
function addGameData(requestData) {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  
  const newRow = [];
  for (let j = 0; j < headers.length; j++) {
    let header = headers[j].toString().toLowerCase().replace(/[^a-z0-9]/g, '_');
    // Fix specific field mappings
    if (header === 'server_down_') header = 'server_down';
    if (header === 'tp_url_') header = 'tp_url';
    if (header === 'dc_url_') header = 'dc_url';
    if (header === 'image_url_') header = 'image_url';
    
    newRow.push(requestData[header] || '');
  }
  
  // Set current timestamp for last_updated
  const lastUpdatedIndex = headers.findIndex(h => h.toString().toLowerCase().includes('updated'));
  if (lastUpdatedIndex !== -1) {
    newRow[lastUpdatedIndex] = new Date();
  }
  
  sheet.appendRow(newRow);
  
  return ContentService
    .createTextOutput(JSON.stringify({
      success: true,
      message: 'Game data added successfully'
    }))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Update server_down count for a specific game and set Last Down Vote timestamp
 * Now supports updating specific game mode within a part_key
 */
function updateServerDown(partKey, gameTitle = null) {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];

  // Find the row with matching part_key and (if provided) game title
  let rowIndex = -1;
  const partKeyIndex = headers.findIndex(h => h.toString().toLowerCase().includes('part'));
  const titleIndex = headers.findIndex(h => h.toString().toLowerCase().includes('title'));
  for (let i = 1; i < data.length; i++) {
    const rowPartKey = data[i][partKeyIndex];
    const rowTitle = titleIndex !== -1 ? data[i][titleIndex] : null;
    if (
      rowPartKey === partKey &&
      (gameTitle === null || (rowTitle && rowTitle.toString() === gameTitle))
    ) {
      rowIndex = i + 1; // 1-based index for Sheets
      break;
    }
  }

  if (rowIndex === -1) {
    return ContentService
      .createTextOutput(JSON.stringify({
        success: false,
        message: 'No matching game found for part_key and title'
      }))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Find server_down column index
  const serverDownIndex = headers.findIndex(h => h.toString().toLowerCase().includes('server') && h.toString().toLowerCase().includes('down'));
  if (serverDownIndex === -1) {
    return ContentService
      .createTextOutput(JSON.stringify({
        success: false,
        message: 'No server_down column found'
      }))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // Find Last Down Vote column index
  const lastDownVoteIndex = headers.findIndex(h => h.toString().toLowerCase().includes('last') && h.toString().toLowerCase().includes('down') && h.toString().toLowerCase().includes('vote'));

  // Get current server_down value and increment it
  const currentValue = Number(data[rowIndex - 1][serverDownIndex]) || 0;
  const newValue = currentValue + 1;
  const currentDate = new Date();

  // Update the server_down count
  sheet.getRange(rowIndex, serverDownIndex + 1).setValue(newValue);

  // Update Last Down Vote timestamp (when player reports)
  if (lastDownVoteIndex !== -1) {
    sheet.getRange(rowIndex, lastDownVoteIndex + 1).setValue(currentDate);
  }

  const logMsg = gameTitle 
    ? `Updated server_down count for ${partKey} (${gameTitle}) to ${newValue} and set Last Down Vote`
    : `Updated server_down count for ${partKey} to ${newValue} and set Last Down Vote`;
  console.log(logMsg);

  return ContentService
    .createTextOutput(JSON.stringify({
      success: true,
      message: 'Server down count and Last Down Vote updated successfully',
      new_count: newValue,
      last_down_vote: currentDate.toLocaleDateString()
    }))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Get specific game data by part_key
 */
function getSpecificGame(partKey) {
  const gameData = getGameData();
  const game = gameData.find(g => g.part_key === partKey);
  
  if (!game) {
    throw new Error('Game with part_key "' + partKey + '" not found');
  }
  
  return ContentService
    .createTextOutput(JSON.stringify(game))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Test function - can be run manually to test the script
 */
function testScript() {
  try {
    const data = getGameData();
    console.log('Game data retrieved successfully:', data);
    return data;
  } catch (error) {
    console.error('Test failed:', error);
    return null;
  }
}

/**
 * Function to create sample data in the sheet (run once to set up)
 * Updated to match new sheet structure with Status, Last Updated, Last Down Vote columns
 */
function createSampleData() {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  
  // Clear existing data
  sheet.clear();
  
  // Add headers matching your new structure
  const headers = ['Part Key', 'TP-URL', 'DC-URL', 'Title', 'Status', 'Last Updated', 'Last Down Vote', 'Server Down', 'Image URL', 'Description'];
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  
  // Add sample data
  const sampleData = [
    ['trlx_tp', 'https://www.roblox.com/games/86148343932287/Foamy-Float-Frenzy-of-the-Neon-Lagoon', 'https://discord.gg/trlx', 'TRLX Con', 'Down', '25/08/2025', '25/08/2025', 1, 'rbxassetid://1044275350', 'This is a basic game where you can explore and have fun with friends. The admins of trlx are reliable users.'],
    ['trlx_tp', 'https://www.roblox.com/games/109522154617015/UPDATE-rainbow-friends-battlegrounds', 'https://discord.gg/trlx', 'TRLX Die Of Seg Online', 'Online', '25/08/2025', '25/08/2025', 1, 'rbxassetid://1044275350', 'This is a new game mode with exciting features and challenges for players to enjoy.'],
    ['hub_tp', 'https://www.roblox.com/games/987654321', 'https://discord.gg/hub', 'Gaming Hub - Main', 'Online', '25/08/2025', '', 0, '', 'The central hub for all gaming activities. Meet other players and discover new games together.'],
    ['test_tp', 'https://www.roblox.com/games/555666777', 'https://discord.gg/test', 'Test Server', 'Maintenance', '25/08/2025', '24/08/2025', 2, '', 'This is a test server for development and debugging purposes. Join to help test new features!']
  ];
  
  sheet.getRange(2, 1, sampleData.length, sampleData[0].length).setValues(sampleData);
  
  console.log('Sample data created successfully with new column structure!');
}

/**
 * Function to format the sheet for better appearance
 */
function formatSheet() {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  
  // Format header row
  const headerRange = sheet.getRange(1, 1, 1, sheet.getLastColumn());
  headerRange.setFontWeight('bold');
  headerRange.setBackground('#4285f4');
  headerRange.setFontColor('white');
  
  // Auto-resize columns
  sheet.autoResizeColumns(1, sheet.getLastColumn());
  
  // Freeze header row
  sheet.setFrozenRows(1);
  
  console.log('Sheet formatted successfully!');
}
