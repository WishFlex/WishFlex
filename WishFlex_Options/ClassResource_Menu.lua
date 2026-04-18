local AddonName, ns = ...
local WF = _G.WishFlex
local L = WF.L
local CR = WF.ClassResourceAPI
if not CR then return end

CR.Menu = {}
local LSM = LibStub("LibSharedMedia-3.0", true)
local math_abs = math.abs
local playerClass = select(2, UnitClass("player"))
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local C_R, C_G, C_B = ClassColor.r, ClassColor.g, ClassColor.b

local function GetSpecOptions()
    local opts = {}
    local classID = select(3, UnitClass("player"))
    for i = 1, GetNumSpecializationsForClassID(classID) do 
        local id, name = GetSpecializationInfoForClassID(classID, i)
        if id and name then table.insert(opts, {text = name, value = id}) end 
    end
    table.insert(opts, {text = L["No Spec / General"] or "无专精 / 通用", value = 0})
    return opts
end

local function GetTextureOptions()
    local opts = {}
    if LSM then local list = LSM:List("statusbar"); if list then for i = 1, #list do table.insert(opts, { text = list[i], value = list[i] }) end end end
    if #opts == 0 then table.insert(opts, {text = "Wish2", value = "Wish2"}) end
    return opts
end

local function GetPowerTypeOptions()
    local opts = { {text = L["All Types"] or "所有类型 (默认)", value = "ALL"} }
    if playerClass == "DRUID" then
        table.insert(opts, {text = L["Mana"] or "法力值", value = 0})
        table.insert(opts, {text = L["Rage"] or "怒气值", value = 1})
        table.insert(opts, {text = L["Energy"] or "能量值", value = 3})
        table.insert(opts, {text = L["Astral Power"] or "星界能量", value = 8})
    elseif playerClass == "WARRIOR" then table.insert(opts, {text = L["Rage"] or "怒气值", value = 1})
    elseif playerClass == "HUNTER" then table.insert(opts, {text = L["Focus"] or "集中值", value = 2})
    elseif playerClass == "ROGUE" then table.insert(opts, {text = L["Energy"] or "能量值", value = 3})
    elseif playerClass == "PRIEST" then table.insert(opts, {text = L["Mana"] or "法力值", value = 0}); table.insert(opts, {text = L["Insanity"] or "狂乱值", value = 13})
    elseif playerClass == "DEATHKNIGHT" then table.insert(opts, {text = L["Runic Power"] or "符文能量", value = 5})
    elseif playerClass == "SHAMAN" then table.insert(opts, {text = L["Mana"] or "法力值", value = 0}); table.insert(opts, {text = L["Maelstrom"] or "漩涡值", value = 11})
    elseif playerClass == "MONK" then table.insert(opts, {text = L["Mana"] or "法力值", value = 0}); table.insert(opts, {text = L["Energy"] or "能量值", value = 3})
    elseif playerClass == "DEMONHUNTER" then table.insert(opts, {text = L["Fury"] or "恶魔怒气", value = 17})
    elseif playerClass == "EVOKER" then table.insert(opts, {text = L["Mana"] or "法力值", value = 0}); table.insert(opts, {text = L["Essence"] or "精华", value = 19})
    else table.insert(opts, {text = L["Mana"] or "法力值", value = 0}) end
    return opts
end

local function BuildTextOpts(title, cfgObj, cb, hasText, hasTimer)
    local childs = {}
    if hasText then
        table.insert(childs, { type = "toggle", key = "textEnable", db = cfgObj, text = L["Enable Main Text"] or "启用主文本(层数/数值)", callback = cb })
        table.insert(childs, { type = "dropdown", key = "textAnchor", db = cfgObj, text = L["Main Text Anchor"] or "主文本锚点", options = { {text=L["CENTER"] or "居中",value="CENTER"}, {text=L["LEFT"] or "靠左",value="LEFT"}, {text=L["RIGHT"] or "靠右",value="RIGHT"} }, callback = cb })
        table.insert(childs, { type = "slider", key = "xOffset", db = cfgObj, text = L["Main Text X Offset"] or "主文本X偏移", min=-200, max=200, step=1, callback = cb })
        table.insert(childs, { type = "slider", key = "yOffset", db = cfgObj, text = L["Main Text Y Offset"] or "主文本Y偏移", min=-100, max=100, step=1, callback = cb })
    end
    if hasTimer then
        table.insert(childs, { type = "toggle", key = "timerEnable", db = cfgObj, text = L["Enable Timer Text"] or "启用计时文本", callback = cb })
        table.insert(childs, { type = "dropdown", key = "timerAnchor", db = cfgObj, text = L["Timer Text Anchor"] or "计时文本锚点", options = { {text=L["CENTER"] or "居中",value="CENTER"}, {text=L["LEFT"] or "靠左",value="LEFT"}, {text=L["RIGHT"] or "靠右",value="RIGHT"} }, callback = cb })
        table.insert(childs, { type = "slider", key = "timerXOffset", db = cfgObj, text = L["Timer Text X Offset"] or "计时文本X偏移", min=-200, max=200, step=1, callback = cb })
        table.insert(childs, { type = "slider", key = "timerYOffset", db = cfgObj, text = L["Timer Text Y Offset"] or "计时文本Y偏移", min=-100, max=100, step=1, callback = cb })
    end
    table.insert(childs, { type = "slider", key = "fontSize", db = cfgObj, text = L["Font Size"] or "字体大小", min=1, max=64, step=1, callback = cb })
    table.insert(childs, { type = "color", key = "color", db = cfgObj, text = L["Text Color"] or "文本颜色", callback = cb })
    return { type = "group", key = "sb_txt_"..title, text = (L["Text Layout"] or "文本排版") .. " - " .. title, childs = childs }
end

local function BuildGradientOpts(cfgDB, handleCallback)
    if type(cfgDB) ~= "table" then return nil end
    if type(cfgDB.gradientStart) ~= "table" then cfgDB.gradientStart = {r=0, g=1, b=0, a=1} end
    if type(cfgDB.gradientEnd) ~= "table" then cfgDB.gradientEnd = {r=1, g=0, b=0, a=1} end
    local childs = {
        { type = "toggle", key = "enableGradient", db = cfgDB, text = L["Enable Gradient Color"] or "开启层数渐变色 (优先级最高)", callback = handleCallback },
        { type = "color", key = "gradientStart", db = cfgDB, text = L["Start Color (1 Stack)"] or "起始颜色 (1层)", callback = handleCallback },
        { type = "color", key = "gradientEnd", db = cfgDB, text = L["End Color (Max Stacks)"] or "结束颜色 (满层)", callback = handleCallback },
    }
    return { type = "group", key = "p_gradient", text = L["Gradient Color Settings"] or "渐变颜色设置", childs = childs }
end

