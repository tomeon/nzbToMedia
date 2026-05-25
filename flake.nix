{
  description = "Description for the project";

  inputs = {
    flake-compat.url = "github:edolstra/flake-compat";

    flake-compat.flake = false;
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({inputs, ...}: {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        packages = {
          default = config.packages.nzbToMedia;
          nzbToMedia = pkgs.callPackage ./release.nix {};
        };
      };
    });
}
