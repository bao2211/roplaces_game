-- Client script for teleportation GUI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local showTpGuiRemote = remoteEvents:WaitForChild("ShowTpGui")
local teleportPlayerRemote = remoteEvents:WaitForChild("TeleportPlayer")
local teleportFailedRemote = remoteEvents:WaitForChild("TeleportFailed")

-- GUI variables
local teleportGui = nil
local lastGuiShow = 0
local CLIENT_COOLDOWN = 2 -- seconds between GUI shows on client
local currentGameData = nil -- Store current game data for error handling

-- Function to show error message
local function showErrorMessage(message)
	-- Create error notification
	local errorGui = Instance.new("ScreenGui")
	errorGui.Name = "ErrorNotification"
	errorGui.Parent = playerGui
	
	local errorFrame = Instance.new("Frame")
	errorFrame.Size = UDim2.fromOffset(400, 120)
	errorFrame.Position = UDim2.new(0.5, -200, 0, -150)
	errorFrame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
	errorFrame.BorderSizePixel = 0
	errorFrame.Parent = errorGui
	
	local errorCorner = Instance.new("UICorner")
	errorCorner.CornerRadius = UDim.new(0, 12)
	errorCorner.Parent = errorFrame
	
	local errorTitle = Instance.new("TextLabel")
	errorTitle.Size = UDim2.new(1, -20, 0, 30)
	errorTitle.Position = UDim2.fromOffset(10, 10)
	errorTitle.BackgroundTransparency = 1
	errorTitle.Text = "⚠️ Teleport Failed"
	errorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	errorTitle.TextScaled = true
	errorTitle.TextXAlignment = Enum.TextXAlignment.Left
	errorTitle.Font = Enum.Font.GothamBold
	errorTitle.Parent = errorFrame
	
	local errorText = Instance.new("TextLabel")
	errorText.Size = UDim2.new(1, -20, 0, 60)
	errorText.Position = UDim2.fromOffset(10, 45)
	errorText.BackgroundTransparency = 1
	errorText.Text = message
	errorText.TextColor3 = Color3.fromRGB(255, 255, 255)
	errorText.TextScaled = true
	errorText.TextXAlignment = Enum.TextXAlignment.Left
	errorText.TextYAlignment = Enum.TextYAlignment.Top
	errorText.TextWrapped = true
	errorText.Font = Enum.Font.Gotham
	errorText.Parent = errorFrame
	
	-- Animate in
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(errorFrame, tweenInfo, {
		Position = UDim2.new(0.5, -200, 0, 20)
	})
	tween:Play()
	
	-- Auto-hide after 5 seconds
	wait(5)
	local tweenOut = TweenService:Create(errorFrame, tweenInfo, {
		Position = UDim2.new(0.5, -200, 0, -150)
	})
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		errorGui:Destroy()
	end)
end

