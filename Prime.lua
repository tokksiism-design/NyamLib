--[[
	UILib v3 — GUI-библиотека для Roblox (Luau), оптимизирована под мобильные экзекуторы (Trigon Evo и т.п.)

	Стиль: светлый фон, чёрный акцент, скругления, дешёвые по FPS анимации (UIScale / прямое присваивание в драгах).

	Компоненты:
		Window, Tab, Section, Label, Button, Toggle, Slider,
		Dropdown (single / multi / MaxChoices),
		ColorPicker (Mode = "Picker" | "Palette" | "Both", опц. Alpha),
		Curve (редактор кривых как в ImGui: точки, drag, добавление тапом, удаление вытягиванием),
		Row (колонки как в ImGui)

	------------------------------------------------------------------
	ИСПОЛЬЗОВАНИЕ

	local UILib = loadstring(game:HttpGet("https://raw.githubusercontent.com/.../UILib.lua"))()

	local Window = UILib:CreateWindow({
		Name = "Моё окно",

		-- всё ниже опционально:
		StartHidden = false,          -- true: меню скрыто при старте, метка мерцает ярко
		Size = Vector2.new(560, 360), -- размер окна
		SidebarWidth = 150,
		CornerRadius = 14,
		Draggable = true,
		ToggleKey = Enum.KeyCode.RightShift, -- клавиша скрыть/показать (для ПК)

		Accent = Color3.fromRGB(20, 20, 20), -- быстрый способ сменить акцент
		Theme = {                            -- или точечно переопределить любые токены
			-- Background, Sidebar, Element, Accent, AccentHover, Text, OnAccent,
			-- SubText, Stroke, ToggleOff, SliderTrack
		},

		-- поведение метки-подсказки (когда меню скрыто):
		HintZoneRadius = 90,   -- радиус зоны двойного тапа от центра экрана (px)
		HintIdleTime = 2,      -- через сколько секунд метка полностью исчезает
		DoubleTapGap = 0.35,   -- макс. пауза между тапами двойного тапа
	})

	local Tab = Window:CreateTab("Главная")

	Tab:CreateSection("Основное")
	Tab:CreateLabel("Просто текст")

	Tab:CreateButton({ Name = "Кнопка", Callback = function() end })

	Tab:CreateToggle({ Name = "Тогл", Default = false, Callback = function(v) end })

	Tab:CreateSlider({
		Name = "Скорость", Min = 16, Max = 200, Step = 1, Default = 16, Suffix = "",
		Callback = function(v) end,
	})

	Tab:CreateDropdown({
		Name = "Режим",
		Options = { "Легко", "Средне", "Сложно" },
		Default = "Легко",
		Multi = false,      -- true = мультивыбор
		MaxChoices = 2,     -- лимит для Multi (nil = без лимита)
		Callback = function(sel) end, -- string, либо {string} при Multi
	})

	-- Палитра / пипетка (2 вида, как в ImGui):
	Tab:CreateColorPicker({
		Name = "Цвет ESP",
		Default = Color3.fromRGB(255, 80, 80),
		Mode = "Picker",   -- "Picker" = SV-квадрат + полоса оттенка
		                   -- "Palette" = сетка готовых цветов
		                   -- "Both" = и то и другое
		Alpha = false,     -- true: добавляется полоса прозрачности, колбэк получает (color, alpha)
		Palette = nil,     -- свой набор цветов для режима Palette: { Color3, ... }
		Callback = function(color, alpha) end,
	})

	-- Редактор кривых (как ImGui curve editor):
	local curve = Tab:CreateCurve({
		Name = "Кривая отдачи",
		Points = { {0, 0}, {0.5, 0.8}, {1, 0.2} }, -- {x, y}, x и y в диапазоне 0..1
		Interpolation = "Smooth", -- "Smooth" | "Linear"
		Height = 110,
		Callback = function(points) end, -- при любом изменении
	})
	print(curve:Evaluate(0.25)) -- значение кривой в точке x
	-- Управление: тап по пустому месту = добавить точку, drag = двигать,
	-- вытащить точку далеко за верх/низ поля = удалить (крайние не удаляются).

	-- Колонки (как ImGui columns / SameLine):
	local left, right = Tab:CreateRow(2)                 -- 2 равные колонки
	local a, b = Tab:CreateRow({ Weights = { 2, 1 } })   -- с весами 2:1
	left:CreateButton({ Name = "OK", Callback = function() end })
	right:CreateButton({ Name = "Отмена", Callback = function() end })

	Window:Show()  Window:Hide()  Window:Toggle()  Window:Destroy()

	------------------------------------------------------------------
	ЗАЩИТА (см. блок "Защита среды" ниже)

	Что реально сделано:
	- GUI монтируется через gethui() / syn.protect_gui / CoreGui — не виден в PlayerGui.
	- Имена всех инстансов рандомизированы посимвольно — не найти через FindFirstChild.
	- Все ссылки на глобалы/сервисы захвачены локально при загрузке: подмена
	  глобалов через getgenv() ПОСЛЕ загрузки библиотеки не перехватит наши вызовы.
	- Все колбэки и состояние живут в замыканиях (upvalues), не в атрибутах/значениях
	  инстансов — их не вытащить обходом дерева GUI через Dex.
	- Публичные таблицы заморожены (table.freeze) — методы нельзя monkey-patch'нуть,
	  чтобы перехватывать колбэки пользователей.
	- Колбэки исполняются через захваченные pcall/task.spawn — ошибка в колбэке
	  не роняет UI и не светит стектрейс с путями.
	- Сторожевой цикл следит, что ScreenGui не репарентнули/не удалили извне.

	Что НЕВОЗМОЖНО сделать из Lua (честно):
	- Спрятать исходник, который раздаётся через loadstring(HttpGet(...)) —
	  атакующий просто перехватит HttpGet. Единственная реальная мера — обфускация
	  (Prometheus / Luarmor) + свой лоадер с проверкой ключа НА СЕРВЕРЕ.
	- Защититься от hookmetamethod/hookfunction на уровне экзекутора атакующего —
	  его среда исполнения "выше" нашей. Мы можем только не облегчать ему жизнь.
]]

--// ====================================================================
--// Защита среды: захватываем всё нужное ЛОКАЛЬНО в момент загрузки.
--// После этого подмена глобалов (getgenv().pcall = ..., game.HttpGet-спуфы
--// и т.п.) не влияет на внутренние вызовы библиотеки.
--// ====================================================================

local _game = game
local _typeof = typeof
local _pcall = pcall
local _select = select
local _tostring = tostring
local _setmetatable = setmetatable
local _mathClamp = math.clamp
local _mathFloor = math.floor
local _mathMax = math.max
local _mathMin = math.min
local _mathRandom = math.random
-- math.atan2 объявлен устаревшим и на части сред отсутствует — фолбэк на math.atan(y, x)
local _mathAtan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local _mathDeg = math.deg
local _mathSqrt = math.sqrt
local _tableInsert = table.insert
local _tableRemove = table.remove
local _tableClear = table.clear
local _tableConcat = table.concat
local _tableCreate = table.create
local _tableSort = table.sort
local _tableUnpack = table.unpack
local _tableFreezeRaw = table.freeze
local _taskSpawn = task.spawn
local _taskDelay = task.delay
local _taskWait = task.wait
local _osClock = os.clock
local _InstanceNew = Instance.new
local _Color3fromRGB = Color3.fromRGB
local _Color3fromHSV = Color3.fromHSV
local _Color3toHSV = Color3.toHSV
local _UDim2new = UDim2.new
local _UDim2fromOffset = UDim2.fromOffset
local _UDim2fromScale = UDim2.fromScale
local _UDimNew = UDim.new
local _Vector2new = Vector2.new
local _TweenInfoNew = TweenInfo.new

local TweenService = _game:GetService("TweenService")
local UserInputService = _game:GetService("UserInputService")
local Players = _game:GetService("Players")
local RunService = _game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Захват метода Create у TweenService: даже если кто-то позже перепишет
-- getgenv().TweenService или обёртки — наша ссылка уже у нас.
local _tsCreate = TweenService.Create

