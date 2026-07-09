--[[
	UILib v2 — GUI-библиотека для Roblox (Luau), оптимизирована под мобильные экзекуторы (Trigon Evo и т.п.)

	Стиль: светлый фон, чёрный акцент, скругления, дешёвые по FPS анимации (UIScale вместо Size).

	Компоненты:
		Window, Tab, Toggle, Slider, Button, Dropdown (single / multi), Label, Section, Row (колонки как в ImGui)

	Использование:
		local UILib = loadstring(game:HttpGet("https://raw.githubusercontent.com/.../UILib.lua"))()

		local Window = UILib:CreateWindow({
			Name = "Моё окно",
			StartHidden = false, -- если true: меню скрыто при старте, метка в центре мерцает
		})

		local Tab = Window:CreateTab("Главная")

		Tab:CreateToggle({ Name = "Тогл", Default = false, Callback = function(v) print(v) end })

		Tab:CreateSlider({
			Name = "Скорость", Min = 16, Max = 200, Step = 1, Default = 16,
			Callback = function(v) print(v) end,
		})

		Tab:CreateDropdown({
			Name = "Режим",
			Options = { "Легко", "Средне", "Сложно" },
			Default = "Легко",
			Multi = false,           -- true = мультивыбор
			MaxChoices = 2,          -- лимит для Multi (nil = без лимита)
			Callback = function(sel) print(sel) end, -- string или {string} при Multi
		})

		-- Колонки (как ImGui columns / SameLine):
		local left, right = Tab:CreateRow(2)
		left:CreateButton({ Name = "OK", Callback = function() end })
		right:CreateButton({ Name = "Отмена", Callback = function() end })

	Защита:
		- GUI монтируется через gethui() / syn.protect_gui / CoreGui — не виден через PlayerGui.
		- Имена всех инстансов рандомизированы: нельзя найти по FindFirstChild("...").
		- ВАЖНО: исходник, отдаваемый loadstring'ом, полностью защитить невозможно.
		  Для реальной защиты кода прогоняй файл через обфускатор (Prometheus / Luarmor)
		  и раздавай через свой лоадер с проверкой ключа.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

--// ============================== Тема ==============================

local Theme = {
	Background = Color3.fromRGB(255, 255, 255),
	Sidebar = Color3.fromRGB(245, 245, 245),
	Element = Color3.fromRGB(245, 245, 245),
	Accent = Color3.fromRGB(20, 20, 20),
	AccentHover = Color3.fromRGB(45, 45, 45),
	Text = Color3.fromRGB(20, 20, 20),
	OnAccent = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(120, 120, 120),
	Stroke = Color3.fromRGB(225, 225, 225),
	ToggleOff = Color3.fromRGB(210, 210, 210),
	SliderTrack = Color3.fromRGB(225, 225, 225),
}

-- Короткие и дешёвые твины: на мобиле с плавающим FPS длинные Back-анимации выглядят рвано.
local TWEEN_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_POP = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DOUBLE_TAP_MAX_GAP = 0.35

--// ============================== Утилиты ==============================

-- Рандомное имя, чтобы GUI/элементы нельзя было найти по имени.
local function randomName()
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local out = {}
	for i = 1, 12 do
		local n = math.random(1, #chars)
		out[i] = chars:sub(n, n)
	end
	return table.concat(out)
end

local function create(className, props, children)
	local inst = Instance.new(className)
	inst.Name = randomName()
	for prop, value in pairs(props or {}) do
		inst[prop] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 10) })
end

local function stroke(color, thickness)
	return create("UIStroke", { Color = color or Theme.Stroke, Thickness = thickness or 1 })
end

local function tween(inst, props, info)
	local t = TweenService:Create(inst, info or TWEEN_FAST, props)
	t:Play()
	return t
end

-- Монтирование GUI максимально скрытно для конкретного экзекутора.
local function mountGui(screenGui)
	-- 1) gethui — самый безопасный вариант (Trigon Evo его поддерживает)
	local ok, hidden = pcall(function()
		return (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
	end)
	if ok and typeof(hidden) == "Instance" then
		screenGui.Parent = hidden
		return
	end
	-- 2) syn.protect_gui + CoreGui
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(screenGui)
		end
	end)
	-- 3) CoreGui, если есть доступ
	local okCore = pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
	end)
	if okCore and screenGui.Parent then
		return
	end
	-- 4) fallback — PlayerGui
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Пресс-эффект через UIScale: одно числовое свойство, не трогает layout, дёшево по FPS.
local function addPressFeel(guiObject, targetScale)
	targetScale = targetScale or 0.94
	local scale = create("UIScale", { Parent = guiObject })

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = targetScale }, TWEEN_PRESS)
		end
	end)
	guiObject.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = 1 }, TWEEN_POP)
		end
	end)
