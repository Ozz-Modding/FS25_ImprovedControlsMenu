ImprovedControlsController = {}
local ImprovedControlsController_mt = Class(ImprovedControlsController)

function ImprovedControlsController.new()
    local self = setmetatable({}, ImprovedControlsController_mt)

    -- Wrap the base ControlsController
    self.baseController = ControlsController.new()

    -- Filter state
    self.nameFilter = ""
    self.inputFilter = nil -- {deviceId, axisNames[]}
    self.duplicateBindings = {} -- Map of binding -> count

    return self
end

-- Delegate to base controller
function ImprovedControlsController:setMessageCallback(callback)
    self.baseController:setMessageCallback(callback)
end

function ImprovedControlsController:setInputDoneCallback(callback)
    self.baseController:setInputDoneCallback(callback)
end

function ImprovedControlsController:saveChanges()
    self.baseController:saveChanges()
end

function ImprovedControlsController:discardChanges()
    self.baseController:discardChanges()
end

function ImprovedControlsController:loadBindings()
    -- Load ALL actions including locked ones (menu navigation etc.)
    self.actionBindings = g_inputBinding:getActionBindingsCopy(false)
    self.baseController.actionBindings = self.actionBindings
end

function ImprovedControlsController:loadDefaultSettings()
    self.baseController:loadDefaultSettings()
end

function ImprovedControlsController:getBindingInputDisplayText(binding)
    return self.baseController:getBindingInputDisplayText(binding)
end

function ImprovedControlsController:beginWaitForInput(deviceCategory, bindingIndex, displayActionBinding, bindingControlsRowIndex)
    self.baseController:beginWaitForInput(deviceCategory, bindingIndex, displayActionBinding, bindingControlsRowIndex)
end

-- Expose waitForInput property
function ImprovedControlsController:isWaitingForInput()
    return self.baseController.waitForInput
end

-- Override to allow locked bindings on gamepad but block keyboard (would break game menus)
function ImprovedControlsController:onClickInput(deviceCategory, bindingIndex, displayActionBinding, bindingControlsRowIndex)
    local startedListening = false

    if not self.waitForInput then
        local lockedSet = ControlsController.LOCKED_BINDINGS[bindingIndex]
        if lockedSet and lockedSet[displayActionBinding.action.name] then
            if deviceCategory == InputDevice.CATEGORY.KEYBOARD_MOUSE then
                if bindingIndex == ControlsController.BINDING_TERTIARY then
                    self.baseController.messageCallback(ControlsController.MESSAGE_CANNOT_MAP_MOUSE)
                else
                    self.baseController.messageCallback(ControlsController.MESSAGE_CANNOT_MAP_KEY)
                end
                return startedListening
            end
            -- Gamepad: fall through and allow binding
        end
        self:beginWaitForInput(deviceCategory, bindingIndex, displayActionBinding, bindingControlsRowIndex)
        startedListening = true
    end

    return startedListening
end

-- Get device category action bindings using our full action list (including locked)
function ImprovedControlsController:getDeviceCategoryActionBindings(deviceCategory)
    self.baseController.numGamepads = getNumOfGamepads()

    local deviceToBindingIndexMapping = {}
    for idx, device in pairs(g_inputBinding:getGamepadDevices()) do
        deviceToBindingIndexMapping[device.deviceId] = idx + 3
    end

    local categories = {}
    local categoryMapping = {}

    for _, actionBinding in ipairs(self.actionBindings) do
        local displayCategory = actionBinding.action.displayCategory
        local categoryName = displayCategory == nil and "$l10n_inputCategory_OTHER" or displayCategory

        local cat
        if categoryMapping[categoryName] == nil then
            cat = {name = categoryName}
            table.insert(categories, cat)
            categoryMapping[categoryName] = #categories
        else
            cat = categories[categoryMapping[categoryName]]
        end

        table.insert(cat, self.baseController:createDisplayAction(deviceCategory, actionBinding, true, deviceToBindingIndexMapping))
        if actionBinding.action:isFullAxis() then
            table.insert(cat, self.baseController:createDisplayAction(deviceCategory, actionBinding, false, deviceToBindingIndexMapping))
        end
    end

    return categories
end

