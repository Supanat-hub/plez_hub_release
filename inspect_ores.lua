local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local sample = {}
local oreCache = Workspace:FindFirstChild("OreCache")
if oreCache then
    for i, child in ipairs(oreCache:GetChildren()) do
        if i > 10 then break end
        local item = {
            Name = child.Name,
            Class = child.ClassName,
            Attributes = child:GetAttributes(),
            Descendants = {},
        }
        for _, d in ipairs(child:GetDescendants()) do
            local dInfo = { Name = d.Name, Class = d.ClassName }
            if d:IsA("ProximityPrompt") then
                dInfo.ActionText = d.ActionText
                dInfo.ObjectText = d.ObjectText
                dInfo.HoldDuration = d.HoldDuration
                dInfo.MaxActivationDistance = d.MaxActivationDistance
                dInfo.KeyboardKeyCode = tostring(d.KeyboardKeyCode)
            elseif d:IsA("BasePart") then
                dInfo.Position = tostring(d.Position)
            end
            table.insert(item.Descendants, dInfo)
        end
        table.insert(sample, item)
    end
end

local json = HttpService:JSONEncode(sample)
pcall(function()
    if typeof(setclipboard) == "function" then setclipboard(json) end
    if typeof(writefile) == "function" then writefile("PSD_Hub/ore_samples.json", json) end
end)
print("[OreScan] Dumped " .. #sample .. " ore samples. Copied to clipboard!")
