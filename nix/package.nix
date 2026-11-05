{ lib
, stdenvNoCC
, makeWrapper
, quickshell
, qt6
, python3
, bash
, coreutils
, findutils
, gawk
, gnused
, gnugrep
, jq
, socat
, inotify-tools
, procps
, psmisc
, libnotify
, wl-clipboard
, cliphist
, grim
, slurp
, brightnessctl
, playerctl
, pamixer
, wireplumber
, pipewire
, pulseaudio
, bluez
, imagemagick
, ffmpeg
, glib
, libqalculate
, lua5_4
, cava
, hyprland
, awww
, xsettingsd
}:

let
  pythonEnv = python3.withPackages (ps: [
    ps.dbus-python
    ps.pillow
  ]);

  runtimeDeps = [
    bash
    coreutils
    findutils
    gawk
    gnused
    gnugrep
    jq
    socat
    inotify-tools
    procps
    psmisc
    libnotify
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    playerctl
    pamixer
    wireplumber
    pipewire
    pulseaudio
    bluez
    imagemagick
    ffmpeg
    glib
    libqalculate
    lua5_4
    cava
    hyprland
    awww
    xsettingsd
    quickshell
    pythonEnv
  ];

  qmlDeps = [
    quickshell
    qt6.qtdeclarative
    qt6.qt5compat
    qt6.qtsvg
    qt6.qtmultimedia
    qt6.qtwayland
  ];
in
stdenvNoCC.mkDerivation {
  pname = "dynamic-you";
  version = "1.0.0";

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      let
        base = baseNameOf path;
      in
        base != ".git" &&
        base != "flake.lock" &&
        base != "result";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    pkgDir="$out/share/dynamic-you"
    mkdir -p "$pkgDir" "$out/bin"

    # Copy rice components
    for dir in quickshell themes Wallpapers scripts hypr kitty fish fastfetch starship active-theme krabby nvim; do
      if [ -d "$dir" ]; then
        cp -r "$dir" "$pkgDir/"
      fi
    done
    [ -d sddm ] && cp -r sddm "$pkgDir/"
    [ -f starship.toml ] && cp starship.toml "$pkgDir/"

    # Fix execution permissions
    chmod +x "$pkgDir"/scripts/*.sh 2>/dev/null || true
    chmod +x "$pkgDir"/quickshell/scripts/*.sh 2>/dev/null || true
    chmod +x "$pkgDir"/quickshell/scripts/*.py 2>/dev/null || true
    chmod +x "$pkgDir"/quickshell/reload.sh 2>/dev/null || true

    # Patch shebangs across all installed scripts
    patchShebangs "$pkgDir"

    # Install the unified dynamic-you CLI runner
    cp ${./dynamic-you.sh} "$out/bin/dynamic-you"
    chmod +x "$out/bin/dynamic-you"
    substituteInPlace "$out/bin/dynamic-you" \
      --subst-var-by pkgDir "$pkgDir"

    # Wrap the main binary
    wrapProgram "$out/bin/dynamic-you" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      --set DYNAMIC_YOU_SHARE_DIR "$pkgDir"

    # Also wrap standalone helper scripts for direct CLI execution
    makeWrapper "$pkgDir/scripts/apply-theme.sh" "$out/bin/apply-theme.sh" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      --set DYNAMIC_YOU_SHARE_DIR "$pkgDir"

    makeWrapper "$pkgDir/scripts/init-wallpaper.sh" "$out/bin/init-wallpaper.sh" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      --set DYNAMIC_YOU_SHARE_DIR "$pkgDir"

    makeWrapper "$pkgDir/scripts/osd-control.sh" "$out/bin/osd-control.sh" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      --set DYNAMIC_YOU_SHARE_DIR "$pkgDir"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Material 3 Expressive × Fluid Wayland Rice powered by QuickShell & Hyprland";
    homepage = "https://github.com/SubhamJM/DynamicYou";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "dynamic-you";
  };
}