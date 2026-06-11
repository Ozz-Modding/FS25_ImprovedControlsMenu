ImprovedControlsMenu = {}
ImprovedControlsMenu.dir = g_currentModDirectory

-- Source required files
source(ImprovedControlsMenu.dir .. "src/ImprovedControlsController.lua")
source(ImprovedControlsMenu.dir .. "src/gui/ImprovedControlsFrame.lua")

function ImprovedControlsMenu:loadMap()
    print("ImprovedControlsMenu: Loading mod")
    
    -- Create and initialize the controls frame
    local controlsFrame = ImprovedControlsFrame.new()
    g_gui:loadGui(ImprovedControlsMenu.dir .. "src/gui/ImprovedControlsFrame.xml", "ImprovedControlsFrame", controlsFrame, true)
    
    -- Initialize with our custom controller
    local controller = ImprovedControlsController.new()
    controlsFrame:initialize(controller)
    
    -- Add to ingame menu
    self:addIngameMenuPage(controlsFrame)
    
    print("ImprovedControlsMenu: Loaded successfully")
end

function ImprovedControlsMenu:deleteMap()
    print("ImprovedControlsMenu: Unloading mod")
end

-- Add menu page to ingame menu (based on RedTape pattern)
function ImprovedControlsMenu:addIngameMenuPage(frame)
    local pageName = "improvedControlsMenu"
    local iconUVs = {0, 0, 128, 128}
    local insertAfter = "pageSettings" -- Insert after settings page
    
    -- Remove if already exists
    g_inGameMenu.controlIDs[pageName] = nil
    
    -- Find insertion position
    local targetPosition = 0
    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[insertAfter] then
            targetPosition = i + 1
            break
        end
    end
    
    -- Add to ingame menu
    g_inGameMenu[pageName] = frame
    g_inGameMenu.pagingElement:addElement(g_inGameMenu[pageName])
    g_inGameMenu:exposeControlsAsFields(pageName)
    
    -- Reorder in elements array
    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.elements, i)
            table.insert(g_inGameMenu.pagingElement.elements, targetPosition, child)
            break
        end
    end
    
    -- Reorder in pages array
    for i = 1, #g_inGameMenu.pagingElement.pages do
        local child = g_inGameMenu.pagingElement.pages[i]
        if child.element == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.pages, i)
            table.insert(g_inGameMenu.pagingElement.pages, targetPosition, child)
            break
        end
    end
    
    -- Update layout
    g_inGameMenu.pagingElement:updateAbsolutePosition()
    g_inGameMenu.pagingElement:updatePageMapping()
    
    -- Register page (always visible predicate)
    g_inGameMenu:registerPage(g_inGameMenu[pageName], nil, function() return true end)
    
    -- Add tab icon
    local iconFileName = Utils.getFilename('images/menuIcon.dds', ImprovedControlsMenu.dir)
    g_inGameMenu:addPageTab(g_inGameMenu[pageName], iconFileName, GuiUtils.getUVs(iconUVs, {128, 128}))
    
    -- Reorder in page frames
    for i = 1, #g_inGameMenu.pageFrames do
        local child = g_inGameMenu.pageFrames[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pageFrames, i)
            table.insert(g_inGameMenu.pageFrames, targetPosition, child)
            break
        end
    end
    
    -- Rebuild tab list
    g_inGameMenu:rebuildTabList()
end

-- Register mod events
addModEventListener(ImprovedControlsMenu)
