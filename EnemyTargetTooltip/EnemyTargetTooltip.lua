-- EnemyTargetTooltip.lua
-- A simple addon to show a sticky tooltip of the current target in WoW Classic

-- Define default anchor settings
local DefaultTooltipAnchorPoint = "BOTTOMRIGHT" -- The point on the tooltip that will be anchored
local DefaultScreenAnchorPoint = "BOTTOMRIGHT"  -- The point on the screen we're anchoring to
local DefaultTooltipOffsetX = -13
local DefaultTooltipOffsetY = 70
local settingsFrame = nil
local ghostTooltip = nil
local tooltipAnchorMarker = nil
local screenAnchorMarker = nil
local DefaultTooltipHooksEnabled = true

local function ShowReloadDialog()
    StaticPopupDialogs["RELOAD_UI"] = {
        text = "This change requires a UI reload to take effect. Would you like to reload now?",
        button1 = "Reload UI",
        button2 = "Later",
        OnAccept = function()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("RELOAD_UI")
end


local function UpdateAnchorMarkers()
    if not tooltipAnchorMarker or not screenAnchorMarker then return end

    local tooltipAnchor = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
    local screenAnchor = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint

    -- Position the screen anchor marker at the exact anchor point without offsets
    screenAnchorMarker:ClearAllPoints()
    screenAnchorMarker:SetPoint("CENTER", UIParent, screenAnchor, 0, 0)

    -- Get tooltip reference
    local tooltipFrame = (ghostTooltip and ghostTooltip:IsShown()) and ghostTooltip or
        (GameTooltip:IsShown() and GameTooltip)

    if tooltipFrame then
        -- Get tooltip's actual position after clamping
        local tooltipLeft, tooltipBottom = tooltipFrame:GetLeft(), tooltipFrame:GetBottom()
        local tooltipRight, tooltipTop = tooltipFrame:GetRight(), tooltipFrame:GetTop()

        if tooltipLeft and tooltipBottom then
            local markerX, markerY = 0, 0

            if tooltipAnchor:find("LEFT") then
                markerX = tooltipLeft
            elseif tooltipAnchor:find("RIGHT") then
                markerX = tooltipRight
            else -- CENTER
                markerX = (tooltipLeft + tooltipRight) / 2
            end

            if tooltipAnchor:find("TOP") then
                markerY = tooltipTop
            elseif tooltipAnchor:find("BOTTOM") then
                markerY = tooltipBottom
            else -- CENTER
                markerY = (tooltipTop + tooltipBottom) / 2
            end

            tooltipAnchorMarker:ClearAllPoints()
            tooltipAnchorMarker:SetPoint("CENTER", UIParent, "BOTTOMLEFT", markerX, markerY)
        end
    end

    -- Show markers
    tooltipAnchorMarker:Show()
    screenAnchorMarker:Show()
end

local function CreateAnchorMarker(name)
    -- Clean up any existing marker with this name
    local existingMarker = _G[name]
    if existingMarker then
        existingMarker:Hide()
        existingMarker:SetParent(nil)
    end

    local marker = CreateFrame("Frame", name, UIParent)
    marker:SetSize(20, 20)
    marker:SetFrameStrata("FULLSCREEN_DIALOG") -- Highest normal strata
    marker:SetFrameLevel(100)

    local texture = marker:CreateTexture(nil, "OVERLAY")
    texture:SetColorTexture(1, 0, 0, 1)
    texture:SetAllPoints()

    marker:Hide()
    return marker
end

-- Function to clean up existing markers
local function CleanupMarkers()
    -- Clean up tooltip anchor marker
    if tooltipAnchorMarker then
        tooltipAnchorMarker:Hide()
        tooltipAnchorMarker:SetParent(nil)
        tooltipAnchorMarker = nil
    end
    -- Also try to clean up by name in case the reference was lost
    local existingTooltipMarker = _G["TooltipAnchorMarker"]
    if existingTooltipMarker then
        existingTooltipMarker:Hide()
        existingTooltipMarker:SetParent(nil)
    end

    -- Clean up screen anchor marker
    if screenAnchorMarker then
        screenAnchorMarker:Hide()
        screenAnchorMarker:SetParent(nil)
        screenAnchorMarker = nil
    end
    -- Also try to clean up by name in case the reference was lost
    local existingScreenMarker = _G["ScreenAnchorMarker"]
    if existingScreenMarker then
        existingScreenMarker:Hide()
        existingScreenMarker:SetParent(nil)
    end

    -- Hide ghost tooltip if it exists
    if ghostTooltip then
        ghostTooltip:Hide()
    end
end

local function CreateGhostTooltip()
    local frame = CreateFrame("Frame", "EnemyTooltipGhost", UIParent, "BackdropTemplate")
    frame:SetSize(240, 120)
    frame:SetFrameStrata("TOOLTIP") -- Very high to ensure visibility
    frame:SetFrameLevel(100)

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0.2, 0.8, 0.8)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    frame:SetClampedToScreen(true)

    -- Create the font strings with initial values
    local title = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Tooltip Preview")

    local tooltipAnchor = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    tooltipAnchor:SetPoint("TOPLEFT", 10, -30)

    local screenAnchor = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    screenAnchor:SetPoint("TOPLEFT", 10, -50)

    local xOffset = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    xOffset:SetPoint("TOPLEFT", 10, -70)

    local yOffset = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    yOffset:SetPoint("TOPLEFT", 10, -90)

    -- Add a function to update the text values
    frame.UpdateValues = function()
        local currentTooltipAnchor = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
        local currentScreenAnchor = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint
        local currentXOffset = ToolTipDB.offsetX or DefaultTooltipOffsetX
        local currentYOffset = ToolTipDB.offsetY or DefaultTooltipOffsetY

        tooltipAnchor:SetText("Tooltip Anchor: " .. currentTooltipAnchor)
        screenAnchor:SetText("Screen Anchor: " .. currentScreenAnchor)
        xOffset:SetText("X-Offset: " .. currentXOffset)
        yOffset:SetText("Y-Offset: " .. currentYOffset)
    end

    frame:Hide()
    return frame
