-- ========== MAJESTY ONTOP v20.0 - VEHICLE ANCHOR TELEPORT ==========
-- Kendaraan: Anchor → PivotTo → Unanchor (cegah jatuh ke void)
-- Jalan kaki: gerak bertahap 80 studs per 0.08 detik (bypass anti-cheat)

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

-- ========== GUI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY ONTOP"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiParentOk = false
if not guiParentOk then pcall(function() screenGui.Parent = gethui(); guiParentOk = true end) end
if not guiParentOk then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiParentOk = true end) end
if not guiParentOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ===== WARNA TEMA =====
local C = {
    bg       = Color3.fromRGB(18, 18, 18),
    topbar   = Color3.fromRGB(24, 24, 24),
    panel    = Color3.fromRGB(22, 22, 22),
    card     = Color3.fromRGB(30, 30, 30),
    card2    = Color3.fromRGB(26, 26, 26),
    accent   = Color3.fromRGB(220, 38, 38),
    accent2  = Color3.fromRGB(239, 68, 68),
    green    = Color3.fromRGB(34, 197, 94),
    red      = Color3.fromRGB(220, 38, 38),
    yellow   = Color3.fromRGB(234, 179, 8),
    text     = Color3.fromRGB(230, 230, 230),
    subtext  = Color3.fromRGB(120, 120, 120),
    border   = Color3.fromRGB(40, 40, 40),
    search   = Color3.fromRGB(28, 28, 28),
    navbg    = Color3.fromRGB(20, 20, 20),
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
mkCorner(mainFrame, 8)
mkStroke(mainFrame, 1, C.border)

-- ===== TITLE BAR =====
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = C.topbar
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
mkCorner(titleBar, 8)

local tbLine = Instance.new("Frame")
tbLine.Size = UDim2.new(1, 0, 0, 1)
tbLine.Position = UDim2.new(0, 0, 1, -1)
tbLine.BackgroundColor3 = C.border
tbLine.BorderSizePixel = 0
tbLine.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = '<font color="rgb(220,38,38)">Majesty Store</font>  |  <font color="rgb(170,170,170)">https://discord.gg/VPeZbhCz8M</font>'
titleLabel.Font = Enum.Font.Gotham
titleLabel.TextSize = 12
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 50, 1, 0)
versionLabel.Position = UDim2.new(1, -100, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v20.0"
versionLabel.TextColor3 = C.subtext
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 11
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.Position = UDim2.new(1, -50, 0.5, -11)
minBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
minBtn.Text = "−"
minBtn.TextColor3 = C.text
minBtn.Font = Enum.Font.Gotham
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.Parent = titleBar
mkCorner(minBtn, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -24, 0.5, -11)
closeBtn.BackgroundColor3 = C.accent
closeBtn.Text = "×"
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

local searchBar = Instance.new("Frame")
searchBar.Size = UDim2.new(0, 180, 0, 28)
searchBar.Position = UDim2.new(0, 10, 0, 44)
searchBar.BackgroundColor3 = C.search
searchBar.BorderSizePixel = 0
searchBar.Parent = mainFrame
mkCorner(searchBar, 6)
mkStroke(searchBar, 1, C.border)

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.new(0, 20, 1, 0)
searchIcon.Position = UDim2.new(0, 6, 0, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextSize = 11
searchIcon.Font = Enum.Font.Gotham
searchIcon.Parent = searchBar

local searchInput = Instance.new("TextBox")
searchInput.Size = UDim2.new(1, -30, 1, 0)
searchInput.Position = UDim2.new(0, 26, 0, 0)
searchInput.BackgroundTransparency = 1
searchInput.PlaceholderText = "search"
searchInput.PlaceholderColor3 = C.subtext
searchInput.Text = ""
searchInput.TextColor3 = C.text
searchInput.Font = Enum.Font.Gotham
searchInput.TextSize = 12
searchInput.TextXAlignment = Enum.TextXAlignment.Left
searchInput.BorderSizePixel = 0
searchInput.Parent = searchBar

-- ===== CONTENT AREA =====
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, 0, 1, -84)
contentArea.Position = UDim2.new(0, 0, 0, 84)
contentArea.BackgroundColor3 = C.panel
contentArea.BorderSizePixel = 0
contentArea.Parent = mainFrame

-- ===== TAB PAGES =====
local function makePage()
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
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

local pageInv    = makePage()
local pageAuto   = makePage()
local pageEsp    = makePage()
local pageTP     = makePage()
local pageAimbot = makePage()
local pageCredits = makePage()

-- ========== WHITELIST ==========
local whitelist = {}
local wlRefreshFn = nil
local function isWhitelisted(plr)
    return whitelist[plr.Name] == true
end

-- ========== ESP ==========
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

-- ========== TELEPORT VARIABLES ==========
local autoTP_Running = false
local autoTP_Thread  = nil
local savedLocations = {
    {name = "NPC Marshmellow", x = 510.1238,            y = 3.5872,              z = 596.9278,           icon = "🍡"},
    {name = "Gunstore Tier",   x = 1169.678955078125,   y = 3.362133026123047,   z = 139.321533203125,   icon = "🔫"},
    {name = "Dealership",      x = 731.5349731445312,   y = 3.7265229225158669,  z = 409.34637451171875, icon = "🚗"},
    {name = "Gunstore Mid",    x = 218.72975158691406,  y = 3.729841709136963,   z = -156.140625,        icon = "🔫"},
    {name = "Gunstore New",    x = -453.7384948730469,  y = 3.7371323108673096,  z = 343.8177490234375,  icon = "🔫"},
}
local tpStatusValue = nil
local tpLoopValue   = nil

-- ========== FUNGSI TELEPORT v20 - ANCHOR METHOD (VEHICLE SAFE) ==========
-- Kendaraan: Anchor semua part → PivotTo → Unanchor → zero velocity (cegah jatuh ke void)
-- Jalan kaki: gerak bertahap (step) bypass anti-cheat
local function doTeleport(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp      = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end

    -- === Cek apakah sedang di kendaraan ===
    local seatPart = humanoid and humanoid.SeatPart
    if seatPart then
        local vehicleModel = seatPart:FindFirstAncestorOfClass("Model")
        if vehicleModel and vehicleModel.PrimaryPart then

            -- Kumpulkan semua BasePart kendaraan
            local allParts = {}
            for _, p in pairs(vehicleModel:GetDescendants()) do
                if p:IsA("BasePart") then
                    table.insert(allParts, p)
                end
            end

            -- Step 1: Anchor semua part (freeze total, cegah gravitasi)
            for _, p in pairs(allParts) do
                p.Anchored = true
            end
            task.wait(0.05)

            -- Step 2: Zero velocity semua part
            for _, p in pairs(allParts) do
                p.AssemblyLinearVelocity  = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end

            -- Step 3: Pindah ke tujuan
            local offset = vehicleModel:GetPivot():ToObjectSpace(hrp.CFrame)
            vehicleModel:PivotTo(targetCFrame * offset:Inverse())
            task.wait(0.05)

            -- Step 4: Unanchor semua part (physics aktif kembali)
            for _, p in pairs(allParts) do
                p.Anchored = false
            end

            -- Step 5: Zero velocity sekali lagi setelah unanchor
            -- (cegah kendaraan melayang saat physics resume)
            task.wait(0.05)
            for _, p in pairs(allParts) do
                p.AssemblyLinearVelocity  = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end

            return true
        end
    end

    -- === Jalan kaki: teleport BERTAHAP (bypass anti-cheat) ===
    -- Gerak sedikit-sedikit agar server tidak detect lompatan posisi besar
    local startPos  = hrp.Position
    local endPos    = targetCFrame.Position
    local totalDist = (endPos - startPos).Magnitude

    local stepSize  = 80    -- studs per langkah — kurangi ke 50 kalau masih kena
    local stepDelay = 0.08  -- detik antar langkah — naikkan ke 0.1 kalau masih kena

    local steps = math.max(1, math.ceil(totalDist / stepSize))

    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end

    for i = 1, steps do
        -- Batalkan kalau karakter respawn/berubah di tengah jalan
        if LocalPlayer.Character ~= char then break end
        local alpha   = i / steps
        local lerpPos = startPos:Lerp(endPos, alpha)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        -- Pertahankan rotasi target, hanya lerp posisi
        hrp.CFrame = CFrame.new(lerpPos) * (targetCFrame - targetCFrame.Position)
        task.wait(stepDelay)
    end

    -- Pastikan tepat di tujuan setelah loop
    if LocalPlayer.Character == char then
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = targetCFrame
        task.wait(0.1)
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end

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
    lbl.TextSize = 11
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
    mkCorner(f, 6)
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

-- ===== PAGE: AUTO MS =====
do
    sectionTitle(pageAuto, "AUTO MARSHMALLOW", 8)

    local statCard = makeCard(pageAuto, 38, 44)
    makeLabel(statCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    statusValue = makeLabel(statCard, "OFF", 90, 0, 200, 44, 16, C.red, Enum.Font.Gotham)

    local phCard = makeCard(pageAuto, 90, 44)
    makeLabel(phCard, "PHASE", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    phaseValue = makeLabel(phCard, "Water", 90, 0, 200, 44, 16, Color3.fromRGB(56,189,248), Enum.Font.Gotham)

    local tmCard = makeCard(pageAuto, 142, 44)
    makeLabel(tmCard, "TIME", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    timerValue = makeLabel(tmCard, "0s", 90, 0, 200, 44, 16, C.yellow, Enum.Font.Gotham)

    local infoCard = makeCard(pageAuto, 194, 30)
    makeLabel(infoCard, "⏱  Delay 1s antara Sugar → Gelatin", 10, 0, 300, 30, 11, C.subtext, Enum.Font.Gotham)

    startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.47, -10, 0, 38)
    startBtn.Position = UDim2.new(0, 10, 0, 234)
    startBtn.BackgroundColor3 = C.green
    startBtn.Text = "▶  START"
    startBtn.TextColor3 = Color3.fromRGB(255,255,255)
    startBtn.Font = Enum.Font.Gotham
    startBtn.TextSize = 14
    startBtn.BorderSizePixel = 0
    startBtn.Parent = pageAuto
    mkCorner(startBtn, 6)

    stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.47, -10, 0, 38)
    stopBtn.Position = UDim2.new(0.5, 5, 0, 234)
    stopBtn.BackgroundColor3 = C.red
    stopBtn.Text = "■  STOP"
    stopBtn.TextColor3 = Color3.fromRGB(255,255,255)
    stopBtn.Font = Enum.Font.Gotham
    stopBtn.TextSize = 14
    stopBtn.BorderSizePixel = 0
    stopBtn.Parent = pageAuto
    mkCorner(stopBtn, 6)

    makeLabel(pageAuto, "PageUp = toggle start/stop", 10, 282, 300, 20, 10, C.subtext, Enum.Font.Gotham)

    sectionTitle(pageAuto, "INVENTORY TRACKER", 312)

    local invItems = {
        {name="Water",       icon="💧", color=Color3.fromRGB(56,189,248),  countColor=Color3.fromRGB(56,189,248)},
        {name="Gelatin",     icon="🍮", color=Color3.fromRGB(251,146,60),  countColor=Color3.fromRGB(251,146,60)},
        {name="Sugar Block", icon="🧊", color=Color3.fromRGB(192,132,252), countColor=Color3.fromRGB(192,132,252)},
        {name="Empty Bag",   icon="👜", color=Color3.fromRGB(74,222,128),  countColor=Color3.fromRGB(74,222,128)},
    }
    local invCountLabels = {}
    for i, item in ipairs(invItems) do
        local card = makeCard(pageAuto, 340 + (i-1)*54, 44)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0,3,1,-8); bar.Position = UDim2.new(0,4,0,4)
        bar.BackgroundColor3 = item.color; bar.BorderSizePixel = 0; bar.Parent = card
        mkCorner(bar, 3)
        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0,30,0,30); icon.Position = UDim2.new(0,12,0.5,-15)
        icon.BackgroundTransparency = 1; icon.Text = item.icon; icon.TextSize = 20
        icon.Font = Enum.Font.Gotham; icon.Parent = card
        makeLabel(card, item.name, 48, 0, 120, 44, 13, C.text, Enum.Font.Gotham)
        local cnt = makeLabel(card, "0", 0, 0, -12, 44, 20, item.countColor, Enum.Font.Gotham, Enum.TextXAlignment.Right)
        cnt.Size = UDim2.new(1,-12,1,0); cnt.Position = UDim2.new(0,0,0,0)
        invCountLabels[#invCountLabels+1] = cnt
    end
    waterCount   = invCountLabels[1]
    gelatinCount = invCountLabels[2]
    sugarCount   = invCountLabels[3]
    bagCount     = invCountLabels[4]

    sectionTitle(pageAuto, "AUTO SELL MARSHMELLOW", 632)
    local sellToggleBtn = Instance.new("TextButton")
    sellToggleBtn.Name = "SellToggleBtn"
    sellToggleBtn.Size = UDim2.new(1,-20,0,38); sellToggleBtn.Position = UDim2.new(0,10,0,658)
    sellToggleBtn.BackgroundColor3 = Color3.fromRGB(35,20,20)
    sellToggleBtn.Text = "💰  AUTO SELL : OFF"; sellToggleBtn.TextColor3 = C.red
    sellToggleBtn.Font = Enum.Font.Gotham; sellToggleBtn.TextSize = 13
    sellToggleBtn.BorderSizePixel = 0; sellToggleBtn.Parent = pageAuto
    mkCorner(sellToggleBtn, 6); mkStroke(sellToggleBtn, 1, C.red)

    local sellStatCard = makeCard(pageAuto, 706, 44)
    makeLabel(sellStatCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    local sellStatusLbl = makeLabel(sellStatCard, "OFF", 90, 0, 200, 44, 14, C.red, Enum.Font.Gotham)
    local sellCountCard = makeCard(pageAuto, 758, 44)
    makeLabel(sellCountCard, "TERJUAL", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    local sellCountLbl = makeLabel(sellCountCard, "0", 90, 0, 200, 44, 14, C.yellow, Enum.Font.Gotham)
    local msTypeCard = makeCard(pageAuto, 810, 30)
    makeLabel(msTypeCard, "🍡  Small  ·  Medium  ·  Big marshmellow", 10, 0, 400, 30, 10, C.subtext, Enum.Font.Gotham)
    local sellInfoCard = makeCard(pageAuto, 848, 30)
    makeLabel(sellInfoCard, "⌨  Tahan E otomatis 1.5 detik per marshmellow", 10, 0, 400, 30, 10, C.subtext, Enum.Font.Gotham)

    sellStatusLbl_ref = sellStatusLbl
    sellCountLbl_ref  = sellCountLbl
    sellToggleBtn_ref = sellToggleBtn

    sellToggleBtn.MouseButton1Click:Connect(function()
        autoSell_Running = not autoSell_Running
        if autoSell_Running then
            sellToggleBtn.Text = "💰  AUTO SELL : ON"; sellToggleBtn.TextColor3 = C.green
            sellToggleBtn.BackgroundColor3 = Color3.fromRGB(20,35,20); mkStroke(sellToggleBtn,1,C.green)
            sellStatusLbl.Text = "RUNNING"; sellStatusLbl.TextColor3 = C.green
        else
            sellToggleBtn.Text = "💰  AUTO SELL : OFF"; sellToggleBtn.TextColor3 = C.red
            sellToggleBtn.BackgroundColor3 = Color3.fromRGB(35,20,20); mkStroke(sellToggleBtn,1,C.red)
            sellStatusLbl.Text = "OFF"; sellStatusLbl.TextColor3 = C.red
        end
    end)

    sectionTitle(pageAuto, "AUTO BUY BAHAN", 886)
    local buyQty = { water = 1, sugar = 1, gelatin = 1 }
    local function makeQtyRow(yPos, emoji, label, key)
        local card = makeCard(pageAuto, yPos, 44)
        makeLabel(card, emoji.."  "..label, 10, 0, 160, 44, 12, C.text, Enum.Font.Gotham)
        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0,30,0,28); minusBtn.Position = UDim2.new(0,175,0,8)
        minusBtn.Text = "−"; minusBtn.TextSize = 18; minusBtn.Font = Enum.Font.Gotham
        minusBtn.BackgroundColor3 = Color3.fromRGB(60,20,20); minusBtn.TextColor3 = C.red
        minusBtn.BorderSizePixel = 0; minusBtn.Parent = card; mkCorner(minusBtn, 6)
        local qtyLbl = Instance.new("TextLabel")
        qtyLbl.Size = UDim2.new(0,40,0,28); qtyLbl.Position = UDim2.new(0,210,0,8)
        qtyLbl.Text = "1"; qtyLbl.TextSize = 14; qtyLbl.Font = Enum.Font.Gotham
        qtyLbl.BackgroundTransparency = 1; qtyLbl.TextColor3 = Color3.fromRGB(255,255,255)
        qtyLbl.TextXAlignment = Enum.TextXAlignment.Center; qtyLbl.Parent = card
        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0,30,0,28); plusBtn.Position = UDim2.new(0,255,0,8)
        plusBtn.Text = "+"; plusBtn.TextSize = 18; plusBtn.Font = Enum.Font.Gotham
        plusBtn.BackgroundColor3 = Color3.fromRGB(20,50,20); plusBtn.TextColor3 = C.green
        plusBtn.BorderSizePixel = 0; plusBtn.Parent = card; mkCorner(plusBtn, 6)
        minusBtn.MouseButton1Click:Connect(function() buyQty[key] = math.max(1, buyQty[key]-1); qtyLbl.Text = tostring(buyQty[key]) end)
        plusBtn.MouseButton1Click:Connect(function() buyQty[key] = math.min(99, buyQty[key]+1); qtyLbl.Text = tostring(buyQty[key]) end)
    end
    makeQtyRow(912, "💧", "Water",       "water")
    makeQtyRow(962, "🧊", "Sugar Block", "sugar")
    makeQtyRow(1012,"🍮", "Gelatin",     "gelatin")

    local autoBuy_Running = false
    local buyToggleBtn = Instance.new("TextButton")
    buyToggleBtn.Size = UDim2.new(1,-20,0,38); buyToggleBtn.Position = UDim2.new(0,10,0,1066)
    buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,40)
    buyToggleBtn.Text = "🛒  AUTO BUY : OFF"; buyToggleBtn.TextColor3 = Color3.fromRGB(100,140,255)
    buyToggleBtn.Font = Enum.Font.Gotham; buyToggleBtn.TextSize = 13
    buyToggleBtn.BorderSizePixel = 0; buyToggleBtn.Parent = pageAuto
    mkCorner(buyToggleBtn, 6); mkStroke(buyToggleBtn, 1, Color3.fromRGB(80,110,220))

    local buyStatCard = makeCard(pageAuto, 1112, 44)
    makeLabel(buyStatCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    local buyStatusLbl = makeLabel(buyStatCard, "OFF", 90, 0, 300, 44, 14, Color3.fromRGB(150,150,150), Enum.Font.Gotham)
    local buyPhaseCard = makeCard(pageAuto, 1162, 44)
    makeLabel(buyPhaseCard, "BAHAN", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    local buyPhaseLbl = makeLabel(buyPhaseCard, "—", 90, 0, 300, 44, 13, Color3.fromRGB(100,200,255), Enum.Font.Gotham)
    local buyInfoCard = makeCard(pageAuto, 1212, 30)
    makeLabel(buyInfoCard, "⚠  Buka shop NPC manual, lalu klik START", 10, 0, 440, 30, 10, C.yellow, Enum.Font.Gotham)

    buyToggleBtn.MouseButton1Click:Connect(function()
        autoBuy_Running = not autoBuy_Running
        if not autoBuy_Running then
            buyToggleBtn.Text = "🛒  AUTO BUY : OFF"; buyToggleBtn.TextColor3 = Color3.fromRGB(100,140,255)
            buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,40); mkStroke(buyToggleBtn,1,Color3.fromRGB(80,110,220))
            buyStatusLbl.Text = "OFF"; buyStatusLbl.TextColor3 = Color3.fromRGB(150,150,150)
            buyPhaseLbl.Text = "—"; return
        end
        buyToggleBtn.Text = "🛒  AUTO BUY : ON"; buyToggleBtn.TextColor3 = C.green
        buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20,35,20); mkStroke(buyToggleBtn,1,C.green)
        buyStatusLbl.Text = "RUNNING"; buyStatusLbl.TextColor3 = C.green

        task.spawn(function()
            local BAHAN = {
                {label="Water",       toolKw="water",   itemText="Water",           emoji="💧", qtyKey="water"},
                {label="Sugar Block", toolKw="sugar",   itemText="Sugar Block Bag", emoji="🧊", qtyKey="sugar"},
                {label="Gelatin",     toolKw="gelatin", itemText="Gelatin",         emoji="🍮", qtyKey="gelatin"},
            }
            local function clickBtn(btn)
                pcall(function() btn.MouseButton1Down:Fire() end); task.wait(0.05)
                pcall(function() btn.MouseButton1Up:Fire() end); task.wait(0.05)
                pcall(function() btn.MouseButton1Click:Fire() end); task.wait(0.05)
                pcall(function() btn.Activated:Fire() end); task.wait(0.05)
                pcall(function() fireclick(btn) end)
            end
            local function beliDariShop(itemText, jumlah)
                local berhasil = 0
                for i = 1, jumlah do
                    if not autoBuy_Running then break end
                    local shopGui = LocalPlayer.PlayerGui:FindFirstChild("Shop")
                    if not shopGui then break end
                    local main = shopGui:FindFirstChild("Main")
                    local sf   = main and main:FindFirstChild("ScrollingFrame")
                    if not sf then break end
                    local found = false
                    for _, item in pairs(sf:GetChildren()) do
                        if item:IsA("TextButton") and item.Name == "PurchaseableItem" then
                            local lbl = item:FindFirstChild("Item")
                            if lbl and lbl:IsA("TextLabel") and lbl.Text:lower():find(itemText:lower()) then
                                clickBtn(item); task.wait(0.6); found = true; berhasil = berhasil+1; break
                            end
                        end
                    end
                    if not found then break end
                end
                return berhasil
            end
            local function tutupShop()
                local sg = LocalPlayer.PlayerGui:FindFirstChild("Shop")
                if sg then
                    local exit = sg:FindFirstChild("Exit", true)
                    if exit then clickBtn(exit); task.wait(0.5) end
                end
            end
            local shopGui = LocalPlayer.PlayerGui:FindFirstChild("Shop")
            if not shopGui then
                buyStatusLbl.Text = "Buka shop dulu!"; buyStatusLbl.TextColor3 = C.red
                task.wait(2); autoBuy_Running = false
                buyToggleBtn.Text = "🛒  AUTO BUY : OFF"; buyToggleBtn.TextColor3 = Color3.fromRGB(100,140,255)
                buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,40); mkStroke(buyToggleBtn,1,Color3.fromRGB(80,110,220))
                buyStatusLbl.TextColor3 = Color3.fromRGB(150,150,150); buyPhaseLbl.Text = "—"; return
            end
            for _, bahan in ipairs(BAHAN) do
                if not autoBuy_Running then break end
                local qty = buyQty[bahan.qtyKey] or 1
                buyPhaseLbl.Text = bahan.emoji.." "..bahan.label.." x"..qty
                buyStatusLbl.Text = "Membeli..."; buyStatusLbl.TextColor3 = C.yellow
                beliDariShop(bahan.itemText, qty); task.wait(0.3)
            end
            tutupShop(); autoBuy_Running = false
            buyToggleBtn.Text = "🛒  AUTO BUY : OFF"; buyToggleBtn.TextColor3 = Color3.fromRGB(100,140,255)
            buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,40); mkStroke(buyToggleBtn,1,Color3.fromRGB(80,110,220))
            buyPhaseLbl.Text = "—"; buyStatusLbl.Text = "SELESAI ✓"; buyStatusLbl.TextColor3 = C.green
        end)
    end)

    pageAuto.CanvasSize = UDim2.new(0, 0, 0, 1400)
