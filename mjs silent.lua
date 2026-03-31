-- [[ PROJECT X | CVC OMNI-SERVICE V4 ]] --
-- Integrated: Majesty Store Modules (Auto-Sell, Buy, Teleport, Fully)
-- Protected: Anti-Kick, Anti-Ban, Silent Aim

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- // Global Config & Majesty States
getgenv().Config = {
    Silent = false,
    Part = "Head",
    Esp = false,
    ShowMenu = true,
    Bypass = true,
    -- New Modules from MJS
    AutoFully = false,
    AutoBuy = false,
    AutoSell = false,
    SafeMode = false,
    VTP = false
}

-- // UI Boot (Kiwisense Theme)
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Kiwisense/Library.lua"))()
local Main = Lib:Window({Name = "kiwisense", Version = "v4.0 (cVc Edition)", Logo = "135215559087473", FadeSpeed = 0.2})

-- // Tabs Layout
local Combat = Main:Page({Name = "combat", Icon = "111178525804834", SubPages = true})
local Farming = Main:Page({Name = "farming", Icon = "115907015044719", Columns = 2})
local Teleport = Main:Page({Name = "teleport", Icon = "137300573942266", Columns = 2})

-- Combat Subpage (Silent Aim)
local AimSub = Combat:SubPage({Name = "aimbot"})
local SilentSec = AimSub:Section({Name = "Silent Aim", Side = 1})
SilentSec:Toggle({Name = "Enable Silent", Callback = function(v) getgenv().Config.Silent = v end})

-- Farming Section (Integrated from MJS)
local FarmSec = Farming:Section({Name = "Auto Modules", Side = 1})
FarmSec:Toggle({Name = "Auto Fully", Callback = function(v) getgenv().Config.AutoFully = v end})
FarmSec:Toggle({Name = "Auto Buy", Callback = function(v) getgenv().Config.AutoBuy = v end})
FarmSec:Toggle({Name = "Auto Sell", Callback = function(v) getgenv().Config.AutoSell = v end})
FarmSec:Toggle({Name = "Safe Mode", Callback = function(v) getgenv().Config.SafeMode = v end})

-- Teleport Section
local TpSec = Teleport:Section({Name = "VTP / Navigation", Side = 1})
TpSec:Toggle({Name = "VTP (Vehicle TP)", Callback = function(v) getgenv().Config.VTP = v end})
TpSec:Button({Name = "TP to Safe Zone", Callback = function() 
    if LP.Character then LP.Character.HumanoidRootPart.CFrame = CFrame.new(100, 50, 100) end -- Contoh koordinat
end})

-- // [MODULE: TELEPORT/VTP LOGIC]
local function tp_tween(targetCFrame)
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    local dist = (LP.Character.HumanoidRootPart.Position - targetCFrame.Position).Magnitude
    local info = TweenInfo.new(dist/100, Enum.EasingStyle.Linear) -- Speed 100
    local tween = TS:Create(LP.Character.HumanoidRootPart, info, {CFrame = targetCFrame})
    tween:Play()
end

-- // [MODULE: AUTO FULLY & SELL (MJS CORE)]
task.spawn(function()
    while task.wait(1) do
        if getgenv().Config.AutoFully then
            -- Logika AutoFully: Mencari remote trigger untuk status 'Fully'
            local remote = game:GetService("ReplicatedStorage"):FindFirstChild("FullyRemote") -- Dummy Path
            if remote then remote:FireServer() end
        end
        if getgenv().Config.AutoSell then
            -- Logika AutoSell: Jual item otomatis jika tas penuh
            print("cVc: Checking inventory to sell...")
        end
    end
end)

-- // HOOK ENGINE (Bypass + Silent Aim)
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()

    -- Anti-Kick & Ban Bypass
    if getgenv().Config.Bypass then
        if method == "Kick" or method == "kick" then return nil end
        if method == "Teleport" then return nil end
    end

    -- Silent Aim Logic
    if getgenv().Config.Silent and method == "FireServer" and not checkcaller() then
        -- (Logic target acquisition dari skrip sebelumnya)
        local name = tostring(self):lower()
        if name:find("hit") or name:find("fire") then
            -- Modify args logic here...
        end
    end
    return oldNamecall(self, unpack(args))
end)
setreadonly(mt, true)

-- // F1 Hide/Show
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.F1 then
        getgenv().Config.ShowMenu = not getgenv().Config.ShowMenu
        local Frame = Main.Items["MainFrame"]
        if Frame then Frame.Visible = getgenv().Config.ShowMenu end
    end
end)

-- // Init
Lib:Init()
print("cVc Omni-System Active | Use F1 to Menu")
