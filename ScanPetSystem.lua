--[[
    PSD Hub — Complete Pet System & Base Plot Diagnostic Scanner
    Inspects:
    1. Base Plot: workspace.Plots.<MyPlot>.Pets (models, names, attributes, billboard text)
    2. PetsTracker UI: PlayerGui.Main.PetsTracker (active pet cards, text, stats, PlaceBest button)
    3. Pet Inventory UI: PlayerGui.Main.Inventory / PetInventory (bag pets, equipped markers, text)
    4. Player Data & Backpack: player.Data / PlayerData / Backpack / Inventory
    5. Pet Remotes: All Remotes in ReplicatedStorage related to pets/placing/equipping

    Outputs:
    1. JSON Dump saved to: PSD_Hub/pet_system_scan.json
    2. Copied directly to system clipboard via setclipboard()
    3. Notifies user in Roblox UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

local function log(msg, isWarn)
    local formatted = "[PetSystemScanner] " .. tostring(msg)
    if isWarn then warn(formatted) else print(formatted) end
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

local function serializeValue(val, depth)
    depth = depth or 0
    if depth > 5 then return "..." end

    local t = typeof(val)
    if t == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "Vector3" then
        return string.format("(%.1f, %.1f, %.1f)", val.X, val.Y, val.Z)
    elseif t == "UDim2" then
        return string.format("{%s, %s, %s, %s}", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
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

local report = {
    Timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    PlayerName = player.Name,
    UserId = player.UserId,
    PlaceId = game.PlaceId,
    BasePlot = {},
    PetsTracker = {},
    PetInventoryUI = {},
    PlayerDataStorage = {},
    PetRemotes = {},
    GameDataSample = {},
}

log("==================================================")
log("  🐾 Starting Deep Pet System Scanner...         ")
log("==================================================")

--==================================================
-- 1. Scan Player's Base Plot & Pets
--==================================================
pcall(function()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        report.BasePlot.Error = "workspace.Plots not found"
        return
    end

    local myPlot = nil
    for _, plot in ipairs(plots:GetChildren()) do
        local data = plot:FindFirstChild("Data")
        local ownerVal = data and data:FindFirstChild("Owner")
        if ownerVal and (tostring(ownerVal.Value) == player.Name or ownerVal.Value == player) then
            myPlot = plot
            break
        end
    end

    if not myPlot then
        report.BasePlot.Error = "MyPlot not found in workspace.Plots"
        return
    end

    report.BasePlot.Name = myPlot.Name
    report.BasePlot.Path = myPlot:GetFullName()

    local petsFolder = myPlot:FindFirstChild("Pets") or myPlot:FindFirstChild("PetModels")
    if not petsFolder then
        report.BasePlot.PetsFolder = "No Pets folder found directly in plot"
        return
    end

    report.BasePlot.PetsFolderPath = petsFolder:GetFullName()
    report.BasePlot.PetsCount = #petsFolder:GetChildren()
    report.BasePlot.PlacedPets = {}

    for i, pet in ipairs(petsFolder:GetChildren()) do
        local petInfo = {
            Index = i,
            Name = pet.Name,
            ClassName = pet.ClassName,
            Attributes = {},
            Tags = CollectionService:GetTags(pet),
            TextLabels = {},
            Values = {},
            PrimaryPart = pet.PrimaryPart and pet.PrimaryPart.Name or nil,
            Position = pet.PrimaryPart and serializeValue(pet.PrimaryPart.Position) or nil,
        }

        local okAttr, attrs = pcall(function() return pet:GetAttributes() end)
        if okAttr and attrs then
            for k, v in pairs(attrs) do
                petInfo.Attributes[k] = serializeValue(v)
            end
        end

        for _, desc in ipairs(pet:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text ~= "" then
                table.insert(petInfo.TextLabels, {
                    Name = desc.Name,
                    Text = desc.Text,
                    Parent = desc.Parent and desc.Parent.Name or "",
                })
            elseif desc:IsA("ValueBase") then
                petInfo.Values[desc.Name] = serializeValue(desc.Value)
            end
        end

        table.insert(report.BasePlot.PlacedPets, petInfo)
    end
    log(string.format("Found %d placed pets in base plot (%s)", #report.BasePlot.PlacedPets, myPlot.Name))
end)

--==================================================
-- 2. Scan PlayerGui.Main.PetsTracker
--==================================================
pcall(function()
    local pgui = player:FindFirstChild("PlayerGui")
    if not pgui then return end

    local main = pgui:FindFirstChild("Main")
    local tracker = main and (main:FindFirstChild("PetsTracker") or main:FindFirstChild("PetTracker"))
        or pgui:FindFirstChild("PetsTracker", true)

    if not tracker then
        report.PetsTracker.Found = false
        report.PetsTracker.Note = "PetsTracker not found in PlayerGui"
        return
    end

    report.PetsTracker.Found = true
    report.PetsTracker.Path = tracker:GetFullName()
    report.PetsTracker.Visible = tracker.Visible
    report.PetsTracker.Cards = {}
    report.PetsTracker.PlaceBestButton = nil

    for _, desc in ipairs(tracker:GetDescendants()) do
        if desc.Name == "PlaceBest" or desc.Name:lower():find("placebest") then
            report.PetsTracker.PlaceBestButton = {
                Name = desc.Name,
                ClassName = desc.ClassName,
                Path = desc:GetFullName(),
                Visible = desc.Visible,
                Text = desc:IsA("TextButton") and desc.Text or "",
                Attributes = desc:GetAttributes(),
            }
        end
    end

    -- Look for pet tracker items/cards
    for _, child in ipairs(tracker:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "PlaceBest" then
            local cardInfo = {
                Name = child.Name,
                ClassName = child.ClassName,
                Visible = child.Visible,
                Attributes = child:GetAttributes(),
                TextLabels = {},
            }
            for _, lbl in ipairs(child:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Text ~= "" then
                    table.insert(cardInfo.TextLabels, { Name = lbl.Name, Text = lbl.Text })
                end
            end
            if #cardInfo.TextLabels > 0 or next(cardInfo.Attributes) ~= nil then
                table.insert(report.PetsTracker.Cards, cardInfo)
            end
        end
    end
    log(string.format("Found %d pet cards in PetsTracker.", #report.PetsTracker.Cards))
end)

--==================================================
-- 3. Scan Pet Inventory UI in PlayerGui
--==================================================
pcall(function()
    local pgui = player:FindFirstChild("PlayerGui")
    if not pgui then return end

    local invContainers = {}
    for _, gui in ipairs(pgui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                local dName = desc.Name:lower()
                if (dName == "inventory" or dName == "pets" or dName == "petinventory" or dName == "petstorage" or dName == "petsframe")
                    and desc:IsA("GuiObject") then
                    table.insert(invContainers, desc)
                end
            end
        end
    end

    report.PetInventoryUI.ContainersFound = #invContainers
    report.PetInventoryUI.Containers = {}

    for _, cont in ipairs(invContainers) do
        local contData = {
            Path = cont:GetFullName(),
            Visible = cont.Visible,
            SampleCards = {},
        }

        local count = 0
        for _, item in ipairs(cont:GetDescendants()) do
            if item:IsA("GuiObject") and (item:IsA("ImageButton") or item:IsA("TextButton") or item:IsA("Frame")) then
                local labels = {}
                for _, lbl in ipairs(item:GetDescendants()) do
                    if lbl:IsA("TextLabel") and lbl.Text ~= "" then
                        table.insert(labels, { Name = lbl.Name, Text = lbl.Text })
                    end
                end
                if #labels >= 2 and count < 6 then
                    count = count + 1
                    table.insert(contData.SampleCards, {
                        CardName = item.Name,
                        ClassName = item.ClassName,
                        Path = item:GetFullName(),
                        Attributes = item:GetAttributes(),
                        Labels = labels,
                    })
                end
            end
        end
        table.insert(report.PetInventoryUI.Containers, contData)
    end
    log(string.format("Scanned %d Pet Inventory containers in PlayerGui.", #invContainers))
end)

--==================================================
-- 4. Scan Player Data / Backpack
--==================================================
pcall(function()
    local pData = player:FindFirstChild("Data") or player:FindFirstChild("PlayerData")
    report.PlayerDataStorage.DataFolderFound = pData ~= nil
    if pData then
        report.PlayerDataStorage.DataFolderPath = pData:GetFullName()
        report.PlayerDataStorage.Children = {}
        for _, c in ipairs(pData:GetChildren()) do
            local cData = { Name = c.Name, ClassName = c.ClassName, Value = c:IsA("ValueBase") and serializeValue(c.Value) or nil }
            if c:IsA("Folder") or c:IsA("Configuration") then
                cData.ItemCount = #c:GetChildren()
                cData.SampleItems = {}
                for i, sub in ipairs(c:GetChildren()) do
                    if i <= 5 then
                        table.insert(cData.SampleItems, { Name = sub.Name, Attributes = sub:GetAttributes(), ClassName = sub.ClassName })
                    end
                end
            end
            table.insert(report.PlayerDataStorage.Children, cData)
        end
    end

    local bp = player:FindFirstChild("Backpack")
    if bp then
        report.PlayerDataStorage.BackpackItems = {}
        for _, item in ipairs(bp:GetChildren()) do
            table.insert(report.PlayerDataStorage.BackpackItems, {
                Name = item.Name,
                ClassName = item.ClassName,
                Attributes = item:GetAttributes(),
            })
        end
    end
end)

--==================================================
-- 5. Scan Pet Remotes in ReplicatedStorage
--==================================================
pcall(function()
    local function scanRemotes(parent, prefix)
        for _, child in ipairs(parent:GetChildren()) do
            local cur = prefix .. "." .. child.Name
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                local cLower = child.Name:lower()
                if cLower:find("pet") or cLower:find("equip") or cLower:find("place") or cLower:find("mount")
                    or cLower:find("ride") or cLower:find("feed") or cLower:find("hatch") or cLower:find("sell") then
                    table.insert(report.PetRemotes, {
                        Name = child.Name,
                        ClassName = child.ClassName,
                        Path = cur,
                    })
                end
            elseif child:IsA("Folder") or child:IsA("Configuration") or child:IsA("Model") then
                scanRemotes(child, cur)
            end
        end
    end

    local repRem = ReplicatedStorage:FindFirstChild("Remotes")
    if repRem then
        scanRemotes(repRem, "ReplicatedStorage.Remotes")
    else
        scanRemotes(ReplicatedStorage, "ReplicatedStorage")
    end
    log(string.format("Found %d relevant Pet Remotes in ReplicatedStorage.", #report.PetRemotes))
end)

--==================================================
-- Output & Save
--==================================================
local jsonString = HttpService:JSONEncode(report)

if typeof(writefile) == "function" then
    pcall(function()
        if typeof(makefolder) == "function" and not isfolder("PSD_Hub") then
            makefolder("PSD_Hub")
        end
        writefile("PSD_Hub/pet_system_scan.json", jsonString)
        log("📁 Full report saved to: PSD_Hub/pet_system_scan.json")
    end)
end

local copied = copyToClipboard(jsonString)
if copied then
    notifyUser("Pet Scanner Complete", "✅ Pet system report copied to Clipboard! Paste in chat.")
    log("✅ Successfully copied JSON report to system clipboard!")
else
    notifyUser("Pet Scanner Complete", "⚠️ Output saved to PSD_Hub/pet_system_scan.json")
    log("⚠️ Could not copy to clipboard, saved to PSD_Hub/pet_system_scan.json")
end

log("==================================================")
log("  🏁 Pet System Scanner Finished!                ")
log("==================================================")

return report