end


local function areAnchorsCompatible(fromTooltipAnchor, toScreenAnchor)
    -- If tooltip uses TOP, screen anchor must also be TOP
    if fromTooltipAnchor:find("TOP") and toScreenAnchor:find("BOTTOM") then
        return false
    end

    -- If tooltip has "BOTTOM", screen can't have "TOP"
    if fromTooltipAnchor:find("BOTTOM") and toScreenAnchor:find("TOP") then
        return false
    end

    -- If tooltip has "LEFT", screen can't have "RIGHT"
    if fromTooltipAnchor:find("LEFT") and toScreenAnchor:find("RIGHT") then
        return false
    end

    -- If tooltip has "RIGHT", screen can't have "LEFT"
    if fromTooltipAnchor:find("RIGHT") and toScreenAnchor:find("LEFT") then
        return false
    end

    return true
end

local function getScreenBasedRanges()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()

    -- Use 25% of screen dimensions as the max range
    local maxXRange = math.floor(screenWidth * 0.25)
    local maxYRange = math.floor(screenHeight * 0.25)

    return maxXRange, maxYRange
end


-- Create the main addon frame
local EnemyTargetTooltipFrame = CreateFrame("Frame")

-- Helper function to format large numbers
local function FormatNumber(number)
    if number >= 1e6 then
        return string.format("%.1fm", number / 1e6)
    elseif number >= 1e5 then
        return string.format("%dk", math.floor(number / 1e3))
    elseif number >= 1e3 then
        return string.format("%.1fk", number / 1e3)
    else
        return tostring(number)
    end
end

