--[[
    Hypershot Ultra-Deep Diagnostic Scanner v3
    Run this script in your executor during an active match.
    It inspects:
    1. Every player & character (Attributes, Children, Highlights, Teams)
    2. Exact evaluation of IsEnemy, IsAlive, IsVisible on every player
    3. Workspace & Camera for Viewmodels, Raycast Obstructions & Map geometry
    4. ReplicatedStorage GameInfo & Gamemode rules
    Results are saved to PSD_Hub/hypershot_deep_scan.json and copied to clipboard.
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

print("==================================================")
print("  🔬 Starting Hypershot Ultra-Deep Diagnostic Scan...")
print("==================================================")

local scanData = {
    ScanTime = os.time(),
    GameInfo = {
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        JobId = game.JobId,
        PlayerCount = #Players:GetPlayers(),
        LocalPlayerName = localPlayer.Name,
        LocalPlayerUserId = localPlayer.UserId,
    },
    ReplicatedStorage_GameInfo = nil,
    CameraChildren = {},
    WorkspaceTopLevel = {},
    PlayersEvaluation = {},
    RaycastDiagnostics = {},
}

-- 1. Scan ReplicatedStorage.GameInfo
pcall(function()
    local gi = ReplicatedStorage:FindFirstChild("GameInfo")
    if gi then
        scanData.ReplicatedStorage_GameInfo = {
            ClassName = gi.ClassName,
            Attributes = gi:GetAttributes(),
            ChildrenCount = #gi:GetChildren(),
        }
    end
end)

-- 2. Scan Camera Children (Detecting ViewModels / Guns that might block WallCheck)
pcall(function()
    for _, child in ipairs(camera:GetChildren()) do
        table.insert(scanData.CameraChildren, {
            Name = child.Name,
            Class = child.ClassName,
            ChildrenCount = #child:GetChildren(),
        })
    end
end)

-- 3. Scan Workspace Top Level (Detecting ViewModel / Arms / Ignore folders)
pcall(function()
    for _, child in ipairs(Workspace:GetChildren()) do
        local n = child.Name:lower()
        if n:find("view") or n:find("arm") or n:find("gun") or n:find("weapon") or n:find("ignore") or n:find("mob") or n:find("player") or n:find("character") then
            table.insert(scanData.WorkspaceTopLevel, {
                Name = child.Name,
                Class = child.ClassName,
                ChildrenCount = #child:GetChildren(),
            })
        end
    end
end)

-- Local Player Attributes
local localTeamAttr = localPlayer:GetAttribute("Team")
local localChar = localPlayer.Character
local localCharTeamAttr = localChar and localChar:GetAttribute("Team")

-- 4. Deep Player Scan & Realtime Targeting Evaluation
for _, player in ipairs(Players:GetPlayers()) do
    local isLocal = (player == localPlayer)
    local char = player.Character

    local pEval = {
        Name = player.Name,
        DisplayName = player.DisplayName,
        UserId = player.UserId,
        IsLocal = isLocal,
        PlayerAttributes = player:GetAttributes(),
        PlayerTeamProp = player.Team and player.Team.Name or "nil",
        PlayerTeamColor = player.TeamColor and tostring(player.TeamColor) or "nil",
        Neutral = player.Neutral,
        Character = nil,
        TargetingAnalysis = {},
    }

    if char then
        local charChildren = {}
        local highlights = {}
        local partsList = {}

        pcall(function()
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Highlight") then
                    table.insert(highlights, {
                        Name = child.Name,
                        Enabled = child.Enabled,
                        FillColor = tostring(child.FillColor),
                        OutlineColor = tostring(child.OutlineColor),
                        FillTransparency = child.FillTransparency,
                        OutlineTransparency = child.OutlineTransparency,
                        DepthMode = tostring(child.DepthMode),
                    })
                elseif child:IsA("BasePart") then
                    table.insert(partsList, child.Name)
                end
                table.insert(charChildren, {
                    Name = child.Name,
                    Class = child.ClassName,
                })
            end
        end)

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        local head = char:FindFirstChild("Head")

        pEval.Character = {
            Name = char.Name,
            Parent = char.Parent and char.Parent.Name or "nil",
            Attributes = char:GetAttributes(),
            Tags = CollectionService:GetTags(char),
            Highlights = highlights,
            BaseParts = partsList,
            HumanoidHealth = humanoid and humanoid.Health or 0,
            HumanoidMaxHealth = humanoid and humanoid.MaxHealth or 0,
            Position = rootPart and tostring(rootPart.Position) or "nil",
        }

        -- Analyze targeting logic
        local isAlive = (char.Parent and char.Parent.Name ~= "IgnoreThese" and char:GetAttribute("CorpseClone") ~= true and humanoid and humanoid.Health > 0 and rootPart ~= nil)
        local isLobby = (char:GetAttribute("LobbyCharacter") == true or player:GetAttribute("LobbyCharacterSpawning") == true)
        local hasEnemyHighlight = (char:FindFirstChild("EnemyHighlight") ~= nil)
        local hasPlayerOutline = (char:FindFirstChild("PlayerOutline") ~= nil)

        -- Raycast test from Camera to Head and RootPart
        local headVisible = false
        local headHitInfo = "No Raycast"
        if head and camera then
            local origin = camera.CFrame.Position
            local dest = head.Position
            local dir = dest - origin
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { camera, localChar, Workspace:FindFirstChild("IgnoreThese") }
            local hit = Workspace:Raycast(origin, dir, params)
            if not hit then
                headVisible = true
                headHitInfo = "Clear (No obstruction)"
            else
                local hp = hit.Instance
                local isOwn = hp:IsDescendantOf(char)
                headVisible = isOwn or ((dest - hit.Position).Magnitude <= 3.5)
                headHitInfo = string.format("Hit: %s (Class: %s, Parent: %s, Own: %s, DistToDest: %.2f)",
                    hp.Name, hp.ClassName, hp.Parent and hp.Parent.Name or "nil", tostring(isOwn), (dest - hit.Position).Magnitude)
            end
        end

        local screenPos, onScreen = Vector2.zero, false
        if head and camera then
            local vPos, os = camera:WorldToViewportPoint(head.Position)
            screenPos = Vector2.new(vPos.X, vPos.Y)
            onScreen = os
        end

        pEval.TargetingAnalysis = {
            IsAlive = isAlive,
            IsLobby = isLobby,
            HasEnemyHighlight = hasEnemyHighlight,
            HasPlayerOutline = hasPlayerOutline,
            HeadVisible = headVisible,
            HeadRaycastDetail = headHitInfo,
            OnScreen = onScreen,
            ScreenPos = tostring(screenPos),
            TeamAttr_Player = player:GetAttribute("Team"),
            TeamAttr_Char = char:GetAttribute("Team"),
        }
    end

    table.insert(scanData.PlayersEvaluation, pEval)
end

-- 5. Scan Workspace.Mobs (Bots playing in the match)
scanData.MobsEvaluation = {}
pcall(function()
    local mobsFolder = Workspace:FindFirstChild("Mobs")
    if mobsFolder then
        for _, mob in ipairs(mobsFolder:GetChildren()) do
            if mob:IsA("Model") then
                local humanoid = mob:FindFirstChildOfClass("Humanoid")
                local root = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
                local highlights = {}
                for _, c in ipairs(mob:GetChildren()) do
                    if c:IsA("Highlight") then
                        table.insert(highlights, {
                            Name = c.Name,
                            FillColor = tostring(c.FillColor),
                            OutlineColor = tostring(c.OutlineColor),
                            Enabled = c.Enabled
                        })
                    end
                end
                table.insert(scanData.MobsEvaluation, {
                    Name = mob.Name,
                    Class = mob.ClassName,
                    TeamAttr = mob:GetAttribute("Team"),
                    AllAttributes = mob:GetAttributes(),
                    Health = humanoid and humanoid.Health or 0,
                    Highlights = highlights,
                    Parent = mob.Parent and mob.Parent.Name or "nil",
                    HasEnemyHighlight = mob:FindFirstChild("EnemyHighlight") ~= nil,
                    HasPlayerOutline = mob:FindFirstChild("PlayerOutline") ~= nil,
                })
            end
        end
    end
end)

-- Serialize and Save
local jsonStr = HttpService:JSONEncode(scanData)

pcall(function()
    if makefolder and not isfolder("PSD_Hub") then makefolder("PSD_Hub") end
    if writefile then
        writefile("PSD_Hub/hypershot_deep_scan.json", jsonStr)
        print("[HypershotDeepScan] Saved to: PSD_Hub/hypershot_deep_scan.json")
    end
end)

pcall(function()
    if setclipboard then
        setclipboard(jsonStr)
        print("[HypershotDeepScan] JSON successfully copied to clipboard!")
    end
end)

print("==================================================")
print("  ✅ HYPERSHOT ULTRA-DEEP SCAN COMPLETED!")
print(string.format("  Players Scanned: %d", #scanData.PlayersEvaluation))
print("  Paste the JSON or file contents to the chat!")
print("==================================================")
