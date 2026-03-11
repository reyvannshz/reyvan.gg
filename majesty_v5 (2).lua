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

-- Sell / Buy Variables
local AutoSell_Running = false
local AutoBuy_Running  = false
local sellStatusValue  = nil
local sellCountValue   = nil
local buyStatusValue   = nil
local buyLogValue      = nil

-- Tunggu character spawn
repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ========== GUI MAJESTY - TEMA REYVAN.GG STYLE ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY ONTOP"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ===== WARNA TEMA =====
local C = {
    bg       = Color3.fromRGB(13, 13, 18),
    sidebar  = Color3.fromRGB(18, 18, 26),
    panel    = Color3.fromRGB(22, 22, 32),
    card     = Color3.fromRGB(28, 28, 40),
    accent   = Color3.fromRGB(99, 102, 241),   -- indigo
    accent2  = Color3.fromRGB(139, 92, 246),   -- violet
    green    = Color3.fromRGB(34, 197, 94),
    red      = Color3.fromRGB(239, 68, 68),
    yellow   = Color3.fromRGB(234, 179, 8),
    text     = Color3.fromRGB(240, 240, 255),
    subtext  = Color3.fromRGB(148, 148, 180),
    border   = Color3.fromRGB(45, 45, 65),
}

local function mkCorner(p, r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 8) c.Parent=p end
local function mkStroke(p, t, col) local s=Instance.new("UIStroke") s.Thickness=t or 1 s.Color=col or C.border s.Parent=p end

-- ===== MAIN WINDOW =====
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 560, 0, 420)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mkCorner(mainFrame, 12)
mkStroke(mainFrame, 1, C.border)

-- ===== TITLE BAR =====
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = C.sidebar
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
mkCorner(titleBar, 12)

-- gradient subtle di titlebar
local tbGrad = Instance.new("UIGradient")
tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 26)),
})
tbGrad.Rotation = 90
tbGrad.Parent = titleBar

-- accent line bawah titlebar
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, -2)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel = 0
accentLine.Parent = titleBar
local alGrad = Instance.new("UIGradient")
alGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.accent),
    ColorSequenceKeypoint.new(0.5, C.accent2),
    ColorSequenceKeypoint.new(1, C.accent),
})
alGrad.Parent = accentLine

-- dot merah/kuning/hijau ala macOS
local dotColors = {Color3.fromRGB(239,68,68), Color3.fromRGB(234,179,8), Color3.fromRGB(34,197,94)}
for i, dc in ipairs(dotColors) do
    local dot = Instance.new("TextButton")
    dot.Size = UDim2.new(0,12,0,12)
    dot.Position = UDim2.new(0, 10 + (i-1)*18, 0.5, -6)
    dot.BackgroundColor3 = dc
    dot.Text = ""
    dot.BorderSizePixel = 0
    dot.Parent = titleBar
    mkCorner(dot, 99)
    if i == 1 then
        dot.MouseButton1Click:Connect(function() screenGui:Destroy() end)
    elseif i == 2 then
        dot.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            if isMinimized then
                mainFrame:TweenSize(UDim2.new(0,560,0,42),"Out","Quad",0.18,true)
                -- hide content
                task.spawn(function() task.wait(0.05) for _,v in pairs(mainFrame:GetChildren()) do if v~=titleBar then v.Visible=false end end end)
            else
                for _,v in pairs(mainFrame:GetChildren()) do v.Visible=true end
                mainFrame:TweenSize(UDim2.new(0,560,0,420),"Out","Quad",0.18,true)
            end
        end)
    end
end

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 60, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MAJESTY  ONTOP"
titleLabel.TextColor3 = C.text
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 80, 1, 0)
versionLabel.Position = UDim2.new(1, -90, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v5.0.0"
versionLabel.TextColor3 = C.accent2
versionLabel.Font = Enum.Font.GothamBold
versionLabel.TextSize = 12
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = titleBar

-- ===== SIDEBAR (KIRI) =====
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 148, 1, -42)
sidebar.Position = UDim2.new(0, 0, 0, 42)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

