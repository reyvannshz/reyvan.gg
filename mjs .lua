-- ========== MAJESTY STORE - INVENTORY TRACKER DENGAN MINIMIZE BUTTON ==========
-- Bisa lihat jumlah item di inventory (Water, Gelatin, Sugar Block Bag, Empty Bag)
-- VERSI FIX: URUTAN Water -> Sugar -> Gelatin -> Bag (dengan delay 1 detik)
-- FITUR BARU: Tombol minimize (kecilin GUI)

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Variables
local LocalPlayer = Players.LocalPlayer
local AutoMS_Running = false
local autoSell_Running = false
local autoSell_Count   = 0
local isMinimized = false
local InventoryItems = {
    Water = 0,
    Gelatin = 0,
    Sugar = 0,
    Bag = 0
}

-- ESP Variables
local espEnabled = false
local espCache = {}
local boxPadding = 4
local espItemColor   = Color3.fromRGB(255, 220, 50)
local espShowItem    = true
local ESP_INTERVAL   = 0.05
local _espAccum      = 0

-- ========== AIMBOT VARIABLES ==========
local aimbotEnabled      = false
local aimbotMode         = "Camera"
local aimbotFOV          = 250
local aimbotSmooth       = 8
local aimbotTarget       = "Head"
local aimbotActive       = false
local aimbotFovCircle    = nil
local aimbotKeybind      = Enum.UserInputType.MouseButton2
local aimbotKeybindIsKey = false
local aimbotKeybindCode  = nil
local aimbotKeybindLabel = "RMB"
local aimbotKeybindType  = "MouseButton"
local isBindingKey       = false
local keybindBtnRef      = nil
local aimbotStatusLbl    = nil

-- Prediction system
local aimbotPrediction   = true
local predStrength       = 0.15
local velCache           = {}

local aimbotPriority     = "Crosshair"
local aimbotMaxDist      = 100
local espMaxDist         = 100

-- ========== VEHICLE FLY VARIABLES ==========
local vFlyEnabled = false
local vFlySpeed   = 60
local vFlyConn    = nil
local vFlyUp      = false
local vFlyDown    = false

local fovColor           = Color3.fromRGB(220, 38, 38)
local espBoxColor        = Color3.fromRGB(255, 50, 50)
local espNameColor       = Color3.fromRGB(255, 255, 255)
local mb4Held = false
local mb5Held = false

-- ========== MINIMIZE KEYBIND VARIABLES ==========
local minKeyType      = "KeyCode"
local minKeyCode      = Enum.KeyCode.RightShift
local minKeyMBtn      = nil
local minKeyLabel     = "RShift"
local isBindingMin    = false
local minKeybindBtnRef = nil

-- Tunggu character spawn
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ========== GUI MAJESTY STORE ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY STORE"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiParentOk = false
if not guiParentOk then pcall(function() screenGui.Parent = gethui(); guiParentOk = true end) end
if not guiParentOk then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiParentOk = true end) end
if not guiParentOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ===== WARNA TEMA =====
local C = {
    bg       = Color3.fromRGB(10, 12, 15),
    topbar   = Color3.fromRGB(15, 19, 24),
    panel    = Color3.fromRGB(13, 16, 20),
    card     = Color3.fromRGB(20, 25, 32),
    card2    = Color3.fromRGB(16, 20, 26),
    accent   = Color3.fromRGB(0, 255, 136),
    accent2  = Color3.fromRGB(0, 196, 255),
    green    = Color3.fromRGB(0, 255, 136),
    red      = Color3.fromRGB(255, 60, 90),
    yellow   = Color3.fromRGB(255, 215, 0),
    text     = Color3.fromRGB(200, 216, 232),
    subtext  = Color3.fromRGB(122, 143, 160),
    border   = Color3.fromRGB(30, 45, 61),
    search   = Color3.fromRGB(20, 25, 32),
    navbg    = Color3.fromRGB(15, 19, 24),
}

local function mkCorner(p, r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 8) c.Parent=p end
local function mkStroke(p, t, col) local s=Instance.new("UIStroke") s.Thickness=t or 1 s.Color=col or C.border s.Parent=p end

-- ===== MAIN WINDOW =====
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 390)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -195)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mkCorner(mainFrame, 6)
mkStroke(mainFrame, 1, C.border)

-- ===== TITLE BAR (clean - no dots, no symbols) =====
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = C.topbar
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
mkCorner(titleBar, 6)

local tbLine = Instance.new("Frame")
tbLine.Size = UDim2.new(1, 0, 0, 1)
tbLine.Position = UDim2.new(0, 0, 1, -1)
tbLine.BackgroundColor3 = C.border
tbLine.BorderSizePixel = 0
tbLine.Parent = titleBar

-- Title text: "MAJESTY STORE" only, no diamond, no dots
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -160, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MAJESTY STORE"
titleLabel.TextColor3 = C.accent
titleLabel.Font = Enum.Font.Gotham
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 100, 1, 0)
versionLabel.Position = UDim2.new(1, -155, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v8.0.0 | South Bronx"
versionLabel.TextColor3 = C.subtext
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 10
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = titleBar

-- Minimize and Close buttons
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.Position = UDim2.new(1, -50, 0.5, -11)
minBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
minBtn.Text = "-"
minBtn.TextColor3 = C.text
minBtn.Font = Enum.Font.Gotham
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.Parent = titleBar
mkCorner(minBtn, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -24, 0.5, -11)
closeBtn.BackgroundColor3 = C.red
closeBtn.Text = "x"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
mkCorner(closeBtn, 4)

closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        task.spawn(function()
            task.wait(0.05)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v ~= titleBar and v:IsA("GuiObject") then v.Visible = false end
            end
        end)
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,480,0,36)}):Play()
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,480,0,390)}):Play()
        task.spawn(function()
            task.wait(0.18)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v:IsA("GuiObject") then v.Visible = true end
            end
        end)
    end
end)

local function doMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        task.spawn(function()
            task.wait(0.05)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v ~= titleBar and v:IsA("GuiObject") then v.Visible = false end
            end
        end)
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,480,0,36)}):Play()
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,480,0,390)}):Play()
        task.spawn(function()
            task.wait(0.18)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v:IsA("GuiObject") then v.Visible = true end
            end
        end)
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if isBindingKey or isBindingMin then return end
    if gpe then return end
    local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
    local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")
    local triggered = false
    if minKeyType == "KeyCode" then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == minKeyCode then triggered = true end
    elseif minKeyType == "MouseButton" then
        if minKeyMBtn ~= nil and input.UserInputType == minKeyMBtn then triggered = true end
    elseif minKeyType == "MB4" then
        if kn == "MouseButton4" or un == "MouseButton4" then triggered = true end
    elseif minKeyType == "MB5" then
        if kn == "MouseButton5" or un == "MouseButton5" then triggered = true end
    end
    if triggered then doMinimize() end
end)

-- Status bar (no emoji, no player icon)
local statusBarFrame = Instance.new("Frame")
statusBarFrame.Size = UDim2.new(1, 0, 0, 24)
statusBarFrame.Position = UDim2.new(0, 0, 0, 36)
statusBarFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
statusBarFrame.BorderSizePixel = 0
statusBarFrame.Parent = mainFrame

local statusBarLine = Instance.new("Frame")
statusBarLine.Size = UDim2.new(1, 0, 0, 1)
statusBarLine.Position = UDim2.new(0, 0, 1, -1)
statusBarLine.BackgroundColor3 = C.border
statusBarLine.BorderSizePixel = 0
statusBarLine.Parent = statusBarFrame

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 6, 0, 6)
statusDot.Position = UDim2.new(0, 10, 0.5, -3)
statusDot.BackgroundColor3 = C.accent
statusDot.BorderSizePixel = 0
statusDot.Parent = statusBarFrame
mkCorner(statusDot, 3)

local statusTextLbl = Instance.new("TextLabel")
statusTextLbl.Size = UDim2.new(0, 160, 1, 0)
statusTextLbl.Position = UDim2.new(0, 22, 0, 0)
statusTextLbl.BackgroundTransparency = 1
statusTextLbl.Text = "EXECUTOR READY"
statusTextLbl.TextColor3 = C.subtext
statusTextLbl.Font = Enum.Font.Gotham
statusTextLbl.TextSize = 10
statusTextLbl.TextXAlignment = Enum.TextXAlignment.Left
statusTextLbl.Parent = statusBarFrame

local discordLbl = Instance.new("TextLabel")
discordLbl.Size = UDim2.new(0, 200, 1, 0)
discordLbl.Position = UDim2.new(1, -205, 0, 0)
discordLbl.BackgroundTransparency = 1
discordLbl.Text = "discord.gg/VPeZbhCz8M"
discordLbl.TextColor3 = C.subtext
discordLbl.Font = Enum.Font.Gotham
discordLbl.TextSize = 10
discordLbl.TextXAlignment = Enum.TextXAlignment.Right
discordLbl.Parent = statusBarFrame

-- ===== CONTENT AREA =====
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, 0, 1, -104)
contentArea.Position = UDim2.new(0, 0, 0, 60)
contentArea.BackgroundColor3 = C.panel
contentArea.BorderSizePixel = 0
contentArea.Parent = mainFrame

-- ===== TAB PAGES =====
local pages = {}
local function makePage()
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.accent
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.None
    sf.ScrollingEnabled = true
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.ElasticBehavior = Enum.ElasticBehavior.Never
    sf.Visible = false
    sf.Parent = contentArea
    return sf
end

local pageAuto      = makePage()
local pageEsp       = makePage()
local pageTP        = makePage()
local pageAimbot    = makePage()
local pageCredits   = makePage()

local whitelist = {}
local wlRefreshFn = nil

local function isWhitelisted(plr)
    return whitelist[plr.Name] == true
end

-- ========== ESP FUNCTIONS ==========
local function removeESP(player)
    if espCache[player] then
        for _, obj in pairs(espCache[player]) do pcall(function() obj:Remove() end) end
        espCache[player] = nil
    end
end

local function createESP(player)
    removeESP(player)
    local boxOutline = Drawing.new("Square")
    boxOutline.Thickness = 1; boxOutline.Color = espBoxColor; boxOutline.Filled = false; boxOutline.Visible = false
    local nameLabel = Drawing.new("Text")
    nameLabel.Text = player.Name; nameLabel.Size = 10; nameLabel.Font = 1; nameLabel.Color = espNameColor
    nameLabel.Outline = true; nameLabel.OutlineColor = Color3.fromRGB(0,0,0); nameLabel.Center = true; nameLabel.Visible = false
    local hpBarBg = Drawing.new("Square")
    hpBarBg.Thickness = 1; hpBarBg.Color = Color3.fromRGB(30,30,30); hpBarBg.Filled = true; hpBarBg.Visible = false
    local hpBarFill = Drawing.new("Square")
    hpBarFill.Thickness = 1; hpBarFill.Color = Color3.fromRGB(0,255,80); hpBarFill.Filled = true; hpBarFill.Visible = false
    local distLabel = Drawing.new("Text")
    distLabel.Size = 10; distLabel.Font = 1; distLabel.Color = Color3.fromRGB(180,220,255)
    distLabel.Outline = true; distLabel.OutlineColor = Color3.fromRGB(0,0,0); distLabel.Center = true; distLabel.Visible = false; distLabel.Text = ""
    local itemLabel = Drawing.new("Text")
    itemLabel.Size = 10; itemLabel.Font = 1; itemLabel.Color = espItemColor
    itemLabel.Outline = true; itemLabel.OutlineColor = Color3.fromRGB(0,0,0); itemLabel.Center = true; itemLabel.Visible = false; itemLabel.Text = ""
    espCache[player] = {boxOutline, nameLabel, hpBarBg, hpBarFill, distLabel, itemLabel}
