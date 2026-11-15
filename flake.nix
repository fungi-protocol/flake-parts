{
  description = "Reusable flake parts for Fungi repositories";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      let
        # Each modules/NAME.nix or modules/NAME/default.nix becomes
        # flakeModules.NAME. A module file is a function of the arguments
        # below, applied with importApply, that returns a flake-parts module.
        moduleArgs = {
          # This flake's inputs, as opposed to the importing flake's `inputs`
          # module argument.
          localInputs = inputs;
          # Lets modules import each other.
          localFlakeModules = flakeModules;
        };
        flakeModules = import ./lib/export-modules.nix {
          inherit lib moduleArgs;
          inherit (inputs.flake-parts.lib) importApply;
          source = ./.;
        };
      in
      {
        systems = [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];

        imports =
          lib.optionals (flakeModules ? treefmt) [ flakeModules.treefmt ]
          ++ lib.optional (builtins.pathExists ./tests) ./tests;

        flake = { inherit flakeModules; };

        perSystem =
          { pkgs, ... }:
          {
            # Converts lcov tracefiles to Cobertura XML. Use from a perSystem
            # module as inputs'.fungi-flake-parts.packages.lcov2xml.
            packages = lib.optionalAttrs (builtins.pathExists ./packages/lcov2xml) {
              lcov2xml = pkgs.callPackage ./packages/lcov2xml { };
            };
          };
      }
    );
}