-- border kanan sidebar
local sbBorder = Instance.new("Frame")
sbBorder.Size = UDim2.new(0, 1, 1, 0)
sbBorder.Position = UDim2.new(1, -1, 0, 0)
sbBorder.BackgroundColor3 = C.border
sbBorder.BorderSizePixel = 0
sbBorder.Parent = sidebar

-- ===== MAIN CONTENT AREA =====
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -149, 1, -42)
contentArea.Position = UDim2.new(0, 149, 0, 42)
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

local pageInv  = makePage()
local pageAuto = makePage()
local pageEsp  = makePage()
local pageTP   = makePage()
local pageSell = makePage()
local pageBuy  = makePage()

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

-- ===== PAGE 3: ESP =====
do
    sectionTitle(pageEsp, "ESP PLAYER", 8)

    local espCard = makeCard(pageEsp, 38, 44)
    makeLabel(espCard, "Box + Name + Health Bar", 12, 0, 220, 44, 12, C.subtext, Enum.Font.Gotham)

    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(1, -20, 0, 38)
    espToggleBtn.Position = UDim2.new(0, 10, 0, 92)
    espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    espToggleBtn.Text = "●  ESP OFF"
    espToggleBtn.TextColor3 = C.red
    espToggleBtn.Font = Enum.Font.GothamBlack
    espToggleBtn.TextSize = 14
    espToggleBtn.BorderSizePixel = 0
    espToggleBtn.Parent = pageEsp
    mkCorner(espToggleBtn, 6)
    mkStroke(espToggleBtn, 1, C.red)

    local espInfo = makeCard(pageEsp, 140, 80)
    makeLabel(espInfo, "🔴  Box outline merah", 10, 4, 280, 18, 11, C.subtext, Enum.Font.Gotham)
    makeLabel(espInfo, "🏷  Nama player di atas box", 10, 22, 280, 18, 11, C.subtext, Enum.Font.Gotham)
    makeLabel(espInfo, "💚  Health bar warna dinamis", 10, 40, 280, 18, 11, C.subtext, Enum.Font.Gotham)
    makeLabel(espInfo, "🖐  Item yang lagi dipegang player", 10, 58, 280, 18, 11, Color3.fromRGB(255,230,100), Enum.Font.Gotham)

    pageEsp.CanvasSize = UDim2.new(0,0,0,240)
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
    loopToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
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
                pb.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
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
            loopToggle.BackgroundColor3 = Color3.fromRGB(20, 50, 20)
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
            loopToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
            mkStroke(loopToggle, 1, C.red)
            tpLoopValue.Text = "ONCE"
            tpLoopValue.TextColor3 = C.accent
            tpStatusValue.Text = "STANDBY"
            tpStatusValue.TextColor3 = C.yellow
        end
    end)

    pageTP.CanvasSize = UDim2.new(0, 0, 0, 780)
end