end

-- ===== PAGE: ESP + WHITELIST =====
do
    sectionTitle(pageEsp, "GENERAL / ESP", 8)

    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(1,-20,0,36); espToggleBtn.Position = UDim2.new(0,10,0,32)
    espToggleBtn.BackgroundColor3 = Color3.fromRGB(35,20,20)
    espToggleBtn.Text = "●  ESP  OFF"; espToggleBtn.TextColor3 = C.red
    espToggleBtn.Font = Enum.Font.Gotham; espToggleBtn.TextSize = 13
    espToggleBtn.BorderSizePixel = 0; espToggleBtn.Parent = pageEsp
    mkCorner(espToggleBtn, 6); mkStroke(espToggleBtn, 1, C.red)

    espToggleBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
            espToggleBtn.Text = "●  ESP  ON"; espToggleBtn.TextColor3 = C.green; mkStroke(espToggleBtn,1,C.green)
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        else
            espToggleBtn.Text = "●  ESP  OFF"; espToggleBtn.TextColor3 = C.red; mkStroke(espToggleBtn,1,C.red)
            for plr, _ in pairs(espCache) do removeESP(plr) end
        end
    end)

    local espInfoRow = makeCard(pageEsp, 76, 26)
    local espInfoLbl = Instance.new("TextLabel")
    espInfoLbl.Size = UDim2.new(1,-12,1,0); espInfoLbl.Position = UDim2.new(0,10,0,0)
    espInfoLbl.BackgroundTransparency = 1
    espInfoLbl.Text = "Box  .  Username  .  HP Bar  .  Item Held  .  Distance"
    espInfoLbl.TextColor3 = C.subtext; espInfoLbl.Font = Enum.Font.Gotham; espInfoLbl.TextSize = 10
    espInfoLbl.TextXAlignment = Enum.TextXAlignment.Left; espInfoLbl.Parent = espInfoRow

    local CP = {Color3.fromRGB(255,50,50),Color3.fromRGB(255,255,255),Color3.fromRGB(0,210,255),Color3.fromRGB(34,197,94),Color3.fromRGB(234,179,8),Color3.fromRGB(168,85,247)}
    local swW = 1 / #CP
    local function mkEspSwatchRow(parent, yPos, label, onPick)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-20,0,13); lbl.Position = UDim2.new(0,10,0,yPos)
        lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = C.subtext
        lbl.Font = Enum.Font.Gotham; lbl.TextSize = 9; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
        local sf = Instance.new("Frame")
        sf.Size = UDim2.new(1,-20,0,20); sf.Position = UDim2.new(0,10,0,yPos+14)
        sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.Parent = parent
        for ci, col in ipairs(CP) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(swW,-3,1,0); sw.Position = UDim2.new(swW*(ci-1),0,0,0)
            sw.BackgroundColor3 = col; sw.Text = ""; sw.BorderSizePixel = 0; sw.Parent = sf; mkCorner(sw,4)
            local capC = col
            sw.MouseButton1Click:Connect(function()
                onPick(capC)
                for _, s in pairs(sf:GetChildren()) do if s:IsA("TextButton") then s.BorderSizePixel = 0 end end
                sw.BorderSizePixel = 2
            end)
        end
    end
    mkEspSwatchRow(pageEsp, 110, "Warna ESP Box",     function(c) espBoxColor  = c end)
    mkEspSwatchRow(pageEsp, 146, "Warna Nama Player", function(c) espNameColor = c end)
    mkEspSwatchRow(pageEsp, 182, "Warna Item Held",   function(c) espItemColor = c end)

    local WO = 170
    sectionTitle(pageEsp, "WHITELIST", 112 + WO)

    local wlCountBadge = Instance.new("TextLabel")
    wlCountBadge.Size = UDim2.new(0,24,0,14); wlCountBadge.Position = UDim2.new(0,104,0,115+WO)
    wlCountBadge.BackgroundColor3 = C.accent; wlCountBadge.Text = "0"
    wlCountBadge.TextColor3 = Color3.fromRGB(255,255,255); wlCountBadge.Font = Enum.Font.Gotham
    wlCountBadge.TextSize = 9; wlCountBadge.BorderSizePixel = 0; wlCountBadge.Parent = pageEsp; mkCorner(wlCountBadge,7)

    local wlActiveScroll = Instance.new("ScrollingFrame")
    wlActiveScroll.Size = UDim2.new(1,-20,0,90); wlActiveScroll.Position = UDim2.new(0,10,0,134+WO)
    wlActiveScroll.BackgroundColor3 = C.card; wlActiveScroll.BorderSizePixel = 0
    wlActiveScroll.ScrollBarThickness = 2; wlActiveScroll.ScrollBarImageColor3 = C.accent
    wlActiveScroll.CanvasSize = UDim2.new(0,0,0,0); wlActiveScroll.Parent = pageEsp
    mkCorner(wlActiveScroll,6); mkStroke(wlActiveScroll,1,C.border)
    local wlActiveLayout = Instance.new("UIListLayout"); wlActiveLayout.Padding = UDim.new(0,2); wlActiveLayout.Parent = wlActiveScroll
    local wlPad = Instance.new("UIPadding"); wlPad.PaddingTop=UDim.new(0,3); wlPad.PaddingLeft=UDim.new(0,3); wlPad.PaddingRight=UDim.new(0,3); wlPad.Parent=wlActiveScroll

    local wlEmptyLbl = Instance.new("TextLabel")
    wlEmptyLbl.Size = UDim2.new(1,0,0,26); wlEmptyLbl.BackgroundTransparency = 1
    wlEmptyLbl.Text = "— Belum ada player di whitelist —"; wlEmptyLbl.TextColor3 = C.subtext
    wlEmptyLbl.Font = Enum.Font.Gotham; wlEmptyLbl.TextSize = 10; wlEmptyLbl.Parent = wlActiveScroll

    local function refreshActiveList()
        for _, ch in pairs(wlActiveScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local count = 0
        for name, _ in pairs(whitelist) do
            count = count + 1
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,0,0,24); row.BackgroundColor3 = Color3.fromRGB(26,26,26); row.BorderSizePixel = 0; row.Parent = wlActiveScroll; mkCorner(row,4)
            local nLbl = Instance.new("TextLabel")
            nLbl.Size = UDim2.new(1,-78,1,0); nLbl.Position = UDim2.new(0,26,0,0)
            nLbl.BackgroundTransparency = 1; nLbl.Text = name; nLbl.TextColor3 = Color3.fromRGB(100,220,255)
            nLbl.Font = Enum.Font.Gotham; nLbl.TextSize = 11; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Parent = row
            local remBtn = Instance.new("TextButton")
            remBtn.Size = UDim2.new(0,52,0,18); remBtn.Position = UDim2.new(1,-56,0.5,-9)
            remBtn.BackgroundColor3 = Color3.fromRGB(130,18,18); remBtn.Text = "✕ Remove"
            remBtn.TextColor3 = Color3.fromRGB(255,255,255); remBtn.Font = Enum.Font.Gotham; remBtn.TextSize = 8
            remBtn.BorderSizePixel = 0; remBtn.Parent = row; mkCorner(remBtn,4)
            local capName = name
            remBtn.MouseButton1Click:Connect(function() whitelist[capName]=nil; refreshActiveList() end)
        end
        wlEmptyLbl.Visible = (count == 0)
        wlCountBadge.Text = tostring(count)
        wlActiveScroll.CanvasSize = UDim2.new(0,0,0,count*26+6)
    end
    wlRefreshFn = refreshActiveList
    refreshActiveList()

    local wlRefreshBtn = Instance.new("TextButton")
    wlRefreshBtn.Size = UDim2.new(1,-20,0,28); wlRefreshBtn.Position = UDim2.new(0,10,0,228+WO)
    wlRefreshBtn.BackgroundColor3 = C.card; wlRefreshBtn.Text = "🔄  Refresh — Cek Player Baru"
    wlRefreshBtn.TextColor3 = C.text; wlRefreshBtn.Font = Enum.Font.Gotham; wlRefreshBtn.TextSize = 11
    wlRefreshBtn.BorderSizePixel = 0; wlRefreshBtn.Parent = pageEsp; mkCorner(wlRefreshBtn,6); mkStroke(wlRefreshBtn,1,C.border)

    sectionTitle(pageEsp, "TAMBAH DARI SERVER", 264+WO)
    local serverScroll = Instance.new("ScrollingFrame")
    serverScroll.Size = UDim2.new(1,-20,0,120); serverScroll.Position = UDim2.new(0,10,0,288+WO)
    serverScroll.BackgroundColor3 = C.card; serverScroll.BorderSizePixel = 0
    serverScroll.ScrollBarThickness = 2; serverScroll.ScrollBarImageColor3 = C.accent
    serverScroll.CanvasSize = UDim2.new(0,0,0,0); serverScroll.Parent = pageEsp
    mkCorner(serverScroll,6); mkStroke(serverScroll,1,C.border)
    local serverLayout = Instance.new("UIListLayout"); serverLayout.Padding = UDim.new(0,2); serverLayout.Parent = serverScroll
    local sPad = Instance.new("UIPadding"); sPad.PaddingTop=UDim.new(0,3); sPad.PaddingLeft=UDim.new(0,3); sPad.PaddingRight=UDim.new(0,3); sPad.Parent=serverScroll

    local function refreshServerList()
        for _, ch in pairs(serverScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local count = 0
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                count = count + 1
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1,0,0,26); row.BackgroundColor3 = Color3.fromRGB(26,26,26); row.BorderSizePixel = 0; row.Parent = serverScroll; mkCorner(row,4)
                local pLbl = Instance.new("TextLabel")
                pLbl.Size = UDim2.new(1,-84,1,0); pLbl.Position = UDim2.new(0,26,0,0)
                pLbl.BackgroundTransparency = 1; pLbl.Text = plr.Name
                pLbl.TextColor3 = whitelist[plr.Name] and Color3.fromRGB(100,220,255) or C.text
                pLbl.Font = Enum.Font.Gotham; pLbl.TextSize = 11; pLbl.TextXAlignment = Enum.TextXAlignment.Left; pLbl.Parent = row
                local addBtn = Instance.new("TextButton")
                addBtn.Size = UDim2.new(0,62,0,18); addBtn.Position = UDim2.new(1,-66,0.5,-9)
                addBtn.BorderSizePixel = 0; addBtn.Font = Enum.Font.Gotham; addBtn.TextSize = 9; addBtn.Parent = row; mkCorner(addBtn,4)
                local function syncBtn()
                    if whitelist[plr.Name] then
                        addBtn.Text = "✓ Listed"; addBtn.BackgroundColor3 = Color3.fromRGB(18,70,18); addBtn.TextColor3 = Color3.fromRGB(100,255,100)
                    else
                        addBtn.Text = "+ Whitelist"; addBtn.BackgroundColor3 = Color3.fromRGB(18,50,110); addBtn.TextColor3 = Color3.fromRGB(180,220,255)
                    end
                end
                syncBtn()
                addBtn.MouseButton1Click:Connect(function()
                    whitelist[plr.Name] = whitelist[plr.Name] ~= true and true or nil
                    syncBtn(); pLbl.TextColor3 = whitelist[plr.Name] and Color3.fromRGB(100,220,255) or C.text
                    refreshActiveList()
                end)
            end
        end
        serverScroll.CanvasSize = UDim2.new(0,0,0,count*28+6)
    end
    refreshServerList()
    wlRefreshBtn.MouseButton1Click:Connect(refreshServerList)
    Players.PlayerAdded:Connect(function() refreshServerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshServerList() end)

    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0.5,-14,0,30); refBtn.Position = UDim2.new(0,10,0,416+WO)
    refBtn.BackgroundColor3 = C.card; refBtn.Text = "🔄 Refresh"; refBtn.TextColor3 = C.text
    refBtn.Font = Enum.Font.Gotham; refBtn.TextSize = 11; refBtn.BorderSizePixel = 0; refBtn.Parent = pageEsp
    mkCorner(refBtn,6); mkStroke(refBtn,1,C.border); refBtn.MouseButton1Click:Connect(refreshServerList)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.5,-14,0,30); clearBtn.Position = UDim2.new(0.5,4,0,416+WO)
    clearBtn.BackgroundColor3 = Color3.fromRGB(50,10,10); clearBtn.Text = "🗑 Clear All"; clearBtn.TextColor3 = C.accent2
    clearBtn.Font = Enum.Font.Gotham; clearBtn.TextSize = 11; clearBtn.BorderSizePixel = 0; clearBtn.Parent = pageEsp
    mkCorner(clearBtn,6); mkStroke(clearBtn,1,C.accent)
    clearBtn.MouseButton1Click:Connect(function() whitelist={}; refreshActiveList(); refreshServerList() end)

    -- VEHICLE FLY
    local VFO = 456 + WO + 16
    sectionTitle(pageEsp, "✈  VEHICLE FLY", VFO)
    local vFlyToggleBtn = Instance.new("TextButton")
    vFlyToggleBtn.Size = UDim2.new(1,-20,0,36); vFlyToggleBtn.Position = UDim2.new(0,10,0,VFO+26)
    vFlyToggleBtn.BackgroundColor3 = Color3.fromRGB(35,20,20); vFlyToggleBtn.Text = "✈  VEHICLE FLY : OFF"
    vFlyToggleBtn.TextColor3 = C.red; vFlyToggleBtn.Font = Enum.Font.Gotham; vFlyToggleBtn.TextSize = 13
    vFlyToggleBtn.BorderSizePixel = 0; vFlyToggleBtn.Parent = pageEsp; mkCorner(vFlyToggleBtn,6); mkStroke(vFlyToggleBtn,1,C.red)
    local vFlyStatCard = makeCard(pageEsp, VFO+70, 36)
    makeLabel(vFlyStatCard, "STATUS", 12, 0, 80, 36, 10, C.subtext, Enum.Font.Gotham)
    local vFlyStatLbl = makeLabel(vFlyStatCard, "Tidak di kendaraan", 90, 0, 260, 36, 11, C.subtext, Enum.Font.Gotham)
    local vFlySpeedCard = makeCard(pageEsp, VFO+114, 44)
    makeLabel(vFlySpeedCard, "Kecepatan Terbang", 12, 2, 200, 20, 11, C.text, Enum.Font.Gotham)
    local vFlySpeedValLbl = makeLabel(vFlySpeedCard, tostring(vFlySpeed), 0, 2, -12, 20, 11, C.accent2, Enum.Font.Gotham, Enum.TextXAlignment.Right)
    vFlySpeedValLbl.Size = UDim2.new(1,-12,0,20)
    local vFlyTrack = Instance.new("Frame")
    vFlyTrack.Size = UDim2.new(1,-20,0,3); vFlyTrack.Position = UDim2.new(0,10,0,32)
    vFlyTrack.BackgroundColor3 = C.border; vFlyTrack.BorderSizePixel = 0; vFlyTrack.Parent = vFlySpeedCard; mkCorner(vFlyTrack,2)
    local vFlyFill = Instance.new("Frame")
    local spRatio0 = (vFlySpeed-10)/(300-10)
    vFlyFill.Size = UDim2.new(spRatio0,0,1,0); vFlyFill.BackgroundColor3 = C.accent; vFlyFill.BorderSizePixel = 0; vFlyFill.Parent = vFlyTrack; mkCorner(vFlyFill,2)
    local vFlyKnob = Instance.new("TextButton")
    vFlyKnob.Size = UDim2.new(0,10,0,10); vFlyKnob.Position = UDim2.new(spRatio0,-5,0.5,-5)
    vFlyKnob.BackgroundColor3 = Color3.fromRGB(255,255,255); vFlyKnob.Text = ""; vFlyKnob.BorderSizePixel = 0; vFlyKnob.Parent = vFlyTrack; mkCorner(vFlyKnob,5)
    local vFlyDragging = false
    vFlyKnob.MouseButton1Down:Connect(function() vFlyDragging = true end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then vFlyDragging=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if vFlyDragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local ap=vFlyTrack.AbsolutePosition; local as=vFlyTrack.AbsoluteSize
            local r=math.clamp((i.Position.X-ap.X)/as.X,0,1)
            vFlySpeed=math.floor(10+r*(300-10)); vFlyFill.Size=UDim2.new(r,0,1,0); vFlyKnob.Position=UDim2.new(r,-5,0.5,-5)
            vFlySpeedValLbl.Text=tostring(vFlySpeed)
        end
    end)
    local vFlyInfoCard = makeCard(pageEsp, VFO+166, 52)
    makeLabel(vFlyInfoCard, "Kontrol saat Vehicle Fly aktif:", 12, 4, 340, 16, 10, C.subtext, Enum.Font.Gotham)
    makeLabel(vFlyInfoCard, "E = Naik   |   Q = Turun   |   WASD = Steer", 12, 20, 380, 16, 10, C.subtext, Enum.Font.Gotham)
    makeLabel(vFlyInfoCard, "Steer otomatis mengikuti arah kamera", 12, 36, 340, 16, 10, Color3.fromRGB(100,180,100), Enum.Font.Gotham)

    local function getVehicleSeat()
        local char = LocalPlayer.Character; if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then return hum.SeatPart end; return nil
    end
    local function getVehicleModel(seat)
        if not seat then return nil end
        return seat:FindFirstAncestorOfClass("Model") or seat
    end
    local function getVehicleRoot(seat)
        if not seat then return nil end
        local model = seat:FindFirstAncestorOfClass("Model")
        if model then
            if model.PrimaryPart then return model.PrimaryPart end
            local biggest, bigSize = nil, 0
            for _, p in pairs(model:GetDescendants()) do
                if p:IsA("BasePart") and p~=seat then
                    local vol=p.Size.X*p.Size.Y*p.Size.Z
                    if vol>bigSize then bigSize=vol; biggest=p end
                end
            end
            return biggest or seat
        end; return seat
    end
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not vFlyEnabled then return end; if gpe then return end
        if input.KeyCode==Enum.KeyCode.E then vFlyUp=true end
        if input.KeyCode==Enum.KeyCode.Q then vFlyDown=true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode==Enum.KeyCode.E then vFlyUp=false end
        if input.KeyCode==Enum.KeyCode.Q then vFlyDown=false end
    end)
    local function startVehicleFly()
        if vFlyConn then vFlyConn:Disconnect(); vFlyConn=nil end
        vFlyConn = RunService.RenderStepped:Connect(function(dt)
            local seat=getVehicleSeat(); local root=getVehicleRoot(seat); local model=getVehicleModel(seat)
            if not(seat and root and model) then vFlyStatLbl.Text="Tidak di kendaraan"; vFlyStatLbl.TextColor3=C.subtext; return end
            vFlyStatLbl.Text="Terbang aktif ✓"; vFlyStatLbl.TextColor3=C.green
            local camCF=Camera.CFrame
            local forward=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z)
            if forward.Magnitude>0.01 then forward=forward.Unit else forward=Vector3.new(0,0,-1) end
            local right=Vector3.new(camCF.RightVector.X,0,camCF.RightVector.Z)
            if right.Magnitude>0.01 then right=right.Unit else right=Vector3.new(1,0,0) end
            local moveVec=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec=moveVec+forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec=moveVec-forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec=moveVec-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec=moveVec+right end
            if vFlyUp then moveVec=moveVec+Vector3.new(0,1,0) end
            if vFlyDown then moveVec=moveVec-Vector3.new(0,1,0) end
            pcall(function()
                for _, p in pairs(model:GetDescendants()) do
                    if p:IsA("BasePart") then p.AssemblyLinearVelocity=Vector3.zero; p.AssemblyAngularVelocity=Vector3.zero end
                end
            end)
            if moveVec.Magnitude>0 then
                moveVec=moveVec.Unit
                local newPos=root.Position+moveVec*vFlySpeed*dt
                local lookDir=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z)
                if lookDir.Magnitude>0.01 then lookDir=lookDir.Unit else lookDir=forward end
                pcall(function()
                    local currentPivot=model:GetPivot()
                    local targetCF=CFrame.new(newPos,newPos+lookDir)
                    local offset=currentPivot:ToObjectSpace(root.CFrame)
                    model:PivotTo(targetCF*offset:Inverse())
                end)
            end
        end)
    end
    local function stopVehicleFly()
        if vFlyConn then vFlyConn:Disconnect(); vFlyConn=nil end
        vFlyUp=false; vFlyDown=false; vFlyStatLbl.Text="Tidak di kendaraan"; vFlyStatLbl.TextColor3=C.subtext
    end
    vFlyToggleBtn.MouseButton1Click:Connect(function()
        vFlyEnabled = not vFlyEnabled
        if vFlyEnabled then
            vFlyToggleBtn.Text="✈  VEHICLE FLY : ON"; vFlyToggleBtn.TextColor3=C.green
            vFlyToggleBtn.BackgroundColor3=Color3.fromRGB(20,35,20); mkStroke(vFlyToggleBtn,1,C.green); startVehicleFly()
        else
            vFlyToggleBtn.Text="✈  VEHICLE FLY : OFF"; vFlyToggleBtn.TextColor3=C.red
            vFlyToggleBtn.BackgroundColor3=Color3.fromRGB(35,20,20); mkStroke(vFlyToggleBtn,1,C.red); stopVehicleFly()
        end
    end)
    pageEsp.CanvasSize = UDim2.new(0,0,0,VFO+280)
