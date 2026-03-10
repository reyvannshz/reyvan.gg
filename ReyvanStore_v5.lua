-- ============================================================
--   van.gg | South Bronx : The Trenches  v5.0
--   Auto Farm Marshmallow + ESP
--   Fix: Auto-detect koordinat, interact ProximityPrompt
-- ============================================================

-- ============================================================
-- EXECUTOR COMPAT + ANTI-KICK & ANTI-BAN
-- 100% safe untuk Xeno Android, Delta, Arceus X, KRNL, Synapse
-- Tidak ada newcclosure / getrawmetatable / hookfunction langsung
-- Semua fungsi executor dicek dulu sebelum dipanggil
-- ============================================================

local _lp = game:GetService("Players").LocalPlayer
local _RS = game:GetService("RunService")

-- Safe fireproximityprompt
local _fireprox
if typeof(fireproximityprompt) == "function" then
    _fireprox = fireproximityprompt
else
    _fireprox = function(p)
        if not p then return end
        pcall(function() p.Triggered:Fire(_lp) end)
    end
end

-- Safe fireclickdetector
local _fireclk
if typeof(fireclickdetector) == "function" then
    _fireclk = fireclickdetector
else
    _fireclk = function(d)
        if not d then return end
        pcall(function() d.MouseClick:Fire(_lp) end)
    end
end

-- ── Anti-Kick Layer 1: Block RemoteEvent bernama kick/ban ──
-- Ini cara PALING aman dan jalan di SEMUA executor termasuk Xeno
local _kickWords = {"kick","ban","punish","exile","suspend","mute"}

local function isKickRemote(name)
    local low = name:lower()
    for _, w in ipairs(_kickWords) do
        if low:find(w, 1, true) then return true end
    end
    return false
end

local function blockRemote(obj)
    pcall(function()
        if obj:IsA("RemoteEvent") and isKickRemote(obj.Name) then
            obj.OnClientEvent:Connect(function()
                -- tidak lakukan apa-apa = kick/ban diabaikan
                warn("[van.gg] Shield: remote '"..obj.Name.."' blocked")
            end)
        end
        if obj:IsA("RemoteFunction") and isKickRemote(obj.Name) then
            obj.OnClientInvoke = function() return nil end
        end
    end)
end

task.spawn(function()
    task.wait(1) -- tunggu game load
    for _, v in ipairs(game:GetDescendants()) do
        pcall(blockRemote, v)
    end
end)

game.DescendantAdded:Connect(function(d)
    task.wait(0.1)
    pcall(blockRemote, d)
end)

-- ── Anti-Kick Layer 2: Hook __namecall (PC only, full pcall guard) ──
task.spawn(function()
    pcall(function()
        -- Hanya jalan kalau semua fungsi ada (Synapse/KRNL)
        -- Xeno tidak punya ini jadi auto-skip
        local ok1 = typeof(getrawmetatable)   == "function"
        local ok2 = typeof(newcclosure)       == "function"
        local ok3 = typeof(getnamecallmethod) == "function"
        if not (ok1 and ok2 and ok3) then return end

        local mt  = getrawmetatable(game)
        local old = rawget(mt, "__namecall")
        if not old then return end

        local ro = typeof(isreadonly)=="function" and isreadonly(mt) or false
        if ro and typeof(setreadonly)=="function" then setreadonly(mt, false) end

        rawset(mt, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if m == "Kick" and self == _lp then
                warn("[van.gg] Shield: Kick blocked")
                return
            end
            return old(self, ...)
        end))

        if ro and typeof(setreadonly)=="function" then setreadonly(mt, true) end
    end)
end)

