-- language: Luau | Pooky Hub GUI v6
-- Changes vs v5: OpenRouter API, Player/Flight split, Discord-in-every-tab, 720x600 default,
-- sidebar logo mark, model dropdown with pricing tiers, config compat with Ouroboros.
-- Setup: getgenv().POOKY_OPENROUTER_KEY = "sk-or-v1-..." BEFORE loading this file.

-- ============ CONFIG ============
local PookyConfig = {
    GITHUB_USER  = "yysof",
    ASSETS_REPO  = "yysof/pooky-assets",
    DISCORD_URL  = "https://discord.gg/rkwFYkWY4d",
    RSCRIPTS_URL = "https://rscripts.net/users/pookyhub",
    OPENROUTER_KEY = (getgenv and getgenv().POOKY_OPENROUTER_KEY) or "",
    DEFAULT_MODEL  = "google/gemini-2.5-flash",
    LOGO_ASSET_ID   = nil,
    BANNER_ASSET_ID = nil,
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
    Footer = "Pooky Hub v0.6",
}) then return end

local ThemeManager = loadstring(game:HttpGet(REPO .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(REPO .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true
Library.NotifySide = "Right"
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

-- ============ image loader ============
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

-- ============ WINDOW (720x600, matches Ouroboros defaults) ============
local Window = Library:CreateWindow({
    Title = "Pooky Hub",
    Icon = PookyConfig.LOGO_ASSET_ID or "sparkles",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Center = true, AutoShow = true, Resizable = true,
    Glow = true,
    Snapping = true,
    EnableSidebarResize = true,
    MinSidebarWidth = 140,
    SidebarCompactWidth = 48,
    SidebarCompacted = false,
    Footer = {
        "Pooky Hub v0.6 |",
        { Text = "discord.gg/rkwFYkWY4d", Copyable = true, CopyText = PookyConfig.DISCORD_URL },
        "|",
        { Text = game.Name, Copyable = true, CopyText = tostring(game.PlaceId) },
    },
    CopyableFooter = true,
    FuzzySearch = true, SearchValues = true, SearchKeybind = Enum.KeyCode.F,
    Minimizable = true, MinimizeKeybind = Enum.KeyCode.RightBracket, MinimizedWidth = 320,
    NotificationHistoryLimit = 100, NotificationHistoryKeybind = Enum.KeyCode.RightAlt,
})
pcall(function() Window:SetCornerRadius(6) end)
pcall(function() Window:SetSizePosition(
    UDim2.fromOffset(720, 600),
    UDim2.new(0.5, -360, 0.5, -285)
) end)

-- inject logo into sidebar top
task.spawn(function()
    task.wait(0.1)
    pcall(function()
        local mf = Library.MainFrame or Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main", true)
        if not mf then return end
        local sidebar
        for _, d in ipairs(mf:GetDescendants()) do
            if d:IsA("Frame") and (d.Name:lower():find("sidebar") or d.Name:lower():find("side")) then
                sidebar = d; break
            end
        end
        if not sidebar or sidebar:FindFirstChild("PookyLogoMark") then return end
        local logoAsset = PookyConfig.LOGO_ASSET_ID
            or loadImage("https://raw.githubusercontent.com/" .. PookyConfig.ASSETS_REPO .. "/main/pooky-hub-logo-512.png")
        if logoAsset == "" then return end
        local holder = Instance.new("Frame")
        holder.Name = "PookyLogoMark"
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.new(1, 0, 0, 44)
        holder.LayoutOrder = -100
        holder.Parent = sidebar
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = logoAsset
        img.ScaleType = Enum.ScaleType.Fit
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.Size = UDim2.new(0, 32, 0, 32)
        img.Parent = holder
    end)
end)

local Tabs = {
    Info      = Window:AddTab({ Name = "Info",     Icon = "info",     Description = "Session, socials, hub status" }),
    AI        = Window:AddTab({ Name = "AI",       Icon = "sparkles", Description = "Ask Claude / Gemini — scripting, game help", SingleColumn = true }),
    Player    = Window:AddTab({ Name = "Player",   Icon = "user-round",   Description = "Movement, flight, character" }),
    Server    = Window:AddTab({ Name = "Server",   Icon = "server",   Description = "Rejoin, hop, job info, players" }),
    Settings  = Window:AddTab({ Name = "Settings", Icon = "settings", Description = "Theme, keybinds, configs" }),
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

-- ============ reusable Discord card factory (used in every tab) ============
local function addDiscordBox(tab, side)
    local bannerImg = PookyConfig.BANNER_ASSET_ID
        or loadImage("https://raw.githubusercontent.com/" .. PookyConfig.ASSETS_REPO .. "/main/pooky-hub-banner.png")
    local logoImg = PookyConfig.LOGO_ASSET_ID
        or loadImage("https://raw.githubusercontent.com/" .. PookyConfig.ASSETS_REPO .. "/main/pooky-hub-logo-512.png")
    local box = (side == "Left") and tab:AddLeftGroupbox("Discord", "message-circle")
        or tab:AddRightGroupbox("Discord", "message-circle")
    box:AddDiscordBox("PookyDiscord_" .. tab.Name, {
        Banner = bannerImg ~= "" and bannerImg or nil,
        BannerColor = "AccentColor",
        Avatar = logoImg ~= "" and logoImg or nil,
        AvatarColor = "AccentColor",
        Title = "Pooky Hub",
        Subtitle = "Keyless scripts, live updates",
        Status = "online",
        Accent = "BlueColor",
        Link = PookyConfig.DISCORD_URL,
        Buttons = {
            { Text = "Copy Discord Invite", Icon = "copy", Copy = true },
        },
        BannerHeight = 72, AvatarSize = 60,
    })
    return box
end

-- ============ INFO TAB (User, Discord, Session, Socials) ============
do
    local execName, execVer = helpers.exec()
    local sessionStart = tick()

    -- LEFT: User card (vertical, centered avatar — Ouroboros style)
    local UserBox = Tabs.Info:AddLeftGroupbox("User", "user")

    local avatarHolder = Instance.new("Frame")
    avatarHolder.BackgroundTransparency = 1
    avatarHolder.Size = UDim2.new(1, 0, 0, 180)
    avatarHolder.LayoutOrder = -10
    avatarHolder.Parent = UserBox.Container

    local avatarFrame = Instance.new("Frame")
    avatarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    avatarFrame.BorderSizePixel = 0
    avatarFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    avatarFrame.Position = UDim2.fromScale(0.5, 0.5)
    avatarFrame.Size = UDim2.new(0, 150, 0, 170)
    avatarFrame.Parent = avatarHolder
    local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0, 8); ac.Parent = avatarFrame
    local as = Instance.new("UIStroke"); as.Color = Color3.fromRGB(45,45,52); as.Thickness = 1; as.Parent = avatarFrame

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.BackgroundTransparency = 1
    avatarImg.Size = UDim2.new(1, -8, 1, -8)
    avatarImg.Position = UDim2.new(0, 4, 0, 4)
    avatarImg.Image = string.format("rbxthumb://type=AvatarBust&id=%d&w=420&h=420", LP.UserId)
    avatarImg.ScaleType = Enum.ScaleType.Fit
    avatarImg.Parent = avatarFrame

    -- styled labels below avatar
    local function styledLabel(prefix, value, layoutOrder)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -8, 0, 18)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.RichText = true
        lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        lbl.LayoutOrder = layoutOrder or 0
        lbl.Text = string.format("<b>%s</b>  <font color=\"rgb(255,105,180)\">%s</font>", prefix, tostring(value))
        lbl.Parent = UserBox.Container
        return lbl
    end
    styledLabel("User",     LP.DisplayName .. "  @" .. LP.Name, -5)
    styledLabel("UserId",   tostring(LP.UserId), -4)
    styledLabel("Executor", execName .. (execVer ~= "" and (" " .. execVer) or "") .. "  (ready)", -3)
    local sessLbl = styledLabel("Session", "0s", -2)

    UserBox:AddDivider()
    UserBox:AddButton({ Text = "Copy Username", Func = function()
        helpers.clip(LP.Name); helpers.notify("Copied", LP.Name, 2, "Success") end })
    UserBox:AddButton({ Text = "Copy Profile Link", Func = function()
        local l = "https://www.roblox.com/users/" .. LP.UserId .. "/profile"
        helpers.clip(l); helpers.notify("Copied", l, 2, "Success") end })

    task.spawn(function() while not Library.Unloaded do
        local t = math.floor(tick() - sessionStart)
        local h, m, s = math.floor(t/3600), math.floor((t%3600)/60), t%60
        local txt = (h>0) and string.format("%dh %dm %ds", h,m,s)
            or (m>0) and string.format("%dm %ds", m,s) or string.format("%ds", s)
        pcall(function() sessLbl.Text = string.format("<b>Session</b>  <font color=\"rgb(255,105,180)\">%s</font>", txt) end)
        task.wait(1) end end)

    -- RIGHT 1: Discord
    addDiscordBox(Tabs.Info, "Right")

    -- RIGHT 2: Session (live)
    local SessBox = Tabs.Info:AddRightGroupbox("Session", "activity")
    local function sessLabel(prefix, value, layoutOrder)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -8, 0, 18)
        lbl.Font = Enum.Font.Code; lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.RichText = true
        lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        lbl.LayoutOrder = layoutOrder or 0
        lbl.Text = string.format("<b>%s</b>  <font color=\"rgb(255,105,180)\">%s</font>", prefix, tostring(value))
        lbl.Parent = SessBox.Container
        return lbl
    end
    sessLabel("Game", game.Name, 1)
    local playersLbl = sessLabel("Players", tostring(#Players:GetPlayers()), 2)
    local jobShort = (#game.JobId > 12) and (game.JobId:sub(1,8) .. "-" .. game.JobId:sub(-4)) or game.JobId
    sessLabel("Job", jobShort, 3)
    local pingLbl = sessLabel("Ping", helpers.getPingMs() .. "ms", 4)
    SessBox:AddDivider()
    SessBox:AddButton({ Text = "Rejoin Place", Func = function() TeleportService:Teleport(game.PlaceId, LP) end })
    SessBox:AddButton({ Text = "Copy Job ID", Func = function()
        helpers.clip(game.JobId); helpers.notify("Copied", game.JobId, 2, "Success") end })

    Players.PlayerAdded:Connect(function()
        pcall(function() playersLbl.Text = string.format("<b>Players</b>  <font color=\"rgb(255,105,180)\">%d</font>", #Players:GetPlayers()) end) end)
    Players.PlayerRemoving:Connect(function()
        pcall(function() playersLbl.Text = string.format("<b>Players</b>  <font color=\"rgb(255,105,180)\">%d</font>", #Players:GetPlayers()-1) end) end)
    helpers.loop(2, function()
        pcall(function() pingLbl.Text = string.format("<b>Ping</b>  <font color=\"rgb(255,105,180)\">%dms</font>", helpers.getPingMs()) end) end)

    -- RIGHT 3: Socials
    local SocBox = Tabs.Info:AddRightGroupbox("Socials", "link")
    SocBox:AddButton({ Text = "Copy Discord",  Func = function() helpers.clip(PookyConfig.DISCORD_URL);  helpers.notify("Copied", PookyConfig.DISCORD_URL, 2, "Success") end })
    SocBox:AddButton({ Text = "Copy Rscripts", Func = function() helpers.clip(PookyConfig.RSCRIPTS_URL); helpers.notify("Copied", PookyConfig.RSCRIPTS_URL, 2, "Success") end })
    SocBox:AddButton({ Text = "Copy YouTube",  Func = function()
        local yt = "https://youtube.com/@pookyhub"
        helpers.clip(yt); helpers.notify("Copied", yt, 2, "Success") end })
end

-- ============ AI TAB (OpenRouter, model selector, run-as-script) ============
do
    local ACCENT_USER = Color3.fromRGB(255, 105, 180)
    local BUBBLE_AI   = Color3.fromRGB(28, 28, 34)
    local TEXT_LIGHT  = Color3.fromRGB(240, 240, 245)
    local TEXT_MUTED  = Color3.fromRGB(150, 150, 160)

    -- OpenRouter model catalog with per-1M-token pricing (approx, keep for cost calc)
    local MODELS = {
        { id = "google/gemini-2.5-flash",      label = "Gemini 2.5 Flash (cheap)",   inCost = 0.30, outCost = 2.50 },
        { id = "google/gemini-2.5-pro",        label = "Gemini 2.5 Pro",             inCost = 1.25, outCost = 10.00 },
        { id = "anthropic/claude-sonnet-4",    label = "Claude Sonnet 4 (best code)", inCost = 3.00, outCost = 15.00 },
        { id = "anthropic/claude-haiku-4-5",   label = "Claude Haiku 4.5 (fast)",    inCost = 1.00, outCost = 5.00 },
        { id = "openai/gpt-4.1-mini",          label = "GPT-4.1 Mini",               inCost = 0.40, outCost = 1.60 },
        { id = "deepseek/deepseek-chat-v3",    label = "DeepSeek V3 (cheapest)",     inCost = 0.14, outCost = 0.28 },
    }
    local modelById = {}
    local modelLabels = {}
    for _, m in ipairs(MODELS) do modelById[m.id] = m; table.insert(modelLabels, m.label) end
    local labelToId = {}
    for _, m in ipairs(MODELS) do labelToId[m.label] = m.id end

    local currentModel = PookyConfig.DEFAULT_MODEL
    local chatHistory, totalCost, messageCount, sending = {}, 0, 0, false

    local ChatBox = Tabs.AI:AddLeftGroupbox("Chat with Pooky AI", "message-square")

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
    list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0, 6); list.Parent = scroll
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
            or (role == "assistant") and BUBBLE_AI or Color3.fromRGB(80, 40, 40)
        bubble.BorderSizePixel = 0
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.Size = UDim2.new(0.85, 0, 0, 0)
        if role == "user" then bubble.AnchorPoint = Vector2.new(1, 0); bubble.Position = UDim2.new(1, 0, 0, 0) end
        bubble.Parent = wrap
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = bubble
        local bp = Instance.new("UIPadding")
        bp.PaddingLeft = UDim.new(0, 10); bp.PaddingRight = UDim.new(0, 10)
        bp.PaddingTop = UDim.new(0, 8);   bp.PaddingBottom = UDim.new(0, 8); bp.Parent = bubble
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

    -- input row
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

    -- settings + stats
    local CtrlBox = Tabs.AI:AddLeftGroupbox("Settings & Stats", "settings-2")
    local defaultLabel = modelById[currentModel] and modelById[currentModel].label or modelLabels[1]
    CtrlBox:AddDropdown("PookyAIModel", {
        Values = modelLabels, Default = defaultLabel, Text = "Model",
        Callback = function(v)
            local id = labelToId[v]; if id then currentModel = id end
        end,
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

    -- send handler (OpenRouter format)
    local function sendMessage()
        if sending then return end
        local text = textBox.Text
        if text == "" or text:match("^%s*$") then return end
        if not httpRequest then appendMessage("system", "No HTTP request function in this executor. AI disabled."); return end
        if PookyConfig.OPENROUTER_KEY == "" then
            appendMessage("system", "No API key. Before loading the hub run:  getgenv().POOKY_OPENROUTER_KEY = \"sk-or-v1-...\"")
            return
        end
        textBox.Text = ""; appendMessage("user", text)
        sending = true; sendBtn.Text = "..."; sendBtn.BackgroundColor3 = Color3.fromRGB(80,80,90)

        task.spawn(function()
            local msgsWithSystem = {
                { role = "system", content =
                    "You are Pooky, an AI assistant inside a Roblox script executor. "
                    .. "Current game: " .. game.Name .. " (placeId " .. game.PlaceId .. "). "
                    .. "User: " .. LP.DisplayName .. ". "
                    .. "Help with Luau scripting, farming strategies, remote analysis, and game questions. "
                    .. "Be concise. Wrap code in ```lua fenced blocks so the executor can run the last one via a button."
                },
            }
            for _, m in ipairs(chatHistory) do table.insert(msgsWithSystem, m) end

            local body = HttpService:JSONEncode({
                model = currentModel,
                max_tokens = 1024,
                messages = msgsWithSystem,
            })
            local ok, resp = pcall(function()
                return httpRequest({
                    Url = "https://openrouter.ai/api/v1/chat/completions",
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["Authorization"] = "Bearer " .. PookyConfig.OPENROUTER_KEY,
                        ["HTTP-Referer"] = "https://github.com/yysof/PookyHub",
                        ["X-Title"] = "Pooky Hub",
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
            if parsed.choices and parsed.choices[1] and parsed.choices[1].message then
                local content = parsed.choices[1].message.content or ""
                appendMessage("assistant", content)
                if parsed.usage then
                    local model = modelById[currentModel]
                    if model then
                        local ic_ = (parsed.usage.prompt_tokens or 0) * model.inCost / 1000000
                        local oc  = (parsed.usage.completion_tokens or 0) * model.outCost / 1000000
                        totalCost = totalCost + ic_ + oc
                        pcall(function() costLbl:SetText(string.format("Session cost: $%.4f", totalCost)) end)
                    end
                end
                pcall(function() msgLbl:SetText("Messages: " .. messageCount) end)
            elseif parsed.error then appendMessage("system", "API error: " .. tostring(parsed.error.message))
            else appendMessage("system", "Unexpected response shape: " .. tostring(resp.Body):sub(1, 200)) end
        end)
    end

    sendBtn.MouseButton1Click:Connect(sendMessage)
    textBox.FocusLost:Connect(function(enter) if enter then sendMessage() end end)

    appendMessage("system", "Pooky AI ready via OpenRouter. Cheapest model (DeepSeek V3) selected by default in Settings — swap to Claude Sonnet for complex scripts. Game context is auto-included.")
end

-- ============ PLAYER TAB (Movement + Flight split, Discord card) ============
do
    -- Movement
    local MoveBox = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
    MoveBox:AddSlider("PookyWalkSpeed", {
        Text = "WalkSpeed", Default = 16, Min = 16, Max = 250, Rounding = 0, Suffix = " studs/s",
        Callback = function(v) local _,_,h = helpers.getChar(); if h then h.WalkSpeed = v end end,
    })
    MoveBox:AddSlider("PookyJumpPower", {
        Text = "JumpPower", Default = 50, Min = 50, Max = 500, Rounding = 0,
        Callback = function(v) local _,_,h = helpers.getChar(); if h then h.JumpPower = v end end,
    })
    MoveBox:AddToggle("PookyInfJump", { Text = "Infinite Jump", Default = false })
    MoveBox:AddToggle("PookyNoclip",  { Text = "Noclip", Default = false })

    UserInputService.JumpRequest:Connect(function()
        if Toggles.PookyInfJump and Toggles.PookyInfJump.Value then
            local _,_,h = helpers.getChar(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
    RunService.Stepped:Connect(function()
        if Toggles.PookyNoclip and Toggles.PookyNoclip.Value then
            local c = LP.Character
            if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
        end end)

    -- Flight (separated per Ouroboros pattern)
    local FlyBox = Tabs.Player:AddLeftGroupbox("Flight", "plane")
    FlyBox:AddToggle("PookyFly", { Text = "Fly", Default = false })
    FlyBox:AddSlider("PookyFlySpeed", {
        Text = "Fly Speed", Default = 60, Min = 10, Max = 300, Rounding = 0, Suffix = " studs/s",
    })

    -- Fly loop (BodyVelocity-based, simple mobile-friendly)
    local flyBV, flyBG
    local function stopFly()
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        local _,_,h = helpers.getChar()
        if h then h.PlatformStand = false end
    end
    local function startFly()
        local _, hrp, hum = helpers.getChar()
        if not hrp then return end
        hum.PlatformStand = true
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1,1,1) * math.huge
        flyBV.Velocity = Vector3.new(0,0,0)
        flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1,1,1) * math.huge
        flyBG.P = 10000
        flyBG.CFrame = hrp.CFrame
        flyBG.Parent = hrp
    end

    RunService.RenderStepped:Connect(function()
        if Toggles.PookyFly and Toggles.PookyFly.Value then
            if not flyBV then startFly() end
            local _, hrp = helpers.getChar()
            local cam = Workspace.CurrentCamera
            if not hrp or not cam or not flyBV or not flyBG then return end
            local speed = Options.PookyFlySpeed and Options.PookyFlySpeed.Value or 60
            local move = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
            flyBV.Velocity = (move.Magnitude > 0 and move.Unit or Vector3.new()) * speed
            flyBG.CFrame = cam.CFrame
        elseif flyBV then stopFly() end
    end)

    -- Visuals
    local VisBox = Tabs.Player:AddRightGroupbox("Visuals", "eye")
    VisBox:AddToggle("PookyFullBright", { Text = "Full Bright", Default = false,
        Callback = function(v) if v then Lighting.Brightness=3; Lighting.ClockTime=14; Lighting.FogEnd=100000; Lighting.GlobalShadows=false
            else Lighting.Brightness=2; Lighting.GlobalShadows=true end end })
    VisBox:AddToggle("PookyESP", { Text = "Player ESP", Default = false })

    -- Discord card (Ouroboros pattern: repeat in every tab)
    addDiscordBox(Tabs.Player, "Right")
end

-- ============ SERVER TAB ============
do
    local SG = Tabs.Server:AddLeftGroupbox("Actions", "activity")
    SG:AddButton({ Text = "Rejoin",      Func = function() TeleportService:Teleport(game.PlaceId, LP) end })
    SG:AddButton({ Text = "Server Hop",  Func = helpers.serverHop })
    SG:AddButton({ Text = "Copy Job ID", Func = function() helpers.clip(game.JobId); helpers.notify("Copied", game.JobId, 2, "Success") end })

    local PG = Tabs.Server:AddLeftGroupbox("Players", "users")
    PG:AddDropdown("PookyPlayerTarget", { SpecialType = "Player", ExcludeLocalPlayer = true, Text = "Select Player" })
    PG:AddButton({ Text = "Teleport To", Func = function()
        local p = Players:FindFirstChild(Options.PookyPlayerTarget.Value); if p then helpers.teleport(p) end end })
    PG:AddButton({ Text = "Spectate", Func = function()
        local p = Players:FindFirstChild(Options.PookyPlayerTarget.Value)
        if p and p.Character then Workspace.CurrentCamera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid") end end })
    PG:AddButton({ Text = "Reset Camera", Func = function()
        local _,_,h = helpers.getChar(); if h then Workspace.CurrentCamera.CameraSubject = h end end })

    addDiscordBox(Tabs.Server, "Right")
end

-- ============ SETTINGS TAB ============
do
    local M = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
    M:AddToggle("KeybindMenuOpen", { Text = "Show Keybind Menu", Default = Library.KeybindFrame.Visible,
        Callback = function(v) Library.KeybindFrame.Visible = v end })
    M:AddToggle("PookyCompactSidebar", { Text = "Compact Sidebar", Default = false,
        Callback = function(v) pcall(function() Window:SetCompact(v) end) end })
    M:AddButton("Unload Hub", function() Library:Unload() end)
    M:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
    Library.ToggleKeybind = Options.MenuKeybind

    local SC = Tabs.Settings:AddLeftGroupbox("Script", "code")
    SC:AddLabel("Pooky Hub  v0.6")
    SC:AddLabel("Framework: ObsidianUltra fork")
    SC:AddLabel("Loader: yysof/PookyHub")
    SC:AddButton({ Text = "Check for updates", Func = function()
        helpers.notify("Update check", "no version endpoint yet", 3, "Info") end })

    addDiscordBox(Tabs.Settings, "Left")

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

-- ============ WATERMARK ============
local Watermark = Library:AddWatermark({
    { Player = LP, NameType = "Username" },
    { Icon = "flame",     Text = "Pooky Hub", Accent = true },
    { Icon = "gamepad-2", Text = function() return game.Name end },
    { Icon = "wifi",      Text = function() return helpers.getPingMs() .. "ms" end },
    { Icon = "users",     Text = function() return #Players:GetPlayers() .. " players" end },
})
Watermark.RefreshRate = 1

helpers.notify("Pooky Hub loaded", game.Name .. "  |  AI: " .. (PookyConfig.OPENROUTER_KEY ~= "" and "ready (OpenRouter)" or "no key"), 3, "Success")

return {
    Library = Library, Window = Window, Options = Options, Toggles = Toggles,
    ThemeManager = ThemeManager, SaveManager = SaveManager,
    Tabs = Tabs, Watermark = Watermark, helpers = helpers, Config = PookyConfig,
}
