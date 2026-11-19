# flake-parts

Reusable [flake-parts](https://flake.parts) modules so Fungi repositories can
share checks instead of maintaining separate copies.

The input is named `fungi-flake-parts` below, because a flake that uses these
modules already has an input named `flake-parts`, the module system itself.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fungi-flake-parts = {
      url = "github:fungi-protocol/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.fungi-flake-parts.flakeModules.NAME ];
    };
}
```

Every `modules/NAME.nix` or `modules/NAME/default.nix` is exported as
`flakeModules.NAME` and documented in its header comment.

## Origins and scope

This extraction builds on [Mshehu5's shared Nix checks proposal,
validate-commits PR #7](https://github.com/fungi-protocol/validate-commits/pull/7)
([reviewed revision `b8da19f`](https://github.com/fungi-protocol/validate-commits/commit/b8da19f984547eecb3beca17bca94ad716a1489f)).
In particular, its Cargo Sort and Cargo Shear negative tests established the
`applyPatches` + `testBuildFailure'` pattern: apply a defect to a separate source
copy, then assert the failing builder's exit code and diagnostic. The harness
in `tests/default.nix` generalizes that pattern for each extracted module.

The modules also draw on the checks in `fungi` and `concurrent-psbt`. Compared
with PR #7:

| Area | This extraction |
| --- | --- |
| Composition | Independently importable modules declare their dependencies; the fixture imports every exported module. |
| Cargo workspaces | Named workspaces select manifests, lockfiles, build inputs and check prefixes; duplicate prefixes are rejected. |
| Dependency reuse | Extends PR #7's shared artifacts to a toolchain/profile table for stable, beta and nightly, each in dev and release. |
| Check selection | Configurable tags determine aggregates instead of a fixed list of check names. |
| Tests of checks | Extends the negative patch fixtures beyond Sort and Shear, with evaluation tests for configuration and module composition. |

Coverage collection and gates are not extracted yet; `lcov2xml` only converts
reports. PR #7's coverage findings therefore remain outside this implementation.
The mutation fixtures test whether the checker rejects missed mutants; they do
not repair surviving mutants in `validate-commits`. Hartig was proposed as the
first consumer in PR #7's discussion, but has not been migrated or validated here.
