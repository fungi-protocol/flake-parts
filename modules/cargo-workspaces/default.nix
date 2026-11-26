# Describes the Cargo workspaces of the importing flake in the perSystem option
# `cargoWorkspaces`, for the cargo-* check modules of this flake:
#
#   perSystem.cargoWorkspaces.default = { };
#
#   perSystem.cargoWorkspaces.fungi = {
#     manifestPath = "Cargo.toml";
#     buildInputs = [ pkgs.openssl ];
#   };
#
# Options of each workspace:
#
# - `manifestPath`: path of the workspace's Cargo.toml relative to `root`,
#   "Cargo.toml" by default. The workspace builds from the Cargo.lock next to
#   it with `--locked --manifest-path`, so a repository may hold several
#   workspaces.
# - `buildInputs`, `nativeBuildInputs`: libraries and build tools added to
#   `commonArgs`, shared by dependency builds and checks.
# - `root`: source tree of the repository, `self` by default.
# - `src`: crane's cleanCargoSource of `root` by default.
# - `checkPrefix`: prepended to the names of the workspace's checks, and of
#   their tags in `checkTags`. "<workspace name>-" by default; use "" for a
#   repository with a single workspace, e.g. to keep existing check names.
#   Two workspaces with the same prefix define the same checks, which the
#   module system reports as a conflict.
#
# Each workspace provides these read-only attributes to the check modules and
# to the importing flake, e.g. for its packages:
#
# - `commonArgs`: arguments for every crane derivation of the workspace.
# - `checkArgs`: `commonArgs` for checks that install nothing.
# - `cargoArtifacts.<toolchain>.<profile>`: dependency-only builds for each
#   toolchain of the rust-toolchains module and the profiles `dev` and
#   `release`. They set CARGO_PROFILE to the profile name.
# - `cargoVendorDir`: vendored dependencies.
# - `cargoManifestPath`: file name of the manifest.
# - `srcDir`: shell expression for the workspace directory of `src`, for
#   checks that run in an unpacked `$src`.
# - `checks`: name in `checks` of each check of `cargoChecks`, by check id.
#
# For example, a package built with the stable toolchain, independently of the
# nightly checks. To select one package, replace --workspace with
# --package <name> in `cargoExtraArgs`, keeping the manifest path:
#
#   perSystem = { config, toolchains, ... }: {
#     packages.default = toolchains.stable.buildPackage (
#       config.cargoWorkspaces.default.commonArgs // {
#         cargoArtifacts = config.cargoWorkspaces.default.cargoArtifacts.stable.release;
#         CARGO_PROFILE = "release";
#       }
#     );
#   };
#
# The cargo-* check modules register their checks in the perSystem option
# `cargoChecks`, which this module instantiates for every workspace. A flake
# can add its own that way:
#
#   perSystem.cargoChecks.coverage = {
#     tags = [ "nightly" ];
#     package = workspace: mkCoverage workspace;
#   };
#
# `package` receives the workspace's attributes described above, plus `name`.
# The check `<checkPrefix><id>` is tagged with `tags` through checkTags, which
# a plain checkTags definition replaces.
#
# This module imports the rust-toolchains and check-tags modules.
{ localFlakeModules, ... }:
{ self, ... }:
{
  imports = [
    localFlakeModules.check-tags
    localFlakeModules.rust-toolchains
  ];

  perSystem =
    {
      config,
      lib,
      options,
      toolchains,
      ...
    }:
    let
      craneLib = toolchains.nightly;
      cargoChecks = config.cargoChecks;
      readOnly =
        description:
        lib.mkOption {
          inherit description;
          type = lib.types.raw;
          readOnly = true;
        };

      workspaceModule =
        { config, name, ... }:
        let
          # Keep the source context so Nix can resolve files in lazy flake
          # inputs before their contents have been materialized in the store.
          rootPath = if builtins.isAttrs config.root then config.root.outPath else config.root;
          manifest = rootPath + "/${config.manifestPath}";
          workspaceDir = builtins.dirOf config.manifestPath;
          lockfile = rootPath + "/${workspaceDir}/Cargo.lock";
          cargoManifestPath = builtins.baseNameOf config.manifestPath;

          commonArgs =
            assert lib.assertMsg (builtins.pathExists manifest)
              "cargoWorkspaces.${name}.manifestPath: ${toString manifest} does not exist";
            assert lib.assertMsg (builtins.pathExists lockfile)
              "cargoWorkspaces.${name}.manifestPath: ${toString lockfile} does not exist";
            {
              inherit (config) src buildInputs nativeBuildInputs;
              cargoToml = builtins.path {
                path = manifest;
                name = "Cargo.toml";
              };
              pname = name;
              strictDeps = true;
              version = "0.0.0";
              # Checks act on every member, not only on Cargo's default
              # members; packages can replace --workspace with --package.
              cargoExtraArgs = "--locked --manifest-path ${lib.escapeShellArg cargoManifestPath} --workspace";
              # Vendoring does not depend on the toolchain, so the nightly one
              # serves every toolchain.
              cargoVendorDir = craneLib.vendorCargoDeps {
                inherit (config) src;
                cargoLock = lockfile;
              };
              postUnpack = ''
                cd "$sourceRoot/${workspaceDir}"
                sourceRoot=.
              '';
            };

          # Built once here so that packages and checks share them.
          cargoArtifacts = builtins.mapAttrs (
            _: toolchain:
            lib.genAttrs [ "dev" "release" ] (
              profile:
              toolchain.buildDepsOnly (
                commonArgs
                // {
                  # Crane defaults to release in a shell hook, after derivation
                  # hashing: unset and explicit "release" yield different drvs.
                  CARGO_PROFILE = profile;
                  # crane's dummy source only carries the repository-root
                  # Cargo.lock; the replaceCargoLock hook installs this one
                  # into the workspace directory before cargo resolves
                  # anything.
                  # Import the lockfile separately: a contextual string into
                  # `root` would make source edits rebuild dependencies.
                  cargoLock = builtins.path {
                    path = lockfile;
                    name = "Cargo.lock";
                  };
                }
              )
            )
          ) toolchains;
        in
        {
          options = {
            manifestPath = lib.mkOption {
              type = lib.types.str;
              default = "Cargo.toml";
              example = "tools/Cargo.toml";
              description = "Path of the workspace's Cargo.toml relative to `root`.";
            };
            buildInputs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Added to `commonArgs.buildInputs`.";
            };
            nativeBuildInputs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Build tools added to dependency builds and Cargo checks.";
            };
            root = lib.mkOption {
              type = lib.types.either lib.types.path lib.types.attrs;
              default = self;
              defaultText = lib.literalExpression "self";
              description = "Source tree of the repository.";
            };
            src = lib.mkOption {
              type = lib.types.either lib.types.path lib.types.attrs;
              default = craneLib.cleanCargoSource config.root;
              defaultText = lib.literalExpression "craneLib.cleanCargoSource root";
              description = "Source for crane derivations.";
            };
            checkPrefix = lib.mkOption {
              type = lib.types.str;
              default = "${name}-";
              defaultText = lib.literalExpression ''"''${name}-"'';
              description = "Prepended to the names of the workspace's checks.";
            };

            commonArgs = readOnly "Arguments for every crane derivation of the workspace.";
            checkArgs = readOnly "`commonArgs` for checks that install nothing.";
            cargoArtifacts = readOnly "Dependency-only builds by toolchain and profile.";
            cargoVendorDir = readOnly "Vendored dependencies.";
            cargoManifestPath = readOnly "File name of the workspace manifest.";
            srcDir = readOnly "Shell expression for the workspace directory of `$src`.";
            name = readOnly "Name of the workspace.";
            checks = readOnly "Name in `checks` of each check of `cargoChecks`, by check id.";
          };

          config = {
            inherit
              name
              commonArgs
              cargoArtifacts
              cargoManifestPath
              ;
            checks = builtins.mapAttrs (id: _: "${config.checkPrefix}${id}") cargoChecks;
            checkArgs = commonArgs // {
              dontFixup = true;
              doInstallCargoArtifacts = false;
              CARGO_PROFILE = "";
            };
            inherit (commonArgs) cargoVendorDir;
            srcDir = "$src/${workspaceDir}";
          };
        };
    in
    {
      options = {
        cargoWorkspaces = lib.mkOption {
          default = { };
          description = "Cargo workspaces of the repository, by name.";
          type = lib.types.attrsOf (lib.types.submodule workspaceModule);
        };

        cargoChecks = lib.mkOption {
          default = { };
          description = "Checks instantiated for every workspace, by check id.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                tags = lib.mkOption {
                  type = options.checkTags.type.nestedTypes.elemType;
                  default = [ ];
                  description = "Aggregate groups that include the check, as in `checkTags`.";
                };
                package = lib.mkOption {
                  type = lib.types.functionTo lib.types.package;
                  description = "Derivation that runs the check, from the attributes of a workspace.";
                };
              };
            }
          );
        };
      };

      config = {
        # One definition per workspace, so that workspaces with the same
        # checkPrefix conflict instead of one silently replacing the other.
        checks = lib.mkMerge (
          lib.mapAttrsToList (
            _: workspace:
            lib.mapAttrs' (
              id: check: lib.nameValuePair workspace.checks.${id} (check.package workspace)
            ) cargoChecks
          ) config.cargoWorkspaces
        );

        checkTags = lib.mkMerge (
          lib.mapAttrsToList (
            _: workspace:
            lib.mapAttrs' (
              id: check: lib.nameValuePair workspace.checks.${id} (lib.mkDefault check.tags)
            ) cargoChecks
          ) config.cargoWorkspaces
        );
      };
    };
}
