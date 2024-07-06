local DrawingDict = {}

-- Part 1: Drawing objects and their properties
local Drawings = {}
local Fonts = {}
local ConsoleQueue = {}
local ConsoleClone = {}
local MessageColor = {}
local MessageTemplate = {}
local InputTemplate = {}
local Console = {}
local colors = {}

funcs.get_thread_identity = function() -- funny little way of getting this
    if coroutine.is_yieldable(coroutine.running()) then -- check if u can use task.wait or not
        QueueGetIdentity()
        task.wait(0.1)
        return tonumber(Identity)
    else
        if Identity == -1 then
            task.spawn(QueueGetIdentity)
            return 1
        else
            return tonumber(Identity)
        end
    end
end
funcs.get_identity = funcs.get_thread_identity

-- Part 2: Console functions
funcs.rconsolecreate = function()
    local Clone = Console:Clone()
    Clone.Parent = gethui()
    ConsoleClone = Clone
    ConsoleClone.ConsoleFrame.Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag(input, ConsoleClone.ConsoleFrame)
        end
    end)
end

funcs.rconsoledestroy = function()
    if ConsoleClone then ConsoleClone:Destroy() end
    ConsoleClone = nil
end

funcs.rconsoleprint = function(msg, cc)
    local CONSOLE = ConsoleClone or Console
    repeat task.wait() until ConsoleQueue:IsEmpty()
    msg = tostring(msg)
    local last_color = nil

    msg = msg:gsub('@@(%a+)@@', function(color)
        local colorName = color:upper()
        local rgbColor = colors[colorName]
        if rgbColor then
            local fontTag = string.format('<font color="rgb(%d,%d,%d)">', rgbColor.R * 255, rgbColor.G * 255, rgbColor.B * 255)
            local result = last_color and '</font>' .. fontTag or fontTag
            last_color = colorName
            return result
        else
            return '@@' .. color .. '@@'
        end
    end)

    if last_color then
        msg = msg .. '</font>'
    end

    if msg:match('<font color=".+">.+</font>') then
        if msg:match('<font color=".+"></font>') == msg then MessageColor = colors[last_color] return end
    end

    local tmp = MessageTemplate:Clone()
    tmp.Parent = CONSOLE.ConsoleFrame.Holder
    tmp.Text = msg
    tmp.Visible = true
    tmp.TextColor3 = cc and cc or MessageColor
end

