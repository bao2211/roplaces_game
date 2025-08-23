/**
 * Google Apps Script for Roblox Teleportation System
 * This script serves game data from a Google Sheet to your Roblox game
 * 
 * Setup Instructions:
 * 1. Create a new Google Sheet with columns: Part Key, TP-URL, DC-URL, Title, Active, Last Updated, Server Down, Image URL
 * 2. Replace SHEET_ID with your Google Sheet ID
 * 3. Deploy this script as a web app with execute permissions for "Anyone"
 * 4. Copy the deployment URL and use it in your Roblox server script
 */

// Configuration
const SHEET_ID = 'YOUR_GOOGLE_SHEET_ID_HERE'; // Replace with your actual Google Sheet ID
const SHEET_NAME = 'Sheet1'; // Replace with your sheet name if different

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
  const headers = data[0].map(header => header.toString().toLowerCase().replace(/[^a-z0-9]/g, '_'));
  const gameData = [];
  
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
      gameData.push(gameInfo);
    }
  }
  
  return gameData;
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
    const header = headers[j].toString().toLowerCase().replace(/[^a-z0-9]/g, '_');
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
    const header = headers[j].toString().toLowerCase().replace(/[^a-z0-9]/g, '_');
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
 */
function createSampleData() {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  
  // Clear existing data
  sheet.clear();
  
  // Add headers
  const headers = ['Part Key', 'TP-URL', 'DC-URL', 'Title', 'Active', 'Last Updated', 'Server Down', 'Image URL'];
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  
  // Add sample data
  const sampleData = [
    ['trlx_tp', 'https://www.roblox.com/games/123456789', 'https://discord.gg/trlx', 'TRLX Games', true, new Date(), 3, 'https://example.com/trlx.png'],
    ['hub_tp', 'https://www.roblox.com/games/987654321', 'https://discord.gg/hub', 'Gaming Hub', true, new Date(), 0, 'https://example.com/hub.png'],
    ['test_tp', 'https://www.roblox.com/games/555666777', 'https://discord.gg/test', 'Test Server', false, new Date(), 1, '']
  ];
  
  sheet.getRange(2, 1, sampleData.length, sampleData[0].length).setValues(sampleData);
  
  console.log('Sample data created successfully!');
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
