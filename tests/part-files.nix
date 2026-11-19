# Discover test entrypoints without importing them.
{ lib, roots }:
file:
lib.listToAttrs (
  lib.concatMap (
    kind:
    let
      dir = roots.${kind};
      entries = lib.optionalAttrs (builtins.pathExists dir) (builtins.readDir dir);
    in
    lib.concatMap (
      name:
      let
        path = dir + "/${name}/${file}";
      in
      lib.optional (entries.${name} == "directory" && builtins.pathExists path) (
        lib.nameValuePair "${kind}-${name}" path
      )
    ) (builtins.attrNames entries)
  ) (builtins.attrNames roots)
)
