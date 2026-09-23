--[[
    Inspect Spawn Mechanics & Remotes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local lines = {}
local function log(str) table.insert(lines, str) end

log("=== INSPECTING ENEMYCTRL ===")
pcall(function()
    local enemyCtrl = require(ReplicatedStorage.CTRL.EnemyCTRL)
    if enemyCtrl then
        for k, v in pairs(enemyCtrl) do
            log("EnemyCTRL." .. tostring(k) .. " = " .. type(v))
        end
    end
end)

log("\n=== INSPECTING STAGE REMOTES & SCRIPTS ===")
pcall(function()
    local stageFolder = ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("Stage")
    if stageFolder then
        for _, r in ipairs(stageFolder:GetChildren()) do
            log(string.format("Stage Remote: %s (%s)", r.Name, r.ClassName))
        end
    end
end)

log("\n=== INSPECTING SUPERLOOT REMOTES ===")
pcall(function()
    local slFolder = ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("SuperLoot")
    if slFolder then
        for _, r in ipairs(slFolder:GetChildren()) do
            log(string.format("SuperLoot Remote: %s (%s)", r.Name, r.ClassName))
        end
    end
end)

log("\n=== LOCALPLAYER ATTRIBUTES ===")
pcall(function()
    for k, v in pairs(Players.LocalPlayer:GetAttributes()) do
        log(string.format("Attr %s = %s", tostring(k), tostring(v)))
    end
end)

-- Search for local scripts in PlayerScripts or Character to see how spawning is triggered
log("\n=== PLAYER SCRIPTS SCAN ===")
pcall(function()
    for _, s in ipairs(Players.LocalPlayer.PlayerScripts:GetDescendants()) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
            local n = s.Name:lower()
            if n:find("stage") or n:find("enemy") or n:find("mob") or n:find("spawn") or n:find("round") or n:find("dungeon") then
                log(string.format("Script: %s (%s) in %s", s.Name, s.ClassName, s.Parent.Name))
            end
        end
    end
end)

local out = table.concat(lines, "\n")
pcall(function()
    if typeof(setclipboard) == "function" then setclipboard(out) end
    if typeof(writefile) == "function" then writefile("PSD_Hub/spawn_mechanics.txt", out) end
end)

print("[SpawnInspect] Copied to clipboard!")