-- ── Anti-Detection: Normalkan velocity setelah teleport ──
-- Supaya tidak kena anticheat velocity South Bronx
local _velConn
local function startVelNorm()
    if _velConn then pcall(function() _velConn:Disconnect() end) end
    _velConn = _RS.Heartbeat:Connect(function()
        pcall(function()
            local char = _lp.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.AssemblyLinearVelocity.Magnitude > 80 then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
    end)
end
task.spawn(startVelNorm)
_lp.CharacterAdded:Connect(function()
    task.wait(1)
    task.spawn(startVelNorm)
end)

print("[van.gg] Shield aktif (Xeno + PC compatible)")

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = workspace

local player    = Players.LocalPlayer
local camera    = Workspace.CurrentCamera
local _isMobile = UserInputService.TouchEnabled

-- Character setup dengan respawn support
local character, humanoid, rootPart
local function setupChar()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid  = character:WaitForChild("Humanoid",10)
    rootPart  = character:WaitForChild("HumanoidRootPart",10)
end
setupChar()
player.CharacterAdded:Connect(function()
    task.wait(1)
    setupChar()
end)

-- ============================================================
-- AUTO-DETECT KOORDINAT dari workspace
-- Sistem: scan semua BasePart/Model cari nama yg cocok
-- ============================================================
local SCAN_KEYWORDS = {
    WATER       = {"water","waterbottle","waterjug","mineral","agua"},
    SUGAR       = {"sugar","sugarblock","gula"},
    GELATIN     = {"gelatin","gelatine","agar","jelly"},
    POT         = {"pot","cookingpot","stove","pan","cooker","oven"},
    BAG         = {"emptybag","bag","pouch","sack","packaging"},
    SELL        = {"sell","dealer","cashier","merchant","vendor","trader","npc"},
    MALLOW      = {"marshmallow","mallow","marsh"},
}

local COORDS = {
    WATER   = nil, SUGAR  = nil, GELATIN = nil,
    POT     = nil, BAG    = nil, SELL    = nil,
    MALLOW  = nil,
}

local function getPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
        if p then return p.Position end
    end
    return nil
end

local function matchName(name, keywords)
    local n = name:lower():gsub("[%s_%-]","")
    for _,kw in ipairs(keywords) do
        if n:find(kw,1,true) then return true end
    end
    return false
end

local function hasPrompt(obj)
    if obj:FindFirstChildOfClass("ProximityPrompt") then return true end
    if obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt") then return true end
    return false
end

local scanLog = {}
local function scanWorkspace()
    scanLog = {}
    local found = 0
    -- Reset
    for k in pairs(COORDS) do COORDS[k] = nil end

    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local pos = getPos(obj)
            if pos then
                for cat, kws in pairs(SCAN_KEYWORDS) do
                    if COORDS[cat] == nil and matchName(obj.Name, kws) then
                        COORDS[cat] = pos
                        found += 1
                        table.insert(scanLog, "✅ "..cat.." → "..obj.Name)
                    end
                end
            end
        end
    end
    table.insert(scanLog, "━━━━━━━━━━━━━━")
    table.insert(scanLog, "📊 "..found.."/7 terdeteksi")
    return found
end

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    WALK_TIMEOUT   = 20,
    INTERACT_DIST  = 6,
    ACTION_DELAY   = 0.6,
    WATER_COOK     = 22,   -- detik masak water
    MIX_COOK       = 47,   -- detik masak campuran
    MALLOW_PRICE   = 950,
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning       = false
local farmActive      = false
local beliActive      = false
local jualActive      = false
local espActive       = false
local targetAmount    = 10
local mallowDone      = 0
local moneyGained     = 0
local cycleCount      = 0
local sessionStart    = tick()
local currentStep     = "Idle"
local espObjects      = {}
local espThread       = nil

-- ============================================================
-- UTILITY
-- ============================================================
local function safeChar()
    return character and humanoid and rootPart
        and humanoid.Health > 0
end

local function walkTo(pos)
    if not isRunning then return end
    if not safeChar() then return end
    humanoid:MoveTo(pos)
    local t = tick()
    repeat
        RunService.Heartbeat:Wait()
        if not isRunning then return end
        if not safeChar() then return end
        if tick()-t > CONFIG.WALK_TIMEOUT then
            currentStep = "⚠️ Timeout jalan, skip"
            break
        end
    until (rootPart.Position - pos).Magnitude < CONFIG.INTERACT_DIST
end

local function waitSec(s)
    if not isRunning then return end
    local t = tick()
    repeat
        RunService.Heartbeat:Wait()
        if not isRunning then return end
    until tick()-t >= s
end

-- Cari ProximityPrompt terdekat dari posisi
local function findPromptNear(pos, radius, keywords)
    radius = radius or 25
    local best, bestDist = nil, math.huge
    for _,obj in ipairs(Workspace:GetDescendants()) do
        local prompts = {}
        if obj:IsA("ProximityPrompt") then
            table.insert(prompts, obj)
        end
        for _,p in ipairs(prompts) do
            local part = p.Parent
            if part and part:IsA("BasePart") then
                local d = (part.Position - pos).Magnitude
                if d <= radius then
                    if keywords then
                        if matchName(part.Name, keywords) or matchName((part.Parent and part.Parent.Name or ""), keywords) then
                            if d < bestDist then best=p bestDist=d end
                        end
                    else
                        if d < bestDist then best=p bestDist=d end
                    end
                end
            end
        end
    end
    return best
end

-- Interact dengan semua ProximityPrompt di radius
local function interactAt(pos, radius, keywords)
    radius = radius or 20
    local fired = false
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                local d = (part.Position - pos).Magnitude
                if d <= radius then
                    local nameOk = true
                    if keywords then
                        nameOk = matchName(part.Name, keywords)
                            or matchName((part.Parent and part.Parent.Name or ""), keywords)
                    end
                    if nameOk then
                        pcall(_fireprox, obj)
                        fired = true
                        task.wait(0.15)
                    end
                end
            end
        end
        -- ClickDetector juga
        if obj:IsA("ClickDetector") then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                local d = (part.Position - pos).Magnitude
                if d <= radius then
                    pcall(_fireclk, obj)
                    fired = true
                    task.wait(0.1)
                end
            end
        end
    end
    return fired
end

-- Teleport & interact (lebih reliable utk South Bronx)
local function goAndInteract(pos, label, keywords, radius)
    if not isRunning then return end
    currentStep = label
    -- Teleport langsung ke dekat objek
    if rootPart then
        rootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,3))
    end
    task.wait(CONFIG.ACTION_DELAY)
    interactAt(pos, radius or 18, keywords)
    task.wait(CONFIG.ACTION_DELAY)
end

-- ============================================================
-- FARMING FUNCTIONS
-- ============================================================

