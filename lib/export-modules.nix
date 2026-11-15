{
  lib,
  source,
  importApply,
  moduleArgs,
}:
let
  moduleEntries = lib.filterAttrs (entry: type: type == "directory" || lib.hasSuffix ".nix" entry) (
    lib.optionalAttrs (builtins.pathExists (source + "/modules")) (
      builtins.readDir (source + "/modules")
    )
  );
  flakeModules = lib.mapAttrs' (
    entry: _:
    let
      name = lib.removeSuffix ".nix" entry;
    in
    lib.nameValuePair name {
      # Deduplicates the module when it is imported more than once, e.g.
      # directly and by another module. Distinct source trees must
      # retain their definitions instead of suppressing one another.
      key = "${source}#flakeModules.${name}";
      imports = [ (importApply (source + "/modules/${entry}") moduleArgs) ];
    }
  ) moduleEntries;
in
flakeModules
