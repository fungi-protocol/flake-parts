# Test harness. Builds a second flake over tests/fixture, a small Rust
# workspace on which every check passes, that imports every flake module and
# each modules/NAME/test.nix and packages/NAME/test.nix, and exposes its
# checks here as `fixture-<name>`.
#
# A test.nix is a flake-parts module. Its perSystem receives `fixture`
# (helpers below) for expected-failure tests: patch the fixture and assert
# the check fails with a given exit code and log message.
#
# modules/NAME/eval-test.nix, packages/NAME/eval-test.nix and
# tests/eval-test.nix return `{ testNAME = { expr; expected; }; }` and run by
# evaluation alone, one `eval-tests-<part>` check per part. `expr` is forced
# with deepSeq, so compare plain data, not derivations. A test that throws,
# or whose name doesn't start with `test`, fails.
#
# A module that defines checks only once configured, such as one Cargo
# workspace, gives that configuration in modules/NAME/test-config.nix, a
# flake-parts module, so that the tests of each module imported alone check
# something.
#
# The fixture must not import from derivation, so tests never evaluate a
# patched flake.
{
  config,
  inputs,
  lib,
  ...
}:
let
  # Retain the path's source accessor during evaluation (including lazy
  # flake inputs). Coercion into a derivation copies only this directory.
  fixtureSelf = {
    outPath = ./fixture;
  };

  partFiles = import ./part-files.nix {
    inherit lib;
    roots = {
      modules = ../modules;
      packages = ../packages;
    };
  };

  # modules/NAME/test.nix and packages/NAME/test.nix
  testModuleFiles = lib.attrValues (partFiles "test.nix");

  # modules/NAME/test-config.nix: the minimal configuration with which
  # module NAME defines its checks when it is imported alone.
  testConfig =
    name:
    let
      path = ../modules + "/${name}/test-config.nix";
    in
    lib.optional (builtins.pathExists path) path;

  evalTestFiles = partFiles "eval-test.nix" // {
    harness = ./eval-test.nix;
  };

  # Provides the perSystem argument `fixture` to test modules.
  fixtureArgs =
    { self, ... }:
    {
      perSystem =
        { pkgs, system, ... }:
        {
          _module.args.fixture = rec {
            # The fixture source path.
            src = self.outPath;

            # `src` with git-diff style patches (paths relative to the
            # fixture root) applied with `patch -p1`.
            patched =
              patches:
              pkgs.applyPatches {
                name = "fixture-patched";
                inherit src patches;
              };

            # A check that passes when building `drv` fails with `exitCode`
            # and its log contains each of `logEntries`.
            expectFailure =
              {
                drv,
                exitCode ? 1,
                logEntries ? [ ],
              }:
              pkgs.testers.testBuildFailure' {
                inherit drv;
                expectedBuilderExitCode = exitCode;
                expectedBuilderLogEntries = logEntries;
              };

            # `expectFailure` for `check` run on `patched patches`. Only for a
            # check that takes its source from `src`; other checks override
            # their source themselves and call `expectFailure`.
            rejects =
              {
                check,
                patches,
                exitCode ? 1,
                logEntries ? [ ],
              }:
              expectFailure {
                drv = check.overrideAttrs { src = patched patches; };
                inherit exitCode logEntries;
              };

            # This flake's packages and modules, and `evalFlake` (below)
            # narrowed to this system, for testing a separate consumer.
            packages = config.allSystems.${system}.packages;
            flakeModules = config.flake.flakeModules;
            evalPerSystem = args: (evalFlake args).allSystems.${system};
          };
        };
    };

  # Outputs of another flake over the fixture (or `self`, a path or an
  # attribute set with `outPath`). It imports `modules`, every flake module
  # unless `allFlakeModules = false`, and the test modules if `testModules`.
  evalFlake =
    {
      modules ? [ ],
      self ? fixtureSelf,
      allFlakeModules ? true,
      testModules ? false,
    }:
    inputs.flake-parts.lib.mkFlake
      {
        inputs = inputs // {
          # A flake's `self` has its inputs, which flake-parts reads for
          # `inputs'` and its default `pkgs`.
          self = (if builtins.isAttrs self then self else { outPath = self; }) // {
            inherit inputs;
          };
        };
      }
      {
        inherit (config) systems;
        debug = true;
        imports =
          lib.optionals allFlakeModules (lib.attrValues config.flake.flakeModules)
          ++ lib.optionals testModules ([ fixtureArgs ] ++ testModuleFiles)
          ++ modules;
      };

  fixtureFlake = evalFlake { testModules = true; };

  # Like lib.debug.runTests, but a test that throws fails with its name
  # instead of aborting, and a misnamed test fails instead of being ignored.
  runEvalTests =
    tests:
    lib.concatLists (
      lib.mapAttrsToList (
        name: test:
        let
          result = builtins.tryEval (builtins.deepSeq test.expr test.expr);
          failure = actual: [
            {
              inherit name;
              expected = test.expected or null;
              result = actual;
            }
          ];
        in
        if !lib.hasPrefix "test" name then
          failure "<not a test: the name must start with 'test'>"
        else if !result.success then
          failure "<throws>"
        else
          lib.optionals (result.value != test.expected) (failure result.value)
      ) tests
    );

  evalTests =
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      # The arguments of every eval-test.nix.
      args = {
        inherit
          lib
          pkgs
          system
          inputs
          ;
        inherit (config.flake) flakeModules;
        src = fixtureSelf.outPath;
        # The fixture flake's perSystem config, e.g. `perSystem.checks`.
        perSystem = fixtureFlake.allSystems.${system};
        inherit evalFlake;
        evalPerSystem = args: (evalFlake args).allSystems.${system};
        packages = config.allSystems.${system}.packages;
        inherit runEvalTests;
        # Catches `throw` and failed assertions, not every error; it only
        # forces `expr` to its outermost value, so deepSeq deeper ones.
        throws = expr: !(builtins.tryEval expr).success;
        inherit testConfig;
      };
    in
    lib.mapAttrs (_: file: import file args) evalTestFiles;
in
{
  flake.tests = lib.genAttrs config.systems evalTests;

  perSystem =
    { pkgs, system, ... }:
    {
      checks =
        lib.mapAttrs' (name: check: lib.nameValuePair "fixture-${name}" check) (
          fixtureFlake.checks.${system} or { }
        )
        // lib.mapAttrs' (
          part: tests:
          let
            failures = runEvalTests tests;
          in
          lib.nameValuePair "eval-tests-${part}" (
            if failures == [ ] then
              pkgs.runCommand "eval-tests-${part}" { } "touch $out"
            else
              throw "eval-tests-${part}: ${toString (builtins.length failures)} failing test(s):\n${
                lib.generators.toPretty { } failures
              }"
          )
        ) config.flake.tests.${system};
    };
}