end

local function getHeldItem(player)
    local char = player.Character
    if not char then return nil end
    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Tool") then return obj.Name end
    end
    return nil
end

-- Teleport Variables
local autoTP_Running = false
local autoTP_Thread = nil
local savedLocations = {
    {name = "NPC Marshmellow", x = 510.1238, y = 3.5872, z = 596.9278},
    {name = "Gunstore Tier",   x = 1169.678955078125, y = 3.362133026123047, z = 139.321533203125},
    {name = "Dealership",      x = 731.5349731445312, y = 3.7265229225158669, z = 409.34637451171875},
    {name = "Gunstore Mid",    x = 218.72975158691406, y = 3.729841709136963, z = -156.140625},
    {name = "Gunstore New",    x = -453.7384948730469, y = 3.7371323108673096, z = 343.8177490234375},
}
local tpStatusValue = nil
local tpLoopValue = nil

local pendingTP = nil

local function onCharacterAdded(newChar)
    if pendingTP then
        local target = pendingTP
        pendingTP = nil
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        local humanoid = newChar:WaitForChild("Humanoid", 5)
        if hrp and humanoid then
            task.wait(0.6)
            hrp.CFrame = target
        end
    end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

local function doTeleport(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp      = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return false end
    local dist = (hrp.Position - targetCFrame.Position).Magnitude
    if dist < 150 then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        task.wait(0.3)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.2)
        hrp.CFrame = targetCFrame
        task.wait(0.5)
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        return true
    end
    pendingTP = targetCFrame
    humanoid.Health = 0
    return true
end

-- ===== HELPERS =====
local function sectionTitle(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.subtext
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -20, 0, 1)
    line.Position = UDim2.new(0, 10, 0, yPos + 22)
    line.BackgroundColor3 = C.border
    line.BorderSizePixel = 0
    line.Parent = parent
    return lbl
end

local function makeCard(parent, yPos, h)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -20, 0, h or 44)
    f.Position = UDim2.new(0, 10, 0, yPos)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(f, 5)
    mkStroke(f, 1, C.border)
    return f
end

local function makeLabel(parent, text, x, y, w, h, size, color, font, xalign)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 0, h)
    l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or C.text
    l.Font = font or Enum.Font.Gotham
    l.TextSize = size or 13
    l.TextXAlignment = xalign or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local sellStatusLbl_ref = nil
local sellCountLbl_ref  = nil
local sellToggleBtn_ref = nil
local statusValue, phaseValue, timerValue, startBtn, stopBtn
local waterCount, gelatinCount, sugarCount, bagCount
local espToggleBtn

