{ pkgs }:
let
  env = pkgs.bundlerEnv {
    name = "jekyll-site-env"; # Add name to bundlerEnv
    ruby = pkgs.ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in pkgs.stdenv.mkDerivation {
  name = "jekyll-site";
  src = ./.;
  nativeBuildInputs = [ env pkgs.ruby ];
  buildPhase = ''
    echo 'Building Jekyll site'
    JEKYLL_ENV=production jekyll build --offline --source . --destination _site --trace
  '';
  installPhase = ''
    mkdir -p $out
    cp -r _site/* $out/
  '';
}
