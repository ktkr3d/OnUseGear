local addonName, ns = ...

-------------------------------------------------------------------------------
-- Constants & Slot Definitions
-------------------------------------------------------------------------------
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local slotButtons = {}
local profileDropdownFrame
local MAX_KEYBIND_SLOTS = 8

-- Default addon configurations
local DEFAULT_PROFILE = {
    ButtonSize  = 45,
    Spacing     = 6,
    IsVertical  = false,
    OpacityCD   = 0.6,
    Locked      = false,
    Position    = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -200 },
    Minimap     = { hide = false, minimapPos = 45, radius = 80, lock = false }
}

-------------------------------------------------------------------------------
-- Main Frame & Drag Handle Initialization
-------------------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "OnUseGearFrame", UIParent)
mainFrame:SetMovable(true)

local dragHandle = CreateFrame("Frame", nil, mainFrame)
dragHandle:SetSize(16, 16)
dragHandle:SetPoint("BOTTOMRIGHT", mainFrame, "TOPLEFT", -2, -2)

local dragTexture = dragHandle:CreateTexture(nil, "BACKGROUND")
dragTexture:SetAllPoints()
dragTexture:SetColorTexture(1, 0.5, 0, 0.8) -- Orange color indicator

dragHandle:SetMovable(true)
dragHandle:EnableMouse(true)
dragHandle:RegisterForDrag("LeftButton")

-------------------------------------------------------------------------------
-- Profile & Database Management
-------------------------------------------------------------------------------
local currentProfileKey

local function GetProfile()
    if not OnUseGearDB then 
        OnUseGearDB = { profiles = {}, charToProfile = {}, minimapButton = { name = "OnUseGear", hide = false, minimapPos = 45, radius = 80, lock = false } } 
    end
    if not OnUseGearDB.minimapButton then
        OnUseGearDB.minimapButton = { name = "OnUseGear", hide = false, minimapPos = 45, radius = 80, lock = false }
    end
    local myKey = UnitName("player") .. " - " .. GetRealmName()
    
    if not OnUseGearDB.charToProfile[myKey] then
        OnUseGearDB.charToProfile[myKey] = myKey
    end
    
    currentProfileKey = OnUseGearDB.charToProfile[myKey]
    
    if not OnUseGearDB.profiles[currentProfileKey] then
        OnUseGearDB.profiles[currentProfileKey] = CopyTable(DEFAULT_PROFILE)
    elseif not OnUseGearDB.profiles[currentProfileKey].Minimap then
        OnUseGearDB.profiles[currentProfileKey].Minimap = CopyTable(DEFAULT_PROFILE.Minimap)
    end

    OnUseGearDB.minimapButton.name = "OnUseGear"
    OnUseGearDB.minimapButton.hide = OnUseGearDB.minimapButton.hide or false
    OnUseGearDB.minimapButton.minimapPos = OnUseGearDB.minimapButton.minimapPos or 45
    OnUseGearDB.minimapButton.radius = OnUseGearDB.minimapButton.radius or 80
    OnUseGearDB.minimapButton.lock = OnUseGearDB.minimapButton.lock or false
    
    return OnUseGearDB.profiles[currentProfileKey]
end

-------------------------------------------------------------------------------
-- Action Bar Rendering & Update Logic
-------------------------------------------------------------------------------
local function UpdateButtonCooldowns()
    local p = GetProfile()
    for _, slotID in ipairs(SLOTS) do
        local btn = slotButtons[slotID]
        if btn and btn:IsShown() then
            local start, duration, enable = GetInventoryItemCooldown("player", slotID)
            if enable and duration > 0 then
                btn.cooldown:SetCooldown(start, duration)
                btn.cooldown:Show()
                btn.icon:SetAlpha(p.OpacityCD)
            else
                btn.cooldown:Hide()
                btn.icon:SetAlpha(1.0)
            end
        end
    end
end

local function ClearButtons()
    for _, btn in pairs(slotButtons) do
        btn:Hide()
        btn:ClearAllPoints()
    end
end

local function UpdateOnUseGear()
    local p = GetProfile()
    ClearButtons()
    local activeCount = 0

    for _, slotID in ipairs(SLOTS) do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID and C_Item.GetItemSpell(itemID) then
            activeCount = activeCount + 1
            local btn = slotButtons[slotID]
            btn.activeIndex = activeCount
            
            btn:SetSize(p.ButtonSize, p.ButtonSize)
            btn.icon:SetTexture(GetItemIcon(itemID))
            
            local offset = (activeCount - 1) * (p.ButtonSize + p.Spacing)
            if p.IsVertical then
                btn:SetPoint("TOP", mainFrame, "TOP", 0, -offset)
            else
                btn:SetPoint("LEFT", mainFrame, "LEFT", offset, 0)
            end
            btn:Show()
        else
            if slotButtons[slotID] then
                slotButtons[slotID].activeIndex = nil
            end
        end
    end
    
    if activeCount > 0 then
        local totalSize = (activeCount * p.ButtonSize) + ((activeCount - 1) * p.Spacing)
        if p.IsVertical then
            mainFrame:SetSize(p.ButtonSize, totalSize)
        else
            mainFrame:SetSize(totalSize, p.ButtonSize)
        end
    else
        mainFrame:SetSize(p.ButtonSize, p.ButtonSize)
    end
    
    UpdateButtonCooldowns()