-- ===== PAGE 1: AUTO MS =====
do
    sectionTitle(pageAuto, "AUTO MARSHMALLOW", 8)
    local statCard = makeCard(pageAuto, 38, 44)
    makeLabel(statCard, "STATUS", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    statusValue = makeLabel(statCard, "OFF", 90, 0, 200, 44, 15, C.red, Enum.Font.Gotham)
    local phCard = makeCard(pageAuto, 90, 44)
    makeLabel(phCard, "PHASE", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    phaseValue = makeLabel(phCard, "Water", 90, 0, 200, 44, 14, C.accent2, Enum.Font.Gotham)
    local tmCard = makeCard(pageAuto, 142, 44)
    makeLabel(tmCard, "TIMER", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    timerValue = makeLabel(tmCard, "0s", 90, 0, 200, 44, 14, C.yellow, Enum.Font.Gotham)
    local infoCard = makeCard(pageAuto, 194, 28)
    makeLabel(infoCard, "Delay 1s antara Sugar - Gelatin  |  PageUp = toggle", 10, 0, 400, 28, 10, C.subtext, Enum.Font.Gotham)

    startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.47, -10, 0, 36)
    startBtn.Position = UDim2.new(0, 10, 0, 230)
    startBtn.BackgroundColor3 = C.card
    startBtn.Text = "START"
    startBtn.TextColor3 = Color3.fromRGB(0, 180, 80)
    startBtn.Font = Enum.Font.Gotham
    startBtn.TextSize = 13
    startBtn.BorderSizePixel = 0
    startBtn.Parent = pageAuto
    mkCorner(startBtn, 5)
    mkStroke(startBtn, 1, Color3.fromRGB(0, 180, 80))

    stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.47, -10, 0, 36)
    stopBtn.Position = UDim2.new(0.5, 5, 0, 230)
    stopBtn.BackgroundColor3 = C.card
    stopBtn.Text = "STOP"
    stopBtn.TextColor3 = Color3.fromRGB(180, 40, 60)
    stopBtn.Font = Enum.Font.Gotham
    stopBtn.TextSize = 13
    stopBtn.BorderSizePixel = 0
    stopBtn.Parent = pageAuto
    mkCorner(stopBtn, 5)
    mkStroke(stopBtn, 1, Color3.fromRGB(180, 40, 60))

    sectionTitle(pageAuto, "INVENTORY TRACKER", 278)
    local invItems = {
        {name="Water",       color=Color3.fromRGB(56,189,248)},
        {name="Gelatin",     color=Color3.fromRGB(251,146,60)},
        {name="Sugar Block", color=Color3.fromRGB(192,132,252)},
        {name="Empty Bag",   color=Color3.fromRGB(74,222,128)},
    }
    local invCountLabels = {}
    for i, item in ipairs(invItems) do
        local card = makeCard(pageAuto, 308 + (i-1)*52, 42)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, -8); bar.Position = UDim2.new(0, 4, 0, 4)
        bar.BackgroundColor3 = item.color; bar.BorderSizePixel = 0; bar.Parent = card
        mkCorner(bar, 2)
        makeLabel(card, item.name, 14, 0, 140, 42, 12, C.text, Enum.Font.Gotham)
        local cnt = makeLabel(card, "0", 0, 0, -12, 42, 18, item.color, Enum.Font.Gotham, Enum.TextXAlignment.Right)
        cnt.Size = UDim2.new(1, -12, 1, 0)
        invCountLabels[#invCountLabels+1] = cnt
    end
    waterCount   = invCountLabels[1]
    gelatinCount = invCountLabels[2]
    sugarCount   = invCountLabels[3]
    bagCount     = invCountLabels[4]

    sectionTitle(pageAuto, "AUTO SELL MARSHMALLOW", 522)
    local sellToggleBtn = Instance.new("TextButton")
    sellToggleBtn.Name = "SellToggleBtn"
    sellToggleBtn.Size = UDim2.new(1, -20, 0, 36)
    sellToggleBtn.Position = UDim2.new(0, 10, 0, 548)
    sellToggleBtn.BackgroundColor3 = C.card
    sellToggleBtn.Text = "AUTO SELL : OFF"
    sellToggleBtn.TextColor3 = C.red
    sellToggleBtn.Font = Enum.Font.Gotham
    sellToggleBtn.TextSize = 13
    sellToggleBtn.BorderSizePixel = 0
    sellToggleBtn.Parent = pageAuto
    mkCorner(sellToggleBtn, 5)
    mkStroke(sellToggleBtn, 1, C.border)
    local sellStatCard = makeCard(pageAuto, 592, 44)
    makeLabel(sellStatCard, "STATUS", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    local sellStatusLbl = makeLabel(sellStatCard, "OFF", 90, 0, 200, 44, 13, C.red, Enum.Font.Gotham)
    local sellCountCard = makeCard(pageAuto, 644, 44)
    makeLabel(sellCountCard, "TERJUAL", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    local sellCountLbl = makeLabel(sellCountCard, "0", 90, 0, 200, 44, 13, C.yellow, Enum.Font.Gotham)
    local msTypeCard = makeCard(pageAuto, 696, 28)
    makeLabel(msTypeCard, "Small  |  Medium  |  Big marshmellow", 10, 0, 400, 28, 10, C.subtext, Enum.Font.Gotham)
    sellStatusLbl_ref = sellStatusLbl
    sellCountLbl_ref  = sellCountLbl
    sellToggleBtn_ref = sellToggleBtn
    sellToggleBtn.MouseButton1Click:Connect(function()
        autoSell_Running = not autoSell_Running
        if autoSell_Running then
            sellToggleBtn.Text = "AUTO SELL : ON"
            sellToggleBtn.TextColor3 = C.accent
            sellToggleBtn.BackgroundColor3 = C.card
            mkStroke(sellToggleBtn, 1, C.border)
            sellStatusLbl.Text = "RUNNING"; sellStatusLbl.TextColor3 = C.accent
        else
            sellToggleBtn.Text = "AUTO SELL : OFF"
            sellToggleBtn.TextColor3 = C.red
            sellToggleBtn.BackgroundColor3 = C.card
            mkStroke(sellToggleBtn, 1, C.border)
            sellStatusLbl.Text = "OFF"; sellStatusLbl.TextColor3 = C.red
        end
    end)

    sectionTitle(pageAuto, "AUTO BUY BAHAN", 736)
    local buyQty = { water = 1, sugar = 1, gelatin = 1 }
    local function makeQtyRow(yPos, label, key)
        local card = makeCard(pageAuto, yPos, 44)
        makeLabel(card, label, 10, 0, 160, 44, 12, C.text, Enum.Font.Gotham)
        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0, 28, 0, 26); minusBtn.Position = UDim2.new(0, 170, 0, 9)
        minusBtn.Text = "-"; minusBtn.TextSize = 16; minusBtn.Font = Enum.Font.Gotham
        minusBtn.BackgroundColor3 = Color3.fromRGB(50,15,15); minusBtn.TextColor3 = C.red
        minusBtn.BorderSizePixel = 0; minusBtn.Parent = card; mkCorner(minusBtn, 5)
        local qtyLbl = Instance.new("TextLabel")
        qtyLbl.Size = UDim2.new(0, 38, 0, 26); qtyLbl.Position = UDim2.new(0, 203, 0, 9)
        qtyLbl.Text = "1"; qtyLbl.TextSize = 13; qtyLbl.Font = Enum.Font.Gotham
        qtyLbl.BackgroundTransparency = 1; qtyLbl.TextColor3 = C.text
        qtyLbl.TextXAlignment = Enum.TextXAlignment.Center; qtyLbl.Parent = card
        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0, 28, 0, 26); plusBtn.Position = UDim2.new(0, 246, 0, 9)
        plusBtn.Text = "+"; plusBtn.TextSize = 16; plusBtn.Font = Enum.Font.Gotham
        plusBtn.BackgroundColor3 = Color3.fromRGB(0,40,20); plusBtn.TextColor3 = C.accent
        plusBtn.BorderSizePixel = 0; plusBtn.Parent = card; mkCorner(plusBtn, 5)
        minusBtn.MouseButton1Click:Connect(function() buyQty[key] = math.max(1, buyQty[key]-1); qtyLbl.Text = tostring(buyQty[key]) end)
        plusBtn.MouseButton1Click:Connect(function() buyQty[key] = math.min(99, buyQty[key]+1); qtyLbl.Text = tostring(buyQty[key]) end)
    end
    makeQtyRow(762, "Water",       "water")
    makeQtyRow(812, "Sugar Block", "sugar")
    makeQtyRow(862, "Gelatin",     "gelatin")

    local autoBuy_Running = false
    local buyToggleBtn = Instance.new("TextButton")
    buyToggleBtn.Size = UDim2.new(1, -20, 0, 36)
    buyToggleBtn.Position = UDim2.new(0, 10, 0, 914)
    buyToggleBtn.BackgroundColor3 = C.card
    buyToggleBtn.Text = "AUTO BUY : OFF"
    buyToggleBtn.TextColor3 = C.red
    buyToggleBtn.Font = Enum.Font.Gotham
    buyToggleBtn.TextSize = 13
    buyToggleBtn.BorderSizePixel = 0
    buyToggleBtn.Parent = pageAuto
    mkCorner(buyToggleBtn, 5)
    mkStroke(buyToggleBtn, 1, C.border)

    local buyInfoCard = makeCard(pageAuto, 958, 28)
    makeLabel(buyInfoCard, "Buka shop NPC manual, lalu klik AUTO BUY", 10, 0, 440, 28, 10, C.yellow, Enum.Font.Gotham)

    buyToggleBtn.MouseButton1Click:Connect(function()
        autoBuy_Running = not autoBuy_Running
        if autoBuy_Running then
            buyToggleBtn.Text = "AUTO BUY : ON"
            buyToggleBtn.TextColor3 = C.accent
            buyToggleBtn.BackgroundColor3 = C.card
            mkStroke(buyToggleBtn, 1, C.border)
        else
            buyToggleBtn.Text = "AUTO BUY : OFF"
            buyToggleBtn.TextColor3 = C.red
            buyToggleBtn.BackgroundColor3 = C.card
            mkStroke(buyToggleBtn, 1, C.border)
        end
    end)

    pageAuto.CanvasSize = UDim2.new(0, 0, 0, 1020)
end

-- ===== PAGE 2: ESP + GENERAL =====
do
    sectionTitle(pageEsp, "ESP", 8)
    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(1, -20, 0, 34)
    espToggleBtn.Position = UDim2.new(0, 10, 0, 34)
    espToggleBtn.BackgroundColor3 = C.card
    espToggleBtn.Text = "Player ESP : OFF"
    espToggleBtn.TextColor3 = C.red
    espToggleBtn.Font = Enum.Font.Gotham
    espToggleBtn.TextSize = 13
    espToggleBtn.BorderSizePixel = 0
    espToggleBtn.Parent = pageEsp
    mkCorner(espToggleBtn, 5)
    mkStroke(espToggleBtn, 1, C.border)

    local espInfoRow = makeCard(pageEsp, 76, 24)
    makeLabel(espInfoRow, "Box  |  Username  |  HP Bar  |  Item Held  |  Distance", 10, 0, 400, 24, 10, C.subtext, Enum.Font.Gotham)

    espToggleBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
            espToggleBtn.Text = "Player ESP : ON"
            espToggleBtn.TextColor3 = C.accent
            espToggleBtn.BackgroundColor3 = C.card
            mkStroke(espToggleBtn, 1, C.border)
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    createESP(plr)
                    plr.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if espEnabled then createESP(plr) end
                    end)
                end
            end
        else
            espToggleBtn.Text = "Player ESP : OFF"
            espToggleBtn.TextColor3 = C.red
            espToggleBtn.BackgroundColor3 = C.card
            mkStroke(espToggleBtn, 1, C.border)
            for plr, _ in pairs(espCache) do removeESP(plr) end
        end
    end)

    Players.PlayerAdded:Connect(function(plr)
        if espEnabled and plr ~= LocalPlayer then
            plr.CharacterAdded:Connect(function()
                task.wait(0.5)
                if espEnabled then createESP(plr) end
            end)
            task.wait(0.5)
            if espEnabled then createESP(plr) end
        end
    end)
    Players.PlayerRemoving:Connect(function(plr)
        removeESP(plr)
    end)

    sectionTitle(pageEsp, "WHITELIST", 112)
    local wlActiveScroll = Instance.new("ScrollingFrame")
    wlActiveScroll.Size = UDim2.new(1, -20, 0, 80)
    wlActiveScroll.Position = UDim2.new(0, 10, 0, 138)
    wlActiveScroll.BackgroundColor3 = C.card
    wlActiveScroll.BorderSizePixel = 0
    wlActiveScroll.ScrollBarThickness = 2
    wlActiveScroll.ScrollBarImageColor3 = C.accent
    wlActiveScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    wlActiveScroll.Parent = pageEsp
    mkCorner(wlActiveScroll, 5)
    mkStroke(wlActiveScroll, 1, C.border)
    Instance.new("UIListLayout", wlActiveScroll).Padding = UDim.new(0, 2)
    local wlPad = Instance.new("UIPadding", wlActiveScroll)
    wlPad.PaddingTop = UDim.new(0,3); wlPad.PaddingLeft = UDim.new(0,3); wlPad.PaddingRight = UDim.new(0,3)

    local wlEmptyLbl = Instance.new("TextLabel")
    wlEmptyLbl.Size = UDim2.new(1,0,0,26); wlEmptyLbl.BackgroundTransparency = 1
    wlEmptyLbl.Text = "Belum ada player di whitelist"
    wlEmptyLbl.TextColor3 = C.subtext; wlEmptyLbl.Font = Enum.Font.Gotham; wlEmptyLbl.TextSize = 10
    wlEmptyLbl.Parent = wlActiveScroll

    local function refreshActiveList()
        for _, ch in pairs(wlActiveScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local count = 0
        for name, _ in pairs(whitelist) do
            count = count + 1
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,0,0,24); row.BackgroundColor3 = C.card2; row.BorderSizePixel = 0; row.Parent = wlActiveScroll
            mkCorner(row, 4)
            local nLbl = Instance.new("TextLabel")
            nLbl.Size = UDim2.new(1,-70,1,0); nLbl.Position = UDim2.new(0,8,0,0)
            nLbl.BackgroundTransparency = 1; nLbl.Text = name; nLbl.TextColor3 = C.accent2
            nLbl.Font = Enum.Font.Gotham; nLbl.TextSize = 11; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Parent = row
            local remBtn = Instance.new("TextButton")
            remBtn.Size = UDim2.new(0,56,0,18); remBtn.Position = UDim2.new(1,-60,0.5,-9)
            remBtn.BackgroundColor3 = Color3.fromRGB(100,15,15); remBtn.Text = "Remove"
            remBtn.TextColor3 = Color3.fromRGB(255,255,255); remBtn.Font = Enum.Font.Gotham; remBtn.TextSize = 8
            remBtn.BorderSizePixel = 0; remBtn.Parent = row; mkCorner(remBtn, 4)
            local capName = name
            remBtn.MouseButton1Click:Connect(function() whitelist[capName]=nil; refreshActiveList() end)
        end
        wlEmptyLbl.Visible = (count == 0)
        wlActiveScroll.CanvasSize = UDim2.new(0,0,0,count*26+6)
    end
    wlRefreshFn = refreshActiveList
    refreshActiveList()

    local serverScroll = Instance.new("ScrollingFrame")
    serverScroll.Size = UDim2.new(1,-20,0,100)
    serverScroll.Position = UDim2.new(0,10,0,228)
    serverScroll.BackgroundColor3 = C.card; serverScroll.BorderSizePixel = 0
    serverScroll.ScrollBarThickness = 2; serverScroll.ScrollBarImageColor3 = C.accent
    serverScroll.CanvasSize = UDim2.new(0,0,0,0); serverScroll.Parent = pageEsp
    mkCorner(serverScroll, 5); mkStroke(serverScroll, 1, C.border)
    Instance.new("UIListLayout", serverScroll).Padding = UDim.new(0,2)
    local sPad = Instance.new("UIPadding", serverScroll)
    sPad.PaddingTop = UDim.new(0,3); sPad.PaddingLeft = UDim.new(0,3); sPad.PaddingRight = UDim.new(0,3)

    local function refreshServerList()
        for _, ch in pairs(serverScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local count = 0
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                count = count + 1
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1,0,0,26); row.BackgroundColor3 = C.card2; row.BorderSizePixel = 0; row.Parent = serverScroll
                mkCorner(row, 4)
                local pLbl = Instance.new("TextLabel")
                pLbl.Size = UDim2.new(1,-84,1,0); pLbl.Position = UDim2.new(0,8,0,0)
                pLbl.BackgroundTransparency = 1; pLbl.Text = plr.Name
                pLbl.TextColor3 = whitelist[plr.Name] and C.accent2 or C.text
                pLbl.Font = Enum.Font.Gotham; pLbl.TextSize = 11; pLbl.TextXAlignment = Enum.TextXAlignment.Left; pLbl.Parent = row
                local addBtn = Instance.new("TextButton")
                addBtn.Size = UDim2.new(0,66,0,18); addBtn.Position = UDim2.new(1,-70,0.5,-9)
                addBtn.BorderSizePixel = 0; addBtn.Font = Enum.Font.Gotham; addBtn.TextSize = 9; addBtn.Parent = row
                mkCorner(addBtn, 4)
                local function syncBtn()
                    if whitelist[plr.Name] then
                        addBtn.Text = "Listed"; addBtn.BackgroundColor3 = Color3.fromRGB(10,50,20); addBtn.TextColor3 = C.accent
                    else
                        addBtn.Text = "Whitelist"; addBtn.BackgroundColor3 = Color3.fromRGB(10,30,70); addBtn.TextColor3 = C.accent2
                    end
                end
                syncBtn()
                addBtn.MouseButton1Click:Connect(function()
                    whitelist[plr.Name] = whitelist[plr.Name] ~= true and true or nil
                    syncBtn(); pLbl.TextColor3 = whitelist[plr.Name] and C.accent2 or C.text
                    refreshActiveList()
                end)
            end
        end
        serverScroll.CanvasSize = UDim2.new(0,0,0,count*28+6)
    end
    refreshServerList()
    Players.PlayerAdded:Connect(function() refreshServerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshServerList() end)

    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0.5,-14,0,30); refBtn.Position = UDim2.new(0,10,0,336)
    refBtn.BackgroundTransparency = 1; refBtn.Text = "Refresh"; refBtn.TextColor3 = C.subtext
    refBtn.Font = Enum.Font.Gotham; refBtn.TextSize = 11; refBtn.BorderSizePixel = 0; refBtn.Parent = pageEsp
    refBtn.MouseButton1Click:Connect(refreshServerList)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.5,-14,0,30); clearBtn.Position = UDim2.new(0.5,4,0,336)
    clearBtn.BackgroundTransparency = 1; clearBtn.Text = "Clear All"
    clearBtn.TextColor3 = C.subtext; clearBtn.Font = Enum.Font.Gotham; clearBtn.TextSize = 11
    clearBtn.BorderSizePixel = 0; clearBtn.Parent = pageEsp
    clearBtn.MouseButton1Click:Connect(function() whitelist = {}; refreshActiveList(); refreshServerList() end)

    -- VEHICLE FLY
    sectionTitle(pageEsp, "VEHICLE FLY", 378)
    local vFlyToggleBtn = Instance.new("TextButton")
    vFlyToggleBtn.Size = UDim2.new(1,-20,0,34); vFlyToggleBtn.Position = UDim2.new(0,10,0,404)
    vFlyToggleBtn.BackgroundColor3 = C.card; vFlyToggleBtn.Text = "Vehicle Fly : OFF"
    vFlyToggleBtn.TextColor3 = C.red; vFlyToggleBtn.Font = Enum.Font.Gotham; vFlyToggleBtn.TextSize = 13
    vFlyToggleBtn.BorderSizePixel = 0; vFlyToggleBtn.Parent = pageEsp
    mkCorner(vFlyToggleBtn, 5); mkStroke(vFlyToggleBtn, 1, C.border)

    local vFlyStatCard = makeCard(pageEsp, 446, 34)
    makeLabel(vFlyStatCard, "STATUS", 12, 0, 80, 34, 10, C.subtext, Enum.Font.Gotham)
    local vFlyStatLbl = makeLabel(vFlyStatCard, "Tidak di kendaraan", 90, 0, 260, 34, 11, C.subtext, Enum.Font.Gotham)

    -- Speed slider
    local vFlySpeedCard = makeCard(pageEsp, 488, 44)
    makeLabel(vFlySpeedCard, "Kecepatan Terbang", 12, 2, 200, 20, 11, C.text, Enum.Font.Gotham)
    local vFlySpeedValLbl = makeLabel(vFlySpeedCard, tostring(vFlySpeed), 0, 2, -12, 20, 11, C.accent2, Enum.Font.Gotham, Enum.TextXAlignment.Right)
    vFlySpeedValLbl.Size = UDim2.new(1, -12, 0, 20)
    local vFlyTrack = Instance.new("Frame")
    vFlyTrack.Size = UDim2.new(1,-20,0,3); vFlyTrack.Position = UDim2.new(0,10,0,32)
    vFlyTrack.BackgroundColor3 = C.border; vFlyTrack.BorderSizePixel = 0; vFlyTrack.Parent = vFlySpeedCard
    mkCorner(vFlyTrack, 2)
    local vFlyFill = Instance.new("Frame")
    local spRatio0 = (vFlySpeed-10)/(300-10)
    vFlyFill.Size = UDim2.new(spRatio0,0,1,0); vFlyFill.BackgroundColor3 = C.accent; vFlyFill.BorderSizePixel = 0; vFlyFill.Parent = vFlyTrack
    mkCorner(vFlyFill, 2)
    local vFlyKnob = Instance.new("TextButton")
    vFlyKnob.Size = UDim2.new(0,10,0,10); vFlyKnob.Position = UDim2.new(spRatio0,-5,0.5,-5)
    vFlyKnob.BackgroundColor3 = Color3.fromRGB(255,255,255); vFlyKnob.Text = ""; vFlyKnob.BorderSizePixel = 0; vFlyKnob.Parent = vFlyTrack
    mkCorner(vFlyKnob, 5)
    local vFlyDragging = false
    vFlyKnob.MouseButton1Down:Connect(function() vFlyDragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then vFlyDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if vFlyDragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local ap = vFlyTrack.AbsolutePosition; local as = vFlyTrack.AbsoluteSize
            local r = math.clamp((i.Position.X-ap.X)/as.X,0,1)
            vFlySpeed = math.floor(10 + r*(300-10))
            vFlyFill.Size = UDim2.new(r,0,1,0); vFlyKnob.Position = UDim2.new(r,-5,0.5,-5)
            vFlySpeedValLbl.Text = tostring(vFlySpeed)
        end
    end)

    local vFlyInfoCard = makeCard(pageEsp, 540, 40)
    makeLabel(vFlyInfoCard, "E = Naik   |   Q = Turun   |   WASD = Steer", 10, 4, 380, 16, 10, C.subtext, Enum.Font.Gotham)
    makeLabel(vFlyInfoCard, "Steer otomatis mengikuti arah kamera", 10, 20, 340, 16, 10, Color3.fromRGB(80,180,80), Enum.Font.Gotham)

    local function getVehicleSeat()
        local char = LocalPlayer.Character; if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then return hum.SeatPart end
        return nil
    end
    local function getVehicleRoot(seat)
        if not seat then return nil end
        local model = seat:FindFirstAncestorOfClass("Model")
        if model then
            if model.PrimaryPart then return model.PrimaryPart end
            local biggest, bigSize = nil, 0
            for _, p in pairs(model:GetDescendants()) do
                if p:IsA("BasePart") and p ~= seat then
                    local vol = p.Size.X*p.Size.Y*p.Size.Z
                    if vol > bigSize then bigSize=vol; biggest=p end
                end
            end
            return biggest or seat
        end
        return seat
    end
    local function getVehicleModel(seat)
        if not seat then return nil end
        return seat:FindFirstAncestorOfClass("Model") or seat
    end

    UserInputService.InputBegan:Connect(function(input, gpe)
        if not vFlyEnabled then return end; if gpe then return end
        if input.KeyCode == Enum.KeyCode.E then vFlyUp = true end
        if input.KeyCode == Enum.KeyCode.Q then vFlyDown = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E then vFlyUp = false end
        if input.KeyCode == Enum.KeyCode.Q then vFlyDown = false end
    end)

    local function startVehicleFly()
        if vFlyConn then vFlyConn:Disconnect(); vFlyConn = nil end
        vFlyConn = RunService.RenderStepped:Connect(function(dt)
            local seat = getVehicleSeat(); local root = getVehicleRoot(seat); local model = getVehicleModel(seat)
            if not (seat and root and model) then vFlyStatLbl.Text="Tidak di kendaraan"; vFlyStatLbl.TextColor3=C.subtext; return end
            vFlyStatLbl.Text="Terbang aktif"; vFlyStatLbl.TextColor3=C.accent
            local camCF = Camera.CFrame
            local forward = Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z)
            if forward.Magnitude > 0.01 then forward = forward.Unit else forward = Vector3.new(0,0,-1) end
            local right = Vector3.new(camCF.RightVector.X,0,camCF.RightVector.Z)
            if right.Magnitude > 0.01 then right = right.Unit else right = Vector3.new(1,0,0) end
            local moveVec = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + right end
            if vFlyUp then moveVec = moveVec + Vector3.new(0,1,0) end
            if vFlyDown then moveVec = moveVec - Vector3.new(0,1,0) end
            pcall(function()
                for _, p in pairs(model:GetDescendants()) do
                    if p:IsA("BasePart") then p.AssemblyLinearVelocity=Vector3.zero; p.AssemblyAngularVelocity=Vector3.zero end
                end
            end)
            if moveVec.Magnitude > 0 then
                moveVec = moveVec.Unit
                local newPos = root.Position + moveVec * vFlySpeed * dt
                local lookDir = Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z)
                if lookDir.Magnitude > 0.01 then lookDir = lookDir.Unit else lookDir = forward end
                pcall(function()
                    local currentPivot = model:GetPivot()
                    local targetCF = CFrame.new(newPos, newPos+lookDir)
                    local offset = currentPivot:ToObjectSpace(root.CFrame)
                    model:PivotTo(targetCF * offset:Inverse())
                end)
            end
        end)
    end
    local function stopVehicleFly()
        if vFlyConn then vFlyConn:Disconnect(); vFlyConn=nil end
        vFlyUp=false; vFlyDown=false
        vFlyStatLbl.Text="Tidak di kendaraan"; vFlyStatLbl.TextColor3=C.subtext
    end
    vFlyToggleBtn.MouseButton1Click:Connect(function()
        vFlyEnabled = not vFlyEnabled
        if vFlyEnabled then
            vFlyToggleBtn.Text="Vehicle Fly : ON"; vFlyToggleBtn.TextColor3=C.accent
            vFlyToggleBtn.BackgroundColor3=C.card; mkStroke(vFlyToggleBtn,1,C.border)
            startVehicleFly()
        else
            vFlyToggleBtn.Text="Vehicle Fly : OFF"; vFlyToggleBtn.TextColor3=C.red
            vFlyToggleBtn.BackgroundColor3=C.card; mkStroke(vFlyToggleBtn,1,C.border)
            stopVehicleFly()
        end
    end)
    pageEsp.CanvasSize = UDim2.new(0,0,0,620)
