local vars = require("variables")
local fn = require("hyprland.functions")

local hypr = os.getenv("HOME") .. "/.config/hypr"
local quickshellScripts = os.getenv("HOME") .. "/.config/quickshell"

--- App launches ---
hl.bind(vars.mainMod .. " + Return", hl.dsp.exec_cmd(vars.terminal))
hl.bind(vars.mainMod .. " + B", hl.dsp.exec_cmd(vars.browser))
hl.bind(vars.mainMod .. " + E", hl.dsp.exec_cmd(vars.fileExplorer))

--- Quickshell & Notch (Current Shell) ---
hl.bind(vars.mainMod .. " + Space", hl.dsp.global("quickshell:toggleNotchLauncher"))
hl.bind(vars.mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(quickshellScripts .. "/reload.sh"))
hl.bind(vars.mainMod .. " + V", hl.dsp.global("quickshell:toggleClipboardNotch"))
hl.bind(vars.mainMod .. " + P", hl.dsp.global("quickshell:togglePowerMenuNotch"))
hl.bind(vars.mainMod .. " + T", hl.dsp.global("quickshell:toggleThemeNotch"))
hl.bind(vars.mainMod .. " + SHIFT + T", hl.dsp.global("quickshell:toggleTaskManagerNotch"))
hl.bind(vars.mainMod .. " + W", hl.dsp.global("quickshell:toggleWallpaperNotch"))
hl.bind(vars.mainMod .. " + ALT + W", hl.dsp.global("quickshell:toggleWallpaperEngineNotch"))
hl.bind(vars.mainMod .. " + CTRL + W", hl.dsp.global("quickshell:toggleWallpaperEngineNotch"))
hl.bind(vars.mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:toggleTransitionNotch"))
hl.bind(vars.mainMod .. " + SHIFT + M", hl.dsp.global("quickshell:toggleMusicInfoNotch"))
hl.bind(vars.mainMod .. " + N", hl.dsp.global("quickshell:toggleNotificationsNotch"))
hl.bind(vars.mainMod .. " + SHIFT + N", hl.dsp.global("quickshell:toggleNotesNotch"))
hl.bind(vars.mainMod .. " + slash", hl.dsp.global("quickshell:toggleCheatsheetNotch"))
hl.bind(vars.mainMod .. " + U", hl.dsp.global("quickshell:toggleUtilityNotch"))
hl.bind(vars.mainMod .. " + grave", hl.dsp.global("quickshell:resetNotchToIdle"))

--- Quickshell Window Switcher (Alt + Tab) ---
hl.bind("ALT + Tab", hl.dsp.global("quickshell:cycleWindowNext"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:cycleWindowPrev"))
hl.bind("ALT + Escape", hl.dsp.global("quickshell:resetNotchToIdle"))
hl.bind("Alt_L", hl.dsp.global("quickshell:confirmAltRelease"), { release = true })
hl.bind("Alt_R", hl.dsp.global("quickshell:confirmAltRelease"), { release = true })

--- Window management ---
hl.bind(vars.mainMod .. " + Q", hl.dsp.window.close())
hl.bind(vars.mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(vars.mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(vars.superMod .. " + C", hl.dsp.layout("colresize +conf"))
hl.bind(vars.superMod .. " + SHIFT + C", hl.dsp.layout("colresize -conf"))
hl.bind(vars.superMod .. " + G", hl.dsp.group.toggle())

hl.bind(vars.mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))
hl.bind(vars.mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(vars.mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(vars.mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(vars.superMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(vars.superMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(vars.superMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(vars.superMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

-- Mouse move/resize (both SUPER and SUPER+SHIFT supported)
hl.bind(vars.mainMod .. " + mouse:272", hl.dsp.window.drag(), { desc = "Move window" })
hl.bind(vars.mainMod .. " + mouse:273", hl.dsp.window.resize(), { desc = "Resize window" })
hl.bind(vars.mainMod .. " + SHIFT + mouse:272", hl.dsp.window.drag(), { desc = "Move window" })
hl.bind(vars.mainMod .. " + SHIFT + mouse:273", hl.dsp.window.resize(), { desc = "Resize window" })

--- Window groups ---
hl.bind(vars.superMod .. " + Tab", hl.dsp.window.cycle_next(), { repeating = true })
hl.bind(vars.superMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
hl.bind(vars.superMod .. " + U", hl.dsp.window.move({ out_of_group = true }))
hl.bind(vars.superMod .. " + SHIFT + Comma", hl.dsp.group.lock_active())
hl.bind("CTRL + " .. vars.mainMod .. " + Tab", hl.dsp.group.next(), { repeating = true })
hl.bind("CTRL + SHIFT + " .. vars.mainMod .. " + Tab", hl.dsp.group.prev(), { repeating = true })

--- Window actions ---
hl.bind(vars.superMod .. " + SHIFT + P", hl.dsp.window.pin())
hl.bind(vars.superMod .. " + Z", hl.dsp.window.drag())
hl.bind("CTRL + " .. vars.superMod .. " + Backslash", hl.dsp.window.center())
hl.bind("CTRL + " .. vars.superMod .. " + ALT + Backslash", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_by_screen(55, 70)))
    hl.dispatch(hl.dsp.window.center())
end)

--- Focus (with smart unmaximize to allow seamless navigation from maximized windows) ---
local function smart_focus(dir)
    local win = hl.get_active_window()
    if win and win.fullscreen and win.fullscreen ~= 0 and win.fullscreen ~= false then
        hl.dispatch(hl.dsp.window.fullscreen({ action = "unset" }))
    end
    hl.dispatch(hl.dsp.focus({ direction = dir }))
end

hl.bind(vars.mainMod .. " + Down", function()
    smart_focus("d")
end)
hl.bind(vars.mainMod .. " + Left", function()
    smart_focus("l")
end)
hl.bind(vars.mainMod .. " + Right", function()
    smart_focus("r")
end)
hl.bind(vars.mainMod .. " + Up", function()
    smart_focus("u")
end)
hl.bind(vars.superMod .. " + H", function()
    smart_focus("l")
end)
hl.bind(vars.superMod .. " + J", function()
    smart_focus("d")
end)
hl.bind(vars.superMod .. " + K", function()
    smart_focus("u")
end)
hl.bind(vars.superMod .. " + L", function()
    smart_focus("r")
end)
hl.bind(vars.superMod .. " + End", hl.dsp.focus({ window = "last" }))
hl.bind(vars.superMod .. " + Home", hl.dsp.focus({ window = "first" }))
hl.bind(vars.mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

--- Resize (percent via dynamic helpers; pixel via native relative delta) ---
hl.bind(vars.mainMod .. " + Equal", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_active_window(10, 0)))
end, { repeating = true })
hl.bind(vars.mainMod .. " + Minus", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_active_window(-10, 0)))
end, { repeating = true })
hl.bind(vars.mainMod .. " + SHIFT + Minus", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_active_window(0, -10)))
end, { repeating = true })
hl.bind(vars.mainMod .. " + SHIFT + Equal", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_active_window(0, 10)))
end, { repeating = true })
hl.bind(vars.superMod .. " + SHIFT + equal", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_active_window(0, 10)))
end, { repeating = true })
hl.bind(vars.superMod .. " + SHIFT + minus", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_active_window(0, -10)))
end, { repeating = true })
hl.bind(
    vars.superMod .. " + code:20",
    hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
    { desc = "Expand window left" }
)
hl.bind(
    vars.superMod .. " + code:21",
    hl.dsp.window.resize({ x = 100, y = 0, relative = true }),
    { desc = "Shrink window left" }
)
hl.bind(vars.superMod .. " + CTRL + F", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_by_screen(100, 100)))
end)

