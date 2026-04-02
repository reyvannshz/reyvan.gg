-- ========== MAJESTY STORE v8.7.0 - KIWISENSE THEME ==========
-- Tema GUI diubah ke Kiwisense Library

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Kiwisense/Library.lua"))()

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
            if part and not part:IsA("BasePart") then
                part = part:FindFirstChildOfClass("BasePart") or part
            end
            local checkPart = part
            if checkPart and checkPart:IsA("BasePart") then
                if (root.Position - checkPart.Position).Magnitude <= (radius or 8) then
                    pcall(function() fireproximityprompt(obj) end)
                end
            elseif part then
                local anchorPart = part:FindFirstChildWhichIsA("BasePart", true)
                if anchorPart and (root.Position - anchorPart.Position).Magnitude <= (radius or 8) then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
        end
    end
end

local function cookInteract(toolName, radius)
    if toolName then
        equipTool(toolName)
        task.wait(0.2)
    end
    firePromptNearby(radius or 8)
    task.wait(0.1)
    pcall(function()
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    task.wait(0.1)
    firePromptNearby(radius or 8)
end

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
        while safeModeActive do
            if not isRunning then return nil end
            task.wait(0.5)
        end
        if not isRunning then return nil end
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
local function isNearNPC(radius)
    local ch  = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return (hrp.Position - NPC_MS_POS).Magnitude <= (radius or CFG.SELL_RADIUS + 5)
end

local function waitCharacterStable(timeout)
    local ch  = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then task.wait(1); return end
    local deadline = tick() + (timeout or 2.5)
    local lastPos  = hrp.Position
    repeat
        task.wait(0.25)
        local delta = (hrp.Position - lastPos).Magnitude
        lastPos = hrp.Position
        if delta < 0.5 then return end
    until tick() >= deadline
end

local function equipToolWithRetry(name, maxRetry)
    for i = 1, (maxRetry or 5) do
        local ok = equipTool(name)
        if ok then
            task.wait(0.3)
            local ch = LocalPlayer.Character
            if ch then
                for _, t in ipairs(ch:GetChildren()) do
                    if t:IsA("Tool") and t.Name == name then
                        return true
                    end
                end
            end
        end
        task.wait(0.4)
    end
    return false
end

local SELL_HOLD_DURATION = 1.8
local SELL_HOLD_RETRIES  = 5

local function trySellOne(msName, setStatus2)
    local bS = countItem(CFG.ITEM_MS_SMALL)
    local bM = countItem(CFG.ITEM_MS_MEDIUM)
    local bL = countItem(CFG.ITEM_MS_LARGE)

    setStatus2("Equip: "..msName.."...", Color3.fromRGB(100,180,255))
    local equipped = equipToolWithRetry(msName, 4)
    if not equipped then
        setStatus2("Gagal equip "..msName, Color3.fromRGB(210,40,40))
        unequipAll(); task.wait(0.4)
        return false
    end
    task.wait(0.5)

    local sold = false
    for attempt = 1, SELL_HOLD_RETRIES do
        setStatus2("Jual: "..msName.." — Hold E ("..attempt.."/"..SELL_HOLD_RETRIES..")...", Color3.fromRGB(50,210,110))
        firePromptNearby(CFG.SELL_RADIUS + 5)
        task.wait(0.1)
        pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
        local holdElapsed = 0
        while holdElapsed < SELL_HOLD_DURATION do
            task.wait(0.1)
            holdElapsed += 0.1
            local diff = (bS - countItem(CFG.ITEM_MS_SMALL))
                       + (bM - countItem(CFG.ITEM_MS_MEDIUM))
                       + (bL - countItem(CFG.ITEM_MS_LARGE))
            if diff > 0 then
                pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
                totalSold += diff
                sold = true
                break
            end
        end
        pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
        if sold then break end
        task.wait(0.3)
        local diff2 = (bS - countItem(CFG.ITEM_MS_SMALL))
                    + (bM - countItem(CFG.ITEM_MS_MEDIUM))
                    + (bL - countItem(CFG.ITEM_MS_LARGE))
        if diff2 > 0 then
            totalSold += diff2
            sold = true
            break
        end
        setStatus2("Belum terjual, retry ("..attempt.."/"..SELL_HOLD_RETRIES..")...", Color3.fromRGB(255,155,35))
        task.wait(0.4)
    end
    unequipAll()
    task.wait(0.3)
    return sold
end

local function doAutoSell(setStatus2)
    local msTotal = countAllMS()
    if msTotal == 0 then
        setStatus2("Tidak ada MS di inventory", Color3.fromRGB(160,160,180))
        task.wait(0.8)
        return
    end
    setStatus2("Deteksi "..msTotal.." MS siap jual...", Color3.fromRGB(50,210,110))
    task.wait(0.4)
    setStatus2("Stabilisasi posisi...", Color3.fromRGB(100,180,255))
    waitCharacterStable(2.5)
    if not isNearNPC(CFG.SELL_RADIUS + 8) then
        setStatus2("Terlalu jauh dari NPC, teleport ulang...", Color3.fromRGB(255,155,35))
        fullyTeleport(NPC_MS_POS)
        task.wait(1.2)
        waitCharacterStable(2)
    end

    local sold       = 0
    local maxFail    = 6
    local fail       = 0
    local maxTPRetry = 2
    local tpRetry    = 0

    while countAllMS() > 0 do
        local msName = getEquippableMS()
        if not msName then
            setStatus2("Item MS tidak terdeteksi!", Color3.fromRGB(210,40,40))
            break
        end
        setStatus2("["..countAllMS().." sisa] Proses: "..msName, Color3.fromRGB(100,180,255))
        if not isNearNPC(CFG.SELL_RADIUS + 8) and tpRetry < maxTPRetry then
            tpRetry += 1
            setStatus2("Jauh dari NPC, TP ulang ("..tpRetry..")...", Color3.fromRGB(255,155,35))
            fullyTeleport(NPC_MS_POS)
            task.wait(1.2)
            waitCharacterStable(2)
            continue
        end
        local ok = trySellOne(msName, setStatus2)
        if ok then
            sold  += 1
            fail   = 0
            tpRetry = 0
            setStatus2("Terjual! Total: "..sold.." | Sisa: "..countAllMS(), Color3.fromRGB(50,210,110))
            task.wait(0.35)
        else
            fail += 1
            setStatus2("Gagal jual ("..fail.."/"..maxFail..") — retry...", Color3.fromRGB(255,155,35))
            task.wait(0.8)
            if fail >= 2 and fail % 2 == 0 then
                setStatus2("Re-teleport ke NPC...", Color3.fromRGB(255,155,35))
                unequipAll(); task.wait(0.3)
                fullyTeleport(NPC_MS_POS)
                task.wait(1.2)
                waitCharacterStable(2)
            end
            if fail >= maxFail then
                setStatus2("Gagal jual setelah "..maxFail.."x. Lanjut loop...", Color3.fromRGB(210,40,40))
                break
            end
        end
    end
    unequipAll()
    if sold > 0 then
        setStatus2("Jual selesai! "..sold.." MS | Total keseluruhan: "..totalSold, Color3.fromRGB(50,210,110))
    else
        setStatus2("Tidak ada MS terjual. Periksa posisi NPC!", Color3.fromRGB(255,155,35))
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

local function _setStatus(msg, color)
    if statusValue then statusValue.Text = msg; statusValue.TextColor3 = color or Color3.fromRGB(0,255,136) end
end

local function _setPhase(txt)
    if phaseValue then phaseValue.Text = txt end
end
local function _setTimer(txt)
    if timerValue then timerValue.Text = txt end
end

local function countdown(secs, phaseTxt, color)
    for i = secs, 1, -1 do
        if not isRunning then return false end
        while safeModeActive do
            if not isRunning then return false end
            task.wait(0.5)
        end
        if not isRunning then return false end
        if statusValue then statusValue.Text = phaseTxt; statusValue.TextColor3 = color or Color3.fromRGB(0,255,136) end
        if phaseValue  then phaseValue.Text  = phaseTxt end
        if timerValue  then timerValue.Text  = i.."s" end
        task.wait(1)
    end
    return true
end

local function doOneCook()
    isBusy = true
    table.clear(rpcQueue)

    local snapS = countItem(CFG.ITEM_MS_SMALL)
    local snapM = countItem(CFG.ITEM_MS_MEDIUM)
    local snapL = countItem(CFG.ITEM_MS_LARGE)

    _setStatus("Masukkan Water...", Color3.fromRGB(100,180,255))
    _setPhase("Masukkan Water...")
    cookInteract(CFG.ITEM_WATER)

    local boilSecs
    for _ = 1, 30 do boilSecs = popTimer(); if boilSecs then break end; task.wait(0.1) end
    boilSecs = boilSecs or CFG.WATER_WAIT

    if not countdown(boilSecs, "Mendidih...", Color3.fromRGB(80,150,255)) then
        isBusy = false; return false
    end

    _setStatus("Tunggu Sugar...", Color3.fromRGB(255,220,100))
    _setPhase("Tunggu Sugar...")
    waitRPC("add_sugar", 10)
    if not isRunning then isBusy = false; return false end
    _setStatus("Masukkan Sugar...", Color3.fromRGB(255,220,100))
    _setPhase("Masukkan Sugar...")
    cookInteract(CFG.ITEM_SUGAR)
    task.wait(0.3)

    _setStatus("Tunggu Gelatin...", Color3.fromRGB(255,200,50))
    _setPhase("Tunggu Gelatin...")
    waitRPC("add_gelatin", 10)
    if not isRunning then isBusy = false; return false end
    _setStatus("Masukkan Gelatin...", Color3.fromRGB(255,200,50))
    _setPhase("Masukkan Gelatin...")
    cookInteract(CFG.ITEM_GEL)
    task.wait(0.3)

    local cookSecs
    for _ = 1, 30 do cookSecs = popTimer(); if cookSecs then break end; task.wait(0.1) end
    cookSecs = cookSecs or CFG.COOK_WAIT

    if not countdown(cookSecs, "Memasak...", Color3.fromRGB(80,140,255)) then
        isBusy = false; return false
    end

    _setStatus("Tunggu Bag...", Color3.fromRGB(100,160,255))
    _setPhase("Tunggu Bag...")
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

    _setPhase("Ambil MS...")
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

    _setPhase("Complete #"..totalMS())
    _setTimer("Done")

    isBusy = false; return true
end

local function autoMSLoop()
    isRunning = true
    while isRunning do
        if not hasAllIngredients() then
            _setStatus("BAHAN HABIS!", Color3.fromRGB(255,60,90))
            isRunning = false; break
        end
        local ok, err = pcall(doOneCook)
        if not ok then
            _setStatus("ERROR: "..(err or "?"), Color3.fromRGB(255,60,90))
            task.wait(2)
        end
        if isRunning then task.wait(0.3) end
    end
    isRunning = false
    AutoMS_Running = false
    _setStatus("OFF", Color3.fromRGB(255,60,90))
    if phaseValue then phaseValue.Text = "Water" end
    if timerValue then timerValue.Text = "0s" end
    isBusy = false
end

-- ================================================================
-- VEHICLE TELEPORT ENGINE
-- ================================================================
local function moveVehicle(vehicle, targetPos, isApart)
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

function fullyTeleport(targetPos, isApart)
    local ch  = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum then task.wait(1); return end
    local seatPart = hum.SeatPart
    if seatPart then
        local vehicle = seatPart:FindFirstAncestorOfClass("Model")
        if vehicle then
            moveVehicle(vehicle, targetPos, isApart)
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
-- AUTO FULLY ENGINE
-- ================================================================
local FULLY_ENEMY_RADIUS = 40
local fullySafeEscaping  = false

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
        setFullyStatus("Teleport ke NPC Marshmallow...", Color3.fromRGB(100,180,255))
        fullyTeleport(NPC_MS_POS)
        if not fullyRunning then break end

        setFullyStatus("Beli bahan untuk "..target.." MS...", Color3.fromRGB(100,180,255))
        doAutoBuy(setFullyStatus, target)
        if not fullyRunning then break end
        task.wait(0.5)

        if fullySavedPos then
            setFullyStatus("Teleport ke Apart...", Color3.fromRGB(148,80,255))
            fullyTeleport(fullySavedPos)
        end
        if not fullyRunning then break end
        task.wait(1.5)

        unequipAll()
        table.clear(rpcQueue)
        setFullyStatus("Mulai masak "..target.." MS...", Color3.fromRGB(82,130,255))
        isRunning = true
        local cooked = 0

        while fullyRunning and hasAllIngredients() do
            local ok = doOneCook()
            if ok then cooked += 1 end
            if fullyRunning then task.wait(0.3) end
        end

        isRunning = false
        if not fullyRunning then break end

        local msReady = countAllMS()
        if msReady == 0 then
            setFullyStatus("Tidak ada MS untuk dijual, skip jual...", Color3.fromRGB(255,155,35))
            task.wait(1)
        else
            setFullyStatus(cooked.." MS selesai! Siap jual ("..msReady.." item)...", Color3.fromRGB(52,210,110))
            task.wait(0.5)
            unequipAll()
            task.wait(0.3)
            setFullyStatus("Teleport ke NPC untuk jual...", Color3.fromRGB(52,210,110))
            fullyTeleport(NPC_MS_POS)
            task.wait(1.8)
            if not fullyRunning then break end

            local ch2  = LocalPlayer.Character
            local hrp2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
            if hrp2 and (hrp2.Position - NPC_MS_POS).Magnitude > (CFG.SELL_RADIUS + 10) then
                setFullyStatus("Posisi meleset, teleport ulang...", Color3.fromRGB(255,155,35))
                fullyTeleport(NPC_MS_POS)
                task.wait(1.5)
            end

            if not fullyRunning then break end
            setFullyStatus("Jual semua MS ("..countAllMS().." item)...", Color3.fromRGB(52,210,110))
            doAutoSell(setFullyStatus)
            if not fullyRunning then break end
        end
        task.wait(0.2)
        setFullyStatus("Loop berikutnya...", Color3.fromRGB(100,180,255))
        task.wait(0.2)
    end

    fullyRunning = false
    isRunning = false
    AutoMS_Running = false
    anchorConn:Disconnect()
end


-- ================================================================
-- KIWISENSE GUI SETUP
-- ================================================================

local Window = Library:Window({
    Name = "MAJESTY STORE",
    Version = "v8.7.0",
    Logo = "135215559087473",
    FadeSpeed = 0.25,
})

local Watermark = Library:Watermark("MAJESTY STORE - Kiwisense Theme", "135215559087473")
local KeybindList = Library:KeybindsList()

-- ================================================================
-- PAGES SETUP
-- ================================================================
local Pages = {
    ["Auto MS"] = Window:Page({
        Name = "auto ms",
        Icon = "111178525804834",
        Columns = 2
    }),
    ["General"] = Window:Page({
        Name = "general",
        Icon = "115907015044719",
        Columns = 2
    }),
    ["Teleport"] = Window:Page({
        Name = "teleport",
        Icon = "136623465713368",
        Columns = 1
    }),
    ["VTeleport"] = Window:Page({
        Name = "vteleport",
        Icon = "109463522861706",
        Columns = 1
    }),
    ["Auto Fully"] = Window:Page({
        Name = "auto fully",
        Icon = "137300573942266",
        Columns = 2
    }),
    ["Aimbot"] = Window:Page({
        Name = "aimbot",
        Icon = "111386589037485",
        Columns = 1
    }),
    ["Settings"] = Window:Page({
        Name = "settings",
        Icon = "103863157706913",
        Columns = 2
    })
}

-- ================================================================
-- PAGE: AUTO MS
-- ================================================================
do
    local LeftSection = Pages["Auto MS"]:Section({Name = "auto marshmallow", Icon = "103174889897193", Side = 1})
    local RightSection = Pages["Auto MS"]:Section({Name = "inventory tracker", Icon = "96491224522405", Side = 2})
    local SafeSection = Pages["Auto MS"]:Section({Name = "safe mode", Icon = "137623872962804", Side = 1})
    local SellSection = Pages["Auto MS"]:Section({Name = "auto sell", Icon = "126028986879491", Side = 2})
    local BuySection = Pages["Auto MS"]:Section({Name = "buy bahan", Icon = "116339777575852", Side = 1})

    -- Status Labels
    LeftSection:Label("Status", "Left")
    local statusLbl = LeftSection:Label("OFF", "Left")
    statusLbl.TextColor3 = Color3.fromRGB(255, 60, 90)
    
    LeftSection:Label("Phase", "Left")
    local phaseLbl = LeftSection:Label("Water", "Left")
    phaseLbl.TextColor3 = Color3.fromRGB(0, 196, 255)
    
    LeftSection:Label("Timer", "Left")
    local timerLbl = LeftSection:Label("0s", "Left")
    timerLbl.TextColor3 = Color3.fromRGB(255, 215, 0)

    -- Connect status labels
    statusValue = statusLbl
    phaseValue = phaseLbl
    timerValue = timerLbl

    -- Start/Stop Toggle
    LeftSection:Toggle({
        Name = "auto cook",
        Flag = "AutoCook",
        Default = false,
        Callback = function(Value)
            if Value then
                if not isRunning then
                    isRunning = true
                    _setStatus("STARTING", Color3.fromRGB(255, 200, 0))
                    task.spawn(autoMSLoop)
                end
            else
                isRunning = false
                AutoMS_Running = false
                _setStatus("OFF", Color3.fromRGB(255, 60, 90))
                if phaseValue then phaseValue.Text = "Water" end
                if timerValue then timerValue.Text = "0s" end
            end
        end
    }):Keybind({
        Name = "toggle key",
        Flag = "AutoCookKey",
        Default = Enum.KeyCode.PageUp,
        Mode = "toggle",
        Callback = function(Value)
            if Value then
                local current = Library.Flags["AutoCook"]
                Library.SetFlags["AutoCook"](not current)
            end
        end
    })

    LeftSection:Label("Hotkey: PageUp = toggle ON/OFF", "Left")

    -- Inventory Tracker
    local waterCountLbl, gelatinCountLbl, sugarCountLbl, bagCountLbl
    
    RightSection:Label("Water", "Left")
    waterCountLbl = RightSection:Label("0", "Left")
    waterCountLbl.TextColor3 = Color3.fromRGB(56, 189, 248)
    
    RightSection:Label("Gelatin", "Left")
    gelatinCountLbl = RightSection:Label("0", "Left")
    gelatinCountLbl.TextColor3 = Color3.fromRGB(251, 146, 60)
    
    RightSection:Label("Sugar Block", "Left")
    sugarCountLbl = RightSection:Label("0", "Left")
    sugarCountLbl.TextColor3 = Color3.fromRGB(192, 132, 252)
    
    RightSection:Label("Empty Bag", "Left")
    bagCountLbl = RightSection:Label("0", "Left")
    bagCountLbl.TextColor3 = Color3.fromRGB(74, 222, 128)

    -- Safe Mode
    SafeSection:Toggle({
        Name = "safe mode",
        Flag = "SafeMode",
        Default = false,
        Callback = function(Value)
            safeMode = Value
            if safeMode then
                safeModeStatusLbl = {Text = "STANDBY", TextColor3 = Color3.fromRGB(0, 255, 136)}
                local char = LocalPlayer.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum then lastHealth = hum.Health end
            else
                safeMode = false
                safeModeActive = false
                safeModeStatusLbl = {Text = "OFF", TextColor3 = Color3.fromRGB(255, 60, 90)}
            end
        end
    })
    
    SafeSection:Label("Detect hit → TP Safe → tunggu musuh pergi → lanjut masak", "Left")
    SafeSection:Label("Auto Fully otomatis aktifkan Safe Mode saat START", "Left")

    -- Auto Sell
    SellSection:Toggle({
        Name = "auto sell",
        Flag = "AutoSell",
        Default = false,
        Callback = function(Value)
            autoSell_UI = Value
            if autoSell_UI then
                sellStatusLbl_ref = {Text = "ON", TextColor3 = Color3.fromRGB(0, 255, 136)}
            else
                autoSell_UI = false
                asSelling = false
                sellStatusLbl_ref = {Text = "OFF", TextColor3 = Color3.fromRGB(255, 60, 90)}
                sellItemLbl_ref = {Text = "-"}
            end
        end
    })
    
    SellSection:Label("Sell Status", "Left")
    local sellStatLbl = SellSection:Label("OFF", "Left")
    sellStatLbl.TextColor3 = Color3.fromRGB(255, 60, 90)
    sellStatusLbl_ref = sellStatLbl
    
    SellSection:Label("Item", "Left")
    local sellItmLbl = SellSection:Label("-", "Left")
    sellItemLbl_ref = sellItmLbl

    -- Buy Bahan
    local buyFullWater = 1
    local buyFullSugar = 1
    local buyFullGelatin = 1
    local autoBuyFull = false

    BuySection:Slider({
        Name = "water qty",
        Flag = "BuyWaterQty",
        Min = 0,
        Default = 1,
        Max = 100,
        Suffix = "",
        Decimals = 0,
        Callback = function(Value)
            buyFullWater = Value
        end
    })

    BuySection:Slider({
        Name = "gelatin qty",
        Flag = "BuyGelatinQty",
        Min = 0,
        Default = 1,
        Max = 100,
        Suffix = "",
        Decimals = 0,
        Callback = function(Value)
            buyFullGelatin = Value
        end
    })

    BuySection:Slider({
        Name = "sugar qty",
        Flag = "BuySugarQty",
        Min = 0,
        Default = 1,
        Max = 100,
        Suffix = "",
        Decimals = 0,
        Callback = function(Value)
            buyFullSugar = Value
        end
    })

    BuySection:Button({
        Name = "buy items",
        Callback = function()
            if autoBuyFull then return end
            autoBuyFull = true
            buyQty[1] = buyFullGelatin
            buyQty[2] = buyFullSugar
            buyQty[3] = buyFullWater
            task.spawn(function()
                doAutoBuy(function(msg, col)
                    Library:Notification({
                        Name = "Buy Status",
                        Description = msg,
                        Duration = 3,
                        Icon = "116339777575852",
                        IconColor = col or Color3.fromRGB(0, 255, 136)
                    })
                end)
                autoBuyFull = false
            end)
        end
    })

    -- Inventory updater
    task.spawn(function()
        while true do
            pcall(function()
                local w = countItem("Water")
                local g = countItem("Gelatin")
                local s = countItem("Sugar Block Bag")
                local b = countItem("Empty Bag")
                if waterCountLbl then
                    waterCountLbl.Text = tostring(w)
                    waterCountLbl.TextColor3 = w > 0 and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(122, 143, 160)
                end
                if gelatinCountLbl then
                    gelatinCountLbl.Text = tostring(g)
                    gelatinCountLbl.TextColor3 = g > 0 and Color3.fromRGB(251, 146, 60) or Color3.fromRGB(122, 143, 160)
                end
                if sugarCountLbl then
                    sugarCountLbl.Text = tostring(s)
                    sugarCountLbl.TextColor3 = s > 0 and Color3.fromRGB(192, 132, 252) or Color3.fromRGB(122, 143, 160)
                end
                if bagCountLbl then
                    bagCountLbl.Text = tostring(b)
                    bagCountLbl.TextColor3 = b > 0 and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(122, 143, 160)
                end
            end)
            task.wait(1)
        end
    end)
end


-- ================================================================
-- PAGE: GENERAL (ESP & VEHICLE FLY)
-- ================================================================
do
    local ESPSection = Pages["General"]:Section({Name = "player esp", Icon = "135799335731002", Side = 1})
    local VFlySection = Pages["General"]:Section({Name = "vehicle fly", Icon = "109463522861706", Side = 2})
    local WhitelistSection = Pages["General"]:Section({Name = "whitelist", Icon = "96491224522405", Side = 1})

    -- ESP Functions
    local function createESP(player)
        if espCache[player] then
            for _,o in pairs(espCache[player]) do pcall(function() o:Remove() end) end
            espCache[player] = nil
        end
        local box  = Drawing.new("Square"); box.Thickness=1; box.Color=espBoxColor; box.Filled=false; box.Visible=false
        local nameL= Drawing.new("Text");   nameL.Text=player.Name; nameL.Size=10; nameL.Font=1; nameL.Color=espNameColor; nameL.Outline=true; nameL.OutlineColor=Color3.fromRGB(0,0,0); nameL.Center=true; nameL.Visible=false
        local hpBg = Drawing.new("Square"); hpBg.Thickness=1; hpBg.Color=Color3.fromRGB(30,30,30); hpBg.Filled=true; hpBg.Visible=false
        local hpFl = Drawing.new("Square"); hpFl.Thickness=1; hpFl.Color=Color3.fromRGB(0,255,80);  hpFl.Filled=true; hpFl.Visible=false
        local dL   = Drawing.new("Text");   dL.Size=10; dL.Font=1; dL.Color=Color3.fromRGB(180,220,255); dL.Outline=true; dL.OutlineColor=Color3.fromRGB(0,0,0); dL.Center=true; dL.Visible=false; dL.Text=""
        local iL   = Drawing.new("Text");   iL.Size=10; iL.Font=1; iL.Color=espItemColor; iL.Outline=true; iL.OutlineColor=Color3.fromRGB(0,0,0); iL.Center=true; iL.Visible=false; iL.Text=""
        espCache[player] = {box, nameL, hpBg, hpFl, dL, iL}
    end
    
    local function removeESP(player)
        if espCache[player] then
            for _,o in pairs(espCache[player]) do pcall(function() o:Remove() end) end
            espCache[player] = nil
        end
    end
    
    for _, plr in pairs(Players:GetPlayers()) do if plr ~= LocalPlayer then createESP(plr) end end
    Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            p.CharacterAdded:Connect(function() task.wait(0.5); if espEnabled then createESP(p) end end)
            if espEnabled then createESP(p) end
        end
    end)
    Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

    -- ESP Toggle
    ESPSection:Toggle({
        Name = "player esp",
        Flag = "PlayerESP",
        Default = false,
        Callback = function(Value)
            espEnabled = Value
            if espEnabled then
                for _, plr in pairs(Players:GetPlayers()) do if plr ~= LocalPlayer then createESP(plr) end end
            else
                for _, drawings in pairs(espCache) do for _, o in pairs(drawings) do pcall(function() o.Visible = false end) end end
            end
        end
    })

    ESPSection:Label("Box | Username | HP Bar | Item Held | Distance", "Left")

    -- ESP Colorpickers
    ESPSection:Label("Box Color", "Left"):Colorpicker({
        Name = "Box Color",
        Flag = "ESPBoxColor",
        Default = espBoxColor,
        Alpha = 0,
        Callback = function(Color)
            espBoxColor = Color
        end
    })

    ESPSection:Label("Name Color", "Left"):Colorpicker({
        Name = "Name Color",
        Flag = "ESPNameColor",
        Default = espNameColor,
        Alpha = 0,
        Callback = function(Color)
            espNameColor = Color
        end
    })

    ESPSection:Slider({
        Name = "esp max distance",
        Flag = "ESPMaxDist",
        Min = 10,
        Default = 100,
        Max = 10000,
        Suffix = "m",
        Decimals = 0,
        Callback = function(Value)
            espMaxDist = Value
        end
    })

    -- Vehicle Fly
    local vfStatusLbl
    VFlySection:Toggle({
        Name = "vehicle fly",
        Flag = "VehicleFly",
        Default = false,
        Callback = function(Value)
            vFlyEnabled = Value
            if vFlyEnabled then
                if vFlyConn then vFlyConn:Disconnect(); vFlyConn = nil end
                vFlyConn = RunService.RenderStepped:Connect(function(dt)
                    local char = LocalPlayer.Character
                    if not char then return end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local seat = hum and hum.SeatPart
                    if not seat then
                        if vfStatusLbl then vfStatusLbl.Text = "Tidak di kendaraan"; vfStatusLbl.TextColor3 = Color3.fromRGB(122, 143, 160) end
                        return
                    end
                    local model = seat:FindFirstAncestorOfClass("Model") or seat
                    local root = model.PrimaryPart or seat
                    if vfStatusLbl then vfStatusLbl.Text = "Terbang aktif"; vfStatusLbl.TextColor3 = Color3.fromRGB(0, 255, 136) end
                    local camCF = Camera.CFrame
                    local fwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                    if fwd.Magnitude > 0.01 then fwd = fwd.Unit else fwd = Vector3.new(0, 0, -1) end
                    local rgt = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
                    if rgt.Magnitude > 0.01 then rgt = rgt.Unit else rgt = Vector3.new(1, 0, 0) end
                    local mv = Vector3.zero
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + fwd end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - fwd end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - rgt end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + rgt end
                    if vFlyUp then mv = mv + Vector3.new(0, 1, 0) end
                    if vFlyDown then mv = mv - Vector3.new(0, 1, 0) end
                    pcall(function()
                        for _, p in pairs(model:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.AssemblyLinearVelocity = Vector3.zero
                                p.AssemblyAngularVelocity = Vector3.zero
                            end
                        end
                    end)
                    if mv.Magnitude > 0 then
                        mv = mv.Unit
                        local np = root.Position + mv * vFlySpeed * dt
                        local ld = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                        if ld.Magnitude > 0.01 then ld = ld.Unit else ld = fwd end
                        pcall(function()
                            local cp = model:GetPivot()
                            local tcf = CFrame.new(np, np + ld)
                            local off = cp:ToObjectSpace(root.CFrame)
                            model:PivotTo(tcf * off:Inverse())
                        end)
                    end
                end)
            else
                if vFlyConn then vFlyConn:Disconnect(); vFlyConn = nil end
                vFlyUp = false
                vFlyDown = false
                if vfStatusLbl then vfStatusLbl.Text = "Tidak di kendaraan"; vfStatusLbl.TextColor3 = Color3.fromRGB(122, 143, 160) end
            end
        end
    })

    VFlySection:Label("Status", "Left")
    vfStatusLbl = VFlySection:Label("Tidak di kendaraan", "Left")
    vfStatusLbl.TextColor3 = Color3.fromRGB(122, 143, 160)

    VFlySection:Slider({
        Name = "fly speed",
        Flag = "VFlySpeed",
        Min = 10,
        Default = 60,
        Max = 300,
        Suffix = "",
        Decimals = 0,
        Callback = function(Value)
            vFlySpeed = Value
        end
    })

    VFlySection:Label("E = Naik | Q = Turun | WASD = Steer", "Left")
    VFlySection:Label("Steer otomatis mengikuti arah kamera", "Left")

    UserInputService.InputBegan:Connect(function(input, gpe)
        if not vFlyEnabled or gpe then return end
        if input.KeyCode == Enum.KeyCode.E then vFlyUp = true end
        if input.KeyCode == Enum.KeyCode.Q then vFlyDown = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E then vFlyUp = false end
        if input.KeyCode == Enum.KeyCode.Q then vFlyDown = false end
    end)

    -- Whitelist
    local whitelist = {}
    local function isWhitelisted(plr) return whitelist[plr.Name] == true end
    
    local wlDropdown = WhitelistSection:Dropdown({
        Name = "players",
        Flag = "WLPlayers",
        Items = {},
        Default = "",
        MaxSize = 150,
        Multi = false,
        Callback = function(Value)
        end
    })

    WhitelistSection:Button({
        Name = "add to whitelist",
        Callback = function()
            local selected = Library.Flags["WLPlayers"]
            if selected and selected ~= "" then
                whitelist[selected] = true
                Library:Notification({
                    Name = "Whitelist",
                    Description = selected .. " ditambahkan ke whitelist",
                    Duration = 3,
                    Icon = "116339777575852",
                    IconColor = Color3.fromRGB(0, 255, 136)
                })
            end
        end
    })

    WhitelistSection:Button({
        Name = "clear whitelist",
        Callback = function()
            whitelist = {}
            Library:Notification({
                Name = "Whitelist",
                Description = "Whitelist dikosongkan",
                Duration = 3,
                Icon = "116339777575852",
                IconColor = Color3.fromRGB(255, 60, 90)
            })
        end
    })

    -- Update player list
    task.spawn(function()
        while true do
            local playerNames = {}
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    table.insert(playerNames, plr.Name)
                end
            end
            wlDropdown:Refresh(playerNames)
            task.wait(2)
        end
    end)

    -- ESP Render Loop
    RunService.Heartbeat:Connect(function(dt)
        if not espEnabled then
            for _, drawings in pairs(espCache) do
                for _, o in pairs(drawings) do
                    pcall(function() o.Visible = false end)
                end
            end
            return
        end
        _espAccum = _espAccum + dt
        if _espAccum < ESP_INTERVAL then return end
        _espAccum = 0
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myPos = myHRP and myHRP.Position
        for player, drawings in pairs(espCache) do
            local box = drawings[1]
            local nameL = drawings[2]
            local hpBg = drawings[3]
            local hpFl = drawings[4]
            local dL = drawings[5]
            local iL = drawings[6]
            local function hideAll()
                box.Visible = false
                nameL.Visible = false
                hpBg.Visible = false
                hpFl.Visible = false
                dL.Visible = false
                if iL then iL.Visible = false end
            end
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local valid = char and hum and root and head and hum.Health > 0 and not isWhitelisted(player)
            if not valid then
                hideAll()
            else
                local dist3D = myPos and (root.Position - myPos).Magnitude or 0
                if myPos and espMaxDist > 0 and dist3D > espMaxDist then
                    hideAll()
                else
                    local hrpPos, hrpVis = Camera:WorldToViewportPoint(root.Position)
                    local headPos, headVis = Camera:WorldToViewportPoint(head.Position)
                    if not (hrpVis and headVis) then
                        hideAll()
                    else
                        local height = math.abs(headPos.Y - hrpPos.Y) * 1.7 + (boxPadding * 2)
                        local width = height * 0.55
                        local boxX = hrpPos.X - width / 2
                        local boxY = headPos.Y - boxPadding
                        box.Color = espBoxColor
                        box.Size = Vector2.new(width, height)
                        box.Position = Vector2.new(boxX, boxY)
                        box.Visible = true
                        nameL.Text = player.Name
                        nameL.Color = espNameColor
                        nameL.Position = Vector2.new(hrpPos.X, boxY - 14)
                        nameL.Visible = true
                        local hpR = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 1
                        hpBg.Size = Vector2.new(4, height - 4)
                        hpBg.Position = Vector2.new(boxX - 8, boxY + 2)
                        hpBg.Visible = true
                        hpFl.Color = Color3.fromRGB(255 * (1 - hpR), 255 * hpR, 80)
                        hpFl.Size = Vector2.new(2, (height - 6) * hpR)
                        hpFl.Position = Vector2.new(boxX - 7, boxY + 3 + (height - 6) * (1 - hpR))
                        hpFl.Visible = true
                        dL.Text = math.floor(dist3D) .. "m"
                        dL.Position = Vector2.new(hrpPos.X, boxY + height + 2)
                        dL.Visible = true
                    end
                end
            end
        end
    end)
end


-- ================================================================
-- PAGE: TELEPORT
-- ================================================================
do
    local TPSection = Pages["Teleport"]:Section({Name = "teleport locations", Icon = "136623465713368", Side = 1})
    local LoopSection = Pages["Teleport"]:Section({Name = "auto loop", Icon = "137623872962804", Side = 1})
    local PlrSection = Pages["Teleport"]:Section({Name = "teleport to player", Icon = "96491224522405", Side = 1})

    local tpLocs = {
        {name="Dealership",            x=732.1171264648438,  y=3.3621320724487305, z=406.0807189941406},
        {name="Jual/Beli Marshmellow", x=510.9961853027344,  y=3.5872106552124023, z=598.3929443359375},
        {name="Tier",                  x=1094.7406005859375, y=3.188796043395996,  z=158.09230041503906},
        {name="Casino",                x=1154.863525390625,  y=4.289375305175781,  z=-46.8486328125},
        {name="Jual Casino",           x=1017.5814819335938, y=4.545021533966064,  z=-321.7923889160156},
        {name="GS Ujung",              x=-464.5489501953125, y=3.7371325492858887, z=335.3158874511719},
        {name="GS Mid",                x=218.74879455566406, y=3.729842185974121,  z=-161.87036132812},
        {name="Apart 1 (Kompor)",      x=1141.8009033203125, y=11.041934967041016, z=450.3515319824219},
        {name="Apart 2 (Kompor)",      x=1142.488525390625, y=11.0384630731506348, z=421.6380920410156},
        {name="Apart 3 (Kompor)",      x=984.08892822265620, y=11.029658317565918, z=248.8081359863281},
        {name="Apart 4 (Kompor)",      x=984.09442138671880, y=11.064784049987793, z=220.2919158935547},
        {name="Apart 5 (Kompor)",      x=925.53119628906250, y=11.016752243041992, z=39.36603775024414},
        {name="Apart 6 (Kompor)",      x=896.86053466796880, y=11.042763710021973, z=38.65096664428711},
    }

    local tpDestination = nil
    local tpPending = false

    local function onCharacterAdded(char)
        if not tpPending or not tpDestination then return end
        tpPending = false
        task.spawn(function()
            local hrp = char:WaitForChild("HumanoidRootPart", 10)
            local hum = char:WaitForChild("Humanoid", 10)
            if not hrp or not hum then return end
            task.wait(1)
            hrp.CFrame = CFrame.new(tpDestination.x, tpDestination.y + 3, tpDestination.z)
            tpDestination = nil
            if tpStatusValue then
                tpStatusValue.Text = "ARRIVED"
                tpStatusValue.TextColor3 = Color3.fromRGB(0, 255, 136)
            end
            task.wait(2)
            if tpStatusValue then
                tpStatusValue.Text = "STANDBY"
                tpStatusValue.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
        end)
    end

    if LocalPlayer.Character then task.spawn(function() onCharacterAdded(LocalPlayer.Character) end) end
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

    local function tpTo(x, y, z)
        task.spawn(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            tpDestination = {x=x, y=y, z=z}
            tpPending = true
            if tpStatusValue then
                tpStatusValue.Text = "KILL-RESPAWN-TP"
                tpStatusValue.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
            if char and hum and hum.Health > 0 then hum.Health = 0 end
        end)
    end

    -- Status
    TPSection:Label("Status", "Left")
    local tpStatLbl = TPSection:Label("STANDBY", "Left")
    tpStatLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    tpStatusValue = tpStatLbl

    TPSection:Label("Mode", "Left")
    local tpModeLbl = TPSection:Label("ONCE", "Left")
    tpModeLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
    tpLoopValue = tpModeLbl

    TPSection:Label("Kill - Respawn - TP otomatis ke tujuan", "Left")

    -- Location Buttons
    for i, loc in ipairs(tpLocs) do
        TPSection:Button({
            Name = loc.name,
            Callback = function()
                tpTo(loc.x, loc.y, loc.z)
            end
        })
    end

    -- Auto Loop
    LoopSection:Toggle({
        Name = "auto loop",
        Flag = "AutoLoopTP",
        Default = false,
        Callback = function(Value)
            autoTP_Running = Value
            if autoTP_Running then
                if tpLoopValue then
                    tpLoopValue.Text = "LOOPING"
                    tpLoopValue.TextColor3 = Color3.fromRGB(0, 255, 136)
                end
                autoTP_Thread = task.spawn(function()
                    while autoTP_Running do
                        tpTo(tpLocs[2].x, tpLocs[2].y, tpLocs[2].z)
                        if tpStatusValue then
                            tpStatusValue.Text = "LOOPING..."
                            tpStatusValue.TextColor3 = Color3.fromRGB(255, 215, 0)
                        end
                        for i = 30, 1, -1 do
                            if not autoTP_Running then break end
                            if tpLoopValue then tpLoopValue.Text = "Next: "..i.."s" end
                            task.wait(1)
                        end
                    end
                    if tpLoopValue then
                        tpLoopValue.Text = "ONCE"
                        tpLoopValue.TextColor3 = Color3.fromRGB(0, 255, 136)
                    end
                end)
            else
                autoTP_Running = false
                if tpLoopValue then
                    tpLoopValue.Text = "ONCE"
                    tpLoopValue.TextColor3 = Color3.fromRGB(0, 255, 136)
                end
                if tpStatusValue then
                    tpStatusValue.Text = "STANDBY"
                    tpStatusValue.TextColor3 = Color3.fromRGB(255, 215, 0)
                end
            end
        end
    })

    -- Teleport to Player
    local plrDropdown = PlrSection:Dropdown({
        Name = "select player",
        Flag = "TPPlayerSelect",
        Items = {},
        Default = "",
        MaxSize = 150,
        Multi = false,
        Callback = function(Value)
        end
    })

    PlrSection:Button({
        Name = "teleport to player",
        Callback = function()
            local selected = Library.Flags["TPPlayerSelect"]
            if selected and selected ~= "" then
                for _, plr in pairs(Players:GetPlayers()) do
                    if plr.Name == selected then
                        local tgt = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if tgt then
                            tpDestination = {x=tgt.Position.X+2, y=tgt.Position.Y, z=tgt.Position.Z}
                            tpPending = true
                            if tpStatusValue then
                                tpStatusValue.Text = "TP: "..plr.Name
                                tpStatusValue.TextColor3 = Color3.fromRGB(255, 215, 0)
                            end
                            local c2 = LocalPlayer.Character
                            local h2 = c2 and c2:FindFirstChildOfClass("Humanoid")
                            if c2 and h2 and h2.Health > 0 then h2.Health = 0 end
                        end
                        break
                    end
                end
            end
        end
    })

    -- Update player list
    task.spawn(function()
        while true do
            local playerNames = {}
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    table.insert(playerNames, plr.Name)
                end
            end
            plrDropdown:Refresh(playerNames)
            task.wait(2)
        end
    end)
end

-- ================================================================
-- PAGE: VEHICLE TELEPORT
-- ================================================================
do
    local VehSection = Pages["VTeleport"]:Section({Name = "vehicle teleport", Icon = "109463522861706", Side = 1})
    local KomporSection = Pages["VTeleport"]:Section({Name = "kompor apartment", Icon = "103174889897193", Side = 1})

    local cachedSeat = nil
    local function updateSeatCache()
        local char = LocalPlayer.Character
        if not char then cachedSeat = nil; return end
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Humanoid") then
                local seat = obj.SeatPart
                if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
                    cachedSeat = seat
                    return
                end
            end
        end
        cachedSeat = nil
    end

    local function hookCharacter(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        hum:GetPropertyChangedSignal("SeatPart"):Connect(updateSeatCache)
        updateSeatCache()
    end

    if LocalPlayer.Character then task.spawn(hookCharacter, LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(char) task.spawn(hookCharacter, char) end)

    VehSection:Label("Tidak perlu mati | Bisa dipakai saat naik motor", "Left")
    
    VehSection:Label("Kendaraan", "Left")
    local vehStatusLbl = VehSection:Label("Tidak ditemukan", "Left")
    vehStatusLbl.TextColor3 = Color3.fromRGB(255, 60, 90)

    task.spawn(function()
        while true do
            task.wait(1)
            if cachedSeat then
                local vehModel = cachedSeat:FindFirstAncestorWhichIsA("Model")
                vehStatusLbl.Text = vehModel and vehModel.Name or cachedSeat.Name
                vehStatusLbl.TextColor3 = Color3.fromRGB(0, 220, 100)
            else
                vehStatusLbl.Text = "Tidak ditemukan"
                vehStatusLbl.TextColor3 = Color3.fromRGB(255, 60, 90)
            end
        end
    end)

    local function tpVehicle(x, y, z)
        task.spawn(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local spawnPos = Vector3.new(x, y + 2, z)
            local targetCF = CFrame.new(spawnPos, spawnPos + Vector3.new(0, 0, 1))
            if cachedSeat then
                local vehModel = cachedSeat:FindFirstAncestorWhichIsA("Model")
                if vehModel and vehModel.PrimaryPart then
                    local seatOffset = vehModel.PrimaryPart.CFrame:Inverse() * cachedSeat.CFrame
                    vehModel:SetPrimaryPartCFrame(targetCF * seatOffset:Inverse())
                elseif vehModel then
                    local delta = targetCF * cachedSeat.CFrame:Inverse()
                    for _, part in ipairs(vehModel:GetDescendants()) do
                        if part:IsA("BasePart") then part.CFrame = delta * part.CFrame end
                    end
                end
            else
                hrp.CFrame = targetCF
            end
        end)
    end

    local vtpLocs = {
        {name="Dealership",            x=732.1171264648438,  y=3.3621320724487305, z=406.0807189941406},
        {name="Jual/Beli Marshmellow", x=510.9961853027344,  y=3.5872106552124023, z=598.3929443359375},
        {name="Tier",                  x=1094.7406005859375, y=3.188796043395996,  z=158.09230041503906},
        {name="Casino",                x=1154.863525390625,  y=4.289375305175781,  z=-46.8486328125},
        {name="Jual Casino",           x=1017.5814819335938, y=4.545021533966064,  z=-321.7923889160156},
        {name="GS Ujung",              x=-464.5489501953125, y=3.7371325492858887, z=335.3158874511719},
        {name="GS Mid",                x=218.74879455566406, y=3.729842185974121,  z=-161.87036132812},
        {name="Safe",                  x=120.85433197021484, y=4.297231197357178,  z=-587.6337280273438},
        {name="Apart 1 (Kompor)",      x=1141.8009033203125, y=11.041934967041016, z=450.3515319824219},
        {name="Apart 2 (Kompor)",      x=1142.488525390625, y=11.0384630731506348, z=421.6380920410156},
        {name="Apart 3 (Kompor)",      x=984.08892822265620, y=11.029658317565918, z=248.8081359863281},
        {name="Apart 4 (Kompor)",      x=984.09442138671880, y=11.064784049987793, z=220.2919158935547},
        {name="Apart 5 (Kompor)",      x=925.53119628906250, y=11.016752243041992, z=39.36603775024414},
        {name="Apart 6 (Kompor)",      x=896.86053466796880, y=11.042763710021973, z=38.65096664428711},
    }

    for i, loc in ipairs(vtpLocs) do
        VehSection:Button({
            Name = loc.name,
            Callback = function()
                tpVehicle(loc.x, loc.y, loc.z)
            end
        })
    end

    local kompors = {
        {name="Kompor Apart 1", x=1141.8009033203125, y=11.041934967041016, z=450.3515319824219},
        {name="Kompor Apart 2", x=1142.488525390625, y=11.0384630731506348, z=421.6380920410156},
        {name="Kompor Apart 3", x=984.08892822265620, y=11.029658317565918, z=248.8081359863281},
        {name="Kompor Apart 4", x=984.09442138671880, y=11.064784049987793, z=220.2919158935547},
        {name="Kompor Apart 5", x=925.53119628906250, y=11.016752243041992, z=39.36603775024414},
        {name="Kompor Apart 6", x=896.86053466796880, y=11.042763710021973, z=38.65096664428711},
    }

    for i, k in ipairs(kompors) do
        KomporSection:Button({
            Name = k.name,
            Callback = function()
                tpVehicle(k.x, k.y, k.z)
            end
        })
    end
end


-- ================================================================
-- PAGE: AUTO FULLY MS
-- ================================================================
do
    local InfoSection = Pages["Auto Fully"]:Section({Name = "info", Icon = "137300573942266", Side = 1})
    local ApartSection = Pages["Auto Fully"]:Section({Name = "apart settings", Icon = "103174889897193", Side = 2})
    local TargetSection = Pages["Auto Fully"]:Section({Name = "target settings", Icon = "96491224522405", Side = 1})
    local ControlSection = Pages["Auto Fully"]:Section({Name = "controls", Icon = "116339777575852", Side = 2})
    local SafeSection = Pages["Auto Fully"]:Section({Name = "safe mode", Icon = "137623872962804", Side = 1})

    local fullyStatusLbl_af
    local fullyCoordLbl_af
    local fullyTargetLbl_af

    local function setFullyStatus_af(msg, col)
        if fullyStatusLbl_af then
            fullyStatusLbl_af.Text = msg
            fullyStatusLbl_af.TextColor3 = col or Color3.fromRGB(122, 143, 160)
        end
    end

    InfoSection:Label("Loop: Beli bahan → Masak di Apart → Jual → Ulangi", "Left")
    InfoSection:Label("Pilih Apart → koordinat tersimpan otomatis!", "Left")

    InfoSection:Label("Status", "Left")
    local afStatusLbl = InfoSection:Label("Belum dimulai", "Left")
    afStatusLbl.TextColor3 = Color3.fromRGB(122, 143, 160)
    fullyStatusLbl_af = afStatusLbl

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

    ApartSection:Label("Apart Tujuan", "Left")
    local afCoordLbl = ApartSection:Label(afApartList[1].name.."  ✓ Tersimpan", "Left")
    afCoordLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
    fullyCoordLbl_af = afCoordLbl

    ApartSection:Dropdown({
        Name = "pilih apart",
        Flag = "ApartSelect",
        Items = {"Apart 1", "Apart 2", "Apart 3", "Apart 4", "Apart 5", "Apart 6"},
        Default = "Apart 1",
        MaxSize = 150,
        Multi = false,
        Callback = function(Value)
            for i, apart in ipairs(afApartList) do
                if apart.name == Value then
                    afSelectedApart = i
                    fullySavedPos = Vector3.new(apart.x, apart.y, apart.z)
                    if fullyCoordLbl_af then
                        fullyCoordLbl_af.Text = apart.name.."  ✓ Tersimpan"
                        fullyCoordLbl_af.TextColor3 = Color3.fromRGB(0, 255, 136)
                    end
                    break
                end
            end
        end
    })

    TargetSection:Slider({
        Name = "target ms per loop",
        Flag = "FullyTarget",
        Min = 1,
        Default = 10,
        Max = 99,
        Suffix = "",
        Decimals = 0,
        Callback = function(Value)
            fullyTarget = Value
            if fullyTargetLbl_af then
                fullyTargetLbl_af.Text = tostring(Value)
            end
        end
    })

    TargetSection:Label("Target", "Left")
    local afTargetLbl = TargetSection:Label("10", "Left")
    afTargetLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    fullyTargetLbl_af = afTargetLbl

    TargetSection:Slider({
        Name = "radius deteksi musuh",
        Flag = "EnemyRadius",
        Min = 10,
        Default = 40,
        Max = 200,
        Suffix = "st",
        Decimals = 0,
        Callback = function(Value)
            FULLY_ENEMY_RADIUS = Value
        end
    })

    TargetSection:Label("Musuh dalam radius ini = kabur dulu sebelum masak", "Left")

    ControlSection:Button({
        Name = "start fully",
        Callback = function()
            if fullyRunning then return end
            if not safeMode then
                safeMode = true
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then lastHealth = hum.Health end
            end
            setFullyStatus_af("Auto Fully berjalan... (Safe Mode ON)", Color3.fromRGB(0, 255, 136))
            task.spawn(function()
                doAutoFully(setFullyStatus_af)
                setFullyStatus_af("Dihentikan", Color3.fromRGB(122, 143, 160))
                safeMode = false
                safeModeActive = false
            end)
        end
    })

    ControlSection:Button({
        Name = "stop fully",
        Callback = function()
            fullyRunning = false
            isRunning = false
            AutoMS_Running = false
            safeMode = false
            safeModeActive = false
            setFullyStatus_af("Dihentikan", Color3.fromRGB(255, 215, 0))
        end
    })

    SafeSection:Label("Safe Mode", "Left")
    local afSafeLbl = SafeSection:Label("Auto (ikut START/STOP)", "Left")
    afSafeLbl.TextColor3 = Color3.fromRGB(122, 143, 160)

    task.spawn(function()
        while true do
            if fullyRunning then
                if safeMode then
                    afSafeLbl.Text = "🟢 ON – Aktif"
                    afSafeLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
                else
                    afSafeLbl.Text = "⚪ OFF"
                    afSafeLbl.TextColor3 = Color3.fromRGB(122, 143, 160)
                end
            else
                afSafeLbl.Text = "Auto (ikut START/STOP)"
                afSafeLbl.TextColor3 = Color3.fromRGB(122, 143, 160)
            end
            task.wait(0.5)
        end
    end)
end

-- ================================================================
-- PAGE: AIMBOT
-- ================================================================
do
    local MainSection = Pages["Aimbot"]:Section({Name = "aimbot settings", Icon = "111386589037485", Side = 1})
    local TargetSection = Pages["Aimbot"]:Section({Name = "target settings", Icon = "126028986879491", Side = 1})
    local KeySection = Pages["Aimbot"]:Section({Name = "keybinds", Icon = "137300573942266", Side = 1})
    local SettingsSection = Pages["Aimbot"]:Section({Name = "settings", Icon = "103863157706913", Side = 1})

    -- Aimbot Toggle
    MainSection:Toggle({
        Name = "enable aimbot",
        Flag = "AimbotEnabled",
        Default = false,
        Callback = function(Value)
            aimbotEnabled = Value
            if aimbotStatusLbl then
                aimbotStatusLbl.Text = Value and "ON" or "OFF"
                aimbotStatusLbl.TextColor3 = Value and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(255, 60, 90)
            end
            if aimbotFovCircle then aimbotFovCircle.Visible = Value end
        end
    })

    MainSection:Label("Status", "Left")
    local aimStatLbl = MainSection:Label("OFF", "Left")
    aimStatLbl.TextColor3 = Color3.fromRGB(255, 60, 90)
    aimbotStatusLbl = aimStatLbl

    MainSection:Dropdown({
        Name = "aim mode",
        Flag = "AimbotMode",
        Items = {"Camera", "FreeAim"},
        Default = "Camera",
        MaxSize = 100,
        Multi = false,
        Callback = function(Value)
            aimbotMode = Value
        end
    })

    TargetSection:Dropdown({
        Name = "target part",
        Flag = "AimbotTarget",
        Items = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"},
        Default = "Head",
        MaxSize = 150,
        Multi = false,
        Callback = function(Value)
            aimbotTarget = Value
        end
    })

    TargetSection:Dropdown({
        Name = "lock priority",
        Flag = "AimbotPriority",
        Items = {"Crosshair", "Distance"},
        Default = "Crosshair",
        MaxSize = 100,
        Multi = false,
        Callback = function(Value)
            aimbotPriority = Value
        end
    })

    KeySection:Label("Hold Key", "Left")
    local kbBtn = KeySection:Label("RMB", "Left")
    kbBtn.TextColor3 = Color3.fromRGB(0, 196, 255)
    keybindBtnRef = kbBtn

    KeySection:Button({
        Name = "set keybind",
        Callback = function()
            if isBindingKey then return end
            isBindingKey = true
            kbBtn.Text = "..."
            kbBtn.TextColor3 = Color3.fromRGB(122, 143, 160)
        end
    })

    KeySection:Label("Hide/Show GUI (atur di tab SETTINGS)", "Left")

    SettingsSection:Slider({
        Name = "fov radius",
        Flag = "AimbotFOV",
        Min = 20,
        Default = 250,
        Max = 400,
        Suffix = "px",
        Decimals = 0,
        Callback = function(Value)
            aimbotFOV = Value
            if aimbotFovCircle then aimbotFovCircle.Radius = Value end
        end
    })

    SettingsSection:Slider({
        Name = "smooth",
        Flag = "AimbotSmooth",
        Min = 1,
        Default = 8,
        Max = 20,
        Suffix = "",
        Decimals = 0,
        Callback = function(Value)
            aimbotSmooth = Value
        end
    })

    SettingsSection:Slider({
        Name = "aimbot max distance",
        Flag = "AimbotMaxDist",
        Min = 10,
        Default = 100,
        Max = 10000,
        Suffix = "m",
        Decimals = 0,
        Callback = function(Value)
            aimbotMaxDist = Value
        end
    })

    SettingsSection:Toggle({
        Name = "enable prediction",
        Flag = "AimbotPrediction",
        Default = true,
        Callback = function(Value)
            aimbotPrediction = Value
        end
    })

    SettingsSection:Slider({
        Name = "prediction strength",
        Flag = "PredStrength",
        Min = 0,
        Default = 15,
        Max = 100,
        Suffix = "%",
        Decimals = 0,
        Callback = function(Value)
            predStrength = Value / 100
        end
    })

    -- Keybind handler
    UserInputService.InputBegan:Connect(function(input, gpe)
        if isBindingKey then
            if input.UserInputType == Enum.UserInputType.MouseButton1 then return end
            isBindingKey = false
            local kn = tostring(input.KeyCode):gsub("Enum%.KeyCode%.", "")
            local un = tostring(input.UserInputType):gsub("Enum%.UserInputType%.", "")
            if un == "MouseButton2" then
                aimbotKeybindType = "MouseButton"
                aimbotKeybind = Enum.UserInputType.MouseButton2
                aimbotKeybindLabel = "RMB"
            elseif un == "MouseButton3" then
                aimbotKeybindType = "MouseButton"
                aimbotKeybind = Enum.UserInputType.MouseButton3
                aimbotKeybindLabel = "MMB"
            elseif un == "Keyboard" and kn ~= "Unknown" then
                aimbotKeybindType = "KeyCode"
                aimbotKeybindCode = input.KeyCode
                aimbotKeybindLabel = kn
            else
                isBindingKey = true
                return
            end
            kbBtn.Text = aimbotKeybindLabel
            kbBtn.TextColor3 = Color3.fromRGB(0, 196, 255)
        end
    end)

    -- Aimbot Loop
    local function getClosestPlayer()
        local closest = nil
        local shortestDist = aimbotFOV
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then return nil end
        local myPos = myHRP.Position
        local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local targetPart = char and char:FindFirstChild(aimbotTarget)
                if hum and targetPart and hum.Health > 0 then
                    local dist3D = (targetPart.Position - myPos).Magnitude
                    if dist3D <= aimbotMaxDist then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                            if aimbotPriority == "Crosshair" then
                                if dist2D < shortestDist then
                                    shortestDist = dist2D
                                    closest = targetPart
                                end
                            else
                                if dist3D < shortestDist then
                                    shortestDist = dist3D
                                    closest = targetPart
                                end
                            end
                        end
                    end
                end
            end
        end
        return closest
    end

    RunService.RenderStepped:Connect(function()
        if not aimbotEnabled then return end
        local holdingKey = false
        if aimbotKeybindType == "MouseButton" then
            holdingKey = UserInputService:IsMouseButtonPressed(aimbotKeybind)
        else
            holdingKey = UserInputService:IsKeyDown(aimbotKeybindCode)
        end
        if not holdingKey then return end
        local target = getClosestPlayer()
        if target then
            local targetPos = target.Position
            if aimbotPrediction then
                local vel = target.AssemblyLinearVelocity
                if vel then
                    targetPos = targetPos + (vel * predStrength)
                end
            end
            if aimbotMode == "Camera" then
                local cf = CFrame.new(Camera.CFrame.Position, targetPos)
                Camera.CFrame = Camera.CFrame:Lerp(cf, 1 / aimbotSmooth)
            else
                local myChar = LocalPlayer.Character
                local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local cf = CFrame.new(myHRP.Position, targetPos)
                    myHRP.CFrame = myHRP.CFrame:Lerp(cf, 1 / aimbotSmooth)
                end
            end
        end
    end)
end


-- ================================================================
-- PAGE: SETTINGS
-- ================================================================
do
    local ThemeSection = Pages["Settings"]:Section({Name = "theming", Icon = "103863157706913", Side = 1})
    local ConfigSection = Pages["Settings"]:Section({Name = "configuration", Icon = "137300573942266", Side = 2})

    -- Theme presets
    ThemeSection:Dropdown({
        Name = "preset themes",
        Flag = "ThemePreset",
        Items = {"Preset", "Halloween", "Aqua", "One Tap"},
        Default = "Preset",
        Multi = false,
        Callback = function(Value)
            local ThemeData = Library.Themes[Value]
            if not ThemeData then return end
            for Index, Value in Library.Theme do
                Library.Theme[Index] = ThemeData[Index]
                Library:ChangeTheme(Index, ThemeData[Index])
            end
            task.wait(0.3)
            Library:Thread(function()
                for Index, Value in Library.Theme do
                    Library.Theme[Index] = Library.Flags["ColorpickerTheme" .. Index].Color
                    Library:ChangeTheme(Index, Library.Flags["ColorpickerTheme" .. Index].Color)
                end
            end)
        end
    })

    -- Theme color pickers
    for Index, Value in Library.Theme do
        Library.ThemeColorpickers[Index] = ThemeSection:Label(Index, "Left"):Colorpicker({
            Name = "Colorpicker",
            Flag = "ColorpickerTheme" .. Index,
            Default = Value,
            Alpha = 0,
            Callback = function(Color, Alpha)
                Library.Theme[Index] = Color
                Library:ChangeTheme(Index, Color)
            end
        })
    end

    -- Config buttons
    ConfigSection:Button({
        Name = "save config",
        Callback = function()
            local configName = "MajestyStoreConfig"
            writefile(Library.Folders.Configs .. "/" .. configName .. ".json", Library:GetConfig())
            Library:Notification({
                Name = "Success",
                Description = "Config saved successfully!",
                Duration = 3,
                Icon = "116339777575852",
                IconColor = Color3.fromRGB(0, 255, 136)
            })
        end
    })

    ConfigSection:Button({
        Name = "load config",
        Callback = function()
            local configName = "MajestyStoreConfig"
            local success, result = Library:LoadConfig(readfile(Library.Folders.Configs .. "/" .. configName .. ".json"))
            if success then
                Library:Notification({
                    Name = "Success",
                    Description = "Config loaded successfully!",
                    Duration = 3,
                    Icon = "116339777575852",
                    IconColor = Color3.fromRGB(0, 255, 136)
                })
            else
                Library:Notification({
                    Name = "Error",
                    Description = "Failed to load config!",
                    Duration = 3,
                    Icon = "97118059177470",
                    IconColor = Color3.fromRGB(255, 60, 90)
                })
            end
        end
    })

    ConfigSection:Button({
        Name = "hide/show gui",
        Callback = function()
            local mainFrame = Window.Items["MainFrame"]
            if mainFrame then
                mainFrame.Instance.Visible = not mainFrame.Instance.Visible
            end
        end
    })

    ConfigSection:Label("Menu Keybind: Z (default)", "Left")
    ConfigSection:Label("Watermark dan Keybind List aktif", "Left")
end

-- ================================================================
-- SAFE MODE RUNTIME
-- ================================================================
local SAFE_X, SAFE_Y, SAFE_Z = -534.245971679687, 14.356728553771973, 189.90879821777344
local SAFE_POS_VEC = Vector3.new(SAFE_X, SAFE_Y, SAFE_Z)
local _safeLastTrigger = 0
local SAFE_COOLDOWN = 3.0

local SM = {
    wasFullyRunning = false,
    savedPhase = nil,
    cookInProgress = false,
}

local function tpToSafe()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    local seat = hum2 and hum2.SeatPart
    local targetCF = CFrame.new(SAFE_X, SAFE_Y + 3, SAFE_Z)
    if seat then
        local vModel = seat:FindFirstAncestorWhichIsA("Model")
        if vModel and vModel.PrimaryPart then
            for _ = 1, 3 do
                pcall(function() vModel:SetPrimaryPartCFrame(targetCF) end)
            end
            return
        end
    end
    for _ = 1, 3 do
        pcall(function() hrp.CFrame = targetCF end)
    end
end

local function hasEnemyNear(pos, radius)
    local whitelist = {}
    for name, _ in pairs(whitelist) do
        whitelist[name] = true
    end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not whitelist[plr.Name] then
            local ch2 = plr.Character
            local hum2 = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            local hrp2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
            if hum2 and hrp2 and hum2.Health > 0 then
                local dist = (hrp2.Position - pos).Magnitude
                if dist <= radius then
                    return true, plr.Name, math.floor(dist)
                end
            end
        end
    end
    return false, nil, 0
end

local function setSafeLbl(msg, col)
    if safeModeStatusLbl then
        safeModeStatusLbl.Text = msg
        safeModeStatusLbl.TextColor3 = col or Color3.fromRGB(255, 200, 0)
    end
end

local function detectCookPhase()
    local hasWater = countItem(CFG.ITEM_WATER) >= 1
    local hasSugar = countItem(CFG.ITEM_SUGAR) >= 1
    local hasGelatin = countItem(CFG.ITEM_GEL) >= 1
    local hasEmptyBag = countItem(CFG.ITEM_EMPTY) >= 1
    for _, v in ipairs(rpcQueue) do
        if v.type == "wait_boil" then return "need_sugar", hasWater, hasSugar, hasGelatin
        elseif v.type == "add_sugar" then return "need_sugar", hasWater, hasSugar, hasGelatin
        elseif v.type == "add_gelatin" then return "need_gelatin", hasWater, hasSugar, hasGelatin
        elseif v.type == "wait_cook" then return "cooking_progress", hasWater, hasSugar, hasGelatin
        elseif v.type == "bag_result" then return "need_bag", hasWater, hasSugar, hasGelatin
        end
    end
    if hasWater and hasSugar and hasGelatin then return "fresh", hasWater, hasSugar, hasGelatin
    elseif not hasWater and hasSugar and hasGelatin then return "need_sugar", hasWater, hasSugar, hasGelatin
    elseif not hasWater and not hasSugar and hasGelatin then return "need_gelatin", hasWater, hasSugar, hasGelatin
    elseif not hasWater and not hasSugar and not hasGelatin then
        if hasEmptyBag then return "need_bag", hasWater, hasSugar, hasGelatin
        else return "cooking_progress", hasWater, hasSugar, hasGelatin end
    end
    return "unknown", hasWater, hasSugar, hasGelatin
end

local function resumeCookFromPhase()
    local phase, hasWater, hasSugar, hasGelatin = detectCookPhase()
    isBusy = true
    local snapS = countItem(CFG.ITEM_MS_SMALL)
    local snapM = countItem(CFG.ITEM_MS_MEDIUM)
    local snapL = countItem(CFG.ITEM_MS_LARGE)
    _setStatus("Resume: "..phase, Color3.fromRGB(255, 200, 50))
    _setPhase("Resume: "..phase)
    if phase == "fresh" or phase == "need_water" then
        if not isRunning then isBusy = false; return false end
        _setStatus("Masukkan Water...", Color3.fromRGB(100, 180, 255))
        _setPhase("Masukkan Water...")
        cookInteract(CFG.ITEM_WATER)
        local boilSecs
        for _ = 1, 30 do boilSecs = popTimer(); if boilSecs then break end; task.wait(0.1) end
        boilSecs = boilSecs or CFG.WATER_WAIT
        if not countdown(boilSecs, "Mendidih...", Color3.fromRGB(80, 150, 255)) then isBusy = false; return false end
        phase = "need_sugar"
    end
    if phase == "need_sugar" then
        if not isRunning then isBusy = false; return false end
        _setStatus("Tunggu Sugar...", Color3.fromRGB(255, 220, 100))
        _setPhase("Tunggu Sugar...")
        waitRPC("add_sugar", 15)
        if not isRunning then isBusy = false; return false end
        _setStatus("Masukkan Sugar...", Color3.fromRGB(255, 220, 100))
        _setPhase("Masukkan Sugar...")
        cookInteract(CFG.ITEM_SUGAR)
        task.wait(0.4)
        phase = "need_gelatin"
    end
    if phase == "need_gelatin" then
        if not isRunning then isBusy = false; return false end
        _setStatus("Tunggu Gelatin...", Color3.fromRGB(255, 200, 50))
        _setPhase("Tunggu Gelatin...")
        waitRPC("add_gelatin", 15)
        if not isRunning then isBusy = false; return false end
        _setStatus("Masukkan Gelatin...", Color3.fromRGB(255, 200, 50))
        _setPhase("Masukkan Gelatin...")
        cookInteract(CFG.ITEM_GEL)
        task.wait(0.4)
        phase = "need_bag"
    end
    if phase == "need_bag" or phase == "cooking_progress" then
        if not isRunning then isBusy = false; return false end
        local cookSecs
        for _ = 1, 30 do cookSecs = popTimer(); if cookSecs then break end; task.wait(0.1) end
        cookSecs = cookSecs or CFG.COOK_WAIT
        if not countdown(cookSecs, "Memasak (resume)...", Color3.fromRGB(80, 140, 255)) then isBusy = false; return false end
        _setStatus("Tunggu Bag...", Color3.fromRGB(100, 160, 255))
        _setPhase("Tunggu Bag...")
        waitRPC("bag_result", 18)
        local bag
        local t2 = 0
        repeat
            bag = LocalPlayer.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
            task.wait(0.3)
            t2 = t2 + 0.3
        until bag or t2 > 14
        if not bag then
            _setStatus("No Empty Bag!", Color3.fromRGB(255, 60, 90))
            isBusy = false
            return false
        end
        _setPhase("Ambil MS...")
        cookInteract(CFG.ITEM_EMPTY)
        local waitMS = 0
        local newS, newM, newL
        repeat
            task.wait(0.3)
            waitMS = waitMS + 0.3
            newS = countItem(CFG.ITEM_MS_SMALL) - snapS
            newM = countItem(CFG.ITEM_MS_MEDIUM) - snapM
            newL = countItem(CFG.ITEM_MS_LARGE) - snapL
        until (newS > 0 or newM > 0 or newL > 0) or waitMS > 10
        if newS > 0 then patStats.small = patStats.small + newS
        elseif newM > 0 then patStats.medium = patStats.medium + newM
        elseif newL > 0 then patStats.large = patStats.large + newL
        else patStats.small = patStats.small + 1 end
        _setPhase("Resume OK #"..totalMS())
        _setTimer("Done")
    end
    isBusy = false
    return true
end

local function triggerSafeEscape(newHP)
    if not safeMode then return end
    if safeModeActive then return end
    local now = tick()
    if now - _safeLastTrigger < SAFE_COOLDOWN then return end
    local dmg = math.floor(lastHealth - newHP)
    if dmg <= 0 then lastHealth = newHP; return end
    safeModeActive = true
    _safeLastTrigger = now
    lastHealth = newHP
    SM.wasFullyRunning = fullyRunning
    SM.savedPhase = detectCookPhase()
    SM.cookInProgress = isBusy
    _setStatus("⚠ HIT -"..dmg.."HP! KABUR!", Color3.fromRGB(255, 40, 40))
    if phaseValue then phaseValue.Text = "Safe Mode..." end
    setSafeLbl("⚠ HIT -"..dmg.."HP! KABUR KE SAFE SPOT...", Color3.fromRGB(255, 40, 40))
    tpToSafe()
    task.defer(tpToSafe)
    task.spawn(function()
        task.wait(0.15)
        setSafeLbl("DI SAFE SPOT – SCAN MUSUH...", Color3.fromRGB(255, 200, 0))
        local scanRadius = FULLY_ENEMY_RADIUS
        local waitStart = tick()
        local MAX_WAIT = 45
        local clearCount = 0
        while tick() - waitStart < MAX_WAIT do
            local myCh = LocalPlayer.Character
            local myHRP = myCh and myCh:FindFirstChild("HumanoidRootPart")
            local scanCenter = myHRP and myHRP.Position or SAFE_POS_VEC
            local enemyFound, enemyName, enemyDist = hasEnemyNear(scanCenter, scanRadius)
            if enemyFound then
                clearCount = 0
                setSafeLbl(string.format("⚠ MUSUH: %s (%.0fm) — TAHAN...", enemyName, enemyDist), Color3.fromRGB(255, 60, 60))
                if enemyDist < 12 then tpToSafe(); task.wait(0.5) end
            else
                clearCount = clearCount + 1
                setSafeLbl(string.format("Clear %d/3 — verifikasi aman...", clearCount), Color3.fromRGB(255, 220, 80))
                if clearCount >= 3 then break end
            end
            task.wait(1.2)
        end
        if fullySavedPos then
            setSafeLbl("AMAN – BALIK KE APARTEMEN...", Color3.fromRGB(100, 255, 180))
            fullyTeleport(fullySavedPos)
            task.wait(1.8)
            local myCh2 = LocalPlayer.Character
            local myHRP2 = myCh2 and myCh2:FindFirstChild("HumanoidRootPart")
            if myHRP2 and (myHRP2.Position - fullySavedPos).Magnitude > 8 then
                fullyTeleport(fullySavedPos)
                task.wait(1.2)
            end
        else
            setSafeLbl("AMAN – Posisi apart belum tersimpan.", Color3.fromRGB(255, 160, 40))
            task.wait(1)
        end
        local apartPos = fullySavedPos or SAFE_POS_VEC
        local ef2, en2, ed2 = hasEnemyNear(apartPos, scanRadius)
        if ef2 then
            setSafeLbl(string.format("MUSUH MASIH DI APART: %s (%.0fm) – BALIK SAFE", en2, ed2), Color3.fromRGB(255, 80, 80))
            tpToSafe()
            task.wait(2)
            local st2 = tick()
            while tick() - st2 < 20 do
                local ef3, en3, ed3 = hasEnemyNear(apartPos, scanRadius)
                if not ef3 then break end
                setSafeLbl(string.format("Tunggu: %s (%.0fm)...", en3, ed3), Color3.fromRGB(255, 80, 80))
                task.wait(1.5)
            end
            if fullySavedPos then fullyTeleport(fullySavedPos); task.wait(1.5) end
        end
        local char3 = LocalPlayer.Character
        local hum3 = char3 and char3:FindFirstChildOfClass("Humanoid")
        if hum3 then lastHealth = hum3.Health end
        local phase, hasW, hasS, hasG = detectCookPhase()
        local phaseDesc = {
            fresh = "KOMPOR KOSONG",
            need_sugar = "BELUM MASUKKAN SUGAR",
            need_gelatin = "BELUM MASUKKAN GELATIN",
            need_bag = "TUNGGU SELESAI MASAK",
            cooking_progress = "LANJUT MASAK",
            unknown = "CEK BAHAN...",
        }
        setSafeLbl("RESUME: "..(phaseDesc[phase] or phase), Color3.fromRGB(82, 210, 150))
        if SM.wasFullyRunning and safeMode then
            if not isRunning then isRunning = true end
            if not fullyRunning then fullyRunning = true end
            task.spawn(function()
                task.wait(0.3)
                unequipAll()
                if phase == "need_sugar" and hasS then
                    setSafeLbl("Masukkan Sugar...", Color3.fromRGB(255, 220, 100))
                    _setStatus("Masukkan Sugar (resume)...", Color3.fromRGB(255, 220, 100))
                    _setPhase("Masukkan Sugar...")
                    cookInteract(CFG.ITEM_SUGAR)
                    task.wait(0.5)
                    phase = "need_gelatin"
                end
                if phase == "need_gelatin" and hasG then
                    setSafeLbl("Masukkan Gelatin...", Color3.fromRGB(255, 200, 50))
                    _setStatus("Masukkan Gelatin (resume)...", Color3.fromRGB(255, 200, 50))
                    _setPhase("Masukkan Gelatin...")
                    cookInteract(CFG.ITEM_GEL)
                    task.wait(0.5)
                end
                safeModeActive = false
                setSafeLbl("LANJUT MASAK...", Color3.fromRGB(0, 255, 136))
            end)
        else
            safeModeActive = false
            setSafeLbl("STANDBY", Color3.fromRGB(0, 255, 136))
        end
    end)
end

local safeConn = nil
local function hookSafeMode(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    lastHealth = hum.Health
    if safeConn then safeConn:Disconnect(); safeConn = nil end
    safeConn = hum.HealthChanged:Connect(triggerSafeEscape)
end

if LocalPlayer.Character then task.spawn(function() hookSafeMode(LocalPlayer.Character) end) end
LocalPlayer.CharacterAdded:Connect(function(char)
    safeModeActive = false
    _safeLastTrigger = 0
    SM.wasFullyRunning = false
    task.spawn(function() hookSafeMode(char) end)
end)

-- ================================================================
-- AUTO SELL LOOP
-- ================================================================
task.spawn(function()
    while true do
        task.wait(0.4)
        if not autoSell_UI or asSelling then continue end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not hrp or hum.Health <= 0 then continue end
        if countAllMS() == 0 then
            if sellItemLbl_ref then sellItemLbl_ref.Text = "-" end
            if sellStatusLbl_ref then
                sellStatusLbl_ref.Text = "MENUNGGU"
                sellStatusLbl_ref.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
            continue
        end
        asSelling = true
        if sellStatusLbl_ref then
            sellStatusLbl_ref.Text = "MENJUAL..."
            sellStatusLbl_ref.TextColor3 = Color3.fromRGB(0, 255, 136)
        end
        doAutoSell(function(msg, col)
            if sellStatusLbl_ref then
                sellStatusLbl_ref.Text = msg
                sellStatusLbl_ref.TextColor3 = col or Color3.fromRGB(0, 255, 136)
            end
            if sellItemLbl_ref then sellItemLbl_ref.Text = msg end
        end)
        asSelling = false
    end
end)

-- ================================================================
-- NOTIFICATION
-- ================================================================
Library:Notification({
    Name = "MAJESTY STORE",
    Description = "Kiwisense Theme Loaded Successfully!",
    Duration = 5,
    Icon = "116339777575852",
    IconColor = Color3.fromRGB(0, 255, 136)
})

print("[MAJESTY STORE] Kiwisense Theme v8.7.0 Loaded!")

