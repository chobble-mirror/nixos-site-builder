{
  # Create a shortened (8 character) hash of a string
  shortHash = str: builtins.substring 0 8 (builtins.hashString "sha256" str);
}
