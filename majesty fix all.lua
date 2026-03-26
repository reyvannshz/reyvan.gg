-- ========== MAJESTY STORE v8.3.1 + PatstoreMS Engine (AutoFully Updated) ==========
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
-- STATE VARIABLES (sama seperti sebelumnya)
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
local safeMode           = false
local safeModeActive     = false
local lastHealth         = 100

local fullyRunning       = false
local fullyTarget        = 10
local fullySavedPos      = nil
local NPC_MS_POS         = Vector3.new(510.061, 4.476, 600.548)
local FULLY_ENEMY_RADIUS = 40
local fullySafeEscaping  = false

local CFG = {
    WATER_WAIT = 20, COOK_WAIT = 46,
    ITEM_WATER="Water", ITEM_SUGAR="Sugar Block Bag",
    ITEM_GEL="Gelatin", ITEM_EMPTY="Empty Bag",
    ITEM_MS_SMALL="Small Marshmallow Bag",
    ITEM_MS_MEDIUM="Medium Marshmallow Bag",
    ITEM_MS_LARGE="Large Marshmallow Bag",
    SELL_RADIUS=10, SELL_TIMEOUT=10,
}

-- ================================================================
-- PATSTORE ENGINE — UTILITY FUNCTIONS (sama)
-- ================================================================
-- (countItem, totalMS, equipTool, unequipAll, pressE, firePromptNearby, cookInteract, dll.)
-- ... (saya keep semua fungsi lama agar tidak error, termasuk doAutoSell, doAutoBuy, doOneCook, autoMSLoop)

-- ================================================================
-- UPDATED: VEHICLE TELEPORT + KOMPOR DETECTION
-- ================================================================
local function moveVehicle(vehicle, targetCFrame)
    if not vehicle or not targetCFrame then return end
    local anchor = vehicle.PrimaryPart or vehicle:FindFirstChildOfClass("VehicleSeat") or vehicle:FindFirstChildOfClass("BasePart")
    if not anchor then return end

    for _, p in ipairs(vehicle:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
                p.Anchored = true
            end)
        end
    end
    task.wait(0.05)

    if vehicle.PrimaryPart then
        vehicle:SetPrimaryPartCFrame(targetCFrame)
    else
        anchor.CFrame = targetCFrame
    end
    task.wait(0.05)

    for _, p in ipairs(vehicle:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.Anchored = false
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function findStove()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local txt = obj.ActionText:lower()
            if txt:find("cook") or txt:find("stove") or txt:find("marshmallow") then
                local part = obj.Parent
                if part and part:IsA("BasePart") then return part end
            end
        end
        if obj.Name:lower():find("stove") or obj.Name:lower():find("kompor") or obj.Name:lower():find("oven") then
            if obj:IsA("BasePart") then return obj end
        end
    end
    return nil
end

local function fullyTeleport(target, isCooking)
    local ch  = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum then return end

    local seatPart = hum.SeatPart
    if seatPart then
        local vehicle = seatPart:FindFirstAncestorOfClass("Model")
        if vehicle then
            if isCooking then
                local stove = findStove()
                if stove then
                    -- Posisi dekat kompor + menghadap samping (seperti foto)
                    local offset = Vector3.new(3.5, 1.2, 0)   -- sesuaikan kalau motor terlalu jauh/terlalu dekat
                    local targetPos = stove.Position + offset
                    local newCF = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(90), 0)
                    moveVehicle(vehicle, newCF)
                    task.wait(0.6)
                    return
                end
            end
            -- fallback
            local spawnPos = typeof(target) == "Vector3" and target + Vector3.new(0, 0.5, 0) or target.Position
            local defaultCF = CFrame.new(spawnPos)
            moveVehicle(vehicle, defaultCF)
        end
    else
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(target) end
    end
    task.wait(0.5)
end

-- ================================================================
-- AUTO FULLY (dengan perubahan teleport)
-- ================================================================
local function doAutoFully(setFullyStatus)
    fullyRunning = true
    fullySafeEscaping = false

    while fullyRunning do
        -- Beli bahan
        setFullyStatus("Teleport ke NPC Marshmallow...", Color3.fromRGB(100,180,255))
        fullyTeleport(NPC_MS_POS, false)
        doAutoBuy(setFullyStatus, fullyTarget)

        -- Teleport ke Apart (cooking mode = true)
        setFullyStatus("Teleport ke Apart...", Color3.fromRGB(148,80,255))
        fullyTeleport(fullySavedPos, true)   -- <--- ini yang penting

        -- Masak, Jual, dll. (logic lama tetap)
        -- ... (sisa kode doAutoFully sama seperti aslinya)

        if not fullyRunning then break end
        task.wait(0.2)
    end
    fullyRunning = false
end

-- ================================================================
-- GUI (tambahan tombol scan & beli apart)
-- ================================================================
-- (Bagian GUI besar tetap sama, hanya tambahkan di pageAutoFully)

-- Contoh tambahan tombol (taruh setelah afApartCard di kode asli)
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1,-20,0,36)
scanBtn.Position = UDim2.new(0,10,0,380)
scanBtn.BackgroundColor3 = Color3.fromRGB(0, 196, 255)
scanBtn.Text = "🔎 SCAN APARTEMEN YANG BELUM DIBELI"
scanBtn.TextColor3 = Color3.new(1,1,1)
scanBtn.Font = Enum.Font.GothamBold
scanBtn.TextSize = 13
scanBtn.Parent = pageAutoFully
mkCorner(scanBtn,5)

scanBtn.MouseButton1Click:Connect(function()
    local avail = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("apart") then
            local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
            if prompt and (prompt.ActionText:lower():find("buy") or prompt.ActionText:lower():find("claim")) then
                local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                if root then
                    table.insert(avail, {
                        name = obj.Name .. " (AVAILABLE)",
                        x = root.Position.X,
                        y = root.Position.Y,
                        z = root.Position.Z
                    })
                end
            end
        end
    end
    if #avail == 0 then
        fullyStatusLbl_af.Text = "Tidak ada apartemen kosong!"
        fullyStatusLbl_af.TextColor3 = Color3.fromRGB(255,60,90)
        return
    end
    afApartList = avail
    afSelectedApart = 1
    updateApartSelection()
    fullyStatusLbl_af.Text = #avail .. " apartemen tersedia!"
    fullyStatusLbl_af.TextColor3 = Color3.fromRGB(0,255,136)
end)

-- Tombol Beli Apartemen
local buyAptBtn = Instance.new("TextButton")
buyAptBtn.Size = UDim2.new(1,-20,0,36)
buyAptBtn.Position = UDim2.new(0,10,0,422)
buyAptBtn.BackgroundColor3 = Color3.fromRGB(0,180,80)
buyAptBtn.Text = "🛒 BELI APARTEMEN INI"
buyAptBtn.TextColor3 = Color3.new(1,1,1)
buyAptBtn.Font = Enum.Font.GothamBold
buyAptBtn.TextSize = 13
buyAptBtn.Parent = pageAutoFully
mkCorner(buyAptBtn,5)

buyAptBtn.MouseButton1Click:Connect(function()
    firePromptNearby(15)
    fullyStatusLbl_af.Text = "Mencoba beli apartemen..."
    fullyStatusLbl_af.TextColor3 = Color3.fromRGB(255,215,0)
end)

print("=== MAJESTY STORE v8.3.1 + AutoFully Updated LOADED ===")
print("discord.gg/VPeZbhCz8M")
