# Expected-failure test of the build check on the fixture. cargo exits with
# 101 when rustc reports an error.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    {
      # compile-error.patch: fixture-base uses a name that does not exist.
      checks.cargo-build-rejects-compile-error = fixture.expectFailure {
        drv = config.checks.build.overrideAttrs {
          src = fixture.patched [ ./compile-error.patch ];
        };
        exitCode = 101;
        logEntries = [
          "cannot find value `offset` in this scope"
          "could not compile `fixture-base`"
        ];
      };
    };
}
