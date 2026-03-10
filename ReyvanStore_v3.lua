-- ============================================================
--   REYVAN STORE v3.0 - South Bronx : The Trenches
--   Auto Farm Marshmallow + Auto-Detect Koordinat
--   Style: valary.gg inspired dark UI
--   Support: PC / Android / Xeno Executor
-- ============================================================

-- ============================================================
-- EXECUTOR COMPATIBILITY LAYER
-- Support: Synapse X, KRNL, Fluxus, Xeno (Android), Delta, Arceus X, etc.
-- ============================================================
local _G_ENV = getfenv and getfenv() or _ENV or {}

-- Safe fireproximityprompt
local _fireprox = (typeof(fireproximityprompt) == "function" and fireproximityprompt)
    or (typeof(_G_ENV.fireproximityprompt) == "function" and _G_ENV.fireproximityprompt)
    or function(prompt)
        -- Fallback: trigger via holdbegin/holdend
        if prompt and prompt.HoldDuration <= 0 then
            prompt.Triggered:Fire()
        end
    end

-- Safe fireclickdetector
local _fireclk = (typeof(fireclickdetector) == "function" and fireclickdetector)
    or (typeof(_G_ENV.fireclickdetector) == "function" and _G_ENV.fireclickdetector)
    or function(det)
        if det and det.MouseClick then pcall(function() det.MouseClick:Fire(game:GetService("Players").LocalPlayer) end) end
    end

-- Android/Xeno: Draggable fix (handle touch input)
local _isMobile = (UserInputService and UserInputService.TouchEnabled) or false

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

-- ============================================================
-- AUTO-DETECT KEYWORD SYSTEM
-- ============================================================
local KEYWORDS = {
    WATER        = {"water","agua","h2o","waterbucket","waterjug","wateritem","mineral"},
    SUGAR_BLOCK  = {"sugar","sugarblock","gula","sweetener","sugaritem"},
    GELATIN      = {"gelatin","gelatine","jelly","agar","gel"},
    COOKING_POT  = {"pot","cookingpot","pan","cauldron","stove","oven","boiler","cook","machine"},
    EMPTY_BAG    = {"emptybag","empty_bag","bag","tas","sack","pouch","package","wrapper"},
    MARSHMALLOW  = {"marshmallow","marshmellow","mallow","marsh","candy"},
    SHOP_WATER   = {"watershop","buywater","waterstore"},
    SHOP_SUGAR   = {"sugarshop","buysugar","sugarstore"},
    SHOP_GELATIN = {"gelatinshop","buygelatin","gelstore"},
    SELL_NPC     = {"sell","sellnpc","dealer","buyer","trader","merchant","cashier"},
}
local GENERIC_SHOP = {"shop","store","vendor","market","purchase","buy"}

local DETECTED = {}
local DET_OBJ  = {}
local scanLog  = {}
local scanDone = false

local function nameMatch(objName, kws)
    local clean = objName:lower():gsub("[%s%-%_]","")
    for _,kw in ipairs(kws) do
        if clean:find(kw:gsub("[%s%-%_]",""),1,true) then return true end
    end
    return false
end
local function hasInteract(obj)
    if obj:FindFirstChildOfClass("ProximityPrompt") then return true end
    if obj:FindFirstChildOfClass("ClickDetector") then return true end
    if obj.Parent then
        if obj.Parent:FindFirstChildOfClass("ProximityPrompt") then return true end
        if obj.Parent:FindFirstChildOfClass("ClickDetector") then return true end
    end
    return false
end
local function getObjPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
        if p then return p.Position end
    end
    return nil
end

local function scanWorkspace()
    scanLog = {}
    DETECTED = {}
    DET_OBJ  = {}
    table.insert(scanLog,"🔍 Scan workspace dimulai...")
    table.insert(scanLog,"━━━━━━━━━━━━━━━━━━")
    local buckets = {}
    for k in pairs(KEYWORDS) do buckets[k] = {} end
    local total = 0
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local pos = getObjPos(obj)
            if pos then
                total += 1
                for cat,kws in pairs(KEYWORDS) do
                    if nameMatch(obj.Name, kws) then
                        table.insert(buckets[cat],{name=obj.Name,pos=pos,obj=obj,score=hasInteract(obj) and 2 or 1})
                    end
                end
                if nameMatch(obj.Name, GENERIC_SHOP) and hasInteract(obj) then
                    for _,sk in ipairs({"SHOP_WATER","SHOP_SUGAR","SHOP_GELATIN","SELL_NPC"}) do
                        if #buckets[sk] == 0 then
                            table.insert(buckets[sk],{name=obj.Name.."[generic]",pos=pos,obj=obj,score=0})
                        end
                    end
                end
            end
        end
    end
    table.insert(scanLog,"📦 Objek di-scan: "..total)
    table.insert(scanLog,"━━━━━━━━━━━━━━━━━━")
    local posKeys = {
        WATER="WATER_POS",SUGAR_BLOCK="SUGAR_BLOCK_POS",GELATIN="GELATIN_POS",
        COOKING_POT="COOKING_POT_POS",EMPTY_BAG="EMPTY_BAG_POS",MARSHMALLOW="RESULT_POS",
        SHOP_WATER="SHOP_WATER_POS",SHOP_SUGAR="SHOP_SUGAR_POS",
        SHOP_GELATIN="SHOP_GELATIN_POS",SELL_NPC="SELL_POS",
    }
    local found = 0
    for cat,pk in pairs(posKeys) do
        local list = buckets[cat]
        if #list > 0 then
            table.sort(list,function(a,b) return a.score>b.score end)
            local best = list[1]
            DETECTED[pk]  = best.pos
            DET_OBJ[pk]   = best.obj
            found += 1
            table.insert(scanLog,"✅ "..cat.." → '"..best.name.."'")
        else
            table.insert(scanLog,"❌ "..cat.." → Tidak ditemukan")
        end
    end
    table.insert(scanLog,"━━━━━━━━━━━━━━━━━━")
    table.insert(scanLog,"📊 Hasil: "..found.."/10 terdeteksi")
    if found>=8 then table.insert(scanLog,"🟢 Sempurna! Siap farming!")
    elseif found>=5 then table.insert(scanLog,"🟡 Sebagian. Farming bisa jalan.")
    else table.insert(scanLog,"🔴 Kurang. Pindah area & scan ulang!") end
    return found
