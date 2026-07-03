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

-- Строгий монохромный дизайн (без синего)
local THEME = {
	BgColor = Color3.fromRGB(0, 0, 0),
	ContainerColor = Color3.fromRGB(28, 28, 30),
	SidebarColor = Color3.fromRGB(16, 16, 18),
	AccentColor = Color3.fromRGB(255, 255, 255),    -- Белый акцент вместо синего
	ToggleOnColor = Color3.fromRGB(48, 209, 88),   -- iOS Зеленый (оставляем для тогглов)
	TextColor = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(142, 142, 147),
	DividerColor = Color3.fromRGB(44, 44, 46),
	Font = Enum.Font.Gotham,
}

local function createTween(obj, info, properties)
	local tween = TweenService:Create(obj, info, properties)
	tween:Play()
	return tween
end

-- Используем ТОЛЬКО для главных панелей, чтобы не ломать скролл на мобилках
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
	local windowSize = size or Vector2.new(470, 330)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "iOS_Library_Menu"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

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
	mainFrame.Parent = screenGui
	preventClickThrough(mainFrame)

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = THEME.DividerColor
	mainStroke.Thickness = 1
	mainStroke.Parent = mainFrame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 42)
	header.BackgroundColor3 = THEME.ContainerColor
	header.BorderSizePixel = 0
	header.Parent = mainFrame
	preventClickThrough(header)

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header

	local headerBottomMask = Instance.new("Frame")
	headerBottomMask.Size = UDim2.new(1, 0, 0, 12)
	headerBottomMask.Position = UDim2.new(0, 0, 1, -12)
	headerBottomMask.BackgroundColor3 = THEME.ContainerColor
	headerBottomMask.BorderSizePixel = 0
	headerBottomMask.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -24, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = THEME.TextColor
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header

	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.new(0, 0, 1, 0)
	headerLine.BackgroundColor3 = THEME.DividerColor
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 120, 1, -43)
	sidebar.Position = UDim2.new(0, 0, 0, 43)
	sidebar.BackgroundColor3 = THEME.SidebarColor
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainFrame
	preventClickThrough(sidebar)

	local sidebarMask = Instance.new("Frame")
	sidebarMask.Size = UDim2.new(0, 12, 0, 12)
	sidebarMask.Position = UDim2.new(0, 0, 1, -12)
	sidebarMask.BackgroundColor3 = THEME.SidebarColor
	sidebarMask.BorderSizePixel = 0
	sidebarMask.Parent = sidebar

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Padding = UDim.new(0, 4)
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	sidebarLayout.Parent = sidebar

	local sidebarPadding = Instance.new("UIPadding")
	sidebarPadding.PaddingTop = UDim.new(0, 8)
	sidebarPadding.Parent = sidebar

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -132, 1, -55)
	contentFrame.Position = UDim2.new(0, 126, 0, 49)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentFrame = contentFrame
	self.Tabs = {}
	self.CurrentTab = nil

	-- Умный обработчик шапки: Тап закрывает, Драг перетаскивает
	local dragging, dragStart, startPos, tapTime, tapPos
	
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
			tapTime = os.clock()
			tapPos = input.Position
		end
	end)

	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			local dist = (input.Position - tapPos).Magnitude
			-- Если время удержания меньше 0.25с и палец не сдвинулся больше чем на 10 пикселей - это быстрый тап
			if (os.clock() - tapTime) < 0.25 and dist < 10 then
				mainFrame.Visible = false
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- Триггер появления меню
	local lastTapTime = 0
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if mainFrame.Visible then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local camera = Workspace.CurrentCamera
			if not camera then return end
			
			local screenCenter = camera.ViewportSize / 2
			local inputPos = Vector2.new(input.Position.X, input.Position.Y)
			
			if (inputPos - screenCenter).Magnitude <= 160 then
				local currentTime = os.clock()
				if currentTime - lastTapTime <= 0.35 then
					mainFrame.Visible = true
				end
				lastTapTime = currentTime
			end
		end
	end)

	return self
end

function iOSLibrary:SelectTab(name)
	local targetTab = self.Tabs[name]
	if not targetTab or self.CurrentTab == targetTab then return end

	local oldTab = self.CurrentTab
	self.CurrentTab = targetTab

	if oldTab then
		createTween(oldTab.Button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 112, 0, 34),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0), 
			BackgroundTransparency = 1
		})
		createTween(oldTab.Button:FindFirstChild("TextLabel"), TweenInfo.new(0.15), {TextColor3 = THEME.SecondaryText, Font = Enum.Font.Gotham})
		
		createTween(oldTab.CanvasGroup, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
			Position = UDim2.new(0, 0, 0, -8)
		}).Completed:Connect(function()
			if self.CurrentTab ~= oldTab then oldTab.CanvasGroup.Visible = false end
		end)
	end

	createTween(targetTab.Button, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 116, 0, 36),
		BackgroundColor3 = THEME.ContainerColor,
		BackgroundTransparency = 0
	})
	createTween(targetTab.Button:FindFirstChild("TextLabel"), TweenInfo.new(0.15), {TextColor3 = THEME.TextColor, Font = Enum.Font.GothamBold})

	targetTab.CanvasGroup.Position = UDim2.new(0, 0, 0, 8)
	targetTab.CanvasGroup.Visible = true
	createTween(targetTab.CanvasGroup, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
		Position = UDim2.new(0, 0, 0, 0)
	})
end

