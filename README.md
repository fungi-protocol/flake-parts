# flake-parts

Reusable [flake-parts](https://flake.parts) modules so Fungi repositories can
share checks instead of maintaining separate copies.

The input is named `fungi-flake-parts` below, because a flake that uses these
modules already has an input named `flake-parts`, the module system itself.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fungi-flake-parts = {
      url = "github:fungi-protocol/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.fungi-flake-parts.flakeModules.NAME ];
    };
}
```

Every `modules/NAME.nix` or `modules/NAME/default.nix` is exported as
`flakeModules.NAME` and documented in its header comment.
