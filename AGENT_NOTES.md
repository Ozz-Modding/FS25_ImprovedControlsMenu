# FS25 Improved Controls Menu - Development Notes

## Project Overview
A Farming Simulator 25 mod that adds an enhanced controls menu to the in-game menu system. This mod addresses three main user issues with the base game's controls menu:

1. **Menu navigation controls are hidden** - Controls like MENU_AXIS_UP_DOWN are not displayed
2. **Hard to find controls** - With 100+ controls, users need search/filter functionality
3. **Hard to identify conflicts** - Multiple actions bound to same key are difficult to spot

## Implementation Status

### ✅ Completed Components

#### 1. ImprovedControlsController (`src/ImprovedControlsController.lua`)
- **Pattern**: Composition wrapper around base game's `ControlsController`
- **Why**: Cannot extend ControlsController due to protected metatable
- **Features**:
  - Delegates all standard operations to base controller
  - **Removes LOCKED_BINDINGS restriction** - allows editing all controls including menu navigation
  - Name filtering: `setNameFilter(searchText)` - case-insensitive partial match
  - Input filtering: `setInputFilter(deviceId, axisNames)` - show controls using specific key/button
  - Duplicate detection: `buildDuplicateBindingsMap()` - identifies conflicts
  - Filter state management and display text generation

#### 2. ImprovedControlsFrame (`src/gui/ImprovedControlsFrame.lua`)
- **Extends**: `TabbedMenuFrameElement` (base game menu frame class)
- **UI Callbacks**:
  - `onSearchTextChanged()` - Live search filtering
  - `onFilterByInput()` - Capture key press and filter by it
  - `onClearFilters()` - Reset all filters
  - `onInputClicked()` - Rebind control (full editing support)
- **Features**:
  - Device column management (KB1, KB2, Mouse, Gamepads)
  - Section-based list with category headers
  - Focus management for keyboard/gamepad navigation
  - Save/Reset to defaults functionality
  - Conflict warning icons

#### 3. UI Layout (`src/gui/ImprovedControlsFrame.xml`)
- **Structure**:
  - Header with icon and title
  - Filter panel (search box, filter buttons, status text)
  - Device column headers
  - Scrollable controls list with conflict indicators
  - Prev/Next buttons for gamepad columns
- **Profiles**: Custom GUI profiles for all elements
- **Base Game Compatibility**: Uses valid base game profiles and image slices

#### 4. Main Entry Point (`src/main.lua`)
- Loads controller and frame classes
- Initializes GUI from XML
- Injects menu page using RedTape pattern
- Inserts after Settings page in menu
- Handles mod lifecycle (loadMap/deleteMap)

#### 5. Localization (`languages/l10n_en.xml`)
- Menu title and labels
- Filter status messages
- Dialog prompts
- Tooltips and warnings

## Technical Issues Resolved

### Issue 1: Protected Metatable Error
```
Error: cannot change a protected metatable
```
**Root Cause**: Attempted to use `Class()` to extend `ControlsController`  
**Solution**: Changed to composition pattern - wrap base controller, delegate method calls

### Issue 2: Missing GUI Profiles
```
Warning: Could not retrieve GUI profile 'fs25_textInputSmall'
Warning: Could not retrieve GUI profile 'fs25_buttonMedium'
```
**Root Cause**: These profiles don't exist in base game  
**Solution**: 
- Created custom `icm_searchInput` profile extending `baseReference`
- Replaced button profiles with `buttonText` (valid base game profile)

### Issue 3: Invalid Image Slice IDs
```
Warning: No slice with ID 'icon_ingameMenu_settings' found
Warning: No slice with ID 'icon_warning' found
Warning: No slice with ID 'button_default' found
```
**Solution**:
- `icon_ingameMenu_settings` → `icon_ingameMenu_generalSettings`
- `icon_warning` → `icon_ingameMenu_alert`
- `button_default` → `gui.empty`

### Issue 4: Undefined Color Presets
```
Warning: Preset 'fs25_colorOrange' is not defined
```
**Solution**: Replaced `$preset_fs25_colorOrange` with RGB values `1 0.6 0 1`