function iOSLibrary:CreateTab(name)
	local tab = setmetatable({}, TabClass)
	tab.Name = name

	-- Используем TextButton для идеальной отработки тапов
	local btnFrame = Instance.new("TextButton")
	btnFrame.Size = UDim2.new(0, 112, 0, 34)
	btnFrame.BackgroundTransparency = 1
	btnFrame.BackgroundColor3 = THEME.ContainerColor
	btnFrame.Text = ""
	btnFrame.AutoButtonColor = false
	btnFrame.Parent = self.Sidebar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btnFrame

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Name = "TextLabel"
	btnLabel.Size = UDim2.new(1, 0, 1, 0)
	btnLabel.Position = UDim2.new(0, 0, 0, 0)
	btnLabel.Text = name
	btnLabel.Font = THEME.Font
	btnLabel.TextSize = 13
	btnLabel.TextColor3 = THEME.SecondaryText
	btnLabel.TextXAlignment = Enum.TextXAlignment.Center
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = btnFrame

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
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.Parent = canvasGroup

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
	end)

	tab.Button = btnFrame
	tab.CanvasGroup = canvasGroup
	tab.Container = container

	-- Нативная обработка кликов (работает 100% на мобилках)
	btnFrame.Activated:Connect(function()
		self:SelectTab(name)
	end)

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
	rowFrame.Size = UDim2.new(1, 0, 0, 36)
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

function RowClass:Toggle(label, default, callback)
	local state = default
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(0.5, -3, 1, 0)
	item.BackgroundColor3 = THEME.ContainerColor
	item.Text = ""
	item.AutoButtonColor = false
	item.Parent = self.Container

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

	item.Activated:Connect(function()
		state = not state
		createTween(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor})
		createTween(thumb, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)})
		task.spawn(callback, state)
	end)
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

	btn.Activated:Connect(function()
		createTween(btn, TweenInfo.new(0.1), {BackgroundColor3 = THEME.ContainerColor})
		task.spawn(callback)
		task.wait(0.1)
		createTween(btn, TweenInfo.new(0.1), {BackgroundColor3 = THEME.DividerColor})
	end)
end

----------------------------------------------------
-- СТАНДАРТНЫЕ ЭЛЕМЕНТЫ ВКЛАДКИ
----------------------------------------------------
function TabClass:Toggle(label, default, callback)
	local state = default
	local itemFrame = Instance.new("TextButton")
	itemFrame.Size = UDim2.new(1, 0, 0, 40)
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
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local switchBg, thumb = makeSwitch(itemFrame, UDim2.new(0, 38, 0, 22), -50, state)

	itemFrame.Activated:Connect(function()
		state = not state
		createTween(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor})
		createTween(thumb, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)})
		task.spawn(callback, state)
	end)
end

function TabClass:DualToggle(label1, default1, callback1, label2, default2, callback2)
	local rowFrame = Instance.new("Frame")
	rowFrame.Size = UDim2.new(1, 0, 0, 40)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = self.Container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = rowFrame

	local function buildHalf(label, default, callback)
		local state = default
		local half = Instance.new("TextButton")
		half.Size = UDim2.new(0.5, -3, 1, 0)
		half.BackgroundColor3 = THEME.ContainerColor
		half.Text = ""
		half.AutoButtonColor = false
		half.Parent = rowFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = half

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
		textLabel.Parent = half

		local switchBg, thumb = makeSwitch(half, UDim2.new(0, 34, 0, 20), -42, state)

		half.Activated:Connect(function()
			state = not state
			createTween(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor})
			createTween(thumb, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)})
			task.spawn(callback, state)
		end)
	end

	buildHalf(label1, default1, callback1)
	buildHalf(label2, default2, callback2)
end

function TabClass:Slider(label, min, max, default, callback)
	local currentVal = math.clamp(default, min, max)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 52)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
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
	sliderTrack.Size = UDim2.new(1, -24, 0, 4)
	sliderTrack.Position = UDim2.new(0, 12, 0, 36)
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

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new((currentVal - min) / (max - min), -7, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = sliderTrack

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local isDragging = false
	local activeInput = nil

	local function updateSlider(input)
		local absPos = sliderTrack.AbsolutePosition
		local absSize = sliderTrack.AbsoluteSize
		local percentage = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
		currentVal = min + (percentage * (max - min))
		valueLabel.Text = string.format("%.1f", currentVal)
		sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
		knob.Position = UDim2.new(percentage, -7, 0.5, -7)
		task.spawn(callback, currentVal)
	end

	itemFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			activeInput = input
			self.Container.ScrollingEnabled = false 
			updateSlider(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			isDragging = false
			activeInput = nil
			self.Container.ScrollingEnabled = true 
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input == activeInput then 
			updateSlider(input) 
		end
	end)
end

function TabClass:Input(label, inputType, default, callback)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 40)
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

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.45, 0, 0, 26)
	inputBox.Position = UDim2.new(0.55, -12, 0.5, -13)
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
		task.spawn(callback, inputBox.Text)
	end)
end

function TabClass:VariableBtn(label, defaultText, btnText, callback)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 40)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.4, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.35, -6, 0, 26)
	inputBox.Position = UDim2.new(0.4, 0, 0.5, -13)
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
	actionBtn.Size = UDim2.new(0.25, -12, 0, 26)
	actionBtn.Position = UDim2.new(0.75, 0, 0.5, -13)
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
	btnLabel.TextColor3 = THEME.BgColor -- Черный текст на белой кнопке для контраста
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = actionBtn

	actionBtn.Activated:Connect(function()
		createTween(actionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.4})
		task.spawn(callback, inputBox.Text)
		task.wait(0.1)
		createTween(actionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0})
	end)
end

return iOSLibrary
