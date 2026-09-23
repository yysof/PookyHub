-- language: Luau | Pooky Hub GUI v5
-- Uses yysof/ObsidianUltra fork widgets: AddPlayerInfo, AddDiscordBox, AddWatermark,
-- CreateUnsupportedScreen, Glow, animations, PillCorners.
-- AI tab: Claude via executor HTTP (request()).
-- Setup: getgenv().POOKY_ANTHROPIC_KEY = "sk-ant-..." BEFORE loading this file.

-- ============ CONFIG ============
local PookyConfig = {
    GITHUB_USER  = "yysof",
    ASSETS_REPO  = "yysof/pooky-assets",
    DISCORD_URL  = "https://discord.gg/rkwFYkWY4d",
    RSCRIPTS_URL = "https://rscripts.net/users/pookyhub",
    ANTHROPIC_API_KEY = (getgenv and getgenv().POOKY_ANTHROPIC_KEY) or "",
    ANTHROPIC_MODEL   = "claude-sonnet-5",
    LOGO_ASSET_ID     = nil,   -- set to "rbxassetid://..." once you upload the pink logo as a Roblox decal
    BANNER_ASSET_ID   = nil,
}

local REPO = "https://raw.githubusercontent.com/" .. PookyConfig.GITHUB_USER .. "/ObsidianUltra/main/"

-- ============ LOADER + GATE ============
local Library = loadstring(game:HttpGet(REPO .. "Library.lua"))()

if Library:CreateUnsupportedScreen({
    Supported = { "Potassium", "Delta", "Krnl", "Swift", "Wave", "Xeno", "Solara", "Ronin" },
    Title = "Pooky Hub — Executor Check",
    Information = {
        "Your executor is missing features Pooky Hub relies on.",
        "Supported: Potassium, Delta, Krnl, Swift, Wave, Xeno, Solara, Ronin.",
        "Get install help at discord.gg/rkwFYkWY4d.",
    },
    Footer = "Pooky Hub v0.5",
}) then return end

