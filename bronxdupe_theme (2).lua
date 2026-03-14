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
local espShowItem    = true  -- selalu true, item held ikut ESP otomatis
local ESP_INTERVAL   = 0.05    -- throttle ~20fps (lebih smooth)
local _espAccum      = 0

-- ========== AIMBOT VARIABLES ==========
local aimbotEnabled      = false
local aimbotMode         = "Camera"   -- "Camera" | "FreeAim"
local aimbotFOV          = 250
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
local predStrength       = 0.15      -- detik ke depan yang diprediksi (0.0 - 1.0)
local velCache           = {}        -- {plr = {lastPos, lastVel, lastTime}}

-- Target Priority: "Crosshair" = terdekat ke crosshair/mouse, "Distance" = terdekat ke karakter kita
local aimbotPriority     = "Crosshair"

-- Distance limits
local aimbotMaxDist      = 100   -- studs
local espMaxDist         = 100   -- studs

-- ========== VEHICLE FLY VARIABLES ==========
local vFlyEnabled = false
local vFlySpeed   = 60
local vFlyConn    = nil
local vFlyUp      = false
local vFlyDown    = false

-- Warna FOV circle, ESP box, nama, dan inventory label
local fovColor           = Color3.fromRGB(220, 38, 38)
local espBoxColor        = Color3.fromRGB(255, 50, 50)
local espNameColor       = Color3.fromRGB(255, 255, 255)
-- espItemColor dideklarasi di ESP Variables section di atas
-- MB4/MB5 manual state (karena IsMouseButtonPressed tidak support)
local mb4Held = false
local mb5Held = false

-- ========== MINIMIZE KEYBIND VARIABLES ==========
-- Keybind tersembunyi (tidak ada UI di layar) untuk toggle minimize/restore GUI
-- Default: RightShift — bisa diganti dari tab Aimbot → MINIMIZE KEYBIND
local minKeyType      = "KeyCode"                -- "KeyCode" | "MouseButton" | "MB4" | "MB5"
local minKeyCode      = Enum.KeyCode.RightShift  -- default key
local minKeyMBtn      = nil                      -- jika pakai mouse button
local minKeyLabel     = "RShift"                 -- label tampil di tombol setting
local isBindingMin    = false                    -- sedang dalam mode binding minimize
local minKeybindBtnRef = nil                     -- referensi tombol di UI settings

-- Tunggu character spawn
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ========== GUI MAJESTY - TEMA BRONXDUPE STYLE ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY ONTOP"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Xeno: coba gethui() → CoreGui → PlayerGui (fallback)
local guiParentOk = false
if not guiParentOk then pcall(function() screenGui.Parent = gethui(); guiParentOk = true end) end
if not guiParentOk then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiParentOk = true end) end
if not guiParentOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ===== WARNA TEMA BRONXDUPE =====
local C = {
    bg       = Color3.fromRGB(15, 15, 15),      -- hitam pekat utama (lebih gelap dari MJS)
    topbar   = Color3.fromRGB(20, 20, 20),      -- titlebar sedikit lebih terang
    panel    = Color3.fromRGB(17, 17, 17),      -- area konten
    sidebar  = Color3.fromRGB(13, 13, 13),      -- sidebar kiri gelap
    card     = Color3.fromRGB(25, 25, 25),      -- card/row item
    card2    = Color3.fromRGB(22, 22, 22),      -- card lebih gelap
    accent   = Color3.fromRGB(220, 38, 38),     -- merah utama
    accent2  = Color3.fromRGB(239, 68, 68),     -- merah terang
    green    = Color3.fromRGB(34, 197, 94),
    red      = Color3.fromRGB(220, 38, 38),
    yellow   = Color3.fromRGB(234, 179, 8),
    text     = Color3.fromRGB(220, 220, 220),   -- putih agak redup
    subtext  = Color3.fromRGB(100, 100, 100),   -- abu-abu
    border   = Color3.fromRGB(35, 35, 35),      -- border tipis gelap
    search   = Color3.fromRGB(22, 22, 22),      -- search bar bg
    navbg    = Color3.fromRGB(13, 13, 13),      -- sidebar nav (kiri, seperti BronxDupe)
    sideAccent = Color3.fromRGB(180, 30, 30),   -- merah gelap untuk sidebar aktif
    toggleOn = Color3.fromRGB(220, 38, 38),     -- warna toggle ON (merah)
    toggleOff= Color3.fromRGB(45, 45, 45),      -- warna toggle OFF (abu)
}

local function mkCorner(p, r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 8) c.Parent=p end
local function mkStroke(p, t, col) local s=Instance.new("UIStroke") s.Thickness=t or 1 s.Color=col or C.border s.Parent=p end

-- ===== MAIN WINDOW (BronxDupe: lebih lebar, ada sidebar kiri) =====
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 560, 0, 400)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -200)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mkCorner(mainFrame, 6)
mkStroke(mainFrame, 1, C.border)

-- Garis merah di bagian atas (BronxDupe accent bar atas)
local topAccentBar = Instance.new("Frame")
topAccentBar.Size = UDim2.new(1, 0, 0, 2)
topAccentBar.Position = UDim2.new(0, 0, 0, 0)
topAccentBar.BackgroundColor3 = C.accent
topAccentBar.BorderSizePixel = 0
topAccentBar.ZIndex = 5
topAccentBar.Parent = mainFrame

-- ===== TITLE BAR (BronxDupe style - flat gelap) =====
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.Position = UDim2.new(0, 0, 0, 2)
titleBar.BackgroundColor3 = C.topbar
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

-- Garis pemisah bawah titlebar
local tbLine = Instance.new("Frame")
tbLine.Size = UDim2.new(1, 0, 0, 1)
tbLine.Position = UDim2.new(0, 0, 1, -1)
tbLine.BackgroundColor3 = C.border
tbLine.BorderSizePixel = 0
tbLine.Parent = titleBar

-- Title text kiri: "BronxDupe" style dengan teks merah
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = '<font color="rgb(220,38,38)">Majesty Store</font>  |  <font color="rgb(140,140,140)">https://discord.gg/VPeZbhCz8M</font>'
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 11
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
versionLabel.TextSize = 10
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = titleBar

-- Tombol − minimize dan × close (kanan titlebar, gaya BronxDupe - kotak kecil)
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 20, 0, 20)
minBtn.Position = UDim2.new(1, -46, 0.5, -10)
minBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
minBtn.Text = "−"
minBtn.TextColor3 = C.text
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 13
minBtn.BorderSizePixel = 0
minBtn.Parent = titleBar
mkCorner(minBtn, 3)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(1, -24, 0.5, -10)
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
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,560,0,36)}):Play()
    else
        -- Restore: tween dulu sampai selesai, baru tampilkan konten
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,560,0,400)}):Play()
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

-- ========== FUNGSI MINIMIZE TERSEMBUNYI ==========
-- Dipanggil dari keybind — identik dengan tombol −, tanpa UI apapun di layar
local function doMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        task.spawn(function()
            task.wait(0.05)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v ~= titleBar and v:IsA("GuiObject") then
                    v.Visible = false
                end
            end
        end)
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,560,0,36)}):Play()
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,560,0,400)}):Play()
        task.spawn(function()
            task.wait(0.18)
            for _, v in pairs(mainFrame:GetChildren()) do
                if v:IsA("GuiObject") then
                    v.Visible = true
                end
            end
        end)
    end
end

-- ========== LISTENER KEYBIND MINIMIZE ==========
-- Cek setiap InputBegan apakah cocok dengan keybind minimize
UserInputService.InputBegan:Connect(function(input, gpe)
    -- Jangan proses kalau sedang binding key (aimbot atau minimize)
    if isBindingKey or isBindingMin then return end
    -- Jangan intercept saat user ngetik di TextBox
    if gpe then return end

    local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
    local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")

    local triggered = false
    if minKeyType == "KeyCode" then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == minKeyCode then
            triggered = true
        end
    elseif minKeyType == "MouseButton" then
        if minKeyMBtn ~= nil and input.UserInputType == minKeyMBtn then
            triggered = true
        end
    elseif minKeyType == "MB4" then
        if kn == "MouseButton4" or un == "MouseButton4" then triggered = true end
    elseif minKeyType == "MB5" then
        if kn == "MouseButton5" or un == "MouseButton5" then triggered = true end
    end

    if triggered then
        doMinimize()
    end
end)
-- ===== SIDEBAR KIRI (BronxDupe style - vertikal, narrow) =====
local sidebarNav = Instance.new("Frame")
sidebarNav.Size = UDim2.new(0, 110, 1, -36)
sidebarNav.Position = UDim2.new(0, 0, 0, 37)
sidebarNav.BackgroundColor3 = C.navbg
sidebarNav.BorderSizePixel = 0
sidebarNav.Parent = mainFrame

-- Garis pembatas kanan sidebar
local sidebarLine = Instance.new("Frame")
sidebarLine.Size = UDim2.new(0, 1, 1, 0)
sidebarLine.Position = UDim2.new(1, -1, 0, 0)
sidebarLine.BackgroundColor3 = C.accent
sidebarLine.BackgroundTransparency = 0.6
sidebarLine.BorderSizePixel = 0
sidebarLine.Parent = sidebarNav

-- ===== CONTENT AREA (di kanan sidebar) =====
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -110, 1, -37)
contentArea.Position = UDim2.new(0, 110, 0, 37)
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

-- ========== FUNGSI ESP (harus didefinisikan sebelum UI pages) ==========
local function removeESP(player)
    if espCache[player] then
        for _, obj in pairs(espCache[player]) do
            pcall(function() obj:Remove() end)
        end
        espCache[player] = nil
    end
end

local function createESP(player)
    removeESP(player)

    local boxOutline = Drawing.new("Square")
    boxOutline.Thickness = 1
    boxOutline.Color = espBoxColor
    boxOutline.Filled = false
    boxOutline.Visible = false

    local nameLabel = Drawing.new("Text")
    nameLabel.Text = player.Name
    nameLabel.Size = 10
    nameLabel.Font = 1
    nameLabel.Color = espNameColor
    nameLabel.Outline = true
    nameLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameLabel.Center = true
    nameLabel.Visible = false

    local hpBarBg = Drawing.new("Square")
    hpBarBg.Thickness = 1
    hpBarBg.Color = Color3.fromRGB(30, 30, 30)
    hpBarBg.Filled = true
    hpBarBg.Visible = false

    local hpBarFill = Drawing.new("Square")
    hpBarFill.Thickness = 1
    hpBarFill.Color = Color3.fromRGB(0, 255, 80)
    hpBarFill.Filled = true
    hpBarFill.Visible = false

    local distLabel = Drawing.new("Text")
    distLabel.Size = 10
    distLabel.Font = 1
    distLabel.Color = Color3.fromRGB(180, 220, 255)
    distLabel.Outline = true
    distLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    distLabel.Center = true
    distLabel.Visible = false
    distLabel.Text = ""

    local itemLabel = Drawing.new("Text")
    itemLabel.Size = 10
    itemLabel.Font = 1
    itemLabel.Color = espItemColor
    itemLabel.Outline = true
    itemLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    itemLabel.Center = true
    itemLabel.Visible = false
    itemLabel.Text = ""

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
    {name = "NPC Marshmellow", x = 510.1238, y = 3.5872, z = 596.9278, icon = "🍡"},
    {name = "Gunstore Tier", x = 1169.678955078125, y = 3.362133026123047, z = 139.321533203125, icon = "🔫"},
    {name = "Dealership", x = 731.5349731445312, y = 3.7265229225158669, z = 409.34637451171875, icon = "🚗"},
    {name = "Gunstore Mid", x = 218.72975158691406, y = 3.729841709136963, z = -156.140625, icon = "🔫"},
    {name = "Gunstore New", x = -453.7384948730469, y = 3.7371323108673096, z = 343.8177490234375, icon = "🔫"},
}
local tpStatusValue = nil
local tpLoopValue = nil

-- ========== FUNGSI TELEPORT V3 - LOADCHARACTER METHOD ==========
-- Metode: simpan target, paksa respawn, set posisi saat spawn
-- ========== SAFE TELEPORT SYSTEM ==========
-- Teknik: stepping bertahap + velocity reset + no-fall damage
-- Tidak pakai humanoid.Health = 0 (mati), tidak langsung lompat jauh (kick)

local pendingTP = nil

local function onCharacterAdded(newChar)
    if pendingTP then
        local target = pendingTP
        pendingTP = nil
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            task.wait(0.5)
            hrp.CFrame = target
        end
    end
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ========== TELEPORT AMAN - STEPPING METHOD ==========
-- Root cause fix:
--   JANGAN pakai PlatformStand=true  → mengunci karakter di tempat
--   JANGAN pakai ChangeState(Physics) → server reject CFrame move
--   GUNAKAN: set CFrame langsung berkali-kali dengan task.wait kecil
--            + zero velocity tiap step agar tidak terpelanting
--            + health guard via pcall (tidak blokir movement)

