# Converts two small tracefiles the way concurrent-psbt's coverage merge does
# (`--demangle --base-dir .`): lcov2xml must merge its inputs, i.e. add up the
# hits of the same line, and demangle the Rust symbol. The expected values were
# checked with lcov2xml 1.0.10 from crates.io, built with cargo.
{ ... }:
{
  perSystem =
    { pkgs, fixture, ... }:
    {
      checks.lcov2xml-merges-tracefiles =
        pkgs.runCommand "lcov2xml-merges-tracefiles"
          {
            nativeBuildInputs = [ fixture.packages.lcov2xml ];
          }
          ''
            lcov2xml --demangle --base-dir . --output single.xml ${./first.lcov}
            lcov2xml --demangle --base-dir . --output merged.xml ${./first.lcov} ${./second.lcov}
            # The first tracefile alone misses line 5, the second one covers it.
            grep -F 'lines-covered="2" lines-valid="3"' single.xml
            grep -F 'lines-covered="3" lines-valid="3"' merged.xml
            # Line 3 has two hits in the first input and one in the second.
            grep -F 'hits="2" number="3"' single.xml
            grep -F 'hits="3" number="3"' merged.xml
            grep -F 'filename="src/lib.rs"' merged.xml
            grep -F 'name="crate[3]::add"' merged.xml
            mkdir "$out"
          '';
    };
}