-- ===== PAGE 5: JUAL MARSHMALLOW =====
do
    sectionTitle(pageSell, "💰 JUAL MARSHMALLOW", 8)

    -- Status card
    local statCard = makeCard(pageSell, 38, 44)
    makeLabel(statCard, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    sellStatusValue = makeLabel(statCard, "OFF", 90, 0, 200, 44, 16, C.red, Enum.Font.GothamBlack)

    -- Total terjual
    local soldCard = makeCard(pageSell, 90, 44)
    makeLabel(soldCard, "TERJUAL", 12, 0, 90, 44, 11, C.subtext, Enum.Font.GothamBold)
    sellCountValue = makeLabel(soldCard, "0", 100, 0, 200, 44, 16, C.yellow, Enum.Font.GothamBlack)

    -- Info cara kerja
    local infoCard = makeCard(pageSell, 142, 56)
    makeLabel(infoCard, "📍 Teleport ke NPC penjual", 10, 4, 280, 16, 11, C.subtext, Enum.Font.Gotham)
    makeLabel(infoCard, "🤝 Interact otomatis untuk menjual", 10, 22, 280, 16, 11, C.subtext, Enum.Font.Gotham)
    makeLabel(infoCard, "🔄 Loop sampai inventory kosong", 10, 40, 280, 16, 11, C.subtext, Enum.Font.Gotham)

    -- Tombol START SELL
    local sellStartBtn = Instance.new("TextButton")
    sellStartBtn.Size = UDim2.new(0.47, -10, 0, 38)
    sellStartBtn.Position = UDim2.new(0, 10, 0, 210)
    sellStartBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    sellStartBtn.Text = "▶  JUAL"
    sellStartBtn.TextColor3 = Color3.fromRGB(255,255,255)
    sellStartBtn.Font = Enum.Font.GothamBlack
    sellStartBtn.TextSize = 14
    sellStartBtn.BorderSizePixel = 0
    sellStartBtn.Parent = pageSell
    mkCorner(sellStartBtn, 6)

    -- Tombol STOP SELL
    local sellStopBtn = Instance.new("TextButton")
    sellStopBtn.Size = UDim2.new(0.47, -10, 0, 38)
    sellStopBtn.Position = UDim2.new(0.5, 5, 0, 210)
    sellStopBtn.BackgroundColor3 = C.red
    sellStopBtn.Text = "■  STOP"
    sellStopBtn.TextColor3 = Color3.fromRGB(255,255,255)
    sellStopBtn.Font = Enum.Font.GothamBlack
    sellStopBtn.TextSize = 14
    sellStopBtn.BorderSizePixel = 0
    sellStopBtn.Parent = pageSell
    mkCorner(sellStopBtn, 6)

    pageSell.CanvasSize = UDim2.new(0,0,0,260)

    -- ===== LOGIKA JUAL =====
    -- Koordinat NPC penjual marshmallow (sesuaikan dengan game)
    local SELL_NPC_POS = Vector3.new(510, 3.5, 597)  -- ganti sesuai lokasi NPC di game

    local function findSellNPC()
        -- Cari NPC/Part bernama mirip "sell", "vendor", "shop", "merchant"
        local keywords = {"sell", "vendor", "shop", "merchant", "buyer", "cashier", "register", "counter"}
        for _, obj in pairs(Workspace:GetDescendants()) do
            if (obj:IsA("Part") or obj:IsA("Model") or obj:IsA("MeshPart")) then
                local n = string.lower(obj.Name)
                for _, kw in ipairs(keywords) do
                    if n:find(kw) then return obj end
                end
            end
        end
        return nil
    end

    local function countMarshmallows()
        local count = 0
        local function scanContainer(container)
            if not container then return end
            for _, item in pairs(container:GetChildren()) do
                if item:IsA("Tool") then
                    local n = string.lower(item.Name)
                    if n:find("marshmallow") or n:find("marsh") or n:find("mallow") or n:find("ms") then
                        count = count + 1
                    end
                end
            end
        end
        scanContainer(LocalPlayer:FindFirstChild("Backpack"))
        scanContainer(LocalPlayer.Character)
        return count
    end

    local function autoSellLoop()
        local totalSold = 0
        sellCountValue.Text = "0"

        while AutoSell_Running do
            local msCount = countMarshmallows()
            if msCount == 0 then
                sellStatusValue.Text = "KOSONG"
                sellStatusValue.TextColor3 = C.yellow
                task.wait(2)
                -- Tetap loop kalau AutoSell masih running (nunggu MS jadi)
                if AutoSell_Running then
                    sellStatusValue.Text = "NUNGGU MS..."
                    sellStatusValue.TextColor3 = Color3.fromRGB(148,148,180)
                end
                task.wait(3)
            else
                sellStatusValue.Text = "JALAN (" .. msCount .. " MS)"
                sellStatusValue.TextColor3 = C.green

                -- Teleport ke dekat NPC penjual
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = CFrame.new(SELL_NPC_POS + Vector3.new(0, 3, 2))
                    task.wait(0.6)
                end

                -- Pegang marshmallow yang pertama ada
                local function holdFirstMarshmallow()
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    if bp then
                        for _, tool in pairs(bp:GetChildren()) do
                            if tool:IsA("Tool") then
                                local n = string.lower(tool.Name)
                                if n:find("marshmallow") or n:find("marsh") or n:find("mallow") or n:find("ms") then
                                    tool.Parent = LocalPlayer.Character
                                    task.wait(0.2)
                                    return true
                                end
                            end
                        end
                    end
                    return false
                end

                holdFirstMarshmallow()
                task.wait(0.3)

                -- Interact (tekan E) untuk menjual
                local VIM = game:GetService("VirtualInputManager")
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.15)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                task.wait(0.5)

                totalSold = totalSold + 1
                sellCountValue.Text = tostring(totalSold)

                task.wait(0.8)
            end
        end

        sellStatusValue.Text = "OFF"
        sellStatusValue.TextColor3 = C.red
    end

    sellStartBtn.MouseButton1Click:Connect(function()
        if not AutoSell_Running then
            AutoSell_Running = true
            sellStatusValue.Text = "STARTING..."
            sellStatusValue.TextColor3 = C.yellow
            task.spawn(autoSellLoop)
        end
    end)

    sellStopBtn.MouseButton1Click:Connect(function()
        AutoSell_Running = false
        sellStatusValue.Text = "OFF"
        sellStatusValue.TextColor3 = C.red
    end)
