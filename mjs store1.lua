-- ========== MAJESTY STORE v8.3.0 ==========
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local VIM              = game:GetService("VirtualInputManager")

repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ================================================================
-- STATE VARIABLES
-- ================================================================
local AutoMS_Running  = false
local autoSell_UI     = false
local asSelling       = false
local asSoldCount     = 0
local isMinimized     = false
local espEnabled      = false
local espCache        = {}
local boxPadding      = 4
local espItemColor    = Color3.fromRGB(255, 220, 50)
local ESP_INTERVAL    = 0.05
local _espAccum       = 0
local aimbotEnabled   = false
local aimbotMode      = "Camera"
local aimbotFOV       = 250
local aimbotSmooth    = 8
local aimbotTarget    = "Head"
local aimbotFovCircle = nil
local aimbotKeybind      = Enum.UserInputType.MouseButton2
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
local vFlyEnabled  = false
local vFlySpeed    = 60
local vFlyConn     = nil
local vFlyUp       = false
local vFlyDown     = false
local fovColor     = Color3.fromRGB(0, 196, 255)
local espBoxColor  = Color3.fromRGB(0, 255, 136)
local espNameColor = Color3.fromRGB(255, 255, 255)
local mb4Held      = false
local mb5Held      = false
local minKeyType   = "KeyCode"
local minKeyCode   = Enum.KeyCode.F1
local minKeyMBtn   = nil
local isBindingMin = false
local minKeybindBtnRef = nil

local autoTP_Running = false
local autoTP_Thread  = nil
local tpStatusValue  = nil
local tpLoopValue    = nil

local safeMode          = false
local safeModeActive    = false
local lastHealth        = 100
local safeModeStatusLbl = nil

local sellStatusLbl_ref = nil
local sellItemLbl_ref   = nil

-- ================================================================
-- AUTO SELL ENGINE — STATE
-- ================================================================
local CFG = {
    WATER_WAIT = 20, COOK_WAIT = 46,
    ITEM_WATER="Water", ITEM_SUGAR="Sugar Block Bag",
    ITEM_GEL="Gelatin", ITEM_EMPTY="Empty Bag",
    ITEM_MS_SMALL="Small Marshmallow Bag",
    ITEM_MS_MEDIUM="Medium Marshmallow Bag",
    ITEM_MS_LARGE="Large Marshmallow Bag",
    SELL_RADIUS=10, SELL_TIMEOUT=10,
}

local patRemotes       = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents", 10)
local storePurchaseRE  = patRemotes and patRemotes:WaitForChild("StorePurchase", 10)
local rpcRE            = patRemotes and patRemotes:WaitForChild("RPC", 10)

local isBusy       = false
local isRunning    = false
local patStats     = {small=0, medium=0, large=0}
local totalSold    = 0
local totalBuy     = 0
local rpcQueue     = {}

-- auto fully shared state
local fullyRunning  = false
local fullyTarget   = 10
local fullySavedPos = nil
local NPC_MS_POS    = Vector3.new(510.061, 4.476, 600.548)

local BUY_ITEMS = {
    {name="Gelatin",        display="Gelatin"},
    {name="Sugar Block Bag",display="Sugar Block Bag"},
    {name="Water",          display="Water"},
}
local buyQty = {1, 1, 1}

-- ================================================================
-- AUTO MS ENGINE — UTILITY FUNCTIONS
-- ================================================================
local function countItem(name)
    local n = 0
    for _,t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t.Name == name then n += 1 end
    end
    local ch = LocalPlayer.Character
    if ch then
        for _,t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") and t.Name == name then n += 1 end
        end
    end
    return n
end

local function totalMS() return patStats.small + patStats.medium + patStats.large end

local function countAllMS()
    return countItem(CFG.ITEM_MS_SMALL)
         + countItem(CFG.ITEM_MS_MEDIUM)
         + countItem(CFG.ITEM_MS_LARGE)
end

local function getEquippableMS()
    if countItem(CFG.ITEM_MS_SMALL)  > 0 then return CFG.ITEM_MS_SMALL  end
    if countItem(CFG.ITEM_MS_MEDIUM) > 0 then return CFG.ITEM_MS_MEDIUM end
    if countItem(CFG.ITEM_MS_LARGE)  > 0 then return CFG.ITEM_MS_LARGE  end
    return nil
end

local function hasAllIngredients()
    return countItem(CFG.ITEM_WATER) >= 1
       and countItem(CFG.ITEM_SUGAR) >= 1
       and countItem(CFG.ITEM_GEL)   >= 1
end

local function equipTool(name)
    local ch  = LocalPlayer.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local t   = LocalPlayer.Backpack:FindFirstChild(name)
    if hum and t then hum:EquipTool(t); task.wait(0.2); return true end
    return false
end

local function unequipAll()
    local ch = LocalPlayer.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then hum:UnequipTools() end
end

