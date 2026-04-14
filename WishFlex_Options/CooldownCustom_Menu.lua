local AddonName, ns = ...
local WF = _G.WishFlex
local L = WF.L

WF.CooldownCustomAPI = WF.CooldownCustomAPI or {}
local CDMod = WF.CooldownCustomAPI
CDMod.Menu = {}

local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local CR, CG, CB = ClassColor.r, ClassColor.g, ClassColor.b

-- ==========================================
-- [ 确认框体注册 ]
-- ==========================================
StaticPopupDialogs["WISHFLEX_RELOAD_CONFIRM"] = {
    text = "|cff00ffccWishFlex|r: " .. (L["Changing visibility of active buffs requires a UI Reload. Do it now?"] or "修改正在生效的增益显示状态需要重载界面，是否现在重载？"),
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ==========================================
-- [ 辅助函数 ]
-- ==========================================
local function GetDynamicGlowOptions(dbRef, isAuraGlow, titleStr, cb)
    local kType = isAuraGlow and "glowType" or "glowType"
    local kColor = isAuraGlow and "glowColor" or "color"
    local kUseColor = isAuraGlow and "glowUseCustomColor" or "useCustomColor"

    local opts = {
        { type = "dropdown", key = kType, db = dbRef, text = L["Glow Style Selection"] or "发光样式选择", options = {
            {text=L["Pixel Glow"] or "像素框", value="pixel"}, {text=L["Autocast Animation"] or "自闭动画", value="autocast"},
            {text=L["Blizzard Default Border"] or "暴雪默认边框", value="button"}, {text=L["Proc Highlight"] or "触发高亮", value="proc"}
        }, callback = function() if cb then cb("UI_REFRESH") end end },
        { type = "toggle", key = kUseColor, db = dbRef, text = L["Enable Custom Color"] or "启用自定义颜色", callback = cb },
        { type = "color", key = kColor, db = dbRef, text = L["Glow Color"] or "发光颜色", callback = cb },
    }

    local currentType = dbRef[kType] or "pixel"
    if currentType == "pixel" then
        table.insert(opts, { type = "slider", key = isAuraGlow and "glowPixelLines" or "pixelLines", db = dbRef, min = 1, max = 20, step = 1, text = L["Line Count"] or "线条数量", callback = cb })
        table.insert(opts, { type = "slider", key = isAuraGlow and "glowPixelFrequency" or "pixelFrequency", db = dbRef, min = 0.05, max = 2, step = 0.05, text = L["Flash Frequency"] or "闪烁频率", callback = cb })
        table.insert(opts, { type = "slider", key = isAuraGlow and "glowPixelThickness" or "pixelThickness", db = dbRef, min = 1, max = 10, step = 1, text = L["Line Thickness"] or "线条厚度", callback = cb })
    elseif currentType == "autocast" then
        table.insert(opts, { type = "slider", key = isAuraGlow and "glowAutocastParticles" or "autocastParticles", db = dbRef, min = 1, max = 10, step = 1, text = L["Particle Count"] or "粒子数量", callback = cb })
        table.insert(opts, { type = "slider", key = isAuraGlow and "glowAutocastScale" or "autocastScale", db = dbRef, min = 0.5, max = 3, step = 0.1, text = L["Scale"] or "缩放比例", callback = cb })
    elseif currentType == "proc" then
        table.insert(opts, { type = "slider", key = isAuraGlow and "glowProcDuration" or "procDuration", db = dbRef, min = 0.5, max = 5, step = 0.1, text = L["Single Duration"] or "单次持续时间", callback = cb })
    end
    return opts
end

local function CreateSandboxContextMenu()
    if WF.UI.SandboxMenu then return WF.UI.SandboxMenu end
    local m = CreateFrame("Frame", "WF_SandboxContextMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("TOOLTIP"); m:SetSize(260, 200)
    WF.UI.Factory.ApplyFlatSkin(m, 0.05, 0.05, 0.05, 0.98, CR, CG, CB, 1)
    m.title = m:CreateFontString(nil, "OVERLAY"); m.title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); m.title:SetPoint("TOP", 0, -12); m.title:SetTextColor(1, 0.82, 0)
    m.closeBtn = CreateFrame("Button", nil, m); m.closeBtn:SetSize(16, 16); m.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    local cTex = m.closeBtn:CreateTexture(nil, "ARTWORK"); cTex:SetAllPoints(); cTex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); cTex:SetVertexColor(0.6, 0.6, 0.6)
    m.closeBtn:SetScript("OnEnter", function() cTex:SetVertexColor(1, 0.2, 0.2) end); m.closeBtn:SetScript("OnLeave", function() cTex:SetVertexColor(0.6, 0.6, 0.6) end); m.closeBtn:SetScript("OnClick", function() m:Hide() end)
    m.items = {}
    m:SetScript("OnUpdate", function(self) if self:IsShown() and not self:IsMouseOver() then if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then self:Hide() end end end)
    m:Hide()
    WF.UI.SandboxMenu = m
    return m
