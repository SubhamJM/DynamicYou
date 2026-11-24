local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local colors = {}
local theme_file = io.open(config .. "/active-theme/hypr-colors.lua", "r")
if theme_file then
    theme_file:close()
    local ok, result = pcall(dofile, config .. "/active-theme/hypr-colors.lua")
    if ok and type(result) == "table" then colors = result end
end

hl.config({
    general = {
        -- Gaps and border
        gaps_in = 6,
        gaps_out = 10,

        border_size = 0,

        col = {
            active_border = colors.active_border or "rgba(0DB7D455)",
            inactive_border = colors.inactive_border or "rgba(31313600)"
        },
        resize_on_border = true,

        no_focus_fallback = true,
        allow_tearing = true, -- This just allows the `immediate` window rule to work
        -- snap = {
        --     enabled = true,
        --     window_gap = 4,
        --     monitor_gap = 5,
        --     respect_gaps = true
        -- }
    },
    decoration = {
        -- 2 = circle, higher = squircle, 4 = very obvious squircle
        -- Fuck clearly visible squircles. 100% Apple brainrot.
        rounding_power = 2.5,
        rounding = 12,

		active_opacity = 1.0,
		inactive_opacity = 1.0,


        blur = {
            enabled = false,
            xray = false,
            special = false,
            new_optimizations = true,
            size = 20,
            passes = 4,
            brightness = 1,
            noise = 0.05,
            contrast = 0.89,
            vibrancy = 0.5,
            vibrancy_darkness = 0.5,
            popups = false,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8
        },
        shadow = {
            enabled = false,
            range = 25,
            render_power = 4,
            color = "rgba(1a1a1aee)"
		},
        -- Dim
        dim_inactive = false,
        dim_strength = 0.0,
        dim_special = 0.0
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false
        -- precise_mouse_move = true,
    },
})

