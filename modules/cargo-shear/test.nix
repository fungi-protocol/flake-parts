# Expected failure of the cargo-shear check on the fixture workspace.
#
# unused-dependency.patch adds fixture-app as a dev-dependency of fixture-base,
# which does not use it. fixture-app depends on fixture-base, and Cargo accepts
# such a cycle through a dev-dependency. Like all dependencies of the fixture
# it is a path dependency, so the vendored dependencies of the patched source
# equal the fixture's and the check keeps its `cargoVendorDir`.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    {
      checks.cargo-shear-rejects-unused-dependency = fixture.rejects {
        check = config.checks.cargo-shear;
        patches = [ ./unused-dependency.patch ];
        logEntries = [
          "unused dependency `fixture-app`"
          "crates/base/Cargo.toml"
        ];
      };
    };
}
