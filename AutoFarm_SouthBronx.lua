-- ============================================================
--  AUTO FARM - South Bronx Map | cvAI4 (by -gigs-)
--  Rebuilt dari: auto_farm_only_lua (obfuscated source)
--  Features: Auto Farm Loop + Anti AFK + Teleport to Item
-- ============================================================

-- ================= SERVICES =================
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local VirtualUser    = game:GetService("VirtualUser")

-- ================= PLAYER =================
local LocalPlayer   = Players.LocalPlayer
local Character     = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP           = Character:WaitForChild("HumanoidRootPart")
local Humanoid      = Character:WaitForChild("Humanoid")

-- Update refs saat respawn
LocalPlayer.CharacterAdded:Connect(function(c)
    Character = c
    HRP       = c:WaitForChild("HumanoidRootPart")
    Humanoid  = c:WaitForChild("Humanoid")
end)

-- ================= CONFIG =================
-- Edit bagian ini sesuai kebutuhan map South Bronx
local CONFIG = {
    -- Farm
    FarmEnabled   = true,
    FarmRadius    = 60,       -- radius scan item (stud)
    LoopDelay     = 0.3,      -- jeda tiap scan (detik)

    -- Folder nama di workspace South Bronx
    -- Ganti/tambah sesuai nama folder asli di explorer
    FarmFolders   = {
        "Items",
        "Drops",
        "Money",
        "Cash",
        "Collectibles",
        "Drugs",          -- common di South Bronx map
        "Weapons",
    },

    -- Teleport
    TeleportEnabled = true,
    TeleportOffset  = Vector3.new(0, 3, 0),  -- offset agar tidak nyangkut di ground
    TeleportSmooth  = false,   -- true = pakai tween (lebih smooth), false = instant

    -- Anti AFK
    AntiAFK = true,

    -- Speed (ubah hati-hati, default 16)
    WalkSpeed = 16,

    -- Chat commands
    CommandPrefix = "/",
}

-- ================= UTILS =================
local function log(msg)
    print("[cvAI4] " .. tostring(msg))
end

local function isAlive()
    return Character
        and Humanoid
        and Humanoid.Health > 0
        and HRP ~= nil
end

-- ================= ANTI AFK =================
if CONFIG.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        log("Anti-AFK triggered ✅")
    end)
    log("Anti-AFK: ON ✅")
end

-- ================= WALKSPEED =================
Humanoid.WalkSpeed = CONFIG.WalkSpeed

-- ================= TELEPORT =================
local function teleportTo(position)
    if not isAlive() then return end
    local target = position + CONFIG.TeleportOffset

    if CONFIG.TeleportSmooth then
        local tween = TweenService:Create(
            HRP,
            TweenInfo.new(0.15, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(target) }
        )
        tween:Play()
        tween.Completed:Wait()
    else
        HRP.CFrame = CFrame.new(target)
    end
    task.wait(0.05)
end

-- ================= SCANNER =================
-- Scan semua item dalam radius, return sorted by distance
local function scanItems(folderName, radius)
    local results = {}
    local folder  = workspace:FindFirstChild(folderName)
    if not folder then return results end

    for _, obj in ipairs(folder:GetChildren()) do
        local pos = nil

        if obj:IsA("Model") and obj.PrimaryPart then
            pos = obj.PrimaryPart.Position
        elseif obj:IsA("BasePart") then
            pos = obj.Position
        end

        if pos then
            local dist = (HRP.Position - pos).Magnitude
            if dist <= radius then
                table.insert(results, {
                    object   = obj,
                    position = pos,
                    distance = dist,
                })
            end
        end
    end

    -- Sort: terdekat dulu
    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    return results
end

-- ================= MAIN FARM LOOP =================
local farmConnection

local function startFarm()
    if farmConnection then
        farmConnection:Disconnect()
    end

    farmConnection = RunService.Heartbeat:Connect(function()
        if not CONFIG.FarmEnabled then return end
        if not isAlive() then return end

        for _, folderName in ipairs(CONFIG.FarmFolders) do
            local items = scanItems(folderName, CONFIG.FarmRadius)

            for _, data in ipairs(items) do
                if CONFIG.TeleportEnabled then
                    teleportTo(data.position)
                end
                task.wait(CONFIG.LoopDelay)
            end
        end
    end)

    log("Auto Farm: STARTED ✅")
end

local function stopFarm()
    if farmConnection then
        farmConnection:Disconnect()
        farmConnection = nil
    end
    log("Auto Farm: STOPPED ❌")
end

-- ================= CHAT COMMANDS =================
LocalPlayer.Chatted:Connect(function(msg)
    msg = msg:lower():gsub("%s+", "")  -- normalize

    if msg == CONFIG.CommandPrefix .. "farm" or
       msg == CONFIG.CommandPrefix .. "farmon" then
        CONFIG.FarmEnabled = true
        startFarm()

    elseif msg == CONFIG.CommandPrefix .. "farmoff" then
        CONFIG.FarmEnabled = false
        stopFarm()

    elseif msg == CONFIG.CommandPrefix .. "farmstatus" then
        log("Farm: " .. (CONFIG.FarmEnabled and "ON ✅" or "OFF ❌"))
        log("Teleport: " .. (CONFIG.TeleportEnabled and "ON ✅" or "OFF ❌"))
        log("Anti-AFK: " .. (CONFIG.AntiAFK and "ON ✅" or "OFF ❌"))
        log("Speed: " .. CONFIG.WalkSpeed)

    elseif msg == CONFIG.CommandPrefix .. "tpon" then
        CONFIG.TeleportEnabled = true
        log("Teleport: ON ✅")

    elseif msg == CONFIG.CommandPrefix .. "tpoff" then
        CONFIG.TeleportEnabled = false
        log("Teleport: OFF ❌")

    elseif msg == CONFIG.CommandPrefix .. "help" then
        log("=== COMMANDS ===")
        log("/farm | /farmon  → Start farm")
        log("/farmoff         → Stop farm")
        log("/farmstatus      → Cek status")
        log("/tpon            → Teleport ON")
        log("/tpoff           → Teleport OFF")
        log("/help            → Show commands")
    end
end)

-- ================= AUTO START =================
startFarm()

log("========================================")
log("  Auto Farm South Bronx | cvAI4 Loaded  ")
log("  by -gigs- | Type /help for commands   ")
log("========================================")


-- ============================================================
-- MODULE VERSION (untuk di-require dari script utama)
-- 
-- Cara pakai di script utama:
--
--   local AutoFarm = loadstring(game:HttpGet("URL_SCRIPT"))()
--   AutoFarm.start()
--   AutoFarm.stop()
--   AutoFarm.setConfig({ FarmRadius = 80, WalkSpeed = 20 })
--
-- ============================================================

return {
    start = startFarm,
    stop  = stopFarm,

    setConfig = function(newConfig)
        for k, v in pairs(newConfig) do
            CONFIG[k] = v
            log("Config updated: " .. tostring(k) .. " = " .. tostring(v))
        end
    end,

    getConfig = function()
        return CONFIG
    end,

    teleportTo = teleportTo,
    scanItems  = scanItems,
    isAlive    = isAlive,
}
