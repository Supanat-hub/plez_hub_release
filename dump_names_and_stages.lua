--[[
    DumpNamesAndStages.lua (Safe Non-Cyclic Serializer)
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local result = {
    OreNames = {},
    MobNames = {},
    StagePositions = {},
    LanguageModules = {},
}

-- Safe table copy that strips circular references and non-primitives
local function safeDeepCopy(tbl, maxDepth, seen)
    maxDepth = maxDepth or 2
    seen = seen or {}
    if maxDepth <= 0 then return "<depth>" end
    if type(tbl) ~= "table" then
        if type(tbl) == "string" or type(tbl) == "number" or type(tbl) == "boolean" then
            return tbl
        else
            return tostring(tbl)
        end
    end
    if seen[tbl] then return "<cyclic>" end
    seen[tbl] = true

    local copy = {}
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
        if count > 60 then
            copy["_more"] = "..."
            break
        end
        local sk = tostring(k)
        if type(v) == "table" then
            copy[sk] = safeDeepCopy(v, maxDepth - 1, seen)
        elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
            copy[sk] = v
        else
            copy[sk] = tostring(v)
        end
    end
    seen[tbl] = nil
    return copy
end

-- 1. Search Language / Localization
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local n = desc.Name:lower()
            if n:find("lang") or n:find("text") or n:find("i18n") or n:find("locale") or n:find("string") then
                local ok, data = pcall(function() return require(desc) end)
                if ok and type(data) == "table" then
                    result.LanguageModules[desc:GetFullName()] = safeDeepCopy(data, 2)
                end
            end
        end
    end
end)

-- 2. Inspect ReplicatedStorage.Config.Ore
pcall(function()
    if ReplicatedStorage:FindFirstChild("Config") and ReplicatedStorage.Config:FindFirstChild("Ore") then
        for _, desc in ipairs(ReplicatedStorage.Config.Ore:GetDescendants()) do
            if desc:IsA("ModuleScript") then
                local ok, data = pcall(function() return require(desc) end)
                if ok and type(data) == "table" then
                    result.OreNames[desc.Name] = safeDeepCopy(data, 2)
                end
            end
        end
    end
end)

-- 3. Inspect ReplicatedStorage.Config.Enemy
pcall(function()
    if ReplicatedStorage:FindFirstChild("Config") and ReplicatedStorage.Config:FindFirstChild("Enemy") then
        for _, desc in ipairs(ReplicatedStorage.Config.Enemy:GetDescendants()) do
            if desc:IsA("ModuleScript") then
                local ok, data = pcall(function() return require(desc) end)
                if ok and type(data) == "table" then
                    result.MobNames[desc.Name] = safeDeepCopy(data, 2)
                end
            end
        end
    end
end)

-- 4. Find all Stage parts in Workspace
pcall(function()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local num = string.match(n, "^[Ss]tage[ _-]?(%d+)$") or string.match(n, "^[Zz]one[ _-]?(%d+)$") or string.match(n, "^[Rr]oom[ _-]?(%d+)$")
            if num then
                local stageNum = tonumber(num)
                local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position)
                result.StagePositions[tostring(stageNum)] = {
                    Name = n,
                    Position = tostring(pos),
                    Class = obj.ClassName,
                }
            end
        end
    end
end)

-- 5. Scan active enemies
pcall(function()
    local ef = Workspace:FindFirstChild("EnemyFolder")
    if ef then
        result.CurrentEnemiesInFolder = {}
        for _, enemy in ipairs(ef:GetChildren()) do
            local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
            table.insert(result.CurrentEnemiesInFolder, {
                Name = enemy.Name,
                EnemyID = enemy:GetAttribute("EnemyID"),
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
print("  ✅ Dump Completed Successfully!")
print("  Copied to Clipboard!")
print("==================================================")
