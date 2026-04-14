local AddonName, ns = ...
local WF = _G.WishFlex
local L = WF.L
local EM = WF.ExtraMonitorAPI
if not EM then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local C_R, C_G, C_B = ClassColor.r, ClassColor.g, ClassColor.b

EM.Sandbox = EM.Sandbox or { popupMode = nil }
WF.UI:RegisterMenu({ id = "ExtraMonitor", parent = "Combat", name = L["Extra CD Monitor"] or "额外监控 (物品/种族)", key = "extraMonitor_Global", order = 35 })

local RACE_RACIALS = {
    Scourge            = { 7744 }, Tauren             = { 20549 }, Orc                = { 20572, 33697, 33702 },
    BloodElf           = { 202719, 50613, 25046, 69179, 80483, 155145, 129597, 232633, 28730 },
    Dwarf              = { 20594 }, Troll              = { 26297 }, Draenei            = { 28880 },
    NightElf           = { 58984 }, Human              = { 59752 }, DarkIronDwarf      = { 265221 },
    Gnome              = { 20589 }, HighmountainTauren = { 69041 }, Worgen             = { 68992 },
    Goblin             = { 69070 }, Pandaren           = { 107079 }, MagharOrc          = { 274738 },
    LightforgedDraenei = { 255647 }, VoidElf            = { 256948 }, KulTiran           = { 287712 },
    ZandalariTroll     = { 291944 }, Vulpera            = { 312411 }, Mechagnome         = { 312924 },
    Dracthyr           = { 357214, 368970 }, EarthenDwarf       = { 436344 }, Haranir            = { 1287685 },
}

local function IsSpellAvailable(spellID)
    if not spellID then return false end
    local isKnown = false
    pcall(function()
        if IsPlayerSpell and IsPlayerSpell(spellID) then isKnown = true end
        if not isKnown and IsSpellKnown and IsSpellKnown(spellID) then isKnown = true end
        if not isKnown and C_Spell and C_Spell.IsSpellUsable then
            local isUsable, noMana = C_Spell.IsSpellUsable(spellID)
            if isUsable or noMana then isKnown = true end
        end
    end)
    return isKnown
end

local function ApplyTexCoord(texture, w, h)
    if not texture or not w or not h or h == 0 then return end
    local ratio = w / h
    if ratio == 1 then texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif ratio > 1 then local offset = (1 - (h/w)) / 2 * 0.84; texture:SetTexCoord(0.08, 0.92, 0.08 + offset, 0.92 - offset)
    else local offset = (1 - (w/h)) / 2 * 0.84; texture:SetTexCoord(0.08 + offset, 0.92 - offset, 0.08, 0.92) end
end

local function CreateSandboxContextMenu()
    if WF.UI.EM_SandboxMenu then return WF.UI.EM_SandboxMenu end
    local m = CreateFrame("Frame", "WF_EM_SandboxContextMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("TOOLTIP"); m:SetSize(260, 200)
    WF.UI.Factory.ApplyFlatSkin(m, 0.05, 0.05, 0.05, 0.98, C_R, C_G, C_B, 1)
    m.title = m:CreateFontString(nil, "OVERLAY"); m.title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    m.title:SetPoint("TOP", 0, -12); m.title:SetTextColor(0.7, 0.7, 0.7)
    m.closeBtn = CreateFrame("Button", nil, m); m.closeBtn:SetSize(16, 16); m.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    local cTex = m.closeBtn:CreateTexture(nil, "ARTWORK"); cTex:SetAllPoints()
    cTex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); cTex:SetVertexColor(0.6, 0.6, 0.6)
    m.closeBtn:SetScript("OnEnter", function() cTex:SetVertexColor(1, 0.2, 0.2) end)
    m.closeBtn:SetScript("OnLeave", function() cTex:SetVertexColor(0.6, 0.6, 0.6) end)
    m.closeBtn:SetScript("OnClick", function() m:Hide() end)
    m.items = {}
    m:SetScript("OnUpdate", function(self)
        if self:IsShown() and not self:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then self:Hide() end
        end
    end)
    WF.UI.EM_SandboxMenu = m
    return m
end

