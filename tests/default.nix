# The negative patch harness extends Mshehu5's applyPatches/testBuildFailure'
# tests in https://github.com/fungi-protocol/validate-commits/pull/7.
# Test harness, a flake-parts module imported by this flake. It evaluates a
# second flake-parts flake whose `self` is tests/fixture, a small repository on
# which every check of every module passes, and exposes the checks of that
# flake as `fixture-<name>` in this flake's own `checks`.
#
# The fixture flake imports every flake module of this flake, and the
# `test.nix` next to a module or package, i.e. modules/NAME/test.nix and
# packages/NAME/test.nix, if there is one. A test module is a flake-parts
# module that configures NAME for the fixture and defines the checks that test
# NAME, such as expected-failure tests. Adding a part therefore adds a file and
# edits no shared one.
#
# Test modules receive the perSystem argument `fixture`:
#
# - `fixture.src`: the fixture source path (`self.outPath` of the fixture flake).
# - `fixture.patched patches`: `fixture.src` with the patch files applied, for
#   the fixture of a bad change.
# - `fixture.expectFailure { drv, exitCode ? 1, logEntries ? [ ] }`: a check
#   that passes when building `drv` fails with the exit code and the log
#   contains each of the log entries (`testBuildFailure'`).
# - `fixture.rejects { check, patches, exitCode ? 1, logEntries ? [ ] }`:
#   `expectFailure` for `check` run on `fixture.patched patches`. Only for a
#   check that is a `runCommand` with the source in its `src` attribute, which
#   `rejects` overrides. Other checks override their `src` (and the
#   attributes derived from it, such as `cargoVendorDir`) and call
#   `expectFailure` themselves.
# - `fixture.packages`: this flake's `packages` for the same system.
# - `fixture.flakeModules`: the exported modules for isolated consumer tests.
# - `fixture.evalPerSystem args`: evaluate a separate consumer for this system,
#   with the same arguments as `evalFlake` below, without building its source.
#
# Patches are git-diff style files in the directory of the test module, with
# paths relative to the fixture root. `patched` applies them with `patch -p1`,
# which is more lenient than `git apply`, so check each patch with both
# `git apply --check` and `patch -p1 --dry-run` in a copy of tests/fixture. The
# fixtures run with the tools pinned by flake.lock; the expected status and
# diagnostic are checked by their native Nix builds.
#
# The evaluation of the fixture must not import from derivation, so tests do
# not evaluate a patched flake. No evaluation depends on `options`, which
# would recurse infinitely.
#
# Evaluation tests: modules/NAME/eval-test.nix, packages/NAME/eval-test.nix
# and tests/eval-test.nix (part `harness`) test the Nix code of a part by
# evaluation alone, so unlike checks that must build they run wherever the
# flake evaluates. An evaluation test file is a function of the arguments
# below that returns tests in the format of `lib.debug.runTests` and nix-unit,
# an attribute set of `testNAME = { expr = ...; expected = ...; }`:
#
# - `lib`, `system`, and `pkgs`: the flake's nixpkgs for `system`, without
#   rust-overlay; the fixture's own `pkgs` and `toolchains` module arguments
#   are `perSystem._module.args`.
# - `flakeModules`: this flake's `flakeModules`.
# - `src`: the fixture source path (`self.outPath` of the fixture flake).
# - `perSystem`: the perSystem config of the fixture flake for `system`, e.g.
#   `perSystem.checks`, `perSystem.checkTags`.
# - `evalFlake { modules ? [ ], self ? fixture source, allFlakeModules ? true,
#   testModules ? false }`: the outputs (with `debug = true`) of another
#   flake-parts flake over the fixture that imports `modules` and, unless
#   `allFlakeModules = false`, every flake module, to test how the options of
#   a part respond to definitions a consumer would write. Pass `self` as a
#   source path or an attribute set with `outPath`. With
#   `allFlakeModules = false` only `modules` are imported, e.g.
#   `[ flakeModules.NAME ]`, to test that a module declares the modules it
#   depends on. With `testModules = true` it imports the test modules too, as
#   the fixture flake does.
# - `evalPerSystem args`: the perSystem config for `system` of `evalFlake args`.
# - `packages`: this flake's `packages` for `system`.
# - `throws expr`: whether evaluating `expr` to weak head normal form throws
#   (`builtins.tryEval`, which catches `throw` and failed assertions, such as
#   module type errors, but not every error, e.g. not a missing attribute).
#   Force deeper values explicitly, e.g. with `builtins.deepSeq`.
# - `runEvalTests tests`: failure records, used to verify that invalid tests
#   cannot pass silently.
#
# `expr` and `expected` are compared after forcing `expr` completely with
# deepSeq, so they should be plain data (names, strings, booleans, lists and
# attribute sets of them), never derivations or store paths: compare names,
# attribute presence and substrings of commands. A test whose `expr` throws
# fails with the result "<throws>"; an attribute whose name does not start
# with `test` fails too, instead of being ignored.
# Parts are named `modules-<name>` or `packages-<name>` so a shared name
# cannot hide tests; `harness` is reserved for the harness itself.
# Tests are exposed as `tests.<system>.<part>` (nix-unit) and one check per part,
# `eval-tests-<part>`: evaluating that check throws with every failing test,
# its expected and actual value, so evaluating the checks runs the tests.
# When they pass, the check is a trivial derivation.
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
            src = self.outPath;

            patched =
              patches:
              pkgs.applyPatches {
                name = "fixture-patched";
                inherit src patches;
              };

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

            packages = config.allSystems.${system}.packages;
            flakeModules = config.flake.flakeModules;
            evalPerSystem = args: (evalFlake args).allSystems.${system};
          };
        };
    };

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
      args = {
        inherit
          lib
          pkgs
          system
          inputs
          ;
        inherit (config.flake) flakeModules;
        src = fixtureSelf.outPath;
        perSystem = fixtureFlake.allSystems.${system};
        inherit evalFlake;
        evalPerSystem = args: (evalFlake args).allSystems.${system};
        packages = config.allSystems.${system}.packages;
        inherit runEvalTests;
        throws = expr: !(builtins.tryEval expr).success;
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
