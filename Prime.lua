--[[
	UILib — простая GUI-библиотека для Roblox (Luau)
	Стиль: светлый фон, чёрный акцент, скруглённые углы, плавные анимации
	Компоненты: Window, Tab, Toggle

	Использование:
		local UILib = loadstring(game:HttpGet("https://raw.githubusercontent.com/.../UILib.lua"))()

		local Window = UILib:CreateWindow({ Name = "Моё окно" })
		local Tab1 = Window:CreateTab("Главная")

		Tab1:CreateToggle({
			Name = "Пример тогла",
			Default = false,
			Callback = function(value)
				print("Toggle:", value)
			end,
		})
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Тема
local Theme = {
	Background = Color3.fromRGB(255, 255, 255),
	Sidebar = Color3.fromRGB(245, 245, 245),
	Accent = Color3.fromRGB(20, 20, 20),
	AccentHover = Color3.fromRGB(45, 45, 45),
	Text = Color3.fromRGB(20, 20, 20),
	SubText = Color3.fromRGB(120, 120, 120),
	Stroke = Color3.fromRGB(225, 225, 225),
	ToggleOff = Color3.fromRGB(210, 210, 210),
	CornerRadius = UDim.new(0, 10),
}

local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

--// Утилиты
local function create(className, props, children)
	local inst = Instance.new(className)
	for prop, value in pairs(props or {}) do
		inst[prop] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = radius or Theme.CornerRadius })
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
	})
end

local function tween(inst, props, info)
	local t = TweenService:Create(inst, info or TWEEN_FAST, props)
	t:Play()
	return t
end

local function makeDraggable(frame, dragHandle)
	local dragging = false
	local dragStart, startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

--// Библиотека
local UILib = {}
UILib.__index = UILib

function UILib:CreateWindow(config)
	config = config or {}
	local windowName = config.Name or "UILib"

	-- ScreenGui
	local screenGui = create("ScreenGui", {
		Name = "UILib_" .. windowName,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})

	-- Главное окно
	local main = create("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(560, 360),
		Position = UDim2.new(0.5, -280, 0.5, -180),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		corner(UDim.new(0, 14)),
		stroke(Theme.Stroke, 1),
	})

	-- Верхняя панель (заголовок, перетаскивание)
	local topBar = create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = main,
	}, {
		corner(UDim.new(0, 14)),
	})

	-- перекрываем нижние скругления верхней панели прямоугольником
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = windowName,
		TextColor3 = Theme.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topBar,
	})

	create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	makeDraggable(main, topBar)

	-- Боковая панель с табами
	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 150, 1, -45),
		Position = UDim2.fromOffset(0, 45),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	}, {
		corner(UDim.new(0, 12)),
	})

	create("Frame", {
		Size = UDim2.new(0, 12, 1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local tabList = create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	create("Frame", {
		Name = "TabButtons",
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		Parent = sidebar,
	}, { tabList })
	local tabButtonsHolder = sidebar.TabButtons

	-- Контейнер контента вкладок
	local content = create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -150, 1, -45),
		Position = UDim2.fromOffset(150, 45),
		BackgroundTransparency = 1,
		Parent = main,
	})

	local window = setmetatable({
		_screenGui = screenGui,
		_main = main,
		_tabButtonsHolder = tabButtonsHolder,
		_content = content,
		_tabs = {},
		_activeTab = nil,
	}, UILib)

	return window
end

function UILib:CreateTab(name)
	local tabButton = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = self._tabButtonsHolder,
	}, { corner(UDim.new(0, 8)) })

	create("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.SubText,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tabButton,
	})

	local tabPage = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, -32, 1, -24),
		Position = UDim2.fromOffset(16, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self._content,
	})

	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabPage,
	})

	local tabObj = {
		_button = tabButton,
		_label = tabButton:FindFirstChildOfClass("TextLabel"),
		_page = tabPage,
		_window = self,
	}

	local function setActive(active)
		if active then
			tween(tabButton, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Accent }, TWEEN_FAST)
			tween(tabObj._label, { TextColor3 = Color3.fromRGB(255, 255, 255) }, TWEEN_FAST)
			tabPage.Visible = true
		else
			tween(tabButton, { BackgroundTransparency = 1 }, TWEEN_FAST)
			tween(tabObj._label, { TextColor3 = Theme.SubText }, TWEEN_FAST)
			tabPage.Visible = false
		end
	end

	tabButton.MouseButton1Click:Connect(function()
		if self._activeTab == tabObj then return end
		if self._activeTab then
			self._activeTab._setActive(false)
		end
		self._activeTab = tabObj
		setActive(true)
	end)

	tabObj._setActive = setActive
	table.insert(self._tabs, tabObj)

	-- активируем первую добавленную вкладку автоматически
	if not self._activeTab then
		self._activeTab = tabObj
		setActive(true)
	end

	--// Компоненты вкладки
	local TabAPI = {}

	function TabAPI:CreateToggle(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Toggle"
		local default = cfg.Default or false
		local callback = cfg.Callback or function() end

		local holder = create("Frame", {
			Name = "Toggle_" .. name,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Sidebar,
			BorderSizePixel = 0,
			Parent = tabPage,
		}, { corner(UDim.new(0, 8)) })

		create("TextLabel", {
			Size = UDim2.new(1, -70, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = holder,
		})

		local switchBg = create("Frame", {
			Name = "Switch",
			Size = UDim2.fromOffset(40, 22),
			Position = UDim2.new(1, -54, 0.5, -11),
			BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner(UDim.new(1, 0)) })

		local knob = create("Frame", {
			Name = "Knob",
			Size = UDim2.fromOffset(18, 18),
			Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = switchBg,
		}, { corner(UDim.new(1, 0)) })

		local clickArea = create("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = holder,
		})

		local state = default

		local function render(animated)
			local info = animated and TWEEN_MED or TWEEN_FAST
			tween(switchBg, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff }, info)
			tween(knob, { Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }, info)
		end

		clickArea.MouseButton1Click:Connect(function()
			state = not state
			render(true)
			callback(state)
		end)

		local toggleObj = {}
		function toggleObj:Set(value)
			state = value and true or false
			render(true)
			callback(state)
		end
		function toggleObj:Get()
			return state
		end

		return toggleObj
	end

	return TabAPI
end

return UILib