local function ShowSandboxMenu(btn, data, titleText)
    local m = CreateSandboxContextMenu(); m:Hide()
    m.title:SetText(titleText or "监控管理"); m.title:Show()
    for _, b in ipairs(m.items) do b:Hide() end
    local yOff = -40
    local db = EM.GetDB()
    local toggles = {}
    
    local function RefreshAll()
        EM:ScanTracked(); EM:UpdateDisplay()
        WF.UI:RefreshCurrentPanel()
        m:Hide()
    end

    if data.isTrinket then table.insert(toggles, { text = "自动识别主动饰品", isToggle = true, state = db.autoTrinkets, action = function() db.autoTrinkets = not db.autoTrinkets; RefreshAll() end })
    elseif data.isRacial then table.insert(toggles, { text = "自动识别种族技能", isToggle = true, state = db.autoRacial, action = function() db.autoRacial = not db.autoRacial; RefreshAll() end })
    elseif data.type == "item" then
        local isEnabled = db.customItems[data.id]
        table.insert(toggles, { text = "启用此物品监控", isToggle = true, state = isEnabled, action = function() db.customItems[data.id] = not db.customItems[data.id]; RefreshAll() end })
        table.insert(toggles, { text = "|cffff0000彻底删除此监控|r", isToggle = false, action = function() db.customItems[data.id] = nil; RefreshAll() end })
    elseif data.type == "spell" then
        local isEnabled = db.customSpells[data.id]
        table.insert(toggles, { text = "启用此法术监控", isToggle = true, state = isEnabled, action = function() db.customSpells[data.id] = not db.customSpells[data.id]; RefreshAll() end })
        table.insert(toggles, { text = "|cffff0000彻底删除此监控|r", isToggle = false, action = function() db.customSpells[data.id] = nil; RefreshAll() end })
    end

    if #toggles == 0 then return end
    
    for i, tData in ipairs(toggles) do
        local b = m.items[i]
        if not b then 
            b = CreateFrame("Button", nil, m, "BackdropTemplate"); b:SetSize(240, 26)
            b.hoverBg = b:CreateTexture(nil, "BACKGROUND"); b.hoverBg:SetColorTexture(C_R, C_G, C_B, 0.25); b.hoverBg:Hide()
            b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
            b.track = b:CreateTexture(nil, "ARTWORK"); b.track:SetSize(26, 12)
            b.thumb = b:CreateTexture(nil, "OVERLAY"); b.thumb:SetSize(10, 10)
            table.insert(m.items, b) 
        end
        b.text:SetText(tData.text)
        b:SetScript("OnEnter", function(self) self.hoverBg:Show(); self.text:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(self) self.hoverBg:Hide(); self.text:SetTextColor(0.7, 0.7, 0.7) end)
        b:SetScript("OnClick", tData.action)

        if tData.isToggle then
            b.track:Show(); b.thumb:Show(); b.text:ClearAllPoints(); b.text:SetPoint("LEFT", 45, 0); b.track:ClearAllPoints(); b.track:SetPoint("LEFT", 10, 0); b.thumb:ClearAllPoints()
            if tData.state then b.track:SetColorTexture(C_R, C_G, C_B, 1); b.thumb:SetColorTexture(1, 1, 1, 1); b.thumb:SetPoint("LEFT", b.track, "LEFT", 15, 0); b.text:SetTextColor(1, 1, 1) else b.track:SetColorTexture(0.2, 0.2, 0.2, 1); b.thumb:SetColorTexture(0.6, 0.6, 0.6, 1); b.thumb:SetPoint("LEFT", b.track, "LEFT", 1, 0); b.text:SetTextColor(0.6, 0.6, 0.6) end
        else
            b.track:Hide(); b.thumb:Hide(); b.text:ClearAllPoints(); b.text:SetPoint("CENTER", 0, 0); b.text:SetTextColor(0.8, 0.8, 0.8)
        end
        b.hoverBg:ClearAllPoints(); b.hoverBg:SetPoint("TOPLEFT", 10, 0); b.hoverBg:SetPoint("BOTTOMRIGHT", -10, 0)
        b:ClearAllPoints(); b:SetPoint("TOP", 0, yOff); b:Show()
        WF.UI.Factory.ApplyFlatSkin(b, 0,0,0,0, 0,0,0,0)
        yOff = yOff - 28
    end
    
    m:SetHeight(math.abs(yOff) + 15)
    local cx, cy = GetCursorPosition(); local scale = UIParent:GetEffectiveScale()
    m:ClearAllPoints(); m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cx/scale) + 10, (cy/scale) - 10)
    m:Show()