local _tpBusy = false

local function doTeleport(targetCFrame)
    if _tpBusy then return false end
    _tpBusy = true

    local char = LocalPlayer.Character
    if not char then _tpBusy = false; return false end

    local hrp      = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then _tpBusy = false; return false end

    local startPos = hrp.Position
    local endPos   = targetCFrame.Position
    local dist     = (endPos - startPos).Magnitude

    -- Guard health supaya tidak mati saat landing / jatuh
    -- Cara: simpan health max, restore setelah TP
    local maxHp = humanoid.MaxHealth
    local healthConn
    healthConn = humanoid.HealthChanged:Connect(function()
        pcall(function()
            if humanoid and humanoid.Parent then
                humanoid.Health = maxHp
            end
        end)
    end)

    -- Helper: set posisi 1 kali, zero velocity, tunggu konfirmasi
    local function stepTo(cf)
        -- Zero velocity SEBELUM pindah agar physics tidak drag balik
        pcall(function() hrp.AssemblyLinearVelocity  = Vector3.zero end)
        pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end)
        hrp.CFrame = cf
        -- Zero velocity SESUDAH pindah supaya tidak langsung jatuh
        pcall(function() hrp.AssemblyLinearVelocity  = Vector3.zero end)
        pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end)
    end

    if dist <= 100 then
        -- ── DEKAT: 1 lompatan langsung ──
        stepTo(targetCFrame)
        task.wait(0.05)
        stepTo(targetCFrame)   -- set 2x untuk konfirmasi

    elseif dist <= 1000 then
        -- ── MENENGAH: potong jadi step ~80 studs ──
        local steps = math.ceil(dist / 80)
        for i = 1, steps do
            local t      = i / steps
            local wPos   = startPos:Lerp(endPos, t)
            -- Angkat 3 studs agar tidak nyangkut geometri
            local liftY  = (i < steps) and 3 or 0
            local cf     = CFrame.new(wPos + Vector3.new(0, liftY, 0))
            stepTo(cf)
            task.wait(0.055)
        end
        -- Pendaratan tepat
        stepTo(targetCFrame)
        task.wait(0.05)
        stepTo(targetCFrame)

    else
        -- ── JAUH: 8 waypoint merata ──
        local WP = 8
        for i = 1, WP do
            local t     = i / WP
            local wPos  = startPos:Lerp(endPos, t)
            local liftY = (i < WP) and 4 or 0
            stepTo(CFrame.new(wPos + Vector3.new(0, liftY, 0)))
            task.wait(0.06)
        end
        stepTo(targetCFrame)
        task.wait(0.05)
        stepTo(targetCFrame)
    end

    -- Tunggu sebentar lalu cabut health guard
    task.wait(0.3)
    healthConn:Disconnect()
    -- Pulihkan health normal
    pcall(function()
        if humanoid and humanoid.Parent then
            humanoid.Health = maxHp
        end
    end)

    _tpBusy = false
    return true
end

-- Wrapper dengan update status label
local function safeTeleport(targetCFrame, statusLabel)
    if statusLabel then
        statusLabel.Text      = "TELEPORTING..."
        statusLabel.TextColor3 = Color3.fromRGB(234, 179, 8)
    end
    task.spawn(function()
        local ok = doTeleport(targetCFrame)
        if statusLabel then
            if ok then
                statusLabel.Text      = "ARRIVED ✓"
                statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
                task.wait(2)
                statusLabel.Text      = "STANDBY"
                statusLabel.TextColor3 = Color3.fromRGB(234, 179, 8)
            else
                statusLabel.Text      = "FAILED"
                statusLabel.TextColor3 = Color3.fromRGB(220, 38, 38)
            end
        end
    end)
end

-- ===== HELPER: Section Title (BronxDupe style) =====
local function sectionTitle(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(160, 160, 160)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    -- garis bawah tipis
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -20, 0, 1)
    line.Position = UDim2.new(0, 10, 0, yPos + 21)
    line.BackgroundColor3 = C.border
    line.BorderSizePixel = 0
    line.Parent = parent
    return lbl
end

local function makeCard(parent, yPos, h)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -16, 0, h or 44)
    f.Position = UDim2.new(0, 8, 0, yPos)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    f.BorderSizePixel = 0
    f.Parent = parent
    mkCorner(f, 4)
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

-- refs untuk auto sell loop (diisi saat pageAuto do block berjalan)
local sellStatusLbl_ref = nil
local sellCountLbl_ref  = nil
local sellToggleBtn_ref = nil

