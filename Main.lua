local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local iOSLibrary = {}
iOSLibrary.__index = iOSLibrary

local TabClass = {}
TabClass.__index = TabClass

local RowClass = {}
RowClass.__index = RowClass

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Строгий монохромный дизайн
local THEME = {
	BgColor = Color3.fromRGB(0, 0, 0),
	ContainerColor = Color3.fromRGB(28, 28, 30),
	SidebarColor = Color3.fromRGB(16, 16, 18),
	AccentColor = Color3.fromRGB(255, 255, 255),
	ToggleOnColor = Color3.fromRGB(48, 209, 88),
	TextColor = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(142, 142, 147),
	DividerColor = Color3.fromRGB(44, 44, 46),
	Font = Enum.Font.Gotham,
}

-- Быстрые тайминги как в iOS
local T_FAST = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_RELEASE = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function createTween(obj, info, properties)
	local tween = TweenService:Create(obj, info, properties)
	tween:Play()
	return tween
end

local function isTouchOrMouse(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Надёжное отслеживание конца касания (работает даже если палец ушёл с элемента)
local function watchInputEnd(input, callback)
	local conn
	conn = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End
			or input.UserInputState == Enum.UserInputState.Cancel then
			conn:Disconnect()
			callback()
		end
	end)
end

-- iOS-эффект нажатия: элемент слегка увеличивается на пару пикселей
local function attachPressEffect(btn, scaleAmount)
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = btn

	btn.InputBegan:Connect(function(input)
		if isTouchOrMouse(input) then
			createTween(uiScale, T_PRESS, { Scale = scaleAmount or 1.04 })
			watchInputEnd(input, function()
				createTween(uiScale, T_RELEASE, { Scale = 1 })
			end)
		end
	end)
	return uiScale
end

local function preventClickThrough(instance)
	instance.Active = true
end

local function makeSwitch(parent, size, posX, state)
	local switchBg = Instance.new("Frame")
	switchBg.Size = size
	switchBg.Position = UDim2.new(1, posX, 0.5, -size.Y.Offset / 2)
	switchBg.BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor
	switchBg.Parent = parent

	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = switchBg

	local thumbSize = size.Y.Offset - 4
	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, thumbSize, 0, thumbSize)
	thumb.Position = state and UDim2.new(1, -thumbSize - 2, 0.5, -thumbSize / 2) or UDim2.new(0, 2, 0.5, -thumbSize / 2)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.Parent = switchBg

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb

	return switchBg, thumb, thumbSize
end

