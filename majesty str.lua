-- ========== MAJESTY STORE v8.7.0 ==========
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
            -- Cek parent langsung (BasePart) ATAU parent dari parent (NPC model)
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
                -- fallback: gunakan WorldPosition dari AncestorModel
                local anchorPart = part:FindFirstChildWhichIsA("BasePart", true)
                if anchorPart and (root.Position - anchorPart.Position).Magnitude <= (radius or 8) then
                    pcall(function() fireproximityprompt(obj) end)
                end
            end
        end
    end
end

-- Interact kompor: versi PatstoreMS (simple & stable)
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
        -- PAUSE saat safe mode aktif (kabur)
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
-- AUTO SELL ENGINE (v5 — improved detection, retry, validation)
-- ================================================================

-- Validasi: apakah player sudah cukup dekat NPC penjual
local function isNearNPC(radius)
    local ch  = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return (hrp.Position - NPC_MS_POS).Magnitude <= (radius or CFG.SELL_RADIUS + 5)
end

-- Tunggu hingga karakter stabil setelah teleport (tidak jatuh / bergerak cepat)
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
        if delta < 0.5 then return end   -- dianggap stabil
    until tick() >= deadline
end

-- Equip dengan retry hingga berhasil atau timeout
local function equipToolWithRetry(name, maxRetry)
    for i = 1, (maxRetry or 5) do
        local ok = equipTool(name)
        if ok then
            -- Pastikan tool benar-benar ada di tangan karakter
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

-- Jual satu item: equip → hold E sampai selesai (1x interact untuk 1x item).
-- Alur: equip → snapshot inv → hold E (tahan penuh) → tunggu inv berkurang → selesai.
-- Tidak ada loop spamming E — 1 hold per 1 item supaya tidak tabrakan.
local SELL_HOLD_DURATION = 1.8   -- durasi hold E (detik) — sesuaikan jika NPC butuh lebih lama
local SELL_HOLD_RETRIES  = 5     -- max percobaan hold E jika item belum terjual

