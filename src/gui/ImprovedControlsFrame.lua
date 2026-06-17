ImprovedControlsFrame = {}
local ImprovedControlsFrame_mt = Class(ImprovedControlsFrame, TabbedMenuFrameElement)
local NO_CALLBACK = function() end

function ImprovedControlsFrame.new(target, custom_mt)
    local self = TabbedMenuFrameElement.new(target, custom_mt or ImprovedControlsFrame_mt)

    self.controlsController = nil
    self.controlsData = {}
    self.controlsMessageText = ""
    self.userChangedInput = false
    self.currentFocusCell = nil
    self.dataRowOffset = 0
    self.hasCustomMenuButtons = true
    self.backButtonInfo = {}
    self.saveButtonInfo = {}
    self.resetButtonInfo = {}
    self.searchButtonInfo = {}
    self.filterByInputButtonInfo = {}
    self.clearFiltersButtonInfo = {}
    self.nextPageButtonInfo = {}
    self.prevPageButtonInfo = {}
    self.isCapturingInputFilter = false
    self.numTotalDevices = 3
    self.gamepads = {}

    return self
end

function ImprovedControlsFrame:initialize(controlsController)
    self.controlsController = controlsController
    self.controlsController.customEnvironment = self.customEnvironment

    self.controlsController:setMessageCallback(function(messageId, additionalText, addLine)
        self:setControlsMessage(messageId, additionalText, addLine)
    end)

    self.controlsController:setInputDoneCallback(function(madeChange)
        self:notifyInputGatheringFinished(madeChange)
    end)

    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }



    self.saveButtonInfo = {
        inputAction = InputAction.MENU_ACTIVATE,
        text = g_i18n:getText("button_saveControls"),
        callback = function() self:saveChanges() end,
        showWhenPaused = true
    }


    self.searchButtonInfo = {
        inputAction = InputAction.MENU_ACCEPT,
        text = g_i18n:getText("icm_searchByName"),
        callback = function() self:onSearchByName() end,
        showWhenPaused = true
    }

    self.filterByKeyButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_2,
        text = g_i18n:getText("icm_filterByKey"),
        callback = function() self:onFilterByKey() end,
        showWhenPaused = true
    }

    self.filterByGamepadButtonInfo = {
        inputAction = InputAction.MENU_EXTRA_1,
        text = g_i18n:getText("icm_filterByGamepad"),
        callback = function() self:onFilterByGamepad() end,
        showWhenPaused = true
    }

    self.clearFiltersButtonInfo = {
        inputAction = InputAction.MENU_CANCEL,
        text = g_i18n:getText("icm_clearFilters"),
        callback = function() self:onClearFilters() end,
        showWhenPaused = true
    }

    -- Prevent focus issues when cells are reused (same as base game)
    function self.controlsList.queueReusableCell(list, cell, _)
        local isFocused = false
        for i = 1, 3 do
            local button = cell:getAttribute("actionButton" .. i)
            if button ~= nil and button:getIsFocused() then
                isFocused = true
                break
            end
        end

        if not isFocused and list.sections[cell.sectionIndex] ~= nil then
            list.sections[cell.sectionIndex].cells[cell.indexInSection] = nil
        end

        if not isFocused then
            cell.sectionIndex = nil
            cell.indexInSection = nil
            local cache = list.cellCache[cell.reusableName]
            cache[#cache + 1] = cell
            FocusManager:removeElement(cell)
            cell:unlinkElement()
        end
    end
end

function ImprovedControlsFrame:onFrameOpen()
    ImprovedControlsFrame:superClass().onFrameOpen(self)

    self.numTotalDevices = 3 + g_inputBinding.numActiveGamepads
    self.dataRowOffset = 0
    self:assignDeviceTableData()
    self.controlsList:makeCellVisible(1, 1)
    self.nextFocusSection = 1
    self.nextFocusCell = 1
    self.nextFocusedButtonName = "actionButton1"
    self.controlsMessageText = ""
    self:updateMenuButtons()
    self:updateFilterDisplay()

    g_messageCenter:subscribe(MessageType.INPUT_DEVICES_CHANGED, self.onControllerChanged, self)

    local _, eventId = g_inputBinding:registerActionEvent(InputAction.MENU_ACCEPT, self, self.onMenuAcceptUp, true, false, false, true)
    self.menuAcceptUpEventId = eventId

    g_inputBinding:resetBindingInputStates()
end

function ImprovedControlsFrame:onFrameClose()
    g_messageCenter:unsubscribe(MessageType.INPUT_DEVICES_CHANGED, self)
    g_inputBinding:removeActionEvent(self.menuAcceptUpEventId)
    ImprovedControlsFrame:superClass().onFrameClose(self)
end

function ImprovedControlsFrame:update(dt)
    ImprovedControlsFrame:superClass().update(self, dt)

    if self.nextFocusSection ~= nil then
        local cell = self.controlsList:getElementAtSectionIndex(self.nextFocusSection, self.nextFocusCell)
        if cell ~= nil then
            local button = cell:getAttribute(self.nextFocusedButtonName)
            FocusManager:setFocus(button)
            self.nextFocusSection = nil
            self.nextFocusCell = nil
        end
    end
end

function ImprovedControlsFrame:assignDeviceTableData()
    self.controlsController:loadBindings()
    self.controlsData = self.controlsController:getFilteredDeviceCategoryActionBindings()
    self.controlsList:reloadData()
    self:updateListHeaderNames()
    self:updateFilterDisplay()
end

function ImprovedControlsFrame:updateListHeaderNames()
    local gamepads = g_inputBinding:getGamepadDevices()
    self.gamepads = gamepads

    for i = 1, 3 do
        local deviceIndex = i + self.dataRowOffset
        local headerName = ""

        if deviceIndex <= 3 then
            local deviceInfo = SettingsControlsFrame.DEVICES[deviceIndex]
            if deviceInfo then
                headerName = g_i18n:getText(deviceInfo.name)
            end
        else
            local gamepad = gamepads[deviceIndex - 3]
            if gamepad then
                headerName = gamepad.name
                if g_i18n:hasText(headerName) then
                    headerName = g_i18n:getText(headerName)
                elseif InputDevice.NAMES[headerName] ~= nil then
                    headerName = InputDevice.NAMES[headerName]
                end
            end
        end

        local headerText = self["headerText" .. i]
        if headerText then
            headerText:setText(headerName)
        end
    end

    if self.buttonPrevRow then
        self.buttonPrevRow:setVisible(self.dataRowOffset > 0)
    end
    if self.buttonNextRow then
        self.buttonNextRow:setVisible(self.dataRowOffset < self.numTotalDevices - 3)
    end
end

function ImprovedControlsFrame:updateFilterDisplay()
    if not self.filterStatusText then
        return
    end

    local statusText = ""

    if self.controlsController:hasActiveFilters() then
        local _, _, showing, total = self.controlsController:getFilteredDeviceCategoryActionBindings()
        statusText = string.format(g_i18n:getText("icm_showingFiltered"), showing, total)

        if self.controlsController.nameFilter ~= "" then
            statusText = statusText .. "  |  " .. string.format(g_i18n:getText("icm_nameFilter"), self.controlsController.nameFilter)
        end

        if self.controlsController.inputFilter ~= nil then
            local inputText = self.controlsController:getInputFilterDisplayText()
            statusText = statusText .. "  |  " .. string.format(g_i18n:getText("icm_inputFilter"), inputText)
        end
    else
        local total = 0
        for _, category in ipairs(self.controlsData) do
            total = total + #category
        end
        statusText = string.format(g_i18n:getText("icm_showingAll"), total)
    end

    self.filterStatusText:setText(statusText)
end

function ImprovedControlsFrame:updateMenuButtons()
    self.menuButtonInfo = {
        self.backButtonInfo,
        self.searchButtonInfo,
        self.filterByKeyButtonInfo,
        self.filterByGamepadButtonInfo,
        self.clearFiltersButtonInfo
    }

    if self.userChangedInput then
        table.insert(self.menuButtonInfo, self.saveButtonInfo)
    end

    self:setMenuButtonInfoDirty()
end

-- Search by name using TextInputDialog
function ImprovedControlsFrame:onSearchByName()
    TextInputDialog.show(
        function(text, confirmed)
            if confirmed then
                self.controlsController:setNameFilter(text)
                self:assignDeviceTableData()
                self:updateMenuButtons()
            end
        end,
        nil,
        self.controlsController.nameFilter,
        g_i18n:getText("icm_searchPrompt"),
        nil,
        50,
        g_i18n:getText("button_confirm")
    )
end

-- Filter by input capture
-- Filter by keyboard key
function ImprovedControlsFrame:onFilterByKey()
    if self.isCapturingInputFilter then
        return
    end

    self.isCapturingInputFilter = true

    -- Build set of keys bound to MENU_EXTRA_2 so we can ignore them
    self.inputFilterIgnoreKeys = {}
    local action = g_inputBinding:getActionByName("MENU_EXTRA_2")
    if action then
        for _, binding in ipairs(action:getBindings()) do
            for _, axisName in ipairs(binding.axisNames) do
                self.inputFilterIgnoreKeys[axisName] = true
            end
        end
    end

    local promptText = g_i18n:getText("icm_pressKeyToFilter")
    MessageDialog.show(promptText, nil, nil, DialogElement.TYPE_KEY)

    local captureState = {
        keyState = {}
    }

    g_inputBinding:startInputCapture(true, false, self, captureState,
        self.onKeyFilterCaptured,
        self.onInputFilterAborted,
        nil)
end

function ImprovedControlsFrame:onKeyFilterCaptured(deviceName, keyName, inputValue, initInputValue, gatheringState)
    -- Ignore the activation key
    if self.inputFilterIgnoreKeys and self.inputFilterIgnoreKeys[keyName] then
        if inputValue == 0 then
            self.inputFilterIgnoreKeys[keyName] = nil
        end
        return
    end

    local keyState = gatheringState.keyState

    if inputValue > 0 then
        -- Key pressed — collect into combo
        table.insert(keyState, keyName)
    else
        -- Key released — apply filter with all collected keys
        if #keyState > 0 then
            g_inputBinding:stopInputGathering()
            self.isCapturingInputFilter = false
            self.inputFilterIgnoreKeys = nil
            g_gui:closeAllDialogs()
            self.controlsController:setInputFilter(deviceName, keyState)
            self:assignDeviceTableData()
            self:updateMenuButtons()
        end
    end
end

-- Filter by gamepad input
function ImprovedControlsFrame:onFilterByGamepad()
    if self.isCapturingInputFilter then
        return
    end

    self.isCapturingInputFilter = true

    local promptText = g_i18n:getText("icm_pressGamepadToFilter")
    MessageDialog.show(promptText, nil, nil, DialogElement.TYPE_KEY)

    local captureState = {
        gamepadState = {}
    }

    g_inputBinding:startInputCapture(false, false, self, captureState,
        self.onGamepadFilterCaptured,
        self.onInputFilterAborted,
        nil)
end

function ImprovedControlsFrame:onGamepadFilterCaptured(deviceId, inputAxisName, inputValue, initInputValue, gatheringState)
    if not self.isCapturingInputFilter then
        return
    end

    local deviceState = gatheringState.gamepadState[deviceId]
    if not deviceState then
        deviceState = {}
        gatheringState.gamepadState[deviceId] = deviceState
    end

    local prev = deviceState[inputAxisName]
    deviceState[inputAxisName] = {inputValue, initInputValue}

    if not prev then
        return
    end

    local prevDelta = prev[1] - initInputValue
    if math.abs(prevDelta) > 0.3 then
        local currDelta = inputValue - initInputValue
        if math.abs(currDelta) <= 0.3 then
            -- Axis/button returned to neutral after being activated
            -- Collect any other axes that were also pushed (combo inputs)
            local axisNames = {}
            for axisName, state in pairs(deviceState) do
                if axisName ~= inputAxisName then
                    local val = state[1]
                    local init = state[2]
                    local initDir = init > 0.5 and 1 or (init < -0.5 and -1 or 0)
                    if math.abs(val) > 0.5 then
                        if initDir == 0 then
                            if val < 0 then
                                table.insert(axisNames, axisName .. "-")
                            else
                                table.insert(axisNames, axisName)
                            end
                        else
                            local adjusted = val - initDir
                            if math.abs(adjusted) > 0.6 or Input.isHalfAxis(Input[axisName]) then
                                if val < 0 then
                                    table.insert(axisNames, axisName .. "-")
                                else
                                    table.insert(axisNames, axisName)
                                end
                            end
                        end
                    end
                end
            end

            table.sort(axisNames)
            table.insert(axisNames, inputAxisName)

            g_inputBinding:stopInputGathering()
            self.isCapturingInputFilter = false
            self.inputFilterIgnoreKeys = nil
            g_gui:closeAllDialogs()
            self.controlsController:setInputFilter(deviceId, axisNames)
            self:assignDeviceTableData()
            self:updateMenuButtons()
        end
    end
end

function ImprovedControlsFrame:onInputFilterCaptured(deviceName, keyName, inputValue, initInputValue, gatheringState)
    -- Ignore the key that activated this capture
    if self.inputFilterIgnoreKeys and self.inputFilterIgnoreKeys[keyName] then
        if inputValue == 0 then
            self.inputFilterIgnoreKeys[keyName] = nil
        end
        return
    end

    -- Only accept on key release
    if inputValue > 0 then
        return
    end

    g_inputBinding:stopInputGathering()
    self.isCapturingInputFilter = false
    self.inputFilterIgnoreKeys = nil
    g_gui:closeAllDialogs()
    self.controlsController:setInputFilter(deviceName, {keyName})
    self:assignDeviceTableData()
    self:updateMenuButtons()
end

function ImprovedControlsFrame:onInputFilterAborted()
    g_inputBinding:stopInputGathering()
    self.isCapturingInputFilter = false
    self.inputFilterIgnoreKeys = nil
    g_gui:closeAllDialogs()
end

function ImprovedControlsFrame:onClearFilters()
    self.controlsController:clearFilters()
    self:assignDeviceTableData()
    self:updateMenuButtons()
end

-- List data source
function ImprovedControlsFrame:getNumberOfSections(list)
    return #self.controlsData
end

function ImprovedControlsFrame:getTitleForSectionHeader(list, section)
    local categoryName = self.controlsData[section].name
    return g_i18n:convertText(categoryName, self.customEnvironment)
end

function ImprovedControlsFrame:getNumberOfItemsInSection(list, section)
    return #self.controlsData[section]
end

function ImprovedControlsFrame:populateCellForItemInSection(list, section, index, cell)
    local actionBinding = self.controlsData[section][index]

    cell:getAttribute("actionName"):setText(actionBinding.displayName)


    -- Populate 3 device columns
    for i = 1, 3 do
        local deviceIndex = i + self.dataRowOffset
        local columnBinding = nil

        if deviceIndex > 3 then
            local gamepad = self.gamepads[deviceIndex - 3]
            if gamepad then
                for bindIdx, binding in pairs(actionBinding.columnBindings) do
                    if binding.deviceId == gamepad.deviceId then
                        columnBinding = binding
                        deviceIndex = bindIdx
                        break
                    end
                end
            end
        else
            columnBinding = actionBinding.columnBindings[deviceIndex]
        end

        local button = cell:getAttribute("actionButton" .. i)
        if button then
            button:setText(actionBinding.columnTexts[deviceIndex] or "")

            local actualDeviceIndex = i + self.dataRowOffset

            local oldFocusEnter = button.onFocusEnter
            function button.onFocusEnter(element)
                if oldFocusEnter then
                    oldFocusEnter(element)
                end
                list:makeCellVisible(cell.sectionIndex, cell.indexInSection)
                self.currentFocusCell = cell
                self.currentFocusSection = cell.sectionIndex
                self.currentFocusIndex = cell.indexInSection
                self["headerText1"]:setSelected(i == 1)
                self["headerText2"]:setSelected(i == 2)
                self["headerText3"]:setSelected(i == 3)
            end

            function button.shouldFocusChange(_, direction)
                if g_gui:getIsDialogVisible() then
                    return false
                end

                local sectionIdx = cell.sectionIndex or self.currentFocusSection
                local itemIdx = cell.indexInSection or self.currentFocusIndex

                if direction == FocusManager.LEFT then
                    if actualDeviceIndex == 1 then
                        return false
                    end
                    if actualDeviceIndex == 1 + self.dataRowOffset then
                        self.dataRowOffset = self.dataRowOffset - 1
                        self.controlsList:reloadData()
                        self:updateListHeaderNames()
                        return false
                    end
                elseif direction == FocusManager.RIGHT then
                    if actualDeviceIndex == self.numTotalDevices then
                        return false
                    end
                    if actualDeviceIndex == 3 + self.dataRowOffset then
                        self.dataRowOffset = self.dataRowOffset + 1
                        self.controlsList:reloadData()
                        self:updateListHeaderNames()
                        return false
                    end
                elseif direction == FocusManager.TOP then
                    local newItemIdx = itemIdx - 1
                    if newItemIdx == 0 then
                        sectionIdx = sectionIdx - 1
                        if sectionIdx == 0 then
                            return false
                        end
                        newItemIdx = list.sections[sectionIdx].numItems
                    end
                    list:makeCellVisible(sectionIdx, newItemIdx)
                    self.nextFocusSection = sectionIdx
                    self.nextFocusCell = newItemIdx
                    self.nextFocusedButtonName = "actionButton" .. i
                    return false
                elseif direction == FocusManager.BOTTOM then
                    local newItemIdx = itemIdx + 1
                    if list.sections[sectionIdx].numItems < newItemIdx then
                        sectionIdx = sectionIdx + 1
                        if #list.sections < sectionIdx then
                            return false
                        end
                        newItemIdx = 1
                    end
                    list:makeCellVisible(sectionIdx, newItemIdx)
                    self.nextFocusSection = sectionIdx
                    self.nextFocusCell = newItemIdx
                    self.nextFocusedButtonName = "actionButton" .. i
                    return false
                end

                return true
            end
        end
    end

    cell.actionBinding = actionBinding
end

function ImprovedControlsFrame:inputEvent(action, value, eventUsed)
    return action == InputAction.MENU_ACCEPT and true or eventUsed
end

function ImprovedControlsFrame:onMenuAcceptUp(action, value, eventUsed)
    if self.currentFocusCell == nil then
        return true
    end

    local rowIndex = 1
    local focusedButton = FocusManager:getFocusedElement()
    if focusedButton.name == "actionButton2" then
        rowIndex = 2
    elseif focusedButton.name == "actionButton3" then
        rowIndex = 3
    end

    local bindingControlsRowIndex = rowIndex + self.dataRowOffset
    local deviceInfoIndex = math.min(bindingControlsRowIndex, 4)

    self:onInputClicked(
        SettingsControlsFrame.DEVICES[deviceInfoIndex].category,
        SettingsControlsFrame.DEVICES[deviceInfoIndex].binding,
        self.currentFocusCell.actionBinding,
        bindingControlsRowIndex
    )

    return true
end

function ImprovedControlsFrame:onInputClicked(deviceCategory, bindingId, actionData, bindingControlsRowIndex)
    self.controlsMessageText = ""
    if self.controlsController:onClickInput(deviceCategory, bindingId, actionData, bindingControlsRowIndex) then
        self:showInputPrompt(deviceCategory, bindingId, actionData)
    end
end

function ImprovedControlsFrame:showInputPrompt(deviceCategory, bindingId, actionData)
    local promptSymbol
    if deviceCategory == InputDevice.CATEGORY.KEYBOARD_MOUSE then
        if bindingId == ControlsController.BINDING_PRIMARY or bindingId == ControlsController.BINDING_SECONDARY then
            promptSymbol = "ui_pressKeyToMap"
        else
            promptSymbol = "ui_pressMouseButtonToMap"
        end
    else
        promptSymbol = "ui_pressGamepadButtonToMap"
    end

    local promptTemplate = g_i18n:getText(promptSymbol)
    local text = string.format(promptTemplate, actionData.displayName) .. "\n" ..
                 g_i18n:getText("ui_pressESCToCancel")

    local ensureInNeutral = g_i18n:getText("ui_ensureAxisToMapInNeutral")
    if utf8Strlen(ensureInNeutral) > 1 then
        text = text .. "\n\n" .. ensureInNeutral
    end

    MessageDialog.show(text, nil, nil, DialogElement.TYPE_KEY)
end

function ImprovedControlsFrame:setControlsMessage(messageId, additionalText, addLine)
    if messageId and messageId ~= ControlsController.MESSAGE_CLEAR then
        local text = (not addLine or self.controlsMessageText == "") and "" or self.controlsMessageText .. "\n"
        local uiSymbol = SettingsControlsFrame.CONTROLS_UI_STRINGS[messageId]
        local isWarning = SettingsControlsFrame.CONFLICT_MESSAGES[messageId] == true
        local dialogType = isWarning and DialogElement.TYPE_WARNING or DialogElement.TYPE_INFO

        if uiSymbol then
            text = text .. g_i18n:getText(uiSymbol)
            if additionalText and #additionalText > 0 then
                text = text .. additionalText[1]
            end
        else
            local formatString = g_i18n:getText(SettingsControlsFrame.L10N_TEMPLATE_SYMBOL[messageId])
            if additionalText and #additionalText > 0 then
                text = text .. string.format(formatString, unpack(additionalText))
            else
                text = text .. formatString
            end
        end

        self.controlsMessageText = text
        InfoDialog.show(text, nil, nil, dialogType)
    else
        self.controlsMessageText = ""
    end
end

function ImprovedControlsFrame:notifyInputGatheringFinished(madeChange)
    self:setSoundSuppressed(true)
    g_gui:closeAllDialogs()
    FocusManager:setGui(self.name)
    self:setSoundSuppressed(false)

    if madeChange then
        self:assignDeviceTableData()
        self.userChangedInput = true
        self:updateMenuButtons()
    end

    self:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
end

function ImprovedControlsFrame:requestClose(callback)
    local canClose = not self.userChangedInput

    if self.userChangedInput then
        ImprovedControlsFrame:superClass().requestClose(self, callback)
        YesNoDialog.show(self.onYesNoSaveControls, self, g_i18n:getText("ui_saveChanges"))
    end

    return canClose
end

function ImprovedControlsFrame:onYesNoSaveControls(yes)
    if yes then
        self:saveChanges()
    else
        self:revertChanges()
        self.requestCloseCallback()
        self.requestCloseCallback = NO_CALLBACK
    end
end

function ImprovedControlsFrame:revertChanges()
    self.controlsController:discardChanges()
    self.userChangedInput = false
    self:updateMenuButtons()
end

function ImprovedControlsFrame:saveChanges()
    if self.userChangedInput then
        self.controlsController:saveChanges()
        self.userChangedInput = false
        self:updateMenuButtons()
        InfoDialog.show(g_i18n:getText("ui_savingFinished"), self.requestCloseCallback)
        self.requestCloseCallback = NO_CALLBACK
    end
end


function ImprovedControlsFrame:onControllerChanged()
    self.dataRowOffset = 0
    self.numTotalDevices = 3 + g_inputBinding.numActiveGamepads
    self.controlsList:makeCellVisible(1, 1, true)
    self.nextFocusSection = 1
    self.nextFocusCell = 1
    self.nextFocusedButtonName = "actionButton1"
    self:assignDeviceTableData()
    self.controlsMessageText = ""
    self:updateMenuButtons()
end

function ImprovedControlsFrame:onClickNextRow()
    self.dataRowOffset = self.dataRowOffset + 1
    self.controlsList:reloadData()
    self:updateListHeaderNames()
end

function ImprovedControlsFrame:onClickPrevRow()
    self.dataRowOffset = self.dataRowOffset - 1
    self.controlsList:reloadData()
    self:updateListHeaderNames()
end
