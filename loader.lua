--[[
    ========================================================
    PSD Hub - Universal Loader with Secure Key System
    Public Repository: https://github.com/Supanat-hub/plez_hub_release
    ========================================================
]]

local GITHUB_USER = "Supanat-hub"
local GITHUB_REPO = "plez_hub_release"
local GITHUB_BRANCH = "main"

local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)
local SCRIPT_URL = BASE_URL .. "plez_hub.lua"
local AUTH_API_URL = "https://psd-auth-engine.12supanat34mml.workers.dev"
local CACHE_KEY_FILE = "PSD_Hub/key.txt"

local env = (typeof(getgenv) == "function" and getgenv()) or _G
local now = tick()

-- 1. Anti-Duplicate Mutex Guard
if env.PSD_LOADING and (now - env.PSD_LOADING) < 8 then
    warn("[PSD Hub] Loader already in progress! Skipping duplicate execution.")
    return
end

-- If an instance is already running in this session:
if env.PSD_LOADED and (env.PSD or _G.PSD) then
    if env.PSD_START_TIME and (now - env.PSD_START_TIME) < 8 then
        warn("[PSD Hub] PSD Hub already active in this session. Skipping duplicate load.")
        return
    end
    local old = env.PSD or _G.PSD
    pcall(function()
        if old.GlobalMaid then old.GlobalMaid:DoCleaning() end
        if old.Window and old.Window.Gui then old.Window.Gui:Destroy() end
    end)
    env.PSD = nil
    _G.PSD = nil
    env.PSD_LOADED = nil
end

env.PSD_LOADING = now
env.PSD_START_TIME = now
_G.PSD_LOADING = now

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local function printBanner()
    print("==================================================")
    print("  Starting PSD Hub...")
    print("  Version: 1.0.0 (Protected Release)")
    print("  Repository: github.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO)
    print("==================================================")
end

local function notifyUser(title, text)
    pcall(function()
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 4,
        })
    end)
end

local function httpRequest(options)
    local fn = (syn and syn.request)
        or (http and http.request)
        or http_request
        or (fluxus and fluxus.request)
        or request
    if fn then
        local ok, res = pcall(fn, options)
        if ok and res then return res end
    end
    if options.Method == "GET" and game.HttpGet then
        local ok, body = pcall(game.HttpGet, game, options.Url)
        if ok then return { StatusCode = 200, Body = body } end
    end
    return nil
end

local function getClientHwid()
    local hwid = nil
    pcall(function()
        if gethwid then
            hwid = gethwid()
        elseif getexecutorname then
            hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        end
    end)
    return hwid or "UNKNOWN_CLIENT_HWID"
end

local function safeReadFile(path)
    if isfile and isfile(path) then
        local ok, content = pcall(readfile, path)
        if ok and content and #content > 0 then return content end
    end
    return nil
end

local function safeWriteFile(path, content)
    pcall(function()
        if writefile then
            local folder = path:match("^(.-)/[^/]+$")
            if folder and makefolder and isfolder and not isfolder(folder) then
                makefolder(folder)
            end
            writefile(path, content)
        end
    end)
end

-- Key Verification Routine
local function verifyKey(key, callback)
    task.spawn(function()
        local endpoint = AUTH_API_URL:gsub("/+$", "") .. "/api/verify"
        local hwid = getClientHwid()
        local userId = player and player.UserId or 0

        local payload = HttpService:JSONEncode({
            key = key or "",
            hwid = hwid,
            userId = userId
        })

        local res = httpRequest({
            Url = endpoint,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PSDHub-Loader/1.0"
            },
            Body = payload
        })

        if not res then
            callback(false, { error = "NETWORK_ERROR", message = "Could not connect to auth server." })
            return
        end

        local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body or "{}")
        if not ok or not data then
            callback(false, { error = "PARSE_ERROR", message = "Invalid response from server." })
            return
        end

        callback(data.success == true, data)
    end)
end