end

-- ===== PAGE: TELEPORT (BARU - STEP BYPASS) =====
do
    sectionTitle(pageTP, "🚀 AUTO TELEPORT", 8)

    local tpStatCard = makeCard(pageTP, 38, 44)
    makeLabel(tpStatCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    tpStatusValue = makeLabel(tpStatCard, "STANDBY", 90, 0, 200, 44, 16, C.yellow, Enum.Font.Gotham)

    local tpLoopCard = makeCard(pageTP, 90, 44)
    makeLabel(tpLoopCard, "MODE", 12, 0, 80, 44, 11, C.subtext, Enum.Font.Gotham)
    tpLoopValue = makeLabel(tpLoopCard, "ONCE", 90, 0, 200, 44, 14, C.accent, Enum.Font.Gotham)

    -- Info method teleport
    local tpInfoCard = makeCard(pageTP, 142, 44)
    makeLabel(tpInfoCard, "⚡ Step Teleport", 10, 4, 200, 18, 12, C.accent2, Enum.Font.Gotham)
    makeLabel(tpInfoCard, "Gerak bertahap 80 studs/step  ·  Bypass anti-cheat", 10, 24, 380, 16, 10, C.subtext, Enum.Font.Gotham)

    sectionTitle(pageTP, "PILIH LOKASI", 198)

    for i, loc in ipairs(savedLocations) do
        local locBtn = Instance.new("TextButton")
        locBtn.Size = UDim2.new(1,-20,0,40); locBtn.Position = UDim2.new(0,10,0,222+(i-1)*48)
        locBtn.BackgroundColor3 = C.card; locBtn.Text = loc.icon.."  "..loc.name
        locBtn.TextColor3 = C.text; locBtn.Font = Enum.Font.Gotham; locBtn.TextSize = 13
        locBtn.TextXAlignment = Enum.TextXAlignment.Left; locBtn.BorderSizePixel = 0; locBtn.Parent = pageTP
        mkCorner(locBtn,6); mkStroke(locBtn,1,C.accent)
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0,12); pad.Parent = locBtn
        local ci = i
        locBtn.MouseButton1Click:Connect(function()
            local l = savedLocations[ci]
            tpStatusValue.Text = "TELEPORTING..."; tpStatusValue.TextColor3 = C.yellow
            task.spawn(function()
                doTeleport(CFrame.new(l.x, l.y+3, l.z))
                tpStatusValue.Text = "ARRIVED ✓"; tpStatusValue.TextColor3 = C.green
                task.wait(2); tpStatusValue.Text = "STANDBY"; tpStatusValue.TextColor3 = C.yellow
            end)
        end)
        locBtn.MouseEnter:Connect(function() locBtn.BackgroundColor3 = Color3.fromRGB(40,40,60) end)
        locBtn.MouseLeave:Connect(function() locBtn.BackgroundColor3 = C.card end)
    end

    sectionTitle(pageTP, "AUTO LOOP TELEPORT", 474)
    local loopToggle = Instance.new("TextButton")
    loopToggle.Size = UDim2.new(1,-20,0,38); loopToggle.Position = UDim2.new(0,10,0,500)
    loopToggle.BackgroundColor3 = Color3.fromRGB(35,20,20); loopToggle.Text = "🔁  AUTO LOOP : OFF"
    loopToggle.TextColor3 = C.red; loopToggle.Font = Enum.Font.Gotham; loopToggle.TextSize = 13
    loopToggle.BorderSizePixel = 0; loopToggle.Parent = pageTP; mkCorner(loopToggle,6); mkStroke(loopToggle,1,C.red)

    local intervalCard = makeCard(pageTP, 546, 30)
    makeLabel(intervalCard, "⏱  Interval teleport: setiap 30 detik", 10, 0, 300, 30, 11, C.subtext, Enum.Font.Gotham)

    sectionTitle(pageTP, "TELEPORT KE PLAYER", 588)
    local playerListFrame = Instance.new("ScrollingFrame")
    playerListFrame.Size = UDim2.new(1,-20,0,100); playerListFrame.Position = UDim2.new(0,10,0,612)
    playerListFrame.BackgroundColor3 = C.card; playerListFrame.BorderSizePixel = 0
    playerListFrame.ScrollBarThickness = 3; playerListFrame.ScrollBarImageColor3 = C.accent
    playerListFrame.CanvasSize = UDim2.new(0,0,0,0); playerListFrame.Parent = pageTP
    mkCorner(playerListFrame,6); mkStroke(playerListFrame,1,C.border)
    Instance.new("UIListLayout", playerListFrame).Padding = UDim.new(0,4)

    local function refreshPlayerList()
        for _, ch in pairs(playerListFrame:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        local count = 0
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local pb = Instance.new("TextButton")
                pb.Size = UDim2.new(1,-8,0,28); pb.BackgroundColor3 = Color3.fromRGB(28,28,28)
                pb.Text = "👤  "..plr.Name; pb.TextColor3 = C.text; pb.Font = Enum.Font.Gotham; pb.TextSize = 11
                pb.TextXAlignment = Enum.TextXAlignment.Left; pb.BorderSizePixel = 0; pb.Parent = playerListFrame; mkCorner(pb,4)
                local pad2 = Instance.new("UIPadding"); pad2.PaddingLeft = UDim.new(0,8); pad2.Parent = pb
                pb.MouseButton1Click:Connect(function()
                    local tgt = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if tgt then
                        tpStatusValue.Text = "TP → "..plr.Name; tpStatusValue.TextColor3 = C.yellow
                        task.spawn(function()
                            doTeleport(tgt.CFrame + Vector3.new(2,0,0))
                            tpStatusValue.Text = "ARRIVED ✓"; tpStatusValue.TextColor3 = C.green
                            task.wait(2); tpStatusValue.Text = "STANDBY"; tpStatusValue.TextColor3 = C.yellow
                        end)
                    end
                end)
                count = count + 1
            end
        end
        playerListFrame.CanvasSize = UDim2.new(0,0,0,count*32)
    end

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1,-20,0,34); refreshBtn.Position = UDim2.new(0,10,0,720)
    refreshBtn.BackgroundColor3 = C.card; refreshBtn.Text = "🔄  Refresh Daftar Player"
    refreshBtn.TextColor3 = C.text; refreshBtn.Font = Enum.Font.Gotham; refreshBtn.TextSize = 12
    refreshBtn.BorderSizePixel = 0; refreshBtn.Parent = pageTP; mkCorner(refreshBtn,6); mkStroke(refreshBtn,1,C.border)
    refreshBtn.MouseButton1Click:Connect(function()
        refreshBtn.Text = "⏳  Refreshing..."; refreshBtn.TextColor3 = C.yellow
        refreshPlayerList(); task.wait(0.3)
        refreshBtn.Text = "🔄  Refresh Daftar Player"; refreshBtn.TextColor3 = C.text
    end)
    refreshPlayerList()
    Players.PlayerAdded:Connect(function() task.wait(0.5); refreshPlayerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshPlayerList() end)

    loopToggle.MouseButton1Click:Connect(function()
        autoTP_Running = not autoTP_Running
        if autoTP_Running then
            loopToggle.Text = "🔁  AUTO LOOP : ON"; loopToggle.TextColor3 = C.green
            loopToggle.BackgroundColor3 = Color3.fromRGB(20,35,20); mkStroke(loopToggle,1,C.green)
            tpLoopValue.Text = "LOOPING"; tpLoopValue.TextColor3 = C.green
            autoTP_Thread = task.spawn(function()
                while autoTP_Running do
                    tpStatusValue.Text = "TELEPORTING"; tpStatusValue.TextColor3 = C.yellow
                    doTeleport(CFrame.new(510.1238, 6.5872, 596.9278))
                    tpStatusValue.Text = "ARRIVED ✓"; tpStatusValue.TextColor3 = C.green
                    for i = 30, 1, -1 do
                        if not autoTP_Running then break end
                        tpLoopValue.Text = "Next: "..i.."s"; task.wait(1)
                    end
                end
                tpLoopValue.Text = "ONCE"; tpLoopValue.TextColor3 = C.accent
            end)
        else
            autoTP_Running = false
            loopToggle.Text = "🔁  AUTO LOOP : OFF"; loopToggle.TextColor3 = C.red
            loopToggle.BackgroundColor3 = Color3.fromRGB(35,20,20); mkStroke(loopToggle,1,C.red)
            tpLoopValue.Text = "ONCE"; tpLoopValue.TextColor3 = C.accent
            tpStatusValue.Text = "STANDBY"; tpStatusValue.TextColor3 = C.yellow
        end
    end)

    pageTP.CanvasSize = UDim2.new(0,0,0,820)