end

-- ===== PAGE 6: BELI BAHAN MARSHMALLOW =====
do
    sectionTitle(pageBuy, "🛒 BELI BAHAN", 8)

    -- Status card
    local statCard2 = makeCard(pageBuy, 38, 44)
    makeLabel(statCard2, "STATUS", 12, 0, 80, 44, 11, C.subtext, Enum.Font.GothamBold)
    buyStatusValue = makeLabel(statCard2, "OFF", 90, 0, 200, 44, 16, C.red, Enum.Font.GothamBlack)

    -- Pilihan bahan dengan checkbox style
    sectionTitle(pageBuy, "PILIH BAHAN", 90)

    local buyItems = {
        {key="water",  label="💧 Water",       color=Color3.fromRGB(56,189,248),  enabled=true},
        {key="sugar",  label="🧊 Sugar Block",  color=Color3.fromRGB(192,132,252), enabled=true},
        {key="gelatin",label="🍮 Gelatin",      color=Color3.fromRGB(251,146,60),  enabled=true},
        {key="bag",    label="👜 Empty Bag",    color=Color3.fromRGB(74,222,128),  enabled=true},
    }
    local buyToggles = {}

    for i, bitem in ipairs(buyItems) do
        local card = makeCard(pageBuy, 112 + (i-1)*48, 38)

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, -8)
        bar.Position = UDim2.new(0, 4, 0, 4)
        bar.BackgroundColor3 = bitem.color
        bar.BorderSizePixel = 0
        bar.Parent = card
        mkCorner(bar, 3)

        makeLabel(card, bitem.label, 14, 0, 160, 38, 12, C.text, Enum.Font.GothamBold)

        local tog = Instance.new("TextButton")
        tog.Size = UDim2.new(0, 52, 0, 24)
        tog.Position = UDim2.new(1, -62, 0.5, -12)
        tog.BackgroundColor3 = bitem.enabled and C.green or C.red
        tog.Text = bitem.enabled and "ON" or "OFF"
        tog.TextColor3 = Color3.fromRGB(255,255,255)
        tog.Font = Enum.Font.GothamBlack
        tog.TextSize = 11
        tog.BorderSizePixel = 0
        tog.Parent = card
        mkCorner(tog, 6)

        buyToggles[bitem.key] = {btn=tog, enabled=bitem.enabled}
        local bkey = bitem.key
        tog.MouseButton1Click:Connect(function()
            buyToggles[bkey].enabled = not buyToggles[bkey].enabled
            local on = buyToggles[bkey].enabled
            tog.BackgroundColor3 = on and C.green or C.red
            tog.Text = on and "ON" or "OFF"
        end)
    end

    -- Jumlah beli (per bahan)
    local qtyCard = makeCard(pageBuy, 318, 44)
    makeLabel(qtyCard, "JUMLAH/BAHAN", 12, 0, 130, 44, 11, C.subtext, Enum.Font.GothamBold)
    local buyQtyValue = makeLabel(qtyCard, "10", 150, 0, 60, 44, 18, C.yellow, Enum.Font.GothamBlack)

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 28, 0, 28)
    minusBtn.Position = UDim2.new(1, -70, 0.5, -14)
    minusBtn.BackgroundColor3 = C.red
    minusBtn.Text = "−"
    minusBtn.TextColor3 = Color3.fromRGB(255,255,255)
    minusBtn.Font = Enum.Font.GothamBlack
    minusBtn.TextSize = 16
    minusBtn.BorderSizePixel = 0
    minusBtn.Parent = qtyCard
    mkCorner(minusBtn, 6)

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 28, 0, 28)
    plusBtn.Position = UDim2.new(1, -36, 0.5, -14)
    plusBtn.BackgroundColor3 = C.green
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.fromRGB(255,255,255)
    plusBtn.Font = Enum.Font.GothamBlack
    plusBtn.TextSize = 16
    plusBtn.BorderSizePixel = 0
    plusBtn.Parent = qtyCard
    mkCorner(plusBtn, 6)

    local buyQty = 10
    minusBtn.MouseButton1Click:Connect(function()
        if buyQty > 1 then
            buyQty = buyQty - 1
            buyQtyValue.Text = tostring(buyQty)
        end
    end)
    plusBtn.MouseButton1Click:Connect(function()
        if buyQty < 99 then
            buyQty = buyQty + 1
            buyQtyValue.Text = tostring(buyQty)
        end
    end)

    -- Tombol START BUY & STOP BUY
    local buyStartBtn = Instance.new("TextButton")
    buyStartBtn.Size = UDim2.new(0.47, -10, 0, 38)
    buyStartBtn.Position = UDim2.new(0, 10, 0, 372)
    buyStartBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    buyStartBtn.Text = "▶  BELI"
    buyStartBtn.TextColor3 = Color3.fromRGB(255,255,255)
    buyStartBtn.Font = Enum.Font.GothamBlack
    buyStartBtn.TextSize = 14
    buyStartBtn.BorderSizePixel = 0
    buyStartBtn.Parent = pageBuy
    mkCorner(buyStartBtn, 6)

    local buyStopBtn = Instance.new("TextButton")
    buyStopBtn.Size = UDim2.new(0.47, -10, 0, 38)
    buyStopBtn.Position = UDim2.new(0.5, 5, 0, 372)
    buyStopBtn.BackgroundColor3 = C.red
    buyStopBtn.Text = "■  STOP"
    buyStopBtn.TextColor3 = Color3.fromRGB(255,255,255)
    buyStopBtn.Font = Enum.Font.GothamBlack
    buyStopBtn.TextSize = 14
    buyStopBtn.BorderSizePixel = 0
    buyStopBtn.Parent = pageBuy
    mkCorner(buyStopBtn, 6)

    -- Log card
    local logCard = makeCard(pageBuy, 420, 44)
    makeLabel(logCard, "LOG", 12, 0, 50, 44, 11, C.subtext, Enum.Font.GothamBold)
    buyLogValue = makeLabel(logCard, "Idle", 65, 0, 240, 44, 11, C.text, Enum.Font.Gotham)

    pageBuy.CanvasSize = UDim2.new(0,0,0,480)

    -- ===== Koordinat NPC toko bahan =====
    -- Water shop, Sugar shop, dll — sesuaikan dengan posisi di game
    local SHOP_LOCATIONS = {
        water   = Vector3.new(500, 3.5, 580),   -- ganti sesuai posisi toko Water di game
        sugar   = Vector3.new(520, 3.5, 580),   -- ganti sesuai posisi toko Sugar di game
        gelatin = Vector3.new(505, 3.5, 600),   -- ganti sesuai posisi toko Gelatin di game
        bag     = Vector3.new(515, 3.5, 600),   -- ganti sesuai posisi toko Bag di game
    }

    local function buyItem(key, qty)
        if not buyToggles[key] or not buyToggles[key].enabled then return end
        local pos = SHOP_LOCATIONS[key]
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Teleport ke toko
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 2))
        task.wait(0.6)
        buyLogValue.Text = "Beli " .. key .. " x" .. qty

        local VIM = game:GetService("VirtualInputManager")
        for i = 1, qty do
            if not AutoBuy_Running then break end
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.15)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
            task.wait(0.4)
            buyLogValue.Text = key .. " " .. i .. "/" .. qty
        end
    end

    local function autoBuyLoop()
        while AutoBuy_Running do
            buyStatusValue.Text = "BELI WATER"
            buyStatusValue.TextColor3 = Color3.fromRGB(56,189,248)
            buyItem("water", buyQty)
            if not AutoBuy_Running then break end

            buyStatusValue.Text = "BELI SUGAR"
            buyStatusValue.TextColor3 = Color3.fromRGB(192,132,252)
            buyItem("sugar", buyQty)
            if not AutoBuy_Running then break end

            buyStatusValue.Text = "BELI GELATIN"
            buyStatusValue.TextColor3 = Color3.fromRGB(251,146,60)
            buyItem("gelatin", buyQty)
            if not AutoBuy_Running then break end

            buyStatusValue.Text = "BELI BAG"
            buyStatusValue.TextColor3 = Color3.fromRGB(74,222,128)
            buyItem("bag", buyQty)
            if not AutoBuy_Running then break end

            buyStatusValue.Text = "SELESAI ✓"
            buyStatusValue.TextColor3 = C.green
            buyLogValue.Text = "Semua bahan dibeli!"
            task.wait(1)
            AutoBuy_Running = false
        end

        buyStatusValue.Text = "OFF"
        buyStatusValue.TextColor3 = C.red
        buyLogValue.Text = "Idle"
    end

    buyStartBtn.MouseButton1Click:Connect(function()
        if not AutoBuy_Running then
            AutoBuy_Running = true
            buyStatusValue.Text = "STARTING..."
            buyStatusValue.TextColor3 = C.yellow
            buyLogValue.Text = "Memulai..."
            task.spawn(autoBuyLoop)
        end
    end)

    buyStopBtn.MouseButton1Click:Connect(function()
        AutoBuy_Running = false
        buyStatusValue.Text = "OFF"
        buyStatusValue.TextColor3 = C.red
        buyLogValue.Text = "Dihentikan"
    end)
