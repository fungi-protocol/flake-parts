# Check `mutants` for each workspace of the cargo-workspaces module, in no
# aggregate. Runs cargo-mutants with nextest in the nightly toolchain's dev
# profile. Each mutant is tested against the entire workspace, including
# dependent crates.
#
# `cargoMutants.incremental` enables incremental compilation. Crane disables
# it, but cargo-mutants rebuilds the crate once per mutant in the same target
# directory. The default is false.
# `cargoMutants.jobs` defaults to half Nix's build cores (at least one).
# A single job mutates in place and reuses artifacts; multiple jobs use
# separate source copies without copying restored target directories.
#
# To let validate-commits inject a commit's repository-relative Rust diff,
# the importing flake declares and locks this non-flake input:
#
#   inputs.mutants-diff = { url = "path:./mutants-diff"; flake = false; };
#
# Track a directory at that path as the full-suite placeholder. An injected
# file selects --in-diff, including an empty file (no changed Rust code).
# validate-commits PR #14 supplies it with --override-input mutants-diff.
# Without an injected file, runs mutate the whole workspace. Baseline checks
# remain enabled; baseline reuse is not implemented.
{ localFlakeModules, ... }:
{ inputs, ... }:
let
  mutantsDiff = inputs.mutants-diff or null;
in
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    {
      config,
      lib,
      pkgs,
      toolchains,
      ...
    }:
    {
      options.cargoMutants.jobs = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Parallel mutant jobs, or null for half NIX_BUILD_CORES (at least one).";
      };

      options.cargoMutants.incremental = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to compile incrementally.";
      };

      config.cargoChecks.mutants.package =
        workspace:
        let
          # Manifest paths can contain redundant separators and dot components.
          # Diff paths are canonical repository-relative paths.
          components = lib.filter (part: part != "" && part != ".") (
            lib.splitString "/" (builtins.dirOf workspace.manifestPath)
          );
          workspaceParts = lib.foldl' (
            parts: part:
            if part == ".." && parts != [ ] && lib.last parts != ".." then lib.init parts else parts ++ [ part ]
          ) [ ] components;
          workspaceDir = lib.concatStringsSep "/" workspaceParts;
          nested = workspaceParts != [ ];
          workspacePattern = lib.escape [ "\\" "[" "]" "*" "?" ] workspaceDir + "/*";
        in
        toolchains.nightly.mkCargoDerivation (
          workspace.checkArgs
          // {
            cargoArtifacts = workspace.cargoArtifacts.nightly.dev;
            CARGO_PROFILE = "dev";
            pnameSuffix = "-mutants";
            nativeBuildInputs =
              workspace.checkArgs.nativeBuildInputs
              ++ (with pkgs; [
                cargo-mutants
                cargo-nextest
              ])
              ++ lib.optional (mutantsDiff != null && nested) pkgs.patchutils;
            # --workspace mutates every member.
            buildPhaseCargoCommand = ''
              jobs=${
                if config.cargoMutants.jobs == null then
                  "$((\${NIX_BUILD_CORES:-1} / 2))"
                else
                  toString config.cargoMutants.jobs
              }
              args=(--workspace --test-workspace=true --test-tool nextest --manifest-path ${lib.escapeShellArg "./${workspace.cargoManifestPath}"})
              ${lib.optionalString (mutantsDiff != null) ''
                if [ -f ${lib.escapeShellArg mutantsDiff.outPath} ]; then
                  diff=${lib.escapeShellArg mutantsDiff.outPath}
                  ${lib.optionalString (nested) ''
                    # The validator's paths start at the repository, not this workspace.
                    filterdiff -p1 -i ${lib.escapeShellArg workspacePattern} \
                      --strip=${toString (1 + builtins.length workspaceParts)} \
                      --addoldprefix=a/ --addnewprefix=b/ "$diff" > "$TMPDIR/mutants-workspace.patch"
                    # filterdiff 0.3.x does not rewrite Git's optional diff header correctly.
                    sed -i '/^diff/d' "$TMPDIR/mutants-workspace.patch"
                    diff="$TMPDIR/mutants-workspace.patch"
                  ''}
                  args+=(--in-diff "$diff")
                fi
              ''}
              if ((jobs > 1)); then
                cargo mutants "''${args[@]}" --jobs "$jobs" --copy-target=false
              else
                cargo mutants "''${args[@]}" --in-place
              fi
            '';
            installPhase = "mkdir -p $out";
          }
          // lib.optionalAttrs config.cargoMutants.incremental {
            CARGO_BUILD_INCREMENTAL = "true";
          }
        );
    };
}