-- Function to create the teleport GUI
local function createTeleportGui()
	-- Main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TeleportGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Background frame
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "Background"
	backgroundFrame.Size = UDim2.fromOffset(400, 250)
	backgroundFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.Parent = screenGui

	-- Add rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = backgroundFrame

	-- Add shadow effect
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 10, 1, 10)
	shadow.Position = UDim2.fromOffset(-5, -5)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.8
	shadow.ZIndex = backgroundFrame.ZIndex - 1
	shadow.Parent = backgroundFrame

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 12)
	shadowCorner.Parent = shadow

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -20, 0, 40)
	titleLabel.Position = UDim2.fromOffset(10, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Game Information"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = backgroundFrame

	-- Game title
	local gameTitleLabel = Instance.new("TextLabel")
	gameTitleLabel.Name = "GameTitle"
	gameTitleLabel.Size = UDim2.new(1, -20, 0, 30)
	gameTitleLabel.Position = UDim2.fromOffset(10, 60)
	gameTitleLabel.BackgroundTransparency = 1
	gameTitleLabel.Text = "Game Title"
	gameTitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	gameTitleLabel.TextScaled = true
	gameTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	gameTitleLabel.Font = Enum.Font.Gotham
	gameTitleLabel.Parent = backgroundFrame

	-- Discord URL label
	local discordLabel = Instance.new("TextLabel")
	discordLabel.Name = "DiscordLabel"
	discordLabel.Size = UDim2.new(1, -20, 0, 20)
	discordLabel.Position = UDim2.fromOffset(10, 100)
	discordLabel.BackgroundTransparency = 1
	discordLabel.Text = "Discord Server:"
	discordLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	discordLabel.TextScaled = true
	discordLabel.TextXAlignment = Enum.TextXAlignment.Left
	discordLabel.Font = Enum.Font.Gotham
	discordLabel.Parent = backgroundFrame

	-- Discord URL text box (for copying)
	local discordTextBox = Instance.new("TextBox")
	discordTextBox.Name = "DiscordUrl"
	discordTextBox.Size = UDim2.new(1, -20, 0, 30)
	discordTextBox.Position = UDim2.fromOffset(10, 125)
	discordTextBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	discordTextBox.BorderSizePixel = 0
	discordTextBox.Text = ""
	discordTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	discordTextBox.TextScaled = true
	discordTextBox.TextXAlignment = Enum.TextXAlignment.Left
	discordTextBox.Font = Enum.Font.Gotham
	discordTextBox.ClearTextOnFocus = false
	discordTextBox.Parent = backgroundFrame

	local discordCorner = Instance.new("UICorner")
	discordCorner.CornerRadius = UDim.new(0, 6)
	discordCorner.Parent = discordTextBox

	-- Copy instruction note
	local copyNote = Instance.new("TextLabel")
	copyNote.Name = "CopyNote"
	copyNote.Size = UDim2.new(1, -20, 0, 15)
	copyNote.Position = UDim2.fromOffset(10, 160)
	copyNote.BackgroundTransparency = 1
	copyNote.Text = "💡 Select the text above to copy and join the communication channel"
	copyNote.TextColor3 = Color3.fromRGB(150, 150, 150)
	copyNote.TextScaled = true
	copyNote.TextXAlignment = Enum.TextXAlignment.Left
	copyNote.Font = Enum.Font.Gotham
	copyNote.Parent = backgroundFrame

	-- Join button
	local joinButton = Instance.new("TextButton")
	joinButton.Name = "JoinButton"
	joinButton.Size = UDim2.new(1, -20, 0, 40)
	joinButton.Position = UDim2.fromOffset(10, 185)
	joinButton.BackgroundColor3 = Color3.fromRGB(67, 181, 129)
	joinButton.BorderSizePixel = 0
	joinButton.Text = "Join Game"
	joinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	joinButton.TextScaled = true
	joinButton.Font = Enum.Font.GothamBold
	joinButton.Parent = backgroundFrame

	local joinCorner = Instance.new("UICorner")
	joinCorner.CornerRadius = UDim.new(0, 8)
	joinCorner.Parent = joinButton

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.Position = UDim2.new(1, -40, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = backgroundFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 15)
	closeCorner.Parent = closeButton

	return screenGui
end

-- Function to show the teleport GUI with game data
local function showTeleportGui(gameData)
	-- Check client-side cooldown
	local currentTime = tick()
	if currentTime - lastGuiShow < CLIENT_COOLDOWN then
		return -- Still in cooldown
	end

	lastGuiShow = currentTime

	if teleportGui then
		teleportGui:Destroy()
	end

	teleportGui = createTeleportGui()
	teleportGui.Parent = playerGui

	-- Update GUI with game data
	local backgroundFrame = teleportGui.Background
	local gameTitleLabel = backgroundFrame.GameTitle
	local discordTextBox = backgroundFrame.DiscordUrl
	local joinButton = backgroundFrame.JoinButton
	local closeButton = backgroundFrame.CloseButton

	-- Set game data
	currentGameData = gameData -- Store for error handling
	gameTitleLabel.Text = gameData.title or "Unknown Game"
	discordTextBox.Text = gameData.dc_url or ""

	-- Animate GUI entrance
	backgroundFrame.Position = UDim2.new(0.5, -200, 1, 0)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(backgroundFrame, tweenInfo, {
		Position = UDim2.new(0.5, -200, 0.5, -125),
	})
	tween:Play()

	-- Button functionality
	joinButton.MouseButton1Click:Connect(function()
		if gameData.tp_url and gameData.tp_url ~= "" then
			teleportPlayerRemote:FireServer(gameData.tp_url, gameData.part_key)
			teleportGui:Destroy()
			teleportGui = nil
		end
	end)

	local function closeGui()
		if teleportGui then
			local tweenOut = TweenService:Create(backgroundFrame, tweenInfo, {
				Position = UDim2.new(0.5, -200, 1, 0),
			})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				teleportGui:Destroy()
				teleportGui = nil
			end)
		end
	end

	closeButton.MouseButton1Click:Connect(closeGui)

	-- Close on Escape key
	local connection
	connection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and teleportGui then
			closeGui()
			connection:Disconnect()
		end
	end)
end

-- Connect to server events
showTpGuiRemote.OnClientEvent:Connect(showTeleportGui)

-- Handle teleport failures
teleportFailedRemote.OnClientEvent:Connect(function(errorMessage, partKey)
	-- Show error message to player
	spawn(function()
		showErrorMessage(errorMessage)
	end)
	
	-- Close teleport GUI if it's open
	if teleportGui then
		teleportGui:Destroy()
		teleportGui = nil
	end
end)

print("Teleportation client system loaded!")
