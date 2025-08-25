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
local reportServerRemote = remoteEvents:WaitForChild("ReportServer")
local showLoadingRemote = remoteEvents:WaitForChild("ShowLoading")

print("[TP Client Debug] RemoteEvents found successfully")
print("[TP Client Debug] ShowTpGui:", showTpGuiRemote)
print("[TP Client Debug] TeleportPlayer:", teleportPlayerRemote)
print("[TP Client Debug] TeleportFailed:", teleportFailedRemote)

-- Variables
local teleportGui = nil
local loadingGui = nil
local currentTeleportData = nil
local selectedGame = nil -- Track the currently selected game globally
local reportCooldowns = {} -- Track cooldown per gamemode/part: [partKey_tpUrl] = lastReportTime
local REPORT_COOLDOWN = 30 * 60 -- 30 minutes in seconds

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
-- TEMPORARY: Force mobile mode for testing (remove this line when done testing)
-- isMobile = true

-- Responsive dimensions
local function getResponsiveDimensions()
	local screenSize = workspace.CurrentCamera.ViewportSize

	if isMobile then
		-- Mobile dimensions (optimized for horizontal space and scrolling)
		local mobileDimensions = {
			width = math.min(screenSize.X * 0.95, screenSize.X - 20), -- Use almost full width
			height = math.min(screenSize.Y * 0.8, screenSize.Y - 100), -- Use more vertical space
			imageSize = 80, -- Increased for better visibility
			padding = 8,
			titleSize = 14,
			textSize = 12,
			buttonHeight = 35,
			sidebarWidth = 0, -- No sidebar on mobile
		}
		return mobileDimensions
	else
		-- Desktop dimensions
		local desktopDimensions = {
			width = 600,
			height = 550,
			imageSize = 150,
			padding = 15,
			titleSize = 22,
			textSize = 16,
			buttonHeight = 50,
			sidebarWidth = 200,
		}
		return desktopDimensions
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

