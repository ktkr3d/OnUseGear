local addonName, ns = ...

local LibStub = _G.LibStub
if not LibStub then return end

local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
local icon = LibStub:GetLibrary("LibDBIcon-1.0", true)

if not LDB or not icon then return end

local myLDB = LDB:NewDataObject(addonName, {
    type = "launcher",
    text = addonName,
    icon = "Interface\\Icons\\inv12_jewelrytrinkets_devouring_host_currency3_silver",
    
    OnClick = function(self, button)
        if button == "LeftButton" then
            SlashCmdList["OnUseGear"]()
        elseif button == "RightButton" then
            SlashCmdList["OnUseGear"]("lock")
        end
    end,
    
    OnTooltipShow = function(tooltip)
        tooltip:AddLine(addonName, 1, 1, 1)
        tooltip:AddLine("|cff00ff00Left Click:|r Open Settings", 0.8, 0.8, 0.8)
        tooltip:AddLine("|cff00ff00Right Click:|r Toggle lock state", 0.8, 0.8, 0.8)
    end,
})

local minimapFrame = CreateFrame("Frame")
minimapFrame:RegisterEvent("ADDON_LOADED")
minimapFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not OnUseGearDB then
            OnUseGearDB = {}
        end
        if not OnUseGearDB.minimapButton then
            OnUseGearDB.minimapButton = { hide = false, minimapPos = 45, radius = 80, lock = false }
        end

        icon:Register(addonName, myLDB, OnUseGearDB.minimapButton)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
