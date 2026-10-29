local data = require("GridData")
local this = script.object

-- =====================================================================
-- 🚨 【填入模版索引】
-- =====================================================================
local T_CURSOR_AREA = 1073741853 -- 光标检测区域
local T_IMAGE       = 1073741869 -- 普通图片
local T_VIDEO_PIXEL = 1073741846 -- 视频像素方块
local T_TEXTBOX     = 1073741867 -- 文本框

local ASSET_WHITE   = 100001     -- 纯白正方形
local ASSET_TRIANGLE= 100003     -- 三角形
local ASSET_ROUND   = 106007     -- 小圆

local TARGET_FPS = data.fps or 12
local function isReady(c) return c ~= nil and c.alive end

-- 工具函数：生成图片控件
local function makeImage(parent, w, h, color, name, assetId)
    local c = game.InstantiateClientUIControl(T_IMAGE, parent)
    if not isReady(c) then return nil end
    c:SetActive(true); c:SetVisible(true)
    c:SetSizeDelta(w, h)
    c:SetImage(Enum.ImageSource.StaticReference, assetId or ASSET_WHITE)
    c.imageType = Enum.ImageType.Stretch
    c.imageColor = color
    if name then c.name = name end
    return c
end

-- 工具函数：获取绝对坐标
local function getAbsolutePos(ctrl)
    local x, y = 0, 0
    while ctrl and isReady(ctrl) do
        local ax, ay = ctrl:GetAnchoredPosition()
        x = x + ax; y = y + ay
        ctrl = ctrl.parent
    end
    return x, y
end

-- =====================================================================
-- 运行时状态
-- =====================================================================
local Runtime = {
    isPlaying = true,
    currentFrame = 1,
    frameTimer = 0,
    frameDuration = 1 / TARGET_FPS,
    lastTime = 0,
    videoControls = {},
    
    playBtnBg = nil,
    playIconRoot = nil,
    pauseIconRoot = nil,
    isBtnHover = false,
    isBtnPress = false,
    
    thumb = nil,
    barArea = nil,
    barW = 400,
    
    pixelSize = 1,
    actualVideoW = 1,
    actualVideoH = 1
}

-- 视频渲染逻辑
local function RenderFrame(frameIdx)
    local rects = data.frames[frameIdx]
    if not rects then return end
    local rectCount = #rects / 5
    for i = 1, #Runtime.videoControls do
        local ctrl = Runtime.videoControls[i]
        if i <= rectCount then
            ctrl:SetActive(true)
            local base = (i - 1) * 5
            local x, y, w, h, cIdx = rects[base+1], rects[base+2], rects[base+3], rects[base+4], rects[base+5]
            ctrl.imageColor = data.palette[cIdx]
            ctrl:SetSizeDelta(w * Runtime.pixelSize, h * Runtime.pixelSize)
            local px = -Runtime.actualVideoW / 2 + (x + w / 2) * Runtime.pixelSize
            local py = Runtime.actualVideoH / 2 - (y + h / 2) * Runtime.pixelSize
            ctrl:SetAnchoredPosition(px, py)
        else
            ctrl:SetActive(false)
        end
    end
end

-- 进度条逻辑
local function UpdateProgressBar()
    if not isReady(Runtime.thumb) then return end
    local percent = (Runtime.currentFrame - 1) / (data.total_frames - 1)
    percent = math.max(0, math.min(1, percent))
    local startX = -Runtime.barW / 2
    local currentX = startX + (Runtime.barW * percent)
    local _, y = Runtime.thumb:GetAnchoredPosition()
    Runtime.thumb:SetAnchoredPosition(currentX, y)
end

local function HandleProgressClick(e)
    local px = e:GetUIPos()
    local canvasW = game.GetUICanvasSize()
    local absX, _ = getAbsolutePos(Runtime.barArea)
    local realCenterX = canvasW / 2 + absX
    local realLeftX = realCenterX - Runtime.barW / 2
    local percent = math.max(0, math.min(1, (px - realLeftX) / Runtime.barW))
    
    Runtime.currentFrame = math.floor(percent * (data.total_frames - 1)) + 1
    Runtime.frameTimer = 0
    RenderFrame(Runtime.currentFrame)
    UpdateProgressBar()
end