-- ===== PAGE 2: AUTO MS (BronxDupe "Main" tab) =====
do
    -- ── BronxDupe style: dua kolom header "Local Player" dan "Auto Farming" ──
    -- Kolom kiri: Local Player options
    local colLeft = Instance.new("Frame")
    colLeft.Size = UDim2.new(0.5, -6, 1, 0)
    colLeft.Position = UDim2.new(0, 4, 0, 0)
    colLeft.BackgroundTransparency = 1
    colLeft.BorderSizePixel = 0
    colLeft.Parent = pageAuto

    -- Kolom kanan: Auto Farming options
    local colRight = Instance.new("Frame")
    colRight.Size = UDim2.new(0.5, -6, 1, 0)
    colRight.Position = UDim2.new(0.5, 2, 0, 0)
    colRight.BackgroundTransparency = 1
    colRight.BorderSizePixel = 0
    colRight.Parent = pageAuto

    -- Garis pemisah tengah
    local colDivider = Instance.new("Frame")
    colDivider.Size = UDim2.new(0, 1, 1, -10)
    colDivider.Position = UDim2.new(0.5, -1, 0, 5)
    colDivider.BackgroundColor3 = C.border
    colDivider.BorderSizePixel = 0
    colDivider.Parent = pageAuto

    -- ── HEADER KOLOM KIRI: "Local Player" ──
    local leftHeader = Instance.new("TextLabel")
    leftHeader.Size = UDim2.new(1, -8, 0, 24)
    leftHeader.Position = UDim2.new(0, 4, 0, 6)
    leftHeader.BackgroundTransparency = 1
    leftHeader.Text = "Local Player"
    leftHeader.TextColor3 = C.text
    leftHeader.Font = Enum.Font.GothamBold
    leftHeader.TextSize = 12
    leftHeader.TextXAlignment = Enum.TextXAlignment.Left
    leftHeader.Parent = colLeft

    -- ── HEADER KOLOM KANAN: "Auto Farming" ──
    local rightHeader = Instance.new("TextLabel")
    rightHeader.Size = UDim2.new(1, -8, 0, 24)
    rightHeader.Position = UDim2.new(0, 4, 0, 6)
    rightHeader.BackgroundTransparency = 1
    rightHeader.Text = "Auto Farming"
    rightHeader.TextColor3 = C.text
    rightHeader.Font = Enum.Font.GothamBold
    rightHeader.TextSize = 12
    rightHeader.TextXAlignment = Enum.TextXAlignment.Left
    rightHeader.Parent = colRight

    -- Helper buat row toggle BronxDupe di kolom tertentu
    local function mkColToggleRow(col, yPos, labelText, defaultOn, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 28)
        row.Position = UDim2.new(0, 4, 0, yPos)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Parent = col
        -- Label
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -48, 1, 0)
        lbl.Position = UDim2.new(0, 2, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = C.text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        -- Toggle BronxDupe style (pill merah)
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0, 36, 0, 18)
        bg.Position = UDim2.new(1, -40, 0.5, -9)
        bg.BackgroundColor3 = defaultOn and C.toggleOn or C.toggleOff
        bg.BorderSizePixel = 0
        bg.Parent = row
        mkCorner(bg, 9)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 13, 0, 13)
        knob.Position = defaultOn and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,2.5,0.5,-6.5)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        knob.Parent = bg
        mkCorner(knob, 7)
        local state = defaultOn
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = bg
        btn.MouseButton1Click:Connect(function()
            state = not state
            TweenService:Create(bg, TweenInfo.new(0.1), {BackgroundColor3 = state and C.toggleOn or C.toggleOff}):Play()
            TweenService:Create(knob, TweenInfo.new(0.1), {Position = state and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,2.5,0.5,-6.5)}):Play()
            if callback then callback(state) end
        end)
        return bg, state
    end

    -- Helper buat input slider/amount di kolom
    local function mkColAmountRow(col, yPos, labelText, defaultVal)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 28)
        row.Position = UDim2.new(0, 4, 0, yPos)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Parent = col
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.65, 0, 1, 0)
        lbl.Position = UDim2.new(0, 2, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = C.text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.35, -4, 1, 0)
        valLbl.Position = UDim2.new(0.65, 0, 0, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(defaultVal)
        valLbl.TextColor3 = C.subtext
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = row
        return valLbl
    end

    -- ── KOLOM KIRI: Local Player features (BronxDupe style) ──
    mkColToggleRow(colLeft, 36, "Instant Interact",  true,  function() end)
    mkColToggleRow(colLeft, 68, "Infinite Stamina",  true,  function() end)
    mkColToggleRow(colLeft, 100,"Infinite Zoom",     false, function() end)
    mkColToggleRow(colLeft, 132,"Hide Name",         false, function() end)
    mkColToggleRow(colLeft, 164,"No Clip",           false, function() end)
    mkColToggleRow(colLeft, 196,"Speed",             false, function() end)
    mkColAmountRow(colLeft, 228,"Speed Amount",      30)

    -- Divider di kolom kiri
    local divL = Instance.new("Frame")
    divL.Size = UDim2.new(1, -8, 0, 1)
    divL.Position = UDim2.new(0, 4, 0, 262)
    divL.BackgroundColor3 = C.border
    divL.BorderSizePixel = 0
    divL.Parent = colLeft

    mkColToggleRow(colLeft, 268,"Spin Bot",          false, function() end)
    mkColAmountRow(colLeft, 300,"Spin Speed Amount", 25)

    local divL2 = Instance.new("Frame")
    divL2.Size = UDim2.new(1, -8, 0, 1)
    divL2.Position = UDim2.new(0, 4, 0, 334)
    divL2.BackgroundColor3 = C.border
    divL2.BorderSizePixel = 0
    divL2.Parent = colLeft

    mkColToggleRow(colLeft, 340,"Hitbox Expander",   false, function() end)
    mkColAmountRow(colLeft, 372,"Hitbox Amount",     10)

    -- ── KOLOM KANAN: Auto Farming features ──
    -- Teleport Method dropdown style
    local tpMethodLbl = Instance.new("TextLabel")
    tpMethodLbl.Size = UDim2.new(1, -8, 0, 18)
    tpMethodLbl.Position = UDim2.new(0, 4, 0, 36)
    tpMethodLbl.BackgroundTransparency = 1
    tpMethodLbl.Text = "Teleport Method"
    tpMethodLbl.TextColor3 = C.text
    tpMethodLbl.Font = Enum.Font.Gotham
    tpMethodLbl.TextSize = 11
    tpMethodLbl.TextXAlignment = Enum.TextXAlignment.Left
    tpMethodLbl.Parent = colRight

    -- Metode teleport yang tersedia
    local tpMethods = {"Instant", "Step (Aman)", "Waypoint"}
    local tpMethodIdx = 2   -- default: Step (Aman)

    local tpDropdown = Instance.new("TextButton")
    tpDropdown.Size = UDim2.new(1, -8, 0, 22)
    tpDropdown.Position = UDim2.new(0, 4, 0, 58)
    tpDropdown.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    tpDropdown.Text = tpMethods[tpMethodIdx] .. "  ▼"
    tpDropdown.TextColor3 = C.text
    tpDropdown.Font = Enum.Font.Gotham
    tpDropdown.TextSize = 11
    tpDropdown.TextXAlignment = Enum.TextXAlignment.Left
    tpDropdown.BorderSizePixel = 0
    tpDropdown.Parent = colRight
    mkCorner(tpDropdown, 4)
    mkStroke(tpDropdown, 1, C.border)
    local tpPad = Instance.new("UIPadding")
    tpPad.PaddingLeft = UDim.new(0, 8)
    tpPad.Parent = tpDropdown

    -- Dropdown popup
    local tpDropFrame = Instance.new("Frame")
    tpDropFrame.Size = UDim2.new(1, -8, 0, #tpMethods * 26)
    tpDropFrame.Position = UDim2.new(0, 4, 0, 82)
    tpDropFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    tpDropFrame.BorderSizePixel = 0
    tpDropFrame.ZIndex = 10
    tpDropFrame.Visible = false
    tpDropFrame.Parent = colRight
    mkCorner(tpDropFrame, 4)
    mkStroke(tpDropFrame, 1, C.accent)

    for mi, mName in ipairs(tpMethods) do
        local mBtn = Instance.new("TextButton")
        mBtn.Size = UDim2.new(1, 0, 0, 26)
        mBtn.Position = UDim2.new(0, 0, 0, (mi-1)*26)
        mBtn.BackgroundTransparency = 1
        mBtn.Text = mName
        mBtn.TextColor3 = mi == tpMethodIdx and C.accent or C.text
        mBtn.Font = Enum.Font.GothamBold
        mBtn.TextSize = 10
        mBtn.ZIndex = 11
        mBtn.BorderSizePixel = 0
        mBtn.Parent = tpDropFrame
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 8)
        pad.Parent = mBtn
        local capIdx = mi
        mBtn.MouseButton1Click:Connect(function()
            tpMethodIdx = capIdx
            tpDropdown.Text = tpMethods[capIdx] .. "  ▼"
            tpDropFrame.Visible = false
            -- Update warna semua option
            for _, ch in pairs(tpDropFrame:GetChildren()) do
                if ch:IsA("TextButton") then
                    ch.TextColor3 = C.text
                end
            end
            mBtn.TextColor3 = C.accent
        end)
    end

    tpDropdown.MouseButton1Click:Connect(function()
        tpDropFrame.Visible = not tpDropFrame.Visible
    end)

    -- Divider
    local divR0 = Instance.new("Frame")
    divR0.Size = UDim2.new(1, -8, 0, 1)
    divR0.Position = UDim2.new(0, 4, 0, 88)
    divR0.BackgroundColor3 = C.border
    divR0.BorderSizePixel = 0
    divR0.Parent = colRight

    mkColToggleRow(colRight, 94,  "Auto Farm Boxes",        false, function() end)
    mkColToggleRow(colRight, 126, "Auto Farm Chips",        false, function() end)
    mkColToggleRow(colRight, 158, "Auto Farm Cards",        false, function() end)
    mkColToggleRow(colRight, 190, "Auto Farm Marshmallows", false, function() end)
    mkColAmountRow(colRight, 222, "Marshmallow Amount",     10)

    -- Divider
    local divR1 = Instance.new("Frame")
    divR1.Size = UDim2.new(1, -8, 0, 1)
    divR1.Position = UDim2.new(0, 4, 0, 256)
    divR1.BackgroundColor3 = C.border
    divR1.BorderSizePixel = 0
    divR1.Parent = colRight

    -- Webhook URL input
    local webhookLbl = Instance.new("TextLabel")
    webhookLbl.Size = UDim2.new(1, -8, 0, 16)
    webhookLbl.Position = UDim2.new(0, 4, 0, 262)
    webhookLbl.BackgroundTransparency = 1
    webhookLbl.Text = "Webhook URL"
    webhookLbl.TextColor3 = C.text
    webhookLbl.Font = Enum.Font.Gotham
    webhookLbl.TextSize = 11
    webhookLbl.TextXAlignment = Enum.TextXAlignment.Left
    webhookLbl.Parent = colRight

    local webhookBox = Instance.new("TextBox")
    webhookBox.Size = UDim2.new(1, -8, 0, 22)
    webhookBox.Position = UDim2.new(0, 4, 0, 282)
    webhookBox.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    webhookBox.PlaceholderText = "Type here..."
    webhookBox.PlaceholderColor3 = C.subtext
    webhookBox.Text = ""
    webhookBox.TextColor3 = C.text
    webhookBox.Font = Enum.Font.Gotham
    webhookBox.TextSize = 10
    webhookBox.TextXAlignment = Enum.TextXAlignment.Left
    webhookBox.BorderSizePixel = 0
    webhookBox.ClearTextOnFocus = false
    webhookBox.Parent = colRight
    mkCorner(webhookBox, 4)
    mkStroke(webhookBox, 1, C.border)
    local whPad = Instance.new("UIPadding")
    whPad.PaddingLeft = UDim.new(0, 6)
    whPad.Parent = webhookBox

    mkColAmountRow(colRight, 312, "Alert Distance", 50)

    -- Divider
    local divR2 = Instance.new("Frame")
    divR2.Size = UDim2.new(1, -8, 0, 1)
    divR2.Position = UDim2.new(0, 4, 0, 346)
    divR2.BackgroundColor3 = C.border
    divR2.BorderSizePixel = 0
    divR2.Parent = colRight

    mkColToggleRow(colRight, 352, "Enable Proximity Alerts", false, function() end)
    mkColToggleRow(colRight, 384, "Enable Death Alerts",     false, function() end)
    mkColToggleRow(colRight, 416, "Anti AFK",                false, function() end)

    -- Set canvas height untuk page auto (isi original di bawah ini via scroll)
    pageAuto.CanvasSize = UDim2.new(0, 0, 0, 460)

    -- ── STATUS SECTION (bawah, full width, original auto MS) ──
    sectionTitle(pageAuto, "AUTO MARSHMALLOW STATUS", 458)

    -- Status card
    local statCard = makeCard(pageAuto, 484, 44)
    makeLabel(statCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    statusValue = makeLabel(statCard, "OFF", 90, 0, 200, 44, 16, C.red, Enum.Font.GothamBlack)

    -- Phase card
    local phCard = makeCard(pageAuto, 534, 44)
    makeLabel(phCard, "PHASE", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    phaseValue = makeLabel(phCard, "Water", 90, 0, 200, 44, 16, Color3.fromRGB(56,189,248), Enum.Font.GothamBlack)

    -- Timer card
    local tmCard = makeCard(pageAuto, 584, 44)
    makeLabel(tmCard, "TIME", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    timerValue = makeLabel(tmCard, "0s", 90, 0, 200, 44, 16, C.yellow, Enum.Font.GothamBlack)

    -- Info card
    local infoCard = makeCard(pageAuto, 634, 30)
    makeLabel(infoCard, "⏱  Delay 1s antara Sugar → Gelatin", 10, 0, 300, 30, 11, C.subtext, Enum.Font.Gotham)

    -- START button
    startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0.47, -10, 0, 38)
    startBtn.Position = UDim2.new(0, 10, 0, 674)
    startBtn.BackgroundColor3 = C.green
    startBtn.Text = "▶  START"
    startBtn.TextColor3 = Color3.fromRGB(255,255,255)
    startBtn.Font = Enum.Font.GothamBlack
    startBtn.TextSize = 14
    startBtn.BorderSizePixel = 0
    startBtn.Parent = pageAuto
    mkCorner(startBtn, 5)

    -- STOP button
    stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.47, -10, 0, 38)
    stopBtn.Position = UDim2.new(0.5, 5, 0, 674)
    stopBtn.BackgroundColor3 = C.red
    stopBtn.Text = "■  STOP"
    stopBtn.TextColor3 = Color3.fromRGB(255,255,255)
    stopBtn.Font = Enum.Font.GothamBlack
    stopBtn.TextSize = 14
    stopBtn.BorderSizePixel = 0
    stopBtn.Parent = pageAuto
    mkCorner(stopBtn, 5)

    local hint = makeLabel(pageAuto, "PageUp = toggle start/stop", 10, 722, 300, 20, 10, C.subtext, Enum.Font.Gotham)

    -- ===== INVENTORY TRACKER (di dalam Auto MS) =====
    sectionTitle(pageAuto, "INVENTORY TRACKER", 752)

    local invItems = {
        {name="Water",      icon="💧", color=Color3.fromRGB(56,189,248),  countColor=Color3.fromRGB(56,189,248)},
        {name="Gelatin",    icon="🍮", color=Color3.fromRGB(251,146,60),  countColor=Color3.fromRGB(251,146,60)},
        {name="Sugar Block",icon="🧊", color=Color3.fromRGB(192,132,252), countColor=Color3.fromRGB(192,132,252)},
        {name="Empty Bag",  icon="👜", color=Color3.fromRGB(74,222,128),  countColor=Color3.fromRGB(74,222,128)},
    }

    local invCountLabels = {}
    for i, item in ipairs(invItems) do
        local card = makeCard(pageAuto, 780 + (i-1)*54, 44)

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
        invCountLabels[#invCountLabels+1] = cnt
    end

    waterCount   = invCountLabels[1]
    gelatinCount = invCountLabels[2]
    sugarCount   = invCountLabels[3]
    bagCount     = invCountLabels[4]


    -- ===== AUTO SELL MARSHMELLOW (di dalam Auto MS) =====
    sectionTitle(pageAuto, "AUTO SELL MARSHMELLOW", 1072)

    -- Toggle button
    local sellToggleBtn = Instance.new("TextButton")
    sellToggleBtn.Name = "SellToggleBtn"
    sellToggleBtn.Size = UDim2.new(1, -20, 0, 38)
    sellToggleBtn.Position = UDim2.new(0, 10, 0, 1098)
    sellToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
    sellToggleBtn.Text = "💰  AUTO SELL : OFF"
    sellToggleBtn.TextColor3 = C.red
    sellToggleBtn.Font = Enum.Font.GothamBlack
    sellToggleBtn.TextSize = 13
    sellToggleBtn.BorderSizePixel = 0
    sellToggleBtn.Parent = pageAuto
    mkCorner(sellToggleBtn, 6)
    mkStroke(sellToggleBtn, 1, C.red)

    -- Status sell
    local sellStatCard = makeCard(pageAuto, 1146, 44)
    makeLabel(sellStatCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    local sellStatusLbl = makeLabel(sellStatCard, "OFF", 90, 0, 200, 44, 14, C.red, Enum.Font.GothamBlack)

    -- Sold count
    local sellCountCard = makeCard(pageAuto, 1198, 44)
    makeLabel(sellCountCard, "TERJUAL", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    local sellCountLbl = makeLabel(sellCountCard, "0", 90, 0, 200, 44, 14, C.yellow, Enum.Font.GothamBlack)

    -- Marshmellow type info
    local msTypeCard = makeCard(pageAuto, 1250, 30)
    makeLabel(msTypeCard, "🍡  Small  ·  Medium  ·  Big marshmellow", 10, 0, 400, 30, 10, C.subtext, Enum.Font.Gotham)

    -- Info jarak NPC
    local sellInfoCard = makeCard(pageAuto, 1288, 30)
    makeLabel(sellInfoCard, "⌨  Tahan E otomatis 1.5 detik per marshmellow", 10, 0, 400, 30, 10, C.subtext, Enum.Font.Gotham)

    sellStatusLbl_ref = sellStatusLbl
    sellCountLbl_ref  = sellCountLbl
    sellToggleBtn_ref = sellToggleBtn

    -- Toggle logic
    sellToggleBtn.MouseButton1Click:Connect(function()
        autoSell_Running = not autoSell_Running
        if autoSell_Running then
            sellToggleBtn.Text = "💰  AUTO SELL : ON"
            sellToggleBtn.TextColor3 = C.green
            sellToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 35, 20)
            mkStroke(sellToggleBtn, 1, C.green)
            sellStatusLbl.Text = "RUNNING"
            sellStatusLbl.TextColor3 = C.green
        else
            sellToggleBtn.Text = "💰  AUTO SELL : OFF"
            sellToggleBtn.TextColor3 = C.red
            sellToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
            mkStroke(sellToggleBtn, 1, C.red)
            sellStatusLbl.Text = "OFF"
            sellStatusLbl.TextColor3 = C.red
        end
    end)

    -- ===== AUTO BUY BAHAN MARSHMALLOW =====
    sectionTitle(pageAuto, "AUTO BUY BAHAN", 1326)

    -- Jumlah per item
    local buyQty = { water = 1, sugar = 1, gelatin = 1 }

    local function makeQtyRow(yPos, emoji, label, key)
        local card = makeCard(pageAuto, yPos, 44)
        makeLabel(card, emoji .. "  " .. label, 10, 0, 160, 44, 12, C.text, Enum.Font.GothamBold)
        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0, 30, 0, 28); minusBtn.Position = UDim2.new(0, 175, 0, 8)
        minusBtn.Text = "−"; minusBtn.TextSize = 18; minusBtn.Font = Enum.Font.GothamBlack
        minusBtn.BackgroundColor3 = Color3.fromRGB(60,20,20); minusBtn.TextColor3 = C.red
        minusBtn.BorderSizePixel = 0; minusBtn.Parent = card; mkCorner(minusBtn, 4)
        local qtyLbl = Instance.new("TextLabel")
        qtyLbl.Size = UDim2.new(0, 40, 0, 28); qtyLbl.Position = UDim2.new(0, 210, 0, 8)
        qtyLbl.Text = "1"; qtyLbl.TextSize = 14; qtyLbl.Font = Enum.Font.GothamBlack
        qtyLbl.BackgroundTransparency = 1; qtyLbl.TextColor3 = Color3.fromRGB(255,255,255)
        qtyLbl.TextXAlignment = Enum.TextXAlignment.Center; qtyLbl.Parent = card
        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0, 30, 0, 28); plusBtn.Position = UDim2.new(0, 255, 0, 8)
        plusBtn.Text = "+"; plusBtn.TextSize = 18; plusBtn.Font = Enum.Font.GothamBlack
        plusBtn.BackgroundColor3 = Color3.fromRGB(20,50,20); plusBtn.TextColor3 = C.green
        plusBtn.BorderSizePixel = 0; plusBtn.Parent = card; mkCorner(plusBtn, 4)

        minusBtn.MouseButton1Click:Connect(function()
            buyQty[key] = math.max(1, buyQty[key] - 1)
            qtyLbl.Text = tostring(buyQty[key])
        end)
        plusBtn.MouseButton1Click:Connect(function()
            buyQty[key] = math.min(99, buyQty[key] + 1)
            qtyLbl.Text = tostring(buyQty[key])
        end)
        return qtyLbl
    end

    makeQtyRow(1352, "💧", "Water",         "water")
    makeQtyRow(1402, "🧊", "Sugar Block",   "sugar")
    makeQtyRow(1452, "🍮", "Gelatin",       "gelatin")

    local autoBuy_Running = false

    local buyToggleBtn = Instance.new("TextButton")
    buyToggleBtn.Size        = UDim2.new(1, -20, 0, 38)
    buyToggleBtn.Position    = UDim2.new(0, 10, 0, 1506)
    buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    buyToggleBtn.Text        = "🛒  AUTO BUY : OFF"
    buyToggleBtn.TextColor3  = Color3.fromRGB(100, 140, 255)
    buyToggleBtn.Font        = Enum.Font.GothamBlack
    buyToggleBtn.TextSize    = 13
    buyToggleBtn.BorderSizePixel = 0
    buyToggleBtn.Parent      = pageAuto
    mkCorner(buyToggleBtn, 6)
    mkStroke(buyToggleBtn, 1, Color3.fromRGB(80, 110, 220))

    local buyStatCard = makeCard(pageAuto, 1552, 44)
    makeLabel(buyStatCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    local buyStatusLbl = makeLabel(buyStatCard, "OFF", 90, 0, 300, 44, 14, Color3.fromRGB(150,150,150), Enum.Font.GothamBlack)

    local buyPhaseCard = makeCard(pageAuto, 1602, 44)
    makeLabel(buyPhaseCard, "BAHAN", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    local buyPhaseLbl = makeLabel(buyPhaseCard, "—", 90, 0, 300, 44, 13, Color3.fromRGB(100,200,255), Enum.Font.GothamBlack)

    local buyInfoCard = makeCard(pageAuto, 1652, 30)
    makeLabel(buyInfoCard, "⚠  Buka shop NPC manual, lalu klik START", 10, 0, 440, 30, 10, C.yellow, Enum.Font.Gotham)

    buyToggleBtn.MouseButton1Click:Connect(function()
        autoBuy_Running = not autoBuy_Running

        if not autoBuy_Running then
            buyToggleBtn.Text = "🛒  AUTO BUY : OFF"
            buyToggleBtn.TextColor3  = Color3.fromRGB(100, 140, 255)
            buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
            mkStroke(buyToggleBtn, 1, Color3.fromRGB(80, 110, 220))
            buyStatusLbl.Text = "OFF"
            buyStatusLbl.TextColor3 = Color3.fromRGB(150,150,150)
            buyPhaseLbl.Text = "—"
            return
        end

        buyToggleBtn.Text = "🛒  AUTO BUY : ON"
        buyToggleBtn.TextColor3  = C.green
        buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 35, 20)
        mkStroke(buyToggleBtn, 1, C.green)
        buyStatusLbl.Text = "RUNNING"
        buyStatusLbl.TextColor3 = C.green

        task.spawn(function()

            local BAHAN = {
                { label="Water",       toolKw="water",   itemText="Water",           emoji="💧", qtyKey="water"   },
                { label="Sugar Block", toolKw="sugar",   itemText="Sugar Block Bag", emoji="🧊", qtyKey="sugar"   },
                { label="Gelatin",     toolKw="gelatin", itemText="Gelatin",         emoji="🍮", qtyKey="gelatin" },
            }

            local function hasItem(kw)
                kw = kw:lower()
                local function chk(p)
                    if not p then return false end
                    for _, o in pairs(p:GetChildren()) do
                        if o:IsA("Tool") and o.Name:lower():find(kw) then return true end
                    end
                    return false
                end
                return chk(LocalPlayer:FindFirstChild("Backpack")) or chk(LocalPlayer.Character)
            end

            -- Klik tombol via events langsung (no mouse move)
            local function clickBtn(btn)
                pcall(function() btn.MouseButton1Down:Fire() end)
                task.wait(0.05)
                pcall(function() btn.MouseButton1Up:Fire() end)
                task.wait(0.05)
                pcall(function() btn.MouseButton1Click:Fire() end)
                task.wait(0.05)
                pcall(function() btn.Activated:Fire() end)
                task.wait(0.05)
                pcall(function() fireclick(btn) end)
            end

            -- Beli item dari shop yang SUDAH terbuka
            -- Path: Shop → Main → ScrollingFrame → PurchaseableItem [TextLabel Item = itemText]
            local function beliDariShop(itemText, jumlah)
                local berhasil = 0
                for i = 1, jumlah do
                    if not autoBuy_Running then break end

                    local shopGui = LocalPlayer.PlayerGui:FindFirstChild("Shop")
                    if not shopGui then
                        print("[AutoBuy] Shop tertutup saat beli ke-" .. i)
                        break
                    end

                    local main = shopGui:FindFirstChild("Main")
                    local sf   = main and main:FindFirstChild("ScrollingFrame")
                    if not sf then
                        print("[AutoBuy] ScrollingFrame tidak ditemukan")
                        break
                    end

                    local found = false
                    for _, item in pairs(sf:GetChildren()) do
                        if item:IsA("TextButton") and item.Name == "PurchaseableItem" then
                            local lbl = item:FindFirstChild("Item")
                            if lbl and lbl:IsA("TextLabel") and lbl.Text:lower():find(itemText:lower()) then
                                print("[AutoBuy] Beli " .. itemText .. " ke-" .. i .. "/" .. jumlah)
                                clickBtn(item)
                                task.wait(0.6)
                                found = true
                                berhasil = berhasil + 1
                                break
                            end
                        end
                    end

                    if not found then
                        print("[AutoBuy] Item '" .. itemText .. "' tidak ditemukan di shop")
                        break
                    end
                end
                return berhasil
            end

            -- Tutup shop
            local function tutupShop()
                local sg = LocalPlayer.PlayerGui:FindFirstChild("Shop")
                if sg then
                    local exit = sg:FindFirstChild("Exit", true)
                    if exit then clickBtn(exit); task.wait(0.5) end
                end
            end

            -- CEK: Shop harus sudah terbuka sebelum START
            local shopGui = LocalPlayer.PlayerGui:FindFirstChild("Shop")
            if not shopGui then
                buyStatusLbl.Text = "Buka shop dulu!"
                buyStatusLbl.TextColor3 = C.red
                print("[AutoBuy] ❌ Shop belum terbuka! Buka dialog NPC manual dulu.")
                task.wait(2)
                autoBuy_Running = false
                buyToggleBtn.Text = "🛒  AUTO BUY : OFF"
                buyToggleBtn.TextColor3 = Color3.fromRGB(100, 140, 255)
                buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
                mkStroke(buyToggleBtn, 1, Color3.fromRGB(80, 110, 220))
                buyStatusLbl.TextColor3 = Color3.fromRGB(150,150,150)
                buyPhaseLbl.Text = "—"
                return
            end

            -- Beli semua bahan sesuai qty
            for _, bahan in ipairs(BAHAN) do
                if not autoBuy_Running then break end
                local qty = buyQty[bahan.qtyKey] or 1
                buyPhaseLbl.Text = bahan.emoji .. " " .. bahan.label .. " x" .. qty
                buyStatusLbl.Text = "Membeli..."
                buyStatusLbl.TextColor3 = C.yellow
                print("[AutoBuy] Beli " .. bahan.label .. " x" .. qty)

                local n = beliDariShop(bahan.itemText, qty)
                print("[AutoBuy] " .. bahan.label .. ": " .. n .. "/" .. qty .. " berhasil")
                task.wait(0.3)
            end

            -- Tutup shop setelah selesai
            tutupShop()

            autoBuy_Running = false
            buyToggleBtn.Text = "🛒  AUTO BUY : OFF"
            buyToggleBtn.TextColor3  = Color3.fromRGB(100, 140, 255)
            buyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
            mkStroke(buyToggleBtn, 1, Color3.fromRGB(80, 110, 220))
            buyPhaseLbl.Text = "—"
            buyStatusLbl.Text = "SELESAI ✓"
            buyStatusLbl.TextColor3 = C.green
            print("[AutoBuy] Selesai!")
        end)
    end)

    pageAuto.CanvasSize = UDim2.new(0, 0, 0, 1700)
end

-- ===== PAGE 3: ESP + WHITELIST (BronxDupe Visuals style) =====
do
    -- ── Toggle ESP ──────────────────────────────────────────────────
    sectionTitle(pageEsp, "VISUALS / ESP", 8)

    local function updateEspBtn(btn)
        if espEnabled then
            btn.Text = "●  ESP  ON"
            btn.TextColor3 = Color3.fromRGB(34, 197, 94)
            mkStroke(btn, 1, Color3.fromRGB(34, 197, 94))
        else
            btn.Text = "●  ESP  OFF"
            btn.TextColor3 = C.red
            mkStroke(btn, 1, C.red)
        end
    end

    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(1, -20, 0, 36)
    espToggleBtn.Position = UDim2.new(0, 10, 0, 32)
    espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
    espToggleBtn.Text = "●  ESP  OFF"
    espToggleBtn.TextColor3 = C.red
    espToggleBtn.Font = Enum.Font.GothamBlack
    espToggleBtn.TextSize = 13
    espToggleBtn.BorderSizePixel = 0
    espToggleBtn.Parent = pageEsp
    mkCorner(espToggleBtn, 6)
    mkStroke(espToggleBtn, 1, C.red)

    -- Toggle ESP ON/OFF — semua fitur (box, nama, HP, item held, jarak) nyala/mati bersamaan
    espToggleBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        updateEspBtn(espToggleBtn)
        if espEnabled then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
            Players.PlayerAdded:Connect(function(plr)
                if espEnabled and plr ~= LocalPlayer then createESP(plr) end
            end)
            Players.PlayerRemoving:Connect(removeESP)
        else
            for plr, _ in pairs(espCache) do removeESP(plr) end
        end
    end)

    -- ── Info bar kecil ───────────────────────────────────────────────
    local espInfoRow = makeCard(pageEsp, 76, 26)
    local espInfoLbl = Instance.new("TextLabel")
    espInfoLbl.Size = UDim2.new(1, -12, 1, 0)
    espInfoLbl.Position = UDim2.new(0, 10, 0, 0)
    espInfoLbl.BackgroundTransparency = 1
    espInfoLbl.Text = "Box  .  Username  .  HP Bar  .  Item Held  .  Distance"
    espInfoLbl.TextColor3 = C.subtext
    espInfoLbl.Font = Enum.Font.Gotham
    espInfoLbl.TextSize = 10
    espInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    espInfoLbl.Parent = espInfoRow

    -- ── Color swatches ESP (di bawah info bar) ──────────────────────
    local CP = {
        Color3.fromRGB(255,50,50),
        Color3.fromRGB(255,255,255),
        Color3.fromRGB(0,210,255),
        Color3.fromRGB(34,197,94),
        Color3.fromRGB(234,179,8),
        Color3.fromRGB(168,85,247),
    }
    local swW = 1 / #CP

    local function mkEspSwatchRow(parent, yPos, label, onPick)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 0, 13)
        lbl.Position = UDim2.new(0, 10, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.subtext
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
        local sf = Instance.new("Frame")
        sf.Size = UDim2.new(1, -20, 0, 20)
        sf.Position = UDim2.new(0, 10, 0, yPos + 14)
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
        sf.Parent = parent
        for ci, col in ipairs(CP) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(swW, -3, 1, 0)
            sw.Position = UDim2.new(swW*(ci-1), 0, 0, 0)
            sw.BackgroundColor3 = col
            sw.Text = ""
            sw.BorderSizePixel = 0
            sw.Parent = sf
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

    -- 3 swatch rows: box, nama, item held
    mkEspSwatchRow(pageEsp, 110, "Warna ESP Box",      function(c) espBoxColor  = c end)
    mkEspSwatchRow(pageEsp, 146, "Warna Nama Player",  function(c) espNameColor = c end)
    mkEspSwatchRow(pageEsp, 182, "Warna Item Held",    function(c) espItemColor = c end)

    -- ── Whitelist section ─────────────────────────────────────────────
    local WO = 170  -- whitelist offset
    sectionTitle(pageEsp, "WHITELIST", 112 + WO)

    local wlCountBadge = Instance.new("TextLabel")
    wlCountBadge.Size = UDim2.new(0, 24, 0, 14)
    wlCountBadge.Position = UDim2.new(0, 104, 0, 115 + WO)
    wlCountBadge.BackgroundColor3 = C.accent
    wlCountBadge.Text = "0"
    wlCountBadge.TextColor3 = Color3.fromRGB(255,255,255)
    wlCountBadge.Font = Enum.Font.GothamBlack
    wlCountBadge.TextSize = 9
    wlCountBadge.BorderSizePixel = 0
    wlCountBadge.Parent = pageEsp
    mkCorner(wlCountBadge, 7)

    -- Tombol refresh whitelist aktif (kanan atas)
    local wlRefreshBtn = Instance.new("TextButton")
    wlRefreshBtn.Size = UDim2.new(0, 70, 0, 18)
    wlRefreshBtn.Position = UDim2.new(1, -80, 0, 113 + WO)
    wlRefreshBtn.BackgroundColor3 = C.card2
    wlRefreshBtn.Text = "🔄 Refresh"
    wlRefreshBtn.TextColor3 = C.subtext
    wlRefreshBtn.Font = Enum.Font.GothamBold
    wlRefreshBtn.TextSize = 9
    wlRefreshBtn.BorderSizePixel = 0
    wlRefreshBtn.Parent = pageEsp
    mkCorner(wlRefreshBtn, 4)
    mkStroke(wlRefreshBtn, 1, C.border)

    local wlActiveScroll = Instance.new("ScrollingFrame")
    wlActiveScroll.Size = UDim2.new(1, -20, 0, 90)
    wlActiveScroll.Position = UDim2.new(0, 10, 0, 134 + WO)
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
    wlRefreshBtn.MouseButton1Click:Connect(refreshActiveList)

    -- Tombol Refresh Server List di bawah whitelist aktif
    local wlRefreshBtn = Instance.new("TextButton")
    wlRefreshBtn.Size = UDim2.new(1, -20, 0, 28)
    wlRefreshBtn.Position = UDim2.new(0, 10, 0, 228 + WO)
    wlRefreshBtn.BackgroundColor3 = C.card
    wlRefreshBtn.Text = "🔄  Refresh — Cek Player Baru"
    wlRefreshBtn.TextColor3 = C.text
    wlRefreshBtn.Font = Enum.Font.GothamBold
    wlRefreshBtn.TextSize = 11
    wlRefreshBtn.BorderSizePixel = 0
    wlRefreshBtn.Parent = pageEsp
    mkCorner(wlRefreshBtn, 6)
    mkStroke(wlRefreshBtn, 1, C.border)

    -- ── Player di server ─────────────────────────────────────────────
    sectionTitle(pageEsp, "TAMBAH DARI SERVER", 264 + WO)

    local serverScroll = Instance.new("ScrollingFrame")
    serverScroll.Size = UDim2.new(1, -20, 0, 120)
    serverScroll.Position = UDim2.new(0, 10, 0, 288 + WO)
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

    -- Connect tombol refresh whitelist ke refreshServerList
    wlRefreshBtn.MouseButton1Click:Connect(refreshServerList)

    -- Auto-refresh saat ada player join / keluar
    Players.PlayerAdded:Connect(function() refreshServerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1) refreshServerList() end)

    -- tombol Refresh + Clear All
    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0.5, -14, 0, 30)
    refBtn.Position = UDim2.new(0, 10, 0, 416 + WO)
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
    clearBtn.Position = UDim2.new(0.5, 4, 0, 416 + WO)
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

    -- ===== VEHICLE FLY SECTION =====
    local VFO = 456 + WO + 16  -- offset mulai section ini

    sectionTitle(pageEsp, "✈  VEHICLE FLY", VFO)

    -- Toggle button
    local vFlyToggleBtn = Instance.new("TextButton")
    vFlyToggleBtn.Size = UDim2.new(1, -20, 0, 36)
    vFlyToggleBtn.Position = UDim2.new(0, 10, 0, VFO + 26)
    vFlyToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
    vFlyToggleBtn.Text = "✈  VEHICLE FLY : OFF"
    vFlyToggleBtn.TextColor3 = C.red
    vFlyToggleBtn.Font = Enum.Font.GothamBlack
    vFlyToggleBtn.TextSize = 13
    vFlyToggleBtn.BorderSizePixel = 0
    vFlyToggleBtn.Parent = pageEsp
    mkCorner(vFlyToggleBtn, 6)
    mkStroke(vFlyToggleBtn, 1, C.red)

    -- Status card
    local vFlyStatCard = makeCard(pageEsp, VFO + 70, 36)
    makeLabel(vFlyStatCard, "STATUS", 12, 0, 80, 36, 10, C.subtext, Enum.Font.GothamBold)
    local vFlyStatLbl = makeLabel(vFlyStatCard, "Tidak di kendaraan", 90, 0, 260, 36, 11, C.subtext, Enum.Font.GothamBold)

    -- Speed slider (manual row)
    local vFlySpeedCard = makeCard(pageEsp, VFO + 114, 44)
    makeLabel(vFlySpeedCard, "Kecepatan Terbang", 12, 2, 200, 20, 11, C.text, Enum.Font.GothamBold)
    local vFlySpeedValLbl = makeLabel(vFlySpeedCard, tostring(vFlySpeed), 0, 2, -12, 20, 11, C.accent2, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    vFlySpeedValLbl.Size = UDim2.new(1, -12, 0, 20)

    local vFlyTrack = Instance.new("Frame")
    vFlyTrack.Size = UDim2.new(1, -20, 0, 3)
    vFlyTrack.Position = UDim2.new(0, 10, 0, 32)
    vFlyTrack.BackgroundColor3 = C.border
    vFlyTrack.BorderSizePixel = 0
    vFlyTrack.Parent = vFlySpeedCard
    mkCorner(vFlyTrack, 2)
    local vFlyFill = Instance.new("Frame")
    local spRatio0 = (vFlySpeed - 10) / (300 - 10)
    vFlyFill.Size = UDim2.new(spRatio0, 0, 1, 0)
    vFlyFill.BackgroundColor3 = C.accent
    vFlyFill.BorderSizePixel = 0
    vFlyFill.Parent = vFlyTrack
    mkCorner(vFlyFill, 2)
    local vFlyKnob = Instance.new("TextButton")
    vFlyKnob.Size = UDim2.new(0, 10, 0, 10)
    vFlyKnob.Position = UDim2.new(spRatio0, -5, 0.5, -5)
    vFlyKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    vFlyKnob.Text = ""
    vFlyKnob.BorderSizePixel = 0
    vFlyKnob.Parent = vFlyTrack
    mkCorner(vFlyKnob, 5)
    local vFlyDragging = false
    vFlyKnob.MouseButton1Down:Connect(function() vFlyDragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then vFlyDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if vFlyDragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local ap = vFlyTrack.AbsolutePosition
            local as = vFlyTrack.AbsoluteSize
            local r = math.clamp((i.Position.X - ap.X) / as.X, 0, 1)
            vFlySpeed = math.floor(10 + r * (300 - 10))
            vFlyFill.Size = UDim2.new(r, 0, 1, 0)
            vFlyKnob.Position = UDim2.new(r, -5, 0.5, -5)
            vFlySpeedValLbl.Text = tostring(vFlySpeed)
        end
    end)

    -- Info kontrol
    local vFlyInfoCard = makeCard(pageEsp, VFO + 166, 52)
    makeLabel(vFlyInfoCard, "Kontrol saat Vehicle Fly aktif:", 12, 4, 340, 16, 10, C.subtext, Enum.Font.GothamBold)
    makeLabel(vFlyInfoCard, "E = Naik   |   Q = Turun   |   WASD = Steer", 12, 20, 380, 16, 10, C.subtext, Enum.Font.Gotham)
    makeLabel(vFlyInfoCard, "Steer otomatis mengikuti arah kamera", 12, 36, 340, 16, 10, Color3.fromRGB(100,180,100), Enum.Font.Gotham)

    -- ===== VEHICLE FLY LOGIC =====
    local function getVehicleSeat()
        local char = LocalPlayer.Character
        if not char then return nil end
        -- Cara paling reliable: cek Humanoid.SeatPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then
            return hum.SeatPart
        end
        return nil
    end

    local function getVehicleModel(seat)
        if not seat then return nil end
        -- Ambil Model kendaraan (bukan hanya PrimaryPart)
        local model = seat:FindFirstAncestorOfClass("Model")
        return model or seat
    end

    local function getVehicleRoot(seat)
        if not seat then return nil end
        local model = seat:FindFirstAncestorOfClass("Model")
        if model then
            if model.PrimaryPart then
                return model.PrimaryPart
            end
            local biggest, bigSize = nil, 0
            for _, p in pairs(model:GetDescendants()) do
                if p:IsA("BasePart") and p ~= seat then
                    local vol = p.Size.X * p.Size.Y * p.Size.Z
                    if vol > bigSize then bigSize = vol; biggest = p end
                end
            end
            return biggest or seat
        end
        return seat
    end

    -- Key state untuk naik/turun (E = Naik, Q = Turun)
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not vFlyEnabled then return end
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.E then vFlyUp = true end
        if input.KeyCode == Enum.KeyCode.Q then vFlyDown = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E then vFlyUp = false end
        if input.KeyCode == Enum.KeyCode.Q then vFlyDown = false end
    end)

    local function startVehicleFly()
        if vFlyConn then vFlyConn:Disconnect() vFlyConn = nil end

        vFlyConn = RunService.RenderStepped:Connect(function(dt)
            local seat  = getVehicleSeat()
            local root  = getVehicleRoot(seat)
            local model = getVehicleModel(seat)

            if not seat or not root or not model then
                vFlyStatLbl.Text = "Tidak di kendaraan"
                vFlyStatLbl.TextColor3 = C.subtext
                return
            end

            vFlyStatLbl.Text = "Terbang aktif ✓"
            vFlyStatLbl.TextColor3 = C.green

            -- Arah dari kamera
            local camCF   = Camera.CFrame
            local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            if forward.Magnitude > 0.01 then forward = forward.Unit else forward = Vector3.new(0,0,-1) end
            local right   = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
            if right.Magnitude > 0.01 then right = right.Unit else right = Vector3.new(1,0,0) end
            local up      = Vector3.new(0, 1, 0)

            -- Input WASD
            local moveVec = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - forward end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + right end
            if vFlyUp   then moveVec = moveVec + up end
            if vFlyDown then moveVec = moveVec - up end

            -- Zero-kan semua velocity di seluruh part model agar tidak melayang sendiri
            pcall(function()
                for _, p in pairs(model:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.AssemblyLinearVelocity  = Vector3.zero
                        p.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end)

            if moveVec.Magnitude > 0 then
                moveVec = moveVec.Unit
                local newPos = root.Position + moveVec * vFlySpeed * dt
                -- Arahkan kendaraan sesuai kamera (yaw saja)
                local lookDir = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                if lookDir.Magnitude > 0.01 then lookDir = lookDir.Unit else lookDir = forward end
                -- Gunakan PivotTo agar SELURUH model (badan + ban + semua part) ikut bergerak
                pcall(function()
                    local currentPivot = model:GetPivot()
                    local targetCF = CFrame.new(newPos, newPos + lookDir)
                    -- Offset pivot dari root agar posisi relatif terjaga
                    local offset = currentPivot:ToObjectSpace(root.CFrame)
                    model:PivotTo(targetCF * offset:Inverse())
                end)
            end
        end)
    end

    local function stopVehicleFly()
        if vFlyConn then vFlyConn:Disconnect() vFlyConn = nil end
        vFlyUp   = false
        vFlyDown = false
        vFlyStatLbl.Text = "Tidak di kendaraan"
        vFlyStatLbl.TextColor3 = C.subtext
    end

    vFlyToggleBtn.MouseButton1Click:Connect(function()
        vFlyEnabled = not vFlyEnabled
        if vFlyEnabled then
            vFlyToggleBtn.Text = "✈  VEHICLE FLY : ON"
            vFlyToggleBtn.TextColor3 = C.green
            vFlyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 35, 20)
            mkStroke(vFlyToggleBtn, 1, C.green)
            startVehicleFly()
        else
            vFlyToggleBtn.Text = "✈  VEHICLE FLY : OFF"
            vFlyToggleBtn.TextColor3 = C.red
            vFlyToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
            mkStroke(vFlyToggleBtn, 1, C.red)
            stopVehicleFly()
        end
    end)

    pageEsp.CanvasSize = UDim2.new(0, 0, 0, VFO + 280)
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
    makeLabel(coordCard, "📍 NPC Marshmellow", 10, 4, 260, 20, 12, C.accent2, Enum.Font.GothamBlack)
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
            safeTeleport(CFrame.new(l.x, l.y + 3, l.z), tpStatusValue)
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
                        safeTeleport(tgt.CFrame + Vector3.new(2, 0, 0), tpStatusValue)
                    end
                end)
                count = count + 1
            end
        end
        playerListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 32)
    end

    -- Refresh button (full width, lebih prominent)
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1, -20, 0, 34)
    refreshBtn.Position = UDim2.new(0, 10, 0, 728)
    refreshBtn.BackgroundColor3 = C.card
    refreshBtn.Text = "🔄  Refresh Daftar Player"
    refreshBtn.TextColor3 = C.text
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Parent = pageTP
    mkCorner(refreshBtn, 6)
    mkStroke(refreshBtn, 1, C.border)

    refreshBtn.MouseButton1Click:Connect(function()
        refreshBtn.Text = "⏳  Refreshing..."
        refreshBtn.TextColor3 = C.yellow
        refreshPlayerList()
        task.wait(0.3)
        refreshBtn.Text = "🔄  Refresh Daftar Player"
        refreshBtn.TextColor3 = C.text
    end)

    refreshPlayerList()

    -- Auto refresh saat ada player join / keluar
    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        refreshPlayerList()
    end)
    Players.PlayerRemoving:Connect(function()
        task.wait(0.1)
        refreshPlayerList()
    end)

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
                    safeTeleport(CFrame.new(510.1238, 6.5872, 596.9278), tpStatusValue)
                    -- Tunggu TP selesai sebelum countdown
                    task.wait(1.5)
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

    pageTP.CanvasSize = UDim2.new(0, 0, 0, 820)
