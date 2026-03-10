-- ============================================================
--   reyvan.gg | South Bronx : The Trenches  v6.0
--   Auto Farm Marshmallow + Inventory Tracker + ESP
--   Rewrite total - logic dari script yang terbukti jalan
-- ============================================================

-- ── SERVICES ────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local Workspace        = workspace

local lp     = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled

-- Tunggu character
repeat task.wait() until lp.Character and lp.Character:FindFirstChild("Humanoid")

-- ── ANTI-KICK (Xeno safe) ───────────────────────────────────
-- Block RemoteEvent bernama kick/ban
local kickWords = {"kick","ban","punish","exile","suspend"}
local function isKickRemote(n)
    n = n:lower()
    for _,w in ipairs(kickWords) do if n:find(w,1,true) then return true end end
    return false
end
local function blockRemote(obj)
    pcall(function()
        if obj:IsA("RemoteEvent") and isKickRemote(obj.Name) then
            obj.OnClientEvent:Connect(function() end)
        end
        if obj:IsA("RemoteFunction") and isKickRemote(obj.Name) then
            obj.OnClientInvoke = function() return nil end
        end
    end)
end
task.spawn(function()
    task.wait(1)
    for _,v in ipairs(game:GetDescendants()) do pcall(blockRemote,v) end
end)
game.DescendantAdded:Connect(function(d) task.wait(0.1) pcall(blockRemote,d) end)

-- Hook namecall (PC executor only, Xeno safe)
task.spawn(function()
    pcall(function()
        if not (typeof(getrawmetatable)=="function" and typeof(newcclosure)=="function" and typeof(getnamecallmethod)=="function") then return end
        local mt  = getrawmetatable(game)
        local old = rawget(mt,"__namecall")
        if not old then return end
        local ro = typeof(isreadonly)=="function" and isreadonly(mt) or false
        if ro and typeof(setreadonly)=="function" then setreadonly(mt,false) end
        rawset(mt,"__namecall",newcclosure(function(self,...)
            if getnamecallmethod()=="Kick" and self==lp then return end
            return old(self,...)
        end))
        if ro and typeof(setreadonly)=="function" then setreadonly(mt,true) end
    end)
end)

-- ── STATE ────────────────────────────────────────────────────
local autoRunning  = false
local espActive    = false
local espObjs      = {}
local sessionStart = tick()
local moneyGained  = 0
local cycleCount   = 0
local currentPhase = "Idle"
local currentTimer = "—"

-- ── INVENTORY TRACKER ────────────────────────────────────────
local invCount = {Water=0, Gelatin=0, Sugar=0, Bag=0}

local function updateInventory()
    local w,g,s,b = 0,0,0,0
    local function scanTools(parent)
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("water")                          then w+=1
                elseif n:find("gelatin") or n:find("gel")  then g+=1
                elseif n:find("sugar") or n:find("block")  then s+=1
                elseif n:find("bag") or n:find("empty")    then b+=1
                end
            end
        end
    end
    pcall(function()
        if lp:FindFirstChild("Backpack") then scanTools(lp.Backpack) end
        if lp.Character then scanTools(lp.Character) end
    end)
    invCount.Water=w invCount.Gelatin=g invCount.Sugar=s invCount.Bag=b
end

-- ── FARMING CORE (terbukti dari script asli) ─────────────────

-- Equip tool dari Backpack ke Character
local function holdItem(name)
    pcall(function()
        local bp = lp:FindFirstChild("Backpack")
        if not bp then return end
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find(name:lower()) then
                tool.Parent = lp.Character
                task.wait(0.25)
                return
            end
        end
    end)
end

-- Hadapkan karakter ke objek terdekat
local function lookAt(name)
    pcall(function()
        local char = lp.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("Part") or obj:IsA("MeshPart")) and
               obj.Name:lower():find(name:lower()) then
                local d = (root.Position - obj.Position).Magnitude
                if d < 20 then
                    root.CFrame = CFrame.lookAt(
                        root.Position,
                        Vector3.new(obj.Position.X, root.Position.Y, obj.Position.Z)
                    )
                    return
                end
            end
        end
    end)