local function pressE()
    pcall(function()
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function firePromptNearby(radius)
    local ch   = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                if (root.Position - part.Position).Magnitude <= (radius or 8) then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
        end
    end
end

local function cookInteract(toolName, radius)
    if toolName then equipTool(toolName); task.wait(0.2) end
    firePromptNearby(radius or 8)
    task.wait(0.1)
    pcall(function()
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    task.wait(0.1)
    firePromptNearby(radius or 8)
end

-- RPC listener
if rpcRE then
    rpcRE.OnClientEvent:Connect(function(_, tblArg)
        if type(tblArg) ~= "table" then return end
        local v1  = tblArg[1]
        local v2  = tblArg[2]
        local msg = tostring(v1 or ""):lower()
        if v2 == "TextLabel" and tonumber(v1) then
            table.insert(rpcQueue, {type="timer", secs=tonumber(v1)}); return
        end
        if     msg:find("boil") or msg:find("water") then table.insert(rpcQueue, {type="wait_boil"})
        elseif msg:find("sugar")   then table.insert(rpcQueue, {type="add_sugar"})
        elseif msg:find("gelatin") then table.insert(rpcQueue, {type="add_gelatin"})
        elseif msg:find("cook")    then table.insert(rpcQueue, {type="wait_cook"})
        elseif msg:find("bag")     then table.insert(rpcQueue, {type="bag_result"})
        end
    end)
end

local function waitRPC(instrType, timeout)
    local start = tick()
    while tick() - start < timeout do
        for i = 1, #rpcQueue do
            local inst = rpcQueue[i]
            if inst and inst.type == instrType then
                table.remove(rpcQueue, i); return inst
            end
        end
        task.wait(0.1)
    end
    return nil
end

local function popTimer()
    for i = 1, #rpcQueue do
        local v = rpcQueue[i]
        if v.type == "timer" then
            table.remove(rpcQueue, i); return v.secs
        end
    end
    return nil
end

-- ================================================================
-- AUTO SELL ENGINE
-- ================================================================
local function doAutoSell(setStatus2)
    local msTotal = countAllMS()
    if msTotal == 0 then
        setStatus2("Tidak ada MS", Color3.fromRGB(160,160,180))
        return
    end
    setStatus2("Memulai jual "..msTotal.." MS...", Color3.fromRGB(50,210,110))
    task.wait(0.3)

    local sold       = 0
    local maxFail    = 5
    local failStreak = 0

    while countAllMS() > 0 do
        local msName = getEquippableMS()
        if not msName then break end

        local ok = equipTool(msName)
        if not ok then
            failStreak += 1
            setStatus2("Gagal equip ("..failStreak.."/"..maxFail..")", Color3.fromRGB(210,40,40))
            task.wait(1)
            if failStreak >= maxFail then break end
            continue
        end

        local bS = countItem(CFG.ITEM_MS_SMALL)
        local bM = countItem(CFG.ITEM_MS_MEDIUM)
        local bL = countItem(CFG.ITEM_MS_LARGE)

        task.wait(0.2)
        pressE()
        task.wait(0.3)
        firePromptNearby(CFG.SELL_RADIUS)
        task.wait(0.3)
        pressE()
        task.wait(0.3)
        firePromptNearby(CFG.SELL_RADIUS)

        local elapsed = 0
        local terjual = false
        while elapsed < CFG.SELL_TIMEOUT do
            local diff = (bS - countItem(CFG.ITEM_MS_SMALL))
                       + (bM - countItem(CFG.ITEM_MS_MEDIUM))
                       + (bL - countItem(CFG.ITEM_MS_LARGE))
            if diff > 0 then
                sold      += diff
                totalSold += diff
                terjual    = true
                failStreak = 0
                break
            end
            task.wait(0.3)
            elapsed += 0.3
        end

        if terjual then
            setStatus2("Terjual "..sold.." | Sisa: "..countAllMS(), Color3.fromRGB(50,210,110))
            task.wait(0.2)
        else
            failStreak += 1
            setStatus2("Tidak terjual ("..failStreak.."/"..maxFail..")", Color3.fromRGB(255,155,35))
            task.wait(1.2)
            if failStreak >= maxFail then
                setStatus2("Gagal jual. Coba lagi...", Color3.fromRGB(210,40,40))
                unequipAll()
                task.wait(0.5)
                local msName2 = getEquippableMS()
                if msName2 then
                    equipTool(msName2)
                    task.wait(0.3)
                    pressE()
                    task.wait(0.3)
                    firePromptNearby(CFG.SELL_RADIUS)
                    task.wait(0.5)
                    firePromptNearby(CFG.SELL_RADIUS)
                    task.wait(1)
                end
                break
            end
        end
    end

    unequipAll()
    if sold > 0 then
        setStatus2("Terjual "..sold.." MS (total: "..totalSold..")", Color3.fromRGB(50,210,110))
    else
        setStatus2("Tidak ada MS terjual. Pastikan dekat NPC!", Color3.fromRGB(255,155,35))
    end
    task.wait(1)
end

-- ================================================================
-- AUTO BUY ENGINE
-- ================================================================
local function doAutoBuy(setStatus2, overrideQty)
    if not storePurchaseRE then
        setStatus2("Mencari remote...", Color3.fromRGB(255,200,50))
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local re = rs:WaitForChild("RemoteEvents", 8)
            if re then storePurchaseRE = re:WaitForChild("StorePurchase", 8) end
        end)
    end
    if not storePurchaseRE then
        setStatus2("Remote StorePurchase tidak ada!", Color3.fromRGB(210,40,40))
        task.wait(1.5); return
    end

    local totalBought = 0
    for idx, item in ipairs(BUY_ITEMS) do
        local qty = overrideQty or buyQty[idx] or 1
        setStatus2("Beli "..item.display.." ×"..qty.."...", Color3.fromRGB(100,180,255))
        local before = countItem(item.name)
        for i = 1, qty do
            pcall(function() storePurchaseRE:FireServer(item.name, 1) end)
            task.wait(0.4)
        end
        local timeout = 0; local gained = 0
        repeat
            task.wait(0.2); timeout += 0.2
            gained = countItem(item.name) - before
        until gained >= qty or timeout > 6
        if gained < qty then
            local missing = qty - gained
            setStatus2("Retry "..missing.." "..item.display, Color3.fromRGB(255,160,40))
            for i = 1, missing do
                pcall(function() storePurchaseRE:FireServer(item.name, 1) end)
                task.wait(0.5)
            end
            timeout = 0
            repeat
                task.wait(0.2); timeout += 0.2
                gained = countItem(item.name) - before
            until gained >= qty or timeout > 5
        end
        totalBought += gained; totalBuy += gained
        if gained < qty then
            setStatus2(item.display.." kurang ("..gained.."/"..qty..")", Color3.fromRGB(255,120,120))
        else
            setStatus2(item.display.." ×"..gained.." selesai!", Color3.fromRGB(80,220,130))
        end
        task.wait(0.2)
    end
    setStatus2("Beli selesai! "..totalBought.." item.", Color3.fromRGB(80,220,130))
    task.wait(1)
end

-- ================================================================
-- AUTO COOK ENGINE
-- ================================================================
local statusValue, phaseValue, timerValue

local function doOneCook()
    isBusy = true
    table.clear(rpcQueue)

    local snapS = countItem(CFG.ITEM_MS_SMALL)
    local snapM = countItem(CFG.ITEM_MS_MEDIUM)
    local snapL = countItem(CFG.ITEM_MS_LARGE)

    if statusValue then statusValue.Text = "RUNNING"; statusValue.TextColor3 = Color3.fromRGB(0,255,136) end
    if phaseValue  then phaseValue.Text  = "Water" end

    if phaseValue then phaseValue.Text = "Masukkan Water..." end
    cookInteract(CFG.ITEM_WATER)

    local boilSecs
    for _ = 1, 30 do boilSecs = popTimer(); if boilSecs then break end; task.wait(0.1) end
    boilSecs = boilSecs or CFG.WATER_WAIT

    for i = boilSecs, 1, -1 do
        if not AutoMS_Running then isBusy = false; return false end
        if statusValue then statusValue.Text = "RUNNING"; statusValue.TextColor3 = Color3.fromRGB(0,255,136) end
        if phaseValue  then phaseValue.Text  = "Mendidih..." end
        if timerValue  then timerValue.Text  = i.."s" end
        task.wait(1)
    end

    if phaseValue then phaseValue.Text = "Tunggu Sugar..." end
    waitRPC("add_sugar", 10)
    if not AutoMS_Running then isBusy = false; return false end
    if phaseValue then phaseValue.Text = "Masukkan Sugar..." end
    cookInteract(CFG.ITEM_SUGAR)
    task.wait(0.5)

    if phaseValue then phaseValue.Text = "Tunggu Gelatin..." end
    waitRPC("add_gelatin", 10)
    if not AutoMS_Running then isBusy = false; return false end
    if phaseValue then phaseValue.Text = "Masukkan Gelatin..." end
    cookInteract(CFG.ITEM_GEL)
    task.wait(0.5)

    local cookSecs
    for _ = 1, 30 do cookSecs = popTimer(); if cookSecs then break end; task.wait(0.1) end
    cookSecs = cookSecs or CFG.COOK_WAIT

    for i = cookSecs, 1, -1 do
        if not AutoMS_Running then isBusy = false; return false end
        if phaseValue then phaseValue.Text = "Memasak..." end
        if timerValue then timerValue.Text = i.."s" end
        task.wait(1)
    end

    if phaseValue then phaseValue.Text = "Tunggu Bag..." end
    waitRPC("bag_result", 12)

    local bag; local t2 = 0
    repeat
        bag = LocalPlayer.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
        task.wait(0.3); t2 += 0.3
    until bag or t2 > 10

    if not bag then
        if statusValue then statusValue.Text = "No Empty Bag!"; statusValue.TextColor3 = Color3.fromRGB(255,60,90) end
        isBusy = false; return false
    end

    if phaseValue then phaseValue.Text = "Ambil MS..." end
    cookInteract(CFG.ITEM_EMPTY)

    local waitMS = 0; local newS, newM, newL
    repeat
        task.wait(0.3); waitMS += 0.3
        newS = countItem(CFG.ITEM_MS_SMALL)  - snapS
        newM = countItem(CFG.ITEM_MS_MEDIUM) - snapM
        newL = countItem(CFG.ITEM_MS_LARGE)  - snapL
    until (newS > 0 or newM > 0 or newL > 0) or waitMS > 8

    if     newS > 0 then patStats.small  += newS
    elseif newM > 0 then patStats.medium += newM
    elseif newL > 0 then patStats.large  += newL
    else                 patStats.small  += 1
    end

    if phaseValue then phaseValue.Text = "Complete #"..totalMS() end
    if timerValue then timerValue.Text = "Done" end

    isBusy = false; return true
end

local function autoMSLoop()
    while AutoMS_Running do
        if not hasAllIngredients() then
            if statusValue then statusValue.Text = "BAHAN HABIS!"; statusValue.TextColor3 = Color3.fromRGB(255,60,90) end
            AutoMS_Running = false; break
        end
        local ok, err = pcall(doOneCook)
        if not ok then
            if statusValue then statusValue.Text = "ERROR"; statusValue.TextColor3 = Color3.fromRGB(255,60,90) end
            task.wait(2)
        end
        if AutoMS_Running then task.wait(0.3) end
    end
    if statusValue then statusValue.Text = "OFF"; statusValue.TextColor3 = Color3.fromRGB(255,60,90) end
    if phaseValue  then phaseValue.Text  = "Water" end
    if timerValue  then timerValue.Text  = "0s" end
    isBusy = false
end

-- ================================================================
-- VEHICLE TELEPORT ENGINE
-- ================================================================
local function moveVehicle(vehicle, targetPos)
    local anchor = vehicle.PrimaryPart
        or vehicle:FindFirstChildOfClass("VehicleSeat")
        or vehicle:FindFirstChildOfClass("BasePart")
    if not anchor then return end
    local spawnPos = targetPos + Vector3.new(0, 0.5, 0)
    local newCF    = CFrame.new(spawnPos, spawnPos + Vector3.new(0, 0, 1))
    for _,p in ipairs(vehicle:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function()
            p.AssemblyLinearVelocity  = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
            p.Anchored = true
        end) end
    end
    task.wait(0.05)
    if vehicle.PrimaryPart then vehicle:SetPrimaryPartCFrame(newCF)
    else anchor.CFrame = newCF end
    task.wait(0.05)
    for _,p in ipairs(vehicle:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function()
            p.Anchored = false
            p.AssemblyLinearVelocity  = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end) end
    end
end

local function fullyTeleport(targetPos)
    local ch  = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum then task.wait(1); return end
    local seatPart = hum.SeatPart
    if seatPart then
        local vehicle = seatPart:FindFirstAncestorOfClass("Model")
        if vehicle then
            moveVehicle(vehicle, targetPos)
            task.wait(0.8)
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1, 0), targetPos + Vector3.new(0, 1, 1))
                end)
            end
        end
    else
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1, 0), targetPos + Vector3.new(0, 1, 1))
            end)
        end
        task.wait(0.8)
    end