end

-- Невидимая кнопка-накладка: даёт нативный .Activated (корректно работает на тач,
-- не срабатывает если палец увели с элемента — в отличие от ручного InputEnded).
local function addClickOverlay(parent, callback)
	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = (parent.ZIndex or 1) + 5,
		Parent = parent,
	})
	btn.Activated:Connect(callback)
	return btn
end

local function makeDraggable(frame, dragHandle, onDragStateChanged)
	local dragging = false
	local dragStart, startPos
	local moveConn, endConn

	local function stopDrag()
		dragging = false
		if moveConn then moveConn:Disconnect() moveConn = nil end
		if endConn then endConn:Disconnect() endConn = nil end
		if onDragStateChanged then onDragStateChanged(false) end
	end

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		if onDragStateChanged then onDragStateChanged(true) end

		-- Глобальные подписки живут только во время драга — не копим коннекты.
		moveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging then return end
			if moveInput.UserInputType == Enum.UserInputType.MouseMovement
				or moveInput.UserInputType == Enum.UserInputType.Touch then
				local delta = moveInput.Position - dragStart
				frame.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(endInput)
			if endInput.UserInputType == Enum.UserInputType.MouseButton1
				or endInput.UserInputType == Enum.UserInputType.Touch then
				stopDrag()
			end
		end)
	end)
end

--// ============================== Компоненты ==============================
-- Все креаторы компонентов вынесены в билдер: одинаково работают
-- и на вкладке, и внутри колонок (CreateRow).