end

-- Apply detected positions to CONFIG (call after scan)
local function applyDetected()
    if DETECTED["WATER_POS"]        then CONFIG.WATER_POS        = DETECTED["WATER_POS"] end
    if DETECTED["SUGAR_BLOCK_POS"]  then CONFIG.SUGAR_BLOCK_POS  = DETECTED["SUGAR_BLOCK_POS"] end
    if DETECTED["GELATIN_POS"]      then CONFIG.GELATIN_POS       = DETECTED["GELATIN_POS"] end
    if DETECTED["COOKING_POT_POS"]  then CONFIG.COOKING_POT_POS  = DETECTED["COOKING_POT_POS"] end
    if DETECTED["EMPTY_BAG_POS"]    then CONFIG.EMPTY_BAG_POS    = DETECTED["EMPTY_BAG_POS"] end
    if DETECTED["RESULT_POS"]       then CONFIG.RESULT_POS        = DETECTED["RESULT_POS"] end
    if DETECTED["SHOP_WATER_POS"]   then CONFIG.SHOP_WATER_POS   = DETECTED["SHOP_WATER_POS"] end
    if DETECTED["SHOP_SUGAR_POS"]   then CONFIG.SHOP_SUGAR_POS   = DETECTED["SHOP_SUGAR_POS"] end
    if DETECTED["SHOP_GELATIN_POS"] then CONFIG.SHOP_GELATIN_POS = DETECTED["SHOP_GELATIN_POS"] end
    if DETECTED["SELL_POS"]         then CONFIG.SELL_POS          = DETECTED["SELL_POS"] end
end

