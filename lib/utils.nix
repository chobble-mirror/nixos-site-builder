let shortHash = str: builtins.substring 0 8 (builtins.hashString "sha256" str);
in {
  inherit shortHash;
  mkServiceName = hash: "site-${shortHash hash}-builder";
}
