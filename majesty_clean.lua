-- ========== MAJESTY STORE v8.3.0 ==========
-- TP JALAN KAKI  : Moonwalk + PlatformStand + Anchor per step (anti ragdoll, tembus tembok)
-- TP KENDARAAN   : Anchor + PivotTo + zero velocity + Unanchor (anti void)
-- AUTO RANGE     : Step & delay dihitung otomatis dari jarak, tidak ada setting manual

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer

repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

-- ========== VARIABLES ==========
local AutoMS_Running   = false
local espEnabled       = false
local espCache         = {}
local boxPadding       = 4
local espItemColor     = Color3.fromRGB(255, 220, 50)
local ESP_INTERVAL     = 0.05
local _espAccum        = 0
local espMaxDist       = 100
local espBoxColor      = Color3.fromRGB(0, 255, 136)
local espNameColor     = Color3.fromRGB(255, 255, 255)




-- ========== SAFE MODE STATE ==========
local safeMode        = false   -- toggle on/off
local safeModeActive  = false   -- sedang dalam proses safe escape
local lastHealth      = 100     -- track HP untuk detect hit
local safeModeStatusLbl = nil   -- ref ke label UI


-- ========== AUTO SELL STATE ==========
local autoSell_UI       = false
local asSelling         = false
local asSoldCount       = 0
local sellStatusLbl_ref = nil
local sellItemLbl_ref   = nil
local sellOrder_UI      = {"Small Marshmallow Bag","Medium Marshmallow Bag","Large Marshmallow Bag"}

-- ========== GUI ==========
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
mainFrame.Size = UDim2.new(0, 480, 0, 390)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -195)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true; mainFrame.Draggable = true; mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mkCorner(mainFrame, 6); mkStroke(mainFrame, 1, C.border)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36); titleBar.BackgroundColor3 = C.topbar
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
versionLabel.BackgroundTransparency = 1; versionLabel.Text = "v8.3.0 | South Bronx"
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
    if minKeyType == "KeyCode" and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == minKeyCode then doMinimize() end
    if minKeyType == "MouseButton" and minKeyMBtn and input.UserInputType == minKeyMBtn then doMinimize() end
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

local pageAuto = makePage()
local pageEsp  = makePage()




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

-- ========== PAGE: AUTO MS ==========
local statusValue, phaseValue, timerValue, startBtn, stopBtn
local waterCount, gelatinCount, sugarCount, bagCount
local sellStatusLbl_ref, sellCountLbl_ref