-- Download and execute Main Hub from GitHub
local function loadAndExecuteMainHub()
    notifyUser("PSD Hub", "Loading latest release from GitHub...")

    local uniqueToken = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    local requestUrl = SCRIPT_URL .. "?t=" .. uniqueToken
    local success, scriptContent = pcall(function()
        return game:HttpGet(requestUrl)
    end)

    if not success or not scriptContent or #scriptContent == 0 then
        warn("[PSD Hub] Failed to download script from: " .. SCRIPT_URL)
        notifyUser("PSD Hub Error", "Failed to download script. Check connection.")
        env.PSD_LOADING = nil
        _G.PSD_LOADING = nil
        return
    end

    local loadSuccess, loadFn = pcall(function()
        return loadstring(scriptContent)
    end)

    if not loadSuccess or type(loadFn) ~= "function" then
        warn("[PSD Hub] Failed to compile script: " .. tostring(loadFn))
        notifyUser("PSD Hub Error", "Failed to compile script.")
        env.PSD_LOADING = nil
        _G.PSD_LOADING = nil
        return
    end

    local runSuccess, runError = pcall(loadFn)
    env.PSD_LOADING = nil
    _G.PSD_LOADING = nil

    if not runSuccess then
        warn("[PSD Hub] Execution error: " .. tostring(runError))
        notifyUser("PSD Hub Error", "Execution error occurred.")
    else
        env.PSD_LOADED = true
        _G.PSD_LOADED = true
        print("[PSD Hub] Successfully loaded and initialized!")
    end
end

