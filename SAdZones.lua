local addonName = ...
local SAdCore = LibStub("SAdCore-1")
local addon = SAdCore:GetAddon(addonName)

addon.savedVarsGlobalName = "SAdZones_Settings_Global"
addon.savedVarsPerCharName = "SAdZones_Settings_Char"
addon.compartmentFuncName = "SAdZones_Compartment_Func"

function addon:LoadConfig()
    self.config.version = "1.0"
    self.author = "Rôkk-Wyrmrest Accord"

    for _, zoneName in ipairs(addon.zones) do
        self.config.settings[zoneName] = {
            title = zoneName .. "Title",
            controls = {
                {
                    type = "checkbox",
                    name = "showMinimap",
                    default = true,
                    onValueChange = self.ValueChanged
                },
                {
                    type = "checkbox",
                    name = "showMicroMenu",
                    default = true,
                    onValueChange = self.ValueChanged
                },
                {
                    type = "checkbox",
                    name = "showBagsBar",
                    default = true,
                    onValueChange = self.ValueChanged
                },
                {
                    type = "checkbox",
                    name = "showQuestFrame",
                    default = true,
                    onValueChange = self.ValueChanged
                },
                {
                    type = "checkbox",
                    name = "showZoneMap",
                    default = true,
                    onValueChange = self.ValueChanged
                },
                {
                    type = "checkbox",
                    name = "showStatusBar",
                    default = true,
                    onValueChange = self.ValueChanged
                },
                {
                    type = "checkbox",
                    name = "showClock",
                    default = true,
                    onValueChange = self.ValueChanged
                },
            }
        }
    end
end

function addon:OnZoneChange(currentZone)
    self:ApplyFrameFiltersForZone()
end

function addon:ValueChanged(currentZone)
    addon:ApplyFrameFiltersForZone(currentZone, true)
end

function addon:ApplyFrameFiltersForZone(currentZone, forceUpdate)
    if not forceUpdate and self.previousZone == self.currentZone then
        return
    end
    
    local zoneSettings = self.settings[self.currentZone]
    if not zoneSettings then
        addon:debug(string.format("No settings found for zone: %s", tostring(self.currentZone)))
        return
    end

    addon:debug(string.format("Applying frame filters for zone: %s", tostring(self.currentZone)))

    for settingName, filterFunc in pairs(addon.frameFilterSettings) do
        if filterFunc and zoneSettings[settingName] ~= nil then
            filterFunc(self, zoneSettings[settingName])
        end
    end
    
    self.previousZone = self.currentZone
end

if not addon.hiddenParent then
    addon.hiddenParent = CreateFrame("Frame")
    addon.hiddenParent:Hide()
end

addon.managedFrames = addon.managedFrames or {}
addon.originalParents = addon.originalParents or {}
addon.frameFilterSettings = {}
addon.toggleFrames = {}
addon.config = {}
addon.config.updateDelay = .2

local protectedFrames = {
    ["BattlefieldMapFrame"] = true,
}

function addon:setFrameVisibility(frameName, visible)
    if not frameName then
        addon:debug("setFrameVisibility failed: frameName is nil")
        return
    end
    
    if protectedFrames[frameName] then
        addon:debug("Skipping protected frame: " .. frameName)
        return
    end
    
    local frame = _G[frameName]
    
    if addon.managedFrames[frameName] == visible and frame then
        if visible and frame:IsShown() then
            addon:debug("Frame '" .. frameName .. "' is already visible, skipping")
            return
        elseif not visible and not frame:IsShown() then
            addon:debug("Frame '" .. frameName .. "' is already hidden, skipping")
            return
        end
    end
    
    addon.managedFrames[frameName] = visible
    
    if not frame then
        if not addon.config or not addon.config.updateDelay then
            addon:debug("setFrameVisibility failed: frame '" .. frameName .. "' doesn't exist and config not available for retry")
            return
        end
        
        C_Timer.After(addon.config.updateDelay, function()
            addon:setFrameVisibility(frameName, visible)
        end)
        return
    end
    
    local success, err = pcall(function()
        if not visible then
            if not frame.Hide then
                addon:debug("setFrameVisibility warning: frame '" .. frameName .. "' has no Hide method")
                return
            end
            
            if frame.SetParent and frame.GetParent and not addon.originalParents[frameName] then
                addon.originalParents[frameName] = frame:GetParent()
            end
            
            frame:Hide()
            
            if frame.SetParent then
                frame:SetParent(addon.hiddenParent)
            else
                addon:debug("setFrameVisibility warning: frame '" .. frameName .. "' has no SetParent method")
            end            

            if not frame.sadzonesShowHooked then
                hooksecurefunc(frame, "Show", function(self)
                    if not addon.managedFrames[frameName] then
                        self:Hide()
                    end
                end)
                frame.sadzonesShowHooked = true
            end            
            addon:debug("Hid frame: " .. frameName)
        else
            if frame.SetParent then
                local originalParent = addon.originalParents[frameName]
                if originalParent then
                    frame:SetParent(originalParent)
                else
                    frame:SetParent(UIParent)
                end
            else
                addon:debug("setFrameVisibility warning: frame '" .. frameName .. "' has no SetParent method")
            end            
            if not frame.Show then
                addon:debug("setFrameVisibility warning: frame '" .. frameName .. "' has no Show method")
                return
            end            
            frame:Show()            
        end
    end)
    
    if not success then
        addon:debug("setFrameVisibility failed for frame '" .. frameName .. "': " .. tostring(err))
    end