-- ============================================================
-- CONFIG
-- ============================================================
CONFIG = {
    WATER_POS           = Vector3.new(0,   0, 0),
    SUGAR_BLOCK_POS     = Vector3.new(10,  0, 0),
    GELATIN_POS         = Vector3.new(20,  0, 0),
    COOKING_POT_POS     = Vector3.new(30,  0, 0),
    EMPTY_BAG_POS       = Vector3.new(40,  0, 0),
    RESULT_POS          = Vector3.new(50,  0, 0),
    SHOP_WATER_POS      = Vector3.new(60,  0, 0),
    SHOP_SUGAR_POS      = Vector3.new(70,  0, 0),
    SHOP_GELATIN_POS    = Vector3.new(80,  0, 0),
    SELL_POS            = Vector3.new(90,  0, 0),

    WATER_COOK_TIME     = 20,
    MIX_COOK_TIME       = 45,
    BUY_AMOUNT          = 1,
    INTERACT_DISTANCE   = 8,
    WALK_TIMEOUT        = 15,
    ACTION_DELAY        = 0.5,

    WATER_NAME          = "Water",
    SUGAR_BLOCK_NAME    = "SugarBlock",
    GELATIN_NAME        = "Gelatin",
    EMPTY_BAG_NAME      = "EmptyBag",
    POT_NAME            = "CookingPot",
    MARSHMALLOW_NAME    = "Marshmallow",
    SELL_NPC_NAME       = "SellNPC",

    MARSHMALLOW_PRICE   = 950,
    ATM_DEPOSIT_LIMIT   = 500000,
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning           = false
local autoFarmCards       = false
local autoFarmChips       = false
local autoFarmMarshmallow = false
local autoFarmBoxes       = false
local autoBuyGunDeath     = false
local autoBuyMaskDeath    = false
local rejoinerEnabled     = true
local autoBuyGuns         = false

local cycleCount          = 0
local totalEarned         = 0
local totalBought         = 0
local moneyGained         = 0
local sessionStart        = tick()
local marshmallowAmount   = 0
local farmThread          = nil
local currentStep         = "Idle"

-- ============================================================
-- UTILITY
-- ============================================================
local function walkTo(position)
    if not isRunning then return end
    humanoid:MoveTo(position)
    local t = tick()
    repeat RunService.Heartbeat:Wait()
        if not isRunning then return end
        if tick()-t > CONFIG.WALK_TIMEOUT then break end
    until (rootPart.Position - position).Magnitude < CONFIG.INTERACT_DISTANCE
end

local function waitSeconds(s)
    if not isRunning then return end
    local t = tick()
    repeat RunService.Heartbeat:Wait()
        if not isRunning then return end
    until tick()-t >= s
end

local function findNearby(name, pos, r)
    r = r or 20
    for _,o in pairs(workspace:GetDescendants()) do
        if o.Name:lower():find(name:lower()) and o:IsA("BasePart") then
            if (o.Position-pos).Magnitude <= r then return o end
        end
    end
end

local function interact(item)
    if not item then return false end
    local p = item:FindFirstChildOfClass("ProximityPrompt") or item.Parent:FindFirstChildOfClass("ProximityPrompt")
    if p then _fireprox(p) return true end
    local c = item:FindFirstChildOfClass("ClickDetector") or item.Parent:FindFirstChildOfClass("ClickDetector")
    if c then _fireclk(c) return true end
    return false
end

local function collectItem(name, pos, label)
    currentStep = "Ambil " .. label
    walkTo(pos) task.wait(CONFIG.ACTION_DELAY)
    local item = findNearby(name, pos)
    if item then interact(item) task.wait(CONFIG.ACTION_DELAY) end
end

-- ============================================================
-- BUY
-- ============================================================
local function buyIngredient(pos, name, label)
    currentStep = "Beli " .. label
    walkTo(pos) task.wait(CONFIG.ACTION_DELAY)
    local shop = findNearby("Shop", pos, 15) or findNearby(name, pos, 15)
    if shop then
        for i=1,CONFIG.BUY_AMOUNT do interact(shop) task.wait(0.3) end
        totalBought += CONFIG.BUY_AMOUNT
    end
end

local function buyAllIngredients()
    currentStep = "Auto Buy Bahan"
    buyIngredient(CONFIG.SHOP_WATER_POS,   CONFIG.WATER_NAME,       "Water")
    buyIngredient(CONFIG.SHOP_SUGAR_POS,   CONFIG.SUGAR_BLOCK_NAME, "Sugar Block")
    buyIngredient(CONFIG.SHOP_GELATIN_POS, CONFIG.GELATIN_NAME,     "Gelatin")
end

-- ============================================================
-- SELL
-- ============================================================
local function sellMarshmallow()
    currentStep = "Jual Marshmallow"
    walkTo(CONFIG.SELL_POS) task.wait(CONFIG.ACTION_DELAY)
    local npc = findNearby(CONFIG.SELL_NPC_NAME, CONFIG.SELL_POS, 15)
        or findNearby("Sell", CONFIG.SELL_POS, 15)
    if npc then
        interact(npc) task.wait(0.4)
        interact(npc) task.wait(CONFIG.ACTION_DELAY)
        moneyGained += CONFIG.MARSHMALLOW_PRICE
        totalEarned += 1
        marshmallowAmount += 1
        if moneyGained >= CONFIG.ATM_DEPOSIT_LIMIT then
            currentStep = "Deposit ATM"
            moneyGained = moneyGained - CONFIG.ATM_DEPOSIT_LIMIT
        end
    end
end

-- ============================================================
-- MAIN CYCLE
-- ============================================================
local function cookingCycle()
    buyAllIngredients()
    task.wait(CONFIG.ACTION_DELAY)

    collectItem(CONFIG.WATER_NAME, CONFIG.WATER_POS, "Water")
    currentStep = "Masak Water"
    walkTo(CONFIG.COOKING_POT_POS) task.wait(CONFIG.ACTION_DELAY)
    interact(findNearby(CONFIG.POT_NAME, CONFIG.COOKING_POT_POS))
    task.wait(CONFIG.ACTION_DELAY)
    waitSeconds(CONFIG.WATER_COOK_TIME)
    if not isRunning then return end

    collectItem(CONFIG.SUGAR_BLOCK_NAME, CONFIG.SUGAR_BLOCK_POS, "Sugar Block")
    collectItem(CONFIG.GELATIN_NAME, CONFIG.GELATIN_POS, "Gelatin")

    currentStep = "Masak Campuran"
    walkTo(CONFIG.COOKING_POT_POS) task.wait(CONFIG.ACTION_DELAY)
    local pot = findNearby(CONFIG.POT_NAME, CONFIG.COOKING_POT_POS)
    interact(pot) task.wait(0.3)
    interact(pot) task.wait(CONFIG.ACTION_DELAY)
    waitSeconds(CONFIG.MIX_COOK_TIME)
    if not isRunning then return end

    collectItem(CONFIG.EMPTY_BAG_NAME, CONFIG.EMPTY_BAG_POS, "Empty Bag")
    currentStep = "Kemas Marshmallow"
    walkTo(CONFIG.COOKING_POT_POS) task.wait(CONFIG.ACTION_DELAY)
    interact(findNearby(CONFIG.POT_NAME, CONFIG.COOKING_POT_POS))
    task.wait(CONFIG.ACTION_DELAY)

    currentStep = "Ambil Hasil"
    walkTo(CONFIG.RESULT_POS) task.wait(CONFIG.ACTION_DELAY)
    local result = findNearby(CONFIG.MARSHMALLOW_NAME, CONFIG.RESULT_POS)
    if result then interact(result) task.wait(CONFIG.ACTION_DELAY) end

    sellMarshmallow()
    cycleCount += 1
    currentStep = "Siklus #" .. cycleCount .. " selesai"
    task.wait(1)
end

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function formatTime(s)
    local h = math.floor(s/3600)
    local m = math.floor((s%3600)/60)
    local sec = math.floor(s%60)
    return string.format("%dh, %dm, %ds", h, m, sec)
end

local function formatMoney(n)
    return "$" .. string.format("%,.0f", n):gsub(",",".")
end

-- Mobile-friendly dragging for Android/Xeno
local function makeDraggable(frame)
    -- Built-in Draggable works on PC; touch needs manual impl
    frame.Active = true
    if not _isMobile then
        frame.Draggable = true
        return
    end
    -- Touch drag
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local function createGUI()
    local old = player.PlayerGui:FindFirstChild("ReyvanStore")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ReyvanStore"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true   -- needed for Xeno/Android
    ScreenGui.Parent = player.PlayerGui

    -- ── MAIN WINDOW ──────────────────────────────────────────
    local Win = Instance.new("Frame")
    Win.Name = "Window"
    -- Slightly smaller on mobile for readability
    local winW = _isMobile and 360 or 680
    local winH = _isMobile and 500 or 460
    Win.Size = UDim2.new(0, winW, 0, winH)
    Win.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
    Win.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    Win.BorderSizePixel = 0
    Win.ClipsDescendants = true
    Win.Parent = ScreenGui
    Instance.new("UICorner", Win).CornerRadius = UDim.new(0,8)
    makeDraggable(Win)

    local border = Instance.new("UIStroke", Win)
    border.Color = Color3.fromRGB(50,50,50)
    border.Thickness = 1

    -- ── TITLE BAR ─────────────────────────────────────────────
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1,0,0,32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(14,14,14)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Win

    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(0,300,1,0)
    TitleText.Position = UDim2.new(0,12,0,0)
    TitleText.BackgroundTransparency = 1
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 13
    TitleText.TextColor3 = Color3.fromRGB(255,255,255)
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.RichText = true
    TitleText.Text = '<font color="rgb(255,255,255)">reyvan</font>'
        .. '<font color="rgb(220,40,40)">.gg</font>'
        .. '<font color="rgb(180,180,180)"> | South Bronx</font>'
        .. '<font color="rgb(100,100,100)"> | v3.0.0</font>'
    TitleText.Parent = TitleBar

    -- Close
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0,28,0,28)
    CloseBtn.Position = UDim2.new(1,-32,0,2)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.fromRGB(150,150,150)
    CloseBtn.TextSize = 22
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Minimize
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0,28,0,28)
    MinBtn.Position = UDim2.new(1,-62,0,2)
    MinBtn.BackgroundTransparency = 1
    MinBtn.Text = "–"
    MinBtn.TextColor3 = Color3.fromRGB(150,150,150)
    MinBtn.TextSize = 18
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = TitleBar
    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Win.Size = minimized and UDim2.new(0,winW,0,32) or UDim2.new(0,winW,0,winH)
    end)

    -- Divider
    local TitleDiv = Instance.new("Frame")
    TitleDiv.Size = UDim2.new(1,0,0,1)
    TitleDiv.Position = UDim2.new(0,0,0,32)
    TitleDiv.BackgroundColor3 = Color3.fromRGB(35,35,35)
    TitleDiv.BorderSizePixel = 0
    TitleDiv.Parent = Win

    -- ── SEARCH BAR ────────────────────────────────────────────
    local SearchFrame = Instance.new("Frame")
    SearchFrame.Size = UDim2.new(0, _isMobile and 200 or 300, 0, 30)
    SearchFrame.Position = UDim2.new(0,12,0,42)
    SearchFrame.BackgroundColor3 = Color3.fromRGB(26,26,26)
    SearchFrame.BorderSizePixel = 0
    SearchFrame.Parent = Win
    Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0,5)
    local SearchStroke = Instance.new("UIStroke", SearchFrame)
    SearchStroke.Color = Color3.fromRGB(40,40,40)
    SearchStroke.Thickness = 1

    local SearchIcon = Instance.new("TextLabel")
    SearchIcon.Size = UDim2.new(0,24,1,0)
    SearchIcon.Position = UDim2.new(0,6,0,0)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Text = "🔍"
    SearchIcon.TextSize = 12
    SearchIcon.Font = Enum.Font.Gotham
    SearchIcon.TextColor3 = Color3.fromRGB(100,100,100)
    SearchIcon.Parent = SearchFrame

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1,-34,1,0)
    SearchBox.Position = UDim2.new(0,28,0,0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.PlaceholderText = "search"
    SearchBox.PlaceholderColor3 = Color3.fromRGB(70,70,70)
    SearchBox.TextColor3 = Color3.fromRGB(180,180,180)
    SearchBox.TextSize = 12
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.Text = ""
    SearchBox.Parent = SearchFrame

    -- ── LAYOUT DEPENDS ON MOBILE OR PC ────────────────────────
    local leftW  = _isMobile and winW or 300
    local rightW = _isMobile and winW or 360

    -- ── LEFT PANEL ────────────────────────────────────────────
    local LeftPanel = Instance.new("ScrollingFrame")
    LeftPanel.Size = UDim2.new(0, leftW, 0, winH - 84 - 46)
    LeftPanel.Position = UDim2.new(0,0,0,84)
    LeftPanel.BackgroundTransparency = 1
    LeftPanel.BorderSizePixel = 0
    LeftPanel.ScrollBarThickness = 2
    LeftPanel.ScrollBarImageColor3 = Color3.fromRGB(220,40,40)
    LeftPanel.CanvasSize = UDim2.new(0,0,0,680)
    LeftPanel.Parent = Win
    local LeftList = Instance.new("UIListLayout", LeftPanel)
    LeftList.Padding = UDim.new(0,0)

    -- Vertical divider (PC only)
    if not _isMobile then
        local VDiv = Instance.new("Frame")
        VDiv.Size = UDim2.new(0,1,0,winH - 84 - 46)
        VDiv.Position = UDim2.new(0,300,0,74)
        VDiv.BackgroundColor3 = Color3.fromRGB(35,35,35)
        VDiv.BorderSizePixel = 0
        VDiv.Parent = Win
    end

    -- ── RIGHT PANEL (PC) / Tab system (Mobile) ─────────────────
    local RightPanel = Instance.new("Frame")
    if _isMobile then
        -- On mobile, right panel is hidden by default (tab switching)
        RightPanel.Size = UDim2.new(0, winW, 0, winH - 84 - 46)
        RightPanel.Position = UDim2.new(0, winW, 0, 84) -- hidden offscreen right
    else
        RightPanel.Size = UDim2.new(0, rightW, 0, winH - 84 - 46)
        RightPanel.Position = UDim2.new(0, 308, 0, 74)
    end
    RightPanel.BackgroundTransparency = 1
    RightPanel.BorderSizePixel = 0
    RightPanel.Parent = Win

    -- ── BOTTOM NAV ────────────────────────────────────────────
    local BottomNav = Instance.new("Frame")
    BottomNav.Size = UDim2.new(1,0,0,46)
    BottomNav.Position = UDim2.new(0,0,1,-46)
    BottomNav.BackgroundColor3 = Color3.fromRGB(14,14,14)
    BottomNav.BorderSizePixel = 0
    BottomNav.Parent = Win
    local NavDiv = Instance.new("Frame")
    NavDiv.Size = UDim2.new(1,0,0,1)
    NavDiv.Position = UDim2.new(0,0,0,0)
    NavDiv.BackgroundColor3 = Color3.fromRGB(35,35,35)
    NavDiv.BorderSizePixel = 0
    NavDiv.Parent = BottomNav

    -- Mobile tab buttons
    if _isMobile then
        local tabs = {
            {label="🛠 Farm",  panel=LeftPanel,  active=true},
            {label="📊 Stats", panel=RightPanel, active=false},
        }
        local navL = Instance.new("UIListLayout")
        navL.FillDirection = Enum.FillDirection.Horizontal
        navL.HorizontalAlignment = Enum.HorizontalAlignment.Center
        navL.VerticalAlignment = Enum.VerticalAlignment.Center
        navL.Padding = UDim.new(0,12)
        navL.Parent = BottomNav
        for _,tab in ipairs(tabs) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0,130,0,36)
            btn.BackgroundColor3 = tab.active and Color3.fromRGB(30,30,30) or Color3.fromRGB(18,18,18)
            btn.BorderSizePixel = 0
            btn.Text = tab.label
            btn.TextColor3 = tab.active and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,100,100)
            btn.TextSize = 13
            btn.Font = Enum.Font.GothamBold
            btn.Parent = BottomNav
            Instance.new("UICorner",btn).CornerRadius = UDim.new(0,18)
            btn.MouseButton1Click:Connect(function()
                -- Show this tab, hide other
                for _,t in ipairs(tabs) do
                    t.panel.Position = UDim2.new(0, winW, 0, 84) -- hide
                end
                tab.panel.Position = UDim2.new(0, 0, 0, 84)
            end)
        end
        -- Show left panel by default
        LeftPanel.Position = UDim2.new(0,0,0,84)
    else
        -- PC nav
        local navItems = {
            {icon="👤"},{icon="👥"},{icon="🔗"},
            {icon="$", label="Money", active=true},
            {icon="🚲"},
        }
        local navLayout = Instance.new("UIListLayout")
        navLayout.FillDirection = Enum.FillDirection.Horizontal
        navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        navLayout.Padding = UDim.new(0,8)
        navLayout.Parent = BottomNav
        for _,nav in ipairs(navItems) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0,70,0,36)
            btn.BackgroundTransparency = nav.active and 0 or 1
            btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
            btn.BorderSizePixel = 0
            btn.Text = nav.icon .. (nav.label and ("  "..nav.label) or "")
            btn.TextColor3 = nav.active and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,100,100)
            btn.TextSize = 12
            btn.Font = Enum.Font.GothamBold
            btn.Parent = BottomNav
            if nav.active then Instance.new("UICorner",btn).CornerRadius=UDim.new(0,18) end
        end
    end

    -- ── HELPERS ───────────────────────────────────────────────
    local function makeSection(parent, title, iconColor)
        local sec = Instance.new("Frame")
        sec.Size = UDim2.new(1,0,0,36)
        sec.BackgroundTransparency = 1
        sec.BorderSizePixel = 0
        sec.Parent = parent
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0,3,0,20)
        dot.Position = UDim2.new(0,12,0,8)
        dot.BackgroundColor3 = iconColor or Color3.fromRGB(220,40,40)
        dot.BorderSizePixel = 0
        dot.Parent = sec
        Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-30,1,0)
        lbl.Position = UDim2.new(0,22,0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = Color3.fromRGB(210,210,210)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = sec
        return sec
    end

    local function makeToggleRow(parent, labelText, defaultOn, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,36)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Parent = parent
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.75,0,1,0)
        lbl.Position = UDim2.new(0,24,0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = defaultOn and Color3.fromRGB(200,200,200) or Color3.fromRGB(100,100,100)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.Parent = row
        local switchBG = Instance.new("Frame")
        switchBG.Size = UDim2.new(0,36,0,18)
        switchBG.Position = UDim2.new(1,-48,0.5,-9)
        switchBG.BackgroundColor3 = defaultOn and Color3.fromRGB(220,40,40) or Color3.fromRGB(45,45,45)
        switchBG.BorderSizePixel = 0
        switchBG.Parent = row
        Instance.new("UICorner",switchBG).CornerRadius = UDim.new(1,0)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0,14,0,14)
        knob.Position = defaultOn and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        knob.Parent = switchBG
        Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)
        local state = defaultOn
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = row
        btn.MouseButton1Click:Connect(function()
            state = not state
            lbl.TextColor3 = state and Color3.fromRGB(200,200,200) or Color3.fromRGB(100,100,100)
            local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
            TweenService:Create(switchBG, ti, {BackgroundColor3 = state and Color3.fromRGB(220,40,40) or Color3.fromRGB(45,45,45)}):Play()
            TweenService:Create(knob, ti, {Position = state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
            if callback then callback(state) end
        end)
        return row, function() return state end
    end

    local function makeInfoRow(parent, labelText, valueText, valueColor)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,28)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Parent = parent
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.65,0,1,0)
        lbl.Position = UDim2.new(0,24,0,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(130,130,130)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.35,-12,1,0)
        val.Position = UDim2.new(0.65,0,0,0)
        val.BackgroundTransparency = 1
        val.Text = valueText
        val.TextColor3 = valueColor or Color3.fromRGB(200,200,200)
        val.TextSize = 12
        val.Font = Enum.Font.GothamBold
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = row
        return row, val
    end

    local function spacer(parent, h)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1,0,0,h or 8)
        f.BackgroundTransparency = 1
        f.Parent = parent
    end

    -- ── LEFT PANEL CONTENT ────────────────────────────────────

    -- Information
    makeSection(LeftPanel, "Information", Color3.fromRGB(220,40,40))
    local infoBox = Instance.new("Frame")
    infoBox.Size = UDim2.new(1,-24,0,54)
    infoBox.BackgroundColor3 = Color3.fromRGB(24,24,24)
    infoBox.BorderSizePixel = 0
    infoBox.Parent = LeftPanel
    Instance.new("UICorner",infoBox).CornerRadius = UDim.new(0,5)
    Instance.new("UIPadding",infoBox).PaddingLeft = UDim.new(0,12)
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1,-14,1,0)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Jika kamu mendapat lebih dari $500,000 dalam satu sesi,\nscript akan deposit $500,000 ke ATM kamu\ndemi keamanan."
    infoText.TextColor3 = Color3.fromRGB(120,120,120)
    infoText.TextSize = 11
    infoText.Font = Enum.Font.Gotham
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextWrapped = true
    infoText.Parent = infoBox
    spacer(LeftPanel, 10)

    -- Auto-Detect Section
    makeSection(LeftPanel, "🔍 Auto-Detect Koordinat", Color3.fromRGB(40,100,220))
    spacer(LeftPanel, 4)

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(1,-16,0,36)
    scanBtn.BackgroundColor3 = Color3.fromRGB(28,100,210)
    scanBtn.BorderSizePixel = 0
    scanBtn.Text = "🔍  SCAN OTOMATIS"
    scanBtn.TextColor3 = Color3.fromRGB(255,255,255)
    scanBtn.TextSize = 13
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.Parent = LeftPanel
    Instance.new("UICorner",scanBtn).CornerRadius = UDim.new(0,6)
    spacer(LeftPanel, 5)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1,-16,0,18)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "⬤  Belum di-scan — tekan tombol di atas"
    statusLbl.TextColor3 = Color3.fromRGB(120,120,120)
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.RichText = true
    statusLbl.Parent = LeftPanel
    spacer(LeftPanel, 5)

    -- Scan log
    local logScr = Instance.new("ScrollingFrame")
    logScr.Size = UDim2.new(1,-16,0,110)
    logScr.BackgroundColor3 = Color3.fromRGB(12,12,12)
    logScr.BorderSizePixel = 0
    logScr.ScrollBarThickness = 2
    logScr.ScrollBarImageColor3 = Color3.fromRGB(55,55,55)
    logScr.CanvasSize = UDim2.new(0,0,0,0)
    logScr.Parent = LeftPanel
    Instance.new("UICorner",logScr).CornerRadius = UDim.new(0,5)
    local logLL = Instance.new("UIListLayout",logScr)
    logLL.Padding = UDim.new(0,1)
    local logPad = Instance.new("UIPadding",logScr)
    logPad.PaddingLeft = UDim.new(0,6)
    logPad.PaddingTop  = UDim.new(0,4)

    local function addLog(text, col)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-6,0,15)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = col or Color3.fromRGB(120,120,120)
        l.TextSize = 10
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = logScr
        logScr.CanvasSize = UDim2.new(0,0,0,logLL.AbsoluteContentSize.Y+8)
        logScr.CanvasPosition = Vector2.new(0,logScr.CanvasSize.Y.Offset)
    end

    -- Scan button logic
    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text = "⏳  Scanning..."
        scanBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        statusLbl.Text = "⬤  Sedang scan..."
        statusLbl.TextColor3 = Color3.fromRGB(220,180,0)
        for _,c in ipairs(logScr:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        task.wait(0.08)
        local count = scanWorkspace()
        applyDetected()
        for _,line in ipairs(scanLog) do
            local c = Color3.fromRGB(120,120,120)
            if line:find("✅") then c = Color3.fromRGB(50,195,70) end
            if line:find("❌") then c = Color3.fromRGB(195,50,50) end
            if line:find("🟢") then c = Color3.fromRGB(50,215,70) end
            if line:find("🟡") then c = Color3.fromRGB(215,175,0) end
            if line:find("🔴") then c = Color3.fromRGB(215,50,50) end
            if line:find("━") or line:find("📊") or line:find("📦") then c = Color3.fromRGB(165,165,165) end
            addLog(line, c)
        end
        if count >= 8 then
            scanDone = true
            scanBtn.Text = "✅  SELESAI  ("..count.."/10)"
            scanBtn.BackgroundColor3 = Color3.fromRGB(25,148,60)
            statusLbl.Text = '⬤  <font color="rgb(50,215,70)">Terdeteksi '..count..'/10 — Siap farming!</font>'
        elseif count >= 5 then
            scanDone = true
            scanBtn.Text = "⚠️  PARSIAL  ("..count.."/10)"
            scanBtn.BackgroundColor3 = Color3.fromRGB(165,105,0)
            statusLbl.Text = '⬤  <font color="rgb(215,175,0)">Parsial '..count..'/10 — Bisa jalan</font>'
        else
            scanDone = false
            scanBtn.Text = "❌  SCAN ULANG  ("..count.."/10)"
            scanBtn.BackgroundColor3 = Color3.fromRGB(28,100,210)
            statusLbl.Text = '⬤  <font color="rgb(215,50,50)">Hanya '..count..'/10 — Pindah area!</font>'
        end
    end)

    spacer(LeftPanel, 10)

    -- Automated Utilities
    makeSection(LeftPanel, "Automated Utilities", Color3.fromRGB(180,40,40))
    makeToggleRow(LeftPanel, "Auto-Farm Cards",  false, function(s) autoFarmCards=s end)
    makeToggleRow(LeftPanel, "Auto-Farm Chips",  false, function(s) autoFarmChips=s end)
    makeToggleRow(LeftPanel, "Auto-Farm Marshmallows", false, function(s)
        autoFarmMarshmallow = s
        if s and not isRunning then
            isRunning = true
            farmThread = task.spawn(function()
                while isRunning and autoFarmMarshmallow do
                    local ok,err = pcall(cookingCycle)
                    if not ok then
                        warn("[ReyvanStore] Error: "..tostring(err))
                        task.wait(2)
                    end
                end
                isRunning = false
            end)
        elseif not s then
            isRunning = false
        end
    end)

    -- Marshmallow count sub-row
    local amountRow = Instance.new("Frame")
    amountRow.Size = UDim2.new(1,0,0,28)
    amountRow.BackgroundTransparency = 1
    amountRow.Parent = LeftPanel
    local amtLabel = Instance.new("TextLabel")
    amtLabel.Size = UDim2.new(0.75,0,1,0)
    amtLabel.Position = UDim2.new(0,24,0,0)
    amtLabel.BackgroundTransparency = 1
    amtLabel.Text = "Marshmallow Amount — $950 each"
    amtLabel.TextColor3 = Color3.fromRGB(100,100,100)
    amtLabel.TextSize = 11
    amtLabel.Font = Enum.Font.Gotham
    amtLabel.TextXAlignment = Enum.TextXAlignment.Left
    amtLabel.Parent = amountRow
    local countPill = Instance.new("Frame")
    countPill.Size = UDim2.new(0,32,0,18)
    countPill.Position = UDim2.new(1,-42,0.5,-9)
    countPill.BackgroundColor3 = Color3.fromRGB(200,30,30)
    countPill.BorderSizePixel = 0
    countPill.Parent = amountRow
    Instance.new("UICorner",countPill).CornerRadius = UDim.new(0,4)
    local countLbl = Instance.new("TextLabel")
    countLbl.Size = UDim2.new(1,0,1,0)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = "0"
    countLbl.TextColor3 = Color3.fromRGB(255,255,255)
    countLbl.TextSize = 11
    countLbl.Font = Enum.Font.GothamBold
    countLbl.Parent = countPill

    makeToggleRow(LeftPanel, "Auto-Farm Boxes", false, function(s) autoFarmBoxes=s end)
    spacer(LeftPanel, 10)
    makeSection(LeftPanel, "Auto Farm Webhook", Color3.fromRGB(180,40,40))
    spacer(LeftPanel, 40)

    -- ── RIGHT PANEL CONTENT ───────────────────────────────────
    local RightList = Instance.new("UIListLayout", RightPanel)
    RightList.Padding = UDim.new(0,0)

    -- Bypass info box
    local bypassBox = Instance.new("Frame")
    bypassBox.Size = UDim2.new(1,-16,0,40)
    bypassBox.BackgroundColor3 = Color3.fromRGB(22,22,22)
    bypassBox.BorderSizePixel = 0
    bypassBox.Parent = RightPanel
    Instance.new("UICorner",bypassBox).CornerRadius = UDim.new(0,5)
    Instance.new("UIPadding",bypassBox).PaddingLeft = UDim.new(0,12)
    local bypassText = Instance.new("TextLabel")
    bypassText.Size = UDim2.new(1,0,1,0)
    bypassText.BackgroundTransparency = 1
    bypassText.RichText = true
    bypassText.Text = '<font color="rgb(100,100,100)">Don\'t worry, </font><font color="rgb(220,220,220)">reyvan</font><font color="rgb(220,40,40)">.gg</font><font color="rgb(100,100,100)"> has already bypassed anti-checks for you!</font>'
    bypassText.TextSize = 11
    bypassText.Font = Enum.Font.Gotham
    bypassText.TextXAlignment = Enum.TextXAlignment.Left
    bypassText.TextWrapped = true
    bypassText.Parent = bypassBox
    spacer(RightPanel, 8)

    makeToggleRow(RightPanel, "Auto-Buy Gun If Death While Auto-Farming",  false, function(s) autoBuyGunDeath=s end)
    makeToggleRow(RightPanel, "Auto-Buy Mask If Death While Auto-Farming", false, function(s) autoBuyMaskDeath=s end)

    local div2 = Instance.new("Frame") div2.Size=UDim2.new(1,-16,0,1) div2.BackgroundColor3=Color3.fromRGB(35,35,35) div2.BorderSizePixel=0 div2.Parent=RightPanel
    spacer(RightPanel, 6)
    makeSection(RightPanel, "Auto Farm Stats Information", Color3.fromRGB(220,40,40))

    local _, timeLbl  = makeInfoRow(RightPanel, "Auto Farm Time Elapsed |", "0h, 0m, 0s", Color3.fromRGB(200,200,200))
    local _, moneyLbl = makeInfoRow(RightPanel, "Money Gained |",           "- $0",       Color3.fromRGB(40,200,80))
    local _, cycleLbl = makeInfoRow(RightPanel, "Siklus Selesai |",         "0",          Color3.fromRGB(160,160,255))
    local _, stepLbl  = makeInfoRow(RightPanel, "Langkah Saat Ini |",       "Idle",       Color3.fromRGB(200,200,100))

    local div3 = Instance.new("Frame") div3.Size=UDim2.new(1,-16,0,1) div3.BackgroundColor3=Color3.fromRGB(35,35,35) div3.BorderSizePixel=0 div3.Parent=RightPanel
    spacer(RightPanel, 6)
    makeSection(RightPanel, "Rejoiner Settings", Color3.fromRGB(180,40,40))

    local rejoinBox = Instance.new("Frame")
    rejoinBox.Size = UDim2.new(1,-16,0,36)
    rejoinBox.BackgroundColor3 = Color3.fromRGB(22,22,22)
    rejoinBox.BorderSizePixel = 0
    rejoinBox.Parent = RightPanel
    Instance.new("UICorner",rejoinBox).CornerRadius = UDim.new(0,5)
    Instance.new("UIPadding",rejoinBox).PaddingLeft = UDim.new(0,12)
    local rejoinText = Instance.new("TextLabel")
    rejoinText.Size = UDim2.new(1,0,1,0)
    rejoinText.BackgroundTransparency = 1
    rejoinText.Text = "Akan rejoin jika mati saat farming marshmallow.\nDisarankan untuk menyalakan semua pilihan."
    rejoinText.TextColor3 = Color3.fromRGB(100,100,100)
    rejoinText.TextSize = 11
    rejoinText.Font = Enum.Font.Gotham
    rejoinText.TextXAlignment = Enum.TextXAlignment.Left
    rejoinText.TextWrapped = true
    rejoinText.Parent = rejoinBox
    makeToggleRow(RightPanel, "Enabled",       true,  function(s) rejoinerEnabled=s end)
    makeToggleRow(RightPanel, "Auto-Buy Guns", false, function(s) autoBuyGuns=s end)

    -- ── LIVE UPDATE ───────────────────────────────────────────
    task.spawn(function()
        while ScreenGui.Parent do
            local elapsed = tick() - sessionStart
            timeLbl.Text  = formatTime(elapsed)
            cycleLbl.Text = tostring(cycleCount)
            stepLbl.Text  = currentStep
            if moneyGained > 0 then
                moneyLbl.Text = "+ " .. formatMoney(moneyGained)
                moneyLbl.TextColor3 = Color3.fromRGB(40,200,80)
            end
            countLbl.Text = tostring(marshmallowAmount)
            task.wait(1)
        end
    end)

    return ScreenGui
end

-- ============================================================
-- LAUNCH
-- ============================================================
createGUI()
print("[REYVAN STORE v3.0] ✅ Script loaded! Support: PC + Android/Xeno")
print("[REYVAN STORE v3.0] Klik tombol SCAN OTOMATIS untuk auto-detect koordinat!")
print("[REYVAN STORE v3.0] Executor detected: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
