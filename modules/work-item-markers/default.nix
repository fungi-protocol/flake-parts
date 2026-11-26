# Each attribute of `workItemMarkers` defines a check of that name, tagged
# `lint` and `nightly`, that fails when grep finds any of its basic regular
# expressions in the importing flake's text files outside Git metadata:
#
#   perSystem.workItemMarkers.no-todo-comments = [ "TO[D]O" "FIX[M]E" ];
#
# The brackets keep each pattern from matching its own definition. A name must
# be valid in a derivation name, e.g. without spaces.
{ localFlakeModules, ... }:
{ self, ... }:
{
  imports = [ localFlakeModules.check-tags ];

  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.workItemMarkers = lib.mkOption {
        default = { };
        description = "Non-empty patterns that must not occur in text files outside Git metadata, by check name.";
        type = lib.types.attrsOf (lib.types.nonEmptyListOf lib.types.nonEmptyStr);
      };

      config = {
        checkTags = lib.mapAttrs (
          _: _:
          lib.mkDefault [
            "lint"
            "nightly"
          ]
        ) config.workItemMarkers;

        checks = lib.mapAttrs (
          name: patterns:
          let
            grepPatterns = lib.concatMapStringsSep " " (p: "-e ${lib.escapeShellArg p}") patterns;
          in
          pkgs.runCommand name { src = self; } ''
            # grep exits with 1 when nothing matches and with 2 on an error,
            # such as an unreadable file, which must not pass the check.
            status=0
            grep -Irn --exclude-dir=.git --exclude=.git ${grepPatterns} "$src" || status=$?
            if [ "$status" -eq 0 ]; then
              echo "FAIL: unresolved work-item markers found"
              exit 1
            elif [ "$status" -ne 1 ]; then
              exit "$status"
            fi
            mkdir -p "$out"
          ''
        ) config.workItemMarkers;
      };
    };
}