end

local function IsBuffCat(c) return (c == "BuffIcon" or c == "BuffBar" or c == "ItemBuff" or (c and string.sub(c, 1, 13) == "CustomBuffRow")) end
local function IsSkillCat(c) return (c == "Essential" or c == "Utility" or c == "Defensive" or (c and string.sub(c, 1, 9) == "CustomRow")) end

-- ==========================================
-- [ 右键菜单核心逻辑 ]
-- ==========================================
function CDMod.Menu:ShowRightClickMenu(btn, spellID, spellName, catName, emData, refreshCallback, subMenu)
    if catName == "ItemBuff" then return end 
    
    local EM = WF.ExtraMonitorAPI
    local toggles = {}
    local m = CreateSandboxContextMenu()
    for _, b in ipairs(m.items) do b:Hide() end

    local emDB = WF.db.extraMonitor or {}
    local catDB = WF.db.cooldownCustom and WF.db.cooldownCustom[catName]

    if subMenu == "visibility" then
        local targetVisDB = (catName == "ExtraMonitor") and emDB or catDB
        if targetVisDB then
            if not targetVisDB.visibility then targetVisDB.visibility = { enable = false, hideOOC = true, dragonriding = false, friendly = false, vehicle = false } end
            local vis = targetVisDB.visibility
            
            table.insert(toggles, { text = L["<- Back to Menu"] or "<- 返回上一级菜单", isAction = true, keepPos = true, action = function() CDMod.Menu:ShowRightClickMenu(btn, spellID, spellName, catName, emData, refreshCallback, nil) end })
            table.insert(toggles, { text = L["Enable SmartHide"] or "开启条件隐藏", state = vis.enable, toggle = function() vis.enable = not vis.enable; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback() end })
            
            if vis.enable then
                table.insert(toggles, { text = L["├ Hide Out of Combat"] or "  ├ 脱战且无目标时隐藏", state = vis.hideOOC, toggle = function() vis.hideOOC = not vis.hideOOC; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback() end })
                table.insert(toggles, { text = L["├ Hide on Friendly"] or "  ├ 目标为友方时隐藏", state = vis.friendly, toggle = function() vis.friendly = not vis.friendly; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback() end })
                table.insert(toggles, { text = L["├ Hide Flying"] or "  ├ 飞行时强制隐藏", state = vis.dragonriding, toggle = function() vis.dragonriding = not vis.dragonriding; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback() end })
                table.insert(toggles, { text = L["└ Hide in Vehicle"] or "  └ 乘坐载具时隐藏", state = vis.vehicle, toggle = function() vis.vehicle = not vis.vehicle; if WF.SmartFader then WF.SmartFader:UpdateVisibility() end; refreshCallback() end })
            end
        end
        m.title:SetText(L["Visibility Settings"] or "显示条件设置")
        m.title:Show()
    else
        if catName == "ExtraMonitor" and emData then
            if emData.isTrinket then table.insert(toggles, { text = L["Auto Recognize Trinkets"] or "自动识别主动饰品", state = emDB.autoTrinkets, toggle = function() emDB.autoTrinkets = not emDB.autoTrinkets; refreshCallback() end })
            elseif emData.isRacial then table.insert(toggles, { text = L["Auto Recognize Racials"] or "自动识别种族技能", state = emDB.autoRacial, toggle = function() emDB.autoRacial = not emDB.autoRacial; refreshCallback() end })
            elseif emData.type == "item" then
                table.insert(toggles, { text = L["Enable Item Monitor"] or "启用此物品监控", state = emDB.customItems[emData.id], toggle = function() emDB.customItems[emData.id] = not emDB.customItems[emData.id]; refreshCallback() end })
                table.insert(toggles, { text = string.format("|cffff0000%s|r", L["Delete This Monitor"] or "删除此监控"), isAction = true, action = function() emDB.customItems[emData.id] = nil; if WF.UI.SandboxMenu then WF.UI.SandboxMenu:Hide() end; refreshCallback() end })
            elseif emData.type == "spell" then
                table.insert(toggles, { text = L["Enable Spell Monitor"] or "启用此法术监控", state = emDB.customSpells[emData.id], toggle = function() emDB.customSpells[emData.id] = not emDB.customSpells[emData.id]; refreshCallback() end })
                table.insert(toggles, { text = string.format("|cffff0000%s|r", L["Delete This Monitor"] or "删除此监控"), isAction = true, action = function() emDB.customSpells[emData.id] = nil; if WF.UI.SandboxMenu then WF.UI.SandboxMenu:Hide() end; refreshCallback() end })
            end

            table.insert(toggles, { text = L["SmartHide Settings ->"] or "显示/隐藏条件设置 ->", isAction = true, keepPos = true, action = function() CDMod.Menu:ShowRightClickMenu(btn, spellID, spellName, catName, emData, refreshCallback, "visibility") end })

            m.title:SetText(emData.name or L["Extra Monitor"] or "额外监控")
            m.title:Show() 
        else
            local agDB = WF.db.auraGlow or { spells = {} }

            if catName == "CustomEffects" then
                local pID = tostring(spellID); local isDisabled = agDB.disabledPresets and agDB.disabledPresets[pID]
                table.insert(toggles, { text = L["Toggle Monitor Group"] or "停用/开启此监控组", state = not isDisabled, toggle = function() 
                    if not agDB.disabledPresets then agDB.disabledPresets = {} end
                    if agDB.disabledPresets[pID] then agDB.disabledPresets[pID] = nil else agDB.disabledPresets[pID] = true end
                    CDMod:MarkLayoutDirty(true); refreshCallback() 
                end })
            end

            if IsBuffCat(catName) or IsSkillCat(catName) then
                local myGlowDB = WF.db.auraGlow and WF.db.auraGlow.spells and WF.db.auraGlow.spells[tostring(spellID)]
                local isGlowEnabled = myGlowDB and myGlowDB.glowEnable or false
                table.insert(toggles, { text = L["Glow on Trigger"] or "触发时高亮发光", state = isGlowEnabled, toggle = function() 
                    if not WF.db.auraGlow then WF.db.auraGlow = {spells={}} end
                    if not WF.db.auraGlow.spells then WF.db.auraGlow.spells = {} end
                    if not WF.db.auraGlow.spells[tostring(spellID)] then WF.db.auraGlow.spells[tostring(spellID)] = {glowEnable=false} end
                    WF.db.auraGlow.spells[tostring(spellID)].glowEnable = not isGlowEnabled
                    if WF.AuraGlowAPI and WF.AuraGlowAPI.UpdateGlows then WF.AuraGlowAPI:UpdateGlows(true) end
                    refreshCallback()
                end })
            end
            
            if catName == "BuffIcon" then
                local dbKey = btn.dbKey or tostring(spellID)
                local isBlacklisted = WF.db.cooldownCustom and WF.db.cooldownCustom.blacklist and (WF.db.cooldownCustom.blacklist[dbKey] or WF.db.cooldownCustom.blacklist[tostring(spellID)])
                table.insert(toggles, { text = L["Hide this Icon"] or "在实际界面中隐藏此图标", state = isBlacklisted, toggle = function()
                    if not WF.db.cooldownCustom.blacklist then WF.db.cooldownCustom.blacklist = {} end
                    if WF.db.cooldownCustom.blacklist[tostring(spellID)] then
                        WF.db.cooldownCustom.blacklist[tostring(spellID)] = nil
                        isBlacklisted = true
                    end
                    WF.db.cooldownCustom.blacklist[dbKey] = not isBlacklisted
                    StaticPopup_Show("WISHFLEX_RELOAD_CONFIRM")
                end })
            end

            if IsBuffCat(catName) or IsSkillCat(catName) then
                table.insert(toggles, { text = L["SmartHide Settings ->"] or "显示/隐藏条件设置 ->", isAction = true, keepPos = true, action = function() CDMod.Menu:ShowRightClickMenu(btn, spellID, spellName, catName, emData, refreshCallback, "visibility") end })
            end

            table.insert(toggles, { text = L["Detailed Glow Settings"] or "发光样式详细设置", isAction = true, action = function() 
                CDMod.Sandbox.popupMode = "GLOW"
                CDMod.Sandbox.popupTarget = spellID
                if WF.UI.GroupState then WF.UI.GroupState["sb_glow_native"] = true; WF.UI.GroupState["sb_glow_aura"] = true end
                if WF.UI.SandboxMenu then WF.UI.SandboxMenu:Hide() end
                if WF.UI.RefreshCurrentPanel then WF.UI:RefreshCurrentPanel() end 
            end })

            m.title:SetText("")
            m.title:Hide() 
        end
    end

    if #toggles == 0 then return end
    local yOff = -35 
    if not m.title:IsShown() then yOff = -15 end
    
    for _, tData in ipairs(toggles) do
        local idx = #m.items + 1; local b = m.items[idx]
        if not b then 
            b = CreateFrame("Button", nil, m, "BackdropTemplate"); b:SetSize(240, 26); 
            b.hoverBg = b:CreateTexture(nil, "BACKGROUND"); b.hoverBg:SetColorTexture(CR, CG, CB, 0.25); b.hoverBg:Hide()
            b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); 
            b.track = b:CreateTexture(nil, "ARTWORK"); b.track:SetSize(26, 12); b.track:SetPoint("LEFT", 12, 0); 
            b.thumb = b:CreateTexture(nil, "OVERLAY"); b.thumb:SetSize(10, 10); 
            table.insert(m.items, b) 
        end
        b.text:SetTextColor(0.7, 0.7, 0.7); b.text:SetText(tData.text)
        b:SetScript("OnEnter", function(self) self.hoverBg:Show() end); b:SetScript("OnLeave", function(self) self.hoverBg:Hide() end)
        
        if tData.isAction then
            b.track:Hide(); b.thumb:Hide(); b.text:SetPoint("LEFT", 15, 0)
            b.hoverBg:SetPoint("TOPLEFT", b, "TOPLEFT", 10, 0); b.hoverBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 0)
            b:SetScript("OnClick", function() 
                if tData.keepPos then m.keepPosition = true end
                tData.action() 
            end)
        else
            b.track:Show(); b.thumb:Show(); b.text:SetPoint("LEFT", 48, 0)
            b.hoverBg:SetPoint("TOPLEFT", b, "TOPLEFT", 42, 0); b.hoverBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 0)
            if tData.state then b.track:SetColorTexture(CR, CG, CB, 1); b.thumb:SetColorTexture(1, 1, 1, 1); b.thumb:SetPoint("CENTER", b.track, "RIGHT", -6, 0) 
            else b.track:SetColorTexture(0.2, 0.2, 0.2, 1); b.thumb:SetColorTexture(0.6, 0.6, 0.6, 1); b.thumb:SetPoint("CENTER", b.track, "LEFT", 6, 0) end
            b:SetScript("OnClick", function() 
                m.keepPosition = true
                tData.toggle() 
                CDMod.Menu:ShowRightClickMenu(btn, spellID, spellName, catName, emData, refreshCallback, subMenu) 
            end) 
        end
        b:ClearAllPoints(); b:SetPoint("TOP", 0, yOff); b:Show(); WF.UI.Factory.ApplyFlatSkin(b, 0,0,0,0, 0,0,0,0); yOff = yOff - 28
    end
    
    m:SetHeight(math.abs(yOff) + 15)
    if not m.keepPosition then
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cx/scale) + 10, (cy/scale) - 10)
    end
    m.keepPosition = false
    m:Show()
