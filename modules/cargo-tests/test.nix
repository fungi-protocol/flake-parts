# Expected failures of the tests and doctests checks on the fixture workspace.
# Only the nightly toolchain in the dev profile is tested; the other checks of
# the module differ in their arguments only.
#
# - failing-unit-test.patch changes the expected value of the unit test of
#   fixture-base::add. nextest exits with 100 when a test fails.
# - failing-doctest.patch changes the expected value of its doctest, which the
#   unit tests under nextest do not run. `cargo test --doc` exits with 101.
#
# The log entries name the failed test and avoid line numbers and counts.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    let
      consumerChecks =
        source:
        (fixture.evalPerSystem {
          allFlakeModules = false;
          self.outPath = source;
          modules = [
            fixture.flakeModules.cargo-tests
            { perSystem.cargoWorkspaces.consumer = { }; }
          ];
        }).checks;
      doctestsOnly = consumerChecks ./fixtures/doctests-only;
      binaryOnly = consumerChecks ./fixtures/binary-only;
    in
    {
      checks.cargo-tests-doctests-only = doctestsOnly.consumer-tests-nightly-dev;
      checks.cargo-tests-doctests-only-docs = doctestsOnly.consumer-doctests-nightly-dev;
      checks.cargo-tests-binary-only = binaryOnly.consumer-tests-nightly-dev;
      checks.cargo-tests-binary-only-docs = binaryOnly.consumer-doctests-nightly-dev;

      checks.cargo-tests-cdylib-only-docs =
        (consumerChecks ./fixtures/cdylib).consumer-doctests-nightly-dev;
      checks.cargo-tests-staticlib-only-docs =
        (consumerChecks ./fixtures/staticlib).consumer-doctests-nightly-dev;

      checks.cargo-tests-rejects-failing-unit-test = fixture.rejects {
        check = config.checks.tests-nightly-dev;
        patches = [ ./failing-unit-test.patch ];
        exitCode = 100;
        logEntries = [
          "FAIL"
          "fixture-base tests::adds"
          "assertion `left == right` failed"
        ];
      };

      checks.cargo-tests-rejects-failing-doctest = fixture.rejects {
        check = config.checks.doctests-nightly-dev;
        patches = [ ./failing-doctest.patch ];
        exitCode = 101;
        logEntries = [
          "crates/base/src/lib.rs - add"
          "FAILED"
          "assertion `left == right` failed"
        ];
      };
    };
}