--// БЕЗОПАСНАЯ заморозка таблиц.
--// КРИТИЧНО для мобильных экзекуторов (Trigon Evo и др.): их песочница может
--// навешивать на таблицы защищённые метатейблы, и тогда table.freeze кидает
--// "invalid argument #1 to 'freeze' (table has a protected metatable)".
--// На части экзекуторов table.freeze вообще отсутствует.
--// Заморозка — это ДОПОЛНИТЕЛЬНАЯ защита от monkey-patch, а не критичная
--// логика, поэтому она никогда не должна ронять UI: любая ошибка глотается,
--// таблица возвращается как есть.
local function _tableFreeze(t)
	if _tableFreezeRaw then
		_pcall(_tableFreezeRaw, t)
	end
	return t
end

--// ====================================================================
--// Тема (дефолт) и сборка темы под конкретное окно
--// ====================================================================

local DefaultTheme = {
	Background = _Color3fromRGB(255, 255, 255),
	Sidebar = _Color3fromRGB(245, 245, 245),
	Element = _Color3fromRGB(245, 245, 245),
	Accent = _Color3fromRGB(20, 20, 20),
	AccentHover = _Color3fromRGB(45, 45, 45),
	Text = _Color3fromRGB(20, 20, 20),
	OnAccent = _Color3fromRGB(255, 255, 255),
	SubText = _Color3fromRGB(120, 120, 120),
	Stroke = _Color3fromRGB(225, 225, 225),
	ToggleOff = _Color3fromRGB(210, 210, 210),
	SliderTrack = _Color3fromRGB(225, 225, 225),
}

local function buildTheme(overrides, accent)
	local T = {}
	for k, v in pairs(DefaultTheme) do
		T[k] = v
	end
	if _typeof(accent) == "Color3" then
		T.Accent = accent
		-- hover чуть светлее акцента
		local h, s, v = _Color3toHSV(accent)
		T.AccentHover = _Color3fromHSV(h, s, _mathClamp(v + 0.12, 0, 1))
	end
	if _typeof(overrides) == "table" then
		for k, v in pairs(overrides) do
			if DefaultTheme[k] ~= nil and _typeof(v) == "Color3" then
				T[k] = v
			end
		end
	end
	return T
end

-- Короткие и дешёвые твины: на мобиле с плавающим FPS длинные Back-анимации выглядят рвано.
local TWEEN_FAST = _TweenInfoNew(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED = _TweenInfoNew(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_POP = _TweenInfoNew(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_PRESS = _TweenInfoNew(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--// ====================================================================
--// Утилиты
--// ====================================================================

-- Рандомное имя, чтобы GUI/элементы нельзя было найти по имени.
local NAME_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function randomName()
	local out = _tableCreate(14)
	for i = 1, 14 do
		local n = _mathRandom(1, #NAME_CHARS)
		out[i] = NAME_CHARS:sub(n, n)
	end
	return _tableConcat(out)
end

local function create(className, props, children)
	local inst = _InstanceNew(className)
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
	return create("UICorner", { CornerRadius = radius or _UDimNew(0, 10) })
end

local function stroke(color, thickness)
	return create("UIStroke", { Color = color, Thickness = thickness or 1 })
end

local function tween(inst, props, info)
	local t = _tsCreate(TweenService, inst, info or TWEEN_FAST, props)
	t:Play()
	return t
end

-- Безопасный запуск пользовательского колбэка: ошибка юзера не роняет UI.
local function safeCall(fn, ...)
	if fn == nil then
		return
	end
	local args = { ... }
	local n = _select("#", ...)
	_taskSpawn(function()
		local ok = _pcall(fn, _tableUnpack(args, 1, n))
		-- глушим ошибку: не светим стектрейс с внутренними путями библиотеки
		if not ok then
			-- намеренно пусто
		end
	end)
end

-- Монтирование GUI максимально скрытно для конкретного экзекутора.
local function mountGui(screenGui)
	-- 1) gethui — самый безопасный вариант (Trigon Evo его поддерживает)
	local ok, hidden = _pcall(function()
		local g = (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
		return g
	end)
	if ok and _typeof(hidden) == "Instance" then
		screenGui.Parent = hidden
		return
	end
	-- 2) syn.protect_gui + CoreGui
	_pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(screenGui)
		end
	end)
	-- 3) CoreGui, если есть доступ
	local okCore = _pcall(function()
		screenGui.Parent = _game:GetService("CoreGui")
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

-- Невидимая кнопка-накладка: даёт нативный .Activated (корректно работает на тач).
local function addClickOverlay(parent, callback)
	local btn = create("TextButton", {
		Size = _UDim2fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = (parent.ZIndex or 1) + 5,
		Parent = parent,
	})
	btn.Activated:Connect(callback)
	return btn
end

-- Универсальное сопровождение пальца/мыши после InputBegan.
-- Подписки живут ТОЛЬКО во время драга — не копим коннекты (важно для долгих сессий на мобиле).
local function trackPointer(onMove, onEnd)
	local moveConn, endConn
	local function cleanup()
		if moveConn then moveConn:Disconnect() moveConn = nil end
		if endConn then endConn:Disconnect() endConn = nil end
	end
	moveConn = UserInputService.InputChanged:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseMovement
			or io.UserInputType == Enum.UserInputType.Touch then
			onMove(io.Position)
		end
	end)
	endConn = UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1
			or io.UserInputType == Enum.UserInputType.Touch then
			cleanup()
			if onEnd then onEnd(io.Position) end
		end
	end)
	return cleanup
end

local function makeDraggable(frame, dragHandle)
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local dragStart = input.Position
		local startPos = frame.Position
		trackPointer(function(pos)
			local delta = pos - dragStart
			frame.Position = _UDim2new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end)
	end)
end

--// ====================================================================
--// Компоненты. Все креаторы вынесены в билдер: одинаково работают
--// и на вкладке, и внутри колонок (CreateRow). T = тема окна.
--// ====================================================================

local attachComponentAPI -- forward declaration (нужно для рекурсии в CreateRow)

