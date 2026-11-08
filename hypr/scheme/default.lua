-- Committed fallback color palette (Lua). Used only if scheme/current.lua
-- does not exist yet, matugen regenerates current.lua from
-- the wallpaper via the hyprland-scheme template.
return {
    mode = "dark",

    -- Palette key colors
    primaryPaletteKeyColor = "9c413c",
    secondaryPaletteKeyColor = "775653",
    tertiaryPaletteKeyColor = "725b2e",
    neutralPaletteKeyColor = "655c5b",
    neutralVariantPaletteKeyColor = "6b5a59",
    errorPaletteKeyColor = "ba1a1a",
    primary_paletteKeyColor = "9c413c",
    secondary_paletteKeyColor = "775653",
    tertiary_paletteKeyColor = "725b2e",
    neutral_paletteKeyColor = "655c5b",
    neutral_variant_paletteKeyColor = "6b5a59",

    -- Surface roles
    background = "1a1110",
    onBackground = "f1dedc",
    surface = "1a1110",
    surfaceDim = "1a1110",
    surfaceBright = "423735",
    surfaceContainerLowest = "140c0b",
    surfaceContainerLow = "231918",
    surfaceContainer = "271d1c",
    surfaceContainerHigh = "322827",
    surfaceContainerHighest = "3d3231",
    onSurface = "f1dedc",
    surfaceVariant = "534342",
    onSurfaceVariant = "d8c2bf",
    inverseSurface = "f1dedc",
    inverseOnSurface = "392e2d",
    outline = "a08c8a",
    outlineVariant = "534342",
    shadow = "000000",
    scrim = "000000",
    surfaceTint = "ffb3ad",

    -- Primary
    primary = "ffb3ad",
    primaryDim = "ff847a",
    onPrimary = "571e1b",
    primaryContainer = "73332f",
    onPrimaryContainer = "ffdad6",
    inversePrimary = "904a45",
    primaryFixed = "ffdad6",
    primaryFixedDim = "ffb3ad",
    onPrimaryFixed = "3b0908",
    onPrimaryFixedVariant = "73332f",

    -- Secondary
    secondary = "e7bdb9",
    secondaryDim = "da9993",
    onSecondary = "442927",
    secondaryContainer = "5d3f3c",
    onSecondaryContainer = "ffdad6",
    secondaryFixed = "ffdad6",
    secondaryFixedDim = "e7bdb9",
    onSecondaryFixed = "2c1513",
    onSecondaryFixedVariant = "5d3f3c",

    -- Tertiary
    tertiary = "e1c28c",
    tertiaryDim = "d6ad64",
    onTertiary = "402d04",
    tertiaryContainer = "584419",
    onTertiaryContainer = "fedea6",
    tertiaryFixed = "fedea6",
    tertiaryFixedDim = "e1c28c",
    onTertiaryFixed = "261900",
    onTertiaryFixedVariant = "584419",

    -- Error
    error = "ffb4ab",
    errorDim = "ff705f",
    onError = "690005",
    errorContainer = "93000a",
    onErrorContainer = "ffdad6",

    -- Terminal 16-color palette
    term0 = "150b09",
    term1 = "bb908c",
    term2 = "30201d",
    term3 = "41302c",
    term4 = "2c1d1a",
    term5 = "2c1d1a",
    term6 = "2c1d1a",
    term7 = "8c6b67",
    term8 = "5c4441",
    term9 = "6e4e48",
    term10 = "60403a",
    term11 = "6f524b",
    term12 = "5c3d36",
    term13 = "5c3d36",
    term14 = "5c3d36",
    term15 = "bc918d",

    -- Catppuccin-style names
    rosewater = "fdf9f9",
    flamingo = "fbf8f8",
    pink = "ecd7b4",
    mauve = "e1c28c",
    red = "ffb4ab",
    maroon = "ff9082",
    peach = "ffe2de",
    yellow = "f6eddd",
    green = "ffd9d6",
    teal = "eecfcc",
    sky = "ffecea",
    sapphire = "ffc1bc",
    blue = "ffb3ad",
    lavender = "e6cda0",

    -- Pywal-style names
    text = "f1dedc",
    subtext1 = "d8c2bf",
    subtext0 = "a08c8a",
    overlay2 = "927b79",
    overlay1 = "5e4c4b",
    overlay0 = "453837",
    surface2 = "322827",
    surface1 = "271d1c",
    surface0 = "231918",
    base = "1a1110",
    mantle = "1a1110",
    crust = "140c0b",

    -- Success role
    success = "fffafa",
    onSuccessContainer = "fff1f0",

    onSuccess = "571e1b",
    successContainer = "73332f",

    -- KDE Konsole syntax-highlight colors (Selection variants mirror their base;
    -- table literals cannot self-reference, so the expression is repeated)
    klink = "ff3d2e",
    klinkSelection = "ff3d2e",
    kvisited = "f1a116",
    kvisitedSelection = "f1a116",
    kpositive = "ff5447",
    kpositiveSelection = "ff5447",

    knegative = "ff1b00",
    knegativeSelection = "ff1b00",
    kneutral = "c45e54",
    kneutralSelection = "c45e54",
}
