-- ============================================================
--   REYVAN STORE v4.0 - South Bronx : The Trenches
--   Auto Cook & Sell Marshmallow
--   Support: PC / Android / Xeno Executor
-- ============================================================

-- ============================================================
-- EXECUTOR COMPAT
-- ============================================================
local _G_ENV = getfenv and getfenv() or _ENV or {}
local _fireprox = (typeof(fireproximityprompt)=="function" and fireproximityprompt)
    or (typeof(_G_ENV.fireproximityprompt)=="function" and _G_ENV.fireproximityprompt)
    or function(p) if p and p.HoldDuration<=0 then p.Triggered:Fire() end end
local _fireclk = (typeof(fireclickdetector)=="function" and fireclickdetector)
    or (typeof(_G_ENV.fireclickdetector)=="function" and _G_ENV.fireclickdetector)
    or function(d) if d and d.MouseClick then pcall(function() d.MouseClick:Fire(game:GetService("Players").LocalPlayer) end) end end

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

local _isMobile = UserInputService.TouchEnabled

-- ============================================================
-- CONFIG - Koordinat South Bronx NPC (sesuaikan jika perlu)
-- ============================================================
local CONFIG = {
    -- Posisi item / NPC di map South Bronx
    WATER_POS        = Vector3.new(0,   0, 0),   -- NPC/item Water
    SUGAR_POS        = Vector3.new(10,  0, 0),   -- NPC/item Sugar Block
    GELATIN_POS      = Vector3.new(20,  0, 0),   -- NPC/item Gelatin
    POT_POS          = Vector3.new(30,  0, 0),   -- Cooking Pot
    BAG_POS          = Vector3.new(40,  0, 0),   -- Empty Bag
    RESULT_POS       = Vector3.new(50,  0, 0),   -- Tempat ambil hasil
    SELL_POS         = Vector3.new(90,  0, 0),   -- NPC Jual Marshmallow

    -- Nama objek
    WATER_NAME       = "Water",
    SUGAR_NAME       = "SugarBlock",
    GELATIN_NAME     = "Gelatin",
    BAG_NAME         = "EmptyBag",
    POT_NAME         = "CookingPot",
    MALLOW_NAME      = "Marshmallow",
    SELL_NAME        = "SellNPC",

    -- Timing
    WATER_COOK_TIME  = 20,
    MIX_COOK_TIME    = 45,
    ACTION_DELAY     = 0.5,
    WALK_TIMEOUT     = 15,
    INTERACT_DIST    = 8,

    -- Harga
    MALLOW_PRICE     = 950,
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning        = false
local farmActive       = false
local targetAmount     = 10       -- jumlah marshmallow target (slider 1-500)
local marshmallowDone  = 0
local moneyGained      = 0
local cycleCount       = 0
local sessionStart     = tick()
local currentStep      = "Idle"

-- ============================================================
-- UTILITY
-- ============================================================
local function walkTo(pos)
    if not isRunning then return end
    humanoid:MoveTo(pos)
    local t = tick()
    repeat RunService.Heartbeat:Wait()
        if not isRunning then return end
        if tick()-t > CONFIG.WALK_TIMEOUT then break end
    until (rootPart.Position - pos).Magnitude < CONFIG.INTERACT_DIST
end

local function waitSec(s)
    if not isRunning then return end
    local t = tick()
    repeat RunService.Heartbeat:Wait()
        if not isRunning then return end
    until tick()-t >= s
end

local function findNearby(name, pos, r)
    r = r or 20
    for _,o in pairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and o.Name:lower():find(name:lower(),1,true) then
            if (o.Position-pos).Magnitude <= r then return o end
        end
    end
end

local function interact(item)
    if not item then return false end
    local p = item:FindFirstChildOfClass("ProximityPrompt")
        or (item.Parent and item.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if p then _fireprox(p) return true end
    local c = item:FindFirstChildOfClass("ClickDetector")
        or (item.Parent and item.Parent:FindFirstChildOfClass("ClickDetector"))
    if c then _fireclk(c) return true end
    return false
end

-- ============================================================
-- BELI BAHAN (Water, Sugar Block, Gelatin) dari NPC South Bronx
-- ============================================================
local function beliWater()
    currentStep = "Beli Water"
    walkTo(CONFIG.WATER_POS)
    task.wait(CONFIG.ACTION_DELAY)
    local npc = findNearby(CONFIG.WATER_NAME, CONFIG.WATER_POS, 15)
             or findNearby("shop", CONFIG.WATER_POS, 15)
    if npc then interact(npc) task.wait(0.3) end
end

local function beliSugar()
    currentStep = "Beli Sugar Block"
    walkTo(CONFIG.SUGAR_POS)
    task.wait(CONFIG.ACTION_DELAY)
    local npc = findNearby(CONFIG.SUGAR_NAME, CONFIG.SUGAR_POS, 15)
             or findNearby("shop", CONFIG.SUGAR_POS, 15)
    if npc then interact(npc) task.wait(0.3) end
end

local function beliGelatin()
    currentStep = "Beli Gelatin"
    walkTo(CONFIG.GELATIN_POS)
    task.wait(CONFIG.ACTION_DELAY)
    local npc = findNearby(CONFIG.GELATIN_NAME, CONFIG.GELATIN_POS, 15)
             or findNearby("shop", CONFIG.GELATIN_POS, 15)
    if npc then interact(npc) task.wait(0.3) end
end

-- ============================================================
-- JUAL MARSHMALLOW di NPC South Bronx
-- ============================================================
local function jualMarshmallow()
    currentStep = "Jual Marshmallow"
    walkTo(CONFIG.SELL_POS)
    task.wait(CONFIG.ACTION_DELAY)
    local npc = findNearby(CONFIG.SELL_NAME, CONFIG.SELL_POS, 15)
             or findNearby("sell", CONFIG.SELL_POS, 15)
             or findNearby("dealer", CONFIG.SELL_POS, 15)
    if npc then
        interact(npc) task.wait(0.4)
        interact(npc) task.wait(CONFIG.ACTION_DELAY)
        moneyGained += CONFIG.MALLOW_PRICE
        marshmallowDone += 1
    end
end

-- ============================================================
-- SATU SIKLUS MASAK
-- ============================================================
local function cookingCycle()
    -- 1. Beli semua bahan
    beliWater()
    if not isRunning then return end
    beliSugar()
    if not isRunning then return end
    beliGelatin()
    if not isRunning then return end

    -- 2. Masak Water dulu
    currentStep = "Ambil Water"
    walkTo(CONFIG.WATER_POS) task.wait(CONFIG.ACTION_DELAY)
    local water = findNearby(CONFIG.WATER_NAME, CONFIG.WATER_POS)
    if water then interact(water) task.wait(CONFIG.ACTION_DELAY) end

    currentStep = "Masak Water"
    walkTo(CONFIG.POT_POS) task.wait(CONFIG.ACTION_DELAY)
    local pot = findNearby(CONFIG.POT_NAME, CONFIG.POT_POS)
    if pot then interact(pot) task.wait(CONFIG.ACTION_DELAY) end
    waitSec(CONFIG.WATER_COOK_TIME)
    if not isRunning then return end

    -- 3. Masukkan Sugar Block & Gelatin
    currentStep = "Ambil Sugar Block"
    walkTo(CONFIG.SUGAR_POS) task.wait(CONFIG.ACTION_DELAY)
    local sugar = findNearby(CONFIG.SUGAR_NAME, CONFIG.SUGAR_POS)
    if sugar then interact(sugar) task.wait(CONFIG.ACTION_DELAY) end

    currentStep = "Ambil Gelatin"
    walkTo(CONFIG.GELATIN_POS) task.wait(CONFIG.ACTION_DELAY)
    local gel = findNearby(CONFIG.GELATIN_NAME, CONFIG.GELATIN_POS)
    if gel then interact(gel) task.wait(CONFIG.ACTION_DELAY) end

    -- 4. Masak campuran
    currentStep = "Masak Campuran"
    walkTo(CONFIG.POT_POS) task.wait(CONFIG.ACTION_DELAY)
    pot = findNearby(CONFIG.POT_NAME, CONFIG.POT_POS)
    if pot then
        interact(pot) task.wait(0.3)
        interact(pot) task.wait(CONFIG.ACTION_DELAY)
    end
    waitSec(CONFIG.MIX_COOK_TIME)
    if not isRunning then return end

    -- 5. Ambil Empty Bag & Kemas
    currentStep = "Ambil Empty Bag"
    walkTo(CONFIG.BAG_POS) task.wait(CONFIG.ACTION_DELAY)
    local bag = findNearby(CONFIG.BAG_NAME, CONFIG.BAG_POS)
    if bag then interact(bag) task.wait(CONFIG.ACTION_DELAY) end

    currentStep = "Kemas Marshmallow"
    walkTo(CONFIG.POT_POS) task.wait(CONFIG.ACTION_DELAY)
    pot = findNearby(CONFIG.POT_NAME, CONFIG.POT_POS)
    if pot then interact(pot) task.wait(CONFIG.ACTION_DELAY) end

    -- 6. Ambil hasil
    currentStep = "Ambil Hasil"
    walkTo(CONFIG.RESULT_POS) task.wait(CONFIG.ACTION_DELAY)
    local result = findNearby(CONFIG.MALLOW_NAME, CONFIG.RESULT_POS)
    if result then interact(result) task.wait(CONFIG.ACTION_DELAY) end

    -- 7. Jual
    jualMarshmallow()

    cycleCount += 1
    currentStep = "Siklus #"..cycleCount.." selesai"
    task.wait(1)
end

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function formatTime(s)
    return string.format("%dh %dm %ds", math.floor(s/3600), math.floor((s%3600)/60), math.floor(s%60))
end
local function formatMoney(n)
    return "$"..tostring(math.floor(n)):reverse():gsub("(%d%d%d)","% 1"):reverse():gsub("^ ",""):gsub(" ",".")
end

local function makeDraggable(frame)
    frame.Active = true
    if not _isMobile then frame.Draggable = true return end
    local drag, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            drag=true dragStart=i.Position startPos=frame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then dragInput=i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i==dragInput and drag then
            local d=i.Position-dragStart
            frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

-- ============================================================
-- GUI MAIN
-- ============================================================
local function createGUI()
    local old = player.PlayerGui:FindFirstChild("ReyvanStore")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ReyvanStore"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = player.PlayerGui

    -- Window
    local W, H = 520, 380
    local Win = Instance.new("Frame")
    Win.Size = UDim2.new(0,W,0,H)
    Win.Position = UDim2.new(0.5,-W/2,0.5,-H/2)
    Win.BackgroundColor3 = Color3.fromRGB(18,18,18)
    Win.BorderSizePixel = 0
    Win.ClipsDescendants = true
    Win.Parent = ScreenGui
    Instance.new("UICorner",Win).CornerRadius = UDim.new(0,10)
    makeDraggable(Win)
    local stroke = Instance.new("UIStroke",Win)
    stroke.Color = Color3.fromRGB(45,45,45)
    stroke.Thickness = 1

    -- Title bar
    local TB = Instance.new("Frame")
    TB.Size = UDim2.new(1,0,0,36)
    TB.BackgroundColor3 = Color3.fromRGB(13,13,13)
    TB.BorderSizePixel = 0
    TB.Parent = Win

    local TL = Instance.new("TextLabel")
    TL.Size = UDim2.new(1,-80,1,0)
    TL.Position = UDim2.new(0,14,0,0)
    TL.BackgroundTransparency = 1
    TL.RichText = true
    TL.Text = '<font color="rgb(255,255,255)"><b>reyvan</b></font>'
        ..'<font color="rgb(220,40,40)"><b>.gg</b></font>'
        ..'<font color="rgb(140,140,140)"> | South Bronx</font>'
        ..'<font color="rgb(80,80,80)"> v4.0</font>'
    TL.TextSize = 13
    TL.Font = Enum.Font.Gotham
    TL.TextXAlignment = Enum.TextXAlignment.Left
    TL.Parent = TB

    -- Close btn
    local CB = Instance.new("TextButton")
    CB.Size = UDim2.new(0,30,0,30)
    CB.Position = UDim2.new(1,-34,0,3)
    CB.BackgroundTransparency = 1
    CB.Text = "✕"
    CB.TextColor3 = Color3.fromRGB(140,140,140)
    CB.TextSize = 16
    CB.Font = Enum.Font.GothamBold
    CB.Parent = TB
    CB.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Minimize
    local MB = Instance.new("TextButton")
    MB.Size = UDim2.new(0,30,0,30)
    MB.Position = UDim2.new(1,-66,0,3)
    MB.BackgroundTransparency = 1
    MB.Text = "─"
    MB.TextColor3 = Color3.fromRGB(140,140,140)
    MB.TextSize = 14
    MB.Font = Enum.Font.GothamBold
    MB.Parent = TB
    local mini = false
    MB.MouseButton1Click:Connect(function()
        mini = not mini
        Win.Size = mini and UDim2.new(0,W,0,36) or UDim2.new(0,W,0,H)
    end)

    -- Divider
    local div0 = Instance.new("Frame")
    div0.Size = UDim2.new(1,0,0,1)
    div0.Position = UDim2.new(0,0,0,36)
    div0.BackgroundColor3 = Color3.fromRGB(32,32,32)
    div0.BorderSizePixel = 0
    div0.Parent = Win

    -- ── LEFT PANEL (features) ──────────────────────────────────
    local LP = Instance.new("ScrollingFrame")
    LP.Size = UDim2.new(0,248,0,H-36-2)
    LP.Position = UDim2.new(0,0,0,38)
    LP.BackgroundTransparency = 1
    LP.BorderSizePixel = 0
    LP.ScrollBarThickness = 2
    LP.ScrollBarImageColor3 = Color3.fromRGB(220,40,40)
    LP.CanvasSize = UDim2.new(0,0,0,600)
    LP.Parent = Win
    local LLL = Instance.new("UIListLayout",LP)
    LLL.Padding = UDim.new(0,0)

    -- Vertical divider
    local vd = Instance.new("Frame")
    vd.Size = UDim2.new(0,1,0,H-36)
    vd.Position = UDim2.new(0,248,0,36)
    vd.BackgroundColor3 = Color3.fromRGB(32,32,32)
    vd.BorderSizePixel = 0
    vd.Parent = Win

    -- ── RIGHT PANEL (stats) ────────────────────────────────────
    local RP = Instance.new("Frame")
    RP.Size = UDim2.new(0,W-250,0,H-36-2)
    RP.Position = UDim2.new(0,250,0,38)
    RP.BackgroundTransparency = 1
    RP.BorderSizePixel = 0
    RP.Parent = Win
    local RLL = Instance.new("UIListLayout",RP)
    RLL.Padding = UDim.new(0,0)

    -- ── HELPERS ───────────────────────────────────────────────
    local function sp(parent, h)
        local f=Instance.new("Frame") f.Size=UDim2.new(1,0,0,h or 8) f.BackgroundTransparency=1 f.Parent=parent
    end

    local function secHeader(parent, txt, col)
        local f=Instance.new("Frame") f.Size=UDim2.new(1,0,0,32) f.BackgroundTransparency=1 f.BorderSizePixel=0 f.Parent=parent
        local dot=Instance.new("Frame") dot.Size=UDim2.new(0,3,0,18) dot.Position=UDim2.new(0,12,0.5,-9)
        dot.BackgroundColor3=col or Color3.fromRGB(220,40,40) dot.BorderSizePixel=0 dot.Parent=f
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
        local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-22,1,0) l.Position=UDim2.new(0,22,0,0)
        l.BackgroundTransparency=1 l.Text=txt l.TextColor3=Color3.fromRGB(200,200,200)
        l.TextSize=12 l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=f
        return f
    end

    local function toggleRow(parent, label, default, cb)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,36) row.BackgroundTransparency=1 row.BorderSizePixel=0 row.Parent=parent
        local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(0.72,0,1,0) lbl.Position=UDim2.new(0,22,0,0)
        lbl.BackgroundTransparency=1 lbl.Text=label lbl.TextColor3=default and Color3.fromRGB(195,195,195) or Color3.fromRGB(90,90,90)
        lbl.TextSize=12 lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.TextWrapped=true lbl.Parent=row
        local bg=Instance.new("Frame") bg.Size=UDim2.new(0,36,0,18) bg.Position=UDim2.new(1,-46,0.5,-9)
        bg.BackgroundColor3=default and Color3.fromRGB(220,40,40) or Color3.fromRGB(42,42,42) bg.BorderSizePixel=0 bg.Parent=row
        Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)
        local knob=Instance.new("Frame") knob.Size=UDim2.new(0,14,0,14)
        knob.Position=default and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
        knob.BackgroundColor3=Color3.fromRGB(255,255,255) knob.BorderSizePixel=0 knob.Parent=bg
        Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
        local btn=Instance.new("TextButton") btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.Parent=row
        local state=default
        btn.MouseButton1Click:Connect(function()
            state=not state
            lbl.TextColor3=state and Color3.fromRGB(195,195,195) or Color3.fromRGB(90,90,90)
            local ti=TweenInfo.new(0.14,Enum.EasingStyle.Quad)
            TweenService:Create(bg,ti,{BackgroundColor3=state and Color3.fromRGB(220,40,40) or Color3.fromRGB(42,42,42)}):Play()
            TweenService:Create(knob,ti,{Position=state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
            if cb then cb(state) end
        end)
        return row
    end

    local function infoRow(parent, label, val, vcol)
        local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,26) row.BackgroundTransparency=1 row.BorderSizePixel=0 row.Parent=parent
        local l=Instance.new("TextLabel") l.Size=UDim2.new(0.58,0,1,0) l.Position=UDim2.new(0,14,0,0)
        l.BackgroundTransparency=1 l.Text=label l.TextColor3=Color3.fromRGB(110,110,110)
        l.TextSize=11 l.Font=Enum.Font.Gotham l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=row
        local v=Instance.new("TextLabel") v.Size=UDim2.new(0.42,-8,1,0) v.Position=UDim2.new(0.58,0,0,0)
        v.BackgroundTransparency=1 v.Text=val v.TextColor3=vcol or Color3.fromRGB(195,195,195)
        v.TextSize=11 v.Font=Enum.Font.GothamBold v.TextXAlignment=Enum.TextXAlignment.Right v.Parent=row
        return v
    end

    -- ══════════════════════════════════════════════
    -- LEFT PANEL CONTENT
    -- ══════════════════════════════════════════════

    -- Section: Auto Cook Marshmallow
    sp(LP,6)
    secHeader(LP,"🍡 Auto Cook Marshmallow", Color3.fromRGB(220,40,40))

    -- Info box
    local ib=Instance.new("Frame") ib.Size=UDim2.new(1,-16,0,50) ib.BackgroundColor3=Color3.fromRGB(22,22,22)
    ib.BorderSizePixel=0 ib.Parent=LP
    Instance.new("UICorner",ib).CornerRadius=UDim.new(0,6)
    local ip=Instance.new("UIPadding",ib) ip.PaddingLeft=UDim.new(0,10) ip.PaddingRight=UDim.new(0,10) ip.PaddingTop=UDim.new(0,6)
    local it=Instance.new("TextLabel") it.Size=UDim2.new(1,0,1,0) it.BackgroundTransparency=1
    it.Text="Script otomatis beli Water, Sugar Block & Gelatin\ndari NPC South Bronx → masak → jual hasil."
    it.TextColor3=Color3.fromRGB(105,105,105) it.TextSize=10 it.Font=Enum.Font.Gotham
    it.TextXAlignment=Enum.TextXAlignment.Left it.TextWrapped=true it.Parent=ib
    sp(LP,6)

    -- Toggle: Auto Cook & Sell
    toggleRow(LP, "Auto Cook Marshmallow", false, function(s)
        farmActive = s
        if s and not isRunning then
            isRunning = true
            task.spawn(function()
                while isRunning and farmActive do
                    if marshmallowDone >= targetAmount then
                        currentStep = "Target tercapai! ("..marshmallowDone.."/"..targetAmount..")"
                        task.wait(2)
                    else
                        local ok, err = pcall(cookingCycle)
                        if not ok then
                            warn("[ReyvanStore] "..tostring(err))
                            task.wait(2)
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

    -- Toggle: Auto Beli Bahan saja
    toggleRow(LP, "Auto Beli Bahan (Water/Sugar/Gelatin)", false, function(s)
        if s and not isRunning then
            isRunning = true
            task.spawn(function()
                while isRunning do
                    local ok,err = pcall(function()
                        beliWater() beliSugar() beliGelatin()
                        task.wait(1)
                    end)
                    if not ok then task.wait(2) end
                end
            end)
        elseif not s then isRunning=false end
    end)

    -- Toggle: Auto Jual Marshmallow saja
    toggleRow(LP, "Auto Jual Marshmallow", false, function(s)
        if s and not isRunning then
            isRunning = true
            task.spawn(function()
                while isRunning do
                    local ok,err = pcall(jualMarshmallow)
                    if not ok then task.wait(2) end
                    task.wait(0.5)
                end
            end)
        elseif not s then isRunning=false end
    end)

    sp(LP,10)

    -- ── SLIDER: Marshmallow Amount (1-500) ──────────────────────
    secHeader(LP,"🎚  Marshmallow Target", Color3.fromRGB(180,40,40))

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1,-16,0,52)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(22,22,22)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = LP
    Instance.new("UICorner",sliderFrame).CornerRadius = UDim.new(0,6)

    -- Label atas slider
    local sliderLabelRow = Instance.new("Frame")
    sliderLabelRow.Size = UDim2.new(1,0,0,22)
    sliderLabelRow.Position = UDim2.new(0,0,0,4)
    sliderLabelRow.BackgroundTransparency = 1
    sliderLabelRow.Parent = sliderFrame

    local sliderDesc = Instance.new("TextLabel")
    sliderDesc.Size = UDim2.new(0.6,0,1,0)
    sliderDesc.Position = UDim2.new(0,10,0,0)
    sliderDesc.BackgroundTransparency = 1
    sliderDesc.Text = "Jumlah target:"
    sliderDesc.TextColor3 = Color3.fromRGB(110,110,110)
    sliderDesc.TextSize = 11
    sliderDesc.Font = Enum.Font.Gotham
    sliderDesc.TextXAlignment = Enum.TextXAlignment.Left
    sliderDesc.Parent = sliderLabelRow

    local sliderValLbl = Instance.new("TextLabel")
    sliderValLbl.Size = UDim2.new(0.4,-10,1,0)
    sliderValLbl.Position = UDim2.new(0.6,0,0,0)
    sliderValLbl.BackgroundTransparency = 1
    sliderValLbl.Text = tostring(targetAmount).." 🍡"
    sliderValLbl.TextColor3 = Color3.fromRGB(220,40,40)
    sliderValLbl.TextSize = 12
    sliderValLbl.Font = Enum.Font.GothamBold
    sliderValLbl.TextXAlignment = Enum.TextXAlignment.Right
    sliderValLbl.Parent = sliderLabelRow

    -- Track
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-20,0,6)
    track.Position = UDim2.new(0,10,0,32)
    track.BackgroundColor3 = Color3.fromRGB(38,38,38)
    track.BorderSizePixel = 0
    track.Parent = sliderFrame
    Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

    -- Fill
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((targetAmount-1)/499,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(220,40,40)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

    -- Knob
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,14,0,14)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new((targetAmount-1)/499,0,0.5,0)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = track
    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)
    local ks = Instance.new("UIStroke",knob) ks.Color=Color3.fromRGB(180,30,30) ks.Thickness=2

    -- Slider input (drag)
    local sliderDragging = false
    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.new(1,0,0,24)
    hitbox.Position = UDim2.new(0,0,0,20)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 4
    hitbox.Parent = sliderFrame

    local function updateSlider(absX)
        local tAbs = track.AbsolutePosition
        local tSize = track.AbsoluteSize
        local rel = math.clamp((absX - tAbs.X) / tSize.X, 0, 1)
        targetAmount = math.floor(rel * 499) + 1
        sliderValLbl.Text = tostring(targetAmount).." 🍡"
        fill.Size = UDim2.new(rel,0,1,0)
        knob.Position = UDim2.new(rel,0,0.5,0)
    end

    hitbox.MouseButton1Down:Connect(function() sliderDragging=true end)
    hitbox.MouseButton1Up:Connect(function() sliderDragging=false end)
    hitbox.MouseLeave:Connect(function() sliderDragging=false end)
    UserInputService.InputChanged:Connect(function(i)
        if sliderDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            updateSlider(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            sliderDragging=false
        end
    end)
    hitbox.MouseButton1Click:Connect(function()
        local mouse = player:GetMouse()
        updateSlider(mouse.X)
    end)

    sp(LP,8)

    -- ── Reset counter button ─────────────────────────────────
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1,-16,0,30)
    resetBtn.BackgroundColor3 = Color3.fromRGB(28,28,28)
    resetBtn.BorderSizePixel = 0
    resetBtn.Text = "🔄  Reset Counter"
    resetBtn.TextColor3 = Color3.fromRGB(140,140,140)
    resetBtn.TextSize = 12
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.Parent = LP
    Instance.new("UICorner",resetBtn).CornerRadius = UDim.new(0,6)
    resetBtn.MouseButton1Click:Connect(function()
        marshmallowDone = 0
        moneyGained = 0
        cycleCount = 0
        sessionStart = tick()
    end)

    sp(LP,50)

    -- ══════════════════════════════════════════════
    -- RIGHT PANEL CONTENT (Stats)
    -- ══════════════════════════════════════════════
    sp(RP,10)
    secHeader(RP,"📊 Stats", Color3.fromRGB(220,40,40))

    local timeLbl   = infoRow(RP, "Waktu Farming",   "0h 0m 0s",  Color3.fromRGB(200,200,200))
    local moneyLbl  = infoRow(RP, "Uang Didapat",    "$0",        Color3.fromRGB(60,210,100))
    local cycleLbl  = infoRow(RP, "Siklus Selesai",  "0",         Color3.fromRGB(160,160,255))
    local mallowLbl = infoRow(RP, "Marshmallow",     "0 / ?",     Color3.fromRGB(255,200,80))
    local stepLbl   = infoRow(RP, "Langkah",         "Idle",      Color3.fromRGB(220,220,100))

    -- divider
    local dv=Instance.new("Frame") dv.Size=UDim2.new(1,-16,0,1) dv.BackgroundColor3=Color3.fromRGB(32,32,32) dv.BorderSizePixel=0 dv.Parent=RP
    sp(RP,8)

    secHeader(RP,"ℹ️  Info", Color3.fromRGB(60,60,60))
    local ib2=Instance.new("Frame") ib2.Size=UDim2.new(1,-16,0,80) ib2.BackgroundColor3=Color3.fromRGB(20,20,20) ib2.BorderSizePixel=0 ib2.Parent=RP
    Instance.new("UICorner",ib2).CornerRadius=UDim.new(0,6)
    local ip2=Instance.new("UIPadding",ib2) ip2.PaddingLeft=UDim.new(0,10) ip2.PaddingTop=UDim.new(0,8) ip2.PaddingRight=UDim.new(0,10)
    local it2=Instance.new("TextLabel") it2.Size=UDim2.new(1,0,1,0) it2.BackgroundTransparency=1
    it2.Text="⚙️ Sebelum farming, pastikan\nkarakter kamu sudah dekat area\nNPC South Bronx di map.\n\n📍 Koordinat bisa diubah di CONFIG."
    it2.TextColor3=Color3.fromRGB(90,90,90) it2.TextSize=10 it2.Font=Enum.Font.Gotham
    it2.TextXAlignment=Enum.TextXAlignment.Left it2.TextWrapped=true it2.Parent=ib2

    -- Live update
    task.spawn(function()
        while ScreenGui.Parent do
            timeLbl.Text   = formatTime(tick()-sessionStart)
            moneyLbl.Text  = formatMoney(moneyGained)
            cycleLbl.Text  = tostring(cycleCount)
            mallowLbl.Text = marshmallowDone.." / "..targetAmount
            stepLbl.Text   = currentStep
            -- color money
            moneyLbl.TextColor3 = moneyGained>0 and Color3.fromRGB(60,210,100) or Color3.fromRGB(110,110,110)
            -- progress bar color on target
            if marshmallowDone >= targetAmount then
                mallowLbl.TextColor3 = Color3.fromRGB(60,210,100)
            else
                mallowLbl.TextColor3 = Color3.fromRGB(255,200,80)
            end
            task.wait(0.5)
        end
    end)

    return ScreenGui
end

-- ============================================================
-- LAUNCH
-- ============================================================
createGUI()
print("[REYVAN STORE v4.0] ✅ Loaded! South Bronx Auto Cook & Sell Marshmallow")
