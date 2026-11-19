# Evaluation tests of the cargo-workspaces module (see tests/default.nix).
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
  toolchains = [
    "beta"
    "nightly"
    "stable"
  ];

  # Checks of the cargo-* modules are not used here: this part is tested without
  # the parts that come after it. `probe` and `quiet` stand in for them, tagged
  # as such a check would be.
  probeChecks = {
    perSystem.cargoChecks = {
      probe = {
        tags = [
          "lint"
          "nightly"
        ];
        package = workspace: pkgs.runCommand "probe-of-${workspace.name}" { } "touch $out";
      };
      quiet = {
        tags = [ ];
        package = workspace: pkgs.runCommand "quiet-of-${workspace.name}" { } "touch $out";
      };
    };
  };
  probeIds = [
    "probe"
    "quiet"
  ];

  # A flake of only this module and the probe checks, with these workspaces,
  # over the fixture.
  withWorkspaces =
    cargoWorkspaces: extra:
    evalPerSystem {
      allFlakeModules = false;
      modules = [
        flakeModules.cargo-workspaces
        probeChecks
        {
          perSystem = {
            inherit cargoWorkspaces;
          }
          // extra;
        }
      ];
    };

  fixtureWs = perSystem.cargoWorkspaces.fixture;
  manifest = withWorkspaces { w.manifestPath = "Cargo.toml"; } { };
  nested = withWorkspaces { w.manifestPath = "sub/Cargo.toml"; } { };