-- 播放按钮视觉逻辑
local function UpdateBtnVisuals()
    if not isReady(Runtime.playBtnBg) then return end
    if Runtime.isBtnPress then
        Runtime.playBtnBg.imageColor = Color(60, 80, 100, 255)
    elseif Runtime.isBtnHover then
        Runtime.playBtnBg.imageColor = Color(110, 140, 160, 255)
    else
        Runtime.playBtnBg.imageColor = Color(90, 120, 140, 255)
    end
    local offsetY = Runtime.isBtnPress and -2 or 0
    if isReady(Runtime.playIconRoot) then Runtime.playIconRoot:SetAnchoredPosition(0, offsetY) end
    if isReady(Runtime.pauseIconRoot) then Runtime.pauseIconRoot:SetAnchoredPosition(0, offsetY) end
    if isReady(Runtime.pauseIconRoot) then Runtime.pauseIconRoot:SetVisible(Runtime.isPlaying) end
    if isReady(Runtime.playIconRoot) then Runtime.playIconRoot:SetVisible(not Runtime.isPlaying) end
end

-- =====================================================================
-- 左上角“结算关卡”按钮
-- =====================================================================
local function BuildExitButton(parent)
    local w, h = 120, 40
    
    -- 1. 光标检测区作为按钮外壳
    local btnArea = game.InstantiateClientUIControl(T_CURSOR_AREA, parent)
    if not isReady(btnArea) then return end
    btnArea:SetActive(true); btnArea:SetVisible(true)
    
    -- 锚点设为左上角 (0, 1)
    btnArea:SetAnchorMin(0, 1)
    btnArea:SetAnchorMax(0, 1)
    btnArea:SetPivot(0, 1) 
    btnArea:SetAnchoredPosition(20, -20) -- 距离屏幕左边 20，上边 -20
    btnArea:SetSizeDelta(w, h)
    btnArea.raycastTarget = true

    -- 2. 红色背景
    local bg = makeImage(btnArea, w, h, Color(200, 50, 50, 255), "ExitBtnBg")
    
    -- 3. 按钮文本
    local textCtrl = game.InstantiateClientUIControl(T_TEXTBOX, btnArea)
    if isReady(textCtrl) then
        textCtrl:SetActive(true); textCtrl:SetVisible(true)
        textCtrl:SetAnchorMin(0.5, 0.5); textCtrl:SetAnchorMax(0.5, 0.5); textCtrl:SetPivot(0.5, 0.5)
        textCtrl:SetSizeDelta(w, h)
        textCtrl:SetAnchoredPosition(0, 0)
        textCtrl.text = "结算关卡"
        textCtrl.fontSize = 18
        textCtrl.fontColor = Color(255, 255, 255, 255)
        textCtrl.horizontalAlignment = Enum.TextHorizontalAlignment.Middle
        textCtrl.verticalAlignment = Enum.TextVerticalAlignment.Middle
    end

    -- 4. 悬停与按压反馈
    local isHover, isPress = false, false
    local function updateVisual()
        if not isReady(bg) then return end
        if isPress then
            bg.imageColor = Color(150, 30, 30, 255)
            btnArea:SetAnchoredPosition(20, -22) -- 模拟按下下沉 2 像素
        elseif isHover then
            bg.imageColor = Color(230, 80, 80, 255)
            btnArea:SetAnchoredPosition(20, -20)
        else
            bg.imageColor = Color(200, 50, 50, 255)
            btnArea:SetAnchoredPosition(20, -20)
        end
    end

    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorEnter, function(_) isHover = true; updateVisual() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorExit, function(_) isHover = false; isPress = false; updateVisual() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorDown, function(_) isPress = true; updateVisual() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorUp, function(_) isPress = false; updateVisual() end)
    
    -- 5. 点击发送服务端信号！
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorClick, function(_)
        -- 发送 game_close 信号
        local signal = game.ServerSignal("game_close")
        if signal then
            signal:SendSignal()
        end
        print("✅ 已发送 game_close 信号，请求结算关卡")
    end)
end

