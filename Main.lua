--!strict
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Типизация для строгого режима Luau
type Theme = {
	BgColor: Color3,
	ContainerColor: Color3,
	AccentColor: Color3,
	ToggleOnColor: Color3,
	TextColor: Color3,
	SecondaryText: Color3,
	DividerColor: Color3,
	Font: Enum.Font,
}

type Tab = {
	Name: string,
	Button: Frame,
	CanvasGroup: CanvasGroup,
	Container: ScrollingFrame,
	Toggle: (self: Tab, label: string, default: boolean, callback: (boolean) -> ()) -> (),
	Slider: (self: Tab, label: string, min: number, max: number, default: number, callback: (number) -> ()) -> (),
	Variable: (self: Tab, label: string, default: string, callback: (string) -> ()) -> ()
}

type Library = {
	ScreenGui: ScreenGui,
	MainFrame: Frame,
	Sidebar: Frame,
	ContentFrame: Frame,
	Tabs: { [string]: Tab },
	CurrentTab: Tab?,
	CreateTab: (self: Library, name: string) -> Tab,
	SelectTab: (self: Library, name: string) -> ()
}

local iOSLibrary = {}
iOSLibrary.__index = iOSLibrary

local TabClass = {}
TabClass.__index = TabClass

-- iOS Dark Premium Theme Config
local THEME: Theme = {
	BgColor = Color3.fromRGB(20, 20, 22),       -- Глубокий темный
	ContainerColor = Color3.fromRGB(36, 36, 38),-- Компоненты
	AccentColor = Color3.fromRGB(10, 132, 255),   -- iOS Синий
	ToggleOnColor = Color3.fromRGB(48, 209, 88),  -- iOS Зеленый
	TextColor = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(142, 142, 147),
	DividerColor = Color3.fromRGB(54, 54, 56),
	Font = Enum.Font.SourceSans,
}

local function createTween(obj: Instance, info: TweenInfo, properties: {[string]: any})
	local tween = TweenService:Create(obj, info, properties)
	tween:Play()
	return tween
end

-- Инициализация главного окна
function iOSLibrary.new(title: string): Library
	local self = setmetatable({}, iOSLibrary) :: any
	
	local menuName = "iOS_Internal_Menu_Protected"
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local oldMenu = CoreGui:FindFirstChild(menuName) or (playerGui and playerGui:FindFirstChild(menuName))
	if oldMenu then oldMenu:Destroy() end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = menuName
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	local success, _ = pcall(function() screenGui.Parent = CoreGui end)
	if not success then
		screenGui.Parent = playerGui or Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.ScreenGui = screenGui
	
	-- Главный фрейм (адаптирован под сайдбар)
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 440, 0, 360)
	mainFrame.Position = UDim2.new(0.5, -220, 0.5, -180)
	mainFrame.BackgroundColor3 = THEME.BgColor
	mainFrame.BackgroundTransparency = 0.05 -- Легкая iOS прозрачность
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 14)
	mainCorner.Parent = mainFrame
	
	-- Хедер
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 45)
	header.BackgroundTransparency = 1
	header.Parent = mainFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = THEME.Font
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = THEME.TextColor
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header
	
	-- Левый сайдбар для вкладок
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 100, 1, -55)
	sidebar.Position = UDim2.new(0, 8, 0, 45)
	sidebar.BackgroundTransparency = 1
	sidebar.Parent = mainFrame
	
	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Padding = UDim.new(0, 8)
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sidebarLayout.Parent = sidebar
	
	-- Контейнер для контента вкладок
	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -122, 1, -55)
	contentFrame.Position = UDim2.new(0, 114, 0, 45)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame
	
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentFrame = contentFrame
	self.Tabs = {}
	self.CurrentTab = nil
	
	-- Драг-система
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
	
	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
			screenGui.Enabled = not screenGui.Enabled
		end
	end)
	
	-- Создание дефолтной вкладки настроек в самом низу
	task.defer(function()
		local settingsTab = self:CreateTab("Настройки")
		settingsTab.Button.LayoutOrder = 9999 -- Всегда снизу
		
		-- Кнопка закрытия чита с двойным подтверждением
		local closeFrame = Instance.new("Frame")
		closeFrame.Size = UDim2.new(1, 0, 0, 44)
		closeFrame.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
		closeFrame.BackgroundTransparency = 0.15
		closeFrame.Parent = settingsTab.Container
		
		local closeCorner = Instance.new("UICorner")
		closeCorner.CornerRadius = UDim.new(0, 10)
		closeCorner.Parent = closeFrame
		
		local closeLabel = Instance.new("TextLabel")
		closeLabel.Size = UDim2.new(1, 0, 1, 0)
		closeLabel.Text = "Закрыть чит"
		closeLabel.Font = THEME.Font
		closeLabel.TextSize = 14
		closeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeLabel.BackgroundTransparency = 1
		closeLabel.Parent = closeFrame
		
		local isConfirming = false
		local confirmThread: thread? = nil
		
		closeFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if not isConfirming then
					isConfirming = true
					closeLabel.Text = "Вы уверены? (Нажмите еще раз)"
					createTween(closeFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 69, 58)})
					
					confirmThread = task.delay(3, function()
						isConfirming = false
						closeLabel.Text = "Закрыть чит"
						createTween(closeFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 59, 48)})
					end)
				else
					if confirmThread then task.cancel(confirmThread) end
					screenGui:Destroy()
				end
			end
		end)
	end)
	
	return self