----------------------------------------------------
-- ОКНО
----------------------------------------------------
function iOSLibrary.CreateWindow(title, size)
	local self = setmetatable({}, iOSLibrary)

	-- Адаптация размера под экран (мобилка)
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
	local desired = size or Vector2.new(470, 330)
	local windowSize = Vector2.new(
		math.min(desired.X, viewport.X - 24),
		math.min(desired.Y, viewport.Y - 60)
	)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "iOS_Library_Menu"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = false

	local success = pcall(function() screenGui.Parent = CoreGui end)
	if not success then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.ScreenGui = screenGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
	mainFrame.Position = UDim2.new(0.5, -windowSize.X / 2, 0.5, -windowSize.Y / 2)
	mainFrame.BackgroundColor3 = THEME.BgColor
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui
	preventClickThrough(mainFrame)

	local windowScale = Instance.new("UIScale")
	windowScale.Scale = 1
	windowScale.Parent = mainFrame
	self.WindowScale = windowScale

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 14)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = THEME.DividerColor
	mainStroke.Thickness = 1
	mainStroke.Parent = mainFrame

	local headerH = IS_MOBILE and 46 or 42
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, headerH)
	header.BackgroundColor3 = THEME.ContainerColor
	header.BorderSizePixel = 0
	header.Parent = mainFrame
	preventClickThrough(header)

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 14)
	headerCorner.Parent = header

	local headerBottomMask = Instance.new("Frame")
	headerBottomMask.Size = UDim2.new(1, 0, 0, 14)
	headerBottomMask.Position = UDim2.new(0, 0, 1, -14)
	headerBottomMask.BackgroundColor3 = THEME.ContainerColor
	headerBottomMask.BorderSizePixel = 0
	headerBottomMask.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -70, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = THEME.TextColor
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header

	-- Кнопка закрытия (вместо "тап по шапке закрывает" — надёжнее на мобилке)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, headerH - 14, 0, headerH - 14)
	closeBtn.Position = UDim2.new(1, -(headerH - 7), 0.5, -(headerH - 14) / 2)
	closeBtn.BackgroundColor3 = THEME.DividerColor
	closeBtn.Text = "✕"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 13
	closeBtn.TextColor3 = THEME.TextColor
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn
	attachPressEffect(closeBtn, 1.08)

	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.new(0, 0, 1, 0)
	headerLine.BackgroundColor3 = THEME.DividerColor
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	local sidebarW = IS_MOBILE and math.max(96, math.floor(windowSize.X * 0.26)) or 120
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Size = UDim2.new(0, sidebarW, 1, -(headerH + 1))
	sidebar.Position = UDim2.new(0, 0, 0, headerH + 1)
	sidebar.BackgroundColor3 = THEME.SidebarColor
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 0
	sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
	sidebar.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.Parent = mainFrame
	preventClickThrough(sidebar)

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Padding = UDim.new(0, 4)
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sidebarLayout.Parent = sidebar

	local sidebarPadding = Instance.new("UIPadding")
	sidebarPadding.PaddingTop = UDim.new(0, 8)
	sidebarPadding.PaddingBottom = UDim.new(0, 8)
	sidebarPadding.Parent = sidebar

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -(sidebarW + 12), 1, -(headerH + 13))
	contentFrame.Position = UDim2.new(0, sidebarW + 6, 0, headerH + 7)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ClipsDescendants = true
	contentFrame.Parent = mainFrame

	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.SidebarWidth = sidebarW
	self.ContentFrame = contentFrame
	self.Tabs = {}
	self.CurrentTab = nil
	self.IsOpen = false

	----------------------------------------------------
	-- Открытие / закрытие с анимацией
	----------------------------------------------------
	function self:SetOpen(open)
		if open == self.IsOpen then return end
		self.IsOpen = open
		if open then
			mainFrame.Visible = true
			windowScale.Scale = 0.92
			createTween(windowScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		else
			createTween(windowScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.92 }).Completed:Connect(function()
				if not self.IsOpen then mainFrame.Visible = false end
			end)
		end
	end

	closeBtn.Activated:Connect(function()
		self:SetOpen(false)
	end)

	----------------------------------------------------
	-- Драг шапки с ограничением в пределах экрана
	----------------------------------------------------
	local dragInput = nil
	header.InputBegan:Connect(function(input)
		if not isTouchOrMouse(input) then return end
		if dragInput then return end
		dragInput = input
		local dragStart = input.Position
		local startPos = mainFrame.Position

		local moveConn
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed ~= input and not (input.UserInputType == Enum.UserInputType.MouseButton1 and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				return
			end
			local delta = changed.Position - dragStart
			local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
			local newX = math.clamp(startPos.X.Scale * vp.X + startPos.X.Offset + delta.X, -windowSize.X + 60, vp.X - 60)
			local newY = math.clamp(startPos.Y.Scale * vp.Y + startPos.Y.Offset + delta.Y, 0, vp.Y - headerH)
			mainFrame.Position = UDim2.new(0, newX, 0, newY)
		end)

		watchInputEnd(input, function()
			moveConn:Disconnect()
			dragInput = nil
		end)
	end)

	----------------------------------------------------
	-- Плавающая кнопка (пузырь) для открытия меню — перетаскиваемая
	----------------------------------------------------
	local bubbleSize = IS_MOBILE and 52 or 44
	local bubble = Instance.new("TextButton")
	bubble.Size = UDim2.new(0, bubbleSize, 0, bubbleSize)
	bubble.Position = UDim2.new(0, 12, 0.5, -bubbleSize / 2)
	bubble.BackgroundColor3 = THEME.ContainerColor
	bubble.Text = "☰"
	bubble.Font = Enum.Font.GothamBold
	bubble.TextSize = 20
	bubble.TextColor3 = THEME.TextColor
	bubble.AutoButtonColor = false
	bubble.Parent = screenGui

	local bubbleCorner = Instance.new("UICorner")
	bubbleCorner.CornerRadius = UDim.new(1, 0)
	bubbleCorner.Parent = bubble

	local bubbleStroke = Instance.new("UIStroke")
	bubbleStroke.Color = THEME.DividerColor
	bubbleStroke.Thickness = 1
	bubbleStroke.Parent = bubble

	attachPressEffect(bubble, 1.1)

	-- Тап = открыть/закрыть; перетаскивание = двигать пузырь
	bubble.InputBegan:Connect(function(input)
		if not isTouchOrMouse(input) then return end
		local startInputPos = input.Position
		local startBubblePos = bubble.Position
		local moved = false

		local moveConn
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed ~= input and not (input.UserInputType == Enum.UserInputType.MouseButton1 and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				return
			end
			local delta = changed.Position - startInputPos
			if delta.Magnitude > 8 then moved = true end
			if moved then
				local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
				local newX = math.clamp(startBubblePos.X.Scale * vp.X + startBubblePos.X.Offset + delta.X, 4, vp.X - bubbleSize - 4)
				local newY = math.clamp(startBubblePos.Y.Scale * vp.Y + startBubblePos.Y.Offset + delta.Y, 4, vp.Y - bubbleSize - 4)
				bubble.Position = UDim2.new(0, newX, 0, newY)
			end
		end)

		watchInputEnd(input, function()
			moveConn:Disconnect()
			if not moved then
				self:SetOpen(not self.IsOpen)
			end
		end)
	end)

	----------------------------------------------------
	-- Уведомления
	----------------------------------------------------
	local notifyHolder = Instance.new("Frame")
	notifyHolder.Size = UDim2.new(0, 240, 1, -20)
	notifyHolder.Position = UDim2.new(1, -250, 0, 10)
	notifyHolder.BackgroundTransparency = 1
	notifyHolder.Parent = screenGui

	local notifyLayout = Instance.new("UIListLayout")
	notifyLayout.Padding = UDim.new(0, 6)
	notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	notifyLayout.Parent = notifyHolder

	function self:Notify(text, duration)
		duration = duration or 2.5
		local note = Instance.new("Frame")
		note.Size = UDim2.new(1, 0, 0, 40)
		note.BackgroundColor3 = THEME.ContainerColor
		note.BackgroundTransparency = 1
		note.Parent = notifyHolder

		local noteCorner = Instance.new("UICorner")
		noteCorner.CornerRadius = UDim.new(0, 10)
		noteCorner.Parent = note

		local noteStroke = Instance.new("UIStroke")
		noteStroke.Color = THEME.DividerColor
		noteStroke.Transparency = 1
		noteStroke.Parent = note

		local noteLabel = Instance.new("TextLabel")
		noteLabel.Size = UDim2.new(1, -24, 1, 0)
		noteLabel.Position = UDim2.new(0, 12, 0, 0)
		noteLabel.Text = text
		noteLabel.Font = THEME.Font
		noteLabel.TextSize = 13
		noteLabel.TextColor3 = THEME.TextColor
		noteLabel.TextTransparency = 1
		noteLabel.TextXAlignment = Enum.TextXAlignment.Left
		noteLabel.TextTruncate = Enum.TextTruncate.AtEnd
		noteLabel.BackgroundTransparency = 1
		noteLabel.Parent = note

		createTween(note, T_FAST, { BackgroundTransparency = 0 })
		createTween(noteStroke, T_FAST, { Transparency = 0 })
		createTween(noteLabel, T_FAST, { TextTransparency = 0 })

		task.delay(duration, function()
			createTween(note, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
			createTween(noteStroke, TweenInfo.new(0.2), { Transparency = 1 })
			createTween(noteLabel, TweenInfo.new(0.2), { TextTransparency = 1 }).Completed:Connect(function()
				note:Destroy()
			end)
		end)
	end

	-- Двойной тап по центру экрана открывает меню (запасной способ)
	local lastTapTime = 0
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or self.IsOpen then return end
		if isTouchOrMouse(input) then
			local cam = Workspace.CurrentCamera
			if not cam then return end
			local screenCenter = cam.ViewportSize / 2
			local inputPos = Vector2.new(input.Position.X, input.Position.Y)
			if (inputPos - screenCenter).Magnitude <= 160 then
				local currentTime = os.clock()
				if currentTime - lastTapTime <= 0.35 then
					self:SetOpen(true)
				end
				lastTapTime = currentTime
			end
		end
	end)

	return self