-- Get all action bindings with filters applied
function ImprovedControlsController:getFilteredDeviceCategoryActionBindings(deviceCategory)
    local allCategories = self:getDeviceCategoryActionBindings(deviceCategory)
    
    -- Build duplicate bindings map first
    self:buildDuplicateBindingsMap()
    
    -- If no filters active, return all
    if self.nameFilter == "" and self.inputFilter == nil then
        return allCategories, false
    end
    
    -- Apply filters
    local filteredCategories = {}
    local totalActions = 0
    local filteredActions = 0
    
    for _, category in ipairs(allCategories) do
        local filteredCategory = {
            name = category.name
        }

        local categoryMatchesName = false
        if self.nameFilter ~= "" then
            local resolvedName = g_i18n:convertText(category.name, self.customEnvironment) or category.name
            categoryMatchesName = resolvedName:lower():find(self.nameFilter:lower(), 1, true) ~= nil
        end

        for _, actionBinding in ipairs(category) do
            totalActions = totalActions + 1

            local passes
            if categoryMatchesName then
                -- Whole section matches: include every item, but still honour any input filter
                passes = self.inputFilter == nil or self:actionUsesInput(actionBinding, self.inputFilter)
            else
                passes = self:matchesFilters(actionBinding)
            end

            if passes then
                table.insert(filteredCategory, actionBinding)
                filteredActions = filteredActions + 1
            end
        end

        -- Only include category if it has actions
        if #filteredCategory > 0 then
            table.insert(filteredCategories, filteredCategory)
        end
    end
    
    return filteredCategories, true, filteredActions, totalActions
end

-- Check if action matches current filters
function ImprovedControlsController:matchesFilters(actionBinding)
    -- Name filter
    if self.nameFilter ~= "" then
        local displayName = actionBinding.displayName or ""
        if displayName:lower():find(self.nameFilter:lower(), 1, true) == nil then
            return false
        end
    end
    
    -- Input filter - check if this action uses the filtered input
    if self.inputFilter ~= nil then
        if not self:actionUsesInput(actionBinding, self.inputFilter) then
            return false
        end
    end
    
    return true
end

-- Input capture reports physical axes without a direction suffix. Search both
-- directions of that axis, while keeping button/key names and devices exact.
local function normalizeAxisName(axisName)
    if axisName:match("^AXIS_") then
        return (axisName:gsub("[+-]$", ""))
    end
    return axisName
end

-- Check if a display action binding uses a specific input
function ImprovedControlsController:actionUsesInput(displayAction, inputFilter)
    for _, binding in pairs(displayAction.columnBindings) do
        if binding.deviceId == inputFilter.deviceId then
            -- All filter axes must be present in the binding
            local allMatch = true
            for _, filterAxis in ipairs(inputFilter.axisNames) do
                local found = false
                for _, bindingAxis in ipairs(binding.axisNames) do
                    if normalizeAxisName(bindingAxis) == normalizeAxisName(filterAxis) then
                        found = true
                        break
                    end
                end
                if not found then
                    allMatch = false
                    break
                end
            end
            if allMatch then
                return true
            end
        end
    end

    return false
end

-- Build map of inputs that have multiple bindings
function ImprovedControlsController:buildDuplicateBindingsMap()
    self.duplicateBindings = {}
    
    -- Map: deviceId_input -> list of action names
    local inputToActions = {}
    
    for _, actionBinding in ipairs(self.actionBindings) do
        for _, binding in ipairs(actionBinding.bindings) do
            for _, axisName in ipairs(binding.axisNames) do
                local key = binding.deviceId .. "_" .. axisName
                
                if inputToActions[key] == nil then
                    inputToActions[key] = {}
                end
                
                table.insert(inputToActions[key], actionBinding.action.name)
            end
        end
    end
    
    -- Store which bindings are duplicated
    for key, actions in pairs(inputToActions) do
        if #actions > 1 then
            -- This input is bound to multiple actions
            for _, actionName in ipairs(actions) do
                self.duplicateBindings[actionName] = self.duplicateBindings[actionName] or {}
                table.insert(self.duplicateBindings[actionName], key)
            end
        end
    end
end

-- Check if an action has duplicate bindings
function ImprovedControlsController:hasConflicts(actionName)
    return self.duplicateBindings[actionName] ~= nil and #self.duplicateBindings[actionName] > 0
end

-- Get conflict info for an action
function ImprovedControlsController:getConflictInfo(actionName)
    return self.duplicateBindings[actionName]
end

-- Set name filter
function ImprovedControlsController:setNameFilter(searchText)
    self.nameFilter = searchText or ""
end

-- Set input filter from a captured binding
function ImprovedControlsController:setInputFilter(deviceId, axisNames)
    if deviceId ~= nil and axisNames ~= nil and #axisNames > 0 then
        self.inputFilter = {
            deviceId = deviceId,
            axisNames = axisNames
        }
    else
        self.inputFilter = nil
    end
end

-- Get display text for current input filter
function ImprovedControlsController:getInputFilterDisplayText()
    if self.inputFilter == nil then
        return ""
    end
    
    -- Create a temporary binding to use display text function
    local tempBinding = {
        deviceId = self.inputFilter.deviceId,
        axisNames = self.inputFilter.axisNames,
        internalDeviceId = -1,
        index = 1,
        axisComponent = 1
    }
    
    return self:getBindingInputDisplayText(tempBinding)
end

-- Clear all filters
function ImprovedControlsController:clearFilters()
    self.nameFilter = ""
    self.inputFilter = nil
end

-- Check if any filters are active
function ImprovedControlsController:hasActiveFilters()
    return self.nameFilter ~= "" or self.inputFilter ~= nil
end
