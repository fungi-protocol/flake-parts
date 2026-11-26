# Configures the fixture as the only Cargo workspace, for the cargo-* check
# modules, and tests the cargoChecks extension point with a check of its own.
{ ... }:
{
  perSystem =
    {
      lib,
      fixture,
      toolchains,
      ...
    }:
    let
      separate = fixture.evalPerSystem {
        allFlakeModules = false;
        self.outPath = ./fixtures;
        modules = [
          fixture.flakeModules.cargo-workspaces
          {
            perSystem = { toolchains, ... }: {
              cargoWorkspaces = {
                root.manifestPath = "Cargo.toml";
                nested.manifestPath = "nested/Cargo.toml";
              };
              cargoChecks.build.package =
                workspace:
                toolchains.nightly.buildPackage (
                  workspace.checkArgs
                  // {
                    cargoArtifacts = workspace.cargoArtifacts.nightly.dev;
                    CARGO_PROFILE = "dev";
                    doCheck = false;
                  }
                );
            };
          }
        ];
      };
    in
    {
      checks = {
        cargo-workspaces-build-root = separate.checks.root-build;
        cargo-workspaces-build-nested = separate.checks.nested-build;
      };

      cargoWorkspaces.fixture = {
        manifestPath = "Cargo.toml";
        # A single workspace: checks are named clippy, doc, ... as in a
        # repository that has one.
        checkPrefix = "";
      };

      # A check registered like the cargo-* modules do. It runs in the
      # workspace directory with the workspace's vendored dependencies, and
      # fails unless Cargo sees both members of the fixture workspace through
      # the manifest the module passes on.
      cargoChecks.workspace-members.package =
        workspace:
        toolchains.nightly.mkCargoDerivation (
          workspace.checkArgs
          // {
            cargoArtifacts = workspace.cargoArtifacts.nightly.dev;
            CARGO_PROFILE = "dev";
            pnameSuffix = "-workspace-members";
            buildPhaseCargoCommand = ''
              cargo metadata --locked --offline --no-deps --format-version 1 \
                --manifest-path ${lib.escapeShellArg workspace.cargoManifestPath} \
                >metadata.json
              for member in fixture-app fixture-base; do
                grep -q "\"name\":\"$member\"" metadata.json
              done
            '';
            installPhase = "mkdir -p $out";
          }
        );
    };
}
