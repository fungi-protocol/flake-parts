# Expected-failure tests of the `fetch-validation-history` check: the test
# suite must reject each broken variant of the helper, which is
# tests/fixture/.github/scripts/fetch-validation-history.sh with a patch
# applied. The check takes the helper as its `helper` attribute, which is
# replaced here. Every patch was validated by running test.sh on the patched
# and on the unpatched helper with git 2.43.0.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    let
      withHelper =
        patches:
        config.checks.fetch-validation-history.overrideAttrs {
          helper = "${fixture.patched patches}/.github/scripts/fetch-validation-history.sh";
        };
    in
    {
      checks = {
        fetch-validation-history-rejects-removed-shallow-read = fixture.expectFailure {
          drv = withHelper [ ./read-removed-shallow.patch ];
          logEntries = [ "FAIL: read the shallow file after it was removed" ];
        };

        # A failed deepening fetch ends the loop, so validation would run on a
        # truncated range. The first scenarios do not need that fetch to fail.
        fetch-validation-history-rejects-ignored-fetch-failure = fixture.expectFailure {
          drv = withHelper [ ./ignore-fetch-failure.patch ];
          logEntries = [
            "PASS: complete and empty ranges need no fetch despite shallow history"
            "FAIL: fetch failure was accepted as complete history"
          ];
        };

        # Fetching once before checking whether the range is complete breaks
        # the scenario whose origin is unreachable; git exits with 128.
        fetch-validation-history-rejects-unneeded-fetch = fixture.expectFailure {
          drv = withHelper [ ./always-fetch.patch ];
          exitCode = 128;
          logEntries = [
            "PASS: fetch a missing base and complete the range without full history"
            "does not appear to be a git repository"
          ];
        };
      };
    };
}
