# Evaluation tests of the harness and of what every flake module must satisfy
# (see tests/default.nix).
{
  lib,
  inputs,
  flakeModules,
  evalFlake,
  evalPerSystem,
  system,
  runEvalTests,
  ...
}:
let
  discovered =
    file:
    import ./part-files.nix {
      inherit lib;
      roots = {
        modules = ./discovery;
        packages = ./discovery;
      };
    } file;
  probe = {
    perSystem.checks.harness-probe = derivation {
      name = "harness-probe";
      system = "x86_64-linux";
      builder = "/bin/sh";
    };
  };

  consumer =
    lib.optionalAttrs (flakeModules ? cargo-workspaces) {
      cargoWorkspaces.w = { };
    }
    // lib.optionalAttrs (flakeModules ? work-item-markers) {
      workItemMarkers.no-markers = [ "TO[D]O" ];
    };
  defaults = evalPerSystem { modules = [ { perSystem = consumer; } ]; };
  clearedTags = lib.mapAttrs (_: _: [ ]) (defaults.checkTags or { });

  # Whether a flake of `modules` alone evaluates: the drvPath of each of its
  # checks, formatter and packages. The cargo-* modules
  # only define checks for a workspace, so one is configured for them.
  evaluates =
    name: modules:
    let
      flake = evalFlake {
        modules =
          modules ++ lib.optional (lib.hasPrefix "cargo-" name) { perSystem.cargoWorkspaces.w = { }; };
        allFlakeModules = false;
      };
    in
    (builtins.tryEval (
      builtins.deepSeq [
        (lib.mapAttrs (_: check: check.drvPath) (flake.checks.${system} or { }))
        (lib.mapAttrs (_: package: package.drvPath) (flake.packages.${system} or { }))
        ((flake.formatter.${system} or { }).drvPath or null)
      ] true
    )).success;
in
{
  testDiscoveryRetainsBothKinds = {
    expr = map (file: lib.attrNames (discovered file)) [
      "test.nix"
      "eval-test.nix"
    ];
    expected = builtins.genList (_: [
      "modules-harness"
      "packages-harness"
    ]) 2;
  };

  testExportIgnoresHelperDirectories = {
    expr = lib.attrNames (
      import ../lib/export-modules.nix {
        inherit lib;
        inherit (inputs.flake-parts.lib) importApply;
        source = ./module-sources/one;
        moduleArgs = { };
      }
    );
    expected = [ "probe" ];
  };

  testEvalFlakeAcceptsSourcePath = {
    expr =
      (evalFlake {
        self = ./fixture;
        allFlakeModules = false;
        modules = [ ({ self, ... }: { flake.fixturePath = self.outPath == ./fixture; }) ];
      }).fixturePath;
    expected = true;
  };

  testDiscoveryKeepsHarnessPart = {
    expr = builtins.length (
      lib.attrNames (discovered "eval-test.nix" // { harness = ./eval-test.nix; })
    );
    expected = 3;
  };

  # Both versions must contribute, while repeated imports of one version
  # still deduplicate. Static sources also work in no-build evaluation.
  testDistinctSourcesRetainDefinitions = {
    expr =
      let
        exports =
          source:
          import ../lib/export-modules.nix {
            inherit lib source;
            inherit (inputs.flake-parts.lib) importApply;
            moduleArgs = { };
          };
        one = (exports ./module-sources/one).probe;
        two = (exports ./module-sources/two).probe;
        values =
          modules:
          builtins.sort builtins.lessThan
            (lib.evalModules {
              modules = [
                { options.values = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
              ]
              ++ modules;
            }).config.values;
      in
      {
        distinct = values [
          one
          two
        ];
        repeated = values [
          one
          one
        ];
      };
    expected = {
      distinct = [
        "one"
        "two"
      ];
      repeated = [ "one" ];
    };
  };

  testIsolationForcesPackageValues = {
    expr = evaluates "probe" [ { perSystem.packages.probe = throw "missing imported option"; } ];
    expected = false;
  };

  # Invalid tests must fail closed, including exceptions nested in a result.
  testRunnerRejectsInvalidTests = {
    expr = map (failure: failure.name) (runEvalTests {
      misspelled = {
        expr = true;
        expected = true;
      };
      testMismatch = {
        expr = false;
        expected = true;
      };
      testThrows = {
        expr.nested = throw "invalid result";
        expected = { };
      };
    });
    expected = [
      "misspelled"
      "testMismatch"
      "testThrows"
    ];
  };

  # Consumers can remove every production check from the default aggregates.
  # Use production modules: fixture probes deliberately set non-default tags.
  testConsumerCanReplaceTags = {
    expr =
      if clearedTags == { } then
        { }
      else
        (evalPerSystem {
          modules = [
            {
              perSystem = consumer // {
                checkTags = clearedTags;
              };
            }
          ];
        }).checkTags;
    expected = clearedTags;
  };

  testOnlyRequestedModules = {
    expr = lib.attrNames (
      (evalPerSystem {
        modules = [ probe ];
        allFlakeModules = false;
      }).checks
    );
    expected = [ "harness-probe" ];
  };

  # Every flake module evaluates with only the modules it imports itself. A
  # module that uses an option of a module it does not import fails here even
  # though the fixture, which imports all of them, passes.
  testEachModuleAlone = {
    expr = lib.mapAttrs (name: module: evaluates name [ module ]) flakeModules;
    expected = lib.mapAttrs (_: _: true) flakeModules;
  };

  # Importing a module twice, e.g. directly and through another module, is
  # harmless thanks to its key.
  testEachModuleImportedTwice = {
    expr = lib.mapAttrs (
      name: module:
      evaluates name [
        module
        module
      ]
    ) flakeModules;
    expected = lib.mapAttrs (_: _: true) flakeModules;
  };
}
