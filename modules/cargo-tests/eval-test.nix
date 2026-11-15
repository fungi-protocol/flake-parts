# Evaluation tests of the cargo-tests module (see tests/default.nix).
{
  lib,
  pkgs,
  perSystem,
  evalPerSystem,
  flakeModules,
  ...
}:
let
  checks = perSystem.checks;
  workspace = perSystem.cargoWorkspaces.fixture;
  toString' = x: builtins.unsafeDiscardStringContext (toString x);

  toolchains = [
    "beta"
    "nightly"
    "stable"
  ];
  profiles = [
    "dev"
    "release"
  ];
  combinations = lib.cartesianProduct {
    toolchain = toolchains;
    profile = profiles;
  };
  idOf = kind: c: "${kind}-${c.toolchain}-${c.profile}";
in
{
  testPreservesNativeBuildTools = {
    expr =
      let
        configured = evalPerSystem {
          allFlakeModules = false;
          modules = [
            flakeModules.cargo-tests
            { perSystem.cargoWorkspaces.w.nativeBuildInputs = [ pkgs.pkg-config ]; }
          ];
        };
      in
      builtins.elem pkgs.pkg-config configured.checks.w-tests-nightly-dev.nativeBuildInputs;
    expected = true;
  };

  # All of them are nightly; the nightly dev ones are quick as well; none is
  # a lint.
  testTags = {
    expr = lib.genAttrs (map (idOf "tests") combinations ++ map (idOf "doctests") combinations) (
      id: perSystem.checkTags.${id}
    );
    expected = lib.genAttrs (map (idOf "tests") combinations ++ map (idOf "doctests") combinations) (
      id: [ "nightly" ] ++ lib.optional (lib.hasSuffix "-nightly-dev" id) "quick"
    );
  };

  # Each check starts from the dependency artifacts of its toolchain and
  # profile, which it also builds in.
  testArtifactsAndProfile = {
    expr = lib.genAttrs (map (idOf "tests") combinations ++ map (idOf "doctests") combinations) (
      id:
      let
        c = lib.findFirst (c: idOf "tests" c == id || idOf "doctests" c == id) null combinations;
      in
      {
        profile = checks.${id}.CARGO_PROFILE == c.profile;
        artifacts =
          toString' checks.${id}.cargoArtifacts
          == toString' workspace.cargoArtifacts.${c.toolchain}.${c.profile};
      }
    );
    expected =
      lib.genAttrs (map (idOf "tests") combinations ++ map (idOf "doctests") combinations)
        (_: {
          profile = true;
          artifacts = true;
        });
  };
}