local function UpdateHealthText(tooltip)
    local unit = select(2, tooltip:GetUnit())
    local timestamp = date("%Y-%m-%d %H:%M:%S")

    if unit and UnitExists(unit) then
        local health = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        local healthPercent = math.ceil((health / maxHealth) * 100) -- Always round up

        -- Format the health and max health numbers
        local formattedHealth = FormatNumber(health)
        local formattedMaxHealth = FormatNumber(maxHealth)

        -- Create or update the health text on the status bar
        if not GameTooltipStatusBar.healthText then
            GameTooltipStatusBar.healthText = GameTooltipStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            GameTooltipStatusBar.healthText:SetPoint("CENTER", GameTooltipStatusBar, "CENTER", 0, 0)
            -- Customize the appearance
            GameTooltipStatusBar.healthText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") -- Set font, size, and outline
            GameTooltipStatusBar.healthText:SetTextColor(1, 1, 1)                         -- Set text color (white in this case)
        end

        if ToolTipDB.cbPercent then
            
            GameTooltipStatusBar.healthText:SetText(formattedHealth .. " / " .. formattedMaxHealth .. " - " .. healthPercent .. "%")
        else
            GameTooltipStatusBar.healthText:SetText(formattedHealth .. " / " .. formattedMaxHealth)
        end

        if ToolTipDB.cbTarget then
            -- Remove existing target line if it exists
            local targetLineIndex = nil
            for i = 1, tooltip:NumLines() do
                local line = _G["GameTooltipTextLeft" .. i]
                if line and line:GetText() and (line:GetText():find("Target:") or line:GetText():find("Target: None")) then
                    targetLineIndex = i
                    break
                end
            end

            if targetLineIndex then
                local targetLine = _G["GameTooltipTextLeft" .. targetLineIndex]
                local targetName = UnitName(unit .. "target")
                if targetName then
                    targetLine:SetText("Target: " .. targetName)
                    targetLine:SetTextColor(1, 1, 0) -- Set text color (yellow in this case)
                else
                    targetLine:SetText("")
                end
            else
                local targetName = UnitName(unit .. "target")
                if targetName then
                    tooltip:AddLine("Target: " .. targetName, 1, 1, 0) -- Set text color (yellow in this case)
                end
            end
        end

        local function SetClassificationText(unit)
            local classification = UnitClassification(unit)
            local classificationText, classificationColor = "", {1, 1, 0} -- Default to yellow
        
            if classification == "worldboss" then
                classificationText = "World Boss"
                classificationColor = {1, 0, 0} -- Red
            elseif classification == "rareelite" then
                classificationText = "Rare Elite"
                classificationColor = {0.75, 0.75, 0.75} -- Light gray
            elseif classification == "elite" then
                classificationText = "Elite"
                classificationColor = {1, 0.5, 0} -- Orange
            elseif classification == "rare" then
                classificationText = "Rare"
                classificationColor = {0.75, 0.75, 0.75} -- Light gray
            elseif classification == "normal" then
                classificationText = "Normal"
                classificationColor = {0, 1, 1} -- White
            elseif classification == "trivial" then
                classificationText = "Trivial"
                classificationColor = {0.5, 0.5, 0.5} -- Gray
            elseif classification == "minus" then
                classificationText = "Minor"
                classificationColor = {0.5, 0.5, 0.5} -- Gray
            end
        
            return classificationText, classificationColor
        end
        
        if ToolTipDB.cbClassification then
            -- Remove existing classification line if it exists
            local classificationLineIndex = nil
            local possibleClassifications = {
                "World Boss", "Rare Elite", "Elite", "Rare", "Normal", "Trivial", "Minor"
            }
            for i = 1, tooltip:NumLines() do
                local line = _G["GameTooltipTextLeft" .. i]
                if line and line:GetText() then
                    for _, classification in ipairs(possibleClassifications) do
                        if line:GetText():find(classification) then
                            classificationLineIndex = i
                            break
                        end
                    end
                end
                if classificationLineIndex then break end
            end
        
            local classificationText, classificationColor = SetClassificationText(unit)
        
            if classificationLineIndex then
                local classificationLine = _G["GameTooltipTextLeft" .. classificationLineIndex]
                if classificationText ~= "" then
                    classificationLine:SetText(classificationText)
                    classificationLine:SetTextColor(unpack(classificationColor))
                else
                    classificationLine:SetText("")
                end
            else
                if classificationText ~= "" then
                    tooltip:AddLine(classificationText, unpack(classificationColor))
                end
            end
        end

        if ToolTipDB.cbGuild then
            -- Check if the unit is a player
            if UnitIsPlayer(unit) then
                -- Remove existing guild lines if they exist
                local guildLineIndex = nil
                for i = 1, tooltip:NumLines() do
                    local line = _G["GameTooltipTextLeft" .. i]
                    if line and line:GetText() then
                        if line:GetText():find("Guild:") or line:GetText():find("Rank:") then
                            guildLineIndex = i
                            break
                        end
                    end
                end
        
                if guildLineIndex then
                    local guildName, guildRankName = GetGuildInfo(unit)
                    if guildName then
                        local guildLine = _G["GameTooltipTextLeft" .. guildLineIndex]
                        guildLine:SetText("Guild: " .. guildName)
                        guildLine:SetTextColor(0, 1, 0) -- Set text color (green in this case)
                        local rankLine = _G["GameTooltipTextLeft" .. (guildLineIndex + 1)]
                        rankLine:SetText("Rank: " .. guildRankName)
                        rankLine:SetTextColor(0, 1, 0) -- Set text color (green in this case)
                    else
                        local guildLine = _G["GameTooltipTextLeft" .. guildLineIndex]
                        guildLine:SetText("")
                        local rankLine = _G["GameTooltipTextLeft" .. (guildLineIndex + 1)]
                        rankLine:SetText("")
                    end
                else
                    local guildName, guildRankName = GetGuildInfo(unit)
                    if guildName then
                        tooltip:AddLine("Guild: " .. guildName, 0, 1, 0) -- Set text color (green in this case)
                        tooltip:AddLine("Rank: " .. guildRankName, 0, 1, 0) -- Set text color (green in this case)
                    end
                end
            end
        end

        tooltip:Show()
    end
end