--- Workspaces (1 to 10) ---
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(vars.mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(vars.mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

--- Workspace navigation (Vertical workspaces: Super + Ctrl + Up/Down) ---
hl.bind("CTRL + " .. vars.superMod .. " + up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + " .. vars.superMod .. " + down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL + " .. vars.superMod .. " + SHIFT + up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("CTRL + " .. vars.superMod .. " + SHIFT + down", hl.dsp.window.move({ workspace = "e+1" }))

--- Window navigation in current workspace (Super + Ctrl + Left/Right) ---
hl.bind("CTRL + " .. vars.superMod .. " + left", function()
    smart_focus("l")
end)
hl.bind("CTRL + " .. vars.superMod .. " + right", function()
    smart_focus("r")
end)
hl.bind("CTRL + " .. vars.superMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind("CTRL + " .. vars.superMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

hl.bind(vars.superMod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(vars.superMod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(vars.mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(vars.mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(vars.superMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(vars.superMod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(vars.superMod .. " + CTRL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(vars.superMod .. " + CTRL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))

--- Monitor focus/move ---
hl.bind(vars.superMod .. " + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind(vars.superMod .. " + CTRL + J", hl.dsp.focus({ monitor = "d" }))
hl.bind(vars.superMod .. " + CTRL + K", hl.dsp.focus({ monitor = "u" }))
hl.bind(vars.superMod .. " + CTRL + L", hl.dsp.focus({ monitor = "r" }))
hl.bind(vars.superMod .. " + ALT + left", hl.dsp.focus({ monitor = "l" }))
hl.bind(vars.superMod .. " + ALT + right", hl.dsp.focus({ monitor = "r" }))
hl.bind(vars.superMod .. " + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "l" }))
hl.bind(vars.superMod .. " + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "d" }))
hl.bind(vars.superMod .. " + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }))
hl.bind(vars.superMod .. " + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }))
hl.bind(vars.superMod .. " + SHIFT + ALT + left", hl.dsp.window.move({ monitor = "l" }))
hl.bind(vars.superMod .. " + SHIFT + ALT + right", hl.dsp.window.move({ monitor = "r" }))

--- Layout (Scrolling layout controls) ---
hl.bind(vars.superMod .. " + bracketleft", hl.dsp.layout("move -col"))
hl.bind(vars.superMod .. " + bracketright", hl.dsp.layout("move +col"))
hl.bind(vars.superMod .. " + CTRL + bracketleft", hl.dsp.layout("swapcol -l"))
hl.bind(vars.superMod .. " + CTRL + bracketright", hl.dsp.layout("swapcol -r"))
hl.bind(vars.superMod .. " + Backslash", hl.dsp.layout("fit towidth"))
hl.bind(vars.superMod .. " + SHIFT + Backslash", hl.dsp.layout("fit toscreen"))
hl.bind(vars.superMod .. " + Period", hl.dsp.layout("promote"))

--- Special workspaces ---
hl.bind("CTRL + SHIFT + Escape", hl.dsp.workspace.toggle_special("sysmon"))
hl.bind(vars.mainMod .. " + M", hl.dsp.workspace.toggle_special("music"))
hl.bind(vars.mainMod .. " + X", hl.dsp.workspace.toggle_special("communication"))
hl.bind(vars.mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(vars.superMod .. " + CTRL + SHIFT + U", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind(vars.superMod .. " + CTRL + SHIFT + T", hl.dsp.window.move({ workspace = "special:todo" }))
hl.bind(vars.superMod .. " + CTRL + SHIFT + X", hl.dsp.window.move({ workspace = "special:communication" }))
hl.bind(vars.superMod .. " + CTRL + SHIFT + Escape", hl.dsp.window.move({ workspace = "special:sysmon" }))
hl.bind(vars.superMod .. " + CTRL + SHIFT + M", hl.dsp.window.move({ workspace = "special:music" }))

--- Volume (via Bar OSD) ---
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh volume_mute"), { locked = true })
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh volume_up"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh volume_down"),
    { locked = true, repeating = true }
)

--- Utilities & Media ---
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh brightness_up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh brightness_down"), { locked = true, repeating = true })
hl.bind(
    "XF86KbdBrightnessUp",
    hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh kbd_up"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86KbdBrightnessDown",
    hl.dsp.exec_cmd(hypr .. "/scripts/osd-control.sh kbd_down"),
    { locked = true, repeating = true }
)

--- Screenshots & Lock ---
hl.bind("CTRL + " .. vars.superMod .. " + SHIFT + S", hl.dsp.exec_cmd(quickshellScripts .. "/scripts/screenshot_hub.sh"))
hl.bind(vars.superMod .. " + SHIFT + S", hl.dsp.exec_cmd(quickshellScripts .. "/scripts/screenshot_hub.sh"))
hl.bind("Print", hl.dsp.exec_cmd(quickshellScripts .. "/scripts/screenshot_hub.sh"))
hl.bind(vars.mainMod .. " + Print", hl.dsp.exec_cmd(quickshellScripts .. "/scripts/screenshot_hub.sh"))
hl.bind(
    vars.mainMod .. " + CTRL + Print",
    hl.dsp.exec_cmd(
        [[sh -c 'hyprctl activewindow -j | jq -r "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" | grim -g - - | wl-copy && notify-send "Screenshot" "Window copied to clipboard"']]
    )
)
hl.bind(vars.mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

--- System ---
hl.bind(vars.superMod .. " + ALT + Q", hl.dsp.exec_cmd(hypr .. "/scripts/killapp.sh"))
hl.bind(vars.superMod .. " + SHIFT + K", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
hl.bind(vars.superMod .. " + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })
hl.bind(vars.superMod .. " + SHIFT + A", hl.dsp.exec_cmd(hypr .. "/scripts/select-blur.sh"))
hl.bind(vars.superMod .. " + ALT + C", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/toggle-cursor-trail"))
