# The fixture forbids both kinds of marker; each expected-failure test adds a
# comment with one of them to a source file.
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
      workItemMarkers.no-todo-comments = [
        "TO[D]O"
        "FIX[M]E"
      ];

      checks = {
        no-todo-comments-ignores-git-metadata = config.checks.no-todo-comments.overrideAttrs {
          src = pkgs.runCommand "marker-source" { } ''
            mkdir -p "$out/.git/hooks" "$out/worktree"
            printf 'TODO: hook sample\n' > "$out/.git/hooks/sample"
            printf 'TODO: worktree metadata\n' > "$out/worktree/.git"
            printf 'TODO\0binary' > "$out/asset.bin"
          '';
        };

        no-todo-comments-rejects-todo = fixture.rejects {
          check = config.checks.no-todo-comments;
          patches = [ ./todo-comment.patch ];
          logEntries = [
            "FAIL: unresolved work-item markers found"
            "// TODO: handle overflow"
          ];
        };

        no-todo-comments-rejects-fixme = fixture.rejects {
          check = config.checks.no-todo-comments;
          patches = [ ./fixme-comment.patch ];
          logEntries = [
            "FAIL: unresolved work-item markers found"
            "// FIXME: use multiplication"
          ];
        };
      };
    };
}
