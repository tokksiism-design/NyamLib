--!strict
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local iOSLibrary = {}
iOSLibrary.__index = iOSLibrary

-- iOS Dark Theme Config
local THEME = {
	BgColor = Color3.fromRGB(28, 28, 30),
	ContainerColor = Color3.fromRGB(44, 44, 46),
	AccentColor = Color3.fromRGB(10, 132, 255),
	ToggleOnColor = Color3.fromRGB(48, 209, 88),
	TextColor = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(142, 142, 147),
	DividerColor = Color3.fromRGB(58, 58, 60),
	Font = Enum.Font.SFMono,
}

local function createTween(obj: Instance, info: TweenInfo, properties: {[string]: any})
	local tween = TweenService:Create(obj, info, properties)
	tween:Play()
	return tween
end

-- Инициализация окна
function iOSLibrary.new(title: string)
	local self = setmetatable({}, iOSLibrary)
	
	-- [ФИКС]: Чистим старое меню при перезапуске скрипта
	local menuName = "iOS_Internal_Menu_Protected"
	local oldMenu = CoreGui:FindFirstChild(menuName) or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"):FindFirstChild(menuName))
	if oldMenu then 
		oldMenu:Destroy() 
	end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = menuName
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	-- [ФИКС]: Безопасный инжект в зависимости от среды выполнения
	local success, _ = pcall(function()
		screenGui.Parent = CoreGui
	end)
	if not success then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	
	self.ScreenGui = screenGui
	
	-- Главный фрейм
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 320, 0, 400)
	mainFrame.Position = UDim2.new(0.5, -160, 0.5, -200)
	mainFrame.BackgroundColor3 = THEME.BgColor
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 14)
	mainCorner.Parent = mainFrame
	
	-- Хедер
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.Parent = mainFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.new(0, 20, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = THEME.Font
	titleLabel.TextSize = 17
	titleLabel.TextColor3 = THEME.TextColor
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header
	
	-- Скролл-контейнер для элементов
	local container = Instance.new("ScrollingFrame")
	container.Size = UDim2.new(1, -20, 1, -60)
	container.Position = UDim2.new(0, 10, 0, 50)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 2
	container.ScrollBarImageColor3 = THEME.SecondaryText
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.Parent = mainFrame
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container
	
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)
	
	self.MainFrame = mainFrame
	self.Container = container
	
	-- Логика перетаскивания (Mouse + Multi-Touch)
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.new()
	local startPos = UDim2.new()
	
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStart = input.Position
			startPos = mainFrame.Position
			
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					dragInput = nil
				end
			end)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	
	-- [ДОБАВЛЕНО]: Бинд на скрытие меню (RightShift)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
			screenGui.Enabled = not screenGui.Enabled
		end
	end)
	
	return self
end

-- Элемент: Toggle
function iOSLibrary:Toggle(label: string, default: boolean, callback: (boolean) -> ())
	local state = default
	
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 44)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemFrame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -70, 1, 0)
	textLabel.Position = UDim2.new(0, 15, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame
	
	local switchBg = Instance.new("Frame")
	switchBg.Size = UDim2.new(0, 51, 0, 31)
	switchBg.Position = UDim2.new(1, -66, 0.5, -15)
	switchBg.BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor
	switchBg.Parent = itemFrame
	
	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = switchBg
	
	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, 27, 0, 27)
	thumb.Position = state and UDim2.new(1, -29, 0.5, -13.5) or UDim2.new(0, 2, 0.5, -13.5)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.Parent = switchBg
	
	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb
	
	local function toggle()
		state = not state
		local targetColor = state and THEME.ToggleOnColor or THEME.DividerColor
		local targetPos = state and UDim2.new(1, -29, 0.5, -13.5) or UDim2.new(0, 2, 0.5, -13.5)
		
		createTween(switchBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = targetColor})
		createTween(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = targetPos})
		
		task.spawn(callback, state)
	end
	
	itemFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			toggle()
		end
	end)
end

-- Элемент: Slider
function iOSLibrary:Slider(label: string, min: number, max: number, default: number, callback: (number) -> ())
	local currentVal = math.clamp(default, min, max)
	
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 65)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemFrame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.7, 0, 0, 30)
	textLabel.Position = UDim2.new(0, 15, 0, 5)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame
	
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.25, 0, 0, 30)
	valueLabel.Position = UDim2.new(0.72, 0, 0, 5)
	valueLabel.Text = string.format("%.1f", currentVal)
	valueLabel.Font = THEME.Font
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = THEME.SecondaryText
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = itemFrame
	
	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, -30, 0, 6)
	sliderTrack.Position = UDim2.new(0, 15, 0, 42)
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
	
	-- Продвинутый Multi-Touch трекинг по InputObject ID
	local isDragging = false
	local activeInput: InputObject? = nil
	
	local function updateSlider(input: InputObject)
		local absPos = sliderTrack.AbsolutePosition
		local absSize = sliderTrack.AbsoluteSize
		local percentage = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
		
		currentVal = min + (percentage * (max - min))
		valueLabel.Text = string.format("%.1f", currentVal)
		sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
		
		task.spawn(callback, currentVal)
	end
	
	itemFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			activeInput = input
			updateSlider(input)
			
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDragging = false
					activeInput = nil
				end
			end)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input == activeInput then
			updateSlider(input)
		end
	end)
end

-- Элемент: Variable (Текстовое поле, ImGui Style)
function iOSLibrary:Variable(label: string, default: string, callback: (string) -> ())
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 44)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemFrame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.5, -15, 1, 0)
	textLabel.Position = UDim2.new(0, 15, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame
	
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.5, -15, 0, 30)
	inputBox.Position = UDim2.new(0.5, 0, 0.5, -15)
	inputBox.BackgroundColor3 = THEME.BgColor
	inputBox.Text = default
	inputBox.Font = THEME.Font
	inputBox.TextSize = 13
	inputBox.TextColor3 = THEME.TextColor
	inputBox.ClipsDescendants = true
	inputBox.ClearTextOnFocus = false
	inputBox.TextXAlignment = Enum.TextXAlignment.Center
	inputBox.Parent = itemFrame
	
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = inputBox
	
	inputBox.FocusLost:Connect(function()
		task.spawn(callback, inputBox.Text)
	end)
end

-- Обязательно возвращаем объект библиотеки для loadstring()()
return iOSLibrary
