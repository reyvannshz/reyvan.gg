-- ========== MAJESTY ONTOP - INVENTORY TRACKER DENGAN MINIMIZE BUTTON ==========
-- Bisa lihat jumlah item di inventory (Water, Gelatin, Sugar Block Bag, Empty Bag)
-- VERSI FIX: URUTAN Water → Sugar → Gelatin → Bag (dengan delay 1 detik)
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
local boxPadding = 6

-- ========== AIMBOT VARIABLES ==========
local aimbotEnabled      = false
local aimbotMode         = "Camera"
local aimbotFOV          = 120
local aimbotSmooth       = 8
local aimbotTarget       = "Head"
local aimbotActive       = false
local aimbotFovCircle    = nil
-- keybindType: "MouseButton" | "KeyCode" | "MB4" | "MB5"
local aimbotKeybind      = Enum.UserInputType.MouseButton2
local aimbotKeybindIsKey = false
local aimbotKeybindCode  = nil
local aimbotKeybindLabel = "RMB"
local aimbotKeybindType  = "MouseButton"   -- "MouseButton"|"KeyCode"|"MB4"|"MB5"
local isBindingKey       = false
local keybindBtnRef      = nil
local aimbotStatusLbl    = nil

-- Prediction system
local aimbotPrediction   = true      -- toggle prediction on/off
local predStrength       = 0.12      -- 0.0 - 1.0 seberapa jauh predict
local velCache           = {}        -- {plr = {lastPos, lastVel, lastTime}}

-- Target Priority: "Crosshair" = terdekat ke crosshair/mouse, "Player" = terdekat ke karakter kita
local aimbotPriority     = "Crosshair"

-- Distance limits
local aimbotMaxDist      = 500   -- studs
local espMaxDist         = 500   -- studs

-- Warna FOV circle dan ESP box (bisa diganti via UI)
local fovColor           = Color3.fromRGB(220, 38, 38)
local espBoxColor        = Color3.fromRGB(255, 50, 50)

-- MB4/MB5 manual state (karena IsMouseButtonPressed tidak support)
local mb4Held = false
local mb5Held = false

-- Tunggu character spawn
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ========== GUI MAJESTY - TEMA VALARY.GG STYLE ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY ONTOP"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Xeno: coba gethui() → CoreGui → PlayerGui (fallback)
local guiParentOk = false
if not guiParentOk then pcall(function() screenGui.Parent = gethui(); guiParentOk = true end) end
if not guiParentOk then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiParentOk = true end) end
if not guiParentOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ===== WARNA TEMA VALARY =====
local C = {
    bg       = Color3.fromRGB(18, 18, 18),      -- hitam pekat utama
    topbar   = Color3.fromRGB(24, 24, 24),      -- titlebar sedikit lebih terang
    panel    = Color3.fromRGB(22, 22, 22),      -- area konten
    card     = Color3.fromRGB(30, 30, 30),      -- card/row item
    card2    = Color3.fromRGB(26, 26, 26),      -- card lebih gelap
    accent   = Color3.fromRGB(220, 38, 38),     -- merah utama
    accent2  = Color3.fromRGB(239, 68, 68),     -- merah terang
    green    = Color3.fromRGB(34, 197, 94),
    red      = Color3.fromRGB(220, 38, 38),
    yellow   = Color3.fromRGB(234, 179, 8),
    text     = Color3.fromRGB(230, 230, 230),   -- putih agak redup
    subtext  = Color3.fromRGB(120, 120, 120),   -- abu-abu
    border   = Color3.fromRGB(40, 40, 40),      -- border tipis gelap
    search   = Color3.fromRGB(28, 28, 28),      -- search bar bg
    navbg    = Color3.fromRGB(20, 20, 20),      -- bottom nav
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

-- ===== TITLE BAR (valary.gg style) =====
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = C.topbar
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
mkCorner(titleBar, 8)

-- Garis pemisah bawah titlebar
local tbLine = Instance.new("Frame")
tbLine.Size = UDim2.new(1, 0, 0, 1)
tbLine.Position = UDim2.new(0, 0, 1, -1)
tbLine.BackgroundColor3 = C.border
tbLine.BorderSizePixel = 0
tbLine.Parent = titleBar

-- Title text kiri: "valary.gg | South Bronx : The Trenches"
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = '<font color="rgb(220,38,38)">majesty.gg</font>  |  <font color="rgb(170,170,170)">MAJESTY ONTOP</font>'
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Versi kanan
local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 50, 1, 0)
versionLabel.Position = UDim2.new(1, -100, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v8.0.0"
versionLabel.TextColor3 = C.subtext
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 11
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = titleBar

-- Tombol − minimize dan × close (kanan titlebar, gaya valary)
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.Position = UDim2.new(1, -50, 0.5, -11)
minBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
minBtn.Text = "−"
minBtn.TextColor3 = C.text
minBtn.Font = Enum.Font.GothamBold
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
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
mkCorner(closeBtn, 4)

closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        -- Minimize: sembunyikan konten dulu, lalu tween kecil
        task.spawn(function()
            task.wait(0.05)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v ~= titleBar and v:IsA("GuiObject") then
                    v.Visible = false
                end
            end
        end)
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,480,0,36)}):Play()
    else
        -- Restore: tween dulu sampai selesai, baru tampilkan konten
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,480,0,390)}):Play()
        task.spawn(function()
            task.wait(0.18)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v:IsA("GuiObject") then
                    v.Visible = true
                end
            end
        end)
    end
end)

-- ===== SEARCH BAR (di bawah titlebar, kiri) =====
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

-- ===== CONTENT AREA (di bawah search, di atas bottom nav) =====
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, 0, 1, -84)   -- 36 topbar + 48 bottomnav
contentArea.Position = UDim2.new(0, 0, 0, 84)
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
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.Visible = false
    sf.Parent = contentArea
    return sf
end

local pageInv       = makePage()
local pageAuto      = makePage()
local pageEsp       = makePage()
local pageTP        = makePage()
local pageAimbot    = makePage()
local pageCredits   = makePage()

-- ========== WHITELIST DATA ==========
-- Set nama player → true berarti di-whitelist (tidak terdeteksi ESP/Aimbot)
local whitelist = {}   -- { ["PlayerName"] = true }
local wlRefreshFn = nil  -- callback untuk refresh UI, diisi nanti

local function isWhitelisted(plr)
    return whitelist[plr.Name] == true
end

-- Teleport Variables
local autoTP_Running = false
local autoTP_Thread = nil
local savedLocations = {
    {name = "South Bronx", x = 510.1238, y = 3.5872, z = 596.9278, icon = "🏙️"},
    {name = "Gunstore Tier", x = 1169.678955078125, y = 3.362133026123047, z = 139.321533203125, icon = "🔫"},
    {name = "Dealership", x = 731.5349731445312, y = 3.7265229225158669, z = 409.34637451171875, icon = "🚗"},
    {name = "Gunstore Mid", x = 218.72975158691406, y = 3.729841709136963, z = -156.140625, icon = "🔫"},
    {name = "Gunstore New", x = -453.7384948730469, y = 3.7371323108673096, z = 343.8177490234375, icon = "🔫"},
}
local tpStatusValue = nil
local tpLoopValue = nil

-- ========== FUNGSI TELEPORT V3 - LOADCHARACTER METHOD ==========
-- Metode: simpan target, paksa respawn, set posisi saat spawn
-- Ini jauh lebih susah dideteksi karena posisi diset saat karakter baru lahir

local pendingTP = nil  -- CFrame tujuan yang akan dipakai saat spawn

-- Hook: setiap kali karakter spawn, cek apakah ada pending teleport
local function onCharacterAdded(newChar)
    if pendingTP then
        local target = pendingTP
        pendingTP = nil
        -- Tunggu HumanoidRootPart siap
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        local humanoid = newChar:WaitForChild("Humanoid", 5)
        if hrp and humanoid then
            -- Tunggu sebentar agar server selesai setup karakter
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

    -- Coba metode 1: langsung set CFrame dengan jeda panjang (untuk jarak dekat)
    local dist = (hrp.Position - targetCFrame.Position).Magnitude
    if dist < 150 then
        -- Jarak dekat: gerak biasa tapi dengan jeda wajar
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

    -- Metode 2: jarak jauh → respawn di titik tujuan
    pendingTP = targetCFrame
    -- Matikan karakter sebentar agar server trigger respawn
    humanoid.Health = 0
    -- onCharacterAdded akan handle teleport setelah spawn
    return true
end