end


function addon.frameFilterSettings.showMinimap(self, show)
    local showFrame = show == true
    self:setFrameVisibility("MinimapCluster", showFrame)
    self:debug("Set showMinimap to: " .. tostring(showFrame))
end

function addon.frameFilterSettings.showMicroMenu(self, show)
    local showFrame = show == true
    self:setFrameVisibility("MicroMenuContainer", showFrame)
    self:debug("Set showMicroMenu to: " .. tostring(showFrame))
end

function addon.frameFilterSettings.showBagsBar(self, show)
    local showFrame = show == true
    self:setFrameVisibility("BagsBar", showFrame)
    self:debug("Set showBagsBar to: " .. tostring(showFrame))
end

function addon.frameFilterSettings.showQuestFrame(self, show)
    local showFrame = show == true
    self:setFrameVisibility("ObjectiveTrackerFrame", showFrame)
    self:debug("Set showQuestFrame to: " .. tostring(showFrame))
end

function addon.frameFilterSettings.showZoneMap(self, show)
    local showFrame = show == true
    
    if showFrame then
        SetCVar("showBattlefieldMinimap", "1")
        self:debug("Enabled showBattlefieldMinimap CVar")
    else
        SetCVar("showBattlefieldMinimap", "0")
        self:debug("Disabled showBattlefieldMinimap CVar")
    end
    
    self:debug("Set showZoneMap to: " .. tostring(showFrame))
end

function addon.frameFilterSettings.showStatusBar(self, show)
    local showFrame = show == true
    self:setFrameVisibility("MainStatusTrackingBarContainer", showFrame)
    self:setFrameVisibility("MainStatusTrackingBar", showFrame)
    self:debug("Set showStatusBar to: " .. tostring(showFrame))
end

function addon.frameFilterSettings.showClock(self, show)
    local showFrame = show == true
    self:setFrameVisibility("TimeManagerClockButton", showFrame)
    self:setFrameVisibility("AddonCompartmentFrame", showFrame)
    self:debug("Set showClock to: " .. tostring(showFrame))
end

function addon:RegisterFunctions()
    self:RegisterSlashCommand("toggle", addon.ToggleFrameCommand)
end

function addon.ToggleFrameCommand(frameName)
    if not frameName or frameName == "" then
        addon:info("Usage: /sadzones toggle <frameName>")
        addon:info("Example: /sadzones toggle minimap")
        return
    end
    
    local normalizedName = string.lower(frameName)
    
    local filterFunc = nil
    local funcKey = nil
    
    for key, func in pairs(addon.frameFilterSettings) do
        if string.lower(key) == normalizedName or string.lower(key) == "show" .. normalizedName then
            filterFunc = func
            funcKey = key
            break
        end
    end
    
    if not filterFunc then
        addon:info("Unknown frame: " .. frameName)
        return
    end
    
    if addon.toggleFrames[funcKey] == nil then
        addon.toggleFrames[funcKey] = true
    end
    
    addon.toggleFrames[funcKey] = not addon.toggleFrames[funcKey]
    
    filterFunc(addon, addon.toggleFrames[funcKey])
    
    local status = addon.toggleFrames[funcKey] and "shown" or "hidden"
    addon:info(frameName .. " is now " .. status)
end