local function ShowGhostTooltip()
    if settingsFrame and settingsFrame:IsShown() then
        UpdateAnchorMarkers()
        -- Create ghost tooltip if it doesn't exist
        if not ghostTooltip then
            ghostTooltip = CreateGhostTooltip()
        end

        ghostTooltip.UpdateValues()
        -- Position ghost tooltip using same settings as regular tooltip
        ghostTooltip:ClearAllPoints()
        ghostTooltip:SetPoint(
            ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint,
            UIParent,
            ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint,
            ToolTipDB.offsetX or DefaultTooltipOffsetX,
            ToolTipDB.offsetY or DefaultTooltipOffsetY
        )
        ghostTooltip:Show()
    end
end

-- Function to show enemy target tooltip with customizable anchor points
local function ShowEnemyTargetTooltip()
    -- Hide ghost frame by default
    if ghostTooltip then
        ghostTooltip:Hide()
    end

    -- First check if we have a target or mouseover unit to show information for
    local unit = UnitExists("target") and "target" or (UnitExists("mouseover") and "mouseover" or nil)
    if unit then
        -- Clear any existing tooltip positioning to prevent conflicts
        GameTooltip:ClearAllPoints()

        -- Set the tooltip owner to WorldFrame with no automatic anchoring
        GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

        -- Get saved anchor points or use defaults if not set
        local tooltipAnchorPoint = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
        local screenAnchorPoint = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint

        -- Position the tooltip using saved or default values
        GameTooltip:SetPoint(
            tooltipAnchorPoint,
            UIParent,
            screenAnchorPoint,
            ToolTipDB.offsetX or DefaultTooltipOffsetX,
            ToolTipDB.offsetY or DefaultTooltipOffsetY
        )

        -- Set and show the tooltip for the current unit
        GameTooltip:SetUnit(unit)
        GameTooltip:Show()
    else
        -- If settings frame is shown but no unit exists, show ghost frame
        ShowGhostTooltip()

        -- Only fade out the GameTooltip if there is no mouseover unit
        if not UnitExists("mouseover") then
            GameTooltip:FadeOut()
        end
    end
end

-- Hook into OnTooltipSetUnit to update health text
GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    UpdateHealthText(tooltip)
end)
-- Function to update both slider ranges based on anchor point
local function updateSliderRanges(xSlider, ySlider, tooltipAnchor, screenAnchor)
    local maxXRange, maxYRange = getScreenBasedRanges()

    -- X-axis slider ranges
    local xMinValue, xMaxValue = -maxXRange, maxXRange -- default for CENTER
    local yMinValue, yMaxValue = -maxYRange, maxYRange -- default for CENTER

    -- Set X ranges based on screen anchor
    if screenAnchor == "LEFT" or screenAnchor == "TOPLEFT" or screenAnchor == "BOTTOMLEFT" then
        xMinValue, xMaxValue = 0, maxXRange  -- Only positive X values
    elseif screenAnchor == "RIGHT" or screenAnchor == "TOPRIGHT" or screenAnchor == "BOTTOMRIGHT" then
        xMinValue, xMaxValue = -maxXRange, 0 -- Only negative X values
    end

    -- Set Y ranges based on screen anchor
    if screenAnchor == "TOP" or screenAnchor == "TOPLEFT" or screenAnchor == "TOPRIGHT" then
        yMinValue, yMaxValue = -maxYRange, 0 -- Only negative Y values
    elseif screenAnchor == "BOTTOM" or screenAnchor == "BOTTOMLEFT" or screenAnchor == "BOTTOMRIGHT" then
        yMinValue, yMaxValue = 0, maxYRange  -- Only positive Y values
    end

    -- Set X slider values
    xSlider:SetMinMaxValues(xMinValue, xMaxValue)
    _G[xSlider:GetName() .. "Low"]:SetText(tostring(xMinValue))
    _G[xSlider:GetName() .. "High"]:SetText(tostring(xMaxValue))

    -- Set Y slider values
    ySlider:SetMinMaxValues(yMinValue, yMaxValue)
    _G[ySlider:GetName() .. "Low"]:SetText(tostring(yMinValue))
    _G[ySlider:GetName() .. "High"]:SetText(tostring(yMaxValue))

    -- Ensure current values are within new ranges
    local currentX = xSlider:GetValue()
    local currentY = ySlider:GetValue()

    if currentX < xMinValue then
        xSlider:SetValue(xMinValue)
    elseif currentX > xMaxValue then
        xSlider:SetValue(xMaxValue)
    end

    if currentY < yMinValue then
        ySlider:SetValue(yMinValue)
    elseif currentY > yMaxValue then
        ySlider:SetValue(yMaxValue)
    end
end