end

-- Klik mouse (interact)
local function interact()
    pcall(function()
        if mouse1press then
            mouse1press()
            task.wait(0.05)
            mouse1release()
        elseif typeof(fireproximityprompt)=="function" then
            -- fallback: fire proximity prompt terdekat
            local char = lp.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.Enabled then
                    local part = obj.Parent
                    if part and part:IsA("BasePart") and
                       (part.Position - root.Position).Magnitude < 8 then
                        fireproximityprompt(obj)
                        break
                    end
                end
            end
        end
    end)
end

-- Countdown timer live di GUI
local function countdown(seconds, phaseLabel)
    for i = 1, seconds do
        if not autoRunning then return end
        currentTimer = i.."/"..seconds.."s"
        updateInventory()
        task.wait(1)
    end
end

-- ── MAIN AUTO FARM LOOP ──────────────────────────────────────
local function autoFarmLoop()
    while autoRunning do
        local ok, err = pcall(function()

            -- STEP 1: WATER
            currentPhase = "💧 Equip Water"
            holdItem("water")
            lookAt("water")
            task.wait(0.3)
            interact()
            updateInventory()
            currentPhase = "⏳ Masak Water"
            countdown(20, "Water")
            if not autoRunning then return end

            -- STEP 2: SUGAR BLOCK
            currentPhase = "🧊 Equip Sugar Block"
            holdItem("sugar")
            lookAt("sugar")
            task.wait(0.3)
            interact()
            updateInventory()

            -- Delay 1 detik antara sugar dan gelatin
            currentPhase = "⏸ Delay Sugar→Gelatin"
            currentTimer = "1s"
            task.wait(1)
            if not autoRunning then return end

            -- STEP 3: GELATIN
            currentPhase = "🍮 Equip Gelatin"
            holdItem("gelatin")
            lookAt("gelatin")
            task.wait(0.3)
            interact()
            updateInventory()
            currentPhase = "⏳ Fermentasi"
            countdown(45, "Ferment")
            if not autoRunning then return end

            -- STEP 4: EMPTY BAG
            currentPhase = "👜 Equip Empty Bag"
            holdItem("bag")
            lookAt("bag")
            task.wait(0.3)
            interact()
            updateInventory()

            currentPhase = "✅ Siklus selesai"
            currentTimer = "Done"
            moneyGained += 950
            cycleCount  += 1
            task.wait(2)
            updateInventory()
        end)

        if not ok then
            warn("[reyvan.gg] Error: "..tostring(err))
            currentPhase = "⚠️ Error, retry..."
            currentTimer = "3s"
            task.wait(3)
        end
    end
    currentPhase = "Idle"
    currentTimer = "—"
end

-- ── ESP ──────────────────────────────────────────────────────
local function clearESP()
    for _, v in pairs(espObjs) do pcall(function() v:Destroy() end) end
    espObjs = {}
end