end



-- ===== SIDEBAR NAV BUTTONS (BronxDupe style - vertikal kiri) =====
local tabDefs = {
    {icon="⚙",  label="Main",       page=pageAuto},
    {icon="👁",  label="Visuals",    page=pageEsp},
    {icon="⚔",  label="Combat",     page=pageAimbot},
    {icon="☰",  label="Miscellaneous", page=pageTP},
    {icon="⚙",  label="Settings",   page=pageCredits},
}

local activeTab = nil
local tabBtns = {}

local function setTab(idx)
    for i, tb in ipairs(tabBtns) do
        local isActive = (i == idx)
        -- teks aktif: putih terang, tidak aktif: abu
        tb.TextColor3 = isActive and C.text or C.subtext
        -- background aktif: sedikit lebih terang dengan garis merah kiri
        tb.BackgroundColor3 = isActive and Color3.fromRGB(22, 22, 22) or Color3.fromRGB(0, 0, 0, 0)
        tb.BackgroundTransparency = isActive and 0 or 1
        -- garis merah kiri untuk tab aktif
        local ind = tb:FindFirstChild("indicator")
        if ind then ind.Visible = isActive end
    end
    for _, td in ipairs(tabDefs) do td.page.Visible = false end
    tabDefs[idx].page.Visible = true
    activeTab = idx