end

----------------------------------------------------
-- ВКЛАДКИ (iOS-стиль: пилюля, быстрые переходы, без индикатора)
----------------------------------------------------
function iOSLibrary:SelectTab(name)
	local targetTab = self.Tabs[name]
	if not targetTab or self.CurrentTab == targetTab then return end

	local oldTab = self.CurrentTab
	self.CurrentTab = targetTab

	if oldTab then
		createTween(oldTab.Button, T_FAST, { BackgroundTransparency = 1 })
		createTween(oldTab.Button.TextLabel, T_FAST, { TextColor3 = THEME.SecondaryText })
		oldTab.Button.TextLabel.Font = Enum.Font.Gotham

		createTween(oldTab.CanvasGroup, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
			Position = UDim2.new(0, -6, 0, 0)
		}).Completed:Connect(function()
			if self.CurrentTab ~= oldTab then oldTab.CanvasGroup.Visible = false end
		end)
	end

	-- Активная вкладка: заполненная пилюля (как iOS segmented control)
	createTween(targetTab.Button, T_FAST, { BackgroundTransparency = 0 })
	createTween(targetTab.Button.TextLabel, T_FAST, { TextColor3 = THEME.TextColor })
	targetTab.Button.TextLabel.Font = Enum.Font.GothamBold

	targetTab.CanvasGroup.Position = UDim2.new(0, 6, 0, 0)
	targetTab.CanvasGroup.Visible = true
	createTween(targetTab.CanvasGroup, T_FAST, {
		GroupTransparency = 0,
		Position = UDim2.new(0, 0, 0, 0)
	})