local function makeESP(plr)
    if plr == lp then return end
    local function build()
        local char = plr.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        -- Box
        local box = Instance.new("SelectionBox")
        box.Color3 = Color3.fromRGB(220,40,40)
        box.LineThickness = 0.035
        box.SurfaceTransparency = 0.88
        box.SurfaceColor3 = Color3.fromRGB(220,40,40)
        box.Adornee = char
        box.Parent = Workspace
        table.insert(espObjs, box)

        -- Billboard
        local bb = Instance.new("BillboardGui")
        bb.Name = "ReyvanESP"
        bb.Size = UDim2.new(0,120,0,52)
        bb.StudsOffset = Vector3.new(0,3.5,0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 400
        bb.Parent = hrp
        table.insert(espObjs, bb)

        -- Name
        local nl = Instance.new("TextLabel")
        nl.Size = UDim2.new(1,0,0,18)
        nl.BackgroundTransparency = 1
        nl.Text = plr.DisplayName
        nl.TextColor3 = Color3.fromRGB(255,255,255)
        nl.TextSize = 11
        nl.Font = Enum.Font.GothamBold
        nl.TextStrokeTransparency = 0
        nl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        nl.Parent = bb

        -- HP bar BG
        local hpBG = Instance.new("Frame")
        hpBG.Size = UDim2.new(1,0,0,7)
        hpBG.Position = UDim2.new(0,0,0,20)
        hpBG.BackgroundColor3 = Color3.fromRGB(35,35,35)
        hpBG.BorderSizePixel = 0
        hpBG.Parent = bb
        Instance.new("UICorner",hpBG).CornerRadius = UDim.new(1,0)

        -- HP fill
        local hpF = Instance.new("Frame")
        hpF.BackgroundColor3 = Color3.fromRGB(60,210,80)
        hpF.BorderSizePixel = 0
        hpF.Size = UDim2.new(1,0,1,0)
        hpF.Parent = hpBG
        Instance.new("UICorner",hpF).CornerRadius = UDim.new(1,0)

        -- HP text
        local ht = Instance.new("TextLabel")
        ht.Size = UDim2.new(1,0,0,14)
        ht.Position = UDim2.new(0,0,0,30)
        ht.BackgroundTransparency = 1
        ht.TextColor3 = Color3.fromRGB(190,190,190)
        ht.TextSize = 9
        ht.Font = Enum.Font.Gotham
        ht.TextStrokeTransparency = 0
        ht.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        ht.Parent = bb

        -- Live update
        local conn = RunService.Heartbeat:Connect(function()
            if not char or not char.Parent then
                box:Destroy() bb:Destroy() return
            end
            local hp = math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            hpF.Size = UDim2.new(hp,0,1,0)
            hpF.BackgroundColor3 = hp>.6
                and Color3.fromRGB(60,210,80)
                or hp>.3
                and Color3.fromRGB(220,180,0)
                or Color3.fromRGB(220,40,40)
            ht.Text = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
        end)
        table.insert(espObjs, conn)
    end
    build()
    plr.CharacterAdded:Connect(function() task.wait(1) if espActive then build() end end)
end

local function enableESP()
    clearESP()
    for _,plr in ipairs(Players:GetPlayers()) do pcall(makeESP,plr) end
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(1) if espActive then pcall(makeESP,plr) end
        end)
    end)
end

-- ── GUI ──────────────────────────────────────────────────────
local function formatMoney(n)
    local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)","% 1"):reverse():gsub("^ ","")
    return "$"..s:gsub(" ",".")
end
local function formatTime(s)
    return ("%dh %dm %ds"):format(math.floor(s/3600),math.floor(s%3600/60),math.floor(s%60))
end

-- Remove old GUI
local old = lp.PlayerGui:FindFirstChild("ReyvanGG")
if old then old:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "ReyvanGG"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
SG.Parent = lp.PlayerGui

local W, H = 380, 560
local Win = Instance.new("Frame")
Win.Size = UDim2.new(0,W,0,H)
Win.Position = UDim2.new(0,30,0,30)
Win.BackgroundColor3 = Color3.fromRGB(12,12,12)
Win.BorderSizePixel = 0
Win.ClipsDescendants = true
Win.Active = true
Win.Draggable = not isMobile
Win.Parent = SG
Instance.new("UICorner",Win).CornerRadius = UDim.new(0,12)
local ws = Instance.new("UIStroke",Win) ws.Color=Color3.fromRGB(30,30,30) ws.Thickness=1

-- Mobile drag
if isMobile then
    local drag,ds,dp = false,nil,nil
    Win.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch then drag=true ds=i.Position dp=Win.Position end
    end)
    Win.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch and drag then
            local d=i.Position-ds
            Win.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end)
    Win.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
end

-- ── HEADER ───────────────────────────────────────────────────
local HDR = Instance.new("Frame")
HDR.Size = UDim2.new(1,0,0,44)
HDR.BackgroundColor3 = Color3.fromRGB(8,8,8)
HDR.BorderSizePixel = 0
HDR.Parent = Win

local TL = Instance.new("TextLabel")
TL.Size = UDim2.new(1,-80,1,0)
TL.Position = UDim2.new(0,14,0,0)
TL.BackgroundTransparency = 1
TL.RichText = true
TL.Text = '<b><font color="rgb(255,255,255)">reyvan</font>'
    ..'<font color="rgb(220,40,40)">.gg</font></b>'
    ..'  <font color="rgb(70,70,70)" size="12">South Bronx v6.0</font>'
