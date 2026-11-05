{
  description = "Material 3 Expressive × Fluid Wayland Rice powered by QuickShell & Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        packages = rec {
          dynamic-you = pkgs.callPackage ./nix/package.nix { };
          default = dynamic-you;
        };

        apps = rec {
          dynamic-you = flake-utils.lib.mkApp {
            drv = self.packages.${system}.dynamic-you;
            name = "dynamic-you";
          };
          default = dynamic-you;
        };

        devShells.default = pkgs.mkShell {
          name = "dynamic-you-devshell";
          packages = [
            self.packages.${system}.dynamic-you
            pkgs.quickshell
            (pkgs.python3.withPackages (ps: [ ps.dbus-python ps.pillow ]))
            pkgs.awww
            pkgs.hyprland
            pkgs.imagemagick
            pkgs.cava
            pkgs.playerctl
            pkgs.wireplumber
          ];

          shellHook = ''
            echo ":: DynamicYou developer environment active."
            echo ":: Run 'dynamic-you help' to inspect commands."
          '';
        };
      }
    ) // rec {
      overlays = rec {
        dynamic-you = final: prev: {
          dynamic-you = final.callPackage ./nix/package.nix { };
        };
        default = dynamic-you;
      };

      nixosModules = rec {
        dynamic-you = { config, lib, pkgs, ... }@args:
          (import ./nix/nixos-module.nix {
            defaultPackage = self.packages.${pkgs.system}.default or null;
          }) args;
        default = dynamic-you;
      };

      homeManagerModules = rec {
        dynamic-you = { config, lib, pkgs, ... }@args:
          (import ./nix/home-module.nix {
            defaultPackage = self.packages.${pkgs.system}.default or null;
          }) args;
        default = dynamic-you;
      };

      homeModules = homeManagerModules;
    };
}