do
    sectionTitle(pageAuto, "AUTO MARSHMALLOW", 8)
    local sc=makeCard(pageAuto,38,44); makeLabel(sc,"STATUS",12,0,80,44,10,C.subtext)
    statusValue=makeLabel(sc,"OFF",90,0,200,44,15,C.red)
    local pc=makeCard(pageAuto,90,44); makeLabel(pc,"PHASE",12,0,80,44,10,C.subtext)
    phaseValue=makeLabel(pc,"Water",90,0,200,44,14,C.accent2)
    local tc=makeCard(pageAuto,142,44); makeLabel(tc,"TIMER",12,0,80,44,10,C.subtext)
    timerValue=makeLabel(tc,"0s",90,0,200,44,14,C.yellow)
    local ic=makeCard(pageAuto,194,28)
    makeLabel(ic,"Delay 1s antara Sugar - Gelatin  |  PageUp = toggle",10,0,400,28,10,C.subtext)
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
    safeTogBtn.Size = UDim2.new(1,-20,0,36)
    safeTogBtn.Position = UDim2.new(0,10,0,548)
    safeTogBtn.BackgroundColor3 = C.card
    safeTogBtn.Text = "SAFE MODE : OFF"
    safeTogBtn.TextColor3 = C.red
    safeTogBtn.Font = Enum.Font.GothamBold
    safeTogBtn.TextSize = 13
    safeTogBtn.BorderSizePixel = 0
    safeTogBtn.Parent = pageAuto
    mkCorner(safeTogBtn,5); mkStroke(safeTogBtn,1,C.border)

    local smCard1 = makeCard(pageAuto,592,44)
    makeLabel(smCard1,"STATUS",12,0,80,44,10,C.subtext)
    safeModeStatusLbl = makeLabel(smCard1,"OFF",90,0,300,44,13,C.red)

    local smInfoCard = makeCard(pageAuto,644,22)
    makeLabel(smInfoCard,"Detect hit saat Auto MS → VTP ke koordinat Safe",10,0,430,22,9,C.subtext)

    safeTogBtn.MouseButton1Click:Connect(function()
        safeMode = not safeMode
        if safeMode then
            safeTogBtn.Text = "SAFE MODE : ON"; safeTogBtn.TextColor3 = C.accent
            mkStroke(safeTogBtn,1,C.accent)
            safeModeStatusLbl.Text = "STANDBY"; safeModeStatusLbl.TextColor3 = C.accent
            -- Reset lastHealth ke HP saat ini
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then lastHealth = hum.Health end
            print("[SAFE MODE] Aktif - memantau HP saat Auto MS berjalan")
        else
            safeMode = false; safeModeActive = false
            safeTogBtn.Text = "SAFE MODE : OFF"; safeTogBtn.TextColor3 = C.red
            mkStroke(safeTogBtn,1,C.border)
            safeModeStatusLbl.Text = "OFF"; safeModeStatusLbl.TextColor3 = C.red
            print("[SAFE MODE] Dimatikan")
        end
    end)

    sectionTitle(pageAuto,"AUTO SELL",682)

    local sellTogBtn = Instance.new("TextButton")
    sellTogBtn.Size = UDim2.new(1,-20,0,36)
    sellTogBtn.Position = UDim2.new(0,10,0,708)
    sellTogBtn.BackgroundColor3 = C.card
    sellTogBtn.Text = "AUTO SELL : OFF"
    sellTogBtn.TextColor3 = C.red
    sellTogBtn.Font = Enum.Font.GothamBold
    sellTogBtn.TextSize = 13
    sellTogBtn.BorderSizePixel = 0
    sellTogBtn.Parent = pageAuto
    mkCorner(sellTogBtn,5); mkStroke(sellTogBtn,1,C.border)

    local ssc = makeCard(pageAuto,752,44); makeLabel(ssc,"SELL",12,0,80,44,10,C.subtext)
    sellStatusLbl_ref = makeLabel(ssc,"OFF",90,0,200,44,13,C.red)
    local sic = makeCard(pageAuto,804,44); makeLabel(sic,"ITEM",12,0,80,44,10,C.subtext)
    sellItemLbl_ref = makeLabel(sic,"-",90,0,280,44,13,C.text)
    local sfc = makeCard(pageAuto,856,44); makeLabel(sfc,"FASE",12,0,80,44,10,C.subtext)
    local asPhaseLbl = makeLabel(sfc,"Idle",90,0,280,44,12,C.accent2)
    local stc = makeCard(pageAuto,908,40); makeLabel(stc,"TERJUAL",12,0,80,40,10,C.subtext)
    local asSoldLbl  = makeLabel(stc,"0",90,0,200,40,13,C.yellow)

    sellTogBtn.MouseButton1Click:Connect(function()
        autoSell_UI = not autoSell_UI
        if autoSell_UI then
            sellTogBtn.Text = "AUTO SELL : ON"; sellTogBtn.TextColor3 = C.accent
            mkStroke(sellTogBtn, 1, C.accent)
            sellStatusLbl_ref.Text = "ON"; sellStatusLbl_ref.TextColor3 = C.accent
            asPhaseLbl.Text = "Menunggu item..."; asPhaseLbl.TextColor3 = C.yellow
            print("[AUTO SELL] Aktif")
        else
            autoSell_UI = false; asSelling = false
            sellTogBtn.Text = "AUTO SELL : OFF"; sellTogBtn.TextColor3 = C.red
            mkStroke(sellTogBtn, 1, C.border)
            sellStatusLbl_ref.Text = "OFF"; sellStatusLbl_ref.TextColor3 = C.red
            sellItemLbl_ref.Text = "-"
            asPhaseLbl.Text = "Idle"; asPhaseLbl.TextColor3 = C.subtext
            print("[AUTO SELL] Dimatikan")
        end
    end)
    -- ========== BUY (from arul) ==========
    sectionTitle(pageAuto,"BUY BAHAN",964)
    local buyFullWater   = 1
    local buyFullSugar   = 1
    local buyFullGelatin = 1
    local autoBuyFull    = false

    -- Slider row helper (arul style, adapted to MAJESTY card GUI)
    local function makeSliderRow(yPos,label,getVal,onMinus,onPlus)
        local card=makeCard(pageAuto,yPos,50)
        makeLabel(card,label,10,4,160,20,12,C.text)
        local valLbl=Instance.new("TextLabel"); valLbl.Size=UDim2.new(0,50,0,20); valLbl.Position=UDim2.new(1,-58,0,4)
        valLbl.BackgroundTransparency=1; valLbl.Text=tostring(getVal()); valLbl.TextColor3=C.yellow
        valLbl.Font=Enum.Font.Gotham; valLbl.TextSize=13; valLbl.TextXAlignment=Enum.TextXAlignment.Right; valLbl.Parent=card
        local track=Instance.new("Frame"); track.Size=UDim2.new(1,-20,0,8); track.Position=UDim2.new(0,10,1,-16)
        track.BackgroundColor3=Color3.fromRGB(40,40,60); track.BorderSizePixel=0; track.Parent=card; mkCorner(track,4)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(getVal()/99,0,1,0); fill.BackgroundColor3=C.accent2
        fill.BorderSizePixel=0; fill.Parent=track; mkCorner(fill,4)
        local knob=Instance.new("TextButton"); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(getVal()/99,-7,0.5,-7)
        knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.Text=""; knob.BorderSizePixel=0; knob.Parent=track; mkCorner(knob,7)
        local function updateSlider(inputX)
            local ap=track.AbsolutePosition; local as=track.AbsoluteSize
            local r=math.clamp((inputX-ap.X)/as.X,0,1)
            local newVal=math.floor(r*99+0.5)
            local cur=getVal(); local diff=newVal-cur
            if diff>0 then for _=1,diff do onPlus() end elseif diff<0 then for _=1,math.abs(diff) do onMinus() end end
            local fv=getVal(); valLbl.Text=tostring(fv)
            fill.Size=UDim2.new(fv/99,0,1,0); knob.Position=UDim2.new(fv/99,-7,0.5,-7)
        end
        local drg=false; knob.MouseButton1Down:Connect(function() drg=true end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drg=false end end)
        UserInputService.InputChanged:Connect(function(i)
            if drg and i.UserInputType==Enum.UserInputType.MouseMovement then updateSlider(i.Position.X) end
        end)
        knob.MouseButton1Click:Connect(function() end) -- absorb
    end

    makeSliderRow(990,"Water",
        function() return buyFullWater end,
        function() buyFullWater=math.max(0,buyFullWater-1) end,
        function() buyFullWater=math.min(99,buyFullWater+1) end)
    makeSliderRow(1106,"Sugar Block Bag",
        function() return buyFullSugar end,
        function() buyFullSugar=math.max(0,buyFullSugar-1) end,
        function() buyFullSugar=math.min(99,buyFullSugar+1) end)
    makeSliderRow(1048,"Gelatin",
        function() return buyFullGelatin end,
        function() buyFullGelatin=math.max(0,buyFullGelatin-1) end,
        function() buyFullGelatin=math.min(99,buyFullGelatin+1) end)

    local buyTogBtn=Instance.new("TextButton"); buyTogBtn.Size=UDim2.new(1,-20,0,36); buyTogBtn.Position=UDim2.new(0,10,0,1164)
    buyTogBtn.BackgroundColor3=C.card; buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
    buyTogBtn.Font=Enum.Font.Gotham; buyTogBtn.TextSize=13; buyTogBtn.BorderSizePixel=0; buyTogBtn.Parent=pageAuto
    mkCorner(buyTogBtn,5); mkStroke(buyTogBtn,1,C.border)

    local bsc=makeCard(pageAuto,1208,44); makeLabel(bsc,"STATUS",12,0,80,44,10,C.subtext)
    local bsl=makeLabel(bsc,"OFF",90,0,180,44,13,C.red)
    local bpc=makeCard(pageAuto,1260,44); makeLabel(bpc,"PHASE",12,0,80,44,10,C.subtext)
    local bpl=makeLabel(bpc,"Idle",90,0,280,44,13,C.accent2)
    local bicc=makeCard(pageAuto,1312,44); makeLabel(bicc,"ITEM",12,0,80,44,10,C.subtext)
    local bil=makeLabel(bicc,"--",90,0,280,44,13,C.subtext)

    -- guiInset for click
    local guiInsetBuy = game:GetService("GuiService"):GetGuiInset()
    local VirtualInputManager2 = game:GetService("VirtualInputManager")

    local function clickGuiBtnFull(btn)
        if not btn then return end
        local pos=btn.AbsolutePosition; local size=btn.AbsoluteSize
        local cx=pos.X+size.X/2; local cy=pos.Y+size.Y/2+guiInsetBuy.Y
        VirtualInputManager2:SendMouseButtonEvent(cx,cy,0,true,game,0); task.wait(0.05)
        VirtualInputManager2:SendMouseButtonEvent(cx,cy,0,false,game,0)
    end

    local function findShopItem(scrollFrame, targetName)
        for _,item in ipairs(scrollFrame:GetChildren()) do
            if item.Name~="PurchaseableItem" then continue end
            local itemLabel=item:FindFirstChild("Item")
            if itemLabel and itemLabel:IsA("TextLabel") then
                local text=itemLabel.Text:match("^%s*(.-)%s*$")
                if text==targetName then return item end
            end
        end
        return nil
    end

    -- TP ke NPC Lamont untuk buy
    local LAMONT_X,LAMONT_Y,LAMONT_Z=510.4306640625,3.587210178375244,597.6616821289062

    buyTogBtn.MouseButton1Click:Connect(function()
        if autoBuyFull then
            autoBuyFull=false
            buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
            bsl.Text="OFF"; bsl.TextColor3=C.red; bpl.Text="Idle"; bil.Text="--"
            return
        end
        autoBuyFull=true
        buyTogBtn.Text="BUY : ON"; buyTogBtn.TextColor3=C.accent
        bsl.Text="RUNNING"; bsl.TextColor3=C.accent

        task.spawn(function()
            -- TP ke Lamont
            bpl.Text="TP ke NPC..."; bpl.TextColor3=C.accent2
            local char2=LocalPlayer.Character
            local hrp2=char2 and char2:FindFirstChild("HumanoidRootPart")
            if hrp2 then hrp2.CFrame=CFrame.new(LAMONT_X,LAMONT_Y+2,LAMONT_Z) end
            task.wait(2)

            bpl.Text="Cari NPC..."
            local prompt2=nil
            for _,obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local part=obj.Parent
                    if part and part:IsA("BasePart") then
                        local mdl=part:FindFirstAncestorWhichIsA("Model")
                        if mdl and mdl.Name:lower():find("lamont") then prompt2=obj; break end
                    end
                end
            end
            if not prompt2 then
                bsl.Text="NPC tidak ketemu!"; bsl.TextColor3=C.red
                task.wait(2); autoBuyFull=false
                buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
                bsl.Text="OFF"; bsl.TextColor3=C.red; bpl.Text="Idle"
                return
            end

            bpl.Text="Interact NPC..."
            fireproximityprompt(prompt2)

            local pg2=LocalPlayer.PlayerGui
            local shopOpened=false; local t2=0
            while t2<8 and not shopOpened do
                task.wait(0.2); t2=t2+0.2
                local shopCheck=pg2:FindFirstChild("Shop")
                local mainCheck=shopCheck and shopCheck:FindFirstChild("Main")
                local scrollCheck=mainCheck and mainCheck:FindFirstChild("ScrollingFrame")
                if scrollCheck then
                    for _,item in ipairs(scrollCheck:GetChildren()) do
                        if item.Name=="PurchaseableItem" then shopOpened=true; break end
                    end
                end
                if not shopOpened then
                    local dlg=pg2:FindFirstChild("DialogueUI")
                    local mf=dlg and dlg:FindFirstChild("MainFrame")
                    local fc=mf and mf:FindFirstChild("FirstChoice")
                    if fc and fc.Visible and fc.Text~="" and not fc.Text:lower():find("nevermind") then
                        bpl.Text="Klik dialog..."
                        local pos2=fc.AbsolutePosition; local sz2=fc.AbsoluteSize
                        VirtualInputManager2:SendMouseButtonEvent(pos2.X+sz2.X/2,pos2.Y+sz2.Y/2,0,true,game,0); task.wait(0.1)
                        VirtualInputManager2:SendMouseButtonEvent(pos2.X+sz2.X/2,pos2.Y+sz2.Y/2,0,false,game,0); task.wait(1)
                    end
                end
            end

            if not shopOpened then
                bsl.Text="Gagal buka shop!"; bsl.TextColor3=C.red
                task.wait(2); autoBuyFull=false
                buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
                bsl.Text="OFF"; bsl.TextColor3=C.red; bpl.Text="Idle"
                return
            end

            bpl.Text="Beli item..."
            local shop3=pg2:FindFirstChild("Shop")
            local mainShop3=shop3 and shop3:FindFirstChild("Main")
            local scrollFrame3=mainShop3 and mainShop3:FindFirstChild("ScrollingFrame")

            if scrollFrame3 then
                local buyList={
                    {name="Water",           amount=buyFullWater,   color=C.accent2},
                    {name="Sugar Block Bag", amount=buyFullSugar,   color=C.yellow},
                    {name="Gelatin",         amount=buyFullGelatin, color=C.accent},
                }
                for _,entry in ipairs(buyList) do
                    if not autoBuyFull then break end
                    if entry.amount<=0 then continue end
                    local itemBtn=findShopItem(scrollFrame3,entry.name)
                    if itemBtn then
                        for ii=1,entry.amount do
                            if not autoBuyFull then break end
                            bpl.Text="Beli item"; bil.Text=entry.name.." ("..ii.."/"..entry.amount..")"; bil.TextColor3=entry.color
                            clickGuiBtnFull(itemBtn); task.wait(0.4)
                        end
                    end
                end
                local exitBtn=mainShop3:FindFirstChild("Exit")
                if exitBtn then clickGuiBtnFull(exitBtn) end
            end

            task.wait(0.5)
            bsl.Text="SELESAI"; bsl.TextColor3=C.accent
            bpl.Text="Done"; bil.Text="Done ✅"; bil.TextColor3=C.accent
            task.wait(2)
            autoBuyFull=false
            buyTogBtn.Text="BUY : OFF"; buyTogBtn.TextColor3=C.red
            bsl.Text="OFF"; bsl.TextColor3=C.red; bpl.Text="Idle"; bil.Text="--"; bil.TextColor3=C.subtext
        end)
    end)

    pageAuto.CanvasSize=UDim2.new(0,0,0,1376)
