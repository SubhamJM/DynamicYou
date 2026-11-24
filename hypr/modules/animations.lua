-------------------
---- ANIMATIONS ---
-------------------

-- Premium, smooth cubic bezier curves:
-- 1. smoothSpatial: Silky, weighted easing with a gentle settling curve (for workspaces & scrolling column pans)
hl.curve("smoothSpatial",    { type = "bezier", points = { { 0.25, 1.00 }, { 0.18, 1.00 } } })
-- 2. emphasizedDecel: Material 3 emphasized deceleration (clear, graceful window pop-ins and open animations)
hl.curve("emphasizedDecel",  { type = "bezier", points = { { 0.05, 0.70 }, { 0.10, 1.00 } } })
-- 3. emphasizedAccel: Decisive, clean acceleration curve for exits
hl.curve("emphasizedAccel",  { type = "bezier", points = { { 0.30, 0.00 }, { 0.80, 0.15 } } })
-- 4. standardEase: Soft, predictable curve for fades, borders, and general transitions
hl.curve("standardEase",     { type = "bezier", points = { { 0.20, 0.00 }, { 0.00, 1.00 } } })

-- Global fallback
hl.animation({ leaf = "global",     enabled = true, speed = 5.0, bezier = "emphasizedDecel" })

-- Windows (Smooth popin at speed 4.5, decisive close at speed 3.0)
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4.5, bezier = "emphasizedDecel", style = "popin 82%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.0, bezier = "emphasizedAccel", style = "popin 85%" })
hl.animation({ leaf = "windows",     enabled = true, speed = 4.5, bezier = "emphasizedDecel" })

-- Column Movement in scrolling layout (Smooth, weighted spatial glide matching workspaces)
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5.8, bezier = "smoothSpatial" })

-- Borders
hl.animation({ leaf = "border",      enabled = true, speed = 3.5, bezier = "standardEase" })

-- Workspaces (Deliberate, graceful 6.5 speed with smooth spatial curve — zero jitter on gestures)
hl.animation({ leaf = "workspaces",    enabled = true, speed = 6.5, bezier = "smoothSpatial", style = "slidevert" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 6.5, bezier = "smoothSpatial", style = "slidevert" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 6.5, bezier = "smoothSpatial", style = "slidevert" })

-- Special Workspace
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.8, bezier = "smoothSpatial", style = "slidefadevert 15%" })

-- Fades
hl.animation({ leaf = "fade",        enabled = true, speed = 3.5, bezier = "standardEase" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 3.0, bezier = "standardEase" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2.8, bezier = "emphasizedAccel" })

-- Layers (Notch, Bar, Popups, Launcher)
hl.animation({ leaf = "layers",         enabled = true, speed = 4.0, bezier = "emphasizedDecel" })
hl.animation({ leaf = "layersIn",       enabled = true, speed = 3.8, bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "layersOut",      enabled = true, speed = 2.8, bezier = "emphasizedAccel", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn",   enabled = true, speed = 3.0, bezier = "standardEase" })
hl.animation({ leaf = "fadeLayersOut",  enabled = true, speed = 2.6, bezier = "emphasizedAccel" })

-- Zoom factor
hl.animation({ leaf = "zoomFactor",  enabled = true, speed = 4.5, bezier = "smoothSpatial" })