end

-- ===== PAGE 3: TELEPORT =====
do
    sectionTitle(pageTP, "TELEPORT STATUS", 8)
    local tpStatCard = makeCard(pageTP, 38, 44)
    makeLabel(tpStatCard, "STATUS", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    tpStatusValue = makeLabel(tpStatCard, "STANDBY", 90, 0, 200, 44, 15, C.yellow, Enum.Font.Gotham)
    local tpLoopCard = makeCard(pageTP, 90, 44)
    makeLabel(tpLoopCard, "MODE", 12, 0, 80, 44, 10, C.subtext, Enum.Font.Gotham)
    tpLoopValue = makeLabel(tpLoopCard, "ONCE", 90, 0, 200, 44, 13, C.accent, Enum.Font.Gotham)

    sectionTitle(pageTP, "PILIH LOKASI", 146)
    for i, loc in ipairs(savedLocations) do
        local locBtn = Instance.new("TextButton")
        locBtn.Size = UDim2.new(1,-20,0,38); locBtn.Position = UDim2.new(0,10,0,170+(i-1)*46)
        locBtn.BackgroundColor3 = C.card; locBtn.Text = loc.name
        locBtn.TextColor3 = C.text; locBtn.Font = Enum.Font.Gotham; locBtn.TextSize = 12
        locBtn.TextXAlignment = Enum.TextXAlignment.Left; locBtn.BorderSizePixel = 0; locBtn.Parent = pageTP
        mkCorner(locBtn, 5); mkStroke(locBtn, 1, C.border)
        local pad = Instance.new("UIPadding", locBtn); pad.PaddingLeft = UDim.new(0,12)
        local ci = i
        locBtn.MouseButton1Click:Connect(function()
            local l = savedLocations[ci]
            tpStatusValue.Text = "TELEPORTING..."; tpStatusValue.TextColor3 = C.yellow
            task.spawn(function()
                doTeleport(CFrame.new(l.x, l.y+3, l.z))
                task.wait(1)
                tpStatusValue.Text = "ARRIVED"; tpStatusValue.TextColor3 = C.accent
                task.wait(2); tpStatusValue.Text = "STANDBY"; tpStatusValue.TextColor3 = C.yellow
            end)
        end)
        locBtn.MouseEnter:Connect(function() locBtn.BackgroundColor3 = Color3.fromRGB(25,35,50) end)
        locBtn.MouseLeave:Connect(function() locBtn.BackgroundColor3 = C.card end)
    end

    sectionTitle(pageTP, "AUTO LOOP TELEPORT", 400)
    local loopToggle = Instance.new("TextButton")
    loopToggle.Size = UDim2.new(1,-20,0,36); loopToggle.Position = UDim2.new(0,10,0,426)
    loopToggle.BackgroundColor3 = C.card; loopToggle.Text = "Auto Loop : OFF"
    loopToggle.TextColor3 = C.red; loopToggle.Font = Enum.Font.Gotham; loopToggle.TextSize = 13
    loopToggle.BorderSizePixel = 0; loopToggle.Parent = pageTP
    mkCorner(loopToggle, 5); mkStroke(loopToggle, 1, C.border)
    local intervalCard = makeCard(pageTP, 470, 28)
    makeLabel(intervalCard, "Interval teleport: setiap 30 detik", 10, 0, 300, 28, 10, C.subtext, Enum.Font.Gotham)

    sectionTitle(pageTP, "TELEPORT KE PLAYER", 510)
    local playerListFrame = Instance.new("ScrollingFrame")
    playerListFrame.Size = UDim2.new(1,-20,0,90); playerListFrame.Position = UDim2.new(0,10,0,536)
    playerListFrame.BackgroundColor3 = C.card; playerListFrame.BorderSizePixel = 0
    playerListFrame.ScrollBarThickness = 3; playerListFrame.ScrollBarImageColor3 = C.accent
    playerListFrame.CanvasSize = UDim2.new(0,0,0,0); playerListFrame.Parent = pageTP
    mkCorner(playerListFrame, 5); mkStroke(playerListFrame, 1, C.border)
    Instance.new("UIListLayout", playerListFrame).Padding = UDim.new(0,4)

    local function refreshPlayerList()
        for _, ch in pairs(playerListFrame:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        local players = Players:GetPlayers(); local count = 0
        for _, plr in pairs(players) do
            if plr ~= LocalPlayer then
                local pb = Instance.new("TextButton")
                pb.Size = UDim2.new(1,-8,0,26); pb.BackgroundColor3 = C.card2
                pb.Text = plr.Name; pb.TextColor3 = C.text; pb.Font = Enum.Font.Gotham; pb.TextSize = 11
                pb.TextXAlignment = Enum.TextXAlignment.Left; pb.BorderSizePixel = 0; pb.Parent = playerListFrame
                mkCorner(pb, 4)
                local pad2 = Instance.new("UIPadding", pb); pad2.PaddingLeft = UDim.new(0,8)
                pb.MouseButton1Click:Connect(function()
                    local tgt = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if tgt then
                        tpStatusValue.Text = "TP: "..plr.Name; tpStatusValue.TextColor3 = C.yellow
                        task.spawn(function()
                            doTeleport(tgt.CFrame + Vector3.new(2,0,0))
                            tpStatusValue.Text = "ARRIVED"; tpStatusValue.TextColor3 = C.accent
                            task.wait(2); tpStatusValue.Text = "STANDBY"; tpStatusValue.TextColor3 = C.yellow
                        end)
                    end
                end)
                count = count + 1
            end
        end
        playerListFrame.CanvasSize = UDim2.new(0,0,0,count*30)
    end

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1,-20,0,32); refreshBtn.Position = UDim2.new(0,10,0,634)
    refreshBtn.BackgroundColor3 = C.card; refreshBtn.Text = "Refresh Daftar Player"
    refreshBtn.TextColor3 = C.text; refreshBtn.Font = Enum.Font.Gotham; refreshBtn.TextSize = 11
    refreshBtn.BorderSizePixel = 0; refreshBtn.Parent = pageTP
    mkCorner(refreshBtn, 5); mkStroke(refreshBtn, 1, C.border)
    refreshBtn.MouseButton1Click:Connect(function()
        refreshBtn.Text = "Refreshing..."; refreshBtn.TextColor3 = C.yellow
        refreshPlayerList(); task.wait(0.3)
        refreshBtn.Text = "Refresh Daftar Player"; refreshBtn.TextColor3 = C.text
    end)
    refreshPlayerList()
    Players.PlayerAdded:Connect(function() task.wait(0.5); refreshPlayerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshPlayerList() end)

    loopToggle.MouseButton1Click:Connect(function()
        autoTP_Running = not autoTP_Running
        if autoTP_Running then
            loopToggle.Text = "Auto Loop : ON"; loopToggle.TextColor3 = C.accent
            loopToggle.BackgroundColor3 = C.card; mkStroke(loopToggle,1,C.border)
            tpLoopValue.Text = "LOOPING"; tpLoopValue.TextColor3 = C.accent
            autoTP_Thread = task.spawn(function()
                while autoTP_Running do
                    tpStatusValue.Text = "TELEPORTING"; tpStatusValue.TextColor3 = C.yellow
                    doTeleport(CFrame.new(510.1238, 6.5872, 596.9278))
                    tpStatusValue.Text = "ARRIVED"; tpStatusValue.TextColor3 = C.accent
                    for i = 30, 1, -1 do
                        if not autoTP_Running then break end
                        tpLoopValue.Text = "Next: "..i.."s"; task.wait(1)
                    end
                end
                tpLoopValue.Text = "ONCE"; tpLoopValue.TextColor3 = C.accent
            end)
        else
            autoTP_Running = false
            loopToggle.Text = "Auto Loop : OFF"; loopToggle.TextColor3 = C.red
            loopToggle.BackgroundColor3 = C.card; mkStroke(loopToggle,1,C.border)
            tpLoopValue.Text = "ONCE"; tpLoopValue.TextColor3 = C.accent
            tpStatusValue.Text = "STANDBY"; tpStatusValue.TextColor3 = C.yellow
        end
    end)
    pageTP.CanvasSize = UDim2.new(0,0,0,700)
end

-- ===== BOTTOM NAV =====
local tabDefs = {
    {label="AUTO MS",  page=pageAuto},
    {label="GENERAL",  page=pageEsp},
    {label="TELEPORT", page=pageTP},
    {label="AIMBOT",   page=pageAimbot},
    {label="CREDITS",  page=pageCredits},
}
local tabBtns = {}
local bottomNav = Instance.new("Frame")
bottomNav.Size = UDim2.new(1,0,0,44); bottomNav.Position = UDim2.new(0,0,1,-44)
bottomNav.BackgroundColor3 = C.navbg; bottomNav.BorderSizePixel = 0; bottomNav.Parent = mainFrame
mkStroke(bottomNav, 1, C.border)
local navLine2 = Instance.new("Frame")
navLine2.Size = UDim2.new(1,0,0,1); navLine2.BackgroundColor3 = C.border; navLine2.BorderSizePixel = 0; navLine2.Parent = bottomNav

local function setTab(idx)
    for i, tb in ipairs(tabBtns) do
        local isActive = (i == idx)
        tb.TextColor3 = isActive and C.accent or C.subtext
        local ind = tb:FindFirstChild("indicator")
        if ind then ind.Visible = isActive end
    end
    for _, td in ipairs(tabDefs) do td.page.Visible = false end
    tabDefs[idx].page.Visible = true
end

local navW = 1 / #tabDefs
for i, td in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(navW,0,1,0); btn.Position = UDim2.new(navW*(i-1),0,0,0)
    btn.BackgroundTransparency = 1; btn.Text = td.label; btn.TextColor3 = C.subtext
    btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.BorderSizePixel = 0; btn.Parent = bottomNav
    local ind = Instance.new("Frame")
    ind.Name = "indicator"; ind.Size = UDim2.new(0.7,0,0,2); ind.Position = UDim2.new(0.15,0,0,0)
    ind.BackgroundColor3 = C.accent; ind.BorderSizePixel = 0; ind.Visible = false; ind.Parent = btn
    mkCorner(ind, 2)
    tabBtns[i] = btn
    local ci = i
    btn.MouseButton1Click:Connect(function() setTab(ci) end)
end
setTab(1)

-- ===== AIMBOT PAGE =====
do
    local function mkRow(parent, yPos, h)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1,-16,0,h or 34); f.Position = UDim2.new(0,8,0,yPos)
        f.BackgroundColor3 = C.card; f.BorderSizePixel = 0; f.Parent = parent
        mkCorner(f, 5); mkStroke(f, 1, C.border); return f
    end
    local function mkRowLabel(row, txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.55,0,1,0); l.Position = UDim2.new(0,10,0,0)
        l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = C.text
        l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = row
    end
    local function mkSectionSep(parent, yPos, txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-16,0,18); l.Position = UDim2.new(0,8,0,yPos)
        l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = C.subtext
        l.Font = Enum.Font.Gotham; l.TextSize = 9; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
    end
    local function mkToggle(parent, defaultOn, callback)
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0,34,0,18); bg.Position = UDim2.new(1,-42,0.5,-9)
        bg.BackgroundColor3 = defaultOn and C.accent or C.border; bg.BorderSizePixel = 0; bg.Parent = parent
        mkCorner(bg, 9)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0,12,0,12); knob.Position = defaultOn and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.BorderSizePixel = 0; knob.Parent = bg; mkCorner(knob, 6)
        local state = defaultOn
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = bg
        btn.MouseButton1Click:Connect(function()
            state = not state
            bg.BackgroundColor3 = state and C.accent or C.border
            knob.Position = state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
            if callback then callback(state) end
        end)
        return bg
    end
    local function mkPairBtn(parent, label1, label2, active, callback)
        local function makeB(txt, xOff, isActive)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0,78,0,22); b.Position = UDim2.new(1,xOff,0.5,-11)
            b.BackgroundColor3 = C.card2
            b.Text = txt; b.TextColor3 = isActive and C.text or C.subtext
            b.Font = Enum.Font.Gotham; b.TextSize = 10; b.BorderSizePixel = 0; b.Parent = parent
            mkCorner(b, 5)
            mkStroke(b, 1, C.border)
            return b
        end
        local b1 = makeB(label1, -162, active == 1)
        local b2 = makeB(label2, -78,  active == 2)
        local function refresh(which)
            b1.TextColor3 = which==1 and C.text or C.subtext
            b2.TextColor3 = which==2 and C.text or C.subtext
        end
        b1.MouseButton1Click:Connect(function() refresh(1); if callback then callback(1) end end)
        b2.MouseButton1Click:Connect(function() refresh(2); if callback then callback(2) end end)
        return b1, b2
    end
    local function mkSlider(parent, yPos, label, minV, maxV, defV, suffix, callback)
        local row = mkRow(parent, yPos, 44)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6,0,0,20); lbl.Position = UDim2.new(0,10,0,2)
        lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C.text
        lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.4,-10,0,20); valLbl.Position = UDim2.new(0.6,0,0,2)
        valLbl.BackgroundTransparency = 1; valLbl.Text = defV..suffix; valLbl.TextColor3 = C.accent2
        valLbl.Font = Enum.Font.Gotham; valLbl.TextSize = 11; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = row
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1,-20,0,3); track.Position = UDim2.new(0,10,0,32)
        track.BackgroundColor3 = C.border; track.BorderSizePixel = 0; track.Parent = row; mkCorner(track, 2)
        local ratio0 = (defV-minV)/(maxV-minV)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(ratio0,0,1,0); fill.BackgroundColor3 = C.accent; fill.BorderSizePixel = 0; fill.Parent = track; mkCorner(fill, 2)
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0,10,0,10); knob.Position = UDim2.new(ratio0,-5,0.5,-5)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.Text = ""; knob.BorderSizePixel = 0; knob.Parent = track; mkCorner(knob, 5)
        local dragging = false
        knob.MouseButton1Down:Connect(function() dragging = true end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local ap = track.AbsolutePosition; local as = track.AbsoluteSize
                local r = math.clamp((i.Position.X-ap.X)/as.X,0,1)
                local v = math.floor(minV + r*(maxV-minV))
                fill.Size = UDim2.new(r,0,1,0); knob.Position = UDim2.new(r,-5,0.5,-5)
                valLbl.Text = v..suffix
                if callback then callback(v) end
            end
        end)
    end
    local function mkColorRow(parent, yPos, label, onPick)
        local colorPresets = {
            Color3.fromRGB(220,38,38), Color3.fromRGB(255,255,255),
            Color3.fromRGB(0,210,255),  Color3.fromRGB(34,197,94),
            Color3.fromRGB(234,179,8),  Color3.fromRGB(168,85,247),
        }
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-16,0,13); lbl.Position = UDim2.new(0,8,0,yPos)
        lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C.subtext
        lbl.Font = Enum.Font.Gotham; lbl.TextSize = 9; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
        local sf = Instance.new("Frame")
        sf.Size = UDim2.new(1,-16,0,20); sf.Position = UDim2.new(0,8,0,yPos+14)
        sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.Parent = parent
        local cw = 1 / #colorPresets
        for ci, col in ipairs(colorPresets) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(cw,-3,1,0); sw.Position = UDim2.new(cw*(ci-1),0,0,0)
            sw.BackgroundColor3 = col; sw.Text = ""; sw.BorderSizePixel = 0; sw.Parent = sf
            mkCorner(sw, 4)
            local capC = col
            sw.MouseButton1Click:Connect(function()
                onPick(capC)
                for _, s in pairs(sf:GetChildren()) do
                    if s:IsA("TextButton") then s.BorderSizePixel = 0 end
                end
                sw.BorderSizePixel = 2
            end)
        end
    end

    local y = 6

    -- Enable Aimbot
    mkSectionSep(pageAimbot, y, "AIMBOT"); y = y + 20
    local statusRow = mkRow(pageAimbot, y, 34)
    local statusTxt = Instance.new("TextLabel")
    statusTxt.Size = UDim2.new(0.5,0,1,0); statusTxt.Position = UDim2.new(0,10,0,0)
    statusTxt.BackgroundTransparency = 1; statusTxt.Text = "Enable Aimbot"; statusTxt.TextColor3 = C.text
    statusTxt.Font = Enum.Font.Gotham; statusTxt.TextSize = 11; statusTxt.TextXAlignment = Enum.TextXAlignment.Left; statusTxt.Parent = statusRow
    aimbotStatusLbl = Instance.new("TextLabel")
    aimbotStatusLbl.Size = UDim2.new(0,40,1,0); aimbotStatusLbl.Position = UDim2.new(1,-88,0,0)
    aimbotStatusLbl.BackgroundTransparency = 1; aimbotStatusLbl.Text = "OFF"; aimbotStatusLbl.TextColor3 = C.red
    aimbotStatusLbl.Font = Enum.Font.Gotham; aimbotStatusLbl.TextSize = 11; aimbotStatusLbl.TextXAlignment = Enum.TextXAlignment.Right; aimbotStatusLbl.Parent = statusRow
    mkToggle(statusRow, false, function(s)
        aimbotEnabled = s
        aimbotStatusLbl.Text = s and "ON" or "OFF"; aimbotStatusLbl.TextColor3 = s and C.accent or C.red
        if aimbotFovCircle then aimbotFovCircle.Visible = s end
    end)
    y = y + 40

    -- Mode
    mkSectionSep(pageAimbot, y, "MODE"); y = y + 20
    local modeRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(modeRow, "Aim Mode")
    mkPairBtn(modeRow, "Camera", "FreeAim", 1, function(which)
        aimbotMode = which == 1 and "Camera" or "FreeAim"
    end)
    y = y + 40

    -- Target Part
    mkSectionSep(pageAimbot, y, "TARGET PART"); y = y + 20
    local targetParts  = {"Head","UpperTorso","Torso","HumanoidRootPart"}
    local targetLabels = {"Head","UpperTorso","Torso","HumanoidRootPart"}
    local targetIdx = 1
    local targetDropOpen = false
    local targetSelRow = mkRow(pageAimbot, y, 30)
    local targetSelLbl = Instance.new("TextLabel")
    targetSelLbl.Size = UDim2.new(0.42,0,1,0); targetSelLbl.Position = UDim2.new(0,10,0,0)
    targetSelLbl.BackgroundTransparency = 1; targetSelLbl.Text = "Target Part"; targetSelLbl.TextColor3 = C.text
    targetSelLbl.Font = Enum.Font.Gotham; targetSelLbl.TextSize = 11; targetSelLbl.TextXAlignment = Enum.TextXAlignment.Left; targetSelLbl.Parent = targetSelRow
    local targetValLbl = Instance.new("TextLabel")
    targetValLbl.Size = UDim2.new(0.36,0,1,0); targetValLbl.Position = UDim2.new(0.42,0,0,0)
    targetValLbl.BackgroundTransparency = 1; targetValLbl.Text = targetLabels[targetIdx]; targetValLbl.TextColor3 = C.accent2
    targetValLbl.Font = Enum.Font.Gotham; targetValLbl.TextSize = 10; targetValLbl.TextXAlignment = Enum.TextXAlignment.Right; targetValLbl.Parent = targetSelRow
    local chevronBtn = Instance.new("TextButton")
    chevronBtn.Size = UDim2.new(0,26,0,20); chevronBtn.Position = UDim2.new(1,-32,0.5,-10)
    chevronBtn.BackgroundColor3 = C.card2; chevronBtn.Text = "v"; chevronBtn.TextColor3 = C.accent2
    chevronBtn.Font = Enum.Font.Gotham; chevronBtn.TextSize = 11; chevronBtn.BorderSizePixel = 0; chevronBtn.Parent = targetSelRow
    mkCorner(chevronBtn, 4); mkStroke(chevronBtn, 1, C.border)
    y = y + 36
    local optionH = #targetLabels * 28 + 4
    local dropContainer = Instance.new("Frame")
    dropContainer.Size = UDim2.new(1,0,0,0); dropContainer.Position = UDim2.new(0,0,0,y)
    dropContainer.BackgroundTransparency = 1; dropContainer.BorderSizePixel = 0
    dropContainer.ClipsDescendants = true; dropContainer.Parent = pageAimbot
    local targetOptBtns = {}
    local function refreshTargetOpts()
        for li, btn in ipairs(targetOptBtns) do
            btn.TextColor3 = li == targetIdx and C.text or C.subtext
        end
        targetValLbl.Text = targetLabels[targetIdx]
    end
    for li, lbl in ipairs(targetLabels) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1,-16,0,24); optBtn.Position = UDim2.new(0,8,0,(li-1)*28+2)
        optBtn.BackgroundColor3 = C.card2; optBtn.TextColor3 = C.subtext; optBtn.Font = Enum.Font.Gotham
        optBtn.TextSize = 10; optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.Text = "    "..lbl; optBtn.BorderSizePixel = 0; optBtn.Parent = dropContainer
        mkCorner(optBtn, 4)
        mkStroke(optBtn, 1, C.border)
        targetOptBtns[li] = optBtn
        local capLi = li
        optBtn.MouseButton1Click:Connect(function()
            targetIdx = capLi; aimbotTarget = targetParts[capLi]; refreshTargetOpts()
        end)
    end
    refreshTargetOpts()
    local function toggleTargetDrop()
        targetDropOpen = not targetDropOpen
        TweenService:Create(dropContainer, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(1,0,0,targetDropOpen and optionH or 0)}):Play()
        chevronBtn.Text = targetDropOpen and "^" or "v"
        chevronBtn.TextColor3 = targetDropOpen and C.text or C.accent2
    end
    chevronBtn.MouseButton1Click:Connect(toggleTargetDrop)
    local rowClickBtn = Instance.new("TextButton")
    rowClickBtn.Size = UDim2.new(1,-38,1,0); rowClickBtn.Position = UDim2.new(0,0,0,0)
    rowClickBtn.BackgroundTransparency = 1; rowClickBtn.Text = ""; rowClickBtn.BorderSizePixel = 0; rowClickBtn.Parent = targetSelRow
    rowClickBtn.MouseButton1Click:Connect(toggleTargetDrop)
    y = y + optionH + 6

    -- Priority
    local prioRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(prioRow, "Lock Priority")
    mkPairBtn(prioRow, "Crosshair", "Distance", 1, function(which)
        aimbotPriority = which == 1 and "Crosshair" or "Distance"
    end)
    y = y + 40

    -- Keybind
    mkSectionSep(pageAimbot, y, "KEYBIND"); y = y + 20
    local kbRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(kbRow, "Hold Key")
    local kbBtn = Instance.new("TextButton")
    kbBtn.Size = UDim2.new(0,80,0,22); kbBtn.Position = UDim2.new(1,-88,0.5,-11)
    kbBtn.BackgroundTransparency = 1; kbBtn.Text = "RMB"; kbBtn.TextColor3 = C.text
    kbBtn.Font = Enum.Font.Gotham; kbBtn.TextSize = 10; kbBtn.BorderSizePixel = 0; kbBtn.Parent = kbRow
    keybindBtnRef = kbBtn
    kbBtn.MouseButton1Click:Connect(function()
        if isBindingKey then return end; isBindingKey = true; kbBtn.Text = "..."; kbBtn.TextColor3 = C.subtext
    end)
    y = y + 40

    -- Minimize Keybind
    mkSectionSep(pageAimbot, y, "MINIMIZE KEYBIND"); y = y + 20
    local minKbRow = mkRow(pageAimbot, y, 34)
    local minKbLabelTxt = Instance.new("TextLabel")
    minKbLabelTxt.Size = UDim2.new(0.55,0,1,0); minKbLabelTxt.Position = UDim2.new(0,10,0,0)
    minKbLabelTxt.BackgroundTransparency = 1; minKbLabelTxt.Text = "Hide / Show GUI"
    minKbLabelTxt.TextColor3 = C.text; minKbLabelTxt.Font = Enum.Font.Gotham; minKbLabelTxt.TextSize = 11
    minKbLabelTxt.TextXAlignment = Enum.TextXAlignment.Left; minKbLabelTxt.Parent = minKbRow
    local minKbSubTxt = Instance.new("TextLabel")
    minKbSubTxt.Size = UDim2.new(0.55,0,0,12); minKbSubTxt.Position = UDim2.new(0,10,1,-14)
    minKbSubTxt.BackgroundTransparency = 1; minKbSubTxt.Text = "tidak terlihat di layar"
    minKbSubTxt.TextColor3 = C.subtext; minKbSubTxt.Font = Enum.Font.Gotham; minKbSubTxt.TextSize = 9
    minKbSubTxt.TextXAlignment = Enum.TextXAlignment.Left; minKbSubTxt.Parent = minKbRow
    local minKbBtn = Instance.new("TextButton")
    minKbBtn.Size = UDim2.new(0,80,0,22); minKbBtn.Position = UDim2.new(1,-88,0.5,-11)
    minKbBtn.BackgroundTransparency = 1; minKbBtn.Text = "RShift"; minKbBtn.TextColor3 = C.text
    minKbBtn.Font = Enum.Font.Gotham; minKbBtn.TextSize = 10; minKbBtn.BorderSizePixel = 0; minKbBtn.Parent = minKbRow
    minKeybindBtnRef = minKbBtn
    minKbBtn.MouseButton1Click:Connect(function()
        if isBindingMin then return end; isBindingMin = true; minKbBtn.Text = "..."; minKbBtn.TextColor3 = C.subtext
    end)
    y = y + 40

    -- Settings
    mkSectionSep(pageAimbot, y, "SETTINGS"); y = y + 20
    mkSlider(pageAimbot, y, "FOV Radius", 20, 400, aimbotFOV, "px", function(v)
        aimbotFOV = v; if aimbotFovCircle then aimbotFovCircle.Radius = v end
    end)
    y = y + 50
    mkColorRow(pageAimbot, y, "Warna FOV Circle", function(c)
        fovColor = c; if aimbotFovCircle then aimbotFovCircle.Color = c end
    end)
    y = y + 44
    mkSlider(pageAimbot, y, "Smooth", 1, 20, aimbotSmooth, "", function(v) aimbotSmooth = v end)
    y = y + 50
    mkSlider(pageAimbot, y, "Aimbot Max Distance", 10, 10000, aimbotMaxDist, "m", function(v) aimbotMaxDist = v end)
    y = y + 50
    mkSlider(pageAimbot, y, "ESP Max Distance", 10, 10000, espMaxDist, "m", function(v) espMaxDist = v end)
    y = y + 50

    -- Prediction
    mkSectionSep(pageAimbot, y, "PREDICTION"); y = y + 20
    local predRow = mkRow(pageAimbot, y, 34)
    local predLbl = Instance.new("TextLabel")
    predLbl.Size = UDim2.new(0.55,0,1,0); predLbl.Position = UDim2.new(0,10,0,0)
    predLbl.BackgroundTransparency = 1; predLbl.Text = "Enable Prediction"; predLbl.TextColor3 = C.text
    predLbl.Font = Enum.Font.Gotham; predLbl.TextSize = 11; predLbl.TextXAlignment = Enum.TextXAlignment.Left; predLbl.Parent = predRow
    mkToggle(predRow, aimbotPrediction, function(s) aimbotPrediction = s end)
    y = y + 40
    mkSlider(pageAimbot, y, "Prediction Strength", 0, 100, math.floor(predStrength*100), "%", function(v) predStrength = v/100 end)
    y = y + 50

    pageAimbot.CanvasSize = UDim2.new(0, 0, 0, y + 50)

    -- Input listeners for keybind binding
    UserInputService.InputBegan:Connect(function(input, gpe)
        if isBindingKey then
            if input.UserInputType == Enum.UserInputType.MouseButton1 then return end
            isBindingKey = false
            local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
            local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")
            if un == "MouseButton2" then aimbotKeybindType="MouseButton"; aimbotKeybind=Enum.UserInputType.MouseButton2; aimbotKeybindLabel="RMB"
            elseif un == "MouseButton3" then aimbotKeybindType="MouseButton"; aimbotKeybind=Enum.UserInputType.MouseButton3; aimbotKeybindLabel="MMB"
            elseif un == "MouseButton4" or kn == "MouseButton4" then aimbotKeybindType="MB4"; aimbotKeybindLabel="MB4"
            elseif un == "MouseButton5" or kn == "MouseButton5" then aimbotKeybindType="MB5"; aimbotKeybindLabel="MB5"
            elseif un == "Keyboard" and kn ~= "Unknown" then aimbotKeybindType="KeyCode"; aimbotKeybindIsKey=true; aimbotKeybindCode=input.KeyCode; aimbotKeybindLabel=kn
            else isBindingKey=true; return end
            kbBtn.Text = aimbotKeybindLabel; kbBtn.TextColor3 = C.text
        end
        if isBindingMin then
            if input.UserInputType == Enum.UserInputType.MouseButton1 then return end
            isBindingMin = false
            local kn2 = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
            local un2 = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")
            if un2 == "MouseButton2" then minKeyType="MouseButton"; minKeyCode=nil; minKeyMBtn=Enum.UserInputType.MouseButton2; minKeyLabel="RMB"
            elseif un2 == "MouseButton3" then minKeyType="MouseButton"; minKeyCode=nil; minKeyMBtn=Enum.UserInputType.MouseButton3; minKeyLabel="MMB"
            elseif un2 == "MouseButton4" or kn2 == "MouseButton4" then minKeyType="MB4"; minKeyCode=nil; minKeyMBtn=nil; minKeyLabel="MB4"
            elseif un2 == "MouseButton5" or kn2 == "MouseButton5" then minKeyType="MB5"; minKeyCode=nil; minKeyMBtn=nil; minKeyLabel="MB5"
            elseif un2 == "Keyboard" and kn2 ~= "Unknown" then minKeyType="KeyCode"; minKeyCode=input.KeyCode; minKeyMBtn=nil; minKeyLabel=kn2
            else isBindingMin=true; return end
            minKbBtn.Text = minKeyLabel; minKbBtn.TextColor3 = C.text
        end
    end)