end

-------------------------------------------------------------------------------
-- Keybind Application
-------------------------------------------------------------------------------
local function ApplyKeybinds()
    if InCombatLockdown() then return end

    for _, slotID in ipairs(SLOTS) do
        local btn = slotButtons[slotID]
        if btn and btn.activeIndex then
            local idx = btn.activeIndex
            if idx <= MAX_KEYBIND_SLOTS then
                local bindingName = "CLICK OnUseGearSlotButton" .. slotID .. ":LeftButton"
                local key1, key2 = GetBindingKey("OnUseGear_SLOT" .. idx)
                if key1 then
                    SetOverrideBinding(mainFrame, true, key1, bindingName)
                end
                if key2 then
                    SetOverrideBinding(mainFrame, true, key2, bindingName)
                end
                local displayKey = key1 and GetBindingText(key1, "KEY_") or ""
                if btn.keybindText then
                    btn.keybindText:SetText(displayKey)
                end
            end
        end
    end
end

local function ClearKeybinds()
    ClearOverrideBindings(mainFrame)
    for _, btn in pairs(slotButtons) do
        if btn.keybindText then
            btn.keybindText:SetText("")
        end
    end
end

local function RefreshLayoutAndLock()
    local p = GetProfile()
    if p.Locked then
        dragHandle:Hide()
    else
        dragHandle:Show()
        dragHandle:SetAlpha(0)
    end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(p.Position.point, UIParent, p.Position.relativePoint, p.Position.x, p.Position.y)
    UpdateOnUseGear()
    ApplyKeybinds()
end

-- Drag Scripts Setup
dragHandle:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
dragHandle:SetScript("OnDragStop", function()
    mainFrame:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = mainFrame:GetPoint()
    local p = GetProfile()
    p.Position = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
end)

local function SetHandleAlpha(alpha)
    local p = GetProfile()
    if p.Locked then dragHandle:SetAlpha(0) else dragHandle:SetAlpha(alpha) end
end
dragHandle:SetScript("OnEnter", function() SetHandleAlpha(1.0) end)
dragHandle:SetScript("OnLeave", function() SetHandleAlpha(0.0) end)

local function InitializeButtons()
    local p = GetProfile()
    for _, slotID in ipairs(SLOTS) do
        local name = "OnUseGearSlotButton" .. slotID
        local btn = CreateFrame("Button", name, mainFrame, "SecureActionButtonTemplate")
        btn:SetSize(p.ButtonSize, p.ButtonSize)
        
        local icon = btn:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        btn.icon = icon
        
        local keybindText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        keybindText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        keybindText:SetTextColor(1, 1, 1, 0.9)
        btn.keybindText = keybindText
        
        local cd = CreateFrame("Cooldown", name .. "Cooldown", btn, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetCountdownFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        btn.cooldown = cd
        
        btn:SetScript("OnEnter", function(self)
            SetHandleAlpha(1.0)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetInventoryItem("player", slotID)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            SetHandleAlpha(0.0)
            GameTooltip:Hide()
        end)
        
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", tostring(slotID))
        
        slotButtons[slotID] = btn
    end
end

-------------------------------------------------------------------------------
-- GUI Options Settings Panel
-------------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "OnUseGearOptionsPanel", UIParent)
optionsPanel.name = "OnUseGear"