local function CreateSettingsFrame()
    -- Create a frame to hold our settings
    local frame = CreateFrame("Frame", "EnemyTooltipSettings", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetSize(300, 600)
    frame:SetClampedToScreen(true)
    frame:SetPoint("LEFT", UIParent, "RIGHT", 100, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Create a title for our settings window
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Target Tooltip Settings")

    frame.CloseButton:SetScript("OnClick", function()
        CleanupMarkers() -- Clean up markers and ghost tooltip
        frame:Hide()
    end)

    local tooltipAnchorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tooltipAnchorLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
    tooltipAnchorLabel:SetText("Tooltip Anchor:")

    local tooltipAnchorDropdown = CreateFrame("Frame", "EnemyTooltipFromAnchor", frame, "UIDropDownMenuTemplate")
    tooltipAnchorDropdown:SetPoint("TOPLEFT", tooltipAnchorLabel, "TOPLEFT", -20, -15)
    tooltipAnchorDropdown:SetFrameStrata("DIALOG")
    tooltipAnchorDropdown:SetFrameLevel(101)

    local screenAnchorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    screenAnchorLabel:SetPoint("TOPLEFT", tooltipAnchorLabel, "BOTTOMLEFT", 0, -50)
    screenAnchorLabel:SetText("Screen Anchor:")

    local screenAnchorDropdown = CreateFrame("Frame", "EnemyTooltipToAnchor", frame, "UIDropDownMenuTemplate")
    screenAnchorDropdown:SetPoint("TOPLEFT", screenAnchorLabel, "TOPLEFT", -20, -15)
    screenAnchorDropdown:SetFrameStrata("DIALOG")
    screenAnchorDropdown:SetFrameLevel(101)

    -- Create anchor display text
    local tooltipAnchorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tooltipAnchorText:SetPoint("TOPLEFT", screenAnchorDropdown, "BOTTOMLEFT", 20, -15)

    local screenAnchorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    screenAnchorText:SetPoint("TOPLEFT", tooltipAnchorText, "BOTTOMLEFT", 0, -15)

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("TOPRIGHT", tooltipAnchorDropdown, "TOPRIGHT", 110, -0)
    resetButton:SetText("Reset Positon")

    -- Create a slider for the X offset
    local xSlider = CreateFrame("Slider", "EnemyTooltipXOffset", frame, "OptionsSliderTemplate")
    xSlider:SetPoint("CENTER", frame, "CENTER", 0, 40)
    xSlider:SetValueStep(1)
    xSlider:SetObeyStepOnDrag(true)
    xSlider:SetWidth(260)
    xSlider:SetFrameStrata("DIALOG")
    xSlider:SetFrameLevel(101)

    _G[xSlider:GetName() .. "Text"]:SetText("X Offset")

    -- Create a slider for the Y offset
    local ySlider = CreateFrame("Slider", "EnemyTooltipYOffset", frame, "OptionsSliderTemplate")
    ySlider:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -30)
    ySlider:SetValueStep(1)
    ySlider:SetObeyStepOnDrag(true)
    ySlider:SetWidth(260)
    ySlider:SetFrameStrata("DIALOG")
    ySlider:SetFrameLevel(101)

    _G[ySlider:GetName() .. "Text"]:SetText("Y Offset")

    -- Create value display for X Slider
    local xValueText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xValueText:SetPoint("BOTTOM", xSlider, "BOTTOM", 0, -10)
    xValueText:SetText("Current X: 0")

    -- Create value display for Y Slider
    local yValueText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yValueText:SetPoint("BOTTOM", ySlider, "BOTTOM", 0, -10)
    yValueText:SetText("Current Y: 0")

    -- Define the available anchor points for our dropdowns
    local anchorPoints = {
        "TOPLEFT", "TOP", "TOPRIGHT",
        "LEFT", "CENTER", "RIGHT",
        "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
    }

    -- Function to update anchor text
    local function UpdateAnchorText()
        local tooltipAnchor = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
        local screenAnchor = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint
        tooltipAnchorText:SetText(string.format("Tooltip Anchor: %s", tooltipAnchor))
        screenAnchorText:SetText(string.format("Screen Anchor: %s", screenAnchor))
    end

    -- Initialize both dropdown menus
    local function InitializeAnchorDropdown(dropdown, dropdownType)
        local function OnClick(self)
            local anchor = self.value
            if dropdownType == "tooltip" then -- More descriptive than "from"
                ToolTipDB.TooltipAnchorPoint = anchor
                -- Update ranges for both sliders when anchor changes
                updateSliderRanges(xSlider, ySlider, ToolTipDB.TooltipAnchorPoint,
                    ToolTipDB.ScreenAnchorPoint)

                -- Reset offsets to 0
                ToolTipDB.offsetX = 0
                ToolTipDB.offsetY = 0

                -- Update slider positions
                xSlider:SetValue(0)
                ySlider:SetValue(0)

                -- Reset the "screenAnchor" anchor if it's no longer compatible
                local currentToAnchor = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint
                if not areAnchorsCompatible(anchor, currentToAnchor) then
                    ToolTipDB.ScreenAnchorPoint = anchor
                    UIDropDownMenu_SetSelectedValue(screenAnchorDropdown, anchor)
                    UIDropDownMenu_SetText(screenAnchorDropdown, anchor)
                end
            else
                -- Handling "Screen Anchor" selection
                local fromAnchor = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
                if areAnchorsCompatible(fromAnchor, anchor) then
                    ToolTipDB.ScreenAnchorPoint = anchor

                    -- Reset offsets to 0
                    ToolTipDB.offsetX = 0
                    ToolTipDB.offsetY = 0

                    updateSliderRanges(xSlider, ySlider, fromAnchor, anchor)

                    -- Update slider positions
                    xSlider:SetValue(0)
                    ySlider:SetValue(0)
                else
                    return
                end
            end

            UIDropDownMenu_SetSelectedValue(dropdown, anchor)
            UIDropDownMenu_SetText(dropdown, anchor)
            UpdateAnchorText()
            ShowEnemyTargetTooltip()
            UpdateAnchorMarkers()
            if ghostTooltip and ghostTooltip:IsShown() then
                ghostTooltip.UpdateValues()
            end
        end

        local function Initialize(self, level)
            local info = UIDropDownMenu_CreateInfo()
            local currentTooltipAnchor = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
            local currentScreenAnchor = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint

            for _, point in ipairs(anchorPoints) do
                -- For tooltip dropdown, show all points (maybe not the best UX)
                -- For screen dropdown, only show compatible anchors (needs fix)
                if dropdownType == "tooltip" or areAnchorsCompatible(currentTooltipAnchor, point) then
                    info.text = point
                    info.value = point
                    info.func = OnClick
                    info.checked = (point == (dropdownType == "tooltip" and currentTooltipAnchor or currentScreenAnchor))
                    UIDropDownMenu_AddButton(info, level)
                end
            end

            -- Set the initial text
            UIDropDownMenu_SetText(dropdown, dropdownType == "tooltip" and currentTooltipAnchor or currentScreenAnchor)
        end

        UIDropDownMenu_Initialize(dropdown, Initialize)
        UIDropDownMenu_SetWidth(dropdown, 120)
        UIDropDownMenu_JustifyText(dropdown, "LEFT")
    end

    InitializeAnchorDropdown(tooltipAnchorDropdown, "tooltip")
    InitializeAnchorDropdown(screenAnchorDropdown, "screen")

    -- Set up the slider value change handlers
    local function OnSliderChanged(self, value)
        if self == xSlider then
            ToolTipDB.offsetX = value
            xValueText:SetText(string.format("Current X: %d", value))
        else
            ToolTipDB.offsetY = value
            yValueText:SetText(string.format("Current Y: %d", value))
        end
        ShowEnemyTargetTooltip()
        UpdateAnchorMarkers()
        if ghostTooltip and ghostTooltip:IsShown() then
            ghostTooltip.UpdateValues()
        end
    end

    xSlider:SetScript("OnValueChanged", OnSliderChanged)
    ySlider:SetScript("OnValueChanged", OnSliderChanged)

    -- Set up the reset button's functionality
    -- Set up the reset button's functionality
    resetButton:SetScript("OnClick", function()
        -- Reset all settings to their default values
        ToolTipDB.offsetX = DefaultTooltipOffsetX
        ToolTipDB.offsetY = DefaultTooltipOffsetY
        ToolTipDB.TooltipAnchorPoint = DefaultTooltipAnchorPoint
        ToolTipDB.ScreenAnchorPoint = DefaultScreenAnchorPoint

        -- Update ranges before setting values, using both anchor points
        updateSliderRanges(xSlider, ySlider, DefaultTooltipAnchorPoint, DefaultScreenAnchorPoint)

        -- Update all UI elements to show default values
        xSlider:SetValue(DefaultTooltipOffsetX)
        ySlider:SetValue(DefaultTooltipOffsetY)
        xValueText:SetText(string.format("Current X: %d", DefaultTooltipOffsetX))
        yValueText:SetText(string.format("Current Y: %d", DefaultTooltipOffsetY))

        -- Update dropdowns
        UIDropDownMenu_SetSelectedValue(tooltipAnchorDropdown, DefaultTooltipAnchorPoint)
        UIDropDownMenu_SetText(tooltipAnchorDropdown, DefaultTooltipAnchorPoint)
        UIDropDownMenu_SetSelectedValue(screenAnchorDropdown, DefaultScreenAnchorPoint)
        UIDropDownMenu_SetText(screenAnchorDropdown, DefaultScreenAnchorPoint)

        UpdateAnchorText()
        ShowEnemyTargetTooltip()
        UpdateAnchorMarkers() -- Added to ensure markers update with reset
    end)

    -- Function to refresh the UI with current settings
    frame.RefreshSettings = function()
        -- Get current anchor points
        local currentTooltipAnchor = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
        local currentScreenAnchor = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint

        -- Update ranges based on both anchor points
        updateSliderRanges(xSlider, ySlider, currentTooltipAnchor, currentScreenAnchor)

        -- Get current offset values
        local xValue = ToolTipDB.offsetX or DefaultTooltipOffsetX
        local yValue = ToolTipDB.offsetY or DefaultTooltipOffsetY

        -- Update slider values and text
        xSlider:SetValue(xValue)
        ySlider:SetValue(yValue)
        xValueText:SetText(string.format("Current X: %d", xValue))
        yValueText:SetText(string.format("Current Y: %d", yValue))

        -- Update dropdown values and text
        UIDropDownMenu_SetSelectedValue(tooltipAnchorDropdown, currentTooltipAnchor)
        UIDropDownMenu_SetText(tooltipAnchorDropdown, currentTooltipAnchor)
        UIDropDownMenu_SetSelectedValue(screenAnchorDropdown, currentScreenAnchor)
        UIDropDownMenu_SetText(screenAnchorDropdown, currentScreenAnchor)

        UpdateAnchorText()
        UpdateAnchorMarkers() -- Added to ensure markers update with refresh
    end

    local tooltipHooksCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    tooltipHooksCheckbox:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -20)
    tooltipHooksCheckbox.text = tooltipHooksCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tooltipHooksCheckbox.text:SetPoint("LEFT", tooltipHooksCheckbox, "RIGHT", 5, 0)
    tooltipHooksCheckbox.text:SetText("Apply positioning to mouseover tooltips")
    tooltipHooksCheckbox:SetChecked(ToolTipDB.tooltipHooksEnabled)

    tooltipHooksCheckbox:SetScript("OnClick", function(self)
        ToolTipDB.tooltipHooksEnabled = self:GetChecked()
        ShowReloadDialog()
    end)

    local cbPercent = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cbPercent:SetPoint("TOPLEFT", tooltipHooksCheckbox, "BOTTOMLEFT", 0, -5)
    cbPercent.text = cbPercent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbPercent.text:SetPoint("LEFT", cbPercent, "RIGHT", 5, 0)
    cbPercent.text:SetText("Show health as percentage")
    cbPercent:SetChecked(ToolTipDB.cbPercent)
    cbPercent:SetScript("OnClick", function(self)
        ToolTipDB.cbPercent = self:GetChecked()
    end)

    local cbTarget = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cbTarget:SetPoint("TOPLEFT", cbPercent, "BOTTOMLEFT", 0, -5)
    cbTarget.text = cbTarget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbTarget.text:SetPoint("LEFT", cbTarget, "RIGHT", 5, 0)
    cbTarget.text:SetText("Show target in tooltip")
    cbTarget:SetChecked(ToolTipDB.cbTarget)
    cbTarget:SetScript("OnClick", function(self)
        ToolTipDB.cbTarget = self:GetChecked()
    end)

    local cbGuild = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cbGuild:SetPoint("TOPLEFT", cbTarget, "BOTTOMLEFT", 0, -5)
    cbGuild.text = cbGuild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbGuild.text:SetPoint("LEFT", cbGuild, "RIGHT", 5, 0)
    cbGuild.text:SetText("Show guild in tooltip")
    cbGuild:SetChecked(ToolTipDB.cbGuild)
    cbGuild:SetScript("OnClick", function(self)
        ToolTipDB.cbGuild = self:GetChecked()
    end)

    local cbClassification = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cbClassification:SetPoint("TOPLEFT", cbGuild, "BOTTOMLEFT", 0, -5)
    cbClassification.text = cbClassification:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbClassification.text:SetPoint("LEFT", cbClassification, "RIGHT", 5, 0)
    cbClassification.text:SetText("Show classification in tooltip")
    cbClassification:SetChecked(ToolTipDB.cbClassification)
    cbClassification:SetScript("OnClick", function(self)
        ToolTipDB.cbClassification = self:GetChecked()
    end)

    return frame
