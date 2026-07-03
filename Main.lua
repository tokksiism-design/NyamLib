local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local iOSLibrary = {}
iOSLibrary.__index = iOSLibrary

local TabClass = {}
TabClass.__index = TabClass

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local THEME = {
	BgColor = Color3.fromRGB(0, 0, 0),
	ContainerColor = Color3.fromRGB(28, 28, 30),
	SidebarColor = Color3.fromRGB(16, 16, 18),
	AccentColor = Color3.fromRGB(255, 255, 255),
	ToggleOnColor = Color3.fromRGB(48, 209, 88),
	DangerColor = Color3.fromRGB(255, 69, 58),      -- iOS красный
	TextColor = Color3.fromRGB(255, 255, 255),
	SecondaryText = Color3.fromRGB(142, 142, 147),
	DividerColor = Color3.fromRGB(44, 44, 46),
	Font = Enum.Font.Gotham,
}

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

----------------------------------------------------
-- РИСОВАННЫЕ ИКОНКИ (без спец-символов)
----------------------------------------------------
local function drawCross(parent, size, color, thickness)
	-- Крестик из двух повернутых полосок
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, size, 0, size)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	for _, rot in ipairs({45, -45}) do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, thickness or 2)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.new(0.5, 0, 0.5, 0)
		line.Rotation = rot
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.Parent = holder
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = line
	end
	return holder
end

local function drawBurger(parent, size, color)
	-- Три полоски
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, size, 0, size)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	for i = 0, 2 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Position = UDim2.new(0, 0, 0, math.floor(i * (size - 2) / 2))
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.Parent = holder
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = line
	end
	return holder
end

local function drawChevron(parent, size, color)
	-- Галочка "v" из двух полосок, поворачиваем holder для смены направления
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, size, 0, size)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local l1 = Instance.new("Frame")
	l1.Size = UDim2.new(0.62, 0, 0, 2)
	l1.AnchorPoint = Vector2.new(1, 0.5)
	l1.Position = UDim2.new(0.5, 1, 0.55, 0)
	l1.Rotation = 45
	l1.BackgroundColor3 = color
	l1.BorderSizePixel = 0
	l1.Parent = holder
	local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(1, 0); c1.Parent = l1

	local l2 = Instance.new("Frame")
	l2.Size = UDim2.new(0.62, 0, 0, 2)
	l2.AnchorPoint = Vector2.new(0, 0.5)
	l2.Position = UDim2.new(0.5, -1, 0.55, 0)
	l2.Rotation = -45
	l2.BackgroundColor3 = color
	l2.BorderSizePixel = 0
	l2.Parent = holder
	local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(1, 0); c2.Parent = l2

	return holder
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
-- ТЕНЬ (imgui-стиль: градиент от полупрозрачного к прозрачному)
-- 4 стороны + 4 угла, без картинок-ассетов
----------------------------------------------------
local function buildShadow(mainFrame, spread)
	spread = spread or 24
	local holder = Instance.new("Frame")
	holder.Name = "ShadowHolder"
	holder.Size = UDim2.new(1, spread * 2, 1, spread * 2)
	holder.Position = UDim2.new(0, -spread, 0, -spread)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 0
	holder.Visible = false
	holder.Parent = mainFrame

	local function edge(size, pos, rotation)
		local f = Instance.new("Frame")
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 0
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		-- 1 часть полупрозрачная -> 2 часть полностью прозрачная
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		return f
	end

	-- Стороны (градиент направлен наружу от окна)
	edge(UDim2.new(1, -spread * 2, 0, spread), UDim2.new(0, spread, 0, 0), -90)              -- верх
	edge(UDim2.new(1, -spread * 2, 0, spread), UDim2.new(0, spread, 1, -spread), 90)         -- низ
	edge(UDim2.new(0, spread, 1, -spread * 2), UDim2.new(0, 0, 0, spread), 180)              -- лево
	edge(UDim2.new(0, spread, 1, -spread * 2), UDim2.new(1, -spread, 0, spread), 0)          -- право

	-- Углы (диагональный градиент)
	local corners = {
		{ UDim2.new(0, 0, 0, 0), 135 },              -- левый верх
		{ UDim2.new(1, -spread, 0, 0), -135 },       -- правый верх (в градусах Roblox: 225)
		{ UDim2.new(0, 0, 1, -spread), 45 },         -- левый низ
		{ UDim2.new(1, -spread, 1, -spread), -45 },  -- правый низ
	}
	for _, data in ipairs(corners) do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, spread, 0, spread)
		f.Position = data[1]
		f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 0
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = data[2]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end

	return holder
