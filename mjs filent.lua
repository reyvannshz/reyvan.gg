-- =============================================
-- Fathir Script - Full Version with Kiwisense GUI
-- Silent Aim + Tracer + FOV + Full ESP
-- =============================================

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Kiwisense/Library.lua"))()

-- ==================== SETTINGS ====================
getgenv().SilentAimSettings = {
    Enabled = true,
    SilentAimHead = true,
    SilentAimBody = false,
    TracerEnabled = true,
    FOVEnabled = true,
    FOVRadius = 150,
}

-- ==================== SILENT AIM + TRACER + FOV ====================
local SilentTarget = nil
local TracerLine = Drawing.new("Line")
local FOVCircle = Drawing.new("Circle")

TracerLine.Thickness = 2
TracerLine.Transparency = 1
TracerLine.Color = Color3.fromRGB(255, 0, 0)

FOVCircle.Thickness = 2
FOVCircle.Transparency = 0.7
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Radius = 150
FOVCircle.NumSides = 64

local function IsInFOV(player)
    if not getgenv().SilentAimSettings.FOVEnabled then return true end
    local camera = workspace.CurrentCamera
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
    local screenPos = camera:WorldToViewportPoint(character.HumanoidRootPart.Position)
    local distance = (Vector2.new(screenPos.X, screenPos.Y) - camera.ViewportSize/2).Magnitude
    return distance <= getgenv().SilentAimSettings.FOVRadius
end

local function GetClosestPlayer()
    local Closest = nil
    local ShortestDistance = math.huge
    local LocalPlayer = game.Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    local Center = Camera.ViewportSize / 2

    for _, Player in ipairs(game.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            if not IsInFOV(Player) then continue end
            local RootPart = Player.Character.HumanoidRootPart
            local ScreenPos = Camera:WorldToViewportPoint(RootPart.Position)
            local Distance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - Center).Magnitude
            if Distance < ShortestDistance then
                ShortestDistance = Distance
                Closest = Player
            end
        end
    end
    return Closest
end

game:GetService("RunService").RenderStepped:Connect(function()
    SilentTarget = GetClosestPlayer()

    -- Tracer
    if getgenv().SilentAimSettings.TracerEnabled and SilentTarget and SilentTarget.Character and SilentTarget.Character:FindFirstChild("HumanoidRootPart") then
        local camera = workspace.CurrentCamera
        local rootPos = SilentTarget.Character.HumanoidRootPart.Position
        local screenPos, onScreen = camera:WorldToViewportPoint(rootPos)
        if onScreen then
            TracerLine.From = camera.ViewportSize / 2
            TracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
            TracerLine.Visible = true
        else
            TracerLine.Visible = false
        end
    else
        TracerLine.Visible = false
    end

    -- FOV
    if getgenv().SilentAimSettings.FOVEnabled then
        FOVCircle.Position = workspace.CurrentCamera.ViewportSize / 2
        FOVCircle.Radius = getgenv().SilentAimSettings.FOVRadius
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
end)

-- Silent Aim Hook
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()

    if getgenv().SilentAimSettings.Enabled and (getgenv().SilentAimSettings.SilentAimHead or getgenv().SilentAimSettings.SilentAimBody) and method == "FireServer" then
        local remoteName = tostring(self):lower()
        if remoteName:find("hit") or remoteName:find("shoot") or remoteName:find("fire") or remoteName:find("attack") then
            if SilentTarget and SilentTarget.Character then
                local hitPart = SilentTarget.Character:FindFirstChild("Head")
                if getgenv().SilentAimSettings.SilentAimBody then
                    hitPart = SilentTarget.Character:FindFirstChild("HumanoidRootPart") or SilentTarget.Character:FindFirstChild("Torso")
                end
                if hitPart then
                    for i, v in pairs(args) do
                        if typeof(v) == "Vector3" then args[i] = hitPart.Position
                        elseif typeof(v) == "Instance" and v:IsA("BasePart") then args[i] = hitPart end
                    end
                end
            end
        end
    end
    return oldNamecall(self, unpack(args))
end)
setreadonly(mt, true)

