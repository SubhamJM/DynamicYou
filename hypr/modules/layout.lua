-----------------------
-------- LAYOUT -------
-----------------------

hl.config({
    general = { layout = "scrolling", gaps_workspaces = 0 },
    dwindle = {
        preserve_split = true,
        split_width_multiplier = 1.5,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    -- Match scrolling-dots: full-width columns, Super+D cycles half/full.
    scrolling = {
        direction = "right",
        fullscreen_on_one_column = true,
        focus_fit_method = 1,
        column_width = 1.0,
        follow_focus = 1,
        follow_min_visible = 0.0,
        explicit_column_widths = "0.5, 1.0",
    },
})
