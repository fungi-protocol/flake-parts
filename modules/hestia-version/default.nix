# Check `hestia-version`, tagged `lint` and `nightly`: fails unless every
# Mic92/hestia step in the importing flake's .github/workflows sets `version`
# to the release named in its pin comment.
{ localFlakeModules, ... }:
{ self, ... }:
{
  imports = [ localFlakeModules.check-tags ];

  perSystem =
    { lib, pkgs, ... }:
    {
      checkTags.hestia-version = lib.mkDefault [
        "lint"
        "nightly"
      ];

      checks.hestia-version =
        pkgs.runCommand "hestia-version"
          {
            nativeBuildInputs = [ pkgs.yq-go ];
            src = self;
          }
          ''
            if [ -d "$src/.github/workflows" ]; then
              find "$src/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) \
                -exec bash ${./hestia-version.sh} {} +
            fi
            mkdir -p "$out"
          '';
    };
}