end

-- ===== CREDITS PAGE =====
do
    sectionTitle(pageCredits, "CREDITS", 8)
    local creditData = {
        {role="Investor & Owner", name="Hiro",         color=Color3.fromRGB(255,215,0),   initials="HI"},
        {role="Developer",        name="V7x & Reyvan", color=Color3.fromRGB(100,180,255),  initials="V7"},
    }
    for i, cr in ipairs(creditData) do
        local card = makeCard(pageCredits, 38+(i-1)*66, 54)
        local avatar = Instance.new("Frame")
        avatar.Size = UDim2.new(0,36,0,36); avatar.Position = UDim2.new(0,10,0.5,-18)
        avatar.BackgroundColor3 = Color3.fromRGB(
            math.floor(cr.color.R*255*0.15),
            math.floor(cr.color.G*255*0.15),
            math.floor(cr.color.B*255*0.15)
        )
        avatar.BorderSizePixel = 0; avatar.Parent = card; mkCorner(avatar, 18)
        mkStroke(avatar, 1, cr.color)
        local initLbl = Instance.new("TextLabel")
        initLbl.Size = UDim2.new(1,0,1,0); initLbl.BackgroundTransparency=1
        initLbl.Text = cr.initials; initLbl.TextColor3 = cr.color
        initLbl.Font = Enum.Font.Gotham; initLbl.TextSize = 13
        initLbl.TextXAlignment = Enum.TextXAlignment.Center; initLbl.Parent = avatar
        makeLabel(card, cr.role, 56, 8, 280, 16, 10, C.subtext, Enum.Font.Gotham)
        makeLabel(card, cr.name, 56, 26, 280, 20, 14, cr.color, Enum.Font.Gotham)
    end
    local footerCard = makeCard(pageCredits, 38+#creditData*66, 38)
    local footerLbl = Instance.new("TextLabel")
    footerLbl.Size = UDim2.new(1,-20,1,0); footerLbl.Position = UDim2.new(0,10,0,0)
    footerLbl.BackgroundTransparency = 1; footerLbl.RichText = true
    footerLbl.Text = '<font color="rgb(255,60,90)">majesty.gg</font>  —  <font color="rgb(100,120,140)">Thank you for using MAJESTY STORE</font>'
    footerLbl.Font = Enum.Font.Gotham; footerLbl.TextSize = 11
    footerLbl.TextXAlignment = Enum.TextXAlignment.Center; footerLbl.Parent = footerCard
    local discCard = makeCard(pageCredits, 38+#creditData*66+46, 30)
    makeLabel(discCard, "discord.gg/VPeZbhCz8M", 0, 0, 0, 30, 11, C.subtext, Enum.Font.Gotham, Enum.TextXAlignment.Center).Size = UDim2.new(1,0,1,0)
    pageCredits.CanvasSize = UDim2.new(0,0,0,200)
end

-- ========== INVENTORY TRACKER ==========
local function updateInventory()
    pcall(function()
        local water,gelatin,sugar,bag = 0,0,0,0
        local function checkParent(parent)
            if not parent then return end
            for _, tool in pairs(parent:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = string.lower(tool.Name)
                    if name:find("water") then water = water+1
                    elseif name:find("gelatin") or name:find("gel") then gelatin = gelatin+1
                    elseif name:find("sugar") or name:find("gula") or name:find("block") then sugar = sugar+1
                    elseif name:find("bag") or name:find("tas") or name:find("empty") then bag = bag+1
                    end
                end
            end
        end
        checkParent(LocalPlayer:FindFirstChild("Backpack"))
        checkParent(LocalPlayer.Character)
        waterCount.Text   = tostring(water)
        gelatinCount.Text = tostring(gelatin)
        sugarCount.Text   = tostring(sugar)
        bagCount.Text     = tostring(bag)
        waterCount.TextColor3   = water>0   and Color3.fromRGB(56,189,248)  or C.subtext
        gelatinCount.TextColor3 = gelatin>0 and Color3.fromRGB(251,146,60)  or C.subtext
        sugarCount.TextColor3   = sugar>0   and Color3.fromRGB(192,132,252) or C.subtext
        bagCount.TextColor3     = bag>0     and Color3.fromRGB(74,222,128)  or C.subtext
    end)
end

-- ========== AUTO MS LOOP ==========
local function interact()
    pcall(function() local vim=game:GetService("VirtualInputManager"); vim:SendKeyEvent(true,Enum.KeyCode.E,false,game); task.wait(0.12); vim:SendKeyEvent(false,Enum.KeyCode.E,false,game) end)
    pcall(function() keypress(0x45) end); task.wait(0.12); pcall(function() keyrelease(0x45) end); task.wait(0.1)
end
local function holdItem(itemName)
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("Backpack") then
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                    tool.Parent = LocalPlayer.Character; task.wait(0.2); return true
                end
            end
        end
    end)
end
local function lookAt(itemName)
    pcall(function()
        local char = LocalPlayer.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart; local searchName = string.lower(itemName)
        for _, obj in pairs(Workspace:GetDescendants()) do
            if (obj:IsA("Part") or obj:IsA("MeshPart")) and string.find(string.lower(obj.Name), searchName) then
                if (root.Position-obj.Position).Magnitude < 15 then
                    root.CFrame = CFrame.lookAt(root.Position, Vector3.new(obj.Position.X, root.Position.Y, obj.Position.Z)); return
                end
            end
        end
    end)
end

local function autoMSLoop()
    while AutoMS_Running do
        local success = pcall(function()
            statusValue.Text="RUNNING"; statusValue.TextColor3=C.accent
            phaseValue.Text="Water"; timerValue.Text="0s"
            holdItem("water"); lookAt("water"); task.wait(0.3); interact(); updateInventory()
            for i=1,20 do if not AutoMS_Running then return end; timerValue.Text=i.."/20s"; updateInventory(); task.wait(1) end
            phaseValue.Text="Sugar"; holdItem("sugar"); lookAt("sugar"); task.wait(0.3); interact(); updateInventory()
            phaseValue.Text="Delay 1s"; timerValue.Text="1s"; task.wait(1); updateInventory()
            phaseValue.Text="Gelatin"; holdItem("gelatin"); lookAt("gelatin"); task.wait(0.3); interact(); updateInventory()
            for i=1,45 do if not AutoMS_Running then return end; phaseValue.Text="Ferment"; timerValue.Text=i.."/45s"; updateInventory(); task.wait(1) end
            phaseValue.Text="Bag"; holdItem("bag"); lookAt("bag"); task.wait(0.3); interact(); updateInventory()
            phaseValue.Text="Complete"; timerValue.Text="Done"; task.wait(2); updateInventory()
        end)
        if not success then statusValue.Text="ERROR"; statusValue.TextColor3=C.red; task.wait(2) end
    end
    statusValue.Text="OFF"; statusValue.TextColor3=C.red; phaseValue.Text="Water"; timerValue.Text="0s"
end

-- ========== AUTO SELL LOOP ==========
local msMsKeywords = {"small marshmellow","medium marshmellow","big marshmellow","smallmarshmellow","mediummarshmellow","bigmarshmellow","small marsh","medium marsh","big marsh","marshmellow"}
local function getMarshmellowItems()
    local items = {}
    local function checkP(parent)
        if not parent then return end
        for _, tool in pairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                for _, kw in pairs(msMsKeywords) do if n:find(kw) then table.insert(items, tool); break end end
            end
        end
    end
    checkP(LocalPlayer:FindFirstChild("Backpack")); checkP(LocalPlayer.Character)
    return items
end
local function holdE(durasi)
    durasi = durasi or 1.5
    pcall(function() local vim=game:GetService("VirtualInputManager"); vim:SendKeyEvent(true,Enum.KeyCode.E,false,game) end)
    pcall(function() keypress(0x45) end)
    local elapsed = 0
    while elapsed < durasi do if not autoSell_Running then break end; task.wait(0.05); elapsed=elapsed+0.05 end
    pcall(function() local vim=game:GetService("VirtualInputManager"); vim:SendKeyEvent(false,Enum.KeyCode.E,false,game) end)
    pcall(function() keyrelease(0x45) end); task.wait(0.1)
end
task.spawn(function()
    while true do
        task.wait(0.5)
        if autoSell_Running then
            local items = getMarshmellowItems()
            if #items == 0 then
                if sellStatusLbl_ref then sellStatusLbl_ref.Text="MENUNGGU MS"; sellStatusLbl_ref.TextColor3=C.yellow end
            else
                if sellStatusLbl_ref then sellStatusLbl_ref.Text="MENJUAL..."; sellStatusLbl_ref.TextColor3=C.accent end
                for _, marshmellow in ipairs(items) do
                    if not autoSell_Running then break end
                    pcall(function() if marshmellow.Parent ~= LocalPlayer.Character then marshmellow.Parent = LocalPlayer.Character end end)
                    task.wait(0.3); holdE(1.5)
                    autoSell_Count = autoSell_Count+1
                    if sellCountLbl_ref then sellCountLbl_ref.Text = tostring(autoSell_Count) end
                    task.wait(0.4)
                end
                if sellStatusLbl_ref then sellStatusLbl_ref.Text="RUNNING"; sellStatusLbl_ref.TextColor3=C.accent end
            end
        end
    end
end)

-- ========== BUTTON EVENTS ==========
startBtn.MouseButton1Click:Connect(function()
    if not AutoMS_Running then
        AutoMS_Running = true
        statusValue.Text="STARTING"; statusValue.TextColor3=C.yellow
        task.spawn(autoMSLoop)
    end
end)
stopBtn.MouseButton1Click:Connect(function()
    AutoMS_Running = false
    statusValue.Text="OFF"; statusValue.TextColor3=C.red
    phaseValue.Text="Water"; timerValue.Text="0s"
end)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.PageUp then
        if AutoMS_Running then
            AutoMS_Running=false; statusValue.Text="OFF"; statusValue.TextColor3=C.red
            phaseValue.Text="Water"; timerValue.Text="0s"
        else
            AutoMS_Running=true; statusValue.Text="STARTING"; statusValue.TextColor3=C.yellow
            task.spawn(autoMSLoop)
        end
    end
end)
task.spawn(function() while true do updateInventory(); task.wait(1) end end)

-- ========== ESP LOOP ==========
RunService.Heartbeat:Connect(function(dt)
    if not espEnabled then return end
    _espAccum = _espAccum + dt
    if _espAccum < ESP_INTERVAL then return end
    _espAccum = 0
    local myChar2 = LocalPlayer.Character
    local myHRP2  = myChar2 and myChar2:FindFirstChild("HumanoidRootPart")
    local myPos   = myHRP2 and myHRP2.Position
    for player, drawings in pairs(espCache) do
        local boxOutline,nameLabel,hpBarBg,hpBarFill,distLabel,itemLabel = drawings[1],drawings[2],drawings[3],drawings[4],drawings[5],drawings[6]
        local char = player.Character; local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart"); local head = char and char:FindFirstChild("Head")
        local function hideAll() boxOutline.Visible=false; nameLabel.Visible=false; hpBarBg.Visible=false; hpBarFill.Visible=false; distLabel.Visible=false; if itemLabel then itemLabel.Visible=false end end
        if not (char and root and head and humanoid and humanoid.Health>0 and not isWhitelisted(player)) then hideAll(); continue end
        local dist3D = myPos and (root.Position-myPos).Magnitude or 0
        if myPos and espMaxDist>0 and dist3D>espMaxDist then hideAll(); continue end
        local hrpPos,hrpVis = Camera:WorldToViewportPoint(root.Position)
        local headPos,headVis = Camera:WorldToViewportPoint(head.Position)
        if not (hrpVis and headVis) then hideAll(); continue end
        local height = math.abs(headPos.Y-hrpPos.Y)*1.7+(boxPadding*2)
        local width = height*0.55; local boxX = hrpPos.X-width/2; local boxY = headPos.Y-boxPadding
        boxOutline.Color=espBoxColor; boxOutline.Size=Vector2.new(width,height); boxOutline.Position=Vector2.new(boxX,boxY); boxOutline.Visible=true
        nameLabel.Text=player.Name; nameLabel.Color=espNameColor; nameLabel.Position=Vector2.new(hrpPos.X,boxY-14); nameLabel.Visible=true
        local hpRatio = humanoid.MaxHealth>0 and math.clamp(humanoid.Health/humanoid.MaxHealth,0,1) or 1
        local hpBarW=3; local hpBarX=boxX-hpBarW-2
        hpBarBg.Size=Vector2.new(hpBarW,height); hpBarBg.Position=Vector2.new(hpBarX,boxY); hpBarBg.Visible=true
        local fillHeight=math.max(1,height*hpRatio); local fillY=boxY+(height-fillHeight)
        hpBarFill.Size=Vector2.new(hpBarW,fillHeight); hpBarFill.Position=Vector2.new(hpBarX,fillY)
        hpBarFill.Color = hpRatio>0.6 and Color3.fromRGB(0,255,80) or hpRatio>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50)
        hpBarFill.Visible=true
        if myPos then distLabel.Text=string.format("[%.0fm]",dist3D); distLabel.Position=Vector2.new(hrpPos.X,boxY+height+4); distLabel.Visible=true else distLabel.Visible=false end
        if itemLabel then
            local heldItem = getHeldItem(player)
            if heldItem then itemLabel.Text="["..heldItem.."]"; itemLabel.Color=espItemColor; itemLabel.Position=Vector2.new(hrpPos.X,boxY+height+16); itemLabel.Visible=true
            else itemLabel.Visible=false end
        end
    end
end)