-- ===== HELPER: Section Title =====
local function sectionTitle(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.subtext
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    -- garis bawah
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

-- ===== PAGE 1: INVENTORY =====
do
    sectionTitle(pageInv, "INVENTORY TRACKER", 8)

    local items = {
        {name="Water",      icon="💧", color=Color3.fromRGB(56,189,248),  countColor=Color3.fromRGB(56,189,248)},
        {name="Gelatin",    icon="🍮", color=Color3.fromRGB(251,146,60),  countColor=Color3.fromRGB(251,146,60)},
        {name="Sugar Block",icon="🧊", color=Color3.fromRGB(192,132,252), countColor=Color3.fromRGB(192,132,252)},
        {name="Empty Bag",  icon="👜", color=Color3.fromRGB(74,222,128),  countColor=Color3.fromRGB(74,222,128)},
    }

    local countLabels = {}
    for i, item in ipairs(items) do
        local card = makeCard(pageInv, 38 + (i-1)*54, 44)

        -- colored left bar
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, -8)
        bar.Position = UDim2.new(0, 4, 0, 4)
        bar.BackgroundColor3 = item.color
        bar.BorderSizePixel = 0
        bar.Parent = card
        mkCorner(bar, 3)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0,30,0,30)
        icon.Position = UDim2.new(0,12,0.5,-15)
        icon.BackgroundTransparency = 1
        icon.Text = item.icon
        icon.TextSize = 20
        icon.Font = Enum.Font.GothamBlack
        icon.Parent = card

        makeLabel(card, item.name, 48, 0, 120, 44, 13, C.text, Enum.Font.GothamBold)

        local cnt = makeLabel(card, "0", 0, 0, -12, 44, 20, item.countColor, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
        cnt.Size = UDim2.new(1, -12, 1, 0)
        cnt.Position = UDim2.new(0, 0, 0, 0)
        countLabels[#countLabels+1] = cnt
    end

    -- assign globals
    waterCount   = countLabels[1]
    gelatinCount = countLabels[2]
    sugarCount   = countLabels[3]
    bagCount     = countLabels[4]

    pageInv.CanvasSize = UDim2.new(0,0,0,260)
end

-- ===== PAGE 2: AUTO MS =====
do
    sectionTitle(pageAuto, "AUTO MARSHMALLOW", 8)

    -- Status card
    local statCard = makeCard(pageAuto, 38, 44)
    makeLabel(statCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    statusValue = makeLabel(statCard, "OFF", 90, 0, 200, 44, 16, C.red, Enum.Font.GothamBlack)

    -- Phase card
    local phCard = makeCard(pageAuto, 90, 44)
    makeLabel(phCard, "PHASE", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    phaseValue = makeLabel(phCard, "Water", 90, 0, 200, 44, 16, Color3.fromRGB(56,189,248), Enum.Font.GothamBlack)

    -- Timer card
    local tmCard = makeCard(pageAuto, 142, 44)
    makeLabel(tmCard, "TIME", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    timerValue = makeLabel(tmCard, "0s", 90, 0, 200, 44, 16, C.yellow, Enum.Font.GothamBlack)

    -- Info card
    local infoCard = makeCard(pageAuto, 194, 30)
    makeLabel(infoCard, "⏱  Delay 1s antara Sugar → Gelatin", 10, 0, 300, 30, 11, C.subtext, Enum.Font.Gotham)

    -- START button
    startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.47, -10, 0, 38)
    startBtn.Position = UDim2.new(0, 10, 0, 234)
    startBtn.BackgroundColor3 = C.green
    startBtn.Text = "▶  START"
    startBtn.TextColor3 = Color3.fromRGB(255,255,255)
    startBtn.Font = Enum.Font.GothamBlack
    startBtn.TextSize = 14
    startBtn.BorderSizePixel = 0
    startBtn.Parent = pageAuto
    mkCorner(startBtn, 6)

    -- STOP button
    stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.47, -10, 0, 38)
    stopBtn.Position = UDim2.new(0.5, 5, 0, 234)
    stopBtn.BackgroundColor3 = C.red
    stopBtn.Text = "■  STOP"
    stopBtn.TextColor3 = Color3.fromRGB(255,255,255)
    stopBtn.Font = Enum.Font.GothamBlack
    stopBtn.TextSize = 14
    stopBtn.BorderSizePixel = 0
    stopBtn.Parent = pageAuto
    mkCorner(stopBtn, 6)

    local hint = makeLabel(pageAuto, "PageUp = toggle start/stop", 10, 282, 300, 20, 10, C.subtext, Enum.Font.Gotham)

    pageAuto.CanvasSize = UDim2.new(0,0,0,310)
end

-- ===== PAGE 3: ESP + WHITELIST =====
do
    -- ── Toggle ESP ──────────────────────────────────────────────────
    sectionTitle(pageEsp, "ESP PLAYER", 8)

    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(1, -20, 0, 36)
    espToggleBtn.Position = UDim2.new(0, 10, 0, 32)
    espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
    espToggleBtn.Text = "●  ESP OFF"
    espToggleBtn.TextColor3 = C.red
    espToggleBtn.Font = Enum.Font.GothamBlack
    espToggleBtn.TextSize = 13
    espToggleBtn.BorderSizePixel = 0
    espToggleBtn.Parent = pageEsp
    mkCorner(espToggleBtn, 6)
    mkStroke(espToggleBtn, 1, C.red)

    -- ── Info bar kecil (satu baris) ─────────────────────────────────
    local espInfoRow = makeCard(pageEsp, 76, 26)
    local espInfoLbl = Instance.new("TextLabel")
    espInfoLbl.Size = UDim2.new(1, -12, 1, 0)
    espInfoLbl.Position = UDim2.new(0, 10, 0, 0)
    espInfoLbl.BackgroundTransparency = 1
    espInfoLbl.Text = "Box  ·  DisplayName  ·  HP Bar  ·  Item  ·  Distance"
    espInfoLbl.TextColor3 = C.subtext
    espInfoLbl.Font = Enum.Font.Gotham
    espInfoLbl.TextSize = 10
    espInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    espInfoLbl.Parent = espInfoRow

    -- ── Whitelist section ───────────────────────────────────────────
    sectionTitle(pageEsp, "🛡  WHITELIST", 112)

    -- badge jumlah WL
    local wlCountBadge = Instance.new("TextLabel")
    wlCountBadge.Size = UDim2.new(0, 24, 0, 14)
    wlCountBadge.Position = UDim2.new(0, 104, 0, 115)
    wlCountBadge.BackgroundColor3 = C.accent
    wlCountBadge.Text = "0"
    wlCountBadge.TextColor3 = Color3.fromRGB(255,255,255)
    wlCountBadge.Font = Enum.Font.GothamBlack
    wlCountBadge.TextSize = 9
    wlCountBadge.BorderSizePixel = 0
    wlCountBadge.Parent = pageEsp
    mkCorner(wlCountBadge, 7)

    -- daftar whitelist aktif
    local wlActiveScroll = Instance.new("ScrollingFrame")
    wlActiveScroll.Size = UDim2.new(1, -20, 0, 90)
    wlActiveScroll.Position = UDim2.new(0, 10, 0, 134)
    wlActiveScroll.BackgroundColor3 = C.card
    wlActiveScroll.BorderSizePixel = 0
    wlActiveScroll.ScrollBarThickness = 2
    wlActiveScroll.ScrollBarImageColor3 = C.accent
    wlActiveScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    wlActiveScroll.Parent = pageEsp
    mkCorner(wlActiveScroll, 6)
    mkStroke(wlActiveScroll, 1, C.border)

    local wlActiveLayout = Instance.new("UIListLayout")
    wlActiveLayout.Padding = UDim.new(0, 2)
    wlActiveLayout.Parent = wlActiveScroll

    local wlPad = Instance.new("UIPadding")
    wlPad.PaddingTop   = UDim.new(0, 3)
    wlPad.PaddingLeft  = UDim.new(0, 3)
    wlPad.PaddingRight = UDim.new(0, 3)
    wlPad.Parent = wlActiveScroll

    local wlEmptyLbl = Instance.new("TextLabel")
    wlEmptyLbl.Size = UDim2.new(1, 0, 0, 26)
    wlEmptyLbl.BackgroundTransparency = 1
    wlEmptyLbl.Text = "— Belum ada player di whitelist —"
    wlEmptyLbl.TextColor3 = C.subtext
    wlEmptyLbl.Font = Enum.Font.Gotham
    wlEmptyLbl.TextSize = 10
    wlEmptyLbl.Parent = wlActiveScroll

    local function refreshActiveList()
        for _, ch in pairs(wlActiveScroll:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
        local count = 0
        for name, _ in pairs(whitelist) do
            count = count + 1
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 24)
            row.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
            row.BorderSizePixel = 0
            row.Parent = wlActiveScroll
            mkCorner(row, 4)

            local ico = Instance.new("TextLabel")
            ico.Size = UDim2.new(0, 20, 1, 0)
            ico.Position = UDim2.new(0, 4, 0, 0)
            ico.BackgroundTransparency = 1
            ico.Text = "🛡"
            ico.TextSize = 11
            ico.Font = Enum.Font.Gotham
            ico.Parent = row

            local nLbl = Instance.new("TextLabel")
            nLbl.Size = UDim2.new(1, -78, 1, 0)
            nLbl.Position = UDim2.new(0, 26, 0, 0)
            nLbl.BackgroundTransparency = 1
            nLbl.Text = name
            nLbl.TextColor3 = Color3.fromRGB(100, 220, 255)
            nLbl.Font = Enum.Font.GothamBold
            nLbl.TextSize = 11
            nLbl.TextXAlignment = Enum.TextXAlignment.Left
            nLbl.Parent = row

            local remBtn = Instance.new("TextButton")
            remBtn.Size = UDim2.new(0, 52, 0, 18)
            remBtn.Position = UDim2.new(1, -56, 0.5, -9)
            remBtn.BackgroundColor3 = Color3.fromRGB(130, 18, 18)
            remBtn.Text = "✕ Remove"
            remBtn.TextColor3 = Color3.fromRGB(255,255,255)
            remBtn.Font = Enum.Font.GothamBold
            remBtn.TextSize = 8
            remBtn.BorderSizePixel = 0
            remBtn.Parent = row
            mkCorner(remBtn, 4)

            local capName = name
            remBtn.MouseButton1Click:Connect(function()
                whitelist[capName] = nil
                refreshActiveList()
            end)
        end
        wlEmptyLbl.Visible = (count == 0)
        wlCountBadge.Text = tostring(count)
        wlActiveScroll.CanvasSize = UDim2.new(0, 0, 0, count * 26 + 6)
    end

    wlRefreshFn = refreshActiveList
    refreshActiveList()

    -- ── Player di server ────────────────────────────────────────────
    sectionTitle(pageEsp, "TAMBAH DARI SERVER", 232)

    local serverScroll = Instance.new("ScrollingFrame")
    serverScroll.Size = UDim2.new(1, -20, 0, 120)
    serverScroll.Position = UDim2.new(0, 10, 0, 256)
    serverScroll.BackgroundColor3 = C.card
    serverScroll.BorderSizePixel = 0
    serverScroll.ScrollBarThickness = 2
    serverScroll.ScrollBarImageColor3 = C.accent
    serverScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    serverScroll.Parent = pageEsp
    mkCorner(serverScroll, 6)
    mkStroke(serverScroll, 1, C.border)

    local serverLayout = Instance.new("UIListLayout")
    serverLayout.Padding = UDim.new(0, 2)
    serverLayout.Parent = serverScroll

    local sPad = Instance.new("UIPadding")
    sPad.PaddingTop   = UDim.new(0, 3)
    sPad.PaddingLeft  = UDim.new(0, 3)
    sPad.PaddingRight = UDim.new(0, 3)
    sPad.Parent = serverScroll

    local function refreshServerList()
        for _, ch in pairs(serverScroll:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
        local count = 0
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                count = count + 1
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 26)
                row.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
                row.BorderSizePixel = 0
                row.Parent = serverScroll
                mkCorner(row, 4)

                local sIco = Instance.new("TextLabel")
                sIco.Size = UDim2.new(0, 20, 1, 0)
                sIco.Position = UDim2.new(0, 4, 0, 0)
                sIco.BackgroundTransparency = 1
                sIco.Text = whitelist[plr.Name] and "🛡" or "👤"
                sIco.TextSize = 11
                sIco.Font = Enum.Font.Gotham
                sIco.Parent = row

                local pLbl = Instance.new("TextLabel")
                pLbl.Size = UDim2.new(1, -84, 1, 0)
                pLbl.Position = UDim2.new(0, 26, 0, 0)
                pLbl.BackgroundTransparency = 1
                pLbl.Text = plr.Name
                pLbl.TextColor3 = whitelist[plr.Name] and Color3.fromRGB(100,220,255) or C.text
                pLbl.Font = Enum.Font.GothamBold
                pLbl.TextSize = 11
                pLbl.TextXAlignment = Enum.TextXAlignment.Left
                pLbl.Parent = row

                local addBtn = Instance.new("TextButton")
                addBtn.Size = UDim2.new(0, 62, 0, 18)
                addBtn.Position = UDim2.new(1, -66, 0.5, -9)
                addBtn.BorderSizePixel = 0
                addBtn.Font = Enum.Font.GothamBold
                addBtn.TextSize = 9
                addBtn.Parent = row
                mkCorner(addBtn, 4)

                local function syncBtn()
                    if whitelist[plr.Name] then
                        addBtn.Text = "✓ Listed"
                        addBtn.BackgroundColor3 = Color3.fromRGB(18, 70, 18)
                        addBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
                    else
                        addBtn.Text = "+ Whitelist"
                        addBtn.BackgroundColor3 = Color3.fromRGB(18, 50, 110)
                        addBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
                    end
                end
                syncBtn()

                addBtn.MouseButton1Click:Connect(function()
                    whitelist[plr.Name] = whitelist[plr.Name] ~= true and true or nil
                    syncBtn()
                    sIco.Text  = whitelist[plr.Name] and "🛡" or "👤"
                    pLbl.TextColor3 = whitelist[plr.Name] and Color3.fromRGB(100,220,255) or C.text
                    refreshActiveList()
                end)
            end
        end
        serverScroll.CanvasSize = UDim2.new(0, 0, 0, count * 28 + 6)
    end

    refreshServerList()

    -- tombol Refresh + Clear All berdampingan
    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0.5, -14, 0, 30)
    refBtn.Position = UDim2.new(0, 10, 0, 384)
    refBtn.BackgroundColor3 = C.card
    refBtn.Text = "🔄 Refresh"
    refBtn.TextColor3 = C.text
    refBtn.Font = Enum.Font.GothamBold
    refBtn.TextSize = 11
    refBtn.BorderSizePixel = 0
    refBtn.Parent = pageEsp
    mkCorner(refBtn, 6)
    mkStroke(refBtn, 1, C.border)
    refBtn.MouseButton1Click:Connect(refreshServerList)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.5, -14, 0, 30)
    clearBtn.Position = UDim2.new(0.5, 4, 0, 384)
    clearBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 10)
    clearBtn.Text = "🗑 Clear All"
    clearBtn.TextColor3 = C.accent2
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 11
    clearBtn.BorderSizePixel = 0
    clearBtn.Parent = pageEsp
    mkCorner(clearBtn, 6)
    mkStroke(clearBtn, 1, C.accent)
    clearBtn.MouseButton1Click:Connect(function()
        whitelist = {}
        refreshActiveList()
        refreshServerList()
    end)

    pageEsp.CanvasSize = UDim2.new(0, 0, 0, 424)
