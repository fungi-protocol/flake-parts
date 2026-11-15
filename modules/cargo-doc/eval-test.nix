# Documentation reuses the dependency build for its toolchain and profile.
{ perSystem, ... }:
{
  testReusesDevArtifacts = {
    expr = {
      artifacts =
        perSystem.checks.doc.cargoArtifacts.drvPath
        == perSystem.cargoWorkspaces.fixture.cargoArtifacts.nightly.dev.drvPath;
      profile = perSystem.checks.doc.CARGO_PROFILE;
    };
    expected = {
      artifacts = true;
      profile = "dev";
    };
  };
}