local function trySellOne(msName, setStatus2)
    -- Snapshot inventory sebelum aksi
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
    -- Tunggu server kenali item di tangan
    task.wait(0.5)

    local sold = false

    for attempt = 1, SELL_HOLD_RETRIES do
        setStatus2(
            "Jual: "..msName.." — Hold E ("..attempt.."/"..SELL_HOLD_RETRIES..")...",
            Color3.fromRGB(50,210,110)
        )

        -- ── STEP 1: fireproximityprompt dulu untuk inisiasi prompt NPC ──
        firePromptNearby(CFG.SELL_RADIUS + 5)
        task.wait(0.1)

        -- ── STEP 2: Hold E secara penuh sampai selesai (tidak di-release sebelum waktunya) ──
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        end)

        -- Tahan E sambil cek inventory tiap 0.1 detik
        local holdElapsed = 0
        while holdElapsed < SELL_HOLD_DURATION do
            task.wait(0.1)
            holdElapsed += 0.1

            local diff = (bS - countItem(CFG.ITEM_MS_SMALL))
                       + (bM - countItem(CFG.ITEM_MS_MEDIUM))
                       + (bL - countItem(CFG.ITEM_MS_LARGE))
            if diff > 0 then
                -- Item terjual — lepas E langsung
                pcall(function()
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                totalSold += diff
                sold = true
                break
            end
        end

        -- Pastikan E selalu dilepas setelah hold selesai
        pcall(function()
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)

        if sold then break end

        -- ── STEP 3: Jika belum terjual, cek sekali lagi setelah jeda singkat ──
        task.wait(0.3)
        local diff2 = (bS - countItem(CFG.ITEM_MS_SMALL))
                    + (bM - countItem(CFG.ITEM_MS_MEDIUM))
                    + (bL - countItem(CFG.ITEM_MS_LARGE))
        if diff2 > 0 then
            totalSold += diff2
            sold = true
            break
        end

        -- Belum terjual — coba lagi setelah jeda pendek
        setStatus2(
            "Belum terjual, retry ("..attempt.."/"..SELL_HOLD_RETRIES..")...",
            Color3.fromRGB(255,155,35)
        )
        task.wait(0.4)
    end

    unequipAll()
    task.wait(0.3)
    return sold
end

local function doAutoSell(setStatus2)
    -- ── VALIDASI: cek inventory ada MS sebelum mulai ──
    local msTotal = countAllMS()
    if msTotal == 0 then
        setStatus2("Tidak ada MS di inventory", Color3.fromRGB(160,160,180))
        task.wait(0.8)
        return
    end

    setStatus2("Deteksi "..msTotal.." MS siap jual...", Color3.fromRGB(50,210,110))
    task.wait(0.4)

    -- ── VALIDASI: pastikan karakter sudah stabil setelah teleport ──
    setStatus2("Stabilisasi posisi...", Color3.fromRGB(100,180,255))
    waitCharacterStable(2.5)

    -- ── VALIDASI: pastikan sudah dekat NPC ──
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

        -- Jika terlalu jauh, re-teleport (maks 2x)
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

            -- Setelah 2x gagal berturut-turut: re-equip + re-teleport
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
-- AUTO BUY ENGINE (StorePurchase:FireServer)
-- ================================================================
local function doAutoBuy(setStatus2, overrideQty)
    -- Coba cari remote lagi jika load terlambat
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
        -- tunggu barang masuk
        local timeout = 0; local gained = 0
        repeat
            task.wait(0.2); timeout += 0.2
            gained = countItem(item.name) - before
        until gained >= qty or timeout > 6
        -- retry jika kurang
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
-- AUTO COOK ENGINE (doOneCook) — sistem PatstoreMS CLEAN
-- ================================================================
-- forward declare statusValue/phaseValue/timerValue (diisi oleh GUI block di bawah)
local statusValue, phaseValue, timerValue

local function _setStatus(msg, color)
    if statusValue then statusValue.Text = msg; statusValue.TextColor3 = color or Color3.fromRGB(0,255,136) end
end

-- Helper update UI
local function _setPhase(txt)
    if phaseValue then phaseValue.Text = txt end
end
local function _setTimer(txt)
    if timerValue then timerValue.Text = txt end
end

-- Countdown: tiap detik update phase+timer.
-- PAUSE otomatis saat safeModeActive = true (kabur ke safe spot).
-- Berhenti (return false) hanya jika isRunning dimatikan secara eksplisit.
local function countdown(secs, phaseTxt, color)
    for i = secs, 1, -1 do
        if not isRunning then return false end
        -- ── SAFE MODE PAUSE: tunggu sampai aman sebelum lanjut hitung mundur ──
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

    -- ── MASUKKAN WATER ──
    cookInteract(CFG.ITEM_WATER)

    local boilSecs
    for _ = 1, 30 do boilSecs = popTimer(); if boilSecs then break end; task.wait(0.1) end
    boilSecs = boilSecs or CFG.WATER_WAIT

    -- ── COUNTDOWN MENDIDIH ──
    if not countdown(boilSecs, "Mendidih...", Color3.fromRGB(80,150,255)) then
        isBusy = false; return false
    end

    -- ── TUNGGU & MASUKKAN SUGAR ──
    _setStatus("Tunggu Sugar...", Color3.fromRGB(255,220,100))
    _setPhase("Tunggu Sugar...")
    waitRPC("add_sugar", 10)
    if not isRunning then isBusy = false; return false end
    _setStatus("Masukkan Sugar...", Color3.fromRGB(255,220,100))
    _setPhase("Masukkan Sugar...")
    cookInteract(CFG.ITEM_SUGAR)
    task.wait(0.3)

    -- ── TUNGGU & MASUKKAN GELATIN ──
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

    -- ── COUNTDOWN MEMASAK ──
    if not countdown(cookSecs, "Memasak...", Color3.fromRGB(80,140,255)) then
        isBusy = false; return false
    end

    -- ── TUNGGU BAG ──
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

    -- ── AMBIL MARSHMALLOW ──
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
    -- PERBAIKAN: Selalu lurus (facing +Z), hapus orientasi miring
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

local function fullyTeleport(targetPos, isApart)
    local ch  = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum then task.wait(1); return end
    local seatPart = hum.SeatPart
    if seatPart then
        local vehicle = seatPart:FindFirstAncestorOfClass("Model")
        if vehicle then
            moveVehicle(vehicle, targetPos, isApart)
            task.wait(0.8)
            -- Paksa posisi player juga ikut
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
local fullySafeEscaping  = false  -- referenced by safe mode UI

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
        task.wait(1.5)

        -- MASAK
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

        -- JUAL
        -- Validasi: cek dulu ada MS sebelum repot teleport
        local msReady = countAllMS()
        if msReady == 0 then
            setFullyStatus("Tidak ada MS untuk dijual, skip jual...", Color3.fromRGB(255,155,35))
            task.wait(1)
        else
            setFullyStatus(cooked.." MS selesai! Siap jual ("..msReady.." item)...", Color3.fromRGB(52,210,110))
            task.wait(0.5)

            -- Unequip semua dulu sebelum teleport jual
            unequipAll()
            task.wait(0.3)

            setFullyStatus("Teleport ke NPC untuk jual...", Color3.fromRGB(52,210,110))
            fullyTeleport(NPC_MS_POS)
            -- Delay lebih panjang agar server sinkronisasi posisi setelah teleport
            task.wait(1.8)
            if not fullyRunning then break end

            -- Verifikasi posisi: cek apakah sudah benar-benar dekat NPC
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
-- GUI SETUP
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAJESTY STORE"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiOk = false
if not guiOk then pcall(function() screenGui.Parent = gethui(); guiOk = true end) end
if not guiOk then pcall(function() screenGui.Parent = game:GetService("CoreGui"); guiOk = true end) end
if not guiOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- TEMA GUI: Kiwisense Library (Preset Theme)
-- Sumber: Example_lua.txt + Library_lua.txt (github.com/sametexe001/sametlibs)
local C = {
    bg      = Color3.fromRGB(16, 18, 21),    -- [Background]
    topbar  = Color3.fromRGB(22, 25, 29),    -- [Inline]
    panel   = Color3.fromRGB(16, 18, 21),    -- [Background]
    card    = Color3.fromRGB(34, 39, 45),    -- [Element]
    card2   = Color3.fromRGB(22, 25, 29),    -- [Inline]
    accent  = Color3.fromRGB(196, 231, 255), -- [Accent]
    accent2 = Color3.fromRGB(180, 220, 255), -- [Accent variant]
    green   = Color3.fromRGB(52, 255, 164),  -- success green
    red     = Color3.fromRGB(255, 120, 120), -- error red
    yellow  = Color3.fromRGB(255, 215, 0),   -- warning yellow
    purple  = Color3.fromRGB(211, 211, 211), -- [Dark Gradient]
    text    = Color3.fromRGB(255, 255, 255), -- [Text]
    subtext = Color3.fromRGB(185, 185, 185), -- [Inactive Text]
    border  = Color3.fromRGB(32, 36, 42),    -- [Border]
    navbg   = Color3.fromRGB(22, 25, 29),    -- [Inline]
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
versionLabel.BackgroundTransparency = 1; versionLabel.Text = "v8.7.0"
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
UserInputService.InputBegan:Connect(function(input, gpe)
    if isBindingKey or isBindingMin or gpe then return end
    if minKeyType == "KeyCode" and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == minKeyCode then doHideShow() end
    if minKeyType == "MouseButton" and minKeyMBtn and input.UserInputType == minKeyMBtn then doHideShow() end
end)

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
local waterCount, gelatinCount, sugarCount, bagCount

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

    -- SAFE MODE
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
    makeLabel(smInfoCard,"Auto Fully otomatis aktifkan Safe Mode saat START",10,22,440,20,9,Color3.fromRGB(80,180,80))

    -- helper: sync tampilan tombol safe mode
    local function syncSafeModeBtn()
        if safeMode then
            safeTogBtn.Text = "SAFE MODE : ON"; safeTogBtn.TextColor3 = C.accent
            mkStroke(safeTogBtn,1,C.accent)
        else
            safeTogBtn.Text = "SAFE MODE : OFF"; safeTogBtn.TextColor3 = C.red
            mkStroke(safeTogBtn,1,C.border)
        end
    end
    -- expose sync untuk dipakai Auto Fully
    _G.__syncSafeModeBtn = syncSafeModeBtn

    safeTogBtn.MouseButton1Click:Connect(function()
        if fullyRunning then return end  -- tidak bisa matiin manual saat auto fully jalan
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

    -- AUTO SELL toggle
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

    -- BUY BAHAN (PatstoreMS StorePurchase)
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
        -- update buyQty dari nilai UI sebelum beli
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
-- ESP
-- ================================================================
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

-- ================================================================
-- PAGE: ESP
-- ================================================================
do
    sectionTitle(pageEsp,"HIDE / SHOW GUI",8)
    local hsCard = makeCard(pageEsp,34,34)
    makeLabel(hsCard,"Keybind Hide/Show",10,0,200,34,11,C.text)
    local hsKbBtn=Instance.new("TextButton"); hsKbBtn.Size=UDim2.new(0,80,0,22); hsKbBtn.Position=UDim2.new(1,-88,0.5,-11)
    hsKbBtn.BackgroundTransparency=1; hsKbBtn.Text="F1"; hsKbBtn.TextColor3=C.accent
    hsKbBtn.Font=Enum.Font.Gotham; hsKbBtn.TextSize=10; hsKbBtn.BorderSizePixel=0; hsKbBtn.Parent=hsCard
    minKeybindBtnRef=hsKbBtn
    hsKbBtn.MouseButton1Click:Connect(function()
        if isBindingMin then return end
        isBindingMin=true; hsKbBtn.Text="..."; hsKbBtn.TextColor3=C.subtext
    end)
    local hsInfoCard = makeCard(pageEsp,76,22)
    makeLabel(hsInfoCard,"Klik tombol di atas lalu tekan tombol keyboard/mouse",10,0,420,22,9,C.subtext)
    local hideTog=Instance.new("TextButton"); hideTog.Size=UDim2.new(1,-20,0,30); hideTog.Position=UDim2.new(0,10,0,106)
    hideTog.BackgroundColor3=C.card; hideTog.Text="Hide/Show GUI Sekarang"; hideTog.TextColor3=C.text
    hideTog.Font=Enum.Font.Gotham; hideTog.TextSize=11; hideTog.BorderSizePixel=0; hideTog.Parent=pageEsp
    mkCorner(hideTog,5); mkStroke(hideTog,1,C.border)
    hideTog.MouseButton1Click:Connect(doHideShow)

    sectionTitle(pageEsp,"ESP",144)
    local etb=Instance.new("TextButton"); etb.Size=UDim2.new(1,-20,0,34); etb.Position=UDim2.new(0,10,0,170)
    etb.BackgroundColor3=C.card; etb.Text="Player ESP : OFF"; etb.TextColor3=C.red
    etb.Font=Enum.Font.Gotham; etb.TextSize=13; etb.BorderSizePixel=0; etb.Parent=pageEsp
    mkCorner(etb,5); mkStroke(etb,1,C.border)
    local eir=makeCard(pageEsp,212,24)
    makeLabel(eir,"Box  |  Username  |  HP Bar  |  Item Held  |  Distance",10,0,400,24,10,C.subtext)
    etb.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
            etb.Text="Player ESP : ON"; etb.TextColor3=C.accent
            for _, plr in pairs(Players:GetPlayers()) do if plr ~= LocalPlayer then createESP(plr) end end
        else
            etb.Text="Player ESP : OFF"; etb.TextColor3=C.red
            for _, drawings in pairs(espCache) do for _, o in pairs(drawings) do pcall(function() o.Visible = false end) end end
        end
    end)
    sectionTitle(pageEsp,"WHITELIST",248)
    local wlScroll=Instance.new("ScrollingFrame"); wlScroll.Size=UDim2.new(1,-20,0,80); wlScroll.Position=UDim2.new(0,10,0,274)
    wlScroll.BackgroundColor3=C.card; wlScroll.BorderSizePixel=0; wlScroll.ScrollBarThickness=2; wlScroll.ScrollBarImageColor3=C.accent
    wlScroll.CanvasSize=UDim2.new(0,0,0,0); wlScroll.Parent=pageEsp; mkCorner(wlScroll,5); mkStroke(wlScroll,1,C.border)
    Instance.new("UIListLayout",wlScroll).Padding=UDim.new(0,2)
    local wp=Instance.new("UIPadding",wlScroll); wp.PaddingTop=UDim.new(0,3); wp.PaddingLeft=UDim.new(0,3); wp.PaddingRight=UDim.new(0,3)
    local wlEmpty=Instance.new("TextLabel"); wlEmpty.Size=UDim2.new(1,0,0,26); wlEmpty.BackgroundTransparency=1
    wlEmpty.Text="Belum ada player di whitelist"; wlEmpty.TextColor3=C.subtext; wlEmpty.Font=Enum.Font.Gotham; wlEmpty.TextSize=10; wlEmpty.Parent=wlScroll
    local function refreshWL()
        for _,ch in pairs(wlScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local count=0
        for name,_ in pairs(whitelist) do count=count+1
            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,24); row.BackgroundColor3=C.card2; row.BorderSizePixel=0; row.Parent=wlScroll; mkCorner(row,4)
            local nL=Instance.new("TextLabel"); nL.Size=UDim2.new(1,-70,1,0); nL.Position=UDim2.new(0,8,0,0); nL.BackgroundTransparency=1; nL.Text=name; nL.TextColor3=C.accent2; nL.Font=Enum.Font.Gotham; nL.TextSize=11; nL.TextXAlignment=Enum.TextXAlignment.Left; nL.Parent=row
            local rb=Instance.new("TextButton"); rb.Size=UDim2.new(0,56,0,18); rb.Position=UDim2.new(1,-60,0.5,-9); rb.BackgroundColor3=Color3.fromRGB(100,15,15); rb.Text="Remove"; rb.TextColor3=Color3.fromRGB(255,255,255); rb.Font=Enum.Font.Gotham; rb.TextSize=8; rb.BorderSizePixel=0; rb.Parent=row; mkCorner(rb,4)
            local cn=name; rb.MouseButton1Click:Connect(function() whitelist[cn]=nil; refreshWL() end)
        end
        wlEmpty.Visible=(count==0); wlScroll.CanvasSize=UDim2.new(0,0,0,count*26+6)
    end
    refreshWL()
    local svrScroll=Instance.new("ScrollingFrame"); svrScroll.Size=UDim2.new(1,-20,0,100); svrScroll.Position=UDim2.new(0,10,0,364)
    svrScroll.BackgroundColor3=C.card; svrScroll.BorderSizePixel=0; svrScroll.ScrollBarThickness=2; svrScroll.ScrollBarImageColor3=C.accent
    svrScroll.CanvasSize=UDim2.new(0,0,0,0); svrScroll.Parent=pageEsp; mkCorner(svrScroll,5); mkStroke(svrScroll,1,C.border)
    Instance.new("UIListLayout",svrScroll).Padding=UDim.new(0,2)
    local sp2=Instance.new("UIPadding",svrScroll); sp2.PaddingTop=UDim.new(0,3); sp2.PaddingLeft=UDim.new(0,3); sp2.PaddingRight=UDim.new(0,3)
    local function refreshSvr()
        for _,ch in pairs(svrScroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local count=0
        for _,plr in pairs(Players:GetPlayers()) do
            if plr~=LocalPlayer then count=count+1
                local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,26); row.BackgroundColor3=C.card2; row.BorderSizePixel=0; row.Parent=svrScroll; mkCorner(row,4)
                local pL=Instance.new("TextLabel"); pL.Size=UDim2.new(1,-84,1,0); pL.Position=UDim2.new(0,8,0,0); pL.BackgroundTransparency=1; pL.Text=plr.Name; pL.TextColor3=whitelist[plr.Name] and C.accent2 or C.text; pL.Font=Enum.Font.Gotham; pL.TextSize=11; pL.TextXAlignment=Enum.TextXAlignment.Left; pL.Parent=row
                local ab=Instance.new("TextButton"); ab.Size=UDim2.new(0,66,0,18); ab.Position=UDim2.new(1,-70,0.5,-9); ab.BorderSizePixel=0; ab.Font=Enum.Font.Gotham; ab.TextSize=9; ab.Parent=row; mkCorner(ab,4)
                local function sync() if whitelist[plr.Name] then ab.Text="Listed";ab.BackgroundColor3=Color3.fromRGB(10,50,20);ab.TextColor3=C.accent else ab.Text="Whitelist";ab.BackgroundColor3=Color3.fromRGB(10,30,70);ab.TextColor3=C.accent2 end end
                sync(); ab.MouseButton1Click:Connect(function() whitelist[plr.Name]=whitelist[plr.Name]~=true and true or nil; sync(); pL.TextColor3=whitelist[plr.Name] and C.accent2 or C.text; refreshWL() end)
            end
        end
        svrScroll.CanvasSize=UDim2.new(0,0,0,count*28+6)
    end
    refreshSvr()
    Players.PlayerAdded:Connect(function() refreshSvr() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshSvr() end)
    local rfBtn=Instance.new("TextButton"); rfBtn.Size=UDim2.new(0.5,-14,0,30); rfBtn.Position=UDim2.new(0,10,0,472); rfBtn.BackgroundTransparency=1; rfBtn.Text="Refresh"; rfBtn.TextColor3=C.subtext; rfBtn.Font=Enum.Font.Gotham; rfBtn.TextSize=11; rfBtn.BorderSizePixel=0; rfBtn.Parent=pageEsp; rfBtn.MouseButton1Click:Connect(refreshSvr)
    local clBtn=Instance.new("TextButton"); clBtn.Size=UDim2.new(0.5,-14,0,30); clBtn.Position=UDim2.new(0.5,4,0,472); clBtn.BackgroundTransparency=1; clBtn.Text="Clear All"; clBtn.TextColor3=C.subtext; clBtn.Font=Enum.Font.Gotham; clBtn.TextSize=11; clBtn.BorderSizePixel=0; clBtn.Parent=pageEsp
    clBtn.MouseButton1Click:Connect(function() whitelist={}; refreshWL(); refreshSvr() end)
    sectionTitle(pageEsp,"VEHICLE FLY",514)
    local vftb=Instance.new("TextButton"); vftb.Size=UDim2.new(1,-20,0,34); vftb.Position=UDim2.new(0,10,0,540)
    vftb.BackgroundColor3=C.card; vftb.Text="Vehicle Fly : OFF"; vftb.TextColor3=C.red
    vftb.Font=Enum.Font.Gotham; vftb.TextSize=13; vftb.BorderSizePixel=0; vftb.Parent=pageEsp; mkCorner(vftb,5); mkStroke(vftb,1,C.border)
    local vfsc=makeCard(pageEsp,582,34); makeLabel(vfsc,"STATUS",12,0,80,34,10,C.subtext)
    local vfsl=makeLabel(vfsc,"Tidak di kendaraan",90,0,260,34,11,C.subtext)
    local vfSpCard=makeCard(pageEsp,624,44)
    makeLabel(vfSpCard,"Kecepatan Terbang",12,2,200,20,11,C.text)
    local vfsvl=makeLabel(vfSpCard,tostring(vFlySpeed),0,2,-12,20,11,C.accent2,Enum.Font.Gotham,Enum.TextXAlignment.Right)
    vfsvl.Size=UDim2.new(1,-12,0,20)
    local vfTrk=Instance.new("Frame"); vfTrk.Size=UDim2.new(1,-20,0,3); vfTrk.Position=UDim2.new(0,10,0,32); vfTrk.BackgroundColor3=C.border; vfTrk.BorderSizePixel=0; vfTrk.Parent=vfSpCard; mkCorner(vfTrk,2)
    local vfFl=Instance.new("Frame"); local vfR0=(vFlySpeed-10)/290; vfFl.Size=UDim2.new(vfR0,0,1,0); vfFl.BackgroundColor3=C.accent; vfFl.BorderSizePixel=0; vfFl.Parent=vfTrk; mkCorner(vfFl,2)
    local vfKn=Instance.new("TextButton"); vfKn.Size=UDim2.new(0,10,0,10); vfKn.Position=UDim2.new(vfR0,-5,0.5,-5); vfKn.BackgroundColor3=Color3.fromRGB(255,255,255); vfKn.Text=""; vfKn.BorderSizePixel=0; vfKn.Parent=vfTrk; mkCorner(vfKn,5)
    local vfDrg=false; vfKn.MouseButton1Down:Connect(function() vfDrg=true end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then vfDrg=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if vfDrg and i.UserInputType==Enum.UserInputType.MouseMovement then
            local ap=vfTrk.AbsolutePosition; local as=vfTrk.AbsoluteSize
            local r=math.clamp((i.Position.X-ap.X)/as.X,0,1)
            vFlySpeed=math.floor(10+r*290); vfFl.Size=UDim2.new(r,0,1,0); vfKn.Position=UDim2.new(r,-5,0.5,-5); vfsvl.Text=tostring(vFlySpeed)
        end
    end)
    local vfic=makeCard(pageEsp,676,40); makeLabel(vfic,"E = Naik  |  Q = Turun  |  WASD = Steer",10,4,380,16,10,C.subtext)
    makeLabel(vfic,"Steer otomatis mengikuti arah kamera",10,20,340,16,10,Color3.fromRGB(80,180,80))
    UserInputService.InputBegan:Connect(function(input,gpe) if not vFlyEnabled or gpe then return end; if input.KeyCode==Enum.KeyCode.E then vFlyUp=true end; if input.KeyCode==Enum.KeyCode.Q then vFlyDown=true end end)
    UserInputService.InputEnded:Connect(function(input) if input.KeyCode==Enum.KeyCode.E then vFlyUp=false end; if input.KeyCode==Enum.KeyCode.Q then vFlyDown=false end end)
    local function startVFly()
        if vFlyConn then vFlyConn:Disconnect(); vFlyConn=nil end
        vFlyConn=RunService.RenderStepped:Connect(function(dt)
            local char=LocalPlayer.Character; if not char then return end
            local hum=char:FindFirstChildOfClass("Humanoid"); local seat=hum and hum.SeatPart
            if not seat then vfsl.Text="Tidak di kendaraan";vfsl.TextColor3=C.subtext;return end
            local model=seat:FindFirstAncestorOfClass("Model") or seat; local root=model.PrimaryPart or seat
            vfsl.Text="Terbang aktif";vfsl.TextColor3=C.accent
            local camCF=Camera.CFrame
            local fwd=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z); if fwd.Magnitude>0.01 then fwd=fwd.Unit else fwd=Vector3.new(0,0,-1) end
            local rgt=Vector3.new(camCF.RightVector.X,0,camCF.RightVector.Z); if rgt.Magnitude>0.01 then rgt=rgt.Unit else rgt=Vector3.new(1,0,0) end
            local mv=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+fwd end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-fwd end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-rgt end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+rgt end
            if vFlyUp then mv=mv+Vector3.new(0,1,0) end; if vFlyDown then mv=mv-Vector3.new(0,1,0) end
            pcall(function() for _,p in pairs(model:GetDescendants()) do if p:IsA("BasePart") then p.AssemblyLinearVelocity=Vector3.zero;p.AssemblyAngularVelocity=Vector3.zero end end end)
            if mv.Magnitude>0 then mv=mv.Unit; local np=root.Position+mv*vFlySpeed*dt
                local ld=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z); if ld.Magnitude>0.01 then ld=ld.Unit else ld=fwd end
                pcall(function() local cp=model:GetPivot(); local tcf=CFrame.new(np,np+ld); local off=cp:ToObjectSpace(root.CFrame); model:PivotTo(tcf*off:Inverse()) end)
            end
        end)
    end
    local function stopVFly() if vFlyConn then vFlyConn:Disconnect();vFlyConn=nil end; vFlyUp=false;vFlyDown=false; vfsl.Text="Tidak di kendaraan";vfsl.TextColor3=C.subtext end
    vftb.MouseButton1Click:Connect(function() vFlyEnabled=not vFlyEnabled; if vFlyEnabled then vftb.Text="Vehicle Fly : ON";vftb.TextColor3=C.accent;startVFly() else vftb.Text="Vehicle Fly : OFF";vftb.TextColor3=C.red;stopVFly() end end)
    pageEsp.CanvasSize=UDim2.new(0,0,0,760)
