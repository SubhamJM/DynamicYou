-------------------
---- ANIMATIONS ---
-------------------

hl.curve("easeExit",       { type = "bezier", points = { {0.48, 0.02}, {0.65, 0.72} } })
hl.curve("easeTransition", { type = "bezier", points = { {0.28, 0.00}, {0.16, 1.00} } })
hl.curve("easeOut",        { type = "bezier", points = { {0.18, 0.58}, {0.22, 1.00} } })

hl.animation({ leaf = "global",     enabled = true, speed = 3.4, bezier = "easeOut" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3.1, bezier = "easeOut" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.4, bezier = "easeOut", style = "popin 78%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.7, bezier = "easeExit", style = "slide bottom" })
-- Scrolling-layout column movement and window reflow use windowsMove.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.7, bezier = "easeTransition" })
hl.animation({ leaf = "border",     enabled = true, speed = 2.4, bezier = "easeOut" })

hl.animation({ leaf = "workspaces",    enabled = true, speed = 3.5, bezier = "easeTransition", style = "slidevert" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 3.5, bezier = "easeTransition", style = "slidevert" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3.5, bezier = "easeTransition", style = "slidevert" })
-- Special workspaces slide over the regular workspace.
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "easeTransition", style = "slidefadevert 15%" })

hl.animation({ leaf = "fade",       enabled = true, speed = 2.5, bezier = "easeOut" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.1, bezier = "easeOut" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2.7, bezier = "easeExit" })

hl.animation({ leaf = "layers",        enabled = true, speed = 2.6, bezier = "easeOut" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.4, bezier = "easeOut", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2.0, bezier = "easeExit", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.4, bezier = "easeOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.0, bezier = "easeExit" })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3.6, bezier = "easeTransition" })
