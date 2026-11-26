# Evaluation tests of the cargo-clippy module (see tests/default.nix).
{
  lib,
  pkgs,
  evalPerSystem,
  flakeModules,
  ...
}:
let

  withLints =
    definitions:
    evalPerSystem {
      modules = [
        { perSystem.cargoWorkspaces.w.manifestPath = "Cargo.toml"; }
      ]
      ++ map (denyLints: { perSystem.cargoClippy = { inherit denyLints; }; }) definitions;
    };
in
{
  testDefaultReusesDevArtifacts = {
    expr =
      let
        config = withLints [ ];
      in
      {
        artifacts =
          config.checks.w-clippy.cargoArtifacts.drvPath
          == config.cargoWorkspaces.w.cargoArtifacts.nightly.dev.drvPath;
        profile = config.checks.w-clippy.CARGO_PROFILE;
      };
    expected = {
      artifacts = true;
      profile = "";
    };
  };

  testEachFeatureComposition = {
    expr =
      let
        configured = evalPerSystem {
          allFlakeModules = false;
          modules = [
            flakeModules.cargo-clippy
            {
              perSystem = {
                cargoWorkspaces.w = {
                  manifestPath = "Cargo.toml";
                  nativeBuildInputs = [ pkgs.pkg-config ];
                };
                cargoClippy.eachFeature = true;
                cargoClippy.denyLints = [ "clippy::dbg_macro" ];
              };
            }
          ];
        };
        check = configured.checks.w-clippy;
      in
      {
        command = lib.hasInfix "cargo hack clippy --locked --manifest-path Cargo.toml --workspace --each-feature --optional-deps --all-targets -- -D warnings -D unused -D clippy::dbg_macro" check.buildPhase;
        tools =
          builtins.elem pkgs.pkg-config check.nativeBuildInputs
          && builtins.elem pkgs.cargo-hack check.nativeBuildInputs;
        artifacts =
          check.cargoArtifacts.drvPath == configured.cargoWorkspaces.w.cargoArtifacts.nightly.dev.drvPath;
      };
    expected = {
      command = true;
      tools = true;
      artifacts = true;
    };
  };

  testConsumerLintsAppend = {
    expr = (withLints [ [ "clippy::allow_attributes" ] ]).cargoClippy.denyLints;
    expected = [
      "warnings"
      "unused"
      "clippy::allow_attributes"
    ];
  };

  testLintsOfSeveralDefinitionsAppend = {
    expr = lib.sort lib.lessThan (
      (withLints [
        [ "clippy::allow_attributes" ]
        [ "clippy::dbg_macro" ]
      ]).cargoClippy.denyLints
    );
    expected = [
      "clippy::allow_attributes"
      "clippy::dbg_macro"
      "unused"
      "warnings"
    ];
  };
}