end

function iOSLibrary:CreateTab(name)
	local tab = setmetatable({}, TabClass)
	tab.Name = name

	local btnH = IS_MOBILE and 40 or 34
	local btnFrame = Instance.new("TextButton")
	btnFrame.Size = UDim2.new(1, -8, 0, btnH)
	btnFrame.BackgroundColor3 = THEME.ContainerColor
	btnFrame.BackgroundTransparency = 1
	btnFrame.Text = ""
	btnFrame.AutoButtonColor = false
	btnFrame.Parent = self.Sidebar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = btnFrame

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Name = "TextLabel"
	btnLabel.Size = UDim2.new(1, 0, 1, 0)
	btnLabel.Text = name
	btnLabel.Font = THEME.Font
	btnLabel.TextSize = 13
	btnLabel.TextColor3 = THEME.SecondaryText
	btnLabel.TextXAlignment = Enum.TextXAlignment.Center
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = btnFrame

	-- Эффект нажатия: увеличение на пару пикселей и пружина обратно
	attachPressEffect(btnFrame, 1.05)

	local canvasGroup = Instance.new("CanvasGroup")
	canvasGroup.Size = UDim2.new(1, 0, 1, 0)
	canvasGroup.BackgroundTransparency = 1
	canvasGroup.GroupTransparency = 1
	canvasGroup.Visible = false
	canvasGroup.Parent = self.ContentFrame

	local container = Instance.new("ScrollingFrame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 0
	container.ScrollingDirection = Enum.ScrollingDirection.Y
	container.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable -- iOS-скролл
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.Parent = canvasGroup

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)

	tab.Button = btnFrame
	tab.CanvasGroup = canvasGroup
	tab.Container = container

	btnFrame.Activated:Connect(function()
		self:SelectTab(name)
	end)

	self.Tabs[name] = tab

	if not self.CurrentTab then
		task.defer(function() self:SelectTab(name) end)
	end

	return tab
end

----------------------------------------------------
-- СТРОКИ (МУЛЬТИ-КОЛОНКИ)
----------------------------------------------------
function TabClass:CreateRow()
	local row = setmetatable({}, RowClass)

	local rowFrame = Instance.new("Frame")
	rowFrame.Size = UDim2.new(1, 0, 0, IS_MOBILE and 42 or 36)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = self.Container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = rowFrame

	row.Container = rowFrame
	row.ParentContainer = self.Container
	return row
end

local function buildToggleHalf(parent, label, default, callback)
	local state = default
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(0.5, -3, 1, 0)
	item.BackgroundColor3 = THEME.ContainerColor
	item.Text = ""
	item.AutoButtonColor = false
	item.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = item

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -45, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 13
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = item

	local switchBg, thumb = makeSwitch(item, UDim2.new(0, 34, 0, 20), -42, state)
	attachPressEffect(item, 1.02)

	item.Activated:Connect(function()
		state = not state
		createTween(switchBg, T_FAST, { BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor })
		createTween(thumb, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		})
		task.spawn(callback, state)
	end)
