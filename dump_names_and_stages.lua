--[[
    DumpNamesAndStages.lua
    Dumps:
    1. ReplicatedStorage Language / Localization / Config for Ore names & Mob names
    2. Exact Stage positions from Workspace / ReplicatedStorage
    3. Ore model names and displayed texts
--]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local result = {
    OreNames = {},
    MobNames = {},
    StagePositions = {},
    LanguageModules = {},
}

-- 1. Search for Language / Translation / Name configs in ReplicatedStorage
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local n = desc.Name:lower()
            if n:find("lang") or n:find("text") or n:find("name") or n:find("i18n") or n:find("locale") or n:find("string") then
                local ok, data = pcall(function() return require(desc) end)
                if ok and type(data) == "table" then
                    result.LanguageModules[desc:GetFullName()] = data
                end
            end
        end
    end
end)

-- 2. Inspect ReplicatedStorage.Config.Ore
pcall(function()
    for _, desc in ipairs(ReplicatedStorage.Config.Ore:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local ok, data = pcall(function() return require(desc) end)
            if ok and type(data) == "table" then
                result.OreNames[desc:GetFullName()] = data
            end
        end
    end
end)

-- 3. Inspect ReplicatedStorage.Config.Enemy
pcall(function()
    for _, desc in ipairs(ReplicatedStorage.Config.Enemy:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local ok, data = pcall(function() return require(desc) end)
            if ok and type(data) == "table" then
                result.MobNames[desc:GetFullName()] = data
            end
        end
    end
end)

-- 4. Find all Stage parts / models in Workspace to get 100% exact coordinates for all 27 stages
pcall(function()
    -- Look for models or folders with numbers 1 to 27 or "Stage"
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local num = string.match(n, "^[Ss]tage[ _-]?(%d+)$") or string.match(n, "^[Zz]one[ _-]?(%d+)$") or string.match(n, "^[Rr]oom[ _-]?(%d+)$")
            if num then
                local stageNum = tonumber(num)
                local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position)
                result.StagePositions[stageNum] = {
                    Name = n,
                    Position = tostring(pos),
                    Class = obj.ClassName,
                    Parent = obj.Parent and obj.Parent.Name,
                }
            end
        end
    end
end)

-- 5. Scan current EnemyFolder to map each active enemy's position to its real stage
pcall(function()
    local ef = Workspace:FindFirstChild("EnemyFolder")
    if ef then
        result.CurrentEnemiesInFolder = {}
        for _, enemy in ipairs(ef:GetChildren()) do
            local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
            table.insert(result.CurrentEnemiesInFolder, {
                Name = enemy.Name,
                EnemyID = enemy:GetAttribute("EnemyID"),
                Attributes = enemy:GetAttributes(),
                Position = root and tostring(root.Position),
            })
        end
    end
end)

local json = HttpService:JSONEncode(result)
pcall(function()
    if typeof(setclipboard) == "function" then setclipboard(json) end
    if typeof(writefile) == "function" then writefile("PSD_Hub/names_and_stages.json", json) end
end)

print("==================================================")
print("  ✅ DumpNamesAndStages Completed!")
print("  Stage Positions Found: " .. tostring(#result.StagePositions))
print("  Ore Configs Found: " .. tostring(#result.OreNames))
print("  Copied to Clipboard!")
print("==================================================")
