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
    printBanner()

    if not game.HttpGet then
        warn("[PSD Hub] Error: Executor does not support HttpGet.")
        notifyUser("PSD Hub Error", "Executor does not support HttpGet!")
        return
    end

    -- Clean up any existing old GUI instances from previous runs
    pcall(function()
        if _G.PSD then
            if _G.PSD.GlobalMaid then _G.PSD.GlobalMaid:DoCleaning() end
            if _G.PSD.Window and _G.PSD.Window.Gui then _G.PSD.Window.Gui:Destroy() end
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
        return
    end

    local loadSuccess, loadFn = pcall(function()
        return loadstring(scriptContent)
    end)

    if not loadSuccess or type(loadFn) ~= "function" then
        warn("[PSD Hub] Failed to compile script: " .. tostring(loadFn))
        notifyUser("PSD Hub Error", "Failed to compile script.")
        return
    end

    local runSuccess, runError = pcall(loadFn)
    if not runSuccess then
        warn("[PSD Hub] Execution error: " .. tostring(runError))
        notifyUser("PSD Hub Error", "Execution error occurred.")
    else
        print("[PSD Hub] Successfully loaded and initialized!")
    end
end

execute()

