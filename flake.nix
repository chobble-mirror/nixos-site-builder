{
  description = "NixOS static site builder and server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    jekyll-builder.url =
      "git+https://git.chobble.com/chobble/nix-jekyll-builder";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, jekyll-builder }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      nixosModules.default = import ./modules/site-builder.nix;

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          utils = import ./lib/utils.nix;
        in import ./tests { inherit pkgs utils; });

      # Convenience apps for running specific test suites
      apps = forAllSystems (system: {
        test-unit = {
          type = "app";
          program = (import ./tests/unit {
            pkgs = nixpkgs.legacyPackages.${system};
            lib = nixpkgs.lib;
          }).program;
        };
        test-integration = {
          type = "app";
          program = (import ./tests/integration {
            pkgs = nixpkgs.legacyPackages.${system};
            lib = nixpkgs.lib;
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
