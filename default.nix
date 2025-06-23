{pkgs ? import <nixpkgs> {}}: {
  nzbToMedia = pkgs.callPackage ./release.nix {};
}