end

function RowClass:Toggle(label, default, callback)
	buildToggleHalf(self.Container, label, default, callback)
end

function RowClass:Button(text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.5, -3, 1, 0)
	btn.BackgroundColor3 = THEME.DividerColor
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	label.Font = THEME.Font
	label.TextSize = 13
	label.TextColor3 = THEME.TextColor
	label.BackgroundTransparency = 1
	label.Parent = btn

	attachPressEffect(btn, 1.03)

	btn.Activated:Connect(function()
		createTween(btn, T_PRESS, { BackgroundColor3 = THEME.ContainerColor })
		task.spawn(callback)
		task.delay(0.1, function()
			createTween(btn, T_FAST, { BackgroundColor3 = THEME.DividerColor })
		end)
	end)
end

----------------------------------------------------
-- СТАНДАРТНЫЕ ЭЛЕМЕНТЫ ВКЛАДКИ
----------------------------------------------------
function TabClass:Section(text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Text = string.upper(text)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = THEME.SecondaryText
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundTransparency = 1
	label.Parent = self.Container

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = label
end

function TabClass:Label(text)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, 0, 0, 32)
	item.BackgroundColor3 = THEME.ContainerColor
	item.BackgroundTransparency = 0.5
	item.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = item

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.Text = text
	label.Font = THEME.Font
	label.TextSize = 12
	label.TextColor3 = THEME.SecondaryText
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.BackgroundTransparency = 1
	label.Parent = item
end

function TabClass:Toggle(label, default, callback)
	local state = default
	local itemH = IS_MOBILE and 46 or 40
	local itemFrame = Instance.new("TextButton")
	itemFrame.Size = UDim2.new(1, 0, 0, itemH)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Text = ""
	itemFrame.AutoButtonColor = false
	itemFrame.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -65, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local switchBg, thumb = makeSwitch(itemFrame, UDim2.new(0, 38, 0, 22), -50, state)
	attachPressEffect(itemFrame, 1.02)

	itemFrame.Activated:Connect(function()
		state = not state
		createTween(switchBg, T_FAST, { BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor })
		createTween(thumb, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
		})
		task.spawn(callback, state)
	end)
end

function TabClass:DualToggle(label1, default1, callback1, label2, default2, callback2)
	local rowFrame = Instance.new("Frame")
	rowFrame.Size = UDim2.new(1, 0, 0, IS_MOBILE and 46 or 40)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = self.Container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = rowFrame

	buildToggleHalf(rowFrame, label1, default1, callback1)
	buildToggleHalf(rowFrame, label2, default2, callback2)
end

function TabClass:Button(text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, IS_MOBILE and 44 or 38)
	btn.BackgroundColor3 = THEME.DividerColor
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	label.Font = THEME.Font
	label.TextSize = 14
	label.TextColor3 = THEME.TextColor
	label.BackgroundTransparency = 1
	label.Parent = btn

	attachPressEffect(btn, 1.03)

	btn.Activated:Connect(function()
		task.spawn(callback)
	end)
end

