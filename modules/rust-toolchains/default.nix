# Provides the perSystem module argument `toolchains`: a crane library for each
# of the latest nightly, beta and stable Rust toolchains. They come from the
# importing flake's own `pkgs` (its nixpkgs, config and overlays) extended with
# rust-overlay; the `pkgs` argument itself is left as it is. A flake that wants
# `pkgs.rust-bin` applies rust-overlay to its `pkgs` itself. flake-parts
# provides `pkgs` when the flake has an input named `nixpkgs`; a flake without
# one defines `perSystem._module.args.pkgs`.
#
# rust-overlay and crane are inputs of this flake. To lock them in the
# importing flake instead:
#
#   fungi-flake-parts.inputs.rust-overlay.follows = "rust-overlay";
#   fungi-flake-parts.inputs.crane.follows = "crane";
{ localInputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      rustPkgs = pkgs.appendOverlays [ localInputs.rust-overlay.overlays.default ];

      commonExtensions = [
        "clippy"
        "rust-analyzer"
        "rust-src"
      ];

      rustToolchains = {
        nightly =
          packages:
          packages.rust-bin.selectLatestNightlyWith (
            t:
            t.default.override {
              extensions = commonExtensions ++ [ "llvm-tools" ];
            }
          );
        beta =
          packages:
          packages.rust-bin.beta.latest.default.override {
            extensions = commonExtensions;
          };
        stable =
          packages:
          packages.rust-bin.stable.latest.default.override {
            extensions = commonExtensions;
          };
      };

      craneLib = localInputs.crane.mkLib rustPkgs;
      # Let Crane choose the toolchain for each package set when cross-compiling.
      mkCraneLib = _: select: craneLib.overrideToolchain select;
      toolchains = builtins.mapAttrs mkCraneLib rustToolchains;
    in
    {
      _module.args.toolchains = toolchains;
    };
}
