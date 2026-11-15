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

        imports = lib.optional (builtins.pathExists ./tests) ./tests;

        flake = { inherit flakeModules; };

        # Each packages/NAME/default.nix becomes packages.<system>.NAME.
        perSystem =
          { pkgs, ... }:
          {
            packages = lib.mapAttrs (name: _: pkgs.callPackage (./packages + "/${name}") { }) (
              lib.filterAttrs (
                name: type: type == "directory" && builtins.pathExists (./packages + "/${name}/default.nix")
              ) (lib.optionalAttrs (builtins.pathExists ./packages) (builtins.readDir ./packages))
            );
          };
      }
    );
}
