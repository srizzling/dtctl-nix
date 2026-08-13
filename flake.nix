{
  description = "Nix packaging for dtctl, the Dynatrace platform CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Upstream also ships an x86_64-darwin binary, and pkgs/dtctl.nix still
      # knows how to install it — the overlay works fine on a nixpkgs that
      # supports Intel macOS. It is absent here because nixpkgs 26.11 dropped
      # x86_64-darwin, so these outputs cannot evaluate for it against the
      # unstable input this flake tracks. Only nixpkgs-26.05-darwin still
      # supports it, with security fixes until the end of 2026.
      systems = [
        "aarch64-darwin"
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
