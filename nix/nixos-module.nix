{ defaultPackage ? null }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.dynamic-you;
in
{
  options.programs.dynamic-you = {
    enable = lib.mkEnableOption "DynamicYou QuickShell and Hyprland desktop environment rice";

    package = lib.mkOption {
      type = lib.types.package;
      default = if defaultPackage != null then defaultPackage else (pkgs.dynamic-you or (pkgs.callPackage ./package.nix { }));
      defaultText = lib.literalExpression "inputs.dynamic-you.packages.\${pkgs.system}.default";
      description = "The dynamic-you package to use.";
    };

    installFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install required fonts (Material Symbols, Inter, Noto Fonts, JetBrains Mono Nerd Font).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    fonts.packages = lib.mkIf cfg.installFonts (
      [
        pkgs.inter
        pkgs.material-symbols
        pkgs.noto-fonts
        pkgs.noto-fonts-color-emoji
      ]
      ++ lib.optional (pkgs ? nerd-fonts && pkgs.nerd-fonts ? jetbrains-mono) pkgs.nerd-fonts.jetbrains-mono
      ++ lib.optional (!(pkgs ? nerd-fonts && pkgs.nerd-fonts ? jetbrains-mono) && pkgs ? nerdfonts) (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    );
  };
}