-- Function to show success messages
local function showSuccessMessage(message)
	-- Create success notification
	local successGui = Instance.new("ScreenGui")
	successGui.Name = "SuccessNotification"
	successGui.Parent = playerGui

	local successFrame = Instance.new("Frame")
	successFrame.Size = UDim2.fromOffset(400, 120)
	successFrame.Position = UDim2.new(0.5, -200, 0, -150)
	successFrame.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
	successFrame.BorderSizePixel = 0
	successFrame.Parent = successGui

	local successCorner = Instance.new("UICorner")
	successCorner.CornerRadius = UDim.new(0, 12)
	successCorner.Parent = successFrame

	local successTitle = Instance.new("TextLabel")
	successTitle.Size = UDim2.new(1, -20, 0, 30)
	successTitle.Position = UDim2.fromOffset(10, 10)
	successTitle.BackgroundTransparency = 1
	successTitle.Text = "✅ Report Sent"
	successTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	successTitle.TextScaled = true
	successTitle.TextXAlignment = Enum.TextXAlignment.Left
	successTitle.Font = Enum.Font.GothamBold
	successTitle.Parent = successFrame

	local successText = Instance.new("TextLabel")
	successText.Size = UDim2.new(1, -20, 0, 60)
	successText.Position = UDim2.fromOffset(10, 45)
	successText.BackgroundTransparency = 1
	successText.Text = message
	successText.TextColor3 = Color3.fromRGB(255, 255, 255)
	successText.TextScaled = true
	successText.TextXAlignment = Enum.TextXAlignment.Left
	successText.TextYAlignment = Enum.TextYAlignment.Top
	successText.TextWrapped = true
	successText.Font = Enum.Font.Gotham
	successText.Parent = successFrame

	-- Animate in
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(successFrame, tweenInfo, {
		Position = UDim2.new(0.5, -200, 0, 20),
	})
	tween:Play()

	-- Auto-hide after 4 seconds
	wait(4)
	local tweenOut = TweenService:Create(successFrame, tweenInfo, {
		Position = UDim2.new(0.5, -200, 0, -150),
	})
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		successGui:Destroy()
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
	-- Different background colors for mobile vs desktop to make it obvious
	backgroundFrame.BackgroundColor3 = isMobile and Color3.fromRGB(45, 60, 45) or Color3.fromRGB(45, 45, 50)
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
local function updateGuiForSelectedGame(backgroundFrame, newSelectedGame, currentDimensions)
	-- Update the global selectedGame variable
	selectedGame = newSelectedGame
	-- Clear existing content (except close button)
	for _, child in pairs(backgroundFrame:GetChildren()) do
		if child.Name ~= "CloseButton" and child.Name ~= "Shadow" and not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	-- Remove any old play/report button references to avoid duplicate connections
	if backgroundFrame:FindFirstChild("PlayButton") then
		backgroundFrame.PlayButton:Destroy()
	end
	if backgroundFrame:FindFirstChild("ReportButton") then
		backgroundFrame.ReportButton:Destroy()
	end

	-- Main content area (scrollable on mobile)
	local contentFrame
	if isMobile then
		-- Create scrolling frame for mobile
		contentFrame = Instance.new("ScrollingFrame")
		contentFrame.Name = "ContentFrame"
		contentFrame.Size = UDim2.new(1, -10, 1, -45)
		contentFrame.Position = UDim2.fromOffset(5, 40)
		contentFrame.BackgroundTransparency = 1
		contentFrame.BorderSizePixel = 0
		contentFrame.ScrollBarThickness = 4
		contentFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
		contentFrame.CanvasSize = UDim2.fromOffset(0, 0) -- Will be updated based on content
		contentFrame.Parent = backgroundFrame
	else
		-- Regular frame for desktop
		contentFrame = Instance.new("Frame")
		contentFrame.Name = "ContentFrame"
		contentFrame.Size = UDim2.new(1, -20, 1, -50)
		contentFrame.Position = UDim2.fromOffset(10, 40)
		contentFrame.BackgroundTransparency = 1
		contentFrame.Parent = backgroundFrame
	end

	-- Check if image and description are available
	local hasImage = selectedGame.imageUrl and selectedGame.imageUrl ~= ""
	local hasDescription = selectedGame.description and selectedGame.description ~= ""

	-- Mobile uses vertical layout, desktop uses sidebar
	if (hasImage or hasDescription) and not isMobile then
		-- Desktop: Main area (left side for content, right side for image/description)
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

	-- Track current Y position for mobile scrolling layout
	local currentY = 0

	-- Game title (responsive sizing)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	if isMobile then
		titleLabel.Size = UDim2.new(1, -16, 0, currentDimensions.titleSize + 5)
		titleLabel.Position = UDim2.fromOffset(8, currentY)
		currentY = currentY + currentDimensions.titleSize + 10
	else
		titleLabel.Size =
			UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, currentDimensions.titleSize + 10)
		titleLabel.Position = UDim2.fromOffset(currentDimensions.padding, 0)
	end
	titleLabel.BackgroundTransparency = 1
	-- Clean professional title with status indicator
	local statusEmoji = "🟢" -- Default green
	local statusColor = Color3.fromRGB(255, 255, 255) -- Default white

	if selectedGame.status then
		local status = selectedGame.status:lower()
		if status == "down" or status == "offline" then
			statusEmoji = "🔴"
			statusColor = Color3.fromRGB(255, 100, 100) -- Light red
		elseif status == "maintenance" or status == "updating" then
			statusEmoji = "🟡"
			statusColor = Color3.fromRGB(255, 255, 100) -- Light yellow
		elseif status == "online" or status == "up" then
			statusEmoji = "🟢"
			statusColor = Color3.fromRGB(100, 255, 100) -- Light green
		end
	end

	titleLabel.Text = statusEmoji .. " " .. selectedGame.title
	titleLabel.TextColor3 = statusColor
	titleLabel.TextSize = currentDimensions.titleSize
	titleLabel.TextXAlignment = isMobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.TextWrapped = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = contentFrame

	-- Status info label (small text below title)
	if selectedGame.status then
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "StatusLabel"
		if isMobile then
			statusLabel.Size = UDim2.new(1, -16, 0, 20)
			statusLabel.Position = UDim2.fromOffset(8, currentY)
			currentY = currentY + 25
		else
			statusLabel.Size = UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, 20)
			statusLabel.Position = UDim2.fromOffset(currentDimensions.padding, currentDimensions.titleSize + 10)
		end
		statusLabel.BackgroundTransparency = 1
		local statusText = "Server Status: " .. selectedGame.status
		if selectedGame.last_updated and selectedGame.last_updated ~= "" then
			statusText = statusText .. " • Last Updated: " .. selectedGame.last_updated
		end
		statusLabel.Text = statusText
		statusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		statusLabel.TextSize = currentDimensions.textSize - 4
		statusLabel.TextXAlignment = isMobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
		statusLabel.Font = Enum.Font.Gotham
		statusLabel.Parent = contentFrame
	end

	-- Instruction text (compact on mobile)
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "InstructionLabel"
	if isMobile then
		instructionLabel.Size = UDim2.new(1, -16, 0, 30)
		instructionLabel.Position = UDim2.fromOffset(8, currentY)
		currentY = currentY + 35
	else
		instructionLabel.Size = UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, 40)
		-- Adjust position to account for status label if present
		local yOffset = selectedGame.status and (currentDimensions.titleSize + 40) or (currentDimensions.titleSize + 20)
		instructionLabel.Position = UDim2.fromOffset(currentDimensions.padding, yOffset)
	end
	instructionLabel.BackgroundTransparency = 1
	-- Clean professional instruction text
	instructionLabel.Text = isMobile
			and "Copy the Discord URL below to join the communication channel you can scroll down to see content"
		or "Copy the Discord URL below to join the communication channel"
	instructionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	instructionLabel.TextSize = currentDimensions.textSize
	instructionLabel.TextXAlignment = Enum.TextXAlignment.Left
	instructionLabel.TextYAlignment = Enum.TextYAlignment.Top
	instructionLabel.TextWrapped = true
	instructionLabel.Font = Enum.Font.Gotham
	instructionLabel.Parent = contentFrame

	-- Discord section (mobile-responsive)
	local discordFrame = Instance.new("Frame")
	discordFrame.Name = "DiscordFrame"
	if isMobile then
		discordFrame.Size = UDim2.new(1, -16, 0, 60)
		discordFrame.Position = UDim2.fromOffset(8, currentY)
		currentY = currentY + 70
	else
		discordFrame.Size = UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, 100)
		-- Adjust position to account for status label if present
		local yOffset = selectedGame.status and (currentDimensions.titleSize + 120)
			or (currentDimensions.titleSize + 80)
		discordFrame.Position = UDim2.fromOffset(currentDimensions.padding, yOffset)
	end
	discordFrame.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	discordFrame.BorderSizePixel = 0
	discordFrame.Parent = contentFrame

	local discordCorner = Instance.new("UICorner")
	discordCorner.CornerRadius = UDim.new(0, isMobile and 6 or 12)
	discordCorner.Parent = discordFrame

	if not isMobile then
		-- Discord header with icon and title (desktop only)
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
	end

	-- Discord URL section (mobile and desktop)
	local urlContainer = Instance.new("Frame")
	urlContainer.Size = UDim2.new(1, isMobile and -8 or -20, 0, isMobile and 25 or 55) -- Reduced from 35 to 25 for mobile
	urlContainer.Position = UDim2.fromOffset(isMobile and 4 or 10, isMobile and 6 or 40) -- Adjusted position
	urlContainer.BackgroundTransparency = 1
	urlContainer.Parent = discordFrame

	if not isMobile then
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
	end

	local discordUrl = Instance.new("TextBox")
	discordUrl.Size = UDim2.new(1, 0, 0, isMobile and 18 or 32) -- Reduced from 22 to 18 for mobile
	discordUrl.Position = UDim2.fromOffset(0, isMobile and 0 or 20)
	discordUrl.BackgroundColor3 = Color3.fromRGB(64, 68, 75)
	discordUrl.BorderSizePixel = 0
	discordUrl.Text = selectedGame.discordUrl
	discordUrl.TextColor3 = Color3.fromRGB(114, 137, 218)
	discordUrl.TextSize = isMobile and currentDimensions.textSize - 1 or currentDimensions.textSize
	discordUrl.TextXAlignment = Enum.TextXAlignment.Center
	discordUrl.TextYAlignment = Enum.TextYAlignment.Center
	discordUrl.Font = Enum.Font.GothamMedium
	discordUrl.ClearTextOnFocus = false
	discordUrl.TextEditable = false
	discordUrl.Parent = urlContainer

	local urlCorner = Instance.new("UICorner")
	urlCorner.CornerRadius = UDim.new(0, isMobile and 4 or 6)
	urlCorner.Parent = discordUrl

	-- Add a subtle border/highlight effect
	local urlStroke = Instance.new("UIStroke")
	urlStroke.Color = Color3.fromRGB(114, 137, 218)
	urlStroke.Transparency = 0.7
	urlStroke.Thickness = 1
	urlStroke.Parent = discordUrl

	-- Mobile/Desktop image and description layout
	if isMobile and (hasImage or hasDescription) then
		-- Create horizontal container for image and description
		local mediaContainer = Instance.new("Frame")
		mediaContainer.Name = "MediaContainer"
		mediaContainer.Size = UDim2.new(1, -16, 0, currentDimensions.imageSize + 10)
		mediaContainer.Position = UDim2.fromOffset(8, currentY)
		mediaContainer.BackgroundTransparency = 1
		mediaContainer.Parent = contentFrame

		if hasImage then
			-- Image on the left
			local gameImage = Instance.new("ImageLabel")
			gameImage.Size = UDim2.fromOffset(currentDimensions.imageSize, currentDimensions.imageSize)
			gameImage.Position = UDim2.fromOffset(0, 0)
			gameImage.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
			gameImage.BorderSizePixel = 0
			gameImage.Image = selectedGame.imageUrl
			gameImage.ScaleType = Enum.ScaleType.Crop
			gameImage.Parent = mediaContainer

			local imageCorner = Instance.new("UICorner")
			imageCorner.CornerRadius = UDim.new(0, 8)
			imageCorner.Parent = gameImage
		end

		if hasDescription then
			-- Description on the right
			local descFrame = Instance.new("ScrollingFrame")
			descFrame.Size =
				UDim2.new(1, hasImage and -(currentDimensions.imageSize + 10) or -5, 0, currentDimensions.imageSize)
			descFrame.Position = UDim2.fromOffset(hasImage and (currentDimensions.imageSize + 10) or 0, 0)
			descFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
			descFrame.BorderSizePixel = 0
			descFrame.ScrollBarThickness = 3
			descFrame.Parent = mediaContainer

			local descCorner = Instance.new("UICorner")
			descCorner.CornerRadius = UDim.new(0, 6)
			descCorner.Parent = descFrame

			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(1, -10, 0, 0)
			descLabel.Position = UDim2.fromOffset(5, 5)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = selectedGame.description
			descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			descLabel.TextSize = currentDimensions.textSize
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.TextYAlignment = Enum.TextYAlignment.Top
			descLabel.TextWrapped = true
			descLabel.Font = Enum.Font.Gotham
			descLabel.Parent = descFrame

			-- Calculate required height for description
			local textService = game:GetService("TextService")
			local textSize = textService:GetTextSize(
				selectedGame.description,
				currentDimensions.textSize,
				Enum.Font.Gotham,
				Vector2.new(descFrame.AbsoluteSize.X - 10, math.huge)
			)
			descLabel.Size = UDim2.new(1, -10, 0, math.max(textSize.Y + 10, currentDimensions.imageSize - 10))
			descFrame.CanvasSize = UDim2.fromOffset(0, textSize.Y + 20)
		end

		currentY = currentY + currentDimensions.imageSize + 20
	end

	-- Gamemode selector (if multiple games available) - mobile responsive
	-- Adjust position to account for status label if present
	local gamemodeY = isMobile and currentY
		or (selectedGame.status and (currentDimensions.titleSize + 240) or (currentDimensions.titleSize + 200))
	if currentTeleportData and #currentTeleportData > 1 then
		if isMobile then
			-- Mobile: Horizontal scrollable button list
			local gamemodeContainer = Instance.new("Frame")
			gamemodeContainer.Name = "GamemodeContainer"
			gamemodeContainer.Size = UDim2.new(1, -16, 0, 50)
			gamemodeContainer.Position = UDim2.fromOffset(8, currentY)
			gamemodeContainer.BackgroundTransparency = 1
			gamemodeContainer.Parent = contentFrame

			-- Title label
			local modeLabel = Instance.new("TextLabel")
			modeLabel.Size = UDim2.new(1, 0, 0, 15)
			modeLabel.Position = UDim2.fromOffset(0, 0)
			modeLabel.BackgroundTransparency = 1
			modeLabel.Text = "Game Modes:"
			modeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			modeLabel.TextSize = currentDimensions.textSize
			modeLabel.TextXAlignment = Enum.TextXAlignment.Left
			modeLabel.Font = Enum.Font.GothamBold
			modeLabel.Parent = gamemodeContainer

			-- Scrollable frame for buttons
			local buttonScrollFrame = Instance.new("ScrollingFrame")
			buttonScrollFrame.Size = UDim2.new(1, 0, 0, 30)
			buttonScrollFrame.Position = UDim2.fromOffset(0, 18)
			buttonScrollFrame.BackgroundTransparency = 1
			buttonScrollFrame.BorderSizePixel = 0
			buttonScrollFrame.ScrollBarThickness = 3
			buttonScrollFrame.ScrollingDirection = Enum.ScrollingDirection.X
			buttonScrollFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.None
			buttonScrollFrame.Parent = gamemodeContainer

			-- Calculate total width needed for all buttons
			local totalWidth = 0
			local buttonWidth = 80
			local buttonSpacing = 8

			-- Create buttons for each gamemode
			for _, gameData in ipairs(currentTeleportData) do
				local isSelected = gameData.title == selectedGame.title

				local modeButton = Instance.new("TextButton")
				modeButton.Size = UDim2.fromOffset(buttonWidth, 26)
				modeButton.Position = UDim2.fromOffset(totalWidth, 2)
				modeButton.BackgroundColor3 = isSelected and Color3.fromRGB(70, 120, 180) or Color3.fromRGB(70, 70, 75)
				modeButton.BorderSizePixel = 0
				modeButton.Text = gameData.title
				modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
				modeButton.TextSize = currentDimensions.textSize - 2
				modeButton.TextScaled = true
				modeButton.Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
				modeButton.Parent = buttonScrollFrame

				local buttonCorner = Instance.new("UICorner")
				buttonCorner.CornerRadius = UDim.new(0, 4)
				buttonCorner.Parent = modeButton

				-- Button click handler
				modeButton.MouseButton1Click:Connect(function()
					print("[TP Client Debug] Mode button clicked:", gameData.title)
					-- Update selected game and refresh UI
					updateGuiForSelectedGame(backgroundFrame, gameData, currentDimensions)
				end)

				totalWidth = totalWidth + buttonWidth + buttonSpacing
			end

			-- Set canvas size for horizontal scrolling
			buttonScrollFrame.CanvasSize = UDim2.fromOffset(totalWidth - buttonSpacing, 30)
			currentY = currentY + 60
		else
			-- Desktop: Traditional dropdown
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
			gamemodeLabel.TextYAlignment = Enum.TextYAlignment.Center
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

			-- Dropdown functionality (existing desktop code)
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
					dropdownList.ZIndex = 100 -- Much higher ZIndex to ensure it's on top
					dropdownList.ClipsDescendants = false
					dropdownList.Parent = backgroundFrame -- Parent to main frame instead of gamemode frame to avoid clipping

					-- Adjust position relative to backgroundFrame instead of gamemodeFrame
					local gamemodeFramePos = gamemodeFrame.Position
					local gamemodeFrameSize = gamemodeFrame.Size
					dropdownList.Position = UDim2.new(
						gamemodeFramePos.X.Scale,
						gamemodeFramePos.X.Offset,
						gamemodeFramePos.Y.Scale,
						gamemodeFramePos.Y.Offset + gamemodeFrameSize.Y.Offset
					)
					dropdownList.Size = UDim2.new(
						gamemodeFrameSize.X.Scale,
						gamemodeFrameSize.X.Offset - 20,
						0,
						#currentTeleportData * 30
					)

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
						optionButton.ZIndex = 101 -- Higher than dropdown list
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
	end

	-- Play button (full width)
	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	if isMobile then
		playButton.Size = UDim2.new(1, -16, 0, currentDimensions.buttonHeight)
		playButton.Position = UDim2.fromOffset(8, currentY)
		currentY = currentY + currentDimensions.buttonHeight + 10
	else
		local playButtonY = gamemodeY + 20
		playButton.Size =
			UDim2.new(1, hasImage and -currentDimensions.sidebarWidth - 20 or -20, 0, currentDimensions.buttonHeight)
		playButton.Position = UDim2.fromOffset(currentDimensions.padding, playButtonY)
	end

	-- Check if server is down and gray out button accordingly
	local isServerDown = selectedGame.status and selectedGame.status:lower() == "down"
	if isServerDown then
		playButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray
		playButton.Text = isMobile and "🚫 Server Down" or "🚫 Server Down - Cannot Play"
		playButton.TextColor3 = Color3.fromRGB(200, 200, 200) -- Light gray text
	else
		playButton.BackgroundColor3 = isMobile and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(40, 167, 69)
		playButton.Text = isMobile and "🎮 Play" or "🎮 Play Game"
		playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	playButton.BorderSizePixel = 0
	playButton.TextSize = isMobile and currentDimensions.textSize or currentDimensions.textSize + 2
	playButton.Font = Enum.Font.GothamBold
	playButton.Parent = contentFrame

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, isMobile and 6 or 8)
	playCorner.Parent = playButton

	-- Report button (full width, under play button)
	local reportButton = Instance.new("TextButton")
	reportButton.Name = "ReportButton"
	if isMobile then
		reportButton.Size = UDim2.new(1, -16, 0, currentDimensions.buttonHeight * 0.8)
		reportButton.Position = UDim2.fromOffset(8, currentY)
		currentY = currentY + (currentDimensions.buttonHeight * 0.8) + 10
	else
		local reportButtonY = (gamemodeY + 20) + currentDimensions.buttonHeight + 10
		reportButton.Size = UDim2.new(
			1,
			hasImage and -currentDimensions.sidebarWidth - 20 or -20,
			0,
			currentDimensions.buttonHeight * 0.8
		)
		reportButton.Position = UDim2.fromOffset(currentDimensions.padding, reportButtonY)
	end

	-- Gray out report button if server is already down
	if isServerDown then
		reportButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120) -- Gray
		reportButton.Text = isMobile and "⚫ Already Reported" or "⚫ Server Already Down"
		reportButton.TextColor3 = Color3.fromRGB(200, 200, 200) -- Light gray text
	else
		reportButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
		reportButton.Text = isMobile and "⚠️ Report Server Down" or "⚠️ ReportServer Down"
		reportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	reportButton.BorderSizePixel = 0
	reportButton.TextSize = isMobile and currentDimensions.textSize - 1 or currentDimensions.textSize
	reportButton.Font = Enum.Font.GothamBold
	reportButton.Parent = contentFrame

	local reportCorner = Instance.new("UICorner")
	reportCorner.CornerRadius = UDim.new(0, isMobile and 6 or 8)
	reportCorner.Parent = reportButton

	-- Button click handlers (always use latest selectedGame)
	playButton.MouseButton1Click:Connect(function()
		-- Check if server is down before allowing teleport
		if selectedGame.status and selectedGame.status:lower() == "down" then
			spawn(function()
				showErrorMessage(
					"This server is currently down and unavailable. Please try a different gamemode or check back later."
				)
			end)
			return
		end
		teleportPlayerRemote:FireServer(selectedGame.tp_url, selectedGame.partKey, selectedGame.title)
	end)

	reportButton.MouseButton1Click:Connect(function()
		-- Check if server is already marked as down
		if selectedGame.status and selectedGame.status:lower() == "down" then
			spawn(function()
				showErrorMessage("This server is already marked as down by the admin. No need to report it again.")
			end)
			return
		end

		local currentTime = tick()

		-- Create unique cooldown key per gamemode/part combination
		local cooldownKey = selectedGame.partKey .. "_" .. selectedGame.tp_url
		local lastReportTime = reportCooldowns[cooldownKey] or 0
		local timeSinceLastReport = currentTime - lastReportTime

		if timeSinceLastReport < REPORT_COOLDOWN then
			local timeLeft = REPORT_COOLDOWN - timeSinceLastReport
			local minutesLeft = math.ceil(timeLeft / 60)
			spawn(function()
				showErrorMessage(
					"You can report "
						.. selectedGame.title
						.. " again in "
						.. minutesLeft
						.. " minutes. You can still report other gamemodes."
				)
			end)
			return
		end
		print("[TP Client Debug] (Before report) selectedGame.title:", selectedGame and selectedGame.title)
		print("[TP Client Debug] Reporting server down with values:")
		print("tp_url:", selectedGame and selectedGame.tp_url)
		print("partKey:", selectedGame and selectedGame.partKey)
		print("title:", selectedGame and selectedGame.title)
		print("[TP Client Debug] Cooldown key:", cooldownKey)
		reportServerRemote:FireServer(selectedGame.tp_url, selectedGame.partKey, selectedGame.title)

		-- Update cooldown for this specific gamemode/part combination
		reportCooldowns[cooldownKey] = currentTime

		spawn(function()
			showSuccessMessage(
				"Server report sent successfully! Admin will update this teleport link soon. Thank you for helping improve our service."
			)
		end)
	end)

	-- Update canvas size for mobile scrolling
	if isMobile then
		contentFrame.CanvasSize = UDim2.fromOffset(0, currentY)
	end

	return backgroundFrame
