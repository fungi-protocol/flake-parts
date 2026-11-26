# Configures treefmt for the fixture and defines expected-failure tests: the
# check must reject a fixture tree that one of the formatters would change.
# `treefmt.build.check` takes the tree to check, so the tests pass it the
# patched fixture instead of overriding `src`. The check ends with
# `git diff --exit-code` (exit 1), whose output holds the formatted lines. The
# shellcheck formatter instead makes treefmt itself fail with exit 1.
#
# The patches were validated with treefmt 2.6.0 and the formatters of
# modules/treefmt/default.nix (rustfmt 1.10.0, taplo 0.10.0, cargo-sort
# 2.1.4, shfmt 3.14.1, yamlfmt 0.21.0, nixfmt 1.5.0, shellcheck 0.11.0): each
# patched copy of the fixture ends in a diff or an error, the unpatched
# fixture in none.
{ ... }:
{
  perSystem =
    {
      config,
      fixture,
      pkgs,
      ...
    }:
    let
      rejects =
        patch: logEntries:
        fixture.expectFailure {
          drv = config.treefmt.build.check (fixture.patched [ patch ]);
          inherit logEntries;
        };
    in
    {
      # The fixture has no flake.nix.
      treefmt.projectRootFile = "Cargo.toml";

      checks = {
        treefmt-cargo-sort-minimal-path = pkgs.runCommand "treefmt-cargo-sort-minimal-path" { } ''
          cp -R ${fixture.src} source
          chmod -R u+w source
          cd source
          PATH= ${config.treefmt.settings.formatter.cargo-sort.command} crates/app/Cargo.toml
          mkdir -- --help
          cp crates/app/Cargo.toml ./--help/Cargo.toml
          PATH= ${config.treefmt.settings.formatter.cargo-sort.command} --help/Cargo.toml
          touch $out
        '';

        treefmt-rejects-unformatted-rust = rejects ./unformatted-rust.patch [
          "+pub fn double(x: u32) -> u32 {"
        ];

        # The cargo-sort formatter, which taplo does not replace: it moves the
        # [dependencies] table below [package].
        treefmt-rejects-unsorted-manifest = rejects ./unsorted-manifest.patch [
          "diff --git a/crates/app/Cargo.toml b/crates/app/Cargo.toml"
          "-[dependencies]"
        ];

        # A non-Cargo file keeps cargo-sort from satisfying Taplo's test.
        treefmt-rejects-unformatted-toml = rejects ./unformatted-toml.patch [
          "+value = 1"
        ];

        treefmt-rejects-unformatted-shell = rejects ./unformatted-shell.patch [
          "diff --git a/greet.sh b/greet.sh"
        ];

        treefmt-rejects-unformatted-yaml = rejects ./unformatted-yaml.patch [
          "+name: fixture"
        ];

        treefmt-rejects-unformatted-nix = rejects ./unformatted-nix.patch [
          "+  a = 1;"
        ];

        treefmt-rejects-shellcheck-warning = rejects ./shellcheck-warning.patch [
          "SC2086"
          "formatting failures detected"
        ];
      };
    };
}
