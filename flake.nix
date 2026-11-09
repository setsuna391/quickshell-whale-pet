{
  description = "DSH desktop pet for Wayland";

  inputs.nixpkgs.url = "tarball+https://codeload.github.com/NixOS/nixpkgs/tar.gz/f4a03c008967841f2a0b3cb7c436fc6fc31671f6";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      overlays.default = final: prev: {
        dsh-pet = final.callPackage ./package.nix { };
      };
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in rec {
          dsh-pet = pkgs.callPackage ./package.nix { };
          default = dsh-pet;
        });
    };
}
