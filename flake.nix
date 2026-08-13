{
  description = "Nix packaging for dtctl, the Dynatrace platform CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Exactly the systems upstream publishes release binaries for.
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      overlays.default = final: _prev: {
        dtctl = final.callPackage ./pkgs/dtctl.nix { };
      };

      packages = forAllSystems (pkgs: rec {
        dtctl = pkgs.callPackage ./pkgs/dtctl.nix { };
        default = dtctl;
      });

      # `nix flake check` builds the package and runs `dtctl version`,
      # asserting the reported version matches sources.json.
      checks = forAllSystems (pkgs: {
        dtctl = self.packages.${pkgs.stdenv.hostPlatform.system}.dtctl;
        version = self.packages.${pkgs.stdenv.hostPlatform.system}.dtctl.passthru.tests.version;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