end

-- ===== BOTTOM NAV =====
local tabDefs = {
    {icon="⚙️", label="Auto MS",  page=pageAuto},
    {icon="👁",  label="General",  page=pageEsp},
    {icon="🚀", label="Teleport", page=pageTP},
    {icon="🎯", label="Aimbot",   page=pageAimbot},
    {icon="⭐", label="Credits",  page=pageCredits},
}
local tabBtns = {}
local bottomNav = Instance.new("Frame")
bottomNav.Size = UDim2.new(1,0,0,44); bottomNav.Position = UDim2.new(0,0,1,-44)
bottomNav.BackgroundColor3 = C.navbg; bottomNav.BorderSizePixel = 0; bottomNav.Parent = mainFrame
mkStroke(bottomNav,1,C.border)
local navLine = Instance.new("Frame")
navLine.Size = UDim2.new(1,0,0,1); navLine.BackgroundColor3 = C.border; navLine.BorderSizePixel = 0; navLine.Parent = bottomNav

local function setTab(idx)
    for i, tb in ipairs(tabBtns) do
        local isActive = (i==idx)
        tb.TextColor3 = isActive and C.accent2 or C.subtext
        local ind = tb:FindFirstChild("indicator"); if ind then ind.Visible = isActive end
    end
    for _, td in ipairs(tabDefs) do td.page.Visible = false end
    tabDefs[idx].page.Visible = true