end

----------------------------------------------------
-- ОКНО
----------------------------------------------------
function iOSLibrary.CreateWindow(title, size)
	local self = setmetatable({}, iOSLibrary)

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
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 2147483647 -- максимум, ничто не перебьет

	-- Экзекьютор-парентинг: gethui -> protect_gui -> CoreGui -> PlayerGui
	local parented = false
	if typeof(gethui) == "function" then
		local ok = pcall(function() screenGui.Parent = gethui() end)
		parented = ok and screenGui.Parent ~= nil
	end
	if not parented and typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		local ok = pcall(function()
			syn.protect_gui(screenGui)
			screenGui.Parent = CoreGui
		end)
		parented = ok and screenGui.Parent ~= nil
	end
	if not parented then
		local ok = pcall(function() screenGui.Parent = CoreGui end)
		parented = ok and screenGui.Parent ~= nil
	end
	if not parented then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.ScreenGui = screenGui

	-- Защита: если кто-то сбросит DisplayOrder — вернем максимум
	screenGui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
		if screenGui.DisplayOrder ~= 2147483647 then
			screenGui.DisplayOrder = 2147483647
		end
	end)

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
	mainFrame.Position = UDim2.new(0.5, -windowSize.X / 2, 0.5, -windowSize.Y / 2)
	mainFrame.BackgroundColor3 = THEME.BgColor
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Active = true
	mainFrame.Parent = screenGui

	local windowScale = Instance.new("UIScale")
	windowScale.Scale = 1
	windowScale.Parent = mainFrame

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 14)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = THEME.DividerColor
	mainStroke.Thickness = 1
	mainStroke.Parent = mainFrame

	-- Тень (по дефолту выключена, тумблер в Settings)
	local shadowHolder = buildShadow(mainFrame, 24)
	self.ShadowHolder = shadowHolder

	local headerH = IS_MOBILE and 46 or 42
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, headerH)
	header.BackgroundColor3 = THEME.ContainerColor
	header.BorderSizePixel = 0
	header.Active = true
	header.Parent = mainFrame

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

	-- Кнопка сворачивания (крестик нарисован фреймами)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, headerH - 14, 0, headerH - 14)
	closeBtn.Position = UDim2.new(1, -(headerH - 7), 0.5, -(headerH - 14) / 2)
	closeBtn.BackgroundColor3 = THEME.DividerColor
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn
	drawCross(closeBtn, 12, THEME.TextColor, 2)
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
	sidebar.Active = true
	sidebar.Parent = mainFrame

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
	contentFrame.Parent = mainFrame

	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.SidebarWidth = sidebarW
	self.ContentFrame = contentFrame
	self.Tabs = {}
	self.TabOrder = 0
	self.CurrentTab = nil
	self.IsOpen = false
	self.Destroyed = false

	function self:SetOpen(open)
		if self.Destroyed then return end
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

	function self:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		createTween(windowScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }).Completed:Connect(function()
			screenGui:Destroy()
		end)
	end

	closeBtn.Activated:Connect(function()
		self:SetOpen(false)
	end)

	-- Драг шапки с ограничением по экрану
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

	-- Плавающий пузырь (правый верх — не мешает джойстику), гамбургер нарисован
	local bubbleSize = IS_MOBILE and 52 or 44
	local bubble = Instance.new("TextButton")
	bubble.Size = UDim2.new(0, bubbleSize, 0, bubbleSize)
	bubble.Position = UDim2.new(1, -bubbleSize - 12, 0, 70)
	bubble.BackgroundColor3 = THEME.ContainerColor
	bubble.Text = ""
	bubble.AutoButtonColor = false
	bubble.Parent = screenGui

	local bubbleCorner = Instance.new("UICorner")
	bubbleCorner.CornerRadius = UDim.new(1, 0)
	bubbleCorner.Parent = bubble

	local bubbleStroke = Instance.new("UIStroke")
	bubbleStroke.Color = THEME.DividerColor
	bubbleStroke.Thickness = 1
	bubbleStroke.Parent = bubble

	drawBurger(bubble, 18, THEME.TextColor)
	attachPressEffect(bubble, 1.1)

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

	-- Уведомления
	local notifyHolder = Instance.new("Frame")
	notifyHolder.Size = UDim2.new(0, 240, 1, -20)
	notifyHolder.Position = UDim2.new(1, -250, 0, 10)
	notifyHolder.BackgroundTransparency = 1
	notifyHolder.Parent = screenGui

	local notifyLayout = Instance.new("UIListLayout")
	notifyLayout.Padding = UDim.new(0, 6)
	notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
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

	----------------------------------------------------
	-- ВКЛАДКА SETTINGS (всегда последняя, LayoutOrder 9999)
	----------------------------------------------------
	task.defer(function()
		local settingsTab = self:CreateTab("Settings")
		settingsTab.Button.LayoutOrder = 9999

		settingsTab:Section("Interface")

		settingsTab:Toggle("Shadow", false, function(state)
			shadowHolder.Visible = state
		end)

		settingsTab:Section("Danger zone")

		-- Красная кнопка выхода с подтверждением: [Отменить] [Выйти]
		local rowH = IS_MOBILE and 44 or 38
		local exitRow = Instance.new("Frame")
		exitRow.Size = UDim2.new(1, 0, 0, rowH)
		exitRow.BackgroundTransparency = 1
		exitRow.Parent = settingsTab.Container

		local confirming = false

		local cancelBtn = Instance.new("TextButton")
		cancelBtn.Size = UDim2.new(1, 0, 1, 0)
		cancelBtn.Position = UDim2.new(0, 0, 0, 0)
		cancelBtn.BackgroundColor3 = THEME.DangerColor
		cancelBtn.Text = "Выйти"
		cancelBtn.Font = Enum.Font.GothamBold
		cancelBtn.TextSize = 14
		cancelBtn.TextColor3 = THEME.TextColor
		cancelBtn.AutoButtonColor = false
		cancelBtn.Parent = exitRow

		local cancelCorner = Instance.new("UICorner")
		cancelCorner.CornerRadius = UDim.new(0, 8)
		cancelCorner.Parent = cancelBtn

		local confirmBtn = Instance.new("TextButton")
		confirmBtn.Size = UDim2.new(0, 0, 1, 0)
		confirmBtn.Position = UDim2.new(1, 0, 0, 0)
		confirmBtn.AnchorPoint = Vector2.new(1, 0)
		confirmBtn.BackgroundColor3 = THEME.DangerColor
		confirmBtn.Text = ""
		confirmBtn.Font = Enum.Font.GothamBold
		confirmBtn.TextSize = 14
		confirmBtn.TextColor3 = THEME.TextColor
		confirmBtn.AutoButtonColor = false
		confirmBtn.Visible = false
		confirmBtn.Parent = exitRow

		local confirmCorner = Instance.new("UICorner")
		confirmCorner.CornerRadius = UDim.new(0, 8)
		confirmCorner.Parent = confirmBtn

		attachPressEffect(cancelBtn, 1.02)
		attachPressEffect(confirmBtn, 1.02)

		local function enterConfirm()
			confirming = true
			-- Первая кнопка укорачивается и становится "Отменить" (серая)
			cancelBtn.Text = "Отменить"
			createTween(cancelBtn, T_FAST, {
				Size = UDim2.new(0.5, -3, 1, 0),
				BackgroundColor3 = THEME.DividerColor,
			})
			-- Вторая появляется справа — красная "Выйти"
			confirmBtn.Visible = true
			confirmBtn.Text = "Выйти"
			createTween(confirmBtn, T_FAST, { Size = UDim2.new(0.5, -3, 1, 0) })
		end

		local function exitConfirm()
			confirming = false
			cancelBtn.Text = "Выйти"
			createTween(cancelBtn, T_FAST, {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = THEME.DangerColor,
			})
			createTween(confirmBtn, T_FAST, { Size = UDim2.new(0, 0, 1, 0) }).Completed:Connect(function()
				if not confirming then confirmBtn.Visible = false end
			end)
		end

		cancelBtn.Activated:Connect(function()
			if confirming then
				exitConfirm()
			else
				enterConfirm()
			end
		end)

		confirmBtn.Activated:Connect(function()
			if confirming then
				self:Destroy()
			end
		end)
	end)

	return self