end

-- ================================================================
-- AUTO FULLY ENGINE (FIXED VERSION - SIMPLIFIED LIKE FILE 2)
-- ================================================================

local function doAutoFully(setFullyStatus)
    fullyRunning = true

    local anchorConn = RunService.Heartbeat:Connect(function()
        if not fullyRunning then return end
        local ch = LocalPlayer.Character
        local hm = ch and ch:FindFirstChildOfClass("Humanoid")
        local sp = hm and hm.SeatPart
        if sp then
            local veh = sp:FindFirstAncestorOfClass("Model")
            if veh then
                for _,p in ipairs(veh:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function()
                        p.AssemblyLinearVelocity  = Vector3.zero
                        p.AssemblyAngularVelocity = Vector3.zero
                    end) end
                end
            end
        end
    end)

    while fullyRunning do
        local target = fullyTarget

        -- BELI BAHAN
        setFullyStatus("Teleport ke NPC Marshmallow...", Color3.fromRGB(100,180,255))
        fullyTeleport(NPC_MS_POS)
        if not fullyRunning then break end

        setFullyStatus("Beli bahan untuk "..target.." MS...", Color3.fromRGB(100,180,255))
        doAutoBuy(setFullyStatus, target)
        if not fullyRunning then break end
        task.wait(0.5)

        -- TELEPORT KE APART
        if fullySavedPos then
            setFullyStatus("Teleport ke Apart...", Color3.fromRGB(148,80,255))
            fullyTeleport(fullySavedPos)
        end
        if not fullyRunning then break end

        -- FIX: Tunggu karakter settle sebelum masak
        task.wait(1.0)
        if not fullyRunning then break end

        -- MASAK
        setFullyStatus("Mulai masak "..target.." MS...", Color3.fromRGB(82,130,255))
        AutoMS_Running = true
        isRunning = true
        local cooked = 0

        while fullyRunning and hasAllIngredients() do
            local ok = doOneCook()
            if ok then cooked += 1 end
            if fullyRunning then task.wait(0.3) end
        end

        AutoMS_Running = false
        isRunning = false
        if not fullyRunning then break end

        -- JUAL
        setFullyStatus(cooked.." MS selesai! Siap jual...", Color3.fromRGB(52,210,110))
        task.wait(0.2)

        setFullyStatus("Teleport ke NPC untuk jual...", Color3.fromRGB(52,210,110))
        fullyTeleport(NPC_MS_POS)
        if not fullyRunning then break end

        setFullyStatus("Jual semua MS...", Color3.fromRGB(52,210,110))
        doAutoSell(setFullyStatus)
        if not fullyRunning then break end
        task.wait(0.2)

        setFullyStatus("Loop berikutnya...", Color3.fromRGB(100,180,255))
        task.wait(0.2)
    end

    fullyRunning = false
    AutoMS_Running = false
    isRunning = false
    anchorConn:Disconnect()