local function BuildThresholdOpts(cfgDB, handleCallback, includePowerTypeDropdown)
    if type(cfgDB) ~= "table" then return nil end
    if not cfgDB.colorThresholds then cfgDB.colorThresholds = {} end
    for i = 1, 5 do 
        if type(cfgDB.colorThresholds[i]) ~= "table" then cfgDB.colorThresholds[i] = {} end 
        if type(cfgDB.colorThresholds[i].color) ~= "table" then cfgDB.colorThresholds[i].color = {r=1, g=1, b=1, a=1} end
    end
    local cLineDB = { slot = CR.selectedColorThresholdSlot or 1 }
    local childs = { { type = "toggle", key = "enableThreshold", db = cfgDB, text = L["Enable Multi-stage Color"] or "开启层数/数值突变", callback = handleCallback } }
    if includePowerTypeDropdown then table.insert(childs, { type = "dropdown", key = "thresholdPowerType", db = cfgDB, text = L["Applicable Power Type"] or "限定生效的能量类型", options = GetPowerTypeOptions(), callback = handleCallback }) end
    table.insert(childs, { type = "dropdown", key = "slot", db = cLineDB, text = L["Select Stage"] or "选择突变阶段", options = { {text=L["Stage 1"] or "阶段 1", value=1}, {text=L["Stage 2"] or "阶段 2", value=2}, {text=L["Stage 3"] or "阶段 3", value=3}, {text=L["Stage 4"] or "阶段 4", value=4}, {text=L["Stage 5"] or "阶段 5", value=5} }, callback = function() CR.selectedColorThresholdSlot = cLineDB.slot; WF.UI:RefreshCurrentPanel() end })
    table.insert(childs, { type = "toggle", key = "enable", db = cfgDB.colorThresholds[cLineDB.slot], text = L["Enable This Stage"] or "启用此阶段", callback = handleCallback })
    table.insert(childs, { type = "slider", key = "value", db = cfgDB.colorThresholds[cLineDB.slot], text = L["Trigger Value"] or "触发层数/数值", min=1, max=300, step=1, callback = handleCallback })
    table.insert(childs, { type = "color", key = "color", db = cfgDB.colorThresholds[cLineDB.slot], text = L["Threshold Color"] or "阶段突变颜色", callback = handleCallback })
    return { type = "group", key = "p_threshold", text = L["Stage Color Settings"] or "层数突变颜色设置", childs = childs }
end

local function CreateSandboxContextMenu()
    if WF.UI.CR_SandboxMenu then return WF.UI.CR_SandboxMenu end
    local m = CreateFrame("Frame", "WF_CR_SandboxContextMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("TOOLTIP"); m:SetSize(260, 200)
    WF.UI.Factory.ApplyFlatSkin(m, 0.05, 0.05, 0.05, 0.98, C_R, C_G, C_B, 1)
    m.title = m:CreateFontString(nil, "OVERLAY"); m.title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); m.title:SetPoint("TOP", 0, -12); m.title:SetTextColor(0.7, 0.7, 0.7)
    m.closeBtn = CreateFrame("Button", nil, m); m.closeBtn:SetSize(16, 16); m.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    local cTex = m.closeBtn:CreateTexture(nil, "ARTWORK"); cTex:SetAllPoints(); cTex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); cTex:SetVertexColor(0.6, 0.6, 0.6)
    m.closeBtn:SetScript("OnEnter", function() cTex:SetVertexColor(1, 0.2, 0.2) end); m.closeBtn:SetScript("OnLeave", function() cTex:SetVertexColor(0.6, 0.6, 0.6) end); m.closeBtn:SetScript("OnClick", function() m:Hide() end)
    m.items = {}
    m:SetScript("OnUpdate", function(self) if self:IsShown() and not self:IsMouseOver() then if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then self:Hide() end end end)
    WF.UI.CR_SandboxMenu = m
    return m
end

local function ShowFlatContextMenu(titleStr, items)
    local m = CreateSandboxContextMenu()
    if titleStr then m.title:SetText(titleStr); m.title:Show() else m.title:Hide() end
    for _, b in ipairs(m.items) do b:Hide() end
    local yOff = m.title:IsShown() and -35 or -15

    for _, tData in ipairs(items) do
        local idx = #m.items + 1; local b = m.items[idx]
        if not b then
            b = CreateFrame("Button", nil, m, "BackdropTemplate"); b:SetSize(240, 26);
            b.hoverBg = b:CreateTexture(nil, "BACKGROUND"); b.hoverBg:SetColorTexture(C_R, C_G, C_B, 0.25); b.hoverBg:Hide()
            b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE");
            b.track = b:CreateTexture(nil, "ARTWORK"); b.track:SetSize(26, 12); b.track:SetPoint("LEFT", 12, 0);
            b.thumb = b:CreateTexture(nil, "OVERLAY"); b.thumb:SetSize(10, 10); table.insert(m.items, b)
        end
        b.text:SetTextColor(0.7, 0.7, 0.7); b.text:SetText(tData.text)
        b:SetScript("OnEnter", function(self) self.hoverBg:Show() end)
        b:SetScript("OnLeave", function(self) self.hoverBg:Hide() end)

        if tData.isAction then
            b.track:Hide(); b.thumb:Hide(); b.text:SetPoint("LEFT", 15, 0)
            b.hoverBg:SetPoint("TOPLEFT", b, "TOPLEFT", 10, 0); b.hoverBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 0)
            b:SetScript("OnClick", function()
                if tData.keepPos then m.keepPosition = true end
                tData.action()
                if not tData.keepPos then m:Hide() end
            end)
        else
            b.track:Show(); b.thumb:Show(); b.text:SetPoint("LEFT", 48, 0)
            b.hoverBg:SetPoint("TOPLEFT", b, "TOPLEFT", 42, 0); b.hoverBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 0)
            if tData.state then
                b.track:SetColorTexture(C_R, C_G, C_B, 1); b.thumb:SetColorTexture(1, 1, 1, 1); b.thumb:SetPoint("CENTER", b.track, "RIGHT", -6, 0)
            else
                b.track:SetColorTexture(0.2, 0.2, 0.2, 1); b.thumb:SetColorTexture(0.6, 0.6, 0.6, 1); b.thumb:SetPoint("CENTER", b.track, "LEFT", 6, 0)
            end
            b:SetScript("OnClick", function()
                m.keepPosition = true
                tData.toggle()
            end)
        end
        b:ClearAllPoints(); b:SetPoint("TOP", 0, yOff); b:Show(); WF.UI.Factory.ApplyFlatSkin(b, 0,0,0,0, 0,0,0,0); yOff = yOff - 28
    end
    m:SetHeight(math_abs(yOff) + 15)

    if not m.keepPosition then
        local cx, cy = GetCursorPosition(); local scale = UIParent:GetEffectiveScale()
        m:ClearAllPoints(); m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cx/scale) + 10, (cy/scale) - 10)
    end
    m.keepPosition = false
    m:Show()
end

function CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, subMenu)
    local toggles = {}
    local mTitle = nil
    local dbRef = CR.GetCurrentSpecConfig(CR.GetCurrentContextID()); local db = CR.GetDB(); local wmDB = WF.db.wishMonitor or {}

    local targetVisDB = nil
    if key == "power" then targetVisDB = dbRef.power
    elseif key == "class" then targetVisDB = dbRef.class
    elseif key == "mana" then targetVisDB = dbRef.mana
    elseif key == "vigor" then targetVisDB = db.vigor
    elseif key == "whirling" then targetVisDB = db.whirling
    elseif string.sub(key, 1, 3) == "WM_" then
        local spellID = string.sub(key, 4)
        targetVisDB = (wmDB.skills and wmDB.skills[spellID]) or (wmDB.buffs and wmDB.buffs[spellID])
    end

    if subMenu == "visibility" and targetVisDB then
        if not targetVisDB.visibility then targetVisDB.visibility = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false } end
        local vis = targetVisDB.visibility

        table.insert(toggles, { text = L["Enable SmartHide"] or "开启条件隐藏", state = vis.enable, toggle = function() vis.enable = not vis.enable; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback(); CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, subMenu) end })

        if vis.enable then
            table.insert(toggles, { text = L["├ Hide Out of Combat"] or "  ├ 脱战且无目标时隐藏", state = vis.hideOOC, toggle = function() vis.hideOOC = not vis.hideOOC; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback(); CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, subMenu) end })
            table.insert(toggles, { text = L["├ Hide on Friendly"] or "  ├ 目标为友方时隐藏", state = vis.friendly, toggle = function() vis.friendly = not vis.friendly; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback(); CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, subMenu) end })
            table.insert(toggles, { text = L["├ Hide Flying"] or "  ├ 飞行时强制隐藏", state = vis.dragonriding, toggle = function() vis.dragonriding = not vis.dragonriding; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback(); CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, subMenu) end })
            table.insert(toggles, { text = L["└ Hide in Vehicle"] or "  └ 乘坐载具时隐藏", state = vis.vehicle, toggle = function() vis.vehicle = not vis.vehicle; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback(); CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, subMenu) end })
        end
        mTitle = L["Visibility Settings"] or "显示条件设置"
    else
        if key == "power" then table.insert(toggles, { text = dbRef.showPower and (L["Disable"] or "禁用") or (L["Enable"] or "启用"), isAction = true, action = function() dbRef.showPower = not dbRef.showPower; refreshCallback() end })
        elseif key == "class" then table.insert(toggles, { text = dbRef.showClass and (L["Disable"] or "禁用") or (L["Enable"] or "启用"), isAction = true, action = function() dbRef.showClass = not dbRef.showClass; refreshCallback() end })
        elseif key == "mana" then table.insert(toggles, { text = dbRef.showMana and (L["Disable"] or "禁用") or (L["Enable"] or "启用"), isAction = true, action = function() dbRef.showMana = not dbRef.showMana; refreshCallback() end })
        elseif key == "vigor" then table.insert(toggles, { text = db.showVigor and (L["Disable"] or "禁用") or (L["Enable"] or "启用"), isAction = true, action = function() db.showVigor = not db.showVigor; refreshCallback() end })
        elseif key == "whirling" then table.insert(toggles, { text = db.showWhirling and (L["Disable"] or "禁用") or (L["Enable"] or "启用"), isAction = true, action = function() db.showWhirling = not db.showWhirling; refreshCallback() end })
        elseif string.sub(key, 1, 3) == "WM_" then
            local spellID = string.sub(key, 4); local cfgObj = (wmDB.skills and wmDB.skills[spellID]) or (wmDB.buffs and wmDB.buffs[spellID])
            if cfgObj then table.insert(toggles, { text = cfgObj.enable and (L["Disable Monitor"] or "禁用监控") or (L["Enable Monitor"] or "启用监控"), isAction = true, action = function() cfgObj.enable = not cfgObj.enable; refreshCallback() end }) end
        end

        if targetVisDB then
            table.insert(toggles, { text = L["SmartHide Settings"] or "显示/隐藏条件设置", isAction = true, keepPos = true, action = function() CR.Menu:ShowRightClickMenu(btn, key, title, refreshCallback, "visibility") end })
        end
    end

    if #toggles > 0 then ShowFlatContextMenu(mTitle, toggles) end
end

function CR.Menu:GetPopup()
    if not WF.UI.CRPopup then
        local popup = CreateFrame("Frame", "WishFlex_CRPopup", WF.MainFrame, "BackdropTemplate")
        popup:SetSize(340, 500); popup:SetPoint("CENTER", WF.MainFrame, "CENTER", 100, 0); popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(WF.MainFrame:GetFrameLevel() + 50)
        popup:EnableMouse(true); popup:SetMovable(true); popup:RegisterForDrag("LeftButton"); popup:SetScript("OnDragStart", popup.StartMoving); popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        WF.UI.Factory.ApplyFlatSkin(popup, 0.08, 0.08, 0.08, 0.98, C_R, C_G, C_B, 1)

        popup.titleBg = CreateFrame("Frame", nil, popup, "BackdropTemplate"); popup.titleBg:SetPoint("TOPLEFT", 1, -1); popup.titleBg:SetPoint("TOPRIGHT", -1, -1); popup.titleBg:SetHeight(30)
        WF.UI.Factory.ApplyFlatSkin(popup.titleBg, 0.15, 0.15, 0.15, 1, 0,0,0,0)
        popup.titleText = popup.titleBg:CreateFontString(nil, "OVERLAY"); popup.titleText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); popup.titleText:SetPoint("LEFT", 10, 0); popup.titleText:SetTextColor(0.7, 0.7, 0.7)

        popup.closeBtn = CreateFrame("Button", nil, popup.titleBg); popup.closeBtn:SetSize(20, 20); popup.closeBtn:SetPoint("RIGHT", -5, 0)
        local cTex = popup.closeBtn:CreateTexture(nil, "ARTWORK"); cTex:SetAllPoints(); cTex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); cTex:SetVertexColor(0.6, 0.6, 0.6)
        popup.closeBtn:SetScript("OnEnter", function() cTex:SetVertexColor(1, 0.2, 0.2) end); popup.closeBtn:SetScript("OnLeave", function() cTex:SetVertexColor(0.6, 0.6, 0.6) end)
        
        popup.closeBtn:SetScript("OnClick", function() 
            CR.Sandbox.popupMode = nil; 
            CR.Sandbox.popupSubMenu = nil; 
            popup:Hide(); 
            WF.UI:RefreshCurrentPanel() 
        end)

        local sFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate"); sFrame:SetPoint("TOPLEFT", 10, -40); sFrame:SetPoint("BOTTOMRIGHT", -30, 10)
        local sChild = CreateFrame("Frame"); sChild:SetSize(sFrame:GetWidth(), 1); sFrame:SetScrollChild(sChild)
        popup.scrollFrame = sFrame; popup.scrollChild = sChild
        
        WF.UI.CRPopup = popup
    end
    return WF.UI.CRPopup
end