end
local navW = 1 / #tabDefs
for i, td in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(navW,0,1,0); btn.Position = UDim2.new(navW*(i-1),0,0,0)
    btn.BackgroundTransparency = 1; btn.Text = td.icon.."  "..td.label; btn.TextColor3 = C.subtext
    btn.Font = Enum.Font.Gotham; btn.TextSize = 12; btn.BorderSizePixel = 0; btn.Parent = bottomNav
    local ind = Instance.new("Frame"); ind.Name = "indicator"
    ind.Size = UDim2.new(0.7,0,0,2); ind.Position = UDim2.new(0.15,0,0,0)
    ind.BackgroundColor3 = C.accent; ind.BorderSizePixel = 0; ind.Visible = false; ind.Parent = btn; mkCorner(ind,2)
    tabBtns[i] = btn
    local ci = i; btn.MouseButton1Click:Connect(function() setTab(ci) end)
end

local playerInfoLbl = Instance.new("TextLabel")
playerInfoLbl.Size = UDim2.new(0,200,0,28); playerInfoLbl.Position = UDim2.new(0,200,0,44)
playerInfoLbl.BackgroundTransparency = 1; playerInfoLbl.Text = "👤  "..LocalPlayer.Name
playerInfoLbl.TextColor3 = C.subtext; playerInfoLbl.Font = Enum.Font.Gotham; playerInfoLbl.TextSize = 11
playerInfoLbl.TextXAlignment = Enum.TextXAlignment.Left; playerInfoLbl.Parent = mainFrame

