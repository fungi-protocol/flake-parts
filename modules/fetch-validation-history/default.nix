# Check `fetch-validation-history`: tests the importing flake's copy of the
# bounded validation-history fetch helper, `fetchValidationHistory.helper`.
# The helper stays in the importing repository because CI runs it before Nix
# is installed.
{ ... }:
{ self, ... }:
{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.fetchValidationHistory.helper = lib.mkOption {
        type = lib.types.path;
        default = "${self}/.github/scripts/fetch-validation-history.sh";
        defaultText = lib.literalExpression ''"''${self}/.github/scripts/fetch-validation-history.sh"'';
        description = "The helper script under test.";
      };

      config.checks.fetch-validation-history =
        pkgs.runCommand "fetch-validation-history"
          {
            nativeBuildInputs = [ pkgs.git ];
            # An attribute, so that tests can replace the helper with
            # overrideAttrs. Copy only the helper, so that the check is not
            # rebuilt for every change to the flake source.
            helper = builtins.path {
              path = config.fetchValidationHistory.helper;
              name = "fetch-validation-history.sh";
            };
          }
          ''
            bash ${./test.sh} "$helper"
            mkdir -p "$out"
          '';
    };
}
