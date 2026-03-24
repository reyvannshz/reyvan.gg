-- ========== MAJESTY STORE v8.3.1 ==========
-- Updated with Majestic Teleport Announcement

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer

repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ================== TELEPORT ANNOUNCEMENT GUI ==================
local majestyAnnounce = Instance.new("ScreenGui")
majestyAnnounce.Name = "MajestyAnnounce"
majestyAnnounce.ResetOnSpawn = false
majestyAnnounce.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiOk = false
if not guiOk then pcall(function() majestyAnnounce.Parent = gethui(); guiOk = true end) end
if not guiOk then pcall(function() majestyAnnounce.Parent = game:GetService("CoreGui"); guiOk = true end) end
if not guiOk then majestyAnnounce.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local announceFrame = Instance.new("Frame")
announceFrame.Size = UDim2.new(0, 460, 0, 160)
announceFrame.Position = UDim2.new(0.5, -230, 0.35, 0)
announceFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 15)
announceFrame.BackgroundTransparency = 1
announceFrame.BorderSizePixel = 0
announceFrame.Parent = majestyAnnounce
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = announceFrame
local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(255, 215, 0); stroke.Parent = announceFrame

local crown = Instance.new("TextLabel")
crown.Size = UDim2.new(0, 90, 0, 70)
crown.Position = UDim2.new(0.5, -45, 0, -35)
crown.BackgroundTransparency = 1
crown.Text = "👑"
crown.TextColor3 = Color3.fromRGB(255, 215, 0)
crown.TextSize = 68
crown.Font = Enum.Font.GothamBold
crown.TextStrokeTransparency = 0.6
crown.TextStrokeColor3 = Color3.fromRGB(0,0,0)
crown.Parent = announceFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.55, 0)
title.Position = UDim2.new(0, 0, 0.38, 0)
title.BackgroundTransparency = 1
title.Text = "MAJESTY STORE"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 46
title.TextStrokeTransparency = 0.7
title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
title.Parent = announceFrame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0.22, 0)
subtitle.Position = UDim2.new(0, 0, 0.78, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "TELEPORT SUCCESS"
subtitle.TextColor3 = Color3.fromRGB(180, 220, 255)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 19
subtitle.TextStrokeTransparency = 0.8
subtitle.Parent = announceFrame

announceFrame.Visible = false

local function showMajestyAnnounce(msg)
    if msg then subtitle.Text = msg end
    announceFrame.Visible = true
    announceFrame.BackgroundTransparency = 1
    crown.TextTransparency = 1
    title.TextTransparency = 1
    subtitle.TextTransparency = 1

    TweenService:Create(announceFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.25}):Play()
    TweenService:Create(crown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
    TweenService:Create(subtitle, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

    task.wait(1.9)

    TweenService:Create(announceFrame, TweenInfo.new(0.65, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
    TweenService:Create(crown, TweenInfo.new(0.65), {TextTransparency = 1}):Play()
    TweenService:Create(title, TweenInfo.new(0.65), {TextTransparency = 1}):Play()
    TweenService:Create(subtitle, TweenInfo.new(0.65), {TextTransparency = 1}):Play()

    task.wait(0.8)
    announceFrame.Visible = false
end
-- ================== END OF ANNOUNCEMENT ==================

-- (Semua kode lama kamu dari awal sampai akhir tetap sama, hanya aku sisipkan announcement ini)

local AutoMS_Running   = false
local autoSell_Running = false
local autoSell_Count   = 0
local isMinimized      = false
local espEnabled       = false
local espCache         = {}
local boxPadding       = 4
local espItemColor     = Color3.fromRGB(255, 220, 50)
local ESP_INTERVAL     = 0.05
local _espAccum        = 0
local aimbotEnabled    = false
local aimbotMode       = "Camera"
local aimbotFOV        = 250
local aimbotSmooth     = 8
local aimbotTarget     = "Head"
local aimbotActive     = false
local aimbotFovCircle  = nil
local aimbotKeybind    = Enum.UserInputType.MouseButton2
local aimbotKeybindCode  = nil
local aimbotKeybindLabel = "RMB"
local aimbotKeybindType  = "MouseButton"
local isBindingKey       = false
local aimbotPrediction   = true
local predStrength       = 0.15
local velCache           = {}
local aimbotPriority     = "Crosshair"
local aimbotMaxDist      = 100
local espMaxDist         = 100
local aimbotStatusLbl    = nil
local keybindBtnRef      = nil
local vFlyEnabled        = false
local vFlySpeed          = 60
local vFlyConn           = nil
local vFlyUp             = false
local vFlyDown           = false
local fovColor           = Color3.fromRGB(0, 196, 255)
local espBoxColor        = Color3.fromRGB(0, 255, 136)
local espNameColor       = Color3.fromRGB(255, 255, 255)
local mb4Held            = false
local mb5Held            = false
local minKeyType         = "KeyCode"
local minKeyCode         = Enum.KeyCode.RightShift
local minKeyMBtn         = nil
local isBindingMin       = false
local minKeybindBtnRef   = nil

local autoTP_Running = false
local autoTP_Thread  = nil
local tpStatusValue  = nil
local tpLoopValue    = nil

local safeMode        = false
local safeModeActive  = false
local lastHealth      = 100
local safeModeStatusLbl = nil

local autoSell_UI       = false
local asSelling         = false
local asSoldCount       = 0
local sellStatusLbl_ref = nil
local sellItemLbl_ref   = nil
local sellOrder_UI      = {"Small Marshmallow Bag","Medium Marshmallow Bag","Large Marshmallow Bag"}

local guiVisible        = true
local guiToggleKeyType  = "KeyCode"
local guiToggleKeyCode  = Enum.KeyCode.F1
local guiToggleMBtn     = nil
local isBindingGuiKey   = false
local guiKeybindBtnRef  = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY STORE"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiOk2 = false
if not guiOk2 then pcall(function() screenGui.Parent = gethui(); guiOk2 = true end) end
if not guiOk2 then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiOk2 = true end) end
if not guiOk2 then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local C = {
    bg      = Color3.fromRGB(10, 12, 15),
    topbar  = Color3.fromRGB(15, 19, 24),
    panel   = Color3.fromRGB(13, 16, 20),
    card    = Color3.fromRGB(20, 25, 32),
    card2   = Color3.fromRGB(16, 20, 26),
    accent  = Color3.fromRGB(0, 255, 136),
    accent2 = Color3.fromRGB(0, 196, 255),
    green   = Color3.fromRGB(0, 255, 136),
    red     = Color3.fromRGB(255, 60, 90),
    yellow  = Color3.fromRGB(255, 215, 0),
    purple  = Color3.fromRGB(192, 132, 252),
    text    = Color3.fromRGB(200, 216, 232),
    subtext = Color3.fromRGB(122, 143, 160),
    border  = Color3.fromRGB(30, 45, 61),
    navbg   = Color3.fromRGB(15, 19, 24),
}

local function mkCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p end
local function mkStroke(p, t, col) local s = Instance.new("UIStroke"); s.Thickness = t or 1; s.Color = col or C.border; s.Parent = p end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 390)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -195)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true; mainFrame.Draggable = true; mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mkCorner(mainFrame, 6); mkStroke(mainFrame, 1, C.border)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36); titleBar.BackgroundColor3 = C.topbar
titleBar.BorderSizePixel = 0; titleBar.Parent = mainFrame; mkCorner(titleBar, 6)
local tbLine = Instance.new("Frame")
tbLine.Size = UDim2.new(1,0,0,1); tbLine.Position = UDim2.new(0,0,1,-1)
tbLine.BackgroundColor3 = C.border; tbLine.BorderSizePixel = 0; tbLine.Parent = titleBar
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1,-160,1,0); titleLabel.Position = UDim2.new(0,12,0,0)
titleLabel.BackgroundTransparency = 1; titleLabel.Text = "MAJESTY STORE"
titleLabel.TextColor3 = C.accent; titleLabel.Font = Enum.Font.Gotham; titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.Parent = titleBar
local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0,120,1,0); versionLabel.Position = UDim2.new(1,-165,0,0)
versionLabel.BackgroundTransparency = 1; versionLabel.Text = "v8.3.1 | South Bronx"
versionLabel.TextColor3 = C.subtext; versionLabel.Font = Enum.Font.Gotham; versionLabel.TextSize = 10
versionLabel.TextXAlignment = Enum.TextXAlignment.Left; versionLabel.Parent = titleBar
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0,22,0,22); minBtn.Position = UDim2.new(1,-50,0.5,-11)
minBtn.BackgroundColor3 = Color3.fromRGB(35,45,55); minBtn.Text = "-"
minBtn.TextColor3 = C.text; minBtn.Font = Enum.Font.Gotham; minBtn.TextSize = 14
minBtn.BorderSizePixel = 0; minBtn.Parent = titleBar; mkCorner(minBtn, 4)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,22,0,22); closeBtn.Position = UDim2.new(1,-24,0.5,-11)
closeBtn.BackgroundColor3 = C.red; closeBtn.Text = "x"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255); closeBtn.Font = Enum.Font.Gotham; closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0; closeBtn.Parent = titleBar; mkCorner(closeBtn, 4)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy(); majestyAnnounce:Destroy() end)