setTab(1)

-- ========== INVENTORY TRACKER ==========
local function updateInventory()
    pcall(function()
        local water,gelatin,sugar,bag = 0,0,0,0
        local function checkParent(parent)
            if not parent then return end
            for _, tool in pairs(parent:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = string.lower(tool.Name)
                    if name:find("water") then water=water+1
                    elseif name:find("gelatin") or name:find("gel") then gelatin=gelatin+1
                    elseif name:find("sugar") or name:find("gula") or name:find("block") then sugar=sugar+1
                    elseif name:find("bag") or name:find("tas") or name:find("empty") then bag=bag+1
                    end
                end
            end
        end
        checkParent(LocalPlayer:FindFirstChild("Backpack")); checkParent(LocalPlayer.Character)
        waterCount.Text=tostring(water); gelatinCount.Text=tostring(gelatin)
        sugarCount.Text=tostring(sugar); bagCount.Text=tostring(bag)
        waterCount.TextColor3   = water>0   and Color3.fromRGB(56,189,248)  or Color3.fromRGB(150,150,150)
        gelatinCount.TextColor3 = gelatin>0 and Color3.fromRGB(251,146,60)  or Color3.fromRGB(150,150,150)
        sugarCount.TextColor3   = sugar>0   and Color3.fromRGB(192,132,252) or Color3.fromRGB(150,150,150)
        bagCount.TextColor3     = bag>0     and Color3.fromRGB(74,222,128)  or Color3.fromRGB(150,150,150)
    end)
end

-- ========== AUTO MS ==========
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
            statusValue.Text="RUNNING"; statusValue.TextColor3=C.green
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

-- ========== AUTO SELL ==========
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
    checkP(LocalPlayer:FindFirstChild("Backpack")); checkP(LocalPlayer.Character); return items
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
                if sellStatusLbl_ref then sellStatusLbl_ref.Text="MENJUAL..."; sellStatusLbl_ref.TextColor3=C.green end
                for _, marshmellow in ipairs(items) do
                    if not autoSell_Running then break end
                    pcall(function() if marshmellow.Parent~=LocalPlayer.Character then marshmellow.Parent=LocalPlayer.Character end end)
                    task.wait(0.3); holdE(1.5)
                    autoSell_Count=autoSell_Count+1
                    if sellCountLbl_ref then sellCountLbl_ref.Text=tostring(autoSell_Count) end
                    task.wait(0.4)
                end
                if sellStatusLbl_ref then sellStatusLbl_ref.Text="RUNNING"; sellStatusLbl_ref.TextColor3=C.green end
            end
        end
    end
end)

