# Expected failures: a workflow that actionlint rejects. Rule names in brackets
# and the start of each message are stable across actionlint versions; the
# rest is not.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    let
      consumerCheck =
        source:
        (fixture.evalPerSystem {
          allFlakeModules = false;
          self.outPath = source;
          modules = [ fixture.flakeModules.actionlint ];
        }).checks.actionlint;
    in
    {
      checks = {
        actionlint-without-workflows = consumerCheck ./fixtures/no-workflows;
        actionlint-with-config-yaml = consumerCheck ./fixtures/config-yaml;
        actionlint-with-config-yml = consumerCheck ./fixtures/config-yml;

        actionlint-rejects-undefined-local-action-input = fixture.expectFailure {
          drv = consumerCheck ./fixtures/local-action;
          logEntries = [
            "[action]"
            "unexpected-input"
          ];
        };

        actionlint-rejects-undefined-context-property = fixture.rejects {
          check = config.checks.actionlint;
          patches = [ ./undefined-context-property.patch ];
          logEntries = [
            ''property "eventt" is not defined in object type''
            "[expression]"
          ];
        };

        actionlint-rejects-job-without-runs-on = fixture.rejects {
          check = config.checks.actionlint;
          patches = [ ./missing-runs-on.patch ];
          logEntries = [
            ''"runs-on" section is missing in job "checks"''
            "[syntax-check]"
          ];
        };
      };
    };
}
