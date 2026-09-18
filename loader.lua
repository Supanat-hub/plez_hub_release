--[[
    ========================================================
    PSD Hub - Universal Loader
    Public Repository: https://github.com/Supanat-hub/plez_hub_release
    ========================================================
]]

local GITHUB_USER = "Supanat-hub"
local GITHUB_REPO = "plez_hub_release"
local GITHUB_BRANCH = "main"

local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)
local SCRIPT_URL = BASE_URL .. "plez_hub.lua"

local env = (typeof(getgenv) == "function" and getgenv()) or _G
local now = tick()

-- 1. Anti-Duplicate Mutex Guard
-- If another instance has started loading within the last 8 seconds, abort immediately!
if env.PSD_LOADING and (now - env.PSD_LOADING) < 8 then
    warn("[PSD Hub] Loader already in progress! Skipping duplicate execution.")
    return
end

-- If an instance is already running and loaded in this session:
if env.PSD_LOADED and (env.PSD or _G.PSD) then
    -- If triggered by teleport queue or autoexec within 8 seconds of script start, abort duplicate
    if env.PSD_START_TIME and (now - env.PSD_START_TIME) < 8 then
        warn("[PSD Hub] PSD Hub already active in this session. Skipping duplicate load.")
        return
    end
    -- If deliberately re-executed much later, clean up old instance first
    local old = env.PSD or _G.PSD
    pcall(function()
        if old.GlobalMaid then old.GlobalMaid:DoCleaning() end
        if old.Window and old.Window.Gui then old.Window.Gui:Destroy() end
    end)
    env.PSD = nil
    _G.PSD = nil
    env.PSD_LOADED = nil
end

-- Acquire loader lock immediately
env.PSD_LOADING = now
env.PSD_START_TIME = now
_G.PSD_LOADING = now

local function printBanner()
    print("==================================================")
    print("  🚀 Starting PSD Hub...")
    print("  📦 Version: 1.0.0 (Protected Release)")
    print("  🌐 Repository: github.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO)
    print("==================================================")
end

local function notifyUser(title, text)
    pcall(function()
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5,
        })
    end)
end

local function execute()
    -- Ensure game and LocalPlayer are fully loaded before downloading or running
    if not game:IsLoaded() then
        print("[PSD Hub] Waiting for game to finish loading...")
        game.Loaded:Wait()
    end

    local Players = game:GetService("Players")
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

    -- Clean up any existing old GUI instances from previous runs
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

    notifyUser("PSD Hub", "Loading latest release from GitHub...")

    -- Cache busting parameter ensures users always get the freshest build
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

execute()