-- ========== BUTTON EVENTS ==========
startBtn.MouseButton1Click:Connect(function()
    if not AutoMS_Running then
        AutoMS_Running=true; statusValue.Text="STARTING"; statusValue.TextColor3=C.yellow
        task.spawn(autoMSLoop)
    end
end)
stopBtn.MouseButton1Click:Connect(function()
    AutoMS_Running=false; statusValue.Text="OFF"; statusValue.TextColor3=C.red
    phaseValue.Text="Water"; timerValue.Text="0s"
end)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.PageUp then
        if AutoMS_Running then
            AutoMS_Running=false; statusValue.Text="OFF"; statusValue.TextColor3=C.red; phaseValue.Text="Water"; timerValue.Text="0s"
        else
            AutoMS_Running=true; statusValue.Text="STARTING"; statusValue.TextColor3=C.yellow; task.spawn(autoMSLoop)
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
        local char=player.Character; local humanoid=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart"); local head=char and char:FindFirstChild("Head")
        local function hideAll() boxOutline.Visible=false; nameLabel.Visible=false; hpBarBg.Visible=false; hpBarFill.Visible=false; distLabel.Visible=false; if itemLabel then itemLabel.Visible=false end end
        if not(char and root and head and humanoid and humanoid.Health>0 and not isWhitelisted(player)) then hideAll(); continue end
        local dist3D = myPos and (root.Position-myPos).Magnitude or 0
        if myPos and espMaxDist>0 and dist3D>espMaxDist then hideAll(); continue end
        local hrpPos,hrpVis=Camera:WorldToViewportPoint(root.Position)
        local headPos,headVis=Camera:WorldToViewportPoint(head.Position)
        if not(hrpVis and headVis) then hideAll(); continue end
        local height=math.abs(headPos.Y-hrpPos.Y)*1.7+(boxPadding*2)
        local width=height*0.55; local boxX=hrpPos.X-width/2; local boxY=headPos.Y-boxPadding
        boxOutline.Color=espBoxColor; boxOutline.Size=Vector2.new(width,height); boxOutline.Position=Vector2.new(boxX,boxY); boxOutline.Visible=true
        nameLabel.Text=player.Name; nameLabel.Color=espNameColor; nameLabel.Position=Vector2.new(hrpPos.X,boxY-14); nameLabel.Visible=true
        local hpRatio=humanoid.MaxHealth>0 and math.clamp(humanoid.Health/humanoid.MaxHealth,0,1) or 1
        local hpBarW=3; local hpBarX=boxX-hpBarW-2
        hpBarBg.Size=Vector2.new(hpBarW,height); hpBarBg.Position=Vector2.new(hpBarX,boxY); hpBarBg.Visible=true
        local fillHeight=math.max(1,height*hpRatio); local fillY=boxY+(height-fillHeight)
        hpBarFill.Size=Vector2.new(hpBarW,fillHeight); hpBarFill.Position=Vector2.new(hpBarX,fillY)
        hpBarFill.Color = hpRatio>0.6 and Color3.fromRGB(0,255,80) or hpRatio>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50)
        hpBarFill.Visible=true
        if myPos then distLabel.Text=string.format("[%.0fm]",dist3D); distLabel.Position=Vector2.new(hrpPos.X,boxY+height+4); distLabel.Visible=true else distLabel.Visible=false end
        if itemLabel then
            local heldItem=getHeldItem(player)
            if heldItem then itemLabel.Text="["..heldItem.."]"; itemLabel.Color=espItemColor; itemLabel.Position=Vector2.new(hrpPos.X,boxY+height+16); itemLabel.Visible=true
            else itemLabel.Visible=false end
        end
    end
