{
  description = "NixOS static site builder and server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      jekyllLib = import ./lib/jekyll-builder;
    in {
      lib = forAllSystems (system: {
        mkJekyllSite = jekyllLib { pkgs = nixpkgs.legacyPackages.${system}; }.mkJekyllSite;
      });

      nixosModules.default = { config, lib, pkgs, ... }: {
        imports = [ ./modules/site-builder.nix ];
        _module.args = { };
      };

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          utils = import ./lib/utils.nix;
          lib = pkgs.lib;
        in import ./tests { inherit pkgs lib utils; });

      # Convenience apps for running specific test suites
      apps = forAllSystems (system: {
        test-unit = {
          type = "app";
          program = (import ./tests/unit {
            pkgs = nixpkgs.legacyPackages.${system};
            lib = nixpkgs.lib;
            utils = import ./lib/utils.nix;
          }).program;
        };
        test-integration = {
          type = "app";
          program = (import ./tests/integration {
            pkgs = nixpkgs.legacyPackages.${system};
            lib = nixpkgs.lib;
            utils = import ./lib/utils.nix;
          }).program;
        };
      });

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ nixpkgs-fmt shellcheck ];
          };
        });
    };
}