-- ========== AIMBOT CORE ==========
local function getPredictedPosition(part, player)
    local now = tick(); local currentPos = part.Position
    if not velCache[player] then velCache[player]={lastPos=currentPos,lastVel=Vector3.zero,lastTime=now}; return currentPos end
    local cache = velCache[player]; local dt = now-cache.lastTime
    if dt>0 and dt<0.2 then local rawVel=(currentPos-cache.lastPos)/dt; cache.lastVel=cache.lastVel:Lerp(rawVel,0.5)
    elseif dt>=0.2 then cache.lastVel=Vector3.zero end
    cache.lastPos=currentPos; cache.lastTime=now
    if not aimbotPrediction then return currentPos end
    return currentPos + cache.lastVel * predStrength
end
local function getBestTarget()
    local mx,my
    if aimbotMode=="FreeAim" then local mp=UserInputService:GetMouseLocation(); mx,my=mp.X,mp.Y
    else mx=Camera.ViewportSize.X/2; my=Camera.ViewportSize.Y/2 end
    local bestScore=math.huge; local bestPart=nil; local bestPlr=nil
    local myChar=LocalPlayer.Character; local myHRP=myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isWhitelisted(plr) then
            local char=plr.Character
            if char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                local part=char:FindFirstChild(aimbotTarget) or char:FindFirstChild("HumanoidRootPart")
                if part and hum and hum.Health>0 then
                    if aimbotMaxDist>0 and myHRP and (part.Position-myHRP.Position).Magnitude>aimbotMaxDist then continue end
                    local sp,vis=Camera:WorldToViewportPoint(part.Position)
                    if vis then
                        local dScreen=math.sqrt((sp.X-mx)^2+(sp.Y-my)^2)
                        if dScreen<=aimbotFOV then
                            local score = aimbotPriority=="Crosshair" and dScreen or (myHRP and (part.Position-myHRP.Position).Magnitude or dScreen)
                            if score<bestScore then bestScore=score; bestPart=part; bestPlr=plr end
                        end
                    end
                end
            end
        end
    end
    return bestPart, bestPlr