end

----------------------------------------------------
-- ВКЛАДКИ
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
	tab.Window = self

	self.TabOrder += 1

	local btnH = IS_MOBILE and 40 or 34
	local btnFrame = Instance.new("TextButton")
	btnFrame.Size = UDim2.new(1, -8, 0, btnH)
	btnFrame.BackgroundColor3 = THEME.ContainerColor
	btnFrame.BackgroundTransparency = 1
	btnFrame.Text = ""
	btnFrame.AutoButtonColor = false
	btnFrame.LayoutOrder = self.TabOrder
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
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = btnFrame

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
	container.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
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
	tab._lastRow = nil

	btnFrame.Activated:Connect(function()
		self:SelectTab(name)
	end)

	self.Tabs[name] = tab

	if not self.CurrentTab then
		task.defer(function() self:SelectTab(name) end)
	end

	return tab
end

-- Скрыть/показать вкладку (для кастомных вкладок)
function TabClass:SetVisible(visible)
	self.Button.Visible = visible
end

----------------------------------------------------
-- РАСКЛАДКА В СТИЛЕ IMGUI (opts вместо позиционных аргументов)
--
-- Каждый элемент принимает последним аргументом НЕОБЯЗАТЕЛЬНУЮ таблицу opts:
--   { Width = 0.5 }               -- ширина элемента (доля строки, 0..1)
--   { Width = 0.33, Inline = true } -- прилепить к предыдущему элементу в той же строке
--   { Height = 50 }               -- своя высота
-- Без opts элемент занимает всю строку, как обычно.
--
-- Пример:
--   tab:Toggle("Fly", false, cb, { Width = 0.5 })
--   tab:Button("Reset", cb, { Width = 0.5, Inline = true })
----------------------------------------------------
local function resolveLayout(tab, defaultHeight, opts)
	opts = opts or {}
	local height = opts.Height or defaultHeight
	local width = opts.Width

	if width and width < 1 then
		local row
		if opts.Inline and tab._lastRow then
			row = tab._lastRow
		else
			row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, height)
			row.BackgroundTransparency = 1
			row.Parent = tab.Container

			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Padding = UDim.new(0, 6)
			rowLayout.Parent = row

			tab._lastRow = row
		end
		return row, UDim2.new(width, -4, 1, 0)
	else
		tab._lastRow = nil
		return tab.Container, UDim2.new(1, 0, 0, height)
	end
