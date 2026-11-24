---------------------
---- MY PROGRAMS ----
---------------------
           
local terminal    = "kitty"
local fileManager = "kitty --class yazi -e yazi"
local menu = "hyprlauncher"
local browser = "zen-browser"


local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- My keybinds (MAIN)
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("command -v " .. browser .. " >/dev/null && exec " .. browser .. "; exec firefox"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", layout_aware = false }))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("~/.config/quickshell/reload.sh"))
hl.bind(mainMod .. " + Space", hl.dsp.global("quickshell:toggleNotchLauncher"))
hl.bind(mainMod .. " + T", hl.dsp.global("quickshell:toggleThemeNotch"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.global("quickshell:toggleTaskManagerNotch"))
hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:toggleWallpaperNotch"))
hl.bind(mainMod .. " + ALT + W", hl.dsp.global("quickshell:toggleWallpaperEngineNotch"))
hl.bind(mainMod .. " + CTRL + W", hl.dsp.global("quickshell:toggleWallpaperEngineNotch"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:toggleTransitionNotch"))
hl.bind(mainMod .. " + ALT + L", hl.dsp.global("quickshell:toggleLockscreenNotch"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.global("quickshell:toggleLockscreenNotch"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.global("quickshell:toggleMusicInfoNotch"))
hl.bind(mainMod .. " + grave", hl.dsp.global("quickshell:resetNotchToIdle"))
hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:toggleNotificationsNotch"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.global("quickshell:toggleNotesNotch"))
hl.bind(mainMod .. " + slash", hl.dsp.global("quickshell:toggleCheatsheetNotch"))
hl.bind(mainMod .. " + U", hl.dsp.global("quickshell:toggleUtilityNotch"))
hl.bind("ALT + TAB", hl.dsp.global("quickshell:cycleWindowNext"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.global("quickshell:cycleWindowPrev"))
hl.bind("ALT + Escape", hl.dsp.global("quickshell:resetNotchToIdle"))
hl.bind("ALT + Alt_L", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("ALT + Alt_R", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("ALT + SHIFT + Alt_L", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("ALT + SHIFT + Alt_R", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("SHIFT + Alt_L", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("SHIFT + Alt_R", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("Alt_L", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("Alt_R", hl.dsp.global("quickshell:confirmAltRelease"), { release = true, dont_inhibit = true })
hl.bind("Print", hl.dsp.exec_cmd(os.getenv("HOME") .. '/.config/hypr/scripts/screenshot.sh area'))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(os.getenv("HOME") .. '/.config/hypr/scripts/screenshot.sh screen'))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/lock-screen.sh"))

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
-- hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:toggleClipboardNotch"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.global("quickshell:togglePowerMenuNotch"))
local scrolling = require("modules.scrolling_keys")

-- Arrow keys focus windows, Shift moves them. Ctrl+Up/Down changes workspace.
local directions = {
    { "Left", "l", "H" },
    { "Down", "d", "J" },
    { "Up", "u", "K" },
    { "Right", "r" },
}
for _, direction in ipairs(directions) do
    local arrow, compass, vi = table.unpack(direction)
    hl.bind(mainMod .. " + " .. arrow, hl.dsp.focus({ direction = compass }))
    hl.bind(mainMod .. " + SHIFT + " .. arrow, hl.dsp.window.move({ direction = compass }))
    -- Super+Shift+L is the Dynamic You lockscreen shortcut.
    if vi then
        hl.bind(mainMod .. " + SHIFT + " .. vi, hl.dsp.window.move({ direction = compass }))
    end
end
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.focus({ direction = "r" }))

-- Number keys select a slot in the current group. Ctrl selects a group at the same slot.
for n = 1, 10 do
    local key = n % 10
    hl.bind(mainMod .. " + " .. key, scrolling.workspace("focus", false, n))
    hl.bind(mainMod .. " + ALT + " .. key, scrolling.workspace("move", false, n))
    hl.bind(mainMod .. " + SHIFT + " .. key, scrolling.workspace("silent", false, n))
    hl.bind(mainMod .. " + CTRL + " .. key, scrolling.workspace("focus", true, n))
    hl.bind(mainMod .. " + CTRL + ALT + " .. key, scrolling.workspace("move", true, n))
end

local workspaceSteps = {
    { "-1", "-10", "Up", "Page_Up", "mouse_up", "bracketleft", "e-1" },
    { "+1", "+10", "Down", "Page_Down", "mouse_down", "bracketright", "e+1" },
}
for _, step in ipairs(workspaceSteps) do
    local nextWorkspace, nextGroup, arrow, page, wheel, bracket, existing = table.unpack(step)
    local focus = hl.dsp.focus({ workspace = nextWorkspace })
    local move = hl.dsp.window.move({ workspace = nextWorkspace })
    hl.bind(mainMod .. " + CTRL + " .. arrow, focus)
    hl.bind(mainMod .. " + " .. page, focus)
    hl.bind(mainMod .. " + " .. wheel, focus)
    hl.bind(mainMod .. " + CTRL + SHIFT + " .. arrow, move)
    hl.bind(mainMod .. " + ALT + " .. page, move)
    hl.bind(mainMod .. " + ALT + " .. wheel, move)
    hl.bind(mainMod .. " + CTRL + " .. wheel, hl.dsp.focus({ workspace = nextGroup }))
    hl.bind(mainMod .. " + ALT + " .. bracket, hl.dsp.focus({ workspace = existing }))
end
-- Super+grave remains the notch reset.
hl.bind(mainMod .. " + ALT + grave", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + CTRL + O", hl.dsp.exec_cmd("qs ipc call workspaces toggle"))

-- Keep the Dynamic You launcher on Super+R and use its split shortcut on Super+J.
hl.bind(mainMod .. " + J", scrolling.split())
hl.bind(mainMod .. " + D", hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + bracketleft", scrolling.preselect("l"))
hl.bind(mainMod .. " + bracketright", scrolling.preselect("r"))
hl.bind(mainMod .. " + CTRL + Backslash", scrolling.center())
hl.bind(mainMod .. " + CTRL + ALT + Backslash", scrolling.size(55, 70))
hl.bind(mainMod .. " + CTRL + F", scrolling.size(100, 100))

local resizeSteps = {
    { "Equal", "ALT + Right", 10, 0 },
    { "Minus", "ALT + Left", -10, 0 },
    { "SHIFT + Equal", "ALT + Down", 0, 10 },
    { "SHIFT + Minus", "ALT + Up", 0, -10 },
}
for _, step in ipairs(resizeSteps) do
    local key, alternative, x, y = table.unpack(step)
    local resize = scrolling.resize(x, y)
    hl.bind(mainMod .. " + " .. key, resize, { repeating = true })
    hl.bind(mainMod .. " + " .. alternative, resize, { repeating = true })
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + SHIFT + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh volume_up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh volume_down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh volume_mute"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh brightness_up"),  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh brightness_down"),{ locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh kbd_up"),          { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd-control.sh kbd_down"),        { locked = true, repeating = true })


-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


-- 2. Screenshot Annotation Hub (Area crop + Dynamic Island action hub)
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/screenshot.sh hub"))

-- 3. Active Window
hl.bind(mainMod .. " + CTRL + Print", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/screenshot.sh active"))

hl.bind("SUPER + M", hl.dsp.workspace.toggle_special("music"))
hl.bind("SUPER + X", hl.dsp.workspace.toggle_special("comms"))
hl.bind("SUPER + CTRL + X", hl.dsp.workspace.toggle_special("extra"))
hl.bind("SUPER + O", hl.dsp.workspace.toggle_special("todo"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.workspace.toggle_special("sysmon"))
hl.bind("SUPER + CTRL + SHIFT + M", hl.dsp.window.move({ workspace = "special:music" }))
hl.bind("SUPER + CTRL + SHIFT + D", hl.dsp.window.move({ workspace = "special:comms" }))
hl.bind("SUPER + CTRL + SHIFT + T", hl.dsp.window.move({ workspace = "special:todo" }))
hl.bind("SUPER + CTRL + SHIFT + Escape", hl.dsp.window.move({ workspace = "special:sysmon" }))