end

local function isAimbotKeyHeld()
    if isBindingKey then return false end
    local t = aimbotKeybindType
    if t=="KeyCode" then return aimbotKeybindCode~=nil and UserInputService:IsKeyDown(aimbotKeybindCode)
    elseif t=="MouseButton" then
        if aimbotKeybind==Enum.UserInputType.MouseButton2 then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif aimbotKeybind==Enum.UserInputType.MouseButton3 then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) end
    elseif t=="MB4" then return mb4Held
    elseif t=="MB5" then return mb5Held end
    return false
end

UserInputService.InputBegan:Connect(function(input)
    if isBindingKey then return end
    local kn=tostring(input.KeyCode):gsub("Enum%.KeyCode%.",""); local un=tostring(input.UserInputType):gsub("Enum%.UserInputType%.","")
    if kn=="MouseButton4" or un=="MouseButton4" then mb4Held=true
    elseif kn=="MouseButton5" or un=="MouseButton5" then mb5Held=true end
end)
UserInputService.InputEnded:Connect(function(input)
    local kn=tostring(input.KeyCode):gsub("Enum%.KeyCode%.",""); local un=tostring(input.UserInputType):gsub("Enum%.UserInputType%.","")
    if kn=="MouseButton4" or un=="MouseButton4" then mb4Held=false
    elseif kn=="MouseButton5" or un=="MouseButton5" then mb5Held=false end
end)

