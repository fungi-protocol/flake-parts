# Evaluation tests of work-item-markers: one check per attribute, with each
# pattern quoted for the shell.
{
  lib,
  evalPerSystem,
  throws,
  ...
}:
let
  withMarkers = markers: evalPerSystem { modules = [ { perSystem.workItemMarkers = markers; } ]; };
  config = withMarkers {
    no-markers = [
      "TO[D]O"
      "it's"
    ];
    no-hacks = [ "HA[C]K" ];
  };
in
{
  testRejectsEmptyPattern = {
    expr = throws (builtins.deepSeq (withMarkers { empty = [ "" ]; }).workItemMarkers true);
    expected = true;
  };

  testOneCheckPerAttribute = {
    expr = map (name: config.checks.${name}.name) [
      "no-hacks"
      "no-markers"
    ];
    expected = [
      "no-hacks"
      "no-markers"
    ];
  };

  # Every pattern is passed with -e and quoted for the shell.
  testPatternsAreQuoted = {
    expr = lib.hasInfix "grep -Irn --exclude-dir=.git --exclude=.git -e 'TO[D]O' -e 'it'\\''s' \"$src\"" config.checks.no-markers.buildCommand;
    expected = true;
  };
}