end

-- ===== PAGE 4: TELEPORT =====
do
    sectionTitle(pageTP, "🚀 AUTO TELEPORT", 8)

    -- Status card
    local tpStatCard = makeCard(pageTP, 38, 44)
    makeLabel(tpStatCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    tpStatusValue = makeLabel(tpStatCard, "STANDBY", 90, 0, 200, 44, 16, C.yellow, Enum.Font.GothamBlack)

    -- Loop info card
    local tpLoopCard = makeCard(pageTP, 90, 44)
    makeLabel(tpLoopCard, "MODE", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    tpLoopValue = makeLabel(tpLoopCard, "ONCE", 90, 0, 200, 44, 14, C.accent, Enum.Font.GothamBlack)

    -- Koordinat info
    local coordCard = makeCard(pageTP, 142, 54)
    makeLabel(coordCard, "📍 South Bronx", 10, 4, 260, 20, 12, C.accent2, Enum.Font.GothamBlack)
    makeLabel(coordCard, "X: 510.12   Y: 3.58   Z: 596.92", 10, 26, 300, 18, 11, C.subtext, Enum.Font.Gotham)

    -- Separator
    sectionTitle(pageTP, "PILIH LOKASI", 208)

    -- Tombol lokasi saved
    for i, loc in ipairs(savedLocations) do
        local locBtn = Instance.new("TextButton")
        locBtn.Size = UDim2.new(1, -20, 0, 40)
        locBtn.Position = UDim2.new(0, 10, 0, 232 + (i-1)*48)
        locBtn.BackgroundColor3 = C.card
        locBtn.Text = loc.icon .. "  " .. loc.name
        locBtn.TextColor3 = C.text
        locBtn.Font = Enum.Font.GothamBold
        locBtn.TextSize = 13
        locBtn.TextXAlignment = Enum.TextXAlignment.Left
        locBtn.BorderSizePixel = 0
        locBtn.Parent = pageTP
        mkCorner(locBtn, 6)
        mkStroke(locBtn, 1, C.accent)

        -- Pad teks
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.Parent = locBtn

        local ci = i
        locBtn.MouseButton1Click:Connect(function()
            local l = savedLocations[ci]
            tpStatusValue.Text = "TELEPORTING..."
            tpStatusValue.TextColor3 = C.yellow
            task.spawn(function()
                doTeleport(CFrame.new(l.x, l.y + 3, l.z))
                -- Tunggu karakter spawn kembali kalau pakai metode respawn
                task.wait(0.5)
                local newChar = LocalPlayer.Character
                if newChar then
                    local hrp2 = newChar:FindFirstChild("HumanoidRootPart")
                    if hrp2 then
                        -- Pastikan posisi sudah benar
                        local dist = (hrp2.Position - Vector3.new(l.x, l.y + 3, l.z)).Magnitude
                        if dist < 20 then
                            tpStatusValue.Text = "ARRIVED ✓"
                            tpStatusValue.TextColor3 = C.green
                        else
                            -- Fallback set ulang posisi
                            hrp2.CFrame = CFrame.new(l.x, l.y + 3, l.z)
                            task.wait(0.3)
                            tpStatusValue.Text = "ARRIVED ✓"
                            tpStatusValue.TextColor3 = C.green
                        end
                    end
                else
                    tpStatusValue.Text = "ARRIVED ✓"
                    tpStatusValue.TextColor3 = C.green
                end
                task.wait(2)
                tpStatusValue.Text = "STANDBY"
                tpStatusValue.TextColor3 = C.yellow
            end)
        end)

        -- Hover effect
        locBtn.MouseEnter:Connect(function()
            locBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        end)
        locBtn.MouseLeave:Connect(function()
            locBtn.BackgroundColor3 = C.card
        end)
    end

    -- ===== AUTO LOOP TELEPORT =====
    sectionTitle(pageTP, "AUTO LOOP TELEPORT", 482)

    -- Toggle loop mode
    local loopToggle = Instance.new("TextButton")
    loopToggle.Size = UDim2.new(1, -20, 0, 38)
    loopToggle.Position = UDim2.new(0, 10, 0, 508)
    loopToggle.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
    loopToggle.Text = "🔁  AUTO LOOP : OFF"
    loopToggle.TextColor3 = C.red
    loopToggle.Font = Enum.Font.GothamBlack
    loopToggle.TextSize = 13
    loopToggle.BorderSizePixel = 0
    loopToggle.Parent = pageTP
    mkCorner(loopToggle, 6)
    mkStroke(loopToggle, 1, C.red)

    -- Interval info
    local intervalCard = makeCard(pageTP, 554, 30)
    makeLabel(intervalCard, "⏱  Interval teleport: setiap 30 detik", 10, 0, 300, 30, 11, C.subtext, Enum.Font.Gotham)

    -- Teleport ke posisi player lain (bonus)
    sectionTitle(pageTP, "TELEPORT KE PLAYER", 596)

    local playerListFrame = Instance.new("ScrollingFrame")
    playerListFrame.Size = UDim2.new(1, -20, 0, 100)
    playerListFrame.Position = UDim2.new(0, 10, 0, 620)
    playerListFrame.BackgroundColor3 = C.card
    playerListFrame.BorderSizePixel = 0
    playerListFrame.ScrollBarThickness = 3
    playerListFrame.ScrollBarImageColor3 = C.accent
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerListFrame.Parent = pageTP
    mkCorner(playerListFrame, 6)
    mkStroke(playerListFrame, 1, C.border)

    local plLayout = Instance.new("UIListLayout")
    plLayout.Padding = UDim.new(0, 4)
    plLayout.Parent = playerListFrame

    local function refreshPlayerList()
        for _, ch in pairs(playerListFrame:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local players = game:GetService("Players"):GetPlayers()
        local count = 0
        for _, plr in pairs(players) do
            if plr ~= LocalPlayer then
                local pb = Instance.new("TextButton")
                pb.Size = UDim2.new(1, -8, 0, 28)
                pb.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
                pb.Text = "👤  " .. plr.Name
                pb.TextColor3 = C.text
                pb.Font = Enum.Font.GothamBold
                pb.TextSize = 11
                pb.TextXAlignment = Enum.TextXAlignment.Left
                pb.BorderSizePixel = 0
                pb.Parent = playerListFrame
                mkCorner(pb, 4)
                local pad2 = Instance.new("UIPadding")
                pad2.PaddingLeft = UDim.new(0, 8)
                pad2.Parent = pb
                pb.MouseButton1Click:Connect(function()
                    local tgt = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if tgt then
                        tpStatusValue.Text = "TP → " .. plr.Name
                        tpStatusValue.TextColor3 = C.yellow
                        task.spawn(function()
                            doTeleport(tgt.CFrame + Vector3.new(2, 0, 0))
                            tpStatusValue.Text = "ARRIVED ✓"
                            tpStatusValue.TextColor3 = C.green
                            task.wait(2)
                            tpStatusValue.Text = "STANDBY"
                            tpStatusValue.TextColor3 = C.yellow
                        end)
                    end
                end)
                count = count + 1
            end
        end
        playerListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 32)
    end

    -- Refresh button
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1, -20, 0, 30)
    refreshBtn.Position = UDim2.new(0, 10, 0, 728)
    refreshBtn.BackgroundColor3 = C.accent
    refreshBtn.Text = "🔄  Refresh Player List"
    refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Parent = pageTP
    mkCorner(refreshBtn, 6)

    refreshBtn.MouseButton1Click:Connect(refreshPlayerList)
    refreshPlayerList()

    -- Loop toggle handler
    loopToggle.MouseButton1Click:Connect(function()
        autoTP_Running = not autoTP_Running
        if autoTP_Running then
            loopToggle.Text = "🔁  AUTO LOOP : ON"
            loopToggle.TextColor3 = C.green
            loopToggle.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
            mkStroke(loopToggle, 1, C.green)
            tpLoopValue.Text = "LOOPING"
            tpLoopValue.TextColor3 = C.green
            autoTP_Thread = task.spawn(function()
                while autoTP_Running do
                    tpStatusValue.Text = "TELEPORTING"
                    tpStatusValue.TextColor3 = C.yellow
                    doTeleport(CFrame.new(510.1238, 6.5872, 596.9278))
                    tpStatusValue.Text = "ARRIVED ✓"
                    tpStatusValue.TextColor3 = C.green
                    for i = 30, 1, -1 do
                        if not autoTP_Running then break end
                        tpLoopValue.Text = "Next: " .. i .. "s"
                        task.wait(1)
                    end
                end
                tpLoopValue.Text = "ONCE"
                tpLoopValue.TextColor3 = C.accent
            end)
        else
            autoTP_Running = false
            loopToggle.Text = "🔁  AUTO LOOP : OFF"
            loopToggle.TextColor3 = C.red
            loopToggle.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
            mkStroke(loopToggle, 1, C.red)
            tpLoopValue.Text = "ONCE"
            tpLoopValue.TextColor3 = C.accent
            tpStatusValue.Text = "STANDBY"
            tpStatusValue.TextColor3 = C.yellow
        end
    end)

    pageTP.CanvasSize = UDim2.new(0, 0, 0, 780)
end



-- ========== PAGE CREDITS ==========
do
    -- ── Warna khusus per role ──
    local roleColor = {
        OWNER     = Color3.fromRGB(255, 200, 0),    -- gold
        DEVELOPER = Color3.fromRGB(99,  202, 255),  -- biru muda
        HELPER    = Color3.fromRGB(74,  222, 128),  -- hijau
    }
    local roleGlow = {
        OWNER     = Color3.fromRGB(255, 160, 0),
        DEVELOPER = Color3.fromRGB(56,  165, 255),
        HELPER    = Color3.fromRGB(34,  197, 94),
    }

    -- ── Data member ──
    local members = {
        {
            name   = "Hiro",
            role   = "OWNER",
            badge  = "👑",
            desc   = "Founder & pemimpin project\nMAJESTY ONTOP",
        },
        {
            name   = "Reyvan",
            role   = "DEVELOPER",
            badge  = "⚙️",
            desc   = "Core developer\nscript & sistem utama",
        },
        {
            name   = "Fachri",
            role   = "DEVELOPER",
            badge  = "⚙️",
            desc   = "Core developer\nUI & fitur tambahan",
        },
        {
            name   = "Qiee",
            role   = "HELPER",
            badge  = "🤝",
            desc   = "Community helper\ntesting & support",
        },
    }

    local y = 0

    -- ── Header banner ──
    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(1, 0, 0, 72)
    banner.Position = UDim2.new(0, 0, 0, y)
    banner.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    banner.BorderSizePixel = 0
    banner.Parent = pageCredits

    -- garis aksen merah kiri
    local bannerAccent = Instance.new("Frame")
    bannerAccent.Size = UDim2.new(0, 3, 1, 0)
    bannerAccent.BackgroundColor3 = C.accent
    bannerAccent.BorderSizePixel = 0
    bannerAccent.Parent = banner

    -- logo teks kiri
    local logoLbl = Instance.new("TextLabel")
    logoLbl.Size = UDim2.new(1, -20, 0, 28)
    logoLbl.Position = UDim2.new(0, 14, 0, 10)
    logoLbl.BackgroundTransparency = 1
    logoLbl.RichText = true
    logoLbl.Text = '<font color="rgb(220,38,38)" size="18"><b>MAJESTY</b></font>'
        .. '<font color="rgb(200,200,200)" size="14">  ONTOP</font>'
    logoLbl.Font = Enum.Font.GothamBlack
    logoLbl.TextSize = 18
    logoLbl.TextXAlignment = Enum.TextXAlignment.Left
    logoLbl.Parent = banner

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -20, 0, 18)
    subLbl.Position = UDim2.new(0, 14, 0, 38)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "The team behind the script"
    subLbl.TextColor3 = C.subtext
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 10
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.Parent = banner

    -- versi kanan
    local verLbl = Instance.new("TextLabel")
    verLbl.Size = UDim2.new(0, 80, 0, 18)
    verLbl.Position = UDim2.new(1, -88, 0, 10)
    verLbl.BackgroundTransparency = 1
    verLbl.Text = "v8.0.0"
    verLbl.TextColor3 = C.accent
    verLbl.Font = Enum.Font.GothamBlack
    verLbl.TextSize = 11
    verLbl.TextXAlignment = Enum.TextXAlignment.Right
    verLbl.Parent = banner

    -- garis bawah banner
    local banLine = Instance.new("Frame")
    banLine.Size = UDim2.new(1, 0, 0, 1)
    banLine.Position = UDim2.new(0, 0, 1, -1)
    banLine.BackgroundColor3 = C.accent
    banLine.BorderSizePixel = 0
    banLine.Parent = banner

    y = y + 80

    -- ── Kartu per member ──
    for _, m in ipairs(members) do
        local col    = roleColor[m.role]
        local glowC  = roleGlow[m.role]

        -- wrapper card
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -16, 0, 80)
        card.Position = UDim2.new(0, 8, 0, y)
        card.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        card.BorderSizePixel = 0
        card.Parent = pageCredits
        mkCorner(card, 8)
        mkStroke(card, 1, Color3.fromRGB(40, 40, 40))

        -- garis kiri berwarna sesuai role
        local roleBar = Instance.new("Frame")
        roleBar.Size = UDim2.new(0, 3, 1, -12)
        roleBar.Position = UDim2.new(0, 0, 0, 6)
        roleBar.BackgroundColor3 = col
        roleBar.BorderSizePixel = 0
        roleBar.Parent = card
        mkCorner(roleBar, 3)

        -- avatar circle (placeholder inisial)
        local avatar = Instance.new("Frame")
        avatar.Size = UDim2.new(0, 46, 0, 46)
        avatar.Position = UDim2.new(0, 12, 0.5, -23)
        avatar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        avatar.BorderSizePixel = 0
        avatar.Parent = card
        mkCorner(avatar, 23)
        mkStroke(avatar, 2, col)

        -- inisial di avatar
        local initLbl = Instance.new("TextLabel")
        initLbl.Size = UDim2.new(1, 0, 1, 0)
        initLbl.BackgroundTransparency = 1
        initLbl.Text = string.upper(string.sub(m.name, 1, 1))
        initLbl.TextColor3 = col
        initLbl.Font = Enum.Font.GothamBlack
        initLbl.TextSize = 20
        initLbl.Parent = avatar

        -- badge emoji
        local badgeLbl = Instance.new("TextLabel")
        badgeLbl.Size = UDim2.new(0, 20, 0, 20)
        badgeLbl.Position = UDim2.new(0, 34, 0.5, 2)
        badgeLbl.BackgroundTransparency = 1
        badgeLbl.Text = m.badge
        badgeLbl.TextSize = 12
        badgeLbl.Font = Enum.Font.Gotham
        badgeLbl.Parent = card

        -- nama player
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -130, 0, 22)
        nameLbl.Position = UDim2.new(0, 66, 0, 12)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = m.name
        nameLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 15
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = card

        -- deskripsi
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -130, 0, 30)
        descLbl.Position = UDim2.new(0, 66, 0, 34)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = m.desc
        descLbl.TextColor3 = C.subtext
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 10
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextWrapped = true
        descLbl.Parent = card

        -- badge role (kanan atas card)
        local rolePill = Instance.new("Frame")
        rolePill.Size = UDim2.new(0, 82, 0, 20)
        rolePill.Position = UDim2.new(1, -90, 0, 10)
        rolePill.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
        rolePill.BorderSizePixel = 0
        rolePill.Parent = card
        mkCorner(rolePill, 10)
        mkStroke(rolePill, 1, col)

        local roleTxt = Instance.new("TextLabel")
        roleTxt.Size = UDim2.new(1, 0, 1, 0)
        roleTxt.BackgroundTransparency = 1
        roleTxt.Text = m.role
        roleTxt.TextColor3 = col
        roleTxt.Font = Enum.Font.GothamBlack
        roleTxt.TextSize = 9
        roleTxt.Parent = rolePill

        y = y + 88
    end

    -- ── Divider ──
    local divFrame = Instance.new("Frame")
    divFrame.Size = UDim2.new(1, -32, 0, 1)
    divFrame.Position = UDim2.new(0, 16, 0, y + 4)
    divFrame.BackgroundColor3 = C.border
    divFrame.BorderSizePixel = 0
    divFrame.Parent = pageCredits
    y = y + 16

    -- ── Footer terima kasih ──
    local footerCard = Instance.new("Frame")
    footerCard.Size = UDim2.new(1, -16, 0, 54)
    footerCard.Position = UDim2.new(0, 8, 0, y)
    footerCard.BackgroundColor3 = Color3.fromRGB(20, 14, 14)
    footerCard.BorderSizePixel = 0
    footerCard.Parent = pageCredits
    mkCorner(footerCard, 8)
    mkStroke(footerCard, 1, C.accent)

    local footerLbl = Instance.new("TextLabel")
    footerLbl.Size = UDim2.new(1, -16, 1, 0)
    footerLbl.Position = UDim2.new(0, 8, 0, 0)
    footerLbl.BackgroundTransparency = 1
    footerLbl.RichText = true
    footerLbl.Text = '<font color="rgb(220,38,38)">❤</font>'
        .. '<font color="rgb(180,180,180)">  Terima kasih sudah menggunakan\n'
        .. '<b>MAJESTY ONTOP</b> — Stay safe, stay smart.</font>'
    footerLbl.Font = Enum.Font.Gotham
    footerLbl.TextSize = 11
    footerLbl.TextWrapped = true
    footerLbl.Parent = footerCard

    y = y + 62

    pageCredits.CanvasSize = UDim2.new(0, 0, 0, y + 16)