local function beliSemua()
    -- Beli Water
    if COORDS.WATER then
        goAndInteract(COORDS.WATER, "Beli Water", {"water","waterbottle"})
    end
    if not isRunning then return end
    -- Beli Sugar Block
    if COORDS.SUGAR then
        goAndInteract(COORDS.SUGAR, "Beli Sugar Block", {"sugar"})
    end
    if not isRunning then return end
    -- Beli Gelatin
    if COORDS.GELATIN then
        goAndInteract(COORDS.GELATIN, "Beli Gelatin", {"gelatin","agar"})
    end
end

local function jualMarshmallow()
    if not isRunning then return end
    if COORDS.SELL then
        goAndInteract(COORDS.SELL, "Jual Marshmallow", {"sell","dealer","cashier","vendor"})
        -- Konfirmasi jual (interact dua kali)
        task.wait(0.3)
        interactAt(COORDS.SELL, 18, {"sell","dealer","cashier","vendor","confirm","yes"})
        moneyGained += CONFIG.MALLOW_PRICE
        mallowDone  += 1
    else
        currentStep = "❌ Koordinat SELL tidak ditemukan! Scan dulu."
    end
end

local function cookingCycle()
    if not safeChar() then task.wait(2) return end

    -- 1. Beli bahan
    beliSemua()
    if not isRunning then return end

    -- 2. Ambil water ke pot
    if COORDS.WATER and COORDS.POT then
        goAndInteract(COORDS.WATER, "Ambil Water")
        task.wait(0.3)
        goAndInteract(COORDS.POT, "Masak Water (tunggu "..CONFIG.WATER_COOK.."s)", {"pot","stove","cooker"})
        waitSec(CONFIG.WATER_COOK)
    end
    if not isRunning then return end

    -- 3. Masukkan Sugar + Gelatin
    if COORDS.SUGAR then
        goAndInteract(COORDS.SUGAR, "Masukkan Sugar Block", {"sugar"})
    end
    if COORDS.GELATIN then
        goAndInteract(COORDS.GELATIN, "Masukkan Gelatin", {"gelatin"})
    end
    if not isRunning then return end

    -- 4. Masak campuran
    if COORDS.POT then
        goAndInteract(COORDS.POT, "Masak Campuran (tunggu "..CONFIG.MIX_COOK.."s)", {"pot","stove","cooker"})
        interactAt(COORDS.POT, 18, {"pot","stove","cooker"})
        waitSec(CONFIG.MIX_COOK)
    end
    if not isRunning then return end

    -- 5. Ambil bag & kemas
    if COORDS.BAG then
        goAndInteract(COORDS.BAG, "Ambil Empty Bag", {"bag","pouch","sack"})
    end
    if COORDS.POT then
        goAndInteract(COORDS.POT, "Kemas Marshmallow", {"pot","stove","cooker"})
    end

    -- 6. Ambil hasil marshmallow
    if COORDS.MALLOW then
        goAndInteract(COORDS.MALLOW, "Ambil Marshmallow", {"marshmallow","mallow"})
    end

    -- 7. Jual
    jualMarshmallow()

    cycleCount += 1
    currentStep = "✅ Siklus #"..cycleCount.." selesai"
    task.wait(1)
end

-- ============================================================
-- ESP SYSTEM
-- ============================================================
local function clearESP()
    for _, h in pairs(espObjects) do
        if h and h.Parent then h:Destroy() end
    end
    espObjects = {}
end

local function createESPForPlayer(plr)
    if plr == player then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- Billboard GUI
    local bb = Instance.new("BillboardGui")
    bb.Name = "VanGG_ESP"
    bb.Size = UDim2.new(0,110,0,60)
    bb.StudsOffset = Vector3.new(0,3.2,0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 300
    bb.Parent = hrp

    -- Name label
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1,0,0,18)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.DisplayName
    nameLbl.TextColor3 = Color3.fromRGB(255,255,255)
    nameLbl.TextSize = 11
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    nameLbl.Parent = bb

    -- Health bar background
    local hpBG = Instance.new("Frame")
    hpBG.Size = UDim2.new(1,0,0,7)
    hpBG.Position = UDim2.new(0,0,0,20)
    hpBG.BackgroundColor3 = Color3.fromRGB(40,40,40)
    hpBG.BorderSizePixel = 0
    hpBG.Parent = bb
    Instance.new("UICorner",hpBG).CornerRadius = UDim.new(1,0)

    -- Health bar fill
    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(hum.Health/hum.MaxHealth,0,1,0)
    hpFill.BackgroundColor3 = Color3.fromRGB(60,210,80)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBG
    Instance.new("UICorner",hpFill).CornerRadius = UDim.new(1,0)

    -- HP text
    local hpLbl = Instance.new("TextLabel")
    hpLbl.Size = UDim2.new(1,0,0,14)
    hpLbl.Position = UDim2.new(0,0,0,29)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Text = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    hpLbl.TextColor3 = Color3.fromRGB(200,200,200)
    hpLbl.TextSize = 9
    hpLbl.Font = Enum.Font.Gotham
    hpLbl.TextStrokeTransparency = 0
    hpLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    hpLbl.Parent = bb

    -- Box ESP (SelectionBox)
    local box = Instance.new("SelectionBox")
    box.Color3 = Color3.fromRGB(220,40,40)
    box.LineThickness = 0.04
    box.SurfaceTransparency = 0.85
    box.SurfaceColor3 = Color3.fromRGB(220,40,40)
    box.Adornee = char
    box.Parent = Workspace

    -- Update HP realtime
    local conn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hum then
            box:Destroy()
            bb:Destroy()
            return
        end
        local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
        hpFill.Size = UDim2.new(hp, 0, 1, 0)
        hpFill.BackgroundColor3 = hp > 0.6
            and Color3.fromRGB(60,210,80)
            or hp > 0.3
            and Color3.fromRGB(220,180,0)
            or Color3.fromRGB(220,40,40)
        hpLbl.Text = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    end)

    table.insert(espObjects, bb)
    table.insert(espObjects, box)
    table.insert(espObjects, conn)