end

----------------------------------------------------
-- ЭЛЕМЕНТЫ
----------------------------------------------------
function TabClass:Section(text)
	self._lastRow = nil
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

function TabClass:Label(text, opts)
	local parent, size = resolveLayout(self, 32, opts)
	local item = Instance.new("Frame")
	item.Size = size
	item.BackgroundColor3 = THEME.ContainerColor
	item.BackgroundTransparency = 0.5
	item.Parent = parent

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

function TabClass:Toggle(label, default, callback, opts)
	local state = default
	local parent, size = resolveLayout(self, IS_MOBILE and 46 or 40, opts)
	local compact = (opts and opts.Width and opts.Width <= 0.5)

	local itemFrame = Instance.new("TextButton")
	itemFrame.Size = size
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Text = ""
	itemFrame.AutoButtonColor = false
	itemFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = itemFrame

	local switchW = compact and 34 or 38
	local switchH = compact and 20 or 22

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -(switchW + 28), 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = compact and 13 or 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = itemFrame

	local switchBg, thumb, thumbSize = makeSwitch(itemFrame, UDim2.new(0, switchW, 0, switchH), -(switchW + 8), state)
	attachPressEffect(itemFrame, 1.02)

	itemFrame.Activated:Connect(function()
		state = not state
		createTween(switchBg, T_FAST, { BackgroundColor3 = state and THEME.ToggleOnColor or THEME.DividerColor })
		createTween(thumb, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = state and UDim2.new(1, -thumbSize - 2, 0.5, -thumbSize / 2) or UDim2.new(0, 2, 0.5, -thumbSize / 2)
		})
		task.spawn(callback, state)
	end)
end

function TabClass:Button(text, callback, opts)
	local parent, size = resolveLayout(self, IS_MOBILE and 44 or 38, opts)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.BackgroundColor3 = THEME.DividerColor
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.Text = text
	label.Font = THEME.Font
	label.TextSize = 13
	label.TextColor3 = THEME.TextColor
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.BackgroundTransparency = 1
	label.Parent = btn

	attachPressEffect(btn, 1.03)

	btn.Activated:Connect(function()
		task.spawn(callback)
	end)
end