function CR.Menu:RenderPopupContent(popup, mode, target, tempDB, specCfg, handleCallback)
    local py = -10; local popW = popup.scrollFrame:GetWidth() - 10
    local db = CR.GetDB(); local wmDB = WF.db.wishMonitor or {}
    
    local titleMap = { power=L["Power Bar"] or "能量条", class=L["Class Resource Bar"] or "主资源条", mana=L["Extra Mana Bar"] or "专属法力条", vigor=L["Vigor Bar"] or "驭空术", whirling=L["Whirling Surge Bar"] or "回旋冲刺" }

    if popup.scrollChild.AddConfirmBtn then popup.scrollChild.AddConfirmBtn:Hide() end
    if popup.scrollChild.DelConfirmBtn then popup.scrollChild.DelConfirmBtn:Hide() end
    if popup.scrollChild.AddIconTitle then popup.scrollChild.AddIconTitle:Hide() end
    if popup.scrollChild.AddEmptyTxt then popup.scrollChild.AddEmptyTxt:Hide() end
    if popup.scrollChild.AddIconPool then for _, b in ipairs(popup.scrollChild.AddIconPool) do b:Hide() end end
    if popup.scrollChild.BackBtn then popup.scrollChild.BackBtn:Hide() end

    if popup.scrollChild.optGroups then for _, group in pairs(popup.scrollChild.optGroups) do group:Hide() end end

    if mode == "GLOBAL" then
        popup.titleText:SetText(L["Global Layout Settings"] or "全局排版与设置")
        local globalBaseOpts = {
            { type = "group", key = "cr_global_base", text = L["Global Basic Layout"] or "全局排版基础设定", childs = {
                { type = "toggle", key = "enable", db = db, text = L["Enable Resource System"] or "启用资源条系统", requireReload = true },
                { type = "dropdown", key = "texture", db = db, text = L["Texture"] or "全局材质", options = GetTextureOptions(), callback = handleCallback },
                { type = "dropdown", key = "font", db = db, text = L["Font"] or "字体", options = WF.UI.FontOptions, callback = handleCallback },
                { type = "color", key = "globalBgColor", db = db, text = L["Background Color"] or "背景颜色", callback = handleCallback },
                { type = "dropdown", key = "spec", db = tempDB, text = L["Editing Context"] or "编辑专精环境", options = GetSpecOptions(), callback = function(val) if tempDB.spec ~= CR.selectedSpecForConfig then CR.selectedSpecForConfig = tempDB.spec; WF.UI:RefreshCurrentPanel() end end },
                { type = "slider", key = "width", db = specCfg, text = L["Width"] or "宽度", min=50, max=600, step=1, callback = handleCallback },
                { type = "slider", key = "yOffset", db = specCfg, text = L["Combat Stack Spacing"] or "实战堆叠间距", min=0, max=50, step=1, callback = handleCallback },
                { type = "toggle", key = "alignWithCD", db = db, text = L["Attach to Cooldowns"] or "吸附到冷却管理器上", callback = handleCallback },
                { type = "slider", key = "alignYOffset", db = db, text = L["Attach Y Offset"] or "吸附Y轴偏移", min = -50, max = 50, step = 1, callback = handleCallback },
                { type = "slider", key = "widthOffset", db = db, text = L["Width Compensation"] or "宽度补偿(微调)", min = -10, max = 10, step = 1, callback = handleCallback },
            }}
        }
        py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, globalBaseOpts, handleCallback)

    elseif mode == "ROW" then
        if CR.Sandbox.lastTarget ~= target then
            CR.Sandbox.popupSubMenu = nil
            CR.Sandbox.lastTarget = target
        end

        local subMenu = CR.Sandbox.popupSubMenu
        local cfgDB = nil

        if target == "power" then cfgDB = specCfg.power
        elseif target == "class" then cfgDB = specCfg.class
        elseif target == "mana" then cfgDB = specCfg.mana
        elseif target == "vigor" then cfgDB = db.vigor
        elseif target == "whirling" then cfgDB = db.whirling
        end

        if not subMenu then
            popup:Hide()
            local mTitle = titleMap[target] or target
            local menuItems = {
                { text = L["Basic Appearance"] or "基础外观设定", isAction = true, action = function() CR.Sandbox.popupSubMenu = "basic"; WF.UI:RefreshCurrentPanel() end },
            }

            local isStackBar = (target == "class" or target == "vigor")
            if isStackBar then
                table.insert(menuItems, { text = L["Gradient Color Settings"] or "层数渐变颜色设置", isAction = true, action = function() CR.Sandbox.popupSubMenu = "gradient"; WF.UI:RefreshCurrentPanel() end })
                table.insert(menuItems, { text = L["Stack Color Settings"] or "多阶段突变颜色设置", isAction = true, action = function() CR.Sandbox.popupSubMenu = "threshold"; WF.UI:RefreshCurrentPanel() end })
            else
                table.insert(menuItems, { text = L["Threshold Lines"] or "能量刻度线设置", isAction = true, action = function() CR.Sandbox.popupSubMenu = "lines"; WF.UI:RefreshCurrentPanel() end })
            end

            ShowFlatContextMenu(mTitle, menuItems)
            return
        else
            popup:Show()
            popup.titleText:SetText((titleMap[target] or target) .. " - " .. (L["Settings"] or "详细设置"))
            py = -10 
            local isClassBar = (target == "class")

            if subMenu == "basic" then
                if isClassBar then
                    if type(cfgDB.useCustomColors) ~= "table" then cfgDB.useCustomColors = {} end
                    if type(cfgDB.customColors) ~= "table" then cfgDB.customColors = {} end
                end
                
                local childs = {
                    { type = "toggle", key = "independent", db = cfgDB, text = L["Enable Independent Layout"] or "开启独立排版(脱离堆叠)", callback = handleCallback },
                }
                
                if cfgDB.independent then
                    if not cfgDB.orientation then cfgDB.orientation = "HORIZONTAL" end
                    table.insert(childs, { type = "dropdown", key = "orientation", db = cfgDB, text = L["Bar Orientation"] or "进度条方向", options = { {text=L["Horizontal"] or "水平方向", value="HORIZONTAL"}, {text=L["Vertical"] or "垂直方向", value="VERTICAL"} }, callback = handleCallback })
                    table.insert(childs, { type = "slider", key = "width", db = cfgDB, text = L["Width"] or "长度/宽度", min=10, max=1000, step=1, callback = handleCallback })
                end
                
                table.insert(childs, { type = "slider", key = "height", db = cfgDB, text = L["Height"] or "高度", min=2, max=50, step=1, callback = handleCallback })
                table.insert(childs, { type = "toggle", key = "useCustomTexture", db = cfgDB, text = L["Enable Independent Texture"] or "启用独立材质", callback = handleCallback })
                table.insert(childs, { type = "dropdown", key = "texture", db = cfgDB, text = L["Independent Texture"] or "独立材质选择", options = GetTextureOptions(), callback = handleCallback })
                
                if isClassBar then
                    table.insert(childs, { type = "toggle", key = playerClass, db = cfgDB.useCustomColors, text = L["Enable Independent Color"] or "启用独立颜色", callback = handleCallback })
                    table.insert(childs, { type = "color", key = playerClass, db = cfgDB.customColors, text = L["Foreground Color"] or "独立前景色", callback = handleCallback })
                else
                    table.insert(childs, { type = "toggle", key = "useCustomColor", db = cfgDB, text = L["Enable Independent Color"] or "启用独立颜色", callback = handleCallback })
                    table.insert(childs, { type = "color", key = "customColor", db = cfgDB, text = L["Foreground Color"] or "独立前景色", callback = handleCallback })
                end
                
                table.insert(childs, { type = "toggle", key = "useCustomBgTexture", db = cfgDB, text = L["Enable Independent Background Texture"] or "启用独立背景材质", callback = handleCallback })
                table.insert(childs, { type = "dropdown", key = "bgTexture", db = cfgDB, text = L["Independent Background Texture"] or "背景材质选择", options = GetTextureOptions(), callback = handleCallback })
                table.insert(childs, { type = "toggle", key = "useCustomBgColor", db = cfgDB, text = L["Enable Independent Background Color"] or "启用独立背景色", callback = handleCallback })
                table.insert(childs, { type = "color", key = "bgColor", db = cfgDB, text = L["Independent Background Color"] or "背景色选择", callback = handleCallback })
                
                py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {{type="group", key="opts_b", text=L["Basic Appearance"] or "基础外观设定", childs=childs}}, handleCallback)
            
            elseif subMenu == "text" then
                local tOpts = BuildTextOpts(titleMap[target] or target, cfgDB, handleCallback, true, false)
                py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {tOpts}, handleCallback)
            
            elseif subMenu == "gradient" then
                local childs = BuildGradientOpts(cfgDB, handleCallback)
                py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {childs}, handleCallback)
            
            elseif subMenu == "threshold" then
                local childs = BuildThresholdOpts(cfgDB, handleCallback, (target == "power"))
                py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {childs}, handleCallback)
            
            elseif subMenu == "lines" then
                local lineDB = { line = CR.selectedThresholdLine or 1 }; if not cfgDB.thresholdLines then cfgDB.thresholdLines = {} end
                for i = 1, 5 do if type(cfgDB.thresholdLines[i]) ~= "table" then cfgDB.thresholdLines[i] = {} end end
                local childs = {
                    { type = "dropdown", key = "line", db = lineDB, text = L["Select Line"] or "选择刻度", options = { {text="1", value=1}, {text="2", value=2}, {text="3", value=3}, {text="4", value=4}, {text="5", value=5} }, callback = function() CR.selectedThresholdLine = lineDB.line; WF.UI:RefreshCurrentPanel() end },
                    { type = "toggle", key = "enable", db = cfgDB.thresholdLines[lineDB.line], text = L["Enable"] or "启用", callback = handleCallback },
                    { type = "slider", key = "value", db = cfgDB.thresholdLines[lineDB.line], text = L["Trigger Value"] or "刻度位置数值", min=1, max=300, step=1, callback = handleCallback },
                    { type = "slider", key = "thickness", db = cfgDB.thresholdLines[lineDB.line], text = L["Thickness"] or "线条粗细", min=1, max=10, step=1, callback = handleCallback },
                    { type = "color", key = "color", db = cfgDB.thresholdLines[lineDB.line], text = L["Color"] or "线条颜色", callback = handleCallback },
                }
                py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {{type="group", key="opts_lines", text=L["Threshold Lines"] or "刻度线设置", childs=childs}}, handleCallback)
            end
        end

    elseif mode == "TEXT" then
        popup:Show()
        popup.titleText:SetText((titleMap[target] or target) .. " - " .. (L["Text Layout"] or "文本设置"))
        py = -10
        local cfgDB = nil
        local isBrewmaster = (playerClass == "MONK" and tempDB.spec == 268)

        if target == "power" then cfgDB = specCfg.power
        elseif target == "class" and isBrewmaster then cfgDB = specCfg.class
        elseif target == "mana" then cfgDB = specCfg.mana
        end

        if cfgDB then
            local tOpts = BuildTextOpts(titleMap[target] or target, cfgDB, handleCallback, true, false)
            py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {tOpts}, handleCallback)
        else
            popup.titleText:SetText(L["Monitor Not Found"] or "该模块没有文本设置")
        end

    elseif mode == "ADD_MONITOR" then
        popup.titleText:SetText(L["Add Custom Monitor"] or "添加监控模块")
        local state = CR.Sandbox.newMonitorState or { cat = "buff", type = "time", spell = nil, displayMode = "bar" }
        local sourceCache = state.cat == "skill" and (WF.WishMonitorAPI and WF.WishMonitorAPI.TrackedSkills or {}) or (WF.WishMonitorAPI and WF.WishMonitorAPI.TrackedBuffs or {})
        local sortedKeys = {}; for k in pairs(sourceCache) do table.insert(sortedKeys, k) end; table.sort(sortedKeys, function(a, b) return tonumber(a) < tonumber(b) end)
        if #sortedKeys > 0 and (not state.spell or not sourceCache[state.spell]) then state.spell = sortedKeys[1] end

        -- 【互斥核心逻辑】：确保纯文本和层数永远不会同时存在
        if state.displayMode == "text" then
            if state.cat == "skill" and state.type == "charge" then state.type = "cooldown" end
            if state.cat == "buff" and state.type == "stack" then state.type = "time" end
        end
        if (state.type == "stack" or state.type == "charge") and state.displayMode == "text" then
            state.displayMode = "bar"
        end

        local addOpts = { 
            { type = "dropdown", key = "cat", db = state, text = L["Monitor Type"] or "监控类型", options = { {text=L["Aura/Buff"] or "光环/增益", value="buff"}, {text=L["Spell/Skill"] or "法术/技能", value="skill"} }, callback = function() state.spell = nil; state.type = (state.cat=="skill") and "cooldown" or "time"; handleCallback() end }
        }
        
        -- 显示模式动态选项（如果选了层数，隐藏纯文本）
        local dispOpts = { {text=L["Status Bar"] or "进度条", value="bar"} }
        if state.type ~= "stack" and state.type ~= "charge" then
            table.insert(dispOpts, {text=L["Pure Text"] or "纯文本", value="text"})
        end
        table.insert(addOpts, { type = "dropdown", key = "displayMode", db = state, text = L["Display Mode"] or "显示模式", options = dispOpts, callback = function()
            if state.displayMode == "text" then
                if state.cat == "skill" and state.type == "charge" then state.type = "cooldown" end
                if state.cat == "buff" and state.type == "stack" then state.type = "time" end
            end
            handleCallback()
        end})
        
        -- 机制动态选项（如果选了纯文本，隐藏层数）
        if state.cat == "skill" then
            local typeOpts = { {text=L["Single Cooldown"] or "单一冷却", value="cooldown"} }
            if state.displayMode ~= "text" then
                table.insert(typeOpts, {text=L["Multiple Charges"] or "充能层数", value="charge"})
            end
            table.insert(addOpts, { type = "dropdown", key = "type", db = state, text = L["Skill Mechanism"] or "技能机制", options = typeOpts, callback = function()
                if state.type == "charge" and state.displayMode == "text" then state.displayMode = "bar" end
                handleCallback()
            end})
        else
            local typeOpts = { {text=L["Duration"] or "持续时间", value="time"} }
            if state.displayMode ~= "text" then
                table.insert(typeOpts, {text=L["Stacking"] or "堆叠层数", value="stack"})
            end
            table.insert(addOpts, { type = "dropdown", key = "type", db = state, text = L["Buff Mechanism"] or "增益机制", options = typeOpts, callback = function()
                if state.type == "stack" and state.displayMode == "text" then state.displayMode = "bar" end
                handleCallback()
            end})
        end

        if state.type == "stack" then state.maxStacks = state.maxStacks or 5; table.insert(addOpts, { type = "slider", key = "maxStacks", db = state, text = (L["Max Stacks"] or "最大层数") .. "(0=无上限)", min = 0, max = 30, step = 1, callback = handleCallback }) end
        py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {{type="group", key="add_opts", text="", childs=addOpts}}, handleCallback)

        local iconTitle = popup.scrollChild.AddIconTitle or popup.scrollChild:CreateFontString(nil, "OVERLAY")
        iconTitle:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); iconTitle:SetTextColor(1, 0.82, 0); popup.scrollChild.AddIconTitle = iconTitle
        iconTitle:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 10, py - 5); iconTitle:SetText(L["Click to select target"] or "点击选择目标："); iconTitle:Show(); py = py - 25

        local iconPool = popup.scrollChild.AddIconPool or {}; popup.scrollChild.AddIconPool = iconPool
        local iconSize = 32; local gap = 4; local cols = math.floor((popW - 20) / (iconSize + gap)); if cols < 1 then cols = 1 end; local row, col, count = 0, 0, 0

        if #sortedKeys == 0 then
            local emptyTxt = popup.scrollChild.AddEmptyTxt or popup.scrollChild:CreateFontString(nil, "OVERLAY")
            emptyTxt:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); emptyTxt:SetTextColor(0.5, 0.5, 0.5); popup.scrollChild.AddEmptyTxt = emptyTxt
            emptyTxt:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 10, py); emptyTxt:SetText(L["No Data"] or "暂无数据"); emptyTxt:Show(); py = py - 20
        else
            for _, idStr in ipairs(sortedKeys) do
                local info = sourceCache[idStr]; count = count + 1; local btn = iconPool[count]
                if not btn then btn = CreateFrame("Button", nil, popup.scrollChild, "BackdropTemplate"); btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1}); btn.tex = btn:CreateTexture(nil, "BACKGROUND"); btn.tex:SetAllPoints(); btn.tex:SetTexCoord(0.1, 0.9, 0.1, 0.9); iconPool[count] = btn end
                btn:SetSize(iconSize, iconSize); btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", popup.scrollChild, "TOPLEFT", 10 + col * (iconSize + gap), py - row * (iconSize + gap)); btn.tex:SetTexture(info.icon or 134400)
                if state.spell == idStr then btn:SetBackdropBorderColor(0, 1, 0, 1); btn.tex:SetVertexColor(1, 1, 1) else btn:SetBackdropBorderColor(0, 0, 0, 1); if state.spell then btn.tex:SetVertexColor(0.4, 0.4, 0.4) else btn.tex:SetVertexColor(1, 1, 1) end end
                btn:SetScript("OnClick", function() CR.Sandbox.newMonitorState.spell = idStr; WF.UI:RefreshCurrentPanel() end); btn:Show(); col = col + 1; if col >= cols then col = 0; row = row + 1 end
            end
            py = py - math.ceil(count / cols) * (iconSize + gap) - 10
        end

        local confirmBtn = popup.scrollChild.AddConfirmBtn or WF.UI.Factory:CreateFlatButton(popup.scrollChild, L["Confirm Add"] or "确认添加", function()
            local st = CR.Sandbox.newMonitorState; if not st or not st.spell or st.spell == "" then return end
            if not wmDB.skills then wmDB.skills = {} end; if not wmDB.buffs then wmDB.buffs = {} end
            local targetDB = st.cat == "skill" and wmDB.skills or wmDB.buffs; 
            local isTextMode = (st.displayMode == "text")
            
            local newCfg = { 
                enable = true, specID = tempDB.spec, displayMode = st.displayMode or "bar", 
                alwaysShow = false, color = {r=0,g=0.8,b=1,a=1}, hideOriginal = false, 
                independent = isTextMode, fontSize = isTextMode and 20 or nil, 
                height = 10, width = 250, useCustomBgColor = false, bgColor = {r=0,g=0,b=0,a=0.5}, 
                textEnable = not isTextMode, 
                timerEnable = true 
            }
            
            if st.cat == "skill" then 
                newCfg.trackType = st.type; newCfg.color = {r=1,g=0.5,b=0,a=1}; newCfg.timerAnchor = "CENTER"
            else 
                newCfg.mode = st.type; newCfg.color = {r=0,g=0.8,b=1,a=1}; 
                if st.type == "stack" then newCfg.maxStacks = st.maxStacks or 5 end; 
                newCfg.timerAnchor = "CENTER" 
            end
            
            local targetSaveKey = st.spell
            if isTextMode then
                targetSaveKey = st.spell .. "_TXT"
                newCfg.realSpellID = st.spell 
            end
            targetDB[targetSaveKey] = newCfg

            if newCfg.hideOriginal then
                local idStr = st.spell
                local exactKey = (st.cat == "skill") and ("CD_" .. idStr) or ("BUFF_" .. idStr)
                if WF.db.cooldownCustom then 
                    if not WF.db.cooldownCustom.blacklist then WF.db.cooldownCustom.blacklist = {} end
                    WF.db.cooldownCustom.blacklist[idStr] = nil
                    WF.db.cooldownCustom.blacklist[exactKey] = true 
                end
                if WF.db.auraGlow then if not WF.db.auraGlow.blacklist then WF.db.auraGlow.blacklist = {} end; WF.db.auraGlow.blacklist[idStr] = true end
                if WF.CooldownCustomAPI and WF.CooldownCustomAPI.TriggerLayout then pcall(function() WF.CooldownCustomAPI:TriggerLayout() end) end
            end
            if WF.WishMonitorAPI then WF.WishMonitorAPI:TriggerUpdate() end; CR.Sandbox.popupMode = nil; WF.UI.CRPopup:Hide(); WF.UI:RefreshCurrentPanel()
            StaticPopup_Show("WISHFLEX_RELOAD_CONFIRM")
        end)
        popup.scrollChild.AddConfirmBtn = confirmBtn; confirmBtn:SetPoint("TOP", popup.scrollChild, "TOP", 0, py - 10); confirmBtn:SetWidth(popW - 20); confirmBtn:Show(); py = py - 40

    elseif mode == "EDIT_MONITOR_BAR" or mode == "EDIT_MONITOR_TEXT" then
        local spellID = CR.Sandbox.editMonitorID
        local cat = CR.Sandbox.editMonitorCat

        if CR.Sandbox.lastEditMonitorID ~= spellID then
            CR.Sandbox.popupSubMenu = nil
            CR.Sandbox.lastEditMonitorID = spellID
        end

        local cfg = wmDB and ((cat == "skill" and wmDB.skills[spellID]) or (cat == "buff" and wmDB.buffs[spellID]))
        if cfg then
            
            if not CR.Sandbox.popupSubMenu then
                if mode == "EDIT_MONITOR_TEXT" then
                    CR.Sandbox.popupSubMenu = "text"
                end
            end

            local subMenu = CR.Sandbox.popupSubMenu

            if not subMenu then
                popup:Hide()
                local realIDForTitle = cfg.realSpellID or tostring(spellID):gsub("_TXT", "")
                local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(tonumber(realIDForTitle)) end)
                local mTitle = (spellInfo and spellInfo.name or realIDForTitle) .. " " .. (L["Settings"] or "设置")

                local menuItems = {
                    { text = L["Basic Appearance"] or "基础外观设定", isAction = true, action = function() CR.Sandbox.popupSubMenu = "basic"; WF.UI:RefreshCurrentPanel() end },
                }
                
                local hasStacks = false
                if cat == "buff" and cfg.mode == "stack" then hasStacks = true end
                if cat == "skill" and cfg.trackType == "charge" then hasStacks = true end

                if hasStacks then
                    table.insert(menuItems, { text = L["Gradient Color Settings"] or "层数渐变颜色设置", isAction = true, action = function() CR.Sandbox.popupSubMenu = "gradient"; WF.UI:RefreshCurrentPanel() end })
                    table.insert(menuItems, { text = L["Stack Color Settings"] or "多阶段突变颜色设置", isAction = true, action = function() CR.Sandbox.popupSubMenu = "threshold"; WF.UI:RefreshCurrentPanel() end })
                else
                    table.insert(menuItems, { text = L["Threshold Lines"] or "刻度线设置", isAction = true, action = function() CR.Sandbox.popupSubMenu = "lines"; WF.UI:RefreshCurrentPanel() end })
                end

                table.insert(menuItems, { text = L["Delete This Monitor"] or "彻底删除该监控", isAction = true, action = function()
                    local tSpell = CR.Sandbox.editMonitorID; local tCat = CR.Sandbox.editMonitorCat; if tCat == "skill" then WF.db.wishMonitor.skills[tSpell] = nil else WF.db.wishMonitor.buffs[tSpell] = nil end
                    local idStr = tostring(tSpell):gsub("_TXT", "")
                    if WF.db.cooldownCustom and WF.db.cooldownCustom.blacklist then
                        WF.db.cooldownCustom.blacklist[idStr] = nil; WF.db.cooldownCustom.blacklist["CD_"..idStr] = nil; WF.db.cooldownCustom.blacklist["BUFF_"..idStr] = nil
                    end
                    if WF.db.auraGlow and WF.db.auraGlow.blacklist then WF.db.auraGlow.blacklist[idStr] = nil end
                    if WF.WishMonitorAPI then WF.WishMonitorAPI:TriggerUpdate() end; CR.Sandbox.popupMode = nil; CR.Sandbox.popupSubMenu = nil; WF.UI.CRPopup:Hide(); WF.UI:RefreshCurrentPanel()
                    StaticPopup_Show("WISHFLEX_RELOAD_CONFIRM")
                end })

                ShowFlatContextMenu(mTitle, menuItems)
                return 
            else
                popup:Show()
                local realIDForTitle = cfg.realSpellID or tostring(spellID):gsub("_TXT", "")
                local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(tonumber(realIDForTitle)) end)
                popup.titleText:SetText((mode=="EDIT_MONITOR_BAR" and (L["Bar Layout"] or "排版设置")..": " or (L["Pure Text Layout"] or "纯文本设置")..": ") .. (spellInfo and spellInfo.name or realIDForTitle))
                py = -10

                if subMenu == "basic" then
                    local childs = {
                        { type = "toggle", key = "independent", db = cfg, text = L["Enable Independent Layout"] or "开启独立排版(脱离堆叠)", callback = handleCallback },
                    }
                    
                    if cfg.independent then
                        if not cfg.orientation then cfg.orientation = "HORIZONTAL" end
                        table.insert(childs, { type = "dropdown", key = "orientation", db = cfg, text = L["Bar Orientation"] or "进度条方向", options = { {text=L["Horizontal"] or "水平方向", value="HORIZONTAL"}, {text=L["Vertical"] or "垂直方向", value="VERTICAL"} }, callback = handleCallback })
                        table.insert(childs, { type = "slider", key = "width", db = cfg, text = L["Width"] or "长度/宽度", min = 10, max = 1000, step = 1, callback = handleCallback })
                    end
                    
                    table.insert(childs, { type = "slider", key = "height", db = cfg, text = L["Height"] or "高度", min=2, max=50, step=1, callback = handleCallback })
                    
                    local isStackMode = (cfg.mode == "stack" or cfg.trackType == "charge")
                    if isStackMode then
                        table.insert(childs, { type = "slider", key = "maxStacks", db = cfg, text = (L["Max Stacks"] or "最大层数").."(0=无上限)", min = 0, max = 30, step = 1, callback = handleCallback })
                    end

                    table.insert(childs, { type = "toggle", key = "alwaysShow", db = cfg, text = L["Always Show Background"] or "常驻显示背景", callback = handleCallback })
                    table.insert(childs, { type = "toggle", key = "reverseFill", db = cfg, text = L["Reverse Fill"] or "反向填充", callback = handleCallback })
                    table.insert(childs, { type = "color", key = "color", db = cfg, text = L["Foreground Color"] or "默认前景色", callback = handleCallback })
                    table.insert(childs, { type = "toggle", key = "useCustomTexture", db = cfg, text = L["Enable Independent Texture"] or "启用独立材质", callback = handleCallback })
                    table.insert(childs, { type = "dropdown", key = "texture", db = cfg, text = L["Independent Texture"] or "独立材质选择", options = GetTextureOptions(), callback = handleCallback })
                    table.insert(childs, { type = "toggle", key = "useCustomBgTexture", db = cfg, text = L["Enable Independent Background Texture"] or "启用独立背景材质", callback = handleCallback })
                    table.insert(childs, { type = "dropdown", key = "bgTexture", db = cfg, text = L["Independent Background Texture"] or "背景材质选择", options = GetTextureOptions(), callback = handleCallback })
                    table.insert(childs, { type = "toggle", key = "useCustomBgColor", db = cfg, text = L["Enable Independent Background Color"] or "启用独立背景色", callback = handleCallback })
                    table.insert(childs, { type = "color", key = "bgColor", db = cfg, text = L["Independent Background Color"] or "独立背景色", callback = function() cfg.useCustomBgColor = true; handleCallback() end })
                    table.insert(childs, { type = "toggle", key = "hideOriginal", db = cfg, text = L["Hide in Original UI"] or "在原模块中隐身", callback = function()
                        local idStr = tostring(spellID):gsub("_TXT", "")
                        local hide = cfg.hideOriginal
                        local exactKey = (cat == "skill") and ("CD_" .. idStr) or ("BUFF_" .. idStr)
                        if WF.db.cooldownCustom then
                            if not WF.db.cooldownCustom.blacklist then WF.db.cooldownCustom.blacklist = {} end
                            WF.db.cooldownCustom.blacklist[idStr] = nil
                            WF.db.cooldownCustom.blacklist[exactKey] = hide and true or nil
                        end
                        if WF.db.auraGlow then if not WF.db.auraGlow.blacklist then WF.db.auraGlow.blacklist = {} end; WF.db.auraGlow.blacklist[idStr] = hide and true or nil end
                        if WF.CooldownCustomAPI and WF.CooldownCustomAPI.TriggerLayout then pcall(function() WF.CooldownCustomAPI:TriggerLayout() end) end; handleCallback()
                        StaticPopup_Show("WISHFLEX_RELOAD_CONFIRM")
                    end })
                    
                    py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {{type="group", key="mon_b", text=L["Basic Appearance"] or "基础外观设定", childs=childs}}, handleCallback)

                elseif subMenu == "text" then
                    local childs = {
                        { type = "toggle", key = "timerEnable", db = cfg, text = L["Enable Timer Text"] or "启用计时文本", callback = handleCallback },
                        { type = "dropdown", key = "timerAnchor", db = cfg, text = L["Timer Text Anchor"] or "锚点位置", options = {
                            {text=L["TOPLEFT"] or "左上",value="TOPLEFT"}, {text=L["TOP"] or "上方",value="TOP"}, {text=L["TOPRIGHT"] or "右上",value="TOPRIGHT"},
                            {text=L["LEFT"] or "靠左",value="LEFT"}, {text=L["CENTER"] or "居中",value="CENTER"}, {text=L["RIGHT"] or "靠右",value="RIGHT"},
                            {text=L["BOTTOMLEFT"] or "左下",value="BOTTOMLEFT"}, {text=L["BOTTOM"] or "下方",value="BOTTOM"}, {text=L["BOTTOMRIGHT"] or "右下",value="BOTTOMRIGHT"}
                        }, callback = handleCallback },
                        { type = "slider", key = "fontSize", db = cfg, text = L["Font Size"] or "字体大小", min = 1, max = 64, step = 1, callback = handleCallback },
                        { type = "slider", key = "timerXOffset", db = cfg, text = L["X Offset"] or "X轴偏移", min=-200, max=200, step=1, callback = handleCallback },
                        { type = "slider", key = "timerYOffset", db = cfg, text = L["Y Offset"] or "Y轴偏移", min=-100, max=100, step=1, callback = handleCallback },
                        { type = "color", key = "textColor", db = cfg, text = L["Text Color"] or "文本颜色", callback = handleCallback },
                    }
                    py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {{type="group", key="mon_t", text=L["Timer Text Layout"] or "文本排版设定", childs=childs}}, handleCallback)
                
                elseif subMenu == "gradient" then
                    local gOpts = BuildGradientOpts(cfg, handleCallback)
                    if gOpts then py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {gOpts}, handleCallback) end
                
                elseif subMenu == "threshold" then
                    local tOpts = BuildThresholdOpts(cfg, handleCallback, false)
                    if tOpts then py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, {tOpts}, handleCallback) end
                    
                elseif subMenu == "lines" then
                    local lineDB = { line = CR.selectedThresholdLine or 1 }; if not cfg.thresholdLines then cfg.thresholdLines = {} end
                    for i = 1, 5 do if type(cfg.thresholdLines[i]) ~= "table" then cfg.thresholdLines[i] = {} end end
                    local opts = { { type = "group", key = "p4", text = L["Threshold Lines"] or "阈值刻度线", childs = {
                        { type = "dropdown", key = "line", db = lineDB, text = L["Select Line"] or "选择刻度", options = { {text="1", value=1}, {text="2", value=2}, {text="3", value=3}, {text="4", value=4}, {text="5", value=5} }, callback = function() CR.selectedThresholdLine = lineDB.line; WF.UI:RefreshCurrentPanel() end },
                        { type = "toggle", key = "enable", db = cfg.thresholdLines[lineDB.line], text = L["Enable"] or "启用", callback = handleCallback },
                        { type = "slider", key = "value", db = cfg.thresholdLines[lineDB.line], text = L["Trigger Value"] or "刻度位置数值", min=1, max=300, step=1, callback = handleCallback },
                        { type = "slider", key = "thickness", db = cfg.thresholdLines[lineDB.line], text = L["Thickness"] or "线条粗细", min=1, max=10, step=1, callback = handleCallback },
                        { type = "color", key = "color", db = cfg.thresholdLines[lineDB.line], text = L["Color"] or "线条颜色", callback = handleCallback },
                    }} }
                    py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, opts, handleCallback)
                end

                if mode == "EDIT_MONITOR_BAR" or mode == "EDIT_MONITOR_TEXT" then
                    local delBtn = popup.scrollChild.DelConfirmBtn or WF.UI.Factory:CreateFlatButton(popup.scrollChild, L["Delete This Monitor"] or "彻底删除此监控", function()
                        local tSpell = CR.Sandbox.editMonitorID; local tCat = CR.Sandbox.editMonitorCat; if tCat == "skill" then WF.db.wishMonitor.skills[tSpell] = nil else WF.db.wishMonitor.buffs[tSpell] = nil end
                        local idStr = tostring(tSpell):gsub("_TXT", "")
                        if WF.db.cooldownCustom and WF.db.cooldownCustom.blacklist then
                            WF.db.cooldownCustom.blacklist[idStr] = nil; WF.db.cooldownCustom.blacklist["CD_"..idStr] = nil; WF.db.cooldownCustom.blacklist["BUFF_"..idStr] = nil
                        end
                        if WF.db.auraGlow and WF.db.auraGlow.blacklist then WF.db.auraGlow.blacklist[idStr] = nil end
                        if WF.WishMonitorAPI then WF.WishMonitorAPI:TriggerUpdate() end; CR.Sandbox.popupMode = nil; CR.Sandbox.popupSubMenu = nil; WF.UI.CRPopup:Hide(); WF.UI:RefreshCurrentPanel()
                        StaticPopup_Show("WISHFLEX_RELOAD_CONFIRM")
                    end)
                    popup.scrollChild.DelConfirmBtn = delBtn
                    delBtn:SetPoint("TOP", popup.scrollChild, "TOP", 0, py - 10)
                    delBtn:SetWidth(popW - 20)
                    delBtn:Show()
                    py = py - 45
                end
            end
        else
            popup.titleText:SetText(L["Monitor Not Found"] or "未找到目标")
            if popup.scrollChild.DelConfirmBtn then popup.scrollChild.DelConfirmBtn:Hide() end
        end
    end
    
    if py == -10 then CR.Sandbox.popupMode = nil; popup:Hide() else popup.scrollChild:SetHeight(math_abs(py) + 20); popup:Show() end
end