-- Clean, Professional Key Prompt UI (Zero Emojis, PSD Brand Badge)
local function showKeyUI(onSuccess)
    local parent = CoreGui:FindFirstChild("RobloxGui") or CoreGui
    pcall(function()
        if gethui then parent = gethui() end
    end)

    local old = parent:FindFirstChild("PSD_KeyPrompt_UI")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PSD_KeyPrompt_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = parent

    -- Main Card
    local Main = Instance.new("Frame")
    Main.Name = "MainCard"
    Main.Size = UDim2.new(0, 400, 0, 276)
    Main.Position = UDim2.new(0.5, -200, 0.5, -138)
    Main.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = Main

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(45, 52, 75)
    MainStroke.Thickness = 1
    MainStroke.Parent = Main

    -- Topbar Header
    local Topbar = Instance.new("Frame")
    Topbar.Name = "Topbar"
    Topbar.Size = UDim2.new(1, 0, 0, 46)
    Topbar.BackgroundTransparency = 1
    Topbar.Parent = Main

    -- Logo Badge (PSD in GothamBlack)
    local LogoBadge = Instance.new("Frame")
    LogoBadge.Name = "LogoBadge"
    LogoBadge.Size = UDim2.new(0, 30, 0, 30)
    LogoBadge.Position = UDim2.new(0, 16, 0.5, -15)
    LogoBadge.BackgroundColor3 = Color3.fromRGB(90, 135, 255)
    LogoBadge.BorderSizePixel = 0
    LogoBadge.Parent = Topbar

    local LogoCorner = Instance.new("UICorner")
    LogoCorner.CornerRadius = UDim.new(0, 6)
    LogoCorner.Parent = LogoBadge

    local LogoText = Instance.new("TextLabel")
    LogoText.Size = UDim2.new(1, 0, 1, 0)
    LogoText.BackgroundTransparency = 1
    LogoText.Text = "PSD"
    LogoText.Font = Enum.Font.GothamBlack
    LogoText.TextSize = 12
    LogoText.TextColor3 = Color3.fromRGB(15, 17, 24)
    LogoText.Parent = LogoBadge

    -- Title
    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Position = UDim2.new(0, 54, 0, 0)
    TitleLbl.Size = UDim2.new(0, 75, 1, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = "PSD Hub"
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextSize = 15
    TitleLbl.TextColor3 = Color3.fromRGB(240, 240, 245)
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = Topbar

    -- Badge: KEY ACCESS
    local TagBadge = Instance.new("Frame")
    TagBadge.Position = UDim2.new(0, 132, 0.5, -10)
    TagBadge.Size = UDim2.new(0, 84, 0, 20)
    TagBadge.BackgroundColor3 = Color3.fromRGB(26, 28, 40)
    TagBadge.BorderSizePixel = 0
    TagBadge.Parent = Topbar

    local TagCorner = Instance.new("UICorner")
    TagCorner.CornerRadius = UDim.new(0, 4)
    TagCorner.Parent = TagBadge

    local TagStroke = Instance.new("UIStroke")
    TagStroke.Color = Color3.fromRGB(90, 135, 255)
    TagStroke.Transparency = 0.5
    TagStroke.Thickness = 1
    TagStroke.Parent = TagBadge

    local TagText = Instance.new("TextLabel")
    TagText.Size = UDim2.new(1, 0, 1, 0)
    TagText.BackgroundTransparency = 1
    TagText.Text = "KEY ACCESS"
    TagText.Font = Enum.Font.GothamBold
    TagText.TextSize = 10
    TagText.TextColor3 = Color3.fromRGB(90, 135, 255)
    TagText.Parent = TagBadge

    -- Close Button (X)
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -42, 0.5, -13)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(26, 28, 40)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "X"
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.TextColor3 = Color3.fromRGB(150, 155, 175)
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = Topbar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 4)
    CloseCorner.Parent = CloseBtn

    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(220, 50, 60),
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(26, 28, 40),
            TextColor3 = Color3.fromRGB(150, 155, 175)
        }):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        env.PSD_LOADING = nil
        _G.PSD_LOADING = nil
        ScreenGui:Destroy()
    end)

    -- Divider Line
    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(1, -32, 0, 1)
    Divider.Position = UDim2.new(0, 16, 0, 46)
    Divider.BackgroundColor3 = Color3.fromRGB(32, 36, 52)
    Divider.BorderSizePixel = 0
    Divider.Parent = Main

    -- Subtitle
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Position = UDim2.new(0, 16, 0, 55)
    Subtitle.Size = UDim2.new(1, -32, 0, 18)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Enter your access key to authenticate this session."
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextSize = 11
    Subtitle.TextColor3 = Color3.fromRGB(150, 155, 175)
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Parent = Main

    -- Input Box Container
    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1, -32, 0, 40)
    InputBox.Position = UDim2.new(0, 16, 0, 78)
    InputBox.BackgroundColor3 = Color3.fromRGB(26, 28, 40)
    InputBox.BorderSizePixel = 0
    InputBox.Font = Enum.Font.Gotham
    InputBox.TextSize = 13
    InputBox.TextColor3 = Color3.fromRGB(240, 240, 245)
    InputBox.PlaceholderText = "Paste access key here (e.g. aom_key)..."
    InputBox.PlaceholderColor3 = Color3.fromRGB(100, 105, 125)
    InputBox.ClearTextOnFocus = false
    InputBox.TextXAlignment = Enum.TextXAlignment.Left
    InputBox.Parent = Main

    local InputCorner = Instance.new("UICorner")
    InputCorner.CornerRadius = UDim.new(0, 6)
    InputCorner.Parent = InputBox

    local InputStroke = Instance.new("UIStroke")
    InputStroke.Color = Color3.fromRGB(42, 48, 70)
    InputStroke.Thickness = 1
    InputStroke.Parent = InputBox

    local InputPad = Instance.new("UIPadding")
    InputPad.PaddingLeft = UDim.new(0, 12)
    InputPad.PaddingRight = UDim.new(0, 12)
    InputPad.Parent = InputBox

    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -32, 0, 18)
    StatusLabel.Position = UDim2.new(0, 16, 0, 122)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Ready"
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 11
    StatusLabel.TextColor3 = Color3.fromRGB(130, 135, 155)
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = Main

    -- Action Buttons Row
    local GetKeyBtn = Instance.new("TextButton")
    GetKeyBtn.Size = UDim2.new(0.5, -21, 0, 38)
    GetKeyBtn.Position = UDim2.new(0, 16, 0, 146)
    GetKeyBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
    GetKeyBtn.BorderSizePixel = 0
    GetKeyBtn.Text = "Get Key"
    GetKeyBtn.Font = Enum.Font.GothamBold
    GetKeyBtn.TextSize = 13
    GetKeyBtn.TextColor3 = Color3.fromRGB(215, 220, 240)
    GetKeyBtn.AutoButtonColor = false
    GetKeyBtn.Parent = Main

    local GetKeyCorner = Instance.new("UICorner")
    GetKeyCorner.CornerRadius = UDim.new(0, 6)
    GetKeyCorner.Parent = GetKeyBtn

    GetKeyBtn.MouseEnter:Connect(function()
        TweenService:Create(GetKeyBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(42, 48, 68)
        }):Play()
    end)
    GetKeyBtn.MouseLeave:Connect(function()
        TweenService:Create(GetKeyBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30, 34, 48)
        }):Play()
    end)

    local VerifyBtn = Instance.new("TextButton")
    VerifyBtn.Size = UDim2.new(0.5, -21, 0, 38)
    VerifyBtn.Position = UDim2.new(0.5, 5, 0, 146)
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(90, 135, 255)
    VerifyBtn.BorderSizePixel = 0
    VerifyBtn.Text = "Verify Key"
    VerifyBtn.Font = Enum.Font.GothamBold
    VerifyBtn.TextSize = 13
    VerifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    VerifyBtn.AutoButtonColor = false
    VerifyBtn.Parent = Main

    local VerifyCorner = Instance.new("UICorner")
    VerifyCorner.CornerRadius = UDim.new(0, 6)
    VerifyCorner.Parent = VerifyBtn

    VerifyBtn.MouseEnter:Connect(function()
        TweenService:Create(VerifyBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(115, 155, 255)
        }):Play()
    end)
    VerifyBtn.MouseLeave:Connect(function()
        TweenService:Create(VerifyBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(90, 135, 255)
        }):Play()
    end)

    -- Bottom Secondary Button: Paste from Clipboard
    local PasteBtn = Instance.new("TextButton")
    PasteBtn.Size = UDim2.new(1, -32, 0, 32)
    PasteBtn.Position = UDim2.new(0, 16, 0, 192)
    PasteBtn.BackgroundColor3 = Color3.fromRGB(23, 26, 38)
    PasteBtn.BorderSizePixel = 0
    PasteBtn.Text = "Paste from Clipboard"
    PasteBtn.Font = Enum.Font.Gotham
    PasteBtn.TextSize = 11
    PasteBtn.TextColor3 = Color3.fromRGB(150, 155, 175)
    PasteBtn.AutoButtonColor = false
    PasteBtn.Parent = Main

    local PasteCorner = Instance.new("UICorner")
    PasteCorner.CornerRadius = UDim.new(0, 6)
    PasteCorner.Parent = PasteBtn

    PasteBtn.MouseEnter:Connect(function()
        TweenService:Create(PasteBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(32, 36, 52),
            TextColor3 = Color3.fromRGB(240, 240, 245)
        }):Play()
    end)
    PasteBtn.MouseLeave:Connect(function()
        TweenService:Create(PasteBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(23, 26, 38),
            TextColor3 = Color3.fromRGB(150, 155, 175)
        }):Play()
    end)

    -- Footer Note
    local FooterLbl = Instance.new("TextLabel")
    FooterLbl.Position = UDim2.new(0, 16, 0, 232)
    FooterLbl.Size = UDim2.new(1, -32, 0, 16)
    FooterLbl.BackgroundTransparency = 1
    FooterLbl.Text = "Keys are securely locked to your device on first use."
    FooterLbl.Font = Enum.Font.Gotham
    FooterLbl.TextSize = 10
    FooterLbl.TextColor3 = Color3.fromRGB(95, 100, 120)
    FooterLbl.TextXAlignment = Enum.TextXAlignment.Center
    FooterLbl.Parent = Main

    -- Event Connections
    GetKeyBtn.MouseButton1Click:Connect(function()
        local hwid = getClientHwid()
        local userId = player and player.UserId or 0
        local link = string.format("%s/get-key?hwid=%s&userId=%d", AUTH_API_URL:gsub("/+$", ""), hwid, userId)
        if setclipboard then
            setclipboard(link)
            StatusLabel.Text = "Link copied to clipboard! Complete in browser."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 220, 140)
        else
            StatusLabel.Text = "Copy failed. Check F9 console for link."
            StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            print("[PSD Hub Key Link]: " .. link)
        end
    end)

    PasteBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if getclipboard then
                InputBox.Text = getclipboard()
                StatusLabel.Text = "Pasted from clipboard."
                StatusLabel.TextColor3 = Color3.fromRGB(100, 220, 140)
            end
        end)
    end)

    VerifyBtn.MouseButton1Click:Connect(function()
        local key = (InputBox.Text or ""):gsub("%s+", "")
        if #key < 3 then
            StatusLabel.Text = "Please enter your access key."
            StatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
            return
        end

        StatusLabel.Text = "Verifying key with server..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        VerifyBtn.Text = "Verifying..."

        verifyKey(key, function(ok, data)
            VerifyBtn.Text = "Verify Key"
            if ok then
                StatusLabel.Text = "Key Verified! Loading PSD Hub..."
                StatusLabel.TextColor3 = Color3.fromRGB(100, 220, 140)
                safeWriteFile(CACHE_KEY_FILE, key)

                task.wait(0.5)
                ScreenGui:Destroy()
                onSuccess()
            else
                StatusLabel.Text = data.message or "Invalid or expired key."
                StatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
            end
        end)
    end)