-- =====================================================================
-- 构建播放器
-- =====================================================================
local function BuildPlayer()
    local canvasW, canvasH = game.GetUICanvasSize()
    
    -- 全屏背景
    local fullBg = makeImage(this, canvasW, canvasH, Color(20, 22, 28, 255), "FullBg")
    if isReady(fullBg) then
        fullBg:SetAnchorMin(0, 0); fullBg:SetAnchorMax(1, 1)
        fullBg:SetSizeDelta(0, 0); fullBg:SetAnchoredPosition(0, 0)
        fullBg:SetAsFirstSibling()
    end

    -- 计算画面尺寸
    local maxW, maxH = canvasW * 0.85, canvasH * 0.75
    local videoRatio = data.width / data.height
    local winW = maxW
    local winH = winW / videoRatio
    if winH > maxH then
        winH = maxH
        winW = winH * videoRatio
    end
    Runtime.pixelSize = math.floor(winW / data.width)
    Runtime.actualVideoW = data.width * Runtime.pixelSize
    Runtime.actualVideoH = data.height * Runtime.pixelSize

    local playerArea = game.InstantiateClientUIControl(T_CURSOR_AREA, this)
    playerArea:SetActive(true); playerArea:SetVisible(true)
    playerArea:SetAnchorMin(0.5, 0.5); playerArea:SetAnchorMax(0.5, 0.5); playerArea:SetPivot(0.5, 0.5)
    playerArea:SetSizeDelta(Runtime.actualVideoW, Runtime.actualVideoH)
    playerArea:SetAnchoredPosition(0, 40) 
    playerArea.raycastTarget = false

    -- 视频渲染区
    local videoRoot = game.InstantiateClientUIControl(T_CURSOR_AREA, playerArea)
    videoRoot:SetActive(true); videoRoot:SetVisible(true)
    videoRoot:SetAnchorMin(0.5, 0.5); videoRoot:SetAnchorMax(0.5, 0.5); videoRoot:SetPivot(0.5, 0.5)
    videoRoot:SetSizeDelta(Runtime.actualVideoW, Runtime.actualVideoH)
    videoRoot:SetAnchoredPosition(0, 0) 
    videoRoot.raycastTarget = false

    local max_nums = 0
    for i = 1, #data.frames do
        if #data.frames[i] > max_nums then max_nums = #data.frames[i] end
    end
    local max_rects = math.floor(max_nums / 5)

    for i = 1, max_rects do
        local c = game.InstantiateClientUIControl(T_VIDEO_PIXEL, videoRoot)
        if isReady(c) then
            c:SetAnchorMin(0.5, 0.5); c:SetAnchorMax(0.5, 0.5); c:SetPivot(0.5, 0.5)
            c:SetImage(Enum.ImageSource.StaticReference, ASSET_WHITE)
            c.imageType = Enum.ImageType.Stretch
            c:SetActive(false)
            table.insert(Runtime.videoControls, c)
        end
    end

    -- 底部 UI
    local barY = -Runtime.actualVideoH / 2 - 40
    Runtime.barW = Runtime.actualVideoW * 0.7

    -- 播放按钮
    local btnSize = 40
    local btnArea = game.InstantiateClientUIControl(T_CURSOR_AREA, playerArea)
    btnArea:SetActive(true); btnArea:SetVisible(true)
    btnArea:SetAnchorMin(0.5, 0.5); btnArea:SetAnchorMax(0.5, 0.5); btnArea:SetPivot(0.5, 0.5)
    btnArea:SetSizeDelta(btnSize, btnSize)
    btnArea:SetAnchoredPosition(-Runtime.barW / 2 - 40, barY)
    btnArea.raycastTarget = true

    Runtime.playBtnBg = makeImage(btnArea, btnSize, btnSize, Color(90, 120, 140, 255), "Bg")

    Runtime.pauseIconRoot = game.InstantiateClientUIControl(T_CURSOR_AREA, btnArea)
    Runtime.pauseIconRoot:SetActive(true); Runtime.pauseIconRoot:SetVisible(true)
    Runtime.pauseIconRoot:SetAnchorMin(0.5, 0.5); Runtime.pauseIconRoot:SetAnchorMax(0.5, 0.5); Runtime.pauseIconRoot:SetPivot(0.5, 0.5)
    Runtime.pauseIconRoot:SetSizeDelta(btnSize, btnSize); Runtime.pauseIconRoot.raycastTarget = false
    local lineLeft = makeImage(Runtime.pauseIconRoot, 6, 18, Color(255, 255, 255, 255), "L"); lineLeft:SetAnchoredPosition(-6, 0)
    local lineRight = makeImage(Runtime.pauseIconRoot, 6, 18, Color(255, 255, 255, 255), "R"); lineRight:SetAnchoredPosition(6, 0)

    Runtime.playIconRoot = game.InstantiateClientUIControl(T_CURSOR_AREA, btnArea)
    Runtime.playIconRoot:SetActive(true); Runtime.playIconRoot:SetVisible(false)
    Runtime.playIconRoot:SetAnchorMin(0.5, 0.5); Runtime.playIconRoot:SetAnchorMax(0.5, 0.5); Runtime.playIconRoot:SetPivot(0.5, 0.5)
    Runtime.playIconRoot:SetSizeDelta(btnSize, btnSize); Runtime.playIconRoot.raycastTarget = false
    local triangle = makeImage(Runtime.playIconRoot, 18, 18, Color(255, 255, 255, 255), "Tri", ASSET_TRIANGLE)
    triangle:SetAnchoredPosition(2, 0); triangle:SetLocalRotation(0, 0, -90)

    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorEnter, function(_) Runtime.isBtnHover = true; UpdateBtnVisuals() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorExit, function(_) Runtime.isBtnHover = false; Runtime.isBtnPress = false; UpdateBtnVisuals() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorDown, function(_) Runtime.isBtnPress = true; UpdateBtnVisuals() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorUp, function(_) Runtime.isBtnPress = false; UpdateBtnVisuals() end)
    btnArea:AddCursorEventListener(Enum.CursorEventType.CursorClick, function(_)
        if Runtime.currentFrame >= data.total_frames then
            Runtime.currentFrame = 1; Runtime.frameTimer = 0
            RenderFrame(1); UpdateProgressBar(); Runtime.isPlaying = true
        else
            Runtime.isPlaying = not Runtime.isPlaying
        end
        UpdateBtnVisuals()
    end)

    -- 进度条底槽
    local barBg = makeImage(playerArea, Runtime.barW, 6, Color(50, 55, 65, 255), "BarBg")
    if isReady(barBg) then barBg:SetAnchoredPosition(0, barY) end

    -- 进度条拖拽区
    Runtime.barArea = game.InstantiateClientUIControl(T_CURSOR_AREA, playerArea)
    Runtime.barArea:SetActive(true); Runtime.barArea:SetVisible(true)
    Runtime.barArea:SetAnchorMin(0.5, 0.5); Runtime.barArea:SetAnchorMax(0.5, 0.5); Runtime.barArea:SetPivot(0.5, 0.5)
    Runtime.barArea:SetSizeDelta(Runtime.barW, 30); Runtime.barArea:SetAnchoredPosition(0, barY); Runtime.barArea.raycastTarget = true
    Runtime.barArea:AddCursorEventListener(Enum.CursorEventType.CursorDown, function(e) HandleProgressClick(e) end)
    Runtime.barArea:AddCursorEventListener(Enum.CursorEventType.CursorDrag, function(e) HandleProgressClick(e) end)

    -- 进度条滑块
    Runtime.thumb = makeImage(playerArea, 24, 16, Color(0, 200, 255, 255), "Thumb", ASSET_ROUND)
    if isReady(Runtime.thumb) then
        Runtime.thumb:SetAnchorMin(0.5, 0.5); Runtime.thumb:SetAnchorMax(0.5, 0.5); Runtime.thumb:SetPivot(0.5, 0.5)
        Runtime.thumb:SetAnchoredPosition(0, barY)
    end

    -- 🚨 调用：生成左上角结算按钮！
    BuildExitButton(this)

    UpdateProgressBar()
    UpdateBtnVisuals()
end

-- 生命周期
function OnInit() script:EnableUpdate(true) end

function OnStart()
    this:SetActive(true); this:SetVisible(true)
    this.showCursor = true 
    
    local ok, err = pcall(BuildPlayer)
    if ok then RenderFrame(1) else printerr("初始化失败: " .. tostring(err)) end
end

function OnUpdate(dt)
    if not Runtime.isPlaying then return end
    local now = os.clock()
    if Runtime.lastTime == 0 then Runtime.lastTime = now end
    local delta = now - Runtime.lastTime
    Runtime.lastTime = now

    Runtime.frameTimer = Runtime.frameTimer + delta
    if Runtime.frameTimer >= Runtime.frameDuration then
        Runtime.frameTimer = Runtime.frameTimer - Runtime.frameDuration
        if Runtime.currentFrame < data.total_frames then
            Runtime.currentFrame = Runtime.currentFrame + 1
            RenderFrame(Runtime.currentFrame)
            UpdateProgressBar()
        else
            Runtime.isPlaying = false
            UpdateBtnVisuals()
        end
    end
end