### Issue 5: InputGlyphElement Not Available
```
Warning: Could not find type name InputGlyphElement
```
**Root Cause**: InputGlyphElement may be internal-only or require special initialization  
**Solution**: Replaced with simple Text elements - displays binding text (e.g., "W", "Mouse Button 1") instead of fancy glyphs

### Issue 6: TextInput Alignment Error
```
Error: TextInputElement using "center" alignment requires specification of "maxInputTextWidth"
```
**Solution**: Added `maxInputTextWidth="340px"` to search input profile

## Current Implementation Details

### Filter System
1. **Name Filter**: 
   - Text input box with `onTextChanged` callback
   - Filters action display names (case-insensitive, partial match)
   - Real-time filtering as user types

2. **Input Filter**:
   - "Filter by Input" button opens input capture dialog
   - Uses `g_inputBinding:startInputCapture()` to capture key/button press
   - Finds all actions bound to that input
   - Displays filter: "Input filter: Q" or "Input filter: Mouse Button 1"

3. **Duplicate Detection**:
   - Builds reverse map: `{deviceId_input → [action names]}`
   - Any input bound to 2+ actions is marked as conflict
   - Conflict icon shown next to affected bindings

### Controller Delegation Pattern
```lua
ImprovedControlsController = {
    baseController = ControlsController.new(),
    nameFilter = "",
    inputFilter = nil,
    duplicateBindings = {}
}

-- All base operations delegate
function ImprovedControlsController:saveChanges()
    self.baseController:saveChanges()
end

-- Custom filter operations
function ImprovedControlsController:setNameFilter(searchText)
    self.nameFilter = searchText or ""
end
```

### Menu Injection
Uses RedTape's `addIngameMenuPage` pattern:
1. Create frame and load GUI XML
2. Add to `g_inGameMenu.pagingElement`
3. Register page with predicate
4. Add icon tab
5. Reorder in all arrays (elements, pages, pageFrames)
6. Rebuild tab list

## Known Limitations

1. **No Input Glyphs**: Displays text like "W" instead of keyboard key icons (base game issue)
2. **No Icon Customization**: Uses generic settings icon (could create custom DDS)
3. **Performance**: With 100+ controls, filtering is synchronous (may lag on slow systems)
4. **User Risk**: Can break menu navigation by editing locked controls (by design per user request)

## File Structure
```
FS25_ImprovedControlsMenu/
├── modDesc.xml                          # Mod descriptor
├── icon_ImprovedControlsMenu.dds        # Menu tab icon
├── languages/
│   └── l10n_en.xml                      # English localization
├── src/
│   ├── main.lua                         # Mod entry point
│   ├── ImprovedControlsController.lua   # Filter & controller logic
│   └── gui/
│       ├── ImprovedControlsFrame.lua    # GUI frame class
│       └── ImprovedControlsFrame.xml    # UI layout & profiles
├── package.bat                          # Build ZIP
├── moveDebug.bat                        # Deploy to game (debug mode)
└── moveZip.bat                          # Deploy to game (release)
```

## Testing Checklist

### Basic Functionality
- [ ] Mod loads without errors
- [ ] Menu tab appears in ESC menu
- [ ] Menu opens and displays controls list
- [ ] All controls visible (including MENU_AXIS_UP_DOWN, etc.)
- [ ] Device columns show correct headers (KB1, KB2, Mouse, Gamepad)

### Search Filter
- [ ] Search box accepts text input
- [ ] Typing filters list in real-time
- [ ] Case-insensitive matching works
- [ ] Filter status shows "Showing X of Y controls"
- [ ] Clearing search box shows all controls

### Input Filter
- [ ] "Filter by Input" button works
- [ ] Dialog appears: "Press any key or button..."
- [ ] Pressing key filters to actions using that key
- [ ] ESC cancels input capture
- [ ] Filter status shows "Input filter: [key name]"
- [ ] Works for keyboard, mouse, and gamepad inputs

### Clear Filters
- [ ] "Clear Filters" button resets both filters
- [ ] Status text updates to "Showing all X controls"
- [ ] Search box clears

