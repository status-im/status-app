{
  description = "status-app";

  inputs = {
    # nixos-26.05 branch with qt 6.11.0
    nixpkgs.url = "github:NixOS/nixpkgs/705e9929918b43bd7b715dc0a878ac870449bb03";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Fixes OpenGL issues at runtime on non-NixOS Linux distros.
    # See See https://github.com/NixOS/nixpkgs/issues/9415
    nixgl = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixGL";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixgl,
  }: let
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;

    pkgsFor = forAllSystems (
      system:
        import nixpkgs {
          inherit system;
          overlays = [
            nixgl.overlay
            self.overlays.default
            (final: prev: {
              unstablePkgs = import nixpkgs-unstable {
                inherit (prev.stdenv.hostPlatform) system;
              };
            })
          ];
        }
    );
  in {
    overlays.default = import ./nix/overlays.nix;

    devShells = forAllSystems (system: {
      default = pkgsFor.${system}.callPackage ./nix/devshell.nix {};
    });

    packages = forAllSystems (
      system: let
        pkgs = pkgsFor.${system};
      in
        {
          inherit (pkgs) jdk; # keycard simulator precompile (USE_SIMULATED_KEYCARD packages)
          inherit (pkgs) nimble; # 0.24.1
        }
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
          inherit (pkgs) fileicon;
          inherit (pkgs.python313Packages) dmgbuild;
        }
    );
  };
}