end

-- ==========================================
-- [ 弹窗设置面板渲染 ]
-- ==========================================
function CDMod.Menu:GetPopup()
    if not WF.UI.CDPopup then
        local popup = CreateFrame("Frame", "WishFlex_CDPopup", WF.MainFrame, "BackdropTemplate")
        popup:SetSize(340, 500); popup:SetPoint("CENTER", WF.MainFrame, "CENTER", 100, 0)
        popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(WF.MainFrame:GetFrameLevel() + 50)
        popup:EnableMouse(true); popup:SetMovable(true); popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving); popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        WF.UI.Factory.ApplyFlatSkin(popup, 0.08, 0.08, 0.08, 0.98, CR, CG, CB, 1)

        popup.titleBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        popup.titleBg:SetPoint("TOPLEFT", 1, -1); popup.titleBg:SetPoint("TOPRIGHT", -1, -1); popup.titleBg:SetHeight(30)
        WF.UI.Factory.ApplyFlatSkin(popup.titleBg, 0.15, 0.15, 0.15, 1, 0,0,0,0)
        popup.titleText = popup.titleBg:CreateFontString(nil, "OVERLAY")
        popup.titleText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); popup.titleText:SetPoint("LEFT", 10, 0); popup.titleText:SetTextColor(0.7, 0.7, 0.7)

        popup.closeBtn = CreateFrame("Button", nil, popup.titleBg); popup.closeBtn:SetSize(20, 20); popup.closeBtn:SetPoint("RIGHT", -5, 0)
        local cTex = popup.closeBtn:CreateTexture(nil, "ARTWORK"); cTex:SetAllPoints(); cTex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); cTex:SetVertexColor(0.6, 0.6, 0.6)
        popup.closeBtn:SetScript("OnEnter", function() cTex:SetVertexColor(1, 0.2, 0.2) end); popup.closeBtn:SetScript("OnLeave", function() cTex:SetVertexColor(0.6, 0.6, 0.6) end)
        popup.closeBtn:SetScript("OnClick", function() CDMod.Sandbox.popupMode = nil; popup:Hide(); WF.UI:RefreshCurrentPanel() end)

        local sFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
        sFrame:SetPoint("TOPLEFT", 10, -40); sFrame:SetPoint("BOTTOMRIGHT", -30, 10)
        local sChild = CreateFrame("Frame"); sChild:SetSize(sFrame:GetWidth(), 1); sFrame:SetScrollChild(sChild)
        popup.scrollFrame = sFrame; popup.scrollChild = sChild
        
        popup:Hide()
        WF.UI.CDPopup = popup
    end
    return WF.UI.CDPopup
