# Evaluation tests of check-tags: the aggregates link the checks tagged with
# their name, definitions replace the mkDefault tags of other modules, and
# misuse fails with the module's messages.
{
  lib,
  pkgs,
  perSystem,
  evalPerSystem,
  throws,
  ...
}:
let
  probe = name: pkgs.runCommand name { } ''mkdir "$out"'';
  linked = aggregate: lib.attrNames aggregate.entries;
  tagged = checkTags: tag: lib.attrNames (lib.filterAttrs (_: builtins.elem tag) checkTags);
  withProbe = tags: {
    perSystem = {
      checks.probe = probe "probe";
      checkTags.probe = tags;
    };
  };
  # Evaluates the path of each entry of an aggregate, where check-tags throws.
  # tryEval drops the message of `throw`, so the tests compare the conditions
  # that throw, not the messages.
  forceAggregate =
    config: tag:
    lib.foldl' (acc: path: builtins.seq path acc) null (lib.attrValues config.checks.${tag}.entries);
in
{
  testAggregateCyclesThrow = {
    expr =
      map
        (
          checkTags:
          throws
            (evalPerSystem {
              modules = [ { perSystem = { inherit checkTags; }; } ];
            }).checks.lint.drvPath
        )
        [
          { lint = [ "lint" ]; }
          {
            lint = [ "quick" ];
            quick = [ "lint" ];
          }
          {
            lint = [ "quick" ];
            quick = [ "nightly" ];
            nightly = [ "lint" ];
          }
        ];
    expected = [
      true
      true
      true
    ];
  };

  testAggregateAliasCycleThrows = {
    expr =
      throws
        (evalPerSystem {
          modules = [
            {
              perSystem = { config, ... }: {
                checks.lint = config.checks.quick;
                checkTags.lint = [ "quick" ];
              };
            }
          ];
        }).checks.quick.drvPath;
    expected = true;
  };

  testAcyclicAggregateNesting = {
    expr =
      let
        config = evalPerSystem {
          modules = [ { perSystem.checkTags.quick = [ "lint" ]; } ];
        };
      in
      {
        nested = config.checks.lint.entries.quick == config.checks.quick;
        builds = builtins.isString config.checks.lint.drvPath;
      };
    expected = {
      nested = true;
      builds = true;
    };
  };

  testReplacedAggregateBreaksCycle = {
    expr =
      map
        (
          name:
          builtins.isString
            (evalPerSystem {
              modules = [
                {
                  perSystem = {
                    checkTags = {
                      lint = [ "quick" ];
                      quick = [ "lint" ];
                    };
                    checks.${name} = probe "replacement";
                  };
                }
              ];
            }).checks.${if name == "lint" then "quick" else "lint"}.drvPath
        )
        [
          "lint"
          "quick"
        ];
    expected = [
      true
      true
    ];
  };

  testReplacedAggregateMayUseOwnTag = {
    expr =
      builtins.isString
        (evalPerSystem {
          modules = [
            {
              perSystem = {
                checks.lint = probe "replacement";
                checkTags.lint = [
                  "lint"
                  "quick"
                ];
              };
            }
          ];
        }).checks.quick.drvPath;
    expected = true;
  };

  # Each aggregate of the fixture links exactly the checks tagged with it.
  testFixtureAggregates = {
    expr = map (tag: linked perSystem.checks.${tag}) [
      "lint"
      "nightly"
      "quick"
    ];
    expected = map (tagged perSystem.checkTags) [
      "lint"
      "nightly"
      "quick"
    ];
  };

  testAggregateLinksCheck = {
    expr =
      let
        config = evalPerSystem { modules = [ (withProbe [ "quick" ]) ]; };
      in
      [
        (builtins.elem "probe" (linked config.checks.quick))
        (builtins.elem "probe" (linked config.checks.lint))
        (config.checks.quick.entries.probe == config.checks.probe)
      ];
    expected = [
      true
      false
      true
    ];
  };

  # The other modules tag their checks with mkDefault, as this one does, so
  # a plain definition replaces their tags instead of adding to them.
  testDefinitionReplacesModuleTags = {
    expr =
      let
        config = evalPerSystem {
          modules = [
            {
              perSystem.checks.probe = probe "probe";
              perSystem.checkTags.probe = lib.mkDefault [
                "lint"
                "nightly"
              ];
            }
            { perSystem.checkTags.probe = [ "quick" ]; }
          ];
        };
      in
      {
        tags = config.checkTags.probe;
        inLint = builtins.elem "probe" (linked config.checks.lint);
        inQuick = builtins.elem "probe" (linked config.checks.quick);
      };
    expected = {
      tags = [ "quick" ];
      inLint = false;
      inQuick = true;
    };
  };

  testTagOfMissingCheckThrows = {
    expr = throws (
      forceAggregate (evalPerSystem {
        modules = [ { perSystem.checkTags.missing = [ "lint" ]; } ];
      }) "lint"
    );
    expected = true;
  };

  testAggregateTaggedWithOwnNameThrows = {
    expr = throws (
      forceAggregate (evalPerSystem { modules = [ { perSystem.checkTags.lint = [ "lint" ]; } ]; }) "lint"
    );
    expected = true;
  };

  # The aggregates are mkDefault, so a flake can replace one.
  testAggregateCanBeReplaced = {
    expr =
      (evalPerSystem { modules = [ { perSystem.checks.lint = probe "own-lint"; } ]; }).checks.lint.name;
    expected = "own-lint";
  };
}
