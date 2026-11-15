# Evaluation tests of the cargo-mutants module (see tests/default.nix).
{
  lib,
  pkgs,
  perSystem,
  evalPerSystem,
  flakeModules,
  throws,
  ...
}:
let

  withWorkspaces =
    cargoWorkspaces: extra:
    evalPerSystem {
      modules = [
        {
          perSystem = {
            inherit cargoWorkspaces;
          }
          // extra;
        }
      ];
    };
  manifest = withWorkspaces { w.manifestPath = "Cargo.toml"; } { };
  incremental = withWorkspaces { w.manifestPath = "Cargo.toml"; } {
    cargoMutants.incremental = true;
  };
in
{
  testReusesDevArtifacts = {
    expr = {
      artifacts =
        manifest.checks.w-mutants.cargoArtifacts.drvPath
        == manifest.cargoWorkspaces.w.cargoArtifacts.nightly.dev.drvPath;
      profile = manifest.checks.w-mutants.CARGO_PROFILE;
    };
    expected = {
      artifacts = true;
      profile = "dev";
    };
  };

  testParallelJobs = {
    expr = {
      automatic = lib.hasInfix "NIX_BUILD_CORES:-1" manifest.checks.w-mutants.buildPhase;
      copies = lib.hasInfix ''--jobs "$jobs" --copy-target=false'' manifest.checks.w-mutants.buildPhase;
      explicit =
        lib.hasInfix "jobs=3"
          (withWorkspaces { w = { }; } { cargoMutants.jobs = 3; }).checks.w-mutants.buildPhase;
      zeroRejected =
        throws
          (withWorkspaces { w = { }; } { cargoMutants.jobs = 0; }).checks.w-mutants.drvPath;
    };
    expected = {
      automatic = true;
      copies = true;
      explicit = true;
      zeroRejected = true;
    };
  };

  testPreservesNativeBuildTools = {
    expr =
      let
        configured = evalPerSystem {
          allFlakeModules = false;
          modules = [
            flakeModules.cargo-mutants
            { perSystem.cargoWorkspaces.w.nativeBuildInputs = [ pkgs.pkg-config ]; }
          ];
        };
      in
      builtins.elem pkgs.pkg-config configured.checks.w-mutants.nativeBuildInputs;
    expected = true;
  };

  # The fixture sets cargoMutants.incremental, and so does concurrent-psbt.
  testIncremental = {
    expr = [
      incremental.cargoMutants.incremental
      incremental.checks.w-mutants.CARGO_BUILD_INCREMENTAL
      perSystem.cargoMutants.incremental
      perSystem.checks.mutants.CARGO_BUILD_INCREMENTAL
    ];
    expected = [
      true
      "true"
      true
      "true"
    ];
  };
}
