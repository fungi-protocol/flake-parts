# Defines the `checkTags` option and the aggregate checks `quick`, `lint` and
# `nightly`, each a linkFarm of the checks tagged with its name:
#
#   perSystem.checkTags.clippy = [ "lint" "nightly" "quick" ];
#
# The other check modules of this flake tag their check with lib.mkDefault, so
# a plain definition replaces their tags.
{ ... }:
{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      aggregates = [
        "lint"
        "nightly"
        "quick"
      ];
      members = tag: lib.filterAttrs (_: tags: builtins.elem tag tags) config.checkTags;
      # Follow the aggregate produced by this module even when a check aliases
      # it. Inspect metadata so cycle detection can run before forcing drvPath.
      acyclic =
        ancestors: name:
        let
          tag = config.checks.${name}._checkTagsAggregate or null;
        in
        if tag == null then
          true
        else if builtins.elem tag ancestors then
          throw "checkTags: aggregate cycle: ${lib.concatStringsSep " -> " (ancestors ++ [ tag ])}"
        else
          lib.all (acyclic (ancestors ++ [ tag ])) (lib.attrNames (members tag));
      tagged =
        tag:
        lib.mapAttrsToList (name: _: {
          inherit name;
          # Keep this guard on entries, so the aggregate's metadata remains
          # available without evaluating its dependencies.
          path =
            assert acyclic [ tag ] name;
            config.checks.${name} or (throw "checkTags.${name}: no check named '${name}' exists in `checks`");
        }) (members tag);
    in
    {
      options.checkTags = lib.mkOption {
        default = { };
        description = "Aggregate groups that include each check, by check name.";
        type = lib.types.attrsOf (lib.types.listOf (lib.types.enum aggregates));
      };

      # linkFarm, not symlinkJoin: checks that write the same file name (e.g.
      # nextest-run.zip) must not collide. mkDefault lets a flake replace an
      # aggregate with its own definition.
      config.checks = lib.genAttrs aggregates (
        tag:
        lib.mkDefault (
          (pkgs.linkFarm tag (tagged tag)).overrideAttrs (previous: {
            passthru = previous.passthru // {
              _checkTagsAggregate = tag;
            };
          })
        )
      );
    };
}