end

-- ================================================================
-- PAGE: TELEPORT
-- ================================================================
do
    local stGrid=Instance.new("Frame"); stGrid.Size=UDim2.new(1,-20,0,44); stGrid.Position=UDim2.new(0,10,0,8)
    stGrid.BackgroundTransparency=1; stGrid.BorderSizePixel=0; stGrid.Parent=pageTP
    local stLay=Instance.new("UIListLayout",stGrid); stLay.FillDirection=Enum.FillDirection.Horizontal; stLay.Padding=UDim.new(0,5)
    local function makeStatCell(parent,lTxt,vTxt,vColor)
        local cell=Instance.new("Frame"); cell.Size=UDim2.new(0.5,-3,1,0); cell.BackgroundColor3=C.card; cell.BorderSizePixel=0; cell.Parent=parent; mkCorner(cell,5); mkStroke(cell,1,C.border)
        local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,-8,0,14); lb.Position=UDim2.new(0,8,0,6); lb.BackgroundTransparency=1; lb.Text=lTxt; lb.TextColor3=C.subtext; lb.Font=Enum.Font.GothamBold; lb.TextSize=9; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=cell
        local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(1,-8,0,20); vl.Position=UDim2.new(0,8,0,20); vl.BackgroundTransparency=1; vl.Text=vTxt; vl.TextColor3=vColor or C.text; vl.Font=Enum.Font.GothamBold; vl.TextSize=12; vl.TextXAlignment=Enum.TextXAlignment.Left; vl.Parent=cell
        return vl
    end
    tpStatusValue = makeStatCell(stGrid,"STATUS","STANDBY",C.yellow)
    tpLoopValue   = makeStatCell(stGrid,"MODE","ONCE",C.accent)
    local infoCard=makeCard(pageTP,60,28)
    makeLabel(infoCard,"Kill - Respawn - TP otomatis ke tujuan",10,0,420,28,10,C.subtext)
    local tpDestination = nil; local tpPending = false
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
            tpStatusValue.Text="ARRIVED"; tpStatusValue.TextColor3=C.accent
            task.wait(2); tpStatusValue.Text="STANDBY"; tpStatusValue.TextColor3=C.yellow
        end)
    end
    if LocalPlayer.Character then task.spawn(function() onCharacterAdded(LocalPlayer.Character) end) end
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    local function tpTo(x, y, z)
        task.spawn(function()
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            tpDestination = {x=x, y=y, z=z}; tpPending = true
            tpStatusValue.Text="KILL-RESPAWN-TP"; tpStatusValue.TextColor3=C.yellow
            if char and hum and hum.Health > 0 then hum.Health = 0 end
        end)
    end
    sectionTitle(pageTP,"PILIH LOKASI",96)
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
    for i, loc in ipairs(tpLocs) do
        local locBtn=Instance.new("TextButton")
        locBtn.Size=UDim2.new(1,-20,0,36); locBtn.Position=UDim2.new(0,10,0,120+(i-1)*44)
        locBtn.BackgroundColor3=C.card; locBtn.Text=loc.name; locBtn.TextColor3=C.text
        locBtn.Font=Enum.Font.GothamBold; locBtn.TextSize=12; locBtn.TextXAlignment=Enum.TextXAlignment.Left
        locBtn.BorderSizePixel=0; locBtn.Parent=pageTP; mkCorner(locBtn,5); mkStroke(locBtn,1,C.border)
        local pad=Instance.new("UIPadding",locBtn); pad.PaddingLeft=UDim.new(0,12)
        locBtn.MouseEnter:Connect(function() locBtn.BackgroundColor3=Color3.fromRGB(20,30,45) end)
        locBtn.MouseLeave:Connect(function() locBtn.BackgroundColor3=C.card end)
        local ci=i; locBtn.MouseButton1Click:Connect(function() local l=tpLocs[ci]; tpTo(l.x,l.y,l.z) end)
    end
    local loopBase = 120 + #tpLocs*44 + 8
    sectionTitle(pageTP,"AUTO LOOP TELEPORT",loopBase)
    local loopTog=Instance.new("TextButton"); loopTog.Size=UDim2.new(1,-20,0,34); loopTog.Position=UDim2.new(0,10,0,loopBase+26)
    loopTog.BackgroundColor3=C.card; loopTog.Text="Auto Loop : OFF"; loopTog.TextColor3=C.red
    loopTog.Font=Enum.Font.GothamBold; loopTog.TextSize=13; loopTog.BorderSizePixel=0; loopTog.Parent=pageTP; mkCorner(loopTog,5); mkStroke(loopTog,1,C.border)
    loopTog.MouseButton1Click:Connect(function()
        autoTP_Running=not autoTP_Running
        if autoTP_Running then
            loopTog.Text="Auto Loop : ON";loopTog.TextColor3=C.accent;tpLoopValue.Text="LOOPING";tpLoopValue.TextColor3=C.accent
            autoTP_Thread=task.spawn(function()
                while autoTP_Running do
                    tpTo(tpLocs[2].x, tpLocs[2].y, tpLocs[2].z)
                    tpStatusValue.Text="LOOPING...";tpStatusValue.TextColor3=C.yellow
                    for i=30,1,-1 do if not autoTP_Running then break end; tpLoopValue.Text="Next: "..i.."s"; task.wait(1) end
                end
                tpLoopValue.Text="ONCE";tpLoopValue.TextColor3=C.accent
            end)
        else
            autoTP_Running=false; loopTog.Text="Auto Loop : OFF";loopTog.TextColor3=C.red
            tpLoopValue.Text="ONCE";tpLoopValue.TextColor3=C.accent
            tpStatusValue.Text="STANDBY";tpStatusValue.TextColor3=C.yellow
        end
    end)
    local plrBase = loopBase + 68
    sectionTitle(pageTP,"TELEPORT KE PLAYER",plrBase)
    local plrList=Instance.new("ScrollingFrame"); plrList.Size=UDim2.new(1,-20,0,90); plrList.Position=UDim2.new(0,10,0,plrBase+26)
    plrList.BackgroundColor3=C.card; plrList.BorderSizePixel=0; plrList.ScrollBarThickness=3; plrList.ScrollBarImageColor3=C.accent
    plrList.CanvasSize=UDim2.new(0,0,0,0); plrList.Parent=pageTP; mkCorner(plrList,5); mkStroke(plrList,1,C.border)
    Instance.new("UIListLayout",plrList).Padding=UDim.new(0,4)
    local function refreshPlrList()
        for _,ch in pairs(plrList:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        local count=0
        for _,plr in pairs(Players:GetPlayers()) do
            if plr~=LocalPlayer then count=count+1
                local pb=Instance.new("TextButton"); pb.Size=UDim2.new(1,-8,0,26); pb.BackgroundColor3=C.card2; pb.Text=plr.Name; pb.TextColor3=C.text; pb.Font=Enum.Font.GothamBold; pb.TextSize=11; pb.TextXAlignment=Enum.TextXAlignment.Left; pb.BorderSizePixel=0; pb.Parent=plrList; mkCorner(pb,4)
                local pp=Instance.new("UIPadding",pb); pp.PaddingLeft=UDim.new(0,8)
                pb.MouseButton1Click:Connect(function()
                    local tgt=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"); if not tgt then return end
                    tpDestination={x=tgt.Position.X+2, y=tgt.Position.Y, z=tgt.Position.Z}; tpPending=true
                    tpStatusValue.Text="TP: "..plr.Name;tpStatusValue.TextColor3=C.yellow
                    local c2=LocalPlayer.Character; local h2=c2 and c2:FindFirstChildOfClass("Humanoid")
                    if c2 and h2 and h2.Health>0 then h2.Health=0 end
                end)
            end
        end
        plrList.CanvasSize=UDim2.new(0,0,0,count*30)
    end
    local rfPlrBtn=Instance.new("TextButton"); rfPlrBtn.Size=UDim2.new(1,-20,0,32); rfPlrBtn.Position=UDim2.new(0,10,0,plrBase+124)
    rfPlrBtn.BackgroundColor3=C.card; rfPlrBtn.Text="Refresh Daftar Player"; rfPlrBtn.TextColor3=C.text; rfPlrBtn.Font=Enum.Font.GothamBold; rfPlrBtn.TextSize=11; rfPlrBtn.BorderSizePixel=0; rfPlrBtn.Parent=pageTP; mkCorner(rfPlrBtn,5); mkStroke(rfPlrBtn,1,C.border)
    rfPlrBtn.MouseButton1Click:Connect(function() rfPlrBtn.Text="Refreshing...";rfPlrBtn.TextColor3=C.yellow; refreshPlrList(); task.wait(0.3); rfPlrBtn.Text="Refresh Daftar Player";rfPlrBtn.TextColor3=C.text end)
    refreshPlrList()
    Players.PlayerAdded:Connect(function() task.wait(0.5);refreshPlrList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1);refreshPlrList() end)
    pageTP.CanvasSize=UDim2.new(0,0,0,plrBase+170)
