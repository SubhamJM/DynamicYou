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

    systemd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable a systemd user service to launch QuickShell with the graphical session.";
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = "Systemd target to bind the DynamicYou service to.";
      };
    };

    linkConfigs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to declaratively symlink DynamicYou configs (~/.config/quickshell, themes, scripts)
        into your user configuration.
        Note: If set to false, you can also use `dynamic-you setup-dotfiles` at any time for mutable dotfiles.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.dynamic-you = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "DynamicYou QuickShell Service";
        PartOf = [ cfg.systemd.target ];
        After = [ cfg.systemd.target ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/dynamic-you daemon";
        Restart = "on-failure";
        RestartSec = 1;
      };

      Install = {
        WantedBy = [ cfg.systemd.target ];
      };
    };

    xdg.configFile = lib.mkIf cfg.linkConfigs {
      "quickshell".source = "${cfg.package}/share/dynamic-you/quickshell";
      "themes".source = "${cfg.package}/share/dynamic-you/themes";
      "scripts".source = "${cfg.package}/share/dynamic-you/scripts";
    };
  };
}