end

-- Sidebar header label "MENU"
local sideHeader = Instance.new("TextLabel")
sideHeader.Size = UDim2.new(1, 0, 0, 30)
sideHeader.Position = UDim2.new(0, 0, 0, 8)
sideHeader.BackgroundTransparency = 1
sideHeader.Text = "MENU"
sideHeader.TextColor3 = C.accent
sideHeader.Font = Enum.Font.GothamBold
sideHeader.TextSize = 10
sideHeader.TextXAlignment = Enum.TextXAlignment.Center
sideHeader.Parent = sidebarNav

-- Garis bawah header
local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(0.8, 0, 0, 1)
headerLine.Position = UDim2.new(0.1, 0, 0, 36)
headerLine.BackgroundColor3 = C.border
headerLine.BorderSizePixel = 0
headerLine.Parent = sidebarNav

-- Buat tombol sidebar vertikal
for i, td in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.Position = UDim2.new(0, 0, 0, 42 + (i-1)*44)
    btn.BackgroundTransparency = 1
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = sidebarNav

    -- Garis merah kiri (indikator aktif)
    local ind = Instance.new("Frame")
    ind.Name = "indicator"
    ind.Size = UDim2.new(0, 2, 0.65, 0)
    ind.Position = UDim2.new(0, 0, 0.175, 0)
    ind.BackgroundColor3 = C.accent
    ind.BorderSizePixel = 0
    ind.Visible = false
    ind.Parent = btn
    mkCorner(ind, 2)

    -- Icon label
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(1, 0, 0, 18)
    iconLbl.Position = UDim2.new(0, 0, 0, 7)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = td.icon
    iconLbl.TextColor3 = C.subtext
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 14
    iconLbl.TextXAlignment = Enum.TextXAlignment.Center
    iconLbl.Parent = btn

    -- Label teks
    local textLbl = Instance.new("TextLabel")
    textLbl.Name = "label"
    textLbl.Size = UDim2.new(1, -4, 0, 16)
    textLbl.Position = UDim2.new(0, 2, 0, 25)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = td.label
    textLbl.TextColor3 = C.subtext
    textLbl.Font = Enum.Font.Gotham
    textLbl.TextSize = 9
    textLbl.TextXAlignment = Enum.TextXAlignment.Center
    textLbl.TextWrapped = true
    textLbl.Parent = btn

    tabBtns[i] = btn
    -- Simpan referensi label agar bisa update warna saat aktif
    btn:SetAttribute("tabIdx", i)

    local capturedIcon = iconLbl
    local capturedText = textLbl
    local ci = i
    btn.MouseButton1Click:Connect(function()
        setTab(ci)
        -- Update warna icon dan text setiap klik
        for j, tb2 in ipairs(tabBtns) do
            local isAct = (j == ci)
            local ic2 = tb2:FindFirstChild("TextLabel")  -- icon
            local tx2 = tb2:FindFirstChild("label")
            if ic2 then ic2.TextColor3 = isAct and C.text or C.subtext end
            if tx2 then tx2.TextColor3 = isAct and C.accent or C.subtext end
        end
    end)