function TabClass:Slider(label, min, max, default, callback, opts)
	local currentVal = math.clamp(default, min, max)
	local itemH = IS_MOBILE and 58 or 52
	local parent, size = resolveLayout(self, itemH, opts)

	local itemFrame = Instance.new("Frame")
	itemFrame.Size = size
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Active = true
	itemFrame.Parent = parent

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
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
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
	sliderTrack.Position = UDim2.new(0, 12, 1, -18)
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
				if math.abs(delta.X) > 8 and math.abs(delta.X) > math.abs(delta.Y) then
					capturing = true
					container.ScrollingEnabled = false
					createTween(knobScale, T_PRESS, { Scale = 1.25 })
					updateSlider(changed.Position.X)
				elseif math.abs(delta.Y) > 10 then
					dead = true
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
-- DROPDOWN без ClipsDescendants (не глючит со скруглением):
-- опции просто скрыты через Visible, фрейм меняет высоту
----------------------------------------------------
function TabClass:Dropdown(label, options, default, callback, opts)
	local currentOption = default or options[1]
	local expanded = false
	local baseH = IS_MOBILE and 44 or 40
	local optH = IS_MOBILE and 38 or 32
	local expandedH = baseH + #options * (optH + 4) + 8

	self._lastRow = nil -- дропдаун всегда на всю строку

	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, baseH)
	itemFrame.BackgroundColor3 = THEME.ContainerColor
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
	textLabel.Size = UDim2.new(0.45, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 12, 0, 0)
	textLabel.Text = label
	textLabel.Font = THEME.Font
	textLabel.TextSize = 14
	textLabel.TextColor3 = THEME.TextColor
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = headerBtn

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.55, -44, 1, 0)
	valueLabel.Position = UDim2.new(0.45, 0, 0, 0)
	valueLabel.Text = currentOption
	valueLabel.Font = THEME.Font
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = THEME.SecondaryText
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = headerBtn

	-- Стрелка нарисована фреймами (галочка вниз)
	local arrowHolder = Instance.new("Frame")
	arrowHolder.Size = UDim2.new(0, 24, 0, 24)
	arrowHolder.Position = UDim2.new(1, -34, 0.5, -12)
	arrowHolder.BackgroundTransparency = 1
	arrowHolder.Parent = headerBtn
	local chevron = drawChevron(arrowHolder, 14, THEME.SecondaryText)
	chevron.Position = UDim2.new(0.5, 0, 0.5, 0)

	local optionsHolder = Instance.new("Frame")
	optionsHolder.Size = UDim2.new(1, -16, 0, #options * (optH + 4))
	optionsHolder.Position = UDim2.new(0, 8, 0, baseH)
	optionsHolder.BackgroundTransparency = 1
	optionsHolder.Visible = false
	optionsHolder.Parent = itemFrame

	local optLayout = Instance.new("UIListLayout")
	optLayout.Padding = UDim.new(0, 4)
	optLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optLayout.Parent = optionsHolder

	local function setExpanded(open)
		expanded = open
		createTween(chevron, T_FAST, { Rotation = open and 180 or 0 })
		if open then
			itemFrame.Size = UDim2.new(1, 0, 0, expandedH)
			optionsHolder.Visible = true
			-- Быстрый fade-in опций
			for _, child in ipairs(optionsHolder:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundTransparency = 1
					child.TextTransparency = 1
					createTween(child, T_FAST, { BackgroundTransparency = 0, TextTransparency = 0 })
				end
			end
		else
			optionsHolder.Visible = false
			itemFrame.Size = UDim2.new(1, 0, 0, baseH)
		end
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

function TabClass:Input(label, inputType, default, callback, opts)
	local parent, size = resolveLayout(self, IS_MOBILE and 46 or 40, opts)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = size
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = parent

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
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
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

function TabClass:VariableBtn(label, defaultText, btnText, callback, opts)
	local parent, size = resolveLayout(self, IS_MOBILE and 46 or 40, opts)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = size
	itemFrame.BackgroundColor3 = THEME.ContainerColor
	itemFrame.Parent = parent

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
	btnLabel.TextTruncate = Enum.TextTruncate.AtEnd
	btnLabel.BackgroundTransparency = 1
	btnLabel.Parent = actionBtn

	attachPressEffect(actionBtn, 1.05)

	actionBtn.Activated:Connect(function()
		task.spawn(callback, inputBox.Text)
	end)
end

return iOSLibrary
