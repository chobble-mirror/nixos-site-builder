{ pkgs ? import <nixpkgs> { }, name }:

let
  env = pkgs.bundlerEnv {
    ruby = pkgs.ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in pkgs.stdenv.mkDerivation {
  inherit name;
  src = ./.;

  nativeBuildInputs = [ env pkgs.ruby ];

  buildPhase = ''
    JEKYLL_ENV=production jekyll build --source . --destination _site --trace
  '';
}
