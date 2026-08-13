{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  testers,
}:

let
  sources = lib.importJSON ../sources.json;

  inherit (stdenvNoCC.hostPlatform) system;

  asset =
    sources.assets.${system} or (throw "dtctl: upstream publishes no release binary for ${system}");
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dtctl";
  version = sources.version;

  src = fetchurl { inherit (asset) url sha256; };

  # The release tarball is flat: the binary, completions/, LICENSE, README.md.
  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    install -Dm755 dtctl $out/bin/dtctl

    installShellCompletion --cmd dtctl \
      --bash completions/dtctl.bash \
      --fish completions/dtctl.fish \
      --zsh completions/dtctl.zsh

    install -Dm644 LICENSE -t $out/share/doc/dtctl

    runHook postInstall
  '';

  # The upstream binary is already stripped and, on Darwin, signed by
  # goreleaser. Re-stripping invalidates the signature.
  dontStrip = true;

  # finalPackage rather than a `dtctl` callPackage argument: this package is
  # not a member of a nixpkgs package set, so there is nothing to resolve it.
  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "dtctl version";
    version = "dtctl version ${finalAttrs.version}";
  };

  meta = {
    description = "CLI for managing Dynatrace platform resources";
    longDescription = ''
      dtctl is a kubectl-inspired command line interface for the Dynatrace
      platform, covering workflows, dashboards, notebooks, SLOs, settings and
      other resource types through get/describe/apply/delete verbs, plus DQL
      queries. It ships an agent skill so AI coding assistants can drive it.

      This package installs the official prebuilt release binary rather than
      building from source.
    '';
    homepage = "https://github.com/dynatrace-oss/dtctl";
    downloadPage = "https://github.com/dynatrace-oss/dtctl/releases";
    changelog = "https://github.com/dynatrace-oss/dtctl/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "dtctl";
    platforms = lib.attrNames sources.assets;
  };
})