end

-- ========== CREATE ESP (global scope agar bisa diakses render loop) ==========
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

-- Langsung buat ESP untuk semua player yang sudah ada saat script dijalankan
-- (akan disembunyikan sampai ESP di-enable, karena Visible=false by default)
for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then createESP(plr) end
end

-- Auto create/remove saat player join/leave
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        -- Tunggu karakter spawn
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if espEnabled then createESP(p) end
        end)
        if espEnabled then createESP(p) end
    end
end)
Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

-- ========== PAGE: ESP ==========
do
    sectionTitle(pageEsp,"ESP",8)
    local etb=Instance.new("TextButton"); etb.Size=UDim2.new(1,-20,0,34); etb.Position=UDim2.new(0,10,0,34)
    etb.BackgroundColor3=C.card; etb.Text="Player ESP : OFF"; etb.TextColor3=C.red
    etb.Font=Enum.Font.GothamBold; etb.TextSize=13; etb.BorderSizePixel=0; etb.Parent=pageEsp
    mkCorner(etb,5); mkStroke(etb,1,C.border)
    local eir=makeCard(pageEsp,76,24)
    makeLabel(eir,"Box  |  Username  |  HP Bar  |  Item Held  |  Distance",10,0,400,24,10,C.subtext)
    etb.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
            etb.Text="Player ESP : ON"; etb.TextColor3=C.accent
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        else
            etb.Text="Player ESP : OFF"; etb.TextColor3=C.red
            for _, drawings in pairs(espCache) do
                for _, o in pairs(drawings) do
                    pcall(function() o.Visible = false end)
                end
            end
        end
    end)


    sectionTitle(pageEsp,"ESP DISTANCE",110)
    local espDistCard = makeCard(pageEsp,134,44)
    makeLabel(espDistCard,"Max Distance",12,0,120,44,10,C.subtext)
    local espDistLbl = Instance.new("TextLabel")
    espDistLbl.Size=UDim2.new(0,60,1,0); espDistLbl.Position=UDim2.new(1,-68,0,0)
    espDistLbl.BackgroundTransparency=1; espDistLbl.Text=tostring(espMaxDist).."m"
    espDistLbl.TextColor3=C.yellow; espDistLbl.Font=Enum.Font.GothamBold
    espDistLbl.TextSize=12; espDistLbl.TextXAlignment=Enum.TextXAlignment.Right; espDistLbl.Parent=espDistCard
    local espDistTrack=Instance.new("Frame"); espDistTrack.Size=UDim2.new(1,-20,0,6); espDistTrack.Position=UDim2.new(0,10,1,-14)
    espDistTrack.BackgroundColor3=C.border; espDistTrack.BorderSizePixel=0; espDistTrack.Parent=espDistCard; mkCorner(espDistTrack,3)
    local espDistFill=Instance.new("Frame"); espDistFill.Size=UDim2.new(espMaxDist/1000,0,1,0)
    espDistFill.BackgroundColor3=C.accent2; espDistFill.BorderSizePixel=0; espDistFill.Parent=espDistTrack; mkCorner(espDistFill,3)
    local espDistKnob=Instance.new("TextButton"); espDistKnob.Size=UDim2.new(0,12,0,12); espDistKnob.Position=UDim2.new(espMaxDist/1000,-6,0.5,-6)
    espDistKnob.BackgroundColor3=Color3.fromRGB(255,255,255); espDistKnob.Text=""; espDistKnob.BorderSizePixel=0; espDistKnob.Parent=espDistTrack; mkCorner(espDistKnob,6)
    local espDistDrag=false; espDistKnob.MouseButton1Down:Connect(function() espDistDrag=true end)
    UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then espDistDrag=false end end)
    UserInputService.InputChanged:Connect(function(inp)
        if espDistDrag and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local ap=espDistTrack.AbsolutePosition; local as=espDistTrack.AbsoluteSize
            local r=math.clamp((inp.Position.X-ap.X)/as.X,0,1)
            espMaxDist=math.floor(10+r*990)
            espDistFill.Size=UDim2.new(r,0,1,0); espDistKnob.Position=UDim2.new(r,-6,0.5,-6)
            espDistLbl.Text=tostring(espMaxDist).."m"
        end
    end)
    pageEsp.CanvasSize=UDim2.new(0,0,0,192)
