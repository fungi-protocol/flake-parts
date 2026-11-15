# Check `cargo-sort` for each workspace of the cargo-workspaces module, tagged
# `lint` and `nightly`. Fails unless the manifests of the workspace are sorted
# as `cargo sort --workspace` would leave them.
{ localFlakeModules, ... }:
{ ... }:
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    { pkgs, ... }:
    {
      cargoChecks.cargo-sort = {
        tags = [
          "lint"
          "nightly"
        ];
        package =
          workspace:
          pkgs.runCommand workspace.checks.cargo-sort
            {
              inherit (workspace.commonArgs) src;
              nativeBuildInputs = [ pkgs.cargo-sort ];
            }
            ''
              cargo-sort --check --workspace "${workspace.srcDir}"
              mkdir -p "$out"
            '';
      };
    };
}
