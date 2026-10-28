local data = require("GridData")
local this = script.object

-- =====================================================================
-- 🚨 【请确保你的模板 ID 在此处填写正确】
-- =====================================================================
local T_CURSOR_AREA = 1073741853 -- 光标检测区域
local T_IMAGE       = 1073741869 -- 普通图片
local T_VIDEO_PIXEL = 1073741846 -- 视频像素方块
local T_PLAY_BTN    = 1073741851 -- 预设按钮
local ASSET_WHITE   = 100001     -- 纯白正方形图片

local TARGET_FPS = 12
local function isReady(c) return c ~= nil and c.alive end

local function makeImage(parent, w, h, color, name)
    local c = game.InstantiateClientUIControl(T_IMAGE, parent)
    if not isReady(c) then return nil end
    c:SetActive(true); c:SetVisible(true)
    c:SetSizeDelta(w, h)
    c:SetImage(Enum.ImageSource.StaticReference, ASSET_WHITE)
    c.imageType = Enum.ImageType.Stretch
    c.imageColor = color
    if name then c.name = name end
    return c
end

local function getAbsolutePos(ctrl)
    local x, y = 0, 0
    while ctrl and isReady(ctrl) do
        local ax, ay = ctrl:GetAnchoredPosition()
        x = x + ax; y = y + ay
        ctrl = ctrl.parent
    end
    return x, y
end

local Runtime = {
    isPlaying = true,
    currentFrame = 1,
    frameTimer = 0,
    frameDuration = 1 / TARGET_FPS,
    lastTime = 0,
    videoControls = {},
    barFill = nil,
    barArea = nil,
    playBtn = nil,
    btnChildrenOrigPos = {}, 
    btnImages = {},          
    pixelSize = 1,
    actualVideoW = 1,
    actualVideoH = 1
}

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

local function HandleProgressClick(e, barW)
    local px = e:GetUIPos()
    local canvasW_ = game.GetUICanvasSize()
    local absX, _ = getAbsolutePos(Runtime.barArea)
    local realCenterX = canvasW_ / 2 + absX
    local realLeftX = realCenterX - barW / 2
    local percent = math.max(0, math.min(1, (px - realLeftX) / barW))
    
    Runtime.currentFrame = math.floor(percent * (data.total_frames - 1)) + 1
    Runtime.frameTimer = 0
    if isReady(Runtime.barFill) then Runtime.barFill.fillAmount = percent end
    RenderFrame(Runtime.currentFrame)
