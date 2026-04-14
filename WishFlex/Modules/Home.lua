local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)

local Home = CreateFrame("Frame")
WF.HomeAPI = Home

WF.UI:RegisterMenu({ id = "HOME", name = L["Home"] or "主页", type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\home.tga", key = "WF_HOME", order = 1 })

-- 定义四个操作步骤的强调颜色
local GridColors = {
    {r=0, g=1, b=0.8},    -- 蒂芙尼蓝 (Sandbox)
    {r=1, g=0.82, b=0},   -- 圣光黄 (Controls)
    {r=0.2, g=0.6, b=1},  -- 奥术蓝 (SmartHide)
    {r=1, g=0.3, b=0.3},  -- 触发红 (Glow)
}

-- 创建操作指南卡片的辅助函数
local function CreateGuideCard(parent, titleText, bodyText, colorRef)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    WF.UI.Factory.ApplyFlatSkin(card, 0.05, 0.05, 0.05, 0.6, 0, 0, 0, 0)
    
    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(4)
    accent:SetColorTexture(colorRef.r, colorRef.g, colorRef.b, 0.8)

    local title = card:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(titleText)
    title:SetTextColor(colorRef.r, colorRef.g, colorRef.b)

    local body = card:CreateFontString(nil, "OVERLAY")
    body:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", -15, 10) 
    body:SetJustifyH("LEFT"); body:SetJustifyV("TOP"); body:SetWordWrap(true)
    body:SetText(bodyText)
    body:SetTextColor(0.8, 0.8, 0.8); body:SetSpacing(6)

    return card
end

local function SetupHomePanel(scrollChild, ColW)
    local targetWidth = 900 
    local currentY = -20

    -- 1. 顶部 Logo 与 简介 (居中)
    local logoContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    logoContainer:SetSize(ColW, 160)
    logoContainer:SetPoint("TOP", scrollChild, "TOP", 0, currentY)
    
    local logo = logoContainer:CreateTexture(nil, "ARTWORK")
    logo:SetSize(90, 90); logo:SetPoint("TOP", logoContainer, "TOP", 0, 0)
    logo:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo3.tga")
    
    local title = logoContainer:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE"); title:SetPoint("TOP", logo, "BOTTOM", 0, -5)
    title:SetText(L["WishFlex GeniSys"] or "WishFlex CDM"); title:SetTextColor(1, 1, 1)
    
    local version = logoContainer:CreateFontString(nil, "OVERLAY")
    version:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); version:SetPoint("BOTTOMLEFT", title, "TOPRIGHT", 5, -8)
    local verStr = C_AddOns.GetAddOnMetadata(AddonName, "Version") or "1.0.0"
    version:SetText(string.format("|cff00ffccv%s|r", verStr))
    
    -- 简介文字
    local introStr = L["Home Intro Desc"] or "一款追求性能的轻量级无限制排版插件。"
    local desc = logoContainer:CreateFontString(nil, "OVERLAY")
    desc:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -10)
    desc:SetJustifyH("CENTER"); desc:SetText(introStr); desc:SetTextColor(0.7, 0.7, 0.7)

    -- 【修改】：将作者信息直接放置在简介文字的下方
    local authorTxt = logoContainer:CreateFontString(nil, "OVERLAY")
    authorTxt:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    authorTxt:SetPoint("TOP", desc, "BOTTOM", 0, -8) -- 距离上方简介 8 像素
    local authorName = C_AddOns.GetAddOnMetadata(AddonName, "Author") or "Unknown"
    authorTxt:SetText(string.format("%s: |cffffffff%s|r", L["Author"] or "开发与维护", authorName))
    authorTxt:SetTextColor(0.5, 0.5, 0.5)

    currentY = currentY - 220

    -- 2. 核心操作指南 (2x2 网格排版)
    local cardW = 300 

    local cardGridContainer = CreateFrame("Frame", nil, scrollChild)
    cardGridContainer:SetSize((cardW * 2) + 20, 1)
    cardGridContainer:SetPoint("TOP", scrollChild, "TOP", 0, currentY)

    local cardH = 100

    local guides = {
        { L["GuideTitle1"] or "沙盒排版", L["GuideBody1"] or "点击顶部齿轮即可解锁所有框体\n直接通过鼠标拖拽进行可视化布局" },
        { L["GuideTitle2"] or "极简操作", L["GuideBody2"] or "在沙盒模式下无需寻找繁琐的菜单\n直接【左右键点击】图标即可调出设置" },
        { L["GuideTitle3"] or "智能隐藏", L["GuideBody3"] or "在右键菜单中点击【显示隐藏设置】\n即可独立开启脱战隐藏、条件隐藏等" },
        { L["GuideTitle4"] or "发光定制", L["GuideBody4"] or "通过右键菜单进入【详细发光设置】\n支持原生高亮接管与自定义流光调节" }
    }

    local cardFrames = {}
    for i, data in ipairs(guides) do
        local card = CreateGuideCard(cardGridContainer, data[1], data[2], GridColors[i])
        card:SetSize(cardW, cardH)
        
        local row = math.floor((i-1)/2)
        local col = (i-1)%2
        card:SetPoint("TOPLEFT", cardGridContainer, "TOPLEFT", col * (cardW + 20), -row * (cardH + 20))
        table.insert(cardFrames, card)
    end

    local gridHeight = 2 * cardH + 20
    cardGridContainer:SetHeight(gridHeight)
    currentY = currentY - gridHeight - 50

    -- 3. 快捷操作区 (并排大按钮)
    local btnW = 200; local btnGap = 15
    local btnReload = WF.UI.Factory:CreateFlatButton(scrollChild, L["Reload UI"] or "重载界面 (/rl)", function() ReloadUI() end)
    btnReload:SetPoint("TOPRIGHT", scrollChild, "TOP", -(btnGap/2), currentY); btnReload:SetWidth(btnW); btnReload:SetHeight(34)
    
    local btnEditMode = WF.UI.Factory:CreateFlatButton(scrollChild, L["Enter Edit Mode"] or "编辑模式", function() 
        if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
        if WF.MainFrame and WF.MainFrame:IsShown() then WF.MainFrame:Hide() end 
    end)
    btnEditMode:SetPoint("TOPLEFT", scrollChild, "TOP", (btnGap/2), currentY); btnEditMode:SetWidth(btnW); btnEditMode:SetHeight(34)

    -- 因为作者信息移到了上面，底部不再需要单独的版权文本
    currentY = currentY - 50

    return -(math.abs(currentY)), targetWidth
end

WF.UI:RegisterPanel("WF_HOME", SetupHomePanel)

local function InitHome()
    WF.HomeInitialized = true
end

WF:RegisterModule("home", L["Home"] or "主页", InitHome)