end
-- ========== BOTTOM NAV ==========
local tabDefs={{label="AUTO MS",page=pageAuto},{label="ESP",page=pageEsp}}
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

-- ========== INVENTORY TRACKER ==========
local function updateInventory()
    pcall(function()
        local w,g,s,b=0,0,0,0
        local function checkP(parent) if not parent then return end
            for _,tool in pairs(parent:GetChildren()) do if tool:IsA("Tool") then
                local n=string.lower(tool.Name)
                if n:find("water") then w=w+1 elseif n:find("gelatin") or n:find("gel") then g=g+1 elseif n:find("sugar") or n:find("block") then s=s+1 elseif n:find("bag") or n:find("empty") then b=b+1 end
            end end
        end
        checkP(LocalPlayer:FindFirstChild("Backpack")); checkP(LocalPlayer.Character)
        waterCount.Text=tostring(w); gelatinCount.Text=tostring(g); sugarCount.Text=tostring(s); bagCount.Text=tostring(b)
        waterCount.TextColor3=w>0 and Color3.fromRGB(56,189,248) or C.subtext
        gelatinCount.TextColor3=g>0 and Color3.fromRGB(251,146,60) or C.subtext
        sugarCount.TextColor3=s>0 and Color3.fromRGB(192,132,252) or C.subtext
        bagCount.TextColor3=b>0 and Color3.fromRGB(74,222,128) or C.subtext
    end)
