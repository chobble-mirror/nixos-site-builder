{
  description = "NixOS static site builder and server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b?narHash=sha256-l0KFg5HjrsfsO/JpG%2Br7fRrqm12kzFHyUHqHCVpMMbI%3D";
    caddy.url = "github:vincentbernat/caddy-nix/9d13eb684b4ba1b2eb92e76f7ea1f517eccc4fe1?narHash=sha256-kUWyjeqkU%2BRHTHVXT61QF19eW2vnWgah5OcPrUlU8oU%3D";

  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      caddy,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkCustomCaddy =
        pkgs:
        (pkgs.extend caddy.overlays.default).caddy.withPlugins {
          plugins = [ "github.com/caddyserver/transform-encoder" ];
          hash = "sha256-9kgxIpIwC5asZ0PV8P6LO8HHVa3udHMSNNI/zV3lmAM=";
        };
    in
    {
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          imports = [ (import ./modules/site-builder.nix) ];
          _module.args.customCaddy = mkCustomCaddy pkgs;
        };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          utils = import ./lib/utils.nix;
        in
        import ./tests {
          inherit pkgs utils;
          customCaddy = mkCustomCaddy pkgs;
        }
      );

      # Convenience apps for running specific test suites
      apps = forAllSystems (system: {
        test-unit = {
          type = "app";
          program =
            (import ./tests/unit {
              pkgs = nixpkgs.legacyPackages.${system};
              lib = nixpkgs.lib;
            }).program;
        };
        test-integration = {
          type = "app";
          program =
            (import ./tests/integration {
              pkgs = nixpkgs.legacyPackages.${system};
              lib = nixpkgs.lib;
            }).program;
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              shellcheck
            ];
          };
        }
      );
    };
}