local guiInset = game:GetService("GuiService"):GetGuiInset()
aimbotFovCircle = Drawing.new("Circle")
aimbotFovCircle.Thickness=1; aimbotFovCircle.Color=fovColor; aimbotFovCircle.Filled=false
aimbotFovCircle.Visible=false; aimbotFovCircle.Radius=aimbotFOV
aimbotFovCircle.Position=Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

local _fovPosX=0; local _fovPosY=0; local _fovRadiusCur=250
local _freeAimVelX=0; local _freeAimVelY=0
local mouseMoveMethod=nil
pcall(function() if mousemoverel then mouseMoveMethod="rel" end end)

RunService.RenderStepped:Connect(function(dt)
    local txFov,tyFov
    if aimbotMode=="FreeAim" then local mp=UserInputService:GetMouseLocation(); txFov,tyFov=mp.X,mp.Y
    else txFov=Camera.ViewportSize.X/2; tyFov=Camera.ViewportSize.Y/2 end
    if _fovPosX==0 then _fovPosX=txFov end; if _fovPosY==0 then _fovPosY=tyFov end
    local fovLerp=math.clamp(dt*40,0,1)
    _fovPosX=_fovPosX+(txFov-_fovPosX)*fovLerp; _fovPosY=_fovPosY+(tyFov-_fovPosY)*fovLerp
    _fovRadiusCur=_fovRadiusCur+(aimbotFOV-_fovRadiusCur)*fovLerp
    aimbotFovCircle.Position=Vector2.new(_fovPosX,_fovPosY); aimbotFovCircle.Radius=_fovRadiusCur
    aimbotFovCircle.Color=fovColor; aimbotFovCircle.Visible=aimbotEnabled
    if not aimbotEnabled then _freeAimVelX=0; _freeAimVelY=0; return end
    aimbotActive = isAimbotKeyHeld()
    if not aimbotActive then _freeAimVelX=_freeAimVelX*0.7; _freeAimVelY=_freeAimVelY*0.7; return end
    local target, targetPlr = getBestTarget()
    if not target then return end
    local pos = getPredictedPosition(target, targetPlr)
    if aimbotMode=="FreeAim" then
        local sp,vis=Camera:WorldToViewportPoint(pos); if not vis then return end
        local mp=UserInputService:GetMouseLocation(); local dx=sp.X-mp.X; local dy=sp.Y-mp.Y
        local base=math.clamp(1-(aimbotSmooth/20),0.04,0.95)
        local lerpT=math.clamp(1-(1-base)^(dt/0.016),0.01,1)
        _freeAimVelX=_freeAimVelX+(dx*lerpT-_freeAimVelX)*0.6; _freeAimVelY=_freeAimVelY+(dy*lerpT-_freeAimVelY)*0.6
        if mouseMoveMethod=="rel" then mousemoverel(_freeAimVelX, _freeAimVelY) end
    else
        local cf=Camera.CFrame; local goal=CFrame.new(cf.Position, pos)
        local base=math.clamp(1-(aimbotSmooth/20),0.04,0.95)
        local t=math.clamp(1-(1-base)^(dt/0.016),0.01,1)
        Camera.CFrame=cf:Lerp(goal,t)
    end
end)

print("=== MAJESTY STORE v8.0.0 ===")
print("discord.gg/VPeZbhCz8M")