end

-- ===== SIDEBAR TABS =====
local tabDefs = {
    {icon="📦", label="Inventory", page=pageInv},
    {icon="⚙️", label="Auto MS",   page=pageAuto},
    {icon="👁", label="ESP",       page=pageEsp},
    {icon="🚀", label="Teleport",  page=pageTP},
    {icon="💰", label="Jual MS",   page=pageSell},
    {icon="🛒", label="Beli Bahan",page=pageBuy},
}

local activeTab = nil
local tabBtns = {}

local function setTab(idx)
    for i, tb in ipairs(tabBtns) do
        if i == idx then
            tb.BackgroundColor3 = C.accent
            tb.TextColor3 = C.text
            mkStroke(tb, 0)
        else
            tb.BackgroundColor3 = Color3.fromRGB(0,0,0,0)
            tb.BackgroundTransparency = 1
            tb.TextColor3 = C.subtext
        end
    end
    for _, td in ipairs(tabDefs) do td.page.Visible = false end
    tabDefs[idx].page.Visible = true
    activeTab = idx
end

-- Brand sidebar top
local brandLbl = Instance.new("TextLabel")
brandLbl.Size = UDim2.new(1, 0, 0, 40)
brandLbl.Position = UDim2.new(0, 0, 0, 8)
brandLbl.BackgroundTransparency = 1
brandLbl.Text = "MAJESTY"
brandLbl.TextColor3 = C.accent2
brandLbl.Font = Enum.Font.GothamBlack
brandLbl.TextSize = 13
brandLbl.Parent = sidebar

