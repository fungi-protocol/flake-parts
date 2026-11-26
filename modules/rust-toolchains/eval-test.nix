# Evaluation tests of rust-toolchains: the `toolchains` argument has the three
# release channels with their components, is built from the importing flake's
# own `pkgs`, and leaves that argument as it is. Versions are not compared,
# because they change when rust-overlay is updated.
{
  lib,
  inputs,
  pkgs,
  flakeModules,
  evalPerSystem,
  ...
}:
let
  alone =
    modules:
    evalPerSystem {
      modules = [ flakeModules.rust-toolchains ] ++ modules;
      allFlakeModules = false;
    };
  toolchains = (alone [ ])._module.args.toolchains;

  # rustc-1.100.0-x86_64-unknown-linux-gnu -> rustc, clippy-preview-... ->
  # clippy. clippy is in the default profile and an extension, so it is listed
  # twice.
  component =
    path:
    lib.removeSuffix "-preview" (
      lib.head (builtins.match "[a-z0-9]{32}-([a-z-]+)-[0-9].*" (baseNameOf path))
    );
  components =
    channel: lib.unique (lib.sort lib.lessThan (map component toolchains.${channel}.rustc.paths));
in
{
  testChannelOfEachToolchain = {
    expr = lib.mapAttrs (
      _: craneLib:
      let
        name = craneLib.rustc.name;
      in
      {
        nightly = lib.hasInfix "-nightly-" name;
        beta = lib.hasInfix "-beta." name;
      }
    ) toolchains;
    expected = {
      nightly = {
        nightly = true;
        beta = false;
      };
      beta = {
        nightly = false;
        beta = true;
      };
      stable = {
        nightly = false;
        beta = false;
      };
    };
  };

  # Every toolchain has clippy, rust-analyzer and rust-src; only nightly has
  # llvm-tools, for coverage.
  testComponents = {
    expr = lib.mapAttrs (channel: _: components channel) toolchains;
    expected =
      let
        common = [
          "cargo"
          "clippy"
          "rust-analyzer"
          "rust-docs"
          "rust-src"
          "rust-std"
          "rustc"
          "rustfmt"
        ];
      in
      {
        nightly = lib.sort lib.lessThan (common ++ [ "llvm-tools" ]);
        beta = common;
        stable = common;
      };
  };

  # The module does not replace the importing flake's `pkgs`.
  testPkgsNotReplaced = {
    expr = {
      rustBin = (alone [ ])._module.args.pkgs ? rust-bin;
      own =
        (alone [
          { perSystem._module.args.pkgs = lib.mkForce (pkgs // { fungiFlakePartsProbe = true; }); }
        ])._module.args.pkgs.fungiFlakePartsProbe or false;
    };
    expected = {
      rustBin = false;
      own = true;
    };
  };

  # The toolchains are built from the importing flake's `pkgs`, so its
  # overlays apply to the toolchain derivation itself.
  testToolchainsUseOwnPkgs = {
    expr =
      let
        own = pkgs.appendOverlays [
          (_: prev: {
            symlinkJoin =
              args:
              prev.symlinkJoin (
                args
                // {
                  passthru = (args.passthru or { }) // {
                    fungiToolchainProbe = true;
                  };
                }
              );
          })
        ];
        config = alone [ { perSystem._module.args.pkgs = lib.mkForce own; } ];
      in
      {
        default = toolchains.nightly.rustc.fungiToolchainProbe or false;
        own = config._module.args.toolchains.nightly.rustc.fungiToolchainProbe or false;
      };
    expected = {
      default = false;
      own = true;
    };
  };

  testCrossToolchainIsSpliced = {
    expr =
      let
        cross = inputs.nixpkgs.legacyPackages.x86_64-linux.pkgsCross.aarch64-multiplatform;
        config = alone [ { perSystem._module.args.pkgs = lib.mkForce cross; } ];
      in
      config._module.args.toolchains.stable.rustc ? __spliced;
    expected = true;
  };
}
