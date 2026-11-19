# Check `clippy` for each workspace of the cargo-workspaces module, tagged
# `lint`, `nightly` and `quick`. Runs `cargo clippy --all-targets
# --all-features` with the nightly toolchain, on the workspace's dependency
# artifacts of the dev profile.
#
# `cargoClippy.denyLints` lists the lints passed to clippy as `-D <lint>`.
# Definitions append to the default `warnings` and `unused`:
#
#   perSystem.cargoClippy.denyLints = [ "clippy::allow_attributes" ];
#
# `cargoClippy.eachFeature = true` uses cargo-hack to check no features,
# defaults, each feature individually (including implicit optional dependencies),
# and all features. It does not enumerate
# every possible feature combination (see concurrent-psbt PR #119).
{ localFlakeModules, ... }:
{ ... }:
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    {
      config,
      lib,
      toolchains,
      pkgs,
      ...
    }:
    {
      options.cargoClippy.eachFeature = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run Clippy with cargo-hack's --each-feature instead of only --all-features.";
      };

      options.cargoClippy.denyLints = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Lints to deny, in addition to the default `warnings` and `unused`.";
      };

      config = {
        cargoClippy.denyLints = lib.mkBefore [
          "warnings"
          "unused"
        ];

        cargoChecks.clippy = {
          tags = [
            "lint"
            "nightly"
            "quick"
          ];
          package =
            workspace:
            let
              lints = lib.concatMapStringsSep " " (
                lint: "-D ${lib.escapeShellArg lint}"
              ) config.cargoClippy.denyLints;
            in
            if config.cargoClippy.eachFeature then
              toolchains.nightly.mkCargoDerivation (
                workspace.checkArgs
                // {
                  cargoArtifacts = workspace.cargoArtifacts.nightly.dev;
                  pnameSuffix = "-clippy";
                  nativeBuildInputs = workspace.checkArgs.nativeBuildInputs ++ [ pkgs.cargo-hack ];
                  # cargoWithProfile would place --profile between hack and clippy.
                  buildPhaseCargoCommand = ''
                    cargo hack clippy ${workspace.commonArgs.cargoExtraArgs} --each-feature --optional-deps --all-targets -- ${lints}
                  '';
                  installPhase = "mkdir -p $out";
                }
              )
            else
              toolchains.nightly.cargoClippy (
                workspace.checkArgs
                // {
                  cargoArtifacts = workspace.cargoArtifacts.nightly.dev;
                  cargoClippyExtraArgs = "--all-targets --all-features -- ${lints}";
                }
              );
        };
      };
    };
}
