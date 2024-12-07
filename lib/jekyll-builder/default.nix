{ pkgs }:

{
  mkJekyllSite = { pname, version ? "1.0.0", src, gemset ? ./gemset.nix
    , gemfile ? ./Gemfile, lockfile ? ./Gemfile.lock }:
    let
      env = pkgs.bundlerEnv {
        name = pname;
        inherit (pkgs) ruby;
        inherit gemfile lockfile gemset;
      };
    in pkgs.stdenv.mkDerivation {
      inherit pname version src;
      nativeBuildInputs = with pkgs; [ ruby_3_3 minify ];
      configurePhase = ''
        export HOME=$TMPDIR
        mkdir -p _site
      '';
      buildPhase = ''
        echo "Building site with Jekyll..."
        JEKYLL_ENV=production ${env}/bin/jekyll build --source . --destination _site --trace
        echo 'Minifying HTML'
        minify --all --recursive --output . _site
      '';
      installPhase = ''
        mkdir -p $out
        cp -r _site/* $out/
      '';
    };
}