----------------------------------------------------
-- СЛАЙДЕР с умным тачем:
-- горизонтальный свайп = слайдер, вертикальный = скролл
----------------------------------------------------
function TabClass:Slider(label, min, max, default, callback)
	local currentVal = math.clamp(default, min, max)
	local itemH = IS_MOBILE and 58 or 52
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, itemH)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Active = true
	itemFrame.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.7, 0, 0, 22)
	textLabel.Position = UDim2.new(0, 12, 0, 5)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 13
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.25, 0, 0, 22)
	valueLabel.Position = UDim2.new(0.75, -12, 0, 5)
	valueLabel.Text = string.format("%.1f", currentVal)
	valueLabel.Font = THEME.Font
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = THEME.SecondaryText
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = itemFrame

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, -24, 0, IS_MOBILE and 6 or 4)
	sliderTrack.Position = UDim2.new(0, 12, 0, itemH - 18)
	sliderTrack.BackgroundColor3 = THEME.DividerColor
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Parent = itemFrame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = sliderTrack

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new((currentVal - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = THEME.AccentColor
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderTrack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = sliderFill

	local knobSize = IS_MOBILE and 20 or 14
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, knobSize, 0, knobSize)
	knob.Position = UDim2.new((currentVal - min) / (max - min), -knobSize / 2, 0.5, -knobSize / 2)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = sliderTrack

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local knobScale = Instance.new("UIScale")
	knobScale.Scale = 1
	knobScale.Parent = knob

	local container = self.Container

	local function updateSlider(posX)
		local absPos = sliderTrack.AbsolutePosition
		local absSize = sliderTrack.AbsoluteSize
		local percentage = math.clamp((posX - absPos.X) / absSize.X, 0, 1)
		currentVal = min + (percentage * (max - min))
		valueLabel.Text = string.format("%.1f", currentVal)
		sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
		knob.Position = UDim2.new(percentage, -knobSize / 2, 0.5, -knobSize / 2)
		task.spawn(callback, currentVal)
	end

	itemFrame.InputBegan:Connect(function(input)
		if not isTouchOrMouse(input) then return end

		local startPos = input.Position
		local capturing = false
		local dead = false

		-- Если тап прямо по зоне трека — начинаем сразу
		local trackY = sliderTrack.AbsolutePosition.Y + sliderTrack.AbsoluteSize.Y / 2
		if math.abs(input.Position.Y - trackY) <= (IS_MOBILE and 22 or 14) then
			capturing = true
			container.ScrollingEnabled = false
			createTween(knobScale, T_PRESS, { Scale = 1.25 })
			updateSlider(input.Position.X)
		end

		local moveConn
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed ~= input and not (input.UserInputType == Enum.UserInputType.MouseButton1 and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				return
			end
			if capturing then
				updateSlider(changed.Position.X)
			elseif not dead then
				local delta = changed.Position - startPos
				-- Определяем намерение: горизонталь = слайдер, вертикаль = скролл
				if math.abs(delta.X) > 8 and math.abs(delta.X) > math.abs(delta.Y) then
					capturing = true
					container.ScrollingEnabled = false
					createTween(knobScale, T_PRESS, { Scale = 1.25 })
					updateSlider(changed.Position.X)
				elseif math.abs(delta.Y) > 10 then
					dead = true -- пользователь скроллит, не мешаем
				end
			end
		end)

		watchInputEnd(input, function()
			moveConn:Disconnect()
			if capturing then
				container.ScrollingEnabled = true
				createTween(knobScale, T_RELEASE, { Scale = 1 })
			end
		end)
	end)
end

----------------------------------------------------
-- DROPDOWN (новое)
----------------------------------------------------
function TabClass:Dropdown(label, options, default, callback)
	local currentOption = default or options[1]
	local expanded = false
	local baseH = IS_MOBILE and 44 or 40
	local optH = IS_MOBILE and 38 or 32

	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, baseH)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.ClipsDescendants = true
	itemFrame.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local headerBtn = Instance.new("TextButton")
	headerBtn.Size = UDim2.new(1, 0, 0, baseH)
	headerBtn.BackgroundTransparency = 1
	headerBtn.Text = ""
	headerBtn.AutoButtonColor = false
	headerBtn.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.5, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = headerBtn

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.5, -34, 1, 0)
	valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
	valueLabel.Text = currentOption
	valueLabel.Font = THEME.Font
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = THEME.SecondaryText
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = headerBtn

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(0, 20, 1, 0)
	arrow.Position = UDim2.new(1, -28, 0, 0)
	arrow.Text = "›"
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 16
	arrow.TextColor3 = THEME.SecondaryText
	arrow.Rotation = 90
	arrow.BackgroundTransparency = 1
	arrow.Parent = headerBtn

	local optionsHolder = Instance.new("Frame")
	optionsHolder.Size = UDim2.new(1, -16, 0, #options * (optH + 4))
	optionsHolder.Position = UDim2.new(0, 8, 0, baseH)
	optionsHolder.BackgroundTransparency = 1
	optionsHolder.Parent = itemFrame

	local optLayout = Instance.new("UIListLayout")
	optLayout.Padding = UDim.new(0, 4)
	optLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optLayout.Parent = optionsHolder

	local function setExpanded(open)
		expanded = open
		local targetH = open and (baseH + #options * (optH + 4) + 8) or baseH
		createTween(itemFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, targetH)
		})
		createTween(arrow, T_FAST, { Rotation = open and 270 or 90 })
	end

	for _, option in ipairs(options) do
		local optBtn = Instance.new("TextButton")
		optBtn.Size = UDim2.new(1, 0, 0, optH)
		optBtn.BackgroundColor3 = THEME.DividerColor
		optBtn.Text = option
		optBtn.Font = THEME.Font
		optBtn.TextSize = 13
		optBtn.TextColor3 = option == currentOption and THEME.TextColor or THEME.SecondaryText
		optBtn.AutoButtonColor = false
		optBtn.Parent = optionsHolder

		local optCorner = Instance.new("UICorner")
		optCorner.CornerRadius = UDim.new(0, 6)
		optCorner.Parent = optBtn

		attachPressEffect(optBtn, 1.02)

		optBtn.Activated:Connect(function()
			currentOption = option
			valueLabel.Text = option
			for _, child in ipairs(optionsHolder:GetChildren()) do
				if child:IsA("TextButton") then
					child.TextColor3 = child.Text == option and THEME.TextColor or THEME.SecondaryText
				end
			end
			setExpanded(false)
			task.spawn(callback, option)
		end)
	end

	attachPressEffect(headerBtn, 1.01)
	headerBtn.Activated:Connect(function()
		setExpanded(not expanded)
	end)