end)

-- ========== PAGE AIMBOT ==========
do
    local function mkRow(parent, yPos, h)
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,-16,0,h or 34); f.Position=UDim2.new(0,8,0,yPos)
        f.BackgroundColor3=C.card; f.BorderSizePixel=0; f.Parent=parent; mkCorner(f,5); mkStroke(f,1,C.border); return f
    end
    local function mkRowLabel(row, txt)
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(0.55,0,1,0); l.Position=UDim2.new(0,10,0,0)
        l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=C.text; l.Font=Enum.Font.Gotham; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=row
    end
    local function mkSectionSep(parent, yPos, txt)
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-16,0,18); l.Position=UDim2.new(0,8,0,yPos)
        l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=C.subtext; l.Font=Enum.Font.Gotham; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent
    end
    local function mkToggle(parent, defaultOn, callback)
        local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,34,0,18); bg.Position=UDim2.new(1,-42,0.5,-9)
        bg.BackgroundColor3=defaultOn and C.accent or C.border; bg.BorderSizePixel=0; bg.Parent=parent; mkCorner(bg,9)
        local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,12,0,12)
        knob.Position=defaultOn and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
        knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.BorderSizePixel=0; knob.Parent=bg; mkCorner(knob,6)
        local state=defaultOn
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=bg
        btn.MouseButton1Click:Connect(function()
            state=not state; bg.BackgroundColor3=state and C.accent or C.border
            knob.Position=state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
            if callback then callback(state) end
        end); return bg
    end
    local function mkPairBtn(parent, label1, label2, active, callback)
        local function makeB(txt, xOff, isActive)
            local b=Instance.new("TextButton"); b.Size=UDim2.new(0,78,0,22); b.Position=UDim2.new(1,xOff,0.5,-11)
            b.BackgroundColor3=is