-- ==================== FULL ESP ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ESPEnabled = true
local ESPObjects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end
    local data = {}
    
    data.BoxOutline = Drawing.new("Square")
    data.BoxOutline.Visible = false
    data.BoxOutline.Color = Color3.new(0, 0, 0)
    data.BoxOutline.Thickness = 3
    data.BoxOutline.Filled = false

    data.Box = Drawing.new("Square")
    data.Box.Visible = false
    data.Box.Color = Color3.new(1, 1, 1)
    data.Box.Thickness = 1
    data.Box.Filled = false

    data.TeamName = Drawing.new("Text")
    data.TeamName.Visible = false
    data.TeamName.Center = true
    data.TeamName.Outline = true
    data.TeamName.OutlineColor = Color3.new(0, 0, 0)
    data.TeamName.Size = 13
    data.TeamName.Font = 2

    data.Bones = {}
    local boneConnections = {
        {"Head", "UpperTorso"},{"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},{"LeftUpperArm", "LeftLowerArm"},{"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},{"RightUpperArm", "RightLowerArm"},{"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"},{"LeftUpperLeg", "LeftLowerLeg"},{"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},{"RightUpperLeg", "RightLowerLeg"},{"RightLowerLeg", "RightFoot"}
    }
    
    for i = 1, #boneConnections do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.new(1, 1, 1)
        line.Thickness = 1
        table.insert(data.Bones, line)
    end
    
    ESPObjects[player] = data
end

local function GetTeamColor(player)
    if player.Team then return player.Team.TeamColor.Color end
    return Color3.new(1, 1, 1)
end

local function WorldToScreen(position)
    local camera = workspace.CurrentCamera
    local screenPos, onScreen = camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function GetBodyPart(character, partName)
    if not character then return nil end
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then return part.Position end
    return nil
end

local function UpdateESP(player)
    local data = ESPObjects[player]
    if not data then return end
    
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    
    if not ESPEnabled or not character or not humanoid or humanoid.Health <= 0 or not hrp then
        for _, obj in pairs(data) do
            if typeof(obj) == "table" then
                for _, v in pairs(obj) do if typeof(v) == "userdata" then v.Visible = false end end
            else
                obj.Visible = false
            end
        end
        return
    end
    
    local teamColor = GetTeamColor(player)
    local headPos, headVisible = WorldToScreen(hrp.Position + Vector3.new(0, 3, 0))
    local footPos, footVisible = WorldToScreen(hrp.Position - Vector3.new(0, 3, 0))
    
    if headVisible or footVisible then
        local height = math.abs(headPos.Y - footPos.Y)
        local width = height * 0.6
        
        data.Box.Size = Vector2.new(width, height)
        data.Box.Position = Vector2.new(footPos.X - width/2, headPos.Y)
        data.Box.Color = teamColor
        data.Box.Visible = true
        
        data.BoxOutline.Size = Vector2.new(width, height)
        data.BoxOutline.Position = Vector2.new(footPos.X - width/2, headPos.Y)
        data.BoxOutline.Visible = true
        
        local teamText = player.Team and player.Team.Name or "No Team"
        data.TeamName.Text = string.format("%s [%s]", player.Name, teamText)
        data.TeamName.Position = Vector2.new(footPos.X, headPos.Y - 15)
        data.TeamName.Color = teamColor
        data.TeamName.Visible = true
    else
        data.Box.Visible = false
        data.BoxOutline.Visible = false
        data.TeamName.Visible = false
    end
    
    -- Skeleton Bones
    local boneConnections = {
        {"Head", "UpperTorso"},{"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},{"LeftUpperArm", "LeftLowerArm"},{"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},{"RightUpperArm", "RightLowerArm"},{"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"},{"LeftUpperLeg", "LeftLowerLeg"},{"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},{"RightUpperLeg", "RightLowerLeg"},{"RightLowerLeg", "RightFoot"}
    }
    
    for i, connection in ipairs(boneConnections) do
        local bone = data.Bones[i]
        local p1 = GetBodyPart(character, connection[1])
        local p2 = GetBodyPart(character, connection[2])
        if p1 and p2 then
            local s1, v1 = WorldToScreen(p1)
            local s2, v2 = WorldToScreen(p2)
            if v1 and v2 then
                bone.From = s1
                bone.To = s2
                bone.Color = teamColor
                bone.Visible = true
            else
                bone.Visible = false
            end
        else
            bone.Visible = false
        end
    end
end

local function OnPlayerAdded(player)
    player.CharacterAdded:Connect(function() CreateESP(player) end)
    if player.Character then CreateESP(player) end
end

for _, player in pairs(Players:GetPlayers()) do OnPlayerAdded(player) end
Players.PlayerAdded:Connect(OnPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        for _, drawing in pairs(ESPObjects[player]) do
            if typeof(drawing) == "table" then
                for _, d in pairs(drawing) do if typeof(d) == "userdata" then d:Remove() end end
            else
                drawing:Remove()
            end
        end
        ESPObjects[player] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    for player in pairs(ESPObjects) do
        UpdateESP(player)
    end
end)

-- ==================== GUI KIWI SENSE ====================
local Window = Library:Window({
    Name = "Fathir Script",
    Version = "v1.4",
    Logo = "135215559087473",
    FadeSpeed = 0.25
})

local Pages = {
    Combat = Window:Page({Name = "Combat", Icon = "111178525804834"}),
    Visuals = Window:Page({Name = "Visuals", Icon = "115907015044719", Columns = 2})
}

-- Combat Tab
local SilentSection = Pages.Combat:Section({Name = "Silent Aim", Icon = "103174889897193", Side = 1})

SilentSection:Toggle({
    Name = "Silent Aim Enabled",
    Default = true,
    Callback = function(v) getgenv().SilentAimSettings.Enabled = v end
})

SilentSection:Toggle({
    Name = "Silent Aim Head",
    Default = true,
    Callback = function(v) getgenv().SilentAimSettings.SilentAimHead = v end
})

SilentSection:Toggle({
    Name = "Silent Aim Body",
    Default = false,
    Callback = function(v) getgenv().SilentAimSettings.SilentAimBody = v end
})

-- Visuals Tab
local VisualsSection = Pages.Visuals:Section({Name = "Visuals", Icon = "135799335731002", Side = 1})

VisualsSection:Toggle({
    Name = "Tracer",
    Default = true,
    Callback = function(v) getgenv().SilentAimSettings.TracerEnabled = v end
})

VisualsSection:Toggle({
    Name = "FOV Circle",
    Default = true,
    Callback = function(v) getgenv().SilentAimSettings.FOVEnabled = v end
})

VisualsSection:Slider({
    Name = "FOV Radius",
    Min = 50,
    Max = 500,
    Default = 150,
    Suffix = "px",
    Decimals = 0,
    Callback = function(v) getgenv().SilentAimSettings.FOVRadius = v end
})

VisualsSection:Toggle({
    Name = "ESP Enabled",
    Default = true,
    Callback = function(v) ESPEnabled = v end
})

Library:Notification({
    Name = "Loaded",
    Description = "Fathir Script berhasil dimuat!\nSilent Aim + Tracer + FOV + ESP",
    Duration = 6
})

Library:Init()

print("🎉 Fathir Script Full Version Loaded!")