funcs.rconsoleinput = function()
    local CONSOLE = ConsoleClone or Console
    repeat task.wait() until ConsoleQueue:IsEmpty()
    ConsoleQueue:Queue('input')
    local box = InputTemplate:Clone()
    local val
    box.Parent = CONSOLE.ConsoleFrame.Holder
    box.Visible = true
    box.TextEditable = true
    box.TextColor3 = MessageColor

    box.FocusLost:Connect(function(a)
        if not a then return end
        val = box.Text
        ConsoleQueue:Update()
    end)

    local FOCUSED = false
    while true do
        if box.Text:sub(#box.Text, #box.Text) == '_' or box.Text == '' or not box:IsFocused() then
            box.TextColor3 = Color3.fromRGB(255, 255, 255)
            box.Text = box.Text .. '_'

            for _ = 1, 100 do
                task.wait(1/2)
                if box:IsFocused() then
                    FOCUSED = true
                    box.TextColor3 = MessageColor
                    break
                end
                box.Text = box.Text:sub(#box.Text, #box.Text) == '_' and box.Text:sub(#box.Text-1, #box.Text-1) or box.Text .. '_'
            end
            if FOCUSED then break end
        else
            task.wait(0.1)
        end
    end
    repeat task.wait() until val
    return val
end

funcs.rconsolename = function(a)
    if ConsoleClone then
        ConsoleClone.ConsoleFrame.Title.Text = a
    else
        Console.ConsoleFrame.Title.Text = a
    end
end

funcs.rconsoleclear = function()
    if ConsoleClone then
        for i, v in pairs(ConsoleClone.ConsoleFrame.Holder:GetChildren()) do
            if v.ClassName == 'TextLabel' or v.ClassName == 'TextBox' then v:Destroy() end
        end
    else
        for i, v in pairs(Console.ConsoleFrame.Holder:GetChildren()) do
            if v.ClassName == 'TextLabel' or v.ClassName == 'TextBox' then v:Destroy() end
        end
    end
end

funcs.rconsoleinfo = function(a)
    rconsoleprint('[INFO]: ' .. tostring(a))
end

funcs.rconsolewarn = function(a)
    rconsoleprint('[*]: ' .. tostring(a))
end

funcs.rconsoleerr = function(a)
    local clr = MessageColor
    local oldColor
    for i, v in pairs(colors) do
        if clr == v then oldColor = i break end
    end
    rconsoleprint(string.format('[@@RED@@*@@%s@@]: %s', oldColor, tostring(a)))
end

funcs.rconsoleinputasync = funcs.rconsoleinput

funcs.consolecreate = funcs.rconsolecreate
funcs.consoleclear = funcs.rconsoleclear
funcs.consoledestroy = funcs.rconsoledestroy
funcs.consoleinput = funcs.rconsoleinput
funcs.consolesettitle = funcs.rconsolename

funcs.queue_on_teleport = function(scripttoexec) -- WARNING: MUST HAVE MOREUNC IN AUTO EXECUTE FOR THIS TO WORK.
    local newTPService = {
        __index = function(self, key)
            if key == 'Teleport' then
                return function(gameId, player, teleportData, loadScreen)
                    teleportData = {teleportData, MOREUNCSCRIPTQUEUE=scripttoexec}
                    return oldGame:GetService("TeleportService"):Teleport(gameId, player, teleportData, loadScreen)
                end
            end
        end
    }
    local gameMeta = {
        __index = function(self, key)
            if key == 'GetService' then
                return function(name)
                    if name == 'TeleportService' then return newTPService end
                end
            elseif key == 'TeleportService' then return newTPService end
            return game[key]
        end,
        __metatable = 'The metatable is protected'
    }
    getgenv().game = setmetatable({}, gameMeta)
end
funcs.queueonteleport = funcs.queue_on_teleport

-- Part 3: File operations
function readfile(path)
    local content = httpget("http://localhost:5000/readfile?path=" .. path:gsub("/", "\\"))
    print(content)
    return content
end

function writefile(path, text)
    local response = httpget("http://localhost:5000/writefile?path=" .. path:gsub("/", "\\") .. "&text=" .. text)
    print(response)
    return response
end

function makefolder(name)
    local response = httpget("http://localhost:5000/makefolder?name=" .. name:gsub("/", "\\"))
    print(response)
    return response
end

function listfiles(path)
    local response = httpget("http://localhost:5000/listfiles?path=" .. path:gsub("/", "\\"))
    print(response)
    local files_table = game:GetService("HttpService"):JSONDecode(response)
    print(files_table)
    for i, v in pairs(files_table) do
        print(i, v)
    end
    return files_table
end

function delfile(path)
    local basepath = "path to workspace folder here"
    local response = httpget("http://localhost:5000/delfile?path=" .. basepath..path:gsub("/", "\\"))
    return response
end

function delfolder(path)
    local basepath = "path to workspace folder here"
    local construct = basepath..path:gsub("/", "\\")
    local response = httpget("http://localhost:5000/delfolder?path="..construct)
    return response
end

-- Miscellaneous functions
getrenv = function() 
    return _ing1("getrenv")
end

-- SafeOverride function definition not included as it wasn't provided in the Lua script parts

-- Safe overriding of functions
local funcs2 = {}
for i, _ in pairs(funcs) do
    table.insert(funcs2, i)
end

for _, i in pairs(funcs2) do
    SafeOverride(i, funcs[i])
end

-- Synapse UI protection
syn.protect_gui(DrawingDict)
syn.protect_gui(ClipboardUI)

-- Initial function call
QueueGetIdentity()

-- End of script
local colors = {}

funcs.get_thread_identity = function() -- funny little way of getting this
    if coroutine.is_yieldable(coroutine.running()) then -- check if u can use task.wait or not
        QueueGetIdentity()
        task.wait(0.1)
        return tonumber(Identity)
    else
        if Identity == -1 then
            task.spawn(QueueGetIdentity)
            return 1
        else
            return tonumber(Identity)
        end
    end
end
funcs.get_identity = funcs.get_thread_identity
funcs.rconsolecreate = function()
    local Clone = Console:Clone()
    Clone.Parent = gethui()
    ConsoleClone = Clone
    ConsoleClone.ConsoleFrame.Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag(input, ConsoleClone.ConsoleFrame)
        end
    end)
end

funcs.rconsoledestroy = function()
    if ConsoleClone then ConsoleClone:Destroy() end
    ConsoleClone = nil
end

funcs.rconsoleprint = function(msg, cc)
    local CONSOLE = ConsoleClone or Console
    repeat task.wait() until ConsoleQueue:IsEmpty()
    msg = tostring(msg)
    local last_color = nil

    msg = msg:gsub('@@(%a+)@@', function(color)
        local colorName = color:upper()
        local rgbColor = colors[colorName]
        if rgbColor then
            local fontTag = string.format('<font color="rgb(%d,%d,%d)">', rgbColor.R * 255, rgbColor.G * 255, rgbColor.B * 255)
            local result = last_color and '</font>' .. fontTag or fontTag
            last_color = colorName
            return result
        else
            return '@@' .. color .. '@@'
        end
    end)

    if last_color then
        msg = msg .. '</font>'
    end

    if msg:match('<font color=".+">.+</font>') then
        if msg:match('<font color=".+"></font>') == msg then MessageColor = colors[last_color] return end
    end

    local tmp = MessageTemplate:Clone()
    tmp.Parent = CONSOLE.ConsoleFrame.Holder
    tmp.Text = msg
    tmp.Visible = true
    tmp.TextColor3 = cc and cc or MessageColor
end

funcs.rconsoleinput = function()
    local CONSOLE = ConsoleClone or Console
    repeat task.wait() until ConsoleQueue:IsEmpty()
    ConsoleQueue:Queue('input')
    local box = InputTemplate:Clone()
    local val
    box.Parent = CONSOLE.ConsoleFrame.Holder
    box.Visible = true
    box.TextEditable = true
    box.TextColor3 = MessageColor

    box.FocusLost:Connect(function(a)
        if not a then return end
        val = box.Text
        ConsoleQueue:Update()
    end)

    local FOCUSED = false
    while true do
        if box.Text:sub(#box.Text, #box.Text) == '_' or box.Text == '' or not box:IsFocused() then
            box.TextColor3 = Color3.fromRGB(255, 255, 255)
            box.Text = box.Text .. '_'

            for _ = 1, 100 do
                task.wait(1/2)
                if box:IsFocused() then
                    FOCUSED = true
                    box.TextColor3 = MessageColor
                    break
                end
                box.Text = box.Text:sub(#box.Text, #box.Text) == '_' and box.Text:sub(#box.Text-1, #box.Text-1) or box.Text .. '_'
            end
            if FOCUSED then break end
        else
            task.wait(0.1)
        end
    end
    repeat task.wait() until val
    return val
end

funcs.rconsolename = function(a)
    if ConsoleClone then
        ConsoleClone.ConsoleFrame.Title.Text = a
    else
        Console.ConsoleFrame.Title.Text = a
    end
end

funcs.rconsoleclear = function()
    if ConsoleClone then
        for i, v in pairs(ConsoleClone.ConsoleFrame.Holder:GetChildren()) do
            if v.ClassName == 'TextLabel' or v.ClassName == 'TextBox' then v:Destroy() end
        end
    else
        for i, v in pairs(Console.ConsoleFrame.Holder:GetChildren()) do
            if v.ClassName == 'TextLabel' or v.ClassName == 'TextBox' then v:Destroy() end
        end
    end
end

funcs.rconsoleinfo = function(a)
    rconsoleprint('[INFO]: ' .. tostring(a))
end

funcs.rconsolewarn = function(a)
    rconsoleprint('[*]: ' .. tostring(a))
end

funcs.rconsoleerr = function(a)
    local clr = MessageColor
    local oldColor
    for i, v in pairs(colors) do
        if clr == v then oldColor = i break end
    end
    rconsoleprint(string.format('[@@RED@@*@@%s@@]: %s', oldColor, tostring(a)))
end

funcs.rconsoleinputasync = funcs.rconsoleinput

funcs.consolecreate = funcs.rconsolecreate
funcs.consoleclear = funcs.rconsoleclear
funcs.consoledestroy = funcs.rconsoledestroy
funcs.consoleinput = funcs.rconsoleinput
funcs.consolesettitle = funcs.rconsolename

funcs.queue_on_teleport = function(scripttoexec) -- WARNING: MUST HAVE MOREUNC IN AUTO EXECUTE FOR THIS TO WORK.
    local newTPService = {
        __index = function(self, key)
            if key == 'Teleport' then
                return function(gameId, player, teleportData, loadScreen)
                    teleportData = {teleportData, MOREUNCSCRIPTQUEUE=scripttoexec}
                    return oldGame:GetService("TeleportService"):Teleport(gameId, player, teleportData, loadScreen)
                end
            end
        end
    }
    local gameMeta = {
        __index = function(self, key)
            if key == 'GetService' then
                return function(name)
                    if name == 'TeleportService' then return newTPService end
                end
            elseif key == 'TeleportService' then return newTPService end
            return game[key]
        end,
        __metatable = 'The metatable is protected'
    }
    getgenv().game = setmetatable({}, gameMeta)
end
funcs.queueonteleport = funcs.queue_on_teleport
-- SafeOverride function definition not included as it wasn't provided in the Lua script parts

-- Safe overriding of functions
local funcs2 = {}
for i, _ in pairs(funcs) do
    table.insert(funcs2, i)
end

for _, i in pairs(funcs2) do
    SafeOverride(i, funcs[i])
end

-- Synapse UI protection
syn.protect_gui(DrawingDict)
syn.protect_gui(ClipboardUI)
-- Initial function call
QueueGetIdentity()

-- End of script