local function attachComponentAPI(api, container)

	----------------------------------------------------------------
	function api:CreateLabel(text)
		local label = create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = text or "",
			TextColor3 = Theme.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = container,
		})
		local obj = {}
		function obj:Set(newText) label.Text = newText end
		return obj
	end

	----------------------------------------------------------------
	function api:CreateSection(text)
		local holder = create("Frame", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Parent = container,
		})
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = string.upper(text or ""),
			TextColor3 = Theme.SubText,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = holder,
		})
		create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -4),
			BackgroundColor3 = Theme.Stroke,
			BorderSizePixel = 0,
			Parent = holder,
		})
	end

	----------------------------------------------------------------
	function api:CreateButton(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Button"
		local callback = cfg.Callback or function() end

		local holder = create("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Parent = container,
		}, { corner(UDim.new(0, 8)) })

		local label = create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.OnAccent,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			Parent = holder,
		})

		addPressFeel(holder, 0.95)
		addClickOverlay(holder, function()
			-- короткая вспышка вместо тяжёлых эффектов
			tween(holder, { BackgroundColor3 = Theme.AccentHover }, TWEEN_PRESS).Completed:Connect(function()
				tween(holder, { BackgroundColor3 = Theme.Accent }, TWEEN_MED)
			end)
			task.spawn(callback)
		end)

		local obj = {}
		function obj:SetText(t) label.Text = t end
		return obj
	end

	----------------------------------------------------------------
	function api:CreateToggle(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Toggle"
		local state = cfg.Default == true
		local callback = cfg.Callback or function() end

		local holder = create("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Parent = container,
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
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local switchBg = create("Frame", {
			Size = UDim2.fromOffset(40, 22),
			Position = UDim2.new(1, -52, 0.5, -11),
			BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner(UDim.new(1, 0)) })

		local knob = create("Frame", {
			Size = UDim2.fromOffset(18, 18),
			Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = switchBg,
		}, { corner(UDim.new(1, 0)) })

		addPressFeel(holder, 0.97)

		local function render()
			tween(switchBg, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff }, TWEEN_MED)
			tween(knob, {
				Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
			}, TWEEN_POP)
		end

		addClickOverlay(holder, function()
			state = not state
			render()
			task.spawn(callback, state)
		end)

		local obj = {}
		function obj:Set(value, silent)
			state = value == true
			render()
			if not silent then task.spawn(callback, state) end
		end
		function obj:Get() return state end
		return obj
	end

	----------------------------------------------------------------
	function api:CreateSlider(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Slider"
		local min = cfg.Min or 0
		local max = cfg.Max or 100
		local step = cfg.Step or 1
		local value = math.clamp(cfg.Default or min, min, max)
		local suffix = cfg.Suffix or ""
		local callback = cfg.Callback or function() end

		local holder = create("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			Parent = container,
		}, { corner(UDim.new(0, 8)) })

		create("TextLabel", {
			Size = UDim2.new(1, -90, 0, 18),
			Position = UDim2.fromOffset(14, 6),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local valueLabel = create("TextLabel", {
			Size = UDim2.new(0, 74, 0, 18),
			Position = UDim2.new(1, -88, 0, 6),
			BackgroundTransparency = 1,
			Text = tostring(value) .. suffix,
			TextColor3 = Theme.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = holder,
		})

		local track = create("Frame", {
			Size = UDim2.new(1, -28, 0, 6),
			Position = UDim2.new(0, 14, 1, -18),
			BackgroundColor3 = Theme.SliderTrack,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner(UDim.new(1, 0)) })

		local fill = create("Frame", {
			Size = UDim2.fromScale((value - min) / math.max(max - min, 1e-9), 1),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(UDim.new(1, 0)) })

		local knob = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(UDim.new(1, 0)), stroke(Theme.Accent, 2) })

		-- Расширенная зона нажатия под палец (сам трек тонкий).
		local touchZone = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.new(0, 0, 0.5, -16),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = track,
		})

		local function snap(v)
			return math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
		end

		-- Во время драга — БЕЗ твинов (прямое присваивание), критично для мобильного FPS.
		local function applyValue(v, animated)
			if v == value and not animated then return end
			value = v
			local alpha = (value - min) / math.max(max - min, 1e-9)
			valueLabel.Text = tostring(value) .. suffix
			if animated then
				tween(fill, { Size = UDim2.fromScale(alpha, 1) }, TWEEN_MED)
				tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, TWEEN_MED)
			else
				fill.Size = UDim2.fromScale(alpha, 1)
				knob.Position = UDim2.new(alpha, 0, 0.5, 0)
			end
		end

		local dragging = false
		local moveConn, endConn

		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local newValue = snap(min + rel * (max - min))
			if newValue ~= value then
				applyValue(newValue, false)
				task.spawn(callback, value)
			end
		end

		local function stopDrag()
			dragging = false
			if moveConn then moveConn:Disconnect() moveConn = nil end
			if endConn then endConn:Disconnect() endConn = nil end
			tween(knob, { Size = UDim2.fromOffset(16, 16) }, TWEEN_POP)
		end

		touchZone.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			dragging = true
			tween(knob, { Size = UDim2.fromOffset(20, 20) }, TWEEN_FAST)
			setFromX(input.Position.X)

			moveConn = UserInputService.InputChanged:Connect(function(moveInput)
				if dragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement
					or moveInput.UserInputType == Enum.UserInputType.Touch) then
					setFromX(moveInput.Position.X)
				end
			end)
			endConn = UserInputService.InputEnded:Connect(function(endInput)
				if endInput.UserInputType == Enum.UserInputType.MouseButton1
					or endInput.UserInputType == Enum.UserInputType.Touch then
					stopDrag()
				end
			end)
		end)

		local obj = {}
		function obj:Set(v, silent)
			applyValue(snap(v), true)
			if not silent then task.spawn(callback, value) end
		end
		function obj:Get() return value end
		return obj
	end

	----------------------------------------------------------------
	function api:CreateDropdown(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Dropdown"
		local options = cfg.Options or {}
		local multi = cfg.Multi == true
		local maxChoices = cfg.MaxChoices -- только для multi, nil = без лимита
		local callback = cfg.Callback or function() end

		local OPTION_H = 32
		local HEADER_H = 40

		local selected = {} -- set: [option] = true
		if cfg.Default ~= nil then
			if typeof(cfg.Default) == "table" then
				for _, v in ipairs(cfg.Default) do selected[v] = true end
			else
				selected[cfg.Default] = true
			end
		end

		local expanded = false

		local holder = create("Frame", {
			Size = UDim2.new(1, 0, 0, HEADER_H),
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = container,
		}, { corner(UDim.new(0, 8)) })

		create("TextLabel", {
			Size = UDim2.new(0.45, -14, 0, HEADER_H),
			Position = UDim2.fromOffset(14, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local selectionLabel = create("TextLabel", {
			Size = UDim2.new(0.55, -46, 0, HEADER_H),
			Position = UDim2.new(0.45, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local arrow = create("TextLabel", {
			Size = UDim2.fromOffset(20, HEADER_H),
			Position = UDim2.new(1, -32, 0, 0),
			BackgroundTransparency = 1,
			Text = "v",
			TextColor3 = Theme.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			Parent = holder,
		})

		local listFrame = create("Frame", {
			Size = UDim2.new(1, -16, 0, #options * OPTION_H),
			Position = UDim2.fromOffset(8, HEADER_H),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })

		local function selectedList()
			local out = {}
			for _, opt in ipairs(options) do
				if selected[opt] then table.insert(out, opt) end
			end
			return out
		end

		local function selectedCount()
			local n = 0
			for _ in pairs(selected) do n += 1 end
			return n
		end

		local function refreshHeader()
			local list = selectedList()
			if #list == 0 then
				selectionLabel.Text = "—"
			else
				selectionLabel.Text = table.concat(list, ", ")
			end
		end

		local optionRows = {}

		local function refreshOptions()
			for opt, row in pairs(optionRows) do
				local isSel = selected[opt] == true
				tween(row.dot, {
					BackgroundColor3 = isSel and Theme.Accent or Theme.ToggleOff,
				}, TWEEN_FAST)
				tween(row.label, {
					TextColor3 = isSel and Theme.Text or Theme.SubText,
				}, TWEEN_FAST)
			end
		end

		local function fireCallback()
			if multi then
				task.spawn(callback, selectedList())
			else
				task.spawn(callback, selectedList()[1])
			end
		end

		local function setExpanded(open)
			expanded = open
			tween(holder, {
				Size = UDim2.new(1, 0, 0, open and (HEADER_H + #options * OPTION_H + 8) or HEADER_H),
			}, TWEEN_MED)
			tween(arrow, { Rotation = open and 180 or 0 }, TWEEN_MED)
		end

		for i, opt in ipairs(options) do
			local row = create("TextButton", {
				Size = UDim2.new(1, 0, 0, OPTION_H),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
				Parent = listFrame,
			})
			local dot = create("Frame", {
				Size = UDim2.fromOffset(10, 10),
				Position = UDim2.new(0, 8, 0.5, -5),
				BackgroundColor3 = selected[opt] and Theme.Accent or Theme.ToggleOff,
				BorderSizePixel = 0,
				Parent = row,
			}, { corner(UDim.new(1, 0)) })
			local label = create("TextLabel", {
				Size = UDim2.new(1, -34, 1, 0),
				Position = UDim2.fromOffset(28, 0),
				BackgroundTransparency = 1,
				Text = opt,
				TextColor3 = selected[opt] and Theme.Text or Theme.SubText,
				TextSize = 13,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
			optionRows[opt] = { dot = dot, label = label }

			row.Activated:Connect(function()
				if multi then
					if selected[opt] then
						selected[opt] = nil
					else
						if maxChoices and selectedCount() >= maxChoices then
							-- лимит достигнут — коротко "дёргаем" точку как отказ
							tween(dot, { Size = UDim2.fromOffset(14, 14) }, TWEEN_PRESS).Completed:Connect(function()
								tween(dot, { Size = UDim2.fromOffset(10, 10) }, TWEEN_POP)
							end)
							return
						end
						selected[opt] = true
					end
				else
					table.clear(selected)
					selected[opt] = true
					setExpanded(false) -- одиночный выбор закрывает список
				end
				refreshOptions()
				refreshHeader()
				fireCallback()
			end)
		end

		refreshHeader()

		-- Клик по шапке (не по опциям) — раскрыть/свернуть
		local headerZone = create("TextButton", {
			Size = UDim2.new(1, 0, 0, HEADER_H),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = holder,
		})
		headerZone.Activated:Connect(function()
			setExpanded(not expanded)
		end)

		local obj = {}
		function obj:Set(values, silent)
			table.clear(selected)
			if typeof(values) == "table" then
				for _, v in ipairs(values) do selected[v] = true end
			elseif values ~= nil then
				selected[values] = true
			end
			refreshOptions()
			refreshHeader()
			if not silent then fireCallback() end
		end
		function obj:Get()
			if multi then return selectedList() end
			return selectedList()[1]
		end
		return obj
	end

	----------------------------------------------------------------
	-- Колонки как в ImGui: local a, b, c = Tab:CreateRow(3)
	-- или с весами: Tab:CreateRow({ Weights = { 2, 1 } })
	function api:CreateRow(cfg)
		local weights
		if typeof(cfg) == "table" then
			weights = cfg.Weights
			if not weights then
				weights = table.create(cfg.Columns or 2, 1)
			end
		else
			weights = table.create(cfg or 2, 1)
		end

		local n = #weights
		local total = 0
		for _, w in ipairs(weights) do total += w end
		local GAP = 8

		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = container,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = row,
		})

		local columns = {}
		for i = 1, n do
			local colFrame = create("Frame", {
				Size = UDim2.new(weights[i] / total, -math.floor(GAP * (n - 1) / n), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = row,
			})
			create("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = colFrame,
			})
			local colApi = {}
			attachComponentAPI(colApi, colFrame)
			columns[i] = colApi
		end

		return table.unpack(columns)
	end
end

--// ============================== Окно ==============================

local UILib = {}
UILib.__index = UILib
UILib.Version = "2.0.0"
UILib.Theme = Theme

function UILib:CreateWindow(config)
	config = config or {}
	local windowName = config.Name or "UILib"
	local startHidden = config.StartHidden == true

	local screenGui = create("ScreenGui", {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})
	mountGui(screenGui)

	local main = create("Frame", {
		Size = UDim2.fromOffset(560, 360),
		Position = UDim2.new(0.5, -280, 0.5, -180),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		corner(UDim.new(0, 14)),
		stroke(Theme.Stroke, 1),
	})

	-- Анимация окна через UIScale — дёшево и не ломает layout детей.
	local windowScale = create("UIScale", { Scale = 1, Parent = main })

	--// Верхняя панель
	local topBar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(UDim.new(0, 14)) })

	create("Frame", { -- перекрываем нижние скругления шапки
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	local titleLabel = create("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = windowName,
		TextColor3 = Theme.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topBar,
	})

	-- Кнопка скрытия (минус) — отдельно от заголовка, чтобы драг и скрытие не конфликтовали
	local hideBtn = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -38, 0.5, -15),
		BackgroundColor3 = Theme.Sidebar,
		Text = "—",
		TextColor3 = Theme.Text,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = topBar,
	}, { corner(UDim.new(0, 8)) })
	addPressFeel(hideBtn, 0.9)

	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	makeDraggable(main, topBar)

	--// Метка-подсказка в центре экрана (когда меню скрыто)
	local reopenHint = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screenGui,
	}, { corner(UDim.new(1, 0)) })

	local hintScale = create("UIScale", { Scale = 1, Parent = reopenHint })

	-- Мерцание метки. strong = заметное (при старте скрытым), иначе короткое и тусклое.
	-- Токен отменяет предыдущее мерцание, чтобы циклы не наслаивались.
	local blinkToken = 0
	local function blinkHint(strong)
		blinkToken += 1
		local token = blinkToken
		task.spawn(function()
			local pulses = strong and 4 or 2
			local brightT = strong and 0.05 or 0.45
			local dimT = strong and 0.8 or 0.85
			local dur = strong and 0.22 or 0.11
			local pulseScale = strong and 1.6 or 1.25

			for _ = 1, pulses do
				if token ~= blinkToken or not reopenHint.Visible then return end
				tween(reopenHint, { BackgroundTransparency = brightT },
					TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
				tween(hintScale, { Scale = pulseScale },
					TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
				task.wait(dur)
				if token ~= blinkToken then return end
				tween(reopenHint, { BackgroundTransparency = dimT },
					TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
				tween(hintScale, { Scale = 1 },
					TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
				task.wait(dur)
			end
			-- мерцание закончилось — метка "затухает" до еле заметной, не отвлекает
			if token == blinkToken and reopenHint.Visible then
				tween(reopenHint, { BackgroundTransparency = 0.82 }, TWEEN_MED)
				tween(hintScale, { Scale = 1 }, TWEEN_MED)
			end
		end)
	end

	--// Открытие/закрытие
	local isOpen = true
	local closeConn

	local function setOpen(open, animated, strongBlink)
		if isOpen == open and main.Visible == open then return end
		isOpen = open
		if closeConn then closeConn:Disconnect() closeConn = nil end

		reopenHint.Visible = not open
		if not open then
			blinkHint(strongBlink == true)
		else
			blinkToken += 1 -- отменяем мерцание
		end

		if open then
			main.Visible = true
			if animated then
				windowScale.Scale = 0.9
				tween(windowScale, { Scale = 1 }, TWEEN_POP)
			else
				windowScale.Scale = 1
			end
		else
			if animated then
				local t = tween(windowScale, { Scale = 0.9 }, TWEEN_FAST)
				closeConn = t.Completed:Connect(function()
					if not isOpen then main.Visible = false end
				end)
			else
				main.Visible = false
			end
		end
	end

	hideBtn.Activated:Connect(function()
		setOpen(false, true, false) -- ручное скрытие = слабое, короткое мерцание
	end)

	--// Двойной тап в зону центра экрана — открыть меню
	do
		local lastTapTime = 0
		local CENTER_ZONE_RADIUS = 90

		local function isInCenterZone(position)
			local camera = workspace.CurrentCamera
			if not camera then return false end
			local viewportSize = camera.ViewportSize
			local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
			return (Vector2.new(position.X, position.Y) - center).Magnitude <= CENTER_ZONE_RADIUS
		end

		UserInputService.InputEnded:Connect(function(input)
			if isOpen then return end
			if input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not isInCenterZone(input.Position) then return end

			local now = os.clock()
			if now - lastTapTime <= DOUBLE_TAP_MAX_GAP then
				lastTapTime = 0
				setOpen(true, true)
			else
				lastTapTime = now
				-- первый тап попал в зону — метка коротко подсвечивается как обратная связь
				tween(reopenHint, { BackgroundTransparency = 0.3 }, TWEEN_PRESS).Completed:Connect(function()
					if not isOpen then
						tween(reopenHint, { BackgroundTransparency = 0.82 }, TWEEN_MED)
					end
				end)
			end
		end)
	end

	--// Боковая панель
	local sidebar = create("Frame", {
		Size = UDim2.new(0, 150, 1, -45),
		Position = UDim2.fromOffset(0, 45),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(UDim.new(0, 12)) })

	create("Frame", { -- перекрываем правые скругления
		Size = UDim2.new(0, 12, 1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local tabButtonsHolder = create("Frame", {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		Parent = sidebar,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local content = create("Frame", {
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
		_setOpen = setOpen,
	}, UILib)

	-- Старт скрытым: заметное мерцание, чтобы юзер понял, куда тапать
	if startHidden then
		main.Visible = false
		isOpen = false
		reopenHint.Visible = true
		blinkHint(true)
	end

	return window
end

function UILib:Show()
	self._setOpen(true, true)
end

function UILib:Hide()
	self._setOpen(false, true, false)
end

function UILib:Toggle()
	if self._main.Visible then self:Hide() else self:Show() end
end

function UILib:Destroy()
	self._screenGui:Destroy()
end

function UILib:CreateTab(name)
	local tabButton = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = self._tabButtonsHolder,
	}, { corner(UDim.new(0, 8)) })

	local tabLabel = create("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.SubText,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = tabButton,
	})

	local tabPage = create("ScrollingFrame", {
		Size = UDim2.new(1, -32, 1, -24),
		Position = UDim2.fromOffset(16, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self._content,
	})

	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabPage,
	})

	addPressFeel(tabButton, 0.95)

	local tabObj = { _page = tabPage }

	local function setActive(active)
		if active then
			tween(tabButton, { BackgroundTransparency = 0 }, TWEEN_MED)
			tween(tabLabel, { TextColor3 = Theme.OnAccent }, TWEEN_MED)
		else
			tween(tabButton, { BackgroundTransparency = 1 }, TWEEN_MED)
			tween(tabLabel, { TextColor3 = Theme.SubText }, TWEEN_MED)
		end
		tabPage.Visible = active
	end
	tabObj._setActive = setActive

	tabButton.Activated:Connect(function()
		if self._activeTab == tabObj then return end
		if self._activeTab then
			self._activeTab._setActive(false)
		end
		self._activeTab = tabObj
		setActive(true)
	end)

	table.insert(self._tabs, tabObj)
	if not self._activeTab then
		self._activeTab = tabObj
		setActive(true)
	end

	local TabAPI = {}
	attachComponentAPI(TabAPI, tabPage)
	return TabAPI
end

-- Замораживаем публичную поверхность, чтобы её нельзя было подменить снаружи
-- (перехват callback'ов через monkey-patch методов библиотеки).
table.freeze(Theme)

return UILib
