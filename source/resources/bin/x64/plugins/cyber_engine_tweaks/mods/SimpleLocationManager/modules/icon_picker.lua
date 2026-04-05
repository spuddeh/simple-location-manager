-------------------------------------------------------------------
-- Mod Name: Simple Location Manager
-- Author: Spuddeh
-- Description: Helper module for selecting icons from CET IconGlyphs.
-- Mod Version: 1.3.1
-------------------------------------------------------------------

local IconPicker = {}

-- State
local searchText = ""
local cachedIcons = nil
local filteredIcons = nil -- Optimization: cache filtered list if search changes

--- Initialize and sort icons once
local function EnsureCache()
    if cachedIcons then return end

    cachedIcons = {}
    if IconGlyphs then
        for name, glyph in pairs(IconGlyphs) do
            table.insert(cachedIcons, { name = name, glyph = glyph })
        end
        -- Sort alphabetically
        table.sort(cachedIcons, function(a, b) return a.name < b.name end)
    end
end

--- Clear the search filter
--- Clear the search filter
function IconPicker.ClearSearch()
    searchText = ""
    filteredIcons = nil
    -- Force reclaim focus? No, just state reset.
end

--- Draw the picker widget
--- @param currentIconName string|nil The name of the currently selected icon
--- @param onSelectCallback function(iconName) Callback function when an icon is clicked
--- @param height number|nil Optional height for the scrollable area (default: 300)
function IconPicker.Draw(currentIconName, onSelectCallback, height)
    EnsureCache()

    if not cachedIcons then
        ImGui.Text("Error: IconGlyphs global not found.")
        return
    end

    -- Stats
    local count = filteredIcons and #filteredIcons or #cachedIcons
    ImGui.TextDisabled(string.format("Total Icons: %d", count))
    ImGui.Separator()

    -- Search Bar with Clear Button
    local style = ImGui.GetStyle()
    local clearBtnW = ImGui.CalcTextSize(IconGlyphs.Eraser) + (style.FramePadding.x * 2)
    local regionAvail = ImGui.GetContentRegionAvail()
    -- Input Width = Avail - ButtonWidth - Spacing
    ImGui.SetNextItemWidth(regionAvail - clearBtnW - style.ItemSpacing.x)

    local newVal, changed = ImGui.InputTextWithHint("##IconSearch", IconGlyphs.Magnify .. " Search icons...", searchText,
        100)
    if changed then
        searchText = newVal
        filteredIcons = nil -- Invalidate filter cache
    end

    ImGui.SameLine()
    if ImGui.Button(IconGlyphs.Eraser) then
        IconPicker.ClearSearch()
    end
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Clear Search") end

    -- Filter Logic (or use cache)
    local displayList = cachedIcons
    if searchText ~= "" then
        if not filteredIcons then
            filteredIcons = {}
            local query = string.lower(searchText)
            for _, icon in ipairs(cachedIcons) do
                if string.find(string.lower(icon.name), query) then
                    table.insert(filteredIcons, icon)
                end
            end
        end
        displayList = filteredIcons
    end

    local childHeight = height or 300

    -- Scrollable Child Area
    -- Force Vertical Scrollbar to ensure consistent layout width
    if ImGui.BeginChild("IconGrid", 0, childHeight, true, ImGuiWindowFlags.AlwaysVerticalScrollbar) then
        local itemSize = 45
        local spacing = style.ItemSpacing.x

        -- Dynamic Wrap Logic variables
        local wx, wy = ImGui.GetWindowPos()
        local wrx, wry = ImGui.GetWindowContentRegionMax()
        local windowVisibleX2 = wx + wrx

        for i, icon in ipairs(displayList) do
            -- Highlight selected
            local isSelected = (currentIconName == icon.name)

            -- Push Colors for "Black Background, Hover Effect"
            if isSelected then
                ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.6, 1.0, 1.0) -- Blue Current
            else
                -- User Request: "make them transparent"
                ImGui.PushStyleColor(ImGuiCol.Button, 0.0, 0.0, 0.0, 0.0) -- Transparent Default
            end

            -- Draw Button
            if ImGui.Button(icon.glyph .. "##" .. icon.name, itemSize, itemSize) then
                if onSelectCallback then onSelectCallback(icon.name) end
            end

            ImGui.PopStyleColor() -- Pop Button Color

            -- Tooltip on hover
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip(icon.name)
            end

            -- Dynamic Wrapping
            -- Check if next button fits on this line
            local lastButtonX2, lastButtonY2 = ImGui.GetItemRectMax()
            local nextButtonX2 = lastButtonX2 + spacing + itemSize

            -- Only SameLine if not last item and next item fits
            if i < #displayList and nextButtonX2 < windowVisibleX2 then
                ImGui.SameLine()
            end
        end
        ImGui.EndChild()
    end
end

return IconPicker
