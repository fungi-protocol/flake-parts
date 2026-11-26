# Evaluation tests of treefmt: the formatters it enables, their order, and how a
# flake disables, adds and extends them.
{
  lib,
  flakeModules,
  evalPerSystem,
  ...
}:
let
  # build.programs has the enabled programs, without the renamed aliases that
  # warn when their `enable` is read.
  enabled = config: lib.attrNames config.treefmt.build.programs;
  defaults = evalPerSystem {
    modules = [ flakeModules.treefmt ];
    allFlakeModules = false;
  };
  customized = evalPerSystem {
    modules = [
      flakeModules.treefmt
      {
        perSystem.treefmt = {
          programs.yamlfmt.enable = false;
          programs.mdformat.enable = true;
          settings.formatter.cargo-sort.includes = [ "tools/Cargo.toml" ];
        };
      }
    ];
    allFlakeModules = false;
  };
in
{
  # The programs are mkDefault: a flake disables one and adds others.
  testProgramsCanBeChanged = {
    expr = enabled customized;
    expected = [
      "mdformat"
      "nixfmt"
      "rustfmt"
      "shellcheck"
      "shfmt"
      "taplo"
    ];
  };

  # cargo-sort sorts the manifests before taplo formats them.
  testCargoSortRunsBeforeTaplo = {
    expr = {
      cargoSort = defaults.treefmt.settings.formatter.cargo-sort.priority;
      taplo = defaults.treefmt.programs.taplo.priority;
    };
    expected = {
      cargoSort = 0;
      taplo = 1;
    };
  };

  # A list definition extends the includes.
  testCargoSortIncludesCanBeExtended = {
    expr = lib.sort lib.lessThan customized.treefmt.settings.formatter.cargo-sort.includes;
    expected = [
      "**/Cargo.toml"
      "Cargo.toml"
      "tools/Cargo.toml"
    ];
  };
}