end

-- ========== AUTO MS ==========
local function interact()
    pcall(function() local vim=game:GetService("VirtualInputManager"); vim:SendKeyEvent(true,Enum.KeyCode.E,false,game); task.wait(0.12); vim:SendKeyEvent(false,Enum.KeyCode.E,false,game) end)
    pcall(function() if keypress then keypress(0x45) end end); task.wait(0.12); pcall(function() if keyrelease then keyrelease(0x45) end end); task.wait(0.1)
end
local function holdItem(n)
    pcall(function() for _,t in pairs(LocalPlayer.Backpack:GetChildren()) do if t:IsA("Tool") and string.find(string.lower(t.Name),string.lower(n)) then t.Parent=LocalPlayer.Character; task.wait(0.2); return end end end)
end
local function lookAt(n)
    pcall(function()
        local char=LocalPlayer.Character; if not char then return end; local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
        for _,obj in pairs(Workspace:GetDescendants()) do if (obj:IsA("Part") or obj:IsA("MeshPart")) and string.find(string.lower(obj.Name),string.lower(n)) then if (root.Position-obj.Position).Magnitude<15 then root.CFrame=CFrame.lookAt(root.Position,Vector3.new(obj.Position.X,root.Position.Y,obj.Position.Z)); return end end end
    end)