end

-- ================================================================
-- GUI SETUP (SIMPLIFIED)
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY STORE"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiOk = false
if not guiOk then pcall(function() screenGui.Parent = gethui(); guiOk = true end) end
if not guiOk then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiOk = true end) end
if not guiOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

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
mainFrame.Size = UDim2.new(0,480,0,390)
mainFrame.Position = UDim2.new(0.5,-240,0.5,-195)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true; mainFrame.Draggable = true; mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mkCorner(mainFrame, 6); mkStroke(mainFrame, 1, C.border)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,36); titleBar.BackgroundColor3 = C.topbar
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
versionLabel.BackgroundTransparency = 1; versionLabel.Text = "v8.3.0"
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
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local isHidden = false
local function doHideShow()
    isHidden = not isHidden
    mainFrame.Visible = not isHidden
end

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

local sbFrame = Instance.new("Frame")
sbFrame.Size = UDim2.new(1,0,0,24); sbFrame.Position = UDim2.new(0,0,0,36)
sbFrame.BackgroundColor3 = Color3.fromRGB(12,15,20); sbFrame.BorderSizePixel = 0; sbFrame.Parent = mainFrame
local sbLine2 = Instance.new("Frame")
sbLine2.Size=UDim2.new(1,0,0,1); sbLine2.Position=UDim2.new(0,0,1,-1)
sbLine2.BackgroundColor3=C.border; sbLine2.BorderSizePixel=0; sbLine2.Parent=sbFrame
local sbDot = Instance.new("Frame")
sbDot.Size=UDim2.new(0,6,0,6); sbDot.Position=UDim2.new(0,10,0.5,-3)
sbDot.BackgroundColor3=C.accent; sbDot.BorderSizePixel=0; sbDot.Parent=sbFrame; mkCorner(sbDot,3)
local sbTxt = Instance.new("TextLabel")
sbTxt.Size=UDim2.new(0,160,1,0); sbTxt.Position=UDim2.new(0,22,0,0)
sbTxt.BackgroundTransparency=1; sbTxt.Text="EXECUTOR READY"; sbTxt.TextColor3=C.subtext
sbTxt.Font=Enum.Font.Gotham; sbTxt.TextSize=10; sbTxt.TextXAlignment=Enum.TextXAlignment.Left; sbTxt.Parent=sbFrame
local discLbl2 = Instance.new("TextLabel")
discLbl2.Size=UDim2.new(0,200,1,0); discLbl2.Position=UDim2.new(1,-205,0,0)
discLbl2.BackgroundTransparency=1; discLbl2.Text="discord.gg/VPeZbhCz8M"
discLbl2.TextColor3=C.subtext; discLbl2.Font=Enum.Font.Gotham; discLbl2.TextSize=10
discLbl2.TextXAlignment=Enum.TextXAlignment.Right; discLbl2.Parent=sbFrame

local contentArea = Instance.new("Frame")
contentArea.Size=UDim2.new(1,0,1,-104); contentArea.Position=UDim2.new(0,0,0,60)
contentArea.BackgroundColor3=C.panel; contentArea.BorderSizePixel=0; contentArea.Parent=mainFrame

local function makePage()
    local sf = Instance.new("ScrollingFrame")
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.ScrollBarThickness=3; sf.ScrollBarImageColor3=C.accent
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.AutomaticCanvasSize=Enum.AutomaticSize.None
    sf.ScrollingEnabled=true; sf.ScrollingDirection=Enum.ScrollingDirection.Y
    sf.ElasticBehavior=Enum.ElasticBehavior.Never; sf.Visible=false; sf.Parent=contentArea
    return sf
end

local pageAuto       = makePage()
local pageEsp        = makePage()
local pageTP         = makePage()
local pageVehicleTP  = makePage()
local pageAutoFully  = makePage()
local pageAimbot     = makePage()
local pageCredits    = makePage()

local whitelist = {}
local function isWhitelisted(plr) return whitelist[plr.Name] == true end

local function sectionTitle(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-20,0,22); lbl.Position=UDim2.new(0,10,0,yPos)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.subtext
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=parent
    local line = Instance.new("Frame")
    line.Size=UDim2.new(1,-20,0,1); line.Position=UDim2.new(0,10,0,yPos+22)
    line.BackgroundColor3=C.border; line.BorderSizePixel=0; line.Parent=parent
end
local function makeCard(parent, yPos, h)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,-20,0,h or 44); f.Position=UDim2.new(0,10,0,yPos)
    f.BackgroundColor3=C.card; f.BorderSizePixel=0; f.Parent=parent
    mkCorner(f,5); mkStroke(f,1,C.border); return f
end
local function makeLabel(parent, text, x, y, w, h, size, color, font, xalign)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(0,w,0,h); l.Position=UDim2.new(0,x,0,y)
    l.BackgroundTransparency=1; l.Text=text; l.TextColor3=color or C.text
    l.Font=font or Enum.Font.Gotham; l.TextSize=size or 13
    l.TextXAlignment=xalign or Enum.TextXAlignment.Left; l.Parent=parent; return l
end

-- ================================================================
-- PAGE: AUTO MS
-- ================================================================
local startBtn, stopBtn