end

-- Keep the original slash command setup
SLASH_ENEMYTOOLTIP1 = "/etooltip"
SLASH_ENEMYTOOLTIP2 = "/ett"

-- Create toggle function for both settings and ghost frame
local function ToggleSettingsFrame()
    if settingsFrame and settingsFrame.IsShown and settingsFrame:IsShown() then
        if settingsFrame.Hide then
            settingsFrame:Hide()
        end
        CleanupMarkers() -- Clean up when closing settings
    elseif settingsFrame then
        if settingsFrame.Show then
            settingsFrame:Show()
        end
        if settingsFrame.RefreshSettings then
            settingsFrame:RefreshSettings()
        end
        -- Create new markers when opening settings
        tooltipAnchorMarker = CreateAnchorMarker("TooltipAnchorMarker")
        screenAnchorMarker = CreateAnchorMarker("ScreenAnchorMarker")
        -- Show ghost tooltip if no target and update markers
        if not UnitExists("target") then
            ShowEnemyTargetTooltip()
        end
        UpdateAnchorMarkers()
    end
end

-- Update the slash command to use the toggle function
SlashCmdList["ENEMYTOOLTIP"] = function(msg)
    if settingsFrame then -- Check if frame exists
        ToggleSettingsFrame()
    end
end

local function InitializeAddon(self, event, addonName)
    if addonName ~= "EnemyTargetTooltip" then return end

    -- Clean up any existing markers first
    CleanupMarkers()

    -- Initialize saved variables with default values
    ToolTipDB = ToolTipDB or {
        offsetX = DefaultTooltipOffsetX,
        offsetY = DefaultTooltipOffsetY,
        anchorPoint = DefaultTooltipAnchorPoint,
        relativePoint = DefaultScreenAnchorPoint,
        tooltipHooksEnabled = DefaultTooltipHooksEnabled,
        cbPercent = false,
        cbTarget = true,
        cbGuild = true,
        cbClassification = true
    }

    -- Create new markers
    tooltipAnchorMarker = CreateAnchorMarker("TooltipAnchorMarker")
    screenAnchorMarker = CreateAnchorMarker("ScreenAnchorMarker")

    -- Create settings frame after DB is initialized
    settingsFrame = CreateSettingsFrame()

    if ToolTipDB.tooltipHooksEnabled then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
            if tooltip and tooltip == GameTooltip then
                tooltip:ClearAllPoints()

                local tooltipAnchorPoint = ToolTipDB.TooltipAnchorPoint or DefaultTooltipAnchorPoint
                local screenAnchorPoint = ToolTipDB.ScreenAnchorPoint or DefaultScreenAnchorPoint

                tooltip:SetPoint(
                    tooltipAnchorPoint,
                    UIParent,
                    screenAnchorPoint,
                    ToolTipDB.offsetX or DefaultTooltipOffsetX,
                    ToolTipDB.offsetY or DefaultTooltipOffsetY
                )
            end
        end)
    end
