-- Matushell template: emits a Lua color table consumed by the Hyprland Lua config.
-- Mirrors the full token set previously provided by scheme/current.conf so the
-- shell and downstream consumers keep working. Colors are hex without '#'.
return {
    mode = "dark",

    -- Palette key colors
    primaryPaletteKeyColor         = "b00090",
    secondaryPaletteKeyColor       = "705765",
    tertiaryPaletteKeyColor        = "80543e",
    neutralPaletteKeyColor         = "635d5f",
    neutralVariantPaletteKeyColor  = "685b61",
    errorPaletteKeyColor           = "ba1a1a",
    primary_paletteKeyColor        = "b00090",
    secondary_paletteKeyColor      = "705765",
    tertiary_paletteKeyColor       = "80543e",
    neutral_paletteKeyColor        = "635d5f",
    neutral_variant_paletteKeyColor = "685b61",

    -- Surface roles
    background            = "1b1017",
    onBackground          = "f2dde7",
    surface               = "1b1017",
    surfaceDim            = "1b1017",
    surfaceBright         = "43353d",
    surfaceContainerLowest = "150b11",
    surfaceContainerLow   = "24181f",
    surfaceContainer      = "281c23",
    surfaceContainerHigh  = "33262e",
    surfaceContainerHighest = "3e3138",
    onSurface             = "f2dde7",
    surfaceVariant        = "51434b",
    onSurfaceVariant      = "d5c1cb",
    inverseSurface        = "f2dde7",
    inverseOnSurface      = "3a2d34",
    outline               = "9e8c95",
    outlineVariant        = "51434b",
    shadow                = "000000",
    scrim                 = "000000",
    surfaceTint           = "ffade0",

    -- Primary
    primary        = "ffade0",
    primaryDim     = "ff7acd",
    onPrimary      = "5f004d",
    primaryContainer = "87006d",
    onPrimaryContainer = "ffd8ed",
    inversePrimary = "b00090",
    primaryFixed   = "ffd8ed",
    primaryFixedDim = "ffade0",
    onPrimaryFixed = "3b002e",
    onPrimaryFixedVariant = "87006d",

    -- Secondary
    secondary        = "eeb8cb",
    secondaryDim     = "e48fad",
    onSecondary      = "492534",
    secondaryContainer = "623b4a",
    onSecondaryContainer = "ffd9e5",
    secondaryFixed   = "ffd9e5",
    secondaryFixedDim = "eeb8cb",
    onSecondaryFixed = "31111f",
    onSecondaryFixedVariant = "623b4a",

    -- Tertiary
    tertiary        = "ffb2bd",
    tertiaryDim     = "ff7f91",
    onTertiary      = "52202a",
    tertiaryContainer = "6e3540",
    onTertiaryContainer = "ffd9dd",
    tertiaryFixed   = "ffd9dd",
    tertiaryFixedDim = "ffb2bd",
    onTertiaryFixed = "380b16",
    onTertiaryFixedVariant = "6e3540",

    -- Error
    error        = "ffb4ab",
    errorDim     = "ff705f",
    onError      = "690005",
    errorContainer = "93000a",
    onErrorContainer = "ffdad6",

    -- Terminal 16-color palette
    term0  = "080017",
    term1  = "080017",
    term2  = "0e001a",
    term3  = "0c021b",
    term4  = "0f011c",
    term5  = "0f0121",
    term6  = "15001c",
    term7  = "a95697",
    term8  = "683464",
    term9  = "0a0119",
    term10 = "370067",
    term11 = "2c0762",
    term12 = "370466",
    term13 = "31036b",
    term14 = "4e0069",
    term15 = "e978ca",

    -- Catppuccin-style names
    rosewater = "fdfbfc",
    flamingo  = "faf8f9",
    pink      = "ffe5e9",
    mauve     = "ffb2bd",
    red       = "ffb4ab",
    maroon    = "ff9082",
    peach     = "ffe2de",
    yellow    = "ffffff",
    green     = "ffd6ef",
    teal      = "f3cdda",
    sky       = "ffeaf7",
    sapphire  = "ffbce6",
    blue      = "ffade0",
    lavender  = "ffccd3",

    -- Pywal-style names
    text     = "f2dde7",
    subtext1 = "d5c1cb",
    subtext0 = "9e8c95",
    overlay2 = "907b86",
    overlay1 = "5c4c55",
    overlay0 = "43373e",
    surface2 = "33262e",
    surface1 = "281c23",
    surface0 = "24181f",
    base     = "1b1017",
    mantle   = "1b1017",
    crust    = "150b11",

    -- Success role
    success = "fffafd",
    onSuccessContainer = "fff2f9",
    
    onSuccess = "5f004d",
    successContainer = "87006d",

    -- KDE Konsole syntax-highlight colors (Selection variants mirror their base;
    -- table literals cannot self-reference, so the expression is repeated)
    klink = "ff2eb0",
    klinkSelection = "ff2eb0",
    kvisited = "ff4c66",
    kvisitedSelection = "ff4c66",
    kpositive = "ff47b9",
    kpositiveSelection = "ff47b9",
    
    knegative = "ff1b00",
    knegativeSelection = "ff1b00",
    kneutral = "d34677",
    kneutralSelection = "d34677",
}