### Conflict Detection
- [ ] Warning icon appears on controls with duplicate bindings
- [ ] Icon visible for all affected controls
- [ ] No false positives (clean bindings have no icon)

### Control Editing
- [ ] Clicking control binding opens rebind dialog
- [ ] Can rebind locked controls (MENU_AXIS_UP_DOWN, etc.)
- [ ] ESC cancels rebind
- [ ] DELETE clears binding
- [ ] Changes mark menu as "unsaved"
- [ ] Save button appears when changes made

### Save/Reset
- [ ] Save button saves changes to inputBinding.xml
- [ ] Changes persist after game restart
- [ ] Reset to Defaults button works
- [ ] Confirmation dialog appears for reset
- [ ] Close without saving prompts for save

### Multi-Device
- [ ] Prev/Next buttons cycle through gamepad columns
- [ ] Multiple gamepads display correctly
- [ ] Device names show in headers

### Edge Cases
- [ ] Works with no gamepads connected
- [ ] Works with 3+ gamepads
- [ ] Empty search (no matches) displays appropriately
- [ ] Very long action names don't break layout
- [ ] Rapid typing in search doesn't cause issues

## Next Steps for Development

### Priority 1: Testing
1. Build and deploy: `.\package.bat && .\moveDebug.bat`
2. Launch FS25 and open ESC menu
3. Navigate to "Improved Controls" tab
4. Test all features from checklist above
5. Check log for errors: `C:\Users\steve\Documents\My Games\FarmingSimulator2025\log.txt`

### Priority 2: Bug Fixes
Based on testing, likely issues:
- Filter status text may not update correctly
- Focus management may need tweaking
- Column width adjustments for long binding names
- Button styling may need improvement

### Priority 3: Enhancements
- Add tooltip on conflict icon showing which actions conflict
- Add keyboard shortcut for search box (auto-focus)
- Add "Show only conflicts" filter toggle
- Add export bindings to file
- Add compare with defaults view
- Add visual indication of changed bindings

### Priority 4: Polish
- Custom icon for menu tab (current: reused settings icon)
- Better conflict icon (current: alert icon)
- Sound effects for filter actions
- Animations for list filtering
- Localization for other languages (DE, FR, etc.)

## Debug Commands

### Game Log Location
```
C:\Users\steve\Documents\My Games\FarmingSimulator2025\log.txt
```

### Input Binding File
```
C:\Users\steve\Documents\My Games\FarmingSimulator2025\inputBinding.xml
```

### Build Commands
```powershell
.\package.bat      # Create ZIP
.\moveDebug.bat    # Deploy as folder (easier debugging)
.\moveZip.bat      # Deploy as ZIP (release mode)
```

### In-Game Console
Enable dev console in game settings, then:
- F1: Toggle console
- Lua errors will appear in red

## Key References

### Base Game Files
- `FS25_Lua/gui/ControlsController.lua` - Original controls controller
- `FS25_Lua/gui/SettingsControlsFrame.lua` - Base controls menu
- `FS25_Lua/gui/InGameMenu.lua` - Menu system
- `FS25_Lua/input/InputBinding.lua` - Input binding system

### Modding Examples
- `FS25_RedTape/src/RedTape.lua` - Menu injection pattern (line 264: `addIngameMenuPage`)
- `FS25_RedTape/src/gui/MenuRedTape.lua` - Custom frame example

## Important Notes

1. **Cannot extend ControlsController**: Use composition/wrapper pattern only
2. **Limited GUI profiles available**: Test profiles exist before using
3. **Image slices must exist**: Check base game GUI for valid slice IDs
4. **InputGlyphElement unavailable**: Use Text elements for binding display
5. **User requested unlock**: All controls editable including menu navigation
6. **Filter performance**: May need optimization for large control lists

## Version History

### v1.0.0 (Current)
- Initial implementation
- Three filter types: name, input, clear
- Conflict detection
- Full control editing (no locks)
- Menu injection working
- XML errors resolved
- Controller wrapper pattern implemented

---

**Last Updated**: June 1, 2026  
**Status**: Ready for initial testing  
**Next Session Goal**: Test in-game, identify and fix runtime issues
