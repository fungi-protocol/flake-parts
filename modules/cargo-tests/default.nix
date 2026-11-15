# Checks `tests-<toolchain>-<profile>` and `doctests-<toolchain>-<profile>` for
# each workspace of the cargo-workspaces module and each toolchain of the
# rust-toolchains module in the dev and release profiles, tagged `nightly`. The
# nightly dev checks are also tagged `quick`.
#
# The tests run under nextest, which records each run; the check exports the
# record as nextest-run.zip. Doctests run under `cargo test --doc`, which
# nextest does not support.
{ localFlakeModules, ... }:
{ ... }:
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    {
      lib,
      pkgs,
      toolchains,
      ...
    }:
    let
      mkTest =
        workspace: craneLib: profile: cargoArtifacts:
        craneLib.cargoNextest (
          workspace.checkArgs
          // {
            inherit cargoArtifacts;
            CARGO_PROFILE = profile;
            cargoNextestExtraArgs = "--no-tests=pass --user-config-file ${./nextest-record.toml}";
            nativeBuildInputs = workspace.checkArgs.nativeBuildInputs ++ [ pkgs.unzip ];
            preCheck = ''
              export NEXTEST_STATE_DIR="$TMPDIR/nextest-state"
              mkdir -p "$NEXTEST_STATE_DIR"
            '';
            postCheck = ''
              cargo nextest store export \
                --no-pager \
                --user-config-file ${./nextest-record.toml} \
                --archive-file "$out/nextest-run.zip" \
                latest
              unzip -tqq "$out/nextest-run.zip"
            '';
          }
        );

      # nextest does not run doctests; cargo test --doc does.
      mkDocTest =
        workspace: craneLib: profile: cargoArtifacts:
        craneLib.mkCargoDerivation (
          workspace.checkArgs
          // {
            inherit cargoArtifacts;
            CARGO_PROFILE = profile;
            pnameSuffix = "-doctest";
            doCheck = true;
            nativeBuildInputs = workspace.checkArgs.nativeBuildInputs ++ [ pkgs.jq ];
            buildPhaseCargoCommand = "";
            checkPhaseCargoCommand = ''
              # Cargo rejects --doc without a Rust-linkable library or proc macro.
              cargo metadata --locked --no-deps --format-version 1 \
                --manifest-path ${lib.escapeShellArg workspace.cargoManifestPath} > cargo-metadata.json
              hasLibraries=$(jq -r '
                any(.packages[].targets[].kind[];
                  IN("lib", "rlib", "proc-macro"))
              ' cargo-metadata.json)
              if [[ $hasLibraries == true ]]; then
                cargoWithProfile test --doc ${workspace.commonArgs.cargoExtraArgs}
              fi
            '';
          }
        );
    in
    {
      cargoChecks = lib.mergeAttrsList (
        lib.concatMap
          (
            profile:
            lib.mapAttrsToList (
              toolchainName: craneLib:
              let
                tags = [
                  "nightly"
                ]
                ++ lib.optional (toolchainName == "nightly" && profile == "dev") "quick";
                cargoArtifacts = workspace: workspace.cargoArtifacts.${toolchainName}.${profile};
              in
              {
                "tests-${toolchainName}-${profile}" = {
                  inherit tags;
                  package = workspace: mkTest workspace craneLib profile (cargoArtifacts workspace);
                };
                "doctests-${toolchainName}-${profile}" = {
                  inherit tags;
                  package = workspace: mkDocTest workspace craneLib profile (cargoArtifacts workspace);
                };
              }
            ) toolchains
          )
          [
            "dev"
            "release"
          ]
      );
    };
}
