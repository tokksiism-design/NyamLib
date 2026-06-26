-- Загрузка твоей библиотеки NyamLib напрямую с GitHub
local LibURL = "https://raw.githubusercontent.com/tokksiism-design/NyamLib/refs/heads/main/Main.lua"
local iOSMenu = loadstring(game:HttpGet(LibURL))()

-- Создаем окно меню
local MainWin = iOSMenu.new("Esta Internal")

-- Твой конфиг функций (стейт)
local State = {
    Wallhack = false,
    FovRadius = 100.0,
    Prefix = "!"
}

-- Наполняем интерфейс элементами
MainWin:Toggle("Включить Wallhack", State.Wallhack, function(bool)
    State.Wallhack = bool
    -- сюда логику твоего WH
end)

MainWin:Slider("Радиус FOV", 10, 500, State.FovRadius, function(val)
    State.FovRadius = val
    -- сюда код изменения радиуса FOV
end)

MainWin:Variable("Префикс команд", State.Prefix, function(txt)
    State.Prefix = txt
end)
