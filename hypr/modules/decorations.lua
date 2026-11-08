-- ==================================================
--  Look and Feel / Decorations (Enhanced from Caelestia)
-- ==================================================

-- Dynamic active-theme border colors loader with graceful M3 fallback
local home = os.getenv("HOME") or "/home/kuro"
local ok, theme_colors = pcall(dofile, home .. "/.config/active-theme/hypr-colors.lua")
local active_border = (ok and type(theme_colors) == "table" and theme_colors.active_border) or "rgba(c084fcee)"
local inactive_border = (ok and type(theme_colors) == "table" and theme_colors.inactive_border) or "rgba(231d3688)"

hl.config({
    general = {
        -- Gaps and borders
        gaps_in = 6,
        gaps_out = 10,
        gaps_workspaces = 20,
        border_size = 2,

        col = {
            active_border = active_border,
            inactive_border = inactive_border,
        },
        resize_on_border = true,
        no_focus_fallback = true,
        allow_tearing = true,
    },

    decoration = {
        -- 2 = circle, higher = squircle
        rounding_power = 2.0,
        rounding = 12,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        blur = {
            enabled = true,
            xray = false,
            special = false,
            new_optimizations = true,
            size = 14,
            passes = 4,
            brightness = 1.0,
            noise = 0.02,
            contrast = 0.90,
            vibrancy = 0.50,
            vibrancy_darkness = 0.50,
            popups = false,
            popups_ignorealpha = 0.6,
            input_methods = false,
            input_methods_ignorealpha = 0.8,
        },

        -- Restore original deep shadow aesthetic
        shadow = {
            enabled = true,
            range = 25,
            render_power = 4,
            color = "rgba(1a1a1aee)",
        },

        -- Dimming for inactive windows
        dim_inactive = false,
        dim_strength = 0.0,
        dim_special = 0.0,
    },

    animations = {
        enabled = true,
    },

    -- Group and groupbar styling (from Caelestia)
    group = {
        col = {
            border_active = active_border,
            border_inactive = inactive_border,
            border_locked_active = active_border,
            border_locked_inactive = inactive_border,
        },
        groupbar = {
            font_family = "Noto Sans",
            font_size = 11,
            gradients = true,
            gradient_rounding = 6,
            height = 24,
            indicator_height = 0,
            gaps_in = 3,
            gaps_out = 3,
            col = {
                active = active_border,
                inactive = inactive_border,
            },
        },
    },
})
