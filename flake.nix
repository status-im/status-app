{
  description = "Status Desktop build tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      forDarwin = f: nixpkgs.lib.genAttrs darwinSystems f;
    in {
      packages = forDarwin (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          dmgbuild = pkgs.python3Packages.dmgbuild.overrideAttrs (old: rec {
            version = "1.6.7";
            src = pkgs.fetchPypi {
              pname = "dmgbuild";
              inherit version;
              hash = "sha256-Z2sXrNRIiZ9tSoOyGE4GV0gEROy2rJxJIoie+tnl2/s=";
            };
          });

          # JDK to precompile the keycard simulator when packaging a USE_SIMULATED_KEYCARD build
          jdk = pkgs.jdk;
        }
      );
    };
}
