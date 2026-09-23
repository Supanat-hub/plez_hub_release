local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local pos = lp.Character and lp.Character:GetPivot().Position

local report = {
    CurrentPlayerPosition = pos and tostring(pos),
    CloseObjects = {},
    WorkspaceFolders = {},
}

-- Check top level workspace folders
for _, c in ipairs(Workspace:GetChildren()) do
    table.insert(report.WorkspaceFolders, { Name = c.Name, Class = c.ClassName, ChildCount = #c:GetChildren() })
end

-- Find any parts within 100 studs of player
if pos then
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsDescendantOf(lp.Character) then
            local dist = (part.Position - pos).Magnitude
            if dist < 60 then
                table.insert(report.CloseObjects, {
                    Name = part.Name,
                    Parent = part.Parent and part.Parent.Name,
                    Dist = math.floor(dist),
                    Position = tostring(part.Position),
                    Attributes = part:GetAttributes(),
                })
                if #report.CloseObjects > 20 then break end
            end
        end
    end
end

local json = HttpService:JSONEncode(report)
pcall(function()
    if typeof(setclipboard) == "function" then setclipboard(json) end
end)
print("[StagePos] Copied stage position report to clipboard!")
