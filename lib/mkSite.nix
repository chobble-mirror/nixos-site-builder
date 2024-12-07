{ pkgs, utils }:

domain: site:

let
  inherit (utils) shortHash mkServiceName;
  jekyllLib = import ./jekyll-builder.nix { inherit pkgs; };
in

if site.builder == "jekyll"
then jekyllLib.mkJekyllSite {
  pname = "${domain}-site";
  src = site.src;
  gemset = site.gemset;
  gemfile = site.gemfile; 
  lockfile = site.lockfile;
}
else if builtins.pathExists "${site.src}/default.nix"
then import site.src
else site.src
