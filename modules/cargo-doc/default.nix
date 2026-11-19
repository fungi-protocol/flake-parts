# Check `doc` for each workspace of the cargo-workspaces module, tagged `lint`
# and `nightly`. Builds the documentation of every workspace member with
# `--no-deps --all-features` and the nightly toolchain, and fails on rustdoc
# warnings.
{ localFlakeModules, ... }:
{ ... }:
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    { toolchains, ... }:
    {
      cargoChecks.doc = {
        tags = [
          "lint"
          "nightly"
        ];
        package =
          workspace:
          toolchains.nightly.cargoDoc (
            workspace.commonArgs
            // {
              cargoArtifacts = workspace.cargoArtifacts.nightly.dev;
              CARGO_PROFILE = "dev";
              cargoDocExtraArgs = "--no-deps --all-features";
              RUSTDOCFLAGS = "-D warnings";
            }
          );
      };
    };
}