do
    sectionTitle(pageAuto, "AUTO MARSHMALLOW", 8)
    local sc=makeCard(pageAuto,38,44); makeLabel(sc,"STATUS",12,0,80,44,10,C.subtext)
    statusValue=makeLabel(sc,"OFF",90,0,200,44,15,C.red)
    local pc=makeCard(pageAuto,90,44); makeLabel(pc,"PHASE",12,0,80,44,10,C.subtext)
    phaseValue=makeLabel(pc,"Water",90,0,200,44,14,C.accent2)
    local tc=makeCard(pageAuto,142,44); makeLabel(tc,"TIMER",12,0,80,44,10,C.subtext)
    timerValue=makeLabel(tc,"0s",90,0,200,44,14,C.yellow)
    local ic=makeCard(pageAuto,194,28)
    makeLabel(ic,"PageUp = toggle masak ON/OFF",10,0,400,28,10,C.subtext)
    startBtn=Instance.new("TextButton"); startBtn.Size=UDim2.new(0.47,-10,0,36); startBtn.Position=UDim2.new(0,10,0,230)
    startBtn.BackgroundColor3=C.card; startBtn.Text="START"; startBtn.TextColor3=Color3.fromRGB(0,180,80)
    startBtn.Font=Enum.Font.Gotham; startBtn.TextSize=13; startBtn.BorderSizePixel=0; startBtn.Parent=pageAuto
    mkCorner(startBtn,5); mkStroke(startBtn,1,Color3.fromRGB(0,180,80))
    stopBtn=Instance.new("TextButton"); stopBtn.Size=UDim2.new(0.47,-10,0,36); stopBtn.Position=UDim2.new(0.5,5,0,230)
    stopBtn.BackgroundColor3=C.card; stopBtn.Text="STOP"; stopBtn.TextColor3=Color3.fromRGB(180,40,60)
    stopBtn.Font=Enum.Font.Gotham; stopBtn.TextSize=13; stopBtn.BorderSizePixel=0; stopBtn.Parent=pageAuto
    mkCorner(stopBtn,5); mkStroke(stopBtn,1,Color3.fromRGB(180,40,60))

    sectionTitle(pageAuto,"INVENTORY TRACKER",278)
    local invItems={{name="Water",color=Color3.fromRGB(56,189,248)},{name="Gelatin",color=Color3.fromRGB(251,146,60)},{name="Sugar Block",color=Color3.fromRGB(192,132,252)},{name="Empty Bag",color=Color3.fromRGB(74,222,128)}}
    local invCounts={}
    for i,item in ipairs(invItems) do
        local card=makeCard(pageAuto,308+(i-1)*52,42)
        local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,3,1,-8); bar.Position=UDim2.new(0,4,0,4)
        bar.BackgroundColor3=item.color; bar.BorderSizePixel=0; bar.Parent=card; mkCorner(bar,2)
        makeLabel(card,item.name,14,0,140,42,12,C.text)
        local cnt=makeLabel(card,"0",0,0,-12,42,18,item.color,Enum.Font.Gotham,Enum.TextXAlignment.Right)
        cnt.Size=UDim2.new(1,-12,1,0); invCounts[i]=cnt
    end
    waterCount=invCounts[1]; gelatinCount=invCounts[2]; sugarCount=invCounts[3]; bagCount=invCounts[4]

    sectionTitle(pageAuto,"SAFE MODE",522)
    local safeTogBtn = Instance.new("TextButton")
    safeTogBtn.Size = UDim2.new(1,-20,0,36); safeTogBtn.Position = UDim2.new(0,10,0,548)
    safeTogBtn.BackgroundColor3 = C.card; safeTogBtn.Text = "SAFE MODE : OFF"; safeTogBtn.TextColor3 = C.red
    safeTogBtn.Font = Enum.Font.GothamBold; safeTogBtn.TextSize = 13; safeTogBtn.BorderSizePixel = 0; safeTogBtn.Parent = pageAuto
    mkCorner(safeTogBtn,5); mkStroke(safeTogBtn,1,C.border)
    local smCard1 = makeCard(pageAuto,592,44)
    makeLabel(smCard1,"STATUS",12,0,80,44,10,C.subtext)
    safeModeStatusLbl = makeLabel(smCard1,"OFF",90,0,300,44,13,C.red)
    local smInfoCard = makeCard(pageAuto,644,44)
    makeLabel(smInfoCard,"Detect hit → TP Safe → tunggu musuh pergi → lanjut masak",10,2,440,20,9,C.subtext)

    local function syncSafeModeBtn()
        if safeMode then
            safeTogBtn.Text = "SAFE MODE : ON"; safeTogBtn.TextColor3 = C.accent
            mkStroke(safeTogBtn,1,C.accent)
        else
            safeTogBtn.Text = "SAFE MODE : OFF"; safeTogBtn.TextColor3 = C.red
            mkStroke(safeTogBtn,1,C.border)
        end
    end
    _G.__syncSafeModeBtn = syncSafeModeBtn

    safeTogBtn.MouseButton1Click:Connect(function()
        if fullyRunning then return end
        safeMode = not safeMode
        if safeMode then
            safeModeStatusLbl.Text = "STANDBY"; safeModeStatusLbl.TextColor3 = C.accent
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then lastHealth = hum.Health end
        else
            safeMode = false; safeModeActive = false
            safeModeStatusLbl.Text = "OFF"; safeModeStatusLbl.TextColor3 = C.red
        end
        syncSafeModeBtn()
    end)

    sectionTitle(pageAuto,"AUTO SELL",682)
    local sellTogBtn = Instance.new("TextButton")
    sellTogBtn.Size = UDim2.new(1,-20,0,36); sellTogBtn.Position = UDim2.new(0,10,0,708)
    sellTogBtn.BackgroundColor3 = C.card; sellTogBtn.Text = "AUTO SELL : OFF"; sellTogBtn.TextColor3 = C.red
    sellTogBtn.Font = Enum.Font.GothamBold; sellTogBtn.TextSize = 13; sellTogBtn.BorderSizePixel = 0; sellTogBtn.Parent = pageAuto
    mkCorner(sellTogBtn,5); mkStroke(sellTogBtn,1,C.border)
    local ssc = makeCard(pageAuto,752,44); makeLabel(ssc,"SELL",12,0,80,44,10,C.subtext)
    sellStatusLbl_ref = makeLabel(ssc,"OFF",90,0,200,44,13,C.red)
    local sic = makeCard(pageAuto,804,44); makeLabel(sic,"ITEM",12,0,80,44,10,C.subtext)
    sellItemLbl_ref = makeLabel(sic,"-",90,0,280,44,13,C.text)
    sellTogBtn.MouseButton1Click:Connect(function()
        autoSell_UI = not autoSell_UI
        if autoSell_UI then
            sellTogBtn.Text = "AUTO SELL : ON"; sellTogBtn.TextColor3 = C.accent
            mkStroke(sellTogBtn, 1, C.accent)
            sellStatusLbl_ref.Text = "ON"; sellStatusLbl_ref.TextColor3 = C.accent
        else
            autoSell_UI = false; asSelling = false
            sellTogBtn.Text = "AUTO SELL : OFF"; sellTogBtn.TextColor3 = C.red
            mkStroke(sellTogBtn, 1, C.border)
            sellStatusLbl_ref.Text = "OFF"; sellStatusLbl_ref.TextColor3 = C.red
            sellItemLbl_ref.Text = "-"
        end
    end)

    sectionTitle(pageAuto,"BUY BAHAN",850)
    local buyFullWater   = 1
    local buyFullSugar   = 1
    local buyFullGelatin = 1
    local autoBuyFull    = false

    local function makePlusMinusRow(yPos, label, getVal, setVal)
        local card = makeCard(pageAuto, yPos, 44)
        makeLabel(card, label, 10, 0, 160, 44, 12, C.text)
        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0,30,0,28); minusBtn.Position = UDim2.new(0,170,0,8)
        minusBtn.Text = "-"; minusBtn.TextSize = 18; minusBtn.Font = Enum.Font.GothamBold
        minusBtn.BackgroundColor3 = Color3.fromRGB(40,15,15); minusBtn.TextColor3 = C.red
        minusBtn.BorderSizePixel = 0; minusBtn.Parent = card; mkCorner(minusBtn, 5)
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0,44,0,28); valLbl.Position = UDim2.new(0,205,0,8)
        valLbl.Text = tostring(getVal()); valLbl.TextSize = 14; valLbl.Font = Enum.Font.GothamBold
        valLbl.BackgroundTransparency = 1; valLbl.TextColor3 = C.yellow
        valLbl.TextXAlignment = Enum.TextXAlignment.Center; valLbl.Parent = card
        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0,30,0,28); plusBtn.Position = UDim2.new(0,254,0,8)
        plusBtn.Text = "+"; plusBtn.TextSize = 18; plusBtn.Font = Enum.Font.GothamBold
        plusBtn.BackgroundColor3 = Color3.fromRGB(0,40,20); plusBtn.TextColor3 = C.accent
        plusBtn.BorderSizePixel = 0; plusBtn.Parent = card; mkCorner(plusBtn, 5)
        minusBtn.MouseButton1Click:Connect(function()
            setVal(math.max(0, getVal()-1)); valLbl.Text = tostring(getVal())
        end)
        plusBtn.MouseButton1Click:Connect(function()
            setVal(math.min(100, getVal()+1)); valLbl.Text = tostring(getVal())
        end)
    end

    makePlusMinusRow(876,  "Water",           function() return buyFullWater   end, function(v) buyFullWater   = v end)
    makePlusMinusRow(926,  "Gelatin",         function() return buyFullGelatin end, function(v) buyFullGelatin = v end)
    makePlusMinusRow(976,  "Sugar Block Bag", function() return buyFullSugar   end, function(v) buyFullSugar   = v end)

    local buyTogBtn=Instance.new("TextButton"); buyTogBtn.Size=UDim2.new(1,-20,0,36); buyTogBtn.Position=UDim2.new(0,10,0,1030)
    buyTogBtn.BackgroundColor3=C.card; buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
    buyTogBtn.Font=Enum.Font.Gotham; buyTogBtn.TextSize=13; buyTogBtn.BorderSizePixel=0; buyTogBtn.Parent=pageAuto
    mkCorner(buyTogBtn,5); mkStroke(buyTogBtn,1,C.border)
    local bsc=makeCard(pageAuto,1074,44); makeLabel(bsc,"STATUS",12,0,80,44,10,C.subtext)
    local bsl=makeLabel(bsc,"OFF",90,0,180,44,13,C.red)
    local bpc=makeCard(pageAuto,1126,44); makeLabel(bpc,"ITEM",12,0,80,44,10,C.subtext)
    local bpl=makeLabel(bpc,"Idle",90,0,280,44,13,C.accent2)

    buyTogBtn.MouseButton1Click:Connect(function()
        if autoBuyFull then
            autoBuyFull=false; buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
            bsl.Text="OFF"; bsl.TextColor3=C.red; bpl.Text="Idle"; return
        end
        autoBuyFull=true; buyTogBtn.Text="BUY : ON"; buyTogBtn.TextColor3=C.accent
        bsl.Text="RUNNING"; bsl.TextColor3=C.accent
        buyQty[1] = buyFullGelatin
        buyQty[2] = buyFullSugar
        buyQty[3] = buyFullWater
        task.spawn(function()
            doAutoBuy(function(msg, col)
                bpl.Text = msg; bpl.TextColor3 = col or C.accent2
            end)
            bsl.Text="SELESAI"; bsl.TextColor3=C.accent; bpl.Text="Done"
            task.wait(2)
            autoBuyFull=false; buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
            bsl.Text="OFF"; bsl.TextColor3=C.red; bpl.Text="Idle"
        end)
    end)
    pageAuto.CanvasSize=UDim2.new(0,0,0,1200)
