--[[
    ScanOreCacheAndStages.lua
    Run this script in executor while inside Loot to Forge.
    It inspects:
    1. Workspace.OreCache (Ores, Parts, ProximityPrompts, Attributes)
    2. Workspace for Stage markers, PointIDs, Spawn points, Zones
    3. ReplicatedStorage.Config.Stage data (PointID definitions, stage positions)
--]]

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

print("==================================================")
print("  🔬 Scanning OreCache & Stage Structure...")
print("==================================================")

local result = {
    PlayerPosition = localPlayer.Character and tostring(localPlayer.Character:GetPivot().Position),
    OreCache = {
        Found = false,
        Count = 0,
        Samples = {},
    },
    WorkspaceStages = {},
    ReplicatedStorageStagePoints = {},
}

-- 1. Scan Workspace.OreCache
pcall(function()
    local oreCache = Workspace:FindFirstChild("OreCache")
    if oreCache then
        result.OreCache.Found = true
        result.OreCache.Count = #oreCache:GetChildren()
        for i, child in ipairs(oreCache:GetChildren()) do
            if i > 15 then break end
            local sample = {
                Name = child.Name,
                Class = child.ClassName,
                Position = child:IsA("BasePart") and tostring(child.Position) or (child.PrimaryPart and tostring(child.PrimaryPart.Position)),
                Attributes = child:GetAttributes(),
                Children = {},
            }
            for _, sub in ipairs(child:GetChildren()) do
                local subInfo = { Name = sub.Name, Class = sub.ClassName }
                if sub:IsA("ProximityPrompt") then
                    subInfo.ActionText = sub.ActionText
                    subInfo.ObjectText = sub.ObjectText
                    subInfo.HoldDuration = sub.HoldDuration
                    subInfo.MaxActivationDistance = sub.MaxActivationDistance
                    subInfo.RequiresLineOfSight = sub.RequiresLineOfSight
                end
                table.insert(sample.Children, subInfo)
            end
            table.insert(result.OreCache.Samples, sample)
        end
    end
end)

-- 2. Scan Workspace for Stage / Map / Point / Zone parts
pcall(function()
    for _, child in ipairs(Workspace:GetChildren()) do
        local n = child.Name:lower()
        if n:find("stage") or n:find("point") or n:find("zone") or n:find("room") or n:find("map") or n:find("spawn") or n:find("gate") then
            local sample = {
                Name = child.Name,
                Class = child.ClassName,
                ChildCount = #child:GetChildren(),
                SubSample = {},
            }
            for i, sub in ipairs(child:GetChildren()) do
                if i > 10 then break end
                table.insert(sample.SubSample, {
                    Name = sub.Name,
                    Class = sub.ClassName,
                    Position = sub:IsA("BasePart") and tostring(sub.Position) or (sub.PrimaryPart and tostring(sub.PrimaryPart.Position)),
                    Attributes = sub:GetAttributes(),
                })
            end
            table.insert(result.WorkspaceStages, sample)
        end
    end
end)

-- 3. Check ReplicatedStorage for Stage Points or Stage Position Configs
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("ModuleScript") and desc.Name:lower():find("point") then
            local ok, mod = pcall(function() return require(desc) end)
            if ok and type(mod) == "table" then
                result.ReplicatedStorageStagePoints[desc:GetFullName()] = mod
            end
        end
    end
end)

-- 4. Check EnemyFolder current enemies & positions
pcall(function()
    local ef = Workspace:FindFirstChild("EnemyFolder")
    if ef then
        result.EnemyFolderCount = #ef:GetChildren()
        result.EnemyPositions = {}
        for i, enemy in ipairs(ef:GetChildren()) do
            if i > 20 then break end
            local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            table.insert(result.EnemyPositions, {
                Name = enemy.Name,
                EnemyID = enemy:GetAttribute("EnemyID"),
                Position = root and tostring(root.Position),
            })
        end
    end
end)

local json = HttpService:JSONEncode(result)
pcall(function()
    if typeof(setclipboard) == "function" then
        setclipboard(json)
    elseif typeof(toclipboard) == "function" then
        toclipboard(json)
    end
    if typeof(writefile) == "function" then
        writefile("PSD_Hub/ore_cache_scan.json", json)
    end
end)

print("==================================================")
print("  ✅ Scan finished! Copied to clipboard.")
print("  OreCache found: " .. tostring(result.OreCache.Found) .. " (" .. result.OreCache.Count .. " items)")
print("==================================================")