end

-- ===== BOTTOM NAV BAR (valary.gg style) =====
local tabDefs = {
    {icon="📦", label="Inventory", page=pageInv},
    {icon="⚙️", label="Auto MS",   page=pageAuto},
    {icon="👁",  label="ESP",       page=pageEsp},
    {icon="🚀", label="Teleport",  page=pageTP},
    {icon="🎯", label="Aimbot",    page=pageAimbot},
    {icon="👑", label="Credits",   page=pageCredits},
}

local activeTab = nil
local tabBtns = {}

local bottomNav = Instance.new("Frame")
bottomNav.Size = UDim2.new(1, 0, 0, 44)
bottomNav.Position = UDim2.new(0, 0, 1, -44)
bottomNav.BackgroundColor3 = C.navbg
bottomNav.BorderSizePixel = 0
bottomNav.Parent = mainFrame
mkStroke(bottomNav, 1, C.border)

-- Garis atas nav
local navLine = Instance.new("Frame")
navLine.Size = UDim2.new(1, 0, 0, 1)
navLine.Position = UDim2.new(0, 0, 0, 0)
navLine.BackgroundColor3 = C.border
navLine.BorderSizePixel = 0
navLine.Parent = bottomNav

local function setTab(idx)
    for i, tb in ipairs(tabBtns) do
        local isActive = (i == idx)
        tb.TextColor3 = isActive and C.accent2 or C.subtext
        -- indikator merah di atas tombol aktif
        local ind = tb:FindFirstChild("indicator")
        if ind then ind.Visible = isActive end
    end
    for _, td in ipairs(tabDefs) do td.page.Visible = false end
    tabDefs[idx].page.Visible = true
    activeTab = idx