end

-- ================================================================
-- PAGE: AUTO FULLY MS
-- ================================================================
do
    local fullyStatusLbl_af
    local fullyCoordLbl_af
    local fullyTargetLbl_af

    local function setFullyStatus_af(msg, col)
        if fullyStatusLbl_af then
            fullyStatusLbl_af.Text       = msg
            fullyStatusLbl_af.TextColor3 = col or C.subtext
        end
    end

    sectionTitle(pageAutoFully,"AUTO FULLY MS",8)
    local afInfoCard = makeCard(pageAutoFully,38,44)
    makeLabel(afInfoCard,"Loop: Beli bahan → Masak di Apart → Jual → Ulangi",10,2,400,20,9,C.subtext)
    makeLabel(afInfoCard,"Pilih Apart → koordinat tersimpan otomatis!",10,22,400,20,9,C.accent)

    local afApartList = {
        {name="Apart 1", x=1141.8009033203125, y=11.041934967041016, z=450.3515319824219},
        {name="Apart 2", x=1142.488525390625, y=11.0384630731506348, z=421.6380920410156},
        {name="Apart 3", x=984.08892822265620, y=11.029658317565918, z=248.8081359863281},
        {name="Apart 4", x=984.09442138671880, y=11.064784049987793, z=220.2919158935547},
        {name="Apart 5", x=925.53119628906250, y=11.016752243041992, z=39.36603775024414},
        {name="Apart 6", x=896.86053466796880, y=11.042763710021973, z=38.65096664428711},
    }
    local afSelectedApart = 1
    do
        local def = afApartList[1]
        fullySavedPos = Vector3.new(def.x, def.y, def.z)
    end

    local afApartCard = makeCard(pageAutoFully,90,34)
    makeLabel(afApartCard,"Apart Tujuan",10,0,120,34,10,C.subtext)
    fullyCoordLbl_af = makeLabel(afApartCard,afApartList[1].name.."  ✓ Tersimpan",135,0,240,34,10,C.accent)

    local afPrevBtn = Instance.new("TextButton")
    afPrevBtn.Size=UDim2.new(0,26,0,22); afPrevBtn.Position=UDim2.new(1,-62,0.5,-11)
    afPrevBtn.BackgroundColor3=C.card2; afPrevBtn.Text="◀"; afPrevBtn.TextColor3=C.text
    afPrevBtn.Font=Enum.Font.GothamBold; afPrevBtn.TextSize=11; afPrevBtn.BorderSizePixel=0
    afPrevBtn.Parent=afApartCard; mkCorner(afPrevBtn,5)

    local afNextBtn = Instance.new("TextButton")
    afNextBtn.Size=UDim2.new(0,26,0,22); afNextBtn.Position=UDim2.new(1,-30,0.5,-11)
    afNextBtn.BackgroundColor3=C.card2; afNextBtn.Text="▶"; afNextBtn.TextColor3=C.text
    afNextBtn.Font=Enum.Font.GothamBold; afNextBtn.TextSize=11; afNextBtn.BorderSizePixel=0
    afNextBtn.Parent=afApartCard; mkCorner(afNextBtn,5)

    local function updateApartSelection()
        local sel = afApartList[afSelectedApart]
        fullySavedPos = Vector3.new(sel.x, sel.y, sel.z)
        fullyCoordLbl_af.Text = sel.name.."  ✓ Tersimpan"
        fullyCoordLbl_af.TextColor3 = C.accent
    end
    afPrevBtn.MouseButton1Click:Connect(function()
        afSelectedApart = afSelectedApart > 1 and afSelectedApart-1 or #afApartList
        updateApartSelection()
    end)
    afNextBtn.MouseButton1Click:Connect(function()
        afSelectedApart = afSelectedApart < #afApartList and afSelectedApart+1 or 1
        updateApartSelection()
    end)

    local afTargetCard = makeCard(pageAutoFully,132,44)
    makeLabel(afTargetCard,"Target MS per loop",10,0,200,44,11,C.text)
    fullyTargetLbl_af = makeLabel(afTargetCard,tostring(fullyTarget),0,0,0,44,15,C.yellow,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    fullyTargetLbl_af.Size=UDim2.new(0,44,1,0); fullyTargetLbl_af.Position=UDim2.new(0.5,-22,0,0)

    local ftMinW_af = makeCard(pageAutoFully,0,0); ftMinW_af.Parent=afTargetCard
    ftMinW_af.Size=UDim2.new(0,30,0,28); ftMinW_af.Position=UDim2.new(0.5,-22-36,0.5,-14); ftMinW_af.BackgroundColor3=C.card2
    local ftMinB_af=Instance.new("TextButton"); ftMinB_af.Size=UDim2.new(1,0,1,0); ftMinB_af.Text="-"; ftMinB_af.TextSize=16; ftMinB_af.Font=Enum.Font.GothamBold; ftMinB_af.BackgroundTransparency=1; ftMinB_af.TextColor3=C.red; ftMinB_af.BorderSizePixel=0; ftMinB_af.Parent=ftMinW_af; mkCorner(ftMinW_af,5)
    local ftPlusW_af = makeCard(pageAutoFully,0,0); ftPlusW_af.Parent=afTargetCard
    ftPlusW_af.Size=UDim2.new(0,30,0,28); ftPlusW_af.Position=UDim2.new(0.5,22+6,0.5,-14); ftPlusW_af.BackgroundColor3=C.card2
    local ftPlusB_af=Instance.new("TextButton"); ftPlusB_af.Size=UDim2.new(1,0,1,0); ftPlusB_af.Text="+"; ftPlusB_af.TextSize=16; ftPlusB_af.Font=Enum.Font.GothamBold; ftPlusB_af.BackgroundTransparency=1; ftPlusB_af.TextColor3=C.accent; ftPlusB_af.BorderSizePixel=0; ftPlusB_af.Parent=ftPlusW_af; mkCorner(ftPlusW_af,5)
    ftMinB_af.MouseButton1Click:Connect(function()
        fullyTarget = math.max(1, fullyTarget-1)
        fullyTargetLbl_af.Text = tostring(fullyTarget)
    end)
    ftPlusB_af.MouseButton1Click:Connect(function()
        fullyTarget = math.min(99, fullyTarget+1)
        fullyTargetLbl_af.Text = tostring(fullyTarget)
    end)

    local afStatusCard = makeCard(pageAutoFully,184,30)
    fullyStatusLbl_af  = makeLabel(afStatusCard,"Belum dimulai",10,0,400,30,10,C.subtext)

    local afStartBtn = Instance.new("TextButton")
    afStartBtn.Size=UDim2.new(0.48,-12,0,34); afStartBtn.Position=UDim2.new(0,10,0,222)
    afStartBtn.BackgroundColor3=C.card; afStartBtn.Text="START FULLY"
    afStartBtn.TextColor3=C.accent; afStartBtn.Font=Enum.Font.GothamBold
    afStartBtn.TextSize=11; afStartBtn.BorderSizePixel=0; afStartBtn.Parent=pageAutoFully
    mkCorner(afStartBtn,5); mkStroke(afStartBtn,1,C.accent)

    local afStopBtn = Instance.new("TextButton")
    afStopBtn.Size=UDim2.new(0.48,-12,0,34); afStopBtn.Position=UDim2.new(0.5,2,0,222)
    afStopBtn.BackgroundColor3=C.card; afStopBtn.Text="STOP FULLY"
    afStopBtn.TextColor3=C.red; afStopBtn.Font=Enum.Font.GothamBold
    afStopBtn.TextSize=11; afStopBtn.BorderSizePixel=0; afStopBtn.Parent=pageAutoFully
    mkCorner(afStopBtn,5); mkStroke(afStopBtn,1,C.red)

    afStartBtn.MouseButton1Click:Connect(function()
        if fullyRunning then return end
        if not safeMode then
            safeMode = true
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then lastHealth = hum.Health end
            if safeModeStatusLbl then safeModeStatusLbl.Text = "STANDBY"; safeModeStatusLbl.TextColor3 = C.accent end
            if _G.__syncSafeModeBtn then _G.__syncSafeModeBtn() end
        end
        setFullyStatus_af("Auto Fully berjalan... (Safe Mode ON)", C.accent)
        task.spawn(function()
            doAutoFully(setFullyStatus_af)
            setFullyStatus_af("Dihentikan", C.subtext)
            safeMode = false; safeModeActive = false
            if safeModeStatusLbl then safeModeStatusLbl.Text = "OFF"; safeModeStatusLbl.TextColor3 = C.red end
            if _G.__syncSafeModeBtn then _G.__syncSafeModeBtn() end
        end)
    end)
    afStopBtn.MouseButton1Click:Connect(function()
        fullyRunning = false; AutoMS_Running = false; isRunning = false
        safeMode = false; safeModeActive = false
        if safeModeStatusLbl then safeModeStatusLbl.Text = "OFF"; safeModeStatusLbl.TextColor3 = C.red end
        if _G.__syncSafeModeBtn then _G.__syncSafeModeBtn() end
        setFullyStatus_af("Dihentikan", C.yellow)
    end)

    pageAutoFully.CanvasSize=UDim2.new(0,0,0,400)
end

-- ================================================================
-- RUNTIME LOOPS
-- ================================================================

-- Inventory updater
local function updateInventory()
    pcall(function()
        local function ci(name) return countItem(name) end
        local w = ci("Water"); local g = ci("Gelatin"); local s = ci("Sugar Block Bag"); local b = ci("Empty Bag")
        if waterCount    then waterCount.Text    = tostring(w); waterCount.TextColor3    = w>0 and Color3.fromRGB(56,189,248)  or C.subtext end
        if gelatinCount  then gelatinCount.Text  = tostring(g); gelatinCount.TextColor3  = g>0 and Color3.fromRGB(251,146,60)  or C.subtext end
        if sugarCount    then sugarCount.Text    = tostring(s); sugarCount.TextColor3    = s>0 and Color3.fromRGB(192,132,252) or C.subtext end
        if bagCount      then bagCount.Text      = tostring(b); bagCount.TextColor3      = b>0 and Color3.fromRGB(74,222,128)  or C.subtext end
    end)
end
task.spawn(function() while true do updateInventory(); task.wait(1) end end)

-- Auto Sell loop
task.spawn(function()
    while true do
        task.wait(0.4)
        if not autoSell_UI or asSelling then continue end
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not hrp or hum.Health <= 0 then continue end
        if countAllMS() == 0 then
            if sellItemLbl_ref   then sellItemLbl_ref.Text   = "-" end
            if sellStatusLbl_ref then sellStatusLbl_ref.Text = "MENUNGGU"; sellStatusLbl_ref.TextColor3 = C.yellow end
            continue
        end
        asSelling = true
        if sellStatusLbl_ref then sellStatusLbl_ref.Text = "MENJUAL..."; sellStatusLbl_ref.TextColor3 = C.accent end
        doAutoSell(function(msg, col)
            if sellStatusLbl_ref then sellStatusLbl_ref.Text = msg; sellStatusLbl_ref.TextColor3 = col or C.accent end
            if sellItemLbl_ref   then sellItemLbl_ref.Text   = msg end
        end)
        asSelling = false
    end
end)

-- Start/Stop buttons
startBtn.MouseButton1Click:Connect(function()
    if not AutoMS_Running then
        AutoMS_Running=true
        if statusValue then statusValue.Text="STARTING"; statusValue.TextColor3=C.yellow end
        task.spawn(autoMSLoop)
    end
end)
stopBtn.MouseButton1Click:Connect(function()
    AutoMS_Running=false
    if statusValue then statusValue.Text="OFF"; statusValue.TextColor3=C.red end
    if phaseValue  then phaseValue.Text="Water" end
    if timerValue  then timerValue.Text="0s" end
end)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.PageUp then
        if AutoMS_Running then
            AutoMS_Running=false
            if statusValue then statusValue.Text="OFF"; statusValue.TextColor3=C.red end
            if phaseValue  then phaseValue.Text="Water" end
            if timerValue  then timerValue.Text="0s" end
        else
            AutoMS_Running=true
            if statusValue then statusValue.Text="STARTING"; statusValue.TextColor3=C.yellow end
            task.spawn(autoMSLoop)
        end
    end
end)