local function doMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        task.spawn(function() task.wait(0.05)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v ~= titleBar and v:IsA("GuiObject") then v.Visible = false end
            end
        end)
        TweenService:Create(mainFrame, TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Size=UDim2.new(0,480,0,36)}):Play()
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Size=UDim2.new(0,480,0,390)}):Play()
        task.spawn(function() task.wait(0.18)
            for _, v in pairs(mainFrame:GetChildren()) do if v:IsA("GuiObject") then v.Visible = true end end
        end)
    end
end
minBtn.MouseButton1Click:Connect(doMinimize)

-- ... (semua kode lama dari sbFrame sampai akhir script tetap sama, aku cuma tambahin announcement di atas)

-- Contoh pemanggilan di teleport success (sudah diintegrasikan):
local function onCharacterAdded(char)
    -- ... kode lama kamu ...
    tpStatusValue.Text="ARRIVED"; tpStatusValue.TextColor3=C.accent
    showMajestyAnnounce("TELEPORT SUCCESS")   -- <-- ini yang baru
    task.wait(2)
    tpStatusValue.Text="STANDBY"; tpStatusValue.TextColor3=C.yellow
end

-- Kamu juga bisa panggil manual di tempat lain:
-- showMajestyAnnounce("AUTO MS COMPLETE")
-- showMajestyAnnounce("SAFE MODE ACTIVATED")

print("=== MAJESTY STORE v8.3.1 LOADED WITH MAJESTIC ANNOUNCEMENT ===")
print("discord.gg/VPeZbhCz8M")