TL.TextSize = 16
TL.Font = Enum.Font.Gotham
TL.TextXAlignment = Enum.TextXAlignment.Left
TL.Parent = HDR

-- Close button
local CB = Instance.new("TextButton")
CB.Size=UDim2.new(0,26,0,26) CB.Position=UDim2.new(1,-30,0.5,-13)
CB.BackgroundColor3=Color3.fromRGB(220,40,40) CB.BorderSizePixel=0
CB.Text="✕" CB.TextColor3=Color3.fromRGB(255,255,255) CB.TextSize=13
CB.Font=Enum.Font.GothamBold CB.Parent=HDR
Instance.new("UICorner",CB).CornerRadius=UDim.new(1,0)
CB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Minimize button
local MB = Instance.new("TextButton")
MB.Size=UDim2.new(0,26,0,26) MB.Position=UDim2.new(1,-58,0.5,-13)
MB.BackgroundColor3=Color3.fromRGB(28,28,28) MB.BorderSizePixel=0
MB.Text="─" MB.TextColor3=Color3.fromRGB(160,160,160) MB.TextSize=14
MB.Font=Enum.Font.GothamBold MB.Parent=HDR
Instance.new("UICorner",MB).CornerRadius=UDim.new(1,0)

-- Red accent line
local acc=Instance.new("Frame")
acc.Size=UDim2.new(1,0,0,2) acc.Position=UDim2.new(0,0,0,44)
acc.BackgroundColor3=Color3.fromRGB(220,40,40) acc.BorderSizePixel=0 acc.Parent=Win

-- ── CONTENT SCROLL ───────────────────────────────────────────
local CS = Instance.new("ScrollingFrame")
CS.Size = UDim2.new(1,0,0,H-46)
CS.Position = UDim2.new(0,0,0,46)
CS.BackgroundTransparency = 1
CS.BorderSizePixel = 0
CS.ScrollBarThickness = 3
CS.ScrollBarImageColor3 = Color3.fromRGB(220,40,40)
CS.CanvasSize = UDim2.new(0,0,0,900)
CS.Parent = Win

local CSLayout = Instance.new("UIListLayout",CS)
CSLayout.Padding = UDim.new(0,0)
local CSPad = Instance.new("UIPadding",CS)
CSPad.PaddingLeft=UDim.new(0,10) CSPad.PaddingRight=UDim.new(0,10) CSPad.PaddingTop=UDim.new(0,8)

-- Minimize
local mini = false
MB.MouseButton1Click:Connect(function()
    mini = not mini
    CS.Visible = not mini
    Win.Size = mini and UDim2.new(0,W,0,46) or UDim2.new(0,W,0,H)
end)

-- ── HELPER FUNCTIONS ─────────────────────────────────────────
local function sp(h)
    local f=Instance.new("Frame",CS) f.Size=UDim2.new(1,0,0,h or 6)
    f.BackgroundTransparency=1 f.BorderSizePixel=0
end

local function sectionHdr(txt, col)
    sp(4)
    local f=Instance.new("Frame",CS) f.Size=UDim2.new(1,0,0,28) f.BackgroundTransparency=1
    local dot=Instance.new("Frame",f) dot.Size=UDim2.new(0,3,0,14) dot.Position=UDim2.new(0,2,0.5,-7)
    dot.BackgroundColor3=col or Color3.fromRGB(220,40,40) dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local l=Instance.new("TextLabel",f) l.Size=UDim2.new(1,-12,1,0) l.Position=UDim2.new(0,12,0,0)
    l.BackgroundTransparency=1 l.Text=txt l.TextColor3=Color3.fromRGB(180,180,180)
    l.TextSize=11 l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left
end

local function card(h)
    local f=Instance.new("Frame",CS) f.Size=UDim2.new(1,0,0,h or 44)
    f.BackgroundColor3=Color3.fromRGB(20,20,20) f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local s=Instance.new("UIStroke",f) s.Color=Color3.fromRGB(32,32,32) s.Thickness=1
    sp(4)
    return f