end
local function autoMSLoop()
    while AutoMS_Running do
        local ok=pcall(function()
            statusValue.Text="RUNNING";statusValue.TextColor3=C.accent; phaseValue.Text="Water";timerValue.Text="0s"
            holdItem("water");lookAt("water");task.wait(0.3);interact();updateInventory()
            for i=1,20 do if not AutoMS_Running then return end; timerValue.Text=i.."/20s";updateInventory();task.wait(1) end
            phaseValue.Text="Sugar";holdItem("sugar");lookAt("sugar");task.wait(0.3);interact();updateInventory()
            phaseValue.Text="Delay 1s";timerValue.Text="1s";task.wait(1);updateInventory()
            phaseValue.Text="Gelatin";holdItem("gelatin");lookAt("gelatin");task.wait(0.3);interact();updateInventory()
            for i=1,45 do if not AutoMS_Running then return end; phaseValue.Text="Ferment";timerValue.Text=i.."/45s";updateInventory();task.wait(1) end
            phaseValue.Text="Bag";holdItem("bag");lookAt("bag");task.wait(0.3);interact();updateInventory()
            phaseValue.Text="Complete";timerValue.Text="Done";task.wait(2);updateInventory()
        end)
        if not ok then statusValue.Text="ERROR";statusValue.TextColor3=C.red;task.wait(2) end
    end
    statusValue.Text="OFF";statusValue.TextColor3=C.red;phaseValue.Text="Water";timerValue.Text="0s"
end


-- ========== SAFE MODE LOGIC ==========

-- Fungsi TP ke Safe (standalone, tidak bergantung scope VTP)
local SAFE_X = 120.85433197021484
local SAFE_Y = 4.297231197357178
local SAFE_Z = -587.6337280273438

local function tpToSafe()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Coba geser kendaraan jika sedang naik
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    local seat = hum2 and hum2.SeatPart
    if seat then
        local vModel = seat:FindFirstAncestorWhichIsA("Model")
        if vModel and vModel.PrimaryPart then
            local seatOff = vModel.PrimaryPart.CFrame:Inverse() * seat.CFrame
            vModel:SetPrimaryPartCFrame(CFrame.new(SAFE_X, SAFE_Y + 2, SAFE_Z) * seatOff:Inverse())
            return
        end
    end
    hrp.CFrame = CFrame.new(SAFE_X, SAFE_Y + 2, SAFE_Z)
