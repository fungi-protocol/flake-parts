# Evaluation tests of the cargo-build module (see tests/default.nix).
{
  lib,
  evalPerSystem,
  ...
}:
let
  toString' = x: builtins.unsafeDiscardStringContext (toString x);

  withProfile =
    profile:
    evalPerSystem {
      modules = [
        {
          perSystem = {
            cargoWorkspaces.w.manifestPath = "Cargo.toml";
            cargoBuild.profile = profile;
          };
        }
      ];
    };
  dev = evalPerSystem { modules = [ { perSystem.cargoWorkspaces.w.manifestPath = "Cargo.toml"; } ]; };
  release = withProfile "release";
  artifacts = flake: profile: toString' flake.cargoWorkspaces.w.cargoArtifacts.nightly.${profile};
in
{
  testBuildDoesNotRunTests = {
    expr = map (config: config.checks.w-build.doCheck) [
      dev
      release
    ];
    expected = [
      false
      false
    ];
  };

  # The default is the dev profile.
  testDefaultProfile = {
    expr = {
      option = dev.cargoBuild.profile;
      cargoProfile = dev.checks.w-build.CARGO_PROFILE;
      artifacts = toString' dev.checks.w-build.cargoArtifacts == artifacts dev "dev";
      release = lib.hasInfix "--release" dev.checks.w-build.buildPhase;
    };
    expected = {
      option = "dev";
      cargoProfile = "";
      artifacts = true;
      release = false;
    };
  };

  # The release profile builds in release, from the release artifacts.
  testReleaseProfile = {
    expr = {
      cargoProfile = release.checks.w-build.CARGO_PROFILE;
      artifacts = toString' release.checks.w-build.cargoArtifacts == artifacts release "release";
      differs = release.checks.w-build.drvPath != dev.checks.w-build.drvPath;
      depsProfile = release.checks.w-build.cargoArtifacts.CARGO_PROFILE;
    };
    expected = {
      cargoProfile = "release";
      artifacts = true;
      differs = true;
      depsProfile = "release";
    };
  };
}
