--[[
    PSD Hub — Hypershot (FPS) Diagnostic Scanner
    PlaceId: 17516596118

    Inspects:
    1. Characters & Hitboxes:
       - Character location (Workspace, Players folder, Characters folder)
       - Rig type (R6, R15, Custom)
       - Target parts (Head, Torso, UpperTorso, HumanoidRootPart)
       - Health & Alive status (Humanoid.Health, Attributes, ObjectValues)
    2. Teams & Opponents:
       - Teams service, player.Team, player.TeamColor, Attributes
       - Opponent vs Teammate identification logic
    3. Viewmodels & Weapons:
       - CurrentCamera children (FPS Viewmodels, Arms, Guns)
       - Character/Backpack equipped tools or weapon objects
       - Weapon stats/attributes (Ammo, Recoil, Spread, Firerate)
       - Client weapon scripts in PlayerScripts / Character
    4. Network Remotes & Modules:
       - ReplicatedStorage remotes related to shooting, hitting, reloading
       - Weapon data modules, Knit/Replica/ByteNet services

    Outputs:
    - Saved to: PSD_Hub/hypershot_scan.json
    - Copied to clipboard via setclipboard()
    - Printed to F9 Console
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Teams = game:GetService("Teams")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local function log(msg)
    print("[HypershotScanner] " .. tostring(msg))
end

local function notifyUser(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 6,
        })
    end)
end

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
    if typeof(fn) == "function" then
        return pcall(function() fn(text) end)
    end
    return false
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

log("Starting Hypershot FPS Diagnostic Scan...")
notifyUser("PSD Scanner", "Scanning Hypershot environment...")

local report = {
    GameInfo = {
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        JobId = game.JobId,
        PlayerCount = #Players:GetPlayers(),
        LocalPlayerName = localPlayer.Name,
        LocalPlayerUserId = localPlayer.UserId,
    },
    Teams = {},
    CharacterAnalysis = {},
    ViewmodelsAndWeapons = {},
    CombatRemotes = {},
    WeaponDataModules = {},
    WorkspaceFolders = {},
}

-- ==================================================
-- 1. Teams Analysis
-- ==================================================
local teamsList = Teams:GetTeams()
report.Teams.TeamsServiceCount = #teamsList
report.Teams.RegisteredTeams = {}
for _, team in ipairs(teamsList) do
    table.insert(report.Teams.RegisteredTeams, {
        Name = team.Name,
        TeamColor = tostring(team.TeamColor),
        AutoAssignable = team.AutoAssignable,
    })
end

report.Teams.LocalPlayerTeam = {
    Team = localPlayer.Team and localPlayer.Team.Name or "nil",
    TeamColor = tostring(localPlayer.TeamColor),
    Attributes = localPlayer:GetAttributes(),
}

-- ==================================================
-- 2. Characters & Hitboxes Analysis
-- ==================================================
-- Check where characters are stored
local possibleFolders = {
    "Players", "Characters", "Entities", "Living", "Rigs", "Actors", "Bots", "Zombies"
}
report.WorkspaceFolders = {}
for _, child in ipairs(Workspace:GetChildren()) do
    if child:IsA("Folder") or child:IsA("Model") then
        local childCount = #child:GetChildren()
        report.WorkspaceFolders[child.Name] = {
            Class = child.ClassName,
            ChildCount = childCount,
            SampleChildren = {},
        }
        for i = 1, math.min(5, childCount) do
            local sample = child:GetChildren()[i]
            table.insert(report.WorkspaceFolders[child.Name].SampleChildren, {
                Name = sample.Name,
                Class = sample.ClassName,
            })
        end
    end
end

-- Inspect LocalPlayer Character & Other Players
local function inspectCharacter(char, ownerPlayer)
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local head = char:FindFirstChild("Head")

    local partsList = {}
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(partsList, part.Name)
        end
    end

    local toolsList = {}
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") or item.Name:lower():find("gun") or item.Name:lower():find("weapon") then
            table.insert(toolsList, {
                Name = item.Name,
                Class = item.ClassName,
                Attributes = item:GetAttributes(),
            })
        end
    end

    return {
        Owner = ownerPlayer and ownerPlayer.Name or "Unknown",
        ModelName = char.Name,
        Parent = char.Parent and char.Parent.Name or "nil",
        RigType = humanoid and tostring(humanoid.RigType) or "Unknown",
        HasHumanoid = humanoid ~= nil,
        Health = humanoid and humanoid.Health or nil,
        MaxHealth = humanoid and humanoid.MaxHealth or nil,
        HasHead = head ~= nil,
        HasRootPart = rootPart ~= nil,
        HeadSize = head and tostring(head.Size) or nil,
        RootPartSize = rootPart and tostring(rootPart.Size) or nil,
        Parts = partsList,
        EquippedItems = toolsList,
        Attributes = char:GetAttributes(),
    }
