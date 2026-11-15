# Evaluation tests of fetch-validation-history (see tests/default.nix).
{
  lib,
  src,
  perSystem,
  evalPerSystem,
  ...
}:
let
  check = perSystem.checks.fetch-validation-history;
in
{
  testHelperCanBeReplaced = {
    expr =
      let
        replaced =
          (evalPerSystem {
            modules = [ { perSystem.fetchValidationHistory.helper = ./test.sh; } ];
          }).checks.fetch-validation-history;
      in
      replaced.helper != check.helper;
    expected = true;
  };

  # The helper is copied alone, so that the check is not rebuilt for every
  # change to the flake source.
  testOnlyHelperIsCopied = {
    expr = {
      name = lib.hasSuffix "-fetch-validation-history.sh" check.helper;
      notSource = lib.hasPrefix "${src}/" check.helper;
    };
    expected = {
      name = true;
      notSource = false;
    };
  };
}