end

local function statRow(parent,lbl,initVal,valCol)
    local row=Instance.new("Frame",parent) row.Size=UDim2.new(1,0,0,32)
    row.BackgroundTransparency=1 row.BorderSizePixel=0
    local ll=Instance.new("TextLabel",row) ll.Size=UDim2.new(0.55,0,1,0) ll.Position=UDim2.new(0,10,0,0)
    ll.BackgroundTransparency=1 ll.Text=lbl ll.TextColor3=Color3.fromRGB(80,80,80)
    ll.TextSize=11 ll.Font=Enum.Font.Gotham ll.TextXAlignment=Enum.TextXAlignment.Left
    local vl=Instance.new("TextLabel",row) vl.Size=UDim2.new(0.45,-10,1,0) vl.Position=UDim2.new(0.55,0,0,0)
    vl.BackgroundTransparency=1 vl.Text=initVal vl.TextColor3=valCol or Color3.fromRGB(190,190,190)
    vl.TextSize=11 vl.Font=Enum.Font.GothamBold vl.TextXAlignment=Enum.TextXAlignment.Right
    return vl
end

local function invItem(icon, name, iconBG, initCount)
    local f=card(40)
    local ib=Instance.new("Frame",f) ib.Size=UDim2.new(0,36,0,36) ib.Position=UDim2.new(0,4,0.5,-18)
    ib.BackgroundColor3=iconBG ib.BorderSizePixel=0
    Instance.new("UICorner",ib).CornerRadius=UDim.new(0,7)
    local il=Instance.new("TextLabel",ib) il.Size=UDim2.new(1,0,1,0)
    il.BackgroundTransparency=1 il.Text=icon il.TextSize=18 il.Font=Enum.Font.Gotham il.TextXAlignment=Enum.TextXAlignment.Center
    local nl=Instance.new("TextLabel",f) nl.Size=UDim2.new(0.5,0,1,0) nl.Position=UDim2.new(0,46,0,0)
    nl.BackgroundTransparency=1 nl.Text=name nl.TextColor3=Color3.fromRGB(200,200,200)
    nl.TextSize=12 nl.Font=Enum.Font.GothamBold nl.TextXAlignment=Enum.TextXAlignment.Left
    local cl=Instance.new("TextLabel",f) cl.Size=UDim2.new(0.3,0,1,0) cl.Position=UDim2.new(0.7,-10,0,0)
    cl.BackgroundTransparency=1 cl.Text=tostring(initCount or 0) cl.TextColor3=Color3.fromRGB(220,220,220)
    cl.TextSize=16 cl.Font=Enum.Font.GothamBlack cl.TextXAlignment=Enum.TextXAlignment.Right
    return cl
end