end

local navW = 1 / #tabDefs
for i, td in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(navW, 0, 1, 0)
    btn.Position = UDim2.new(navW * (i-1), 0, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Text = td.icon .. "  " .. td.label
    btn.TextColor3 = C.subtext
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = bottomNav

    -- indikator garis merah di atas tombol aktif
    local ind = Instance.new("Frame")
    ind.Name = "indicator"
    ind.Size = UDim2.new(0.7, 0, 0, 2)
    ind.Position = UDim2.new(0.15, 0, 0, 0)
    ind.BackgroundColor3 = C.accent
    ind.BorderSizePixel = 0
    ind.Visible = false
    ind.Parent = btn
    mkCorner(ind, 2)

    tabBtns[i] = btn
    local ci = i
    btn.MouseButton1Click:Connect(function() setTab(ci) end)
end

-- Player info di kiri atas (di antara search dan content)
local playerInfoLbl = Instance.new("TextLabel")
playerInfoLbl.Size = UDim2.new(0, 200, 0, 28)
playerInfoLbl.Position = UDim2.new(0, 200, 0, 44)
playerInfoLbl.BackgroundTransparency = 1
playerInfoLbl.Text = "👤  " .. LocalPlayer.Name
playerInfoLbl.TextColor3 = C.subtext
playerInfoLbl.Font = Enum.Font.GothamBold
playerInfoLbl.TextSize = 11
playerInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
playerInfoLbl.Parent = mainFrame

-- Default ke tab 1
setTab(1)

-- ========== FUNGSI MINIMIZE (handled by dot buttons in titlebar) ==========

-- ========== FUNGSI INVENTORY TRACKER ==========
local function updateInventory()
    pcall(function()
        local water = 0
        local gelatin = 0
        local sugar = 0
        local bag = 0
        
        -- Cek di Backpack
        if LocalPlayer and LocalPlayer:FindFirstChild("Backpack") then
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = string.lower(tool.Name)
                    
                    if name:find("water") then
                        water = water + 1
                    elseif name:find("gelatin") or name:find("gel") then
                        gelatin = gelatin + 1
                    elseif name:find("sugar") or name:find("gula") or name:find("block") then
                        sugar = sugar + 1
                    elseif name:find("bag") or name:find("tas") or name:find("empty") then
                        bag = bag + 1
                    end
                end
            end
        end
        
        -- Cek di Character (yang lagi dipegang)
        if LocalPlayer.Character then
            for _, tool in pairs(LocalPlayer.Character:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = string.lower(tool.Name)
                    
                    if name:find("water") then
                        water = water + 1
                    elseif name:find("gelatin") or name:find("gel") then
                        gelatin = gelatin + 1
                    elseif name:find("sugar") or name:find("gula") or name:find("block") then
                        sugar = sugar + 1
                    elseif name:find("bag") or name:find("tas") or name:find("empty") then
                        bag = bag + 1
                    end
                end
            end
        end
        
        -- Update UI
        waterCount.Text = tostring(water)
        gelatinCount.Text = tostring(gelatin)
        sugarCount.Text = tostring(sugar)
        bagCount.Text = tostring(bag)
        
        -- Update warna berdasarkan jumlah
        if water > 0 then
            waterCount.TextColor3 = Color3.fromRGB(0, 255, 255)
        else
            waterCount.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        
        if gelatin > 0 then
            gelatinCount.TextColor3 = Color3.fromRGB(255, 200, 0)
        else
            gelatinCount.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        
        if sugar > 0 then
            sugarCount.TextColor3 = Color3.fromRGB(255, 100, 255)
        else
            sugarCount.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        
        if bag > 0 then
            bagCount.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            bagCount.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end)
end

-- ========== FUNGSI AUTO MS ==========
-- Xeno: VirtualInputManager tidak reliable, pakai keypress/keyrelease langsung
local function interact()
    -- Coba VirtualInputManager dulu (Synapse X, Script-Ware)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.12)
        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    -- Xeno / KRNL / lainnya: pakai keypress API
    pcall(function() keypress(0x45) end)
    task.wait(0.12)
    pcall(function() keyrelease(0x45) end)
    task.wait(0.1)
end

local function holdItem(itemName)
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("Backpack") then
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    local toolName = string.lower(tool.Name)
                    local searchName = string.lower(itemName)
                    
                    if string.find(toolName, searchName) then
                        tool.Parent = LocalPlayer.Character
                        task.wait(0.2)
                        return true
                    end
                end
            end
        end
    end)
    return false
end

local function lookAt(itemName)
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local root = char.HumanoidRootPart
        local searchName = string.lower(itemName)
        
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                local objName = string.lower(obj.Name)
                if string.find(objName, searchName) then
                    local dist = (root.Position - obj.Position).Magnitude
                    if dist < 15 then
                        root.CFrame = CFrame.lookAt(root.Position, Vector3.new(obj.Position.X, root.Position.Y, obj.Position.Z))
                        return
                    end
                end
            end
        end
    end)
end

-- ========== MAIN LOOP ==========
local function autoMSLoop()
    while AutoMS_Running do
        local success = pcall(function()
            -- STEP 1: WATER
            statusValue.Text = "RUNNING"
            statusValue.TextColor3 = Color3.fromRGB(100, 255, 100)
            phaseValue.Text = "Water"
            timerValue.Text = "0s"
            holdItem("water")
            lookAt("water")
            task.wait(0.3)
            interact()
            updateInventory()
            
            -- Tunggu 20 detik
            for i = 1, 20 do
                if not AutoMS_Running then return end
                timerValue.Text = i .. "/20s"
                updateInventory()
                task.wait(1)
            end
            
            -- STEP 2: SUGAR
            phaseValue.Text = "Sugar"
            timerValue.Text = "0s"
            holdItem("sugar")
            lookAt("sugar")
            task.wait(0.3)
            interact()
            updateInventory()
            
            -- ===== DELAY 1 DETIK =====
            phaseValue.Text = "Delay 1s"
            timerValue.Text = "1s"
            task.wait(1)
            updateInventory()
            -- =========================
            
            -- STEP 3: GELATIN
            phaseValue.Text = "Gelatin"
            timerValue.Text = "0s"
            holdItem("gelatin")
            lookAt("gelatin")
            task.wait(0.3)
            interact()
            updateInventory()
            
            -- Tunggu 45 detik
            for i = 1, 45 do
                if not AutoMS_Running then return end
                phaseValue.Text = "Ferment"
                timerValue.Text = i .. "/45s"
                updateInventory()
                task.wait(1)
            end
            
            -- STEP 4: BAG
            phaseValue.Text = "Bag"
            timerValue.Text = "0s"
            holdItem("bag")
            lookAt("bag")
            task.wait(0.3)
            interact()
            updateInventory()
            
            phaseValue.Text = "Complete"
            timerValue.Text = "Done"
            task.wait(2)
            updateInventory()
        end)
        
        if not success then
            statusValue.Text = "ERROR"
            statusValue.TextColor3 = Color3.fromRGB(255, 0, 0)
            task.wait(2)
        end
    end
    
    statusValue.Text = "OFF"
    statusValue.TextColor3 = Color3.fromRGB(255, 80, 80)
    phaseValue.Text = "Water"
    timerValue.Text = "0s"
end

-- ========== BUTTON FUNCTIONS ==========
startBtn.MouseButton1Click:Connect(function()
    if not AutoMS_Running then
        AutoMS_Running = true
        statusValue.Text = "STARTING"
        statusValue.TextColor3 = Color3.fromRGB(255, 255, 0)
        task.spawn(autoMSLoop)
    end
end)

stopBtn.MouseButton1Click:Connect(function()
    AutoMS_Running = false
    statusValue.Text = "OFF"
    statusValue.TextColor3 = Color3.fromRGB(255, 80, 80)
    phaseValue.Text = "Water"
    timerValue.Text = "0s"
end)

-- PageUp toggle
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.PageUp then
        if AutoMS_Running then
            AutoMS_Running = false
            statusValue.Text = "OFF"
            statusValue.TextColor3 = Color3.fromRGB(255, 80, 80)
            phaseValue.Text = "Water"
            timerValue.Text = "0s"
        else
            AutoMS_Running = true
            statusValue.Text = "STARTING"
            statusValue.TextColor3 = Color3.fromRGB(255, 255, 0)
            task.spawn(autoMSLoop)
        end
    end
end)

-- Update inventory tiap 1 detik
task.spawn(function()
    while true do
        updateInventory()
        task.wait(1)
    end
end)

-- ========== FUNGSI ESP ==========
local function removeESP(player)
    if espCache[player] then
        for _, obj in pairs(espCache[player]) do
            obj:Remove()
        end
        espCache[player] = nil
    end
