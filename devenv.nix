{ pkgs, ... }:

{
  # Note: flake.nix here exists only to expose package outputs to consumers.
  # It deliberately defines no devShell — this devenv is the dev environment.
  packages = [
    pkgs.git
    pkgs.gh
    pkgs.jq
    pkgs.curl
    pkgs.nixfmt-rfc-style
  ];

  scripts.update.exec = ''
    exec "$DEVENV_ROOT/update.sh" "$@"
  '';

  scripts.check.exec = ''
    nix flake check --print-build-logs "$@"
  '';

  enterShell = ''
    echo "dtctl-nix — pinned at $(jq -r .version "$DEVENV_ROOT/sources.json")"
    echo "  update   repin sources.json to the latest upstream release"
    echo "  check    nix flake check (builds + asserts dtctl version)"
  '';

  enterTest = ''
    nix flake check --print-build-logs
  '';

  git-hooks.hooks = {
    nixfmt-rfc-style.enable = true;
    shellcheck.enable = true;
  };
}