end

-- Player info tidak diperlukan lagi (sidebar sudah ada)

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


-- ========== AUTO SELL MARSHMELLOW LOOP ==========
-- Cara kerja:
-- 1. Deteksi marshmellow (small/medium/big) di backpack/tangan
-- 2. Hold marshmellow (pindah ke tangan)
-- 3. Cari NPC penjual terdekat di workspace
-- 4. Arahkan karakter ke NPC
-- 5. Tekan E untuk jual
-- Repeat sampai semua terjual atau sell dimatikan

local msMsKeywords  = {"small marshmellow","medium marshmellow","big marshmellow",
                       "smallmarshmellow","mediummarshmellow","bigmarshmellow",
                       "small marsh","medium marsh","big marsh","marshmellow"}
local function getMarshmellowItems()
    local items = {}
    local bp  = LocalPlayer:FindFirstChild("Backpack")
    local ch  = LocalPlayer.Character
    local function checkParent(parent)
        if not parent then return end
        for _, tool in pairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                for _, kw in pairs(msMsKeywords) do
                    if n:find(kw) then
                        table.insert(items, tool)
                        break
                    end
                end
            end
        end
    end
    checkParent(bp)
    checkParent(ch)
    return items
end


-- Tahan E selama durasi detik (simulate hold, bukan tap cepat)
local function holdE(durasi)
    durasi = durasi or 1.5
    -- VirtualInputManager: press → tahan → release
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end)
    pcall(function() keypress(0x45) end)
    -- Tahan selama durasi, cek tiap 0.05s agar loop bisa dihentikan
    local elapsed = 0
    while elapsed < durasi do
        if not autoSell_Running then break end
        task.wait(0.05)
        elapsed = elapsed + 0.05
    end
    -- Release
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    pcall(function() keyrelease(0x45) end)
    task.wait(0.1)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if autoSell_Running then
            local items = getMarshmellowItems()
            if #items == 0 then
                if sellStatusLbl_ref then
                    sellStatusLbl_ref.Text = "MENUNGGU MS"
                    sellStatusLbl_ref.TextColor3 = Color3.fromRGB(234, 179, 8)
                end
            else

        if sellStatusLbl_ref then
            sellStatusLbl_ref.Text = "MENJUAL..."
            sellStatusLbl_ref.TextColor3 = Color3.fromRGB(34, 197, 94)
        end

        for _, marshmellow in ipairs(items) do
            if not autoSell_Running then break end

            -- Hold marshmellow ke tangan (tanpa teleport)
            pcall(function()
                if marshmellow.Parent ~= LocalPlayer.Character then
                    marshmellow.Parent = LocalPlayer.Character
                end
            end)
            task.wait(0.3)

            -- Tahan E selama 1.5 detik (simulate hold sampai prompt selesai)
            holdE(1.5)

            -- Update counter
            autoSell_Count = autoSell_Count + 1
            if sellCountLbl_ref then
                sellCountLbl_ref.Text = tostring(autoSell_Count)
            end

            task.wait(0.4)
        end

            if sellStatusLbl_ref then
                sellStatusLbl_ref.Text = "RUNNING"
                sellStatusLbl_ref.TextColor3 = Color3.fromRGB(34, 197, 94)
            end
            end -- close else (#items > 0)
        end -- close if autoSell_Running
    end -- close while true
end)

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

-- ========== ESP MAIN LOOP (throttled ~20fps, hemat CPU) ==========
RunService.Heartbeat:Connect(function(dt)
    if not espEnabled then return end
    _espAccum = _espAccum + dt
    if _espAccum < ESP_INTERVAL then return end
    _espAccum = 0

    local myChar2 = LocalPlayer.Character
    local myHRP2  = myChar2 and myChar2:FindFirstChild("HumanoidRootPart")
    local myPos   = myHRP2 and myHRP2.Position

    for player, drawings in pairs(espCache) do
        local boxOutline = drawings[1]
        local nameLabel  = drawings[2]
        local hpBarBg    = drawings[3]
        local hpBarFill  = drawings[4]
        local distLabel  = drawings[5]
        local itemLabel  = drawings[6]

        local char      = player.Character
        local humanoid  = char and char:FindFirstChildOfClass("Humanoid")
        local root      = char and char:FindFirstChild("HumanoidRootPart")
        local head      = char and char:FindFirstChild("Head")

        local function hideAll()
            boxOutline.Visible = false
            nameLabel.Visible  = false
            hpBarBg.Visible    = false
            hpBarFill.Visible  = false
            distLabel.Visible  = false
            if itemLabel then itemLabel.Visible = false end
        end

        if not (char and root and head and humanoid and humanoid.Health > 0 and not isWhitelisted(player)) then
            hideAll(); continue
        end

        -- Distance check (hitung sekali, reuse)
        local dist3D = myPos and (root.Position - myPos).Magnitude or 0
        if myPos and espMaxDist > 0 and dist3D > espMaxDist then
            hideAll(); continue
        end

        local hrpPos, hrpVis   = Camera:WorldToViewportPoint(root.Position)
        local headPos, headVis = Camera:WorldToViewportPoint(head.Position)
        if not (hrpVis and headVis) then hideAll(); continue end

        local height = math.abs(headPos.Y - hrpPos.Y) * 1.7 + (boxPadding * 2)
        local width  = height * 0.55
        local boxX   = hrpPos.X - width / 2
        local boxY   = headPos.Y - boxPadding

        -- Box
        boxOutline.Color    = espBoxColor
        boxOutline.Size     = Vector2.new(width, height)
        boxOutline.Position = Vector2.new(boxX, boxY)
        boxOutline.Visible  = true

        -- Nama
        nameLabel.Text     = player.Name
        nameLabel.Color    = espNameColor
        nameLabel.Position = Vector2.new(hrpPos.X, boxY - 14)
        nameLabel.Visible  = true

        -- HP bar
        local hpBarW  = 3
        local hpBarX  = boxX - hpBarW - 2
        -- Guard: MaxHealth bisa 0 saat player baru spawn
        local maxHp   = humanoid.MaxHealth
        local curHp   = humanoid.Health
        local hpRatio
        if maxHp > 0 then
            hpRatio = math.clamp(curHp / maxHp, 0, 1)
        else
            hpRatio = 1  -- fallback: anggap full
        end

        -- Background bar (selalu full height)
        hpBarBg.Size     = Vector2.new(hpBarW, height)
        hpBarBg.Position = Vector2.new(hpBarX, boxY)
        hpBarBg.Visible  = true

        -- Fill bar: hitung dari atas agar sesuai visual (atas = 100%, bawah = 0%)
        local fillHeight = math.max(1, height * hpRatio)  -- minimal 1px agar tidak glitch
        local fillY      = boxY + (height - fillHeight)   -- mulai dari bawah ke atas
        hpBarFill.Size     = Vector2.new(hpBarW, fillHeight)
        hpBarFill.Position = Vector2.new(hpBarX, fillY)
        -- Warna: hijau > kuning > merah
        if hpRatio > 0.6 then
            hpBarFill.Color = Color3.fromRGB(0, 255, 80)
        elseif hpRatio > 0.3 then
            hpBarFill.Color = Color3.fromRGB(255, 200, 0)
        else
            hpBarFill.Color = Color3.fromRGB(255, 50, 50)
        end
        hpBarFill.Visible = true

        -- Distance
        if myPos then
            distLabel.Text     = string.format("[%.0fm]", dist3D)
            distLabel.Position = Vector2.new(hrpPos.X, boxY + height + 4)
            distLabel.Visible  = true
        else
            distLabel.Visible = false
        end

        -- Item Held (di bawah distance)
        if itemLabel then
            if espShowItem then
                local heldItem = getHeldItem(player)
                if heldItem then
                    itemLabel.Text     = "[" .. heldItem .. "]"
                    itemLabel.Color    = espItemColor
                    itemLabel.Position = Vector2.new(hrpPos.X, boxY + height + 16)
                    itemLabel.Visible  = true
                else
                    itemLabel.Visible = false
                end
            else
                itemLabel.Visible = false
            end
        end
    end
end)