end

-- ================================================================
-- PAGE: VEHICLE TP + AUTO FULLY
-- ================================================================
do
    sectionTitle(pageVehicleTP,"TELEPORT KENDARAAN",8)
    local infoCard=makeCard(pageVehicleTP,34,22)
    makeLabel(infoCard,"Tidak perlu mati  |  Bisa dipakai saat naik motor",10,0,430,22,9,Color3.fromRGB(0,220,100))
    local cachedSeat = nil
    local function updateSeatCache()
        local char = LocalPlayer.Character; if not char then cachedSeat=nil; return end
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Humanoid") then
                local seat = obj.SeatPart
                if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then cachedSeat=seat; return end
            end
        end
        cachedSeat = nil
    end
    local function hookCharacter(char)
        local hum = char:WaitForChild("Humanoid", 10); if not hum then return end
        hum:GetPropertyChangedSignal("SeatPart"):Connect(updateSeatCache); updateSeatCache()
    end
    if LocalPlayer.Character then task.spawn(hookCharacter, LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(char) task.spawn(hookCharacter, char) end)
    local vehStatusCard=makeCard(pageVehicleTP,64,30)
    local vehStatusLbl=makeLabel(vehStatusCard,"Kendaraan  -  Tidak ditemukan",10,0,400,30,11,C.red)
    task.spawn(function()
        while true do task.wait(1)
            if cachedSeat then
                local vehModel=cachedSeat:FindFirstAncestorWhichIsA("Model")
                vehStatusLbl.Text="Kendaraan  -  "..(vehModel and vehModel.Name or cachedSeat.Name)
                vehStatusLbl.TextColor3=Color3.fromRGB(0,220,100)
            else
                vehStatusLbl.Text="Kendaraan  -  Tidak ditemukan"
                vehStatusLbl.TextColor3=C.red
            end
        end
    end)
    -- PERBAIKAN: Selalu lurus, hapus parameter isApart
    local function tpVehicle(x, y, z)
        task.spawn(function()
            local char=LocalPlayer.Character; if not char then return end
            local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            -- Selalu lurus (facing +Z)
            local spawnPos = Vector3.new(x, y+2, z)
            local targetCF = CFrame.new(spawnPos, spawnPos + Vector3.new(0,0,1))
            if cachedSeat then
                local vehModel=cachedSeat:FindFirstAncestorWhichIsA("Model")
                if vehModel and vehModel.PrimaryPart then
                    local seatOffset=vehModel.PrimaryPart.CFrame:Inverse()*cachedSeat.CFrame
                    vehModel:SetPrimaryPartCFrame(targetCF*seatOffset:Inverse())
                elseif vehModel then
                    local delta=targetCF*cachedSeat.CFrame:Inverse()
                    for _,part in ipairs(vehModel:GetDescendants()) do
                        if part:IsA("BasePart") then part.CFrame=delta*part.CFrame end
                    end
                end
            else hrp.CFrame=targetCF end
        end)
    end
    sectionTitle(pageVehicleTP,"PILIH LOKASI",102)
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
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,-20,0,36); btn.Position=UDim2.new(0,10,0,128+(i-1)*44)
        btn.BackgroundColor3=C.card; btn.Text=loc.name; btn.TextColor3=C.text
        btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.TextXAlignment=Enum.TextXAlignment.Left
        btn.BorderSizePixel=0; btn.Parent=pageVehicleTP; mkCorner(btn,5); mkStroke(btn,1,C.border)
        local pad=Instance.new("UIPadding",btn); pad.PaddingLeft=UDim.new(0,12)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(20,30,45) end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3=C.card end)
        local ci=i; btn.MouseButton1Click:Connect(function()
            local l=vtpLocs[ci]
            tpVehicle(l.x,l.y,l.z)
        end)
    end
    local kompBase = 128 + #vtpLocs*44 + 8
    sectionTitle(pageVehicleTP,"KOMPOR APARTMENT",kompBase)
    local kompors = {
        {name="Kompor Apart 1", x=1141.8009033203125, y=11.041934967041016, z=450.3515319824219},
        {name="Kompor Apart 2", x=1142.488525390625, y=11.0384630731506348, z=421.6380920410156},
        {name="Kompor Apart 3", x=984.08892822265620, y=11.029658317565918, z=248.8081359863281},
        {name="Kompor Apart 4", x=984.09442138671880, y=11.064784049987793, z=220.2919158935547},
        {name="Kompor Apart 5", x=925.53119628906250, y=11.016752243041992, z=39.36603775024414},
        {name="Kompor Apart 6", x=896.86053466796880, y=11.042763710021973, z=38.65096664428711},
    }
    for i, k in ipairs(kompors) do
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,-20,0,36); btn.Position=UDim2.new(0,10,0,kompBase+26+(i-1)*44)
        btn.BackgroundColor3=C.card; btn.Text=k.name; btn.TextColor3=C.text
        btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.TextXAlignment=Enum.TextXAlignment.Left
        btn.BorderSizePixel=0; btn.Parent=pageVehicleTP; mkCorner(btn,5); mkStroke(btn,1,C.border)
        local pad=Instance.new("UIPadding",btn); pad.PaddingLeft=UDim.new(0,12)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(20,30,45) end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3=C.card end)
        local ci=i; btn.MouseButton1Click:Connect(function() local kk=kompors[ci]; tpVehicle(kk.x,kk.y,kk.z) end)
    end

    pageVehicleTP.CanvasSize=UDim2.new(0,0,0,kompBase+26+#kompors*44+10)
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

    -- Daftar Apart (koordinat sudah digeser ke samping)
    local afApartList = {
        {name="Apart 1", x=1141.8009033203125, y=11.041934967041016, z=450.3515319824219},
        {name="Apart 2", x=1142.488525390625, y=11.0384630731506348, z=421.6380920410156},
        {name="Apart 3", x=984.08892822265620, y=11.029658317565918, z=248.8081359863281},
        {name="Apart 4", x=984.09442138671880, y=11.064784049987793, z=220.2919158935547},
        {name="Apart 5", x=925.53119628906250, y=11.016752243041992, z=39.36603775024414},
        {name="Apart 6", x=896.86053466796880, y=11.042763710021973, z=38.65096664428711},
    }
    local afSelectedApart = 1
    -- Set default koordinat langsung ke Apart 1
    do
        local def = afApartList[1]
        fullySavedPos = Vector3.new(def.x, def.y, def.z)
    end

    -- Pilih Apart (dropdown row)
    local afApartCard = makeCard(pageAutoFully,90,34)
    makeLabel(afApartCard,"Apart Tujuan",10,0,120,34,10,C.subtext)
    fullyCoordLbl_af = makeLabel(afApartCard,afApartList[1].name.."  ✓ Tersimpan",135,0,240,34,10,C.accent)

    -- Tombol kiri kanan untuk pilih Apart
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

    -- Target stepper
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

    -- Status
    local afStatusCard = makeCard(pageAutoFully,184,30)
    fullyStatusLbl_af  = makeLabel(afStatusCard,"Belum dimulai",10,0,400,30,10,C.subtext)

    -- Start / Stop
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
        -- Auto aktifkan Safe Mode
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
            -- Matikan Safe Mode otomatis setelah selesai/stop
            safeMode = false; safeModeActive = false
            if safeModeStatusLbl then safeModeStatusLbl.Text = "OFF"; safeModeStatusLbl.TextColor3 = C.red end
            if _G.__syncSafeModeBtn then _G.__syncSafeModeBtn() end
        end)
    end)
    afStopBtn.MouseButton1Click:Connect(function()
        fullyRunning = false; isRunning = false; AutoMS_Running = false
        -- Matikan Safe Mode saat stop manual
        safeMode = false; safeModeActive = false
        if safeModeStatusLbl then safeModeStatusLbl.Text = "OFF"; safeModeStatusLbl.TextColor3 = C.red end
        if _G.__syncSafeModeBtn then _G.__syncSafeModeBtn() end
        setFullyStatus_af("Dihentikan", C.yellow)
    end)

    -- Status Safe Mode di halaman Auto Fully
    local afSafeModeCard = makeCard(pageAutoFully,262,44)
    makeLabel(afSafeModeCard,"SAFE MODE",12,0,100,44,10,C.subtext)
    local afSafeLbl = makeLabel(afSafeModeCard,"Auto (ikut START/STOP)",115,0,290,44,11,C.subtext)
    -- Update label ini tiap detik
    task.spawn(function()
        while screenGui.Parent do
            if fullyRunning then
                if safeMode then
                    afSafeLbl.Text = "🟢 ON – Aktif"; afSafeLbl.TextColor3 = C.accent
                else
                    afSafeLbl.Text = "⚪ OFF"; afSafeLbl.TextColor3 = C.subtext
                end
            else
                afSafeLbl.Text = "Auto (ikut START/STOP)"; afSafeLbl.TextColor3 = C.subtext
            end
            task.wait(0.5)
        end
    end)

    -- Radius deteksi musuh stepper
    local afRadiusCard = makeCard(pageAutoFully,314,44)
    makeLabel(afRadiusCard,"Radius Deteksi Musuh",10,0,200,44,11,C.text)
    local afRadiusLbl = makeLabel(afRadiusCard,tostring(FULLY_ENEMY_RADIUS).." st",0,0,0,44,13,C.yellow,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    afRadiusLbl.Size=UDim2.new(0,54,1,0); afRadiusLbl.Position=UDim2.new(0.5,-27,0,0)
    local arMinW=makeCard(pageAutoFully,0,0); arMinW.Parent=afRadiusCard
    arMinW.Size=UDim2.new(0,30,0,28); arMinW.Position=UDim2.new(0.5,-27-36,0.5,-14); arMinW.BackgroundColor3=C.card2
    local arMinB=Instance.new("TextButton"); arMinB.Size=UDim2.new(1,0,1,0); arMinB.Text="-"; arMinB.TextSize=16; arMinB.Font=Enum.Font.GothamBold; arMinB.BackgroundTransparency=1; arMinB.TextColor3=C.red; arMinB.BorderSizePixel=0; arMinB.Parent=arMinW; mkCorner(arMinW,5)
    local arPlusW=makeCard(pageAutoFully,0,0); arPlusW.Parent=afRadiusCard
    arPlusW.Size=UDim2.new(0,30,0,28); arPlusW.Position=UDim2.new(0.5,27+6,0.5,-14); arPlusW.BackgroundColor3=C.card2
    local arPlusB=Instance.new("TextButton"); arPlusB.Size=UDim2.new(1,0,1,0); arPlusB.Text="+"; arPlusB.TextSize=16; arPlusB.Font=Enum.Font.GothamBold; arPlusB.BackgroundTransparency=1; arPlusB.TextColor3=C.accent; arPlusB.BorderSizePixel=0; arPlusB.Parent=arPlusW; mkCorner(arPlusW,5)
    arMinB.MouseButton1Click:Connect(function()
        FULLY_ENEMY_RADIUS = math.max(10, FULLY_ENEMY_RADIUS-5)
        afRadiusLbl.Text = tostring(FULLY_ENEMY_RADIUS).." st"
    end)
    arPlusB.MouseButton1Click:Connect(function()
        FULLY_ENEMY_RADIUS = math.min(200, FULLY_ENEMY_RADIUS+5)
        afRadiusLbl.Text = tostring(FULLY_ENEMY_RADIUS).." st"
    end)
    local afRadiusInfo = makeCard(pageAutoFully,366,22)
    makeLabel(afRadiusInfo,"Musuh dalam radius ini = kabur dulu sebelum masak",10,0,430,22,9,C.subtext)

    pageAutoFully.CanvasSize=UDim2.new(0,0,0,400)
end

-- ================================================================
-- PAGE: AIMBOT
-- ================================================================
do
    local function mkRow(parent,yPos,h) local f=Instance.new("Frame"); f.Size=UDim2.new(1,-16,0,h or 34); f.Position=UDim2.new(0,8,0,yPos); f.BackgroundColor3=C.card; f.BorderSizePixel=0; f.Parent=parent; mkCorner(f,5); mkStroke(f,1,C.border); return f end
    local function mkSep(parent,yPos,txt) local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-16,0,18); l.Position=UDim2.new(0,8,0,yPos); l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=C.subtext; l.Font=Enum.Font.Gotham; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent end
    local function mkToggle(parent,defaultOn,callback)
        local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,34,0,18); bg.Position=UDim2.new(1,-42,0.5,-9); bg.BackgroundColor3=defaultOn and C.accent or C.border; bg.BorderSizePixel=0; bg.Parent=parent; mkCorner(bg,9)
        local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,12,0,12); knob.Position=defaultOn and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6); knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.BorderSizePixel=0; knob.Parent=bg; mkCorner(knob,6)
        local state=defaultOn; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=bg
        btn.MouseButton1Click:Connect(function() state=not state; bg.BackgroundColor3=state and C.accent or C.border; knob.Position=state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6); if callback then callback(state) end end)
        return bg
    end
    local function mkPairBtn(parent,l1,l2,active,callback)
        local function makeB(txt,xOff,isA) local b=Instance.new("TextButton"); b.Size=UDim2.new(0,78,0,22); b.Position=UDim2.new(1,xOff,0.5,-11); b.BackgroundColor3=C.card2; b.Text=txt; b.TextColor3=isA and C.text or C.subtext; b.Font=Enum.Font.Gotham; b.TextSize=10; b.BorderSizePixel=0; b.Parent=parent; mkCorner(b,5); mkStroke(b,1,C.border); return b end
        local b1=makeB(l1,-162,active==1); local b2=makeB(l2,-78,active==2)
        b1.MouseButton1Click:Connect(function() b1.TextColor3=C.text;b2.TextColor3=C.subtext; if callback then callback(1) end end)
        b2.MouseButton1Click:Connect(function() b2.TextColor3=C.text;b1.TextColor3=C.subtext; if callback then callback(2) end end)
        return b1,b2
    end
    local function mkSlider(parent,yPos,label,minV,maxV,defV,suffix,callback)
        local row=mkRow(parent,yPos,44)
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.6,0,0,20); lbl.Position=UDim2.new(0,10,0,2); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.text; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
        local vlbl=Instance.new("TextLabel"); vlbl.Size=UDim2.new(0.4,-10,0,20); vlbl.Position=UDim2.new(0.6,0,0,2); vlbl.BackgroundTransparency=1; vlbl.Text=defV..suffix; vlbl.TextColor3=C.accent2; vlbl.Font=Enum.Font.Gotham; vlbl.TextSize=11; vlbl.TextXAlignment=Enum.TextXAlignment.Right; vlbl.Parent=row
        local track=Instance.new("Frame"); track.Size=UDim2.new(1,-20,0,3); track.Position=UDim2.new(0,10,0,32); track.BackgroundColor3=C.border; track.BorderSizePixel=0; track.Parent=row; mkCorner(track,2)
        local r0=(defV-minV)/(maxV-minV)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(r0,0,1,0); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; fill.Parent=track; mkCorner(fill,2)
        local knob=Instance.new("TextButton"); knob.Size=UDim2.new(0,10,0,10); knob.Position=UDim2.new(r0,-5,0.5,-5); knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.Text=""; knob.BorderSizePixel=0; knob.Parent=track; mkCorner(knob,5)
        local drg=false; knob.MouseButton1Down:Connect(function() drg=true end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drg=false end end)
        UserInputService.InputChanged:Connect(function(i)
            if drg and i.UserInputType==Enum.UserInputType.MouseMovement then
                local ap=track.AbsolutePosition; local as=track.AbsoluteSize
                local r=math.clamp((i.Position.X-ap.X)/as.X,0,1); local v=math.floor(minV+r*(maxV-minV))
                fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,-5,0.5,-5); vlbl.Text=v..suffix; if callback then callback(v) end
            end
        end)
    end
    local y=6
    mkSep(pageAimbot,y,"AIMBOT"); y=y+20
    local sRow=mkRow(pageAimbot,y,34)
    local sTxt=Instance.new("TextLabel"); sTxt.Size=UDim2.new(0.5,0,1,0); sTxt.Position=UDim2.new(0,10,0,0); sTxt.BackgroundTransparency=1; sTxt.Text="Enable Aimbot"; sTxt.TextColor3=C.text; sTxt.Font=Enum.Font.Gotham; sTxt.TextSize=11; sTxt.TextXAlignment=Enum.TextXAlignment.Left; sTxt.Parent=sRow
    aimbotStatusLbl=Instance.new("TextLabel"); aimbotStatusLbl.Size=UDim2.new(0,40,1,0); aimbotStatusLbl.Position=UDim2.new(1,-88,0,0); aimbotStatusLbl.BackgroundTransparency=1; aimbotStatusLbl.Text="OFF"; aimbotStatusLbl.TextColor3=C.red; aimbotStatusLbl.Font=Enum.Font.Gotham; aimbotStatusLbl.TextSize=11; aimbotStatusLbl.TextXAlignment=Enum.TextXAlignment.Right; aimbotStatusLbl.Parent=sRow
    mkToggle(sRow,false,function(s) aimbotEnabled=s; aimbotStatusLbl.Text=s and "ON" or "OFF"; aimbotStatusLbl.TextColor3=s and C.accent or C.red; if aimbotFovCircle then aimbotFovCircle.Visible=s end end); y=y+40
    mkSep(pageAimbot,y,"MODE"); y=y+20
    local mRow=mkRow(pageAimbot,y,34)
    local mLbl=Instance.new("TextLabel"); mLbl.Size=UDim2.new(0.55,0,1,0); mLbl.Position=UDim2.new(0,10,0,0); mLbl.BackgroundTransparency=1; mLbl.Text="Aim Mode"; mLbl.TextColor3=C.text; mLbl.Font=Enum.Font.Gotham; mLbl.TextSize=11; mLbl.TextXAlignment=Enum.TextXAlignment.Left; mLbl.Parent=mRow
    mkPairBtn(mRow,"Camera","FreeAim",1,function(w) aimbotMode=w==1 and "Camera" or "FreeAim" end); y=y+40
    mkSep(pageAimbot,y,"TARGET PART"); y=y+20
    local tParts={"Head","UpperTorso","Torso","HumanoidRootPart"}; local tIdx=1
    local tRow=mkRow(pageAimbot,y,30)
    local tLbl=Instance.new("TextLabel"); tLbl.Size=UDim2.new(0.42,0,1,0); tLbl.Position=UDim2.new(0,10,0,0); tLbl.BackgroundTransparency=1; tLbl.Text="Target Part"; tLbl.TextColor3=C.text; tLbl.Font=Enum.Font.Gotham; tLbl.TextSize=11; tLbl.TextXAlignment=Enum.TextXAlignment.Left; tLbl.Parent=tRow
    local tVlbl=Instance.new("TextLabel"); tVlbl.Size=UDim2.new(0.36,0,1,0); tVlbl.Position=UDim2.new(0.42,0,0,0); tVlbl.BackgroundTransparency=1; tVlbl.Text=tParts[tIdx]; tVlbl.TextColor3=C.accent2; tVlbl.Font=Enum.Font.Gotham; tVlbl.TextSize=10; tVlbl.TextXAlignment=Enum.TextXAlignment.Right; tVlbl.Parent=tRow
    local chevBtn=Instance.new("TextButton"); chevBtn.Size=UDim2.new(0,26,0,20); chevBtn.Position=UDim2.new(1,-32,0.5,-10); chevBtn.BackgroundColor3=C.card2; chevBtn.Text="v"; chevBtn.TextColor3=C.accent2; chevBtn.Font=Enum.Font.Gotham; chevBtn.TextSize=11; chevBtn.BorderSizePixel=0; chevBtn.Parent=tRow; mkCorner(chevBtn,4); mkStroke(chevBtn,1,C.border); y=y+36
    local optH=#tParts*28+4
    local dropCon=Instance.new("Frame"); dropCon.Size=UDim2.new(1,0,0,0); dropCon.Position=UDim2.new(0,0,0,y); dropCon.BackgroundTransparency=1; dropCon.BorderSizePixel=0; dropCon.ClipsDescendants=true; dropCon.Parent=pageAimbot
    local tOptBtns={}
    local function refreshTOpts() for li,btn in ipairs(tOptBtns) do btn.TextColor3=li==tIdx and C.text or C.subtext end; tVlbl.Text=tParts[tIdx] end
    for li,lbl in ipairs(tParts) do
        local ob=Instance.new("TextButton"); ob.Size=UDim2.new(1,-16,0,24); ob.Position=UDim2.new(0,8,0,(li-1)*28+2); ob.BackgroundColor3=C.card2; ob.TextColor3=C.subtext; ob.Font=Enum.Font.Gotham; ob.TextSize=10; ob.TextXAlignment=Enum.TextXAlignment.Left; ob.Text="    "..lbl; ob.BorderSizePixel=0; ob.Parent=dropCon; mkCorner(ob,4); mkStroke(ob,1,C.border); tOptBtns[li]=ob
        local cLi=li; ob.MouseButton1Click:Connect(function() tIdx=cLi; aimbotTarget=tParts[cLi]; refreshTOpts() end)
    end
    refreshTOpts()
    local dropOpen=false
    local function toggleDrop() dropOpen=not dropOpen; TweenService:Create(dropCon,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,dropOpen and optH or 0)}):Play(); chevBtn.Text=dropOpen and "^" or "v" end
    chevBtn.MouseButton1Click:Connect(toggleDrop)
    local rClick=Instance.new("TextButton"); rClick.Size=UDim2.new(1,-38,1,0); rClick.BackgroundTransparency=1; rClick.Text=""; rClick.BorderSizePixel=0; rClick.Parent=tRow; rClick.MouseButton1Click:Connect(toggleDrop); y=y+optH+6
    local prioRow=mkRow(pageAimbot,y,34)
    local pLbl=Instance.new("TextLabel"); pLbl.Size=UDim2.new(0.55,0,1,0); pLbl.Position=UDim2.new(0,10,0,0); pLbl.BackgroundTransparency=1; pLbl.Text="Lock Priority"; pLbl.TextColor3=C.text; pLbl.Font=Enum.Font.Gotham; pLbl.TextSize=11; pLbl.TextXAlignment=Enum.TextXAlignment.Left; pLbl.Parent=prioRow
    mkPairBtn(prioRow,"Crosshair","Distance",1,function(w) aimbotPriority=w==1 and "Crosshair" or "Distance" end); y=y+40
    mkSep(pageAimbot,y,"KEYBIND"); y=y+20
    local kbRow=mkRow(pageAimbot,y,34)
    local kbLbl=Instance.new("TextLabel"); kbLbl.Size=UDim2.new(0.55,0,1,0); kbLbl.Position=UDim2.new(0,10,0,0); kbLbl.BackgroundTransparency=1; kbLbl.Text="Hold Key"; kbLbl.TextColor3=C.text; kbLbl.Font=Enum.Font.Gotham; kbLbl.TextSize=11; kbLbl.TextXAlignment=Enum.TextXAlignment.Left; kbLbl.Parent=kbRow
    local kbBtn=Instance.new("TextButton"); kbBtn.Size=UDim2.new(0,80,0,22); kbBtn.Position=UDim2.new(1,-88,0.5,-11); kbBtn.BackgroundTransparency=1; kbBtn.Text="RMB"; kbBtn.TextColor3=C.text; kbBtn.Font=Enum.Font.Gotham; kbBtn.TextSize=10; kbBtn.BorderSizePixel=0; kbBtn.Parent=kbRow; keybindBtnRef=kbBtn
    kbBtn.MouseButton1Click:Connect(function() if isBindingKey then return end; isBindingKey=true; kbBtn.Text="..."; kbBtn.TextColor3=C.subtext end); y=y+40
    mkSep(pageAimbot,y,"MINIMIZE KEYBIND"); y=y+20
    local mkRow2=mkRow(pageAimbot,y,34)
    local mkLbl=Instance.new("TextLabel"); mkLbl.Size=UDim2.new(0.75,0,1,0); mkLbl.Position=UDim2.new(0,10,0,0); mkLbl.BackgroundTransparency=1; mkLbl.Text="Hide/Show GUI  (atur di tab GENERAL)"; mkLbl.TextColor3=C.subtext; mkLbl.Font=Enum.Font.Gotham; mkLbl.TextSize=10; mkLbl.TextXAlignment=Enum.TextXAlignment.Left; mkLbl.Parent=mkRow2
    local minKbBtn=Instance.new("TextButton"); minKbBtn.Size=UDim2.new(0,80,0,22); minKbBtn.Position=UDim2.new(1,-88,0.5,-11); minKbBtn.BackgroundTransparency=1; minKbBtn.Text="F1"; minKbBtn.TextColor3=C.accent; minKbBtn.Font=Enum.Font.Gotham; minKbBtn.TextSize=10; minKbBtn.BorderSizePixel=0; minKbBtn.Parent=mkRow2
    minKbBtn.MouseButton1Click:Connect(function() if isBindingMin then return end; isBindingMin=true; minKbBtn.Text="..."; minKbBtn.TextColor3=C.subtext end); y=y+40
    mkSep(pageAimbot,y,"SETTINGS"); y=y+20
    mkSlider(pageAimbot,y,"FOV Radius",20,400,aimbotFOV,"px",function(v) aimbotFOV=v; if aimbotFovCircle then aimbotFovCircle.Radius=v end end); y=y+50
    mkSlider(pageAimbot,y,"Smooth",1,20,aimbotSmooth,"",function(v) aimbotSmooth=v end); y=y+50
    mkSlider(pageAimbot,y,"Aimbot Max Distance",10,10000,aimbotMaxDist,"m",function(v) aimbotMaxDist=v end); y=y+50
    mkSlider(pageAimbot,y,"ESP Max Distance",10,10000,espMaxDist,"m",function(v) espMaxDist=v end); y=y+50
    mkSep(pageAimbot,y,"PREDICTION"); y=y+20
    local predRow=mkRow(pageAimbot,y,34)
    local predLbl=Instance.new("TextLabel"); predLbl.Size=UDim2.new(0.55,0,1,0); predLbl.Position=UDim2.new(0,10,0,0); predLbl.BackgroundTransparency=1; predLbl.Text="Enable Prediction"; predLbl.TextColor3=C.text; predLbl.Font=Enum.Font.Gotham; predLbl.TextSize=11; predLbl.TextXAlignment=Enum.TextXAlignment.Left; predLbl.Parent=predRow
    mkToggle(predRow,aimbotPrediction,function(s) aimbotPrediction=s end); y=y+40
    mkSlider(pageAimbot,y,"Prediction Strength",0,100,math.floor(predStrength*100),"%",function(v) predStrength=v/100 end); y=y+50
    pageAimbot.CanvasSize=UDim2.new(0,0,0,y+30)
    UserInputService.InputBegan:Connect(function(input,gpe)
        if isBindingKey then
            if input.UserInputType==Enum.UserInputType.MouseButton1 then return end; isBindingKey=false
            local kn=tostring(input.KeyCode):gsub("Enum%.KeyCode%.",""); local un=tostring(input.UserInputType):gsub("Enum%.UserInputType%.","")
            if un=="MouseButton2" then aimbotKeybindType="MouseButton";aimbotKeybind=Enum.UserInputType.MouseButton2;aimbotKeybindLabel="RMB"
            elseif un=="MouseButton3" then aimbotKeybindType="MouseButton";aimbotKeybind=Enum.UserInputType.MouseButton3;aimbotKeybindLabel="MMB"
            elseif un=="Keyboard" and kn~="Unknown" then aimbotKeybindType="KeyCode";aimbotKeybindCode=input.KeyCode;aimbotKeybindLabel=kn
            else isBindingKey=true; return end
            kbBtn.Text=aimbotKeybindLabel; kbBtn.TextColor3=C.text
        end
        if isBindingMin then
            if input.UserInputType==Enum.UserInputType.MouseButton1 then return end; isBindingMin=false
            local kn2=tostring(input.KeyCode):gsub("Enum%.KeyCode%.",""); local un2=tostring(input.UserInputType):gsub("Enum%.UserInputType%.","")
            if un2=="MouseButton2" then minKeyType="MouseButton";minKeyMBtn=Enum.UserInputType.MouseButton2;minKeyCode=nil
            elseif un2=="MouseButton3" then minKeyType="MouseButton";minKeyMBtn=Enum.UserInputType.MouseButton3;minKeyCode=nil
            elseif un2=="Keyboard" and kn2~="Unknown" then minKeyType="KeyCode";minKeyCode=input.KeyCode;minKeyMBtn=nil
            else isBindingMin=true; return end
            local newLabel=tostring(minKeyCode or minKeyMBtn):gsub("Enum%..*%.","")
            if minKeybindBtnRef then minKeybindBtnRef.Text=newLabel; minKeybindBtnRef.TextColor3=C.accent end
            minKbBtn.Text=newLabel; minKbBtn.TextColor3=C.accent
        end
    end)