end

local function enableESP()
    clearESP()
    for _,plr in ipairs(Players:GetPlayers()) do
        pcall(createESPForPlayer, plr)
    end
    -- ESP untuk player yang join setelah
    Players.PlayerAdded:Connect(function(plr)
        if not espActive then return end
        plr.CharacterAdded:Connect(function()
            task.wait(1)
            if espActive then pcall(createESPForPlayer, plr) end
        end)
    end)
    -- Update jika char respawn
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            plr.CharacterAdded:Connect(function()
                task.wait(1)
                if espActive then pcall(createESPForPlayer, plr) end
            end)
        end
    end
end

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function formatTime(s)
    return string.format("%dh %dm %ds",math.floor(s/3600),math.floor((s%3600)/60),math.floor(s%60))
end
local function formatMoney(n)
    local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)","% 1"):reverse():gsub("^ ","")
    return "$"..s:gsub(" ",".")
end

local function makeDraggable(frame)
    frame.Active = true
    if not _isMobile then frame.Draggable = true return end
    local drag,di,ds,sp2
    frame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch then
            drag=true ds=i.Position sp2=frame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    frame.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then di=i end end)
    UserInputService.InputChanged:Connect(function(i)
        if i==di and drag then
            local d=i.Position-ds
            frame.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
        end
    end)
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local function createGUI()
    local old = player.PlayerGui:FindFirstChild("VanGG")
    if old then old:Destroy() end

    local SG = Instance.new("ScreenGui")
    SG.Name = "VanGG"
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.IgnoreGuiInset = true
    SG.Parent = player.PlayerGui

    local W,H = 560,420
    local Win = Instance.new("Frame")
    Win.Size = UDim2.new(0,W,0,H)
    Win.Position = UDim2.new(0.5,-W/2,0.5,-H/2)
    Win.BackgroundColor3 = Color3.fromRGB(14,14,14)
    Win.BorderSizePixel = 0
    Win.ClipsDescendants = true
    Win.Parent = SG
    Instance.new("UICorner",Win).CornerRadius = UDim.new(0,10)
    makeDraggable(Win)
    local wstroke = Instance.new("UIStroke",Win)
    wstroke.Color = Color3.fromRGB(35,35,35)
    wstroke.Thickness = 1

    -- ── TITLE BAR ──────────────────────────────────────────
    local TB = Instance.new("Frame")
    TB.Size = UDim2.new(1,0,0,36)
    TB.BackgroundColor3 = Color3.fromRGB(10,10,10)
    TB.BorderSizePixel = 0
    TB.Parent = Win

    local TL = Instance.new("TextLabel")
    TL.Size = UDim2.new(1,-90,1,0)
    TL.Position = UDim2.new(0,14,0,0)
    TL.BackgroundTransparency = 1
    TL.RichText = true
    TL.Text = '<b><font color="rgb(255,255,255)">van</font>'
        ..'<font color="rgb(220,40,40)">.gg</font></b>'
        ..'<font color="rgb(100,100,100)"> | South Bronx  v5.1</font>'
        ..'<font color="rgb(60,180,60)">  🛡️</font>'
    TL.TextSize = 13
    TL.Font = Enum.Font.Gotham
    TL.TextXAlignment = Enum.TextXAlignment.Left
    TL.Parent = TB

    local CB = Instance.new("TextButton")
    CB.Size = UDim2.new(0,28,0,28) CB.Position = UDim2.new(1,-32,0,4)
    CB.BackgroundTransparency = 1 CB.Text = "✕"
    CB.TextColor3 = Color3.fromRGB(120,120,120) CB.TextSize = 15
    CB.Font = Enum.Font.GothamBold CB.Parent = TB
    CB.MouseButton1Click:Connect(function() SG:Destroy() end)

    local MB = Instance.new("TextButton")
    MB.Size = UDim2.new(0,28,0,28) MB.Position = UDim2.new(1,-62,0,4)
    MB.BackgroundTransparency = 1 MB.Text = "─"
    MB.TextColor3 = Color3.fromRGB(120,120,120) MB.TextSize = 13
    MB.Font = Enum.Font.GothamBold MB.Parent = TB
    local mini = false
    MB.MouseButton1Click:Connect(function()
        mini = not mini
        Win.Size = mini and UDim2.new(0,W,0,36) or UDim2.new(0,W,0,H)
    end)

    -- Accent line
    local acc = Instance.new("Frame")
    acc.Size = UDim2.new(1,0,0,2)
    acc.Position = UDim2.new(0,0,0,36)
    acc.BackgroundColor3 = Color3.fromRGB(220,40,40)
    acc.BorderSizePixel = 0
    acc.Parent = Win

    -- ── LEFT PANEL ────────────────────────────────────────
    local LP = Instance.new("ScrollingFrame")
    LP.Size = UDim2.new(0,265,0,H-38-2)
    LP.Position = UDim2.new(0,0,0,40)
    LP.BackgroundTransparency = 1
    LP.BorderSizePixel = 0
    LP.ScrollBarThickness = 2
    LP.ScrollBarImageColor3 = Color3.fromRGB(220,40,40)
    LP.CanvasSize = UDim2.new(0,0,0,700)
    LP.Parent = Win
    Instance.new("UIListLayout",LP).Padding = UDim.new(0,0)

    -- Vertical div
    local vd = Instance.new("Frame")
    vd.Size = UDim2.new(0,1,1,-38) vd.Position = UDim2.new(0,265,0,38)
    vd.BackgroundColor3 = Color3.fromRGB(28,28,28) vd.BorderSizePixel=0 vd.Parent=Win

    -- ── RIGHT PANEL ───────────────────────────────────────
    local RP = Instance.new("ScrollingFrame")
    RP.Size = UDim2.new(0,W-267,0,H-38-2)
    RP.Position = UDim2.new(0,267,0,40)
    RP.BackgroundTransparency = 1
    RP.BorderSizePixel = 0
    RP.ScrollBarThickness = 2
    RP.ScrollBarImageColor3 = Color3.fromRGB(60,60,60)
    RP.CanvasSize = UDim2.new(0,0,0,600)
    RP.Parent = Win
    Instance.new("UIListLayout",RP).Padding = UDim.new(0,0)

    -- ── HELPERS ──────────────────────────────────────────
    local function sp(p,h) local f=Instance.new("Frame") f.Size=UDim2.new(1,0,0,h or 8) f.BackgroundTransparency=1 f.Parent=p end

    local function secHdr(p,txt,col)
        local f=Instance.new("Frame") f.Size=UDim2.new(1,0,0,30) f.BackgroundTransparency=1 f.BorderSizePixel=0 f.Parent=p
        local dot=Instance.new("Frame") dot.Size=UDim2.new(0,3,0,16) dot.Position=UDim2.new(0,10,0.5,-8)
        dot.BackgroundColor3=col or Color3.fromRGB(220,40,40) dot.BorderSizePixel=0 dot.Parent=f
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
        local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-20,1,0) l.Position=UDim2.new(0,20,0,0)
        l.BackgroundTransparency=1 l.Text=txt l.TextColor3=Color3.fromRGB(195,195,195)
        l.TextSize=12 l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=f
    end

    local function togRow(p,lbl,def,cb)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,36) row.BackgroundTransparency=1 row.BorderSizePixel=0 row.Parent=p
        local ll=Instance.new("TextLabel") ll.Size=UDim2.new(0.7,0,1,0) ll.Position=UDim2.new(0,20,0,0)
        ll.BackgroundTransparency=1 ll.Text=lbl ll.TextColor3=def and Color3.fromRGB(190,190,190) or Color3.fromRGB(85,85,85)
        ll.TextSize=12 ll.Font=Enum.Font.Gotham ll.TextXAlignment=Enum.TextXAlignment.Left ll.TextWrapped=true ll.Parent=row
        local bg=Instance.new("Frame") bg.Size=UDim2.new(0,36,0,18) bg.Position=UDim2.new(1,-44,0.5,-9)
        bg.BackgroundColor3=def and Color3.fromRGB(220,40,40) or Color3.fromRGB(38,38,38) bg.BorderSizePixel=0 bg.Parent=row
        Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)
        local kn=Instance.new("Frame") kn.Size=UDim2.new(0,14,0,14)
        kn.Position=def and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
        kn.BackgroundColor3=Color3.fromRGB(255,255,255) kn.BorderSizePixel=0 kn.Parent=bg
        Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)
        local btn=Instance.new("TextButton") btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=row
        local state=def
        btn.MouseButton1Click:Connect(function()
            state=not state
            ll.TextColor3=state and Color3.fromRGB(190,190,190) or Color3.fromRGB(85,85,85)
            local ti=TweenInfo.new(0.13,Enum.EasingStyle.Quad)
            TweenService:Create(bg,ti,{BackgroundColor3=state and Color3.fromRGB(220,40,40) or Color3.fromRGB(38,38,38)}):Play()
            TweenService:Create(kn,ti,{Position=state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
            if cb then cb(state) end
        end)
        return btn
    end

    local function infoRow(p,lbl,val,vc)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,24) row.BackgroundTransparency=1 row.BorderSizePixel=0 row.Parent=p
        local l=Instance.new("TextLabel") l.Size=UDim2.new(0.55,0,1,0) l.Position=UDim2.new(0,12,0,0)
        l.BackgroundTransparency=1 l.Text=lbl l.TextColor3=Color3.fromRGB(90,90,90)
        l.TextSize=11 l.Font=Enum.Font.Gotham l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=row
        local v=Instance.new("TextLabel") v.Size=UDim2.new(0.45,-8,1,0) v.Position=UDim2.new(0.55,0,0,0)
        v.BackgroundTransparency=1 v.Text=val v.TextColor3=vc or Color3.fromRGB(190,190,190)
        v.TextSize=11 v.Font=Enum.Font.GothamBold v.TextXAlignment=Enum.TextXAlignment.Right v.Parent=row
        return v
    end

    -- ═══════════════════════════════════════════════
    -- LEFT PANEL CONTENT
    -- ═══════════════════════════════════════════════
    sp(LP,6)

    -- ── SCAN KOORDINAT ──────────────────────────
    secHdr(LP,"🔍 Scan Koordinat", Color3.fromRGB(40,120,220))
    sp(LP,4)

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(1,-16,0,34)
    scanBtn.BackgroundColor3 = Color3.fromRGB(28,90,200)
    scanBtn.BorderSizePixel = 0
    scanBtn.Text = "🔍  SCAN OTOMATIS"
    scanBtn.TextColor3 = Color3.fromRGB(255,255,255)
    scanBtn.TextSize = 12
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.Parent = LP
    Instance.new("UICorner",scanBtn).CornerRadius = UDim.new(0,7)

    sp(LP,4)
    local scanStatus = Instance.new("TextLabel")
    scanStatus.Size = UDim2.new(1,-16,0,16)
    scanStatus.BackgroundTransparency = 1
    scanStatus.Text = "⬤  Belum di-scan"
    scanStatus.TextColor3 = Color3.fromRGB(90,90,90)
    scanStatus.TextSize = 10
    scanStatus.Font = Enum.Font.Gotham
    scanStatus.TextXAlignment = Enum.TextXAlignment.Left
    scanStatus.RichText = true
    scanStatus.Parent = LP
    sp(LP,4)

    -- Log box
    local logScr = Instance.new("ScrollingFrame")
    logScr.Size = UDim2.new(1,-16,0,90)
    logScr.BackgroundColor3 = Color3.fromRGB(10,10,10)
    logScr.BorderSizePixel = 0
    logScr.ScrollBarThickness = 2
    logScr.ScrollBarImageColor3 = Color3.fromRGB(50,50,50)
    logScr.CanvasSize = UDim2.new(0,0,0,0)
    logScr.Parent = LP
    Instance.new("UICorner",logScr).CornerRadius = UDim.new(0,6)
    local logLL = Instance.new("UIListLayout",logScr) logLL.Padding=UDim.new(0,1)
    local logPad = Instance.new("UIPadding",logScr) logPad.PaddingLeft=UDim.new(0,7) logPad.PaddingTop=UDim.new(0,5)

    local function addLog(txt,col)
        local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-7,0,14)
        l.BackgroundTransparency=1 l.Text=txt l.TextColor3=col or Color3.fromRGB(110,110,110)
        l.TextSize=9 l.Font=Enum.Font.Gotham l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=logScr
        logScr.CanvasSize=UDim2.new(0,0,0,logLL.AbsoluteContentSize.Y+10)
        logScr.CanvasPosition=Vector2.new(0,9e9)
    end

    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text = "⏳ Scanning..."
        scanBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        for _,c in ipairs(logScr:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        task.wait(0.1)

        local count = scanWorkspace()

        for _,line in ipairs(scanLog) do
            local c = Color3.fromRGB(110,110,110)
            if line:find("✅") then c=Color3.fromRGB(50,200,70) end
            if line:find("📊") or line:find("━") then c=Color3.fromRGB(150,150,150) end
            addLog(line,c)
        end

        if count >= 5 then
            scanBtn.Text = "✅  SCAN SELESAI ("..count.."/7)"
            scanBtn.BackgroundColor3 = Color3.fromRGB(25,140,55)
            scanStatus.Text = '<font color="rgb(50,200,70)">⬤  '..count..'/7 terdeteksi — siap!</font>'
        elseif count >= 3 then
            scanBtn.Text = "⚠️  PARSIAL ("..count.."/7)"
            scanBtn.BackgroundColor3 = Color3.fromRGB(150,100,0)
            scanStatus.Text = '<font color="rgb(220,170,0)">⬤  Parsial '..count..'/7</font>'
        else
            scanBtn.Text = "❌  ULANG ("..count.."/7)"
            scanBtn.BackgroundColor3 = Color3.fromRGB(28,90,200)
            scanStatus.Text = '<font color="rgb(220,40,40)">⬤  Hanya '..count..'/7 — pindah area!</font>'
        end
    end)

    sp(LP,10)

    -- ── AUTO FARM ────────────────────────────────
    secHdr(LP,"🍡 Auto Farm Marshmallow", Color3.fromRGB(220,40,40))

    togRow(LP,"Auto Cook & Sell (Full Cycle)",false,function(s)
        farmActive = s
        if s and not isRunning then
            isRunning = true
            task.spawn(function()
                while isRunning and farmActive do
                    if mallowDone >= targetAmount then
                        currentStep = "🎯 Target "..targetAmount.." tercapai!"
                        task.wait(3)
                    else
                        local ok,err = pcall(cookingCycle)
                        if not ok then
                            warn("[van.gg] "..tostring(err))
                            currentStep = "⚠️ Error, retry..."
                            task.wait(3)
                        end
                    end
                end
                isRunning = false
                currentStep = "Idle"
            end)
        elseif not s then
            isRunning = false
        end
    end)

    togRow(LP,"Auto Beli Bahan Saja",false,function(s)
        beliActive = s
        if s and not isRunning then
            isRunning = true
            task.spawn(function()
                while isRunning and beliActive do
                    pcall(beliSemua)
                    task.wait(2)
                end
                isRunning = false
            end)
        elseif not s then isRunning = false end
    end)

    togRow(LP,"Auto Jual Marshmallow Saja",false,function(s)
        jualActive = s
        if s and not isRunning then
            isRunning = true
            task.spawn(function()
                while isRunning and jualActive do
                    pcall(jualMarshmallow)
                    task.wait(1)
                end
                isRunning = false
            end)
        elseif not s then isRunning = false end
    end)

    sp(LP,10)

    -- ── ESP ──────────────────────────────────────
    secHdr(LP,"👁 ESP", Color3.fromRGB(80,80,220))

    togRow(LP,"Player ESP (Box + HP + Name)",false,function(s)
        espActive = s
        if s then
            enableESP()
        else
            clearESP()
        end
    end)

    sp(LP,10)

    -- ── SLIDER TARGET ────────────────────────────
    secHdr(LP,"🎚 Target Marshmallow", Color3.fromRGB(180,40,40))

    local slF = Instance.new("Frame")
    slF.Size = UDim2.new(1,-16,0,54)
    slF.BackgroundColor3 = Color3.fromRGB(20,20,20)
    slF.BorderSizePixel = 0
    slF.Parent = LP
    Instance.new("UICorner",slF).CornerRadius = UDim.new(0,7)

    local slTop = Instance.new("Frame")
    slTop.Size = UDim2.new(1,0,0,22)
    slTop.Position = UDim2.new(0,0,0,4)
    slTop.BackgroundTransparency = 1
    slTop.Parent = slF

    local slDesc = Instance.new("TextLabel")
    slDesc.Size = UDim2.new(0.6,0,1,0)
    slDesc.Position = UDim2.new(0,10,0,0)
    slDesc.BackgroundTransparency = 1
    slDesc.Text = "Jumlah target:"
    slDesc.TextColor3 = Color3.fromRGB(90,90,90)
    slDesc.TextSize = 11
    slDesc.Font = Enum.Font.Gotham
    slDesc.TextXAlignment = Enum.TextXAlignment.Left
    slDesc.Parent = slTop

    local slVal = Instance.new("TextLabel")
    slVal.Size = UDim2.new(0.4,-10,1,0)
    slVal.Position = UDim2.new(0.6,0,0,0)
    slVal.BackgroundTransparency = 1
    slVal.Text = targetAmount.." 🍡"
    slVal.TextColor3 = Color3.fromRGB(220,40,40)
    slVal.TextSize = 12
    slVal.Font = Enum.Font.GothamBold
    slVal.TextXAlignment = Enum.TextXAlignment.Right
    slVal.Parent = slTop

    local trk = Instance.new("Frame")
    trk.Size = UDim2.new(1,-20,0,6)
    trk.Position = UDim2.new(0,10,0,34)
    trk.BackgroundColor3 = Color3.fromRGB(35,35,35)
    trk.BorderSizePixel = 0
    trk.Parent = slF
    Instance.new("UICorner",trk).CornerRadius = UDim.new(1,0)

    local slFill = Instance.new("Frame")
    slFill.Size = UDim2.new((targetAmount-1)/499,0,1,0)
    slFill.BackgroundColor3 = Color3.fromRGB(220,40,40)
    slFill.BorderSizePixel = 0
    slFill.Parent = trk
    Instance.new("UICorner",slFill).CornerRadius = UDim.new(1,0)

    local slKnob = Instance.new("Frame")
    slKnob.Size = UDim2.new(0,14,0,14)
    slKnob.AnchorPoint = Vector2.new(0.5,0.5)
    slKnob.Position = UDim2.new((targetAmount-1)/499,0,0.5,0)
    slKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    slKnob.BorderSizePixel = 0
    slKnob.ZIndex = 3
    slKnob.Parent = trk
    Instance.new("UICorner",slKnob).CornerRadius = UDim.new(1,0)

    local slHit = Instance.new("TextButton")
    slHit.Size = UDim2.new(1,0,0,26)
    slHit.Position = UDim2.new(0,0,0,22)
    slHit.BackgroundTransparency = 1
    slHit.Text = ""
    slHit.ZIndex = 4
    slHit.Parent = slF

    local slDrag = false
    local function updateSlider(ax)
        local tp = trk.AbsolutePosition
        local ts = trk.AbsoluteSize
        local rel = math.clamp((ax-tp.X)/ts.X,0,1)
        targetAmount = math.floor(rel*499)+1
        slVal.Text = targetAmount.." 🍡"
        slFill.Size = UDim2.new(rel,0,1,0)
        slKnob.Position = UDim2.new(rel,0,0.5,0)
    end
    slHit.MouseButton1Down:Connect(function() slDrag=true end)
    UserInputService.InputChanged:Connect(function(i)
        if slDrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            updateSlider(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            slDrag=false
        end
    end)

    sp(LP,8)

    -- Reset btn
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1,-16,0,30)
    resetBtn.BackgroundColor3 = Color3.fromRGB(24,24,24)
    resetBtn.BorderSizePixel = 0
    resetBtn.Text = "🔄  Reset Counter"
    resetBtn.TextColor3 = Color3.fromRGB(120,120,120)
    resetBtn.TextSize = 11
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.Parent = LP
    Instance.new("UICorner",resetBtn).CornerRadius = UDim.new(0,6)
    resetBtn.MouseButton1Click:Connect(function()
        mallowDone=0 moneyGained=0 cycleCount=0 sessionStart=tick()
    end)

    sp(LP,60)

    -- ═══════════════════════════════════════════════
    -- RIGHT PANEL CONTENT
    -- ═══════════════════════════════════════════════
    sp(RP,8)
    secHdr(RP,"📊 Stats", Color3.fromRGB(220,40,40))

    local timeLbl   = infoRow(RP,"Waktu Farming","0h 0m 0s",Color3.fromRGB(190,190,190))
    local moneyLbl  = infoRow(RP,"Uang Didapat","$0",Color3.fromRGB(60,210,90))
    local cycleLbl  = infoRow(RP,"Siklus Selesai","0",Color3.fromRGB(150,150,255))
    local mallowLbl = infoRow(RP,"Marshmallow","0 / 10",Color3.fromRGB(255,200,80))
    local stepLbl   = infoRow(RP,"Status","Idle",Color3.fromRGB(220,220,80))

    -- Divider
    local dv2=Instance.new("Frame") dv2.Size=UDim2.new(1,-16,0,1) dv2.BackgroundColor3=Color3.fromRGB(28,28,28) dv2.BorderSizePixel=0 dv2.Parent=RP
    sp(RP,8)

    -- Koordinat status
    secHdr(RP,"📍 Koordinat Terdeteksi", Color3.fromRGB(60,60,60))

    local coordLabels = {}
    local coordKeys = {"WATER","SUGAR","GELATIN","POT","BAG","SELL","MALLOW"}
    local coordNames = {WATER="Water NPC",SUGAR="Sugar NPC",GELATIN="Gelatin NPC",POT="Cooking Pot",BAG="Empty Bag",SELL="Sell NPC",MALLOW="Marshmallow"}
    for _,k in ipairs(coordKeys) do
        coordLabels[k] = infoRow(RP, coordNames[k], "❌ Belum scan", Color3.fromRGB(180,50,50))
    end

    sp(RP,8)
    local dv3=Instance.new("Frame") dv3.Size=UDim2.new(1,-16,0,1) dv3.BackgroundColor3=Color3.fromRGB(28,28,28) dv3.BorderSizePixel=0 dv3.Parent=RP
    sp(RP,8)

    secHdr(RP,"ℹ️  Cara Pakai", Color3.fromRGB(50,50,50))
    local helpBox=Instance.new("Frame") helpBox.Size=UDim2.new(1,-16,0,100) helpBox.BackgroundColor3=Color3.fromRGB(18,18,18) helpBox.BorderSizePixel=0 helpBox.Parent=RP
    Instance.new("UICorner",helpBox).CornerRadius=UDim.new(0,7)
    local hpad=Instance.new("UIPadding",helpBox) hpad.PaddingLeft=UDim.new(0,10) hpad.PaddingTop=UDim.new(0,8) hpad.PaddingRight=UDim.new(0,8)
    local htxt=Instance.new("TextLabel") htxt.Size=UDim2.new(1,0,1,0) htxt.BackgroundTransparency=1
    htxt.Text="1️⃣  Pergi ke area NPC South Bronx\n2️⃣  Klik SCAN OTOMATIS\n3️⃣  Tunggu hasil scan (min 5/7)\n4️⃣  Nyalakan Auto Cook & Sell\n5️⃣  Set target slider lalu farming!"
    htxt.TextColor3=Color3.fromRGB(85,85,85) htxt.TextSize=10 htxt.Font=Enum.Font.Gotham
    htxt.TextXAlignment=Enum.TextXAlignment.Left htxt.TextWrapped=true htxt.Parent=helpBox

    sp(RP,60)

    -- ── LIVE UPDATE ───────────────────────────────
    task.spawn(function()
        while SG.Parent do
            timeLbl.Text   = formatTime(tick()-sessionStart)
            moneyLbl.Text  = formatMoney(moneyGained)
            cycleLbl.Text  = tostring(cycleCount)
            mallowLbl.Text = mallowDone.." / "..targetAmount
            stepLbl.Text   = currentStep
            moneyLbl.TextColor3 = moneyGained>0 and Color3.fromRGB(60,210,90) or Color3.fromRGB(90,90,90)
            mallowLbl.TextColor3 = mallowDone>=targetAmount and Color3.fromRGB(60,210,90) or Color3.fromRGB(255,200,80)
            -- Update koordinat labels
            for _,k in ipairs(coordKeys) do
                if COORDS[k] then
                    local p = COORDS[k]
                    coordLabels[k].Text = string.format("%.0f, %.0f, %.0f",p.X,p.Y,p.Z)
                    coordLabels[k].TextColor3 = Color3.fromRGB(60,200,80)
                else
                    coordLabels[k].Text = "❌ Belum scan"
                    coordLabels[k].TextColor3 = Color3.fromRGB(180,50,50)
                end
            end
            task.wait(0.5)
        end
    end)

    return SG
end

-- ============================================================
-- LAUNCH
-- ============================================================
createGUI()
print("[van.gg v5.1] ✅ Loaded! Anti-Kick & Anti-Ban aktif!")
print("[van.gg v5.1] Scan koordinat dulu sebelum farming!")