end

function CDMod.Menu:RenderPopupContent(popup, mode, target, db, handleCallback, refreshEMCallback)
    local py = -10
    local popW = popup.scrollFrame:GetWidth() - 10
    local dbEM = WF.db.extraMonitor or {}

    if mode == "GLOBAL" then
        popup.titleText:SetText(L["Global Layout & Settings"] or "全局排版与通用设置")
        if not db.ExtraMonitor then db.ExtraMonitor = {} end

        local globalBaseOpts = {
            { type = "group", key = "cd_global_base", text = L["Global Core Module Settings"] or "全局核心模块设置", childs = { 
                { type = "toggle", key = "enable", db = db, text = L["Enable Layout Management Module"] or "启用排版管理模块", requireReload = true }, 
                { type = "dropdown", key = "countFont", db = db, text = L["Global Number Font"] or "全局数字字体", options = WF.UI.FontOptions or {"Expressway"} }, 
                { type = "color", key = "swipeColor", db = db, text = L["Default Swipe Color"] or "默认冷却遮罩颜色" }, 
                { type = "color", key = "activeAuraColor", db = db, text = L["Active Swipe Color"] or "激活时冷却遮罩颜色" }, 
                { type = "toggle", key = "reverseSwipe", db = db, text = L["Reverse Swipe"] or "反转冷却转圈方向", callback = handleCallback },
            } },
            { type = "group", key = "cd_snap_settings", text = L["Snap & Attach Settings"] or "吸附与对齐设置", childs = {
                { type = "toggle", key = "snapToEssential", db = db.Utility, text = L["Utility Snap to Essential"] or "实用组吸附到核心组下方", callback = handleCallback },
                { type = "toggle", key = "snapToResource", db = db.BuffIcon, text = L["Buff Icon Snap to Resource"] or "增益图标吸附到资源条", callback = function(val) db.BuffIcon.snapToResource = val; if val then db.BuffIcon.snapToEssential = false end; handleCallback("UI_REFRESH") end },
                { type = "toggle", key = "snapToEssential", db = db.BuffIcon, text = L["Buff Icon Snap to Essential"] or "增益图标吸附到核心组", callback = function(val) db.BuffIcon.snapToEssential = val; if val then db.BuffIcon.snapToResource = false end; handleCallback("UI_REFRESH") end },
                -- 【新增：加入吸附设置】
                { type = "toggle", key = "snapToBuffIcon", db = db.ItemBuff, text = L["Item Buff Snap to Buff Icon"] or "物品/药水组吸附增益组", callback = handleCallback }, 
                { type = "toggle", key = "attachToPlayer", db = db.Defensive, text = L["Defensive Attach to Player"] or "防御组吸附玩家头像", callback = handleCallback },
                { type = "toggle", key = "attachToPlayer", db = db.ExtraMonitor, text = L["Extra Monitor Attach to Player"] or "额外监控吸附玩家头像", callback = handleCallback },
            } }
        }
        py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, globalBaseOpts, handleCallback)
    
    elseif mode == "GLOW" then
        popup.titleText:SetText(L["Detailed Glow Settings"] or "发光样式详细设置")
        if type(WF.db.glow) ~= "table" then WF.db.glow = {} end
        if type(WF.db.auraGlow) ~= "table" then WF.db.auraGlow = { spells = {} } end
        
        local nativeOpts = { { type = "toggle", key = "enable", db = WF.db.glow, text = L["Enable Blizzard Native Glow Override"] or "启用暴雪原生发光接管", callback = handleCallback } }
        for _, o in ipairs(GetDynamicGlowOptions(WF.db.glow, false, L["Native Cooldown Glow"] or "原生冷却高亮", handleCallback)) do table.insert(nativeOpts, o) end
        
        local auraOpts = { { type = "toggle", key = "enable", db = WF.db.auraGlow, text = L["Enable Custom Status Glow"] or "启用自定义状态高亮", callback = handleCallback } }
        for _, o in ipairs(GetDynamicGlowOptions(WF.db.auraGlow, true, L["Custom Status Frame"] or "自定义状态提示框", handleCallback)) do table.insert(auraOpts, o) end

        local glowDynamicOpts = {
            { type = "group", key = "sb_glow_native", text = L["Native Cooldown Glow"] or "暴雪原生冷却高亮", childs = nativeOpts },
            { type = "group", key = "sb_glow_aura", text = L["Custom Status Frame"] or "自定义状态提示框", childs = auraOpts }
        }
        py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, glowDynamicOpts, handleCallback)
    
    elseif mode == "ROW" then
        popup.titleText:SetText((L["Layout & Size Settings"] or "布局与尺寸设置 - ") .. tostring(target))
        
        if popup.scrollChild.emItemInput then popup.scrollChild.emItemInput:Hide() end
        if popup.scrollChild.btnAdd1 then popup.scrollChild.btnAdd1:Hide() end
        if popup.scrollChild.emSpellInput then popup.scrollChild.emSpellInput:Hide() end
        if popup.scrollChild.btnAdd2 then popup.scrollChild.btnAdd2:Hide() end

        local rowOpts = nil
        local catDB = db[target] or {}
        
        if target == "Essential" or target == "Utility" or target == "Defensive" or target == "BuffIcon" then
            rowOpts = { { type = "group", key = "sb_"..target, text = target .. (L["Group Layout"] or " 组排版"), childs = {
                { type = "slider", key = "iconGap", db = catDB, min = 0, max = 50, step = 1, text = L["Gap"] or "间距" },
                { type = "slider", key = "width", db = catDB, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "height", db = catDB, min = 10, max = 100, step = 1, text = L["Height"] or "高度" }
            } } }
        elseif target == "BuffBar" then
            rowOpts = { { type = "group", key = "sb_bb", text = L["Buff Bar Group"] or "增益条组", childs = { 
                { type = "toggle", key = "showIcon", db = catDB, text = L["Show Skill Icon"] or "显示技能图标", callback = handleCallback },
                { type = "dropdown", key = "growth", db = catDB, text = L["Bar Growth Direction"] or "条的生长方向", options = { {text=L["Grow Down"] or "向下生长", value="DOWN"}, {text=L["Grow Up"] or "向上生长", value="UP"} }, callback = handleCallback },
                { type = "dropdown", key = "iconPosition", db = catDB, text = L["Icon Position on Bar"] or "图标位于条的", options = { {text=L["LEFT"] or "左侧", value="LEFT"}, {text=L["RIGHT"] or "右侧", value="RIGHT"} }, callback = handleCallback },
                { type = "dropdown", key = "barPosition", db = catDB, text = L["Bar & Icon Alignment"] or "条与图标对齐方式", options = { {text=L["TOP"] or "顶部对齐", value="TOP"}, {text=L["CENTER"] or "居中对齐", value="CENTER"}, {text=L["BOTTOM"] or "底部对齐", value="BOTTOM"} }, callback = handleCallback },
                { type = "dropdown", key = "barTexture", db = catDB, text = L["Buff Bar Texture"] or "增益条材质", options = WF.UI.StatusBarOptions or { {text="Blizzard", value="Blizzard"} }, callback = handleCallback },
                { type = "color", key = "barColor", db = catDB, text = L["Buff Bar Color"] or "增益条颜色", callback = handleCallback },
                { type = "slider", key = "iconGap", db = catDB, min = 0, max = 50, step = 1, text = L["Icon & Bar Gap"] or "图标与条间距", callback = handleCallback }, 
                { type = "slider", key = "width", db = catDB, min = 50, max = 400, step = 1, text = L["Total Width"] or "总宽度", callback = handleCallback },
                { type = "slider", key = "height", db = catDB, min = 10, max = 100, step = 1, text = L["Icon Size"] or "图标大小", callback = handleCallback }, 
                { type = "slider", key = "barHeight", db = catDB, min = 2, max = 100, step = 1, text = L["Independent Bar Height"] or "增益条独立高度", callback = handleCallback } 
            } } }
        elseif target == "ItemBuff" then
            -- 【新增】：加入快捷吸附开关
            rowOpts = { { type = "group", key = "sb_ItemBuff", text = L["Item/Potion Buff"] or "物品/药水持续时间", childs = {
                { type = "toggle", key = "snapToBuffIcon", db = catDB, text = L["Snap to Buff Icon"] or "吸附到增益组上方", callback = handleCallback },
                { type = "slider", key = "iconGap", db = catDB, min = 0, max = 50, step = 1, text = L["Gap"] or "间距", callback = handleCallback },
                { type = "slider", key = "width", db = catDB, min = 10, max = 150, step = 1, text = L["Width"] or "宽度", callback = handleCallback },
                { type = "slider", key = "height", db = catDB, min = 10, max = 150, step = 1, text = L["Height"] or "高度", callback = handleCallback },
                { type = "slider", key = "maxPerRow", db = catDB, min = 1, max = 20, step = 1, text = L["Max Icons Per Row"] or "每行最大图标数", callback = handleCallback },
            } } }
        elseif target == "ExtraMonitor" then
            rowOpts = { { type = "group", key = "sb_ExtraMonitor", text = L["Extra Monitor (Item/Racial)"] or "额外监控 (物品/种族)", childs = {
                { type = "toggle", key = "enable", db = dbEM, text = L["Enable Extra Monitor Globally"] or "全局启用额外监控", callback = refreshEMCallback },
                { type = "slider", key = "iconGap", db = catDB, min = 0, max = 50, step = 1, text = L["Gap"] or "间距", callback = handleCallback },
                { type = "slider", key = "width", db = catDB, min = 10, max = 150, step = 1, text = L["Width"] or "宽度", callback = handleCallback },
                { type = "slider", key = "height", db = catDB, min = 10, max = 150, step = 1, text = L["Height"] or "高度", callback = handleCallback },
                { type = "slider", key = "maxPerRow", db = catDB, min = 1, max = 20, step = 1, text = L["Max Icons Per Row"] or "每行最大图标数", callback = handleCallback },
                { type = "dropdown", key = "zeroCountBehavior", db = dbEM, text = L["Behavior on Zero Count"] or "层数为0/未装备时", options = { {text=L["Hide Completely"] or "完全隐藏", value="hide"}, {text=L["Desaturate"] or "褪色变灰", value="gray"} }, callback = refreshEMCallback },
            } } }
        elseif string.sub(target, 1, 9) == "CustomRow" or string.sub(target, 1, 13) == "CustomBuffRow" then
            rowOpts = { { type = "group", key = "sb_"..target, text = (L["Custom Group"] or "自定义组 (") .. target .. ")", childs = {
                { type = "slider", key = "iconGap", db = catDB, min = 0, max = 50, step = 1, text = L["Gap"] or "间距" },
                { type = "slider", key = "width", db = catDB, min = 10, max = 150, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "height", db = catDB, min = 10, max = 150, step = 1, text = L["Height"] or "高度" },
                { type = "dropdown", key = "growth", db = catDB, text = L["Growth Direction"] or "生长方向", options = { {text=L["Grow Horizontally"] or "横向生长", value="CENTER_HORIZONTAL"}, {text=L["Grow Up"] or "向上生长", value="UP"}, {text=L["Grow Down"] or "向下生长", value="DOWN"} } },
                { type = "button", key = "deleteGroup", text = L["Delete This Group"] or "删除此组", callback = function()
                    local targetArr = (string.sub(target, 1, 13) == "CustomBuffRow") and db.CustomBuffRows or db.CustomRows
                    for i, v in ipairs(targetArr) do if v == target then table.remove(targetArr, i); break end end
                    WF.db.cooldownCustom[target] = nil
                    if db.spellOverrides then for k, v in pairs(db.spellOverrides) do if v.category == target then v.category = nil end end end
                    CDMod.Sandbox.popupMode = nil; popup:Hide(); CDMod:MarkLayoutDirty(true); WF.UI:RefreshCurrentPanel()
                end }
            } } }
        end
        
        if rowOpts then py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, rowOpts, handleCallback) end

    elseif mode == "TEXT" then
        popup.titleText:SetText((L["Text Style"] or "文本样式") .. " - " .. tostring(target.cat) .. " (" .. target.type .. ")")
        local catDB = db[target.cat] or {}
        local kType = (target.type == "CD") and "cd" or "stack"
        local tOpts = { WF.UI:GetTextOptions(catDB, kType, target.cat .. " - " .. target.type, "txt_"..target.cat.."_"..kType) }
        py = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, py, popW, tOpts, handleCallback)
    end

    if py == -10 then CDMod.Sandbox.popupMode = nil; popup:Hide()
    else popup.scrollChild:SetHeight(math.abs(py) + 20); popup:Show() end
end