end

-- ================================================================
-- PAGE: CREDITS
-- ================================================================
do
    sectionTitle(pageCredits,"CREDITS",8)
    local creditData={{role="Investor & Owner",name="Hiro",color=Color3.fromRGB(255,215,0),initials="HI"},{role="Developer",name="V7x & Reyvan",color=Color3.fromRGB(100,180,255),initials="V7"}}
    for i,cr in ipairs(creditData) do
        local card=makeCard(pageCredits,38+(i-1)*66,54)
        local avatar=Instance.new("Frame"); avatar.Size=UDim2.new(0,36,0,36); avatar.Position=UDim2.new(0,10,0.5,-18); avatar.BackgroundColor3=Color3.fromRGB(math.floor(cr.color.R*255*0.15),math.floor(cr.color.G*255*0.15),math.floor(cr.color.B*255*0.15)); avatar.BorderSizePixel=0; avatar.Parent=card; mkCorner(avatar,18); mkStroke(avatar,1,cr.color)
        local iLbl=Instance.new("TextLabel"); iLbl.Size=UDim2.new(1,0,1,0); iLbl.BackgroundTransparency=1; iLbl.Text=cr.initials; iLbl.TextColor3=cr.color; iLbl.Font=Enum.Font.Gotham; iLbl.TextSize=13; iLbl.Parent=avatar
        makeLabel(card,cr.role,56,8,280,16,10,C.subtext); makeLabel(card,cr.name,56,26,280,20,14,cr.color)
    end
    local fCard=makeCard(pageCredits,38+#creditData*66,38)
    local fLbl=Instance.new("TextLabel"); fLbl.Size=UDim2.new(1,-20,1,0); fLbl.Position=UDim2.new(0,10,0,0); fLbl.BackgroundTransparency=1; fLbl.RichText=true
    fLbl.Text='<font color="rgb(255,60,90)">majesty.gg</font>  -  <font color="rgb(100,120,140)">Thank you for using MAJESTY STORE</font>'
    fLbl.Font=Enum.Font.Gotham; fLbl.TextSize=11; fLbl.TextXAlignment=Enum.TextXAlignment.Center; fLbl.Parent=fCard
    local dCard=makeCard(pageCredits,38+#creditData*66+46,30)
    local dLbl=makeLabel(dCard,"discord.gg/VPeZbhCz8M",0,0,0,30,11,C.subtext,Enum.Font.Gotham,Enum.TextXAlignment.Center); dLbl.Size=UDim2.new(1,0,1,0)
    pageCredits.CanvasSize=UDim2.new(0,0,0,220)
end

-- ================================================================
-- BOTTOM NAV
-- ================================================================
local tabDefs={{label="Auto ms",page=pageAuto},{label="General",page=pageEsp},{label="Teleport",page=pageTP},{label="Vteleport",page=pageVehicleTP},{label="Auto fully",page=pageAutoFully},{label="Aimbot",page=pageAimbot},{label="Credits",page=pageCredits}}
local tabBtns={}
local bottomNav=Instance.new("Frame"); bottomNav.Size=UDim2.new(1,0,0,44); bottomNav.Position=UDim2.new(0,0,1,-44); bottomNav.BackgroundColor3=C.navbg; bottomNav.BorderSizePixel=0; bottomNav.Parent=mainFrame; mkStroke(bottomNav,1,C.border)
local navLine=Instance.new("Frame"); navLine.Size=UDim2.new(1,0,0,1); navLine.BackgroundColor3=C.border; navLine.BorderSizePixel=0; navLine.Parent=bottomNav
local function setTab(idx)
    for i,tb in ipairs(tabBtns) do local isA=(i==idx); tb.TextColor3=isA and C.accent or C.subtext; local ind=tb:FindFirstChild("indicator"); if ind then ind.Visible=isA end end
    for _,td in ipairs(tabDefs) do td.page.Visible=false end; tabDefs[idx].page.Visible=true
end
local navW=1/#tabDefs
for i,td in ipairs(tabDefs) do
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(navW,0,1,0); btn.Position=UDim2.new(navW*(i-1),0,0,0); btn.BackgroundTransparency=1; btn.Text=td.label; btn.TextColor3=C.subtext; btn.Font=Enum.Font.Gotham; btn.TextSize=10; btn.BorderSizePixel=0; btn.Parent=bottomNav
    local ind=Instance.new("Frame"); ind.Name="indicator"; ind.Size=UDim2.new(0.7,0,0,2); ind.Position=UDim2.new(0.15,0,0,0); ind.BackgroundColor3=C.accent; ind.BorderSizePixel=0; ind.Visible=false; ind.Parent=btn; mkCorner(ind,2)
    tabBtns[i]=btn; local ci=i; btn.MouseButton1Click:Connect(function() setTab(ci) end)
end
setTab(1)

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
    if not isRunning then
        isRunning = true
        _setStatus("STARTING", C.yellow)
        task.spawn(autoMSLoop)
    end
end)
stopBtn.MouseButton1Click:Connect(function()
    isRunning = false
    AutoMS_Running = false
    _setStatus("OFF", Color3.fromRGB(255,60,90))
    if phaseValue then phaseValue.Text="Water" end
    if timerValue then timerValue.Text="0s" end
end)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.PageUp then
        if isRunning then
            isRunning = false
            AutoMS_Running = false
            _setStatus("OFF", Color3.fromRGB(255,60,90))
            if phaseValue then phaseValue.Text="Water" end
            if timerValue then timerValue.Text="0s" end
        else
            isRunning = true
            _setStatus("STARTING", C.yellow)
            task.spawn(autoMSLoop)
        end
    end
end)

