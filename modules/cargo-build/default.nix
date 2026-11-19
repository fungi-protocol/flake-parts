# Check `build` for each workspace of the cargo-workspaces module, tagged
# `nightly`. Builds the workspace with the nightly toolchain and without
# running tests, which the cargo-tests module does.
#
# `cargoBuild.profile` selects the profile the workspace is built in, `dev` or
# `release`, starting from the dependency artifacts of that profile. The
# default is arbitrary.
{ localFlakeModules, ... }:
{ ... }:
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    {
      config,
      lib,
      toolchains,
      ...
    }:
    {
      options.cargoBuild.profile = lib.mkOption {
        type = lib.types.enum [
          "dev"
          "release"
        ];
        default = "dev";
        description = "Profile to build in, with the dependency artifacts of the same profile.";
      };

      config.cargoChecks.build = {
        tags = [ "nightly" ];
        package =
          workspace:
          toolchains.nightly.buildPackage (
            workspace.checkArgs
            // {
              cargoArtifacts = workspace.cargoArtifacts.nightly.${config.cargoBuild.profile};
              # `checkArgs` leaves the profile empty, which crane builds in the
              # dev profile. Release must be named, so that the build uses the
              # profile of its artifacts.
              CARGO_PROFILE = lib.optionalString (config.cargoBuild.profile == "release") "release";
              # The tests-* checks run the test suite under nextest.
              doCheck = false;
            }
          );
      };
    };
}
