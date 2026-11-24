-- Match scrolling-dots: switch workspaces vertically and pan columns sideways.
hl.config({
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.20,
        workspace_swipe_min_speed_to_force = 10,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new = true,
        scrolling = {
            move_snap_to_grid = true,
            move_snap_cursor = false,
        },
    },
})

hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })

-- Keep the first six workspaces available for swiping at startup.
for i = 1, 6 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- Four fingers open or close Dynamic You's workspace pager. Super+Ctrl+O also toggles it.
local function overview(action)
    return function()
        hl.dispatch(hl.dsp.exec_cmd("qs ipc call workspaces " .. action))
    end
end

hl.gesture({ fingers = 4, direction = "down", scale = 1.6, action = overview("open") })
hl.gesture({ fingers = 4, direction = "up", scale = 1.6, action = overview("close") })
