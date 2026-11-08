-- ==================================================
--  M3 Expressive Animation Curves & Configuration
--  Enhanced from Caelestia motion spec
-- ==================================================

-- Spatial Curves (Bouncy overshoot settle for movement & workspaces)
hl.curve("expressiveDefaultSpatial", {
    type = "bezier",
    points = {{0.38, 1.21}, {0.22, 1.00}}
})
hl.curve("expressiveFastSpatial", {
    type = "bezier",
    points = {{0.42, 1.67}, {0.21, 0.90}}
})
hl.curve("expressiveSlowSpatial", {
    type = "bezier",
    points = {{0.39, 1.29}, {0.35, 0.98}}
})

-- Visual Effects Curves (Fades, opacities, and borders)
hl.curve("expressiveDefaultEffects", {
    type = "bezier",
    points = {{0.34, 0.80}, {0.34, 1.00}}
})
hl.curve("expressiveFastEffects", {
    type = "bezier",
    points = {{0.31, 0.94}, {0.34, 1.00}}
})

-- Emphasized Curves (Enter / Exit transitions)
hl.curve("emphasizedDecel", {
    type = "bezier",
    points = {{0.05, 0.70}, {0.10, 1.00}}
})
hl.curve("emphasizedAccel", {
    type = "bezier",
    points = {{0.30, 0.00}, {0.80, 0.15}}
})

-- Standard & Utility Curves
hl.curve("standardDecel", {
    type = "bezier",
    points = {{0.00, 0.00}, {0.00, 1.00}}
})
hl.curve("menu_decel", {
    type = "bezier",
    points = {{0.10, 1.00}, {0.00, 1.00}}
})
hl.curve("menu_accel", {
    type = "bezier",
    points = {{0.52, 0.03}, {0.72, 0.08}}
})
hl.curve("stall", {
    type = "bezier",
    points = {{1.00, -0.10}, {0.70, 0.85}}
})

-- ==================================================
--  Animation Bindings
-- ==================================================

-- Window Opening & Closing
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 3.6,
    bezier = "emphasizedDecel",
    style = "popin 84%"
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 2.4,
    bezier = "emphasizedAccel",
    style = "popin 88%"
})
hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 4.8,
    bezier = "expressiveDefaultSpatial",
    style = "slide"
})

-- Fade Transitions
hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 2.8,
    bezier = "expressiveDefaultEffects"
})
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 2.0,
    bezier = "expressiveFastEffects"
})
hl.animation({
    leaf = "fadeSwitch",
    enabled = true,
    speed = 3.2,
    bezier = "expressiveDefaultEffects"
})
hl.animation({
    leaf = "fadeDim",
    enabled = true,
    speed = 3.2,
    bezier = "expressiveDefaultEffects"
})

-- Borders
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 2.8,
    bezier = "expressiveFastEffects"
})
hl.animation({
    leaf = "borderangle",
    enabled = false
})

-- Layer Shell Surfaces (Popups, Bars, OSDs)
hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 3.0,
    bezier = "emphasizedDecel",
    style = "popin 92%"
})
hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 2.2,
    bezier = "emphasizedAccel",
    style = "popin 94%"
})
hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 2.0,
    bezier = "expressiveDefaultEffects"
})
hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 1.8,
    bezier = "expressiveFastEffects"
})

-- Workspaces Navigation (Vertical slide with M3 overshoot)
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 6.5,
    bezier = "expressiveSlowSpatial",
    style = "slidevert"
})
hl.animation({
    leaf = "specialWorkspaceIn",
    enabled = true,
    speed = 4.2,
    bezier = "expressiveDefaultSpatial",
    style = "slidefadevert 15%"
})
hl.animation({
    leaf = "specialWorkspaceOut",
    enabled = true,
    speed = 2.8,
    bezier = "emphasizedAccel",
    style = "slidefadevert 15%"
})

-- Zoom
hl.animation({
    leaf = "zoomFactor",
    enabled = true,
    speed = 3.0,
    bezier = "standardDecel"
})
