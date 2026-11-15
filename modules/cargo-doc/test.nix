# Expected-failure test of the doc check on the fixture. cargo exits with 101
# when rustdoc reports an error.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    {
      # broken-link.patch: an intra-doc link to an item that does not exist.
      # rustdoc only warns about it, so the test fails unless the check
      # passes RUSTDOCFLAGS="-D warnings".
      checks.cargo-doc-rejects-broken-link = fixture.expectFailure {
        drv = config.checks.doc.overrideAttrs {
          src = fixture.patched [ ./broken-link.patch ];
        };
        exitCode = 101;
        logEntries = [
          "unresolved link to `fixture_base::subtract`"
          "could not document `fixture-app`"
        ];
      };
    };
}
