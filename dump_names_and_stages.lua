--[[
    DumpNamesAndStages.lua (No JSONEncode - Raw String Builder to prevent cyclic crash)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

print("==================================================")
print("  🔬 Scanning Names & Stage Positions...")
print("==================================================")

local lines = {}
local function log(str)
    table.insert(lines, str)
end

log("=== ORE CONFIG DATA ===")
pcall(function()
    local oreFolder = ReplicatedStorage:FindFirstChild("Config") and ReplicatedStorage.Config:FindFirstChild("Ore")
    if oreFolder then
        for _, m in ipairs(oreFolder:GetDescendants()) do
            if m:IsA("ModuleScript") then
                log("[OreModule: " .. m.Name .. "]")
                local ok, data = pcall(function() return require(m) end)
                if ok and type(data) == "table" then
                    for k, v in pairs(data) do
                        if type(v) == "table" then
                            local summary = {}
                            for subK, subV in pairs(v) do
                                if type(subV) ~= "table" and type(subV) ~= "function" then
                                    table.insert(summary, tostring(subK) .. "=" .. tostring(subV))
                                end
                            end
                            log(tostring(k) .. ": {" .. table.concat(summary, ", ") .. "}")
                        else
                            log(tostring(k) .. "=" .. tostring(v))
                        end
                    end
                end
            end
        end
    end
end)

log("\n=== ENEMY CONFIG DATA ===")
pcall(function()
    local enemyFolder = ReplicatedStorage:FindFirstChild("Config") and ReplicatedStorage.Config:FindFirstChild("Enemy")
    if enemyFolder then
        for _, m in ipairs(enemyFolder:GetDescendants()) do
            if m:IsA("ModuleScript") then
                log("[EnemyModule: " .. m.Name .. "]")
                local ok, data = pcall(function() return require(m) end)
                if ok and type(data) == "table" then
                    for k, v in pairs(data) do
                        if type(v) == "table" then
                            local summary = {}
                            for subK, subV in pairs(v) do
                                if type(subV) ~= "table" and type(subV) ~= "function" then
                                    table.insert(summary, tostring(subK) .. "=" .. tostring(subV))
                                end
                            end
                            log(tostring(k) .. ": {" .. table.concat(summary, ", ") .. "}")
                        else
                            log(tostring(k) .. "=" .. tostring(v))
                        end
                    end
                end
            end
        end
    end
end)

log("\n=== WORKSPACE STAGE POSITIONS ===")
pcall(function()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local num = string.match(n, "^[Ss]tage[ _-]?(%d+)$") or string.match(n, "^[Zz]one[ _-]?(%d+)$") or string.match(n, "^[Rr]oom[ _-]?(%d+)$")
            if num then
                local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position)
                log("Stage " .. num .. " (" .. n .. "): Position = " .. tostring(pos))
            end
        end
    end
end)

log("\n=== CURRENT ACTIVE ENEMIES ===")
pcall(function()
    local ef = Workspace:FindFirstChild("EnemyFolder")
    if ef then
        for _, enemy in ipairs(ef:GetChildren()) do
            local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            log(string.format("Enemy: %s | ID: %s | HP: %s | Pos: %s",
                enemy.Name,
                tostring(enemy:GetAttribute("EnemyID")),
                hum and tostring(hum.Health) or "nil",
                root and tostring(root.Position) or "nil"
            ))
        end
    end
end)

local finalOutput = table.concat(lines, "\n")

pcall(function()
    if typeof(setclipboard) == "function" then
        setclipboard(finalOutput)
    elseif typeof(toclipboard) == "function" then
        toclipboard(finalOutput)
    end
    if typeof(writefile) == "function" then
        writefile("PSD_Hub/names_and_stages.txt", finalOutput)
    end
end)

print("==================================================")
print("  ✅ DUMP SUCCESSFUL! Copied text to clipboard.")
print("==================================================")
