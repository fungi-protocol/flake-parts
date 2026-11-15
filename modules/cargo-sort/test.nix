# Expected failure of the cargo-sort check on the fixture workspace.
#
# unsorted-dependencies.patch adds a [workspace.dependencies] table whose
# entries are out of order, which cargo-sort reports as unsorted dependencies
# of the workspace root. The check names the root by the directory name of the
# source, which is not stable, so the log entry stops before it.
{ ... }:
{
  perSystem =
    { config, fixture, ... }:
    {
      checks.cargo-sort-rejects-unsorted-dependencies = fixture.rejects {
        check = config.checks.cargo-sort;
        patches = [ ./unsorted-dependencies.patch ];
        logEntries = [
          "Dependencies for "
          "Some Cargo.toml files are not sorted or formatted"
        ];
      };
    };
}