-- ================================================================
-- SAFE MODE RUNTIME  (v6 — full rewrite)
-- ================================================================

local SAFE_X, SAFE_Y, SAFE_Z = -534.245971679687, 14.356728553771973, 189.90879821777344
local SAFE_POS_VEC            = Vector3.new(SAFE_X, SAFE_Y, SAFE_Z)

-- ── Cooldown guard: cegah re-trigger dalam 3 detik ──
local _safeLastTrigger = 0
local SAFE_COOLDOWN    = 3.0   -- detik minimum antar trigger

-- ── Cook state snapshot (disimpan saat kabur) ──
local SM = {
    wasFullyRunning = false,   -- apakah auto fully sedang jalan saat dipicu
    savedPhase      = nil,     -- fase masak terakhir
    cookInProgress  = false,   -- apakah sedang di tengah siklus masak
}

-- ── Teleport INSTAN ke safe spot: paksa CFrame 3x berturut agar server sync ──
-- Dipanggil langsung dari HealthChanged, tidak boleh ada delay di sini.
local function tpToSafe()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hum2 = char:FindFirstChildOfClass("Humanoid")
    local seat = hum2 and hum2.SeatPart
    local targetCF = CFrame.new(SAFE_X, SAFE_Y + 3, SAFE_Z)

    if seat then
        local vModel = seat:FindFirstAncestorWhichIsA("Model")
        if vModel and vModel.PrimaryPart then
            -- Paksa kendaraan ke safe 3x tanpa delay
            for _ = 1, 3 do
                pcall(function() vModel:SetPrimaryPartCFrame(targetCF) end)
            end
            return
        end
    end

    -- Paksa HRP ke safe 3x tanpa delay antar frame
    for _ = 1, 3 do
        pcall(function() hrp.CFrame = targetCF end)
    end
end

-- ── Cek musuh dalam radius dari suatu posisi ──
local function hasEnemyNear(pos, radius)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isWhitelisted(plr) then
            local ch2  = plr.Character
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

