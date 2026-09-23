local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")

local found = {}
if pg then
    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local t = desc.Text
            if t:find("/") or t:find("10") or t:find("Bag") or t:find("Ore") then
                table.insert(found, string.format("GUI: %s | Label: %s | Text: '%s'", desc:GetFullName(), desc.Name, t))
            end
        end
    end
end

local out = table.concat(found, "\n")
pcall(function()
    if typeof(setclipboard) == "function" then setclipboard(out) end
end)
print("[CheckBackpackUI] Found " .. #found .. " matching labels:")
print(out)