end

-- Переключение вкладок с iOS анимацией контента и кнопок
function iOSLibrary:SelectTab(name: string)
	local targetTab = self.Tabs[name]
	if not targetTab or self.CurrentTab == targetTab then return end
	
	local oldTab = self.CurrentTab
	self.CurrentTab = targetTab
	
	if oldTab then
		-- Сжатие и затемнение старой кнопки
		createTween(oldTab.Button, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 84, 0, 55),
			BackgroundColor3 = THEME.ContainerColor
		})
		-- Анимация исчезновения старого контента
		createTween(oldTab.CanvasGroup, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 1,
			Position = UDim2.new(0, 0, 0, -10)
		}).Completed:Connect(function()
			if self.CurrentTab ~= oldTab then oldTab.CanvasGroup.Visible = false end
		end)
	end
	
	-- Анимация расширения и осветления активной кнопки (+пара пикселей)
	createTween(targetTab.Button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 92, 0, 62),
		BackgroundColor3 = Color3.fromRGB(58, 58, 60)
	})
	
	-- Плавное появление нового контента (выезжает снизу вверх)
	targetTab.CanvasGroup.Visible = true
	targetTab.CanvasGroup.Position = UDim2.new(0, 0, 0, 15)
	
	createTween(targetTab.CanvasGroup, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
		Position = UDim2.new(0, 0, 0, 0)
	})
end

-- Создание новой вкладки
function iOSLibrary:CreateTab(name: string): Tab
	local tab = setmetatable({}, TabClass) :: any
	tab.Name = name
	
	-- Квадратная кнопка в сайдбаре
	local btnFrame = Instance.new("Frame")
	btnFrame.Size = UDim2.new(0, 84, 0, 55)
	btnFrame.BackgroundColor3 = THEME.ContainerColor
	btnFrame.Parent = self.Sidebar
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = btnFrame
	
	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(1, -10, 1, -10)
	btnLabel.Position = UDim2.new(0, 5, 0, 5)
	btnLabel.Text = name
	btnLabel.Font = THEME.Font
	btnLabel.TextSize = 13
	btnLabel.TextColor3 = THEME.TextColor
	btnLabel.TextWrapped = true
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = btnFrame
	
	-- CanvasGroup для красивого iOS фейда страниц
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
	container.ScrollBarImageColor3 = THEME.SecondaryText
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.Parent = canvasGroup
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container
	
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)
	
	tab.Button = btnFrame
	tab.CanvasGroup = canvasGroup
	tab.Container = container
	
	self.Tabs[name] = tab
	
	btnFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:SelectTab(name)
		end
	end)
	
	-- Авто-выбор первой созданной вкладки
	if not self.CurrentTab and name ~= "Настройки" then
		task.defer(function() self:SelectTab(name) end)
	end
	
	return tab
end

----------------------------------------------------
-- МЕТОДЫ ЭЛЕМЕНТОВ ВКЛАДКИ (Toggle, Slider, Variable)
----------------------------------------------------

function TabClass:Toggle(label: string, default: boolean, callback: (boolean) -> ())
	local state = default
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, -6, 0, 44)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemFrame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -70, 1, 0)
	textLabel.Position = UDim2.new(0, 14, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame
	
	local switchBg = Instance.new("Frame")
	switchBg.Size = UDim2.new(0, 46, 0, 26)
	switchBg.Position = UDim2.new(1, -56, 0.5, -13)
	switchBg.BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor
	switchBg.Parent = itemFrame
	
	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = switchBg
	
	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, 22, 0, 22)
	thumb.Position = state and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.Parent = switchBg
	
	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb
	
	local function toggle()
		state = not state
		local targetColor = state and THEME.ToggleOnColor or THEME.DividerColor
		local targetPos = state and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
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

function TabClass:Slider(label: string, min: number, max: number, default: number, callback: (number) -> ())
	local currentVal = math.clamp(default, min, max)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, -6, 0, 60)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemFrame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.7, 0, 0, 25)
	textLabel.Position = UDim2.new(0, 14, 0, 4)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame
	
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.25, 0, 0, 25)
	valueLabel.Position = UDim2.new(0.72, -10, 0, 4)
	valueLabel.Text = string.format("%.1f", currentVal)
	valueLabel.Font = THEME.Font
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = THEME.SecondaryText
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = itemFrame
	
	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, -28, 0, 6)
	sliderTrack.Position = UDim2.new(0, 14, 0, 38)
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

function TabClass:Variable(label: string, default: string, callback: (string) -> ())
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, -6, 0, 44)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = self.Container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemFrame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.5, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 14, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame
	
	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0.45, 0, 0, 28)
	inputBox.Position = UDim2.new(0.55, -10, 0.5, -14)
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

return iOSLibrary