attachComponentAPI = function(api, container, T)

	----------------------------------------------------------------
	function api:CreateLabel(text)
		local label = create("TextLabel", {
			Size = _UDim2new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = text or "",
			TextColor3 = T.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = container,
		})
		local obj = {}
		function obj:Set(newText) label.Text = newText end
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	function api:CreateSection(text)
		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Parent = container,
		})
		create("TextLabel", {
			Size = _UDim2new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = string.upper(text or ""),
			TextColor3 = T.SubText,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = holder,
		})
		create("Frame", {
			Size = _UDim2new(1, 0, 0, 1),
			Position = _UDim2new(0, 0, 1, -4),
			BackgroundColor3 = T.Stroke,
			BorderSizePixel = 0,
			Parent = holder,
		})
	end

	----------------------------------------------------------------
	function api:CreateButton(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Button"
		local callback = cfg.Callback

		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, 36),
			BackgroundColor3 = T.Accent,
			BorderSizePixel = 0,
			Parent = container,
		}, { corner(_UDimNew(0, 8)) })

		local label = create("TextLabel", {
			Size = _UDim2fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = T.OnAccent,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			Parent = holder,
		})

		addPressFeel(holder, 0.95)
		addClickOverlay(holder, function()
			tween(holder, { BackgroundColor3 = T.AccentHover }, TWEEN_PRESS).Completed:Connect(function()
				tween(holder, { BackgroundColor3 = T.Accent }, TWEEN_MED)
			end)
			safeCall(callback)
		end)

		local obj = {}
		function obj:SetText(t) label.Text = t end
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	function api:CreateToggle(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Toggle"
		local state = cfg.Default == true
		local callback = cfg.Callback

		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, 40),
			BackgroundColor3 = T.Element,
			BorderSizePixel = 0,
			Parent = container,
		}, { corner(_UDimNew(0, 8)) })

		create("TextLabel", {
			Size = _UDim2new(1, -70, 1, 0),
			Position = _UDim2fromOffset(14, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local switchBg = create("Frame", {
			Size = _UDim2fromOffset(40, 22),
			Position = _UDim2new(1, -52, 0.5, -11),
			BackgroundColor3 = state and T.Accent or T.ToggleOff,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner(_UDimNew(1, 0)) })

		local knob = create("Frame", {
			Size = _UDim2fromOffset(18, 18),
			Position = state and _UDim2new(1, -20, 0.5, -9) or _UDim2new(0, 2, 0.5, -9),
			BackgroundColor3 = _Color3fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = switchBg,
		}, { corner(_UDimNew(1, 0)) })

		addPressFeel(holder, 0.97)

		local function render()
			tween(switchBg, { BackgroundColor3 = state and T.Accent or T.ToggleOff }, TWEEN_MED)
			tween(knob, {
				Position = state and _UDim2new(1, -20, 0.5, -9) or _UDim2new(0, 2, 0.5, -9),
			}, TWEEN_POP)
		end

		addClickOverlay(holder, function()
			state = not state
			render()
			safeCall(callback, state)
		end)

		local obj = {}
		function obj:Set(value, silent)
			state = value == true
			render()
			if not silent then safeCall(callback, state) end
		end
		function obj:Get() return state end
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	function api:CreateSlider(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Slider"
		local min = cfg.Min or 0
		local max = cfg.Max or 100
		local step = cfg.Step or 1
		local value = _mathClamp(cfg.Default or min, min, max)
		local suffix = cfg.Suffix or ""
		local callback = cfg.Callback

		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, 52),
			BackgroundColor3 = T.Element,
			BorderSizePixel = 0,
			Parent = container,
		}, { corner(_UDimNew(0, 8)) })

		create("TextLabel", {
			Size = _UDim2new(1, -90, 0, 18),
			Position = _UDim2fromOffset(14, 6),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local valueLabel = create("TextLabel", {
			Size = _UDim2new(0, 74, 0, 18),
			Position = _UDim2new(1, -88, 0, 6),
			BackgroundTransparency = 1,
			Text = _tostring(value) .. suffix,
			TextColor3 = T.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = holder,
		})

		local track = create("Frame", {
			Size = _UDim2new(1, -28, 0, 6),
			Position = _UDim2new(0, 14, 1, -18),
			BackgroundColor3 = T.SliderTrack,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner(_UDimNew(1, 0)) })

		local fill = create("Frame", {
			Size = _UDim2fromScale((value - min) / _mathMax(max - min, 1e-9), 1),
			BackgroundColor3 = T.Accent,
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(_UDimNew(1, 0)) })

		local knob = create("Frame", {
			AnchorPoint = _Vector2new(0.5, 0.5),
			Size = _UDim2fromOffset(16, 16),
			Position = _UDim2new(fill.Size.X.Scale, 0, 0.5, 0),
			BackgroundColor3 = _Color3fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(_UDimNew(1, 0)), stroke(T.Accent, 2) })

		-- Расширенная зона нажатия под палец (сам трек тонкий).
		local touchZone = create("TextButton", {
			Size = _UDim2new(1, 0, 0, 32),
			Position = _UDim2new(0, 0, 0.5, -16),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = track,
		})

		local function snap(v)
			return _mathClamp(_mathFloor((v - min) / step + 0.5) * step + min, min, max)
		end

		-- Во время драга — БЕЗ твинов (прямое присваивание), критично для мобильного FPS.
		local function applyValue(v, animated)
			value = v
			local alpha = (value - min) / _mathMax(max - min, 1e-9)
			valueLabel.Text = _tostring(value) .. suffix
			if animated then
				tween(fill, { Size = _UDim2fromScale(alpha, 1) }, TWEEN_MED)
				tween(knob, { Position = _UDim2new(alpha, 0, 0.5, 0) }, TWEEN_MED)
			else
				fill.Size = _UDim2fromScale(alpha, 1)
				knob.Position = _UDim2new(alpha, 0, 0.5, 0)
			end
		end

		local function setFromX(x)
			local rel = _mathClamp((x - track.AbsolutePosition.X) / _mathMax(track.AbsoluteSize.X, 1), 0, 1)
			local newValue = snap(min + rel * (max - min))
			if newValue ~= value then
				applyValue(newValue, false)
				safeCall(callback, value)
			end
		end

		touchZone.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			tween(knob, { Size = _UDim2fromOffset(20, 20) }, TWEEN_FAST)
			setFromX(input.Position.X)
			trackPointer(function(pos)
				setFromX(pos.X)
			end, function()
				tween(knob, { Size = _UDim2fromOffset(16, 16) }, TWEEN_POP)
			end)
		end)

		local obj = {}
		function obj:Set(v, silent)
			applyValue(snap(v), true)
			if not silent then safeCall(callback, value) end
		end
		function obj:Get() return value end
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	function api:CreateDropdown(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Dropdown"
		local options = cfg.Options or {}
		local multi = cfg.Multi == true
		local maxChoices = cfg.MaxChoices
		local callback = cfg.Callback

		local OPTION_H = 32
		local HEADER_H = 40

		local selected = {}
		if cfg.Default ~= nil then
			if _typeof(cfg.Default) == "table" then
				for _, v in ipairs(cfg.Default) do selected[v] = true end
			else
				selected[cfg.Default] = true
			end
		end

		local expanded = false

		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, HEADER_H),
			BackgroundColor3 = T.Element,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = container,
		}, { corner(_UDimNew(0, 8)) })

		create("TextLabel", {
			Size = _UDim2new(0.45, -14, 0, HEADER_H),
			Position = _UDim2fromOffset(14, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local selectionLabel = create("TextLabel", {
			Size = _UDim2new(0.55, -46, 0, HEADER_H),
			Position = _UDim2new(0.45, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = T.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local arrow = create("TextLabel", {
			Size = _UDim2fromOffset(20, HEADER_H),
			Position = _UDim2new(1, -32, 0, 0),
			BackgroundTransparency = 1,
			Text = "v",
			TextColor3 = T.SubText,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			Parent = holder,
		})

		local listFrame = create("Frame", {
			Size = _UDim2new(1, -16, 0, #options * OPTION_H),
			Position = _UDim2fromOffset(8, HEADER_H),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })

		local function selectedList()
			local out = {}
			for _, opt in ipairs(options) do
				if selected[opt] then _tableInsert(out, opt) end
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
			selectionLabel.Text = #list == 0 and "—" or _tableConcat(list, ", ")
		end

		local optionRows = {}

		local function refreshOptions()
			for opt, row in pairs(optionRows) do
				local isSel = selected[opt] == true
				tween(row.dot, { BackgroundColor3 = isSel and T.Accent or T.ToggleOff }, TWEEN_FAST)
				tween(row.label, { TextColor3 = isSel and T.Text or T.SubText }, TWEEN_FAST)
			end
		end

		local function fireCallback()
			if multi then
				safeCall(callback, selectedList())
			else
				safeCall(callback, selectedList()[1])
			end
		end

		local function setExpanded(open)
			expanded = open
			tween(holder, {
				Size = _UDim2new(1, 0, 0, open and (HEADER_H + #options * OPTION_H + 8) or HEADER_H),
			}, TWEEN_MED)
			tween(arrow, { Rotation = open and 180 or 0 }, TWEEN_MED)
		end

		for i, opt in ipairs(options) do
			local row = create("TextButton", {
				Size = _UDim2new(1, 0, 0, OPTION_H),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
				Parent = listFrame,
			})
			local dot = create("Frame", {
				Size = _UDim2fromOffset(10, 10),
				Position = _UDim2new(0, 8, 0.5, -5),
				BackgroundColor3 = selected[opt] and T.Accent or T.ToggleOff,
				BorderSizePixel = 0,
				Parent = row,
			}, { corner(_UDimNew(1, 0)) })
			local label = create("TextLabel", {
				Size = _UDim2new(1, -34, 1, 0),
				Position = _UDim2fromOffset(28, 0),
				BackgroundTransparency = 1,
				Text = opt,
				TextColor3 = selected[opt] and T.Text or T.SubText,
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
							tween(dot, { Size = _UDim2fromOffset(14, 14) }, TWEEN_PRESS).Completed:Connect(function()
								tween(dot, { Size = _UDim2fromOffset(10, 10) }, TWEEN_POP)
							end)
							return
						end
						selected[opt] = true
					end
				else
					_tableClear(selected)
					selected[opt] = true
					setExpanded(false)
				end
				refreshOptions()
				refreshHeader()
				fireCallback()
			end)
		end

		refreshHeader()

		local headerZone = create("TextButton", {
			Size = _UDim2new(1, 0, 0, HEADER_H),
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
			_tableClear(selected)
			if _typeof(values) == "table" then
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
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	-- ColorPicker: 2 вида, как в ImGui.
	--   Mode = "Picker"  — SV-квадрат + горизонтальная полоса оттенка (ImGui ColorPicker)
	--   Mode = "Palette" — сетка готовых ��вотчей (ImGui palette buttons)
	--   Mode = "Both"    — пикер + палитра под ним
	--   Alpha = true     — дополнительная полоса прозрачности; колбэк получает (color, alpha)
	function api:CreateColorPicker(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Color"
		local mode = cfg.Mode or "Picker"
		local useAlpha = cfg.Alpha == true
		local callback = cfg.Callback

		local defaultColor = _typeof(cfg.Default) == "Color3" and cfg.Default or _Color3fromRGB(20, 20, 20)
		local hue, sat, val = _Color3toHSV(defaultColor)
		local alpha = _mathClamp(cfg.DefaultAlpha or 1, 0, 1)

		local palette = cfg.Palette or {
			_Color3fromRGB(255, 255, 255), _Color3fromRGB(20, 20, 20),
			_Color3fromRGB(230, 60, 60), _Color3fromRGB(240, 130, 40),
			_Color3fromRGB(245, 200, 50), _Color3fromRGB(90, 200, 90),
			_Color3fromRGB(60, 180, 170), _Color3fromRGB(70, 140, 240),
			_Color3fromRGB(110, 90, 230), _Color3fromRGB(200, 90, 220),
			_Color3fromRGB(240, 110, 170), _Color3fromRGB(150, 110, 70),
			_Color3fromRGB(120, 120, 120), _Color3fromRGB(190, 190, 190),
		}

		local HEADER_H = 40
		local PAD = 14
		local SV_H = 110
		local BAR_H = 14
		local SWATCH = 26
		local GAP = 8

		local showPicker = (mode == "Picker" or mode == "Both")
		local showPalette = (mode == "Palette" or mode == "Both")

		-- расчёт высоты развёрнутого состояния
		local function paletteRows(width)
			local perRow = _mathMax(_mathFloor((width + GAP) / (SWATCH + GAP)), 1)
			return math.ceil(#palette / perRow)
		end

		local expanded = false

		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, HEADER_H),
			BackgroundColor3 = T.Element,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = container,
		}, { corner(_UDimNew(0, 8)) })

		create("TextLabel", {
			Size = _UDim2new(1, -80, 0, HEADER_H),
			Position = _UDim2fromOffset(PAD, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		-- превью текущего цвета в шапке
		local preview = create("Frame", {
			Size = _UDim2fromOffset(34, 22),
			Position = _UDim2new(1, -48, 0, (HEADER_H - 22) / 2),
			BackgroundColor3 = defaultColor,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner(_UDimNew(0, 6)), stroke(T.Stroke, 1) })

		local body = create("Frame", {
			Size = _UDim2new(1, -PAD * 2, 0, 0),
			Position = _UDim2fromOffset(PAD, HEADER_H),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = holder,
		})
		create("UIListLayout", {
			Padding = _UDimNew(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = body,
		})

		local function currentColor()
			return _Color3fromHSV(hue, sat, val)
		end

		local svBase, svCursor, hueCursor, alphaCursor, alphaGradient
		local paletteStrokes = {}

		local function refreshVisuals(animated)
			local c = currentColor()
			local info = animated and TWEEN_FAST or nil
			if animated then
				tween(preview, { BackgroundColor3 = c }, info)
			else
				preview.BackgroundColor3 = c
			end
			if svBase then
				svBase.BackgroundColor3 = _Color3fromHSV(hue, 1, 1)
				svCursor.Position = _UDim2new(sat, 0, 1 - val, 0)
			end
			if hueCursor then
				hueCursor.Position = _UDim2new(hue, 0, 0.5, 0)
			end
			if alphaCursor then
				alphaCursor.Position = _UDim2new(alpha, 0, 0.5, 0)
				alphaGradient.Color = ColorSequence.new(c, c)
			end
		end

		local function fire()
			if useAlpha then
				safeCall(callback, currentColor(), alpha)
			else
				safeCall(callback, currentColor())
			end
		end

		--------------------------------------------------------
		-- Вид 1: SV-квадрат + полоса оттенка (+ альфа)
		if showPicker then
			-- SV-квадрат: базовый цвет = чистый hue, поверх — белый градиент
			-- слева и чёрный градиент снизу (стандартная ImGui-схема).
			svBase = create("Frame", {
				Size = _UDim2new(1, 0, 0, SV_H),
				BackgroundColor3 = _Color3fromHSV(hue, 1, 1),
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Parent = body,
			}, { corner(_UDimNew(0, 8)) })

			local whiteOverlay = create("Frame", {
				Size = _UDim2fromScale(1, 1),
				BackgroundColor3 = _Color3fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				Parent = svBase,
			}, { corner(_UDimNew(0, 8)) })
			create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = whiteOverlay,
			})

			local blackOverlay = create("Frame", {
				Size = _UDim2fromScale(1, 1),
				BackgroundColor3 = _Color3fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = svBase,
			}, { corner(_UDimNew(0, 8)) })
			create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Parent = blackOverlay,
			})

			svCursor = create("Frame", {
				AnchorPoint = _Vector2new(0.5, 0.5),
				Size = _UDim2fromOffset(14, 14),
				Position = _UDim2new(sat, 0, 1 - val, 0),
				BackgroundColor3 = _Color3fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = svBase,
			}, { corner(_UDimNew(1, 0)), stroke(_Color3fromRGB(20, 20, 20), 2) })

			local svZone = create("TextButton", {
				Size = _UDim2fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 4,
				Parent = svBase,
			})
			svZone.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				local function apply(pos)
					local relX = _mathClamp((pos.X - svBase.AbsolutePosition.X) / _mathMax(svBase.AbsoluteSize.X, 1), 0, 1)
					local relY = _mathClamp((pos.Y - svBase.AbsolutePosition.Y) / _mathMax(svBase.AbsoluteSize.Y, 1), 0, 1)
					sat = relX
					val = 1 - relY
					refreshVisuals(false) -- прямое присваивание в драге, без твинов
					fire()
				end
				apply(input.Position)
				trackPointer(apply)
			end)

			-- Полоса оттенка (радуга через UIGradient)
			local hueBar = create("Frame", {
				Size = _UDim2new(1, 0, 0, BAR_H),
				BackgroundColor3 = _Color3fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Parent = body,
			}, { corner(_UDimNew(1, 0)) })
			create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, _Color3fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(1 / 6, _Color3fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(2 / 6, _Color3fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(3 / 6, _Color3fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(4 / 6, _Color3fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(5 / 6, _Color3fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1, _Color3fromRGB(255, 0, 0)),
				}),
				Parent = hueBar,
			})
			hueCursor = create("Frame", {
				AnchorPoint = _Vector2new(0.5, 0.5),
				Size = _UDim2fromOffset(10, BAR_H + 6),
				Position = _UDim2new(hue, 0, 0.5, 0),
				BackgroundColor3 = _Color3fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = hueBar,
			}, { corner(_UDimNew(0, 4)), stroke(_Color3fromRGB(20, 20, 20), 1) })

			local hueZone = create("TextButton", {
				Size = _UDim2new(1, 0, 0, BAR_H + 18),
				Position = _UDim2new(0, 0, 0.5, -(BAR_H + 18) / 2),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 4,
				Parent = hueBar,
			})
			hueZone.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				local function apply(pos)
					hue = _mathClamp((pos.X - hueBar.AbsolutePosition.X) / _mathMax(hueBar.AbsoluteSize.X, 1), 0, 1)
					refreshVisuals(false)
					fire()
				end
				apply(input.Position)
				trackPointer(apply)
			end)

			-- Полоса альфы (опционально)
			if useAlpha then
				local alphaBar = create("Frame", {
					Size = _UDim2new(1, 0, 0, BAR_H),
					BackgroundColor3 = _Color3fromRGB(255, 255, 255),
					BorderSizePixel = 0,
					LayoutOrder = 3,
					Parent = body,
				}, { corner(_UDimNew(1, 0)), stroke(T.Stroke, 1) })

				local alphaFill = create("Frame", {
					Size = _UDim2fromScale(1, 1),
					BackgroundColor3 = _Color3fromRGB(255, 255, 255),
					BorderSizePixel = 0,
					Parent = alphaBar,
				}, { corner(_UDimNew(1, 0)) })
				alphaGradient = create("UIGradient", {
					Color = ColorSequence.new(currentColor(), currentColor()),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0),
					}),
					Parent = alphaFill,
				})
				alphaFill.BackgroundColor3 = _Color3fromRGB(255, 255, 255)

				alphaCursor = create("Frame", {
					AnchorPoint = _Vector2new(0.5, 0.5),
					Size = _UDim2fromOffset(10, BAR_H + 6),
					Position = _UDim2new(alpha, 0, 0.5, 0),
					BackgroundColor3 = _Color3fromRGB(255, 255, 255),
					BorderSizePixel = 0,
					ZIndex = 3,
					Parent = alphaBar,
				}, { corner(_UDimNew(0, 4)), stroke(_Color3fromRGB(20, 20, 20), 1) })

				local alphaZone = create("TextButton", {
					Size = _UDim2new(1, 0, 0, BAR_H + 18),
					Position = _UDim2new(0, 0, 0.5, -(BAR_H + 18) / 2),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 4,
					Parent = alphaBar,
				})
				alphaZone.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1
						and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					local function apply(pos)
						alpha = _mathClamp((pos.X - alphaBar.AbsolutePosition.X) / _mathMax(alphaBar.AbsoluteSize.X, 1), 0, 1)
						refreshVisuals(false)
						fire()
					end
					apply(input.Position)
					trackPointer(apply)
				end)
			end
		end

		--------------------------------------------------------
		-- Вид 2: сетка свотчей (палитра)
		if showPalette then
			local grid = create("Frame", {
				Size = _UDim2new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 10,
				Parent = body,
			})
			create("UIGridLayout", {
				CellSize = _UDim2fromOffset(SWATCH, SWATCH),
				CellPadding = _UDim2fromOffset(GAP, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = grid,
			})

			for i, c in ipairs(palette) do
				local swatch = create("TextButton", {
					BackgroundColor3 = c,
					Text = "",
					AutoButtonColor = false,
					BorderSizePixel = 0,
					LayoutOrder = i,
					Parent = grid,
				}, { corner(_UDimNew(0, 6)) })
				local sw = stroke(T.Stroke, 1)
				sw.Parent = swatch
				paletteStrokes[i] = { stroke = sw, color = c }

				addPressFeel(swatch, 0.88)
				swatch.Activated:Connect(function()
					hue, sat, val = _Color3toHSV(c)
					refreshVisuals(true)
					-- подсветка выбранного свотча
					for _, entry in ipairs(paletteStrokes) do
						entry.stroke.Color = T.Stroke
						entry.stroke.Thickness = 1
					end
					sw.Color = T.Accent
					sw.Thickness = 2
					fire()
				end)
			end
		end

		--------------------------------------------------------
		-- Развёртка/свёртка
		local function bodyHeight()
			local h = 0
			if showPicker then
				h += SV_H + GAP + BAR_H
				if useAlpha then h += GAP + BAR_H end
			end
			if showPalette then
				local width = _mathMax(holder.AbsoluteSize.X - PAD * 2, 100)
				h += (showPicker and GAP or 0) + paletteRows(width) * (SWATCH + GAP)
			end
			return h
		end

		local function setExpanded(open)
			expanded = open
			tween(holder, {
				Size = _UDim2new(1, 0, 0, open and (HEADER_H + bodyHeight() + PAD) or HEADER_H),
			}, TWEEN_MED)
		end

		local headerZone = create("TextButton", {
			Size = _UDim2new(1, 0, 0, HEADER_H),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = holder,
		})
		headerZone.Activated:Connect(function()
			setExpanded(not expanded)
		end)

		refreshVisuals(false)

		local obj = {}
		function obj:Set(color, newAlpha, silent)
			if _typeof(color) == "Color3" then
				hue, sat, val = _Color3toHSV(color)
			end
			if newAlpha ~= nil then
				alpha = _mathClamp(newAlpha, 0, 1)
			end
			refreshVisuals(true)
			if not silent then fire() end
		end
		function obj:Get()
			if useAlpha then return currentColor(), alpha end
			return currentColor()
		end
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	-- Редактор кривых, как в ImGui:
	--   тап по пустому месту поля — добавить точку
	--   drag точки — переместить (x зажат между соседями, крайние точки двигаются только по y)
	--   вытащить точку далеко за верх/низ поля и отпустить — удалить (кроме крайних)
	--   Interpolation = "Smooth" (Catmull-Rom) | "Linear"
	function api:CreateCurve(cfg)
		cfg = cfg or {}
		local name = cfg.Name or "Curve"
		local interpolation = cfg.Interpolation or "Smooth"
		local canvasH = cfg.Height or 110
		local callback = cfg.Callback

		local HEADER_H = 30
		local PAD = 14
		local REMOVE_DIST = 46 -- на сколько px вытащить точку за поле, чтобы удалить
		local SAMPLES_PER_SEG = interpolation == "Smooth" and 6 or 1
		local MAX_POINTS = 12

		-- точки: массив {x, y}, x/y в 0..1, отсортированы по x
		local points = {}
		do
			local src = cfg.Points or { { 0, 0 }, { 1, 1 } }
			for _, p in ipairs(src) do
				_tableInsert(points, { _mathClamp(p[1] or 0, 0, 1), _mathClamp(p[2] or 0, 0, 1) })
			end
			_tableSort(points, function(a, b) return a[1] < b[1] end)
			-- гарантируем крайние точки
			if points[1][1] > 0 then _tableInsert(points, 1, { 0, points[1][2] }) end
			if points[#points][1] < 1 then _tableInsert(points, { 1, points[#points][2] }) end
		end

		local holder = create("Frame", {
			Size = _UDim2new(1, 0, 0, HEADER_H + canvasH + PAD),
			BackgroundColor3 = T.Element,
			BorderSizePixel = 0,
			Parent = container,
		}, { corner(_UDimNew(0, 8)) })

		create("TextLabel", {
			Size = _UDim2new(1, -PAD * 2, 0, HEADER_H),
			Position = _UDim2fromOffset(PAD, 2),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})

		local canvas = create("Frame", {
			Size = _UDim2new(1, -PAD * 2, 0, canvasH),
			Position = _UDim2fromOffset(PAD, HEADER_H),
			BackgroundColor3 = T.Background,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Parent = holder,
		}, { corner(_UDimNew(0, 8)), stroke(T.Stroke, 1) })

		-- сетка: 3 горизонтальные + 3 вертикальные тонкие линии
		for i = 1, 3 do
			create("Frame", {
				Size = _UDim2new(1, 0, 0, 1),
				Position = _UDim2new(0, 0, i * 0.25, 0),
				BackgroundColor3 = T.Stroke,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Parent = canvas,
			})
			create("Frame", {
				Size = _UDim2new(0, 1, 1, 0),
				Position = _UDim2new(i * 0.25, 0, 0, 0),
				BackgroundColor3 = T.Stroke,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Parent = canvas,
			})
		end

		--------------------------------------------------------
		-- Интерполяция
		local function evaluate(x)
			x = _mathClamp(x, 0, 1)
			-- найти сегмент
			local i = 1
			while i < #points and points[i + 1][1] < x do
				i += 1
			end
			if i >= #points then
				return points[#points][2]
			end
			local p1, p2 = points[i], points[i + 1]
			local dx = p2[1] - p1[1]
			if dx <= 1e-9 then return p2[2] end
			local t = (x - p1[1]) / dx

			if interpolation == "Linear" then
				return p1[2] + (p2[2] - p1[2]) * t
			end

			-- Catmull-Rom (Hermite по y(x)) с зажатыми краями
			local p0 = points[_mathMax(i - 1, 1)]
			local p3 = points[_mathMin(i + 2, #points)]
			local m1 = (p2[2] - p0[2]) / _mathMax(p2[1] - p0[1], 1e-9)
			local m2 = (p3[2] - p1[2]) / _mathMax(p3[1] - p1[1], 1e-9)
			local t2, t3 = t * t, t * t * t
			local y = (2 * t3 - 3 * t2 + 1) * p1[2]
				+ (t3 - 2 * t2 + t) * dx * m1
				+ (-2 * t3 + 3 * t2) * p2[2]
				+ (t3 - t2) * dx * m2
			return _mathClamp(y, 0, 1)
		end

		--------------------------------------------------------
		-- Рендер кривой: пул тонких повёрнутых фреймов-сегментов.
		-- Перерисовка ТОЛЬКО при изменении точек (не каждый кадр) — дёшево для мобилы.
		local segmentPool = {}
		local pointDots = {}

		local function getSegment(idx)
			local seg = segmentPool[idx]
			if not seg then
				seg = create("Frame", {
					AnchorPoint = _Vector2new(0.5, 0.5),
					BackgroundColor3 = T.Accent,
					BorderSizePixel = 0,
					ZIndex = 2,
					Parent = canvas,
				})
				segmentPool[idx] = seg
			end
			seg.Visible = true
			return seg
		end

		local lastRedraw = 0
		local redrawQueued = false

		local function redrawNow()
			lastRedraw = _osClock()
			local W = _mathMax(canvas.AbsoluteSize.X, 1)
			local H = _mathMax(canvas.AbsoluteSize.Y, 1)

			-- сэмплы вдоль кривой
			local xs = {}
			for i = 1, #points - 1 do
				local x1, x2 = points[i][1], points[i + 1][1]
				for s = 0, SAMPLES_PER_SEG - 1 do
					_tableInsert(xs, x1 + (x2 - x1) * (s / SAMPLES_PER_SEG))
				end
			end
			_tableInsert(xs, 1)

			local used = 0
			for i = 1, #xs - 1 do
				local ax, ay = xs[i] * W, (1 - evaluate(xs[i])) * H
				local bx, by = xs[i + 1] * W, (1 - evaluate(xs[i + 1])) * H
				local dxp, dyp = bx - ax, by - ay
				local len = _mathSqrt(dxp * dxp + dyp * dyp)
				if len > 0.5 then
					used += 1
					local seg = getSegment(used)
					seg.Position = _UDim2fromOffset((ax + bx) / 2, (ay + by) / 2)
					seg.Size = _UDim2fromOffset(len + 1, 2)
					seg.Rotation = _mathDeg(_mathAtan2(dyp, dxp))
				end
			end
			-- прячем лишние сегменты из пула
			for i = used + 1, #segmentPool do
				segmentPool[i].Visible = false
			end

			-- точки
			for i, dot in ipairs(pointDots) do
				local p = points[i]
				if p then
					dot.Visible = true
					dot.Position = _UDim2new(p[1], 0, p[2] and (1 - p[2]) or 0, 0)
				else
					dot.Visible = false
				end
			end
		end

		-- Троттлинг перерисовки: во время драга не чаще ~30 раз/сек.
		local function redraw()
			local now = _osClock()
			if now - lastRedraw >= 0.033 then
				redrawNow()
			elseif not redrawQueued then
				redrawQueued = true
				_taskDelay(0.033, function()
					redrawQueued = false
					redrawNow()
				end)
			end
		end

		local function fireChanged()
			-- отдаём копию, чтобы юзер не мог мутировать наше состояние напрямую
			local copy = {}
			for _, p in ipairs(points) do
				_tableInsert(copy, { p[1], p[2] })
			end
			safeCall(callback, copy)
		end

		--------------------------------------------------------
		-- Точки: создание, drag, удаление
		local rebuildDots -- forward

		local function makeDot(index)
			local dot = create("TextButton", {
				AnchorPoint = _Vector2new(0.5, 0.5),
				Size = _UDim2fromOffset(14, 14),
				BackgroundColor3 = _Color3fromRGB(255, 255, 255),
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 5,
				Parent = canvas,
			}, { corner(_UDimNew(1, 0)), stroke(T.Accent, 2) })

			-- расширенная тач-зона
			local zone = create("TextButton", {
				AnchorPoint = _Vector2new(0.5, 0.5),
				Size = _UDim2fromOffset(30, 30),
				Position = _UDim2fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 6,
				Parent = dot,
			})

			zone.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				-- индекс ищем на момент нажатия (мог сдвинуться после вставок/удалений)
				local myIndex
				for i, d in ipairs(pointDots) do
					if d == dot then myIndex = i break end
				end
				if not myIndex then return end

				local isEndpoint = (myIndex == 1 or myIndex == #points)
				tween(dot, { Size = _UDim2fromOffset(18, 18) }, TWEEN_FAST)

				local removing = false

				trackPointer(function(pos)
					local W = _mathMax(canvas.AbsoluteSize.X, 1)
					local H = _mathMax(canvas.AbsoluteSize.Y, 1)
					local relX = (pos.X - canvas.AbsolutePosition.X) / W
					local relYraw = pos.Y - canvas.AbsolutePosition.Y
					local relY = _mathClamp(relYraw / H, 0, 1)

					-- зажимаем x между соседями (не даём точкам меняться местами)
					if isEndpoint then
						relX = points[myIndex][1] -- крайние двигаются только по y
					else
						local lo = points[myIndex - 1][1] + 0.02
						local hi = points[myIndex + 1][1] - 0.02
						relX = _mathClamp(relX, lo, hi)
					end

					points[myIndex][1] = relX
					points[myIndex][2] = 1 - relY

					-- визуальный сигнал "будет удалена": точка тускнеет
					if not isEndpoint then
						local outside = relYraw < -REMOVE_DIST or relYraw > H + REMOVE_DIST
						if outside ~= removing then
							removing = outside
							tween(dot, {
								BackgroundTransparency = removing and 0.6 or 0,
							}, TWEEN_FAST)
						end
					end

					redraw()
				end, function(pos)
					tween(dot, { Size = _UDim2fromOffset(14, 14), BackgroundTransparency = 0 }, TWEEN_POP)
					local H = _mathMax(canvas.AbsoluteSize.Y, 1)
					local relYraw = pos.Y - canvas.AbsolutePosition.Y
					if not isEndpoint and (relYraw < -REMOVE_DIST or relYraw > H + REMOVE_DIST) then
						_tableRemove(points, myIndex)
						rebuildDots()
					end
					redrawNow()
					fireChanged()
				end)
			end)

			return dot
		end

		rebuildDots = function()
			for _, d in ipairs(pointDots) do
				d:Destroy()
			end
			_tableClear(pointDots)
			for i = 1, #points do
				pointDots[i] = makeDot(i)
			end
		end

		-- Тап по пустому месту поля — добавить точку (с pop-анимацией)
		local canvasZone = create("TextButton", {
			Size = _UDim2fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 1,
			Parent = canvas,
		})
		canvasZone.Activated:Connect(function()
			if #points >= MAX_POINTS then return end
			local mouse = UserInputService:GetMouseLocation()
			local W = _mathMax(canvas.AbsoluteSize.X, 1)
			local H = _mathMax(canvas.AbsoluteSize.Y, 1)
			-- GetMouseLocation даёт координаты с учётом inset; AbsolutePosition GUI при
			-- IgnoreGuiInset тоже в этих координатах, так что напрямую сопоставимо
			local relX = _mathClamp((mouse.X - canvas.AbsolutePosition.X) / W, 0, 1)
			local relY = _mathClamp((mouse.Y - canvas.AbsolutePosition.Y) / H, 0, 1)

			-- вставка с сохранением сортировки по x
			local newPoint = { relX, 1 - relY }
			local insertAt = #points + 1
			for i, p in ipairs(points) do
				if p[1] > relX then
					insertAt = i
					break
				end
			end
			-- не дублируем x впритык к соседям
			if insertAt > 1 and relX - points[insertAt - 1][1] < 0.03 then return end
			if insertAt <= #points and points[insertAt][1] - relX < 0.03 then return end

			_tableInsert(points, insertAt, newPoint)
			rebuildDots()
			redrawNow()

			-- pop-анимация новой точки
			local dot = pointDots[insertAt]
			if dot then
				local sc = create("UIScale", { Scale = 0.3, Parent = dot })
				tween(sc, { Scale = 1 }, TWEEN_POP).Completed:Connect(function()
					sc:Destroy()
				end)
			end
			fireChanged()
		end)

		rebuildDots()
		-- первая отрисовка после того, как layout посчитает AbsoluteSize
		_taskDelay(0, redrawNow)
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(redrawNow)

		local obj = {}
		function obj:Evaluate(x)
			return evaluate(x)
		end
		function obj:GetPoints()
			local copy = {}
			for _, p in ipairs(points) do
				_tableInsert(copy, { p[1], p[2] })
			end
			return copy
		end
		function obj:SetPoints(newPoints, silent)
			_tableClear(points)
			for _, p in ipairs(newPoints or {}) do
				_tableInsert(points, { _mathClamp(p[1] or 0, 0, 1), _mathClamp(p[2] or 0, 0, 1) })
			end
			if #points < 2 then
				_tableInsert(points, { 0, 0 })
				_tableInsert(points, { 1, 1 })
			end
			_tableSort(points, function(a, b) return a[1] < b[1] end)
			rebuildDots()
			redrawNow()
			if not silent then fireChanged() end
		end
		return _tableFreeze(obj)
	end

	----------------------------------------------------------------
	-- Колонки как в ImGui: local a, b, c = Tab:CreateRow(3)
	-- или с весами: Tab:CreateRow({ Weights = { 2, 1 } })
	function api:CreateRow(cfg)
		local weights
		if _typeof(cfg) == "table" then
			weights = cfg.Weights
			if not weights then
				weights = _tableCreate(cfg.Columns or 2, 1)
			end
		else
			weights = _tableCreate(cfg or 2, 1)
		end

		local n = #weights
		local total = 0
		for _, w in ipairs(weights) do total += w end
		local GAP = 8

		local row = create("Frame", {
			Size = _UDim2new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = container,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = _UDimNew(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = row,
		})

		local columns = {}
		for i = 1, n do
			local colFrame = create("Frame", {
				Size = _UDim2new(weights[i] / total, -_mathFloor(GAP * (n - 1) / n), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = row,
			})
			create("UIListLayout", {
				Padding = _UDimNew(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = colFrame,
			})
			local colApi = {}
			attachComponentAPI(colApi, colFrame, T)
			columns[i] = _tableFreeze(colApi)
		end

		return _tableUnpack(columns)
	end
end

--// ====================================================================
--// Окно
--// ====================================================================

local UILib = {}
UILib.__index = UILib
UILib.Version = "3.0.0"

function UILib:CreateWindow(config)
	config = config or {}
	local windowName = config.Name or "UILib"
	local startHidden = config.StartHidden == true

	local T = buildTheme(config.Theme, config.Accent)
	_tableFreeze(T)

	local winW, winH = 560, 360
	if _typeof(config.Size) == "Vector2" then
		winW, winH = config.Size.X, config.Size.Y
	end
	local sidebarW = config.SidebarWidth or 150
	local cornerR = config.CornerRadius or 14
	local hintZoneRadius = config.HintZoneRadius or 90
	local hintIdleTime = config.HintIdleTime or 2
	local doubleTapGap = config.DoubleTapGap or 0.35
	local draggable = config.Draggable ~= false

	local screenGui = create("ScreenGui", {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})
	mountGui(screenGui)

	local main = create("Frame", {
		Size = _UDim2fromOffset(winW, winH),
		Position = _UDim2new(0.5, -winW / 2, 0.5, -winH / 2),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		corner(_UDimNew(0, cornerR)),
		stroke(T.Stroke, 1),
	})

	-- Анимация окна через UIScale — дёшево и не ломает layout детей.
	local windowScale = create("UIScale", { Scale = 1, Parent = main })

	--// Верхняя панель
	local topBar = create("Frame", {
		Size = _UDim2new(1, 0, 0, 44),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(_UDimNew(0, cornerR)) })

	create("Frame", { -- перекрываем нижние скругления шапки
		Size = _UDim2new(1, 0, 0, cornerR),
		Position = _UDim2new(0, 0, 1, -cornerR),
		BackgroundColor3 = T.Background,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	create("TextLabel", {
		Size = _UDim2new(1, -60, 1, 0),
		Position = _UDim2fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = windowName,
		TextColor3 = T.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topBar,
	})

	local hideBtn = create("TextButton", {
		Size = _UDim2fromOffset(30, 30),
		Position = _UDim2new(1, -38, 0.5, -15),
		BackgroundColor3 = T.Sidebar,
		Text = "—",
		TextColor3 = T.Text,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = topBar,
	}, { corner(_UDimNew(0, 8)) })
	addPressFeel(hideBtn, 0.9)

	create("Frame", {
		Size = _UDim2new(1, 0, 0, 1),
		Position = _UDim2new(0, 0, 1, 0),
		BackgroundColor3 = T.Stroke,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	if draggable then
		makeDraggable(main, topBar)
	end

	--// ================================================================
	--// Метка-подсказка (когда меню скрыто)
	--//
	--// Жизненный цикл:
	--//   меню скрыли -> мерцание (яркое при StartHidden, короткое тусклое при ручном)
	--//   -> метка висит тускло hintIdleTime секунд -> полностью исчезает
	--//   тап в зону центра, когда метка невидима -> метка появляется ярко
	--//   -> если второй тап не пришёл за doubleTapGap -> быстро исчезает
	--//   двойной тап -> меню открывается
	--// ================================================================

	local reopenHint = create("Frame", {
		AnchorPoint = _Vector2new(0.5, 0.5),
		Position = _UDim2new(0.5, 0, 0.5, 0),
		Size = _UDim2fromOffset(12, 12),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screenGui,
	}, { corner(_UDimNew(1, 0)) })

	local hintScale = create("UIScale", { Scale = 1, Parent = reopenHint })

	local isOpen = true

	-- Один токен на все фазы жизни метки: любое новое действие отменяет
	-- запланированные старые (мерцания, отложенные скрытия) — ничего не наслаивается.
	local hintToken = 0

	local function hintBump()
		hintToken += 1
		return hintToken
	end

	local function hintFadeOut(token, fast)
		-- плавное полное исчезновение метки
		if token ~= hintToken then return end
		local dur = fast and 0.15 or 0.35
		tween(reopenHint, { BackgroundTransparency = 1 },
			_TweenInfoNew(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		tween(hintScale, { Scale = 0.6 },
			_TweenInfoNew(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		_taskDelay(dur, function()
			if token == hintToken then
				reopenHint.Visible = false
			end
		end)
	end

	local function hintScheduleIdleHide(token)
		-- через hintIdleTime секунд тихо убираем метку совсем
		_taskDelay(hintIdleTime, function()
			hintFadeOut(token, false)
		end)
	end

	-- Мерцание. strong = заметное (при старте скрытым), иначе короткое и тусклое.
	local function hintBlink(strong)
		local token = hintBump()
		reopenHint.Visible = true
		_taskSpawn(function()
			local pulses = strong and 4 or 2
			local brightT = strong and 0.05 or 0.45
			local dimT = strong and 0.75 or 0.85
			local dur = strong and 0.22 or 0.1
			local pulseScale = strong and 1.6 or 1.2

			for _ = 1, pulses do
				if token ~= hintToken then return end
				tween(reopenHint, { BackgroundTransparency = brightT },
					_TweenInfoNew(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
				tween(hintScale, { Scale = pulseScale },
					_TweenInfoNew(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
				_taskWait(dur)
				if token ~= hintToken then return end
				tween(reopenHint, { BackgroundTransparency = dimT },
					_TweenInfoNew(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
				tween(hintScale, { Scale = 1 },
					_TweenInfoNew(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
				_taskWait(dur)
			end
			-- после мерцания: висим тускло hintIdleTime секунд, затем исчезаем
			if token == hintToken then
				tween(reopenHint, { BackgroundTransparency = 0.8 }, TWEEN_MED)
				tween(hintScale, { Scale = 1 }, TWEEN_MED)
				hintScheduleIdleHide(token)
			end
		end)
	end

	-- Показ метки после тапа в зону (яркая вспышка + ожидание второго тапа)
	local function hintShowForTap()
		local token = hintBump()
		reopenHint.Visible = true
		tween(reopenHint, { BackgroundTransparency = 0.15 }, TWEEN_PRESS)
		tween(hintScale, { Scale = 1.3 }, TWEEN_PRESS)
		-- если второй тап не придёт — быстро прячем
		_taskDelay(doubleTapGap + 0.05, function()
			hintFadeOut(token, true)
		end)
	end

	local function hintHideInstant()
		hintBump()
		reopenHint.Visible = false
		reopenHint.BackgroundTransparency = 1
	end

	--// Открытие/закрытие окна
	local closeConn

	local function setOpen(open, animated, strongBlink)
		if isOpen == open and main.Visible == open then return end
		isOpen = open
		if closeConn then closeConn:Disconnect() closeConn = nil end

		if not open then
			hintBlink(strongBlink == true)
		else
			hintHideInstant()
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

		local function isInCenterZone(position)
			local camera = workspace.CurrentCamera
			if not camera then return false end
			local viewportSize = camera.ViewportSize
			local center = _Vector2new(viewportSize.X / 2, viewportSize.Y / 2)
			return (_Vector2new(position.X, position.Y) - center).Magnitude <= hintZoneRadius
		end

		UserInputService.InputEnded:Connect(function(input)
			if isOpen then return end
			if input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not isInCenterZone(input.Position) then return end

			local now = _osClock()
			if now - lastTapTime <= doubleTapGap then
				lastTapTime = 0
				setOpen(true, true)
			else
				lastTapTime = now
				-- первый тап: метка появляется/вспыхивает и ждёт второй тап
				hintShowForTap()
			end
		end)
	end

	--// Клавиша-тоггл (для ПК)
	if config.ToggleKey then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == config.ToggleKey then
				setOpen(not isOpen, true, false)
			end
		end)
	end

	--// Боковая панель
	local sidebar = create("Frame", {
		Size = _UDim2new(0, sidebarW, 1, -45),
		Position = _UDim2fromOffset(0, 45),
		BackgroundColor3 = T.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(_UDimNew(0, 12)) })

	create("Frame", { -- перекрываем правые скругления
		Size = _UDim2new(0, 12, 1, 0),
		Position = _UDim2new(1, -12, 0, 0),
		BackgroundColor3 = T.Sidebar,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local tabButtonsHolder = create("Frame", {
		Size = _UDim2new(1, -16, 1, -16),
		Position = _UDim2fromOffset(8, 8),
		BackgroundTransparency = 1,
		Parent = sidebar,
	}, {
		create("UIListLayout", { Padding = _UDimNew(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local content = create("Frame", {
		Size = _UDim2new(1, -sidebarW, 1, -45),
		Position = _UDim2fromOffset(sidebarW, 45),
		BackgroundTransparency = 1,
		Parent = main,
	})

	--// Сторож: если наш GUI репарентнули/удалили извне — восстанавливаем.
	--// (Защита от чужих скриптов, чистящих CoreGui, и от кривых "анти-чит" зачисток.)
	local guardEnabled = true
	_taskSpawn(function()
		local expectedParent = screenGui.Parent
		while guardEnabled do
			_taskWait(2)
			if not guardEnabled then break end
			local ok = _pcall(function()
				if screenGui.Parent == nil then
					-- удалили — перемонтируем
					mountGui(screenGui)
					expectedParent = screenGui.Parent
				elseif screenGui.Parent ~= expectedParent then
					screenGui.Parent = expectedParent
				end
			end)
			if not ok then break end
		end
	end)

	local window = _setmetatable({
		_screenGui = screenGui,
		_main = main,
		_theme = T,
		_tabButtonsHolder = tabButtonsHolder,
		_content = content,
		_tabs = {},
		_activeTab = nil,
		_setOpen = setOpen,
		_stopGuard = function() guardEnabled = false end,
	}, UILib)

	-- Старт скрытым: заметное мерцание, чтобы юзер понял, куда тапать
	if startHidden then
		main.Visible = false
		isOpen = false
		hintBlink(true)
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
	self._stopGuard()
	self._screenGui:Destroy()
end

function UILib:CreateTab(name)
	local T = self._theme

	local tabButton = create("TextButton", {
		Size = _UDim2new(1, 0, 0, 34),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = self._tabButtonsHolder,
	}, { corner(_UDimNew(0, 8)) })

	local tabLabel = create("TextLabel", {
		Size = _UDim2new(1, -20, 1, 0),
		Position = _UDim2fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = T.SubText,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = tabButton,
	})

	local tabPage = create("ScrollingFrame", {
		Size = _UDim2new(1, -32, 1, -24),
		Position = _UDim2fromOffset(16, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Stroke,
		CanvasSize = _UDim2new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self._content,
	})

	create("UIListLayout", {
		Padding = _UDimNew(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabPage,
	})

	addPressFeel(tabButton, 0.95)

	local tabObj = { _page = tabPage }

	local function setActive(active)
		if active then
			tween(tabButton, { BackgroundTransparency = 0 }, TWEEN_MED)
			tween(tabLabel, { TextColor3 = T.OnAccent }, TWEEN_MED)
		else
			tween(tabButton, { BackgroundTransparency = 1 }, TWEEN_MED)
			tween(tabLabel, { TextColor3 = T.SubText }, TWEEN_MED)
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

	_tableInsert(self._tabs, tabObj)
	if not self._activeTab then
		self._activeTab = tabObj
		setActive(true)
	end

	local TabAPI = {}
	attachComponentAPI(TabAPI, tabPage, T)
	return _tableFreeze(TabAPI)
end

--// ====================================================================
--// Заморозка публичной поверхности: методы библиотеки нельзя подменить
--// снаружи (monkey-patch для перехвата пользовательских колбэков).
--// ВАЖНО: не отдаём наружу ссылок на внутренние функции/инстансы, кроме
--// необходимого минимума через API-объекты (тоже замороженные).
--// ====================================================================

_tableFreeze(DefaultTheme)

-- ВАЖНО (Luau): table.freeze нельзя вызывать на таблице с защищённым
-- метатейблом, а setmetatable — на уже замороженной. Поэтому:
--   1) замораживаем ВНУТРЕННЮЮ таблицу методов UILib (реальная цель
--      защиты от monkey-patch — подменить CreateWindow и перехватить
--      колбэки через прокси не выйдет, __index ведёт в frozen-таблицу);
--   2) прокси НЕ фризим: запись в него блокирует __newindex, а метатейбл
--      закрыт через __metatable = "locked".
_tableFreeze(UILib)

return _setmetatable({}, {
	__index = UILib,
	__metatable = "locked", -- getmetatable вернёт строку, а не таблицу с методами
	__newindex = function() end, -- молча игнорируем попытки записи
})
