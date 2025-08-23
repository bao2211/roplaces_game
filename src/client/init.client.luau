-- Teleportation Client Script
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get remote events
local remoteEvents = game.ReplicatedStorage:WaitForChild("RemoteEvents")
local showTpGuiRemote = remoteEvents:WaitForChild("ShowTpGui")
local teleportPlayerRemote = remoteEvents:WaitForChild("TeleportPlayer")
local teleportFailedRemote = remoteEvents:WaitForChild("TeleportFailed")

print("[TP Client Debug] RemoteEvents found successfully")
print("[TP Client Debug] ShowTpGui:", showTpGuiRemote)
print("[TP Client Debug] TeleportPlayer:", teleportPlayerRemote)
print("[TP Client Debug] TeleportFailed:", teleportFailedRemote)

-- Variables
local teleportGui = nil
local currentTeleportData = nil

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Responsive dimensions
local function getResponsiveDimensions()
	local screenSize = workspace.CurrentCamera.ViewportSize

	if isMobile then
		-- Mobile dimensions (smaller and more compact)
		return {
			width = math.min(screenSize.X * 0.95, 420),
			height = math.min(screenSize.Y * 0.8, 500),
			imageSize = 120,
			padding = 8,
			titleSize = 18,
			textSize = 14,
			buttonHeight = 40,
			sidebarWidth = 140,
		}
	else
		-- Desktop dimensions
		return {
			width = 600,
			height = 550,
			imageSize = 150,
			padding = 15,
			titleSize = 22,
			textSize = 16,
			buttonHeight = 50,
			sidebarWidth = 200,
		}
	end
end

-- Function to show error messages
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
		Position = UDim2.new(0.5, -200, 0, 20),
	})
	tween:Play()

	-- Auto-hide after 5 seconds
	wait(5)
	local tweenOut = TweenService:Create(errorFrame, tweenInfo, {
		Position = UDim2.new(0.5, -200, 0, -150),
	})
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		errorGui:Destroy()
	end)
end

