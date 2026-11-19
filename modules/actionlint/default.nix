# Check `actionlint`, tagged `lint` and `nightly`: runs actionlint over the
# importing flake's .github/workflows.
{ localFlakeModules, ... }:
{ self, ... }:
{
  imports = [ localFlakeModules.check-tags ];

  perSystem =
    { lib, pkgs, ... }:
    {
      checkTags.actionlint = lib.mkDefault [
        "lint"
        "nightly"
      ];

      checks.actionlint =
        pkgs.runCommand "actionlint"
          {
            nativeBuildInputs = [ pkgs.actionlint ];
            src = self;
          }
          ''
            if [ -d "$src/.github/workflows" ]; then
              # actionlint uses .git to locate the project and resolve local actions.
              # Nix's Git source snapshots do not include repository metadata.
              mkdir source
              cp -R "$src"/. source/
              cd source
              if [ ! -e .git ]; then
                mkdir .git
              fi
              args=()
              for extension in yaml yml; do
                if [ -f ".github/actionlint.$extension" ]; then
                  args=(-config-file ".github/actionlint.$extension")
                  break
                fi
              done
              # actionlint 1.7.12 predates the code-quality permission scope.
              find .github/workflows -type f \
                \( -name '*.yml' -o -name '*.yaml' \) \
                -exec actionlint "''${args[@]}" -ignore 'unknown permission scope "code-quality"' {} +
            fi
            mkdir -p "$out"
          '';
    };
}
