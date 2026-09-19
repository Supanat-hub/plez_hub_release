--[[
    PSD Hub — Egg & Mutation Structure Diagnostic Scanner
    Scans live egg instances in workspace, player plots, and ReplicatedStorage modules
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

local function serializeValue(val)
    local t = typeof(val)
    if t == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "Vector3" then
        return string.format("(%.1f, %.1f, %.1f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        return string.format("Pos(%.1f, %.1f, %.1f)", val.Position.X, val.Position.Y, val.Position.Z)
    elseif t == "Instance" then
        return val:GetFullName()
    elseif t == "table" or t == "string" or t == "number" or t == "boolean" then
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
        HasHighlight = false,
        SuspiciousKeywords = {},
    }

    -- 1. Attributes
    local okAttr, attrs = pcall(function() return egg:GetAttributes() end)
    if okAttr and attrs then
        for k, v in pairs(attrs) do
            data.Attributes[k] = serializeValue(v)
        end
    end

    -- 2. CollectionService Tags
    pcall(function()
        data.Tags = CollectionService:GetTags(egg)
    end)

    -- 3. Check for mutation keywords in Name
    local keywords = {"eternal", "void", "rage", "volted", "volt", "shocked", "shock", "thunder", "lightning", "mutated", "mutation", "100x", "10x", "4x", "3x", "2x"}
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

        -- Check descendant names for keywords
        for _, kw in ipairs(keywords) do
            if dLower:find(kw) then
                table.insert(data.SuspiciousKeywords, string.format("%s(%s):%s", dClass, dName, kw))
            end
        end

        if desc:IsA("BasePart") then
            data.PartsCount = data.PartsCount + 1
        elseif desc:IsA("Highlight") then
            data.HasHighlight = true
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

    -- Flags if this egg looks special or mutated
    data.IsPotentiallyMutated = (#data.SuspiciousKeywords > 0)
        or (next(data.Attributes) ~= nil)
        or (#data.Tags > 0)
        or data.HasHighlight
        or (#data.VisualEffects > 0)

    return data
end

-- Scans ReplicatedStorage for Modules that might contain Egg, Pet, or Mutation tables
local function scanReplicatedStorage()
    local moduleDumps = {}
    local keywords = {"egg", "pet", "mutation", "weather", "config", "data", "hatch", "drop"}

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local lowerName = desc.Name:lower()
            local matches = false
            for _, kw in ipairs(keywords) do
                if lowerName:find(kw) then
                    matches = true
                    break
                end
            end

            if matches then
                local modInfo = {
                    FullName = desc:GetFullName(),
                    Name = desc.Name,
                    Attributes = desc:GetAttributes(),
                    RequireSuccessful = false,
                    ExportedKeys = {},
                    SampleData = nil,
                }

                -- Try requiring the module
                local okReq, result = pcall(function()
                    return require(desc)
                end)

                if okReq and type(result) == "table" then
                    modInfo.RequireSuccessful = true
                    local keys = {}
                    for k, v in pairs(result) do
                        table.insert(keys, tostring(k))
                    end
                    modInfo.ExportedKeys = keys

                    -- If small table, include representation
                    local okJson, json = pcall(function()
                        return HttpService:JSONEncode(result)
                    end)
                    if okJson and #json < 4000 then
                        modInfo.SampleData = result
                    end
                end

                table.insert(moduleDumps, modInfo)
            end
        end
    end

    return moduleDumps
end

-- Checks global weather environment
local function scanWeatherEnvironment()
    local env = {
        WorkspaceAttributes = workspace:GetAttributes(),
        LightingAttributes = Lighting:GetAttributes(),
        ReplicatedStorageAttributes = ReplicatedStorage:GetAttributes(),
        WeatherObjects = {},
    }

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

    return env
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
        Weather = scanWeatherEnvironment(),
        Modules = scanReplicatedStorage(),
        RenderedEggsSummary = {
            TotalEggs = 0,
            UniqueNames = {},
            MutatedCount = 0,
        },
        DetailedEggs = {},
        PlayerPlotEggs = {},
    }

    -- 1. Scan workspace.RenderedEggs
    local renderedFolder = workspace:FindFirstChild("RenderedEggs")
    if renderedFolder then
        local children = renderedFolder:GetChildren()
        report.RenderedEggsSummary.TotalEggs = #children

        local nameCount = {}
        for _, egg in ipairs(children) do
            nameCount[egg.Name] = (nameCount[egg.Name] or 0) + 1
        end
        report.RenderedEggsSummary.UniqueNames = nameCount

        -- Store detailed inspection for:
        -- - ALL eggs marked as potentially mutated
        -- - 1 sample of each standard egg type
        local samplesSaved = {}
        for _, egg in ipairs(children) do
            local inspected = inspectEggInstance(egg)
            if inspected then
                if inspected.IsPotentiallyMutated then
                    report.RenderedEggsSummary.MutatedCount = report.RenderedEggsSummary.MutatedCount + 1
                    table.insert(report.DetailedEggs, inspected)
                    log(string.format("⚡ FOUND MUTATED/SPECIAL EGG: %s (Attributes: %d, Tags: %d, Keywords: %s)",
                        egg.Name,
                        #inspected.Attributes,
                        #inspected.Tags,
                        table.concat(inspected.SuspiciousKeywords, ", ")
                    ), true)
                elseif not samplesSaved[egg.Name] then
                    samplesSaved[egg.Name] = true
                    table.insert(report.DetailedEggs, inspected)
                end
            end
        end
    else
        log("⚠️ workspace.RenderedEggs not found!", true)
    end

    -- 2. Scan Player Base Plot Eggs
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local eggsFolder = plot:FindFirstChild("Eggs")
            if eggsFolder and #eggsFolder:GetChildren() > 0 then
                for _, egg in ipairs(eggsFolder:GetChildren()) do
                    local inspected = inspectEggInstance(egg)
                    if inspected then
                        table.insert(report.PlayerPlotEggs, inspected)
                    end
                end
            end
        end
    end

    -- 3. Print Concise Human-Readable Summary
    log(string.format("✅ Scan Finished! Total Rendered Eggs: %d | Mutated/Special: %d",
        report.RenderedEggsSummary.TotalEggs,
        report.RenderedEggsSummary.MutatedCount
    ))

    log("--- Weather Environment ---")
    for k, v in pairs(report.Weather.WorkspaceAttributes) do
        log(string.format("  workspace[%s] = %s", tostring(k), serializeValue(v)))
    end
    for k, v in pairs(report.Weather.LightingAttributes) do
        log(string.format("  Lighting[%s] = %s", tostring(k), serializeValue(v)))
    end

    log("--- ReplicatedStorage Modules Found ---")
    for _, mod in ipairs(report.Modules) do
        log(string.format("  Module: %s (Exported Keys: %s)", mod.Name, table.concat(mod.ExportedKeys, ", ")))
    end

    -- 4. Serialize to JSON
    local okJson, jsonString = pcall(function()
        return HttpService:JSONEncode(report)
    end)

    if okJson and jsonString then
        -- Save to file
        if saveToFile and typeof(writefile) == "function" then
            pcall(function()
                if typeof(makefolder) == "function" and not isfolder("PSD_Hub") then
                    makefolder("PSD_Hub")
                end
                writefile("PSD_Hub/egg_scan_dump.json", jsonString)
                log("📁 Full dump saved to: PSD_Hub/egg_scan_dump.json")
            end)
        end

        -- Copy to clipboard
        if copyClipboard then
            local copied = copyToClipboard(jsonString)
            if copied then
                log("📋 Dump copied to system clipboard! You can paste it directly.")
            end
        end

        notifyUser("Egg Scanner", string.format("Scan complete! %d eggs scanned (%d mutated). Data copied to clipboard!", report.RenderedEggsSummary.TotalEggs, report.RenderedEggsSummary.MutatedCount))
    else
        log("❌ Failed to encode scan report to JSON.", true)
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
        task.wait(0.2) -- Wait for attributes to replicate
        local inspected = inspectEggInstance(child)
        if inspected and inspected.IsPotentiallyMutated then
            log(string.format("⚡ [LIVE DETECTED] %s spawned with special traits! Tags: %s | Attrs: %s",
                child.Name,
                table.concat(inspected.Tags, ", "),
                HttpService:JSONEncode(inspected.Attributes)
            ), true)
        end
    end)

    local descConn = renderedFolder.DescendantAdded:Connect(function(desc)
        if desc:IsA("ParticleEmitter") or desc:IsA("Highlight") or desc:IsA("Beam") then
            local egg = desc:FindFirstAncestorWhichIsA("Model") or desc.Parent
            log(string.format("✨ [EFFECT ADDED] Effect %s added to egg: %s", desc.Name, egg and egg.Name or "Unknown"))
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