-- Function to create the teleport GUI
local function createTeleportGui()
	-- Destroy existing GUI if any
	if teleportGui then
		teleportGui:Destroy()
	end

	-- Get responsive dimensions
	local currentDimensions = getResponsiveDimensions()

	-- Create main GUI
	teleportGui = Instance.new("ScreenGui")
	teleportGui.Name = "TeleportGui"
	teleportGui.Parent = playerGui

	-- Main frame (background)
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "BackgroundFrame"
	backgroundFrame.Size = UDim2.fromOffset(currentDimensions.width, currentDimensions.height)
	backgroundFrame.Position = UDim2.new(0.5, -currentDimensions.width / 2, 1, 0) -- Start off-screen
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.Parent = teleportGui

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = backgroundFrame

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.fromOffset(-3, -3)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.8
	shadow.ZIndex = backgroundFrame.ZIndex - 1
	shadow.Parent = backgroundFrame

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 15)
	shadowCorner.Parent = shadow

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.Position = UDim2.new(1, -40, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 16
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = backgroundFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	return backgroundFrame, closeButton, currentDimensions
end

-- Function to update GUI content for selected game
local function updateGuiForSelectedGame(backgroundFrame, selectedGame, currentDimensions)
	-- Clear existing content (except close button)
	for _, child in pairs(backgroundFrame:GetChildren()) do
		if child.Name ~= "CloseButton" and child.Name ~= "Shadow" and not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	-- Main content area
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -20, 1, -50)
	contentFrame.Position = UDim2.fromOffset(10, 40)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = backgroundFrame

	-- Check if image and description are available
	local hasImage = selectedGame.imageUrl and selectedGame.imageUrl ~= ""
	local hasDescription = selectedGame.description and selectedGame.description ~= ""

	if hasImage or hasDescription then
		-- Main area (left side for content, right side for image/description)
		local mainArea = Instance.new("Frame")
		mainArea.Name = "MainArea"
		mainArea.Size = UDim2.new(1, -currentDimensions.sidebarWidth - 10, 1, 0)
		mainArea.Position = UDim2.fromOffset(0, 0)
		mainArea.BackgroundTransparency = 1
		mainArea.Parent = contentFrame

		-- Sidebar for image and description
		local sidebar = Instance.new("Frame")
		sidebar.Name = "Sidebar"
		sidebar.Size = UDim2.fromOffset(currentDimensions.sidebarWidth, currentDimensions.height - 60)
		sidebar.Position = UDim2.new(1, -currentDimensions.sidebarWidth, 0, 0)
		sidebar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		sidebar.BorderSizePixel = 0
		sidebar.Parent = contentFrame

		local sidebarCorner = Instance.new("UICorner")
		sidebarCorner.CornerRadius = UDim.new(0, 8)
		sidebarCorner.Parent = sidebar

		-- Sidebar content with scrolling
		local sidebarScroll = Instance.new("ScrollingFrame")
		sidebarScroll.Size = UDim2.new(1, -10, 1, -10)
		sidebarScroll.Position = UDim2.fromOffset(5, 5)
		sidebarScroll.BackgroundTransparency = 1
		sidebarScroll.BorderSizePixel = 0
		sidebarScroll.ScrollBarThickness = 4
		sidebarScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
		sidebarScroll.Parent = sidebar

		local currentY = 0

		-- Image in sidebar
		if hasImage then
			local gameImage = Instance.new("ImageLabel")
			gameImage.Name = "GameImage"
			gameImage.Size = UDim2.fromOffset(currentDimensions.imageSize, currentDimensions.imageSize)
			gameImage.Position =
				UDim2.fromOffset((currentDimensions.sidebarWidth - currentDimensions.imageSize) / 2 - 5, currentY)
			gameImage.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
			gameImage.BorderSizePixel = 0
			gameImage.Image = selectedGame.imageUrl
			gameImage.ScaleType = Enum.ScaleType.Fit
			gameImage.Parent = sidebarScroll

			local imageCorner = Instance.new("UICorner")
			imageCorner.CornerRadius = UDim.new(0, 8)
			imageCorner.Parent = gameImage

			currentY = currentY + currentDimensions.imageSize + currentDimensions.padding
		end

		-- Description in sidebar
		if hasDescription then
			local descLabel = Instance.new("TextLabel")
			descLabel.Name = "DescriptionLabel"
			descLabel.Size = UDim2.new(1, -10, 0, 0) -- Height will be auto-calculated
			descLabel.Position = UDim2.fromOffset(5, currentY)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = selectedGame.description
			descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			descLabel.TextSize = currentDimensions.textSize - 2
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.TextYAlignment = Enum.TextYAlignment.Top
			descLabel.TextWrapped = true
			descLabel.Font = Enum.Font.Gotham
			descLabel.Parent = sidebarScroll

			-- Calculate required height for description
			local textService = game:GetService("TextService")
			local textBounds = textService:GetTextSize(
				selectedGame.description,
				currentDimensions.textSize - 2,
				Enum.Font.Gotham,
				Vector2.new(currentDimensions.sidebarWidth - 20, math.huge)
			)
			descLabel.Size = UDim2.new(1, -10, 0, textBounds.Y)

			currentY = currentY + textBounds.Y + currentDimensions.padding
		end

		-- Update sidebar scroll canvas size
		sidebarScroll.CanvasSize = UDim2.fromOffset(0, currentY)
	end

	-- Game title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size =
		UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, currentDimensions.titleSize + 10)
	titleLabel.Position = UDim2.fromOffset(currentDimensions.padding, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = selectedGame.title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = currentDimensions.titleSize
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.TextWrapped = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = contentFrame

	-- Instruction text
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "InstructionLabel"
	instructionLabel.Size = UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, 40)
	instructionLabel.Position = UDim2.fromOffset(currentDimensions.padding, currentDimensions.titleSize + 20)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = "Copy the Discord URL below to join the communication channel, then teleport to the game!"
	instructionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	instructionLabel.TextSize = currentDimensions.textSize
	instructionLabel.TextXAlignment = Enum.TextXAlignment.Left
	instructionLabel.TextYAlignment = Enum.TextYAlignment.Top
	instructionLabel.TextWrapped = true
	instructionLabel.Font = Enum.Font.Gotham
	instructionLabel.Parent = contentFrame

	-- Discord section
	local discordFrame = Instance.new("Frame")
	discordFrame.Name = "DiscordFrame"
	discordFrame.Size = UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, 100)
	discordFrame.Position = UDim2.fromOffset(currentDimensions.padding, currentDimensions.titleSize + 80)
	discordFrame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
	discordFrame.BorderSizePixel = 0
	discordFrame.Parent = contentFrame

	local discordCorner = Instance.new("UICorner")
	discordCorner.CornerRadius = UDim.new(0, 12)
	discordCorner.Parent = discordFrame

	-- Discord header with icon and title
	local discordHeader = Instance.new("Frame")
	discordHeader.Size = UDim2.new(1, 0, 0, 35)
	discordHeader.Position = UDim2.fromOffset(0, 0)
	discordHeader.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	discordHeader.BorderSizePixel = 0
	discordHeader.Parent = discordFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = discordHeader

	-- Clip bottom corners of header
	local headerClipper = Instance.new("Frame")
	headerClipper.Size = UDim2.new(1, 0, 0, 12)
	headerClipper.Position = UDim2.fromOffset(0, 23)
	headerClipper.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	headerClipper.BorderSizePixel = 0
	headerClipper.Parent = discordHeader

	local discordIcon = Instance.new("TextLabel")
	discordIcon.Size = UDim2.fromOffset(24, 24)
	discordIcon.Position = UDim2.fromOffset(12, 6)
	discordIcon.BackgroundTransparency = 1
	discordIcon.Text = "💬"
	discordIcon.TextScaled = true
	discordIcon.Parent = discordHeader

	local discordLabel = Instance.new("TextLabel")
	discordLabel.Size = UDim2.new(1, -50, 0, 35)
	discordLabel.Position = UDim2.fromOffset(40, 0)
	discordLabel.BackgroundTransparency = 1
	discordLabel.Text = "Join Communication Channel"
	discordLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	discordLabel.TextSize = currentDimensions.textSize + 1
	discordLabel.TextXAlignment = Enum.TextXAlignment.Left
	discordLabel.TextYAlignment = Enum.TextYAlignment.Center
	discordLabel.Font = Enum.Font.GothamBold
	discordLabel.Parent = discordHeader

	-- Discord URL section
	local urlContainer = Instance.new("Frame")
	urlContainer.Size = UDim2.new(1, -20, 0, 55)
	urlContainer.Position = UDim2.fromOffset(10, 40)
	urlContainer.BackgroundTransparency = 1
	urlContainer.Parent = discordFrame

	local copyInstructionLabel = Instance.new("TextLabel")
	copyInstructionLabel.Size = UDim2.new(1, 0, 0, 18)
	copyInstructionLabel.Position = UDim2.fromOffset(0, 0)
	copyInstructionLabel.BackgroundTransparency = 1
	copyInstructionLabel.Text = "Click the link below to select and copy:"
	copyInstructionLabel.TextColor3 = Color3.fromRGB(185, 187, 190)
	copyInstructionLabel.TextSize = currentDimensions.textSize - 2
	copyInstructionLabel.TextXAlignment = Enum.TextXAlignment.Left
	copyInstructionLabel.Font = Enum.Font.Gotham
	copyInstructionLabel.Parent = urlContainer

	local discordUrl = Instance.new("TextBox")
	discordUrl.Size = UDim2.new(1, 0, 0, 32)
	discordUrl.Position = UDim2.fromOffset(0, 20)
	discordUrl.BackgroundColor3 = Color3.fromRGB(64, 68, 75)
	discordUrl.BorderSizePixel = 0
	discordUrl.Text = selectedGame.discordUrl
	discordUrl.TextColor3 = Color3.fromRGB(114, 137, 218)
	discordUrl.TextSize = currentDimensions.textSize
	discordUrl.TextXAlignment = Enum.TextXAlignment.Center
	discordUrl.TextYAlignment = Enum.TextYAlignment.Center
	discordUrl.Font = Enum.Font.GothamMedium
	discordUrl.ClearTextOnFocus = false
	discordUrl.TextEditable = false
	discordUrl.Parent = urlContainer

	local urlCorner = Instance.new("UICorner")
	urlCorner.CornerRadius = UDim.new(0, 6)
	urlCorner.Parent = discordUrl

	-- Add a subtle border/highlight effect
	local urlStroke = Instance.new("UIStroke")
	urlStroke.Color = Color3.fromRGB(114, 137, 218)
	urlStroke.Transparency = 0.7
	urlStroke.Thickness = 1
	urlStroke.Parent = discordUrl

	-- Gamemode selector (if multiple games available)
	local gamemodeY = currentDimensions.titleSize + 200
	if currentTeleportData and #currentTeleportData > 1 then
		-- Gamemode selector frame
		local gamemodeFrame = Instance.new("Frame")
		gamemodeFrame.Name = "GamemodeFrame"
		gamemodeFrame.Size = UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, 60)
		gamemodeFrame.Position = UDim2.fromOffset(currentDimensions.padding, gamemodeY)
		gamemodeFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
		gamemodeFrame.BorderSizePixel = 0
		gamemodeFrame.Parent = contentFrame

		local gamemodeCorner = Instance.new("UICorner")
		gamemodeCorner.CornerRadius = UDim.new(0, 8)
		gamemodeCorner.Parent = gamemodeFrame

		-- Gamemode label
		local gamemodeLabel = Instance.new("TextLabel")
		gamemodeLabel.Size = UDim2.new(1, -20, 0, 25)
		gamemodeLabel.Position = UDim2.fromOffset(10, 5)
		gamemodeLabel.BackgroundTransparency = 1
		gamemodeLabel.Text = "Select Gamemode:"
		gamemodeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		gamemodeLabel.TextSize = currentDimensions.textSize
		gamemodeLabel.TextXAlignment = Enum.TextXAlignment.Left
		gamemodeLabel.Font = Enum.Font.GothamBold
		gamemodeLabel.Parent = gamemodeFrame

		-- Gamemode dropdown
		local gamemodeDropdown = Instance.new("TextButton")
		gamemodeDropdown.Name = "GamemodeDropdown"
		gamemodeDropdown.Size = UDim2.new(1, -20, 0, 25)
		gamemodeDropdown.Position = UDim2.fromOffset(10, 30)
		gamemodeDropdown.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
		gamemodeDropdown.BorderSizePixel = 0
		gamemodeDropdown.Text = selectedGame.title .. " ▼"
		gamemodeDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
		gamemodeDropdown.TextSize = currentDimensions.textSize - 2
		gamemodeDropdown.TextXAlignment = Enum.TextXAlignment.Left
		gamemodeDropdown.Font = Enum.Font.Gotham
		gamemodeDropdown.Parent = gamemodeFrame

		local dropdownCorner = Instance.new("UICorner")
		dropdownCorner.CornerRadius = UDim.new(0, 4)
		dropdownCorner.Parent = gamemodeDropdown

		-- Dropdown functionality
		local dropdownOpen = false
		local dropdownList = nil

		gamemodeDropdown.MouseButton1Click:Connect(function()
			print("[TP Client Debug] Gamemode dropdown clicked, dropdownOpen:", dropdownOpen)
			if dropdownOpen then
				-- Close dropdown
				print("[TP Client Debug] Closing dropdown")
				if dropdownList then
					dropdownList:Destroy()
					dropdownList = nil
				end
				dropdownOpen = false
				gamemodeDropdown.Text = selectedGame.title .. " ▼"
			else
				-- Open dropdown
				print("[TP Client Debug] Opening dropdown")
				dropdownOpen = true
				gamemodeDropdown.Text = selectedGame.title .. " ▲"

				-- Create dropdown list
				dropdownList = Instance.new("Frame")
				dropdownList.Name = "DropdownList"
				dropdownList.Size = UDim2.new(1, 0, 0, #currentTeleportData * 30)
				dropdownList.Position = UDim2.fromOffset(0, 60)
				dropdownList.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
				dropdownList.BorderSizePixel = 0
				dropdownList.ZIndex = 100  -- Much higher ZIndex to ensure it's on top
				dropdownList.ClipsDescendants = false
				dropdownList.Parent = backgroundFrame  -- Parent to main frame instead of gamemode frame to avoid clipping

				-- Adjust position relative to backgroundFrame instead of gamemodeFrame
				local gamemodeFramePos = gamemodeFrame.Position
				local gamemodeFrameSize = gamemodeFrame.Size
				dropdownList.Position = UDim2.new(
					gamemodeFramePos.X.Scale, 
					gamemodeFramePos.X.Offset, 
					gamemodeFramePos.Y.Scale, 
					gamemodeFramePos.Y.Offset + gamemodeFrameSize.Y.Offset
				)
				dropdownList.Size = UDim2.new(gamemodeFrameSize.X.Scale, gamemodeFrameSize.X.Offset - 20, 0, #currentTeleportData * 30)

				local listCorner = Instance.new("UICorner")
				listCorner.CornerRadius = UDim.new(0, 4)
				listCorner.Parent = dropdownList

				-- Create buttons for each gamemode
				print("[TP Client Debug] Creating dropdown options for", #currentTeleportData, "games")
				for i, gameData in ipairs(currentTeleportData) do
					print("[TP Client Debug] Game", i, ":", gameData.title)
					local optionButton = Instance.new("TextButton")
					optionButton.Size = UDim2.new(1, -10, 0, 25)
					optionButton.Position = UDim2.fromOffset(5, (i - 1) * 30 + 2)
					optionButton.BackgroundColor3 = gameData.title == selectedGame.title
							and Color3.fromRGB(70, 120, 180)
						or Color3.fromRGB(70, 70, 75)
					optionButton.BorderSizePixel = 0
					optionButton.Text = gameData.title
					optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
					optionButton.TextSize = currentDimensions.textSize - 2
					optionButton.TextXAlignment = Enum.TextXAlignment.Left
					optionButton.Font = Enum.Font.Gotham
					optionButton.ZIndex = 101  -- Higher than dropdown list
					optionButton.Parent = dropdownList

					local optionCorner = Instance.new("UICorner")
					optionCorner.CornerRadius = UDim.new(0, 3)
					optionCorner.Parent = optionButton

					-- Option click handler
					optionButton.MouseButton1Click:Connect(function()
						print("[TP Client Debug] Option clicked:", gameData.title)
						-- Update selected game
						updateGuiForSelectedGame(backgroundFrame, gameData, currentDimensions)

						-- Close dropdown
						if dropdownList then
							dropdownList:Destroy()
							dropdownList = nil
						end
						dropdownOpen = false
					end)
				end
			end
		end)

		gamemodeY = gamemodeY + 80
	end

	-- Play button
	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size =
		UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, currentDimensions.buttonHeight)
	playButton.Position = UDim2.fromOffset(currentDimensions.padding, gamemodeY + 20)
	playButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
	playButton.BorderSizePixel = 0
	playButton.Text = "🎮 Play Game"
	playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	playButton.TextSize = currentDimensions.textSize + 2
	playButton.Font = Enum.Font.GothamBold
	playButton.Parent = contentFrame

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 8)
	playCorner.Parent = playButton

	-- Button click handlers
	playButton.MouseButton1Click:Connect(function()
		-- Request teleportation with the selected game's teleport URL, part key, and title
		teleportPlayerRemote:FireServer(selectedGame.tp_url, selectedGame.partKey, selectedGame.title)
	end)

	return backgroundFrame
end

-- Function to show the teleport GUI
local function showTeleportGui(teleportData)
	print("[TP Client Debug] showTeleportGui called")
	print("[TP Client Debug] teleportData:", teleportData)

	currentTeleportData = teleportData

	-- Use first game as default selection
	local selectedGame = teleportData[1]
	print("[TP Client Debug] Selected game:", selectedGame.title)

	-- Create the GUI
	local backgroundFrame, closeButton, currentDimensions = createTeleportGui()

	-- Update content for selected game
	updateGuiForSelectedGame(backgroundFrame, selectedGame, currentDimensions)

	-- Animate GUI in
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(backgroundFrame, tweenInfo, {
		Position = UDim2.new(0.5, -currentDimensions.width / 2, 0.5, -currentDimensions.height / 2),
	})
	tween:Play()

	-- Close function
	local function closeGui()
		if teleportGui then
			local tweenOut = TweenService:Create(backgroundFrame, tweenInfo, {
				Position = UDim2.new(0.5, -currentDimensions.width / 2, 1, 0),
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
showTpGuiRemote.OnClientEvent:Connect(function(teleportData)
	print("[TP Client Debug] Received teleport data from server")
	print("[TP Client Debug] Data type:", type(teleportData))
	if teleportData then
		print("[TP Client Debug] Data length:", #teleportData)
		if #teleportData > 0 then
			print("[TP Client Debug] First game title:", teleportData[1].title)
		end
	end

	showTeleportGui(teleportData)
end)

-- Handle teleport failures
teleportFailedRemote.OnClientEvent:Connect(function(errorMessage)
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
print("[TP Client Debug] Client script initialization complete")