end

report.CharacterAnalysis.LocalPlayer = inspectCharacter(localPlayer.Character, localPlayer)

report.CharacterAnalysis.OtherPlayersSample = {}
local sampleCount = 0
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= localPlayer and p.Character and sampleCount < 3 then
        table.insert(report.CharacterAnalysis.OtherPlayersSample, inspectCharacter(p.Character, p))
        sampleCount = sampleCount + 1
    end
end

-- ==================================================
-- 3. Viewmodels & Weapons (CurrentCamera & Backpack)
-- ==================================================
report.ViewmodelsAndWeapons.CameraChildren = {}
for _, child in ipairs(camera:GetChildren()) do
    table.insert(report.ViewmodelsAndWeapons.CameraChildren, {
        Name = child.Name,
        Class = child.ClassName,
        ChildCount = #child:GetChildren(),
    })
end

report.ViewmodelsAndWeapons.BackpackTools = {}
local backpack = localPlayer:FindFirstChildOfClass("Backpack")
if backpack then
    for _, tool in ipairs(backpack:GetChildren()) do
        table.insert(report.ViewmodelsAndWeapons.BackpackTools, {
            Name = tool.Name,
            Class = tool.ClassName,
            Attributes = tool:GetAttributes(),
            Children = (function()
                local c = {}
                for _, sub in ipairs(tool:GetChildren()) do
                    table.insert(c, sub.Name .. " (" .. sub.ClassName .. ")")
                end
                return c
            end)(),
        })
    end
end

-- Inspect LocalPlayer Scripts
report.ViewmodelsAndWeapons.PlayerScripts = {}
local playerScripts = localPlayer:FindFirstChildOfClass("PlayerScripts")
if playerScripts then
    for _, s in ipairs(playerScripts:GetDescendants()) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
            local n = s.Name:lower()
            if n:find("gun") or n:find("weapon") or n:find("shoot") or n:find("combat") or n:find("fps") or n:find("viewmodel") or n:find("cam") then
                table.insert(report.ViewmodelsAndWeapons.PlayerScripts, {
                    Path = s:GetFullName(),
                    Name = s.Name,
                    Class = s.ClassName,
                })
            end
        end
    end
end

-- ==================================================
-- 4. ReplicatedStorage Remotes & Weapon Data
-- ==================================================
local combatKeywords = {
    "shoot", "fire", "hit", "damage", "bullet", "reload", "gun", "weapon", "combat", "ray", "cast", "knife", "ability", "skill", "kill"
}

for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        local nameLower = obj.Name:lower()
        local matches = false
        for _, kw in ipairs(combatKeywords) do
            if nameLower:find(kw) then
                matches = true
                break
            end
        end
        if matches or #report.CombatRemotes < 25 then
            table.insert(report.CombatRemotes, {
                Name = obj.Name,
                Class = obj.ClassName,
                Path = obj:GetFullName():gsub("^ReplicatedStorage%.", ""),
            })
        end
    elseif obj:IsA("ModuleScript") then
        local nameLower = obj.Name:lower()
        for _, kw in ipairs(combatKeywords) do
            if nameLower:find(kw) then
                table.insert(report.WeaponDataModules, {
                    Name = obj.Name,
                    Path = obj:GetFullName():gsub("^ReplicatedStorage%.", ""),
                })
                break
            end
        end
    end
end

-- ==================================================
-- Final Output Generation
-- ==================================================
local jsonReport = HttpService:JSONEncode(report)

safeWriteFile("PSD_Hub/hypershot_scan.json", jsonReport)
local copied = copyToClipboard(jsonReport)

log("==================================================")
log("  HYPERSHOT SCAN COMPLETED!")
log("  Saved to: PSD_Hub/hypershot_scan.json")
if copied then
    log("  JSON successfully copied to clipboard!")
    notifyUser("PSD Scanner Complete", "Data copied to clipboard & saved to file!")
else
    log("  Clipboard copy failed (not supported). Check PSD_Hub/hypershot_scan.json")
    notifyUser("PSD Scanner Complete", "Saved to PSD_Hub/hypershot_scan.json")
end
log("==================================================")

return report
