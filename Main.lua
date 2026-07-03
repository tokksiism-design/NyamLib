local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local iOSLibrary = {}
iOSLibrary.__index = iOSLibrary

local TabClass = {}
TabClass.__index = TabClass

local RowClass = {}
RowClass.__index = RowClass

-- Чистокровный iOS Dark (Pure Black & Grayscale)
local THEME = {
	BgColor = Color3.fromRGB(23, 23, 23),
	ContainerColor = Color3.fromRGB(28, 28, 30),
	AccentColor = Color3.fromRGB(10, 132, 255),
	ToggleOnColor = Color3.fromRGB(48, 209, 88),
	TextColor = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(142, 142, 147),
	DividerColor = Color3.fromRGB(44, 44, 46),
	Font = Enum.Font.SourceSans,
}

local function createTween(obj, info, properties)
	local tween = TweenService:Create(obj, info, properties)
	tween:Play()
	return tween
end

-- Блокировка прокликов сквозь интерфейс
local function preventClickThrough(instance)
	instance.Active = true
	instance.InputBegan:Connect(function() end)
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
	local windowSize = size or Vector2.new(460, 340)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "iOS_Window_" .. title:gsub("%s+", "_")
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
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	preventClickThrough(mainFrame)

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 14)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = THEME.DividerColor
	mainStroke.Thickness = 1
	mainStroke.Transparency = 0.4
	mainStroke.Parent = mainFrame

	-- Хедер окна
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundColor3 = THEME.ContainerColor
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = THEME.TextColor
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header

	-- Сайдбар для вкладок
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 110, 1, -40)
	sidebar.Position = UDim2.new(0, 0, 0, 40)
	sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainFrame

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Padding = UDim.new(0, 4)
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sidebarLayout.Parent = sidebar

	local sidebarPadding = Instance.new("UIPadding")
	sidebarPadding.PaddingTop = UDim.new(0, 8)
	sidebarPadding.Parent = sidebar

	-- Контент
	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -122, 1, -52)
	contentFrame.Position = UDim2.new(0, 116, 0, 46)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentFrame = contentFrame
	self.Tabs = {}
	self.CurrentTab = nil

	-- Драг
	local dragging, dragInput, dragStart, startPos = false, nil, Vector3.new(), UDim2.new()
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStart = input.Position
			startPos = mainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false dragInput = nil end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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
		createTween(oldTab.Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(12, 12, 12)})
		createTween(oldTab.Button:FindFirstChild("TextLabel"), TweenInfo.new(0.2), {TextColor3 = THEME.SecondaryText})
		if oldTab.Indicator then
			createTween(oldTab.Indicator, TweenInfo.new(0.2), {BackgroundTransparency = 1})
		end
		createTween(oldTab.CanvasGroup, TweenInfo.new(0.15), {GroupTransparency = 1}).Completed:Connect(function()
			if self.CurrentTab ~= oldTab then oldTab.CanvasGroup.Visible = false end
		end)
	end

	createTween(targetTab.Button, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = THEME.ContainerColor
	})
	createTween(targetTab.Button:FindFirstChild("TextLabel"), TweenInfo.new(0.2), {TextColor3 = THEME.AccentColor})
	if targetTab.Indicator then
		createTween(targetTab.Indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0})
	end

	targetTab.CanvasGroup.Visible = true
	createTween(targetTab.CanvasGroup, TweenInfo.new(0.2), {GroupTransparency = 0})
end

function iOSLibrary:CreateTab(name)
	local tab = setmetatable({}, TabClass)
	tab.Name = name

	local btnFrame = Instance.new("Frame")
	btnFrame.Size = UDim2.new(0, 100, 0, 32)
	btnFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	btnFrame.Parent = self.Sidebar
	preventClickThrough(btnFrame)

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btnFrame

	-- Индикатор активной вкладки (тонкая полоска слева, как в iOS настройках)
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0, 16)
	indicator.Position = UDim2.new(0, 0, 0.5, -8)
	indicator.BackgroundColor3 = THEME.AccentColor
	indicator.BackgroundTransparency = 1
	indicator.Parent = btnFrame

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(1, 0)
	indicatorCorner.Parent = indicator

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Name = "TextLabel"
	btnLabel.Size = UDim2.new(1, -8, 1, 0)
	btnLabel.Position = UDim2.new(0, 8, 0, 0)
	btnLabel.Text = name
	btnLabel.Font = THEME.Font
	btnLabel.TextSize = 13
	btnLabel.TextColor3 = THEME.SecondaryText
	btnLabel.TextXAlignment = Enum.TextXAlignment.Left
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
	container.ScrollBarThickness = 2
	container.ScrollBarImageColor3 = THEME.DividerColor
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.Parent = canvasGroup

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
	end)

	tab.Button = btnFrame
	tab.Indicator = indicator
	tab.CanvasGroup = canvasGroup
	tab.Container = container

	self.Tabs[name] = tab

	btnFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:SelectTab(name)
		end
	end)

	if not self.CurrentTab then
		task.defer(function() self:SelectTab(name) end)
	end

	return tab
end

----------------------------------------------------
-- СТРОКИ (SIDE-BY-SIDE / МУЛЬТИ-КОЛОНКИ)
----------------------------------------------------
function TabClass:CreateRow()
	local row = setmetatable({}, RowClass)

	local rowFrame = Instance.new("Frame")
	rowFrame.Size = UDim2.new(1, 0, 0, 35)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = self.Container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = rowFrame

	row.Container = rowFrame
	return row