local function CreateOptionsGUI()
    local p = GetProfile()
    
    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("OnUseGear Settings")

    -- Lock Checkbox
    local lockCheck = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    lockCheck.Text:SetText("Lock Action Bar")
    lockCheck:SetChecked(p.Locked)
    lockCheck:SetScript("OnClick", function(self)
        p.Locked = self:GetChecked()
        RefreshLayoutAndLock()
    end)

    -- Vertical Checkbox
    local verticalCheck = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    verticalCheck:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -8)
    verticalCheck.Text:SetText("Align Vertically")
    verticalCheck:SetChecked(p.IsVertical)
    verticalCheck:SetScript("OnClick", function(self)
        p.IsVertical = self:GetChecked()
        UpdateOnUseGear()
    end)

    -- Minimap Checkbox
    local minimapCheck = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", verticalCheck, "BOTTOMLEFT", 0, -8)
    minimapCheck.Text:SetText("Hide Minimap Button")
    minimapCheck:SetChecked(p.Minimap and p.Minimap.hide)
    minimapCheck:SetScript("OnClick", function(self)
        if not p.Minimap then p.Minimap = { hide = false, minimapPos = 45 } end
        p.Minimap.hide = self:GetChecked()
        -- UpdateMinimapButton()
    end)

    -- Size Input Label
    local sizeLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -20)
    sizeLabel:SetText("Button Size (20 - 80):")

    -- Size EditBox
    local sizeInput = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
    sizeInput:SetSize(50, 20)
    sizeInput:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    sizeInput:SetAutoFocus(false)
    sizeInput:SetMaxLetters(2)
    sizeInput:SetNumber(p.ButtonSize)

    local function SaveSizeInput(self)
        local val = tonumber(self:GetText())
        if not val then val = p.ButtonSize end
        if val < 20 then val = 20 elseif val > 80 then val = 80 end
        self:SetText(val)
        p.ButtonSize = val
        UpdateOnUseGear()
    end

    sizeInput:SetScript("OnEnterPressed", function(self)
        SaveSizeInput(self)
        self:ClearFocus()
    end)
    sizeInput:SetScript("OnEditFocusLost", function(self)
        SaveSizeInput(self)
    end)

    -- Profile Selector Dropdown Label
    local dropdownLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dropdownLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", -4, -24)
    dropdownLabel:SetText("Active Profile:")

    -- Integration with standard Settings Dropdown Menu (Dragonflight API)
    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "OnUseGear")
    OnUseGear_CategoryID = category:GetID()
    
    -- Create standard Dropdown for the Canvas Layout (11.0 API)
    local profileDropdown = CreateFrame("DropdownButton", nil, optionsPanel, "WowStyle1DropdownTemplate")
    profileDropdown:SetPoint("LEFT", dropdownLabel, "RIGHT", 10, 0)
    profileDropdown:SetWidth(150)
    
    local function IsProfileSelected(profileName)
        return currentProfileKey == profileName
    end

    local function SetProfileSelected(profileName)
        local myKey = UnitName("player") .. " - " .. GetRealmName()
        OnUseGearDB.charToProfile[myKey] = profileName
        currentProfileKey = profileName
        RefreshLayoutAndLock()
        if optionsPanel.refresh then optionsPanel.refresh() end
    end

    profileDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateTitle("Select a Profile")
        if OnUseGearDB and OnUseGearDB.profiles then
            for profileName in pairs(OnUseGearDB.profiles) do
                rootDescription:CreateRadio(profileName, IsProfileSelected, SetProfileSelected, profileName)
            end
        end
    end)

    optionsPanel.refresh = function()
        local currentP = GetProfile()
        lockCheck:SetChecked(currentP.Locked)
        verticalCheck:SetChecked(currentP.IsVertical)
        minimapCheck:SetChecked(currentP.Minimap and currentP.Minimap.hide)
        if currentP and currentP.ButtonSize then
            sizeInput:SetText(tostring(currentP.ButtonSize))
            sizeInput:SetCursorPosition(0)
        end
    end

    optionsPanel:HookScript("OnShow", function()
        if optionsPanel.refresh then
            optionsPanel.refresh()
        end
    end)

    Settings.RegisterAddOnCategory(category)
end

-------------------------------------------------------------------------------
-- Slash Commands Handler
-------------------------------------------------------------------------------
SLASH_OnUseGear1 = "/oug"
SlashCmdList["OnUseGear"] = function(msg)
    if msg == "lock" then
        local p = GetProfile()
        p.Locked = not p.Locked
        RefreshLayoutAndLock()
    else
        Settings.OpenToCategory(OnUseGear_CategoryID)
    end
end

-------------------------------------------------------------------------------
-- Event Listeners
-------------------------------------------------------------------------------
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
mainFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("UPDATE_BINDINGS")
mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

mainFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "OnUseGear" then
        GetProfile()
        InitializeButtons()
        -- UpdateMinimapButton()
        CreateOptionsGUI()
        RefreshLayoutAndLock()
        mainFrame:UnregisterEvent("ADDON_LOADED")
    elseif event == "BAG_UPDATE_COOLDOWN" then
        UpdateButtonCooldowns()
    elseif event == "UPDATE_BINDINGS" then
        ApplyKeybinds()
    elseif event == "PLAYER_REGEN_DISABLED" then
        --
    elseif event == "PLAYER_ENTERING_WORLD" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
        if not InCombatLockdown() then
            UpdateOnUseGear()
            ApplyKeybinds()
        else
            mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateOnUseGear()
        ApplyKeybinds()
        mainFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)