-- ── Update label safe mode (aman jika lbl belum siap) ──
local function setSafeLbl(msg, col)
    if safeModeStatusLbl then
        safeModeStatusLbl.Text       = msg
        safeModeStatusLbl.TextColor3 = col or Color3.fromRGB(255,200,0)
    end
end

-- ── Snapshot fase masak saat ini berdasarkan inventory + rpcQueue ──
local function detectCookPhase()
    local hasWater    = countItem(CFG.ITEM_WATER) >= 1
    local hasSugar    = countItem(CFG.ITEM_SUGAR) >= 1
    local hasGelatin  = countItem(CFG.ITEM_GEL)   >= 1
    local hasEmptyBag = countItem(CFG.ITEM_EMPTY)  >= 1

    -- Prioritaskan sinyal RPC dari server (paling akurat)
    for _, v in ipairs(rpcQueue) do
        if     v.type == "wait_boil"   then return "need_sugar",       hasWater, hasSugar, hasGelatin
        elseif v.type == "add_sugar"   then return "need_sugar",       hasWater, hasSugar, hasGelatin
        elseif v.type == "add_gelatin" then return "need_gelatin",     hasWater, hasSugar, hasGelatin
        elseif v.type == "wait_cook"   then return "cooking_progress", hasWater, hasSugar, hasGelatin
        elseif v.type == "bag_result"  then return "need_bag",         hasWater, hasSugar, hasGelatin
        end
    end

    -- Fallback: deduksi dari inventory
    if     hasWater  and hasSugar  and hasGelatin  then return "fresh",            hasWater, hasSugar, hasGelatin
    elseif not hasWater and hasSugar  and hasGelatin  then return "need_sugar",   hasWater, hasSugar, hasGelatin
    elseif not hasWater and not hasSugar and hasGelatin  then return "need_gelatin", hasWater, hasSugar, hasGelatin
    elseif not hasWater and not hasSugar and not hasGelatin then
        if hasEmptyBag then return "need_bag",         hasWater, hasSugar, hasGelatin
        else                return "cooking_progress", hasWater, hasSugar, hasGelatin end
    end
    return "unknown", hasWater, hasSugar, hasGelatin
end

-- ── Resume masak dari fase terdeteksi, lanjut normal setelahnya ──
local function resumeCookFromPhase()
    local phase, hasWater, hasSugar, hasGelatin = detectCookPhase()
    isBusy = true

    local snapS = countItem(CFG.ITEM_MS_SMALL)
    local snapM = countItem(CFG.ITEM_MS_MEDIUM)
    local snapL = countItem(CFG.ITEM_MS_LARGE)

    _setStatus("Resume: "..phase, Color3.fromRGB(255,200,50))
    _setPhase("Resume: "..phase)

    -- FASE: kompor kosong → masukkan water
    if phase == "fresh" or phase == "need_water" then
        if not isRunning then isBusy=false; return false end
        _setStatus("Masukkan Water...", Color3.fromRGB(100,180,255))
        _setPhase("Masukkan Water...")
        cookInteract(CFG.ITEM_WATER)
        local boilSecs
        for _ = 1, 30 do boilSecs = popTimer(); if boilSecs then break end; task.wait(0.1) end
        boilSecs = boilSecs or CFG.WATER_WAIT
        if not countdown(boilSecs, "Mendidih...", Color3.fromRGB(80,150,255)) then isBusy=false; return false end
        phase = "need_sugar"
    end

    -- FASE: butuh sugar
    if phase == "need_sugar" then
        if not isRunning then isBusy=false; return false end
        _setStatus("Tunggu Sugar...", Color3.fromRGB(255,220,100))
        _setPhase("Tunggu Sugar...")
        waitRPC("add_sugar", 15)
        if not isRunning then isBusy=false; return false end
        _setStatus("Masukkan Sugar...", Color3.fromRGB(255,220,100))
        _setPhase("Masukkan Sugar...")
        cookInteract(CFG.ITEM_SUGAR)
        task.wait(0.4)
        phase = "need_gelatin"
    end

    -- FASE: butuh gelatin
    if phase == "need_gelatin" then
        if not isRunning then isBusy=false; return false end
        _setStatus("Tunggu Gelatin...", Color3.fromRGB(255,200,50))
        _setPhase("Tunggu Gelatin...")
        waitRPC("add_gelatin", 15)
        if not isRunning then isBusy=false; return false end
        _setStatus("Masukkan Gelatin...", Color3.fromRGB(255,200,50))
        _setPhase("Masukkan Gelatin...")
        cookInteract(CFG.ITEM_GEL)
        task.wait(0.4)
        phase = "need_bag"
    end

    -- FASE: semua bahan sudah masuk, tunggu hasil masak
    if phase == "need_bag" or phase == "cooking_progress" then
        if not isRunning then isBusy=false; return false end
        local cookSecs
        for _ = 1, 30 do cookSecs = popTimer(); if cookSecs then break end; task.wait(0.1) end
        cookSecs = cookSecs or CFG.COOK_WAIT
        if not countdown(cookSecs, "Memasak (resume)...", Color3.fromRGB(80,140,255)) then isBusy=false; return false end

        _setStatus("Tunggu Bag...", Color3.fromRGB(100,160,255))
        _setPhase("Tunggu Bag...")
        waitRPC("bag_result", 18)

        local bag; local t2 = 0
        repeat
            bag = LocalPlayer.Backpack:FindFirstChild(CFG.ITEM_EMPTY)
            task.wait(0.3); t2 += 0.3
        until bag or t2 > 14

        if not bag then
            _setStatus("No Empty Bag!", Color3.fromRGB(255,60,90))
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
        until (newS > 0 or newM > 0 or newL > 0) or waitMS > 10

        if     newS > 0 then patStats.small  += newS
        elseif newM > 0 then patStats.medium += newM
        elseif newL > 0 then patStats.large  += newL
        else                 patStats.small  += 1 end

        _setPhase("Resume OK #"..totalMS())
        _setTimer("Done")
    end

    isBusy = false
    return true
end

-- ── Status label helper gabungan (MS + SafeMode) ──
local function dualStatus(msg, col)
    _setStatus(msg, col)
    setSafeLbl(msg, col)
end

-- ================================================================
-- SAFE MODE — TRIGGER UTAMA  (v7)
-- Filosofi: PAUSE bukan STOP. Loop autofully tetap "jalan" di latar,
-- tapi eksekusi di-pause via safeModeActive flag yang dicek countdown().
-- Setelah aman → balik apart → lanjut masukkan bahan yang belum masuk.
-- ================================================================
local safeConn = nil

local function triggerSafeEscape(newHP)
    -- Guard 1: safe mode harus aktif
    if not safeMode then return end
    -- Guard 2: tidak boleh trigger ulang saat sudah aktif
    if safeModeActive then return end
    -- Guard 3: cooldown antar trigger
    local now = tick()
    if now - _safeLastTrigger < SAFE_COOLDOWN then return end
    -- Guard 4: harus damage nyata (HP turun)
    local dmg = math.floor(lastHealth - newHP)
    if dmg <= 0 then lastHealth = newHP; return end

    -- ── Kunci trigger ──
    safeModeActive   = true
    _safeLastTrigger = now
    lastHealth       = newHP

    -- Snapshot state (apakah fully sedang jalan?)
    SM.wasFullyRunning = fullyRunning
    SM.savedPhase, _   = detectCookPhase()
    SM.cookInProgress  = isBusy

    -- ── Update UI ──
    _setStatus("⚠ HIT -"..dmg.."HP! KABUR!", Color3.fromRGB(255,40,40))
    if phaseValue then phaseValue.Text = "Safe Mode..." end
    setSafeLbl("⚠ HIT -"..dmg.."HP! KABUR KE SAFE SPOT...", Color3.fromRGB(255,40,40))

    -- ── Teleport INSTAN — dilakukan SEKARANG (sinkron, sebelum task.spawn) ──
    -- Ini memastikan karakter sudah berpindah sebelum frame berikutnya.
    tpToSafe()
    -- Teleport kedua setelah satu frame untuk pastikan server terima
    task.defer(tpToSafe)

    -- ── Recovery goroutine (scan musuh, balik apart, resume) ──
    task.spawn(function()
        task.wait(0.15)  -- minimal stabilisasi, bukan 0.8

        -- ═══════════════════════════════════════
        -- FASE 1: TUNGGU AMAN DI SAFE SPOT
        -- ═══════════════════════════════════════
        setSafeLbl("DI SAFE SPOT – SCAN MUSUH...", Color3.fromRGB(255,200,0))

        local scanRadius = FULLY_ENEMY_RADIUS
        local waitStart  = tick()
        local MAX_WAIT   = 45   -- tunggu max 45 detik
        local clearCount = 0    -- butuh 3x scan bersih berturut → boleh balik

        while tick() - waitStart < MAX_WAIT do
            local myCh  = LocalPlayer.Character
            local myHRP = myCh and myCh:FindFirstChild("HumanoidRootPart")
            local scanCenter = myHRP and myHRP.Position or SAFE_POS_VEC

            local enemyFound, enemyName, enemyDist = hasEnemyNear(scanCenter, scanRadius)

            if enemyFound then
                clearCount = 0
                setSafeLbl(
                    string.format("⚠ MUSUH: %s (%.0fm) — TAHAN...", enemyName, enemyDist),
                    Color3.fromRGB(255,60,60)
                )
                if enemyDist < 12 then tpToSafe(); task.wait(0.5) end
            else
                clearCount += 1
                setSafeLbl(
                    string.format("Clear %d/3 — verifikasi aman...", clearCount),
                    Color3.fromRGB(255,220,80)
                )
                if clearCount >= 3 then break end
            end
            task.wait(1.2)
        end

        -- ═══════════════════════════════════════
        -- FASE 2: BALIK KE APARTEMEN
        -- ═══════════════════════════════════════
        if fullySavedPos then
            setSafeLbl("AMAN – BALIK KE APARTEMEN...", Color3.fromRGB(100,255,180))
            fullyTeleport(fullySavedPos)
            task.wait(1.8)

            -- Verifikasi posisi
            local myCh2  = LocalPlayer.Character
            local myHRP2 = myCh2 and myCh2:FindFirstChild("HumanoidRootPart")
            if myHRP2 and (myHRP2.Position - fullySavedPos).Magnitude > 8 then
                fullyTeleport(fullySavedPos)
                task.wait(1.2)
            end
        else
            setSafeLbl("AMAN – Posisi apart belum tersimpan.", Color3.fromRGB(255,160,40))
            task.wait(1)
        end

        -- ═══════════════════════════════════════
        -- FASE 3: CEK MUSUH LAGI DI APART
        -- ═══════════════════════════════════════
        local apartPos = fullySavedPos or SAFE_POS_VEC
        local ef2, en2, ed2 = hasEnemyNear(apartPos, scanRadius)
        if ef2 then
            setSafeLbl(
                string.format("MUSUH MASIH DI APART: %s (%.0fm) – BALIK SAFE", en2, ed2),
                Color3.fromRGB(255,80,80)
            )
            tpToSafe(); task.wait(2)
            local st2 = tick()
            while tick() - st2 < 20 do
                local ef3, en3, ed3 = hasEnemyNear(apartPos, scanRadius)
                if not ef3 then break end
                setSafeLbl(string.format("Tunggu: %s (%.0fm)...", en3, ed3), Color3.fromRGB(255,80,80))
                task.wait(1.5)
            end
            if fullySavedPos then fullyTeleport(fullySavedPos); task.wait(1.5) end
        end

        -- ═══════════════════════════════════════
        -- FASE 4: RESET FLAG → loop lanjut otomatis
        -- ═══════════════════════════════════════
        local char3 = LocalPlayer.Character
        local hum3  = char3 and char3:FindFirstChildOfClass("Humanoid")
        if hum3 then lastHealth = hum3.Health end

        -- ── Deteksi fase masak setelah kembali ke apart ──
        local phase, hasW, hasS, hasG = detectCookPhase()

        local phaseDesc = {
            fresh            = "KOMPOR KOSONG",
            need_sugar       = "BELUM MASUKKAN SUGAR",
            need_gelatin     = "BELUM MASUKKAN GELATIN",
            need_bag         = "TUNGGU SELESAI MASAK",
            cooking_progress = "LANJUT MASAK",
            unknown          = "CEK BAHAN...",
        }
        setSafeLbl("RESUME: "..(phaseDesc[phase] or phase), Color3.fromRGB(82,210,150))

        -- ── Jika fully sedang jalan: lanjutkan dari fase (tanpa restart) ──
        if SM.wasFullyRunning and safeMode then

            -- Jika loop sudah berhenti saat kabur (karena non-countdown path berhenti),
            -- aktifkan kembali. Jika masih aktif (di-pause oleh countdown), biarkan.
            if not isRunning then isRunning = true end
            if not fullyRunning then fullyRunning = true end

            -- Lepas pause → countdown() akan lanjut sendiri
            -- Tapi jika kita sedang di luar countdown (misal di waitRPC atau antara fase),
            -- kita perlu interject: masukkan bahan yang belum masuk secara eksplisit.
            -- Cek apakah ada bahan yang masih harus dimasukkan.
            task.spawn(function()
                task.wait(0.3)

                -- ── Masukkan bahan yang belum masuk (interject cook) ──
                unequipAll()

                -- Sugar: jika masih di inventory dan kompor menunggu sugar
                if phase == "need_sugar" and hasS then
                    setSafeLbl("Masukkan Sugar...", Color3.fromRGB(255,220,100))
                    _setStatus("Masukkan Sugar (resume)...", Color3.fromRGB(255,220,100))
                    _setPhase("Masukkan Sugar...")
                    cookInteract(CFG.ITEM_SUGAR)
                    task.wait(0.5)
                    phase = "need_gelatin"
                end

                -- Gelatin: jika masih di inventory dan kompor menunggu gelatin
                if phase == "need_gelatin" and hasG then
                    setSafeLbl("Masukkan Gelatin...", Color3.fromRGB(255,200,50))
                    _setStatus("Masukkan Gelatin (resume)...", Color3.fromRGB(255,200,50))
                    _setPhase("Masukkan Gelatin...")
                    cookInteract(CFG.ITEM_GEL)
                    task.wait(0.5)
                end

                -- Setelah bahan dimasukkan, baru release safeModeActive
                -- agar countdown() yang di-pause bisa lanjut
                safeModeActive = false
                setSafeLbl("LANJUT MASAK...", Color3.fromRGB(0,255,136))
            end)
        else
            -- Fully tidak jalan → langsung release
            safeModeActive = false
            setSafeLbl("STANDBY", Color3.fromRGB(0,255,136))
        end
    end)
