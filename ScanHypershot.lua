--[[
    PSD Hub — Hypershot Universal Humanoid & Entity Scanner v4
    Scans:
    1. Every Humanoid in Workspace (Players, Bots, Mobs, Viewmodels)
    2. Exact Location (Parent, Grandparent)
    3. Part names (Head, HRP, FakeHRP, Torso, UpperTorso)
    4. Team attributes & Game Highlights (PlayerOutline, EnemyHighlight)
    5. GameData.IsEnemy & GameData.IsAlive evaluation
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

print("==================================================")
print("  🔍 Starting Universal Humanoid Scan v4...")
print("==================================================")

local scanData = {
    ScanTime = os.time(),
    LocalPlayerName = localPlayer.Name,
    LocalPlayerTeam = localPlayer:GetAttribute("Team"),
    GameInfo = {},
    HumanoidsInWorkspace = {},
}

pcall(function()
    local gi = ReplicatedStorage:FindFirstChild("GameInfo")
    if gi then
        scanData.GameInfo = gi:GetAttributes()
    end
end)

-- Scan every Humanoid in Workspace
for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc:IsA("Humanoid") then
        local model = desc.Parent
        if model and model:IsA("Model") then
            local pObj = Players:GetPlayerFromCharacter(model) or Players:FindFirstChild(model.Name)
            local isLocal = (model == localPlayer.Character or pObj == localPlayer)

            local parts = {}
            local highlights = {}
            for _, c in ipairs(model:GetChildren()) do
                if c:IsA("BasePart") then
                    table.insert(parts, c.Name)
                elseif c:IsA("Highlight") then
                    table.insert(highlights, {
                        Name = c.Name,
                        Enabled = c.Enabled,
                        FillColor = tostring(c.FillColor),
                        OutlineColor = tostring(c.OutlineColor),
                    })
                end
            end

            local parentPath = model.Parent and model.Parent:GetFullName() or "nil"

            table.insert(scanData.HumanoidsInWorkspace, {
                ModelName = model.Name,
                IsLocal = isLocal,
                IsPlayer = (pObj ~= nil),
                PlayerName = pObj and pObj.Name or nil,
                PlayerTeam = pObj and pObj:GetAttribute("Team") or nil,
                ModelTeam = model:GetAttribute("Team"),
                Health = desc.Health,
                MaxHealth = desc.MaxHealth,
                ParentPath = parentPath,
                ParentName = model.Parent and model.Parent.Name or "nil",
                Attributes = model:GetAttributes(),
                Parts = parts,
                Highlights = highlights,
                HasHRP = model:FindFirstChild("HumanoidRootPart") ~= nil,
                HasFakeHRP = model:FindFirstChild("FakeHRP") ~= nil,
                HasUpperTorso = model:FindFirstChild("UpperTorso") ~= nil,
                HasHead = model:FindFirstChild("Head") ~= nil,
                HasEnemyHighlight = model:FindFirstChild("EnemyHighlight") ~= nil,
                HasPlayerOutline = model:FindFirstChild("PlayerOutline") ~= nil,
            })
        end
    end
end

local jsonStr = HttpService:JSONEncode(scanData)

pcall(function()
    if makefolder and not isfolder("PSD_Hub") then makefolder("PSD_Hub") end
    if writefile then
        writefile("PSD_Hub/hypershot_all_humanoids.json", jsonStr)
        print("[UniversalScan] Saved to: PSD_Hub/hypershot_all_humanoids.json")
    end
end)

pcall(function()
    local fn = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
    if typeof(fn) == "function" then
        fn(jsonStr)
        print("[UniversalScan] JSON copied to clipboard!")
    end
end)

print("==================================================")
print(string.format("  ✅ TOTAL HUMANOIDS FOUND: %d", #scanData.HumanoidsInWorkspace))
print("==================================================")