end

-- Health monitor: EVENT-BASED via HealthChanged (reaksi instan saat kena tembak)
local safeConn = nil  -- koneksi HealthChanged aktif

local function triggerSafeEscape(newHP, maxHP)
    if not safeMode or not AutoMS_Running then return end
    if safeModeActive then return end

    local dmg = math.floor(lastHealth - newHP)
    if dmg <= 0 then lastHealth = newHP; return end  -- HP naik / sama, bukan hit

    -- REAKSI INSTAN: eksekusi tanpa delay
    safeModeActive = true
    lastHealth = newHP

    -- Update UI
    if safeModeStatusLbl then
        safeModeStatusLbl.Text = "HIT -"..dmg.."HP! KABUR..."
        safeModeStatusLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
    end
    if statusValue then statusValue.Text = "SAFE!"; statusValue.TextColor3 = Color3.fromRGB(255, 60, 60) end
    if phaseValue  then phaseValue.Text  = "Kabur..." end
    print("[SAFE MODE] Kena hit "..dmg.."HP → TP instan!")

    -- Stop Auto MS
    AutoMS_Running = false

    -- TP INSTAN ke Safe (tanpa delay apapun)
    tpToSafe()

    -- Update UI setelah TP
    task.spawn(function()
        task.wait(0.5)
        if safeModeStatusLbl then
            safeModeStatusLbl.Text = "SELAMAT"
            safeModeStatusLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
        end
        if statusValue then statusValue.Text = "SAFE ✓"; statusValue.TextColor3 = Color3.fromRGB(0, 255, 136) end
        if phaseValue  then phaseValue.Text  = "Idle" end
        print("[SAFE MODE] Berhasil TP ke Safe")
        task.wait(1.5)  -- cooldown singkat
        local char2 = LocalPlayer.Character
        local hum2  = char2 and char2:FindFirstChildOfClass("Humanoid")
        if hum2 then lastHealth = hum2.Health end
        safeModeActive = false
        if safeModeStatusLbl then
            safeModeStatusLbl.Text = "STANDBY"
            safeModeStatusLbl.TextColor3 = Color3.fromRGB(0, 255, 136)
        end
    end)
end

-- Hook HealthChanged ke karakter saat ini dan setiap respawn
local function hookSafeMode(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    -- Reset lastHealth ke HP saat karakter spawn
    lastHealth = hum.Health
    -- Disconnect koneksi lama jika ada
    if safeConn then safeConn:Disconnect() end
    -- Connect event HealthChanged — trigger INSTAN saat HP berubah
    safeConn = hum.HealthChanged:Connect(function(newHP)
        triggerSafeEscape(newHP, hum.MaxHealth)
    end)
end

-- Hook ke karakter saat ini
if LocalPlayer.Character then task.spawn(function() hookSafeMode(LocalPlayer.Character) end) end
-- Hook setiap respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.spawn(function() hookSafeMode(char) end)
end)

-- ========== AUTO SELL ==========

local function countMSItem(name)
    local count = 0
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if bp   then for _,t in pairs(bp:GetChildren())   do if t:IsA("Tool") and t.Name == name then count += 1 end end end
    if char then for _,t in pairs(char:GetChildren()) do if t:IsA("Tool") and t.Name == name then count += 1 end end end
    return count
end

local function equipMSItem(name)
    local char = LocalPlayer.Character; if not char then return false end
    local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return false end
    for _, t in pairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name == name then return true end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack"); if not bp then return false end
    for _, t in pairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name == name then
            local ok = pcall(function() hum:EquipTool(t) end)
            if not ok then pcall(function() t.Parent = char end) end
            task.wait(0.3)
            return true
        end
    end
    return false
end

local function findSellPrompt(pos, radius)
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local part = obj.Parent
            while part and not part:IsA("BasePart") and not part:IsA("Model") do
                part = part.Parent
            end
            if part then
                local partPos
                if part:IsA("BasePart") then
                    partPos = part.Position
                elseif part:IsA("Model") and part.PrimaryPart then
                    partPos = part.PrimaryPart.Position
                elseif part:IsA("Model") then
                    for _, child in pairs(part:GetChildren()) do
                        if child:IsA("BasePart") then partPos = child.Position; break end
                    end
                end
                if partPos then
                    local dist = (partPos - pos).Magnitude
                    if dist < radius and dist < bestDist then
                        bestDist = dist; best = obj
                    end
                end
            end
        end
    end
    return best, bestDist
