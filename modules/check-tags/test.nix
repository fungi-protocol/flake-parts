# Each aggregate must link exactly the checks tagged with its name, for the
# fixture's tags as a whole and for two probe checks with distinct tags.
{ ... }:
{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      probe = name: pkgs.runCommand name { } ''mkdir "$out"'';
      # One check name per line.
      expected =
        tag:
        lib.concatMapStrings (name: "${name}\n") (
          lib.attrNames (lib.filterAttrs (_: tags: builtins.elem tag tags) config.checkTags)
        );
    in
    {
      checks = {
        check-tags-probe-lint = probe "check-tags-probe-lint";
        check-tags-probe-nightly = probe "check-tags-probe-nightly";

        check-tags-aggregates =
          pkgs.runCommand "check-tags-aggregates"
            {
              inherit (config.checks) lint nightly quick;
              expectedLint = expected "lint";
              expectedNightly = expected "nightly";
              expectedQuick = expected "quick";
            }
            ''
              export LC_ALL=C
              diff <(ls -1 "$lint") <(printf %s "$expectedLint")
              diff <(ls -1 "$nightly") <(printf %s "$expectedNightly")
              diff <(ls -1 "$quick") <(printf %s "$expectedQuick")
              [[ -e $lint/check-tags-probe-lint && ! -e $lint/check-tags-probe-nightly ]]
              [[ -e $nightly/check-tags-probe-nightly && ! -e $nightly/check-tags-probe-lint ]]
              mkdir "$out"
            '';
      };

      checkTags = {
        check-tags-probe-lint = [ "lint" ];
        check-tags-probe-nightly = [ "nightly" ];
      };
    };
}