in
{
  testStringRoot = {
    expr =
      let
        root = builtins.path {
          path = ./fixtures;
          name = "workspace-root";
        };
        evaluate = root: (withWorkspaces { w = { inherit root; }; } { }).cargoWorkspaces.w;
        stringRoot = evaluate root;
        wrappedRoot = evaluate { outPath = root; };
      in
      {
        isString = builtins.isString root;
        sameArtifacts = lib.all (
          toolchain:
          lib.all
            (
              profile:
              stringRoot.cargoArtifacts.${toolchain}.${profile}.drvPath
              == wrappedRoot.cargoArtifacts.${toolchain}.${profile}.drvPath
            )
            [
              "dev"
              "release"
            ]
        ) toolchains;
      };
    expected = {
      isString = true;
      sameArtifacts = true;
    };
  };

  testCargoCheckTagsValidatedWithoutWorkspace = {
    expr =
      map
        (
          tags:
          throws (
            builtins.deepSeq
              (withWorkspaces { } { cargoChecks.probe.tags = lib.mkForce tags; }).cargoChecks.probe.tags
              true
          )
        )
        [
          [ "docs" ]
          [
            "lint"
            "nightly"
            "quick"
          ]
        ];
    expected = [
      true
      false
    ];
  };

  testNativeBuildTools = {
    expr =
      let
        w = (withWorkspaces { w.nativeBuildInputs = [ pkgs.pkg-config ]; } { }).cargoWorkspaces.w;
      in
      lib.all (args: builtins.elem pkgs.pkg-config args.nativeBuildInputs) (
        [
          w.commonArgs
          w.checkArgs
        ]
        ++ lib.concatMap (
          toolchain:
          map (profile: w.cargoArtifacts.${toolchain}.${profile}) [
            "dev"
            "release"
          ]
        ) toolchains
      );
    expected = true;
  };

  testSourceOnlyChangesReuseArtifacts = {
    expr =
      let
        evaluate =
          root:
          evalPerSystem {
            allFlakeModules = false;
            modules = [
              flakeModules.cargo-workspaces
              {
                perSystem.cargoWorkspaces.w = {
                  inherit root;
                  manifestPath = "Cargo.toml";
                };
              }
            ];
          };
        original = (evaluate ./fixtures).cargoWorkspaces.w;
        filtered =
          (evaluate {
            outPath = builtins.path {
              path = ./fixtures;
              name = "workspace-source-only-change";
              filter = path: _: builtins.baseNameOf path != "unused.rs";
            };
          }).cargoWorkspaces.w;
      in
      {
        differentSource = toString original.commonArgs.src != toString filtered.commonArgs.src;
        artifacts = lib.all (
          toolchain:
          lib.all
            (
              profile:
              original.cargoArtifacts.${toolchain}.${profile}.drvPath
              == filtered.cargoArtifacts.${toolchain}.${profile}.drvPath
            )
            [
              "dev"
              "release"
            ]
        ) toolchains;
      };
    expected = {
      differentSource = true;
      artifacts = true;
    };
  };

  # The fixture's test module configures one workspace without a prefix, so
  # its checks keep the names of a repository that has a single workspace.
  testEmptyPrefixKeepsNames = {
    expr = lib.attrValues fixtureWs.checks;
    expected = lib.attrNames perSystem.cargoChecks;
  };

  # Without checkPrefix, checks are prefixed with the name of the workspace,
  # and so are their tags.
  testDefaultPrefix = {
    expr = {
      checks = lib.attrValues manifest.cargoWorkspaces.w.checks;
      probeTags = manifest.checkTags.w-probe;
      quietTags = manifest.checkTags.w-quiet;
      unprefixed = manifest.checks ? probe;
    };
    expected = {
      checks = map (id: "w-${id}") probeIds;
      probeTags = [
        "lint"
        "nightly"
      ];
      quietTags = [ ];
      unprefixed = false;
    };
  };

  # Two workspaces with the same prefix define the same checks, which is an
  # error and not one workspace replacing the other.
  testSamePrefixConflicts = {
    expr =
      let
        ws = withWorkspaces {
          a = {
            manifestPath = "Cargo.toml";
            checkPrefix = "";
          };
          b = {
            manifestPath = "Cargo.toml";
            checkPrefix = "";
          };
        } { };
      in
      throws ws.checks.probe.drvPath;
    expected = true;
  };

  testIdenticalChecksStillRejectDuplicatePrefixes = {
    expr =
      let
        ws =
          withWorkspaces
            {
              a.checkPrefix = "same-";
              b.checkPrefix = "same-";
            }
            {
              cargoChecks.identical.package = _: pkgs.runCommand "identical" { } "touch $out";
            };
      in
      throws ws.checks.same-identical.drvPath;
    expected = true;
  };

  # A manifest in a subdirectory: cargo runs there with the file name only.
  testNestedManifestPath = {
    expr = {
      manifest = nested.cargoWorkspaces.w.cargoManifestPath;
      srcDir = nested.cargoWorkspaces.w.srcDir;
    };
    expected = {
      manifest = "Cargo.toml";
      srcDir = "$src/sub";
    };
  };

  testMissingManifestThrows = {
    expr = throws nested.cargoWorkspaces.w.commonArgs.cargoToml;
    expected = true;
  };

  # Dependency artifacts exist for each toolchain and profile, and set the
  # profile their dependencies are built in.
  testCargoArtifacts = {
    expr = lib.mapAttrs (_: lib.mapAttrs (_: a: a.CARGO_PROFILE)) fixtureWs.cargoArtifacts;
    expected = lib.genAttrs toolchains (_: {
      dev = "dev";
      release = "release";
    });
  };

  # A consumer registers its own check, instantiated for every workspace
  # with the workspace's attributes, and tags it.
  testCargoChecksExtension = {
    expr =
      let
        ws =
          withWorkspaces
            {
              w.manifestPath = "Cargo.toml";
              v.manifestPath = "Cargo.toml";
            }
            {
              cargoChecks.coverage = {
                tags = [ "nightly" ];
                package = workspace: pkgs.runCommand "coverage-of-${workspace.name}" { } "touch $out";
              };
            };
      in
      {
        names = [
          ws.checks.w-coverage.name
          ws.checks.v-coverage.name
        ];
        tags = ws.checkTags.w-coverage;
        id = ws.cargoWorkspaces.w.checks.coverage;
        aggregated = ws.checks.nightly.entries ? w-coverage;
      };
    expected = {
      names = [
        "coverage-of-w"
        "coverage-of-v"
      ];
      tags = [ "nightly" ];
      id = "w-coverage";
      aggregated = true;
    };
  };

  # The tags of a workspace's check are defaults: a plain definition replaces
  # them.
  testCheckTagsReplaced = {
    expr =
      let
        ws = withWorkspaces { w.manifestPath = "Cargo.toml"; } {
          checkTags.w-probe = [ "lint" ];
        };
      in
      {
        probe = ws.checkTags.w-probe;
        quiet = ws.checkTags.w-quiet;
        nightly = lib.attrNames ws.checks.nightly.entries;
      };
    expected = {
      probe = [ "lint" ];
      quiet = [ ];
      nightly = [ ];
    };
  };
}
