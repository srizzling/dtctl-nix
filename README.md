# dtctl-nix

Nix packaging for [dtctl](https://github.com/dynatrace-oss/dtctl), the Dynatrace
platform CLI.

`dtctl` is not in nixpkgs. This flake packages the official release binaries and
tracks upstream automatically, so a new dtctl release lands here within a day
without anyone recomputing hashes by hand.

Community maintained, and not affiliated with or endorsed by Dynatrace.

## Use it

Run it without installing:

```bash
nix run github:srizzling/dtctl-nix -- version
```

Add it to a flake:

```nix
{
  inputs.dtctl-nix.url = "github:srizzling/dtctl-nix";

  outputs = { nixpkgs, dtctl-nix, ... }: {
    # as a package
    # dtctl-nix.packages.${system}.dtctl

    # or through the overlay
    # nixpkgs.overlays = [ dtctl-nix.overlays.default ];  ->  pkgs.dtctl
  };
}
```

Add it to a [devenv](https://devenv.sh) project — `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  dtctl-nix:
    url: github:srizzling/dtctl-nix
```

`devenv.nix`:

```nix
{ pkgs, inputs, ... }:

{
  packages = [
    inputs.dtctl-nix.packages.${pkgs.stdenv.hostPlatform.system}.dtctl
  ];
}
```

Bash, zsh and fish completions are installed alongside the binary and are picked
up automatically by both nix-darwin/home-manager and devenv.

## Supported systems

`aarch64-darwin`, `aarch64-linux`, `x86_64-linux`. Every release is built on all
three in CI before it is merged.

### Intel macOS

Upstream ships an `x86_64-darwin` binary and this package still knows how to
install it, but the flake does not expose it, because **nixpkgs 26.11 dropped
`x86_64-darwin` support entirely** — these outputs cannot even evaluate for it
against the unstable input tracked here.

If you are on an Intel Mac, use the overlay on top of a nixpkgs that still
supports it (`nixpkgs-26.05-darwin`, security fixes until the end of 2026):

```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
nixpkgs.overlays = [ dtctl-nix.overlays.default ];  # -> pkgs.dtctl
```

`sources.json` keeps the `x86_64-darwin` hash up to date for exactly this
reason, and `update.sh` still repins it — it is simply not built in CI.

## How updating works

`update.sh` reads the latest release tag and pulls all four hashes out of the
release's own `checksums.txt`, so it never downloads a tarball or runs
`nix-prefetch`:

```
releases/latest  ->  v0.37.0
checksums.txt    ->  four sha256, one 1 KB request
sources.json     ->  rewritten
```

A daily workflow runs it, builds the result on all four systems, and only then
opens a pull request and merges it. The build happens in the same workflow run
rather than as a check on the PR, because pull requests opened with
`GITHUB_TOKEN` do not trigger further workflow runs — doing it this way needs no
personal access token and no branch protection, while still gating the merge on
a real build.

To bump manually:

```bash
./update.sh          # or `update` inside the devenv shell
nix flake check      # or `check`
```

## This package uses the release binary

It installs upstream's prebuilt, signed binary rather than building from source
(`sourceProvenance = binaryNativeCode`). That keeps the Darwin code signature
intact and avoids vendoring Go dependencies. `dontStrip` is set for the same
reason: stripping would invalidate the signature.

## Development

```bash
direnv allow    # devenv provides gh, jq, nixfmt
update          # repin sources.json
check           # nix flake check
```

## Licence

The packaging in this repository is MIT. `dtctl` itself is Apache-2.0 and
remains the property of its authors.