end

local function faceTowards(targetPos)
    pcall(function()
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
    end)
end

task.spawn(function()
    while true do
        task.wait(0.4)
        if not autoSell_UI or asSelling then continue end

        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not hrp or hum.Health <= 0 then continue end

        local targetItem = nil
        for _, name in ipairs(sellOrder_UI) do
            if countMSItem(name) > 0 then targetItem = name; break end
        end
        if not targetItem then
            if sellItemLbl_ref   then sellItemLbl_ref.Text   = "-" end
            if sellStatusLbl_ref then sellStatusLbl_ref.Text = "MENUNGGU"; sellStatusLbl_ref.TextColor3 = C.yellow end
            if asPhaseLbl        then asPhaseLbl.Text = "Tidak ada item"; asPhaseLbl.TextColor3 = C.subtext end
            continue
        end

        local prompt, dist = findSellPrompt(hrp.Position, 20)
        if not prompt then
            if sellItemLbl_ref   then sellItemLbl_ref.Text   = targetItem end
            if sellStatusLbl_ref then sellStatusLbl_ref.Text = "DEKATI NPC"; sellStatusLbl_ref.TextColor3 = C.subtext end
            if asPhaseLbl        then asPhaseLbl.Text = "Cari NPC jual..."; asPhaseLbl.TextColor3 = C.subtext end
            continue
        end

        asSelling = true
        if sellItemLbl_ref   then sellItemLbl_ref.Text   = targetItem end
        if sellStatusLbl_ref then sellStatusLbl_ref.Text = "EQUIP..."; sellStatusLbl_ref.TextColor3 = C.accent end
        if asPhaseLbl        then asPhaseLbl.Text = "Equip item..."; asPhaseLbl.TextColor3 = C.accent end

        equipMSItem(targetItem)

        local promptPart = prompt.Parent
        if promptPart and promptPart:IsA("BasePart") then faceTowards(promptPart.Position) end
        task.wait(0.2)

        if sellStatusLbl_ref then sellStatusLbl_ref.Text = "MENJUAL..." end
        if asPhaseLbl        then asPhaseLbl.Text = "Menjual..." end

        local ok1 = pcall(fireproximityprompt, prompt)
        if not ok1 then interact() end
        task.wait(0.5)

        if countMSItem(targetItem) == 0 then
            asSoldCount += 1
            if asSoldLbl then asSoldLbl.Text = tostring(asSoldCount) end
        end

        if autoSell_UI then
            if sellStatusLbl_ref then sellStatusLbl_ref.Text = "ON"; sellStatusLbl_ref.TextColor3 = C.accent end
            if asPhaseLbl        then asPhaseLbl.Text = "Siap"; asPhaseLbl.TextColor3 = C.accent end
        end
        asSelling = false
    end
end)
-- ========== BUTTON EVENTS ==========
startBtn.MouseButton1Click:Connect(function() if not AutoMS_Running then AutoMS_Running=true;statusValue.Text="STARTING";statusValue.TextColor3=C.yellow;task.spawn(autoMSLoop) end end)
stopBtn.MouseButton1Click:Connect(function() AutoMS_Running=false;statusValue.Text="OFF";statusValue.TextColor3=C.red;phaseValue.Text="Water";timerValue.Text="0s" end)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.PageUp then
        if AutoMS_Running then AutoMS_Running=false;statusValue.Text="OFF";statusValue.TextColor3=C.red;phaseValue.Text="Water";timerValue.Text="0s"
        else AutoMS_Running=true;statusValue.Text="STARTING";statusValue.TextColor3=C.yellow;task.spawn(autoMSLoop) end
    end
end)
task.spawn(function() while true do updateInventory();task.wait(1) end end)

-- ========== ESP RENDER LOOP ==========
RunService.Heartbeat:Connect(function(dt)
    if not espEnabled then
        for _, drawings in pairs(espCache) do
            for _, o in pairs(drawings) do pcall(function() o.Visible = false end) end
        end
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
        local valid=char and hum and root and head and hum.Health>0
        if not valid then
            hideAll()
        else
            local dist3D=myPos and (root.Position-myPos).Magnitude or 0
            local tooFar=myPos and espMaxDist>0 and dist3D>espMaxDist
            if tooFar then
                hideAll()
            else
                local hrpPos,hrpVis=Camera:WorldToViewportPoint(root.Position)
                local headPos,headVis=Camera:WorldToViewportPoint(head.Position)
                if not(hrpVis and headVis) then
                    hideAll()
                else
                    local height=math.abs(headPos.Y-hrpPos.Y)*1.7+(boxPadding*2)
                    local width=height*0.55
                    local boxX=hrpPos.X-width/2
                    local boxY=headPos.Y-boxPadding
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
