# Expected-failure tests of the clippy check on the fixture. Each patch is a
# deliberately bad change to the fixture; cargo exits with 101 when clippy
# reports an error.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    let
      each =
        (fixture.evalPerSystem {
          allFlakeModules = false;
          modules = [
            fixture.flakeModules.cargo-clippy
            {
              perSystem = {
                cargoWorkspaces.fixture.manifestPath = "Cargo.toml";
                cargoClippy.eachFeature = true;
                cargoClippy.denyLints = [ "clippy::allow_attributes" ];
              };
            }
          ];
        }).checks.fixture-clippy;
      featureSource = fixture.patched [ ./feature-specific-warning.patch ];
    in
    {
      checks.cargo-clippy-each-feature = each;
      checks.cargo-clippy-all-features-control = config.checks.clippy.overrideAttrs {
        src = featureSource;
      };
      checks.cargo-clippy-rejects-feature-specific-warning = fixture.expectFailure {
        drv = each.overrideAttrs { src = featureSource; };
        # cargo-hack reports a failed child invocation with status 1.
        exitCode = 1;
        logEntries = [ "unused variable: `feature_only`" ];
      };

      checks.cargo-clippy-rejects-implicit-optional-feature-warning = fixture.expectFailure {
        drv = each.overrideAttrs {
          src = fixture.patched [ ./implicit-optional-feature.patch ];
        };
        exitCode = 1;
        logEntries = [ "unused variable: `optional_only`" ];
      };

      # Denied in addition to the default `warnings` and `unused`; the
      # fixture satisfies it.
      cargoClippy.denyLints = [ "clippy::allow_attributes" ];

      # needless-return.patch: a `return` as the last statement of a function,
      # a default-warn clippy lint that the default `-D warnings` denies.
      checks.cargo-clippy-rejects-needless-return = fixture.expectFailure {
        drv = config.checks.clippy.overrideAttrs {
          src = fixture.patched [ ./needless-return.patch ];
        };
        exitCode = 101;
        logEntries = [
          "unneeded `return` statement"
          "could not compile `fixture-base`"
        ];
      };

      # allow-attribute.patch: an `#[allow]` attribute, which clippy accepts
      # unless clippy::allow_attributes is denied through
      # cargoClippy.denyLints, as above.
      checks.cargo-clippy-rejects-denied-lint = fixture.expectFailure {
        drv = config.checks.clippy.overrideAttrs {
          src = fixture.patched [ ./allow-attribute.patch ];
        };
        exitCode = 101;
        logEntries = [
          "#[allow] attribute found"
          "could not compile `fixture-base`"
        ];
      };
    };
}