end

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
    local maxW, maxH = canvasW * 0.85, canvasH * 0.85
    local videoRatio = data.width / data.height
    local winW = maxW
    local winH = winW / videoRatio + 80
    if winH > maxH then
        winH = maxH
        winW = (winH - 80) * videoRatio
    end
    Runtime.pixelSize = math.floor(winW / data.width)
    Runtime.actualVideoW = data.width * Runtime.pixelSize
    Runtime.actualVideoH = data.height * Runtime.pixelSize

    local playerArea = game.InstantiateClientUIControl(T_CURSOR_AREA, this)
    if isReady(playerArea) then
        playerArea:SetActive(true); playerArea:SetVisible(true)
        playerArea:SetAnchorMin(0.5, 0.5); playerArea:SetAnchorMax(0.5, 0.5); playerArea:SetPivot(0.5, 0.5)
        playerArea:SetSizeDelta(winW, winH)
        playerArea:SetAnchoredPosition(0, 0)
        playerArea.raycastTarget = false
    end

    local videoRoot = game.InstantiateClientUIControl(T_CURSOR_AREA, playerArea)
    if isReady(videoRoot) then
        videoRoot:SetActive(true); videoRoot:SetVisible(true)
        videoRoot:SetAnchorMin(0.5, 0.5); videoRoot:SetAnchorMax(0.5, 0.5); videoRoot:SetPivot(0.5, 0.5)
        videoRoot:SetSizeDelta(Runtime.actualVideoW, Runtime.actualVideoH)
        videoRoot:SetAnchoredPosition(0, 40) 
        videoRoot.raycastTarget = false
    end

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

    local barW = winW - 120
    local barH = 8
    local barY = -winH / 2 + 30

    local barBg = makeImage(playerArea, barW, barH, Color(80, 85, 95, 255), "BarBg")
    if isReady(barBg) then barBg:SetAnchoredPosition(20, barY) end

    Runtime.barFill = makeImage(playerArea, barW, barH, Color(0, 200, 255, 255), "BarFill")
    if isReady(Runtime.barFill) then
        Runtime.barFill:SetAnchoredPosition(20, barY)
        Runtime.barFill.fillType = Enum.ImageFillType.Horizontal
        Runtime.barFill.fillHorizontalType = Enum.ImageFillHorizontalType.Left
        Runtime.barFill.fillAmount = 0
    end

    local barArea = game.InstantiateClientUIControl(T_CURSOR_AREA, playerArea)
    if isReady(barArea) then
        barArea:SetActive(true); barArea:SetVisible(true)
        barArea:SetAnchorMin(0.5, 0.5); barArea:SetAnchorMax(0.5, 0.5); barArea:SetPivot(0.5, 0.5)
        barArea:SetSizeDelta(barW, 40)
        barArea:SetAnchoredPosition(20, barY)
        barArea.raycastTarget = true
        Runtime.barArea = barArea

        barArea:AddCursorEventListener(Enum.CursorEventType.CursorDown, function(e) HandleProgressClick(e, barW) end)
        barArea:AddCursorEventListener(Enum.CursorEventType.CursorDrag, function(e) HandleProgressClick(e, barW) end)
    end

    Runtime.playBtn = game.InstantiateClientUIControl(T_PLAY_BTN, playerArea)
    if isReady(Runtime.playBtn) then
        Runtime.playBtn:SetActive(true); Runtime.playBtn:SetVisible(true)
        Runtime.playBtn:SetAnchorMin(0.5, 0.5); Runtime.playBtn:SetAnchorMax(0.5, 0.5); Runtime.playBtn:SetPivot(0.5, 0.5)
        Runtime.playBtn:SetAnchoredPosition(-winW / 2 + 10, barY)
        Runtime.playBtn.raycastTarget = true
        
        local children = Runtime.playBtn:GetChildren()
        for _, child in ipairs(children) do
            local x, y = child:GetAnchoredPosition()
            table.insert(Runtime.btnChildrenOrigPos, {ctrl = child, x = x, y = y})
            if child.imageColor or child.SetImage then table.insert(Runtime.btnImages, child) end
        end

        Runtime.playBtn:AddCursorEventListener(Enum.CursorEventType.CursorDown, function(_)
            for _, info in ipairs(Runtime.btnChildrenOrigPos) do info.ctrl:SetAnchoredPosition(info.x, info.y - 3) end
        end)

        Runtime.playBtn:AddCursorEventListener(Enum.CursorEventType.CursorUp, function(_)
            for _, info in ipairs(Runtime.btnChildrenOrigPos) do info.ctrl:SetAnchoredPosition(info.x, info.y) end
        end)

        Runtime.playBtn:AddCursorEventListener(Enum.CursorEventType.CursorClick, function(_)
            if Runtime.currentFrame >= data.total_frames then
                Runtime.currentFrame = 1
                if isReady(Runtime.barFill) then Runtime.barFill.fillAmount = 0 end
                RenderFrame(1)
                Runtime.isPlaying = true
            else
                Runtime.isPlaying = not Runtime.isPlaying
            end
            
            local targetColor = Runtime.isPlaying and Color(255, 255, 255, 255) or Color(255, 100, 100, 255)
            for _, imgCtrl in ipairs(Runtime.btnImages) do
                if isReady(imgCtrl) then imgCtrl.imageColor = targetColor end
            end
        end)
    end
end

function OnInit() script:EnableUpdate(true) end

function OnStart()
    this:SetActive(true); this:SetVisible(true)
    local ok, err = pcall(BuildPlayer)
    if ok then RenderFrame(1) else printerr("错误: " .. tostring(err)) end
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
            if isReady(Runtime.barFill) then
                Runtime.barFill.fillAmount = (Runtime.currentFrame - 1) / (data.total_frames - 1)
            end
        else
            Runtime.isPlaying = false
            for _, imgCtrl in ipairs(Runtime.btnImages) do
                if isReady(imgCtrl) then imgCtrl.imageColor = Color(255, 100, 100, 255) end
            end
        end
    end
end
