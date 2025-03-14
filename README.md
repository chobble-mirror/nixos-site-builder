# ⚠️ NOTE: This is unmaintained - I'm not using Forgejo actions to build and push sites instead, it's much simpler! ⚠️

# NixOS Static Site Builder

This flake grabs and builds static sites (maybe via a `default.nix`) and copies their outputs to `/var/www`

You can import it into your `flake.nix` like:

```
inputs = {
  site-builder = {
    url = "git+https://git.chobble.com/chobble/nixos-site-builder";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

and then add it as a module to your server's host, like:

```
({ config, ... }: {
  imports = [ site-builder.nixosModules.default ];
  services.site-builder = {
    enable = true;
    sites = {
      "chobble.com" = {
        gitRepo = "http://localhost:3000/chobble/chobble";
        wwwRedirect = true;
      };
      "veganprestwich.co.uk" = {
        gitRepo = "http://localhost:3000/chobble/vegan-prestwich";
        wwwRedirect = true;
      };
    };
  };
})
```

My Git repos in this example are hosted on localhost by my Forgejo instance but yours can be wherever.

- [Here's a default.nix for a Jekyll site](https://git.chobble.com/chobble/chobble/src/branch/main/default.nix)
- [And here's a default.nix for an Eleventy site](https://git.chobble.com/chobble/vegan-prestwich/src/branch/main/default.nix)