end

local function createESP(player)
    removeESP(player)

    -- Box outline
    local boxOutline = Drawing.new("Square")
    boxOutline.Thickness = 1
    boxOutline.Color = espBoxColor
    boxOutline.Filled = false
    boxOutline.Visible = false

    -- Name label di atas box
    local nameLabel = Drawing.new("Text")
    nameLabel.Text = player.DisplayName
    nameLabel.Size = 10
    nameLabel.Font = 1
    nameLabel.Color = Color3.fromRGB(255, 255, 255)
    nameLabel.Outline = true
    nameLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameLabel.Center = true
    nameLabel.Visible = false

    -- Health bar background (abu gelap)
    local hpBarBg = Drawing.new("Square")
    hpBarBg.Thickness = 1
    hpBarBg.Color = Color3.fromRGB(30, 30, 30)
    hpBarBg.Filled = true
    hpBarBg.Visible = false

    -- Health bar fill (hijau → merah sesuai HP)
    local hpBarFill = Drawing.new("Square")
    hpBarFill.Thickness = 1
    hpBarFill.Color = Color3.fromRGB(0, 255, 80)
    hpBarFill.Filled = true
    hpBarFill.Visible = false

    -- Health text (persentase)
    local hpText = Drawing.new("Text")
    hpText.Size = 11
    hpText.Font = 1
    hpText.Color = Color3.fromRGB(255, 255, 255)
    hpText.Outline = true
    hpText.OutlineColor = Color3.fromRGB(0, 0, 0)
    hpText.Center = true
    hpText.Visible = false

    -- Inventory label (muncul di bawah nama)
    local invLabel = Drawing.new("Text")
    invLabel.Size = 9
    invLabel.Font = 1
    invLabel.Color = Color3.fromRGB(255, 230, 100)
    invLabel.Outline = true
    invLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    invLabel.Center = true
    invLabel.Visible = false
    invLabel.Text = ""

    -- Distance label (jarak ke player)
    local distLabel = Drawing.new("Text")
    distLabel.Size = 10
    distLabel.Font = 1
    distLabel.Color = Color3.fromRGB(180, 220, 255)
    distLabel.Outline = true
    distLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    distLabel.Center = true
    distLabel.Visible = false
    distLabel.Text = ""

    espCache[player] = {boxOutline, nameLabel, hpBarBg, hpBarFill, hpText, invLabel, distLabel}

    local function getHeldItem(plr)
        local char = plr.Character
        if char then
            for _, tool in pairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    return tool.Name
                end
            end
        end
        return nil
    end

    local function buildInvText(itemName)
        if not itemName then return "" end
        return "🖐 " .. itemName
    end

    local lastInvUpdate = 0
    local cachedInvText = ""

    RunService.RenderStepped:Connect(function()
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")

        if espEnabled and char
            and char:FindFirstChild("HumanoidRootPart")
            and char:FindFirstChild("Head")
            and humanoid and humanoid.Health > 0
            and not isWhitelisted(player) then

            local root = char.HumanoidRootPart
            local head = char.Head

            -- Distance limit check
            local myChar2 = LocalPlayer.Character
            local myHRP2  = myChar2 and myChar2:FindFirstChild("HumanoidRootPart")
            if myHRP2 and espMaxDist > 0 then
                local d3 = (root.Position - myHRP2.Position).Magnitude
                if d3 > espMaxDist then
                    boxOutline.Visible = false
                    nameLabel.Visible  = false
                    hpBarBg.Visible    = false
                    hpBarFill.Visible  = false
                    hpText.Visible     = false
                    invLabel.Visible   = false
                    distLabel.Visible  = false
                    return
                end
            end

            -- Apply warna box live
            boxOutline.Color = espBoxColor
            local hrpPos, hrpVis = Camera:WorldToViewportPoint(root.Position)
            local headPos, headVis = Camera:WorldToViewportPoint(head.Position)

            if hrpVis and headVis then
                local height = math.abs(headPos.Y - hrpPos.Y) * 1.6 + (boxPadding * 2)
                local width = height * 0.6
                local boxX = hrpPos.X - width / 2
                local boxY = headPos.Y - boxPadding

                -- Box
                boxOutline.Size = Vector2.new(width, height)
                boxOutline.Position = Vector2.new(boxX, boxY)
                boxOutline.Visible = true

                -- Nama di atas box — hanya DisplayName
                nameLabel.Text = player.DisplayName
                nameLabel.Position = Vector2.new(hrpPos.X, boxY - 16)
                nameLabel.Visible = true

                -- Health bar (di sebelah kiri box, lebar 4px)
                local hpBarW = 4
                local hpBarX = boxX - hpBarW - 3
                local hpRatio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

                hpBarBg.Size = Vector2.new(hpBarW, height)
                hpBarBg.Position = Vector2.new(hpBarX, boxY)
                hpBarBg.Visible = true

                local fillHeight = math.floor(height * hpRatio)
                hpBarFill.Size = Vector2.new(hpBarW, fillHeight)
                hpBarFill.Position = Vector2.new(hpBarX, boxY + (height - fillHeight))

                -- Warna HP: hijau > kuning > merah
                if hpRatio > 0.6 then
                    hpBarFill.Color = Color3.fromRGB(0, 255, 80)
                elseif hpRatio > 0.3 then
                    hpBarFill.Color = Color3.fromRGB(255, 200, 0)
                else
                    hpBarFill.Color = Color3.fromRGB(255, 50, 50)
                end
                hpBarFill.Visible = true

                -- HP text disembunyikan
                hpText.Visible = false

                -- ===== INVENTORY ESP (item yang lagi dipegang) =====
                local now = tick()
                if now - lastInvUpdate >= 0.5 then
                    lastInvUpdate = now
                    local held = getHeldItem(player)
                    cachedInvText = buildInvText(held)
                end
                if cachedInvText ~= "" then
                    invLabel.Text = cachedInvText
                    invLabel.Position = Vector2.new(hrpPos.X, boxY - 28)
                    invLabel.Visible = true
                else
                    invLabel.Visible = false
                end

                -- ===== DISTANCE ESP =====
                local myChar = LocalPlayer.Character
                local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local dist3D = (root.Position - myHRP.Position).Magnitude
                    local distStr = string.format("[%.0fm]", dist3D)
                    distLabel.Text = distStr
                    -- Tampilkan di bawah box
                    distLabel.Position = Vector2.new(hrpPos.X, boxY + height + 14)
                    distLabel.Visible = true
                else
                    distLabel.Visible = false
                end
            else
                boxOutline.Visible = false
                nameLabel.Visible = false
                hpBarBg.Visible = false
                hpBarFill.Visible = false
                hpText.Visible = false
                invLabel.Visible = false
                distLabel.Visible = false
            end
        else
            boxOutline.Visible = false
            nameLabel.Visible = false
            hpBarBg.Visible = false
            hpBarFill.Visible = false
            hpText.Visible = false
            invLabel.Visible = false
            distLabel.Visible = false
        end
    end)
end

-- ESP Toggle Button Handler
espToggleBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled

    if espEnabled then
        espToggleBtn.Text = "●  ESP ON"
        espToggleBtn.TextColor3 = Color3.fromRGB(34, 197, 94)
        espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                createESP(plr)
            end
        end
        Players.PlayerAdded:Connect(function(plr)
            if espEnabled and plr ~= LocalPlayer then
                createESP(plr)
            end
        end)
        Players.PlayerRemoving:Connect(removeESP)
    else
        espToggleBtn.Text = "●  ESP OFF"
        espToggleBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
        espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
        for plr, _ in pairs(espCache) do
            removeESP(plr)
        end
    end
end)

