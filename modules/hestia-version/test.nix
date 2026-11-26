# Expected-failure tests of the `hestia-version` check. Each patch is a change
# to tests/fixture/.github/workflows/ci.yml that makes the Mic92/hestia step
# disagree with its pin comment, or the workflow unparsable. The check must
# exit 1 and name the pin and the version, or the workflow. Every patch was
# validated with yq 4.54.3 by running hestia-version.sh on the patched and on
# the unpatched fixture.
{ ... }:
{
  perSystem =
    {
      config,
      fixture,
      pkgs,
      ...
    }:
    {
      checks = {
        hestia-version-pin-comments =
          pkgs.runCommand "hestia-version-pin-comments" { nativeBuildInputs = [ pkgs.yq-go ]; }
            ''
              bash ${./test.sh} ${./hestia-version.sh}
              touch "$out"
            '';

        hestia-version-without-workflows =
          (fixture.evalPerSystem {
            allFlakeModules = false;
            self.outPath = ./fixtures/no-workflows;
            modules = [ fixture.flakeModules.hestia-version ];
          }).checks.hestia-version;

        hestia-version-rejects-mismatched-version = fixture.rejects {
          check = config.checks.hestia-version;
          patches = [ ./mismatched-version.patch ];
          logEntries = [ "pins 'v3.1.0' but sets version 'v3.0.1'" ];
        };

        hestia-version-rejects-unset-version = fixture.rejects {
          check = config.checks.hestia-version;
          patches = [ ./unset-version.patch ];
          logEntries = [ "pins 'v3.1.0' but sets version 'latest'" ];
        };

        hestia-version-rejects-missing-pin-comment = fixture.rejects {
          check = config.checks.hestia-version;
          patches = [ ./missing-pin-comment.patch ];
          logEntries = [ "pins 'no release comment' but sets version 'v3.1.0'" ];
        };

        # yq's exit status must not be lost: an unparsable workflow is not a
        # workflow without hestia steps.
        hestia-version-rejects-unparsable-workflow = fixture.rejects {
          check = config.checks.hestia-version;
          patches = [ ./unparsable-workflow.patch ];
          logEntries = [ "cannot parse workflow" ];
        };
      };
    };
}
