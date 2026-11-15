# Check `cargo-shear` for each workspace of the cargo-workspaces module, tagged
# `lint` and `nightly`. Fails if cargo-shear finds unused dependencies. It
# reads manifests and sources, so it only needs the dependencies vendored and
# cargo kept offline, not the workspace built.
{ localFlakeModules, ... }:
{ ... }:
{
  imports = [ localFlakeModules.cargo-workspaces ];

  perSystem =
    { pkgs, ... }:
    {
      cargoChecks.cargo-shear = {
        tags = [
          "lint"
          "nightly"
        ];
        package =
          workspace:
          pkgs.runCommand workspace.checks.cargo-shear
            {
              inherit (workspace) cargoVendorDir;
              inherit (workspace.commonArgs) src;
              nativeBuildInputs = [
                pkgs.cargo
                pkgs.cargo-shear
              ];
            }
            ''
              export CARGO_HOME="$TMPDIR/cargo-home"
              export CARGO_NET_OFFLINE=true
              mkdir -p "$CARGO_HOME"
              cp "$cargoVendorDir/config.toml" "$CARGO_HOME/config.toml"
              cd "${workspace.srcDir}"
              cargo-shear
              mkdir -p "$out"
            '';
      };
    };
}