end

-- ==================================================
-- Main Execution Flow
-- ==================================================
local function execute()
    if not game:IsLoaded() then
        print("[PSD Hub] Waiting for game to finish loading...")
        game.Loaded:Wait()
    end

    while not Players.LocalPlayer do
        task.wait(0.1)
    end

    printBanner()

    if not game.HttpGet then
        warn("[PSD Hub] Error: Executor does not support HttpGet.")
        notifyUser("PSD Hub Error", "Executor does not support HttpGet!")
        env.PSD_LOADING = nil
        _G.PSD_LOADING = nil
        return
    end

    -- Clean up any dangling instances from previous runs
    pcall(function()
        local old = env.PSD or _G.PSD
        if old then
            if old.GlobalMaid then old.GlobalMaid:DoCleaning() end
            if old.Window and old.Window.Gui then old.Window.Gui:Destroy() end
            env.PSD = nil
            _G.PSD = nil
        end
        local cg = game:GetService("CoreGui")
        if cg and cg:FindFirstChild("PlezUI") then cg.PlezUI:Destroy() end
        local lp = game:GetService("Players").LocalPlayer
        if lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("PlezUI") then
            lp.PlayerGui.PlezUI:Destroy()
        end
    end)

    -- Step 1: Check cached key in background
    local cachedKey = safeReadFile(CACHE_KEY_FILE)
    if cachedKey and #cachedKey >= 3 then
        print("[PSD Hub] Checking saved access key...")
        verifyKey(cachedKey, function(ok, data)
            if ok then
                print("[PSD Hub] Key verified! Starting hub...")
                loadAndExecuteMainHub()
            else
                print("[PSD Hub] Saved key expired or invalid. Prompting user...")
                showKeyUI(function()
                    loadAndExecuteMainHub()
                end)
            end
        end)
    else
        showKeyUI(function()
            loadAndExecuteMainHub()
        end)
    end
end

execute()