-- ========== PAGE AIMBOT ==========
do
    local function mkRow(parent, yPos, h)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -16, 0, h or 34)
        f.Position = UDim2.new(0, 8, 0, yPos)
        f.BackgroundColor3 = C.card
        f.BorderSizePixel = 0
        f.Parent = parent
        mkCorner(f, 5)
        mkStroke(f, 1, C.border)
        return f
    end
    local function mkRowLabel(row, txt, subTxt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.55, 0, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = C.text
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = row
        if subTxt then
            local s = Instance.new("TextLabel")
            s.Size = UDim2.new(0.55, 0, 1, 0)
            s.Position = UDim2.new(0, 10, 0, 0)
            s.BackgroundTransparency = 1
            s.Text = subTxt
            s.TextColor3 = C.subtext
            s.Font = Enum.Font.Gotham
            s.TextSize = 9
            s.TextXAlignment = Enum.TextXAlignment.Left
            s.Parent = row
        end
    end
    local function mkSectionSep(parent, yPos, txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -16, 0, 18)
        l.Position = UDim2.new(0, 8, 0, yPos)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = C.subtext
        l.Font = Enum.Font.GothamBold
        l.TextSize = 9
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = parent
    end
    local function mkToggle(parent, defaultOn, callback)
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0, 34, 0, 18)
        bg.Position = UDim2.new(1, -42, 0.5, -9)
        bg.BackgroundColor3 = defaultOn and C.accent or C.border
        bg.BorderSizePixel = 0
        bg.Parent = parent
        mkCorner(bg, 9)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.Position = defaultOn and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        knob.Parent = bg
        mkCorner(knob, 6)
        local state = defaultOn
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = bg
        btn.MouseButton1Click:Connect(function()
            state = not state
            bg.BackgroundColor3 = state and C.accent or C.border
            knob.Position = state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
            if callback then callback(state) end
        end)
        return bg
    end
    local function mkPairBtn(parent, label1, label2, active, callback)
        -- active: 1 or 2
        local function makeB(txt, xOff, isActive)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 78, 0, 22)
            b.Position = UDim2.new(1, xOff, 0.5, -11)
            b.BackgroundColor3 = isActive and C.accent or C.card2
            b.Text = txt
            b.TextColor3 = isActive and Color3.fromRGB(255,255,255) or C.subtext
            b.Font = Enum.Font.GothamBold
            b.TextSize = 10
            b.BorderSizePixel = 0
            b.Parent = parent
            mkCorner(b, 5)
            if not isActive then mkStroke(b, 1, C.border) end
            return b
        end
        local b1 = makeB(label1, -162, active == 1)
        local b2 = makeB(label2, -78,  active == 2)
        local function refresh(which)
            b1.BackgroundColor3 = which==1 and C.accent or C.card2
            b1.TextColor3       = which==1 and Color3.fromRGB(255,255,255) or C.subtext
            b2.BackgroundColor3 = which==2 and C.accent or C.card2
            b2.TextColor3       = which==2 and Color3.fromRGB(255,255,255) or C.subtext
        end
        b1.MouseButton1Click:Connect(function() refresh(1) if callback then callback(1) end end)
        b2.MouseButton1Click:Connect(function() refresh(2) if callback then callback(2) end end)
        return b1, b2
    end
    local function mkSlider(parent, yPos, label, minV, maxV, defV, suffix, callback)
        local row = mkRow(parent, yPos, 44)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 0, 20)
        lbl.Position = UDim2.new(0, 10, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.text
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.4, -10, 0, 20)
        valLbl.Position = UDim2.new(0.6, 0, 0, 2)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = defV..suffix
        valLbl.TextColor3 = C.accent2
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = row
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -20, 0, 3)
        track.Position = UDim2.new(0, 10, 0, 32)
        track.BackgroundColor3 = C.border
        track.BorderSizePixel = 0
        track.Parent = row
        mkCorner(track, 2)
        local ratio0 = (defV-minV)/(maxV-minV)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(ratio0, 0, 1, 0)
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        mkCorner(fill, 2)
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0, 10, 0, 10)
        knob.Position = UDim2.new(ratio0, -5, 0.5, -5)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.Text = ""
        knob.BorderSizePixel = 0
        knob.Parent = track
        mkCorner(knob, 5)
        local dragging = false
        knob.MouseButton1Down:Connect(function() dragging = true end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local ap = track.AbsolutePosition
                local as = track.AbsoluteSize
                local r = math.clamp((i.Position.X - ap.X) / as.X, 0, 1)
                local v = math.floor(minV + r*(maxV-minV))
                fill.Size = UDim2.new(r, 0, 1, 0)
                knob.Position = UDim2.new(r, -5, 0.5, -5)
                valLbl.Text = v..suffix
                if callback then callback(v) end
            end
        end)
    end

    -- === UI LAYOUT ===
    local y = 6

    -- Status + enable toggle
    mkSectionSep(pageAimbot, y, "AIMBOT")
    y = y + 20

    local statusRow = mkRow(pageAimbot, y, 34)
    local statusTxt = Instance.new("TextLabel")
    statusTxt.Size = UDim2.new(0.5, 0, 1, 0)
    statusTxt.Position = UDim2.new(0, 10, 0, 0)
    statusTxt.BackgroundTransparency = 1
    statusTxt.Text = "Enable Aimbot"
    statusTxt.TextColor3 = C.text
    statusTxt.Font = Enum.Font.GothamBold
    statusTxt.TextSize = 11
    statusTxt.TextXAlignment = Enum.TextXAlignment.Left
    statusTxt.Parent = statusRow
    aimbotStatusLbl = Instance.new("TextLabel")
    aimbotStatusLbl.Size = UDim2.new(0, 40, 1, 0)
    aimbotStatusLbl.Position = UDim2.new(1, -88, 0, 0)
    aimbotStatusLbl.BackgroundTransparency = 1
    aimbotStatusLbl.Text = "OFF"
    aimbotStatusLbl.TextColor3 = C.red
    aimbotStatusLbl.Font = Enum.Font.GothamBlack
    aimbotStatusLbl.TextSize = 11
    aimbotStatusLbl.TextXAlignment = Enum.TextXAlignment.Right
    aimbotStatusLbl.Parent = statusRow
    mkToggle(statusRow, false, function(s)
        aimbotEnabled = s
        aimbotStatusLbl.Text = s and "ON" or "OFF"
        aimbotStatusLbl.TextColor3 = s and C.green or C.red
        if aimbotFovCircle then aimbotFovCircle.Visible = s end
    end)
    y = y + 40

    -- TARGET (dropdown list)
    mkSectionSep(pageAimbot, y, "TARGET PART")
    y = y + 20
    local targetParts  = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"}
    local targetLabels = {"💀  Head", "🫁  UpperTorso", "🧍  Torso", "⬛  HumanoidRootPart"}
    local targetIdx    = 1

    -- selected display row
    local targetSelRow = mkRow(pageAimbot, y, 28)
    local targetSelLbl = Instance.new("TextLabel")
    targetSelLbl.Size = UDim2.new(0.5, 0, 1, 0)
    targetSelLbl.Position = UDim2.new(0, 10, 0, 0)
    targetSelLbl.BackgroundTransparency = 1
    targetSelLbl.Text = "Target Part"
    targetSelLbl.TextColor3 = C.text
    targetSelLbl.Font = Enum.Font.GothamBold
    targetSelLbl.TextSize = 11
    targetSelLbl.TextXAlignment = Enum.TextXAlignment.Left
    targetSelLbl.Parent = targetSelRow

    local targetValLbl = Instance.new("TextLabel")
    targetValLbl.Size = UDim2.new(0.5, -8, 1, 0)
    targetValLbl.Position = UDim2.new(0.5, 0, 0, 0)
    targetValLbl.BackgroundTransparency = 1
    targetValLbl.Text = targetLabels[targetIdx]
    targetValLbl.TextColor3 = C.accent2
    targetValLbl.Font = Enum.Font.GothamBold
    targetValLbl.TextSize = 10
    targetValLbl.TextXAlignment = Enum.TextXAlignment.Right
    targetValLbl.Parent = targetSelRow
    y = y + 32

    -- build list dengan tabel refresher
    local targetOptBtns = {}
    local function refreshTargetOpts()
        for li, btn in ipairs(targetOptBtns) do
            if targetIdx == li then
                btn.BackgroundColor3 = C.accent
                btn.TextColor3 = Color3.fromRGB(255,255,255)
            else
                btn.BackgroundColor3 = C.card2
                btn.TextColor3 = C.subtext
            end
        end
        targetValLbl.Text = targetLabels[targetIdx]
    end

    for li, lbl in ipairs(targetLabels) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, -16, 0, 24)
        optBtn.Position = UDim2.new(0, 8, 0, y)
        optBtn.BackgroundColor3 = C.card2
        optBtn.TextColor3 = C.subtext
        optBtn.Font = Enum.Font.GothamBold
        optBtn.TextSize = 10
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.Text = "    " .. lbl
        optBtn.BorderSizePixel = 0
        optBtn.Parent = pageAimbot
        mkCorner(optBtn, 4)
        targetOptBtns[li] = optBtn
        local capLi = li
        optBtn.MouseButton1Click:Connect(function()
            targetIdx = capLi
            aimbotTarget = targetParts[capLi]
            refreshTargetOpts()
        end)
        y = y + 26
    end
    refreshTargetOpts()
    y = y + 6

    -- PRIORITY
    local prioRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(prioRow, "Lock Priority", "terdekat ke...")
    mkPairBtn(prioRow, "🎯 Crosshair", "🧍 Player", 1, function(which)
        aimbotPriority = which == 1 and "Crosshair" or "Player"
    end)
    y = y + 40

    -- KEYBIND
    mkSectionSep(pageAimbot, y, "KEYBIND")
    y = y + 20
    local kbRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(kbRow, "Hold Key")
    local kbBtn = Instance.new("TextButton")
    kbBtn.Size = UDim2.new(0, 80, 0, 22)
    kbBtn.Position = UDim2.new(1, -88, 0.5, -11)
    kbBtn.BackgroundColor3 = C.card2
    kbBtn.Text = "[ RMB ]"
    kbBtn.TextColor3 = C.accent2
    kbBtn.Font = Enum.Font.GothamBold
    kbBtn.TextSize = 10
    kbBtn.BorderSizePixel = 0
    kbBtn.Parent = kbRow
    mkCorner(kbBtn, 5)
    mkStroke(kbBtn, 1, C.accent)
    keybindBtnRef = kbBtn

    kbBtn.MouseButton1Click:Connect(function()
        if isBindingKey then return end
        isBindingKey = true
        kbBtn.Text = "[ ... ]"
        kbBtn.TextColor3 = C.yellow
    end)

    -- Listen keybind input
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not isBindingKey then return end
        -- Skip klik kiri (biar dialog tidak langsung nutup)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then return end

        isBindingKey = false

        local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
        local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")

        if un == "MouseButton2" then
            aimbotKeybindType  = "MouseButton"
            aimbotKeybindIsKey = false
            aimbotKeybindCode  = nil
            aimbotKeybind      = Enum.UserInputType.MouseButton2
            aimbotKeybindLabel = "RMB"
        elseif un == "MouseButton3" then
            aimbotKeybindType  = "MouseButton"
            aimbotKeybindIsKey = false
            aimbotKeybindCode  = nil
            aimbotKeybind      = Enum.UserInputType.MouseButton3
            aimbotKeybindLabel = "MMB"
        elseif un == "MouseButton4" or kn == "MouseButton4" then
            aimbotKeybindType  = "MB4"
            aimbotKeybindIsKey = false
            aimbotKeybindCode  = nil
            aimbotKeybindLabel = "MB4"
        elseif un == "MouseButton5" or kn == "MouseButton5" then
            aimbotKeybindType  = "MB5"
            aimbotKeybindIsKey = false
            aimbotKeybindCode  = nil
            aimbotKeybindLabel = "MB5"
        elseif un == "Keyboard" and kn ~= "Unknown" then
            aimbotKeybindType  = "KeyCode"
            aimbotKeybindIsKey = true
            aimbotKeybindCode  = input.KeyCode
            aimbotKeybindLabel = kn
        else
            -- Input tidak dikenal, biarkan binding ulang
            isBindingKey = true
            return
        end

        kbBtn.Text       = "[ " .. aimbotKeybindLabel .. " ]"
        kbBtn.TextColor3 = C.accent2
    end)
    y = y + 40

    -- SLIDERS
    mkSectionSep(pageAimbot, y, "SETTINGS")
    y = y + 20
    mkSlider(pageAimbot, y, "FOV Radius", 20, 400, aimbotFOV, "px", function(v)
        aimbotFOV = v
        if aimbotFovCircle then aimbotFovCircle.Radius = v end
    end)
    y = y + 50
    mkSlider(pageAimbot, y, "Smoothness", 1, 20, aimbotSmooth, "", function(v)
        aimbotSmooth = v
    end)
    y = y + 50
    mkSlider(pageAimbot, y, "Aimbot Max Distance", 50, 1000, aimbotMaxDist, "m", function(v)
        aimbotMaxDist = v
    end)
    y = y + 50
    mkSlider(pageAimbot, y, "ESP Max Distance", 50, 1000, espMaxDist, "m", function(v)
        espMaxDist = v
    end)
    y = y + 50

    -- COLOR PICKERS: FOV circle + ESP box
    mkSectionSep(pageAimbot, y, "WARNA")
    y = y + 20

    -- Helper: buat color preset row
    local colorPresets = {
        {name="Merah",   c=Color3.fromRGB(220,38,38)},
        {name="Putih",   c=Color3.fromRGB(255,255,255)},
        {name="Cyan",    c=Color3.fromRGB(0,210,255)},
        {name="Hijau",   c=Color3.fromRGB(34,197,94)},
        {name="Kuning",  c=Color3.fromRGB(234,179,8)},
        {name="Ungu",    c=Color3.fromRGB(168,85,247)},
    }

    local function mkColorRow(parent, yPos, label, onPick)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 0, 14)
        lbl.Position = UDim2.new(0, 8, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.subtext
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent

        local swatchRow = Instance.new("Frame")
        swatchRow.Size = UDim2.new(1, -16, 0, 22)
        swatchRow.Position = UDim2.new(0, 8, 0, yPos + 16)
        swatchRow.BackgroundTransparency = 1
        swatchRow.BorderSizePixel = 0
        swatchRow.Parent = parent

        local swW = 1 / #colorPresets
        for ci, cp in ipairs(colorPresets) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(swW, -3, 1, 0)
            sw.Position = UDim2.new(swW * (ci-1), 0, 0, 0)
            sw.BackgroundColor3 = cp.c
            sw.Text = ""
            sw.BorderSizePixel = 0
            sw.Parent = swatchRow
            mkCorner(sw, 4)
            local capC = cp.c
            sw.MouseButton1Click:Connect(function()
                onPick(capC)
                -- outline selected
                for _, s in pairs(swatchRow:GetChildren()) do
                    if s:IsA("TextButton") then
                        s.BorderSizePixel = 0
                    end
                end
                sw.BorderSizePixel = 2
            end)
        end
    end

    mkColorRow(pageAimbot, y, "🔴 Warna FOV Circle", function(c)
        fovColor = c
        if aimbotFovCircle then aimbotFovCircle.Color = c end
    end)
    y = y + 44

    mkColorRow(pageAimbot, y, "🟥 Warna ESP Box", function(c)
        espBoxColor = c
    end)
    y = y + 44

    -- PREDICTION
    mkSectionSep(pageAimbot, y, "PREDICTION")
    y = y + 20

    local predRow = mkRow(pageAimbot, y, 34)
    local predLbl = Instance.new("TextLabel")
    predLbl.Size = UDim2.new(0.55, 0, 1, 0)
    predLbl.Position = UDim2.new(0, 10, 0, 0)
    predLbl.BackgroundTransparency = 1
    predLbl.Text = "Enable Prediction"
    predLbl.TextColor3 = C.text
    predLbl.Font = Enum.Font.GothamBold
    predLbl.TextSize = 11
    predLbl.TextXAlignment = Enum.TextXAlignment.Left
    predLbl.Parent = predRow
    mkToggle(predRow, aimbotPrediction, function(s)
        aimbotPrediction = s
    end)
    y = y + 40

    mkSlider(pageAimbot, y, "Prediction Strength", 1, 20, math.floor(predStrength * 100), "%", function(v)
        predStrength = v / 100
    end)
    y = y + 50

    pageAimbot.CanvasSize = UDim2.new(0, 0, 0, y + 50)
end

-- ========== AIMBOT FOV CIRCLE ==========
-- Xeno: GetMouseLocation() kadang include/exclude GUI inset
-- WorldToViewportPoint tidak include inset (pakai viewport murni)
-- GetMouseLocation() di Xeno = screen coords (sudah include inset Y ~36px)
-- Kompensasi: kurangi GuiInset.Y dari GetMouseLocation
local guiInset = game:GetService("GuiService"):GetGuiInset()
local function getMouseViewportPos()
    local raw = UserInputService:GetMouseLocation()
    -- Kurangi inset agar match WorldToViewportPoint
    return Vector2.new(raw.X, raw.Y - guiInset.Y)
end
-- Drawing.Circle: .Position = CENTER lingkaran
-- GetMouseLocation() = viewport coords (sama dengan WorldToViewportPoint)
-- Jadi circle akan tepat mengelilingi crosshair/mouse
aimbotFovCircle = Drawing.new("Circle")
aimbotFovCircle.Thickness  = 1
aimbotFovCircle.Color      = Color3.fromRGB(220, 38, 38)
aimbotFovCircle.Filled     = false
aimbotFovCircle.Visible    = false
aimbotFovCircle.Radius     = aimbotFOV
aimbotFovCircle.Position   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

-- ========== MB4/MB5 MANUAL STATE TRACKER ==========
-- InputBegan/Ended untuk MB4 dan MB5 karena executor map mereka berbeda-beda
UserInputService.InputBegan:Connect(function(input)
    if isBindingKey then return end
    -- Cek nama KeyCode (beberapa executor map MB4/5 sebagai KeyCode)
    local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
    -- Cek nama UserInputType (executor lain pakai custom UserInputType)
    local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")
    if kn == "MouseButton4" or un == "MouseButton4" then
        mb4Held = true
    elseif kn == "MouseButton5" or un == "MouseButton5" then
        mb5Held = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
    local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")
    if kn == "MouseButton4" or un == "MouseButton4" then
        mb4Held = false
    elseif kn == "MouseButton5" or un == "MouseButton5" then
        mb5Held = false
    end
end)

-- ========== KEYBIND HOLD CHECK ==========
local function isAimbotKeyHeld()
    if isBindingKey then return false end
    local t = aimbotKeybindType
    if t == "KeyCode" then
        return aimbotKeybindCode ~= nil and UserInputService:IsKeyDown(aimbotKeybindCode)
    elseif t == "MouseButton" then
        if aimbotKeybind == Enum.UserInputType.MouseButton2 then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif aimbotKeybind == Enum.UserInputType.MouseButton3 then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        end
    elseif t == "MB4" then
        return mb4Held
    elseif t == "MB5" then
        return mb5Held
    end
    return false
end

-- ========== AIMBOT CORE ==========

-- Prediction velocity cache
local function getPredictedPosition(part, player)
    local now        = tick()
    local currentPos = part.Position
    if not velCache[player] then
        velCache[player] = { lastPos = currentPos, lastVel = Vector3.zero, lastTime = now }
        return currentPos
    end
    local cache = velCache[player]
    local dt    = now - cache.lastTime
    if dt > 0 and dt < 0.5 then
        local rawVel  = (currentPos - cache.lastPos) / dt
        cache.lastVel = cache.lastVel:Lerp(rawVel, 0.35)
    end
    cache.lastPos  = currentPos
    cache.lastTime = now
    if not aimbotPrediction then return currentPos end
    return currentPos + cache.lastVel * (predStrength * 0.5)
end

-- Cari target dalam FOV — support dua mode priority
local function getBestTarget()
    -- Crosshair Roblox selalu di tengah viewport
    local mx = Camera.ViewportSize.X / 2
    local my = Camera.ViewportSize.Y / 2
    local bestScore = math.huge
    local bestPart = nil
    local bestPlr  = nil

    -- Untuk mode "Player": ambil posisi karakter kita
    local myChar = LocalPlayer.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isWhitelisted(plr) then
            local char = plr.Character
            if char then
                local hum  = char:FindFirstChildOfClass("Humanoid")
                -- Coba target part yang dipilih, fallback ke HumanoidRootPart
                local part = char:FindFirstChild(aimbotTarget) or char:FindFirstChild("HumanoidRootPart")
                if part and hum and hum.Health > 0 then
                    -- Distance limit check
                    if aimbotMaxDist > 0 and myHRP then
                        local d3 = (part.Position - myHRP.Position).Magnitude
                        if d3 > aimbotMaxDist then continue end
                    end
                    -- WorldToViewportPoint → viewport coords → match GetMouseLocation
                    local sp, vis = Camera:WorldToViewportPoint(part.Position)
                    if vis then
                        -- Cek apakah dalam FOV (selalu diukur dari crosshair)
                        local dScreen = math.sqrt((sp.X - mx)^2 + (sp.Y - my)^2)
                        if dScreen <= aimbotFOV then
                            -- Score berdasarkan priority
                            local score
                            if aimbotPriority == "Crosshair" then
                                -- Terdekat ke crosshair (dalam viewport px)
                                score = dScreen
                            else
                                -- Terdekat ke karakter kita (dalam studs 3D)
                                if myHRP then
                                    score = (part.Position - myHRP.Position).Magnitude
                                else
                                    score = dScreen
                                end
                            end
                            if score < bestScore then
                                bestScore = score
                                bestPart = part
                                bestPlr  = plr
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPart, bestPlr
end

-- Camera mode: rotate kamera ke arah target
local function aimCamera(part, plr)
    local pos  = getPredictedPosition(part, plr)
    local cf   = Camera.CFrame
    local goal = CFrame.new(cf.Position, pos)
    local t    = math.clamp(1 - (aimbotSmooth / 20), 0.05, 1)
    Camera.CFrame = cf:Lerp(goal, t)
end

-- ========== MAIN AIMBOT LOOP ==========
local wasActive = false

RunService.RenderStepped:Connect(function()
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    aimbotFovCircle.Position = Vector2.new(cx, cy)
    aimbotFovCircle.Radius   = aimbotFOV
    aimbotFovCircle.Color    = fovColor
    aimbotFovCircle.Visible  = aimbotEnabled

    if not aimbotEnabled then
        wasActive = false
        return
    end

    aimbotActive = isAimbotKeyHeld()

    if not aimbotActive then
        wasActive = false
        return
    end

    if not wasActive then
        wasActive = true
    end

    local target, targetPlr = getBestTarget()
    if not target then return end

    aimCamera(target, targetPlr)
end)


print("=== MAJESTY ONTOP v17.0 - VALARY THEME ===")
print("Fitur:")
print("- 📦 Inventory Tracker")
print("- ⚙️  Auto MS")
print("- 👁️  ESP + Whitelist | Name kecil | Inv kecil | Dist limit | Box color")
print("- 🚀 Teleport")
print("- 🎯 AIMBOT: Camera only | Target list | Dist limit | FOV/ESP color | No FreeAim")
print("=========================================")