-- ================================================================
-- SAFE MODE RUNTIME
-- ================================================================
local SAFE_X,SAFE_Y,SAFE_Z = -534.245971679687, 14.356728553771973, 189.90879821777344
local function tpToSafe()
    local char = LocalPlayer.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    local seat = hum2 and hum2.SeatPart
    if seat then
        local vModel = seat:FindFirstAncestorWhichIsA("Model")
        if vModel and vModel.PrimaryPart then
            local seatOff = vModel.PrimaryPart.CFrame:Inverse() * seat.CFrame
            vModel:SetPrimaryPartCFrame(CFrame.new(SAFE_X,SAFE_Y+2,SAFE_Z)*seatOff:Inverse()); return
        end
    end
    hrp.CFrame = CFrame.new(SAFE_X, SAFE_Y+2, SAFE_Z)
end
local safeConn = nil
local function triggerSafeEscape(newHP)
    if not safeMode or safeModeActive then return end
    local dmg = math.floor(lastHealth - newHP)
    if dmg <= 0 then lastHealth = newHP; return end
    safeModeActive = true; lastHealth = newHP

    if fullyRunning then
        fullyRunning = false
        AutoMS_Running = false
        if statusValue then statusValue.Text = "SAFE!"; statusValue.TextColor3 = Color3.fromRGB(255,60,60) end
        if phaseValue  then phaseValue.Text  = "Kabur..." end
    elseif AutoMS_Running then
        AutoMS_Running = false
        if statusValue then statusValue.Text = "SAFE!"; statusValue.TextColor3 = Color3.fromRGB(255,60,60) end
        if phaseValue  then phaseValue.Text  = "Kabur..." end
    end

    if safeModeStatusLbl then safeModeStatusLbl.Text = "HIT -"..dmg.."HP! KABUR..."; safeModeStatusLbl.TextColor3 = Color3.fromRGB(255,60,60) end
    tpToSafe()
    task.spawn(function()
        task.wait(0.5)
        if safeModeStatusLbl then safeModeStatusLbl.Text = "DI SAFE SPOT"; safeModeStatusLbl.TextColor3 = C.accent end
        task.wait(1.5)
        local char2 = LocalPlayer.Character
        local hum2  = char2 and char2:FindFirstChildOfClass("Humanoid")
        if hum2 then lastHealth = hum2.Health end
        safeModeActive = false
        if safeModeStatusLbl then safeModeStatusLbl.Text = "STANDBY"; safeModeStatusLbl.TextColor3 = C.accent end
    end)
end
local function hookSafeMode(char)
    local hum = char:WaitForChild("Humanoid", 10); if not hum then return end
    lastHealth = hum.Health
    if safeConn then safeConn:Disconnect() end
    safeConn = hum.HealthChanged:Connect(triggerSafeEscape)
end
if LocalPlayer.Character then task.spawn(function() hookSafeMode(LocalPlayer.Character) end) end
LocalPlayer.CharacterAdded:Connect(function(char) task.spawn(function() hookSafeMode(char) end) end)

print("=== MAJESTY STORE v8.3.0 LOADED ===")
print("discord.gg/VPeZbhCz8M")