end

----------------------------------------------------
-- INPUT / VARIABLE BTN
----------------------------------------------------
function TabClass:Input(label, inputType, default, callback)
	local itemH = IS_MOBILE and 46 or 40
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, itemH)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.5, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local boxH = IS_MOBILE and 32 or 26
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.45, 0, 0, boxH)
	inputBox.Position = UDim2.new(0.55, -12, 0.5, -boxH / 2)
	inputBox.BackgroundColor3 = THEME.BgColor
	inputBox.Text = default
	inputBox.Font = THEME.Font
	inputBox.TextSize = 13
	inputBox.TextColor3 = THEME.TextColor
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = itemFrame

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = inputBox

	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = THEME.DividerColor
	boxStroke.Thickness = 1
	boxStroke.Parent = inputBox

	inputBox.Focused:Connect(function()
		createTween(boxStroke, T_FAST, { Color = THEME.AccentColor })
	end)

	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = inputBox.Text
		if inputType == "Number" then
			local filtered = text:gsub("[^%d%.%-]", "")
			if filtered ~= text then inputBox.Text = filtered end
		elseif inputType == "Text" then
			local filtered = text:gsub("[%d]", "")
			if filtered ~= text then inputBox.Text = filtered end
		end
	end)

	inputBox.FocusLost:Connect(function()
		createTween(boxStroke, T_FAST, { Color = THEME.DividerColor })
		task.spawn(callback, inputBox.Text)
	end)
end

function TabClass:VariableBtn(label, defaultText, btnText, callback)
	local itemH = IS_MOBILE and 46 or 40
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, itemH)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.35, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local boxH = IS_MOBILE and 32 or 26
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.32, -6, 0, boxH)
	inputBox.Position = UDim2.new(0.37, 0, 0.5, -boxH / 2)
	inputBox.BackgroundColor3 = THEME.BgColor
	inputBox.Text = defaultText
	inputBox.Font = THEME.Font
	inputBox.TextSize = 13
	inputBox.TextColor3 = THEME.TextColor
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = itemFrame

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = inputBox

	local actionBtn = Instance.new("TextButton")
	actionBtn.Size = UDim2.new(0.26, -12, 0, boxH)
	actionBtn.Position = UDim2.new(0.74, 0, 0.5, -boxH / 2)
	actionBtn.BackgroundColor3 = THEME.AccentColor
	actionBtn.Text = ""
	actionBtn.AutoButtonColor = false
	actionBtn.Parent = itemFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = actionBtn

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(1, 0, 1, 0)
	btnLabel.Text = btnText
	btnLabel.Font = THEME.Font
	btnLabel.TextSize = 12
	btnLabel.TextColor3 = THEME.BgColor
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = actionBtn

	attachPressEffect(actionBtn, 1.05)

	actionBtn.Activated:Connect(function()
		task.spawn(callback, inputBox.Text)
	end)
end

return iOSLibrary