for i, td in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.Position = UDim2.new(0, 8, 0, 50 + (i-1)*36)
    btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
    btn.BackgroundTransparency = 1
    btn.Text = td.icon .. "  " .. td.label
    btn.TextColor3 = C.subtext
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BorderSizePixel = 0
    btn.Parent = sidebar
    mkCorner(btn, 6)

    tabBtns[i] = btn
    local ci = i
    btn.MouseButton1Click:Connect(function() setTab(ci) end)
end

-- Player info di bawah sidebar
local playerCard = Instance.new("Frame")
playerCard.Size = UDim2.new(1, -16, 0, 40)
playerCard.Position = UDim2.new(0, 8, 1, -50)
playerCard.BackgroundColor3 = C.card
playerCard.BorderSizePixel = 0
playerCard.Parent = sidebar
mkCorner(playerCard, 6)

local playerName = Instance.new("TextLabel")
playerName.Size = UDim2.new(1, -8, 1, 0)
playerName.Position = UDim2.new(0, 8, 0, 0)
playerName.BackgroundTransparency = 1
playerName.Text = "👤  " .. LocalPlayer.Name
playerName.TextColor3 = C.text
playerName.Font = Enum.Font.GothamBold
playerName.TextSize = 11
playerName.TextXAlignment = Enum.TextXAlignment.Left
playerName.Parent = playerCard

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
local VirtualInputManager = game:GetService("VirtualInputManager")