end

-- ── Hook health listener, re-hook saat respawn ──
local function hookSafeMode(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    lastHealth = hum.Health
    if safeConn then safeConn:Disconnect(); safeConn = nil end
    safeConn = hum.HealthChanged:Connect(triggerSafeEscape)
end
if LocalPlayer.Character then task.spawn(function() hookSafeMode(LocalPlayer.Character) end) end
LocalPlayer.CharacterAdded:Connect(function(char)
    safeModeActive   = false
    _safeLastTrigger = 0
    SM.wasFullyRunning = false
    task.spawn(function() hookSafeMode(char) end)
end)

-- ================================================================
-- ESP RENDER LOOP
-- ================================================================
RunService.Heartbeat:Connect(function(dt)
    if not espEnabled then
        for _, drawings in pairs(espCache) do for _, o in pairs(drawings) do pcall(function() o.Visible = false end) end end
        return
    end
    _espAccum = _espAccum + dt
    if _espAccum < ESP_INTERVAL then return end
    _espAccum = 0
    local myChar = LocalPlayer.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos  = myHRP and myHRP.Position
    for player, drawings in pairs(espCache) do
        local box=drawings[1]; local nameL=drawings[2]; local hpBg=drawings[3]
        local hpFl=drawings[4]; local dL=drawings[5]; local iL=drawings[6]
        local function hideAll()
            box.Visible=false; nameL.Visible=false; hpBg.Visible=false
            hpFl.Visible=false; dL.Visible=false
            if iL then iL.Visible=false end
        end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local head=char and char:FindFirstChild("Head")
        local valid=char and hum and root and head and hum.Health>0 and not isWhitelisted(player)
        if not valid then hideAll()
        else
            local dist3D=myPos and (root.Position-myPos).Magnitude or 0
            if myPos and espMaxDist>0 and dist3D>espMaxDist then hideAll()
            else
                local hrpPos,hrpVis=Camera:WorldToViewportPoint(root.Position)
                local headPos,headVis=Camera:WorldToViewportPoint(head.Position)
                if not(hrpVis and headVis) then hideAll()
                else
                    local height=math.abs(headPos.Y-hrpPos.Y)*1.7+(boxPadding*2)
                    local width=height*0.55; local boxX=hrpPos.X-width/2; local boxY=headPos.Y-boxPadding
                    box.Color=espBoxColor; box.Size=Vector2.new(width,height); box.Position=Vector2.new(boxX,boxY); box.Visible=true
                    nameL.Text=player.Name; nameL.Color=espNameColor; nameL.Position=Vector2.new(hrpPos.X,boxY-14); nameL.Visible=true
                    local hpR=hum.MaxHealth>0 and math.clamp(hum.Health/hum.MaxHealth,0,1) or 1
                    local hpBW=3; local hpBX=boxX-hpBW-2
                    hpBg.Size=Vector2.new(hpBW,height); hpBg.Position=Vector2.new(hpBX,boxY); hpBg.Visible=true
                    local fH=math.max(1,height*hpR); local fY=boxY+(height-fH)
                    hpFl.Size=Vector2.new(hpBW,fH); hpFl.Position=Vector2.new(hpBX,fY)
                    hpFl.Color=hpR>0.6 and Color3.fromRGB(0,255,80) or hpR>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50)
                    hpFl.Visible=true
                    if myPos then dL.Text=string.format("[%.0fm]",dist3D); dL.Position=Vector2.new(hrpPos.X,boxY+height+4); dL.Visible=true else dL.Visible=false end
                    if iL then
                        local hi=nil
                        if char then for _,o in pairs(char:GetChildren()) do if o:IsA("Tool") then hi=o.Name; break end end end
                        if hi then iL.Text="["..hi.."]"; iL.Color=espItemColor; iL.Position=Vector2.new(hrpPos.X,boxY+height+16); iL.Visible=true
                        else iL.Visible=false end
                    end
                end
            end
        end
    end
end)

-- ================================================================
-- AIMBOT CORE
-- ================================================================
local function getPredPos(part,player)
    local now=tick(); local cur=part.Position
    if not velCache[player] then velCache[player]={lastPos=cur,lastVel=Vector3.zero,lastTime=now};return cur end
    local cache=velCache[player]; local dt=now-cache.lastTime
    if dt>0 and dt<0.2 then cache.lastVel=cache.lastVel:Lerp((cur-cache.lastPos)/dt,0.5) elseif dt>=0.2 then cache.lastVel=Vector3.zero end
    cache.lastPos=cur;cache.lastTime=now; if not aimbotPrediction then return cur end; return cur+cache.lastVel*predStrength
end
local function getBestTarget()
    local mx,my; if aimbotMode=="FreeAim" then local mp=UserInputService:GetMouseLocation();mx,my=mp.X,mp.Y else mx=Camera.ViewportSize.X/2;my=Camera.ViewportSize.Y/2 end
    local bestScore=math.huge;local bestPart=nil;local bestPlr=nil
    local myChar=LocalPlayer.Character;local myHRP=myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _,plr in pairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and not isWhitelisted(plr) then
            local char=plr.Character; if char then
                local hum=char:FindFirstChildOfClass("Humanoid"); local part=char:FindFirstChild(aimbotTarget) or char:FindFirstChild("HumanoidRootPart")
                if part and hum and hum.Health>0 then
                    if aimbotMaxDist>0 and myHRP and (part.Position-myHRP.Position).Magnitude>aimbotMaxDist then continue end
                    local sp,vis=Camera:WorldToViewportPoint(part.Position); if vis then
                        local dS=math.sqrt((sp.X-mx)^2+(sp.Y-my)^2)
                        if dS<=aimbotFOV then local score=aimbotPriority=="Crosshair" and dS or (myHRP and (part.Position-myHRP.Position).Magnitude or dS); if score<bestScore then bestScore=score;bestPart=part;bestPlr=plr end end
                    end
                end
            end
        end
    end
    return bestPart,bestPlr
end
local function isAimKeyHeld()
    if isBindingKey then return false end
    local t=aimbotKeybindType
    if t=="KeyCode" then return aimbotKeybindCode~=nil and UserInputService:IsKeyDown(aimbotKeybindCode)
    elseif t=="MouseButton" then
        if aimbotKeybind==Enum.UserInputType.MouseButton2 then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif aimbotKeybind==Enum.UserInputType.MouseButton3 then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) end
    elseif t=="MB4" then return mb4Held elseif t=="MB5" then return mb5Held end; return false
end
UserInputService.InputBegan:Connect(function(input) if isBindingKey then return end; local kn=tostring(input.KeyCode):gsub("Enum%.KeyCode%.","");local un=tostring(input.UserInputType):gsub("Enum%.UserInputType%.",""); if kn=="MouseButton4" or un=="MouseButton4" then mb4Held=true elseif kn=="MouseButton5" or un=="MouseButton5" then mb5Held=true end end)
UserInputService.InputEnded:Connect(function(input) local kn=tostring(input.KeyCode):gsub("Enum%.KeyCode%.","");local un=tostring(input.UserInputType):gsub("Enum%.UserInputType%.",""); if kn=="MouseButton4" or un=="MouseButton4" then mb4Held=false elseif kn=="MouseButton5" or un=="MouseButton5" then mb5Held=false end end)

aimbotFovCircle=Drawing.new("Circle"); aimbotFovCircle.Thickness=1; aimbotFovCircle.Color=fovColor; aimbotFovCircle.Filled=false; aimbotFovCircle.Visible=false; aimbotFovCircle.Radius=aimbotFOV
aimbotFovCircle.Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)

local _fpX=0;local _fpY=0;local _fRCur=250;local _faVX=0;local _faVY=0
local mmMethod=nil; pcall(function() if mousemoverel then mmMethod="rel" end end)

RunService.RenderStepped:Connect(function(dt)
    local txF,tyF; if aimbotMode=="FreeAim" then local mp=UserInputService:GetMouseLocation();txF,tyF=mp.X,mp.Y else txF=Camera.ViewportSize.X/2;tyF=Camera.ViewportSize.Y/2 end
    if _fpX==0 then _fpX=txF end; if _fpY==0 then _fpY=tyF end
    local fL=math.clamp(dt*40,0,1); _fpX=_fpX+(txF-_fpX)*fL; _fpY=_fpY+(tyF-_fpY)*fL; _fRCur=_fRCur+(aimbotFOV-_fRCur)*fL
    aimbotFovCircle.Position=Vector2.new(_fpX,_fpY); aimbotFovCircle.Radius=_fRCur; aimbotFovCircle.Color=fovColor; aimbotFovCircle.Visible=aimbotEnabled
    if not aimbotEnabled then _faVX=0;_faVY=0;return end
    local aimbotActive2=isAimKeyHeld(); if not aimbotActive2 then _faVX=_faVX*0.7;_faVY=_faVY*0.7;return end
    local target,tPlr=getBestTarget(); if not target then return end
    local pos=getPredPos(target,tPlr)
    if aimbotMode=="FreeAim" then
        local sp,vis=Camera:WorldToViewportPoint(pos); if not vis then return end
        local mp=UserInputService:GetMouseLocation(); local dx=sp.X-mp.X;local dy=sp.Y-mp.Y
        local base=math.clamp(1-(aimbotSmooth/20),0.04,0.95); local lT=math.clamp(1-(1-base)^(dt/0.016),0.01,1)
        _faVX=_faVX+(dx*lT-_faVX)*0.6;_faVY=_faVY+(dy*lT-_faVY)*0.6; if mmMethod=="rel" then mousemoverel(_faVX,_faVY) end
    else
        local cf=Camera.CFrame;local goal=CFrame.new(cf.Position,pos); local base=math.clamp(1-(aimbotSmooth/20),0.04,0.95); local t=math.clamp(1-(1-base)^(dt/0.016),0.01,1); Camera.CFrame=cf:Lerp(goal,t)
    end
end)

print("=== MAJESTY STORE v8.7.0 LOADED ===")
print("discord.gg/VPeZbhCz8M")