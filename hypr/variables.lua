-- All variables
local ok, scheme = pcall(require, "scheme.current")
if not ok or type(scheme) ~= "table" then
    local ok2, def = pcall(require, "scheme.default")
    scheme = (ok2 and type(def) == "table") and def or { shadow = "000000" }
end

return {
    ------------------
    ---- HYPRLAND ----
    ------------------

    -- Apps
    terminal = "foot",
    browser = "zen-beta",
    editor = "zed",
    fileExplorer = "dolphin",
    audioSettings = "pavucontrol",

    -- Special workspace apps
    sysmonToggle = "foot -a btop -T btop sh -ic 'exec btop'",
    musicToggle = "spicetify watch -s",
    communicationToggle = "vesktop",
    todoToggle = "obsidian",

    -- Modifiers, handy for composing keyspecs
    mainMod = "SUPER",
    superMod = "SUPER",

    -- Keyboard
    kbLayout = "us",

    -- Cursor (Material Light Cursors)
    cursorTheme = "material_light_cursors",
    cursorSize = 24,

    -- Blur
    blurEnabled = false,
    blurSpecialWs = false,
    blurPopups = false,
    blurInputMethods = false,
    blurSize = 10,
    blurPasses = 4,
    blurXray = false,
    blurNoise = 0.04,
    blurBrightness = 1,
    blurContrast = 0.89,
    blurVibrancy = 0.2,
    blurVibrancyDark = 0.2,

    -- Motion blur
    motionBlurEnabled = false,
    motionBlurSamples = 7,

    -- Shadow
    shadowEnabled = true,
    shadowRange = 25,
    shadowRenderPower = 4,
    shadowColour = "rgba(1a1a1aee)",
    shadowOffset = "0 0",

    -- Gaps
    workspaceGaps = 20,
    windowGapsIn = 5,
    windowGapsOut = 6,
    singleWindowGapsOut = 6,

    -- Window styling
    opacitySingleMode = 1,
    singleWindowOpacity = 1,
    -- only works if opacitySingleMode is off (0)
    activeWindowOpacity = 1,
    inactiveWindowOpacity = 1,

    windowRounding = 12,
    windowRoundingPower = 2.0,
    windowBorderSize = 0,
    activeWindowBorderColour = "rgb(ffffff)",
    inactiveWindowBorderColour = "rgba(ffffff33)",

    -- Animations
    -- "m3-expressive", "m3-hybrid", "m3-standard", "simple"
    animationProfile = "m3-hybrid",
    animationsEnabled = true,
    -- only used by the "simple" profile
    animationSpeed = 20,

    -- slide, slidevert, slidefade, slidefadevert
    workspaceStyle = "slidevert",
    -- dwindle, master, scrolling
    tilingLayout = "scrolling",

    -- General
    allowTearing = false,
    directScanout = false,

    -- Touchpad / gestures
    touchpadDisableTyping = true,
    touchpadScrollFactor = 0.3,
    workspaceSwipeFingers = 3,
    gestureFingers = 4,
    gestureFingersMore = 4,

    -- Misc
    volumeStep = 4,
    sleepGestureCmd = "systemctl suspend-then-hibernate",

    ------------------
    ---- KEYBINDS ----
    ------------------

    -- Each entry is a keyspec string ("MOD + KEY" format) or an array of
    -- keyspecs, all bound to the same action.

    -- Apps
    kbTerminal = "SUPER + Return",
    kbBrowser = "SUPER + B",
    kbEditor = "SUPER + C",
    kbFileExplorer = "SUPER + E",
    kbSmartFloat = "SUPER + Space", -- tile / float (900x600, centered)

    -- Window management
    kbCloseWindow = "SUPER + Q",
    kbWindowFullscreen = "SUPER + SHIFT + F",
    kbWindowMaximized = "SUPER + F",
    kbToggleSplit = "SUPER + R",
    kbToggleGroup = "SUPER + W",

    kbWindowMoveLeft = "SUPER + SHIFT + Left",
    kbWindowMoveDown = "SUPER + SHIFT + Down",
    kbWindowMoveUp = "SUPER + SHIFT + Up",
    kbWindowMoveRight = "SUPER + SHIFT + Right",

    kbMouseMove = "SUPER + SHIFT + mouse:272",
    kbMouseResize = "SUPER + SHIFT + mouse:273",

    -- Window groups
    kbWindowCycleNext = "SUPER + Tab",
    kbWindowCyclePrev = "SUPER + SHIFT + Tab",
    kbUngroup = "SUPER + U",
    kbGroupLockActive = "SUPER + SHIFT + Comma",
    kbGroupNext = "CTRL + SUPER + Tab",
    kbGroupPrev = "CTRL + SHIFT + SUPER + Tab",

    -- Window actions
    kbPinWindow = "SUPER + P",
    kbMoveWindow = "SUPER + Z",
    kbResizeWindow = "SUPER + X",
    kbCenterWindow = "CTRL + SUPER + Backslash",
    kbNormalizeWindow = "CTRL + SUPER + ALT + Backslash", -- 55x70 + center

    -- Focus
    -- No H/L aliases: SUPER+H opens the Hub and SUPER+L locks the session;
    -- duplicate keyspecs fire both binds.
    kbFocusLeft = "SUPER + Left",
    kbFocusDown = "SUPER + Down",
    kbFocusUp = "SUPER + Up",
    kbFocusRight = "SUPER + Right",
    kbFocusLastWindow = "SUPER + End",
    kbFocusFirstWindow = "SUPER + Home",

    -- Resize
    kbWindowIncreaseWidth = "SUPER + Equal",
    kbWindowDecreaseWidth = "SUPER + Minus",
    kbWindowIncreaseHeight = "SUPER + SHIFT + Equal",
    kbWindowDecreaseHeight = "SUPER + SHIFT + Minus",
    kbWindowExpandLeft = "SUPER + code:20",
    kbWindowShrinkLeft = "SUPER + code:21",
    kbWindowFillScreen = "SUPER + CTRL + F",

    -- Workspaces
    kbGoToWs = "SUPER",
    kbMoveWinToWs = "SUPER + SHIFT",

    -- Workspace navigation
    kbNextWs = { "SUPER + Page_Down", "SUPER + mouse_down" },
    kbPrevWs = { "SUPER + Page_Up", "SUPER + mouse_up" },
    kbMoveWinToWsNext = { "SUPER + SHIFT + Page_Down", "SUPER + SHIFT + mouse_down" },
    kbMoveWinToWsPrev = { "SUPER + SHIFT + Page_Up", "SUPER + SHIFT + mouse_up" },
    kbCycleNextWs = { "SUPER + ALT + Page_Down", "SUPER + ALT + mouse_down" },
    kbCyclePrevWs = { "SUPER + ALT + Page_Up", "SUPER + ALT + mouse_up" },
    kbToggleLastWorkspace = "ALT + Tab",

    -- Monitor focus/move
    kbFocusMonitorLeft = { "SUPER + CTRL + H", "SUPER + CTRL + left" },
    kbFocusMonitorDown = "SUPER + CTRL + J",
    kbFocusMonitorUp = "SUPER + CTRL + K",
    kbFocusMonitorRight = { "SUPER + CTRL + L", "SUPER + CTRL + right" },

    -- No up/down arrow aliases here: SUPER+CTRL+SHIFT+up/down are used by the
    -- special-workspace move binds below, and duplicate keyspecs fire both binds.
    kbMoveMonitorLeft = { "SUPER + SHIFT + CTRL + H", "SUPER + SHIFT + CTRL + left" },
    kbMoveMonitorDown = "SUPER + SHIFT + CTRL + J",
    kbMoveMonitorUp = "SUPER + SHIFT + CTRL + K",
    kbMoveMonitorRight = { "SUPER + SHIFT + CTRL + L", "SUPER + SHIFT + CTRL + right" },

    -- Layout
    kbPreselectLeft = "SUPER + bracketleft",
    kbPreselectRight = "SUPER + bracketright",

    -- Special workspace toggles
    kbSystemMonitorWs = "CTRL + SHIFT + Escape",
    kbMusicWs = "SUPER + M",
    kbCommunicationWs = "SUPER + D",
    kbTodoWs = "SUPER + T",
    kbSpecialWs = "SUPER + S",

    -- Move the active window to/from special workspaces
    kbMoveWinToWsSpecial = { "SUPER + CTRL + SHIFT + S", "SUPER + CTRL + SHIFT + up" },
    kbMoveWinFromWsSpecial = "SUPER + CTRL + SHIFT + down",
    kbMoveWinToSysmon = "SUPER + CTRL + SHIFT + Escape",
    kbMoveWinToMusic = "SUPER + CTRL + SHIFT + M",
    kbMoveWinToCommunication = "SUPER + CTRL + SHIFT + D",
    kbMoveWinToTodo = "SUPER + CTRL + SHIFT + T",

    -- Volume (wpctl)
    kbVolumeMute = { "XF86AudioMute", "SUPER + SHIFT + M" },
    kbMicMute = "XF86AudioMicMute",
    kbVolumeUp = "XF86AudioRaiseVolume",
    kbVolumeDown = "XF86AudioLowerVolume",

    -- System
    kbSwitchKeyboardLayout = "SUPER + SHIFT + K",
    kbSuspend = "SUPER + SHIFT + L",

    ---------------------------------
    ---- OMARCHY SHELL KEYBINDS -----
    ---------------------------------

    -- Panels
    kbHub = "SUPER + H",
    kbNotifications = "SUPER + N",
    kbLock = "SUPER + L",
    kbPowerMenu = "CTRL + ALT + Delete",
    kbControlCenter = "SUPER + ALT + C",
    kbMediaPlayer = "SUPER + ALT + M",
    kbSystemMonitor = "SUPER + ALT + S",
    kbWallpaperCarousel = "SUPER + SHIFT + W",

    -- Launcher (bound with the release flag so it fires on Super let-go)
    kbLauncher = "SUPER + Super_L",

    -- Toggles
    kbToggleDnd = "SUPER + ALT + D",
    kbToggleGamemode = "SUPER + ALT + G",
    kbToggleKeepAwake = "SUPER + ALT + I",
    kbThemeToggle = "SUPER + ALT + T",

    -- Clipboard & emoji
    kbClipboard = "SUPER + V",
    kbEmojiPicker = "SUPER + Period",

    -- Capture
    kbColorPicker = "SUPER + SHIFT + C",
    kbScreenshotRegion = "SUPER + SHIFT + S",
    kbScreenshotFullscreen = "Print",
    kbRecordFullscreen = "SUPER + ALT + R",

    -- Brightness / volume via the shell OSD
    kbBrightnessUp = { "XF86MonBrightnessUp", "SUPER + ALT + right" },
    kbBrightnessDown = { "XF86MonBrightnessDown", "SUPER + ALT + left" },
    kbShellVolumeUp = { "SUPER + ALT + up" },
    kbShellVolumeDown = { "SUPER + ALT + down" },
}