end

WF.UI:RegisterPanel("extraMonitor_Global", function(scrollChild, ColW)
    local db = EM.GetDB()
    EM:ScanTracked()
    
    local currentY = -15

    local function Refresh()
        EM:ScanTracked(); EM:UpdateDisplay()
        WF.UI:RefreshCurrentPanel()
    end

    local btnHelp = scrollChild.EM_HelpBtn or WF.UI.Factory:CreateFlatButton(scrollChild, "排版与操作设置", function()
        EM.Sandbox.popupMode = "GLOBAL"
        WF.UI:RefreshCurrentPanel()
    end)
    scrollChild.EM_HelpBtn = btnHelp
    btnHelp:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 15, currentY); btnHelp:SetWidth(180); btnHelp:Show()

    btnHelp:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("【沙盒操作指南】", 1, 0.82, 0); GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00[左键点击]|r 图标/按钮：打开基础排版设置", 1, 1, 1)
        GameTooltip:AddLine("|cff00ccff[左键拖动]|r 任意图标：通过绿色参考线插入排版", 1, 1, 1)
        GameTooltip:AddLine("|cffffaa00[右键点击]|r 任意图标：管理独立开关", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnHelp:SetScript("OnLeave", function() GameTooltip:Hide() end)

    currentY = currentY - 35

    local previewBox = scrollChild.EM_Sandbox_Box or CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    previewBox:SetPoint("TOPLEFT", 15, currentY)
    WF.UI.Factory.ApplyFlatSkin(previewBox, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); previewBox:Show(); scrollChild.EM_Sandbox_Box = previewBox

    local title = previewBox.title or previewBox:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("|cff00ccff[Live Sandbox]|r 额外监控拖拽排版沙盒"); title:SetTextColor(1, 0.82, 0)
    previewBox.title = title
    
    local ind = previewBox.dropIndicator
    if not ind then
        ind = CreateFrame("Frame", nil, previewBox, "BackdropTemplate")
        local tex = ind:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(); tex:SetColorTexture(0, 1, 0, 1)
        ind.tex = tex; ind:Hide()
        previewBox.dropIndicator = ind
    end

    local py = -40
    local px = 15
    local w = tonumber(db.iconWidth) or 36
    local h = tonumber(db.iconHeight) or 36
    local gap = tonumber(db.iconGap) or 1
    local maxRow = math.floor((ColW - 60) / (w + gap))

    if not previewBox.pool then previewBox.pool = {} end
    for _, v in ipairs(previewBox.pool) do v:Hide() end

    -- 【UI 沙盒去重】：解决设置面板预览出现双重图标的问题
    local uiTrackers = {}
    local seenSpells = {}
    local seenItems = {}
    
    local myRacials = {}
    local _, race = UnitRace("player")
    if race and RACE_RACIALS[race] then 
        for _, spellID in ipairs(RACE_RACIALS[race]) do 
            if IsSpellAvailable(spellID) then table.insert(myRacials, spellID) end 
        end 
    end
    
    for _, sid in ipairs(myRacials) do 
        if not seenSpells[sid] then
            seenSpells[sid] = true
            table.insert(uiTrackers, { type="spell", id=sid, isRacial=true, enabled=db.autoRacial }) 
        end
    end
    
    for slot = 13, 14 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then 
            local _, useSpellID = C_Item.GetItemSpell(itemID); 
            if useSpellID and useSpellID > 0 and not seenItems[itemID] then 
                seenItems[itemID] = true
                table.insert(uiTrackers, { type="item", id=itemID, slot=slot, isTrinket=true, enabled=db.autoTrinkets }) 
            end 
        end
    end
    
    if db.customSpells then 
        for id, en in pairs(db.customSpells) do 
            if not seenSpells[id] then
                seenSpells[id] = true
                table.insert(uiTrackers, { type="spell", id=id, enabled=en }) 
            end
        end 
    end
    
    if db.customItems then 
        for configID, en in pairs(db.customItems) do 
            if not seenItems[configID] then
                seenItems[configID] = true
                table.insert(uiTrackers, { type="item", id=configID, enabled=en }) 
            end
        end 
    end

    table.sort(uiTrackers, function(a, b)
        local order = db.customOrder or {}
        local idA = a.type .. "_" .. a.id
        local idB = b.type .. "_" .. b.id
        local valA = order[idA] or 999
        local valB = order[idB] or 999
        if valA == valB then return idA < idB end
        return valA < valB
    end)

    local col, row = 0, 0
    for i, data in ipairs(uiTrackers) do
        local btn = previewBox.pool[i]
        if not btn then
            btn = CreateFrame("Button", nil, previewBox, "BackdropTemplate")
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp"); btn:RegisterForDrag("LeftButton"); btn:SetMovable(true)
            btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            btn.icon = btn:CreateTexture(nil, "BACKGROUND"); btn.icon:SetAllPoints()
            btn.mask = btn:CreateTexture(nil, "OVERLAY"); btn.mask:SetAllPoints(); btn.mask:SetColorTexture(0, 0, 0, 0.7)
            btn.maskIcon = btn:CreateTexture(nil, "OVERLAY"); btn.maskIcon:SetSize(16, 16); btn.maskIcon:SetPoint("CENTER")
            btn.maskIcon:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); btn.maskIcon:SetVertexColor(1, 0, 0, 0.8)
            previewBox.pool[i] = btn
        end

        btn.trackerData = data
        local iconTex = (data.type == "item") and C_Item.GetItemIconByID(data.id) or C_Spell.GetSpellTexture(data.id)
        btn.icon:SetTexture(iconTex)
        btn:SetSize(w, h)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", px + col*(w+gap), py - row*(h+gap))
        
        ApplyTexCoord(btn.icon, w, h)
        
        if data.enabled then btn.icon:SetDesaturated(false); btn.mask:Hide(); btn.maskIcon:Hide(); btn:SetBackdropBorderColor(0, 0, 0, 1) else btn.icon:SetDesaturated(true); btn.mask:Show(); btn.maskIcon:Show(); btn:SetBackdropBorderColor(1, 0, 0, 1) end
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1, 0.8, 0, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local nameStr = (data.type == "item") and (C_Item.GetItemNameByID(data.id) or "物品ID: " .. data.id) or ((C_Spell.GetSpellInfo(data.id) and C_Spell.GetSpellInfo(data.id).name) or "法术ID: " .. data.id)
            GameTooltip:AddLine(nameStr, 1, 1, 1)
            if not data.enabled then GameTooltip:AddLine("|cffff0000(当前已停用)|r", 1, 1, 1) end
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function(self) if data.enabled then self:SetBackdropBorderColor(0, 0, 0, 1) else self:SetBackdropBorderColor(1, 0, 0, 1) end; GameTooltip:Hide() end)

        btn:SetScript("OnDragStart", function(self)
            self.isDragging = true
            local currentLevel = self:GetFrameLevel() or 1
            self.origFrameLevel = currentLevel
            self:SetFrameLevel(math.min(65535, currentLevel + 50))
            local cx, cy = GetCursorPosition()
            local uiScale = self:GetEffectiveScale()
            self.cursorStartX = cx / uiScale
            self.cursorStartY = cy / uiScale
            local p, rt, rp, x, y = self:GetPoint()
            self.origP, self.origRT, self.origRP = p, rt, rp
            self.startX, self.startY = x, y

            self:SetScript("OnUpdate", function(s)
                local ncx, ncy = GetCursorPosition()
                ncx = ncx / uiScale; ncy = ncy / uiScale
                s:ClearAllPoints()
                s:SetPoint(s.origP, s.origRT, s.origRP, s.startX + (ncx - s.cursorStartX), s.startY + (ncy - s.cursorStartY))

                local scx, scy = s:GetCenter()
                if not scx then return end

                local closestBtn = nil
                local minDist = 9999
                for j, other in ipairs(previewBox.pool) do
                    if other:IsShown() and other ~= s then
                        local ox, oy = other:GetCenter()
                        if ox and oy then
                            local dist = math.sqrt((scx - ox)^2 + (scy - oy)^2)
                            if dist < minDist then minDist = dist; closestBtn = other end
                        end
                    end
                end

                if closestBtn and minDist < 60 then
                    local ox, oy = closestBtn:GetCenter()
                    s.dropTarget = closestBtn
                    s.dropModeDir = (scx < ox) and "before" or "after"
                    
                    ind:SetParent(closestBtn:GetParent())
                    ind:SetFrameLevel(closestBtn:GetFrameLevel() + 5)
                    ind:SetSize(4, closestBtn:GetHeight() + 10)
                    ind:ClearAllPoints()
                    
                    if s.dropModeDir == "before" then
                        ind:SetPoint("RIGHT", closestBtn, "LEFT", -2, 0)
                    else
                        ind:SetPoint("LEFT", closestBtn, "RIGHT", 2, 0)
                    end
                    ind:Show()
                else
                    ind:Hide()
                    s.dropTarget = nil
                end
            end)
        end)

        btn:SetScript("OnDragStop", function(self)
            self.isDragging = false
            self:SetScript("OnUpdate", nil)
            self:SetFrameLevel(math.max(1, math.min(65535, self.origFrameLevel or 1)))
            ind:Hide()

            if self.dropTarget then
                local sortedList = {}
                for _, v in ipairs(uiTrackers) do table.insert(sortedList, v) end

                local dragIdx
                for idx, v in ipairs(sortedList) do
                    if v.type == data.type and v.id == data.id then dragIdx = idx; break end
                end

                if dragIdx then
                    local draggedItem = table.remove(sortedList, dragIdx)
                    
                    local targetIdx
                    for idx, v in ipairs(sortedList) do
                        if v.type == self.dropTarget.trackerData.type and v.id == self.dropTarget.trackerData.id then targetIdx = idx; break end
                    end

                    if targetIdx then
                        if self.dropModeDir == "after" then
                            table.insert(sortedList, targetIdx + 1, draggedItem)
                        else
                            table.insert(sortedList, targetIdx, draggedItem)
                        end

                        if not db.customOrder then db.customOrder = {} end
                        for idx, v in ipairs(sortedList) do
                            local key = v.type .. "_" .. v.id
                            db.customOrder[key] = idx * 10
                        end
                    end
                end
            end
            Refresh()
        end)
        
        btn:SetScript("OnClick", function(self, button)
            if self.isDragging then return end
            if button == "RightButton" then
                local titleStr = (data.type == "item") and (C_Item.GetItemNameByID(data.id) or "自定义物品") or ((C_Spell.GetSpellInfo(data.id) and C_Spell.GetSpellInfo(data.id).name) or "自定义法术")
                ShowSandboxMenu(btn, data, titleStr)
            elseif button == "LeftButton" then
                EM.Sandbox.popupMode = "GLOBAL"
                WF.UI:RefreshCurrentPanel()
            end
        end)
        
        btn:Show()
        col = col + 1
        if col >= maxRow then col = 0; row = row + 1 end
    end

    local previewHeight = math.abs(py) + (row + 1) * (h + gap) + 20
    previewBox:SetSize(ColW - 30, math.max(220, previewHeight))
    currentY = currentY - previewBox:GetHeight() - 20

    if EM.Sandbox.popupMode == "GLOBAL" then
        if not WF.UI.EMPopup then
            local popup = CreateFrame("Frame", "WishFlex_EMPopup", WF.MainFrame, "BackdropTemplate")
            popup:SetSize(340, 480); popup:SetPoint("CENTER", WF.MainFrame, "CENTER", 100, 0)
            popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(WF.MainFrame:GetFrameLevel() + 50)
            popup:EnableMouse(true); popup:SetMovable(true); popup:RegisterForDrag("LeftButton")
            popup:SetScript("OnDragStart", popup.StartMoving); popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
            WF.UI.Factory.ApplyFlatSkin(popup, 0.08, 0.08, 0.08, 0.98, C_R, C_G, C_B, 1)

            popup.titleBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
            popup.titleBg:SetPoint("TOPLEFT", 1, -1); popup.titleBg:SetPoint("TOPRIGHT", -1, -1); popup.titleBg:SetHeight(30)
            WF.UI.Factory.ApplyFlatSkin(popup.titleBg, 0.15, 0.15, 0.15, 1, 0,0,0,0)
            popup.titleText = popup.titleBg:CreateFontString(nil, "OVERLAY")
            popup.titleText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE"); popup.titleText:SetPoint("LEFT", 10, 0); popup.titleText:SetTextColor(0.7, 0.7, 0.7)
            popup.titleText:SetText("排版设置")

            popup.closeBtn = CreateFrame("Button", nil, popup.titleBg); popup.closeBtn:SetSize(20, 20); popup.closeBtn:SetPoint("RIGHT", -5, 0)
            local cTex = popup.closeBtn:CreateTexture(nil, "ARTWORK"); cTex:SetAllPoints(); cTex:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"); cTex:SetVertexColor(0.6, 0.6, 0.6)
            popup.closeBtn:SetScript("OnEnter", function() cTex:SetVertexColor(1, 0.2, 0.2) end); popup.closeBtn:SetScript("OnLeave", function() cTex:SetVertexColor(0.6, 0.6, 0.6) end)
            popup.closeBtn:SetScript("OnClick", function() EM.Sandbox.popupMode = nil; popup:Hide(); WF.UI:RefreshCurrentPanel() end)

            local sFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
            sFrame:SetPoint("TOPLEFT", 10, -40); sFrame:SetPoint("BOTTOMRIGHT", -30, 10)
            local sChild = CreateFrame("Frame"); sChild:SetSize(sFrame:GetWidth(), 1); sFrame:SetScrollChild(sChild)
            popup.scrollFrame = sFrame; popup.scrollChild = sChild
            WF.UI.EMPopup = popup
        end

        local popup = WF.UI.EMPopup
        popup:Show()
        local popY = -10
        local popW = popup.scrollFrame:GetWidth() - 10

