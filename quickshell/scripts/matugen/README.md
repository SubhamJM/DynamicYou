# Wallpaper colors

Dynamic You derives a Material 3 palette when you choose a wallpaper, when a preset chooses one, and on startup. It uses the same Matugen defaults and app templates as Lucid. All the code and templates live here. The default installation uses the wallpaper library at `~/Pictures/Wallpapers`.

The full Arch installer includes Matugen. For an existing installation or a dotfiles-only setup, install Matugen 4 and Python 3 with your package manager if needed. The wallpaper still applies if generation fails. To refresh colors for the current wallpaper without changing it, run:

```sh
python3 "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts/matugen/update.py"
```

## Settings

Optional user settings live in `${XDG_CONFIG_HOME:-$HOME/.config}/dynamic-you/matugen.json`. No config file is needed for the defaults.

```json
{
  "enabled": true,
  "mode": "dark",
  "scheme": "scheme-tonal-spot",
  "contrast": 0,
  "surfaceTint": 0.7
}
```

Use `"light"` or `"auto"` for mode. Auto uses ImageMagick to pick light or dark from the image, with dark as the fallback. Contrast ranges from -1 to 1. To use a different dominant color on one wallpaper, add its resolved path as `sourceImage` and a `sourceIndex` from 0 to 3. Other wallpapers use their most dominant color. Set `enabled` to false and run the refresh command to return the shell, Hyprland, and Kitty to their existing colors. Presets still select wallpaper collections and provide fallback colors.

## App integration

- Quickshell watches its palette cache and Hyprland applies the same primary and outline. The wallpaper palette takes precedence over the media accent in the shell.
- Kitty loads the generated palette via an include. Starship recolors the existing active palette table while preserving its prompt layout. Running Kitty instances of the current user reload their configuration. An optional `kittySocket` such as `unix:/path/to/your/kitty.sock` also updates clients using that socket.
- Zen’s default profile is discovered from `installs.ini` or `profiles.ini`, including the usual native and Flatpak locations. Start Zen once if it has no profile. Its existing CSS and preferences are preserved, and the generated browser and supported-site styles are imported. Native CSS changes take effect on restart. If the profile already uses Lucid’s watcher, Dynamic You uses it for live updates. With Fx AutoConfig already installed, add Dynamic You’s equivalent watcher with `update.py --install-zen-live`, then restart Zen once. The tool only installs the palette watcher for this explicit option.
- GTK loads an imported generated stylesheet. Also generated are the DynamicYou qt6ct and KDE schemes, a Vesktop theme stylesheet, and the Matugen VS Code cache formats. Select the matching scheme or theme in those applications if applicable.

Generated files go under the current user’s config and cache directories. Dynamic You reads its own palette at `${XDG_CACHE_HOME:-$HOME/.cache}/dynamic-you/palette.json`.
