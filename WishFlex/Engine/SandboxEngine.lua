local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
WF.SandboxEngine = {}

function WF.SandboxEngine:EnableDragAndDrop(container, itemPool, onDragStopCallback)
    if not container.dropIndicator then
        local ind = CreateFrame("Frame", nil, container, "BackdropTemplate")
        local tex = ind:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(); tex:SetColorTexture(0, 1, 0, 1) -- 绿色插入提示线
        ind.tex = tex; ind:Hide()
        container.dropIndicator = ind
    end

    for _, btn in ipairs(itemPool) do
        if not btn.isDragEnabled then
            btn:RegisterForDrag("LeftButton")
            btn:SetMovable(true)

            btn:SetScript("OnDragStart", function(self)
                self.isDragging = true
                self.origFrameLevel = self:GetFrameLevel() or 1
                self:SetFrameLevel(math.min(65535, self.origFrameLevel + 50))
                
                local cx, cy = GetCursorPosition()
                local uiScale = self:GetEffectiveScale()
                self.cursorStartX = cx / uiScale
                self.cursorStartY = cy / uiScale
                local p, rt, rp, x, y = self:GetPoint()
                self.origP, self.origRT, self.origRP, self.startX, self.startY = p, rt, rp, x, y

                self:SetScript("OnUpdate", function(s)
                    local ncx, ncy = GetCursorPosition()
                    ncx = ncx / uiScale; ncy = ncy / uiScale
                    s:ClearAllPoints()
                    s:SetPoint(s.origP, s.origRT, s.origRP, s.startX + (ncx - s.cursorStartX), s.startY + (ncy - s.cursorStartY))

                    local scx, scy = s:GetCenter()
                    local closestBtn = nil
                    local minDist = 9999

                    for _, other in ipairs(itemPool) do
                        if other:IsShown() and other ~= s then
                            local ox, oy = other:GetCenter()
                            if ox and oy then
                                local dist = math.sqrt((scx - ox)^2 + (scy - oy)^2)
                                if dist < minDist then minDist = dist; closestBtn = other end
                            end
                        end
                    end

                    if closestBtn and minDist < 60 then
                        local ox = closestBtn:GetCenter()
                        s.dropTarget = closestBtn
                        s.dropModeDir = (scx < ox) and "before" or "after"
                        
                        local ind = container.dropIndicator
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
                        container.dropIndicator:Hide()
                        s.dropTarget = nil
                    end
                end)
            end)

            btn:SetScript("OnDragStop", function(self)
                self.isDragging = false
                self:SetScript("OnUpdate", nil)
                self:SetFrameLevel(math.max(1, math.min(65535, self.origFrameLevel or 1)))
                container.dropIndicator:Hide()

                if self.dropTarget and onDragStopCallback then
                    onDragStopCallback(self.trackerData, self.dropTarget.trackerData, self.dropModeDir)
                end
            end)
            
            btn.isDragEnabled = true
        end
    end
end