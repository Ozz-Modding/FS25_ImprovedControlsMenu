# FS25 Improved Controls Menu

## Overview
A Farming Simulator 25 mod that adds an enhanced controls menu with search/filter capabilities and access to hidden locked bindings (menu navigation controls).

## Key Architecture Decisions
- Uses composition pattern to wrap `ControlsController` (cannot extend due to protected metatable)
- Loads ALL actions via `g_inputBinding:getActionBindingsCopy(false)` to include locked bindings
- Calls `self.baseController:createDisplayAction()` to build display data using the full action list
- XML uses base game profiles from `SettingsControlsFrame` (e.g. `fs25_settingsControlsListButton`, `fs25_settingsControlsListHeaderButtonPrev`)

## Reference Locations
- Base game Lua: `C:\Users\steve\Documents\My FS 25 Mods\Reference\FS25_Lua`
- Base game settings XML (includes controls tab): `InGameMenuSettingsFrame.xml` in project root
- The controls section is `subCategoryPages[4]` in that XML

## Input Capture
- Keyboard: `startInputCapture(true, false, ...)` - callback fires with `(deviceName, keyName, inputValue, initInputValue, gatheringState)`
- Gamepad: `startInputCapture(false, false, ...)` - callback fires every frame for all axes/buttons; uses threshold logic (0.3/0.5) to detect real input
- Mouse: `startInputCapture(false, true, ...)` - keyboard abort + mouse input
- Only one capture mode at a time; cannot capture all three simultaneously
- Must call `g_inputBinding:stopInputGathering()` to end capture

## Build & Deploy
```
.\package.bat      # Create ZIP
.\moveDebug.bat    # Deploy as folder
```
Game log: `C:\Users\steve\Documents\My Games\FarmingSimulator2025\log.txt`

## Linter False Positives
FS25 engine globals (`g_inputBinding`, `g_i18n`, `g_gui`, `g_currentMission`, `Class`, `Input`, `InputAction`, `InputDevice`, `InputBinding`, `MessageDialog`, `TextInputDialog`, `FocusManager`, `getNumOfGamepads`, `keyEvent`) are all undefined to the linter but available at runtime.