-- ========== PAGE AIMBOT ==========
do
    local function mkRow(parent, yPos, h)
        -- BronxDupe style: row flat tanpa border tebal, subtle background
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -16, 0, h or 34)
        f.Position = UDim2.new(0, 8, 0, yPos)
        f.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        f.BorderSizePixel = 0
        f.Parent = parent
        mkCorner(f, 4)
        -- Garis bawah tipis sebagai divider (BronxDupe style)
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, 0, 0, 1)
        divider.Position = UDim2.new(0, 0, 1, -1)
        divider.BackgroundColor3 = C.border
        divider.BorderSizePixel = 0
        divider.BackgroundTransparency = 0.5
        divider.Parent = f
        return f
    end
    local function mkRowLabel(row, txt, subTxt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.55, 0, subTxt and 0.55 or 1, 0)
        l.Position = UDim2.new(0, 10, 0, subTxt and 3 or 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = C.text
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = row
        if subTxt then
            local s = Instance.new("TextLabel")
            s.Size = UDim2.new(0.55, 0, 0.45, 0)
            s.Position = UDim2.new(0, 10, 0.55, 0)
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
        -- BronxDupe style section separator - sama seperti asli tapi lebih gelap
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
        -- BronxDupe style: toggle pill merah, lebih besar
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0, 38, 0, 20)
        bg.Position = UDim2.new(1, -46, 0.5, -10)
        bg.BackgroundColor3 = defaultOn and C.toggleOn or C.toggleOff
        bg.BorderSizePixel = 0
        bg.Parent = parent
        mkCorner(bg, 10)
        -- Knob putih
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = defaultOn and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        knob.Parent = bg
        mkCorner(knob, 7)
        local state = defaultOn
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = bg
        btn.MouseButton1Click:Connect(function()
            state = not state
            TweenService:Create(bg, TweenInfo.new(0.12), {BackgroundColor3 = state and C.toggleOn or C.toggleOff}):Play()
            TweenService:Create(knob, TweenInfo.new(0.12), {Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
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

    -- MODE: Camera / FreeAim
    mkSectionSep(pageAimbot, y, "MODE")
    y = y + 20
    local modeRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(modeRow, "Aim Mode", "Camera rotates | FreeAim moves mouse")
    mkPairBtn(modeRow, "Camera", "FreeAim", 1, function(which)
        aimbotMode = which == 1 and "Camera" or "FreeAim"
    end)
    y = y + 40

    -- TARGET (dropdown list)
    mkSectionSep(pageAimbot, y, "TARGET PART")
    y = y + 20
    local targetParts  = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"}
    local targetLabels = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"}
    local targetIdx    = 1
    local targetDropOpen = false

    -- Row header: label + nilai aktif + chevron
    local targetSelRow = mkRow(pageAimbot, y, 30)
    local targetSelLbl = Instance.new("TextLabel")
    targetSelLbl.Size = UDim2.new(0.42, 0, 1, 0)
    targetSelLbl.Position = UDim2.new(0, 10, 0, 0)
    targetSelLbl.BackgroundTransparency = 1
    targetSelLbl.Text = "Target Part"
    targetSelLbl.TextColor3 = C.text
    targetSelLbl.Font = Enum.Font.GothamBold
    targetSelLbl.TextSize = 11
    targetSelLbl.TextXAlignment = Enum.TextXAlignment.Left
    targetSelLbl.Parent = targetSelRow

    local targetValLbl = Instance.new("TextLabel")
    targetValLbl.Size = UDim2.new(0.36, 0, 1, 0)
    targetValLbl.Position = UDim2.new(0.42, 0, 0, 0)
    targetValLbl.BackgroundTransparency = 1
    targetValLbl.Text = targetLabels[targetIdx]
    targetValLbl.TextColor3 = C.accent2
    targetValLbl.Font = Enum.Font.GothamBold
    targetValLbl.TextSize = 10
    targetValLbl.TextXAlignment = Enum.TextXAlignment.Right
    targetValLbl.Parent = targetSelRow

    -- Tombol chevron toggle
    local chevronBtn = Instance.new("TextButton")
    chevronBtn.Size = UDim2.new(0, 26, 0, 20)
    chevronBtn.Position = UDim2.new(1, -32, 0.5, -10)
    chevronBtn.BackgroundColor3 = C.card2
    chevronBtn.Text = "v"
    chevronBtn.TextColor3 = C.accent2
    chevronBtn.Font = Enum.Font.GothamBold
    chevronBtn.TextSize = 11
    chevronBtn.BorderSizePixel = 0
    chevronBtn.Parent = targetSelRow
    mkCorner(chevronBtn, 4)
    mkStroke(chevronBtn, 1, C.border)

    y = y + 36

    -- Container frame untuk option list (tinggi = 0 saat collapse)
    local optionH = #targetLabels * 28 + 4
    local dropContainer = Instance.new("Frame")
    dropContainer.Size = UDim2.new(1, 0, 0, 0)
    dropContainer.Position = UDim2.new(0, 0, 0, y)
    dropContainer.BackgroundTransparency = 1
    dropContainer.BorderSizePixel = 0
    dropContainer.ClipsDescendants = true
    dropContainer.Parent = pageAimbot

    -- build option buttons di dalam container
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
        optBtn.Position = UDim2.new(0, 8, 0, (li-1)*28 + 2)
        optBtn.BackgroundColor3 = C.card2
        optBtn.TextColor3 = C.subtext
        optBtn.Font = Enum.Font.GothamBold
        optBtn.TextSize = 10
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.Text = "    " .. lbl
        optBtn.BorderSizePixel = 0
        optBtn.Parent = dropContainer
        mkCorner(optBtn, 4)
        targetOptBtns[li] = optBtn
        local capLi = li
        optBtn.MouseButton1Click:Connect(function()
            targetIdx = capLi
            aimbotTarget = targetParts[capLi]
            refreshTargetOpts()
        end)
    end
    refreshTargetOpts()

    -- Semua elemen setelah dropdown di-offset ini (posisi absolut)
    local postDropY = y  -- collapsed: tidak ada tinggi extra

    -- Fungsi toggle buka/tutup
    local function toggleTargetDrop()
        targetDropOpen = not targetDropOpen
        TweenService:Create(dropContainer,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, 0, 0, targetDropOpen and optionH or 0) }
        ):Play()
        chevronBtn.Text = targetDropOpen and "^" or "v"
        chevronBtn.BackgroundColor3 = targetDropOpen and C.accent or C.card2
        chevronBtn.TextColor3 = targetDropOpen and Color3.fromRGB(255,255,255) or C.accent2
    end

    chevronBtn.MouseButton1Click:Connect(toggleTargetDrop)

    -- klik area label/val juga toggle
    local rowClickBtn = Instance.new("TextButton")
    rowClickBtn.Size = UDim2.new(1, -38, 1, 0)
    rowClickBtn.Position = UDim2.new(0, 0, 0, 0)
    rowClickBtn.BackgroundTransparency = 1
    rowClickBtn.Text = ""
    rowClickBtn.BorderSizePixel = 0
    rowClickBtn.Parent = targetSelRow
    rowClickBtn.MouseButton1Click:Connect(toggleTargetDrop)

    -- Offset y untuk PRIORITY dan seterusnya
    -- (diletakkan setelah container; container punya tinggi 0 saat collapse)
    y = y + optionH + 6  -- pakai optionH agar tidak overlap saat dibuka

    -- PRIORITY
    local prioRow = mkRow(pageAimbot, y, 34)
    mkRowLabel(prioRow, "Lock Priority", "terdekat ke...")
    mkPairBtn(prioRow, "Crosshair", "Distance", 1, function(which)
        aimbotPriority = which == 1 and "Crosshair" or "Distance"
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

    -- ── MINIMIZE KEYBIND ──────────────────────────────────────────────
    mkSectionSep(pageAimbot, y, "MINIMIZE KEYBIND")
    y = y + 20
    local minKbRow = mkRow(pageAimbot, y, 34)
    local minKbLabelTxt = Instance.new("TextLabel")
    minKbLabelTxt.Size = UDim2.new(0.55, 0, 1, 0)
    minKbLabelTxt.Position = UDim2.new(0, 10, 0, 0)
    minKbLabelTxt.BackgroundTransparency = 1
    minKbLabelTxt.Text = "Hide / Show GUI"
    minKbLabelTxt.TextColor3 = C.text
    minKbLabelTxt.Font = Enum.Font.GothamBold
    minKbLabelTxt.TextSize = 11
    minKbLabelTxt.TextXAlignment = Enum.TextXAlignment.Left
    minKbLabelTxt.Parent = minKbRow

    local minKbSubTxt = Instance.new("TextLabel")
    minKbSubTxt.Size = UDim2.new(0.55, 0, 0, 12)
    minKbSubTxt.Position = UDim2.new(0, 10, 1, -14)
    minKbSubTxt.BackgroundTransparency = 1
    minKbSubTxt.Text = "tidak terlihat di layar"
    minKbSubTxt.TextColor3 = C.subtext
    minKbSubTxt.Font = Enum.Font.Gotham
    minKbSubTxt.TextSize = 9
    minKbSubTxt.TextXAlignment = Enum.TextXAlignment.Left
    minKbSubTxt.Parent = minKbRow

    local minKbBtn = Instance.new("TextButton")
    minKbBtn.Size = UDim2.new(0, 80, 0, 22)
    minKbBtn.Position = UDim2.new(1, -88, 0.5, -11)
    minKbBtn.BackgroundColor3 = C.card2
    minKbBtn.Text = "[ RShift ]"
    minKbBtn.TextColor3 = C.accent2
    minKbBtn.Font = Enum.Font.GothamBold
    minKbBtn.TextSize = 10
    minKbBtn.BorderSizePixel = 0
    minKbBtn.Parent = minKbRow
    mkCorner(minKbBtn, 5)
    mkStroke(minKbBtn, 1, C.accent)
    minKeybindBtnRef = minKbBtn

    -- Klik tombol → mulai binding minimize
    minKbBtn.MouseButton1Click:Connect(function()
        if isBindingMin then return end
        isBindingMin = true
        minKbBtn.Text = "[ ... ]"
        minKbBtn.TextColor3 = C.yellow
    end)

    -- Listen input untuk binding minimize
    UserInputService.InputBegan:Connect(function(input, _gpe)
        if not isBindingMin then return end
        -- Skip LMB agar dialog tidak langsung nutup
        if input.UserInputType == Enum.UserInputType.MouseButton1 then return end

        isBindingMin = false

        local kn2 = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
        local un2 = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")

        if un2 == "MouseButton2" then
            minKeyType   = "MouseButton"
            minKeyCode   = nil
            minKeyMBtn   = Enum.UserInputType.MouseButton2
            minKeyLabel  = "RMB"
        elseif un2 == "MouseButton3" then
            minKeyType   = "MouseButton"
            minKeyCode   = nil
            minKeyMBtn   = Enum.UserInputType.MouseButton3
            minKeyLabel  = "MMB"
        elseif un2 == "MouseButton4" or kn2 == "MouseButton4" then
            minKeyType   = "MB4"
            minKeyCode   = nil
            minKeyMBtn   = nil
            minKeyLabel  = "MB4"
        elseif un2 == "MouseButton5" or kn2 == "MouseButton5" then
            minKeyType   = "MB5"
            minKeyCode   = nil
            minKeyMBtn   = nil
            minKeyLabel  = "MB5"
        elseif un2 == "Keyboard" and kn2 ~= "Unknown" then
            minKeyType   = "KeyCode"
            minKeyCode   = input.KeyCode
            minKeyMBtn   = nil
            minKeyLabel  = kn2
        else
            -- Input tidak dikenal, ulangi binding
            isBindingMin = true
            return
        end

        minKbBtn.Text       = "[ " .. minKeyLabel .. " ]"
        minKbBtn.TextColor3 = C.accent2
    end)
    y = y + 40
    -- Helper: color swatch row (dipakai untuk FOV)
    local colorPresets = {
        Color3.fromRGB(220,38,38),
        Color3.fromRGB(255,255,255),
        Color3.fromRGB(0,210,255),
        Color3.fromRGB(34,197,94),
        Color3.fromRGB(234,179,8),
        Color3.fromRGB(168,85,247),
    }
    local function mkColorRow(parent, yPos, label, onPick)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 0, 13)
        lbl.Position = UDim2.new(0, 8, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.subtext
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
        local sf = Instance.new("Frame")
        sf.Size = UDim2.new(1, -16, 0, 20)
        sf.Position = UDim2.new(0, 8, 0, yPos + 14)
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
        sf.Parent = parent
        local cw = 1 / #colorPresets
        for ci, col in ipairs(colorPresets) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(cw, -3, 1, 0)
            sw.Position = UDim2.new(cw*(ci-1), 0, 0, 0)
            sw.BackgroundColor3 = col
            sw.Text = ""
            sw.BorderSizePixel = 0
            sw.Parent = sf
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
    mkSectionSep(pageAimbot, y, "SETTINGS")
    y = y + 20
    mkSlider(pageAimbot, y, "FOV Radius", 20, 400, aimbotFOV, "px", function(v)
        aimbotFOV = v
        if aimbotFovCircle then aimbotFovCircle.Radius = v end
    end)
    y = y + 50

    -- Warna FOV tepat di bawah slider FOV
    mkColorRow(pageAimbot, y, "🔴 Warna FOV Circle", function(c)
        fovColor = c
        if aimbotFovCircle then aimbotFovCircle.Color = c end
    end)
    y = y + 44

    mkSlider(pageAimbot, y, "Smooth", 1, 20, aimbotSmooth, "", function(v)
        aimbotSmooth = v
    end)
    y = y + 50
    mkSlider(pageAimbot, y, "Aimbot Max Distance", 10, 10000, aimbotMaxDist, "m", function(v)
        aimbotMaxDist = v
    end)
    y = y + 50
    mkSlider(pageAimbot, y, "ESP Max Distance", 10, 10000, espMaxDist, "m", function(v)
        espMaxDist = v
    end)
    y = y + 50

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

    mkSlider(pageAimbot, y, "Prediction", 0, 100, math.floor(predStrength * 100), "%", function(v)
        predStrength = v / 100
    end)
    y = y + 50

    pageAimbot.CanvasSize = UDim2.new(0, 0, 0, y + 50)
end

-- ===== PAGE: CREDITS =====
do
    sectionTitle(pageCredits, "⭐ CREDITS", 8)

    local creditData = {
        {role="Investor & Owner", name="Hiro", icon="👑", color=Color3.fromRGB(255,215,0)},
        {role="Developer",        name="V7x & Reyvan", icon="💻", color=Color3.fromRGB(100,180,255)},
    }

    for i, cr in ipairs(creditData) do
        local card = makeCard(pageCredits, 38 + (i-1)*68, 56)

        -- colored accent bar left
        local accentBar = Instance.new("Frame")
        accentBar.Size = UDim2.new(0, 3, 1, -10)
        accentBar.Position = UDim2.new(0, 4, 0, 5)
        accentBar.BackgroundColor3 = cr.color
        accentBar.BorderSizePixel = 0
        accentBar.Parent = card
        mkCorner(accentBar, 2)

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.new(0, 34, 1, 0)
        iconLbl.Position = UDim2.new(0, 14, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = cr.icon
        iconLbl.TextSize = 22
        iconLbl.Font = Enum.Font.GothamBlack
        iconLbl.Parent = card

        local roleLbl = Instance.new("TextLabel")
        roleLbl.Size = UDim2.new(1, -60, 0, 20)
        roleLbl.Position = UDim2.new(0, 52, 0, 8)
        roleLbl.BackgroundTransparency = 1
        roleLbl.Text = cr.role
        roleLbl.TextColor3 = C.subtext
        roleLbl.Font = Enum.Font.GothamBold
        roleLbl.TextSize = 10
        roleLbl.TextXAlignment = Enum.TextXAlignment.Left
        roleLbl.Parent = card

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -60, 0, 24)
        nameLbl.Position = UDim2.new(0, 52, 0, 26)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = cr.name
        nameLbl.TextColor3 = cr.color
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 15
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = card
    end

    -- Footer
    local footerCard = makeCard(pageCredits, 38 + #creditData * 68, 40)
    local footerLbl = Instance.new("TextLabel")
    footerLbl.Size = UDim2.new(1, -20, 1, 0)
    footerLbl.Position = UDim2.new(0, 10, 0, 0)
    footerLbl.BackgroundTransparency = 1
    footerLbl.RichText = true
    footerLbl.Text = '<font color="rgb(220,38,38)">Majesty Store</font>  ·  <font color="rgb(100,100,100)">Thank you for using MAJESTY ONTOP</font>'
    footerLbl.Font = Enum.Font.GothamBold
    footerLbl.TextSize = 11
    footerLbl.TextXAlignment = Enum.TextXAlignment.Center
    footerLbl.Parent = footerCard

    pageCredits.CanvasSize = UDim2.new(0, 0, 0, 38 + #creditData * 68 + 100)
end
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
-- predStrength slider: 0-100% → dipakai langsung sebagai multiplier detik ke depan
-- contoh predStrength=0.12 artinya prediksi posisi 0.12 detik ke depan
local function getPredictedPosition(part, player)
    local now        = tick()
    local currentPos = part.Position

    if not velCache[player] then
        velCache[player] = { lastPos = currentPos, lastVel = Vector3.zero, lastTime = now }
        return currentPos
    end

    local cache = velCache[player]
    local dt    = now - cache.lastTime

    if dt > 0 and dt < 0.2 then   -- max 200ms gap, lebih dari itu berarti lag/respawn
        local rawVel = (currentPos - cache.lastPos) / dt
        -- Lerp lebih responsif: 0.5 agar velocity cepat tracking gerakan player
        -- Tapi tidak 1.0 agar tidak terlalu noisy
        cache.lastVel = cache.lastVel:Lerp(rawVel, 0.5)
    elseif dt >= 0.2 then
        -- Jika gap terlalu besar (lag/teleport), reset velocity
        cache.lastVel = Vector3.zero
    end

    -- PENTING: selalu update lastPos dan lastTime setiap call
    cache.lastPos  = currentPos
    cache.lastTime = now

    if not aimbotPrediction then return currentPos end

    -- predStrength langsung sebagai detik ke depan (bukan dikali 0.5 lagi)
    -- contoh: predStrength=0.12 → predict 0.12s ke depan
    return currentPos + cache.lastVel * predStrength
end

-- Cari target dalam FOV — support dua mode priority
local function getBestTarget()
    -- FreeAim: ukur dari posisi mouse | Camera: dari tengah viewport
    local mx, my
    if aimbotMode == "FreeAim" then
        local mp = UserInputService:GetMouseLocation()
        mx, my = mp.X, mp.Y
    else
        mx = Camera.ViewportSize.X / 2
        my = Camera.ViewportSize.Y / 2
    end
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

-- Camera mode: rotate kamera ke arah target (frame-rate independent lerp)
local function aimCamera(part, plr, dt)
    local pos  = getPredictedPosition(part, plr)
    local cf   = Camera.CFrame
    local goal = CFrame.new(cf.Position, pos)
    -- Alpha berbasis dt agar smooth di semua FPS: a = 1 - (1-base)^(dt/ref)
    local base = math.clamp(1 - (aimbotSmooth / 20), 0.04, 0.95)
    local t    = 1 - (1 - base) ^ (dt / 0.016)   -- normalized ke ~60fps
    Camera.CFrame = cf:Lerp(goal, math.clamp(t, 0.01, 1))
end

-- FreeAim mode: gerakkan mouse smooth ke arah target dengan velocity lerp
local mouseMoveMethod = nil
pcall(function()
    if mousemoverel then mouseMoveMethod = "rel" end
end)
pcall(function()
    if not mouseMoveMethod and mouse1press then mouseMoveMethod = "press" end
end)

local _freeAimVelX = 0   -- velocity mouse X saat ini (smooth carry-over)
local _freeAimVelY = 0   -- velocity mouse Y saat ini

local function aimFreeAim(part, plr, dt)
    local pos       = getPredictedPosition(part, plr)
    local sp, vis   = Camera:WorldToViewportPoint(pos)
    if not vis then return end
    local mp     = UserInputService:GetMouseLocation()
    local dx     = sp.X - mp.X
    local dy     = sp.Y - mp.Y
    -- Smooth factor berbasis dt
    local base   = math.clamp(1 - (aimbotSmooth / 20), 0.04, 0.95)
    local lerpT  = 1 - (1 - base) ^ (dt / 0.016)
    lerpT        = math.clamp(lerpT, 0.01, 1)
    -- Lerp velocity untuk gerakan halus (tidak langsung snap)
    _freeAimVelX = _freeAimVelX + (dx * lerpT - _freeAimVelX) * 0.6
    _freeAimVelY = _freeAimVelY + (dy * lerpT - _freeAimVelY) * 0.6
    if mouseMoveMethod == "rel" then
        mousemoverel(_freeAimVelX, _freeAimVelY)
    end
end

-- ========== MAIN AIMBOT LOOP ==========
local wasActive       = false
local _fovRadiusCur   = 250       -- radius FOV circle saat ini (di-lerp)
local _fovPosX        = 0
local _fovPosY        = 0

RunService.RenderStepped:Connect(function(dt)
    -- Target posisi FOV circle
    local txFov, tyFov
    if aimbotMode == "FreeAim" then
        local mp = UserInputService:GetMouseLocation()
        txFov, tyFov = mp.X, mp.Y
    else
        txFov = Camera.ViewportSize.X / 2
        tyFov = Camera.ViewportSize.Y / 2
    end

    -- Inisialisasi posisi pertama kali
    if _fovPosX == 0 then _fovPosX = txFov end
    if _fovPosY == 0 then _fovPosY = tyFov end

    -- Smooth lerp posisi dan radius FOV circle setiap frame
    local fovLerp   = math.clamp(dt * 40, 0, 1)   -- cepat tapi smooth
    _fovPosX        = _fovPosX + (txFov - _fovPosX) * fovLerp
    _fovPosY        = _fovPosY + (tyFov - _fovPosY) * fovLerp
    _fovRadiusCur   = _fovRadiusCur + (aimbotFOV - _fovRadiusCur) * fovLerp

    aimbotFovCircle.Position = Vector2.new(_fovPosX, _fovPosY)
    aimbotFovCircle.Radius   = _fovRadiusCur
    aimbotFovCircle.Color    = fovColor
    aimbotFovCircle.Visible  = aimbotEnabled

    if not aimbotEnabled then
        wasActive = false
        _freeAimVelX = 0
        _freeAimVelY = 0
        return
    end

    aimbotActive = isAimbotKeyHeld()

    if not aimbotActive then
        wasActive = false
        -- Decay velocity saat tidak aktif agar tidak lanjut bergerak
        _freeAimVelX = _freeAimVelX * 0.7
        _freeAimVelY = _freeAimVelY * 0.7
        return
    end

    wasActive = true

    local target, targetPlr = getBestTarget()
    if not target then return end

    if aimbotMode == "FreeAim" then
        aimFreeAim(target, targetPlr, dt)
    else
        aimCamera(target, targetPlr, dt)
    end
end)


print("=== MAJESTY ONTOP v18.0 ===")
print("Fitur:")
print("-  Inventory Tracker")
print("-  Auto MS")
print("-  ESP: Box | Name | HP | Item Held | Distance | Throttled ~15fps")
print("-  Teleport")
print("-  AIMBOT: Camera + FreeAim | FOV ikuti mouse (FreeAim) | Lock ke Head | Priority tanpa emoji")
print("=========================================")