local function togBtn(parent,lbl,def,cb)
    local row=Instance.new("Frame",parent) row.Size=UDim2.new(1,0,0,36)
    row.BackgroundTransparency=1 row.BorderSizePixel=0
    local ll=Instance.new("TextLabel",row) ll.Size=UDim2.new(0.72,0,1,0) ll.Position=UDim2.new(0,10,0,0)
    ll.BackgroundTransparency=1 ll.Text=lbl
    ll.TextColor3=def and Color3.fromRGB(200,200,200) or Color3.fromRGB(75,75,75)
    ll.TextSize=12 ll.Font=Enum.Font.Gotham ll.TextXAlignment=Enum.TextXAlignment.Left ll.TextWrapped=true
    local bg=Instance.new("Frame",row) bg.Size=UDim2.new(0,38,0,20) bg.Position=UDim2.new(1,-42,0.5,-10)
    bg.BackgroundColor3=def and Color3.fromRGB(220,40,40) or Color3.fromRGB(38,38,38) bg.BorderSizePixel=0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)
    local kn=Instance.new("Frame",bg) kn.Size=UDim2.new(0,16,0,16)
    kn.Position=def and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255) kn.BorderSizePixel=0
    Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)
    local hit=Instance.new("TextButton",row) hit.Size=UDim2.new(1,0,1,0) hit.BackgroundTransparency=1 hit.Text=""
    local state=def
    hit.MouseButton1Click:Connect(function()
        state=not state
        local ti=TweenInfo.new(0.12)
        TweenService:Create(bg,ti,{BackgroundColor3=state and Color3.fromRGB(220,40,40) or Color3.fromRGB(38,38,38)}):Play()
        TweenService:Create(kn,ti,{Position=state and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
        ll.TextColor3=state and Color3.fromRGB(200,200,200) or Color3.fromRGB(75,75,75)
        if cb then cb(state) end
    end)
end

-- ══════════════════════════════════════════════
-- SECTION: INVENTORY
-- ══════════════════════════════════════════════
sectionHdr("📦  INVENTORY", Color3.fromRGB(40,140,220))
local waterLbl   = invItem("💧","Water",      Color3.fromRGB(0,130,220), 0)
local sugarLbl   = invItem("🧊","Sugar Block", Color3.fromRGB(180,60,220), 0)
local gelatinLbl = invItem("🍮","Gelatin",     Color3.fromRGB(220,130,0), 0)
local bagLbl     = invItem("👜","Empty Bag",   Color3.fromRGB(60,160,60), 0)

-- ══════════════════════════════════════════════
-- SECTION: AUTO FARM
-- ══════════════════════════════════════════════
sp(2)
sectionHdr("🍡  AUTO FARM MARSHMALLOW", Color3.fromRGB(220,40,40))

-- START / STOP buttons
do
    local f=Instance.new("Frame",CS) f.Size=UDim2.new(1,0,0,44) f.BackgroundTransparency=1
    sp(4)

    local startB=Instance.new("TextButton",f) startB.Size=UDim2.new(0.48,0,1,0)
    startB.BackgroundColor3=Color3.fromRGB(30,150,60) startB.BorderSizePixel=0
    startB.Text="▶  START" startB.TextColor3=Color3.fromRGB(255,255,255)
    startB.TextSize=13 startB.Font=Enum.Font.GothamBold
    Instance.new("UICorner",startB).CornerRadius=UDim.new(0,8)

    local stopB=Instance.new("TextButton",f) stopB.Size=UDim2.new(0.48,0,1,0) stopB.Position=UDim2.new(0.52,0,0,0)
    stopB.BackgroundColor3=Color3.fromRGB(180,30,30) stopB.BorderSizePixel=0
    stopB.Text="■  STOP" stopB.TextColor3=Color3.fromRGB(255,255,255)
    stopB.TextSize=13 stopB.Font=Enum.Font.GothamBold
    Instance.new("UICorner",stopB).CornerRadius=UDim.new(0,8)

    startB.MouseButton1Click:Connect(function()
        if not autoRunning then
            autoRunning = true
            task.spawn(autoFarmLoop)
        end
    end)
    stopB.MouseButton1Click:Connect(function()
        autoRunning = false
    end)

    -- PageUp hotkey PC
    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode == Enum.KeyCode.PageUp then
            if autoRunning then autoRunning=false
            else autoRunning=true task.spawn(autoFarmLoop) end
        end
    end)
end

sp(4)

-- Status card
local statusCard = card(80)
local phaseLblVal  = statRow(statusCard, "Phase",   "Idle",  Color3.fromRGB(220,220,80))
local timerLblVal  = statRow(statusCard, "Timer",   "—",     Color3.fromRGB(100,200,255))
local cycleLblVal  = statRow(statusCard, "Siklus",  "0",     Color3.fromRGB(150,150,255))

-- ══════════════════════════════════════════════
-- SECTION: STATS
-- ══════════════════════════════════════════════
sectionHdr("📊  STATISTIK", Color3.fromRGB(100,100,220))
local statsCard = card(96)
local timeLbl  = statRow(statsCard, "Waktu Farming", "0h 0m 0s", Color3.fromRGB(190,190,190))
local moneyLbl = statRow(statsCard, "Uang Didapat",  "$0",        Color3.fromRGB(60,210,90))

-- Reset counter
sp(4)
local resetF=Instance.new("Frame",CS) resetF.Size=UDim2.new(1,0,0,32) resetF.BackgroundTransparency=1
local resetB=Instance.new("TextButton",resetF) resetB.Size=UDim2.new(1,0,1,0)
resetB.BackgroundColor3=Color3.fromRGB(22,22,22) resetB.BorderSizePixel=0
resetB.Text="🔄  Reset Counter" resetB.TextColor3=Color3.fromRGB(100,100,100)
resetB.TextSize=11 resetB.Font=Enum.Font.GothamBold
Instance.new("UICorner",resetB).CornerRadius=UDim.new(0,7)
resetB.MouseButton1Click:Connect(function()
    moneyGained=0 cycleCount=0 sessionStart=tick()
end)

-- ══════════════════════════════════════════════
-- SECTION: ESP
-- ══════════════════════════════════════════════
sectionHdr("👁  ESP", Color3.fromRGB(80,80,220))
local espCard = card(36)
togBtn(espCard, "Player ESP  (Box + Health Bar + Name)", false, function(s)
    espActive = s
    if s then enableESP() else clearESP() end
end)

-- ══════════════════════════════════════════════
-- SECTION: CARA PAKAI
-- ══════════════════════════════════════════════
sectionHdr("ℹ️  CARA PAKAI", Color3.fromRGB(50,50,50))
local helpCard = card(90)
local ht=Instance.new("TextLabel",helpCard)
ht.Size=UDim2.new(1,-16,1,-8) ht.Position=UDim2.new(0,8,0,4)
ht.BackgroundTransparency=1 ht.TextWrapped=true
ht.Text="1. Beli semua bahan dari NPC secara manual\n2. Taruh di depan Cooking Pot\n3. Klik START atau tekan PageUp\n4. Script akan equip item + interact otomatis\n5. Ulangi terus sampai target tercapai"
ht.TextColor3=Color3.fromRGB(70,70,70) ht.TextSize=10 ht.Font=Enum.Font.Gotham
ht.TextXAlignment=Enum.TextXAlignment.Left ht.TextYAlignment=Enum.TextYAlignment.Top

sp(40)

-- ── LIVE UPDATE LOOP ─────────────────────────────────────────
task.spawn(function()
    while SG.Parent do
        updateInventory()
        waterLbl.Text   = tostring(invCount.Water)
        sugarLbl.Text   = tostring(invCount.Sugar)
        gelatinLbl.Text = tostring(invCount.Gelatin)
        bagLbl.Text     = tostring(invCount.Bag)

        -- Color berdasarkan jumlah
        waterLbl.TextColor3   = invCount.Water>0   and Color3.fromRGB(0,200,255)   or Color3.fromRGB(80,80,80)
        sugarLbl.TextColor3   = invCount.Sugar>0   and Color3.fromRGB(200,80,255)  or Color3.fromRGB(80,80,80)
        gelatinLbl.TextColor3 = invCount.Gelatin>0 and Color3.fromRGB(255,190,0)   or Color3.fromRGB(80,80,80)
        bagLbl.TextColor3     = invCount.Bag>0     and Color3.fromRGB(80,220,80)   or Color3.fromRGB(80,80,80)

        phaseLblVal.Text  = currentPhase
        timerLblVal.Text  = currentTimer
        cycleLblVal.Text  = tostring(cycleCount)
        timeLbl.Text      = formatTime(tick()-sessionStart)
        moneyLbl.Text     = formatMoney(moneyGained)
        moneyLbl.TextColor3 = moneyGained>0 and Color3.fromRGB(60,210,90) or Color3.fromRGB(80,80,80)

        -- Status color
        if autoRunning then
            phaseLblVal.TextColor3 = Color3.fromRGB(100,255,100)
        else
            phaseLblVal.TextColor3 = Color3.fromRGB(220,220,80)
        end

        -- Update canvas size
        CS.CanvasSize = UDim2.new(0,0,0, CSLayout.AbsoluteContentSize.Y + 20)

        task.wait(0.5)
    end
end)

print("[reyvan.gg v6.0] Loaded! Klik START atau PageUp untuk mulai.")
print("[reyvan.gg] Pastikan Water/Sugar/Gelatin/Bag ada di Backpack sebelum start!")