local ThemeManager = loadstring(game:HttpGet(REPO .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(REPO .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true
Library.NotifySide = "Right"

-- turn on every animation flag (5 default off, 3 default on)
Library.Animations = {
    ToggleWindow = true, TabSwitch = true, Groupbox = true,
    GroupboxCollapse = true, Dropdown = true, KeyPicker = true,
    SubTabUnderline = true, SidebarSubTabs = true,
}

-- ============ SERVICES ============
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")
local Lighting         = game:GetService("Lighting")
local LP = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- ============ image loader (GitHub -> writefile -> getcustomasset) ============
local imageCache = {}
local function loadImage(url)
    if imageCache[url] then return imageCache[url] end
    if not (writefile and getcustomasset) then return "" end
    local ok, data = pcall(function() return game:HttpGet(url) end)
    if not ok or not data or #data < 100 then return "" end
    local ext = url:match("%.(%w+)$") or "png"
    local fname = "pooky_" .. HttpService:GenerateGUID(false):gsub("-", "") .. "." .. ext
    if not pcall(writefile, fname, data) then return "" end
    local ok2, asset = pcall(getcustomasset, fname)
    if not ok2 then return "" end
    imageCache[url] = asset
    return asset
end

-- ============ WINDOW ============
local Window = Library:CreateWindow({
    Title = "Pooky Hub",
    Icon = PookyConfig.LOGO_ASSET_ID or "sparkles",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Center = true, AutoShow = true, Resizable = true,
    Glow = true,             -- premium accent shadow
    Snapping = true,         -- snap to screen edges
    EnableSidebarResize = true,
    MinSidebarWidth = 140, SidebarCompactWidth = 48,
    Footer = {
        "Pooky Hub v0.5 |",
        { Text = "discord.gg/rkwFYkWY4d", Copyable = true, CopyText = PookyConfig.DISCORD_URL },
        "|",
        { Text = game.Name, Copyable = true, CopyText = tostring(game.PlaceId) },
    },
    CopyableFooter = true,
    FuzzySearch = true, SearchValues = true, SearchKeybind = Enum.KeyCode.F,
    Minimizable = true, MinimizeKeybind = Enum.KeyCode.RightBracket, MinimizedWidth = 320,
    NotificationHistoryLimit = 100, NotificationHistoryKeybind = Enum.KeyCode.RightAlt,
})
pcall(function() Window:SetCornerRadius(4) end)  -- softer corners, still terminal-y

local Tabs = {
    Info      = Window:AddTab({ Name = "Info",      Icon = "info",     Description = "Session, socials, hub status" }),
    AI        = Window:AddTab({ Name = "AI",        Icon = "sparkles", Description = "Ask Claude — scripting, strategy, game help", SingleColumn = true }),
    Universal = Window:AddTab({ Name = "Universal", Icon = "globe",    Description = "Movement + visuals — every game" }),
    Players   = Window:AddTab({ Name = "Players",   Icon = "users",    Description = "Teleport, spectate, list" }),
    Server    = Window:AddTab({ Name = "Server",    Icon = "server",   Description = "Rejoin, hop, job info" }),
    Settings  = Window:AddTab({ Name = "Settings",  Icon = "settings", Description = "Theme, keybinds, configs" }),
}

-- ============ HELPERS ============
local helpers = {}
function helpers.getChar(plr) plr = plr or LP; local c = plr.Character; if not c then return nil end
    local hrp, hum = c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then return c, hrp, hum end end
function helpers.teleport(t) local _, hrp = helpers.getChar(); if not hrp then return end
    if typeof(t) == "Instance" then
        if t:IsA("Player") then local _, th = helpers.getChar(t); if th then hrp.CFrame = th.CFrame + Vector3.new(0,2,0) end
        elseif t:IsA("BasePart") then hrp.CFrame = t.CFrame + Vector3.new(0,3,0) end
    elseif typeof(t) == "Vector3" then hrp.CFrame = CFrame.new(t)
    elseif typeof(t) == "CFrame" then hrp.CFrame = t end end
function helpers.serverHop()
    local u = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    local ok, r = pcall(function() return HttpService:JSONDecode(game:HttpGet(u)) end)
    if ok and r.data then for _, s in ipairs(r.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP); return end end end end
function helpers.notify(t, d, tm, ty) Library:Notify({Title=t, Description=d or "", Time=tm or 3, Type=ty or "Info"}) end
function helpers.clip(s) if setclipboard then setclipboard(tostring(s)) end end
function helpers.getPingMs()
    local ok, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and p then return math.floor(p) end
    return math.floor(LP:GetNetworkPing() * 1000) end
function helpers.exec() local n,v = "Unknown","";
    pcall(function() if identifyexecutor then n,v = identifyexecutor() end end); return n, v end
function helpers.loop(iv, fn, flag) task.spawn(function() while task.wait(iv) do
    if Library.Unloaded then break end
    if flag == nil or (Toggles[flag] and Toggles[flag].Value) then pcall(fn) end end end) end

-- ============ INFO TAB (PlayerInfo banner + DiscordBox + session + socials) ============
do
    local execName, execVer = helpers.exec()
    local sessionStart = tick()

    -- full-width banner using fork's PlayerInfo widget
    local UserBanner = Tabs.Info:AddPlayerInfo("PookyUserBanner", {
        Player = LP,
        Title = string.format("<b>%s</b>  <font color=\"#C7C7CE\">@%s</font>", LP.DisplayName, LP.Name),
        Description = {
            string.format("<font color=\"#8E8E9E\">UserId</font>  %d", LP.UserId),
            string.format("<font color=\"#8E8E9E\">Executor</font>  %s%s", execName, execVer ~= "" and (" " .. execVer) or ""),
            "<font color=\"#8E8E9E\">Session</font>  0s",
        },
        ThumbnailType = "Bust",
        Height = 96,
    })

    task.spawn(function() while not Library.Unloaded do
        local t = math.floor(tick() - sessionStart)
        local h, m, s = math.floor(t/3600), math.floor((t%3600)/60), t%60
        local sess = (h>0) and string.format("%dh %dm %ds", h,m,s)
            or (m>0) and string.format("%dm %ds", m,s) or string.format("%ds", s)
        pcall(function() UserBanner:SetDescription({
            string.format("<font color=\"#8E8E9E\">UserId</font>  %d", LP.UserId),
            string.format("<font color=\"#8E8E9E\">Executor</font>  %s%s", execName, execVer ~= "" and (" " .. execVer) or ""),
            string.format("<font color=\"#8E8E9E\">Session</font>  %s", sess),
        }) end)
        task.wait(1) end end)

    -- left: quick actions
    local ActBox = Tabs.Info:AddLeftGroupbox("Quick Actions", "zap")
    ActBox:AddButton({ Text = "Copy Username", Func = function()
        helpers.clip(LP.Name); helpers.notify("Copied", LP.Name, 2, "Success") end })
    ActBox:AddButton({ Text = "Copy Profile Link", Func = function()
        local l = "https://www.roblox.com/users/" .. LP.UserId .. "/profile"
        helpers.clip(l); helpers.notify("Copied", l, 2, "Success") end })
    ActBox:AddButton({ Text = "Copy Job ID", Func = function()
        helpers.clip(game.JobId); helpers.notify("Copied", game.JobId, 2, "Success") end })
    ActBox:AddButton({ Text = "Rejoin Server", Func = function() TeleportService:Teleport(game.PlaceId, LP) end })
    ActBox:AddButton({ Text = "Server Hop", Func = helpers.serverHop })

    -- right: fork's DiscordBox widget (proper Ouroboros-style card)
    local bannerImg = PookyConfig.BANNER_ASSET_ID
        or loadImage("https://raw.githubusercontent.com/" .. PookyConfig.ASSETS_REPO .. "/main/pooky-hub-banner.png")
    local logoImg = PookyConfig.LOGO_ASSET_ID
        or loadImage("https://raw.githubusercontent.com/" .. PookyConfig.ASSETS_REPO .. "/main/pooky-hub-logo-512.png")

    local DiscBox = Tabs.Info:AddRightGroupbox("Community", "message-circle")
    DiscBox:AddDiscordBox("PookyDiscord", {
        Banner = bannerImg ~= "" and bannerImg or nil,
        BannerColor = "AccentColor",
        Avatar = logoImg ~= "" and logoImg or nil,
        AvatarColor = "AccentColor",
        Title = "Pooky Hub",
        Subtitle = "Keyless scripts, live updates",
        Status = "online",
        Accent = "AccentColor",
        Link = PookyConfig.DISCORD_URL,
        Buttons = {
            { Text = "Copy Invite", Icon = "copy", Copy = true },
            { Text = "Open Discord", Icon = "external-link", Style = "Secondary",
              Func = function(url) helpers.clip(url); helpers.notify("Link copied", url, 2, "Info") end },
        },
        BannerHeight = 72, AvatarSize = 60,
    })

    -- right: session
    local SessBox = Tabs.Info:AddRightGroupbox("Session Info", "activity")
    SessBox:AddLabel("Game: " .. game.Name)
    local playersLbl = SessBox:AddLabel("Players: " .. #Players:GetPlayers())
    local pingLbl = SessBox:AddLabel("Ping: " .. helpers.getPingMs() .. "ms")
    local jobShort = (#game.JobId > 12) and (game.JobId:sub(1,8) .. "-" .. game.JobId:sub(-4)) or game.JobId
    SessBox:AddLabel("Job: " .. jobShort)
    Players.PlayerAdded:Connect(function() pcall(function() playersLbl:SetText("Players: " .. #Players:GetPlayers()) end) end)
    Players.PlayerRemoving:Connect(function() pcall(function() playersLbl:SetText("Players: " .. (#Players:GetPlayers()-1)) end) end)
    helpers.loop(2, function() pcall(function() pingLbl:SetText("Ping: " .. helpers.getPingMs() .. "ms") end) end)

    -- right: socials
    local SocBox = Tabs.Info:AddRightGroupbox("Socials", "link")
    SocBox:AddButton({ Text = "Copy Discord",  Func = function() helpers.clip(PookyConfig.DISCORD_URL); helpers.notify("Copied", PookyConfig.DISCORD_URL, 2, "Success") end })
    SocBox:AddButton({ Text = "Copy Rscripts", Func = function() helpers.clip(PookyConfig.RSCRIPTS_URL); helpers.notify("Copied", PookyConfig.RSCRIPTS_URL, 2, "Success") end })
end

-- ============ AI TAB (Claude chat via executor HTTP) ============
do
    local ACCENT_USER = Color3.fromRGB(255, 105, 180)
    local BUBBLE_AI   = Color3.fromRGB(28, 28, 34)
    local TEXT_LIGHT  = Color3.fromRGB(240, 240, 245)
    local TEXT_MUTED  = Color3.fromRGB(150, 150, 160)

    local chatHistory, totalCost, messageCount, sending = {}, 0, 0, false

    local ChatBox = Tabs.AI:AddLeftGroupbox("Chat with Pooky AI", "message-square")

    -- inject ScrollingFrame for messages
    local scrollHolder = Instance.new("Frame")
    scrollHolder.BackgroundTransparency = 1
    scrollHolder.Size = UDim2.new(1, -4, 0, 320)
    scrollHolder.LayoutOrder = -1
    scrollHolder.Parent = ChatBox.Container

    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = ACCENT_USER
    scroll.Parent = scrollHolder

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6); list.Parent = scroll
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
    pad.PaddingTop = UDim.new(0, 4);  pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = scroll

    local function makeBubble(role, text)
        local wrap = Instance.new("Frame")
        wrap.BackgroundTransparency = 1
        wrap.Size = UDim2.new(1, 0, 0, 0)
        wrap.AutomaticSize = Enum.AutomaticSize.Y
        wrap.LayoutOrder = #scroll:GetChildren()

        local bubble = Instance.new("Frame")
        bubble.BackgroundColor3 = (role == "user") and ACCENT_USER
            or (role == "assistant") and BUBBLE_AI
            or Color3.fromRGB(80, 40, 40)
        bubble.BorderSizePixel = 0
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.Size = UDim2.new(0.85, 0, 0, 0)
        if role == "user" then
            bubble.AnchorPoint = Vector2.new(1, 0); bubble.Position = UDim2.new(1, 0, 0, 0)
        end
        bubble.Parent = wrap

        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = bubble
        local bp = Instance.new("UIPadding")
        bp.PaddingLeft = UDim.new(0, 10); bp.PaddingRight = UDim.new(0, 10)
        bp.PaddingTop = UDim.new(0, 8); bp.PaddingBottom = UDim.new(0, 8); bp.Parent = bubble

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham; label.TextSize = 13
        label.TextColor3 = (role == "user") and Color3.fromRGB(255,255,255) or TEXT_LIGHT
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.Size = UDim2.new(1, 0, 0, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.Text = text; label.RichText = true
        label.Parent = bubble

        wrap.Parent = scroll
        task.wait()
        scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
    end

    local function appendMessage(role, text)
        makeBubble(role, text)
        if role == "user" or role == "assistant" then
            table.insert(chatHistory, { role = role, content = text })
            messageCount = messageCount + 1
        end
    end

    -- input row (custom because Obsidian's AddInput has no send button)
    local inputHolder = Instance.new("Frame")
    inputHolder.BackgroundTransparency = 1
    inputHolder.Size = UDim2.new(1, -4, 0, 34)
    inputHolder.LayoutOrder = 999
    inputHolder.Parent = ChatBox.Container

    local inputBg = Instance.new("Frame")
    inputBg.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    inputBg.BorderSizePixel = 0
    inputBg.Size = UDim2.new(1, -80, 1, 0)
    inputBg.Parent = inputHolder
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 6); ic.Parent = inputBg

    local textBox = Instance.new("TextBox")
    textBox.BackgroundTransparency = 1
    textBox.Size = UDim2.new(1, -16, 1, 0); textBox.Position = UDim2.new(0, 8, 0, 0)
    textBox.Font = Enum.Font.Gotham; textBox.TextSize = 13
    textBox.TextColor3 = TEXT_LIGHT
    textBox.PlaceholderText = "ask anything — script help, game strategy, remote analysis..."
    textBox.PlaceholderColor3 = TEXT_MUTED
    textBox.Text = ""; textBox.ClearTextOnFocus = false
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Center
    textBox.Parent = inputBg

    local sendBtn = Instance.new("TextButton")
    sendBtn.BackgroundColor3 = ACCENT_USER
    sendBtn.BorderSizePixel = 0
    sendBtn.Size = UDim2.new(0, 72, 1, 0); sendBtn.Position = UDim2.new(1, -72, 0, 0)
    sendBtn.Font = Enum.Font.GothamMedium; sendBtn.TextSize = 13
    sendBtn.TextColor3 = Color3.fromRGB(255,255,255)
    sendBtn.Text = "Send"; sendBtn.Parent = inputHolder
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = sendBtn

    -- settings / stats
    local CtrlBox = Tabs.AI:AddLeftGroupbox("Settings & Stats", "settings-2")
    CtrlBox:AddDropdown("PookyAIModel", {
        Values = { "claude-sonnet-5", "claude-opus-5-5", "claude-haiku-4-5-20251001" },
        Default = PookyConfig.ANTHROPIC_MODEL, Text = "Model",
        Callback = function(v) PookyConfig.ANTHROPIC_MODEL = v end,
    })
    local costLbl = CtrlBox:AddLabel("Session cost: $0.0000")
    local msgLbl  = CtrlBox:AddLabel("Messages: 0")
    CtrlBox:AddButton({ Text = "Clear Chat", Func = function()
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        chatHistory = {}; messageCount = 0
        pcall(function() msgLbl:SetText("Messages: 0") end)
    end })
    CtrlBox:AddButton({ Text = "Copy Last AI Reply", Func = function()
        for i = #chatHistory, 1, -1 do
            if chatHistory[i].role == "assistant" then
                helpers.clip(chatHistory[i].content)
                helpers.notify("Copied", "AI reply copied", 2, "Success"); return
            end
        end
        helpers.notify("Nothing to copy", "no replies yet", 2, "Warning")
    end })
    CtrlBox:AddButton({ Text = "Run Last AI Reply as Script", Func = function()
        for i = #chatHistory, 1, -1 do
            if chatHistory[i].role == "assistant" then
                local code = chatHistory[i].content:match("```lua\n(.-)```")
                    or chatHistory[i].content:match("```luau\n(.-)```")
                    or chatHistory[i].content:match("```\n(.-)```")
                if not code then helpers.notify("No code block found", "AI reply has no ``` block", 3, "Warning"); return end
                local fn, err = loadstring(code)
                if not fn then helpers.notify("Compile error", tostring(err), 4, "Error"); return end
                local ok, e = pcall(fn)
                if not ok then helpers.notify("Runtime error", tostring(e), 4, "Error")
                else helpers.notify("Executed", "AI script ran successfully", 3, "Success") end
                return
            end
        end
    end })

    -- send handler
    local function sendMessage()
        if sending then return end
        local text = textBox.Text
        if text == "" or text:match("^%s*$") then return end
        if not httpRequest then appendMessage("system", "No HTTP request function in this executor. AI disabled."); return end
        if PookyConfig.ANTHROPIC_API_KEY == "" then
            appendMessage("system", "No API key. Before loading the hub run:  getgenv().POOKY_ANTHROPIC_KEY = \"sk-ant-...\"")
            return
        end
        textBox.Text = ""; appendMessage("user", text)
        sending = true; sendBtn.Text = "..."; sendBtn.BackgroundColor3 = Color3.fromRGB(80,80,90)

        task.spawn(function()
            local body = HttpService:JSONEncode({
                model = PookyConfig.ANTHROPIC_MODEL,
                max_tokens = 1024,
                system = "You are Pooky, an AI assistant inside a Roblox script executor. Current game: " .. game.Name
                    .. " (placeId " .. game.PlaceId .. "). User: " .. LP.DisplayName
                    .. ". Help with Luau scripting, farming strategies, remote analysis, and game questions."
                    .. " Be concise. Use ```lua fenced code blocks for code (the executor can run the last block via a button).",
                messages = chatHistory,
            })
            local ok, resp = pcall(function()
                return httpRequest({
                    Url = "https://api.anthropic.com/v1/messages",
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["x-api-key"] = PookyConfig.ANTHROPIC_API_KEY,
                        ["anthropic-version"] = "2023-06-01",
                    },
                    Body = body,
                })
            end)
            sending = false; sendBtn.Text = "Send"; sendBtn.BackgroundColor3 = ACCENT_USER
            if not ok or not resp then appendMessage("system", "Request failed: " .. tostring(resp)); return end
            if resp.StatusCode and resp.StatusCode >= 400 then
                appendMessage("system", "HTTP " .. tostring(resp.StatusCode) .. ": " .. tostring(resp.Body or ""))
                return
            end
            local pok, parsed = pcall(HttpService.JSONDecode, HttpService, resp.Body or "")
            if not pok then appendMessage("system", "Failed to parse response"); return end
            if parsed.content and parsed.content[1] and parsed.content[1].text then
                appendMessage("assistant", parsed.content[1].text)
                if parsed.usage then
                    local ic_ = (parsed.usage.input_tokens or 0) * 3 / 1000000
                    local oc = (parsed.usage.output_tokens or 0) * 15 / 1000000
                    totalCost = totalCost + ic_ + oc
                    pcall(function() costLbl:SetText(string.format("Session cost: $%.4f", totalCost)) end)
                end
                pcall(function() msgLbl:SetText("Messages: " .. messageCount) end)
            elseif parsed.error then appendMessage("system", "API error: " .. tostring(parsed.error.message))
            else appendMessage("system", "Unexpected response shape") end
        end)
    end

    sendBtn.MouseButton1Click:Connect(sendMessage)
    textBox.FocusLost:Connect(function(enterPressed) if enterPressed then sendMessage() end end)

    appendMessage("system", "Pooky AI ready. Game context is auto-included. Ask for scripts and I'll wrap them in ```lua so you can hit 'Run Last AI Reply' below.")
end

-- ============ UNIVERSAL ============
do
    local UGroup = Tabs.Universal:AddLeftGroupbox("Movement", "footprints")
    UGroup:AddSlider("PookyWalkSpeed", { Text = "WalkSpeed", Default = 16, Min = 16, Max = 250, Rounding = 0, Suffix = " studs/s",
        Callback = function(v) local _,_,h = helpers.getChar(); if h then h.WalkSpeed = v end end })
    UGroup:AddSlider("PookyJumpPower", { Text = "JumpPower", Default = 50, Min = 50, Max = 500, Rounding = 0,
        Callback = function(v) local _,_,h = helpers.getChar(); if h then h.JumpPower = v end end })
    UGroup:AddToggle("PookyInfJump", { Text = "Infinite Jump", Default = false })
    UGroup:AddToggle("PookyNoclip",  { Text = "Noclip",         Default = false })

    UserInputService.JumpRequest:Connect(function()
        if Toggles.PookyInfJump and Toggles.PookyInfJump.Value then
            local _,_,h = helpers.getChar(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
    RunService.Stepped:Connect(function()
        if Toggles.PookyNoclip and Toggles.PookyNoclip.Value then
            local c = LP.Character
            if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
        end end)

    local VGroup = Tabs.Universal:AddRightGroupbox("Visuals", "eye")
    VGroup:AddToggle("PookyFullBright", { Text = "Full Bright", Default = false,
        Callback = function(v) if v then Lighting.Brightness=3; Lighting.ClockTime=14; Lighting.FogEnd=100000; Lighting.GlobalShadows=false
            else Lighting.Brightness=2; Lighting.GlobalShadows=true end end })
    VGroup:AddToggle("PookyESP", { Text = "Player ESP", Default = false })
end

-- ============ PLAYERS ============
do
    local PG = Tabs.Players:AddLeftGroupbox("Actions", "user")
    PG:AddDropdown("PookyPlayerTarget", { SpecialType = "Player", ExcludeLocalPlayer = true, Text = "Select Player" })
    PG:AddButton({ Text = "Teleport To", Func = function()
        local p = Players:FindFirstChild(Options.PookyPlayerTarget.Value); if p then helpers.teleport(p) end end })
    PG:AddButton({ Text = "Spectate", Func = function()
        local p = Players:FindFirstChild(Options.PookyPlayerTarget.Value)
        if p and p.Character then Workspace.CurrentCamera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid") end end })
    PG:AddButton({ Text = "Reset Camera", Func = function()
        local _,_,h = helpers.getChar(); if h then Workspace.CurrentCamera.CameraSubject = h end end })
end

-- ============ SERVER ============
do
    local SG = Tabs.Server:AddLeftGroupbox("Actions", "activity")
    SG:AddButton({ Text = "Rejoin",      Func = function() TeleportService:Teleport(game.PlaceId, LP) end })
    SG:AddButton({ Text = "Server Hop",  Func = helpers.serverHop })
    SG:AddButton({ Text = "Copy Job ID", Func = function() helpers.clip(game.JobId); helpers.notify("Copied", game.JobId, 2, "Success") end })
    local I = Tabs.Server:AddRightGroupbox("Info", "info")
    I:AddLabel("Game: " .. game.Name); I:AddLabel("PlaceId: " .. game.PlaceId); I:AddLabel("Players: " .. #Players:GetPlayers())
end

-- ============ SETTINGS ============
do
    local M = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
    M:AddToggle("KeybindMenuOpen", { Text = "Show Keybind Menu", Default = Library.KeybindFrame.Visible,
        Callback = function(v) Library.KeybindFrame.Visible = v end })
    M:AddToggle("PookyCompactSidebar", { Text = "Compact Sidebar", Default = false,
        Callback = function(v) pcall(function() Window:SetCompact(v) end) end })
    M:AddButton("Unload Hub", function() Library:Unload() end)
    M:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
    Library.ToggleKeybind = Options.MenuKeybind

    ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "PookyAIModel" })
    ThemeManager:SetFolder("PookyHub")
    SaveManager:SetFolder("PookyHub/" .. tostring(game.PlaceId))
    ThemeManager:ApplyToTab(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    pcall(function() ThemeManager:ApplyTheme("Evil Hello Kitty") end)
    pcall(function() SaveManager:LoadAutoloadConfig() end)
end

-- ============ WATERMARK (floating status bar) ============
local Watermark = Library:AddWatermark({
    { Player = LP, NameType = "Username" },
    { Icon = "flame",     Text = "Pooky Hub", Accent = true },
    { Icon = "gamepad-2", Text = function() return game.Name end },
    { Icon = "wifi",      Text = function() return helpers.getPingMs() .. "ms" end },
    { Icon = "users",     Text = function() return #Players:GetPlayers() .. " players" end },
})
Watermark.RefreshRate = 1

helpers.notify("Pooky Hub loaded", game.Name .. "  |  AI: " .. (PookyConfig.ANTHROPIC_API_KEY ~= "" and "ready" or "no key set"), 3, "Success")

return {
    Library = Library, Window = Window, Options = Options, Toggles = Toggles,
    ThemeManager = ThemeManager, SaveManager = SaveManager,
    Tabs = Tabs, Watermark = Watermark, helpers = helpers, Config = PookyConfig,
}