end

-- Function to show the teleport GUI
local function showTeleportGui(teleportData)
	print("[TP Client Debug] showTeleportGui called")
	print("[TP Client Debug] teleportData:", teleportData)

	currentTeleportData = teleportData
	-- Use first game as default selection and set global selectedGame
	selectedGame = teleportData[1]
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

-- Handle server report responses (if server sends any confirmation)
if reportServerRemote then
	reportServerRemote.OnClientEvent:Connect(function(success, message)
		if success then
			spawn(function()
				showSuccessMessage(
					message or "Server report sent successfully! Admin will update this teleport link soon."
				)
			end)
		else
			spawn(function()
				showErrorMessage(message or "Failed to send server report. Please try again later.")
			end)
		end
	end)
end

-- Function to create/show loading screen
local function createLoadingGui()
	if loadingGui then
		loadingGui:Destroy()
	end
	
	loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "LoadingGui"
	loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	loadingGui.Parent = playerGui
	
	-- Background frame
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Size = UDim2.new(1, 0, 1, 0)
	backgroundFrame.Position = UDim2.new(0, 0, 0, 0)
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backgroundFrame.BackgroundTransparency = 0.5
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.Parent = loadingGui
	
	-- Loading frame
	local loadingFrame = Instance.new("Frame")
	loadingFrame.Size = UDim2.new(0, 300, 0, 100)
	loadingFrame.Position = UDim2.new(0.5, -150, 0.5, -50)
	loadingFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	loadingFrame.BorderSizePixel = 0
	loadingFrame.Parent = backgroundFrame
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = loadingFrame
	
	-- Loading text
	local loadingText = Instance.new("TextLabel")
	loadingText.Size = UDim2.new(1, -20, 0, 30)
	loadingText.Position = UDim2.new(0, 10, 0, 10)
	loadingText.BackgroundTransparency = 1
	loadingText.Text = "Loading Fresh Data..."
	loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
	loadingText.TextScaled = true
	loadingText.Font = Enum.Font.SourceSansBold
	loadingText.Parent = loadingFrame
	
	-- Loading spinner (simple rotating element)
	local spinner = Instance.new("Frame")
	spinner.Size = UDim2.new(0, 40, 0, 40)
	spinner.Position = UDim2.new(0.5, -20, 0, 50)
	spinner.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	spinner.BorderSizePixel = 0
	spinner.Parent = loadingFrame
	
	local spinnerCorner = Instance.new("UICorner")
	spinnerCorner.CornerRadius = UDim.new(0.5, 0)
	spinnerCorner.Parent = spinner
	
	-- Animate spinner
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	local tween = TweenService:Create(spinner, tweenInfo, {Rotation = 360})
	tween:Play()
	
	return loadingGui
end

-- Function to hide loading screen
local function hideLoadingGui()
	if loadingGui then
		loadingGui:Destroy()
		loadingGui = nil
	end
end

-- Handle loading screen show/hide
showLoadingRemote.OnClientEvent:Connect(function(show)
	if show then
		createLoadingGui()
	else
		hideLoadingGui()
	end
end)

print("Teleportation client system loaded!")
print("[TP Client Debug] Client script initialization complete")
