# treefmt-nix configuration shared by Fungi repositories: nixfmt, rustfmt,
# shellcheck, shfmt, taplo, yamlfmt and a cargo-sort formatter that runs before
# taplo. Provides the `treefmt` check and the flake's `formatter`. Formatters
# are enabled with mkDefault, so the importing flake can disable them as well
# as add its own:
#
#   perSystem.treefmt.programs.mdformat.enable = true;
#
# The cargo-sort formatter is a plain definition: a list such as its `includes`
# can be extended, but to replace a value use lib.mkForce. The project root
# file is treefmt-nix's default, flake.nix.
#
# The importing flake must not import treefmt-nix's flakeModule itself. If it
# keeps a treefmt-nix input, it should add
# `fungi-flake-parts.inputs.treefmt-nix.follows = "treefmt-nix"`.
{ localInputs, ... }:
{
  imports = [ localInputs.treefmt-nix.flakeModule ];

  perSystem =
    { lib, pkgs, ... }:
    let
      cargo-sort = pkgs.writeShellApplication {
        name = "treefmt-cargo-sort";
        runtimeInputs = [
          pkgs.cargo-sort
          pkgs.coreutils
        ];
        text = ''
          for manifest in "$@"; do
            cargo-sort -- "$(dirname -- "$manifest")"
          done
        '';
      };
    in
    {
      treefmt = {
        programs.nixfmt.enable = lib.mkDefault true;
        programs.rustfmt.enable = lib.mkDefault true;
        programs.shellcheck.enable = lib.mkDefault true;
        programs.shfmt.enable = lib.mkDefault true;
        programs.taplo = {
          enable = lib.mkDefault true;
          priority = 1; # run after cargo-sort
        };
        programs.yamlfmt.enable = lib.mkDefault true;

        settings.formatter.cargo-sort = {
          command = cargo-sort;
          priority = 0; # run before taplo
          includes = [
            "Cargo.toml"
            "**/Cargo.toml"
          ];
        };
      };
    };
}