end

function RowClass:Toggle(label, default, callback)
	local state = default
	local item = Instance.new("Frame")
	item.Size = UDim2.new(0.5, -3, 1, 0)
	item.BackgroundColor3 = THEME.ContainerColor
	item.Parent = self.Container
	preventClickThrough(item)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = item

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -45, 1, 0)
	textLabel.Position = UDim2.new(0, 10, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 13
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = item

	local switchBg, thumb = makeSwitch(item, UDim2.new(0, 32, 0, 18), -40, state)

	item.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state = not state
			createTween(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor})
			createTween(thumb, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)})
			task.spawn(callback, state)
		end
	end)
end

function RowClass:Button(text, callback)
	local btn = Instance.new("Frame")
	btn.Size = UDim2.new(0.5, -3, 1, 0)
	btn.BackgroundColor3 = THEME.DividerColor
	btn.Parent = self.Container
	preventClickThrough(btn)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	label.Font = THEME.Font
	label.TextSize = 13
	label.TextColor3 = THEME.TextColor
	label.BackgroundTransparency = 1
	label.Parent = btn

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			createTween(btn, TweenInfo.new(0.1), {BackgroundColor3 = THEME.ContainerColor})
			task.spawn(callback)
			task.wait(0.1)
			createTween(btn, TweenInfo.new(0.1), {BackgroundColor3 = THEME.DividerColor})
		end
	end)
end

----------------------------------------------------
-- СТАНДАРТНЫЕ ЭЛЕМЕНТЫ ВКЛАДКИ
----------------------------------------------------

function TabClass:Toggle(label, default, callback)
	local state = default
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 38)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	preventClickThrough(itemFrame)

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

	itemFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state = not state
			createTween(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor})
			createTween(thumb, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)})
			task.spawn(callback, state)
		end
	end)
end

-- ДВА ТОГГЛА В ОДНОМ РЯДУ (как просили — рядом с тогглом ещё тоггл, в стиле обычного Toggle)
function TabClass:DualToggle(label1, default1, callback1, label2, default2, callback2)
	local rowFrame = Instance.new("Frame")
	rowFrame.Size = UDim2.new(1, 0, 0, 38)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = self.Container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = rowFrame

	local function buildHalf(label, default, callback)
		local state = default
		local half = Instance.new("Frame")
		half.Size = UDim2.new(0.5, -3, 1, 0)
		half.BackgroundColor3 = THEME.ContainerColor
		half.Parent = rowFrame
		preventClickThrough(half)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = half

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, -45, 1, 0)
		textLabel.Position = UDim2.new(0, 10, 0, 0)
		textLabel.Text = label
		textLabel.Font = THEME.Font
		textLabel.TextSize = 13
		textLabel.TextColor3 = THEME.TextColor
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.TextTruncate = Enum.TextTruncate.AtEnd
		textLabel.BackgroundTransparency = 1
		textLabel.Parent = half

		local switchBg, thumb = makeSwitch(half, UDim2.new(0, 32, 0, 18), -40, state)

		half.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				state = not state
				createTween(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor})
				createTween(thumb, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)})
				task.spawn(callback, state)
			end
		end)
	end

	buildHalf(label1, default1, callback1)
	buildHalf(label2, default2, callback2)
end

function TabClass:Slider(label, min, max, default, callback)
	local currentVal = math.clamp(default, min, max)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 50)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	preventClickThrough(itemFrame)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.7, 0, 0, 22)
	textLabel.Position = UDim2.new(0, 12, 0, 4)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 13
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.25, 0, 0, 22)
	valueLabel.Position = UDim2.new(0.75, -12, 0, 4)
	valueLabel.Text = string.format("%.1f", currentVal)
	valueLabel.Font = THEME.Font
	valueLabel.TextSize = 12
	valueLabel.TextColor3 = THEME.SecondaryText
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = itemFrame

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, -24, 0, 4)
	sliderTrack.Position = UDim2.new(0, 12, 0, 34)
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
			updateSlider(input)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then isDragging = false activeInput = nil end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input == activeInput then updateSlider(input) end
	end)
end

function TabClass:Input(label, inputType, default, callback)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 38)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	preventClickThrough(itemFrame)

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
	inputBox.Size = UDim2.new(0.45, 0, 0, 24)
	inputBox.Position = UDim2.new(0.55, -12, 0.5, -12)
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
	itemFrame.Size = UDim2.new(1, 0, 0, 38)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	preventClickThrough(itemFrame)

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
	inputBox.Size = UDim2.new(0.35, -6, 0, 24)
	inputBox.Position = UDim2.new(0.4, 0, 0.5, -12)
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

	local actionBtn = Instance.new("Frame")
	actionBtn.Size = UDim2.new(0.25, -12, 0, 24)
	actionBtn.Position = UDim2.new(0.75, 0, 0.5, -12)
	actionBtn.BackgroundColor3 = THEME.AccentColor
	actionBtn.Parent = itemFrame
	preventClickThrough(actionBtn)

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = actionBtn

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(1, 0, 1, 0)
	btnLabel.Text = btnText
	btnLabel.Font = THEME.Font
	btnLabel.TextSize = 12
	btnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = actionBtn

	actionBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			createTween(actionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3})
			task.spawn(callback, inputBox.Text)
			task.wait(0.1)
			createTween(actionBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0})
		end
	end)
end

return iOSLibrary
