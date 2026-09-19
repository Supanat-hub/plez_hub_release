--[[
    PSD Hub — Egg & Mutation Structure Diagnostic Scanner
    Scans live egg instances in workspace, player plots, and ReplicatedStorage.GameData
    to discover the exact attributes, tags, effects, and naming conventions used
    for standard and mutated eggs in Ride a Pet.

    Outputs:
    1. Console tree view (F9 / Developer Console)
    2. JSON dump saved to: PSD_Hub/egg_scan_dump.json
    3. Copied to system clipboard via setclipboard()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

local Scanner = {}

local function log(msg, isWarn)
    local formatted = "[EggScanner] " .. tostring(msg)
    if isWarn then
        warn(formatted)
    else
        print(formatted)
    end
    pcall(function()
        if typeof(rconsoleprint) == "function" then
            rconsoleprint(formatted .. "\n")
        end
    end)
end

local function notifyUser(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5,
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

local function serializeValue(val, depth)
    depth = depth or 0
    if depth > 5 then return "..." end

    local t = typeof(val)
    if t == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "Vector3" then
        return string.format("(%.1f, %.1f, %.1f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        return string.format("Pos(%.1f, %.1f, %.1f)", val.Position.X, val.Position.Y, val.Position.Z)
    elseif t == "Instance" then
        return val:GetFullName()
    elseif t == "table" then
        local safe = {}
        for k, v in pairs(val) do
            safe[tostring(k)] = serializeValue(v, depth + 1)
        end
        return safe
    elseif t == "string" or t == "number" or t == "boolean" then
        return val
    else
        return tostring(val)
    end
end

-- Inspects an individual egg instance and extracts all structural details
local function inspectEggInstance(egg)
    if not egg or not egg.Parent then return nil end

    local data = {
        Name = egg.Name,
        ClassName = egg.ClassName,
        Parent = egg.Parent and egg.Parent.Name or "None",
        Attributes = {},
        Tags = {},
        ProximityPrompts = {},
        VisualEffects = {},
        Guis = {},
        ValueObjects = {},
        PartsCount = 0,
        HasMutationHitbox = false,
        MutationAttribute = nil,
        SuspiciousKeywords = {},
        IsPotentiallyMutated = false,
    }

    -- 1. Attributes
    local okAttr, attrs = pcall(function() return egg:GetAttributes() end)
    if okAttr and attrs then
        for k, v in pairs(attrs) do
            data.Attributes[k] = serializeValue(v)
            if tostring(k):lower() == "mutation" then
                data.MutationAttribute = tostring(v)
            end
        end
    end

    -- 2. CollectionService Tags
    pcall(function()
        data.Tags = CollectionService:GetTags(egg)
    end)

    -- 3. Check for mutation keywords in Name
    local keywords = {"eternal", "void", "rage", "volted", "volt", "shocked", "shock", "thunder", "lightning", "mutated", "mutation"}
    local lowerName = egg.Name:lower()
    for _, kw in ipairs(keywords) do
        if lowerName:find(kw) then
            table.insert(data.SuspiciousKeywords, "NameContains:" .. kw)
        end
    end

    -- 4. Deep descendant scan
    for _, desc in ipairs(egg:GetDescendants()) do
        local dClass = desc.ClassName
        local dName = desc.Name
        local dLower = dName:lower()

        if dName == "MutationHitbox" then
            data.HasMutationHitbox = true
            table.insert(data.SuspiciousKeywords, "Part(MutationHitbox)")
        end

        -- Check particle and beam names for mutation effects
        if desc:IsA("ParticleEmitter") or desc:IsA("Beam") then
            for _, kw in ipairs({"lightning", "shock", "volt", "void", "rage", "eternal", "mutation"}) do
                if dLower:find(kw) then
                    table.insert(data.SuspiciousKeywords, string.format("%s(%s):%s", dClass, dName, kw))
                end
            end
        end

        if desc:IsA("BasePart") then
            data.PartsCount = data.PartsCount + 1
        elseif desc:IsA("Highlight") then
            table.insert(data.VisualEffects, {
                Type = "Highlight",
                Name = dName,
                FillColor = serializeValue(desc.FillColor),
                OutlineColor = serializeValue(desc.OutlineColor),
                Enabled = desc.Enabled,
            })
        elseif desc:IsA("ParticleEmitter") then
            table.insert(data.VisualEffects, {
                Type = "ParticleEmitter",
                Name = dName,
                Texture = desc.Texture,
                Rate = desc.Rate,
                Enabled = desc.Enabled,
            })
        elseif desc:IsA("Beam") then
            table.insert(data.VisualEffects, {
                Type = "Beam",
                Name = dName,
                Texture = desc.Texture,
                Enabled = desc.Enabled,
            })
        elseif desc:IsA("PointLight") or desc:IsA("SurfaceLight") or desc:IsA("SpotLight") then
            table.insert(data.VisualEffects, {
                Type = dClass,
                Name = dName,
                Color = serializeValue(desc.Color),
                Brightness = desc.Brightness,
                Range = desc.Range,
                Enabled = desc.Enabled,
            })
        elseif desc:IsA("ProximityPrompt") then
            local promptData = {
                Name = dName,
                ActionText = desc.ActionText,
                ObjectText = desc.ObjectText,
                HoldDuration = desc.HoldDuration,
                MaxActivationDistance = desc.MaxActivationDistance,
                Enabled = desc.Enabled,
                Attributes = {},
            }
            local pAttrs = desc:GetAttributes()
            for pk, pv in pairs(pAttrs) do
                promptData.Attributes[pk] = serializeValue(pv)
            end
            table.insert(data.ProximityPrompts, promptData)
        elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
            local labels = {}
            for _, textObj in ipairs(desc:GetDescendants()) do
                if textObj:IsA("TextLabel") and textObj.Text ~= "" then
                    table.insert(labels, {
                        Name = textObj.Name,
                        Text = textObj.Text,
                        TextColor3 = serializeValue(textObj.TextColor3),
                    })
                end
            end
            if #labels > 0 then
                table.insert(data.Guis, {
                    Type = dClass,
                    Name = dName,
                    Labels = labels,
                })
            end
        elseif desc:IsA("ValueBase") then
            table.insert(data.ValueObjects, {
                Type = dClass,
                Name = dName,
                Value = serializeValue(desc.Value),
            })
        end
    end

    -- Accurately determine mutation:
    -- Standard eggs have EggOutline (Highlight) and EggGlow (PointLight).
    -- Mutated eggs have:
    -- 1. Mutation attribute
    -- 2. MutationHitbox child
    -- 3. Mutation-specific particles / name keywords
    data.IsPotentiallyMutated = (data.MutationAttribute ~= nil)
        or data.HasMutationHitbox
        or (#data.SuspiciousKeywords > 0)

    return data
end

-- Checks global weather environment
local function scanWeatherEnvironment()
    local env = {
        WorkspaceAttributes = {},
        LightingAttributes = {},
        ReplicatedStorageAttributes = {},
        WeatherObjects = {},
    }

    pcall(function()
        for k, v in pairs(workspace:GetAttributes()) do
            env.WorkspaceAttributes[k] = serializeValue(v)
        end
    end)

    pcall(function()
        for k, v in pairs(Lighting:GetAttributes()) do
            env.LightingAttributes[k] = serializeValue(v)
        end
    end)

    pcall(function()
        for k, v in pairs(ReplicatedStorage:GetAttributes()) do
            env.ReplicatedStorageAttributes[k] = serializeValue(v)
        end
    end)

    pcall(function()
        for _, root in ipairs({workspace, Lighting, ReplicatedStorage}) do
            for _, child in ipairs(root:GetChildren()) do
                local lName = child.Name:lower()
                if lName:find("weather") or lName:find("event") or lName:find("storm") or lName:find("lighting") then
                    table.insert(env.WeatherObjects, {
                        Path = child:GetFullName(),
                        ClassName = child.ClassName,
                        Attributes = child:GetAttributes(),
                        Value = child:IsA("ValueBase") and tostring(child.Value) or nil,
                    })
                end
            end
        end
    end)

    return env
end

-- Safely inspects and dumps ReplicatedStorage.GameData tables (Mutations, Weather, Eggs, HatchLuck)
local function dumpGameDataModules()
    local results = {}
    local gameData = ReplicatedStorage:FindFirstChild("GameData")
    if not gameData then
        return results
    end

    for _, mod in ipairs(gameData:GetChildren()) do
        if mod:IsA("ModuleScript") then
            local okReq, res = pcall(function()
                return require(mod)
            end)
            if okReq and type(res) == "table" then
                results[mod.Name] = serializeValue(res)
                log(string.format("  -> Successfully dumped ReplicatedStorage.GameData.%s", mod.Name))
            else
                log(string.format("  -> Could not require GameData.%s (skipped)", mod.Name), true)
            end
        end
    end

    return results
end

-- Main diagnostic scan execution
function Scanner:Run(options)
    options = options or {}
    local saveToFile = options.SaveFile ~= false
    local copyClipboard = options.Clipboard ~= false

    log("==================================================")
    log("  🔍 Starting Egg & Mutation Structural Scan...  ")
    log("==================================================")

    local report = {
        Timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        PlaceId = game.PlaceId,
        GameJobId = game.JobId,
        GameData = {},
        Weather = {},
        RenderedEggsSummary = {
            TotalEggs = 0,
            UniqueNames = {},
            MutatedCount = 0,
        },
        DetailedEggs = {},
        PlayerPlotEggs = {},
        OtherEggContainers = {},
    }

    -- STEP 1: Scan workspace.RenderedEggs (Wild eggs)
    log("[Step 1/4] Scanning workspace.RenderedEggs...")
    local renderedFolder = workspace:FindFirstChild("RenderedEggs")
    if renderedFolder then
        local children = renderedFolder:GetChildren()
        report.RenderedEggsSummary.TotalEggs = #children
        log(string.format("  -> Found %d eggs in workspace.RenderedEggs", #children))

        local nameCount = {}
        for _, egg in ipairs(children) do
            nameCount[egg.Name] = (nameCount[egg.Name] or 0) + 1
        end
        report.RenderedEggsSummary.UniqueNames = nameCount

        for eggName, count in pairs(nameCount) do
            log(string.format("     • %s: %d active", eggName, count))
        end

        local samplesSaved = {}
        for _, egg in ipairs(children) do
            local inspected = inspectEggInstance(egg)
            if inspected then
                if inspected.IsPotentiallyMutated then
                    report.RenderedEggsSummary.MutatedCount = report.RenderedEggsSummary.MutatedCount + 1
                    table.insert(report.DetailedEggs, inspected)
                    log(string.format("⚡ [MUTATED IN WILD] %s (Mutation: %s, Hitbox: %s)",
                        egg.Name,
                        tostring(inspected.MutationAttribute or "None"),
                        tostring(inspected.HasMutationHitbox)
                    ), true)
                elseif not samplesSaved[egg.Name] then
                    samplesSaved[egg.Name] = true
                    table.insert(report.DetailedEggs, inspected)
                end
            end
        end
    else
        log("⚠️ workspace.RenderedEggs not found! Searching for fallback egg containers...", true)
        for _, obj in ipairs(workspace:GetChildren()) do
            local lower = obj.Name:lower()
            if (lower:find("egg") or lower:find("render")) and (obj:IsA("Folder") or obj:IsA("Model")) then
                table.insert(report.OtherEggContainers, obj:GetFullName())
                log(string.format("  -> Discovered container: %s (%d items)", obj.Name, #obj:GetChildren()))
            end
        end
    end

    -- STEP 2: Scan Player Base Plot Eggs
    log("[Step 2/4] Scanning Player Plot Eggs (workspace.Plots)...")
    pcall(function()
        local plots = workspace:FindFirstChild("Plots")
        if plots then
            for _, plot in ipairs(plots:GetChildren()) do
                local eggsFolder = plot:FindFirstChild("Eggs")
                if eggsFolder and #eggsFolder:GetChildren() > 0 then
                    for _, egg in ipairs(eggsFolder:GetChildren()) do
                        local inspected = inspectEggInstance(egg)
                        if inspected then
                            inspected.PlotOwner = plot.Name
                            table.insert(report.PlayerPlotEggs, inspected)
                            if inspected.IsPotentiallyMutated then
                                log(string.format("  ⚡ Found Base Mutated Egg: %s (Mutation: %s, Owner: %s)",
                                    egg.Name,
                                    tostring(inspected.MutationAttribute),
                                    tostring(inspected.PlotOwner)
                                ))
                            end
                        end
                    end
                end
            end
            log(string.format("  -> Scanned %d base eggs across plots", #report.PlayerPlotEggs))
        end
    end)

    -- STEP 3: Scan Weather & Environment
    log("[Step 3/4] Scanning Weather & Environment...")
    pcall(function()
        report.Weather = scanWeatherEnvironment()
    end)

    -- STEP 4: Dump ReplicatedStorage.GameData Modules (Mutations, Weather, Eggs, HatchLuck)
    log("[Step 4/4] Reading ReplicatedStorage.GameData modules...")
    pcall(function()
        report.GameData = dumpGameDataModules()
    end)

    -- STEP 5: Serialize and Export
    log("==================================================")
    log(string.format("✅ Scan Finished! Total Rendered Eggs: %d | Mutated Wild: %d | Base Eggs: %d",
        report.RenderedEggsSummary.TotalEggs,
        report.RenderedEggsSummary.MutatedCount,
        #report.PlayerPlotEggs
    ))
    log("==================================================")

    local jsonString = nil
    local okJson, encoded = pcall(function()
        return HttpService:JSONEncode(report)
    end)

    if okJson and encoded then
        jsonString = encoded
    else
        log("⚠️ Standard JSON encode failed, using serialized table...", true)
        jsonString = HttpService:JSONEncode(serializeValue(report))
    end

    if jsonString then
        -- Save to file via UNC writefile
        if saveToFile and typeof(writefile) == "function" then
            pcall(function()
                if typeof(makefolder) == "function" and not isfolder("PSD_Hub") then
                    makefolder("PSD_Hub")
                end
                writefile("PSD_Hub/egg_scan_dump.json", jsonString)
                log("📁 Full dump saved to: PSD_Hub/egg_scan_dump.json")
            end)
        end

        -- Copy to clipboard via UNC setclipboard
        if copyClipboard then
            local copied = copyToClipboard(jsonString)
            if copied then
                log("📋 Dump copied to system clipboard! Press Ctrl+V to paste.")
            end
        end

        notifyUser("Egg Scanner", string.format("Scan complete! %d eggs scanned. Copied to clipboard!", report.RenderedEggsSummary.TotalEggs))
    end

    return report
end

-- Real-time watcher: listens for new eggs or mutations as they happen live
function Scanner:StartWatcher()
    local renderedFolder = workspace:FindFirstChild("RenderedEggs")
    if not renderedFolder then
        log("❌ Cannot start watcher: workspace.RenderedEggs not found.", true)
        return
    end

    log("👀 Live Egg Mutation Watcher STARTED. Waiting for egg spawns or weather mutations...")

    local conn = renderedFolder.ChildAdded:Connect(function(child)
        task.wait(0.2)
        local inspected = inspectEggInstance(child)
        if inspected and inspected.IsPotentiallyMutated then
            log(string.format("⚡ [LIVE DETECTED] %s spawned with Mutation: %s!",
                child.Name,
                tostring(inspected.MutationAttribute or "VisualEffect")
            ), true)
        end
    end)

    local descConn = renderedFolder.DescendantAdded:Connect(function(desc)
        if desc.Name == "MutationHitbox" or desc.Name:lower():find("lightning") then
            local egg = desc:FindFirstAncestorWhichIsA("Model") or desc.Parent
            log(string.format("✨ [MUTATION STRUCK] %s struck on egg: %s", desc.Name, egg and egg.Name or "Unknown"), true)
        end
    end)

    _G.PSD_EggWatcherConnections = { conn, descConn }
    return _G.PSD_EggWatcherConnections
end

function Scanner:StopWatcher()
    if _G.PSD_EggWatcherConnections then
        for _, c in ipairs(_G.PSD_EggWatcherConnections) do
            pcall(function() c:Disconnect() end)
        end
        _G.PSD_EggWatcherConnections = nil
        log("⏹️ Live Egg Mutation Watcher STOPPED.")
    end
end

-- Auto run when executed directly
if not _G.PSD_SCANNER_NO_AUTORUN then
    Scanner:Run()
end

return Scanner