-- 新增：实时同步重绘沙盒与实体图标的函数
        local function LiveUpdateSize()
            EM:UpdateDisplay() -- 更新真实UI
            if previewBox and previewBox.pool then
                local sw = tonumber(db.iconWidth) or 36
                local sh = tonumber(db.iconHeight) or 36
                local sgap = tonumber(db.iconGap) or 1
                local maxC = math.floor((ColW - 60) / (sw + sgap))
                if maxC < 1 then maxC = 1 end
                local c, r = 0, 0
                for _, btn in ipairs(previewBox.pool) do
                    if btn:IsShown() then
                        btn:SetSize(sw, sh)
                        btn:ClearAllPoints()
                        btn:SetPoint("TOPLEFT", 15 + c*(sw+sgap), -40 - r*(sh+sgap))
                        ApplyTexCoord(btn.icon, sw, sh)
                        c = c + 1
                        if c >= maxC then c = 0; r = r + 1 end
                    end
                end
                previewBox:SetHeight(math.abs(-40) + (r + 1) * (sh + sgap) + 20)
            end
        end

        local baseOpts = {
            { type = "group", key = "em_base", text = "基础排版", childs = {
                { type = "toggle", key = "enable", db = db, text = "全局启用额外监控", callback = Refresh },
                { type = "slider", key = "iconWidth", db = db, text = "图标宽度", min = 20, max = 100, step = 1, callback = LiveUpdateSize },
                { type = "slider", key = "iconHeight", db = db, text = "图标高度", min = 20, max = 100, step = 1, callback = LiveUpdateSize },
                { type = "slider", key = "iconGap", db = db, text = "图标间距", min = 0, max = 20, step = 1, callback = LiveUpdateSize },
                { type = "slider", key = "maxPerRow", db = db, text = "每行最大图标数", min = 1, max = 20, step = 1, callback = LiveUpdateSize },
                { type = "dropdown", key = "zeroCountBehavior", db = db, text = "层数为0/未装备时", options = { {text="完全隐藏", value="hide"}, {text="变灰显示0层", value="gray"} }, callback = function() EM:UpdateDisplay() end },
            }},
        }
        
        popY = WF.UI:RenderOptionsGroup(popup.scrollChild, 5, popY, popW, baseOpts, Refresh)
        popY = popY - 10

        popup.scrollChild:SetHeight(math.abs(popY) + 20)
    else
        if WF.UI.EMPopup then WF.UI.EMPopup:Hide() end
    end

    return currentY, 800
end)