--[[
    Loot to Forge — Diagnostic Scanner
    Run this script in your executor while inside the "Loot to Forge" game.
    
    It inspects:
    1. PlaceId and Game Information
    2. ReplicatedStorage (Remotes, Knit services, Item/Ore modules, Mob modules, Crafting configs)
    3. Workspace.EnemyFolder (Stage layout, Mob models, Humanoids, Attributes, Positions)
    4. Workspace Drops / Loot / Forge / Craft stations / Base locations
    5. LocalPlayer Backpack, Inventory, Stats, and PlayerGui Capacity UI
    
    Results are saved to:
    - PSD_Hub/loot_to_forge_scan.json
    - Copied to your clipboard automatically!
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

print("==================================================")
print("  🔬 Starting Loot to Forge Diagnostic Scan...")
print("==================================================")

local scanData = {
    ScanTime = os.time(),
    GameInfo = {
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        JobId = game.JobId,
        LocalPlayerName = localPlayer and localPlayer.Name or "Unknown",
        LocalPlayerUserId = localPlayer and localPlayer.UserId or 0,
    },
    LocalPlayerState = {},
    Workspace_EnemyFolder = nil,
    Workspace_DropsAndLoot = {},
    Workspace_StationsAndBase = {},
    ReplicatedStorage_Remotes = {},
    ReplicatedStorage_Modules = {},
    PlayerGui_InventoryUI = {},
}

-- Safe table sanitizer for JSON encoding
local function safeValue(v, depth)
    depth = depth or 0
    if depth > 3 then return "<depth limit>" end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then
        return v
    elseif t == "userdata" or typeof(v) == "Vector3" or typeof(v) == "CFrame" or typeof(v) == "Color3" then
        return tostring(v)
    elseif t == "table" then
        local cleaned = {}
        local count = 0
        for k, val in pairs(v) do
            count = count + 1
            if count > 50 then
                cleaned["_truncated"] = "more entries..."
                break
            end
            cleaned[tostring(k)] = safeValue(val, depth + 1)
        end
        return cleaned
    else
        return tostring(v)
    end
end

-- 1. Scan LocalPlayer State & Attributes
pcall(function()
    scanData.LocalPlayerState.Attributes = localPlayer:GetAttributes()
    local leaderstats = localPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        scanData.LocalPlayerState.Leaderstats = {}
        for _, v in ipairs(leaderstats:GetChildren()) do
            if v:IsA("ValueBase") then
                scanData.LocalPlayerState.Leaderstats[v.Name] = v.Value
            end
        end
    end
    
    -- Check tools in Backpack and Character
    scanData.LocalPlayerState.BackpackTools = {}
    local bp = localPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            table.insert(scanData.LocalPlayerState.BackpackTools, {
                Name = tool.Name,
                Class = tool.ClassName,
                Attributes = tool:GetAttributes(),
            })
        end
    end
    local char = localPlayer.Character
    if char then
        scanData.LocalPlayerState.CharacterPosition = char.PrimaryPart and tostring(char.PrimaryPart.Position) or (char:FindFirstChild("HumanoidRootPart") and tostring(char.HumanoidRootPart.Position))
        scanData.LocalPlayerState.EquippedTools = {}
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(scanData.LocalPlayerState.EquippedTools, {
                    Name = tool.Name,
                    Attributes = tool:GetAttributes(),
                })
            end
        end
    end
end)

-- 2. Scan ReplicatedStorage: Remotes & Data Modules
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        -- Remotes
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            table.insert(scanData.ReplicatedStorage_Remotes, {
                Name = desc.Name,
                Class = desc.ClassName,
                Path = desc:GetFullName(),
            })
        -- Modules that likely contain game data
        elseif desc:IsA("ModuleScript") then
            local n = desc.Name:lower()
            local shouldInspect = n:find("ore") or n:find("item") or n:find("mob") or n:find("enemy")
                or n:find("monster") or n:find("stage") or n:find("wave") or n:find("craft")
                or n:find("forge") or n:find("drop") or n:find("loot") or n:find("weapon")
                or n:find("tool") or n:find("config") or n:find("data") or n:find("inventory")
                or n:find("bag") or n:find("backpack") or n:find("stats")

            if shouldInspect then
                local modInfo = {
                    Name = desc.Name,
                    Path = desc:GetFullName(),
                    CanRequire = false,
                    DataSample = nil,
                }
                local ok, result = pcall(function()
                    return require(desc)
                end)
                if ok and type(result) == "table" then
                    modInfo.CanRequire = true
                    modInfo.DataSample = safeValue(result, 1)
                end
                table.insert(scanData.ReplicatedStorage_Modules, modInfo)
            end
        end
    end
end)

-- 3. Scan Workspace.EnemyFolder
pcall(function()
    local enemyFolder = Workspace:FindFirstChild("EnemyFolder")
    if not enemyFolder then
        -- Search if named differently (case-insensitive)
        for _, child in ipairs(Workspace:GetChildren()) do
            if child.Name:lower():find("enemy") or child.Name:lower():find("mob") or child.Name:lower():find("monster") then
                enemyFolder = child
                break
            end
        end
    end

    if enemyFolder then
        scanData.Workspace_EnemyFolder = {
            Name = enemyFolder.Name,
            Class = enemyFolder.ClassName,
            TotalChildren = #enemyFolder:GetChildren(),
            StructureType = "Flat", -- or "Stages"
            ChildrenSample = {},
        }

        local children = enemyFolder:GetChildren()
        -- Check if children are stage subfolders (e.g. Stage1, Stage2) or direct enemy models
        for i, child in ipairs(children) do
            if i > 25 then break end

            local isFolder = child:IsA("Folder") or (child:IsA("Model") and not child:FindFirstChildOfClass("Humanoid"))
            if isFolder then
                scanData.Workspace_EnemyFolder.StructureType = "Subfolders_or_Stages"
                local subSample = {
                    StageName = child.Name,
                    MobCount = #child:GetChildren(),
                    SampleMobs = {},
                }
                for j, subChild in ipairs(child:GetChildren()) do
                    if j > 5 then break end
                    local hum = subChild:FindFirstChildOfClass("Humanoid")
                    local root = subChild:FindFirstChild("HumanoidRootPart") or subChild.PrimaryPart
                    table.insert(subSample.SampleMobs, {
                        Name = subChild.Name,
                        Health = hum and hum.Health or nil,
                        MaxHealth = hum and hum.MaxHealth or nil,
                        Position = root and tostring(root.Position) or nil,
                        Attributes = subChild:GetAttributes(),
                    })
                end
                table.insert(scanData.Workspace_EnemyFolder.ChildrenSample, subSample)
            else
                local hum = child:FindFirstChildOfClass("Humanoid")
                local root = child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart
                table.insert(scanData.Workspace_EnemyFolder.ChildrenSample, {
                    Name = child.Name,
                    Health = hum and hum.Health or nil,
                    MaxHealth = hum and hum.MaxHealth or nil,
                    Position = root and tostring(root.Position) or nil,
                    Attributes = child:GetAttributes(),
                })
            end
        end
    else
        scanData.Workspace_EnemyFolder = { Note = "Workspace.EnemyFolder not found directly." }
    end
end)

-- 4. Scan Workspace for Drops, Ores, Loot, Craft Stations, Base
pcall(function()
    for _, child in ipairs(Workspace:GetChildren()) do
        local n = child.Name:lower()
        if n:find("drop") or n:find("loot") or n:find("ore") or n:find("debris") or n:find("item") or n:find("pickup") then
            table.insert(scanData.Workspace_DropsAndLoot, {
                Name = child.Name,
                Class = child.ClassName,
                ItemCount = #child:GetChildren(),
                SampleItems = (function()
                    local s = {}
                    for i, item in ipairs(child:GetChildren()) do
                        if i > 8 then break end
                        table.insert(s, {
                            Name = item.Name,
                            Class = item.ClassName,
                            Position = item:IsA("BasePart") and tostring(item.Position) or (item.PrimaryPart and tostring(item.PrimaryPart.Position)),
                            Attributes = item:GetAttributes(),
                        })
                    end
                    return s
                end)(),
            })
        elseif n:find("forge") or n:find("anvil") or n:find("craft") or n:find("base") or n:find("shop") or n:find("station") or n:find("spawn") then
            local pos = child:IsA("BasePart") and tostring(child.Position) or (child.PrimaryPart and tostring(child.PrimaryPart.Position))
            table.insert(scanData.Workspace_StationsAndBase, {
                Name = child.Name,
                Class = child.ClassName,
                Position = pos,
                Attributes = child:GetAttributes(),
            })
        end
    end
end)

-- 5. Scan PlayerGui for Inventory, Backpack, Crafting HUD
pcall(function()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name:lower()
                if n:find("inv") or n:find("bag") or n:find("pack") or n:find("craft") or n:find("forge") or n:find("hud") or n:find("main") or n:find("stage") then
                    local textSamples = {}
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if desc:IsA("TextLabel") and desc.Text and desc.Text ~= "" and #desc.Text < 50 then
                            table.insert(textSamples, {
                                LabelName = desc.Name,
                                Text = desc.Text,
                            })
                            if #textSamples > 15 then break end
                        end
                    end
                    table.insert(scanData.PlayerGui_InventoryUI, {
                        GuiName = gui.Name,
                        Enabled = gui.Enabled,
                        Texts = textSamples,
                    })
                end
            end
        end
    end
end)

-- ==============================
-- Output & Serialization
-- ==============================
local jsonOutput = nil
local ok, err = pcall(function()
    jsonOutput = HttpService:JSONEncode(scanData)
end)

if not ok or not jsonOutput then
    warn("[LootToForgeScanner] JSON Encode failed: " .. tostring(err))
    return
end

-- Save to file
local filePath = "PSD_Hub/loot_to_forge_scan.json"
pcall(function()
    if typeof(makefolder) == "function" and not isfolder("PSD_Hub") then
        makefolder("PSD_Hub")
    end
    if typeof(writefile) == "function" then
        writefile(filePath, jsonOutput)
        print("[LootToForgeScanner] Saved scan to: " .. filePath)
    end
end)

-- Copy to clipboard
local clipOk = pcall(function()
    if typeof(setclipboard) == "function" then
        setclipboard(jsonOutput)
        print("[LootToForgeScanner] JSON copied to clipboard successfully!")
    elseif typeof(toclipboard) == "function" then
        toclipboard(jsonOutput)
        print("[LootToForgeScanner] JSON copied to clipboard successfully!")
    end
end)

print("==================================================")
print("  ✅ LOOT TO FORGE SCAN COMPLETED!")
print("  PlaceId: " .. tostring(scanData.GameInfo.PlaceId))
print("  Remotes Found: " .. #scanData.ReplicatedStorage_Remotes)
print("  Modules Found: " .. #scanData.ReplicatedStorage_Modules)
print("  EnemyFolder: " .. (scanData.Workspace_EnemyFolder and scanData.Workspace_EnemyFolder.Name or "None"))
print("  Copy JSON from clipboard or file: " .. filePath)
print("==================================================")
