local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)

local Home = CreateFrame("Frame")
WF.HomeAPI = Home

WF.UI:RegisterMenu({ id = "HOME", name = L["Home"] or "主页", type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\home.tga", key = "WF_HOME", order = 1 })
local CustomCopyDialog = nil

local function ShowCustomCopyDialog(urlText)
    if not CustomCopyDialog then
        CustomCopyDialog = CreateFrame("Frame", "WishFlexCustomCopyDialog", UIParent, "BackdropTemplate")
        CustomCopyDialog:SetSize(320, 110)
        CustomCopyDialog:SetPoint("CENTER", 0, 50) 
        CustomCopyDialog:SetFrameStrata("TOOLTIP") 
        CustomCopyDialog:SetFrameLevel(100)
        
        CustomCopyDialog:EnableMouse(true)
        WF.UI.Factory.ApplyFlatSkin(CustomCopyDialog, 0.08, 0.08, 0.08, 0.98, 0, 1, 0.8, 1)
        local title = CustomCopyDialog:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        title:SetPoint("TOP", 0, -15)
        title:SetText(L["Press Ctrl+C to copy the link:"] or "请按 Ctrl+C 复制下方链接：")
        title:SetTextColor(1, 1, 1)
        local boxBg = CreateFrame("Frame", nil, CustomCopyDialog, "BackdropTemplate")
        boxBg:SetSize(280, 26)
        boxBg:SetPoint("TOP", title, "BOTTOM", 0, -10)
        WF.UI.Factory.ApplyFlatSkin(boxBg, 0, 0, 0, 0.6, 0.4, 0.4, 0.4, 0.8)
        local eBox = CreateFrame("EditBox", nil, boxBg)
        eBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        eBox:SetPoint("TOPLEFT", 5, 0)
        eBox:SetPoint("BOTTOMRIGHT", -5, 0)
        eBox:SetAutoFocus(false)
        eBox:SetTextColor(0, 1, 0.8) 
        eBox:SetScript("OnEscapePressed", function() CustomCopyDialog:Hide() end)
        CustomCopyDialog.editBox = eBox
        local closeBtn = CreateFrame("Button", nil, CustomCopyDialog, "BackdropTemplate")
        closeBtn:SetSize(100, 26)
        closeBtn:SetPoint("BOTTOM", 0, 12)
        WF.UI.Factory.ApplyFlatSkin(closeBtn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
        
        local btnText = closeBtn:CreateFontString(nil, "OVERLAY")
        btnText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        btnText:SetPoint("CENTER")
        btnText:SetText("关闭 (Close)")
        btnText:SetTextColor(0.8, 0.8, 0.8)

        closeBtn:SetScript("OnEnter", function() 
            WF.UI.Factory.ApplyFlatSkin(closeBtn, 0.25, 0.25, 0.25, 1, 0, 0, 0, 1)
            btnText:SetTextColor(1, 1, 1)
        end)
        closeBtn:SetScript("OnLeave", function() 
            WF.UI.Factory.ApplyFlatSkin(closeBtn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
            btnText:SetTextColor(0.8, 0.8, 0.8)
        end)
        closeBtn:SetScript("OnClick", function() CustomCopyDialog:Hide() end)
    end

    CustomCopyDialog.editBox:SetText(urlText)
    CustomCopyDialog:Show()
    CustomCopyDialog.editBox:SetFocus()
    CustomCopyDialog.editBox:HighlightText()
end

-- ==========================================

local GridColors = {
    {r=0, g=1, b=0.8},
    {r=1, g=0.82, b=0},
    {r=0.2, g=0.6, b=1},
    {r=1, g=0.3, b=0.3},
}

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
    local targetWidth = 850 
    local currentY = -20
    local margin = 40
    local centerGap = 10
    local logoContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    logoContainer:SetHeight(160)
    logoContainer:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
    logoContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, currentY)
    
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
    
    local introStr = L["Home Intro Desc"] or "一款追求性能的轻量级无限制排版插件。"
    local desc = logoContainer:CreateFontString(nil, "OVERLAY")
    desc:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -10)
    desc:SetJustifyH("CENTER"); desc:SetText(introStr); desc:SetTextColor(0.7, 0.7, 0.7)

    local authorTxt = logoContainer:CreateFontString(nil, "OVERLAY")
    authorTxt:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    authorTxt:SetPoint("TOP", desc, "BOTTOM", 0, -8)
    local authorName = C_AddOns.GetAddOnMetadata(AddonName, "Author") or "Unknown"
    authorTxt:SetText(string.format("%s: |cffffffff%s|r", L["Author"] or "开发与维护", authorName))
    authorTxt:SetTextColor(0.5, 0.5, 0.5)

    currentY = currentY - 200
    local cardGridContainer = CreateFrame("Frame", nil, scrollChild)
    cardGridContainer:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
    cardGridContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, currentY)
    local cardH = 110 

    local guides = {
        { L["GuideTitle1"] or "沙盒排版", L["GuideBody1"] or "点击顶部齿轮即可解锁所有框体\n直接通过鼠标拖拽进行可视化布局" },
        { L["GuideTitle2"] or "极简操作", L["GuideBody2"] or "在沙盒模式下无需寻找繁琐的菜单\n直接【左右键点击】图标即可调出设置" },
        { L["GuideTitle3"] or "智能隐藏", L["GuideBody3"] or "在右键菜单中点击【显示隐藏设置】\n即可独立开启脱战隐藏、条件隐藏等" },
        { L["GuideTitle4"] or "发光定制", L["GuideBody4"] or "通过右键菜单进入【详细发光设置】\n支持原生高亮接管与自定义流光调节" }
    }

    for i, data in ipairs(guides) do
        local card = CreateGuideCard(cardGridContainer, data[1], data[2], GridColors[i])
        card:SetHeight(cardH)
        local row = math.floor((i-1)/2)
        local isLeft = (i%2 == 1)
        local yOff = -row * (cardH + 20)
        if isLeft then
            card:SetPoint("TOPLEFT", cardGridContainer, "TOPLEFT", margin, yOff)
            card:SetPoint("TOPRIGHT", cardGridContainer, "TOP", -centerGap, yOff)
        else
            card:SetPoint("TOPLEFT", cardGridContainer, "TOP", centerGap, yOff)
            card:SetPoint("TOPRIGHT", cardGridContainer, "TOPRIGHT", -margin, yOff)
        end
    end

    local gridHeight = 2 * cardH + 20
    cardGridContainer:SetHeight(gridHeight)
    currentY = currentY - gridHeight - 40
    local btnEditMode = WF.UI.Factory:CreateFlatButton(scrollChild, L["Enter Edit Mode"] or "编辑模式", function() 
        if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
        if WF.MainFrame and WF.MainFrame:IsShown() then WF.MainFrame:Hide() end 
    end)
    btnEditMode:SetHeight(34)
    btnEditMode:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", margin, currentY)
    btnEditMode:SetPoint("TOPRIGHT", scrollChild, "TOP", -centerGap, currentY)

    local btnReload = WF.UI.Factory:CreateFlatButton(scrollChild, L["Reload UI"] or "重载界面 (/rl)", function() ReloadUI() end)
    btnReload:SetHeight(34)
    btnReload:SetPoint("TOPLEFT", scrollChild, "TOP", centerGap, currentY)
    btnReload:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -margin, currentY)

    currentY = currentY - 50
    local btnGitHub = WF.UI.Factory:CreateFlatButton(scrollChild, L["GitHub Repo"] or "GitHub 开源主页", function() 
        ShowCustomCopyDialog("https://github.com/WishFlex/WishFlex") 
    end)
    btnGitHub:SetHeight(34)
    btnGitHub:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", margin, currentY)
    btnGitHub:SetPoint("TOPRIGHT", scrollChild, "TOP", -centerGap, currentY)

    local btnAfdian = WF.UI.Factory:CreateFlatButton(scrollChild, L["Afdian Sponsor"] or "爱发电 赞助支持", function() 
        ShowCustomCopyDialog("https://ifdian.net/a/wishflex") 
    end)
    btnAfdian:SetHeight(34)
    btnAfdian:SetPoint("TOPLEFT", scrollChild, "TOP", centerGap, currentY)
    btnAfdian:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -margin, currentY)

    currentY = currentY - 60

    return -(math.abs(currentY)), targetWidth
end

WF.UI:RegisterPanel("WF_HOME", SetupHomePanel)

local function InitHome()
    WF.HomeInitialized = true
end

WF:RegisterModule("home", L["Home"] or "主页", InitHome)