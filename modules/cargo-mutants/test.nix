# Expected failure of the mutants check on the fixture workspace.
#
# dependent-tests.patch weakens only fixture-base's test: fixture-app's
# `double(21) == 42` still catches the mutation of `a + b` to `a * b` in add.
# missed-mutant.patch also weakens that dependent test to `double(2) == 4`,
# so the mutant survives both packages. The doctests still detect it, but
# nextest does not run them. cargo-mutants exits with 2 for a missed mutant.
#
# The mutant is reported by its description, which has no line numbers.
#
# The fixture also sets cargoMutants.incremental, as concurrent-psbt does, so
# that the option is evaluated and the unpatched check keeps passing with it.
{ inputs, ... }:
{
  perSystem =
    {
      config,
      fixture,
      system,
      ...
    }:
    let
      withDiff =
        {
          diff,
          nested ? false,
          jobs ? 1,
        }:
        let
          consumerInputs = inputs // {
            mutants-diff.outPath = diff;
          };
          consumer =
            inputs.flake-parts.lib.mkFlake
              {
                inputs = consumerInputs // {
                  self = {
                    outPath = if nested then ./fixtures/diff else ./fixtures/diff/crate;
                    inputs = consumerInputs;
                  };
                };
              }
              {
                systems = [ system ];
                imports = [ fixture.flakeModules.cargo-mutants ];
                perSystem = {
                  cargoWorkspaces.consumer.manifestPath = if nested then "./crate//./Cargo.toml" else "Cargo.toml";
                  cargoMutants.jobs = jobs;
                };
              };
        in
        consumer.checks.${system}.consumer-mutants;
      selectsChanged =
        args:
        (withDiff args).overrideAttrs (old: {
          postBuild = (old.postBuild or "") + ''
            grep -F changed mutants.out/caught.txt
            if grep -F untouched mutants.out/caught.txt; then
              echo "mutated code outside the injected diff" >&2
              exit 1
            fi
          '';
        });
    in
    {
      checks.cargo-mutants-injected-diff = selectsChanged { diff = ./fixtures/diff/root.patch; };
      checks.cargo-mutants-injected-diff-parallel = selectsChanged {
        diff = ./fixtures/diff/root.patch;
        jobs = 2;
      };
      checks.cargo-mutants-injected-empty-diff = withDiff { diff = ./fixtures/diff/empty.patch; };
      checks.cargo-mutants-injected-nested-diff = selectsChanged {
        diff = ./fixtures/diff/nested.patch;
        nested = true;
      };
      checks.cargo-mutants-placeholder-runs-full-suite = fixture.expectFailure {
        drv = withDiff { diff = ./fixtures/diff/placeholder; };
        exitCode = 2;
        logEntries = [
          "MISSED"
          "replace + with * in untouched"
        ];
      };

      cargoMutants.incremental = true;
      cargoMutants.jobs = 2;

      checks.cargo-mutants-single-job =
        (fixture.evalPerSystem {
          allFlakeModules = false;
          modules = [
            fixture.flakeModules.cargo-mutants
            {
              perSystem = {
                cargoWorkspaces.fixture.manifestPath = "Cargo.toml";
                cargoMutants.jobs = 1;
              };
            }
          ];
        }).checks.fixture-mutants;

      checks.cargo-mutants-uses-dependent-tests = config.checks.mutants.overrideAttrs {
        src = fixture.patched [ ./dependent-tests.patch ];
      };

      checks.cargo-mutants-rejects-missed-mutant = fixture.rejects {
        check = config.checks.mutants;
        patches = [ ./missed-mutant.patch ];
        exitCode = 2;
        logEntries = [
          "MISSED"
          "replace + with * in add"
        ];
      };
    };
}