local function interact()
    -- Metode 1: VirtualInputManager (paling reliable di Roblox)
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    -- Fallback: executor keypress API (Synapse/KRNL/dll)
    if not ok then
        pcall(function()
            keypress(0x45)   -- 0x45 = huruf E
            task.wait(0.15)
            keyrelease(0x45)
        end)
    end
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
    boxOutline.Thickness = 2
    boxOutline.Color = Color3.fromRGB(255, 50, 50)
    boxOutline.Filled = false
    boxOutline.Visible = false

    -- Name label di atas box
    local nameLabel = Drawing.new("Text")
    nameLabel.Text = player.DisplayName .. " [" .. player.Name .. "]"
    nameLabel.Size = 13
    nameLabel.Font = Drawing.Fonts.UI
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
    hpText.Font = Drawing.Fonts.UI
    hpText.Color = Color3.fromRGB(255, 255, 255)
    hpText.Outline = true
    hpText.OutlineColor = Color3.fromRGB(0, 0, 0)
    hpText.Center = true
    hpText.Visible = false

    -- Inventory label (muncul di bawah nama)
    local invLabel = Drawing.new("Text")
    invLabel.Size = 11
    invLabel.Font = Drawing.Fonts.UI
    invLabel.Color = Color3.fromRGB(255, 230, 100)
    invLabel.Outline = true
    invLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    invLabel.Center = true
    invLabel.Visible = false
    invLabel.Text = ""

    espCache[player] = {boxOutline, nameLabel, hpBarBg, hpBarFill, hpText, invLabel}

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
            and humanoid and humanoid.Health > 0 then

            local root = char.HumanoidRootPart
            local head = char.Head
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

                -- Nama di atas box
                nameLabel.Text = player.DisplayName ~= player.Name
                    and (player.DisplayName .. " [" .. player.Name .. "]")
                    or player.Name
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

                -- HP text di bawah health bar
                hpText.Text = math.floor(hpRatio * 100) .. "%"
                hpText.Position = Vector2.new(hpBarX + hpBarW / 2, boxY + height + 2)
                hpText.Visible = true

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
            else
                boxOutline.Visible = false
                nameLabel.Visible = false
                hpBarBg.Visible = false
                hpBarFill.Visible = false
                hpText.Visible = false
                invLabel.Visible = false
            end
        else
            boxOutline.Visible = false
            nameLabel.Visible = false
            hpBarBg.Visible = false
            hpBarFill.Visible = false
            hpText.Visible = false
            invLabel.Visible = false
        end
    end)
end

-- ESP Toggle Button Handler
espToggleBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled

    if espEnabled then
        espToggleBtn.Text = "●  ESP ON"
        espToggleBtn.TextColor3 = Color3.fromRGB(34, 197, 94)
        espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 35)
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
        espToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
        for plr, _ in pairs(espCache) do
            removeESP(plr)
        end
    end
end)

print("=== MAJESTY ONTOP v5.0 ===")
print("Fitur:")
print("- 📦 Inventory Tracker (Water/Gelatin/Sugar/Bag)")
print("- ⚙️  Auto MS: Water → Sugar → Gelatin → Bag")
print("- 👁️  ESP: Box + Name + HP + Item Dipegang")
print("- 🚀 Teleport ke lokasi & player")
print("- 💰 AUTO JUAL MARSHMALLOW (loop sampai habis)")
print("- 🛒 AUTO BELI BAHAN (pilih bahan + jumlah)")
print("========================================")