end


-- Event handler function
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == "EnemyTargetTooltip" then
            InitializeAddon(self, event, ...)
            print("|cFF00FF00TargetTooltip|r loaded. Type |cFFFFFF00/ett|r to open the settings.")
        elseif loadedAddonName == "Leatrix_Plus" then
            if LeaPlusDB and LeaPlusDB["TipModEnable"] == "On" then
                print(
                "|cFF00FF00TargetTooltip:|r Detected a Leatrix Plus setting that conflicts with our addon. Adjusting for compatibility.")
                LeaPlusDB["TipModEnable"] = "Off"
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if settingsFrame and not settingsFrame:IsShown() then
            CleanupMarkers()
        end
        ShowEnemyTargetTooltip()
    elseif event == "PLAYER_REGEN_DISABLED" then -- Entering combat
        CleanupMarkers()
        if settingsFrame and settingsFrame:IsShown() then
            settingsFrame:Hide()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        CleanupMarkers() -- Clean up when loading screens finish
    elseif event == "PLAYER_LEAVING_WORLD" then
        CleanupMarkers() -- Clean up when starting loading screens
    end
end

-- Register events and set the event handler
EnemyTargetTooltipFrame:RegisterEvent("ADDON_LOADED")
EnemyTargetTooltipFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EnemyTargetTooltipFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EnemyTargetTooltipFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EnemyTargetTooltipFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
EnemyTargetTooltipFrame:SetScript("OnEvent", OnEvent)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_HEALTH")
-- Set the script to update the tooltip on health change
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_HEALTH" and arg1 == "target" then
        if GameTooltip:IsShown() and UnitExists("target") then
            GameTooltip:ClearLines()
            GameTooltip:SetUnit("target")
            UpdateHealthText(GameTooltip)
        end
    end
end)
